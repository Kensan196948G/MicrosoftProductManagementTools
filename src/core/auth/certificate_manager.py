"""
Certificate management utilities for authentication.
Handles loading certificates from files, stores, and conversion.
"""

import logging
import platform
from pathlib import Path
from typing import Dict, Any, Optional, Union
import base64
import hashlib

from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID


class CertificateManager:
    """Manages certificates for authentication."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.is_windows = platform.system() == "Windows"
    
    def load_certificate_from_file(self, cert_path: Path, 
                                  password: Optional[str] = None) -> Dict[str, Any]:
        """
        Load certificate from file (.pfx, .p12, .pem, .crt).
        
        Returns:
            Dict containing private_key, certificate, thumbprint
        """
        if not cert_path.exists():
            raise FileNotFoundError(f"証明書ファイルが見つかりません: {cert_path}")
        
        cert_data = cert_path.read_bytes()
        file_ext = cert_path.suffix.lower()
        
        if file_ext in ['.pfx', '.p12']:
            return self._load_pfx(cert_data, password)
        elif file_ext in ['.pem', '.crt', '.cer']:
            return self._load_pem(cert_data, password)
        else:
            # Try to detect format
            try:
                return self._load_pfx(cert_data, password)
            except Exception:
                return self._load_pem(cert_data, password)
    
    def load_certificate_from_bytes(self, cert_data: bytes,
                                   password: Optional[str] = None) -> Dict[str, Any]:
        """Load certificate from bytes."""
        # Try PFX first, then PEM
        try:
            return self._load_pfx(cert_data, password)
        except Exception:
            return self._load_pem(cert_data, password)
    
    def load_certificate_from_store(self, thumbprint: str) -> Dict[str, Any]:
        """
        Load certificate from Windows certificate store.
        Only available on Windows.
        """
        if not self.is_windows:
            raise NotImplementedError("証明書ストアはWindowsでのみ利用可能です")
        
        try:
            import wincertstore
        except ImportError:
            raise ImportError("wincertstoreが必要です: pip install wincertstore")
        
        # Clean thumbprint
        thumbprint = thumbprint.replace(' ', '').replace(':', '').upper()
        
        # Search in MY store (personal certificates)
        with wincertstore.CertSystemStore("MY") as store:
            for cert in store.itercerts(usage=wincertstore.SERVER_AUTH):
                cert_thumbprint = cert.get_thumbprint().hex().upper()
                if cert_thumbprint == thumbprint:
                    pem_data = cert.get_pem()
                    # Note: Private key extraction from store is complex
                    # and may require additional Windows APIs
                    return self._load_pem(pem_data.encode(), None)
        
        raise ValueError(f"証明書が見つかりません: {thumbprint}")
    
    def _load_pfx(self, pfx_data: bytes, password: Optional[str]) -> Dict[str, Any]:
        """Load PFX/P12 certificate."""
        try:
            # Convert password to bytes if needed
            pwd_bytes = password.encode('utf-8') if password else None
            
            # Load PFX
            private_key, certificate, additional_certs = pkcs12.load_key_and_certificates(
                pfx_data,
                pwd_bytes,
                backend=default_backend()
            )
            
            if not private_key or not certificate:
                raise ValueError("証明書またはプライベートキーが見つかりません")
            
            # Get certificate info
            cert_info = self._extract_cert_info(certificate)
            
            # Serialize private key
            private_key_pem = private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption()
            ).decode('utf-8')
            
            # Serialize certificate
            cert_pem = certificate.public_bytes(
                encoding=serialization.Encoding.PEM
            ).decode('utf-8')
            
            return {
                'private_key': private_key_pem,
                'certificate': cert_pem,
                'public_certificate': cert_pem,  # For compatibility
                'thumbprint': cert_info['thumbprint'],
                'subject': cert_info['subject'],
                'issuer': cert_info['issuer'],
                'serial_number': cert_info['serial_number'],
                'not_valid_before': cert_info['not_valid_before'],
                'not_valid_after': cert_info['not_valid_after']
            }
            
        except Exception as e:
            raise ValueError(f"PFX証明書の読み込みに失敗しました: {e}")
    
    def _load_pem(self, pem_data: bytes, password: Optional[str]) -> Dict[str, Any]:
        """Load PEM certificate and key."""
        try:
            # Try to load certificate
            cert = None
            private_key = None
            
            # PEM data might contain both cert and key
            pem_str = pem_data.decode('utf-8')
            
            # Extract certificate
            if 'BEGIN CERTIFICATE' in pem_str:
                cert_start = pem_str.index('-----BEGIN CERTIFICATE-----')
                cert_end = pem_str.index('-----END CERTIFICATE-----') + len('-----END CERTIFICATE-----')
                cert_pem = pem_str[cert_start:cert_end]
                cert = x509.load_pem_x509_certificate(
                    cert_pem.encode('utf-8'),
                    backend=default_backend()
                )
            
            # Extract private key
            if 'BEGIN PRIVATE KEY' in pem_str or 'BEGIN RSA PRIVATE KEY' in pem_str:
                pwd_bytes = password.encode('utf-8') if password else None
                private_key = serialization.load_pem_private_key(
                    pem_data,
                    password=pwd_bytes,
                    backend=default_backend()
                )
            
            if not cert:
                raise ValueError("証明書が見つかりません")
            
            # Get certificate info
            cert_info = self._extract_cert_info(cert)
            
            result = {
                'certificate': cert.public_bytes(
                    encoding=serialization.Encoding.PEM
                ).decode('utf-8'),
                'thumbprint': cert_info['thumbprint'],
                'subject': cert_info['subject'],
                'issuer': cert_info['issuer'],
                'serial_number': cert_info['serial_number'],
                'not_valid_before': cert_info['not_valid_before'],
                'not_valid_after': cert_info['not_valid_after']
            }
            
            if private_key:
                result['private_key'] = private_key.private_bytes(
                    encoding=serialization.Encoding.PEM,
                    format=serialization.PrivateFormat.PKCS8,
                    encryption_algorithm=serialization.NoEncryption()
                ).decode('utf-8')
            
            return result
            
        except Exception as e:
            raise ValueError(f"PEM証明書の読み込みに失敗しました: {e}")
    
    def _extract_cert_info(self, certificate: x509.Certificate) -> Dict[str, Any]:
        """Extract information from certificate."""
        # Calculate thumbprint (SHA1 hash of DER encoding)
        der_bytes = certificate.public_bytes(serialization.Encoding.DER)
        thumbprint = hashlib.sha1(der_bytes).hexdigest().upper()
        
        # Get subject and issuer
        subject = certificate.subject
        issuer = certificate.issuer
        
        def get_name_attribute(name, oid):
            try:
                return name.get_attributes_for_oid(oid)[0].value
            except (IndexError, Exception):
                return None
        
        return {
            'thumbprint': thumbprint,
            'subject': {
                'common_name': get_name_attribute(subject, NameOID.COMMON_NAME),
                'organization': get_name_attribute(subject, NameOID.ORGANIZATION_NAME),
                'country': get_name_attribute(subject, NameOID.COUNTRY_NAME),
            },
            'issuer': {
                'common_name': get_name_attribute(issuer, NameOID.COMMON_NAME),
                'organization': get_name_attribute(issuer, NameOID.ORGANIZATION_NAME),
                'country': get_name_attribute(issuer, NameOID.COUNTRY_NAME),
            },
            'serial_number': str(certificate.serial_number),
            'not_valid_before': certificate.not_valid_before,
            'not_valid_after': certificate.not_valid_after,
            'version': certificate.version.name,
            'signature_algorithm': certificate.signature_algorithm_oid._name
        }
    
    def validate_certificate(self, cert_path: Path, password: Optional[str] = None) -> bool:
        """Validate certificate is valid and not expired."""
        try:
            cert_data = self.load_certificate_from_file(cert_path, password)
            
            # Check expiration
            from datetime import datetime
            now = datetime.utcnow()
            
            not_before = cert_data['not_valid_before']
            not_after = cert_data['not_valid_after']
            
            if now < not_before:
                self.logger.warning(f"証明書はまだ有効ではありません: {not_before}")
                return False
            
            if now > not_after:
                self.logger.warning(f"証明書は期限切れです: {not_after}")
                return False
            
            return True
            
        except Exception as e:
            self.logger.error(f"証明書の検証に失敗しました: {e}")
            return False
    
    def get_certificate_info(self, cert_path: Path, 
                           password: Optional[str] = None) -> Dict[str, Any]:
        """Get detailed certificate information."""
        cert_data = self.load_certificate_from_file(cert_path, password)
        
        # Remove sensitive data
        info = {k: v for k, v in cert_data.items() if k != 'private_key'}
        
        # Add additional info
        from datetime import datetime
        now = datetime.utcnow()
        expires_in = (cert_data['not_valid_after'] - now).days
        
        info['is_valid'] = self.validate_certificate(cert_path, password)
        info['expires_in_days'] = expires_in
        
        return info