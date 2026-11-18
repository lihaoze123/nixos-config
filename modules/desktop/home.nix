{ lib, pkgs, osConfig, ... }:
{
  imports = [
    ./kitty
    ./file-manager.nix
    ./viewers.nix
    ./utilities.nix
  ];

  config = lib.mkIf osConfig.my.desktop.enable {
    home.packages = with pkgs; [
      satty
      grim
      slurp
    ];
  };
}
