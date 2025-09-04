# 🔐 GitHub Secrets 配置指南

本文档详细说明如何为Docker镜像同步系统配置GitHub Secrets，特别是阿里云Container Registry的认证信息。

## 📋 配置概览

### 必需配置（阿里云）

| Secret名称 | 值 | 说明 |
|-----------|----|---------|
| `ALIYUN_USERNAME` | `swufelab` | 阿里云Container Registry用户名（固定） |
| `ALIYUN_PASSWORD` | `您的密码` | 阿里云Container Registry密码 |

### 可选配置（DockerHub）

| Secret名称 | 值 | 说明 |
|-----------|----|---------|
| `DOCKERHUB_USERNAME` | `您的用户名` | DockerHub用户名（可选） |
| `DOCKERHUB_TOKEN` | `您的Token` | DockerHub访问令牌（可选） |

### 固化配置说明

使用Crane工具后，以下配置已固化在代码中，无需在Secrets中配置：

- **仓库地址**: `registry.cn-hangzhou.aliyuncs.com` (杭州区域)
- **命名空间**: `dslab`
- **仓库名**: `vllm`
- **用户名**: `swufelab`

## 🚀 配置步骤

### 步骤1: 进入仓库设置

1. 在您的GitHub仓库页面，点击 **Settings** 标签
2. 在左侧菜单中选择 **Secrets and variables** > **Actions**

### 步骤2: 添加阿里云配置（必需）

#### 2.1 添加用户名

1. 点击 **New repository secret** 按钮
2. **Name**: `ALIYUN_USERNAME`
3. **Secret**: `swufelab`
4. 点击 **Add secret**

#### 2.2 添加密码

1. 点击 **New repository secret** 按钮
2. **Name**: `ALIYUN_PASSWORD`
3. **Secret**: `您的阿里云Container Registry密码`
4. 点击 **Add secret**

> ⚠️ **重要提示**: 密码是您在阿里云Container Registry中设置的密码，不是阿里云账号密码。

### 步骤3: 添加DockerHub配置（可选）

如果您需要拉取私有镜像或避免匿名用户的拉取限制，可以配置DockerHub认证：

#### 3.1 添加DockerHub用户名

1. 点击 **New repository secret** 按钮
2. **Name**: `DOCKERHUB_USERNAME`
3. **Secret**: `您的DockerHub用户名`
4. 点击 **Add secret**

#### 3.2 添加DockerHub Token

1. 点击 **New repository secret** 按钮
2. **Name**: `DOCKERHUB_TOKEN`
3. **Secret**: `您的DockerHub访问令牌`
4. 点击 **Add secret**

## 🔑 获取阿里云认证信息

### 方法1: 通过阿里云控制台

1. **登录阿里云控制台**
   - 访问 [阿里云控制台](https://ecs.console.aliyun.com/)
   - 使用您的阿里云账号登录

2. **进入容器镜像服务**
   - 搜索并进入 "容器镜像服务ACR"
   - 选择 "个人版" 或 "企业版"

3. **查看访问凭证**
   - 在左侧菜单中选择 "访问凭证"
   - 查看用户名（应为 `swufelab`）
   - 如需重置密码，点击 "重置Docker登录密码"

### 方法2: 通过Docker命令验证

您可以使用以下命令验证认证信息是否正确：

```bash
# 测试登录
docker login --username=swufelab registry.cn-hangzhou.aliyuncs.com

# 输入密码后，如果显示 "Login Succeeded" 则配置正确

# 拉取镜像（示例）
docker pull registry.cn-hangzhou.aliyuncs.com/dslab/vllm:nginx-latest
docker pull registry.cn-hangzhou.aliyuncs.com/dslab/vllm:redis-alpine
```

## 🔍 获取DockerHub Token

如果您选择配置DockerHub认证：

1. **登录DockerHub**
   - 访问 [DockerHub](https://hub.docker.com/)
   - 登录您的账号

2. **创建访问令牌**
   - 点击右上角头像 > **Account Settings**
   - 选择 **Security** 标签
   - 点击 **New Access Token**
   - 输入Token名称（如：`github-actions`）
   - 选择权限（推荐：**Read, Write, Delete**）
   - 点击 **Generate**

3. **复制Token**
   - 复制生成的Token（以 `dckr_pat_` 开头）
   - ⚠️ **注意**: Token只显示一次，请立即复制保存

## ✅ 配置验证

### 验证方法1: 查看Secrets列表

在仓库的 **Settings** > **Secrets and variables** > **Actions** 页面，您应该看到：

**必需的Secrets**:
- ✅ `ALIYUN_USERNAME`
- ✅ `ALIYUN_PASSWORD`

**可选的Secrets**:
- 🔲 `DOCKERHUB_USERNAME` (可选)
- 🔲 `DOCKERHUB_TOKEN` (可选)

### 验证方法2: 运行测试工作流

1. 进入 **Actions** 标签
2. 选择 "Enhanced Docker Image Sync with Crane" 工作流
3. 点击 **Run workflow**
4. 输入测试镜像（如：`nginx:latest`）
5. 启用 **干运行模式**
6. 点击 **Run workflow**

如果配置正确，工作流应该能够成功通过认证步骤。

## 🚨 常见问题

### Q1: 阿里云认证失败

**错误信息**: `❌ 阿里云认证失败`

**解决方案**:
1. 确认用户名为 `swufelab`
2. 确认密码是Container Registry的密码，不是阿里云账号密码
3. 在阿里云控制台重置Docker登录密码
4. 确认仓库地址为 `registry.cn-hangzhou.aliyuncs.com`

### Q2: DockerHub认证失败

**错误信息**: `⚠️ DockerHub认证失败，将使用匿名拉取`

**解决方案**:
1. 确认Token格式正确（以 `dckr_pat_` 开头）
2. 确认Token权限包含读取权限
3. 检查Token是否已过期
4. 重新生成新的Token

### Q3: 权限不足错误

**错误信息**: `permission denied` 或 `access denied`

**解决方案**:
1. 确认阿里云账号有Container Registry的操作权限
2. 确认命名空间 `dslab` 存在且有访问权限
3. 确认仓库 `vllm` 存在且有推送权限
4. 联系阿里云管理员检查RAM用户权限

### Q4: 网络连接问题

**错误信息**: `connection timeout` 或 `network unreachable`

**解决方案**:
1. 检查GitHub Actions的网络连接
2. 确认阿里云服务在目标区域可用
3. 尝试使用其他区域的仓库地址

## 📞 技术支持

如果您在配置过程中遇到问题：

1. **检查日志**: 在GitHub Actions的运行日志中查看详细错误信息
2. **验证配置**: 使用本地Docker命令验证认证信息
3. **联系支持**: 如果问题持续存在，请在仓库中创建Issue

## 🔄 配置更新

当需要更新配置时：

1. **更新密码**: 在阿里云控制台重置密码后，更新GitHub Secrets中的 `ALIYUN_PASSWORD`
2. **更新Token**: DockerHub Token过期时，生成新Token并更新 `DOCKERHUB_TOKEN`
3. **测试验证**: 更新后运行测试工作流验证配置

---

## 📝 配置模板

### 最小配置（仅阿里云）

```
ALIYUN_USERNAME=swufelab
ALIYUN_PASSWORD=your_aliyun_password
```

### 完整配置（包含DockerHub）

```
ALIYUN_USERNAME=swufelab
ALIYUN_PASSWORD=your_aliyun_password
DOCKERHUB_USERNAME=your_dockerhub_username
DOCKERHUB_TOKEN=dckr_pat_xxxxxxxxxx
```

---

*本文档最后更新: 2024年1月*