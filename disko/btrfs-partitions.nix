{ inputs, ... }:
{
  imports = [ inputs.disko.nixosModules.disko ];

  # These devices are existing partitions, never the whole Windows disk.
  # Create them separately; format first, then mount and install (no destroy).
  disko.devices.disk = {
    nixboot = {
      type = "disk";
      device = "/dev/disk/by-partlabel/NIXBOOT";
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
        mountOptions = [ "umask=0077" ];
      };
    };
    nixos = {
      type = "disk";
      device = "/dev/disk/by-partlabel/nixos";
      content = {
        type = "btrfs";
        extraArgs = [ "-f" ];
        subvolumes = {
          "/root" = {
            mountpoint = "/";
            mountOptions = [ "compress=zstd" ];
          };
          "/home" = {
            mountpoint = "/home";
            mountOptions = [ "compress=zstd" ];
          };
          "/nix" = {
            mountpoint = "/nix";
            mountOptions = [ "compress=zstd" "noatime" ];
          };
          "/swap" = {
            mountpoint = "/.swapvol";
            swap.swapfile.size = "8G";
          };
        };
      };
    };
  };
}
