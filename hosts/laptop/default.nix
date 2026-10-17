{ config, lib, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ../../profiles/personal.nix
    inputs.nur-packages.nixosModules.gxfp5130-chicago
  ];

  my = {
    # Applications already in use on this machine, beyond the profile's Edge and mpv.
    apps = {
      chrome.enable = true;
      wechat.enable = true;
      qq.enable = true;
      telegram.enable = true;
      vlc.enable = true;
      obs.enable = true;
      ytDlp.enable = true;
      ffmpeg.enable = true;
    };
    input.vtype.enable = true;
    input.speech.backend = "vinput";
    desktop = {
      graphicalBoot = {
        enable = true;
        # Native 2x theme assets for the 3120x2080 panel.
        scale = 2;
      };
      codexComputerUse.enable = true;
      phone.enable = true;
      screenCast.enable = true;
      # wallpaperEngine.enable = true;
      outputs."eDP-1" = {
        mode = "3120x2080@120";
        scale = 2;
        position = { x = 1280; y = 0; };
      };
    };
    fonts.windows.enable = true;
    kernel.cachyos.enable = true;
    network.proxy.backend = "honk";
    virtualisation = {
      podman.enable = true;
      libvirt.enable = true;
      waydroid.enable = true;
    };
    programs.steam.enable = true;
  };

  # System secrets must be available before /home is mounted.
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Wi-Fi Display discovery on the built-in Wi-Fi interface.
  networking.firewall.interfaces."wlp0s20f3" = lib.mkIf config.my.desktop.screenCast.enable {
    allowedTCPPorts = [ 45545 ];
    allowedUDPPorts = [ 45545 6771 ];
  };
}
