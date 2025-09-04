#!/bin/bash

# Crane工具设置测试脚本
# 用于验证crane工具是否正确安装和配置

set -euo pipefail

echo "🔧 测试Crane工具设置..."

# 检查crane是否安装
if ! command -v crane &> /dev/null; then
    echo "❌ Crane工具未安装"
    echo "请安装crane: go install github.com/google/go-containerregistry/cmd/crane@latest"
    exit 1
fi

# 显示crane版本
echo "✅ Crane工具已安装"
crane_version=$(crane version 2>/dev/null || echo "unknown")
echo "📦 Crane版本: $crane_version"

# 测试基本功能
echo "🧪 测试基本功能..."

# 测试列出公开镜像的标签
echo "📋 测试列出镜像标签 (hello-world)..."
if crane ls hello-world | head -5; then
    echo "✅ 基本功能测试通过"
else
    echo "❌ 基本功能测试失败"
    exit 1
fi

# 测试镜像信息获取
echo "📊 测试获取镜像信息..."
if crane manifest hello-world:latest > /dev/null 2>&1; then
    echo "✅ 镜像信息获取测试通过"
else
    echo "❌ 镜像信息获取测试失败"
    exit 1
fi

echo "🎉 Crane工具设置测试完成！"
echo "💡 现在可以使用新的GitHub Actions工作流进行镜像同步"