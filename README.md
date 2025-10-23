# NixOS 配置仓库

这是一个使用 flakes 和 home-manager 的 NixOS 系统配置仓库。配置了完整的 NixOS 系统，包括 Niri Wayland 窗口管理器环境以及用户特定的家目录配置。

## 🖥️ 系统概览

### 主要特性
- **窗口管理器**: Niri 窗口管理器
- **显示管理器**: SDDM 配合 SilentSDDM 主题
- **音频系统**: PipeWire
- **输入法**: Fcitx5 + Rime 小鹤音形
- **代理服务**: DAE 高级代理系统，智能路由和自动化订阅管理
- **设备配置**: 支持多设备的差异化配置
- **用户环境**: 统一的 Shell 环境（Fish + Starship）和开发工具

### 多设备支持
- **笔记本电脑**: 高分辨率显示（3120x2080@120），2.0 倍缩放
- **实验室设备**: 标准显示（1980x1080@60），1.2 倍缩放
- **默认配置**: 笔记本电脑配置（通过 `nixos` 别名访问）

## 🚀 快速开始

### 系统管理命令

```bash
# 构建并切换到新的系统配置
sudo nixos-rebuild switch --flake .

# 更新 flake 输入
nix flake update

# 查看 flake 输出
nix flake show

# 格式化代码库
nix fmt
```

### 设备特定配置

```bash
# 构建笔记本电脑配置
sudo nixos-rebuild switch --flake .#laptop

# 构建实验室配置
sudo nixos-rebuild switch --flake .#class

# 默认配置（别名到笔记本）
sudo nixos-rebuild switch --flake .#nixos
```

### 秘密管理（ragenix）

```bash
# 编辑秘密文件
ragenix -e secret-name.age

# 为新 SSH 密钥重新密钥所有秘密
ragenix -r

# 列出所有秘密
ragenix -l
```

## 📁 目录结构

```
nixos-config/
├── flake.nix                    # 主 flake 定义
├── flake.lock                   # flake 锁定文件
├── hosts/                       # 设备配置（新架构）
│   ├── laptop/                  # 笔记本电脑配置
│   │   ├── default.nix          # 主机配置入口
│   │   ├── hardware-configuration.nix  # 硬件配置
│   │   └── laptop.nix           # 设备特定配置
│   ├── class/                   # 实验室设备配置
│   │   ├── default.nix          # 主机配置入口
│   │   ├── hardware-configuration.nix  # 硬件配置
│   │   ├── class.nix            # 设备特定配置
│   │   └── config-class.kdl     # Niri 窗口管理器配置
│   └── base.nix                 # 基础系统配置
├── home-manager/                # 用户家目录配置
│   ├── home.nix                 # 基础用户配置（包、Git、Age、模块化Shell导入）
│   ├── shell/                   # Shell 环境配置
│   │   ├── default.nix          # Shell 模块入口
│   │   ├── fish/                # Fish Shell + Starship 配置
│   │   ├── kitty/               # Kitty 终端模拟器
│   │   ├── neovim/              # Neovim/LazyVim 配置
│   │   ├── claude-code/         # Claude Code AI 助手
│   │   ├── gcc/                 # GCC14 工具链
│   │   └── common.nix           # 通用 Shell 工具
│   ├── fcitx5/                  # Fcitx5 + Rime 小鹤音形输入法
│   ├── niri/                    # Niri 窗口管理器配置
│   │   └── config.kdl           # 默认电脑配置（高分辨率）
│   ├── secrets/                 # 用户秘密文件
│   └── applications/            # 用户应用程序
├── modules/                     # 自定义 NixOS 模块
│   ├── dae/                     # DAE 代理服务模块
│   │   ├── default.nix          # DAE 服务配置
│   │   ├── subscriber.nix       # 自动订阅管理
│   │   └── config.dae           # 内联 DAE 配置
│   ├── niri/                    # Niri 窗口管理器模块
│   │   ├── default.nix          # Niri 系统集成
│   │   └── sddm.nix             # SDDM 显示管理器配置
│   └── default.nix              # 模块入口点
├── overlays/                    # Nixpkgs 覆盖层
│   ├── default.nix              # 覆盖层入口
│   └── fcitx5/                  # Fcitx5 自定义配置
└── secrets/                     # 系统级加密秘密文件
```

## ⚙️ 核心组件

### 1. 主机配置系统 (`hosts/`)
采用分层主机配置架构，支持多设备管理：
- **共享模块**: 通过模块化系统实现配置复用
- **设备特定**: 每个设备在独立目录中管理其配置
- **硬件抽象**: `hardware-configuration.nix` 自动生成并维护

#### 主机配置文件结构
- `hosts/hostname/default.nix` - 主机配置入口点，导入必要模块
- `hosts/hostname/hardware-configuration.nix` - 硬件特定配置（自动生成）
- `hosts/hostname/hostname.nix` - 设备特定的额外配置

### 2. 用户环境配置 (`home-manager/`)
模块化用户环境管理系统：
- **基础配置** (`home-manager/home.nix`): 共享用户包、Git 配置、Age 加密、模块化 Shell 导入
- **Shell 环境** (`home-manager/shell/`): Fish Shell + Starship、开发工具、终端配置
- **输入法** (`home-manager/fcitx5/`): Fcitx5 + Rime 小鹤音形输入法
- **窗口管理器** (`home-manager/niri/`): 设备特定的 Niri 配置文件
- **应用配置** (`home-manager/applications/`): 用户应用程序配置

### 3. DAE 代理服务 (`modules/dae/`)
- 高级代理系统，智能路由
- 通过 systemd 计时器自动化订阅管理
- 内联配置与加密订阅文件
- 智能路由策略：
  - 国际网站：Google DNS（8.8.8.8）
  - 国内网站：阿里 DNS（223.5.5.5）
  - AI 服务：代理直连
  - 区域特定代理规则

### 4. Shell 环境 (`home-manager/shell/`)
模块化 Shell 环境配置系统：
- **Fish Shell** (`shell/fish/`): 配合 Starship 提示符，交互式 Shell
- **Kitty** (`shell/kitty/`): 功能强大的终端模拟器
- **Neovim** (`shell/neovim/`): LazyVim 配置，LSP 和插件
- **GCC 工具链** (`shell/gcc/`): GCC14 配置，带有标准库预编译头文件
- **开发工具**: fzf、ripgrep、eza、bat、lazygit 等
- **Claude Code** (`shell/claude-code/`): AI 编程助手集成
- **通用工具** (`shell/common.nix`): 跨平台通用开发工具

#### Shell 模块结构
- `shell/default.nix` - Shell 模块入口点，导入所有子模块
- 各子模块独立配置，便于维护和选择性启用

### 5. 自定义覆盖层 (`overlays/`)
- **Fcitx5**: 带有自定义 Rime 小鹤音形数据的输入法

## 🏗️ 配置管理模式

### 主机配置模式
仓库采用分层主机配置架构：

1. **基础层**: `home-manager/home.nix` 和 `modules/` 中的共享配置
2. **主机层**: `hosts/hostname/` 中的主机特定配置
3. **硬件层**: `hosts/hostname/hardware-configuration.nix` 中的硬件特定设置
4. **服务层**: 应用于所有设备的 `modules/` 中的自定义模块
5. **用户层**: `home-manager/` 中的模块化用户环境配置

### 主机配置结构
每个主机配置遵循统一的结构模式：
- `hosts/hostname/default.nix` - 主配置文件，导入所有必要的模块
- `hosts/hostname/hardware-configuration.nix` - 硬件配置（由 `nixos-generate-config` 生成）
- `hosts/hostname/hostname.nix` - 主机特定的额外配置

这种模式允许：
- **共享配置**: 通用设置在模块和基础配置中定义一次
- **主机特化**: 每个主机在独立目录中管理其特定配置
- **可维护性**: 通过创建新主机目录轻松添加新设备
- **一致性**: 所有主机都从相同的模块系统继承
- **硬件隔离**: 硬件配置与逻辑配置分离

### 模块系统
配置使用自定义模块系统：
- `modules/default.nix`: 主模块入口点
- `modules/dae/`: DAE 代理服务配置
- `modules/niri/`: Niri 窗口管理器系统配置
- 模块在主 flake 配置中导入并应用于所有设备配置

## 🛠️ 开发环境

### 开发工具配置
- **GCC**: 自定义 GCC14 配置，带有标准库预编译头文件
- **Neovim**: 带有自定义插件的 LazyVim 配置（LSP、competitest、配色方案）
- **Fish Shell**: Starship 提示符集成
- **Kitty**: 带有 Dracula 主题和自定义配置的终端模拟器
- **Claude Code**: AI 助手集成

### 外部依赖
- **nixpkgs-unstable**: 主要包集合
- **nixpkgs-25.05**: 稳定版后备
- **home-manager-25.05**: 家目录管理器
- **daeuniverse**: 代理服务
- **ragenix**: 秘密管理
- **SilentSDDM**: Niri 的 SDDM 主题

## 🔐 秘密管理
秘密使用 age 加密并通过 ragenix 管理：
- 在 `home-manager/secrets/secrets.nix` 中为笔记本电脑和家庭 SSH 密钥定义公钥
- 系统秘密（如 DAE 配置）位于 `secrets/` 目录
- 用户秘密（API 令牌）位于 `home-manager/secrets/` 目录
- Age 身份路径：`/home/chumeng/.ssh/id_rsa`

## 📝 开发注意事项

- 系统使用实验性 Nix 功能（flakes、nix-command）
- 允许非自由包（`nixpkgs.config.allowUnfree = true`）
- 配置了清华大学镜像器作为中国的加速替代源
- NixOS 和 home-manager 的状态版本都设置为 25.05
- 格式化工具：nixpkgs-fmt（使用 `nix fmt`）
- 禁用家目录管理器版本检查以增加灵活性
- 桌面环境：Niri 窗口管理器

## 📋 配置管理最佳实践

### 添加新设备
1. **创建主机目录**: `mkdir hosts/new-host`
2. **复制并适配配置**: 从现有主机复制 `default.nix` 并根据需要调整
3. **生成硬件配置**: `sudo nixos-generate-config` 并将 `hardware-configuration.nix` 复制到新主机目录
4. **更新 flake.nix**: 在 `nixosConfigurations` 中添加新主机配置
5. **创建家目录配置**: 根据需要创建对应的 home-manager 配置

### 修改配置
- **系统级更改**: 编辑 `modules/` 中的相应模块
- **用户环境更改**: 编辑 `home-manager/home.nix`（影响所有设备）或 `home-manager/shell/` 中的模块
- **主机特定更改**: 编辑 `hosts/hostname/` 中的配置文件
- **服务更改**: 编辑 `modules/` 中的适当模块
- **硬件更改**: 编辑 `hosts/hostname/hardware-configuration.nix`（通常自动生成）

### 测试更改
```bash
# 测试特定设备配置
sudo nixos-rebuild build --flake .#laptop
sudo nixos-rebuild build --flake .#class

# 验证 flake 输出
nix flake show
```

## 🎨 Niri 窗口管理器配置

系统使用 Niri 作为主要窗口管理器，具有设备特定配置：

### 系统集成 (`modules/niri/`)
- **系统服务**: Polkit、GNOME Keyring、swaylock/swayidle
- **显示管理器**: 带 SilentSDDM 主题和 Wayland 支持的 SDDM
- **用户服务**: waybar（状态栏）、mako（通知）、wofi（应用启动器）
- **背景管理**: swaybg 壁纸管理
- **X11 支持**: xwayland-satellite 用于 X11 应用程序兼容性
- **用户头像**: SDDM 自动头像复制服务

### 设备特定配置
- **笔记本电脑**: 使用 `home-manager/niri/config.kdl`，支持高分辨率显示（3120x2080@120，2.0 缩放）
- **实验室设备**: 使用 `hosts/class/config-class.kdl`，标准显示设置（1980x1080@60，1.2 缩放）
