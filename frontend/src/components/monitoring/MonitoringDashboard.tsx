// Microsoft 365 Management Tools - Monitoring Dashboard Component
// 24/7本格運用監視システム - 統合監視ダッシュボード

import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { clsx } from 'clsx';
import { useQuery } from '@tanstack/react-query';
import { LoadingSpinner } from '../shared/LoadingSpinner';
import { HealthMonitor } from './HealthMonitor';
import { PerformanceMonitor } from './PerformanceMonitor';
import { AlertManager } from './AlertManager';
import { LogViewer } from './LogViewer';

interface MonitoringOverview {
  systemStatus: 'healthy' | 'warning' | 'critical';
  uptime: number; // seconds
  totalAlerts: number;
  criticalAlerts: number;
  errorRate: number;
  avgResponseTime: number;
  activeUsers: number;
  lastUpdate: string;
}

interface QuickStats {
  cpu: number;
  memory: number;
  disk: number;
  network: number;
  throughput: number;
  errors: number;
}

// 監視データAPI
const monitoringAPI = {
  async getOverview(): Promise<MonitoringOverview> {
    const response = await fetch('/api/monitoring/overview');
    if (!response.ok) {
      throw new Error('Failed to fetch monitoring overview');
    }
    return response.json();
  },

  async getQuickStats(): Promise<QuickStats> {
    const response = await fetch('/api/monitoring/quick-stats');
    if (!response.ok) {
      throw new Error('Failed to fetch quick stats');
    }
    return response.json();
  }
};

type MonitoringView = 'overview' | 'health' | 'performance' | 'alerts' | 'logs';

export const MonitoringDashboard: React.FC = () => {
  const [currentView, setCurrentView] = useState<MonitoringView>('overview');
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [refreshInterval, setRefreshInterval] = useState(30000); // 30秒

  // 監視概要データの取得
  const { 
    data: overview, 
    isLoading: overviewLoading, 
    error: overviewError 
  } = useQuery({
    queryKey: ['monitoringOverview'],
    queryFn: monitoringAPI.getOverview,
    refetchInterval: refreshInterval,
    refetchOnWindowFocus: true,
    staleTime: 10000,
  });

  // クイック統計の取得
  const { 
    data: quickStats, 
    isLoading: statsLoading 
  } = useQuery({
    queryKey: ['quickStats'],
    queryFn: monitoringAPI.getQuickStats,
    refetchInterval: refreshInterval,
    refetchOnWindowFocus: true,
    staleTime: 10000,
  });

  // フルスクリーン制御
  useEffect(() => {
    const handleKeyPress = (e: KeyboardEvent) => {
      if (e.key === 'F11') {
        e.preventDefault();
        setIsFullscreen(!isFullscreen);
        
        if (!isFullscreen) {
          document.documentElement.requestFullscreen();
        } else {
          document.exitFullscreen();
        }
      }
    };

    window.addEventListener('keydown', handleKeyPress);
    return () => window.removeEventListener('keydown', handleKeyPress);
  }, [isFullscreen]);

  // システム状態の色分け
  const getSystemStatusColor = (status: MonitoringOverview['systemStatus']) => {
    switch (status) {
      case 'healthy': return 'text-green-600 bg-green-50';
      case 'warning': return 'text-yellow-600 bg-yellow-50';
      case 'critical': return 'text-red-600 bg-red-50';
      default: return 'text-gray-600 bg-gray-50';
    }
  };

  // システム状態のアイコン
  const getSystemStatusIcon = (status: MonitoringOverview['systemStatus']) => {
    switch (status) {
      case 'healthy': return '✅';
      case 'warning': return '⚠️';
      case 'critical': return '🚨';
      default: return '❓';
    }
  };

  // アップタイムの表示
  const formatUptime = (seconds: number) => {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    if (days > 0) {
      return `${days}日 ${hours}時間 ${minutes}分`;
    } else if (hours > 0) {
      return `${hours}時間 ${minutes}分`;
    } else {
      return `${minutes}分`;
    }
  };

  // ナビゲーション項目
  const navItems = [
    { id: 'overview', label: '概要', icon: '📊' },
    { id: 'health', label: 'ヘルス', icon: '❤️' },
    { id: 'performance', label: 'パフォーマンス', icon: '⚡' },
    { id: 'alerts', label: 'アラート', icon: '🚨' },
    { id: 'logs', label: 'ログ', icon: '📋' },
  ];

  // メトリクスの色分け
  const getMetricColor = (value: number, thresholds: { warning: number; critical: number }) => {
    if (value >= thresholds.critical) return 'text-red-600';
    if (value >= thresholds.warning) return 'text-yellow-600';
    return 'text-green-600';
  };

  if (overviewLoading && !overview) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <LoadingSpinner message="監視ダッシュボード初期化中..." />
      </div>
    );
  }

  if (overviewError) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="bg-white rounded-lg shadow-sm p-8 max-w-md">
          <div className="text-center">
            <div className="text-6xl mb-4">🚨</div>
            <h2 className="text-2xl font-bold text-gray-900 mb-2">監視システムエラー</h2>
            <p className="text-gray-600 mb-4">
              監視システムに接続できません。システム管理者にお問い合わせください。
            </p>
            <button
              onClick={() => window.location.reload()}
              className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md"
            >
              再読み込み
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={clsx('min-h-screen bg-gray-50', isFullscreen && 'p-0')}>
      {/* ヘッダー */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center space-x-4">
              <h1 className="text-2xl font-bold text-gray-900">
                Microsoft 365 Management Tools - 監視ダッシュボード
              </h1>
              
              {overview && (
                <div className={clsx(
                  'flex items-center space-x-2 px-3 py-1 rounded-full text-sm font-medium',
                  getSystemStatusColor(overview.systemStatus)
                )}>
                  <span>{getSystemStatusIcon(overview.systemStatus)}</span>
                  <span>
                    {overview.systemStatus === 'healthy' ? '正常' :
                     overview.systemStatus === 'warning' ? '警告' : '重要'}
                  </span>
                </div>
              )}
            </div>
            
            <div className="flex items-center space-x-4">
              {overview && (
                <div className="text-sm text-gray-500">
                  稼働時間: {formatUptime(overview.uptime)}
                </div>
              )}
              
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
              
              <button
                onClick={() => setIsFullscreen(!isFullscreen)}
                className="text-sm bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-1 rounded-md"
              >
                {isFullscreen ? '通常表示' : 'フルスクリーン'}
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* ナビゲーション */}
      <nav className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex space-x-8">
            {navItems.map((item) => (
              <button
                key={item.id}
                onClick={() => setCurrentView(item.id as MonitoringView)}
                className={clsx(
                  'flex items-center space-x-2 py-4 px-1 border-b-2 font-medium text-sm transition-colors',
                  currentView === item.id
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                )}
              >
                <span className="text-lg">{item.icon}</span>
                <span>{item.label}</span>
              </button>
            ))}
          </div>
        </div>
      </nav>

      {/* メインコンテンツ */}
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        {/* 概要表示 */}
        {currentView === 'overview' && (
          <div className="space-y-6">
            {/* クイック統計 */}
            {quickStats && (
              <div className="bg-white rounded-lg shadow-sm p-6">
                <h2 className="text-lg font-semibold text-gray-900 mb-4">クイック統計</h2>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-6 gap-4">
                  <div className="text-center">
                    <div className={clsx(
                      'text-2xl font-bold',
                      getMetricColor(quickStats.cpu, { warning: 70, critical: 90 })
                    )}>
                      {quickStats.cpu.toFixed(1)}%
                    </div>
                    <div className="text-sm text-gray-500">CPU使用率</div>
                  </div>
                  
                  <div className="text-center">
                    <div className={clsx(
                      'text-2xl font-bold',
                      getMetricColor(quickStats.memory, { warning: 70, critical: 90 })
                    )}>
                      {quickStats.memory.toFixed(1)}%
                    </div>
                    <div className="text-sm text-gray-500">メモリ使用率</div>
                  </div>
                  
                  <div className="text-center">
                    <div className={clsx(
                      'text-2xl font-bold',
                      getMetricColor(quickStats.disk, { warning: 80, critical: 95 })
                    )}>
                      {quickStats.disk.toFixed(1)}%
                    </div>
                    <div className="text-sm text-gray-500">ディスク使用率</div>
                  </div>
                  
                  <div className="text-center">
                    <div className={clsx(
                      'text-2xl font-bold',
                      getMetricColor(quickStats.network, { warning: 70, critical: 90 })
                    )}>
                      {quickStats.network.toFixed(1)}%
                    </div>
                    <div className="text-sm text-gray-500">ネットワーク使用率</div>
                  </div>
                  
                  <div className="text-center">
                    <div className="text-2xl font-bold text-blue-600">
                      {quickStats.throughput.toFixed(1)}
                    </div>
                    <div className="text-sm text-gray-500">req/s</div>
                  </div>
                  
                  <div className="text-center">
                    <div className={clsx(
                      'text-2xl font-bold',
                      quickStats.errors > 0 ? 'text-red-600' : 'text-green-600'
                    )}>
                      {quickStats.errors}
                    </div>
                    <div className="text-sm text-gray-500">エラー/分</div>
                  </div>
                </div>
              </div>
            )}

            {/* 監視概要 */}
            {overview && (
              <div className="bg-white rounded-lg shadow-sm p-6">
                <h2 className="text-lg font-semibold text-gray-900 mb-4">システム概要</h2>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                  <div className="text-center">
                    <div className="text-3xl mb-2">{getSystemStatusIcon(overview.systemStatus)}</div>
                    <div className="text-sm text-gray-500">システム状態</div>
                    <div className={clsx(
                      'text-lg font-semibold',
                      getSystemStatusColor(overview.systemStatus).split(' ')[0]
                    )}>
                      {overview.systemStatus === 'healthy' ? '正常' :
                       overview.systemStatus === 'warning' ? '警告' : '重要'}
                    </div>
                  </div>
                  
                  <div className="text-center">
                    <div className="text-2xl font-bold text-gray-900 mb-2">
                      {overview.totalAlerts}
                    </div>
                    <div className="text-sm text-gray-500">総アラート数</div>
                    {overview.criticalAlerts > 0 && (
                      <div className="text-sm text-red-600">
                        ({overview.criticalAlerts}件重要)
                      </div>
                    )}
                  </div>
                  
                  <div className="text-center">
                    <div className={clsx(
                      'text-2xl font-bold mb-2',
                      overview.errorRate > 5 ? 'text-red-600' :
                      overview.errorRate > 1 ? 'text-yellow-600' : 'text-green-600'
                    )}>
                      {overview.errorRate.toFixed(2)}%
                    </div>
                    <div className="text-sm text-gray-500">エラー率</div>
                  </div>
                  
                  <div className="text-center">
                    <div className={clsx(
                      'text-2xl font-bold mb-2',
                      overview.avgResponseTime > 2000 ? 'text-red-600' :
                      overview.avgResponseTime > 1000 ? 'text-yellow-600' : 'text-green-600'
                    )}>
                      {overview.avgResponseTime.toFixed(0)}ms
                    </div>
                    <div className="text-sm text-gray-500">平均応答時間</div>
                  </div>
                </div>
                
                <div className="mt-6 pt-4 border-t border-gray-200">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="text-sm text-gray-500">アクティブユーザー数</div>
                      <div className="text-xl font-bold text-gray-900">{overview.activeUsers}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-sm text-gray-500">最終更新</div>
                      <div className="text-sm text-gray-900">
                        {new Date(overview.lastUpdate).toLocaleString('ja-JP')}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* アラート概要 */}
            <div className="bg-white rounded-lg shadow-sm p-6">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">最近のアラート</h2>
              <div className="text-center text-gray-500 py-8">
                <div className="text-4xl mb-4">🔔</div>
                <p>アラートデータは各監視セクションで確認できます</p>
              </div>
            </div>
          </div>
        )}

        {/* 各監視コンポーネント */}
        {currentView === 'health' && <HealthMonitor />}
        {currentView === 'performance' && <PerformanceMonitor />}
        {currentView === 'alerts' && <AlertManager />}
        {currentView === 'logs' && <LogViewer />}
      </main>
    </div>
  );
};

export default MonitoringDashboard;