{ config, pkgs, inputs, ... }:
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
    inputs.browser-previews.packages.${pkgs.system}.google-chrome-dev
    inputs.browser-previews.packages.${pkgs.system}.google-chrome
    microsoft-edge
    inputs.browser-previews.packages.${pkgs.system}.google-chrome-beta

    # tools
    pavucontrol
    moonlight-qt
    rustdesk-flutter

    # massage
    qq
    wechat
    feishu

    # media
    spotify

    # learn
    anki
    obsidian

    # typeset
    pandoc
    typst
    # tex
    tectonic
    typora
    # wpsoffice
    libreoffice-qt

    # image
    inkscape

    # develop
    tmux
    dbeaver-bin
    antigravity
    jetbrains.idea
    jetbrains.rust-rover
    cherry-studio
    rtk
  ];
}
