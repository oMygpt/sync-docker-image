# 🐳 Docker镜像同步系统 - 增强版 (Crane版本)

一个使用Google Crane工具的功能强大的Docker镜像同步工具，用于将DockerHub镜像高效同步到阿里云容器镜像服务，解决国内访问DockerHub速度慢的问题。相比传统Docker命令，Crane提供更好的可靠性和性能。

## ✨ 主要特性

### 🚀 核心功能
- **Crane工具**: 使用Google Crane替代Docker命令，提供更好的可靠性
- **智能认证**: 支持DockerHub可选认证，公开镜像可匿名拉取
- **手动同步**: 支持单个镜像的精确同步控制
- **批量同步**: 支持多镜像并发同步，提高效率
- **多重备用**: 直接复制失败时自动使用本地缓存方式
- **自动化流程**: GitHub Actions自动触发同步
- **智能重试**: 可配置的重试机制和错误恢复
- **状态跟踪**: 实时进度显示和详细状态监控

### 🛡️ 增强特性
- **输入验证**: 严格的镜像名称格式验证和自动修正
- **并发控制**: 可配置的并发数量，平衡速度和资源使用
- **错误处理**: 完善的错误分类、重试策略和失败恢复
- **日志系统**: 分级日志记录和彩色输出
- **配置管理**: 灵活的配置文件和环境变量支持
- **干运行模式**: 安全的预览模式，验证操作而不执行

### 📊 监控和报告
- **进度条**: 实时显示同步进度
- **统计报告**: 详细的同步统计和性能指标
- **历史记录**: 完整的同步历史追踪
- **失败分析**: 失败镜像列表和错误分析

## 📁 项目结构

```
sync-docker-image/
├── 📜 transfer.sh              # 原版同步脚本
├── 🚀 transfer_enhanced.sh     # 增强版同步脚本
├── 📦 batch_sync.sh           # 批量同步脚本
├── ⚙️ sync_config.conf        # 配置文件模板
├── 📋 transfer_history.md     # 同步历史记录
├── 📂 .github/workflows/
│   ├── sync-images.yml        # 原版GitHub Actions
│   └── sync-images-enhanced.yml # 增强版GitHub Actions
├── 📂 upload/
│   ├── images.md              # 镜像列表文件
│   └── batch_sync.json        # 批量同步配置
├── 📂 done/                   # 已处理镜像标记
├── 📂 logs/                   # 日志文件目录
└── 📂 .trae/documents/        # 项目文档
```

## 🍴 Fork 使用指南

### 📋 Fork 这个仓库的完整步骤

如果您想使用这个Docker镜像同步系统，最简单的方法是fork这个仓库到您自己的GitHub账户。

#### 1. Fork 仓库

1. **点击Fork按钮**
   - 访问本仓库页面
   - 点击右上角的 "Fork" 按钮
   - 选择您的GitHub账户作为目标

2. **克隆到本地（可选）**
   ```bash
   git clone https://github.com/YOUR_USERNAME/sync-docker-image.git
   cd sync-docker-image
   ```

#### 2. 配置GitHub Secrets

在您fork的仓库中配置必要的环境变量：

1. **进入仓库设置**
   - 在您fork的仓库页面，点击 "Settings" 标签
   - 在左侧菜单中选择 "Secrets and variables" > "Actions"

2. **添加必需的Secrets**
   
   点击 "New repository secret" 按钮，逐一添加以下变量：

   **阿里云配置（必需）：**
   ```
   ALIYUN_REGISTRY           # 如：registry.cn-hangzhou.aliyuncs.com
   ALIYUN_USERNAME           # 阿里云容器镜像服务用户名
   ALIYUN_PASSWORD           # 阿里云容器镜像服务密码
   ALIYUN_NAMESPACE          # 您的命名空间名称
   ```

   > **注意**: 使用Crane工具后，不再需要阿里云CLI相关的ACCESS_KEY配置。

   **DockerHub配置（可选，推荐）：**
   ```
   DOCKERHUB_USERNAME        # DockerHub用户名
   DOCKERHUB_TOKEN          # DockerHub访问令牌
   ```

#### 3. 获取阿里云凭证

1. **获取AccessKey**
   - 登录阿里云控制台
   - 访问 "AccessKey管理" 页面
   - 创建AccessKey，记录AccessKey ID和Secret

2. **设置容器镜像服务**
   - 访问阿里云 "容器镜像服务" 控制台
   - 创建命名空间（如果没有）
   - 记录Registry地址和登录凭证

3. **获取DockerHub Token（可选）**
   - 登录DockerHub网站
   - 进入 Account Settings > Security
   - 创建新的Access Token
   - 复制生成的Token（以dckr_pat_开头）

#### 4. 开始使用

配置完成后，您可以通过以下方式使用系统：

**方式一：编辑镜像列表文件**
```bash
# 在您fork的仓库中编辑 upload/images.md 文件
echo "nginx:latest" >> upload/images.md
echo "redis:alpine" >> upload/images.md

# 提交更改
git add upload/images.md
git commit -m "添加要同步的镜像"
git push
```

**方式二：手动触发GitHub Actions**
1. 在您的仓库中，点击 "Actions" 标签
2. 选择 "Enhanced Docker Image Sync" 工作流
3. 点击 "Run workflow" 按钮
4. 在输入框中填入镜像名称（每行一个）
5. 点击 "Run workflow" 执行

**方式三：使用JSON配置**
```bash
# 编辑 upload/batch_sync.json 文件，添加您的镜像配置
# 提交更改即可触发自动同步
```

#### 5. 监控同步进度

- **GitHub Actions页面**：查看实时同步日志
- **同步历史**：查看 `transfer_history.md` 文件
- **镜像映射**：查看 `image_list.md` 文件
- **阿里云控制台**：验证镜像是否成功推送

#### 6. 常见问题解答

**Q: 为什么我的同步失败了？**
A: 请检查：
- GitHub Secrets是否正确配置
- 阿里云AccessKey是否有足够权限
- 镜像名称格式是否正确
- 查看Actions日志获取详细错误信息

**Q: 可以同步私有镜像吗？**
A: 可以，但需要配置DockerHub凭证（DOCKERHUB_USERNAME和DOCKERHUB_TOKEN）

**Q: 同步后的镜像地址是什么？**
A: 格式为：`registry.cn-hangzhou.aliyuncs.com/your-namespace/image-name:tag`

**Q: 如何批量添加多个镜像？**
A: 编辑 `upload/images.md` 文件，每行添加一个镜像名称，然后提交到GitHub

**Q: 系统支持哪些镜像仓库？**
A: 目前支持从DockerHub同步到阿里云容器镜像服务

---

## 🚀 快速开始

### 1. 环境准备

确保系统已安装以下工具：
- Google Crane 工具 (推荐)
- Git
- Bash (4.0+)
- jq (用于JSON处理)

#### 安装Crane工具

```bash
# 使用Go安装
go install github.com/google/go-containerregistry/cmd/crane@latest

# 或下载预编译二进制文件
curl -sL "https://github.com/google/go-containerregistry/releases/latest/download/go-containerregistry_$(uname -s)_$(uname -m).tar.gz" | tar xz -C /tmp/
sudo mv /tmp/crane /usr/local/bin/
```

### 2. 配置认证信息

#### GitHub Secrets配置
在GitHub仓库的Settings > Secrets中添加以下环境变量：

##### 必需配置（阿里云）
```bash
# 阿里云配置 - 必需
ALIYUN_REGISTRY=registry.cn-hangzhou.aliyuncs.com
ALIYUN_USERNAME=your_aliyun_username
ALIYUN_PASSWORD=your_aliyun_password
ALIYUN_NAMESPACE=your_namespace
```

> **注意**: 使用Crane工具后，不再需要阿里云CLI相关的ACCESS_KEY配置。

##### 可选配置（DockerHub）
```bash
# DockerHub配置 - 可选（用于私有镜像或提高拉取限制）
DOCKERHUB_USERNAME=your_dockerhub_username
DOCKERHUB_TOKEN=your_dockerhub_token
```

> **注意**: DockerHub凭证是可选的。如果不配置，系统将以匿名方式拉取公开镜像。配置DockerHub凭证的好处：
> - 避免匿名用户的拉取限制
> - 可以拉取私有镜像
> - 提高拉取稳定性

#### 本地配置
复制并编辑配置文件：
```bash
cp sync_config.conf.example sync_config.conf
# 编辑配置文件，设置您的参数
```

### 3. 基本使用

#### 手动同步单个镜像
```bash
# 使用增强版脚本
./transfer_enhanced.sh -s nginx:latest -d registry.cn-hangzhou.aliyuncs.com/namespace/nginx:latest

# 详细输出模式
./transfer_enhanced.sh -s redis:alpine -d registry.cn-hangzhou.aliyuncs.com/namespace/redis:alpine -v

# 干运行模式（预览操作）
./transfer_enhanced.sh -s ubuntu:20.04 -d registry.cn-hangzhou.aliyuncs.com/namespace/ubuntu:20.04 --dry-run
```

#### 批量同步
```bash
# 使用镜像列表文件
./batch_sync.sh upload/images.md

# 使用JSON配置文件
./batch_sync.sh -j upload/batch_sync.json

# 并发同步（5个并发）
./batch_sync.sh -p 5 upload/images.md

# 强制同步所有镜像
./batch_sync.sh -f upload/images.md
```

## 📖 详细使用指南

### 增强版脚本 (transfer_enhanced.sh)

#### 命令行选项
```bash
./transfer_enhanced.sh [选项]

选项:
  -s, --source <镜像>          源镜像地址 (必需)
  -d, --destination <镜像>     目标镜像地址 (必需)
  -r, --retries <次数>         重试次数 (默认: 3)
  -w, --wait <秒数>           重试间隔 (默认: 5)
  -v, --verbose               详细输出模式
  -n, --dry-run              干运行模式
  -f, --force                强制执行
  -c, --config <文件>         配置文件路径
  -l, --log <文件>           日志文件路径
  -h, --help                 显示帮助信息
```

#### 使用示例
```bash
# 基本同步
./transfer_enhanced.sh \
  -s nginx:latest \
  -d registry.cn-hangzhou.aliyuncs.com/my-namespace/nginx:latest

# 高级配置
./transfer_enhanced.sh \
  -s redis:6.2-alpine \
  -d registry.cn-hangzhou.aliyuncs.com/my-namespace/redis:6.2-alpine \
  -r 5 \
  -w 10 \
  -v \
  -c my_config.conf

# 干运行测试
./transfer_enhanced.sh \
  -s mysql:8.0 \
  -d registry.cn-hangzhou.aliyuncs.com/my-namespace/mysql:8.0 \
  --dry-run
```

### 批量同步脚本 (batch_sync.sh)

#### 命令行选项
```bash
./batch_sync.sh [选项] <镜像列表文件>

选项:
  -c, --config <文件>         配置文件路径
  -j, --json <文件>          JSON配置文件路径
  -p, --parallel <数量>       最大并发数 (默认: 3)
  -r, --retries <次数>        重试次数 (默认: 3)
  -w, --wait <秒数>          重试间隔 (默认: 5)
  -v, --verbose              详细输出模式
  -n, --dry-run             干运行模式
  -f, --force               强制同步
  --no-cleanup              不清理本地镜像
  --no-skip                 不跳过已存在的镜像
  -h, --help                显示帮助信息
```

#### 镜像列表文件格式 (upload/images.md)
```markdown
# Docker镜像列表
# 每行一个镜像，支持注释

nginx:latest
redis:alpine
mysql:8.0
node:18-alpine
python:3.11-slim

# 这是注释行，会被忽略
# ubuntu:22.04
```

#### JSON配置文件格式 (upload/batch_sync.json)
```json
{
  "config": {
    "maxRetries": 3,
    "retryDelay": 10,
    "maxParallel": 3,
    "dryRun": false,
    "forceSync": false
  },
  "images": [
    {
      "source": "nginx:latest",
      "target": "nginx:latest",
      "priority": "high",
      "description": "Nginx web server"
    },
    {
      "source": "redis:alpine",
      "target": "redis:alpine",
      "priority": "medium",
      "description": "Redis database"
    }
  ]
}
```

### GitHub Actions自动化

#### 触发方式
1. **自动触发**: 修改 `upload/images.md` 或 `upload/batch_sync.json` 文件
2. **手动触发**: 在GitHub Actions页面手动运行工作流

#### 手动触发参数
- **镜像列表**: 直接输入镜像名称（每行一个）
- **干运行模式**: 预览操作而不执行
- **最大并发数**: 控制同时处理的镜像数量
- **强制同步**: 忽略已处理标记，重新同步所有镜像

## ⚙️ 配置说明

### 配置文件 (sync_config.conf)

主要配置选项：

```bash
# 基本配置
MAX_RETRIES=3              # 最大重试次数
RETRY_DELAY=5              # 重试间隔（秒）
VERBOSE=false              # 详细输出模式
DRY_RUN=false              # 干运行模式

# 并发配置
MAX_PARALLEL=3             # 最大并发数
MAX_PROCESSING_TIME=1800   # 单个镜像最大处理时间

# 日志配置
LOG_LEVEL=INFO             # 日志级别
LOG_RETENTION_DAYS=7       # 日志保留天数
COLOR_OUTPUT=true          # 彩色输出

# 镜像处理
CLEANUP_ON_SUCCESS=true    # 成功后清理本地镜像
SKIP_EXISTING=true         # 跳过已存在的镜像
IMAGE_VALIDATION=basic     # 镜像验证模式

# 错误处理
FAIL_FAST=true             # 遇到错误立即退出
SAVE_FAILED_IMAGES=true    # 保存失败镜像列表
ERROR_NOTIFICATION=false   # 错误通知
```

### 环境变量

支持通过环境变量覆盖配置：

```bash
export MAX_RETRIES=5
export RETRY_DELAY=10
export VERBOSE=true
export DRY_RUN=false
```

## 📊 监控和日志

### 日志系统

#### 日志级别
- **DEBUG**: 调试信息（需要启用详细模式）
- **INFO**: 一般信息
- **WARN**: 警告信息
- **ERROR**: 错误信息
- **SUCCESS**: 成功信息

#### 日志文件
- **单个同步**: `sync_YYYYMMDD_HHMMSS.log`
- **批量同步**: `batch_sync_YYYYMMDD_HHMMSS.log`
- **镜像特定**: `logs/sync_image_name_YYYYMMDD_HHMMSS.log`

### 统计报告

批量同步会生成详细的统计报告：

```json
{
  "summary": {
    "startTime": "2024-01-15 10:00:00",
    "endTime": "2024-01-15 10:30:00",
    "duration": 1800,
    "totalImages": 10,
    "successCount": 8,
    "failedCount": 2,
    "skippedCount": 0,
    "successRate": 80
  },
  "details": {
    "nginx:latest": {
      "status": "success",
      "duration": 120,
      "logFile": "logs/nginx_latest.log"
    }
  }
}
```

### 历史记录

同步历史记录在 `transfer_history.md` 文件中：

| 源镜像 | 目标镜像 | 状态 | 运行时间 | 日志文件 |
|--------|----------|------|----------|----------|
| `nginx:latest` | `registry.cn-hangzhou.aliyuncs.com/ns/nginx:latest` | SUCCESS | 2024-01-15 10:00:00 | `sync_20240115_100000.log` |

## 🔧 故障排除

### 常见问题

#### 1. Docker认证失败
```bash
# 检查Docker登录状态
docker info

# 重新登录
docker login registry.cn-hangzhou.aliyuncs.com
```

#### 2. 镜像拉取失败
```bash
# 检查网络连接
ping registry-1.docker.io

# 使用代理
export HTTP_PROXY=http://proxy:8080
export HTTPS_PROXY=http://proxy:8080
```

#### 3. 阿里云仓库创建失败
```bash
# 检查阿里云CLI配置
aliyun configure list

# 测试API访问
aliyun cr GetNamespace --NamespaceName your-namespace
```

#### 4. 权限问题
```bash
# 检查脚本权限
ls -la *.sh

# 添加执行权限
chmod +x *.sh
```

### 调试模式

启用详细输出和调试信息：

```bash
# 单个镜像调试
./transfer_enhanced.sh -s nginx:latest -d target:latest -v

# 批量同步调试
./batch_sync.sh -v upload/images.md

# 干运行模式测试
./transfer_enhanced.sh -s nginx:latest -d target:latest --dry-run
```

### 日志分析

```bash
# 查看最新日志
tail -f logs/sync_*.log

# 搜索错误信息
grep -i error logs/*.log

# 统计成功率
grep -c "SUCCESS" logs/*.log
```

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

### 开发环境设置

```bash
# 克隆仓库
git clone https://github.com/your-org/sync-docker-image.git
cd sync-docker-image

# 安装依赖
# Ubuntu/Debian
sudo apt-get install docker.io jq

# CentOS/RHEL
sudo yum install docker jq

# macOS
brew install docker jq
```

### 测试

```bash
# 运行测试
./test/run_tests.sh

# 代码检查
shellcheck *.sh
```

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

感谢所有贡献者和开源社区的支持！

---

**📞 支持**: 如有问题，请提交 [Issue](https://github.com/your-org/sync-docker-image/issues)

**📚 文档**: 更多详细信息请查看 [Wiki](https://github.com/your-org/sync-docker-image/wiki)
