{ config, pkgs, ... }@inputs:
{
  imports = [
    ./fcitx5
    ./shell
    inputs.ragenix.homeManagerModules.default
  ];

  age.identityPaths = [ "/home/chumeng/.ssh/id_rsa" ];

  home.username = "chumeng";
  home.homeDirectory = "/home/chumeng";

  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 172;
  };

  home.packages = with pkgs;[
    # browser
    microsoft-edge

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
