{ config, lib, pkgs, ... }:
let
  # GPU containers need the NVIDIA driver even without a graphical session.
  useNvidia = config.my.desktop.enable || config.my.virtualisation.docker.enable;
in
{
  imports = [
    ./hardware-configuration.nix
    ./services.nix
    ../../profiles/personal.nix
  ];

  my = {
    network.proxy.backend = "dae";
    # wallpaperEngine, podman, libvirt and waydroid stay off here.
    desktop.outputs."DP-1" = {
      mode = "3440x1440@144.0";
      scale = 1.2;
      position = { x = 1280; y = 0; };
    };
  };

  hardware.graphics.enable = useNvidia;
  services.xserver.videoDrivers = lib.mkIf useNvidia [ "nvidia" ];
  hardware.nvidia = lib.mkIf useNvidia {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Docker with NVIDIA support
  hardware.nvidia-container-toolkit.enable = config.my.virtualisation.docker.enable;
  virtualisation.docker.extraPackages = lib.mkIf config.my.virtualisation.docker.enable [ pkgs.nvidia-container-toolkit ];
}
