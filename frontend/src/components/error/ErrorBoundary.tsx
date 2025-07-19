// Microsoft 365 Management Tools - Error Boundary Component
// React エラーバウンダリとエラーハンドリング

import React, { Component, ReactNode } from 'react';
import { motion } from 'framer-motion';

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
  errorInfo: React.ErrorInfo | null;
  errorId: string;
}

interface ErrorBoundaryProps {
  children: ReactNode;
  fallback?: ReactNode;
  onError?: (error: Error, errorInfo: React.ErrorInfo) => void;
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null,
      errorId: '',
    };
  }

  static getDerivedStateFromError(error: Error): Partial<ErrorBoundaryState> {
    return {
      hasError: true,
      error,
      errorId: `error_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
    };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    this.setState({
      errorInfo,
    });

    // エラーログの記録
    console.error('Error Boundary Caught:', error, errorInfo);

    // コールバック実行
    if (this.props.onError) {
      this.props.onError(error, errorInfo);
    }

    // エラーレポーティング（本番環境）
    if (process.env.NODE_ENV === 'production') {
      this.reportErrorToService(error, errorInfo);
    }
  }

  private reportErrorToService = (error: Error, errorInfo: React.ErrorInfo) => {
    // エラーレポーティングサービスへの送信
    // 実際の実装では、エラートラッキングサービス（Sentry, LogRocket等）を使用
    const errorReport = {
      errorId: this.state.errorId,
      message: error.message,
      stack: error.stack,
      componentStack: errorInfo.componentStack,
      timestamp: new Date().toISOString(),
      userAgent: navigator.userAgent,
      url: window.location.href,
    };

    console.log('Error Report:', errorReport);
    
    // fetch('/api/errors', {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify(errorReport),
    // });
  };

  private handleReload = () => {
    window.location.reload();
  };

  private handleReset = () => {
    this.setState({
      hasError: false,
      error: null,
      errorInfo: null,
      errorId: '',
    });
  };

  private handleReportBug = () => {
    const { error, errorInfo, errorId } = this.state;
    
    const bugReport = {
      errorId,
      message: error?.message || 'Unknown error',
      stack: error?.stack || 'No stack trace',
      componentStack: errorInfo?.componentStack || 'No component stack',
      timestamp: new Date().toISOString(),
      userAgent: navigator.userAgent,
      url: window.location.href,
    };

    // Bug報告システムへの送信
    console.log('Bug Report:', bugReport);
    
    // GitHubやJira等のIssue作成
    const issueBody = `
エラーID: ${errorId}
エラーメッセージ: ${error?.message}
発生時刻: ${new Date().toLocaleString()}
URL: ${window.location.href}
ユーザーエージェント: ${navigator.userAgent}

スタックトレース:
${error?.stack}

コンポーネントスタック:
${errorInfo?.componentStack}
    `;

    const githubUrl = `https://github.com/organization/repo/issues/new?title=Frontend Error: ${encodeURIComponent(error?.message || 'Unknown error')}&body=${encodeURIComponent(issueBody)}`;
    
    window.open(githubUrl, '_blank');
  };

  render() {
    if (this.state.hasError) {
      // カスタムフォールバックUIがある場合
      if (this.props.fallback) {
        return this.props.fallback;
      }

      // デフォルトエラーUI
      return (
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
          className="min-h-screen bg-gray-50 flex items-center justify-center px-4"
        >
          <div className="max-w-md w-full bg-white rounded-lg shadow-lg p-6">
            {/* エラーアイコン */}
            <div className="flex items-center justify-center w-16 h-16 mx-auto bg-red-100 rounded-full mb-4">
              <svg
                className="w-8 h-8 text-red-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                />
              </svg>
            </div>

            {/* エラーメッセージ */}
            <div className="text-center">
              <h1 className="text-xl font-bold text-gray-900 mb-2">
                アプリケーションエラー
              </h1>
              <p className="text-gray-600 mb-4">
                予期しないエラーが発生しました。お手数ですが、ページを再読み込みしてください。
              </p>
              
              {/* エラーID */}
              <div className="bg-gray-100 rounded-md p-3 mb-4">
                <p className="text-sm text-gray-700">
                  <span className="font-semibold">エラーID:</span> {this.state.errorId}
                </p>
              </div>

              {/* 開発環境でのエラー詳細 */}
              {process.env.NODE_ENV === 'development' && (
                <details className="mt-4 text-left">
                  <summary className="cursor-pointer font-semibold text-red-600 mb-2">
                    開発者向け詳細情報
                  </summary>
                  <div className="bg-red-50 border border-red-200 rounded-md p-3 text-sm">
                    <div className="mb-2">
                      <strong>エラーメッセージ:</strong>
                      <pre className="whitespace-pre-wrap text-red-800">
                        {this.state.error?.message}
                      </pre>
                    </div>
                    <div className="mb-2">
                      <strong>スタックトレース:</strong>
                      <pre className="whitespace-pre-wrap text-red-800 text-xs">
                        {this.state.error?.stack}
                      </pre>
                    </div>
                    <div>
                      <strong>コンポーネントスタック:</strong>
                      <pre className="whitespace-pre-wrap text-red-800 text-xs">
                        {this.state.errorInfo?.componentStack}
                      </pre>
                    </div>
                  </div>
                </details>
              )}

              {/* アクションボタン */}
              <div className="flex flex-col space-y-2 mt-6">
                <button
                  onClick={this.handleReload}
                  className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-md transition-colors"
                >
                  ページを再読み込み
                </button>
                
                <button
                  onClick={this.handleReset}
                  className="w-full bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-4 rounded-md transition-colors"
                >
                  エラーをリセット
                </button>
                
                <button
                  onClick={this.handleReportBug}
                  className="w-full bg-red-600 hover:bg-red-700 text-white font-medium py-2 px-4 rounded-md transition-colors"
                >
                  バグを報告
                </button>
              </div>

              {/* サポート情報 */}
              <div className="mt-4 text-sm text-gray-500">
                <p>
                  問題が続く場合は、システム管理者にお問い合わせください。
                </p>
                <p className="mt-1">
                  エラーID: <code className="font-mono">{this.state.errorId}</code>
                </p>
              </div>
            </div>
          </div>
        </motion.div>
      );
    }

    return this.props.children;
  }
}

// HOC: エラーバウンダリでコンポーネントをラップ
export const withErrorBoundary = <P extends object>(
  Component: React.ComponentType<P>,
  fallback?: ReactNode
) => {
  const WrappedComponent = (props: P) => (
    <ErrorBoundary fallback={fallback}>
      <Component {...props} />
    </ErrorBoundary>
  );

  WrappedComponent.displayName = `withErrorBoundary(${Component.displayName || Component.name})`;
  return WrappedComponent;
};

export default ErrorBoundary;