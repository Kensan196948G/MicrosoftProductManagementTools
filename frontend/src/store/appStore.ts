// Microsoft 365 Management Tools - App Store (Zustand)
// PowerShell GUI 互換の状態管理

import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { UIState, TabCategory, AuthState, ThemeConfig, AccessibilityConfig } from '../types/features';

interface AppState extends UIState {
  // Actions
  setActiveTab: (tab: TabCategory) => void;
  toggleSidebar: () => void;
  toggleLogVisible: () => void;
  setTheme: (theme: Partial<ThemeConfig>) => void;
  setAccessibility: (config: Partial<AccessibilityConfig>) => void;
  setAuth: (auth: Partial<AuthState>) => void;
  setLastAction: (action: string) => void;
  
  // Connection actions
  connect: () => Promise<void>;
  disconnect: () => void;
  
  // Settings
  loadSettings: () => void;
  saveSettings: () => void;
  resetSettings: () => void;
}

// 初期状態
const initialState: UIState = {
  activeTab: 'regular-reports',
  sidebarOpen: true,
  logVisible: false,
  
  theme: {
    mode: 'light',
    primaryColor: '#0078d4',
    fontSize: 14,
    compactMode: false
  },
  
  accessibility: {
    highContrast: false,
    reducedMotion: false,
    screenReader: false,
    keyboardNavigation: true,
    fontSize: 'medium'
  },
  
  progress: {
    isVisible: false,
    current: 0,
    total: 100,
    message: '',
    stage: 'connecting'
  },
  
  auth: {
    isConnected: false,
    lastConnected: undefined,
    connectionStatus: 'disconnected',
    services: {
      graph: false,
      exchange: false,
      teams: false,
      oneDrive: false
    }
  },
  
  lastAction: undefined
};

export const useAppStore = create<AppState>()(
  persist(
    (set, get) => ({
      ...initialState,
      
      // Tab management
      setActiveTab: (tab: TabCategory) => {
        set({ activeTab: tab });
      },
      
      // UI toggles
      toggleSidebar: () => {
        set((state) => ({ sidebarOpen: !state.sidebarOpen }));
      },
      
      toggleLogVisible: () => {
        set((state) => ({ logVisible: !state.logVisible }));
      },
      
      // Theme management
      setTheme: (theme: Partial<ThemeConfig>) => {
        set((state) => ({
          theme: { ...state.theme, ...theme }
        }));
      },
      
      // Accessibility management
      setAccessibility: (config: Partial<AccessibilityConfig>) => {
        set((state) => ({
          accessibility: { ...state.accessibility, ...config }
        }));
      },
      
      // Auth management
      setAuth: (auth: Partial<AuthState>) => {
        set((state) => ({
          auth: { ...state.auth, ...auth }
        }));
      },
      
      // Action tracking
      setLastAction: (action: string) => {
        set({ lastAction: action });
      },
      
      // Connection management
      connect: async () => {
        set((state) => ({
          auth: {
            ...state.auth,
            connectionStatus: 'connecting'
          }
        }));
        
        try {
          // 実際の接続処理はここに実装
          // 現在はシミュレーション
          await new Promise(resolve => setTimeout(resolve, 2000));
          
          set((state) => ({
            auth: {
              ...state.auth,
              isConnected: true,
              lastConnected: new Date(),
              connectionStatus: 'connected',
              services: {
                graph: true,
                exchange: true,
                teams: true,
                oneDrive: true
              }
            }
          }));
          
        } catch (error) {
          set((state) => ({
            auth: {
              ...state.auth,
              isConnected: false,
              connectionStatus: 'error',
              services: {
                graph: false,
                exchange: false,
                teams: false,
                oneDrive: false
              }
            }
          }));
          
          throw error;
        }
      },
      
      disconnect: () => {
        set((state) => ({
          auth: {
            ...state.auth,
            isConnected: false,
            connectionStatus: 'disconnected',
            services: {
              graph: false,
              exchange: false,
              teams: false,
              oneDrive: false
            }
          }
        }));
      },
      
      // Settings management
      loadSettings: () => {
        // 設定のロード（localStorage から自動的に復元される）
        const state = get();
        
        // システム設定の適用
        if (state.accessibility.highContrast) {
          document.documentElement.classList.add('high-contrast');
        }
        
        if (state.accessibility.reducedMotion) {
          document.documentElement.classList.add('reduce-motion');
        }
        
        if (state.theme.mode === 'dark') {
          document.documentElement.classList.add('dark');
        }
      },
      
      saveSettings: () => {
        // 設定の保存（persist middleware により自動的に保存される）
        const state = get();
        
        // 追加の設定保存処理があればここに実装
        console.log('Settings saved:', {
          theme: state.theme,
          accessibility: state.accessibility
        });
      },
      
      resetSettings: () => {
        set({
          theme: initialState.theme,
          accessibility: initialState.accessibility,
          sidebarOpen: initialState.sidebarOpen,
          logVisible: initialState.logVisible
        });
        
        // DOM クラスのリセット
        document.documentElement.classList.remove('high-contrast', 'reduce-motion', 'dark');
      }
    }),
    {
      name: 'microsoft-365-tools-settings',
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({
        theme: state.theme,
        accessibility: state.accessibility,
        sidebarOpen: state.sidebarOpen,
        logVisible: state.logVisible,
        activeTab: state.activeTab
      })
    }
  )
);

// セレクター関数
export const useAuth = () => useAppStore((state) => state.auth);
export const useTheme = () => useAppStore((state) => state.theme);
export const useAccessibility = () => useAppStore((state) => state.accessibility);
export const useProgress = () => useAppStore((state) => state.progress);

// アクション関数
export const useAuthActions = () => useAppStore((state) => ({
  connect: state.connect,
  disconnect: state.disconnect,
  setAuth: state.setAuth
}));

export const useThemeActions = () => useAppStore((state) => ({
  setTheme: state.setTheme,
  resetSettings: state.resetSettings
}));

export const useAccessibilityActions = () => useAppStore((state) => ({
  setAccessibility: state.setAccessibility
}));

export default useAppStore;