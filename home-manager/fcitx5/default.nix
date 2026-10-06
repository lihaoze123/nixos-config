{ config
, lib
, pkgs
, inputs
, ...
}:
let
  vocotypePackage = inputs.vocotype.packages.${pkgs.stdenv.hostPlatform.system}.vocotype-fcitx5;
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
  # Keep Python entry points beside their shared module in the store.
  xhup-script-bundle = name: files: pkgs.runCommand name { } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n"
      (file: "cp ${./scripts + "/${file}"} $out/${file}")
      ([ "xhup_common.py" ] ++ files)}
  '';
  xhup-encoder-scripts = xhup-script-bundle "xhup-encoder-scripts" [ "generate-xhup-computer-dict.py" ];
  xhup-lookup-scripts = xhup-script-bundle "xhup-lookup-scripts" [ "xhup-lookup.py" ];
  xhup-add-scripts = xhup-script-bundle "xhup-add-scripts" [ "xhup-add-word.py" ];
  useDms = lib.attrByPath [ "programs" "dank-material-shell" "enable" ] false config;
  rime-crane-rev = "71f3add6a39d58a8e8b35abc7ca9c998d766b274";
  thuocl-it-rev = "a30ce79d895d01ab5132a5c74c29703ff7efb4cc";
  rime-user-dictionaries = {
    "xhup.user.dict.yaml" = ./dictionaries/xhup.user.dict.yaml;
    "xhup.user.chat.dict.yaml" = ./dictionaries/xhup.user.chat.dict.yaml;
    "xhup.user.coding.dict.yaml" = ./dictionaries/xhup.user.coding.dict.yaml;
    "xhup.user.work.dict.yaml" = ./dictionaries/xhup.user.work.dict.yaml;
  };
  rime-crane-config-id = builtins.hashString "sha256" ''
    ${rime-crane-rev}
    ${xhup-computer-dictionary}
    ${xhup-reverse-dictionary}
    ${builtins.readFile ./config/default.custom.yaml}
    ${builtins.readFile ./config/xhup.custom.yaml}
    ${builtins.readFile ./patches/rime-crane-shortcuts.patch}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (_: path: builtins.readFile path) rime-user-dictionaries
    )}
  '';
  rime-crane-src = pkgs.fetchFromGitHub {
    owner = "kchen0x";
    repo = "rime-crane";
    rev = rime-crane-rev;
    hash = "sha256-+eZ82uy8XJ8L9Mm/Kj1kVgBEMg2IUN2lrrmhiHcLpLM=";
  };
  thuocl-it-src = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/thunlp/THUOCL/${thuocl-it-rev}/data/THUOCL_IT.txt";
    hash = "sha256-6M1CyfVVlzX6O/uRUVy+BR+ZHv1KgDA4odXA2oWvNSY=";
  };

  xhup-computer-dictionary = pkgs.runCommand "xhup-user-computer-dictionary"
    {
      nativeBuildInputs = [
        (pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pypinyin ]))
      ];
    } ''
    mkdir -p $out/share/rime-data/xhup_dicts
    python ${xhup-encoder-scripts}/generate-xhup-computer-dict.py \
      --source ${thuocl-it-src} \
      --source-revision ${thuocl-it-rev} \
      --extra ${./dictionaries/computer-terms.txt} \
      --pinyin-dictionary ${rime-crane-src}/cn_dicts \
      --pinyin-overrides ${./dictionaries/computer-pinyin-overrides.txt} \
      --exclude ${rime-crane-src}/xhup_dicts \
      ${lib.concatMapStringsSep " " (path: "--exclude ${path}") (lib.attrValues rime-user-dictionaries)} \
      --min-frequency 1000 \
      --output $out/share/rime-data/xhup_dicts/xhup.user.computer.dict.yaml
  '';

  xhup-reverse-dictionary = pkgs.runCommand "xhup-weighted-reverse-dictionary"
    {
      nativeBuildInputs = [ pkgs.python3 ];
    } ''
    mkdir -p $out/share/rime-data
    python ${./scripts/generate-xhup-reverse-dict.py} \
      --reverse-dictionary ${rime-crane-src}/xhup_reverse.dict.yaml \
      --frequency-dictionary ${rime-crane-src}/cn_dicts/8105.dict.yaml \
      --output $out/share/rime-data/xhup_reverse.dict.yaml
  '';

  rime-crane = pkgs.stdenvNoCC.mkDerivation {
    pname = "rime-crane";
    version = builtins.substring 0 7 rime-crane-rev;
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.patch (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/rime-data
      cp -r ${rime-crane-src}/. $out/share/rime-data/
      chmod -R u+w $out/share/rime-data
      # Upstream shortcut tables omit Linux/Others (NixOS). Keep ordinary
      # translation and candidate selection working on unsupported systems.
      patch -d "$out/share/rime-data" -p1 < ${./patches/rime-crane-shortcuts.patch}
      cp -r ${xhup-computer-dictionary}/share/rime-data/. $out/share/rime-data/
      install -Dm644 \
        ${xhup-reverse-dictionary}/share/rime-data/xhup_reverse.dict.yaml \
        $out/share/rime-data/xhup_reverse.dict.yaml
      install -Dm644 ${./dictionaries/THUOCL-LICENSE.txt} $out/share/licenses/rime-crane/THUOCL.txt
      # Preserve our existing priority: upstream tables, manual user tables,
      # then generated computer terms. Parse YAML instead of matching comments.
      python - "$out/share/rime-data/xhup.dict.yaml" <<'PY'
      from pathlib import Path
      import sys
      import yaml

      path = Path(sys.argv[1])
      header, separator, body = path.read_text(encoding="utf-8").partition("\n...")
      if not separator:
          raise ValueError("xhup.dict.yaml is missing its dictionary header separator")
      metadata = yaml.safe_load(header)
      tables = metadata["import_tables"]
      if tables.count("xhup_dicts/xhup.user") != 1:
          raise ValueError("expected exactly one upstream user dictionary import")
      local_tables = [
          "xhup_dicts/xhup.user",
          "xhup_dicts/xhup.user.work",
          "xhup_dicts/xhup.user.coding",
          "xhup_dicts/xhup.user.chat",
          "xhup_dicts/xhup.user.computer",
      ]
      metadata["import_tables"] = [table for table in tables if table not in local_tables] + local_tables
      path.write_text(
          "# Rime dictionary; local user tables follow upstream tables.\n"
          + yaml.safe_dump(metadata, allow_unicode=True, sort_keys=False, explicit_start=True, explicit_end=True)
          + body.lstrip("\n"),
          encoding="utf-8",
      )
      PY

      runHook postInstall
    '';
  };

  fcitx5-rime-crane = pkgs.fcitx5-rime.override {
    rimeDataPkgs = [ rime-crane ];
  };

  rime-user-data-dir = "${config.home.homeDirectory}/.local/share/fcitx5/rime";
  rime-user-dictionary-dir = "${config.home.homeDirectory}/nixos-config/home-manager/fcitx5/dictionaries";
  # Only the wofi lookup frontend uses this live-dmenu extension; DMS hosts
  # use the launcher plugin instead and keep just the command-line query.
  xhup-wofi = pkgs.wofi.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/wofi-live.patch ];
  });
  xhup-lookup = pkgs.writeShellApplication {
    name = "xhup-lookup";
    runtimeInputs = [
      (pkgs.python3.withPackages (ps: [ ps.pyyaml ]))
      pkgs.wl-clipboard
    ] ++ lib.optional (!useDms) xhup-wofi;
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
  xhup-dms-plugin = inputs.dms-xhup.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
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
{
  imports = [ ./doubao.nix ./hotwords.nix ];
  home.packages = [ xhup-lookup xhup-add-word vocotype doubaoWorker ];
  # Also expose settings when activating Home Manager before a system switch.
  home.file.".local/bin/vocotype-settings".source = "${vocotype}/bin/vocotype-settings";

  home.activation.enableXhupDmsPlugin = lib.mkIf useDms (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe enable-xhup-dms-plugin}
    ''
  );

  xdg.configFile = {
    "DankMaterialShell/plugins/flypyXhup" = lib.mkIf useDms { source = xhup-dms-plugin; };
    # The Home Manager service owns Fcitx5; an XDG autostart instance could
    # otherwise acquire its D-Bus name first and survive package upgrades.
    "autostart/org.fcitx.Fcitx5.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Fcitx 5
      Hidden=true
    '';
    "fcitx5/profile" = {
      source = ./config/profile;
      force = true;
    };
  };
  home.file = {
    ".local/share/fcitx5/rime/default.custom.yaml".source = ./config/default.custom.yaml;
    ".local/share/fcitx5/rime/xhup.custom.yaml".source = ./config/xhup.custom.yaml;

    # Files in the Nix store have a fixed mtime, so Rime cannot notice that
    # their contents changed. Invalidate only the generated deployment state
    # when upstream data, generated dictionaries, or local customizations change.
    ".local/share/fcitx5/rime/.rime-crane-config-id" = {
      text = rime-crane-config-id;
      onChange = ''
        rime_user_data_dir=${lib.escapeShellArg rime-user-data-dir}
        run rm -rf -- "$rime_user_data_dir/build"
        run rm -f -- "$rime_user_data_dir/user.yaml"
      '';
    };
  };

  xdg.dataFile = lib.mapAttrs'
    (
      name: _:
        lib.nameValuePair "fcitx5/rime/xhup_dicts/${name}" {
          source = config.lib.file.mkOutOfStoreSymlink "${rime-user-dictionary-dir}/${name}";
          force = true;
        }
    )
    rime-user-dictionaries // {
      "applications/vocotype-settings.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=VoCoType 设置
        Exec=${vocotype}/bin/vocotype-settings
        Icon=${vocotype}/share/icons/hicolor/192x192/apps/vocotype.png
        Terminal=false
        Categories=Settings;Utility;
      '';
    };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      vocotype
      fcitx5-rime-crane
      qt6Packages.fcitx5-configtool
      fcitx5-gtk
    ];
  };

  # DMS launches applications through systemd-run, which inherits the user
  # manager environment rather than niri's environment block. WeChat bundles
  # its Qt Fcitx module and needs this selection in either launch path.
  systemd.user.sessionVariables.QT_IM_MODULE = "fcitx";

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

  # Restart Fcitx5 after cache invalidation so Rime deploys the new schema
  # before it handles the next input event.
  systemd.user.services.fcitx5-daemon.Unit.X-Restart-Triggers = [ rime-crane-config-id ];
  systemd.user.services.fcitx5-daemon.Service.Environment = [
    "ALSA_CONFIG_PATH=${vocotypeAlsaConfig}"
    "ALSA_PLUGIN_DIR=${vocotypeAlsaPlugins}"
    "VOCOTYPE_FCITX5_BACKEND=${lib.getExe vocotypeServiceLauncher}"
  ];
  # Also handle an already-running desktop instance during the first handover.
  systemd.user.services.fcitx5-daemon.Unit.Conflicts = [ "app-org.fcitx.Fcitx5@autostart.service" ];
  systemd.user.services.fcitx5-daemon.Unit.After = [
    "app-org.fcitx.Fcitx5@autostart.service"
    "vocotype-fcitx5-backend.service"
  ];
  systemd.user.services.fcitx5-daemon.Unit.Wants = [ "vocotype-fcitx5-backend.service" ];
}
