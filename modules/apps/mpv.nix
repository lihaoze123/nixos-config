{ lib, pkgs, osConfig, ... }:
lib.mkIf osConfig.my.apps.mpv.enable {
  programs.mpv = {
    enable = true;
    scripts = with pkgs.mpvScripts; [
      uosc
      thumbfast
      mpris
      uosc-danmaku
    ];

    config = {
      vo = "gpu-next";
      # Copy-back decoding keeps the danmaku fps filter on the GPU decoder.
      hwdec = "auto-copy-safe";

      # uosc replaces the built-in OSC and OSD bar.
      osc = false;
      osd-bar = false;
      border = false;

      save-position-on-quit = true;
      keep-open = true;
      volume = 100;
      volume-max = 130;

      screenshot-directory = "~/Pictures/mpv";
      screenshot-format = "png";

      slang = "chs,sc,zh-Hans,zh-CN,zh,chi,zho,cht,zh-Hant,eng,en";
      alang = "jpn,ja,chi,zho,zh,eng,en";
      sub-auto = "fuzzy";
      # Applies to plain-text subtitles; ASS keeps its own styles.
      sub-font = "Noto Sans CJK SC";
      sub-font-size = 44;
      sub-outline-size = 2.5;
      sub-shadow-offset = 1;

      ytdl-format = "bestvideo[height<=?1440]+bestaudio/best";
      ytdl-raw-options = "cookies-from-browser=edge";
    };

    # Linear playback speed steps instead of the default multipliers.
    bindings = {
      "[" = "add speed -0.1";
      "]" = "add speed 0.1";
      "{" = "add speed -0.5";
      "}" = "add speed 0.5";
    };

    scriptOpts = {
      uosc = {
        autoload = true;
        controls = lib.concatStringsSep "," [
          "menu"
          "gap"
          "<video,audio>subtitles"
          "<has_many_audio>audio"
          "<has_many_video>video"
          "<has_many_edition>editions"
          "<stream>stream-quality"
          "button:danmaku"
          "cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?弹幕开关"
          "button:danmaku_menu"
          "gap"
          "space"
          "<video,audio>speed"
          "space"
          "shuffle"
          "loop-playlist"
          "loop-file"
          "gap"
          "prev"
          "items"
          "next"
          "gap"
          "fullscreen"
        ];
      };
      uosc_danmaku = {
        api_server = "https://danmaku-api.152468.xyz";
        # Keep j for mpv's subtitle cycling.
        show_danmaku_keyboard_key = "D";
        auto_load = true;
        autoload_local_danmaku = true;
        autoload_for_url = true;
        chConvert = 1;
        merge_tolerance = 1;
        fontname = "Noto Sans CJK SC";
        vf_fps = true;
        fps = "60/1.001";
      };
    };
  };

  xdg.mimeApps.defaultApplications = lib.genAttrs [
    "video/mp4"
    "video/x-matroska"
    "video/webm"
    "video/x-msvideo"
    "video/quicktime"
    "video/mp2t"
    "video/mpeg"
    "video/x-flv"
    "video/ogg"
    "audio/mpeg"
    "audio/flac"
    "audio/ogg"
    "audio/x-wav"
    "audio/aac"
    "audio/mp4"
    "audio/opus"
  ]
    (_: [ "mpv.desktop" ]);
}
