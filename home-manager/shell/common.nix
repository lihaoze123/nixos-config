{ lib, pkgs, osConfig, ... }:
{
  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "chumeng";
        email = "2595248810@qq.com";
      };
      ui = {
        default-command = "log";
        diff-formatter = "difft";
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
  ] ++ lib.optionals osConfig.my.features.desktop.enable [
    satty
    grim
    slurp
  ];
}
