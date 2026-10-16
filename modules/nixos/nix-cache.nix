{ config, lib, inputs, ... }:
let
  caches = inputs.nur-packages.lib.cacheConfig;
  private = config.my.nix.cacheProfile == "private";
in
{
  age.secrets.r2-cache-credentials = lib.mkIf private {
    file = ../../secrets/r2-cache-credentials.age;
    mode = "0400";
  };

  systemd.services.nix-daemon = lib.mkIf private {
    environment.AWS_SHARED_CREDENTIALS_FILE =
      config.age.secrets.r2-cache-credentials.path;
    restartTriggers = [ config.age.secrets.r2-cache-credentials.file ];
  };

  nix.settings = {
    substituters = lib.mkForce (if private then caches.base else [ "https://cache.nixos.org" ]);
    extra-substituters = lib.mkForce [ ];
    trusted-substituters = lib.optionals private (map (cache: cache.url) (lib.attrValues caches.caches));
    extra-trusted-public-keys = lib.optionals private (map (cache: cache.key) (lib.attrValues caches.caches));
  };
}
