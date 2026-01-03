{ pkgs, ... }:
{
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
    nodejs
    bun
    jdk
    gh
    codex
  ];
}
