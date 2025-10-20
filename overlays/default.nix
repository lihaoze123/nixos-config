{ config, pkgs, lib, ... }:

{
  nixpkgs.overlays = [
    (import ./fcitx5)
  ];
}
