#!/usr/bin/env python3
"""
Microsoft 365 Management Tools - 包括パフォーマンステストスイート
負荷テスト、メモリリーク、同期処理性能の包括的テスト
"""

import pytest
import asyncio
import time
import psutil
import os
import threading
import concurrent.futures
from typing import Dict, List, Any, Callable
import logging
import sys
from pathlib import Path
import json
from unittest.mock import Mock, patch, AsyncMock
import gc
import resource
from datetime import datetime
import subprocess
import multiprocessing

# プロジェクトルートをパスに追加
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))


class PerformanceMonitor:
    """パフォーマンス監視クラス"""
    
    def __init__(self):
        self.process = psutil.Process(os.getpid())
        self.start_time = None
        self.start_memory = None
        self.start_cpu = None
        
    def start_monitoring(self):
        """監視開始"""
        self.start_time = time.time()
        self.start_memory = self.process.memory_info().rss / 1024 / 1024  # MB
        self.start_cpu = self.process.cpu_percent()
        
    def get_metrics(self) -> Dict[str, float]:
        """メトリクス取得"""
        if self.start_time is None:
            return {}
            
        current_time = time.time()
        current_memory = self.process.memory_info().rss / 1024 / 1024  # MB
        current_cpu = self.process.cpu_percent()
        
        return {
            'execution_time': current_time - self.start_time,
            'memory_usage': current_memory,
            'memory_increase': current_memory - self.start_memory,
            'cpu_usage': current_cpu,
            'cpu_increase': current_cpu - self.start_cpu
        }


class TestPerformanceComprehensive:
    """包括パフォーマンステストクラス"""
    
    @pytest.fixture(autouse=True)
    def performance_setup(self):
        """パフォーマンステストセットアップ"""
        self.monitor = PerformanceMonitor()
        
        # ガベージコレクション実行
        gc.collect()
        
        yield
        
        # テスト後のクリーンアップ
        gc.collect()
    
    @pytest.mark.performance
    def test_gui_startup_performance(self):
        """アプリケーション起動パフォーマンステスト"""
        self.monitor.start_monitoring()
        
        # GUIアプリケーションのシミュレーション
        try:
            with patch('PyQt6.QtWidgets.QApplication'):
                from gui.main_window import MainWindow
                
                # 起動時間測定
                start_time = time.time()
                main_window = MainWindow()
                startup_time = time.time() - start_time
                
                # パフォーマンス基準
                assert startup_time < 3.0, f"GUI起動時間が基準を超過: {startup_time:.2f}秒"
                
        except ImportError:
            pytest.skip("GUIモジュールが利用できません")
        
        metrics = self.monitor.get_metrics()
        
        # メモリ使用量基準: 100MB以内
        assert metrics['memory_increase'] < 100, f"メモリ使用量増加が基準を超過: {metrics['memory_increase']:.2f}MB"
        
        logging.info(f"GUI起動パフォーマンス: {metrics}")
    
    @pytest.mark.performance
    def test_api_response_time_performance(self):
        """API応答時間パフォーマンステスト"""
        self.monitor.start_monitoring()
        
        # モックMicrosoft Graph APIクライアント
        mock_graph_client = AsyncMock()
        mock_graph_client.get_users.return_value = [
            {
                "id": f"user{i}",
                "displayName": f"Test User {i}",
                "userPrincipalName": f"user{i}@contoso.com"
            } for i in range(100)  # 100人のユーザーデータ
        ]
        
        async def api_performance_test():
            start_time = time.time()
            users = await mock_graph_client.get_users()
            response_time = time.time() - start_time
            
            # API応答時間基準: 1秒以内
            assert response_time < 1.0, f"API応答時間が基準を超過: {response_time:.3f}秒"
            
            return len(users), response_time
        
        # 非同期APIテストの実行
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            user_count, response_time = loop.run_until_complete(api_performance_test())
            
            metrics = self.monitor.get_metrics()
            
            # パフォーマンスメトリクス検証
            assert user_count == 100, f"期待したユーザー数と一致しません: {user_count}"
            
            logging.info(f"APIパフォーマンス - 応答時間: {response_time:.3f}秒, メトリクス: {metrics}")
        
        finally:
            loop.close()
    
    @pytest.mark.performance
    def test_memory_usage_under_load(self):
        """負荷時メモリ使用量テスト"""
        self.monitor.start_monitoring()
        
        # 大量データ処理のシミュレーション
        large_datasets = []
        
        try:
            for i in range(10):  # 10回繰り返し
                # 1000件のユーザーデータを作成
                dataset = [
                    {
                        "id": f"user{j}_{i}",
                        "displayName": f"Test User {j} Batch {i}",
                        "userPrincipalName": f"user{j}_{i}@contoso.com",
                        "mail": f"user{j}_{i}@contoso.com",
                        "department": f"Department {j % 10}",
                        "jobTitle": f"Position {j % 5}",
                        "officeLocation": f"Office {j % 3}"
                    } for j in range(1000)
                ]
                large_datasets.append(dataset)
                
                # 中間メトリクス測定
                current_metrics = self.monitor.get_metrics()
                
                # メモリ使用量が異常に高くなっていないかチェック
                if current_metrics['memory_usage'] > 500:  # 500MBを超えたら警告
                    logging.warning(f"メモリ使用量が高い: {current_metrics['memory_usage']:.2f}MB")
        
        finally:
            # メモリクリーンアップ
            del large_datasets
            gc.collect()
        
        final_metrics = self.monitor.get_metrics()
        
        # メモリリーク検査基準: 200MB以内の増加
        assert final_metrics['memory_increase'] < 200, f"メモリリークの可能性: {final_metrics['memory_increase']:.2f}MB"
        
        logging.info(f"負荷時メモリパフォーマンス: {final_metrics}")
    
    @pytest.mark.performance
    def test_concurrent_api_calls_performance(self):
        """同時API呼び出しパフォーマンステスト"""
        self.monitor.start_monitoring()
        
        # モックAPIクライアント
        mock_api_client = Mock()
        
        def api_call(call_id: int) -> Dict[str, Any]:
            """API呼び出しのシミュレーション"""
            time.sleep(0.1)  # 100msのAPI応答時間をシミュレーション
            return {
                "id": call_id,
                "status": "success",
                "data": [f"item_{i}" for i in range(10)]
            }
        
        # 同時実行テスト
        num_concurrent_calls = 20
        start_time = time.time()
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(api_call, i) for i in range(num_concurrent_calls)]
            results = [future.result() for future in concurrent.futures.as_completed(futures)]
        
        total_time = time.time() - start_time
        
        # 同時実行パフォーマンス基準: 3秒以内
        assert total_time < 3.0, f"同時API呼び出し時間が基準を超過: {total_time:.2f}秒"
        
        # 全ての呼び出しが成功したことを確認
        assert len(results) == num_concurrent_calls, f"一部のAPI呼び出しが失敗: {len(results)}/{num_concurrent_calls}"
        
        metrics = self.monitor.get_metrics()
        
        logging.info(f"同時APIパフォーマンス - 総時間: {total_time:.2f}秒, メトリクス: {metrics}")
    
    @pytest.mark.performance
    def test_database_query_performance(self):
        """データベースクエリパフォーマンステスト"""
        self.monitor.start_monitoring()
        
        # SQLiteテストデータベースの作成
        import sqlite3
        import tempfile
        
        with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as temp_db:
            db_path = temp_db.name
        
        try:
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            
            # テストテーブル作成
            cursor.execute('''
                CREATE TABLE users (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    email TEXT NOT NULL,
                    department TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # 大量データ挿入パフォーマンス測定
            start_time = time.time()
            
            test_data = [
                (f"User {i}", f"user{i}@contoso.com", f"Dept {i % 10}")
                for i in range(10000)  # 10,000レコード
            ]
            
            cursor.executemany(
                "INSERT INTO users (name, email, department) VALUES (?, ?, ?)",
                test_data
            )
            conn.commit()
            
            insert_time = time.time() - start_time
            
            # クエリパフォーマンス測定
            start_time = time.time()
            
            cursor.execute("SELECT COUNT(*) FROM users")
            count_result = cursor.fetchone()[0]
            
            cursor.execute("SELECT * FROM users WHERE department = 'Dept 5' LIMIT 100")
            query_results = cursor.fetchall()
            
            query_time = time.time() - start_time
            
            conn.close()
            
            # パフォーマンス基準
            assert insert_time < 5.0, f"データ挿入時間が基準を超過: {insert_time:.2f}秒"
            assert query_time < 1.0, f"クエリ実行時間が基準を超過: {query_time:.3f}秒"
            assert count_result == 10000, f"挿入データ数が不正: {count_result}"
            
            metrics = self.monitor.get_metrics()
            
            logging.info(f"DBパフォーマンス - 挿入: {insert_time:.2f}秒, クエリ: {query_time:.3f}秒, メトリクス: {metrics}")
        
        finally:
            # テストDBファイル削除
            try:
                os.unlink(db_path)
            except:
                pass
    
    @pytest.mark.performance
    def test_file_io_performance(self):
        """ファイルI/Oパフォーマンステスト"""
        self.monitor.start_monitoring()
        
        import tempfile
        import csv
        import json
        
        # 大量データの作成
        test_data = [
            {
                "id": i,
                "name": f"User {i}",
                "email": f"user{i}@contoso.com",
                "department": f"Department {i % 10}",
                "data": f"Data {i}" * 10  # データサイズを増やす
            } for i in range(5000)  # 5,000レコード
        ]
        
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            
            # CSVファイル書き込みパフォーマンス
            csv_file = temp_path / "test_data.csv"
            start_time = time.time()
            
            with open(csv_file, 'w', newline='', encoding='utf-8-sig') as f:
                if test_data:
                    writer = csv.DictWriter(f, fieldnames=test_data[0].keys())
                    writer.writeheader()
                    writer.writerows(test_data)
            
            csv_write_time = time.time() - start_time
            
            # JSONファイル書き込みパフォーマンス
            json_file = temp_path / "test_data.json"
            start_time = time.time()
            
            with open(json_file, 'w', encoding='utf-8') as f:
                json.dump(test_data, f, ensure_ascii=False, indent=2)
            
            json_write_time = time.time() - start_time
            
            # ファイル読み込みパフォーマンス
            start_time = time.time()
            
            with open(csv_file, 'r', encoding='utf-8-sig') as f:
                csv_reader = csv.DictReader(f)
                csv_data = list(csv_reader)
            
            csv_read_time = time.time() - start_time
            
            start_time = time.time()
            
            with open(json_file, 'r', encoding='utf-8') as f:
                json_data = json.load(f)
            
            json_read_time = time.time() - start_time
            
            # パフォーマンス基準
            assert csv_write_time < 3.0, f"CSV書き込み時間が基準を超過: {csv_write_time:.2f}秒"
            assert json_write_time < 3.0, f"JSON書き込み時間が基準を超過: {json_write_time:.2f}秒"
            assert csv_read_time < 2.0, f"CSV読み込み時間が基準を超過: {csv_read_time:.2f}秒"
            assert json_read_time < 2.0, f"JSON読み込み時間が基準を超過: {json_read_time:.2f}秒"
            
            # データ整合性確認
            assert len(csv_data) == len(test_data), f"CSVデータ数が不正: {len(csv_data)}"
            assert len(json_data) == len(test_data), f"JSONデータ数が不正: {len(json_data)}"
            
            metrics = self.monitor.get_metrics()
            
            logging.info(f"File I/Oパフォーマンス - CSV書き込み: {csv_write_time:.2f}秒, "
                        f"JSON書き込み: {json_write_time:.2f}秒, "
                        f"CSV読み込み: {csv_read_time:.2f}秒, "
                        f"JSON読み込み: {json_read_time:.2f}秒")
    
    @pytest.mark.performance
    def test_cpu_intensive_operations(self):
        """CPU集約的操作パフォーマンステスト"""
        self.monitor.start_monitoring()
        
        def cpu_intensive_task(n: int) -> int:
            """CPU集約的なタスクのシミュレーション"""
            result = 0
            for i in range(n):
                result += i * i
            return result
        
        # シングルスレッド処理
        start_time = time.time()
        single_result = cpu_intensive_task(1000000)
        single_thread_time = time.time() - start_time
        
        # マルチスレッド処理
        start_time = time.time()
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
            futures = [executor.submit(cpu_intensive_task, 250000) for _ in range(4)]
            multi_results = [future.result() for future in concurrent.futures.as_completed(futures)]
        
        multi_thread_time = time.time() - start_time
        
        # パフォーマンス基準
        assert single_thread_time < 5.0, f"シングルスレッド処理時間が基準を超過: {single_thread_time:.2f}秒"
        assert multi_thread_time < 8.0, f"マルチスレッド処理時間が基準を超過: {multi_thread_time:.2f}秒"
        
        # 結果の整合性確認
        expected_result = sum(multi_results)
        assert single_result == expected_result, f"処理結果が不正: {single_result} != {expected_result}"
        
        metrics = self.monitor.get_metrics()
        
        logging.info(f"CPU集約処理パフォーマンス - シングル: {single_thread_time:.2f}秒, "
                    f"マルチ: {multi_thread_time:.2f}秒, メトリクス: {metrics}")


class TestLoadTesting:
    """負荷テストクラス"""
    
    @pytest.mark.performance
    @pytest.mark.slow
    def test_stress_test_user_creation(self):
        """ユーザー作成ストレステスト"""
        monitor = PerformanceMonitor()
        monitor.start_monitoring()
        
        # ストレステストパラメータ
        num_users = 1000
        batch_size = 100
        max_concurrent_batches = 10
        
        def create_user_batch(batch_id: int, batch_size: int) -> List[Dict[str, Any]]:
            """ユーザーバッチ作成"""
            users = []
            for i in range(batch_size):
                user_id = batch_id * batch_size + i
                users.append({
                    "id": f"user_{user_id}",
                    "displayName": f"Test User {user_id}",
                    "userPrincipalName": f"user{user_id}@contoso.com",
                    "mail": f"user{user_id}@contoso.com",
                    "department": f"Department {user_id % 10}",
                    "jobTitle": f"Position {user_id % 5}"
                })
            return users
        
        start_time = time.time()
        all_users = []
        
        # バッチ処理でユーザー作成
        num_batches = num_users // batch_size
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_concurrent_batches) as executor:
            futures = [executor.submit(create_user_batch, i, batch_size) for i in range(num_batches)]
            
            for future in concurrent.futures.as_completed(futures):
                batch_users = future.result()
                all_users.extend(batch_users)
        
        total_time = time.time() - start_time
        
        # ストレステスト基準
        assert total_time < 10.0, f"ストレステスト時間が基準を超過: {total_time:.2f}秒"
        assert len(all_users) == num_users, f"作成ユーザー数が不正: {len(all_users)}"
        
        # ユーザーIDの一意性確認
        user_ids = [user['id'] for user in all_users]
        assert len(set(user_ids)) == num_users, "重複したユーザーIDが存在します"
        
        metrics = monitor.get_metrics()
        
        # メモリ使用量が異常に高くなっていないか確認
        assert metrics['memory_increase'] < 300, f"ストレステストでメモリ使用量が異常増加: {metrics['memory_increase']:.2f}MB"
        
        throughput = num_users / total_time
        
        logging.info(f"ストレステスト結果 - 総時間: {total_time:.2f}秒, "
                    f"スループット: {throughput:.2f}ユーザー/秒, "
                    f"メトリクス: {metrics}")
    
    @pytest.mark.performance
    @pytest.mark.slow
    def test_endurance_test(self):
        """耐久テスト"""
        monitor = PerformanceMonitor()
        monitor.start_monitoring()
        
        # 耐久テストパラメータ
        test_duration = 30  # 30秒間のテスト
        operation_interval = 0.1  # 100ms間隔
        
        start_time = time.time()
        operation_count = 0
        memory_samples = []
        
        while time.time() - start_time < test_duration:
            # 模擬的な操作を実行
            data = [f"data_{i}" for i in range(100)]
            processed_data = [item.upper() for item in data]
            
            operation_count += 1
            
            # メモリ使用量を定期的にサンプリング
            if operation_count % 50 == 0:  # 50回に1回
                current_metrics = monitor.get_metrics()
                memory_samples.append(current_metrics['memory_usage'])
            
            time.sleep(operation_interval)
        
        total_time = time.time() - start_time
        final_metrics = monitor.get_metrics()
        
        # 耐久テスト基準
        # メモリリークがないことを確認
        if len(memory_samples) > 1:
            memory_trend = memory_samples[-1] - memory_samples[0]
            assert memory_trend < 50, f"メモリリークの可能性: {memory_trend:.2f}MBの増加"
        
        # パフォーマンスが一定していることを確認
        operations_per_second = operation_count / total_time
        assert operations_per_second > 5, f"パフォーマンスが低下: {operations_per_second:.2f}操作/秒"
        
        logging.info(f"耐久テスト結果 - 総時間: {total_time:.2f}秒, "
                    f"操作数: {operation_count}, "
                    f"操作/秒: {operations_per_second:.2f}, "
                    f"メモリサンプル: {len(memory_samples)}個, "
                    f"最終メトリクス: {final_metrics}")


class TestPerformanceBenchmarks:
    """パフォーマンスベンチマーククラス"""
    
    def test_performance_baseline_measurement(self):
        """パフォーマンスベースライン測定"""
        # システム情報収集
        system_info = {
            'cpu_count': psutil.cpu_count(),
            'cpu_freq': psutil.cpu_freq()._asdict() if psutil.cpu_freq() else None,
            'memory_total': psutil.virtual_memory().total / 1024 / 1024 / 1024,  # GB
            'disk_usage': psutil.disk_usage('/').free / 1024 / 1024 / 1024,  # GB
            'python_version': sys.version
        }
        
        # ベースラインパフォーマンステスト
        benchmarks = {}
        
        # CPUベンチマーク
        start_time = time.time()
        result = sum(i * i for i in range(100000))
        benchmarks['cpu_benchmark'] = time.time() - start_time
        
        # メモリベンチマーク
        start_time = time.time()
        large_list = [i for i in range(1000000)]
        benchmarks['memory_benchmark'] = time.time() - start_time
        del large_list
        
        # I/Oベンチマーク
        start_time = time.time()
        with tempfile.NamedTemporaryFile(mode='w+', delete=True) as f:
            for i in range(10000):
                f.write(f"line {i}\n")
            f.flush()
        benchmarks['io_benchmark'] = time.time() - start_time
        
        # ベンチマーク結果の保存
        benchmark_report = {
            'timestamp': datetime.now().isoformat(),
            'system_info': system_info,
            'benchmarks': benchmarks
        }
        
        # ベンチマークファイルに保存
        benchmark_file = Path(__file__).parent.parent / "reports" / "performance_baseline.json"
        benchmark_file.parent.mkdir(exist_ok=True)
        
        with open(benchmark_file, 'w', encoding='utf-8') as f:
            json.dump(benchmark_report, f, ensure_ascii=False, indent=2)
        
        # ベースライン基準の確認
        assert benchmarks['cpu_benchmark'] < 1.0, f"CPUベンチマークが低い: {benchmarks['cpu_benchmark']:.3f}秒"
        assert benchmarks['memory_benchmark'] < 0.5, f"メモリベンチマークが低い: {benchmarks['memory_benchmark']:.3f}秒"
        assert benchmarks['io_benchmark'] < 2.0, f"I/Oベンチマークが低い: {benchmarks['io_benchmark']:.3f}秒"
        
        logging.info(f"パフォーマンスベースライン: {benchmarks}")
        logging.info(f"システム情報: {system_info}")


if __name__ == '__main__':
    # パフォーマンステストの単体実行
    pytest.main([__file__, '-v', '--tb=short', '-m', 'performance'])
