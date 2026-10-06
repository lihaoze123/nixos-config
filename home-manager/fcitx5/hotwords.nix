{ config, lib, pkgs, inputs, ... }:
let
  useDms = lib.attrByPath [ "programs" "dank-material-shell" "enable" ] false config;
  parser = pkgs.stdenv.mkDerivation {
    pname = "vocotype-terms-parser";
    version = "1";
    dontUnpack = true;
    buildInputs = [ pkgs.nlohmann_json ];
    buildPhase = ''
      $CXX -std=c++20 -O2 -I${inputs.vocotype}/src/common/include \
        ${./dms-hotwords/terms-parser.cpp} \
        ${inputs.vocotype}/src/common/src/terms_yaml.cpp -o vocotype-terms-parser
    '';
    installPhase = ''
      install -Dm755 vocotype-terms-parser $out/bin/vocotype-terms-parser
    '';
  };
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
  enable = pkgs.writeShellApplication {
    name = "enable-vocotype-hotwords-plugin";
    runtimeInputs = [ pkgs.coreutils pkgs.jq config.programs.dank-material-shell.package ];
    text = ''
      settings=${lib.escapeShellArg "${config.xdg.configHome}/DankMaterialShell/plugin_settings.json"}
      install -d -m 700 "$(dirname "$settings")"
      current='{}'
      if [ -s "$settings" ]; then current=$(cat "$settings"); fi
      if [ "$(jq '.vocotypeHotwords.enabled == null' <<<"$current")" = true ]; then
        tmp=$(mktemp "$settings.XXXXXX")
        jq '.vocotypeHotwords.enabled = true' <<<"$current" >"$tmp"
        chmod 600 "$tmp"
        mv "$tmp" "$settings"
        timeout 5 dms ipc call plugin-scan scan >/dev/null 2>&1 || true
        timeout 5 dms ipc call plugins enable vocotypeHotwords >/dev/null 2>&1 || true
      fi
    '';
  };
in
{
  config = lib.mkIf useDms {
    xdg.configFile."DankMaterialShell/plugins/vocotypeHotwords".source = plugin;
    home.activation.enableVocotypeHotwordsPlugin = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe enable}
    '';
  };
}
