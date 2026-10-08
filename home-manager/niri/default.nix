{ lib, pkgs, osConfig, ... }:
{
  imports = [ ./dms ];

  config = lib.mkIf osConfig.my.features.desktop.enable {
    home.file.".background/wallpaper.jpg".source = ./wallpaper.jpg;
    home.file.".face.icon".source = ./.face.icon;

    xresources.properties = {
      "Xcursor.size" = lib.mkDefault 16;
      "Xft.dpi" = 172;
    };

    systemd.user.services.xwayland-satellite = {
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

    home.packages = [ pkgs.xwayland-satellite ];
  };
}
