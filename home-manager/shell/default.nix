{ config, pkgs, pkgs-stable, ... }@inputs:
{
  imports = [
    ./kitty
    ./fish
    ./neovim
    ./claude-code
    ./common.nix
  ];
}
