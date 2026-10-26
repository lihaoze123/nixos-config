# 博客管理：Pages CMS

使用 **https://app.pagescms.org/** 官方托管版管理私有仓库
[lihaoze123/hexo-blog](https://github.com/lihaoze123/hexo-blog)。
`https://cms.chumeng.xyz` 仅通过原生 Nginx 配置跳转到官方入口。

## 写作与发布

1. 从最新 `main` 创建草稿分支，在 Pages CMS 选择该分支。
2. 编辑文章、分类标签、关于页；图片上传到同一草稿分支的 `source/uploads`。
3. 确认后在 GitHub 创建 PR 并合并到 `main`；合并触发自动发布。

PR 只检查 Hexo 构建，不再提供自建真实主题预览。正式博客继续使用
`https://chumeng.xyz`，生成产物仍在 `lihaoze123/lihaoze123.github.io` 的 `main` 分支。
直接编辑 `main` 会立即触发发布，未完成的正文与图片应始终保存在草稿分支。

## 维护范围

- 博客仓库只维护 `.pages.yml`、Hexo 配置和一个标准 GitHub Actions 工作流。
- 正文使用 Pages CMS 原生 Markdown 代码编辑器；未列出的 frontmatter 字段合并保留。
- 发布使用现成 `peaceiris/actions-gh-pages`，无需自写上传、路径改写或发布脚本。
- GitHub App 由 Pages CMS 官方管理，安装时只授权 `hexo-blog` 仓库。
- VPS 不运行 CMS、OAuth 回调、预览或上传服务，不保存 CMS 数据。

发布只需要 Actions Secret `PAGES_DEPLOY_KEY`，对应公钥保存在博客仓库的
`deploy/pages.pub`，仅能写公开产物仓库。其私钥加密备份为
`secrets/blog-pages-deploy-key.age`，仅授权 laptop 与 class-user 解密；不挂载到 VPS。
需要恢复或轮换时，通过 stdin 将解密结果交给 `gh secret set`，不把私钥放进命令参数。

旧 Sveltia、认证 Worker、受限上传账号和私密预览配置均已移除；不保留兼容脚本或激活钩子。
旧 GitHub OAuth 应用 `Hexo CMS` 不再使用，可在 GitHub Developer settings 删除。
