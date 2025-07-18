// Microsoft 365 Management Tools - Feature Grid Component
// PowerShell Windows Forms GUI 互換のグリッドレイアウト

import React, { useMemo } from 'react';
import { motion } from 'framer-motion';
import { clsx } from 'clsx';
import { FeatureButton } from '../shared/FeatureButton';
import { TabConfig, FeatureButton as FeatureButtonType } from '../../types/features';
import { UI_CONSTANTS } from '../../config/features';

interface FeatureGridProps {
  tab: TabConfig;
  onFeatureClick: (action: string) => void;
  className?: string;
}

export const FeatureGrid: React.FC<FeatureGridProps> = ({
  tab,
  onFeatureClick,
  className = ''
}) => {
  // グリッドレイアウト計算（PowerShell GUI 互換）
  const gridConfig = useMemo(() => {
    switch (tab.layout) {
      case 'grid-2x2':
        return {
          cols: 2,
          rows: 2,
          gridClass: 'grid-cols-2',
          containerClass: 'max-w-2xl'
        };
      case 'grid-3x2':
        return {
          cols: 3,
          rows: 2,
          gridClass: 'grid-cols-3',
          containerClass: 'max-w-4xl'
        };
      case 'grid-3x3':
        return {
          cols: 3,
          rows: 3,
          gridClass: 'grid-cols-3',
          containerClass: 'max-w-4xl'
        };
      default:
        return {
          cols: 3,
          rows: 2,
          gridClass: 'grid-cols-3',
          containerClass: 'max-w-4xl'
        };
    }
  }, [tab.layout]);

  // レスポンシブ対応のグリッドクラス
  const responsiveGridClass = useMemo(() => {
    if (gridConfig.cols === 2) {
      return 'grid-cols-1 sm:grid-cols-2';
    } else if (gridConfig.cols === 3) {
      return 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3';
    }
    return 'grid-cols-1';
  }, [gridConfig.cols]);

  return (
    <div 
      className={clsx(
        'w-full mx-auto px-4 py-6',
        gridConfig.containerClass,
        className
      )}
      role="region"
      aria-labelledby={`tab-${tab.id}`}
      aria-describedby={`tab-${tab.id}-description`}
    >
      {/* タブ説明 */}
      <div className="mb-6 text-center">
        <h2 
          id={`tab-${tab.id}`}
          className="text-2xl font-bold text-gray-900 mb-2"
        >
          {tab.title}
        </h2>
        <p 
          id={`tab-${tab.id}-description`}
          className="text-gray-600 text-sm"
        >
          {tab.description}
        </p>
      </div>

      {/* 機能ボタングリッド */}
      <motion.div
        className={clsx(
          'grid gap-4',
          responsiveGridClass,
          // デスクトップでの中央寄せ
          'justify-items-center'
        )}
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3, staggerChildren: 0.1 }}
      >
        {tab.features.map((feature, index) => (
          <motion.div
            key={feature.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, delay: index * 0.1 }}
          >
            <FeatureButton
              feature={feature}
              onClick={onFeatureClick}
              className="w-full"
            />
          </motion.div>
        ))}
      </motion.div>
    </div>
  );
};

// 高度な機能を持つグリッドコンポーネント
export const EnhancedFeatureGrid: React.FC<FeatureGridProps & {
  searchTerm?: string;
  filterStatus?: 'all' | 'active' | 'disabled';
  sortBy?: 'name' | 'category' | 'status';
}> = ({
  tab,
  onFeatureClick,
  searchTerm = '',
  filterStatus = 'all',
  sortBy = 'name',
  className = ''
}) => {
  // フィルタリングとソート
  const filteredFeatures = useMemo(() => {
    let filtered = [...tab.features];

    // 検索フィルター
    if (searchTerm) {
      filtered = filtered.filter(feature =>
        feature.text.toLowerCase().includes(searchTerm.toLowerCase()) ||
        feature.description.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    // ステータスフィルター
    if (filterStatus !== 'all') {
      filtered = filtered.filter(feature => feature.status === filterStatus);
    }

    // ソート
    filtered.sort((a, b) => {
      switch (sortBy) {
        case 'name':
          return a.text.localeCompare(b.text);
        case 'category':
          return a.category.localeCompare(b.category);
        case 'status':
          return a.status.localeCompare(b.status);
        default:
          return 0;
      }
    });

    return filtered;
  }, [tab.features, searchTerm, filterStatus, sortBy]);

  // グリッドレイアウト計算
  const gridConfig = useMemo(() => {
    const featureCount = filteredFeatures.length;
    if (featureCount <= 4) {
      return {
        cols: 2,
        gridClass: 'grid-cols-1 sm:grid-cols-2',
        containerClass: 'max-w-2xl'
      };
    } else if (featureCount <= 6) {
      return {
        cols: 3,
        gridClass: 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3',
        containerClass: 'max-w-4xl'
      };
    } else {
      return {
        cols: 4,
        gridClass: 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4',
        containerClass: 'max-w-6xl'
      };
    }
  }, [filteredFeatures.length]);

  return (
    <div 
      className={clsx(
        'w-full mx-auto px-4 py-6',
        gridConfig.containerClass,
        className
      )}
      role="region"
      aria-labelledby={`tab-${tab.id}`}
      aria-live="polite"
    >
      {/* 検索結果の表示 */}
      {searchTerm && (
        <div className="mb-4 text-center">
          <p className="text-sm text-gray-600">
            "{searchTerm}" の検索結果: {filteredFeatures.length}件
          </p>
        </div>
      )}

      {/* 機能ボタングリッド */}
      <motion.div
        className={clsx(
          'grid gap-4',
          gridConfig.gridClass,
          'justify-items-center'
        )}
        layout
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.3 }}
      >
        {filteredFeatures.map((feature, index) => (
          <motion.div
            key={feature.id}
            layout
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.8 }}
            transition={{ duration: 0.2, delay: index * 0.05 }}
          >
            <FeatureButton
              feature={feature}
              onClick={onFeatureClick}
              className="w-full"
            />
          </motion.div>
        ))}
      </motion.div>

      {/* 結果なしの表示 */}
      {filteredFeatures.length === 0 && (
        <motion.div
          className="text-center py-12"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.3 }}
        >
          <div className="text-gray-400 text-6xl mb-4">🔍</div>
          <h3 className="text-lg font-medium text-gray-900 mb-2">
            機能が見つかりませんでした
          </h3>
          <p className="text-gray-600">
            検索条件を変更してお試しください
          </p>
        </motion.div>
      )}
    </div>
  );
};

export default FeatureGrid;