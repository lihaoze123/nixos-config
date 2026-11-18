{ config, lib, inputs, myLib, ... }:
let
  cfg = config.my.network.edunet;
in
{
  imports = [
    inputs.nur.repos.lihaoze123.modules.nixos.edunet
  ];

  options.my.network.edunet.enable = lib.mkEnableOption "campus network authentication";

  config = lib.mkIf cfg.enable {
    age.secrets.edunet-env = {
      file = myLib.secret "edunet-env.age";
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
