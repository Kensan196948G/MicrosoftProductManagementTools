#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CSVファイルから完全なユーザー一覧HTMLテーブルを生成するPythonスクリプト
"""

import csv
import os
import sys
from datetime import datetime

def main():
    if len(sys.argv) != 3:
        print("使用方法: python generate_complete_user_table.py <CSV_PATH> <OUTPUT_HTML_PATH>")
        sys.exit(1)
    
    csv_path = sys.argv[1]
    output_html_path = sys.argv[2]
    
    try:
        print(f"CSVファイルからユーザーデータを読み込み中: {csv_path}")
        
        # CSVファイルを読み込み
        user_data = []
        with open(csv_path, 'r', encoding='utf-8-sig') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                user_data.append(row)
        
        print(f"読み込み完了: {len(user_data)}ユーザー")
        
        # ライセンス別にカウント
        total_e3 = len([u for u in user_data if u['AssignedLicenses'] == 'Microsoft 365 E3'])
        total_exchange = len([u for u in user_data if u['AssignedLicenses'] == 'Exchange Online Plan 2'])
        total_basic = len([u for u in user_data if 'Business Basic' in u['AssignedLicenses']])
        
        # 総コスト計算
        total_cost = sum(int(u['TotalMonthlyCost']) for u in user_data)
        avg_cost = total_cost // len(user_data) if user_data else 0
        
        # HTMLコンテンツを生成
        html_content = f"""<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft 365ライセンス割り当てユーザー完全一覧表</title>
    <style>
        * {{ box-sizing: border-box; }}
        body {{ 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; padding: 20px;
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }}
        .header {{ 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }}
        .header h1 {{ margin: 0; font-size: 28px; }}
        .header .subtitle {{ margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }}
        
        .summary-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }}
        .summary-card {{
            background: white;
            padding: 25px;
            border-radius: 10px;
            text-align: center;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            border-left: 5px solid #0078d4;
        }}
        .summary-card h3 {{ 
            margin: 0 0 15px 0; 
            color: #666; 
            font-size: 16px; 
            font-weight: 600;
        }}
        .summary-card .value {{ 
            font-size: 36px; 
            font-weight: bold; 
            margin: 10px 0 15px 0; 
            color: #0078d4; 
        }}
        .summary-card .description {{ 
            color: #888; 
            font-size: 14px; 
            margin: 0;
        }}
        
        .controls-section {{
            background: white;
            padding: 25px;
            border-radius: 10px;
            margin-bottom: 25px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
        }}
        .controls-section h3 {{
            margin: 0 0 20px 0;
            color: #333;
            font-size: 18px;
        }}
        .filter-controls {{
            display: flex;
            gap: 15px;
            align-items: center;
            flex-wrap: wrap;
            margin-bottom: 20px;
        }}
        .filter-controls input, .filter-controls select {{
            padding: 10px 15px;
            border: 2px solid #ddd;
            border-radius: 6px;
            font-size: 14px;
            min-width: 180px;
        }}
        .filter-controls input:focus, .filter-controls select:focus {{
            outline: none;
            border-color: #0078d4;
        }}
        .filter-controls button {{
            padding: 10px 20px;
            background: #0078d4;
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
            transition: background-color 0.3s;
        }}
        .filter-controls button:hover {{
            background: #106ebe;
        }}
        .filter-controls button.export {{
            background: #28a745;
        }}
        .filter-controls button.export:hover {{
            background: #218838;
        }}
        
        .table-container {{
            background: white;
            border-radius: 10px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            overflow: hidden;
        }}
        .table-header {{
            background: linear-gradient(135deg, #6c757d 0%, #5a6268 100%);
            color: white;
            padding: 20px 25px;
            font-weight: bold;
            font-size: 18px;
        }}
        .table-wrapper {{
            max-height: 700px;
            overflow-y: auto;
            border: 1px solid #ddd;
        }}
        .data-table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
        }}
        .data-table thead th {{
            background-color: #0078d4;
            color: white;
            border: 1px solid #0078d4;
            padding: 15px 12px;
            text-align: left;
            font-weight: 600;
            position: sticky;
            top: 0;
            z-index: 10;
        }}
        .data-table tbody td {{
            border: 1px solid #e0e0e0;
            padding: 12px;
            font-size: 13px;
        }}
        .data-table tbody tr:nth-child(even) {{
            background-color: #f8f9fa;
        }}
        .data-table tbody tr:hover {{
            background-color: #e3f2fd;
            cursor: pointer;
        }}
        
        /* ライセンス種別による色分け */
        .license-e3 {{ 
            background-color: #e3f2fd !important; 
            border-left: 4px solid #2196f3;
        }}
        .license-exchange {{ 
            background-color: #e8f5e8 !important; 
            border-left: 4px solid #4caf50;
        }}
        .license-basic {{ 
            background-color: #fff3e0 !important; 
            border-left: 4px solid #ff9800;
        }}
        
        .stats-footer {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 15px;
            padding: 20px 25px;
            background: #f8f9fa;
            border-top: 3px solid #0078d4;
            font-size: 13px;
        }}
        .stats-footer > div {{
            text-align: center;
            padding: 10px;
        }}
        .stats-footer .label {{
            font-weight: 600;
            color: #666;
            display: block;
            margin-bottom: 5px;
        }}
        .stats-footer .value {{
            font-size: 20px;
            color: #0078d4;
            font-weight: bold;
        }}
        
        .footer {{ 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 40px; 
            padding: 25px;
            background: white;
            border-radius: 10px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
        }}
        
        .no-results {{
            text-align: center;
            padding: 40px;
            color: #666;
            font-style: italic;
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>👥 Microsoft 365ライセンス割り当てユーザー完全一覧表</h1>
        <div class="subtitle">みらい建設工業株式会社 - 全ユーザーライセンス情報</div>
        <div class="subtitle">生成日時: {datetime.now().strftime('%Y年%m月%d日 %H:%M:%S')}</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>Microsoft 365 E3</h3>
            <div class="value">{total_e3}</div>
            <div class="description">ユーザー（¥2,840/月）</div>
        </div>
        <div class="summary-card">
            <h3>Exchange Online Plan 2</h3>
            <div class="value">{total_exchange}</div>
            <div class="description">ユーザー（¥960/月）</div>
        </div>
        <div class="summary-card">
            <h3>Business Basic (レガシー)</h3>
            <div class="value">{total_basic}</div>
            <div class="description">ユーザー（¥1,000/月）</div>
        </div>
        <div class="summary-card">
            <h3>総月額コスト</h3>
            <div class="value">¥{total_cost:,}</div>
            <div class="description">現在の支出</div>
        </div>
    </div>

    <div class="controls-section">
        <h3>🔍 検索・フィルター・エクスポート</h3>
        <div class="filter-controls">
            <input type="text" id="searchInput" placeholder="ユーザー名で検索..." onkeyup="filterTable()">
            <select id="licenseFilter" onchange="filterTable()">
                <option value="">全ライセンス</option>
                <option value="Microsoft 365 E3">Microsoft 365 E3</option>
                <option value="Exchange Online Plan 2">Exchange Online Plan 2</option>
                <option value="Business Basic">Business Basic (レガシー)</option>
            </select>
            <select id="departmentFilter" onchange="filterTable()">
                <option value="">全部署</option>
                <option value="has-dept">部署コードあり</option>
                <option value="no-dept">部署コードなし</option>
            </select>
            <button onclick="clearFilters()">フィルタークリア</button>
            <button class="export" onclick="exportToCSV()">CSV出力</button>
        </div>
    </div>

    <div class="table-container">
        <div class="table-header" id="tableHeader">📋 ライセンス割り当てユーザー詳細一覧（全{len(user_data)}名）</div>
        <div class="table-wrapper">
            <table class="data-table" id="userTable">
                <thead>
                    <tr>
                        <th style="width: 60px;">No.</th>
                        <th style="width: 200px;">ユーザー名</th>
                        <th style="width: 100px;">部署コード</th>
                        <th style="width: 250px;">ライセンス種別</th>
                        <th style="width: 120px;">月額コスト</th>
                        <th style="width: 100px;">利用状況</th>
                        <th style="width: 120px;">最適化状況</th>
                    </tr>
                </thead>
                <tbody id="userTableBody">"""

        # ユーザーデータのテーブル行を生成
        for index, user in enumerate(user_data, 1):
            department = user['Department'] if user['Department'].strip() else '-'
            license_name = user['AssignedLicenses']
            
            # ライセンス種別によるCSSクラス決定
            if license_name == 'Microsoft 365 E3':
                license_class = 'license-e3'
            elif license_name == 'Exchange Online Plan 2':
                license_class = 'license-exchange'
            else:
                license_class = 'license-basic'
            
            monthly_cost = int(user['TotalMonthlyCost'])
            
            html_content += f"""
                    <tr class="{license_class}">
                        <td>{index}</td>
                        <td><strong>{user['DisplayName']}</strong></td>
                        <td>{department}</td>
                        <td>{license_name}</td>
                        <td>¥{monthly_cost:,}</td>
                        <td>{user['UtilizationStatus']}</td>
                        <td>{user['OptimizationRecommendations']}</td>
                    </tr>"""

        # HTMLの残り部分を追加
        html_content += f"""
                </tbody>
            </table>
        </div>
        
        <div class="stats-footer">
            <div><span class="label">表示中</span><span class="value" id="visibleCount">{len(user_data)}</span></div>
            <div><span class="label">Microsoft 365 E3</span><span class="value">{total_e3}</span></div>
            <div><span class="label">Exchange Online Plan 2</span><span class="value">{total_exchange}</span></div>
            <div><span class="label">Business Basic</span><span class="value">{total_basic}</span></div>
            <div><span class="label">総ユーザー数</span><span class="value">{len(user_data)}</span></div>
            <div><span class="label">平均コスト/ユーザー</span><span class="value">¥{avg_cost:,}</span></div>
        </div>
    </div>

    <div class="footer">
        <p><strong>このレポートは Microsoft 365 ライセンス管理システムにより自動生成されました</strong></p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社 ライセンス最適化センター</p>
        <p>🤖 Generated with Claude Code</p>
    </div>

    <script>
        // フィルター機能
        function filterTable() {{
            const searchInput = document.getElementById('searchInput').value.toLowerCase();
            const licenseFilter = document.getElementById('licenseFilter').value;
            const departmentFilter = document.getElementById('departmentFilter').value;
            const tableBody = document.getElementById('userTableBody');
            const rows = tableBody.getElementsByTagName('tr');

            let visibleCount = 0;
            for (let i = 0; i < rows.length; i++) {{
                const row = rows[i];
                const userName = row.cells[1] ? row.cells[1].textContent.toLowerCase() : '';
                const license = row.cells[3] ? row.cells[3].textContent : '';
                const department = row.cells[2] ? row.cells[2].textContent : '';
                
                let showRow = true;

                if (searchInput && !userName.includes(searchInput)) {{
                    showRow = false;
                }}

                if (licenseFilter && !license.includes(licenseFilter)) {{
                    showRow = false;
                }}

                if (departmentFilter === 'has-dept' && department === '-') {{
                    showRow = false;
                }} else if (departmentFilter === 'no-dept' && department !== '-') {{
                    showRow = false;
                }}

                row.style.display = showRow ? '' : 'none';
                if (showRow) visibleCount++;
            }}
            
            document.getElementById('tableHeader').textContent = `📋 ライセンス割り当てユーザー詳細一覧（表示中: ${{visibleCount}}名 / 全{len(user_data)}名）`;
            document.getElementById('visibleCount').textContent = visibleCount;
        }}

        // フィルタークリア
        function clearFilters() {{
            document.getElementById('searchInput').value = '';
            document.getElementById('licenseFilter').value = '';
            document.getElementById('departmentFilter').value = '';
            filterTable();
        }}

        // CSV出力
        function exportToCSV() {{
            const visibleRows = [];
            const tableBody = document.getElementById('userTableBody');
            const rows = tableBody.getElementsByTagName('tr');
            
            // ヘッダー
            visibleRows.push(['No.', 'ユーザー名', '部署コード', 'ライセンス種別', '月額コスト', '利用状況', '最適化状況']);
            
            // 表示中の行のみ
            for (let i = 0; i < rows.length; i++) {{
                const row = rows[i];
                if (row.style.display !== 'none') {{
                    const rowData = [];
                    for (let j = 0; j < row.cells.length; j++) {{
                        rowData.push(row.cells[j].textContent);
                    }}
                    visibleRows.push(rowData);
                }}
            }}
            
            // CSV形式に変換
            const csvContent = visibleRows.map(row => 
                row.map(cell => `"${{cell}}"`).join(',')
            ).join('\\n');
            
            // ダウンロード
            const blob = new Blob([csvContent], {{ type: 'text/csv;charset=utf-8;' }});
            const link = document.createElement('a');
            const url = URL.createObjectURL(blob);
            link.setAttribute('href', url);
            link.setAttribute('download', 'license_users_' + new Date().toISOString().split('T')[0] + '.csv');
            link.style.visibility = 'hidden';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }}
    </script>
</body>
</html>"""

        # HTMLファイルに出力
        with open(output_html_path, 'w', encoding='utf-8') as htmlfile:
            htmlfile.write(html_content)
        
        print(f"完全なHTMLユーザー一覧表を生成しました: {output_html_path}")
        print(f"総ユーザー数: {len(user_data)}名")
        print(f"Microsoft 365 E3: {total_e3}名")
        print(f"Exchange Online Plan 2: {total_exchange}名")
        print(f"Business Basic: {total_basic}名")
        print(f"総月額コスト: ¥{total_cost:,}")
        
    except Exception as e:
        print(f"エラーが発生しました: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()