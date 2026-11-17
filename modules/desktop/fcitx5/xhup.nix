{ config, lib, pkgs, ... }:
let
  inherit (import ./packages.nix {
    inherit pkgs lib;
    homeDirectory = config.my.user.home;
  })
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
in
{
  config = lib.mkIf config.my.desktop.enable {
    my.desktop.dms.plugins.flypyXhup = {
      source = xhup-dms-plugin;
      liveEnableViaIpc = true;
    };
    my.home = lib.setDefaultModuleLocation ./xhup.nix {
      home.packages = [ xhup-lookup xhup-add-word ];
    };
  };
}
