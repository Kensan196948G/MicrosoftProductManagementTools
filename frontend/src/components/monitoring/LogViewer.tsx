// Microsoft 365 Management Tools - Log Viewer Component
// 24/7本格運用監視システム - ログビューア

import React, { useState, useEffect, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { clsx } from 'clsx';
import { useQuery } from '@tanstack/react-query';
import { LoadingSpinner } from '../shared/LoadingSpinner';

interface LogEntry {
  id: string;
  timestamp: string;
  level: 'debug' | 'info' | 'warn' | 'error' | 'fatal';
  message: string;
  source: string;
  metadata?: Record<string, any>;
  stack?: string;
  userId?: string;
  sessionId?: string;
  correlationId?: string;
}

interface LogFilters {
  level?: string;
  source?: string;
  startTime?: string;
  endTime?: string;
  search?: string;
  userId?: string;
  limit?: number;
  realtime?: boolean;
}

interface LogStats {
  totalLogs: number;
  errorRate: number;
  warningRate: number;
  avgLogsPerMinute: number;
  topSources: { source: string; count: number }[];
  recentErrors: LogEntry[];
}

// ログ管理API
const logAPI = {
  async getLogs(filters: LogFilters): Promise<LogEntry[]> {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== '') {
        params.append(key, value.toString());
      }
    });
    
    const response = await fetch(`/api/logs?${params}`);
    if (!response.ok) {
      throw new Error('Failed to fetch logs');
    }
    return response.json();
  },

  async getLogStats(): Promise<LogStats> {
    const response = await fetch('/api/logs/stats');
    if (!response.ok) {
      throw new Error('Failed to fetch log stats');
    }
    return response.json();
  },

  async exportLogs(filters: LogFilters): Promise<Blob> {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== '') {
        params.append(key, value.toString());
      }
    });
    
    const response = await fetch(`/api/logs/export?${params}`);
    if (!response.ok) {
      throw new Error('Failed to export logs');
    }
    return response.blob();
  }
};

export const LogViewer: React.FC = () => {
  const [filters, setFilters] = useState<LogFilters>({
    level: '',
    source: '',
    startTime: '',
    endTime: '',
    search: '',
    userId: '',
    limit: 100,
    realtime: false,
  });
  const [selectedLog, setSelectedLog] = useState<LogEntry | null>(null);
  const [autoScroll, setAutoScroll] = useState(true);
  const [showFilters, setShowFilters] = useState(false);
  const logContainerRef = useRef<HTMLDivElement>(null);

  // ログ一覧の取得
  const { 
    data: logs, 
    isLoading, 
    error,
    refetch 
  } = useQuery({
    queryKey: ['logs', filters],
    queryFn: () => logAPI.getLogs(filters),
    refetchInterval: filters.realtime ? 5000 : false, // リアルタイムモードでは5秒間隔
    refetchOnWindowFocus: false,
    staleTime: filters.realtime ? 0 : 30000,
  });

  // ログ統計の取得
  const { 
    data: logStats, 
    isLoading: statsLoading 
  } = useQuery({
    queryKey: ['logStats'],
    queryFn: logAPI.getLogStats,
    refetchInterval: 30000, // 30秒間隔
    refetchOnWindowFocus: false,
  });

  // 自動スクロール
  useEffect(() => {
    if (autoScroll && logContainerRef.current) {
      logContainerRef.current.scrollTop = logContainerRef.current.scrollHeight;
    }
  }, [logs, autoScroll]);

  // ログエクスポート
  const exportLogs = useCallback(async () => {
    try {
      const blob = await logAPI.exportLogs(filters);
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `logs_${new Date().toISOString().split('T')[0]}.json`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (error) {
      console.error('Failed to export logs:', error);
    }
  }, [filters]);

  // ログレベルの色分け
  const getLogLevelColor = (level: LogEntry['level']) => {
    switch (level) {
      case 'debug': return 'text-gray-500';
      case 'info': return 'text-blue-600';
      case 'warn': return 'text-yellow-600';
      case 'error': return 'text-red-600';
      case 'fatal': return 'text-red-800 font-bold';
      default: return 'text-gray-600';
    }
  };

  // ログレベルの背景色
  const getLogLevelBg = (level: LogEntry['level']) => {
    switch (level) {
      case 'debug': return 'bg-gray-50';
      case 'info': return 'bg-blue-50';
      case 'warn': return 'bg-yellow-50';
      case 'error': return 'bg-red-50';
      case 'fatal': return 'bg-red-100';
      default: return 'bg-white';
    }
  };

  // ログレベルのアイコン
  const getLogLevelIcon = (level: LogEntry['level']) => {
    switch (level) {
      case 'debug': return '🔍';
      case 'info': return 'ℹ️';
      case 'warn': return '⚠️';
      case 'error': return '❌';
      case 'fatal': return '💀';
      default: return '📋';
    }
  };

  // 検索ハイライト
  const highlightSearch = (text: string, search: string) => {
    if (!search) return text;
    
    const regex = new RegExp(`(${search})`, 'gi');
    return text.replace(regex, '<mark class="bg-yellow-200">$1</mark>');
  };

  if (isLoading && !logs) {
    return (
      <div className="bg-white rounded-lg shadow-sm p-6">
        <LoadingSpinner message="ログデータ読み込み中..." />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-lg shadow-sm p-6">
        <div className="flex items-center space-x-2 text-red-600">
          <span className="text-2xl">⚠️</span>
          <div>
            <h3 className="font-semibold">ログビューア接続エラー</h3>
            <p className="text-sm text-gray-600">
              ログデータを取得できません。
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
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-semibold text-gray-900">ログビューア</h2>
          
          <div className="flex items-center space-x-4">
            <label className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={filters.realtime}
                onChange={(e) => setFilters(prev => ({ ...prev, realtime: e.target.checked }))}
                className="rounded border-gray-300"
              />
              <span className="text-sm text-gray-700">リアルタイム更新</span>
            </label>
            
            <label className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={autoScroll}
                onChange={(e) => setAutoScroll(e.target.checked)}
                className="rounded border-gray-300"
              />
              <span className="text-sm text-gray-700">自動スクロール</span>
            </label>
            
            <button
              onClick={() => setShowFilters(!showFilters)}
              className="text-sm bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-1 rounded-md"
            >
              フィルター
            </button>
            
            <button
              onClick={exportLogs}
              className="text-sm bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded-md"
            >
              エクスポート
            </button>
            
            <button
              onClick={() => refetch()}
              className="text-sm bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded-md"
            >
              更新
            </button>
          </div>
        </div>

        {/* 統計情報 */}
        {logStats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-gray-900">{logStats.totalLogs}</div>
              <div className="text-sm text-gray-500">総ログ数</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-red-600">{logStats.errorRate.toFixed(1)}%</div>
              <div className="text-sm text-gray-500">エラー率</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-yellow-600">{logStats.warningRate.toFixed(1)}%</div>
              <div className="text-sm text-gray-500">警告率</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">{logStats.avgLogsPerMinute.toFixed(1)}</div>
              <div className="text-sm text-gray-500">ログ/分</div>
            </div>
          </div>
        )}

        {/* フィルター */}
        <AnimatePresence>
          {showFilters && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="border-t border-gray-200 pt-4"
            >
              <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    ログレベル
                  </label>
                  <select
                    value={filters.level || ''}
                    onChange={(e) => setFilters(prev => ({ ...prev, level: e.target.value }))}
                    className="w-full text-sm border border-gray-300 rounded-md px-3 py-1"
                  >
                    <option value="">すべて</option>
                    <option value="debug">Debug</option>
                    <option value="info">Info</option>
                    <option value="warn">Warning</option>
                    <option value="error">Error</option>
                    <option value="fatal">Fatal</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    ソース
                  </label>
                  <select
                    value={filters.source || ''}
                    onChange={(e) => setFilters(prev => ({ ...prev, source: e.target.value }))}
                    className="w-full text-sm border border-gray-300 rounded-md px-3 py-1"
                  >
                    <option value="">すべて</option>
                    <option value="frontend">Frontend</option>
                    <option value="backend">Backend</option>
                    <option value="database">Database</option>
                    <option value="auth">Authentication</option>
                    <option value="api">API</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    開始時刻
                  </label>
                  <input
                    type="datetime-local"
                    value={filters.startTime || ''}
                    onChange={(e) => setFilters(prev => ({ ...prev, startTime: e.target.value }))}
                    className="w-full text-sm border border-gray-300 rounded-md px-3 py-1"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    終了時刻
                  </label>
                  <input
                    type="datetime-local"
                    value={filters.endTime || ''}
                    onChange={(e) => setFilters(prev => ({ ...prev, endTime: e.target.value }))}
                    className="w-full text-sm border border-gray-300 rounded-md px-3 py-1"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    検索
                  </label>
                  <input
                    type="text"
                    value={filters.search || ''}
                    onChange={(e) => setFilters(prev => ({ ...prev, search: e.target.value }))}
                    placeholder="メッセージ内容で検索"
                    className="w-full text-sm border border-gray-300 rounded-md px-3 py-1"
                  />
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* ログ一覧 */}
      <div className="bg-white rounded-lg shadow-sm">
        <div
          ref={logContainerRef}
          className="max-h-96 overflow-y-auto"
          style={{ minHeight: '400px' }}
        >
          {logs && logs.length > 0 ? (
            <div className="divide-y divide-gray-200">
              {logs.map((log) => (
                <motion.div
                  key={log.id}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  className={clsx(
                    'p-4 hover:bg-gray-50 cursor-pointer transition-colors',
                    getLogLevelBg(log.level)
                  )}
                  onClick={() => setSelectedLog(log)}
                >
                  <div className="flex items-start space-x-3">
                    <div className="text-lg">{getLogLevelIcon(log.level)}</div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center space-x-2 mb-1">
                        <span className={clsx('text-sm font-medium', getLogLevelColor(log.level))}>
                          {log.level.toUpperCase()}
                        </span>
                        <span className="text-sm text-gray-500">{log.source}</span>
                        <span className="text-sm text-gray-500">
                          {new Date(log.timestamp).toLocaleString('ja-JP')}
                        </span>
                      </div>
                      
                      <div
                        className="text-sm text-gray-900 break-words"
                        dangerouslySetInnerHTML={{
                          __html: highlightSearch(log.message, filters.search || '')
                        }}
                      />
                      
                      {log.metadata && (
                        <div className="mt-2 text-xs text-gray-500">
                          {Object.entries(log.metadata).slice(0, 3).map(([key, value]) => (
                            <span key={key} className="mr-4">
                              {key}: {String(value)}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                </motion.div>
              ))}
            </div>
          ) : (
            <div className="p-8 text-center text-gray-500">
              <div className="text-4xl mb-4">📋</div>
              <p>ログがありません</p>
            </div>
          )}
        </div>
      </div>

      {/* ログ詳細モーダル */}
      <AnimatePresence>
        {selectedLog && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
            onClick={() => setSelectedLog(null)}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="bg-white rounded-lg shadow-xl max-w-4xl w-full max-h-[90vh] overflow-y-auto"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="p-6">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center space-x-3">
                    <div className="text-2xl">{getLogLevelIcon(selectedLog.level)}</div>
                    <div>
                      <h3 className="text-lg font-semibold text-gray-900">
                        ログ詳細
                      </h3>
                      <div className="flex items-center space-x-2 text-sm text-gray-500">
                        <span className={clsx('font-medium', getLogLevelColor(selectedLog.level))}>
                          {selectedLog.level.toUpperCase()}
                        </span>
                        <span>•</span>
                        <span>{selectedLog.source}</span>
                        <span>•</span>
                        <span>{new Date(selectedLog.timestamp).toLocaleString('ja-JP')}</span>
                      </div>
                    </div>
                  </div>
                  <button
                    onClick={() => setSelectedLog(null)}
                    className="text-gray-400 hover:text-gray-600"
                  >
                    ✕
                  </button>
                </div>
                
                <div className="space-y-4">
                  <div>
                    <h4 className="font-medium text-gray-900 mb-2">メッセージ</h4>
                    <div className="bg-gray-50 p-3 rounded-md">
                      <p className="text-sm text-gray-900 whitespace-pre-wrap">{selectedLog.message}</p>
                    </div>
                  </div>
                  
                  {selectedLog.stack && (
                    <div>
                      <h4 className="font-medium text-gray-900 mb-2">スタックトレース</h4>
                      <div className="bg-gray-50 p-3 rounded-md">
                        <pre className="text-xs text-gray-900 whitespace-pre-wrap overflow-x-auto">
                          {selectedLog.stack}
                        </pre>
                      </div>
                    </div>
                  )}
                  
                  {selectedLog.metadata && (
                    <div>
                      <h4 className="font-medium text-gray-900 mb-2">メタデータ</h4>
                      <div className="bg-gray-50 p-3 rounded-md">
                        <pre className="text-xs text-gray-900 whitespace-pre-wrap overflow-x-auto">
                          {JSON.stringify(selectedLog.metadata, null, 2)}
                        </pre>
                      </div>
                    </div>
                  )}
                  
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    {selectedLog.userId && (
                      <div>
                        <h4 className="font-medium text-gray-900 mb-1">ユーザーID</h4>
                        <p className="text-sm text-gray-600">{selectedLog.userId}</p>
                      </div>
                    )}
                    {selectedLog.sessionId && (
                      <div>
                        <h4 className="font-medium text-gray-900 mb-1">セッションID</h4>
                        <p className="text-sm text-gray-600">{selectedLog.sessionId}</p>
                      </div>
                    )}
                    {selectedLog.correlationId && (
                      <div>
                        <h4 className="font-medium text-gray-900 mb-1">相関ID</h4>
                        <p className="text-sm text-gray-600">{selectedLog.correlationId}</p>
                      </div>
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

export default LogViewer;