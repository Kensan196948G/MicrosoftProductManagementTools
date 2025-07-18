#\!/bin/bash
# tmux各WindowとPaneの作業ディレクトリをルートに変更

ROOT_DIR="/mnt/e/MicrosoftProductManagementTools"
SESSION_NAME="MicrosoftProductTools"

echo "各WindowとPaneの作業ディレクトリをルートディレクトリに変更中..."

# Window 0 (CTO)
tmux send-keys -t $SESSION_NAME:0 "cd $ROOT_DIR" C-m

# Window 1 (Manager)  
tmux send-keys -t $SESSION_NAME:1 "cd $ROOT_DIR" C-m

# Window 2 (Developer Workspace) - 各Paneを変更
tmux send-keys -t $SESSION_NAME:2.0 "cd $ROOT_DIR" C-m
tmux send-keys -t $SESSION_NAME:2.1 "cd $ROOT_DIR" C-m
tmux send-keys -t $SESSION_NAME:2.2 "cd $ROOT_DIR" C-m
tmux send-keys -t $SESSION_NAME:2.3 "cd $ROOT_DIR" C-m

# Window 3 (Monitoring) - tail -fを一旦停止してディレクトリ変更
tmux send-keys -t $SESSION_NAME:3.0 "C-c"
tmux send-keys -t $SESSION_NAME:3.0 "cd $ROOT_DIR" C-m
tmux send-keys -t $SESSION_NAME:3.0 "watch -n 5 'tail -n 20 ~/projects/MicrosoftProductTools/logs/developer-activity.log'" C-m

tmux send-keys -t $SESSION_NAME:3.1 "C-c"
tmux send-keys -t $SESSION_NAME:3.1 "cd $ROOT_DIR" C-m
tmux send-keys -t $SESSION_NAME:3.1 "tail -f ~/projects/MicrosoftProductTools/logs/integrated-dev.log" C-m

# Window 4 (Automation) - 既にプロジェクトディレクトリにいるのでルートに変更
tmux send-keys -t $SESSION_NAME:4 "cd $ROOT_DIR" C-m

echo "✅ 全WindowとPaneの作業ディレクトリをルートディレクトリに変更しました"
