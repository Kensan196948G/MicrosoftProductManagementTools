# tmux AI並列開発システム 技術仕様書 v3.0

## 📋 システム概要

tmux AI並列開発システムは、複数のClaude AIエージェントを並列で動作させ、ITシステム開発における3階層体制（CTO→Manager→Developer）を実現する統合開発環境です。

## 🆕 v3.0 新統合システム

### 🔧 認証統一化システム

**問題解決**: tmux環境でのClaude認証問題を完全解決

**技術仕様**:
- **統一認証管理**: 環境変数による認証情報永続化
- **ペイン間認証統一**: 全てのペインで同じ認証状態を維持
- **自動認証継承**: 新しいペインで自動的に認証済み状態を継承
- **セッション復旧**: 既存セッションへの安全な再接続機能

### 🏗️ 新アーキテクチャ

#### 統合スクリプト
- **`~/bin/claude-tmux`**: ワンコマンド起動システム
- **環境変数統一**: CLAUDE_CODE_*系統の統一管理
- **tmux設定統合**: ~/.tmux.confとの完全統合

#### 3ペイン標準構成
```
┌─────────────────────────────────────────────────────────┐
│                    claude-dev セッション                 │
├─────────────────────────┬───────────────────────────────┤
│                         │                               │
│   🤖 Claude Main       │      🛠️ System Commands      │
│   (対話型・プライマリ)  │    (通常シェル・ファイル操作)  │
│                         │                               │
├─────────────────────────┼───────────────────────────────┤
│                         │                               │
│   ⚙️ Claude Work       │                               │
│   (作業用・セカンダリ)  │                               │
│                         │                               │
└─────────────────────────┴───────────────────────────────┘
```

### 🎯 主要目標
- **自動化されたITシステム開発**: AIエージェントによる効率的な開発プロセス
- **階層的チーム体制**: 現実的な開発組織構造の再現
- **高品質・高速開発**: 並列処理による開発効率向上
- **包括的品質保証**: セキュリティ・パフォーマンス・保守性の確保

### 🔧 v3.0 技術仕様

#### 環境変数管理
```bash
# ~/.bashrc 統合設定
export CLAUDE_CODE_CONFIG_PATH="$HOME/.local/share/claude"
export CLAUDE_CODE_CACHE_PATH="$HOME/.cache/claude"
export CLAUDE_CODE_AUTO_START="true"
export PATH="$HOME/bin:$PATH"
```

#### tmux統合設定
```bash
# ~/.tmux.conf 統合設定
set-environment -g CLAUDE_CODE_CONFIG_PATH "$HOME/.local/share/claude"
set-environment -g CLAUDE_CODE_CACHE_PATH "$HOME/.cache/claude"
set-environment -g CLAUDE_CODE_AUTO_START "true"

# Claude専用キーバインド
bind-key C-g new-window -n "claude-code"
bind-key C-d split-window -h \; split-window -v \; send-keys 'claude' C-m
```

#### エイリアス統合
```bash
# コマンド統合
alias claude-tmux="~/bin/claude-tmux"        # メイン起動
alias claude-attach="tmux attach-session -t claude-dev"
alias claude-kill="tmux kill-session -t claude-dev"
alias claude-list="tmux list-sessions | grep claude"
alias claude-status="tmux list-sessions 2>/dev/null | grep claude-dev"
```

## 🏗️ システムアーキテクチャ

### v3.0 統合システム構成

#### 新統合ディレクトリ構造
```
/home/kensan/
├── bin/                                    # 実行可能スクリプト
│   └── claude-tmux                         # 統合起動スクリプト
├── .bashrc                                 # 環境設定・エイリアス
├── .tmux.conf                              # tmux統合設定
├── .local/share/claude/                    # Claude設定
└── .cache/claude/                          # Claudeキャッシュ
```

### v2.0 レガシーシステム構成

#### ディレクトリ構造
```
/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/tmux/
├── README.md                           # システム概要・使用方法
├── scripts/                           # 実行スクリプト群
│   ├── main_launcher.sh               # メインランチャー（エントリーポイント）
│   ├── setup_2devs_new.sh            # 2 Developers構成
│   ├── setup_4devs_new.sh            # 4 Developers構成
│   ├── setup_6devs_new.sh            # 6 Developers構成
│   └── setup_4devs_perfect.sh        # 完璧版（旧版互換）
├── instructions/                      # AIエージェント役割定義
│   ├── manager.md                     # Technical Manager役割
│   ├── ceo.md                         # CTO役割
│   └── developer.md                   # Software Engineer役割
├── tmux_Docs/                         # 技術文書
│   ├── tmux仕様書.md                  # 本ファイル
│   └── 操作手順書.md                  # 操作マニュアル
├── logs/                              # ログファイル
│   ├── communication.log              # エージェント間通信ログ
│   ├── integration.log                # システム統合ログ
│   └── attach.log                     # セッション接続ログ
├── accept-claude-terms.sh             # Claude利用規約同意
├── attach-team.sh                     # セッション接続
├── check-claude-status.sh             # Claude状態確認
├── get-auth-url-manual.sh             # 手動認証URL取得
├── role-integration.sh                # 役割統合機能
└── send-message.sh                    # エージェント間メッセージング
```

## 🔧 システム構成

### 1. tmuxレイアウト仕様

#### 共通レイアウト構造
```
┌─────────────────────────────────────────────────────────┐
│                    tmux セッション                      │
├─────────────────┬───────────────────────────────────────┤
│                 │                                       │
│   👔 Manager    │           💻 Developers               │
│  （左上固定）   │         （右側均等分割）              │
│                 │                                       │
├─────────────────┤   Dev0  │  Dev1  │ Dev2  │ Dev3     │
│                 │─────────┼────────┼───────┼─────────│
│    👑 CEO       │         │        │       │           │
│  （左下固定）   │    （Developer数に応じて動的調整）   │
│                 │                                       │
└─────────────────┴───────────────────────────────────────┘
```

#### ペイン番号配置
- **ペイン0**: 👔 Manager（左上固定）
- **ペイン1**: 👑 CEO（左下固定）  
- **ペイン2〜N**: 💻 Developers（右側均等分割）

### 2. 利用可能な構成

| 構成名 | Developer数 | 総ペイン数 | 用途 |
|--------|-------------|------------|------|
| 2 Developers | 2 | 4 | 小規模開発・プロトタイプ |
| 4 Developers | 4 | 6 | 標準的な開発プロジェクト |
| 6 Developers | 6 | 8 | 大規模開発・複雑なシステム |
| 完璧版 | 4 | 6 | 既存プロジェクト互換 |

## 🤖 AIエージェント役割定義

### 1. CTO（最高技術責任者）- `instructions/ceo.md`

**責務:**
- 技術戦略決定・アーキテクチャ承認
- システム技術要件分析・技術方針決定
- プロジェクト最終承認・技術評価
- セキュリティ・品質基準設定

**主要行動パターン:**
```bash
# ITプロジェクト開始指示
./send-message.sh manager "【ITプロジェクト開始指示】
プロジェクト名：[システム名]
システム種別：[Webアプリ/API/DB/インフラ]
技術要件：[パフォーマンス・セキュリティ・スケーラビリティ]
推奨技術スタック：[React/Node.js/PostgreSQL/AWS等]
品質基準：[コードカバレッジ85%以上・OWASP準拠等]
期限：[リリース予定日]"
```

**禁止事項:**
- 直接的なコーディング・プログラミング
- Managerを経由しない開発者への直接指示
- 技術実装詳細の直接決定

### 2. Technical Manager - `instructions/manager.md`

**責務:**
- CTO技術指示の具体的実装管理
- 開発タスクの分割・配布・統括
- 技術進捗管理・品質保証・技術指導
- 開発者間の技術調整・統合

**重要な自動化行動:**
```bash
# CTO指示受信後3分以内の必須実行
./send-message.sh dev1 "【開発タスク】Frontend開発：React+TypeScript..."
./send-message.sh dev2 "【開発タスク】Backend開発：Node.js+Express..."
./send-message.sh dev3 "【開発タスク】QA・テスト：Jest+Cypress..."
./send-message.sh dev4 "【開発タスク】インフラ：Docker+AWS..."
```

**完了報告受信時の対応フロー:**
1. **即座に技術的受信確認**（3秒以内）
2. **全開発者の技術状況一覧化**
3. **技術的依存関係・統合判断**
4. **5分以内に次の技術アクション決定・実行**

### 3. Software Engineer - `instructions/developer.md`

**技術専門性分担:**
- **dev1**: フロントエンド/UI（React/TypeScript/レスポンシブ）
- **dev2**: バックエンド/インフラ（Node.js/Python/クラウド/CI-CD）
- **dev3**: QA/セキュリティ（テスト自動化/OWASP/監視）
- **dev4**: フルスタック/アーキテクチャ（設計/最適化/技術指導）

**完了報告必須フォーマット:**
```bash
./send-message.sh manager "【完了報告】[技術領域]: [完了内容]。
技術成果物: [コード・設定・ドキュメント]。
品質確認: [テスト結果・動作確認]。
次の指示をお待ちしています。"
```

**技術品質基準:**
- **コード品質**: ESLint/カバレッジ85%以上/TypeScript strict
- **セキュリティ**: OWASP準拠・脆弱性スキャン通過
- **パフォーマンス**: Core Web Vitals基準達成
- **ドキュメント**: 技術仕様書・API仕様書・運用手順書完備

## 🚀 スクリプト仕様

### 1. main_launcher.sh - システムエントリーポイント

**機能:**
- 統合メニューシステム
- 前提条件チェック（tmux・Claude CLI・指示ファイル）
- エラーハンドリング強化
- 既存セッション管理

**エラーハンドリング機能:**
- `set -euo pipefail`: エラー時即座終了
- ログ機能：info・success・error・warning
- エラートラップ：予期しないエラーの検出・報告
- ファイル存在・実行権限チェック

**実行方法:**
```bash
cd /media/kensan/LinuxHDD/ITSM-ITmanagementSystem/tmux
./scripts/main_launcher.sh
```

### 2. setup_*devs_new.sh - 構成別セットアップスクリプト

**共通機能:**
- 動的ペイン作成・分割
- 完全均等サイズ調整
- Claude AI自動起動
- ペインタイトル設定
- 構成検証・エラー検出

**サイズ調整アルゴリズム:**
```bash
# 右側Developer領域の完全均等化
WINDOW_HEIGHT=$(tmux display-message -t $SESSION -p '#{window_height}')
DEV_HEIGHT=$((WINDOW_HEIGHT / [DEVELOPER_COUNT]))

# 各Developerペインを絶対値で均等設定
for pane in $DEVELOPER_PANES; do
    tmux resize-pane -t $SESSION:0.$pane -y $DEV_HEIGHT
    tmux resize-pane -t $SESSION:0.$pane -p $PERCENTAGE
done
```

### 3. send-message.sh - エージェント間通信

**機能:**
- 役割別エージェント通信（ceo・manager・dev1-6）
- 動的ペイン解決システム
- 通信ログ記録
- エラーハンドリング

**使用例:**
```bash
./send-message.sh ceo "技術戦略に関する相談..."
./send-message.sh manager "開発進捗の報告..."
./send-message.sh dev1 "フロントエンド実装の依頼..."
```

## 📊 システム監視・ログ

### 1. ログファイル

#### communication.log - エージェント間通信
```
[2025-07-04 14:30:15] → manager: "【ITプロジェクト開始指示】ECサイト開発..."
[2025-07-04 14:33:42] → dev1: "【開発タスク】React フロントエンド開発..."
[2025-07-04 14:35:18] ← dev1: "【完了報告】フロントエンド開発完了..."
```

#### integration.log - システム統合
```
[2025-07-04 14:30:10] [INFO] System startup initiated
[2025-07-04 14:30:15] [SUCCESS] 4 Developers configuration created
[2025-07-04 14:30:20] [INFO] Claude agents initialization started
[2025-07-04 14:30:45] [SUCCESS] All Claude agents running successfully
```

### 2. 状態確認コマンド

```bash
./check-claude-status.sh              # Claude動作状況確認
./attach-team.sh                      # セッション状況表示・接続
tail -f logs/communication.log        # リアルタイム通信監視
```

## 🔒 セキュリティ・品質保証

### 1. Claude認証管理
- `accept-claude-terms.sh`: 利用規約自動同意
- `get-auth-url-manual.sh`: 手動認証URL取得
- 認証情報の安全な保存・管理

### 2. 品質基準
- **コードカバレッジ**: 85%以上必須
- **セキュリティテスト**: OWASP準拠・脆弱性ゼロ
- **パフォーマンステスト**: 目標値達成必須
- **ドキュメント**: 技術仕様書・API仕様書・運用手順書

### 3. エラー対応
- 包括的エラーハンドリング
- 自動復旧機能
- 詳細なエラーログ・デバッグ情報
- トラブルシューティングガイド

## 🚦 運用フロー

### 1. システム起動
```bash
cd /media/kensan/LinuxHDD/ITSM-ITmanagementSystem/tmux
./scripts/main_launcher.sh
# 構成選択（1-4）
```

### 2. プロジェクト開始
```bash
# CTOへプロジェクト開始要請
./send-message.sh ceo "【プロジェクト開始要請】ECサイト開発"
```

### 3. 開発監視
```bash
tmux attach-session -t claude-team-[構成名]  # 開発画面接続
```

### 4. セッション操作
```bash
Ctrl+B → ↑↓←→    # ペイン移動
Ctrl+B → z       # ペイン全画面切り替え
Ctrl+B → d       # セッション切断
```

## 🔧 トラブルシューティング

### 1. よくある問題

#### "no space for new pane"エラー
**原因**: ターミナルサイズ不足
**解決**: 新システムで自動解決済み（動的サイズ計算）

#### Claude認証エラー
```bash
./accept-claude-terms.sh
./get-auth-url-manual.sh
```

#### ペイン配置異常
**原因**: 分割順序エラー
**解決**: 新システムで自動解決済み（正確な分割手順）

#### セッション競合
**解決**: main_launcher.shが自動的に既存セッション確認・終了

### 2. システム再起動
```bash
tmux kill-server                      # 全セッション強制終了
./scripts/main_launcher.sh            # システム再起動
```

### 3. ログ確認
```bash
tail -f logs/communication.log        # 通信ログ監視
tail -f logs/integration.log          # 統合ログ監視
```

## 🚀 今後の拡張予定

### 1. 技術的拡張
- Developer数の動的拡張（8・10・12開発者）
- クラウド統合（AWS・Azure・GCP連携）
- CI/CD パイプライン自動化
- コンテナ化対応（Docker・Kubernetes）

### 2. 機能拡張
- プロジェクト種別別ワークフロー
- 自動コードレビュー機能
- 品質メトリクス自動収集
- レポート生成機能

### 3. UI/UX改善
- Web UI統合
- リアルタイム進捗可視化
- ダッシュボード機能
- 通知システム

## 🆕 v3.0 運用手順

### 1. 統合システム起動
```bash
# ワンコマンド起動
claude-tmux
```

### 2. セッション管理
```bash
# 状態確認
claude-status

# 再接続
claude-attach

# 終了
claude-kill
```

### 3. tmux内操作
```bash
# 開発用レイアウト作成
Ctrl+b → Ctrl+d

# 新しいClaude専用ウィンドウ
Ctrl+b → Ctrl+g

# 現在のウィンドウを分割
Ctrl+b → Ctrl+l
```

### 4. 認証問題解決
```bash
# 環境変数確認
echo $CLAUDE_CODE_CONFIG_PATH
echo $CLAUDE_CODE_CACHE_PATH

# 設定再読み込み
source ~/.bashrc
```

## 🔄 システム移行ガイド

### v2.0 → v3.0 移行手順

1. **新統合システムセットアップ**
   ```bash
   # 設定読み込み
   source ~/.bashrc
   
   # 新システム起動
   claude-tmux
   ```

2. **旧システムとの併用**
   ```bash
   # 旧システム（必要に応じて）
   cd /media/kensan/LinuxHDD/ITSM-ITmanagementSystem/tmux
   ./scripts/main_launcher.sh
   ```

3. **認証問題の完全解決**
   - v3.0では認証問題が根本的に解決
   - 全ペインで統一認証状態を維持
   - 新しいペインで自動的に認証継承

---

**最終更新**: 2025年7月5日  
**バージョン**: 3.0  
**システム状態**: 本番稼動可能（認証問題完全解決）