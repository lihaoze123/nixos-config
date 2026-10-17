# VPS Memos

访问 **https://memos.chumeng.xyz**。配置位于 [hosts/vps/memos.nix](../hosts/vps/memos.nix)，由 NixOS 原生 `services.memos` 管理，版本随锁定的 Nixpkgs（当前 0.31.0）。Cloudflare 使用仅 DNS 模式，HTTPS 由现有 Nginx 和 ACME 提供。

## 账号与访问

管理员用户名为 `chumeng`。随机初始密码加密保存在 `secrets/memos-admin-password.age`，收件人沿用 VPS、laptop 与 class-user。在仓库根目录执行以下命令查看（会把密码显示到当前终端）：

```bash
ragenix --rules secrets/secrets.nix -e secrets/memos-admin-password.age --editor cat
```

首次登录后在账号设置中修改密码。加密文件仅记录初始密码，网页改密后不会同步，重新部署也不会重置账号密码。不要把解密结果写入日志或提交。

公开注册已关闭，实例采用私有访问；其他账号由管理员创建。新增笔记默认私有。显式创建的分享链接仍可被持有链接的人访问，直至撤销或过期。访问策略与注册设置通过只读 JSON 文件加载到 Memos 专属的 `/etc/secrets` 挂载空间；修改这些策略应编辑 Nix 配置并重新部署，不能在网页中覆盖。参见 [部署配置文档](https://usememos.com/docs/configuration/deployment-configuration)。

应用只监听 `127.0.0.1:5230`，不新增公网端口；公网通过 443 访问，80 用于 HTTPS 跳转和证书验证。Nginx 单次请求上限为 32 MiB，应用内附件大小限制另行生效。

## 数据与备份

数据目录为 `/var/lib/memos/`，SQLite 数据库为 `memos_prod.db`，附件与运行状态也在该目录。服务使用独立系统用户和上游模块提供的沙箱，异常退出后自动重启。

当前未配置自动备份。重要升级前暂停写入，停止 `memos.service`，以 root 备份整个数据目录后再启动；备份包含私密笔记、附件及认证状态，应限制访问并复制到异机。在线数据库备份需使用 SQLite backup API，并单独保证附件一致性。恢复时保留目录所有权 `memos:memos`，先在隔离环境验证。NixOS 回滚不会恢复数据库，旧版本也不一定能读取升级后的数据。个人笔记可在网页设置的导出与导入功能中导出，但这不包含整个实例的账号和设置。

## 检查与更新

```bash
ssh 'chumeng@<VPS_IP>' 'systemctl status memos nginx --no-pager'
ssh 'chumeng@<VPS_IP>' 'sudo journalctl -u memos -n 100 --no-pager'
ssh 'chumeng@<VPS_IP>' 'systemctl list-timers acme-renew-memos.chumeng.xyz.timer'
ssh 'chumeng@<VPS_IP>' 'systemctl --failed'
curl --fail https://memos.chumeng.xyz/
```

按照 [VPS 更新流程](vps-installation.md#后续更新) 先构建和预览，再激活。升级时阅读 [Memos 发布说明](https://github.com/usememos/memos/releases)，遵守中间版本迁移要求；不要仅为更新该服务而更新全部 Flake 输入。

2026-10-17 已完成配置求值、远端构建、激活预览和正式部署。HTTPS 返回 200，证书校验通过，HTTP 以 301 跳转 HTTPS；管理员登录、中文 Markdown 笔记、默认私有可见性、附件上传与原文字节比对、服务重启后的账号与数据保留均通过。匿名读取笔记返回 401，匿名注册验证返回 403，测试笔记与附件已清理。ACME 自动续期计时器已启用，系统失败服务为 0，Cloudreve、wastebin 与 Forgejo HTTPS 均正常，无需重启 VPS。Google 与 Cloudflare 的公共 DNS over HTTPS 均已解析到 VPS；本机局域网 DNS 仍曾返回旧 NXDOMAIN，HTTPS 检查使用 `curl --resolve` 指向公共解析地址。若新域名暂时无法打开，应等待本地 DNS 缓存过期。
