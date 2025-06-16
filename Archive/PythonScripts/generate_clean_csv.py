#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
元CSVファイルから綺麗に整理されたCSVファイルを生成するPythonスクリプト
"""

import csv
import os
import sys
from datetime import datetime

def main():
    if len(sys.argv) != 3:
        print("使用方法: python generate_clean_csv.py <INPUT_CSV_PATH> <OUTPUT_CSV_PATH>")
        sys.exit(1)
    
    input_csv_path = sys.argv[1]
    output_csv_path = sys.argv[2]
    
    try:
        print(f"CSVファイルからユーザーデータを読み込み中: {input_csv_path}")
        
        # CSVファイルを読み込み
        user_data = []
        with open(input_csv_path, 'r', encoding='utf-8-sig') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                user_data.append(row)
        
        print(f"読み込み完了: {len(user_data)}ユーザー")
        
        # ライセンス種別でソート（E3 → Exchange → Basic）
        def license_sort_key(user):
            license = user['AssignedLicenses']
            if license == 'Microsoft 365 E3':
                return (1, user['DisplayName'])
            elif license == 'Exchange Online Plan 2':
                return (2, user['DisplayName'])
            else:
                return (3, user['DisplayName'])
        
        user_data.sort(key=license_sort_key)
        
        # 清潔で整理されたCSVファイルを生成
        with open(output_csv_path, 'w', encoding='utf-8-sig', newline='') as csvfile:
            fieldnames = [
                'No',
                'ユーザー名',
                '部署コード',
                'ライセンス種別',
                '月額コスト（円）',
                '利用状況',
                '最適化状況',
                'メールアドレス',
                '作成日時',
                '分析日時'
            ]
            
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            
            for index, user in enumerate(user_data, 1):
                department = user['Department'] if user['Department'].strip() else '-'
                monthly_cost = int(user['TotalMonthlyCost'])
                
                writer.writerow({
                    'No': index,
                    'ユーザー名': user['DisplayName'],
                    '部署コード': department,
                    'ライセンス種別': user['AssignedLicenses'],
                    '月額コスト（円）': f"¥{monthly_cost:,}",
                    '利用状況': user['UtilizationStatus'],
                    '最適化状況': user['OptimizationRecommendations'],
                    'メールアドレス': user['UserPrincipalName'],
                    '作成日時': user['CreatedDateTime'],
                    '分析日時': user['AnalysisTimestamp']
                })
        
        # ライセンス別統計情報を生成
        total_e3 = len([u for u in user_data if u['AssignedLicenses'] == 'Microsoft 365 E3'])
        total_exchange = len([u for u in user_data if u['AssignedLicenses'] == 'Exchange Online Plan 2'])
        total_basic = len([u for u in user_data if 'Business Basic' in u['AssignedLicenses']])
        total_cost = sum(int(u['TotalMonthlyCost']) for u in user_data)
        
        # 統計情報CSVも生成
        stats_csv_path = output_csv_path.replace('.csv', '_統計情報.csv')
        with open(stats_csv_path, 'w', encoding='utf-8-sig', newline='') as csvfile:
            fieldnames = ['項目', '数量', '備考']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            
            writer.writerow({'項目': 'Microsoft 365 E3ライセンス', '数量': f'{total_e3}ユーザー', '備考': '¥2,840/月'})
            writer.writerow({'項目': 'Exchange Online Plan 2ライセンス', '数量': f'{total_exchange}ユーザー', '備考': '¥960/月'})
            writer.writerow({'項目': 'Business Basic ライセンス', '数量': f'{total_basic}ユーザー', '備考': '¥1,000/月'})
            writer.writerow({'項目': '総ユーザー数', '数量': f'{len(user_data)}ユーザー', '備考': '全ライセンス合計'})
            writer.writerow({'項目': '総月額コスト', '数量': f'¥{total_cost:,}', '備考': '全ライセンス合計'})
            writer.writerow({'項目': '平均コスト/ユーザー', '数量': f'¥{total_cost // len(user_data):,}', '備考': '月額平均'})
            writer.writerow({'項目': '生成日時', '数量': datetime.now().strftime('%Y年%m月%d日 %H:%M:%S'), '備考': 'システム生成'})
        
        print(f"綺麗に整理されたCSVファイルを生成しました: {output_csv_path}")
        print(f"統計情報CSVファイルを生成しました: {stats_csv_path}")
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