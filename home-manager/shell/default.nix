{ config, pkgs, ... }@inputs:
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
