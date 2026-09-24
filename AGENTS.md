# mihomo-aio — Agent 入口

业务出站代理。订阅 URL 只写本地 `.env`，勿提交。

## 端口

| 角色 | 宿主机（loopback） | 容器内 |
|------|-------------------|--------|
| mixed / `HTTP_PROXY` | **17890** | 7890 |
| 外部控制器 | 19090 | 19090（与 `.env` 同变量） |
| 面板 | 19091 | 80（nginx dashboard） |
| subconverter | 25501 | 25500 |

面板 `:19091` 勿当业务入口、勿改契约。业务 compose 的 `HTTP_PROXY` 只指 `127.0.0.1:17890`。construct 仍可能装 danted `:17891`，本仓不使用。

无 `.env` 时 compose 默认值必须与上表一致（勿回退 Clash 默认 7890/9090/9091）。

## 路径

- 本机：`Code/VPS/mihomo-aio`
- 生产独立栈：`/home/ubuntu/Code/VPS/mihomo-aio`
- rss 仓内另有 **submodule 副本**：只消费，勿 `git submodule update --remote`，勿移出 rss。

## 部署（生产唯一入口）

```bash
./scripts/up.sh
# 订阅热更新：crontab 跑 scripts/subscription-hot-reload.sh
# 回滚：上一 mihomo-aio-mihomo-core 镜像 + 上一 compose；不要 construct bootstrap
```

默认 `up --no-build`；Dockerfile / `MIHOMO_VERSION` 变了才 `--build`。腾讯云 `registry-mirrors` EOF 时经 `mirror.gcr.io` 预拉 alpine，勿重启 dockerd。

## 测试

- **single**：`./scripts/smoke-test.sh` 或 `./scripts/health-check.sh`
- **related**：`curl --noproxy '*' http://127.0.0.1:17890/`（裸 HTTP **400** 算在听）

## 硬约束

- 只绑 `127.0.0.1`。
- rss 生产用 `docker-compose.external-mihomo.override.yml` 时，容器连 `mihomo-aio-core:7890`（容器内 mixed），宿主机脚本仍用 17890。
- 禁止 `compose down -v` / `volume rm`。订阅只在 `.env`。
