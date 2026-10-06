{ config, lib, pkgs, ... }:
let
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
  dankscale = fetchPlugin "dwright134" "dms-dankscale"
    "bddebf0e2935ba23b0614ff9af5bf8f4ed6d3d9f"
    "sha256-o5kcFV7VAmHJqsKgnjDuuryubnuI9U+GQIPOlENZ5ao=";
  officialPlugins = fetchPlugin "AvengeMedia" "dms-plugins"
    "a8a508bc371e7c3f2c7862d8840b88cf5c63978f"
    "sha256-3nHfkGzmmq8JpN7bmO8Z5zIumvx8dzwS1GtQ6V0XgMg=";
  initialize = pkgs.writeShellApplication {
    name = "initialize-dms-plugins";
    runtimeInputs = [ pkgs.python3 pkgs.systemd ];
    text = ''
      exec python3 ${./initialize-plugins.py} ${lib.escapeShellArg config.xdg.configHome}
    '';
  };
in
{
  config = lib.mkIf config.programs.dank-material-shell.enable {
    home.packages = [ pkgs.translate-shell ];
    xdg.configFile = {
      "DankMaterialShell/plugins/calculator".source = calculator;
      "DankMaterialShell/plugins/dankTranslate".source = translate;
      "DankMaterialShell/plugins/dankscale".source = dankscale;
      "DankMaterialShell/plugins/dankPomodoroTimer".source = "${officialPlugins}/DankPomodoroTimer";
    };
    home.activation.initializeDmsPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe initialize}
    '';
  };
}
