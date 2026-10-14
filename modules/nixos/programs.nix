{ config, lib, pkgs, ... }:
let
  cfg = config.my.programs;
in
{
  programs.nix-ld.enable = cfg.nixLd.enable;
  programs.appimage = { enable = cfg.appimage.enable; binfmt = cfg.appimage.enable; };
  programs.wireshark = lib.mkIf cfg.wireshark.enable { enable = true; package = pkgs.wireshark; };
  users.users.chumeng.extraGroups = lib.optional cfg.wireshark.enable "wireshark";
  programs.steam.enable = cfg.steam.enable;
}
