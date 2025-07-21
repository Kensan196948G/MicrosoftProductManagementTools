# 6人構成並列開発環境 - Context7統合共有コンテキスト
## 更新時刻: Mon Jul 21 08:11:35 JST 2025
## 進捗状況:
- Manager: Context7統合待機中
- CTO: Context7統合待機中
- Dev01: 待機中
- Dev02: 待機中
- Dev03: 待機中
- Dev04: PowerShell専門待機中

## 連携フロー:
Manager → CTO → Dev01/Dev02/Dev03/Dev04 → CTO → Manager

## メッセージ送信方法:
./tmux/send-message.sh [role] [メッセージ]
./tmux/send-message.sh manager "【報告】タスク完了"
