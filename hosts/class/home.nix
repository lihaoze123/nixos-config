{ panelMode }:
{ lib, pkgs, osConfig, ... }:
{
  age.identityPaths = [ "/home/chumeng/.ssh/id_ed25519" ];
  xresources.properties."Xft.dpi" = lib.mkForce 96;
  # The new machine has no checkout at ~/nixos-config: ship these files.
  xdg.configFile."nvim".source = lib.mkForce ../../modules/home/shell/neovim/nvim;
  # Keep the desktop and greeter on the same preferred panel mode.
  xdg.configFile."niri/base.kdl" = lib.mkIf osConfig.my.desktop.enable {
    source = lib.mkForce (pkgs.writeText "class-niri-base.kdl" (lib.replaceStrings
      [ "mode \"3120x2080@120\"" "scale 2.0" "position x=1280 y=0" "window-rule {\n    match is-agent-driven=true" "include \"dms/layout.kdl\"" ]
      [ "mode \"${panelMode}\"" "scale 1.0" "position x=0 y=0" "${lib.optionalString (!osConfig.my.desktop.codexComputerUse.enable) "/-"}window-rule {\n    match is-agent-driven=true" "include optional=true \"dms/layout.kdl\"" ]
      (builtins.readFile ../../modules/home/desktop/niri/config.kdl)));
  };
}
