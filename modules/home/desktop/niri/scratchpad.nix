{ config, lib, pkgs, osConfig, ... }:
{
  config = lib.mkIf osConfig.my.desktop.enable {
    xdg.configFile."niri/scratchpad.py".source = ./scratchpad.py;
    xdg.configFile."niri/scratchpad.kdl".text =
      let
        command = ''"${pkgs.python3}/bin/python3" "${config.xdg.configHome}/niri/scratchpad.py"'';
      in
      ''
        // IPC scratchpad: this remains an ordinary, visible named workspace.
        workspace "scratch"

        binds {
            Mod+Shift+grave repeat=false hotkey-overlay-title="Scratchpad: 收起当前窗口" { spawn ${command} "stash"; }
            Mod+grave repeat=false hotkey-overlay-title="Scratchpad: 呼出／收起" { spawn ${command} "toggle"; }
            Mod+Ctrl+grave repeat=false hotkey-overlay-title="Scratchpad: 下一个窗口" { spawn ${command} "next"; }
        }
      '';
  };
}
