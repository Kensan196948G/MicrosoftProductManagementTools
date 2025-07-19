// Microsoft 365 Management Tools - Main Application Component
// PowerShell GUI 互換 React アプリケーション

import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { MainDashboard } from './components/dashboard/MainDashboard';
import { NotFound } from './components/error/NotFound';
import { LoadingSpinner } from './components/shared/LoadingSpinner';
import { useAppStore } from './store/appStore';
import { useAuth, useSystemStatus } from './hooks/useApi';

// Lazy Loading Components
const Settings = React.lazy(() => import('./pages/Settings'));
const Reports = React.lazy(() => import('./pages/Reports'));
const Logs = React.lazy(() => import('./pages/Logs'));
const MonitoringPage = React.lazy(() => import('./pages/MonitoringPage'));

const App: React.FC = () => {
  const { loadSettings } = useAppStore();
  const { isCheckingAuth } = useAuth();
  const { isLoading: isSystemLoading } = useSystemStatus();

  // 初期設定の読み込み
  React.useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  // 初期化中のローディング
  if (isCheckingAuth || isSystemLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <LoadingSpinner size="large" message="アプリケーションを初期化中..." />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <React.Suspense 
        fallback={
          <div className="min-h-screen bg-gray-50 flex items-center justify-center">
            <LoadingSpinner size="large" message="ページを読み込み中..." />
          </div>
        }
      >
        <Routes>
          {/* メインダッシュボード */}
          <Route path="/" element={<MainDashboard />} />
          
          {/* 機能別ページ */}
          <Route path="/reports" element={<Reports />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="/logs" element={<Logs />} />
          <Route path="/monitoring" element={<MonitoringPage />} />
          
          {/* 404エラー */}
          <Route path="*" element={<NotFound />} />
        </Routes>
      </React.Suspense>
    </div>
  );
};

export default App;