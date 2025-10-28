{ config, pkgs, ... }:
{
  imports = [
    ./vscode.nix
  ];

  home.packages = with pkgs;[
    # browser
    microsoft-edge

    # massage
    qq
    wechat

    # typeset
    texlive.combined.scheme-full
    pandoc

    # develop
    dbeaver-bin
  ];
}
