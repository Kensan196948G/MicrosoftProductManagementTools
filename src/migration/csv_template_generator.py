"""
Microsoft 365管理ツール CSV テンプレート生成器
==========================================

PowerShell互換CSVテンプレート・サンプルデータ生成
- 26機能対応CSVテンプレート自動生成
- PowerShell形式互換性維持
- ダミーデータ生成（テスト・サンプル用）
"""

import os
import csv
import json
from datetime import datetime, date, timedelta
from decimal import Decimal
from typing import List, Dict, Any, Optional
from pathlib import Path
import random
import string
from uuid import uuid4

from ..database.models import (
    # 定期レポート
    DailySecurityReport, PeriodicSummaryReport, TestExecutionResult,
    
    # 分析レポート  
    LicenseAnalysis, ServiceUsageAnalysis, PerformanceMonitoring,
    SecurityAnalysis, PermissionAudit,
    
    # Entra ID
    User, MFAStatus, ConditionalAccessPolicy, SignInLog,
    
    # Exchange Online
    Mailbox, MailFlowAnalysis, SpamProtectionAnalysis, MailDeliveryAnalysis,
    
    # Teams
    TeamsUsage, TeamsSettingsAnalysis, MeetingQualityAnalysis, TeamsAppAnalysis,
    
    # OneDrive
    OneDriveStorageAnalysis, OneDriveSharingAnalysis, OneDriveSyncError,
    OneDriveExternalSharing
)


class PowerShellCSVTemplateGenerator:
    """PowerShell互換CSVテンプレート生成器"""
    
    # モデルクラスマッピング（data_migrator.pyと同じ）
    MODEL_MAPPING = {
        # 定期レポート (5機能)
        "daily": DailySecurityReport,
        "weekly": PeriodicSummaryReport, 
        "monthly": PeriodicSummaryReport,
        "yearly": PeriodicSummaryReport,
        "test": TestExecutionResult,
        
        # 分析レポート (5機能)
        "license": LicenseAnalysis,
        "usage": ServiceUsageAnalysis,
        "performance": PerformanceMonitoring,
        "security": SecurityAnalysis,
        "permissions": PermissionAudit,
        
        # Entra ID管理 (4機能)
        "users": User,
        "mfa": MFAStatus,
        "conditional_access": ConditionalAccessPolicy,
        "signin_logs": SignInLog,
        
        # Exchange Online管理 (4機能)
        "mailboxes": Mailbox,
        "mail_flow": MailFlowAnalysis,
        "spam_protection": SpamProtectionAnalysis,
        "mail_delivery": MailDeliveryAnalysis,
        
        # Teams管理 (4機能)
        "teams_usage": TeamsUsage,
        "teams_settings": TeamsSettingsAnalysis,
        "meeting_quality": MeetingQualityAnalysis,
        "teams_apps": TeamsAppAnalysis,
        
        # OneDrive管理 (4機能)
        "storage": OneDriveStorageAnalysis,
        "sharing": OneDriveSharingAnalysis,
        "sync_errors": OneDriveSyncError,
        "external_sharing": OneDriveExternalSharing
    }
    
    def __init__(self, output_path: str = "/mnt/e/MicrosoftProductManagementTools/Templates/Generated"):
        """
        テンプレート生成器初期化
        
        Args:
            output_path: テンプレート出力パス
        """
        self.output_path = Path(output_path)
        self.output_path.mkdir(parents=True, exist_ok=True)
        
        # サンプルデータ生成用設定
        self.sample_data_config = self._initialize_sample_config()
    
    def _initialize_sample_config(self) -> Dict[str, Any]:
        """サンプルデータ生成設定初期化"""
        return {
            "sample_users": [
                "田中太郎", "佐藤花子", "鈴木一郎", "高橋美咲", "伊藤健太",
                "渡辺真理", "山本次郎", "中村由美", "小林和也", "加藤麻衣"
            ],
            "departments": [
                "経営企画部", "人事部", "財務部", "営業部", "マーケティング部",
                "開発部", "品質保証部", "情報システム部", "総務部", "法務部"
            ],
            "license_types": [
                "Microsoft 365 E3", "Microsoft 365 E5", "Office 365 E1",
                "Exchange Online Plan 1", "Teams Essentials", "OneDrive for Business"
            ],
            "status_values": {
                "general": ["アクティブ", "非アクティブ", "保留中"],
                "risk": ["低", "中", "高"],
                "quality": ["良好", "普通", "要改善"],
                "mfa": ["有効", "無効", "強制"]
            }
        }
    
    def generate_all_templates(self, include_sample_data: bool = True) -> Dict[str, str]:
        """全機能のテンプレート一括生成"""
        
        generated_files = {}
        
        for function_name, model_class in self.MODEL_MAPPING.items():
            try:
                # CSVテンプレート生成
                template_path = self.generate_csv_template(function_name, model_class)
                generated_files[f"{function_name}_template"] = str(template_path)
                
                # サンプルデータ生成
                if include_sample_data:
                    sample_path = self.generate_sample_data(function_name, model_class)
                    generated_files[f"{function_name}_sample"] = str(sample_path)
                
            except Exception as e:
                print(f"テンプレート生成エラー {function_name}: {e}")
        
        return generated_files
    
    def generate_csv_template(self, function_name: str, model_class) -> Path:
        """個別CSVテンプレート生成"""
        
        # ファイルパス決定
        template_filename = f"{function_name}_template.csv"
        template_path = self.output_path / template_filename
        
        # カラム定義取得
        headers = self._get_powershell_headers(model_class)
        
        # CSVテンプレート作成
        with open(template_path, 'w', newline='', encoding='utf-8-sig') as csvfile:
            writer = csv.writer(csvfile)
            
            # ヘッダー行
            writer.writerow(headers)
            
            # 空行（テンプレート用）
            writer.writerow([''] * len(headers))
        
        print(f"CSVテンプレート生成完了: {template_path}")
        return template_path
    
    def generate_sample_data(self, function_name: str, model_class, sample_count: int = 50) -> Path:
        """サンプルデータ生成"""
        
        # ファイルパス決定
        sample_filename = f"{function_name}_sample_data.csv"
        sample_path = self.output_path / sample_filename
        
        # カラム定義取得
        headers = self._get_powershell_headers(model_class)
        
        # サンプルデータ生成
        sample_records = []
        for i in range(sample_count):
            record = self._generate_sample_record(model_class, function_name, i)
            sample_records.append(record)
        
        # CSV出力
        with open(sample_path, 'w', newline='', encoding='utf-8-sig') as csvfile:
            writer = csv.writer(csvfile)
            
            # ヘッダー行
            writer.writerow(headers)
            
            # データ行
            for record in sample_records:
                row = [record.get(header, '') for header in headers]
                writer.writerow(row)
        
        print(f"サンプルデータ生成完了: {sample_path}")
        return sample_path
    
    def _get_powershell_headers(self, model_class) -> List[str]:
        """PowerShell互換ヘッダー生成"""
        
        headers = []
        
        for column in model_class.__table__.columns:
            # データベース列名をPowerShell形式に変換
            powershell_name = self._convert_to_powershell_name(column.name)
            headers.append(powershell_name)
        
        return headers
    
    def _convert_to_powershell_name(self, db_column_name: str) -> str:
        """データベース列名 → PowerShell列名変換"""
        
        # 特別なマッピング
        special_mappings = {
            'user_name': 'UserName',
            'user_principal_name': 'UserPrincipalName', 
            'created_at': 'CreatedDateTime',
            'updated_at': 'LastModifiedDateTime',
            'report_date': 'ReportDate',
            'total_size_mb': 'TotalItemSize',
            'usage_percent': 'Usage %',
            'license_type': 'LicenseType',
            'mfa_status': 'MFAStatus',
            'signin_datetime': 'SignInDateTime',
            'ip_address': 'IPAddress',
            'risk_level': 'RiskLevel'
        }
        
        if db_column_name in special_mappings:
            return special_mappings[db_column_name]
        
        # 一般的な変換（snake_case → PascalCase）
        return ''.join(word.capitalize() for word in db_column_name.split('_'))
    
    def _generate_sample_record(self, model_class, function_name: str, index: int) -> Dict[str, Any]:
        """サンプルレコード生成"""
        
        record = {}
        
        for column in model_class.__table__.columns:
            powershell_name = self._convert_to_powershell_name(column.name)
            
            # データ型に応じてサンプル値生成
            sample_value = self._generate_sample_value(column, function_name, index)
            record[powershell_name] = sample_value
        
        return record
    
    def _generate_sample_value(self, column, function_name: str, index: int) -> Any:
        """カラム型に応じたサンプル値生成"""
        
        column_name = column.name
        
        try:
            # 主キー（ID）
            if column_name == 'id':
                return index + 1
            
            # ユーザー名
            elif 'user_name' in column_name or 'display_name' in column_name:
                return random.choice(self.sample_data_config["sample_users"])
            
            # メールアドレス・UPN
            elif 'email' in column_name or 'user_principal_name' in column_name:
                username = random.choice(self.sample_data_config["sample_users"]).replace(' ', '.')
                return f"{username.lower()}@contoso.com"
            
            # 部署
            elif 'department' in column_name:
                return random.choice(self.sample_data_config["departments"])
            
            # 日付型
            elif str(column.type).startswith('DATETIME'):
                base_date = datetime.now() - timedelta(days=random.randint(1, 365))
                return base_date.strftime('%Y-%m-%d %H:%M:%S')
            
            elif str(column.type).startswith('DATE'):
                base_date = date.today() - timedelta(days=random.randint(1, 365))
                return base_date.strftime('%Y-%m-%d')
            
            # 整数型
            elif hasattr(column.type, 'python_type') and column.type.python_type == int:
                if 'count' in column_name or 'size' in column_name:
                    return random.randint(1, 1000)
                elif 'percent' in column_name:
                    return random.randint(0, 100)
                else:
                    return random.randint(1, 100)
            
            # Decimal型
            elif str(column.type).startswith('DECIMAL'):
                if 'percent' in column_name or 'rate' in column_name:
                    return f"{random.uniform(0, 100):.2f}%"
                elif 'cost' in column_name or 'price' in column_name:
                    return f"¥{random.uniform(100, 10000):.2f}"
                else:
                    return f"{random.uniform(0, 1000):.2f}"
            
            # Boolean型
            elif hasattr(column.type, 'python_type') and column.type.python_type == bool:
                return random.choice(['True', 'False'])
            
            # ステータス・リスク系
            elif any(keyword in column_name for keyword in ['status', 'risk', 'level']):
                if 'risk' in column_name:
                    return random.choice(self.sample_data_config["status_values"]["risk"])
                elif 'mfa' in column_name:
                    return random.choice(self.sample_data_config["status_values"]["mfa"])
                else:
                    return random.choice(self.sample_data_config["status_values"]["general"])
            
            # ライセンス型
            elif 'license' in column_name:
                return random.choice(self.sample_data_config["license_types"])
            
            # IPアドレス
            elif 'ip_address' in column_name:
                return f"192.168.{random.randint(1, 255)}.{random.randint(1, 255)}"
            
            # URL
            elif 'url' in column_name:
                return f"https://contoso.sharepoint.com/{random.choice(['sites', 'personal'])}/{uuid4().hex[:8]}"
            
            # メッセージID
            elif 'message_id' in column_name:
                return f"<{uuid4()}@contoso.com>"
            
            # その他の文字列
            elif hasattr(column.type, 'python_type') and column.type.python_type == str:
                if 'name' in column_name:
                    return f"Sample {column_name.title()} {index + 1}"
                else:
                    return f"Sample Data {index + 1}"
            
            else:
                return f"Sample_{index + 1}"
                
        except Exception as e:
            print(f"サンプル値生成エラー {column_name}: {e}")
            return f"Sample_{index + 1}"
    
    def generate_function_documentation(self, function_name: str, model_class) -> Path:
        """機能別データ仕様書生成"""
        
        doc_filename = f"{function_name}_data_specification.md"
        doc_path = self.output_path / doc_filename
        
        # データ仕様書内容生成
        documentation = self._create_data_specification(function_name, model_class)
        
        # マークダウンファイル出力
        with open(doc_path, 'w', encoding='utf-8') as f:
            f.write(documentation)
        
        print(f"データ仕様書生成完了: {doc_path}")
        return doc_path
    
    def _create_data_specification(self, function_name: str, model_class) -> str:
        """データ仕様書内容作成"""
        
        spec_content = f"""# {function_name.upper()} データ仕様書

## 概要
Microsoft 365管理ツール - {function_name} 機能のデータ仕様書

## データベーステーブル
- テーブル名: `{model_class.__tablename__}`
- 機能名: {function_name}

## カラム仕様

| PowerShell列名 | データベース列名 | データ型 | 必須 | 説明 |
|---------------|-----------------|---------|-----|-----|
"""
        
        for column in model_class.__table__.columns:
            powershell_name = self._convert_to_powershell_name(column.name)
            db_name = column.name
            data_type = str(column.type)
            nullable = "任意" if column.nullable else "必須"
            
            # 説明生成
            description = self._generate_column_description(column.name, function_name)
            
            spec_content += f"| {powershell_name} | {db_name} | {data_type} | {nullable} | {description} |\n"
        
        # サンプルデータセクション追加
        spec_content += f"""
## サンプルCSVファイル
- テンプレート: `{function_name}_template.csv`
- サンプルデータ: `{function_name}_sample_data.csv`

## PowerShell互換性
このデータ形式はPowerShell出力と完全互換です。

## 注意事項
- 日付形式: `YYYY-MM-DD HH:MM:SS`
- 文字エンコーディング: UTF-8 with BOM
- 数値形式: カンマ区切りサポート
- パーセント値: `XX.XX%` 形式
"""
        
        return spec_content
    
    def _generate_column_description(self, column_name: str, function_name: str) -> str:
        """カラム説明生成"""
        
        descriptions = {
            'id': 'プライマリキー（自動生成）',
            'user_name': 'ユーザー表示名',
            'user_principal_name': 'ユーザープリンシパル名（UPN）',
            'email': 'メールアドレス',
            'department': '所属部署',
            'created_at': 'レコード作成日時',
            'updated_at': 'レコード更新日時',
            'report_date': 'レポート生成日',
            'mfa_status': '多要素認証ステータス',
            'license_type': 'ライセンスタイプ',
            'risk_level': 'リスクレベル（低/中/高）',
            'status': 'ステータス'
        }
        
        return descriptions.get(column_name, f'{function_name}関連データ項目')


# 便利関数
def generate_all_csv_templates(output_path: Optional[str] = None) -> Dict[str, str]:
    """全機能のCSVテンプレート一括生成"""
    
    generator = PowerShellCSVTemplateGenerator(
        output_path or "/mnt/e/MicrosoftProductManagementTools/Templates/Generated"
    )
    
    return generator.generate_all_templates()


def generate_specific_template(function_name: str, output_path: Optional[str] = None) -> str:
    """特定機能のテンプレート生成"""
    
    generator = PowerShellCSVTemplateGenerator(
        output_path or "/mnt/e/MicrosoftProductManagementTools/Templates/Generated"  
    )
    
    if function_name not in generator.MODEL_MAPPING:
        raise ValueError(f"サポートされていない機能名: {function_name}")
    
    model_class = generator.MODEL_MAPPING[function_name]
    template_path = generator.generate_csv_template(function_name, model_class)
    
    return str(template_path)


if __name__ == "__main__":
    # テスト実行
    print("CSVテンプレート生成テスト開始")
    
    # 全テンプレート生成
    generated_files = generate_all_csv_templates()
    
    print("生成完了:")
    for name, path in generated_files.items():
        print(f"  - {name}: {path}")