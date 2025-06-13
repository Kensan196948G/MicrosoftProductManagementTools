# ================================================================================
# Generate-CompleteUserTable.ps1
# CSVファイルから完全なユーザー一覧HTMLテーブルを生成
# ================================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,
    
    [Parameter(Mandatory = $true)]
    [string]$OutputHtmlPath
)

try {
    Write-Host "CSVファイルからユーザーデータを読み込み中: $CsvPath" -ForegroundColor Cyan
    
    # CSVファイルを読み込み
    $userData = Import-Csv -Path $CsvPath -Encoding UTF8
    
    Write-Host "読み込み完了: $($userData.Count)ユーザー" -ForegroundColor Green
    
    # ライセンス別にカウント
    $totalE3 = ($userData | Where-Object { $_.AssignedLicenses -eq "Microsoft 365 E3" }).Count
    $totalExchange = ($userData | Where-Object { $_.AssignedLicenses -eq "Exchange Online Plan 2" }).Count
    $totalBasic = ($userData | Where-Object { $_.AssignedLicenses -like "*Business Basic*" }).Count
    
    # HTMLコンテンツを生成
    $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft 365ライセンス割り当てユーザー完全一覧表</title>
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
        
        .summary-cards {
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
        .summary-card .value { font-size: 32px; font-weight: bold; margin: 10px 0; color: #0078d4; }
        
        .filter-section {
            background: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .filter-controls {
            display: flex;
            gap: 15px;
            align-items: center;
            flex-wrap: wrap;
        }
        .filter-controls input, .filter-controls select {
            padding: 8px 12px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
        }
        .filter-controls button {
            padding: 8px 16px;
            background: #0078d4;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
        }
        .filter-controls button:hover {
            background: #106ebe;
        }
        
        .table-container {
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .table-header {
            background: linear-gradient(135deg, #6c757d 0%, #5a6268 100%);
            color: white;
            padding: 15px 20px;
            font-weight: bold;
        }
        .data-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }
        .data-table th {
            background-color: #0078d4;
            color: white;
            border: 1px solid #ddd;
            padding: 12px 8px;
            text-align: left;
            font-weight: bold;
            position: sticky;
            top: 0;
            z-index: 10;
        }
        .data-table td {
            border: 1px solid #ddd;
            padding: 8px;
            font-size: 12px;
            white-space: nowrap;
        }
        .data-table tr:nth-child(even) {
            background-color: #f8f9fa;
        }
        .data-table tr:hover {
            background-color: #e9ecef;
        }
        
        .license-e3 { background-color: #d1ecf1 !important; }
        .license-exchange { background-color: #d4edda !important; }
        .license-basic { background-color: #fff3cd !important; }
        
        .table-scroll {
            max-height: 600px;
            overflow-y: auto;
            border: 1px solid #ddd;
        }
        
        .stats-info {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 10px;
            padding: 15px;
            background: #f8f9fa;
            border-top: 2px solid #0078d4;
            font-size: 12px;
        }
        .stats-info div {
            text-align: center;
        }
        .stats-info .label {
            font-weight: bold;
            color: #666;
        }
        .stats-info .value {
            font-size: 18px;
            color: #0078d4;
            font-weight: bold;
        }
        
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>👥 Microsoft 365ライセンス割り当てユーザー完全一覧表</h1>
        <div class="subtitle">みらい建設工業株式会社 - 全ユーザーライセンス情報</div>
        <div class="subtitle">生成日時: $(Get-Date -Format "yyyy年MM月dd日 HH:mm:ss")</div>
    </div>

    <div class="summary-cards">
        <div class="summary-card">
            <h3>Microsoft 365 E3</h3>
            <div class="value">$totalE3</div>
            <div class="description">ユーザー</div>
        </div>
        <div class="summary-card">
            <h3>Exchange Online Plan 2</h3>
            <div class="value">$totalExchange</div>
            <div class="description">ユーザー</div>
        </div>
        <div class="summary-card">
            <h3>Business Basic (レガシー)</h3>
            <div class="value">$totalBasic</div>
            <div class="description">ユーザー</div>
        </div>
        <div class="summary-card">
            <h3>総ユーザー数</h3>
            <div class="value">$($userData.Count)</div>
            <div class="description">全ライセンス</div>
        </div>
    </div>

    <div class="filter-section">
        <h3>🔍 フィルター・検索</h3>
        <div class="filter-controls">
            <input type="text" id="searchInput" placeholder="ユーザー名で検索..." onkeyup="filterTable()">
            <select id="licenseFilter" onchange="filterTable()">
                <option value="">全ライセンス</option>
                <option value="Microsoft 365 E3">Microsoft 365 E3</option>
                <option value="Exchange Online Plan 2">Exchange Online Plan 2</option>
                <option value="Microsoft 365 Business Basic">Business Basic (レガシー)</option>
            </select>
            <select id="departmentFilter" onchange="filterTable()">
                <option value="">全部署</option>
                <option value="has-dept">部署コードあり</option>
                <option value="no-dept">部署コードなし</option>
            </select>
            <button onclick="clearFilters()">フィルタークリア</button>
        </div>
    </div>

    <div class="table-container">
        <div class="table-header">📋 ライセンス割り当てユーザー詳細一覧（全$($userData.Count)名）</div>
        <div class="table-scroll">
            <table class="data-table" id="userTable">
                <thead>
                    <tr>
                        <th>No.</th>
                        <th>ユーザー名</th>
                        <th>部署コード</th>
                        <th>ライセンス種別</th>
                        <th>月額コスト</th>
                        <th>利用状況</th>
                        <th>最適化状況</th>
                    </tr>
                </thead>
                <tbody id="userTableBody">
"@

    # ユーザーデータのテーブル行を生成
    $rowNumber = 1
    foreach ($user in $userData) {
        $department = if ([string]::IsNullOrEmpty($user.Department)) { "-" } else { $user.Department }
        $licenseClass = switch ($user.AssignedLicenses) {
            "Microsoft 365 E3" { "license-e3" }
            "Exchange Online Plan 2" { "license-exchange" }
            default { "license-basic" }
        }
        
        $htmlContent += @"
                    <tr class="$licenseClass">
                        <td>$rowNumber</td>
                        <td>$($user.DisplayName)</td>
                        <td>$department</td>
                        <td>$($user.AssignedLicenses)</td>
                        <td>¥$('{0:N0}' -f [int]$user.TotalMonthlyCost)</td>
                        <td>$($user.UtilizationStatus)</td>
                        <td>$($user.OptimizationRecommendations)</td>
                    </tr>
"@
        $rowNumber++
    }

    # HTMLの残り部分を追加
    $htmlContent += @"
                </tbody>
            </table>
        </div>
        
        <div class="stats-info">
            <div><div class="label">総ユーザー数</div><div class="value">$($userData.Count)</div></div>
            <div><div class="label">Microsoft 365 E3</div><div class="value">$totalE3</div></div>
            <div><div class="label">Exchange Online Plan 2</div><div class="value">$totalExchange</div></div>
            <div><div class="label">Business Basic</div><div class="value">$totalBasic</div></div>
            <div><div class="label">総月額コスト</div><div class="value">¥$((($userData | ForEach-Object { [int]$_.TotalMonthlyCost }) | Measure-Object -Sum).Sum.ToString('N0'))</div></div>
            <div><div class="label">平均コスト/ユーザー</div><div class="value">¥$([math]::Round((($userData | ForEach-Object { [int]$_.TotalMonthlyCost }) | Measure-Object -Average).Average).ToString('N0'))</div></div>
        </div>
    </div>

    <div class="footer">
        <p>このレポートは Microsoft 365 ライセンス管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社 ライセンス最適化センター</p>
        <p>🤖 Generated with Claude Code</p>
    </div>

    <script>
        // 検索とフィルター機能
        function filterTable() {
            const searchInput = document.getElementById('searchInput').value.toLowerCase();
            const licenseFilter = document.getElementById('licenseFilter').value;
            const departmentFilter = document.getElementById('departmentFilter').value;
            const tableBody = document.getElementById('userTableBody');
            const rows = tableBody.getElementsByTagName('tr');

            let visibleCount = 0;
            for (let i = 0; i < rows.length; i++) {
                const row = rows[i];
                const userName = row.cells[1] ? row.cells[1].textContent.toLowerCase() : '';
                const license = row.cells[3] ? row.cells[3].textContent : '';
                const department = row.cells[2] ? row.cells[2].textContent : '';
                
                let showRow = true;

                // 検索フィルター
                if (searchInput && !userName.includes(searchInput)) {
                    showRow = false;
                }

                // ライセンスフィルター
                if (licenseFilter && !license.includes(licenseFilter)) {
                    showRow = false;
                }

                // 部署フィルター
                if (departmentFilter === 'has-dept' && department === '-') {
                    showRow = false;
                } else if (departmentFilter === 'no-dept' && department !== '-') {
                    showRow = false;
                }

                row.style.display = showRow ? '' : 'none';
                if (showRow) visibleCount++;
            }
            
            // 表示件数を更新
            document.querySelector('.table-header').textContent = '📋 ライセンス割り当てユーザー詳細一覧（表示中: ' + visibleCount + '名 / 全$($userData.Count)名）';
        }

        function clearFilters() {
            document.getElementById('searchInput').value = '';
            document.getElementById('licenseFilter').value = '';
            document.getElementById('departmentFilter').value = '';
            filterTable();
        }

        // 初期表示時のフィルター適用
        document.addEventListener('DOMContentLoaded', function() {
            filterTable();
        });
    </script>
</body>
</html>
"@

    # HTMLファイルに出力
    $htmlContent | Out-File -FilePath $OutputHtmlPath -Encoding UTF8
    
    Write-Host "完全なHTMLユーザー一覧表を生成しました: $OutputHtmlPath" -ForegroundColor Green
    Write-Host "総ユーザー数: $($userData.Count)名" -ForegroundColor Yellow
    Write-Host "Microsoft 365 E3: $totalE3名" -ForegroundColor Cyan
    Write-Host "Exchange Online Plan 2: $totalExchange名" -ForegroundColor Cyan
    Write-Host "Business Basic: $totalBasic名" -ForegroundColor Cyan
    
} catch {
    Write-Error "エラーが発生しました: $($_.Exception.Message)"
    throw $_
}