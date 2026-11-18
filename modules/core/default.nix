{ inputs, lib, pkgs, ... }:
{
  imports = [
    ./boot.nix
    ./user.nix
    ./nix-cache.nix
  ];

  networking = {
    networkmanager.enable = lib.mkDefault true;
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

  services.openssh.enable = true;
  programs.mosh.enable = true;

  networking.nftables.enable = true;
  networking.firewall.enable = true;

  programs.direnv = {
    enable = true;
    silent = false;
    loadInNixShell = true;

    nix-direnv.enable = true;
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ inputs.nur.overlays.default ];

  system.stateVersion = "25.05";
}
