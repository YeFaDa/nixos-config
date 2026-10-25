{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

# 上游只发预编译 gnu 二进制（无源码构建产物差异），依赖面实测仅
# libc/libm/libgcc_s；autoPatchelfHook 负责重写 ELF 解释器。
stdenv.mkDerivation (finalAttrs: {
  pname = "alter-zero";
  version = "0.15.0";

  src = fetchurl {
    url = "https://github.com/linuztx/alter-zero/releases/download/v${finalAttrs.version}/alter-zero-v${finalAttrs.version}-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-FyH9qv82ztawOzNWd2D8bdZjUOe8AGx+yvi0xZD+g5g=";
  };

  sourceRoot = "alter-zero-v${finalAttrs.version}-x86_64-unknown-linux-gnu";

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    install -Dm755 alter-zero $out/bin/alter-zero
    install -Dm644 LICENSE $out/share/licenses/alter-zero/LICENSE

    runHook postInstall
  '';

  meta = {
    description = "Terminal agent harness for coding, cybersecurity, and automation";
    homepage = "https://github.com/linuztx/alter-zero";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "alter-zero";
  };
})
