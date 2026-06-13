# TrendRadar Docker 一键部署指南

本文档面向“下载 fork 后直接安装”的场景，配套脚本位于：

```text
trendrader/install-trendradar-docker.sh
```

项目 fork 地址：

```text
https://github.com/heixiaochun/TrendRadar.git
```

## 一键安装

在服务器或本机下载 fork 后执行：

```bash
git clone https://github.com/heixiaochun/TrendRadar.git
cd TrendRadar

bash trendrader/install-trendradar-docker.sh
```

默认行为：

- 检查 Docker 是否可用。
- 检查 `docker compose` 是否可用。
- 确保 `docker/.env` 存在；不存在时自动生成最小配置。
- 拉取 `wantcat/trendradar:latest` 镜像。
- 启动 `trendradar` 核心服务。
- 输出 Web 报告访问地址和常用管理命令。

## 常用安装选项

指定 Web 端口：

```bash
bash trendrader/install-trendradar-docker.sh --port 8090
```

同时启动 MCP 服务：

```bash
bash trendrader/install-trendradar-docker.sh --with-mcp
```

Linux 环境下如果还没有安装 Docker，可以让脚本尝试安装 Docker：

```bash
bash trendrader/install-trendradar-docker.sh --install-docker
```

跳过镜像拉取，直接使用本地镜像启动：

```bash
bash trendrader/install-trendradar-docker.sh --skip-pull
```

只执行一次，不启用定时任务：

```bash
bash trendrader/install-trendradar-docker.sh --once
```

指定定时表达式，例如每 15 分钟运行一次：

```bash
bash trendrader/install-trendradar-docker.sh --cron '*/15 * * * *'
```

查看帮助：

```bash
bash trendrader/install-trendradar-docker.sh --help
```

## Docker 安装说明

### macOS / Windows

推荐安装 Docker Desktop：

- macOS：https://docs.docker.com/desktop/setup/install/mac-install/
- Windows：https://docs.docker.com/desktop/setup/install/windows-install/

安装完成后确认：

```bash
docker --version
docker compose version
```

### Linux

推荐优先使用官方 Docker Engine 文档：

```text
https://docs.docker.com/engine/install/
```

如果你信任当前环境，也可以用本目录脚本自动安装：

```bash
bash trendrader/install-trendradar-docker.sh --install-docker
```

脚本会调用 Docker 官方安装脚本。安装完成后，当前用户可能需要重新登录，或者手动运行：

```bash
sudo usermod -aG docker "$USER"
```

如果不想重新登录，可以临时使用：

```bash
newgrp docker
```

## 配置文件

主要配置文件：

```text
config/config.yaml
config/frequency_words.txt
docker/.env
```

配置分工：

- `config/config.yaml`：平台开关、RSS、推送模式、AI 分析等功能配置。
- `config/frequency_words.txt`：关注关键词。
- `docker/.env`：Webhook、API Key、端口、定时任务等环境变量。

敏感信息只放在 `docker/.env`，不要写入公开文档、日志或提交记录。

## 服务组成

核心服务：

```text
trendradar
```

负责热点抓取、报告生成、Web 报告和推送。大多数用户只需要这个服务。

可选服务：

```text
trendradar-mcp
```

用于 MCP / AI 分析相关能力，需要时再通过 `--with-mcp` 启动。

## 访问报告

默认端口是 `8080`：

```text
http://localhost:8080
```

如果部署在远程服务器，需要使用服务器 IP 或域名：

```text
http://服务器IP:8080
```

注意：当前 `docker/docker-compose.yml` 默认绑定 `127.0.0.1`，只允许本机访问。如需外部访问，需要调整端口绑定或使用反向代理。

## 常用运维命令

进入 Docker 目录：

```bash
cd docker
```

查看日志：

```bash
docker logs -f trendradar
```

查看容器状态：

```bash
docker compose ps
```

手动运行一次任务：

```bash
docker exec -it trendradar python manage.py run
```

查看容器内部状态：

```bash
docker exec -it trendradar python manage.py status
```

查看当前配置：

```bash
docker exec -it trendradar python manage.py config
```

停止服务：

```bash
docker compose stop trendradar
```

重启服务：

```bash
docker compose restart trendradar
```

更新镜像并重启：

```bash
docker compose pull
docker compose up -d
```

## 推荐流程

1. 下载 fork：

```bash
git clone https://github.com/heixiaochun/TrendRadar.git
cd TrendRadar
```

2. 修改关键词：

```bash
vim config/frequency_words.txt
```

3. 修改推送和 AI 配置：

```bash
vim docker/.env
vim config/config.yaml
```

4. 一键启动：

```bash
bash trendrader/install-trendradar-docker.sh
```

5. 查看日志：

```bash
docker logs -f trendradar
```

## 排查建议

- 启动失败：先运行 `docker compose version`，确认 Docker Compose 插件可用。
- 拉镜像失败：检查服务器网络，或稍后重试 `docker compose pull`。
- 端口冲突：使用 `--port 8090` 或修改 `docker/.env` 的 `WEBSERVER_PORT`。
- 报告为空：检查 `config/frequency_words.txt`、平台开关和网络访问。
- 收不到推送：检查 `docker/.env` 中的 Webhook、Token、API Key。
- 远程无法访问报告：确认 `docker-compose.yml` 端口绑定、服务器防火墙和反向代理配置。
