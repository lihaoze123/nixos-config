# Fcitx5 与小鹤音形

[default.nix](default.nix) 是 Home Manager 模块入口，负责词库构建、
配置部署、输入法服务，以及查码/加词工具和 DMS 插件的安装。

当前固定上游 [rime-crane `71f3add`（2026-09-10）](https://github.com/kchen0x/rime-crane/commit/71f3add6a39d58a8e8b35abc7ca9c998d766b274)，
包含小鹤音形官方清风版 `v1.26.9c` 码表及同步至 2026-09-08 的雾凇词库。
本地继续采用「上游词库 → 通用/工作/编程/聊天用户词库 → 计算机补充词库」
的导入顺序；置顶用户词库仍在最前。上游可选的 5 码英文联想未启用。

```text
fcitx5/
├── default.nix         # Nix 模块入口
├── README.md
├── config/             # Fcitx5 profile 与 Rime 配置补丁
├── dictionaries/       # 计算机术语源数据与许可证（用户词库在独立仓库 xhup-dicts）
├── scripts/            # 词库生成脚本与查码/加词程序
├── patches/            # rime-crane 快捷键补丁
├── tests/              # 查码测试
└── docs/               # 使用与维护说明
    └── archive/        # 已完成任务的计划和研究记录
```

## 常用修改入口

### 输入法列表

[config/profile](config/profile) 默认包含英文键盘、Rime 和微信拼音，默认中文输入法为 Rime。
微信拼音需另外安装并初始化 [VType 独立包](../../profiles/vtype-linux/README.md)。
输入法列表由 Home Manager 管理；修改此文件并应用配置后，重启 Fcitx5 生效。

### 候选框主题

安装 [Mellow 主题](https://github.com/sanweiya/fcitx5-mellow-themes) 的全部五种配色，
默认使用釉蓝（`mellow-youlan` / `mellow-youlan-dark`），随桌面浅色／深色切换。
上游版本与校验和固定在 `default.nix`；配色、字体、候选列表方向和缩放设置
由 `config/classicui.conf` 管理。修改该文件的 `Theme` 和 `DarkTheme` 后重新应用配置，
再运行 `systemctl --user restart fcitx5-daemon.service` 重启输入法。
配置工具中的临时修改会在下一次应用配置时被覆盖。

### 云端语音输入：Vinput Lite + 豆包

启用 `my.features.desktop.enable`、`my.features.speech.enable` 和
`my.features.doubao.enable`（laptop、home 已启用）。Lite 只有云端识别，
不安装 FunASR、ONNX Runtime 或本地 ASR 模型；speech 必须同时启用 doubao。

聚焦文本框，**按住 F9 说话，松开完成听写**，在小鹤和英文模式下都能使用。
`Shift+F9` 打开 Vinput 命令面板；关闭默认右 Alt、右 Ctrl、右 Shift 绑定。
当前只配置原始听写，不配置 LLM，也不绑定语音编辑键。
打开 `vinput-gui` 查看状态；参数由 Home Manager 管理，修改入口为
[vinput.nix](vinput.nix)，GUI 中的配置修改不能覆盖只读的声明式配置。

使用官方豆包 ASR 2.0 双向流式接口
`wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async`，资源为
`volc.seedasr.sauc.duration`。录音期间直接向云端发送 16 kHz 单声道 PCM，
中间文字来自豆包，松键后等待最终结果；不再使用本地模型预览。
需要联网，费用由火山引擎账号所开通的服务计收；失败不回退到本地。

[vinput-doubao.py](scripts/vinput-doubao.py) 包装固定版本的上游 provider，
补充现有单 API Key 认证、词库热词及别名替换，并去除最终文字末尾的句号。
凭据沿用 agenix 的 `age.secrets.doubao-asr`，只在 provider 运行时读取；
不写入 Vinput 配置或 Nix store。支持原来的 JSON：

```json
{ "api_key": "你的语音服务 API Key" }
```

也支持 `app_id` 与 `access_token`。编辑密文继续使用：

```bash
ragenix --rules secrets/secrets.nix --edit secrets/doubao-asr.age
```

词库继续放在 `~/.config/vocotype/terms.yaml`，保留旧路径以复用用户数据。
DMS `Alt+Ctrl+T` 或 `热+NixOS = 尼克斯 | nix os` 仍可加热词及纠错别名，
下一次录音会重新读取词库，无需重启或重建。仅复用 VoCoType 的独立词库解析器，
不启动或安装其识别核心。保护词不再参与 VoCoType 的后处理，别名按显式词条替换；
数字和标点由豆包负责。详见 [DMS 热词插件](dms-hotwords/README.md)。

录音直接使用 PipeWire 的默认输入，关闭本地 VAD 和额外音量归一化，
避免重复处理 EasyEffects 输出。首次应用后，在 EasyEffects 输入页面确认
Vinput 录音流经过降噪；不要把系统默认麦克风设置为 EasyEffects Source。

识别服务为 `vinput-daemon.service`，等待 agenix 解密完成，在登录后启动，
异常退出自动重启。排查命令：

```bash
systemctl --user status vinput-daemon.service
journalctl --user -u vinput-daemon.service -b
```

迁移只改变声明式配置，不删除旧模型、设置或词库。应用新配置后应确认
旧 `vocotype-fcitx5-backend.service` 已停止，Fcitx5 已重新加载 Vinput。
未应用配置前仍运行原方案。只有明确要求构建或部署时才执行系统构建／切换。

离线回归测试（不用真实凭据，不联网）：

```bash
nix shell nixpkgs#python3 --command python3 home-manager/fcitx5/tests/test-vinput-doubao.py
```

### 配置与词库

| 修改内容 | 文件 |
| --- | --- |
| 通用、聊天、编程、工作词库 | 私有仓库 [xhup-dicts](https://github.com/lihaoze123/xhup-dicts)，本地为 `~/src/xhup-dicts/xhup.user*.dict.yaml` |
| 计算机术语补充 | [dictionaries/computer-terms.txt](dictionaries/computer-terms.txt) |
| 术语读音修正 | [dictionaries/computer-pinyin-overrides.txt](dictionaries/computer-pinyin-overrides.txt) |
| Rime 方案列表 | [config/default.custom.yaml](config/default.custom.yaml) |
| 小鹤方案与输入法内反查 | [config/xhup.custom.yaml](config/xhup.custom.yaml) |
| 查码前缀、glob 与排序逻辑 | [scripts/xhup-lookup.py](scripts/xhup-lookup.py) |
| DMS 插件（启动器、加词语法、字根图） | 独立仓库 [dms-xhup](https://github.com/lihaoze123/dms-xhup)，经 flake 输入 `dms-xhup` 引入 |

四份用户词库放在独立的私有仓库 `lihaoze123/xhup-dicts`，克隆在 `~/src/xhup-dicts`，通过
`mkOutOfStoreSymlink` 链接到 `~/.local/share/fcitx5/rime/xhup_dicts/`。新机器激活 Home Manager 时自动克隆，
失败（离线或还没有 SSH key）只给出警告，之后手动克隆并重新部署即可。加词或手工编辑不会改动本仓库，
也不触发系统重建；在词库仓库中运行 `just sync` 提交、合并其他机器的改动并推送。
修改后，Rime 需要重新部署；DMS 插件在下次查询时自动重新加载。
计算机术语码表由 Nix 生成，修改术语源数据后需要重新构建。

## 说明与验证

- [计算机词库来源、生成规则与维护](docs/computer-dictionary.md)
- [实时查码（DMS）、前缀与 glob 用法](docs/xhup-lookup.md)
- [快速添加用户词：快捷键、部署与恢复](docs/add-user-word.md)
- [加词实现计划及验证记录](docs/plans/add-user-word/implementation.md)
- [历史研究记录](docs/archive/notes.md)与[已完成任务计划](docs/archive/task_plan.md)
  仅作归档，其中的路径和阶段描述保留当时记录。

查码测试需要 Python 与 PyYAML，从仓库根目录运行：

```bash
python3 home-manager/fcitx5/tests/test-xhup-lookup.py
```

DMS 插件及其后端的测试在 dms-xhup 仓库中。

从仓库根目录构建当前 laptop 配置：

```bash
nixos-rebuild build --flake path:.#laptop
```

`path:.` 会包含尚未加入 Git 的迁移文件。其他机器替换主机名。
