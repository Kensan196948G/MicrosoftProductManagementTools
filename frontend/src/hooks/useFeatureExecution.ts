// Microsoft 365 Management Tools - 機能実行Hook
import { useState, useCallback, useRef } from 'react';
import { apiClient, FeatureExecutionRequest, FeatureExecutionResponse } from '../services/api';
import { toast } from 'react-hot-toast';

export interface ExecutionState {
  isExecuting: boolean;
  progress: number;
  message: string;
  currentExecution: FeatureExecutionResponse | null;
  error: string | null;
  result: any | null;
}

export interface ExecutionActions {
  executeFeature: (action: string, options?: Record<string, any>) => Promise<void>;
  cancelExecution: () => Promise<void>;
  clearResult: () => void;
  downloadResult: (filePath: string) => Promise<void>;
}

export const useFeatureExecution = (): ExecutionState & ExecutionActions => {
  const [state, setState] = useState<ExecutionState>({
    isExecuting: false,
    progress: 0,
    message: '',
    currentExecution: null,
    error: null,
    result: null,
  });

  const pollingInterval = useRef<NodeJS.Timeout | null>(null);
  const currentExecutionId = useRef<string | null>(null);

  // 実行状況ポーリング
  const pollExecutionStatus = useCallback(async (executionId: string) => {
    try {
      const status = await apiClient.getExecutionStatus(executionId);
      
      setState(prev => ({
        ...prev,
        progress: status.progress,
        message: status.message,
        currentExecution: status,
      }));

      // 実行完了またはエラーの場合
      if (status.status === 'completed' || status.status === 'failed') {
        if (pollingInterval.current) {
          clearInterval(pollingInterval.current);
          pollingInterval.current = null;
        }

        setState(prev => ({
          ...prev,
          isExecuting: false,
          progress: status.status === 'completed' ? 100 : prev.progress,
          result: status.data,
          error: status.status === 'failed' ? status.message : null,
        }));

        if (status.status === 'completed') {
          toast.success('機能実行が完了しました');
          
          // 結果ファイルがある場合は自動ダウンロード提案
          if (status.outputPath) {
            toast.success(
              `レポートが生成されました: ${status.outputPath}`,
              { duration: 10000 }
            );
          }
        } else {
          toast.error(`実行に失敗しました: ${status.message}`);
        }

        currentExecutionId.current = null;
      }
    } catch (error: any) {
      console.error('Failed to poll execution status:', error);
      
      // ポーリングエラーが続く場合は停止
      if (pollingInterval.current) {
        clearInterval(pollingInterval.current);
        pollingInterval.current = null;
      }

      setState(prev => ({
        ...prev,
        isExecuting: false,
        error: error.message || '実行状況の確認に失敗しました',
      }));

      toast.error('実行状況の確認に失敗しました');
      currentExecutionId.current = null;
    }
  }, []);

  // 機能実行
  const executeFeature = useCallback(async (action: string, options?: Record<string, any>) => {
    try {
      // 既に実行中の場合は停止
      if (state.isExecuting) {
        toast.error('既に実行中の機能があります');
        return;
      }

      setState(prev => ({
        ...prev,
        isExecuting: true,
        progress: 0,
        message: 'Microsoft 365 に接続中...',
        error: null,
        result: null,
        currentExecution: null,
      }));

      const request: FeatureExecutionRequest = {
        action,
        parameters: options,
        outputFormat: 'HTML', // デフォルトはHTML
      };

      const execution = await apiClient.executeFeature(request);
      currentExecutionId.current = execution.executionId;

      setState(prev => ({
        ...prev,
        progress: execution.progress,
        message: execution.message,
        currentExecution: execution,
      }));

      // 実行状況ポーリング開始
      pollingInterval.current = setInterval(() => {
        pollExecutionStatus(execution.executionId);
      }, 2000); // 2秒間隔

    } catch (error: any) {
      console.error('Feature execution failed:', error);
      
      setState(prev => ({
        ...prev,
        isExecuting: false,
        error: error.message || '機能実行に失敗しました',
      }));

      toast.error(error.message || '機能実行に失敗しました');
      currentExecutionId.current = null;
    }
  }, [state.isExecuting, pollExecutionStatus]);

  // 実行キャンセル
  const cancelExecution = useCallback(async () => {
    if (!currentExecutionId.current) {
      return;
    }

    try {
      const success = await apiClient.cancelExecution(currentExecutionId.current);
      
      if (success) {
        if (pollingInterval.current) {
          clearInterval(pollingInterval.current);
          pollingInterval.current = null;
        }

        setState(prev => ({
          ...prev,
          isExecuting: false,
          message: '実行がキャンセルされました',
          error: null,
        }));

        toast.success('実行をキャンセルしました');
        currentExecutionId.current = null;
      } else {
        toast.error('キャンセルに失敗しました');
      }
    } catch (error: any) {
      console.error('Cancel execution failed:', error);
      toast.error(error.message || 'キャンセルに失敗しました');
    }
  }, []);

  // 結果クリア
  const clearResult = useCallback(() => {
    setState(prev => ({
      ...prev,
      result: null,
      error: null,
      progress: 0,
      message: '',
      currentExecution: null,
    }));
  }, []);

  // 結果ダウンロード
  const downloadResult = useCallback(async (filePath: string) => {
    try {
      const blob = await apiClient.getReport(filePath);
      
      // ファイルダウンロード
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filePath.split('/').pop() || 'report';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
      
      toast.success('ファイルをダウンロードしました');
    } catch (error: any) {
      console.error('Download failed:', error);
      toast.error(error.message || 'ダウンロードに失敗しました');
    }
  }, []);

  // クリーンアップ
  const cleanup = useCallback(() => {
    if (pollingInterval.current) {
      clearInterval(pollingInterval.current);
      pollingInterval.current = null;
    }
    currentExecutionId.current = null;
  }, []);

  // コンポーネントのアンマウント時のクリーンアップ
  React.useEffect(() => {
    return cleanup;
  }, [cleanup]);

  return {
    ...state,
    executeFeature,
    cancelExecution,
    clearResult,
    downloadResult,
  };
};

export default useFeatureExecution;