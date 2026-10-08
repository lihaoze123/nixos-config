# class 双系统首次安装

`class` 首次安装时基于 `base` 重建为最小系统。当前已选择开启桌面、常用命令行工具、
常用桌面软件、蓝牙、DAE 代理和校园网自动认证；其他功能保持关闭。
旧 class 的硬件、Home Manager 专属配置和 Niri 布局已删除。
硬件配置已在 2026-10-08 安装时由目标机自动生成，不包含文件系统声明。
本地 build 通过不等于硬件启动已验证。

本次已完成安装并启动验证：主机名 class，root/chumeng 的 laptop 公钥已配置；
root/chumeng SSH 可用，Btrfs 与 ESP 挂载正常，8 GiB swap 已启用，systemd 无失败单元。
首次启动后已重新生成 GRUB 菜单并检测到 Windows Boot Manager。
Wi-Fi 地址仍为 `10.121.60.116`，有线地址为 `10.115.8.199`。

## 目标与磁盘布局

2026-10-08 检查：目标 `root@10.121.60.116` 已在 x86_64 UEFI NixOS 安装环境中。
`/dev/sda` 是 Ventoy U 盘；内置盘是 `/dev/nvme0n1`（FORESEE XP1000F512G，约 477 GiB）。
保留原来的 p1–p7，只使用 p4 与 p5 之间约 178 GiB 未分配空间。

| 新分区 | 标签 | 用途 |
| --- | --- | --- |
| p8，1 GiB | `NIXBOOT` | NixOS 独立 ESP，挂载 `/boot` |
| p9，约 176.7 GiB | `nixos` | Btrfs，子卷 root/home/nix/swap；含 8 GiB swapfile |

Windows ESP 的 UUID 是 `B6E9-B042`，只读挂载 `/boot/windows`，不交给 disko。
`disko/btrfs-partitions.nix` 直接指向两个新分区，没有 GPT 整盘配置。
下列分区、安装命令是后续执行步骤；准备本地配置时未执行。

## 本地构建

```bash
cd ~/nixos-config
jj status
nix flake check --no-build
nix build .#nixosConfigurations.class.config.system.build.toplevel --out-link result-class
nix build .#nixosConfigurations.class.config.system.build.diskoScript --out-link result-class-disko
```

## 创建新分区

先确认磁盘布局仍和上述检查一致。保留 Windows 时应关闭快速启动；重要数据先备份。

```bash
ssh root@10.121.60.116 'lsblk; parted -s /dev/nvme0n1 unit GiB print free'
ssh root@10.121.60.116 'sgdisk --pretend -n 0:0:+1G -t 0:ef00 -c 0:NIXBOOT -n 0:0:0 -t 0:8300 -c 0:nixos -p /dev/nvme0n1'
```

确认演练只新增上述 p8/p9 后，以下命令会实际修改分区表（只执行一次）：

```bash
ssh root@10.121.60.116 'sgdisk -n 0:0:+1G -t 0:ef00 -c 0:NIXBOOT -n 0:0:0 -t 0:8300 -c 0:nixos -p /dev/nvme0n1 && partprobe /dev/nvme0n1 && udevadm settle'
ssh root@10.121.60.116 'lsblk -o NAME,SIZE,FSTYPE,PARTLABEL; ls -l /dev/disk/by-partlabel/NIXBOOT /dev/disk/by-partlabel/nixos'
```

## 安装

当前 nixos-anywhere/disko 的 `format` 模式只创建文件系统，不会挂载 `/mnt`。
先单独格式化，然后用 `mount` 模式挂载并安装，两个步骤均跳过 destroy。
`--phases disko,install,reboot` 适用于当前已启动的安装环境。

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#class \
  --disko-mode format \
  --phases disko \
  --generate-hardware-config nixos-generate-config ./hosts/class/hardware-configuration.nix \
  --target-host root@10.121.60.116

nix run github:nix-community/nixos-anywhere -- \
  --flake .#class \
  --disko-mode mount \
  --phases disko,install,reboot \
  --target-host root@10.121.60.116
jj status
```

文件系统完全由 disko 声明，生成的硬件配置不应重复声明文件系统。
安装工具会改写本地 `hosts/class/hardware-configuration.nix`，安装后检查并保留该变更。
参数说明见 [nixos-anywhere 官方文档](https://nix-community.github.io/nixos-anywhere/reference.html)。

## 首次登录与更新

root 和 chumeng 均允许 laptop 公钥登录 SSH。没有配置登录密码，首次登录 root 后用
`passwd chumeng` 设置本地登录和 sudo 密码。设置前通过 root 做管理操作。
本次安装已将安装环境正在使用的 HHU-WiFi 连接配置复制到新系统，权限为 0600，
该文件只保存在目标机，不进入配置仓库。此 flake 本身不声明 Wi-Fi 连接；以后重装需
重新迁移连接配置，或在目标机 root 控制台用 `nmtui` 配置 Wi-Fi。也可使用已插入的有线网络。
重启后 IP 可能变化。

```bash
ssh root@<启动后的IP>
passwd chumeng
```

若 GRUB 尚未显示 Windows，首次进 NixOS 后以 root 运行
`nixos-rebuild boot --flake /path/to/nixos-config#class`，再重启。
共享配置允许写入 EFI 启动项，固件的默认启动顺序可能改变。

日常更新从本机执行：

```bash
nixos-rebuild switch --flake .#class --target-host root@<IP>
```

需要桌面或其他功能时编辑 `hosts/class/features.nix`。

## 加密凭据

`secrets/keys.nix` 已登记 `class`（SSH 主机公钥）和 `class-user`（chumeng 的 SSH 公钥）。
系统 agenix 使用 `/etc/ssh/ssh_host_ed25519_key`；Home Manager 使用
`/home/chumeng/.ssh/id_ed25519`，均覆盖 base 的旧 id_rsa 路径。
两把私钥只保存在目标机；重装前须单独备份，或在重装后生成新密钥并重新加密。

系统 secrets 的收件人包含 class；用户 AI CLI secrets 的收件人包含 class-user；
豆包凭据也包含 class-user。laptop 和 home 的权限保留。
已重新加密并在目标机验证全部对应文件可解密，同时核对明文内容未变。
密钥配置已应用；开启服务后才会部署对应凭据。

## 桌面配置

`hosts/class/features.nix` 开启 desktop、graphicalBoot、extra、extraDesktop、bluetooth、dae、edunet、aiCli、codexDesktop。
内屏 eDP-1 固定使用 `1920x1080@50.002`、100% 缩放，greeter 与桌面一致。
这是屏幕 EDID 提供的非整数刷新率模式；是否解决静止画面黑屏仍需实机观察。
DMS 的显示设置会覆盖 Niri 基础配置；已有配置的机器还须在 DMS 设置 → 显示中
选择 eDP-1、1920×1080、50.002 Hz 并应用，避免继续使用其保存的 60.000 Hz。
Niri 与 Neovim 的配置直接随系统部署，不依赖目标机上的 `~/nixos-config` checkout。
class 与 laptop 共用 Codex Desktop 和 computer use 集成，使用带 agent input 补丁的 Niri，
启用 is-agent-driven 窗口规则；关闭 codexDesktop 时恢复标准 Niri 并禁用该规则。
用户 chumeng 加入 ydotool 组，系统部署 uinput 权限、ydotool 服务和 AT-SPI 支持。
命令行入口为 `codex-desktop` 和 `codex-computer-use`（MCP 模式使用 `codex-computer-use mcp`）。
首次启用须按下方步骤写入下一次启动并重启，让新 Niri 和组权限生效。
DMS 布局文件采用可选 include，以支持首次启动。
小鹤个人词库已从本机复制到目标机的 `~/src/xhup-dicts`（仅词库文件快照，未复制 Git 私钥）。
以后可以自行连接词库仓库或同步这些文件。

`graphicalBoot` 与 laptop 共用 `modules/graphical-boot/default.nix`：隐藏 GRUB 菜单并等待
1 秒，显示深色背景、紫色 NixOS 标志与转圈，隐藏常规启动文字，并在 Dank Greeter
接管屏幕后保留 Plymouth 最后一帧退出。class 提前在 initrd 加载 i915，主题使用
1 倍素材；laptop 使用 2 倍素材。开机时按 Esc 可显示 GRUB 菜单并选择 Windows
或旧系统代际；在 Plymouth 画面按 Esc 可查看启动日志。

桌面/登录管理器变更先构建、验证，再写入下一次启动：

```bash
nixos-rebuild boot --flake .#class --target-host root@10.121.60.116
```

重启后生效，不在运行的会话中切换登录管理器。


2026-10-08 已完成远程 `boot` 部署并重启验证：greetd、蓝牙和 DAE 服务运行正常，
Home Manager 激活成功，目标机 Niri 配置验证通过。校园网检查成功，
`edunet-check.timer` 已启动。`/etc/dae/config.dae` 与 `/etc/edunet/edunet.env`
均已解密，权限为 `0400 root:root`，内容已与本地加密文件解密结果核对一致。
