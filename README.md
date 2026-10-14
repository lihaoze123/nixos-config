# NixOS 配置仓库

模块化 NixOS + Home Manager 配置，支持 laptop、home、class 三台主机，以及供新机器首次安装的最小配置 `base`。各主机选择一个 profile（`workstation` 或 `personal`），再在自己的 `default.nix` 中覆盖 `my.*` 开关。普通应用交给 `nix profile`，编程环境由各项目自己的 devShell 管理。

## 安装与构建

```bash
# 各主机的日常配置
nixos-rebuild build --flake .#laptop   # 别名 .#nixos
nixos-rebuild build --flake .#home
nixos-rebuild build --flake .#class

# 最小系统：先用目标机器生成 hosts/base/hardware-configuration.nix
nixos-rebuild build --flake .#base
```

改变图形登录配置时，构建通过后使用 `sudo nixos-rebuild boot --flake .#<主机>` 并重启。

功能开关、应用安装、项目环境及迁移注意事项见 [分阶段安装指南](docs/installation-profiles.md)。
class 的分区、首次安装和登录命令见 [class 双系统安装指南](docs/class-installation.md)。

### 自定义安装镜像

`installer` 是独立的 x86_64 Linux 安装环境，使用 NixOS minimal ISO，开机启用 SSH，
并允许 `secrets/keys.nix` 中的 `laptop` 公钥登录 root。镜像包含 Git、Jujutsu（`jj`）、Vim、NetworkManager
和 Nix flakes 支持，配置了清华 Nix 缓存；不导入日常主机的共享配置和功能模块。

在仓库根目录构建镜像，使用独立的输出链接保留日常系统构建的 `result`：

```bash
nix build .#installer-iso --out-link result-installer
ls -lh result-installer/iso/*.iso

# 等价的 host 构建入口
nix build .#nixosConfigurations.installer.config.system.build.isoImage --out-link result-installer
```

可以将 `result-installer/iso/` 下的 ISO 复制到 Ventoy，也可以直接写入 U 盘。
下面的 `dd` 会覆盖整个目标设备，先用 `lsblk` 确认 U 盘，并将 `/dev/sdX` 替换为实际设备（不是分区）：

```bash
lsblk
sudo dd if=result-installer/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

目标机从镜像启动后，有线网络通常自动连接；Wi-Fi 可用 `nmtui` 配置。
通过 `ip a` 查看目标机 IP，再从持有 laptop 对应 SSH 私钥的机器连接：

```bash
ssh root@<IP>
```

## 配置结构

- `flake.nix` / `flake.lock`：锁定输入、主机入口、安装镜像和项目模板。
- `lib/default.nix`：`mkHost`，为每台主机接入 `modules/nixos`、Home Manager 和 `hosts/<主机>`，并设置主机名。
- `modules/options.nix`：全部 `my.*` 开关的集中声明与依赖断言。
- `modules/nixos/`：系统层。`core.nix`（启动、网络、用户、SSH、防火墙、Nix、direnv）、`nix-cache.nix`、`overlays.nix`，以及 `desktop/`、`hardware/`、`network/`、`services/`、`virtualisation.nix`、`programs.nix`。
- `modules/home/`：Home Manager 层。`shell/`、`desktop/`（Niri、DMS、输入法、文件管理等） 与 `ai/`。
- `profiles/`：`workstation.nix`（所有桌面主机共用）与 `personal.nix`（laptop、home 的个人功能），均以 `mkDefault` 设置，主机可直接覆盖。
- `hosts/<主机>/`：选择 profile、覆盖开关，并放置硬件与单主机配置；`home.nix` 为该主机的 Home Manager 覆盖。`hosts/base/` 是功能全关的最小配置，`hosts/installer/` 为独立安装镜像。
- 自定义软件包在独立 [nur-packages](https://github.com/lihaoze123/nur-packages) 仓库维护；本仓库通过 Flake 输入引用。
- `templates/project/`：通用 devShell 模板（`#project`）和 Java 8 Servlet/JSP 可执行 JAR 模板（`#java-webapp`）。
- `secrets/`：系统与 Home Manager 共用的 age 加密凭据，收件人规则见 `secrets/secrets.nix`。

## 常用操作

```bash
# 逐个安装用户应用，不需要重建系统
nix profile install nixpkgs#wechat
nix profile install nixpkgs#anki nixpkgs#obsidian
nix profile install github:lihaoze123/nur-packages#vscode

# 版本管理使用 Jujutsu
jj status
jj diff

# 更新输入、检查与格式化
nix flake update
nix flake check
nix fmt
```

不编辑自动生成的 `hardware-configuration.nix`。新增脚本使用 `/usr/bin/env` shebang。先 build 再激活，不自动清理旧系统代际。

笔记本登录、启动画面与锁屏细节见 [Laptop 桌面说明](docs/laptop-desktop.md)。
