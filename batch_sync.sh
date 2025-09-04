#!/bin/bash

# 批量Docker镜像同步脚本
# 支持并发处理、高级错误处理和配置文件管理

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 导入配置
if [[ -f "sync_config.conf" ]]; then
    # shellcheck source=sync_config.conf
    source "sync_config.conf"
fi

# 设置默认值
MAX_PARALLEL=${MAX_PARALLEL:-3}
MAX_RETRIES=${MAX_RETRIES:-3}
RETRY_DELAY=${RETRY_DELAY:-5}
VERBOSE=${VERBOSE:-false}
DRY_RUN=${DRY_RUN:-false}
FORCE=${FORCE:-false}
CLEANUP_ON_SUCCESS=${CLEANUP_ON_SUCCESS:-true}
SKIP_EXISTING=${SKIP_EXISTING:-true}
LOG_LEVEL=${LOG_LEVEL:-INFO}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 全局变量
LOG_FILE="batch_sync_$(date +%Y%m%d_%H%M%S).log"
STATS_FILE="sync_stats_$(date +%Y%m%d_%H%M%S).json"
FAILED_IMAGES_FILE="failed_images_$(date +%Y%m%d_%H%M%S).txt"
PID_FILE="batch_sync.pid"
START_TIME=$(date +%s)

# 统计变量
TOTAL_IMAGES=0
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0
RETRY_COUNT=0

# 进程管理
declare -a RUNNING_PIDS=()
declare -A IMAGE_STATUS=()
declare -A IMAGE_LOGS=()
declare -A IMAGE_START_TIME=()

# 日志函数
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color="$NC"
    
    case "$level" in
        "DEBUG") [[ "$VERBOSE" != "true" ]] && return; color="$MAGENTA" ;;
        "INFO") color="$CYAN" ;;
        "WARN") color="$YELLOW" ;;
        "ERROR") color="$RED" ;;
        "SUCCESS") color="$GREEN" ;;
    esac
    
    echo -e "${color}[${level}]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
}

# 进度显示函数
show_progress() {
    local current=$1
    local total=$2
    local status="$3"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${BLUE}进度:${NC} %3d%% [" "$percentage"
    printf "%*s" $completed | tr ' ' '█'
    printf "%*s" $remaining | tr ' ' '░'
    printf "] (%d/%d) %s" $current $total "$status"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# 统计信息更新
update_stats() {
    local status="$1"
    case "$status" in
        "success") ((SUCCESS_COUNT++)) ;;
        "failed") ((FAILED_COUNT++)) ;;
        "skipped") ((SKIPPED_COUNT++)) ;;
        "retry") ((RETRY_COUNT++)) ;;
    esac
}

# 生成统计报告
generate_stats() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    cat > "$STATS_FILE" << EOF
{
  "summary": {
    "startTime": "$(date -d @$START_TIME '+%Y-%m-%d %H:%M:%S')",
    "endTime": "$(date -d @$end_time '+%Y-%m-%d %H:%M:%S')",
    "duration": $duration,
    "totalImages": $TOTAL_IMAGES,
    "successCount": $SUCCESS_COUNT,
    "failedCount": $FAILED_COUNT,
    "skippedCount": $SKIPPED_COUNT,
    "retryCount": $RETRY_COUNT,
    "successRate": $(( TOTAL_IMAGES > 0 ? SUCCESS_COUNT * 100 / TOTAL_IMAGES : 0 ))
  },
  "details": {
EOF
    
    local first=true
    for image in "${!IMAGE_STATUS[@]}"; do
        [[ "$first" == "true" ]] && first=false || echo "," >> "$STATS_FILE"
        local status="${IMAGE_STATUS[$image]}"
        local start_time="${IMAGE_START_TIME[$image]:-$START_TIME}"
        local image_duration=$((end_time - start_time))
        
        cat >> "$STATS_FILE" << EOF
    "$image": {
      "status": "$status",
      "startTime": "$(date -d @$start_time '+%Y-%m-%d %H:%M:%S')",
      "duration": $image_duration,
      "logFile": "${IMAGE_LOGS[$image]:-}"
    }EOF
    done
    
    echo -e "\n  }\n}" >> "$STATS_FILE"
}

# 清理函数
cleanup() {
    log "INFO" "正在清理资源..."
    
    # 终止所有子进程
    for pid in "${RUNNING_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            log "WARN" "终止进程 $pid"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 2
            kill -KILL "$pid" 2>/dev/null || true
        fi
    done
    
    # 删除PID文件
    [[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"
    
    # 生成最终统计
    generate_stats
    
    log "INFO" "清理完成"
}

# 信号处理
trap cleanup EXIT INT TERM

# 检查是否已有实例在运行
check_running_instance() {
    if [[ -f "$PID_FILE" ]]; then
        local old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log "ERROR" "检测到另一个实例正在运行 (PID: $old_pid)"
            exit 1
        else
            log "WARN" "发现过期的PID文件，正在清理"
            rm -f "$PID_FILE"
        fi
    fi
    
    echo $$ > "$PID_FILE"
}

# 验证镜像格式
validate_image() {
    local image="$1"
    
    if [[ ! "$image" =~ ^[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)*(:([a-zA-Z0-9._-]+))?$ ]]; then
        log "ERROR" "无效的镜像格式: $image"
        return 1
    fi
    
    # 添加默认标签
    if [[ ! "$image" =~ ":" ]]; then
        echo "${image}:latest"
    else
        echo "$image"
    fi
}

# 检查镜像是否已处理
check_if_processed() {
    local image="$1"
    local done_marker="done/${image//[\/:]/_}.txt"
    
    if [[ "$SKIP_EXISTING" == "true" && "$FORCE" != "true" && -f "$done_marker" ]]; then
        return 0  # 已处理
    else
        return 1  # 未处理
    fi
}

# 同步单个镜像（后台进程）
sync_single_image() {
    local image="$1"
    local image_log="logs/batch_${image//[\/:]/_}_$(date +%Y%m%d_%H%M%S).log"
    
    # 记录开始时间
    IMAGE_START_TIME["$image"]=$(date +%s)
    IMAGE_LOGS["$image"]="$image_log"
    
    # 创建日志目录
    mkdir -p "$(dirname "$image_log")"
    
    {
        log "INFO" "开始同步镜像: $image"
        
        # 检查是否已处理
        if check_if_processed "$image"; then
            log "INFO" "镜像已处理，跳过: $image"
            IMAGE_STATUS["$image"]="skipped"
            update_stats "skipped"
            return 0
        fi
        
        # 构建目标镜像路径
        local image_name=$(echo "$image" | cut -d':' -f1)
        local image_tag=$(echo "$image" | grep ':' > /dev/null && echo "$image" | cut -d':' -f2 || echo "latest")
        local repo_name=$(echo "$image_name" | rev | cut -d'/' -f1 | rev)
        
        # 这里应该从配置或环境变量获取
        local target_registry="registry.cn-hangzhou.aliyuncs.com"
        local target_namespace="your-namespace"
        local target_image="${target_registry}/${target_namespace}/${repo_name}:${image_tag}"
        
        # 调用增强版同步脚本
        local sync_args=(
            "-s" "$image"
            "-d" "$target_image"
            "-r" "$MAX_RETRIES"
            "-w" "$RETRY_DELAY"
            "-l" "$image_log"
        )
        
        [[ "$VERBOSE" == "true" ]] && sync_args+=("--verbose")
        [[ "$DRY_RUN" == "true" ]] && sync_args+=("--dry-run")
        [[ "$FORCE" == "true" ]] && sync_args+=("--force")
        
        if "$SCRIPT_DIR/transfer_enhanced.sh" "${sync_args[@]}"; then
            log "SUCCESS" "镜像同步成功: $image -> $target_image"
            IMAGE_STATUS["$image"]="success"
            update_stats "success"
            
            # 标记为已处理
            local done_marker="done/${image//[\/:]/_}.txt"
            mkdir -p "$(dirname "$done_marker")"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $image -> $target_image" > "$done_marker"
        else
            log "ERROR" "镜像同步失败: $image"
            IMAGE_STATUS["$image"]="failed"
            update_stats "failed"
            
            # 记录失败的镜像
            echo "$image" >> "$FAILED_IMAGES_FILE"
        fi
        
    } 2>&1 | tee -a "$image_log"
}

# 等待进程完成
wait_for_processes() {
    local max_wait=${1:-3600}  # 默认最大等待1小时
    local wait_start=$(date +%s)
    
    while [[ ${#RUNNING_PIDS[@]} -gt 0 ]]; do
        local new_pids=()
        
        for pid in "${RUNNING_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                new_pids+=("$pid")
            else
                wait "$pid" 2>/dev/null || true
            fi
        done
        
        RUNNING_PIDS=("${new_pids[@]}")
        
        # 检查超时
        local current_time=$(date +%s)
        if [[ $((current_time - wait_start)) -gt $max_wait ]]; then
            log "WARN" "等待进程超时，强制终止剩余进程"
            for pid in "${RUNNING_PIDS[@]}"; do
                kill -TERM "$pid" 2>/dev/null || true
            done
            sleep 5
            for pid in "${RUNNING_PIDS[@]}"; do
                kill -KILL "$pid" 2>/dev/null || true
            done
            break
        fi
        
        sleep 1
    done
}

# 处理镜像列表
process_images() {
    local images_file="$1"
    local images=()
    
    log "INFO" "读取镜像列表: $images_file"
    
    # 读取镜像列表
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | tr -d '\r' | xargs)
        [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
        
        if validated_image=$(validate_image "$line"); then
            images+=("$validated_image")
        else
            log "WARN" "跳过无效镜像: $line"
        fi
    done < "$images_file"
    
    TOTAL_IMAGES=${#images[@]}
    log "INFO" "找到 $TOTAL_IMAGES 个有效镜像"
    
    if [[ $TOTAL_IMAGES -eq 0 ]]; then
        log "ERROR" "没有找到有效的镜像"
        return 1
    fi
    
    # 创建必要的目录
    mkdir -p done logs temp
    
    # 并发处理镜像
    local processed=0
    for image in "${images[@]}"; do
        # 控制并发数
        while [[ ${#RUNNING_PIDS[@]} -ge $MAX_PARALLEL ]]; do
            local new_pids=()
            for pid in "${RUNNING_PIDS[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    new_pids+=("$pid")
                else
                    wait "$pid" 2>/dev/null || true
                    ((processed++))
                    show_progress $processed $TOTAL_IMAGES "处理中..."
                fi
            done
            RUNNING_PIDS=("${new_pids[@]}")
            sleep 0.1
        done
        
        # 启动新的同步进程
        sync_single_image "$image" &
        local pid=$!
        RUNNING_PIDS+=("$pid")
        
        log "DEBUG" "启动同步进程: $image (PID: $pid)"
    done
    
    # 等待所有进程完成
    log "INFO" "等待所有同步进程完成..."
    wait_for_processes
    
    show_progress $TOTAL_IMAGES $TOTAL_IMAGES "完成"
}

# 处理JSON配置文件
process_json_config() {
    local json_file="$1"
    
    if ! command -v jq &> /dev/null; then
        log "ERROR" "需要安装jq来处理JSON配置文件"
        return 1
    fi
    
    log "INFO" "处理JSON配置文件: $json_file"
    
    # 提取配置
    local config_max_parallel=$(jq -r '.config.maxParallel // 3' "$json_file")
    local config_max_retries=$(jq -r '.config.maxRetries // 3' "$json_file")
    local config_dry_run=$(jq -r '.config.dryRun // false' "$json_file")
    
    # 应用配置
    MAX_PARALLEL="$config_max_parallel"
    MAX_RETRIES="$config_max_retries"
    DRY_RUN="$config_dry_run"
    
    # 提取镜像列表
    local temp_images_file="temp/images_from_json.txt"
    jq -r '.images[].source' "$json_file" > "$temp_images_file"
    
    process_images "$temp_images_file"
}

# 显示使用帮助
usage() {
    cat << EOF
${BOLD}Docker镜像批量同步工具${NC}

${YELLOW}用法:${NC}
    $0 [选项] <镜像列表文件>

${YELLOW}选项:${NC}
    -c, --config <文件>         配置文件路径 (默认: sync_config.conf)
    -j, --json <文件>          JSON配置文件路径
    -p, --parallel <数量>       最大并发数 (默认: 3)
    -r, --retries <次数>        重试次数 (默认: 3)
    -w, --wait <秒数>          重试间隔 (默认: 5)
    -v, --verbose              详细输出模式
    -n, --dry-run             干运行模式
    -f, --force               强制同步（忽略已处理标记）
    --no-cleanup              不清理成功的本地镜像
    --no-skip                 不跳过已存在的镜像
    -h, --help                显示此帮助信息

${YELLOW}示例:${NC}
    $0 upload/images.md
    $0 -j upload/batch_sync.json
    $0 -p 5 -r 3 -v upload/images.md
    $0 --dry-run upload/images.md

${YELLOW}文件格式:${NC}
    镜像列表文件: 每行一个镜像名称
    JSON配置文件: 参考 upload/batch_sync.json 模板
EOF
}

# 主函数
main() {
    local config_file="sync_config.conf"
    local json_file=""
    local images_file=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            -j|--json)
                json_file="$2"
                shift 2
                ;;
            -p|--parallel)
                MAX_PARALLEL="$2"
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
            --no-cleanup)
                CLEANUP_ON_SUCCESS=false
                shift
                ;;
            --no-skip)
                SKIP_EXISTING=false
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log "ERROR" "未知选项: $1"
                usage
                exit 1
                ;;
            *)
                images_file="$1"
                shift
                ;;
        esac
    done
    
    # 检查运行实例
    check_running_instance
    
    # 重新加载配置文件
    if [[ -f "$config_file" ]]; then
        log "INFO" "加载配置文件: $config_file"
        # shellcheck source=/dev/null
        source "$config_file"
    fi
    
    # 显示启动信息
    echo -e "${BOLD}${BLUE}Docker镜像批量同步工具${NC}"
    echo -e "启动时间: $(date)"
    echo -e "最大并发数: $MAX_PARALLEL"
    echo -e "最大重试次数: $MAX_RETRIES"
    echo -e "重试间隔: ${RETRY_DELAY}秒"
    [[ "$DRY_RUN" == "true" ]] && echo -e "${YELLOW}运行模式: 干运行${NC}"
    echo
    
    # 处理输入
    if [[ -n "$json_file" ]]; then
        if [[ ! -f "$json_file" ]]; then
            log "ERROR" "JSON配置文件不存在: $json_file"
            exit 1
        fi
        process_json_config "$json_file"
    elif [[ -n "$images_file" ]]; then
        if [[ ! -f "$images_file" ]]; then
            log "ERROR" "镜像列表文件不存在: $images_file"
            exit 1
        fi
        process_images "$images_file"
    else
        # 尝试默认文件
        if [[ -f "upload/batch_sync.json" ]]; then
            process_json_config "upload/batch_sync.json"
        elif [[ -f "upload/images.md" ]]; then
            process_images "upload/images.md"
        else
            log "ERROR" "请指定镜像列表文件或JSON配置文件"
            usage
            exit 1
        fi
    fi
    
    # 显示最终统计
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    echo
    echo -e "${BOLD}=== 同步完成 ===${NC}"
    echo -e "总镜像数:   ${CYAN}$TOTAL_IMAGES${NC}"
    echo -e "成功:       ${GREEN}$SUCCESS_COUNT${NC}"
    echo -e "失败:       ${RED}$FAILED_COUNT${NC}"
    echo -e "跳过:       ${YELLOW}$SKIPPED_COUNT${NC}"
    echo -e "重试次数:   ${MAGENTA}$RETRY_COUNT${NC}"
    echo -e "总耗时:     ${BLUE}${duration}秒${NC}"
    echo -e "成功率:     $(( TOTAL_IMAGES > 0 ? SUCCESS_COUNT * 100 / TOTAL_IMAGES : 0 ))%"
    echo -e "日志文件:   ${CYAN}$LOG_FILE${NC}"
    echo -e "统计文件:   ${CYAN}$STATS_FILE${NC}"
    [[ $FAILED_COUNT -gt 0 ]] && echo -e "失败列表:   ${RED}$FAILED_IMAGES_FILE${NC}"
    echo
    
    # 返回适当的退出码
    if [[ $FAILED_COUNT -eq 0 ]]; then
        log "SUCCESS" "所有镜像同步完成！"
        exit 0
    else
        log "WARN" "部分镜像同步失败，请查看日志"
        exit 1
    fi
}

# 执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi