#!/usr/bin/env bash
# 安装到 ubuntu crontab 的模板（与生产 2026-09-16 对照）。
# 生产历史树：/home/ubuntu/Code/VPN/mihomo-aio
# 本机不要提交 .env。不要把 RAW_SUB_URL 写进本文件。
#
# crontab -e（用户 ubuntu）：
# 0 1 * * * cd /home/ubuntu/Code/VPN/mihomo-aio && ./scripts/subscription-hot-reload.sh >> /home/ubuntu/Code/VPN/mihomo-aio/logs/subscription-hot-reload.log 2>&1
#
# 安装前确认：
# - 该目录已有可读 .env（含 RAW_SUB_URL）
# - mixed 仍是 127.0.0.1:17890；danted 是 17891，本脚本不走 danted
set -euo pipefail
echo "这是模板，请把上面 crontab 行复制到目标机。不在本机执行。"
exit 1
