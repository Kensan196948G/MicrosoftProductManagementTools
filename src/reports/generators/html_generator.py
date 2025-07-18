"""HTML report generator."""

import logging
from typing import List, Dict, Any
from pathlib import Path
from datetime import datetime
import html


class HTMLGenerator:
    """HTML report generator with responsive design."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def generate(self, data: List[Dict[str, Any]], output_path: str, 
                 report_title: str = "Microsoft 365 レポート") -> bool:
        """
        Generate HTML report from data.
        
        Args:
            data: List of dictionaries containing report data
            output_path: Path to save the HTML file
            report_title: Title for the report
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if not data:
                self.logger.warning("No data provided for HTML generation")
                return False
            
            # Ensure output directory exists
            Path(output_path).parent.mkdir(parents=True, exist_ok=True)
            
            html_content = self._generate_html_content(data, report_title)
            
            with open(output_path, 'w', encoding='utf-8') as htmlfile:
                htmlfile.write(html_content)
            
            self.logger.info(f"HTML report generated successfully: {output_path}")
            self.logger.info(f"Records included: {len(data)}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to generate HTML report: {e}")
            return False
    
    def _generate_html_content(self, data: List[Dict[str, Any]], title: str) -> str:
        """Generate complete HTML content."""
        
        # Get headers from first record
        headers = list(data[0].keys()) if data else []
        
        html_content = f"""
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{html.escape(title)}</title>
    <style>
        {self._get_css_styles()}
    </style>
</head>
<body>
    <div class="container">
        <header class="report-header">
            <h1><i class="icon">🚀</i> {html.escape(title)}</h1>
            <div class="report-info">
                <span class="generated-time">生成日時: {datetime.now().strftime('%Y年%m月%d日 %H:%M:%S')}</span>
                <span class="record-count">件数: {len(data):,} 件</span>
            </div>
        </header>
        
        <div class="report-summary">
            <div class="summary-card">
                <h3>📊 サマリー情報</h3>
                <div class="summary-grid">
                    <div class="summary-item">
                        <span class="label">総レコード数:</span>
                        <span class="value">{len(data):,}</span>
                    </div>
                    <div class="summary-item">
                        <span class="label">データ項目数:</span>
                        <span class="value">{len(headers)}</span>
                    </div>
                    <div class="summary-item">
                        <span class="label">レポート形式:</span>
                        <span class="value">Python GUI版</span>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="table-container">
            <table class="data-table">
                <thead>
                    <tr>
                        {"".join(f'<th>{html.escape(str(header))}</th>' for header in headers)}
                    </tr>
                </thead>
                <tbody>
                    {self._generate_table_rows(data, headers)}
                </tbody>
            </table>
        </div>
        
        <footer class="report-footer">
            <p>🐍 Microsoft 365 統合管理ツール - Python Edition</p>
            <p>Powered by PyQt6 & Microsoft Graph API</p>
        </footer>
    </div>
    
    <script>
        {self._get_javascript()}
    </script>
</body>
</html>
"""
        return html_content
    
    def _generate_table_rows(self, data: List[Dict[str, Any]], headers: List[str]) -> str:
        """Generate table rows HTML."""
        rows = []
        
        for i, record in enumerate(data):
            row_class = "row-even" if i % 2 == 0 else "row-odd"
            cells = []
            
            for header in headers:
                value = record.get(header, '')
                
                # Format different data types
                if isinstance(value, (list, dict)):
                    value = str(value)
                elif value is None:
                    value = ''
                else:
                    value = str(value)
                
                # Add status styling for specific columns
                cell_class = ""
                if header in ['ステータス', 'Status'] and value:
                    if '正常' in value or 'Success' in value:
                        cell_class = ' class="status-success"'
                    elif '警告' in value or 'Warning' in value:
                        cell_class = ' class="status-warning"'
                    elif '異常' in value or 'Error' in value:
                        cell_class = ' class="status-error"'
                
                cells.append(f'<td{cell_class}>{html.escape(value)}</td>')
            
            rows.append(f'<tr class="{row_class}">{"".join(cells)}</tr>')
        
        return "\\n".join(rows)
    
    def _get_css_styles(self) -> str:
        """Get CSS styles for the report."""
        return """
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', 'Yu Gothic UI', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .report-header {
            background: linear-gradient(135deg, #0078D4, #106EBE);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .report-header h1 {
            font-size: 2.5em;
            margin-bottom: 15px;
            font-weight: 300;
        }
        
        .report-header .icon {
            font-size: 1.2em;
            margin-right: 10px;
        }
        
        .report-info {
            display: flex;
            justify-content: center;
            gap: 30px;
            margin-top: 15px;
        }
        
        .report-info span {
            background: rgba(255,255,255,0.2);
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 0.9em;
        }
        
        .report-summary {
            padding: 30px;
            background: #f8f9fa;
        }
        
        .summary-card {
            background: white;
            border-radius: 8px;
            padding: 25px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }
        
        .summary-card h3 {
            color: #333;
            margin-bottom: 20px;
            font-size: 1.3em;
        }
        
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
        }
        
        .summary-item {
            display: flex;
            justify-content: space-between;
            padding: 15px 0;
            border-bottom: 1px solid #eee;
        }
        
        .summary-item .label {
            color: #666;
            font-weight: 500;
        }
        
        .summary-item .value {
            color: #0078D4;
            font-weight: bold;
        }
        
        .table-container {
            padding: 0 30px 30px;
            overflow-x: auto;
        }
        
        .data-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }
        
        .data-table th {
            background: #f8f9fa;
            color: #333;
            font-weight: 600;
            padding: 15px 12px;
            text-align: left;
            border-bottom: 2px solid #dee2e6;
            position: sticky;
            top: 0;
            z-index: 10;
        }
        
        .data-table td {
            padding: 12px;
            border-bottom: 1px solid #eee;
            vertical-align: top;
        }
        
        .row-even {
            background: #ffffff;
        }
        
        .row-odd {
            background: #f8f9fa;
        }
        
        .data-table tr:hover {
            background: #e3f2fd !important;
            transition: background 0.2s ease;
        }
        
        .status-success {
            color: #28a745;
            font-weight: bold;
        }
        
        .status-warning {
            color: #ffc107;
            font-weight: bold;
        }
        
        .status-error {
            color: #dc3545;
            font-weight: bold;
        }
        
        .report-footer {
            background: #333;
            color: white;
            text-align: center;
            padding: 20px;
            font-size: 0.9em;
        }
        
        .report-footer p {
            margin: 5px 0;
        }
        
        @media (max-width: 768px) {
            .container {
                margin: 10px;
                border-radius: 8px;
            }
            
            .report-header {
                padding: 20px;
            }
            
            .report-header h1 {
                font-size: 1.8em;
            }
            
            .report-info {
                flex-direction: column;
                gap: 10px;
            }
            
            .table-container {
                padding: 0 15px 20px;
            }
            
            .data-table {
                font-size: 0.9em;
            }
            
            .data-table th,
            .data-table td {
                padding: 8px 6px;
            }
        }
        """
    
    def _get_javascript(self) -> str:
        """Get JavaScript for interactive features."""
        return """
        // Simple table interactions
        document.addEventListener('DOMContentLoaded', function() {
            const table = document.querySelector('.data-table');
            if (table) {
                // Add click-to-highlight functionality
                const rows = table.querySelectorAll('tbody tr');
                rows.forEach(row => {
                    row.addEventListener('click', function() {
                        rows.forEach(r => r.classList.remove('selected'));
                        this.classList.add('selected');
                    });
                });
            }
            
            // Add print functionality
            const printButton = document.createElement('button');
            printButton.textContent = '🖨️ 印刷';
            printButton.style.cssText = 'position: fixed; top: 20px; right: 20px; background: #0078D4; color: white; border: none; padding: 10px 15px; border-radius: 5px; cursor: pointer; z-index: 1000;';
            printButton.onclick = function() { window.print(); };
            document.body.appendChild(printButton);
        });
        """