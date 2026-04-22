#!/usr/bin/env bash
set -e

# One-command shutdown entrypoint.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"${SCRIPT_DIR}/compose-down.sh"
