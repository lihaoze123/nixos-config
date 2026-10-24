{ ... }:
{
  # Each module is gated by osConfig.my.desktop or a more specific switch.
  imports = [
    ./niri
    ./fcitx5
    ./kitty
    ./file-manager.nix
    ./viewers.nix
    ./utilities.nix
    ./easyeffects.nix
    ./mpv.nix
  ];
}
