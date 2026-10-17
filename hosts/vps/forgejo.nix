{ config, ... }:
let
  cfg = config.services.forgejo;
  domain = "git.chumeng.xyz";
in
{
  services.forgejo = {
    enable = true;
    database.type = "sqlite3";
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = domain;
        ROOT_URL = "https://${domain}/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
        # Use the system OpenSSH server and Forgejo-managed authorized_keys.
        START_SSH_SERVER = false;
        SSH_DOMAIN = domain;
        SSH_USER = cfg.user;
        SSH_PORT = 22;
      };
      service = {
        DISABLE_REGISTRATION = true;
        REQUIRE_SIGNIN_VIEW = true;
        DEFAULT_KEEP_EMAIL_PRIVATE = true;
      };
      repository.DEFAULT_PRIVATE = "private";
      openid = {
        ENABLE_OPENID_SIGNIN = false;
        ENABLE_OPENID_SIGNUP = false;
      };
      session.COOKIE_SECURE = true;
      picture = {
        DISABLE_GRAVATAR = true;
        ENABLE_FEDERATED_AVATAR = false;
      };
      # Add runners separately when CI is needed.
      actions.ENABLED = false;
    };
    dump = {
      enable = true;
      interval = "*-*-* 04:31:00";
      type = "tar.gz";
      age = "14d";
    };
  };

  environment.systemPackages = [ cfg.package ];

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString cfg.settings.server.HTTP_PORT}";
      recommendedProxySettings = true;
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 1G;
        proxy_request_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
      '';
    };
  };
}
