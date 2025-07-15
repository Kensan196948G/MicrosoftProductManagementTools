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
    
    if (!table) {
        console.warn('dataTable要素が見つかりません');
        return;
    }
    
    const tbody = table.querySelector('tbody');
    if (!tbody) {
        console.warn('tbody要素が見つかりません');
        return;
    }
    
    const rows = tbody.querySelectorAll('tr');
    if (!rows || rows.length === 0) {
        console.warn('テーブル行が見つかりません');
        return;
    }
    
    const headers = table.querySelectorAll('th');
    if (!headers || headers.length === 0) {
        console.warn('テーブルヘッダーが見つかりません');
        return;
    }
    
    originalData = Array.from(rows).map(row => {
        const cells = row.querySelectorAll('td');
        const data = {};
        
        headers.forEach((header, index) => {
            const columnName = header.textContent.trim();
            data[columnName] = cells[index] ? cells[index].textContent.trim() : '';
        });
        
        return { element: row, data: data };
    });
    
    filteredData = [...originalData];
    
    // 検索サジェスト用のデータ収集
    originalData.forEach(item => {
        if (item && item.data) {
            Object.values(item.data).forEach(value => {
                if (value && value.length > 2) {
                    searchSuggestions.add(value);
                }
            });
        }
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
    
    // 必要な要素が存在しない場合は何もしない
    if (!container || !headers || headers.length === 0) {
        console.warn('フィルタードロップダウン生成に必要な要素が見つかりません');
        return;
    }
    
    // originalDataが存在しない場合は何もしない
    if (!originalData || !Array.isArray(originalData) || originalData.length === 0) {
        console.warn('originalDataが利用できません');
        return;
    }
    
    // 各カラムのユニーク値を収集
    const columnValues = {};
    headers.forEach((header, index) => {
        const columnName = header.textContent.replace(' ', '').trim();
        columnValues[columnName] = new Set();
        
        originalData.forEach(item => {
            if (item && item.data) {
                const value = item.data[columnName];
                if (value) {
                    columnValues[columnName].add(value);
                }
            }
        });
    });
    
    try {
        // コンテナをクリア
        container.innerHTML = '';
        
        // ドロップダウンを生成（値が10個以下のカラムのみ）
        Object.entries(columnValues).forEach(([columnName, values]) => {
            if (values.size > 1 && values.size <= 10) {
                const dropdown = createFilterDropdown(columnName, Array.from(values));
                if (dropdown) {
                    container.appendChild(dropdown);
                }
            }
        });
    } catch (error) {
        console.error('フィルタードロップダウンの生成に失敗しました:', error);
    }
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
    
    // tbody要素が存在しない場合は何もしない
    if (!tbody) {
        console.warn('tableBody要素が見つかりません');
        return;
    }
    
    // originalDataが存在し、有効な場合のみ処理
    if (originalData && Array.isArray(originalData)) {
        // すべての行を非表示
        originalData.forEach(item => {
            if (item && item.element && item.element.style) {
                item.element.style.display = 'none';
            }
        });
    }
    
    // filteredDataが存在し、有効な場合のみ処理
    if (filteredData && Array.isArray(filteredData)) {
        // フィルター済みデータを表示
        const startIndex = (currentPage - 1) * itemsPerPage;
        const endIndex = startIndex + itemsPerPage;
        const pageData = filteredData.slice(startIndex, endIndex);
        
        pageData.forEach(item => {
            if (item && item.element && item.element.style) {
                item.element.style.display = '';
            }
        });
        
        // 統計情報更新
        const visibleRecords = document.getElementById('visibleRecords');
        if (visibleRecords) {
            visibleRecords.textContent = filteredData.length;
        }
    }
    
    // ページネーション更新
    updatePagination();
}

// ページネーション更新
function updatePagination() {
    const totalPages = Math.ceil(filteredData.length / itemsPerPage);
    const pagination = document.getElementById('pagination');
    
    // pagination要素が存在しない場合は何もしない
    if (!pagination) {
        console.warn('pagination要素が見つかりません');
        return;
    }
    
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
        try {
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
            
            const filteredLength = (filteredData && Array.isArray(filteredData)) ? filteredData.length : 0;
            const originalLength = (originalData && Array.isArray(originalData)) ? originalData.length : 0;
            
            pdfInfo.innerHTML = `
                <div style="display: flex; justify-content: space-between; flex-wrap: wrap;">
                    <div>PDF生成日時: ${formatDate}</div>
                    <div>フィルタ済み件数: ${filteredLength}件 / 全件数: ${originalLength}件</div>
                </div>
            `;
            
            header.appendChild(pdfInfo);
        } catch (error) {
            console.warn('PDFヘッダー情報の追加に失敗しました:', error);
        }
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
        try {
            const dataLength = (filteredData && Array.isArray(filteredData)) ? filteredData.length : 0;
            paginationContainer.innerHTML = `
                <div class="pdf-only" style="text-align: center; padding: 5mm; font-size: 9pt; color: #666;">
                    全${dataLength}件のデータを表示
                </div>
            `;
        } catch (error) {
            console.warn('PDF用ページネーション情報の更新に失敗しました:', error);
        }
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
        console.log('=== html2pdf.jsを使用したPDF生成開始 ===');
        
        // html2pdf.jsの存在確認
        if (typeof html2pdf === 'undefined') {
            console.error('html2pdf.jsが読み込まれていません');
            showErrorMessage('html2pdf.jsライブラリが読み込まれていません。ページを再読み込みしてください。');
            document.body.removeChild(loadingOverlay);
            return;
        }
        
        console.log('html2pdf.js確認: OK');
        
        // PDF生成対象の要素を取得
        const element = document.body;
        
        // ヘッダー情報を取得してファイル名を作成
        let reportTitle = 'Microsoft_365_Report';
        try {
            const headerH1 = document.querySelector('.header h1');
            if (headerH1) {
                let title = headerH1.textContent || 'Microsoft_365_Report';
                // 日本語文字とアイコンを除去してファイル名に適した形式に変換
                title = title.replace(/[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]/g, ''); // 日本語文字除去
                title = title.replace(/[\uF000-\uF8FF]/g, ''); // アイコン除去
                title = title.replace(/[^a-zA-Z0-9_\s]/g, ''); // 特殊文字除去
                title = title.trim().replace(/\s+/g, '_'); // スペースをアンダースコアに
                if (title) {
                    reportTitle = title;
                }
            }
        } catch (titleError) {
            console.warn('ヘッダーからタイトルを取得できませんでした:', titleError);
        }
        
        // 現在の日時を取得してファイル名に追加
        const now = new Date();
        const timestamp = now.toISOString().slice(0, 19).replace(/[T:-]/g, '_');
        const fileName = `${reportTitle}_${timestamp}.pdf`;
        
        console.log('生成するファイル名:', fileName);
        
        // html2pdf.jsのオプション設定（日本語フォント対応）
        const options = {
            margin: [10, 10, 10, 10],
            filename: fileName,
            image: { 
                type: 'jpeg', 
                quality: 0.98 
            },
            html2canvas: { 
                scale: 2, // 高解像度でフォントを鮮明に
                useCORS: true,
                letterRendering: true,
                allowTaint: true,
                backgroundColor: '#ffffff',
                scrollX: 0,
                scrollY: 0,
                width: window.innerWidth,
                height: window.innerHeight,
                // 日本語フォントレンダリングの改善
                foreignObjectRendering: true,
                imageTimeout: 15000,
                logging: true
            },
            jsPDF: { 
                unit: 'mm', 
                format: 'a4', 
                orientation: 'portrait',
                compress: true,
                // 日本語フォントサポートのための設定
                putOnlyUsedFonts: true,
                floatPrecision: 16
            }
        };
        
        console.log('html2pdf.js設定完了:', options);
        
        // 日本語フォントの事前読み込みを確認
        const fontCheckPromise = new Promise((resolve) => {
            // Noto Sans JPフォントの読み込みを確認
            if (document.fonts && document.fonts.ready) {
                document.fonts.ready.then(() => {
                    console.log('フォント読み込み完了');
                    resolve();
                });
            } else {
                // フォールバック: 短い遅延でフォントの読み込みを待つ
                setTimeout(() => {
                    console.log('フォント読み込み待機完了 (fallback)');
                    resolve();
                }, 1000);
            }
        });
        
        // フォント読み込み後にPDF生成を開始
        fontCheckPromise.then(() => {
            console.log('PDF生成開始（日本語フォント対応）');
            
            // PDF生成とダウンロード
            html2pdf()
                .from(element)
                .set(options)
                .save()
                .then(() => {
                    console.log('PDF生成完了:', fileName);
                    document.body.removeChild(loadingOverlay);
                    showSuccessMessage(`PDFファイル「${fileName}」のダウンロードが完了しました。\n日本語フォント対応で生成されました。`);
                })
                .catch((error) => {
                    console.error('html2pdf.jsエラー:', error);
                    document.body.removeChild(loadingOverlay);
                    showErrorMessage('PDF生成中にエラーが発生しました: ' + error.message);
                });
        });
            
        console.log('html2pdf.js処理開始完了');
        
    } catch (error) {
        console.error('PDF生成エラー:', error);
        if (loadingOverlay && loadingOverlay.parentNode) {
            document.body.removeChild(loadingOverlay);
        }
        showErrorMessage('PDF生成中にエラーが発生しました: ' + error.message);
    }
}

// 旧バージョンのdownloadPDFWithCanvas関数（バックアップ用）
function downloadPDFWithCanvas() {
    // PDF生成開始の通知
    const loadingOverlay = createLoadingOverlay();
    document.body.appendChild(loadingOverlay);
    
    try {
        console.log('=== Canvas方式PDFダウンロード開始 ===');
        
        // 変数の存在確認
        console.log('変数の存在確認:');
        console.log('  typeof originalData:', typeof originalData);
        console.log('  typeof filteredData:', typeof filteredData);
        console.log('  typeof currentPage:', typeof currentPage);
        console.log('  typeof itemsPerPage:', typeof itemsPerPage);
        
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
        
        // ヘッダー情報を取得
        let reportTitle = 'Microsoft 365 Report';
        try {
            const headerH1 = document.querySelector('.header h1');
            if (headerH1) {
                reportTitle = headerH1.textContent || 'Microsoft 365 Report';
            }
        } catch (titleError) {
            console.warn('ヘッダーからタイトルを取得できませんでした:', titleError);
        }
        
        // 日本語文字とアイコンを除去してクリーンなタイトルを作成
        reportTitle = reportTitle.replace(/[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]/g, ''); // 日本語文字除去
        reportTitle = reportTitle.replace(/[\uF000-\uF8FF]/g, ''); // アイコン除去
        reportTitle = reportTitle.trim();
        
        // 空の場合はデフォルトタイトルを設定
        if (!reportTitle) {
            reportTitle = 'Microsoft 365 Report';
        }
        
        // 現在の日時を取得（英語形式）
        const now = new Date();
        const timestamp = now.toLocaleDateString('en-US', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            hour12: false
        });
        
        // 日本語フォントの代替対応のため、HTML2Canvasを使用してフォールバックを実行
        // jsPDFは日本語フォントをサポートしていないため、HTML2Canvasを使用
        console.log('日本語対応のため、HTML2Canvasを使用してPDF生成を開始します');
        
        // HTML2Canvasを使用してフォールバックの英語PDFを生成
        downloadPDFWithCanvas();
        
        // PDF終了処理
        if (loadingOverlay && loadingOverlay.parentNode) {
            document.body.removeChild(loadingOverlay);
        }
        
        return;
        
    } catch (error) {
        console.error('PDFダウンロードエラー:', error);
        console.error('エラーの詳細:', error.message);
        console.error('エラーのスタック:', error.stack);
        console.error('エラーが発生した時点での状態:');
        console.error('  typeof originalData:', typeof originalData);
        console.error('  typeof filteredData:', typeof filteredData);
        console.error('  typeof window.jsPDF:', typeof window.jsPDF);
        console.error('  typeof html2canvas:', typeof html2canvas);
        
        // エラーメッセージをユーザーに表示
        let errorMessage = 'PDFダウンロード中にエラーが発生しました。';
        if (error.message) {
            errorMessage += ' 詳細: ' + error.message;
        }
        showErrorMessage(errorMessage);
    } finally {
        // ローディングオーバーレイを削除
        try {
            if (loadingOverlay && loadingOverlay.parentNode) {
                document.body.removeChild(loadingOverlay);
            }
        } catch (removeError) {
            console.warn('ローディングオーバーレイの削除に失敗しました:', removeError);
        }
    }
}

// テーブルデータをPDF用に準備
function prepareTableDataForPDF() {
    console.log('=== PDF用データ準備開始 ===');
    const table = document.getElementById('dataTable');
    const headers = [];
    const rows = [];
    
    if (!table) {
        console.error('テーブルが見つかりません');
        return { headers: [], rows: [] };
    }
    
    console.log('テーブルが見つかりました:', table);
    
    // ヘッダーを取得して英語に変換
    const headerCells = table.querySelectorAll('th');
    console.log('ヘッダーセル数:', headerCells.length);
    
    headerCells.forEach((cell, index) => {
        let headerText = cell.textContent.trim();
        console.log(`ヘッダー${index + 1} 元テキスト:`, headerText);
        
        // アイコンとUnicodeシンボルを除去
        headerText = headerText.replace(/[\uF000-\uF8FF]/g, ''); // プライベート領域
        headerText = headerText.replace(/[\u2000-\u206F]/g, ''); // 一般句読点
        headerText = headerText.replace(/[\u2700-\u27BF]/g, ''); // 装飾記号
        headerText = headerText.replace(/[\uE000-\uF8FF]/g, ''); // プライベート使用領域
        headerText = headerText.replace(/\s*\uf0dc\s*/g, '').trim();
        
        console.log(`ヘッダー${index + 1} クリーン後:`, headerText);
        
        // 日本語を英語に変換（フォールバック用）
        const headerTranslations = {
            '日付': 'Date',
            'ユーザー名': 'User_Name',
            '部署': 'Department',
            'ログイン失敗数': 'Failed_Logins',
            '総ログイン数': 'Total_Logins',
            'ストレージ使用率': 'Storage_Usage',
            'メールボックス数': 'Mailbox_Count',
            'OneDrive使用率': 'OneDrive_Usage',
            'Teamsアクティブユーザー': 'Teams_Active_Users',
            'ステータス': 'Status',
            'MFA有効': 'MFA_Enabled',
            'ライセンス': 'License',
            'メールアドレス': 'Email_Address',
            'アカウント状態': 'Account_Status'
        };
        
        let englishHeader = headerTranslations[headerText] || headerText;
        englishHeader = englishHeader.replace(/[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]/g, '');
        
        // 空の場合はデフォルト値を設定
        if (!englishHeader.trim()) {
            englishHeader = `Column_${headers.length + 1}`;
        }
        
        console.log(`ヘッダー${index + 1} 最終結果:`, englishHeader);
        headers.push(englishHeader);
    });
    
    console.log('=== データ行処理開始 ===');
    console.log('filteredData:', filteredData);
    console.log('filteredData の長さ:', filteredData.length);
    
    // データが存在しない場合は直接テーブルから読み取る
    if (!filteredData || filteredData.length === 0) {
        console.log('filteredData が空です。テーブルから直接読み取ります。');
        const tbody = table.querySelector('tbody');
        if (tbody) {
            const dataRows = tbody.querySelectorAll('tr');
            console.log('テーブル行数:', dataRows.length);
            
            // 非表示の行もすべて処理対象にする
            const visibleRows = Array.from(dataRows).filter(row => row.style.display !== 'none');
            console.log('表示中の行数:', visibleRows.length);
            
            // 実際に処理する行を決定
            const rowsToProcess = visibleRows.length > 0 ? visibleRows : dataRows;
            console.log('処理する行数:', rowsToProcess.length);
            
            rowsToProcess.forEach((row, rowIndex) => {
                const cells = row.querySelectorAll('td');
                const rowData = [];
                
                cells.forEach((cell, cellIndex) => {
                    let cellValue = cell.textContent.trim();
                    console.log(`行${rowIndex + 1} セル${cellIndex + 1} 元の値:`, cellValue);
                    
                    // HTMLタグを除去
                    cellValue = cellValue.replace(/<[^>]*>/g, '');
                    
                    // 改行文字を空白に置換
                    cellValue = cellValue.replace(/\n/g, ' ');
                    
                    // 日本語文字を英語に変換
                    const nameTranslations = {
                        '田中太郎': 'Taro Tanaka',
                        '鈴木花子': 'Hanako Suzuki',
                        '佐藤次郎': 'Jiro Sato',
                        '高橋美咲': 'Misaki Takahashi',
                        '渡辺健一': 'Kenichi Watanabe',
                        '伊藤光子': 'Mitsuko Ito',
                        '山田和也': 'Kazuya Yamada',
                        '中村真理': 'Mari Nakamura',
                        '小林秀樹': 'Hideki Kobayashi',
                        '加藤明美': 'Akemi Kato'
                    };
                    
                    const departmentTranslations = {
                        '営業部': 'Sales',
                        '開発部': 'Development',
                        '総務部': 'General Affairs',
                        '人事部': 'Human Resources',
                        '経理部': 'Accounting',
                        'マーケティング部': 'Marketing',
                        'システム部': 'IT Systems'
                    };
                    
                    const statusTranslations = {
                        '正常': 'Normal',
                        '警告': 'Warning',
                        '注意': 'Caution',
                        '危険': 'Critical',
                        'エラー': 'Error',
                        '有効': 'Enabled',
                        '無効': 'Disabled'
                    };
                    
                    // 各種変換を適用
                    if (nameTranslations[cellValue]) {
                        cellValue = nameTranslations[cellValue];
                    } else if (departmentTranslations[cellValue]) {
                        cellValue = departmentTranslations[cellValue];
                    } else if (statusTranslations[cellValue]) {
                        cellValue = statusTranslations[cellValue];
                    } else {
                        // 残った日本語文字を除去
                        cellValue = cellValue.replace(/[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]/g, '');
                    }
                    
                    console.log(`行${rowIndex + 1} セル${cellIndex + 1} 変換後:`, cellValue);
                    
                    // 長すぎるテキストは切り詰める（制限を厳格化）
                    if (cellValue.length > 30) {
                        cellValue = cellValue.substring(0, 27) + '...';
                        console.log(`長いテキストを切り詰めました: "${cellValue}"`);
                    }
                    
                    console.log(`行${rowIndex + 1} セル${cellIndex + 1} 最終値:`, cellValue);
                    rowData.push(cellValue);
                });
                
                rows.push(rowData);
                console.log(`行${rowIndex + 1} 完了:`, rowData);
            });
        }
    } else {
        // フィルタ済みデータの行を取得
        filteredData.forEach((item, itemIndex) => {
            const row = [];
            
            // 元のヘッダー名（日本語）を使用してデータを取得
            const originalHeaders = [];
            const headerCells = table.querySelectorAll('th');
            headerCells.forEach(cell => {
                let headerText = cell.textContent.trim();
                headerText = headerText.replace(/\s*\uf0dc\s*/g, '').trim();
                originalHeaders.push(headerText);
            });
            
            console.log(`データ項目${itemIndex + 1}:`, item);
            
            originalHeaders.forEach((originalHeader, index) => {
                let cellValue = item.data[originalHeader] || '';
                console.log(`データ項目${itemIndex + 1} フィールド${originalHeader}:`, cellValue);
                
                // HTMLタグを除去
                cellValue = cellValue.replace(/<[^>]*>/g, '');
                
                // 改行文字を空白に置換
                cellValue = cellValue.replace(/\n/g, ' ');
                
                // 日本語文字を英語に変換
                const nameTranslations = {
                    '田中太郎': 'Taro Tanaka',
                    '鈴木花子': 'Hanako Suzuki',
                    '佐藤次郎': 'Jiro Sato',
                    '高橋美咲': 'Misaki Takahashi',
                    '渡辺健一': 'Kenichi Watanabe',
                    '伊藤光子': 'Mitsuko Ito',
                    '山田和也': 'Kazuya Yamada',
                    '中村真理': 'Mari Nakamura',
                    '小林秀樹': 'Hideki Kobayashi',
                    '加藤明美': 'Akemi Kato'
                };
                
                const departmentTranslations = {
                    '営業部': 'Sales',
                    '開発部': 'Development',
                    '総務部': 'General Affairs',
                    '人事部': 'Human Resources',
                    '経理部': 'Accounting',
                    'マーケティング部': 'Marketing',
                    'システム部': 'IT Systems'
                };
                
                const statusTranslations = {
                    '正常': 'Normal',
                    '警告': 'Warning',
                    '注意': 'Caution',
                    '危険': 'Critical',
                    'エラー': 'Error',
                    '有効': 'Enabled',
                    '無効': 'Disabled'
                };
                
                // 各種変換を適用
                if (nameTranslations[cellValue]) {
                    cellValue = nameTranslations[cellValue];
                } else if (departmentTranslations[cellValue]) {
                    cellValue = departmentTranslations[cellValue];
                } else if (statusTranslations[cellValue]) {
                    cellValue = statusTranslations[cellValue];
                } else {
                    // 残った日本語文字を除去
                    cellValue = cellValue.replace(/[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]/g, '');
                }
                
                console.log(`データ項目${itemIndex + 1} 変換後:`, cellValue);
                
                // 長すぎるテキストは切り詰める（制限を厳格化）
                if (cellValue.length > 30) {
                    cellValue = cellValue.substring(0, 27) + '...';
                    console.log(`長いテキストを切り詰めました: "${cellValue}"`);
                }
                
                console.log(`データ項目${itemIndex + 1} 最終値:`, cellValue);
                row.push(cellValue);
            });
            rows.push(row);
        });
    }
    
    console.log('=== PDF用データ準備完了 ===');
    console.log('最終ヘッダー:', headers);
    console.log('最終データ行数:', rows.length);
    console.log('最終データ:', rows);
    
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
    try {
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
            ${message || 'Success'}
        `;
        
        document.body.appendChild(messageDiv);
        
        setTimeout(() => {
            try {
                if (messageDiv.parentNode) {
                    messageDiv.parentNode.removeChild(messageDiv);
                }
            } catch (removeError) {
                console.warn('成功メッセージの削除に失敗しました:', removeError);
            }
        }, 5000);
    } catch (error) {
        console.error('成功メッセージの表示に失敗しました:', error);
    }
}

// エラーメッセージを表示
function showErrorMessage(message) {
    try {
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
            ${message || 'Error occurred'}
        `;
        
        document.body.appendChild(messageDiv);
        
        setTimeout(() => {
            try {
                if (messageDiv.parentNode) {
                    messageDiv.parentNode.removeChild(messageDiv);
                }
            } catch (removeError) {
                console.warn('エラーメッセージの削除に失敗しました:', removeError);
            }
        }, 8000);
    } catch (error) {
        console.error('エラーメッセージの表示に失敗しました:', error);
        // フォールバック: アラート表示
        alert(message || 'Error occurred');
    }
}

// HTML2Canvas を使用したPDF生成（日本語対応）
function generatePDFWithHTML2Canvas(reportTitle, timestamp, loadingOverlay) {
    console.log('HTML2Canvas による日本語対応PDF生成を開始します');
    
    try {
        // 現在の状態を保存
        const originalPage = currentPage;
        const originalItemsPerPage = itemsPerPage;
        
        // 全データを表示
        if (typeof currentPage !== 'undefined' && typeof itemsPerPage !== 'undefined') {
            currentPage = 1;
            if (typeof filteredData !== 'undefined' && filteredData.length > 0) {
                itemsPerPage = filteredData.length;
            } else {
                itemsPerPage = 1000; // デフォルト値
            }
            if (typeof updateDisplay === 'function') {
                updateDisplay();
            }
        }
        
        // 不要な要素を一時的に非表示
        const elementsToHide = document.querySelectorAll('.filter-section, .pagination, .btn, .controls');
        elementsToHide.forEach(el => el.style.display = 'none');
        
        // 大きなデータテーブルを制限する
        const tbody = document.querySelector('tbody');
        const allRows = tbody ? tbody.querySelectorAll('tr') : [];
        const maxRows = 100; // 最大100行まで
        
        if (allRows.length > maxRows) {
            console.log(`行数が多すぎます (${allRows.length}行)。${maxRows}行に制限します。`);
            for (let i = maxRows; i < allRows.length; i++) {
                allRows[i].style.display = 'none';
            }
        }
        
        // PDFスタイルを適用
        document.body.style.backgroundColor = 'white';
        document.body.style.padding = '20px';
        
        // html2canvasの存在確認
        if (typeof html2canvas === 'undefined') {
            throw new Error('html2canvas ライブラリが読み込まれていません');
        }
        
        console.log('html2canvas でキャプチャ開始');
        
        // html2canvasでキャプチャ（制限値を追加）
        const maxWidth = 4096;  // 最大幅制限
        const maxHeight = 4096; // 最大高さ制限
        const actualWidth = Math.min(document.body.scrollWidth, maxWidth);
        const actualHeight = Math.min(document.body.scrollHeight, maxHeight);
        
        console.log('Canvas設定:');
        console.log('  元のサイズ:', document.body.scrollWidth, 'x', document.body.scrollHeight);
        console.log('  実際のサイズ:', actualWidth, 'x', actualHeight);
        
        html2canvas(document.body, {
            scale: 1, // スケールを1に変更して負荷を軽減
            useCORS: true,
            allowTaint: true,
            scrollX: 0,
            scrollY: 0,
            width: actualWidth,
            height: actualHeight,
            backgroundColor: '#ffffff',
            logging: true, // デバッグ用ログ有効化
            onrendered: function(canvas) {
                console.log('html2canvas レンダリング完了');
            }
        }).then(canvas => {
            console.log('Canvas生成完了');
            console.log('Canvas サイズ:', canvas.width, 'x', canvas.height);
            
            // キャンバスの有効性を確認
            if (!canvas || canvas.width === 0 || canvas.height === 0) {
                throw new Error('キャンバスが無効です。サイズ: ' + canvas.width + 'x' + canvas.height);
            }
            
            // キャンバスのデータを確認
            const ctx = canvas.getContext('2d');
            const imageData = ctx.getImageData(0, 0, Math.min(canvas.width, 10), Math.min(canvas.height, 10));
            let hasContent = false;
            for (let i = 0; i < imageData.data.length; i += 4) {
                if (imageData.data[i] !== 255 || imageData.data[i + 1] !== 255 || imageData.data[i + 2] !== 255) {
                    hasContent = true;
                    break;
                }
            }
            
            if (!hasContent) {
                console.warn('キャンバスが空白です。コンテンツを確認してください。');
            }
            
            // jsPDFコンストラクタを取得
            let jsPDFConstructor = null;
            if (typeof window.jsPDF !== 'undefined') {
                if (window.jsPDF.jsPDF) {
                    jsPDFConstructor = window.jsPDF.jsPDF;
                } else if (typeof window.jsPDF === 'function') {
                    jsPDFConstructor = window.jsPDF;
                }
            }
            
            if (!jsPDFConstructor) {
                throw new Error('jsPDFが利用できません');
            }
            
            const doc = new jsPDFConstructor('l', 'mm', 'a4');
            
            // PDFドキュメントの有効性を確認
            if (!doc || typeof doc.save !== 'function') {
                throw new Error('PDFドキュメントの作成に失敗しました');
            }
            
            // PDFに基本情報を追加
            doc.setProperties({
                title: reportTitle || 'Microsoft 365 Report',
                subject: 'Automated Report',
                author: 'Microsoft 365 Management Tool',
                creator: 'html2canvas + jsPDF'
            });
            
            // 画像データのサイズチェック
            console.log('Canvas実際のサイズ:', canvas.width, 'x', canvas.height);
            
            // 画像データを生成（品質を調整）
            let imgData;
            try {
                // JPEGで品質を下げてサイズを削減
                imgData = canvas.toDataURL('image/jpeg', 0.8);
                console.log('画像データ生成完了 (JPEG, 品質: 0.8)');
                console.log('画像データサイズ:', imgData.length, 'characters');
                
                // 画像データが大きすぎる場合はさらに品質を下げる
                if (imgData.length > 10000000) { // 10MB以上の場合
                    console.log('画像データが大きすぎるため、品質を下げます');
                    imgData = canvas.toDataURL('image/jpeg', 0.5);
                    console.log('再生成後の画像データサイズ:', imgData.length, 'characters');
                }
                
                // それでも大きすぎる場合は最低品質に
                if (imgData.length > 20000000) { // 20MB以上の場合
                    console.log('画像データが非常に大きいため、最低品質に設定します');
                    imgData = canvas.toDataURL('image/jpeg', 0.3);
                    console.log('最終画像データサイズ:', imgData.length, 'characters');
                }
            } catch (error) {
                console.error('画像データ生成エラー:', error);
                throw new Error('画像データ生成中にエラーが発生しました: ' + error.message);
            }
            
            const imgWidth = 297; // A4横向きの幅
            const pageHeight = 210; // A4横向きの高さ
            const imgHeight = (canvas.height * imgWidth) / canvas.width;
            let heightLeft = imgHeight;
            
            console.log('PDF にキャンバス画像を追加中...');
            console.log('  画像サイズ:', imgWidth, 'x', imgHeight);
            
            let position = 0;
            
            try {
                // PDFにヘッダーテキストを追加
                doc.setFontSize(16);
                doc.text(reportTitle || 'Microsoft 365 Report', 20, 30);
                doc.setFontSize(12);
                doc.text('Generated: ' + new Date().toLocaleString(), 20, 45);
                
                // 画像を追加
                doc.addImage(imgData, 'JPEG', 0, position + 50, imgWidth, imgHeight);
                console.log('最初のページに画像追加完了');
                heightLeft -= pageHeight;
                
                // 複数ページの場合
                let pageCount = 1;
                while (heightLeft >= 0 && pageCount < 10) { // 最大10ページまで制限
                    position = heightLeft - imgHeight;
                    doc.addPage();
                    doc.addImage(imgData, 'JPEG', 0, position, imgWidth, imgHeight);
                    heightLeft -= pageHeight;
                    pageCount++;
                    console.log(`ページ ${pageCount} に画像追加完了`);
                }
                
                if (pageCount >= 10) {
                    console.warn('ページ数が制限に達しました (最大10ページ)');
                }
                
                // PDFのページ数を確認
                const pageCount2 = doc.internal.getNumberOfPages();
                console.log('PDFページ数:', pageCount2);
                
                if (pageCount2 === 0) {
                    console.warn('PDFにページがありません。デフォルトページを追加します。');
                    doc.addPage();
                    doc.text('No content available', 20, 20);
                }
                
            } catch (addImageError) {
                console.error('画像追加エラー:', addImageError);
                // 画像追加に失敗した場合、テキストのみのPDFを作成
                console.log('画像追加に失敗しました。テキストのみのPDFを作成します。');
                doc.setFontSize(16);
                doc.text(reportTitle || 'Microsoft 365 Report', 20, 30);
                doc.setFontSize(12);
                doc.text('Generated: ' + new Date().toLocaleString(), 20, 45);
                doc.text('Error: Could not generate image content', 20, 60);
                doc.text('Please try again or contact support', 20, 75);
            }
            
            // ファイル名を生成
            const now = new Date();
            const cleanTimestamp = now.toISOString().slice(0, 19).replace(/[T:-]/g, '_');
            const cleanTitle = reportTitle.replace(/[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]/g, '').replace(/[^\w\s]/g, '').replace(/\s+/g, '_');
            const fileName = cleanTitle ? `${cleanTitle}_${cleanTimestamp}.pdf` : `Report_${cleanTimestamp}.pdf`;
            
            // PDFの内容を検証
            try {
                const pdfOutput = doc.output('arraybuffer');
                console.log('PDFサイズ:', pdfOutput.byteLength, 'bytes');
                
                if (pdfOutput.byteLength < 1000) {
                    console.warn('PDFサイズが小さすぎます。内容が正しく生成されていない可能性があります。');
                    // 最小限のコンテンツを追加
                    doc.setFontSize(14);
                    doc.text('PDF generation completed with minimal content', 20, 90);
                    doc.text('Canvas size: ' + canvas.width + 'x' + canvas.height, 20, 105);
                    doc.text('Image data size: ' + imgData.length + ' chars', 20, 120);
                }
                
                console.log('PDF保存:', fileName);
                doc.save(fileName);
                
                showSuccessMessage('PDFファイルがダウンロードされました。ファイルサイズ: ' + Math.round(pdfOutput.byteLength / 1024) + 'KB');
                
            } catch (saveError) {
                console.error('PDF保存エラー:', saveError);
                throw new Error('PDF保存中にエラーが発生しました: ' + saveError.message);
            }
            
            // 元の状態に戻す
            elementsToHide.forEach(el => el.style.display = '');
            document.body.style.backgroundColor = '';
            document.body.style.padding = '';
            
            if (typeof originalPage !== 'undefined' && typeof originalItemsPerPage !== 'undefined') {
                currentPage = originalPage;
                itemsPerPage = originalItemsPerPage;
                if (typeof updateDisplay === 'function') {
                    updateDisplay();
                }
            }
            
        }).catch(error => {
            console.error('Canvas PDF生成エラー:', error);
            console.error('エラーの詳細:', error.message);
            console.error('エラーのスタック:', error.stack);
            showErrorMessage('PDF生成中にエラーが発生しました: ' + error.message);
        }).finally(() => {
            if (loadingOverlay && loadingOverlay.parentNode) {
                document.body.removeChild(loadingOverlay);
            }
        });
        
    } catch (error) {
        console.error('Canvas PDF生成エラー:', error);
        console.error('エラーの詳細:', error.message);
        console.error('エラーのスタック:', error.stack);
        showErrorMessage('PDF生成中にエラーが発生しました: ' + error.message);
        if (loadingOverlay && loadingOverlay.parentNode) {
            document.body.removeChild(loadingOverlay);
        }
    }
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