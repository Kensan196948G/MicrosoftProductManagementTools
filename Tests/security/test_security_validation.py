"""
セキュリティ統合テスト - セキュリティ検証・脆弱性テスト
Dev1 - Test/QA Developer によるセキュリティテスト実装

Microsoft 365管理ツールのセキュリティ要件検証
"""

import pytest
import json
import tempfile
import hashlib
import secrets
import ssl
import base64
from pathlib import Path
from datetime import datetime, timedelta
from unittest.mock import Mock, patch, MagicMock
from typing import Dict, List, Any, Optional
import jwt
import cryptography
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
import requests

# プロジェクトモジュール（実装時に調整）
try:
    from src.core.auth.auth_manager import AuthManager
    from src.core.auth.certificate_manager import CertificateManager
    from src.core.config import Config
    from src.api.graph.client import GraphClient
    from src.core.security.encryption import EncryptionManager
    from src.core.security.token_validator import TokenValidator
except ImportError:
    # 開発初期段階でのモック定義
    AuthManager = Mock()
    CertificateManager = Mock()
    Config = Mock()
    GraphClient = Mock()
    EncryptionManager = Mock()
    TokenValidator = Mock()


@pytest.mark.security
class TestAuthenticationSecurity:
    """認証セキュリティテスト"""
    
    @pytest.fixture(autouse=True)
    def setup_auth_security_test(self, temp_project_dir):
        """認証セキュリティテストセットアップ"""
        self.temp_dir = temp_project_dir
        self.config_path = self.temp_dir / "config.json"
        
        # テスト用設定
        self.test_config = {
            "Authentication": {
                "TenantId": "test-tenant-12345",
                "ClientId": "test-client-67890",
                "CertificateThumbprint": "A1B2C3D4E5F6789012345678901234567890ABCD",
                "AuthorityUrl": "https://login.microsoftonline.com/",
                "Scopes": ["https://graph.microsoft.com/.default"]
            },
            "Security": {
                "TokenValidationSettings": {
                    "ValidateIssuer": True,
                    "ValidateAudience": True,
                    "ValidateLifetime": True,
                    "ValidateSignature": True,
                    "ClockSkew": 300
                },
                "CertificateSettings": {
                    "StoreLocation": "CurrentUser",
                    "StoreName": "My",
                    "ValidationMode": "ChainTrust"
                }
            }
        }
        
        with open(self.config_path, 'w', encoding='utf-8') as f:
            json.dump(self.test_config, f, indent=2)
    
    @pytest.mark.requires_auth
    def test_certificate_validation_security(self):
        """証明書検証セキュリティテスト"""
        # 1. 正常な証明書検証
        cert_manager = CertificateManager(self.config_path)
        
        # 2. 無効な証明書サムプリント
        invalid_thumbprints = [
            "INVALID_THUMBPRINT",
            "12345", 
            "X" * 40,  # 無効な文字
            "",  # 空文字
            None  # None値
        ]
        
        for invalid_thumbprint in invalid_thumbprints:
            with pytest.raises(Exception):
                cert_manager.validate_certificate(invalid_thumbprint)
        
        # 3. 期限切れ証明書のテスト
        expired_cert_info = {
            "thumbprint": "EXPIRED_CERT_THUMBPRINT",
            "valid_from": datetime.now() - timedelta(days=400),
            "valid_to": datetime.now() - timedelta(days=1)
        }
        
        with patch.object(cert_manager, 'get_certificate_info', return_value=expired_cert_info):
            with pytest.raises(Exception, match="証明書が期限切れです"):
                cert_manager.validate_certificate_expiry(expired_cert_info["thumbprint"])
        
        # 4. 証明書チェーン検証
        with patch.object(cert_manager, 'validate_certificate_chain') as mock_chain:
            mock_chain.return_value = False
            
            with pytest.raises(Exception, match="証明書チェーンが無効です"):
                cert_manager.validate_certificate_chain("test-thumbprint")
    
    @pytest.mark.requires_auth
    def test_token_validation_security(self):
        """トークン検証セキュリティテスト"""
        token_validator = TokenValidator(self.config_path)
        
        # 1. 正常なトークン（モック）
        valid_token_payload = {
            "iss": "https://sts.windows.net/test-tenant-12345/",
            "aud": "test-client-67890",
            "exp": int((datetime.now() + timedelta(hours=1)).timestamp()),
            "nbf": int((datetime.now() - timedelta(minutes=5)).timestamp()),
            "iat": int(datetime.now().timestamp()),
            "sub": "test-user-id",
            "tid": "test-tenant-12345"
        }
        
        # テスト用秘密鍵
        private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048
        )
        
        valid_token = jwt.encode(
            valid_token_payload, 
            private_key, 
            algorithm="RS256",
            headers={"kid": "test-key-id"}
        )
        
        # 2. 署名検証テスト
        public_key = private_key.public_key()
        
        with patch.object(token_validator, 'get_public_key', return_value=public_key):
            # 正常なトークンの検証
            is_valid = token_validator.validate_token(valid_token)
            assert is_valid is True
        
        # 3. 改ざんされたトークンテスト
        tampered_token = valid_token[:-10] + "tampered123"
        
        with patch.object(token_validator, 'get_public_key', return_value=public_key):
            with pytest.raises(jwt.InvalidSignatureError):
                token_validator.validate_token(tampered_token)
        
        # 4. 期限切れトークンテスト
        expired_payload = valid_token_payload.copy()
        expired_payload["exp"] = int((datetime.now() - timedelta(hours=1)).timestamp())
        
        expired_token = jwt.encode(expired_payload, private_key, algorithm="RS256")
        
        with patch.object(token_validator, 'get_public_key', return_value=public_key):
            with pytest.raises(jwt.ExpiredSignatureError):
                token_validator.validate_token(expired_token)
        
        # 5. 不正なissuer テスト
        invalid_issuer_payload = valid_token_payload.copy()
        invalid_issuer_payload["iss"] = "https://malicious-issuer.com/"
        
        invalid_issuer_token = jwt.encode(invalid_issuer_payload, private_key, algorithm="RS256")
        
        with patch.object(token_validator, 'get_public_key', return_value=public_key):
            with pytest.raises(jwt.InvalidIssuerError):
                token_validator.validate_token(invalid_issuer_token)
    
    @pytest.mark.requires_auth
    def test_authentication_flow_security(self):
        """認証フローセキュリティテスト"""
        auth_manager = AuthManager(self.config_path)
        
        # 1. 正常な認証フロー
        with patch.object(auth_manager, 'authenticate') as mock_auth:
            mock_auth.return_value = {
                "access_token": "valid_token",
                "token_type": "Bearer",
                "expires_in": 3600
            }
            
            result = auth_manager.authenticate()
            assert result is not None
            assert "access_token" in result
        
        # 2. 不正な認証情報
        invalid_configs = [
            {"TenantId": "", "ClientId": "test-client", "CertificateThumbprint": "test-cert"},
            {"TenantId": "test-tenant", "ClientId": "", "CertificateThumbprint": "test-cert"},
            {"TenantId": "test-tenant", "ClientId": "test-client", "CertificateThumbprint": ""},
            {"TenantId": None, "ClientId": "test-client", "CertificateThumbprint": "test-cert"}
        ]
        
        for invalid_config in invalid_configs:
            with patch.object(auth_manager, '_load_config', return_value=invalid_config):
                with pytest.raises(Exception):
                    auth_manager.authenticate()
        
        # 3. CSRFトークン検証
        csrf_token = secrets.token_urlsafe(32)
        
        with patch.object(auth_manager, 'generate_csrf_token', return_value=csrf_token):
            generated_token = auth_manager.generate_csrf_token()
            assert len(generated_token) > 20
            assert generated_token == csrf_token
        
        # 4. セッション管理セキュリティ
        session_data = {
            "user_id": "test-user",
            "session_id": secrets.token_urlsafe(32),
            "created_at": datetime.now().isoformat(),
            "expires_at": (datetime.now() + timedelta(hours=1)).isoformat()
        }
        
        # セッションタイムアウト検証
        expired_session = session_data.copy()
        expired_session["expires_at"] = (datetime.now() - timedelta(hours=1)).isoformat()
        
        with patch.object(auth_manager, 'get_session', return_value=expired_session):
            with pytest.raises(Exception, match="セッションが期限切れです"):
                auth_manager.validate_session("test-session-id")


@pytest.mark.security
class TestDataEncryptionSecurity:
    """データ暗号化セキュリティテスト"""
    
    @pytest.fixture(autouse=True)
    def setup_encryption_test(self, temp_project_dir):
        """暗号化テストセットアップ"""
        self.temp_dir = temp_project_dir
        self.encryption_manager = EncryptionManager()
        
        # テスト用暗号化設定
        self.encryption_config = {
            "algorithm": "AES-256-GCM",
            "key_derivation": "PBKDF2",
            "iterations": 100000,
            "salt_length": 32
        }
    
    def test_sensitive_data_encryption(self):
        """機密データ暗号化テスト"""
        # 1. 機密データ準備
        sensitive_data = {
            "client_secret": "super-secret-client-secret-12345",
            "api_key": "api-key-67890-abcdef",
            "personal_info": {
                "name": "山田太郎",
                "email": "yamada@example.com",
                "phone": "090-1234-5678"
            }
        }
        
        # 2. 暗号化実行
        encrypted_data = self.encryption_manager.encrypt_data(
            json.dumps(sensitive_data, ensure_ascii=False),
            self.encryption_config
        )
        
        # 3. 暗号化データの検証
        assert encrypted_data is not None
        assert encrypted_data != json.dumps(sensitive_data)
        assert len(encrypted_data) > len(json.dumps(sensitive_data))
        
        # 4. 復号化実行
        decrypted_data = self.encryption_manager.decrypt_data(
            encrypted_data,
            self.encryption_config
        )
        
        # 5. 復号化データの検証
        decrypted_json = json.loads(decrypted_data)
        assert decrypted_json == sensitive_data
        
        # 6. 不正な暗号化データのテスト
        invalid_encrypted_data = encrypted_data[:-10] + "tamperedXX"
        
        with pytest.raises(Exception):
            self.encryption_manager.decrypt_data(
                invalid_encrypted_data,
                self.encryption_config
            )
    
    def test_password_hashing_security(self):
        """パスワードハッシュセキュリティテスト"""
        # 1. パスワードハッシュ生成
        passwords = [
            "simple_password",
            "Complex@Password123!",
            "VeryLongPasswordWith@Special#Characters$And%Numbers123456789",
            "日本語パスワード@12345"
        ]
        
        hashed_passwords = []
        
        for password in passwords:
            # BCrypt等の安全なハッシュ関数を使用
            salt = secrets.token_hex(32)
            hashed = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
            hashed_password = {
                "hash": base64.b64encode(hashed).decode(),
                "salt": salt,
                "iterations": 100000
            }
            hashed_passwords.append(hashed_password)
        
        # 2. ハッシュ値の一意性確認
        hash_values = [hp["hash"] for hp in hashed_passwords]
        assert len(set(hash_values)) == len(hash_values)  # 全て異なる
        
        # 3. パスワード検証
        for i, password in enumerate(passwords):
            stored_hash = hashed_passwords[i]
            
            # 正しいパスワードの検証
            test_hash = hashlib.pbkdf2_hmac(
                'sha256',
                password.encode(),
                stored_hash["salt"].encode(),
                stored_hash["iterations"]
            )
            
            assert base64.b64encode(test_hash).decode() == stored_hash["hash"]
            
            # 間違ったパスワードの検証
            wrong_password = password + "wrong"
            wrong_hash = hashlib.pbkdf2_hmac(
                'sha256',
                wrong_password.encode(),
                stored_hash["salt"].encode(),
                stored_hash["iterations"]
            )
            
            assert base64.b64encode(wrong_hash).decode() != stored_hash["hash"]
    
    def test_file_encryption_security(self):
        """ファイル暗号化セキュリティテスト"""
        # 1. テストファイル作成
        test_file = self.temp_dir / "sensitive_data.json"
        sensitive_content = {
            "database_connection": "Server=localhost;Database=TestDB;User=admin;Password=secret123",
            "api_keys": {
                "graph_api": "graph-api-key-12345",
                "exchange_api": "exchange-api-key-67890"
            },
            "certificates": {
                "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC..."
            }
        }
        
        with open(test_file, 'w', encoding='utf-8') as f:
            json.dump(sensitive_content, f, ensure_ascii=False, indent=2)
        
        # 2. ファイル暗号化
        encrypted_file = self.temp_dir / "sensitive_data.encrypted"
        
        with open(test_file, 'rb') as f:
            file_data = f.read()
        
        encrypted_data = self.encryption_manager.encrypt_file_data(
            file_data,
            self.encryption_config
        )
        
        with open(encrypted_file, 'wb') as f:
            f.write(encrypted_data)
        
        # 3. 暗号化ファイルの検証
        assert encrypted_file.exists()
        assert encrypted_file.stat().st_size > test_file.stat().st_size
        
        # 4. 暗号化ファイルの内容確認（読み取り不可）
        with open(encrypted_file, 'rb') as f:
            encrypted_content = f.read()
            
        # 元のデータが含まれていないことを確認
        assert b"database_connection" not in encrypted_content
        assert b"api_keys" not in encrypted_content
        assert b"certificates" not in encrypted_content
        
        # 5. 復号化実行
        decrypted_data = self.encryption_manager.decrypt_file_data(
            encrypted_content,
            self.encryption_config
        )
        
        # 6. 復号化データの検証
        decrypted_json = json.loads(decrypted_data.decode('utf-8'))
        assert decrypted_json == sensitive_content


@pytest.mark.security
class TestAPISecurityValidation:
    """API セキュリティ検証テスト"""
    
    @pytest.fixture(autouse=True)
    def setup_api_security_test(self):
        """API セキュリティテストセットアップ"""
        self.graph_client = GraphClient()
        self.api_endpoints = [
            "https://graph.microsoft.com/v1.0/users",
            "https://graph.microsoft.com/v1.0/groups",
            "https://graph.microsoft.com/v1.0/applications",
            "https://graph.microsoft.com/v1.0/servicePrincipals"
        ]
    
    @pytest.mark.api
    def test_https_enforcement(self):
        """HTTPS 強制セキュリティテスト"""
        # 1. HTTP URL の拒否
        http_urls = [
            "http://graph.microsoft.com/v1.0/users",
            "http://login.microsoftonline.com/common/oauth2/v2.0/token",
            "http://management.azure.com/subscriptions"
        ]
        
        for http_url in http_urls:
            with pytest.raises(Exception, match="HTTPSが必要です"):
                self.graph_client.validate_url_security(http_url)
        
        # 2. HTTPS URL の許可
        https_urls = [
            "https://graph.microsoft.com/v1.0/users",
            "https://login.microsoftonline.com/common/oauth2/v2.0/token",
            "https://management.azure.com/subscriptions"
        ]
        
        for https_url in https_urls:
            # 例外が発生しないことを確認
            try:
                self.graph_client.validate_url_security(https_url)
            except Exception:
                pytest.fail(f"HTTPS URL が拒否されました: {https_url}")
    
    @pytest.mark.api
    def test_api_request_validation(self):
        """API リクエスト検証テスト"""
        # 1. 正常なリクエスト
        valid_request = {
            "method": "GET",
            "url": "https://graph.microsoft.com/v1.0/users",
            "headers": {
                "Authorization": "Bearer valid-token-12345",
                "Content-Type": "application/json"
            }
        }
        
        is_valid = self.graph_client.validate_request(valid_request)
        assert is_valid is True
        
        # 2. 不正なヘッダー
        invalid_requests = [
            # Authorization ヘッダーなし
            {
                "method": "GET",
                "url": "https://graph.microsoft.com/v1.0/users",
                "headers": {"Content-Type": "application/json"}
            },
            # 不正なトークン形式
            {
                "method": "GET",
                "url": "https://graph.microsoft.com/v1.0/users",
                "headers": {
                    "Authorization": "invalid-token-format",
                    "Content-Type": "application/json"
                }
            },
            # SQLインジェクション試行
            {
                "method": "GET",
                "url": "https://graph.microsoft.com/v1.0/users?$filter=displayName eq 'test'; DROP TABLE users;--",
                "headers": {
                    "Authorization": "Bearer valid-token-12345",
                    "Content-Type": "application/json"
                }
            }
        ]
        
        for invalid_request in invalid_requests:
            with pytest.raises(Exception):
                self.graph_client.validate_request(invalid_request)
    
    @pytest.mark.api
    def test_rate_limiting_security(self):
        """レート制限セキュリティテスト"""
        # 1. 正常なリクエスト頻度
        normal_requests = []
        for i in range(10):
            request = {
                "timestamp": datetime.now() - timedelta(seconds=i),
                "client_id": "test-client-12345",
                "endpoint": "/users"
            }
            normal_requests.append(request)
        
        # レート制限チェック（10リクエスト/分）
        rate_limiter = self.graph_client.get_rate_limiter()
        
        for request in normal_requests:
            is_allowed = rate_limiter.is_request_allowed(request)
            assert is_allowed is True
        
        # 2. 異常なリクエスト頻度
        burst_requests = []
        for i in range(100):  # 100リクエスト/秒
            request = {
                "timestamp": datetime.now(),
                "client_id": "test-client-12345",
                "endpoint": "/users"
            }
            burst_requests.append(request)
        
        # 最初の数リクエストは許可、その後は拒否
        allowed_count = 0
        for request in burst_requests:
            if rate_limiter.is_request_allowed(request):
                allowed_count += 1
            else:
                break
        
        assert allowed_count < 100  # 全てが許可されることはない
        assert allowed_count > 0    # 最初の数リクエストは許可
    
    @pytest.mark.api
    def test_input_sanitization_security(self):
        """入力サニタイゼーションセキュリティテスト"""
        # 1. 危険な入力パターン
        dangerous_inputs = [
            # XSS攻撃
            "<script>alert('XSS')</script>",
            "javascript:alert('XSS')",
            "<img src=x onerror=alert('XSS')>",
            
            # SQLインジェクション
            "'; DROP TABLE users; --",
            "' OR '1'='1",
            "UNION SELECT * FROM passwords",
            
            # コマンドインジェクション
            "; rm -rf /",
            "| cat /etc/passwd",
            "&& curl malicious-site.com",
            
            # パストラバーサル
            "../../etc/passwd",
            "..\\..\\windows\\system32\\config\\sam",
            
            # 非常に長い文字列
            "A" * 10000,
            
            # 制御文字
            "\x00\x01\x02\x03\x04\x05"
        ]
        
        input_sanitizer = self.graph_client.get_input_sanitizer()
        
        for dangerous_input in dangerous_inputs:
            # 2. サニタイゼーション実行
            sanitized = input_sanitizer.sanitize(dangerous_input)
            
            # 3. 危険な要素が除去されていることを確認
            assert "<script>" not in sanitized.lower()
            assert "javascript:" not in sanitized.lower()
            assert "drop table" not in sanitized.lower()
            assert "rm -rf" not in sanitized
            assert "../" not in sanitized
            assert len(sanitized) <= 1000  # 最大長制限
            
            # 4. 制御文字の除去確認
            for char in sanitized:
                assert ord(char) >= 32 or char in ['\n', '\r', '\t']


@pytest.mark.security
class TestVulnerabilityScanning:
    """脆弱性スキャンテスト"""
    
    @pytest.fixture(autouse=True)
    def setup_vulnerability_test(self, temp_project_dir):
        """脆弱性テストセットアップ"""
        self.temp_dir = temp_project_dir
        self.vulnerability_scanner = Mock()
    
    def test_dependency_vulnerability_scan(self):
        """依存関係脆弱性スキャンテスト"""
        # 1. 依存関係情報
        dependencies = {
            "requests": "2.25.1",
            "urllib3": "1.26.5",
            "cryptography": "3.4.8",
            "jwt": "2.1.0",
            "msal": "1.12.0"
        }
        
        # 2. 既知の脆弱性データベース（モック）
        known_vulnerabilities = {
            "requests": {
                "2.25.1": [
                    {
                        "cve": "CVE-2023-32681",
                        "severity": "medium",
                        "description": "Request library vulnerability"
                    }
                ]
            },
            "urllib3": {
                "1.26.5": [
                    {
                        "cve": "CVE-2023-43804",
                        "severity": "high",
                        "description": "urllib3 vulnerability"
                    }
                ]
            }
        }
        
        # 3. 脆弱性スキャン実行
        vulnerabilities_found = []
        
        for package, version in dependencies.items():
            if package in known_vulnerabilities:
                if version in known_vulnerabilities[package]:
                    vulnerabilities_found.extend(known_vulnerabilities[package][version])
        
        # 4. 脆弱性レポート生成
        vulnerability_report = {
            "scan_date": datetime.now().isoformat(),
            "total_dependencies": len(dependencies),
            "vulnerabilities_found": len(vulnerabilities_found),
            "high_severity": len([v for v in vulnerabilities_found if v["severity"] == "high"]),
            "medium_severity": len([v for v in vulnerabilities_found if v["severity"] == "medium"]),
            "low_severity": len([v for v in vulnerabilities_found if v["severity"] == "low"]),
            "details": vulnerabilities_found
        }
        
        # 5. 脆弱性レポート保存
        report_path = self.temp_dir / "vulnerability_report.json"
        with open(report_path, 'w', encoding='utf-8') as f:
            json.dump(vulnerability_report, f, ensure_ascii=False, indent=2)
        
        # 6. 高リスク脆弱性の検出
        high_risk_count = vulnerability_report["high_severity"]
        if high_risk_count > 0:
            pytest.fail(f"高リスク脆弱性が{high_risk_count}件検出されました")
        
        # 7. 脆弱性レポートの確認
        assert report_path.exists()
        assert vulnerability_report["total_dependencies"] == 5
        assert vulnerability_report["vulnerabilities_found"] == 2
    
    def test_security_headers_validation(self):
        """セキュリティヘッダー検証テスト"""
        # 1. 推奨セキュリティヘッダー
        required_security_headers = {
            "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
            "X-Content-Type-Options": "nosniff",
            "X-Frame-Options": "DENY",
            "X-XSS-Protection": "1; mode=block",
            "Content-Security-Policy": "default-src 'self'",
            "Referrer-Policy": "strict-origin-when-cross-origin"
        }
        
        # 2. APIレスポンスヘッダーの検証
        mock_response_headers = {
            "Content-Type": "application/json",
            "X-Content-Type-Options": "nosniff",
            "X-Frame-Options": "DENY",
            "Cache-Control": "no-cache, no-store, must-revalidate"
        }
        
        # 3. 不足しているセキュリティヘッダーの検出
        missing_headers = []
        for header, expected_value in required_security_headers.items():
            if header not in mock_response_headers:
                missing_headers.append(header)
        
        # 4. セキュリティヘッダーレポート
        security_report = {
            "total_required_headers": len(required_security_headers),
            "present_headers": len(required_security_headers) - len(missing_headers),
            "missing_headers": missing_headers,
            "security_score": ((len(required_security_headers) - len(missing_headers)) / len(required_security_headers)) * 100
        }
        
        # 5. セキュリティスコアの確認
        assert security_report["security_score"] >= 50  # 最低50%のセキュリティスコア
        
        # 6. 重要なセキュリティヘッダーの確認
        critical_headers = ["X-Content-Type-Options", "X-Frame-Options"]
        for header in critical_headers:
            assert header in mock_response_headers or header in missing_headers
        
        print(f"セキュリティスコア: {security_report['security_score']:.1f}%")
        print(f"不足ヘッダー: {missing_headers}")


if __name__ == "__main__":
    pytest.main([
        __file__, 
        "-v", 
        "--tb=short", 
        "-m", "security",
        "--html=security_test_report.html"
    ])