{ config, lib, pkgs, ... }:
let cfg = config.my.virtualisation;
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.docker.enable {
      virtualisation.docker = {
        enable = true;
        rootless = { enable = true; setSocketVariable = true; };
      };
    })
    (lib.mkIf cfg.libvirt.enable {
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

      my.network.proxy.lanInterfaces = [ "virbr0" ];

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

      systemd.services.dae = lib.mkIf (config.my.network.proxy.backend == "dae") {
        requires = [ "libvirt-default-network.service" ];
        after = [ "libvirt-default-network.service" ];
      };
      systemd.services.honk = lib.mkIf (config.my.network.proxy.backend == "honk") {
        requires = [ "libvirt-default-network.service" ];
        after = [ "libvirt-default-network.service" ];
      };
    })
    (lib.mkIf cfg.waydroid.enable { virtualisation.waydroid.enable = true; })
    (lib.mkIf cfg.podman.enable {
      virtualisation.podman.enable = true;
      virtualisation.containers.registries.settings.unqualified-search-registries = [
        "docker.io"
        "quay.io"
        "ghcr.io"
      ];
      environment.systemPackages = [ pkgs.distrobox ];
    })
  ];
}
