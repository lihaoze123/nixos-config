{ config, lib, pkgs, osConfig, ... }:
let
  inherit (import ./packages.nix { inherit pkgs lib; inherit (config.home) homeDirectory; })
    rime-crane fcitx5-rime-crane rime-user-data-dir rime-user-dictionary-dir
    xhup-lookup-scripts xhup-add-scripts;
  # The DMS launcher plugin is the lookup UI; this keeps the command-line query.
  xhup-lookup = pkgs.writeShellApplication {
    name = "xhup-lookup";
    runtimeInputs = [
      (pkgs.python3.withPackages (ps: [ ps.pyyaml ]))
      pkgs.wl-clipboard
    ];
    text = ''
      exec python3 ${xhup-lookup-scripts}/xhup-lookup.py \
        --data-dir ${rime-crane}/share/rime-data \
        --user-dir ${lib.escapeShellArg rime-user-data-dir} "$@"
    '';
  };
  xhup-add-word = pkgs.writeShellApplication {
    name = "xhup-add-word";
    runtimeInputs = [
      (pkgs.python3.withPackages (ps: [ ps.pyyaml ps.pypinyin ]))
      pkgs.wofi
      pkgs.systemd
      pkgs.libnotify
    ];
    text = ''
      exec python3 ${xhup-add-scripts}/xhup-add-word.py \
        --data-dir ${rime-crane}/share/rime-data \
        --user-dir ${lib.escapeShellArg rime-user-data-dir} \
        --dictionary-dir ${lib.escapeShellArg rime-user-dictionary-dir} \
        --expected-plugin ${fcitx5-rime-crane}/lib/fcitx5/librime.so "$@"
    '';
  };
  # DMS plugin (github:lihaoze123/dms-xhup): lookup, quick add and the
  # part-root chart. The Rime shared data lives in the store, so pass it here;
  # directories set in the plugin settings would take precedence.
  xhup-dms-plugin = pkgs.nur.repos.lihaoze123.dms-xhup.override {
    serviceArgs = [
      "--data-dir"
      "${rime-crane}/share/rime-data"
      "--user-dir"
      rime-user-data-dir
      "--dictionary-dir"
      rime-user-dictionary-dir
      "--expected-plugin"
      "${fcitx5-rime-crane}/lib/fcitx5/librime.so"
    ];
  };
  # Enable the plugin once, but keep a later choice made in the DMS settings UI.
  # A running shell does not load plugins enabled only through this file.
  enable-xhup-dms-plugin = pkgs.writeShellApplication {
    name = "enable-xhup-dms-plugin";
    runtimeInputs = [ pkgs.coreutils pkgs.jq config.programs.dank-material-shell.package ];
    text = ''
      settings=${lib.escapeShellArg "${config.xdg.configHome}/DankMaterialShell/plugin_settings.json"}
      install -d -m 700 "$(dirname "$settings")"
      current='{}'
      if [ -s "$settings" ]; then
        current=$(cat "$settings")
      fi
      if [ "$(jq '.flypyXhup.enabled == null' <<<"$current")" = true ]; then
        tmp=$(mktemp "$settings.XXXXXX")
        jq '.flypyXhup.enabled = true' <<<"$current" >"$tmp"
        chmod 600 "$tmp"
        mv "$tmp" "$settings"
        timeout 5 dms ipc call plugins enable flypyXhup >/dev/null 2>&1 || true
      fi
    '';
  };
in
lib.mkIf osConfig.my.desktop.enable {
  home.packages = [ xhup-lookup xhup-add-word ];

  xdg.configFile."DankMaterialShell/plugins/flypyXhup".source = xhup-dms-plugin;
  home.activation.enableXhupDmsPlugin = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${lib.getExe enable-xhup-dms-plugin}
  '';
}
