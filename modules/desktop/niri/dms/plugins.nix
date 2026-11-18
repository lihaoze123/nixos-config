{ config, lib, pkgs, osConfig, ... }:
let
  registeredPlugins = osConfig.my.desktop.dms.plugins;
  jsonFormat = pkgs.formats.json { };
  pluginSpecs = jsonFormat.generate "dms-plugin-specs.json" (
    lib.mapAttrs
      (
        _: pluginCfg: {
          inherit (pluginCfg)
            defaultEnabled
            barWidget
            barWidgetOrder
            defaultSettings
            liveEnableViaIpc
            ;
        }
      )
      registeredPlugins
  );
  initialize = pkgs.writeShellApplication {
    name = "initialize-dms-plugins";
    runtimeInputs = [
      pkgs.python3
      pkgs.systemd
      pkgs.coreutils
      config.programs.dank-material-shell.package
    ];
    text = ''
      exec python3 ${./initialize-plugins.py} \
        ${lib.escapeShellArg config.xdg.configHome} \
        ${pluginSpecs}
    '';
  };
in
{
  config = lib.mkIf config.programs.dank-material-shell.enable {
    home.packages = [ pkgs.translate-shell ];
    xdg.configFile = lib.mapAttrs'
      (
        id: pluginCfg:
          lib.nameValuePair "DankMaterialShell/plugins/${id}" {
            inherit (pluginCfg) source;
          }
      )
      registeredPlugins;
    home.activation.initializeDmsPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe initialize}
    '';
  };
}
