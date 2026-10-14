{ lib, pkgs, osConfig, ... }:
let
  cfg = osConfig.my.apps;
in
{
  # Applications in daily use. Try new software with `nix shell` or
  # `nix profile`, then add it here once it is kept.
  home.packages = with pkgs;
    lib.optionals cfg.browsers.enable [
      google-chrome
      microsoft-edge
    ] ++ lib.optionals cfg.chat.enable [
      wechat
      qq
      telegram-desktop
    ] ++ lib.optionals cfg.media.enable [
      mpv
      vlc
      yt-dlp
      ffmpeg
    ];

  programs.obs-studio.enable = cfg.media.enable;
}
