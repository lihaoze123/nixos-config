# 小鹤反查

`Mod+Shift+X` 打开实时查码；输入后自动更新，回车复制选中的编码，Esc 关闭。
`Mod+X` 打开字根图。

- **启用 DMS 的主机**（laptop）：快捷键打开 DMS 启动器并填入触发前缀 `;`，
  结果由 [dms-xhup](https://github.com/lihaoze123/dms-xhup) 插件提供；在启动器中直接输入 `;he` 也一样。
  右键结果可单独复制词语或某个编码。字根图是 DMS 覆盖层，按 Esc 或点击外侧关闭。
- **其他主机**：使用下文的 wofi 实时窗口和 swayimg 字根图。

两种前端共用同一套匹配规则：

- 普通文本按**字段前缀**匹配汉字/词语、单字全拼和小鹤编码。
  `he` 可以匹配 `he`、`hei`、`hen`、`heng`，不会因为 `she` 中间含有 `he` 而命中。
  任一读音或编码匹配即可，因此多音字可能凭另一个读音命中。
- 输入含 `*`、`?`、`[` 时，按 glob **完整字段**匹配，不隐式补 `*`：
  `he*` 匹配以 he 开头的字段，`h?` 匹配 h 加一个字符，
  `[hs]e` 匹配 he/se，`[!h]e` 匹配非 h 字符加 e，`*鹤` 匹配以“鹤”结尾的字词。
  `?` 按 Unicode 字符计数；不经过 shell，不执行命令。用 `[*]` 匹配字面星号。
- 普通查询中，字段完全匹配优先，然后按字词频降序。
  glob 查询按字词频降序。相同权重用字词 Unicode 顺序稳定排序。
- 单字使用随配置固定版本的 `cn_dicts/8105.dict.yaml` 字频，多音字取最大值；
  词语使用 `cn_dicts/base.dict.yaml` 词频，并保留码表中更高的显式权重。
  缺失频率用 0。这是词库权重，不是个人输入历史。
- 每次启动读取当前本地用户词库；修改后重新打开查询窗口即可。
  最多显示排序后的 200 条，底部显示匹配总数。可以继续输入缩小范围。
  空查询显示高频条目，查不到时显示 0 条，回车不会复制查询文字。

## 实现与维护

DMS 前端是独立仓库 [dms-xhup](https://github.com/lihaoze123/dms-xhup)，实现与字根图转写说明见其 README。
[default.nix](../default.nix) 用 `serviceArgs` 传入 rime-crane 数据目录、本仓库词库目录和
预期的 librime 插件；在 DMS 插件设置中填写的目录会覆盖这些参数，因此这里应保持留空。
升级插件：`nix flake update dms-xhup`。

[xhup-lookup.py](../scripts/xhup-lookup.py) 加载词库并保持运行。私有的 wofi 构建通过
[wofi-live.patch](../patches/wofi-live.patch) 增加实时 dmenu 通道：约每 60 ms 检查输入变化，
用继承的 Unix socket 发送查询，以请求序号丢弃过期响应。
查询字段和响应以 Base64 分帧，不经过 shell。只为最多 200 条结果创建 GTK 控件。
普通启动器、剪贴板菜单仍使用未修改的 wofi。

升级 nixpkgs/wofi 后需要验证补丁仍能应用，并检查实时输入、空结果、Esc、选择复制。
[test-xhup-lookup.py](../tests/test-xhup-lookup.py) 用 Python + PyYAML 运行，覆盖前缀、glob、排序、
本地词库覆盖、结果截断和多轮通道通信。

命令行查询可用于检查实际词库，例如：

```bash
xhup-lookup --query he
xhup-lookup --query '*鹤'
```
