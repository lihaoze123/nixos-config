{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.my.desktop.fonts;
in
{
  options.my.desktop.fonts = {
    extra.enable = lib.mkEnableOption "additional Chinese and typesetting fonts";
    windows.enable = lib.mkEnableOption "Windows fonts from chinese-fonts-overlay";
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.extra.enable || config.my.desktop.enable;
          message = "my.desktop.fonts.extra requires my.desktop";
        }
        {
          assertion = !cfg.windows.enable || cfg.extra.enable;
          message = "my.desktop.fonts.windows requires my.desktop.fonts.extra";
        }
      ];
      nixpkgs.overlays = lib.optionals cfg.extra.enable [
        inputs.chinese-fonts-overlay.overlays.default
      ];
    }
    (lib.mkIf config.my.desktop.enable {
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
    })
  ];
}
