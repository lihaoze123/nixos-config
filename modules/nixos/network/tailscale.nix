{ config, lib, ... }:
lib.mkIf config.my.network.tailscale.enable {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    # Dankscale manages Tailscale as the desktop user, without recurring prompts.
    extraSetFlags = lib.optional config.my.desktop.enable "--operator=${config.my.user.name}";
  };
  networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
