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
    jujutsu
    (python313.withPackages (py-pkgs: with py-pkgs; [
      pygments
    ]))
    jdk
  ];
}
