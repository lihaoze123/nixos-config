# 安装入口、功能开关与用户应用

> 当前 class 已基于 base 重建，启用桌面、常用工具、蓝牙、DAE、校园网认证、AI CLI 和 Codex Desktop / computer use，旧硬件与专属桌面配置已移除。
> 安装步骤见 [class 双系统安装指南](class-installation.md)。下文有关旧 class 桌面、已启用功能及迁移验证的记录仅描述此前的配置。

各主机通过 `hosts/<主机>/features.nix` 选择功能，保持重构前的功能；普通应用和语言工具链移出了系统：应用由用户 profile 管理，工具链属于各项目的 devShell。home、class 的桌面已统一为 laptop 使用的 DMS。`base` 是独立的最小配置，供新机器首次安装使用。

## 安装入口

| Flake 入口 | 内容 |
| --- | --- |
| `laptop`（别名 `nixos`） | 笔记本日常配置：桌面、Plymouth、语音、容器、虚拟化、指纹等原有功能 |
| `home` | 桌面、NVIDIA、打印、Syncthing、Docker 等原有功能 |
| `class` | 基于 base，Btrfs + 独立 ESP，保留 Windows；桌面、常用工具、蓝牙、DAE、校园网认证、AI CLI、Codex Desktop / computer use |
| `base` | 最小系统：启动、网络、用户、SSH、防火墙、Shell、Git/Jujutsu、Neovim、direnv，无图形会话 |

三台主机使用同一套桌面：Niri + DankMaterialShell，登录界面为 Dank Greeter（greetd）。各主机只在 niri 布局（`home-manager/niri/config.kdl`、`hosts/<主机>/config-<主机>.kdl`）和 greeter 的输出设置（`my.niri.greeterExtraConfig`）上不同。从 SDDM 切换过来时，用 `sudo nixos-rebuild boot` 后重启。

`base` 不属于任何现有主机，有自己的 `hosts/base/`。新机器上安装前，先用目标机器的硬件配置替换占位文件：

```bash
nixos-generate-config --show-hardware-config > hosts/base/hardware-configuration.nix
jj status   # 让 flake 读取到新文件
nixos-rebuild build --flake .#base
```

占位的 `hardware-configuration.nix` 只用于让仓库能求值（按 NixOS 手册的 `nixos` / `boot` 分区标签），不能直接用于实际机器。需要更多功能时编辑 `hosts/base/features.nix`；以后为这台机器单独建主机目录时，可以把 `hosts/base` 复制一份作为起点。

```bash
# 在仓库根目录：只构建，不激活
nixos-rebuild build --flake .#laptop
nixos-rebuild build --flake .#home

# 改变桌面/登录管理器配置时，用 boot 后重启
sudo nixos-rebuild boot --flake .#laptop
```

## 功能开关

所有 `my.features.<名称>.enable` 在模块中默认都是 `false`。laptop、home、class 的 `features.nix` 显式打开了各自重构前就有的功能，文件末尾以注释列出该主机重构前没有、但可以开启的功能。`hosts/base/features.nix` 全部注释，只列出共享模块实现的功能。

```nix
{
  my.features = {
    desktop.enable = true;
    bluetooth.enable = true;
    docker.enable = true;
    speech.enable = true;
    doubao.enable = true; # 需要 speech
  };
}
```

| 功能开关 | 管理的内容 |
| --- | --- |
| `extra` | base 之外的常用命令行工具：lazygit、zellij、tealdeer、fastfetch、try；不依赖桌面 |
| `extraDesktop` | 常用图形工具：ghostty、neovide、pavucontrol、GNOME 磁盘、baobab、Filelight、Microsoft Edge |
| `desktop` | Niri + DankMaterialShell（状态栏、通知、启动器、锁屏、剪贴板、文件搜索）、Dank Greeter、中文输入法、PipeWire、基础字体、Kitty、文件管理；laptop 另启用 Plymouth |
| `bluetooth`、`tailscale`、`dae`、`edunet` | 蓝牙、VPN、代理、校园网认证，各自独立 |
| `docker`、`podman` | Docker rootless；Podman + Distrobox，各自独立 |
| `virtualMachines`、`waydroid` | QEMU/libvirt/virt-manager；Waydroid，各自独立 |
| `speech`、`doubao`、`easyeffects` | VoCoType；豆包凭据与 worker 集成；麦克风降噪，各自独立 |
| `aiCli` | Claude Code、Codex、OpenCode 与已有加密凭据/包装命令 |
| `aria2` | aria2 RPC、AriaNg 和本地 Caddy 服务 |
| `wireshark`、`appimage`、`nixLd` | 抓包权限；AppImage；外部程序兼容加载器，各自独立 |
| `extraFonts` | 基础桌面字体之外的中文及排版字体 |
| `codexDesktop` | Codex Desktop 和 Niri computer use 集成；laptop、class 已启用 |
| `fingerprint`、`cachyosKernel`、`steam` | laptop：指纹驱动；CachyOS 内核；Steam，各自独立 |
| `phoneIntegration`、`screenCast` | laptop：Valent/KDE Connect；Wi-Fi 投屏及配套端口，各自独立 |
| `printing`、`syncthing` | home：打印及驱动；已有 Syncthing 同步配置，各自独立 |

extraDesktop、语音识别、EasyEffects、Codex 桌面、手机集成和投屏要求 desktop；doubao 要求 speech。不满足依赖时求值会给出错误。开关只控制安装与服务，关闭不会删除原有用户数据。

没有启用 cachyosKernel 时使用 NixOS 默认内核。没有启用 fingerprint 时不安装第三方指纹驱动，也不引入其内核开发闭包。

## 用户 profile：逐个安装应用

> **切换到新配置前，先在每台机器上装好需要的应用。** 功能开关保持了原有行为，但下面这些软件已经不随系统安装，laptop、home、class 切换后都会消失：
>
> - 应用：VS Code（含原来的六个扩展）、Microsoft Edge、QQ、微信、Anki、Obsidian
> - 排版：typst、pandoc、tectonic
> - 工具链：GCC、Clang、Rust（含 `~/.rust-rover/toolchain` 链接与 `RUST_SRC_PATH`）、JDK、Node.js、Bun、Python、uv，改由项目 devShell 提供
>
> lazygit、zellij、tealdeer、fastfetch、try 由 `extra` 开关安装；ghostty、neovide、pavucontrol、GNOME 磁盘、baobab、Filelight 由 `extraDesktop` 开关安装。laptop、home、class 都已开启，切换后不会消失；base 默认不装。
>
> 依赖这些软件的配置也要留意：
>
> - 默认终端由 ghostty 改为 kitty（niri `Mod+Return`、DMS `terminalOverride`）。
> - niri 的 `Mod+C` 仍绑定 `microsoft-edge`，未安装 `.#microsoft-edge` 时该快捷键无效。
> - Fish 中的 `lg`（lazygit）和 `try` 集成只在安装对应程序后生效（开启 `extra`，或用 profile 安装）。
> - Neovim 自身需要的 tree-sitter、gcc、Node.js 和 clangd 仍随 Home Manager 安装，只在 nvim 内可见。

包定义位于 `profiles/packages.nix`，沿用仓库的 nixpkgs 锁定版本；除 `extra` 复用的 `try` 外，不被 NixOS 系统引用。以普通用户在仓库根目录执行，选择需要的包，不必全部安装：

```bash
nix profile install .#wechat
nix profile install .#anki .#obsidian
nix profile install .#vscode
nix profile install .#microsoft-edge
nix profile install .#typst .#pandoc
```

VS Code 保留原来的六个扩展。其他可安装输出包括 `qq`、`tectonic`；没有开启 `extra`、`extraDesktop` 的机器（如 base）也可以单独安装 `fastfetch`、`lazygit`、`zellij`、`tealdeer`、`try`，以及 `ghostty`、`neovide`、`pavucontrol`、`gnome-disk-utility`、`baobab`、`filelight`。`try` 保留此前针对 NixOS shebang 的修补，`extra` 使用同一个包；安装后 Fish 会自动加载其 shell 集成（目录为 `~/src/tries`）。

你已有 profile 中的 QQ Wayland 修复版，可以继续使用，无需再装 `.#qq`。重建系统不会自动补装或更新 profile 中的应用。

```bash
nix profile list
nix profile upgrade wechat
nix profile remove wechat
```

名字以 `nix profile list` 的实际输出为准。更新应用前先按需要更新仓库锁文件。安装后应用的启动器条目由用户 profile 提供；已运行的桌面若未刷新条目，可以重新登录。

profile 的收益是延后安装和独立更新；以后全部装回仍会占空间。旧系统/profile 代际也可能继续保留旧包，当前改动不会自动删除代际或执行 GC。

## 开发环境：各项目自己的 flake

系统不再全局安装 GCC、Clang、Rust、JDK、Node、Bun、Python 开发环境和 IDE。Neovim 只为自身附带 tree-sitter、gcc、Node.js 和 clangd，不启用 Node/Python/Ruby provider；项目需要的其他 LSP、编译器放入项目 devShell。

仓库提供项目模板，包含 Rust、C++、Node、Python、Java 五种独立 shell。进入新建或没有 flake 的项目目录：

```bash
nix flake init -t /home/chumeng/nixos-config#project
# 在项目里生成并保留自己的 flake.lock
nix develop .#rust
# 或 .#cpp / .#node / .#python / .#java
```

在已有 flake 的项目中，手动合并需要的 devShell，不覆盖已有文件。删掉不需要的 shell，并按项目要求选择版本与依赖。项目使用 jj 时，新文件写入后执行 `jj status` 让 flake 能读取它们。

direnv 示例：项目 `.envrc` 写 `use flake .#rust`，再执行 `direnv allow`。从该环境启动 `nvim`，项目 LSP 与编译器会出现在 PATH 中。工具链只在使用该项目时实现，不参与首次系统构建。

## 本次验证

功能拆分时，与重构前（`1a85601`）逐项对比 laptop、home、class 的求值结果：系统包、启用的 systemd 服务、用户组、字体、Home Manager 的 xdg 配置文件和用户服务完全一致，差异只有上面列出的移到 profile/devShell 的软件（以及相应的 VS Code 扩展、`~/.rust-rover` 链接），另外新增了 `fd`。

统一桌面后：laptop 只少了不再使用的 swaylock/swayidle；home、class 的 SDDM、Waybar、Mako、wofi、swaybg、cliphist 换成了 DMS、Dank Greeter 及其系统后端（UPower、电源模式、AccountsService、dsearch），Tailscale 增加 `--operator=chumeng` 供 Dankscale 使用。

基于当前 `flake.lock` 的构建闭包大小（NAR 大小，非下载量），为重构过程中的测量：

| 配置 | 大小 | store 路径数 |
| --- | --- | --- |
| 改动前 laptop | 30.74 GiB | 3457 |
| 改动后 laptop | 21.65 GiB | 3153 |
| 最小系统（无桌面） | 3.49 GiB | 1045 |

所有入口求值通过，`nix flake check --no-build` 通过；未激活任何系统。实际桌面登录、设备与服务仍需在启动新代际后验证。
