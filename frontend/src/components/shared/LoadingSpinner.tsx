// Microsoft 365 Management Tools - Loading Spinner Component
// ローディング状態とスケルトンUI

import React from 'react';
import { motion } from 'framer-motion';
import { clsx } from 'clsx';

interface LoadingSpinnerProps {
  size?: 'small' | 'medium' | 'large';
  message?: string;
  className?: string;
}

export const LoadingSpinner: React.FC<LoadingSpinnerProps> = ({
  size = 'medium',
  message,
  className = '',
}) => {
  const sizeClasses = {
    small: 'w-4 h-4',
    medium: 'w-8 h-8',
    large: 'w-12 h-12',
  };

  const containerClasses = {
    small: 'p-2',
    medium: 'p-4',
    large: 'p-6',
  };

  return (
    <div className={clsx('flex flex-col items-center justify-center', containerClasses[size], className)}>
      <motion.div
        className={clsx(
          'border-2 border-gray-200 border-t-blue-600 rounded-full',
          sizeClasses[size]
        )}
        animate={{ rotate: 360 }}
        transition={{
          duration: 1,
          repeat: Infinity,
          ease: 'linear',
        }}
      />
      
      {message && (
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.5 }}
          className="mt-2 text-sm text-gray-600 text-center"
        >
          {message}
        </motion.p>
      )}
    </div>
  );
};

// スケルトンローダー
export const SkeletonLoader: React.FC<{
  width?: string;
  height?: string;
  className?: string;
}> = ({ width = '100%', height = '1rem', className = '' }) => {
  return (
    <motion.div
      className={clsx('bg-gray-200 rounded', className)}
      style={{ width, height }}
      animate={{ opacity: [1, 0.5, 1] }}
      transition={{
        duration: 1.5,
        repeat: Infinity,
        ease: 'easeInOut',
      }}
    />
  );
};

// ボタン用スケルトン
export const ButtonSkeleton: React.FC<{
  className?: string;
}> = ({ className = '' }) => {
  return (
    <SkeletonLoader
      width="190px"
      height="50px"
      className={clsx('rounded-md', className)}
    />
  );
};

// カード用スケルトン
export const CardSkeleton: React.FC<{
  className?: string;
}> = ({ className = '' }) => {
  return (
    <div className={clsx('bg-white rounded-lg shadow-sm p-6', className)}>
      <SkeletonLoader width="60%" height="1.5rem" className="mb-4" />
      <SkeletonLoader width="100%" height="1rem" className="mb-2" />
      <SkeletonLoader width="80%" height="1rem" className="mb-4" />
      <SkeletonLoader width="120px" height="2rem" className="rounded-md" />
    </div>
  );
};

// テーブル用スケルトン
export const TableSkeleton: React.FC<{
  rows?: number;
  columns?: number;
  className?: string;
}> = ({ rows = 5, columns = 4, className = '' }) => {
  return (
    <div className={clsx('bg-white rounded-lg shadow-sm overflow-hidden', className)}>
      {/* ヘッダー */}
      <div className="bg-gray-50 px-6 py-3 border-b">
        <div className="flex space-x-4">
          {Array.from({ length: columns }).map((_, index) => (
            <SkeletonLoader key={index} width="120px" height="1.25rem" />
          ))}
        </div>
      </div>
      
      {/* ボディ */}
      <div className="divide-y divide-gray-200">
        {Array.from({ length: rows }).map((_, rowIndex) => (
          <div key={rowIndex} className="px-6 py-4">
            <div className="flex space-x-4">
              {Array.from({ length: columns }).map((_, colIndex) => (
                <SkeletonLoader
                  key={colIndex}
                  width={colIndex === 0 ? '150px' : '100px'}
                  height="1rem"
                />
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ダッシュボード用スケルトン
export const DashboardSkeleton: React.FC = () => {
  return (
    <div className="min-h-screen bg-gray-50">
      {/* ヘッダー */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <SkeletonLoader width="300px" height="1.5rem" />
            <SkeletonLoader width="100px" height="1rem" />
          </div>
        </div>
      </div>

      {/* タブナビゲーション */}
      <div className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex space-x-8 py-4">
            {Array.from({ length: 6 }).map((_, index) => (
              <SkeletonLoader key={index} width="140px" height="1.25rem" />
            ))}
          </div>
        </div>
      </div>

      {/* メインコンテンツ */}
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="bg-white rounded-lg shadow-sm p-6">
          {/* タイトル */}
          <div className="text-center mb-6">
            <SkeletonLoader width="200px" height="2rem" className="mx-auto mb-2" />
            <SkeletonLoader width="300px" height="1rem" className="mx-auto" />
          </div>

          {/* 機能ボタングリッド */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 justify-items-center">
            {Array.from({ length: 6 }).map((_, index) => (
              <ButtonSkeleton key={index} />
            ))}
          </div>
        </div>
      </main>
    </div>
  );
};

// プログレスバー付きローディング
export const ProgressLoading: React.FC<{
  progress: number;
  message?: string;
  className?: string;
}> = ({ progress, message, className = '' }) => {
  return (
    <div className={clsx('flex flex-col items-center justify-center p-6', className)}>
      <LoadingSpinner size="large" />
      
      {/* プログレスバー */}
      <div className="w-full max-w-md mt-4">
        <div className="bg-gray-200 rounded-full h-2 mb-2">
          <motion.div
            className="bg-blue-600 h-2 rounded-full"
            initial={{ width: 0 }}
            animate={{ width: `${Math.min(progress, 100)}%` }}
            transition={{ duration: 0.5 }}
          />
        </div>
        <div className="flex justify-between text-sm text-gray-600">
          <span>{Math.round(progress)}%</span>
          <span>完了</span>
        </div>
      </div>
      
      {message && (
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          className="mt-2 text-sm text-gray-600 text-center"
        >
          {message}
        </motion.p>
      )}
    </div>
  );
};

export default LoadingSpinner;