// Microsoft 365 Management Tools - 404 Not Found Component
// 404エラーページ

import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';

export const NotFound: React.FC = () => {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      className="min-h-screen bg-gray-50 flex items-center justify-center px-4"
    >
      <div className="max-w-md w-full text-center">
        {/* 404 イラスト */}
        <motion.div
          initial={{ scale: 0.8 }}
          animate={{ scale: 1 }}
          transition={{ duration: 0.5, delay: 0.2 }}
          className="mb-8"
        >
          <div className="text-6xl font-bold text-blue-600 mb-4">404</div>
          <div className="text-8xl mb-4">🔍</div>
        </motion.div>

        {/* メッセージ */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.5, delay: 0.4 }}
        >
          <h1 className="text-2xl font-bold text-gray-900 mb-4">
            ページが見つかりません
          </h1>
          <p className="text-gray-600 mb-8">
            お探しのページは削除されたか、URLが間違っている可能性があります。
          </p>
        </motion.div>

        {/* アクションボタン */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.6 }}
          className="space-y-4"
        >
          <Link
            to="/"
            className="block w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-3 px-6 rounded-md transition-colors"
          >
            ホームに戻る
          </Link>
          
          <button
            onClick={() => window.history.back()}
            className="block w-full bg-gray-200 hover:bg-gray-300 text-gray-800 font-medium py-3 px-6 rounded-md transition-colors"
          >
            前のページに戻る
          </button>
        </motion.div>

        {/* サポート情報 */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.5, delay: 0.8 }}
          className="mt-8 text-sm text-gray-500"
        >
          <p>
            問題が続く場合は、システム管理者にお問い合わせください。
          </p>
        </motion.div>
      </div>
    </motion.div>
  );
};

export default NotFound;