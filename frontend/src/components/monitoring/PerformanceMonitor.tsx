// Microsoft 365 Management Tools - Performance Monitor Component
// 24/7本格運用監視システム - パフォーマンスモニタリング

import React, { useState, useEffect, useRef } from 'react';
import { motion } from 'framer-motion';
import { clsx } from 'clsx';
import { useQuery } from '@tanstack/react-query';
import { LoadingSpinner } from '../shared/LoadingSpinner';

interface PerformanceMetric {
  timestamp: string;
  value: number;
  unit: string;
  category: 'cpu' | 'memory' | 'network' | 'disk' | 'response' | 'throughput';
}

interface PerformanceData {
  current: {
    cpu: number;
    memory: number;
    network: number;
    disk: number;
    responseTime: number;
    throughput: number;
  };
  history: PerformanceMetric[];
  alerts: {
    id: string;
    metric: string;
    threshold: number;
    currentValue: number;
    severity: 'warning' | 'critical';
    timestamp: string;
    message: string;
  }[];
}

interface WebVitals {
  fcp: number; // First Contentful Paint
  lcp: number; // Largest Contentful Paint
  fid: number; // First Input Delay
  cls: number; // Cumulative Layout Shift
  ttfb: number; // Time to First Byte
  tti: number; // Time to Interactive
}

// パフォーマンスAPI
const performanceAPI = {
  async getPerformanceData(): Promise<PerformanceData> {
    const response = await fetch('/api/monitoring/performance');
    if (!response.ok) {
      throw new Error('Performance data fetch failed');
    }
    return response.json();
  },

  async getWebVitals(): Promise<WebVitals> {
    const response = await fetch('/api/monitoring/web-vitals');
    if (!response.ok) {
      throw new Error('Web vitals fetch failed');
    }
    return response.json();
  },

  async getPerformanceHistory(hours: number = 24): Promise<PerformanceMetric[]> {
    const response = await fetch(`/api/monitoring/performance/history?hours=${hours}`);
    if (!response.ok) {
      throw new Error('Performance history fetch failed');
    }
    return response.json();
  }
};

// Web Vitals収集
const collectWebVitals = (): Promise<WebVitals> => {
  return new Promise((resolve) => {
    const vitals: Partial<WebVitals> = {};

    // First Contentful Paint
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      entries.forEach((entry) => {
        if (entry.name === 'first-contentful-paint') {
          vitals.fcp = entry.startTime;
        }
      });
    }).observe({ type: 'paint', buffered: true });

    // Largest Contentful Paint
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      const lastEntry = entries[entries.length - 1];
      vitals.lcp = lastEntry.startTime;
    }).observe({ type: 'largest-contentful-paint', buffered: true });

    // First Input Delay
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      entries.forEach((entry) => {
        if (entry.processingStart && entry.startTime) {
          vitals.fid = entry.processingStart - entry.startTime;
        }
      });
    }).observe({ type: 'first-input', buffered: true });

    // Cumulative Layout Shift
    let cumulativeLayoutShift = 0;
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      entries.forEach((entry) => {
        if (!(entry as any).hadRecentInput) {
          cumulativeLayoutShift += (entry as any).value;
        }
      });
      vitals.cls = cumulativeLayoutShift;
    }).observe({ type: 'layout-shift', buffered: true });

    // Time to First Byte
    const navigationEntry = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    if (navigationEntry) {
      vitals.ttfb = navigationEntry.responseStart - navigationEntry.requestStart;
    }

    // Time to Interactive (簡易計算)
    vitals.tti = performance.now();

    // 2秒後に結果を返す（各種メトリクスの収集完了を待つ）
    setTimeout(() => {
      resolve(vitals as WebVitals);
    }, 2000);
  });
};

export const PerformanceMonitor: React.FC = () => {
  const [selectedMetric, setSelectedMetric] = useState<string>('cpu');
  const [timeRange, setTimeRange] = useState<number>(24);
  const [webVitals, setWebVitals] = useState<WebVitals | null>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  // パフォーマンスデータの取得
  const { 
    data: performanceData, 
    isLoading, 
    error 
  } = useQuery({
    queryKey: ['performanceData'],
    queryFn: performanceAPI.getPerformanceData,
    refetchInterval: 30000, // 30秒間隔
    refetchOnWindowFocus: true,
    staleTime: 10000,
  });

  // Web Vitalsの収集
  useEffect(() => {
    collectWebVitals().then(setWebVitals);
  }, []);

  // チャート描画
  const drawChart = (canvas: HTMLCanvasElement, data: PerformanceMetric[]) => {
    const ctx = canvas.getContext('2d');
    if (!ctx || !data.length) return;

    const width = canvas.width;
    const height = canvas.height;
    const padding = 40;

    // キャンバスをクリア
    ctx.clearRect(0, 0, width, height);

    // データの最大値・最小値を計算
    const values = data.map(d => d.value);
    const maxValue = Math.max(...values);
    const minValue = Math.min(...values);
    const range = maxValue - minValue || 1;

    // グリッドの描画
    ctx.strokeStyle = '#e5e7eb';
    ctx.lineWidth = 1;
    
    // 水平線
    for (let i = 0; i <= 5; i++) {
      const y = padding + (height - 2 * padding) * i / 5;
      ctx.beginPath();
      ctx.moveTo(padding, y);
      ctx.lineTo(width - padding, y);
      ctx.stroke();
    }

    // 垂直線
    for (let i = 0; i <= 10; i++) {
      const x = padding + (width - 2 * padding) * i / 10;
      ctx.beginPath();
      ctx.moveTo(x, padding);
      ctx.lineTo(x, height - padding);
      ctx.stroke();
    }

    // データライン描画
    ctx.strokeStyle = '#3b82f6';
    ctx.lineWidth = 2;
    ctx.beginPath();

    data.forEach((point, index) => {
      const x = padding + (width - 2 * padding) * index / (data.length - 1);
      const y = height - padding - ((point.value - minValue) / range) * (height - 2 * padding);
      
      if (index === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    });

    ctx.stroke();

    // データポイントの描画
    ctx.fillStyle = '#3b82f6';
    data.forEach((point, index) => {
      const x = padding + (width - 2 * padding) * index / (data.length - 1);
      const y = height - padding - ((point.value - minValue) / range) * (height - 2 * padding);
      
      ctx.beginPath();
      ctx.arc(x, y, 3, 0, 2 * Math.PI);
      ctx.fill();
    });

    // Y軸ラベル
    ctx.fillStyle = '#6b7280';
    ctx.font = '12px sans-serif';
    ctx.textAlign = 'right';
    
    for (let i = 0; i <= 5; i++) {
      const value = minValue + (maxValue - minValue) * (5 - i) / 5;
      const y = padding + (height - 2 * padding) * i / 5;
      ctx.fillText(value.toFixed(1), padding - 10, y + 4);
    }
  };

  // チャートの更新
  useEffect(() => {
    if (!canvasRef.current || !performanceData?.history) return;

    const filteredData = performanceData.history.filter(
      item => item.category === selectedMetric
    );

    drawChart(canvasRef.current, filteredData);
  }, [performanceData, selectedMetric]);

  // Web Vitalsの評価
  const getWebVitalRating = (metric: keyof WebVitals, value: number) => {
    const thresholds = {
      fcp: { good: 1800, needsImprovement: 3000 },
      lcp: { good: 2500, needsImprovement: 4000 },
      fid: { good: 100, needsImprovement: 300 },
      cls: { good: 0.1, needsImprovement: 0.25 },
      ttfb: { good: 800, needsImprovement: 1800 },
      tti: { good: 3800, needsImprovement: 7300 }
    };

    const threshold = thresholds[metric];
    if (value <= threshold.good) return 'good';
    if (value <= threshold.needsImprovement) return 'needs-improvement';
    return 'poor';
  };

  const getRatingColor = (rating: string) => {
    switch (rating) {
      case 'good': return 'text-green-600 bg-green-50';
      case 'needs-improvement': return 'text-yellow-600 bg-yellow-50';
      case 'poor': return 'text-red-600 bg-red-50';
      default: return 'text-gray-600 bg-gray-50';
    }
  };

  if (isLoading) {
    return (
      <div className="bg-white rounded-lg shadow-sm p-6">
        <LoadingSpinner message="パフォーマンスデータ読み込み中..." />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-lg shadow-sm p-6">
        <div className="flex items-center space-x-2 text-red-600">
          <span className="text-2xl">⚠️</span>
          <div>
            <h3 className="font-semibold">パフォーマンスモニター接続エラー</h3>
            <p className="text-sm text-gray-600">
              パフォーマンスデータを取得できません。
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
          <h2 className="text-xl font-semibold text-gray-900">
            パフォーマンスモニター
          </h2>
          
          <div className="flex items-center space-x-4">
            <select
              value={selectedMetric}
              onChange={(e) => setSelectedMetric(e.target.value)}
              className="text-sm border border-gray-300 rounded-md px-3 py-1"
            >
              <option value="cpu">CPU使用率</option>
              <option value="memory">メモリ使用率</option>
              <option value="network">ネットワーク使用率</option>
              <option value="disk">ディスク使用率</option>
              <option value="response">応答時間</option>
              <option value="throughput">スループット</option>
            </select>
            
            <select
              value={timeRange}
              onChange={(e) => setTimeRange(Number(e.target.value))}
              className="text-sm border border-gray-300 rounded-md px-3 py-1"
            >
              <option value={1}>1時間</option>
              <option value={6}>6時間</option>
              <option value={24}>24時間</option>
              <option value={168}>7日間</option>
            </select>
          </div>
        </div>
      </div>

      {/* 現在のメトリクス */}
      {performanceData && (
        <div className="bg-white rounded-lg shadow-sm p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">現在のパフォーマンス</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div className="border border-gray-200 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">CPU使用率</div>
              <div className="text-2xl font-bold text-blue-600">
                {performanceData.current.cpu.toFixed(1)}%
              </div>
              <div className="mt-2 w-full bg-gray-200 rounded-full h-2">
                <div
                  className={clsx(
                    'h-2 rounded-full transition-all duration-500',
                    performanceData.current.cpu >= 80 ? 'bg-red-500' :
                    performanceData.current.cpu >= 60 ? 'bg-yellow-500' : 'bg-green-500'
                  )}
                  style={{ width: `${performanceData.current.cpu}%` }}
                />
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">メモリ使用率</div>
              <div className="text-2xl font-bold text-blue-600">
                {performanceData.current.memory.toFixed(1)}%
              </div>
              <div className="mt-2 w-full bg-gray-200 rounded-full h-2">
                <div
                  className={clsx(
                    'h-2 rounded-full transition-all duration-500',
                    performanceData.current.memory >= 80 ? 'bg-red-500' :
                    performanceData.current.memory >= 60 ? 'bg-yellow-500' : 'bg-green-500'
                  )}
                  style={{ width: `${performanceData.current.memory}%` }}
                />
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">応答時間</div>
              <div className="text-2xl font-bold text-blue-600">
                {performanceData.current.responseTime.toFixed(0)}ms
              </div>
              <div className={clsx(
                'text-sm mt-1',
                performanceData.current.responseTime >= 2000 ? 'text-red-600' :
                performanceData.current.responseTime >= 1000 ? 'text-yellow-600' : 'text-green-600'
              )}>
                {performanceData.current.responseTime < 1000 ? '高速' :
                 performanceData.current.responseTime < 2000 ? '普通' : '低速'}
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">ネットワーク使用率</div>
              <div className="text-2xl font-bold text-blue-600">
                {performanceData.current.network.toFixed(1)}%
              </div>
              <div className="mt-2 w-full bg-gray-200 rounded-full h-2">
                <div
                  className={clsx(
                    'h-2 rounded-full transition-all duration-500',
                    performanceData.current.network >= 80 ? 'bg-red-500' :
                    performanceData.current.network >= 60 ? 'bg-yellow-500' : 'bg-green-500'
                  )}
                  style={{ width: `${performanceData.current.network}%` }}
                />
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">ディスク使用率</div>
              <div className="text-2xl font-bold text-blue-600">
                {performanceData.current.disk.toFixed(1)}%
              </div>
              <div className="mt-2 w-full bg-gray-200 rounded-full h-2">
                <div
                  className={clsx(
                    'h-2 rounded-full transition-all duration-500',
                    performanceData.current.disk >= 80 ? 'bg-red-500' :
                    performanceData.current.disk >= 60 ? 'bg-yellow-500' : 'bg-green-500'
                  )}
                  style={{ width: `${performanceData.current.disk}%` }}
                />
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">スループット</div>
              <div className="text-2xl font-bold text-blue-600">
                {performanceData.current.throughput.toFixed(1)}
                <span className="text-sm text-gray-500 ml-1">req/s</span>
              </div>
              <div className={clsx(
                'text-sm mt-1',
                performanceData.current.throughput >= 100 ? 'text-green-600' :
                performanceData.current.throughput >= 50 ? 'text-yellow-600' : 'text-red-600'
              )}>
                {performanceData.current.throughput >= 100 ? '高' :
                 performanceData.current.throughput >= 50 ? '中' : '低'}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* パフォーマンスチャート */}
      <div className="bg-white rounded-lg shadow-sm p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">
          パフォーマンストレンド - {selectedMetric}
        </h3>
        <div className="relative">
          <canvas
            ref={canvasRef}
            width={800}
            height={300}
            className="w-full h-auto border border-gray-200 rounded-lg"
          />
        </div>
      </div>

      {/* Web Vitals */}
      {webVitals && (
        <div className="bg-white rounded-lg shadow-sm p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Core Web Vitals</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div className="border border-gray-200 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">First Contentful Paint</div>
              <div className="text-2xl font-bold text-blue-600">
                {webVitals.fcp.toFixed(0)}ms
              </div>
              <div className={clsx(
                'text-sm mt-1 px-2 py-1 rounded-full inline-block',
                getRatingColor(getWebVitalRating('fcp', webVitals.fcp))
              )}>
                {getWebVitalRating('fcp', webVitals.fcp) === 'good' ? '良好' :
                 getWebVitalRating('fcp', webVitals.fcp) === 'needs-improvement' ? '改善が必要' : '不良'}
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">Largest Contentful Paint</div>
              <div className="text-2xl font-bold text-blue-600">
                {webVitals.lcp.toFixed(0)}ms
              </div>
              <div className={clsx(
                'text-sm mt-1 px-2 py-1 rounded-full inline-block',
                getRatingColor(getWebVitalRating('lcp', webVitals.lcp))
              )}>
                {getWebVitalRating('lcp', webVitals.lcp) === 'good' ? '良好' :
                 getWebVitalRating('lcp', webVitals.lcp) === 'needs-improvement' ? '改善が必要' : '不良'}
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">First Input Delay</div>
              <div className="text-2xl font-bold text-blue-600">
                {webVitals.fid.toFixed(0)}ms
              </div>
              <div className={clsx(
                'text-sm mt-1 px-2 py-1 rounded-full inline-block',
                getRatingColor(getWebVitalRating('fid', webVitals.fid))
              )}>
                {getWebVitalRating('fid', webVitals.fid) === 'good' ? '良好' :
                 getWebVitalRating('fid', webVitals.fid) === 'needs-improvement' ? '改善が必要' : '不良'}
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">Cumulative Layout Shift</div>
              <div className="text-2xl font-bold text-blue-600">
                {webVitals.cls.toFixed(3)}
              </div>
              <div className={clsx(
                'text-sm mt-1 px-2 py-1 rounded-full inline-block',
                getRatingColor(getWebVitalRating('cls', webVitals.cls))
              )}>
                {getWebVitalRating('cls', webVitals.cls) === 'good' ? '良好' :
                 getWebVitalRating('cls', webVitals.cls) === 'needs-improvement' ? '改善が必要' : '不良'}
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">Time to First Byte</div>
              <div className="text-2xl font-bold text-blue-600">
                {webVitals.ttfb.toFixed(0)}ms
              </div>
              <div className={clsx(
                'text-sm mt-1 px-2 py-1 rounded-full inline-block',
                getRatingColor(getWebVitalRating('ttfb', webVitals.ttfb))
              )}>
                {getWebVitalRating('ttfb', webVitals.ttfb) === 'good' ? '良好' :
                 getWebVitalRating('ttfb', webVitals.ttfb) === 'needs-improvement' ? '改善が必要' : '不良'}
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-4">
              <div className="text-sm text-gray-500 mb-1">Time to Interactive</div>
              <div className="text-2xl font-bold text-blue-600">
                {webVitals.tti.toFixed(0)}ms
              </div>
              <div className={clsx(
                'text-sm mt-1 px-2 py-1 rounded-full inline-block',
                getRatingColor(getWebVitalRating('tti', webVitals.tti))
              )}>
                {getWebVitalRating('tti', webVitals.tti) === 'good' ? '良好' :
                 getWebVitalRating('tti', webVitals.tti) === 'needs-improvement' ? '改善が必要' : '不良'}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* パフォーマンスアラート */}
      {performanceData?.alerts && performanceData.alerts.length > 0 && (
        <div className="bg-white rounded-lg shadow-sm p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">パフォーマンスアラート</h3>
          <div className="space-y-3">
            {performanceData.alerts.map((alert) => (
              <motion.div
                key={alert.id}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                className={clsx(
                  'border rounded-lg p-4',
                  alert.severity === 'critical' ? 'border-red-200 bg-red-50' : 'border-yellow-200 bg-yellow-50'
                )}
              >
                <div className="flex items-start space-x-3">
                  <div className={clsx(
                    'text-2xl',
                    alert.severity === 'critical' ? 'text-red-600' : 'text-yellow-600'
                  )}>
                    {alert.severity === 'critical' ? '🚨' : '⚠️'}
                  </div>
                  <div className="flex-1">
                    <div className="font-medium text-gray-900">{alert.message}</div>
                    <div className="text-sm text-gray-600 mt-1">
                      {alert.metric}: {alert.currentValue} (閾値: {alert.threshold})
                    </div>
                    <div className="text-xs text-gray-500 mt-1">
                      {new Date(alert.timestamp).toLocaleString('ja-JP')}
                    </div>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default PerformanceMonitor;