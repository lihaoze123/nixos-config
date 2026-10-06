{ config, pkgs, inputs, ... }:
{
  imports = [
    ./vscode.nix
    ./file-manager.nix
  ];

  home.packages = with pkgs;[
    # browser
    microsoft-edge

    # tools
    pavucontrol

    # massage
    qq
    wechat

    # learn
    anki
    obsidian

    # typeset
    pandoc
    typst
    tectonic

    # develop
    tmux
  ];
}
