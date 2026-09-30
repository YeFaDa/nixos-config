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
    # niri-glass：不使用 niri-glass flake 自带的包（它锁死 niri@49fc611 + 自己的 nixpkgs），
    # 改为把它的 8 个补丁文件叠加到本机 nixpkgs 的 niri（v26.04）源码上，
    # 用本机 rustc 和依赖集构建。补丁只覆盖源码、不动 Cargo.lock，vendor hash 不变。
    (final: prev: {
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
    })
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
  boot.kernelParams = [
    ''"acpi_osi=Windows 2020"''
    "pcie_aspm=off"
    "nvme_core.default_ps_max_latency_us=0"
    "nvidia.NVreg_EnableS0ixPowerManagement=1"
    "resume_offset=533760"
  ];
  # 挂起转休眠（suspend-then-hibernate）：先 s2idle 快睡，HibernateDelaySec 到点自动落盘
  # 休眠，合盖放一整天也不掉电。配套把合盖行为也改成 suspend-then-hibernate。
  # 注：旧写法 systemd.sleep.extraConfig 在本版 nixpkgs 已改名为 settings.Sleep。
  systemd.sleep.settings.Sleep.HibernateDelaySec = "30min";
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
  # 走 suspend-then-hibernate 时补的绑定。注意：只绑 suspend/resume，不要绑 hibernate。
  # systemd-suspend-then-hibernate.service 是独立单元，不经过 systemd-suspend.service，
  # 而 NixOS/NVIDIA 生成的 unit 只绑定了后者，所以必须显式补上，否则 NVIDIA 的
  # 挂起准备不执行，s2idle 阶段直接唤不醒（2026-09-26 实测）。
  # 反过来 nvidia-hibernate 不能绑：suspend-then-hibernate 的 VRAM 在 suspend 阶段
  # 已存进系统内存，会随内存一起落盘，不需要再单独跑 hibernate；两个都跑会让
  # /proc/driver/nvidia/suspend 被连写两次（2026-09-28 实测 hibernate 先于 suspend），
  # 驱动状态错乱 → 进 s2idle 7 秒后 GSP RPC timeout（Xid 119），恢复后屏幕不亮。
  systemd.services.nvidia-suspend = {
    before = [ "systemd-suspend-then-hibernate.service" ];
    wantedBy = [ "systemd-suspend-then-hibernate.service" ];
  };
  systemd.services.nvidia-resume = {
    after = [ "systemd-suspend-then-hibernate.service" ];
    wantedBy = [ "systemd-suspend-then-hibernate.service" ];
  };
  # zenergy：AMD Zen 功耗传感器内核模块（k10temp 不暴露 power1_average）。
  # 装好后 MangoHud 就能读到 CPU 功耗。
  boot.extraModulePackages = [ config.boot.kernelPackages.zenergy ];
  boot.kernelModules = [ "zenergy" "ntsync" ];
  # scx_lavd in Gaming mode（= --performance，与 CachyOS 的 gaming_mode 相同）
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
    extraArgs = [
      "--performance"
      "--pinned-slice-us"
      "500"
    ];
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
  # NVIDIA 开源模块直接使用与当前 CachyOS 内核匹配的驱动包。
  branch = "bleeding_edge";
	modesetting.enable = true;
	open = true;
	nvidiaSettings = true;
	powerManagement.enable = true;
	# 595+ 起在 open 模块下默认为 true，后果是 nvidia-suspend / nvidia-resume 两个 unit
	# 整个不再生成（nvidia.nix 里的条件是 powerManagement.enable && !kernelSuspendNotifier）。
	# 本机固件只有 s2idle，走内核 notifier 会进得去回不来，所以退回 systemd 服务路径。
	powerManagement.kernelSuspendNotifier = false;
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
programs.niri.package = pkgs.niri-glass;


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
  #tuigreet
  bluez
  kdePackages.qt6ct
  adw-gtk3
  nwg-look
  qemu
  file-roller
  #usbutils
  xwayland
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

nix.settings.experimental-features = [ "nix-command" "flakes" ];
nix.settings.substituters = [ "https://mirrors.ustc.edu.cn/nix-channels/store" "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" "https://cache.nixos.org" ];
# CachyOS 内核二进制缓存（xddxdd/nix-cachyos-kernel/release 构建在此缓存）
# noctalia 官方 cachix 缓存（noctalia-greeter 等直接下二进制，不用源码编译）
nix.settings.extra-substituters = [ "https://noctalia.cachix.org" "https://attic.xuyh0120.win/lantian?priority=1000" ];
nix.settings.extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
}
