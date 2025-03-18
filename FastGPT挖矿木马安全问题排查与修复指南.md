# FastGPT挖矿木马安全问题排查与修复指南

## 问题描述

在FastGPT官方Docker镜像中，特别是oneapi容器中发现了加密货币挖矿木马。恶意代码以一个名为"utility"的可执行文件形式存在于容器的`/tmp`目录中，并利用容器资源进行挖矿活动。

## 问题详情

- **恶意文件路径**: `/tmp/utility`（容器内）
- **恶意文件MD5**: `2212ea55ef893b39a1ba5e66f2ae803`
- **恶意文件SHA256**: `57c51126fa47cdbff4260f4eb9cfae63630ac5d375f80a4a7fb71d5d319fe7dd`
- **样本家族与特征**: `Miner:Linux/CoinMiner`（加密货币挖矿木马）
- **受影响的容器**: `fastgpt_oneapi_fastgpt`
- **容器ID**: `b1aebe63335952ec033e5299fddc1cc2c1847c291139ec720ed91cd4c30c802e`
- **受影响的镜像**: `ghcr.io/labring/fastgpt:v4.8.14`

## 问题复现分析

### 问题复现途径

复现这个挖矿木马问题主要通过以下方式：

1. **使用受感染的官方镜像**：直接使用 `ghcr.io/labring/fastgpt:v4.8.14` 镜像，特别是其中的oneapi容器。
2. **版本特定漏洞**：这主要是特定版本(v4.8.14)的问题，而非所有版本都受影响。

### 代码与构建分析

1. **不是源代码问题**：该挖矿木马很可能不是通过源代码植入，而是在镜像构建过程或托管平台被注入。
2. **供应链攻击**：可能是GitHub容器仓库(ghcr.io)的特定镜像被攻击者替换或修改，或构建过程中使用的某个基础镜像已被感染。

### 镜像源安全性比较

| 镜像源 | 安全性 | 原因 |
|---|---|---|
| ghcr.io/labring | 较低（特别是旧版本） | 曾发现挖矿木马；构建流程可能被入侵 |
| registry.cn-hangzhou.aliyuncs.com/fastgpt | 较高 | 未发现恶意软件；有更严格的安全审核机制；需实名认证上传 |

## 风险评估

此类挖矿木马的主要风险包括：

1. **资源消耗**: 大量消耗CPU和内存资源，导致服务变慢或不可用
2. **隐私风险**: 潜在数据泄露风险，恶意软件可能会收集系统信息
3. **系统稳定性**: 可能导致系统崩溃或服务中断
4. **额外成本**: 增加电费和云服务费用

## 解决方案

### 方案一：停止并替换受感染容器（推荐）

1. **停止并删除受感染的容器**

```bash
# 停止运行中的容器
docker stop fastgpt_oneapi_fastgpt

# 删除容器
docker rm fastgpt_oneapi_fastgpt

# 可选：删除受感染的镜像
docker rmi ghcr.io/labring/fastgpt:v4.8.14
```

2. **使用可信源镜像替代**

FastGPT在最新版本中已经推荐使用阿里云镜像源，而非ghcr.io源。修改您的docker-compose.yml文件，确保使用的是阿里云镜像：

```yaml
oneapi:
  container_name: oneapi
  image: registry.cn-hangzhou.aliyuncs.com/fastgpt/one-api:v0.6.6 # 阿里云镜像
  # 不要使用 image: ghcr.io/songquanpeng/one-api:v0.6.7
```

3. **加固容器配置**

增加以下安全配置到docker-compose.yml中的oneapi服务：

```yaml
oneapi:
  # ... 现有配置 ...
  # 添加资源限制
  deploy:
    resources:
      limits:
        cpus: '0.50'
        memory: 500M
  # 添加安全选项
  security_opt:
    - no-new-privileges:true
  # 使用临时文件系统替代写入/tmp
  tmpfs:
    - /tmp:exec,size=100M
```

4. **重新部署服务**

```bash
cd /path/to/fastgpt/deploy
docker-compose up -d
```

### 方案二：升级至最新版本并迁移至AI Proxy（长期解决方案）

最新版FastGPT（v4.9.0+）已逐步迁移至AI Proxy替代OneAPI。建议升级并完成迁移：

1. **更新到FastGPT最新版本**

   更新docker-compose.yml文件中的镜像版本至最新版（如v4.9.1）

2. **替换OneAPI为AI Proxy**

   按照[FastGPT官方迁移文档](https://github.com/labring/FastGPT/releases/tag/v4.9.0)进行配置：
   
   - 添加AI Proxy服务配置
   - 配置FastGPT使用AI Proxy
   - 执行迁移脚本

## 木马检测与清理

如果您怀疑系统受到感染，可执行以下检测步骤：

### 1. 检查可疑进程

```bash
# 检查高CPU占用的进程
docker exec oneapi top -b -n 1 | head -20

# 列出所有可执行文件
docker exec oneapi find /tmp -type f -executable -ls
```

### 2. 检查网络连接

```bash
# 检查可疑网络连接
docker exec oneapi netstat -tunap
```

### 3. 执行安全扫描

使用Docker安全扫描工具：

```bash
# 使用Trivy扫描镜像
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image registry.cn-hangzhou.aliyuncs.com/fastgpt/one-api:v0.6.6
```

## 预防措施

为防止类似问题再次发生，建议采取以下措施：

1. **使用可信镜像源**
   - 优先使用阿里云等官方认证的镜像源（`registry.cn-hangzhou.aliyuncs.com/fastgpt/`）
   - 避免使用`ghcr.io/labring`前缀的镜像，尤其是旧版本
   - 避免使用未经验证的第三方镜像

2. **定期更新**
   - 保持FastGPT及其组件的版本更新（推荐v4.9.1+）
   - 关注官方安全公告和GitHub发布页面
   - 考虑升级使用AI Proxy替代OneAPI（v4.9.0后推荐的方案）

3. **实施容器安全最佳实践**
   - 使用非root用户运行容器
   - 限制容器资源使用（CPU、内存上限）
   - 使用只读文件系统，特别是对敏感目录
   - 实施网络策略限制，限制不必要的出站连接
   - 使用tmpfs挂载临时目录，防止写入持久化

4. **定期安全检查**
   - 创建并执行定期安全检查脚本
   - 监控异常CPU和内存使用
   - 定期检查容器中的异常文件和进程

## 创建自动检查脚本

创建一个简单的检查脚本，定期执行以检测可能的挖矿活动：

```bash
#!/bin/bash
# 保存为 docker-security-check.sh
echo "==== 容器安全检查 $(date) ===="

# 检查所有容器中可疑文件和进程
for container in $(docker ps -q); do
  name=$(docker inspect --format='{{.Name}}' $container | sed 's/\///')
  echo "检查容器: $name"
  
  # 检查tmp目录下的可执行文件
  echo "- 检查可执行文件:"
  docker exec $container find /tmp -type f -executable -ls 2>/dev/null || echo "  无法检查 /tmp"
  
  # 检查高CPU使用率进程
  echo "- 检查高CPU使用率进程:"
  docker exec $container ps aux --sort=-%cpu | head -n 5 2>/dev/null || echo "  无法检查进程"
  
  # 检查可疑网络连接
  echo "- 检查可疑网络连接:"
  docker exec $container netstat -tunap 2>/dev/null | grep ESTABLISHED || echo "  无可疑连接"
  
  echo ""
done
```

设置为可执行并添加到crontab定期执行：

```bash
chmod +x docker-security-check.sh
# 每6小时执行一次
(crontab -l 2>/dev/null; echo "0 */6 * * * $(pwd)/docker-security-check.sh >> $(pwd)/security-check.log 2>&1") | crontab -
```

## 报告安全漏洞

如果您发现FastGPT相关的安全漏洞，请按照官方安全政策进行报告：

- 发送邮件至：yujinlong@sealos.io
- 请注明版本以及您的GitHub账号
- 在漏洞未修复前，请勿公开披露漏洞详情

## 参考资源

1. [FastGPT官方GitHub仓库](https://github.com/labring/FastGPT)
2. [FastGPT最新版本发布](https://github.com/labring/FastGPT/releases)
3. [Docker安全最佳实践](https://docs.docker.com/engine/security/security/)
4. [容器安全指南](https://owasp.org/www-project-docker-security/)
