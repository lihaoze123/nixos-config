# Karakeep 收藏与稍后阅读

访问 **https://keep.chumeng.xyz**。配置位于 [hosts/vps/karakeep.nix](../hosts/vps/karakeep.nix)，由 NixOS 管理系统级 Docker 容器，开机自动启动。Karakeep 0.34.1、上游浏览器镜像和 Meilisearch 1.41.0 均固定镜像摘要，支持 ARM64。

## 登录与使用

管理员显示名为 `chumeng`，登录邮箱为 `2595248810@qq.com`。首次账号已初始化，公开注册关闭。在自己的终端查看随机初始密码：

```bash
ssh vps 'sudo cat /run/agenix/karakeep-admin-password'
```

密码加密保存在 `secrets/karakeep-admin-password.age`，会话签名和搜索密钥保存在 `secrets/karakeep-env.age`，仅授权 VPS、laptop 与 class-user 解密。网页修改账号密码后，初始密码备份不会自动更新；重新部署也不会重置已有账号。

可以直接添加链接、笔记、图片和 PDF，也可安装上游浏览器扩展或手机客户端，服务地址填写上述 HTTPS 域名。已配置 Chromium 抓取、截图与 Meilisearch 全文搜索；启用完整网页归档，每份归档上限 25 MiB，附件上传沿用应用默认的 50 MB 上限。尚未配置 AI 提供商，自动标签与摘要需要另行设置 API 凭据。

## 网络与数据

Nginx 将 HTTPS 反代到 `127.0.0.1:3080`，Cloudflare 使用仅 DNS 模式，证书由 ACME 自动续期。浏览器调试端口和 Meilisearch 仅在专用 Docker 网络 `karakeep` 内访问，不发布宿主机端口。

| 宿主机路径 | 内容 |
| --- | --- |
| `/var/lib/karakeep/data` | SQLite 数据库、账号、收藏、附件与网页归档 |
| `/var/lib/karakeep/meilisearch` | 全文搜索索引 |

升级前备份应用数据、加密凭据与解密所需密钥；数据库宜停服备份。目前未配置自动异机备份。Meilisearch 升级可能需要单独迁移索引，不能直接替换大版本镜像；参见[上游升级说明](https://github.com/karakeep-app/karakeep/blob/v0.34.1/docs/docs/06-administration/10-meilisearch-upgrade.md)。系统回滚不会恢复数据库。

## 维护

```bash
ssh vps 'systemctl status docker-karakeep docker-karakeep-chrome docker-karakeep-meilisearch --no-pager'
ssh vps 'sudo journalctl -u docker-karakeep -n 100 --no-pager'
curl --fail https://keep.chumeng.xyz/api/health
```

容器日志限制为每个 10 MiB × 3，收藏和归档不受此限制。升级时显式修改镜像版本与摘要，再按 [VPS 更新流程](vps-installation.md#后续更新) 先构建预览、后部署，无需更新全部 Flake 输入。新增实例的账号初始化属于一次性操作，不在共享模块中添加初始化或密码重置钩子。

## 部署验证（2026-10-26）

已通过局部配置求值、ARM64 远端构建、激活预览和 deploy-rs 正式部署。HTTPS 登录、管理员权限、Secure 会话 Cookie、关闭公开注册和全文搜索均通过。使用临时链接验证 Chromium 抓取、网页标题、截图和完整网页归档，测试收藏已删除。Karakeep 的三个容器均已启用开机启动，凭据权限为 root `0400`；服务器侧 IPv6 HTTPS 检查通过，系统失败服务为 0，未重启 VPS。

上游：[Docker 部署](https://github.com/karakeep-app/karakeep/blob/v0.34.1/docs/docs/02-installation/01-docker.md)、[环境变量](https://github.com/karakeep-app/karakeep/blob/v0.34.1/docs/docs/03-configuration/01-environment-variables.md)。
