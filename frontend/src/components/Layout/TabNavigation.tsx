// Microsoft 365 Management Tools - Tab Navigation Component
// PowerShell Windows Forms GUI 互換のタブナビゲーション

import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { clsx } from 'clsx';
import { TabCategory } from '../../types/features';
import { FEATURE_TABS } from '../../config/features';

interface TabNavigationProps {
  activeTab: TabCategory;
  onTabChange: (tab: TabCategory) => void;
  className?: string;
}

export const TabNavigation: React.FC<TabNavigationProps> = ({
  activeTab,
  onTabChange,
  className = ''
}) => {
  const [focusedTab, setFocusedTab] = useState<TabCategory | null>(null);

  // キーボードナビゲーション
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') {
        event.preventDefault();
        
        const currentIndex = FEATURE_TABS.findIndex(tab => tab.id === activeTab);
        const direction = event.key === 'ArrowRight' ? 1 : -1;
        const nextIndex = (currentIndex + direction + FEATURE_TABS.length) % FEATURE_TABS.length;
        
        onTabChange(FEATURE_TABS[nextIndex].id);
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [activeTab, onTabChange]);

  return (
    <div 
      className={clsx(
        'flex bg-white border-b border-gray-200 overflow-x-auto',
        'scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100',
        className
      )}
      role="tablist"
      aria-label="Microsoft 365 管理機能"
    >
      {FEATURE_TABS.map((tab, index) => {
        const isActive = tab.id === activeTab;
        const isFocused = tab.id === focusedTab;
        
        return (
          <motion.button
            key={tab.id}
            className={clsx(
              // 基本スタイル
              'relative flex-shrink-0 px-4 py-3 text-sm font-medium',
              'border-b-2 transition-colors duration-200',
              'focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500',
              'hover:text-blue-600 hover:border-blue-300',
              'min-w-[140px] max-w-[200px]',
              
              // アクティブ状態
              {
                'text-blue-600 border-blue-500 bg-blue-50': isActive,
                'text-gray-500 border-transparent hover:border-gray-300': !isActive,
                'ring-2 ring-blue-500': isFocused
              }
            )}
            onClick={() => onTabChange(tab.id)}
            onFocus={() => setFocusedTab(tab.id)}
            onBlur={() => setFocusedTab(null)}
            role="tab"
            aria-selected={isActive}
            aria-controls={`tabpanel-${tab.id}`}
            tabIndex={isActive ? 0 : -1}
            id={`tab-${tab.id}`}
            
            // アニメーション
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
          >
            {/* タブコンテンツ */}
            <div className="flex items-center space-x-2">
              <span className="text-lg" aria-hidden="true">
                {tab.icon}
              </span>
              <span className="truncate">
                {tab.title}
              </span>
            </div>
            
            {/* アクティブインジケーター */}
            <AnimatePresence>
              {isActive && (
                <motion.div
                  className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-500"
                  initial={{ scaleX: 0 }}
                  animate={{ scaleX: 1 }}
                  exit={{ scaleX: 0 }}
                  transition={{ duration: 0.2 }}
                />
              )}
            </AnimatePresence>
            
            {/* ホバー効果 */}
            <motion.div
              className="absolute inset-0 bg-blue-50 opacity-0 pointer-events-none"
              whileHover={{ opacity: 0.5 }}
              transition={{ duration: 0.2 }}
            />
          </motion.button>
        );
      })}
    </div>
  );
};

// レスポンシブタブナビゲーション
export const ResponsiveTabNavigation: React.FC<TabNavigationProps> = ({
  activeTab,
  onTabChange,
  className = ''
}) => {
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 768);
    };

    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  const activeTabConfig = FEATURE_TABS.find(tab => tab.id === activeTab);

  if (isMobile) {
    return (
      <div className={clsx('relative', className)}>
        {/* モバイル用ドロップダウン */}
        <button
          className="w-full flex items-center justify-between px-4 py-3 bg-white border-b border-gray-200 text-left"
          onClick={() => setIsDropdownOpen(!isDropdownOpen)}
          aria-expanded={isDropdownOpen}
          aria-haspopup="listbox"
        >
          <div className="flex items-center space-x-2">
            <span className="text-lg">{activeTabConfig?.icon}</span>
            <span className="font-medium">{activeTabConfig?.title}</span>
          </div>
          <svg
            className={clsx(
              'w-5 h-5 transition-transform duration-200',
              isDropdownOpen ? 'rotate-180' : 'rotate-0'
            )}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        {/* ドロップダウンメニュー */}
        <AnimatePresence>
          {isDropdownOpen && (
            <motion.div
              className="absolute top-full left-0 right-0 bg-white border border-gray-200 shadow-lg z-50"
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              transition={{ duration: 0.2 }}
            >
              {FEATURE_TABS.map((tab) => (
                <button
                  key={tab.id}
                  className={clsx(
                    'w-full flex items-center space-x-3 px-4 py-3 text-left hover:bg-gray-50',
                    {
                      'bg-blue-50 text-blue-600': tab.id === activeTab,
                      'text-gray-700': tab.id !== activeTab
                    }
                  )}
                  onClick={() => {
                    onTabChange(tab.id);
                    setIsDropdownOpen(false);
                  }}
                >
                  <span className="text-lg">{tab.icon}</span>
                  <div>
                    <div className="font-medium">{tab.title}</div>
                    <div className="text-xs text-gray-500">{tab.description}</div>
                  </div>
                </button>
              ))}
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    );
  }

  return (
    <TabNavigation
      activeTab={activeTab}
      onTabChange={onTabChange}
      className={className}
    />
  );
};

export default ResponsiveTabNavigation;