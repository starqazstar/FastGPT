#!/bin/bash

# FastGPT Mac部署脚本
# 作者：基于FastGPT官方文档创建
# 版本：1.1

# 彩色输出函数
print_green() {
    echo -e "\033[32m$1\033[0m"
}

print_yellow() {
    echo -e "\033[33m$1\033[0m"
}

print_red() {
    echo -e "\033[31m$1\033[0m"
}

print_blue() {
    echo -e "\033[34m$1\033[0m"
}

# 检查是否已安装Docker和Docker Compose
check_docker() {
    print_blue "正在检查Docker和Docker Compose安装状态..."
    
    if ! command -v docker &> /dev/null; then
        print_red "未安装Docker，请先安装Docker!"
        print_yellow "可以从 https://www.docker.com/products/docker-desktop 下载安装"
        exit 1
    else
        docker_version=$(docker --version)
        print_green "Docker已安装: $docker_version"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_red "未安装Docker Compose，请先安装Docker Compose!"
        print_yellow "可以通过Homebrew安装: brew install docker-compose"
        exit 1
    else
        compose_version=$(docker-compose --version)
        print_green "Docker Compose已安装: $compose_version"
    fi
}

# 创建部署目录
create_deploy_dir() {
    print_blue "正在创建部署目录..."
    
    deploy_dir="$1"
    if [ -d "$deploy_dir" ]; then
        print_yellow "目录 $deploy_dir 已存在"
    else
        mkdir -p "$deploy_dir"
        print_green "已创建部署目录: $deploy_dir"
    fi
    
    cd "$deploy_dir"
    print_green "当前工作目录: $(pwd)"
}

# 下载配置文件
download_config_files() {
    print_blue "正在下载配置文件..."
    
    # 下载config.json
    if [ -f "config.json" ]; then
        print_yellow "config.json 已存在，跳过下载"
    else
        curl -O https://raw.githubusercontent.com/labring/FastGPT/main/projects/app/data/config.json
        print_green "config.json 下载完成"
    fi
    
    # 根据用户选择下载对应的docker-compose文件
    if [ -f "docker-compose.yml" ]; then
        print_yellow "docker-compose.yml 已存在，是否覆盖? (y/n)"
        read -r overwrite
        if [ "$overwrite" != "y" ]; then
            print_yellow "保留现有docker-compose.yml文件"
            return
        fi
    fi
    
    print_yellow "请选择向量数据库类型:"
    echo "1) PgVector (推荐用于测试和小规模应用，5000万以下向量)"
    echo "2) Milvus (适用于亿级以上向量)"
    echo "3) Zilliz Cloud (Milvus的云托管服务)"
    
    read -r choice
    case $choice in
        1)
            curl -o docker-compose.yml https://raw.githubusercontent.com/labring/FastGPT/main/deploy/docker/docker-compose-pgvector.yml
            print_green "已下载PgVector版本的docker-compose.yml"
            ;;
        2)
            curl -o docker-compose.yml https://raw.githubusercontent.com/labring/FastGPT/main/deploy/docker/docker-compose-milvus.yml
            print_green "已下载Milvus版本的docker-compose.yml"
            ;;
        3)
            curl -o docker-compose.yml https://raw.githubusercontent.com/labring/FastGPT/main/deploy/docker/docker-compose-zilliz.yml
            print_green "已下载Zilliz Cloud版本的docker-compose.yml"
            ;;
        *)
            print_red "无效选择，默认使用PgVector版本"
            curl -o docker-compose.yml https://raw.githubusercontent.com/labring/FastGPT/main/deploy/docker/docker-compose-pgvector.yml
            print_green "已下载PgVector版本的docker-compose.yml"
            ;;
    esac
}

# 配置环境变量
configure_env_vars() {
    print_blue "配置环境变量..."
    
    # 获取当前IP地址
    ip_address=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -n 1 | awk '{print $2}')
    
    print_yellow "请输入前端访问地址 (默认: http://$ip_address:3000)"
    read -r fe_domain
    fe_domain=${fe_domain:-http://$ip_address:3000}
    
    print_yellow "请输入root用户密码 (默认: 1234)"
    read -r root_pwd
    root_pwd=${root_pwd:-1234}
    
    # 修改docker-compose.yml中的环境变量
    # 使用sed命令替换环境变量
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS版本的sed命令
        sed -i '' "s|FE_DOMAIN=.*|FE_DOMAIN=$fe_domain|g" docker-compose.yml
        sed -i '' "s|DEFAULT_ROOT_PSW=.*|DEFAULT_ROOT_PSW=$root_pwd|g" docker-compose.yml
        
        # 确保OPENAI_BASE_URL包含/v1路径
        if grep -q "OPENAI_BASE_URL=http://oneapi:3000$" docker-compose.yml; then
            sed -i '' "s|OPENAI_BASE_URL=http://oneapi:3000|OPENAI_BASE_URL=http://oneapi:3000/v1|g" docker-compose.yml
            print_green "已修改OPENAI_BASE_URL添加/v1路径"
        fi
    else
        # Linux版本的sed命令
        sed -i "s|FE_DOMAIN=.*|FE_DOMAIN=$fe_domain|g" docker-compose.yml
        sed -i "s|DEFAULT_ROOT_PSW=.*|DEFAULT_ROOT_PSW=$root_pwd|g" docker-compose.yml
        
        # 确保OPENAI_BASE_URL包含/v1路径
        if grep -q "OPENAI_BASE_URL=http://oneapi:3000$" docker-compose.yml; then
            sed -i "s|OPENAI_BASE_URL=http://oneapi:3000|OPENAI_BASE_URL=http://oneapi:3000/v1|g" docker-compose.yml
            print_green "已修改OPENAI_BASE_URL添加/v1路径"
        fi
    fi
    
    print_green "环境变量配置完成"
}

# 启动容器
start_containers() {
    print_blue "启动FastGPT容器..."
    
    docker-compose down
    docker-compose up -d
    
    print_yellow "等待10秒，确保OneAPI连接到MySQL..."
    sleep 10
    
    print_blue "重启OneAPI容器..."
    docker restart oneapi
    
    print_green "FastGPT容器启动完成!"
    
    # 提供模型配置指导
    print_blue "\n===== OneAPI模型配置指南 ====="
    print_yellow "请在 http://localhost:3001 配置以下模型渠道:"
    echo "1. 对于DeepSeek模型，请注意模型重定向设置:"
    echo "   模型重定向示例: "
    print_green '   {
     "gpt-3.5-turbo": "deepseek-chat",
     "gpt-4": "deepseek-coder"
   }'
    
    echo "2. DeepSeek模型没有embedding功能，请配置阿里或其他支持embedding的模型"
    echo "   可用于向量生成，如text-embedding-ada-002"
    
    echo "3. 代理URL正确格式: https://api.deepseek.com (为DeepSeek)"
    echo "4. 需要添加密钥前缀 'Bearer ' (包含空格)"
}

# 检查容器状态
check_container_status() {
    print_blue "检查容器状态..."
    
    docker ps | grep -E "fastgpt|oneapi|mongo|postgres"
    
    print_yellow "检查FastGPT日志..."
    docker logs fastgpt --tail 20
    
    print_yellow "检查OneAPI日志..."
    docker logs oneapi --tail 20
}

# 问题排查函数
troubleshoot() {
    print_blue "开始问题排查..."
    
    print_yellow "1. 检查FastGPT容器环境变量..."
    docker inspect fastgpt | grep -A 20 "Env"
    
    print_yellow "2. 检查网络连接..."
    docker exec -it fastgpt ping -c 3 oneapi
    
    print_yellow "3. 检查Mongo副本集状态..."
    docker exec -it mongo mongo -u $(grep MONGO_INITDB_ROOT_USERNAME docker-compose.yml | cut -d= -f2) -p $(grep MONGO_INITDB_ROOT_PASSWORD docker-compose.yml | cut -d= -f2) --authenticationDatabase admin --eval "rs.status()"
    
    print_yellow "4. 检查API状态..."
    docker exec -it fastgpt curl -I http://oneapi:3000/v1
    docker exec -it fastgpt curl http://oneapi:3000/api/status
    
    print_yellow "5. 检查模型配置..."
    print_yellow "如果你使用DeepSeek模型但无法正常响应，请检查:"
    echo "- OneAPI中模型重定向配置是否正确 (例如 {\"gpt-3.5-turbo\": \"deepseek-chat\"})"
    echo "- 代理URL是否包含正确格式 (https://api.deepseek.com)"
    echo "- 密钥前缀是否包含 'Bearer ' (包含空格)"
    echo "- 请为Embedding向量模型配置单独渠道 (如使用阿里模型)"
    
    print_green "问题排查完成，请查看上述输出以识别潜在问题"
}

# 备份数据库
backup_database() {
    print_blue "备份数据库..."
    
    timestamp=$(date +%Y%m%d%H%M%S)
    backup_dir="./backup_$timestamp"
    mkdir -p "$backup_dir"
    
    print_yellow "备份MongoDB数据..."
    docker exec mongo mongodump --host localhost --port 27017 -u $(grep MONGO_INITDB_ROOT_USERNAME docker-compose.yml | cut -d= -f2) -p $(grep MONGO_INITDB_ROOT_PASSWORD docker-compose.yml | cut -d= -f2) --authenticationDatabase admin --out /data/db/backup
    docker cp mongo:/data/db/backup "$backup_dir/mongo_backup"
    
    print_yellow "备份PgVector数据..."
    if docker ps | grep -q postgres; then
        docker exec postgres pg_dump -U $(grep POSTGRES_USER docker-compose.yml | cut -d= -f2) -d $(grep POSTGRES_DB docker-compose.yml | cut -d= -f2) -f /var/lib/postgresql/data/backup.sql
        docker cp postgres:/var/lib/postgresql/data/backup.sql "$backup_dir/postgres_backup.sql"
    fi
    
    print_green "数据库备份完成，备份文件存储在: $backup_dir"
}

# 显示使用说明
show_usage() {
    cat << EOF
FastGPT Mac部署脚本使用说明:
  deploy    - 部署FastGPT (执行全部步骤)
  status    - 显示容器状态
  restart   - 重启所有容器
  logs      - 查看容器日志
  trouble   - 问题排查
  backup    - 备份数据库
  model     - 显示模型配置指南
  help      - 显示此帮助信息
EOF
}

# 主函数
main() {
    case $1 in
        deploy)
            print_green "===== 开始部署FastGPT ====="
            check_docker
            create_deploy_dir "${2:-./fastgpt}"
            download_config_files
            configure_env_vars
            start_containers
            
            print_green "===== FastGPT部署完成 ====="
            print_green "请访问: $(grep FE_DOMAIN docker-compose.yml | cut -d= -f2)"
            print_green "默认用户名: root"
            print_green "默认密码: $(grep DEFAULT_ROOT_PSW docker-compose.yml | cut -d= -f2)"
            print_green "OneAPI地址: http://localhost:3001 (默认用户名:root 密码:123456)"
            print_yellow "重要提示: 请务必在OneAPI中配置至少一组AI模型渠道，否则系统无法正常使用"
            print_yellow "使用 './deploy-mac.sh model' 命令查看详细的模型配置指南"
            ;;
        status)
            check_container_status
            ;;
        restart)
            docker-compose down
            docker-compose up -d
            sleep 10
            docker restart oneapi
            print_green "容器已重启"
            ;;
        logs)
            print_yellow "FastGPT日志:"
            docker logs fastgpt --tail 50
            print_yellow "OneAPI日志:"
            docker logs oneapi --tail 50
            ;;
        trouble)
            troubleshoot
            ;;
        backup)
            backup_database
            ;;
        model)
            show_model_guide
            ;;
        *)
            show_usage
            ;;
    esac
}

# 显示模型配置指南
show_model_guide() {
    print_blue "===== OneAPI模型配置指南 ====="
    
    print_yellow "1. DeepSeek模型配置:"
    echo "类型: DeepSeek"
    echo "名称: 自定义名称，如 Deepseek-chat"
    echo "分组: default 或自定义分组"
    echo "模型: 添加需要支持的模型，如 deepseek-chat, deepseek-coder, deepseek-reasoner, gpt-3.5-turbo, gpt-4"
    
    print_yellow "2. 模型重定向配置 (非常重要):"
    echo "模型重定向示例:"
    print_green '{
  "gpt-3.5-turbo": "deepseek-chat",
  "gpt-4": "deepseek-coder"
}'
    echo "这样可以让系统使用gpt-3.5-turbo的地方实际调用deepseek-chat模型"
    
    print_yellow "3. DeepSeek API配置:"
    echo "密钥: 填入DeepSeek API密钥"
    echo "密钥前缀: Bearer (包含空格)"
    echo "代理: https://api.deepseek.com"
    
    print_yellow "4. Embedding模型配置:"
    echo "由于DeepSeek没有提供embedding模型，需要单独配置其他模型用于向量化"
    echo "可以使用阿里模型来做Embedding，例如 text-embedding-ada-002"
    echo "添加一个新的渠道，类型为 OpenAI"
    echo "名称: 自定义名称，如 Embedding-Ali"
    echo "分组: default 或自定义分组"
    echo "模型: text-embedding-ada-002"
    echo "代理: https://dashscope.aliyuncs.com/compatible-mode/v1"
    echo "密钥: 填入阿里API密钥 (无需Bearer前缀)"
    
    print_yellow "5. 测试渠道连接:"
    echo "配置完成后，点击'测试'按钮验证连接是否正常"
}

# 如果没有参数，显示使用说明
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

main "$@"
