# Microsoft 365管理ツール コーディング規約

策定日: 2025年1月17日  
策定者: CTO  
バージョン: 1.0

## 1. 全般的な規約

### 1.1 ファイル命名規則
- **PowerShellスクリプト**: パスカルケース（例：`Authentication.psm1`）
- **設定ファイル**: 小文字（例：`appsettings.json`）
- **レポートファイル**: 機能名_タイムスタンプ（例：`DailyReport_20250117_120000.csv`）

### 1.2 文字エンコーディング
- **すべてのファイル**: UTF-8 with BOM
- **CSVファイル**: UTF-8 BOM（Excel互換性確保）
- **HTMLファイル**: UTF-8（meta charset指定必須）

### 1.3 コメント規約
- 関数の先頭に概要説明を記載
- 複雑なロジックには日本語でコメント追加
- TODOコメントは`# TODO: [担当者] 内容`形式

## 2. PowerShell固有の規約

### 2.1 関数命名規則
```powershell
# 良い例
function Get-UserLicenseInfo { }
function Set-ExchangeConfiguration { }
function New-ComplianceReport { }

# 悪い例
function getUserInfo { }  # キャメルケース不可
function ProcessData { }  # 動詞-名詞形式必須
```

### 2.2 パラメータ定義
```powershell
function Get-UserReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportType,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('CSV', 'HTML', 'Both')]
        [string]$OutputFormat = 'Both',
        
        [Parameter(Mandatory = $false)]
        [int]$MaxResults = 1000
    )
    # 実装
}
```

### 2.3 エラーハンドリング
```powershell
try {
    # 主処理
    $result = Invoke-RestMethod @params
}
catch [System.Net.WebException] {
    # ネットワークエラー固有の処理
    Write-Error "ネットワークエラー: $_"
    throw
}
catch {
    # 一般的なエラー処理
    Write-Error "予期しないエラー: $_"
    throw
}
finally {
    # クリーンアップ処理
}
```

### 2.4 ログ出力
```powershell
# 統一されたログ関数を使用
Write-Log -Level "Info" -Message "処理開始"
Write-Log -Level "Warning" -Message "リトライ実行中"
Write-Log -Level "Error" -Message "認証エラー発生" -ErrorRecord $_
```

## 3. Microsoft 365 API統合規約

### 3.1 認証処理
```powershell
# 認証は必ずAuthentication.psm1の関数を使用
$authResult = Get-AuthenticatedConnection -Service "MicrosoftGraph"

# 直接接続は禁止
# Connect-MgGraph -ClientId $appId  # NG
```

### 3.2 API呼び出し
```powershell
# リトライロジック付き関数を使用
$users = Invoke-GraphAPIWithRetry -Uri "/v1.0/users" -Method "GET"

# バッチ処理の実装
$batchSize = 100
$allUsers = @()
$skipToken = $null
do {
    $uri = "/v1.0/users?`$top=$batchSize"
    if ($skipToken) { $uri += "&`$skiptoken=$skipToken" }
    $response = Invoke-GraphAPIWithRetry -Uri $uri
    $allUsers += $response.value
    $skipToken = $response.'@odata.nextLink'
} while ($skipToken)
```

### 3.3 権限チェック
```powershell
# 必要な権限を明示的にチェック
$requiredScopes = @("User.Read.All", "Directory.Read.All")
Test-RequiredPermissions -Scopes $requiredScopes
```

## 4. セキュリティ規約

### 4.1 認証情報の取り扱い
```powershell
# 環境変数または設定ファイルから取得
$clientSecret = $env:AZURE_CLIENT_SECRET
$certPassword = Get-SecureStringFromConfig -Key "CertificatePassword"

# ハードコーディング禁止
# $password = "MyPassword123"  # 絶対NG
```

### 4.2 証明書の管理
```powershell
# 証明書は専用ディレクトリに保管
$certPath = Join-Path $PSScriptRoot "..\..\Certificates\mycert.pfx"

# パスワードはSecureStringで管理
$certPassword = ConvertTo-SecureString $env:CERT_PASSWORD -AsPlainText -Force
```

### 4.3 ログのサニタイゼーション
```powershell
# 機密情報をマスク
$maskedUrl = $url -replace '(client_secret=)[^&]+', '$1****'
Write-Log -Message "API呼び出し: $maskedUrl"
```

## 5. パフォーマンス規約

### 5.1 並列処理
```powershell
# ForEach-Object -Parallelの使用（PowerShell 7+）
$results = $items | ForEach-Object -Parallel {
    # 処理
} -ThrottleLimit 5
```

### 5.2 メモリ管理
```powershell
# 大量データの処理後は明示的に解放
$largeData = Get-LargeDataset
# 処理
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
```

## 6. テスト規約

### 6.1 単体テスト
```powershell
# Pesterフレームワークの使用
Describe "Get-UserLicenseInfo" {
    It "有効なユーザーIDでライセンス情報を取得" {
        $result = Get-UserLicenseInfo -UserId "test@contoso.com"
        $result | Should -Not -BeNullOrEmpty
    }
}
```

### 6.2 統合テスト
- TestScripts配下に配置
- 実データとダミーデータの両方でテスト
- エラーケースも含める

## 7. ドキュメント規約

### 7.1 関数ドキュメント
```powershell
<#
.SYNOPSIS
    ユーザーのライセンス情報を取得します

.DESCRIPTION
    指定されたユーザーのMicrosoft 365ライセンス情報を
    Microsoft Graph APIを使用して取得します

.PARAMETER UserId
    ユーザーのUPN（user@domain.com）

.EXAMPLE
    Get-UserLicenseInfo -UserId "john@contoso.com"

.OUTPUTS
    PSCustomObject - ライセンス情報を含むオブジェクト
#>
```

### 7.2 README更新
- 新機能追加時は必ずREADME.mdを更新
- 使用例を含める
- 依存関係を明記

## 8. バージョン管理規約

### 8.1 コミットメッセージ
```
種別: 簡潔な説明

詳細な説明（必要に応じて）

関連Issue: #123
```

種別：
- feat: 新機能
- fix: バグ修正
- docs: ドキュメント更新
- refactor: リファクタリング
- test: テスト追加・修正
- chore: その他の変更

### 8.2 ブランチ戦略
- main: 本番環境
- develop: 開発環境
- feature/*: 機能開発
- hotfix/*: 緊急修正

## 9. 非推奨項目と移行方針

### 9.1 PowerShell 5.1固有機能
- 使用を避け、PowerShell 7互換のコードを記述
- やむを得ない場合はバージョンチェックを実装

### 9.2 Exchange Online旧API
- `CertificateThumbprint`パラメータ → `CertificatePath`へ移行
- 基本認証 → 証明書ベース認証へ完全移行

## 10. レビューチェックリスト

- [ ] 命名規則に従っているか
- [ ] エラーハンドリングが適切か
- [ ] ログ出力が実装されているか
- [ ] セキュリティ規約に準拠しているか
- [ ] テストが作成されているか
- [ ] ドキュメントが更新されているか
- [ ] パフォーマンスを考慮しているか
- [ ] PowerShell 7.5.1で動作確認済みか

## 改訂履歴

| バージョン | 日付 | 変更内容 | 承認者 |
|---------|------|---------|--------|
| 1.0 | 2025-01-17 | 初版作成 | CTO |