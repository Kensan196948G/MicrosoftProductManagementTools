// Microsoft 365 Management Tools - Security Utilities
// エンタープライズセキュリティ強化ユーティリティ

import { clsx } from 'clsx';

// セキュリティ設定
export interface SecurityConfig {
  enableCSP: boolean;
  enableXSSProtection: boolean;
  enableClickjacking: boolean;
  enableSecureCookies: boolean;
  enableHSTS: boolean;
  maxLoginAttempts: number;
  sessionTimeout: number;
  passwordMinLength: number;
  requireMFA: boolean;
}

// デフォルトセキュリティ設定
export const defaultSecurityConfig: SecurityConfig = {
  enableCSP: true,
  enableXSSProtection: true,
  enableClickjacking: true,
  enableSecureCookies: true,
  enableHSTS: true,
  maxLoginAttempts: 5,
  sessionTimeout: 30 * 60 * 1000, // 30分
  passwordMinLength: 12,
  requireMFA: true,
};

// セキュリティユーティリティクラス
export class SecurityUtils {
  private static config: SecurityConfig = defaultSecurityConfig;

  // セキュリティ設定の更新
  static setConfig(config: Partial<SecurityConfig>): void {
    this.config = { ...this.config, ...config };
  }

  // XSS防止: HTMLエスケープ
  static escapeHtml(text: string): string {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // XSS防止: HTMLサニタイズ
  static sanitizeHtml(html: string): string {
    const allowedTags = ['b', 'i', 'em', 'strong', 'span', 'div', 'p', 'br'];
    const allowedAttrs = ['class', 'style'];
    
    // 簡易的なHTMLサニタイズ（本番環境ではDOMPurifyを使用）
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = html;
    
    const sanitize = (node: Node): void => {
      if (node.nodeType === Node.ELEMENT_NODE) {
        const element = node as Element;
        
        // 許可されていないタグを削除
        if (!allowedTags.includes(element.tagName.toLowerCase())) {
          element.remove();
          return;
        }
        
        // 許可されていない属性を削除
        Array.from(element.attributes).forEach(attr => {
          if (!allowedAttrs.includes(attr.name.toLowerCase())) {
            element.removeAttribute(attr.name);
          }
        });
        
        // 子ノードを再帰的にサニタイズ
        Array.from(element.childNodes).forEach(child => {
          sanitize(child);
        });
      }
    };
    
    Array.from(tempDiv.childNodes).forEach(child => {
      sanitize(child);
    });
    
    return tempDiv.innerHTML;
  }

  // SQLインジェクション防止: パラメータエスケープ
  static escapeQueryParameter(param: string): string {
    return param.replace(/['"\\]/g, '\\$&');
  }

  // CSRF防止: CSRFトークンの生成
  static generateCSRFToken(): string {
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
  }

  // CSRF防止: CSRFトークンの検証
  static validateCSRFToken(token: string, expectedToken: string): boolean {
    if (!token || !expectedToken) return false;
    
    // タイミング攻撃防止のための定数時間比較
    if (token.length !== expectedToken.length) return false;
    
    let result = 0;
    for (let i = 0; i < token.length; i++) {
      result |= token.charCodeAt(i) ^ expectedToken.charCodeAt(i);
    }
    
    return result === 0;
  }

  // パスワード強度チェック
  static checkPasswordStrength(password: string): {
    score: number;
    feedback: string[];
    isValid: boolean;
  } {
    const feedback: string[] = [];
    let score = 0;

    // 長さチェック
    if (password.length < this.config.passwordMinLength) {
      feedback.push(`パスワードは${this.config.passwordMinLength}文字以上である必要があります`);
    } else {
      score += 1;
    }

    // 大文字チェック
    if (!/[A-Z]/.test(password)) {
      feedback.push('大文字を含む必要があります');
    } else {
      score += 1;
    }

    // 小文字チェック
    if (!/[a-z]/.test(password)) {
      feedback.push('小文字を含む必要があります');
    } else {
      score += 1;
    }

    // 数字チェック
    if (!/[0-9]/.test(password)) {
      feedback.push('数字を含む必要があります');
    } else {
      score += 1;
    }

    // 特殊文字チェック
    if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
      feedback.push('特殊文字を含む必要があります');
    } else {
      score += 1;
    }

    // 共通パスワードチェック
    const commonPasswords = [
      'password', '123456', 'password123', 'admin', 'qwerty',
      'letmein', 'welcome', 'monkey', '1234567890', 'abc123'
    ];
    
    if (commonPasswords.includes(password.toLowerCase())) {
      feedback.push('よく使われるパスワードは避けてください');
      score = Math.max(0, score - 2);
    }

    return {
      score: Math.min(score, 5),
      feedback,
      isValid: score >= 4 && feedback.length === 0
    };
  }

  // セッション管理
  static isSessionValid(sessionStart: number): boolean {
    const now = Date.now();
    return (now - sessionStart) < this.config.sessionTimeout;
  }

  // セキュアランダム文字列生成
  static generateSecureRandomString(length: number = 32): string {
    const array = new Uint8Array(length);
    crypto.getRandomValues(array);
    return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
  }

  // IPアドレスの検証
  static validateIPAddress(ip: string): boolean {
    const ipv4Regex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    const ipv6Regex = /^(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$/;
    
    return ipv4Regex.test(ip) || ipv6Regex.test(ip);
  }

  // URLの検証
  static validateURL(url: string): boolean {
    try {
      const urlObj = new URL(url);
      // HTTPSのみ許可
      return urlObj.protocol === 'https:';
    } catch {
      return false;
    }
  }

  // ファイルアップロードの検証
  static validateFileUpload(file: File): {
    isValid: boolean;
    errors: string[];
  } {
    const errors: string[] = [];
    const maxSize = 10 * 1024 * 1024; // 10MB
    const allowedTypes = [
      'image/jpeg', 'image/png', 'image/gif', 'image/webp',
      'application/pdf', 'text/plain', 'application/json'
    ];

    // ファイルサイズチェック
    if (file.size > maxSize) {
      errors.push('ファイルサイズが10MBを超えています');
    }

    // ファイルタイプチェック
    if (!allowedTypes.includes(file.type)) {
      errors.push('許可されていないファイルタイプです');
    }

    // ファイル名チェック
    if (!/^[a-zA-Z0-9._-]+$/.test(file.name)) {
      errors.push('ファイル名に無効な文字が含まれています');
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  // Content Security Policy設定
  static setupCSP(): void {
    if (!this.config.enableCSP) return;

    const cspDirectives = [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.google-analytics.com",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "img-src 'self' data: https:",
      "font-src 'self' https://fonts.gstatic.com",
      "connect-src 'self' https://api.microsoft.com https://graph.microsoft.com",
      "media-src 'self'",
      "object-src 'none'",
      "base-uri 'self'",
      "form-action 'self'",
      "frame-ancestors 'none'"
    ];

    const csp = cspDirectives.join('; ');
    
    // メタタグでCSPを設定
    const meta = document.createElement('meta');
    meta.httpEquiv = 'Content-Security-Policy';
    meta.content = csp;
    document.head.appendChild(meta);
  }

  // セキュリティヘッダーの設定
  static setupSecurityHeaders(): void {
    // X-Frame-Options (Clickjacking防止)
    if (this.config.enableClickjacking) {
      const frameOptions = document.createElement('meta');
      frameOptions.httpEquiv = 'X-Frame-Options';
      frameOptions.content = 'DENY';
      document.head.appendChild(frameOptions);
    }

    // X-Content-Type-Options
    const contentTypeOptions = document.createElement('meta');
    contentTypeOptions.httpEquiv = 'X-Content-Type-Options';
    contentTypeOptions.content = 'nosniff';
    document.head.appendChild(contentTypeOptions);

    // X-XSS-Protection
    if (this.config.enableXSSProtection) {
      const xssProtection = document.createElement('meta');
      xssProtection.httpEquiv = 'X-XSS-Protection';
      xssProtection.content = '1; mode=block';
      document.head.appendChild(xssProtection);
    }

    // Referrer Policy
    const referrerPolicy = document.createElement('meta');
    referrerPolicy.name = 'referrer';
    referrerPolicy.content = 'strict-origin-when-cross-origin';
    document.head.appendChild(referrerPolicy);
  }

  // セキュアCookieの設定
  static setSecureCookie(name: string, value: string, days: number = 7): void {
    const expires = new Date();
    expires.setTime(expires.getTime() + (days * 24 * 60 * 60 * 1000));
    
    const cookieOptions = [
      `${name}=${value}`,
      `expires=${expires.toUTCString()}`,
      'path=/',
      'SameSite=Strict'
    ];

    if (this.config.enableSecureCookies && location.protocol === 'https:') {
      cookieOptions.push('Secure');
    }

    document.cookie = cookieOptions.join('; ');
  }

  // セキュアストレージ
  static setSecureStorage(key: string, value: string, encrypt: boolean = true): void {
    const storage = localStorage;
    
    if (encrypt) {
      // 簡易的な暗号化（本番環境ではより強力な暗号化を使用）
      const encrypted = btoa(JSON.stringify({
        data: value,
        timestamp: Date.now(),
        checksum: this.generateChecksum(value)
      }));
      storage.setItem(key, encrypted);
    } else {
      storage.setItem(key, value);
    }
  }

  static getSecureStorage(key: string, decrypt: boolean = true): string | null {
    const storage = localStorage;
    const stored = storage.getItem(key);
    
    if (!stored) return null;
    
    if (decrypt) {
      try {
        const decrypted = JSON.parse(atob(stored));
        
        // チェックサムの検証
        if (this.generateChecksum(decrypted.data) !== decrypted.checksum) {
          console.warn('Storage data integrity check failed');
          return null;
        }
        
        return decrypted.data;
      } catch {
        return null;
      }
    }
    
    return stored;
  }

  // チェックサム生成
  private static generateChecksum(data: string): string {
    let hash = 0;
    for (let i = 0; i < data.length; i++) {
      const char = data.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // 32bit整数に変換
    }
    return hash.toString(16);
  }

  // 不正アクセス検出
  static detectSuspiciousActivity(): void {
    let suspiciousActivityCount = 0;
    
    // 異常な頻度でのAPIコール検出
    const apiCallTracker = new Map<string, number[]>();
    
    const originalFetch = window.fetch;
    window.fetch = function(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
      const url = typeof input === 'string' ? input : input.toString();
      const now = Date.now();
      
      if (!apiCallTracker.has(url)) {
        apiCallTracker.set(url, []);
      }
      
      const calls = apiCallTracker.get(url)!;
      calls.push(now);
      
      // 直近1分間のコール数をチェック
      const recentCalls = calls.filter(timestamp => now - timestamp < 60000);
      apiCallTracker.set(url, recentCalls);
      
      if (recentCalls.length > 100) { // 1分間に100回以上
        suspiciousActivityCount++;
        console.warn(`Suspicious API activity detected: ${url}`);
        
        if (suspiciousActivityCount > 5) {
          // セキュリティ機能を強化
          SecurityUtils.enableEmergencyMode();
        }
      }
      
      return originalFetch.call(this, input, init);
    };
  }

  // 緊急モードの有効化
  static enableEmergencyMode(): void {
    console.warn('Emergency security mode enabled');
    
    // より厳しいセキュリティ設定を適用
    this.config.sessionTimeout = 5 * 60 * 1000; // 5分に短縮
    this.config.maxLoginAttempts = 3; // 3回に制限
    
    // 追加のセキュリティヘッダー
    const emergencyCSP = document.createElement('meta');
    emergencyCSP.httpEquiv = 'Content-Security-Policy';
    emergencyCSP.content = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; object-src 'none';";
    document.head.appendChild(emergencyCSP);
  }

  // セキュリティ監査ログ
  static auditLog(action: string, details: any): void {
    const logEntry = {
      timestamp: new Date().toISOString(),
      action,
      details,
      userAgent: navigator.userAgent,
      url: window.location.href,
      sessionId: this.getSessionId()
    };
    
    // セキュリティログを送信
    fetch('/api/security/audit', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(logEntry)
    }).catch(error => {
      console.error('Failed to send security audit log:', error);
    });
  }

  private static getSessionId(): string {
    return sessionStorage.getItem('sessionId') || 'anonymous';
  }
}

// 入力値検証ユーティリティ
export class InputValidator {
  // メールアドレスの検証
  static validateEmail(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  // 電話番号の検証
  static validatePhone(phone: string): boolean {
    const phoneRegex = /^[\+]?[1-9][\d]{0,15}$/;
    return phoneRegex.test(phone.replace(/[\s\-\(\)]/g, ''));
  }

  // 日付の検証
  static validateDate(date: string): boolean {
    const dateObj = new Date(date);
    return !isNaN(dateObj.getTime());
  }

  // 数値の検証
  static validateNumber(value: string, min?: number, max?: number): boolean {
    const num = parseFloat(value);
    if (isNaN(num)) return false;
    
    if (min !== undefined && num < min) return false;
    if (max !== undefined && num > max) return false;
    
    return true;
  }

  // 文字列長の検証
  static validateLength(value: string, min: number, max: number): boolean {
    return value.length >= min && value.length <= max;
  }

  // 正規表現による検証
  static validatePattern(value: string, pattern: RegExp): boolean {
    return pattern.test(value);
  }

  // 複数の検証をまとめて実行
  static validateMultiple(
    value: string,
    validators: Array<(value: string) => boolean>
  ): boolean {
    return validators.every(validator => validator(value));
  }
}

// アクセス制御ユーティリティ
export class AccessControl {
  private static permissions: Map<string, string[]> = new Map();
  private static currentUserRoles: string[] = [];

  // 権限の設定
  static setPermissions(role: string, permissions: string[]): void {
    this.permissions.set(role, permissions);
  }

  // 現在のユーザーロールの設定
  static setCurrentUserRoles(roles: string[]): void {
    this.currentUserRoles = roles;
  }

  // 権限チェック
  static hasPermission(permission: string): boolean {
    return this.currentUserRoles.some(role => {
      const rolePermissions = this.permissions.get(role);
      return rolePermissions?.includes(permission) || false;
    });
  }

  // 複数権限チェック
  static hasAllPermissions(permissions: string[]): boolean {
    return permissions.every(permission => this.hasPermission(permission));
  }

  // いずれかの権限チェック
  static hasAnyPermission(permissions: string[]): boolean {
    return permissions.some(permission => this.hasPermission(permission));
  }

  // 管理者権限チェック
  static isAdmin(): boolean {
    return this.currentUserRoles.includes('admin') || this.currentUserRoles.includes('super_admin');
  }

  // リソースアクセス制御
  static canAccessResource(resource: string, action: string): boolean {
    const permission = `${resource}:${action}`;
    return this.hasPermission(permission);
  }
}

// セキュリティ初期化
export const initializeSecurity = (): void => {
  // セキュリティ設定の適用
  SecurityUtils.setupCSP();
  SecurityUtils.setupSecurityHeaders();
  SecurityUtils.detectSuspiciousActivity();
  
  // セキュリティ監査ログ
  SecurityUtils.auditLog('security_initialized', {
    config: defaultSecurityConfig,
    userAgent: navigator.userAgent,
    timestamp: Date.now()
  });
  
  console.log('[Security] Security measures initialized');
};

export default {
  SecurityUtils,
  InputValidator,
  AccessControl,
  defaultSecurityConfig,
  initializeSecurity,
};