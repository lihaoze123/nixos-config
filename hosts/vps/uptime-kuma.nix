{ config, ... }:
{
  age.secrets.uptime-kuma-admin-password = {
    file = ../../secrets/uptime-kuma-admin-password.age;
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/uptime-kuma 0700 root root - -"
  ];

  virtualisation.oci-containers.containers.uptime-kuma = {
    image = "louislam/uptime-kuma:2.5.7@sha256:4b95dbe7ac5343b768f8e04e3035ccd59997872b1a35ab9b0f082d2cc279070e";
    ports = [ "127.0.0.1:3001:3001" ];
    environment = {
      TZ = "Asia/Shanghai";
      UPTIME_KUMA_DB_TYPE = "sqlite";
    };
    volumes = [ "/var/lib/uptime-kuma:/app/data" ];
    log-driver = "json-file";
    extraOptions = [
      "--security-opt=no-new-privileges"
      "--log-opt=max-size=10m"
      "--log-opt=max-file=3"
    ];
  };

  services.nginx.virtualHosts."uptime.chumeng.xyz" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3001";
      recommendedProxySettings = true;
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
      '';
    };
  };
}
