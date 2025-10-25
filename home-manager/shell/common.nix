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
  ];
}
