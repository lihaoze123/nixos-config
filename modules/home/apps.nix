{ lib, pkgs, osConfig, ... }:
let
  cfg = osConfig.my.apps;
  # Application switch -> packages it installs.
  packages = with pkgs; {
    edge = [ microsoft-edge ];
    chrome = [ google-chrome ];
    wechat = [ wechat ];
    qq = [ qq ];
    telegram = [ telegram-desktop ];
    vlc = [ vlc ];
    ytDlp = [ yt-dlp ];
    ffmpeg = [ ffmpeg ];
    anki = [ anki ];
    obsidian = [ obsidian ];
    typesetting = [ typst pandoc tectonic ];
  };
in
{
  # Applications in daily use, each behind its own switch. Try new software
  # with `nix shell` or `nix profile`, then add it here once it is kept.
  home.packages = lib.concatLists
    (lib.mapAttrsToList (name: ps: lib.optionals cfg.${name}.enable ps) packages);

  xdg.mimeApps = lib.mkIf cfg.edge.enable {
    enable = true;
    defaultApplications = lib.genAttrs [
      "text/html"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ]
      (_: [ "microsoft-edge.desktop" ]);
  };

  programs.obs-studio.enable = cfg.obs.enable;

  programs.vscode = lib.mkIf cfg.vscode.enable {
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
