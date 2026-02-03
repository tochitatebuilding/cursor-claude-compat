#!/usr/bin/env bash
#
# sync-global.sh - Claude Code グローバル設定を Cursor に同期
#
# 同期対象:
#   - ~/.claude/CLAUDE.md → ~/.cursor/rules/claude-global.md
#   - ~/.claude/skills/ → ~/.cursor/skills-cursor/claude-skills/
#   - ~/.claude.json内mcpServers → ~/.cursor/mcp.json
#
# Usage: sync-global.sh [OPTIONS]
#
set -euo pipefail

# =============================================================================
# 定数・初期化
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリを読み込み
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=src/scripts/lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  # フォールバック: インストール先から読み込み
  INSTALLED_LIB="${HOME}/.cursor/skills-cursor/sync-claude-docs/lib/common.sh"
  if [[ -f "$INSTALLED_LIB" ]]; then
    # shellcheck disable=SC1090
    source "$INSTALLED_LIB"
  else
    echo "Error: common.sh が見つかりません" >&2
    exit 1
  fi
fi

# パスの定義
CLAUDE_DIR="$(expand_path ~/.claude)"
CLAUDE_JSON="$(expand_path ~/.claude.json)"
CURSOR_DIR="$(expand_path ~/.cursor)"
CONFIG_FILE="${CURSOR_DIR}/claude-compat-global.json"
VERSION="1"

# 同期元
SOURCE_CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"
SOURCE_SKILLS="${CLAUDE_DIR}/skills"
SOURCE_MCP_CONFIG="${CLAUDE_JSON}"

# 同期先
TARGET_RULES="${CURSOR_DIR}/rules/claude-global.md"
TARGET_SKILLS="${CURSOR_DIR}/skills-cursor/claude-skills"
TARGET_MCP="${CURSOR_DIR}/mcp.json"

# =============================================================================
# 設定ファイル操作
# =============================================================================

# 設定ファイルを読み込み
load_global_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    return 1
  fi
  
  if [[ "$HAS_JQ" == "true" ]] && validate_json "$CONFIG_FILE"; then
    # カスタムパスがあれば読み込み
    local custom_claude_md
    custom_claude_md=$(json_get "$CONFIG_FILE" '.source.claudeMd')
    [[ -n "$custom_claude_md" ]] && SOURCE_CLAUDE_MD="$custom_claude_md"
    
    local custom_skills
    custom_skills=$(json_get "$CONFIG_FILE" '.source.skills')
    [[ -n "$custom_skills" ]] && SOURCE_SKILLS="$custom_skills"
    
    local custom_mcp
    custom_mcp=$(json_get "$CONFIG_FILE" '.source.mcpConfig')
    [[ -n "$custom_mcp" ]] && SOURCE_MCP_CONFIG="$custom_mcp"
    
    return 0
  fi
  
  return 1
}

# 設定ファイルを保存
save_global_config() {
  local status="$1"
  local rules_result="$2"
  local skills_result="$3"
  local mcp_result="$4"
  
  mkdir -p "$(dirname "$CONFIG_FILE")"
  
  cat > "$CONFIG_FILE" << EOF
{
  "version": "$VERSION",
  "source": {
    "claudeMd": "$SOURCE_CLAUDE_MD",
    "skills": "$SOURCE_SKILLS",
    "mcpConfig": "$SOURCE_MCP_CONFIG"
  },
  "target": {
    "rules": "$TARGET_RULES",
    "skills": "$TARGET_SKILLS",
    "mcp": "$TARGET_MCP"
  },
  "syncMethod": {
    "rules": "convert",
    "skills": "symlink",
    "mcp": "merge"
  },
  "conflictPolicy": "ask",
  "lastSync": "$(date -Iseconds)",
  "lastSyncStatus": "$status",
  "lastSyncDetails": {
    "rules": "$rules_result",
    "skills": "$skills_result",
    "mcp": "$mcp_result"
  }
}
EOF
  
  log_success "設定ファイルを保存: $CONFIG_FILE"
}

# =============================================================================
# 対話モード
# =============================================================================
run_global_interactive_setup() {
  echo ""
  log_info "Claude グローバル設定を検出中..."
  echo ""
  
  # CLAUDE.md の検出
  if [[ -f "$SOURCE_CLAUDE_MD" ]]; then
    log_success "CLAUDE.md を検出: $SOURCE_CLAUDE_MD"
  else
    log_warn "CLAUDE.md が見つかりません: $SOURCE_CLAUDE_MD"
    echo ""
    read -rp "CLAUDE.md のパスを入力してください（空欄でスキップ）: " custom_path
    if [[ -n "$custom_path" ]]; then
      custom_path="$(expand_path "$custom_path")"
      if [[ -f "$custom_path" ]]; then
        SOURCE_CLAUDE_MD="$custom_path"
        log_success "CLAUDE.md を設定: $SOURCE_CLAUDE_MD"
      else
        log_error "ファイルが見つかりません: $custom_path"
      fi
    fi
  fi
  
  # skills ディレクトリの検出
  echo ""
  if [[ -d "$SOURCE_SKILLS" ]]; then
    log_success "skills ディレクトリを検出: $SOURCE_SKILLS"
  else
    log_warn "skills ディレクトリが見つかりません: $SOURCE_SKILLS"
    echo ""
    read -rp "skills ディレクトリのパスを入力してください（空欄でスキップ）: " custom_path
    if [[ -n "$custom_path" ]]; then
      custom_path="$(expand_path "$custom_path")"
      if [[ -d "$custom_path" ]]; then
        SOURCE_SKILLS="$custom_path"
        log_success "skills ディレクトリを設定: $SOURCE_SKILLS"
      else
        log_error "ディレクトリが見つかりません: $custom_path"
      fi
    fi
  fi
  
  # MCP設定の検出
  echo ""
  if [[ -f "$SOURCE_MCP_CONFIG" ]]; then
    log_success "MCP設定を検出: $SOURCE_MCP_CONFIG"
    if [[ "$HAS_JQ" != "true" ]]; then
      log_warn "jq がインストールされていないため、MCP設定の同期はスキップされます"
    fi
  else
    log_info "MCP設定が見つかりません: $SOURCE_MCP_CONFIG"
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 検出された設定"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "同期元:"
  echo "  CLAUDE.md:  ${SOURCE_CLAUDE_MD:-（なし）}"
  echo "  skills:     ${SOURCE_SKILLS:-（なし）}"
  echo "  MCP設定:    ${SOURCE_MCP_CONFIG:-（なし）}"
  echo ""
  echo "同期先:"
  echo "  rules:      $TARGET_RULES"
  echo "  skills:     $TARGET_SKILLS"
  echo "  MCP:        $TARGET_MCP"
  echo ""
  
  if [[ ! -f "$SOURCE_CLAUDE_MD" && ! -d "$SOURCE_SKILLS" && ! -f "$SOURCE_MCP_CONFIG" ]]; then
    log_error "同期元が見つかりません。Claude Code の設定を確認してください。"
    exit 1
  fi
  
  read -rp "この設定で続行しますか? [Y/n]: " confirm
  if [[ "$confirm" =~ ^[Nn] ]]; then
    log_info "同期をキャンセルしました"
    exit 0
  fi
}

# =============================================================================
# プレビュー表示
# =============================================================================
show_preview() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 変更内容のプレビュー"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # rules
  echo "[rules]"
  if [[ -f "$SOURCE_CLAUDE_MD" ]]; then
    if [[ -f "$TARGET_RULES" ]]; then
      echo "  ~ claude-global.md: 更新"
    else
      echo "  + claude-global.md: 新規作成"
    fi
  else
    echo "  - CLAUDE.md が見つかりません（スキップ）"
  fi
  echo ""
  
  # skills
  echo "[skills]"
  if [[ -d "$SOURCE_SKILLS" ]]; then
    if [[ -e "$TARGET_SKILLS" ]]; then
      if [[ -L "$TARGET_SKILLS" ]]; then
        echo "  ~ claude-skills: リンク更新"
      else
        echo "  ~ claude-skills: 更新（ディレクトリ → リンク）"
      fi
    else
      echo "  + claude-skills: シンボリックリンク作成"
    fi
  else
    echo "  - skills ディレクトリが見つかりません（スキップ）"
  fi
  echo ""
  
  # mcp
  echo "[mcp]"
  if [[ "$HAS_JQ" != "true" ]]; then
    echo "  - jq がインストールされていません（スキップ）"
  elif [[ ! -f "$SOURCE_MCP_CONFIG" ]]; then
    echo "  - MCP設定が見つかりません（スキップ）"
  else
    if ! validate_json "$SOURCE_MCP_CONFIG"; then
      echo "  ✗ MCP設定が不正なJSONです（スキップ）"
    else
      local claude_servers
      claude_servers=$(jq -r '.mcpServers // {} | keys[]' "$SOURCE_MCP_CONFIG" 2>/dev/null || true)
      
      if [[ -z "$claude_servers" ]]; then
        echo "  - mcpServers がありません（スキップ）"
      else
        if [[ -f "$TARGET_MCP" ]] && validate_json "$TARGET_MCP"; then
          # 既存のCursor側のサーバーを取得
          local cursor_servers
          cursor_servers=$(jq -r '.mcpServers // {} | keys[]' "$TARGET_MCP" 2>/dev/null || true)
          
          for server in $claude_servers; do
            if echo "$cursor_servers" | grep -qx "$server"; then
              echo "  ~ mcpServers.$server: スキップ（既存優先）"
            else
              echo "  + mcpServers.$server: 新規追加"
            fi
          done
        else
          for server in $claude_servers; do
            echo "  + mcpServers.$server: 新規追加"
          done
        fi
      fi
    fi
  fi
  echo ""
}

# =============================================================================
# 同期処理
# =============================================================================

# CLAUDE.md → rules/claude-global.md 変換
sync_claude_md() {
  if [[ ! -f "$SOURCE_CLAUDE_MD" ]]; then
    log_info "CLAUDE.md が見つかりません。rules同期をスキップします。"
    return 1
  fi
  
  # 既存ファイルの処理
  if [[ -f "$TARGET_RULES" ]]; then
    resolve_conflict "$TARGET_RULES"
    
    if [[ "$CONFLICT_ACTION" == "skip" ]]; then
      log_info "スキップ: $TARGET_RULES"
      return 1
    fi
    
    if [[ "$DRY_RUN" != "true" ]]; then
      backup_file "$TARGET_RULES"
    fi
  fi
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] 変換: $SOURCE_CLAUDE_MD -> $TARGET_RULES"
    return 0
  fi
  
  # 親ディレクトリ作成
  mkdir -p "$(dirname "$TARGET_RULES")"
  
  # frontmatter を追加して変換
  {
    echo "---"
    echo "description: Claude グローバルルール（自動生成）"
    echo 'globs: ["**/*"]'
    echo "alwaysApply: true"
    echo "---"
    echo ""
    cat "$SOURCE_CLAUDE_MD"
  } > "$TARGET_RULES"
  
  log_success "変換完了: $SOURCE_CLAUDE_MD -> $TARGET_RULES"
  return 0
}

# skills シンボリックリンク/コピー
sync_global_skills() {
  if [[ ! -d "$SOURCE_SKILLS" ]]; then
    log_info "skills ディレクトリが見つかりません。skills同期をスキップします。"
    return 1
  fi
  
  # 既存の処理
  if [[ -e "$TARGET_SKILLS" ]]; then
    resolve_conflict "$TARGET_SKILLS"
    
    if [[ "$CONFLICT_ACTION" == "skip" ]]; then
      log_info "スキップ: $TARGET_SKILLS"
      return 1
    fi
    
    if [[ "$DRY_RUN" != "true" ]]; then
      if [[ -L "$TARGET_SKILLS" ]]; then
        backup_file "$TARGET_SKILLS"
        rm "$TARGET_SKILLS"
      else
        backup_directory "$TARGET_SKILLS"
        rm -rf "$TARGET_SKILLS"
      fi
    fi
  fi
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] リンク作成: $SOURCE_SKILLS -> $TARGET_SKILLS"
    return 0
  fi
  
  # 親ディレクトリ作成
  mkdir -p "$(dirname "$TARGET_SKILLS")"
  
  # シンボリックリンクを試行
  if check_symlink_support; then
    ln -s "$SOURCE_SKILLS" "$TARGET_SKILLS"
    log_success "シンボリックリンク作成: $TARGET_SKILLS -> $SOURCE_SKILLS"
  else
    # フォールバック: コピー
    copy_directory "$SOURCE_SKILLS" "$TARGET_SKILLS"
    log_success "コピー完了: $SOURCE_SKILLS -> $TARGET_SKILLS"
  fi
  
  return 0
}

# MCP設定の安全マージ
sync_mcp_config() {
  if [[ "$HAS_JQ" != "true" ]]; then
    log_warn "jq がインストールされていません。MCP同期をスキップします。"
    return 1
  fi
  
  if [[ ! -f "$SOURCE_MCP_CONFIG" ]]; then
    log_info "MCP設定が見つかりません。MCP同期をスキップします。"
    return 1
  fi
  
  # Claude側のJSON検証
  if ! validate_json "$SOURCE_MCP_CONFIG"; then
    log_error "MCP設定が不正なJSONです: $SOURCE_MCP_CONFIG"
    return 1
  fi
  
  # mcpServersの存在チェック
  local claude_mcp_servers
  claude_mcp_servers=$(jq -r '.mcpServers // empty' "$SOURCE_MCP_CONFIG" 2>/dev/null)
  
  if [[ -z "$claude_mcp_servers" || "$claude_mcp_servers" == "null" ]]; then
    log_info "mcpServers がありません。MCP同期をスキップします。"
    return 1
  fi
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] MCPマージ: $SOURCE_MCP_CONFIG -> $TARGET_MCP"
    return 0
  fi
  
  # Cursor側の処理
  local cursor_mcp='{}'
  
  if [[ -f "$TARGET_MCP" ]]; then
    # 既存ファイルの検証
    if ! validate_json "$TARGET_MCP"; then
      log_error "Cursor側のMCP設定が不正なJSONです: $TARGET_MCP"
      log_info "バックアップから復元するか、手動で修正してください。"
      return 1
    fi
    
    # バックアップ
    backup_file "$TARGET_MCP"
    cursor_mcp=$(cat "$TARGET_MCP")
  fi
  
  # マージ処理（競合時は既存優先）
  # Claude側から新しいキーのみを追加
  local merged
  merged=$(jq -s '
    .[0] as $cursor |
    .[1] as $claude |
    $cursor * {
      mcpServers: (
        ($cursor.mcpServers // {}) as $existing |
        ($claude.mcpServers // {}) as $new |
        $existing + ($new | to_entries | map(select(.key | in($existing) | not)) | from_entries)
      )
    }
  ' <(echo "$cursor_mcp") "$SOURCE_MCP_CONFIG")
  
  # 親ディレクトリ作成
  mkdir -p "$(dirname "$TARGET_MCP")"
  
  # 書き込み
  echo "$merged" > "$TARGET_MCP"
  
  # 書き込み後の検証
  if ! validate_json "$TARGET_MCP"; then
    log_error "マージ後のJSONが不正です。バックアップから復元します。"
    rollback_file "$TARGET_MCP"
    return 1
  fi
  
  log_success "MCPマージ完了: $TARGET_MCP"
  return 0
}

# =============================================================================
# ヘルプ表示
# =============================================================================
show_help() {
  cat << EOF
Usage: $0 [OPTIONS]

Claude Code のグローバル設定を Cursor に同期します。

同期対象:
  - ~/.claude/CLAUDE.md → ~/.cursor/rules/claude-global.md
  - ~/.claude/skills/ → ~/.cursor/skills-cursor/claude-skills/
  - ~/.claude.json内mcpServers → ~/.cursor/mcp.json

OPTIONS:
  --yes, -y           非対話モード（デフォルト: バックアップ後上書き）
  --skip-existing     既存ファイルはスキップ
  --force, -f         既存ファイルを確認なしで上書き（バックアップは作成）
  --dry-run, -n       実際には実行せず、何が行われるか表示
  --no-backup         バックアップを作成しない（非推奨）
  --help, -h          ヘルプ表示

EXAMPLES:
  $0                  # 対話モードで実行
  $0 --yes            # 非対話モード（デフォルト動作）
  $0 --skip-existing  # 既存ファイルをスキップ
  $0 --dry-run        # プレビューのみ

NOTES:
  - MCP設定の同期には jq が必要です
  - 競合時は既存のCursor設定が優先されます（安全性重視）
  - バックアップは ~/.cursor/.claude-compat-backup/ に保存されます
EOF
}

# =============================================================================
# メイン処理
# =============================================================================
main() {
  # 引数解析
  while [[ $# -gt 0 ]]; do
    if parse_common_option "$1"; then
      shift
      continue
    fi
    
    case "$1" in
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        log_error "不明なオプション: $1"
        echo "ヘルプを表示するには: $0 --help"
        exit 1
        ;;
    esac
  done
  
  # オプションの妥当性チェック
  if ! validate_options; then
    exit 1
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Cursor-Claude Compat - グローバル同期ツール"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # 依存関係チェック
  check_dependencies
  
  # バックアップディレクトリを初期化
  init_backup_dir "$CURSOR_DIR"
  
  # 設定ファイル確認
  if ! load_global_config; then
    if [[ "$YES_MODE" == "true" ]]; then
      # --yes モードでも設定がない場合はデフォルトパスで続行
      log_info "設定ファイルが見つかりません。デフォルトパスを使用します。"
      
      # 同期元が存在しない場合はエラー
      if [[ ! -f "$SOURCE_CLAUDE_MD" && ! -d "$SOURCE_SKILLS" && ! -f "$SOURCE_MCP_CONFIG" ]]; then
        log_error "同期元が見つかりません。"
        log_info "対話モードで初回セットアップを行ってください: $0"
        exit 1
      fi
    else
      run_global_interactive_setup
    fi
  fi
  
  # プレビュー表示
  show_preview
  
  # 確認（--yes でない場合）
  if [[ "$YES_MODE" != "true" && "$DRY_RUN" != "true" ]]; then
    read -rp "続行しますか? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn] ]]; then
      log_info "同期をキャンセルしました"
      exit 0
    fi
  fi
  
  echo ""
  log_info "同期を開始します..."
  echo ""
  
  # 同期結果を追跡
  local sync_status="success"
  local rules_result="skipped"
  local skills_result="skipped"
  local mcp_result="skipped"
  
  # CLAUDE.md → rules
  if sync_claude_md; then
    rules_result="success"
  elif [[ -f "$SOURCE_CLAUDE_MD" ]]; then
    # ファイルは存在するがスキップされた場合
    rules_result="skipped"
  fi
  
  # skills
  if sync_global_skills; then
    skills_result="success"
  elif [[ -d "$SOURCE_SKILLS" ]]; then
    skills_result="skipped"
  fi
  
  # MCP
  if sync_mcp_config; then
    mcp_result="success"
  elif [[ -f "$SOURCE_MCP_CONFIG" && "$HAS_JQ" == "true" ]]; then
    mcp_result="skipped"
  fi
  
  # 結果の判定
  if [[ "$rules_result" == "success" || "$skills_result" == "success" || "$mcp_result" == "success" ]]; then
    if [[ "$rules_result" == "skipped" || "$skills_result" == "skipped" || "$mcp_result" == "skipped" ]]; then
      sync_status="partial"
    else
      sync_status="success"
    fi
  else
    sync_status="failed"
  fi
  
  # 設定ファイルを保存
  if [[ "$DRY_RUN" != "true" ]]; then
    save_global_config "$sync_status" "$rules_result" "$skills_result" "$mcp_result"
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 同期完了"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "同期結果:"
  echo "  rules:  $rules_result"
  echo "  skills: $skills_result"
  echo "  mcp:    $mcp_result"
  echo ""
  
  if [[ "$sync_status" == "success" ]]; then
    log_success "すべての同期が完了しました!"
  elif [[ "$sync_status" == "partial" ]]; then
    log_warn "一部の同期がスキップされました"
  else
    log_error "同期に失敗しました"
    exit 1
  fi
}

main "$@"
