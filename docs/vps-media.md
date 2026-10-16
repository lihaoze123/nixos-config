# VPS 自动追番与 Emby

配置位于 [hosts/vps/media.nix](../hosts/vps/media.nix)，由 NixOS 管理系统级 Docker 容器，重启后自动启动。镜像固定摘要，升级时显式修改版本及摘要，再按 [VPS 部署流程](vps-installation.md#后续更新) 构建预览和部署。

| 服务 | 访问入口 | 版本 |
| --- | --- | --- |
| AutoBangumi | https://ab.chumeng.xyz | 3.3.6 |
| Emby | https://emby.chumeng.xyz | 4.10.0.40，官方 ARM64 镜像 |
| qBittorrent | SSH 隧道，见下文 | 5.2.4，LinuxServer 镜像 |

## 账号与订阅

三个服务的初始用户名均为 `admin`，密码各自随机生成。凭据通过 ragenix 加密在 `secrets/media-credentials.age`，只授权 VPS 及现有个人密钥解密。在自己的终端查看：

```bash
ssh chumeng@<VPS_IP> 'sudo cat /run/agenix/media-credentials'
```

该文件记录初始凭据；在网页更改密码后不会自动同步。重新部署不会重置已有账号。qBittorrent 仅在配置不存在时由 [media-seed.py](../hosts/vps/media-seed.py) 初始化，现有配置和账号始终保留。如果更改 qBittorrent 密码，还需同步修改 AutoBangumi 的下载器密码。

AutoBangumi 已连接 `qbittorrent:8080`，下载目录为 `/downloads/Bangumi`。登录 AutoBangumi 后添加自己的蜜柑聚合 RSS；选择聚合 RSS 并填写个人订阅链接。RSS 含个人 token，通过网页保存，不要写进仓库。没有 RSS 时不会下载番剧。

Emby 中的「番剧」媒体库读取 `/media/Bangumi`，对应宿主机 `/srv/media/Bangumi`。下载与重命名通过 qBittorrent 完成，Emby 只读挂载；媒体识别语言使用中文。VPS 没有配置硬件转码，优先选择客户端可直接播放的编码。

qBittorrent 默认最多同时下载 3 个任务，上传限速 2 MiB/s，分享率达到 1 或做种达到 24 小时后暂停做种。不会自动删除已下载视频；当前没有媒体存储配额或自动清理任务，需留意与系统、Cloudreve 共用的磁盘空间。

## 网络

应用端口仅发布在回环地址 `127.0.0.1:7892`、`127.0.0.1:8096` 和 `127.0.0.1:8080`。AutoBangumi 与 Emby 通过 Nginx 提供 HTTPS，支持 WebSocket / SSE；视频响应关闭代理缓冲。qBittorrent 不提供公网管理入口，BT 连接使用 TCP/UDP 51413。

两个域名应配置 A / AAAA 指向与 Cloudreve 相同的 VPS，使用 Cloudflare 仅 DNS 模式。证书由现有 ACME 自动签发和续期。

qBittorrent 管理及故障排查可使用隧道（保持 SSH 运行）：

```bash
ssh -N -L 8080:127.0.0.1:8080 \
  -L 7892:127.0.0.1:7892 -L 8096:127.0.0.1:8096 chumeng@<VPS_IP>
```

随后访问 `http://127.0.0.1:8080`、`http://127.0.0.1:7892`、`http://127.0.0.1:8096`。Emby 客户端优先填写 HTTPS 域名。

## 数据与维护

| 宿主机路径 | 内容 |
| --- | --- |
| `/var/lib/media-stack/autobangumi/config` | AutoBangumi 配置与设置完成标记 |
| `/var/lib/media-stack/autobangumi/data` | AutoBangumi 数据库和应用状态 |
| `/var/lib/media-stack/qbittorrent` | 下载器配置、任务和恢复信息 |
| `/var/lib/media-stack/emby` | Emby 数据库、账号、元数据和转码缓存 |
| `/srv/media/Bangumi` | 完成的番剧及整理后的目录 |
| `/srv/media/incomplete` | 未完成下载 |

容器使用专用 `media` 用户（UID/GID 995），配置父目录权限为 `0700`，媒体目录为 `0750`。不要递归改成其他用户。备份时应同时保留应用状态、媒体、加密凭据及可解密密钥；数据库宜停服备份。NixOS 回滚只回滚系统配置，不能恢复数据库或视频。目前没有自动异机备份。

```bash
ssh chumeng@<VPS_IP> 'systemctl status docker-autobangumi docker-qbittorrent docker-emby --no-pager'
ssh chumeng@<VPS_IP> 'sudo journalctl -u docker-autobangumi -n 100 --no-pager'
ssh chumeng@<VPS_IP> 'df -h /; systemctl --failed --no-pager'
curl --fail https://ab.chumeng.xyz/health
curl --fail https://emby.chumeng.xyz/emby/System/Info/Public
```

升级 AutoBangumi 使用 Nix 配置中的镜像版本，避免应用内在线更新产生与声明版本不同的覆盖层。三个容器日志均限制为 10 MiB × 3；数据库及媒体文件不受此限制。

## 部署验证（2026-10-16）

已通过远端构建、激活及 deploy-rs 连接确认。两个域名的 A / AAAA 记录由 `cf` CLI 创建，使用仅 DNS 模式、TTL 300 秒；HTTPS 证书及续期定时器正常，HTTP 跳转 HTTPS。外部 IPv4 访问通过，服务器侧强制 IPv4 / IPv6 访问均返回 200；本机无 IPv6 默认路由，未验证从本机到 VPS 的外部 IPv6 路径。

已验证三个账号登录、AutoBangumi 后台任务与下载器认证、Emby 番剧库，以及 HTTPS 登录 Cookie 的 Secure 属性。使用自生成的两秒视频完成扫描与 HTTPS 静态播放测试：Range 请求返回 206，响应前 1024 字节与原视频一致，测试文件已清理。媒体目录可读且挂载为只读，管理端口仅绑定回环地址，公网 HTTP 无法直接访问 7892、8096、8080。

三个容器和初始化服务已启用开机启动，并通过服务重启后的账号、配置、媒体库及 HTTPS 检查；未重启 VPS。Cloudreve 与 wastebin 健康检查正常，系统失败服务为 0，根文件系统约有 132 GiB 可用。RSS 由用户之后自行添加，本次没有订阅或下载第三方番剧内容。

上游：[AutoBangumi 部署](https://www.autobangumi.org/deploy/quick-start.html)、[下载器配置](https://www.autobangumi.org/config/downloader.html)、[Emby 官方镜像](https://hub.docker.com/r/emby/embyserver)、[LinuxServer qBittorrent](https://docs.linuxserver.io/images/docker-qbittorrent/)。
