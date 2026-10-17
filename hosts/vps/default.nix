# Oracle Cloud ARM VPS. Installation procedure: docs/vps-installation.md.
{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./hardware.nix
    ./disk-config.nix
    ./cloudreve.nix
    ./wastebin.nix
    ./media.nix
    ./attic.nix
    ./network-tuning.nix
  ];

  my = {
    configPath = null;
    nix.cacheProfile = "public";
    virtualisation.docker.enable = true;
    shell.profile = "minimal";
    editor.neovim.profile = "minimal";
    cli.packages = with pkgs; [
      fd
      fzf
      ripgrep
      eza
      bat
      jq
      tmux
      btop
      tealdeer
      ouch
      iperf
      nh
    ];
  };

  # Match OCI's existing NIC; the public IPv4 is mapped by OCI, not assigned here.
  networking = {
    networkmanager.enable = lib.mkForce false;
    useNetworkd = true;
    useDHCP = false;
    timeServers = [ "169.254.169.254" ];
    # OCI's NSG allows all IPv4/IPv6 ingress; filter service ports in NixOS.
    firewall = {
      allowedUDPPortRanges = lib.mkForce [ ];
      # Keep NixOS's loopback allowance for the local DNS stub and other IPC.
      trustedInterfaces = lib.mkForce [ "lo" ];
    };
  };
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "02:00:17:03:51:20";
    linkConfig.MTUBytes = 9000;
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
    dhcpV4Config.ClientIdentifier = "mac";
  };
  services.resolved.enable = true;

  users.users.${config.my.user.name} = {
    linger = true;
    extraGroups = lib.mkForce [ "wheel" "docker" ];
    openssh.authorizedKeys.keyFiles = [ ./authorized_keys ];
  };
  security.sudo.wheelNeedsPassword = false;
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
  programs.mosh.enable = lib.mkForce false;

  zramSwap = {
    enable = true;
    memoryMax = 2 * 1024 * 1024 * 1024;
  };
}
