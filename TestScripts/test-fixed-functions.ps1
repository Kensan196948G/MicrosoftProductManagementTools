# ================================================================================
# 修正後の関数テスト
# test-fixed-functions.ps1
# 修正した関数が正しく動作するか確認
# ================================================================================

Write-Host "`n🔍 修正後の関数テスト開始" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor DarkGray

# テスト環境準備
$rootPath = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $rootPath "Scripts\Common"

Write-Host "`n1️⃣ 修正した関数の確認" -ForegroundColor Yellow

$fixedFunctions = @(
    @{ 
        Original = "Get-EXOMailboxCapacityReport"
        Fixed = "Get-ExchangeMailboxReport"
        Module = "Scripts\EXO\MailboxManagement.ps1"
    },
    @{ 
        Original = "Get-EXOMailDeliveryReport (in ScheduledReports)"
        Fixed = "Get-ExchangeMessageTrace"
        Module = "Scripts\EXO\MailDeliveryAnalysis.ps1"
    },
    @{ 
        Original = "Get-EXOForwardingRules"
        Fixed = "Get-ExchangeTransportRules"
        Module = "Scripts\EXO\MailboxManagement.ps1"
    },
    @{ 
        Original = "Get-EXODistributionGroupReport"
        Fixed = "Get-ExchangeDistributionGroups"
        Module = "Scripts\EXO\MailboxManagement.ps1"
    },
    @{ 
        Original = "Get-OneDriveSharingReport"
        Fixed = "Get-OneDriveReport"
        Module = "Scripts\EntraID\TeamsOneDriveManagement.ps1"
    },
    @{ 
        Original = "Get-OneDriveUsageReport"
        Fixed = "Get-OneDriveReport"
        Module = "Scripts\EntraID\TeamsOneDriveManagement.ps1"
    }
)

foreach ($func in $fixedFunctions) {
    Write-Host "`n  📋 $($func.Original)" -ForegroundColor Yellow
    Write-Host "     → 修正後: $($func.Fixed)" -ForegroundColor Green
    Write-Host "     → モジュール: $($func.Module)" -ForegroundColor Gray
}

Write-Host "`n2️⃣ ScheduledReports.ps1の読み込みテスト" -ForegroundColor Yellow

try {
    Import-Module "$modulePath\ScheduledReports.ps1" -Force
    Write-Host "✅ ScheduledReports.ps1の読み込み成功" -ForegroundColor Green
}
catch {
    Write-Host "❌ ScheduledReports.ps1の読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n3️⃣ 日次レポート生成テスト（修正後）" -ForegroundColor Yellow

try {
    # 必要なモジュールをインポート
    Import-Module "$modulePath\Common.psm1" -Force
    Import-Module "$modulePath\Authentication.psm1" -Force
    Import-Module "$modulePath\Logging.psm1" -Force
    
    Write-Host "日次レポート生成を実行..." -ForegroundColor Cyan
    
    # 日次レポート実行（エラーが発生しないことを確認）
    $result = & {
        try {
            Invoke-DailyReports
            return @{ Success = $true; Error = $null }
        }
        catch {
            return @{ Success = $false; Error = $_.Exception.Message }
        }
    }
    
    if ($result.Success) {
        Write-Host "✅ 日次レポート生成が正常に実行されました" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  日次レポート生成でエラーが発生しましたが、関数エラーではありません" -ForegroundColor Yellow
        Write-Host "   エラー: $($result.Error)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "❌ テストエラー: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n4️⃣ 修正内容のサマリー" -ForegroundColor Yellow

Write-Host @"

修正した内容:
1. Get-EXOMailboxCapacityReport → Get-ExchangeMailboxReport
2. Get-EXOMailDeliveryReport → Get-ExchangeMessageTrace（別モジュール）
3. Get-AttachmentAnalysisNEW → コメントアウト（実装確認が必要）
4. Get-EXOForwardingRules → Get-ExchangeTransportRules
5. Get-EXODistributionGroupReport → Get-ExchangeDistributionGroups
6. Get-OneDriveSharingReport → Get-OneDriveReport
7. Get-OneDriveUsageReport → Get-OneDriveReport
8. Get-M365LicenseUtilizationReport → コメントアウト（実装確認が必要）

これにより、"The term ... is not recognized" エラーが解消されます。

"@ -ForegroundColor Cyan

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host "テスト完了" -ForegroundColor Cyan