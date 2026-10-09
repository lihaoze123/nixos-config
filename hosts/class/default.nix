{ config, inputs, pkgs, pkgs-stable, system, lib, ... }:

# Base-derived host; select optional features in ./features.nix.
{
  imports = [
    ./features.nix
    ./hardware-configuration.nix
    ../../disko/btrfs-partitions.nix
    ../base.nix
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.chumeng = {
        imports = [ ../../home-manager/home.nix ];
        age.identityPaths = lib.mkForce [ "/home/chumeng/.ssh/id_ed25519" ];
        xresources.properties."Xft.dpi" = lib.mkForce 96;
        # The new machine has no checkout at ~/nixos-config: ship these files.
        xdg.configFile."nvim".source = lib.mkForce ../../home-manager/shell/neovim/nvim;
        # Pin the panel's fractional EDID mode instead of auto-selecting 60 Hz.
        xdg.configFile."niri/base.kdl" = lib.mkIf config.my.features.desktop.enable {
          source = lib.mkForce (pkgs.writeText "class-niri-base.kdl" (lib.replaceStrings
            [ "mode \"3120x2080@120\"" "scale 2.0" "position x=1280 y=0" "window-rule {\n    match is-agent-driven=true" "include \"dms/layout.kdl\"" ]
            [ "mode \"1920x1080@50.002\"" "scale 1.0" "position x=0 y=0" "${lib.optionalString (!config.my.features.codexDesktop.enable) "/-"}window-rule {\n    match is-agent-driven=true" "include optional=true \"dms/layout.kdl\"" ]
            (builtins.readFile ../../home-manager/niri/config.kdl)));
        };
      };
      home-manager.extraSpecialArgs = { inherit inputs pkgs-stable system; };
    }
    (import ../../modules)
    (import ../../overlays)
  ];

  networking.hostName = "class";
  networking.firewall = {
    allowedTCPPorts = [ 9100 ];
    allowedUDPPorts = [ 7778 ];
  };
  nixpkgs.hostPlatform = "x86_64-linux";
  # Start Plymouth on the Intel KMS device, before the greeter takes over.
  boot.initrd.kernelModules = lib.mkIf config.my.features.graphicalBoot.enable [ "i915" ];
  my.niri.greeterExtraConfig = ''
    output "eDP-1" {
      mode "1920x1080@50.002"
      scale 1.0
    }
  '';
  age.identityPaths = lib.mkForce [ "/etc/ssh/ssh_host_ed25519_key" ];

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
