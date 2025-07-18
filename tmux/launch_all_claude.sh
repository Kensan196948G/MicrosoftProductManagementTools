#\!/bin/bash
# 全役割でClaude起動

echo "全役割でClaude起動中..."

# CTO (既に起動済みの場合はスキップ)
# tmux send-keys -t MicrosoftProductTools:0 "./claude_auto.sh 'CTOとして技術戦略を管理します'" C-m

# Manager (既に起動済みの場合はスキップ)
# tmux send-keys -t MicrosoftProductTools:1 "./claude_auto.sh 'Project Managerとしてチームを調整します'" C-m

# Frontend Developer
tmux send-keys -t MicrosoftProductTools:2.0 "./claude_auto.sh 'Frontend Developer として React/Vue.js の実装を行います'" C-m

# Backend Developer
tmux send-keys -t MicrosoftProductTools:2.1 "./claude_auto.sh 'Backend Developer として Node.js/Express の実装を行います'" C-m

# Test/QA Developer
tmux send-keys -t MicrosoftProductTools:2.2 "./claude_auto.sh 'Test/QA Developer として自動テストとセキュリティ検証を行います'" C-m

# Validation Developer
tmux send-keys -t MicrosoftProductTools:2.3 "./claude_auto.sh 'Validation Developer として手動テストと品質保証を行います'" C-m

echo "✅ 全Developer PaneでClaude起動コマンドを送信しました"
