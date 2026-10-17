{ config, lib, inputs, ... }:
let
  caches = inputs.nur-packages.lib.cacheConfig;
  private = config.my.nix.cacheProfile == "private";
  # Permanently revoke lantian after the server compromise (upstream issue #110).
  # Keep this guard while older nur-packages locks still advertise the cache.
  projectCaches = lib.filter
    (cache: cache.url != "https://attic.xuyh0120.win/lantian" && !(lib.hasPrefix "lantian:" cache.key))
    (lib.attrValues caches.caches);
in
{
  age.secrets.attic-netrc = lib.mkIf private {
    file = ../../secrets/attic-netrc.age;
    mode = "0400";
  };

  systemd.services.nix-daemon = lib.mkIf private {
    restartTriggers = [ config.age.secrets.attic-netrc.file ];
  };

  nix.settings = {
    substituters = lib.mkForce (if private then caches.base ++ map (cache: cache.url) projectCaches else [ "https://cache.nixos.org" ]);
    extra-substituters = lib.mkForce [ ];
    extra-trusted-public-keys = lib.optionals private (map (cache: cache.key) projectCaches);
    netrc-file = lib.mkIf private config.age.secrets.attic-netrc.path;
  };
}
