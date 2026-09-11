{ inputs, pkgs, pkgs-stable, system, mkRustToolchain, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../base.nix
    ../../modules/virtualisation
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.codex-desktop-linux.nixosModules.default
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

  programs.codexDesktopLinux = {
    enable = true;
    package = import ../../modules/niri/codex-desktop.nix { inherit inputs system; };
    linuxFeatures = [ "computer-use-linux" ];
  };

  # Expose tiled-window positions for exact niri Computer Use input mapping.
  programs.niri.package = pkgs.niri.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../patches/niri-ipc-tiled-window-position.patch ];
  });

  programs.ydotool.enable = true;
  services.gnome.at-spi2-core.enable = true;
  home-manager.users.chumeng.dconf.settings."org/gnome/desktop/interface" = {
    toolkit-accessibility = true;
  };
  users.users.chumeng.extraGroups = [ "ydotool" ];
  boot.kernelModules = [ "uinput" ];

  # Native pointer input; keyboard input uses the ydotool daemon socket.
  services.udev.extraRules = ''
    KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="ydotool", MODE="0660"
  '';

  programs.steam = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    dnsmasq
    flclash
    gnome-network-displays
  ];

  networking.firewall = {
    trustedInterfaces = [ "p2p-wl+" ];
    allowedTCPPorts = [ 7236 7250 ];
    allowedUDPPorts = [ 7236 5353 ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
