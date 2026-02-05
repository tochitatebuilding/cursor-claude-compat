# Configuration

設定ファイルとオプションの詳細リファレンスです。

> **Note**: Cursor は `~/.claude/CLAUDE.md`、`~/.claude/agents/`、`~/.claude/skills/`、`~/.claude/settings.json` をネイティブに読み込むようになりました。これらはグローバル同期の対象外です。グローバル同期は MCP 設定（`~/.claude.json` → `~/.cursor/mcp.json`）のみを処理します。

## 設定ファイル

### プロジェクト設定: `.cursor/claude-compat.json`

初回同期時に自動生成されます。

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
  },
  "lastSync": "2026-02-03T12:00:00+09:00",
  "lastSyncStatus": "success"
}
```

### フィールド説明

| フィールド | 説明 |
|-----------|------|
| `version` | 設定ファイルのバージョン |
| `source.*` | Claude Code用のソースディレクトリ |
| `target.*` | Cursor用の同期先ディレクトリ |
| `syncMethod.*` | 同期方式（`symlink`, `copy`, `convert`, `merge`） |
| `lastSync` | 最終同期日時（ISO 8601形式） |
| `lastSyncStatus` | 最終同期のステータス（`success`, `failed`） |

### 同期方式

| 方式 | 説明 | 用途 |
|------|------|------|
| `symlink` | シンボリックリンクを作成 | plans, skills（デフォルト） |
| `copy` | ファイルをコピー | symlinkが使えない環境 |
| `convert` | 形式変換してコピー | rules（プロジェクト同期で使用） |

## コマンドラインオプション

### sync.sh

```bash
~/.cursor/skills-cursor/sync-claude-docs/sync.sh [OPTIONS]
```

| オプション | 説明 |
|-----------|------|
| `--force`, `-f` | 既存ディレクトリを強制上書き |
| `--dry-run`, `-n` | 実行内容をプレビュー（実際には実行しない） |
| `--help`, `-h` | ヘルプを表示 |

### 使用例

```bash
# 通常の同期
~/.cursor/skills-cursor/sync-claude-docs/sync.sh

# 強制上書き
~/.cursor/skills-cursor/sync-claude-docs/sync.sh --force

# プレビュー
~/.cursor/skills-cursor/sync-claude-docs/sync.sh --dry-run
```

## ルール変換の詳細

### frontmatter の自動生成

Claude形式（純粋Markdown）から Cursor形式（.mdc）への変換時に、frontmatterを自動生成します。

#### description

最初の `#` 見出しから抽出:

```markdown
# 日本語で応答
→ description: 日本語で応答
```

#### globs

ファイル名から推測:

| ファイル名パターン | 生成される globs |
|-------------------|-----------------|
| `*typescript*`, `*ts*` | `["**/*.ts", "**/*.tsx"]` |
| `*javascript*`, `*js*` | `["**/*.js", "**/*.jsx"]` |
| `*python*`, `*py*` | `["**/*.py"]` |
| `*astro*` | `["**/*.astro"]` |
| `*react*` | `["**/*.tsx", "**/*.jsx"]` |
| `*css*`, `*style*` | `["**/*.css", "**/*.scss"]` |
| その他 | `["**/*"]` |

#### alwaysApply

デフォルトは `false`。変更が必要な場合は、変換後のファイルを手動で編集してください。

### ルールのサブディレクトリ対応

ルール同期はネストされたサブディレクトリを再帰的に処理します。ソースディレクトリ内のディレクトリ構造がそのまま同期先に反映されます。

## MCP設定の同期

### グローバル同期

`~/.claude.json` → `~/.cursor/mcp.json` へ MCP サーバー設定をマージします。

### プロジェクト同期

`.mcp.json` → `.cursor/mcp.json` へ MCP サーバー設定をマージします（設定ファイルの `mcp` フィールドで制御）。

### Claude固有フィールドの自動除去

MCP設定の同期時、以下の Claude 固有フィールドは Cursor と互換性がないため自動的に除去されます:

| フィールド | 説明 |
|-----------|------|
| `type` | サーバータイプの指定（Claude固有） |
| `envFile` | 環境変数ファイルの指定 |
| `oauth` | OAuth認証設定 |
| `disabledTools` | 無効化ツールの指定 |

### 空の mcpServers の扱い

ソースの `mcpServers` が空オブジェクト（`{}`）の場合、既存の Cursor 側の MCP 設定はそのまま保持されます。

### アトミック書き込み

MCP設定ファイルの更新は、一時ファイルへの書き込み → JSON バリデーション → 移動（mv）の順で行われ、書き込み途中の不正な状態を防ぎます。

## VSCodeタスク

### 自動チェックタスク

`templates/.vscode/tasks.json` の `Check Claude Docs Sync` タスク:

- **実行タイミング**: フォルダオープン時（`runOn: folderOpen`）
- **条件**: Cursorで実行している場合のみ
- **動作**: 同期状態をチェックし、問題があれば警告

### 自動タスクの有効化

`.vscode/settings.json`:

```json
{
  "task.allowAutomaticTasks": "on"
}
```

### Cursor検出条件

タスク内で以下の条件でCursorかどうかを判定:

```bash
[[ -n "$CURSOR_AGENT" ]] || \
[[ "$VSCODE_CWD" == *cursor* ]] || \
[[ "$PATH" == *.cursor-server* ]]
```

VSCodeで開いた場合はタスクがスキップされます。

## 環境変数

| 変数 | 説明 |
|------|------|
| `CURSOR_AGENT` | Cursorエージェントが設定 |
| `VSCODE_CWD` | VSCode/Cursorの起動ディレクトリ |

## カスタマイズ

### 異なるソースディレクトリを使用

設定ファイルを手動で編集:

```json
{
  "source": {
    "plans": ".claude/plans",
    "skills": ".claude/skills",
    "rules": ".claude/rules"
  }
}
```

### 一部のディレクトリのみ同期

不要なディレクトリは空文字列に設定:

```json
{
  "source": {
    "plans": "docs/plans",
    "skills": "",
    "rules": ""
  }
}
```
