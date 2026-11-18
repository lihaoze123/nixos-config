{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.my.desktop.input;
in
{
  imports = [
    ./xhup.nix
    ./hotwords.nix
  ];

  options.my.desktop.input = {
    speech = {
      enable = mkEnableOption "speech recognition";
      backend = mkOption {
        type = types.enum [ "vocotype" "vinput" ];
        default = "vocotype";
        description = "Fcitx5 speech recognition backend.";
      };
      doubao.enable = mkEnableOption "Doubao speech credentials and worker integration";
    };
    vtype.enable = mkEnableOption "VType (WeChat Pinyin) Fcitx5 addon; the engine is fetched by wetype-setup";
  };

  config = {
    assertions = [
      {
        assertion = !cfg.speech.enable || config.my.desktop.enable;
        message = "my.desktop.input.speech requires my.desktop";
      }
      {
        assertion = !cfg.vtype.enable || config.my.desktop.enable;
        message = "my.desktop.input.vtype requires my.desktop";
      }
      {
        assertion = !cfg.speech.doubao.enable || cfg.speech.enable;
        message = "my.desktop.input.speech.doubao requires my.desktop.input.speech";
      }
      {
        assertion = !(cfg.speech.enable && cfg.speech.backend == "vinput") || cfg.speech.doubao.enable;
        message = "my.desktop.input.speech.backend=vinput requires my.desktop.input.speech.doubao";
      }
    ];
    my.home = ./home.nix;
  };
}
