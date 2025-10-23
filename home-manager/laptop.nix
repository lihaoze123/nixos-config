{ config, pkgs, ... }@inputs:
{
  imports = [
    ./home.nix
  ];

  home.packages = with pkgs; [
  ];
}
