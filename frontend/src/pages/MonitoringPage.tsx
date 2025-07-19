// Microsoft 365 Management Tools - Monitoring Page
// 24/7本格運用監視システム - 監視ページ

import React, { useEffect } from 'react';
import { motion } from 'framer-motion';
import { Helmet } from 'react-helmet-async';
import { MonitoringDashboard } from '../components/monitoring';
import { useAppStore } from '../store/appStore';

export const MonitoringPage: React.FC = () => {
  const { user, isAuthenticated } = useAppStore();

  useEffect(() => {
    // 監視ページアクセス時の認証チェック
    if (!isAuthenticated) {
      // 認証されていない場合は監視ページへのアクセスを制限
      window.location.href = '/login';
      return;
    }

    // 監視ページアクセスログ
    console.log(`[Monitoring] User ${user?.name || 'Unknown'} accessed monitoring dashboard`);
  }, [isAuthenticated, user]);

  // 認証されていない場合のローディング表示
  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="bg-white rounded-lg shadow-sm p-8 max-w-md text-center"
        >
          <div className="text-4xl mb-4">🔐</div>
          <h2 className="text-xl font-semibold text-gray-900 mb-2">
            認証が必要です
          </h2>
          <p className="text-gray-600 mb-4">
            監視ダッシュボードにアクセスするには認証が必要です。
          </p>
          <button
            onClick={() => window.location.href = '/login'}
            className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-md"
          >
            ログインページへ
          </button>
        </motion.div>
      </div>
    );
  }

  return (
    <>
      <Helmet>
        <title>監視ダッシュボード - Microsoft 365 Management Tools</title>
        <meta name="description" content="24/7本格運用監視システム - システムヘルス、パフォーマンス、アラート、ログの統合監視" />
        <meta name="keywords" content="監視,ダッシュボード,Microsoft 365,システムヘルス,パフォーマンス,アラート,ログ" />
      </Helmet>
      
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.3 }}
      >
        <MonitoringDashboard />
      </motion.div>
    </>
  );
};

export default MonitoringPage;