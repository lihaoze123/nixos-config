{ config, pkgs, ... }:
let
  user = "blog-upload";
  root = "/srv/blog";
  receiver = pkgs.writeShellApplication {
    name = "blog-upload";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./blog-upload.py} ${root}
    '';
  };
  uploadKey = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./blog-upload.pub);
in
{
  age.secrets.blog-preview-htpasswd = {
    file = ../../secrets/blog-preview-htpasswd.age;
    owner = "nginx";
    group = "nginx";
    mode = "0400";
  };

  users.groups.${user} = { };
  users.users.${user} = {
    isSystemUser = true;
    group = user;
    home = "/var/lib/${user}";
    createHome = true;
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      ''restrict,command="${receiver}/bin/blog-upload" ${uploadKey}''
    ];
  };
  users.users.nginx.extraGroups = [ user ];

  systemd.tmpfiles.rules = [
    "d ${root} 0750 ${user} ${user} -"
    "d ${root}/cms 0750 ${user} ${user} -"
    "d ${root}/previews 0750 ${user} ${user} -"
    "d ${root}/state 0700 ${user} ${user} -"
    "d ${root}/staging 0700 ${user} ${user} 1d"
  ];

  services.nginx.virtualHosts = {
    "cms.chumeng.xyz" = {
      enableACME = true;
      forceSSL = true;
      root = "${root}/cms/current";
      locations."/" = {
        tryFiles = "$uri $uri/ =404";
        extraConfig = ''
          add_header Cache-Control "no-store" always;
          add_header Referrer-Policy "no-referrer" always;
          add_header X-Content-Type-Options "nosniff" always;
          add_header X-Frame-Options "DENY" always;
        '';
      };
    };
    "preview.chumeng.xyz" = {
      enableACME = true;
      forceSSL = true;
      basicAuthFile = config.age.secrets.blog-preview-htpasswd.path;
      extraConfig = ''
        add_header Cache-Control "private, no-store" always;
        add_header Referrer-Policy "no-referrer" always;
        add_header X-Robots-Tag "noindex, nofollow, noarchive" always;
        add_header X-Content-Type-Options "nosniff" always;
      '';
      locations = {
        # The capture is digits only; each PR has an atomically replaced current symlink.
        "~ ^/pr-([1-9][0-9]*)/(.*)$" = {
          alias = "${root}/previews/pr-$1/current/$2";
          index = "index.html";
        };
        "/".return = "404";
      };
    };
  };
}
