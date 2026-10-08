{ config, lib, pkgs, osConfig, ... }:
lib.mkIf osConfig.my.features.desktop.enable {
  xdg.configFile."kitty" = {
    source = ./config;
    recursive = true;
  };
  programs.kitty.enable = true;
}
