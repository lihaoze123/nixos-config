{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./features.nix
    ./nix-cache
    ./graphical-boot
    ./virtualisation
    ./aria2
    ./niri
    ./edunet
    ./dae
    ./honk
  ];
}
