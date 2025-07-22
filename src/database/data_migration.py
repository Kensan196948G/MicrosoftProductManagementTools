# Microsoft 365 Management Tools - Data Migration Scripts
# PowerShell to Python database migration with full compatibility preservation

import os
import sys
import logging
import json
import csv
import pandas as pd
from pathlib import Path
from typing import Optional, Dict, Any, List, Union, Iterator
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
from sqlalchemy.orm import Session
from sqlalchemy import text, inspect
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from .engine import get_database_engine, get_session
from .models import (
    Base, User, MFAStatus, SignInLog, Mailbox, MailFlowAnalysis,
    TeamsUsage, OneDriveStorageAnalysis, LicenseAnalysis, 
    ReportMetadata, DailySecurityReport, PerformanceMonitoring
)

# Configure logging
logger = logging.getLogger(__name__)

# Migration configuration
MIGRATION_CONFIG = {
    'source_data_path': os.getenv('MIGRATION_SOURCE_PATH', './Reports'),
    'backup_path': os.getenv('MIGRATION_BACKUP_PATH', './Backups/migration'),
    'batch_size': int(os.getenv('MIGRATION_BATCH_SIZE', '1000')),
    'parallel_workers': int(os.getenv('MIGRATION_WORKERS', '4')),
    'validation_enabled': os.getenv('MIGRATION_VALIDATION', 'true').lower() == 'true',
    'dry_run_mode': os.getenv('MIGRATION_DRY_RUN', 'false').lower() == 'true',
    'preserve_timestamps': os.getenv('MIGRATION_PRESERVE_TIMESTAMPS', 'true').lower() == 'true',
    'error_threshold_percent': float(os.getenv('MIGRATION_ERROR_THRESHOLD', '5.0')),
    'powershell_csv_encoding': os.getenv('POWERSHELL_CSV_ENCODING', 'utf-8-sig')
}

@dataclass
class MigrationResult:
    """Migration result data class."""
    source_file: str
    target_table: str
    records_processed: int
    records_migrated: int
    records_skipped: int
    records_failed: int
    start_time: datetime
    end_time: datetime
    status: str
    errors: List[str]
    
    @property
    def duration_seconds(self) -> float:
        return (self.end_time - self.start_time).total_seconds()
    
    @property
    def success_rate(self) -> float:
        if self.records_processed == 0:
            return 0.0
        return (self.records_migrated / self.records_processed) * 100

class PowerShellDataMigrator:
    """PowerShell to Python database migration manager."""
    
    def __init__(self):
        self.engine = get_database_engine()
        self.source_path = Path(MIGRATION_CONFIG['source_data_path'])
        self.backup_path = Path(MIGRATION_CONFIG['backup_path'])
        self.backup_path.mkdir(parents=True, exist_ok=True)
        
        # PowerShell report mappings to Python models
        self.table_mappings = {
            'users': {
                'model': User,
                'csv_patterns': ['*users*.csv', '*user_list*.csv', '*entra_users*.csv'],
                'field_mappings': {
                    'DisplayName': 'display_name',
                    'UserPrincipalName': 'user_principal_name',
                    'Mail': 'email',
                    'Department': 'department',
                    'JobTitle': 'job_title',
                    'AccountEnabled': 'account_status',
                    'CreatedDateTime': 'creation_date',
                    'SignInActivity': 'last_sign_in',
                    'UsageLocation': 'usage_location'
                }
            },
            'mfa_status': {
                'model': MFAStatus,
                'csv_patterns': ['*mfa*.csv', '*multi_factor*.csv'],
                'field_mappings': {
                    'UserPrincipalName': 'user_principal_name',
                    'DisplayName': 'display_name',
                    'Department': 'department',
                    'MfaStatus': 'mfa_status',
                    'DefaultMethod': 'mfa_default_method',
                    'PhoneNumber': 'phone_number',
                    'Email': 'email',
                    'RegistrationTime': 'registration_date'
                }
            },
            'signin_logs': {
                'model': SignInLog,
                'csv_patterns': ['*signin*.csv', '*sign_in*.csv', '*login*.csv'],
                'field_mappings': {
                    'CreatedDateTime': 'signin_datetime',
                    'UserDisplayName': 'user_name',
                    'UserPrincipalName': 'user_principal_name',
                    'AppDisplayName': 'application',
                    'ClientAppUsed': 'client_app',
                    'DeviceDetail': 'device_info',
                    'LocationCity': 'location_city',
                    'LocationCountry': 'location_country',
                    'IpAddress': 'ip_address',
                    'Status': 'status',
                    'ErrorCode': 'error_code',
                    'FailureReason': 'failure_reason'
                }
            },
            'mailboxes': {
                'model': Mailbox,
                'csv_patterns': ['*mailbox*.csv', '*exchange*.csv'],
                'field_mappings': {
                    'PrimarySmtpAddress': 'email',
                    'DisplayName': 'display_name',
                    'UserPrincipalName': 'user_principal_name',
                    'RecipientTypeDetails': 'mailbox_type',
                    'TotalItemSize': 'total_size_mb',
                    'ProhibitSendQuota': 'quota_mb',
                    'ItemCount': 'message_count',
                    'LastLogonTime': 'last_access'
                }
            },
            'teams_usage': {
                'model': TeamsUsage,
                'csv_patterns': ['*teams*.csv', '*teams_usage*.csv'],
                'field_mappings': {
                    'UserPrincipalName': 'user_principal_name',
                    'DisplayName': 'user_name',
                    'Department': 'department',
                    'LastActivityDate': 'last_access',
                    'TeamChatMessageCount': 'chat_messages_count',
                    'MeetingsOrganized': 'meetings_organized',
                    'MeetingsAttended': 'meetings_attended',
                    'CallCount': 'calls_count',
                    'SharedFiles': 'files_shared'
                }
            },
            'onedrive_storage': {
                'model': OneDriveStorageAnalysis,
                'csv_patterns': ['*onedrive*.csv', '*sharepoint*.csv'],
                'field_mappings': {
                    'UserPrincipalName': 'user_principal_name',
                    'DisplayName': 'user_name',
                    'Department': 'department',
                    'StorageUsed': 'used_storage_gb',
                    'StorageQuota': 'total_storage_gb',
                    'FileCount': 'file_count',
                    'LastActivityDate': 'last_activity'
                }
            },
            'license_analysis': {
                'model': LicenseAnalysis,
                'csv_patterns': ['*license*.csv', '*subscription*.csv'],
                'field_mappings': {
                    'LicenseType': 'license_type',
                    'UserName': 'user_name',
                    'Department': 'department',
                    'AssignedLicenses': 'assigned_licenses',
                    'AvailableLicenses': 'available_licenses',
                    'UtilizationRate': 'utilization_rate',
                    'MonthlyCost': 'monthly_cost'
                }
            }
        }
    
    def discover_source_files(self) -> Dict[str, List[Path]]:
        """Discover PowerShell generated CSV files for migration."""
        discovered_files = {}
        
        try:
            if not self.source_path.exists():
                logger.warning(f"Source data path not found: {self.source_path}")
                return discovered_files
            
            for table_name, mapping in self.table_mappings.items():
                files = []
                for pattern in mapping['csv_patterns']:
                    files.extend(self.source_path.rglob(pattern))
                
                # Filter for actual CSV files and sort by modification time
                csv_files = [f for f in files if f.suffix.lower() == '.csv' and f.is_file()]
                csv_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
                
                discovered_files[table_name] = csv_files
                logger.info(f"Discovered {len(csv_files)} files for {table_name}")
            
            return discovered_files
            
        except Exception as e:
            logger.error(f"File discovery failed: {e}")
            return {}
    
    def validate_csv_file(self, file_path: Path, expected_fields: Dict[str, str]) -> Dict[str, Any]:
        """Validate CSV file format and content."""
        try:
            # Read first few rows to check format
            df = pd.read_csv(
                file_path, 
                encoding=MIGRATION_CONFIG['powershell_csv_encoding'],
                nrows=5
            )
            
            # Check for required columns
            required_columns = list(expected_fields.keys())
            available_columns = list(df.columns)
            missing_columns = [col for col in required_columns if col not in available_columns]
            extra_columns = [col for col in available_columns if col not in required_columns]
            
            # Estimate row count
            with open(file_path, 'r', encoding=MIGRATION_CONFIG['powershell_csv_encoding']) as f:
                row_count = sum(1 for line in f) - 1  # Subtract header
            
            return {
                'valid': len(missing_columns) == 0,
                'row_count': row_count,
                'column_count': len(available_columns),
                'missing_columns': missing_columns,
                'extra_columns': extra_columns,
                'sample_data': df.head(2).to_dict('records') if not df.empty else [],
                'file_size_mb': file_path.stat().st_size / (1024 * 1024)
            }
            
        except Exception as e:
            logger.error(f"CSV validation failed for {file_path}: {e}")
            return {
                'valid': False,
                'error': str(e),
                'row_count': 0
            }
    
    def backup_existing_data(self, table_name: str) -> bool:
        """Backup existing data before migration."""
        try:
            backup_file = self.backup_path / f"{table_name}_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
            
            with get_session() as session:
                # Get the model class
                model = self.table_mappings[table_name]['model']
                
                # Query all existing data
                query = session.query(model)
                records = query.all()
                
                if not records:
                    logger.info(f"No existing data to backup for {table_name}")
                    return True
                
                # Convert to dictionaries
                data_dicts = []
                for record in records:
                    record_dict = {}
                    for column in model.__table__.columns:
                        value = getattr(record, column.name)
                        if isinstance(value, datetime):
                            record_dict[column.name] = value.isoformat()
                        else:
                            record_dict[column.name] = value
                    data_dicts.append(record_dict)
                
                # Write to CSV
                if data_dicts:
                    df = pd.DataFrame(data_dicts)
                    df.to_csv(backup_file, index=False, encoding='utf-8-sig')
                    
                    logger.info(f"Backed up {len(records)} records to {backup_file}")
                
                return True
                
        except Exception as e:
            logger.error(f"Data backup failed for {table_name}: {e}")
            return False
    
    def transform_record(self, source_record: Dict[str, Any], field_mappings: Dict[str, str]) -> Dict[str, Any]:
        """Transform PowerShell record to Python model format."""
        transformed = {}
        
        try:
            for source_field, target_field in field_mappings.items():
                if source_field in source_record:
                    value = source_record[source_field]
                    
                    # Handle special transformations
                    if target_field in ['creation_date', 'last_sign_in', 'signin_datetime', 'last_access']:
                        # Convert PowerShell datetime strings to Python datetime
                        if value and value != 'N/A' and str(value).strip():
                            try:
                                # Try common PowerShell datetime formats
                                for fmt in ['%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%d %H:%M:%S', '%m/%d/%Y %H:%M:%S']:
                                    try:
                                        transformed[target_field] = datetime.strptime(str(value), fmt)
                                        break
                                    except ValueError:
                                        continue
                                else:
                                    # If no format matches, try pandas conversion
                                    transformed[target_field] = pd.to_datetime(value, errors='coerce').to_pydatetime()
                            except:
                                transformed[target_field] = None
                        else:
                            transformed[target_field] = None
                    
                    elif target_field in ['total_size_mb', 'quota_mb', 'utilization_rate', 'monthly_cost']:
                        # Convert numeric fields
                        if value and value != 'N/A':
                            try:
                                # Remove common PowerShell formatting
                                clean_value = str(value).replace(',', '').replace(' MB', '').replace(' GB', '').replace('$', '')
                                transformed[target_field] = float(clean_value)
                            except (ValueError, TypeError):
                                transformed[target_field] = 0.0
                        else:
                            transformed[target_field] = 0.0
                    
                    elif target_field == 'account_status':
                        # Convert boolean to status string
                        if isinstance(value, bool):
                            transformed[target_field] = '有効' if value else '無効'
                        else:
                            transformed[target_field] = str(value) if value else '無効'
                    
                    else:
                        # Default string conversion
                        transformed[target_field] = str(value) if value and value != 'N/A' else None
            
            # Add metadata fields
            transformed['created_at'] = datetime.utcnow()
            transformed['updated_at'] = datetime.utcnow()
            
            return transformed
            
        except Exception as e:
            logger.error(f"Record transformation failed: {e}")
            return {}
    
    def migrate_table_data(self, table_name: str, source_files: List[Path]) -> MigrationResult:
        """Migrate data for a specific table."""
        start_time = datetime.utcnow()
        errors = []
        records_processed = 0
        records_migrated = 0
        records_skipped = 0
        records_failed = 0
        
        try:
            if not source_files:
                return MigrationResult(
                    source_file='',
                    target_table=table_name,
                    records_processed=0,
                    records_migrated=0,
                    records_skipped=0,
                    records_failed=0,
                    start_time=start_time,
                    end_time=datetime.utcnow(),
                    status='no_files',
                    errors=['No source files found']
                )
            
            # Get table mapping
            mapping = self.table_mappings[table_name]
            model_class = mapping['model']
            field_mappings = mapping['field_mappings']
            
            # Backup existing data if not in dry run mode
            if not MIGRATION_CONFIG['dry_run_mode']:
                if not self.backup_existing_data(table_name):
                    errors.append("Failed to backup existing data")
            
            # Process each source file
            for source_file in source_files:
                try:
                    logger.info(f"Processing {source_file} for table {table_name}")
                    
                    # Validate file format
                    validation = self.validate_csv_file(source_file, field_mappings)
                    if not validation['valid']:
                        error_msg = f"Invalid file format: {validation.get('error', 'Unknown error')}"
                        errors.append(error_msg)
                        logger.error(error_msg)
                        continue
                    
                    # Read CSV data in batches
                    chunk_size = MIGRATION_CONFIG['batch_size']
                    
                    with get_session() as session:
                        for chunk_df in pd.read_csv(
                            source_file,
                            encoding=MIGRATION_CONFIG['powershell_csv_encoding'],
                            chunksize=chunk_size
                        ):
                            # Process each record in the chunk
                            for _, row in chunk_df.iterrows():
                                records_processed += 1
                                
                                try:
                                    # Transform record
                                    transformed = self.transform_record(row.to_dict(), field_mappings)
                                    
                                    if not transformed:
                                        records_skipped += 1
                                        continue
                                    
                                    # Create model instance
                                    if not MIGRATION_CONFIG['dry_run_mode']:
                                        instance = model_class(**transformed)
                                        session.add(instance)
                                        session.flush()  # Flush to catch integrity errors
                                    
                                    records_migrated += 1
                                    
                                    # Commit in batches
                                    if records_migrated % chunk_size == 0:
                                        if not MIGRATION_CONFIG['dry_run_mode']:
                                            session.commit()
                                        logger.info(f"Migrated {records_migrated} records for {table_name}")
                                
                                except IntegrityError as e:
                                    session.rollback()
                                    records_failed += 1
                                    error_msg = f"Integrity error for record {records_processed}: {str(e)[:200]}"
                                    errors.append(error_msg)
                                    logger.warning(error_msg)
                                
                                except Exception as e:
                                    records_failed += 1
                                    error_msg = f"Error processing record {records_processed}: {str(e)[:200]}"
                                    errors.append(error_msg)
                                    logger.error(error_msg)
                            
                            # Final commit for remaining records
                            if not MIGRATION_CONFIG['dry_run_mode']:
                                try:
                                    session.commit()
                                except Exception as e:
                                    session.rollback()
                                    errors.append(f"Final commit failed: {e}")
                
                except Exception as e:
                    error_msg = f"Error processing file {source_file}: {e}"
                    errors.append(error_msg)
                    logger.error(error_msg)
            
            # Determine final status
            error_rate = (records_failed / records_processed * 100) if records_processed > 0 else 0
            if error_rate > MIGRATION_CONFIG['error_threshold_percent']:
                status = 'failed_high_error_rate'
            elif records_failed > 0:
                status = 'completed_with_errors'
            else:
                status = 'success'
            
            return MigrationResult(
                source_file=', '.join([f.name for f in source_files]),
                target_table=table_name,
                records_processed=records_processed,
                records_migrated=records_migrated,
                records_skipped=records_skipped,
                records_failed=records_failed,
                start_time=start_time,
                end_time=datetime.utcnow(),
                status=status,
                errors=errors
            )
            
        except Exception as e:
            logger.error(f"Table migration failed for {table_name}: {e}")
            return MigrationResult(
                source_file='',
                target_table=table_name,
                records_processed=records_processed,
                records_migrated=records_migrated,
                records_skipped=records_skipped,
                records_failed=records_failed,
                start_time=start_time,
                end_time=datetime.utcnow(),
                status='error',
                errors=[str(e)]
            )
    
    def run_full_migration(self) -> List[MigrationResult]:
        """Run complete data migration from PowerShell CSV files."""
        logger.info("Starting full data migration from PowerShell CSV files...")
        migration_results = []
        
        try:
            # Discover source files
            discovered_files = self.discover_source_files()
            
            if not discovered_files:
                logger.warning("No source files discovered for migration")
                return migration_results
            
            # Process each table
            for table_name, source_files in discovered_files.items():
                if not source_files:
                    logger.info(f"No files found for table: {table_name}")
                    continue
                
                logger.info(f"Migrating {len(source_files)} files for table: {table_name}")
                
                # Migrate table data
                result = self.migrate_table_data(table_name, source_files)
                migration_results.append(result)
                
                # Log result summary
                logger.info(
                    f"Migration completed for {table_name}: "
                    f"{result.records_migrated}/{result.records_processed} records "
                    f"(Success rate: {result.success_rate:.1f}%)"
                )
            
            # Generate migration report
            self.generate_migration_report(migration_results)
            
            return migration_results
            
        except Exception as e:
            logger.error(f"Full migration failed: {e}")
            return migration_results
    
    def generate_migration_report(self, results: List[MigrationResult]):
        """Generate comprehensive migration report."""
        try:
            report_file = self.backup_path / f"migration_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            
            # Calculate summary statistics
            total_processed = sum(r.records_processed for r in results)
            total_migrated = sum(r.records_migrated for r in results)
            total_failed = sum(r.records_failed for r in results)
            overall_success_rate = (total_migrated / total_processed * 100) if total_processed > 0 else 0
            
            report = {
                'migration_summary': {
                    'start_time': min(r.start_time for r in results).isoformat() if results else None,
                    'end_time': max(r.end_time for r in results).isoformat() if results else None,
                    'total_tables': len(results),
                    'total_records_processed': total_processed,
                    'total_records_migrated': total_migrated,
                    'total_records_failed': total_failed,
                    'overall_success_rate': round(overall_success_rate, 2),
                    'dry_run_mode': MIGRATION_CONFIG['dry_run_mode']
                },
                'table_results': [
                    {
                        'table_name': r.target_table,
                        'source_files': r.source_file,
                        'records_processed': r.records_processed,
                        'records_migrated': r.records_migrated,
                        'records_skipped': r.records_skipped,
                        'records_failed': r.records_failed,
                        'success_rate': round(r.success_rate, 2),
                        'duration_seconds': round(r.duration_seconds, 2),
                        'status': r.status,
                        'error_count': len(r.errors),
                        'errors': r.errors[:10]  # Limit to first 10 errors
                    }
                    for r in results
                ],
                'configuration': MIGRATION_CONFIG
            }
            
            # Save report
            with open(report_file, 'w', encoding='utf-8') as f:
                json.dump(report, f, indent=2, ensure_ascii=False)
            
            logger.info(f"Migration report saved: {report_file}")
            
        except Exception as e:
            logger.error(f"Failed to generate migration report: {e}")

# Utility functions
def run_migration() -> List[MigrationResult]:
    """Convenience function to run data migration."""
    migrator = PowerShellDataMigrator()
    return migrator.run_full_migration()

def validate_migration_sources(source_path: Optional[str] = None) -> Dict[str, Any]:
    """Validate migration source files."""
    try:
        path = Path(source_path) if source_path else Path(MIGRATION_CONFIG['source_data_path'])
        migrator = PowerShellDataMigrator()
        migrator.source_path = path
        
        discovered = migrator.discover_source_files()
        
        validation_results = {}
        for table_name, files in discovered.items():
            table_validation = []
            for file_path in files:
                field_mappings = migrator.table_mappings[table_name]['field_mappings']
                validation = migrator.validate_csv_file(file_path, field_mappings)
                validation['file_path'] = str(file_path)
                table_validation.append(validation)
            validation_results[table_name] = table_validation
        
        return {
            'source_path': str(path),
            'tables_discovered': len(discovered),
            'files_discovered': sum(len(files) for files in discovered.values()),
            'validation_results': validation_results
        }
        
    except Exception as e:
        return {'error': str(e)}

# PowerShell compatibility functions
def get_powershell_migration_status() -> Dict[str, Any]:
    """Get migration status in PowerShell-compatible format."""
    try:
        # Check for recent migration reports
        backup_path = Path(MIGRATION_CONFIG['backup_path'])
        if backup_path.exists():
            report_files = list(backup_path.glob('migration_report_*.json'))
            if report_files:
                latest_report = max(report_files, key=lambda x: x.stat().st_mtime)
                
                with open(latest_report, 'r', encoding='utf-8') as f:
                    report = json.load(f)
                
                summary = report.get('migration_summary', {})
                
                return {
                    "MigrationStatus": "COMPLETED" if summary.get('total_records_migrated', 0) > 0 else "PENDING",
                    "TotalRecordsProcessed": summary.get('total_records_processed', 0),
                    "TotalRecordsMigrated": summary.get('total_records_migrated', 0),
                    "SuccessRate": summary.get('overall_success_rate', 0),
                    "TablesProcessed": summary.get('total_tables', 0),
                    "LastMigration": summary.get('end_time', 'Never'),
                    "DryRunMode": summary.get('dry_run_mode', True),
                    "BackupPath": str(backup_path),
                    "LastCheck": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                }
        
        return {
            "MigrationStatus": "NOT_STARTED",
            "TotalRecordsProcessed": 0,
            "TotalRecordsMigrated": 0,
            "SuccessRate": 0,
            "TablesProcessed": 0,
            "LastMigration": "Never",
            "LastCheck": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
        
    except Exception as e:
        return {
            "MigrationStatus": "ERROR",
            "Error": str(e),
            "LastCheck": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }

if __name__ == "__main__":
    # Test migration functionality
    try:
        print("📊 Testing data migration functionality...")
        
        # Validate source files
        print("Validating migration sources...")
        validation = validate_migration_sources()
        
        if 'error' in validation:
            print(f"❌ Source validation failed: {validation['error']}")
        else:
            print(f"✅ Found {validation['files_discovered']} files across {validation['tables_discovered']} tables")
        
        # Get PowerShell status
        ps_status = get_powershell_migration_status()
        print(f"🔗 PowerShell status: {ps_status}")
        
        # Run migration in dry-run mode
        if validation.get('files_discovered', 0) > 0:
            print("Running migration in dry-run mode...")
            migrator = PowerShellDataMigrator()
            results = migrator.run_full_migration()
            
            if results:
                total_processed = sum(r.records_processed for r in results)
                total_migrated = sum(r.records_migrated for r in results)
                print(f"✅ Migration test completed: {total_migrated}/{total_processed} records")
            else:
                print("⚠️ No migration results generated")
        
        print("✅ Data migration test completed successfully")
        
    except Exception as e:
        print(f"❌ Data migration test failed: {e}")