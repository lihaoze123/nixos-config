{ config, pkgs, ... }@inputs:
{
  imports = [
    ../../home-manager/home.nix
  ];

  home.packages = with pkgs; [
  ];
}
