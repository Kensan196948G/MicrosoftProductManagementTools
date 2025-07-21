// Microsoft 365 Management Tools - Main Dashboard Component
// PowerShell Windows Forms GUI 完全互換のメインダッシュボード

import React, { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import toast from 'react-hot-toast';
import { TabNavigation } from '../layout/TabNavigation';
import { FeatureGrid } from './FeatureGrid';
import { ProgressModal } from '../shared/ProgressModal';
import { TabCategory, ExecutionResult, ProgressState } from '../../types/features';
import { FEATURE_TABS } from '../../config/features';
import { useAppStore } from '../../store/appStore';
import { useApiService } from '../../services/api';

interface MainDashboardProps {
  className?: string;
}

export const MainDashboard: React.FC<MainDashboardProps> = ({
  className = ''
}) => {
  const [activeTab, setActiveTab] = useState<TabCategory>('regular-reports');
  const [progress, setProgress] = useState<ProgressState>({
    isVisible: false,
    current: 0,
    total: 100,
    message: '',
    stage: 'connecting'
  });

  const { auth, theme, settings } = useAppStore();
  const { executeFeature, getExecutionStatus, checkAuthStatus, healthCheck } = useApiService();

  // アクティブタブの設定
  const activeTabConfig = FEATURE_TABS.find(tab => tab.id === activeTab);

  // 接続状態チェック
  useEffect(() => {
    const checkConnection = async () => {
      try {
        const isHealthy = await healthCheck();
        if (isHealthy) {
          const authStatus = await checkAuthStatus();
          // 認証状態をストアに反映
        }
      } catch (error) {
        console.error('Connection check failed:', error);
      }
    };

    checkConnection();
    const interval = setInterval(checkConnection, 30000); // 30秒ごと
    return () => clearInterval(interval);
  }, [healthCheck, checkAuthStatus]);

  // 機能実行のハンドラー
  const handleFeatureClick = useCallback(async (action: string) => {
    try {
      // 進捗モーダルを表示
      setProgress({
        isVisible: true,
        current: 0,
        total: 100,
        message: '接続中...',
        stage: 'connecting'
      });

      // 段階的な進捗更新
      const stages = [
        { message: 'Microsoft 365 に接続中...', progress: 20, stage: 'connecting' as const },
        { message: 'データを取得中...', progress: 50, stage: 'processing' as const },
        { message: 'レポートを生成中...', progress: 80, stage: 'generating' as const },
        { message: '完了', progress: 100, stage: 'completed' as const }
      ];

      for (const stage of stages) {
        await new Promise(resolve => setTimeout(resolve, 1000));
        setProgress(prev => ({
          ...prev,
          current: stage.progress,
          message: stage.message,
          stage: stage.stage
        }));
      }

      // 実際のAPI呼び出し（プレースホルダー）
      const result = await executeFeature(action);
      
      if (result.success) {
        toast.success(`${action} が正常に実行されました`);
        
        // ファイルが生成された場合の処理
        if (result.outputPath) {
          toast.success(`レポートが生成されました: ${result.outputPath}`);
        }
      } else {
        toast.error(`実行エラー: ${result.message}`);
      }

    } catch (error) {
      console.error('Feature execution error:', error);
      toast.error('実行中にエラーが発生しました');
      
      setProgress(prev => ({
        ...prev,
        stage: 'error',
        message: 'エラーが発生しました'
      }));
    } finally {
      // 進捗モーダルを非表示
      setTimeout(() => {
        setProgress(prev => ({ ...prev, isVisible: false }));
      }, 1500);
    }
  }, []);

  // 機能実行の実装（プレースホルダー）
  const executeFeature = async (action: string): Promise<ExecutionResult> => {
    // 実際のAPI呼び出しまたはPowerShellブリッジ呼び出し
    // 現在はシミュレーション
    
    return {
      success: true,
      message: `${action} completed successfully`,
      outputPath: `/Reports/${action}_${new Date().toISOString().split('T')[0]}.html`,
      reportType: 'HTML',
      timestamp: new Date()
    };
  };

  // キーボードショートカット
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.ctrlKey || event.metaKey) {
        switch (event.key) {
          case 'r':
            event.preventDefault();
            setActiveTab('regular-reports');
            break;
          case 't':
            event.preventDefault();
            setActiveTab('analytics-reports');
            break;
          case 'q':
            event.preventDefault();
            // アプリケーション終了（必要に応じて）
            break;
        }
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, []);

  return (
    <div className={`min-h-screen bg-gray-50 ${className}`}>
      {/* ヘッダー */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center">
              <h1 className="text-xl font-bold text-gray-900">
                🚀 Microsoft 365統合管理ツール
              </h1>
              <span className="ml-2 px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded-full">
                React版
              </span>
            </div>
            
            {/* 接続状態表示 */}
            <div className="flex items-center space-x-4">
              <div className={`flex items-center space-x-2 ${
                auth.isConnected ? 'text-green-600' : 'text-gray-400'
              }`}>
                <div className={`w-2 h-2 rounded-full ${
                  auth.isConnected ? 'bg-green-500' : 'bg-gray-400'
                }`} />
                <span className="text-sm">
                  {auth.isConnected ? 'Connected' : 'Disconnected'}
                </span>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* タブナビゲーション */}
      <TabNavigation
        activeTab={activeTab}
        onTabChange={setActiveTab}
        className="bg-white shadow-sm"
      />

      {/* メインコンテンツ */}
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <AnimatePresence mode="wait">
          <motion.div
            key={activeTab}
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            transition={{ duration: 0.2 }}
            className="bg-white rounded-lg shadow-sm"
          >
            {activeTabConfig && (
              <FeatureGrid
                tab={activeTabConfig}
                onFeatureClick={handleFeatureClick}
                className="p-6"
              />
            )}
          </motion.div>
        </AnimatePresence>
      </main>

      {/* 進捗モーダル */}
      <ProgressModal
        isVisible={progress.isVisible}
        progress={progress.current}
        total={progress.total}
        message={progress.message}
        stage={progress.stage}
        onClose={() => setProgress(prev => ({ ...prev, isVisible: false }))}
      />

      {/* フッター */}
      <footer className="bg-white border-t mt-auto">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex items-center justify-between text-sm text-gray-500">
            <div>
              Microsoft 365 Management Tools v1.0.0
            </div>
            <div>
              PowerShell → React 移行版
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default MainDashboard;