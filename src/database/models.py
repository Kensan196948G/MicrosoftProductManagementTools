"""
Microsoft 365管理ツール データベースモデル定義
========================================

PowerShell 26機能からPython SQLAlchemy ORM移行用モデル
- 完全なデータ互換性維持
- Microsoft 365 API統合最適化
- PostgreSQL高パフォーマンス対応
"""

from datetime import datetime, date
from decimal import Decimal
from typing import List, Optional, Dict, Any
from uuid import UUID, uuid4
from sqlalchemy import (
    Boolean, Column, Date, DateTime, Decimal as SQLDecimal,
    ForeignKey, Integer, String, Text, UniqueConstraint,
    Index, event, func, text
)
from sqlalchemy.dialects.postgresql import INET, UUID as PGUUID, JSONB
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref
from sqlalchemy.sql import expression

Base = declarative_base()


# ========================================
# 共通ベースモデルクラス
# ========================================
class TimestampMixin:
    """作成・更新日時管理Mixin（PowerShell監査証跡対応）"""
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class ReportBaseMixin(TimestampMixin):
    """レポートベースMixin"""
    id = Column(Integer, primary_key=True)
    report_date = Column(Date, default=func.current_date())


# ========================================
# 1. 定期レポート（5機能）
# ========================================
class DailySecurityReport(ReportBaseMixin, Base):
    """日次セキュリティレポート（PowerShell DailyReport互換）"""
    __tablename__ = 'daily_security_reports'
    
    user_name = Column(String(255), nullable=False, index=True)
    email = Column(String(255), nullable=False, index=True)
    account_creation_date = Column(Date)
    last_password_change = Column(Date)
    days_since_password_change = Column(Integer)
    activity_status = Column(String(50))  # "✗ 長期未更新" など
    security_risk = Column(String(50))    # "⚠️ 高リスク" など
    recommended_action = Column(Text)
    
    __table_args__ = (
        Index('idx_security_report_date_risk', 'report_date', 'security_risk'),
        Index('idx_security_user_email', 'user_name', 'email'),
    )


class PeriodicSummaryReport(ReportBaseMixin, Base):
    """定期サマリーレポート（週次・月次・年次）"""
    __tablename__ = 'periodic_summary_reports'
    
    report_type = Column(String(20), nullable=False)  # "週次", "月次", "年次"
    period_start = Column(Date, nullable=False)
    period_end = Column(Date, nullable=False)
    active_users_count = Column(Integer, default=0)
    total_activity_count = Column(Integer, default=0)
    service_performance_score = Column(SQLDecimal(3,1))
    
    __table_args__ = (
        Index('idx_periodic_report_type_period', 'report_type', 'period_start', 'period_end'),
    )


class TestExecutionResult(ReportBaseMixin, Base):
    """テスト実行結果"""
    __tablename__ = 'test_execution_results'
    
    test_id = Column(String(50), nullable=False, index=True)
    test_name = Column(String(255), nullable=False)
    category = Column(String(100))  # "基本機能" など
    execution_status = Column(String(50))  # "成功", "失敗" など
    result = Column(String(50))
    error_message = Column(Text)
    execution_time_ms = Column(Integer)
    test_date = Column(DateTime, default=datetime.utcnow)


# ========================================
# 2. 分析レポート（5機能）
# ========================================
class LicenseAnalysis(ReportBaseMixin, Base):
    """ライセンス分析"""
    __tablename__ = 'license_analysis'
    
    license_type = Column(String(100), nullable=False, index=True)  # "Microsoft 365 E3" など
    user_name = Column(String(255), index=True)
    department = Column(String(100), index=True)
    total_licenses = Column(Integer, default=0)
    assigned_licenses = Column(Integer, default=0)
    available_licenses = Column(Integer, default=0)
    utilization_rate = Column(SQLDecimal(5,2))  # 利用率パーセント
    monthly_cost = Column(SQLDecimal(10,2))
    expiration_date = Column(Date)
    
    __table_args__ = (
        Index('idx_license_type_dept', 'license_type', 'department'),
    )


class ServiceUsageAnalysis(ReportBaseMixin, Base):
    """サービス使用状況分析"""
    __tablename__ = 'service_usage_analysis'
    
    service_name = Column(String(100), nullable=False, index=True)  # "Exchange Online", "Teams" など
    active_users = Column(Integer, default=0)
    total_users = Column(Integer, default=0)
    adoption_rate = Column(SQLDecimal(5,2))  # 採用率パーセント
    daily_active_users = Column(Integer, default=0)
    weekly_active_users = Column(Integer, default=0)
    monthly_active_users = Column(Integer, default=0)
    trend_direction = Column(String(20))  # "上昇", "下降", "安定"
    
    __table_args__ = (
        Index('idx_service_usage_date', 'service_name', 'report_date'),
    )


class PerformanceMonitoring(TimestampMixin, Base):
    """パフォーマンス監視"""
    __tablename__ = 'performance_monitoring'
    
    id = Column(Integer, primary_key=True)
    timestamp = Column(DateTime, nullable=False, index=True)
    service_name = Column(String(100), nullable=False, index=True)
    response_time_ms = Column(Integer)
    availability_percent = Column(SQLDecimal(5,2))
    throughput_mbps = Column(SQLDecimal(10,2))
    error_rate = Column(SQLDecimal(5,2))
    status = Column(String(20))  # "正常", "警告", "エラー"
    
    __table_args__ = (
        Index('idx_perf_service_timestamp', 'service_name', 'timestamp'),
    )


class SecurityAnalysis(ReportBaseMixin, Base):
    """セキュリティ分析"""
    __tablename__ = 'security_analysis'
    
    security_item = Column(String(100), nullable=False, index=True)  # "MFA有効率" など
    status = Column(String(50))
    target_users = Column(Integer)
    compliance_rate_percent = Column(SQLDecimal(5,2))
    risk_level = Column(String(20), index=True)  # "低", "中", "高"
    last_check_date = Column(DateTime)
    recommended_action = Column(Text)
    details = Column(Text)


class PermissionAudit(ReportBaseMixin, Base):
    """権限監査"""
    __tablename__ = 'permission_audit'
    
    user_name = Column(String(255), nullable=False, index=True)
    email = Column(String(255), nullable=False, index=True)
    department = Column(String(100), index=True)
    admin_role = Column(String(100))
    access_rights = Column(String(100))  # "標準ユーザー", "管理者" など
    last_login = Column(DateTime)
    mfa_status = Column(String(20))  # "有効", "無効"
    status = Column(String(50))  # "適切", "要確認" など
    audit_date = Column(Date, default=func.current_date())


# ========================================
# 3. Entra ID管理（4機能）
# ========================================
class User(TimestampMixin, Base):
    """ユーザー管理（Microsoft Graph Users API対応）"""
    __tablename__ = 'users'
    
    id = Column(Integer, primary_key=True)
    display_name = Column(String(255), nullable=False)
    user_principal_name = Column(String(255), unique=True, nullable=False, index=True)
    email = Column(String(255), index=True)
    department = Column(String(100), index=True)
    job_title = Column(String(100))
    account_status = Column(String(20), default='有効')  # "有効", "無効"
    license_status = Column(String(100))
    creation_date = Column(Date)
    last_sign_in = Column(DateTime)
    usage_location = Column(String(10))  # ISO 3166-1 alpha-2
    azure_ad_id = Column(PGUUID(as_uuid=True), unique=True, index=True)
    
    # リレーション
    mfa_status = relationship("MFAStatus", back_populates="user", uselist=False)
    signin_logs = relationship("SignInLog", back_populates="user")
    mailbox = relationship("Mailbox", back_populates="user", uselist=False)
    teams_usage = relationship("TeamsUsage", back_populates="user")
    onedrive_storage = relationship("OneDriveStorageAnalysis", back_populates="user")
    
    __table_args__ = (
        Index('idx_user_status_dept', 'account_status', 'department'),
    )


class MFAStatus(ReportBaseMixin, Base):
    """MFA状況"""
    __tablename__ = 'mfa_status'
    
    user_principal_name = Column(String(255), ForeignKey('users.user_principal_name'), nullable=False, index=True)
    display_name = Column(String(255))
    department = Column(String(100))
    mfa_status = Column(String(20))  # "有効", "無効", "強制"
    mfa_default_method = Column(String(50))  # "SMS", "認証アプリ" など
    phone_number = Column(String(20))
    email = Column(String(255))
    registration_date = Column(DateTime)
    last_verification = Column(DateTime)
    status = Column(String(50))
    
    # リレーション
    user = relationship("User", back_populates="mfa_status")


class ConditionalAccessPolicy(TimestampMixin, Base):
    """条件付きアクセスポリシー"""
    __tablename__ = 'conditional_access_policies'
    
    id = Column(Integer, primary_key=True)
    policy_name = Column(String(255), nullable=False, index=True)
    status = Column(String(20))  # "有効", "無効"
    target_users = Column(String(100))  # "全ユーザー", "特定グループ" など
    target_applications = Column(String(255))
    conditions = Column(Text)
    access_controls = Column(Text)
    creation_date = Column(Date)
    last_updated = Column(Date)
    application_count = Column(Integer, default=0)


class SignInLog(TimestampMixin, Base):
    """サインインログ"""
    __tablename__ = 'signin_logs'
    
    id = Column(Integer, primary_key=True)
    signin_datetime = Column(DateTime, nullable=False, index=True)
    user_name = Column(String(255), nullable=False)
    user_principal_name = Column(String(255), ForeignKey('users.user_principal_name'), index=True)
    application = Column(String(255), index=True)
    client_app = Column(String(100))
    device_info = Column(Text)
    location_city = Column(String(100))
    location_country = Column(String(100))
    ip_address = Column(INET)
    status = Column(String(50), index=True)  # "成功", "失敗"
    error_code = Column(String(20))
    failure_reason = Column(Text)
    risk_level = Column(String(20), index=True)
    
    # リレーション
    user = relationship("User", back_populates="signin_logs")
    
    __table_args__ = (
        Index('idx_signin_datetime_status', 'signin_datetime', 'status'),
    )


# ========================================
# 4. Exchange Online管理（4機能）
# ========================================
class Mailbox(TimestampMixin, Base):
    """メールボックス"""
    __tablename__ = 'mailboxes'
    
    id = Column(Integer, primary_key=True)
    email = Column(String(255), nullable=False, unique=True, index=True)
    display_name = Column(String(255))
    user_principal_name = Column(String(255), ForeignKey('users.user_principal_name'), index=True)
    mailbox_type = Column(String(50))  # "UserMailbox", "SharedMailbox" など
    total_size_mb = Column(SQLDecimal(12,2))
    quota_mb = Column(SQLDecimal(12,2))
    usage_percent = Column(SQLDecimal(5,2))
    message_count = Column(Integer, default=0)
    last_access = Column(DateTime)
    forwarding_enabled = Column(Boolean, default=False)
    forwarding_address = Column(String(255))
    auto_reply_enabled = Column(Boolean, default=False)
    
    # リレーション
    user = relationship("User", back_populates="mailbox")
    mail_flow_logs = relationship("MailFlowAnalysis", foreign_keys="MailFlowAnalysis.recipient_mailbox_id")
    
    __table_args__ = (
        Index('idx_mailbox_type_usage', 'mailbox_type', 'usage_percent'),
    )


class MailFlowAnalysis(TimestampMixin, Base):
    """メールフロー分析"""
    __tablename__ = 'mail_flow_analysis'
    
    id = Column(Integer, primary_key=True)
    datetime = Column(DateTime, nullable=False, index=True)
    sender = Column(String(255), index=True)
    recipient = Column(String(255), index=True)
    recipient_mailbox_id = Column(Integer, ForeignKey('mailboxes.id'))
    subject = Column(String(500))
    message_size_kb = Column(SQLDecimal(10,2))
    status = Column(String(50), index=True)  # "配信済み", "遅延", "失敗"
    connector = Column(String(100))
    event_type = Column(String(50))  # "送信", "受信", "内部"
    details = Column(Text)


class SpamProtectionAnalysis(TimestampMixin, Base):
    """スパム対策分析"""
    __tablename__ = 'spam_protection_analysis'
    
    id = Column(Integer, primary_key=True)
    datetime = Column(DateTime, nullable=False, index=True)
    sender = Column(String(255))
    recipient = Column(String(255))
    subject = Column(String(500))
    threat_type = Column(String(50), index=True)  # "スパム", "フィッシング", "マルウェア"
    spam_score = Column(SQLDecimal(4,2))
    action = Column(String(50))  # "検疫", "削除", "通過"
    policy_name = Column(String(100))
    details = Column(Text)


class MailDeliveryAnalysis(TimestampMixin, Base):
    """メール配信分析"""
    __tablename__ = 'mail_delivery_analysis'
    
    id = Column(Integer, primary_key=True)
    send_datetime = Column(DateTime, nullable=False, index=True)
    sender = Column(String(255))
    recipient = Column(String(255))
    subject = Column(String(500))
    message_id = Column(String(255), index=True)
    delivery_status = Column(String(50), index=True)  # "配信成功", "配信失敗", "遅延"
    latest_event = Column(String(100))
    delay_reason = Column(Text)
    recipient_server = Column(String(255))
    bounce_type = Column(String(50))


# ========================================
# 5. Teams管理（4機能）
# ========================================
class TeamsUsage(ReportBaseMixin, Base):
    """Teams使用状況"""
    __tablename__ = 'teams_usage'
    
    user_name = Column(String(255), nullable=False)
    user_principal_name = Column(String(255), ForeignKey('users.user_principal_name'), index=True)
    department = Column(String(100))
    last_access = Column(DateTime)
    chat_messages_count = Column(Integer, default=0)
    meetings_organized = Column(Integer, default=0)
    meetings_attended = Column(Integer, default=0)
    calls_count = Column(Integer, default=0)
    files_shared = Column(Integer, default=0)
    activity_score = Column(SQLDecimal(5,2))
    
    # リレーション
    user = relationship("User", back_populates="teams_usage")


class TeamsSettingsAnalysis(TimestampMixin, Base):
    """Teams設定分析"""
    __tablename__ = 'teams_settings_analysis'
    
    id = Column(Integer, primary_key=True)
    policy_name = Column(String(255), nullable=False, index=True)
    policy_type = Column(String(100))  # "Teams会議", "メッセージング" など
    target_users_count = Column(Integer, default=0)
    status = Column(String(20))  # "有効", "無効"
    messaging_permission = Column(String(20))
    file_sharing_permission = Column(String(20))
    meeting_recording_permission = Column(String(50))
    last_updated = Column(Date)
    compliance = Column(String(20))  # "準拠", "非準拠"


class MeetingQualityAnalysis(TimestampMixin, Base):
    """会議品質分析"""
    __tablename__ = 'meeting_quality_analysis'
    
    id = Column(Integer, primary_key=True)
    meeting_id = Column(String(100), nullable=False, unique=True, index=True)
    meeting_name = Column(String(255))
    datetime = Column(DateTime, nullable=False, index=True)
    participant_count = Column(Integer, default=0)
    duration_minutes = Column(Integer)
    audio_quality = Column(String(20))  # "良好", "普通", "悪い"
    video_quality = Column(String(20))
    network_quality = Column(String(20))
    overall_quality_score = Column(SQLDecimal(3,1))
    quality_rating = Column(String(20))  # "優秀", "良好", "要改善"
    issues_reported = Column(Text)


class TeamsAppAnalysis(TimestampMixin, Base):
    """Teamsアプリ分析"""
    __tablename__ = 'teams_apps_analysis'
    
    id = Column(Integer, primary_key=True)
    app_name = Column(String(255), nullable=False, index=True)
    version = Column(String(50))
    publisher = Column(String(100))
    installation_count = Column(Integer, default=0)
    active_users_count = Column(Integer, default=0)
    last_used_date = Column(Date)
    app_status = Column(String(20))  # "アクティブ", "非アクティブ"
    permission_status = Column(String(20))  # "承認済み", "要確認"
    security_score = Column(SQLDecimal(3,1))
    risk_level = Column(String(20))
    
    __table_args__ = (
        Index('idx_teams_app_status_risk', 'app_status', 'risk_level'),
    )


# ========================================
# 6. OneDrive管理（4機能）
# ========================================
class OneDriveStorageAnalysis(ReportBaseMixin, Base):
    """OneDriveストレージ分析"""
    __tablename__ = 'onedrive_storage_analysis'
    
    user_name = Column(String(255), nullable=False)
    user_principal_name = Column(String(255), ForeignKey('users.user_principal_name'), index=True)
    department = Column(String(100))
    total_storage_gb = Column(SQLDecimal(10,2))
    used_storage_gb = Column(SQLDecimal(10,2))
    usage_percent = Column(SQLDecimal(5,2))
    file_count = Column(Integer, default=0)
    folder_count = Column(Integer, default=0)
    last_activity = Column(DateTime)
    sync_status = Column(String(20))  # "同期済み", "同期中", "エラー"
    
    # リレーション
    user = relationship("User", back_populates="onedrive_storage")


class OneDriveSharingAnalysis(TimestampMixin, Base):
    """OneDrive共有分析"""
    __tablename__ = 'onedrive_sharing_analysis'
    
    id = Column(Integer, primary_key=True)
    file_name = Column(String(500), nullable=False, index=True)
    owner = Column(String(255), index=True)
    file_size_mb = Column(SQLDecimal(10,2))
    share_type = Column(String(20), index=True)  # "内部", "外部"
    shared_with = Column(String(255))
    access_permission = Column(String(50))  # "編集可能", "表示のみ"
    share_date = Column(DateTime)
    last_access = Column(DateTime)
    risk_level = Column(String(20), index=True)  # "低", "中", "高"


class OneDriveSyncError(TimestampMixin, Base):
    """OneDrive同期エラー"""
    __tablename__ = 'onedrive_sync_errors'
    
    id = Column(Integer, primary_key=True)
    occurrence_date = Column(DateTime, nullable=False, index=True)
    user_name = Column(String(255), index=True)
    user_principal_name = Column(String(255), ForeignKey('users.user_principal_name'))
    file_path = Column(Text)
    error_type = Column(String(100), index=True)  # "同期競合", "権限エラー" など
    error_code = Column(String(50))
    error_message = Column(Text)
    affected_files_count = Column(Integer, default=0)
    status = Column(String(50))  # "解決済み", "未解決", "対応中"
    resolution_date = Column(Date)


class OneDriveExternalSharing(TimestampMixin, Base):
    """OneDrive外部共有"""
    __tablename__ = 'onedrive_external_sharing'
    
    id = Column(Integer, primary_key=True)
    file_name = Column(String(500), nullable=False, index=True)
    owner = Column(String(255), index=True)
    external_domain = Column(String(255), index=True)
    shared_email = Column(String(255))
    access_permission = Column(String(50))
    share_url = Column(Text)
    share_start_date = Column(Date)
    last_access = Column(DateTime)
    risk_level = Column(String(20), index=True)  # "低", "中", "高"
    expiration_date = Column(Date)
    download_count = Column(Integer, default=0)


# ========================================
# 共通メタデータテーブル
# ========================================
class ReportMetadata(TimestampMixin, Base):
    """レポート生成メタデータ（PowerShell互換性維持）"""
    __tablename__ = 'report_metadata'
    
    id = Column(Integer, primary_key=True)
    report_type = Column(String(100), nullable=False, index=True)
    report_category = Column(String(50), index=True)  # "定期レポート", "分析レポート" など
    file_path = Column(Text)
    csv_file_path = Column(Text)
    html_file_path = Column(Text)
    generation_time = Column(DateTime, default=datetime.utcnow)
    data_source = Column(String(100))  # "Microsoft Graph", "Exchange Online" など
    record_count = Column(Integer, default=0)
    status = Column(String(20))  # "成功", "失敗", "部分的成功"
    generation_params = Column(JSONB)  # 生成パラメータ（JSON形式）


class DataQualityLog(TimestampMixin, Base):
    """データ品質・検証ログ"""
    __tablename__ = 'data_quality_logs'
    
    id = Column(Integer, primary_key=True)
    table_name = Column(String(100), nullable=False, index=True)
    validation_type = Column(String(50))  # "データ型", "必須項目", "整合性"
    validation_status = Column(String(20), index=True)  # "成功", "警告", "エラー"
    error_details = Column(Text)
    affected_records = Column(Integer, default=0)
    validated_at = Column(DateTime, default=datetime.utcnow)


# ========================================
# パフォーマンス最適化用インデックス
# ========================================
def create_performance_indexes(engine):
    """パフォーマンス最適化インデックス作成"""
    
    # 複合インデックス（検索パフォーマンス向上）
    indexes = [
        # 時系列データ用
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_performance_service_time_status ON performance_monitoring(service_name, timestamp, status)",
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_signin_user_time_status ON signin_logs(user_principal_name, signin_datetime, status)",
        
        # レポート生成用
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_license_dept_type_date ON license_analysis(department, license_type, report_date)",
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_usage_service_date_users ON service_usage_analysis(service_name, report_date, active_users)",
        
        # セキュリティ分析用
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_security_item_risk_date ON security_analysis(security_item, risk_level, report_date)",
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mfa_status_user ON mfa_status(mfa_status, user_principal_name)",
        
        # メール分析用
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mailflow_sender_recipient_date ON mail_flow_analysis(sender, recipient, datetime)",
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_spam_threat_date ON spam_protection_analysis(threat_type, datetime)",
        
        # Teams分析用
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_teams_user_activity_date ON teams_usage(user_principal_name, activity_score, report_date)",
        
        # OneDrive分析用
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_onedrive_user_usage_date ON onedrive_storage_analysis(user_principal_name, usage_percent, report_date)",
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sharing_risk_type ON onedrive_sharing_analysis(risk_level, share_type)",
    ]
    
    with engine.connect() as conn:
        for index_sql in indexes:
            try:
                conn.execute(text(index_sql))
            except Exception as e:
                print(f"インデックス作成エラー: {e}")


# ========================================
# SQLAlchemy イベントハンドラー
# ========================================
@event.listens_for(User, 'before_insert')
def set_user_azure_ad_id(mapper, connection, target):
    """ユーザー作成時にUUID自動生成"""
    if not target.azure_ad_id:
        target.azure_ad_id = uuid4()


@event.listens_for(ReportMetadata, 'before_insert')
def set_report_generation_time(mapper, connection, target):
    """レポートメタデータ作成時に生成時間設定"""
    if not target.generation_time:
        target.generation_time = datetime.utcnow()


# ========================================
# PowerShell互換性ヘルパー関数
# ========================================
def get_powershell_compatible_data(table_class, session, limit: int = None) -> List[Dict[str, Any]]:
    """PowerShell CSV形式互換データ取得"""
    query = session.query(table_class)
    if limit:
        query = query.limit(limit)
    
    results = []
    for record in query.all():
        row_data = {}
        for column in table_class.__table__.columns:
            value = getattr(record, column.name)
            if isinstance(value, datetime):
                # PowerShell互換日時形式
                row_data[column.name] = value.strftime('%Y-%m-%d %H:%M:%S')
            elif isinstance(value, date):
                row_data[column.name] = value.strftime('%Y-%m-%d')
            elif isinstance(value, Decimal):
                row_data[column.name] = float(value)
            else:
                row_data[column.name] = str(value) if value is not None else ""
        results.append(row_data)
    
    return results


# ========================================
# データベース初期化関数
# ========================================
def create_all_tables(engine):
    """全テーブル作成"""
    Base.metadata.create_all(engine)
    create_performance_indexes(engine)
    print("データベーステーブル・インデックス作成完了")


def drop_all_tables(engine):
    """全テーブル削除（開発・テスト用）"""
    Base.metadata.drop_all(engine)
    print("全データベーステーブル削除完了")


if __name__ == "__main__":
    # テスト実行用
    from sqlalchemy import create_engine
    
    # PostgreSQL接続URL（実際の本番環境では環境変数から取得）
    DATABASE_URL = "postgresql://username:password@localhost:5432/ms365_management"
    
    engine = create_engine(DATABASE_URL, echo=True)
    create_all_tables(engine)
    
    print("Microsoft 365管理ツール データベーススキーマ作成完了")
    print(f"テーブル数: {len(Base.metadata.tables)}")
    for table_name in Base.metadata.tables.keys():
        print(f"  - {table_name}")