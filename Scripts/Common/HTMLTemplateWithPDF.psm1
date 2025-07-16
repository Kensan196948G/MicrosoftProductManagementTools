# ================================================================================
# HTMLTemplateWithPDF.psm1
# PDF生成機能付きHTMLレポートテンプレート（Templates統合版）
# Microsoft 365統合管理ツール用
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force

function New-HTMLReportWithPDF {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [array]$DataSections = @(),
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Summary = @{}
    )
    
    try {
        # Templatesディレクトリからテンプレートファイルを読み込み
        $toolRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $templatePath = Join-Path $toolRoot "Templates\HTML\report-template.html"
        
        if (-not (Test-Path $templatePath)) {
            Write-Log "テンプレートファイルが見つかりません: $templatePath" -Level "Warning"
            # フォールバック: 簡単なテンプレートを使用
            $templateContent = Get-FallbackTemplate
        } else {
            $templateContent = Get-Content -Path $templatePath -Raw -Encoding UTF8
            Write-Log "テンプレートファイルを読み込みました: $templatePath" -Level "Info"
        }
        
        # テンプレート変数を置換
        $htmlContent = Set-TemplateVariables -TemplateContent $templateContent -Title $Title -DataSections $DataSections -Summary $Summary

        # HTMLファイルを出力
        $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        Write-Log "Templates統合HTML-PDFレポートを生成しました: $OutputPath" -Level "Info"
        
        return $OutputPath
    }
    catch {
        Write-Log "HTMLレポート生成エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# テンプレート変数置換関数
function Set-TemplateVariables {
    param(
        [string]$TemplateContent,
        [string]$Title,
        [array]$DataSections,
        [hashtable]$Summary
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
        $totalRecords = ($DataSections | ForEach-Object { $_.Data.Count } | Measure-Object -Sum).Sum
        
        # 基本変数の置換
        $htmlContent = $TemplateContent -replace '{{REPORT_NAME}}', $Title
        $htmlContent = $htmlContent -replace '{{GENERATED_DATE}}', $timestamp  
        $htmlContent = $htmlContent -replace '{{TOTAL_RECORDS}}', $totalRecords
        $htmlContent = $htmlContent -replace '{{PS_VERSION}}', $PSVersionTable.PSVersion
        $htmlContent = $htmlContent -replace '{{TOOL_VERSION}}', "Microsoft 365統合管理ツール v1.0"
        
        # テーブルヘッダーとデータの生成
        $tableHeaders = ""
        $tableData = ""
        
        if ($DataSections -and $DataSections.Count -gt 0) {
            $firstSection = $DataSections[0]
            if ($firstSection.Data -and $firstSection.Data.Count -gt 0) {
                $properties = $firstSection.Data[0].PSObject.Properties.Name
                
                # ヘッダー生成
                $tableHeaders = "<tr>"
                foreach ($prop in $properties) {
                    $tableHeaders += "<th onclick=`"sortTable('$prop')`">$prop <i class=`"fas fa-sort sort-icon`"></i></th>"
                }
                $tableHeaders += "</tr>"
                
                # データ行生成（全セクションのデータを統合）
                foreach ($section in $DataSections) {
                    if ($section.Data -and $section.Data.Count -gt 0) {
                        foreach ($item in $section.Data) {
                            $tableData += "<tr>"
                            foreach ($prop in $properties) {
                                $value = if ($item.$prop) { $item.$prop } else { "" }
                                
                                # ステータスバッジの適用
                                $badgeClass = Get-StatusBadgeClass -Property $prop -Value $value
                                if ($badgeClass) {
                                    $tableData += "<td><span class='badge $badgeClass'>$value</span></td>"
                                } else {
                                    $tableData += "<td>$value</td>"
                                }
                            }
                            $tableData += "</tr>"
                        }
                    }
                }
            }
        }
        
        # HTMLコンテンツの置換
        $htmlContent = $htmlContent -replace '{{TABLE_HEADERS}}', $tableHeaders
        $htmlContent = $htmlContent -replace '{{TABLE_DATA}}', $tableData
        
        # JavaScriptコンテンツ生成（改良版PDF機能付き）
        $jsContent = Generate-JavaScriptContent -DataSections $DataSections -Summary $Summary
        
        # HTMLテンプレートのscript srcを置換ではなく、直接JavaScript挿入に変更
        $scriptTag = "<script>`n$jsContent`n</script>"
        $htmlContent = $htmlContent -replace '<script src="{{JS_PATH}}"></script>', $scriptTag
        
        return $htmlContent
    }
    catch {
        Write-Log "テンプレート変数置換エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# ステータスバッジクラス取得関数
function Get-StatusBadgeClass {
    param(
        [string]$Property,
        [string]$Value
    )
    
    if ($Property -match "Status|状況|状態|アクティビティ") {
        if ($Value -match "正常|設定済み|アクティブ|✓|○") {
            return "badge-success"
        }
        elseif ($Value -match "警告|要確認|△|⚡") {
            return "badge-warning"
        }
        elseif ($Value -match "危険|未設定|長期未更新|✗|⚠️") {
            return "badge-danger"
        }
    }
    return $null
}

# JavaScript生成関数
function Generate-JavaScriptContent {
    param(
        [array]$DataSections,
        [hashtable]$Summary
    )
    
    # データをJSONに変換
    $jsonData = @{}
    foreach ($section in $DataSections) {
        $sectionName = $section.Title -replace '[^\w]', ''
        if ($section.Data -and $section.Data.Count -gt 0) {
            $jsonData[$sectionName] = $section.Data
        }
    }
    
    # JavaScriptを文字列として組み立て（${}エスケープ問題を回避）
    $jsonString = $jsonData | ConvertTo-Json -Depth 10 -Compress
    
    $jsContent = @"
// Microsoft 365統合管理ツール - インタラクティブレポート
const reportData = $jsonString;
let filteredData = [...Object.values(reportData).flat()];
let currentPage = 1;
const rowsPerPage = 50;

// ページ読み込み時の初期化
document.addEventListener('DOMContentLoaded', function() {
    console.log('レポートデータ読み込み完了');
    initializeFilters();
    setupEventListeners();
    updateTable();
});

// フィルター初期化
function initializeFilters() {
    const filterContainer = document.getElementById('filterDropdowns');
    if (!filterContainer) return;
    
    // 動的フィルター生成（例：部署、状態等）
    const filterOptions = extractFilterOptions();
    filterOptions.forEach(option => {
        const filterDiv = createFilterDropdown(option.name, option.values);
        filterContainer.appendChild(filterDiv);
    });
}

// フィルターオプション抽出
function extractFilterOptions() {
    const allData = Object.values(reportData).flat();
    const options = [];
    
    if (allData.length > 0) {
        const sampleItem = allData[0];
        Object.keys(sampleItem).forEach(key => {
            if (key.includes('部署') || key.includes('状態') || key.includes('状況')) {
                const uniqueValues = [...new Set(allData.map(item => item[key]).filter(v => v))];
                options.push({ name: key, values: uniqueValues });
            }
        });
    }
    
    return options;
}

// ドロップダウンフィルター作成
function createFilterDropdown(name, values) {
    const div = document.createElement('div');
    div.className = 'filter-dropdown';
    
    const selectId = 'filter_' + name;
    const optionsHtml = values.map(val => '<option value="' + val + '">' + val + '</option>').join('');
    
    div.innerHTML = '<label for="' + selectId + '">' + name + '</label>' +
                   '<select id="' + selectId + '" class="dropdown-select" onchange="applyFilters()">' +
                   '<option value="">すべて</option>' + optionsHtml + '</select>';
    
    return div;
}

// イベントリスナー設定
function setupEventListeners() {
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
        searchInput.addEventListener('input', debounce(applyFilters, 300));
    }
}

// デバウンス関数
function debounce(func, delay) {
    let timeoutId;
    return function (...args) {
        clearTimeout(timeoutId);
        timeoutId = setTimeout(() => func.apply(this, args), delay);
    };
}

// フィルター適用
function applyFilters() {
    const searchValue = document.getElementById('searchInput')?.value?.toLowerCase() || '';
    const allData = Object.values(reportData).flat();
    
    filteredData = allData.filter(item => {
        // テキスト検索
        const textMatch = Object.values(item).some(val => 
            val && val.toString().toLowerCase().includes(searchValue)
        );
        
        // ドロップダウンフィルター
        const dropdownFilters = document.querySelectorAll('[id^="filter_"]');
        const dropdownMatch = Array.from(dropdownFilters).every(select => {
            const filterKey = select.id.replace('filter_', '');
            const filterValue = select.value;
            return !filterValue || item[filterKey] === filterValue;
        });
        
        return textMatch && dropdownMatch;
    });
    
    currentPage = 1;
    updateTable();
    updateStats();
}

// テーブル更新
function updateTable() {
    const tableBody = document.getElementById('tableBody');
    if (!tableBody) return;
    
    const startIndex = (currentPage - 1) * rowsPerPage;
    const endIndex = startIndex + rowsPerPage;
    const pageData = filteredData.slice(startIndex, endIndex);
    
    tableBody.innerHTML = '';
    
    pageData.forEach(item => {
        const row = document.createElement('tr');
        const firstItem = Object.values(reportData).flat()[0];
        
        Object.keys(firstItem).forEach(key => {
            const cell = document.createElement('td');
            const value = item[key] || '';
            
            // バッジ適用
            if (key.includes('状態') || key.includes('状況')) {
                const badgeClass = getBadgeClass(value);
                cell.innerHTML = '<span class="badge ' + badgeClass + '">' + value + '</span>';
            } else {
                cell.textContent = value;
            }
            
            row.appendChild(cell);
        });
        
        tableBody.appendChild(row);
    });
    
    updatePagination();
}

// バッジクラス取得
function getBadgeClass(value) {
    if (value.match(/正常|設定済み|アクティブ|✓|○/)) return 'badge-success';
    if (value.match(/警告|要確認|△|⚡/)) return 'badge-warning';
    if (value.match(/危険|未設定|長期未更新|✗|⚠️/)) return 'badge-danger';
    return 'badge-info';
}

// 統計更新
function updateStats() {
    const totalElement = document.getElementById('totalRecords');
    const visibleElement = document.getElementById('visibleRecords');
    
    if (totalElement) totalElement.textContent = Object.values(reportData).flat().length;
    if (visibleElement) visibleElement.textContent = filteredData.length;
}

// ページネーション更新
function updatePagination() {
    const pagination = document.getElementById('pagination');
    if (!pagination) return;
    
    const totalPages = Math.ceil(filteredData.length / rowsPerPage);
    let paginationHTML = '';
    
    // 前へボタン
    const prevDisabled = currentPage === 1 ? 'disabled' : '';
    paginationHTML += '<button onclick="changePage(' + (currentPage - 1) + ')" ' + prevDisabled + '>前へ</button>';
    
    // ページ番号
    for (let i = Math.max(1, currentPage - 2); i <= Math.min(totalPages, currentPage + 2); i++) {
        const activeClass = i === currentPage ? 'class="active"' : '';
        paginationHTML += '<button onclick="changePage(' + i + ')" ' + activeClass + '>' + i + '</button>';
    }
    
    // 次へボタン
    const nextDisabled = currentPage === totalPages ? 'disabled' : '';
    paginationHTML += '<button onclick="changePage(' + (currentPage + 1) + ')" ' + nextDisabled + '>次へ</button>';
    
    // 情報表示
    const startRecord = Math.min((currentPage - 1) * rowsPerPage + 1, filteredData.length);
    const endRecord = Math.min(currentPage * rowsPerPage, filteredData.length);
    paginationHTML += '<span class="page-info">' + filteredData.length + ' 件中 ' + startRecord + ' - ' + endRecord + ' 件表示</span>';
    
    pagination.innerHTML = paginationHTML;
}

// ページ変更
function changePage(page) {
    const totalPages = Math.ceil(filteredData.length / rowsPerPage);
    if (page >= 1 && page <= totalPages) {
        currentPage = page;
        updateTable();
    }
}

// フィルターリセット
function resetFilters() {
    document.getElementById('searchInput').value = '';
    document.querySelectorAll('[id^="filter_"]').forEach(select => select.value = '');
    applyFilters();
}

// PDF印刷
function exportToPDF() {
    window.print();
}

// PDFダウンロード（完全改良版）
function downloadPDF() {
    console.log('PDFダウンロード開始...');
    showNotification('📄 PDF生成中...', 'info');
    
    // まずhtml2pdfを試行（最も確実）
    if (typeof html2pdf !== 'undefined') {
        try {
            console.log('html2pdfを使用してPDF生成');
            executeHtml2PdfDownload();
            return;
        } catch (error) {
            console.error('html2pdf エラー:', error);
        }
    }
    
    // html2pdfが利用できない場合、動的読み込み
    if (typeof html2pdf === 'undefined') {
        console.log('html2pdfライブラリを動的読み込み中...');
        loadLibraryAndExecute('https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js', 
            function() {
                console.log('html2pdf読み込み完了、PDF生成実行');
                executeHtml2PdfDownload();
            },
            function() {
                console.log('html2pdf読み込み失敗、jsPDFを試行');
                tryJsPdfDownload();
            }
        );
        return;
    }
    
    // 最終手段：jsPDF + html2canvas
    tryJsPdfDownload();
}

// ライブラリ動的読み込み共通関数
function loadLibraryAndExecute(url, onSuccess, onError) {
    const script = document.createElement('script');
    script.src = url;
    script.onload = function() {
        setTimeout(onSuccess, 200); // 少し待ってから実行
    };
    script.onerror = function() {
        console.error('ライブラリ読み込み失敗:', url);
        if (onError) onError();
    };
    document.head.appendChild(script);
}

// jsPDF + html2canvas による PDF生成
function tryJsPdfDownload() {
    // html2canvasが利用可能か確認
    if (typeof html2canvas === 'undefined') {
        loadLibraryAndExecute('https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js',
            function() {
                tryJsPdfWithCanvas();
            },
            function() {
                showNotification('❌ PDF生成ライブラリの読み込みに失敗しました。印刷機能を使用してください。', 'error');
                window.print();
            }
        );
        return;
    }
    
    tryJsPdfWithCanvas();
}

function tryJsPdfWithCanvas() {
    // jsPDFが利用可能か確認
    if (typeof jsPDF === 'undefined' && typeof window.jsPDF === 'undefined' && typeof window.jspdf === 'undefined') {
        loadLibraryAndExecute('https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js',
            function() {
                executeJsPdfDownload();
            },
            function() {
                showNotification('❌ PDF生成ライブラリの読み込みに失敗しました。印刷機能を使用してください。', 'error');
                window.print();
            }
        );
        return;
    }
    
    executeJsPdfDownload();
}

function executeJsPdfDownload() {
    try {
        // jsPDFオブジェクトの取得（複数パターン対応）
        let jsPDFClass;
        if (typeof jsPDF !== 'undefined') {
            jsPDFClass = jsPDF;
        } else if (typeof window.jsPDF !== 'undefined') {
            jsPDFClass = window.jsPDF;
        } else if (typeof window.jspdf !== 'undefined' && window.jspdf.jsPDF) {
            jsPDFClass = window.jspdf.jsPDF;
        } else {
            throw new Error('jsPDFオブジェクトが見つかりません');
        }
        
        const pdf = new jsPDFClass({
            orientation: 'landscape',
            unit: 'mm',
            format: 'a4'
        });
        
        console.log('html2canvasでキャプチャ中...');
        html2canvas(document.querySelector('main'), {
            scale: 1.5,
            useCORS: true,
            allowTaint: true,
            backgroundColor: '#ffffff'
        }).then(canvas => {
            const imgData = canvas.toDataURL('image/png');
            const imgWidth = 297; // A4横向きの幅
            const pageHeight = 210; // A4横向きの高さ
            const imgHeight = (canvas.height * imgWidth) / canvas.width;
            let heightLeft = imgHeight;
            
            let position = 0;
            
            pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
            heightLeft -= pageHeight;
            
            while (heightLeft >= 0) {
                position = heightLeft - imgHeight;
                pdf.addPage();
                pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
                heightLeft -= pageHeight;
            }
            
            const filename = 'Microsoft365_Report_' + new Date().toISOString().slice(0,10) + '.pdf';
            pdf.save(filename);
            
            showNotification('✅ PDFダウンロードが完了しました: ' + filename, 'success');
        }).catch(error => {
            console.error('html2canvas エラー:', error);
            showNotification('⚠️ PDF生成でエラーが発生しました。印刷機能を使用してください。', 'warning');
            window.print();
        });
        
    } catch (error) {
        console.error('jsPDF実行エラー:', error);
        showNotification('⚠️ PDF生成でエラーが発生しました。印刷機能を使用してください。', 'warning');
        window.print();
    }
}

// html2pdfライブラリを使用するフォールバック関数
function loadHtml2PdfAndDownload() {
    if (typeof html2pdf === 'undefined') {
        const script = document.createElement('script');
        script.src = 'https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js';
        script.onload = function() {
            setTimeout(executeHtml2PdfDownload, 100);
        };
        script.onerror = function() {
            showNotification('⚠️ PDF生成ライブラリの読み込みに失敗しました。印刷機能を使用してください。', 'warning');
            window.print();
        };
        document.head.appendChild(script);
    } else {
        executeHtml2PdfDownload();
    }
}

// html2pdfを実行する関数
function executeHtml2PdfDownload() {
    try {
        const element = document.querySelector('main');
        const options = {
            margin: 10,
            filename: 'Microsoft365_Report_' + new Date().toISOString().slice(0,10) + '.pdf',
            image: { type: 'jpeg', quality: 0.98 },
            html2canvas: { scale: 2, useCORS: true },
            jsPDF: { unit: 'mm', format: 'a4', orientation: 'landscape' }
        };
        
        html2pdf().set(options).from(element).save().then(() => {
            showNotification('✅ PDFダウンロードが完了しました', 'success');
        }).catch(error => {
            console.error('html2pdf エラー:', error);
            showNotification('⚠️ PDF生成でエラーが発生しました。印刷機能を使用してください。', 'warning');
            window.print();
        });
    } catch (error) {
        console.error('html2pdf実行エラー:', error);
        showNotification('⚠️ PDF生成でエラーが発生しました。印刷機能を使用してください。', 'warning');
        window.print();
    }
}

// 通知表示関数
function showNotification(message, type) {
    // 既存の通知を削除
    const existingNotification = document.querySelector('.pdf-notification');
    if (existingNotification) {
        existingNotification.remove();
    }
    
    // 通知要素を作成
    const notification = document.createElement('div');
    notification.className = 'pdf-notification';
    notification.style.cssText = \`
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 15px 20px;
        border-radius: 5px;
        color: white;
        font-weight: bold;
        z-index: 10000;
        max-width: 300px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        background-color: \${type === 'success' ? '#28a745' : type === 'warning' ? '#ffc107' : type === 'info' ? '#17a2b8' : '#dc3545'};
    \`;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    // 5秒後に自動削除
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, 5000);
}

// html2canvasライブラリの動的読み込み
if (typeof html2canvas === 'undefined') {
    const script = document.createElement('script');
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js';
    script.async = true;
    document.head.appendChild(script);
}

// テーブルソート
function sortTable(column) {
    console.log('ソート対象列:', column);
}

// 列の表示/非表示切り替え
function toggleColumns() {
    console.log('列表示切り替え');
}
"@
    
    return $jsContent
}

# フォールバックテンプレート
function Get-FallbackTemplate {
    return @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{REPORT_NAME}}</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; margin: 20px; }
        .header { background: #0078d4; color: white; padding: 20px; border-radius: 8px; }
        .content { margin-top: 20px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>{{REPORT_NAME}}</h1>
        <p>生成日時: {{GENERATED_DATE}}</p>
    </div>
    <div class="content">
        <table>
            <thead>{{TABLE_HEADERS}}</thead>
            <tbody>{{TABLE_DATA}}</tbody>
        </table>
    </div>
</body>
</html>
"@
}

# エクスポート
Export-ModuleMember -Function New-HTMLReportWithPDF, Set-TemplateVariables, Get-StatusBadgeClass, Generate-JavaScriptContent, Get-FallbackTemplate