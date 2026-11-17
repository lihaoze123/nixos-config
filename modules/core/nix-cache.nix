{ config, lib, pkgs, myLib, ... }:
let
  # Keep cache trust local; NUR repositories do not configure substituters.
  privateCache = {
    url = "https://cache.chumeng.xyz/nur";
    key = "nur:dJh05Op2+iv3GCHoaF2+1FfQtqcUZzf/4v/ZTaLHomY=";
  };
  baseCaches = [ "https://mirrors.cernet.edu.cn/nix-channels/store" "https://cache.nixos.org/" ];
  private = config.my.nix.cacheProfile == "private";
in
{
  options.my.nix.cacheProfile = lib.mkOption {
    type = lib.types.enum [ "private" "public" ];
    default = "private";
    description = "Cache policy; private enables the configured public project caches and Attic by default; public uses only cache.nixos.org and requires no private cache credentials.";
  };

  config = {
    age.secrets.attic-netrc = lib.mkIf private {
      file = myLib.secret "attic-netrc.age";
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

    my.home = lib.setDefaultModuleLocation ./nix-cache.nix ({ config, ... }:
      lib.mkIf private {
        age.secrets.attic-upload-token = {
          file = myLib.secret "attic-upload-token.age";
          path = "${config.xdg.dataHome}/attic/token";
        };
        xdg.configFile."attic/config.toml".text = ''
          default-server = "personal"

          [servers.personal]
          endpoint = "https://cache.chumeng.xyz/"
          token-file = "${config.age.secrets.attic-upload-token.path}"
        '';
        home.packages = [ pkgs.attic-client ];
      });
  };
}
