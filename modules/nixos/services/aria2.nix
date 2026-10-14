{ config, lib, pkgs, ... }:
let
  user = config.my.user;
in
{
  config = lib.mkIf config.my.services.aria2.enable {
    age.secrets."aria2-password" = {
      file = ../../../secrets/aria2-password.age;
      path = "/etc/aria2/rpc-secret";
      symlink = false;
      mode = "0400";
    };

    systemd.tmpfiles.rules = lib.mkBefore [
      # The first rule for a path wins; precede the upstream aria2-owned rules.
      "d '${user.home}/Download' 0710 ${user.name} users - -"
      "d '/var/lib/aria2' 0770 ${user.name} users - -"
      # Transfer existing state and downloads after the module creates its directories.
      "Z /var/lib/aria2 - ${user.name} users - -"
    ];

    systemd.services.aria2.serviceConfig = {
      User = lib.mkForce user.name;
      Group = lib.mkForce "users";
    };

    services.caddy = {
      enable = true;
      virtualHosts."http://localhost:8081".extraConfig = ''
        bind 127.0.0.1 ::1
        reverse_proxy /jsonrpc localhost:${toString config.services.aria2.settings.rpc-listen-port}
        file_server {
          root ${pkgs.ariang}/share/ariang
        }
      '';
    };

    services.aria2 = {
      enable = true;
      rpcSecretFile = config.age.secrets."aria2-password".path;
      serviceUMask = "0007";
      downloadDirPermission = "0710";
      settings = {
        dir = "${user.home}/Download";
        max-concurrent-downloads = 3;
        max-connection-per-server = 16;
        split = 16;
        min-split-size = "5M";
        enable-rpc = true;
        rpc-listen-all = false;
        rpc-listen-port = 6800;
        rpc-allow-origin-all = true;
        save-session = "/var/lib/aria2/aria2.session";
        input-file = "/var/lib/aria2/aria2.session";
        save-session-interval = 60;
      };
    };
  };
}
