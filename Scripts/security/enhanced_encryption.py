#!/usr/bin/env python3
"""
Enhanced Data Encryption Utility
Provides AES encryption for sensitive data
"""

import os
import base64
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

class SecureDataManager:
    """Secure data encryption/decryption manager"""
    
    def __init__(self, password: str = None):
        if password is None:
            password = os.environ.get('ENCRYPTION_KEY', 'default-key')
        
        # Generate key from password
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=b'microsoft365tool',
            iterations=100000,
        )
        key = base64.urlsafe_b64encode(kdf.derive(password.encode()))
        self.cipher = Fernet(key)
    
    def encrypt_sensitive_data(self, data: str) -> str:
        """Encrypt sensitive data"""
        encrypted = self.cipher.encrypt(data.encode())
        return base64.urlsafe_b64encode(encrypted).decode()
    
    def decrypt_sensitive_data(self, encrypted_data: str) -> str:
        """Decrypt sensitive data"""
        encrypted_bytes = base64.urlsafe_b64decode(encrypted_data.encode())
        decrypted = self.cipher.decrypt(encrypted_bytes)
        return decrypted.decode()
    
    def secure_log_data(self, user_data: Dict) -> Dict:
        """Sanitize user data for logging"""
        safe_data = {}
        sensitive_fields = ['userPrincipalName', 'mail', 'displayName']
        
        for key, value in user_data.items():
            if key in sensitive_fields and value:
                # Only log user ID for sensitive fields
                safe_data[key] = "***REDACTED***"
                safe_data[f"{key}_id"] = user_data.get('id', 'unknown')
            else:
                safe_data[key] = value
        
        return safe_data
