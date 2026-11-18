{ config, lib, inputs, ... }:
let
  cfg = config.my.shell.ai;
in
{
  options.my.shell.ai.enable = lib.mkEnableOption "Claude Code and Codex CLI tools";

  config = {
    nixpkgs.overlays = lib.optionals cfg.enable [
      inputs.claude-code.overlays.default
      inputs.codex-code.overlays.default
      inputs.llm-agents.overlays.shared-nixpkgs
    ];
    my.home = ./home.nix;
  };
}
