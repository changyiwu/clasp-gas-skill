#!/usr/bin/env bash
# clasp-setup 安裝器的 macOS／Linux 進入點。
#
# 這支「只負責找到 node 並轉呼叫」，安裝邏輯的唯一實作在 scripts/install.mjs。
# 不要在這裡加入任何複製、排除、驗證或路徑判斷邏輯——那正是雙軌漂移的來源，
# validate.ps1 會擋下含有安裝邏輯的殼層。
#
# 用法：
#   bash scripts/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v node >/dev/null 2>&1; then
  echo "找不到 Node.js。clasp v3 需要 Node.js 22 以上，請先安裝：https://nodejs.org/" >&2
  exit 1
fi

exec node "$SCRIPT_DIR/install.mjs" "$@"
