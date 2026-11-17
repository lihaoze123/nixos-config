{ config, lib, ... }:
let
  cfg = config.my.desktop.easyeffects;
in
{
  options.my.desktop.easyeffects.enable = lib.mkEnableOption "EasyEffects microphone denoising";

  config = {
    assertions = [
      {
        assertion = !cfg.enable || config.my.desktop.enable;
        message = "my.desktop.easyeffects requires my.desktop";
      }
    ];
    my.home = ./home.nix;
  };
}
