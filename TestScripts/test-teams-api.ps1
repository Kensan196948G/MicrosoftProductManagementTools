#!/usr/bin/env pwsh
<#
.SYNOPSIS
Microsoft Teams API接続テスト

.DESCRIPTION
Microsoft Graph APIを使用してTeams関連の機能をテストします。

.EXAMPLE
TestScripts/test-teams-api.ps1
#>

# 開始時間を記録
$testStartTime = Get-Date
Write-Host "🧪 Teams API テストを開始します..." -ForegroundColor Green
Write-Host "開始時間: $($testStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan

# 共通モジュールの読み込み
$commonPath = Join-Path $PSScriptRoot "..\Scripts\Common\RealM365DataProvider.psm1"
if (Test-Path $commonPath) {
    try {
        Import-Module $commonPath -Force -ErrorAction Stop
        Write-Host "✅ RealM365DataProvider モジュール読み込み成功" -ForegroundColor Green
    } catch {
        Write-Host "❌ モジュール読み込み失敗: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ RealM365DataProvider モジュールが見つかりません: $commonPath" -ForegroundColor Red
    exit 1
}

# テスト結果を格納する配列
$testResults = @()

# テスト1: Microsoft Graph接続状態確認
Write-Host "`n🔍 テスト1: Microsoft Graph接続状態確認" -ForegroundColor Yellow
try {
    $authResult = Test-M365Authentication
    if ($authResult -and $authResult.GraphConnected) {
        Write-Host "✅ Microsoft Graph: 接続成功" -ForegroundColor Green
        $testResults += [PSCustomObject]@{
            テスト項目 = "Microsoft Graph接続"
            結果 = "成功"
            詳細 = "正常に接続されています"
        }
    } else {
        Write-Host "❌ Microsoft Graph: 接続失敗" -ForegroundColor Red
        $testResults += [PSCustomObject]@{
            テスト項目 = "Microsoft Graph接続"
            結果 = "失敗"
            詳細 = "Graph APIに接続できません"
        }
    }
} catch {
    Write-Host "❌ Graph接続テストエラー: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += [PSCustomObject]@{
        テスト項目 = "Microsoft Graph接続"
        結果 = "エラー"
        詳細 = $_.Exception.Message
    }
}

# テスト2: ユーザー情報取得テスト
Write-Host "`n🔍 テスト2: Microsoft Graph ユーザー情報取得" -ForegroundColor Yellow
try {
    if (Get-Command Get-MgUser -ErrorAction SilentlyContinue) {
        $users = Get-MgUser -Top 3 -ErrorAction SilentlyContinue
        if ($users -and $users.Count -gt 0) {
            Write-Host "✅ ユーザー情報取得成功: $($users.Count) 件" -ForegroundColor Green
            foreach ($user in $users) {
                Write-Host "  - $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Cyan
            }
            $testResults += [PSCustomObject]@{
                テスト項目 = "ユーザー情報取得"
                結果 = "成功"
                詳細 = "$($users.Count) 件のユーザー情報を取得"
            }
        } else {
            Write-Host "❌ ユーザー情報取得失敗: データなし" -ForegroundColor Red
            $testResults += [PSCustomObject]@{
                テスト項目 = "ユーザー情報取得"
                結果 = "失敗"
                詳細 = "ユーザーデータが取得できません"
            }
        }
    } else {
        Write-Host "❌ Get-MgUser コマンドレットが見つかりません" -ForegroundColor Red
        $testResults += [PSCustomObject]@{
            テスト項目 = "ユーザー情報取得"
            結果 = "失敗"
            詳細 = "Microsoft Graph PowerShell モジュールが不足"
        }
    }
} catch {
    Write-Host "❌ ユーザー情報取得エラー: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += [PSCustomObject]@{
        テスト項目 = "ユーザー情報取得"
        結果 = "エラー"
        詳細 = $_.Exception.Message
    }
}

# テスト3: Teams チーム情報取得テスト
Write-Host "`n🔍 テスト3: Microsoft Teams チーム情報取得" -ForegroundColor Yellow
try {
    if (Get-Command Get-MgGroup -ErrorAction SilentlyContinue) {
        $teams = Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -Top 3 -ErrorAction SilentlyContinue
        if ($teams -and $teams.Count -gt 0) {
            Write-Host "✅ Teams チーム情報取得成功: $($teams.Count) 件" -ForegroundColor Green
            foreach ($team in $teams) {
                Write-Host "  - $($team.DisplayName) (ID: $($team.Id))" -ForegroundColor Cyan
            }
            $testResults += [PSCustomObject]@{
                テスト項目 = "Teams チーム情報取得"
                結果 = "成功"
                詳細 = "$($teams.Count) 件のチーム情報を取得"
            }
        } else {
            Write-Host "⚠️ Teams チーム情報取得: データなし（権限またはチームが存在しない可能性）" -ForegroundColor Yellow
            $testResults += [PSCustomObject]@{
                テスト項目 = "Teams チーム情報取得"
                結果 = "警告"
                詳細 = "チームデータが見つかりません（権限またはデータの問題）"
            }
        }
    } else {
        Write-Host "❌ Get-MgGroup コマンドレットが見つかりません" -ForegroundColor Red
        $testResults += [PSCustomObject]@{
            テスト項目 = "Teams チーム情報取得"
            結果 = "失敗"
            詳細 = "Microsoft Graph PowerShell モジュールが不足"
        }
    }
} catch {
    Write-Host "❌ Teams チーム情報取得エラー: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += [PSCustomObject]@{
        テスト項目 = "Teams チーム情報取得"
        結果 = "エラー"
        詳細 = $_.Exception.Message
    }
}

# テスト4: Teams 使用状況取得テスト
Write-Host "`n🔍 テスト4: Teams 使用状況データ取得" -ForegroundColor Yellow
try {
    if (Get-Command Get-M365TeamsUsage -ErrorAction SilentlyContinue) {
        $teamsUsage = Get-M365TeamsUsage
        if ($teamsUsage -and $teamsUsage.Count -gt 0) {
            Write-Host "✅ Teams 使用状況取得成功: $($teamsUsage.Count) 件" -ForegroundColor Green
            $testResults += [PSCustomObject]@{
                テスト項目 = "Teams 使用状況取得"
                結果 = "成功"
                詳細 = "$($teamsUsage.Count) 件の使用状況データを取得"
            }
        } else {
            Write-Host "❌ Teams 使用状況取得失敗: データなし" -ForegroundColor Red
            $testResults += [PSCustomObject]@{
                テスト項目 = "Teams 使用状況取得"
                結果 = "失敗"
                詳細 = "使用状況データが取得できません"
            }
        }
    } else {
        Write-Host "⚠️ Get-M365TeamsUsage 関数が見つかりません" -ForegroundColor Yellow
        $testResults += [PSCustomObject]@{
            テスト項目 = "Teams 使用状況取得"
            結果 = "警告"
            詳細 = "専用データプロバイダー関数が見つかりません"
        }
    }
} catch {
    Write-Host "❌ Teams 使用状況取得エラー: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += [PSCustomObject]@{
        テスト項目 = "Teams 使用状況取得"
        結果 = "エラー"
        詳細 = $_.Exception.Message
    }
}

# テスト5: Teams 設定確認テスト
Write-Host "`n🔍 テスト5: Teams 設定確認" -ForegroundColor Yellow
try {
    if (Get-Command Get-MgOrganization -ErrorAction SilentlyContinue) {
        $orgSettings = Get-MgOrganization -ErrorAction SilentlyContinue
        if ($orgSettings) {
            Write-Host "✅ 組織設定取得成功: $($orgSettings.DisplayName)" -ForegroundColor Green
            $testResults += [PSCustomObject]@{
                テスト項目 = "Teams 設定確認"
                結果 = "成功"
                詳細 = "組織設定の取得が可能"
            }
        } else {
            Write-Host "❌ 組織設定取得失敗" -ForegroundColor Red
            $testResults += [PSCustomObject]@{
                テスト項目 = "Teams 設定確認"
                結果 = "失敗"
                詳細 = "組織設定データが取得できません"
            }
        }
    } else {
        Write-Host "❌ Get-MgOrganization コマンドレットが見つかりません" -ForegroundColor Red
        $testResults += [PSCustomObject]@{
            テスト項目 = "Teams 設定確認"
            結果 = "失敗"
            詳細 = "Microsoft Graph PowerShell モジュールが不足"
        }
    }
} catch {
    Write-Host "❌ Teams 設定確認エラー: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += [PSCustomObject]@{
        テスト項目 = "Teams 設定確認"
        結果 = "エラー"
        詳細 = $_.Exception.Message
    }
}

# テスト結果の集計
$testEndTime = Get-Date
$testDuration = $testEndTime - $testStartTime

Write-Host "`n" -NoNewline
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "🧪 Teams API テスト結果サマリー" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan

$successCount = ($testResults | Where-Object { $_.結果 -eq "成功" }).Count
$warningCount = ($testResults | Where-Object { $_.結果 -eq "警告" }).Count
$failureCount = ($testResults | Where-Object { $_.結果 -eq "失敗" }).Count
$errorCount = ($testResults | Where-Object { $_.結果 -eq "エラー" }).Count

Write-Host "📊 テスト実行統計:" -ForegroundColor Yellow
Write-Host "  ✅ 成功: $successCount 件" -ForegroundColor Green
Write-Host "  ⚠️ 警告: $warningCount 件" -ForegroundColor Yellow  
Write-Host "  ❌ 失敗: $failureCount 件" -ForegroundColor Red
Write-Host "  🚫 エラー: $errorCount 件" -ForegroundColor Red
Write-Host "  ⏱️ 実行時間: $($testDuration.TotalSeconds.ToString('F2')) 秒" -ForegroundColor Cyan

Write-Host "`n📋 詳細テスト結果:" -ForegroundColor Yellow
$testResults | Format-Table -AutoSize

# レポートファイル出力
$reportDir = Join-Path $PSScriptRoot "TestReports"
if (-not (Test-Path $reportDir)) {
    New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvPath = Join-Path $reportDir "teams-api-test_$timestamp.csv"
$htmlPath = Join-Path $reportDir "teams-api-test_$timestamp.html"

# CSV出力
try {
    $testResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8BOM
    Write-Host "📄 CSVレポート出力: $csvPath" -ForegroundColor Green
} catch {
    Write-Host "❌ CSVレポート出力エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# HTML出力
try {
    $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Teams API テスト結果</title>
    <style>
        body { font-family: 'Yu Gothic UI', 'Segoe UI', sans-serif; margin: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; }
        .summary { background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 20px 0; }
        .success { color: #28a745; font-weight: bold; }
        .warning { color: #ffc107; font-weight: bold; }
        .error { color: #dc3545; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .timestamp { text-align: center; color: #666; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 Microsoft Teams API テスト結果</h1>
        <p>実行日時: $($testStartTime.ToString('yyyy年MM月dd日 HH:mm:ss'))</p>
    </div>
    
    <div class="summary">
        <h2>📊 テスト実行統計</h2>
        <p><span class="success">✅ 成功: $successCount 件</span></p>
        <p><span class="warning">⚠️ 警告: $warningCount 件</span></p>
        <p><span class="error">❌ 失敗: $failureCount 件</span></p>
        <p><span class="error">🚫 エラー: $errorCount 件</span></p>
        <p><strong>⏱️ 実行時間: $($testDuration.TotalSeconds.ToString('F2')) 秒</strong></p>
    </div>
    
    <h2>📋 詳細テスト結果</h2>
    <table>
        <tr>
            <th>テスト項目</th>
            <th>結果</th>
            <th>詳細</th>
        </tr>
"@

    foreach ($result in $testResults) {
        $statusClass = switch ($result.結果) {
            "成功" { "success" }
            "警告" { "warning" }
            default { "error" }
        }
        $statusIcon = switch ($result.結果) {
            "成功" { "✅" }
            "警告" { "⚠️" }
            "失敗" { "❌" }
            "エラー" { "🚫" }
        }
        
        $htmlContent += @"
        <tr>
            <td>$($result.テスト項目)</td>
            <td class="$statusClass">$statusIcon $($result.結果)</td>
            <td>$($result.詳細)</td>
        </tr>
"@
    }

    $htmlContent += @"
    </table>
    
    <div class="timestamp">
        <p>Microsoft 365統合管理ツール - Teams API テスト<br>
        生成日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</p>
    </div>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
    Write-Host "📄 HTMLレポート出力: $htmlPath" -ForegroundColor Green
    
    # HTMLファイルを自動で開く
    try {
        Start-Process $htmlPath
        Write-Host "🌐 HTMLレポートを開きました" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ HTMLレポート自動表示エラー: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ HTMLレポート出力エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 終了メッセージ
Write-Host "`n🏁 Teams API テストが完了しました。" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan

# 終了コード設定（失敗またはエラーがある場合は非0）
if ($failureCount -gt 0 -or $errorCount -gt 0) {
    exit 1
} else {
    exit 0
}