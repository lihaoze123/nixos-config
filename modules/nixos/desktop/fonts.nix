{ config, lib, pkgs, ... }:
let
  cfg = config.my.fonts;
in
lib.mkIf config.my.desktop.enable {
  fonts = {
    packages = with pkgs; [
      material-design-icons
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      nerd-fonts.fira-code
    ] ++ lib.optionals cfg.extra.enable [
      source-han-sans
      source-han-serif
      wqy_zenhei
      foundertype-fonts
      lxgw-wenkai
      cm_unicode
    ] ++ lib.optionals cfg.windows.enable [ windows-fonts ];
    enableDefaultPackages = false;
    fontconfig.defaultFonts = {
      serif = [ "Noto Serif CJK SC" ];
      sansSerif = [ "Noto Sans CJK SC" ];
      monospace = [ "FiraCode Nerd Font" "Noto Sans CJK SC" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
