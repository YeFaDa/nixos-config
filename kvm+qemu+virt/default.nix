{ config, lib, pkgs, inputs, ... }:
{
#虚拟化：virt-manager + QEMU/KVM
programs.virt-manager.enable = true;
virtualisation.libvirtd.enable = true;
virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;
virtualisation.libvirtd.qemu.runAsRoot = true;
virtualisation.libvirtd.qemu.swtpm.enable = true;# TPM 支持（Win11 需要）
virtualisation.libvirtd.qemu.vhostUserPackages = [ pkgs.virtiofsd ];
virtualisation.spiceUSBRedirection.enable = true;
# 声明式启用 libvirt 默认网络的 autostart（上游模块无此选项，用 tmpfiles 在开机时建符号链接）
systemd.tmpfiles.rules = [
  "d /var/lib/libvirt/qemu/networks/autostart 0755 root root -"
  "L+ /var/lib/libvirt/qemu/networks/autostart/default.xml - - - - /var/lib/libvirt/qemu/networks/default.xml"
];
}
