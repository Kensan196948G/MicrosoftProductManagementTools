# ================================================================================
# データソース可視化モジュール
# 実データ取得状況をプロンプト上で詳細表示
# ================================================================================

function Show-DataSourceStatus {
    <#
    .SYNOPSIS
    データ取得状況の詳細表示
    #>
    param(
        [string]$DataType,
        [string]$Status,
        [int]$RecordCount = 0,
        [string]$Source = "Unknown",
        [hashtable]$Details = @{}
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    # ステータスに応じた色とアイコン
    switch ($Status) {
        "ConnectingToM365" {
            Write-Host "[$timestamp] 🔄 Microsoft 365 接続中..." -ForegroundColor Yellow
        }
        "ConnectingToExchange" {
            Write-Host "[$timestamp] 📧 Exchange Online 接続中..." -ForegroundColor Yellow
        }
        "RealDataSuccess" {
            Write-Host "[$timestamp] ✅ 実データ取得成功" -ForegroundColor Green
            if (Get-Command Write-ModuleLog -ErrorAction SilentlyContinue) {
                Write-ModuleLog "    📊 データ種別: $DataType" "INFO"
                Write-ModuleLog "    📈 取得件数: $RecordCount 件" "INFO"
                Write-ModuleLog "    🎯 データソース: $Source" "INFO"
            } else {
                Write-Host "    📊 データ種別: $DataType" -ForegroundColor Cyan
                Write-Host "    📈 取得件数: $RecordCount 件" -ForegroundColor Cyan
                Write-Host "    🎯 データソース: $Source" -ForegroundColor Cyan
            }
            if ($Details.Count -gt 0) {
                Write-Host "    🔍 詳細情報:" -ForegroundColor Gray
                foreach ($key in $Details.Keys) {
                    Write-Host "      $key : $($Details[$key])" -ForegroundColor Gray
                }
            }
        }
        "FallbackToE3" {
            if (Get-Command Write-ModuleLog -ErrorAction SilentlyContinue) {
                Write-ModuleLog "🔄 E3ライセンス対応モードに切り替え" "INFO"
            } else {
                Write-Host "[$timestamp] 🔄 E3ライセンス対応モードに切り替え" -ForegroundColor Yellow
            }
            if (Get-Command Write-ModuleLog -ErrorAction SilentlyContinue) {
                Write-ModuleLog "    📊 データ種別: $DataType" "INFO"
                Write-ModuleLog "    📈 取得件数: $RecordCount 件" "INFO"
                Write-ModuleLog "    🎯 データソース: $Source" "INFO"
            } else {
                Write-Host "    📊 データ種別: $DataType" -ForegroundColor Cyan
                Write-Host "    📈 取得件数: $RecordCount 件" -ForegroundColor Cyan
                Write-Host "    🎯 データソース: $Source" -ForegroundColor Cyan
            }
        }
        "FallbackToDummy" {
            Write-Host "[$timestamp] ⚠️ ダミーデータモードで動作" -ForegroundColor Yellow
            Write-Host "    📊 データ種別: $DataType" -ForegroundColor Cyan
            Write-Host "    📈 生成件数: $RecordCount 件" -ForegroundColor Cyan
            Write-Host "    🎯 データソース: $Source" -ForegroundColor Cyan
        }
        "AuthenticationRequired" {
            Write-Host "[$timestamp] 🔐 認証が必要です" -ForegroundColor Red
            Write-Host "    📊 データ種別: $DataType" -ForegroundColor Cyan
            Write-Host "    ⚠️ Microsoft 365 への接続が必要です" -ForegroundColor Yellow
        }
        "Error" {
            Write-Host "[$timestamp] ❌ エラーが発生しました" -ForegroundColor Red
            Write-Host "    📊 データ種別: $DataType" -ForegroundColor Cyan
            Write-Host "    🎯 データソース: $Source" -ForegroundColor Cyan
            if ($Details.ContainsKey("ErrorMessage")) {
                Write-Host "    ⚠️ エラー内容: $($Details["ErrorMessage"])" -ForegroundColor Yellow
            }
        }
    }
}

function Show-ConnectionStatus {
    <#
    .SYNOPSIS
    Microsoft 365 接続状況の詳細表示
    #>
    param()
    
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    Write-Host "🔍 Microsoft 365 接続状況 - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "="*80 -ForegroundColor Cyan
    
    # Microsoft Graph 接続状況
    try {
        $graphContext = Get-MgContext -ErrorAction SilentlyContinue
        if ($graphContext) {
            Write-Host "✅ Microsoft Graph: 接続済み" -ForegroundColor Green
            Write-Host "   👤 アカウント: $($graphContext.Account)" -ForegroundColor Gray
            Write-Host "   🏢 テナント: $($graphContext.TenantId)" -ForegroundColor Gray
            Write-Host "   🎯 スコープ: $($graphContext.Scopes -join ', ')" -ForegroundColor Gray
        } else {
            Write-Host "❌ Microsoft Graph: 未接続" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Microsoft Graph: 未接続" -ForegroundColor Red
    }
    
    # Exchange Online 接続状況
    try {
        $exchangeSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq "Microsoft.Exchange" -and $_.State -eq "Opened" }
        if ($exchangeSession) {
            Write-Host "✅ Exchange Online: 接続済み" -ForegroundColor Green
            Write-Host "   🌐 接続先: $($exchangeSession.ComputerName)" -ForegroundColor Gray
        } else {
            Write-Host "❌ Exchange Online: 未接続" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Exchange Online: 未接続" -ForegroundColor Red
    }
    
    # ライセンス情報
    try {
        $licenses = Get-MgSubscribedSku -ErrorAction SilentlyContinue
        if ($licenses) {
            Write-Host "📋 ライセンス情報:" -ForegroundColor Cyan
            foreach ($license in $licenses) {
                $skuName = switch ($license.SkuPartNumber) {
                    "ENTERPRISEPACK" { "Microsoft 365 E3" }
                    "ENTERPRISEPREMIUM" { "Microsoft 365 E5" }
                    "SPE_E3" { "Microsoft 365 E3" }
                    "SPE_E5" { "Microsoft 365 E5" }
                    default { $license.SkuPartNumber }
                }
                Write-Host "   📦 $skuName : $($license.ConsumedUnits)/$($license.PrepaidUnits.Enabled) 使用中" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "⚠️ ライセンス情報: 取得できませんでした" -ForegroundColor Yellow
    }
    
    Write-Host "="*80 -ForegroundColor Cyan
}

function Show-DataSummary {
    <#
    .SYNOPSIS
    データ取得結果のサマリー表示
    #>
    param(
        [array]$Data,
        [string]$DataType,
        [string]$Source = "Unknown"
    )
    
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "📊 データ取得結果サマリー" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    Write-Host "🎯 データ種別: $DataType" -ForegroundColor White
    Write-Host "📈 取得件数: $($Data.Count) 件" -ForegroundColor White
    Write-Host "🔗 データソース: $Source" -ForegroundColor White
    
    if ($Data.Count -gt 0) {
        Write-Host "📋 データ項目:" -ForegroundColor Yellow
        $properties = $Data[0].PSObject.Properties.Name
        foreach ($prop in $properties) {
            Write-Host "   • $prop" -ForegroundColor Gray
        }
        
        Write-Host "📝 サンプルデータ (最初の3件):" -ForegroundColor Yellow
        $sampleCount = [Math]::Min(3, $Data.Count)
        for ($i = 0; $i -lt $sampleCount; $i++) {
            Write-Host "   [$($i + 1)] " -ForegroundColor Cyan -NoNewline
            $sampleData = $Data[$i]
            # 主要なプロパティを表示
            $mainProp = $properties[0]
            if ($sampleData.$mainProp) {
                Write-Host "$($sampleData.$mainProp)" -ForegroundColor White
            } else {
                Write-Host "データなし" -ForegroundColor Gray
            }
        }
        
        # データの品質チェック
        if ($Source -eq "Microsoft 365 API") {
            Write-Host "✅ 実データ取得成功" -ForegroundColor Green
        } elseif ($Source -eq "E3ライセンス対応") {
            Write-Host "🔄 E3ライセンス対応データ" -ForegroundColor Yellow
        } else {
            Write-Host "⚠️ フォールバックデータ" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ データが取得できませんでした" -ForegroundColor Red
    }
    
    Write-Host "="*60 -ForegroundColor Cyan
}

# 実データ検証関数
function Test-RealDataQuality {
    <#
    .SYNOPSIS
    取得したデータが実データかダミーデータかを判定
    #>
    param(
        [array]$Data,
        [string]$DataType
    )
    
    if (-not $Data -or $Data.Count -eq 0) {
        return @{
            IsRealData = $false
            Confidence = 0
            Reason = "データが空です"
        }
    }
    
    $confidence = 0
    $reasons = @()
    
    # データ種別に応じた実データ判定
    switch ($DataType) {
        "Users" {
            # ユーザーデータの実データ判定
            if ($Data[0].UserPrincipalName -match "@.*\.onmicrosoft\.com$") {
                $confidence += 50
                $reasons += "実際のテナントドメインを使用"
            }
            if ($Data.Count -gt 10) {
                $confidence += 30
                $reasons += "十分なデータ件数"
            }
            if ($Data[0].CreatedDateTime -and $Data[0].CreatedDateTime -ne "N/A") {
                $confidence += 20
                $reasons += "実際の作成日時データ"
            }
        }
        "DailyReport" {
            # 日次レポートの実データ判定
            if ($Data[0].ActiveUsersCount -gt 0) {
                $confidence += 40
                $reasons += "実際のアクティブユーザー数"
            }
            if ($Data[0].LastCheck -and $Data[0].LastCheck -match (Get-Date -Format "yyyy-MM-dd")) {
                $confidence += 30
                $reasons += "最新の確認日時"
            }
            if ($Data[0].ServiceName -eq "Microsoft 365") {
                $confidence += 30
                $reasons += "正しいサービス名"
            }
            # 実データベース推定値の場合は信頼度を調整
            if ($Data[0].ActiveUsersCount -gt 300) {
                $confidence += 20
                $reasons += "実テナント規模に適合"
            }
        }
        default {
            # 汎用的な実データ判定
            if ($Data.Count -gt 5) {
                $confidence += 25
                $reasons += "十分なデータ件数"
            }
            if ($Data[0].PSObject.Properties.Name.Count -gt 3) {
                $confidence += 25
                $reasons += "詳細なプロパティ"
            }
        }
    }
    
    return @{
        IsRealData = $confidence -gt 50
        Confidence = $confidence
        Reason = $reasons -join ", "
    }
}

Export-ModuleMember -Function Show-DataSourceStatus, Show-ConnectionStatus, Show-DataSummary, Test-RealDataQuality