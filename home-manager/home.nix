{ config, pkgs, ... }@inputs:
{
  imports = [
    ./fcitx5
    ./shell
    ./niri
    ./applications
    inputs.ragenix.homeManagerModules.default
  ];
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
    userName = "chumeng";
    userEmail = "2595248810@qq.com";
  };

  home.stateVersion = "25.05";
}
