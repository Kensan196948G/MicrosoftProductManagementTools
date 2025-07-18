// Microsoft 365 Management Tools - Feature Types
// PowerShell Windows Forms GUI 完全互換の型定義

export interface FeatureButton {
  id: string;
  text: string;
  icon: string;
  action: string;
  description: string;
  category: TabCategory;
  position: {
    x: number;
    y: number;
  };
  status: 'active' | 'disabled' | 'loading';
}

export type TabCategory = 
  | 'regular-reports'
  | 'analytics-reports'
  | 'entra-id'
  | 'exchange-online'
  | 'teams-management'
  | 'onedrive-management';

export interface TabConfig {
  id: TabCategory;
  title: string;
  icon: string;
  description: string;
  features: FeatureButton[];
  layout: 'grid-2x2' | 'grid-3x2' | 'grid-3x3';
}

// 26機能の完全マッピング（PowerShell GUI完全互換）
export const FEATURE_MAPPING = {
  // 📊 定期レポート（6機能）
  'regular-reports': {
    'DailyReport': '📅 日次レポート',
    'WeeklyReport': '📊 週次レポート', 
    'MonthlyReport': '📈 月次レポート',
    'YearlyReport': '📆 年次レポート',
    'TestExecution': '🧪 テスト実行',
    'ShowLatestDailyReport': '📋 最新日次レポート表示'
  },
  
  // 🔍 分析レポート（5機能）
  'analytics-reports': {
    'LicenseAnalysis': '📊 ライセンス分析',
    'UsageAnalysis': '📈 使用状況分析',
    'PerformanceAnalysis': '⚡ パフォーマンス分析',
    'SecurityAnalysis': '🛡️ セキュリティ分析',
    'PermissionAudit': '🔍 権限監査'
  },
  
  // 👥 Entra ID管理（4機能）
  'entra-id': {
    'UserList': '👥 ユーザー一覧',
    'MFAStatus': '🔐 MFA状況',
    'ConditionalAccess': '🛡️ 条件付きアクセス',
    'SignInLogs': '📝 サインインログ'
  },
  
  // 📧 Exchange Online管理（4機能）
  'exchange-online': {
    'MailboxManagement': '📧 メールボックス管理',
    'MailFlowAnalysis': '🔄 メールフロー分析',
    'SpamProtectionAnalysis': '🛡️ スパム対策分析',
    'MailDeliveryAnalysis': '📬 配信分析'
  },
  
  // 💬 Teams管理（4機能）
  'teams-management': {
    'TeamsUsage': '💬 Teams使用状況',
    'TeamsSettingsAnalysis': '⚙️ Teams設定分析',
    'MeetingQualityAnalysis': '📹 会議品質分析',
    'TeamsAppAnalysis': '📱 アプリ分析'
  },
  
  // 💾 OneDrive管理（4機能）
  'onedrive-management': {
    'StorageAnalysis': '💾 ストレージ分析',
    'SharingAnalysis': '🤝 共有分析',
    'SyncErrorAnalysis': '🔄 同期エラー分析',
    'ExternalSharingAnalysis': '🌐 外部共有分析'
  }
} as const;

// 実行結果タイプ
export interface ExecutionResult {
  success: boolean;
  message: string;
  data?: any;
  outputPath?: string;
  reportType?: 'CSV' | 'HTML' | 'PDF';
  timestamp: Date;
}

// 進捗状態
export interface ProgressState {
  isVisible: boolean;
  current: number;
  total: number;
  message: string;
  stage: 'connecting' | 'processing' | 'generating' | 'completed' | 'error';
}

// 認証状態
export interface AuthState {
  isConnected: boolean;
  lastConnected?: Date;
  connectionStatus: 'connected' | 'disconnected' | 'connecting' | 'error';
  services: {
    graph: boolean;
    exchange: boolean;
    teams: boolean;
    oneDrive: boolean;
  };
}

// アクセシビリティ設定
export interface AccessibilityConfig {
  highContrast: boolean;
  reducedMotion: boolean;
  screenReader: boolean;
  keyboardNavigation: boolean;
  fontSize: 'small' | 'medium' | 'large' | 'xl';
}

// テーマ設定
export interface ThemeConfig {
  mode: 'light' | 'dark' | 'auto';
  primaryColor: string;
  fontSize: number;
  compactMode: boolean;
}

// UI状態管理
export interface UIState {
  activeTab: TabCategory;
  sidebarOpen: boolean;
  logVisible: boolean;
  theme: ThemeConfig;
  accessibility: AccessibilityConfig;
  progress: ProgressState;
  auth: AuthState;
  lastAction?: string;
}