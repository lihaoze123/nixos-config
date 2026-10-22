{ config, pkgs, lib, inputs, ... }:
let
  cfg = config.my.desktop;
  desktopPackages = inputs.nur-desktop.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    inputs.nur-desktop.nixosModules.computer-use
    ./graphical-boot.nix
    ./fonts.nix
    ./phone.nix
    ./screen-cast.nix
  ];

  config = lib.mkIf cfg.enable {
    programs.niri = {
      enable = true;
      # The imported module otherwise rebuilds niri with the host's pkgs.
      # Keep its feature flags while selecting the exact CI-cached package set.
      package = lib.mkIf (config.programs.codexComputerUse.enable && config.programs.codexComputerUse.patchNiri)
        (lib.mkForce (desktopPackages.niri-patched.override {
          agentInput = config.programs.codexComputerUse.agentInput;
        }));
    };

    # Share the desktop and native niri backend across hosts.
    programs.codexComputerUse = {
      enable = cfg.codexComputerUse.enable;
      users = [ config.my.user.name ];
      package = desktopPackages.codex-desktop;
    };

    # Dank Greeter on greetd. Switching display managers stops the running
    # session: apply with `nixos-rebuild boot` and reboot.
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

          input {
              touchpad {
                  tap
                  natural-scroll
              }
          }
        '' + cfg.outputsConfig + cfg.greeter.extraConfig;
      };
      # Copies the DMS theme and wallpaper into the greeter before each start.
      configHome = config.my.user.home;
    };

    security.polkit.enable = true;
    services.gnome.gnome-keyring.enable = true;
    # Nautilus: removable disks, MTP phones, trash and remote file access.
    services.gvfs.enable = true;
    services.udisks2.enable = true;
    services.gnome.sushi.enable = true;

    # System backends used by the Home Manager DMS session.
    services.upower.enable = true;
    services.power-profiles-daemon.enable = true;
    services.accounts-daemon.enable = true;
    programs.dconf.enable = true;

    # Use the pinned nixpkgs module and its user service for DMS file search.
    programs.dsearch = {
      enable = true;
      systemd.target = "graphical-session.target";
    };

    environment.systemPackages = [ pkgs.wl-clipboard ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    users.users.${config.my.user.name}.extraGroups = [ "render" "audio" ];
  };
}
