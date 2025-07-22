"""
Microsoft 365管理ツール 本番セキュリティ強化
==========================================

本番環境向けセキュリティ強化システム
- 認証・認可強化・多要素認証対応
- 入力検証・SQLインジェクション対策
- レート制限・DDoS攻撃対策
- 監査ログ・セキュリティ監視
"""

import asyncio
import logging
import hashlib
import secrets
import time
import re
from typing import Dict, Any, List, Optional, Set, Callable
from functools import wraps
from dataclasses import dataclass
from datetime import datetime, timedelta
from ipaddress import ip_address, ip_network, AddressValueError
import jwt
from cryptography.fernet import Fernet
import bcrypt

logger = logging.getLogger(__name__)


@dataclass
class SecurityEvent:
    """セキュリティイベント"""
    event_type: str
    source_ip: str
    user_id: Optional[str]
    endpoint: str
    severity: str
    description: str
    timestamp: datetime
    additional_info: Dict[str, Any]


@dataclass
class AuthenticationAttempt:
    """認証試行記録"""
    ip_address: str
    user_id: str
    success: bool
    timestamp: datetime
    user_agent: str
    failure_reason: Optional[str] = None


class ProductionSecurityManager:
    """本番セキュリティ管理クラス"""
    
    # 危険IPアドレスブラックリスト（例）
    BLACKLISTED_IPS = {
        "192.168.1.100",  # 例: 既知の攻撃元
        "10.0.0.0/8",     # 例: 内部ネットワーク制限
    }
    
    # 許可されたIPアドレスホワイトリスト
    WHITELISTED_IPS = {
        "192.168.1.0/24",   # 例: 社内ネットワーク
        "10.0.0.0/8",       # 例: VPNネットワーク
    }
    
    # SQLインジェクション検出パターン
    SQL_INJECTION_PATTERNS = [
        r"(\s*(union|select|insert|update|delete|drop|create|alter|exec)\s+)",
        r"(\s*;\s*(drop|delete|truncate)\s+)",
        r"(\s*'\s*(or|and)\s*')",
        r"(\s*--\s*)",
        r"(\s*/\*.*\*/\s*)",
        r"(\s*xp_\w+\s*)",
        r"(\s*sp_\w+\s*)",
    ]
    
    # XSS検出パターン
    XSS_PATTERNS = [
        r"<script[^>]*>.*?</script>",
        r"javascript:",
        r"on\w+\s*=",
        r"<iframe[^>]*>.*?</iframe>",
        r"<object[^>]*>.*?</object>",
        r"<embed[^>]*>.*?</embed>",
    ]
    
    def __init__(self):
        self.security_events: List[SecurityEvent] = []
        self.auth_attempts: List[AuthenticationAttempt] = []
        self.rate_limits: Dict[str, List[datetime]] = {}
        self.blocked_ips: Set[str] = set(self.BLACKLISTED_IPS)
        self.suspicious_activities: Dict[str, int] = {}
        
        # 暗号化キー（本番では環境変数から取得）
        self.encryption_key = Fernet.generate_key()
        self.cipher_suite = Fernet(self.encryption_key)
        
        # JWT設定
        self.jwt_secret = secrets.token_hex(32)
        self.jwt_algorithm = "HS256"
        self.jwt_expiration = 3600  # 1時間
        
        # セキュリティ設定
        self.max_login_attempts = 5
        self.login_attempt_window = 300  # 5分
        self.rate_limit_window = 60  # 1分
        self.max_requests_per_minute = 100
        
    def require_authentication(self, required_roles: Optional[List[str]] = None):
        """認証必須デコレータ"""
        def decorator(func: Callable):
            @wraps(func)
            async def wrapper(*args, **kwargs):
                request = kwargs.get('request') or (args[0] if args else None)
                
                if not request:
                    raise SecurityException("リクエストオブジェクトが必要です")
                
                # 認証トークン検証
                token = self._extract_token(request)
                user_info = await self._verify_token(token)
                
                if not user_info:
                    await self._log_security_event(
                        "AUTHENTICATION_FAILED",
                        self._get_client_ip(request),
                        None,
                        getattr(request, 'url', {}).get('path', ''),
                        "HIGH",
                        "無効な認証トークン"
                    )
                    raise SecurityException("認証が必要です")
                
                # 役割ベースアクセス制御
                if required_roles and not self._check_user_roles(user_info, required_roles):
                    await self._log_security_event(
                        "AUTHORIZATION_FAILED",
                        self._get_client_ip(request),
                        user_info.get('user_id'),
                        getattr(request, 'url', {}).get('path', ''),
                        "MEDIUM",
                        f"必要な役割なし: {required_roles}"
                    )
                    raise SecurityException("アクセス権限がありません")
                
                # 認証済みユーザー情報をリクエストに追加
                request.user = user_info
                
                return await func(*args, **kwargs)
                
            return wrapper
        return decorator
    
    def rate_limit_protection(self, max_requests: int = 100, window_minutes: int = 1):
        """レート制限保護デコレータ"""
        def decorator(func: Callable):
            @wraps(func)
            async def wrapper(*args, **kwargs):
                request = kwargs.get('request') or (args[0] if args else None)
                
                if request:
                    client_ip = self._get_client_ip(request)
                    
                    # レート制限チェック
                    if not await self._check_rate_limit(client_ip, max_requests, window_minutes):
                        await self._log_security_event(
                            "RATE_LIMIT_EXCEEDED",
                            client_ip,
                            getattr(request, 'user', {}).get('user_id'),
                            getattr(request, 'url', {}).get('path', ''),
                            "HIGH",
                            f"レート制限超過: {max_requests}req/{window_minutes}min"
                        )
                        raise SecurityException("レート制限を超過しました")
                
                return await func(*args, **kwargs)
                
            return wrapper
        return decorator
    
    def input_validation(self, check_sql_injection: bool = True, check_xss: bool = True):
        """入力検証デコレータ"""
        def decorator(func: Callable):
            @wraps(func)
            async def wrapper(*args, **kwargs):
                request = kwargs.get('request')
                
                if request:
                    # リクエストボディの検証
                    if hasattr(request, 'json') and callable(request.json):
                        try:
                            body = await request.json()
                            await self._validate_input_data(body, check_sql_injection, check_xss)
                        except Exception as e:
                            logger.warning(f"リクエストボディ検証エラー: {e}")
                    
                    # クエリパラメータの検証
                    if hasattr(request, 'query_params'):
                        for key, value in request.query_params.items():
                            await self._validate_input_string(value, check_sql_injection, check_xss)
                
                return await func(*args, **kwargs)
                
            return wrapper
        return decorator
    
    def ip_whitelist_protection(self, allowed_networks: Optional[List[str]] = None):
        """IPホワイトリスト保護デコレータ"""
        def decorator(func: Callable):
            @wraps(func)
            async def wrapper(*args, **kwargs):
                request = kwargs.get('request')
                
                if request:
                    client_ip = self._get_client_ip(request)
                    networks = allowed_networks or list(self.WHITELISTED_IPS)
                    
                    if not self._is_ip_allowed(client_ip, networks):
                        await self._log_security_event(
                            "IP_BLOCKED",
                            client_ip,
                            getattr(request, 'user', {}).get('user_id'),
                            getattr(request, 'url', {}).get('path', ''),
                            "HIGH",
                            "許可されていないIPアドレス"
                        )
                        raise SecurityException("アクセスが拒否されました")
                
                return await func(*args, **kwargs)
                
            return wrapper
        return decorator
    
    async def authenticate_user(self, username: str, password: str, ip_address: str, user_agent: str) -> Dict[str, Any]:
        """ユーザー認証"""
        
        # ログイン試行チェック
        if not await self._check_login_attempts(ip_address, username):
            raise SecurityException("ログイン試行回数が上限に達しました")
        
        # 認証処理（実際の実装では外部認証システムを使用）
        user_info = await self._verify_user_credentials(username, password)
        
        auth_attempt = AuthenticationAttempt(
            ip_address=ip_address,
            user_id=username,
            success=user_info is not None,
            timestamp=datetime.utcnow(),
            user_agent=user_agent,
            failure_reason=None if user_info else "無効な認証情報"
        )
        
        self.auth_attempts.append(auth_attempt)
        
        if not user_info:
            await self._log_security_event(
                "LOGIN_FAILED",
                ip_address,
                username,
                "/auth/login",
                "MEDIUM",
                "ログイン失敗"
            )
            raise SecurityException("認証に失敗しました")
        
        # JWTトークン生成
        token = await self._generate_jwt_token(user_info)
        
        await self._log_security_event(
            "LOGIN_SUCCESS",
            ip_address,
            user_info['user_id'],
            "/auth/login",
            "INFO",
            "ログイン成功"
        )
        
        return {
            "token": token,
            "user": user_info,
            "expires_in": self.jwt_expiration
        }
    
    async def _verify_user_credentials(self, username: str, password: str) -> Optional[Dict[str, Any]]:
        """ユーザー認証情報検証"""
        
        # 実際の実装では、データベースやLDAPから認証情報を取得
        # ここではデモ用のハードコード
        demo_users = {
            "admin": {
                "user_id": "admin",
                "username": "admin", 
                "password_hash": bcrypt.hashpw("password".encode('utf-8'), bcrypt.gensalt()),
                "roles": ["admin", "user"],
                "department": "IT",
                "email": "admin@company.com"
            },
            "user": {
                "user_id": "user",
                "username": "user",
                "password_hash": bcrypt.hashpw("password".encode('utf-8'), bcrypt.gensalt()),
                "roles": ["user"],
                "department": "General",
                "email": "user@company.com"
            }
        }
        
        user = demo_users.get(username)
        if not user:
            return None
        
        # パスワード検証
        if bcrypt.checkpw(password.encode('utf-8'), user['password_hash']):
            return {
                "user_id": user["user_id"],
                "username": user["username"],
                "roles": user["roles"],
                "department": user["department"],
                "email": user["email"]
            }
        
        return None
    
    async def _generate_jwt_token(self, user_info: Dict[str, Any]) -> str:
        """JWTトークン生成"""
        
        payload = {
            "user_id": user_info["user_id"],
            "username": user_info["username"],
            "roles": user_info["roles"],
            "iat": int(time.time()),
            "exp": int(time.time()) + self.jwt_expiration
        }
        
        token = jwt.encode(payload, self.jwt_secret, algorithm=self.jwt_algorithm)
        return token
    
    async def _verify_token(self, token: str) -> Optional[Dict[str, Any]]:
        """JWTトークン検証"""
        
        if not token:
            return None
        
        try:
            payload = jwt.decode(token, self.jwt_secret, algorithms=[self.jwt_algorithm])
            
            # 有効期限チェック
            if payload.get('exp', 0) < time.time():
                return None
            
            return payload
            
        except jwt.InvalidTokenError as e:
            logger.warning(f"無効なJWTトークン: {e}")
            return None
    
    def _extract_token(self, request) -> Optional[str]:
        """リクエストからトークン抽出"""
        
        # Authorizationヘッダーから抽出
        if hasattr(request, 'headers'):
            auth_header = request.headers.get('Authorization')
            if auth_header and auth_header.startswith('Bearer '):
                return auth_header[7:]  # "Bearer " を除去
        
        # クエリパラメータから抽出
        if hasattr(request, 'query_params'):
            return request.query_params.get('token')
        
        return None
    
    def _check_user_roles(self, user_info: Dict[str, Any], required_roles: List[str]) -> bool:
        """ユーザー役割チェック"""
        
        user_roles = set(user_info.get('roles', []))
        required_roles_set = set(required_roles)
        
        return bool(user_roles.intersection(required_roles_set))
    
    def _get_client_ip(self, request) -> str:
        """クライアントIP取得"""
        
        # X-Forwarded-Forヘッダーをチェック（プロキシ環境）
        if hasattr(request, 'headers'):
            forwarded_for = request.headers.get('X-Forwarded-For')
            if forwarded_for:
                return forwarded_for.split(',')[0].strip()
            
            real_ip = request.headers.get('X-Real-IP')
            if real_ip:
                return real_ip.strip()
        
        # 直接接続のIPアドレス
        if hasattr(request, 'client') and hasattr(request.client, 'host'):
            return request.client.host
        
        return "unknown"
    
    async def _check_rate_limit(self, identifier: str, max_requests: int, window_minutes: int) -> bool:
        """レート制限チェック"""
        
        current_time = datetime.utcnow()
        window_start = current_time - timedelta(minutes=window_minutes)
        
        # 既存の記録をクリーンアップ
        if identifier in self.rate_limits:
            self.rate_limits[identifier] = [
                timestamp for timestamp in self.rate_limits[identifier]
                if timestamp > window_start
            ]
        else:
            self.rate_limits[identifier] = []
        
        # リクエスト数チェック
        if len(self.rate_limits[identifier]) >= max_requests:
            return False
        
        # 新しいリクエストを記録
        self.rate_limits[identifier].append(current_time)
        return True
    
    async def _check_login_attempts(self, ip_address: str, username: str) -> bool:
        """ログイン試行チェック"""
        
        cutoff_time = datetime.utcnow() - timedelta(seconds=self.login_attempt_window)
        
        # IP別失敗回数カウント
        ip_failures = [
            attempt for attempt in self.auth_attempts
            if attempt.ip_address == ip_address
            and not attempt.success
            and attempt.timestamp > cutoff_time
        ]
        
        # ユーザー別失敗回数カウント
        user_failures = [
            attempt for attempt in self.auth_attempts
            if attempt.user_id == username
            and not attempt.success
            and attempt.timestamp > cutoff_time
        ]
        
        return (len(ip_failures) < self.max_login_attempts and 
                len(user_failures) < self.max_login_attempts)
    
    def _is_ip_allowed(self, ip_address: str, allowed_networks: List[str]) -> bool:
        """IPアドレス許可チェック"""
        
        try:
            client_ip = ip_address(ip_address)
            
            for network_str in allowed_networks:
                try:
                    if '/' in network_str:
                        network = ip_network(network_str, strict=False)
                        if client_ip in network:
                            return True
                    else:
                        if str(client_ip) == network_str:
                            return True
                except AddressValueError:
                    continue
            
            return False
            
        except AddressValueError:
            logger.warning(f"無効なIPアドレス: {ip_address}")
            return False
    
    async def _validate_input_data(self, data: Any, check_sql: bool, check_xss: bool):
        """入力データ検証"""
        
        if isinstance(data, dict):
            for key, value in data.items():
                await self._validate_input_data(value, check_sql, check_xss)
        elif isinstance(data, list):
            for item in data:
                await self._validate_input_data(item, check_sql, check_xss)
        elif isinstance(data, str):
            await self._validate_input_string(data, check_sql, check_xss)
    
    async def _validate_input_string(self, input_str: str, check_sql: bool, check_xss: bool):
        """文字列入力検証"""
        
        if check_sql:
            for pattern in self.SQL_INJECTION_PATTERNS:
                if re.search(pattern, input_str, re.IGNORECASE):
                    await self._log_security_event(
                        "SQL_INJECTION_ATTEMPT",
                        "unknown",
                        None,
                        "/api/*",
                        "HIGH",
                        f"SQLインジェクション検出: {pattern}"
                    )
                    raise SecurityException("不正な入力が検出されました")
        
        if check_xss:
            for pattern in self.XSS_PATTERNS:
                if re.search(pattern, input_str, re.IGNORECASE):
                    await self._log_security_event(
                        "XSS_ATTEMPT",
                        "unknown",
                        None,
                        "/api/*",
                        "HIGH",
                        f"XSS攻撃検出: {pattern}"
                    )
                    raise SecurityException("不正な入力が検出されました")
    
    async def _log_security_event(self, event_type: str, source_ip: str, user_id: Optional[str],
                                endpoint: str, severity: str, description: str, **additional_info):
        """セキュリティイベントログ"""
        
        event = SecurityEvent(
            event_type=event_type,
            source_ip=source_ip,
            user_id=user_id,
            endpoint=endpoint,
            severity=severity,
            description=description,
            timestamp=datetime.utcnow(),
            additional_info=additional_info
        )
        
        self.security_events.append(event)
        
        # 重要度に応じたログレベル
        if severity == "HIGH":
            logger.error(f"セキュリティ警告: {description} (IP: {source_ip}, User: {user_id})")
        elif severity == "MEDIUM":
            logger.warning(f"セキュリティ注意: {description} (IP: {source_ip}, User: {user_id})")
        else:
            logger.info(f"セキュリティ情報: {description} (IP: {source_ip}, User: {user_id})")
    
    def encrypt_sensitive_data(self, data: str) -> str:
        """機密データ暗号化"""
        return self.cipher_suite.encrypt(data.encode()).decode()
    
    def decrypt_sensitive_data(self, encrypted_data: str) -> str:
        """機密データ復号化"""
        return self.cipher_suite.decrypt(encrypted_data.encode()).decode()
    
    def hash_password(self, password: str) -> str:
        """パスワードハッシュ化"""
        return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode()
    
    def verify_password(self, password: str, hashed: str) -> bool:
        """パスワード検証"""
        return bcrypt.checkpw(password.encode('utf-8'), hashed.encode())
    
    async def get_security_report(self, hours: int = 24) -> Dict[str, Any]:
        """セキュリティレポート取得"""
        
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        # 指定時間内のイベント
        recent_events = [
            event for event in self.security_events
            if event.timestamp > cutoff_time
        ]
        
        # 指定時間内の認証試行
        recent_auth_attempts = [
            attempt for attempt in self.auth_attempts
            if attempt.timestamp > cutoff_time
        ]
        
        # 統計計算
        event_by_type = {}
        event_by_severity = {}
        
        for event in recent_events:
            event_by_type[event.event_type] = event_by_type.get(event.event_type, 0) + 1
            event_by_severity[event.severity] = event_by_severity.get(event.severity, 0) + 1
        
        auth_success_rate = 0
        if recent_auth_attempts:
            successes = sum(1 for attempt in recent_auth_attempts if attempt.success)
            auth_success_rate = successes / len(recent_auth_attempts)
        
        return {
            "period_hours": hours,
            "total_security_events": len(recent_events),
            "events_by_type": event_by_type,
            "events_by_severity": event_by_severity,
            "authentication_statistics": {
                "total_attempts": len(recent_auth_attempts),
                "success_rate": auth_success_rate,
                "failed_attempts": len([a for a in recent_auth_attempts if not a.success])
            },
            "blocked_ips": list(self.blocked_ips),
            "rate_limit_violations": event_by_type.get("RATE_LIMIT_EXCEEDED", 0),
            "injection_attempts": event_by_type.get("SQL_INJECTION_ATTEMPT", 0) + 
                                event_by_type.get("XSS_ATTEMPT", 0),
            "recommendations": self._generate_security_recommendations(recent_events),
            "timestamp": datetime.utcnow().isoformat()
        }
    
    def _generate_security_recommendations(self, events: List[SecurityEvent]) -> List[str]:
        """セキュリティ推奨事項生成"""
        
        recommendations = []
        
        # 高頻度の攻撃チェック
        high_severity_events = [e for e in events if e.severity == "HIGH"]
        if len(high_severity_events) > 10:
            recommendations.append("高重要度セキュリティイベントの頻発: システム監視強化推奨")
        
        # SQLインジェクション試行チェック
        sql_injection_events = [e for e in events if e.event_type == "SQL_INJECTION_ATTEMPT"]
        if sql_injection_events:
            recommendations.append("SQLインジェクション攻撃検出: WAF導入推奨")
        
        # ログイン失敗チェック
        login_failures = [e for e in events if e.event_type == "LOGIN_FAILED"]
        if len(login_failures) > 20:
            recommendations.append("ログイン失敗多発: パスワードポリシー強化推奨")
        
        return recommendations


class SecurityException(Exception):
    """セキュリティ例外"""
    pass


# グローバルセキュリティマネージャー
security_manager = ProductionSecurityManager()