#!/bin/bash

# 增强版Docker镜像同步脚本
# 功能：自动化拉取、打标签并推送Docker镜像，包含完整的验证、状态跟踪和错误处理

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

# 检查Docker是否运行
check_docker() {
    log "INFO" "检查Docker服务状态..."
    
    if ! command -v docker &> /dev/null; then
        log "ERROR" "Docker未安装或不在PATH中"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log "ERROR" "Docker服务未运行或无权限访问"
        log "INFO" "请确保Docker服务已启动且当前用户有权限访问"
        return 1
    fi
    
    log "SUCCESS" "Docker服务运行正常"
    return 0
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

# 拉取源镜像
pull_source_image() {
    log "INFO" "开始拉取源镜像: $SOURCE_IMAGE"
    show_progress 1 5 "拉取镜像"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] 模拟拉取镜像: $SOURCE_IMAGE"
        return 0
    fi
    
    retry_command "$MAX_RETRIES" "$RETRY_DELAY" "拉取源镜像" docker pull "$SOURCE_IMAGE"
    
    # 验证镜像是否成功拉取
    if docker image inspect "$SOURCE_IMAGE" &> /dev/null; then
        local image_size=$(docker image inspect "$SOURCE_IMAGE" --format '{{.Size}}' | numfmt --to=iec)
        local image_id=$(docker image inspect "$SOURCE_IMAGE" --format '{{.Id}}' | cut -d':' -f2 | cut -c1-12)
        log "SUCCESS" "源镜像拉取成功！镜像ID: $image_id, 大小: $image_size"
        return 0
    else
        log "ERROR" "镜像拉取后验证失败"
        return 1
    fi
}

# 标签镜像
tag_image() {
    log "INFO" "为镜像打标签: $SOURCE_IMAGE -> $DEST_IMAGE"
    show_progress 2 5 "打标签"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] 模拟打标签: $SOURCE_IMAGE -> $DEST_IMAGE"
        return 0
    fi
    
    if docker tag "$SOURCE_IMAGE" "$DEST_IMAGE"; then
        log "SUCCESS" "镜像标签创建成功"
        return 0
    else
        log "ERROR" "镜像标签创建失败"
        return 1
    fi
}

# 推送目标镜像
push_dest_image() {
    log "INFO" "推送目标镜像: $DEST_IMAGE"
    show_progress 3 5 "推送镜像"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] 模拟推送镜像: $DEST_IMAGE"
        return 0
    fi
    
    retry_command "$MAX_RETRIES" "$RETRY_DELAY" "推送目标镜像" docker push "$DEST_IMAGE"
    
    log "SUCCESS" "目标镜像推送成功！"
    return 0
}

# 清理本地镜像
cleanup_images() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] 模拟清理本地镜像"
        return 0
    fi
    
    log "INFO" "清理本地镜像..."
    show_progress 4 5 "清理镜像"
    
    # 只清理目标标签，保留源镜像
    if docker rmi "$DEST_IMAGE" &> /dev/null; then
        log "SUCCESS" "已清理目标镜像标签: $DEST_IMAGE"
    else
        log "WARN" "清理目标镜像标签失败或镜像不存在"
    fi
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
    
    if ! pull_source_image; then
        sync_status="FAILED"
    elif ! tag_image; then
        sync_status="FAILED"
    elif ! push_dest_image; then
        sync_status="FAILED"
    fi
    
    # 清理（可选）
    if [[ "$sync_status" == "SUCCESS" ]]; then
        cleanup_images || true  # 清理失败不影响整体状态
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