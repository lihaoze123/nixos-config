{ inputs, pkgs, pkgs-stable, system, mkRustToolchain, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../base.nix
    ../../modules/virtualisation
    inputs.ragenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.computer-use.nixosModules.default
    inputs.gxfp-linux-driver.nixosModules.default
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "backup";
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

  # Fingerprint authentication supplements the existing password PAM rules.
  services.fprintd = {
    enable = true;
    # The GXFP fork needs its matching daemon (newer fprintd needs libfprint >=1.94.9).
    package = (pkgs.callPackage "${inputs.libfprint-gxfp}/nix/fprintd.nix" {
      libfprint-gxfp = pkgs.callPackage "${inputs.libfprint-gxfp}/nix/libfprint.nix" { };
    }).overrideAttrs (_: {
      # Manage DeviceAllow below; upstream's service patch emits a literal \\n.
      postInstall = "";
    });
  };
  hardware.gxfp.enable = true;
  services.udev.extraRules = ''
    SUBSYSTEM=="misc", KERNEL=="gxfp", MODE="0660", TAG+="uaccess"
  '';
  # The sensor PSK is provisioned separately and must never enter the Nix store.
  # StateDirectory also permits this path through fprintd's systemd sandbox.
  systemd.services.fprintd.serviceConfig = {
    DeviceAllow = [ "/dev/gxfp rw" ];
    StateDirectory = "fprintd/gxfp";
    StateDirectoryMode = "0700";
  };
  security.pam.services = {
    sudo.fprintAuth = true;
    # SDDM authenticates through the login PAM substack in this nixpkgs version.
    login.fprintAuth = true;
  };

  # Use the pinned nixpkgs module and its user service for DMS file search.
  programs.dsearch = {
    enable = true;
    systemd.target = "graphical-session.target";
  };

  environment.systemPackages = with pkgs; [
    dnsmasq
    gnome-network-displays
    # Diagnostic tools use the same nixpkgs as the host and fingerprint stack.
    (pkgs.callPackage "${inputs.libfprint-gxfp}/nix/gxfp-tools.nix" { })
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
