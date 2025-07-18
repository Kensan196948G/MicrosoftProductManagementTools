"""
パフォーマンス統合テスト - 性能測定・ベンチマーク
Dev1 - Test/QA Developer によるパフォーマンステスト実装

Microsoft 365管理ツールの性能測定と最適化検証
"""

import pytest
import time
import asyncio
import threading
import psutil
import gc
import json
import tempfile
from pathlib import Path
from datetime import datetime, timedelta
from unittest.mock import Mock, patch
from typing import Dict, List, Any, Generator
import pandas as pd
import concurrent.futures
from dataclasses import dataclass
from contextlib import contextmanager

# プロジェクトモジュール（実装時に調整）
try:
    from src.api.graph.client import GraphClient
    from src.reports.generator import ReportGenerator
    from src.core.config import Config
    from src.gui.main_window import MainWindow
except ImportError:
    # 開発初期段階でのモック定義
    GraphClient = Mock()
    ReportGenerator = Mock()
    Config = Mock()
    MainWindow = Mock()


@dataclass
class PerformanceMetrics:
    """パフォーマンス測定メトリクス"""
    execution_time: float
    memory_usage_mb: float
    cpu_usage_percent: float
    operation_count: int
    throughput_ops_per_sec: float
    peak_memory_mb: float
    
    def to_dict(self) -> Dict[str, Any]:
        """辞書形式に変換"""
        return {
            "execution_time": self.execution_time,
            "memory_usage_mb": self.memory_usage_mb,
            "cpu_usage_percent": self.cpu_usage_percent,
            "operation_count": self.operation_count,
            "throughput_ops_per_sec": self.throughput_ops_per_sec,
            "peak_memory_mb": self.peak_memory_mb
        }


class PerformanceMonitor:
    """パフォーマンス監視クラス"""
    
    def __init__(self):
        self.process = psutil.Process()
        self.start_time = None
        self.start_memory = None
        self.peak_memory = 0
        self.operation_count = 0
    
    @contextmanager
    def monitor_performance(self) -> Generator[None, None, PerformanceMetrics]:
        """パフォーマンス監視コンテキストマネージャー"""
        # 開始時の状態記録
        self.start_time = time.time()
        self.start_memory = self.process.memory_info().rss / 1024 / 1024  # MB
        self.peak_memory = self.start_memory
        
        # ガベージコレクション実行
        gc.collect()
        
        try:
            yield
        finally:
            # 終了時の測定
            end_time = time.time()
            end_memory = self.process.memory_info().rss / 1024 / 1024  # MB
            cpu_percent = self.process.cpu_percent()
            
            execution_time = end_time - self.start_time
            memory_usage = end_memory - self.start_memory
            
            throughput = self.operation_count / execution_time if execution_time > 0 else 0
            
            self.metrics = PerformanceMetrics(
                execution_time=execution_time,
                memory_usage_mb=memory_usage,
                cpu_usage_percent=cpu_percent,
                operation_count=self.operation_count,
                throughput_ops_per_sec=throughput,
                peak_memory_mb=self.peak_memory
            )
    
    def increment_operation_count(self, count: int = 1):
        """操作カウントをインクリメント"""
        self.operation_count += count
        
        # ピークメモリ更新
        current_memory = self.process.memory_info().rss / 1024 / 1024
        if current_memory > self.peak_memory:
            self.peak_memory = current_memory


@pytest.mark.performance
@pytest.mark.slow
class TestAPIPerformance:
    """API性能テスト"""
    
    @pytest.fixture(autouse=True)
    def setup_performance_test(self):
        """パフォーマンステストセットアップ"""
        self.monitor = PerformanceMonitor()
        self.mock_graph_client = Mock()
        
        # 大量データのモック準備
        self.large_user_dataset = {
            "value": [
                {
                    "id": f"user-{i:05d}",
                    "displayName": f"テストユーザー{i}",
                    "userPrincipalName": f"user{i}@contoso.com",
                    "department": f"部署{i % 50}",
                    "jobTitle": f"職位{i % 20}",
                    "accountEnabled": True,
                    "createdDateTime": f"2024-01-{(i % 28) + 1:02d}T10:00:00Z",
                    "lastSignInDateTime": f"2024-01-{(i % 28) + 1:02d}T15:30:00Z"
                }
                for i in range(5000)  # 5000ユーザー
            ]
        }
        
        self.mock_graph_client.get_users.return_value = self.large_user_dataset
    
    @pytest.mark.benchmark
    def test_large_user_dataset_processing(self):
        """大規模ユーザーデータセット処理性能テスト"""
        with self.monitor.monitor_performance():
            # 1. データ取得
            users = self.mock_graph_client.get_users()
            self.monitor.increment_operation_count(1)
            
            # 2. データ処理
            processed_users = []
            for user in users["value"]:
                processed_user = {
                    "id": user["id"],
                    "name": user["displayName"],
                    "email": user["userPrincipalName"],
                    "department": user["department"],
                    "active": user["accountEnabled"]
                }
                processed_users.append(processed_user)
                self.monitor.increment_operation_count(1)
            
            # 3. データフィルタリング
            active_users = [u for u in processed_users if u["active"]]
            self.monitor.increment_operation_count(len(active_users))
        
        # 4. 性能要件確認
        metrics = self.monitor.metrics
        assert metrics.execution_time < 10.0  # 10秒以内
        assert metrics.memory_usage_mb < 100  # 100MB以下
        assert metrics.throughput_ops_per_sec > 500  # 500ops/sec以上
        assert len(processed_users) == 5000
        
        # 5. メトリクス出力
        print(f"処理時間: {metrics.execution_time:.2f}秒")
        print(f"メモリ使用量: {metrics.memory_usage_mb:.2f}MB")
        print(f"スループット: {metrics.throughput_ops_per_sec:.2f}ops/sec")
    
    @pytest.mark.benchmark
    def test_concurrent_api_calls_performance(self):
        """並行API呼び出し性能テスト"""
        async def simulate_api_call(delay: float = 0.1):
            """API呼び出しシミュレーション"""
            await asyncio.sleep(delay)
            return self.mock_graph_client.get_users()
        
        async def run_concurrent_calls():
            """並行API呼び出し実行"""
            tasks = []
            for i in range(10):  # 10並行
                task = simulate_api_call(0.1)
                tasks.append(task)
            
            results = await asyncio.gather(*tasks)
            return results
        
        with self.monitor.monitor_performance():
            # 並行実行
            results = asyncio.run(run_concurrent_calls())
            self.monitor.increment_operation_count(len(results))
        
        # 性能要件確認
        metrics = self.monitor.metrics
        assert metrics.execution_time < 2.0  # 2秒以内（順次実行なら1秒）
        assert len(results) == 10
        
        # 並行処理の効率性確認
        expected_sequential_time = 10 * 0.1  # 1秒
        efficiency = expected_sequential_time / metrics.execution_time
        assert efficiency > 3.0  # 3倍以上の効率化
    
    @pytest.mark.benchmark
    def test_memory_usage_optimization(self):
        """メモリ使用量最適化テスト"""
        with self.monitor.monitor_performance():
            # 1. 大量データ処理（メモリ効率的）
            for batch_start in range(0, 5000, 1000):  # 1000件ずつ処理
                batch_users = self.large_user_dataset["value"][batch_start:batch_start + 1000]
                
                # バッチ処理
                processed_batch = []
                for user in batch_users:
                    processed_user = {
                        "id": user["id"],
                        "name": user["displayName"]
                    }
                    processed_batch.append(processed_user)
                
                self.monitor.increment_operation_count(len(processed_batch))
                
                # メモリ解放
                del processed_batch
                gc.collect()
        
        # メモリ使用量確認
        metrics = self.monitor.metrics
        assert metrics.peak_memory_mb < 50  # ピークメモリ50MB以下
        assert metrics.memory_usage_mb < 20  # 最終メモリ使用量20MB以下
    
    @pytest.mark.benchmark
    def test_data_transformation_performance(self):
        """データ変換性能テスト"""
        with self.monitor.monitor_performance():
            # 1. 複雑なデータ変換
            users_data = self.large_user_dataset["value"]
            
            # DataFrame変換
            df = pd.DataFrame(users_data)
            self.monitor.increment_operation_count(1)
            
            # データ加工
            df['department_code'] = df['department'].str.extract(r'(\d+)')
            df['last_login_date'] = pd.to_datetime(df['lastSignInDateTime'])
            df['account_age_days'] = (pd.Timestamp.now() - pd.to_datetime(df['createdDateTime'])).dt.days
            
            # グループ化・集計
            dept_summary = df.groupby('department').agg({
                'id': 'count',
                'accountEnabled': 'sum',
                'account_age_days': 'mean'
            }).reset_index()
            
            self.monitor.increment_operation_count(len(dept_summary))
        
        # 変換結果確認
        metrics = self.monitor.metrics
        assert metrics.execution_time < 5.0  # 5秒以内
        assert len(dept_summary) == 50  # 50部署
        
        # DataFrame性能確認
        assert df.shape[0] == 5000
        assert 'department_code' in df.columns


@pytest.mark.performance
@pytest.mark.slow
class TestReportGenerationPerformance:
    """レポート生成性能テスト"""
    
    @pytest.fixture(autouse=True)
    def setup_report_performance_test(self, temp_project_dir):
        """レポート性能テストセットアップ"""
        self.monitor = PerformanceMonitor()
        self.temp_dir = temp_project_dir
        self.reports_dir = self.temp_dir / "Reports"
        self.reports_dir.mkdir(exist_ok=True)
        
        # 大量データ準備
        self.large_dataset = {
            "users": [
                {
                    "ID": f"user-{i:05d}",
                    "表示名": f"テストユーザー{i}",
                    "メールアドレス": f"user{i}@contoso.com",
                    "部署": f"部署{i % 100}",
                    "職位": f"職位{i % 30}",
                    "状態": "有効" if i % 10 != 0 else "無効",
                    "作成日": f"2024-{(i % 12) + 1:02d}-{(i % 28) + 1:02d}",
                    "最終ログイン": f"2024-{(i % 12) + 1:02d}-{(i % 28) + 1:02d}"
                }
                for i in range(10000)  # 10000ユーザー
            ],
            "licenses": [
                {
                    "SKU ID": f"sku-{i:03d}",
                    "製品名": f"製品{i}",
                    "消費数": str(i * 10),
                    "利用率": f"{min(95, i * 2)}%"
                }
                for i in range(100)  # 100ライセンス
            ]
        }
    
    @pytest.mark.benchmark
    def test_large_html_report_generation(self):
        """大規模HTMLレポート生成性能テスト"""
        with self.monitor.monitor_performance():
            # 1. HTMLレポート生成
            report_generator = ReportGenerator(self.reports_dir)
            
            # HTMLテンプレート作成
            html_template = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>性能テストレポート</title>
                <style>
                    table {{ border-collapse: collapse; width: 100%; }}
                    th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
                    th {{ background-color: #f2f2f2; }}
                </style>
            </head>
            <body>
                <h1>Microsoft 365 管理レポート</h1>
                <h2>ユーザー情報 ({user_count}件)</h2>
                <table>
                    <tr>
                        <th>ID</th><th>表示名</th><th>メールアドレス</th><th>部署</th><th>状態</th>
                    </tr>
                    {user_rows}
                </table>
                <h2>ライセンス情報 ({license_count}件)</h2>
                <table>
                    <tr>
                        <th>SKU ID</th><th>製品名</th><th>消費数</th><th>利用率</th>
                    </tr>
                    {license_rows}
                </table>
            </body>
            </html>
            """
            
            # ユーザー行生成
            user_rows = []
            for user in self.large_dataset["users"]:
                row = f"""
                <tr>
                    <td>{user['ID']}</td>
                    <td>{user['表示名']}</td>
                    <td>{user['メールアドレス']}</td>
                    <td>{user['部署']}</td>
                    <td>{user['状態']}</td>
                </tr>
                """
                user_rows.append(row)
                self.monitor.increment_operation_count(1)
            
            # ライセンス行生成
            license_rows = []
            for license in self.large_dataset["licenses"]:
                row = f"""
                <tr>
                    <td>{license['SKU ID']}</td>
                    <td>{license['製品名']}</td>
                    <td>{license['消費数']}</td>
                    <td>{license['利用率']}</td>
                </tr>
                """
                license_rows.append(row)
                self.monitor.increment_operation_count(1)
            
            # HTMLファイル作成
            html_content = html_template.format(
                user_count=len(self.large_dataset["users"]),
                license_count=len(self.large_dataset["licenses"]),
                user_rows="".join(user_rows),
                license_rows="".join(license_rows)
            )
            
            report_path = self.reports_dir / "performance_test_report.html"
            with open(report_path, 'w', encoding='utf-8') as f:
                f.write(html_content)
            
            self.monitor.increment_operation_count(1)
        
        # 性能要件確認
        metrics = self.monitor.metrics
        assert metrics.execution_time < 30.0  # 30秒以内
        assert metrics.memory_usage_mb < 200  # 200MB以下
        assert report_path.exists()
        
        # ファイルサイズ確認
        file_size_mb = report_path.stat().st_size / 1024 / 1024
        assert file_size_mb > 1.0  # 1MB以上（大量データ）
        
        print(f"HTMLレポート生成時間: {metrics.execution_time:.2f}秒")
        print(f"ファイルサイズ: {file_size_mb:.2f}MB")
    
    @pytest.mark.benchmark
    def test_large_csv_report_generation(self):
        """大規模CSVレポート生成性能テスト"""
        with self.monitor.monitor_performance():
            # 1. CSVレポート生成
            csv_path = self.reports_dir / "performance_test_report.csv"
            
            # CSVヘッダー
            csv_content = ["ID,表示名,メールアドレス,部署,職位,状態,作成日,最終ログイン"]
            
            # CSVデータ行
            for user in self.large_dataset["users"]:
                row = f"{user['ID']},{user['表示名']},{user['メールアドレス']},{user['部署']},{user['職位']},{user['状態']},{user['作成日']},{user['最終ログイン']}"
                csv_content.append(row)
                self.monitor.increment_operation_count(1)
            
            # UTF-8 BOM付きで保存
            with open(csv_path, 'w', encoding='utf-8-sig') as f:
                f.write('\n'.join(csv_content))
            
            self.monitor.increment_operation_count(1)
        
        # 性能要件確認
        metrics = self.monitor.metrics
        assert metrics.execution_time < 10.0  # 10秒以内
        assert metrics.throughput_ops_per_sec > 1000  # 1000ops/sec以上
        assert csv_path.exists()
        
        # CSVファイル検証
        df = pd.read_csv(csv_path, encoding='utf-8-sig')
        assert len(df) == 10000
        assert df.columns.tolist() == ['ID', '表示名', 'メールアドレス', '部署', '職位', '状態', '作成日', '最終ログイン']
    
    @pytest.mark.benchmark
    def test_multi_format_report_generation(self):
        """複数フォーマット同時生成性能テスト"""
        with self.monitor.monitor_performance():
            # 1. 複数フォーマットで同時生成
            formats = ['html', 'csv', 'json']
            generated_files = {}
            
            for format_type in formats:
                if format_type == 'html':
                    # HTML生成
                    file_path = self.reports_dir / f"multi_format_report.{format_type}"
                    html_content = f"""
                    <!DOCTYPE html>
                    <html>
                    <head><title>マルチフォーマットレポート</title></head>
                    <body>
                        <h1>ユーザー数: {len(self.large_dataset['users'])}</h1>
                        <h1>ライセンス数: {len(self.large_dataset['licenses'])}</h1>
                    </body>
                    </html>
                    """
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(html_content)
                
                elif format_type == 'csv':
                    # CSV生成
                    file_path = self.reports_dir / f"multi_format_report.{format_type}"
                    df = pd.DataFrame(self.large_dataset["users"])
                    df.to_csv(file_path, index=False, encoding='utf-8-sig')
                
                elif format_type == 'json':
                    # JSON生成
                    file_path = self.reports_dir / f"multi_format_report.{format_type}"
                    with open(file_path, 'w', encoding='utf-8') as f:
                        json.dump(self.large_dataset, f, ensure_ascii=False, indent=2)
                
                generated_files[format_type] = file_path
                self.monitor.increment_operation_count(1)
        
        # 性能要件確認
        metrics = self.monitor.metrics
        assert metrics.execution_time < 15.0  # 15秒以内
        assert len(generated_files) == 3
        
        # 全ファイル存在確認
        for format_type, file_path in generated_files.items():
            assert file_path.exists()
            assert file_path.suffix == f'.{format_type}'


@pytest.mark.performance
@pytest.mark.slow
class TestGUIPerformance:
    """GUI性能テスト"""
    
    @pytest.fixture(autouse=True)
    def setup_gui_performance_test(self, gui_test_env):
        """GUI性能テストセットアップ"""
        self.monitor = PerformanceMonitor()
    
    @pytest.mark.gui
    @pytest.mark.benchmark
    def test_gui_startup_performance(self):
        """GUI起動性能テスト"""
        with self.monitor.monitor_performance():
            # GUI起動シミュレーション
            with patch('src.gui.main_window.MainWindow') as mock_window:
                mock_window.return_value.show.return_value = None
                mock_window.return_value.exec.return_value = 0
                
                # ウィンドウ作成
                window = MainWindow()
                window.show()
                
                self.monitor.increment_operation_count(1)
        
        # 起動時間確認
        metrics = self.monitor.metrics
        assert metrics.execution_time < 3.0  # 3秒以内
        assert metrics.memory_usage_mb < 100  # 100MB以下
    
    @pytest.mark.gui
    @pytest.mark.benchmark
    def test_gui_large_data_rendering(self):
        """GUI大量データ描画性能テスト"""
        with self.monitor.monitor_performance():
            # 大量データ描画シミュレーション
            large_data = [{"name": f"アイテム{i}", "value": i} for i in range(1000)]
            
            with patch('src.gui.components.data_grid.DataGrid') as mock_grid:
                mock_grid.return_value.load_data.return_value = None
                mock_grid.return_value.render.return_value = None
                
                # データグリッド作成と描画
                grid = mock_grid()
                grid.load_data(large_data)
                grid.render()
                
                self.monitor.increment_operation_count(len(large_data))
        
        # 描画性能確認
        metrics = self.monitor.metrics
        assert metrics.execution_time < 2.0  # 2秒以内
        assert metrics.throughput_ops_per_sec > 500  # 500ops/sec以上


@pytest.mark.performance
@pytest.mark.slow
class TestMemoryLeakDetection:
    """メモリリーク検出テスト"""
    
    @pytest.fixture(autouse=True)
    def setup_memory_leak_test(self):
        """メモリリークテストセットアップ"""
        self.monitor = PerformanceMonitor()
        gc.collect()  # 初期ガベージコレクション
    
    @pytest.mark.benchmark
    def test_memory_leak_detection(self):
        """メモリリーク検出テスト"""
        initial_memory = self.monitor.process.memory_info().rss / 1024 / 1024
        memory_samples = []
        
        # 反復処理でメモリ使用量監視
        for iteration in range(100):
            # 処理シミュレーション
            large_data = [{"id": i, "data": "x" * 1000} for i in range(1000)]
            
            # データ処理
            processed_data = []
            for item in large_data:
                processed_item = {
                    "id": item["id"],
                    "length": len(item["data"])
                }
                processed_data.append(processed_item)
            
            # メモリ使用量記録
            current_memory = self.monitor.process.memory_info().rss / 1024 / 1024
            memory_samples.append(current_memory)
            
            # 定期的なガベージコレクション
            if iteration % 10 == 0:
                gc.collect()
            
            # 明示的なメモリ解放
            del large_data
            del processed_data
        
        # メモリリーク検出
        final_memory = self.monitor.process.memory_info().rss / 1024 / 1024
        memory_increase = final_memory - initial_memory
        
        # 最後のガベージコレクション
        gc.collect()
        after_gc_memory = self.monitor.process.memory_info().rss / 1024 / 1024
        
        # メモリリーク閾値確認
        assert memory_increase < 50  # 50MB以下の増加
        assert after_gc_memory - initial_memory < 20  # GC後20MB以下
        
        # メモリ使用量の推移確認
        memory_trend = sum(memory_samples[-10:]) / 10 - sum(memory_samples[:10]) / 10
        assert memory_trend < 10  # 最後の10回の平均が最初の10回より10MB以下の増加
        
        print(f"初期メモリ: {initial_memory:.2f}MB")
        print(f"最終メモリ: {final_memory:.2f}MB")
        print(f"GC後メモリ: {after_gc_memory:.2f}MB")
        print(f"メモリ増加量: {memory_increase:.2f}MB")


if __name__ == "__main__":
    pytest.main([
        __file__, 
        "-v", 
        "--tb=short", 
        "-m", "performance",
        "--benchmark-json=benchmark_results.json"
    ])