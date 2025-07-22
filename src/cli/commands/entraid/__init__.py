# Entra ID Commands Package
# Microsoft 365 管理ツール - Entra ID管理コマンド群

import click

from .users import users_command
from .mfa import mfa_command
from .conditional import conditional_command
from .signin import signin_command

@click.group()
def entraid_group():
    """👥 Entra ID管理 - ユーザー・MFA・条件付きアクセス・サインインログ"""
    pass

# Register commands
entraid_group.add_command(users_command, name='users')
entraid_group.add_command(mfa_command, name='mfa')
entraid_group.add_command(conditional_command, name='conditional')
entraid_group.add_command(signin_command, name='signin')

__all__ = [
    'entraid_group',
    'users_command',
    'mfa_command',
    'conditional_command',
    'signin_command'
]