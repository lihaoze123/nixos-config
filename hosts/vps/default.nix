# Oracle Cloud ARM VPS. Installation procedure: docs/vps-installation.md.
{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./hardware.nix
    ./disk-config.nix
    ./web.nix
    ./cloudreve.nix
    ./wastebin.nix
    ./media.nix
    ./attic.nix
    ./forgejo.nix
    ./memos.nix
    ./libretv.nix
    ./karakeep.nix
    ./uptime-kuma.nix
    ./network-tuning.nix
  ];

  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  virtualisation.oci-containers.backend = "docker";

  my = {
    configPath = null;
    nix.cacheProfile = "public";
    virtualisation.docker.enable = true;
    apps.nixLd.enable = true;
    shell = {
      fish.profile = "minimal";
      neovim.profile = "minimal";
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
  };

  # Match OCI's existing NIC; the public IPv4 is mapped by OCI, not assigned here.
  networking = {
    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;
    timeServers = [ "169.254.169.254" ];
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
    extraGroups = [ "docker" ];
    openssh.authorizedKeys.keyFiles = [ ./authorized_keys ];
  };
  security.sudo.wheelNeedsPassword = false;
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  zramSwap = {
    enable = true;
    memoryMax = 2 * 1024 * 1024 * 1024;
  };
}
