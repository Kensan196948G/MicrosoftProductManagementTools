# Exchange Online Commands Package
# Microsoft 365 管理ツール - Exchange Online管理コマンド群

import click

from .mailbox import mailbox_command
from .mailflow import mailflow_command
from .spam import spam_command
from .delivery import delivery_command

@click.group()
def exchange_group():
    """📧 Exchange Online管理 - メールボックス・メールフロー・スパム対策・配信分析"""
    pass

# Register commands
exchange_group.add_command(mailbox_command, name='mailbox')
exchange_group.add_command(mailflow_command, name='mailflow')
exchange_group.add_command(spam_command, name='spam')
exchange_group.add_command(delivery_command, name='delivery')

__all__ = [
    'exchange_group',
    'mailbox_command',
    'mailflow_command',
    'spam_command',
    'delivery_command'
]