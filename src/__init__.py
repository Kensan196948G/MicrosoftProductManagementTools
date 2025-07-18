"""
Microsoft365 Management Tools - Python Edition
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

エンタープライズ向けMicrosoft 365統合管理ツール

PowerShellからPythonへの段階的移行版
既存26機能の完全互換性を保持しつつ、モダンなアーキテクチャで再構築

:copyright: (c) 2025 Development Team.
:license: MIT, see LICENSE for more details.
"""

__version__ = "2.0.0"
__author__ = "Development Team"
__email__ = "dev@example.com"

# Version info
VERSION_INFO = {
    "major": 2,
    "minor": 0,
    "patch": 0,
    "release": "beta",
    "build": "20250118"
}

def get_version():
    """Get the full version string."""
    version = f"{VERSION_INFO['major']}.{VERSION_INFO['minor']}.{VERSION_INFO['patch']}"
    if VERSION_INFO['release'] != 'stable':
        version += f"-{VERSION_INFO['release']}"
    return version