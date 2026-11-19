# Daily desktop shared by every graphical host.
{ lib, ... }:
let
  on = lib.mkDefault true;
in
{
  my = {
    shell = {
      cli.extra.enable = on;
      ai.enable = on;
    };
    apps = {
      edge.enable = on;
      antigravity.enable = on;
      mpv.enable = on;
      nixLd.enable = on;
    };
    desktop = {
      enable = on;
      utilities.enable = on;
      fonts.extra.enable = on;
    };
    hardware.bluetooth.enable = on;
    network.edunet.enable = on;
  };
}
