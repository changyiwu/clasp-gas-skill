#!/usr/bin/env bash
# 安裝 clasp-setup 技能到本機（macOS / Linux）
#
# 會複製到兩個資料夾，一次涵蓋四個平台：
#   ~/.claude/skills/   → Claude Code、opencode
#   ~/.agents/skills/   → ChatGPT 應用程式（Codex）、AntiGravity 2、opencode
#
# 用法：
#   bash scripts/install.sh              # 裝到使用者家目錄（預設）
#   bash scripts/install.sh --project    # 改裝到目前專案資料夾

set -euo pipefail

SKILL_NAME="clasp-setup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/../skills/$SKILL_NAME"

if [ ! -d "$SOURCE" ]; then
  echo "找不到技能來源資料夾：$SOURCE" >&2
  exit 1
fi

if [ "${1:-}" = "--project" ]; then
  ROOT="$(pwd)"
else
  ROOT="$HOME"
fi

for BASE in ".claude/skills" ".agents/skills"; do
  TARGET="$ROOT/$BASE/$SKILL_NAME"
  mkdir -p "$ROOT/$BASE"
  rm -rf "$TARGET"
  cp -r "$SOURCE" "$TARGET"
  echo "✅ 已安裝：$TARGET"
done

echo ""
echo "裝好了。請重開你的 agent（或開一個新對話）讓它讀到新技能。"
echo "驗證方式：跟 agent 說「接 Apps Script」，看它有沒有載入 $SKILL_NAME。"
