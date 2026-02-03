# Claude グローバル設定を Cursor に同期

## Purpose

Claude Code のグローバル設定（`~/.claude/`）を Cursor のグローバル設定（`~/.cursor/`）に同期します。

## Preconditions

- Claude Code のグローバル設定が存在する
  - `~/.claude/CLAUDE.md` - グローバルルール/メモリ
  - `~/.claude/skills/` - グローバルスキル
  - `~/.claude.json` - MCP設定（mcpServers）

## When to Use

- Claude Code でグローバルな設定を編集した後、Cursor にも反映したい場合
- `/sync-claude-global` コマンドで呼び出し

## Steps

### Step 1: グローバル同期スクリプトの実行

以下のコマンドを実行してください:

```bash
~/.cursor/skills-cursor/sync-claude-docs/sync-global.sh
```

### Step 2: 初回セットアップ（設定ファイルがない場合）

初回実行時は対話モードで以下を確認します:

1. **設定の自動検出**
   - `~/.claude/CLAUDE.md`
   - `~/.claude/skills/`
   - `~/.claude.json`

2. **確認プロンプト**
   - 検出された設定で続行するか確認
   - 必要に応じて手動でパスを入力

3. **プレビュー表示**
   - 同期される内容を事前に確認

### Step 3: 同期処理

**CLAUDE.md → rules（形式変換）**:

入力（`~/.claude/CLAUDE.md`）:
```markdown
ユーザーがどんな言語で発話しても日本語で応答すること
```

出力（`~/.cursor/rules/claude-global.md`）:
```markdown
---
description: Claude グローバルルール（自動生成）
globs: ["**/*"]
alwaysApply: true
---

ユーザーがどんな言語で発話しても日本語で応答すること
```

**skills → シンボリックリンク**:

```bash
~/.cursor/skills-cursor/claude-skills -> ~/.claude/skills
```

**MCP設定 → 安全マージ**:

- Claude側の `mcpServers` を Cursor側にマージ
- 既存のCursor設定は保持（競合時は既存優先）
- jq がインストールされていない場合はスキップ

## オプション

```bash
# 対話モードで実行（デフォルト）
~/.cursor/skills-cursor/sync-claude-docs/sync-global.sh

# 非対話モード（CI向け）
~/.cursor/skills-cursor/sync-claude-docs/sync-global.sh --yes

# 既存ファイルをスキップ
~/.cursor/skills-cursor/sync-claude-docs/sync-global.sh --skip-existing

# 強制上書き（バックアップは作成）
~/.cursor/skills-cursor/sync-claude-docs/sync-global.sh --force

# プレビューのみ（実際には実行しない）
~/.cursor/skills-cursor/sync-claude-docs/sync-global.sh --dry-run
```

## 差分チェック

同期状態を確認するには:

```bash
~/.cursor/skills-cursor/sync-claude-docs/check-global.sh
```

出力例:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Cursor-Claude Compat - グローバル差分チェック
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[rules]
  ✓ claude-global.md: 同期済み

[skills]
  ✓ claude-skills: 同期済み（リンク正常）

[mcp]
  ✓ mcpServers.github: 同期済み
  ⚠ mcpServers.notion: Claude側にあり、Cursor側にない

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠ 差分のある項目があります: 1 件

同期を実行するには: sync-global.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 設定ファイル

`~/.cursor/claude-compat-global.json`:

```json
{
  "version": "1",
  "source": {
    "claudeMd": "/home/user/.claude/CLAUDE.md",
    "skills": "/home/user/.claude/skills",
    "mcpConfig": "/home/user/.claude.json"
  },
  "target": {
    "rules": "/home/user/.cursor/rules/claude-global.md",
    "skills": "/home/user/.cursor/skills-cursor/claude-skills",
    "mcp": "/home/user/.cursor/mcp.json"
  },
  "lastSync": "2026-02-03T12:00:00+09:00",
  "lastSyncStatus": "success"
}
```

## Troubleshooting

| 症状 | 原因 | 対処法 |
|------|------|--------|
| `jq が見つかりません` | jq未インストール | `sudo apt install jq` または `brew install jq` |
| MCP設定がスキップされる | jq がない、または mcpServers がない | jq をインストール、または Claude側で MCP設定を確認 |
| シンボリックリンク失敗 | Windows/WSL環境 | 自動でコピー方式にフォールバック |
| 競合で上書きされない | 既存優先ポリシー | `--force` オプションで強制上書き |

## Notes

- **マスターは Claude 側**: 編集は `~/.claude/` で行い、同期で `~/.cursor/` に反映
- **バックアップ自動作成**: `~/.cursor/.claude-compat-backup/` に保存（最新5件を保持）
- **MCP の安全性**: 競合時は既存の Cursor 設定を優先（意図しない上書きを防止）
- **ロールバック可能**: バックアップから手動で復元可能

## Related

- プロジェクト単位の同期: `/sync-claude-docs` スキル
- グローバルルール: `~/.cursor/rules/claude-global.md`
