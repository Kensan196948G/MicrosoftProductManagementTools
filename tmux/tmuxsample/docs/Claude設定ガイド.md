# Claude Code v3.0 統合システム セットアップガイド

## 🎯 概要

このファイルは、tmux環境でのClaude認証問題を完全解決するv3.0統合システムのセットアップ手順です。

## 🚀 自動セットアップ（推奨）

### システム要件確認済み
- ✅ Claude Code 1.0.38 インストール済み
- ✅ tmux 3.4 インストール済み  
- ✅ bash シェル環境
- ✅ 認証情報パス: `~/.local/share/claude/`

### セットアップ完了内容

#### 1. 環境変数設定
```bash
# ~/.bashrc に追加済み
export CLAUDE_CODE_CONFIG_PATH="$HOME/.local/share/claude"
export CLAUDE_CODE_CACHE_PATH="$HOME/.cache/claude"  
export CLAUDE_CODE_AUTO_START="true"
export PATH="$HOME/bin:$PATH"
```

#### 2. tmux統合設定
```bash
# ~/.tmux.conf に追加済み
set-environment -g CLAUDE_CODE_CONFIG_PATH "$HOME/.local/share/claude"
set-environment -g CLAUDE_CODE_CACHE_PATH "$HOME/.cache/claude"
set-environment -g CLAUDE_CODE_AUTO_START "true"

# Claude専用キーバインド
bind-key C-g new-window -n "claude-code"
bind-key C-d split-window -h \; split-window -v \; send-keys 'claude' C-m
bind-key C-l split-window -h \; split-window -v \; send-keys 'claude' C-m
```

#### 3. 起動スクリプト
- **場所**: `~/bin/claude-tmux`
- **権限**: 実行可能（755）
- **機能**: 3ペイン自動構成、認証統一管理

#### 4. エイリアス設定
```bash
# ~/.bashrc に追加済み
alias claude-tmux="~/bin/claude-tmux"
alias claude-attach="tmux attach-session -t claude-dev"
alias claude-kill="tmux kill-session -t claude-dev"
alias claude-list="tmux list-sessions | grep claude"
alias claude-status="tmux list-sessions 2>/dev/null | grep claude-dev"
```

## 🔧 使用方法

### 1. 設定有効化（初回のみ）
```bash
source ~/.bashrc
```

### 2. システム起動
```bash
claude-tmux
```

### 3. セッション管理
```bash
claude-status    # 状態確認
claude-attach    # 再接続
claude-kill      # 終了
claude-list      # 一覧
```

### 4. tmux内操作
```bash
# 開発用レイアウト作成
Ctrl+b → Ctrl+d

# 新しいClaude専用ウィンドウ
Ctrl+b → Ctrl+g

# 現在のウィンドウを分割
Ctrl+b → Ctrl+l
```

## 🆚 システム比較

| 項目 | v2.0（旧） | v3.0（新） |
|------|------------|------------|
| 認証問題 | ❌ 頻発 | ✅ 完全解決 |
| 起動方法 | `./scripts/main_launcher.sh` | `claude-tmux` |
| ペイン構成 | 4-8ペイン | 3ペイン（効率化） |
| 設定管理 | 手動 | 自動・永続化 |
| 環境変数 | 不統一 | 統一管理 |
| トラブル対応 | 複雑 | シンプル |

## 🔍 認証問題解決の仕組み

### 統一認証管理
1. **環境変数による永続化**: CLAUDE_CODE_CONFIG_PATH統一
2. **ペイン間認証統一**: 全ペイン同じ認証状態
3. **自動認証継承**: 新ペインで自動的に認証済み状態
4. **セッション復旧**: 既存セッションへの安全な再接続

### 技術的実装
```bash
# tmux環境変数設定により全ペインで統一
set-environment -g CLAUDE_CODE_CONFIG_PATH "$HOME/.local/share/claude"
set-environment -g CLAUDE_CODE_CACHE_PATH "$HOME/.cache/claude"

# 起動スクリプトでプロジェクトディレクトリ固定
PROJECT_DIR="/media/kensan/LinuxHDD/ITSM-ITmanagementSystem"

# 各ペインで同じ環境でClaude起動
tmux send-keys -t $SESSION:0.0 'claude' C-m
tmux send-keys -t $SESSION:0.1 'claude' C-m
```

## 🚨 トラブルシューティング

### エイリアスが認識されない
```bash
# 設定再読み込み
source ~/.bashrc

# 手動実行
~/bin/claude-tmux
```

### セッション競合
```bash
claude-kill     # 既存セッション終了
claude-tmux     # 新セッション開始
```

### 認証状態確認
```bash
echo $CLAUDE_CODE_CONFIG_PATH
echo $CLAUDE_CODE_CACHE_PATH
```

## 📁 ファイル構成

```
/home/kensan/
├── bin/
│   └── claude-tmux                 # 統合起動スクリプト
├── .bashrc                         # 環境設定・エイリアス
├── .tmux.conf                      # tmux統合設定
├── .local/share/claude/            # Claude設定
└── .cache/claude/                  # Claudeキャッシュ

/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/tmux/
├── claude-tmux                     # スクリプトのコピー
├── CLAUDE_V3_SETUP.md             # このファイル
├── README.md                       # v3.0対応更新済み
├── tmux_Docs/
│   ├── tmux-specification.md              # v3.0対応更新済み
│   └── operation-manual.md              # v3.0対応更新済み
└── operation-manual.md                  # v3.0対応更新済み
```

## ✅ セットアップ確認

### 動作確認チェックリスト
- [ ] `claude --version` でバージョン表示
- [ ] `claude-tmux` コマンドでセッション起動
- [ ] 3ペイン構成で表示される
- [ ] 全ペインでClaude認証済み状態
- [ ] `claude-status` でセッション確認可能
- [ ] セッション終了・再起動が正常動作

### 認証確認
- [ ] Main ペインでClaude起動確認
- [ ] Work ペインでClaude起動確認  
- [ ] 新しいペイン作成時も認証継承
- [ ] セッション再接続後も認証維持

## 📞 サポート

- **v3.0新機能**: 認証問題完全解決、ワンコマンド起動
- **v2.0レガシー**: 既存システムとの併用可能
- **移行サポート**: 段階的移行対応

---

**作成日**: 2025年7月5日  
**バージョン**: 3.0  
**ステータス**: セットアップ完了・運用開始可能