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
├── dictionaries/       # 手工码表、计算机术语源数据与许可证
├── scripts/            # 词库生成脚本与查码/加词程序
├── patches/            # 非 DMS 主机查码用的 wofi 补丁
├── tests/              # 查码测试
└── docs/               # 使用与维护说明
    └── archive/        # 已完成任务的计划和研究记录
```

## 常用修改入口

### 离线语音输入

通过 flake 固定 VoCoType-linux `v5.0.1`，作为 Fcitx5 全局插件安装。
在小鹤或英文输入模式下，聚焦文本框后按住 `F9` 说话，松开后提交文字。

首次使用运行 `vocotype-model-manager --download --all` 下载并校验模型，
再打开 `vocotype-settings` 选择麦克风，可在 Playground 中测试录音和识别。
模型保存在用户缓存中；普通听写在本地运行。设置中心中的 AI 润色和
语音编辑需要另外配置 API，普通听写无需配置。

插件由 Nix / Home Manager 安装，更新后重启 `fcitx5-daemon.service`；
无需使用设置中心的输入法安装或修复按钮。

录音和回放通过 PipeWire 的 PulseAudio 兼容服务，设备选择 `default`，
采样率为 `48000`，跟随系统当前默认麦克风和扬声器。
直接选择笔记本的 `DMIC Raw` 曾出现严重失真，因此包装器仅暴露系统
默认音频设备。ALSA 插件使用 VoCoType 固定的 nixpkgs，以匹配其 libc。

### 配置与词库

| 修改内容 | 文件 |
| --- | --- |
| 通用自定义词 | [dictionaries/xhup.user.dict.yaml](dictionaries/xhup.user.dict.yaml) |
| 聊天、编程、工作词库 | `dictionaries/xhup.user.{chat,coding,work}.dict.yaml` |
| 计算机术语补充 | [dictionaries/computer-terms.txt](dictionaries/computer-terms.txt) |
| 术语读音修正 | [dictionaries/computer-pinyin-overrides.txt](dictionaries/computer-pinyin-overrides.txt) |
| Rime 方案列表 | [config/default.custom.yaml](config/default.custom.yaml) |
| 小鹤方案与输入法内反查 | [config/xhup.custom.yaml](config/xhup.custom.yaml) |
| 查码前缀、glob 与排序逻辑 | [scripts/xhup-lookup.py](scripts/xhup-lookup.py) |
| DMS 插件（启动器、加词语法、字根图） | 独立仓库 [dms-xhup](https://github.com/lihaoze123/dms-xhup)，经 flake 输入 `dms-xhup` 引入 |

四份手工码表通过 `mkOutOfStoreSymlink` 链接到
`~/.local/share/fcitx5/rime/xhup_dicts/`，直接编辑 `dictionaries/` 下的源文件。
修改后，Rime 需要重新部署；wofi 查码窗口重新打开即可读取，DMS 插件在下次查询时自动重新加载。
计算机术语码表由 Nix 生成，修改术语源数据后需要重新构建。

## 说明与验证

- [计算机词库来源、生成规则与维护](docs/computer-dictionary.md)
- [实时查码（DMS / wofi）、前缀与 glob 用法](docs/xhup-lookup.md)
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
