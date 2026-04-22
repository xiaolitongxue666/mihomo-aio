#!/usr/bin/env bash
set -e

# Smoke test: start stack, run health check, and sample proxy latency.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$ROOT_DIR"

echo "[1/4] 启动容器栈"
./scripts/up.sh

echo "[2/4] 等待服务稳定"
sleep 8

echo "[3/4] 执行健康检查"
./scripts/health-check.sh

echo "[4/4] 抽样测延迟（前10个节点）"
./scripts/list-proxies-latency.sh 10 || true

echo "smoke-test 完成"
