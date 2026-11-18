{ config, pkgs, lib, inputs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.my.desktop;
in
{
  imports = [
    ./graphical-boot.nix
    ./fonts.nix
    ./niri
    ./fcitx5
    ./codex-computer-use.nix
    ./wallpaper-engine.nix
    ./phone
    ./screen-cast.nix
    ./easyeffects
  ];

  options.my.desktop = {
    enable = mkEnableOption "Niri with DankMaterialShell and Dank Greeter, Chinese input, audio and desktop utilities";
    utilities.enable = mkEnableOption "commonly used graphical tools: terminal, editor, audio and disk utilities";
    xftDpi = mkOption {
      type = types.ints.positive;
      default = 96;
      description = "XWayland Xft.dpi resource value.";
    };
    greeter.extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Host-specific niri configuration for the Dank Greeter, such as outputs.";
    };
    outputs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          mode = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "1920x1080@60.000";
          };
          scale = mkOption {
            type = types.nullOr types.number;
            default = null;
          };
          position = mkOption {
            type = types.nullOr (types.submodule {
              options = {
                x = mkOption { type = types.int; };
                y = mkOption { type = types.int; };
              };
            });
            default = null;
          };
        };
      });
      default = { };
      description = "Monitors keyed by connector name (`niri msg outputs`), for both the desktop and the Dank Greeter.";
    };
    outputsConfig = mkOption {
      type = types.lines;
      internal = true;
      readOnly = true;
      default = lib.concatStrings (lib.mapAttrsToList
        (name: o: "output \"${name}\" {\n"
          + lib.optionalString (o.mode != null) "    mode \"${o.mode}\"\n"
          + lib.optionalString (o.scale != null) "    scale ${builtins.toJSON o.scale}\n"
          + lib.optionalString (o.position != null) "    position x=${toString o.position.x} y=${toString o.position.y}\n"
          + "}\n")
        cfg.outputs);
      description = "niri KDL generated from my.desktop.outputs.";
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.utilities.enable || cfg.enable;
          message = "my.desktop.utilities requires my.desktop";
        }
      ];
      my.home = ./home.nix;
    }
    (lib.mkIf cfg.enable {
      nixpkgs.overlays = [ inputs.xwayland-satellite.overlays.default ];
      programs.niri.enable = true;

      # Dank Greeter on greetd. Switching display managers stops the running
      # session: apply with `nixos-rebuild boot` and reboot.
      services.displayManager.dux-greeter = {
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
      programs.dux-search = {
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
    })
  ];
}
