# 私有 Attic 缓存

私有二进制缓存部署在甲骨文 VPS，由 [hosts/vps/attic.nix](../hosts/vps/attic.nix)
通过 NixOS 原生 `services.atticd` 管理。API 为 `https://cache.chumeng.xyz/`，
缓存地址为 `https://cache.chumeng.xyz/nur`。Cloudflare 仅提供 DNS，HTTPS 由 VPS 的
Nginx 与 ACME 管理，上传和响应均不缓冲到 Nginx 临时文件。

缓存保持私有；上传权限与下载权限分开。签名私钥由 Attic 保存在服务端数据库中，
客户端和 CI 不持有缓存签名私钥，也不需要 S3 凭据。

## 凭据放在哪里

| 用途 | 仓库密文 / GitHub Secret | 运行时位置与权限 |
| --- | --- | --- |
| 服务端 JWT 签名 | `secrets/attic-server-env.age` | VPS `/run/agenix/attic-server-env`，root `0400` |
| 个人设备只读下载 | `secrets/attic-netrc.age` | `/run/agenix/attic-netrc`，root `0400`，由 Nix daemon 的 `netrc-file` 读取 |
| 个人手动上传 | `secrets/attic-upload-token.age` | Home Manager 解密到用户运行目录，`~/.local/share/attic/token` 仅是指向它的链接 |
| CI 读取与上传 | GitHub Secret `ATTIC_TOKEN` | 临时权限 `0600` 文件，任务结束后清理 |

个人设备 token 与 CI token 仅针对 `nur`，没有创建、管理或删除缓存的权限。
当前 token 有效期为两年，轮换时只替换对应凭据，不更换服务端 JWT 密钥。
更换服务端 JWT 密钥会使全部旧 token 失效；更换缓存签名密钥则需要同步更新客户端公钥。
凭据加密收件人规则见 [secrets/secrets.nix](../secrets/secrets.nix)，私钥不进入仓库或 Nix store。

当前缓存公钥由 NUR `lib/cache-config.nix` 维护：

```text
nur:dJh05Op2+iv3GCHoaF2+1FfQtqcUZzf/4v/ZTaLHomY=
```

## 下载与上传

laptop、home、class、base 默认启用官方缓存、清华镜像、已有公开项目缓存和私有 Attic。
共享系统模块统一声明下载源、公钥和 daemon 的只读 netrc；Home Manager 不再覆盖下载源。
普通 `nix build`、`nix develop` 和系统构建命令会直接查询配置中的缓存，无需包装命令或缓存组。
长期使用的软件仍声明在 NixOS / Home Manager 中；`nix profile` 仅用于临时试用。

例如构建单个 NUR 包：

```bash
nix build github:lihaoze123/nur-packages#dbx
```

系统重建沿用现有流程，只有明确准备构建或部署时才执行，不需要额外传入缓存参数。
缓存命中要求 store path 一致，各设备应尽量使用相同依赖锁定版本。

`vps` 与 installer 使用 public 策略，不解密个人设备下载或上传 token。
其他设备首次应用本次变更后，Nix daemon 的 netrc 路径和 Home Manager 的客户端配置才生效。
新增设备需将解密公钥加入 ragenix 收件人规则，并为它配置正确的身份路径。

Home Manager 安装 `attic` 并声明 `~/.config/attic/config.toml`，其中只包含服务端地址
和 `token-file` 路径，不包含明文 token；无需执行 `attic login` 或 `attic use` 改写配置。
上传本机已构建结果：

```bash
attic cache info personal:nur
attic push personal:nur /nix/store/替换为实际输出路径
```

Attic 默认连同依赖闭包上传，并跳过已有官方缓存签名的路径；其他机器继续从官方缓存
获取这些公共依赖。缓存命中要求输出路径一致，主机架构和依赖版本仍会影响命中。
ARM VPS 可以保存、分发 x86_64 输出，不能因此替代 x86_64 原生构建机。

## CI

NUR CI 的求值、构建目标保持原有范围；读取和上传改用 Attic。
`ATTIC_TOKEN` 允许 pull/push `nur`，没有缓存管理或删除权限。
上传脚本为 NUR 的 `scripts/cache-attic.sh`，它使用 token 文件运行 `attic push`，
不再导出暂存二进制缓存、不运行 rclone，也不向 CI 分发缓存签名私钥。
旧对象存储上传脚本、凭据和 CI 配置已移除。

## 服务与清理

- 服务：`atticd.service`；只监听 `127.0.0.1:8085`，外部经 HTTPS 访问。
- 状态：`/var/lib/atticd/server.db`（SQLite，包含缓存签名密钥）与 `/var/lib/atticd/storage`。
- 压缩：zstd，级别 3；1 MiB 起分块，最小 256 KiB、平均 1 MiB、最大 4 MiB。
  相比模块默认的平均 64 KiB，减少大包的小文件与数据库写入。已有分块仍可读取，
  但切换后新旧分块的边界不同，过渡期间分块复用率会降低。
- 数据库：服务每次启动运行 SQLite `PRAGMA optimize`，维护查询统计，避免分块去重查询误选索引。
- 回收：每 12 小时检查，未访问 90 天的路径可被回收。保留时间不是磁盘容量硬限制，
  缓存和网盘/媒体共用根分区，需要检查 `df -h /`。

只读维护：

```bash
ssh chumeng@<VPS_IP> 'systemctl status atticd nginx --no-pager'
ssh chumeng@<VPS_IP> 'sudo journalctl -u atticd -n 100 --no-pager'
ssh chumeng@<VPS_IP> 'sudo du -shL /var/lib/atticd; df -h /'
```

管理 token 可在 VPS 上通过 `sudo atticd-atticadm make-token` 按需生成，限定缓存与有效期；
不要将生成结果贴到日志、仓库或截图。只读 token 无法执行缓存管理，管理操作需要另行授权。
完整备份必须包含数据库一致快照、storage 目录及加密 JWT 凭据，不能只备份 age 文件。
更新服务仍按 [VPS 部署流程](vps-installation.md#后续更新) 先构建预览，再激活。

## 迁移记录

2026-10-16 从原对象存储迁入 1095 个可查询路径，并从官方缓存补齐依赖。
完整闭包共 1483 个路径，由 Attic 重新签名；旧缓存不再是运行依赖。
全部 1483 个闭包路径均可在 Attic 查询，签名校验通过；原始 1095 个路径的
NarHash、NarSize、References 与迁移结果逐项一致，差异为 0。Windows 字体和
VType harness 已从 HTTPS 缓存下载至隔离 store，并通过内容及签名校验。

初次批量入库发现 SQLite 缺少统计信息，去重查询误选 `idx-chunk-state-holders`，
导致大量扫描。补齐统计后确认使用 `idx-chunk-chunk-hash`，导入完成；服务启动时
维护统计，并将新上传平均分块从 64 KiB 调为 1 MiB。切换后本机实际上传一个约
12.3 MiB 的 Attic 客户端输出耗时 6.48 秒（含准备与请求），此小样本不代表所有网络或大包速度。
NUR CI 的求值、构建、检查及 Attic 上传均成功。

已通过 Cloudflare CLI 的后台清空任务删除原 `nix-cache` 全部 2503 个对象，
再删除空桶；最终桶列表仅保留 `hhacm-notebook`。原桶约 3.38 GiB 的存储占用已释放。
旧上传脚本、配置、密文、GitHub Secrets/variable 及 VPS 迁移快照、临时 token、
临时 GC roots 均已清理。个人桌面设备尚未激活本次客户端配置，下次重建后生效。

参考：[Attic 官方使用说明](https://docs.attic.rs/tutorial.html)。
