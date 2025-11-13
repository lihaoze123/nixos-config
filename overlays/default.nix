{ config, pkgs, lib, inputs, ... }:

{
  nixpkgs.overlays = [
    inputs.chinese-fonts-overlay.overlays.default
  ];
}
