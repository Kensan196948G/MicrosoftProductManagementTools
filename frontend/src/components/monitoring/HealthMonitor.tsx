// Microsoft 365 Management Tools - Health Monitor Component
// 24/7本格運用監視システム - ヘルスモニタリング

import React, { useState, useEffect, useCallback } from 'react';
import { motion } from 'framer-motion';
import { clsx } from 'clsx';
import { useQuery } from '@tanstack/react-query';
import { LoadingSpinner } from '../shared/LoadingSpinner';

interface HealthStatus {
  status: 'healthy' | 'warning' | 'critical' | 'unknown';
  timestamp: string;
  responseTime: number;
  message?: string;
}

interface SystemHealth {
  overall: HealthStatus;
  frontend: HealthStatus;
  backend: HealthStatus;
  database: HealthStatus;
  api: HealthStatus;
  authentication: HealthStatus;
  microsoft365: HealthStatus;
}

interface MetricData {
  timestamp: string;
  value: number;
  unit: string;
  threshold?: number;
}

interface SystemMetrics {
  cpu: MetricData;
  memory: MetricData;
  disk: MetricData;
  network: MetricData;
  activeUsers: MetricData;
  errorRate: MetricData;
  avgResponseTime: MetricData;
}

// ヘルスチェック API
const healthCheckAPI = {
  async checkSystemHealth(): Promise<SystemHealth> {
    const response = await fetch('/api/health/system');
    if (!response.ok) {
      throw new Error('Health check failed');
    }
    return response.json();
  },

  async getSystemMetrics(): Promise<SystemMetrics> {
    const response = await fetch('/api/health/metrics');
    if (!response.ok) {
      throw new Error('Metrics fetch failed');
    }
    return response.json();
  },

  async getHealthHistory(hours: number = 24): Promise<HealthStatus[]> {
    const response = await fetch(`/api/health/history?hours=${hours}`);
    if (!response.ok) {
      throw new Error('Health history fetch failed');
    }
    return response.json();
  }
};

export const HealthMonitor: React.FC = () => {
  const [refreshInterval, setRefreshInterval] = useState(30000); // 30秒間隔
  const [alertsEnabled, setAlertsEnabled] = useState(true);
  const [showDetails, setShowDetails] = useState(false);

  // システムヘルス状態の取得
  const { 
    data: systemHealth, 
    isLoading: healthLoading, 
    error: healthError,
    refetch: refetchHealth
  } = useQuery({
    queryKey: ['systemHealth'],
    queryFn: healthCheckAPI.checkSystemHealth,
    refetchInterval: refreshInterval,
    refetchOnWindowFocus: true,
    staleTime: 10000, // 10秒間はキャッシュを使用
  });

  // システムメトリクスの取得
  const { 
    data: systemMetrics, 
    isLoading: metricsLoading,
    error: metricsError
  } = useQuery({
    queryKey: ['systemMetrics'],
    queryFn: healthCheckAPI.getSystemMetrics,
    refetchInterval: refreshInterval,
    refetchOnWindowFocus: true,
    staleTime: 10000,
  });

  // ヘルス履歴の取得
  const { 
    data: healthHistory, 
    isLoading: historyLoading 
  } = useQuery({
    queryKey: ['healthHistory'],
    queryFn: () => healthCheckAPI.getHealthHistory(24),
    refetchInterval: 300000, // 5分間隔
    staleTime: 60000, // 1分間はキャッシュを使用
  });

  // アラート通知
  const showAlert = useCallback((message: string, type: 'warning' | 'error') => {
    if (!alertsEnabled) return;

    // ブラウザ通知
    if (Notification.permission === 'granted') {
      new Notification(`システム${type === 'error' ? 'エラー' : '警告'}`, {
        body: message,
        icon: '/favicon.ico',
        badge: '/favicon.ico',
      });
    }

    // コンソールログ
    console[type](`[Health Monitor] ${message}`);
  }, [alertsEnabled]);

  // ヘルス状態の監視
  useEffect(() => {
    if (!systemHealth) return;

    const { overall, backend, database, api, authentication, microsoft365 } = systemHealth;

    // 全体的な健全性チェック
    if (overall.status === 'critical') {
      showAlert('システムが重大な問題を検出しました', 'error');
    } else if (overall.status === 'warning') {
      showAlert('システムで軽微な問題が発生しています', 'warning');
    }

    // 個別コンポーネントの監視
    const criticalComponents = [backend, database, api, authentication, microsoft365];
    criticalComponents.forEach((component, index) => {
      const componentNames = ['バックエンド', 'データベース', 'API', '認証', 'Microsoft 365'];
      if (component.status === 'critical') {
        showAlert(`${componentNames[index]}で重大な問題が発生しています`, 'error');
      }
    });
  }, [systemHealth, showAlert]);

  // 通知権限の要求
  useEffect(() => {
    if (alertsEnabled && Notification.permission === 'default') {
      Notification.requestPermission();
    }
  }, [alertsEnabled]);

  // ステータスインジケーターの色
  const getStatusColor = (status: HealthStatus['status']) => {
    switch (status) {
      case 'healthy': return 'bg-green-500';
      case 'warning': return 'bg-yellow-500';
      case 'critical': return 'bg-red-500';
      default: return 'bg-gray-500';
    }
  };

  // ステータステキスト
  const getStatusText = (status: HealthStatus['status']) => {
    switch (status) {
      case 'healthy': return '正常';
      case 'warning': return '警告';
      case 'critical': return '重大';
      default: return '不明';
    }
  };

  // メトリクスの表示色
  const getMetricColor = (metric: MetricData) => {
    if (!metric.threshold) return 'text-blue-600';
    
    const percentage = (metric.value / metric.threshold) * 100;
    if (percentage >= 90) return 'text-red-600';
    if (percentage >= 70) return 'text-yellow-600';
    return 'text-green-600';
  };

  if (healthLoading && !systemHealth) {
    return (
      <div className="bg-white rounded-lg shadow-sm p-6">
        <LoadingSpinner message="ヘルスモニター初期化中..." />
      </div>
    );
  }

  if (healthError) {
    return (
      <div className="bg-white rounded-lg shadow-sm p-6">
        <div className="flex items-center space-x-2 text-red-600">
          <span className="text-2xl">⚠️</span>
          <div>
            <h3 className="font-semibold">ヘルスモニター接続エラー</h3>
            <p className="text-sm text-gray-600">
              監視システムに接続できません。システム管理者にお問い合わせください。
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="bg-white rounded-lg shadow-sm p-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="flex items-center space-x-2">
              <motion.div
                className={clsx('w-4 h-4 rounded-full', getStatusColor(systemHealth?.overall.status || 'unknown'))}
                animate={{ scale: [1, 1.1, 1] }}
                transition={{ duration: 2, repeat: Infinity }}
              />
              <h2 className="text-xl font-semibold text-gray-900">
                システム監視ダッシュボード
              </h2>
            </div>
            <span className="text-sm text-gray-500">
              {systemHealth?.overall.status && getStatusText(systemHealth.overall.status)}
            </span>
          </div>

          <div className="flex items-center space-x-4">
            {/* リフレッシュ間隔設定 */}
            <select
              value={refreshInterval}
              onChange={(e) => setRefreshInterval(Number(e.target.value))}
              className="text-sm border border-gray-300 rounded-md px-3 py-1"
            >
              <option value={10000}>10秒</option>
              <option value={30000}>30秒</option>
              <option value={60000}>1分</option>
              <option value={300000}>5分</option>
            </select>

            {/* アラート設定 */}
            <label className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={alertsEnabled}
                onChange={(e) => setAlertsEnabled(e.target.checked)}
                className="rounded border-gray-300"
              />
              <span className="text-sm text-gray-700">アラート</span>
            </label>

            {/* 詳細表示切り替え */}
            <button
              onClick={() => setShowDetails(!showDetails)}
              className="text-sm text-blue-600 hover:text-blue-700"
            >
              {showDetails ? '簡易表示' : '詳細表示'}
            </button>

            {/* 手動リフレッシュ */}
            <button
              onClick={() => refetchHealth()}
              className="text-sm bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded-md"
            >
              更新
            </button>
          </div>
        </div>

        {/* 最終更新時刻 */}
        <div className="mt-2 text-sm text-gray-500">
          最終更新: {systemHealth?.overall.timestamp ? new Date(systemHealth.overall.timestamp).toLocaleString('ja-JP') : '-'}
        </div>
      </div>

      {/* システムコンポーネント状態 */}
      <div className="bg-white rounded-lg shadow-sm p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">コンポーネント状態</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {systemHealth && Object.entries(systemHealth).map(([key, status]) => {
            if (key === 'overall') return null;
            
            const componentNames: Record<string, string> = {
              frontend: 'フロントエンド',
              backend: 'バックエンド',
              database: 'データベース',
              api: 'API',
              authentication: '認証',
              microsoft365: 'Microsoft 365'
            };

            return (
              <motion.div
                key={key}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="border border-gray-200 rounded-lg p-4"
              >
                <div className="flex items-center justify-between mb-2">
                  <span className="font-medium text-gray-900">
                    {componentNames[key] || key}
                  </span>
                  <div className={clsx('w-3 h-3 rounded-full', getStatusColor(status.status))} />
                </div>
                
                <div className="space-y-1 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-500">状態:</span>
                    <span className={clsx(
                      'font-medium',
                      status.status === 'healthy' ? 'text-green-600' :
                      status.status === 'warning' ? 'text-yellow-600' : 'text-red-600'
                    )}>
                      {getStatusText(status.status)}
                    </span>
                  </div>
                  
                  <div className="flex justify-between">
                    <span className="text-gray-500">応答時間:</span>
                    <span className="text-gray-900">{status.responseTime}ms</span>
                  </div>
                  
                  {status.message && (
                    <div className="mt-2 text-xs text-gray-600">
                      {status.message}
                    </div>
                  )}
                </div>
              </motion.div>
            );
          })}
        </div>
      </div>

      {/* システムメトリクス */}
      {systemMetrics && (
        <div className="bg-white rounded-lg shadow-sm p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">システムメトリクス</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {Object.entries(systemMetrics).map(([key, metric]) => {
              const metricNames: Record<string, string> = {
                cpu: 'CPU使用率',
                memory: 'メモリ使用率',
                disk: 'ディスク使用率',
                network: 'ネットワーク使用率',
                activeUsers: 'アクティブユーザー',
                errorRate: 'エラー率',
                avgResponseTime: '平均応答時間'
              };

              return (
                <motion.div
                  key={key}
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  className="border border-gray-200 rounded-lg p-4"
                >
                  <div className="text-sm text-gray-500 mb-1">
                    {metricNames[key] || key}
                  </div>
                  <div className={clsx('text-2xl font-bold', getMetricColor(metric))}>
                    {metric.value}
                    <span className="text-sm text-gray-500 ml-1">{metric.unit}</span>
                  </div>
                  
                  {metric.threshold && (
                    <div className="mt-2">
                      <div className="w-full bg-gray-200 rounded-full h-2">
                        <div
                          className={clsx(
                            'h-2 rounded-full transition-all duration-500',
                            (metric.value / metric.threshold) * 100 >= 90 ? 'bg-red-500' :
                            (metric.value / metric.threshold) * 100 >= 70 ? 'bg-yellow-500' : 'bg-green-500'
                          )}
                          style={{ width: `${Math.min((metric.value / metric.threshold) * 100, 100)}%` }}
                        />
                      </div>
                      <div className="text-xs text-gray-500 mt-1">
                        閾値: {metric.threshold} {metric.unit}
                      </div>
                    </div>
                  )}
                </motion.div>
              );
            })}
          </div>
        </div>
      )}

      {/* ヘルス履歴 */}
      {showDetails && healthHistory && (
        <div className="bg-white rounded-lg shadow-sm p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">24時間ヘルス履歴</h3>
          <div className="space-y-2">
            {healthHistory.slice(0, 10).map((status, index) => (
              <div key={index} className="flex items-center justify-between py-2 border-b border-gray-100">
                <div className="flex items-center space-x-3">
                  <div className={clsx('w-2 h-2 rounded-full', getStatusColor(status.status))} />
                  <span className="text-sm text-gray-900">
                    {getStatusText(status.status)}
                  </span>
                  {status.message && (
                    <span className="text-sm text-gray-500">- {status.message}</span>
                  )}
                </div>
                <div className="text-sm text-gray-500">
                  {new Date(status.timestamp).toLocaleString('ja-JP')}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default HealthMonitor;