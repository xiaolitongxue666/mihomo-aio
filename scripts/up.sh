#!/usr/bin/env bash
set -e

# One-command startup entrypoint.
# Starts containers and prints web URL, then exits to host shell.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"${SCRIPT_DIR}/compose-up.sh"
