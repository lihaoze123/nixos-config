{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ./sddm.nix
  ];

  programs.niri = {
    enable = true;
  };

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.swaylock = { };

  environment.systemPackages = with pkgs; [
    swaylock
    swayidle
  ];

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
