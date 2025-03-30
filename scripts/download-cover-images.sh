#!/bin/bash

# 创建存放封面图片的目录
mkdir -p static/images/real-covers

# 下载封面图片
# 架构与性能的封面图
curl -o static/images/real-covers/architecture.jpg "https://images.unsplash.com/photo-1486551937199-baf066858de7?ixlib=rb-1.2.1&auto=format&fit=crop&w=1200&q=80"

# Vite构建优化的封面图
curl -o static/images/real-covers/vite-optimization.jpg "https://images.unsplash.com/photo-1589149098258-3e9102cd63d3?ixlib=rb-1.2.1&auto=format&fit=crop&w=1200&q=80"

# React Hooks的封面图
curl -o static/images/real-covers/react-hooks.jpg "https://images.unsplash.com/photo-1555066931-4365d14bab8c?ixlib=rb-1.2.1&auto=format&fit=crop&w=1200&q=80"

# 前端安全的封面图
curl -o static/images/real-covers/web-security.jpg "https://images.unsplash.com/photo-1550751827-4bd374c3f58b?ixlib=rb-1.2.1&auto=format&fit=crop&w=1200&q=80"

# React虚拟DOM的封面图
curl -o static/images/real-covers/virtual-dom.jpg "https://images.unsplash.com/photo-1517694712202-14dd9538aa97?ixlib=rb-1.2.1&auto=format&fit=crop&w=1200&q=80"

# React事件系统的封面图
curl -o static/images/real-covers/react-events.jpg "https://images.unsplash.com/photo-1563206767-5b18f218e8de?ixlib=rb-1.2.1&auto=format&fit=crop&w=1200&q=80"

# React服务端渲染的封面图
curl -o static/images/real-covers/react-ssr.jpg "https://images.unsplash.com/photo-1507721999472-8ed4421c4af2?ixlib=rb-1.2.1&auto=format&fit=crop&w=1200&q=80"

# React Node的封面图
curl -o static/images/real-covers/react-node.jpg "https://images.unsplash.com/photo-1535016120720-40c646be5580?ixlib=rb-1.2.1&auto=format&fit=crop&w=1200&q=80"

# 浏览器渲染的封面图
curl -o static/images/real-covers/browser-render.jpg "https://images.unsplash.com/photo-1593720213428-28a5b9e94613?ixlib=rb-1.2.1&auto=format&fit=crop&w=1200&q=80"

# 前端工程化的封面图
curl -o static/images/real-covers/frontend-engineering.jpg "https://images.unsplash.com/photo-1618401471353-b98afee0b2eb?ixlib=rb-1.2.1&auto=format&fit=crop&w=1200&q=80"

echo "所有封面图片已下载完成！" 