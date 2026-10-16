{ config, lib, pkgs, ... }:
let
  uid = 995;
  gid = 995;
  stateDir = "/var/lib/media-stack";
  mediaDir = "/srv/media";
  containers = [ "qbittorrent" "autobangumi" "emby" ];
  containerOptions = [
    "--network=media-stack"
    "--security-opt=no-new-privileges"
    "--log-opt=max-size=10m"
    "--log-opt=max-file=3"
  ];
in
{
  age.secrets.media-credentials = {
    file = ../../secrets/media-credentials.age;
    mode = "0400";
  };

  users.groups.media = { inherit gid; };
  users.users.media = {
    inherit uid;
    group = "media";
    isSystemUser = true;
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 media media - -"
    "d ${stateDir}/autobangumi 0700 media media - -"
    "d ${stateDir}/autobangumi/config 0700 media media - -"
    "d ${stateDir}/autobangumi/data 0700 media media - -"
    "d ${stateDir}/qbittorrent 0700 media media - -"
    "d ${stateDir}/emby 0700 media media - -"
    "d ${mediaDir} 0750 media media - -"
    "d ${mediaDir}/Bangumi 0750 media media - -"
    "d ${mediaDir}/incomplete 0750 media media - -"
  ];

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      qbittorrent = {
        log-driver = "json-file";
        image = "lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed";
        ports = [ "127.0.0.1:8080:8080" "51413:51413/tcp" "51413:51413/udp" ];
        environment = {
          PUID = toString uid;
          PGID = toString gid;
          TZ = "Asia/Shanghai";
          UMASK = "027";
          WEBUI_PORT = "8080";
          TORRENTING_PORT = "51413";
        };
        volumes = [ "${stateDir}/qbittorrent:/config" "${mediaDir}:/downloads" ];
        extraOptions = containerOptions;
      };
      autobangumi = {
        log-driver = "json-file";
        image = "ghcr.io/estrellaxd/auto_bangumi:3.3.6@sha256:3d8b9e5ebf344a8ca96d0f158f6ad95da430ad27b7c85badb791d3c9fa86a9d0";
        dependsOn = [ "qbittorrent" ];
        ports = [ "127.0.0.1:7892:7892" ];
        environment = {
          PUID = toString uid;
          PGID = toString gid;
          TZ = "Asia/Shanghai";
          UMASK = "027";
        };
        volumes = [
          "${stateDir}/autobangumi/config:/app/config"
          "${stateDir}/autobangumi/data:/app/data"
        ];
        extraOptions = containerOptions;
      };
      emby = {
        log-driver = "json-file";
        image = "emby/embyserver:4.10.0.40@sha256:3aafff933d3f28d23ed0bc201022abe71c0aa80deb17177566c726b9bbc686c6";
        ports = [ "127.0.0.1:8096:8096" ];
        environment = {
          UID = toString uid;
          GID = toString gid;
          GIDLIST = toString gid;
          TZ = "Asia/Shanghai";
        };
        volumes = [ "${stateDir}/emby:/config" "${mediaDir}/Bangumi:/media/Bangumi:ro" ];
        extraOptions = containerOptions;
      };
    };
  };

  systemd.services = lib.genAttrs (map (name: "docker-${name}") containers)
    (_: {
      after = [ "media-stack-prepare.service" ];
      requires = [ "media-stack-prepare.service" ];
    }) // {
    media-stack-prepare = {
      description = "Prepare media network and first-run downloader credentials";
      after = [ "docker.service" "agenix.service" "systemd-tmpfiles-setup.service" ];
      requires = [ "docker.service" ];
      path = [ pkgs.docker ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      script = ''
        docker network inspect media-stack >/dev/null 2>&1 || docker network create media-stack >/dev/null
        ${pkgs.python3}/bin/python3 ${./media-seed.py} ${config.age.secrets.media-credentials.path}
      '';
    };
    media-stack-initialize = {
      description = "Initialize media accounts and library before public access";
      wantedBy = [ "multi-user.target" ];
      after = map (name: "docker-${name}.service") containers;
      requires = map (name: "docker-${name}.service") containers;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "media-stack";
        RuntimeDirectoryMode = "0755";
        UMask = "0077";
        TimeoutStartSec = 600;
        ExecStart = "${pkgs.python3}/bin/python3 ${./media-initialize.py} ${config.age.secrets.media-credentials.path}";
      };
    };
  };

  services.nginx.virtualHosts = lib.mapAttrs
    (_: port: {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
        recommendedProxySettings = true;
        extraConfig = ''
          # Keep first-run account setup private, including after data loss.
          if (!-f /run/media-stack/ready) { return 503; }
          client_max_body_size 50m;
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_cookie_flags token secure httponly samesite=strict;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        '';
      };
    })
    {
      "ab.chumeng.xyz" = 7892;
      "emby.chumeng.xyz" = 8096;
    };

  # Nginx provides HTTPS; only the downloader's peer port is published directly.
  networking.firewall.allowedTCPPorts = [ 51413 ];
  networking.firewall.allowedUDPPorts = [ 51413 ];
}
