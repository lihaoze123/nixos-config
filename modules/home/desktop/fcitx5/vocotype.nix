{ config, lib, pkgs, inputs, osConfig, ... }:
let
  vocotypePackage = inputs.vocotype.packages.${pkgs.stdenv.hostPlatform.system}.vocotype-fcitx5.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/vocotype-edit-context-bounds.patch ];
  });
  vocotypePkgs = import inputs.vocotype.inputs.nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
  };
  # Route capture and playback through PipeWire's PulseAudio compatibility
  # server. Opening DMIC Raw directly caused distorted recordings here.
  # Match the ALSA plugin to VoCoType's pinned libc rather than the host's.
  vocotypeAlsaPlugins = "${vocotypePkgs.alsa-plugins}/lib/alsa-lib";
  vocotypeAlsaConfig = pkgs.writeText "vocotype-asound.conf" ''
    pcm.!default { type pulse }
    ctl.!default { type pulse }
  '';
  doubaoEnabled = config.programs.vocotype.doubao.enable;
  doubaoCredentials = if doubaoEnabled then config.age.secrets.doubao-asr.path else "/dev/null";
  vocotypeWorkers = inputs.vocotype.packages.${pkgs.stdenv.hostPlatform.system}.vocotype-funasr-workers;
  doubaoWorker = pkgs.writeShellApplication {
    name = "vocotype-doubao-worker";
    runtimeInputs = [
      (pkgs.python3.withPackages (ps: [ ps.websockets ]))
      pkgs.ffmpeg-headless
    ];
    text = ''
      exec python3 ${./scripts/doubao-asr-worker.py} \
        ${lib.optionalString doubaoEnabled "--enabled"} \
        --credentials "${doubaoCredentials}" \
        --local-worker ${vocotypeWorkers}/bin/vocotype-offline-worker "$@"
    '';
  };
  # The addon looks for systemctl only under /usr/bin and /bin, then falls
  # back to its compiled upstream backend path. Give that fallback a NixOS
  # launcher that starts our managed unit instead of a second local core.
  vocotypeServiceLauncher = pkgs.writeShellApplication {
    name = "vocotype-start-backend-service";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      exec systemctl --user start vocotype-fcitx5-backend.service
    '';
  };
  vocotype = pkgs.symlinkJoin {
    name = "vocotype-fcitx5-pipewire";
    paths = [ vocotypePackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    inherit (vocotypePackage) meta;
    postBuild = ''
      # Upstream wrappers hard-code their original store paths. Replace the
      # systemd launch chain; frontends connect to this already-running core.
      rm "$out/bin/vocotype-core" "$out/bin/vocotype-fcitx5-backend"
      makeWrapper ${vocotypePackage}/libexec/vocotype-core "$out/bin/vocotype-core" \
        --set VOCOTYPE_OFFLINE_WORKER ${lib.getExe doubaoWorker} \
        --set VOCOTYPE_STREAMING_WORKER ${vocotypeWorkers}/bin/vocotype-streaming-worker
      makeWrapper "$out/bin/vocotype-core" "$out/bin/vocotype-fcitx5-backend" \
        --add-flags --enable-final-asr
      for program in vocotype-settings vocotype-fcitx5-recorder; do
        wrapProgram "$out/bin/$program" \
          --set ALSA_CONFIG_PATH ${vocotypeAlsaConfig} \
          --set ALSA_PLUGIN_DIR ${vocotypeAlsaPlugins}
      done
    '';
  };
in
lib.mkIf (osConfig.my.desktop.enable && osConfig.my.input.speech.enable) {
  home.packages = [ vocotype doubaoWorker ];
  # Also expose settings when activating Home Manager before a system switch.
  home.file.".local/bin/vocotype-settings".source = "${vocotype}/bin/vocotype-settings";
  xdg.dataFile."applications/vocotype-settings.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=VoCoType 设置
    Exec=${vocotype}/bin/vocotype-settings
    Icon=${vocotype}/share/icons/hicolor/192x192/apps/vocotype.png
    Terminal=false
    Categories=Settings;Utility;
  '';

  i18n.inputMethod.fcitx5.addons = lib.mkAfter [ vocotype ];

  # The upstream Nix package does not install the backend user unit. Keep the
  # core alive independently of the settings window and Fcitx's launcher.
  systemd.user.services.vocotype-fcitx5-backend = {
    Unit.Description = "VoCoType native speech recognition core";
    Unit.After = lib.optional doubaoEnabled "agenix.service";
    Unit.Requires = lib.optional doubaoEnabled "agenix.service";
    Service = {
      ExecStart = "${vocotype}/bin/vocotype-fcitx5-backend";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.fcitx5-daemon = {
    Service.Environment = [
      "ALSA_CONFIG_PATH=${vocotypeAlsaConfig}"
      "ALSA_PLUGIN_DIR=${vocotypeAlsaPlugins}"
      "VOCOTYPE_FCITX5_BACKEND=${lib.getExe vocotypeServiceLauncher}"
    ];
    Unit.After = [ "vocotype-fcitx5-backend.service" ];
    Unit.Wants = [ "vocotype-fcitx5-backend.service" ];
  };
}
