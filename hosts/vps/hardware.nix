# Hand-written from the running OCI instance; filesystems are owned by disko.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot = {
    initrd.availableKernelModules = [ "sd_mod" ];
    kernelParams = [ "console=tty1" "console=ttyAMA0,115200" ];
    loader = {
      efi.canTouchEfiVariables = false;
      grub = {
        useOSProber = false;
        efiInstallAsRemovable = true;
      };
    };
  };
}
