{ config, lib, pkgs, system, inputs, osConfig, ... }:
{
  imports = [
    ./shell
    ./desktop
    ./ai
    ./apps.nix
    inputs.ragenix.homeManagerModules.default
  ];
  programs.dank-material-shell.enable = osConfig.my.desktop.enable;
  programs.vocotype.doubao.enable = osConfig.my.input.speech.doubao.enable;
  home.enableNixpkgsReleaseCheck = false;
  age.identityPaths = lib.mkDefault [ "/home/chumeng/.ssh/id_rsa" ];

  home.username = "chumeng";
  home.homeDirectory = "/home/chumeng";
  xdg.configFile."nix/nix.conf".text = ''
    # Project caches are selected explicitly by nur-with-caches.
    substituters = ${pkgs.lib.concatStringsSep " " inputs.nur-packages.lib.cacheConfig.base}
  '';

  home.packages = with pkgs;[
    # archives
    zip
    xz
    unzip
    p7zip

    # secret
    inputs.ragenix.packages."${system}".default

    # misc
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    # nix related
    nix-output-monitor
  ];

  home.stateVersion = "25.05";
}
