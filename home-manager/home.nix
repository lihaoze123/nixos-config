{ config, pkgs, system, inputs, osConfig, ... }:
{
  imports = [
    ./fcitx5
    ./shell
    ./niri
    ./applications
    ./applications/easyeffects.nix
    inputs.ragenix.homeManagerModules.default
  ];
  programs.dank-material-shell.enable = osConfig.my.features.desktop.enable;
  programs.vocotype.doubao.enable = osConfig.my.features.doubao.enable;
  home.enableNixpkgsReleaseCheck = false;
  age.identityPaths = [ "/home/chumeng/.ssh/id_rsa" ];

  home.username = "chumeng";
  home.homeDirectory = "/home/chumeng";

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

  programs.git = {
    enable = true;
    settings.user = {
      name = "chumeng";
      email = "2595248810@qq.com";
    };
  };

  home.stateVersion = "25.05";
}
