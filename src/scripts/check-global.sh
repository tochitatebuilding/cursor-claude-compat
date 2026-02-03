#!/usr/bin/env bash
#
# check-global.sh - Claude グローバル設定の同期状態をチェック
#
# チェック対象:
#   - ~/.claude/CLAUDE.md と ~/.cursor/rules/claude-global.md の同期状態
#   - ~/.claude/skills/ シンボリックリンクの状態
#   - ~/.claude.json内mcpServers と ~/.cursor/mcp.json の差分
#
set -euo pipefail

# =============================================================================
# 定数・初期化
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリを読み込み
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  source "${SCRIPT_DIR}/lib/common.sh"
else
  # フォールバック: インストール先から読み込み
  INSTALLED_LIB="${HOME}/.cursor/skills-cursor/sync-claude-docs/lib/common.sh"
  if [[ -f "$INSTALLED_LIB" ]]; then
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

# 同期元
SOURCE_CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"
SOURCE_SKILLS="${CLAUDE_DIR}/skills"
SOURCE_MCP_CONFIG="${CLAUDE_JSON}"

# 同期先
TARGET_RULES="${CURSOR_DIR}/rules/claude-global.md"
TARGET_SKILLS="${CURSOR_DIR}/skills-cursor/claude-skills"
TARGET_MCP="${CURSOR_DIR}/mcp.json"

# カウンター
ISSUES=0
WARNINGS=0

# =============================================================================
# 設定ファイル読み込み
# =============================================================================
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
    
    local custom_target_rules
    custom_target_rules=$(json_get "$CONFIG_FILE" '.target.rules')
    [[ -n "$custom_target_rules" ]] && TARGET_RULES="$custom_target_rules"
    
    local custom_target_skills
    custom_target_skills=$(json_get "$CONFIG_FILE" '.target.skills')
    [[ -n "$custom_target_skills" ]] && TARGET_SKILLS="$custom_target_skills"
    
    local custom_target_mcp
    custom_target_mcp=$(json_get "$CONFIG_FILE" '.target.mcp')
    [[ -n "$custom_target_mcp" ]] && TARGET_MCP="$custom_target_mcp"
    
    return 0
  fi
  
  return 1
}

# =============================================================================
# チェック処理
# =============================================================================

# CLAUDE.md と rules/claude-global.md の比較
check_rules() {
  echo "[rules]"
  
  if [[ ! -f "$SOURCE_CLAUDE_MD" ]]; then
    echo "  ℹ CLAUDE.md: 存在しない（スキップ）"
    return 0
  fi
  
  if [[ ! -f "$TARGET_RULES" ]]; then
    echo "  ✗ claude-global.md: 未作成"
    ((ISSUES++))
    return 1
  fi
  
  # frontmatter を除外して内容を比較
  local source_content target_content
  source_content=$(cat "$SOURCE_CLAUDE_MD")
  target_content=$(extract_content_without_frontmatter "$TARGET_RULES")
  
  # 空白行の正規化（末尾の空白行を除去して比較）
  source_content=$(echo "$source_content" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
  target_content=$(echo "$target_content" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
  
  if [[ "$source_content" == "$target_content" ]]; then
    echo "  ✓ claude-global.md: 同期済み"
    return 0
  else
    echo "  ⚠ claude-global.md: 差分あり"
    ((WARNINGS++))
    return 1
  fi
}

# skills シンボリックリンクのチェック
check_skills() {
  echo ""
  echo "[skills]"
  
  if [[ ! -d "$SOURCE_SKILLS" ]]; then
    echo "  ℹ skills: 存在しない（スキップ）"
    return 0
  fi
  
  if [[ ! -e "$TARGET_SKILLS" ]]; then
    echo "  ✗ claude-skills: 未作成"
    ((ISSUES++))
    return 1
  fi
  
  if [[ -L "$TARGET_SKILLS" ]]; then
    # シンボリックリンクの場合
    if [[ -e "$TARGET_SKILLS" ]]; then
      # リンク先が存在する
      local link_target
      link_target=$(readlink -f "$TARGET_SKILLS" 2>/dev/null || readlink "$TARGET_SKILLS")
      local source_real
      source_real=$(realpath "$SOURCE_SKILLS" 2>/dev/null || echo "$SOURCE_SKILLS")
      
      if [[ "$link_target" == "$source_real" ]]; then
        echo "  ✓ claude-skills: 同期済み（リンク正常）"
        return 0
      else
        echo "  ⚠ claude-skills: リンク先が異なる"
        echo "    現在: $link_target"
        echo "    期待: $source_real"
        ((WARNINGS++))
        return 1
      fi
    else
      echo "  ⚠ claude-skills: リンク切れ"
      ((WARNINGS++))
      return 1
    fi
  else
    # ディレクトリの場合（コピーされている）
    echo "  ℹ claude-skills: コピーで同期（シンボリックリンクではない）"
    return 0
  fi
}

# MCP設定の比較
check_mcp() {
  echo ""
  echo "[mcp]"
  
  if [[ "$HAS_JQ" != "true" ]]; then
    echo "  ℹ mcp: jq がインストールされていません（スキップ）"
    return 0
  fi
  
  if [[ ! -f "$SOURCE_MCP_CONFIG" ]]; then
    echo "  ℹ mcp: Claude MCP設定が見つかりません（スキップ）"
    return 0
  fi
  
  if ! validate_json "$SOURCE_MCP_CONFIG"; then
    echo "  ✗ mcp: Claude MCP設定が不正なJSON"
    ((ISSUES++))
    return 1
  fi
  
  # Claude側のmcpServersを取得
  local claude_servers
  claude_servers=$(jq -r '.mcpServers // {} | keys[]' "$SOURCE_MCP_CONFIG" 2>/dev/null || true)
  
  if [[ -z "$claude_servers" ]]; then
    echo "  ℹ mcp: mcpServers がありません（スキップ）"
    return 0
  fi
  
  if [[ ! -f "$TARGET_MCP" ]]; then
    echo "  ✗ mcp.json: 未作成"
    for server in $claude_servers; do
      echo "    ⚠ mcpServers.$server: Claude側にあり、Cursor側にない"
    done
    ((ISSUES++))
    return 1
  fi
  
  if ! validate_json "$TARGET_MCP"; then
    echo "  ✗ mcp.json: 不正なJSON"
    ((ISSUES++))
    return 1
  fi
  
  # Cursor側のmcpServersを取得
  local cursor_servers
  cursor_servers=$(jq -r '.mcpServers // {} | keys[]' "$TARGET_MCP" 2>/dev/null || true)
  
  local has_diff=false
  
  # Claude側のサーバーをチェック
  for server in $claude_servers; do
    if echo "$cursor_servers" | grep -qx "$server"; then
      # 両方に存在 - 内容の比較
      local claude_config cursor_config
      claude_config=$(jq -c ".mcpServers[\"$server\"]" "$SOURCE_MCP_CONFIG")
      cursor_config=$(jq -c ".mcpServers[\"$server\"]" "$TARGET_MCP")
      
      if [[ "$claude_config" == "$cursor_config" ]]; then
        echo "  ✓ mcpServers.$server: 同期済み"
      else
        echo "  ℹ mcpServers.$server: Cursor側が異なる（既存優先）"
      fi
    else
      # Claude側にのみ存在
      echo "  ⚠ mcpServers.$server: Claude側にあり、Cursor側にない"
      has_diff=true
    fi
  done
  
  # Cursor側のみに存在するサーバー
  for server in $cursor_servers; do
    if ! echo "$claude_servers" | grep -qx "$server"; then
      echo "  ℹ mcpServers.$server: Cursor側のみ（正常）"
    fi
  done
  
  if [[ "$has_diff" == "true" ]]; then
    ((WARNINGS++))
    return 1
  fi
  
  return 0
}

# 設定ファイルの整合性チェック
check_config() {
  echo ""
  echo "[設定ファイル]"
  
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "  ℹ claude-compat-global.json: 未作成（初回同期が必要）"
    return 0
  fi
  
  if [[ "$HAS_JQ" != "true" ]]; then
    echo "  ℹ 設定ファイルの検証にはjqが必要です"
    return 0
  fi
  
  if ! validate_json "$CONFIG_FILE"; then
    echo "  ✗ claude-compat-global.json: 不正なJSON"
    ((ISSUES++))
    return 1
  fi
  
  local last_sync last_status
  last_sync=$(json_get "$CONFIG_FILE" '.lastSync')
  last_status=$(json_get "$CONFIG_FILE" '.lastSyncStatus')
  
  echo "  ✓ claude-compat-global.json: 有効"
  if [[ -n "$last_sync" ]]; then
    echo "    最終同期: $last_sync"
  fi
  if [[ -n "$last_status" ]]; then
    echo "    ステータス: $last_status"
  fi
  
  return 0
}

# =============================================================================
# ヘルプ表示
# =============================================================================
show_help() {
  cat << EOF
Usage: $0 [OPTIONS]

Claude グローバル設定の同期状態をチェックします。

チェック対象:
  - ~/.claude/CLAUDE.md と ~/.cursor/rules/claude-global.md
  - ~/.claude/skills/ シンボリックリンク
  - ~/.claude.json内mcpServers と ~/.cursor/mcp.json

OPTIONS:
  --help, -h    ヘルプ表示

OUTPUT:
  ✓ 同期済み / 正常
  ⚠ 差分あり / 警告
  ✗ エラー / 未作成
  ℹ 情報 / スキップ
EOF
}

# =============================================================================
# メイン処理
# =============================================================================
main() {
  # 引数解析
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        log_error "不明なオプション: $1"
        exit 1
        ;;
    esac
  done
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Cursor-Claude Compat - グローバル差分チェック"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # 依存関係チェック（警告のみ）
  if command -v jq &>/dev/null; then
    HAS_JQ=true
  else
    HAS_JQ=false
  fi
  
  # 設定ファイル読み込み
  load_global_config || true
  
  # 各項目をチェック
  check_rules
  check_skills
  check_mcp
  check_config
  
  # 結果サマリー
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  if [[ $ISSUES -eq 0 && $WARNINGS -eq 0 ]]; then
    log_success "すべて同期済みです"
  else
    if [[ $ISSUES -gt 0 ]]; then
      log_error "未同期の項目があります: $ISSUES 件"
    fi
    if [[ $WARNINGS -gt 0 ]]; then
      log_warn "差分のある項目があります: $WARNINGS 件"
    fi
    echo ""
    log_info "同期を実行するには: sync-global.sh"
  fi
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # 終了コード
  if [[ $ISSUES -gt 0 ]]; then
    exit 2
  elif [[ $WARNINGS -gt 0 ]]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"
