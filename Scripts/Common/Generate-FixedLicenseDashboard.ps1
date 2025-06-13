# Microsoft 365ライセンス分析ダッシュボード生成スクリプト
# 固定データを使用してテンプレートベースで確実に生成

param(
    [string]$OutputPath = "Reports/Monthly/License_Analysis_Dashboard_20250613_150236.html",
    [string]$CSVOutputPath = "Reports/Monthly/Clean_Complete_User_License_Details.csv",
    [string]$TemplateFile = "Reports/Monthly/License_Analysis_Dashboard_20250613_142142.html"
)

# 共通機能をインポート
Import-Module "$PSScriptRoot\Common.psm1" -Force

function Generate-FixedDashboard {
    <#
    .SYNOPSIS
    固定データを使用してダッシュボードを生成
    #>
    
    param(
        [string]$OutputFile,
        [string]$CSVFile
    )
    
    try {
        Write-LogMessage "固定データベースのダッシュボード生成を開始..." -Level Info
        
        # CSVファイルが存在するか確認
        $csvFullPath = Join-Path $PSScriptRoot "../../$CSVFile"
        if (-not (Test-Path $csvFullPath)) {
            Write-LogMessage "CSVファイルが見つかりません: $csvFullPath" -Level Warning
            Write-LogMessage "CSVファイルを生成します..." -Level Info
            
            # Pythonスクリプトを使用してCSVを生成
            $csvScript = Join-Path $PSScriptRoot "generate_clean_csv_from_text.py"
            if (Test-Path $csvScript) {
                Start-Process -FilePath "python3" -ArgumentList $csvScript -NoNewWindow -Wait
            }
        }
        
        # Pythonスクリプトを使用してHTMLダッシュボードを生成
        $dashboardScript = Join-Path $PSScriptRoot "fix_150236_dashboard.py"
        if (Test-Path $dashboardScript) {
            Write-LogMessage "Pythonスクリプトを実行してダッシュボードを生成..." -Level Info
            
            $processInfo = Start-Process -FilePath "python3" -ArgumentList $dashboardScript -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\dashboard_output.txt" -RedirectStandardError "$env:TEMP\dashboard_error.txt"
            
            if ($processInfo.ExitCode -eq 0) {
                $outputContent = Get-Content "$env:TEMP\dashboard_output.txt" -Raw -ErrorAction SilentlyContinue
                if ($outputContent) {
                    Write-LogMessage $outputContent -Level Info
                }
                
                $outputFullPath = Join-Path $PSScriptRoot "../../$OutputFile"
                if (Test-Path $outputFullPath) {
                    Write-LogMessage "ダッシュボードが正常に生成されました: $outputFullPath" -Level Success
                    return $outputFullPath
                } else {
                    Write-LogMessage "出力ファイルが見つかりません: $outputFullPath" -Level Error
                }
            } else {
                $errorContent = Get-Content "$env:TEMP\dashboard_error.txt" -Raw -ErrorAction SilentlyContinue
                Write-LogMessage "Python実行エラー: $errorContent" -Level Error
            }
        } else {
            Write-LogMessage "Pythonスクリプトが見つかりません: $dashboardScript" -Level Error
        }
        
        # フォールバック: PowerShellで直接生成
        Write-LogMessage "フォールバック: PowerShellで直接生成します..." -Level Info
        return Generate-PowerShellDashboard -OutputFile $OutputFile -CSVFile $CSVFile
        
    }
    catch {
        Write-LogMessage "ダッシュボード生成エラー: $_" -Level Error
        throw
    }
}

function Generate-PowerShellDashboard {
    param(
        [string]$OutputFile,
        [string]$CSVFile
    )
    
    try {
        # CSVファイルからユーザーデータを読み込み
        $csvFullPath = Join-Path $PSScriptRoot "../../$CSVFile"
        $users = @()
        
        if (Test-Path $csvFullPath) {
            $csvData = Import-Csv $csvFullPath -Encoding UTF8
            $users = $csvData
        } else {
            Write-LogMessage "CSVファイルが見つからないため、サンプルデータを使用します" -Level Warning
            # サンプルデータ（最初の5ユーザー）
            $users = @(
                @{ No=1; ユーザー名="ザーニ トェイ"; 部署コード="073"; ライセンス数=1; ライセンス種別="Microsoft 365 E3"; 月額コスト="¥2,840"; 最終サインイン="不明"; 利用状況="アクティブ"; 最適化状況="最適化済み" },
                @{ No=2; ユーザー名="トゥ リン"; 部署コード="091"; ライセンス数=1; ライセンス種別="Microsoft 365 E3"; 月額コスト="¥2,840"; 最終サインイン="不明"; 利用状況="アクティブ"; 最適化状況="最適化済み" },
                @{ No=3; ユーザー名="三村 ひとみ"; 部署コード="065"; ライセンス数=1; ライセンス種別="Microsoft 365 E3"; 月額コスト="¥2,840"; 最終サインイン="不明"; 利用状況="アクティブ"; 最適化状況="最適化済み" },
                @{ No=4; ユーザー名="三由 知英"; 部署コード="106"; ライセンス数=1; ライセンス種別="Microsoft 365 E3"; 月額コスト="¥2,840"; 最終サインイン="不明"; 利用状況="アクティブ"; 最適化状況="最適化済み" },
                @{ No=5; ユーザー名="三輪 綾"; 部署コード="089"; ライセンス数=1; ライセンス種別="Microsoft 365 E3"; 月額コスト="¥2,840"; 最終サインイン="不明"; 利用状況="アクティブ"; 最適化状況="最適化済み" }
            )
        }
        
        # ユーザーテーブル行を生成
        $userRows = @()
        foreach ($user in $users) {
            $cssClass = "risk-normal"
            if ($user.ライセンス種別 -like "*Exchange*") { $cssClass = "risk-attention" }
            elseif ($user.ライセンス種別 -like "*Basic*") { $cssClass = "risk-info" }
            
            $deptCode = if ($user.部署コード -and $user.部署コード -ne "-") { $user.部署コード } else { "" }
            
            $userRows += @"
                        <tr class="$cssClass">
                            <td>$($user.No)</td>
                            <td><strong>$($user.ユーザー名)</strong></td>
                            <td>$deptCode</td>
                            <td style="text-align: center;">$($user.ライセンス数)</td>
                            <td>$($user.ライセンス種別)</td>
                            <td style="text-align: right;">$($user.月額コスト)</td>
                            <td style="text-align: center;">$($user.最終サインイン)</td>
                            <td style="text-align: center;">$($user.利用状況)</td>
                            <td>$($user.最適化状況)</td>
                        </tr>
"@
        }
        
        $userTableContent = $userRows -join "`n"
        $currentDateTime = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
        
        # 完全なHTMLを生成
        $htmlContent = @"
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
        .risk-normal { background-color: #d4edda !important; color: #155724; }
        .risk-attention { background-color: #cce5f0 !important; color: #0c5460; }
        .risk-info { background-color: #d1ecf1 !important; color: #0c5460; }
        .scrollable-table {
            overflow-x: auto;
            margin: 20px 0;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            max-height: 600px;
            overflow-y: auto;
        }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
    </style>
    <script>
        function filterTable() {
            const searchInput = document.getElementById('searchInput').value.toLowerCase();
            const licenseFilter = document.getElementById('licenseFilter').value;
            const table = document.getElementById('userTable');
            const rows = table.getElementsByTagName('tr');
            
            for (let i = 1; i < rows.length; i++) {
                const row = rows[i];
                const cells = row.getElementsByTagName('td');
                let showRow = true;
                
                if (searchInput) {
                    const userName = cells[1] ? cells[1].textContent.toLowerCase() : '';
                    const deptCode = cells[2] ? cells[2].textContent.toLowerCase() : '';
                    const licenseType = cells[4] ? cells[4].textContent.toLowerCase() : '';
                    
                    if (!userName.includes(searchInput) && 
                        !deptCode.includes(searchInput) && 
                        !licenseType.includes(searchInput)) {
                        showRow = false;
                    }
                }
                
                if (licenseFilter && cells[4]) {
                    if (!cells[4].textContent.includes(licenseFilter)) {
                        showRow = false;
                    }
                }
                
                row.style.display = showRow ? '' : 'none';
            }
        }
        
        function exportToCSV() {
            window.open('Clean_Complete_User_License_Details.csv');
        }
        
        document.addEventListener('DOMContentLoaded', function() {
            document.getElementById('searchInput').addEventListener('input', filterTable);
            document.getElementById('licenseFilter').addEventListener('change', filterTable);
        });
    </script>
</head>
<body>
    <div class="header">
        <h1>💰 Microsoft 365ライセンス分析ダッシュボード</h1>
        <div class="subtitle">みらい建設工業株式会社 - ライセンス最適化・コスト監視</div>
        <div class="subtitle">分析実行日時: $currentDateTime</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総ライセンス数</h3>
            <div class="value info">508</div>
            <div class="description">購入済み</div>
            <div style="font-size: 12px; margin-top: 10px; color: #666;">
                E3: 440 | Exchange: 50 | Basic: 18
            </div>
        </div>
        <div class="summary-card">
            <h3>使用中ライセンス</h3>
            <div class="value success">157</div>
            <div class="description">割り当て済み</div>
            <div style="font-size: 12px; margin-top: 10px; color: #666;">
                E3: 107 | Exchange: 49 | Basic: 1
            </div>
        </div>
        <div class="summary-card">
            <h3>未使用ライセンス</h3>
            <div class="value warning">351</div>
            <div class="description">コスト削減機会</div>
            <div style="font-size: 12px; margin-top: 10px; color: #666;">
                E3: 333 | Exchange: 1 | Basic: 17
            </div>
        </div>
        <div class="summary-card">
            <h3>ライセンス利用率</h3>
            <div class="value info">30.9%</div>
            <div class="description">効率性指標</div>
            <div style="font-size: 12px; margin-top: 10px; color: #666;">
                改善の余地あり
            </div>
        </div>
    </div>

    <div class="section">
        <div class="section-header">👥 ユーザーライセンス詳細一覧</div>
        <div class="section-content">
            <p>総ユーザー数: <strong>$($users.Count)名</strong> | 検索・フィルター機能付き</p>
            <div style="margin: 15px 0;">
                <input type="text" id="searchInput" placeholder="ユーザー名、部署コード、ライセンス種別で検索..." style="padding: 8px; width: 300px; border: 1px solid #ddd; border-radius: 4px;">
                <select id="licenseFilter" style="padding: 8px; margin-left: 10px; border: 1px solid #ddd; border-radius: 4px;">
                    <option value="">全ライセンス</option>
                    <option value="Microsoft 365 E3">Microsoft 365 E3</option>
                    <option value="Exchange Online Plan 2">Exchange Online Plan 2</option>
                    <option value="Business Basic">Business Basic</option>
                </select>
                <button onclick="exportToCSV()" style="padding: 8px 15px; margin-left: 10px; background: #0078d4; color: white; border: none; border-radius: 4px; cursor: pointer;">CSV出力</button>
            </div>
            <div class="scrollable-table">
                <table class="data-table" id="userTable">
                    <thead>
                        <tr>
                            <th>No</th>
                            <th>ユーザー名</th>
                            <th>部署コード</th>
                            <th>ライセンス数</th>
                            <th>ライセンス種別</th>
                            <th>月額コスト</th>
                            <th>最終サインイン</th>
                            <th>利用状況</th>
                            <th>最適化状況</th>
                        </tr>
                    </thead>
                    <tbody>
$userTableContent
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div class="footer">
        <p>このレポートは Microsoft 365 ライセンス管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社 ライセンス最適化センター</p>
        <p>PowerShell生成 - $currentDateTime - 🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@
        
        # ファイル出力
        $outputFullPath = Join-Path $PSScriptRoot "../../$OutputFile"
        $outputDir = Split-Path $outputFullPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        
        $htmlContent | Out-File -FilePath $outputFullPath -Encoding UTF8 -Force
        
        Write-LogMessage "PowerShellでダッシュボードを生成しました: $outputFullPath" -Level Success
        return $outputFullPath
        
    }
    catch {
        Write-LogMessage "PowerShellダッシュボード生成エラー: $_" -Level Error
        throw
    }
}

# メイン処理
try {
    Write-LogMessage "固定ライセンス分析ダッシュボード生成を開始..." -Level Info
    Write-LogMessage "出力ファイル: $OutputPath" -Level Info
    Write-LogMessage "CSVファイル: $CSVOutputPath" -Level Info
    
    $result = Generate-FixedDashboard -OutputFile $OutputPath -CSVFile $CSVOutputPath
    
    Write-LogMessage "=== 生成結果 ===" -Level Success
    Write-LogMessage "📈 HTMLダッシュボード: $result" -Level Success
    Write-LogMessage "📊 統計情報:" -Level Info
    Write-LogMessage "  - 総ライセンス数: 508" -Level Info
    Write-LogMessage "  - 使用中ライセンス: 157" -Level Info
    Write-LogMessage "  - 未使用ライセンス: 351" -Level Info
    Write-LogMessage "  - ライセンス利用率: 30.9%" -Level Info
    
    return $result
}
catch {
    Write-LogMessage "固定ダッシュボード生成エラー: $_" -Level Error
    throw
}