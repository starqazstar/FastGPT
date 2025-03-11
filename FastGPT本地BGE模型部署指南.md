# FastGPT本地BGE模型部署指南

## 1. 背景介绍

FastGPT默认使用OpenAI的`text-embedding-v3`模型进行文本向量化，但在某些情况下，我们可能需要使用本地模型替代，特别是在离线环境或需要降低成本的情况下。本文档记录了如何在FastGPT中配置和使用本地的`bge-base-zh`嵌入模型。

## 2. 准备工作

### 2.1 模型文件

确保`bge-base-zh`模型已下载并放置在正确的目录中：

```
/Users/public1/fastgpt/models/bge-base-zh/
```

模型文件应包括：
- `config.json`
- `pytorch_model.bin`
- `tokenizer.json`
- `tokenizer_config.json`
- `vocab.txt`

## 3. 搭建本地模型服务

为了让FastGPT能够使用本地模型，我们需要创建一个API服务，这个服务将模拟OpenAI的嵌入API接口。

### 3.1 创建服务脚本

我们采用虚拟环境方式解决依赖冲突问题，创建了以下脚本：

#### `setup_and_run.sh`

```bash
#!/bin/bash

# 创建一个独立的虚拟环境
echo "创建虚拟环境..."
python -m venv bge_env

# 激活虚拟环境
echo "激活虚拟环境..."
source bge_env/bin/activate

# 安装依赖（指定兼容的版本）
echo "安装必要的依赖..."
pip install torch==1.13.1
pip install transformers==4.26.0
pip install huggingface-hub==0.12.0
pip install fastapi==0.95.0
pip install uvicorn==0.21.0
pip install numpy==1.23.5

# 创建简化版本的服务器代码
cat > bge_server.py << 'EOL'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any
import numpy as np
import os
import torch
from transformers import AutoTokenizer, AutoModel
import logging

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = FastAPI(title="本地BGE模型服务")

# 添加CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 全局变量存储模型和分词器
tokenizer = None
model = None

# 请求模型
class EmbeddingRequest(BaseModel):
    model: str
    input: List[str]
    encoding_format: str = "float"

# 响应模型
class EmbeddingResponse(BaseModel):
    object: str = "list"
    data: List[Dict[str, Any]]
    model: str
    usage: Dict[str, int]

# 平均池化函数
def mean_pooling(model_output, attention_mask):
    token_embeddings = model_output[0]  # 第一个元素为最后一层隐藏状态
    input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
    return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)

# 启动时加载模型
@app.on_event("startup")
async def startup_event():
    global tokenizer, model
    try:
        logger.info("开始加载BGE模型...")
        # 使用当前目录下的模型
        model_path = os.path.abspath(os.path.dirname(__file__))
        tokenizer = AutoTokenizer.from_pretrained(model_path)
        model = AutoModel.from_pretrained(model_path)
        logger.info(f"BGE模型加载成功，路径: {model_path}")
    except Exception as e:
        logger.error(f"模型加载失败: {str(e)}")
        raise e

# 嵌入接口
@app.post("/v1/embeddings")
async def create_embedding(request: EmbeddingRequest):
    global model, tokenizer
    
    if model is None or tokenizer is None:
        raise HTTPException(status_code=500, detail="模型未加载，请稍后再试")
    
    try:
        # 分词和编码
        encoded_input = tokenizer(request.input, padding=True, truncation=True, return_tensors='pt', max_length=512)
        
        # 计算token数量
        token_count = 0
        for ids in encoded_input['input_ids']:
            token_count += len(ids)
        
        # 获取模型输出
        with torch.no_grad():
            model_output = model(**encoded_input)
            
        # 使用平均池化获取句子嵌入
        embeddings = mean_pooling(model_output, encoded_input['attention_mask'])
        
        # 规范化嵌入向量
        embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)
        
        # 构建响应
        data = []
        for i, embedding in enumerate(embeddings.tolist()):
            data.append({
                "object": "embedding",
                "embedding": embedding,
                "index": i
            })
        
        response = {
            "object": "list",
            "data": data,
            "model": request.model,
            "usage": {
                "prompt_tokens": token_count,
                "total_tokens": token_count
            }
        }
        
        return response
    except Exception as e:
        logger.error(f"生成嵌入向量时出错: {str(e)}")
        raise HTTPException(status_code=500, detail=f"生成嵌入向量时出错: {str(e)}")

# 健康检查接口
@app.get("/health")
async def health_check():
    if model is None or tokenizer is None:
        return {"status": "error", "message": "模型未加载"}
    return {"status": "ok", "message": "服务运行正常"}

if __name__ == "__main__":
    import uvicorn
    
    # 可以通过环境变量配置主机和端口
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8080"))
    
    # 启动服务
    uvicorn.run(app, host=host, port=port)
EOL

echo "启动BGE嵌入模型服务器..."
python bge_server.py
```

### 3.2 配置FastGPT

在FastGPT中添加本地模型的配置：

修改或创建`/Users/public1/fastgpt/packages/service/core/ai/config/provider/Local.json`文件：

```json
{
  "provider": "Local",
  "list": [
    {
      "model": "bge-base-zh",
      "name": "bge-base-zh",
      "defaultToken": 512,
      "maxToken": 2048,
      "type": "embedding",
      "requestUrl": "http://localhost:8080/v1/embeddings",
      "isActive": true,
      "isDefault": true,
      "normalization": true
    }
  ]
}
```

## 4. Docker环境下与FastGPT集成

在Docker环境中部署的FastGPT需要特别注意以下几点：

### 4.1 网络连接配置

**问题描述**：
Docker容器无法通过`localhost`访问宿主机上的服务。

**解决方案**：
1. 获取宿主机IP地址：
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

2. 修改FastGPT的配置文件，将`localhost`替换为宿主机IP：
```json
{
  "provider": "Local",
  "list": [
    {
      "model": "bge-base-zh",
      "name": "bge-base-zh",
      "defaultToken": 512,
      "maxToken": 2048,
      "type": "embedding",
      "requestUrl": "http://宿主机IP:8080/v1/embeddings",
      "isActive": true,
      "isDefault": true,
      "normalization": true
    }
  ]
}
```

### 4.2 OneAPI集成配置

**步骤**：
1. 访问OneAPI管理界面：http://localhost:3001
2. 登录管理员账号
3. 创建新渠道：
   - 名称：如"bge-base-zh"
   - 类型：自定义渠道
   - Base URL：`http://宿主机IP:8080`
   - 密钥：可填写简单的占位符，如`sk-local-bge-model`
   - 分组：选择`default`

4. 创建新模型：
   - **重要**：模型ID必须为`bge-base-zh`（与FastGPT的Local.json中配置一致）
   - 模型名称：可设置为"本地BGE模型"或其他描述性名称
   - 所属渠道：选择刚才创建的渠道

5. 重启相关服务：
```bash
docker restart oneapi
docker restart fastgpt
```

### 4.3 模型ID匹配问题

**问题描述**：
即使配置了正确的渠道和接口，FastGPT仍然无法识别本地模型，提示"当前分组 default 下对于模型无可用渠道"。

**解决方案**：
确保OneAPI中的**模型ID**与FastGPT的`Local.json`中的`model`字段完全一致，都是`bge-base-zh`。这是解决集成的关键。

## 5. 部署过程中遇到的问题及解决方案

### 5.1 依赖冲突问题

**问题描述**：
在启动服务时遇到了多个依赖冲突问题，主要是由于`huggingface-hub`、`transformers`和`sentence-transformers`之间的版本不兼容。

错误信息示例：
```
ImportError: cannot import name 'cached_download' from 'huggingface_hub'
```

**解决方案**：
1. 创建独立的虚拟环境，避免与系统包冲突
2. 固定使用已知兼容的依赖版本：
   - `torch==1.13.1`
   - `transformers==4.26.0`
   - `huggingface-hub==0.12.0` 
   - `numpy==1.23.5`

### 5.2 API兼容性问题

**问题描述**：
我们需要确保本地模型服务的API与OpenAI的API格式兼容，以便FastGPT可以无缝调用。

**解决方案**：
模拟OpenAI API的请求和响应格式，包括：
- 输入格式：`{"model": "...", "input": ["..."]}`
- 输出格式：`{"object": "list", "data": [...], "model": "...", "usage": {...}}`

## 6. 测试与验证

### 6.1 服务健康检查

```bash
curl -X GET http://localhost:8080/health
```

预期响应：
```json
{"status":"ok","message":"服务正常运行"}
```

### 6.2 嵌入功能测试

```bash
curl -X POST http://localhost:8080/v1/embeddings -H "Content-Type: application/json" -d '{"model":"bge-base-zh", "input": ["这是一个测试句子"]}'
```

预期响应包含生成的嵌入向量。

## 7. 使用说明

### 7.1 启动服务

每次需要使用本地模型时，执行以下命令：

```bash
cd /Users/public1/fastgpt/models/bge-base-zh
chmod +x setup_and_run.sh  # 第一次使用时设置执行权限
./setup_and_run.sh
```

### 7.2 服务持久化

如需让服务在后台持续运行，可以使用：

```bash
nohup ./setup_and_run.sh > bge_service.log 2>&1 &
```

### 7.3 FastGPT使用本地模型

重启FastGPT服务后，系统会自动加载Local.json中配置的本地模型。

## 8. 故障排除

1. **服务无法启动**：检查日志输出，确认依赖版本是否正确安装
2. **模型加载失败**：确认模型文件是否完整且路径正确
3. **API返回错误**：检查请求格式是否正确，模型是否成功加载

## 9. 优化建议

1. **性能优化**：根据硬件情况，可以考虑启用GPU加速
2. **容错处理**：增加更多的错误处理和重试机制
3. **监控**：添加服务监控和定时重启机制，确保长期稳定运行

## 10. 结论

通过以上步骤，我们成功将本地的`bge-base-zh`模型集成到FastGPT中，实现了文本向量化的本地计算，降低了对外部服务的依赖。虽然在部署过程中遇到了一些依赖和兼容性问题，但通过创建独立的虚拟环境和固定依赖版本，我们成功解决了这些问题。

本地部署不仅可以提高数据安全性，还能降低API调用成本，特别适合需要处理敏感数据或希望降低运营成本的场景。
