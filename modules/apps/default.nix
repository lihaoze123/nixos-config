{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption;
  apps = config.my.apps;
in
{
  # One switch per application. Profiles enable only the first-install set;
  # try anything else with nix shell or nix profile.
  options.my.apps = {
    edge.enable = mkEnableOption "Microsoft Edge";
    chrome.enable = mkEnableOption "Google Chrome";
    wechat.enable = mkEnableOption "WeChat";
    qq.enable = mkEnableOption "QQ";
    telegram.enable = mkEnableOption "Telegram Desktop";
    mpv.enable = mkEnableOption "mpv";
    vlc.enable = mkEnableOption "VLC";
    obs.enable = mkEnableOption "OBS Studio";
    ytDlp.enable = mkEnableOption "yt-dlp";
    ffmpeg.enable = mkEnableOption "FFmpeg command-line tools";
    vscode.enable = mkEnableOption "VS Code with Vim, Dracula, Tinymist, LaTeX Workshop, CodeSnap and the Chinese language pack";
    anki.enable = mkEnableOption "Anki";
    obsidian.enable = mkEnableOption "Obsidian";
    typesetting.enable = mkEnableOption "Typst, Pandoc and Tectonic";
    wireshark.enable = mkEnableOption "Wireshark with capture permissions";
    appimage.enable = mkEnableOption "AppImage execution support";
    nixLd.enable = mkEnableOption "compatibility loader for external binaries";
    steam.enable = mkEnableOption "Steam and its system integration";
  };

  config = {
    assertions = map
      (name: {
        assertion = !apps.${name}.enable || config.my.desktop.enable;
        message = "my.apps.${name} requires my.desktop";
      })
      [ "edge" "chrome" "wechat" "qq" "telegram" "mpv" "vlc" "obs" "vscode" "anki" "obsidian" ];

    programs.nix-ld.enable = apps.nixLd.enable;
    programs.appimage = { enable = apps.appimage.enable; binfmt = apps.appimage.enable; };
    programs.wireshark = lib.mkIf apps.wireshark.enable { enable = true; package = pkgs.wireshark; };
    users.users.${config.my.user.name}.extraGroups = lib.optional apps.wireshark.enable "wireshark";
    programs.steam.enable = apps.steam.enable;

    my.home = ./home.nix;
  };
}
