#!/bin/bash

# 如果命令行没有指定提交信息，则使用默认提交信息
msg="更新网站内容 $(date)"
if [ $# -eq 1 ]
  then msg="$1"
fi

echo -e "\033[0;32m开始构建...\033[0m"

# 构建网站
hugo --minify

# 进入public目录
cd public

# 创建CNAME文件
echo "www.yss520.online" > CNAME

echo -e "\033[0;32m构建完成!\033[0m"
echo -e "\033[0;32m请将public目录中的内容推送到GitHub Pages仓库\033[0m"
echo -e "\033[0;32m或者使用GitHub Actions自动部署\033[0m" 