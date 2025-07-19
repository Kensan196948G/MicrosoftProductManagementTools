#!/usr/bin/env python3
"""
Multi-Factor Authentication Enhanced - CTO継続技術監督最優先実装
Microsoft 365 Management Tools - MFA強化セキュリティ

Features:
- Multi-factor認証強化システム
- TOTP/SMS/Email/Hardware Token対応
- Zero-trust統合準備
- Enterprise Grade MFA実装
- リアルタイム認証監視

Author: Operations Manager - CTO継続技術監督対応
Version: 2.0.0 CTO-SUPERVISED
Date: 2025-07-19
"""

import asyncio
import logging
import secrets
import hashlib
import hmac
import time
import base64
import qrcode
import io
from typing import Dict, List, Optional, Any, Union, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from enum import Enum
import json
import sqlite3
from pathlib import Path

try:
    import pyotp
    import cryptography
    from cryptography.fernet import Fernet
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa, padding
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
    import smtplib
    from email.mime.text import MimeText
    from email.mime.multipart import MimeMultipart
    import requests
except ImportError as e:
    print(f"⚠️ MFA dependencies not available: {e}")
    print("Install with: pip install pyotp cryptography qrcode[pil] requests")

# Configure logging for enterprise security
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.FileHandler('/var/log/microsoft365-mfa.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class MFAMethodType(Enum):
    """Multi-Factor Authentication Method Types"""
    TOTP = "totp"  # Time-based One-Time Password
    SMS = "sms"   # SMS verification
    EMAIL = "email"  # Email verification
    HARDWARE_TOKEN = "hardware_token"  # Hardware security key
    PUSH_NOTIFICATION = "push"  # Push notification
    BACKUP_CODES = "backup_codes"  # Backup recovery codes


class AuthenticationStatus(Enum):
    """Authentication Status"""
    PENDING = "pending"
    VERIFIED = "verified"
    FAILED = "failed"
    EXPIRED = "expired"
    BLOCKED = "blocked"


@dataclass
class MFADevice:
    """MFA Device Configuration"""
    device_id: str
    user_id: str
    method_type: MFAMethodType
    device_name: str
    secret_key: str = ""
    phone_number: str = ""
    email_address: str = ""
    is_primary: bool = False
    is_active: bool = True
    created_at: datetime = field(default_factory=datetime.utcnow)
    last_used: Optional[datetime] = None
    use_count: int = 0
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            "device_id": self.device_id,
            "user_id": self.user_id,
            "method_type": self.method_type.value,
            "device_name": self.device_name,
            "phone_number": self.phone_number,
            "email_address": self.email_address,
            "is_primary": self.is_primary,
            "is_active": self.is_active,
            "created_at": self.created_at.isoformat(),
            "last_used": self.last_used.isoformat() if self.last_used else None,
            "use_count": self.use_count
        }


@dataclass
class AuthenticationAttempt:
    """Authentication Attempt Record"""
    attempt_id: str
    user_id: str
    device_id: str
    method_type: MFAMethodType
    status: AuthenticationStatus
    ip_address: str = ""
    user_agent: str = ""
    location: str = ""
    timestamp: datetime = field(default_factory=datetime.utcnow)
    verification_code: str = ""
    expires_at: Optional[datetime] = None
    
    def is_expired(self) -> bool:
        """Check if attempt is expired"""
        if not self.expires_at:
            return False
        return datetime.utcnow() > self.expires_at


class EncryptionManager:
    """Enhanced Encryption Manager for MFA Secrets"""
    
    def __init__(self, master_key: Optional[bytes] = None):
        if master_key:
            self.fernet = Fernet(master_key)
        else:
            # Generate new key for development
            self.fernet = Fernet(Fernet.generate_key())
        
        logger.info("🔐 Encryption Manager initialized")
    
    def encrypt_secret(self, secret: str) -> str:
        """Encrypt MFA secret"""
        try:
            encrypted_data = self.fernet.encrypt(secret.encode())
            return base64.urlsafe_b64encode(encrypted_data).decode()
        except Exception as e:
            logger.error(f"Failed to encrypt secret: {e}")
            raise
    
    def decrypt_secret(self, encrypted_secret: str) -> str:
        """Decrypt MFA secret"""
        try:
            encrypted_data = base64.urlsafe_b64decode(encrypted_secret.encode())
            decrypted_data = self.fernet.decrypt(encrypted_data)
            return decrypted_data.decode()
        except Exception as e:
            logger.error(f"Failed to decrypt secret: {e}")
            raise
    
    def generate_backup_codes(self, count: int = 10) -> List[str]:
        """Generate backup recovery codes"""
        codes = []
        for _ in range(count):
            code = secrets.token_hex(4).upper()
            formatted_code = f"{code[:4]}-{code[4:]}"
            codes.append(formatted_code)
        
        logger.info(f"Generated {count} backup codes")
        return codes


class TOTPManager:
    """TOTP (Time-based One-Time Password) Manager"""
    
    def __init__(self, encryption_manager: EncryptionManager):
        self.encryption_manager = encryption_manager
        
        logger.info("🔑 TOTP Manager initialized")
    
    def generate_secret(self) -> str:
        """Generate new TOTP secret"""
        return pyotp.random_base32()
    
    def generate_provisioning_uri(self, 
                                secret: str, 
                                user_email: str,
                                issuer_name: str = "Microsoft 365 Management") -> str:
        """Generate TOTP provisioning URI for QR code"""
        totp = pyotp.TOTP(secret)
        return totp.provisioning_uri(
            name=user_email,
            issuer_name=issuer_name
        )
    
    def generate_qr_code(self, provisioning_uri: str) -> bytes:
        """Generate QR code for TOTP setup"""
        try:
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=4,
            )
            qr.add_data(provisioning_uri)
            qr.make(fit=True)
            
            img = qr.make_image(fill_color="black", back_color="white")
            
            # Convert to bytes
            img_buffer = io.BytesIO()
            img.save(img_buffer, format='PNG')
            img_buffer.seek(0)
            
            logger.info("📱 QR code generated for TOTP setup")
            return img_buffer.getvalue()
            
        except Exception as e:
            logger.error(f"Failed to generate QR code: {e}")
            raise
    
    def verify_totp_code(self, secret: str, user_code: str, window: int = 1) -> bool:
        """Verify TOTP code"""
        try:
            totp = pyotp.TOTP(secret)
            return totp.verify(user_code, valid_window=window)
        except Exception as e:
            logger.error(f"TOTP verification failed: {e}")
            return False
    
    def get_current_code(self, secret: str) -> str:
        """Get current TOTP code (for testing)"""
        totp = pyotp.TOTP(secret)
        return totp.now()


class SMSManager:
    """SMS-based MFA Manager"""
    
    def __init__(self, sms_config: Dict[str, Any]):
        self.sms_config = sms_config
        self.verification_codes: Dict[str, Dict[str, Any]] = {}
        
        logger.info("📱 SMS Manager initialized")
    
    def generate_sms_code(self, length: int = 6) -> str:
        """Generate SMS verification code"""
        return ''.join([str(secrets.randbelow(10)) for _ in range(length)])
    
    async def send_sms_code(self, 
                          phone_number: str, 
                          user_id: str,
                          code: str = None) -> Dict[str, Any]:
        """Send SMS verification code"""
        try:
            if not code:
                code = self.generate_sms_code()
            
            # Store verification code with expiration
            verification_data = {
                "code": code,
                "phone_number": phone_number,
                "user_id": user_id,
                "created_at": datetime.utcnow(),
                "expires_at": datetime.utcnow() + timedelta(minutes=5),
                "attempts": 0
            }
            
            verification_id = secrets.token_urlsafe(16)
            self.verification_codes[verification_id] = verification_data
            
            # Send SMS (placeholder - integrate with SMS service)
            await self._send_sms_via_service(phone_number, code)
            
            logger.info(f"📱 SMS code sent to {phone_number[-4:]}")
            
            return {
                "status": "success",
                "verification_id": verification_id,
                "expires_in": 300  # 5 minutes
            }
            
        except Exception as e:
            logger.error(f"Failed to send SMS code: {e}")
            return {"status": "error", "error": str(e)}
    
    async def _send_sms_via_service(self, phone_number: str, code: str):
        """Send SMS via external service (placeholder)"""
        # Integrate with SMS service like Twilio, AWS SNS, etc.
        message = f"Your Microsoft 365 verification code is: {code}. Valid for 5 minutes."
        
        # Placeholder implementation
        logger.info(f"📱 SMS would be sent to {phone_number}: {code}")
        
        # Example Twilio integration:
        # from twilio.rest import Client
        # client = Client(account_sid, auth_token)
        # message = client.messages.create(
        #     body=message,
        #     from_=self.sms_config['from_number'],
        #     to=phone_number
        # )
    
    def verify_sms_code(self, verification_id: str, user_code: str) -> bool:
        """Verify SMS code"""
        try:
            verification_data = self.verification_codes.get(verification_id)
            if not verification_data:
                logger.warning("SMS verification ID not found")
                return False
            
            # Check expiration
            if datetime.utcnow() > verification_data["expires_at"]:
                logger.warning("SMS code expired")
                del self.verification_codes[verification_id]
                return False
            
            # Check attempts
            verification_data["attempts"] += 1
            if verification_data["attempts"] > 3:
                logger.warning("Too many SMS verification attempts")
                del self.verification_codes[verification_id]
                return False
            
            # Verify code
            if verification_data["code"] == user_code:
                logger.info("✅ SMS code verified successfully")
                del self.verification_codes[verification_id]
                return True
            else:
                logger.warning("❌ SMS code verification failed")
                return False
                
        except Exception as e:
            logger.error(f"SMS verification error: {e}")
            return False


class EmailMFAManager:
    """Email-based MFA Manager"""
    
    def __init__(self, email_config: Dict[str, Any]):
        self.email_config = email_config
        self.verification_codes: Dict[str, Dict[str, Any]] = {}
        
        logger.info("📧 Email MFA Manager initialized")
    
    def generate_email_code(self, length: int = 8) -> str:
        """Generate email verification code"""
        return secrets.token_urlsafe(length)[:length].upper()
    
    async def send_email_code(self, 
                            email_address: str, 
                            user_id: str,
                            code: str = None) -> Dict[str, Any]:
        """Send email verification code"""
        try:
            if not code:
                code = self.generate_email_code()
            
            # Store verification code
            verification_data = {
                "code": code,
                "email_address": email_address,
                "user_id": user_id,
                "created_at": datetime.utcnow(),
                "expires_at": datetime.utcnow() + timedelta(minutes=10),
                "attempts": 0
            }
            
            verification_id = secrets.token_urlsafe(16)
            self.verification_codes[verification_id] = verification_data
            
            # Send email
            await self._send_verification_email(email_address, code)
            
            logger.info(f"📧 Email code sent to {email_address}")
            
            return {
                "status": "success",
                "verification_id": verification_id,
                "expires_in": 600  # 10 minutes
            }
            
        except Exception as e:
            logger.error(f"Failed to send email code: {e}")
            return {"status": "error", "error": str(e)}
    
    async def _send_verification_email(self, email_address: str, code: str):
        """Send verification email"""
        try:
            subject = "Microsoft 365 Verification Code"
            body = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Microsoft 365 Verification</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #0078d4;">Microsoft 365 Verification Code</h2>
        <p>Your verification code is:</p>
        <div style="background: #f5f5f5; padding: 20px; text-align: center; font-size: 24px; font-weight: bold; letter-spacing: 2px; border-radius: 5px;">
            {code}
        </div>
        <p><strong>This code expires in 10 minutes.</strong></p>
        <p>If you did not request this verification, please ignore this email.</p>
        <hr style="margin: 20px 0;">
        <p style="font-size: 12px; color: #666;">
            Microsoft 365 Management Tools - Enterprise Security
        </p>
    </div>
</body>
</html>
            """
            
            msg = MimeMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = self.email_config.get("from_address", "noreply@company.com")
            msg["To"] = email_address
            
            html_part = MimeText(body, "html")
            msg.attach(html_part)
            
            # Send email (placeholder - configure SMTP)
            logger.info(f"📧 Email verification sent to {email_address}")
            
            # Example SMTP implementation:
            # with smtplib.SMTP(self.email_config["smtp_server"], self.email_config["smtp_port"]) as server:
            #     if self.email_config.get("use_tls"):
            #         server.starttls()
            #     if self.email_config.get("username"):
            #         server.login(self.email_config["username"], self.email_config["password"])
            #     server.send_message(msg)
            
        except Exception as e:
            logger.error(f"Failed to send verification email: {e}")
            raise
    
    def verify_email_code(self, verification_id: str, user_code: str) -> bool:
        """Verify email code"""
        try:
            verification_data = self.verification_codes.get(verification_id)
            if not verification_data:
                return False
            
            # Check expiration
            if datetime.utcnow() > verification_data["expires_at"]:
                del self.verification_codes[verification_id]
                return False
            
            # Check attempts
            verification_data["attempts"] += 1
            if verification_data["attempts"] > 5:
                del self.verification_codes[verification_id]
                return False
            
            # Verify code
            if verification_data["code"] == user_code:
                del self.verification_codes[verification_id]
                return True
            else:
                return False
                
        except Exception as e:
            logger.error(f"Email verification error: {e}")
            return False


class EnhancedMFAManager:
    """
    Enhanced Multi-Factor Authentication Manager
    CTO継続技術監督最優先実装
    """
    
    def __init__(self, config_path: str = "config/mfa_config.json"):
        self.config = self._load_config(config_path)
        self.encryption_manager = EncryptionManager()
        self.totp_manager = TOTPManager(self.encryption_manager)
        self.sms_manager = SMSManager(self.config.get("sms", {}))
        self.email_manager = EmailMFAManager(self.config.get("email", {}))
        
        # Database setup
        self.db_path = self.config.get("database", {}).get("path", "mfa_database.db")
        self._init_database()
        
        # MFA devices and attempts storage
        self.mfa_devices: Dict[str, List[MFADevice]] = {}
        self.auth_attempts: Dict[str, AuthenticationAttempt] = {}
        
        # Load existing devices
        self._load_mfa_devices()
        
        logger.info("🔐 Enhanced MFA Manager initialized - CTO Supervised")
    
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load MFA configuration"""
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            logger.warning(f"MFA config file not found: {config_path}, using defaults")
            return self._get_default_config()
    
    def _get_default_config(self) -> Dict[str, Any]:
        """Default MFA configuration"""
        return {
            "totp": {
                "issuer": "Microsoft 365 Management",
                "window": 1
            },
            "sms": {
                "service": "placeholder",
                "from_number": "+1234567890"
            },
            "email": {
                "smtp_server": "localhost",
                "smtp_port": 587,
                "from_address": "noreply@company.com"
            },
            "security": {
                "max_attempts": 3,
                "lockout_duration": 300,  # 5 minutes
                "code_lifetime": 300     # 5 minutes
            },
            "database": {
                "path": "mfa_database.db"
            }
        }
    
    def _init_database(self):
        """Initialize MFA database"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # MFA devices table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS mfa_devices (
                    device_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    method_type TEXT NOT NULL,
                    device_name TEXT NOT NULL,
                    secret_key TEXT,
                    phone_number TEXT,
                    email_address TEXT,
                    is_primary BOOLEAN DEFAULT FALSE,
                    is_active BOOLEAN DEFAULT TRUE,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    last_used DATETIME,
                    use_count INTEGER DEFAULT 0
                )
            ''')
            
            # Authentication attempts table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS auth_attempts (
                    attempt_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    device_id TEXT,
                    method_type TEXT NOT NULL,
                    status TEXT NOT NULL,
                    ip_address TEXT,
                    user_agent TEXT,
                    location TEXT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    expires_at DATETIME
                )
            ''')
            
            # Backup codes table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS backup_codes (
                    code_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    code_hash TEXT NOT NULL,
                    is_used BOOLEAN DEFAULT FALSE,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    used_at DATETIME
                )
            ''')
            
            conn.commit()
            conn.close()
            
            logger.info("🗄️ MFA database initialized")
            
        except Exception as e:
            logger.error(f"MFA database initialization failed: {e}")
    
    def _load_mfa_devices(self):
        """Load MFA devices from database"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute("SELECT * FROM mfa_devices WHERE is_active = TRUE")
            rows = cursor.fetchall()
            
            for row in rows:
                device = MFADevice(
                    device_id=row[0],
                    user_id=row[1],
                    method_type=MFAMethodType(row[2]),
                    device_name=row[3],
                    secret_key=row[4] or "",
                    phone_number=row[5] or "",
                    email_address=row[6] or "",
                    is_primary=bool(row[7]),
                    is_active=bool(row[8]),
                    created_at=datetime.fromisoformat(row[9]),
                    last_used=datetime.fromisoformat(row[10]) if row[10] else None,
                    use_count=row[11]
                )
                
                if device.user_id not in self.mfa_devices:
                    self.mfa_devices[device.user_id] = []
                self.mfa_devices[device.user_id].append(device)
            
            conn.close()
            
            logger.info(f"📱 Loaded {sum(len(devices) for devices in self.mfa_devices.values())} MFA devices")
            
        except Exception as e:
            logger.error(f"Failed to load MFA devices: {e}")
    
    async def register_totp_device(self, 
                                 user_id: str, 
                                 device_name: str,
                                 user_email: str) -> Dict[str, Any]:
        """Register new TOTP device"""
        try:
            # Generate secret
            secret = self.totp_manager.generate_secret()
            encrypted_secret = self.encryption_manager.encrypt_secret(secret)
            
            # Create device
            device = MFADevice(
                device_id=f"totp_{secrets.token_urlsafe(8)}",
                user_id=user_id,
                method_type=MFAMethodType.TOTP,
                device_name=device_name,
                secret_key=encrypted_secret,
                email_address=user_email
            )
            
            # Generate provisioning URI and QR code
            provisioning_uri = self.totp_manager.generate_provisioning_uri(secret, user_email)
            qr_code_bytes = self.totp_manager.generate_qr_code(provisioning_uri)
            qr_code_base64 = base64.b64encode(qr_code_bytes).decode()
            
            # Save to database
            await self._save_mfa_device(device)
            
            # Add to memory
            if user_id not in self.mfa_devices:
                self.mfa_devices[user_id] = []
            self.mfa_devices[user_id].append(device)
            
            logger.info(f"📱 TOTP device registered for user {user_id}")
            
            return {
                "status": "success",
                "device_id": device.device_id,
                "provisioning_uri": provisioning_uri,
                "qr_code": qr_code_base64,
                "secret": secret  # For manual entry
            }
            
        except Exception as e:
            logger.error(f"Failed to register TOTP device: {e}")
            return {"status": "error", "error": str(e)}
    
    async def register_sms_device(self, 
                                user_id: str, 
                                device_name: str,
                                phone_number: str) -> Dict[str, Any]:
        """Register new SMS device"""
        try:
            device = MFADevice(
                device_id=f"sms_{secrets.token_urlsafe(8)}",
                user_id=user_id,
                method_type=MFAMethodType.SMS,
                device_name=device_name,
                phone_number=phone_number
            )
            
            await self._save_mfa_device(device)
            
            if user_id not in self.mfa_devices:
                self.mfa_devices[user_id] = []
            self.mfa_devices[user_id].append(device)
            
            logger.info(f"📱 SMS device registered for user {user_id}")
            
            return {
                "status": "success",
                "device_id": device.device_id
            }
            
        except Exception as e:
            logger.error(f"Failed to register SMS device: {e}")
            return {"status": "error", "error": str(e)}
    
    async def register_email_device(self, 
                                   user_id: str, 
                                   device_name: str,
                                   email_address: str) -> Dict[str, Any]:
        """Register new email device"""
        try:
            device = MFADevice(
                device_id=f"email_{secrets.token_urlsafe(8)}",
                user_id=user_id,
                method_type=MFAMethodType.EMAIL,
                device_name=device_name,
                email_address=email_address
            )
            
            await self._save_mfa_device(device)
            
            if user_id not in self.mfa_devices:
                self.mfa_devices[user_id] = []
            self.mfa_devices[user_id].append(device)
            
            logger.info(f"📧 Email device registered for user {user_id}")
            
            return {
                "status": "success",
                "device_id": device.device_id
            }
            
        except Exception as e:
            logger.error(f"Failed to register email device: {e}")
            return {"status": "error", "error": str(e)}
    
    async def _save_mfa_device(self, device: MFADevice):
        """Save MFA device to database"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO mfa_devices 
                (device_id, user_id, method_type, device_name, secret_key, 
                 phone_number, email_address, is_primary, is_active, created_at, use_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                device.device_id, device.user_id, device.method_type.value, device.device_name,
                device.secret_key, device.phone_number, device.email_address,
                device.is_primary, device.is_active, device.created_at.isoformat(), device.use_count
            ))
            
            conn.commit()
            conn.close()
            
        except Exception as e:
            logger.error(f"Failed to save MFA device: {e}")
            raise
    
    async def initiate_authentication(self, 
                                    user_id: str, 
                                    device_id: str,
                                    ip_address: str = "",
                                    user_agent: str = "") -> Dict[str, Any]:
        """Initiate MFA authentication"""
        try:
            # Find device
            device = self._find_device(user_id, device_id)
            if not device:
                return {"status": "error", "error": "Device not found"}
            
            if not device.is_active:
                return {"status": "error", "error": "Device is inactive"}
            
            # Create authentication attempt
            attempt = AuthenticationAttempt(
                attempt_id=secrets.token_urlsafe(16),
                user_id=user_id,
                device_id=device_id,
                method_type=device.method_type,
                status=AuthenticationStatus.PENDING,
                ip_address=ip_address,
                user_agent=user_agent,
                expires_at=datetime.utcnow() + timedelta(minutes=5)
            )
            
            self.auth_attempts[attempt.attempt_id] = attempt
            
            # Handle different authentication methods
            if device.method_type == MFAMethodType.TOTP:
                return {
                    "status": "success",
                    "attempt_id": attempt.attempt_id,
                    "method": "totp",
                    "message": "Enter TOTP code from your authenticator app"
                }
            
            elif device.method_type == MFAMethodType.SMS:
                sms_result = await self.sms_manager.send_sms_code(
                    device.phone_number, user_id
                )
                if sms_result["status"] == "success":
                    attempt.verification_code = sms_result["verification_id"]
                    return {
                        "status": "success",
                        "attempt_id": attempt.attempt_id,
                        "method": "sms",
                        "message": f"SMS code sent to {device.phone_number[-4:]}"
                    }
                else:
                    return sms_result
            
            elif device.method_type == MFAMethodType.EMAIL:
                email_result = await self.email_manager.send_email_code(
                    device.email_address, user_id
                )
                if email_result["status"] == "success":
                    attempt.verification_code = email_result["verification_id"]
                    return {
                        "status": "success",
                        "attempt_id": attempt.attempt_id,
                        "method": "email",
                        "message": f"Verification code sent to {device.email_address}"
                    }
                else:
                    return email_result
            
            else:
                return {"status": "error", "error": "Unsupported authentication method"}
                
        except Exception as e:
            logger.error(f"Failed to initiate authentication: {e}")
            return {"status": "error", "error": str(e)}
    
    async def verify_authentication(self, 
                                  attempt_id: str, 
                                  verification_code: str) -> Dict[str, Any]:
        """Verify MFA authentication"""
        try:
            attempt = self.auth_attempts.get(attempt_id)
            if not attempt:
                return {"status": "error", "error": "Invalid attempt ID"}
            
            if attempt.is_expired():
                del self.auth_attempts[attempt_id]
                return {"status": "error", "error": "Authentication expired"}
            
            # Find device
            device = self._find_device(attempt.user_id, attempt.device_id)
            if not device:
                return {"status": "error", "error": "Device not found"}
            
            # Verify based on method
            verification_successful = False
            
            if device.method_type == MFAMethodType.TOTP:
                secret = self.encryption_manager.decrypt_secret(device.secret_key)
                verification_successful = self.totp_manager.verify_totp_code(secret, verification_code)
            
            elif device.method_type == MFAMethodType.SMS:
                verification_successful = self.sms_manager.verify_sms_code(
                    attempt.verification_code, verification_code
                )
            
            elif device.method_type == MFAMethodType.EMAIL:
                verification_successful = self.email_manager.verify_email_code(
                    attempt.verification_code, verification_code
                )
            
            # Update attempt status
            if verification_successful:
                attempt.status = AuthenticationStatus.VERIFIED
                
                # Update device usage
                device.last_used = datetime.utcnow()
                device.use_count += 1
                await self._update_device_usage(device)
                
                # Log successful authentication
                await self._log_auth_attempt(attempt)
                
                # Clean up
                del self.auth_attempts[attempt_id]
                
                logger.info(f"✅ MFA authentication successful for user {attempt.user_id}")
                
                return {
                    "status": "success",
                    "message": "Authentication verified",
                    "user_id": attempt.user_id,
                    "device_id": attempt.device_id,
                    "method": device.method_type.value
                }
            
            else:
                attempt.status = AuthenticationStatus.FAILED
                await self._log_auth_attempt(attempt)
                
                logger.warning(f"❌ MFA authentication failed for user {attempt.user_id}")
                
                return {
                    "status": "error",
                    "error": "Invalid verification code"
                }
                
        except Exception as e:
            logger.error(f"Failed to verify authentication: {e}")
            return {"status": "error", "error": str(e)}
    
    def _find_device(self, user_id: str, device_id: str) -> Optional[MFADevice]:
        """Find MFA device by user and device ID"""
        user_devices = self.mfa_devices.get(user_id, [])
        for device in user_devices:
            if device.device_id == device_id:
                return device
        return None
    
    async def _update_device_usage(self, device: MFADevice):
        """Update device usage statistics"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                UPDATE mfa_devices 
                SET last_used = ?, use_count = ?
                WHERE device_id = ?
            ''', (device.last_used.isoformat(), device.use_count, device.device_id))
            
            conn.commit()
            conn.close()
            
        except Exception as e:
            logger.error(f"Failed to update device usage: {e}")
    
    async def _log_auth_attempt(self, attempt: AuthenticationAttempt):
        """Log authentication attempt"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO auth_attempts 
                (attempt_id, user_id, device_id, method_type, status, 
                 ip_address, user_agent, location, timestamp, expires_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                attempt.attempt_id, attempt.user_id, attempt.device_id,
                attempt.method_type.value, attempt.status.value,
                attempt.ip_address, attempt.user_agent, attempt.location,
                attempt.timestamp.isoformat(),
                attempt.expires_at.isoformat() if attempt.expires_at else None
            ))
            
            conn.commit()
            conn.close()
            
        except Exception as e:
            logger.error(f"Failed to log auth attempt: {e}")
    
    async def get_user_devices(self, user_id: str) -> List[Dict[str, Any]]:
        """Get all MFA devices for user"""
        user_devices = self.mfa_devices.get(user_id, [])
        return [device.to_dict() for device in user_devices if device.is_active]
    
    async def deactivate_device(self, user_id: str, device_id: str) -> Dict[str, Any]:
        """Deactivate MFA device"""
        try:
            device = self._find_device(user_id, device_id)
            if not device:
                return {"status": "error", "error": "Device not found"}
            
            device.is_active = False
            
            # Update database
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cursor.execute(
                "UPDATE mfa_devices SET is_active = FALSE WHERE device_id = ?",
                (device_id,)
            )
            conn.commit()
            conn.close()
            
            logger.info(f"📱 Device deactivated: {device_id}")
            
            return {"status": "success", "message": "Device deactivated"}
            
        except Exception as e:
            logger.error(f"Failed to deactivate device: {e}")
            return {"status": "error", "error": str(e)}
    
    async def generate_backup_codes(self, user_id: str) -> Dict[str, Any]:
        """Generate backup recovery codes"""
        try:
            codes = self.encryption_manager.generate_backup_codes()
            
            # Hash and store codes
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            for code in codes:
                code_id = secrets.token_urlsafe(8)
                code_hash = hashlib.sha256(code.encode()).hexdigest()
                
                cursor.execute('''
                    INSERT INTO backup_codes (code_id, user_id, code_hash, created_at)
                    VALUES (?, ?, ?, ?)
                ''', (code_id, user_id, code_hash, datetime.utcnow().isoformat()))
            
            conn.commit()
            conn.close()
            
            logger.info(f"🔑 Generated {len(codes)} backup codes for user {user_id}")
            
            return {
                "status": "success",
                "backup_codes": codes,
                "message": "Save these codes in a secure location"
            }
            
        except Exception as e:
            logger.error(f"Failed to generate backup codes: {e}")
            return {"status": "error", "error": str(e)}
    
    def get_mfa_statistics(self) -> Dict[str, Any]:
        """Get MFA usage statistics"""
        try:
            total_devices = sum(len(devices) for devices in self.mfa_devices.values())
            total_users = len(self.mfa_devices)
            
            method_counts = {}
            for devices in self.mfa_devices.values():
                for device in devices:
                    if device.is_active:
                        method = device.method_type.value
                        method_counts[method] = method_counts.get(method, 0) + 1
            
            return {
                "total_users": total_users,
                "total_devices": total_devices,
                "method_distribution": method_counts,
                "timestamp": datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Failed to get MFA statistics: {e}")
            return {"error": str(e)}


# Global MFA manager instance
enhanced_mfa_manager = EnhancedMFAManager()


async def setup_enterprise_mfa() -> Dict[str, Any]:
    """Setup enterprise MFA system"""
    print("🔐 Microsoft 365 Enhanced MFA System - CTO継続技術監督")
    print("Setting up enterprise multi-factor authentication...")
    
    try:
        # Test MFA system
        test_user_id = "test_user_001"
        
        # Register TOTP device
        totp_result = await enhanced_mfa_manager.register_totp_device(
            test_user_id, "Test Authenticator", "test@company.com"
        )
        print(f"TOTP Registration: {totp_result['status']}")
        
        # Register SMS device
        sms_result = await enhanced_mfa_manager.register_sms_device(
            test_user_id, "Test Phone", "+1234567890"
        )
        print(f"SMS Registration: {sms_result['status']}")
        
        # Get statistics
        stats = enhanced_mfa_manager.get_mfa_statistics()
        print(f"MFA Statistics: {stats}")
        
        return {
            "status": "success",
            "totp_setup": totp_result,
            "sms_setup": sms_result,
            "statistics": stats
        }
        
    except Exception as e:
        print(f"❌ MFA setup error: {e}")
        return {"status": "error", "error": str(e)}


if __name__ == "__main__":
    asyncio.run(setup_enterprise_mfa())