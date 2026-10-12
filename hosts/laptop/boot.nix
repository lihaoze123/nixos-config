{ config, lib, ... }:
{
  config = lib.mkMerge [
    (lib.mkIf config.my.features.graphicalBoot.enable {
      # Start Plymouth on the Intel KMS device with native 2x theme assets.
      boot.initrd.kernelModules = [ "i915" ];
      my.graphicalBoot.scale = 2;
    })
  ];
}
