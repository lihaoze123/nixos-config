# Uptime Kuma 服务监控

访问 **https://uptime.chumeng.xyz**。配置位于 [hosts/vps/uptime-kuma.nix](../hosts/vps/uptime-kuma.nix)，由 NixOS 管理系统级 Docker 容器，开机自动启动。使用 Uptime Kuma 2.5.7 的 ARM64 镜像并固定摘要。

## 登录与监控

管理员用户名为 `chumeng`，首次账号已初始化。在自己的终端查看随机初始密码：

```bash
ssh vps 'sudo cat /run/agenix/uptime-kuma-admin-password'
```

密码加密保存在 `secrets/uptime-kuma-admin-password.age`，仅授权 VPS、laptop 与 class-user 解密。网页修改密码后，初始密码备份不会自动更新；重新部署不会重置账号或监控项。

监控项在网页维护，已添加 Cloudreve、wastebin、AutoBangumi、Emby、Forgejo、Memos、LibreTV 和 Karakeep 共 8 项 HTTPS 检查。基础检查每 60 秒执行一次，失败后间隔 60 秒重试，连续失败超过两次后判定故障。当前未配置通知渠道或公开状态页；需要推送时在「设置 → 通知」中添加渠道，并为对应监控启用。

探测程序和被监控服务运行于同一台 VPS，只能反映该机器视角的可用性；整机宕机、断网和外部访问异常还需独立机器上的探测。

## 网络与数据

应用仅发布 `127.0.0.1:3001`，Nginx 提供 HTTPS 与 WebSocket 反代；Cloudflare 使用仅 DNS 模式，ACME 自动续期。应用已启用可信代理头。不挂载 Docker socket，现有站点通过 HTTP(S) 监控。

`/var/lib/uptime-kuma` 保存 SQLite 数据库、账号、监控项、历史记录和通知设置。备份时停止 `docker-uptime-kuma.service` 后复制整个目录，并备份加密密码及解密密钥；目前未配置自动异机备份。系统回滚不会恢复数据库。

## 维护

```bash
ssh vps 'systemctl status docker-uptime-kuma --no-pager'
ssh vps 'sudo journalctl -u docker-uptime-kuma -n 100 --no-pager'
curl --fail https://uptime.chumeng.xyz/
```

容器日志限制为 10 MiB × 3。升级时先备份，再显式更新镜像版本与摘要，按 [VPS 更新流程](vps-installation.md#后续更新) 先构建预览、后部署。不要删除数据库来重复初始化账号。

## 部署验证（2026-10-26）

已通过局部求值、ARM64 远端构建、激活预览和 deploy-rs 正式部署。管理员账号在公开站点启用前初始化，正式容器启动后再次通过 HTTPS WebSocket 验证登录与账号持久化，8 项监控均返回正常。HTTP 跳转 HTTPS、服务器侧 IPv6 HTTPS、证书续期定时器和开机启动检查通过。

上游：[项目与部署](https://github.com/louislam/uptime-kuma)、[Nginx 反代](https://github.com/louislam/uptime-kuma/wiki/Reverse-Proxy)。
