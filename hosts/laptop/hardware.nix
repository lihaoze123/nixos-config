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

  # Native ChicagoHS fingerprint support; private files and enrolled prints stay in /var/lib.
  hardware.gxfp5130Chicago.enable = true;

  # Local login, privilege prompts and screen lockers; retain password fallback.
  security.pam.services = {
    # greetd (Dank Greeter) runs login as a substack, and its single PAM
    # conversation cannot race pam_fprintd against a typed password: Enter would
    # wait for the fingerprint timeout. Log in with the password only, which
    # also unlocks GNOME Keyring; the lock screen keeps fingerprint.
    login.fprintAuth = false;
    sudo.fprintAuth = true;
    polkit-1.fprintAuth = true;
    # DMS lock runs its own fingerprint PAM context ("fprint") in parallel with
    # the password one. pam_fprintd here would make both claim the reader and
    # block typed passwords until it times out.
    dankshell.fprintAuth = false;
  };
}
