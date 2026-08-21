{ inputs, ... }:
{
  imports = [
    inputs.noctalia.nixosModules.default
    inputs.noctalia-greeter.nixosModules.default
  ];

  programs.noctalia = {
    enable = true;

    # Enables NetworkManager, Bluetooth, UPower, and a power profile service.
    recommendedServices.enable = true;
  };

  # 登录界面：noctalia-greeter 模块会把 greeter 设为 greetd 的 default_session（vt1）
  # 这里显式启用 greetd；default_session 的 command/user 由模块管理，不要在这里覆盖
  #services.greetd.enable = true;
  # 想开机免密直接进 niri（跳过登录界面）的话，取消下面注释：
  # services.greetd.settings.initial_session = {
  #   command = "niri-session";
  #   user = "yz";
  # };

  programs.noctalia-greeter.enable = true;
}
