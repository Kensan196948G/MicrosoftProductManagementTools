#!/bin/bash
# Create a monitoring pane within tmux

SESSION="MicrosoftProductTools-Python-Context7-5team"

# Create a new window for monitoring
tmux new-window -t "${SESSION}" -n "Monitor"

# Split the window horizontally
tmux split-window -h -t "${SESSION}:Monitor"

# In the left pane, monitor Manager (pane 0)
tmux send-keys -t "${SESSION}:Monitor.0" "watch -n 1 'tmux capture-pane -t \"${SESSION}:0.0\" -p | tail -30 | grep -E \"送信|完了|実行|dev[0-5]|タスク\"'" Enter

# In the right pane, monitor communication log
tmux send-keys -t "${SESSION}:Monitor.1" "tail -f logs/communication.log" Enter

echo "✅ モニターウィンドウを作成しました"
echo "切り替え: tmux select-window -t ${SESSION}:Monitor"