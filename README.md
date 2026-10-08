# NixOS 配置仓库

模块化 NixOS + Home Manager 配置，支持 laptop、home、class 三台主机，以及供新机器首次安装的最小配置 `base`。各主机通过自己的 `features.nix` 选择功能；class 基于 base 重建，按需启用桌面、常用工具、蓝牙、代理和校园网认证。普通应用交给 `nix profile`，编程环境由各项目自己的 devShell 管理。

## 安装与构建

```bash
# 各主机的日常配置
nixos-rebuild build --flake .#laptop   # 别名 .#nixos
nixos-rebuild build --flake .#home
nixos-rebuild build --flake .#class

# 最小系统：先用目标机器生成 hosts/base/hardware-configuration.nix
nixos-rebuild build --flake .#base
```

改变图形登录配置时，构建通过后使用 `sudo nixos-rebuild boot --flake .#<主机>` 并重启。切换前先用 `nix profile` 装好移出系统的应用。

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

- `flake.nix` / `flake.lock`：锁定输入、主机入口、独立 profile 包和项目模板。
- `hosts/base.nix`：启动、网络、用户、SSH、防火墙、Nix 和 direnv。
- `hosts/<主机>/features.nix`：选择主机功能；base 默认全部关闭，class 按选择开启。
- `hosts/base/`：独立的最小配置，功能默认全部关闭，硬件配置为占位文件。
- `hosts/installer/`：独立的安装镜像配置，构建输出为 `installer-iso`。
- `hosts/<主机>/default.nix`：主机及硬件相关配置。
- `modules/features.nix`：`my.features.*.enable` 选项、基础集成和依赖约束。
- `modules/`：桌面、代理、下载、校园网和虚拟化服务。
- `home-manager/`：Shell、编辑器以及受开关控制的桌面与输入法配置。
- `profiles/packages.nix`：通过 `nix profile install .#包名` 按需安装应用。
- `templates/project/`：项目自己的 Rust/C++/Node/Python/Java devShell 模板。
- `secrets/`：age 加密凭据，相关功能开启时使用。

## 常用操作

```bash
# 逐个安装用户应用，不需要重建系统
nix profile install .#wechat
nix profile install .#anki .#obsidian
nix profile install .#vscode

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
