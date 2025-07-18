// Microsoft 365 Management Tools - API Hooks
// React Query を使用したAPIデータ管理

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient, FeatureExecutionRequest, FeatureExecutionResponse, AuthenticationRequest, AuthenticationResponse, ApiError } from '../services/api';
import { useAppStore } from '../store/appStore';
import { useCallback, useEffect, useState } from 'react';
import toast from 'react-hot-toast';

// Query Keys
export const QUERY_KEYS = {
  AUTH_STATUS: ['auth', 'status'],
  SYSTEM_STATUS: ['system', 'status'],
  SETTINGS: ['settings'],
  LOGS: ['logs'],
  EXECUTION_STATUS: (id: string) => ['execution', 'status', id],
  REPORTS: ['reports'],
} as const;

// 認証フック
export const useAuth = () => {
  const { auth, setAuth } = useAppStore();
  const queryClient = useQueryClient();

  // 認証状態確認
  const { data: authStatus, isLoading: isCheckingAuth, error: authError } = useQuery({
    queryKey: QUERY_KEYS.AUTH_STATUS,
    queryFn: () => apiClient.checkAuthStatus(),
    retry: 1,
    refetchInterval: 5 * 60 * 1000, // 5分間隔
    staleTime: 1 * 60 * 1000, // 1分間キャッシュ
  });

  // 認証実行
  const authMutation = useMutation({
    mutationFn: (request: AuthenticationRequest) => apiClient.authenticate(request),
    onSuccess: (data: AuthenticationResponse) => {
      setAuth({
        isConnected: data.isAuthenticated,
        lastConnected: new Date(),
        connectionStatus: 'connected',
        services: data.services,
      });
      
      // キャッシュを更新
      queryClient.setQueryData(QUERY_KEYS.AUTH_STATUS, data);
      
      toast.success('認証に成功しました');
    },
    onError: (error: ApiError) => {
      setAuth({
        isConnected: false,
        connectionStatus: 'error',
        services: {
          graph: false,
          exchange: false,
          teams: false,
          oneDrive: false,
        },
      });
      
      toast.error(`認証エラー: ${error.message}`);
    },
  });

  // 認証状態をストアに同期
  useEffect(() => {
    if (authStatus) {
      setAuth({
        isConnected: authStatus.isAuthenticated,
        lastConnected: authStatus.isAuthenticated ? new Date() : auth.lastConnected,
        connectionStatus: authStatus.isAuthenticated ? 'connected' : 'disconnected',
        services: authStatus.services,
      });
    }
  }, [authStatus, setAuth, auth.lastConnected]);

  // 認証期限切れイベントの監視
  useEffect(() => {
    const handleAuthExpired = () => {
      setAuth({
        isConnected: false,
        connectionStatus: 'disconnected',
        services: {
          graph: false,
          exchange: false,
          teams: false,
          oneDrive: false,
        },
      });
      
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.AUTH_STATUS });
      toast.error('認証が期限切れです。再度ログインしてください。');
    };

    window.addEventListener('auth-expired', handleAuthExpired);
    return () => window.removeEventListener('auth-expired', handleAuthExpired);
  }, [setAuth, queryClient]);

  return {
    authStatus,
    isCheckingAuth,
    authError,
    authenticate: authMutation.mutate,
    isAuthenticating: authMutation.isPending,
    authenticationError: authMutation.error,
  };
};

// 機能実行フック
export const useFeatureExecution = () => {
  const [executionId, setExecutionId] = useState<string | null>(null);
  const { setProgress } = useAppStore();

  // 機能実行
  const executeMutation = useMutation({
    mutationFn: (request: FeatureExecutionRequest) => apiClient.executeFeature(request),
    onSuccess: (data: FeatureExecutionResponse) => {
      setExecutionId(data.executionId);
      
      // 初期進捗状態設定
      setProgress({
        isVisible: true,
        current: data.progress,
        total: 100,
        message: data.message,
        stage: data.status === 'running' ? 'processing' : 'completed',
      });
      
      toast.success('機能実行を開始しました');
    },
    onError: (error: ApiError) => {
      setProgress({
        isVisible: true,
        current: 0,
        total: 100,
        message: `エラー: ${error.message}`,
        stage: 'error',
      });
      
      toast.error(`実行エラー: ${error.message}`);
    },
  });

  // 実行状況監視
  const { data: executionStatus } = useQuery({
    queryKey: QUERY_KEYS.EXECUTION_STATUS(executionId || ''),
    queryFn: () => apiClient.getExecutionStatus(executionId!),
    enabled: !!executionId,
    refetchInterval: (data) => {
      // 実行中は1秒間隔で監視
      if (data?.status === 'running') {
        return 1000;
      }
      // 完了/失敗時は停止
      return false;
    },
    retry: 1,
  });

  // 実行状況をストアに同期
  useEffect(() => {
    if (executionStatus) {
      const stage = executionStatus.status === 'running' ? 'processing' : 
                   executionStatus.status === 'completed' ? 'completed' : 'error';
      
      setProgress({
        isVisible: true,
        current: executionStatus.progress,
        total: 100,
        message: executionStatus.message,
        stage,
      });

      // 完了時の処理
      if (executionStatus.status === 'completed') {
        toast.success('機能実行が完了しました');
        
        if (executionStatus.outputUrl) {
          toast.success(
            <div>
              <p>レポートが生成されました</p>
              <a href={executionStatus.outputUrl} target="_blank" rel="noopener noreferrer">
                レポートを開く
              </a>
            </div>
          );
        }
      }
    }
  }, [executionStatus, setProgress]);

  // 実行キャンセル
  const cancelMutation = useMutation({
    mutationFn: (id: string) => apiClient.cancelExecution(id),
    onSuccess: () => {
      setExecutionId(null);
      setProgress({
        isVisible: false,
        current: 0,
        total: 100,
        message: '',
        stage: 'connecting',
      });
      
      toast.success('実行をキャンセルしました');
    },
    onError: (error: ApiError) => {
      toast.error(`キャンセルエラー: ${error.message}`);
    },
  });

  return {
    executeFeature: executeMutation.mutate,
    isExecuting: executeMutation.isPending,
    executionError: executeMutation.error,
    executionStatus,
    cancelExecution: useCallback(
      () => executionId && cancelMutation.mutate(executionId),
      [executionId, cancelMutation]
    ),
    isCanceling: cancelMutation.isPending,
  };
};

// システム状態フック
export const useSystemStatus = () => {
  const { data: systemStatus, isLoading, error } = useQuery({
    queryKey: QUERY_KEYS.SYSTEM_STATUS,
    queryFn: () => apiClient.getSystemStatus(),
    refetchInterval: 30000, // 30秒間隔
    staleTime: 10000, // 10秒間キャッシュ
    retry: 3,
  });

  return {
    systemStatus,
    isLoading,
    error,
    isHealthy: systemStatus?.status === 'healthy',
  };
};

// 設定フック
export const useSettings = () => {
  const queryClient = useQueryClient();

  const { data: settings, isLoading, error } = useQuery({
    queryKey: QUERY_KEYS.SETTINGS,
    queryFn: () => apiClient.getSettings(),
    staleTime: 5 * 60 * 1000, // 5分間キャッシュ
  });

  const updateMutation = useMutation({
    mutationFn: (newSettings: Record<string, any>) => apiClient.updateSettings(newSettings),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: QUERY_KEYS.SETTINGS });
      toast.success('設定を更新しました');
    },
    onError: (error: ApiError) => {
      toast.error(`設定更新エラー: ${error.message}`);
    },
  });

  return {
    settings,
    isLoading,
    error,
    updateSettings: updateMutation.mutate,
    isUpdating: updateMutation.isPending,
  };
};

// ログフック
export const useLogs = (filters?: {
  level?: 'debug' | 'info' | 'warn' | 'error';
  startDate?: string;
  endDate?: string;
  limit?: number;
}) => {
  const { data: logs, isLoading, error } = useQuery({
    queryKey: [...QUERY_KEYS.LOGS, filters],
    queryFn: () => apiClient.getLogs(filters),
    staleTime: 30000, // 30秒間キャッシュ
    refetchInterval: 60000, // 1分間隔
  });

  return {
    logs,
    isLoading,
    error,
  };
};

// レポートダウンロードフック
export const useReportDownload = () => {
  const downloadMutation = useMutation({
    mutationFn: (reportPath: string) => apiClient.getReport(reportPath),
    onSuccess: (blob: Blob, reportPath: string) => {
      // ファイルダウンロード
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = reportPath.split('/').pop() || 'report';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(url);
      
      toast.success('レポートをダウンロードしました');
    },
    onError: (error: ApiError) => {
      toast.error(`ダウンロードエラー: ${error.message}`);
    },
  });

  return {
    downloadReport: downloadMutation.mutate,
    isDownloading: downloadMutation.isPending,
    downloadError: downloadMutation.error,
  };
};

// ヘルスチェックフック
export const useHealthCheck = () => {
  const [isHealthy, setIsHealthy] = useState<boolean>(true);
  const [lastCheck, setLastCheck] = useState<Date>(new Date());

  useEffect(() => {
    const checkHealth = async () => {
      try {
        const healthy = await apiClient.healthCheck();
        setIsHealthy(healthy);
        setLastCheck(new Date());
      } catch (error) {
        setIsHealthy(false);
        setLastCheck(new Date());
      }
    };

    // 初回チェック
    checkHealth();

    // 定期チェック (30秒間隔)
    const interval = setInterval(checkHealth, 30000);

    return () => clearInterval(interval);
  }, []);

  return {
    isHealthy,
    lastCheck,
  };
};

// カスタムエラーハンドリングフック
export const useApiError = () => {
  const handleError = useCallback((error: unknown) => {
    if (error instanceof Error) {
      toast.error(error.message);
    } else {
      toast.error('予期しないエラーが発生しました');
    }
  }, []);

  return {
    handleError,
  };
};