{ config, lib, pkgs, ... }:
let cfg = config.my.features;
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.virtualMachines.enable {
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
      users.users.chumeng.extraGroups = [ "kvm" "libvirtd" ];
      networking.firewall.interfaces."virbr0".allowedUDPPorts = [ 67 ];
    })
    (lib.mkIf cfg.waydroid.enable { virtualisation.waydroid.enable = true; })
    (lib.mkIf cfg.podman.enable {
      virtualisation.podman.enable = true;
      environment.systemPackages = [ pkgs.distrobox ];
    })
  ];
}
