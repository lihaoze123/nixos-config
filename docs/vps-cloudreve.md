# VPS Cloudreve

配置位于 [hosts/vps/cloudreve.nix](../hosts/vps/cloudreve.nix)。Cloudreve 社区版通过 NixOS OCI 容器模块和系统级 Docker 运行，包含 Cloudreve 4.19.1、PostgreSQL 17 和 Redis 8；三个镜像均固定摘要，升级须显式修改配置后部署。

## 访问与账号

访问 **https://pan.chumeng.xyz**，管理员登录邮箱为 `2595248810@qq.com`。管理员已在开放公网入口前初始化，公开注册已关闭；需要新用户时可在管理面板操作。

初始密码使用 ragenix 加密保存在 `secrets/cloudreve-admin-password.age`。在自己的终端运行以下命令查看：

```bash
ssh chumeng@<VPS_IP> 'sudo cat /run/agenix/cloudreve-admin-password'
```

日后在网页里修改密码。加密文件仅记录初始密码，修改文件或重新部署不会重置现有账号。站点 URL、注册开关、存储策略等应用设置存储在数据库，通过管理面板维护。

## 服务与网络

- `docker-cloudreve.service`：应用，仅发布到 `127.0.0.1:5212`。
- `docker-cloudreve-db.service`：专用 PostgreSQL，仅在 Cloudreve 的 Docker 网络内访问，不发布端口；沿用官方 Compose 的内部网络信任认证方式。
- `docker-cloudreve-redis.service`：专用 Redis，同样不发布端口。
- `cloudreve-network.service`：创建专用 Docker 网络，数据库和 Redis 依赖此服务。
- Nginx：代理到回环 5212，支持 WebSocket，关闭上传和响应缓冲；单次请求上限 10 GiB。
- HTTPS：沿用 Let's Encrypt 证书与自动续期，HTTP 自动跳转 HTTPS。
- 防火墙：NixOS 放行 TCP 22、80、443；OCI 对本 VPS 的入站流量全放行。

Cloudflare 的 A / AAAA 记录继续指向 VPS，保持仅 DNS 模式。无需修改 DNS，也无需 SSH 隧道。镜像中包含缩略图和媒体处理工具；当前直接启动 Cloudreve 主程序，未启动 Aria2 离线下载服务，也未开放 6888 端口。

## 数据与维护

所有新数据位于 `/var/lib/cloudreve/`，父目录权限为 `0700 root:root`：

| 目录 | 用途 |
| --- | --- |
| `data/` | Cloudreve 配置、会话密钥、本地存储文件及临时文件 |
| `postgresql/` | Cloudreve 专用 PostgreSQL 数据库 |
| `redis/` | Redis 数据 |

文件归属与容器内的数据库用户保持一致，不要递归把数据库目录改为 root 所有。定期备份应用数据和一致性的 PostgreSQL 转储；NixOS 回滚不会恢复文件或数据库。当前未配置自动异机备份。

```bash
systemctl status docker-cloudreve docker-cloudreve-db docker-cloudreve-redis --no-pager
journalctl -u docker-cloudreve -n 100 --no-pager
curl --fail https://pan.chumeng.xyz/api/v4/site/ping
sudo docker exec cloudreve-db pg_isready -U cloudreve -d cloudreve
systemctl list-timers acme-renew-pan.chumeng.xyz.timer
systemctl --failed
```

升级时先备份，再修改镜像版本和摘要，通过 [VPS 更新流程](vps-installation.md#后续更新) 先构建预览、后正式部署。PostgreSQL 大版本升级需要迁移数据库，不能直接替换镜像。

## 从 Nextcloud 切换

2026-10-16 已在切换前通过维护模式备份 Nextcloud 数据和 PostgreSQL 转储，路径为：

```text
/var/backups/nextcloud-retired-20261016T022934Z/
  nextcloud-state.tar.gz
  nextcloud.dump
  database-contents.txt
  postgresql-cluster.tar.gz
  redis-nextcloud.tar.gz
```

归档及目录仅 root 可读，已验证压缩包和数据库转储可列出内容。按用户要求，Cloudreve 验证通过后已删除旧 `/var/lib/nextcloud`、`/var/lib/postgresql`、`/var/lib/redis-nextcloud` 数据目录，移除旧服务、定时任务和 Nextcloud 初始密码配置。旧系统代际保留，但若要恢复运行 Nextcloud，需要先恢复上述备份中的数据。Cloudreve 使用独立数据库和存储，旧账号、文件、分享链接没有自动导入 Cloudreve。

切换验证：公网 IPv4、IPv6 均返回 Cloudreve 4.19.1；HTTPS 前端返回 200，证书校验通过，HTTP 返回 301 跳转 HTTPS。管理员登录、管理 API、文件上传、下载内容比对和删除均通过；关闭公开注册，站点 URL 为 `https://pan.chumeng.xyz`。旧 Nextcloud 相关单元均为 `not-found/inactive`，Cloudreve 服务重启后恢复正常，失败服务为 0。

上游文档：[部署规划](https://docs.cloudreve.org/en/overview/deploy/)、[官方 Compose](https://github.com/cloudreve/docker-compose)、[反向代理与站点设置](https://docs.cloudreve.org/en/overview/deploy/configure)。
