{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.daeuniverse.nixosModules.dae
    ./subscriber.nix
  ];

  services.dae = {
    enable = true;

    openFirewall = {
      enable = true;
      port = 12345;
    };

    config = builtins.readFile ./config.dae;
  };
}
