{ lib, pkgs, osConfig, ... }:
let
  # Commit identity shared by Git and Jujutsu.
  identity = {
    name = "chumeng";
    email = "2595248810@qq.com";
  };
in
{
  programs.git = {
    enable = true;
    settings.user = identity;
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    enableJujutsuIntegration = true;
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user = identity;
      ui = {
        default-command = "log";
      };
      aliases = lib.mkIf osConfig.my.shell.cli.extra.enable {
        review = [ "util" "exec" "--" "tuicr" ];
      };
      merge-tools.difft = lib.mkIf (builtins.elem pkgs.difftastic osConfig.my.shell.cli.packages) {
        diff-invocation-mode = "file-by-file";
      };
    };
  };

  programs.tuicr.enable = osConfig.my.shell.cli.extra.enable;

  home.packages = osConfig.my.shell.cli.packages ++ lib.optionals osConfig.my.shell.cli.extra.enable (with pkgs; [
    lazygit
    zellij
    tealdeer
    fastfetch
    btop
    ouch
    iperf
    jjui
    nh
    nix-search-tv
    nur.repos.lihaoze123.cloudflare-cli
    # tobi/try with the NixOS shebang fix.
    nur.repos.lihaoze123.try
  ]);
}
