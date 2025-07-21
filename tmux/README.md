# 🚀 tmux メッセージ送信システム 総合ドキュメント

Microsoft 365 Python移行プロジェクトのためのtmux並列開発環境における、超簡単メッセージ送信システムの完全ガイドです。

## 📋 目次

1. [⚡ クイックスタート](#-クイックスタート)
2. [🎯 基本コマンド](#-基本コマンド)
3. [🚀 超簡単エイリアス](#-超簡単エイリアス)
4. [📝 使用例](#-使用例)
5. [📊 システム構成](#-システム構成)
6. [🔧 設定・インストール](#-設定インストール)
7. [📖 詳細ドキュメント](#-詳細ドキュメント)

## ⚡ クイックスタート

### 1. エイリアス読み込み
```bash
source ./tmux/quick-aliases.sh
```

### 2. すぐに使える3つのコマンド
```bash
both "プロジェクト進捗確認をお願いします"     # 👔👨‍💻 両方に同時送信
via "技術仕様変更をDeveloperに説明して"      # 🔄 Manager経由指示
階層 "APIスケジュール調整してください"       # 📋 階層指示
```

### 3. 引用符なしでもOK！
```bash
both 進捗確認
via 仕様変更説明
階層 スケジュール調整
```

## 🎯 基本コマンド

| コマンド | 送信先 | 説明 |
|---|---|---|
| `manager "メッセージ"` | 👔 Manager | プロジェクト管理者に送信 |
| `developer "メッセージ"` | 💻 開発者全員 | 全開発者に一斉送信 |
| `cto "メッセージ"` | 👑 CTO | 技術責任者に送信 |
| `AllMember "メッセージ"` | 🌟 全員 | Manager + 全開発者に送信 |

## 🚀 超簡単エイリアス（最重要！）

### 🎯 CTOからの階層的指示

| コマンド | 動作 | 使用場面 |
|---|---|---|
| `both "メッセージ"` | 👔👨‍💻 両方に同時送信 | 即座に全員に伝えたい |
| `via "メッセージ"` | 🔄 Manager経由指示 | Managerの判断を経由したい |
| `階層 "メッセージ"` | 📋 Manager→Developer階層指示 | 正式な階層管理を重視 |

### 🎯 個別開発者指示

| コマンド | 送信先 | 専門分野 |
|---|---|---|
| `dev0 "メッセージ"` | 💻 Dev0 | フロントエンド専門 (React + TypeScript) |
| `dev1 "メッセージ"` | 💻 Dev1 | バックエンド専門 (Python + FastAPI) |
| `dev2 "メッセージ"` | 💻 Dev2 | QA・テスト専門 (pytest + CI/CD) |

## 📝 使用例

### CTOからの典型的な指示パターン

```bash
# エイリアス読み込み
source ./tmux/quick-aliases.sh

# 🌟 プロジェクト全体指示
AllMember "Microsoft 365 Python移行プロジェクトのフェーズ2を開始します"

# 🎯 階層的指示（推奨パターン）
both "プロジェクト進捗確認をお願いします"
via "技術仕様変更についてDeveloperに説明してください"
階層 "バックエンドAPIの実装スケジュールを調整してください"

# 💻 専門分野別指示
dev0 "React + TypeScript によるGUI移行を開始してください"
dev1 "PowerShell Scripts → Python + FastAPI移行を開始してください"
dev2 "pytest自動テスト環境の構築をお願いします"

# 📋 個別確認
manager "各開発者の進捗状況をまとめて報告してください"
```

### 日常的な開発コミュニケーション

```bash
# 🔄 技術相談
cto "認証システムの実装方針について相談があります"

# 💻 開発者間連携
developer "API仕様書を更新しました。確認をお願いします"

# 📊 完了報告
manager "フロントエンドコンポーネント実装が完了しました"

# ⚡ 緊急対応
both "緊急：本番環境でエラーが発生しています"
```

## 📊 システム構成

### 🏗️ 6ペイン構成
- **Pane 0**: 👑 CTO - 戦略統括・技術方針決定
- **Pane 1**: 👔 Manager - チーム管理・品質統制
- **Pane 2**: 💻 Dev01 (dev0) - FullStack開発（フロントエンド専門）
- **Pane 3**: 💻 Dev02 (dev1) - FullStack開発（バックエンド専門）
- **Pane 4**: 💻 Dev03 (dev2) - QA・テスト専門
- **Pane 5**: 🔧 Dev04 - PowerShell・Microsoft 365専門

### 🔄 メッセージ経路

```
CTO → both → Manager + Developer (直接)
CTO → via → Manager → Developer (経由)
CTO → 階層 → Manager → Developer (階層)
```

## 🔧 設定・インストール

### 前提条件
- tmux 3.4以上
- PowerShell 7.5.1以上（WSL環境対応）
- Context7統合 (npx 9.2.0以上)
- Python 3.12.3以上

### セットアップ

1. **プロジェクトディレクトリに移動**
```bash
cd /mnt/e/MicrosoftProductManagementTools
```

2. **エイリアス読み込み**
```bash
source ./tmux/quick-aliases.sh
```

3. **自動起動設定（オプション）**
```bash
# ~/.bashrc または ~/.zshrc に追加
alias tmux-aliases='source /mnt/e/MicrosoftProductManagementTools/tmux/quick-aliases.sh'
```

### 🚀 統合ランチャー
```bash
./tmux/launcher-6team-enterprise.sh
```
- 6人チーム エンタープライズ統一ランチャー
- PowerShell 7検出・Context7統合
- 品質監視システム
- 緊急診断機能

## 📖 詳細ドキュメント

### 📁 ファイル構成

| ファイル | 説明 |
|---|---|
| `quick-aliases.sh` | メイン関数エイリアス |
| `send-message.sh` | ベースメッセージ送信システム |
| `shortcuts.sh` | スクリプト形式ショートカット |
| `launcher-6team-enterprise.sh` | エンタープライズ統一ランチャー |

### 📚 参考ドキュメント

1. **[QUICK_GUIDE.md](./QUICK_GUIDE.md)** - 3秒で始める超簡単ガイド
2. **[SHORTCUTS.md](./SHORTCUTS.md)** - 詳細なショートカット説明
3. **[instructions/](./instructions/)** - 各役割の詳細指示書
   - `cto.md` - CTO役割指示
   - `manager.md` - Manager役割指示
   - `developer.md` - Developer役割指示
   - `powershell-specialist.md` - PowerShell専門家指示

### 🎨 アイコン表示機能

**最新アップデート (2025年7月20日)**: 全ての送受信メッセージにアイコン表示機能を追加

#### 役職別アイコン
- 👑 **CTO**: 技術戦略・最高責任者
- 👔 **Manager**: プロジェクト管理・チーム統括
- 💻 **Dev0/Frontend**: フロントエンド開発 (React + TypeScript)
- ⚙️ **Dev1/Backend**: バックエンド開発 (Python + FastAPI)
- 🧪 **Dev2/QA**: テスト・品質保証 (pytest + CI/CD)
- 📢 **その他**: 汎用メッセージ

#### アイコン表示例
```bash
# 送信時のアイコン表示
📤 👑 → 👔 送信中: Manager へメッセージを送信...
✅ 👑 → 👔 送信完了: Manager に自動実行されました

# 緊急メッセージの場合
⚡ 👑 → 💻 即時配信実行: dev0
⚡ 👑 → 💻 即時配信完了: dev0
```

#### 対応機能
- ✅ **階層メッセージング**: CTO→Manager→Developer指示にアイコン表示
- ✅ **緊急メッセージ**: 即時配信時のアイコン表示
- ✅ **進捗報告収集**: 報告要求・完了通知のアイコン表示
- ✅ **自動タスク分散**: ラウンドロビン分配時のアイコン表示
- ✅ **チーム活動監視**: 非アクティブ検出ping時のアイコン表示

### 🔄 従来コマンドとの比較

#### Before (従来)
```bash
./tmux/send-message.sh manager "現在の開発状況を教えてください"
./tmux/send-message.sh broadcast "バックエンドAPIの実装を開始してください"
./tmux/send-message.sh manager "【CTOから指示】技術仕様変更をDeveloperに伝達してください"
```

#### After (超簡単エイリアス)
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

## 💡 トラブルシューティング

### ❓ よくある質問

**Q: エイリアスが認識されない**
```bash
# 再読み込み
source ./tmux/quick-aliases.sh
```

**Q: tmuxセッションが見つからない**
```bash
# セッション確認
tmux list-sessions
# ランチャーで再セットアップ
./tmux/launcher-6team-enterprise.sh
```

**Q: PowerShell 7が検出されない**
```bash
# WSL環境の場合、pwsh.exeを確認
which pwsh.exe
pwsh.exe --version
```

### 🆘 ヘルプ・サポート

```bash
# ヘルプ表示
tmux_help

# システム状況確認
./tmux/launcher-6team-enterprise.sh
# → 22) システム状況確認

# 緊急診断
./tmux/launcher-6team-enterprise.sh  
# → 24) 緊急システム診断
```

## 🎯 成功メトリクス

- **コマンド入力短縮**: 70%削減 (`./tmux/send-message.sh` → `both`)
- **階層指示効率**: 3パターンを簡単コマンドで実現
- **学習コスト**: 3つのコマンド(`both`, `via`, `階層`)で完結
- **エラー率**: 引用符なし対応で入力ミス削減

---

## 🚀 今すぐ始める

```bash
# 1. エイリアス読み込み
source ./tmux/quick-aliases.sh

# 2. 一番簡単なコマンドで送信
both 進捗確認

# 3. ヘルプ確認
tmux_help
```

**🎉 Microsoft 365 Python移行プロジェクトのチーム連携が革命的に簡単になりました！**

---

*最終更新: 2025年7月20日*  
*作成者: CTO (Claude Code)*  
*プロジェクト: Microsoft Product Management Tools Python移行*  
*アイコン表示機能追加: 2025年7月20日*