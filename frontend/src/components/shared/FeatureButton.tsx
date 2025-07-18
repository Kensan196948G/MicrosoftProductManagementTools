// Microsoft 365 Management Tools - Feature Button Component
// PowerShell Windows Forms GUI 完全互換のボタンコンポーネント

import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { clsx } from 'clsx';
import { FeatureButton as FeatureButtonType } from '../../types/features';
import { CATEGORY_COLORS, UI_CONSTANTS } from '../../config/features';

interface FeatureButtonProps {
  feature: FeatureButtonType;
  onClick: (action: string) => void;
  disabled?: boolean;
  className?: string;
}

export const FeatureButton: React.FC<FeatureButtonProps> = ({
  feature,
  onClick,
  disabled = false,
  className = ''
}) => {
  const [isHovered, setIsHovered] = useState(false);
  const [isPressed, setIsPressed] = useState(false);
  
  const categoryColors = CATEGORY_COLORS[feature.category];
  
  const handleClick = () => {
    if (!disabled && feature.status !== 'disabled') {
      onClick(feature.action);
    }
  };

  const handleKeyDown = (event: React.KeyboardEvent) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      handleClick();
    }
  };

  return (
    <motion.button
      className={clsx(
        // 基本スタイル
        'relative inline-flex items-center justify-center',
        'text-sm font-bold text-white',
        'border border-solid cursor-pointer',
        'transition-colors duration-200',
        'focus:outline-none focus:ring-2 focus:ring-offset-2',
        
        // サイズ（PowerShell GUI 互換: 190x50px）
        'w-[190px] h-[50px]',
        
        // 状態別スタイル
        {
          'bg-blue-600 border-blue-700 hover:bg-blue-700 active:bg-blue-800': 
            feature.status === 'active' && !disabled,
          'bg-gray-400 border-gray-500 cursor-not-allowed': 
            feature.status === 'disabled' || disabled,
          'bg-blue-500 border-blue-600 cursor-wait': 
            feature.status === 'loading',
          'focus:ring-blue-500': feature.status === 'active'
        },
        
        // カスタムクラス
        className
      )}
      style={{
        backgroundColor: isPressed 
          ? categoryColors.accent 
          : isHovered 
            ? categoryColors.secondary 
            : categoryColors.primary,
        borderColor: categoryColors.accent,
        borderRadius: `${UI_CONSTANTS.BORDER_RADIUS}px`
      }}
      onClick={handleClick}
      onKeyDown={handleKeyDown}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => {
        setIsHovered(false);
        setIsPressed(false);
      }}
      onMouseDown={() => setIsPressed(true)}
      onMouseUp={() => setIsPressed(false)}
      disabled={disabled || feature.status === 'disabled'}
      aria-label={`${feature.text} - ${feature.description}`}
      aria-pressed={isPressed}
      aria-busy={feature.status === 'loading'}
      role="button"
      tabIndex={0}
      
      // アニメーション設定
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.98 }}
      transition={{ duration: UI_CONSTANTS.ANIMATION_DURATION / 1000 }}
    >
      {/* ローディング状態の表示 */}
      {feature.status === 'loading' && (
        <div className="absolute inset-0 flex items-center justify-center bg-blue-500 bg-opacity-90 rounded">
          <div className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent" />
        </div>
      )}
      
      {/* ボタンテキスト */}
      <span className="relative z-10 text-center leading-tight">
        {feature.text}
      </span>
      
      {/* ホバー効果（PowerShell GUI 互換）*/}
      <motion.div
        className="absolute inset-0 rounded"
        initial={{ opacity: 0 }}
        animate={{ opacity: isHovered ? 0.1 : 0 }}
        transition={{ duration: 0.2 }}
        style={{
          backgroundColor: 'white',
          borderRadius: `${UI_CONSTANTS.BORDER_RADIUS}px`
        }}
      />
      
      {/* フォーカス表示 */}
      <div 
        className={clsx(
          'absolute inset-0 rounded border-2 border-white opacity-0 transition-opacity duration-200',
          'focus-within:opacity-50'
        )}
        style={{ borderRadius: `${UI_CONSTANTS.BORDER_RADIUS}px` }}
      />
    </motion.button>
  );
};

// アクセシビリティ対応のボタングループ
export const FeatureButtonGroup: React.FC<{
  features: FeatureButtonType[];
  onFeatureClick: (action: string) => void;
  className?: string;
}> = ({ features, onFeatureClick, className = '' }) => {
  return (
    <div 
      className={clsx('grid gap-4', className)}
      role="group"
      aria-label="機能ボタン"
    >
      {features.map((feature) => (
        <FeatureButton
          key={feature.id}
          feature={feature}
          onClick={onFeatureClick}
        />
      ))}
    </div>
  );
};

export default FeatureButton;