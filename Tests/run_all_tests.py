#!/usr/bin/env python3
"""
Microsoft 365 Management Tools - 統合テストランナー
全てのテストスイートを実行し、包括的なレポートを生成します。
"""

import sys
import os
import pytest
import subprocess
from pathlib import Path
from datetime import datetime
import json
import logging
from typing import Dict, List, Any
import argparse
import time


class TestSuiteRunner:
    """統合テストスイートランナー"""
    
    def __init__(self, project_root: Path = None):
        self.project_root = project_root or Path(__file__).parent.parent
        self.test_root = self.project_root / "Tests"
        self.output_dir = self.project_root / "TestOutput"
        self.output_dir.mkdir(exist_ok=True)
        
        # ログ設定
        self.log_file = self.output_dir / f"test_run_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        self._setup_logging()
        
    def _setup_logging(self):
        """ログ設定"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.log_file, encoding='utf-8'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def run_all_tests(self, test_types: List[str] = None) -> Dict[str, Any]:
        """全テストスイートを実行"""
        if test_types is None:
            test_types = ['unit', 'integration', 'compatibility', 'performance']
        
        self.logger.info("="*80)
        self.logger.info("Microsoft 365 管理ツール - 統合テスト開始")
        self.logger.info(f"プロジェクトルート: {self.project_root}")
        self.logger.info(f"テストタイプ: {', '.join(test_types)}")
        self.logger.info("="*80)
        
        results = {}
        start_time = time.time()
        
        # 各テストタイプを実行
        for test_type in test_types:
            self.logger.info(f"\n{test_type.upper()}テスト開始...")
            results[test_type] = self._run_test_type(test_type)
        
        # 互換性テスト専用ランナーを実行
        if 'compatibility' in test_types:
            self.logger.info("\n詳細互換性テスト実行...")
            results['compatibility_detailed'] = self._run_compatibility_tests()
        
        # カバレッジレポート生成
        if 'coverage' in test_types or 'unit' in test_types:
            self.logger.info("\nカバレッジレポート生成...")
            results['coverage'] = self._generate_coverage_report()
        
        # 総合レポート生成
        total_time = time.time() - start_time
        summary = self._generate_summary_report(results, total_time)
        
        self.logger.info("\n" + "="*80)
        self.logger.info("テスト完了")
        self.logger.info(f"総実行時間: {total_time:.2f}秒")
        self.logger.info(f"レポート保存先: {self.output_dir}")
        self.logger.info("="*80)
        
        return summary
    
    def _run_test_type(self, test_type: str) -> Dict[str, Any]:
        """特定タイプのテストを実行"""
        test_paths = {
            'unit': self.test_root / 'unit',
            'integration': self.test_root / 'integration',
            'compatibility': self.test_root / 'compatibility',
            'performance': self.test_root / 'performance'
        }
        
        test_path = test_paths.get(test_type)
        if not test_path or not test_path.exists():
            self.logger.warning(f"{test_type}テストディレクトリが見つかりません: {test_path}")
            return {'status': 'skipped', 'reason': 'directory not found'}
        
        # pytest実行
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        report_file = self.output_dir / f"{test_type}_report_{timestamp}.json"
        
        pytest_args = [
            '-v',
            '--tb=short',
            f'--json-report-file={report_file}',
            '--json-report',
            str(test_path)
        ]
        
        # カバレッジオプション（単体テストのみ）
        if test_type == 'unit':
            pytest_args.extend([
                '--cov=src',
                '--cov-report=html',
                f'--cov-report=html:{self.output_dir}/coverage_html',
                '--cov-report=term'
            ])
        
        # マーカーオプション
        if test_type == 'integration':
            pytest_args.extend(['-m', 'integration'])
        elif test_type == 'compatibility':
            pytest_args.extend(['-m', 'compatibility'])
        elif test_type == 'performance':
            pytest_args.extend(['-m', 'performance'])
        
        try:
            result = subprocess.run(
                [sys.executable, '-m', 'pytest'] + pytest_args,
                capture_output=True,
                text=True,
                cwd=self.project_root
            )
            
            # 結果解析
            test_result = {
                'status': 'passed' if result.returncode == 0 else 'failed',
                'return_code': result.returncode,
                'report_file': str(report_file) if report_file.exists() else None
            }
            
            # JSONレポート読み込み
            if report_file.exists():
                with open(report_file, 'r', encoding='utf-8') as f:
                    json_report = json.load(f)
                    test_result.update({
                        'total': json_report['summary']['total'],
                        'passed': json_report['summary'].get('passed', 0),
                        'failed': json_report['summary'].get('failed', 0),
                        'skipped': json_report['summary'].get('skipped', 0),
                        'duration': json_report['duration']
                    })
            
            self.logger.info(f"{test_type}テスト完了: {test_result['status']}")
            return test_result
            
        except Exception as e:
            self.logger.error(f"{test_type}テスト実行エラー: {e}")
            return {'status': 'error', 'error': str(e)}
    
    def _run_compatibility_tests(self) -> Dict[str, Any]:
        """互換性テスト専用ランナーを実行"""
        compat_runner = self.test_root / 'run_compatibility_tests.py'
        
        if not compat_runner.exists():
            return {'status': 'skipped', 'reason': 'runner not found'}
        
        try:
            result = subprocess.run(
                [sys.executable, str(compat_runner)],
                capture_output=True,
                text=True,
                cwd=self.project_root
            )
            
            return {
                'status': 'completed',
                'return_code': result.returncode,
                'output': result.stdout[-1000:] if result.stdout else None  # Last 1000 chars
            }
            
        except Exception as e:
            self.logger.error(f"互換性テスト実行エラー: {e}")
            return {'status': 'error', 'error': str(e)}
    
    def _generate_coverage_report(self) -> Dict[str, Any]:
        """カバレッジレポート生成"""
        try:
            # カバレッジ統計取得
            result = subprocess.run(
                [sys.executable, '-m', 'coverage', 'report', '--format=json'],
                capture_output=True,
                text=True,
                cwd=self.project_root
            )
            
            if result.returncode == 0:
                coverage_data = json.loads(result.stdout)
                return {
                    'status': 'generated',
                    'total_coverage': coverage_data.get('totals', {}).get('percent_covered', 0),
                    'files': coverage_data.get('files', {})
                }
            else:
                return {'status': 'failed', 'error': result.stderr}
                
        except Exception as e:
            self.logger.error(f"カバレッジレポート生成エラー: {e}")
            return {'status': 'error', 'error': str(e)}
    
    def _generate_summary_report(self, results: Dict[str, Any], total_time: float) -> Dict[str, Any]:
        """総合サマリーレポート生成"""
        summary = {
            'timestamp': datetime.now().isoformat(),
            'total_execution_time': total_time,
            'test_results': results,
            'overall_status': 'passed',
            'statistics': {
                'total_tests': 0,
                'passed_tests': 0,
                'failed_tests': 0,
                'skipped_tests': 0
            }
        }
        
        # 統計集計
        for test_type, result in results.items():
            if isinstance(result, dict) and 'total' in result:
                summary['statistics']['total_tests'] += result.get('total', 0)
                summary['statistics']['passed_tests'] += result.get('passed', 0)
                summary['statistics']['failed_tests'] += result.get('failed', 0)
                summary['statistics']['skipped_tests'] += result.get('skipped', 0)
                
                if result.get('status') == 'failed':
                    summary['overall_status'] = 'failed'
        
        # HTMLレポート生成
        self._generate_html_summary(summary)
        
        # JSONレポート保存
        report_file = self.output_dir / f"test_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(summary, f, ensure_ascii=False, indent=2)
        
        return summary
    
    def _generate_html_summary(self, summary: Dict[str, Any]):
        """HTML形式のサマリーレポート生成"""
        html_file = self.output_dir / f"test_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.html"
        
        stats = summary['statistics']
        pass_rate = (stats['passed_tests'] / stats['total_tests'] * 100) if stats['total_tests'] > 0 else 0
        
        html_content = f"""
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <title>テスト実行サマリー - Microsoft 365 管理ツール</title>
    <style>
        body {{
            font-family: 'Segoe UI', sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }}
        .container {{
            max-width: 1000px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }}
        h1 {{
            color: #0078d4;
            text-align: center;
            margin-bottom: 30px;
        }}
        .metrics {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }}
        .metric-card {{
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            border: 1px solid #e9ecef;
        }}
        .metric-value {{
            font-size: 36px;
            font-weight: bold;
            margin-bottom: 5px;
        }}
        .metric-label {{
            color: #6c757d;
            font-size: 14px;
        }}
        .status-passed {{
            color: #28a745;
        }}
        .status-failed {{
            color: #dc3545;
        }}
        .test-results {{
            margin-top: 30px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }}
        th, td {{
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #dee2e6;
        }}
        th {{
            background-color: #0078d4;
            color: white;
            font-weight: 600;
        }}
        tr:hover {{
            background-color: #f8f9fa;
        }}
        .badge {{
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
        }}
        .badge-success {{
            background-color: #d4edda;
            color: #155724;
        }}
        .badge-danger {{
            background-color: #f8d7da;
            color: #721c24;
        }}
        .badge-warning {{
            background-color: #fff3cd;
            color: #856404;
        }}
        .footer {{
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #dee2e6;
            text-align: center;
            color: #6c757d;
            font-size: 14px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🧪 テスト実行サマリー</h1>
        
        <div class="metrics">
            <div class="metric-card">
                <div class="metric-value">{stats['total_tests']}</div>
                <div class="metric-label">総テスト数</div>
            </div>
            <div class="metric-card">
                <div class="metric-value status-passed">{stats['passed_tests']}</div>
                <div class="metric-label">成功</div>
            </div>
            <div class="metric-card">
                <div class="metric-value status-failed">{stats['failed_tests']}</div>
                <div class="metric-label">失敗</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">{pass_rate:.1f}%</div>
                <div class="metric-label">成功率</div>
            </div>
        </div>
        
        <div class="test-results">
            <h2>📊 テストタイプ別結果</h2>
            <table>
                <thead>
                    <tr>
                        <th>テストタイプ</th>
                        <th>ステータス</th>
                        <th>実行テスト数</th>
                        <th>成功</th>
                        <th>失敗</th>
                        <th>スキップ</th>
                        <th>実行時間</th>
                    </tr>
                </thead>
                <tbody>
"""
        
        for test_type, result in summary['test_results'].items():
            if isinstance(result, dict) and 'status' in result:
                status_badge = {
                    'passed': '<span class="badge badge-success">成功</span>',
                    'failed': '<span class="badge badge-danger">失敗</span>',
                    'skipped': '<span class="badge badge-warning">スキップ</span>',
                    'error': '<span class="badge badge-danger">エラー</span>'
                }.get(result['status'], result['status'])
                
                html_content += f"""
                    <tr>
                        <td>{test_type}</td>
                        <td>{status_badge}</td>
                        <td>{result.get('total', '-')}</td>
                        <td>{result.get('passed', '-')}</td>
                        <td>{result.get('failed', '-')}</td>
                        <td>{result.get('skipped', '-')}</td>
                        <td>{result.get('duration', '-')}s</td>
                    </tr>
"""
        
        html_content += f"""
                </tbody>
            </table>
        </div>
        
        <div class="footer">
            <p>生成日時: {datetime.now().strftime('%Y年%m月%d日 %H:%M:%S')}</p>
            <p>総実行時間: {summary['total_execution_time']:.2f}秒</p>
            <p>Microsoft 365 管理ツール - Python版テストレポート</p>
        </div>
    </div>
</body>
</html>
"""
        
        with open(html_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        self.logger.info(f"HTMLサマリーレポート生成: {html_file}")


def main():
    """メインエントリーポイント"""
    parser = argparse.ArgumentParser(
        description='Microsoft 365 管理ツール - テストランナー'
    )
    parser.add_argument(
        '--types',
        nargs='+',
        choices=['unit', 'integration', 'compatibility', 'performance', 'all'],
        default=['all'],
        help='実行するテストタイプ'
    )
    parser.add_argument(
        '--output',
        type=Path,
        help='レポート出力ディレクトリ'
    )
    
    args = parser.parse_args()
    
    # テストタイプ決定
    if 'all' in args.types:
        test_types = ['unit', 'integration', 'compatibility', 'performance']
    else:
        test_types = args.types
    
    # テストランナー実行
    runner = TestSuiteRunner()
    if args.output:
        runner.output_dir = args.output
        runner.output_dir.mkdir(exist_ok=True)
    
    summary = runner.run_all_tests(test_types)
    
    # 終了コード決定
    exit_code = 0 if summary['overall_status'] == 'passed' else 1
    sys.exit(exit_code)


if __name__ == '__main__':
    main()