# FastGPT部署问题排查指南

## 问题描述

在使用Docker Compose部署FastGPT v4.8.22版本时，可能会遇到模型流响应为空的问题。主要表现为在聊天界面发送消息后，模型不返回任何响应，或者返回空响应。

## 问题原因

经过排查，主要原因是FastGPT的环境变量`OPENAI_BASE_URL`配置错误，缺少了`/v1`路径后缀。

## 复现步骤

1. 使用以下版本的FastGPT和相关组件：
   - FastGPT: v4.8.22
   - OneAPI: v0.6.6
   - PostgreSQL with pgvector: v0.7.0
   - MongoDB: v5.0.18

2. 在`/Users/public1/fastgpt/deploy/docker-compose.yml`文件中，检查FastGPT容器的环境变量配置：

```yaml
# 错误配置
- OPENAI_BASE_URL=http://oneapi:3000
```

3. 使用此配置启动FastGPT后，当尝试使用模型时，会在日志中看到以下错误：

```
[Warn] 2025-02-27 08:12:49 LLM response empty {"requestBody":{"model":"deepseek-chat","stream":true,"messages":[{"role":"user","content":"你好"}],"temperature":0.3,"max_tokens":1950}}
[Warn] 2025-02-27 08:12:49 workflow error {"message":"chat:LLM_model_response_empty"}
```

## 解决方案

修改`/Users/public1/fastgpt/deploy/docker-compose.yml`文件中的环境变量配置，添加`/v1`路径后缀：

```yaml
# 正确配置
- OPENAI_BASE_URL=http://oneapi:3000/v1
```

然后重启FastGPT容器：

```bash
cd /Users/public1/fastgpt/deploy
docker-compose down
docker-compose up -d
```

## 排查过程中使用的命令

以下是排查过程中使用的主要命令，可以帮助诊断和解决问题：

### 1. 检查容器状态

```bash
docker ps | grep -E "fastgpt|oneapi"
```

### 2. 查看FastGPT日志

```bash
docker logs fastgpt --tail 50
```

### 3. 查看OneAPI日志

```bash
docker logs oneapi --tail 50
```

### 4. 检查FastGPT环境变量

```bash
docker inspect fastgpt | grep -A 20 "Env"
```

### 5. 检查网络连接

```bash
docker exec fastgpt ping -c 3 oneapi
```

### 6. 测试API路径

```bash
docker exec fastgpt curl -I http://oneapi:3000/v1
docker exec fastgpt curl -I http://oneapi:3000/api/v1
docker exec fastgpt curl http://oneapi:3000/api/status
```

### 7. 测试模型API调用

```bash
docker exec fastgpt curl -X POST "http://oneapi:3000/api/v1/chat/completions" -H "Content-Type: application/json" -H "Authorization: Bearer sk-fastgpt" -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"你好"}]}'
```

## DeepSeek API认证问题排查

在配置OneAPI使用DeepSeek模型时，可能会遇到以下错误：

```
错误: status code 401:
Authentication Fails (no such user)
```

### 可能的原因

1. **API密钥格式错误**：DeepSeek API密钥可能有特定格式要求
2. **认证方式不正确**：可能需要使用Bearer认证
3. **账户问题**：API密钥可能已失效或账户余额不足

### 解决方法

1. 登录DeepSeek官网，检查API密钥是否正确
2. 在OneAPI的渠道配置中，确保：
   - **密钥**字段中输入正确的API密钥，没有多余空格或换行符
   - **密钥前缀**字段中输入"Bearer "（包含空格）
   - **模型**字段中输入正确的模型名称，如"deepseek-chat"
   - **模型重定向**字段中配置正确的映射，如`{"deepseek-chat": "deepseek-chat"}`

3. 保存配置后，使用OneAPI的测试功能验证连接

## DeepSeek API自定义请求地址和自定义请求Key配置问题

### 问题描述

在使用FastGPT前端配置DeepSeek API时，可能会遇到使用自定义请求地址和自定义请求Key无法正常调用API的问题。

### 问题原因

DeepSeek API使用与OpenAI兼容的API格式，但在配置时需要注意以下几点：
1. 自定义请求地址需要包含完整路径，包括`/v1`
2. 认证头格式必须正确设置
3. 模型名称必须与DeepSeek支持的模型名称匹配

### 复现步骤

1. 在FastGPT的OneAPI配置界面（通常访问地址为`http://your-server-ip:3001`）中添加新渠道
2. 配置以下信息：
   - 自定义请求地址: `https://api.deepseek.com`（错误，缺少`/v1`）
   - 自定义请求Key: 仅填写API密钥，没有添加`Bearer`前缀

3. 使用此配置后，在调用模型时会收到401认证错误：
```
错误: status code 401:
Authentication Fails (no such user)
```

### 解决方案

正确的配置方式应为：

1. **自定义请求地址**：
   - LLM: `https://api.deepseek.com/v1/chat/completions`
   - Embedding: `https://api.deepseek.com/v1/embeddings`
   - 其他API根据需要添加完整路径

2. **自定义请求Key**：
   - 在OneAPI的渠道配置中，在"密钥"字段填入完整的DeepSeek API密钥
   - 在"密钥前缀"字段中输入`Bearer `（包含空格）

3. **模型配置**：
   - 模型名称使用`deepseek-chat`（调用DeepSeek-V3）或`deepseek-reasoner`（调用DeepSeek-R1）
   - 模型重定向配置为`{"gpt-3.5-turbo": "deepseek-chat"}`或根据需要映射

### 验证配置

配置完成后，可以使用以下命令测试API连接是否正常：

```bash
# 使用curl测试DeepSeek API连接
curl -X POST "https://api.deepseek.com/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role": "user", "content": "你好"}],
    "temperature": 0.7,
    "max_tokens": 500
  }'
```

### 排查命令

在排查过程中，可以使用以下命令检查OneAPI与DeepSeek API的连接情况：

```bash
# 检查OneAPI容器日志
docker logs oneapi --tail 50

# 进入OneAPI容器并测试网络连接
docker exec -it oneapi bash
curl -I https://api.deepseek.com/v1/chat/completions

# 测试API认证
curl -X POST "https://api.deepseek.com/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"测试"}]}'
```

## 前端使用自定义请求地址和自定义请求Key的最佳实践

在FastGPT前端配置第三方API（如DeepSeek）时，建议遵循以下最佳实践：

1. **完整的API路径**：
   - 始终使用完整的API路径，包括基础URL和端点路径
   - 例如：`https://api.deepseek.com/v1/chat/completions`而不仅仅是`https://api.deepseek.com`

2. **正确的认证格式**：
   - 大多数API使用Bearer认证，格式为`Bearer YOUR_API_KEY`
   - 在OneAPI中，可以在"密钥前缀"字段中设置`Bearer `，在"密钥"字段中只填写API密钥

3. **模型名称映射**：
   - 确保在"模型重定向"字段中正确映射模型名称
   - 例如：`{"gpt-3.5-turbo": "deepseek-chat", "text-embedding-ada-002": "deepseek-embed"}`

4. **测试验证**：
   - 配置完成后，使用OneAPI的测试功能验证连接
   - 或使用curl命令直接测试API连接

通过遵循以上最佳实践，可以避免大多数与第三方API集成相关的问题。

## 其他常见问题

### 1. PostgreSQL连接错误

如果遇到PostgreSQL连接错误（`connect ECONNREFUSED 172.18.0.3:5432`），可以尝试：

```bash
# 检查PostgreSQL容器状态
docker exec -it pg pg_isready -h localhost -p 5432

# 重启PostgreSQL容器
docker restart pg
```

### 2. MongoDB连接错误

如果遇到MongoDB连接错误，可以尝试：

```bash
# 检查MongoDB容器状态
docker exec -it mongo mongosh --eval "rs.status()"

# 重启MongoDB容器
docker restart mongo
```

### 3. 模型不可用

如果在FastGPT中选择模型时显示"当前分组下对于模型无可用渠道"，请在OneAPI中检查：

1. 渠道是否正确配置
2. 模型名称是否与FastGPT请求的模型名称一致
3. 模型重定向是否正确配置

## 总结

FastGPT与OneAPI集成时，最常见的问题是API路径配置不正确和模型名称不匹配。通过正确配置`OPENAI_BASE_URL`环境变量和在OneAPI中设置正确的模型映射，可以解决大多数连接问题。

对于DeepSeek等第三方模型的认证问题，需要确保API密钥格式正确，并按照模型提供商的要求设置正确的认证方式。

在配置第三方API时，建议遵循最佳实践，确保完整的API路径、正确的认证格式和模型名称映射，以避免大多数与API集成相关的问题。


deepseek api文档：https://api-docs.deepseek.com/zh-cn/
deepseek api开放平台：https://platform.deepseek.com/api_keys
embeding 阿里百练：https://bailian.console.aliyun.com/#/model-market
