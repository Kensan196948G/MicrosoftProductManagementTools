import React from 'react';
import {
  Assessment as AssessmentIcon,
  Analytics as AnalyticsIcon,
  People as PeopleIcon,
  Email as EmailIcon,
  Groups as GroupsIcon,
  CloudQueue as CloudQueueIcon,
  CalendarToday as CalendarIcon,
  BarChart as BarChartIcon,
  TrendingUp as TrendingUpIcon,
  EventNote as EventNoteIcon,
  BugReport as BugReportIcon,
  Assignment as AssignmentIcon,
  DonutLarge as DonutLargeIcon,
  Speed as SpeedIcon,
  Security as SecurityIcon,
  AdminPanelSettings as AdminPanelSettingsIcon,
  Person as PersonIcon,
  Shield as ShieldIcon,
  VpnKey as VpnKeyIcon,
  Description as DescriptionIcon,
  Inbox as InboxIcon,
  CompareArrows as CompareArrowsIcon,
  Block as BlockIcon,
  Send as SendIcon,
  Chat as ChatIcon,
  Settings as SettingsIcon,
  VideoCall as VideoCallIcon,
  Apps as AppsIcon,
  Storage as StorageIcon,
  Share as ShareIcon,
  Sync as SyncIcon,
  Public as PublicIcon
} from '@mui/icons-material';
import { TabConfig } from '@types/index';

export const tabsConfig: TabConfig[] = [
  {
    id: 'regular-reports',
    label: '📊 定期レポート',
    icon: React.createElement(AssessmentIcon),
    color: '#0078d4',
    functions: [
      {
        id: 'daily-report',
        title: '📅 日次レポート',
        description: '毎日のシステム利用状況と重要メトリクスを自動収集し、管理者向けダッシュボード形式で表示',
        icon: React.createElement(CalendarIcon),
        action: 'DailyReport',
        reportType: 'daily',
        estimatedTime: '2-3 min',
        isEnabled: true
      },
      {
        id: 'weekly-report',
        title: '📊 週次レポート',
        description: '週単位でのトレンド分析とパフォーマンス指標を包括的にレポート',
        icon: React.createElement(BarChartIcon),
        action: 'WeeklyReport',
        reportType: 'weekly',
        estimatedTime: '3-4 min',
        isEnabled: true
      },
      {
        id: 'monthly-report',
        title: '📈 月次レポート',
        description: '月次のビジネスインテリジェンスと戦略的インサイトを提供',
        icon: React.createElement(TrendingUpIcon),
        action: 'MonthlyReport',
        reportType: 'monthly',
        estimatedTime: '5-7 min',
        isEnabled: true
      },
      {
        id: 'yearly-report',
        title: '📆 年次レポート',
        description: '年次統計とコンプライアンス要件に対応した包括的レポート',
        icon: React.createElement(EventNoteIcon),
        action: 'YearlyReport',
        reportType: 'yearly',
        estimatedTime: '8-10 min',
        isEnabled: true
      },
      {
        id: 'test-execution',
        title: '🧪 テスト実行',
        description: 'システムの健全性チェックとパフォーマンステストを実行',
        icon: React.createElement(BugReportIcon),
        action: 'TestExecution',
        reportType: 'daily',
        estimatedTime: '1-2 min',
        isEnabled: true
      },
      {
        id: 'latest-daily-report',
        title: '📋 最新日次レポート表示',
        description: '最新の日次レポートを即座に表示・ダウンロード',
        icon: React.createElement(AssignmentIcon),
        action: 'ShowLatestDailyReport',
        reportType: 'daily',
        estimatedTime: '< 1 min',
        isEnabled: true
      }
    ]
  },
  {
    id: 'analytics',
    label: '🔍 分析レポート',
    icon: React.createElement(AnalyticsIcon),
    color: '#6c757d',
    functions: [
      {
        id: 'license-analysis',
        title: '📊 ライセンス分析',
        description: 'Microsoft 365ライセンスの利用状況と最適化提案',
        icon: React.createElement(DonutLargeIcon),
        action: 'LicenseAnalysis',
        reportType: 'license',
        estimatedTime: '3-4 min',
        isEnabled: true
      },
      {
        id: 'usage-analysis',
        title: '📈 使用状況分析',
        description: 'サービス別使用状況の詳細分析とトレンド',
        icon: React.createElement(TrendingUpIcon),
        action: 'UsageAnalysis',
        reportType: 'usage',
        estimatedTime: '4-5 min',
        isEnabled: true
      },
      {
        id: 'performance-analysis',
        title: '⚡ パフォーマンス分析',
        description: 'システムパフォーマンスと応答時間の詳細分析',
        icon: React.createElement(SpeedIcon),
        action: 'PerformanceAnalysis',
        reportType: 'performance',
        estimatedTime: '5-6 min',
        isEnabled: true
      },
      {
        id: 'security-analysis',
        title: '🛡️ セキュリティ分析',
        description: 'セキュリティ脅威の検出とコンプライアンス状況',
        icon: React.createElement(SecurityIcon),
        action: 'SecurityAnalysis',
        reportType: 'security',
        estimatedTime: '6-7 min',
        isEnabled: true
      },
      {
        id: 'permission-audit',
        title: '🔍 権限監査',
        description: 'アクセス権限の包括的監査と異常検知',
        icon: React.createElement(AdminPanelSettingsIcon),
        action: 'PermissionAudit',
        reportType: 'permission',
        estimatedTime: '7-8 min',
        isEnabled: true
      }
    ]
  },
  {
    id: 'entra-id',
    label: '👥 Entra ID管理',
    icon: React.createElement(PeopleIcon),
    color: '#28a745',
    functions: [
      {
        id: 'user-list',
        title: '👥 ユーザー一覧',
        description: 'Entra IDユーザーの包括的一覧とプロファイル情報',
        icon: React.createElement(PersonIcon),
        action: 'UserList',
        reportType: 'users',
        estimatedTime: '2-3 min',
        isEnabled: true
      },
      {
        id: 'mfa-status',
        title: '🔐 MFA状況',
        description: '多要素認証の実装状況と推奨事項',
        icon: React.createElement(ShieldIcon),
        action: 'MFAStatus',
        reportType: 'mfa',
        estimatedTime: '3-4 min',
        isEnabled: true
      },
      {
        id: 'conditional-access',
        title: '🛡️ 条件付きアクセス',
        description: '条件付きアクセスポリシーの設定と効果分析',
        icon: React.createElement(VpnKeyIcon),
        action: 'ConditionalAccess',
        reportType: 'conditional-access',
        estimatedTime: '4-5 min',
        isEnabled: true
      },
      {
        id: 'signin-logs',
        title: '📝 サインインログ',
        description: 'ユーザーサインインアクティビティの詳細分析',
        icon: React.createElement(DescriptionIcon),
        action: 'SignInLogs',
        reportType: 'signin-logs',
        estimatedTime: '5-6 min',
        isEnabled: true
      }
    ]
  },
  {
    id: 'exchange',
    label: '📧 Exchange Online',
    icon: React.createElement(EmailIcon),
    color: '#ffc107',
    functions: [
      {
        id: 'mailbox-management',
        title: '📧 メールボックス管理',
        description: 'Exchange Onlineメールボックスの包括的管理',
        icon: React.createElement(InboxIcon),
        action: 'MailboxManagement',
        reportType: 'mailbox',
        estimatedTime: '3-4 min',
        isEnabled: true
      },
      {
        id: 'mailflow-analysis',
        title: '🔄 メールフロー分析',
        description: 'メールフローの詳細分析とボトルネック検出',
        icon: React.createElement(CompareArrowsIcon),
        action: 'MailFlowAnalysis',
        reportType: 'mailflow',
        estimatedTime: '4-5 min',
        isEnabled: true
      },
      {
        id: 'spam-protection',
        title: '🛡️ スパム対策分析',
        description: 'スパム対策の効果と推奨設定の分析',
        icon: React.createElement(BlockIcon),
        action: 'SpamProtectionAnalysis',
        reportType: 'spam-protection',
        estimatedTime: '3-4 min',
        isEnabled: true
      },
      {
        id: 'mail-delivery',
        title: '📬 配信分析',
        description: 'メール配信状況と配信エラーの詳細分析',
        icon: React.createElement(SendIcon),
        action: 'MailDeliveryAnalysis',
        reportType: 'mail-delivery',
        estimatedTime: '4-5 min',
        isEnabled: true
      }
    ]
  },
  {
    id: 'teams',
    label: '💬 Teams管理',
    icon: React.createElement(GroupsIcon),
    color: '#dc3545',
    functions: [
      {
        id: 'teams-usage',
        title: '💬 Teams使用状況',
        description: 'Microsoft Teamsの利用状況と活用度分析',
        icon: React.createElement(ChatIcon),
        action: 'TeamsUsage',
        reportType: 'teams-usage',
        estimatedTime: '3-4 min',
        isEnabled: true
      },
      {
        id: 'teams-settings',
        title: '⚙️ Teams設定分析',
        description: 'Teams設定の最適化と推奨構成',
        icon: React.createElement(SettingsIcon),
        action: 'TeamsSettingsAnalysis',
        reportType: 'teams-settings',
        estimatedTime: '4-5 min',
        isEnabled: true
      },
      {
        id: 'meeting-quality',
        title: '📹 会議品質分析',
        description: 'Teams会議の品質メトリクスと改善提案',
        icon: React.createElement(VideoCallIcon),
        action: 'MeetingQualityAnalysis',
        reportType: 'meeting-quality',
        estimatedTime: '5-6 min',
        isEnabled: true
      },
      {
        id: 'teams-apps',
        title: '📱 アプリ分析',
        description: 'Teamsアプリの利用状況と管理推奨事項',
        icon: React.createElement(AppsIcon),
        action: 'TeamsAppAnalysis',
        reportType: 'teams-apps',
        estimatedTime: '4-5 min',
        isEnabled: true
      }
    ]
  },
  {
    id: 'onedrive',
    label: '💾 OneDrive管理',
    icon: React.createElement(CloudQueueIcon),
    color: '#17a2b8',
    functions: [
      {
        id: 'storage-analysis',
        title: '💾 ストレージ分析',
        description: 'OneDriveストレージの利用状況と最適化',
        icon: React.createElement(StorageIcon),
        action: 'StorageAnalysis',
        reportType: 'storage',
        estimatedTime: '3-4 min',
        isEnabled: true
      },
      {
        id: 'sharing-analysis',
        title: '🤝 共有分析',
        description: 'ファイル共有の詳細分析とガバナンス',
        icon: React.createElement(ShareIcon),
        action: 'SharingAnalysis',
        reportType: 'sharing',
        estimatedTime: '4-5 min',
        isEnabled: true
      },
      {
        id: 'sync-errors',
        title: '🔄 同期エラー分析',
        description: 'OneDrive同期エラーの検出と解決策',
        icon: React.createElement(SyncIcon),
        action: 'SyncErrorAnalysis',
        reportType: 'sync-errors',
        estimatedTime: '4-5 min',
        isEnabled: true
      },
      {
        id: 'external-sharing',
        title: '🌐 外部共有分析',
        description: '外部共有のセキュリティ分析とコンプライアンス',
        icon: React.createElement(PublicIcon),
        action: 'ExternalSharingAnalysis',
        reportType: 'external-sharing',
        estimatedTime: '5-6 min',
        isEnabled: true
      }
    ]
  }
];

export default tabsConfig;