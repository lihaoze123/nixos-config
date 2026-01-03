{ config, pkgs, ... }:
let
  tex = (pkgs.texlive.combine {
    inherit (pkgs.texlive) scheme-full fandol;
  });
in
{
  imports = [
    ./vscode.nix
    ./antigravity-tools.nix
  ];

  home.packages = with pkgs;[
    # browser
    microsoft-edge

    # massage
    qq
    wechat
    feishu

    # learn
    anki

    # typeset
    pandoc
    # tex
    tectonic
    typora
    wpsoffice

    # image
    inkscape

    # develop
    dbeaver-bin
    wineWowPackages.stable
    antigravity
    jetbrains.idea
  ];
}
