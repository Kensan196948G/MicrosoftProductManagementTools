# ================================================================================
# SecurityAudit.ps1
# セキュリティとコンプライアンス監査
# ================================================================================

[CmdletBinding()]
param()

# 共通モジュールのインポート
$CommonPath = Join-Path $PSScriptRoot "."
Import-Module "$CommonPath\Logging.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$CommonPath\ErrorHandling.psm1" -Force -ErrorAction SilentlyContinue

function Start-SecurityComplianceAudit {
    <#
    .SYNOPSIS
    セキュリティ設定とコンプライアンス状況の監査
    
    .DESCRIPTION
    Microsoft 365環境のセキュリティ設定、MFA状況、
    条件付きアクセス、外部共有設定等を監査します
    
    .EXAMPLE
    Start-SecurityComplianceAudit
    #>
    
    Write-Host "🔒 Microsoft 365 セキュリティ・コンプライアンス監査" -ForegroundColor Cyan
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
        
        # MFA設定状況の確認
        Write-Host "🔐 多要素認証(MFA)設定状況を確認中..." -ForegroundColor Yellow
        
        try {
            $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled
            $mfaStats = @{
                TotalUsers = 0
                EnabledUsers = 0
                DisabledUsers = 0
                ExemptUsers = 0
                MfaEnabledUsers = @()
                MfaDisabledUsers = @()
            }
            
            $activeUsers = $users | Where-Object {$_.AccountEnabled -eq $true}
            $mfaStats.TotalUsers = $activeUsers.Count
            
            Write-Host "📊 MFA統計:" -ForegroundColor Cyan
            Write-Host "   👥 総アクティブユーザー数: $($mfaStats.TotalUsers)" -ForegroundColor White
            
            # 注意: 実際のMFA状況取得にはMicrosoft Graph Beta APIまたは
            # Azure AD PowerShell v2が必要です。ここではサンプル実装を提供
            Write-Host "   ℹ️  詳細なMFA設定確認には Azure AD PowerShell または" -ForegroundColor Blue
            Write-Host "      Azure ポータルでの手動確認が必要です" -ForegroundColor Blue
            Write-Host ""
            
        }
        catch {
            Write-Host "❌ MFA設定確認エラー: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
        }
        
        # 条件付きアクセスポリシーの確認
        Write-Host "🛡️ 条件付きアクセスポリシーを確認中..." -ForegroundColor Yellow
        
        try {
            $conditionalAccessPolicies = Get-MgIdentityConditionalAccessPolicy -ErrorAction SilentlyContinue
            
            if ($conditionalAccessPolicies) {
                Write-Host "📋 条件付きアクセスポリシー統計:" -ForegroundColor Cyan
                
                $enabledPolicies = $conditionalAccessPolicies | Where-Object {$_.State -eq "enabled"}
                $disabledPolicies = $conditionalAccessPolicies | Where-Object {$_.State -eq "disabled"}
                $reportOnlyPolicies = $conditionalAccessPolicies | Where-Object {$_.State -eq "enabledForReportingButNotEnforced"}
                
                Write-Host "   📊 総ポリシー数: $($conditionalAccessPolicies.Count)" -ForegroundColor White
                Write-Host "   ✅ 有効: $($enabledPolicies.Count)" -ForegroundColor Green
                Write-Host "   ❌ 無効: $($disabledPolicies.Count)" -ForegroundColor Red
                Write-Host "   📊 レポートのみ: $($reportOnlyPolicies.Count)" -ForegroundColor Yellow
                
                if ($enabledPolicies.Count -gt 0) {
                    Write-Host ""
                    Write-Host "   🛡️ 有効なポリシー:" -ForegroundColor Cyan
                    foreach ($policy in $enabledPolicies) {
                        Write-Host "     • $($policy.DisplayName)" -ForegroundColor White
                    }
                }
                
                Write-Host ""
            }
            else {
                Write-Host "   ⚠️  条件付きアクセスポリシーが設定されていません" -ForegroundColor Yellow
                Write-Host ""
            }
        }
        catch {
            Write-Host "❌ 条件付きアクセス確認エラー: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
        }
        
        # 管理者ロール割り当ての確認
        Write-Host "👑 管理者ロール割り当てを確認中..." -ForegroundColor Yellow
        
        try {
            $directoryRoles = Get-MgDirectoryRole -All
            $adminStats = @()
            
            foreach ($role in $directoryRoles) {
                $roleMembers = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -ErrorAction SilentlyContinue
                
                if ($roleMembers.Count -gt 0) {
                    $adminStats += [PSCustomObject]@{
                        RoleName = $role.DisplayName
                        MemberCount = $roleMembers.Count
                        Members = ($roleMembers | ForEach-Object {
                            try {
                                $member = Get-MgUser -UserId $_.Id -ErrorAction SilentlyContinue
                                if ($member) { $member.UserPrincipalName }
                            } catch { $_.Id }
                        }) -join ", "
                    }
                }
            }
            
            Write-Host "📊 管理者ロール統計:" -ForegroundColor Cyan
            
            $criticalRoles = @("Global Administrator", "Security Administrator", "Exchange Administrator")
            
            foreach ($stat in $adminStats | Sort-Object MemberCount -Descending) {
                $color = if ($stat.RoleName -in $criticalRoles) { "Red" } else { "White" }
                $criticalMark = if ($stat.RoleName -in $criticalRoles) { " [重要]" } else { "" }
                
                Write-Host "   👤 $($stat.RoleName)$criticalMark: $($stat.MemberCount) 人" -ForegroundColor $color
                if ($stat.MemberCount -le 5) {
                    Write-Host "     📧 $($stat.Members)" -ForegroundColor Gray
                }
            }
            Write-Host ""
            
        }
        catch {
            Write-Host "❌ 管理者ロール確認エラー: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
        }
        
        # 外部共有設定の確認
        Write-Host "🌐 外部共有設定を確認中..." -ForegroundColor Yellow
        
        try {
            # SharePoint Online管理が必要な場合の代替として組織設定を確認
            $orgSettings = Get-MgOrganization -Property Id,DisplayName
            
            Write-Host "📊 外部共有設定:" -ForegroundColor Cyan
            Write-Host "   ℹ️  詳細な外部共有設定の確認には SharePoint Online Management Shell" -ForegroundColor Blue
            Write-Host "      または SharePoint 管理センターでの確認が推奨されます" -ForegroundColor Blue
            Write-Host ""
            
        }
        catch {
            Write-Host "❌ 外部共有設定確認エラー: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
        }
        
        # サインインログの分析
        Write-Host "📊 サインイン統計を確認中..." -ForegroundColor Yellow
        
        try {
            # 過去7日間のサインインログを確認（サンプル）
            $sevenDaysAgo = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
            
            Write-Host "📋 サインイン統計 (過去7日間):" -ForegroundColor Cyan
            Write-Host "   ℹ️  詳細なサインインログ分析には Azure AD Premium ライセンスと" -ForegroundColor Blue
            Write-Host "      適切な権限が必要です" -ForegroundColor Blue
            Write-Host ""
            
        }
        catch {
            Write-Host "❌ サインイン統計取得エラー: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
        }
        
        # セキュリティスコア（概念的）
        Write-Host "🏆 セキュリティ評価サマリー:" -ForegroundColor Cyan
        
        $securityScore = 0
        $maxScore = 100
        $recommendations = @()
        
        # 条件付きアクセスポリシーの評価
        if ($conditionalAccessPolicies -and $enabledPolicies.Count -gt 0) {
            $securityScore += 25
            Write-Host "   ✅ 条件付きアクセス設定済み (+25点)" -ForegroundColor Green
        } else {
            $recommendations += "条件付きアクセスポリシーの設定"
            Write-Host "   ❌ 条件付きアクセス未設定 (0点)" -ForegroundColor Red
        }
        
        # 管理者ロールの評価
        $globalAdmins = $adminStats | Where-Object {$_.RoleName -eq "Global Administrator"}
        if ($globalAdmins -and $globalAdmins.MemberCount -le 3) {
            $securityScore += 20
            Write-Host "   ✅ 全体管理者数が適切 (+20点)" -ForegroundColor Green
        } else {
            $recommendations += "全体管理者数の削減（推奨: 2-3名）"
            Write-Host "   ⚠️  全体管理者数要確認 (+10点)" -ForegroundColor Yellow
            $securityScore += 10
        }
        
        # 基本的なユーザー管理
        if ($users -and $users.Count -gt 0) {
            $securityScore += 15
            Write-Host "   ✅ ユーザー管理実装済み (+15点)" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "   📊 総合セキュリティスコア: $securityScore / $maxScore 点" -ForegroundColor $(
            if ($securityScore -ge 80) { "Green" } 
            elseif ($securityScore -ge 60) { "Yellow" } 
            else { "Red" }
        )
        
        # 推奨アクション
        if ($recommendations.Count -gt 0) {
            Write-Host ""
            Write-Host "💡 推奨セキュリティ改善アクション:" -ForegroundColor Cyan
            foreach ($recommendation in $recommendations) {
                Write-Host "   • $recommendation" -ForegroundColor White
            }
        }
        
        Write-Host ""
        Write-Host "🔒 追加の推奨事項:" -ForegroundColor Cyan
        Write-Host "   1. 定期的なアクセス権限レビューの実施" -ForegroundColor White
        Write-Host "   2. セキュリティ既定値群またはカスタム条件付きアクセスの有効化" -ForegroundColor White
        Write-Host "   3. 特権アカウントのPIМ (Privileged Identity Management) 利用検討" -ForegroundColor White
        Write-Host "   4. セキュリティ インシデント対応手順の策定・テスト" -ForegroundColor White
        Write-Host "   5. ユーザーセキュリティ意識向上トレーニングの実施" -ForegroundColor White
        Write-Host ""
        
        # レポート生成
        $auditReport = [PSCustomObject]@{
            AuditDate = Get-Date
            TotalUsers = if ($users) { $users.Count } else { 0 }
            ActiveUsers = if ($users) { ($users | Where-Object {$_.AccountEnabled}).Count } else { 0 }
            ConditionalAccessPolicies = if ($conditionalAccessPolicies) { $conditionalAccessPolicies.Count } else { 0 }
            EnabledConditionalAccessPolicies = if ($enabledPolicies) { $enabledPolicies.Count } else { 0 }
            AdminRoleAssignments = if ($adminStats) { $adminStats.Count } else { 0 }
            SecurityScore = $securityScore
            MaxSecurityScore = $maxScore
            SecurityPercentage = [math]::Round(($securityScore / $maxScore) * 100, 1)
            Recommendations = ($recommendations -join "; ")
        }
        
        # CSV・HTMLレポート生成
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $reportBaseName = "Security_Audit_$timestamp"
        $csvPath = "Reports\Daily\$reportBaseName.csv"
        $htmlPath = "Reports\Daily\$reportBaseName.html"
        
        $reportDir = Split-Path $csvPath -Parent
        if (-not (Test-Path $reportDir)) {
            New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
        }
        
        # CSV出力
        $auditReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "📊 CSVレポートを出力しました: $csvPath" -ForegroundColor Green
        
        # HTMLレポート生成
        $scoreColor = if ($securityScore -ge 80) { "success" } elseif ($securityScore -ge 60) { "warning" } else { "danger" }
        $scoreBarWidth = [math]::Round(($securityScore / $maxScore) * 100, 1)
        
        $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft 365 セキュリティ・コンプライアンス監査レポート</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 1400px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; padding-bottom: 20px; border-bottom: 3px solid #dc3545; }
        .header h1 { color: #dc3545; margin: 0; font-size: 28px; }
        .header .subtitle { color: #666; margin: 10px 0 0 0; font-size: 16px; }
        .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .status-card { padding: 20px; border-radius: 8px; text-align: center; }
        .status-success { background: linear-gradient(135deg, #28a745, #20c997); color: white; }
        .status-warning { background: linear-gradient(135deg, #ffc107, #fd7e14); color: white; }
        .status-danger { background: linear-gradient(135deg, #dc3545, #e83e8c); color: white; }
        .status-info { background: linear-gradient(135deg, #007bff, #6f42c1); color: white; }
        .status-card h3 { margin: 0 0 10px 0; font-size: 16px; }
        .status-card .value { font-size: 24px; font-weight: bold; margin: 10px 0; }
        .security-score { background: linear-gradient(135deg, #$scoreColor, #$scoreColor); padding: 30px; border-radius: 15px; text-align: center; margin: 30px 0; }
        .security-score h2 { color: white; margin: 0 0 20px 0; font-size: 24px; }
        .score-display { font-size: 48px; font-weight: bold; color: white; margin: 20px 0; }
        .score-bar { background: rgba(255,255,255,0.3); height: 20px; border-radius: 10px; overflow: hidden; margin: 20px 0; }
        .score-fill { height: 100%; background: white; width: $scoreBarWidth%; transition: width 0.5s ease; }
        .details-section { margin: 30px 0; }
        .details-title { font-size: 20px; color: #dc3545; margin-bottom: 15px; padding-bottom: 5px; border-bottom: 2px solid #e0e0e0; }
        .details-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 30px; margin: 20px 0; }
        .details-card { background: #f8f9fa; padding: 20px; border-radius: 8px; }
        .details-card h4 { color: #dc3545; margin: 0 0 15px 0; }
        .stats-list { list-style: none; padding: 0; }
        .stats-list li { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #e0e0e0; }
        .stats-list li:last-child { border-bottom: none; }
        .admin-roles { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
        .recommendations { background: #d1ecf1; border-left: 4px solid #0077be; padding: 15px; margin: 20px 0; }
        .critical { color: #dc3545; font-weight: bold; }
        .timestamp { text-align: center; color: #666; font-size: 14px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e0e0e0; }
        .icon { font-size: 2em; margin-bottom: 10px; }
        @media (max-width: 768px) { .details-grid { grid-template-columns: 1fr; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 Microsoft 365 セキュリティ・コンプライアンス監査レポート</h1>
            <div class="subtitle">Microsoft 365統合管理ツール - ITSM/ISO27001/27002準拠</div>
        </div>
        
        <div class="security-score status-$scoreColor">
            <h2>🏆 総合セキュリティスコア</h2>
            <div class="score-display">$securityScore / $maxScore</div>
            <div class="score-bar">
                <div class="score-fill"></div>
            </div>
            <div style="color: white; font-size: 18px;">セキュリティレベル: $($auditReport.SecurityPercentage)%</div>
        </div>
        
        <div class="status-grid">
            <div class="status-card status-info">
                <div class="icon">👥</div>
                <h3>総ユーザー数</h3>
                <div class="value">$($auditReport.TotalUsers)</div>
            </div>
            
            <div class="status-card status-success">
                <div class="icon">✅</div>
                <h3>アクティブユーザー</h3>
                <div class="value">$($auditReport.ActiveUsers)</div>
            </div>
            
            <div class="status-card status-$(if ($auditReport.EnabledConditionalAccessPolicies -gt 0) { 'success' } else { 'danger' })">
                <div class="icon">🛡️</div>
                <h3>条件付きアクセス</h3>
                <div class="value">$($auditReport.EnabledConditionalAccessPolicies)</div>
            </div>
            
            <div class="status-card status-warning">
                <div class="icon">👑</div>
                <h3>管理者ロール</h3>
                <div class="value">$($auditReport.AdminRoleAssignments)</div>
            </div>
        </div>
        
        <div class="details-grid">
            <div class="details-card">
                <h4>🔐 認証・アクセス制御</h4>
                <ul class="stats-list">
                    <li><span>条件付きアクセスポリシー（総数）</span><span>$($auditReport.ConditionalAccessPolicies)</span></li>
                    <li><span>有効な条件付きアクセス</span><span class="$(if ($auditReport.EnabledConditionalAccessPolicies -gt 0) { 'text-success' } else { 'critical' })">$($auditReport.EnabledConditionalAccessPolicies)</span></li>
                    <li><span>MFA設定状況</span><span>要手動確認</span></li>
                    <li><span>セキュリティ既定値群</span><span>要確認</span></li>
                </ul>
            </div>
            
            <div class="details-card">
                <h4>👑 管理者権限</h4>
                <ul class="stats-list">
                    <li><span>管理者ロール種類</span><span>$($auditReport.AdminRoleAssignments)</span></li>
                    <li><span>全体管理者数</span><span class="$(if ($globalAdmins -and $globalAdmins.MemberCount -le 3) { 'text-success' } else { 'critical' })">$(if ($globalAdmins) { $globalAdmins.MemberCount } else { '要確認' })</span></li>
                    <li><span>特権アカウント管理</span><span>要確認</span></li>
                    <li><span>PIM利用状況</span><span>要確認</span></li>
                </ul>
            </div>
        </div>
        
        <div class="admin-roles">
            <div class="details-title">⚠️ 重要な管理者ロール</div>
            <p>以下の重要な管理者ロールの設定を定期的に確認してください：</p>
            <ul>
                <li><strong>全体管理者</strong>: 最小限の人数（推奨: 2-3名）に制限</li>
                <li><strong>セキュリティ管理者</strong>: セキュリティ設定の管理権限</li>
                <li><strong>Exchange管理者</strong>: メール系統の管理権限</li>
                <li><strong>SharePoint管理者</strong>: 外部共有設定の管理権限</li>
            </ul>
        </div>
"@
        
        if ($recommendations.Count -gt 0) {
            $htmlContent += @"
        
        <div class="recommendations">
            <div class="details-title">🔧 推奨セキュリティ改善アクション</div>
            <ul>
"@
            foreach ($recommendation in $recommendations) {
                $htmlContent += "                <li><strong>$recommendation</strong></li>`n"
            }
            $htmlContent += @"
            </ul>
        </div>
"@
        }
        
        $htmlContent += @"
        
        <div class="recommendations">
            <div class="details-title">💡 一般的なセキュリティ推奨事項</div>
            <ul style="line-height: 1.8;">
                <li>🔍 <strong>定期的なアクセス権限レビューの実施</strong></li>
                <li>🛡️ <strong>セキュリティ既定値群またはカスタム条件付きアクセスの有効化</strong></li>
                <li>👑 <strong>特権アカウントのPIM (Privileged Identity Management) 利用検討</strong></li>
                <li>🚨 <strong>セキュリティインシデント対応手順の策定・テスト</strong></li>
                <li>🎓 <strong>ユーザーセキュリティ意識向上トレーニングの実施</strong></li>
                <li>📊 <strong>定期的なセキュリティ監査とコンプライアンスチェック</strong></li>
            </ul>
        </div>
        
        <div class="timestamp">
            📅 レポート生成日時: $($auditReport.AuditDate.ToString('yyyy年MM月dd日 HH:mm:ss'))<br>
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
    Write-Host "🔒 セキュリティ・コンプライアンス監査が完了しました" -ForegroundColor Green
}

# メイン実行
if ($MyInvocation.InvocationName -ne '.') {
    Start-SecurityComplianceAudit
}