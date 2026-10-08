# Repository Guidelines

## 项目结构与模块组织

本仓库管理 NixOS 与 Home Manager 配置，支持 `laptop`、`home`、`class` 和最小安装配置 `base`。

- `flake.nix`、`flake.lock`：主机入口、依赖锁定、应用包与项目模板。
- `hosts/`：`base.nix` 提供共享配置；各主机的 `default.nix` 管理导入，`features.nix` 选择功能。
- `modules/`：系统服务、`my.features.*.enable` 选项与依赖约束。
- `home-manager/`：Shell、编辑器、Niri、DMS、输入法及脚本和配置资源；输入法测试位于 `home-manager/fcitx5/tests/`。
- `profiles/packages.nix`：独立用户应用；`templates/project/`：项目开发环境模板。
- `docs/`：安装与桌面说明；`secrets/`：加密凭据及规则。

## 构建、检查与开发命令

在仓库根目录执行：

```bash
nix fmt                                # 使用 nixpkgs-fmt 格式化 Nix
nix flake check --no-build              # 检查 Flake 与配置求值
nix flake check                        # 执行 Flake 检查
nixos-rebuild build --flake .#laptop    # 构建目标主机，不激活系统
nix profile install .#anki             # 安装独立用户应用
```

将 `laptop` 替换为目标主机。编程环境使用项目自己的 devShell；在项目目录通过 `nix flake init -t /path/to/nixos-config#project` 初始化模板。仅在需要更新依赖时运行 `nix flake update`。

## 编码风格与命名约定

Nix 使用两空格缩进，以 `nix fmt` 输出为准。模块入口命名为 `default.nix`。功能开关集中声明、按主机启用；共享逻辑放入模块，设备差异保留在 `hosts/<主机>/`。普通应用优先放入 profile。新增脚本使用 `/usr/bin/env` shebang；Python 使用四空格缩进，并遵循相邻文件风格。

## 测试指南

修改配置后检查求值并构建受影响主机；修改共享模块时覆盖各相关主机。Python 回归测试主要使用 `unittest`，文件命名为 `test-*.py`，方法使用 `test_*`。直接运行脚本，避免默认 discovery 漏掉含连字符的文件名：

```bash
python3 home-manager/fcitx5/tests/test-xhup-lookup.py
```

该测试需要 Python 与 PyYAML；其他依赖和真实 Fcitx/Rime 集成测试步骤见输入法文档。仓库未设定覆盖率门槛。桌面、硬件与服务变更还需在目标机器验证。

## 提交与 Pull Request 指南

优先使用 `jj status`、`jj diff`、`jj log` 和 `jj describe`，避免使用会改变仓库状态的 Git 命令。历史通常采用 `feat(scope): 描述`、`refactor(scope): 描述` 等格式；提交聚焦单项变更。

PR 说明变更目的、受影响主机或功能、验证命令与结果；有关联 issue 时链接，界面变更附截图。依赖更新说明原因，行为迁移同步更新文档。

## 配置安全与代理约定

代理回复使用中文。不得提交明文凭据、私钥或解密内容；加密凭据按现有 ragenix 规则维护。不要手工编辑自动生成的硬件配置；`base` 安装前须替换为目标机器生成的文件。先构建再激活；图形登录变更按文档使用 `nixos-rebuild boot` 后重启，不自动清理旧系统代际。
