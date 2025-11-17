{ config, pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      dracula-theme.theme-dracula
      vscodevim.vim
      myriad-dreamin.tinymist
      ms-ceintl.vscode-language-pack-zh-hans
      adpyke.codesnap
      james-yu.latex-workshop
    ];
  };
}
