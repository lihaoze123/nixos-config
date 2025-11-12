{ config, pkgs, lib, inputs, ... }:

{
  nixpkgs.overlays = [
    (import ./fcitx5)
    inputs.chinese-fonts-overlay.overlays.default
  ];
}
