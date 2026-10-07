{ pkgs, ... }:
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
    fastfetch
    yazi
    lazygit
    fzf
    ripgrep
    eza
    bat
    (python313.withPackages (py-pkgs: with py-pkgs; [
      pygments
    ]))
    uv
    nodejs
    bun
    jdk
    gh
    codex
    zellij
    opencode
    jq
    just
    difftastic
    satty
    grim
    slurp
    tree-sitter
    ghostty
    tealdeer
  ];
}
