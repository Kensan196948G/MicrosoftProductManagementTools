# 📚 tmux メッセージ送信システム - ドキュメント目次

Microsoft 365 Python移行プロジェクトのtmux並列開発環境における、メッセージ送信システムの全ドキュメント索引です。

## 🚀 はじめに読むべきドキュメント

### 1. [README.md](./README.md) 📖
**総合ガイド - すべてがここにまとまっています**
- システム全体の概要
- 基本コマンド・超簡単エイリアス
- 設定方法・トラブルシューティング
- **初回利用者は必読**

### 2. [QUICK_GUIDE.md](./QUICK_GUIDE.md) ⚡
**3秒で始める超簡単ガイド**
- 最重要3コマンド(`both`, `via`, `階層`)
- 引用符なし使用法
- 迷った時の判断基準
- **今すぐ使いたい方向け**

## 📋 機能別ドキュメント

### 3. [SHORTCUTS.md](./SHORTCUTS.md) 🔧
**詳細なショートカット説明**
- 全コマンド一覧表
- 階層的指示の詳細
- 実用例・使い分けガイド
- Before/After比較
- **コマンドを深く理解したい方向け**

## 🎯 役割別指示書

### 4. [instructions/cto.md](./instructions/cto.md) 👑
**CTO（最高技術責任者）指示書**
- 技術戦略決定・アーキテクチャ監督
- Manager委任プロセス
- ITシステム開発特化指示パターン
- UI/UX品質監督
- **CTO役割の方必読**

### 5. [instructions/manager.md](./instructions/manager.md) 👔
**Manager（技術プロジェクトマネージャー）指示書**
- Python移行プロジェクト管理
- 開発者タスク配布・進捗管理
- 技術的判断・品質統制
- **Manager役割の方必読**

### 6. [instructions/developer.md](./instructions/developer.md) 💻
**Developer（ソフトウェアエンジニア）指示書**
- Python移行開発タスク
- 技術専門性別役割分担
- 完了報告フォーマット
- UI/UX品質実装チェックリスト
- **Developer役割の方必読**

### 7. [instructions/powershell-specialist.md](./instructions/powershell-specialist.md) 🔧
**PowerShell・Microsoft 365専門家指示書**
- PowerShell 7・Microsoft Graph API
- Exchange Online統合
- ログ管理・監査証跡
- **Dev04（PowerShell専門）の方必読**

## 🛠️ システム・技術ドキュメント

### 8. 実行ファイル

| ファイル | 説明 | 対象者 |
|---|---|---|
| `quick-aliases.sh` | メイン関数エイリアス | 全員 |
| `send-message.sh` | ベースメッセージ送信 | システム |
| `shortcuts.sh` | スクリプト形式 | 上級者 |
| `launcher-6team-enterprise.sh` | 統一ランチャー | 管理者 |

### 9. 設定ファイル

| ファイル | 説明 |
|---|---|
| `tmux_shared_context.md` | 共有コンテキスト |
| `logs/communication.log` | 通信ログ |
| `logs/quality/` | 品質監視ログ |

## 🎯 使用場面別ガイド

### 📝 初回セットアップ
1. [README.md](./README.md) - 設定・インストール
2. [QUICK_GUIDE.md](./QUICK_GUIDE.md) - 基本操作

### 🚀 日常利用
1. [QUICK_GUIDE.md](./QUICK_GUIDE.md) - 3つのメインコマンド
2. [SHORTCUTS.md](./SHORTCUTS.md) - 詳細コマンド

### 🔧 高度な利用
1. [SHORTCUTS.md](./SHORTCUTS.md) - 全機能
2. 役割別指示書 - 専門的な運用

### 🆘 トラブル時
1. [README.md](./README.md) - トラブルシューティング
2. `launcher-6team-enterprise.sh` - 緊急診断

## 📊 コマンド早見表

### ⚡ 超簡単エイリアス（最重要）
```bash
both "メッセージ"    # 👔👨‍💻 両方に同時送信
via "メッセージ"     # 🔄 Manager経由指示  
階層 "メッセージ"    # 📋 Manager→Developer階層指示
```

### 📋 基本コマンド
```bash
manager "メッセージ"      # 👔 Manager
developer "メッセージ"    # 💻 Developer全員
cto "メッセージ"          # 👑 CTO
AllMember "メッセージ"    # 🌟 全員
```

### 🎯 個別指示
```bash
dev0 "メッセージ"    # 💻 Frontend専門
dev1 "メッセージ"    # 💻 Backend専門  
dev2 "メッセージ"    # 💻 QA専門
```

## 🔄 更新履歴

### 2025年7月20日
- ✅ 超簡単エイリアス追加（`both`, `via`, `階層`）
- ✅ 6ペイン構成対応完了
- ✅ PowerShell 7.5.1 WSL環境検出修正
- ✅ エンタープライズ統一ランチャー強化
- ✅ ドキュメント統合・体系化完了

### 主要機能完成
- ✅ tmux並列開発環境相互連携
- ✅ 階層的タスク管理システム
- ✅ 超簡単ショートカットシステム
- ✅ Context7統合
- ✅ 企業品質保証システム

## 🚀 今すぐ始める

```bash
# 1. エイリアス読み込み
source ./tmux/quick-aliases.sh

# 2. ヘルプ確認
tmux_help

# 3. 最初のメッセージ送信
both "はじめてのメッセージです"
```

## 🆘 サポート

- **ヘルプコマンド**: `tmux_help`
- **システム診断**: `./tmux/launcher-6team-enterprise.sh` → 24
- **ドキュメント**: 本目次から適切なファイルを選択

---

**🎯 目的別おすすめドキュメント**

| 目的 | おすすめドキュメント |
|---|---|
| **今すぐ使いたい** | [QUICK_GUIDE.md](./QUICK_GUIDE.md) |
| **全体を理解したい** | [README.md](./README.md) |
| **詳細を知りたい** | [SHORTCUTS.md](./SHORTCUTS.md) |
| **役割を理解したい** | `instructions/`内の該当ファイル |

**🚀 Microsoft 365 Python移行プロジェクトの成功のために！**