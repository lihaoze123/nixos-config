{ config, lib, pkgs, ... }:
# Wi-Fi Display ports; hosts add their Wi-Fi interface's discovery ports.
lib.mkIf config.my.desktop.screenCast.enable {
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
    publish = {
      enable = true;
      userServices = true;
    };
    nssmdns4 = true;
    openFirewall = true;
  };
}
