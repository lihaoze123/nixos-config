{ config, lib, ... }:
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
      # The panel's preferred EDID timing, for both greeter and desktop.
      outputs."eDP-1" = {
        mode = "1920x1080@60.000";
        scale = 1;
        position = { x = 0; y = 0; };
      };
    };
    input.vtype.enable = true;
    fonts.windows.enable = true;
    kernel.cachyos.enable = true;
    network.proxy.backend = "dae";
    virtualisation = {
      podman.enable = true;
      libvirt.enable = true;
    };
  };

  # No checkout of this repository on this machine: ship configs from the store.
  my.configPath = null;
  my.home.imports = [ ./home.nix ];

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
  users.users.${config.my.user.name}.openssh.authorizedKeys.keys = [
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
