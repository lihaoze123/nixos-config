{ config, pkgs, ... }@inputs:
{
  imports = [
    ./kitty
    ./fish
    ./neovim
    ./claude-code
    ./common.nix
  ];
}
