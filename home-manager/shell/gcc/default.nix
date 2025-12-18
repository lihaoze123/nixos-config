{ config, pkgs, pkgs-stable, ... }:
{
  home.packages = [
    # NOTE Make sure that clangd is not installed by mason
    pkgs-stable.clang-tools # https://github.com/nixos/nixpkgs/issues/463367
    pkgs.gcc
  ];
}

