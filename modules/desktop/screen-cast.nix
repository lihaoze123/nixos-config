{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.screenCast;
in
{
  options.my.desktop.screenCast.enable = lib.mkEnableOption "GNOME Network Displays and Wi-Fi display ports";

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || config.my.desktop.enable;
          message = "my.desktop.screenCast requires my.desktop";
        }
      ];
    }
    # Wi-Fi Display ports; hosts add their Wi-Fi interface's discovery ports.
    (lib.mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        dnsmasq
        gnome-network-displays
      ];

      networking.firewall = {
        trustedInterfaces = [ "p2p-wl+" ];
        allowedTCPPorts = [ 7236 7250 ];
        allowedUDPPorts = [ 7236 5353 ];
      };

      services.avahi = {
        enable = true;
        settings.publish = {
          disable-publishing = false;
          disable-user-service-publishing = false;
          publish-addresses = true;
        };
        nssmdns4 = true;
        openFirewall = true;
      };
    })
  ];
}
