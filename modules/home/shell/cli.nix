{ lib, pkgs, osConfig, inputs, system, ... }:
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
      merge-tools.difft.diff-invocation-mode = "file-by-file";
    };
  };

  home.packages = with pkgs; [
    yazi
    fd
    fzf
    ripgrep
    eza
    bat
    gh
    jq
    just
    difftastic
    tmux
  ] ++ lib.optionals osConfig.my.cli.extra.enable [
    lazygit
    zellij
    tealdeer
    fastfetch
    btop
    ouch
    iperf
    jjui
    nh
    # tobi/try with the NixOS shebang fix.
    inputs.nur-packages.packages.${system}.try
  ] ++ lib.optionals osConfig.my.desktop.enable [
    satty
    grim
    slurp
  ];
}
