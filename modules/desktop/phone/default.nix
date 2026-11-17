{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.phone;
in
{
  options.my.desktop.phone.enable = lib.mkEnableOption "Valent / KDE Connect phone integration";

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || config.my.desktop.enable;
          message = "my.desktop.phone requires my.desktop";
        }
      ];
      my.home = ./home.nix;
    }
    (lib.mkIf cfg.enable {
      # Valent speaks KDE Connect and browses phone files through Nautilus/GVfs.
      programs.kdeconnect = {
        enable = true;
        package = pkgs.valent;
      };

      services.avahi = {
        enable = true;
        # Valent advertises its KDE Connect endpoint through DNS-SD.
        settings.publish = {
          disable-publishing = false;
          disable-user-service-publishing = false;
          publish-addresses = true;
        };
        nssmdns4 = true;
        openFirewall = true;
      };

      my.desktop.dms.plugins.dankKDEConnect = {
        source = "${config.my.desktop.dms.officialPluginsRepo}/DankKDEConnect";
        barWidget = true;
        barWidgetOrder = 30;
      };
    })
  ];
}
