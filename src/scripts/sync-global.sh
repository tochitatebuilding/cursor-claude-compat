#!/usr/bin/env bash
#
# sync-global.sh - Claude Code グローバル MCP 設定を Cursor に同期
#
# 同期対象:
#   - ~/.claude.json内mcpServers → ~/.cursor/mcp.json
#
# Note: Cursor は ~/.claude/CLAUDE.md, ~/.claude/agents/, ~/.claude/skills/,
#       ~/.claude/settings.json hooks をネイティブで読み取るため、
#       それらの同期は不要です。
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
CLAUDE_JSON="$(expand_path ~/.claude.json)"
CURSOR_DIR="$(expand_path ~/.cursor)"
CONFIG_FILE="${CURSOR_DIR}/claude-compat-global.json"
VERSION="1"

# 同期元
SOURCE_MCP_CONFIG="${CLAUDE_JSON}"

# 同期先
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
    local custom_mcp
    custom_mcp=$(json_get "$CONFIG_FILE" '.source.mcpConfig')
    [[ -n "$custom_mcp" ]] && SOURCE_MCP_CONFIG="$custom_mcp"

    local custom_target_mcp
    custom_target_mcp=$(json_get "$CONFIG_FILE" '.target.mcp')
    [[ -n "$custom_target_mcp" ]] && TARGET_MCP="$custom_target_mcp"

    return 0
  fi

  return 1
}

# 設定ファイルを保存
save_global_config() {
  local status="$1"
  local mcp_result="$2"

  mkdir -p "$(dirname "$CONFIG_FILE")"

  cat > "$CONFIG_FILE" << EOF
{
  "version": "$VERSION",
  "source": {
    "mcpConfig": "$SOURCE_MCP_CONFIG"
  },
  "target": {
    "mcp": "$TARGET_MCP"
  },
  "syncMethod": {
    "mcp": "merge"
  },
  "conflictPolicy": "ask",
  "lastSync": "$(date -Iseconds)",
  "lastSyncStatus": "$status",
  "lastSyncDetails": {
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
  log_info "Claude グローバル MCP 設定を検出中..."
  echo ""

  # MCP設定の検出
  if [[ -f "$SOURCE_MCP_CONFIG" ]]; then
    log_success "MCP設定を検出: $SOURCE_MCP_CONFIG"
    if [[ "$HAS_JQ" != "true" ]]; then
      log_warn "jq がインストールされていないため、MCP設定の同期はスキップされます"
    fi
  else
    log_warn "MCP設定が見つかりません: $SOURCE_MCP_CONFIG"
    echo ""
    read -rp "MCP設定ファイルのパスを入力してください（空欄でスキップ）: " custom_path
    if [[ -n "$custom_path" ]]; then
      custom_path="$(expand_path "$custom_path")"
      if [[ -f "$custom_path" ]]; then
        SOURCE_MCP_CONFIG="$custom_path"
        log_success "MCP設定を設定: $SOURCE_MCP_CONFIG"
      else
        log_error "ファイルが見つかりません: $custom_path"
      fi
    fi
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 検出された設定"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "同期元:"
  echo "  MCP設定:    ${SOURCE_MCP_CONFIG:-（なし）}"
  echo ""
  echo "同期先:"
  echo "  MCP:        $TARGET_MCP"
  echo ""
  echo "注意:"
  echo "  Cursor は ~/.claude/CLAUDE.md, ~/.claude/skills/, ~/.claude/agents/ を"
  echo "  ネイティブで読み取るため、それらの同期は不要です。"
  echo ""

  if [[ ! -f "$SOURCE_MCP_CONFIG" ]]; then
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
        echo "  - mcpServers がありません"
        if [[ -f "$TARGET_MCP" ]] && validate_json "$TARGET_MCP"; then
          echo "  ℹ 既存の Cursor MCP 設定は保持されます"
        fi
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

  # mcpServersの存在チェック（空オブジェクトは許可）
  local has_mcp_servers
  has_mcp_servers=$(jq 'has("mcpServers")' "$SOURCE_MCP_CONFIG" 2>/dev/null || echo "false")

  if [[ "$has_mcp_servers" != "true" ]]; then
    log_info "mcpServers がありません。MCP同期をスキップします。"
    return 1
  fi

  local claude_server_count
  claude_server_count=$(jq '.mcpServers | length' "$SOURCE_MCP_CONFIG" 2>/dev/null || echo "0")

  if [[ "$DRY_RUN" == "true" ]]; then
    if [[ "$claude_server_count" -eq 0 ]]; then
      log_info "[DRY-RUN] mcpServers が空です。既存の Cursor 設定は保持されます。"
    else
      log_info "[DRY-RUN] MCPマージ: $SOURCE_MCP_CONFIG -> $TARGET_MCP"
    fi
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

  # Claude 側が空の mcpServers の場合は既存を保持
  if [[ "$claude_server_count" -eq 0 ]]; then
    log_info "mcpServers が空です。既存の Cursor 設定を保持します。"
    return 0
  fi

  # Claude 固有フィールドを除去
  local sanitized_claude
  sanitized_claude=$(sanitize_mcp_for_cursor "$(cat "$SOURCE_MCP_CONFIG")")

  # 一時ファイルに書き込み → 検証 → mv のパターン
  local tmpfile
  tmpfile=$(mktemp "${TARGET_MCP}.tmp.XXXXXX")

  # マージ処理（競合時は既存優先）
  # Claude側から新しいキーのみを追加
  jq -s '
    .[0] as $cursor |
    .[1] as $claude |
    $cursor * {
      mcpServers: (
        ($cursor.mcpServers // {}) as $existing |
        ($claude.mcpServers // {}) as $new |
        $existing + ($new | to_entries | map(select(.key | in($existing) | not)) | from_entries)
      )
    }
  ' <(echo "$cursor_mcp") <(echo "$sanitized_claude") > "$tmpfile"

  # 書き込み後の検証
  if ! validate_json "$tmpfile"; then
    log_error "マージ後のJSONが不正です。バックアップから復元します。"
    rm -f "$tmpfile"
    rollback_file "$TARGET_MCP"
    return 1
  fi

  # 親ディレクトリ作成
  mkdir -p "$(dirname "$TARGET_MCP")"

  # 検証済みファイルを配置
  mv "$tmpfile" "$TARGET_MCP"

  log_success "MCPマージ完了: $TARGET_MCP"
  return 0
}

# =============================================================================
# ヘルプ表示
# =============================================================================
show_help() {
  cat << EOF
Usage: $0 [OPTIONS]

Claude Code のグローバル MCP 設定を Cursor に同期します。

同期対象:
  - ~/.claude.json内mcpServers → ~/.cursor/mcp.json

注意:
  Cursor は以下をネイティブで読み取るため、同期は不要です:
  - ~/.claude/CLAUDE.md
  - ~/.claude/agents/
  - ~/.claude/skills/
  - ~/.claude/settings.json (hooks)

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
  - Claude 固有フィールド（type, envFile, oauth, disabledTools）は自動除去されます
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
  echo " Cursor-Claude Compat - グローバル MCP 同期ツール"
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
      if [[ ! -f "$SOURCE_MCP_CONFIG" ]]; then
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
  local mcp_result="skipped"

  # MCP
  if sync_mcp_config; then
    mcp_result="success"
  elif [[ -f "$SOURCE_MCP_CONFIG" && "$HAS_JQ" == "true" ]]; then
    mcp_result="skipped"
  fi

  # 結果の判定
  if [[ "$mcp_result" == "success" ]]; then
    sync_status="success"
  else
    sync_status="failed"
  fi

  # 設定ファイルを保存
  if [[ "$DRY_RUN" != "true" ]]; then
    save_global_config "$sync_status" "$mcp_result"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 同期完了"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "同期結果:"
  echo "  mcp:    $mcp_result"
  echo ""

  if [[ "$sync_status" == "success" ]]; then
    log_success "MCP 同期が完了しました!"
  else
    log_warn "MCP 同期がスキップされました"
    exit 1
  fi
}

main "$@"
