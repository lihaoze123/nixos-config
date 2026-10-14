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
      networking.firewall.interfaces."virbr0".allowedUDPPorts = [ 67 ];
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
