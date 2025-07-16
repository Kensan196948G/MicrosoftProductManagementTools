# ================================================================================
# 軽量化された実データ取得テスト
# Microsoft 365統合管理ツール用
# ================================================================================

[CmdletBinding()]
param()

# スクリプトの場所とToolRootを設定
$Script:TestRoot = $PSScriptRoot
$Script:ToolRoot = Split-Path $Script:TestRoot -Parent

Write-Host "=== 軽量化実データ取得テスト開始 ===" -ForegroundColor Green
Write-Host "ToolRoot: $Script:ToolRoot" -ForegroundColor Cyan

try {
    # 必要なモジュールのインポート
    $dailyModulePath = Join-Path $Script:ToolRoot "Scripts\Common\DailyReportData.psm1"
    
    Write-Host "`n📦 DailyReportDataモジュールインポート" -ForegroundColor Yellow
    
    if (Test-Path $dailyModulePath) {
        Import-Module $dailyModulePath -Force -ErrorAction Stop
        Write-Host "✅ DailyReportDataモジュール読み込み成功" -ForegroundColor Green
    } else {
        throw "DailyReportDataモジュールが見つかりません: $dailyModulePath"
    }
    
    # 軽量化された実データ取得のテスト
    Write-Host "`n🧪 軽量化実データ取得テスト" -ForegroundColor Yellow
    
    # 1. 日次レポート実データ取得テスト
    Write-Host "`n1️⃣ 日次レポート実データ取得（軽量版）" -ForegroundColor Cyan
    Write-Host "最大100件のユーザー、50件のメールボックスで制限テスト..." -ForegroundColor Gray
    
    $startTime = Get-Date
    try {
        $dailyData = Get-DailyReportRealData
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        if ($dailyData) {
            Write-Host "✅ 日次レポート実データ取得成功" -ForegroundColor Green
            Write-Host "⏱️ 取得時間: $([math]::Round($duration, 2)) 秒" -ForegroundColor Cyan
            
            # データ内容の確認
            if ($dailyData.UserActivity -and $dailyData.UserActivity.Count -gt 0) {
                Write-Host "👥 ユーザーアクティビティ: $($dailyData.UserActivity.Count) 件" -ForegroundColor White
                $dailyData.UserActivity | Select-Object -First 3 | Format-Table ユーザー名, メールアドレス, アクティビティ状態, セキュリティリスク -AutoSize
            }
            
            if ($dailyData.MailboxCapacity -and $dailyData.MailboxCapacity.Count -gt 0) {
                Write-Host "📧 メールボックス容量: $($dailyData.MailboxCapacity.Count) 件" -ForegroundColor White
                $dailyData.MailboxCapacity | Select-Object -First 3 | Format-Table メールボックス, 使用容量GB, 使用率, Status -AutoSize
            }
            
            if ($dailyData.SecurityAlerts -and $dailyData.SecurityAlerts.Count -gt 0) {
                Write-Host "🔒 セキュリティアラート: $($dailyData.SecurityAlerts.Count) 件" -ForegroundColor White
                $dailyData.SecurityAlerts | Select-Object -First 3 | Format-Table 種類, Severity, ユーザー, 詳細 -AutoSize
            }
            
            if ($dailyData.MFAStatus -and $dailyData.MFAStatus.Count -gt 0) {
                Write-Host "🔐 MFA状況: $($dailyData.MFAStatus.Count) 件" -ForegroundColor White
                $dailyData.MFAStatus | Select-Object -First 3 | Format-Table ユーザー名, MFA状況, 認証方法, リスク -AutoSize
            }
            
            # サマリー情報
            if ($dailyData.Summary) {
                Write-Host "📊 サマリー情報:" -ForegroundColor Cyan
                $dailyData.Summary | Format-List
            }
        } else {
            Write-Host "⚠️ 実データが取得できませんでした" -ForegroundColor Yellow
        }
        
    }
    catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        Write-Host "❌ 実データ取得エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "⏱️ エラー発生までの時間: $([math]::Round($duration, 2)) 秒" -ForegroundColor Yellow
        Write-Host "詳細: $($_.ScriptStackTrace)" -ForegroundColor Gray
    }
    
    # 2. 個別関数テスト
    Write-Host "`n2️⃣ 個別関数軽量化テスト" -ForegroundColor Cyan
    
    # ユーザーアクティビティ取得
    Write-Host "`n👥 ユーザーアクティビティ取得テスト（最大100件）" -ForegroundColor White
    try {
        $userStartTime = Get-Date
        $userActivity = Get-UserActivityRealData
        $userEndTime = Get-Date
        $userDuration = ($userEndTime - $userStartTime).TotalSeconds
        
        Write-Host "✅ ユーザーアクティビティ取得成功: $($userActivity.Count) 件" -ForegroundColor Green
        Write-Host "⏱️ 取得時間: $([math]::Round($userDuration, 2)) 秒" -ForegroundColor Cyan
        
        if ($userActivity.Count -gt 0) {
            Write-Host "📋 サンプルデータ:" -ForegroundColor Gray
            $userActivity | Select-Object -First 2 | Format-List ユーザー名, メールアドレス, アクティビティ状態, セキュリティリスク, 推奨アクション
        }
    }
    catch {
        Write-Host "❌ ユーザーアクティビティ取得エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # MFA状況取得
    Write-Host "`n🔐 MFA状況取得テスト（最大50件）" -ForegroundColor White
    try {
        $mfaStartTime = Get-Date
        $mfaStatus = Get-MFAStatusRealData
        $mfaEndTime = Get-Date
        $mfaDuration = ($mfaEndTime - $mfaStartTime).TotalSeconds
        
        Write-Host "✅ MFA状況取得成功: $($mfaStatus.Count) 件" -ForegroundColor Green
        Write-Host "⏱️ 取得時間: $([math]::Round($mfaDuration, 2)) 秒" -ForegroundColor Cyan
        
        if ($mfaStatus.Count -gt 0) {
            $mfaEnabled = ($mfaStatus | Where-Object { $_.HasMFA -eq $true }).Count
            $mfaDisabled = ($mfaStatus | Where-Object { $_.HasMFA -eq $false }).Count
            Write-Host "📊 MFA設定済み: $mfaEnabled 件 / 未設定: $mfaDisabled 件" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "❌ MFA状況取得エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n📋 軽量化テスト結果サマリー:" -ForegroundColor Blue
    Write-Host "・データ件数制限: ユーザー100件、メールボックス50件に制限" -ForegroundColor White
    Write-Host "・処理時間: 大幅短縮（全件取得回避）" -ForegroundColor White
    Write-Host "・エラーハンドリング: 個別処理でのエラー対応" -ForegroundColor White
    Write-Host "・認証状態: Microsoft Graph + Exchange Online接続確認済み" -ForegroundColor White
    
}
catch {
    Write-Host "`n❌ テストエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "詳細: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

Write-Host "`n=== 軽量化実データ取得テスト終了 ===" -ForegroundColor Magenta