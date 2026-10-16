# VPS wastebin

访问 **https://paste.chumeng.xyz**。配置位于 [hosts/vps/wastebin.nix](../hosts/vps/wastebin.nix)，通过 NixOS 原生 `services.wastebin` 运行，版本随仓库锁定的 Nixpkgs（当前 3.8.0）。

## 服务与网络

- `wastebin.service` 开机启动，异常退出后自动重启，使用动态用户与上游 NixOS 模块的服务沙箱。
- 应用仅监听 `127.0.0.1:8088`，经现有 Nginx 提供 HTTPS；HTTP 自动跳转 HTTPS，Let's Encrypt 自动续期。
- Cloudflare A / AAAA 记录指向与 Cloudreve 相同的 VPS，使用仅 DNS 模式，TTL 300 秒。
- 沿用 TCP 22、80、443 的防火墙配置，无需公开 8088。
- 请求体最大 1 MiB（包含 JSON 编码开销）。每个来源 IP 每秒平均 10 个请求，允许突发 40 个；POST / DELETE 每分钟平均 10 个，允许突发 5 个；最多 20 个并发连接，超限返回 429。

这是允许匿名发布的文本分享服务，无账号或管理员登录。可通过页面选择有效期、阅后即焚和密码；发布后应保存链接。创建者删除权限依赖浏览器 Cookie；清除 Cookie 后不能直接删除原内容。应用能力见 [wastebin 3.8.0 文档](https://github.com/matze/wastebin/blob/3.8.0/README.md)。

## 数据与密钥

SQLite 数据库位于 `/var/lib/wastebin/sqlite3.db`；systemd 的动态用户机制将实际目录放在 `/var/lib/private/wastebin`，通过前述路径访问，目录权限为 `0700`。NixOS 回滚不恢复数据库。

Cookie 签名密钥与密码盐由安全随机数生成，遵循现有 ragenix 规则加密保存在 `secrets/wastebin-env.age`，仅授权 VPS 主机及现有个人密钥解密；运行时为 `/run/agenix/wastebin-env`，权限 `0400`。稳定签名密钥使创建者删除权限在重启后继续有效。不要随意替换盐，否则已有密码保护内容可能无法解密。

备份时同时保留数据库、加密密钥文件及解密所需的 SSH 密钥。可在停服后由 root 复制整个数据目录，再启动服务；在线备份应使用 SQLite backup API。当前未配置自动异机备份。

## 检查与更新

```bash
ssh vps 'systemctl status wastebin nginx --no-pager'
ssh vps 'sudo journalctl -u wastebin -n 100 --no-pager'
curl --fail https://paste.chumeng.xyz/
ssh vps 'systemctl list-timers acme-renew-paste.chumeng.xyz.timer'
ssh vps 'systemctl --failed'
```

更新配置后按 [VPS 更新流程](vps-installation.md#后续更新) 先构建预览，再正式部署。软件版本跟随 `flake.lock`，无需单独下载二进制。

2026-10-16 已完成远端构建、激活预览和正式部署。公网 IPv4 / IPv6 HTTPS 均返回 200，证书校验通过，HTTP 返回 301；发布、中文原文比对、Markdown 渲染、密码保护、阅后即焚、1 MiB 请求体限制和写入限流均通过。服务重启后内容与创建者删除权限仍有效；测试内容已清理。Cloudreve 健康检查正常，系统失败服务为 0，无需重启 VPS。
