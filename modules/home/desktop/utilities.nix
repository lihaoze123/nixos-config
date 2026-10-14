{ lib, pkgs, osConfig, ... }:
lib.mkIf osConfig.my.desktop.utilities.enable {
  home.packages = with pkgs; [
    ghostty
    neovide
    pavucontrol
    gnome-disk-utility
    baobab
    kdePackages.filelight
    microsoft-edge
  ];
}
