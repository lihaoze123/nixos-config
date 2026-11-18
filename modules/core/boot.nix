{ lib, ... }:
{
  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = lib.mkDefault true;
    };
    efi = {
      canTouchEfiVariables = lib.mkDefault true;
      efiSysMountPoint = "/boot";
    };
  };
}
