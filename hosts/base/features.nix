# 最小系统的功能选择：默认全部关闭，按需取消注释。
# 这里只列出共享模块实现的功能；指纹、CachyOS 内核、Steam 等属于具体主机。
{ ... }:
{
  my.features = {
    # desktop.enable = true;
    # dms.enable = true; # 需要 desktop
    # bluetooth.enable = true;
    # tailscale.enable = true;
    # dae.enable = true;
    # edunet.enable = true;
    # aria2.enable = true;
    # docker.enable = true;
    # podman.enable = true;
    # virtualMachines.enable = true;
    # waydroid.enable = true;
    # wireshark.enable = true;
    # appimage.enable = true;
    # nixLd.enable = true;
    # extraFonts.enable = true;
    # aiCli.enable = true;
    # speech.enable = true; # 需要 desktop
    # doubao.enable = true; # 需要 speech
    # easyeffects.enable = true; # 需要 desktop
  };
}
