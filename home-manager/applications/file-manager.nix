{ lib, pkgs, osConfig, ... }:
lib.mkIf osConfig.my.features.desktop.enable {
  home.packages = with pkgs; [
    nautilus
    file-roller
  ];

  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    # Nautilus already exposes eject/unmount; no separate tray is needed.
    tray = "never";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications."inode/directory" = [ "org.gnome.Nautilus.desktop" ];
  };
}
