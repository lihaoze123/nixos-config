{ config, pkgs, pkgs-stable, ... }@inputs:
{
  imports = [
    ./kitty
    ./fish
    ./neovim
    ./gcc
    ./claude-code
    ./common.nix
  ];
}
