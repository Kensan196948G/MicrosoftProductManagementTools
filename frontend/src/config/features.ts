// Microsoft 365 Management Tools - Feature Configuration
// PowerShell Windows Forms GUI 完全互換の機能設定

import { TabConfig, FeatureButton } from '../types/features';

// 26機能の完全定義（PowerShell GUI から移行）
export const FEATURE_TABS: TabConfig[] = [
  {
    id: 'regular-reports',
    title: '📊 定期レポート',
    icon: '📊',
    description: '日次・週次・月次・年次レポートとテスト実行',
    layout: 'grid-3x2',
    features: [
      {
        id: 'daily-report',
        text: '📅 日次レポート',
        icon: '📅',
        action: 'DailyReport',
        description: '日次のユーザーアクティビティとシステム使用状況',
        category: 'regular-reports',
        position: { x: 15, y: 15 },
        status: 'active'
      },
      {
        id: 'weekly-report', 
        text: '📊 週次レポート',
        icon: '📊',
        action: 'WeeklyReport',
        description: '週次のトレンド分析とパフォーマンス評価',
        category: 'regular-reports',
        position: { x: 215, y: 15 },
        status: 'active'
      },
      {
        id: 'monthly-report',
        text: '📈 月次レポート', 
        icon: '📈',
        action: 'MonthlyReport',
        description: '月次の利用状況とコスト分析',
        category: 'regular-reports',
        position: { x: 415, y: 15 },
        status: 'active'
      },
      {
        id: 'yearly-report',
        text: '📆 年次レポート',
        icon: '📆', 
        action: 'YearlyReport',
        description: '年次の総合分析とライセンス消費',
        category: 'regular-reports',
        position: { x: 15, y: 75 },
        status: 'active'
      },
      {
        id: 'test-execution',
        text: '🧪 テスト実行',
        icon: '🧪',
        action: 'TestExecution',
        description: 'システムテストと接続確認',
        category: 'regular-reports',
        position: { x: 215, y: 75 },
        status: 'active'
      },
      {
        id: 'show-latest-daily-report',
        text: '📋 最新日次レポート表示',
        icon: '📋',
        action: 'ShowLatestDailyReport',
        description: '最新の日次レポートを表示',
        category: 'regular-reports',
        position: { x: 415, y: 75 },
        status: 'active'
      }
    ]
  },
  
  {
    id: 'analytics-reports',
    title: '🔍 分析レポート',
    icon: '🔍',
    description: 'ライセンス・使用状況・パフォーマンス・セキュリティ分析',
    layout: 'grid-3x2',
    features: [
      {
        id: 'license-analysis',
        text: '📊 ライセンス分析',
        icon: '📊',
        action: 'LicenseAnalysis',
        description: 'ライセンス使用状況とコスト最適化',
        category: 'analytics-reports',
        position: { x: 15, y: 15 },
        status: 'active'
      },
      {
        id: 'usage-analysis',
        text: '📈 使用状況分析',
        icon: '📈',
        action: 'UsageAnalysis',
        description: 'サービス別使用状況と普及率',
        category: 'analytics-reports',
        position: { x: 215, y: 15 },
        status: 'active'
      },
      {
        id: 'performance-analysis',
        text: '⚡ パフォーマンス分析',
        icon: '⚡',
        action: 'PerformanceAnalysis',
        description: 'システムパフォーマンスと会議品質',
        category: 'analytics-reports',
        position: { x: 415, y: 15 },
        status: 'active'
      },
      {
        id: 'security-analysis',
        text: '🛡️ セキュリティ分析',
        icon: '🛡️',
        action: 'SecurityAnalysis',
        description: 'セキュリティ状況と脆弱性評価',
        category: 'analytics-reports',
        position: { x: 15, y: 75 },
        status: 'active'
      },
      {
        id: 'permission-audit',
        text: '🔍 権限監査',
        icon: '🔍',
        action: 'PermissionAudit',
        description: 'ユーザー権限とアクセス制御の監査',
        category: 'analytics-reports',
        position: { x: 215, y: 75 },
        status: 'active'
      }
    ]
  },
  
  {
    id: 'entra-id',
    title: '👥 Entra ID管理',
    icon: '👥',
    description: 'ユーザー管理・MFA・条件付きアクセス・サインインログ',
    layout: 'grid-2x2',
    features: [
      {
        id: 'user-list',
        text: '👥 ユーザー一覧',
        icon: '👥',
        action: 'UserList',
        description: 'すべてのユーザーアカウントの一覧表示',
        category: 'entra-id',
        position: { x: 50, y: 15 },
        status: 'active'
      },
      {
        id: 'mfa-status',
        text: '🔐 MFA状況',
        icon: '🔐',
        action: 'MFAStatus',
        description: '多要素認証の設定状況',
        category: 'entra-id',
        position: { x: 280, y: 15 },
        status: 'active'
      },
      {
        id: 'conditional-access',
        text: '🛡️ 条件付きアクセス',
        icon: '🛡️',
        action: 'ConditionalAccess',
        description: '条件付きアクセスポリシーの状況',
        category: 'entra-id',
        position: { x: 50, y: 75 },
        status: 'active'
      },
      {
        id: 'signin-logs',
        text: '📝 サインインログ',
        icon: '📝',
        action: 'SignInLogs',
        description: 'ユーザーのサインイン履歴',
        category: 'entra-id',
        position: { x: 280, y: 75 },
        status: 'active'
      }
    ]
  },
  
  {
    id: 'exchange-online',
    title: '📧 Exchange Online',
    icon: '📧',
    description: 'メールボックス・メールフロー・スパム対策・配信分析',
    layout: 'grid-2x2',
    features: [
      {
        id: 'mailbox-management',
        text: '📧 メールボックス管理',
        icon: '📧',
        action: 'MailboxManagement',
        description: 'メールボックスの使用状況と管理',
        category: 'exchange-online',
        position: { x: 50, y: 15 },
        status: 'active'
      },
      {
        id: 'mail-flow-analysis',
        text: '🔄 メールフロー分析',
        icon: '🔄',
        action: 'MailFlowAnalysis',
        description: 'メールフローの分析と最適化',
        category: 'exchange-online',
        position: { x: 280, y: 15 },
        status: 'active'
      },
      {
        id: 'spam-protection-analysis',
        text: '🛡️ スパム対策分析',
        icon: '🛡️',
        action: 'SpamProtectionAnalysis',
        description: 'スパム対策の効果と設定状況',
        category: 'exchange-online',
        position: { x: 50, y: 75 },
        status: 'active'
      },
      {
        id: 'mail-delivery-analysis',
        text: '📬 配信分析',
        icon: '📬',
        action: 'MailDeliveryAnalysis',
        description: 'メール配信の成功率と問題分析',
        category: 'exchange-online',
        position: { x: 280, y: 75 },
        status: 'active'
      }
    ]
  },
  
  {
    id: 'teams-management',
    title: '💬 Teams管理',
    icon: '💬',
    description: 'Teams使用状況・設定・会議品質・アプリ分析',
    layout: 'grid-2x2',
    features: [
      {
        id: 'teams-usage',
        text: '💬 Teams使用状況',
        icon: '💬',
        action: 'TeamsUsage',
        description: 'Teams の使用状況と活動分析',
        category: 'teams-management',
        position: { x: 50, y: 15 },
        status: 'active'
      },
      {
        id: 'teams-settings-analysis',
        text: '⚙️ Teams設定分析',
        icon: '⚙️',
        action: 'TeamsSettingsAnalysis',
        description: 'Teams の設定状況とポリシー',
        category: 'teams-management',
        position: { x: 280, y: 15 },
        status: 'active'
      },
      {
        id: 'meeting-quality-analysis',
        text: '📹 会議品質分析',
        icon: '📹',
        action: 'MeetingQualityAnalysis',
        description: '会議の品質とパフォーマンス分析',
        category: 'teams-management',
        position: { x: 50, y: 75 },
        status: 'active'
      },
      {
        id: 'teams-app-analysis',
        text: '📱 アプリ分析',
        icon: '📱',
        action: 'TeamsAppAnalysis',
        description: 'Teams アプリの使用状況',
        category: 'teams-management',
        position: { x: 280, y: 75 },
        status: 'active'
      }
    ]
  },
  
  {
    id: 'onedrive-management',
    title: '💾 OneDrive管理',
    icon: '💾',
    description: 'ストレージ・共有・同期エラー・外部共有分析',
    layout: 'grid-2x2',
    features: [
      {
        id: 'storage-analysis',
        text: '💾 ストレージ分析',
        icon: '💾',
        action: 'StorageAnalysis',
        description: 'OneDrive ストレージの使用状況',
        category: 'onedrive-management',
        position: { x: 50, y: 15 },
        status: 'active'
      },
      {
        id: 'sharing-analysis',
        text: '🤝 共有分析',
        icon: '🤝',
        action: 'SharingAnalysis',
        description: 'ファイル共有の状況と分析',
        category: 'onedrive-management',
        position: { x: 280, y: 15 },
        status: 'active'
      },
      {
        id: 'sync-error-analysis',
        text: '🔄 同期エラー分析',
        icon: '🔄',
        action: 'SyncErrorAnalysis',
        description: '同期エラーの分析と対策',
        category: 'onedrive-management',
        position: { x: 50, y: 75 },
        status: 'active'
      },
      {
        id: 'external-sharing-analysis',
        text: '🌐 外部共有分析',
        icon: '🌐',
        action: 'ExternalSharingAnalysis',
        description: '外部共有の状況とセキュリティ',
        category: 'onedrive-management',
        position: { x: 280, y: 75 },
        status: 'active'
      }
    ]
  }
];

// 機能カテゴリ別の色設定（PowerShell GUI 互換）
export const CATEGORY_COLORS = {
  'regular-reports': {
    primary: '#0078d4',
    secondary: '#106ebe',
    accent: '#005a9e',
    background: '#f3f9ff'
  },
  'analytics-reports': {
    primary: '#0078d4',
    secondary: '#106ebe', 
    accent: '#005a9e',
    background: '#f3f9ff'
  },
  'entra-id': {
    primary: '#0078d4',
    secondary: '#106ebe',
    accent: '#005a9e',
    background: '#f3f9ff'
  },
  'exchange-online': {
    primary: '#0078d4',
    secondary: '#106ebe',
    accent: '#005a9e',
    background: '#f3f9ff'
  },
  'teams-management': {
    primary: '#0078d4',
    secondary: '#106ebe',
    accent: '#005a9e',
    background: '#f3f9ff'
  },
  'onedrive-management': {
    primary: '#0078d4',
    secondary: '#106ebe',
    accent: '#005a9e',
    background: '#f3f9ff'
  }
} as const;

// PowerShell GUI 互換の設定値
export const UI_CONSTANTS = {
  BUTTON_SIZE: {
    width: 190,
    height: 50
  },
  GRID_SPACING: {
    x: 200,
    y: 60
  },
  CONTAINER_PADDING: 20,
  BORDER_RADIUS: 4,
  ANIMATION_DURATION: 200
} as const;