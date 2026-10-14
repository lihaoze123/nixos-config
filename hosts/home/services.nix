{ config, pkgs, ... }:
let
  user = config.my.user;
in
{
  # HP printer
  users.users.${user.name}.extraGroups = [ "lpadmin" ];
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
    user = user.name;
    dataDir = "${user.home}/Documents";
    configDir = "${user.home}/.config/syncthing";
    settings = {
      devices = {
        "remote" = {
          id = "OD5XNWZ-FW3WZDK-JK3K7WW-EEJADOA-WLND3WI-OWN6NAN-KV22IEH-UBQXKAP";
        };
      };
      folders = {
        "Tweets" = {
          path = "${user.home}/Documents/.obsidian/Notes/Tweets";
          devices = [ "remote" ];
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d ${user.home}/Documents/.obsidian/Notes/Tweets 0755 ${user.name} syncthing -"
  ];
}
