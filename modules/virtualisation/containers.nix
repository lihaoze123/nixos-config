{ config, lib, pkgs, ... }:
let
  cfg = config.my.virtualisation;
in
{
  options.my.virtualisation = {
    docker.enable = lib.mkEnableOption "rootless Docker";
    podman.enable = lib.mkEnableOption "Podman and Distrobox";
    waydroid.enable = lib.mkEnableOption "Waydroid";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.docker.enable {
      virtualisation.docker = {
        enable = true;
        rootless = { enable = true; setSocketVariable = true; };
      };
    })
    (lib.mkIf cfg.waydroid.enable {
      virtualisation.waydroid.enable = true;
    })
    (lib.mkIf cfg.podman.enable {
      virtualisation.podman.enable = true;
      virtualisation.containers.registries.settings.unqualified-search-registries = [
        "docker.io"
        "quay.io"
        "ghcr.io"
      ];
      environment.systemPackages = [ pkgs.distrobox ];
    })
  ];
}
