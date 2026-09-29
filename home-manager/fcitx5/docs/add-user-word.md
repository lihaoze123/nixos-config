# 快速添加用户词

`Mod+Ctrl+X` 打开 `xhup-add-word`。它维护仓库中的文本用户词库，保存后请求当前 Fcitx5/Rime 重新部署。日常加词不需要重建系统。

## 首次安装

从仓库根目录执行，其他机器替换主机名：

```bash
nixos-rebuild build --flake path:.#laptop
sudo nixos-rebuild switch --flake path:.#laptop
systemctl --user restart fcitx5-daemon.service
```

本模块禁用了重复的 XDG Fcitx5 自启动，以 Home Manager 用户服务为唯一入口。服务的 `Conflicts` 和 `After` 会在启动前停止旧的 `app-org.fcitx.Fcitx5@autostart.service`。第一次应用后执行上面的 restart，确保旧实例已交接；输入法短暂退出后恢复。工具不会在每次加词时重启输入法。

## 日常使用

1. 按 `Mod+Ctrl+X`，在空白输入框中输入词语，也可以手动粘贴。窗口不读取剪贴板进行预填。
2. 回车进入编码页，检查建议读音与编码，编码可以直接编辑。
3. 回车进入确认页。标题显示词语、编码、分类及重码数量；列表包含保存操作、已有词条、重码候选及来源。选择“保存并部署”或“仅保存”。

默认写入通用词库。确认页可“切换词库”为 work、coding、chat，也可“修改读音并重新编码”。读音使用空格分隔的无声调拼音，ü 可以写成 v；中英混合词中的英文字母逐个填写。任何一步按 Esc 都会取消尚未保存的操作。

自动编码复用计算机词库生成器：双字 2+2、三字 1+1+2、长词取前三字和末字首码。现有码表编码优先，拼音建议优先使用附带词典注音，再由 pypinyin 补充。单字需要使用已有音形编码或手填；含标点等无法自动编码的词语也可以手填。

词语限 1–128 个字符，不接受换行、制表符、控制字符或以 `#` 开头的词语。编码限 1–4 个英文字母，自动转为小写。

## 重复、重码与词频

- 同词同码已存在于任何启用词库：提示来源，不追加、不再次部署。
- 同词不同码：保留现有码，允许确认后增加别码。
- 同码不同词：显示已有候选、权重和来源，确认后共存。

新增权重固定为 `100`，与现有手工词库一致。预览按权重排列，不代表 Rime 最终候选顺序，也不保证新增词成为首选。

## 保存和部署状态

“已保存”表示源文件已写入；“已请求部署”表示当前实例接受了请求。Rime 部署异步运行，完成或失败由其原生通知报告。请求成功不等于词语已经可输入。

工具会核对 D-Bus 实例实际加载的 Rime 插件及用户数据目录。若仍是旧实例、服务未启动或无法核实时，可选择“仅保存”；完成服务交接后重试：

```bash
xhup-add-word deploy
```

部署请求失败时词语仍保存在词库中，不会自动回滚；超时可能意味着请求已经发出，先查看 Rime 通知再决定是否重试。

保存前会检查确认期间词库是否变化，必要时要求重新确认；工具自身使用文件锁避免并发覆盖。外部编辑器不受该锁约束，避免同时手工编辑正在保存的文件。

## 命令行

```bash
# 仅预览建议编码、读音、已有词条和重码；不写入或访问部署接口
xhup-add-word add '快速加词示例' --dry-run

# 指定词语、编码、分类，直接保存并请求部署
xhup-add-word add '我的项目' --code wdxm --category work --yes

# 只写文件，不部署
xhup-add-word add '我的项目' --code wdxm --category work --yes --save-only
```

不带 `--yes` 或 `--dry-run` 时进入 wofi 确认流程。单字和不能自动编码的词语请提供 `--code`。

结果以 JSON 输出，状态包括 `preview`、`cancelled`、`already_exists`、`saved_only`、`deploy_requested`、`saved_deploy_failed`。退出码 0 表示按选择完成或无须添加；2 为输入/预检错误，3 为写入错误，4 为部署请求错误。特别是 `saved_deploy_failed` 表示文件已经保存；不要将非零退出码当成没有写入。

## 备份与恢复

目标文件仍是 `dictionaries/xhup.user*.dict.yaml`。工具跟随 Home Manager 链接写真实源文件，保留链接和已有注释，每次写入更新 Rime 的词库版本。

修改前备份保存在 `$XDG_STATE_HOME/xhup-add-word/backups/`，默认 `~/.local/state/xhup-add-word/backups/`；命令结果会给出具体备份路径。工具不会自动提交 Git。恢复时先比较源文件与备份，确认不会覆盖后来添加的词，再恢复源文件并重新部署。

## 验证

在仓库根目录，用与系统配置一致的依赖运行单元测试：

```bash
nix shell --impure --expr '
  let p = (builtins.getFlake (toString ./.)).nixosConfigurations.laptop.pkgs;
  in p.python3.withPackages (ps: [ ps.pyyaml ps.pypinyin ])
' -c python3 home-manager/fcitx5/tests/test-xhup-add-word.py
```

测试覆盖编码、重复/重码、符号链接、备份、原子替换失败、并发锁、确认期间修改、取消、只保存和部署错误。

原有查码回归使用同一条命令，将末尾路径替换为 `home-manager/fcitx5/tests/test-xhup-lookup.py`。文件名包含连字符，直接运行脚本，避免 unittest discover 静默跳过它们。

`tests/test-xhup-rime-integration.py` 还可在独立 `dbus-run-session` 中启动真实 Fcitx。通过 `--fcitx`、`--data-dir`、`--plugin` 指定同一次构建的路径，通过 `--probe` 指定使用 librime 编译的 `tests/rime-candidate-probe.c`。它复制词库至临时 HOME，添加测试词并发起真实部署，退出测试 Fcitx 后查询 Rime 候选，最后自动清理，不修改实际用户词库。

实际使用时，添加自己的词语后等待部署完成，切换到小鹤并输入其编码验证候选；wofi 查码能读到文本只说明保存成功。
