{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./aria2
    ./niri
    ./edunet
    ./dae
  ];
}
