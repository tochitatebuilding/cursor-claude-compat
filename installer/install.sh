#!/usr/bin/env bash
#
# install.sh - Cursor-Claude Compat ツールキットのインストール
#
# グローバルスキルとルールを ~/.cursor/ にインストールします
#
set -euo pipefail

# =============================================================================
# 定数
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

CURSOR_DIR="${HOME}/.cursor"
SKILLS_DIR="${CURSOR_DIR}/skills-cursor"
RULES_DIR="${CURSOR_DIR}/rules"

SKILL_NAME="sync-claude-docs"
RULE_NAME="cursor-claude-compat.md"

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
  echo " Cursor-Claude Compat - インストーラー"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Cursorディレクトリの確認
  if [[ ! -d "$CURSOR_DIR" ]]; then
    log_warn "Cursorディレクトリが見つかりません: $CURSOR_DIR"
    log_info "ディレクトリを作成します..."
    mkdir -p "$CURSOR_DIR"
  fi
  
  # ==========================================================================
  # スキルのインストール
  # ==========================================================================
  local skill_target="${SKILLS_DIR}/${SKILL_NAME}"
  
  log_info "グローバルスキルをインストール中..."
  
  # 既存のバックアップ
  if [[ -d "$skill_target" ]]; then
    local backup="${skill_target}.backup.$(date +%Y%m%d%H%M%S)"
    log_warn "既存のスキルをバックアップ: $backup"
    mv "$skill_target" "$backup"
  fi
  
  # スキルディレクトリを作成
  mkdir -p "$skill_target"
  mkdir -p "$skill_target/lib"
  
  # プロジェクト同期スキル
  cp "${REPO_DIR}/src/skill/SKILL.md" "${skill_target}/SKILL.md"
  log_success "スキルファイルをコピー: SKILL.md"
  
  # グローバル同期スキル
  cp "${REPO_DIR}/src/skill/SKILL-global.md" "${skill_target}/SKILL-global.md"
  log_success "スキルファイルをコピー: SKILL-global.md"
  
  # 共通ライブラリ
  cp "${REPO_DIR}/src/scripts/lib/common.sh" "${skill_target}/lib/common.sh"
  chmod +x "${skill_target}/lib/common.sh"
  log_success "共通ライブラリをコピー: lib/common.sh"
  
  # プロジェクト同期スクリプト
  cp "${REPO_DIR}/src/scripts/sync.sh" "${skill_target}/sync.sh"
  chmod +x "${skill_target}/sync.sh"
  log_success "スクリプトをコピー: sync.sh"
  
  # プロジェクト差分チェックスクリプト
  cp "${REPO_DIR}/src/scripts/check.sh" "${skill_target}/check.sh"
  chmod +x "${skill_target}/check.sh"
  log_success "スクリプトをコピー: check.sh"
  
  # グローバル同期スクリプト
  cp "${REPO_DIR}/src/scripts/sync-global.sh" "${skill_target}/sync-global.sh"
  chmod +x "${skill_target}/sync-global.sh"
  log_success "スクリプトをコピー: sync-global.sh"
  
  # グローバル差分チェックスクリプト
  cp "${REPO_DIR}/src/scripts/check-global.sh" "${skill_target}/check-global.sh"
  chmod +x "${skill_target}/check-global.sh"
  log_success "スクリプトをコピー: check-global.sh"
  
  log_success "スキルをインストール: $skill_target"
  
  # ==========================================================================
  # ルールのインストール
  # ==========================================================================
  log_info "グローバルルールをインストール中..."
  
  mkdir -p "$RULES_DIR"
  
  local rule_target="${RULES_DIR}/${RULE_NAME}"
  
  # 既存のバックアップ
  if [[ -f "$rule_target" ]]; then
    local backup="${rule_target}.backup.$(date +%Y%m%d%H%M%S)"
    log_warn "既存のルールをバックアップ: $backup"
    mv "$rule_target" "$backup"
  fi
  
  cp "${REPO_DIR}/src/rule/cursor-claude-compat.md" "$rule_target"
  
  log_success "ルールをインストール: $rule_target"
  
  # ==========================================================================
  # 依存関係チェック
  # ==========================================================================
  echo ""
  log_info "依存関係をチェック中..."
  
  local missing_deps=()
  
  if ! command -v jq &>/dev/null; then
    missing_deps+=("jq")
  fi
  
  if ! command -v rsync &>/dev/null; then
    missing_deps+=("rsync")
  fi
  
  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    log_warn "以下の推奨依存関係がインストールされていません:"
    for dep in "${missing_deps[@]}"; do
      echo "  - $dep"
    done
    echo ""
    log_info "インストール方法:"
    echo "  Ubuntu/Debian: sudo apt install ${missing_deps[*]}"
    echo "  macOS: brew install ${missing_deps[*]}"
    echo ""
    log_info "jq がないと MCP設定の同期はスキップされます"
  else
    log_success "すべての推奨依存関係がインストールされています"
  fi
  
  # ==========================================================================
  # 完了メッセージ
  # ==========================================================================
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " インストール完了"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "インストールされたファイル:"
  echo ""
  echo "  スキル:"
  echo "    - ${skill_target}/SKILL.md"
  echo "    - ${skill_target}/SKILL-global.md"
  echo "    - ${skill_target}/lib/common.sh"
  echo "    - ${skill_target}/sync.sh"
  echo "    - ${skill_target}/check.sh"
  echo "    - ${skill_target}/sync-global.sh"
  echo "    - ${skill_target}/check-global.sh"
  echo ""
  echo "  ルール:"
  echo "    - ${rule_target}"
  echo ""
  echo "使用方法:"
  echo ""
  echo "  プロジェクト単位の同期:"
  echo "    1. Cursorでプロジェクトを開く"
  echo "    2. /sync-claude-docs と入力してスキルを実行"
  echo ""
  echo "  グローバル設定の同期:"
  echo "    1. /sync-claude-global と入力してスキルを実行"
  echo "    または: ${skill_target}/sync-global.sh"
  echo ""
}

main "$@"
