{ pkgs, config, lib, ...}:
{
  programs.clash-verge = {
    enable = true;
    package = pkgs.pkgs.clash-verge-rev;
    tunMode = true;
    serviceMode = true;
    autoStart = false;
  };
  boot.kernel.sysctl = {
  "net.ipv4.ip_forward" = 1;
  "net.ipv6.conf.all.forwarding" = 1;
};
services.resolved.enable = false;
networking.firewall.enable = false;
}
