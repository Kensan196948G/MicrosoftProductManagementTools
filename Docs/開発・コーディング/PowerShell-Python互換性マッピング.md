# PowerShell-Python互換性マッピング仕様書

## 概要
本ドキュメントは、既存PowerShell版Microsoft365管理ツールの26機能をPython版に移行する際の互換性マッピングを定義します。

## 1. アーキテクチャマッピング

### PowerShell構成 → Python構成

| PowerShell | Python | 説明 |
|------------|---------|------|
| `Apps/GuiApp_Enhanced.ps1` | `src/gui/main_window.py` | メインGUIアプリケーション |
| `Apps/CliApp_Enhanced.ps1` | `src/cli/cli_app.py` | CLIアプリケーション |
| `Scripts/Common/*.psm1` | `src/core/*.py` | コア機能モジュール |
| `Config/appsettings.json` | `Config/appsettings.json` | 設定ファイル（完全互換） |
| `Reports/` | `Reports/` | 出力ディレクトリ（完全互換） |

## 2. 認証方式の互換性

### 証明書認証（優先）
- **PowerShell**: `ExchangeOnlineManagement` モジュールの証明書認証
- **Python**: `msal` ライブラリによる証明書認証
- **互換性**: 既存の証明書（.pfx, .cer）をそのまま利用可能

### 設定ファイル互換性
```json
{
  "Authentication": {
    "TenantId": "xxx",
    "ClientId": "xxx",
    "CertificateThumbprint": "xxx",
    "CertificatePath": "Certificates/mycert.pfx",
    "CertificatePassword": "xxx"
  }
}
```

## 3. 26機能の詳細マッピング

### 3.1 定期レポート（5機能）

| 機能名 | PowerShell実装 | Python実装 | API/データソース |
|--------|----------------|------------|-----------------|
| 日次レポート | `Get-M365DailyReport` | `reports.daily_report()` | Graph API: `/reports/getOffice365ActiveUserDetail` |
| 週次レポート | `Get-M365WeeklyReport` | `reports.weekly_report()` | Graph API: 複数エンドポイント集約 |
| 月次レポート | `Get-M365MonthlyReport` | `reports.monthly_report()` | Graph API: 月次集計 |
| 年次レポート | `Get-M365YearlyReport` | `reports.yearly_report()` | Graph API: 年次集計 |
| テスト実行 | `Test-M365Reports` | `reports.test_execution()` | モックデータ生成 |

### 3.2 分析レポート（5機能）

| 機能名 | PowerShell実装 | Python実装 | API/データソース |
|--------|----------------|------------|-----------------|
| ライセンス分析 | `Get-M365LicenseAnalysis` | `analysis.license_analysis()` | Graph API: `/subscribedSkus` |
| 使用状況分析 | `Get-M365UsageAnalysis` | `analysis.usage_analysis()` | Graph API: `/reports/getOffice365ActiveUserCounts` |
| パフォーマンス分析 | `Get-M365PerformanceAnalysis` | `analysis.performance_analysis()` | Graph API: `/reports/getTeamsUserActivityCounts` |
| セキュリティ分析 | `Get-M365SecurityAnalysis` | `analysis.security_analysis()` | Graph API: `/security/alerts` |
| 権限監査 | `Get-M365PermissionAudit` | `analysis.permission_audit()` | Graph API: `/roleManagement/directory/roleAssignments` |

### 3.3 Entra ID管理（4機能）

| 機能名 | PowerShell実装 | Python実装 | API/データソース |
|--------|----------------|------------|-----------------|
| ユーザー一覧 | `Get-EntraIDUsers` | `entra.get_users()` | Graph API: `/users` |
| MFA状況 | `Get-MFAStatus` | `entra.get_mfa_status()` | Graph API: `/users?$select=strongAuthenticationRequirements` |
| 条件付きアクセス | `Get-ConditionalAccess` | `entra.get_conditional_access()` | Graph API: `/identity/conditionalAccess/policies` |
| サインインログ | `Get-SignInLogs` | `entra.get_signin_logs()` | Graph API: `/auditLogs/signIns` |

### 3.4 Exchange Online管理（4機能）

| 機能名 | PowerShell実装 | Python実装 | API/データソース |
|--------|----------------|------------|-----------------|
| メールボックス管理 | `Get-MailboxManagement` | `exchange.mailbox_management()` | Graph API: `/users/{id}/mailboxSettings` |
| メールフロー分析 | `Get-MailFlowAnalysis` | `exchange.mail_flow_analysis()` | Graph API: `/reports/getEmailActivityCounts` |
| スパム対策 | `Get-SpamProtection` | `exchange.spam_protection()` | Graph API: `/security/alerts` (filtered) |
| 配信分析 | `Get-DeliveryAnalysis` | `exchange.delivery_analysis()` | Graph API: `/reports/getEmailAppUsageUserDetail` |

### 3.5 Teams管理（4機能）

| 機能名 | PowerShell実装 | Python実装 | API/データソース |
|--------|----------------|------------|-----------------|
| Teams使用状況 | `Get-TeamsUsage` | `teams.usage_report()` | Graph API: `/reports/getTeamsUserActivityCounts` |
| Teams設定 | `Get-TeamsSettings` | `teams.get_settings()` | Graph API: `/teams/{id}/settings` |
| 会議品質 | `Get-MeetingQuality` | `teams.meeting_quality()` | Graph API: `/communications/callRecords` |
| アプリ分析 | `Get-TeamsAppAnalysis` | `teams.app_analysis()` | Graph API: `/teams/apps` |

### 3.6 OneDrive管理（4機能）

| 機能名 | PowerShell実装 | Python実装 | API/データソース |
|--------|----------------|------------|-----------------|
| ストレージ分析 | `Get-StorageAnalysis` | `onedrive.storage_analysis()` | Graph API: `/reports/getOneDriveUsageAccountDetail` |
| 共有分析 | `Get-SharingAnalysis` | `onedrive.sharing_analysis()` | Graph API: `/sites/{id}/drives/{id}/items` |
| 同期エラー | `Get-SyncErrors` | `onedrive.sync_errors()` | Graph API: `/reports/getOneDriveActivityUserDetail` |
| 外部共有分析 | `Get-ExternalSharing` | `onedrive.external_sharing()` | Graph API: `/sites/{id}/permissions` |

## 4. 出力形式の互換性

### HTMLレポート
- **テンプレートエンジン**: Jinja2（PowerShellのヒアドキュメントを置換）
- **デザイン**: 既存のレスポンシブデザインを完全継承
- **JavaScript**: 既存のreport-functions.jsをそのまま利用

### CSVレポート
- **エンコーディング**: UTF-8 BOM（PowerShell互換）
- **列構成**: 既存フォーマットを完全維持
- **日付形式**: `yyyy-MM-dd HH:mm:ss`

### ファイル命名規則
```
{レポート名}_{YYYYMMDD}_{HHMMSS}.{拡張子}
例: 日次レポート_20250118_143022.html
```

## 5. PowerShellブリッジ設計

### 必要最小限のPowerShell連携
```python
# PowerShell Bridge例
class PowerShellBridge:
    def execute_ps_command(self, command: str) -> str:
        """既存PowerShellスクリプトを実行"""
        # Exchange Online接続など、Python未対応機能用
        pass
```

### 段階的移行対象
1. Exchange Online PowerShell専用コマンドレット
2. 複雑な権限設定スクリプト
3. レガシーシステム連携部分

## 6. UI/UX互換性

### ボタン配置
- 6つのタブ構成を維持
- 各タブ内のボタン配置を完全再現
- 絵文字アイコンの継承

### ログ表示
- リアルタイムログ表示（3つのタブ）
- カラーコーディング（5レベル）
- PowerShellプロンプトタブの維持

### ポップアップ通知
- 成功/警告/エラー通知
- 自動クローズタイマー
- 既存の通知位置・デザイン継承

## 7. 移行優先順位

### Phase 1（必須機能）
1. 基本認証・API接続
2. ユーザー一覧・ライセンス分析
3. 日次レポート生成

### Phase 2（コア機能）
1. 全定期レポート
2. Entra ID管理機能
3. 基本的な分析レポート

### Phase 3（高度機能）
1. Exchange Online管理
2. Teams/OneDrive管理
3. セキュリティ分析

### Phase 4（最適化）
1. パフォーマンス改善
2. 非同期処理実装
3. キャッシュ機能

## 8. テスト戦略

### 互換性テスト
```python
def test_output_compatibility():
    """PowerShell版とPython版の出力比較"""
    ps_output = load_powershell_report()
    py_output = generate_python_report()
    assert compare_reports(ps_output, py_output)
```

### 機能テスト
- 全26機能の動作確認
- API接続テスト
- エラーハンドリング確認

### パフォーマンステスト
- PowerShell版との処理時間比較
- メモリ使用量測定
- 同時実行性能

## 9. ドキュメント更新計画

### 更新対象
1. ユーザーマニュアル（操作手順書）
2. 管理者ガイド（運用マニュアル）
3. API仕様書
4. トラブルシューティングガイド

### 新規作成
1. Python環境セットアップガイド
2. 移行手順書
3. PowerShell-Python対応表

## 10. リスクと対策

### 技術的リスク
- **Exchange Online PowerShell依存**: ブリッジ実装で対応
- **証明書認証の複雑性**: 既存証明書の再利用
- **パフォーマンス劣化**: 非同期処理・キャッシュで対策

### 運用リスク
- **ユーザー教育**: UIを完全互換にして最小化
- **データ移行**: 既存レポートディレクトリをそのまま利用
- **並行運用**: PowerShell版を残して段階移行

---

**作成日**: 2025年1月18日  
**バージョン**: 1.0  
**次回更新**: Phase 1完了時