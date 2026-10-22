# Repository Guidelines

## 项目结构与模块组织

本仓库管理 NixOS 与 Home Manager 配置，支持 `laptop`、`home`、`class` 和最小安装配置 `base`。

- `flake.nix`、`flake.lock`：输入、主机入口与项目模板；`lib/` 提供 `mkHost`，统一接入共享模块、Home Manager 与主机目录。
- `modules/options.nix`：集中声明全部 `my.*` 开关（`my.desktop`、`my.network.proxy`、`my.apps` 等）及依赖断言。
- `modules/nixos/`：系统层，`core.nix` 为所有主机共用的基础，其余按 desktop、hardware、network、services、virtualisation、programs 分组。
- `modules/home/`：Home Manager 层，分为 shell、desktop（Niri、DMS、输入法）、ai 和 `apps.nix`（日常图形应用）；输入法测试位于 `modules/home/desktop/fcitx5/tests/`。
- `profiles/`：角色组合，以 `mkDefault` 打开一组开关；`workstation` 为所有桌面主机共用，`personal` 在其上增加 laptop、home 的个人功能。
- `hosts/<主机>/`：`default.nix` 选择 profile 并覆盖开关，硬件与单主机配置（指纹、打印、NVIDIA 等）直接写在此目录，不设共享开关；`home.nix` 放该主机的 Home Manager 覆盖。
- 自定义软件包维护于独立 `nur-packages` 仓库，本仓库仅引用；`templates/project/`：项目开发环境模板。
- `docs/`：安装与桌面说明；`secrets/`：加密凭据及规则。

## 构建、检查与开发命令

**除非用户明确要求，否则永远不要运行完整构建。** 修改配置、修复问题或一般验证请求不构成完整构建授权。此限制包括 `nixos-rebuild build/boot/switch/test`、构建 `system.build.toplevel` 的 `nix build` 及其他会构建完整系统的等价命令；也不要自动运行会执行构建的 `nix flake check`。

在仓库根目录执行：

```bash
nix fmt                                # 使用 nixpkgs-fmt 格式化 Nix
nix flake check --no-build              # 检查 Flake 与配置求值
nix flake check                        # 仅用户明确要求时执行含构建的 Flake 检查
nixos-rebuild build --flake .#laptop    # 仅用户明确要求时构建目标主机，不激活系统
nix shell nixpkgs#hello                # 临时试用软件；确定长期使用后写入 modules/home/apps.nix
```

将 `laptop` 替换为目标主机。编程环境使用项目自己的 devShell；在项目目录通过 `nix flake init -t /path/to/nixos-config#project` 初始化模板。仅在需要更新依赖时运行 `nix flake update`。

## 编码风格与命名约定

Nix 使用两空格缩进，以 `nix fmt` 输出为准。模块入口命名为 `default.nix`。功能开关集中声明、按主机启用；共享逻辑放入模块，设备差异保留在 `hosts/<主机>/`。日常应用一律声明在配置中（`modules/home/apps.nix` 或相应模块），`nix profile` 和 `nix shell` 只用于试用。新增脚本使用 `/usr/bin/env` shebang；Python 使用四空格缩进，并遵循相邻文件风格。

临时诊断、验证实验、一次性迁移或清理脚本，以及仅用于这些操作的测试、导出入口和中间产物，一律在 `/tmp` 下创建和运行，不得保留在代码库中，也不要为单台机器的遗留状态添加共享激活钩子或兼容逻辑。代码库只保留长期需要的配置、功能实现及其回归测试；临时操作完成后清理对应的 `/tmp` 文件。

## 测试指南

修改配置后优先使用针对改动的轻量检查和局部求值；修改共享模块时检查各相关主机的受影响选项。未经用户明确要求，不构建受影响主机。`nix flake check --no-build` 仍会求值多个完整配置，不能视为轻量检查；避免并行运行完整配置求值或构建，以免耗尽内存。Python 回归测试主要使用 `unittest`，文件命名为 `test-*.py`，方法使用 `test_*`。直接运行脚本，避免默认 discovery 漏掉含连字符的文件名：

```bash
python3 modules/home/desktop/fcitx5/tests/test-xhup-lookup.py
```

该测试需要 Python 与 PyYAML；其他依赖和真实 Fcitx/Rime 集成测试步骤见输入法文档。仓库未设定覆盖率门槛。桌面、硬件与服务变更还需在目标机器验证。

## 提交与 Pull Request 指南

优先使用 `jj status`、`jj diff`、`jj log` 和 `jj describe`，避免使用会改变仓库状态的 Git 命令。历史通常采用 `feat(scope): 描述`、`refactor(scope): 描述` 等格式；提交聚焦单项变更。

每次提交前，必须先运行 `jj status` 并检查 `jj diff` 的实际改动内容，不能仅凭文件名或先前上下文直接提交。若当前改动包含不同功能或独立目的，必须先按逻辑拆分（使用 `jj split` 或按文件、改动块选择提交），再分别提交，禁止一次性打包提交。例如，新增服务与独立的依赖更新应分成两条提交；同一功能所需的配置、文档和测试可放在同一条提交中。拆分后逐条核对差异与提交说明，确保每条提交只包含对应的改动。

PR 说明变更目的、受影响主机或功能、验证命令与结果；有关联 issue 时链接，界面变更附截图。依赖更新说明原因，行为迁移同步更新文档。

## 配置安全与代理约定

代理回复使用中文。不得提交明文凭据、私钥或解密内容；加密凭据按现有 ragenix 规则维护。不要手工编辑自动生成的硬件配置；`base` 安装前须替换为目标机器生成的文件。只有用户明确要求构建或部署时才执行相应操作，且先构建再激活；图形登录变更按文档使用 `nixos-rebuild boot` 后重启，不自动清理旧系统代际。
