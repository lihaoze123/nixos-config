{ config, pkgs, ... }:
{
    programs.vscode = {
        enable = true;
        extensions = with pkgs.vscode-extensions; [
            dracula-theme.theme-dracula
            vscodevim.vim
            myriad-dreamin.tinymist
            ms-ceintl.vscode-language-pack-zh-hans
            adpyke.codesnap
        ];
    };
}
