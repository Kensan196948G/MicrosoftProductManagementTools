# tmux Python移行プロジェクト環境

## 📁 ファイル構成

### 🚀 メインスクリプト
- **`python_tmux_launcher.sh`** - **統合ランチャー（推奨）**
  - セッション作成から安全な接続まで一括実行
  - ペインタイトル保護システム内蔵
  - 既存セッション管理機能付き

### 🛠 ユーティリティスクリプト
- **`fix_pane_titles.sh`** - 緊急ペインタイトル修正
  - タイトルが上書きされた場合の復旧用
  - 継続監視システム再起動
  
- **`enable_pane_titles_display.sh`** - ペインタイトル表示設定
  - tmux表示設定の強制有効化
  - ボーダー表示オプション設定

### 📂 サブディレクトリ

#### `/collaboration/`
- **`messaging_system_python.sh`** - Python移行プロジェクト専用メッセージングシステム
- **`messaging_system.sh`** - 汎用メッセージングシステム
- **`5pane_integration_guide.md`** - 5ペイン統合ガイド
- **`communication_flow_diagram.md`** - コミュニケーションフロー図
- **`tmux_config_summary.md`** - tmux設定サマリー

#### `/logs/`
- **`messages/`** - メッセージングシステムログ保存用

## 🎯 使用方法

### 基本的な使用（推奨）
```bash
# Python移行プロジェクト環境を起動
./tmux/python_tmux_launcher.sh
```

### トラブルシューティング
```bash
# ペインタイトルが表示されない場合
./tmux/fix_pane_titles.sh

# tmux表示設定を強制有効化
./tmux/enable_pane_titles_display.sh
```

### セッション操作
```bash
# セッション一覧確認
tmux list-sessions

# セッションに手動接続
tmux attach-session -t MicrosoftProductTools-Python

# セッション終了
tmux kill-session -t MicrosoftProductTools-Python
```

## 🏗 ペイン構成

```
┌─────────────────────────────────┬─────────────────────────────────┐
│  👔 Manager: Coordination       │  🐍 Dev0: Python GUI &         │
│     & Progress                  │     API Development             │
├─────────────────────────────────┼─────────────────────────────────┤
│  👑 CTO: Strategy &             │  🧪 Dev1: Testing &            │
│     Decision                    │     Quality Assurance           │
│                                 ├─────────────────────────────────┤
│                                 │  🔄 Dev2: PowerShell           │
│                                 │     Compatibility &             │
│                                 │     Infrastructure              │
└─────────────────────────────────┴─────────────────────────────────┘
```

## 🔧 技術仕様

- **tmux Version**: 3.4以上推奨
- **セッション名**: `MicrosoftProductTools-Python`
- **ペイン数**: 5ペイン構成
- **Claude統合**: 自動起動・日本語プロンプト送信
- **監視システム**: 3秒間隔でペインタイトル保護

## 📝 注意事項

1. **統合ランチャー使用を推奨** - 手動セットアップは非推奨
2. **Claude起動時間** - 環境により15-20秒の起動待機時間が必要
3. **ペインタイトル保護** - バックグラウンド監視システムが自動実行
4. **セッション重複** - 既存セッションは自動検出・選択肢提示

## 🆕 更新履歴

- **2025-01-18**: 統合ランチャー完成、ファイル整理実施
- **2025-01-18**: ペインタイトル表示問題完全解決
- **2025-01-18**: Python移行プロジェクト専用環境構築

---

**推奨コマンド**: `./tmux/python_tmux_launcher.sh`