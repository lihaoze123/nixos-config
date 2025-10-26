{ config, pkgs, ... }:
{
  imports = [
    ./vscode.nix
  ];

  home.packages = with pkgs;[
    # browser
    microsoft-edge

    # massaging app
    qq
    wechat
  ];
}
