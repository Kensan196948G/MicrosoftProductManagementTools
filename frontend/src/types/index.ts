// Microsoft 365 Admin Tools - Type Definitions
export interface User {
  id: string;
  displayName: string;
  userPrincipalName: string;
  mail: string;
  mfaEnabled: boolean;
  accountEnabled: boolean;
  lastSignInDateTime: string;
  createdDateTime: string;
  department?: string;
  jobTitle?: string;
  usageLocation?: string;
  assignedLicenses: AssignedLicense[];
}

export interface AssignedLicense {
  disabledPlans: string[];
  skuId: string;
  skuPartNumber: string;
  servicePlans: ServicePlan[];
}

export interface ServicePlan {
  servicePlanId: string;
  servicePlanName: string;
  provisioningStatus: string;
  appliesTo: string;
}

export interface ReportData {
  id: string;
  type: ReportType;
  title: string;
  description: string;
  createdDate: string;
  status: 'completed' | 'processing' | 'failed';
  dataRows: number;
  fileSize: string;
  downloadUrl?: string;
}

export type ReportType = 
  | 'daily'
  | 'weekly'
  | 'monthly'
  | 'yearly'
  | 'license'
  | 'usage'
  | 'performance'
  | 'security'
  | 'permission'
  | 'users'
  | 'mfa'
  | 'conditional-access'
  | 'signin-logs'
  | 'mailbox'
  | 'mailflow'
  | 'spam-protection'
  | 'mail-delivery'
  | 'teams-usage'
  | 'teams-settings'
  | 'meeting-quality'
  | 'teams-apps'
  | 'storage'
  | 'sharing'
  | 'sync-errors'
  | 'external-sharing';

export interface TabConfig {
  id: string;
  label: string;
  icon: React.ReactNode;
  color: string;
  functions: FunctionConfig[];
}

export interface FunctionConfig {
  id: string;
  title: string;
  description: string;
  icon: React.ReactNode;
  action: string;
  reportType: ReportType;
  estimatedTime: string;
  isEnabled: boolean;
}

export interface AppState {
  currentTab: string;
  isLoading: boolean;
  reports: ReportData[];
  notifications: Notification[];
  user: User | null;
  theme: 'light' | 'dark';
}

export interface Notification {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  title: string;
  message: string;
  timestamp: string;
  isRead: boolean;
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  timestamp: string;
}

export interface ExportOptions {
  format: 'csv' | 'html' | 'json';
  includeHeaders: boolean;
  dateRange?: {
    start: string;
    end: string;
  };
}

export interface FilterOptions {
  search?: string;
  status?: string;
  dateRange?: {
    start: string;
    end: string;
  };
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
  pageSize?: number;
  currentPage?: number;
}