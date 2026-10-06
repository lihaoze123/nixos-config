# DMS 快速添加语音热词

在 DMS 启动器输入 `热+`，或按 `Alt+Ctrl+T`（本配置中 Mod 为 Alt），
然后输入热词，选择第一项「保存热词」并回车。只有回车选择保存项时才写文件，
Esc 取消不会添加。

```text
热+豆包
热+NixOS
热+NixOS = 尼克斯 | nix os
```

`=` 左边是标准写法，右边是识别后纠错的别名，多条用 `|` 分隔。
`=` 和 `|` 是本插件的语法分隔符，需要包含这些字符的词条请在 VoCoType 设置中心维护。
插件默认设置 `hotword: true` 和 `protect: true`。热词限 1–10 个字符、不能包含空白，
沿用当前 VoCoType 核心的筛选规则；别名可以包含空格。

词库默认是 `~/.config/vocotype/terms.yaml`，也遵循 `XDG_CONFIG_HOME`、
`VOCOTYPE_TERMS_FILE` 和旧 `user-dictionary.yaml` 的回退规则。
直接使用 VoCoType 原来的词库，不另建词表。核心会在下一次听写时检查词库变更，
无需重建系统、重启输入法或在豆包控制台再维护一份；豆包热词接入代码需先应用到系统。

已有标准词会显示「已存在」，不会覆盖原有别名或热词选项。词语和别名与其他词条
冲突时阻止保存；修改已有词、保护词或多词英文表达请使用 VoCoType 设置中心。

写入前由 flake 固定的 VoCoType 原生解析器验证。新增词块保留已有注释和内容，
跟随符号链接写入真实文件，使用文件锁、预览指纹和原子替换；
词库在预览后变化时提示刷新，避免覆盖修改。外部编辑器不受插件锁约束，避免同时编辑。
已有文件的备份保存在 `$XDG_STATE_HOME/vocotype-hotwords/backups/`，默认
`~/.local/state/vocotype-hotwords/backups/`。测试不会写入正式词库。

插件由 Home Manager 安装，并在首次安装时启用；之后尊重 DMS 设置中的禁用选择。
命令行入口：

```bash
dms ipc call vocotypeHotwords add
dms ipc call vocotypeHotwords status
```

在仓库根目录构建并运行词库测试：

```bash
parser_store=$(nix build --impure --no-link --print-out-paths --expr \
  '(builtins.getFlake (toString ./.)).nixosConfigurations.laptop.config.home-manager.users.chumeng.xdg.configFile."DankMaterialShell/plugins/vocotypeHotwords".source.parser')
VOCOTYPE_TEST_PARSER="$parser_store/bin/vocotype-terms-parser" \
  python3 home-manager/fcitx5/tests/test-vocotype-hotwords.py
```
