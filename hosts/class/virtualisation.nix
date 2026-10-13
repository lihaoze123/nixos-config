{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.my.features.virtualMachines.enable {
    my.proxy.lanInterfaces = [ "virbr0" ];

    networking.firewall.interfaces."virbr0" = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    systemd.services.libvirt-default-network = {
      description = "Start the libvirt default network before the proxy";
      wantedBy = [ "multi-user.target" ];
      wants = [ "libvirtd.service" ];
      requires = [ "libvirtd.socket" ];
      after = [ "libvirtd.socket" "libvirtd.service" ];
      before = [ "dae.service" "honk.service" ];
      path = [ config.virtualisation.libvirtd.package pkgs.iproute2 pkgs.gnugrep ];
      script = ''
        virsh -c qemu:///system net-autostart default
        active_networks=$(virsh -c qemu:///system net-list --name)
        if ! printf '%s\n' "$active_networks" | grep -Fxq default; then
          virsh -c qemu:///system net-start default
        fi
        ip link show dev virbr0 > /dev/null
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "30s";
      };
    };

    systemd.services.dae = lib.mkIf config.my.features.dae.enable {
      requires = [ "libvirt-default-network.service" ];
      after = [ "libvirt-default-network.service" ];
    };
    systemd.services.honk = lib.mkIf config.my.features.honk.enable {
      requires = [ "libvirt-default-network.service" ];
      after = [ "libvirt-default-network.service" ];
    };
  };
}
