{ config, lib, pkgs, inputs, ... }:
let
  parser = (import ./packages.nix { inherit pkgs lib inputs; }).termsParser;
  backend = pkgs.writeShellApplication {
    name = "vocotype-hotwords-service";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./dms-hotwords/backend.py} --parser ${parser}/bin/vocotype-terms-parser "$@"
    '';
  };
  plugin = pkgs.runCommand "dms-vocotype-hotwords" { passthru = { inherit parser; }; } ''
    mkdir -p $out
    cp ${./dms-hotwords/plugin.json} $out/plugin.json
    cp ${./dms-hotwords/HotwordsDaemon.qml} $out/HotwordsDaemon.qml
    cp ${./dms-hotwords/HotwordsLauncher.qml} $out/HotwordsLauncher.qml
    echo 'var command = ${builtins.toJSON [ (lib.getExe backend) ]};' > $out/config.js
  '';
in
{
  config = lib.mkIf (config.my.desktop.enable && config.my.desktop.input.speech.enable) {
    my.desktop.dms.plugins.vocotypeHotwords = {
      source = plugin;
      liveEnableViaIpc = true;
    };
    my.home = lib.setDefaultModuleLocation ./hotwords.nix {
      xdg.configFile."niri/speech-bindings.kdl".text = ''
        binds {
            Mod+Ctrl+T hotkey-overlay-title="语音快速加热词" { spawn "dms" "ipc" "call" "vocotypeHotwords" "add"; }
        }
      '';
    };
  };
}
