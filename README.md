# mihomo-aio

`mihomo-aio` 是一个以 [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) 为核心的容器化代理栈，支持在线启动与离线 VPS 部署。

## 功能概览

- 核心固定为 `mihomo`
- 三容器编排：`subconverter + mihomo-core + dashboard`
- Docker / Podman 双引擎离线部署
- `.env` 统一管理端口、订阅、密钥、远端部署参数
- 脚本化控制：延迟查询、节点切换、订阅热重载、健康检查

## 快速开始（在线）

```bash
cp .env.example .env
# 编辑 .env（至少填写 RAW_SUB_URL）
./scripts/up.sh
```

### 本地切换 Docker / Podman

本地 `./scripts/up.sh` 与 `./scripts/down.sh` 会读取 `.env` 中的 `VPS_DEPLOY_CONTAINER_ENGINE`：

```bash
# Docker（默认）
VPS_DEPLOY_CONTAINER_ENGINE=docker

# Podman
VPS_DEPLOY_CONTAINER_ENGINE=podman
```

Podman 模式要求已安装 `podman` 和 `podman-compose`，并且本地已有镜像（或由 `vps-mihomo-aio-bootstrap.sh` 离线导入后打标签）：

- `localhost/mihomo-core:latest`
- `localhost/subconverter:latest`
- `localhost/mihomo-aio-dashboard:latest`

## 离线 VPS 部署

离线场景（VPS 无外网、无代理）请使用：

```bash
./deploy-remote.sh pack
./deploy-remote.sh upload
# 远端执行
sudo bash vps-mihomo-aio-bootstrap.sh .
```

`pack` 阶段会在本机构建并导出镜像，生成：

- `dist/mihomo-aio-bundle.zip`
- `dist/mihomo-aio-images.tar.gz`（内含 mihomo-core、subconverter、nginx-alpine 离线层）

详细步骤见 `DEPLOYMENT.md`。

## 常用脚本

- 启动容器：`./scripts/up.sh`
- 关闭容器：`./scripts/down.sh`
- 进入核心容器：`./scripts/shell.sh`
- 延迟查询：`./scripts/list-proxies-latency.sh [limit]`
- 按序号切换节点：`./scripts/select-proxy-by-index.sh [limit]`
- 订阅热重载：`./scripts/subscription-hot-reload.sh`
- 健康检查：`./scripts/health-check.sh`
- 冒烟测试：`./scripts/smoke-test.sh`
- API 调试：`./scripts/debug-api.sh`

## 目录

- `docker-compose.yaml`：Docker 编排
- `podman-compose.yaml`：Podman 编排
- `deploy-remote.sh`：离线打包/上传入口
- `vps-mihomo-aio-bootstrap.sh`：远端离线部署启动脚本
- `mihomo-docker-prereq.inc.sh`：Docker 前置安装与换源
- `scripts/`：运维脚本
- `DEPLOYMENT.md`：部署细节

## 许可证

本项目采用 `Apache-2.0` 许可证，详见 `LICENSE` 与 `NOTICE`。
