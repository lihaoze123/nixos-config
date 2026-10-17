{ config, lib, inputs, ... }:
let
  privateCache = inputs.nur-packages.lib.cacheConfig.caches.nur;
  baseCaches = [ "https://mirrors.cernet.edu.cn/nix-channels/store" "https://cache.nixos.org/" ];
  private = config.my.nix.cacheProfile == "private";
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
    # Only import our private cache; project caches (including lantian) stay disabled.
    substituters = lib.mkForce (if private then baseCaches ++ [ privateCache.url ] else [ "https://cache.nixos.org" ]);
    extra-substituters = lib.mkForce [ ];
    extra-trusted-public-keys = lib.optionals private [ privateCache.key ];
    netrc-file = lib.mkIf private config.age.secrets.attic-netrc.path;
  };
}
