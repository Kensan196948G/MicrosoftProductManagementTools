#!/usr/bin/env pwsh
<#
.SYNOPSIS
Microsoft 365 接続テスト

.DESCRIPTION
Microsoft 365各サービス（Microsoft Graph、Exchange Online）への接続状態をテストします。

.EXAMPLE
TestScripts/test-connection.ps1
#>

# 開始時間を記録
$testStartTime = Get-Date
Write-Host "🧪 Microsoft 365 接続テストを開始します..." -ForegroundColor Green
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

# テスト1: Microsoft Graph接続テスト
Write-Host "`n🔍 テスト1: Microsoft Graph 接続状態確認" -ForegroundColor Yellow
try {
    $authResult = Test-M365Authentication
    if ($authResult) {
        if ($authResult.GraphConnected) {
            Write-Host "✅ Microsoft Graph: 接続成功" -ForegroundColor Green
            $testResults += [PSCustomObject]@{
                サービス = "Microsoft Graph"
                接続状態 = "成功"
                詳細 = "正常に接続されています"
                テスト時刻 = (Get-Date).ToString("HH:mm:ss")
            }
        } else {
            Write-Host "❌ Microsoft Graph: 接続失敗" -ForegroundColor Red
            $testResults += [PSCustomObject]@{
                サービス = "Microsoft Graph"
                接続状態 = "失敗"
                詳細 = "認証エラーまたはセッション未確立"
                テスト時刻 = (Get-Date).ToString("HH:mm:ss")
            }
        }
        
        if ($authResult.ExchangeConnected) {
            Write-Host "✅ Exchange Online: 接続成功" -ForegroundColor Green
            $testResults += [PSCustomObject]@{
                サービス = "Exchange Online"
                接続状態 = "成功"
                詳細 = "正常に接続されています"
                テスト時刻 = (Get-Date).ToString("HH:mm:ss")
            }
        } else {
            Write-Host "❌ Exchange Online: 接続失敗" -ForegroundColor Red
            $testResults += [PSCustomObject]@{
                サービス = "Exchange Online"
                接続状態 = "失敗"
                詳細 = "認証エラーまたはセッション未確立"
                テスト時刻 = (Get-Date).ToString("HH:mm:ss")
            }
        }
    } else {
        Write-Host "❌ 認証テスト自体が失敗しました" -ForegroundColor Red
        $testResults += [PSCustomObject]@{
            サービス = "認証システム"
            接続状態 = "エラー"
            詳細 = "Test-M365Authentication関数の実行に失敗"
            テスト時刻 = (Get-Date).ToString("HH:mm:ss")
        }
    }
} catch {
    Write-Host "❌ 接続テストエラー: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += [PSCustomObject]@{
        サービス = "接続テスト"
        接続状態 = "エラー"
        詳細 = $_.Exception.Message
        テスト時刻 = (Get-Date).ToString("HH:mm:ss")
    }
}

# テスト2: PowerShellモジュール確認
Write-Host "`n🔍 テスト2: 必要なPowerShellモジュール確認" -ForegroundColor Yellow
$requiredModules = @(
    "Microsoft.Graph.Users",
    "Microsoft.Graph.Groups", 
    "Microsoft.Graph.Reports",
    "ExchangeOnlineManagement"
)

foreach ($moduleName in $requiredModules) {
    try {
        $module = Get-Module $moduleName -ListAvailable -ErrorAction SilentlyContinue
        if ($module) {
            Write-Host "✅ $moduleName : インストール済み (Ver: $($module[0].Version))" -ForegroundColor Green
            $testResults += [PSCustomObject]@{
                サービス = $moduleName
                接続状態 = "利用可能"
                詳細 = "バージョン: $($module[0].Version)"
                テスト時刻 = (Get-Date).ToString("HH:mm:ss")
            }
        } else {
            Write-Host "❌ $moduleName : 未インストール" -ForegroundColor Red
            $testResults += [PSCustomObject]@{
                サービス = $moduleName
                接続状態 = "未インストール"
                詳細 = "PowerShellモジュールが見つかりません"
                テスト時刻 = (Get-Date).ToString("HH:mm:ss")
            }
        }
    } catch {
        Write-Host "❌ $moduleName : 確認エラー - $($_.Exception.Message)" -ForegroundColor Red
        $testResults += [PSCustomObject]@{
            サービス = $moduleName
            接続状態 = "エラー"
            詳細 = $_.Exception.Message
            テスト時刻 = (Get-Date).ToString("HH:mm:ss")
        }
    }
}

# テスト3: 簡単なAPIコール テスト
Write-Host "`n🔍 テスト3: 基本的なAPIコール テスト" -ForegroundColor Yellow
try {
    if (Get-Command Get-MgUser -ErrorAction SilentlyContinue) {
        $users = Get-MgUser -Top 1 -ErrorAction SilentlyContinue
        if ($users) {
            Write-Host "✅ Microsoft Graph API: 基本的なユーザー取得成功" -ForegroundColor Green
            $testResults += [PSCustomObject]@{
                サービス = "Graph API Call"
                接続状態 = "成功"
                詳細 = "ユーザーデータ取得可能"
                テスト時刻 = (Get-Date).ToString("HH:mm:ss")
            }
        } else {
            Write-Host "⚠️ Microsoft Graph API: ユーザー取得結果が空" -ForegroundColor Yellow
            $testResults += [PSCustomObject]@{
                サービス = "Graph API Call"
                接続状態 = "警告"
                詳細 = "APIコールは成功したがデータが空"
                テスト時刻 = (Get-Date).ToString("HH:mm:ss")
            }
        }
    } else {
        Write-Host "❌ Get-MgUser コマンドレットが見つかりません" -ForegroundColor Red
        $testResults += [PSCustomObject]@{
            サービス = "Graph API Call"
            接続状態 = "失敗"
            詳細 = "Microsoft Graph PowerShell モジュールが不足"
            テスト時刻 = (Get-Date).ToString("HH:mm:ss")
        }
    }
} catch {
    Write-Host "❌ Graph APIコールエラー: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += [PSCustomObject]@{
        サービス = "Graph API Call"
        接続状態 = "エラー"
        詳細 = $_.Exception.Message
        テスト時刻 = (Get-Date).ToString("HH:mm:ss")
    }
}

# テスト4: Exchange Online基本コール テスト
Write-Host "`n🔍 テスト4: Exchange Online 基本コール テスト" -ForegroundColor Yellow
try {
    if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
        $exchangeSession = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if ($exchangeSession) {
            Write-Host "✅ Exchange Online: セッション確認成功" -ForegroundColor Green
            Write-Host "   組織: $($exchangeSession.Organization)" -ForegroundColor Cyan
            $testResults += [PSCustomObject]@{
                サービス = "Exchange Online Session"
                接続状態 = "成功"
                詳細 = "組織: $($exchangeSession.Organization)"
                テスト時刻 = (Get-Date).ToString("HH:mm:ss")
            }
        } else {
            Write-Host "❌ Exchange Online: セッション未確立" -ForegroundColor Red
            $testResults += [PSCustomObject]@{
                サービス = "Exchange Online Session"
                接続状態 = "失敗"
                詳細 = "Exchange Onlineセッションが確立されていません"
                テスト時刻 = (Get-Date).ToString("HH:mm:ss")
            }
        }
    } else {
        Write-Host "❌ Get-ConnectionInformation コマンドレットが見つかりません" -ForegroundColor Red
        $testResults += [PSCustomObject]@{
            サービス = "Exchange Online Session"
            接続状態 = "失敗"
            詳細 = "Exchange Online PowerShell モジュールが不足"
            テスト時刻 = (Get-Date).ToString("HH:mm:ss")
        }
    }
} catch {
    Write-Host "❌ Exchange Onlineセッション確認エラー: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += [PSCustomObject]@{
        サービス = "Exchange Online Session"
        接続状態 = "エラー"
        詳細 = $_.Exception.Message
        テスト時刻 = (Get-Date).ToString("HH:mm:ss")
    }
}

# テスト結果の集計
$testEndTime = Get-Date
$testDuration = $testEndTime - $testStartTime

Write-Host "`n" -NoNewline
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "🧪 Microsoft 365 接続テスト結果サマリー" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan

$successCount = ($testResults | Where-Object { $_.接続状態 -eq "成功" -or $_.接続状態 -eq "利用可能" }).Count
$warningCount = ($testResults | Where-Object { $_.接続状態 -eq "警告" }).Count
$failureCount = ($testResults | Where-Object { $_.接続状態 -eq "失敗" -or $_.接続状態 -eq "未インストール" }).Count
$errorCount = ($testResults | Where-Object { $_.接続状態 -eq "エラー" }).Count

Write-Host "📊 接続テスト統計:" -ForegroundColor Yellow
Write-Host "  ✅ 成功: $successCount 件" -ForegroundColor Green
Write-Host "  ⚠️ 警告: $warningCount 件" -ForegroundColor Yellow
Write-Host "  ❌ 失敗: $failureCount 件" -ForegroundColor Red
Write-Host "  🚫 エラー: $errorCount 件" -ForegroundColor Red
Write-Host "  ⏱️ 実行時間: $($testDuration.TotalSeconds.ToString('F2')) 秒" -ForegroundColor Cyan

Write-Host "`n📋 詳細接続結果:" -ForegroundColor Yellow
$testResults | Format-Table -AutoSize

# レポートファイル出力
$reportDir = Join-Path $PSScriptRoot "TestReports"
if (-not (Test-Path $reportDir)) {
    New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvPath = Join-Path $reportDir "connection-test_$timestamp.csv"
$htmlPath = Join-Path $reportDir "connection-test_$timestamp.html"

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
    <title>Microsoft 365 接続テスト結果</title>
    <style>
        body { font-family: 'Yu Gothic UI', 'Segoe UI', sans-serif; margin: 20px; }
        .header { background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; }
        .summary { background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 20px 0; }
        .success { color: #28a745; font-weight: bold; }
        .warning { color: #ffc107; font-weight: bold; }
        .error { color: #dc3545; font-weight: bold; }
        .available { color: #17a2b8; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .timestamp { text-align: center; color: #666; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🌐 Microsoft 365 接続テスト結果</h1>
        <p>実行日時: $($testStartTime.ToString('yyyy年MM月dd日 HH:mm:ss'))</p>
    </div>
    
    <div class="summary">
        <h2>📊 接続テスト統計</h2>
        <p><span class="success">✅ 成功: $successCount 件</span></p>
        <p><span class="warning">⚠️ 警告: $warningCount 件</span></p>
        <p><span class="error">❌ 失敗: $failureCount 件</span></p>
        <p><span class="error">🚫 エラー: $errorCount 件</span></p>
        <p><strong>⏱️ 実行時間: $($testDuration.TotalSeconds.ToString('F2')) 秒</strong></p>
    </div>
    
    <h2>📋 詳細接続結果</h2>
    <table>
        <tr>
            <th>サービス</th>
            <th>接続状態</th>
            <th>詳細</th>
            <th>テスト時刻</th>
        </tr>
"@

    foreach ($result in $testResults) {
        $statusClass = switch ($result.接続状態) {
            "成功" { "success" }
            "利用可能" { "available" }
            "警告" { "warning" }
            default { "error" }
        }
        $statusIcon = switch ($result.接続状態) {
            "成功" { "✅" }
            "利用可能" { "💡" }
            "警告" { "⚠️" }
            "失敗" { "❌" }
            "未インストール" { "❌" }
            "エラー" { "🚫" }
        }
        
        $htmlContent += @"
        <tr>
            <td>$($result.サービス)</td>
            <td class="$statusClass">$statusIcon $($result.接続状態)</td>
            <td>$($result.詳細)</td>
            <td>$($result.テスト時刻)</td>
        </tr>
"@
    }

    $htmlContent += @"
    </table>
    
    <div class="timestamp">
        <p>Microsoft 365統合管理ツール - 接続テスト<br>
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
Write-Host "`n🏁 Microsoft 365 接続テストが完了しました。" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan

# 終了コード設定（失敗またはエラーがある場合は非0）
if ($failureCount -gt 0 -or $errorCount -gt 0) {
    exit 1
} else {
    exit 0
}