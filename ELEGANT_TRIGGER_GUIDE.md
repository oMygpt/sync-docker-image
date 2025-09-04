# 🎯 优雅的Docker镜像同步触发系统

本文档介绍了Docker镜像同步系统的多种优雅触发方式，告别传统的文件修改方式，提供更加用户友好的操作体验。

## 📋 目录

- [触发方式概览](#触发方式概览)
- [GitHub Actions手动触发](#github-actions手动触发)
- [Web界面触发](#web界面触发)
- [GitHub Issues触发](#github-issues触发)
- [API端点触发](#api端点触发)
- [传统文件触发](#传统文件触发)
- [配置说明](#配置说明)
- [最佳实践](#最佳实践)

## 🚀 触发方式概览

| 触发方式 | 优雅程度 | 技术难度 | 适用场景 | 推荐指数 |
|---------|---------|---------|---------|----------|
| 🌐 Web界面 | ⭐⭐⭐⭐⭐ | ⭐ | 日常使用、新手友好 | ⭐⭐⭐⭐⭐ |
| 🎮 GitHub Actions | ⭐⭐⭐⭐ | ⭐⭐ | 开发者、批量操作 | ⭐⭐⭐⭐ |
| 📝 GitHub Issues | ⭐⭐⭐⭐ | ⭐⭐ | 团队协作、需求跟踪 | ⭐⭐⭐⭐ |
| 🔌 API端点 | ⭐⭐⭐ | ⭐⭐⭐ | 自动化集成、脚本调用 | ⭐⭐⭐ |
| 📄 文件修改 | ⭐⭐ | ⭐ | 传统方式、备用方案 | ⭐⭐ |

---

## 🌐 Web界面触发

### 特点
- ✅ 最用户友好的方式
- ✅ 可视化操作界面
- ✅ 实时参数配置
- ✅ 预设镜像组合
- ✅ 支持移动端访问

### 使用方法

1. **本地访问**（推荐用于开发）
   ```bash
   # 启动本地Web服务
   cd web-interface
   python3 -m http.server 8080
   # 或使用Node.js
   npx serve .
   
   # 访问 http://localhost:8080
   ```

2. **GitHub Pages部署**（推荐用于生产）
   ```bash
   # 将web-interface目录内容推送到gh-pages分支
   git subtree push --prefix web-interface origin gh-pages
   
   # 访问 https://yourusername.github.io/sync-docker-image
   ```

### 界面功能

#### 🎯 单个镜像同步
- 输入单个镜像名称
- 实时格式验证
- 一键触发同步

#### 📋 多个镜像同步
- 多行文本输入
- 自动去重和验证
- 支持注释行（#开头）

#### ⚡ 预设镜像组
- **Web服务器**: nginx, apache, caddy
- **数据库**: mysql, postgres, redis, mongodb
- **AI/ML**: pytorch, tensorflow, jupyter
- **开发工具**: node, python, golang
- **监控工具**: prometheus, grafana, jaeger

#### ⚙️ 高级选项
- 目标仓库区域选择
- 同步模式配置
- 并发数控制
- 通知方式设置

---

## 🎮 GitHub Actions手动触发

### 特点
- ✅ GitHub原生支持
- ✅ 丰富的参数选项
- ✅ 完整的执行日志
- ✅ 权限控制

### 使用步骤

1. **访问Actions页面**
   ```
   https://github.com/yourusername/sync-docker-image/actions
   ```

2. **选择工作流**
   - 点击 "优雅的Docker镜像同步系统"
   - 点击 "Run workflow" 按钮

3. **配置参数**
   
   #### 同步模式
   - `single`: 单个镜像
   - `multiple`: 多个镜像
   - `batch`: 批量文件
   - `preset`: 预设组合
   
   #### 镜像输入
   ```
   # 单个镜像
   nginx:latest
   
   # 多个镜像（每行一个）
   nginx:latest
   redis:alpine
   mysql:8.0
   
   # 预设组合
   web-servers
   databases
   ai-ml
   dev-tools
   monitoring
   ```
   
   #### 目标仓库
   - `aliyun-hangzhou`: 杭州区域
   - `aliyun-beijing`: 北京区域
   - `aliyun-shanghai`: 上海区域
   - `aliyun-shenzhen`: 深圳区域
   
   #### 同步选项
   - `normal`: 正常同步
   - `force`: 强制同步
   - `dry-run`: 干运行预览
   - `verify-only`: 仅验证

4. **执行和监控**
   - 点击 "Run workflow" 开始执行
   - 在Actions页面查看实时进度
   - 查看详细日志和结果

---

## 📝 GitHub Issues触发

### 特点
- ✅ 标准化请求流程
- ✅ 需求跟踪和讨论
- ✅ 自动化处理
- ✅ 团队协作友好

### 使用方法

1. **创建同步请求Issue**
   ```
   https://github.com/yourusername/sync-docker-image/issues/new/choose
   ```

2. **选择模板**
   - 选择 "🐳 Docker镜像同步请求" 模板

3. **填写表单**
   
   #### 基本信息
   - **标题**: 自动生成，格式为 `[sync] 请求同步镜像: xxx`
   - **同步类型**: 单个/多个/预设镜像组
   - **镜像信息**: 根据类型填写相应字段
   
   #### 配置选项
   - **目标仓库区域**: 选择阿里云区域
   - **同步模式**: 正常/强制/干运行/仅验证
   - **优先级**: 高/中/低
   - **最大并发数**: 1-10
   
   #### 附加选项
   - [ ] 发送详细通知
   - [ ] 生成同步报告
   - [ ] 更新镜像映射表
   - [ ] 验证镜像完整性

4. **提交和跟踪**
   - 提交Issue后自动触发同步
   - 在Issue中查看处理进度
   - 完成后自动添加结果评论

### Issue标题格式
```
[sync] 请求同步镜像: nginx:latest
[sync] 批量同步Web服务器镜像
[同步] 紧急同步AI/ML镜像组
```

---

## 🔌 API端点触发

### 特点
- ✅ 编程接口
- ✅ 自动化集成
- ✅ 速率限制保护
- ✅ 详细的响应信息

### 启动API服务

```bash
# 安装依赖（如果需要）
npm install

# 设置环境变量
export GITHUB_TOKEN="your_github_token"
export GITHUB_REPO="yourusername/sync-docker-image"
export PORT=3000

# 启动服务
node api/sync-endpoint.js
```

### API端点

#### POST /api/sync - 触发同步

**请求示例**:
```bash
# 单个镜像
curl -X POST http://localhost:3000/api/sync \
  -H "Content-Type: application/json" \
  -d '{
    "mode": "single",
    "images": ["nginx:latest"],
    "targetRegistry": "aliyun-hangzhou",
    "syncOptions": "normal",
    "maxParallel": 3
  }'

# 多个镜像
curl -X POST http://localhost:3000/api/sync \
  -H "Content-Type: application/json" \
  -d '{
    "mode": "multiple",
    "images": ["nginx:latest", "redis:alpine", "mysql:8.0"],
    "targetRegistry": "aliyun-hangzhou",
    "syncOptions": "normal"
  }'

# 预设组合
curl -X POST http://localhost:3000/api/sync \
  -H "Content-Type: application/json" \
  -d '{
    "mode": "preset",
    "presetGroup": "web-servers",
    "targetRegistry": "aliyun-hangzhou"
  }'
```

**响应示例**:
```json
{
  "success": true,
  "message": "Sync request submitted successfully",
  "data": {
    "mode": "single",
    "imageCount": 1,
    "targetRegistry": "aliyun-hangzhou",
    "syncOptions": "normal",
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

#### GET /api/status - 查看状态

```bash
curl http://localhost:3000/api/status
```

#### GET /api/history - 查看历史

```bash
# 获取最近20条记录
curl http://localhost:3000/api/history

# 分页查询
curl "http://localhost:3000/api/history?limit=10&offset=20"
```

### 错误处理

```json
{
  "success": false,
  "error": {
    "code": 400,
    "message": "Invalid image names: invalid-image-name"
  }
}
```

### 速率限制

- **窗口期**: 5分钟
- **最大请求数**: 10次
- **超限响应**: HTTP 429

---

## 📄 传统文件触发

### 特点
- ✅ 简单直接
- ✅ Git版本控制
- ✅ 批量操作友好
- ❌ 操作相对繁琐

### 使用方法

#### 方式1: 修改images.md文件

```bash
# 编辑镜像列表文件
echo "nginx:latest" >> upload/images.md
echo "redis:alpine" >> upload/images.md

# 提交更改
git add upload/images.md
git commit -m "添加要同步的镜像"
git push
```

#### 方式2: 使用batch_sync.json文件

```json
{
  "config": {
    "maxRetries": 3,
    "retryDelay": 10,
    "maxParallel": 3,
    "targetRegistry": "aliyun-hangzhou"
  },
  "images": [
    "nginx:latest",
    "redis:alpine",
    "mysql:8.0"
  ]
}
```

---

## ⚙️ 配置说明

### GitHub Secrets配置

必需的Secrets:
```
ALIYUN_REGISTRY=registry.cn-hangzhou.aliyuncs.com
ALIYUN_USERNAME=your-aliyun-username
ALIYUN_PASSWORD=your-aliyun-password
ALIYUN_NAMESPACE=your-namespace
```

可选的Secrets（用于API触发）:
```
GITHUB_TOKEN=your-github-token
DOCKERHUB_USERNAME=your-dockerhub-username
DOCKERHUB_TOKEN=your-dockerhub-token
```

### 目标仓库映射

| 选项 | 实际地址 | 区域 |
|------|----------|------|
| aliyun-hangzhou | registry.cn-hangzhou.aliyuncs.com | 华东1 |
| aliyun-beijing | registry.cn-beijing.aliyuncs.com | 华北2 |
| aliyun-shanghai | registry.cn-shanghai.aliyuncs.com | 华东2 |
| aliyun-shenzhen | registry.cn-shenzhen.aliyuncs.com | 华南1 |

### 同步选项说明

| 选项 | 说明 | 适用场景 |
|------|------|----------|
| normal | 正常同步，跳过已存在的镜像 | 日常使用 |
| force | 强制同步，覆盖已存在的镜像 | 更新镜像 |
| dry-run | 干运行，仅预览操作不实际执行 | 测试验证 |
| verify-only | 仅验证镜像是否存在 | 检查可用性 |

---

## 🎯 最佳实践

### 1. 选择合适的触发方式

- **日常使用**: 推荐Web界面，操作简单直观
- **开发调试**: 推荐GitHub Actions手动触发，日志详细
- **团队协作**: 推荐GitHub Issues，便于讨论和跟踪
- **自动化集成**: 推荐API端点，编程友好
- **批量操作**: 推荐文件触发，Git版本控制

### 2. 镜像命名规范

```bash
# 推荐格式
nginx:latest          # 官方镜像
nginx:1.21-alpine     # 指定版本和变体
myregistry/nginx:v1.0 # 私有仓库镜像

# 避免格式
nginx                 # 缺少标签（会自动添加:latest）
invalid@image         # 包含非法字符
```

### 3. 并发控制

- **小镜像（<100MB）**: 可设置较高并发数（5-10）
- **大镜像（>1GB）**: 建议较低并发数（1-3）
- **网络较慢**: 降低并发数避免超时

### 4. 错误处理

- 使用干运行模式预先验证
- 查看详细日志定位问题
- 对失败的镜像单独重试
- 检查网络连接和认证信息

### 5. 安全考虑

- 定期更新GitHub Token
- 使用最小权限原则
- 启用API速率限制
- 监控异常访问

### 6. 性能优化

- 选择就近的目标仓库区域
- 避免在高峰期进行大批量同步
- 使用预设组合减少配置时间
- 定期清理不需要的镜像

---

## 🔗 相关链接

- [主要文档](README.md)
- [迁移指南](MIGRATION_SUMMARY.md)
- [GitHub Actions工作流](.github/workflows/sync-images-elegant.yml)
- [Web界面](web-interface/index.html)
- [API端点](api/sync-endpoint.js)
- [Issues模板](.github/ISSUE_TEMPLATE/sync-request.yml)

---

## 📞 支持和反馈

如果您在使用过程中遇到问题或有改进建议，请：

1. 查看[常见问题](README.md#常见问题)
2. 搜索[已有Issues](../../issues)
3. 创建[新的Issue](../../issues/new/choose)
4. 参与[讨论区](../../discussions)

---

**享受优雅的Docker镜像同步体验！** 🚀