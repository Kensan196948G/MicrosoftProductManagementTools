# Microsoft 365統合管理ツール - レポートフォルダ

このフォルダには、Microsoft 365統合管理ツールで生成されるレポートファイルが保存されます。

## フォルダ構造

### 🔐 Authentication/
認証・セキュリティ関連のレポート
- 認証テスト結果
- セキュリティ分析レポート
- 権限監査結果

### 📊 Reports/
定期レポート
- **Daily/**: 日次レポート
- **Weekly/**: 週次レポート  
- **Monthly/**: 月次レポート
- **Yearly/**: 年次レポート

### 📈 Analysis/
分析レポート
- **License/**: ライセンス分析
- **Usage/**: 使用状況分析
- **Performance/**: パフォーマンス監視

### 🛠️ Tools/
ツール・ユーティリティ
- **Config/**: 設定管理レポート
- **Logs/**: ログビューア出力

### 📧 Exchange/
Exchange Online 関連
- **Mailbox/**: メールボックス監視
- **MailFlow/**: メールフロー分析
- **AntiSpam/**: スパム対策レポート
- **Delivery/**: 配信レポート

### 💬 Teams/
Microsoft Teams 関連
- **Usage/**: チーム利用状況
- **MeetingQuality/**: 会議品質分析
- **ExternalAccess/**: 外部アクセス監視
- **Apps/**: アプリ利用状況

### 💾 OneDrive/
OneDrive 関連
- **Storage/**: ストレージ利用状況
- **Sharing/**: 共有ファイル監視
- **SyncErrors/**: 同期エラー分析
- **ExternalSharing/**: 外部共有レポート

### 🔐 EntraID/
Entra ID (Azure AD) 関連
- **Users/**: ユーザー監視
- **SignInLogs/**: サインインログ分析
- **ConditionalAccess/**: 条件付きアクセス
- **MFA/**: MFA状況確認
- **AppRegistrations/**: アプリ登録監視

## ファイル命名規則

全てのレポートファイルは以下の命名規則に従います：
```
ReportName_YYYYMMDD_HHMMSS.{csv,html}
```

例：
- `認証テスト結果_20251216_143052.csv`
- `日次レポート_20251216_143052.html`

## ファイル形式

- **CSV**: データ分析用の構造化ファイル
- **HTML**: 視覚的なレポート表示用ファイル

---
Generated by Microsoft 365統合管理ツール