# VPS 私有 Git 服务：Forgejo

配置位于 [hosts/vps/forgejo.nix](../hosts/vps/forgejo.nix)，由 NixOS 原生 `services.forgejo` 管理，使用锁定 Nixpkgs 中的默认 LTS 软件包。访问地址为 **https://git.chumeng.xyz**，域名必须先解析至 VPS；HTTPS 沿用现有 Nginx 与 ACME 配置。

## 访问与账号

关闭公开注册和 OpenID 登录、注册，要求登录后访问，新建仓库默认私有。该设置控制账号和仓库访问，服务地址仍可从公网连接。尚未配置邮件发送和 CI runner，Actions 暂时关闭。

本次部署创建管理员 `chumeng`，随机初始密码加密保存在 `secrets/forgejo-admin-password.age`，收件人沿用 VPS、laptop 与 class-user。持有对应私钥时，在仓库根目录执行以下命令查看（会把初始密码显示到当前终端）：

```bash
ragenix --rules secrets/secrets.nix -e secrets/forgejo-admin-password.age --editor cat
```

首次登录必须修改密码。该加密文件仅记录初始密码，网页改密后不会同步，也不会在重部署时重置密码。不要把解密输出写入日志或提交到仓库。

新实例尚无管理员时，可通过 SSH 登录 VPS，以 `forgejo` 系统用户手动创建：

```bash
sudo -u forgejo forgejo \
  --work-path /var/lib/forgejo \
  --config /var/lib/forgejo/custom/conf/app.ini \
  admin user create \
  --username chumeng \
  --email 2595248810@qq.com \
  --admin --random-password --random-password-length 32 --must-change-password
```

命令会在当前终端显示随机初始密码，首次登录必须修改。只在账号不存在时运行，不要把密码写入命令、仓库或日志；重新部署不会重置账号。其他账号由管理员创建。参数见 [Forgejo CLI 文档](https://forgejo.org/docs/latest/admin/command-line/)。

本次部署已将 [VPS 授权公钥](../hosts/vps/authorized_keys) 中的两把个人公钥添加到管理员账号；新增设备时在账号设置中添加 SSH 公钥。Git SSH 复用系统 OpenSSH 的 TCP 22，连接用户为 **`forgejo`**，不是 VPS 管理用户 `chumeng`；网页账号仍为 `chumeng`。Forgejo 根据添加到网页账号的公钥控制仓库权限，后续修改 VPS 的授权密钥不会自动同步至 Forgejo。

```bash
ssh -T forgejo@git.chumeng.xyz
```

先在网页创建私有仓库，再为已有 Jujutsu 仓库添加远端：

```bash
# 将 <repo> 替换为实际仓库名；forgejo 是本地远端名称。
jj git remote add forgejo 'ssh://forgejo@git.chumeng.xyz/chumeng/<repo>.git'
jj git push --remote forgejo --bookmark main
```

也支持 HTTPS 推拉；启用双因素认证后使用个人访问令牌。Git LFS 已启用，Nginx 单次请求体上限为 1 GiB。

## 数据与备份

状态目录为 `/var/lib/forgejo`，包含 `repositories/`、SQLite 数据库 `data/forgejo.db`、LFS 对象 `data/lfs/`、账号 SSH 公钥和 `custom/conf/` 中的运行配置与密钥。NixOS 模块在首次启动时生成应用密钥，随后持久保存；运行配置包含密钥，不能提交到仓库。

`forgejo-dump.timer` 每天 04:31 触发本机备份，写入 `/var/lib/forgejo/dump/`，格式为 `tar.gz`，由 tmpfiles 按 14 天清理。备份仍在同一块磁盘，应另行复制到异机。在线 dump 不保证并发写入期间各部分完全一致；重要升级或迁移前暂停写入，并在停服后备份整个状态目录。恢复应先在隔离环境验证；系统配置回滚不会回滚数据库或仓库数据。参见 [备份与恢复文档](https://forgejo.org/docs/latest/admin/backup-restore/)。

## 检查与更新

HTTP 服务仅监听 `127.0.0.1:3000`，公网经 Nginx 的 443 访问；80 用于 HTTPS 跳转和 ACME 验证。无需新增防火墙端口。

```bash
systemctl status forgejo nginx --no-pager
sudo journalctl -u forgejo -n 100 --no-pager
systemctl list-timers forgejo-dump.timer
systemctl --failed
curl --fail https://git.chumeng.xyz/user/login
```

按 [VPS 更新流程](vps-installation.md#后续更新) 先构建、预览，再激活。部署后需核对证书、注册关闭和匿名访问限制，并用临时私有仓库验证 SSH 推送与拉取、未授权密钥拒绝访问，以及服务重启后数据保留。

2026-10-17 已完成选项求值、远端构建、激活预览与正式部署。Forgejo LTS 15.0.9 登录页 HTTPS 返回 200，证书校验通过，HTTP 跳转为 301；注册页面显示注册关闭。临时私有仓库通过 Jujutsu SSH 推送、克隆及字节比对；匿名 API 返回 403、匿名 Git HTTP 返回 401，未登记 SSH 密钥被拒绝。服务重启后仓库、文件与应用密钥均保留；手动 dump 成功，每日计时器正常。测试账号和仓库已清理，Cloudreve 与 wastebin HTTPS 均为 200，失败服务为 0，无需重启 VPS。Cloudflare 已添加 DNS-only A 记录，公共解析指向 VPS；本机 NSS 曾保留旧的不存在结果，HTTPS 校验使用 `curl --resolve` 指向公共 DNS 返回的地址。
