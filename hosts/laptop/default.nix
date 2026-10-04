{ inputs, pkgs, pkgs-stable, system, mkRustToolchain, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../base.nix
    ../../modules/virtualisation
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.computer-use.nixosModules.default
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.chumeng = import ./laptop.nix;
      home-manager.extraSpecialArgs = { inherit inputs pkgs-stable system mkRustToolchain; };
    }
    (import ../../modules)
    (import ../../overlays)
  ];

  networking.hostName = "laptop";

  # Codex Desktop Computer Use on niri, including agent input that does not take the
  # pointer or focus: https://github.com/lihaoze123/niri-computer-use
  programs.codexComputerUse = {
    enable = true;
    users = [ "chumeng" ];
  };

  programs.steam = {
    enable = true;
  };

  # System backends used by the Home Manager DMS session.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.accounts-daemon.enable = true;
  security.pam.services.dankshell = { };

  environment.systemPackages = with pkgs; [
    dnsmasq
    gnome-network-displays
  ];

  networking.firewall = {
    trustedInterfaces = [ "p2p-wl+" ];
    allowedTCPPorts = [ 7236 7250 ];
    allowedUDPPorts = [ 7236 5353 ];
    interfaces."wlp0s20f3" = {
      allowedTCPPorts = [ 45545 ];
      allowedUDPPorts = [ 45545 6771 ];
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
