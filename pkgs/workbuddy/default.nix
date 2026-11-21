{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,

  # 运行时依赖（同时供 autoPatchelf 与 wrapper 使用）
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libkrb5,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  libxkbcommon,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
  libxscrnsaver,
  libxtst,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  util-linux,
  xdg-utils,

  # 额外开关
  commandLineArgs ? "",
  # Electron 的 chrome-sandbox 在 Nix store 内无法 setuid，默认关闭沙箱。
  disableSandbox ? true,
  # 是否保留 deb 自带的 node/python 运行时（resources/runtime，约 595 MB）。
  # 自带 Electron 本身始终保留。
  keepBundledRuntime ? false,
}:

let
  # deb 文件名中的 build hash，升级时需同步修改
  buildHash = "c7b525f3";

  selectSystem = attrs:
    attrs.${stdenv.hostPlatform.system}
      or (throw "workbuddy: ${stdenv.hostPlatform.system} is not supported");

  source = selectSystem {
    x86_64-linux = {
      arch = "x64";
      hash = "sha256-EhSa2MDNdI/VBi2PYseCfWiNgJVCetqZsa6ecBmJdSM=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-VhgiV4Q104KgbQoLB5pLFX9otYjJ/nLVieKoiy/RVfo=";
    };
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "workbuddy";
  version = "5.6.2.40046327";

  src = fetchurl {
    url = "https://download.codebuddy.cn/workbuddy/saas/linux-${source.arch}-deb/WorkBuddy-linux-${source.arch}-deb-${finalAttrs.version}-${buildHash}.deb";
    # 实测哈希。官方 /v2/update 接口返回的 sha256hash 与 CDN 实际文件不符
    # （x64、arm64 都不一致），不要直接填接口给的值。
    hash = source.hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
    dpkg
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    glib
    gtk3
    libdrm
    libgbm
    libkrb5
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libxkbcommon
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
    libxscrnsaver
    libxtst
    mesa
    nspr
    nss
    pango
    util-linux
    xdg-utils
  ];

  # 跨平台预编译产物（koffi 的 openbsd/musl 变体等）依赖别的平台的库，
  # autoPatchelf 扫到会失败，直接全部忽略
  autoPatchelfIgnoreMissingDeps = true;

  runtimeDependencies = map lib.getLib [
    systemd
    libkrb5
  ];

  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # 内置 node/python 运行时（约 595 MB），默认不保留。
    # 自带 Electron、app.asar 及其 unpacked 原生模块全部保持原样：
    # Electron 37 与 better-sqlite3 12.8.0 的 ABI 136 本来就是配套的。
    ${lib.optionalString (!keepBundledRuntime) ''
      rm -rf opt/WorkBuddy/resources/runtime
    ''}

    cp -r opt $out/opt
    cp -r usr/share $out/share

    substituteInPlace $out/share/applications/workbuddy.desktop \
      --replace-fail "/opt/WorkBuddy/workbuddy" "$out/bin/workbuddy"

    # 自带 Electron 从 process.execPath 推导 resources 目录；安装目录保持
    # opt/WorkBuddy/{workbuddy,resources} 的相对布局，所以 process.resourcesPath
    # 自动指向 $out/opt/WorkBuddy/resources，无需改写 app.asar。
    makeWrapper $out/opt/WorkBuddy/workbuddy $out/bin/workbuddy \
      --argv0 "workbuddy" \
      --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH" \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          libGL
          libuuid
          libsecret
          libxscrnsaver
          libxtst
        ]
      }" \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--enable-features=WaylandWindowDecorations" \
      --add-flags "--enable-wayland-ime=true" \
      --add-flags "--wayland-text-input-version=3" \
      ${lib.optionalString (commandLineArgs != "") "--add-flags ${lib.escapeShellArg commandLineArgs}"} \
      ${lib.optionalString disableSandbox "--add-flags --no-sandbox"} \
      "''${gappsWrapperArgs[@]}"

    runHook postInstall
  '';

  meta = {
    description = "WorkBuddy Desktop - AI Agent Desktop Application";
    homepage = "https://www.codebuddy.cn/work/";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "workbuddy";
  };
})
