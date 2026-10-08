# Placeholder for evaluation. Replace it on the target machine with:
#   nixos-generate-config --show-hardware-config > hosts/base/hardware-configuration.nix
# The labels below follow the NixOS manual's partitioning example.
{ modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
