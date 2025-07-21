# 🚀 tmux メッセージ送信ショートカット

簡単なコマンドでtmuxペイン間のメッセージ送信ができるショートカット集です。

## 🎯 基本的な使用方法

### 1. エイリアス有効化
```bash
# プロジェクトディレクトリで実行
source ./tmux/quick-aliases.sh
```

### 2. 簡単コマンドで送信
```bash
# 👔 Managerに送信
manager "現在の開発状況を教えてください"

# 💻 開発者全員に送信
developer "バックエンドAPIの実装を開始してください"

# 👑 CTOに送信
cto "技術的な判断が必要です"

# 🌟 全員に送信
AllMember "定時ミーティングを開始します"
```

## 📋 基本ショートカット（アイコン表示対応）

| ショートカット | 送信先 | アイコン表示 | 説明 |
|---|---|---|---|
| `manager "メッセージ"` | 👔 Manager | 📤 [送信者] → 👔 送信中 | プロジェクト管理者に送信 |
| `developer "メッセージ"` | 💻 開発者全員 | 📤 [送信者] → 💻⚙️🧪 送信中 | 全開発者に一斉送信 |
| `cto "メッセージ"` | 👑 CTO | 📤 [送信者] → 👑 送信中 | 技術責任者に送信 |
| `AllMember "メッセージ"` | 🌟 全員 | 📤 [送信者] → 👔💻⚙️🧪 送信中 | Manager + 全開発者に送信 |

## 🎯 階層的指示ショートカット

| ショートカット | 動作 | 説明 |
|---|---|---|
| `mgr_dev "メッセージ"` | 📋 Manager→Developer階層指示 | Managerが受けて→Developerに伝達 |
| `mgr_and_dev "メッセージ"` | 🎯 Manager+Developer同時指示 | Manager・Developer両方に直接送信 |
| `via_manager "メッセージ"` | 🔄 Manager経由Developer指示 | Manager経由でDeveloperに伝達指示 |

## 🚀 超簡単エイリアス（最重要！）

| ショートカット | 動作 | 説明 |
|---|---|---|
| `both "メッセージ"` | 🎯 両方に同時送信 | Manager・Developer両方に直接送信 |
| `via "メッセージ"` | 🔄 Manager経由指示 | Manager経由でDeveloperに伝達指示 |
| `階層 "メッセージ"` | 📋 Manager→Developer階層指示 | Managerが受けて→Developerに伝達 |

**💫 引用符なしでもOK！**
- `both 進捗確認`
- `via 仕様変更説明`
- `階層 スケジュール調整`

## 🎯 個別開発者向けショートカット（アイコン表示対応）

| ショートカット | 送信先 | アイコン表示 | 専門分野 |
|---|---|---|---|
| `dev0 "メッセージ"` | 💻 Dev0 | 📤 [送信者] → 💻 送信中 | フロントエンド専門 (React + TypeScript) |
| `dev1 "メッセージ"` | ⚙️ Dev1 | 📤 [送信者] → ⚙️ 送信中 | バックエンド専門 (Python + FastAPI) |
| `dev2 "メッセージ"` | 🧪 Dev2 | 📤 [送信者] → 🧪 送信中 | QA・テスト専門 (pytest + CI/CD) |

## 📝 実用例

### CTOからの指示
```bash
# エイリアス読み込み
source ./tmux/quick-aliases.sh

# 全体指示
AllMember "Microsoft 365 Python移行プロジェクトのフェーズ2を開始します"

# 🚀 超簡単エイリアス（最推奨！）
both "プロジェクト進捗確認をお願いします"
via "技術仕様変更についてDeveloperに説明してください"
階層 "バックエンドAPIの実装スケジュールを調整してください"

# 従来の階層的指示
mgr_dev "バックエンドAPIの実装スケジュールを調整してください"
via_manager "技術仕様変更についてDeveloperに説明してください"
mgr_and_dev "プロジェクト進捗確認をお願いします"

# 専門分野別指示
dev0 "React + TypeScript によるGUI移行を開始してください"
dev1 "PowerShell Scripts → Python + FastAPI移行を開始してください"
dev2 "pytest自動テスト環境の構築をお願いします"

# 進捗確認
manager "各開発者の進捗状況をまとめて報告してください"
```

### 開発中の連絡
```bash
# 技術相談
cto "認証システムの実装方針について相談があります"

# 開発者間連携
developer "API仕様書を更新しました。確認をお願いします"

# 完了報告
manager "フロントエンドコンポーネント実装が完了しました"
```

## 🔄 従来コマンドとの比較

### Before (従来)
```bash
./tmux/send-message.sh manager "現在の開発状況を教えてください"
./tmux/send-message.sh broadcast "バックエンドAPIの実装を開始してください"
./tmux/send-message.sh manager "【CTOから指示】技術仕様変更をDeveloperに伝達してください"
```

### After (超簡単エイリアス)
```bash
source ./tmux/quick-aliases.sh
manager "現在の開発状況を教えてください"
both "プロジェクト進捗確認をお願いします"
via "技術仕様変更をDeveloperに説明してください"

# 引用符なしでもOK！
both 進捗確認
via 仕様変更説明
階層 スケジュール調整
```

## 🚀 自動起動設定

プロジェクト作業時に毎回自動で読み込むには、`.bashrc`や`.zshrc`に追加：

```bash
# ~/.bashrc または ~/.zshrc に追加
alias tmux-aliases='source /mnt/e/MicrosoftProductManagementTools/tmux/quick-aliases.sh'

# または、プロジェクトディレクトリに移動時の自動読み込み
cd /mnt/e/MicrosoftProductManagementTools && source ./tmux/quick-aliases.sh
```

## 🎨 アイコン表示機能 (New!)

**最新アップデート (2025年7月20日)**: 全てのメッセージ送受信にアイコン表示機能を追加

### 役職別アイコン
- 👑 **CTO**: 技術戦略・最高責任者
- 👔 **Manager**: プロジェクト管理・チーム統括
- 💻 **Dev0/Frontend**: フロントエンド開発 (React + TypeScript)
- ⚙️ **Dev1/Backend**: バックエンド開発 (Python + FastAPI)
- 🧪 **Dev2/QA**: テスト・品質保証 (pytest + CI/CD)

### アイコン表示例
```bash
# 送信時
📤 👑 → 👔 送信中: Manager へメッセージを送信...
✅ 👑 → 👔 送信完了: Manager に自動実行されました

# 緊急メッセージ時
⚡ 👑 → 💻 即時配信実行: dev0
⚡ 👑 → 💻 即時配信完了: dev0
```

## 💡 ヒント

- **メッセージに日本語OK**: `manager "進捗確認をお願いします"`
- **長いメッセージも可能**: 複数行はクオートで囲む
- **アイコン表示**: 送受信状況が視覚的に確認可能
- **エラー時は従来コマンド**: 問題時は`./tmux/send-message.sh`を直接使用
- **ヘルプ表示**: `tmux_help`で使用方法を再表示

## 🔧 技術詳細

- **ベースコマンド**: `./tmux/send-message.sh`のラッパー関数
- **対象セッション**: `MicrosoftProductTools-Python-Context7-5team`
- **ログ記録**: `logs/communication.log`に自動記録
- **色付き出力**: 送信状況が視覚的に確認可能