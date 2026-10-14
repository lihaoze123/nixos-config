# Personal machines (laptop, home): voice input, downloads, containers and tooling.
{ lib, ... }:
let
  on = lib.mkDefault true;
in
{
  imports = [ ./workstation.nix ];

  my = {
    desktop.easyeffects.enable = on;
    input.speech = {
      enable = on;
      doubao.enable = on;
    };
    network.tailscale.enable = on;
    services.aria2.enable = on;
    virtualisation.docker.enable = on;
    programs = {
      wireshark.enable = on;
      appimage.enable = on;
    };
  };
}
