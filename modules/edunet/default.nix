{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.edunet.nixosModules.default
  ];

  config = lib.mkIf config.my.features.edunet.enable {
    age.secrets.edunet-env = {
      file = ../../secrets/edunet-env.age;
      path = "/etc/edunet/edunet.env";
      symlink = false;
    };

    services.edunet = {
      enable = true;
      environmentFile = config.age.secrets.edunet-env.path;
      interval = "2min";
    };
  };
}
