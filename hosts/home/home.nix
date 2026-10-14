{ config, lib, osConfig, ... }:
let
  niriConfigPath = "${config.home.homeDirectory}/nixos-config/hosts/home/config-home.kdl";
in
{
  # DMS loads niri/config.kdl and includes this host's layout as base.kdl.
  xdg.configFile."niri/base.kdl" = lib.mkIf osConfig.my.desktop.enable {
    source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink niriConfigPath);
  };
}
