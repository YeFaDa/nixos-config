{ config, lib, pkgs, ... }:
{
  boot.extraModulePackages = [ config.boot.kernelPackages.qc71_laptop ];
  boot.kernelModules = [ "qc71_laptop" ];

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
	];
};
#蓝牙设置
hardware.bluetooth.enable = true;
#amd和nvidia驱动
services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];
hardware.graphics = {
	enable = true;
	enable32Bit = true;
};
hardware.nvidia = {
  package = config.boot.kernelPackages.nvidiaPackages.production;
	modesetting.enable = true;
	open = true;
	nvidiaSettings = true;
	powerManagement.enable = true;
};
/*systemd.services.adjust-nvidia-backlight = {
  description = "根据 amdgpu_bl2 状态调整 nvidia_0 调光权限";

  # 挂载到 graphical.target 确保硬件驱动基本就绪
  wantedBy = [ "graphical.target" ];

  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    # 强制使用 root 权限执行
    User = "root";
    ExecStart = "${pkgs.writeShellScript "check-backlight" ''
      # 等待路径出现，最多等 5 秒
      for i in {1..5}; do
        if [ -d "/sys/class/backlight/nvidia_0" ]; then break; fi
        sleep 1
      done

      AMD_PATH="/sys/class/backlight/amdgpu_bl2"
      NVIDIA_FILE="/sys/class/backlight/nvidia_0/brightness"

      if [ -d "$AMD_PATH" ]; then
        echo "检测到 AMD 背光，屏蔽 NVIDIA 调光..."
        [ -f "$NVIDIA_FILE" ] && chmod 000 "$NVIDIA_FILE"
      else
        echo "未检测到 AMD 背光，开启 NVIDIA 权限..."
        [ -f "$NVIDIA_FILE" ] && chmod 666 "$NVIDIA_FILE"
      fi
    ''}";
  };
};*/

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
	extraGroups = [ "video" "wheel" "networkmanager" "render" "storage" "network" ];
  #shell = pkgs.fish;
};
#greeted设置
services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # 选择一个合适的 greeter（登录界面）
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember-session --remember";
        user = "greeter";
      };
    };
  };

####软件安装
  # programs.firefox.enable = true;
programs.firefox.enable = true;
programs.firefox.languagePacks = ["zh-CN" ];
programs.niri.enable = true;
programs.fish.enable = true;
programs.chromium.enable = true;

hardware.brillo.enable = true;
programs.light.enable = true;
security.polkit.enable = true;
security.soteria.enable = true;
programs.localsend.enable = true;
services.udisks2.enable = true;
services.gvfs.enable = true;
programs.obs-studio.enable = true;
services.dbus.enable = true;

environment.systemPackages = with pkgs; [
	#kitty
	fuzzel
	qq
	#wechat
	git
	xwayland-satellite
	google-chrome
	brightnessctl
	zed-editor
	wl-clipboard
	cliphist
	rofi
  nixd
  nautilus
  bilibili
  ntfs3g
  fastfetch
  starship
  tuigreet
  bluez
  kdePackages.qt6ct
  adw-gtk3
  nwg-look
];
#字体设置，不用改了
fonts = {
	fontDir.enable = true;
	packages = with pkgs; [
	source-sans
	source-serif
	source-han-sans
	source-han-serif
	noto-fonts-color-emoji
	nerd-fonts.jetbrains-mono
];
fontconfig.defaultFonts = {
	emoji = [ "Noto Color Emoji" ];
	monospace = [ "JetBrainsMono Nerd Font" ];
	sansSerif = [ "Source Han Sans SC" ];
	serif = [ "Source Han Serif Sc" ];
  };
};

}
