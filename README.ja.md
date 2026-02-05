<div align="center">

![Tochitatebuilding Logo](.github/assets/logo-black.svg)

# Cursor-Claude Compat

**Claude CodeとCursorの両方でプロジェクトを効率的に管理するためのツールキット**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/tochitatebuilding/cursor-claude-compat/actions/workflows/ci.yml/badge.svg)](https://github.com/tochitatebuilding/cursor-claude-compat/actions/workflows/ci.yml)
[![Contributors](https://img.shields.io/github/contributors/tochitatebuilding/cursor-claude-compat)](https://github.com/tochitatebuilding/cursor-claude-compat/graphs/contributors)

</div>

## 概要

Cursor-Claude Compatは、Claude CodeとCursorの間でプロジェクト設定、スキル、ルール、プラン、MCP設定をシームレスに同期するためのツールキットです。複数のAIコーディングアシスタントを使用する際に、開発者が一貫性を保つことを支援します。

## なぜOSS化するのか？

トチタテビルディングは、倉庫・工場専門の不動産会社として、AIを活用してビジネス運営を変革することに取り組んでいます。このプロジェクトをオープンソース化することで、以下のことを目指しています：

- **学習の共有**: 複数のAIコーディングアシスタントを使用する開発者コミュニティと学びを共有する
- **コラボレーションの促進**: フィードバックを受け取り、ツールを改善する
- **透明性の実証**: AI導入の取り組みにおける透明性を示す
- **オープンソースエコシステムへの貢献**: 私たちの成長を可能にしてくれたオープンソースエコシステムに貢献する

オープンなコラボレーションがイノベーションを加速すると信じており、特に急速に進化するAI支援開発の分野においてそれが重要だと考えています。

## 機能

### プロジェクト単位の同期

- `docs/plans/`と`docs/skills/`を`.cursor/`ディレクトリに自動同期
- `docs/rules/`をCursor形式（frontmatter付き）に変換
- 初回実行時の対話式セットアップ
- シンボリックリンクを優先し、フォールバックでコピー

### グローバル設定の同期

- `~/.claude.json`の`mcpServers` → `~/.cursor/mcp.json`（安全マージ、Claude固有フィールドの除去）

> **注意**: Cursorは `~/.claude/CLAUDE.md`、`~/.claude/agents/`、`~/.claude/skills/`、`~/.claude/settings.json` フックをネイティブに読み取ります -- これらの同期は不要です。

## クイックスタート

### インストール

```bash
# リポジトリをクローン
git clone https://github.com/tochitatebuilding/cursor-claude-compat.git
cd cursor-claude-compat

# グローバルスキル・ルールをインストール
./installer/install.sh
```

### 使用方法

#### プロジェクト単位の同期

Cursorでプロジェクトを開き、以下のいずれかの方法で同期を実行：

1. **スキル呼び出し**: `/sync-claude-docs`と入力
2. **コマンド実行**: `~/.cursor/skills-cursor/sync-claude-docs/sync.sh`

初回実行時は、ソースディレクトリの確認を求められ、`.cursor/claude-compat.json`に保存されます。

#### グローバル設定の同期

Claude Codeのグローバル設定をCursorに同期：

1. **スキル呼び出し**: `/sync-claude-global`と入力
2. **コマンド実行**: `~/.cursor/skills-cursor/sync-claude-docs/sync-global.sh`

## 同期方式

### プロジェクト同期

| 対象 | Claude形式 | Cursor形式 | 同期方法 |
|------|------------|------------|----------|
| plans | `docs/plans/*.md` | `.cursor/plans/*.md` | シンボリックリンク or コピー |
| skills | `docs/skills/*.md` | `.cursor/skills/*.md` | シンボリックリンク or コピー |
| rules | `docs/rules/*.md` | `.cursor/rules/*.md` | 形式変換コピー |
| mcp | `.mcp.json` | `.cursor/mcp.json` | 安全マージ |

### グローバル同期

| 対象 | Claude形式 | Cursor形式 | 同期方法 |
|------|------------|------------|----------|
| mcp | `~/.claude.json`の`mcpServers` | `~/.cursor/mcp.json` | 安全マージ（既存が優先、Claude固有フィールド除去） |

> **注意**: Cursorは `~/.claude/CLAUDE.md`、`~/.claude/agents/`、`~/.claude/skills/`、`~/.claude/settings.json` をネイティブにサポートしています。これらの同期は不要になりました。
>
> Claude固有フィールド（`type`、`envFile`、`oauth`、`disabledTools`）はMCP設定マージ時に自動的に除去されます。

## コマンドラインオプション

```bash
# プロジェクト同期
sync.sh [OPTIONS]

# グローバル同期
sync-global.sh [OPTIONS]

OPTIONS:
  --yes, -y           非対話モード（デフォルト: バックアップ後上書き）
  --skip-existing     既存ファイルはスキップ
  --force, -f         既存ファイルを確認なしで上書き（バックアップは作成）
  --dry-run, -n       実際には実行せず、何が行われるか表示
  --no-backup         バックアップを作成しない（非推奨）
  --help, -h          ヘルプ表示
```

## ディレクトリ構成

```
cursor-claude-compat/
├── src/
│   ├── skill/
│   │   ├── SKILL.md              # プロジェクト同期スキル
│   │   └── SKILL-global.md       # グローバル同期スキル
│   ├── rule/
│   │   └── cursor-claude-compat.md
│   └── scripts/
│       ├── lib/
│       │   └── common.sh         # 共通ライブラリ
│       ├── sync.sh               # プロジェクト同期
│       ├── check.sh              # プロジェクト差分チェック
│       ├── sync-global.sh        # グローバル同期
│       └── check-global.sh       # グローバル差分チェック
├── installer/
│   ├── install.sh
│   └── uninstall.sh
├── templates/
└── docs/
```

## 設定ファイル

### プロジェクト設定

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
  },
  "lastSync": "2026-02-03T12:00:00+09:00",
  "lastSyncStatus": "success"
}
```

### グローバル設定

`~/.cursor/claude-compat-global.json`:

```json
{
  "version": "1",
  "source": {
    "mcpConfig": "/home/user/.claude.json"
  },
  "target": {
    "mcp": "/home/user/.cursor/mcp.json"
  },
  "lastSync": "2026-02-03T12:00:00+09:00",
  "lastSyncStatus": "success"
}
```

## 依存関係

**必須**:
- bash 4.0+
- coreutils (ln, mkdir, realpath)

**推奨**:
- jq (MCP設定のマージに必須。利用できない場合はMCP同期はスキップされます)
- rsync (フォールバックコピー操作用)

## バックアップと復元

- バックアップは`~/.cursor/.claude-compat-backup/`に自動保存されます
- 最新5件を保持（古いものは自動削除）
- 同期が失敗した場合は、バックアップから手動で復元可能です

## AI利用の透明性

**重要**: このプロジェクトは、特定の自動化タスクにAI支援を使用しています：

- **Issue返信**: 一部のIssue返信はAIによって生成または支援される場合があります
- **プルリクエスト生成**: 自動化されたPR（有効化されている場合）はAI支援で作成される場合があります
- **ドキュメント**: ドキュメントはAI支援で強化される場合があります

すべてのAI生成コンテンツは、マージ前にメンテナーによってレビューされます。オープンソースプロジェクトにおけるAI利用の透明性を重視しています。

## コントリビューション

コントリビューションを歓迎します！このプロジェクトへの貢献方法については、[CONTRIBUTING.md](CONTRIBUTING.md)をご覧ください。

## セキュリティ

セキュリティの脆弱性を発見した場合は、[セキュリティポリシー](SECURITY.md)に従って報告してください。

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細については[LICENSE](LICENSE)ファイルを参照してください。

**注意**: コードはMITライセンスの下にありますが、トチタテビルディングのロゴと商標はこのライセンスから除外されています。詳細については[TRADEMARK.md](TRADEMARK.md)を参照してください。

## サポート

サポートに関する質問については、[SUPPORT.md](SUPPORT.md)をご覧ください。

## トチタテビルディングについて

トチタテビルディングは、倉庫・工場専門の不動産会社です。AIを活用してビジネス運営を変革し、オープンソースコミュニティに貢献することに取り組んでいます。

- **ウェブサイト**: [https://tochitatebuilding.co.jp/](https://tochitatebuilding.co.jp/)
- **GitHub**: [@tochitatebuilding](https://github.com/tochitatebuilding)

---

<div align="center">

Made with ❤️ by [Tochitatebuilding](https://tochitatebuilding.co.jp/)

</div>
