{ config, lib, ... }:
let
  # Use the panel's preferred EDID timing for both greeter and desktop.
  panelMode = "1920x1080@60.000";
in
# Base-derived classroom machine alongside Windows.
{
  imports = [
    ./hardware-configuration.nix
    ./display.nix
    ./virtualisation.nix
    ../../disko/btrfs-partitions.nix
    ../../profiles/workstation.nix
  ];

  my = {
    desktop = {
      graphicalBoot.enable = true;
      codexComputerUse.enable = true;
      greeter.extraConfig = ''
        output "eDP-1" {
          mode "${panelMode}"
          scale 1.0
        }
      '';
    };
    fonts.windows.enable = true;
    kernel.cachyos.enable = true;
    network.proxy.backend = "dae";
    virtualisation = {
      podman.enable = true;
      libvirt.enable = true;
    };
  };

  home-manager.users.chumeng.imports = [
    (import ./home.nix { inherit panelMode; })
  ];

  networking.firewall = {
    allowedTCPPorts = [ 9100 ];
    allowedUDPPorts = [ 7778 ];
  };
  # Discover wireless displays on the LAN through mDNS/DNS-SD.
  services.avahi = {
    enable = true;
    openFirewall = true;
  };
  nixpkgs.hostPlatform = "x86_64-linux";
  # Start Plymouth on the Intel KMS device, before the greeter takes over.
  boot.initrd.kernelModules = lib.mkIf config.my.desktop.graphicalBoot.enable [ "i915" ];
  # Keep FBC disabled during validation of the DRRS fix in ./display.nix.
  # Disabling FBC alone did not stop the static-image blackouts.
  boot.kernelParams = lib.mkIf config.my.desktop.enable [ "i915.enable_fbc=0" ];
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  users.users.root.openssh.authorizedKeys.keys = [
    (import ../../secrets/keys.nix).laptop
  ];
  users.users.chumeng.openssh.authorizedKeys.keys = [
    (import ../../secrets/keys.nix).laptop
  ];

  # Existing Windows ESP: mount only, outside disko's formatting scope.
  fileSystems."/boot/windows" = {
    device = "/dev/disk/by-uuid/B6E9-B042";
    fsType = "vfat";
    noCheck = true;
    options = [ "ro" "umask=0077" "nofail" ];
  };
}
