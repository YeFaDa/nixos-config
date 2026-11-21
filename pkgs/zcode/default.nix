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

  # 3.17.x 起 Electron 44 不再自带 ANGLE 的 libEGL/libGLESv2，
  # 运行时通过 dlopen 找系统的 libEGL.so.1 / libGLESv2.so.2 / libGL.so.1。
  # NixOS 这些只在 libglvnd 的 store 路径里，必须显式加进 RUNPATH；
  # vulkan-loader 让 ANGLE 能发现 /run/opengl-driver 的 NVIDIA ICD；
  # pciutils 是 ANGLE 枚举 GPU 时 dlopen libpci 用的。
  libGL,
  vulkan-loader,
  pciutils,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "zcode";
  version = "3.18.2";

  src = fetchurl {
    url = "https://cdn-zcode.z.ai/zcode/electron/releases/${finalAttrs.version}/linux-x64/ZCode-${finalAttrs.version}-linux-x64.deb";
    hash = "sha256-p+Bm7rAY0V5ANUahTdNpIiD8mXZ2mx81JaBiDPqXT3M=";
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

  # 这些库只被 dlopen，不会出现在 DT_NEEDED 里，autoPatchelf 不会自动
  # 加进 RUNPATH，所以显式声明为运行时依赖。
  runtimeDependencies = [
    libGL
    vulkan-loader
    pciutils
  ];

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

    # deb 自带的 vulkan-loader 未经 NixOS 补丁，找不到 /run/opengl-driver
    # 下的 NVIDIA ICD；换成 nixpkgs 的 loader，SwiftShader ICD 仍保留。
    rm $out/opt/ZCode/libvulkan.so.1
    ln -s ${lib.getLib vulkan-loader}/lib/libvulkan.so.1 $out/opt/ZCode/libvulkan.so.1

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
