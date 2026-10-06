{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ./sddm.nix
  ];

  # Hosts keep SDDM unless they opt into the DankMaterialShell greeter.
  options.my.niri.greeter = lib.mkOption {
    type = lib.types.enum [ "sddm" "dms" ];
    default = "sddm";
    description = "Display manager used to start the Niri session.";
  };

  config = {
    programs.niri = {
      enable = true;
    };

    security.polkit.enable = true;
    services.gnome.gnome-keyring.enable = true;
    # Nautilus: removable disks, MTP phones, trash and remote file access.
    services.gvfs.enable = true;
    services.udisks2.enable = true;
    services.gnome.sushi.enable = true;
    security.pam.services.swaylock = { };

    environment.systemPackages = with pkgs; [
      swaylock
      swayidle
    ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
