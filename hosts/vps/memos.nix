{ config, lib, pkgs, ... }:
let
  cfg = config.services.memos;
  domain = "memos.chumeng.xyz";
  settingsDir = pkgs.linkFarm "memos-settings" (map
    (setting: {
      name = "memos-instance-setting-${setting.name}.json";
      path = pkgs.writeText "memos-${setting.name}.json" (builtins.toJSON setting.value);
    })
    [
      {
        name = "access";
        value = {
          key = "ACCESS";
          accessSetting.accessMode = "INSTANCE_ACCESS_MODE_PRIVATE";
        };
      }
      {
        name = "general";
        value = {
          key = "GENERAL";
          generalSetting = {
            disallowUserRegistration = true;
            disallowPasswordAuth = false;
            weekStartDayOffset = 1;
          };
        };
      }
    ]);
in
{
  services.memos = {
    enable = true;
    settings = {
      MEMOS_ADDR = "127.0.0.1";
      MEMOS_PORT = "5230";
      MEMOS_DATA = cfg.dataDir;
      MEMOS_DRIVER = "sqlite";
      MEMOS_INSTANCE_URL = "https://${domain}";
    };
  };

  systemd.services.memos = {
    restartTriggers = [ settingsDir ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = lib.mkForce "5s";
      # Scope deployment-managed settings to this service's mount namespace.
      BindReadOnlyPaths = [ "${settingsDir}:/etc/secrets" ];
    };
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${cfg.settings.MEMOS_PORT}";
      recommendedProxySettings = true;
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 32m;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
      '';
    };
  };
}
