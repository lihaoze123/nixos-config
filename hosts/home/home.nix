{ config, pkgs, pkgs-stable, lib, ... }@inputs:
let
  niriConfigPath = "${config.home.homeDirectory}/nixos-config/hosts/home/config-home.kdl";
in
{
  imports = [
    ../../home-manager/home.nix
  ];

  home.packages = with pkgs; [
  ];

  xdg.configFile."niri/config.kdl".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink niriConfigPath);
}
