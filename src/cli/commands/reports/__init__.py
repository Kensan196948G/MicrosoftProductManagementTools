# Microsoft 365 Management Tools - Regular Reports Commands
# 定期レポートコマンド群 (5機能) - PowerShell Enhanced CLI Compatible

import click
from .daily import daily_command
from .weekly import weekly_command
from .monthly import monthly_command
from .yearly import yearly_command
from .test import test_command

@click.group(name='reports')
def reports_group():
    """📊 定期レポート管理 (5機能) - PowerShell Enhanced CLI Compatible"""
    pass

# Add commands to group
reports_group.add_command(daily_command, name='daily')
reports_group.add_command(weekly_command, name='weekly')
reports_group.add_command(monthly_command, name='monthly')
reports_group.add_command(yearly_command, name='yearly')
reports_group.add_command(test_command, name='test')

__all__ = ['reports_group']