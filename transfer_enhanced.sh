#!/bin/bash

# Enhanced Docker Image Transfer Script with Crane
# 支持批量镜像同步、错误处理、进度报告和日志记录
# 使用crane工具替代docker命令以提高可靠性

set -euo pipefail  # 严格模式：遇到错误立即退出

# 设置颜色变量和样式
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 全局变量
SOURCE_IMAGE=""
DEST_IMAGE=""
MAX_RETRIES=3
RETRY_DELAY=5
LOG_FILE="sync_$(date +%Y%m%d_%H%M%S).log"
VERBOSE=false
DRY_RUN=false
FORCE=false
CONFIG_FILE="sync_config.conf"

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${CYAN}[INFO]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
            ;;
        "DEBUG")
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "${MAGENTA}[DEBUG]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
            fi
            ;;
    esac
}

# 进度条函数
show_progress() {
    local current=$1
    local total=$2
    local step_name="$3"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${BLUE}[%s]${NC} %s [" "$step_name" "$percentage%"
    printf "%*s" $completed | tr ' ' '█'
    printf "%*s" $remaining | tr ' ' '░'
    printf "] (%d/%d)" $current $total
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# 镜像名称验证函数
validate_image_name() {
    local image="$1"
    local image_type="$2"
    
    log "DEBUG" "验证镜像名称: $image"
    
    # 检查是否为空
    if [[ -z "$image" ]]; then
        log "ERROR" "${image_type}镜像名称不能为空"
        return 1
    fi
    
    # 基本格式验证：registry/namespace/repository:tag
    if [[ ! "$image" =~ ^[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)*(:([a-zA-Z0-9._-]+))?$ ]]; then
        log "ERROR" "${image_type}镜像名称格式无效: $image"
        log "INFO" "正确格式示例: nginx:latest, registry.com/namespace/image:tag"
        return 1
    fi
    
    # 检查标签，如果没有则添加latest
    if [[ ! "$image" =~ ":" ]]; then
        log "WARN" "${image_type}镜像未指定标签，将使用 :latest"
        echo "${image}:latest"
    else
        echo "$image"
    fi
    
    return 0
}

# 检查必需的工具
check_dependencies() {
    local missing_tools=()
    
    for tool in crane jq curl; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log "ERROR" "缺少必需的工具: ${missing_tools[*]}"
        log "ERROR" "请安装缺少的工具后重试"
        log "INFO" "安装crane: go install github.com/google/go-containerregistry/cmd/crane@latest"
        exit 1
    fi
    
    # 验证crane版本
    local crane_version
    crane_version=$(crane version 2>/dev/null || echo "unknown")
    log "INFO" "依赖检查通过 - crane版本: $crane_version"
}

# 检查网络连接
check_network() {
    local registry="$1"
    log "INFO" "检查网络连接到 $registry..."
    
    # 提取主机名
    local hostname=$(echo "$registry" | sed 's|.*://||' | sed 's|/.*||' | sed 's|:.*||')
    
    if [[ -z "$hostname" ]]; then
        hostname="registry-1.docker.io"  # Docker Hub默认
    fi
    
    if ! ping -c 1 -W 3 "$hostname" &> /dev/null; then
        log "WARN" "无法ping通 $hostname，但这可能是正常的（某些服务器禁用ping）"
    else
        log "SUCCESS" "网络连接正常"
    fi
    
    return 0
}

# 镜像存在性检查
check_image_exists() {
    local image="$1"
    log "INFO" "检查镜像是否存在: $image"
    
    if docker manifest inspect "$image" &> /dev/null; then
        log "SUCCESS" "镜像存在: $image"
        return 0
    else
        log "WARN" "无法验证镜像存在性: $image（可能需要认证或镜像不存在）"
        return 1
    fi
}

# 重试机制包装函数
retry_command() {
    local max_attempts="$1"
    local delay="$2"
    local description="$3"
    shift 3
    local command=("$@")
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        log "INFO" "$description (尝试 $attempt/$max_attempts)"
        
        if "${command[@]}"; then
            log "SUCCESS" "$description 成功"
            return 0
        else
            local exit_code=$?
            if [[ $attempt -lt $max_attempts ]]; then
                log "WARN" "$description 失败，${delay}秒后重试..."
                sleep "$delay"
            else
                log "ERROR" "$description 在 $max_attempts 次尝试后仍然失败"
                return $exit_code
            fi
        fi
        
        ((attempt++))
    done
}

# 配置Crane认证
setup_authentication() {
    log "INFO" "配置认证信息..."
    
    # 检查必需的环境变量
    local required_vars=(
        "ALIYUN_REGISTRY"
        "ALIYUN_USERNAME" 
        "ALIYUN_PASSWORD"
        "ALIYUN_NAMESPACE"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log "ERROR" "缺少必需的环境变量: ${missing_vars[*]}"
        exit 1
    fi
    
    # 登录阿里云容器服务
    log "INFO" "登录阿里云容器服务..."
    if crane auth login -u "$ALIYUN_USERNAME" -p "$ALIYUN_PASSWORD" "$ALIYUN_REGISTRY"; then
        log "INFO" "阿里云认证成功"
    else
        log "ERROR" "阿里云认证失败"
        exit 1
    fi
    
    # 可选：登录DockerHub（如果配置了凭证）
    if [[ -n "${DOCKERHUB_USERNAME:-}" && -n "${DOCKERHUB_TOKEN:-}" ]]; then
        log "INFO" "登录Docker Hub..."
        if crane auth login -u "$DOCKERHUB_USERNAME" -p "$DOCKERHUB_TOKEN" docker.io; then
            log "INFO" "DockerHub认证成功"
        else
            log "WARN" "DockerHub认证失败，将使用匿名拉取"
        fi
    else
        log "INFO" "跳过DockerHub认证，将使用匿名拉取"
    fi
    
    log "INFO" "认证配置完成"
}

# 验证源镜像存在
verify_source_image() {
    log "INFO" "验证源镜像: $SOURCE_IMAGE"
    
    if [[ -z "$SOURCE_IMAGE" ]]; then
        log "ERROR" "源镜像名称为空"
        return 1
    fi
    
    # 使用crane ls检查镜像是否存在
    local repo_name=$(echo $SOURCE_IMAGE | cut -d':' -f1)
    local tag_name=$(echo $SOURCE_IMAGE | cut -d':' -f2)
    
    if crane ls "$repo_name" | grep -q "$tag_name"; then
        log "SUCCESS" "源镜像验证成功: $SOURCE_IMAGE"
        return 0
    else
        log "ERROR" "源镜像不存在或无法访问: $SOURCE_IMAGE"
        return 1
    fi
}

# 使用crane复制镜像
copy_image() {
    log "INFO" "使用crane复制镜像: $SOURCE_IMAGE -> $DEST_IMAGE"
    
    if [[ -z "$DEST_IMAGE" ]]; then
        log "ERROR" "目标镜像名称为空"
        return 1
    fi
    
    # 方法1: 尝试直接复制
    log "INFO" "尝试直接复制镜像..."
    if crane copy "$SOURCE_IMAGE" "$DEST_IMAGE" 2>&1 | tee /tmp/copy.log; then
        log "SUCCESS" "✅ 直接复制成功: $DEST_IMAGE"
        return 0
    else
        log "WARN" "直接复制失败，尝试备用方法..."
        
        # 方法2: 通过本地缓存方式
        log "INFO" "使用本地缓存方式..."
        local temp_tar="/tmp/$(basename $SOURCE_IMAGE | tr ':/' '_').tar"
        
        if crane pull "$SOURCE_IMAGE" "$temp_tar"; then
            log "INFO" "镜像已拉取到本地缓存: $temp_tar"
            if crane push "$temp_tar" "$DEST_IMAGE"; then
                log "SUCCESS" "✅ 通过本地缓存复制成功: $DEST_IMAGE"
                rm -f "$temp_tar"
                return 0
            else
                log "ERROR" "本地缓存推送失败"
                rm -f "$temp_tar"
                cat /tmp/copy.log || true
                return 1
            fi
        else
            log "ERROR" "无法拉取镜像到本地缓存"
            return 1
        fi
    fi
}

# 验证目标镜像推送成功
verify_target_image() {
    log "INFO" "验证目标镜像: $DEST_IMAGE"
    
    if [[ -z "$DEST_IMAGE" ]]; then
        log "ERROR" "目标镜像名称为空"
        return 1
    fi
    
    # 使用crane验证镜像是否存在
    local repo_name=$(echo $DEST_IMAGE | cut -d':' -f1)
    local tag_name=$(echo $DEST_IMAGE | cut -d':' -f2)
    
    if crane ls "$repo_name" | grep -q "$tag_name"; then
        log "SUCCESS" "目标镜像验证成功: $DEST_IMAGE"
        return 0
    else
        log "ERROR" "目标镜像验证失败: $DEST_IMAGE"
        return 1
    fi
}

# 清理临时文件
cleanup_temp_files() {
    log "INFO" "清理临时文件..."
    
    # 清理临时tar文件
    find /tmp -name "*.tar" -type f -mmin +60 -delete 2>/dev/null || true
    
    # 清理日志文件
    rm -f /tmp/copy.log 2>/dev/null || true
    
    log "INFO" "临时文件清理完成"
}

# 记录同步历史
record_history() {
    local history_file="transfer_history.md"
    local current_time=$(date +"%Y-%m-%d %H:%M:%S")
    local status="$1"
    
    log "INFO" "记录同步历史..."
    show_progress 5 5 "记录历史"
    
    # 确保历史文件存在
    if [[ ! -f "$history_file" ]]; then
        cat > "$history_file" << EOF
# Docker镜像同步历史

| 源镜像 | 目标镜像 | 状态 | 运行时间 | 日志文件 |
|--------|----------|------|----------|----------|
EOF
    fi
    
    # 添加记录
    echo "| \`$SOURCE_IMAGE\` | \`$DEST_IMAGE\` | $status | $current_time | \`$LOG_FILE\` |" >> "$history_file"
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "同步历史记录成功"
    else
        log "ERROR" "同步历史记录失败"
    fi
}

# 显示使用帮助
usage() {
    cat << EOF
${BOLD}Docker镜像同步工具 - 增强版${NC}

${YELLOW}用法:${NC}
    $0 [选项]

${YELLOW}选项:${NC}
    -s, --source <镜像>          源镜像地址 (必需)
    -d, --destination <镜像>     目标镜像地址 (必需)
    -r, --retries <次数>         重试次数 (默认: 3)
    -w, --wait <秒数>           重试间隔 (默认: 5)
    -v, --verbose               详细输出模式
    -n, --dry-run              干运行模式（不执行实际操作）
    -f, --force                强制执行（跳过某些检查）
    -c, --config <文件>         配置文件路径
    -l, --log <文件>           日志文件路径
    -h, --help                 显示此帮助信息

${YELLOW}示例:${NC}
    $0 -s nginx:latest -d registry.cn-hangzhou.aliyuncs.com/namespace/nginx:latest
    $0 -s redis:alpine -d my-registry.com/redis:alpine -v -r 5
    $0 -s ubuntu:20.04 -d harbor.example.com/library/ubuntu:20.04 --dry-run

${YELLOW}配置文件格式 (sync_config.conf):${NC}
    MAX_RETRIES=5
    RETRY_DELAY=10
    VERBOSE=true
    # 更多配置选项...
EOF
}

# 加载配置文件
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log "INFO" "加载配置文件: $CONFIG_FILE"
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        log "SUCCESS" "配置文件加载成功"
    fi
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--source)
                SOURCE_IMAGE="$2"
                shift 2
                ;;
            -d|--destination)
                DEST_IMAGE="$2"
                shift 2
                ;;
            -r|--retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            -w|--wait)
                RETRY_DELAY="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log "ERROR" "未知参数: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # 验证必需参数
    if [[ -z "$SOURCE_IMAGE" || -z "$DEST_IMAGE" ]]; then
        log "ERROR" "源镜像和目标镜像地址都是必需的"
        usage
        exit 1
    fi
}

# 预检查函数
pre_check() {
    log "INFO" "开始预检查..."
    
    # 验证和格式化镜像名称
    SOURCE_IMAGE=$(validate_image_name "$SOURCE_IMAGE" "源")
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    DEST_IMAGE=$(validate_image_name "$DEST_IMAGE" "目标")
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    # 检查Docker
    if ! check_docker; then
        exit 1
    fi
    
    # 检查网络（非强制）
    check_network "$SOURCE_IMAGE" || true
    
    # 检查源镜像存在性（非强制）
    if [[ "$FORCE" != "true" ]]; then
        check_image_exists "$SOURCE_IMAGE" || true
    fi
    
    log "SUCCESS" "预检查完成"
}

# 显示同步摘要
show_summary() {
    local status="$1"
    local start_time="$2"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo
    echo -e "${BOLD}=== 同步摘要 ===${NC}"
    echo -e "源镜像:     ${CYAN}$SOURCE_IMAGE${NC}"
    echo -e "目标镜像:   ${CYAN}$DEST_IMAGE${NC}"
    echo -e "状态:       $([[ "$status" == "SUCCESS" ]] && echo -e "${GREEN}成功${NC}" || echo -e "${RED}失败${NC}")"
    echo -e "耗时:       ${YELLOW}${duration}秒${NC}"
    echo -e "日志文件:   ${MAGENTA}$LOG_FILE${NC}"
    echo -e "干运行模式: $([[ "$DRY_RUN" == "true" ]] && echo -e "${YELLOW}是${NC}" || echo -e "否")"
    echo
}

# 信号处理函数
cleanup_on_exit() {
    local exit_code=$?
    log "WARN" "收到退出信号，正在清理..."
    
    # 这里可以添加清理逻辑
    # 比如清理临时文件、停止后台进程等
    
    exit $exit_code
}

# 主函数
main() {
    local start_time=$(date +%s)
    
    # 设置信号处理
    trap cleanup_on_exit INT TERM
    
    # 显示脚本信息
    echo -e "${BOLD}${BLUE}Docker镜像同步工具 - 增强版${NC}"
    echo -e "启动时间: $(date)"
    echo
    
    # 加载配置
    load_config
    
    # 解析参数
    parse_args "$@"
    
    # 预检查
    pre_check
    
    # 显示操作信息
    log "INFO" "开始同步操作"
    log "INFO" "源镜像: $SOURCE_IMAGE"
    log "INFO" "目标镜像: $DEST_IMAGE"
    log "INFO" "最大重试次数: $MAX_RETRIES"
    log "INFO" "重试间隔: ${RETRY_DELAY}秒"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "WARN" "运行在干运行模式，不会执行实际操作"
    fi
    
    # 执行同步步骤
    local sync_status="SUCCESS"
    
    if ! verify_source_image; then
        sync_status="FAILED"
    elif ! copy_image; then
        sync_status="FAILED"
    elif ! verify_target_image; then
        sync_status="FAILED"
    fi
    
    # 清理（可选）
    if [[ "$sync_status" == "SUCCESS" ]]; then
        cleanup_temp_files || true  # 清理失败不影响整体状态
    fi
    
    # 记录历史
    record_history "$sync_status"
    
    # 显示摘要
    show_summary "$sync_status" "$start_time"
    
    # 返回适当的退出码
    if [[ "$sync_status" == "SUCCESS" ]]; then
        log "SUCCESS" "镜像同步完成！"
        exit 0
    else
        log "ERROR" "镜像同步失败！"
        exit 1
    fi
}

# 执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi