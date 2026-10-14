# VType Linux 试用

独立 NUR 仓库的 `pkgs/vtype-linux/default.nix` 提供固定版本的微信拼音 Fcitx5 插件、静态 QEMU 和
`wetype-demo`、`wetype-cloud` 命令，并补充小鹤双拼设置。用独立用户 profile 安装：

```bash
nix profile install github:lihaoze123/nur-packages#vtype-linux
```

这个包编译带双拼支持的 Android 宿主程序，需要另行安装腾讯引擎库、词库和
Android 系统运行库；首次安装不会自动下载这些腾讯文件。
当前 `class` 机器已从腾讯官方下载并校验微信输入法 3.5.4 APK，
按上游脚本编译和安装运行时，位置如下：

| 内容 | 位置 |
| --- | --- |
| 固定版本源码 | `~/.local/share/vtype-linux-src`，提交 `f73fc9a4942dcbc5cfe270b716ae892895da173d` |
| Android 引擎、公共词库与运行时 | `~/.local/lib/wetype-ime/arm64` |
| 官方 APK 缓存 | `~/.cache/wetype-ime/wetype_3.5.4.apk` |
| 个人学习词库 | `~/.local/share/wetype-ime` |
| 设备关联身份 | `~/.local/state/wetype-ime/account`（关联后生成，勿分享） |

其他机器的引擎准备步骤见
[上游安装说明](https://github.com/zhl-HFUT/vtype-linux/blob/main/docs/安装与使用.md)。
编译需要 Android NDK r27c；NixOS 上通过 `nix shell` 提供 `unzip`、`e2fsprogs`，
使用本包的 `libexec/qemu-aarch64-static`，并用本包的 Fcitx 插件替代上游安装器
生成的插件。本包修正了插件库的搜索路径和 Python 入口。

## 本地试用

命令行查看候选：

```bash
wetype-demo nihc
```

在 Fcitx5 设置中添加“微信拼音”并重启输入法后，可以切换：

```bash
fcitx5-remote -s wetype-im
fcitx5-remote -n
```

当前 `class` 的微信拼音已使用小鹤双拼，输入 `nihc` 应出现“你好”，
`vsgo` 应出现“中国”。切回 Rime：

```bash
fcitx5-remote -s rime
```

Fcitx5 由 `fcitx5-daemon.service` 管理，重启使用
`systemctl --user restart fcitx5-daemon.service`。重启会中断当前未上屏内容。
`~/.config/fcitx5/profile` 由 Home Manager 管理；试用期间对该文件的本地修改
会在下次 Home Manager 激活时被仓库中的输入法列表替换。

当前 `class` 已追加 `wetype-im` 并切换到微信拼音，默认输入法仍为 Rime。
启用前的配置备份在 `~/.local/state/vtype-linux/backup-20261013-104312/`，
`profile.original` 保存原内容，`profile.symlink-target` 保存原 Home Manager 链接目标。

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

## 自检与关联

安装自检使用临时词库，不修改个人学习数据。指定本包宿主程序：

```bash
python3 ~/.local/share/vtype-linux-src/scripts/test_bionic_daemon.py \
  --engine-dir ~/.local/lib/wetype-ime/arm64 \
  --harness ~/.nix-profile/libexec/wetype-harness
```

NUR 仓库中的双拼回归检查（在 nur-packages 根目录执行）：

```bash
python3 tests/vtype-linux/test-double-pinyin.py \
  --source ~/.local/share/vtype-linux-src --package ~/.nix-profile
```

同一脚本的 `--mode fcitx` 使用独立 D-Bus 和临时 Fcitx 配置，测试图形设置、
上屏与方案切换；此模式另需 `dbus-python` 和 `pygobject3`。

包内提供 wxc 0.1.0，设备关联无需另外安装 npm 包。默认使用包内客户端，
可用 `WETYPE_WXC` 显式覆盖；已有设备身份继续保留在用户目录：

```bash
wxc --version
wetype-cloud pair
```

`wetype-cloud` 和引擎云代理的 Python 入口已包含 OpenSSL 路径，避免 NixOS
出现找不到 `openssl` 的错误。协议脚本随包安装，并使用固定的 Snappy 共享库
路径；不依赖 `ctypes.find_library` 在系统目录中查找库。压缩响应回归检查：

```bash
python3 tests/vtype-linux/test-cloud-runtime.py --package ~/.nix-profile
```

云候选启用时，本包将官方引擎接收云结果的时限从 200 毫秒调整为 1.5 秒，
避免 HTTPS 和 QEMU 的响应耗时导致成功结果被丢弃。本地候选仍先显示；
云候选到达后沿用引擎的会话、版本及输入覆盖长度校验。同步短暂占用身份锁时，
云查询最多等待 300 毫秒再获取锁。离线检查不读取账户、不发送网络请求：

```bash
python3 tests/vtype-linux/test-cloud-latency.py \
  --source ~/.local/share/vtype-linux-src --package ~/.nix-profile
```

在临时词库和独立 Fcitx 会话中，全拼 `xianyanbao` 已验证能从云端补入
“显眼包”并正确选词上屏；小鹤双拼也已验证异步候选更新。不同编码的云端
候选可能不同，某个热词缺失仍需检查实际响应。云候选更新不等于上屏后的词语联想。

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
