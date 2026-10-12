{ config, lib, pkgs, inputs, osConfig, ... }:
let
  enabled = osConfig.my.features.desktop.enable && osConfig.my.features.speech.enable;
  vinput = inputs.fcitx5-vinput.packages.${pkgs.stdenv.hostPlatform.system}.fcitx5-vinput-lite;
  providerSource = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/xifan2333/vinput-registry/5c48be07249cc66b7c21673350ad6f6ef1771a9c/resources/providers/doubao/streaming/entry.py";
    hash = "sha256-Gzp0i2GVghGKNuAGx32KUrQx3DUxb1C6QZmZKpvd46Q=";
  };
  parser = config.xdg.configFile."DankMaterialShell/plugins/vocotypeHotwords".source.parser;
  provider = pkgs.writeShellApplication {
    name = "vinput-doubao-provider";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./scripts/vinput-doubao.py} \
        --provider ${providerSource} \
        --credentials "${config.age.secrets.doubao-asr.path}" \
        --parser ${parser}/bin/vocotype-terms-parser "$@"
    '';
  };
in
{
  config = lib.mkIf enabled {
    home.packages = [ vinput provider ];
    i18n.inputMethod.fcitx5.addons = [ vinput ];
    xdg.configFile."fcitx5/conf/vinput.conf".text = ''
      TriggerMode=Hold

      [TriggerKey]
      0=F9

      [CommandKeys]
      0=

      [MenuKey]
      0=Shift+F9
    '';
    # Declarative and secret-free; credentials are read only by the provider.
    xdg.configFile."vinput/config.json".text = builtins.toJSON {
      version = 1;
      global = {
        capture_device = "default";
        duck_output_while_recording = false;
      };
      asr = {
        active_provider = "provider.doubao.streaming";
        normalize_audio = false;
        input_gain = 1.0;
        vad.enabled = false;
        providers = [{
          id = "provider.doubao.streaming";
          type = "command";
          command = lib.getExe provider;
          timeout_ms = 60000;
          env = {
            VINPUT_ASR_URL = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async";
            VINPUT_ASR_RESOURCE_ID = "volc.seedasr.sauc.duration";
            VINPUT_ASR_ENABLE_ITN = "true";
            VINPUT_ASR_ENABLE_PUNC = "true";
            VINPUT_ASR_FINISH_GRACE_SECS = "10";
          };
        }];
      };
      llm = { providers = [ ]; adapters = [ ]; };
      scenes = {
        active_scene = "__raw__";
        definitions = [{ id = "__raw__"; count = 0; }];
      };
    };
    systemd.user.services.vinput-daemon = {
      Unit = {
        Description = "Vinput Lite cloud voice input";
        After = [ "pipewire.service" "agenix.service" ];
        Requires = [ "agenix.service" ];
        X-Restart-Triggers = [ config.xdg.configFile."vinput/config.json".source ];
      };
      Service = {
        Type = "dbus";
        BusName = "org.fcitx.Vinput";
        ExecStart = "${vinput}/bin/vinput-daemon";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "default.target" ];
    };
    systemd.user.services.fcitx5-daemon.Unit = {
      After = [ "vinput-daemon.service" ];
      Wants = [ "vinput-daemon.service" ];
    };
  };
}
