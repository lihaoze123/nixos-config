{ config, lib, pkgs, ... }:
let
  cfg = config.my.network.tailscale;
  dankscale = pkgs.fetchFromGitHub {
    owner = "dwright134";
    repo = "dms-dankscale";
    rev = "bddebf0e2935ba23b0614ff9af5bf8f4ed6d3d9f";
    hash = "sha256-o5kcFV7VAmHJqsKgnjDuuryubnuI9U+GQIPOlENZ5ao=";
  };
in
{
  options.my.network.tailscale.enable = lib.mkEnableOption "Tailscale networking";

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "both";
      # Dankscale manages Tailscale as the desktop user, without recurring prompts.
      extraSetFlags = lib.optional config.my.desktop.enable "--operator=${config.my.user.name}";
    };
    networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];
    networking.firewall.trustedInterfaces = [ "tailscale0" ];

    my.desktop.dms.plugins.dankscale = lib.mkIf config.my.desktop.enable {
      source = dankscale;
      barWidget = true;
      barWidgetOrder = 10;
    };
  };
}
