# NixOS 配置仓库

模块化 NixOS + Home Manager 配置，支持 laptop、home、class 三台主机，以及供新机器首次安装的最小配置 `base`。各主机通过自己的 `features.nix` 选择功能并保持原有行为；普通应用交给 `nix profile`，编程环境由各项目自己的 devShell 管理。

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

## 配置结构

- `flake.nix` / `flake.lock`：锁定输入、主机入口、独立 profile 包和项目模板。
- `hosts/base.nix`：启动、网络、用户、SSH、防火墙、Nix 和 direnv。
- `hosts/<主机>/features.nix`：选择主机功能，laptop、home、class 保持原有行为。
- `hosts/base/`：独立的最小配置，功能默认全部关闭，硬件配置为占位文件。
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
