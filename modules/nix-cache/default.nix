{ config, lib, inputs, ... }:
let
  caches = inputs.nur-packages.lib.cacheConfig;
in
{
  age.secrets.r2-cache-credentials = {
    file = ../../secrets/r2-cache-credentials.age;
    mode = "0400";
  };

  systemd.services.nix-daemon = {
    environment.AWS_SHARED_CREDENTIALS_FILE =
      config.age.secrets.r2-cache-credentials.path;
    restartTriggers = [ config.age.secrets.r2-cache-credentials.file ];
  };

  nix.settings = {
    substituters = lib.mkForce caches.base;
    extra-substituters = lib.mkForce [ ];
    trusted-substituters = map (cache: cache.url) (lib.attrValues caches.caches);
    extra-trusted-public-keys = map (cache: cache.key) (lib.attrValues caches.caches);
  };
}
