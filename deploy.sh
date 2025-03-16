#!/bin/bash

# 如果命令行没有指定提交信息，则使用默认提交信息
msg="更新网站内容 $(date)"
if [ $# -eq 1 ]
  then msg="$1"
fi

echo -e "\033[0;32m开始部署...\033[0m"

# 构建网站
hugo --minify

# 进入public目录
cd public

# 创建CNAME文件
echo "www.yss520.online" > CNAME

# 初始化git仓库（如果不存在）
if [ ! -d ".git" ]; then
  git init
  git remote add origin https://github.com/lixiaolong/lixiaolong.github.io.git
fi

# 添加所有文件
git add .

# 提交更改
git commit -m "$msg"

# 推送到GitHub
git push -u origin master

# 返回上级目录
cd ..

echo -e "\033[0;32m部署完成!\033[0m" 