{ config, lib, inputs, pkgs, ... }:
let
  cfg = config.my.hardware.cachyos;
in
{
  options.my.hardware.cachyos.enable = lib.mkEnableOption "CachyOS BORE kernel (cached in our private Attic)";

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
    boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore;
  };
}
