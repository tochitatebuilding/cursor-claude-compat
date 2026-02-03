#!/usr/bin/env bash
#
# sync.sh - Claude Code ドキュメントを Cursor に同期
#
# Usage: sync.sh [OPTIONS]
#
# OPTIONS:
#   --yes, -y           非対話モード（デフォルト: バックアップ後上書き）
#   --skip-existing     既存ファイルはスキップ
#   --force, -f         既存ファイルを確認なしで上書き（バックアップは作成）
#   --dry-run, -n       実際には実行せず、何が行われるか表示
#   --no-backup         バックアップを作成しない（非推奨）
#   --help, -h          ヘルプ表示
#
set -euo pipefail

# =============================================================================
# 定数・初期化
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE=".cursor/claude-compat.json"
VERSION="1"

# 共通ライブラリを読み込み
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  # フォールバック: インストール先から読み込み
  INSTALLED_LIB="${HOME}/.cursor/skills-cursor/sync-claude-docs/lib/common.sh"
  if [[ -f "$INSTALLED_LIB" ]]; then
    # shellcheck source=/dev/null
    source "$INSTALLED_LIB"
  else
    echo "Error: common.sh が見つかりません" >&2
    exit 1
  fi
fi

# =============================================================================
# 設定ファイル操作
# =============================================================================

# 設定ファイルを読み込み
load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    return 1
  fi
  
  if [[ "$HAS_JQ" == "true" ]]; then
    SOURCE_PLANS=$(json_get "$CONFIG_FILE" '.source.plans')
    SOURCE_SKILLS=$(json_get "$CONFIG_FILE" '.source.skills')
    SOURCE_RULES=$(json_get "$CONFIG_FILE" '.source.rules')
    TARGET_PLANS=$(json_get "$CONFIG_FILE" '.target.plans' '.cursor/plans')
    TARGET_SKILLS=$(json_get "$CONFIG_FILE" '.target.skills' '.cursor/skills')
    TARGET_RULES=$(json_get "$CONFIG_FILE" '.target.rules' '.cursor/rules')
  else
    # jqがない場合はgrepで簡易パース
    SOURCE_PLANS=$(grep -oP '"plans"\s*:\s*"\K[^"]+' "$CONFIG_FILE" 2>/dev/null | head -1 || true)
    SOURCE_SKILLS=$(grep -oP '"skills"\s*:\s*"\K[^"]+' "$CONFIG_FILE" 2>/dev/null | head -1 || true)
    SOURCE_RULES=$(grep -oP '"rules"\s*:\s*"\K[^"]+' "$CONFIG_FILE" 2>/dev/null | head -1 || true)
    TARGET_PLANS=".cursor/plans"
    TARGET_SKILLS=".cursor/skills"
    TARGET_RULES=".cursor/rules"
  fi
  
  return 0
}

# 設定ファイルを保存
save_config() {
  local plans_dir="$1"
  local skills_dir="$2"
  local rules_dir="$3"
  local sync_method="$4"
  local status="${5:-success}"
  
  mkdir -p "$(dirname "$CONFIG_FILE")"
  
  cat > "$CONFIG_FILE" << EOF
{
  "version": "$VERSION",
  "source": {
    "plans": "$plans_dir",
    "skills": "$skills_dir",
    "rules": "$rules_dir"
  },
  "target": {
    "plans": ".cursor/plans",
    "skills": ".cursor/skills",
    "rules": ".cursor/rules"
  },
  "syncMethod": {
    "plans": "$sync_method",
    "skills": "$sync_method",
    "rules": "convert"
  },
  "lastSync": "$(date -Iseconds)",
  "lastSyncStatus": "$status"
}
EOF
  
  log_success "設定ファイルを保存: $CONFIG_FILE"
}

# 設定の参照先が有効かチェック
validate_config() {
  local valid=true
  
  if [[ -n "$SOURCE_PLANS" ]] && [[ ! -d "$SOURCE_PLANS" ]]; then
    log_warn "plans ディレクトリが見つかりません: $SOURCE_PLANS"
    valid=false
  fi
  
  if [[ -n "$SOURCE_SKILLS" ]] && [[ ! -d "$SOURCE_SKILLS" ]]; then
    log_warn "skills ディレクトリが見つかりません: $SOURCE_SKILLS"
    valid=false
  fi
  
  if [[ -n "$SOURCE_RULES" ]] && [[ ! -d "$SOURCE_RULES" ]]; then
    log_warn "rules ディレクトリが見つかりません: $SOURCE_RULES"
    valid=false
  fi
  
  [[ "$valid" == "true" ]]
}

# =============================================================================
# 対話モード
# =============================================================================
run_interactive_setup() {
  echo ""
  log_info "Claude Code ドキュメントディレクトリを検出中..."
  echo ""
  
  # 候補ディレクトリを検索
  local candidates=("docs/plans" "docs/skills" "docs/rules" ".claude/plans" ".claude/skills" ".claude/rules")
  local found=()
  
  for dir in "${candidates[@]}"; do
    if [[ -d "$dir" ]]; then
      found+=("$dir")
    fi
  done
  
  local plans_dir=""
  local skills_dir=""
  local rules_dir=""
  
  if [[ ${#found[@]} -gt 0 ]]; then
    echo "以下のディレクトリが見つかりました:"
    printf '  - %s\n' "${found[@]}"
    echo ""
    
    # 自動検出を試行
    for dir in "${found[@]}"; do
      case "$dir" in
        *plans*) [[ -z "$plans_dir" ]] && plans_dir="$dir" ;;
        *skills*) [[ -z "$skills_dir" ]] && skills_dir="$dir" ;;
        *rules*) [[ -z "$rules_dir" ]] && rules_dir="$dir" ;;
      esac
    done
    
    echo "検出された設定:"
    echo "  plans:  ${plans_dir:-（なし）}"
    echo "  skills: ${skills_dir:-（なし）}"
    echo "  rules:  ${rules_dir:-（なし）}"
    echo ""
    
    read -rp "この設定で続行しますか? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn] ]]; then
      plans_dir=""
      skills_dir=""
      rules_dir=""
    fi
  fi
  
  # 手動入力
  if [[ -z "$plans_dir" && -z "$skills_dir" && -z "$rules_dir" ]]; then
    echo ""
    echo "ディレクトリパスを入力してください（空欄でスキップ）:"
    read -rp "  plans ディレクトリ: " plans_dir
    read -rp "  skills ディレクトリ: " skills_dir
    read -rp "  rules ディレクトリ: " rules_dir
  fi
  
  # 少なくとも1つは必要
  if [[ -z "$plans_dir" && -z "$skills_dir" && -z "$rules_dir" ]]; then
    log_error "同期元ディレクトリが指定されていません"
    exit 1
  fi
  
  # 存在確認
  for dir in "$plans_dir" "$skills_dir" "$rules_dir"; do
    if [[ -n "$dir" && ! -d "$dir" ]]; then
      log_error "ディレクトリが存在しません: $dir"
      exit 1
    fi
  done
  
  # 同期方式を決定
  local sync_method="symlink"
  if ! check_symlink_support; then
    log_warn "シンボリックリンクが使用できません。コピー方式を使用します。"
    sync_method="copy"
  fi
  
  # 設定を保存
  save_config "$plans_dir" "$skills_dir" "$rules_dir" "$sync_method"
  
  # グローバル変数を更新
  SOURCE_PLANS="$plans_dir"
  SOURCE_SKILLS="$skills_dir"
  SOURCE_RULES="$rules_dir"
  TARGET_PLANS=".cursor/plans"
  TARGET_SKILLS=".cursor/skills"
  TARGET_RULES=".cursor/rules"
}

# =============================================================================
# 同期処理
# =============================================================================

# ディレクトリを同期（シンボリックリンク or コピー）
sync_directory() {
  local source="$1"
  local target="$2"
  local method="$3"
  
  if [[ -z "$source" || ! -d "$source" ]]; then
    return 0
  fi
  
  # 既存ターゲットの処理
  if [[ -e "$target" ]]; then
    if [[ -L "$target" ]]; then
      # シンボリックリンクの場合はバックアップして削除
      if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] シンボリックリンクを削除: $target"
      else
        backup_file "$target"
        rm "$target"
      fi
    elif [[ -d "$target" ]]; then
      # ディレクトリの場合は競合解決
      resolve_conflict "$target"
      
      if [[ "$CONFLICT_ACTION" == "skip" ]]; then
        log_info "スキップ: $target"
        return 0
      fi
      
      if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] バックアップ後削除: $target"
      else
        backup_directory "$target"
        rm -rf "$target"
      fi
    fi
  fi
  
  # 親ディレクトリ作成
  mkdir -p "$(dirname "$target")"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] $method: $source -> $target"
    return 0
  fi
  
  if [[ "$method" == "symlink" ]] && check_symlink_support; then
    # 相対パスでシンボリックリンク作成
    local relative_source
    relative_source=$(realpath --relative-to="$(dirname "$target")" "$source")
    ln -s "$relative_source" "$target"
    log_success "シンボリックリンク作成: $target -> $relative_source"
  else
    # rsync でコピー（なければ cp）
    copy_directory "$source" "$target"
    log_success "コピー完了: $source -> $target"
  fi
}

# ルールを変換して同期
sync_rules() {
  local source="$1"
  local target="$2"
  
  if [[ -z "$source" || ! -d "$source" ]]; then
    return 0
  fi
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] ルール変換: $source -> $target"
    return 0
  fi
  
  # 既存ターゲットの処理
  if [[ -d "$target" ]]; then
    resolve_conflict "$target"
    
    if [[ "$CONFLICT_ACTION" == "skip" ]]; then
      log_info "スキップ: $target"
      return 0
    fi
    
    backup_directory "$target"
    rm -rf "$target"
  fi
  
  mkdir -p "$target"
  
  # 各ファイルを変換
  local count=0
  for source_file in "$source"/*.md; do
    [[ -f "$source_file" ]] || continue
    
    local basename
    basename=$(basename "$source_file")
    local target_file="$target/$basename"
    
    convert_rule_to_cursor "$source_file" "$target_file"
    ((count++))
  done
  
  if [[ $count -gt 0 ]]; then
    log_success "ルール変換完了: $count ファイル ($source -> $target)"
  else
    log_info "変換対象のルールファイルがありません: $source"
  fi
}

# Claude形式 → Cursor形式 変換
convert_rule_to_cursor() {
  local source_file="$1"
  local target_file="$2"
  
  local basename
  basename=$(basename "$source_file" .md)
  
  # ファイル名からglobsを推測
  local globs='["**/*"]'
  case "$basename" in
    *typescript*|*ts*) globs='["**/*.ts", "**/*.tsx"]' ;;
    *javascript*|*js*) globs='["**/*.js", "**/*.jsx"]' ;;
    *python*|*py*) globs='["**/*.py"]' ;;
    *astro*) globs='["**/*.astro"]' ;;
    *react*) globs='["**/*.tsx", "**/*.jsx"]' ;;
    *css*|*style*) globs='["**/*.css", "**/*.scss"]' ;;
    *html*) globs='["**/*.html"]' ;;
    *json*) globs='["**/*.json"]' ;;
    *yaml*|*yml*) globs='["**/*.yaml", "**/*.yml"]' ;;
    *markdown*|*md*) globs='["**/*.md"]' ;;
  esac
  
  # 最初の見出しからdescriptionを抽出
  local first_heading
  first_heading=$(grep -m1 '^#' "$source_file" 2>/dev/null | sed 's/^#* *//' || echo "")
  local description="${first_heading:-$basename}"
  
  # frontmatterを生成してファイルを出力
  {
    echo "---"
    echo "description: $description"
    echo "globs: $globs"
    echo "alwaysApply: false"
    echo "---"
    echo ""
    cat "$source_file"
  } > "$target_file"
}

# =============================================================================
# ヘルプ表示
# =============================================================================
show_help() {
  cat << EOF
Usage: $0 [OPTIONS]

Claude Code ドキュメントを Cursor に同期します。

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
  $0 --force          # 強制上書き（バックアップは作成）
  $0 --dry-run        # プレビューのみ
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
  echo " Cursor-Claude Compat - 同期ツール"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # 依存関係チェック
  check_dependencies
  
  # バックアップディレクトリを初期化
  init_backup_dir ".cursor"
  
  # 設定ファイル確認
  if ! load_config; then
    if [[ "$YES_MODE" == "true" ]]; then
      log_error "設定ファイルが見つかりません。"
      log_info "対話モードで初回セットアップを行ってください: $0"
      exit 1
    fi
    log_info "設定ファイルが見つかりません。対話モードでセットアップします。"
    run_interactive_setup
  elif ! validate_config; then
    if [[ "$YES_MODE" == "true" ]]; then
      log_error "設定ファイルの参照先が無効です。"
      log_info "対話モードで再セットアップを行ってください: $0"
      exit 1
    fi
    log_warn "設定ファイルの参照先が無効です。再セットアップします。"
    run_interactive_setup
  else
    log_info "設定ファイルを読み込みました: $CONFIG_FILE"
  fi
  
  echo ""
  log_info "同期を開始します..."
  echo ""
  
  # 同期方式を決定
  local sync_method="symlink"
  if ! check_symlink_support; then
    sync_method="copy"
  fi
  
  # 同期結果を追跡
  local sync_status="success"
  local plans_result="skipped"
  local skills_result="skipped"
  local rules_result="skipped"
  
  # plans/skills を同期
  if [[ -n "$SOURCE_PLANS" && -d "$SOURCE_PLANS" ]]; then
    if sync_directory "$SOURCE_PLANS" "$TARGET_PLANS" "$sync_method"; then
      plans_result="success"
    else
      plans_result="failed"
      sync_status="partial"
    fi
  fi
  
  if [[ -n "$SOURCE_SKILLS" && -d "$SOURCE_SKILLS" ]]; then
    if sync_directory "$SOURCE_SKILLS" "$TARGET_SKILLS" "$sync_method"; then
      skills_result="success"
    else
      skills_result="failed"
      sync_status="partial"
    fi
  fi
  
  # rules を変換同期
  if [[ -n "$SOURCE_RULES" && -d "$SOURCE_RULES" ]]; then
    if sync_rules "$SOURCE_RULES" "$TARGET_RULES"; then
      rules_result="success"
    else
      rules_result="failed"
      sync_status="partial"
    fi
  fi
  
  # 設定ファイルを更新（lastSyncを記録）
  if [[ "$DRY_RUN" != "true" ]]; then
    save_config "$SOURCE_PLANS" "$SOURCE_SKILLS" "$SOURCE_RULES" "$sync_method" "$sync_status"
  fi
  
  echo ""
  log_success "同期が完了しました!"
  echo ""
  echo "同期結果:"
  echo "  plans:  $plans_result"
  echo "  skills: $skills_result"
  echo "  rules:  $rules_result"
  echo ""
}

main "$@"
