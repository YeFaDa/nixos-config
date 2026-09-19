{ pkgs, inputs, config, ...}:
{
  environment.systemPackages = with pkgs; [
  (pkgs.buildFHSEnv {
        name = "pixi";           # 生成的可执行文件名，在终端输入 `pixi` 即可调用
        runScript = "pixi";      # 在 FHS 沙箱内实际执行的命令
        targetPkgs = pkgs: with pkgs; [
          pixi                   # 将 pixi 本身安装到沙箱中
          zlib
          glibc
          stdenv.cc.cc
          stdenv.cc.cc.lib
          openssl
          util-linux
          icu
          libxml2
          libxcrypt
          # NVIDIA 驱动库
          #cudatoolkit
          #cudaPackages.cudnn
          #cudaPackages.cuda_cudart   # CUDA Runtime
          libGLU
          libGL
          libXi
          libXmu
          freeglut
          libXext
          libX11
          libXv
          libXrandr
          libffi
          gccNGPackages.libgfortran
          libxcrypt-legacy
          ncurses
          readline
          expat
          bzip2
          xz
          zstd
          libarchive
          curl
          krb5
          libiconv
          libintl
          pcre2
          freetype
          pixman
          libSM
          libICE
          libXau
          libXdamage
          libXcomposite
          libXScrnSaver
          libselinux
          fontconfig
          dbus
          glib
          libuuid
          git
          ghostty.terminfo
          # 根据 pixi 运行时可能需要的依赖，可以在这里补充，例如：
          # glibc
          # zlib
        ];
        /*extraBwrapArgs = [
          "--dir" "/run/opengl-driver"
          "--dir" "/run/opengl-driver-32"
          "--ro-bind" "/run/opengl-driver" "/run/opengl-driver"
          "--ro-bind" "/run/opengl-driver-32" "/run/opengl-driver-32"
          ];*/
        profile = ''
                export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib:$LD_LIBRARY_PATH"
              '';
        }
  )];
}
