{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./features.nix
    ./virtualisation
    ./aria2
    ./niri
    ./edunet
    ./dae
  ];
}
