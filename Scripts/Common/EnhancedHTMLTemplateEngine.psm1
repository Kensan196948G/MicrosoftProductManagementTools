# ================================================================================
# 拡張HTMLテンプレートエンジン
# 検索、フィルター、PDF印刷・ダウンロード機能付きHTMLレポートを生成
# ================================================================================

function Generate-InteractiveHTMLReport {
    <#
    .SYNOPSIS
    Interactive HTML report with search, filter, and PDF functionality
    #>
    param(
        [array]$Data,
        [string]$ReportType,
        [string]$Title,
        [string]$OutputPath,
        [hashtable]$AdditionalVariables = @{}
    )
    
    try {
        if (-not $Data -or $Data.Count -eq 0) {
            Write-Host "⚠️ 出力するデータがありません" -ForegroundColor Yellow
            return $null
        }
        
        # データをHTMLテーブルに変換
        $tableRows = Convert-DataToInteractiveHTML -Data $Data -ReportType $ReportType
        
        # 統計情報を計算
        $statistics = Calculate-ReportStatistics -Data $Data -ReportType $ReportType
        
        # インタラクティブHTMLテンプレートを生成
        $htmlContent = Generate-InteractiveHTMLTemplate -Data $Data -ReportType $ReportType -Title $Title -TableRows $tableRows -Statistics $statistics -AdditionalVariables $AdditionalVariables
        
        # ファイルに出力
        $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
        
        Write-Host "✅ インタラクティブHTMLレポートを生成しました: $OutputPath" -ForegroundColor Green
        return $htmlContent
    }
    catch {
        Write-Host "❌ インタラクティブHTMLレポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Convert-FieldNameToJapanese {
    param([string]$FieldName)
    
    $fieldMapping = @{
        "ServiceName" = "サービス名"
        "ActiveUsersCount" = "アクティブユーザー数"
        "TotalActivityCount" = "総アクティビティ数"
        "NewUsersCount" = "新規ユーザー数"
        "ErrorCount" = "エラー数"
        "ServiceStatus" = "サービス状況"
        "PerformanceScore" = "パフォーマンススコア"
        "LastCheck" = "最終チェック"
        "Status" = "ステータス"
        "UserName" = "ユーザー名"
        "UserPrincipalName" = "ユーザープリンシパル名"
        "DisplayName" = "表示名"
        "Email" = "メールアドレス"
        "Department" = "部署"
        "JobTitle" = "役職"
        "AccountStatus" = "アカウント状況"
        "LicenseStatus" = "ライセンス状況"
        "CreationDate" = "作成日"
        "LastSignIn" = "最終サインイン"
        "DailyLogins" = "日次ログイン"
        "DailyEmails" = "日次メール"
        "TeamsActivity" = "Teamsアクティビティ"
        "ActivityLevel" = "アクティビティレベル"
        "ActivityScore" = "アクティビティスコア"
        "LicenseName" = "ライセンス名"
        "SkuId" = "SKU ID"
        "PurchasedQuantity" = "購入数"
        "AssignedQuantity" = "割り当て済み"
        "AvailableQuantity" = "利用可能数"
        "UsageRate" = "利用率"
        "MonthlyUnitPrice" = "月額単価"
        "MonthlyCost" = "月額コスト"
        "MFAStatus" = "MFA状況"
        "AuthenticationMethod" = "認証方法"
        "FallbackMethod" = "フォールバック方法"
        "LastMFASetupDate" = "最終MFA設定日"
        "Compliance" = "コンプライアンス"
        "RiskLevel" = "リスクレベル"
        "LastAccess" = "最終アクセス"
        "MonthlyMeetingParticipation" = "月次会議参加"
        "MonthlyChatCount" = "月次チャット数"
        "StorageUsedMB" = "使用ストレージ(MB)"
        "AppUsageCount" = "アプリ使用数"
        "UsageLevel" = "使用レベル"
    }
    
    return $fieldMapping[$FieldName] ?? $FieldName
}

function Convert-DataToInteractiveHTML {
    param(
        [array]$Data,
        [string]$ReportType
    )
    
    $html = ""
    
    switch ($ReportType) {
        "DailyReport" {
            foreach ($item in $Data) {
                $html += "<tr class='data-row' data-user='$($item.UserName)' data-level='$($item.ActivityLevel)' data-score='$($item.ActivityScore)'>"
                $html += "<td data-field='UserName'>$($item.UserName ?? '不明')</td>"
                $html += "<td data-field='UserPrincipalName'>$($item.UserPrincipalName ?? '不明')</td>"
                $html += "<td data-field='DailyLogins'>$($item.DailyLogins ?? 0)</td>"
                $html += "<td data-field='DailyEmails'>$($item.DailyEmails ?? 0)</td>"
                $html += "<td data-field='TeamsActivity'>$($item.TeamsActivity ?? 0)</td>"
                $html += "<td data-field='ActivityLevel'><span class='badge badge-$(if($item.ActivityLevel -eq "高") { "active" } elseif($item.ActivityLevel -eq "中") { "warning" } else { "inactive" })'>$($item.ActivityLevel ?? "不明")</span></td>"
                $html += "<td data-field='ActivityScore'>$($item.ActivityScore ?? 0)</td>"
                $html += "<td data-field='Status'><span class='badge badge-$(if($item.Status -eq "アクティブ") { "active" } else { "inactive" })'>$($item.Status ?? "不明")</span></td>"
                $html += "</tr>"
            }
        }
        "Users" {
            foreach ($item in $Data) {
                $html += "<tr class='data-row' data-user='$($item.DisplayName)' data-status='$($item.AccountStatus)'>"
                $html += "<td data-field='DisplayName'>$($item.DisplayName ?? '不明')</td>"
                $html += "<td data-field='UserPrincipalName'>$($item.UserPrincipalName ?? '不明')</td>"
                $html += "<td data-field='Email'>$($item.Email ?? '不明')</td>"
                $html += "<td data-field='AccountStatus'><span class='badge badge-$(if($item.AccountStatus -eq "有効") { "active" } else { "inactive" })'>$($item.AccountStatus)</span></td>"
                $html += "<td data-field='LicenseStatus'><span class='badge badge-enabled'>$($item.LicenseStatus ?? '不明')</span></td>"
                $html += "<td data-field='CreationDate'>$($item.CreationDate ?? '不明')</td>"
                $html += "</tr>"
            }
        }
        "LicenseAnalysis" {
            foreach ($item in $Data) {
                $html += "<tr class='data-row' data-license='$($item.LicenseName)' data-status='$($item.Status)'>"
                $html += "<td data-field='LicenseName'>$($item.LicenseName ?? '不明')</td>"
                $html += "<td data-field='SkuId'>$($item.SkuId ?? '不明')</td>"
                $html += "<td data-field='PurchasedQuantity'>$($item.PurchasedQuantity ?? 0)</td>"
                $html += "<td data-field='AssignedQuantity'>$($item.AssignedQuantity ?? 0)</td>"
                $html += "<td data-field='AvailableQuantity'>$($item.AvailableQuantity ?? 0)</td>"
                $html += "<td data-field='UsageRate'>$($item.UsageRate ?? 0)%</td>"
                $html += "<td data-field='MonthlyUnitPrice'>$($item.MonthlyUnitPrice ?? '¥0')</td>"
                $html += "<td data-field='MonthlyCost'>$($item.MonthlyCost ?? '¥0')</td>"
                $html += "<td data-field='Status'><span class='badge badge-$(if($item.Status -eq "利用可能") { "active" } else { "inactive" })'>$($item.Status ?? "不明")</span></td>"
                $html += "</tr>"
            }
        }
        default {
            # 汎用テーブル生成
            foreach ($item in $Data) {
                $html += "<tr class='data-row'>"
                $properties = $item.PSObject.Properties.Name
                foreach ($prop in $properties) {
                    $value = $item.$prop
                    if ($null -eq $value) { $value = "-" }
                    $html += "<td data-field='$prop'>$value</td>"
                }
                $html += "</tr>"
            }
        }
    }
    
    return $html
}

function Calculate-ReportStatistics {
    param(
        [array]$Data,
        [string]$ReportType
    )
    
    $stats = @{}
    
    switch ($ReportType) {
        "DailyReport" {
            $stats["TOTAL_USERS"] = $Data.Count
            $stats["ACTIVE_USERS"] = ($Data | Where-Object { $_.ActivityLevel -ne "低" }).Count
            $stats["HIGH_ACTIVITY"] = ($Data | Where-Object { $_.ActivityLevel -eq "高" }).Count
            $stats["MEDIUM_ACTIVITY"] = ($Data | Where-Object { $_.ActivityLevel -eq "中" }).Count
            $stats["LOW_ACTIVITY"] = ($Data | Where-Object { $_.ActivityLevel -eq "低" }).Count
            $stats["TOTAL_LOGINS"] = ($Data | Measure-Object DailyLogins -Sum).Sum
            $stats["TOTAL_EMAILS"] = ($Data | Measure-Object DailyEmails -Sum).Sum
            $stats["TOTAL_TEAMS"] = ($Data | Measure-Object TeamsActivity -Sum).Sum
        }
        "Users" {
            $stats["TOTAL_USERS"] = $Data.Count
            $stats["ACTIVE_USERS"] = ($Data | Where-Object { $_.AccountStatus -eq "有効" }).Count
            $stats["INACTIVE_USERS"] = ($Data | Where-Object { $_.AccountStatus -eq "無効" }).Count
        }
        "LicenseAnalysis" {
            $stats["TOTAL_LICENSES"] = $Data.Count
            $stats["TOTAL_PURCHASED"] = ($Data | Measure-Object PurchasedQuantity -Sum).Sum
            $stats["TOTAL_ASSIGNED"] = ($Data | Measure-Object AssignedQuantity -Sum).Sum
            $stats["TOTAL_AVAILABLE"] = ($Data | Measure-Object AvailableQuantity -Sum).Sum
            $stats["ACTIVE_LICENSES"] = ($Data | Where-Object { $_.Status -eq "利用可能" }).Count
        }
        default {
            $stats["TOTAL_RECORDS"] = $Data.Count
        }
    }
    
    return $stats
}

function Generate-InteractiveHTMLTemplate {
    param(
        [array]$Data,
        [string]$ReportType,
        [string]$Title,
        [string]$TableRows,
        [hashtable]$Statistics,
        [hashtable]$AdditionalVariables = @{}
    )
    
    # テーブルヘッダーを生成
    $tableHeaders = Generate-TableHeaders -Data $Data -ReportType $ReportType
    
    # フィルターオプションを生成
    $filterOptions = Generate-FilterOptions -Data $Data -ReportType $ReportType
    
    # 統計情報を表示用に整形
    $statisticsHTML = Generate-StatisticsHTML -Statistics $Statistics -ReportType $ReportType
    
    $template = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Title - Microsoft 365統合管理ツール</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@300;400;500;700&display=swap" rel="stylesheet">
    
    <!-- PDF生成ライブラリ -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf-autotable/3.5.31/jspdf.plugin.autotable.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js"></script>
    
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Noto Sans JP', 'Yu Gothic', 'Meiryo', 'MS Gothic', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: #f5f7fa;
            color: #333;
            line-height: 1.6;
            font-size: 14px;
        }
        
        .header {
            background: linear-gradient(135deg, #0f1419 0%, #2c3e50 100%);
            color: white;
            padding: 2rem;
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
            position: relative;
        }
        
        .header h1 {
            font-size: 2.2rem;
            margin-bottom: 0.5rem;
            display: flex;
            align-items: center;
            gap: 1rem;
            font-weight: 700;
        }
        
        .header .meta-info {
            font-size: 0.95rem;
            opacity: 0.95;
        }
        
        .header .stats {
            display: flex;
            gap: 2.5rem;
            margin-top: 1.2rem;
            flex-wrap: wrap;
        }
        
        .header .stat-item {
            display: flex;
            align-items: center;
            gap: 0.6rem;
            font-weight: 500;
        }
        
        .actions-bar {
            background: white;
            padding: 1rem 2rem;
            border-bottom: 1px solid #e8ecef;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 1rem;
        }
        
        .search-controls {
            display: flex;
            gap: 1rem;
            align-items: center;
            flex-wrap: wrap;
        }
        
        .search-input {
            padding: 0.5rem 1rem;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 0.9rem;
            width: 300px;
        }
        
        .filter-select {
            padding: 0.5rem 1rem;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 0.9rem;
            background: white;
        }
        
        .pdf-controls {
            display: flex;
            gap: 0.5rem;
        }
        
        .btn {
            padding: 0.5rem 1rem;
            border: none;
            border-radius: 4px;
            font-size: 0.9rem;
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 0.5rem;
            transition: all 0.3s;
        }
        
        .btn-primary {
            background: #3498db;
            color: white;
        }
        
        .btn-primary:hover {
            background: #2980b9;
        }
        
        .btn-secondary {
            background: #95a5a6;
            color: white;
        }
        
        .btn-secondary:hover {
            background: #7f8c8d;
        }
        
        .container {
            width: 100%;
            max-width: 100%;
            margin: 0 auto;
            padding: 1.5rem;
        }
        
        .table-container {
            background: white;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 4px 15px rgba(0,0,0,0.08);
            border: 1px solid #e8ecef;
        }
        
        .table-header {
            padding: 1.5rem 2rem;
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            border-bottom: 2px solid #dee2e6;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .table-title {
            font-size: 1.4rem;
            font-weight: 700;
            color: #2c3e50;
            display: flex;
            align-items: center;
            gap: 0.6rem;
        }
        
        .table-wrapper {
            overflow-x: auto;
            max-height: 600px;
            overflow-y: auto;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            table-layout: auto;
            min-width: 1000px;
        }
        
        th {
            background: linear-gradient(135deg, #34495e 0%, #2c3e50 100%);
            color: white;
            padding: 0.8rem 1rem;
            text-align: left;
            font-weight: 600;
            border: none;
            white-space: nowrap;
            font-size: 0.9rem;
            position: sticky;
            top: 0;
            z-index: 10;
        }
        
        td {
            padding: 0.8rem 1rem;
            border-bottom: 1px solid #f1f3f4;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            font-size: 0.9rem;
        }
        
        tbody tr:hover {
            background-color: #f8f9fa;
        }
        
        .data-row.hidden {
            display: none;
        }
        
        .badge {
            padding: 0.3rem 0.8rem;
            border-radius: 16px;
            font-size: 0.75rem;
            font-weight: 600;
            display: inline-block;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .badge-active {
            background: linear-gradient(135deg, #d4edda 0%, #c3e6cb 100%);
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .badge-warning {
            background: linear-gradient(135deg, #fff3cd 0%, #ffeaa7 100%);
            color: #856404;
            border: 1px solid #ffeaa7;
        }
        
        .badge-inactive {
            background: linear-gradient(135deg, #f8d7da 0%, #f5c6cb 100%);
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .badge-enabled {
            background: linear-gradient(135deg, #d1ecf1 0%, #bee5eb 100%);
            color: #0c5460;
            border: 1px solid #bee5eb;
        }
        
        .no-results {
            text-align: center;
            padding: 2rem;
            color: #666;
            font-style: italic;
        }
        
        .footer {
            text-align: center;
            padding: 2.5rem;
            color: white;
            font-size: 0.9rem;
            background: #2c3e50;
            margin-top: 2rem;
        }
        
        .footer p {
            margin-bottom: 0.5rem;
        }
        
        /* 印刷用スタイル */
        @media print {
            .actions-bar, .pdf-controls {
                display: none !important;
            }
            
            .header {
                background: #2c3e50 !important;
                -webkit-print-color-adjust: exact;
            }
            
            .table-wrapper {
                max-height: none !important;
                overflow: visible !important;
            }
            
            table {
                break-inside: avoid;
            }
            
            .data-row.hidden {
                display: none !important;
            }
        }
    </style>
</head>
<body>
    <header class="header">
        <div class="container">
            <h1>
                <i class="fas fa-chart-line"></i>
                $Title - Microsoft 365統合管理レポート
            </h1>
            <div class="meta-info">
                <div class="stats">
                    $statisticsHTML
                    <div class="stat-item">
                        <i class="fas fa-calendar-alt"></i>
                        <span>生成日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</span>
                    </div>
                </div>
            </div>
        </div>
    </header>

    <div class="actions-bar">
        <div class="search-controls">
            <input type="text" class="search-input" id="searchInput" placeholder="🔍 検索..." onkeyup="performSearch()">
            <select class="filter-select" id="filterSelect" onchange="performFilter()">
                <option value="">すべて表示</option>
                $filterOptions
            </select>
            <select class="filter-select" id="categoryFilter" onchange="performFilter()">
                <option value="">カテゴリー</option>
                <option value="service">サービス</option>
                <option value="user">ユーザー</option>
                <option value="license">ライセンス</option>
                <option value="system">システム</option>
            </select>
            <select class="filter-select" id="dateFilter" onchange="performFilter()">
                <option value="">期間</option>
                <option value="today">今日</option>
                <option value="week">今週</option>
                <option value="month">今月</option>
                <option value="year">今年</option>
            </select>
            <button class="btn btn-secondary" onclick="resetFilters()">
                <i class="fas fa-refresh"></i> リセット
            </button>
        </div>
        <div class="pdf-controls">
            <button class="btn btn-primary" onclick="printReport()">
                <i class="fas fa-print"></i> 印刷
            </button>
            <button class="btn btn-primary" onclick="downloadPDF()">
                <i class="fas fa-download"></i> PDF ダウンロード
            </button>
        </div>
    </div>

    <main class="container">
        <section class="table-container">
            <div class="table-header">
                <div class="table-title">
                    <i class="fas fa-table"></i>
                    $Title 詳細データ
                </div>
                <div class="table-info">
                    <span id="visibleCount">$($Data.Count)</span> / $($Data.Count) 件表示
                </div>
            </div>
            
            <div class="table-wrapper">
                <table id="dataTable">
                    <thead>
                        <tr>
                            $tableHeaders
                        </tr>
                    </thead>
                    <tbody id="tableBody">
                        $TableRows
                    </tbody>
                </table>
                <div id="noResults" class="no-results" style="display: none;">
                    <i class="fas fa-search"></i>
                    <p>検索条件に一致するデータが見つかりませんでした。</p>
                </div>
            </div>
        </section>
    </main>

    <footer class="footer">
        <p><strong>Microsoft 365統合管理ツール</strong> - $Title</p>
        <p>PowerShell 7.5.1 | Microsoft Graph API v1.0 | Generated on $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</p>
        <p>© 2025 Microsoft 365統合管理システム - すべての権利を保有</p>
    </footer>

    <script>
        // 検索機能
        function performSearch() {
            const searchTerm = document.getElementById('searchInput').value.toLowerCase();
            const rows = document.querySelectorAll('.data-row');
            const filterSelect = document.getElementById('filterSelect');
            const filterValue = filterSelect.value;
            
            let visibleCount = 0;
            
            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                const matchesSearch = text.includes(searchTerm);
                const matchesFilter = filterValue === '' || matchesFilterCondition(row, filterValue);
                
                if (matchesSearch && matchesFilter) {
                    row.classList.remove('hidden');
                    visibleCount++;
                } else {
                    row.classList.add('hidden');
                }
            });
            
            updateVisibleCount(visibleCount);
        }
        
        // フィルター機能
        function performFilter() {
            const filterSelect = document.getElementById('filterSelect');
            const categoryFilter = document.getElementById('categoryFilter');
            const dateFilter = document.getElementById('dateFilter');
            const filterValue = filterSelect.value;
            const categoryValue = categoryFilter.value;
            const dateValue = dateFilter.value;
            const searchTerm = document.getElementById('searchInput').value.toLowerCase();
            const rows = document.querySelectorAll('.data-row');
            
            let visibleCount = 0;
            
            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                const matchesSearch = text.includes(searchTerm);
                const matchesFilter = filterValue === '' || matchesFilterCondition(row, filterValue);
                const matchesCategory = categoryValue === '' || matchesCategoryCondition(row, categoryValue);
                const matchesDate = dateValue === '' || matchesDateCondition(row, dateValue);
                
                if (matchesSearch && matchesFilter && matchesCategory && matchesDate) {
                    row.classList.remove('hidden');
                    visibleCount++;
                } else {
                    row.classList.add('hidden');
                }
            });
            
            updateVisibleCount(visibleCount);
        }
        
        // フィルター条件チェック
        function matchesFilterCondition(row, filterValue) {
            switch(filterValue) {
                case 'active':
                    return row.querySelector('[data-field="Status"]')?.textContent.includes('アクティブ') || 
                           row.querySelector('[data-field="AccountStatus"]')?.textContent.includes('有効');
                case 'inactive':
                    return row.querySelector('[data-field="Status"]')?.textContent.includes('非アクティブ') || 
                           row.querySelector('[data-field="AccountStatus"]')?.textContent.includes('無効');
                case 'high':
                    return row.querySelector('[data-field="ActivityLevel"]')?.textContent.includes('高');
                case 'medium':
                    return row.querySelector('[data-field="ActivityLevel"]')?.textContent.includes('中');
                case 'low':
                    return row.querySelector('[data-field="ActivityLevel"]')?.textContent.includes('低');
                case 'normal':
                    return row.querySelector('[data-field="ServiceStatus"]')?.textContent.includes('正常') ||
                           row.querySelector('[data-field="Status"]')?.textContent.includes('正常');
                case 'warning':
                    return row.querySelector('[data-field="ServiceStatus"]')?.textContent.includes('警告') ||
                           row.querySelector('[data-field="Status"]')?.textContent.includes('警告');
                case 'error':
                    return row.querySelector('[data-field="ServiceStatus"]')?.textContent.includes('エラー') ||
                           row.querySelector('[data-field="Status"]')?.textContent.includes('エラー');
                default:
                    return true;
            }
        }
        
        // カテゴリーフィルター条件チェック
        function matchesCategoryCondition(row, categoryValue) {
            switch(categoryValue) {
                case 'service':
                    return row.querySelector('[data-field="ServiceName"]') !== null;
                case 'user':
                    return row.querySelector('[data-field="UserName"]') !== null || 
                           row.querySelector('[data-field="DisplayName"]') !== null;
                case 'license':
                    return row.querySelector('[data-field="LicenseName"]') !== null;
                case 'system':
                    return row.querySelector('[data-field="PerformanceScore"]') !== null;
                default:
                    return true;
            }
        }
        
        // 日付フィルター条件チェック
        function matchesDateCondition(row, dateValue) {
            const today = new Date();
            const lastCheckCell = row.querySelector('[data-field="LastCheck"]');
            const creationDateCell = row.querySelector('[data-field="CreationDate"]');
            
            if (!lastCheckCell && !creationDateCell) {
                return true;
            }
            
            const dateText = lastCheckCell?.textContent || creationDateCell?.textContent;
            if (!dateText || dateText === '-' || dateText === '不明') {
                return true;
            }
            
            // 簡易的な日付チェック（実際の実装では正規表現を使用）
            switch(dateValue) {
                case 'today':
                    return dateText.includes(today.toISOString().substr(0, 10));
                case 'week':
                    return true; // 週次フィルタリングの実装が必要
                case 'month':
                    return true; // 月次フィルタリングの実装が必要
                case 'year':
                    return dateText.includes(today.getFullYear().toString());
                default:
                    return true;
            }
        }
        
        // 表示件数更新
        function updateVisibleCount(count) {
            document.getElementById('visibleCount').textContent = count;
            const noResults = document.getElementById('noResults');
            const tableBody = document.getElementById('tableBody');
            
            if (count === 0) {
                noResults.style.display = 'block';
                tableBody.style.display = 'none';
            } else {
                noResults.style.display = 'none';
                tableBody.style.display = 'table-row-group';
            }
        }
        
        // フィルターリセット
        function resetFilters() {
            document.getElementById('searchInput').value = '';
            document.getElementById('filterSelect').value = '';
            document.getElementById('categoryFilter').value = '';
            document.getElementById('dateFilter').value = '';
            
            const rows = document.querySelectorAll('.data-row');
            rows.forEach(row => row.classList.remove('hidden'));
            
            updateVisibleCount(rows.length);
        }
        
        // 印刷機能
        function printReport() {
            window.print();
        }
        
        // PDF ダウンロード機能
        function downloadPDF() {
            const element = document.body;
            const options = {
                margin: 1,
                filename: '$Title_$(Get-Date -Format 'yyyyMMdd_HHmmss').pdf',
                image: { type: 'jpeg', quality: 0.98 },
                html2canvas: { scale: 2 },
                jsPDF: { unit: 'in', format: 'a4', orientation: 'landscape' }
            };
            
            html2pdf().from(element).set(options).save();
        }
        
        // 初期化
        document.addEventListener('DOMContentLoaded', function() {
            updateVisibleCount(document.querySelectorAll('.data-row').length);
        });
    </script>
</body>
</html>
"@
    
    return $template
}

function Generate-TableHeaders {
    param(
        [array]$Data,
        [string]$ReportType
    )
    
    $headers = ""
    
    switch ($ReportType) {
        "DailyReport" {
            $headers = @(
                "<th>ユーザー名</th>",
                "<th>ユーザープリンシパル名</th>",
                "<th>日次ログイン</th>",
                "<th>日次メール</th>",
                "<th>Teamsアクティビティ</th>",
                "<th>アクティビティレベル</th>",
                "<th>アクティビティスコア</th>",
                "<th>ステータス</th>"
            ) -join "`n"
        }
        "Users" {
            $headers = @(
                "<th>表示名</th>",
                "<th>ユーザープリンシパル名</th>",
                "<th>メールアドレス</th>",
                "<th>アカウントステータス</th>",
                "<th>ライセンス状況</th>",
                "<th>作成日</th>"
            ) -join "`n"
        }
        "LicenseAnalysis" {
            $headers = @(
                "<th>ライセンス名</th>",
                "<th>SKU ID</th>",
                "<th>購入数</th>",
                "<th>割り当て済み</th>",
                "<th>利用可能</th>",
                "<th>利用率 (%)</th>",
                "<th>月額単価</th>",
                "<th>月額コスト</th>",
                "<th>ステータス</th>"
            ) -join "`n"
        }
        default {
            if ($Data.Count -gt 0) {
                $properties = $Data[0].PSObject.Properties.Name
                $headers = ($properties | ForEach-Object { 
                    $japaneseLabel = Convert-FieldNameToJapanese $_
                    "<th>$japaneseLabel</th>"
                }) -join "`n"
            }
        }
    }
    
    return $headers
}

function Generate-FilterOptions {
    param(
        [array]$Data,
        [string]$ReportType
    )
    
    $options = ""
    
    switch ($ReportType) {
        "DailyReport" {
            $options = @(
                '<option value="active">アクティブユーザー</option>',
                '<option value="inactive">非アクティブユーザー</option>',
                '<option value="high">高アクティビティ</option>',
                '<option value="medium">中アクティビティ</option>',
                '<option value="low">低アクティビティ</option>'
            ) -join "`n"
        }
        "Users" {
            $options = @(
                '<option value="active">有効アカウント</option>',
                '<option value="inactive">無効アカウント</option>'
            ) -join "`n"
        }
        "LicenseAnalysis" {
            $options = @(
                '<option value="active">利用可能</option>',
                '<option value="inactive">利用不可</option>'
            ) -join "`n"
        }
        default {
            $options = @(
                '<option value="active">アクティブ</option>',
                '<option value="inactive">非アクティブ</option>',
                '<option value="normal">正常</option>',
                '<option value="warning">警告</option>',
                '<option value="error">エラー</option>'
            ) -join "`n"
        }
    }
    
    return $options
}

function Generate-StatisticsHTML {
    param(
        [hashtable]$Statistics,
        [string]$ReportType
    )
    
    $html = ""
    
    switch ($ReportType) {
        "DailyReport" {
            $html = @(
                "<div class='stat-item'><i class='fas fa-users'></i><span>総ユーザー数: <strong>$($Statistics.TOTAL_USERS)</strong> 人</span></div>",
                "<div class='stat-item'><i class='fas fa-user-check'></i><span>アクティブユーザー: <strong>$($Statistics.ACTIVE_USERS)</strong> 人</span></div>",
                "<div class='stat-item'><i class='fas fa-sign-in-alt'></i><span>総ログイン数: <strong>$($Statistics.TOTAL_LOGINS)</strong> 回</span></div>",
                "<div class='stat-item'><i class='fas fa-envelope'></i><span>総メール数: <strong>$($Statistics.TOTAL_EMAILS)</strong> 通</span></div>"
            ) -join "`n"
        }
        "Users" {
            $html = @(
                "<div class='stat-item'><i class='fas fa-users'></i><span>総ユーザー数: <strong>$($Statistics.TOTAL_USERS)</strong> 人</span></div>",
                "<div class='stat-item'><i class='fas fa-user-check'></i><span>有効アカウント: <strong>$($Statistics.ACTIVE_USERS)</strong> 人</span></div>",
                "<div class='stat-item'><i class='fas fa-user-times'></i><span>無効アカウント: <strong>$($Statistics.INACTIVE_USERS)</strong> 人</span></div>"
            ) -join "`n"
        }
        "LicenseAnalysis" {
            $html = @(
                "<div class='stat-item'><i class='fas fa-key'></i><span>ライセンス数: <strong>$($Statistics.TOTAL_LICENSES)</strong> 種類</span></div>",
                "<div class='stat-item'><i class='fas fa-shopping-cart'></i><span>購入総数: <strong>$($Statistics.TOTAL_PURCHASED)</strong> 個</span></div>",
                "<div class='stat-item'><i class='fas fa-user-tag'></i><span>割り当て済み: <strong>$($Statistics.TOTAL_ASSIGNED)</strong> 個</span></div>",
                "<div class='stat-item'><i class='fas fa-box'></i><span>利用可能: <strong>$($Statistics.TOTAL_AVAILABLE)</strong> 個</span></div>"
            ) -join "`n"
        }
        default {
            $html = "<div class='stat-item'><i class='fas fa-database'></i><span>総レコード数: <strong>$($Statistics.TOTAL_RECORDS)</strong> 件</span></div>"
        }
    }
    
    return $html
}

Export-ModuleMember -Function Generate-InteractiveHTMLReport