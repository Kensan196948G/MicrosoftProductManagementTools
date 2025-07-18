// Microsoft 365 Management Tools - API Client
// React Frontend と Backend API の統合クライアント

import axios, { AxiosInstance, AxiosResponse, AxiosError } from 'axios';
import { ExecutionResult, AuthState } from '../types/features';

// API設定
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';
const API_TIMEOUT = 30000; // 30秒

// API応答型定義
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
  timestamp: string;
}

export interface FeatureExecutionRequest {
  action: string;
  parameters?: Record<string, any>;
  outputFormat?: 'CSV' | 'HTML' | 'PDF';
}

export interface FeatureExecutionResponse {
  executionId: string;
  status: 'running' | 'completed' | 'failed';
  progress: number;
  message: string;
  outputPath?: string;
  outputUrl?: string;
  reportType?: 'CSV' | 'HTML' | 'PDF';
  data?: any;
}

export interface AuthenticationRequest {
  clientId?: string;
  tenantId?: string;
  certificateThumbprint?: string;
  interactive?: boolean;
}

export interface AuthenticationResponse {
  isAuthenticated: boolean;
  services: {
    graph: boolean;
    exchange: boolean;
    teams: boolean;
    oneDrive: boolean;
  };
  expiresAt: string;
  userInfo?: {
    displayName: string;
    email: string;
    tenantId: string;
  };
}

// APIクライアントクラス
class ApiClient {
  private client: AxiosInstance;
  private authToken: string | null = null;

  constructor() {
    this.client = axios.create({
      baseURL: API_BASE_URL,
      timeout: API_TIMEOUT,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    });

    // レスポンスインターセプター
    this.client.interceptors.response.use(
      (response: AxiosResponse) => {
        return response;
      },
      (error: AxiosError) => {
        return this.handleError(error);
      }
    );

    // リクエストインターセプター
    this.client.interceptors.request.use(
      (config) => {
        // 認証トークンの付与
        if (this.authToken) {
          config.headers.Authorization = `Bearer ${this.authToken}`;
        }

        // リクエストID追加
        config.headers['X-Request-ID'] = this.generateRequestId();

        return config;
      },
      (error) => {
        return Promise.reject(error);
      }
    );
  }

  // エラーハンドリング
  private handleError(error: AxiosError): Promise<never> {
    const errorMessage = error.response?.data?.message || error.message;
    const statusCode = error.response?.status;

    console.error('API Error:', {
      message: errorMessage,
      status: statusCode,
      url: error.config?.url,
      method: error.config?.method,
    });

    // 認証エラー
    if (statusCode === 401) {
      this.authToken = null;
      // 認証状態をリセット
      window.dispatchEvent(new CustomEvent('auth-expired'));
    }

    return Promise.reject({
      message: errorMessage,
      status: statusCode,
      originalError: error,
    });
  }

  // リクエストID生成
  private generateRequestId(): string {
    return `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  // 認証
  async authenticate(request: AuthenticationRequest): Promise<AuthenticationResponse> {
    try {
      const response = await this.client.post<ApiResponse<AuthenticationResponse>>(
        '/api/auth/authenticate',
        request
      );

      if (response.data.success && response.data.data) {
        const authData = response.data.data;
        
        // 認証トークンの保存（実際のトークンが返される場合）
        if ((authData as any).token) {
          this.authToken = (authData as any).token;
        }

        return authData;
      }

      throw new Error(response.data.message || 'Authentication failed');
    } catch (error) {
      throw error;
    }
  }

  // 認証状態確認
  async checkAuthStatus(): Promise<AuthenticationResponse> {
    try {
      const response = await this.client.get<ApiResponse<AuthenticationResponse>>(
        '/api/auth/status'
      );

      if (response.data.success && response.data.data) {
        return response.data.data;
      }

      throw new Error(response.data.message || 'Failed to check auth status');
    } catch (error) {
      throw error;
    }
  }

  // 機能実行
  async executeFeature(request: FeatureExecutionRequest): Promise<FeatureExecutionResponse> {
    try {
      const response = await this.client.post<ApiResponse<FeatureExecutionResponse>>(
        '/api/features/execute',
        request
      );

      if (response.data.success && response.data.data) {
        return response.data.data;
      }

      throw new Error(response.data.message || 'Feature execution failed');
    } catch (error) {
      throw error;
    }
  }

  // 実行状況確認
  async getExecutionStatus(executionId: string): Promise<FeatureExecutionResponse> {
    try {
      const response = await this.client.get<ApiResponse<FeatureExecutionResponse>>(
        `/api/features/execution/${executionId}`
      );

      if (response.data.success && response.data.data) {
        return response.data.data;
      }

      throw new Error(response.data.message || 'Failed to get execution status');
    } catch (error) {
      throw error;
    }
  }

  // 実行キャンセル
  async cancelExecution(executionId: string): Promise<boolean> {
    try {
      const response = await this.client.delete<ApiResponse<boolean>>(
        `/api/features/execution/${executionId}`
      );

      return response.data.success;
    } catch (error) {
      throw error;
    }
  }

  // レポート取得
  async getReport(reportPath: string): Promise<Blob> {
    try {
      const response = await this.client.get(`/api/reports/${reportPath}`, {
        responseType: 'blob',
      });

      return response.data;
    } catch (error) {
      throw error;
    }
  }

  // システム状態確認
  async getSystemStatus(): Promise<{
    status: 'healthy' | 'degraded' | 'down';
    version: string;
    uptime: number;
    services: Record<string, boolean>;
  }> {
    try {
      const response = await this.client.get<ApiResponse<any>>('/api/system/status');

      if (response.data.success && response.data.data) {
        return response.data.data;
      }

      throw new Error(response.data.message || 'Failed to get system status');
    } catch (error) {
      throw error;
    }
  }

  // 設定取得
  async getSettings(): Promise<Record<string, any>> {
    try {
      const response = await this.client.get<ApiResponse<Record<string, any>>>('/api/settings');

      if (response.data.success && response.data.data) {
        return response.data.data;
      }

      throw new Error(response.data.message || 'Failed to get settings');
    } catch (error) {
      throw error;
    }
  }

  // 設定更新
  async updateSettings(settings: Record<string, any>): Promise<boolean> {
    try {
      const response = await this.client.put<ApiResponse<boolean>>('/api/settings', settings);

      return response.data.success;
    } catch (error) {
      throw error;
    }
  }

  // ログ取得
  async getLogs(filters?: {
    level?: 'debug' | 'info' | 'warn' | 'error';
    startDate?: string;
    endDate?: string;
    limit?: number;
  }): Promise<any[]> {
    try {
      const response = await this.client.get<ApiResponse<any[]>>('/api/logs', {
        params: filters,
      });

      if (response.data.success && response.data.data) {
        return response.data.data;
      }

      throw new Error(response.data.message || 'Failed to get logs');
    } catch (error) {
      throw error;
    }
  }

  // ヘルスチェック
  async healthCheck(): Promise<boolean> {
    try {
      const response = await this.client.get('/api/health');
      return response.status === 200;
    } catch (error) {
      return false;
    }
  }

  // 認証トークンリセット
  resetAuth(): void {
    this.authToken = null;
  }
}

// シングルトンインスタンス
export const apiClient = new ApiClient();

// エラー型定義
export interface ApiError {
  message: string;
  status?: number;
  code?: string;
  originalError?: any;
}

// カスタムエラークラス
export class ApiClientError extends Error {
  public status?: number;
  public code?: string;
  public originalError?: any;

  constructor(message: string, status?: number, code?: string, originalError?: any) {
    super(message);
    this.name = 'ApiClientError';
    this.status = status;
    this.code = code;
    this.originalError = originalError;
  }
}

// ユーティリティ関数
export const isApiError = (error: any): error is ApiError => {
  return error && typeof error.message === 'string';
};

export const getErrorMessage = (error: unknown): string => {
  if (isApiError(error)) {
    return error.message;
  }
  
  if (error instanceof Error) {
    return error.message;
  }
  
  return 'Unknown error occurred';
};

export default apiClient;