{ lib, pkgs, osConfig, ... }:
lib.mkIf osConfig.my.desktop.enable {
  home.packages = with pkgs; [
    loupe
    zathura
  ];

  xdg.configFile."zathura/zathurarc".source = ./zathura/zathurarc;

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
    "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
    "image/png" = [ "org.gnome.Loupe.desktop" ];
    "image/gif" = [ "org.gnome.Loupe.desktop" ];
    "image/webp" = [ "org.gnome.Loupe.desktop" ];
    "image/avif" = [ "org.gnome.Loupe.desktop" ];
    "image/bmp" = [ "org.gnome.Loupe.desktop" ];
    "image/tiff" = [ "org.gnome.Loupe.desktop" ];
    "image/svg+xml" = [ "org.gnome.Loupe.desktop" ];
  };
}
