# VPS LibreTV

访问 **https://tv.chumeng.xyz**。配置位于 [hosts/vps/libretv.nix](../hosts/vps/libretv.nix)，由 NixOS 管理系统级 Docker 容器，开机自动启动。使用上游 LibreTV 2.21.0 的 ARM64 镜像并固定摘要；Cloudflare 使用仅 DNS 模式，Nginx 和 ACME 提供 HTTPS。

## 访问密码

站点使用一个共享访问密码，随机密码与独立的会话签名密钥通过 ragenix 加密保存在 `secrets/libretv-env.age`，只授权 VPS、laptop 和 class-user 解密。在自己的终端查看密码：

```bash
ssh 'chumeng@<VPS_IP>' 'sudo sed -n "s/^PASSWORD=//p" /run/agenix/libretv-env'
```

更改密码时使用 `ragenix --rules secrets/secrets.nix -e secrets/libretv-env.age` 编辑 `PASSWORD`，然后重新部署。需要让已有会话失效时同时重新生成 `PROXY_SECRET`；不要把明文写入仓库或日志。

## 数据源与浏览器数据

应用不预置点播源或直播订阅。首次登录后，在「设置 → 源管理」添加自己使用的数据源或订阅地址；点播源使用 Apple CMS API，直播源使用 M3U。需要让所有浏览器首次访问时自动导入，可在 Nix 容器环境中声明上游支持的 `DEFAULT_SOURCES`、`DEFAULT_LIVE_SOURCES` 或 `DEFAULT_SUBSCRIPTIONS`。含私人 token 的地址应放在加密环境文件中。

LibreTV 是无状态服务，无需数据库或持久卷。观看历史与进度存储在当前浏览器 IndexedDB，设置和源信息保存在浏览器本地；更换浏览器不会自动同步，清除站点数据会丢失这些记录，需要时先使用应用的导出功能。

## 网络与维护

容器端口仅发布到 `127.0.0.1:8081`，公网通过现有 443 端口访问，80 用于 HTTPS 跳转和证书签发。视频代理关闭缓冲并允许长连接，登录 Cookie 强制启用 Secure。容器使用上游非 root 用户，日志限制为 10 MiB × 3。

```bash
ssh 'chumeng@<VPS_IP>' 'systemctl status docker-libretv nginx --no-pager'
ssh 'chumeng@<VPS_IP>' 'sudo journalctl -u docker-libretv -n 100 --no-pager'
ssh 'chumeng@<VPS_IP>' 'systemctl list-timers acme-renew-tv.chumeng.xyz.timer'
curl --fail https://tv.chumeng.xyz/api/status
```

升级时核对 [上游发布说明](https://github.com/LibreSpark/LibreTV/releases)，显式更新镜像版本和 ARM64 摘要，按照 [VPS 更新流程](vps-installation.md#后续更新) 先构建和预览，再激活；无需更新全部 Flake 输入。备份加密凭据与可解密的密钥，并按需导出浏览器数据。

## 部署验证（2026-10-26）

已通过局部配置求值、远端构建、激活预览、正式部署与 deploy-rs 连接确认。公共 DNS 的 A / AAAA 记录均已创建，HTTPS 证书校验通过，HTTP 以 301 跳转 HTTPS；外部 IPv4 与服务器侧 IPv6 状态接口均返回 2.21.0。

首页、正确密码登录、会话验证与登出均通过，错误密码和匿名搜索返回 401，登录 Cookie 包含 Secure 与 HttpOnly。容器以 `nextjs` 用户运行，端口仅绑定回环地址；容器服务和 ACME 续期计时器已启用，系统失败服务为 0。本次未重启 VPS，也未配置第三方影视源或验证源站播放。
