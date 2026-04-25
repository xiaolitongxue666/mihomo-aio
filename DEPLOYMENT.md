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

### 2.1.1 端口与现有服务（避免冲突）

本栈对外映射的主机端口全部由 `.env` 决定，**与宿主机上其它进程是否冲突取决于这些取值**。请在 **`./deploy-remote.sh pack` 之前** 选好未占用的端口（改 `.env` 后再打包，zip 内会带上当前 `.env`）。

| 变量 | 含义 |
|------|------|
| `ALL_PROXY_PORT` | 混合代理（mixed）在宿主机上的端口 |
| `EXTERNAL_CONTROLLER_PORT` | mihomo external-controller 在宿主机上的端口 |
| `CONTROL_PANEL_PORT` | Dashboard（nginx）在宿主机上的端口 |
| `SUBCONVERTER_HOST_PORT` | subconverter 在宿主机上的端口 |

**部署前在 VPS 上自检（将下面数字换成你 `.env` 里的值）：**

```bash
ss -tulpen | grep -E ':(17890|19090|19091|25501)\b' || true
```

若无输出，通常表示这些端口当前无监听；若有输出，请在本地改 `.env` 中对应变量后重新 `pack` 并上传。

**对其它服务的影响范围：**

- `vps-mihomo-aio-bootstrap.sh` 里 `podman compose … down` / `up` 只作用于**当前目录下的 `podman-compose.yaml`（或 Docker 下的 `docker-compose.yaml`）**中定义的容器（名称前缀为 `mihomo-aio-*`），**不会**按名字去停掉宿主机上其它 compose 项目或任意容器。
- 若仍担心与其它服务争用端口，请使用**未被占用的高位端口**（示例默认已用 `17890`、`19090`、`19091`、`25501` 一类，可按需再改）。

**仅重启本栈（不重新 bootstrap 全量解压）：**

```bash
cd /opt/mihomo-aio   # 或与 VPS_DEPLOY_DEPLOY_DIR 一致
# Podman
podman compose -f podman-compose.yaml up -d
# 或调整 .env 后
podman compose -f podman-compose.yaml down
podman compose -f podman-compose.yaml up -d
```

### 2.2 本地打包与上传

```bash
./deploy-remote.sh pack
./deploy-remote.sh upload
# 或
./deploy-remote.sh all
```

生成产物：

- `dist/mihomo-aio-bundle.zip`
- `dist/mihomo-aio-images.tar.gz`（内含 `mihomo-core`、`subconverter`、`nginx-alpine` 三层镜像导出，便于无外网环境）

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

- 端口已被占用：`podman compose up` 报错 `address already in use`。在 VPS 上用 `ss -tulpen` 对照 `.env` 中四个发布端口；在本地改 `.env` 后重新 `pack`、`upload`，再在部署目录执行 `podman compose -f podman-compose.yaml down` 与 `up -d`。
- Docker 安装失败：检查远端系统是否 Ubuntu/Debian，确认 `DOCKER_CE_APT_MIRROR`。
- Podman 启动失败：确认 `podman compose` 或 `podman-compose` 至少一个可用。
- Dashboard 无数据：检查 `SECRET` 与 `EXTERNAL_CONTROLLER_PORT`。
- 订阅拉取失败：检查 `RAW_SUB_URL` 与 `subconverter` 容器日志。
