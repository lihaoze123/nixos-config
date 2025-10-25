{ config, pkgs, ... }@inputs:
let
  niriConfigPath = "${config.home.homeDirectory}/nixos-config/home-manager/niri/config.kdl";
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
  ];
}
