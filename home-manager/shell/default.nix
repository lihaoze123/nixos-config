{ config, pkgs, pkgs-stable, ... }@inputs:
{
  imports = [
    ./kitty
    ./fish
    ./neovim
    ./gcc
    ./claude-code
    ./agent-browser.nix
    ./common.nix
  ];
}
