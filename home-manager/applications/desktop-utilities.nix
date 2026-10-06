{ pkgs, ... }:
{
  home.packages = with pkgs; [
    loupe
    gnome-disk-utility
    baobab
    kdePackages.filelight
  ];

  xdg.mimeApps.defaultApplications = {
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
