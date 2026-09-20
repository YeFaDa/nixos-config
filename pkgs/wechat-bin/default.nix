{
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  cairo,
  cups,
  dbus,
  dpkg,
  eudev,
  expat,
  fetchurl,
  fontconfig,
  freetype,
  gcc-unwrapped,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  hicolor-icon-theme,
  libdrm,
  libglvnd,
  libice,
  libjack2,
  libpulseaudio,
  libsecret,
  libsm,
  libxcb,
  libx11,
  libxcursor,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxcb-image,
  libxcb-keysyms,
  libxcb-render-util,
  libxcb-wm,
  makeWrapper,
  mesa,
  nspr,
  nss,
  pango,
  patchelf,
  pipewire,
  stdenvNoCC,
  systemd,
  lib,
  wayland,
  xdg-utils,
  xkeyboard_config,
  zlib,
}:
stdenvNoCC.mkDerivation {
  pname = "wechat-bin";
  version = "4.1.13.23";

  src = fetchurl {
    url = "https://dldir1.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb";
    hash = "sha256-t9D41T6fZIvCx3pglqBBANAI8tnw05iKKkhZtZkqygo=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    patchelf
  ];

  # AUR wechat-bin's depends plus what the bundled RadiumWMPF/WeChatAppEx
  # (Electron) and vlc_plugins really link against.
  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    eudev
    expat
    fontconfig
    freetype
    gcc-unwrapped.lib # libstdc++, libgcc_s, libatomic
    glib
    gsettings-desktop-schemas
    gtk3
    hicolor-icon-theme
    libdrm
    libglvnd
    libice
    libjack2
    libpulseaudio
    libsm
    libxcb
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libxrender
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-wm
    mesa # libgbm
    nspr
    nss
    pango
    zlib
  ];

  # Vendor binaries carry their own debug sections and integrity data.
  dontStrip = true;

  # autoPatchelf runs from postFixupHooks, i.e. after this package's own
  # postFixup, and it rewrites every RUNPATH it touches. Driving it by hand is
  # the only way to reorder the result afterwards.
  dontAutoPatchelf = true;

  unpackPhase = ''
    runHook preUnpack
    mkdir -p wechat-deb
    dpkg-deb -x "$src" wechat-deb
    cd wechat-deb
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib"
    cp -a opt/wechat "$out/lib/wechat"
    cp -a usr/share "$out/share"

    # The deb's desktop entry points at FHS paths that do not exist here.
    substituteInPlace "$out/share/applications/wechat.desktop" \
      --replace-fail "Exec=/usr/bin/wechat" "Exec=wechat" \
      --replace-fail "Icon=/usr/share/icons/hicolor/512x512/apps/wechat.png" "Icon=wechat"

    runHook postInstall
  '';

  postFixup = ''
    autoPatchelf "$out/lib/wechat"

    # Everything WeChat reaches for with dlopen("libfoo.so.N") instead of
    # linking against it: its own "Wayland stub"/"GLVND stub" loaders, the
    # PulseAudio/PipeWire/ALSA audio backends, GL drivers, GTK3 for the file
    # chooser, libudev. autoPatchelf only records NEEDED entries, so none of
    # these land in a RUNPATH and every such dlopen fails unless the caller
    # happens to inherit a wide LD_LIBRARY_PATH -- WeChat then calls through the
    # null function pointer and SIGSEGVs before a window is mapped.
    dlopen_dirs=${lib.makeLibraryPath [
      alsa-lib
      at-spi2-core
      cairo
      cups
      dbus
      expat
      fontconfig
      gcc-unwrapped.lib
      glib
      gtk3
      libdrm
      libglvnd
      libice
      libjack2
      libpulseaudio
      libsecret
      libsm
      libxcursor
      libx11
      libxkbcommon
      libxcb
      mesa
      nspr
      nss
      pango
      pipewire
      systemd
      wayland
      zlib
    ]}

    # The bundle keeps two different libffmpeg.so files in two directories and
    # both are needed by their own neighbour, but autoPatchelf puts whichever it
    # walked first at the head of every RUNPATH: WeChatAppEx then got vlc's copy
    # and died on an undefined av_stream_get_first_dts. Upstream only ever
    # searched the loading binary's own directory, so restore that precedence.
    #
    # The dlopen directories go at the *tail* for the same reason: LD_LIBRARY_PATH
    # would work too, but ld.so consults it before DT_RUNPATH, so exporting it
    # would let a nixpkgs library win over the bundle's own neighbour again.
    origin='$ORIGIN'
    find "$out/lib/wechat" -type f | while IFS= read -r file; do
      rp=$(patchelf --print-rpath "$file" 2>/dev/null) || continue
      [ -n "$rp" ] || rp="$origin"
      case "$rp" in
        "$origin:"*|"$origin") ;;
        *) rp="$origin:$rp" ;;
      esac
      patchelf --set-rpath "$rp:$dlopen_dirs" "$file"
    done

    # WeChatAppEx dlopens GTK3 for its file chooser and aborts in
    # g_settings_new() without the compiled schemas nixpkgs ships. gtk3 nests
    # those one versioned directory deeper, so they are resolved at build time.
    xdg_data_dirs="$out/share"
    for d in ${gtk3}/share/gsettings-schemas/*/; do
      if [ -d "''${d}glib-2.0/schemas" ]; then
        xdg_data_dirs="$xdg_data_dirs:''${d%/}"
      fi
    done
    xdg_data_dirs="$xdg_data_dirs:${gsettings-desktop-schemas}/share:${hicolor-icon-theme}/share"

    # WeChat's Wayland backend dereferences the compiled xkb keymap unchecked,
    # and libxkbcommon otherwise falls back to /usr/share/X11/xkb: no keymap,
    # no window, just a SIGSEGV in the wl keyboard callback.
    mkdir -p "$out/bin"
    makeWrapper "$out/lib/wechat/wechat" "$out/bin/wechat" \
      --prefix XDG_DATA_DIRS : "$xdg_data_dirs" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --set XKB_CONFIG_ROOT ${xkeyboard_config}/share/X11/xkb \
      --set QT_IM_MODULE text-input-unstable-v3
  '';

  meta = {
    description = "WeChat, messaging and calling app (repackaged from the official .deb)";
    homepage = "https://linux.weixin.qq.com/";
    downloadPage = "https://linux.weixin.qq.com/en";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "wechat";
    platforms = [ "x86_64-linux" ];
  };
}
