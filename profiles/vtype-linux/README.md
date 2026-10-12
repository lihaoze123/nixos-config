# VType 独立输入法包

当前固定 PR #4 的完整 Nix 打包版本，另外应用小鹤双拼和云延迟补丁。

```sh
nix profile install .#vtype-linux
wetype-setup
wetype-check
```

已经安装过同名包时用 `nix profile upgrade vtype-linux`。
首次初始化校验并提取官方 APK。升级运行目录前先退出 Fcitx5；初始化备份旧目录，
保留预置词库和个人学习数据。旧手动插件遮蔽时使用 `wetype-setup --migrate-fcitx`。

启动 Fcitx5 后，在“微信拼音”的设置中选择“小鹤双拼”。云功能需关联官方客户端，
再执行 `wetype-cloud enable`；定时刷新可另加 `--timer`，剪贴板同步单独启用。

`运行时缺少 cloud_proxy.py` 表示尚未执行新版 `wetype-setup`，或 `WETYPE_ENGINE_DIR`
指向了旧运行目录。初始化不关联设备，不自动启用云功能或重启 Fcitx5。
