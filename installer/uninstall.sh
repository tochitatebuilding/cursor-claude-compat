#!/usr/bin/env bash
#
# uninstall.sh - Cursor-Claude Compat ツールキットのアンインストール
#
set -euo pipefail

# =============================================================================
# 定数
# =============================================================================
CURSOR_DIR="${HOME}/.cursor"
SKILLS_DIR="${CURSOR_DIR}/skills-cursor"
RULES_DIR="${CURSOR_DIR}/rules"
BACKUP_DIR="${CURSOR_DIR}/.claude-compat-backup"

SKILL_NAME="sync-claude-docs"
RULE_NAME="cursor-claude-compat.md"
GLOBAL_CONFIG="claude-compat-global.json"
GLOBAL_RULE="claude-global.md"
GLOBAL_SKILLS="claude-skills"

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

# =============================================================================
# メイン処理
# =============================================================================
main() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Cursor-Claude Compat - アンインストーラー"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  local removed=0
  
  # ==========================================================================
  # スキルの削除
  # ==========================================================================
  local skill_target="${SKILLS_DIR}/${SKILL_NAME}"
  
  if [[ -d "$skill_target" ]]; then
    log_info "スキルを削除中: $skill_target"
    rm -rf "$skill_target"
    log_success "スキルを削除しました"
    ((removed++))
  else
    log_info "スキルが見つかりません: $skill_target"
  fi
  
  # スキルのバックアップも削除するか確認
  local skill_backups
  skill_backups=$(find "$SKILLS_DIR" -maxdepth 1 -name "${SKILL_NAME}.backup.*" -type d 2>/dev/null || true)
  
  if [[ -n "$skill_backups" ]]; then
    echo ""
    echo "スキルのバックアップが見つかりました:"
    echo "$skill_backups"
    echo ""
    read -rp "バックアップも削除しますか? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
      echo "$skill_backups" | xargs rm -rf
      log_success "スキルのバックアップを削除しました"
    fi
  fi
  
  # ==========================================================================
  # ルールの削除
  # ==========================================================================
  local rule_target="${RULES_DIR}/${RULE_NAME}"
  
  if [[ -f "$rule_target" ]]; then
    log_info "ルールを削除中: $rule_target"
    rm -f "$rule_target"
    log_success "ルールを削除しました"
    ((removed++))
  else
    log_info "ルールが見つかりません: $rule_target"
  fi
  
  # ルールのバックアップも削除するか確認
  local rule_backups
  rule_backups=$(find "$RULES_DIR" -maxdepth 1 -name "${RULE_NAME}.backup.*" -type f 2>/dev/null || true)
  
  if [[ -n "$rule_backups" ]]; then
    echo ""
    echo "ルールのバックアップが見つかりました:"
    echo "$rule_backups"
    echo ""
    read -rp "バックアップも削除しますか? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
      echo "$rule_backups" | xargs rm -f
      log_success "ルールのバックアップを削除しました"
    fi
  fi
  
  # ==========================================================================
  # グローバル同期関連ファイルの削除
  # ==========================================================================
  echo ""
  log_info "グローバル同期関連ファイルをチェック中..."
  
  # グローバル設定ファイル
  local global_config="${CURSOR_DIR}/${GLOBAL_CONFIG}"
  if [[ -f "$global_config" ]]; then
    echo ""
    echo "グローバル同期設定ファイルが見つかりました:"
    echo "  $global_config"
    read -rp "削除しますか? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
      rm -f "$global_config"
      log_success "グローバル設定ファイルを削除しました"
      ((removed++))
    fi
  fi
  
  # グローバルルール（同期で作成されたもの）
  local global_rule="${RULES_DIR}/${GLOBAL_RULE}"
  if [[ -f "$global_rule" ]]; then
    echo ""
    echo "同期で作成されたグローバルルールが見つかりました:"
    echo "  $global_rule"
    read -rp "削除しますか? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
      rm -f "$global_rule"
      log_success "グローバルルールを削除しました"
      ((removed++))
    fi
  fi
  
  # グローバルスキル（シンボリックリンク）
  local global_skills="${SKILLS_DIR}/${GLOBAL_SKILLS}"
  if [[ -e "$global_skills" ]]; then
    echo ""
    if [[ -L "$global_skills" ]]; then
      echo "同期で作成されたスキルのシンボリックリンクが見つかりました:"
    else
      echo "同期で作成されたスキルのコピーが見つかりました:"
    fi
    echo "  $global_skills"
    read -rp "削除しますか? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
      rm -rf "$global_skills"
      log_success "グローバルスキルを削除しました"
      ((removed++))
    fi
  fi
  
  # ==========================================================================
  # バックアップディレクトリの削除
  # ==========================================================================
  if [[ -d "$BACKUP_DIR" ]]; then
    echo ""
    echo "バックアップディレクトリが見つかりました:"
    echo "  $BACKUP_DIR"
    
    # バックアップの内容を表示
    local backup_count
    backup_count=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)
    echo "  （${backup_count} 個のバックアップファイル）"
    
    echo ""
    read -rp "バックアップディレクトリを削除しますか? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
      rm -rf "$BACKUP_DIR"
      log_success "バックアップディレクトリを削除しました"
      ((removed++))
    else
      log_info "バックアップディレクトリは残されます"
    fi
  fi
  
  # ==========================================================================
  # 完了メッセージ
  # ==========================================================================
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  if [[ $removed -gt 0 ]]; then
    echo " アンインストール完了"
  else
    echo " 削除対象がありませんでした"
  fi
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "注意:"
  echo "  - プロジェクトごとの設定ファイル (.cursor/claude-compat.json) は"
  echo "    各プロジェクトに残っています。必要に応じて手動で削除してください。"
  echo ""
  echo "  - Claude側の設定 (~/.claude/, ~/.claude.json) は変更されていません。"
  echo ""
}

main "$@"
