{ config, pkgs, ... }@inputs:
let
  niriConfigPath = "${config.home.homeDirectory}/nixos-config/home-manager/niri/config.kdl";

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
      exec swayimg --class=xhup-roots --scale=fit --config=info.show=no ${xhup-roots-image}
    '';
  };
in
{
  xdg.configFile."niri/config.kdl".source = config.lib.file.mkOutOfStoreSymlink niriConfigPath;
  xdg.configFile."waybar".source = ./waybar;
  xdg.configFile."wofi".source = ./wofi;
  xdg.configFile."mako".source = ./mako;
  home.file.".background/wallpaper.jpg".source = ./wallpaper.jpg;
  home.file.".face.icon".source = ./.face.icon;

  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 172;
  };

  programs.waybar = {
    enable = true;
    systemd.enable = true;
  };

  systemd.user.services = {
    mako = {
      Unit = {
        After = [ "niri.service" ];
        Requires = [ "niri.service" ];
      };
    };

    waybar = {
      Unit = {
        After = [ "niri.service" ];
        Requires = [ "niri.service" ];
      };
    };

    swaybg = {
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
    wofi
    mako
    swaybg
    cliphist
    xwayland-satellite
    nautilus
    xhup-roots
  ];
}
