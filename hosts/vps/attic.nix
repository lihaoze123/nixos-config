{ config, pkgs, ... }:
{
  age.secrets.attic-server-env = {
    file = ../../secrets/attic-server-env.age;
    mode = "0400";
  };

  services.atticd = {
    enable = true;
    environmentFile = config.age.secrets.attic-server-env.path;
    settings = {
      listen = "127.0.0.1:8085";
      allowed-hosts = [ "cache.chumeng.xyz" ];
      api-endpoint = "https://cache.chumeng.xyz/";
      database.url = "sqlite:///var/lib/atticd/server.db?mode=rwc";
      storage = {
        type = "local";
        path = "/var/lib/atticd/storage";
      };
      compression = { type = "zstd"; level = 3; };
      # 减少大包上传时的小文件与数据库写入；已有分块仍可正常读取。
      chunking = {
        nar-size-threshold = 1048576;
        min-size = 262144;
        avg-size = 1048576;
        max-size = 4194304;
      };
      garbage-collection = {
        interval = "12 hours";
        default-retention-period = "90 days";
      };
    };
  };
  systemd.services.atticd = {
    # SQLite 初次批量导入后可能误选 state 索引，启动时维护查询统计。
    preStart = ''
      if [ -s /var/lib/atticd/server.db ]; then
        ${pkgs.sqlite.bin}/bin/sqlite3 /var/lib/atticd/server.db 'PRAGMA optimize=0x10002;'
      fi
    '';
    restartTriggers = [ config.age.secrets.attic-server-env.file ];
  };

  environment.systemPackages = [ pkgs.attic-client ];

  services.nginx.virtualHosts."cache.chumeng.xyz" = {
    enableACME = true;
    forceSSL = true;
    extraConfig = ''
      client_max_body_size 10G;
      client_body_timeout 600s;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:8085";
      extraConfig = ''
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_request_buffering off;
        proxy_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
      '';
    };
  };
}
