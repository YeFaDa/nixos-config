{ config, lib, pkgs, inputs, ... }:
{
  # Use latest kernel.
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  # CachyOS BORE + LTO + zen4 内核（7845HX）。pinned overlay 用 fork 预构建产物，命中 attic 缓存。
  nixpkgs.overlays = [
    inputs.nix-cachyos-kernel.overlays.pinned
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
    # 本地包 deepseek-harness（DeepSeek 开源 agent harness，dsh CLI），定义在 pkgs/deepseek-harness/package.nix
    (final: prev: {
      deepseek-harness = final.callPackage ./pkgs/deepseek-harness/package.nix { };
    })
  ];
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-zen4;
  # 让 ACPI 固件认为系统是 Windows 11（ACPI _OSI "Windows 2020"）
  boot.kernelParams = [ ''"acpi_osi=Windows 2020"'' ];
  # zenergy：AMD Zen 功耗传感器内核模块（k10temp 不暴露 power1_average）。
  # 装好后 MangoHud 就能读到 CPU 功耗。
  boot.extraModulePackages = [ config.boot.kernelPackages.zenergy ];
  boot.kernelModules = [ "zenergy" ];
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
#iwd作为后端
  networking.wireless.enable = false;
  networking.firewall.enable = false;
  networking.networkmanager.wifi.backend = "iwd";
  #host设置#
  networking.extraHosts = ''
  20.205.243.166 github.com
  # 你可以在这里写注释
'';
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
hardware.nvidia = {
  # nvidia-open 610.57.04 与 cachyos 内核的兼容补丁（7.1.6 和 7.1.8 都需要，头文件同样缺 const 修复）：
  # 1. gpio_device_get_chip：cachyos 头文件参数为非 const，调用处强转
  # 2. -Werror=format-security：panic() 和 dmem_cgroup_register_region() 传变量当格式串
  package = let
    nvidia = config.boot.kernelPackages.nvidiaPackages.latest;
  in nvidia // {
    open = nvidia.open.overrideAttrs (old: {
      postPatch = (if old ? postPatch && old.postPatch != null then old.postPatch else "") + ''
        substituteInPlace kernel-open/common/inc/nv-linux.h \
          --replace 'gpio_device_get_chip(gdev)' 'gpio_device_get_chip((struct gpio_device *)gdev)'
        substituteInPlace kernel-open/nvidia/os-interface.c \
          --replace 'panic(bugCodeStr);' 'panic("%s", bugCodeStr);'
        substituteInPlace kernel-open/nvidia/os-interface.c \
          --replace 'dmem_cgroup_register_region(size, name)' 'dmem_cgroup_register_region(size, "%s", name)'
      '';
    });
  };
	modesetting.enable = true;
	open = true;
	nvidiaSettings = true;
	powerManagement.enable = true;
	# 启用 nvidia-powerd：Dynamic Boost 让独显能用到满 TGP（当前被锁 50W → 应到 115W）
	dynamicBoost.enable = true;
};


#门户设置
xdg.portal = {
  enable = true;
  # 强制让 niri 优先调用 gnome 后端处理核心请求
  config.common.default = [ "gnome" "gtk" ];

  extraPortals = [
    pkgs.xdg-desktop-portal-gnome
    pkgs.xdg-desktop-portal-gtk
  ];
};
#启用非自由软件
hardware.enableRedistributableFirmware = true;
nixpkgs.config.allowUnfree = true;
#用户设置
users.users.yz = {
	extraGroups = [ "video" "wheel" "networkmanager" "render" "storage" "network" "libvirtd" "kvm" ];
  #shell = pkgs.fish;
};
#greeted设置
/*services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # 选择一个合适的 greeter（登录界面）
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember-session --remember";
        user = "greeter";
      };
    };
  };*/

####软件安装
  # programs.firefox.enable = true;
programs.firefox.enable = true;
programs.firefox.languagePacks = ["zh-CN" ];
programs.niri.enable = true;
programs.fish.enable = true;

hardware.brillo.enable = true;
security.polkit.enable = true;
security.soteria.enable = true;
programs.localsend.enable = true;
services.udisks2.enable = true;
services.gvfs.enable = true;
#programs.obs-studio.enable = true;
services.dbus.enable = true;



environment.systemPackages = with pkgs; [
  kitty
  qq
  wechat
  git
  lutris
  protonplus
  mangohud
  mangojuice
  xwayland-satellite
  google-chrome
  zed-editor
  nixd
  nil
  nh # nix-helper: better nixos-rebuild CLI with full build logs
  nautilus
  xdg-user-dirs
  bilibili
  fastfetch
  btop
  ww-manager
  deepseek-harness
  starship
  #tuigreet
  bluez
  kdePackages.qt6ct
  adw-gtk3
  nwg-look
  qemu
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
nix.settings.experimental-features = [ "nix-command" "flakes" ];
nix.settings.substituters = [ "https://mirrors.ustc.edu.cn/nix-channels/store" "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" ];
# CachyOS 内核二进制缓存（xddxdd/nix-cachyos-kernel，master 构建在此缓存）
nix.settings.extra-substituters = [ "https://attic.xuyh0120.win/lantian" ];
nix.settings.extra-trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
}
