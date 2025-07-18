# ITSM-tmux並列開発環境仕様書

## 概要

このドキュメントは、Microsoft 365統合管理ツールのPython移行プロジェクト並列開発環境として構築されたtmuxベースの開発環境の仕様を定義します。ITSM（ISO/IEC 20000）準拠のIT運用システム開発において、5ペイン構成（Manager、CTO、Dev0、Dev1、Dev2）による効率的な開発体制を実現します。

**最終更新**: 2025年7月18日  
**対象**: Python移行プロジェクト統合ランチャー環境

## システム構成

### 環境要件
- **OS**: Linux/macOS/WSL2
- **tmux**: バージョン3.4以上推奨
- **PowerShell**: 7.5.1以上（Claude実行用）
- **Claude CLI**: 最新版（日本語対応）
- **Python**: 3.11以上（PyQt6対応）

### プロジェクト構造
```
MicrosoftProductManagementTools/
├── tmux/                                    # tmux並列開発環境
│   ├── python_tmux_launcher.sh            # 🚀 統合ランチャー（メイン）
│   ├── fix_pane_titles.sh                 # 🛠 緊急ペインタイトル修正
│   ├── enable_pane_titles_display.sh      # ⚙️ ペインタイトル表示設定
│   ├── collaboration/                      # 相互連携システム
│   │   ├── messaging_system_python.sh     # Python移行プロジェクト専用
│   │   ├── messaging_system.sh            # 汎用メッセージングシステム
│   │   ├── 5pane_integration_guide.md     # 5ペイン統合ガイド
│   │   ├── communication_flow_diagram.md  # コミュニケーションフロー図
│   │   └── tmux_config_summary.md         # tmux設定サマリー
│   ├── logs/                               # ログ保存用
│   │   └── messages/                       # メッセージログ
│   └── README.md                           # 使用ガイド
└── [その他のプロジェクトファイル]
```

## 5ペイン構成（Microsoft 365管理ツールPython版開発）

### ペインレイアウト
```
┌─────────────────┬─────────────────┐
│  👔 Manager     │  🐍 Dev0        │
│   (ペイン0)     │   (ペイン2)     │
├─────────────────┼─────────────────┤
│  👑 CTO         │  🧪 Dev1        │
│   (ペイン1)     │   (ペイン3)     │
│                 ├─────────────────┤
│                 │  🔄 Dev2        │
│                 │   (ペイン4)     │
└─────────────────┴─────────────────┘
```

### ペイン詳細（Python移行プロジェクト用）
- **ペイン0 (左上)**: 👔 Manager - 進捗管理・タスク調整
- **ペイン1 (左中)**: 👑 CTO - 戦略決定・技術承認
- **ペイン2 (右上)**: 🐍 Dev0 - Python GUI/API開発
- **ペイン3 (右中)**: 🧪 Dev1 - テスト・品質保証
- **ペイン4 (右下)**: 🔄 Dev2 - PowerShell互換・インフラ

## 役割定義

### 👑 CTO (Chief Technology Officer) - Pane 1
**責任範囲**:
- Python移行の戦略的決定
- 既存PowerShell版との互換性方針
- 技術アーキテクチャの最終承認
- 品質基準の設定
- 投資対効果の評価
- セキュリティポリシーの策定

**主要タスク**:
- PyQt6 vs tkinter の技術選定
- Microsoft Graph API統合方針
- PowerShell Bridge戦略
- 段階的移行計画の承認

### 👔 Manager (Project Manager) - Pane 0
**責任範囲**:
- 既存26機能の仕様分析
- Python版開発の進捗管理
- 3名開発者のタスク調整
- PowerShell版の継続運用管理
- ステークホルダーへの報告
- 品質統括とレビュー

**主要タスク**:
- Phase別スケジュール管理
- デイリースクラムの実施
- ブロッカー解決の調整
- 移行計画の具体化

### 🐍 Dev0 - Python GUI/API Developer - Pane 2
**責任範囲**:
- PyQt6によるGUI実装
- 既存26機能のPython実装
- Microsoft Graph API統合
- レポート生成エンジン開発
- ユーザー体験の完全互換

**専門技術**:
- Python 3.11+
- PyQt6フレームワーク
- MSAL認証
- pandas/jinja2

**担当機能**:
- 26機能のGUIボタン配置
- リアルタイムログパネル
- プログレスバー表示
- ポップアップ通知

### 🧪 Dev1 - Test/QA Developer - Pane 3
**責任範囲**:
- pytest基盤構築
- PowerShell版との互換性テスト
- GUI自動テストの実装
- CI/CDパイプライン構築
- 品質メトリクス管理

**専門技術**:
- Python pytest
- PyQt Test Framework
- GitHub Actions
- カバレッジ測定

**担当機能**:
- 単体テスト実装
- 統合テスト設計
- パフォーマンステスト
- セキュリティ監査

### 🔄 Dev2 - PowerShell Compatibility & Infrastructure - Pane 4
**責任範囲**:
- 既存PowerShell版の詳細分析
- Python版との互換性確保
- 移行ツールの開発
- WSL環境・インフラ管理
- ドキュメント作成

**専門技術**:
- PowerShell 7.5.1
- Python-PowerShell Bridge
- WSL2/Linux環境
- パッケージング技術

**担当機能**:
- 既存26機能の仕様解析
- Config/認証情報の移行
- 出力形式の互換性確保
- デプロイメント準備

## Claude統合

### 自動起動設定
各ペインでClaudeが自動起動し、役割に応じた日本語プロンプトが設定されます：

```bash
# セットアップ実行
./tmux_itsm_setup.sh

# 待機時間調整（デフォルト8秒）
CLAUDE_STARTUP_WAIT=10 ./tmux_itsm_setup.sh
```

### 日本語対応プロンプト（Python移行プロジェクト用）
各役割に以下のプロンプトが自動送信されます：
- **Manager (Pane 0)**: 「日本語で解説・対応してください。Project Manager として PowerShell版からPython版への移行プロジェクトを管理します。26機能の仕様分析とタスク調整を行います」
- **CTO (Pane 1)**: 「日本語で解説・対応してください。CTO として Python移行の技術戦略を決定します。既存資産を保護しつつ段階的移行を実現します」
- **Dev0 (Pane 2)**: 「日本語で解説・対応してください。Dev0 - Python GUI/API Developer として PyQt6による26機能のGUI実装とMicrosoft Graph API統合を担当します」
- **Dev1 (Pane 3)**: 「日本語で解説・対応してください。Dev1 - Test/QA Developer として pytest基盤構築とPowerShell版との互換性テストを実装します」
- **Dev2 (Pane 4)**: 「日本語で解説・対応してください。Dev2 - PowerShell Compatibility Developer として 既存仕様の分析と移行ツール開発を担当します」

## 相互連携システム

### メッセージングシステム
`collaboration/messaging_system.sh`により、役割間のコミュニケーションが可能：

```bash
# メッセージ送信
send_message "CTO" "Manager" "coordination" "新プロジェクトを開始します"
send_message "Manager" "Developer" "coordination" "タスクを割り当てます"
send_message "Dev0" "Manager" "status" "UIが完成しました"

# 緊急通知
emergency_notification "Dev2" "本番環境で問題発生"

# ステータス更新
update_status "CTO" "対応中" "問題を調査しています"
```

### 指示系統（Python移行プロジェクト）
1. **CTO (Pane 1) → Manager (Pane 0)**: Python移行戦略・技術方針の伝達
2. **Manager (Pane 0) → Developers (Pane 2-4)**: 具体的タスクの割り当て・優先度設定
3. **Developers → Manager**: 進捗報告・ブロッカー報告
4. **Manager → CTO**: 全体進捗・重要課題のエスカレーション
5. **Developer間の横断連携**: 技術相談・互換性確認

## 操作方法

### 基本操作
- **セッション作成**: `./tmux_itsm_setup.sh`
- **セッション接続**: `tmux attach-session -t MicrosoftProductTools`
- **ペイン移動**: `Ctrl+b` + 矢印キー
- **ペイン番号表示**: `Ctrl+b` + `q`
- **セッション終了**: `tmux kill-session -t MicrosoftProductTools`

### tmuxキーバインド
- **ペイン分割**: `Ctrl+b` + `|`（垂直）、`Ctrl+b` + `-`（水平）
- **ペインリサイズ**: `Ctrl+b` + `H/J/K/L`
- **ペインズーム**: `Ctrl+b` + `z`
- **設定リロード**: `Ctrl+b` + `r`

### 特殊キーバインド（5ペイン構成用）
- **Manager フォーカス**: `Alt+m`
- **CTO フォーカス**: `Alt+c`
- **Developer フォーカス**: `Alt+0/1/2`
- **全Developer停止**: `Alt+x`

## セキュリティ考慮事項

### 認証管理
- Microsoft 365認証情報は`Config/appsettings.json`で管理
- 証明書ベース認証またはクライアントシークレット方式を使用
- 認証情報の暗号化保存

### アクセス制御
- 各役割に応じた権限設定
- CTOのみが重要な設定変更可能
- 監査ログの自動記録

### コンプライアンス
- ISO/IEC 20000（ITSM）準拠
- ISO/IEC 27001（情報セキュリティ）準拠
- ISO/IEC 27002（セキュリティ管理策）準拠

## トラブルシューティング

### Claude起動時の問題
```bash
# 手動で初期プロンプト送信
./init_claude_roles.sh

# 待機時間を長くして再実行
CLAUDE_STARTUP_WAIT=15 ./tmux_itsm_setup.sh
```

### メッセージングシステムの問題
```bash
# ペイン番号確認
tmux list-panes -t MicrosoftProductTools:0

# メッセージングシステム再読み込み
source /mnt/e/MicrosoftProductManagementTools/tmux/collaboration/messaging_system.sh
```

### セッションリセット
```bash
# 完全リセット
tmux kill-session -t MicrosoftProductTools
./tmux_itsm_setup.sh
```

## 今後の拡張計画

1. **自動化強化**
   - CI/CDパイプライン統合
   - 自動デプロイメント機能
   - コード品質自動チェック

2. **監視機能**
   - リアルタイム進捗ダッシュボード
   - パフォーマンスメトリクス表示
   - エラー監視アラート

3. **コラボレーション強化**
   - ビデオ会議統合
   - 画面共有機能
   - コードレビューワークフロー

## 関連ドキュメント
- [README日本語.md](../README日本語.md) - プロジェクト全体の説明
- [CLAUDE.md](../CLAUDE.md) - Claude Code用ガイダンス
- [role_communication_guide.md](collaboration/role_communication_guide.md) - 役割間コミュニケーションガイド