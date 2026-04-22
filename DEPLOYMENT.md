# 部署说明

## 1. 环境准备

- Docker Engine
- Docker Compose Plugin（支持 `docker compose`）
- 可访问 GitHub Releases（用于构建 mihomo 镜像）

## 2. 配置

```bash
cp .env.example .env
```

建议至少配置：

- `RAW_SUB_URL`（订阅地址）
- `ALL_PROXY_PORT`（宿主机代理端口）
- `CONTROL_PANEL_PORT`（宿主机 Web 管理端口）

可选强化配置：

- `SECRET`（external-controller 鉴权密钥）
- `EXTERNAL_CONTROLLER_PORT`（API 端口）

## 3. 启动

```bash
./scripts/up.sh
```

启动脚本行为：

- 启动容器栈（后台）
- 打印 Web 管理地址
- 启动后返回宿主机终端，不进入容器

## 4. 验证

```bash
./scripts/health-check.sh
./scripts/smoke-test.sh
```

## 5. 运维常用

```bash
# 进入 core 容器（排障）
./scripts/shell.sh

# 订阅热重载
./scripts/subscription-hot-reload.sh

# 查看节点延迟
./scripts/list-proxies-latency.sh 20

# 按序号切换节点
./scripts/select-proxy-by-index.sh 20
```

## 6. 停止

```bash
./scripts/down.sh
```

## 7. 常见问题

- Dashboard 能打开但无数据：
  - 检查 API 地址与 `SECRET`
  - 检查 `EXTERNAL_CONTROLLER_PORT` 映射
- 订阅拉取失败：
  - 检查 `RAW_SUB_URL`
  - 检查 `subconverter` 是否就绪
- 端口冲突：
  - 修改 `.env` 中宿主机端口（如 `CONTROL_PANEL_PORT`、`ALL_PROXY_PORT`）
