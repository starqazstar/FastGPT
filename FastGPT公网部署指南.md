# FastGPT公网部署指南

本文档记录了如何将本地部署的FastGPT应用通过ngrok工具暴露到公网，实现远程访问。

## 前提条件

- 已成功在本地部署FastGPT应用，并能通过 http://localhost:3000 访问
- 已安装ngrok工具（如未安装，可通过 `brew install ngrok` 安装）

## 部署步骤

### 1. 安装ngrok

在macOS系统上，可以使用Homebrew安装ngrok：

```bash
brew install ngrok
```

### 2. 配置ngrok认证令牌

注册ngrok账号后，获取authtoken并配置：

```bash
ngrok config add-authtoken 您的authtoken
```

例如：
```bash
ngrok config add-authtoken 2u17P1degF6dZzzk9kXJrUe4jDL_3QGhfaGc2FEfojgpLDxDk
```

### 3. 启动ngrok内网穿透

确保FastGPT应用正在本地运行（监听3000端口），然后执行：

```bash
ngrok http http://localhost:3000
```

### 4. 获取公网访问地址

成功启动后，ngrok会提供一个公网访问地址，格式如下：

```
https://xxxx-xxx-xxx-xxx.ngrok-free.app -> http://localhost:3000
```

例如：
```
https://e64e-219-142-152-160.ngrok-free.app
```

现在可以通过这个地址从任何地方访问您的FastGPT应用。

## 注意事项

1. **临时域名**：免费版ngrok提供的是临时域名，每次重启ngrok服务后，域名会改变
2. **保持终端运行**：ngrok需要保持终端窗口开启，关闭终端会中断公网访问
3. **连接限制**：免费版有连接数和带宽限制
4. **安全性**：公网访问意味着任何人都可以访问您的应用，请确保应用有适当的安全措施
5. **监控请求**：可通过 http://127.0.0.1:4040 访问ngrok的Web界面，查看请求日志和其他信息

## 其他公网部署方案

除了使用ngrok外，还可以考虑以下方案：

### 1. FRP内网穿透（更稳定的开源方案）

FRP是一个开源的内网穿透工具，比ngrok更稳定且没有免费版的限制。

#### 服务端配置（需要有公网服务器）

1. 在公网服务器上下载frp：
```bash
wget https://github.com/fatedier/frp/releases/download/v0.51.3/frp_0.51.3_linux_amd64.tar.gz
tar -zxvf frp_0.51.3_linux_amd64.tar.gz
cd frp_0.51.3_linux_amd64
```

2. 编辑服务端配置文件frps.ini：
```ini
[common]
bind_port = 7000
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
token = your_token_here
```

3. 启动frp服务端：
```bash
./frps -c frps.ini
```

#### 客户端配置（本地机器）

1. 在本地下载对应系统版本的frp
2. 编辑客户端配置文件frpc.ini：
```ini
[common]
server_addr = 公网服务器IP
server_port = 7000
token = your_token_here

[fastgpt-web]
type = tcp
local_ip = 127.0.0.1
local_port = 3000
remote_port = 8080
```

3. 启动frp客户端：
```bash
./frpc -c frpc.ini
```

4. 通过`http://公网服务器IP:8080`访问FastGPT

### 2. Cloudflare Tunnel

Cloudflare Tunnel提供免费的内网穿透服务，并且自带CDN加速和SSL证书。

1. 注册Cloudflare账号并添加您的域名
2. 安装cloudflared客户端：
```bash
# macOS
brew install cloudflare/cloudflare/cloudflared

# Linux
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

3. 登录Cloudflare账号：
```bash
cloudflared tunnel login
```

4. 创建隧道：
```bash
cloudflared tunnel create fastgpt-tunnel
```

5. 配置隧道路由，创建配置文件config.yml：
```yaml
tunnel: <tunnel-id>
credentials-file: /path/to/.cloudflared/<tunnel-id>.json
ingress:
  - hostname: fastgpt.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
```

6. 启动隧道：
```bash
cloudflared tunnel run fastgpt-tunnel
```

7. 添加DNS记录：
```bash
cloudflared tunnel route dns fastgpt-tunnel fastgpt.yourdomain.com
```

8. 通过`https://fastgpt.yourdomain.com`访问FastGPT

### 3. 部署到云服务器

将FastGPT直接部署到具有公网IP的云服务器上是最稳定的方案。

1. 在云服务器上安装必要环境：
```bash
# 安装Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 安装pnpm
npm install -g pnpm@9.4.0

# 安装Docker和Docker Compose
sudo apt-get update
sudo apt-get install docker.io docker-compose -y
```

2. 克隆FastGPT仓库：
```bash
git clone https://github.com/labring/FastGPT.git
cd FastGPT
```

3. 按照FastGPT文档配置数据库和环境变量

4. 启动应用：
```bash
cd projects/app
pnpm i
pnpm dev
```

5. 配置防火墙开放3000端口：
```bash
sudo ufw allow 3000
```

6. 通过`http://服务器公网IP:3000`访问FastGPT

### 4. Nginx反向代理

如果您已有网站和域名，可以使用Nginx进行反向代理：

1. 安装Nginx：
```bash
sudo apt update
sudo apt install nginx -y
```

2. 创建Nginx配置文件：
```bash
sudo nano /etc/nginx/sites-available/fastgpt
```

3. 添加以下配置：
```nginx
server {
    listen 80;
    server_name fastgpt.yourdomain.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

4. 创建符号链接并重启Nginx：
```bash
sudo ln -s /etc/nginx/sites-available/fastgpt /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

5. 配置SSL证书（推荐）：
```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d fastgpt.yourdomain.com
```

6. 通过`https://fastgpt.yourdomain.com`访问FastGPT

### 5. Docker部署并映射端口

使用Docker部署FastGPT并直接映射端口到主机：

1. 编辑docker-compose.yml文件，确保FastGPT服务的端口映射配置如下：
```yaml
services:
  fastgpt:
    # 其他配置...
    ports:
      - "80:3000"  # 将容器的3000端口映射到主机的80端口
```

2. 启动Docker容器：
```bash
docker-compose up -d
```

3. 确保服务器防火墙开放80端口：
```bash
sudo ufw allow 80
```

4. 通过`http://服务器公网IP`访问FastGPT

### 6. 使用云服务提供商的应用托管服务

许多云服务提供商提供应用托管服务，可以轻松部署Node.js应用：

1. **Vercel**：
   - 注册Vercel账号并连接GitHub仓库
   - 导入FastGPT项目
   - 配置环境变量
   - 部署应用

2. **Railway**：
   - 注册Railway账号
   - 导入GitHub仓库
   - 配置环境变量和构建命令
   - 部署应用

3. **Heroku**：
   - 注册Heroku账号
   - 创建新应用并连接GitHub仓库
   - 配置环境变量
   - 部署应用

## 参考资源

- [ngrok官方文档](https://ngrok.com/docs)
- [FastGPT官方文档](https://doc.tryfastgpt.ai/docs/development/intro/)
