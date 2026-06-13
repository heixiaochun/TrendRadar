#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKER_DIR="${PROJECT_ROOT}/docker"
ENV_FILE="${DOCKER_DIR}/.env"

WITH_MCP=false
INSTALL_DOCKER=false
SKIP_PULL=false
WEB_PORT=""
CRON_SCHEDULE_VALUE=""
RUN_MODE_VALUE="cron"
IMMEDIATE_RUN_VALUE="true"

usage() {
  cat <<'USAGE'
TrendRadar Docker 一键安装脚本

用法:
  bash trendrader/install-trendradar-docker.sh [选项]

选项:
  --with-mcp          同时启动 trendradar-mcp 服务
  --install-docker    Linux 环境下自动安装 Docker Engine
  --skip-pull         跳过 docker compose pull
  --port PORT         设置 Web 服务端口，默认使用 docker/.env 或 8080
  --cron EXPR         设置 CRON_SCHEDULE，例如 '*/15 * * * *'
  --once              只运行一次任务，设置 RUN_MODE=once
  -h, --help          显示帮助

示例:
  bash trendrader/install-trendradar-docker.sh
  bash trendrader/install-trendradar-docker.sh --port 8090
  bash trendrader/install-trendradar-docker.sh --with-mcp
  bash trendrader/install-trendradar-docker.sh --install-docker
USAGE
}

log() {
  printf '\n[TrendRadar] %s\n' "$1"
}

die() {
  printf '\n[TrendRadar] 错误：%s\n' "$1" >&2
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with-mcp)
        WITH_MCP=true
        shift
        ;;
      --install-docker)
        INSTALL_DOCKER=true
        shift
        ;;
      --skip-pull)
        SKIP_PULL=true
        shift
        ;;
      --port)
        [[ $# -ge 2 ]] || die "--port 需要端口参数"
        WEB_PORT="$2"
        shift 2
        ;;
      --cron)
        [[ $# -ge 2 ]] || die "--cron 需要 cron 表达式"
        CRON_SCHEDULE_VALUE="$2"
        shift 2
        ;;
      --once)
        RUN_MODE_VALUE="once"
        IMMEDIATE_RUN_VALUE="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "未知参数：$1"
        ;;
    esac
  done
}

ensure_project_layout() {
  [[ -d "${DOCKER_DIR}" ]] || die "未找到 docker 目录：${DOCKER_DIR}"
  [[ -f "${DOCKER_DIR}/docker-compose.yml" ]] || die "未找到 docker-compose.yml"
  [[ -d "${PROJECT_ROOT}/config" ]] || die "未找到 config 目录：${PROJECT_ROOT}/config"
}

has_docker() {
  command -v docker >/dev/null 2>&1
}

has_compose() {
  docker compose version >/dev/null 2>&1
}

install_docker_linux() {
  [[ "$(uname -s)" == "Linux" ]] || die "--install-docker 仅支持 Linux；macOS/Windows 请安装 Docker Desktop"
  command -v curl >/dev/null 2>&1 || die "需要 curl 才能安装 Docker"

  log "准备通过 Docker 官方脚本安装 Docker Engine"
  log "官方脚本地址：https://get.docker.com"

  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh

  if command -v sudo >/dev/null 2>&1; then
    sudo usermod -aG docker "$USER" || true
  fi

  log "Docker 安装完成。如果当前用户仍无权限，请重新登录或执行：newgrp docker"
}

ensure_docker() {
  if ! has_docker; then
    if [[ "${INSTALL_DOCKER}" == "true" ]]; then
      install_docker_linux
    else
      die "未检测到 docker。请先安装 Docker，或在 Linux 上使用 --install-docker"
    fi
  fi

  if ! docker info >/dev/null 2>&1; then
    die "Docker daemon 不可用。请启动 Docker Desktop 或 Docker 服务"
  fi

  if ! has_compose; then
    die "未检测到 docker compose 插件。请安装 Docker Compose v2"
  fi
}

ensure_env_file() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    log "未找到 docker/.env，生成最小配置"
    cat > "${ENV_FILE}" <<'EOF'
WEBSERVER_PORT=8080
CRON_SCHEDULE=*/30 * * * *
RUN_MODE=cron
IMMEDIATE_RUN=true

FEISHU_WEBHOOK_URL=
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
DINGTALK_WEBHOOK_URL=
WEWORK_WEBHOOK_URL=
WEWORK_MSG_TYPE=
EMAIL_FROM=
EMAIL_PASSWORD=
EMAIL_TO=
EMAIL_SMTP_SERVER=
EMAIL_SMTP_PORT=
NTFY_SERVER_URL=
NTFY_TOPIC=
NTFY_TOKEN=
BARK_URL=
SLACK_WEBHOOK_URL=
GENERIC_WEBHOOK_URL=
GENERIC_WEBHOOK_TEMPLATE=

AI_ANALYSIS_ENABLED=
AI_API_KEY=
AI_MODEL=
AI_API_BASE=

S3_ENDPOINT_URL=
S3_BUCKET_NAME=
S3_ACCESS_KEY_ID=
S3_SECRET_ACCESS_KEY=
S3_REGION=
EOF
  fi
}

set_env_value() {
  local key="$1"
  local value="$2"
  local escaped
  escaped="$(printf '%s' "$value" | sed 's/[\\&|]/\\&/g')"

  if grep -q "^${key}=" "${ENV_FILE}"; then
    sed -i.bak "s|^${key}=.*|${key}=${escaped}|" "${ENV_FILE}"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${ENV_FILE}"
  fi
}

configure_env() {
  ensure_env_file

  if [[ -n "${WEB_PORT}" ]]; then
    [[ "${WEB_PORT}" =~ ^[0-9]+$ ]] || die "端口必须是数字：${WEB_PORT}"
    if (( WEB_PORT < 1 || WEB_PORT > 65535 )); then
      die "端口范围必须是 1-65535：${WEB_PORT}"
    fi
    set_env_value "WEBSERVER_PORT" "${WEB_PORT}"
  fi

  if [[ -n "${CRON_SCHEDULE_VALUE}" ]]; then
    set_env_value "CRON_SCHEDULE" "${CRON_SCHEDULE_VALUE}"
  fi

  set_env_value "RUN_MODE" "${RUN_MODE_VALUE}"
  set_env_value "IMMEDIATE_RUN" "${IMMEDIATE_RUN_VALUE}"
}

compose() {
  (cd "${DOCKER_DIR}" && docker compose "$@")
}

start_services() {
  local services=("trendradar")
  if [[ "${WITH_MCP}" == "true" ]]; then
    services+=("trendradar-mcp")
  fi

  if [[ "${SKIP_PULL}" != "true" ]]; then
    log "拉取 Docker 镜像"
    compose pull "${services[@]}"
  fi

  log "启动服务：${services[*]}"
  compose up -d "${services[@]}"
}

show_next_steps() {
  local port
  port="$(grep '^WEBSERVER_PORT=' "${ENV_FILE}" | tail -n 1 | cut -d= -f2-)"
  port="${port:-8080}"

  log "部署完成"
  printf 'Web 报告本机访问：http://localhost:%s\n' "${port}"
  printf '\n常用命令：\n'
  printf '  docker logs -f trendradar\n'
  printf '  docker compose -f docker/docker-compose.yml ps\n'
  printf '  docker exec -it trendradar python manage.py run\n'
  printf '  docker exec -it trendradar python manage.py status\n'
  printf '\n配置文件：\n'
  printf '  config/config.yaml\n'
  printf '  config/frequency_words.txt\n'
  printf '  docker/.env\n'
}

main() {
  parse_args "$@"
  ensure_project_layout
  ensure_docker
  configure_env
  start_services
  show_next_steps
}

main "$@"
