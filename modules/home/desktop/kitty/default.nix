{ config, lib, pkgs, osConfig, ... }:
lib.mkIf osConfig.my.desktop.enable {
  xdg.configFile."kitty" = {
    source = ./config;
    recursive = true;
  };
  programs.kitty.enable = true;
}
