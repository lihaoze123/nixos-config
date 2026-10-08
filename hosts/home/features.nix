# home 的日常功能：保持重构前的行为。
# 已移到 nix profile 的应用和项目 devShell 中的工具链不在此列。
{ ... }:
{
  my.features = {
    extra.enable = true;
    desktop.enable = true;
    extraDesktop.enable = true; # 需要 desktop
    bluetooth.enable = true;
    tailscale.enable = true;
    dae.enable = true;
    edunet.enable = true;
    aria2.enable = true;
    docker.enable = true;
    wireshark.enable = true;
    appimage.enable = true;
    nixLd.enable = true;
    extraFonts.enable = true;
    aiCli.enable = true;
    speech.enable = true;
    printing.enable = true;
    syncthing.enable = true;

    # 重构前未启用，可按需开启：
    # podman.enable = true;
    # virtualMachines.enable = true;
    # waydroid.enable = true;
    doubao.enable = true; # 需要 speech
    easyeffects.enable = true;
  };
}
