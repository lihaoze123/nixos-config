{ lib, pkgs, ... }:
{
  options.my.shell.cli = {
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [ yazi fd fzf ripgrep eza bat gh jq just difftastic tmux ];
      description = "Base CLI packages; hosts may select a smaller set or add individual extra tools.";
    };
    extra.enable = lib.mkEnableOption "commonly used command-line tools beyond the minimal system";
  };

  config.my.home = ./home.nix;
}
