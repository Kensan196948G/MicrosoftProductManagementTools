"""Microsoft Teams API integration module."""

from .client import TeamsClient
from .services import TeamsService

__all__ = ['TeamsClient', 'TeamsService']
