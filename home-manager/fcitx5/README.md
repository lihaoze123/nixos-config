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

识别核心由 `vocotype-fcitx5-backend.service` 用户服务在登录后启动，
独立于设置窗口运行，异常退出后自动重启。如果出现
`cannot connect to native core`，用
`systemctl --user status vocotype-fcitx5-backend.service` 查看状态，
用 `journalctl --user -u vocotype-fcitx5-backend.service -b` 查看日志。

录音和回放通过 PipeWire 的 PulseAudio 兼容服务，设备选择 `default`，
采样率为 `48000`，跟随系统当前默认麦克风和扬声器。
直接选择笔记本的 `DMIC Raw` 曾出现严重失真，因此包装器仅暴露系统
默认音频设备。ALSA 插件使用 VoCoType 固定的 nixpkgs，以匹配其 libc。

### 豆包在线语音输入（可选）

保留按住 `F9` 录音、松开上屏的操作，最终转写可改用火山引擎官方
[豆包 ASR 2.0 一句话识别 WebSocket API](https://docs.volcengine.com/docs/DoubaoVoice/unidirectional-streaming-automatic-speech-recognition-websocket?lang=zh)。
接口为 `wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_nostream`，
属于流式语音识别，不使用录音文件识别 API。
当前适配器在松键后将录音转换为 PCM 数据包，通过 WebSocket 发送，
收到最终完整结果后提交文字；尚未实现按住 F9 时实时向云端发送音频。
需联网，费用按火山引擎账号所开通的服务计收。
本次接入不改变本地实时预览，也不接入语音对话或文字润色 API。

1. 在[豆包语音控制台](https://console.volcengine.com/speech/app)开通
   **豆包流式语音识别模型 2.0（小时版）**，确认资源 `volc.seedasr.sauc.duration` 可用，
   获取该语音服务的 API Key（不是方舟文字模型的 API Key）。
2. 密钥由 Home Manager 的 agenix 模块声明为 `age.secrets.doubao-asr`，
   运行时从其 `path` 读取。仓库只保存 `secrets/doubao-asr.age` 密文，
   recipients 沿用 `secrets/keys.nix` 中的 laptop 和 home 公钥。
   使用仓库中的 ragenix（agenix 兼容实现）编辑密钥：

   ```bash
   ragenix --rules secrets/secrets.nix --edit secrets/doubao-asr.age
   ```

   解密编辑器中填写 JSON 凭据，仅包含密钥，不包含功能开关：

   ```json
   { "api_key": "你的语音服务 API Key" }
   ```

   旧版控制台可填写 `app_id` 和 `access_token`，不填写 `api_key`。
   不将明文内容写进 Nix 表达式、Nix store 或普通用户配置文件。
3. 在主机的 Home Manager 配置中声明开关（laptop 已启用）：

   ```nix
   programs.vocotype.doubao.enable = true;
   ```

   其他主机默认使用本地识别，也不会解密豆包凭据。
4. 构建并应用配置，Home Manager 的 `agenix.service` 负责在用户运行时目录解密凭据，
   语音后端通过 `After` / `Requires` 等待解密完成：

   ```bash
   nixos-rebuild build --flake path:.#laptop
   sudo nixos-rebuild switch --flake path:.#laptop
   systemctl --user restart vocotype-fcitx5-backend.service
   ```

   最终识别由该用户服务提供，请保持服务运行。VoCoType 设置中心的
   自动拉起路径仍属于上游包，不能代替此服务启动在线后端。
   Fcitx 用户服务等待识别后端启动，并将插件的兜底启动器指向
   `systemctl --user start vocotype-fcitx5-backend.service`，防止上游硬编码的
   `/usr/bin/systemctl` 路径在 NixOS 上失效后启动第二个本地识别核心。
   首次迁移后，agenix 解密成功且凭据与旧文件一致时，会自动移除
   `~/.config/vocotype/doubao-asr.json`。若凭据不一致则保留旧文件并报错。

可用已有 WAV 录音独立验证接口（会上传转换后的音频）：
后端会在内存中自动转换为 16 kHz、16 bit、单声道 PCM，保留原录音文件。
F9 的最终录音通常为 48 kHz，也通过同一转换处理，无需调整麦克风设置。

```bash
pw-record --rate 16000 --channels 1 --format s16 /tmp/doubao-test.wav
# 说完后按 Ctrl+C 停止录音，再执行：
vocotype-doubao-worker --transcribe /tmp/doubao-test.wav
```

agenix 已解密凭据后，也可从仓库构建并运行同一后端：

```bash
nix run --impure --expr 'let f = builtins.getFlake (toString ./.); in builtins.head (builtins.filter (p: p.name == "vocotype-doubao-worker") f.nixosConfigurations.laptop.config.home-manager.users.chumeng.home.packages)' \
  -- --transcribe /tmp/doubao-test.wav
```

切回本地识别时，将 `programs.vocotype.doubao.enable` 改为 `false`，
重新构建并应用系统配置。不会读取先前的 `~/.config/vocotype/doubao-asr.json`。
云端失败会显示错误，不自动重试。服务端错误保留状态码或错误类别，
便于排查，不输出密钥、录音或服务端响应正文。

目前仍需保留已下载的本地模型目录：上游核心启动 worker 前会检查目录。
本地热词会自动随每次最终识别请求传给豆包，无需在控制台维护第二份词表。
继续在 VoCoType 设置中心维护用户词典（`hotword: true` / `hotwords`）及
`asr.hotword` 临时热词；核心合并后的热词通过 `request.corpus.context`
发送，格式遵循上面的豆包接口文档。修改词典后可在设置中心点击“热更新词典”。
现有术语替换和文本规范化继续由 VoCoType 核心处理；仅作为别名或保护词的条目
不会自动成为云端热词。沿用核心现有筛选规则：单词不含空白、至多 10 个字符，
去重后最多 1000 个热词。热词提高识别概率，不保证每次命中。
上面的 `--transcribe` 命令直接调用 worker，绕过核心，因此不加载用户词典；
验证词库效果请通过输入法正常听写。
交互录音在本地限制为 25 MiB，请求超时为 60 秒。

协议测试（不联网，不使用真实凭据）：

```bash
nix shell --impure --expr 'let f = builtins.getFlake (toString ./.); p = f.inputs.nixpkgs.legacyPackages.x86_64-linux; in [ (p.python3.withPackages (ps: [ ps.websockets ])) p.ffmpeg-headless ]' \
  --command python3 home-manager/fcitx5/tests/test-doubao-asr.py
```

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
