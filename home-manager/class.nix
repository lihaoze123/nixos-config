{ config, pkgs, lib, ... }@inputs:
let
  niriConfigPath = "${config.home.homeDirectory}/nixos-config/home-manager/niri/config-class.kdl";
in
{
  imports = [
    ./home.nix
  ];

  home.packages = with pkgs; [
  ];

  xdg.configFile."niri/config.kdl".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink niriConfigPath);
}
