{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.daeuniverse.nixosModules.dae
  ];

  config = {
    age.secrets.dae-nodes = lib.mkIf (config.my.features.dae.enable || config.my.features.honk.enable) {
      file = ../../secrets/dae-nodes.age;
      path = "/etc/dae/nodes.dae";
      symlink = false;
    };

    services.dae = lib.mkIf config.my.features.dae.enable {
      enable = true;

      # Use the release maintained by nixpkgs; the upstream flake's default lags behind.
      package = pkgs.dae;

      openFirewall = {
        enable = true;
        port = 12345;
      };

      assetsPath = toString (pkgs.symlinkJoin {
        name = "dae-assets";
        paths = [ "${inputs.geodb}" ];
      });

      config = import ./render-config.nix { inherit config lib; };
    };

    systemd.services.dae = lib.mkIf config.my.features.dae.enable {
      after = [ "agenix.service" ];
      requires = [ "agenix.service" ];
      conflicts = [ "honk.service" ];
      restartTriggers = [ config.age.secrets.dae-nodes.file ];
    };
  };
}
