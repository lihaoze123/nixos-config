{ config, pkgs, ... }:
{
  home.packages = with pkgs;[
    # browser
    microsoft-edge

    # massaging app
    qq
    wechat
  ];
}
