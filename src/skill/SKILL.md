# Claude Docs を Cursor に同期

## Purpose

Claude Code用の `docs/plans/`, `docs/skills/`, `docs/rules/` を `.cursor/` 配下に同期し、CursorとClaude Codeの両方からアクセス可能にします。また、`.mcp.json` のMCPサーバー設定を `.cursor/mcp.json` に安全マージします。

## Preconditions

- プロジェクトに Claude Code 用のドキュメントディレクトリが存在する
  - `docs/plans/`
  - `docs/skills/`
  - `docs/rules/`
- または `.mcp.json` が存在する

注意: `.claude/plans/`, `.claude/skills/`, `.claude/rules/` は Cursor がネイティブで読み取るため、同期の対象外です。

## When to Use

- Claude Code用に `docs/` 配下に plans/skills/rules を配置したプロジェクトで、Cursorからも参照したい場合
- `.mcp.json` のMCPサーバー設定をCursorでも使いたい場合
- `/sync-claude-docs` コマンドで呼び出し

## Steps

### Step 1: 同期スクリプトの実行

以下のコマンドを実行してください:

```bash
~/.cursor/skills-cursor/sync-claude-docs/sync.sh
```

### Step 2: 初回セットアップ（設定ファイルがない場合）

初回実行時は対話モードで以下を確認します:

1. **ディレクトリの自動検出**
   - `docs/plans`, `docs/skills`, `docs/rules`
   - `.mcp.json`

2. **確認プロンプト**
   - 検出された設定で続行するか確認
   - 必要に応じて手動でパスを入力

3. **設定ファイルの保存**
   - `.cursor/claude-compat.json` に設定を保存
   - 次回以降は自動で読み込み

### Step 3: 同期処理

**plans/skills の同期（シンボリックリンク優先）**:

```bash
# シンボリックリンクが使える場合
ln -s ../docs/plans .cursor/plans
ln -s ../docs/skills .cursor/skills

# シンボリックリンクが使えない場合（フォールバック）
rsync -av --delete docs/plans/ .cursor/plans/
rsync -av --delete docs/skills/ .cursor/skills/
```

**rules の同期（形式変換）**:

Claude形式（純粋Markdown）から Cursor形式（frontmatter付き）に変換してコピーします。サブディレクトリも再帰的に処理されます。

入力（`docs/rules/japanese-response.md`）:
```markdown
# 日本語応答

すべての応答は日本語で行ってください。
```

出力（`.cursor/rules/japanese-response.md`）:
```markdown
---
description: 日本語応答
globs: ["**/*"]
alwaysApply: false
---

# 日本語応答

すべての応答は日本語で行ってください。
```

**MCP の同期（安全マージ）**:

`.mcp.json` の `mcpServers` を `.cursor/mcp.json` にマージします:
- 既存の Cursor 設定は保持（競合時は既存優先）
- Claude 固有フィールド（`type`, `envFile`, `oauth`, `disabledTools`）は自動除去
- jq が必要（インストールされていない場合はスキップ）

## オプション

```bash
# 既存ディレクトリを強制上書き
~/.cursor/skills-cursor/sync-claude-docs/sync.sh --force

# 実行内容のプレビュー（実際には実行しない）
~/.cursor/skills-cursor/sync-claude-docs/sync.sh --dry-run
```

## 設定ファイル

`.cursor/claude-compat.json`:

```json
{
  "version": "1",
  "source": {
    "plans": "docs/plans",
    "skills": "docs/skills",
    "rules": "docs/rules",
    "mcp": ".mcp.json"
  },
  "target": {
    "plans": ".cursor/plans",
    "skills": ".cursor/skills",
    "rules": ".cursor/rules",
    "mcp": ".cursor/mcp.json"
  },
  "syncMethod": {
    "plans": "symlink",
    "skills": "symlink",
    "rules": "convert",
    "mcp": "merge"
  }
}
```

## Troubleshooting

| 症状 | 原因 | 対処法 |
|------|------|--------|
| `ln: failed to create symbolic link` | 既存ファイル/ディレクトリがある | `--force` オプションで上書き |
| シンボリックリンクが機能しない | Windows環境 | 自動でコピー方式にフォールバック |
| Cursorが認識しない | 設定ファイルが壊れている | `.cursor/claude-compat.json` を削除して再実行 |
| ルールが反映されない | 形式変換エラー | `.cursor/rules/` の内容を確認 |
| MCP同期がスキップされる | jq未インストール | `sudo apt install jq` |

## Notes

- **マスターは docs/ 側**: 編集は `docs/` 配下で行い、同期で `.cursor/` に反映
- **Git管理**: `.cursor/` は `.gitignore` に含めることで、同期結果はコミットされない
- **定期同期**: Cursorの自動タスク機能でフォルダオープン時にチェック可能（オプション）
- **MCP の安全性**: 競合時は既存の Cursor 設定を優先（意図しない上書きを防止）

## Related

- グローバルルール: `~/.cursor/rules/cursor-claude-compat.md`
  - `.cursor/` への直接編集を禁止するルール
