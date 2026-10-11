# Windows 字体

`my.features.windowsFonts.enable` 通过 `chinese-fonts-overlay` 的上游
`pkgs.windows-fonts` 安装 Windows 字体，需要同时启用 `desktop` 和 `extraFonts`。
当前 laptop、class 已开启，默认字体保持原设置。配置没有本地字体路径或来源覆盖。

各设备共用私有 R2 下载缓存。字体首次构建后可按 [缓存配置与维护](nix-cache.md)
手动上传；其他设备部署缓存配置后会自动下载同一输出。

Nix 会复用 `/nix/store` 中已经构建好的同一份字体包，普通系统 rebuild 不会重复下载
Windows ISO 或重新提取字体。首次没有缓存时，仍需要下载并解包上游指定的 ISO。
单个 `microsoftPackages` 字体包也依赖这份整套字体来源。

构建输入改变或结果被垃圾回收后，才可能需要重新构建。`flake.lock` 固定上游版本，
不要为安装字体更新依赖。系统安装后，其代际会保留字体输出；清理旧代际不会删除
仍被当前系统引用的字体输出。

如果要在安装系统前预先构建字体并保留缓存，可以在仓库根目录执行：

```bash
mkdir -p ~/.local/state
nix build --out-link ~/.local/state/windows-fonts-cache \
  .#nixosConfigurations.laptop.pkgs.windows-fonts
```

这个结果链接是 GC root，保留链接即可保护字体输出免于垃圾回收。该路径只用于缓存，
系统配置仍然依赖上游包。之后正常先构建、再激活系统。
