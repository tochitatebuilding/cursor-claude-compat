#!/usr/bin/env bash
#
# common.sh - Cursor-Claude Compat 共通ライブラリ
#
# プロジェクト版（sync.sh）とグローバル版（sync-global.sh）で共通の関数を提供
#

# =============================================================================
# グローバル変数
# =============================================================================

# 色付き出力
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_NC='\033[0m' # No Color

# オプション（両スクリプトで共通）
FORCE=false
SKIP_EXISTING=false
YES_MODE=false
DRY_RUN=false
NO_BACKUP=false
NO_BACKUP_CLEANUP=false

# 依存関係フラグ
HAS_JQ=false
HAS_RSYNC=false

# 競合解決ポリシー（対話中に「以降すべて」が選択された場合に設定）
CONFLICT_POLICY=""

# 最後の競合解決結果
# shellcheck disable=SC2034  # Used in sync.sh and sync-global.sh
CONFLICT_ACTION=""

# バックアップディレクトリ（呼び出し側で設定）
BACKUP_DIR=""

# 保持するバックアップの最大数
BACKUP_KEEP_COUNT=5

# =============================================================================
# ログ関数
# =============================================================================

log_info() {
  echo -e "${COLOR_BLUE}ℹ${COLOR_NC} $*"
}

log_success() {
  echo -e "${COLOR_GREEN}✓${COLOR_NC} $*"
}

log_warn() {
  echo -e "${COLOR_YELLOW}⚠${COLOR_NC} $*"
}

log_error() {
  echo -e "${COLOR_RED}✗${COLOR_NC} $*" >&2
}

# =============================================================================
# パス展開
# =============================================================================

# ~ を $HOME に展開し、絶対パスに変換
expand_path() {
  local path="$1"
  # ~ を $HOME に置換
  path="${path/#\~/$HOME}"
  # 相対パスを絶対パスに（存在する場合）
  if [[ -e "$path" ]]; then
    realpath "$path"
  else
    echo "$path"
  fi
}

# =============================================================================
# 依存チェック
# =============================================================================

# jq, rsync の存在確認、フラグ設定
check_dependencies() {
  # jq チェック（なければMCP同期をスキップ）
  if command -v jq &>/dev/null; then
    HAS_JQ=true
  else
    HAS_JQ=false
    log_warn "jq が見つかりません。MCP設定の同期はスキップされます。"
    log_info "MCP同期を有効にするには: sudo apt install jq (または brew install jq)"
  fi
  
  # rsync チェック
  if command -v rsync &>/dev/null; then
    HAS_RSYNC=true
  else
    HAS_RSYNC=false
  fi
}

# シンボリックリンクが使えるかテスト
check_symlink_support() {
  local test_dir
  test_dir=$(mktemp -d)
  local test_target="$test_dir/target"
  local test_link="$test_dir/link"
  
  mkdir -p "$test_target"
  if ln -s "$test_target" "$test_link" 2>/dev/null; then
    rm -rf "$test_dir"
    return 0
  else
    rm -rf "$test_dir"
    return 1
  fi
}

# Cursorで実行されているかチェック
is_cursor() {
  [[ -n "${CURSOR_AGENT:-}" ]] || \
  [[ "${VSCODE_CWD:-}" == *"cursor"* ]] || \
  [[ "${PATH:-}" == *".cursor-server"* ]]
}

# =============================================================================
# バックアップ/ロールバック
# =============================================================================

# バックアップディレクトリを初期化
init_backup_dir() {
  local base_dir="$1"
  BACKUP_DIR="${base_dir}/.claude-compat-backup"
  mkdir -p "$BACKUP_DIR"
}

# 古いバックアップを削除（最新N件を保持）
cleanup_old_backups() {
  local basename="$1"
  
  if [[ "$NO_BACKUP_CLEANUP" == "true" ]]; then
    return 0
  fi
  
  # 古い順にソートして、keep_count件を超えるものを削除
  local old_backups
  # Use find instead of ls for better handling of non-alphanumeric filenames
  # shellcheck disable=SC2012  # ls is acceptable here for timestamp sorting
  old_backups=$(ls -t "${BACKUP_DIR}/${basename}."* 2>/dev/null | tail -n +$((BACKUP_KEEP_COUNT + 1)) || true)
  
  if [[ -n "$old_backups" ]]; then
    echo "$old_backups" | xargs -r rm -rf
  fi
}

# ファイルをバックアップ（タイムスタンプ付き）
backup_file() {
  local file="$1"
  
  if [[ "$NO_BACKUP" == "true" ]]; then
    return 0
  fi
  
  if [[ ! -e "$file" ]]; then
    return 0
  fi
  
  if [[ -z "$BACKUP_DIR" ]]; then
    log_error "BACKUP_DIR が設定されていません"
    return 1
  fi
  
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local basename
  basename=$(basename "$file")
  local backup_path="${BACKUP_DIR}/${basename}.${timestamp}"
  
  mkdir -p "$BACKUP_DIR"
  
  if [[ -L "$file" ]]; then
    # シンボリックリンクの場合はリンク自体をコピー
    cp -P "$file" "$backup_path"
  else
    cp -a "$file" "$backup_path"
  fi
  
  log_info "バックアップ作成: $backup_path"
  
  # 古いバックアップを削除
  cleanup_old_backups "$basename"
}

# ディレクトリをバックアップ
backup_directory() {
  local dir="$1"
  
  if [[ "$NO_BACKUP" == "true" ]]; then
    return 0
  fi
  
  if [[ ! -e "$dir" ]]; then
    return 0
  fi
  
  if [[ -z "$BACKUP_DIR" ]]; then
    log_error "BACKUP_DIR が設定されていません"
    return 1
  fi
  
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local basename
  basename=$(basename "$dir")
  local backup_path="${BACKUP_DIR}/${basename}.${timestamp}"
  
  mkdir -p "$BACKUP_DIR"
  
  if [[ -L "$dir" ]]; then
    # シンボリックリンクの場合はリンク自体をコピー
    cp -P "$dir" "$backup_path"
  else
    cp -a "$dir" "$backup_path"
  fi
  
  log_info "バックアップ作成: $backup_path"
  
  # 古いバックアップを削除
  cleanup_old_backups "$basename"
}

# 最新のバックアップから復元
rollback_file() {
  local file="$1"
  
  if [[ -z "$BACKUP_DIR" ]]; then
    log_error "BACKUP_DIR が設定されていません"
    return 1
  fi
  
  local basename
  basename=$(basename "$file")
  local latest_backup
  # shellcheck disable=SC2012  # ls -t is acceptable here for timestamp sorting of backup files
  latest_backup=$(ls -t "${BACKUP_DIR}/${basename}."* 2>/dev/null | head -1 || true)
  
  if [[ -n "$latest_backup" && -e "$latest_backup" ]]; then
    # 現在のファイルを削除
    rm -rf "$file"
    
    if [[ -L "$latest_backup" ]]; then
      cp -P "$latest_backup" "$file"
    else
      cp -a "$latest_backup" "$file"
    fi
    
    log_success "ロールバック完了: $file (from $latest_backup)"
    return 0
  else
    log_error "バックアップが見つかりません: $file"
    return 1
  fi
}

# =============================================================================
# 競合解決
# =============================================================================

# 競合時の対話確認 + 「以降すべて」オプション
# 結果は CONFLICT_ACTION に設定される
# 戻り値: "backup", "skip", "all_backup", "all_skip"
resolve_conflict() {
  local file="$1"
  
  # オプションの優先順位チェック
  # --force > --skip-existing > --yes > 対話
  if [[ "$FORCE" == "true" ]]; then
    CONFLICT_ACTION="backup"
    return 0
  fi
  
  if [[ "$SKIP_EXISTING" == "true" ]]; then
    CONFLICT_ACTION="skip"
    return 0
  fi
  
  # グローバルポリシーが設定されている場合
  if [[ "$CONFLICT_POLICY" == "all_backup" ]]; then
    CONFLICT_ACTION="backup"
    return 0
  fi
  
  if [[ "$CONFLICT_POLICY" == "all_skip" ]]; then
    CONFLICT_ACTION="skip"
    return 0
  fi
  
  # --yes モード（デフォルト: バックアップ後上書き）
  if [[ "$YES_MODE" == "true" ]]; then
    CONFLICT_ACTION="backup"
    return 0
  fi
  
  # 対話モード
  echo ""
  log_warn "既存ファイルがあります: $file"
  echo "  [B]ackup & overwrite - バックアップ後上書き"
  echo "  [S]kip              - スキップ（既存を維持）"
  echo "  [A]ll backup        - 以降すべてバックアップ後上書き"
  echo "  [N]one              - 以降すべてスキップ"
  echo ""
  
  while true; do
    read -rp "  選択 [B/S/A/N]: " choice
    case "$choice" in
      [Bb])
        CONFLICT_ACTION="backup"
        return 0
        ;;
      [Ss])
        CONFLICT_ACTION="skip"
        return 0
        ;;
      [Aa])
        CONFLICT_ACTION="backup"
        CONFLICT_POLICY="all_backup"
        return 0
        ;;
      [Nn])
        CONFLICT_ACTION="skip"
        CONFLICT_POLICY="all_skip"
        return 0
        ;;
      *)
        echo "  無効な入力です。B, S, A, N のいずれかを入力してください。"
        ;;
    esac
  done
}

# =============================================================================
# オプション解析ヘルパー
# =============================================================================

# 矛盾するオプションのチェック
validate_options() {
  if [[ "$FORCE" == "true" && "$SKIP_EXISTING" == "true" ]]; then
    log_error "--force と --skip-existing は同時に指定できません"
    return 1
  fi
  return 0
}

# 共通オプションの解析
# 使用方法: remaining_args=$(parse_common_options "$@")
parse_common_option() {
  local arg="$1"
  
  case "$arg" in
    --force|-f)
      FORCE=true
      return 0
      ;;
    --skip-existing)
      SKIP_EXISTING=true
      return 0
      ;;
    --yes|-y)
      YES_MODE=true
      return 0
      ;;
    --dry-run|-n)
      DRY_RUN=true
      return 0
      ;;
    --no-backup)
      NO_BACKUP=true
      return 0
      ;;
    --no-backup-cleanup)
      NO_BACKUP_CLEANUP=true
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# =============================================================================
# frontmatter 処理
# =============================================================================

# frontmatter（---で囲まれたYAMLブロック）を除外して内容を抽出
# 1行目が --- で始まる場合のみ frontmatter とみなす
# 2個目の --- 以降は全て本文
extract_content_without_frontmatter() {
  local file="$1"
  awk '
    NR == 1 && /^---$/ { in_frontmatter=1; next }
    in_frontmatter && /^---$/ { in_frontmatter=0; next }
    !in_frontmatter { print }
  ' "$file"
}

# =============================================================================
# JSON操作（jqが必要）
# =============================================================================

# JSONファイルが有効か検証
validate_json() {
  local file="$1"
  
  if [[ "$HAS_JQ" != "true" ]]; then
    log_error "jq がインストールされていません"
    return 1
  fi
  
  if [[ ! -f "$file" ]]; then
    return 1
  fi
  
  if jq empty "$file" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# JSONファイルから値を取得
json_get() {
  local file="$1"
  local key="$2"
  local default="${3:-}"
  
  if [[ "$HAS_JQ" != "true" ]]; then
    echo "$default"
    return
  fi
  
  local value
  value=$(jq -r "$key // empty" "$file" 2>/dev/null || true)
  
  if [[ -n "$value" ]]; then
    echo "$value"
  else
    echo "$default"
  fi
}

# =============================================================================
# その他のユーティリティ
# =============================================================================

# 安全なディレクトリ削除（バックアップ後）
safe_remove() {
  local target="$1"
  
  if [[ ! -e "$target" ]]; then
    return 0
  fi
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] 削除: $target"
    return 0
  fi
  
  # バックアップを作成
  if [[ -d "$target" ]]; then
    backup_directory "$target"
  else
    backup_file "$target"
  fi
  
  rm -rf "$target"
}

# ディレクトリをコピー（rsyncがあれば使用）
copy_directory() {
  local source="$1"
  local target="$2"
  
  if [[ "$HAS_RSYNC" == "true" ]]; then
    rsync -av --delete "$source/" "$target/"
  else
    rm -rf "$target"
    cp -r "$source" "$target"
  fi
}
