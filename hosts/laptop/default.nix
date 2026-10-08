{ config, lib, inputs, pkgs, pkgs-stable, system, ... }:
{
  imports = [
    ./features.nix
    ./hardware-configuration.nix
    ./boot.nix
    ../base.nix
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.gxfp5130Chicago.nixosModules.default
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "backup";
      home-manager.users.chumeng = import ./laptop.nix;
      home-manager.extraSpecialArgs = { inherit inputs pkgs-stable system; };
    }
    (import ../../modules)
    (import ../../overlays)
  ];

  config = lib.mkMerge [
    {
      networking.hostName = "laptop";

      # Ignore the Wi-Fi side of F9 to avoid accidental rfkill toggles when
      # switching Fn modes. The regular F9 used by VoCoType remains available.
      services.udev.extraHwdb = ''
        evdev:name:Huawei WMI hotkeys:dmi:*:svnHUAWEI:pnVGHH-XX:*
         KEYBOARD_KEY_289=reserved
      '';

      # Native ChicagoHS support; private files and enrolled prints stay in /var/lib.
      hardware.gxfp5130Chicago.enable = config.my.features.fingerprint.enable;

    }
    (lib.mkIf config.my.features.desktop.enable {
      # The shared Dank Greeter (modules/niri) with this panel's output.
      my.niri.greeterExtraConfig = ''
        output "eDP-1" {
            mode "3120x2080@120"
            scale 2
        }
      '';

    })
    {
      # Local login, privilege prompts and screen lockers; retain password fallback.
      # Without the driver, fprintAuth already defaults to off for every service.
      security.pam.services = lib.mkIf config.my.features.fingerprint.enable {
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

      programs.steam = {
        enable = config.my.features.steam.enable;
      };

      # Valent speaks KDE Connect and browses phone files through Nautilus/GVfs.
      programs.kdeconnect = {
        enable = config.my.features.phoneIntegration.enable;
        package = pkgs.valent;
      };

    }
    (lib.mkIf config.my.features.screenCast.enable {
      environment.systemPackages = with pkgs; [
        dnsmasq
        gnome-network-displays
      ];

      networking.firewall = {
        trustedInterfaces = [ "p2p-wl+" ];
        allowedTCPPorts = [ 7236 7250 ];
        allowedUDPPorts = [ 7236 5353 ];
        interfaces."wlp0s20f3" = {
          allowedTCPPorts = [ 45545 ];
          allowedUDPPorts = [ 45545 6771 ];
        };
      };

    })
    {
      services.avahi = lib.mkIf (config.my.features.phoneIntegration.enable || config.my.features.screenCast.enable) {
        enable = true;
        # Valent advertises its KDE Connect endpoint through DNS-SD.
        publish = {
          enable = true;
          userServices = true;
        };
        nssmdns4 = true;
        openFirewall = true;
      };
    }
  ];
}
