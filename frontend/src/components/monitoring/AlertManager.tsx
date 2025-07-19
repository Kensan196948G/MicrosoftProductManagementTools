// Microsoft 365 Management Tools - Alert Manager Component
// 24/7本格運用監視システム - アラート管理

import React, { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { clsx } from 'clsx';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { LoadingSpinner } from '../shared/LoadingSpinner';
import toast from 'react-hot-toast';

interface Alert {
  id: string;
  title: string;
  message: string;
  severity: 'info' | 'warning' | 'error' | 'critical';
  source: string;
  timestamp: string;
  acknowledged: boolean;
  resolved: boolean;
  acknowledgedBy?: string;
  resolvedBy?: string;
  metadata?: Record<string, any>;
}

interface AlertRule {
  id: string;
  name: string;
  description: string;
  enabled: boolean;
  condition: {
    metric: string;
    operator: 'gt' | 'lt' | 'eq' | 'ne' | 'gte' | 'lte';
    threshold: number;
    duration: number; // seconds
  };
  severity: Alert['severity'];
  actions: {
    email: boolean;
    webhook: boolean;
    notification: boolean;
  };
}

interface AlertStats {
  total: number;
  unacknowledged: number;
  critical: number;
  warning: number;
  resolved: number;
  last24h: number;
}

// アラート管理API
const alertAPI = {
  async getAlerts(filters?: { 
    severity?: string; 
    acknowledged?: boolean; 
    resolved?: boolean;
    limit?: number;
  }): Promise<Alert[]> {
    const params = new URLSearchParams();
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined) {
          params.append(key, value.toString());
        }
      });
    }
    
    const response = await fetch(`/api/alerts?${params}`);
    if (!response.ok) {
      throw new Error('Failed to fetch alerts');
    }
    return response.json();
  },

  async acknowledgeAlert(alertId: string): Promise<void> {
    const response = await fetch(`/api/alerts/${alertId}/acknowledge`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
    });
    
    if (!response.ok) {
      throw new Error('Failed to acknowledge alert');
    }
  },

  async resolveAlert(alertId: string): Promise<void> {
    const response = await fetch(`/api/alerts/${alertId}/resolve`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
    });
    
    if (!response.ok) {
      throw new Error('Failed to resolve alert');
    }
  },

  async deleteAlert(alertId: string): Promise<void> {
    const response = await fetch(`/api/alerts/${alertId}`, {
      method: 'DELETE',
    });
    
    if (!response.ok) {
      throw new Error('Failed to delete alert');
    }
  },

  async getAlertRules(): Promise<AlertRule[]> {
    const response = await fetch('/api/alerts/rules');
    if (!response.ok) {
      throw new Error('Failed to fetch alert rules');
    }
    return response.json();
  },

  async updateAlertRule(rule: AlertRule): Promise<void> {
    const response = await fetch(`/api/alerts/rules/${rule.id}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(rule),
    });
    
    if (!response.ok) {
      throw new Error('Failed to update alert rule');
    }
  },

  async getAlertStats(): Promise<AlertStats> {
    const response = await fetch('/api/alerts/stats');
    if (!response.ok) {
      throw new Error('Failed to fetch alert stats');
    }
    return response.json();
  }
};

export const AlertManager: React.FC = () => {
  const [selectedTab, setSelectedTab] = useState<'alerts' | 'rules' | 'stats'>('alerts');
  const [selectedAlert, setSelectedAlert] = useState<Alert | null>(null);
  const [filters, setFilters] = useState({
    severity: '',
    acknowledged: false,
    resolved: false,
  });
  const [showModal, setShowModal] = useState(false);

  const queryClient = useQueryClient();

  // アラート一覧の取得
  const { 
    data: alerts, 
    isLoading: alertsLoading, 
    error: alertsError 
  } = useQuery({
    queryKey: ['alerts', filters],
    queryFn: () => alertAPI.getAlerts(filters),
    refetchInterval: 30000, // 30秒間隔
    refetchOnWindowFocus: true,
  });

  // アラートルール一覧の取得
  const { 
    data: alertRules, 
    isLoading: rulesLoading 
  } = useQuery({
    queryKey: ['alertRules'],
    queryFn: alertAPI.getAlertRules,
    refetchInterval: 60000, // 1分間隔
  });

  // アラート統計の取得
  const { 
    data: alertStats, 
    isLoading: statsLoading 
  } = useQuery({
    queryKey: ['alertStats'],
    queryFn: alertAPI.getAlertStats,
    refetchInterval: 60000, // 1分間隔
  });

  // アラート確認
  const acknowledgeMutation = useMutation({
    mutationFn: alertAPI.acknowledgeAlert,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['alerts'] });
      queryClient.invalidateQueries({ queryKey: ['alertStats'] });
      toast.success('アラートを確認しました');
    },
    onError: () => {
      toast.error('アラートの確認に失敗しました');
    },
  });

  // アラート解決
  const resolveMutation = useMutation({
    mutationFn: alertAPI.resolveAlert,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['alerts'] });
      queryClient.invalidateQueries({ queryKey: ['alertStats'] });
      toast.success('アラートを解決しました');
    },
    onError: () => {
      toast.error('アラートの解決に失敗しました');
    },
  });

  // アラート削除
  const deleteMutation = useMutation({
    mutationFn: alertAPI.deleteAlert,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['alerts'] });
      queryClient.invalidateQueries({ queryKey: ['alertStats'] });
      toast.success('アラートを削除しました');
      setShowModal(false);
      setSelectedAlert(null);
    },
    onError: () => {
      toast.error('アラートの削除に失敗しました');
    },
  });

  // アラートルール更新
  const updateRuleMutation = useMutation({
    mutationFn: alertAPI.updateAlertRule,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['alertRules'] });
      toast.success('アラートルールを更新しました');
    },
    onError: () => {
      toast.error('アラートルールの更新に失敗しました');
    },
  });

  // 重要なアラートの音声通知
  const playAlertSound = useCallback(() => {
    const audio = new Audio('/sounds/alert.mp3');
    audio.play().catch(() => {
      // 音声再生に失敗した場合は無視
    });
  }, []);

  // 新しいクリティカルアラートの監視
  useEffect(() => {
    if (!alerts) return;

    const criticalAlerts = alerts.filter(
      alert => alert.severity === 'critical' && !alert.acknowledged
    );

    if (criticalAlerts.length > 0) {
      playAlertSound();
      
      // ブラウザ通知
      if (Notification.permission === 'granted') {
        criticalAlerts.forEach(alert => {
          new Notification('重要なアラート', {
            body: alert.message,
            icon: '/favicon.ico',
            badge: '/favicon.ico',
            requireInteraction: true,
          });
        });
      }
    }
  }, [alerts, playAlertSound]);

  // 通知権限の要求
  useEffect(() => {
    if (Notification.permission === 'default') {
      Notification.requestPermission();
    }
  }, []);

  // アラートの重要度による色分け
  const getSeverityColor = (severity: Alert['severity']) => {
    switch (severity) {
      case 'critical': return 'bg-red-500 text-white';
      case 'error': return 'bg-red-100 text-red-800';
      case 'warning': return 'bg-yellow-100 text-yellow-800';
      case 'info': return 'bg-blue-100 text-blue-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  // アラートの重要度による絵文字
  const getSeverityIcon = (severity: Alert['severity']) => {
    switch (severity) {
      case 'critical': return '🚨';
      case 'error': return '❌';
      case 'warning': return '⚠️';
      case 'info': return 'ℹ️';
      default: return '📋';
    }
  };

  if (alertsLoading && !alerts) {
    return (
      <div className="bg-white rounded-lg shadow-sm p-6">
        <LoadingSpinner message="アラートマネージャー初期化中..." />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="bg-white rounded-lg shadow-sm p-6">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-semibold text-gray-900">
            アラートマネージャー
          </h2>
          
          {/* タブナビゲーション */}
          <div className="flex space-x-4">
            <button
              onClick={() => setSelectedTab('alerts')}
              className={clsx(
                'px-4 py-2 rounded-md text-sm font-medium transition-colors',
                selectedTab === 'alerts'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              )}
            >
              アラート
            </button>
            <button
              onClick={() => setSelectedTab('rules')}
              className={clsx(
                'px-4 py-2 rounded-md text-sm font-medium transition-colors',
                selectedTab === 'rules'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              )}
            >
              ルール
            </button>
            <button
              onClick={() => setSelectedTab('stats')}
              className={clsx(
                'px-4 py-2 rounded-md text-sm font-medium transition-colors',
                selectedTab === 'stats'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              )}
            >
              統計
            </button>
          </div>
        </div>
      </div>

      {/* アラート統計サマリー */}
      {alertStats && (
        <div className="bg-white rounded-lg shadow-sm p-6">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-6 gap-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-gray-900">{alertStats.total}</div>
              <div className="text-sm text-gray-500">総アラート数</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-red-600">{alertStats.unacknowledged}</div>
              <div className="text-sm text-gray-500">未確認</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-red-500">{alertStats.critical}</div>
              <div className="text-sm text-gray-500">重要</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-yellow-500">{alertStats.warning}</div>
              <div className="text-sm text-gray-500">警告</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">{alertStats.resolved}</div>
              <div className="text-sm text-gray-500">解決済み</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">{alertStats.last24h}</div>
              <div className="text-sm text-gray-500">24時間以内</div>
            </div>
          </div>
        </div>
      )}

      {/* アラート一覧 */}
      {selectedTab === 'alerts' && (
        <div className="bg-white rounded-lg shadow-sm">
          {/* フィルター */}
          <div className="p-4 border-b border-gray-200">
            <div className="flex items-center space-x-4">
              <select
                value={filters.severity}
                onChange={(e) => setFilters(prev => ({ ...prev, severity: e.target.value }))}
                className="text-sm border border-gray-300 rounded-md px-3 py-1"
              >
                <option value="">すべての重要度</option>
                <option value="critical">重要</option>
                <option value="error">エラー</option>
                <option value="warning">警告</option>
                <option value="info">情報</option>
              </select>
              
              <label className="flex items-center space-x-2">
                <input
                  type="checkbox"
                  checked={filters.acknowledged}
                  onChange={(e) => setFilters(prev => ({ ...prev, acknowledged: e.target.checked }))}
                  className="rounded border-gray-300"
                />
                <span className="text-sm text-gray-700">確認済みのみ</span>
              </label>
              
              <label className="flex items-center space-x-2">
                <input
                  type="checkbox"
                  checked={filters.resolved}
                  onChange={(e) => setFilters(prev => ({ ...prev, resolved: e.target.checked }))}
                  className="rounded border-gray-300"
                />
                <span className="text-sm text-gray-700">解決済みのみ</span>
              </label>
            </div>
          </div>

          {/* アラートリスト */}
          <div className="divide-y divide-gray-200">
            {alerts && alerts.length > 0 ? (
              alerts.map((alert) => (
                <motion.div
                  key={alert.id}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  className={clsx(
                    'p-4 hover:bg-gray-50 cursor-pointer transition-colors',
                    !alert.acknowledged && 'bg-yellow-50'
                  )}
                  onClick={() => {
                    setSelectedAlert(alert);
                    setShowModal(true);
                  }}
                >
                  <div className="flex items-start justify-between">
                    <div className="flex items-start space-x-3">
                      <div className="text-2xl">{getSeverityIcon(alert.severity)}</div>
                      <div className="flex-1">
                        <div className="flex items-center space-x-2 mb-1">
                          <span className="font-medium text-gray-900">{alert.title}</span>
                          <span className={clsx(
                            'px-2 py-1 text-xs rounded-full',
                            getSeverityColor(alert.severity)
                          )}>
                            {alert.severity}
                          </span>
                          {alert.acknowledged && (
                            <span className="px-2 py-1 text-xs bg-green-100 text-green-800 rounded-full">
                              確認済み
                            </span>
                          )}
                          {alert.resolved && (
                            <span className="px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded-full">
                              解決済み
                            </span>
                          )}
                        </div>
                        <p className="text-sm text-gray-600 mb-1">{alert.message}</p>
                        <div className="flex items-center space-x-4 text-xs text-gray-500">
                          <span>ソース: {alert.source}</span>
                          <span>{new Date(alert.timestamp).toLocaleString('ja-JP')}</span>
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex items-center space-x-2">
                      {!alert.acknowledged && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            acknowledgeMutation.mutate(alert.id);
                          }}
                          className="text-sm bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded-md"
                        >
                          確認
                        </button>
                      )}
                      {!alert.resolved && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            resolveMutation.mutate(alert.id);
                          }}
                          className="text-sm bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded-md"
                        >
                          解決
                        </button>
                      )}
                    </div>
                  </div>
                </motion.div>
              ))
            ) : (
              <div className="p-8 text-center text-gray-500">
                <div className="text-4xl mb-4">🎉</div>
                <p>現在アラートはありません</p>
              </div>
            )}
          </div>
        </div>
      )}

      {/* アラートルール */}
      {selectedTab === 'rules' && (
        <div className="bg-white rounded-lg shadow-sm p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">アラートルール</h3>
          
          {rulesLoading ? (
            <LoadingSpinner message="ルール読み込み中..." />
          ) : (
            <div className="space-y-4">
              {alertRules?.map((rule) => (
                <div key={rule.id} className="border border-gray-200 rounded-lg p-4">
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center space-x-2">
                      <h4 className="font-medium text-gray-900">{rule.name}</h4>
                      <span className={clsx(
                        'px-2 py-1 text-xs rounded-full',
                        rule.enabled ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                      )}>
                        {rule.enabled ? '有効' : '無効'}
                      </span>
                    </div>
                    <button
                      onClick={() => updateRuleMutation.mutate({ ...rule, enabled: !rule.enabled })}
                      className={clsx(
                        'text-sm px-3 py-1 rounded-md',
                        rule.enabled
                          ? 'bg-red-100 text-red-800 hover:bg-red-200'
                          : 'bg-green-100 text-green-800 hover:bg-green-200'
                      )}
                    >
                      {rule.enabled ? '無効化' : '有効化'}
                    </button>
                  </div>
                  
                  <p className="text-sm text-gray-600 mb-3">{rule.description}</p>
                  
                  <div className="text-sm text-gray-500 space-y-1">
                    <div>
                      条件: {rule.condition.metric} {rule.condition.operator} {rule.condition.threshold}
                    </div>
                    <div>
                      継続時間: {rule.condition.duration}秒
                    </div>
                    <div>
                      重要度: {rule.severity}
                    </div>
                    <div>
                      アクション: 
                      {rule.actions.email && ' メール'}
                      {rule.actions.webhook && ' Webhook'}
                      {rule.actions.notification && ' 通知'}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* アラート詳細モーダル */}
      <AnimatePresence>
        {showModal && selectedAlert && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
            onClick={() => setShowModal(false)}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="p-6">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center space-x-3">
                    <div className="text-3xl">{getSeverityIcon(selectedAlert.severity)}</div>
                    <div>
                      <h3 className="text-lg font-semibold text-gray-900">{selectedAlert.title}</h3>
                      <span className={clsx(
                        'px-2 py-1 text-xs rounded-full',
                        getSeverityColor(selectedAlert.severity)
                      )}>
                        {selectedAlert.severity}
                      </span>
                    </div>
                  </div>
                  <button
                    onClick={() => setShowModal(false)}
                    className="text-gray-400 hover:text-gray-600"
                  >
                    ✕
                  </button>
                </div>
                
                <div className="space-y-4">
                  <div>
                    <h4 className="font-medium text-gray-900 mb-2">メッセージ</h4>
                    <p className="text-gray-600">{selectedAlert.message}</p>
                  </div>
                  
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <h4 className="font-medium text-gray-900 mb-1">ソース</h4>
                      <p className="text-sm text-gray-600">{selectedAlert.source}</p>
                    </div>
                    <div>
                      <h4 className="font-medium text-gray-900 mb-1">発生時刻</h4>
                      <p className="text-sm text-gray-600">
                        {new Date(selectedAlert.timestamp).toLocaleString('ja-JP')}
                      </p>
                    </div>
                  </div>
                  
                  {selectedAlert.metadata && (
                    <div>
                      <h4 className="font-medium text-gray-900 mb-2">詳細情報</h4>
                      <pre className="text-sm text-gray-600 bg-gray-50 p-3 rounded-md overflow-x-auto">
                        {JSON.stringify(selectedAlert.metadata, null, 2)}
                      </pre>
                    </div>
                  )}
                </div>
                
                <div className="flex items-center justify-between mt-6 pt-4 border-t border-gray-200">
                  <div className="flex items-center space-x-2">
                    {selectedAlert.acknowledged && (
                      <span className="text-sm text-green-600">
                        ✓ 確認済み ({selectedAlert.acknowledgedBy})
                      </span>
                    )}
                    {selectedAlert.resolved && (
                      <span className="text-sm text-blue-600">
                        ✓ 解決済み ({selectedAlert.resolvedBy})
                      </span>
                    )}
                  </div>
                  
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => deleteMutation.mutate(selectedAlert.id)}
                      className="text-sm bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md"
                    >
                      削除
                    </button>
                    {!selectedAlert.acknowledged && (
                      <button
                        onClick={() => acknowledgeMutation.mutate(selectedAlert.id)}
                        className="text-sm bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md"
                      >
                        確認
                      </button>
                    )}
                    {!selectedAlert.resolved && (
                      <button
                        onClick={() => resolveMutation.mutate(selectedAlert.id)}
                        className="text-sm bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-md"
                      >
                        解決
                      </button>
                    )}
                  </div>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};

export default AlertManager;