# My Personal Blog

这是一个使用 Hugo 和 PaperMod 主题构建的个人博客。它包括以下功能：

- 多语言支持（英文和中文）
- 带有标签和分类的博客文章
- 项目展示
- 关于页面
- 搜索功能
- 暗/亮模式切换
- 响应式设计
- 画廊功能

## 本地运行

### 前提条件

- Hugo（扩展版）v0.80.0 或更高版本

### 本地启动

```bash
# 克隆仓库
git clone <repository-url>
cd my-blog

# 启动Hugo服务器
hugo server -D
```

网站将在 http://localhost:1313/ 可用

## 添加内容

### 创建新文章

```bash
# 英文文章
hugo new content/en/posts/my-new-post.md

# 中文文章
hugo new content/zh/posts/my-new-post.md
```

## 部署到 GitHub Pages

### 手动部署

```bash
# 给deploy.sh添加执行权限
chmod +x deploy.sh

# 运行部署脚本
./deploy.sh "提交信息"
```

### 自动部署

本仓库配置了 GitHub Actions，当你推送到 main 分支时，它会自动构建并部署网站到 GitHub Pages。

## 自定义域名

本网站配置为使用 www.yss520.online 作为自定义域名。如果你想使用不同的域名，请修改以下文件：

1. `hugo.yaml` 中的 `baseURL`
2. `.github/workflows/hugo.yml` 中的 CNAME 设置
3. `deploy.sh` 中的 CNAME 设置

## 许可证

MIT
