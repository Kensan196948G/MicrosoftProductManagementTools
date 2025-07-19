// Microsoft 365 Management Tools - Monitoring Components Export
// 24/7本格運用監視システム - コンポーネント一覧

export { HealthMonitor } from './HealthMonitor';
export { PerformanceMonitor } from './PerformanceMonitor';
export { AlertManager } from './AlertManager';
export { LogViewer } from './LogViewer';
export { MonitoringDashboard } from './MonitoringDashboard';

// 監視システムの型定義
export interface MonitoringConfig {
  refreshInterval: number;
  alertsEnabled: boolean;
  notificationsEnabled: boolean;
  realtimeUpdates: boolean;
  logLevel: 'debug' | 'info' | 'warn' | 'error' | 'fatal';
  retentionDays: number;
}

// デフォルト設定
export const defaultMonitoringConfig: MonitoringConfig = {
  refreshInterval: 30000, // 30秒
  alertsEnabled: true,
  notificationsEnabled: true,
  realtimeUpdates: true,
  logLevel: 'info',
  retentionDays: 30,
};

// 監視システムユーティリティ
export const monitoringUtils = {
  formatUptime: (seconds: number): string => {
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
  },

  formatBytes: (bytes: number): string => {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let size = bytes;
    let unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return `${size.toFixed(1)} ${units[unitIndex]}`;
  },

  getStatusColor: (status: string): string => {
    switch (status) {
      case 'healthy': return 'text-green-600';
      case 'warning': return 'text-yellow-600';
      case 'critical': return 'text-red-600';
      case 'error': return 'text-red-600';
      default: return 'text-gray-600';
    }
  },

  getStatusIcon: (status: string): string => {
    switch (status) {
      case 'healthy': return '✅';
      case 'warning': return '⚠️';
      case 'critical': return '🚨';
      case 'error': return '❌';
      default: return '❓';
    }
  },

  calculatePercentage: (current: number, total: number): number => {
    if (total === 0) return 0;
    return Math.round((current / total) * 100);
  },

  isThresholdExceeded: (value: number, threshold: number): boolean => {
    return value >= threshold;
  },

  generateAlertId: (): string => {
    return `alert_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  },

  formatLogLevel: (level: string): string => {
    return level.charAt(0).toUpperCase() + level.slice(1).toLowerCase();
  },

  parseLogTimestamp: (timestamp: string): Date => {
    return new Date(timestamp);
  },

  formatDuration: (milliseconds: number): string => {
    const seconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) {
      return `${days}日前`;
    } else if (hours > 0) {
      return `${hours}時間前`;
    } else if (minutes > 0) {
      return `${minutes}分前`;
    } else {
      return `${seconds}秒前`;
    }
  },

  validateThreshold: (value: number, min: number = 0, max: number = 100): boolean => {
    return value >= min && value <= max;
  },

  generateCorrelationId: (): string => {
    return `correlation_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  },

  sanitizeLogMessage: (message: string): string => {
    // 潜在的に危険な文字列をサニタイズ
    return message
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#x27;')
      .replace(/\//g, '&#x2F;');
  },

  checkSystemHealth: (metrics: Record<string, number>): 'healthy' | 'warning' | 'critical' => {
    const criticalThresholds = {
      cpu: 90,
      memory: 90,
      disk: 95,
      errorRate: 10,
    };

    const warningThresholds = {
      cpu: 70,
      memory: 70,
      disk: 80,
      errorRate: 5,
    };

    // 重要な問題をチェック
    for (const [metric, value] of Object.entries(metrics)) {
      if (criticalThresholds[metric] && value >= criticalThresholds[metric]) {
        return 'critical';
      }
    }

    // 警告レベルをチェック
    for (const [metric, value] of Object.entries(metrics)) {
      if (warningThresholds[metric] && value >= warningThresholds[metric]) {
        return 'warning';
      }
    }

    return 'healthy';
  },

  exportData: (data: any[], filename: string = 'monitoring_data.json'): void => {
    const blob = new Blob([JSON.stringify(data, null, 2)], {
      type: 'application/json',
    });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    window.URL.revokeObjectURL(url);
    document.body.removeChild(a);
  },

  playNotificationSound: (type: 'info' | 'warning' | 'error' | 'success' = 'info'): void => {
    const audio = new Audio(`/sounds/${type}.mp3`);
    audio.play().catch(() => {
      // 音声再生に失敗した場合は無視
    });
  },

  requestNotificationPermission: (): Promise<NotificationPermission> => {
    if ('Notification' in window) {
      return Notification.requestPermission();
    }
    return Promise.resolve('denied');
  },

  showBrowserNotification: (title: string, message: string, type: 'info' | 'warning' | 'error' = 'info'): void => {
    if (Notification.permission === 'granted') {
      new Notification(title, {
        body: message,
        icon: '/favicon.ico',
        badge: '/favicon.ico',
        requireInteraction: type === 'error',
      });
    }
  },
};

// 監視システムのコンスタント
export const MONITORING_CONSTANTS = {
  REFRESH_INTERVALS: {
    FAST: 10000,    // 10秒
    NORMAL: 30000,  // 30秒
    SLOW: 60000,    // 1分
    VERY_SLOW: 300000, // 5分
  },
  
  THRESHOLDS: {
    CPU: {
      WARNING: 70,
      CRITICAL: 90,
    },
    MEMORY: {
      WARNING: 70,
      CRITICAL: 90,
    },
    DISK: {
      WARNING: 80,
      CRITICAL: 95,
    },
    RESPONSE_TIME: {
      WARNING: 1000,
      CRITICAL: 2000,
    },
    ERROR_RATE: {
      WARNING: 1,
      CRITICAL: 5,
    },
  },
  
  LOG_LEVELS: {
    DEBUG: 0,
    INFO: 1,
    WARN: 2,
    ERROR: 3,
    FATAL: 4,
  },
  
  ALERT_SEVERITIES: {
    INFO: 'info',
    WARNING: 'warning',
    ERROR: 'error',
    CRITICAL: 'critical',
  },
  
  RETENTION_PERIODS: {
    LOGS: 30,      // 30日
    METRICS: 90,   // 90日
    ALERTS: 365,   // 365日
  },
};

export default {
  HealthMonitor,
  PerformanceMonitor,
  AlertManager,
  LogViewer,
  MonitoringDashboard,
  monitoringUtils,
  defaultMonitoringConfig,
  MONITORING_CONSTANTS,
};