# Troubleshooting

よくある問題と解決策をまとめています。

## インストール関連

### スキルが見つからない

**症状**: `/sync-claude-docs` を実行してもスキルが認識されない

**原因**: インストールが完了していない、またはCursorがスキルを読み込んでいない

**解決策**:
1. インストールを再実行:
   ```bash
   ./installer/install.sh
   ```
2. Cursorを再起動
3. スキルディレクトリを確認:
   ```bash
   ls -la ~/.cursor/skills-cursor/sync-claude-docs/
   ```

### Permission denied

**症状**: インストール時に権限エラー

**解決策**:
```bash
chmod +x installer/install.sh
./installer/install.sh
```

## 同期関連

### シンボリックリンクの作成に失敗

**症状**: `ln: failed to create symbolic link`

**原因**: 
- 既存のファイル/ディレクトリがある
- Windows環境でシンボリックリンクが使えない

**解決策**:
1. `--force` オプションで上書き:
   ```bash
   ~/.cursor/skills-cursor/sync-claude-docs/sync.sh --force
   ```
2. Windows環境では自動でコピー方式にフォールバックされます

### 設定ファイルが壊れている

**症状**: JSONパースエラー、設定が読み込めない

**解決策**:
1. 設定ファイルを削除:
   ```bash
   rm .cursor/claude-compat.json
   ```
2. 再度同期を実行（対話モードで再設定）

### 同期元ディレクトリが見つからない

**症状**: 設定ファイルの参照先が無効

**解決策**:
1. 設定ファイルを削除して再セットアップ
2. または設定ファイルを手動で編集:
   ```json
   {
     "source": {
       "plans": "正しいパス"
     }
   }
   ```

## ルール変換関連

### ルールが反映されない

**症状**: `.cursor/rules/` に変換後のファイルがあるが、Cursorで認識されない

**原因**: 
- frontmatterの形式が不正
- ファイル名の問題

**解決策**:
1. 変換後のファイルを確認:
   ```bash
   cat .cursor/rules/your-rule.md
   ```
2. frontmatterが正しい形式か確認:
   ```yaml
   ---
   description: ルール名
   globs: ["**/*"]
   alwaysApply: false
   ---
   ```
3. Cursorを再起動

### 日本語が文字化けする

**症状**: ルール変換後に日本語が正しく表示されない

**原因**: ファイルのエンコーディングの問題

**解決策**:
1. ソースファイルがUTF-8で保存されているか確認
2. ターミナルのエンコーディングを確認:
   ```bash
   echo $LANG
   ```

## VSCodeタスク関連

### 自動タスクが実行されない

**症状**: フォルダを開いてもチェックタスクが実行されない

**原因**: 
- 自動タスクが許可されていない
- VSCodeで開いている（Cursorでない）

**解決策**:
1. `.vscode/settings.json` を確認:
   ```json
   {
     "task.allowAutomaticTasks": "on"
   }
   ```
2. Cursorで開いているか確認

### VSCodeでタスクが実行されてしまう

**症状**: VSCodeで開いた時も同期チェックが実行される

**原因**: Cursor検出条件が機能していない

**解決策**:
- タスクテンプレートを更新して、Cursor検出条件を確認:
  ```bash
  if [[ -n "$CURSOR_AGENT" ]] || [[ "$VSCODE_CWD" == *cursor* ]] || [[ "$PATH" == *.cursor-server* ]]; then
    # Cursorの場合のみ実行
  fi
  ```

## MCP設定関連

### Claude固有フィールドが原因でCursorのMCPサーバーが動作しない

**症状**: MCP同期後、Cursorで MCP サーバーに接続できない

**原因**: Claude 固有のフィールド（`type`, `envFile`, `oauth`, `disabledTools`）が残っている可能性

**解決策**:
1. 同期を再実行すると、これらのフィールドは自動的に除去されます:
   ```bash
   ~/.cursor/skills-cursor/sync-claude-docs/sync-global.sh
   ```
2. 手動で確認する場合:
   ```bash
   cat ~/.cursor/mcp.json | jq '.mcpServers | to_entries[] | select(.value.type != null or .value.envFile != null)'
   ```
   上記コマンドで出力がなければ、Claude固有フィールドは除去済みです。

### 空の mcpServers で既存設定が消える

**症状**: ソース側の `mcpServers` が空だったのに、Cursor 側の既存MCP設定が消えた

**原因**: 通常は発生しません。`mcpServers: {}` の場合、既存の Cursor 設定は保持されます。

**解決策**:
1. バックアップから復元:
   ```bash
   ls ~/.cursor/.claude-compat-backup/
   cp ~/.cursor/.claude-compat-backup/mcp.json.YYYYMMDD_HHMMSS ~/.cursor/mcp.json
   ```
2. 再同期を実行

### MCP設定のマージに失敗する

**症状**: MCP同期時にJSONパースエラーが発生する

**原因**: ソースまたはターゲットのJSONファイルが不正な形式

**解決策**:
1. ソースファイルのJSON形式を確認:
   ```bash
   # グローバル
   jq . ~/.claude.json
   # プロジェクト
   jq . .mcp.json
   ```
2. ターゲットファイルの形式を確認:
   ```bash
   jq . ~/.cursor/mcp.json
   ```
3. ファイルが不正な場合、修正するか削除して再同期:
   ```bash
   rm ~/.cursor/mcp.json
   ~/.cursor/skills-cursor/sync-claude-docs/sync-global.sh
   ```

> **Note**: MCP設定の書き込みはアトミック（一時ファイル → バリデーション → 移動）で行われるため、書き込み途中の破損は通常発生しません。

## その他

### jqがインストールされていない

**症状**: 設定ファイルの読み込みが遅い、または一部機能が動作しない

**解決策**:
```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq

# Windows (WSL)
sudo apt install jq
```

jqがなくても動作しますが、あると設定ファイルの処理が高速になります。

### rsyncがインストールされていない

**症状**: コピー方式でエラーが発生

**解決策**:
```bash
# Ubuntu/Debian
sudo apt install rsync

# macOS
brew install rsync
```

rsyncがない場合は `cp -r` にフォールバックします。

## ログの確認

### 詳細なログを出力

```bash
bash -x ~/.cursor/skills-cursor/sync-claude-docs/sync.sh
```

### ドライランで動作確認

```bash
~/.cursor/skills-cursor/sync-claude-docs/sync.sh --dry-run
```

## 問題が解決しない場合

1. 設定をリセット:
   ```bash
   rm -rf .cursor/claude-compat.json
   rm -rf .cursor/plans .cursor/skills .cursor/rules
   ```

2. 再インストール:
   ```bash
   ./installer/uninstall.sh
   ./installer/install.sh
   ```

3. 再同期:
   ```bash
   ~/.cursor/skills-cursor/sync-claude-docs/sync.sh
   ```
