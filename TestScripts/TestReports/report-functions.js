// ================================================================================
// Microsoft 365統合管理ツール - レポート用JavaScript
// 検索、フィルター、ソート、ページネーション機能
// ================================================================================

// グローバル変数
let originalData = [];
let filteredData = [];
let currentPage = 1;
let itemsPerPage = 50;
let activeFilters = {};
let sortColumn = null;
let sortDirection = 'asc';
let searchSuggestions = new Set();

// 初期化
document.addEventListener('DOMContentLoaded', function() {
    initializeData();
    setupEventListeners();
    generateFilterDropdowns();
    
    // 初期表示時にフィルターを適用
    applyAllFilters();
    updateDisplay();
});

// データ初期化
function initializeData() {
    // テーブルからデータを読み込み
    const table = document.getElementById('dataTable');
    const tbody = table.querySelector('tbody');
    const rows = tbody.querySelectorAll('tr');
    
    originalData = Array.from(rows).map(row => {
        const cells = row.querySelectorAll('td');
        const data = {};
        const headers = table.querySelectorAll('th');
        
        headers.forEach((header, index) => {
            const columnName = header.textContent.trim();
            data[columnName] = cells[index] ? cells[index].textContent.trim() : '';
        });
        
        return { element: row, data: data };
    });
    
    filteredData = [...originalData];
    
    // 検索サジェスト用のデータ収集
    originalData.forEach(item => {
        Object.values(item.data).forEach(value => {
            if (value && value.length > 2) {
                searchSuggestions.add(value);
            }
        });
    });
}

// イベントリスナー設定
function setupEventListeners() {
    // 検索ボックス
    const searchInput = document.getElementById('searchInput');
    searchInput.addEventListener('input', debounce(handleSearch, 300));
    searchInput.addEventListener('focus', showSearchSuggestions);
    searchInput.addEventListener('blur', () => {
        setTimeout(hideSearchSuggestions, 200);
    });
    
    // テーブルヘッダーのソート
    const headers = document.querySelectorAll('th');
    headers.forEach((header, index) => {
        header.addEventListener('click', () => sortTable(index));
        header.innerHTML += ' <i class="fas fa-sort sort-icon"></i>';
    });
    
    // ウィンドウリサイズ
    window.addEventListener('resize', debounce(adjustTableLayout, 250));
}

// フィルタードロップダウン生成
function generateFilterDropdowns() {
    const container = document.getElementById('filterDropdowns');
    const headers = document.querySelectorAll('th');
    
    // 各カラムのユニーク値を収集
    const columnValues = {};
    headers.forEach((header, index) => {
        const columnName = header.textContent.replace(' ', '').trim();
        columnValues[columnName] = new Set();
        
        originalData.forEach(item => {
            const value = item.data[columnName];
            if (value) {
                columnValues[columnName].add(value);
            }
        });
    });
    
    // ドロップダウンを生成（値が10個以下のカラムのみ）
    Object.entries(columnValues).forEach(([columnName, values]) => {
        if (values.size > 1 && values.size <= 10) {
            const dropdown = createFilterDropdown(columnName, Array.from(values));
            container.appendChild(dropdown);
        }
    });
}

// フィルタードロップダウン作成
function createFilterDropdown(columnName, values) {
    const container = document.createElement('div');
    container.className = 'filter-dropdown';
    
    const label = document.createElement('label');
    label.textContent = columnName;
    label.setAttribute('for', `filter-${columnName}`);
    
    const select = document.createElement('select');
    select.id = `filter-${columnName}`;
    select.className = 'dropdown-select';
    select.addEventListener('change', (e) => handleFilterChange(columnName, e.target.value));
    
    // デフォルトオプション
    const defaultOption = document.createElement('option');
    defaultOption.value = '';
    defaultOption.textContent = 'すべて';
    select.appendChild(defaultOption);
    
    // 値オプション
    values.sort().forEach(value => {
        const option = document.createElement('option');
        option.value = value;
        option.textContent = value;
        select.appendChild(option);
    });
    
    container.appendChild(label);
    container.appendChild(select);
    
    return container;
}

// 検索処理
function handleSearch(event) {
    // 検索時は全フィルターを再適用
    applyAllFilters();
    updateDisplay();
}

// 検索サジェスト表示
function showSearchSuggestions() {
    const input = document.getElementById('searchInput');
    const suggestionsBox = document.getElementById('searchSuggestions');
    const searchTerm = input.value.toLowerCase();
    
    if (searchTerm.length < 2) {
        hideSearchSuggestions();
        return;
    }
    
    const matches = Array.from(searchSuggestions)
        .filter(suggestion => suggestion.toLowerCase().includes(searchTerm))
        .slice(0, 10);
    
    if (matches.length > 0) {
        suggestionsBox.innerHTML = matches.map(match => 
            `<div class="suggestion-item" onclick="selectSuggestion('${match}')">${match}</div>`
        ).join('');
        suggestionsBox.classList.add('active');
    } else {
        hideSearchSuggestions();
    }
}

// 検索サジェスト非表示
function hideSearchSuggestions() {
    const suggestionsBox = document.getElementById('searchSuggestions');
    suggestionsBox.classList.remove('active');
}

// サジェスト選択
function selectSuggestion(value) {
    const input = document.getElementById('searchInput');
    input.value = value;
    hideSearchSuggestions();
    handleSearch({ target: input });
}

// フィルター変更処理
function handleFilterChange(columnName, value) {
    if (value === '' || value === 'すべて') {
        delete activeFilters[columnName];
    } else {
        activeFilters[columnName] = value;
    }
    
    // フィルターを再適用
    applyAllFilters();
    updateDisplay();
    updateActiveFiltersDisplay();
}

// 全フィルター適用
function applyAllFilters() {
    // 元のデータから開始（検索フィルターも含めて再適用）
    let data = [...originalData];
    
    // 検索フィルターを適用
    const searchInput = document.getElementById('searchInput');
    if (searchInput && searchInput.value.trim() !== '') {
        const searchTerm = searchInput.value.toLowerCase();
        data = data.filter(item => {
            return Object.values(item.data).some(value => 
                value.toLowerCase().includes(searchTerm)
            );
        });
    }
    
    // 各カラムフィルター適用
    Object.entries(activeFilters).forEach(([columnName, filterValue]) => {
        data = data.filter(item => item.data[columnName] === filterValue);
    });
    
    filteredData = data;
}

// アクティブフィルター表示更新
function updateActiveFiltersDisplay() {
    const container = document.getElementById('activeFilters');
    container.innerHTML = '';
    
    Object.entries(activeFilters).forEach(([columnName, value]) => {
        const tag = document.createElement('span');
        tag.className = 'filter-tag';
        tag.innerHTML = `
            ${columnName}: ${value}
            <span class="remove" onclick="removeFilter('${columnName}')">×</span>
        `;
        container.appendChild(tag);
    });
}

// フィルター削除
function removeFilter(columnName) {
    // アクティブフィルターから削除
    delete activeFilters[columnName];
    
    // 対応するドロップダウンを「すべて」に設定
    const dropdown = document.getElementById(`filter-${columnName}`);
    if (dropdown) {
        dropdown.value = '';
    }
    
    // 全フィルターを再適用
    applyAllFilters();
    
    // 表示更新
    updateDisplay();
    updateActiveFiltersDisplay();
}

// フィルターリセット
function resetFilters() {
    // 検索ボックスクリア
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
        searchInput.value = '';
    }
    
    // ドロップダウンリセット
    document.querySelectorAll('.dropdown-select').forEach(select => {
        select.value = '';
    });
    
    // フィルタークリア
    activeFilters = {};
    
    // 全フィルターを再適用（検索もクリアされているため、元データに戻る）
    applyAllFilters();
    
    // 表示更新
    updateDisplay();
    updateActiveFiltersDisplay();
}

// テーブルソート
function sortTable(columnIndex) {
    const headers = document.querySelectorAll('th');
    const columnName = headers[columnIndex].textContent.replace(' ', '').trim();
    
    // ソート方向切り替え
    if (sortColumn === columnName) {
        sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
    } else {
        sortColumn = columnName;
        sortDirection = 'asc';
    }
    
    // ソート実行
    filteredData.sort((a, b) => {
        const aValue = a.data[columnName];
        const bValue = b.data[columnName];
        
        // 数値判定
        const aNum = parseFloat(aValue);
        const bNum = parseFloat(bValue);
        
        if (!isNaN(aNum) && !isNaN(bNum)) {
            return sortDirection === 'asc' ? aNum - bNum : bNum - aNum;
        }
        
        // 文字列ソート
        const result = aValue.localeCompare(bValue, 'ja');
        return sortDirection === 'asc' ? result : -result;
    });
    
    // ヘッダーアイコン更新
    headers.forEach((header, index) => {
        header.classList.remove('sorted-asc', 'sorted-desc');
        const icon = header.querySelector('.sort-icon');
        icon.className = 'fas fa-sort sort-icon';
    });
    
    headers[columnIndex].classList.add(`sorted-${sortDirection}`);
    const sortIcon = headers[columnIndex].querySelector('.sort-icon');
    sortIcon.className = `fas fa-sort-${sortDirection === 'asc' ? 'up' : 'down'} sort-icon`;
    
    updateDisplay();
}

// 表示更新
function updateDisplay() {
    const tbody = document.getElementById('tableBody');
    
    // すべての行を非表示
    originalData.forEach(item => {
        item.element.style.display = 'none';
    });
    
    // フィルター済みデータを表示
    const startIndex = (currentPage - 1) * itemsPerPage;
    const endIndex = startIndex + itemsPerPage;
    const pageData = filteredData.slice(startIndex, endIndex);
    
    pageData.forEach(item => {
        item.element.style.display = '';
    });
    
    // 統計情報更新
    document.getElementById('visibleRecords').textContent = filteredData.length;
    
    // ページネーション更新
    updatePagination();
}

// ページネーション更新
function updatePagination() {
    const totalPages = Math.ceil(filteredData.length / itemsPerPage);
    const pagination = document.getElementById('pagination');
    
    let html = '';
    
    // 前へボタン
    html += `<button onclick="goToPage(${currentPage - 1})" ${currentPage === 1 ? 'disabled' : ''}>
                <i class="fas fa-chevron-left"></i>
             </button>`;
    
    // ページ番号
    const maxButtons = 7;
    let startPage = Math.max(1, currentPage - Math.floor(maxButtons / 2));
    let endPage = Math.min(totalPages, startPage + maxButtons - 1);
    
    if (endPage - startPage < maxButtons - 1) {
        startPage = Math.max(1, endPage - maxButtons + 1);
    }
    
    if (startPage > 1) {
        html += `<button onclick="goToPage(1)">1</button>`;
        if (startPage > 2) {
            html += `<span>...</span>`;
        }
    }
    
    for (let i = startPage; i <= endPage; i++) {
        html += `<button onclick="goToPage(${i})" class="${i === currentPage ? 'active' : ''}">${i}</button>`;
    }
    
    if (endPage < totalPages) {
        if (endPage < totalPages - 1) {
            html += `<span>...</span>`;
        }
        html += `<button onclick="goToPage(${totalPages})">${totalPages}</button>`;
    }
    
    // 次へボタン
    html += `<button onclick="goToPage(${currentPage + 1})" ${currentPage === totalPages ? 'disabled' : ''}>
                <i class="fas fa-chevron-right"></i>
             </button>`;
    
    // ページ情報
    html += `<span class="page-info">
                ${filteredData.length} 件中 ${(currentPage - 1) * itemsPerPage + 1} - 
                ${Math.min(currentPage * itemsPerPage, filteredData.length)} 件を表示
             </span>`;
    
    pagination.innerHTML = html;
}

// ページ移動
function goToPage(page) {
    const totalPages = Math.ceil(filteredData.length / itemsPerPage);
    if (page >= 1 && page <= totalPages) {
        currentPage = page;
        updateDisplay();
    }
}

// PDFエクスポート
function exportToPDF() {
    // PDF出力開始の通知
    const loadingOverlay = createLoadingOverlay();
    document.body.appendChild(loadingOverlay);
    
    try {
        // 現在のページネーション状態を保存
        const originalPage = currentPage;
        const originalItemsPerPage = itemsPerPage;
        
        // ページネーションを無効化（全データを表示）
        currentPage = 1;
        itemsPerPage = filteredData.length;
        
        // 長いセルの内容を検出してクラスを追加
        markLongContentCells();
        
        // 改ページ制御のためのクラスを追加
        addPageBreakClasses();
        
        // PDFヘッダー情報を追加
        addPDFHeaderInfo();
        
        // 全フィルタ済みデータを表示
        displayAllFilteredData();
        
        // 印刷ダイアログを開く
        window.print();
        
        // 元の状態に戻す
        setTimeout(() => {
            restoreOriginalState(originalPage, originalItemsPerPage);
            removePDFEnhancements();
            document.body.removeChild(loadingOverlay);
        }, 500);
        
    } catch (error) {
        console.error('PDF出力エラー:', error);
        alert('PDF出力中にエラーが発生しました。');
        document.body.removeChild(loadingOverlay);
    }
}

// ローディングオーバーレイを作成
function createLoadingOverlay() {
    const overlay = document.createElement('div');
    overlay.id = 'pdf-loading-overlay';
    overlay.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(255, 255, 255, 0.9);
        display: flex;
        justify-content: center;
        align-items: center;
        z-index: 9999;
        font-size: 18px;
        color: #0078d4;
    `;
    overlay.innerHTML = `
        <div>
            <div class="spinner"></div>
            PDF出力準備中...
        </div>
    `;
    return overlay;
}

// 長いセルの内容を検出してクラスを追加
function markLongContentCells() {
    const cells = document.querySelectorAll('td');
    cells.forEach(cell => {
        const content = cell.textContent.trim();
        if (content.length > 50 || content.includes('\n')) {
            cell.classList.add('long-content');
        }
    });
}

// 改ページ制御のためのクラスを追加
function addPageBreakClasses() {
    const rows = document.querySelectorAll('tbody tr');
    rows.forEach((row, index) => {
        // 25行ごとに改ページを促す
        if (index > 0 && index % 25 === 0) {
            row.classList.add('page-break');
        }
        
        // 重要な行は改ページしない
        if (row.querySelector('.badge-danger, .badge-warning')) {
            row.classList.add('no-break');
        }
    });
}

// PDFヘッダー情報を追加
function addPDFHeaderInfo() {
    const header = document.querySelector('.header');
    if (header) {
        const pdfInfo = document.createElement('div');
        pdfInfo.className = 'pdf-only';
        pdfInfo.style.cssText = `
            font-size: 9pt;
            color: rgba(255, 255, 255, 0.8);
            margin-top: 5mm;
            padding-top: 3mm;
            border-top: 1px solid rgba(255, 255, 255, 0.3);
        `;
        
        const now = new Date();
        const formatDate = now.toLocaleDateString('ja-JP', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        });
        
        pdfInfo.innerHTML = `
            <div style="display: flex; justify-content: space-between; flex-wrap: wrap;">
                <div>PDF生成日時: ${formatDate}</div>
                <div>フィルタ済み件数: ${filteredData.length}件 / 全件数: ${originalData.length}件</div>
            </div>
        `;
        
        header.appendChild(pdfInfo);
    }
}

// 全フィルタ済みデータを表示
function displayAllFilteredData() {
    const tbody = document.getElementById('tableBody');
    
    // 全ての行を非表示
    originalData.forEach(item => {
        item.element.style.display = 'none';
    });
    
    // フィルタ済みデータを表示
    filteredData.forEach(item => {
        item.element.style.display = '';
    });
    
    // ページネーション情報を更新
    updatePaginationForPDF();
}

// PDF用のページネーション情報を更新
function updatePaginationForPDF() {
    const paginationContainer = document.getElementById('pagination');
    if (paginationContainer) {
        paginationContainer.innerHTML = `
            <div class="pdf-only" style="text-align: center; padding: 5mm; font-size: 9pt; color: #666;">
                全${filteredData.length}件のデータを表示
            </div>
        `;
    }
}

// 元の状態に戻す
function restoreOriginalState(originalPage, originalItemsPerPage) {
    currentPage = originalPage;
    itemsPerPage = originalItemsPerPage;
    updateDisplay();
}

// PDF用の拡張機能を削除
function removePDFEnhancements() {
    // 追加したクラスを削除
    document.querySelectorAll('.long-content').forEach(cell => {
        cell.classList.remove('long-content');
    });
    
    document.querySelectorAll('.page-break').forEach(row => {
        row.classList.remove('page-break');
    });
    
    document.querySelectorAll('.no-break').forEach(row => {
        row.classList.remove('no-break');
    });
    
    // PDF専用要素を削除
    document.querySelectorAll('.pdf-only').forEach(element => {
        element.remove();
    });
}

// PDFダウンロード機能
function downloadPDF() {
    // PDF生成開始の通知
    const loadingOverlay = createLoadingOverlay();
    document.body.appendChild(loadingOverlay);
    
    try {
        console.log('=== PDFダウンロード開始 ===');
        
        // jsPDFライブラリの確認（複数のアクセス方法を試行）
        let jsPDFLib = null;
        let jsPDFConstructor = null;
        
        // 方法1: window.jsPDF
        if (typeof window.jsPDF !== 'undefined') {
            jsPDFLib = window.jsPDF;
            console.log('jsPDF found at window.jsPDF');
            
            // UMD形式の場合、jsPDFコンストラクタを取得
            if (jsPDFLib.jsPDF) {
                jsPDFConstructor = jsPDFLib.jsPDF;
                console.log('jsPDF constructor found at window.jsPDF.jsPDF');
            } else if (typeof jsPDFLib === 'function') {
                jsPDFConstructor = jsPDFLib;
                console.log('jsPDF constructor is window.jsPDF itself');
            }
        }
        // 方法2: グローバルjsPDF
        else if (typeof jsPDF !== 'undefined') {
            jsPDFConstructor = jsPDF;
            console.log('jsPDF constructor found at global jsPDF');
        }
        // 方法3: window.jspdf
        else if (typeof window.jspdf !== 'undefined') {
            jsPDFLib = window.jspdf;
            if (jsPDFLib.jsPDF) {
                jsPDFConstructor = jsPDFLib.jsPDF;
            } else if (typeof jsPDFLib === 'function') {
                jsPDFConstructor = jsPDFLib;
            }
            console.log('jsPDF found at window.jspdf');
        }
        
        if (!jsPDFConstructor) {
            console.error('利用可能なjsPDFコンストラクタが見つかりません');
            console.error('window.jsPDF:', typeof window.jsPDF);
            console.error('global jsPDF:', typeof jsPDF);
            console.error('window.jspdf:', typeof window.jspdf);
            
            showErrorMessage('jsPDFライブラリが読み込まれていません。ページを再読み込みしてください。');
            return;
        }
        
        console.log('jsPDF constructor type:', typeof jsPDFConstructor);
        
        // PDFドキュメントを作成
        const doc = new jsPDFConstructor('l', 'mm', 'a4'); // 横向き、A4サイズ
        console.log('jsPDF document created successfully');
        
        // 日本語フォントの設定
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(12);
        
        // ヘッダー情報を追加
        const reportTitle = document.querySelector('.header h1').textContent || 'レポート';
        const timestamp = new Date().toLocaleDateString('ja-JP', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        });
        
        // タイトルを追加
        doc.setFontSize(16);
        doc.text(reportTitle, 20, 20);
        
        // 生成日時を追加
        doc.setFontSize(10);
        doc.text(`生成日時: ${timestamp}`, 20, 30);
        doc.text(`データ件数: ${filteredData.length}件 / 全件数: ${originalData.length}件`, 20, 35);
        
        // テーブルデータを準備
        const tableData = prepareTableDataForPDF();
        
        if (tableData.headers.length > 0 && tableData.rows.length > 0) {
            // autoTableを使用してテーブルを生成
            doc.autoTable({
                head: [tableData.headers],
                body: tableData.rows,
                startY: 45,
                margin: { top: 45, right: 20, bottom: 20, left: 20 },
                styles: {
                    fontSize: 8,
                    cellPadding: 2,
                    lineColor: [200, 200, 200],
                    lineWidth: 0.1,
                    font: 'helvetica'
                },
                headStyles: {
                    fillColor: [0, 120, 212],
                    textColor: [255, 255, 255],
                    fontSize: 9,
                    fontStyle: 'bold',
                    halign: 'center'
                },
                bodyStyles: {
                    textColor: [0, 0, 0],
                    fontSize: 8
                },
                alternateRowStyles: {
                    fillColor: [248, 249, 250]
                },
                columnStyles: generateColumnStyles(tableData.headers.length),
                didDrawPage: function (data) {
                    // フッターを追加
                    const pageCount = doc.internal.getNumberOfPages();
                    const pageSize = doc.internal.pageSize;
                    const pageHeight = pageSize.height ? pageSize.height : pageSize.getHeight();
                    
                    doc.setFontSize(8);
                    doc.text(
                        `ページ ${data.pageNumber} / ${pageCount}`,
                        pageSize.width - 40,
                        pageHeight - 10
                    );
                    
                    doc.text(
                        'Microsoft 365統合管理ツール',
                        20,
                        pageHeight - 10
                    );
                }
            });
        } else {
            // データがない場合
            doc.text('表示するデータがありません。', 20, 50);
        }
        
        // PDFをダウンロード
        const fileName = `${reportTitle.replace(/[^\w\s-]/g, '')}_${timestamp.replace(/[^\w\s-]/g, '')}.pdf`;
        doc.save(fileName);
        
        // 成功メッセージ
        showSuccessMessage('PDFファイルがダウンロードされました。');
        
    } catch (error) {
        console.error('PDFダウンロードエラー:', error);
        showErrorMessage('PDFダウンロード中にエラーが発生しました: ' + error.message);
    } finally {
        // ローディングオーバーレイを削除
        document.body.removeChild(loadingOverlay);
    }
}

// テーブルデータをPDF用に準備
function prepareTableDataForPDF() {
    const table = document.getElementById('dataTable');
    const headers = [];
    const rows = [];
    
    if (!table) {
        return { headers: [], rows: [] };
    }
    
    // ヘッダーを取得
    const headerCells = table.querySelectorAll('th');
    headerCells.forEach(cell => {
        let headerText = cell.textContent.trim();
        // アイコンを除去
        headerText = headerText.replace(/\s*\uf0dc\s*/g, '').trim();
        headers.push(headerText);
    });
    
    // フィルタ済みデータの行を取得
    filteredData.forEach(item => {
        const row = [];
        headers.forEach((header, index) => {
            let cellValue = item.data[header] || '';
            
            // HTMLタグを除去
            cellValue = cellValue.replace(/<[^>]*>/g, '');
            
            // 長すぎるテキストは切り詰める
            if (cellValue.length > 50) {
                cellValue = cellValue.substring(0, 47) + '...';
            }
            
            row.push(cellValue);
        });
        rows.push(row);
    });
    
    return { headers: headers, rows: rows };
}

// 列スタイルを生成
function generateColumnStyles(columnCount) {
    const styles = {};
    const maxWidth = 270; // A4横向きの利用可能幅
    const columnWidth = maxWidth / columnCount;
    
    for (let i = 0; i < columnCount; i++) {
        styles[i] = {
            cellWidth: Math.max(15, columnWidth), // 最小幅15mm
            overflow: 'linebreak',
            fontSize: 7
        };
    }
    
    return styles;
}

// 成功メッセージを表示
function showSuccessMessage(message) {
    const messageDiv = document.createElement('div');
    messageDiv.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: #d4edda;
        color: #155724;
        padding: 15px 20px;
        border-radius: 5px;
        border: 1px solid #c3e6cb;
        z-index: 10000;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    `;
    messageDiv.innerHTML = `
        <i class="fas fa-check-circle" style="margin-right: 10px;"></i>
        ${message}
    `;
    
    document.body.appendChild(messageDiv);
    
    setTimeout(() => {
        if (messageDiv.parentNode) {
            messageDiv.parentNode.removeChild(messageDiv);
        }
    }, 5000);
}

// エラーメッセージを表示
function showErrorMessage(message) {
    const messageDiv = document.createElement('div');
    messageDiv.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: #f8d7da;
        color: #721c24;
        padding: 15px 20px;
        border-radius: 5px;
        border: 1px solid #f5c6cb;
        z-index: 10000;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    `;
    messageDiv.innerHTML = `
        <i class="fas fa-exclamation-triangle" style="margin-right: 10px;"></i>
        ${message}
    `;
    
    document.body.appendChild(messageDiv);
    
    setTimeout(() => {
        if (messageDiv.parentNode) {
            messageDiv.parentNode.removeChild(messageDiv);
        }
    }, 8000);
}

// HTML2Canvas を使用したPDF生成（フォールバック）
function downloadPDFWithCanvas() {
    const loadingOverlay = createLoadingOverlay();
    document.body.appendChild(loadingOverlay);
    
    try {
        // 現在の状態を保存
        const originalPage = currentPage;
        const originalItemsPerPage = itemsPerPage;
        
        // 全データを表示
        currentPage = 1;
        itemsPerPage = filteredData.length;
        updateDisplay();
        
        // 不要な要素を一時的に非表示
        const elementsToHide = document.querySelectorAll('.filter-section, .pagination, .btn');
        elementsToHide.forEach(el => el.style.display = 'none');
        
        // html2canvasでキャプチャ
        html2canvas(document.body, {
            scale: 2,
            useCORS: true,
            allowTaint: true,
            scrollX: 0,
            scrollY: 0,
            width: document.body.scrollWidth,
            height: document.body.scrollHeight
        }).then(canvas => {
            const { jsPDF } = window.jsPDF;
            const doc = new jsPDF('l', 'mm', 'a4');
            
            const imgData = canvas.toDataURL('image/png');
            const imgWidth = 297; // A4横向きの幅
            const pageHeight = 210; // A4横向きの高さ
            const imgHeight = (canvas.height * imgWidth) / canvas.width;
            let heightLeft = imgHeight;
            
            let position = 0;
            
            doc.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
            heightLeft -= pageHeight;
            
            while (heightLeft >= 0) {
                position = heightLeft - imgHeight;
                doc.addPage();
                doc.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
                heightLeft -= pageHeight;
            }
            
            const fileName = `report_${new Date().toISOString().slice(0, 10)}.pdf`;
            doc.save(fileName);
            
            showSuccessMessage('PDFファイルがダウンロードされました。');
            
            // 元の状態に戻す
            elementsToHide.forEach(el => el.style.display = '');
            currentPage = originalPage;
            itemsPerPage = originalItemsPerPage;
            updateDisplay();
            
        }).catch(error => {
            console.error('Canvas PDF生成エラー:', error);
            showErrorMessage('PDF生成中にエラーが発生しました。');
        }).finally(() => {
            document.body.removeChild(loadingOverlay);
        });
        
    } catch (error) {
        console.error('Canvas PDF生成エラー:', error);
        showErrorMessage('PDF生成中にエラーが発生しました。');
        document.body.removeChild(loadingOverlay);
    }
}

// CSVエクスポート（バックアップ用）
function exportToCSV() {
    const headers = Array.from(document.querySelectorAll('th')).map(th => 
        th.textContent.replace(' ', '').trim()
    );
    
    let csv = headers.join(',') + '\n';
    
    filteredData.forEach(item => {
        const row = headers.map(header => {
            const value = item.data[header] || '';
            // CSVエスケープ
            if (value.includes(',') || value.includes('"') || value.includes('\n')) {
                return `"${value.replace(/"/g, '""')}"`;
            }
            return value;
        });
        csv += row.join(',') + '\n';
    });
    
    // ダウンロード
    const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').substring(0, 19);
    link.download = `filtered_report_${timestamp}.csv`;
    link.href = URL.createObjectURL(blob);
    link.click();
}

// 列の表示/非表示切り替え
function toggleColumns() {
    // TODO: 列選択モーダルの実装
    alert('列の表示/非表示機能は現在開発中です。');
}

// テーブルレイアウト調整
function adjustTableLayout() {
    const table = document.getElementById('dataTable');
    const container = document.querySelector('.table-wrapper');
    
    if (table.offsetWidth > container.offsetWidth) {
        table.style.fontSize = '0.9rem';
    } else {
        table.style.fontSize = '';
    }
}

// デバウンス関数
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}