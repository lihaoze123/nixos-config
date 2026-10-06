{ config, lib, inputs, pkgs, pkgs-stable, system, mkRustToolchain, ... }:
let
  plymouth = "${config.boot.plymouth.package}/bin/plymouth";

  # Wait (at most 15s) for the greeter's niri to create its Wayland socket,
  # plus a moment for its first frame.
  waitForGreeter = pkgs.writeShellScript "wait-for-greeter" ''
    uid=$(${pkgs.coreutils}/bin/id -u dms-greeter) || exit 0
    for _ in $(${pkgs.coreutils}/bin/seq 150); do
      for socket in /run/user/$uid/wayland-*; do
        if [ -S "$socket" ]; then
          exec ${pkgs.coreutils}/bin/sleep 1
        fi
      done
      ${pkgs.coreutils}/bin/sleep 0.1
    done
  '';
in
{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ../base.nix
    ../../modules/virtualisation
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.computer-use.nixosModules.default
    inputs.gxfp5130Chicago.nixosModules.default
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "backup";
      home-manager.users.chumeng = import ./laptop.nix;
      home-manager.extraSpecialArgs = { inherit inputs pkgs-stable system mkRustToolchain; };
    }
    (import ../../modules)
    (import ../../overlays)
  ];

  networking.hostName = "laptop";

  # Ignore the Wi-Fi side of F9 to avoid accidental rfkill toggles when
  # switching Fn modes. The regular F9 used by VoCoType remains available.
  services.udev.extraHwdb = ''
    evdev:name:Huawei WMI hotkeys:dmi:*:svnHUAWEI:pnVGHH-XX:*
     KEYBOARD_KEY_289=reserved
  '';

  # Native ChicagoHS support; private files and enrolled prints stay in /var/lib.
  hardware.gxfp5130Chicago.enable = true;

  # Dank Greeter on greetd instead of the shared SDDM default. Switching display
  # managers stops the running session: apply with `nixos-rebuild boot` and reboot.
  my.niri.greeter = "dms";
  services.displayManager.dms-greeter = {
    enable = true;
    compositor = {
      name = "niri";
      # Replaces the greeter's built-in niri config, so its defaults are kept here.
      customConfig = ''
        hotkey-overlay {
            skip-at-startup
        }

        environment {
            DMS_RUN_GREETER "1"
        }

        gestures {
            hot-corners {
                off
            }
        }

        // Match the Plymouth background to avoid a flash between them.
        layout {
            background-color "#141218"
        }

        output "eDP-1" {
            mode "3120x2080@120"
            scale 2
        }

        input {
            touchpad {
                tap
                natural-scroll
            }
        }
      '';
    };
    # Copies the DMS theme and wallpaper into the greeter before each start.
    configHome = "/home/chumeng";
  };

  # Hand the display from Plymouth straight to the greeter. By default Plymouth
  # quits before greetd starts; the DRM device is then left to i915's fbdev
  # copy of the firmware framebuffer, flashing the vendor logo for seconds.
  # Instead, Plymouth only drops DRM master here and keeps its last frame up,
  # then quits with --retain-splash once the greeter's niri owns the display.
  services.greetd.greeterManagesPlymouth = true;
  systemd.services.greetd = {
    after = [ "plymouth-start.service" ];
    # Type=idle waits up to 5s for other boot jobs before starting the greeter.
    serviceConfig.Type = lib.mkForce "simple";
    preStart = lib.mkAfter ''
      if ${plymouth} --ping; then
        ${plymouth} deactivate || :
      fi
    '';
  };
  systemd.services.plymouth-quit = {
    after = [ "greetd.service" ];
    # A rebuild must not rerun the wait below inside a running session.
    restartIfChanged = false;
    serviceConfig = {
      ExecStartPre = "-${waitForGreeter}";
      ExecStart = [ "" "-${plymouth} quit --retain-splash" ];
    };
  };

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
    swaylock.fprintAuth = true;
  };

  # Codex Desktop Computer Use on niri, including agent input that does not take the
  # pointer or focus: https://github.com/lihaoze123/niri-computer-use
  programs.codexComputerUse = {
    enable = true;
    users = [ "chumeng" ];
    package = import ../../modules/niri/codex-desktop.nix { inherit inputs system; };
  };

  programs.steam = {
    enable = true;
  };

  # System backends used by the Home Manager DMS session.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.accounts-daemon.enable = true;
  programs.dconf.enable = true;
  # Dankscale manages Tailscale as the desktop user, without recurring prompts.
  services.tailscale.extraSetFlags = [ "--operator=chumeng" ];
  # Valent speaks KDE Connect and browses phone files through Nautilus/GVfs.
  programs.kdeconnect = {
    enable = true;
    package = pkgs.valent;
  };

  # Use the pinned nixpkgs module and its user service for DMS file search.
  programs.dsearch = {
    enable = true;
    systemd.target = "graphical-session.target";
  };

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

  services.avahi = {
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
