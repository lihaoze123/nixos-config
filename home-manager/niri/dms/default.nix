{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.programs.dank-material-shell;
  jsonFormat = pkgs.formats.json { };
  initialSettings = jsonFormat.generate "dms-settings.json" {
    configVersion = 18;
    clockFormat = "24h";
    currentThemeName = "purple";
    launchPrefix = "systemd-run --user --collect --no-block --";
    # Application themes remain opt-in in the DMS settings UI.
    runDmsMatugenTemplates = false;
    runUserMatugenTemplates = false;
    syncModeWithPortal = false;
  };
  initialSession = jsonFormat.generate "dms-session.json" {
    configVersion = 4;
    isLightMode = false;
    wallpaperPath = "${config.home.homeDirectory}/.background/wallpaper.jpg";
    terminalOverride = "ghostty";
  };
  initialize = pkgs.writeShellApplication {
    name = "dms-initialize";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      settings_dir=${lib.escapeShellArg "${config.xdg.configHome}/DankMaterialShell"}
      state_dir=${lib.escapeShellArg "${config.xdg.stateHome}/DankMaterialShell"}
      fragments_dir=${lib.escapeShellArg "${config.xdg.configHome}/niri/dms"}
      install -d -m 700 "$settings_dir" "$state_dir" "$fragments_dir"
      if [ ! -e "$settings_dir/settings.json" ]; then
        install -m 600 ${initialSettings} "$settings_dir/settings.json"
      fi
      if [ ! -e "$state_dir/session.json" ]; then
        install -m 600 ${initialSession} "$state_dir/session.json"
      fi
      # DMS owns these files and rewrites them from its GUI. Never link them
      # into the read-only Nix store or truncate an existing configuration.
      for name in colors layout alttab binds cursor outputs windowrules wpblur input; do
        if [ ! -e "$fragments_dir/$name.kdl" ]; then
          install -m 600 /dev/null "$fragments_dir/$name.kdl"
        fi
      done
    '';
  };
in
{
  imports = [ inputs.dms.homeModules.dank-material-shell ];

  config = lib.mkIf cfg.enable {
    # Qt's GTK platform theme needs a complete icon theme for named tray icons.
    # Application-provided icons remain available through the hicolor fallback.
    gtk = {
      enable = true;
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
    };

    home.packages = [ pkgs.adw-gtk3 ];

    # Install both Qt control tools, leaving their writable settings to DMS.
    qt = {
      enable = true;
      platformTheme.name = "qtct";
    };
    home.sessionVariables.QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
    systemd.user.sessionVariables.QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";

    programs.dank-material-shell = {
      # Use nixpkgs for the runtime and the upstream flake for its module.
      package = pkgs.dms-shell;
      quickshell.package = pkgs.quickshell;
      systemd.enable = true;
      systemd.target = "graphical-session.target";
      enableCalendarEvents = true;
      # Leave settings/session unset: the upstream options create read-only
      # files. Seed writable defaults below so GUI edits survive rebuilds.
    };

    xdg.configFile = {
      "niri/config.kdl".source = ./niri.kdl;
      "niri/base.kdl".source = config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/home-manager/niri/config.kdl";
      "niri/dms-bindings.kdl".source = ./binds.kdl;
    };

    home.activation.initializeDms = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe initialize}
    '';

    systemd.user.services.dms = {
      Unit = {
        After = [ "niri.service" ];
        Requisite = [ "niri.service" ];
        Conflicts = [ "waybar.service" "mako.service" "swaybg.service" ];
      };
      Service = {
        ExecStartPre = lib.getExe initialize;
        Environment = [
          "QT_QPA_PLATFORM=wayland"
          "QT_QPA_PLATFORMTHEME=qt5ct"
          "QT_QPA_PLATFORMTHEME_QT6=qt6ct"
        ];
      };
    };
  };
}
