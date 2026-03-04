{ config, pkgs, ... }:

{
  # 注意修改这里的用户名与用户目录
  home.username = "yz";
  home.homeDirectory = "/home/yz";
  home.stateVersion = "25.11";

  imports =
    [ # Include the results of the hardware scan.
      ./home-modules/kitty.nix
      ./home-modules/vscode.nix
    ];
}
