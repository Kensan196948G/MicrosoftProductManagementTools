// Microsoft 365 Management Tools - 統合API サービス  
// Frontend ↔ Backend 統合テスト対応API クライアント

import { apiClient } from './api';
import { toast } from 'react-hot-toast';

// 統合テスト用API インターフェース
export interface IntegrationTestRequest {
  testSuite: string;
  features: string[];
  testData?: Record<string, any>;
  environment: 'development' | 'testing' | 'production';
}

export interface IntegrationTestResponse {
  testId: string;
  status: 'running' | 'completed' | 'failed';
  results: {
    backend: TestResult;
    frontend: TestResult;
    integration: TestResult;
  };
  metrics: {
    duration: number;
    coverage: number;
    performance: PerformanceMetrics;
  };
}

export interface TestResult {
  passed: number;
  failed: number;
  skipped: number;
  coverage: number;
  duration: number;
  errors: string[];
}

export interface PerformanceMetrics {
  averageResponseTime: number;
  maxResponseTime: number;
  minResponseTime: number;
  throughput: number;
}

// Microsoft 365統合API エンドポイント
export interface M365IntegrationEndpoints {
  // 📊 定期レポート API
  regularReports: {
    daily: '/api/reports/daily';
    weekly: '/api/reports/weekly';
    monthly: '/api/reports/monthly';
    yearly: '/api/reports/yearly';
    testExecution: '/api/reports/test-execution';
  };

  // 🔍 分析レポート API
  analyticsReports: {
    license: '/api/analytics/license';
    usage: '/api/analytics/usage';
    performance: '/api/analytics/performance';
    security: '/api/analytics/security';
    permissions: '/api/analytics/permissions';
  };

  // 👥 Entra ID管理 API
  entraId: {
    users: '/api/entraid/users';
    mfa: '/api/entraid/mfa';
    conditionalAccess: '/api/entraid/conditional-access';
    signInLogs: '/api/entraid/signin-logs';
  };

  // 📧 Exchange Online API
  exchange: {
    mailboxes: '/api/exchange/mailboxes';
    mailFlow: '/api/exchange/mail-flow';
    spamProtection: '/api/exchange/spam-protection';
    deliveryAnalysis: '/api/exchange/delivery-analysis';
  };

  // 💬 Teams管理 API
  teams: {
    usage: '/api/teams/usage';
    settings: '/api/teams/settings';
    meetingQuality: '/api/teams/meeting-quality';
    appAnalysis: '/api/teams/app-analysis';
  };

  // 💾 OneDrive管理 API
  oneDrive: {
    storage: '/api/onedrive/storage';
    sharing: '/api/onedrive/sharing';
    syncErrors: '/api/onedrive/sync-errors';
    externalSharing: '/api/onedrive/external-sharing';
  };
}

class IntegrationApiService {
  private endpoints: M365IntegrationEndpoints;

  constructor() {
    this.endpoints = {
      regularReports: {
        daily: '/api/reports/daily',
        weekly: '/api/reports/weekly',
        monthly: '/api/reports/monthly',
        yearly: '/api/reports/yearly',
        testExecution: '/api/reports/test-execution',
      },
      analyticsReports: {
        license: '/api/analytics/license',
        usage: '/api/analytics/usage',
        performance: '/api/analytics/performance',
        security: '/api/analytics/security',
        permissions: '/api/analytics/permissions',
      },
      entraId: {
        users: '/api/entraid/users',
        mfa: '/api/entraid/mfa',
        conditionalAccess: '/api/entraid/conditional-access',
        signInLogs: '/api/entraid/signin-logs',
      },
      exchange: {
        mailboxes: '/api/exchange/mailboxes',
        mailFlow: '/api/exchange/mail-flow',
        spamProtection: '/api/exchange/spam-protection',
        deliveryAnalysis: '/api/exchange/delivery-analysis',
      },
      teams: {
        usage: '/api/teams/usage',
        settings: '/api/teams/settings',
        meetingQuality: '/api/teams/meeting-quality',
        appAnalysis: '/api/teams/app-analysis',
      },
      oneDrive: {
        storage: '/api/onedrive/storage',
        sharing: '/api/onedrive/sharing',
        syncErrors: '/api/onedrive/sync-errors',
        externalSharing: '/api/onedrive/external-sharing',
      },
    };
  }

  // 統合テスト実行
  async runIntegrationTest(request: IntegrationTestRequest): Promise<IntegrationTestResponse> {
    try {
      toast.info(`統合テスト開始: ${request.testSuite}`);
      
      const response = await apiClient.client.post<IntegrationTestResponse>(
        '/api/integration/test/run',
        request
      );

      if (response.data) {
        toast.success('統合テスト開始成功');
        return response.data;
      }

      throw new Error('統合テスト開始に失敗しました');
    } catch (error: any) {
      toast.error(`統合テスト開始失敗: ${error.message}`);
      throw error;
    }
  }

  // 統合テスト状況確認
  async getIntegrationTestStatus(testId: string): Promise<IntegrationTestResponse> {
    try {
      const response = await apiClient.client.get<IntegrationTestResponse>(
        `/api/integration/test/${testId}/status`
      );

      if (response.data) {
        return response.data;
      }

      throw new Error('統合テスト状況取得に失敗しました');
    } catch (error: any) {
      throw error;
    }
  }

  // 26機能一括テスト実行
  async runAll26FeaturesTest(): Promise<IntegrationTestResponse> {
    const request: IntegrationTestRequest = {
      testSuite: 'all-26-features',
      features: [
        // 📊 定期レポート (5機能)
        'DailyReport', 'WeeklyReport', 'MonthlyReport', 'YearlyReport', 'TestExecution',
        
        // 🔍 分析レポート (5機能)
        'LicenseAnalysis', 'UsageAnalysis', 'PerformanceAnalysis', 'SecurityAnalysis', 'PermissionAudit',
        
        // 👥 Entra ID管理 (4機能)
        'EntraUserList', 'EntraMFAStatus', 'EntraConditionalAccess', 'EntraSignInLogs',
        
        // 📧 Exchange Online管理 (4機能)
        'ExchangeMailboxes', 'ExchangeMailFlow', 'ExchangeSpamProtection', 'ExchangeDeliveryAnalysis',
        
        // 💬 Teams管理 (4機能)
        'TeamsUsage', 'TeamsSettings', 'TeamsMeetingQuality', 'TeamsAppAnalysis',
        
        // 💾 OneDrive管理 (4機能)
        'OneDriveStorage', 'OneDriveSharing', 'OneDriveSyncErrors', 'OneDriveExternalSharing'
      ],
      environment: process.env.NODE_ENV === 'production' ? 'production' : 'testing'
    };

    return this.runIntegrationTest(request);
  }

  // カテゴリ別テスト実行
  async runCategoryTest(category: keyof M365IntegrationEndpoints): Promise<IntegrationTestResponse> {
    const categoryFeatures = {
      regularReports: ['DailyReport', 'WeeklyReport', 'MonthlyReport', 'YearlyReport', 'TestExecution'],
      analyticsReports: ['LicenseAnalysis', 'UsageAnalysis', 'PerformanceAnalysis', 'SecurityAnalysis', 'PermissionAudit'],
      entraId: ['EntraUserList', 'EntraMFAStatus', 'EntraConditionalAccess', 'EntraSignInLogs'],
      exchange: ['ExchangeMailboxes', 'ExchangeMailFlow', 'ExchangeSpamProtection', 'ExchangeDeliveryAnalysis'],
      teams: ['TeamsUsage', 'TeamsSettings', 'TeamsMeetingQuality', 'TeamsAppAnalysis'],
      oneDrive: ['OneDriveStorage', 'OneDriveSharing', 'OneDriveSyncErrors', 'OneDriveExternalSharing']
    };

    const request: IntegrationTestRequest = {
      testSuite: `category-${category}`,
      features: categoryFeatures[category],
      environment: 'testing'
    };

    return this.runIntegrationTest(request);
  }

  // API エンドポイント接続確認
  async checkApiConnectivity(): Promise<{ [key: string]: boolean }> {
    const results: { [key: string]: boolean } = {};
    
    try {
      // 各カテゴリのヘルスチェック
      for (const [category, endpoints] of Object.entries(this.endpoints)) {
        try {
          const endpoint = Object.values(endpoints)[0] + '/health';
          await apiClient.client.get(endpoint);
          results[category] = true;
        } catch {
          results[category] = false;
        }
      }
      
      return results;
    } catch (error) {
      toast.error('API接続確認に失敗しました');
      throw error;
    }
  }

  // パフォーマンス監視
  async monitorPerformance(testId: string): Promise<PerformanceMetrics> {
    try {
      const response = await apiClient.client.get<PerformanceMetrics>(
        `/api/integration/test/${testId}/performance`
      );

      if (response.data) {
        return response.data;
      }

      throw new Error('パフォーマンス監視データ取得に失敗しました');
    } catch (error: any) {
      throw error;
    }
  }

  // テスト結果レポート取得
  async getTestReport(testId: string, format: 'html' | 'json' | 'pdf' = 'html'): Promise<Blob> {
    try {
      const response = await apiClient.client.get(
        `/api/integration/test/${testId}/report`,
        {
          params: { format },
          responseType: 'blob'
        }
      );

      return response.data;
    } catch (error: any) {
      toast.error(`テストレポート取得失敗: ${error.message}`);
      throw error;
    }
  }

  // リアルタイム統合テスト監視
  async watchIntegrationTest(testId: string, onUpdate: (status: IntegrationTestResponse) => void): Promise<void> {
    const pollInterval = setInterval(async () => {
      try {
        const status = await this.getIntegrationTestStatus(testId);
        onUpdate(status);
        
        if (status.status === 'completed' || status.status === 'failed') {
          clearInterval(pollInterval);
        }
      } catch (error) {
        console.error('統合テスト監視エラー:', error);
        clearInterval(pollInterval);
      }
    }, 2000); // 2秒間隔
  }

  // エンドポイント一覧取得
  getEndpoints(): M365IntegrationEndpoints {
    return this.endpoints;
  }

  // バックエンド連携確認
  async verifyBackendIntegration(): Promise<{
    pytest: boolean;
    fastapi: boolean;
    microsoft365: boolean;
    powerShell: boolean;
  }> {
    try {
      const response = await apiClient.client.get('/api/integration/verify');
      
      if (response.data) {
        return response.data;
      }

      throw new Error('バックエンド統合確認に失敗しました');
    } catch (error: any) {
      toast.error(`バックエンド統合確認失敗: ${error.message}`);
      throw error;
    }
  }
}

// シングルトンインスタンス
export const integrationApiService = new IntegrationApiService();

// React Hook
export const useIntegrationApi = () => {
  return {
    runIntegrationTest: integrationApiService.runIntegrationTest.bind(integrationApiService),
    getIntegrationTestStatus: integrationApiService.getIntegrationTestStatus.bind(integrationApiService),
    runAll26FeaturesTest: integrationApiService.runAll26FeaturesTest.bind(integrationApiService),
    runCategoryTest: integrationApiService.runCategoryTest.bind(integrationApiService),
    checkApiConnectivity: integrationApiService.checkApiConnectivity.bind(integrationApiService),
    monitorPerformance: integrationApiService.monitorPerformance.bind(integrationApiService),
    getTestReport: integrationApiService.getTestReport.bind(integrationApiService),
    watchIntegrationTest: integrationApiService.watchIntegrationTest.bind(integrationApiService),
    verifyBackendIntegration: integrationApiService.verifyBackendIntegration.bind(integrationApiService),
  };
};

export default integrationApiService;