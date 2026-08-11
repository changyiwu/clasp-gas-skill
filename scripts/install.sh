#!/usr/bin/env bash
# 安裝 clasp-setup 技能到本機（macOS / Linux）
#
# 用法：
#   bash scripts/install.sh              # 安裝到已存在的四個 Agent 全域目錄

set -euo pipefail

SKILL_NAME="clasp-setup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/../skills/$SKILL_NAME"

if [ "$#" -gt 0 ]; then
  echo "不支援的參數：$1" >&2
  exit 2
fi

if [ ! -d "$SOURCE" ] || [ ! -f "$SOURCE/SKILL.md" ]; then
  echo "找不到技能來源資料夾：$SOURCE" >&2
  exit 1
fi

FRONTMATTER_NAME="$(sed -n '1,12s/^[[:space:]]*name:[[:space:]]*//p' "$SOURCE/SKILL.md" | head -n 1 | tr -d '\r' | sed "s/^[\"']//;s/[\"']$//")"
if [ "$FRONTMATTER_NAME" != "$SKILL_NAME" ]; then
  echo "SKILL.md 的 name 必須是 '$SKILL_NAME'，目前是 '$FRONTMATTER_NAME'。" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  hash_file() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  hash_file() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  echo "找不到 sha256sum 或 shasum，無法驗證安裝結果。" >&2
  exit 1
fi

write_manifest() {
  local root="$1"
  local output="$2"
  (
    cd "$root"
    find . -type f -print | LC_ALL=C sort | while IFS= read -r relative; do
      printf '%s  %s\n' "$(hash_file "$relative")" "$relative"
    done
  ) > "$output"
}

BASES=(
  "$HOME/.claude/skills"
  "$HOME/.agents/skills"
  "$HOME/.config/opencode/skills"
  "$HOME/.gemini/config/skills"
)
LABELS=("Claude Code" "Codex" "OpenCode" "Antigravity")

TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_ROOT"' EXIT
write_manifest "$SOURCE" "$TEMP_ROOT/source.sha256"

INSTALLED=0
for index in "${!BASES[@]}"; do
  BASE="${BASES[$index]}"
  LABEL="${LABELS[$index]}"

  if [ ! -d "$BASE" ]; then
    echo "[SKIP] $LABEL：目錄不存在（這台可能未安裝該工具）"
    continue
  fi

  TARGET="$BASE/$SKILL_NAME"
  case "$TARGET" in
    "$BASE/$SKILL_NAME") ;;
    *)
      echo "拒絕操作不安全的安裝目標：$TARGET" >&2
      exit 1
      ;;
  esac

  rm -rf -- "$TARGET"
  mkdir -p "$TARGET"
  cp -R "$SOURCE/." "$TARGET/"

  write_manifest "$TARGET" "$TEMP_ROOT/target-$index.sha256"
  if ! cmp -s "$TEMP_ROOT/source.sha256" "$TEMP_ROOT/target-$index.sha256"; then
    echo "$LABEL 安裝驗證失敗：來源與目標 SHA-256 清單不一致。" >&2
    diff -u "$TEMP_ROOT/source.sha256" "$TEMP_ROOT/target-$index.sha256" || true
    exit 1
  fi

  INSTALLED=$((INSTALLED + 1))
  FILE_COUNT="$(wc -l < "$TEMP_ROOT/source.sha256" | tr -d ' ')"
  echo "[OK] $LABEL：$TARGET（$FILE_COUNT 檔，SHA-256 一致）"
done

if [ "$INSTALLED" -eq 0 ]; then
  echo "沒有可用的安裝目標。全域模式只安裝到已存在的 Agent 技能目錄。" >&2
  exit 1
fi

echo
echo "安裝完成。若技能未立即出現，請重開 agent 或開新對話。"
