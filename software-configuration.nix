{ config, lib, pkgs, inputs, ... }:
{
  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # CachyOS BORE + LTO + zen4 内核（7845HX）。pinned overlay 用 fork 预构建产物，命中 attic 缓存。
  nixpkgs.overlays = [
    # 本地包 ww-manager（鸣潮 CLI 管理器），定义在 pkgs/ww-manager。
    # 与上游 nixpkgs PR（python3Packages.ww-manager）同款接线：
    # 包进 python3 包集合（callPackage 自动填全部 python 参数），顶层用 toPythonApplication 暴露。
    (final: prev: {
      python3 = prev.python3.override {
        packageOverrides = pfinal: pprev: {
          ww-manager = pfinal.callPackage ./pkgs/ww-manager { };
        };
      };
      ww-manager = final.python3.pkgs.toPythonApplication final.python3.pkgs.ww-manager;
    })
    # 本地包 wechat-bin：把微信官方 Linux .deb 重打包（4.1.13.23，直接拉 dldir1，
    # 不像 nixpkgs 的 wechat 那样固定在 web.archive 的 4.1.1.x 上）。
    # 依赖表照 AUR wechat-bin；libffmpeg.so 同名遮蔽和 XKB_CONFIG_ROOT 两个坑见 pkgs/wechat-bin/default.nix。
    (final: prev: {
      wechat-bin = final.callPackage ./pkgs/wechat-bin { };
    })
    # 本地包 zcode：NUR 的 zcode 3.16.2 随 nix profile 迁入后，其锁定的
    # NUR rev 已找不到活的 deb 源（3.12.3 的 URL 404），且 NUR 新架构
    # （repos.json 按需拉作者仓库）不适合直接 follows。这里按原 NUR 包
    # 的依赖表逆向 vendor，用系统 nixpkgs 构建。
    (final: prev: {
      zcode = final.callPackage ./pkgs/zcode { };
    })
    # 本地包 alter-zero：上游只发预编译二进制，依赖面仅 glibc/libgcc，
    # 用 autoPatchelfHook 接入系统 nixpkgs；定义见 pkgs/alter-zero。
    (final: prev: {
      alter-zero = final.callPackage ./pkgs/alter-zero { };
    })
    # 本地包 workbuddy：腾讯 CodeBuddy 桌面版，官方 deb 重打包（原 ~/workbuddy-nix）。
    # 自带 Electron + 官方 app.asar；默认删 resources/runtime（约 595 MB），
    # Nix store 内 chrome-sandbox 无法 setuid，默认加 --no-sandbox。
    (final: prev: {
      workbuddy = final.callPackage ./pkgs/workbuddy { };
    })
    # Kimi Code 本地补丁：上游在 OpenCode Go 端点不会发 x-opencode-session。
    # 请求入口在 packages/core/src/llm/generate.ts；补丁在该文件解析 endpoint
    # 时用会话 cacheKey 动态注入该头，一份补丁即可同时覆盖 openai-responses 与
    # chat/completions；仅对 opencode.ai 的 /zen/go/v1 端点生效。
    /*(final: prev: {
      kimi-code = inputs.kimi-code.packages.x86_64-linux.default.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./pkgs/kimi-code/opencode-session.patch ];
      });
    })*/
    # niri-glass：不使用 niri-glass flake 自带的包（它锁死 niri@49fc611 + 自己的 nixpkgs），
    # 改为把它的 8 个补丁文件叠加到本机 nixpkgs 的 niri（v26.04）源码上，
    # 用本机 rustc 和依赖集构建。补丁只覆盖源码、不动 Cargo.lock，vendor hash 不变。
    /*(final: prev: {
      niri-glass = prev.niri.overrideAttrs (old: {
        pname = "niri-glass";
        postPatch = (old.postPatch or "") + ''
          echo "==> Applying Niri-glass liquid-glass overlay"
          chmod -R u+w src/render_helpers niri-config/src
          cp --no-preserve=mode ${inputs.niri-glass}/src/render_helpers/liquid_glass.rs src/render_helpers/liquid_glass.rs
          cp --no-preserve=mode ${inputs.niri-glass}/src/render_helpers/background_effect.rs src/render_helpers/background_effect.rs
          cp --no-preserve=mode ${inputs.niri-glass}/src/render_helpers/framebuffer_effect.rs src/render_helpers/framebuffer_effect.rs
          cp --no-preserve=mode ${inputs.niri-glass}/src/render_helpers/xray.rs src/render_helpers/xray.rs
          cp --no-preserve=mode ${inputs.niri-glass}/src/render_helpers/mod.rs src/render_helpers/mod.rs
          cp --no-preserve=mode ${inputs.niri-glass}/src/render_helpers/shaders/clipped_surface.frag src/render_helpers/shaders/clipped_surface.frag
          cp --no-preserve=mode ${inputs.niri-glass}/src/render_helpers/shaders/mod.rs src/render_helpers/shaders/mod.rs
          cp --no-preserve=mode ${inputs.niri-glass}/niri-config/src/appearance.rs niri-config/src/appearance.rs
        '';
      });
    })*/
    # NUR（qoder-cn / zcode）：overlay 让这些包用本 nixpkgs 实例评估构建，
    # stdenv/glibc 与系统一致；input 定义（含 follows）见 flake.nix。
    inputs.nur.overlays.default
  ];
  #boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-zen4;
  # 休眠（hibernate）恢复：swapfile 在根分区 @swap 子卷里，这里写"分区"而不是文件路径。
  # 还必须在 boot.kernelParams 里配 resume_offset（swapfile 才需要），见下方。
  boot.resumeDevice = "/dev/disk/by-uuid/636e2f55-6c8e-48b4-8fda-05095668387d";
  # 让 ACPI 固件认为系统是 Windows 11（ACPI _OSI "Windows 2020"）
  # pcie_aspm=off / nvme_core.default_ps_max_latency_us=0：
  # 本机固件只暴露 s2idle，PCIe ASPM 和 NVMe APST 会在 s2idle 进出时把链路拖死，
  # 独显直连（内屏挂 dGPU）下的表现就是按电源键没有任何反应。
  # nvidia.NVreg_EnableS0ixPowerManagement=1：s2idle 下必须让 NVIDIA 走 S0ix 电源管理，
  # 否则挂起进得去出不来。不能写成 hardware.nvidia.powerManagement.finegrained，
  # 那个选项带断言"需要 PRIME offload"，本机独显直连会 eval 失败。
  # 验证：cat /proc/driver/nvidia/gpus/*/power → S0ix Power Management: Status: Enabled
  # resume_offset：swapfile 恢复用，值取自
  #   sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
  # 前提是 boot.resumeDevice 指向该 swapfile 所在分区（见上方）。
  # 重建 swapfile 后这个偏移会变，需重新取。
  # 回退：删掉后四行再 nixos-rebuild switch 即可。
  # TemporaryFilePath：VRAM 落盘位置，默认 /tmp，NVIDIA 建议换到 /var/tmp（Arch 同款）。
  # 不要动 UseKernelSuspendNotifiers：615 的 open 模块默认就是 1（内核挂起通知器），
  # 595+ 上游就是用这条路径取代 nvidia-suspend/resume 服务的。
  # 2026-09-29 的 hibernate 能成，靠的就是它；2026-10-20 把它关成 0 之后，
  # hibernate 阶段没有机制通知驱动，从 S4 回来 GPU 直接 FULLCHIP_RESET。
  boot.kernelParams = [
    ''"acpi_osi=Windows 2020"''
    "pcie_aspm=off"
    "nvme_core.default_ps_max_latency_us=0"
    "nvidia.NVreg_EnableS0ixPowerManagement=1"
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
    "resume_offset=533760"
  ];
  # 合盖：先 s2idle 快睡，HibernateDelaySec 到点自动转休眠。
  # 2026-09-29 验证过这条路能完整走通（s2idle → 转 hibernate → 7.8 小时后恢复）。
  systemd.sleep.settings.Sleep.HibernateDelaySec = "30min";
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
  # 注意：改用内核挂起通知器（powerManagement.kernelSuspendNotifier = true）后，
  # NixOS 不再生成 nvidia-suspend / nvidia-resume / nvidia-hibernate 这三个 unit，
  # 所以这里不能（也不需要）再给它们补 before/wantedBy —— 给不存在的服务设属性
  # 会造出没有 ExecStart 的空 unit。
  # 2026-10-29：s2idle 实测恢复失败（现有日志 10-25 起唯一一次睡眠，无成功基线）。
  # 16:11:27 `systemctl suspend`（logind 记到 PID 2536 'systemctl'）→ 16:11:28 进入 s2idle；
  # 17:27:09 唤醒时 NVIDIA 615.78.08 open 模块 GC6 退出失败：
  #   GSP-FMC Error error code=0x83d
  #   gpuPowerManagementResume: GSP boot failed at resume (bootMode 0x2): 0x55
  #   _gpuGc6ExitStateLoad: GPU is unable to transition from GC6 to D0 state
  # nv_set_system_power_state 触发 WARNING 后 GSP 超时、寄存器读坏；17:27:57 日志
  # 无 shutdown 序列直接中断，user journal 损坏，17:28:57 冷启动（reset reason
  # 0x00200800 = ACPI power state transition）→ 判定为强制断电。
  # 结论：S0ix=1 的 GC6 退出路径在 615.78.08 上不可用；不是 resume_offset 问题
  # （每次启动都会报 "PM: Image not found"，属正常探测）。
  # 待验证：① 切回 stable 595.104.02 重测 s2idle（615 是 10 月下旬才换上的变量）；
  # ② 若留在 615，唯一可试的是关 S0ix PM，但旧记录称关了唤不醒，属实验；
  # ③ 修好前合盖 suspend-then-hibernate 也别用：30 分钟后转休眠要经同一条 GC6 退出路径。
  # offset 复核（应为 533760）：sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
  # zenergy：AMD Zen 功耗传感器内核模块（k10temp 不暴露 power1_average）。
  # 装好后 MangoHud 就能读到 CPU 功耗。
  # 新 nixpkgs 在内核 dev 树里保留了 System.map，7.3 的 modules_install 因此
  # 真的会跑 depmod，zenergy 自带的 modules.* 与内核模块树合并时冲突
  # （buildEnv exit 25）。DEPMOD=true 跳过这一步；aggregateModules 合并后
  # 本来就会统一重跑 depmod，索引不会缺。
  boot.extraModulePackages = [
    (config.boot.kernelPackages.zenergy.overrideAttrs (old: {
      makeFlags = old.makeFlags ++ [ "DEPMOD=true" ];
    }))
  ];
  boot.kernelModules = [ "zenergy" "ntsync" ];
  # scx_lavd in Gaming mode（= --performance，与 CachyOS 的 gaming_mode 相同）
  # nixpkgs 已移除 services.scx，改为 scx_loader；default_mode 固定为 Gaming，
  # 保持开机即按 gaming 参数运行（原 extraArgs 迁到 scheds.scx_lavd.gaming_mode）。
  services.scx-loader = {
    enable = true;
    config = {
      default_sched = "scx_lavd";
      default_mode = "Gaming";
      scheds.scx_lavd.gaming_mode = [
        "--performance"
        "--pinned-slice-us"
        "500"
      ];
    };
  };
#Wi-Fi 后端：改用 wpa_supplicant（荣耀分享走互传联盟 MTA 时需要 Wi-Fi Direct(P2P)；
#iwd 的 P2P 支持不完整，NM 里只会暴露一个虚拟 p2p 占位设备，nmcli 也没有
#`device wifi-p2p` 子命令）。连接配置文件是 keyfile，与后端无关，切换后会自动重连。
#注意：NM 模块在 wpa_supplicant 后端下会自己把 networking.wireless.enable 置为 true
#（= NixOS 的 wpa_supplicant 走 dbusControlled 模式，由 NM 通过 D-Bus 控制它），
#所以这里**不能**再写 networking.wireless.enable = false，否则选项定义冲突、eval 直接失败。
#原先那行 `= false` 是配合 iwd 后端用的，随本次切换一并移除。
#回退：改回 "iwd" 并重新加上 networking.wireless.enable = false; 再 nixos-rebuild switch。
  networking.networkmanager.wifi.backend = "wpa_supplicant";
  networking.networkmanager.wifi.powersave = false;
  networking.firewall = {
    enable = true;
    # TUN 网卡名由 FlClash 自己定的，就叫 FlClash（区分大小写）
    trustedInterfaces = [ "FlClash" "ASGAME" ];
    # SSH 的 22 端口只对无线/有线这两块物理网卡开（见文件末尾的 services.openssh）。
    # 不用 services.openssh.openFirewall：那个写法对**所有**网卡开 22，
    # 包括荣耀分享的 p2p-wlan0-0/1 热点和 libvirt 的 virbr0，多余的暴露面没必要留。
    # 网卡名由 systemd predictable naming 从 PCI 路径生成，同型号硬件上稳定。
    # 以后插 USB 网卡或改用其他接口，记得往这里加，否则 SSH 连不上。
    interfaces = {
      wlp2s0.allowedTCPPorts = [ 22 ];
      enp4s0.allowedTCPPorts = [ 22 ];
    };
  };
  #host设置#
  security.pki.caCertificateBlacklist = [
      "Comodo AAA Services root"
    ];
  #本土化设置
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "zh_CN.UTF-8/UTF-8" ];
  #networking.proxy.default = "http://127.0.0.1:7897";

  #fcitx5输入法
i18n.inputMethod = {
	type = "fcitx5";
	enable = true;
	fcitx5.addons = with pkgs; [
		qt6Packages.fcitx5-chinese-addons
		fcitx5-rime
		qt6Packages.fcitx5-configtool
		fcitx5-gtk
		qt6Packages.fcitx5-qt
	];
};
#蓝牙设置
hardware.bluetooth.enable = true;
#zram虚拟内存
zramSwap.enable = true;
zramSwap.algorithm = "zstd";
zramSwap.memoryPercent = 50;
#amd和nvidia驱动
services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];
hardware.graphics = {
	enable = true;
	enable32Bit = true;
};
/*hardware.nvidia = {
  # NVIDIA 开源模块直接使用与当前 CachyOS 内核匹配的驱动包。
  branch = "bleeding_edge";
  # CachyOS 内核 flake 只在 nvidiaPackages.latest 上打了 nvidia-open 的修复补丁
  # （见 kernel-cachyos/packages.nix 的 "Fix NVIDIA open module build failure"），
  # bleeding_edge / new_feature 没有：610.57.04 的
  # __to_hwgpio(const struct gpio_device *gdev, ...) 把 const 指针传给了形参非 const 的
  # gpio_device_get_chip()，撞上 6.15+ 内核无条件启用的
  # -Werror=incompatible-pointer-types（CONFIG_WERROR 关着也没用），
  # nvidia-open 的 24 个 .o 全部编译失败，进而 nvidia-open → linux modules →
  # nixos-system 逐级失败。
  # 所以这里显式指定 bleeding_edge + 同款补丁。补丁后内核模块的 drv 与 latest 的
  # 完全相同（/nix/store/4i0mxkgj7x43z95v6s88i9kms0841nxw-nvidia-open-610.57.04-7.2.4.drv，
  # store 里已构建好），userspace 包 drv 也不变，都不会触发重新编译。
  # 注意：NVIDIA 上游修好这个 const 后，--replace-fail 会因找不到原串而报错，
  # 届时删掉这段 package override（回到只用 branch）即可。
  package = let
    pkg = config.boot.kernelPackages.nvidiaPackages.bleeding_edge;
    nvidiaOpen = pkg.open.overrideAttrs (mod: {
      postPatch = (mod.postPatch or "") + ''
        substituteInPlace kernel-open/common/inc/nv-linux.h \
          --replace-fail \
            "static inline int __to_hwgpio(const struct gpio_device *gdev," \
            "static inline int __to_hwgpio(struct gpio_device *gdev,"
      '';
    });
  in
  pkg.overrideAttrs (old: {
    passthru = old.passthru // { open = nvidiaOpen; };
  });
	modesetting.enable = true;
	...（其余不变）*/
hardware.nvidia = {
  # 2026-10-21：615.78.08 的用户态二进制（nvidia-powerd / nvidia-smi /
  # nvidia-cuda-mps-control）启动即在 dl_main 段错误，dynamicBoost 因此激活失败
  # （switch-to-configuration exit 4）。
  # 2026-10-29 复核：当前代际 615.78.08 下 nvidia-smi 正常、nvidia-powerd active，
  # 10-21 的段错误未再复现（power.limit 仍报 N/A，Dynamic Boost 实际档位未验证）。
  # 注意 nixpkgs 的分支算法（nvidia-x11/default.nix）：
  #   latest        = max(production, new_feature) = max(595.104.02, 615.78.08) = 615.78.08
  #   bleeding_edge = max(latest, beta)                                        = 615.78.08
  # 两者是同一枚坏二进制，切来切去没用。只有 stable（= production = 595.104.02）
  # 才躲得开。等 NVIDIA 修好 615 再换回来。
  branch = "bleeding_edge";
	modesetting.enable = true;
	open = true;
	nvidiaSettings = true;
	powerManagement.enable = true;
	# 用内核挂起通知器：615 的 open 模块默认就是这条路径，也是 595+ 上游推荐的。
	# 它会取代 nvidia-suspend/resume/hibernate 三个 systemd 服务
	# （nvidia.nix 的生成条件是 powerManagement.enable && !kernelSuspendNotifier）。
	# 2026-09-29 的 hibernate 能成正是走这条；10-20 误设成 false 退回服务路径后，
	# hibernate 阶段没人通知驱动，S4 恢复后 GPU 直接 FULLCHIP_RESET。
	powerManagement.kernelSuspendNotifier = true;
	# 关键项 NVreg_EnableS0ixPowerManagement=1 见文件上方 boot.kernelParams：
	# 本机固件只暴露 s2idle，NVIDIA 要求 s2idle 下必须开 S0ix 电源管理，否则唤不醒。
	# 不能写成 powerManagement.finegrained：该选项带断言
	# "Fine-grained power management requires offload to be enabled"，
	# 本机独显直连、没有 PRIME offload，会直接 eval 失败。
	# 启用 nvidia-powerd：Dynamic Boost 让独显能用到满 TGP（当前被锁 50W → 应到 115W）
	dynamicBoost.enable = true;
};


#门户设置
/*xdg.portal = {
  enable = true;
  # 强制让 niri 优先调用 gnome 后端处理核心请求
  config.common.default = [ "gnome" "gtk" ];

  extraPortals = [
    pkgs.xdg-desktop-portal-gnome
    pkgs.xdg-desktop-portal-gtk
  ];
  };*/

#启用非自由软件
hardware.enableRedistributableFirmware = true;
nixpkgs.config.allowUnfree = true;
#用户设置
users.users.yz = {
	extraGroups = [ "video" "wheel" "networkmanager" "render" "storage" "network" "libvirtd" "kvm" "plugdev" ];
  #shell = pkgs.fish;
};
#greetd 登录界面配置已移至 noctalia.nix（noctalia-greeter）

####软件安装
  # programs.firefox.enable = true;
programs.firefox.enable = true;
programs.firefox.languagePacks = [ "zh-CN" ];
programs.google-chrome.enable = true;

#niri-glass（补丁叠在 nixpkgs 的 niri 上，overlay 定义见本文件顶部）
programs.niri.enable = true;
#programs.niri.package = pkgs.niri-glass;


programs.fish.enable = true;

hardware.brillo.enable = true;
security.polkit.enable = true;
security.rtkit.enable = true;
security.soteria.enable = true;
programs.localsend.enable = true;
services.udisks2.enable = true;
services.gvfs.enable = true;
#programs.obs-studio.enable = true;
services.dbus.enable = true;




environment.systemPackages = with pkgs; [
  kitty
  ghostty
  ghostty.terminfo
  qq
  wechat-bin
  git
  lutris-free
  protonplus
  mangohud
  mangojuice
  xwayland-satellite
  #google-chrome
  zed-editor
  nixd
  #nil
  nixfmt
  nh # nix-helper: better nixos-rebuild CLI with full build logs
  nautilus
  xdg-user-dirs
  bilibili
  fastfetch
  btop
  nodejs_24
  ww-manager
  starship
  nomacs
  #tuigreet
  bluez
  kdePackages.qt6ct
  adw-gtk3
  nwg-look
  qemu
  file-roller
  #usbutils
  xwayland
  wpsoffice-cn

  inputs.antigravity-nix.packages.x86_64-linux.default

  # —— 2026-10-21 自 nix profile 迁入 ——
  # 背景：profile 时代每个来源各钉各的 nixpkgs（光 registry 的 flake:nixpkgs
  # 就有八九枚不同的锁），机器上同时活着 glibc 2.42/2.44 多个世代。Electron
  # 应用进程里加载着旧 libm，dlopen 系统 mesa 26.2.5 的 dri_gbm.so 时
  # GLIBC_2.43 not found → MESA-LOADER 报错、硬件加速全丢。
  # 现在全部收进系统 flake：nixpkgs 包直接用系统实例，外部包走 follows。
  # 外部 flake 包（input 均已 inputs.nixpkgs.follows，见 flake.nix）
  inputs.codex-desktop-linux.packages.x86_64-linux.default
  inputs.llm-agents.packages.x86_64-linux.opencode2
  inputs.llm-agents.packages.x86_64-linux.prime-agent
  inputs.omp-nix.packages.x86_64-linux.default
  # Kimi Code CLI 已加本地补丁（见上方 overlay 与 pkgs/kimi-code）
  # kimi-code
  # NUR 包（经上方 nixpkgs.overlays 的 inputs.nur.overlays.default 进入 pkgs.nur）
  nur.repos.Sittymin.qoder-cn
  # zcode 已 vendor 到 pkgs/zcode（见上方 overlay）
  zcode
  # alter-zero 已 vendor 到 pkgs/alter-zero（见上方 overlay）
  #alter-zero
  # workbuddy 已 vendor 到 pkgs/workbuddy（见上方 overlay）
  workbuddy
  # 以下原为 registry nixpkgs 包（各自锁过不同的 nixpkgs），统一到系统实例
  android-tools
  antiword
  bbe
  binutils
  capitaine-cursors
  pkgsCross.aarch64-multiplatform.stdenv.cc
  pkgsCross.aarch64-multiplatform.musl.stdenv.cc
  discord
  ffmpeg
  fluffychat
  gpu-screen-recorder
  #hmcl
  iw
  libxml2
  # mpv-with-scripts 属性已被上游移除，现用 mpv（同 0.41.0；脚本需要时
  # 可用 pkgs.mpvScripts.* 自行拼）
  mpv
  openjdk21
  paper-icon-theme
  papirus-icon-theme
  patchelf
  pnpm
  poppler-utils
  python3
  qogir-icon-theme
  radare2
  telegram-desktop
  #temurin-bin-17
  #temurin-bin-21
  #temurin-bin-25
  unzip
  uv
  winetricks
  zig
  # 注：profile 里的 temurin-bin-21-1 与 temurin-bin-21 是同一个 store 路径
  # （不同锁装了两遍），已去重。
];
#字体设置，不用改了
fonts = {
	fontDir.enable = true;
	packages = with pkgs; [
	#source-sans
	#source-serif
	source-han-sans
	source-han-serif
	noto-fonts
  noto-fonts-cjk-sans
  noto-fonts-cjk-serif
	noto-fonts-color-emoji
	nerd-fonts.jetbrains-mono
];
fontconfig.defaultFonts = {
	emoji = [ "Noto Color Emoji" ];
	monospace = [ "JetBrainsMono Nerd Font" ];
	serif = [ "Source Han Serif SC" "Noto Serif CJK SC" "DejaVu Serif" ];
  sansSerif = [ "Source Han Sans SC" "Noto Sans CJK SC" "DejaVu Sans" ];
  };

};
#ssh
# ⚠️ 迁移顺序（现在还没 rebuild，所以线上还是密码登录，暂时是安全的）：
# 本机 ~/.ssh 目录和 authorized_keys 都不存在，密码是当前唯一入口。
# 下面把密码认证关掉了，所以必须按顺序做完再 nixos-rebuild switch，否则会把自己锁在外面：
#   1. 在**客户端**机器上 `ssh-keygen -t ed25519` 生成密钥（不要在本机生成）
#   2. 把客户端的公钥内容写进本机 ~/.ssh/authorized_keys
#      （本机执行：mkdir -p ~/.ssh && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys）
#   3. 从客户端实测 `ssh yz@<本机IP>` 能免密登进来（一定要真的连成功一次）
#   4. 确认无误，再 sudo nixos-rebuild switch
# 应急回退：万一 3 失败，本机本地登录后把 AuthenticationMethods 那行删掉 rebuild 即可。
services.openssh = {
  enable = true;
  openFirewall = false; # 改用上面 networking.firewall.interfaces，只对 wlp2s0/enp4s0 开
  settings = {
    PermitRootLogin = "no";
    # 白名单：只有这一个账号能发起 SSH 会话，爆破时连"试哪个用户"这步都省了
    AllowUsers = [ "yz" ];
    # 一刀切成公钥认证。注意：只写 PasswordAuthentication = false 是**关不掉密码**的——
    # KbdInteractiveAuthentication 和 UsePAM 默认都是 yes，sshd 的 PAM 线程照样走
    # keyboard-interactive 把密码验掉。用 AuthenticationMethods 从入口处封死所有非公钥方式。
    AuthenticationMethods = "publickey";
    # 单连接内最多试 3 次（默认 6）。爆破脚本常按默认值卡着来，压到 3 直接废掉一半效率
    MaxAuthTries = 3;
    # 未认证连接 30s 内没完成握手就断开，压缩暴力破解能复用的空闲连接数
    LoginGraceTime = 30;
    # MaxStartups = "5:30:10" 未认证并发连接限速（10 个以下正常，之后按比例随机丢）。
    # 默认 10:30:100 在公网上太宽松了，但调太低会影响正常并发，先不启用，需要再说。
    #
    # 下面这行能彻底关掉 IPv6 监听（sshd 不再 bind [::]:22）。本机 wlp2s0 上挂着
    # 2001:da8:7013:... 的公网可路由 IPv6（CERNET 教育网），走 IPv6 端口是对着公网开的，
    # 关掉最省事。**但如果客户端在同一 /64 内会优先用 IPv6 连，会连不上**，所以默认注释。
    # 真要断掉公网入口，优先考虑 Tailscale 而不是这个。
    # AddressFamily = "inet";
  };
};

nix.settings.trusted-users = [ "root" "yz" ];

nix.settings.experimental-features = [ "nix-command" "flakes" ];
nix.settings.substituters = [ "https://mirrors.ustc.edu.cn/nix-channels/store" "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" "https://cache.nixos.org" ];
# CachyOS 内核二进制缓存（xddxdd/nix-cachyos-kernel/release 构建在此缓存）
# noctalia 官方 cachix 缓存（noctalia-greeter 等直接下二进制，不用源码编译）
nix.settings.extra-substituters = [ "https://noctalia.cachix.org" ];
nix.settings.extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
}
