{ config, lib, inputs, pkgs, ... }:
{
  config = lib.mkMerge [
    (lib.mkIf config.my.features.cachyosKernel.enable {
      nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
      boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

      nix.settings = {
        substituters = [ "https://attic.xuyh0120.win/lantian" ];
        trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
      };
    })
    (lib.mkIf config.my.features.graphicalBoot.enable {
      # Start Plymouth on the Intel KMS device with native 2x theme assets.
      boot.initrd.kernelModules = [ "i915" ];
      my.graphicalBoot.scale = 2;
    })
  ];
}
