{ config, lib, pkgs, ... }:
{
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  age.secrets.cloudreve-admin-password = {
    file = ../../secrets/cloudreve-admin-password.age;
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/cloudreve 0700 root root - -"
    "d /var/lib/cloudreve/data 0700 root root - -"
    "d /var/lib/cloudreve/postgresql 0700 - - - -"
    "d /var/lib/cloudreve/redis 0700 - - - -"
  ];

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      cloudreve-db = {
        image = "postgres:17@sha256:2d2b8998d31037bf721cfdf764d76ba74171b4fab3431b7f72c27c56ddbdf9e3";
        environment = {
          POSTGRES_USER = "cloudreve";
          POSTGRES_DB = "cloudreve";
          # The database is isolated on this stack's network, with no published port.
          POSTGRES_HOST_AUTH_METHOD = "trust";
        };
        volumes = [ "/var/lib/cloudreve/postgresql:/var/lib/postgresql/data" ];
        extraOptions = [ "--network=cloudreve" ];
      };
      cloudreve-redis = {
        image = "redis:8@sha256:2c2dff791878316e3b083188be0d578423b24813cdda5de0e80ea4f7b3e6bfd6";
        volumes = [ "/var/lib/cloudreve/redis:/data" ];
        extraOptions = [ "--network=cloudreve" ];
      };
      cloudreve = {
        image = "cloudreve/cloudreve:4.19.1@sha256:5c6c5baf7fa5bc6e1bb9a7509c09dde00e80b618d180244eb1d5f7e36b358ea2";
        dependsOn = [ "cloudreve-db" "cloudreve-redis" ];
        # Run the application directly; enable offline download services separately if needed.
        entrypoint = "/cloudreve/cloudreve";
        ports = [ "127.0.0.1:5212:5212" ];
        environment = {
          TZ = "Asia/Shanghai";
          CR_ENABLE_ARIA2 = "0";
          "CR_CONF_System.ProxyHeader" = "X-Real-IP";
          "CR_CONF_Database.Type" = "postgres";
          "CR_CONF_Database.Host" = "cloudreve-db";
          "CR_CONF_Database.Port" = "5432";
          "CR_CONF_Database.User" = "cloudreve";
          "CR_CONF_Database.Name" = "cloudreve";
          "CR_CONF_Redis.Server" = "cloudreve-redis:6379";
        };
        volumes = [ "/var/lib/cloudreve/data:/cloudreve/data" ];
        extraOptions = [
          "--network=cloudreve"
          "--cap-drop=ALL"
          "--security-opt=no-new-privileges"
        ];
      };
    };
  };

  systemd.services = lib.genAttrs [ "docker-cloudreve-db" "docker-cloudreve-redis" ]
    (_: {
      after = [ "cloudreve-network.service" ];
      requires = [ "cloudreve-network.service" ];
    }) // {
    cloudreve-network = {
      description = "Private Docker network for Cloudreve";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      path = [ pkgs.docker ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        docker network inspect cloudreve >/dev/null 2>&1 || docker network create cloudreve >/dev/null
      '';
    };
    docker-cloudreve = {
      path = [ pkgs.docker pkgs.coreutils ];
      preStart = lib.mkAfter ''
        for attempt in {1..60}; do
          if docker exec cloudreve-db pg_isready -U cloudreve -d cloudreve >/dev/null 2>&1 &&
             docker exec cloudreve-redis redis-cli ping >/dev/null 2>&1; then
            exit 0
          fi
          sleep 2
        done
        echo "Cloudreve database or Redis did not become ready" >&2
        exit 1
      '';
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."pan.chumeng.xyz" = {
      enableACME = true;
      forceSSL = true;
      extraConfig = ''
        # Give HTTP/2 uploads room to progress over the high-latency relay.
        http2_body_preread_size 32m;
        client_body_buffer_size 32m;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:5212";
        proxyWebsockets = true;
        recommendedProxySettings = true;
        extraConfig = ''
          client_max_body_size 10G;
          proxy_request_buffering off;
          proxy_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        '';
      };
    };
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "2595248810@qq.com";
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
