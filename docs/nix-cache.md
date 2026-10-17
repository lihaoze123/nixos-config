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

laptop、home、class、base 仅启用官方缓存、[CERNET 镜像](https://help.mirrors.cernet.edu.cn/nix-channels/)和私有 Attic。
镜像地址为 `https://mirrors.cernet.edu.cn/nix-channels/store`。
自定义包统一从私有 Attic 获取，不再启用 Codex、Niri computer-use 和 fcitx5-vinput
的项目 Cachix 下载源及其签名公钥，减少逐源查询；NUR 新增项目缓存也不会自动启用。
共享系统模块统一声明下载源、公钥和 daemon 的只读 netrc；Home Manager 不再覆盖下载源。
普通 `nix build`、`nix develop` 和系统构建命令会直接查询配置中的缓存，无需包装命令或缓存组。
长期使用的软件仍声明在 NixOS / Home Manager 中；`nix profile` 仅用于临时试用。

上游维护者于 2026-10-15 [确认缓存与构建服务器遭入侵](https://github.com/xddxdd/nix-cachyos-kernel/issues/110#issuecomment-6189203183)。
永久弃用 `https://attic.xuyh0120.win/lantian` 及 `lantian:` 签名公钥，即使服务恢复也不重新启用。
共享模块仅引用 NUR 的私有 `nur` 缓存地址和公钥，旧锁文件中的 lantian 配置不会被引入。
CachyOS 内核改由可信环境编译并上传私有 Attic；撤销缓存信任不会替换本地已安装或正在运行的内核。

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

## CachyOS 内核

保留 `nix-cachyos-kernel` 源码 input 和 `overlays.pinned`，不接受其上游缓存配置。
内核输出保存在现有私有 `nur` 缓存，不新增凭据或签名密钥。更新锁文件后，
先在可信的 x86_64 环境编译，再上传供其他设备复用；NUR 软件包 CI 不会自动构建此内核。

首次撤销上游缓存信任时，不能直接上传本地旧产物；普通构建也可能复用它们。
可在仓库根目录创建全新 chroot store，仅使用官方缓存及公钥获取工具链和公共依赖。
以下命令需要 Linux 用户命名空间；不需要 sudo，不构建完整系统，也不激活内核：

```bash
build_root=$(mktemp -d "$HOME/.cache/cachyos-build.XXXXXX")
nix build --store "local?root=$build_root" \
  '.#nixosConfigurations.laptop.config.boot.kernelPackages.kernel^*' \
  --no-update-lock-file --out-link "$build_root/result-cachyos" \
  --print-out-paths -L \
  --option build-users-group '' \
  --option sandbox true --option sandbox-fallback false \
  --option builders '' --option max-jobs 2 --option cores 12 \
  --option accept-flake-config false --option require-sigs true \
  --option substituters 'https://cache.nixos.org/' \
  --option extra-substituters '' \
  --option trusted-public-keys \
    'cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=' \
  --option extra-trusted-public-keys '' \
  > "$build_root/cachyos-paths.txt"

# 让 Attic 读取刚才的隔离 store，避免误上传系统 store 中的旧产物。
NIX_REMOTE="local?root=$build_root" \
  attic push personal:nur --stdin < "$build_root/cachyos-paths.txt"
```

云主机也应使用全新 store，仅配置官方缓存和公钥，并先核对内核 `drvPath`。
上传直接在编译机执行，避免通过本机 SSH store 中转大型产物。若编译机和 Attic
位于不同 OCI 区域，先通过临时 DRG/RPC 建立 VCN 私网互联，添加对端主机的 `/32`
路由；编译机将缓存域名解析到 Attic 的私网 IP，HTTPS 仍使用原域名并校验证书。
为临时编译机签发仅有目标缓存 push/pull 权限、短期有效的 token，以 `token-file`
方式配置客户端，不复制个人长期上传 token。随后在编译机直接执行：

```bash
attic push private:nur --stdin --jobs 4 < cachyos-paths.txt
```

空 store 下载验证也在云上执行。验证成功后移除临时 token、私网路由与 DRG/RPC，
并删除临时编译机及其引导卷，避免持续计费。

`^*` 包含 `out`、`dev` 和 `modules`，不能只上传内核镜像而漏掉模块或开发输出。
构建并发按机器资源调整；若其他主机的内核 derivation 不同，应另行构建其目标。
上传后需要从另一个空 store 实际下载并验证签名、内容与依赖闭包；仅查询 narinfo
或在已有产物的机器上构建成功，不能证明缓存完整。NVIDIA、ZFS 等外部模块属于独立产物。

2026-10-17 已在全新 OCI 东京 E6 实例（32 OCPU、64 线程、128 GB 内存）重新构建
当前 laptop/class 共用的 CachyOS BORE 7.2.8，源码 input 固定为 `b1332396df6e880d7e3b6b451c6a74132ce8cf66`。
北京时间 13:38:54 开始、13:52:39 完成，总耗时约 13 分 45 秒，主体编译阶段为 9 分钟。
三个输出已保存到现有 `nur` 缓存；切换至 OCI 跨区域私网后完成剩余上传，并从
另一个空 store 下载其 73 个路径的闭包。官方或自建签名均通过校验，NarHash、NarSize 和 References 与
远端构建结果逐项一致。三个输出的 NarHash、NarSize 也与本机原有同版本产物一致。
临时实例、引导卷、专用网络及两端 DRG/RPC 已删除，原有路由已恢复。
本次仅重新构建和缓存内核，没有构建或激活完整系统。

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
