{ ... }:
{
  # File management and image viewing belong to the optional desktop.
  # Common desktop tools follow extraDesktop; other applications use nix profile.
  imports = [ ./file-manager.nix ./desktop-utilities.nix ./extra-desktop.nix ];
}
