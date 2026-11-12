{ config, lib, pkgs, ... }:
lib.mkIf config.my.desktop.phone.enable {
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
}
