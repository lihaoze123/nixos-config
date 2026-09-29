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

    # The daeuniverse flake still pins its release package to v1.0.0.
    package = inputs.daeuniverse.packages.${pkgs.stdenv.hostPlatform.system}.dae.overrideAttrs (old: rec {
      version = "v2.1.1";
      src = pkgs.fetchFromGitHub {
        owner = "daeuniverse";
        repo = "dae";
        rev = version;
        fetchSubmodules = true;
        hash = "sha256-+Gls/lFhOjzfPisgWS96mEevI0mMtQ139Zf4NIik2X8=";
      };
      vendorHash = "sha256-N2noQXRV9Vewie4PiWkjDeX6U2+kF1kQ9L10kZ5X/LI=";
      env = (old.env or { }) // { VERSION = version; };
    });

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
