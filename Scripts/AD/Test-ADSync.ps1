# ================================================================================
# Test-ADSync.ps1
# Active DirectoryとEntra IDの同期状況確認
# ================================================================================

[CmdletBinding()]
param()

# 共通モジュールのインポート
$CommonPath = Join-Path $PSScriptRoot "..\Common"
Import-Module "$CommonPath\Logging.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$CommonPath\ErrorHandling.psm1" -Force -ErrorAction SilentlyContinue

function Test-ADDirectorySync {
    <#
    .SYNOPSIS
    Active DirectoryとEntra IDの同期状況を確認
    
    .DESCRIPTION
    AD ConnectまたはEntra ID Connectの同期状況を確認し、
    最新の同期実行時刻や同期エラーの有無を分析します
    
    .EXAMPLE
    Test-ADDirectorySync
    #>
    
    Write-Host "🔄 Active Directory - Entra ID 同期状況確認" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Microsoft Graph接続確認
        Write-Host "📡 Microsoft Graph API 接続確認中..." -ForegroundColor Yellow
        
        try {
            $context = Get-MgContext -ErrorAction SilentlyContinue
            if (-not $context) {
                Write-Host "⚠️  Microsoft Graph未接続 - 認証が必要です" -ForegroundColor Yellow
                Write-Host "   手動でConnect-MgGraphを実行してください" -ForegroundColor Gray
                return
            }
            
            Write-Host "✅ Microsoft Graph接続確認完了" -ForegroundColor Green
            Write-Host "   テナント: $($context.TenantId)" -ForegroundColor Gray
            Write-Host ""
        }
        catch {
            Write-Host "❌ Microsoft Graph接続エラー: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
        
        # ディレクトリ同期状況の取得
        Write-Host "🔍 ディレクトリ同期状況を確認中..." -ForegroundColor Yellow
        
        try {
            # 組織情報の取得
            $orgInfo = Get-MgOrganization -Property Id,DisplayName,OnPremisesSyncEnabled,OnPremisesLastSyncDateTime
            
            Write-Host "📋 組織情報:" -ForegroundColor Cyan
            Write-Host "   組織名: $($orgInfo.DisplayName)" -ForegroundColor White
            Write-Host "   テナントID: $($orgInfo.Id)" -ForegroundColor White
            
            if ($orgInfo.OnPremisesSyncEnabled) {
                Write-Host "   🔄 オンプレミス同期: 有効" -ForegroundColor Green
                
                if ($orgInfo.OnPremisesLastSyncDateTime) {
                    $lastSync = [DateTime]::Parse($orgInfo.OnPremisesLastSyncDateTime)
                    $timeDiff = (Get-Date) - $lastSync
                    
                    Write-Host "   📅 最終同期日時: $($lastSync.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
                    
                    if ($timeDiff.TotalHours -lt 2) {
                        Write-Host "   ✅ 同期状況: 正常 (最終同期から $([Math]::Round($timeDiff.TotalMinutes, 0)) 分経過)" -ForegroundColor Green
                    }
                    elseif ($timeDiff.TotalHours -lt 24) {
                        Write-Host "   ⚠️  同期状況: 注意 (最終同期から $([Math]::Round($timeDiff.TotalHours, 1)) 時間経過)" -ForegroundColor Yellow
                    }
                    else {
                        Write-Host "   ❌ 同期状況: 警告 (最終同期から $([Math]::Round($timeDiff.TotalDays, 1)) 日経過)" -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "   ❌ 最終同期日時が取得できません" -ForegroundColor Red
                }
            }
            else {
                Write-Host "   ℹ️  オンプレミス同期: 無効 (クラウドオンリー)" -ForegroundColor Blue
            }
            
            Write-Host ""
        }
        catch {
            Write-Host "❌ ディレクトリ同期情報取得エラー: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
        }
        
        # 同期対象ユーザーの確認
        Write-Host "👥 同期対象ユーザー統計を確認中..." -ForegroundColor Yellow
        
        try {
            # オンプレミス由来のユーザー数
            $onPremUsers = Get-MgUser -Filter "onPremisesSyncEnabled eq true" -CountVariable onPremCount -ConsistencyLevel eventual -Top 1
            Write-Host "   🏢 オンプレミス同期ユーザー数: $onPremCount 人" -ForegroundColor White
            
            # クラウドオンリーユーザー数
            $cloudOnlyUsers = Get-MgUser -Filter "onPremisesSyncEnabled eq false" -CountVariable cloudOnlyCount -ConsistencyLevel eventual -Top 1
            Write-Host "   ☁️  クラウドオンリーユーザー数: $cloudOnlyCount 人" -ForegroundColor White
            
            $totalUsers = $onPremCount + $cloudOnlyCount
            if ($totalUsers -gt 0) {
                $syncPercentage = [Math]::Round(($onPremCount / $totalUsers) * 100, 1)
                Write-Host "   📊 同期率: $syncPercentage% ($onPremCount / $totalUsers)" -ForegroundColor White
            }
            
            Write-Host ""
        }
        catch {
            Write-Host "❌ ユーザー統計取得エラー: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
        }
        
        # 最近のディレクトリエラーの確認
        Write-Host "🔍 ディレクトリ同期エラーを確認中..." -ForegroundColor Yellow
        
        try {
            # Get-MgDirectoryAdministrativeUnit はサンプルとして使用
            # 実際の環境では適切な監査ログ確認APIを使用
            Write-Host "   ℹ️  詳細なエラー情報の確認には Azure AD Connect Health または" -ForegroundColor Blue
            Write-Host "      Azure ポータルの「Azure AD Connect」セクションをご確認ください" -ForegroundColor Blue
            Write-Host ""
        }
        catch {
            Write-Host "   ℹ️  ディレクトリエラー情報の自動取得はできませんでした" -ForegroundColor Blue
            Write-Host ""
        }
        
        # 推奨アクション
        Write-Host "💡 推奨アクション:" -ForegroundColor Cyan
        Write-Host "   1. Azure ポータルで Azure AD Connect Health を確認" -ForegroundColor White
        Write-Host "   2. オンプレミス AD Connect サーバーのイベントログを確認" -ForegroundColor White
        Write-Host "   3. 同期が24時間以上停止している場合は調査が必要" -ForegroundColor White
        Write-Host "   4. 定期的な同期状況モニタリングの実施" -ForegroundColor White
        Write-Host ""
        
        # レポート生成
        $reportData = [PSCustomObject]@{
            ReportDate = Get-Date
            OrganizationName = $orgInfo.DisplayName
            TenantId = $orgInfo.Id
            SyncEnabled = $orgInfo.OnPremisesSyncEnabled
            LastSyncDateTime = $orgInfo.OnPremisesLastSyncDateTime
            OnPremisesUserCount = $onPremCount
            CloudOnlyUserCount = $cloudOnlyCount
            TotalUserCount = $totalUsers
            SyncPercentage = if ($totalUsers -gt 0) { [Math]::Round(($onPremCount / $totalUsers) * 100, 1) } else { 0 }
        }
        
        # CSV・HTMLレポート生成
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $reportBaseName = "AD_Sync_Status_$timestamp"
        $csvPath = "Reports\Daily\$reportBaseName.csv"
        $htmlPath = "Reports\Daily\$reportBaseName.html"
        
        $reportDir = Split-Path $csvPath -Parent
        if (-not (Test-Path $reportDir)) {
            New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
        }
        
        # CSV出力
        $reportData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "📊 CSVレポートを出力しました: $csvPath" -ForegroundColor Green
        
        # HTMLレポート生成
        $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Active Directory 同期状況レポート</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; padding-bottom: 20px; border-bottom: 3px solid #0078d4; }
        .header h1 { color: #0078d4; margin: 0; font-size: 28px; }
        .header .subtitle { color: #666; margin: 10px 0 0 0; font-size: 16px; }
        .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }
        .status-card { padding: 20px; border-radius: 8px; text-align: center; }
        .status-success { background: linear-gradient(135deg, #4CAF50, #45a049); color: white; }
        .status-warning { background: linear-gradient(135deg, #ff9800, #f57c00); color: white; }
        .status-info { background: linear-gradient(135deg, #2196F3, #1976D2); color: white; }
        .status-card h3 { margin: 0 0 10px 0; font-size: 18px; }
        .status-card .value { font-size: 24px; font-weight: bold; margin: 10px 0; }
        .details-section { margin: 30px 0; }
        .details-title { font-size: 20px; color: #0078d4; margin-bottom: 15px; padding-bottom: 5px; border-bottom: 2px solid #e0e0e0; }
        .info-table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        .info-table th, .info-table td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        .info-table th { background-color: #f8f9fa; font-weight: 600; color: #495057; }
        .timestamp { text-align: center; color: #666; font-size: 14px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e0e0e0; }
        .icon { font-size: 2em; margin-bottom: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔄 Active Directory 同期状況レポート</h1>
            <div class="subtitle">Microsoft 365統合管理ツール - ITSM/ISO27001/27002準拠</div>
        </div>
        
        <div class="status-grid">
            <div class="status-card status-$(if ($reportData.SyncEnabled) { 'success' } else { 'warning' })">
                <div class="icon">🔄</div>
                <h3>同期状況</h3>
                <div class="value">$(if ($reportData.SyncEnabled) { '有効' } else { '無効' })</div>
            </div>
            
            <div class="status-card status-info">
                <div class="icon">👥</div>
                <h3>総ユーザー数</h3>
                <div class="value">$($reportData.TotalUserCount)</div>
            </div>
            
            <div class="status-card status-success">
                <div class="icon">📊</div>
                <h3>同期率</h3>
                <div class="value">$($reportData.SyncPercentage)%</div>
            </div>
        </div>
        
        <div class="details-section">
            <div class="details-title">📋 詳細情報</div>
            <table class="info-table">
                <tr>
                    <th>項目</th>
                    <th>値</th>
                </tr>
                <tr>
                    <td>🏢 組織名</td>
                    <td>$($reportData.OrganizationName)</td>
                </tr>
                <tr>
                    <td>🆔 テナントID</td>
                    <td>$($reportData.TenantId)</td>
                </tr>
                <tr>
                    <td>🔄 オンプレミス同期</td>
                    <td>$(if ($reportData.SyncEnabled) { '✅ 有効' } else { '❌ 無効' })</td>
                </tr>
                <tr>
                    <td>⏰ 最終同期日時</td>
                    <td>$(if ($reportData.LastSyncDateTime) { $reportData.LastSyncDateTime } else { 'データなし' })</td>
                </tr>
                <tr>
                    <td>👥 オンプレミスユーザー数</td>
                    <td>$($reportData.OnPremisesUserCount) 人</td>
                </tr>
                <tr>
                    <td>☁️ クラウドオンリーユーザー数</td>
                    <td>$($reportData.CloudOnlyUserCount) 人</td>
                </tr>
                <tr>
                    <td>📊 同期率</td>
                    <td>$($reportData.SyncPercentage)%</td>
                </tr>
            </table>
        </div>
        
        <div class="details-section">
            <div class="details-title">💡 推奨アクション</div>
            <ul style="line-height: 1.8;">
                <li>🔍 <strong>Azure ポータルでAzure AD Connect Healthを確認</strong></li>
                <li>🖥️ <strong>オンプレミスAD Connectサーバーのイベントログを確認</strong></li>
                <li>⚠️ <strong>同期が24時間以上停止している場合は調査が必要</strong></li>
                <li>📊 <strong>定期的な同期状況モニタリングの実施</strong></li>
            </ul>
        </div>
        
        <div class="timestamp">
            📅 レポート生成日時: $($reportData.ReportDate.ToString('yyyy年MM月dd日 HH:mm:ss'))<br>
            🤖 Microsoft 365統合管理ツール v2.0 | ITSM/ISO27001/27002準拠
        </div>
    </div>
</body>
</html>
"@
        
        $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
        Write-Host "📊 HTMLレポートを出力しました: $htmlPath" -ForegroundColor Green
        
    }
    catch {
        Write-Host "❌ 予期しないエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "スタックトレース: $($_.ScriptStackTrace)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "🔄 AD同期状況確認が完了しました" -ForegroundColor Green
}

# メイン実行
if ($MyInvocation.InvocationName -ne '.') {
    Test-ADDirectorySync
}