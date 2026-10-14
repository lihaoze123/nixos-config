# 安装入口、功能开关与应用

配置分为四层：`modules/options.nix` 集中声明开关，`modules/nixos` 与 `modules/home` 实现开关，`profiles/` 把常用开关组合成角色，`hosts/<主机>/` 选择 profile 并覆盖开关、放置硬件与单主机配置。`base` 是功能全关的最小配置，供新机器首次安装使用；class 的安装步骤见 [class 双系统安装指南](class-installation.md)。

## 安装入口

| Flake 入口 | Profile | 主机额外开启 |
| --- | --- | --- |
| `laptop`（别名 `nixos`） | `personal` | Plymouth、Codex computer use、手机集成、投屏、Windows 字体、CachyOS 内核、honk、Podman、libvirt、Waydroid、Steam；指纹在 `hosts/laptop/hardware.nix` |
| `home` | `personal` | dae；NVIDIA、打印、Syncthing 在 `hosts/home/` |
| `class` | `workstation` | Plymouth、Codex computer use、Windows 字体、CachyOS 内核、dae、Podman、libvirt；Btrfs + 独立 ESP，保留 Windows |
| `base` | 无 | 最小系统：启动、网络、用户、SSH、防火墙、Shell、Git/Jujutsu、Neovim、direnv，无图形会话 |

三台主机使用同一套桌面：Niri + DankMaterialShell，登录界面为 Dank Greeter（greetd）。各主机只在 niri 布局（`modules/home/desktop/niri/config.kdl`、`hosts/<主机>/config-<主机>.kdl`）和 greeter 输出（`my.desktop.greeter.extraConfig`）上不同。改变登录管理器配置时，用 `sudo nixos-rebuild boot` 后重启。

laptop、home、class、base 共用 `modules/nixos/nix-cache.nix` 的缓存信任配置，项目缓存按命令启用，
使用 `secrets/r2-cache-credentials.age` 和同一份缓存签名公钥；installer 保持独立。
凭据由 agenix 解密为 root 可读文件，nix-daemon 在配置激活后使用它，上传仍手动执行。
新机器须先将解密公钥加入 `secrets/keys.nix` 与凭据收件人规则，重新加密，并配置
`age.identityPaths` 指向对应私钥；`modules/nixos/core.nix` 中默认的 id_rsa 路径（`mkDefault`）可在主机中直接覆盖。
首次构建使用的是机器当前的缓存配置；需要下载 Windows 字体的设备可先关闭
`fonts.windows`，部署缓存配置后再开启字体并构建。
日常上传其他输出、校验、密钥轮换与清理见 [私有 R2 缓存维护](nix-cache.md)。

`base` 有自己的 `hosts/base/`。新机器上安装前，先用目标机器的硬件配置替换占位文件：

```bash
nixos-generate-config --show-hardware-config > hosts/base/hardware-configuration.nix
jj status   # 让 flake 读取到新文件
nixos-rebuild build --flake .#base
```

占位的 `hardware-configuration.nix` 只用于让仓库能求值（按 NixOS 手册的 `nixos` / `boot` 分区标签），不能直接用于实际机器。需要桌面时在 `hosts/base/default.nix` 中导入 `../../profiles/workstation.nix`；以后为这台机器单独建主机目录时，复制 `hosts/base` 作为起点，并在 `flake.nix` 中加一行 `mkHost "<主机名>"`。

## 开关与 profile

所有 `my.*` 开关默认关闭，完整列表与说明见 `modules/options.nix`。profile 以 `lib.mkDefault` 设置开关，主机中直接赋值即可覆盖，例如在 personal 主机上关闭语音：

```nix
{
  imports = [ ../../profiles/personal.nix ];
  my = {
    input.speech.enable = false;
    network.proxy.backend = "dae"; # 或 "honk"，null 为不启用
  };
}
```

| 开关 | 管理的内容 | workstation | personal |
| --- | --- | --- | --- |
| `cli.extra` | lazygit、zellij、tealdeer、fastfetch、btop、ouch、iperf、jjui、nh、try | ✓ | ✓ |
| `ai` | Claude Code、Codex、OpenCode 与加密凭据/包装命令 | ✓ | ✓ |
| `desktop` | Niri + DMS、Dank Greeter、中文输入法、PipeWire、基础字体、Kitty、文件管理 | ✓ | ✓ |
| `desktop.utilities` | ghostty、neovide、pavucontrol、GNOME 磁盘、baobab、Filelight | ✓ | ✓ |
| `apps.browsers` | Google Chrome、Microsoft Edge | ✓ | ✓ |
| `apps.chat` | 微信、QQ、Telegram | | ✓ |
| `apps.media` | mpv、VLC、OBS Studio、yt-dlp、FFmpeg | | ✓ |
| `fonts.extra` / `fonts.windows` | 额外中文与排版字体；chinese-fonts-overlay 的 Windows 字体 | extra | extra |
| `hardware.bluetooth` | 蓝牙及桌面小程序 | ✓ | ✓ |
| `network.edunet` / `network.tailscale` | 校园网认证；Tailscale | edunet | 两者 |
| `network.proxy.backend` | `"dae"`、`"honk"` 或 `null`，见 [代理说明](proxy.md) | | |
| `programs.nixLd` / `appimage` / `wireshark` / `steam` | 外部程序加载器；AppImage；抓包；Steam | nixLd | 前三项 |
| `input.speech` / `input.speech.doubao` | VoCoType；豆包凭据与 worker | | ✓ |
| `desktop.easyeffects` | 麦克风降噪 | | ✓ |
| `services.aria2` | aria2 RPC、AriaNg 和本地 Caddy | | ✓ |
| `virtualisation.docker` / `podman` / `libvirt` / `waydroid` | rootless Docker；Podman + Distrobox；QEMU/libvirt；Waydroid | | docker |
| `desktop.graphicalBoot` / `codexComputerUse` / `phone` / `screenCast` / `wallpaperEngine` | Plymouth；Codex Desktop computer use；Valent；Wi-Fi 投屏；动态壁纸 | | |
| `kernel.cachyos` | CachyOS BORE 内核及二进制缓存 | | |

依赖不满足时求值会给出断言错误（例如 `apps.*`、`desktop.*`、`input.speech` 需要 `desktop`，`input.speech.doubao` 需要 `input.speech`，`fonts.windows` 需要 `fonts.extra`）。开关只控制安装与服务，关闭不会删除原有用户数据。只在一台主机上存在的配置（指纹、打印、Syncthing、NVIDIA）直接写在该主机目录，不设共享开关。

启用 `podman` 时，未指定仓库域名的镜像名按 `docker.io`、`quay.io`、`ghcr.io` 的顺序搜索，配置由 NixOS 写入 `/etc/containers/registries.conf`。例如 `podman pull alpine` 使用此搜索列表；`podman pull docker.io/library/alpine` 则直接使用指定仓库。Podman 可能提示选择仓库并记住选择；用户自己的 `~/.config/containers/registries.conf` 会覆盖系统配置。

没有启用 `kernel.cachyos` 时使用 NixOS 默认内核。启用后先运行 `nixos-rebuild build --flake .#class` 验证构建，再运行 `sudo nixos-rebuild boot --flake .#class` 并重启（其他主机替换 `class`）；新内核在重启后生效。第三方指纹驱动只在 laptop 的 `hosts/laptop/hardware.nix` 中启用，其他主机不引入其内核开发闭包。

首次启用时，当前系统尚未信任 CachyOS 缓存，可先使用以下命令构建，避免本地编译内核；写入启动配置后，缓存设置会在新系统启动时生效：

```bash
sudo nix build .#nixosConfigurations.class.config.system.build.toplevel --no-link \
  --extra-substituters https://attic.xuyh0120.win/lantian \
  --extra-trusted-public-keys 'lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc='
```

## 应用：声明式安装，profile 只用于试用

长期使用的图形应用写在 `modules/home/apps.nix` 的分组中，命令行工具写在 `modules/home/shell/cli.nix`，随系统构建与回滚。新增分组时在 `modules/options.nix` 的 `my.apps` 下声明开关，再在合适的 profile 或主机中开启。

试用软件不改配置：

```bash
nix shell nixpkgs#obsidian                    # 只在当前 shell 中可用
nix profile install nixpkgs#obsidian          # 临时保留，可随时移除
nix profile install github:lihaoze123/nur-packages#vscode
nix profile list
nix profile remove obsidian
```

确定长期使用后，把软件写进配置，切换到新系统，再从 profile 中移除，避免同一程序有两份。本仓库不再导出 `packages` / `legacyPackages` 供 profile 安装；自定义包直接从 nur-packages 安装。

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

Java 8 + 内嵌 Tomcat 9 + javax Servlet/JSP 的最小项目使用独立模板，打包产物为包含全部运行依赖和 JSP 的单个 JAR：

```bash
mkdir my-webapp
cd my-webapp
nix flake init -t /home/chumeng/nixos-config#java-webapp
nix develop
mvn clean package
java -jar target/my-jsp-project.jar
```

访问 `http://localhost:8080/` 和 `/hello`。初始化后的默认 devShell 为 Temurin JDK 8，Maven 和 `JAVA_HOME` 均使用同一个 JDK。只需复制打包后的 JAR，即可在其他装有 Java 8 或以上版本的机器上运行。

direnv 示例：项目 `.envrc` 写 `use flake .#rust`，再执行 `direnv allow`。从该环境启动 `nvim`，项目 LSP 与编译器会出现在 PATH 中。工具链只在使用该项目时实现，不参与首次系统构建。
