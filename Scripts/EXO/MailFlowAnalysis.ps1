# ================================================================================
# MailFlowAnalysis.ps1
# Exchange Online メールフロー分析スクリプト（実データ対応版）
# ITSM/ISO27001/27002準拠 - メールフロー・ルーティング分析
# ================================================================================

function Get-MailFlowAnalysis {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 7,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Exchange\MailFlow",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeTransportRules = $true,
        
        [Parameter(Mandatory = $false)]
        [int]$SampleSize = 1000
    )
    
    try {
        Write-Host "🔄 Exchange Online メールフロー分析を開始します（過去 $DaysBack 日間）" -ForegroundColor Cyan
        
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
        
        $mailFlowReport = @()
        $transportRulesReport = @()
        $connectorReport = @()
        $summaryStats = @{}
        
        if ($exchangeConnected) {
            try {
                Write-Host "🔍 メールフロー情報を取得中..." -ForegroundColor Cyan
                
                # メッセージトレースを取得（フロー分析）
                Write-Host "  📋 メッセージトレースを分析中（最大${SampleSize}件）..." -ForegroundColor Gray
                $messageTrace = Get-MessageTrace -StartDate $startDate -EndDate $endDate -PageSize $SampleSize -ErrorAction Stop
                Write-Host "  ✅ $($messageTrace.Count) 件のメッセージトレースを取得しました" -ForegroundColor Green
                
                # トランスポートルール情報取得（設定による）
                if ($IncludeTransportRules) {
                    Write-Host "  📋 トランスポートルールを取得中..." -ForegroundColor Gray
                    try {
                        $transportRules = Get-TransportRule -ErrorAction SilentlyContinue
                        Write-Host "  ✅ $($transportRules.Count) 件のトランスポートルールを取得しました" -ForegroundColor Green
                    } catch {
                        Write-Host "  ⚠️ トランスポートルール取得をスキップ（権限制限または設定無効）" -ForegroundColor Yellow
                        $transportRules = @()
                    }
                } else {
                    $transportRules = @()
                }
                
                # 送信コネクタ情報取得
                Write-Host "  📋 送信コネクタ情報を取得中..." -ForegroundColor Gray
                try {
                    $outboundConnectors = Get-OutboundConnector -ErrorAction SilentlyContinue
                    $inboundConnectors = Get-InboundConnector -ErrorAction SilentlyContinue
                    Write-Host "  ✅ 送信コネクタ $($outboundConnectors.Count) 件, 受信コネクタ $($inboundConnectors.Count) 件を取得しました" -ForegroundColor Green
                } catch {
                    Write-Host "  ⚠️ コネクタ情報取得をスキップ（権限制限）" -ForegroundColor Yellow
                    $outboundConnectors = @()
                    $inboundConnectors = @()
                }
                
                # メールフロー分析データ生成
                Write-Host "  🔄 メールフロー分析中..." -ForegroundColor Gray
                
                # ドメイン別フロー分析
                $domainFlow = $messageTrace | Group-Object { 
                    if ($_.SenderAddress -match "@(.+)") { $matches[1] } else { "Unknown" }
                } | ForEach-Object {
                    $domain = $_.Name
                    $messages = $_.Group
                    $deliveredCount = ($messages | Where-Object Status -eq "Delivered").Count
                    
                    [PSCustomObject]@{
                        送信ドメイン = $domain
                        総メッセージ数 = $messages.Count
                        配信成功数 = $deliveredCount
                        配信失敗数 = $messages.Count - $deliveredCount
                        成功率パーセント = [math]::Round(($deliveredCount / $messages.Count) * 100, 2)
                        平均サイズMB = [math]::Round(($messages | Measure-Object Size -Average).Average / 1MB, 2)
                        分析日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                } | Sort-Object 総メッセージ数 -Descending
                
                # 時間別フロー分析
                $hourlyFlow = $messageTrace | Group-Object { $_.Received.Hour } | ForEach-Object {
                    $hour = $_.Name
                    $messages = $_.Group
                    
                    [PSCustomObject]@{
                        時間帯 = "${hour}:00-${hour}:59"
                        メッセージ数 = $messages.Count
                        配信成功数 = ($messages | Where-Object Status -eq "Delivered").Count
                        平均サイズMB = [math]::Round(($messages | Measure-Object Size -Average).Average / 1MB, 2)
                        分析日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                } | Sort-Object { [int]$_.時間帯.Split(':')[0] }
                
                # メールフローレポート生成（詳細）
                foreach ($message in $messageTrace) {
                    $senderDomain = if ($message.SenderAddress -match "@(.+)") { $matches[1] } else { "Unknown" }
                    $recipientDomain = if ($message.RecipientAddress -match "@(.+)") { $matches[1] } else { "Unknown" }
                    
                    $mailFlowReport += [PSCustomObject]@{
                        受信日時 = $message.Received.ToString("yyyy-MM-dd HH:mm:ss")
                        送信者ドメイン = $senderDomain
                        受信者ドメイン = $recipientDomain
                        送信者 = $message.SenderAddress
                        受信者 = $message.RecipientAddress
                        配信状況 = $message.Status
                        メッセージサイズMB = [math]::Round($message.Size / 1MB, 2)
                        件名 = $message.Subject
                        メッセージID = $message.MessageId
                        フロー方向 = if ($recipientDomain -like "*onmicrosoft.com" -or $recipientDomain -like "*miraiconst*") { "受信" } else { "送信" }
                        分析日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
                
                # トランスポートルールレポート
                foreach ($rule in $transportRules) {
                    $transportRulesReport += [PSCustomObject]@{
                        ルール名 = $rule.Name
                        状態 = if ($rule.State -eq "Enabled") { "有効" } else { "無効" }
                        優先度 = $rule.Priority
                        条件 = $rule.Conditions -join "; "
                        アクション = $rule.Actions -join "; "
                        説明 = $rule.Description
                        最終更新日 = $rule.WhenChanged.ToString("yyyy-MM-dd HH:mm:ss")
                        分析日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
                
                # コネクタレポート
                foreach ($connector in $outboundConnectors) {
                    $connectorReport += [PSCustomObject]@{
                        コネクタ名 = $connector.Name
                        タイプ = "送信"
                        状態 = if ($connector.Enabled) { "有効" } else { "無効" }
                        接続先 = $connector.SmartHosts -join "; "
                        TLS設定 = $connector.TlsSettings
                        証明書検証 = $connector.CloudServicesMailEnabled
                        最終更新日 = $connector.WhenChanged.ToString("yyyy-MM-dd HH:mm:ss")
                        分析日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
                
                foreach ($connector in $inboundConnectors) {
                    $connectorReport += [PSCustomObject]@{
                        コネクタ名 = $connector.Name
                        タイプ = "受信"
                        状態 = if ($connector.Enabled) { "有効" } else { "無効" }
                        接続元 = $connector.SenderDomains -join "; "
                        TLS設定 = $connector.RequireTls
                        証明書検証 = $connector.RestrictDomainsToIPAddresses
                        最終更新日 = $connector.WhenChanged.ToString("yyyy-MM-dd HH:mm:ss")
                        分析日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
                
                # 統計サマリー
                $internalMail = $mailFlowReport | Where-Object フロー方向 -eq "受信"
                $externalMail = $mailFlowReport | Where-Object フロー方向 -eq "送信"
                
                $summaryStats = @{
                    総メッセージ数 = $mailFlowReport.Count
                    内部メール数 = $internalMail.Count
                    外部メール数 = $externalMail.Count
                    ユニーク送信ドメイン数 = ($mailFlowReport | Select-Object 送信者ドメイン -Unique).Count
                    平均メッセージサイズMB = [math]::Round(($mailFlowReport | Measure-Object メッセージサイズMB -Average).Average, 2)
                    有効なトランスポートルール数 = ($transportRulesReport | Where-Object 状態 -eq "有効").Count
                    総トランスポートルール数 = $transportRulesReport.Count
                    有効なコネクタ数 = ($connectorReport | Where-Object 状態 -eq "有効").Count
                    分析期間日数 = $DaysBack
                    最新データ取得時刻 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    データソース = "Exchange Online API (実データ)"
                }
                
                Write-Host "✅ 実データからメールフロー分析が完了しました" -ForegroundColor Green
                
            } catch {
                Write-Host "❌ 実データ取得エラー: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "📊 サンプルデータで分析を生成します..." -ForegroundColor Yellow
                $exchangeConnected = $false
            }
        }
        
        # 実データ取得に失敗した場合のサンプルデータ生成
        if (-not $exchangeConnected -or $mailFlowReport.Count -eq 0) {
            Write-Host "📊 サンプルデータでメールフロー分析を生成中..." -ForegroundColor Yellow
            
            # 現実的なサンプルデータ生成
            $sampleCount = 600
            $domains = @("contoso.com", "fabrikam.com", "northwind.com", "adventure-works.com", "example.com")
            $internalDomains = @("miraiconst.onmicrosoft.com", "miraiconst.local")
            
            for ($i = 1; $i -le $sampleCount; $i++) {
                $randomDate = (Get-Date).AddHours(-([System.Random]::new().Next(0, $DaysBack * 24)))
                $isInbound = [System.Random]::new().Next(0, 2) -eq 0
                
                if ($isInbound) {
                    $senderDomain = $domains | Get-Random
                    $recipientDomain = $internalDomains | Get-Random
                    $flowDirection = "受信"
                } else {
                    $senderDomain = $internalDomains | Get-Random
                    $recipientDomain = $domains | Get-Random
                    $flowDirection = "送信"
                }
                
                $status = if ([System.Random]::new().Next(0, 100) -lt 95) { "Delivered" } else { "Failed" }
                
                $mailFlowReport += [PSCustomObject]@{
                    受信日時 = $randomDate.ToString("yyyy-MM-dd HH:mm:ss")
                    送信者ドメイン = $senderDomain
                    受信者ドメイン = $recipientDomain
                    送信者 = "user$([System.Random]::new().Next(1, 100))@$senderDomain"
                    受信者 = "user$([System.Random]::new().Next(1, 50))@$recipientDomain"
                    配信状況 = $status
                    メッセージサイズMB = [math]::Round([System.Random]::new().NextDouble() * 25, 2)
                    件名 = "サンプルメッセージ $i"
                    メッセージID = "sample-flow-$i-$(Get-Random)"
                    フロー方向 = $flowDirection
                    分析日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                }
            }
            
            # サンプルトランスポートルール
            $sampleRules = @(
                @{Name="スパムフィルタ"; State="Enabled"; Priority=1; Conditions="送信者レピュテーション"; Actions="隔離"},
                @{Name="外部転送ブロック"; State="Enabled"; Priority=2; Conditions="外部ドメイン転送"; Actions="ブロック"},
                @{Name="大容量添付ファイル制限"; State="Enabled"; Priority=3; Conditions="添付ファイル>25MB"; Actions="拒否"},
                @{Name="機密情報保護"; State="Enabled"; Priority=4; Conditions="DLP検出"; Actions="暗号化"}
            )
            
            foreach ($rule in $sampleRules) {
                $transportRulesReport += [PSCustomObject]@{
                    ルール名 = $rule.Name
                    状態 = if ($rule.State -eq "Enabled") { "有効" } else { "無効" }
                    優先度 = $rule.Priority
                    条件 = $rule.Conditions
                    アクション = $rule.Actions
                    説明 = "サンプルトランスポートルール: $($rule.Name)"
                    最終更新日 = (Get-Date).AddDays(-[System.Random]::new().Next(1, 30)).ToString("yyyy-MM-dd HH:mm:ss")
                    分析日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                }
            }
            
            # サンプル統計
            $internalMail = $mailFlowReport | Where-Object フロー方向 -eq "受信"
            $externalMail = $mailFlowReport | Where-Object フロー方向 -eq "送信"
            
            $summaryStats = @{
                総メッセージ数 = $mailFlowReport.Count
                内部メール数 = $internalMail.Count
                外部メール数 = $externalMail.Count
                ユニーク送信ドメイン数 = ($mailFlowReport | Select-Object 送信者ドメイン -Unique).Count
                平均メッセージサイズMB = [math]::Round(($mailFlowReport | Measure-Object メッセージサイズMB -Average).Average, 2)
                有効なトランスポートルール数 = ($transportRulesReport | Where-Object 状態 -eq "有効").Count
                総トランスポートルール数 = $transportRulesReport.Count
                有効なコネクタ数 = 2
                分析期間日数 = $DaysBack
                最新データ取得時刻 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                データソース = "サンプルデータ（実運用向けテスト）"
            }
            
            Write-Host "✅ サンプルデータでメールフロー分析が完了しました" -ForegroundColor Green
        }
        
        Write-Host "📊 分析結果をエクスポート中..." -ForegroundColor Cyan
        
        # CSV出力
        if ($ExportCSV) {
            $csvPath = Join-Path $OutputPath "MailFlowAnalysis_$timestamp.csv"
            $mailFlowReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host "  ✅ CSVファイルを出力しました: $csvPath" -ForegroundColor Green
            
            if ($transportRulesReport.Count -gt 0) {
                $rulesCsvPath = Join-Path $OutputPath "TransportRules_$timestamp.csv"
                $transportRulesReport | Export-Csv -Path $rulesCsvPath -NoTypeInformation -Encoding UTF8
                Write-Host "  ✅ トランスポートルールCSVファイルを出力しました: $rulesCsvPath" -ForegroundColor Green
            }
        }
        
        # HTML出力
        if ($ExportHTML) {
            $htmlPath = Join-Path $OutputPath "MailFlowAnalysis_$timestamp.html"
            
            $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>メールフロー分析レポート - $((Get-Date).ToString("yyyy年MM月dd日 HH:mm"))</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; text-align: center; margin-bottom: 30px; }
        h2 { color: #34495e; border-bottom: 2px solid #e74c3c; padding-bottom: 10px; }
        .summary { background-color: #ecf0f1; padding: 20px; border-radius: 8px; margin-bottom: 30px; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; }
        .summary-item { background-color: white; padding: 15px; border-radius: 6px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .summary-value { font-size: 24px; font-weight: bold; color: #e74c3c; }
        .summary-label { font-size: 14px; color: #7f8c8d; margin-top: 5px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
        th, td { border: 1px solid #bdc3c7; padding: 12px; text-align: left; }
        th { background-color: #e74c3c; color: white; font-weight: bold; }
        tr:nth-child(even) { background-color: #f8f9fa; }
        tr:hover { background-color: #fdf2f2; }
        .inbound { background-color: #d5edda; color: #155724; }
        .outbound { background-color: #d1ecf1; color: #0c5460; }
        .enabled { background-color: #d5edda; color: #155724; }
        .disabled { background-color: #f8d7da; color: #721c24; }
        .footer { text-align: center; margin-top: 30px; color: #7f8c8d; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔄 Exchange Online メールフロー分析レポート</h1>
        
        <div class="summary">
            <h2>📊 フロー分析サマリー</h2>
            <div class="summary-grid">
                <div class="summary-item">
                    <div class="summary-value">$($summaryStats.総メッセージ数)</div>
                    <div class="summary-label">総メッセージ数</div>
                </div>
                <div class="summary-item">
                    <div class="summary-value">$($summaryStats.内部メール数)</div>
                    <div class="summary-label">内部メール数</div>
                </div>
                <div class="summary-item">
                    <div class="summary-value">$($summaryStats.外部メール数)</div>
                    <div class="summary-label">外部メール数</div>
                </div>
                <div class="summary-item">
                    <div class="summary-value">$($summaryStats.ユニーク送信ドメイン数)</div>
                    <div class="summary-label">送信ドメイン数</div>
                </div>
                <div class="summary-item">
                    <div class="summary-value">$($summaryStats.平均メッセージサイズMB) MB</div>
                    <div class="summary-label">平均メッセージサイズ</div>
                </div>
                <div class="summary-item">
                    <div class="summary-value">$($summaryStats.有効なトランスポートルール数)</div>
                    <div class="summary-label">有効ルール数</div>
                </div>
            </div>
            <p><strong>データソース:</strong> $($summaryStats.データソース)</p>
            <p><strong>最新データ取得時刻:</strong> $($summaryStats.最新データ取得時刻)</p>
        </div>
        
        <h2>📋 メールフロー詳細</h2>
        <table>
            <thead>
                <tr>
                    <th>受信日時</th>
                    <th>フロー方向</th>
                    <th>送信者ドメイン</th>
                    <th>受信者ドメイン</th>
                    <th>配信状況</th>
                    <th>サイズ(MB)</th>
                </tr>
            </thead>
            <tbody>
"@
            
            # 最新の50件のみ表示（パフォーマンス考慮）
            $recentFlow = $mailFlowReport | Sort-Object 受信日時 -Descending | Select-Object -First 50
            foreach ($flow in $recentFlow) {
                $flowClass = if ($flow.フロー方向 -eq "受信") { "inbound" } else { "outbound" }
                
                $htmlContent += @"
                <tr class="$flowClass">
                    <td>$($flow.受信日時)</td>
                    <td>$($flow.フロー方向)</td>
                    <td>$($flow.送信者ドメイン)</td>
                    <td>$($flow.受信者ドメイン)</td>
                    <td>$($flow.配信状況)</td>
                    <td>$($flow.メッセージサイズMB)</td>
                </tr>
"@
            }
            
            $htmlContent += @"
            </tbody>
        </table>
"@
            
            # トランスポートルール情報
            if ($transportRulesReport.Count -gt 0) {
                $htmlContent += @"
        <h2>⚙️ トランスポートルール設定</h2>
        <table>
            <thead>
                <tr>
                    <th>ルール名</th>
                    <th>状態</th>
                    <th>優先度</th>
                    <th>条件</th>
                    <th>アクション</th>
                </tr>
            </thead>
            <tbody>
"@
                
                foreach ($rule in $transportRulesReport) {
                    $ruleClass = if ($rule.状態 -eq "有効") { "enabled" } else { "disabled" }
                    
                    $htmlContent += @"
                <tr class="$ruleClass">
                    <td>$($rule.ルール名)</td>
                    <td>$($rule.状態)</td>
                    <td>$($rule.優先度)</td>
                    <td>$($rule.条件)</td>
                    <td>$($rule.アクション)</td>
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
            <p>Microsoft 365統合管理ツール - メールフロー分析</p>
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
        
        Write-Host "🎯 メールフロー分析が完了しました" -ForegroundColor Green
        Write-Host "  📊 分析対象: $($summaryStats.総メッセージ数) 件のメッセージ" -ForegroundColor Cyan
        Write-Host "  🔄 内部メール: $($summaryStats.内部メール数) 件, 外部メール: $($summaryStats.外部メール数) 件" -ForegroundColor Cyan
        Write-Host "  📁 出力先: $OutputPath" -ForegroundColor Cyan
        
        return @{
            MailFlowReport = $mailFlowReport
            TransportRulesReport = $transportRulesReport
            ConnectorReport = $connectorReport
            Summary = $summaryStats
            OutputPath = $OutputPath
        }
        
    } catch {
        Write-Host "❌ メールフロー分析でエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# モジュールとしての使用時のエクスポート
if ($MyInvocation.InvocationName -ne '&') {
    Export-ModuleMember -Function Get-MailFlowAnalysis
}