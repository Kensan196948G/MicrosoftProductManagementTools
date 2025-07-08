# ================================================================================
# MailDeliveryAnalysis.ps1
# Exchange Online メール配信分析スクリプト（実データ対応版）
# ITSM/ISO27001/27002準拠 - メール配信状況・エラー分析
# ================================================================================

function Get-MailDeliveryAnalysis {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 7,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Exchange\Delivery",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeDetailedAnalysis = $true,
        
        [Parameter(Mandatory = $false)]
        [int]$SampleSize = 1000
    )
    
    try {
        Write-Host "📧 Exchange Online メール配信分析を開始します（過去 $DaysBack 日間）" -ForegroundColor Cyan
        
        # 前提条件チェック
        if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
            Write-Host "❌ ExchangeOnlineManagementモジュールがインストールされていません" -ForegroundColor Red
            return $null
        }
        
        # Exchange Online接続確認と自動接続
        $exchangeConnected = $false
        try {
            $sessions = Get-PSSession | Where-Object { $_.ComputerName -like "*outlook.office365.com*" -and $_.State -eq "Opened" }
            if (-not $sessions) {
                Write-Host "⚠️ Exchange Onlineに接続されていません。自動接続を試行します..." -ForegroundColor Yellow
                
                # 設定ファイルから認証情報を読み込み
                $configPath = Join-Path $PWD "Config\appsettings.json"
                if (Test-Path $configPath) {
                    $config = Get-Content $configPath | ConvertFrom-Json
                    $exchangeConfig = $config.ExchangeOnline
                    
                    Write-Host "🔐 証明書ベース認証でExchange Onlineに接続中..." -ForegroundColor Cyan
                    
                    try {
                        # 証明書ファイルから証明書を読み込み
                        $certPath = $exchangeConfig.CertificatePath
                        $certPassword = ConvertTo-SecureString $exchangeConfig.CertificatePassword -AsPlainText -Force
                        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $certPassword)
                        
                        Connect-ExchangeOnline -AppId $exchangeConfig.AppId -Certificate $cert -Organization $exchangeConfig.Organization -ShowBanner:$false
                        $exchangeConnected = $true
                        Write-Host "✅ Exchange Onlineに正常に接続しました" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "❌ Exchange Online接続エラー: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "📊 サンプルデータを使用して分析を生成します..." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "❌ 設定ファイルが見つかりません: $configPath" -ForegroundColor Red
                    Write-Host "📊 サンプルデータを使用して分析を生成します..." -ForegroundColor Yellow
                }
            } else {
                $exchangeConnected = $true
                Write-Host "✅ Exchange Onlineに接続済みです" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "❌ Exchange Online接続確認でエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "📊 サンプルデータを使用して分析を生成します..." -ForegroundColor Yellow
        }
        
        # Exchange Onlineの制限：メッセージトレースは過去10日以内のみ
        $maxDaysBack = 10
        if ($DaysBack -gt $maxDaysBack) {
            Write-Host "⚠️ Exchange Onlineの制限により、分析期間を過去${maxDaysBack}日間に調整します" -ForegroundColor Yellow
            $DaysBack = $maxDaysBack
        }
        
        $startDate = (Get-Date).AddDays(-$DaysBack)
        $endDate = Get-Date
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        # 出力ディレクトリの作成
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
        
        $deliveryReport = @()
        $errorReport = @()
        $summaryStats = @{}
        
        if ($exchangeConnected) {
            try {
                Write-Host "🔍 メール配信トレースを取得中..." -ForegroundColor Cyan
                Write-Host "  📋 過去${DaysBack}日間のメッセージトレースを分析中（最大${SampleSize}件）..." -ForegroundColor Gray
                
                # メッセージトレースを取得（配信状況分析）
                $messageTrace = Get-MessageTrace -StartDate $startDate -EndDate $endDate -PageSize $SampleSize -ErrorAction Stop
                Write-Host "  ✅ $($messageTrace.Count) 件のメッセージトレースを取得しました" -ForegroundColor Green
                
                # 配信状況統計の計算
                $statusCounts = $messageTrace | Group-Object Status | ForEach-Object {
                    [PSCustomObject]@{
                        Status = $_.Name
                        Count = $_.Count
                        Percentage = [math]::Round(($_.Count / $messageTrace.Count) * 100, 2)
                    }
                }
                
                # 配信エラー詳細分析
                $failedMessages = $messageTrace | Where-Object { $_.Status -in @("Failed", "FilteredAsSpam", "Quarantined") }
                
                Write-Host "  📊 配信統計: 成功 $($statusCounts | Where-Object Status -eq 'Delivered' | ForEach-Object Count) 件, 失敗 $($failedMessages.Count) 件" -ForegroundColor Gray
                
                # 配信レポート生成
                foreach ($message in $messageTrace) {
                    $deliveryReport += [PSCustomObject]@{
                        受信日時 = $message.Received.ToString("yyyy-MM-dd HH:mm:ss")
                        送信者 = $message.SenderAddress
                        受信者 = $message.RecipientAddress
                        件名 = $message.Subject
                        配信状況 = $message.Status
                        メッセージサイズMB = [math]::Round($message.Size / 1MB, 2)
                        遅延時間秒 = if ($message.Received -and $message.Received) { 
                            [math]::Round(($message.Received - $message.Received).TotalSeconds, 2) 
                        } else { 0 }
                        メッセージID = $message.MessageId
                        分析日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
                
                # エラー詳細レポート
                foreach ($failedMsg in $failedMessages) {
                    # 詳細トレースを取得（エラーメッセージ用）
                    try {
                        $detailTrace = Get-MessageTraceDetail -MessageTraceId $failedMsg.MessageTraceId -RecipientAddress $failedMsg.RecipientAddress -ErrorAction SilentlyContinue
                        $errorDetail = if ($detailTrace) { $detailTrace.Detail -join "; " } else { "詳細不明" }
                    } catch {
                        $errorDetail = "詳細取得エラー"
                    }
                    
                    $errorReport += [PSCustomObject]@{
                        エラー発生日時 = $failedMsg.Received.ToString("yyyy-MM-dd HH:mm:ss")
                        送信者 = $failedMsg.SenderAddress
                        受信者 = $failedMsg.RecipientAddress
                        件名 = $failedMsg.Subject
                        エラータイプ = $failedMsg.Status
                        エラー詳細 = $errorDetail
                        メッセージサイズMB = [math]::Round($failedMsg.Size / 1MB, 2)
                        メッセージID = $failedMsg.MessageId
                        分析日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
                
                # 統計サマリー
                $summaryStats = @{
                    総メッセージ数 = $messageTrace.Count
                    成功配信数 = ($messageTrace | Where-Object Status -eq "Delivered").Count
                    配信失敗数 = $failedMessages.Count
                    成功率パーセント = [math]::Round((($messageTrace | Where-Object Status -eq "Delivered").Count / $messageTrace.Count) * 100, 2)
                    平均メッセージサイズMB = [math]::Round(($messageTrace | Measure-Object Size -Average).Average / 1MB, 2)
                    分析期間日数 = $DaysBack
                    最新データ取得時刻 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    データソース = "Exchange Online API (実データ)"
                }
                
                Write-Host "✅ 実データからメール配信分析が完了しました" -ForegroundColor Green
                
            } catch {
                Write-Host "❌ 実データ取得エラー: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "📊 サンプルデータで分析を生成します..." -ForegroundColor Yellow
                $exchangeConnected = $false
            }
        }
        
        # 実データ取得に失敗した場合のサンプルデータ生成
        if (-not $exchangeConnected -or $deliveryReport.Count -eq 0) {
            Write-Host "📊 サンプルデータでメール配信分析を生成中..." -ForegroundColor Yellow
            
            # 現実的なサンプルデータ生成
            $sampleCount = 500
            $domains = @("example.com", "contoso.com", "fabrikam.com", "northwind.com", "adventure-works.com")
            $statuses = @(
                @{Status="Delivered"; Weight=85},
                @{Status="Failed"; Weight=8},
                @{Status="FilteredAsSpam"; Weight=4},
                @{Status="Quarantined"; Weight=2},
                @{Status="Pending"; Weight=1}
            )
            
            for ($i = 1; $i -le $sampleCount; $i++) {
                $randomDate = (Get-Date).AddHours(-([System.Random]::new().Next(0, $DaysBack * 24)))
                $randomDomain = $domains | Get-Random
                $weightedStatus = $statuses | Get-Random
                
                # サンプル配信データ
                $deliveryReport += [PSCustomObject]@{
                    受信日時 = $randomDate.ToString("yyyy-MM-dd HH:mm:ss")
                    送信者 = "sender$([System.Random]::new().Next(1, 100))@$randomDomain"
                    受信者 = "user$([System.Random]::new().Next(1, 50))@miraiconst.onmicrosoft.com"
                    件名 = "サンプルメッセージ $i"
                    配信状況 = $weightedStatus.Status
                    メッセージサイズMB = [math]::Round([System.Random]::new().NextDouble() * 25, 2)
                    遅延時間秒 = [System.Random]::new().Next(0, 300)
                    メッセージID = "sample-msg-$i-$(Get-Random)"
                    分析日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                }
                
                # エラーデータ（失敗状況の場合）
                if ($weightedStatus.Status -ne "Delivered") {
                    $errorReport += [PSCustomObject]@{
                        エラー発生日時 = $randomDate.ToString("yyyy-MM-dd HH:mm:ss")
                        送信者 = "sender$([System.Random]::new().Next(1, 100))@$randomDomain"
                        受信者 = "user$([System.Random]::new().Next(1, 50))@miraiconst.onmicrosoft.com"
                        件名 = "サンプルメッセージ $i"
                        エラータイプ = $weightedStatus.Status
                        エラー詳細 = "サンプルエラー詳細: $($weightedStatus.Status)による配信失敗"
                        メッセージサイズMB = [math]::Round([System.Random]::new().NextDouble() * 25, 2)
                        メッセージID = "sample-msg-$i-$(Get-Random)"
                        分析日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
            }
            
            # サンプル統計
            $deliveredCount = ($deliveryReport | Where-Object 配信状況 -eq "Delivered").Count
            $summaryStats = @{
                総メッセージ数 = $deliveryReport.Count
                成功配信数 = $deliveredCount
                配信失敗数 = $errorReport.Count
                成功率パーセント = [math]::Round(($deliveredCount / $deliveryReport.Count) * 100, 2)
                平均メッセージサイズMB = [math]::Round(($deliveryReport | Measure-Object メッセージサイズMB -Average).Average, 2)
                分析期間日数 = $DaysBack
                最新データ取得時刻 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                データソース = "サンプルデータ（実運用向けテスト）"
            }
            
            Write-Host "✅ サンプルデータでメール配信分析が完了しました" -ForegroundColor Green
        }
        
        Write-Host "📊 分析結果をエクスポート中..." -ForegroundColor Cyan
        
        # CSV出力
        if ($ExportCSV) {
            $csvPath = Join-Path $OutputPath "MailDeliveryAnalysis_$timestamp.csv"
            $deliveryReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host "  ✅ CSVファイルを出力しました: $csvPath" -ForegroundColor Green
            
            if ($errorReport.Count -gt 0) {
                $errorCsvPath = Join-Path $OutputPath "MailDeliveryErrors_$timestamp.csv"
                $errorReport | Export-Csv -Path $errorCsvPath -NoTypeInformation -Encoding UTF8
                Write-Host "  ✅ エラーCSVファイルを出力しました: $errorCsvPath" -ForegroundColor Green
            }
        }
        
        # HTML出力
        if ($ExportHTML) {
            $htmlPath = Join-Path $OutputPath "MailDeliveryAnalysis_$timestamp.html"
            
            $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>メール配信分析レポート - $((Get-Date).ToString("yyyy年MM月dd日 HH:mm"))</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; text-align: center; margin-bottom: 30px; }
        h2 { color: #34495e; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .summary { background-color: #ecf0f1; padding: 20px; border-radius: 8px; margin-bottom: 30px; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; }
        .summary-item { background-color: white; padding: 15px; border-radius: 6px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .summary-value { font-size: 24px; font-weight: bold; color: #2980b9; }
        .summary-label { font-size: 14px; color: #7f8c8d; margin-top: 5px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
        th, td { border: 1px solid #bdc3c7; padding: 12px; text-align: left; }
        th { background-color: #3498db; color: white; font-weight: bold; }
        tr:nth-child(even) { background-color: #f8f9fa; }
        tr:hover { background-color: #e8f4fd; }
        .success { background-color: #d5edda; color: #155724; }
        .warning { background-color: #fff3cd; color: #856404; }
        .error { background-color: #f8d7da; color: #721c24; }
        .footer { text-align: center; margin-top: 30px; color: #7f8c8d; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📧 Exchange Online メール配信分析レポート</h1>
        
        <div class="summary">
            <h2>📊 分析サマリー</h2>
            <div class="summary-grid">
                <div class="summary-item">
                    <div class="summary-value">$($summaryStats.総メッセージ数)</div>
                    <div class="summary-label">総メッセージ数</div>
                </div>
                <div class="summary-item">
                    <div class="summary-value">$($summaryStats.成功配信数)</div>
                    <div class="summary-label">成功配信数</div>
                </div>
                <div class="summary-item">
                    <div class="summary-value">$($summaryStats.配信失敗数)</div>
                    <div class="summary-label">配信失敗数</div>
                </div>
                <div class="summary-item">
                    <div class="summary-value">$($summaryStats.成功率パーセント)%</div>
                    <div class="summary-label">配信成功率</div>
                </div>
                <div class="summary-item">
                    <div class="summary-value">$($summaryStats.平均メッセージサイズMB) MB</div>
                    <div class="summary-label">平均メッセージサイズ</div>
                </div>
                <div class="summary-item">
                    <div class="summary-value">$($summaryStats.分析期間日数) 日間</div>
                    <div class="summary-label">分析期間</div>
                </div>
            </div>
            <p><strong>データソース:</strong> $($summaryStats.データソース)</p>
            <p><strong>最新データ取得時刻:</strong> $($summaryStats.最新データ取得時刻)</p>
        </div>
        
        <h2>📋 配信状況詳細</h2>
        <table>
            <thead>
                <tr>
                    <th>受信日時</th>
                    <th>送信者</th>
                    <th>受信者</th>
                    <th>配信状況</th>
                    <th>サイズ(MB)</th>
                    <th>遅延(秒)</th>
                </tr>
            </thead>
            <tbody>
"@
            
            # 最新の50件のみ表示（パフォーマンス考慮）
            $recentMessages = $deliveryReport | Sort-Object 受信日時 -Descending | Select-Object -First 50
            foreach ($message in $recentMessages) {
                $statusClass = switch ($message.配信状況) {
                    "Delivered" { "success" }
                    "Failed" { "error" }
                    "FilteredAsSpam" { "warning" }
                    "Quarantined" { "error" }
                    default { "" }
                }
                
                $htmlContent += @"
                <tr class="$statusClass">
                    <td>$($message.受信日時)</td>
                    <td>$($message.送信者)</td>
                    <td>$($message.受信者)</td>
                    <td>$($message.配信状況)</td>
                    <td>$($message.メッセージサイズMB)</td>
                    <td>$($message.遅延時間秒)</td>
                </tr>
"@
            }
            
            $htmlContent += @"
            </tbody>
        </table>
"@
            
            # エラーレポートがある場合は追加
            if ($errorReport.Count -gt 0) {
                $htmlContent += @"
        <h2>🚨 配信エラー詳細</h2>
        <table>
            <thead>
                <tr>
                    <th>エラー発生日時</th>
                    <th>送信者</th>
                    <th>受信者</th>
                    <th>エラータイプ</th>
                    <th>エラー詳細</th>
                </tr>
            </thead>
            <tbody>
"@
                
                $recentErrors = $errorReport | Sort-Object エラー発生日時 -Descending | Select-Object -First 20
                foreach ($error in $recentErrors) {
                    $htmlContent += @"
                <tr class="error">
                    <td>$($error.エラー発生日時)</td>
                    <td>$($error.送信者)</td>
                    <td>$($error.受信者)</td>
                    <td>$($error.エラータイプ)</td>
                    <td>$($error.エラー詳細)</td>
                </tr>
"@
                }
                
                $htmlContent += @"
            </tbody>
        </table>
"@
            }
            
            $htmlContent += @"
        <div class="footer">
            <p>Microsoft 365統合管理ツール - メール配信分析</p>
            <p>生成日時: $((Get-Date).ToString("yyyy年MM月dd日 HH:mm:ss"))</p>
            <p>ITSM/ISO27001/27002準拠レポート</p>
        </div>
    </div>
</body>
</html>
"@
            
            Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
            Write-Host "  ✅ HTMLレポートを出力しました: $htmlPath" -ForegroundColor Green
        }
        
        Write-Host "🎯 メール配信分析が完了しました" -ForegroundColor Green
        Write-Host "  📊 分析対象: $($summaryStats.総メッセージ数) 件のメッセージ" -ForegroundColor Cyan
        Write-Host "  ✅ 成功率: $($summaryStats.成功率パーセント)%" -ForegroundColor Cyan
        Write-Host "  📁 出力先: $OutputPath" -ForegroundColor Cyan
        
        return @{
            DeliveryReport = $deliveryReport
            ErrorReport = $errorReport
            Summary = $summaryStats
            OutputPath = $OutputPath
        }
        
    } catch {
        Write-Host "❌ メール配信分析でエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# モジュールとしての使用時のエクスポート
if ($MyInvocation.InvocationName -ne '&') {
    Export-ModuleMember -Function Get-MailDeliveryAnalysis
}