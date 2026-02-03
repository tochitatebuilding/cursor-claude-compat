#!/usr/bin/env bash
#
# check.sh - Claude Docs 同期状態をチェック
#
# フォルダオープン時に自動実行し、差異があれば警告を表示
#
set -euo pipefail

# =============================================================================
# 定数
# =============================================================================
CONFIG_FILE=".cursor/claude-compat.json"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# ユーティリティ関数
# =============================================================================
log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

# Cursorで実行されているかチェック
is_cursor() {
  [[ -n "${CURSOR_AGENT:-}" ]] || \
  [[ "${VSCODE_CWD:-}" == *"cursor"* ]] || \
  [[ "${PATH:-}" == *".cursor-server"* ]]
}

# jqが使えるかチェック
has_jq() {
  command -v jq &>/dev/null
}

# =============================================================================
# メイン処理
# =============================================================================
main() {
  # Cursorでない場合はスキップ
  if ! is_cursor; then
    exit 0
  fi
  
  # 設定ファイルがない場合
  if [[ ! -f "$CONFIG_FILE" ]]; then
    # Claude用ディレクトリが存在するかチェック
    local has_claude_docs=false
    for dir in docs/plans docs/skills docs/rules .claude/plans .claude/skills .claude/rules; do
      if [[ -d "$dir" ]]; then
        has_claude_docs=true
        break
      fi
    done
    
    if [[ "$has_claude_docs" == "true" ]]; then
      log_warn "Claude Docs が検出されましたが、同期が設定されていません"
      log_info "同期を設定するには /sync-claude-docs を実行してください"
    fi
    exit 0
  fi
  
  # 設定ファイルを読み込み
  local source_plans source_skills source_rules
  local target_plans target_skills target_rules
  
  if has_jq; then
    source_plans=$(jq -r '.source.plans // empty' "$CONFIG_FILE")
    source_skills=$(jq -r '.source.skills // empty' "$CONFIG_FILE")
    source_rules=$(jq -r '.source.rules // empty' "$CONFIG_FILE")
    target_plans=$(jq -r '.target.plans // empty' "$CONFIG_FILE")
    target_skills=$(jq -r '.target.skills // empty' "$CONFIG_FILE")
    target_rules=$(jq -r '.target.rules // empty' "$CONFIG_FILE")
  else
    source_plans=$(grep -oP '"plans"\s*:\s*"\K[^"]+' "$CONFIG_FILE" | head -1)
    source_skills=$(grep -oP '"skills"\s*:\s*"\K[^"]+' "$CONFIG_FILE" | sed -n '2p')
    source_rules=$(grep -oP '"rules"\s*:\s*"\K[^"]+' "$CONFIG_FILE" | sed -n '3p')
    target_plans=".cursor/plans"
    target_skills=".cursor/skills"
    target_rules=".cursor/rules"
  fi
  
  local issues=0
  
  # plans チェック
  if [[ -n "$source_plans" && -d "$source_plans" ]]; then
    if [[ ! -e "$target_plans" ]]; then
      log_warn "plans が同期されていません: $target_plans が存在しません"
      ((issues++))
    elif [[ -L "$target_plans" ]]; then
      # シンボリックリンクの有効性をチェック
      if [[ ! -d "$target_plans" ]]; then
        log_warn "plans のシンボリックリンクが壊れています: $target_plans"
        ((issues++))
      fi
    fi
  fi
  
  # skills チェック
  if [[ -n "$source_skills" && -d "$source_skills" ]]; then
    if [[ ! -e "$target_skills" ]]; then
      log_warn "skills が同期されていません: $target_skills が存在しません"
      ((issues++))
    elif [[ -L "$target_skills" ]]; then
      if [[ ! -d "$target_skills" ]]; then
        log_warn "skills のシンボリックリンクが壊れています: $target_skills"
        ((issues++))
      fi
    fi
  fi
  
  # rules チェック（変換なので、ファイル数を比較）
  if [[ -n "$source_rules" && -d "$source_rules" ]]; then
    if [[ ! -d "$target_rules" ]]; then
      log_warn "rules が同期されていません: $target_rules が存在しません"
      ((issues++))
    else
      local source_count target_count
      source_count=$(find "$source_rules" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l)
      target_count=$(find "$target_rules" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l)
      
      if [[ "$source_count" -ne "$target_count" ]]; then
        log_warn "rules のファイル数が一致しません: source=$source_count, target=$target_count"
        ((issues++))
      fi
    fi
  fi
  
  # 結果を表示
  if [[ $issues -eq 0 ]]; then
    log_success "Claude Docs の同期は正常です"
  else
    log_info "同期を更新するには /sync-claude-docs を実行してください"
  fi
}

main "$@"
