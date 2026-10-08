# Laptop 桌面：启动、登录与锁屏

仅适用于 `laptop` / `nixos` 主机。home、class 仍使用共享模块默认的 SDDM（`my.niri.greeter = "sddm"`）。

| 环节 | 实现 | 配置位置 |
| --- | --- | --- |
| GRUB | 隐藏菜单，1 秒窗口 | `hosts/laptop/boot.nix` |
| 启动/关机画面 | Plymouth `dms-nixos` 主题（spinner 改色，居中 NixOS 标志） | `hosts/laptop/boot.nix` |
| 登录 | Dank Greeter（greetd + niri） | `hosts/laptop/default.nix` |
| 锁屏与空闲 | DMS 自带锁屏与 IdleService | `home-manager/niri/dms/binds.kdl`，空闲策略在 DMS 设置界面 |

`i915` 放在 initrd 中，Plymouth 一开始就画在最终的显卡设备上。否则它会先画在固件帧缓冲（simpledrm）上，第二阶段 i915 接管时会短暂露出厂商 logo。固件自己显示的厂商 logo（Plymouth 启动前约 2 秒）不受系统控制。

Plymouth 到 greeter 的交接（`hosts/laptop/default.nix`）：NixOS 默认先退出 Plymouth 再启动 greetd，中间几秒 i915 会把从固件继承的帧缓冲（厂商 logo）重新显示出来。现在的顺序是：greetd 立即启动（`Type=simple`），`plymouth deactivate` 只交出显示控制权，画面保留；`plymouth-quit` 等 greeter 的 niri 创建 Wayland socket 后（最多等 15 秒）再执行 `quit --retain-splash`。如果 greeter 启动失败，Plymouth 也会在 15 秒后退出。

Plymouth 运行在 `DeviceScale=1`，主题素材直接按屏幕 2 倍分辨率生成（logo 192px，转圈 48px），避免 Plymouth 放大位图导致模糊。如果更换了缩放比例不同的屏幕，要修改 `boot.nix` 里的 `scale`。

启动画面颜色固定取自 DMS purple 主题深色方案（背景 `#141218`，主色 `#d0bcff`），不跟随壁纸动态配色。

## 应用配置

切换显示管理器时，`switch` 会停止正在运行的图形会话，所以这次改动要用 `boot` 并重启：

```bash
nixos-rebuild build --flake .#laptop
sudo nixos-rebuild boot --flake .#laptop
reboot
```

之后只改 Plymouth、GRUB、快捷键等内容时，可以照常使用 `switch`。

## GRUB 与回滚

- 开机后 GRUB 等待 1 秒且不显示菜单。在这 1 秒内按 **Esc**（或按住 **Shift**）即可显示菜单。
- 菜单中 “NixOS - All configurations” 可选旧代际；os-prober 检测到的其他系统入口保持不变。
- 进入系统后回滚：`sudo nixos-rebuild switch --rollback`；或在 GRUB 里选旧代际启动后再执行 `sudo /run/current-system/bin/switch-to-configuration boot`，将其设为默认。

## 启动诊断

- Plymouth 画面中按 **Esc** 可切换到文字启动日志。
- 隐藏画面上的日志不影响日志记录：`journalctl -b`、`journalctl -b -1`（上一次启动）、`systemd-analyze blame`。
- 文字控制台：**Ctrl+Alt+F2** 等切换到 TTY；greetd 在 tty1 上。
- 排查 greeter 问题时，可临时设置 `services.displayManager.dms-greeter.logs.save = true`，日志写入 `/tmp/dms-greeter.log`。

## 登录（Dank Greeter）

- 启动 greetd 前，会从 `/home/chumeng` 复制 DMS 的 `settings.json`、`session.json` 与配色，因此主题和壁纸与桌面一致。
- greeter 自己的 niri 配置写在 `compositor.customConfig` 中（eDP-1、2 倍缩放、触摸板轻触）。修改缩放时要同时改这里。
- 登录只用密码：greetd 通过 `login` PAM substack 认证，`login.fprintAuth = false`。greetd 只有一个 PAM 会话，`pam_fprintd` 排在密码前面时，回车后要等指纹超时才验证密码，所以登录不启用指纹。用密码登录也能自动解锁 GNOME Keyring。
- 启用 `my.features.fingerprint.enable` 后，指纹用于锁屏（DMS 自带的 `fprint` 会话，和密码并行）、sudo 和 polkit。TTY 登录同样只用密码。

## 锁屏

- 手动锁屏：**Super+L**（HHKB 的 ◇ 键），对应 `dms ipc call lock lock`。没有用 Ctrl+Alt+L，因为它会抢走 JetBrains 的 Reformat Code。
- 锁屏同时运行两个 PAM 会话：`dankshell` 只验证密码，DMS 自带的 `fprint` 会话负责指纹（DMS 设置中的指纹开关 `enableFprint`）。`dankshell` 不能再开 `fprintAuth`，否则两个会话会抢同一个指纹设备，导致指纹成功率低、键盘输入的密码要等指纹超时才验证。
- 系统中没有启动 swayidle/swaylock，锁屏与空闲只由 DMS 管理。

### 空闲策略（在 DMS 设置界面中手动设置）

这些值保存在 DMS 自己可写的 `settings.json` 中，仓库不管理。在 设置 → 电源/锁屏 中设置，AC 与电池两套都要设：

| 设置项（settings.json 键） | 值 | 作用 |
| --- | --- | --- |
| 锁屏超时 `acLockTimeout` / `batteryLockTimeout` | 600 | 空闲 10 分钟锁屏 |
| 锁屏后关屏 `acPostLockMonitorTimeout` / `batteryPostLockMonitorTimeout` | 120 | 锁屏后再空闲 2 分钟关屏 |
| 休眠超时 `acSuspendTimeout` / `batterySuspendTimeout` | 0 | 不因空闲自动挂起 |
| 挂起前锁屏 `lockBeforeSuspend` | 开 | 通过 logind 延迟锁，合盖和 `systemctl suspend` 都会先锁屏 |
| loginctl 集成 `loginctlLockIntegration` | 开（默认） | `loginctl lock-session` 触发 DMS 锁屏 |

注意：锁屏后关屏要用 *PostLock* 那一项。只设置普通的关屏超时 720 秒的话，锁屏状态变化会重新开始计时，实际要约 22 分钟才关屏。另外 fade-to-lock 默认有 5 秒渐隐，锁屏时间会比 10 分钟多几秒。

当前合盖行为（未在仓库中显式配置，沿用 logind 默认值）：`HandleLidSwitch=suspend`，接电源时同样挂起，扩展坞模式下不处理。

## 麦克风处理与文件管理

启用 `my.features.easyeffects.enable` 后，Home Manager 启用 EasyEffects，随图形会话启动并加载
`microphone-denoise` 输入预设，使用内置 RNNoise 模型。默认不增加增益，
不开启 VAD 门限，避免截断轻声和词尾。设置与预设见
`home-manager/applications/easyeffects.nix`。

EasyEffects 自动将录音应用移到处理后的虚拟输入，VoCoType 的
PulseAudio 兼容录音流也在其中。系统默认输入仍应选择真实麦克风，
不要改成 EasyEffects Source。打开 EasyEffects 的输入页面可查看
应用是否已接入；可用全局旁路对比原声与降噪效果。若 VoCoType 被手动
指定为直接访问硬件的 ALSA 设备，请在其设置中改回 `default` 或 `pulse`。
识别率变化仍需用同一段语音实测。

所有 Niri 主机的 Nautilus 配套启用 GVfs、UDisks2、udiskie 与 Sushi：

- U 盘、移动硬盘接入后自动挂载并通知，在 Nautilus 侧栏弹出/卸载。
- Android 手机解锁并选择「文件传输」后，可通过 MTP 浏览文件。
- `Ctrl+L` 输入 `sftp://主机/路径` 或 `smb://主机/共享` 可访问远程文件。
- 选中文件按空格打开 Sushi 预览；File Roller 提供图形压缩包管理。

Nautilus 是默认的目录打开程序。udiskie 不显示独立托盘图标，
其服务随图形会话启动和停止。文件管理配置在
`home-manager/applications/file-manager.nix`，系统后端在
`modules/niri/default.nix`。

## 历史验收记录

功能分层后的安装入口见 [分阶段安装指南](installation-profiles.md)。

以下为此前启动、登录和锁屏改动的验收记录，不包含新增的麦克风与文件管理功能。

| 项目 | 状态 |
| --- | --- |
| laptop 构建 | 已通过 |
| home/class 的系统 drv 与改动前一致（仍为 SDDM） | 已验证 |
| laptop 只有 greetd，无 sddm；无 swayidle 等空闲服务 | 已验证 |
| GRUB 隐藏/Esc 调出、Plymouth 开关机画面 | 已实机验证 |
| Plymouth → greeter 无厂商 logo 闪回（greeter 9.1s 起，Plymouth 10.6s 保留画面退出） | 已实机验证 |
| Greeter 密码登录（回车立即生效）、注销返回 | 待重启验证（已改为登录只用密码） |
| Super+L 锁屏，密码/指纹解锁 | 已实机验证 |
| 10 分钟锁屏/12 分钟关屏/不自动挂起（AC 与电池两套已在 DMS 界面设置） | 已实机验证 |
| 挂起/合盖前锁屏 | 已实机验证 |
| DMS 设置在重启服务、重新登录、重建后保留 | 已实机验证 |
