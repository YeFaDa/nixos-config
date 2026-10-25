{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,

  # 运行时依赖（drv 逆向自 NUR@c270f80b 的 zcode 3.16.2，
  # 保证与官方 deb 的链接面一致；改用系统 nixpkgs 后 glibc/mesa
  # 自动跟随系统，不再自带旧世代）
  alsa-lib,
  at-spi2-core,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libnotify,
  libsecret,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxtst,
  libxcb,
  nspr,
  nss,
  pango,
  util-linux,
  xdg-utils,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "zcode";
  version = "3.16.3";

  src = fetchurl {
    url = "https://cdn-zcode.z.ai/zcode/electron/releases/${finalAttrs.version}/linux-x64/ZCode-${finalAttrs.version}-linux-x64.deb";
    # 实测哈希（与原 NUR 包一致）
    hash = "sha256-EoEysZWXf9CoyKbClc9C/hWSItelxe/v2LXwDviKuLY=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-core
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libnotify
    libsecret
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libxrender
    libxscrnsaver
    libxtst
    libxcb
    nspr
    nss
    pango
    util-linux
    xdg-utils
  ];

  # Electron 的 koffi 等原生模块带其他平台的库，autoPatchelf 扫到会失败
  autoPatchelfIgnoreMissingDeps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/applications

    cp -r opt $out/opt
    cp -r usr/share/icons $out/share/icons

    substituteInPlace usr/share/applications/zcode.desktop \
      --replace-fail "/opt/ZCode/zcode" "$out/bin/zcode"
    cp usr/share/applications/zcode.desktop $out/share/applications/zcode.desktop

    # 自带 Electron 从 process.execPath 推导 resources 目录；
    # opt/ZCode/{zcode,resources} 的相对布局保持原样即可
    makeWrapper $out/opt/ZCode/zcode $out/bin/zcode \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}"

    runHook postInstall
  '';

  meta = {
    description = "ZCode - AI coding agent (Electron desktop + CLI)";
    homepage = "https://z.ai";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "zcode";
  };
})
