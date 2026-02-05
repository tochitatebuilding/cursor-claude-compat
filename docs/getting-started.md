# Getting Started

Cursor-Claude Compat のセットアップと基本的な使い方を説明します。

## 前提条件

- Cursor がインストールされていること
- bash 4.0 以上
- （推奨）jq コマンド - MCP設定の同期に必要
- （推奨）rsync コマンド - コピー方式での同期時に使用

## インストール

### 1. リポジトリのクローン

```bash
git clone https://github.com/your-org/cursor-claude-compat.git
cd cursor-claude-compat
```

### 2. インストールスクリプトの実行

```bash
./installer/install.sh
```

これにより以下がインストールされます:

- グローバルスキル: `~/.cursor/skills-cursor/sync-claude-docs/`
  - `SKILL.md` - プロジェクト同期スキル
  - `SKILL-global.md` - グローバル同期スキル
  - `sync.sh`, `check.sh` - プロジェクト同期スクリプト
  - `sync-global.sh`, `check-global.sh` - グローバル同期スクリプト
  - `lib/common.sh` - 共通ライブラリ
- グローバルルール: `~/.cursor/rules/cursor-claude-compat.md`

## 使用方法

### プロジェクト単位の同期

Claude Code 用の `docs/` ディレクトリを `.cursor/` に同期します。

#### 方法1: スキルから実行（推奨）

1. Cursorで対象プロジェクトを開く
2. チャットまたはコマンドパレットで `/sync-claude-docs` と入力
3. AIがスキルの手順に従って同期を実行

#### 方法2: シェルスクリプトを直接実行

```bash
# プロジェクトディレクトリで実行
~/.cursor/skills-cursor/sync-claude-docs/sync.sh
```

### グローバル設定の同期

Claude Code の MCP 設定（`~/.claude.json`）を Cursor の MCP 設定（`~/.cursor/mcp.json`）に同期します。

> **Note**: Cursor は `~/.claude/CLAUDE.md`、`~/.claude/agents/`、`~/.claude/skills/`、`~/.claude/settings.json` をネイティブに読み込むようになったため、グローバル同期は MCP 設定のみを対象とします。

#### 方法1: スキルから実行（推奨）

1. Cursorでチャットを開く
2. `/sync-claude-global` と入力
3. AIがスキルの手順に従って同期を実行

#### 方法2: シェルスクリプトを直接実行

```bash
~/.cursor/skills-cursor/sync-claude-docs/sync-global.sh
```

## 初回セットアップの流れ

### プロジェクト同期の場合

初めて同期を実行すると、対話モードでセットアップが行われます。

> **Note**: `.claude/` ディレクトリは Cursor がネイティブに読み込むため、同期ソースの候補には含まれません。

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Cursor-Claude Compat - 同期ツール
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ 設定ファイルが見つかりません。対話モードでセットアップします。

ℹ Claude Code ドキュメントディレクトリを検出中...

以下のディレクトリが見つかりました:
  - docs/plans
  - docs/skills
  - docs/rules

MCP設定ファイルを検出:
  - .mcp.json

検出された設定:
  plans:  docs/plans
  skills: docs/skills
  rules:  docs/rules
  mcp:    .mcp.json → .cursor/mcp.json

この設定で続行しますか? [Y/n]:
```

### グローバル同期の場合

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Cursor-Claude Compat - グローバル同期ツール
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Claude グローバル設定を検出中...

✓ MCP設定を検出: /home/user/.claude.json
ℹ CLAUDE.md, skills, agents はCursorがネイティブに読み込みます（同期不要）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 変更内容のプレビュー
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[mcp]
  + mcpServers.github: 新規追加
  + mcpServers.notion: 新規追加
  - mcpServers.github.type: 除去（Claude固有フィールド）

続行しますか? [Y/n]:
```

## 競合時の対処

既存ファイルがある場合、以下の選択肢が表示されます:

```
⚠ 既存ファイルがあります: ~/.cursor/mcp.json
  [B]ackup & overwrite - バックアップ後上書き
  [S]kip              - スキップ（既存を維持）
  [A]ll backup        - 以降すべてバックアップ後上書き
  [N]one              - 以降すべてスキップ

  選択 [B/S/A/N]:
```

## ディレクトリ構成例

### プロジェクト同期後

```
your-project/
├── docs/                      # マスター（Git管理）
│   ├── plans/
│   │   └── feature-x.plan.md
│   ├── skills/
│   │   └── deployment/SKILL.md
│   └── rules/
│       └── coding-style.md    # 純粋Markdown
│
├── .mcp.json                  # MCP設定（Claude Code用）
│
├── .cursor/                   # 同期先（.gitignore）
│   ├── plans -> ../docs/plans  # シンボリックリンク
│   ├── skills -> ../docs/skills
│   ├── rules/
│   │   └── coding-style.md    # 変換後（frontmatter付き）
│   ├── mcp.json               # MCP設定（マージ済み）
│   └── claude-compat.json     # 設定ファイル
│
└── .gitignore                 # .cursor/ を除外
```

### グローバル同期後

```
~/.claude/                     # マスター（Claude Code）
├── CLAUDE.md                  # Cursorがネイティブに読み込み
├── agents/                    # Cursorがネイティブに読み込み
├── skills/                    # Cursorがネイティブに読み込み
├── settings.json              # Cursorがネイティブに読み込み
└── ...

~/.claude.json                 # MCP設定（Claude Code）

~/.cursor/                     # 同期先（Cursor）
├── mcp.json                   # MCP設定（マージ済み）
├── claude-compat-global.json  # グローバル同期設定
└── .claude-compat-backup/     # バックアップ
```

## 差分チェック

同期状態を確認するには:

```bash
# プロジェクト同期の状態
~/.cursor/skills-cursor/sync-claude-docs/check.sh

# グローバル同期の状態
~/.cursor/skills-cursor/sync-claude-docs/check-global.sh
```

## 次のステップ

- [設定リファレンス](./configuration.md) - 詳細な設定オプション
- [トラブルシューティング](./troubleshooting.md) - よくある問題と解決策
