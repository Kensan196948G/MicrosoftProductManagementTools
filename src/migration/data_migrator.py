"""
Microsoft 365管理ツール データ移行システム
=====================================

PowerShell CSV/JSON → PostgreSQL データベース移行
- 26機能完全対応データ移行
- PowerShellテンプレート/サンプル互換性維持
- バッチ処理・大容量データ対応
- データ検証・品質保証機能
"""

import os
import json
import csv
import logging
import asyncio
import pandas as pd
from datetime import datetime, date
from decimal import Decimal
from typing import List, Dict, Any, Optional, Union, Tuple
from pathlib import Path
import aiofiles

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, insert, update, delete, text
from sqlalchemy.exc import IntegrityError, DataError

# 自作モジュールインポート
from ..database.connection import get_migration_session, BatchProcessor
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
    OneDriveExternalSharing,
    
    # メタデータ
    ReportMetadata, DataQualityLog
)

logger = logging.getLogger(__name__)


class PowerShellDataMigrator:
    """PowerShell CSV/JSONデータ移行管理クラス"""
    
    # PowerShell機能とデータベースモデルのマッピング
    FUNCTION_MODEL_MAPPING = {
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
    
    def __init__(self, 
                 reports_base_path: str = "/mnt/e/MicrosoftProductManagementTools/Reports",
                 templates_path: str = "/mnt/e/MicrosoftProductManagementTools/Templates",
                 batch_size: int = 1000):
        """
        データ移行ツール初期化
        
        Args:
            reports_base_path: PowerShellレポート出力ベースパス
            templates_path: PowerShellテンプレート・サンプルパス  
            batch_size: バッチ処理サイズ
        """
        self.reports_base_path = Path(reports_base_path)
        self.templates_path = Path(templates_path)
        self.batch_size = batch_size
        self.batch_processor = BatchProcessor(batch_size)
        
        # データ変換ルール
        self.data_conversion_rules = self._initialize_conversion_rules()
        
        # 統計情報
        self.migration_stats = {
            "processed_files": 0,
            "processed_records": 0,
            "successful_records": 0,
            "failed_records": 0,
            "warnings": 0,
            "start_time": None,
            "end_time": None
        }
    
    def _initialize_conversion_rules(self) -> Dict[str, Dict[str, Any]]:
        """データ変換ルール初期化"""
        return {
            # 日付変換ルール（PowerShell形式 → Python）
            "date_formats": [
                "%Y-%m-%d %H:%M:%S",      # PowerShell標準形式
                "%Y/%m/%d %H:%M:%S",      # 日本語形式
                "%m/%d/%Y %H:%M:%S",      # US形式
                "%Y-%m-%dT%H:%M:%S",      # ISO形式
                "%Y-%m-%d",               # 日付のみ
                "%Y/%m/%d",               # 日本語日付のみ
            ],
            
            # ブール値変換（PowerShell → Python）
            "boolean_mapping": {
                "True": True, "False": False,
                "true": True, "false": False,
                "$true": True, "$false": False,
                "Yes": True, "No": False,
                "はい": True, "いいえ": False,
                "有効": True, "無効": False,
                "1": True, "0": False
            },
            
            # ステータス正規化
            "status_normalization": {
                "Active": "アクティブ", "Inactive": "非アクティブ", 
                "Enabled": "有効", "Disabled": "無効",
                "Success": "成功", "Failed": "失敗", "Error": "エラー",
                "High": "高", "Medium": "中", "Low": "低",
                "Good": "良好", "Poor": "要改善", "Excellent": "優秀"
            }
        }
    
    async def migrate_all_powershell_data(self) -> Dict[str, Any]:
        """全PowerShellデータの一括移行"""
        logger.info("PowerShell全データ移行開始")
        self.migration_stats["start_time"] = datetime.utcnow()
        
        try:
            # レポートディレクトリスキャン
            migration_results = {}
            
            for function_name, model_class in self.FUNCTION_MODEL_MAPPING.items():
                logger.info(f"機能 '{function_name}' の移行開始")
                
                try:
                    result = await self.migrate_function_data(function_name, model_class)
                    migration_results[function_name] = result
                    
                except Exception as e:
                    logger.error(f"機能 '{function_name}' の移行エラー: {e}")
                    migration_results[function_name] = {
                        "status": "error",
                        "error": str(e),
                        "processed_records": 0
                    }
            
            self.migration_stats["end_time"] = datetime.utcnow()
            
            # 移行統計レポート生成
            await self._generate_migration_report(migration_results)
            
            return {
                "status": "completed",
                "migration_results": migration_results,
                "statistics": self.migration_stats,
                "duration_seconds": (self.migration_stats["end_time"] - 
                                   self.migration_stats["start_time"]).total_seconds()
            }
            
        except Exception as e:
            logger.error(f"データ移行全体エラー: {e}")
            self.migration_stats["end_time"] = datetime.utcnow()
            return {
                "status": "failed",
                "error": str(e),
                "statistics": self.migration_stats
            }
    
    async def migrate_function_data(self, function_name: str, model_class) -> Dict[str, Any]:
        """個別機能データの移行"""
        
        # PowerShellデータファイル検索
        data_files = await self._find_powershell_data_files(function_name)
        
        if not data_files:
            logger.warning(f"機能 '{function_name}' のデータファイルが見つかりません")
            return {
                "status": "no_data",
                "processed_records": 0,
                "message": "データファイルなし"
            }
        
        processed_records = 0
        successful_records = 0
        failed_records = 0
        
        async with get_migration_session() as session:
            for file_path in data_files:
                try:
                    logger.info(f"ファイル処理開始: {file_path}")
                    
                    # ファイル形式に応じてデータ読み込み
                    if file_path.suffix.lower() == '.csv':
                        data_records = await self._load_csv_data(file_path)
                    elif file_path.suffix.lower() == '.json':
                        data_records = await self._load_json_data(file_path)
                    else:
                        logger.warning(f"サポートされていないファイル形式: {file_path}")
                        continue
                    
                    if not data_records:
                        continue
                    
                    # データ変換・検証
                    converted_records = []
                    for record in data_records:
                        try:
                            converted_record = await self._convert_record_to_model(
                                record, model_class, function_name
                            )
                            if converted_record:
                                converted_records.append(converted_record)
                                successful_records += 1
                        except Exception as e:
                            logger.warning(f"レコード変換エラー: {e} - データ: {record}")
                            failed_records += 1
                            
                            # データ品質ログ記録
                            await self._log_data_quality_issue(
                                session, model_class.__tablename__, 
                                "レコード変換エラー", str(e)
                            )
                    
                    # バッチ処理でデータベース挿入
                    if converted_records:
                        await self.batch_processor.process_batch(
                            session, converted_records, model_class, "update"
                        )
                    
                    processed_records += len(data_records)
                    self.migration_stats["processed_files"] += 1
                    
                except Exception as e:
                    logger.error(f"ファイル処理エラー {file_path}: {e}")
                    failed_records += len(data_records) if 'data_records' in locals() else 0
        
        # 機能別移行統計更新
        self.migration_stats["processed_records"] += processed_records
        self.migration_stats["successful_records"] += successful_records
        self.migration_stats["failed_records"] += failed_records
        
        return {
            "status": "completed",
            "processed_files": len(data_files),
            "processed_records": processed_records,
            "successful_records": successful_records,
            "failed_records": failed_records,
            "success_rate": (successful_records / processed_records * 100) if processed_records > 0 else 0
        }
    
    async def _find_powershell_data_files(self, function_name: str) -> List[Path]:
        """PowerShellデータファイル検索"""
        data_files = []
        
        # レポートディレクトリ検索パターン
        search_patterns = [
            f"**/Daily/*{function_name}*.csv",
            f"**/Weekly/*{function_name}*.csv", 
            f"**/Monthly/*{function_name}*.csv",
            f"**/Yearly/*{function_name}*.csv",
            f"**/Analysis/**/*{function_name}*.csv",
            f"**/EntraID/*{function_name}*.csv",
            f"**/Exchange/*{function_name}*.csv",
            f"**/Teams/*{function_name}*.csv",
            f"**/OneDrive/*{function_name}*.csv",
            # JSON形式も対応
            f"**/*{function_name}*.json",
        ]
        
        for pattern in search_patterns:
            for file_path in self.reports_base_path.glob(pattern):
                if file_path.is_file():
                    data_files.append(file_path)
        
        # Templatesディレクトリからサンプルデータ検索
        templates_patterns = [
            f"**/Samples/**/*{function_name}*.csv",
            f"**/*{function_name}*.csv"
        ]
        
        for pattern in templates_patterns:
            for file_path in self.templates_path.glob(pattern):
                if file_path.is_file():
                    data_files.append(file_path)
        
        return list(set(data_files))  # 重複除去
    
    async def _load_csv_data(self, file_path: Path) -> List[Dict[str, Any]]:
        """CSV データ読み込み（PowerShell互換）"""
        try:
            # PowerShell CSV特有の文字エンコーディング対応
            encodings = ['utf-8-sig', 'utf-8', 'cp932', 'shift-jis']
            
            for encoding in encodings:
                try:
                    async with aiofiles.open(file_path, 'r', encoding=encoding) as f:
                        content = await f.read()
                        
                    # pandas でCSV解析（PowerShellの特殊文字対応）
                    import io
                    df = pd.read_csv(io.StringIO(content), 
                                   na_values=['', 'NULL', 'null', '$null'],
                                   keep_default_na=False)
                    
                    # DataFrameを辞書リストに変換
                    return df.to_dict('records')
                    
                except UnicodeDecodeError:
                    continue
                    
            raise ValueError(f"サポートされていない文字エンコーディング: {file_path}")
            
        except Exception as e:
            logger.error(f"CSV読み込みエラー {file_path}: {e}")
            return []
    
    async def _load_json_data(self, file_path: Path) -> List[Dict[str, Any]]:
        """JSON データ読み込み"""
        try:
            async with aiofiles.open(file_path, 'r', encoding='utf-8') as f:
                content = await f.read()
                
            data = json.loads(content)
            
            # JSON構造に応じてリスト形式に変換
            if isinstance(data, list):
                return data
            elif isinstance(data, dict):
                # PowerShell形式のJSONレスポンス対応
                if 'data' in data:
                    return data['data'] if isinstance(data['data'], list) else [data['data']]
                elif 'results' in data:
                    return data['results'] if isinstance(data['results'], list) else [data['results']]
                else:
                    return [data]  # 単一オブジェクトの場合
            else:
                return []
                
        except Exception as e:
            logger.error(f"JSON読み込みエラー {file_path}: {e}")
            return []
    
    async def _convert_record_to_model(self, 
                                     record: Dict[str, Any], 
                                     model_class, 
                                     function_name: str) -> Optional[Dict[str, Any]]:
        """レコードをデータベースモデル形式に変換"""
        
        try:
            converted_record = {}
            
            # モデルのカラム定義取得
            table_columns = model_class.__table__.columns
            
            for column in table_columns:
                column_name = column.name
                
                # PowerShell → Pythonフィールド名マッピング
                powershell_field = self._map_powershell_field_name(column_name, record.keys())
                
                if powershell_field and powershell_field in record:
                    raw_value = record[powershell_field]
                    
                    # データ型に応じて変換
                    converted_value = await self._convert_value_by_type(
                        raw_value, column.type, column_name
                    )
                    
                    if converted_value is not None:
                        converted_record[column_name] = converted_value
                
                elif hasattr(column, 'default') and column.default is not None:
                    # デフォルト値設定
                    if callable(column.default.arg):
                        converted_record[column_name] = column.default.arg()
                    else:
                        converted_record[column_name] = column.default.arg
            
            # 機能固有の変換処理
            converted_record = await self._apply_function_specific_conversion(
                converted_record, function_name, record
            )
            
            return converted_record
            
        except Exception as e:
            logger.error(f"レコード変換エラー: {e} - 元データ: {record}")
            return None
    
    def _map_powershell_field_name(self, 
                                  db_field_name: str, 
                                  powershell_fields: List[str]) -> Optional[str]:
        """PowerShellフィールド名 → データベースフィールド名マッピング"""
        
        # 一般的なマッピング規則
        mapping_patterns = {
            # 基本パターン
            db_field_name: db_field_name,
            db_field_name.replace('_', ' ').title(): db_field_name,
            db_field_name.replace('_', '').lower(): db_field_name,
            
            # PowerShell特有パターン  
            'user_name': ['UserName', 'User Name', 'DisplayName', 'Name'],
            'user_principal_name': ['UserPrincipalName', 'UPN', 'Email'],
            'created_at': ['CreatedDateTime', 'CreationTime', 'Created'],
            'updated_at': ['LastModifiedDateTime', 'Modified', 'Updated'],
            'report_date': ['ReportDate', 'Date', 'Timestamp'],
            
            # Microsoft 365固有マッピング
            'total_size_mb': ['TotalItemSize', 'TotalSize', 'Size'],
            'usage_percent': ['UsagePercent', 'Usage %', '使用率'],
            'license_type': ['LicenseType', 'SKU', 'Product'],
            'mfa_status': ['MFAStatus', 'MFA Status', 'Multi-Factor Authentication'],
        }
        
        # 直接マッピング確認
        if db_field_name in powershell_fields:
            return db_field_name
        
        # パターンマッピング確認
        if db_field_name in mapping_patterns:
            candidates = mapping_patterns[db_field_name]
            if isinstance(candidates, str):
                candidates = [candidates]
                
            for candidate in candidates:
                if candidate in powershell_fields:
                    return candidate
        
        # 類似性検索（部分一致）
        for field in powershell_fields:
            if (db_field_name.lower() in field.lower() or 
                field.lower() in db_field_name.lower()):
                return field
        
        return None
    
    async def _convert_value_by_type(self, 
                                   raw_value: Any, 
                                   column_type, 
                                   column_name: str) -> Any:
        """データ型に応じた値変換"""
        
        if raw_value is None or raw_value == '' or str(raw_value).strip() == '':
            return None
        
        try:
            # 文字列型
            if hasattr(column_type, 'python_type') and column_type.python_type == str:
                value_str = str(raw_value).strip()
                
                # ステータス正規化
                if column_name in ['status', 'mfa_status', 'risk_level']:
                    return self.data_conversion_rules["status_normalization"].get(
                        value_str, value_str
                    )
                
                return value_str
            
            # 整数型
            elif hasattr(column_type, 'python_type') and column_type.python_type == int:
                if isinstance(raw_value, str):
                    # PowerShell数値文字列処理
                    clean_value = raw_value.replace(',', '').replace('%', '')
                    return int(float(clean_value))
                return int(raw_value)
            
            # Decimal型  
            elif str(column_type).startswith('DECIMAL'):
                if isinstance(raw_value, str):
                    clean_value = raw_value.replace(',', '').replace('%', '').replace('¥', '')
                    return Decimal(clean_value)
                return Decimal(str(raw_value))
            
            # Boolean型
            elif hasattr(column_type, 'python_type') and column_type.python_type == bool:
                if isinstance(raw_value, str):
                    return self.data_conversion_rules["boolean_mapping"].get(
                        raw_value, bool(raw_value)
                    )
                return bool(raw_value)
            
            # 日付・時刻型
            elif str(column_type).startswith('DATETIME'):
                return await self._parse_datetime(raw_value)
            
            elif str(column_type).startswith('DATE'):
                dt = await self._parse_datetime(raw_value)
                return dt.date() if dt else None
            
            # その他はそのまま返す
            else:
                return raw_value
                
        except Exception as e:
            logger.warning(f"値変換エラー {column_name}: {raw_value} -> {e}")
            return None
    
    async def _parse_datetime(self, value: Any) -> Optional[datetime]:
        """日時解析（PowerShell形式対応）"""
        
        if not value:
            return None
        
        value_str = str(value).strip()
        if not value_str:
            return None
        
        # 各フォーマットで解析試行
        for date_format in self.data_conversion_rules["date_formats"]:
            try:
                return datetime.strptime(value_str, date_format)
            except ValueError:
                continue
        
        # pandas日時解析試行（柔軟性向上）
        try:
            return pd.to_datetime(value_str).to_pydatetime()
        except:
            logger.warning(f"日時解析失敗: {value_str}")
            return None
    
    async def _apply_function_specific_conversion(self, 
                                                converted_record: Dict[str, Any], 
                                                function_name: str,
                                                original_record: Dict[str, Any]) -> Dict[str, Any]:
        """機能固有の変換処理"""
        
        # 定期レポート用変換
        if function_name in ['weekly', 'monthly', 'yearly']:
            converted_record['report_type'] = function_name.replace('ly', '次')
        
        # ユーザー関連データの統合
        if function_name in ['users', 'mfa', 'signin_logs']:
            if 'user_principal_name' not in converted_record and 'email' in original_record:
                converted_record['user_principal_name'] = original_record['email']
        
        # ライセンス分析特有処理
        if function_name == 'license':
            if 'utilization_rate' in converted_record and isinstance(converted_record['utilization_rate'], str):
                rate_str = converted_record['utilization_rate'].replace('%', '')
                try:
                    converted_record['utilization_rate'] = Decimal(rate_str)
                except:
                    pass
        
        # Teams使用状況の活動スコア計算
        if function_name == 'teams_usage':
            if all(key in converted_record for key in ['chat_messages_count', 'meetings_organized', 'calls_count']):
                score = (converted_record['chat_messages_count'] * 0.3 + 
                        converted_record['meetings_organized'] * 0.4 +
                        converted_record['calls_count'] * 0.3)
                converted_record['activity_score'] = Decimal(str(round(score, 2)))
        
        return converted_record
    
    async def _log_data_quality_issue(self, 
                                    session: AsyncSession,
                                    table_name: str,
                                    validation_type: str, 
                                    error_details: str):
        """データ品質問題ログ記録"""
        
        try:
            quality_log = DataQualityLog(
                table_name=table_name,
                validation_type=validation_type,
                validation_status="エラー",
                error_details=error_details,
                affected_records=1,
                validated_at=datetime.utcnow()
            )
            
            session.add(quality_log)
            await session.commit()
            
        except Exception as e:
            logger.error(f"品質ログ記録エラー: {e}")
    
    async def _generate_migration_report(self, migration_results: Dict[str, Any]):
        """移行統計レポート生成"""
        
        try:
            report_data = {
                "migration_summary": {
                    "total_functions": len(migration_results),
                    "successful_functions": len([r for r in migration_results.values() 
                                                if r.get("status") == "completed"]),
                    "failed_functions": len([r for r in migration_results.values() 
                                           if r.get("status") == "error"]),
                    "total_processed_records": self.migration_stats["processed_records"],
                    "successful_records": self.migration_stats["successful_records"],
                    "failed_records": self.migration_stats["failed_records"],
                    "overall_success_rate": (self.migration_stats["successful_records"] / 
                                           self.migration_stats["processed_records"] * 100) 
                                           if self.migration_stats["processed_records"] > 0 else 0
                },
                "function_details": migration_results,
                "execution_info": {
                    "start_time": self.migration_stats["start_time"].isoformat(),
                    "end_time": self.migration_stats["end_time"].isoformat(),
                    "duration_minutes": ((self.migration_stats["end_time"] - 
                                        self.migration_stats["start_time"]).total_seconds() / 60)
                }
            }
            
            # レポートファイル出力
            report_filename = f"data_migration_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            report_path = self.reports_base_path / "migration" / report_filename
            
            os.makedirs(report_path.parent, exist_ok=True)
            
            async with aiofiles.open(report_path, 'w', encoding='utf-8') as f:
                await f.write(json.dumps(report_data, ensure_ascii=False, indent=2, default=str))
            
            logger.info(f"移行レポート生成完了: {report_path}")
            
        except Exception as e:
            logger.error(f"移行レポート生成エラー: {e}")


# 便利関数
async def migrate_specific_function(function_name: str, 
                                  reports_path: Optional[str] = None) -> Dict[str, Any]:
    """特定機能のデータ移行実行"""
    
    migrator = PowerShellDataMigrator(reports_base_path=reports_path or 
                                    "/mnt/e/MicrosoftProductManagementTools/Reports")
    
    if function_name not in migrator.FUNCTION_MODEL_MAPPING:
        raise ValueError(f"サポートされていない機能名: {function_name}")
    
    model_class = migrator.FUNCTION_MODEL_MAPPING[function_name]
    return await migrator.migrate_function_data(function_name, model_class)


async def migrate_all_data(reports_path: Optional[str] = None) -> Dict[str, Any]:
    """全データ移行実行（便利関数）"""
    
    migrator = PowerShellDataMigrator(reports_base_path=reports_path or 
                                    "/mnt/e/MicrosoftProductManagementTools/Reports")
    
    return await migrator.migrate_all_powershell_data()


if __name__ == "__main__":
    # テスト実行
    async def test_migration():
        logger.info("データ移行テスト開始")
        
        # 特定機能のテスト移行
        result = await migrate_specific_function("users")
        print(f"ユーザー移行結果: {result}")
        
        # 全データ移行テスト
        # full_result = await migrate_all_data()
        # print(f"全移行結果: {full_result}")
    
    asyncio.run(test_migration())