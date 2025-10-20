{ config, pkgs, ... }:
{
    xdg.configFile."kitty" = {
        source = ./config;
	recursive = true;
    };
    programs.kitty.enable = true;
}
