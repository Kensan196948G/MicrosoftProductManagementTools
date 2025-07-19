// Microsoft 365 Management Tools - React Application Entry Point
// PowerShell GUI 完全互換 React アプリケーション

import React from 'react';
import ReactDOM from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { BrowserRouter } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import App from './App';
import { AccessibilityProvider } from './components/accessibility/AccessibilityProvider';
import { ErrorBoundary } from './components/error/ErrorBoundary';
import { initializePerformanceOptimization } from './utils/performance';
import { initializeSecurity } from './utils/security';
import './styles/globals.css';

// React Query設定
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 3,
      retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
      staleTime: 5 * 60 * 1000, // 5分
      cacheTime: 10 * 60 * 1000, // 10分
      refetchOnWindowFocus: false,
      refetchOnReconnect: true,
    },
    mutations: {
      retry: 1,
    },
  },
});

// パフォーマンス最適化の初期化
initializePerformanceOptimization();

// セキュリティ機能の初期化
initializeSecurity();

// エラーハンドリング
const handleError = (error: Error, errorInfo: React.ErrorInfo) => {
  console.error('React Error Boundary:', error, errorInfo);
  
  // エラーレポーティング（本番環境では実際のサービスに送信）
  if (process.env.NODE_ENV === 'production') {
    // sendErrorToService(error, errorInfo);
  }
};

// アプリケーションルート
const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

root.render(
  <React.StrictMode>
    <ErrorBoundary onError={handleError}>
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <AccessibilityProvider>
            <App />
            
            {/* React Query DevTools（開発環境のみ） */}
            {process.env.NODE_ENV === 'development' && (
              <ReactQueryDevtools initialIsOpen={false} />
            )}
            
            {/* Toast通知 */}
            <Toaster
              position="top-right"
              toastOptions={{
                duration: 4000,
                style: {
                  background: '#363636',
                  color: '#fff',
                  fontSize: '14px',
                },
                success: {
                  iconTheme: {
                    primary: '#4ade80',
                    secondary: '#fff',
                  },
                },
                error: {
                  iconTheme: {
                    primary: '#ef4444',
                    secondary: '#fff',
                  },
                },
              }}
            />
          </AccessibilityProvider>
        </BrowserRouter>
      </QueryClientProvider>
    </ErrorBoundary>
  </React.StrictMode>
);

// Service Worker登録（プロダクション環境）
if ('serviceWorker' in navigator && process.env.NODE_ENV === 'production') {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then((registration) => {
        console.log('SW registered: ', registration);
      })
      .catch((registrationError) => {
        console.log('SW registration failed: ', registrationError);
      });
  });
}

// パフォーマンス測定（開発環境）
if (process.env.NODE_ENV === 'development') {
  import('web-vitals').then(({ getCLS, getFID, getFCP, getLCP, getTTFB }) => {
    getCLS(console.log);
    getFID(console.log);
    getFCP(console.log);
    getLCP(console.log);
    getTTFB(console.log);
  });
}