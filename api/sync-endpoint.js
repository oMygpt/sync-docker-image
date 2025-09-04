#!/usr/bin/env node

/**
 * Docker镜像同步API端点
 * 提供HTTP API接口来触发GitHub Actions同步操作
 * 
 * 使用方法:
 *   node sync-endpoint.js
 *   
 * API端点:
 *   POST /api/sync - 触发同步操作
 *   GET /api/status - 查看同步状态
 *   GET /api/history - 查看同步历史
 *   GET / - Web界面
 */

const http = require('http');
const url = require('url');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// 配置
const CONFIG = {
    port: process.env.PORT || 3000,
    host: process.env.HOST || 'localhost',
    githubToken: process.env.GITHUB_TOKEN,
    githubRepo: process.env.GITHUB_REPO || 'oMygpt/sync-docker-image',
    allowedOrigins: (process.env.ALLOWED_ORIGINS || '*').split(','),
    maxImageCount: parseInt(process.env.MAX_IMAGE_COUNT || '50'),
    rateLimitWindow: parseInt(process.env.RATE_LIMIT_WINDOW || '300000'), // 5分钟
    rateLimitMax: parseInt(process.env.RATE_LIMIT_MAX || '10')
};

// 预设镜像组
const PRESET_GROUPS = {
    'web-servers': [
        'nginx:latest',
        'nginx:alpine',
        'httpd:latest',
        'caddy:latest'
    ],
    'databases': [
        'mysql:8.0',
        'postgres:15',
        'redis:7-alpine',
        'mongo:6'
    ],
    'ai-ml': [
        'pytorch/pytorch:latest',
        'tensorflow/tensorflow:latest',
        'jupyter/scipy-notebook:latest'
    ],
    'dev-tools': [
        'node:18-alpine',
        'python:3.11-slim',
        'golang:1.21-alpine'
    ],
    'monitoring': [
        'prom/prometheus:latest',
        'grafana/grafana:latest',
        'jaegertracing/all-in-one:latest'
    ]
};

// 速率限制存储
const rateLimitStore = new Map();

// 同步历史存储
const syncHistory = [];

/**
 * 设置CORS头
 */
function setCORSHeaders(res, origin) {
    if (CONFIG.allowedOrigins.includes('*') || CONFIG.allowedOrigins.includes(origin)) {
        res.setHeader('Access-Control-Allow-Origin', origin || '*');
    }
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Access-Control-Max-Age', '86400');
}

/**
 * 检查速率限制
 */
function checkRateLimit(clientIP) {
    const now = Date.now();
    const windowStart = now - CONFIG.rateLimitWindow;
    
    if (!rateLimitStore.has(clientIP)) {
        rateLimitStore.set(clientIP, []);
    }
    
    const requests = rateLimitStore.get(clientIP);
    
    // 清理过期请求
    const validRequests = requests.filter(time => time > windowStart);
    rateLimitStore.set(clientIP, validRequests);
    
    // 检查是否超过限制
    if (validRequests.length >= CONFIG.rateLimitMax) {
        return false;
    }
    
    // 记录新请求
    validRequests.push(now);
    return true;
}

/**
 * 验证镜像名称格式
 */
function validateImageName(imageName) {
    const imageRegex = /^[a-zA-Z0-9._/-]+(:([a-zA-Z0-9._-]+))?$/;
    return imageRegex.test(imageName);
}

/**
 * 解析请求体
 */
function parseRequestBody(req) {
    return new Promise((resolve, reject) => {
        let body = '';
        req.on('data', chunk => {
            body += chunk.toString();
        });
        req.on('end', () => {
            try {
                resolve(JSON.parse(body));
            } catch (error) {
                reject(new Error('Invalid JSON'));
            }
        });
        req.on('error', reject);
    });
}

/**
 * 触发GitHub Actions工作流
 */
async function triggerGitHubActions(syncRequest) {
    if (!CONFIG.githubToken) {
        throw new Error('GitHub token not configured');
    }
    
    const workflowInputs = {
        sync_mode: syncRequest.mode,
        target_registry: syncRequest.targetRegistry || 'aliyun-hangzhou',
        sync_options: syncRequest.syncOptions || 'normal',
        max_parallel: syncRequest.maxParallel || 3,
        notification: syncRequest.notification || 'summary'
    };
    
    // 根据模式设置不同的输入
    switch (syncRequest.mode) {
        case 'single':
            workflowInputs.single_image = syncRequest.images[0];
            break;
        case 'multiple':
            workflowInputs.multiple_images = syncRequest.images.join('\n');
            break;
        case 'preset':
            workflowInputs.preset_group = syncRequest.presetGroup;
            break;
    }
    
    // 构建GitHub API请求
    const apiUrl = `https://api.github.com/repos/${CONFIG.githubRepo}/actions/workflows/sync-images-elegant.yml/dispatches`;
    
    const requestBody = JSON.stringify({
        ref: 'main',
        inputs: workflowInputs
    });
    
    // 使用curl触发（简化实现）
    try {
        const curlCommand = [
            'curl',
            '-X', 'POST',
            '-H', `Authorization: token ${CONFIG.githubToken}`,
            '-H', 'Accept: application/vnd.github.v3+json',
            '-H', 'Content-Type: application/json',
            '-d', `'${requestBody}'`,
            apiUrl
        ].join(' ');
        
        execSync(curlCommand, { stdio: 'pipe' });
        return { success: true, message: 'Workflow triggered successfully' };
    } catch (error) {
        throw new Error(`Failed to trigger workflow: ${error.message}`);
    }
}

/**
 * 处理同步请求
 */
async function handleSyncRequest(req, res) {
    try {
        const body = await parseRequestBody(req);
        
        // 验证请求格式
        if (!body.mode || !body.images) {
            return sendError(res, 400, 'Missing required fields: mode, images');
        }
        
        // 验证同步模式
        const validModes = ['single', 'multiple', 'preset'];
        if (!validModes.includes(body.mode)) {
            return sendError(res, 400, 'Invalid sync mode');
        }
        
        // 处理镜像列表
        let images = [];
        
        switch (body.mode) {
            case 'single':
                if (!body.images[0]) {
                    return sendError(res, 400, 'Single image name required');
                }
                images = [body.images[0]];
                break;
                
            case 'multiple':
                images = body.images.filter(img => img && validateImageName(img));
                if (images.length === 0) {
                    return sendError(res, 400, 'No valid images provided');
                }
                break;
                
            case 'preset':
                if (!body.presetGroup || !PRESET_GROUPS[body.presetGroup]) {
                    return sendError(res, 400, 'Invalid preset group');
                }
                images = PRESET_GROUPS[body.presetGroup];
                break;
        }
        
        // 检查镜像数量限制
        if (images.length > CONFIG.maxImageCount) {
            return sendError(res, 400, `Too many images. Maximum allowed: ${CONFIG.maxImageCount}`);
        }
        
        // 验证所有镜像名称
        const invalidImages = images.filter(img => !validateImageName(img));
        if (invalidImages.length > 0) {
            return sendError(res, 400, `Invalid image names: ${invalidImages.join(', ')}`);
        }
        
        // 构建同步请求
        const syncRequest = {
            mode: body.mode,
            images: images,
            presetGroup: body.presetGroup,
            targetRegistry: body.targetRegistry || 'aliyun-hangzhou',
            syncOptions: body.syncOptions || 'normal',
            maxParallel: Math.min(parseInt(body.maxParallel) || 3, 10),
            notification: body.notification || 'summary',
            timestamp: new Date().toISOString(),
            clientIP: req.connection.remoteAddress
        };
        
        // 触发GitHub Actions
        const result = await triggerGitHubActions(syncRequest);
        
        // 记录到历史
        syncHistory.unshift({
            id: Date.now().toString(),
            ...syncRequest,
            status: 'triggered',
            result: result
        });
        
        // 保持历史记录数量
        if (syncHistory.length > 100) {
            syncHistory.splice(100);
        }
        
        // 返回成功响应
        sendJSON(res, 200, {
            success: true,
            message: 'Sync request submitted successfully',
            data: {
                mode: syncRequest.mode,
                imageCount: images.length,
                targetRegistry: syncRequest.targetRegistry,
                syncOptions: syncRequest.syncOptions,
                timestamp: syncRequest.timestamp
            }
        });
        
    } catch (error) {
        console.error('Sync request error:', error);
        sendError(res, 500, error.message);
    }
}

/**
 * 处理状态查询
 */
function handleStatusRequest(req, res) {
    const recentSyncs = syncHistory.slice(0, 10);
    
    sendJSON(res, 200, {
        success: true,
        data: {
            server: {
                status: 'running',
                uptime: process.uptime(),
                version: '1.0.0'
            },
            recentSyncs: recentSyncs,
            statistics: {
                totalRequests: syncHistory.length,
                presetGroups: Object.keys(PRESET_GROUPS),
                rateLimitWindow: CONFIG.rateLimitWindow,
                rateLimitMax: CONFIG.rateLimitMax
            }
        }
    });
}

/**
 * 处理历史查询
 */
function handleHistoryRequest(req, res) {
    const urlParts = url.parse(req.url, true);
    const limit = Math.min(parseInt(urlParts.query.limit) || 20, 100);
    const offset = parseInt(urlParts.query.offset) || 0;
    
    const paginatedHistory = syncHistory.slice(offset, offset + limit);
    
    sendJSON(res, 200, {
        success: true,
        data: {
            history: paginatedHistory,
            pagination: {
                total: syncHistory.length,
                limit: limit,
                offset: offset,
                hasMore: offset + limit < syncHistory.length
            }
        }
    });
}

/**
 * 发送JSON响应
 */
function sendJSON(res, statusCode, data) {
    res.writeHead(statusCode, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(data, null, 2));
}

/**
 * 发送错误响应
 */
function sendError(res, statusCode, message) {
    sendJSON(res, statusCode, {
        success: false,
        error: {
            code: statusCode,
            message: message
        }
    });
}

/**
 * 发送静态文件
 */
function sendStaticFile(res, filePath, contentType) {
    try {
        const content = fs.readFileSync(filePath);
        res.writeHead(200, { 'Content-Type': contentType });
        res.end(content);
    } catch (error) {
        sendError(res, 404, 'File not found');
    }
}

/**
 * 主请求处理器
 */
function handleRequest(req, res) {
    const clientIP = req.connection.remoteAddress;
    const origin = req.headers.origin;
    
    // 设置CORS头
    setCORSHeaders(res, origin);
    
    // 处理OPTIONS请求
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }
    
    // 检查速率限制
    if (!checkRateLimit(clientIP)) {
        return sendError(res, 429, 'Rate limit exceeded');
    }
    
    const urlParts = url.parse(req.url, true);
    const pathname = urlParts.pathname;
    
    console.log(`${new Date().toISOString()} - ${req.method} ${pathname} - ${clientIP}`);
    
    // 路由处理
    switch (pathname) {
        case '/api/sync':
            if (req.method === 'POST') {
                handleSyncRequest(req, res);
            } else {
                sendError(res, 405, 'Method not allowed');
            }
            break;
            
        case '/api/status':
            if (req.method === 'GET') {
                handleStatusRequest(req, res);
            } else {
                sendError(res, 405, 'Method not allowed');
            }
            break;
            
        case '/api/history':
            if (req.method === 'GET') {
                handleHistoryRequest(req, res);
            } else {
                sendError(res, 405, 'Method not allowed');
            }
            break;
            
        case '/':
        case '/index.html':
            const webInterfacePath = path.join(__dirname, '..', 'web-interface', 'index.html');
            sendStaticFile(res, webInterfacePath, 'text/html');
            break;
            
        default:
            sendError(res, 404, 'Not found');
            break;
    }
}

/**
 * 启动服务器
 */
function startServer() {
    const server = http.createServer(handleRequest);
    
    server.listen(CONFIG.port, CONFIG.host, () => {
        console.log(`🚀 Docker镜像同步API服务器已启动`);
        console.log(`📍 地址: http://${CONFIG.host}:${CONFIG.port}`);
        console.log(`🌐 Web界面: http://${CONFIG.host}:${CONFIG.port}`);
        console.log(`📡 API端点:`);
        console.log(`   POST /api/sync - 触发同步`);
        console.log(`   GET  /api/status - 查看状态`);
        console.log(`   GET  /api/history - 查看历史`);
        console.log(`⚙️  配置:`);
        console.log(`   最大镜像数: ${CONFIG.maxImageCount}`);
        console.log(`   速率限制: ${CONFIG.rateLimitMax}次/${CONFIG.rateLimitWindow/1000}秒`);
        console.log(`   GitHub仓库: ${CONFIG.githubRepo}`);
        console.log(`   GitHub Token: ${CONFIG.githubToken ? '已配置' : '未配置'}`);
    });
    
    // 优雅关闭
    process.on('SIGINT', () => {
        console.log('\n🛑 正在关闭服务器...');
        server.close(() => {
            console.log('✅ 服务器已关闭');
            process.exit(0);
        });
    });
    
    return server;
}

// 如果直接运行此文件，启动服务器
if (require.main === module) {
    startServer();
}

module.exports = {
    startServer,
    CONFIG,
    PRESET_GROUPS
};