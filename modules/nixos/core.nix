{ config, lib, pkgs, ... }:
let
  user = config.my.user;
in
{
  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };
  networking = {
    networkmanager.enable = true;
  };
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    bind
  ];

  users.users.${user.name} = {
    isNormalUser = true;
    description = user.name;
    extraGroups = [ "networkmanager" "wheel" ];
  };

  age.identityPaths = lib.mkDefault [ "${user.home}/.ssh/id_rsa" ];

  services.openssh.enable = true;
  programs.mosh.enable = true;
  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 65535; }
  ];

  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "wg0" ];
  };

  programs.direnv = {
    enable = true;
    silent = false;
    loadInNixShell = true;

    nix-direnv.enable = true;
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings.substituters = [ "https://mirrors.cernet.edu.cn/nix-channels/store" ];

  system.stateVersion = "25.05";
}
