"""
Microsoft 365 Authentication Module - Python MSAL Implementation
================================================================

PowerShell認証システムからの完全移行対応
- 証明書ベース認証（ファイル/Thumbprint対応）
- クライアントシークレット認証
- Microsoft Graph API統合
- Exchange Online認証統合
- リトライロジック・エラーハンドリング
- 並行実行対応（スレッドセーフ）

移行期間中のPowerShell互換性維持
"""

import logging
import json
import os
import threading
import time
from pathlib import Path
from typing import Dict, List, Optional, Union, Any, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta
from cryptography.x509 import load_pem_x509_certificate, load_der_x509_certificate
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import pkcs12

import msal
from msal import ConfidentialClientApplication, PublicClientApplication
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Microsoft Graph SDK for Python (互換性確保)
try:
    import msgraph
    from msgraph import GraphServiceClient
    from azure.identity import CertificateCredential, ClientSecretCredential
    MSGRAPH_AVAILABLE = True
except ImportError:
    MSGRAPH_AVAILABLE = False
    logging.warning("Microsoft Graph SDK not available. Using REST API fallback.")

# Exchange Online PowerShell互換モジュール
try:
    import exchangelib
    EXCHANGELIB_AVAILABLE = True
except ImportError:
    EXCHANGELIB_AVAILABLE = False
    logging.warning("Exchange Online library not available. Using Graph API fallback.")


@dataclass
class AuthenticationConfig:
    """認証設定データクラス（PowerShell appsettings.json互換）"""
    tenant_id: str
    client_id: str
    client_secret: Optional[str] = None
    certificate_path: Optional[str] = None
    certificate_password: Optional[str] = None
    certificate_thumbprint: Optional[str] = None
    authority: Optional[str] = None
    scopes: Optional[List[str]] = None
    
    def __post_init__(self):
        if not self.authority:
            self.authority = f"https://login.microsoftonline.com/{self.tenant_id}"
        if not self.scopes:
            self.scopes = [
                "https://graph.microsoft.com/.default",
                "https://outlook.office365.com/.default"
            ]


@dataclass
class AuthenticationResult:
    """認証結果データクラス"""
    success: bool
    access_token: Optional[str] = None
    expires_at: Optional[datetime] = None
    services: Optional[List[str]] = None
    error_message: Optional[str] = None
    token_cache: Optional[Dict[str, Any]] = None


class MSALAuthenticationManager:
    """
    Microsoft 365統合認証マネージャー
    PowerShell Authentication.psm1からの完全移行
    """
    
    def __init__(self, config: AuthenticationConfig):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self._lock = threading.RLock()
        self._token_cache = {}
        self._token_expiry = {}
        self._auth_clients = {}
        self._last_auth_time = None
        
        # リトライ設定（PowerShell互換）
        self.retry_strategy = Retry(
            total=5,
            status_forcelist=[429, 500, 502, 503, 504],
            method_whitelist=["HEAD", "GET", "POST"],
            backoff_factor=2
        )
        
        # HTTP セッション設定
        self.session = requests.Session()
        adapter = HTTPAdapter(max_retries=self.retry_strategy)
        self.session.mount("https://", adapter)
        
        self._initialize_auth_clients()
    
    def _initialize_auth_clients(self):
        """認証クライアントの初期化"""
        try:
            # 証明書ベース認証クライアント
            if self.config.certificate_path or self.config.certificate_thumbprint:
                self._setup_certificate_auth()
            
            # クライアントシークレット認証クライアント
            if self.config.client_secret:
                self._setup_client_secret_auth()
                
            self.logger.info("認証クライアント初期化完了")
            
        except Exception as e:
            self.logger.error(f"認証クライアント初期化エラー: {str(e)}")
            raise
    
    def _setup_certificate_auth(self):
        """証明書ベース認証セットアップ"""
        try:
            certificate_data = None
            private_key = None
            
            if self.config.certificate_path:
                # ファイルベース証明書（PowerShell互換）
                cert_path = Path(self.config.certificate_path)
                if not cert_path.is_absolute():
                    # 相対パス対応
                    cert_path = Path(__file__).parent.parent.parent / self.config.certificate_path
                
                if not cert_path.exists():
                    raise FileNotFoundError(f"証明書ファイルが見つかりません: {cert_path}")
                
                # 複数パスワード候補で試行（PowerShell互換ロジック）
                password_candidates = []
                if self.config.certificate_password:
                    password_candidates.append(self.config.certificate_password)
                password_candidates.extend([None, ""])
                
                cert_loaded = False
                last_error = None
                
                for password in password_candidates:
                    try:
                        with open(cert_path, 'rb') as cert_file:
                            cert_data = cert_file.read()
                        
                        if password:
                            # PKCS#12形式（.pfx/.p12）
                            try:
                                private_key, certificate, additional_certs = pkcs12.load_key_and_certificates(
                                    cert_data, password.encode() if isinstance(password, str) else password
                                )
                                certificate_data = certificate
                                cert_loaded = True
                                self.logger.info("PKCS#12証明書読み込み成功（パスワード保護）")
                                break
                            except Exception:
                                continue
                        else:
                            # PEM/DER形式（パスワードなし）
                            try:
                                certificate_data = load_pem_x509_certificate(cert_data)
                                cert_loaded = True
                                self.logger.info("PEM証明書読み込み成功")
                                break
                            except Exception:
                                try:
                                    certificate_data = load_der_x509_certificate(cert_data)
                                    cert_loaded = True
                                    self.logger.info("DER証明書読み込み成功")
                                    break
                                except Exception as e:
                                    last_error = e
                                    continue
                                    
                    except Exception as e:
                        last_error = e
                        continue
                
                if not cert_loaded:
                    raise Exception(f"証明書の読み込みに失敗: {last_error}")
            
            # MSAL証明書認証クライアント作成
            if certificate_data and private_key:
                # 秘密鍵付き証明書
                self._auth_clients['certificate'] = ConfidentialClientApplication(
                    client_id=self.config.client_id,
                    client_credential={
                        "private_key": private_key.private_bytes(
                            encoding=serialization.Encoding.PEM,
                            format=serialization.PrivateFormat.PKCS8,
                            encryption_algorithm=serialization.NoEncryption()
                        ),
                        "thumbprint": certificate_data.fingerprint(hashes.SHA1()).hex(),
                        "public_certificate": certificate_data.public_bytes(serialization.Encoding.PEM)
                    },
                    authority=self.config.authority
                )
            elif certificate_data:
                # 証明書のみ（Thumbprint認証）
                self._auth_clients['certificate'] = ConfidentialClientApplication(
                    client_id=self.config.client_id,
                    client_credential={
                        "thumbprint": certificate_data.fingerprint(hashes.SHA1()).hex(),
                        "public_certificate": certificate_data.public_bytes(serialization.Encoding.PEM)
                    },
                    authority=self.config.authority
                )
            
            self.logger.info("証明書ベース認証クライアント設定完了")
            
        except Exception as e:
            self.logger.error(f"証明書ベース認証設定エラー: {str(e)}")
            raise
    
    def _setup_client_secret_auth(self):
        """クライアントシークレット認証セットアップ"""
        try:
            # 環境変数展開（PowerShell互換）
            client_secret = self._expand_environment_variables(self.config.client_secret)
            
            self._auth_clients['client_secret'] = ConfidentialClientApplication(
                client_id=self.config.client_id,
                client_credential=client_secret,
                authority=self.config.authority
            )
            
            self.logger.info("クライアントシークレット認証クライアント設定完了")
            
        except Exception as e:
            self.logger.error(f"クライアントシークレット認証設定エラー: {str(e)}")
            raise
    
    def _expand_environment_variables(self, value: str) -> str:
        """環境変数展開（PowerShell互換）"""
        if not value:
            return value
            
        import re
        pattern = r'\$\{(.+?)\}'
        
        def replace_var(match):
            var_name = match.group(1)
            env_value = os.environ.get(var_name)
            if env_value:
                self.logger.debug(f"環境変数展開: {var_name} = {env_value[:10]}...")
                return env_value
            else:
                self.logger.warning(f"環境変数が見つかりません: {var_name}")
                return match.group(0)
        
        return re.sub(pattern, replace_var, value)
    
    def authenticate(self, services: List[str] = None) -> AuthenticationResult:
        """
        Microsoft 365認証実行
        PowerShell Connect-ToMicrosoft365互換
        """
        if services is None:
            services = ["MicrosoftGraph", "ExchangeOnline"]
        
        with self._lock:
            try:
                self.logger.info(f"Microsoft 365認証開始: {services}")
                
                result = AuthenticationResult(success=False, services=[])
                
                for service in services:
                    service_result = self._authenticate_service(service)
                    if service_result.success:
                        result.services.append(service)
                        if not result.access_token:
                            result.access_token = service_result.access_token
                            result.expires_at = service_result.expires_at
                
                result.success = len(result.services) > 0
                
                if result.success:
                    self._last_auth_time = datetime.now()
                    self.logger.info(f"認証成功: {result.services}")
                else:
                    self.logger.error("すべてのサービス認証に失敗")
                
                return result
                
            except Exception as e:
                self.logger.error(f"認証エラー: {str(e)}")
                return AuthenticationResult(success=False, error_message=str(e))
    
    def _authenticate_service(self, service: str) -> AuthenticationResult:
        """個別サービス認証"""
        try:
            if service == "MicrosoftGraph":
                return self._authenticate_graph()
            elif service == "ExchangeOnline":
                return self._authenticate_exchange()
            else:
                raise ValueError(f"サポートされていないサービス: {service}")
                
        except Exception as e:
            self.logger.error(f"{service} 認証エラー: {str(e)}")
            return AuthenticationResult(success=False, error_message=str(e))
    
    def _authenticate_graph(self) -> AuthenticationResult:
        """Microsoft Graph認証"""
        try:
            # キャッシュ確認
            cached_token = self._get_cached_token("MicrosoftGraph")
            if cached_token:
                return cached_token
            
            # 認証実行（優先順位: クライアントシークレット → 証明書）
            auth_result = None
            
            # 1. クライアントシークレット認証
            if 'client_secret' in self._auth_clients:
                auth_result = self._try_authentication_with_retry(
                    self._auth_clients['client_secret'],
                    self.config.scopes,
                    "クライアントシークレット"
                )
            
            # 2. 証明書ベース認証（フォールバック）
            if not auth_result and 'certificate' in self._auth_clients:
                auth_result = self._try_authentication_with_retry(
                    self._auth_clients['certificate'],
                    self.config.scopes,
                    "証明書ベース"
                )
            
            if not auth_result:
                raise Exception("Microsoft Graph認証に失敗しました")
            
            # 結果作成
            result = AuthenticationResult(
                success=True,
                access_token=auth_result.get('access_token'),
                expires_at=datetime.now() + timedelta(seconds=auth_result.get('expires_in', 3600))
            )
            
            # キャッシュ保存
            self._set_cached_token("MicrosoftGraph", result)
            
            # 接続テスト
            if self._test_graph_connection(result.access_token):
                self.logger.info("Microsoft Graph 認証・接続テスト成功")
                return result
            else:
                self.logger.warning("Microsoft Graph 接続テストに失敗")
                return AuthenticationResult(success=False, error_message="接続テスト失敗")
            
        except Exception as e:
            self.logger.error(f"Microsoft Graph認証エラー: {str(e)}")
            return AuthenticationResult(success=False, error_message=str(e))
    
    def _authenticate_exchange(self) -> AuthenticationResult:
        """Exchange Online認証"""
        try:
            # Graph認証を流用（Exchange OnlineはGraph APIでアクセス可能）
            graph_result = self._authenticate_graph()
            if not graph_result.success:
                return graph_result
            
            # Exchange Online特有の権限確認
            if self._test_exchange_permissions(graph_result.access_token):
                self.logger.info("Exchange Online 認証・権限確認成功")
                return AuthenticationResult(
                    success=True,
                    access_token=graph_result.access_token,
                    expires_at=graph_result.expires_at
                )
            else:
                self.logger.warning("Exchange Online権限が不足")
                return AuthenticationResult(success=False, error_message="Exchange Online権限不足")
            
        except Exception as e:
            self.logger.error(f"Exchange Online認証エラー: {str(e)}")
            return AuthenticationResult(success=False, error_message=str(e))
    
    def _try_authentication_with_retry(self, client: ConfidentialClientApplication, scopes: List[str], method_name: str) -> Optional[Dict[str, Any]]:
        """リトライ付き認証実行（PowerShell Invoke-GraphAPIWithRetry互換）"""
        max_retries = 5
        base_delay = 2
        
        for attempt in range(1, max_retries + 1):
            try:
                self.logger.info(f"{method_name} 認証試行 {attempt}/{max_retries}")
                
                result = client.acquire_token_for_client(scopes=scopes)
                
                if 'access_token' in result:
                    self.logger.info(f"{method_name} 認証成功")
                    return result
                elif 'error' in result:
                    error_msg = result.get('error_description', result.get('error', 'Unknown error'))
                    self.logger.warning(f"{method_name} 認証エラー (試行 {attempt}): {error_msg}")
                    
                    # エラー分類とリトライ判定
                    if self._should_retry_auth_error(result.get('error', '')):
                        if attempt < max_retries:
                            delay = self._calculate_adaptive_delay(attempt, base_delay, error_msg)
                            self.logger.info(f"{delay}秒後にリトライします...")
                            time.sleep(delay)
                            continue
                    else:
                        # リトライ不可能なエラー
                        raise Exception(f"{method_name} 認証失敗: {error_msg}")
                
            except Exception as e:
                self.logger.error(f"{method_name} 認証エラー (試行 {attempt}): {str(e)}")
                if attempt >= max_retries:
                    raise
                
                delay = base_delay * attempt
                self.logger.info(f"{delay}秒後にリトライします...")
                time.sleep(delay)
        
        return None
    
    def _should_retry_auth_error(self, error_code: str) -> bool:
        """認証エラーのリトライ判定（PowerShell Get-ErrorCategory互換）"""
        retryable_errors = [
            'temporarily_unavailable',
            'service_unavailable',
            'request_timeout',
            'server_error',
            'throttled'
        ]
        return any(err in error_code.lower() for err in retryable_errors)
    
    def _calculate_adaptive_delay(self, attempt: int, base_delay: int, error_message: str) -> int:
        """適応的遅延計算（PowerShell Get-AdaptiveDelay互換）"""
        import re
        import random
        
        # Retry-After ヘッダー抽出
        retry_after_match = re.search(r'retry.*after.*(\d+)', error_message.lower())
        if retry_after_match:
            retry_after = int(retry_after_match.group(1))
            return min(retry_after + 1, 300)  # 最大5分
        
        # 指数バックオフ + ジッター
        base_delay = base_delay * (2 ** attempt)
        jitter = random.uniform(0, base_delay * 0.1)
        return min(int(base_delay + jitter), 120)  # 最大2分
    
    def _test_graph_connection(self, access_token: str) -> bool:
        """Microsoft Graph接続テスト（PowerShell Test-GraphConnection互換）"""
        try:
            headers = {'Authorization': f'Bearer {access_token}'}
            
            # 基本API呼び出しテスト
            response = self.session.get(
                'https://graph.microsoft.com/v1.0/users?$top=1&$select=id',
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                self.logger.info("Microsoft Graph API接続テスト成功")
                return True
            else:
                self.logger.warning(f"Microsoft Graph API接続テスト失敗: {response.status_code}")
                return False
                
        except Exception as e:
            self.logger.error(f"Microsoft Graph接続テストエラー: {str(e)}")
            return False
    
    def _test_exchange_permissions(self, access_token: str) -> bool:
        """Exchange Online権限テスト"""
        try:
            headers = {'Authorization': f'Bearer {access_token}'}
            
            # Exchange Online固有のAPI確認
            response = self.session.get(
                'https://graph.microsoft.com/v1.0/me/mailboxSettings',
                headers=headers,
                timeout=30
            )
            
            return response.status_code in [200, 404]  # 404はメールボックスがない場合で正常
            
        except Exception as e:
            self.logger.error(f"Exchange Online権限テストエラー: {str(e)}")
            return False
    
    def _get_cached_token(self, service: str) -> Optional[AuthenticationResult]:
        """キャッシュトークン取得（PowerShell Get-CachedToken互換）"""
        if service in self._token_cache:
            expiry = self._token_expiry.get(service)
            if expiry and datetime.now() < expiry:
                self.logger.info(f"キャッシュトークン使用: {service}")
                return self._token_cache[service]
            else:
                self.logger.info(f"トークン期限切れ: {service}")
                del self._token_cache[service]
                if service in self._token_expiry:
                    del self._token_expiry[service]
        
        return None
    
    def _set_cached_token(self, service: str, result: AuthenticationResult):
        """キャッシュトークン保存（PowerShell Set-CachedToken互換）"""
        self._token_cache[service] = result
        # 50分（デフォルトトークン期限より短く設定）
        self._token_expiry[service] = datetime.now() + timedelta(minutes=50)
        self.logger.info(f"トークンキャッシュ保存: {service}")
    
    def test_authentication(self) -> Dict[str, bool]:
        """認証状態テスト（PowerShell Test-AuthenticationStatus互換）"""
        try:
            result = {}
            
            # Microsoft Graph テスト
            graph_result = self._get_cached_token("MicrosoftGraph")
            if graph_result and graph_result.success:
                result['MicrosoftGraph'] = self._test_graph_connection(graph_result.access_token)
            else:
                result['MicrosoftGraph'] = False
            
            # Exchange Online テスト
            exchange_result = self._get_cached_token("ExchangeOnline") or graph_result
            if exchange_result and exchange_result.success:
                result['ExchangeOnline'] = self._test_exchange_permissions(exchange_result.access_token)
            else:
                result['ExchangeOnline'] = False
            
            return result
            
        except Exception as e:
            self.logger.error(f"認証状態テストエラー: {str(e)}")
            return {'MicrosoftGraph': False, 'ExchangeOnline': False}
    
    def get_access_token(self, service: str = "MicrosoftGraph") -> Optional[str]:
        """アクセストークン取得"""
        cached_result = self._get_cached_token(service)
        if cached_result and cached_result.success:
            return cached_result.access_token
        return None
    
    def disconnect_all_services(self):
        """全サービス切断（PowerShell Disconnect-AllServices互換）"""
        try:
            self.logger.info("全サービス接続切断中...")
            
            # トークンキャッシュクリア
            self._token_cache.clear()
            self._token_expiry.clear()
            
            # 認証クライアントクリア
            self._auth_clients.clear()
            
            self.logger.info("全サービス接続切断完了")
            
        except Exception as e:
            self.logger.error(f"サービス切断エラー: {str(e)}")
    
    def get_integration_diagnostics(self) -> Dict[str, Any]:
        """統合診断情報取得（PowerShell Get-IntegrationDiagnostics互換）"""
        try:
            diagnostics = {
                'timestamp': datetime.now().isoformat(),
                'microsoft_graph': {
                    'status': 'Unknown',
                    'last_error': None
                },
                'exchange_online': {
                    'status': 'Unknown',
                    'last_error': None
                },
                'integration': {
                    'status': 'Unknown',
                    'issues': [],
                    'recommendations': []
                }
            }
            
            # Microsoft Graph 状態確認
            graph_token = self.get_access_token("MicrosoftGraph")
            if graph_token:
                if self._test_graph_connection(graph_token):
                    diagnostics['microsoft_graph']['status'] = 'Connected'
                else:
                    diagnostics['microsoft_graph']['status'] = 'Disconnected'
                    diagnostics['integration']['issues'].append('Microsoft Graph接続が無効')
            else:
                diagnostics['microsoft_graph']['status'] = 'No Token'
                diagnostics['integration']['issues'].append('Microsoft Graphトークンなし')
            
            # Exchange Online 状態確認
            exchange_token = self.get_access_token("ExchangeOnline") or graph_token
            if exchange_token:
                if self._test_exchange_permissions(exchange_token):
                    diagnostics['exchange_online']['status'] = 'Connected'
                else:
                    diagnostics['exchange_online']['status'] = 'Disconnected'
                    diagnostics['integration']['issues'].append('Exchange Online権限が無効')
            else:
                diagnostics['exchange_online']['status'] = 'No Token'
                diagnostics['integration']['issues'].append('Exchange Onlineトークンなし')
            
            # 全体ステータス判定
            graph_ok = diagnostics['microsoft_graph']['status'] == 'Connected'
            exchange_ok = diagnostics['exchange_online']['status'] == 'Connected'
            
            if graph_ok and exchange_ok:
                diagnostics['integration']['status'] = 'Healthy'
            elif graph_ok or exchange_ok:
                diagnostics['integration']['status'] = 'Partial'
            else:
                diagnostics['integration']['status'] = 'Failed'
                diagnostics['integration']['recommendations'].append('認証の再実行が必要')
            
            return diagnostics
            
        except Exception as e:
            self.logger.error(f"統合診断エラー: {str(e)}")
            return {
                'timestamp': datetime.now().isoformat(),
                'error': str(e),
                'integration': {'status': 'Error'}
            }


def load_authentication_config(config_path: str = None) -> AuthenticationConfig:
    """
    認証設定読み込み（PowerShell appsettings.json互換）
    """
    if not config_path:
        # デフォルト設定ファイル検索
        base_dir = Path(__file__).parent.parent.parent
        config_candidates = [
            base_dir / "Config" / "appsettings.json",
            base_dir / "appsettings.json",
            Path.cwd() / "appsettings.json"
        ]
        
        for candidate in config_candidates:
            if candidate.exists():
                config_path = str(candidate)
                break
        
        if not config_path:
            raise FileNotFoundError("設定ファイルが見つかりません")
    
    with open(config_path, 'r', encoding='utf-8') as f:
        config_data = json.load(f)
    
    # EntraID設定抽出
    entra_config = config_data.get('EntraID', {})
    
    return AuthenticationConfig(
        tenant_id=entra_config.get('TenantId', ''),
        client_id=entra_config.get('ClientId', ''),
        client_secret=entra_config.get('ClientSecret'),
        certificate_path=entra_config.get('CertificatePath'),
        certificate_password=entra_config.get('CertificatePassword'),
        certificate_thumbprint=entra_config.get('CertificateThumbprint'),
        authority=entra_config.get('Authority'),
        scopes=entra_config.get('Scopes')
    )


def create_authentication_manager(config_path: str = None) -> MSALAuthenticationManager:
    """
    認証マネージャー作成（エントリーポイント）
    """
    config = load_authentication_config(config_path)
    return MSALAuthenticationManager(config)


# PowerShell互換性関数
def Connect_ToMicrosoft365(config_path: str = None, services: List[str] = None) -> AuthenticationResult:
    """PowerShell Connect-ToMicrosoft365互換関数"""
    manager = create_authentication_manager(config_path)
    return manager.authenticate(services)


def Test_AuthenticationStatus(config_path: str = None) -> Dict[str, bool]:
    """PowerShell Test-AuthenticationStatus互換関数"""
    manager = create_authentication_manager(config_path)
    return manager.test_authentication()


def Get_IntegrationDiagnostics(config_path: str = None) -> Dict[str, Any]:
    """PowerShell Get-IntegrationDiagnostics互換関数"""
    manager = create_authentication_manager(config_path)
    return manager.get_integration_diagnostics()


if __name__ == "__main__":
    # テスト実行
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    
    try:
        # 認証テスト
        result = Connect_ToMicrosoft365()
        print(f"認証結果: {result}")
        
        # 診断テスト
        diagnostics = Get_IntegrationDiagnostics()
        print(f"診断結果: {diagnostics}")
        
    except Exception as e:
        print(f"テストエラー: {e}")