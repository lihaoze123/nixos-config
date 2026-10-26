{ config, lib, pkgs, ... }:
let
  stateDir = "/var/lib/karakeep";
  containers = [ "karakeep" "karakeep-chrome" "karakeep-meilisearch" ];
  containerOptions = [
    "--network=karakeep"
    "--security-opt=no-new-privileges"
    "--log-opt=max-size=10m"
    "--log-opt=max-file=3"
  ];
in
{
  age.secrets = {
    karakeep-env = {
      file = ../../secrets/karakeep-env.age;
      mode = "0400";
    };
    karakeep-admin-password = {
      file = ../../secrets/karakeep-admin-password.age;
      mode = "0400";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 root root - -"
    "d ${stateDir}/data 0700 root root - -"
    "d ${stateDir}/meilisearch 0700 root root - -"
  ];

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      karakeep = {
        image = "ghcr.io/karakeep-app/karakeep:0.34.1@sha256:69ae5315c618b7c14c1af3e34c6e211acdb231793af424ecd1cab0b70691d987";
        dependsOn = [ "karakeep-chrome" "karakeep-meilisearch" ];
        ports = [ "127.0.0.1:3080:3000" ];
        environment = {
          TZ = "Asia/Shanghai";
          DATA_DIR = "/data";
          NEXTAUTH_URL = "https://keep.chumeng.xyz";
          DISABLE_SIGNUPS = "true";
          DISABLE_NEW_RELEASE_CHECK = "true";
          MEILI_ADDR = "http://karakeep-meilisearch:7700";
          BROWSER_WEB_URL = "http://karakeep-chrome:9222";
          CRAWLER_FULL_PAGE_ARCHIVE = "true";
          CRAWLER_FULL_PAGE_ARCHIVE_MAX_SIZE_MB = "25";
        };
        environmentFiles = [ config.age.secrets.karakeep-env.path ];
        volumes = [ "${stateDir}/data:/data" ];
        log-driver = "json-file";
        extraOptions = containerOptions;
      };
      karakeep-chrome = {
        # Upstream's browser image includes Debian Chromium for ARM64.
        image = "ghcr.io/karakeep-app/karakeep-chrome:release@sha256:4ad61127638dd27bfe685222787c5780dd1d083d23a7658c39af657775814c44";
        cmd = [
          "--disable-gpu"
          "--disable-dev-shm-usage"
          "--hide-scrollbars"
          "--disable-blink-features=AutomationControlled"
          "--window-size=1440,900"
        ];
        log-driver = "json-file";
        extraOptions = containerOptions ++ [ "--init" "--cap-drop=ALL" ];
      };
      karakeep-meilisearch = {
        image = "getmeili/meilisearch:v1.41.0@sha256:860fa4baed04ae1c235de870edab0c8006227546dea1bbb6411fbfc5e27cf1db";
        environment = {
          MEILI_ENV = "production";
          MEILI_NO_ANALYTICS = "true";
        };
        environmentFiles = [ config.age.secrets.karakeep-env.path ];
        volumes = [ "${stateDir}/meilisearch:/meili_data" ];
        log-driver = "json-file";
        extraOptions = containerOptions ++ [ "--cap-drop=ALL" ];
      };
    };
  };

  systemd.services = lib.genAttrs (map (name: "docker-${name}") containers)
    (_: {
      after = [ "karakeep-network.service" ];
      requires = [ "karakeep-network.service" ];
    }) // {
    karakeep-network = {
      description = "Private Docker network for Karakeep";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      path = [ pkgs.docker ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        docker network inspect karakeep >/dev/null 2>&1 || docker network create karakeep >/dev/null
      '';
    };
  };

  services.nginx.virtualHosts."keep.chumeng.xyz" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3080";
      recommendedProxySettings = true;
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 64m;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
      '';
    };
  };
}
