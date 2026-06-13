# TrendRadar 一键 Docker 部署

最短路径：

```bash
git clone https://github.com/heixiaochun/TrendRadar.git
cd TrendRadar
bash trendrader/install-trendradar-docker.sh
```

常用选项：

```bash
# 指定 Web 端口
bash trendrader/install-trendradar-docker.sh --port 8090

# 同时启动 MCP 服务
bash trendrader/install-trendradar-docker.sh --with-mcp

# Linux 上顺手安装 Docker
bash trendrader/install-trendradar-docker.sh --install-docker
```

完整说明见：[TrendRadar-guide.md](./TrendRadar-guide.md)
