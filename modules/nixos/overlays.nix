{ config, lib, inputs, ... }:

{
  nixpkgs.overlays = lib.optionals config.my.fonts.extra.enable [
    inputs.chinese-fonts-overlay.overlays.default
  ] ++ lib.optionals config.my.desktop.enable [
    inputs.xwayland-satellite.overlays.default
  ] ++ lib.optionals config.my.ai.enable [
    inputs.claude-code.overlays.default
    inputs.codex-code.overlays.default
  ];
}
