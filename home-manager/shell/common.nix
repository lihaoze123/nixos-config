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
     gcc14
  ];

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      character.success_symbol = "[~](bold green)";
    };
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
