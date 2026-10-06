{ config, pkgs, pkgs-stable, ... }@inputs:
{
  imports = [
    ../../home-manager/home.nix
    ../../home-manager/applications/easyeffects.nix
  ];

  programs.dank-material-shell.enable = true;
  programs.vocotype.doubao.enable = true;

  home.packages = with pkgs; [
  ];
}
