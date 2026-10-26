{ config, ... }:
{
  age.secrets.libretv-env = {
    file = ../../secrets/libretv-env.age;
    mode = "0400";
  };

  virtualisation.oci-containers.containers.libretv = {
    image = "ghcr.io/librespark/libretv:2.21.0@sha256:3fb7ab9a4e2477f606d515b39222b3f683a21e0e0293855662b5c35e6f7f1fc3";
    ports = [ "127.0.0.1:8081:8080" ];
    environment = {
      TZ = "Asia/Shanghai";
      COOKIE_SECURE = "true";
    };
    environmentFiles = [ config.age.secrets.libretv-env.path ];
    log-driver = "json-file";
    extraOptions = [
      "--cap-drop=ALL"
      "--security-opt=no-new-privileges"
      "--log-opt=max-size=10m"
      "--log-opt=max-file=3"
    ];
  };

  services.nginx.virtualHosts."tv.chumeng.xyz" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8081";
      recommendedProxySettings = true;
      proxyWebsockets = true;
      extraConfig = ''
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
      '';
    };
  };
}
