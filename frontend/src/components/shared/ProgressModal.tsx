// Microsoft 365 Management Tools - Progress Modal Component
// PowerShell GUI 互換の進捗表示モーダル

import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { clsx } from 'clsx';
import { ProgressState } from '../../types/features';

interface ProgressModalProps {
  isVisible: boolean;
  progress: number;
  total: number;
  message: string;
  stage: ProgressState['stage'];
  onClose: () => void;
  className?: string;
}

export const ProgressModal: React.FC<ProgressModalProps> = ({
  isVisible,
  progress,
  total,
  message,
  stage,
  onClose,
  className = ''
}) => {
  const [displayProgress, setDisplayProgress] = useState(0);

  // 進捗のアニメーション
  useEffect(() => {
    if (isVisible) {
      const timer = setTimeout(() => {
        setDisplayProgress(progress);
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [progress, isVisible]);

  // 進捗率計算
  const progressPercentage = Math.min((displayProgress / total) * 100, 100);

  // ステージ別のアイコンとカラー
  const stageConfig = {
    connecting: {
      icon: '🔄',
      color: 'text-blue-600',
      bgColor: 'bg-blue-50',
      borderColor: 'border-blue-200'
    },
    processing: {
      icon: '⚙️',
      color: 'text-yellow-600',
      bgColor: 'bg-yellow-50',
      borderColor: 'border-yellow-200'
    },
    generating: {
      icon: '📊',
      color: 'text-green-600',
      bgColor: 'bg-green-50',
      borderColor: 'border-green-200'
    },
    completed: {
      icon: '✅',
      color: 'text-green-600',
      bgColor: 'bg-green-50',
      borderColor: 'border-green-200'
    },
    error: {
      icon: '❌',
      color: 'text-red-600',
      bgColor: 'bg-red-50',
      borderColor: 'border-red-200'
    }
  };

  const currentStage = stageConfig[stage];

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
        >
          <motion.div
            className={clsx(
              'bg-white rounded-lg shadow-xl max-w-md w-full mx-4',
              currentStage.bgColor,
              currentStage.borderColor,
              'border-2',
              className
            )}
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.8, opacity: 0 }}
            transition={{ duration: 0.2 }}
            role="dialog"
            aria-modal="true"
            aria-labelledby="progress-title"
            aria-describedby="progress-description"
          >
            {/* ヘッダー */}
            <div className="p-6 pb-4">
              <div className="flex items-center justify-between">
                <h3 
                  id="progress-title"
                  className="text-lg font-medium text-gray-900"
                >
                  実行中...
                </h3>
                
                {/* 閉じるボタン（完了時のみ） */}
                {stage === 'completed' && (
                  <button
                    onClick={onClose}
                    className="text-gray-400 hover:text-gray-600 transition-colors"
                    aria-label="閉じる"
                  >
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                )}
              </div>
              
              {/* ステージ表示 */}
              <div className="flex items-center mt-4 space-x-3">
                <div className="text-2xl animate-pulse">
                  {currentStage.icon}
                </div>
                <div className="flex-1">
                  <p 
                    id="progress-description"
                    className={clsx('text-sm font-medium', currentStage.color)}
                  >
                    {message}
                  </p>
                </div>
              </div>
            </div>

            {/* 進捗バー */}
            <div className="px-6 pb-6">
              <div className="w-full bg-gray-200 rounded-full h-2.5 mb-4">
                <motion.div
                  className="bg-blue-600 h-2.5 rounded-full"
                  initial={{ width: 0 }}
                  animate={{ width: `${progressPercentage}%` }}
                  transition={{ duration: 0.5, ease: "easeInOut" }}
                />
              </div>
              
              {/* 進捗数値 */}
              <div className="flex justify-between text-sm text-gray-600">
                <span>{displayProgress}%</span>
                <span>{Math.round(progressPercentage)}%</span>
              </div>
            </div>

            {/* エラー時の詳細 */}
            {stage === 'error' && (
              <div className="px-6 pb-6">
                <div className="bg-red-50 border border-red-200 rounded-md p-4">
                  <div className="flex">
                    <div className="flex-shrink-0">
                      <svg className="h-5 w-5 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
                      </svg>
                    </div>
                    <div className="ml-3">
                      <p className="text-sm text-red-800">
                        実行中にエラーが発生しました。再度お試しください。
                      </p>
                    </div>
                  </div>
                </div>
                
                <div className="mt-4 flex justify-end space-x-3">
                  <button
                    onClick={onClose}
                    className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    閉じる
                  </button>
                </div>
              </div>
            )}

            {/* 完了時のアクション */}
            {stage === 'completed' && (
              <div className="px-6 pb-6">
                <div className="bg-green-50 border border-green-200 rounded-md p-4">
                  <div className="flex">
                    <div className="flex-shrink-0">
                      <svg className="h-5 w-5 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </div>
                    <div className="ml-3">
                      <p className="text-sm text-green-800">
                        実行が正常に完了しました。
                      </p>
                    </div>
                  </div>
                </div>
                
                <div className="mt-4 flex justify-end space-x-3">
                  <button
                    onClick={onClose}
                    className="px-4 py-2 text-sm font-medium text-white bg-green-600 border border-transparent rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
                  >
                    OK
                  </button>
                </div>
              </div>
            )}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

// 軽量版の進捗インジケーター
export const ProgressIndicator: React.FC<{
  progress: number;
  total: number;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}> = ({ progress, total, size = 'md', className = '' }) => {
  const percentage = Math.min((progress / total) * 100, 100);
  
  const sizeClasses = {
    sm: 'h-1',
    md: 'h-2',
    lg: 'h-3'
  };

  return (
    <div className={clsx('w-full bg-gray-200 rounded-full', sizeClasses[size], className)}>
      <motion.div
        className="bg-blue-600 h-full rounded-full"
        initial={{ width: 0 }}
        animate={{ width: `${percentage}%` }}
        transition={{ duration: 0.5, ease: "easeInOut" }}
      />
    </div>
  );
};

export default ProgressModal;