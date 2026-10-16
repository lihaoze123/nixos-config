{ config, lib, ... }:
{
  # Start Plymouth on the Intel KMS device.
  boot.initrd.kernelModules = lib.mkIf config.my.desktop.graphicalBoot.enable [ "i915" ];

  # Ignore the Wi-Fi side of F9 to avoid accidental rfkill toggles when
  # switching Fn modes. The regular F9 used by VoCoType remains available.
  services.udev.extraHwdb = ''
    evdev:name:Huawei WMI hotkeys:dmi:*:svnHUAWEI:pnVGHH-XX:*
     KEYBOARD_KEY_289=reserved
  '';

  # Disable the unreliable fingerprint reader; keep enrolled prints in /var/lib.
  hardware.gxfp5130Chicago.enable = false;

  # Use passwords for login, privilege prompts and screen unlocking.
  security.pam.services = {
    login.fprintAuth = false;
    sudo.fprintAuth = false;
    polkit-1.fprintAuth = false;
    dankshell.fprintAuth = false;
  };
}
