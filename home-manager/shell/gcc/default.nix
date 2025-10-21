{ config, pkgs, ... }:
let
  stcpp = pkgs.callPackage ./gcc14-stdcpp-precompiled.nix { };
in
{
  home.packages = [ stcpp ];
}

