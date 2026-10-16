{ config, ... }:
{
  age.secrets.wastebin-env = {
    file = ../../secrets/wastebin-env.age;
    mode = "0400";
  };

  services.wastebin = {
    enable = true;
    secretFile = config.age.secrets.wastebin-env.path;
    settings = {
      WASTEBIN_ADDRESS_PORT = "127.0.0.1:8088";
      WASTEBIN_BASE_URL = "https://paste.chumeng.xyz";
      WASTEBIN_MAX_BODY_SIZE = 1048576;
    };
  };
  systemd.services.wastebin.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "5s";
    StateDirectoryMode = "0700";
  };

  services.nginx = {
    # Empty keys skip write limiting for reads and static assets.
    appendHttpConfig = ''
      map $request_method $wastebin_write_key {
        default "";
        POST $binary_remote_addr;
        DELETE $binary_remote_addr;
      }
      limit_req_zone $binary_remote_addr zone=wastebin_requests:10m rate=10r/s;
      limit_req_zone $wastebin_write_key zone=wastebin_writes:10m rate=10r/m;
      limit_conn_zone $binary_remote_addr zone=wastebin_connections:10m;
    '';
    virtualHosts."paste.chumeng.xyz" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8088";
        recommendedProxySettings = true;
        extraConfig = ''
          client_max_body_size 1m;
          limit_req zone=wastebin_requests burst=40 nodelay;
          limit_req zone=wastebin_writes burst=5 nodelay;
          limit_req_status 429;
          limit_conn wastebin_connections 20;
          limit_conn_status 429;
        '';
      };
    };
  };
}
