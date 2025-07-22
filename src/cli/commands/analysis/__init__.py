# Analysis Commands Package
# Microsoft 365 管理ツール - 分析レポートコマンド群

import click

from .license import license_command
from .usage import usage_command
from .performance import performance_command
from .security import security_command
from .permission import permission_command

@click.group()
def analysis_group():
    """🔍 分析レポート - ライセンス・使用状況・パフォーマンス・セキュリティ・権限監査"""
    pass

# Register commands
analysis_group.add_command(license_command, name='license')
analysis_group.add_command(usage_command, name='usage')
analysis_group.add_command(performance_command, name='performance')
analysis_group.add_command(security_command, name='security')
analysis_group.add_command(permission_command, name='permission')

__all__ = [
    'analysis_group',
    'license_command',
    'usage_command', 
    'performance_command',
    'security_command',
    'permission_command'
]