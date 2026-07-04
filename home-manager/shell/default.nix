{ config, pkgs, pkgs-stable, ... }@inputs:
{
  imports = [
    ./kitty
    ./fish
    ./neovim
    ./gcc
    ./rust.nix
    ./claude-code
    ./agent-browser.nix
    ./common.nix
  ];
}
