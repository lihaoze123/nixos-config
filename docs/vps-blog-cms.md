# Hexo 博客管理与私密预览

本配置准备了 Sveltia CMS 的 VPS 静态托管和 PR 预览接收端；**尚未部署上线**。
CMS 与 GitHub Actions 的源码位于独立仓库
[lihaoze123/hexo-blog](https://github.com/lihaoze123/hexo-blog)，本地检出路径为
`/home/chumeng/src/hexo-blog`。正式博客继续由公开产物仓库
`lihaoze123/lihaoze123.github.io` 的 `main:/` 发布到 `https://chumeng.xyz`。

## 地址与数据流

| 地址 | 用途 |
| --- | --- |
| `https://cms.chumeng.xyz` | Sveltia CMS；GitHub OAuth 登录，直接读写私有源码 |
| `https://auth.chumeng.xyz` | 自有 Cloudflare Worker；只处理 GitHub 授权回调 |
| `https://preview.chumeng.xyz/pr-<编号>/` | 真实 Pandoc / Fluid / MathJax 预览；全站密码验证 |
| `https://chumeng.xyz` | 正式博客；继续使用现有 GitHub Pages |

CMS 保存文章或关于页时建立草稿分支和 PR。Actions 在该分支上运行真实 Hexo 构建，
上传静态预览，并在 PR head commit 上回报 `hexo-preview` 状态与预览 URL。
在 CMS 点击发布会合并 PR，`main` 的 workflow 随后构建正式站、推送产物仓库并更新 CMS。
关闭或合并 PR 会删除对应预览。首期不做定时发布。

预览使用独立域名和 `/pr-N/` 前缀；构建程序为主题、正文图片、链接、CSS 资源补齐前缀，
不改变正式站地址、文章文件名和正文中的原始 URL。预览的根页面、资源及错误响应设置
禁止缓存、禁止搜索引擎索引和禁止传递 Referer；访问正文和资源均须输入密码。

## VPS 配置

[blog-cms.nix](../hosts/vps/blog-cms.nix) 创建 `blog-upload` 系统账号及 `/srv/blog`。
它没有 sudo 权限；唯一部署公钥受 OpenSSH `restrict` 与强制命令约束，
只能提交 CMS/预览静态归档或删除指定 PR 的预览，不能执行任意 shell、SCP 或端口转发。

[blog-upload.py](../hosts/vps/blog-upload.py) 校验命令、PR 编号、工作流顺序号和 SHA，
拒绝路径穿越、绝对路径、链接、设备文件、重复文件和超限归档。
归档须包含 `index.html`；上传完整解包成功后才原子切换 `current`。
新任务完成或 PR 清理后，较旧任务不能覆盖或恢复预览。上传上限为解包内容 256 MiB、
20000 个归档条目；每次更新只保留当前静态版本。

| 路径 | 内容 |
| --- | --- |
| `/srv/blog/cms/current` | 当前 CMS；首次成功运行发布 workflow 后才存在 |
| `/srv/blog/previews/pr-N/current` | 当前 PR 的预览 |
| `/srv/blog/state` | 发布顺序与清理记录，不由 Nginx 提供 |
| `/srv/blog/staging` | 接收中的临时目录，由 tmpfiles 清理超过一天的遗留目录 |

## 凭据

`secrets/blog-preview-htpasswd.age` 是 Nginx 使用的密码哈希；运行时路径为
`/run/agenix/blog-preview-htpasswd`，仅 Nginx 可读。
`secrets/blog-cms-credentials.age` 保存预览密码及两把独立部署私钥，仅作为加密备份，
不会挂载到 VPS 服务；收件人沿用 VPS、laptop、class-user。

| 凭据/公钥 | 用途 |
| --- | --- |
| `blog_upload_private_key` | GitHub Actions → VPS 受限接收端；对应 `hosts/vps/blog-upload.pub` |
| `pages_deploy_private_key` | 源码仓库 Actions → 公开产物仓库；对应博客仓库 `deploy/pages.pub` |
| `preview_username` / `preview_password` | 浏览器访问草稿预览 |
| `github_oauth_client_id` / `github_oauth_client_secret` | Cloudflare Worker Secret；仅以加密形式备份，不写入前端 |

默认 `GITHUB_TOKEN` 只限源码仓库，不能代替跨仓库发布凭据。公开产物仓库使用单独可写
deploy key，不给 CMS 登录令牌承担部署职责。轮换任一 SSH key 时，需同时更新对应公钥、
Actions Secret 和加密备份；轮换预览密码时同步更新加密密码哈希与备份。

## 上线顺序

以下包含构建、部署与外部配置操作，**仅在用户明确授权后执行**。

1. 将两个仓库的改动审核并推送到对应主分支。博客 workflow 默认只验证与构建；
   只有 Actions Variable `BLOG_DEPLOY_ENABLED=true` 才上传、发布或清理。
2. Cloudflare 为 `cms.chumeng.xyz`、`preview.chumeng.xyz` 添加指向 VPS 的 DNS-only A 记录，
   VPS 的公网 IPv6 已核实可用时再添加 AAAA。`auth.chumeng.xyz` 交给 Worker Custom Domain，
   不把该域名解析至 VPS。
3. 在自己的 GitHub 账号创建 OAuth App：Homepage URL 为 `https://cms.chumeng.xyz`，
   callback 为 `https://auth.chumeng.xyz/callback`。将 Client ID / Secret 作为
   `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` 配置到自有 Cloudflare Worker，
   使用博客仓库 `cms-auth/wrangler.toml` 部署官方固定版本的回调程序。
   域名限制必须保持精确的 `ALLOWED_DOMAINS=cms.chumeng.xyz`，不启用 `workflow` scope。
   私有仓库 OAuth 的 `repo` scope 不能限定为单个仓库，这项取舍已确认。
4. 按 [VPS 更新流程](vps-installation.md#后续更新) 先构建和激活预览，再正式部署。
   CMS 初始返回 404 属正常现象，直到第一次发布静态 CMS。
5. 在公开产物仓库安装博客仓库的 `deploy/pages.pub`，仅对该仓库开启写入：

   ```bash
   gh repo deploy-key add deploy/pages.pub --repo lihaoze123/lihaoze123.github.io \
     --allow-write --title hexo-blog-publish
   ```

6. 在私有源码仓库配置 Actions：

   | 类型 | 名称 | 值 |
   | --- | --- | --- |
   | Variable | `BLOG_VPS_HOST` | VPS 的实际地址或稳定主机名，SSH 端口为 22 |
   | Secret | `BLOG_UPLOAD_KEY` | 加密备份中的 `blog_upload_private_key` |
   | Secret | `PAGES_DEPLOY_KEY` | 加密备份中的 `pages_deploy_private_key` |
   | Secret | `BLOG_VPS_KNOWN_HOSTS` | 与该地址匹配、已通过可信 SSH 连接核对的 known_hosts 记录 |
   | Variable | `BLOG_DEPLOY_ENABLED` | 最后设置为 `true` |

   解密时通过管道传给 `gh secret set`，不要把私钥放进命令参数或日志。例如在本配置仓库：

   ```bash
   nix shell nixpkgs#age --command age --decrypt -i ~/.ssh/id_ed25519 \
     secrets/blog-cms-credentials.age | jq -r .blog_upload_private_key \
     | gh secret set BLOG_UPLOAD_KEY --repo lihaoze123/hexo-blog
   nix shell nixpkgs#age --command age --decrypt -i ~/.ssh/id_ed25519 \
     secrets/blog-cms-credentials.age | jq -r .pages_deploy_private_key \
     | gh secret set PAGES_DEPLOY_KEY --repo lihaoze123/hexo-blog
   ```

   不以未经核对的 `ssh-keyscan` 输出代替主机身份验证，不关闭 `StrictHostKeyChecking`。
7. 手动触发 `Hexo blog` workflow 的 `main`，检查正式博客和 CMS 均成功发布。
8. 登录 CMS，用一篇临时草稿验证下述验收项，完成后删除测试文章和附件。

## 验收与日常维护

本地轻量检查：

```bash
PYTHONDONTWRITEBYTECODE=1 python3 hosts/vps/tests/test-blog-upload.py
nix eval --raw '.#nixosConfigurations.vps.config.services.nginx.virtualHosts."cms.chumeng.xyz".root'
```

上线后须验证：OAuth 登录、文章列表、新建与修改、分类标签、关于页、编辑器上传图片、
保存后生成 PR、CMS 显示真实预览链接、公式与脚注渲染、原有文章链接保持一致。
匿名读取预览 HTML 和图片应为 401；已登录可读取，关闭 PR 后应为 404；草稿及图片不得
提前进入正式站。验证发布、旧任务拒绝覆盖、重启后的文件保留与其他既有服务健康。

CMS 使用原始 Markdown 编辑模式；编辑器即时预览只作为参考，公式和主题效果以真实站点
预览为准。全局媒体库直接写主分支，因此本站入口阻止进入该页面；图片从文章编辑器上传，
随草稿保存。此入口限制用于避免误操作，不是针对仓库写入者的权限隔离。

日常本地写作前先同步源码 `main`；避免浏览器和本地同时修改同一篇文章。
本地推送 `main` 会自动发布；未写完的文章放草稿分支/PR，或使用 Hexo 的 `source/_drafts`。
定时发布尚未启用，填写未来日期不会建立定时任务。

CMS 更新由博客仓库锁定的 `@sveltia/cms` 版本控制；Worker 另按固定上游提交更新。
VPS 只托管静态文件，无数据库或常驻 Hexo 进程；关闭 `BLOG_DEPLOY_ENABLED` 可暂停全部
自动发布，已经上线的博客和静态页面继续保留。
