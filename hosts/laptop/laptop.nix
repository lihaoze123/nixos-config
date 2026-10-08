{ config, pkgs, pkgs-stable, osConfig, ... }@inputs:
{
  imports = [
    ../../home-manager/home.nix
  ];

  home.packages = with pkgs; [
  ];
}
