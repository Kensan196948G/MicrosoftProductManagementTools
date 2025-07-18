# tmux設定 仕様書準拠版 まとめ

## 📋 正しいペイン配置

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

## 🔄 連携フロー

### 基本的な指示系統
```
👔 Manager (Pane 0) ←→ 👑 CTO (Pane 1)
  ↓ タスク分解・指示    ↑ 戦略決定・承認
🐍 dev0 (Pane 2) ←→ 🧪 dev1 (Pane 3) ←→ 🔄 dev2 (Pane 4)
     実装           テスト              互換性確認
```

### 役割と責任

#### Pane 0: 👔 Manager
- **位置**: 左上（最も目立つ位置）
- **役割**: 進捗管理・タスク調整の中心
- **責任**: 
  - CTOからの戦略を具体的タスクに分解
  - 3名の開発者への指示と調整
  - 全体進捗の把握と報告

#### Pane 1: 👑 CTO
- **位置**: 左中
- **役割**: 戦略決定・最終承認
- **責任**:
  - Python移行の戦略的判断
  - 技術アーキテクチャの承認
  - 重要な意思決定

#### Pane 2: 🐍 Developer dev0
- **位置**: 右上
- **役割**: GUI/API開発
- **責任**:
  - PyQt6によるGUI実装
  - Microsoft Graph API統合
  - 26機能の実装

#### Pane 3: 🧪 Developer dev1
- **位置**: 右中
- **役割**: テスト・品質保証
- **責任**:
  - pytest基盤構築
  - 自動テスト実装
  - CI/CD パイプライン

#### Pane 4: 🔄 Developer dev2
- **位置**: 右下
- **役割**: 互換性・インフラ
- **責任**:
  - PowerShell版との互換性
  - WSL環境管理
  - 移行ツール開発

## 📝 更新内容まとめ

1. **setup_5pane_dev.sh**
   - ペイン配置を仕様書準拠に修正
   - Manager を Pane 0（左上）に配置
   - CTO を Pane 1（左中）に配置

2. **Microsoft365管理ツール変更仕様書.md**
   - ペイン初期化コマンドを修正
   - 役割の順序を修正（Manager → CTO）
   - 連携フローを正しい配置に更新

3. **連携パターン**
   - Manager が中心となる調整役
   - CTO は戦略的判断に専念
   - Developer間の横断的連携を維持

## 🚀 使用方法

```bash
# tmux環境を起動
./tmux/collaboration/setup_5pane_dev.sh

# 各ペインでの基本操作
# Pane 0 (Manager): タスク管理と調整
team status Manager "スプリント開始、タスク割り当て中"

# Pane 1 (CTO): 戦略的指示
team request CTO Manager "Phase 1の品質基準を80%に設定"

# Pane 2-4 (Developers): 実装と報告
team status dev0 "PyQt6環境構築完了"
team consult dev1 dev2 "PowerShell互換テストの実装方法"
```

これで仕様書に完全準拠したtmux設定となりました。