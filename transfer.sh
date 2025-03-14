#!/bin/bash

# 自动化拉取、打标签并推送 Docker 镜像脚本，并记录迁移历史

# 设置颜色变量，用于输出提示信息
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印使用说明
usage() {
    echo -e "${YELLOW}Usage:${NC} $0 [OPTIONS]"
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  -s, --source <source_image>      指定要拉取的源镜像地址（格式：registry/repository:tag）"
    echo -e "  -d, --destination <dest_image>    指定目标镜像地址（格式：registry/repository:tag）"
    echo -e "  -h, --help                        显示此帮助信息"
}

# 解析命令行参数
parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -s|--source)
                source_image="$2"
                shift
                ;;
            -d|--destination)
                dest_image="$2"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown parameter $1${NC}"
                usage
                exit 1
                ;;
        esac
        shift
    done

    if [[ -z "$source_image" || -z "$dest_image" ]]; then
        echo -e "${RED}Error: 源镜像或目标镜像地址未设置${NC}"
        usage
        exit 1
    fi
}

# 拉取源镜像
pull_source_image() {
    echo -e "${YELLOW}正在拉取源镜像: ${source_image}${NC}"
    docker pull "${source_image}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}拉取源镜像失败！${NC}"
        exit 1
    else
        echo -e "${GREEN}源镜像拉取成功！${NC}"
    fi
}

# 获取源镜像的 IMAGE ID
get_source_image_id() {
    echo -e "${YELLOW}正在获取源镜像的 IMAGE ID...${NC}"
    source_image_id=$(docker image inspect --format '{{.Id}}' "${source_image}" 2>/dev/null)
    if [ -z "$source_image_id" ]; then
        echo -e "${RED}无法获取源镜像的 IMAGE ID！可能是因为镜像未正确拉取或镜像名有误。${NC}"
        exit 1
    else
        echo -e "${GREEN}源镜像的 IMAGE ID: ${source_image_id}${NC}"
    fi
}

# 打标签为目标镜像
tag_image() {
    echo -e "${YELLOW}正在为目标镜像打标签: ${dest_image}${NC}"
    docker tag "${source_image_id}" "${dest_image}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}为目标镜像打标签失败！${NC}"
        exit 1
    else
        echo -e "${GREEN}为目标镜像打标签成功！${NC}"
    fi
}

# 推送目标镜像到目标仓库
push_dest_image() {
    echo -e "${YELLOW}正在推送目标镜像到目标仓库: ${dest_image}${NC}"
    docker push "${dest_image}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}推送目标镜像失败！请确保已登录目标 registry。${NC}"
        exit 1
    else
        echo -e "${GREEN}目标镜像推送成功！${NC}"
    fi
}

# 记录 transfer 历史到 transfer_history.md
record_transfer_history() {
    local history_file="transfer_history.md"
    local current_time=$(date +"%Y-%m-%d %H:%M:%S")

    # 如果文件不存在，创建文件并写入表头
    if [ ! -f "$history_file" ]; then
        echo "| 源镜像 | 目标镜像 | 运行时间 |" > "$history_file"
        echo "|---|---|---|" >> "$history_file"
    fi

    # 追加记录行
    echo "| ${source_image} | ${dest_image} | ${current_time} |" >> "$history_file"
    if [ $? -ne 0 ]; then
        echo -e "${RED}记录 transfer 历史失败！请检查文件写入权限。${NC}"
    else
        echo -e "${GREEN}transfer 历史记录成功！${NC}"
    fi
}

# 主函数
main() {
    parse_args "$@"
    pull_source_image
    get_source_image_id
    tag_image
    push_dest_image
    record_transfer_history  # 在推送成功后记录历史
}

# 执行主函数
main "$@"