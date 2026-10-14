{ pkgs, ... }:
{
  # HP printer
  users.users.chumeng.extraGroups = [ "lpadmin" ];
  services.printing = {
    enable = true;
    drivers = [ pkgs.hplipWithPlugin ];
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.syncthing = {
    enable = true;
    user = "chumeng";
    dataDir = "/home/chumeng/Documents";
    configDir = "/home/chumeng/.config/syncthing";
    settings = {
      devices = {
        "remote" = {
          id = "OD5XNWZ-FW3WZDK-JK3K7WW-EEJADOA-WLND3WI-OWN6NAN-KV22IEH-UBQXKAP";
        };
      };
      folders = {
        "Tweets" = {
          path = "/home/chumeng/Documents/.obsidian/Notes/Tweets";
          devices = [ "remote" ];
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/chumeng/Documents/.obsidian/Notes/Tweets 0755 chumeng syncthing -"
  ];
}
