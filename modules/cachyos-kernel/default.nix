{ config, lib, inputs, pkgs, ... }:
{
  config = lib.mkIf config.my.features.cachyosKernel.enable {
    nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
    boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore;

  };
}
