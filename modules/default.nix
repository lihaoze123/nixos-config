{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./features.nix
    ./graphical-boot
    ./virtualisation
    ./aria2
    ./niri
    ./edunet
    ./dae
  ];
}
