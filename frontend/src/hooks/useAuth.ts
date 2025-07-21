// Microsoft 365 Management Tools - 認証Hook
import { useState, useEffect, useCallback } from 'react';
import { apiClient, AuthenticationRequest, AuthenticationResponse } from '../services/api';
import { toast } from 'react-hot-toast';

export interface AuthHookState {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: any | null;
  authStatus: AuthenticationResponse | null;
  error: string | null;
}

export interface AuthHookActions {
  login: (request: AuthenticationRequest) => Promise<void>;
  logout: () => void;
  checkAuth: () => Promise<void>;
  refreshAuth: () => Promise<void>;
  clearError: () => void;
}

export const useAuth = (): AuthHookState & AuthHookActions => {
  const [state, setState] = useState<AuthHookState>({
    isAuthenticated: false,
    isLoading: true,
    user: null,
    authStatus: null,
    error: null,
  });

  // 認証状態確認
  const checkAuth = useCallback(async () => {
    try {
      setState(prev => ({ ...prev, isLoading: true, error: null }));
      
      // ローカルストレージから認証情報復元
      const storedUser = apiClient.getCurrentUser();
      
      if (storedUser && apiClient.isAuthenticated()) {
        // バックエンドで認証状態確認
        const authStatus = await apiClient.checkAuthStatus();
        
        setState(prev => ({
          ...prev,
          isAuthenticated: authStatus.isAuthenticated,
          user: authStatus.userInfo || storedUser,
          authStatus,
          isLoading: false,
        }));
      } else {
        setState(prev => ({
          ...prev,
          isAuthenticated: false,
          user: null,
          authStatus: null,
          isLoading: false,
        }));
      }
    } catch (error: any) {
      console.error('Auth check failed:', error);
      
      // 認証確認失敗時はローカル認証情報をクリア
      apiClient.resetAuth();
      
      setState(prev => ({
        ...prev,
        isAuthenticated: false,
        user: null,
        authStatus: null,
        error: error.message || '認証状態の確認に失敗しました',
        isLoading: false,
      }));
    }
  }, []);

  // ログイン
  const login = useCallback(async (request: AuthenticationRequest) => {
    try {
      setState(prev => ({ ...prev, isLoading: true, error: null }));
      
      const authResponse = await apiClient.authenticate(request);
      
      if (authResponse.isAuthenticated) {
        // ユーザー情報をローカルストレージに保存
        if (authResponse.userInfo) {
          localStorage.setItem('user_info', JSON.stringify(authResponse.userInfo));
        }
        
        setState(prev => ({
          ...prev,
          isAuthenticated: true,
          user: authResponse.userInfo,
          authStatus: authResponse,
          error: null,
          isLoading: false,
        }));
        
        toast.success('Microsoft 365 に正常に認証されました');
      } else {
        throw new Error('認証に失敗しました');
      }
    } catch (error: any) {
      console.error('Login failed:', error);
      
      setState(prev => ({
        ...prev,
        isAuthenticated: false,
        user: null,
        authStatus: null,
        error: error.message || 'ログインに失敗しました',
        isLoading: false,
      }));
      
      toast.error(error.message || 'ログインに失敗しました');
    }
  }, []);

  // ログアウト
  const logout = useCallback(() => {
    apiClient.resetAuth();
    
    setState({
      isAuthenticated: false,
      isLoading: false,
      user: null,
      authStatus: null,
      error: null,
    });
    
    toast.success('ログアウトしました');
  }, []);

  // 認証情報更新
  const refreshAuth = useCallback(async () => {
    await checkAuth();
  }, [checkAuth]);

  // エラークリア
  const clearError = useCallback(() => {
    setState(prev => ({ ...prev, error: null }));
  }, []);

  // 認証期限切れイベントリスナー
  useEffect(() => {
    const handleAuthExpired = () => {
      setState(prev => ({
        ...prev,
        isAuthenticated: false,
        user: null,
        authStatus: null,
        error: '認証が期限切れになりました',
      }));
      
      toast.error('認証が期限切れになりました。再ログインしてください。');
    };

    window.addEventListener('auth-expired', handleAuthExpired);
    
    return () => {
      window.removeEventListener('auth-expired', handleAuthExpired);
    };
  }, []);

  // 初期認証状態確認
  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  // 定期的な認証状態確認（5分間隔）
  useEffect(() => {
    if (state.isAuthenticated) {
      const interval = setInterval(() => {
        checkAuth();
      }, 5 * 60 * 1000); // 5分
      
      return () => clearInterval(interval);
    }
  }, [state.isAuthenticated, checkAuth]);

  return {
    ...state,
    login,
    logout,
    checkAuth,
    refreshAuth,
    clearError,
  };
};

export default useAuth;