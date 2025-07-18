"""
Authentication module for Microsoft 365 services.
Provides unified authentication for Graph API, Exchange Online, and other services.
"""

from .authenticator import Authenticator, AuthenticationMethod, AuthenticationResult
from .graph_auth import GraphAuthenticator
from .exchange_auth import ExchangeAuthenticator
from .certificate_manager import CertificateManager

__all__ = [
    'Authenticator',
    'AuthenticationMethod',
    'AuthenticationResult',
    'GraphAuthenticator',
    'ExchangeAuthenticator',
    'CertificateManager'
]