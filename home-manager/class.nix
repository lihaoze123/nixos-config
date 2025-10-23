{ config, pkgs, ... }@inputs:
let
  niriConfigPath = "${config.home.homeDirectory}/nixos-config/home-manager/niri/config-class.kdl";
in
{
  imports = [
    ./home.nix
  ];

  home.packages = with pkgs; [
  ];

  xdg.configFile."niri/config.kdl".source = config.lib.file.mkOutOfStoreSymlink niriConfigPath;
}
