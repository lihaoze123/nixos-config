# 快速加词：调研记录

## 已确认
- 4 份手工词库在 dictionaries/，通过 mkOutOfStoreSymlink 部署到 Rime 用户目录。
- scripts/generate-xhup-computer-dict.py 已实现双字、三字、多字词编码及词典注音优先策略。
- scripts/xhup-lookup.py 已能读取实际启用词库和本地覆盖，适合复用为查重/查编码来源。
- xhup.schema.yaml 的 enable_user_dict=false，加词应维护文本码表，不依赖 Rime 自动学习。
- Fcitx5-Rime 5.1.13 的 RimeEngine::setSubConfig("deploy", ...) 调用 deploy()；/rime D-Bus 对象没有直接 Deploy 方法。
- deploy() 释放 session、finalize 后执行 rimeStart(true)，不是简单配置重载。

## 实现验证结论
- Controller SetConfig 的 URI 和空配置 variant 已通过真实 Fcitx 隔离测试。
- 添加测试词、部署、查询真实 Rime 候选的端到端验证通过。原生桌面通知未在隔离测试中启用。

## 部署接口结论
- Fcitx 5.1.19 Controller 的 SetConfig(uri, variant) 会把 `fcitx://config/addon/rime/deploy` 分派到 Rime 的 setSubConfig("deploy", ...)。
- 已核实源码：https://raw.githubusercontent.com/fcitx/fcitx5/5.1.19/src/modules/dbus/dbusmodule.cpp ，SetConfig / addonConfigPrefix。
- 当前安装的 fcitx5-rime 5.1.13 源码：rimeengine.cpp 的 setSubConfig、deploy、rimeStart、notify。
- start_maintenance(fullcheck) 异步执行；插件通过原生通知报告 start/success/failure。调用返回不能作为完成凭据。
- 第一版由添加工具提示“已保存，已请求部署”，由 Fcitx/Rime 原生通知报告完成或失败；不伪造逐词“已生效”通知。

## 运行实例结论（仅作排查快照）
- D-Bus GetConnectionUnixProcessID 返回的实际实例属于 `app-org.fcitx.Fcitx5@autostart.service`。
- 实际实例加载的是旧的 fcitx5-rime 插件；Home Manager 的 fcitx5-daemon.service 为 inactive。
- 实现时优先以 D-Bus owner 查 PID，再对比 /proc/PID/maps 中的 Rime 插件与 Nix 注入的期望路径。
- 仅比较 fcitx5 主程序版本或 systemd 服务状态不足以判断正在使用的词库版本。
- 计划以 Home Manager 用户服务作为唯一入口，用用户级 Hidden=true desktop 覆盖禁用重复 XDG 自启动。

## 调研过程限制
- 本地 fcitx5 源码 store 路径尚未实现，改读官方 5.1.19 tag 源码。
- web 工具读取 dbushelper.cpp 失败，使用官方 raw URL 的直接读取作为补充。
- 未执行 SetConfig/Deploy、退出输入法或写入测试词；实际部署调用留待隔离集成测试。

## 交付
- implementation.md：交互、编码与重码、写入恢复、部署状态、CLI、文件改动及分阶段验收。

## 实现与验证记录（2026-09-29）

- 新增 xhup-add-word.py、xhup_common.py；编码器与查码共享最小公共逻辑。
- 各入口以真实文件复制进独立脚本目录，保证 Python sibling import 可用，并避免仅修改加词 UI 就重建词库。
- 保留既有查码 wofi 补丁；加词使用普通 wofi。
- 加词测试 20 项、查码测试 5 项通过；编码器 self-test 通过。生成的计算机词库 SHA-256 与重构前完全相同。
- 三份 niri 配置验证通过。NixOS laptop 完整构建通过；最终产物为 /nix/store/4wggb4zfnafclfngrv14yh47d2dr2k0w-nixos-system-laptop-26.05.20260515.d233902。
- 构建后的 xhup-add-word --dry-run 成功，正确输出自动编码及上游重码；没有写入真实词库。
- tests/test-xhup-rime-integration.py 在独立 dbus-run-session 与临时 HOME 中通过：SetConfig 返回请求成功，退出测试实例后 librime 确认 zzzz 的候选含“鹤词测试隔离词”。测试目录自动清理。
- Weston headless + 嵌套 niri 中，真实 wofi 完成三个弹窗并写入临时词库；Esc 流程不写入。
- 图形测试最初失败源于 wtype/niri 的动态键盘映射：新窗口收到默认映射，将虚拟键码 1 当作 Esc。每一步改变测试映射后通过，未因此修改应用取消行为。
- 未切换当前系统、未重启实际输入法、未修改真实用户词库；旧实例交接需在应用新配置后进行。
