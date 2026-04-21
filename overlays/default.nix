{ config, pkgs, lib, inputs, ... }:

{
  nixpkgs.overlays = [
    inputs.chinese-fonts-overlay.overlays.default
    inputs.claude-code.overlays.default
    inputs.codex-code.overlays.default
    (import ./antigravity-tools.nix)
  ];
}
