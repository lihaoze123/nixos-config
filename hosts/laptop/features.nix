# laptop 的日常功能：保持重构前的行为。
# 已移到 nix profile 的应用和项目 devShell 中的工具链不在此列。
{ ... }:
{
  my.features = {
    desktop.enable = true;
    bluetooth.enable = true;
    tailscale.enable = true;
    dae.enable = true;
    edunet.enable = true;
    aria2.enable = true;
    docker.enable = true;
    podman.enable = true;
    virtualMachines.enable = true;
    waydroid.enable = true;
    wireshark.enable = true;
    appimage.enable = true;
    nixLd.enable = true;
    extraFonts.enable = true;
    aiCli.enable = true;
    speech.enable = true;
    doubao.enable = true; # 需要 speech
    easyeffects.enable = true;
    dms.enable = true; # 需要 desktop
    codexDesktop.enable = true;
    fingerprint.enable = true;
    cachyosKernel.enable = true;
    steam.enable = true;
    phoneIntegration.enable = true;
    screenCast.enable = true;
  };
}
