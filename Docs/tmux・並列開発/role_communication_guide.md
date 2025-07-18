# 5ペイン構成 役割間コミュニケーションガイド（Python移行プロジェクト版）

## 概要
PowerShell版からPython版への移行プロジェクトにおける5ペイン構成での役割間の連携方法を説明します。

## ペイン配置（仕様書準拠）
```
┌─────────────────┬─────────────────┐
│  👔 Manager     │  🐍 Dev0        │
│   (ペイン0)     │   (ペイン2)     │
│  進捗管理       │  Python GUI/API  │
├─────────────────┼─────────────────┤
│  👑 CTO         │  🧪 Dev1        │
│   (ペイン1)     │   (ペイン3)     │
│  戦略決定       │  テスト/QA       │
│                 ├─────────────────┤
│                 │  🔄 Dev2        │
│                 │   (ペイン4)     │
│                 │  PowerShell互換  │
└─────────────────┴─────────────────┘
```

## 指示系統（Python移行プロジェクト）

### 1. CTO → Manager
- **目的**: Python移行戦略・技術方針の伝達
- **コマンド例**:
```bash
send_message "CTO" "Manager" "coordination" "PyQt6をGUIフレームワークとして採用します"
send_message "CTO" "Manager" "coordination" "Phase 1の品質基準を80%カバレッジに設定"
```

### 2. Manager → Developer
- **目的**: Python移行タスクの割り当て・進捗管理
- **コマンド例**:
```bash
# 全Developer宛
send_message "Manager" "Developer" "coordination" "Phase 1の基盤構築タスクを開始します"

# 特定Developer宛
send_message "Manager" "Dev0" "coordination" "PyQt6環境のセットアップをお願いします"
send_message "Manager" "Dev1" "coordination" "pytest基盤の構築を開始してください"
send_message "Manager" "Dev2" "coordination" "PowerShell版26機能の仕様分析をお願いします"
```

## 報告系統

### 1. Developer → Manager
- **目的**: Python移行作業の進捗報告・問題報告
- **コマンド例**:
```bash
send_message "Dev0" "Manager" "status" "PyQt6のMainWindow実装が完了しました"
send_message "Dev1" "Manager" "status" "単体テスト60%実装、カバレッジ72%達成"
send_message "Dev2" "Manager" "status" "既存26機能中15機能の仕様分析完了"
```

### 2. Manager → CTO
- **目的**: プロジェクト状況報告
- **コマンド例**:
```bash
send_message "Manager" "CTO" "status" "Sprint 3は予定通り進行中です"
```

### 3. Developer → CTO（技術相談）
- **目的**: Python移行に関する技術的判断
- **コマンド例**:
```bash
technical_consultation "Dev0" "CTO" "PyQt6とtkinterのパフォーマンス比較について"
technical_consultation "Dev2" "CTO" "PowerShellコマンドレットのPythonラッパー方式について"
```

## 緊急連絡

### 全員への緊急通知
```bash
emergency_notification "Manager" "本番環境で障害が発生しました"
emergency_notification "Dev2" "セキュリティ脆弱性を発見しました"
```

## メッセージングシステムの使い方

### 1. 初期設定
各ペインで以下を実行してメッセージング機能を有効化：
```bash
source /mnt/e/MicrosoftProductManagementTools/tmux/collaboration/messaging_system.sh
```

### 2. 基本的な使い方

#### メッセージ送信
```bash
send_message <送信元> <送信先> <タイプ> <メッセージ>
```

#### ステータス更新
```bash
update_status <役割> <ステータス> <詳細>
```

#### タスク依頼
```bash
request_task <送信元> <送信先> <タスク内容> <優先度>
```

#### 技術相談
```bash
technical_consultation <送信元> <送信先> <相談内容>
```

#### 緊急通知
```bash
emergency_notification <送信元> <メッセージ>
```

## メッセージタイプ
- **emergency**: 緊急事項（赤色） - 互換性問題、ブロッカー等
- **technical**: 技術的な内容（水色） - Python/PowerShell技術相談
- **coordination**: 調整・連携事項（黄色） - タスク割当、Phase調整
- **general**: 一般的な連絡（緑色） - 定例報告、会議連絡
- **status**: ステータス更新（青色） - 移行進捗、テスト結果

## 送信先オプション（Python移行プロジェクト用）
- **CTO**: CTOのみ（戦略決定）
- **Manager**: Managerのみ（進捗管理）
- **Developer**: 全Developer（Dev0, Dev1, Dev2）
- **Dev0** / **Python**: Dev0のみ（Python GUI/API）
- **Dev1** / **Test**: Dev1のみ（テスト/QA）
- **Dev2** / **Compat**: Dev2のみ（PowerShell互換）
- **All**: 全員

## 実践例

### 朝のスタンドアップミーティング（Python移行プロジェクト）
```bash
# Manager から全員へ
send_message "Manager" "All" "general" "おはようございます。Python移行プロジェクト朝会を開始します"

# 各Developerから進捗報告
send_message "Dev0" "All" "status" "昨日：PyQt6メインウィンドウ完成、今日：26機能ボタン実装"
send_message "Dev1" "All" "status" "昨日：pytest基盤構築完了、今日：GUIテスト実装"
send_message "Dev2" "All" "status" "昨日：PowerShell 10機能分析、今日：移行ツール設計"
```

### 技術的な意思決定（Python移行関連）
```bash
# Developer から CTO へ相談
technical_consultation "Dev0" "CTO" "PyQt6でのPowerShellコマンド実行方法について"

# CTO から回答
send_message "CTO" "Dev0" "technical" "subprocessモジュールでPowerShell呼び出しを実装してください"

# CTO から Manager へ連携
send_message "CTO" "Manager" "coordination" "PowerShellブリッジ方式をsubprocess経由に決定"
```

### 緊急対応フロー（Python移行特有の問題）
```bash
# 互換性問題発見
emergency_notification "Dev2" "本番環境でエラー率が急上昇しています"

# CTO から指示
send_message "CTO" "All" "emergency" "緊急対応モードに移行。Dev1は原因調査、Dev0はロールバック準備"

# Manager から調整
send_message "Manager" "All" "coordination" "定例会議は延期します。障害対応を優先"
```

## ログ管理
全てのメッセージは以下のログファイルに記録されます：
- `/mnt/e/MicrosoftProductManagementTools/logs/messages/all_messages.log`: 全メッセージ
- `/mnt/e/MicrosoftProductManagementTools/logs/messages/<role>_sent.log`: 送信ログ
- `/mnt/e/MicrosoftProductManagementTools/logs/messages/<role>_received.log`: 受信ログ

## トラブルシューティング

### メッセージが届かない場合
1. tmuxセッションが起動しているか確認
2. 正しいセッション名を確認（`tmux list-sessions`）
3. 正しいペイン番号か確認（`tmux list-panes -t MicrosoftProductTools-Python:0`）
4. メッセージングシステムがsourceされているか確認

### ペイン番号の確認方法
```bash
tmux display-panes -t MicrosoftProductTools-Python:0
```

## まとめ
この5ペイン構成により、PowerShell版からPython版への移行プロジェクトにおけるCTO・Manager・Developer間の効率的な連携が可能になります。

特にPython移行プロジェクトでは：
- **Manager**：既存仕様の分析とPhase管理
- **CTO**：技術戦略と品質基準の決定
- **Dev0**：PyQt6による新GUI実装
- **Dev1**：pytestと互換性テスト
- **Dev2**：PowerShell互換性の確保

適切なメッセージタイプと送信先を選択することで、移行プロジェクトの成功を支援します。