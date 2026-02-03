---
description: Cursor-Claude互換運用ルール - ファイル配置の原則を強制
globs: ["**/*.md", ".cursor/**/*", "docs/**/*"]
alwaysApply: true
---

# Cursor-Claude互換運用ルール

このプロジェクトは Claude Code と Cursor の両方で運用されています。
ファイル配置の原則に従ってください。

## ファイル配置の原則

plans, skills, rules を新規作成・編集する場合:

### 1. 実体は `docs/` 配下に配置

- `docs/plans/` - 計画ファイル（*.plan.md）
- `docs/skills/` - スキルファイル（SKILL.md）
- `docs/rules/` - ルールファイル（*.md, 純粋Markdown形式）

### 2. `.cursor/` 配下は自動生成

- `.cursor/plans/` → `docs/plans/` へのシンボリックリンク
- `.cursor/skills/` → `docs/skills/` へのシンボリックリンク
- `.cursor/rules/` → `docs/rules/` から変換生成

**直接編集しないでください。**

### 3. 新規ファイル作成時の手順

1. `docs/` 配下にファイルを作成
2. `/sync-claude-docs` を実行してCursor側に反映

## 禁止事項

以下の操作は避けてください:

- `.cursor/plans/` に直接ファイルを作成
- `.cursor/skills/` に直接ファイルを作成
- `.cursor/rules/` を直接編集（変換で上書きされる）
- シンボリックリンクを手動で削除

## ルールファイルの形式

### Claude Code形式（docs/rules/*.md）

純粋なMarkdown形式で記述:

```markdown
# ルール名

ルールの内容
```

### Cursor形式（.cursor/rules/*.md）

YAML frontmatter + Markdown形式（自動変換）:

```markdown
---
description: ルール名
globs: ["**/*"]
alwaysApply: false
---

# ルール名

ルールの内容
```

## 同期の実行

```bash
# スキルから呼び出し
/sync-claude-docs

# または直接実行
~/.cursor/skills-cursor/sync-claude-docs/sync.sh
```

## 設定ファイル

プロジェクト設定: `.cursor/claude-compat.json`

この設定ファイルは初回同期時に自動生成されます。
