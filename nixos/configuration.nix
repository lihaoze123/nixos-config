{ config, lib, pkgs, inputs, ... }:
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
    hostName = "nixos";
    networkmanager.enable = true;
  };
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    wl-clipboard
  ];

  users.users.chumeng = {
    isNormalUser = true;
    description = "chumeng";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  age.identityPaths = [ "/home/chumeng/.ssh/id_rsa" ];

  fonts = {
    packages = with pkgs; [
      material-design-icons

      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-emoji

      nerd-fonts.fira-code
    ];

    enableDefaultPackages = false;

    fontconfig.defaultFonts = {
      serif = [ "Noto Serif CJK SC" ];
      sansSerif = [ "Noto Sans CJK SC" ];
      monospace = [ "FiraCode Nerd Font" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  programs.nix-ld.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix.settings.substituters = [ "https://mirror.tuna.tsinghua.edu.cn/nix-channels/store" ];
  system.stateVersion = "25.05";
}
