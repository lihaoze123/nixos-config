# Oracle Cloud VPS：nixos-anywhere + disko

本配置的 flake 入口为 `#vps`。文档中的 `<VPS_IP>` 是占位符，执行命令前替换为实例的实际 IP，不要原样运行。本文包含只读核对、首次安装与后续更新步骤；只有实际重装时才运行安装命令。

## 目标与布局

实例是 Oracle Cloud Singapore 的 ARM64 虚拟机：4 核 Neoverse-N1、约 24 GiB 内存、UEFI、virtio SCSI 引导卷。引导卷已在控制台扩容至 150 GB，设备重新扫描后识别为 150 GiB（161061273600 字节）。disko 不固定根分区容量，始终使用整盘剩余空间。

| 项目 | 配置 |
| --- | --- |
| 主机与架构 | `vps` / `aarch64-linux` |
| 目标磁盘 | `/dev/disk/by-id/scsi-3605da4698b0f4bbfb46b19c18c3d2ac5`（当前 `/dev/sda`） |
| 分区表 | 整盘 GPT；覆盖现有 Ubuntu，无双系统保留逻辑 |
| `/boot` | 512 MiB EFI System Partition，vfat |
| `/` | 剩余全部空间，ext4；不单独分 `/home`，不加密 |
| swap | zram，上限 2 GiB，无磁盘 swap |
| 引导 | GRUB EFI removable 路径，不写 EFI variables；串口 `ttyAMA0,115200` |
| 网络 | 按 MAC `02:00:17:03:51:20` 匹配，networkd DHCPv4/DHCPv6 + IPv6 RA，MTU 9000 |
| 公网地址 | IPv4 由 OCI 映射到 DHCP 内网地址，不能将公网 IPv4 配在接口上 |
| 登录 | `chumeng`，现有个人 RSA 与 class Ed25519 公钥，免密 sudo |
| SSH | TCP 22；禁用密码、键盘交互认证和 root SSH 登录 |
| Nix 缓存 | 仅 `https://cache.nixos.org`，不解密个人设备缓存 token，不复制个人私钥 |

机器专属设置在 [hosts/vps/default.nix](../hosts/vps/default.nix)，磁盘布局在 [disk-config.nix](../hosts/vps/disk-config.nix)。[hardware.nix](../hosts/vps/hardware.nix) 是根据现有 OCI 虚拟硬件手写的模块，导入上游 QEMU guest 驱动；无需复制其他主机自动生成的硬件配置，也不要导入 `disko/btrfs-partitions.nix`。

重建实例、替换引导卷或 VNIC 后，须重新核对磁盘标识、MAC、架构及 SSH 公钥。

## 软件范围

- 基础工具：归档解压、file、which、tree、GNU 文本工具、GnuPG、DNS 查询、wget、direnv/nix-direnv、ragenix、nix-output-monitor。
- CLI：Git、Jujutsu、delta、fd、fzf、ripgrep、eza、bat、jq、tmux。
- cli-extra 子集：btop、tealdeer、ouch、iperf、nh；总开关仍关闭，按包选取。
- Shell：Fish、Starship（含 JJ 状态）、zoxide；关闭 Atuin、nix-index/comma。
- 编辑器：简洁 Neovim，无 LazyVim、插件自举、GCC、Node.js 或 clang-tools；共享系统层仍有 Vim。

启用系统级 Docker 和 rootless Docker，`chumeng` 加入 `docker` 组，Docker CLI 默认连接 rootless 用户 socket。启用 linger，让用户服务在开机时启动、退出 SSH 后保持运行。业务服务包含由 NixOS 管理的 Cloudreve、AutoBangumi、qBittorrent、Emby 容器与原生 wastebin、Forgejo、Memos 服务，见 [Cloudreve 使用说明](vps-cloudreve.md)、[wastebin 使用说明](vps-wastebin.md)、[私有 Git 服务](vps-forgejo.md)、[Memos 笔记](vps-memos.md)、[私有 Attic 缓存](nix-cache.md) 和 [自动追番与 Emby](vps-media.md)。启用 Mosh，不启用桌面、AI、代理或 Tailscale。时区与 locale 沿用共享配置的 `Asia/Shanghai` 和 `zh_CN.UTF-8`。

Mosh 沿用 SSH 公钥认证，由 SSH 按需启动 `mosh-server`，无需常驻服务。客户端使用 `mosh chumeng@<VPS_IP>`，或 `mosh <SSH 别名>` 连接；会话随后通过 UDP 60000–61000 通信。

2026-10-25 已完成 Mosh 的远端构建、激活预览和 deploy-rs 正式部署。`mosh-server` 版本为 1.4.0，nftables 已放行 UDP 60000–61000，实际 Mosh 会话成功返回测试标记并正常退出。SSH、防火墙与 Nginx 服务正常，系统失败服务为 0，无需重启 VPS。

登录后使用 `docker info` 查看 rootless 状态，通过 `systemctl --user status docker` 查看用户服务状态。加入 `docker` 组后需重新登录，之后可使用 `docker -H unix:///var/run/docker.sock info` 访问系统级 Docker，无需 sudo。

网络调优由 [network-tuning.nix](../hosts/vps/network-tuning.nix) 声明，使用内核自带的 BBR 拥塞控制与 fq 队列。`vps-wan-fq.service` 等待 `enp0s6` 出现后更新发送队列，保留网卡的 mq 多队列结构；仅设置 `net.core.default_qdisc` 不会替换已存在的队列。部署后用 `sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc` 和 `tc qdisc show dev enp0s6` 核对，预期分别为 `bbr`、`fq`，以及 mq 下的 fq 子队列。运行中的临时调参不代替配置部署。

LibreTV 部署在 `https://tv.chumeng.xyz`，使用独立的访问密码及固定摘要的 ARM64 容器；数据源配置和使用方法见 [LibreTV](vps-libretv.md)。

## 防火墙管理

OCI 云侧对本 VPS 放行所有入站协议与端口，服务端口统一由 NixOS 的 `networking.firewall` 管理。2026-10-16 已在仅关联 VPS VNIC 的 `ig-quick-action-NSG` 中添加两条有状态入站规则：来源 `0.0.0.0/0` 和 `::/0`，协议均为“所有协议”。NSG 与子网安全列表的允许规则取并集，子网原有的窄范围规则不限制这两条放行规则。

主机使用 nftables，入站默认丢弃；当前允许 TCP 22、80、443、51413，UDP 51413 和 Mosh 使用的 UDP 60000–61000，以及 NixOS 默认的 ICMP、DHCP 等必要流量。51413 用于 qBittorrent 的 BT 连接；AutoBangumi、Emby 和下载器的 Web 端口均只发布在回环地址。`trustedInterfaces` 仅包含 `lo`。Cloudreve 通过 `https://pan.chumeng.xyz` 公开访问，80 端口用于跳转 HTTPS 和 ACME 证书验证；应用容器仅发布至 `127.0.0.1:5212`，数据库和 Redis 不发布端口。后续公开服务须在 Nix 配置中声明监听地址和对应 `allowedTCPPorts` / `allowedUDPPorts`，构建并部署后生效，无需再逐端口修改 OCI。新建或更换 VNIC 时，需重新确认其关联了该 NSG。

## 安装前核对（只读）

在本仓库根目录操作。先准备 OCI 控制台与串口控制台入口，确认 SSH 密钥可用；云侧安全列表/NSG 也需要允许当前来源的 TCP 22（本 VPS 已通过上述全入站 NSG 放行）。

```bash
ssh ubuntu@<VPS_IP> 'uname -m'
ssh ubuntu@<VPS_IP> 'sudo -n true'
ssh ubuntu@<VPS_IP> 'lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS'
ssh ubuntu@<VPS_IP> 'readlink -f /dev/disk/by-id/scsi-3605da4698b0f4bbfb46b19c18c3d2ac5'
ssh ubuntu@<VPS_IP> 'ip -br address'
ssh-keygen -lf hosts/vps/authorized_keys

jj status
nix eval --raw .#nixosConfigurations.vps.config.nixpkgs.hostPlatform.system
nix eval --json .#nixosConfigurations.vps.config.disko.devices.disk.main
nix eval --json .#nixosConfigurations.vps.config.services.openssh.settings
```

架构应为 `aarch64`，磁盘应指向 `/dev/sda`，卷扩容生效后整盘容量应为 150G。只需确认整盘容量，不必为即将清空的 Ubuntu 扩大原根分区。若控制台已扩容而 `lsblk` 仍是 100G，可按卷页面给出的设备重新扫描步骤刷新容量后再核对。

仓库公钥指纹应为：

- RSA 3072：`SHA256:ZHIaijFOZNPyfM7FJ0qnROvcIdevFynATTiB0N/teaE`（`chumeng@chumeng`）。
- Ed25519：`SHA256:J/KEcMqDmM5uT0fn4WrBowDCCkPQ07+k9halP66Dhr8`（`chumeng@class`）。

这些是登录公钥，不是个人私钥。当前 Ubuntu 上的两把授权公钥已用于本配置。

## 实际安装（会清空整块引导卷）

确认当前 Ubuntu 与所有数据均可丢弃后，再运行本节命令。先启动内存中的安装环境，再由 nixos-anywhere 执行 disko 重分区、构建并安装系统，最后重启。安装过程中 SSH 会短暂断开；不要同时运行其他重分区或部署操作。

固定安装器版本为 `bc36798d8fcad7ee85ac139c8473e999afbf4a1d`，其源码已支持 ARM64 默认 kexec 镜像。不过，本机原有 Ubuntu `6.8.0-1060-oracle` 在直接 kexec 时出现磁盘 I/O 阻塞，`--no-sync` 也未解决；当次安装通过临时 GRUB 菜单正常引导进入内存安装环境。该一次性准备脚本不再保留在仓库。

以下命令从已经启动的 ARM64 NixOS 内存安装环境开始。未来重装时，需要根据当时的系统重新核对引导方式，不能直接在运行中的磁盘系统跳过这一步。先确认 root SSH 可用、系统为 NixOS 安装器且 `/` 是 tmpfs；此时原磁盘尚未格式化。安装前应备份服务器 SSH 主机密钥，以保留主机身份及未来服务密钥的解密能力：

```bash
ssh root@<VPS_IP> 'cat /etc/os-release; findmnt /; lsblk'
```

### 执行分区与安装

```bash
nix run github:nix-community/nixos-anywhere/bc36798d8fcad7ee85ac139c8473e999afbf4a1d -- \
  --flake .#vps \
  --target-host root@<VPS_IP> \
  --build-on remote \
  --copy-host-keys \
  --phases disko,install,reboot
```

`--build-on remote` 在 ARM VPS 原生构建，适合从当前 x86_64 工作站发起，不要求本机配置 ARM 仿真。这里连接内存安装器的 root，`--phases` 跳过已经完成的引导步骤。`--copy-host-keys` 保留服务器 SSH 主机身份，避免正常重装导致 known_hosts 变化；它不会复制个人登录私钥。

本配置已用 QEMU guest 模块提供 virtio 驱动，并由 disko 声明文件系统，无需再加 `--generate-hardware-config`。安装器构建使用仓库的 `flake.lock`；无需运行 `nix flake update`。

## 安装后验证

安装完成后改用 `chumeng` 登录，原来的 `ubuntu` 账户不再存在，root SSH 已关闭：

```bash
ssh chumeng@<VPS_IP>
sudo -n true
hostname
uname -m
findmnt /
findmnt /boot
df -h /
swapon --show
networkctl status
systemctl --failed
```

应看到主机名 `vps`、架构 `aarch64`、ext4 根分区、vfat `/boot` 和 zram swap。IPv4/IPv6 实际连通性、EFI 启动和首次 SSH 登录仍需要安装后在目标实例验证，配置求值不能替代这些检查。

### 本机安装验证记录（2026-10-16）

已通过正常 EFI 引导启动 NixOS `26.11.20261006.151fa4e`，内核 `6.18.55`。`chumeng` 公钥登录、免密 sudo、Fish 和无插件的 Neovim 启动均正常；SSH、networkd、resolved 与 Home Manager 服务正常，失败服务为 0。

整盘为 150 GiB：`/boot` 512 MiB，ext4 根分区约 149.5 GiB，文件系统显示约 147 GiB；zram 为 2 GiB。已确认 root SSH 登录被拒绝，密码及键盘交互认证禁用。

IPv4 和 IPv6 均可访问官方缓存。已在 OCI 路由表添加 `::/0 → ig-quick-action-IGW`，子网安全列表原有的有状态 IPv6 出站规则已允许所有协议，无需新增安全规则或重启系统。强制 IPv6 访问 `https://cache.nixos.org/nix-cache-info` 返回 `200 OK`，公网 IPv6 ping 3 次全部成功。DHCPv6 与 RA 继续由 networkd 自动配置；见 [上游 IPv6 网络说明](https://wiki.nixos.org/wiki/Install_NixOS_on_Oracle_Cloud#Networking)。

子网安全列表原本已允许来自 `::/0` 的 TCP 22 和 ICMPv6 Packet Too Big；默认路由生效后，SSH 也可经公网 IPv6 访问，仍仅接受公钥认证。

后续发现 Nix 无法解析域名，而 `getent`/wget 正常：原因是将 `trustedInterfaces` 强制清空，覆盖了 NixOS 默认的 `lo` 放行，导致通过本机 DNS stub（`127.0.0.53`）查询的程序超时。配置已修正为仅信任 `lo`，并通过 deploy-rs 完成远端构建、激活预览、正式激活与连接确认。主动重新加载 `nftables.service` 后，回环放行规则仍存在，DNS 查询、`nix registry list` 与 IPv4/IPv6 HTTPS 均通过，修复已持久化。SSH、networkd、resolved 和 Home Manager 服务正常，失败服务为 0；此次部署无需重启，旧系统代际保留。

## 后续更新

首次安装完成后，使用原生 deploy-rs 更新 VPS；`nix run .#deploy` 直接调用仓库锁定版本的 CLI。每次通过 `--hostname` 手动指定实际 IP，仓库不保存部署地址。`deploy.nodes.vps.hostname` 中的 `vps` 仅为逻辑占位名。

部署使用 `chumeng` 登录，再通过 sudo 以 root 激活。先确认连接和 sudo 可用：

```bash
ssh 'chumeng@<VPS_IP>'
# 退出远端 SSH，回到本地后继续
ssh 'chumeng@<VPS_IP>' 'sudo -n true'
```

修改本地配置后，在仓库根目录运行：

```bash
jj status

# 构建并预览激活变更，不切换运行中的服务；仍会完整构建系统
nix run .#deploy -- .#vps --hostname '<VPS_IP>' --skip-checks --dry-activate

# 正式部署：在 ARM VPS 构建成功后激活
nix run .#deploy -- .#vps --hostname '<VPS_IP>' --skip-checks
```

`remoteBuild = true` 在 VPS 上原生构建，CLI 与激活程序由 `flake.lock` 中同一份 deploy-rs 版本提供。deploy-rs 默认先运行整个仓库的 `nix flake check`；这里显式传入 `--skip-checks`，避免触发无关主机的检查构建，不会跳过实际部署所需的构建。

`autoRollback = true` 在激活失败时尝试恢复上一版本；`magicRollback = true` 要求客户端在激活后确认连接，超时未确认则由目标机回滚。这不替代业务健康检查、数据备份或重启后的引导验证。`--dry-activate` 也会构建完整系统，需要准备实际部署时再执行。

仍可使用原生 nixos-rebuild。先构建成功，再激活：

```bash
nixos-rebuild build --flake .#vps \
  --build-host chumeng@<VPS_IP> \
  --target-host chumeng@<VPS_IP> \
  --sudo

nixos-rebuild switch --flake .#vps \
  --build-host chumeng@<VPS_IP> \
  --target-host chumeng@<VPS_IP> \
  --sudo
```

不要再次运行 nixos-anywhere 来做日常更新，因为其默认流程会重分区。旧系统代际不自动清理。

### 日常维护

- 软件与服务改动写回 `hosts/vps/` 或共享模块，先做相关选项的局部求值，再按上面的预览、部署顺序执行。
- 升级软件时显式更新 `flake.lock`，例如 `nix flake update nixpkgs home-manager`；检查差异后部署。共享输入升级也会影响其他主机，不要仅为修改 VPS 配置而更新全部输入。
- 部署后登录检查 `systemctl --failed`、`dig @127.0.0.53 channels.nixos.org`，以及 `wget -4`、`wget -6` 访问官方缓存，并验证新增服务。内核或引导变更需安排重启，再检查实际内核、SSH 与服务。`system.stateVersion` 不随软件升级而递增。
- 保留最近确认可用的系统代际。若激活后应用异常但 SSH 仍可用，可登录后执行 `sudo nixos-rebuild switch --rollback`；重启失败时通过 OCI 控制台选择旧代际。自动回滚不替代重启验证。
- 备份业务数据和恢复所需密钥；OCI 路由、安全列表和卷配置也应记录。NixOS 回滚不会恢复数据库或用户文件。观察 `df -h / /boot`，确认不再需要旧代际后再手动清理。

## 上游依据

- [nixos-anywhere Quickstart](https://nix-community.github.io/nixos-anywhere/quickstart.html)：SSH、免密 sudo、disko 与安装流程。
- [固定版本的安装器源码](https://github.com/nix-community/nixos-anywhere/blob/bc36798d8fcad7ee85ac139c8473e999afbf4a1d/src/nixos-anywhere.sh)：ARM64 kexec、远端构建和主机密钥复制。
- [Nixpkgs OCI 模块](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/oci-common.nix)：串口与 EFI removable 引导策略；本配置只参考所需设置，不导入其文件系统声明。
- [disko EFI + ext4 示例](https://github.com/nix-community/disko/blob/master/example/simple-efi.nix)。
- [deploy-rs 配置与回滚机制](https://github.com/serokell/deploy-rs)：远端构建、SSH/sudo 与自动回滚。
- [deploy-rs CLI 源码](https://github.com/serokell/deploy-rs/blob/master/src/cli.rs)：默认 Flake 检查、`--skip-checks` 与 `--dry-activate`。
