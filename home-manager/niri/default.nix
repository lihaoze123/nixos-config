{ config, lib, pkgs, osConfig, ... }:
let
  niriConfigPath = "${config.home.homeDirectory}/nixos-config/home-manager/niri/config.kdl";
  useDms = config.programs.dank-material-shell.enable;

  # 小鹤音形官方部件字根键盘图 (https://flypy.cc/help/#/zg)
  xhup-roots-image = pkgs.fetchurl {
    url = "https://flypy.cc/help/assets/img/xhzg.webp";
    hash = "sha256-nV14v2z67cX34jRt4ncRMbFduJG+WGDRnwXsQt5AJYE=";
  };

  # Toggle the chart: close it if it is already open, otherwise open it.
  # The niri window rule for app-id "xhup-roots" makes it float centered.
  xhup-roots = pkgs.writeShellApplication {
    name = "xhup-roots";
    runtimeInputs = with pkgs; [ jq swayimg ];
    text = ''
      id=$(niri msg --json windows | jq -r 'first(.[] | select(.app_id == "xhup-roots") | .id) // empty')
      if [ -n "$id" ]; then
        exec niri msg action close-window --id "$id"
      fi
      exec swayimg --appid=xhup-roots \
        --execute='swayimg.viewer.default_scale = "fit"; swayimg.text.visible = false' \
        ${xhup-roots-image}
    '';
  };
in
{
  imports = [ ./dms ];

  config = lib.mkIf osConfig.my.features.desktop.enable {

    xdg.configFile."niri/config.kdl" = lib.mkIf (!useDms) {
      source = config.lib.file.mkOutOfStoreSymlink niriConfigPath;
    };
    xdg.configFile."waybar" = lib.mkIf (!useDms) { source = ./waybar; };
    xdg.configFile."wofi" = lib.mkIf (!useDms) { source = ./wofi; };
    xdg.configFile."mako" = lib.mkIf (!useDms) { source = ./mako; };
    home.file.".background/wallpaper.jpg".source = ./wallpaper.jpg;
    home.file.".face.icon".source = ./.face.icon;

    xresources.properties = {
      "Xcursor.size" = lib.mkDefault 16;
      "Xft.dpi" = 172;
    };

    # DMS runs its own clipboard history server.
    services.cliphist = {
      enable = !useDms;
      systemdTargets = [ "graphical-session.target" ];
    };

    programs.waybar = {
      enable = !useDms;
      systemd.enable = !useDms;
    };

    systemd.user.services = {
      mako = lib.mkIf (!useDms) {
        Unit = {
          After = [ "niri.service" ];
          Requires = [ "niri.service" ];
        };
      };

      waybar = lib.mkIf (!useDms) {
        Unit = {
          After = [ "niri.service" ];
          Requires = [ "niri.service" ];
        };
      };

      swaybg = lib.mkIf (!useDms) {
        Unit = {
          After = [ "niri.service" ];
          Requires = [ "niri.service" ];
          PartOf = [ "graphical-session.target" ];
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${config.home.homeDirectory}/.background/wallpaper.jpg -m fill";
          Restart = "on-failure";
        };
      };

      xwayland-satellite = {
        Unit = {
          After = [ "niri.service" ];
          Requires = [ "niri.service" ];
          PartOf = [ "graphical-session.target" ];
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite :3";
          Restart = "on-failure";
        };
      };
    };

    home.packages = with pkgs; [
      xwayland-satellite
    ] ++ lib.optionals (!useDms) [ wofi mako swaybg xhup-roots ];
  };
}
