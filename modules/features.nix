{ config, lib, pkgs, ... }:
let
  cfg = config.my.features;
  features = {
    desktop = "Niri desktop, Chinese input, audio and desktop utilities";
    dms = "DankMaterialShell (laptop also uses its greeter)";
    bluetooth = "Bluetooth and its desktop applet";
    docker = "rootless Docker";
    podman = "Podman and Distrobox";
    virtualMachines = "libvirt, QEMU and virt-manager";
    waydroid = "Waydroid";
    steam = "Steam and its system integration";
    speech = "VoCoType speech recognition";
    doubao = "Doubao speech credentials and worker integration";
    easyeffects = "EasyEffects microphone denoising";
    codexDesktop = "Codex Desktop Computer Use integration";
    aiCli = "Claude Code, Codex and OpenCode CLI tools";
    fingerprint = "Chicago fingerprint driver and authentication";
    cachyosKernel = "CachyOS kernel and binary cache";
    extraFonts = "additional Chinese and typesetting fonts";
    tailscale = "Tailscale networking";
    dae = "DAE proxy with encrypted configuration";
    edunet = "campus network authentication";
    aria2 = "aria2 RPC and local AriaNg web interface";
    wireshark = "Wireshark with capture permissions";
    appimage = "AppImage execution support";
    nixLd = "compatibility loader for external binaries";
    phoneIntegration = "Valent / KDE Connect phone integration";
    screenCast = "GNOME Network Displays and Wi-Fi display ports";
    printing = "printer support on home";
    syncthing = "Syncthing on home";
  };
in
{
  options.my.features = lib.mapAttrs
    (_: description: {
      enable = lib.mkEnableOption description;
    })
    features;

  config = {
    assertions = [
      { assertion = !cfg.dms.enable || cfg.desktop.enable; message = "my.features.dms requires desktop"; }
      { assertion = !cfg.speech.enable || cfg.desktop.enable; message = "my.features.speech requires desktop"; }
      { assertion = !cfg.doubao.enable || cfg.speech.enable; message = "my.features.doubao requires speech"; }
      { assertion = !cfg.easyeffects.enable || cfg.desktop.enable; message = "my.features.easyeffects requires desktop"; }
      { assertion = !cfg.codexDesktop.enable || cfg.desktop.enable; message = "my.features.codexDesktop requires desktop"; }
      { assertion = !cfg.phoneIntegration.enable || cfg.desktop.enable; message = "my.features.phoneIntegration requires desktop"; }
      { assertion = !cfg.screenCast.enable || cfg.desktop.enable; message = "my.features.screenCast requires desktop"; }
    ];

    hardware.bluetooth = lib.mkIf cfg.bluetooth.enable {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = { Experimental = true; FastConnectable = true; };
        Policy.AutoEnable = true;
      };
    };
    services.blueman.enable = cfg.bluetooth.enable && cfg.desktop.enable;
    services.pipewire = lib.mkIf cfg.desktop.enable {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    fonts = lib.mkIf cfg.desktop.enable {
      packages = with pkgs; [
        material-design-icons
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
        nerd-fonts.fira-code
      ] ++ lib.optionals cfg.extraFonts.enable [
        source-han-sans
        source-han-serif
        wqy_zenhei
        foundertype-fonts
        lxgw-wenkai
        cm_unicode
      ];
      enableDefaultPackages = false;
      fontconfig.defaultFonts = {
        serif = [ "Noto Serif CJK SC" ];
        sansSerif = [ "Noto Sans CJK SC" ];
        monospace = [ "FiraCode Nerd Font" "Noto Sans CJK SC" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
    programs.nix-ld.enable = cfg.nixLd.enable;
    programs.appimage = { enable = cfg.appimage.enable; binfmt = cfg.appimage.enable; };
    programs.wireshark = lib.mkIf cfg.wireshark.enable { enable = true; package = pkgs.wireshark; };
    users.users.chumeng.extraGroups = lib.optional cfg.wireshark.enable "wireshark"
      ++ lib.optionals cfg.desktop.enable [ "render" "audio" ]
      ++ lib.optional cfg.bluetooth.enable "bluetooth";
    virtualisation.docker = lib.mkIf cfg.docker.enable {
      enable = true;
      rootless = { enable = true; setSocketVariable = true; };
    };
    services.tailscale = lib.mkIf cfg.tailscale.enable { enable = true; useRoutingFeatures = "both"; };
    networking.firewall.allowedUDPPorts = lib.optional cfg.tailscale.enable config.services.tailscale.port;
    networking.firewall.trustedInterfaces = lib.optional cfg.tailscale.enable "tailscale0";
  };
}
