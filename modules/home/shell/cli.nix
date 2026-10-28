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
      merge-tools.difft = lib.mkIf (builtins.elem pkgs.difftastic osConfig.my.cli.packages) {
        diff-invocation-mode = "file-by-file";
      };
    };
  };

  home.packages = osConfig.my.cli.packages ++ (with pkgs; lib.optionals osConfig.my.cli.extra.enable [
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
  ] ++ lib.optionals osConfig.my.desktop.enable [
    satty
    grim
    slurp
  ]);
}
