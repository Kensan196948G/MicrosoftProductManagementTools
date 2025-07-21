// Microsoft 365 Management Tools - Enhanced Feature Button Component
// PowerShell GUI 完全互換 + Backend API統合対応

import React, { useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { clsx } from 'clsx';
import { Loader2, CheckCircle, AlertCircle, Download, Eye, Play } from 'lucide-react';
import { toast } from 'react-hot-toast';
import { FeatureButton as FeatureButtonType } from '../../types/features';
import { CATEGORY_COLORS, UI_CONSTANTS } from '../../config/features';
import { useApiService } from '../../services/api';
import { useAppStore } from '../../store/appStore';

interface FeatureButtonProps {
  feature: FeatureButtonType;
  onClick?: (action: string) => void;
  onExecute?: (feature: FeatureButtonType) => void;
  disabled?: boolean;
  className?: string;
}

export const FeatureButton: React.FC<FeatureButtonProps> = ({
  feature,
  onClick,
  onExecute,
  disabled = false,
  className = ''
}) => {
  const [isHovered, setIsHovered] = useState(false);
  const [isPressed, setIsPressed] = useState(false);
  const [isExecuting, setIsExecuting] = useState(false);
  const [lastExecutionResult, setLastExecutionResult] = useState<'success' | 'error' | null>(null);
  
  const { executeFeature, getExecutionStatus } = useApiService();
  const { settings } = useAppStore();
  const categoryColors = CATEGORY_COLORS[feature.category];
  
  // 機能実行ハンドラー
  const handleExecute = useCallback(async () => {
    if (isExecuting || disabled || feature.status === 'disabled') return;

    try {
      setIsExecuting(true);
      setLastExecutionResult(null);

      // カスタムハンドラーがある場合は優先
      if (onExecute) {
        onExecute(feature);
        return;
      }

      // 従来のonClickハンドラーがある場合
      if (onClick) {
        onClick(feature.action);
        return;
      }

      // Backend API経由で実行
      const execution = await executeFeature({
        action: feature.action,
        parameters: {
          outputPath: settings.outputPath || 'Reports/General',
          autoOpen: settings.autoOpenFiles !== false,
          language: 'ja'
        },
        outputFormat: settings.defaultOutputFormat || 'HTML'
      });

      toast.success(`${feature.text}を開始しました`);

      // 実行状況をポーリング
      const pollInterval = setInterval(async () => {
        try {
          const status = await getExecutionStatus(execution.executionId);
          
          if (status.status === 'completed') {
            clearInterval(pollInterval);
            setLastExecutionResult('success');
            toast.success(`${feature.text}が完了しました`);
            
            // レポートファイルの自動表示
            if (status.outputUrl && settings.autoOpenFiles !== false) {
              window.open(status.outputUrl, '_blank');
            }
            
          } else if (status.status === 'failed') {
            clearInterval(pollInterval);
            setLastExecutionResult('error');
            toast.error(`${feature.text}の実行に失敗しました`);
          }
        } catch (error) {
          clearInterval(pollInterval);
          setLastExecutionResult('error');
          console.error('Status polling error:', error);
        }
      }, 2000);

      // 5分でタイムアウト
      setTimeout(() => {
        clearInterval(pollInterval);
        if (isExecuting) {
          setLastExecutionResult('error');
          toast.error(`${feature.text}の実行がタイムアウトしました`);
        }
      }, 300000);

    } catch (error) {
      setLastExecutionResult('error');
      console.error('Feature execution error:', error);
      toast.error(`${feature.text}の実行に失敗しました`);
    } finally {
      setIsExecuting(false);
    }
  }, [feature, onExecute, onClick, disabled, isExecuting, executeFeature, getExecutionStatus, settings]);

  const handleClick = () => {
    handleExecute();
  };

  const handleKeyDown = (event: React.KeyboardEvent) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      handleClick();
    }
  };

  // ステータスアイコン取得
  const getStatusIcon = () => {
    if (isExecuting) {
      return <Loader2 className="w-4 h-4 animate-spin text-white" />;
    }
    if (lastExecutionResult === 'success') {
      return <CheckCircle className="w-4 h-4 text-green-400" />;
    }
    if (lastExecutionResult === 'error') {
      return <AlertCircle className="w-4 h-4 text-red-400" />;
    }
    return null;
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
        'w-[190px] h-[50px] min-w-[190px] max-w-[220px]',
        
        // レスポンシブ対応
        'sm:w-[180px] sm:h-[48px] sm:text-xs',
        'md:w-[190px] md:h-[50px] md:text-sm',
        'lg:w-[200px] lg:h-[52px] lg:text-sm',
        'xl:w-[210px] xl:h-[54px] xl:text-base',
        
        // 状態別スタイル
        {
          'bg-blue-600 border-blue-700 hover:bg-blue-700 active:bg-blue-800': 
            feature.status === 'active' && !disabled && !isExecuting,
          'bg-gray-400 border-gray-500 cursor-not-allowed': 
            feature.status === 'disabled' || disabled,
          'bg-blue-500 border-blue-600 cursor-wait': 
            feature.status === 'loading' || isExecuting,
          'bg-green-600 border-green-700': lastExecutionResult === 'success',
          'bg-red-600 border-red-700': lastExecutionResult === 'error',
          'focus:ring-blue-500': feature.status === 'active'
        },
        
        // アクセシビリティ対応
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500',
        'active:transform active:scale-95',
        
        // ハイコントラストモード対応
        'contrast-more:border-2',
        
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
      disabled={disabled || feature.status === 'disabled' || isExecuting}
      aria-label={`${feature.text} - ${feature.description}`}
      aria-pressed={isPressed}
      aria-busy={feature.status === 'loading' || isExecuting}
      role="button"
      tabIndex={0}
      data-testid={`feature-button-${feature.id}`}
      
      // アニメーション設定（モーション無効化対応）
      whileHover={!window.matchMedia('(prefers-reduced-motion: reduce)').matches ? { scale: 1.02 } : {}}
      whileTap={!window.matchMedia('(prefers-reduced-motion: reduce)').matches ? { scale: 0.98 } : {}}
      transition={{ 
        duration: window.matchMedia('(prefers-reduced-motion: reduce)').matches 
          ? 0.01 
          : UI_CONSTANTS.ANIMATION_DURATION / 1000 
      }}
    >
      {/* アクティブ状態のオーバーレイ */}
      <AnimatePresence>
        {isExecuting && (
          <motion.div
            className="absolute inset-0 bg-blue-500 opacity-10 rounded"
            initial={{ scale: 0, opacity: 0 }}
            animate={{ scale: 1, opacity: 0.1 }}
            exit={{ scale: 0, opacity: 0 }}
            transition={{ duration: 0.3 }}
          />
        )}
      </AnimatePresence>

      {/* メインコンテンツ */}
      <div className="flex items-center justify-between h-full w-full relative z-10 px-2">
        {/* ボタンテキスト */}
        <span className="text-center leading-tight break-words flex-1">
          {feature.text}
        </span>
        
        {/* ステータスアイコン */}
        <div className="ml-2 flex-shrink-0">
          {getStatusIcon()}
        </div>
      </div>
      
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