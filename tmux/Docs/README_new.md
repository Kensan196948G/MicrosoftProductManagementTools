# Microsoft Product Management Tools - tmux開発環境

tmuxsampleを参考にした完全新規実装による高度なチーム開発環境システムです。

## 🚀 概要

PowerShellからPythonへの移行プロジェクトを効率的に管理するための、階層的チーム構成による並列開発システムです。

### 主要機能

- ✅ **5人/8人構成対応**: Manager+CTO+開発者3人 または Manager+CEO+開発者6人
- ✅ **ペインタイトル維持**: Claude起動後も役職+アイコンが維持される
- ✅ **ゼロプロンプト干渉**: メッセージがClaudeプロンプトに残らない
- ✅ **自動Claude起動**: 各ペインで段階的にClaude起動
- ✅ **階層メッセージング**: 役職間の効率的なコミュニケーション
- ✅ **クイック接続**: 既存セッションへの高速アクセス

## 📁 ファイル構成

```
tmux/
├── python_project_launcher.sh    # メインランチャー（新規実装）
├── team_messaging.sh             # チームメッセージングシステム
├── quick_connect.sh               # クイック接続・状況確認
├── README_new.md                  # このファイル
└── logs/                          # ログディレクトリ
    ├── launcher_*.log
    ├── messaging_*.log
    └── claude_auth.log
```

## 🛠️ 使用方法

### 1. メインランチャー起動

```bash
cd /mnt/e/MicrosoftProductManagementTools/tmux
./python_project_launcher.sh
```

### 2. チーム構成選択

```
👥 開発チーム構成:
1) 5人構成 - 標準開発 (Manager + CTO + Dev0-2) 🌟推奨
2) 8人構成 - 大規模開発 (Manager + CEO + Dev0-5)

⚡ 高速セットアップ:
4) 標準5人構成で即座起動 (推奨設定)
```

### 3. セッション接続

```bash
# クイック状況確認
./quick_connect.sh

# 即座接続
./quick_connect.sh -c

# 全セッション終了
./quick_connect.sh -k
```

## 👥 チーム構成詳細

### 5人構成（推奨）
```
┌─────────────┬─────────────────────────────────┐
│ 👔 Manager  │ 💻 Dev0: Frontend/UI            │
│ Coordination│ ⚙️ Dev1: Backend/API             │
├─────────────┤ 🔒 Dev2: QA/Test                │
│ 💼 CTO      │                                 │
│ Technical   │                                 │
└─────────────┴─────────────────────────────────┘
```

### 8人構成（大規模）
```
┌─────────────┬─────────────────────────────────┐
│ 👔 Manager  │ 💻 Dev0: Frontend/UI            │
│ Coordination│ ⚙️ Dev1: Backend/API             │
├─────────────┤ 🔒 Dev2: QA/Test                │
│ 👑 CEO      │ 🧪 Dev3: DevOps/Infrastructure  │
│ Strategic   │ 🚀 Dev4: Database/Architecture  │
│             │ 📊 Dev5: Data/Analytics         │
└─────────────┴─────────────────────────────────┘
```

## 📨 メッセージングシステム

### 対話モード

```bash
./team_messaging.sh
```

### コマンドラインモード

```bash
# 自動検出でManagerに送信
./team_messaging.sh auto Manager "プロジェクト進捗を報告します"

# 全Developerに一斉送信
./team_messaging.sh auto 全Developer "コードレビューを開始します"

# 特定の開発者に送信
./team_messaging.sh auto Dev0 "UI実装をお願いします"
```

### メッセージング特徴

- ✅ **プロンプト非干渉**: display-messageのみ使用
- ✅ **アイコン表示**: 送受信確認アイコン付き
- ✅ **自動識別**: 現在のペイン役職を自動検出
- ✅ **一斉送信**: 全Developerへの同時メッセージ
- ✅ **ログ記録**: 全メッセージの詳細ログ

## 🎯 役職・専門分野

| 役職 | アイコン | 専門分野 | 責任範囲 |
|------|----------|----------|----------|
| Manager | 👔 | プロジェクト管理 | 進捗調整・リソース配分 |
| CTO | 💼 | 技術的意思決定 | アーキテクチャ・技術選択 |
| CEO | 👑 | 戦略的リーダーシップ | 事業戦略・意思決定 |
| Dev0 | 💻 | Frontend/UI | ユーザーインターフェース |
| Dev1 | ⚙️ | Backend/API | サーバーサイド・API |
| Dev2 | 🔒 | QA/Test | 品質管理・テスト |
| Dev3 | 🧪 | DevOps/Infrastructure | インフラ・CI/CD |
| Dev4 | 🚀 | Database/Architecture | データ設計・アーキテクチャ |
| Dev5 | 📊 | Data/Analytics | データ分析・可視化 |

## 🔧 技術仕様

### Claude起動
- **自動認証**: `--dangerously-skip-permissions`フラグ使用
- **段階起動**: 各ペイン3-5秒間隔で起動
- **モデル選択**: Manager/CEO/CTOはOpus、DeveloperはSonnet（予定）

### ペインタイトル
- **維持システム**: バックグラウンドプロセスで30回×3秒間隔で再設定
- **表示形式**: `#{pane_title}`を使用
- **自動命名無効**: `automatic-rename off`

### セッション命名
- **プレフィックス**: `MicrosoftProductTools-Python`
- **5人構成**: `MicrosoftProductTools-Python-5team`
- **8人構成**: `MicrosoftProductTools-Python-8team`

## 🚨 トラブルシューティング

### セッションが見つからない
```bash
# セッション状況確認
./quick_connect.sh

# 新規作成
./python_project_launcher.sh
```

### ペインタイトルが消える
```bash
# セッション再接続
tmux detach-client
./quick_connect.sh -c
```

### Claude起動エラー
```bash
# 認証状況確認
claude --version

# 手動起動
claude --dangerously-skip-permissions
```

### メッセージが表示されない
```bash
# メッセージングテスト
./team_messaging.sh --test

# ログ確認
tail -f logs/messaging_*.log
```

## 📋 ログファイル

| ファイル | 内容 |
|----------|------|
| `logs/launcher_*.log` | ランチャー実行ログ |
| `logs/messaging_*.log` | メッセージング履歴 |
| `logs/claude_auth.log` | Claude認証ログ |

## 🔄 アップデート履歴

### v4.0 - 完全新規実装
- tmuxsampleを参考にした完全書き直し
- 5人/8人構成の両対応
- ゼロプロンプト干渉メッセージング
- 階層的チーム組織
- クイック接続システム

### 従来版との差異
- ✅ **プロンプト干渉解決**: メッセージがClaudeに残らない
- ✅ **ペインタイトル維持**: Claude起動後も役職表示維持
- ✅ **階層組織対応**: Manager/CTO/CEO + Developers
- ✅ **自動化強化**: セッション検出・接続・管理の完全自動化

## 💡 ベストプラクティス

1. **推奨構成**: 5人構成から開始
2. **メッセージング**: 定期的な進捗共有
3. **ログ確認**: 問題発生時はログファイルを確認
4. **セッション管理**: 不要なセッションは定期的に終了
5. **Claude認証**: 事前に認証を完了しておく

---

📞 **サポート**: 問題が発生した場合は、ログファイルと併せて報告してください。