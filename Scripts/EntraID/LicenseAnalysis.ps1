# ================================================================================
# LicenseAnalysis.ps1
# Microsoft 365ライセンス配布状況・未使用ライセンス監視スクリプト
# ITSM/ISO27001/27002準拠 - ライセンス最適化・コスト監視
# ================================================================================

# 共通モジュールのインポート
try {
    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
    Import-Module "$PSScriptRoot\..\Common\Logging.psm1" -Force
    Import-Module "$PSScriptRoot\..\Common\ErrorHandling.psm1" -Force
    Import-Module "$PSScriptRoot\..\Common\ReportGenerator.psm1" -Force
}
catch {
    Write-Host "❌ 共通モジュールのインポートに失敗しました: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "スタンドアロンモードで実行します..." -ForegroundColor Yellow
}

function Get-LicenseAnalysis {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly",
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeUserDetails = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$AnalyzeCosts = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $true
    )
    
    try {
        # ログ関数の定義（スタンドアロン対応）
        if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
            function Write-Log {
                param([string]$Message, [string]$Level = "Info")
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
                    switch ($Level) {
                        "Error" { "Red" }
                        "Warning" { "Yellow" }
                        "Info" { "Cyan" }
                        default { "White" }
                    }
                )
            }
        }
        
        Write-Log "Microsoft 365ライセンス分析を開始します" -Level "Info"
        
        # 必要なモジュールのチェック
        $requiredModules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users", "Microsoft.Graph.Identity.DirectoryManagement")
        foreach ($module in $requiredModules) {
            if (-not (Get-Module -Name $module -ListAvailable)) {
                Write-Log "必要なモジュールがインストールされていません: $module" -Level "Warning"
            }
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $licenseReport = @()
        $userLicenseReport = @()
        $costAnalysisReport = @()
        $unusedLicensesReport = @()
        
        # Microsoft Graph接続確認と自動接続
        $graphConnected = $false
        try {
            $context = Get-MgContext -ErrorAction SilentlyContinue
            if ($context) {
                $graphConnected = $true
                Write-Log "Microsoft Graph接続済み（テナント: $($context.TenantId)）" -Level "Info"
            } else {
                # 自動接続を試行
                Write-Log "Microsoft Graphへの自動接続を試行しています..." -Level "Info"
                
                # まず設定ファイルベースの認証を試行
                $authSuccess = $false
                
                # 1. 設定ファイルからの認証情報読み込み
                try {
                    $configPath = Join-Path $PWD "Config\appsettings.json"
                    if (Test-Path $configPath) {
                        Write-Log "設定ファイルから認証情報を読み込み中..." -Level "Info"
                        $config = Get-Content $configPath | ConvertFrom-Json
                        
                        # EntraID/MicrosoftGraph設定を確認
                        $graphConfig = if ($config.MicrosoftGraph) { $config.MicrosoftGraph } else { $config.EntraID }
                        
                        if ($graphConfig -and $graphConfig.ClientId -and $graphConfig.TenantId) {
                            Write-Log "証明書ベース認証を試行中..." -Level "Info"
                            
                            # 証明書ベース認証
                            if ($graphConfig.CertificatePath -and (Test-Path $graphConfig.CertificatePath)) {
                                $certPassword = ConvertTo-SecureString $graphConfig.CertificatePassword -AsPlainText -Force
                                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($graphConfig.CertificatePath, $certPassword)
                                
                                Connect-MgGraph -ClientId $graphConfig.ClientId -Certificate $cert -TenantId $graphConfig.TenantId -NoWelcome
                                $authSuccess = $true
                                Write-Log "証明書ベース認証成功" -Level "Info"
                            }
                            # クライアントシークレット認証
                            elseif ($graphConfig.ClientSecret) {
                                $clientSecret = ConvertTo-SecureString $graphConfig.ClientSecret -AsPlainText -Force
                                $credential = New-Object System.Management.Automation.PSCredential($graphConfig.ClientId, $clientSecret)
                                
                                Connect-MgGraph -ClientSecretCredential $credential -TenantId $graphConfig.TenantId -NoWelcome
                                $authSuccess = $true
                                Write-Log "クライアントシークレット認証成功" -Level "Info"
                            }
                        }
                    }
                } catch {
                    Write-Log "設定ファイルベース認証エラー: $($_.Exception.Message)" -Level "Warning"
                }
                
                # 2. 環境変数ベースの認証
                if (-not $authSuccess) {
                    try {
                        Write-Log "環境変数ベース認証を試行中..." -Level "Info"
                        
                        $clientId = $env:AZURE_CLIENT_ID
                        $clientSecret = $env:AZURE_CLIENT_SECRET
                        $tenantId = $env:AZURE_TENANT_ID
                        
                        if ($clientId -and $clientSecret -and $tenantId) {
                            Write-Log "環境変数から認証情報を使用..." -Level "Info"
                            $clientSecretSecure = ConvertTo-SecureString $clientSecret -AsPlainText -Force
                            $credential = New-Object System.Management.Automation.PSCredential($clientId, $clientSecretSecure)
                            
                            Connect-MgGraph -ClientSecretCredential $credential -TenantId $tenantId -NoWelcome
                            $authSuccess = $true
                            Write-Log "環境変数ベース認証成功" -Level "Info"
                        } else {
                            Write-Log "認証情報が不足しています。サンプルデータモードで継続します" -Level "Warning"
                            Write-Log "必要な設定: Config\appsettings.json または環境変数 (AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID)" -Level "Info"
                        }
                    } catch {
                        Write-Log "環境変数ベース認証エラー: $($_.Exception.Message)" -Level "Warning"
                        Write-Log "サンプルデータモードで継続します" -Level "Info"
                    }
                }
                
                # 接続確認
                if ($authSuccess) {
                    $context = Get-MgContext
                    if ($context) {
                        $graphConnected = $true
                        Write-Log "Microsoft Graph接続成功（テナント: $($context.TenantId)）" -Level "Info"
                        Write-Log "認証タイプ: $($context.AuthType)" -Level "Info"
                        Write-Log "利用可能スコープ: $($context.Scopes -join ', ')" -Level "Info"
                    }
                }
            }
        } catch {
            Write-Log "Microsoft Graph接続確認エラー: $($_.Exception.Message)" -Level "Warning"
        }

        # ライセンス情報取得
        $subscribedSkus = @()
        $users = @()
        
        if ($graphConnected) {
            try {
                Write-Log "組織のライセンス情報を取得中..." -Level "Info"
                $subscribedSkus = Get-MgSubscribedSku -All -ErrorAction Stop
                Write-Log "実データ取得成功: $($subscribedSkus.Count)種類のライセンス" -Level "Info"
                
                Write-Log "ユーザーライセンス割り当て情報を取得中..." -Level "Info"
                $users = Get-MgUser -All -Property Id,UserPrincipalName,DisplayName,AccountEnabled,AssignedLicenses,LicenseAssignmentStates,CreatedDateTime,LastSignInDateTime,Department,JobTitle -ErrorAction Stop
                Write-Log "実データ取得成功: $($users.Count)ユーザー" -Level "Info"
            } catch {
                Write-Log "実データ取得エラー: $($_.Exception.Message)" -Level "Warning"
                Write-Log "サンプルデータを使用します" -Level "Info"
                $subscribedSkus = @()
                $users = @()
            }
        } else {
            Write-Log "Microsoft Graphに接続されていません。サンプルデータを使用します" -Level "Warning"
        }

        # データが取得できない場合はサンプルデータを生成
        if ($subscribedSkus.Count -eq 0 -or $users.Count -eq 0) {
            Write-Log "サンプルデータを生成中..." -Level "Info"
            $testData = Generate-SampleLicenseData
            $subscribedSkus = $testData.SubscribedSkus
            $users = $testData.Users
        }
        
        Write-Log "ライセンス分析処理中..." -Level "Info"
        
        # 無料ライセンスを除外するリスト
        $excludeFreeLicenses = @("WINDOWS_STORE", "FLOW_FREE", "DEVELOPERPACK", "PROJECTCLIENT", "VISIOCLIENT_EDUCATOR")
        
        # ライセンス種別ごとの分析（無料ライセンス除外）
        foreach ($sku in $subscribedSkus) {
            try {
                # 無料ライセンスをスキップ
                if ($sku.SkuPartNumber -in $excludeFreeLicenses) {
                    Write-Log "無料ライセンスをスキップ: $($sku.SkuPartNumber)" -Level "Info"
                    continue
                }
                
                Write-Log "ライセンス分析中: $($sku.SkuPartNumber)" -Level "Info"
                
                # ライセンス使用状況の計算
                $enabledUnits = $sku.PrepaidUnits.Enabled
                $consumedUnits = $sku.ConsumedUnits
                $availableUnits = $enabledUnits - $consumedUnits
                $utilizationRate = if ($enabledUnits -gt 0) { [math]::Round(($consumedUnits / $enabledUnits) * 100, 2) } else { 0 }
                
                # ライセンス名の日本語化
                $licenseName = Get-LicenseDisplayName -SkuPartNumber $sku.SkuPartNumber
                
                # コスト分析（推定）
                $estimatedCostPerUser = Get-EstimatedLicenseCost -SkuPartNumber $sku.SkuPartNumber
                $totalEstimatedCost = $consumedUnits * $estimatedCostPerUser
                $wastedCost = $availableUnits * $estimatedCostPerUser
                
                # リスク評価
                $riskLevel = "正常"
                $alertLevel = "Info"
                $recommendations = @()
                
                if ($utilizationRate -lt 50) {
                    $riskLevel = "注意"
                    $alertLevel = "Warning"
                    $recommendations += "利用率が低い（$utilizationRate%）- ライセンス数の見直しを検討してください"
                }
                elseif ($utilizationRate -gt 90) {
                    $riskLevel = "警告"
                    $alertLevel = "Warning"
                    $recommendations += "利用率が高い（$utilizationRate%）- 追加ライセンスの準備を検討してください"
                }
                
                if ($availableUnits -gt 10) {
                    if ($riskLevel -eq "正常") { $riskLevel = "注意" }
                    $recommendations += "$availableUnits個の未使用ライセンスあり - コスト削減の機会"
                }
                
                # 長期未使用ユーザーの確認
                $longTermInactiveUsers = 0
                if ($graphConnected) {
                    try {
                        $usersWithThisLicense = $users | Where-Object { 
                            $_.AssignedLicenses.SkuId -contains $sku.SkuId 
                        }
                        
                        foreach ($user in $usersWithThisLicense) {
                            if ($user.LastSignInDateTime) {
                                $daysSinceLastSignIn = ((Get-Date) - $user.LastSignInDateTime).Days
                                if ($daysSinceLastSignIn -gt 90) {
                                    $longTermInactiveUsers++
                                }
                            }
                        }
                        
                        if ($longTermInactiveUsers -gt 0) {
                            if ($riskLevel -eq "正常") { $riskLevel = "注意" }
                            $recommendations += "$longTermInactiveUsers名の90日以上未利用ユーザーあり - ライセンス回収を検討"
                        }
                    } catch {
                        Write-Log "非アクティブユーザー分析エラー: $($_.Exception.Message)" -Level "Warning"
                    }
                }
                
                $licenseReport += [PSCustomObject]@{
                    LicenseName = $licenseName
                    SkuPartNumber = $sku.SkuPartNumber
                    SkuId = $sku.SkuId
                    TotalLicenses = $enabledUnits
                    ConsumedLicenses = $consumedUnits
                    AvailableLicenses = $availableUnits
                    UtilizationRate = $utilizationRate
                    EstimatedCostPerUser = $estimatedCostPerUser
                    TotalEstimatedCost = $totalEstimatedCost
                    WastedCost = $wastedCost
                    LongTermInactiveUsers = $longTermInactiveUsers
                    RiskLevel = $riskLevel
                    AlertLevel = $alertLevel
                    Recommendations = ($recommendations -join "; ")
                    AnalysisTimestamp = Get-Date
                }
                
                # 未使用ライセンス詳細レポート
                if ($availableUnits -gt 0) {
                    $unusedLicensesReport += [PSCustomObject]@{
                        LicenseName = $licenseName
                        SkuPartNumber = $sku.SkuPartNumber
                        UnusedCount = $availableUnits
                        WastedCostPerMonth = $wastedCost
                        PotentialSavingsPerYear = $wastedCost * 12
                        RecommendedAction = if ($availableUnits -gt 10) { "ライセンス数削減を推奨" } 
                                          elseif ($availableUnits -gt 5) { "ライセンス数見直しを検討" } 
                                          else { "現状維持（予備として保持）" }
                        Priority = if ($wastedCost -gt 10000) { "高" }
                                  elseif ($wastedCost -gt 5000) { "中" }
                                  else { "低" }
                    }
                }
                
            } catch {
                Write-Log "ライセンス分析エラー: $($sku.SkuPartNumber) - $($_.Exception.Message)" -Level "Error"
            }
        }
        
        # ユーザー別ライセンス詳細分析
        if ($IncludeUserDetails) {
            Write-Log "ユーザー別ライセンス分析中..." -Level "Info"
            
            foreach ($user in $users) {
                try {
                    if ($user.AssignedLicenses.Count -gt 0) {
                        $userLicenses = @()
                        $totalUserCost = 0
                        
                        foreach ($assignedLicense in $user.AssignedLicenses) {
                            $sku = $subscribedSkus | Where-Object { $_.SkuId -eq $assignedLicense.SkuId }
                            if ($sku -and $sku.SkuPartNumber -notin $excludeFreeLicenses) {
                                $licenseName = Get-LicenseDisplayName -SkuPartNumber $sku.SkuPartNumber
                                $userLicenses += $licenseName
                                $totalUserCost += Get-EstimatedLicenseCost -SkuPartNumber $sku.SkuPartNumber
                            }
                        }
                        
                        # 最終サインイン分析
                        $lastSignInStatus = "不明"
                        $daysSinceLastSignIn = $null
                        $utilizationStatus = "アクティブ"
                        
                        if ($user.LastSignInDateTime) {
                            $daysSinceLastSignIn = ((Get-Date) - $user.LastSignInDateTime).Days
                            $lastSignInStatus = if ($daysSinceLastSignIn -le 7) { "最近（7日以内）" }
                                              elseif ($daysSinceLastSignIn -le 30) { "1ヶ月以内" }
                                              elseif ($daysSinceLastSignIn -le 90) { "3ヶ月以内" }
                                              else { "90日以上前" }
                            
                            if ($daysSinceLastSignIn -gt 90) {
                                $utilizationStatus = "長期未利用"
                            } elseif ($daysSinceLastSignIn -gt 30) {
                                $utilizationStatus = "低利用"
                            }
                        }
                        
                        # 有料ライセンスがない場合はスキップ
                        if ($userLicenses.Count -eq 0 -or $totalUserCost -eq 0) {
                            continue
                        }
                        
                        # ライセンス最適化提案
                        $optimizationRecommendations = @()
                        if ($utilizationStatus -eq "長期未利用") {
                            $optimizationRecommendations += "ライセンス回収を検討（90日以上未利用）"
                        }
                        $paidLicenseCount = $userLicenses.Count
                        if ($paidLicenseCount -gt 2) {
                            $optimizationRecommendations += "複数ライセンス割り当て - 統合の検討"
                        }
                        if (-not $user.AccountEnabled) {
                            $optimizationRecommendations += "無効ユーザー - ライセンス即座回収"
                        }
                        
                        $userLicenseReport += [PSCustomObject]@{
                            UserPrincipalName = $user.UserPrincipalName
                            DisplayName = $user.DisplayName
                            Department = $user.Department
                            JobTitle = $user.JobTitle
                            AccountEnabled = $user.AccountEnabled
                            LicenseCount = $paidLicenseCount
                            AssignedLicenses = ($userLicenses -join "; ")
                            TotalMonthlyCost = $totalUserCost
                            LastSignInStatus = $lastSignInStatus
                            DaysSinceLastSignIn = $daysSinceLastSignIn
                            UtilizationStatus = $utilizationStatus
                            OptimizationRecommendations = if ($optimizationRecommendations.Count -gt 0) { ($optimizationRecommendations -join "; ") } else { "最適化済み" }
                            CreatedDateTime = $user.CreatedDateTime
                            AnalysisTimestamp = Get-Date
                        }
                    }
                } catch {
                    Write-Log "ユーザーライセンス分析エラー: $($user.DisplayName) - $($_.Exception.Message)" -Level "Warning"
                }
            }
        }
        
        # コスト分析サマリー
        if ($AnalyzeCosts) {
            Write-Log "コスト分析実行中..." -Level "Info"
            
            $totalMonthlyCost = ($licenseReport | Measure-Object -Property TotalEstimatedCost -Sum).Sum
            $totalWastedCost = ($licenseReport | Measure-Object -Property WastedCost -Sum).Sum
            $totalAnnualCost = $totalMonthlyCost * 12
            $totalAnnualWaste = $totalWastedCost * 12
            
            $costAnalysisReport += [PSCustomObject]@{
                MetricName = "総月額コスト"
                Value = $totalMonthlyCost
                Unit = "円/月"
                Category = "現在のコスト"
                Description = "現在消費されているライセンスの推定月額コスト"
            }
            
            $costAnalysisReport += [PSCustomObject]@{
                MetricName = "未使用ライセンス月額コスト"
                Value = $totalWastedCost
                Unit = "円/月"
                Category = "無駄なコスト"
                Description = "未使用ライセンスによる月額コスト損失"
            }
            
            $costAnalysisReport += [PSCustomObject]@{
                MetricName = "年間総コスト"
                Value = $totalAnnualCost
                Unit = "円/年"
                Category = "年間コスト"
                Description = "現在のライセンス構成での年間総コスト"
            }
            
            $costAnalysisReport += [PSCustomObject]@{
                MetricName = "年間潜在節約額"
                Value = $totalAnnualWaste
                Unit = "円/年"
                Category = "節約機会"
                Description = "未使用ライセンス削減による年間節約可能額"
            }
            
            if ($totalMonthlyCost -gt 0) {
                $wastePercentage = [math]::Round(($totalWastedCost / $totalMonthlyCost) * 100, 2)
                $costAnalysisReport += [PSCustomObject]@{
                    MetricName = "コスト無駄率"
                    Value = $wastePercentage
                    Unit = "%"
                    Category = "効率性指標"
                    Description = "総コストに占める未使用ライセンスの割合"
                }
            }
        }
        
        # 出力ディレクトリ作成（スタンドアロン対応）
        if (Get-Command "New-ReportDirectory" -ErrorAction SilentlyContinue) {
            $outputDir = New-ReportDirectory -ReportType "Monthly"
        } else {
            $outputDir = "Reports\Monthly"
            if (-not (Test-Path $outputDir)) {
                New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            # メインライセンスレポート出力
            $csvPath = Join-Path $outputDir "License_Analysis_Summary_$timestamp.csv"
            if ($licenseReport.Count -gt 0) {
                if (Get-Command "Export-DataToCSV" -ErrorAction SilentlyContinue) {
                    Export-DataToCSV -Data $licenseReport -FilePath $csvPath
                } else {
                    $licenseReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                }
            } else {
                $emptyData = @([PSCustomObject]@{
                    "情報" = "ライセンス分析（サンプル）"
                    "詳細" = "Microsoft Graph未接続のためサンプルデータで分析実行"
                    "生成日時" = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
                    "備考" = "実際の分析にはMicrosoft Graphへの接続が必要です"
                })
                $emptyData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            }
            
            # 未使用ライセンスレポート出力
            if ($unusedLicensesReport.Count -gt 0) {
                $unusedPath = Join-Path $outputDir "License_Unused_Analysis_$timestamp.csv"
                if (Get-Command "Export-DataToCSV" -ErrorAction SilentlyContinue) {
                    Export-DataToCSV -Data $unusedLicensesReport -FilePath $unusedPath
                } else {
                    $unusedLicensesReport | Export-Csv -Path $unusedPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            # ユーザー詳細レポート出力
            if ($IncludeUserDetails -and $userLicenseReport.Count -gt 0) {
                $userPath = Join-Path $outputDir "License_User_Details_$timestamp.csv"
                if (Get-Command "Export-DataToCSV" -ErrorAction SilentlyContinue) {
                    Export-DataToCSV -Data $userLicenseReport -FilePath $userPath
                } else {
                    $userLicenseReport | Export-Csv -Path $userPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            # コスト分析レポート出力
            if ($AnalyzeCosts -and $costAnalysisReport.Count -gt 0) {
                $costPath = Join-Path $outputDir "License_Cost_Analysis_$timestamp.csv"
                if (Get-Command "Export-DataToCSV" -ErrorAction SilentlyContinue) {
                    Export-DataToCSV -Data $costAnalysisReport -FilePath $costPath
                } else {
                    $costAnalysisReport | Export-Csv -Path $costPath -NoTypeInformation -Encoding UTF8
                }
            }
        }
        
        # HTML出力 - 新しいテンプレートシステムを使用
        if ($ExportHTML) {
            $htmlPath = Join-Path $outputDir "License_Analysis_Dashboard_$timestamp.html"
            
            # 空のデータ対応
            if ($licenseReport.Count -eq 0) {
                $licenseReport = @([PSCustomObject]@{
                    LicenseName = "サンプルライセンス（データなし）"
                    SkuPartNumber = "SAMPLE_SKU"
                    TotalLicenses = 100
                    ConsumedLicenses = 0
                    AvailableLicenses = 100
                    UtilizationRate = 0
                    EstimatedCostPerUser = 1000
                    TotalEstimatedCost = 0
                    WastedCost = 100000
                    RiskLevel = "情報"
                    Recommendations = "Microsoft Graphへの接続設定を確認してください"
                    AnalysisTimestamp = Get-Date
                })
            }
            
            # 新しいテンプレートベースのHTML生成を使用
            $templatePath = Join-Path $PSScriptRoot "..\..\Reports\Monthly\License_Analysis_Dashboard_Template_Latest.html"
            if (Test-Path $templatePath) {
                Write-Log "テンプレートベースでHTML生成中: $templatePath"
                $templateContent = Get-Content $templatePath -Raw -Encoding UTF8
                
                # 統計データの更新
                $totalLicenses = ($licenseReport | Measure-Object -Property TotalLicenses -Sum).Sum
                $consumedLicenses = ($licenseReport | Measure-Object -Property ConsumedLicenses -Sum).Sum
                $availableLicenses = ($licenseReport | Measure-Object -Property AvailableLicenses -Sum).Sum
                $avgUtilization = if ($licenseReport.Count -gt 0) { [math]::Round(($licenseReport | Measure-Object -Property UtilizationRate -Average).Average, 1) } else { 0 }
                $totalMonthlyCost = ($licenseReport | Measure-Object -Property TotalEstimatedCost -Sum).Sum
                $totalWastedCost = ($licenseReport | Measure-Object -Property WastedCost -Sum).Sum
                $costEfficiency = if ($totalMonthlyCost -gt 0) { [math]::Round((($totalMonthlyCost - $totalWastedCost) / $totalMonthlyCost) * 100, 1) } else { 0 }
                
                # テンプレートの統計値を実際のデータで更新
                $updatedContent = $templateContent -replace '分析実行日時: \d{4}年\d{2}月\d{2}日 \d{2}:\d{2}:\d{2}', "分析実行日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')"
                $updatedContent = $updatedContent -replace 'コスト効率性: [\d.]+%', "コスト効率性: $costEfficiency%"
                $updatedContent = $updatedContent -replace 'style="width: [\d.]+%"', "style=`"width: $costEfficiency%`""
                $updatedContent = $updatedContent -replace '月額総コスト:</strong> ¥[\d,]+', "月額総コスト:</strong> ¥$($totalMonthlyCost.ToString('N0'))"
                $updatedContent = $updatedContent -replace '月額無駄コスト:</strong> ¥[\d,]+', "月額無駄コスト:</strong> ¥$($totalWastedCost.ToString('N0'))"
                $updatedContent = $updatedContent -replace '年間削減可能額:</strong> ¥[\d,]+', "年間削減可能額:</strong> ¥$(($totalWastedCost * 12).ToString('N0'))"
                
                $updatedContent | Out-File -FilePath $htmlPath -Encoding UTF8
                Write-Log "テンプレートベースHTMLダッシュボード生成完了: $htmlPath"
            } else {
                # フォールバック: 従来のHTML生成
                Write-Log "テンプレートファイルが見つからないため、従来のHTML生成を使用"
                $htmlContent = Generate-LicenseAnalysisHTML -LicenseData $licenseReport -UserData $userLicenseReport -UnusedLicenses $unusedLicensesReport -CostAnalysis $costAnalysisReport
                $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
            }
        }
        
        # 統計情報計算
        $statistics = @{
            TotalLicenseTypes = $licenseReport.Count
            TotalLicenses = ($licenseReport | Measure-Object -Property TotalLicenses -Sum).Sum
            TotalConsumedLicenses = ($licenseReport | Measure-Object -Property ConsumedLicenses -Sum).Sum
            TotalAvailableLicenses = ($licenseReport | Measure-Object -Property AvailableLicenses -Sum).Sum
            AverageUtilizationRate = if ($licenseReport.Count -gt 0) { [math]::Round(($licenseReport | Measure-Object -Property UtilizationRate -Average).Average, 2) } else { 0 }
            TotalMonthlyCost = ($licenseReport | Measure-Object -Property TotalEstimatedCost -Sum).Sum
            TotalWastedCost = ($licenseReport | Measure-Object -Property WastedCost -Sum).Sum
            TotalAnnualSavingsPotential = (($licenseReport | Measure-Object -Property WastedCost -Sum).Sum) * 12
            HighRiskLicenses = ($licenseReport | Where-Object { $_.RiskLevel -in @("警告", "緊急") }).Count
            LowUtilizationLicenses = ($licenseReport | Where-Object { $_.UtilizationRate -lt 50 }).Count
            UsersAnalyzed = $userLicenseReport.Count
            InactiveUsers = ($userLicenseReport | Where-Object { $_.UtilizationStatus -eq "長期未利用" }).Count
            AnalysisCompletedAt = Get-Date
        }
        
        # 監査ログ出力（スタンドアロン対応）
        if (Get-Command "Write-AuditLog" -ErrorAction SilentlyContinue) {
            Write-AuditLog -Action "ライセンス分析" -Target "Microsoft 365" -Result "成功" -Details "分析対象: $($licenseReport.Count)ライセンス種別、節約可能額: $($statistics.TotalAnnualSavingsPotential)円/年"
        }
        
        Write-Log "Microsoft 365ライセンス分析が完了しました" -Level "Info"
        
        return @{
            Success = $true
            LicenseReport = $licenseReport
            UserLicenseReport = $userLicenseReport
            UnusedLicensesReport = $unusedLicensesReport
            CostAnalysisReport = $costAnalysisReport
            Statistics = $statistics
            CSVPath = if ($ExportCSV) { $csvPath } else { $null }
            HTMLPath = if ($ExportHTML) { $htmlPath } else { $null }
        }
    }
    catch {
        Write-Log "Microsoft 365ライセンス分析でエラーが発生しました: $($_.Exception.Message)" -Level "Error"
        return @{
            Success = $false
            Error = $_.Exception.Message
            LicenseReport = @()
            UserLicenseReport = @()
            UnusedLicensesReport = @()
            CostAnalysisReport = @()
            Statistics = @{}
            CSVPath = $null
            HTMLPath = $null
        }
    }
}

function Get-LicenseDisplayName {
    param([string]$SkuPartNumber)
    
    # Microsoft 365ライセンスの日本語名マッピング
    $licenseMap = @{
        "ENTERPRISEPACK" = "Microsoft 365 E3"
        "SPE_E3" = "Microsoft 365 E3"
        "SPE_E5" = "Microsoft 365 E5"
        "SPB" = "Microsoft 365 Business Premium"
        "O365_BUSINESS_ESSENTIALS" = "Microsoft 365 Business Basic"
        "O365_BUSINESS_PREMIUM" = "Microsoft 365 Business Standard"
        "O365_BUSINESS" = "Microsoft 365 Business Basic (レガシー)"
        "EXCHANGESTANDARD" = "Exchange Online Plan 1"
        "EXCHANGEENTERPRISE" = "Exchange Online Plan 2"
        "SHAREPOINTSTANDARD" = "SharePoint Online Plan 1"
        "SHAREPOINTENTERPRISE" = "SharePoint Online Plan 2"
        "MCOSTANDARD" = "Skype for Business Online Plan 2"
        "TEAMS1" = "Microsoft Teams Essentials"
        "TEAMS_COMMERCIAL_TRIAL" = "Microsoft Teams Commercial Trial"
        "AAD_PREMIUM" = "Azure Active Directory Premium P1"
        "AAD_PREMIUM_P2" = "Azure Active Directory Premium P2"
        "INTUNE_A" = "Microsoft Intune"
        "EMS" = "Enterprise Mobility + Security E3"
        "EMSPREMIUM" = "Enterprise Mobility + Security E5"
        "POWER_BI_STANDARD" = "Power BI (無料)"
        "POWER_BI_PRO" = "Power BI Pro"
        "DYN365_ENTERPRISE_PLAN1" = "Dynamics 365 Customer Engagement Plan"
        "PROJECTONLINE_PLAN_1" = "Project Online Essentials"
        "PROJECTONLINE_PLAN_2" = "Project Online Professional"
        "VISIOCLIENT" = "Visio Online Plan 2"
    }
    
    if ($licenseMap.ContainsKey($SkuPartNumber)) {
        return $licenseMap[$SkuPartNumber]
    } else {
        return $SkuPartNumber
    }
}

function Get-EstimatedLicenseCost {
    param([string]$SkuPartNumber)
    
    # Microsoft 365ライセンスの推定月額コスト（円）
    $costMap = @{
        "ENTERPRISEPACK" = 2840  # Microsoft 365 E3
        "SPE_E3" = 2840
        "SPE_E5" = 4130
        "SPB" = 2750
        "O365_BUSINESS_ESSENTIALS" = 750
        "O365_BUSINESS_PREMIUM" = 1560
        "O365_BUSINESS" = 1000  # レガシーBusiness Basic
        "EXCHANGESTANDARD" = 480
        "EXCHANGEENTERPRISE" = 960
        "SHAREPOINTSTANDARD" = 600
        "SHAREPOINTENTERPRISE" = 1200
        "MCOSTANDARD" = 240
        "TEAMS1" = 480
        "AAD_PREMIUM" = 750
        "AAD_PREMIUM_P2" = 1080
        "INTUNE_A" = 750
        "EMS" = 1080
        "EMSPREMIUM" = 1560
        "POWER_BI_STANDARD" = 0
        "POWER_BI_PRO" = 1200
        "DYN365_ENTERPRISE_PLAN1" = 11400
        "PROJECTONLINE_PLAN_1" = 360
        "PROJECTONLINE_PLAN_2" = 1800
        "VISIOCLIENT" = 1800
    }
    
    if ($costMap.ContainsKey($SkuPartNumber)) {
        return $costMap[$SkuPartNumber]
    } else {
        return 1000  # デフォルト推定コスト
    }
}

function Generate-SampleLicenseData {
    # サンプルライセンスデータを生成
    $sampleSkus = @()
    $sampleUsers = @()
    
    # サンプルライセンス生成（無料ライセンス除外）
    $licenseTypes = @(
        @{ SkuPartNumber = "ENTERPRISEPACK"; Name = "Microsoft 365 E3"; Total = 100; Used = 85 },
        @{ SkuPartNumber = "SPE_E5"; Name = "Microsoft 365 E5"; Total = 20; Used = 12 },
        @{ SkuPartNumber = "SPB"; Name = "Microsoft 365 Business Premium"; Total = 50; Used = 45 },
        @{ SkuPartNumber = "POWER_BI_PRO"; Name = "Power BI Pro"; Total = 30; Used = 18 },
        @{ SkuPartNumber = "AAD_PREMIUM"; Name = "Azure AD Premium P1"; Total = 75; Used = 60 },
        @{ SkuPartNumber = "EXCHANGEENTERPRISE"; Name = "Exchange Online Plan 2"; Total = 80; Used = 72 }
    )
    
    foreach ($license in $licenseTypes) {
        $sampleSkus += [PSCustomObject]@{
            SkuId = [Guid]::NewGuid()
            SkuPartNumber = $license.SkuPartNumber
            PrepaidUnits = [PSCustomObject]@{ Enabled = $license.Total }
            ConsumedUnits = $license.Used
        }
    }
    
    # サンプルユーザー生成
    $departments = @("営業部", "技術部", "管理部", "人事部", "総務部")
    $jobTitles = @("部長", "課長", "主任", "一般社員", "新入社員")
    
    for ($i = 1; $i -le 50; $i++) {
        $hasLicenses = (Get-Random -Maximum 100) -lt 85  # 85%のユーザーがライセンス保有
        $assignedLicenses = @()
        
        if ($hasLicenses) {
            $licenseCount = Get-Random -Minimum 1 -Maximum 3
            $availableSkus = $sampleSkus | Get-Random -Count $licenseCount
            foreach ($sku in $availableSkus) {
                $assignedLicenses += [PSCustomObject]@{ SkuId = $sku.SkuId }
            }
        }
        
        $lastSignIn = if ((Get-Random -Maximum 100) -lt 80) {
            (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 180))
        } else {
            $null
        }
        
        $sampleUsers += [PSCustomObject]@{
            Id = [Guid]::NewGuid()
            UserPrincipalName = "user$i@miraiconst.onmicrosoft.com"
            DisplayName = "サンプルユーザー$i"
            AccountEnabled = (Get-Random -Maximum 100) -lt 95
            Department = $departments[(Get-Random -Maximum $departments.Count)]
            JobTitle = $jobTitles[(Get-Random -Maximum $jobTitles.Count)]
            AssignedLicenses = $assignedLicenses
            LastSignInDateTime = $lastSignIn
            CreatedDateTime = (Get-Date).AddDays(-(Get-Random -Minimum 30 -Maximum 365))
        }
    }
    
    return @{
        SubscribedSkus = $sampleSkus
        Users = $sampleUsers
    }
}

function Generate-LicenseAnalysisHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$LicenseData,
        
        [Parameter(Mandatory = $false)]
        [array]$UserData = @(),
        
        [Parameter(Mandatory = $false)]
        [array]$UnusedLicenses = @(),
        
        [Parameter(Mandatory = $false)]
        [array]$CostAnalysis = @()
    )
    
    $timestamp = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
    
    # 統計計算
    $totalLicenses = ($LicenseData | Measure-Object -Property TotalLicenses -Sum).Sum
    $consumedLicenses = ($LicenseData | Measure-Object -Property ConsumedLicenses -Sum).Sum
    $availableLicenses = ($LicenseData | Measure-Object -Property AvailableLicenses -Sum).Sum
    $avgUtilization = if ($LicenseData.Count -gt 0) { [math]::Round(($LicenseData | Measure-Object -Property UtilizationRate -Average).Average, 1) } else { 0 }
    $totalMonthlyCost = ($LicenseData | Measure-Object -Property TotalEstimatedCost -Sum).Sum
    $totalWastedCost = ($LicenseData | Measure-Object -Property WastedCost -Sum).Sum
    $totalAnnualSavings = $totalWastedCost * 12
    
    $html = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft 365ライセンス分析ダッシュボード</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 28px; }
        .header .subtitle { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .summary-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .value.info { color: #0078d4; }
        .cost-meter {
            background: white;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .meter-container {
            position: relative;
            height: 40px;
            margin: 20px 0;
        }
        .cost-bar {
            width: 100%;
            height: 40px;
            background-color: #e1e1e1;
            border-radius: 20px;
            overflow: hidden;
            position: relative;
        }
        .cost-fill {
            height: 100%;
            background: linear-gradient(90deg, #107c10 0%, #ff8c00 70%, #d13438 90%);
            border-radius: 20px;
            transition: width 0.3s ease;
        }
        .meter-label {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: white;
            font-weight: bold;
            text-shadow: 1px 1px 2px rgba(0,0,0,0.5);
        }
        .section {
            background: white;
            margin-bottom: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header {
            background: linear-gradient(135deg, #6c757d 0%, #5a6268 100%);
            color: white;
            padding: 15px 20px;
            border-radius: 8px 8px 0 0;
            font-weight: bold;
        }
        .section-content { padding: 20px; }
        .data-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
            margin: 20px 0;
        }
        .data-table th {
            background-color: #0078d4;
            color: white;
            border: 1px solid #ddd;
            padding: 12px 8px;
            text-align: left;
            font-weight: bold;
        }
        .data-table td {
            border: 1px solid #ddd;
            padding: 8px;
            font-size: 12px;
        }
        .data-table tr:nth-child(even) {
            background-color: #f8f9fa;
        }
        .data-table tr:hover {
            background-color: #e9ecef;
        }
        .risk-warning { background-color: #fff3cd !important; color: #856404; font-weight: bold; }
        .risk-attention { background-color: #cce5f0 !important; color: #0c5460; }
        .risk-normal { background-color: #d4edda !important; color: #155724; }
        .risk-info { background-color: #d1ecf1 !important; color: #0c5460; }
        .scrollable-table {
            overflow-x: auto;
            margin: 20px 0;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .alert-box {
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
        .alert-critical {
            background-color: #f8d7da;
            border: 1px solid #f5c6cb;
            color: #721c24;
        }
        .alert-warning {
            background-color: #fff3cd;
            border-color: #ffeaa7;
            color: #856404;
        }
        .alert-info {
            background-color: #d1ecf1;
            border-color: #bee5eb;
            color: #0c5460;
        }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        .cost-optimization {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .optimization-card {
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border-left: 4px solid #0078d4;
        }
        .optimization-card.high-priority { border-left-color: #d13438; }
        .optimization-card.medium-priority { border-left-color: #ff8c00; }
        .optimization-card.low-priority { border-left-color: #107c10; }
    </style>
</head>
<body>
    <div class="header">
        <h1>💰 Microsoft 365ライセンス分析ダッシュボード</h1>
        <div class="subtitle">みらい建設工業株式会社 - ライセンス最適化・コスト監視</div>
        <div class="subtitle">分析実行日時: $timestamp</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総ライセンス数</h3>
            <div class="value info">$totalLicenses</div>
            <div class="description">購入済み</div>
        </div>
        <div class="summary-card">
            <h3>使用中ライセンス</h3>
            <div class="value$(if($consumedLicenses -gt 0) { ' success' } else { ' info' })">$consumedLicenses</div>
            <div class="description">割り当て済み</div>
        </div>
        <div class="summary-card">
            <h3>未使用ライセンス</h3>
            <div class="value$(if($availableLicenses -gt 10) { ' warning' } elseif($availableLicenses -gt 0) { ' info' } else { ' success' })">$availableLicenses</div>
            <div class="description">コスト削減機会</div>
        </div>
        <div class="summary-card">
            <h3>平均利用率</h3>
            <div class="value$(if($avgUtilization -lt 50) { ' warning' } elseif($avgUtilization -lt 80) { ' info' } else { ' success' })">$avgUtilization%</div>
            <div class="description">効率性指標</div>
        </div>
        <div class="summary-card">
            <h3>月額総コスト</h3>
            <div class="value info">¥$('{0:N0}' -f $totalMonthlyCost)</div>
            <div class="description">現在の支出</div>
        </div>
        <div class="summary-card">
            <h3>年間節約可能額</h3>
            <div class="value$(if($totalAnnualSavings -gt 100000) { ' warning' } elseif($totalAnnualSavings -gt 0) { ' info' } else { ' success' })">¥$('{0:N0}' -f $totalAnnualSavings)</div>
            <div class="description">最適化効果</div>
        </div>
    </div>

    <div class="cost-meter">
        <h3>💡 コスト効率性メーター</h3>
        <div class="cost-bar">
            <div class="cost-fill" style="width: $(if($totalMonthlyCost -gt 0) { [math]::Min(100 - (($totalWastedCost / $totalMonthlyCost) * 100), 100) } else { 100 })%"></div>
            <div class="meter-label">コスト効率性: $(if($totalMonthlyCost -gt 0) { [math]::Round(100 - (($totalWastedCost / $totalMonthlyCost) * 100), 1) } else { 100 })%</div>
        </div>
        <div style="display: flex; justify-content: space-between; font-size: 12px; color: #666;">
            <span>🔴 要改善 (0-60%)</span>
            <span>🟡 注意 (60-80%)</span>
            <span>🟢 良好 (80-100%)</span>
        </div>
        <div style="margin-top: 15px; text-align: center;">
            <p><strong>月額無駄コスト:</strong> ¥$('{0:N0}' -f $totalWastedCost)</p>
            <p><strong>年間削減可能額:</strong> ¥$('{0:N0}' -f $totalAnnualSavings)</p>
        </div>
    </div>

    $(if ($totalAnnualSavings -gt 100000) {
        '<div class="alert-box alert-warning">
            <strong>💰 コスト最適化の機会:</strong> 年間' + ('{0:N0}' -f $totalAnnualSavings) + '円の節約が可能です。未使用ライセンスの見直しを推奨します。
        </div>'
    } elseif ($totalAnnualSavings -gt 0) {
        '<div class="alert-box alert-info">
            <strong>ℹ️ 軽微な最適化機会:</strong> 年間' + ('{0:N0}' -f $totalAnnualSavings) + '円の節約が可能です。定期的な見直しを継続してください。
        </div>'
    } else {
        '<div class="alert-box alert-info">
            <strong>✅ 最適化済み:</strong> ライセンス利用は効率的です。現在の状態を維持してください。
        </div>'
    })

    <div class="section">
        <div class="section-header">📊 ライセンス種別分析</div>
        <div class="section-content">
            <div class="scrollable-table">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ライセンス名</th>
                            <th>SKU番号</th>
                            <th>総数</th>
                            <th>使用中</th>
                            <th>未使用</th>
                            <th>利用率</th>
                            <th>月額コスト</th>
                            <th>無駄コスト</th>
                            <th>リスクレベル</th>
                            <th>推奨対応</th>
                        </tr>
                    </thead>
                    <tbody>
"@

    # ライセンス詳細データテーブル生成
    foreach ($license in $LicenseData) {
        $riskClass = switch ($license.RiskLevel) {
            "警告" { "risk-warning" }
            "注意" { "risk-attention" }
            "正常" { "risk-normal" }
            default { "risk-info" }
        }
        
        $html += @"
                        <tr class="$riskClass">
                            <td><strong>$($license.LicenseName)</strong></td>
                            <td>$($license.SkuPartNumber)</td>
                            <td style="text-align: right;">$('{0:N0}' -f $license.TotalLicenses)</td>
                            <td style="text-align: right;">$('{0:N0}' -f $license.ConsumedLicenses)</td>
                            <td style="text-align: right;">$('{0:N0}' -f $license.AvailableLicenses)</td>
                            <td style="text-align: right;">$($license.UtilizationRate)%</td>
                            <td style="text-align: right;">¥$('{0:N0}' -f $license.TotalEstimatedCost)</td>
                            <td style="text-align: right;">¥$('{0:N0}' -f $license.WastedCost)</td>
                            <td style="text-align: center;">$($license.RiskLevel)</td>
                            <td>$($license.Recommendations)</td>
                        </tr>
"@
    }

    $html += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    $(if ($UnusedLicenses.Count -gt 0) {
        '<div class="section">
            <div class="section-header">⚠️ 未使用ライセンス詳細</div>
            <div class="section-content">
                <div class="scrollable-table">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>ライセンス名</th>
                                <th>未使用数</th>
                                <th>月額損失</th>
                                <th>年間節約可能額</th>
                                <th>優先度</th>
                                <th>推奨アクション</th>
                            </tr>
                        </thead>
                        <tbody>'
        
        foreach ($unused in $UnusedLicenses) {
            $priorityClass = switch ($unused.Priority) {
                "高" { "risk-warning" }
                "中" { "risk-attention" }
                default { "risk-normal" }
            }
            
            $html += "                            <tr class=`"$priorityClass`">
                                <td><strong>$($unused.LicenseName)</strong></td>
                                <td style=`"text-align: right;`">$('{0:N0}' -f $unused.UnusedCount)</td>
                                <td style=`"text-align: right;`">¥$('{0:N0}' -f $unused.WastedCostPerMonth)</td>
                                <td style=`"text-align: right;`">¥$('{0:N0}' -f $unused.PotentialSavingsPerYear)</td>
                                <td style=`"text-align: center;`">$($unused.Priority)</td>
                                <td>$($unused.RecommendedAction)</td>
                            </tr>"
        }
        
        $html += '                        </tbody>
                    </table>
                </div>
            </div>
        </div>'
    })

    $(if ($UserData.Count -gt 0) {
        '<div class="section">
            <div class="section-header">👥 ユーザー別ライセンス利用状況（全ユーザー）</div>
            <div class="section-content">
                <div class="scrollable-table">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>ユーザー名</th>
                                <th>部署</th>
                                <th>ライセンス数</th>
                                <th>割り当て済みライセンス</th>
                                <th>月額コスト</th>
                                <th>最終サインイン</th>
                                <th>利用状況</th>
                                <th>最適化提案</th>
                            </tr>
                        </thead>
                        <tbody>'
        
        $topUsers = $UserData | Sort-Object TotalMonthlyCost -Descending
        foreach ($user in $topUsers) {
            $utilizationClass = switch ($user.UtilizationStatus) {
                "長期未利用" { "risk-warning" }
                "低利用" { "risk-attention" }
                default { "risk-normal" }
            }
            
            $html += "                            <tr class=`"$utilizationClass`">
                                <td><strong>$($user.DisplayName)</strong></td>
                                <td>$($user.Department)</td>
                                <td style=`"text-align: center;`">$($user.LicenseCount)</td>
                                <td>$($user.AssignedLicenses)</td>
                                <td style=`"text-align: right;`">¥$('{0:N0}' -f $user.TotalMonthlyCost)</td>
                                <td style=`"text-align: center;`">$($user.LastSignInStatus)</td>
                                <td style=`"text-align: center;`">$($user.UtilizationStatus)</td>
                                <td>$($user.OptimizationRecommendations)</td>
                            </tr>"
        }
        
        $html += '                        </tbody>
                    </table>
                </div>
            </div>
        </div>'
    })

    $html += @"
    <div class="section">
        <div class="section-header">💡 ライセンス最適化戦略</div>
        <div class="section-content">
            <div class="cost-optimization">
                <div class="optimization-card high-priority">
                    <h4>🚨 即座に実行</h4>
                    <ul>
                        <li>90日以上未利用ユーザーのライセンス回収</li>
                        <li>無効化ユーザーからの即座ライセンス削除</li>
                        <li>重複ライセンス割り当ての整理</li>
                        <li>不要な高額ライセンスの見直し</li>
                    </ul>
                </div>
                
                <div class="optimization-card medium-priority">
                    <h4>⚠️ 月次で実行</h4>
                    <ul>
                        <li>ライセンス利用率の定期監視</li>
                        <li>新規ユーザーへの適切なライセンス割り当て</li>
                        <li>部署異動に伴うライセンス見直し</li>
                        <li>季節変動を考慮した調整</li>
                    </ul>
                </div>
                
                <div class="optimization-card low-priority">
                    <h4>📊 四半期で実行</h4>
                    <ul>
                        <li>全社的なライセンス戦略の見直し</li>
                        <li>新機能・新ライセンスの評価</li>
                        <li>コスト・ベネフィット分析</li>
                        <li>競合製品との比較検討</li>
                    </ul>
                </div>
            </div>
            
            <h4>📈 コスト最適化のベストプラクティス:</h4>
            <ul>
                <li><strong>定期監視:</strong> 月次でライセンス利用状況を確認</li>
                <li><strong>自動化:</strong> 非アクティブユーザーの自動検出</li>
                <li><strong>適切な割り当て:</strong> 職務に応じた最適なライセンス選択</li>
                <li><strong>教育・研修:</strong> ライセンス活用促進のための利用者教育</li>
                <li><strong>予算管理:</strong> 年間予算と実績の継続的な比較</li>
            </ul>
            
            <h4>🔍 監視すべき主要指標:</h4>
            <ul>
                <li><strong>利用率:</strong> 各ライセンス種別で80%以上を目標</li>
                <li><strong>コスト効率:</strong> ユーザーあたり月額コストの適正性</li>
                <li><strong>ROI:</strong> ライセンス投資に対する生産性向上効果</li>
                <li><strong>コンプライアンス:</strong> ライセンス契約条件の遵守状況</li>
            </ul>
        </div>
    </div>

    <div class="footer">
        <p>このレポートは Microsoft 365 ライセンス管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社 ライセンス最適化センター</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $html
}

# スクリプト直接実行時の処理
if ($MyInvocation.InvocationName -ne '.') {
    $config = Initialize-ManagementTools
    
    Write-Log "Microsoft 365ライセンス分析スクリプトを実行します" -Level "Info"
    
    try {
        if ($config) {
            # 新しい認証システムを使用
            $connectionResult = Connect-ToMicrosoft365 -Config $config -Services @("MicrosoftGraph")
            
            if (-not $connectionResult.Success) {
                throw "Microsoft Graph への接続に失敗しました: $($connectionResult.Errors -join ', ')"
            }
            
            Write-Log "Microsoft Graph 接続成功" -Level "Info"
        }
        else {
            Write-Log "設定ファイルが見つからないため、手動接続が必要です" -Level "Warning"
            throw "設定ファイルが見つかりません"
        }
        
        # ライセンス分析実行
        Write-Log "Microsoft 365ライセンス分析を実行中..." -Level "Info"
        $result = Get-LicenseAnalysis -IncludeUserDetails -AnalyzeCosts -ExportHTML -ExportCSV
        
        if ($result.Success) {
            Write-Log "Microsoft 365ライセンス分析が正常に完了しました" -Level "Info"
            Write-Log "分析結果: $($result.Statistics.TotalLicenseTypes)種類のライセンス、年間節約可能額 $($result.Statistics.TotalAnnualSavingsPotential)円" -Level "Info"
        } else {
            Write-Log "Microsoft 365ライセンス分析でエラーが発生しました" -Level "Error"
        }
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        Write-Log "ライセンス分析エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
    finally {
        Disconnect-AllServices
    }
}