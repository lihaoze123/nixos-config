{ config, lib, inputs, ... }:

{
  nixpkgs.overlays = lib.optionals config.my.features.extraFonts.enable [
    inputs.chinese-fonts-overlay.overlays.default
  ] ++ lib.optionals config.my.features.desktop.enable [
    inputs.xwayland-satellite.overlays.default
  ] ++ lib.optionals config.my.features.aiCli.enable [
    inputs.claude-code.overlays.default
    inputs.codex-code.overlays.default
  ];
}
