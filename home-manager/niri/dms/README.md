# DMS on Niri

目前仅在 `hosts/laptop/laptop.nix` 启用：

```nix
programs.dank-material-shell.enable = true;
```

Home Manager 通过官方 DMS v1.6.2 模块管理 `dms.service`，运行包使用
仓库锁定的 `pkgs.dms-shell` 和 `pkgs.quickshell`。DMS 随 Niri 图形会话启动，
接管状态栏、通知和壁纸；启用时不再安装或启动 Waybar、Mako、swaybg。
`hosts/laptop/default.nix` 提供 UPower、电源模式、AccountsService 和锁屏 PAM。

## 配置归属

| 配置 | 管理方式 |
| --- | --- |
| `~/.config/niri/config.kdl` | Home Manager 部署本目录的 `niri.kdl`，负责加载下列文件 |
| `~/.config/niri/base.kdl` | 链接到仓库的 `home-manager/niri/config.kdl`，保留原有窗口管理配置 |
| `~/.config/niri/dms-bindings.kdl` | Home Manager 部署本目录的 `binds.kdl` |
| `~/.config/niri/dms/*.kdl` | DMS 界面生成，放在基础配置之后加载，让界面调整生效 |
| `~/.config/DankMaterialShell/settings.json` | DMS 界面设置，可写且重建时保留 |
| `~/.local/state/DankMaterialShell/session.json` | 壁纸、明暗模式等本机状态，可写且重建时保留 |

`default.nix` 中的 `initialSettings`、`initialSession` 只在文件不存在时初始化。
已有设置不会被覆盖。首次安装默认使用紫色主题、24 小时制和仓库壁纸；
外部主题模板默认关闭，可以之后在 DMS 中启用。

启用 DMS 时，Home Manager 安装并配置 `Papirus-Dark` 图标主题，供 Qt
查找输入法、蓝牙等托盘图标。DMS 的图标主题保持「System Default」即可。
修改后重建并重启 `dms.service`，让 Qt 重新加载图标主题。

配套安装 `adw-gtk3`、`qt5ct`、`qt6ct` 和 `khal`。Qt 平台主题在用户会话、
systemd 用户服务和 Niri 中分别配置，Qt5 使用 `qt5ct`，Qt6 使用 `qt6ct`。
Qt 工具的配置保持可写，供 DMS 管理。需要应用动态配色时，在 DMS 的
Theme & Colors 设置中启用主题模板及 Apply GTK/Qt Themes；已保存的设置
不会在重建时被覆盖。若托盘图标没有继承系统主题，可在 Qt 工具中选择
`Papirus-Dark`。

日历事件支持已启用；显示个人日程前，需要配置 `khal` 的日历来源。
`hosts/laptop/default.nix` 通过 nixpkgs 原生模块安装 DankSearch，并让
`dsearch.service` 随图形会话启动。可用 `systemctl --user status dsearch`
检查服务，在 DMS 启动器中使用文件搜索。

**界面调整会保存在本机，但不会自动进入 Git。** 想让某项偏好在新机器上也
复现，可将对应值加入上述初始配置；修改初始值不会覆盖本机已有文件。
Niri 的固定默认值可写入仓库的 KDL，DMS 生成的片段拥有更后的覆盖顺序。
不要把 GUI 管理的 JSON 或 KDL 链接到只读 Nix store，否则界面无法正常保存。

## HHKB 快捷键

现有 Niri 的 `Mod` 是 `Alt`，不需要 Win 键。

| 按键 | 功能 |
| --- | --- |
| `Print` | Quick Capture 框选截图并编辑 |
| `Ctrl+Print` | Quick Capture 当前屏幕截图并编辑 |
| `Alt+Print` | Quick Capture 当前窗口截图并编辑 |
| `Ctrl+Alt+Space` 或 `Alt+P` | 应用启动器 |
| `Ctrl+Alt+N` | 通知中心 |
| `Ctrl+Alt+M` | 进程监视器 |
| `Ctrl+Alt+,` | DMS 设置 |
| `Alt+V` | 剪贴板历史 |
| `Alt+X` | 小鹤字根表（覆盖层，Esc 关闭） |
| `Alt+Shift+X` | 小鹤反查：打开启动器并填入 `;` |
| `Alt+Ctrl+X` | 小鹤加词：打开启动器并填入 `;+` |

剪贴板历史由 DMS 自带的服务记录，启用 DMS 时不再运行 cliphist；
其他主机通过 Home Manager 的 `services.cliphist` 记录。
截图快捷键通过 IPC 调用已安装并启用的 `quickCapture` 插件，与状态栏部件
使用同一套截图和编辑功能，覆盖基础配置中的 Niri 原生截图快捷键。
小鹤功能由独立仓库 [dms-xhup](https://github.com/lihaoze123/dms-xhup) 的 DMS 插件提供，在 fcitx5 模块中部署，
用法见 [反查](../../fcitx5/docs/xhup-lookup.md) 与 [加词](../../fcitx5/docs/add-user-word.md)。

## 应用配置

在仓库根目录执行：

```bash
nixos-rebuild build --flake .#laptop
sudo nixos-rebuild switch --flake .#laptop
```

从临时试用首次切换后，保存工作并注销、重新登录，以结束临时服务并由
`dms.service` 接管。之后配置不再依赖试用脚本或 `~/.cache/dms-trial-*`。

可用 `systemctl --user status dms.service` 检查启动结果，
用 `journalctl --user -u dms.service -b` 查看日志。
其他主机仍使用原有 Waybar 配置；要让 laptop 恢复 Waybar，移除它的 DMS
启用选项，重新构建、切换并登录。
