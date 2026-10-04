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

## laptop 的 GXFP5130 指纹测试

`hosts/laptop/default.nix` 启用社区 `gxfp` 内核模块及配套 libfprint/fprintd，
仅作用于 laptop。源码和子模块由 `flake.lock` 锁定。sudo 和 SDDM 使用指纹
认证并保留密码；当前 nixpkgs 的 SDDM 复用 `login` PAM 子栈。

切换配置后重启，以确保加载与新内核对应的模块，再检查：

```bash
ls -l /dev/gxfp
fprintd-list chumeng
journalctl -b -u fprintd --no-pager
```

该传感器通过 TLS-PSK 通信，录入前还需要与传感器匹配的 32 字节密钥。
双系统建议按 [上游 PSK 文档](https://github.com/Void755/gxfpmoc/blob/main/PSK.md)
在 Windows 中使用 `tools/unseal_bb010002.py` 提取现有密钥。将得到的
`psk_raw32.bin` 安装到本机状态目录（替换下面的输入文件路径）：

```bash
sudo install -m 600 -o root -g root /path/to/psk_raw32.bin /var/lib/fprintd/gxfp/psk_raw32.bin
sudo systemctl restart fprintd
fprintd-enroll
fprintd-verify
sudo -k
sudo -v
```

密钥不进入仓库或 Nix store；配置只创建权限为 `0700` 的状态目录，
不生成密钥、不改写传感器。Windows 的驱动若重新配置了 PSK，可能需要
重新提取。`gxfp_psk_tool`、`gxfp_capture`、`gxfp_recovery` 已安装供诊断，
不要在共享 Windows 的设备上直接执行上游 Linux-only 的密钥上传步骤。

上游将 MateBook X Pro 2024 标为部分支持。构建通过仅说明软件可编译，
读图、录入、匹配以及 SDDM 登录仍需实机验证。

参考：[官方 NixOS / Home Manager 模块文档](https://danklinux.com/docs/dankmaterialshell/nixos-flake)。
