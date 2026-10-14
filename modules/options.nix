{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.my;
  # Every switch defaults to off; profiles and hosts enable them.
  requires = enabled: dependency: name: dependencyName: {
    assertion = !enabled || dependency;
    message = "my.${name} requires my.${dependencyName}";
  };
in
{
  # Feature switches shared by the NixOS and Home Manager modules.
  # Hosts select them through profiles/ and their own default.nix.
  options.my = {
    cli.extra.enable = mkEnableOption "commonly used command-line tools beyond the minimal system";
    ai.enable = mkEnableOption "Claude Code, Codex and OpenCode CLI tools";

    desktop = {
      enable = mkEnableOption "Niri with DankMaterialShell and Dank Greeter, Chinese input, audio and desktop utilities";
      utilities.enable = mkEnableOption "commonly used graphical tools: terminal, editor, audio and disk utilities";
      graphicalBoot = {
        enable = mkEnableOption "quiet boot with the DMS Plymouth theme and Dank Greeter handoff";
        scale = mkOption {
          type = types.ints.positive;
          default = 1;
          description = "Display scale used to render the Plymouth theme assets.";
        };
      };
      greeter.extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Host-specific niri configuration for the Dank Greeter, such as outputs.";
      };
      wallpaperEngine.enable = mkEnableOption "Wallpaper Engine animated wallpapers with the DMS plugin";
      codexComputerUse.enable = mkEnableOption "Codex Desktop Computer Use integration";
      easyeffects.enable = mkEnableOption "EasyEffects microphone denoising";
      phone.enable = mkEnableOption "Valent / KDE Connect phone integration";
      screenCast.enable = mkEnableOption "GNOME Network Displays and Wi-Fi display ports";
    };

    input.speech = {
      enable = mkEnableOption "VoCoType speech recognition";
      doubao.enable = mkEnableOption "Doubao speech credentials and worker integration";
    };

    fonts = {
      extra.enable = mkEnableOption "additional Chinese and typesetting fonts";
      windows.enable = mkEnableOption "Windows fonts from chinese-fonts-overlay";
    };

    hardware.bluetooth.enable = mkEnableOption "Bluetooth and its desktop applet";
    kernel.cachyos.enable = mkEnableOption "CachyOS BORE kernel and binary cache";

    network = {
      tailscale.enable = mkEnableOption "Tailscale networking";
      edunet.enable = mkEnableOption "campus network authentication";
      proxy = {
        backend = mkOption {
          type = types.nullOr (types.enum [ "dae" "honk" ]);
          default = null;
          description = "Transparent proxy using the shared encrypted nodes; null disables it.";
        };
        lanInterfaces = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "virbr0" ];
          description = ''
            LAN interfaces whose forwarded traffic dae or honk should proxy.
            These interfaces must exist before the proxy starts. Enabling Docker
            or libvirt does not automatically add their bridges to this list.
          '';
        };
      };
    };

    services.aria2.enable = mkEnableOption "aria2 RPC and local AriaNg web interface";

    virtualisation = {
      docker.enable = mkEnableOption "rootless Docker";
      podman.enable = mkEnableOption "Podman and Distrobox";
      libvirt.enable = mkEnableOption "libvirt, QEMU and virt-manager";
      waydroid.enable = mkEnableOption "Waydroid";
    };

    # Daily graphical applications; nix profile is only for trying software.
    apps = {
      browsers.enable = mkEnableOption "Google Chrome and Microsoft Edge";
      chat.enable = mkEnableOption "WeChat, QQ and Telegram";
      media.enable = mkEnableOption "mpv, VLC, OBS Studio, yt-dlp and FFmpeg";
    };

    programs = {
      wireshark.enable = mkEnableOption "Wireshark with capture permissions";
      appimage.enable = mkEnableOption "AppImage execution support";
      nixLd.enable = mkEnableOption "compatibility loader for external binaries";
      steam.enable = mkEnableOption "Steam and its system integration";
    };
  };

  config.assertions = [
    {
      assertion = !(cfg.network.proxy.backend == "honk" && config.services.dae.enable);
      message = "my.network.proxy.backend = \"honk\" conflicts with services.dae";
    }
    (requires cfg.desktop.utilities.enable cfg.desktop.enable "desktop.utilities" "desktop")
    (requires cfg.desktop.graphicalBoot.enable cfg.desktop.enable "desktop.graphicalBoot" "desktop")
    (requires cfg.desktop.wallpaperEngine.enable cfg.desktop.enable "desktop.wallpaperEngine" "desktop")
    (requires cfg.desktop.codexComputerUse.enable cfg.desktop.enable "desktop.codexComputerUse" "desktop")
    (requires cfg.desktop.easyeffects.enable cfg.desktop.enable "desktop.easyeffects" "desktop")
    (requires cfg.desktop.phone.enable cfg.desktop.enable "desktop.phone" "desktop")
    (requires cfg.desktop.screenCast.enable cfg.desktop.enable "desktop.screenCast" "desktop")
    (requires cfg.apps.browsers.enable cfg.desktop.enable "apps.browsers" "desktop")
    (requires cfg.apps.chat.enable cfg.desktop.enable "apps.chat" "desktop")
    (requires cfg.apps.media.enable cfg.desktop.enable "apps.media" "desktop")
    (requires cfg.input.speech.enable cfg.desktop.enable "input.speech" "desktop")
    (requires cfg.input.speech.doubao.enable cfg.input.speech.enable "input.speech.doubao" "input.speech")
    (requires cfg.fonts.extra.enable cfg.desktop.enable "fonts.extra" "desktop")
    (requires cfg.fonts.windows.enable cfg.fonts.extra.enable "fonts.windows" "fonts.extra")
  ];
}
