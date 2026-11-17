{ config, lib, pkgs, ... }:
let
  cfg = config.my.virtualisation.libvirt;
in
{
  options.my.virtualisation.libvirt.enable = lib.mkEnableOption "libvirt, QEMU and virt-manager";

  config = lib.mkIf cfg.enable {
    programs.virt-manager.enable = true;
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
        vhostUserPackages = [ pkgs.virtiofsd ];
      };
    };
    virtualisation.spiceUSBRedirection.enable = true;
    users.users.${config.my.user.name}.extraGroups = [ "kvm" "libvirtd" ];
    networking.firewall.interfaces."virbr0" = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 67 ];
    };

    my.network.proxy = {
      lanInterfaces = [ "virbr0" ];
      afterServices = [ "libvirt-default-network" ];
    };

    systemd.services.libvirt-default-network = {
      description = "Start the libvirt default network before the proxy";
      wantedBy = [ "multi-user.target" ];
      wants = [ "libvirtd.service" ];
      requires = [ "libvirtd.socket" ];
      after = [ "libvirtd.socket" "libvirtd.service" ];
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
  };
}
