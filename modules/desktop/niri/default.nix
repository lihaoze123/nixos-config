{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  fetchPlugin = owner: repo: rev: hash: pkgs.fetchFromGitHub {
    inherit owner repo rev hash;
  };
  calculator = fetchPlugin "rochacbruno" "DankCalculator"
    "c9fbbe921e9afeb92f4e92390e9fc05f006f0373"
    "sha256-dqFTvNogWsqK82EhgMIbJB70R5TgcRiA3Elx1LkSia8=";
  translateSrc = fetchPlugin "alcxyz" "DankTranslate"
    "5f7d40b0902985c4990f3da24f373ba28a0e1895"
    "sha256-UGIIA/rQW+vVqroefGXCxiP6BgZO9nY6UeeN3Xjjfok=";
  translate = pkgs.runCommand "dms-translate" { } ''
    cp -r ${translateSrc} $out
    chmod -R u+w $out
    # DMS is already running when this is first installed; do not rely on
    # its old PATH containing a newly installed translate-shell package.
    substituteInPlace $out/DankTranslate.qml \
      --replace-fail 'command -v trans' 'test -x ${pkgs.translate-shell}/bin/trans' \
      --replace-fail 'exec trans ' 'exec ${pkgs.translate-shell}/bin/trans '
  '';
in
{
  options.my.desktop.dms = {
    officialPluginsRepo = mkOption {
      internal = true;
      readOnly = true;
      type = types.package;
      default = fetchPlugin "AvengeMedia" "dms-plugins"
        "a8a508bc371e7c3f2c7862d8840b88cf5c63978f"
        "sha256-3nHfkGzmmq8JpN7bmO8Z5zIumvx8dzwS1GtQ6V0XgMg=";
      description = "Shared upstream AvengeMedia/dms-plugins repository.";
    };

    plugins = mkOption {
      internal = true;
      default = { };
      description = "DMS plugins registered by desktop and feature modules.";
      type = types.attrsOf (types.submodule {
        options = {
          source = mkOption {
            type = types.path;
            description = "Directory linked to DankMaterialShell/plugins/<id>.";
          };
          defaultEnabled = mkOption {
            type = types.bool;
            default = true;
            description = "Enable once when plugin_settings.json has no enabled field yet, preserving later GUI edits.";
          };
          barWidget = mkOption {
            type = types.bool;
            default = false;
            description = "Insert into the primary enabled bar's rightWidgets on first enable and try-restart dms.service.";
          };
          barWidgetOrder = mkOption {
            type = types.int;
            default = 100;
            description = "Sort weight when first injecting into rightWidgets.";
          };
          defaultSettings = mkOption {
            type = types.attrsOf types.anything;
            default = { };
            description = "Missing keys populated with setdefault semantics on every activation, without overwriting user edits.";
          };
          liveEnableViaIpc = mkOption {
            type = types.bool;
            default = false;
            description = "Scan and live-enable via dms ipc on first enable when dms.service was not restarted.";
          };
        };
      });
    };
  };

  config = lib.mkMerge [
    {
      my.home = ./home.nix;
    }
    (lib.mkIf config.my.desktop.enable {
      my.desktop.dms.plugins = {
        calculator.source = calculator;
        dankTranslate = {
          source = translate;
          defaultSettings.defaultLang = "zh-CN";
        };
        dankPomodoroTimer = {
          source = "${config.my.desktop.dms.officialPluginsRepo}/DankPomodoroTimer";
          barWidget = true;
          barWidgetOrder = 20;
        };
      };
    })
  ];
}
