{ ... }:
{
  # File management and image viewing belong to the optional desktop.
  # Ordinary applications are installed independently with nix profile.
  imports = [ ./file-manager.nix ./desktop-utilities.nix ];
}
