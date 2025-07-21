# 🚀 超簡単！tmuxメッセージ送信ガイド

## ⚡ 3秒で始める

```bash
source ./tmux/quick-aliases.sh
```

## 🎯 最も使う3つのコマンド

### 1️⃣ 両方に送信
```bash
both "プロジェクト進捗確認をお願いします"
```
- Manager・Developer両方に直接送信
- 即座に全員に伝えたい時

### 2️⃣ Manager経由で指示
```bash
via "技術仕様変更をDeveloperに説明してください"
```
- Managerが受けて→Developerに伝達
- Managerの判断を経由したい時

### 3️⃣ 階層指示
```bash
階層 "バックエンドAPIのスケジュール調整してください"
```
- Manager→Developer階層指示
- 正式な階層管理を重視する時

## 💫 超簡単！引用符なしもOK

```bash
both 進捗確認
via 仕様変更説明
階層 スケジュール調整
```

## 📋 基本コマンド

```bash
manager "メッセージ"      # 👔 Managerのみ
developer "メッセージ"    # 💻 Developer全員
cto "メッセージ"          # 👑 CTOのみ
AllMember "メッセージ"    # 🌟 全員
```

## 🎯 個別指示

```bash
dev0 "React実装お願いします"     # 💻 Frontend専門
dev1 "FastAPI実装お願いします"   # 💻 Backend専門
dev2 "テスト実装お願いします"    # 💻 QA専門
```

## 💡 迷った時は

- **急ぎで全員に**: `both`
- **Manager経由で**: `via`
- **正式な階層で**: `階層`

## 🔄 ヘルプ表示

```bash
tmux_help
```

---

**📝 使用例**
```bash
# エイリアス読み込み
source ./tmux/quick-aliases.sh

# 今すぐ使える！
both "定時ミーティング開始します"
via "新しい技術仕様について説明してください"
階層 "開発スケジュールを調整してください"
```

🚀 **これだけ覚えればOK！**