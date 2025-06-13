#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import csv

# CSVファイルからユーザーデータを読み込み
csv_path = '/mnt/e/MicrosoftProductManagementTools/Reports/Monthly/Clean_Complete_User_License_Details.csv'
html_rows = []

with open(csv_path, 'r', encoding='utf-8-sig') as file:
    reader = csv.DictReader(file)
    for row in reader:
        # ライセンス種別に応じたCSSクラスを設定
        css_class = 'risk-normal'
        if 'Exchange' in row['ライセンス種別']:
            css_class = 'risk-attention'
        elif 'Basic' in row['ライセンス種別']:
            css_class = 'risk-info'
        
        dept_code = row['部署コード'] if row['部署コード'] != '-' else ''
        
        html_row = f'''                        <tr class="{css_class}">
                            <td>{row['No']}</td>
                            <td><strong>{row['ユーザー名']}</strong></td>
                            <td>{dept_code}</td>
                            <td style="text-align: center;">{row['ライセンス数']}</td>
                            <td>{row['ライセンス種別']}</td>
                            <td style="text-align: right;">{row['月額コスト']}</td>
                            <td style="text-align: center;">{row['最終サインイン']}</td>
                            <td style="text-align: center;">{row['利用状況']}</td>
                            <td>{row['最適化状況']}</td>
                        </tr>'''
        html_rows.append(html_row)

# 結果を出力
print('\n'.join(html_rows))