{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # NOTE Make sure that clangd is not installed by mason
    clang-tools
    gcc
  ];
}

