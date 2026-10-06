{ ... }:
{
  services.easyeffects = {
    enable = true;
    preset.input = "microphone-denoise";
    settings = {
      EffectsPipelines = {
        processAllInputs = true;
        processAllOutputs = false;
      };
      StreamInputs = {
        useDefaultInputDevice = true;
        listenToMic = false;
      };
    };
    extraPresets.microphone-denoise.input = {
      blocklist = [ ];
      plugins_order = [ "rnnoise#0" ];
      "rnnoise#0" = {
        bypass = false;
        input-gain = 0.0;
        output-gain = 0.0;
        model-name = "";
        use-standard-model = true;
        # Avoid gating quiet speech and the beginnings/endings of words.
        enable-vad = false;
        vad-thres = 50.0;
        wet = 0.0;
        release = 20.0;
      };
    };
  };
}
