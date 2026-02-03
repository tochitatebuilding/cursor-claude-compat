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

Claude Code のグローバル設定（`~/.claude/`）を Cursor のグローバル設定（`~/.cursor/`）に同期します。

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

初めて同期を実行すると、対話モードでセットアップが行われます:

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

検出された設定:
  plans:  docs/plans
  skills: docs/skills
  rules:  docs/rules

この設定で続行しますか? [Y/n]: 
```

### グローバル同期の場合

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Cursor-Claude Compat - グローバル同期ツール
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Claude グローバル設定を検出中...

✓ CLAUDE.md を検出: /home/user/.claude/CLAUDE.md
✓ skills ディレクトリを検出: /home/user/.claude/skills
✓ MCP設定を検出: /home/user/.claude.json

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 変更内容のプレビュー
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[rules]
  + claude-global.md: 新規作成

[skills]
  + claude-skills: シンボリックリンク作成

[mcp]
  + mcpServers.github: 新規追加
  + mcpServers.notion: 新規追加

続行しますか? [Y/n]: 
```

## 競合時の対処

既存ファイルがある場合、以下の選択肢が表示されます:

```
⚠ 既存ファイルがあります: ~/.cursor/rules/claude-global.md
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
├── .cursor/                   # 同期先（.gitignore）
│   ├── plans -> ../docs/plans  # シンボリックリンク
│   ├── skills -> ../docs/skills
│   ├── rules/
│   │   └── coding-style.md    # 変換後（frontmatter付き）
│   └── claude-compat.json     # 設定ファイル
│
└── .gitignore                 # .cursor/ を除外
```

### グローバル同期後

```
~/.claude/                     # マスター（Claude Code）
├── CLAUDE.md
├── skills/
│   └── my-skill/
│       └── SKILL.md
└── ...

~/.claude.json                 # MCP設定（Claude Code）

~/.cursor/                     # 同期先（Cursor）
├── rules/
│   └── claude-global.md       # CLAUDE.md から変換
├── skills-cursor/
│   └── claude-skills -> ~/.claude/skills  # シンボリックリンク
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
