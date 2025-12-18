{ config, pkgs, pkgs-stable, ... }@inputs:
{
  imports = [
    ../../home-manager/home.nix
  ];

  home.packages = with pkgs; [
  ];
}
