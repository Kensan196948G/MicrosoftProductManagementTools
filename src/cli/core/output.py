# Microsoft 365 Management Tools - CLI Output Formatter
# PowerShell Enhanced CLI compatible output formatting

import csv
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Union
from io import StringIO

import click
from jinja2 import Template

class OutputFormatter:
    """CLI Output Formatter - PowerShell Enhanced CLI Compatible"""
    
    def __init__(self, context):
        self.context = context
        self.output_path = Path(context.output_path) if context.output_path else Path("Reports")
        self.templates_path = Path(__file__).parent.parent / "templates"
    
    async def output_results(self, data: List[Dict[str, Any]], 
                           report_type: str,
                           filename_prefix: str = None) -> Dict[str, str]:
        """Output results in requested formats"""
        
        if not data:
            click.echo("⚠️ 結果データがありません")
            return {}
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        if not filename_prefix:
            filename_prefix = report_type.lower().replace(" ", "_")
        
        output_files = {}
        
        # Always output to console in table format (unless batch mode)
        if not self.context.batch_mode:
            self._output_table(data, report_type)
        
        # CSV output
        if self.context.should_output_format('csv'):
            csv_file = f"{filename_prefix}_{timestamp}.csv"
            csv_path = self.output_path / csv_file
            self._output_csv(data, csv_path)
            output_files['csv'] = str(csv_path)
            
            if not self.context.batch_mode:
                click.echo(f"📄 CSV出力: {csv_path}")
        
        # HTML output
        if self.context.should_output_format('html'):
            html_file = f"{filename_prefix}_{timestamp}.html"
            html_path = self.output_path / html_file
            self._output_html(data, html_path, report_type)
            output_files['html'] = str(html_path)
            
            if not self.context.batch_mode:
                click.echo(f"🌐 HTML出力: {html_path}")
        
        # JSON output
        if self.context.should_output_format('json'):
            json_file = f"{filename_prefix}_{timestamp}.json"
            json_path = self.output_path / json_file
            self._output_json(data, json_path, report_type)
            output_files['json'] = str(json_path)
            
            if not self.context.batch_mode:
                click.echo(f"📋 JSON出力: {json_path}")
        
        # PowerShell compatible auto-open behavior
        if self.context.config and self.context.config.get('Output.AutoOpenFiles', False):
            await self._auto_open_files(output_files)
        
        return output_files
    
    def _output_table(self, data: List[Dict[str, Any]], title: str):
        """Output data as formatted table to console"""
        
        if not data:
            return
        
        click.echo(f"\\n📊 {title}")
        click.echo("=" * (len(title) + 4))
        
        # Get column headers
        headers = list(data[0].keys()) if data else []
        if not headers:
            return
        
        # Calculate column widths
        widths = {}
        for header in headers:
            widths[header] = len(header)
            for row in data:
                value = str(row.get(header, ''))
                widths[header] = max(widths[header], len(value))
        
        # Limit column width for better display
        max_width = 50
        for header in headers:
            widths[header] = min(widths[header], max_width)
        
        # Output header
        header_row = " | ".join(header.ljust(widths[header]) for header in headers)
        click.echo(header_row)
        click.echo("-" * len(header_row))
        
        # Output data rows
        for i, row in enumerate(data):
            if i >= 20:  # Limit console output to 20 rows
                remaining = len(data) - 20
                click.echo(f"... (+{remaining} more rows)")
                break
            
            values = []
            for header in headers:
                value = str(row.get(header, ''))
                if len(value) > widths[header]:
                    value = value[:widths[header]-3] + "..."
                values.append(value.ljust(widths[header]))
            
            row_str = " | ".join(values)
            click.echo(row_str)
        
        click.echo(f"\\n📋 合計: {len(data)} 件")
    
    def _output_csv(self, data: List[Dict[str, Any]], file_path: Path):
        """Output data as CSV (PowerShell compatible UTF-8 BOM)"""
        
        if not data:
            return
        
        # Ensure directory exists
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Use UTF-8 BOM encoding for PowerShell compatibility
        with open(file_path, 'w', newline='', encoding='utf-8-sig') as csvfile:
            if data:
                fieldnames = data[0].keys()
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writeheader()
                
                for row in data:
                    # Convert all values to strings and handle None
                    clean_row = {}
                    for key, value in row.items():
                        if value is None:
                            clean_row[key] = ""
                        elif isinstance(value, datetime):
                            clean_row[key] = value.strftime("%Y-%m-%d %H:%M:%S")
                        else:
                            clean_row[key] = str(value)
                    
                    writer.writerow(clean_row)
    
    def _output_json(self, data: List[Dict[str, Any]], file_path: Path, title: str):
        """Output data as JSON"""
        
        # Ensure directory exists
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        output_data = {
            "report_type": title,
            "generated_at": datetime.now().isoformat(),
            "total_records": len(data),
            "data": data
        }
        
        with open(file_path, 'w', encoding='utf-8') as jsonfile:
            json.dump(output_data, jsonfile, indent=2, ensure_ascii=False, default=str)
    
    def _output_html(self, data: List[Dict[str, Any]], file_path: Path, title: str):
        """Output data as HTML (PowerShell compatible responsive design)"""
        
        # Ensure directory exists
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        # HTML template (PowerShell Enhanced CLI compatible)
        html_template = Template(\"\"\"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ title }} - Microsoft 365 Management Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2em;
            font-weight: 300;
        }
        .summary {
            padding: 20px 30px;
            background: #f8f9fa;
            border-bottom: 1px solid #e9ecef;
        }
        .stats {
            display: flex;
            justify-content: space-around;
            flex-wrap: wrap;
            gap: 20px;
        }
        .stat-item {
            text-align: center;
            flex: 1;
            min-width: 120px;
        }
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #0078d4;
            margin-bottom: 5px;
        }
        .stat-label {
            color: #666;
            font-size: 0.9em;
        }
        .table-container {
            padding: 30px;
            overflow-x: auto;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th {
            background: #f8f9fa;
            color: #333;
            font-weight: 600;
            padding: 12px 8px;
            text-align: left;
            border-bottom: 2px solid #dee2e6;
            position: sticky;
            top: 0;
        }
        td {
            padding: 8px;
            border-bottom: 1px solid #e9ecef;
        }
        tr:hover {
            background-color: #f8f9fa;
        }
        .footer {
            background: #f8f9fa;
            padding: 20px 30px;
            text-align: center;
            color: #666;
            font-size: 0.9em;
            border-top: 1px solid #e9ecef;
        }
        @media (max-width: 768px) {
            .stats {
                flex-direction: column;
            }
            .table-container {
                padding: 15px;
            }
            table {
                font-size: 0.9em;
            }
            th, td {
                padding: 6px 4px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 {{ title }}</h1>
            <p>Microsoft 365統合管理ツール - Python CLI版</p>
        </div>
        
        <div class="summary">
            <div class="stats">
                <div class="stat-item">
                    <div class="stat-number">{{ total_records }}</div>
                    <div class="stat-label">総レコード数</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number">{{ column_count }}</div>
                    <div class="stat-label">列数</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number">{{ generated_time }}</div>
                    <div class="stat-label">生成時刻</div>
                </div>
            </div>
        </div>
        
        {% if data %}
        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        {% for header in headers %}
                        <th>{{ header }}</th>
                        {% endfor %}
                    </tr>
                </thead>
                <tbody>
                    {% for row in data %}
                    <tr>
                        {% for header in headers %}
                        <td>{{ row.get(header, '') }}</td>
                        {% endfor %}
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
        {% else %}
        <div class="table-container">
            <p>データがありません。</p>
        </div>
        {% endif %}
        
        <div class="footer">
            <p>Generated by Microsoft 365 Management Tools CLI v3.0.0 | {{ generation_time }}</p>
            <p>PowerShell Enhanced CLI Compatible</p>
        </div>
    </div>
</body>
</html>
        \"\"\")
        
        # Prepare template data
        headers = list(data[0].keys()) if data else []
        template_data = {
            'title': title,
            'data': data,
            'headers': headers,
            'total_records': len(data),
            'column_count': len(headers),
            'generated_time': datetime.now().strftime("%H:%M:%S"),
            'generation_time': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # Render and save HTML
        html_content = html_template.render(**template_data)
        
        with open(file_path, 'w', encoding='utf-8') as htmlfile:
            htmlfile.write(html_content)
    
    async def _auto_open_files(self, output_files: Dict[str, str]):
        """Auto-open generated files (PowerShell compatible behavior)"""
        
        if self.context.batch_mode:
            return  # Skip auto-open in batch mode
        
        try:
            # Open HTML file first (preferred), then CSV
            if 'html' in output_files:
                await self._open_file(output_files['html'])
            elif 'csv' in output_files:
                await self._open_file(output_files['csv'])
        except Exception as e:
            click.echo(f"ファイルを開けませんでした: {e}")
    
    async def _open_file(self, file_path: str):
        """Open file with default application"""
        
        try:
            if sys.platform.startswith('win'):
                # Windows
                os.startfile(file_path)
            elif sys.platform.startswith('darwin'):
                # macOS
                subprocess.run(['open', file_path])
            else:
                # Linux
                subprocess.run(['xdg-open', file_path])
        except Exception as e:
            click.echo(f"ファイルを開けませんでした ({file_path}): {e}")
    
    def output_error(self, error: str, details: str = None):
        """Output error message"""
        click.echo(f"❌ エラー: {error}", err=True)
        if details and self.context.verbose:
            click.echo(f"詳細: {details}", err=True)
    
    def output_warning(self, warning: str):
        """Output warning message"""
        click.echo(f"⚠️ 警告: {warning}")
    
    def output_success(self, message: str):
        """Output success message"""
        click.echo(f"✅ {message}")
    
    def output_info(self, message: str):
        """Output info message"""
        if self.context.verbose or not self.context.batch_mode:
            click.echo(f"ℹ️ {message}")
    
    def output_progress(self, message: str, current: int = None, total: int = None):
        """Output progress message"""
        if self.context.batch_mode:
            return
        
        if current is not None and total is not None:
            percentage = (current / total) * 100
            click.echo(f"⏳ {message} ({current}/{total} - {percentage:.1f}%)")
        else:
            click.echo(f"⏳ {message}")
    
    def confirm_action(self, message: str) -> bool:
        """Confirm action with user (skip in batch mode)"""
        if self.context.batch_mode:
            return True
        
        return click.confirm(message)
    
    def prompt_for_input(self, message: str, default: str = None) -> str:
        """Prompt for user input (use default in batch mode)"""
        if self.context.batch_mode:
            return default or ""
        
        return click.prompt(message, default=default)
    
    def select_from_options(self, message: str, options: List[str], default: int = 0) -> str:
        """Select from options (use default in batch mode)"""
        if self.context.batch_mode:
            return options[default] if options else ""
        
        click.echo(message)
        for i, option in enumerate(options):
            click.echo(f"  {i + 1}. {option}")
        
        while True:
            try:
                choice = click.prompt("選択してください", type=int, default=default + 1)
                if 1 <= choice <= len(options):
                    return options[choice - 1]
                else:
                    click.echo("無効な選択です")
            except click.Abort:
                return options[default] if options else ""