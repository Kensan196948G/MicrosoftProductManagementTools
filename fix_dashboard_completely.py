#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
破損したHTMLダッシュボードファイルを完全に修正するスクリプト
"""

import csv
from datetime import datetime

# CSVファイルからユーザーデータを読み込み
def load_user_data():
    csv_path = '/mnt/e/MicrosoftProductManagementTools/Reports/Monthly/Clean_Complete_User_License_Details.csv'
    users = []
    
    with open(csv_path, 'r', encoding='utf-8-sig') as file:
        reader = csv.DictReader(file)
        for row in reader:
            users.append(row)
    
    return users

# 完全なHTMLダッシュボードを生成
def generate_complete_dashboard():
    users = load_user_data()
    
    # ユーザーテーブル行を生成
    user_rows = []
    for user in users:
        # ライセンス種別に応じたCSSクラスを設定
        css_class = 'risk-normal'
        if 'Exchange' in user['ライセンス種別']:
            css_class = 'risk-attention'
        elif 'Basic' in user['ライセンス種別']:
            css_class = 'risk-info'
        
        dept_code = user['部署コード'] if user['部署コード'] != '-' else ''
        
        user_row = f'''                        <tr class="{css_class}">
                            <td>{user['No']}</td>
                            <td><strong>{user['ユーザー名']}</strong></td>
                            <td>{dept_code}</td>
                            <td style="text-align: center;">{user['ライセンス数']}</td>
                            <td>{user['ライセンス種別']}</td>
                            <td style="text-align: right;">{user['月額コスト']}</td>
                            <td style="text-align: center;">{user['最終サインイン']}</td>
                            <td style="text-align: center;">{user['利用状況']}</td>
                            <td>{user['最適化状況']}</td>
                        </tr>'''
        user_rows.append(user_row)
    
    user_table_content = '\n'.join(user_rows)
    
    # 完全なHTMLファイルを生成
    html_content = f'''<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft 365ライセンス分析ダッシュボード</title>
    <style>
        body {{ 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
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
        }}
        .header h1 {{ margin: 0; font-size: 28px; }}
        .header .subtitle {{ margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }}
        .summary-grid {{ 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }}
        .summary-card {{ 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        .summary-card h3 {{ margin: 0 0 10px 0; color: #666; font-size: 14px; }}
        .summary-card .value {{ font-size: 36px; font-weight: bold; margin: 10px 0; }}
        .value.success {{ color: #107c10; }}
        .value.warning {{ color: #ff8c00; }}
        .value.danger {{ color: #d13438; }}
        .value.info {{ color: #0078d4; }}
        .section {{
            background: white;
            margin-bottom: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        .section-header {{
            background: linear-gradient(135deg, #6c757d 0%, #5a6268 100%);
            color: white;
            padding: 15px 20px;
            border-radius: 8px 8px 0 0;
            font-weight: bold;
        }}
        .section-content {{ padding: 20px; }}
        .data-table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
            margin: 20px 0;
        }}
        .data-table th {{
            background-color: #0078d4;
            color: white;
            border: 1px solid #ddd;
            padding: 12px 8px;
            text-align: left;
            font-weight: bold;
        }}
        .data-table td {{
            border: 1px solid #ddd;
            padding: 8px;
            font-size: 12px;
        }}
        .data-table tr:nth-child(even) {{
            background-color: #f8f9fa;
        }}
        .data-table tr:hover {{
            background-color: #e9ecef;
        }}
        .risk-normal {{ background-color: #d4edda !important; color: #155724; }}
        .risk-attention {{ background-color: #cce5f0 !important; color: #0c5460; }}
        .risk-info {{ background-color: #d1ecf1 !important; color: #0c5460; }}
        .scrollable-table {{
            overflow-x: auto;
            margin: 20px 0;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            max-height: 600px;
            overflow-y: auto;
        }}
        .footer {{ 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }}
    </style>
    <script>
        function filterTable() {{
            const searchInput = document.getElementById('searchInput').value.toLowerCase();
            const licenseFilter = document.getElementById('licenseFilter').value;
            const table = document.getElementById('userTable');
            const rows = table.getElementsByTagName('tr');
            
            for (let i = 1; i < rows.length; i++) {{
                const row = rows[i];
                const cells = row.getElementsByTagName('td');
                let showRow = true;
                
                if (searchInput) {{
                    const userName = cells[1] ? cells[1].textContent.toLowerCase() : '';
                    const deptCode = cells[2] ? cells[2].textContent.toLowerCase() : '';
                    const licenseType = cells[4] ? cells[4].textContent.toLowerCase() : '';
                    
                    if (!userName.includes(searchInput) && 
                        !deptCode.includes(searchInput) && 
                        !licenseType.includes(searchInput)) {{
                        showRow = false;
                    }}
                }}
                
                if (licenseFilter && cells[4]) {{
                    if (!cells[4].textContent.includes(licenseFilter)) {{
                        showRow = false;
                    }}
                }}
                
                row.style.display = showRow ? '' : 'none';
            }}
        }}
        
        function exportToCSV() {{
            window.open('/mnt/e/MicrosoftProductManagementTools/Reports/Monthly/Clean_Complete_User_License_Details.csv');
        }}
        
        document.addEventListener('DOMContentLoaded', function() {{
            document.getElementById('searchInput').addEventListener('input', filterTable);
            document.getElementById('licenseFilter').addEventListener('change', filterTable);
        }});
    </script>
</head>
<body>
    <div class="header">
        <h1>💰 Microsoft 365ライセンス分析ダッシュボード</h1>
        <div class="subtitle">みらい建設工業株式会社 - ライセンス最適化・コスト監視</div>
        <div class="subtitle">分析実行日時: {datetime.now().strftime('%Y年%m月%d日 %H:%M:%S')}</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総ライセンス数</h3>
            <div class="value info">508</div>
            <div class="description">購入済み</div>
        </div>
        <div class="summary-card">
            <h3>使用中ライセンス</h3>
            <div class="value success">463</div>
            <div class="description">割り当て済み</div>
        </div>
        <div class="summary-card">
            <h3>未使用ライセンス</h3>
            <div class="value warning">45</div>
            <div class="description">コスト削減機会</div>
        </div>
        <div class="summary-card">
            <h3>月額総コスト</h3>
            <div class="value info">¥1,220,960</div>
            <div class="description">現在の支出</div>
        </div>
    </div>

    <div class="section">
        <div class="section-header">👥 ユーザーライセンス詳細一覧</div>
        <div class="section-content">
            <p>総ユーザー数: <strong>{len(users)}名</strong> | 検索・フィルター機能付き</p>
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
{user_table_content}
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div class="footer">
        <p>このレポートは Microsoft 365 ライセンス管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社 ライセンス最適化センター</p>
        <p>修正済み - 🤖 Generated with Claude Code</p>
    </div>
</body>
</html>'''

    return html_content

# メイン処理
if __name__ == "__main__":
    html_content = generate_complete_dashboard()
    
    # 修正済みファイルを保存
    output_path = '/mnt/e/MicrosoftProductManagementTools/Reports/Monthly/License_Analysis_Dashboard_20250613_142142.html'
    
    with open(output_path, 'w', encoding='utf-8') as file:
        file.write(html_content)
    
    print(f"完全に修正されたHTMLダッシュボードを生成しました: {output_path}")
    print("ユーザーデータが正しい表形式で表示されます")