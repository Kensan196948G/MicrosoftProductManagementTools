# Microsoft 365 Management Tools - Python CLI Main Entry Point
# Enterprise-grade CLI with PowerShell compatibility

import click
import sys
import os
import asyncio
from pathlib import Path
from typing import Optional, Dict, Any

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from src.cli.core.app import M365CLI
from src.cli.core.context import CLIContext
from src.cli.core.config import CLIConfig
from src.core.logging_config import setup_logging

# Configure CLI logging
setup_logging(
    log_level=os.getenv('CLI_LOG_LEVEL', 'INFO'),
    log_dir=os.getenv('CLI_LOG_DIR', 'Logs/CLI'),
    console=True,
    file=True
)

@click.group(invoke_without_command=True)
@click.option('--config', '-c', type=click.Path(exists=True), help='設定ファイルパス')
@click.option('--verbose', '-v', is_flag=True, help='詳細出力モード')
@click.option('--dry-run', is_flag=True, help='ドライラン実行（実際の操作なし）')
@click.option('--batch', is_flag=True, help='バッチモード（非対話実行）')
@click.option('--output-csv', is_flag=True, help='CSV形式で出力')
@click.option('--output-html', is_flag=True, help='HTML形式で出力')
@click.option('--output-json', is_flag=True, help='JSON形式で出力')
@click.option('--output-path', type=click.Path(), help='出力ディレクトリパス')
@click.option('--max-results', type=int, default=1000, help='最大結果数')
@click.option('--no-connect', is_flag=True, help='Microsoft 365接続をスキップ')
@click.option('--tenant-id', help='Azure テナントID')
@click.option('--client-id', help='アプリケーション（クライアント）ID')
@click.version_option(version='3.0.0', prog_name='Microsoft 365 Management CLI')
@click.pass_context
def cli(ctx, config, verbose, dry_run, batch, output_csv, output_html, output_json,
        output_path, max_results, no_connect, tenant_id, client_id):
    """
    🚀 Microsoft 365統合管理ツール - Python CLI
    
    PowerShell Enhanced CLI完全互換 + エンタープライズ機能
    26機能完全対応・クロスプラットフォーム対応
    """
    
    # Initialize CLI context
    ctx.ensure_object(CLIContext)
    
    # Configure CLI context
    ctx.obj.configure(
        config_file=config,
        verbose=verbose,
        dry_run=dry_run,
        batch_mode=batch,
        output_formats={
            'csv': output_csv,
            'html': output_html,
            'json': output_json
        },
        output_path=output_path,
        max_results=max_results,
        no_connect=no_connect,
        tenant_id=tenant_id,
        client_id=client_id
    )
    
    # If no command specified, show interactive menu (PowerShell compatible)
    if ctx.invoked_subcommand is None:
        if batch:
            click.echo("エラー: バッチモードではコマンドを指定してください")
            click.echo("使用方法: ms365 --help")
            sys.exit(1)
        else:
            # Start interactive menu (PowerShell Enhanced CLI compatible)
            cli_app = M365CLI(ctx.obj)
            asyncio.run(cli_app.run_interactive_menu())

# Import and register command groups
from src.cli.commands.reports import reports_group
from src.cli.commands.analysis import analysis_group
from src.cli.commands.entraid import entraid_group
from src.cli.commands.exchange import exchange_group
from src.cli.commands.teams import teams_group
from src.cli.commands.onedrive import onedrive_group

# Register command groups
cli.add_command(reports_group, name='reports')
cli.add_command(analysis_group, name='analysis')
cli.add_command(entraid_group, name='entraid')
cli.add_command(exchange_group, name='exchange')
cli.add_command(teams_group, name='teams')
cli.add_command(onedrive_group, name='onedrive')

# PowerShell compatibility aliases
@cli.group(name='powershell', hidden=True, invoke_without_command=True)
@click.argument('action', required=True)
@click.option('--batch', is_flag=True)
@click.option('--output-csv', is_flag=True)
@click.option('--output-html', is_flag=True)
@click.option('--output-path', type=click.Path())
@click.option('--max-results', type=int, default=1000)
@click.option('--no-connect', is_flag=True)
@click.pass_context
def powershell_compat(ctx, action, **kwargs):
    """PowerShell Enhanced CLI 完全互換コマンド"""
    
    # Map PowerShell actions to Click commands
    command_map = {
        'daily': 'reports daily',
        'weekly': 'reports weekly', 
        'monthly': 'reports monthly',
        'yearly': 'reports yearly',
        'test': 'reports test',
        'license': 'analysis license',
        'usage': 'analysis usage',
        'performance': 'analysis performance',
        'security': 'analysis security',
        'permission': 'analysis permission',
        'users': 'entraid users',
        'mfa': 'entraid mfa',
        'conditional': 'entraid conditional',
        'signin': 'entraid signin',
        'mailbox': 'exchange mailbox',
        'mailflow': 'exchange mailflow',
        'spam': 'exchange spam',
        'delivery': 'exchange delivery',
        'teams': 'teams usage',
        'teamssettings': 'teams settings',
        'meetings': 'teams meetings',
        'teamsapps': 'teams apps',
        'storage': 'onedrive storage',
        'sharing': 'onedrive sharing',
        'syncerror': 'onedrive syncerror',
        'external': 'onedrive external'
    }
    
    if action in command_map:
        # Execute mapped command
        mapped_cmd = command_map[action].split()
        ctx.invoke(cli, mapped_cmd, **kwargs)
    else:
        click.echo(f"エラー: 不明なアクション '{action}'")
        click.echo("使用可能なアクション: " + ", ".join(command_map.keys()))
        sys.exit(1)

if __name__ == '__main__':
    cli()