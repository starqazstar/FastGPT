# Git操作流程记录

本文档记录了FastGPT项目的Git操作流程，包括如何处理数据文件、配置文件和代码提交等步骤，方便后续复习和回顾。

## 前期准备

### 克隆仓库
```bash
git clone https://github.com/starqazstar/FastGPT.git
cd FastGPT
```

## 配置 .gitignore

### 排除大型模型文件和数据库文件
```bash
# 添加以下内容到 .gitignore 文件
# large model files
models/

# database files
deploy/pg/data/
deploy/mysql/
deploy/mongo/data/
```

### a排除敏感配置文件
```bash
# 添加以下内容到 .gitignore 文件
# sensitive configuration files
.env
*.env
projects/app/.env
packages/service/core/ai/config/provider/*.json
```

### 排除日志文件
```bash
# 添加以下内容到 .gitignore 文件
# log files
*.log
logs/
deploy/*/logs/
```

## 提交流程

### 1. 提交 .gitignore 文件
```bash
git add .gitignore
git commit -m "更新 .gitignore 文件，排除模型文件、数据库文件、敏感配置和日志文件"
```

### 2. 提交文档和脚本文件
```bash
git add "FastGPT公网部署指南.md" "FastGPT本地BGE模型部署指南.md" "FastGPT部署问题排查指南.md" "Docker Compose快速部署.md" "本地部署.md" deploy-mac.sh
git commit -m "添加部署指南和部署脚本"
```

### 3. 提交配置文件和依赖锁定文件
```bash
git add pnpm-lock.yaml deploy/ docker/
git commit -m "添加部署配置文件和依赖锁定文件"
```

### 4. 推送到远程仓库
```bash
git push origin main
```

## 注意事项

### 应该提交的文件
- 源代码文件
- 文档和说明文件
- 部署指南和脚本
- 配置模板和示例
- 依赖锁定文件（如 pnpm-lock.yaml）

### 不应该提交的文件
- 大型模型文件（models/ 目录）
- 数据库文件（deploy/pg/data/, deploy/mysql/, deploy/mongo/data/）
- 敏感配置文件（.env, *.env, 包含API密钥的配置）
- 日志文件（*.log, logs/ 目录）

## 常用Git命令

### 检查状态
```bash
git status
```

### 查看修改
```bash
git diff [文件名]
```

### 查看提交历史
```bash
git log
```

### 切换分支
```bash
git checkout [分支名]
```

### 创建新分支
```bash
git checkout -b [新分支名]
```

### 合并分支
```bash
git merge [分支名]
```

### 更新远程代码
```bash
git pull origin [分支名]
```

## 处理特定场景

### 添加新功能后的更新步骤
1. 更新相关的 requirements.txt 文件（如有新依赖）
2. 提交代码和配置文件
3. 更新文档
4. 推送到远程仓库

### 在多台设备间同步
1. 在设备A上推送：`git push origin main`
2. 在设备B上同步：`git pull origin main`
3. 注意：模型文件等大型数据需要单独传输或重新下载，不通过Git同步

### 回退到之前版本
```bash
git log  # 查找要回退的提交ID
git reset --hard [提交ID]  # 硬回退
git push origin main --force  # 强制推送（谨慎使用）
```
