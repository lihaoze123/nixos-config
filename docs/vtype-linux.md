# VType Linux（微信拼音）

微信拼音 Fcitx5 插件使用 [NUR 配方](https://github.com/lihaoze123/nur-packages/tree/main/pkgs/vtype-linux)
打包上游 [vtype-linux](https://github.com/zhl-HFUT/vtype-linux)，包含插件、ARM64 宿主、AOSP 运行库、静态 QEMU、wxc 以及
`wetype-setup`、`wetype-check`、`wetype-demo`、`wetype-cloud` 命令。上游 Nix 说明见
[docs/NixOS.md](https://github.com/zhl-HFUT/vtype-linux/blob/main/docs/NixOS.md)。

## 启用

在主机的 `default.nix` 中开启（需要 `my.desktop`，laptop、class 已开启）：

```nix
my.input.vtype.enable = true;
```

Home Manager 把插件加入 Fcitx5 的 addons，并安装上述命令。`~/.config/fcitx5/profile`
由仓库的 `modules/home/desktop/fcitx5/config/profile` 管理，已包含 `wetype-im`，默认中文输入法仍为 Rime。
NUR 官方索引收录配方更新后，使用 `nix flake update nur` 更新客户端锁定版本。

当前锁定上游 2026-10-16 的 `03b011c359a354bd8a790e24ae6e1552ae788359`，
包含 19 组模糊音、自定义翻页键、输入框内显示拼音、始终使用英文标点，
以及 GNOME Wayland 剪贴板和常用语导出的修复。
云候选有效期使用上游实现，默认 1500ms，可通过 `cloud.json` 的 `cloud_timeout_ms`
设置为 200–5000ms。NUR 额外保留身份锁竞争修复：后台同步占锁时，云查询最多等待
300ms，避免短暂竞争使查询立即失败；网络请求超时仍为上游的 1.2 秒。

## 首次初始化

腾讯引擎与词库不进入 Nix 包。切换到新系统后，先退出 Fcitx5，再从腾讯服务器下载微信输入法
3.5.4 APK（约 214 MB），校验后在用户目录提取引擎并打补丁：

```bash
systemctl --user stop fcitx5-daemon.service
wetype-setup                     # 已有 APK：wetype-setup --apk ~/.cache/wetype-ime/wetype_3.5.4.apk
wetype-check
systemctl --user start fcitx5-daemon.service
```

此前通过 nix profile 或手动安装过运行时的机器（laptop、class），改用迁移命令，
它会备份旧运行目录和用户级插件注册文件，避免遮蔽新插件：

```bash
wetype-setup --migrate-fcitx
wetype-check
```

之后每次更新插件，都要退出 Fcitx5 后重新运行 `wetype-setup`，以刷新运行目录中的包资源链接。

| 内容 | 位置 |
| --- | --- |
| Android 引擎、公共词库与运行时 | `~/.local/lib/wetype-ime/arm64` |
| 官方 APK 缓存 | `~/.cache/wetype-ime/wetype_3.5.4.apk` |
| 个人学习词库 | `~/.local/share/wetype-ime` |
| 设备关联身份 | `~/.local/state/wetype-ime/account`（关联后生成，勿分享） |

## 使用

```bash
wetype-demo nihc                 # 命令行查看候选
fcitx5-remote -s wetype-im       # 切到微信拼音
fcitx5-remote -s rime            # 切回 Rime
```

Fcitx5 由 `fcitx5-daemon.service` 管理，重启使用 `systemctl --user restart fcitx5-daemon.service`，
会中断当前未上屏内容。

## 拼音方案设置

运行 `fcitx5-configtool`，在输入法列表中选中“微信拼音”，点击配置按钮，
将“拼音方案”设为“全拼”或“小鹤双拼”并应用。附加组件中的“微信输入法”
配置入口也提供相同设置。

配置保存在 `~/.config/fcitx5/conf/wetype.conf`：

```ini
PinyinScheme=小鹤双拼
```

应用后插件自动重启自己的引擎会话。切换前先完成当前输入；尚未完成的编码
会作为原始文本上屏。双拼预编辑每两键分段，例如 `ni hc`；词库学习和部分选词
由官方引擎处理。其他双拼方案尚未接入图形设置。

`wetype-demo` 跟随这个配置；临时用全拼可运行 `WETYPE_DOUBLE_PIN=0 wetype-demo nihao`。

同一设置界面也可调整 19 组模糊音、上一页/下一页按键、输入框内显示拼音
和始终使用英文标点。模糊音默认全部关闭，逗号/句号翻页需自行配置；
更新插件后保留已有设置。

## 云功能

```bash
wetype-cloud pair
wetype-cloud enable --timer
wetype-cloud status
```

手机或电脑确认关联后重启 Fcitx5。剪贴板互通需另外执行 `wetype-cloud clipboard enable`。
设备关联、云候选与剪贴板同步需分别启用，数据发送范围见
[上游说明](https://github.com/zhl-HFUT/vtype-linux#会发送什么)。

## 历史词库恢复记录（class）

词库增量同步成功不代表历史快照已经导入。隔离补拉已确认一处快照凭证
校验问题：官方引擎使用设备编号和快照版本申请下载凭证，可能与下载 URL 的
文件名不同。临时补丁修正校验后，配对设备的备份下载返回 `404 NoSuchKey`，
尚未完成历史快照合并。进一步用元数据中的文件名重新申请下载签名，两条备份
路径仍返回 404；仅有快照元数据不能保证文件可用。当前包仍保留原有快照放行规则。

历史数据还可通过重拉服务器保留的增量记录恢复。针对 `class` 的已关闭词库
副本，将增量游标归零后由官方引擎只读重放，补回了 84 条词语关联记录和
41 条前缀学习记录。另行准备的恢复副本只补入这 125 条缺失记录，全部原有
记录和值保持不变；全拼、小鹤双拼、部分选词和重启读取均通过离线验证，
补入的记录在重启后仍保留。

经用户确认，已在退出输入法并备份正式词库后，补入这 125 条仍缺失的记录。
写入时全部原有记录和值保持不变，同步游标未修改。实际输入法重启后检查，
125 条记录仍保留；更新后的正式词库副本也通过上述离线输入和重启验证。

没有快照合并记录不等于所有历史词条都缺失；重放增量也不能证明手机端所有
数据已完整恢复。后续仍需用官方设备上已有、Linux 上缺失的具体词语验证。

设备关联、云候选与剪贴板同步需分别启用，
数据发送范围见 [上游说明](https://github.com/zhl-HFUT/vtype-linux#会发送什么)。

## 停用

先切回 Rime，在 Fcitx5 设置中移除“微信拼音”，再卸载插件：

```bash
nix profile remove vtype-linux
systemctl --user restart fcitx5-daemon.service
```

引擎和用户词库保留在上述用户目录，卸载 profile 包不会删除它们。

## 停用

先切回 Rime，再在主机配置中关闭 `my.input.vtype.enable` 并重建系统。
引擎和用户词库保留在上述用户目录，停用不会删除它们。
