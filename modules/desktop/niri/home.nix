{ lib, pkgs, osConfig, ... }:
{
  imports = [ ./dms ./scratchpad.nix ];

  config = lib.mkMerge [
    {
      programs.dank-material-shell.enable = osConfig.my.desktop.enable;
    }
    (lib.mkIf osConfig.my.desktop.enable {
      home.file.".background/wallpaper.jpg".source = ./wallpaper.jpg;
      home.file.".face.icon".source = ./.face.icon;

      xresources.properties = {
        "Xcursor.size" = lib.mkDefault 16;
        "Xft.dpi" = osConfig.my.desktop.xftDpi;
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
    })
  ];
}
