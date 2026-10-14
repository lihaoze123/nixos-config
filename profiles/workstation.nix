# Daily desktop shared by every graphical host.
{ lib, ... }:
let
  on = lib.mkDefault true;
in
{
  my = {
    cli.extra.enable = on;
    ai.enable = on;
    apps.browsers.enable = on;
    desktop = {
      enable = on;
      utilities.enable = on;
    };
    fonts.extra.enable = on;
    hardware.bluetooth.enable = on;
    network.edunet.enable = on;
    programs.nixLd.enable = on;
  };
}
