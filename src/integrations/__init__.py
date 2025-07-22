"""
Microsoft 365管理ツール 統合モジュール
===================================

外部サービス統合
"""

from .microsoft_graph import MicrosoftGraphIntegration
from .exchange_online import ExchangeOnlineIntegration

__all__ = [
    'MicrosoftGraphIntegration',
    'ExchangeOnlineIntegration'
]