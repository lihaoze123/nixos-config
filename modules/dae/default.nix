{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.daeuniverse.nixosModules.dae
  ];

  age.secrets.dae-config = {
    file = ../../secrets/dae-config.age;
    path = "/etc/dae/config.dae";
    symlink = false;
  };

  services.dae = {
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

    configFile = config.age.secrets.dae-config.path;
  };
}
