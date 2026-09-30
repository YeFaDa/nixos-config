# 荣耀分享 → 互传联盟(MTA) 互操作：系统侧准备
#
# 背景：荣耀 MagicOS 的分享面板除华为自家栈外还支持互传联盟(MTA)，
# 其协议栈为 BLE 广播/GATT → ECDH(P-256) → Wi-Fi Direct → HTTPS/WebSocket。
# 本文件只做系统侧必要准备，不含任何业务逻辑。
#
# 参考实现：https://github.com/Tinnci/cattysend   (Linux/Rust)
#           https://github.com/kmod-midori/CatShare (Android，协议来源)
{ config, lib, pkgs, ... }:

let
  bt = config.hardware.bluetooth;

  # 与 nixpkgs 的 nixos/modules/services/hardware/bluetooth.nix 保持一致，
  # 只额外插入 -E（实验性 D-Bus 接口）。上游默认等价于：
  #   ExecStart = [ "" "${package}/libexec/bluetooth/bluetoothd -f /etc/bluetooth/main.conf" ]
  #
  # 注意：bluez 5.87 的 /etc/bluetooth/main.conf 已经没有 Experimental 键，
  #       所以 hardware.bluetooth.settings.General.Experimental = true 是无效写法，
  #       只能通过命令行开关 -E 开启。
  bluetoothdArgs = [
    "-E" # 实验性 D-Bus 接口：LEAdvertisement1 的 ScanResponse* 属性
    "-f" "/etc/bluetooth/main.conf"
  ] ++ lib.optional (bt.disabledPlugins != [ ])
    "--noplugin=${lib.concatStringsSep "," bt.disabledPlugins}";
in
{
  # ① BLE：MTA 需要把设备名放进「扫描响应包」(Scan Response)，与主广播包分包发送。
  #    未开实验接口时 BlueZ 会把所有数据塞进主广播包 → 超过 31 字节 → 自动升级为
  #    Extended Advertising → 手机的分享面板搜不到这台设备。
  systemd.services.bluetooth.serviceConfig.ExecStart = lib.mkForce [
    ""
    "${bt.package}/libexec/bluetooth/bluetoothd ${lib.concatStringsSep " " bluetoothdArgs}"
  ];

  # ②-补充：若改用「自己起 wpa_supplicant / hostapd 管 P2P」的方案，
  #        取消下面注释让 NetworkManager 不去接管 P2P 接口。
  #        ⚠️ cattysend 走 NM 委托方案时不要取消注释（会让 NM 不再暴露 P2P 设备）。
  # networking.networkmanager.unmanaged = [
  #   "interface-name:p2p-dev-wlan0"
  #   "interface-name:p2p-wlan0-0"
  #   "interface-name:p2p-wlan0-1"
  # ];

  # ③ 防火墙：只放行 P2P 组接口上的传输端口。
  #    手机 → 本机（接收）不需要：我们作为客户端主动出站。
  #    本机 → 手机（发送）才需要：本机要做 HTTPS/WebSocket 服务端。
  #    8443 取自 MTA 的 P2pInfo.port 惯例；若实际协商成别的端口，改这里即可。
  networking.firewall.interfaces = {
    "p2p-wlan0-0".allowedTCPPorts = [ 8443 ];
    "p2p-wlan0-1".allowedTCPPorts = [ 8443 ];
  };
}
