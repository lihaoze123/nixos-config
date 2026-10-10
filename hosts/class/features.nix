# class 的功能选择：桌面、常用工具、蓝牙、代理和校园网认证。
# 这里只列出共享模块实现的功能；指纹、CachyOS 内核、Steam 等属于具体主机。
{ ... }:
{
  my.features = {
    extra.enable = true;
    desktop.enable = true;
    graphicalBoot.enable = true; # 需要 desktop
    extraDesktop.enable = true; # 需要 desktop
    bluetooth.enable = true;
    # tailscale.enable = true;
    honk.enable = true;
    # dae.enable = true;
    edunet.enable = true;
    # aria2.enable = true;
    # docker.enable = true;
    # podman.enable = true;
    # virtualMachines.enable = true;
    # waydroid.enable = true;
    # wireshark.enable = true;
    # appimage.enable = true;
    nixLd.enable = true;
    # extraFonts.enable = true;
    aiCli.enable = true;
    codexDesktop.enable = true; # 需要 desktop
    # speech.enable = true; # 需要 desktop
    # doubao.enable = true; # 需要 speech
    # easyeffects.enable = true; # 需要 desktop
  };
}
