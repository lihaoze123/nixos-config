# Local workaround for niri tiled windows without global IPC coordinates.
{ inputs, system }:
let
  upstream = inputs.codex-desktop-linux;
  pkgs = import upstream.inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  buildRustPackage = pkgs.rustPlatform.buildRustPackage.override {
    importCargoLock = pkgs.rustPlatform.importCargoLock.override {
      fetchurl = args: pkgs.fetchurl (args // {
        url = builtins.replaceStrings
          [ "https://crates.io/api/v1/crates" ]
          [ "https://static.crates.io/crates" ]
          args.url;
      });
    };
  };
  compatibilityPatches = [
    ../../patches/codex-niri-window-screenshot.patch
    ../../patches/codex-niri-window-coordinates.patch
    ../../patches/codex-linux-native-drag.patch
    ../../patches/codex-linux-drag-interpolation.patch
  ];
  patchedSource = pkgs.applyPatches {
    name = "codex-desktop-linux-niri-source";
    src = upstream;
    patches = compatibilityPatches;
  };
  backend = buildRustPackage {
    pname = "codex-computer-use-niri";
    version = "0.4.9-linux-alpha1";
    src = patchedSource;
    cargoLock.lockFile = patchedSource + "/Cargo.lock";
    cargoBuildFlags = [ "-p" "codex-computer-use-linux" "--bin" "codex-computer-use-linux" ];
    cargoTestFlags = [ "-p" "codex-computer-use-linux" "--bin" "codex-computer-use-linux" ];
    doCheck = true;
  };
  desktop = upstream.packages.${system}.codex-desktop-computer-use-ui;
in
  desktop.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      install -m755 ${backend}/bin/codex-computer-use-linux \
        "$out/opt/codex-desktop/resources/plugins/openai-bundled/plugins/unified-computer-use/bin/codex-computer-use-linux"
      install -m644 ${patchedSource}/linux-features/computer-use-linux/native-client.mjs \
        "$out/opt/codex-desktop/resources/plugins/openai-bundled/plugins/unified-computer-use/scripts/native-client.mjs"
      install -m644 ${patchedSource}/linux-features/computer-use-linux/native-service.mjs \
        "$out/opt/codex-desktop/resources/plugins/openai-bundled/plugins/unified-computer-use/scripts/native-service.mjs"
    '';
    passthru = (old.passthru or { }) // { niriBackend = backend; };
  })
