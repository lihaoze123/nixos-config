{ config, pkgs, ... }:
let
    tex = (pkgs.texlive.combine {
        inherit (pkgs.texlive) scheme-full fandol;
    });
in
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
    pandoc
    tex

    # develop
    dbeaver-bin
  ];
}
