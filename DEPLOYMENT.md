# 部署说明

## 1. 在线部署（有外网）

```bash
cp .env.example .env
# 可选：VPS_DEPLOY_CONTAINER_ENGINE=docker 或 podman
./scripts/up.sh
```

## 2. 离线 VPS 部署（无外网/无代理）

### 2.1 本地准备

1. 复制并填写 `.env`：

```bash
cp .env.example .env
```

2. 重点配置项：

- `RAW_SUB_URL`
- `VPS_DEPLOY_SSH_HOST`
- `VPS_DEPLOY_SSH_USER`
- `VPS_DEPLOY_REMOTE_DIR`
- `VPS_DEPLOY_DEPLOY_DIR`
- `VPS_DEPLOY_CONTAINER_ENGINE`（`docker` 或 `podman`）
- `MIHOMO_SKIP_DOCKER_ENSURE`（`1` 表示跳过 Docker 预装/校验）
- `MIHOMO_SKIP_PODMAN_ENSURE`（`1` 表示跳过 Podman 预装/校验）

### 2.2 本地打包与上传

```bash
./deploy-remote.sh pack
./deploy-remote.sh upload
# 或
./deploy-remote.sh all
```

生成产物：

- `dist/mihomo-aio-bundle.zip`
- `dist/mihomo-aio-images.tar.gz`

### 2.3 远端执行

SSH 到 VPS 后进入上传目录：

```bash
sudo bash vps-mihomo-aio-bootstrap.sh .
```

脚本行为：

- 解压项目 bundle
- 导入离线镜像（`docker load` / `podman load`）
- 预装阶段采用“双预装单运行”：无论 `VPS_DEPLOY_CONTAINER_ENGINE` 选什么，默认都会先校验/安装 Docker 与 Podman（可通过 skip 变量关闭）
- Podman 路径自动对 `localhost/*:latest` 补标签
- Docker 路径可按需自动安装 Docker CE（含 apt 源回退）
- Podman 启动时优先 `podman compose`，回退 `podman-compose`
- 启动 compose 并触发健康检查

## 3. 本地验证（不走 VM）

```bash
# Docker 路径
cp .env.example .env
sed -i.bak 's/^VPS_DEPLOY_CONTAINER_ENGINE=.*/VPS_DEPLOY_CONTAINER_ENGINE=docker/' .env
./scripts/up.sh
./scripts/health-check.sh
./scripts/down.sh

# Podman 路径
sed -i.bak 's/^VPS_DEPLOY_CONTAINER_ENGINE=.*/VPS_DEPLOY_CONTAINER_ENGINE=podman/' .env
./scripts/up.sh
./scripts/health-check.sh
./scripts/down.sh
```

如需完整链路验证，可执行：

```bash
./scripts/smoke-test.sh
```

## 4. 常用运维

```bash
# 在线/离线部署后都可用
./scripts/health-check.sh
./scripts/smoke-test.sh
./scripts/subscription-hot-reload.sh
```

## 5. 常见问题

- Docker 安装失败：检查远端系统是否 Ubuntu/Debian，确认 `DOCKER_CE_APT_MIRROR`。
- Podman 启动失败：确认 `podman compose` 或 `podman-compose` 至少一个可用。
- Dashboard 无数据：检查 `SECRET` 与 `EXTERNAL_CONTROLLER_PORT`。
- 订阅拉取失败：检查 `RAW_SUB_URL` 与 `subconverter` 容器日志。
