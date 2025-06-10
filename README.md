# Microsoft製品運用管理ツール

ITSM/ISO27001/27002準拠 Microsoft 365 統合管理システム

## 📋 概要

このツール群は、Microsoft 365製品群（Active Directory、Entra ID、Exchange Online、OneDrive、Microsoft Teams）の運用業務を自動化し、ITSM（ISO/IEC 20000）および情報セキュリティ管理（ISO/IEC 27001・27002）に完全準拠した監視・レポート・証跡管理システムです。

## 🎯 主要機能

### ユーザー管理（UM系）
- ログイン履歴抽出（無操作検出）
- ログイン失敗アラート検出
- MFA未設定者抽出
- パスワード有効期限チェック
- ライセンス未割当者確認
- ユーザー属性変更履歴確認

### グループ管理（GM系）
- グループ一覧・構成抽出
- メンバー棚卸レポート出力
- 動的グループ設定確認
- グループ属性およびロール確認

### Exchange Online（EX系）
- メールボックス容量・上限監視
- 添付ファイル送信履歴分析
- 自動転送・返信設定の確認
- スパム・フィッシング傾向分析
- 配布グループ整合性チェック

### OneDrive/Teams/ライセンス（OD/TM/LM系）
- OneDrive使用容量／残容量の分析
- Teams構成確認（チーム一覧、録画設定、オーナー不在）
- OneDrive外部共有状況確認
- ライセンス配布状況・未使用ライセンス監視

## 🛠️ システム要件

| 項目 | 要件内容 |
|------|----------|
| OS | Windows 10/11 Pro or Server 2016以降 |
| PowerShell | v5.1 または PowerShell 7（Core対応） |
| .NET Framework | v4.8（PS5.1用） |
| モジュール | ExchangeOnlineManagement, Microsoft.Graph |
| 認証方式 | 証明書認証またはクライアントシークレット（非対話型） |
| 実行ポリシー | RemoteSigned または Bypass |

## 📁 フォルダ構成

```
MicrosoftProductManagementTools/
├── Scripts/
│   ├── AD/                 # Active Directory 管理
│   ├── EXO/                # Exchange Online 管理
│   ├── EntraID/            # Entra ID / Microsoft Graph 管理
│   └── Common/             # 共通関数・認証・ロギング処理
├── Reports/                # 自動生成レポート出力先
│   ├── Daily/
│   ├── Weekly/
│   ├── Monthly/
│   └── Yearly/
├── Logs/                   # 実行ログ／エラーログ／証跡ログ
├── Config/                 # 認証設定
│   └── appsettings.json
└── Templates/              # HTMLテンプレート群
```

## ⚙️ セットアップ

### 1. 必要なPowerShellモジュールのインストール

```powershell
# Microsoft Graph PowerShell SDK
Install-Module Microsoft.Graph -Scope CurrentUser

# Exchange Online Management
Install-Module ExchangeOnlineManagement -Scope CurrentUser

# Active Directory モジュール（必要に応じて）
# RSAT for Windows 10/11 または Windows Server機能として追加
```

### 2. 設定ファイルの更新

`Config/appsettings.json`を編集し、組織の環境に合わせて設定を更新してください：

```json
{
  "EntraID": {
    "TenantId": "YOUR-TENANT-ID-HERE",
    "ClientId": "YOUR-CLIENT-ID-HERE",
    "CertificateThumbprint": "YOUR-CERTIFICATE-THUMBPRINT-HERE"
  },
  "ExchangeOnline": {
    "Organization": "yourdomain.onmicrosoft.com",
    "AppId": "YOUR-EXO-APP-ID-HERE",
    "CertificateThumbprint": "YOUR-EXO-CERTIFICATE-THUMBPRINT-HERE"
  }
}
```

### 3. アプリケーション登録（Entra ID）

Microsoft Entra IDでアプリケーションを登録し、以下の権限を付与してください：

- `User.Read.All`
- `Group.Read.All`
- `Directory.Read.All`
- `AuditLog.Read.All`
- `Reports.Read.All`
- `Team.ReadBasic.All`

## 🚀 使用方法

### 管理ツールの初期化

```powershell
Import-Module Scripts\Common\Common.psm1
$config = Initialize-ManagementTools
```

### レポートの実行

```powershell
# 日次レポート
Scripts\Common\ScheduledReports.ps1 -ReportType "Daily"

# 週次レポート
Scripts\Common\ScheduledReports.ps1 -ReportType "Weekly"

# 月次レポート
Scripts\Common\ScheduledReports.ps1 -ReportType "Monthly"

# 年次レポート
Scripts\Common\ScheduledReports.ps1 -ReportType "Yearly"
```

### 個別スクリプトの実行例

```powershell
# Active Directory ユーザー管理
Scripts\AD\UserManagement.ps1

# Exchange Online メールボックス管理
Scripts\EXO\MailboxManagement.ps1

# Entra ID セキュリティ管理
Scripts\EntraID\UserSecurityManagement.ps1
```

## 📊 レポート出力

### レポート種別

| 種類 | 主な内容 | 実行頻度 |
|------|----------|----------|
| 日次 | ログイン失敗、容量監視、添付分析 | 毎日 06:00 |
| 週次 | MFA設定状況、外部共有、配布グループ棚卸 | 毎週月曜 07:00 |
| 月次 | 利用率・容量・権限レビュー、スパム傾向分析 | 毎月1日 08:00 |
| 年次 | ライセンス消費、インシデント統計、証跡一括出力 | 毎年1月1日 09:00 |

### 出力形式

- **HTML**: 可読性の高いダッシュボード形式
- **CSV**: 構造化データ（監査証跡・分析用）

## 🔧 自動化設定

### Windowsタスクスケジューラー設定例

```powershell
# 日次レポートのタスク作成
schtasks /create /tn "MS365DailyReport" /tr "powershell.exe -File 'C:\Path\To\Scripts\Common\ScheduledReports.ps1' -ReportType 'Daily'" /sc daily /st 06:00 /ru "SYSTEM"

# 週次レポートのタスク作成
schtasks /create /tn "MS365WeeklyReport" /tr "powershell.exe -File 'C:\Path\To\Scripts\Common\ScheduledReports.ps1' -ReportType 'Weekly'" /sc weekly /d mon /st 07:00 /ru "SYSTEM"
```

## 📋 コンプライアンス

### ISO 27001/27002 準拠

- 監査証跡の自動記録
- アクセス制御ログの管理
- 定期的なセキュリティレビュー
- インシデント検出・対応履歴

### ITSM（ISO/IEC 20000）準拠

- サービス可用性監視
- 変更管理履歴
- 問題管理・解決追跡
- サービスレベル測定

## 🛡️ セキュリティ

- **証明書認証**: 非対話型実行での安全な認証
- **最小権限**: 必要最小限のアクセス権限で動作
- **ログ暗号化**: 機密情報の保護
- **改ざん検知**: ログファイルの整合性チェック

## 📝 ログ管理

- **実行ログ**: スクリプト実行の詳細記録
- **エラーログ**: 障害・例外の詳細情報
- **監査ログ**: セキュリティ・コンプライアンス用証跡
- **保管期間**: 1年間（設定変更可能）

## ⚠️ 注意事項

1. **認証設定**: 本番環境では必ず証明書認証を使用してください
2. **権限管理**: 実行アカウントには必要最小限の権限のみを付与してください
3. **ログ保護**: ログファイルへの不正アクセスを防ぐため適切なアクセス制御を設定してください
4. **定期更新**: Microsoft Graph API の変更に対応するため定期的な更新を行ってください

## 🔄 更新履歴

- **Ver. 2.0** (2025年6月): ITSM/ISO27001/27002完全準拠版
- **Ver. 1.0** (2024年): 初期リリース

## 📞 サポート

技術的な問題や改善要望については、システム管理者にお問い合わせください。

---

**© 2025 Microsoft製品運用管理ツール - All Rights Reserved**