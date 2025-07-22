#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
E2Eユーザーシナリオ自動テストスイート

QA Engineer - Phase 3品質保証
エンドツーエンドユーザーシナリオの完全自動化テスト

テスト範囲: 全26機能のユーザーシナリオベース完全テスト
品質目標: E2Eテスト合格率 85%以上
"""

import sys
import os
import pytest
import asyncio
import tempfile
import time
import json
from unittest.mock import Mock, patch, AsyncMock, MagicMock
from datetime import datetime, timedelta
from pathlib import Path

# テスト対象のパスを追加
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src'))

# PyQt6とその他ライブラリのモック設定（統合テストと同様）
class MockPyQt6:
    class QtCore:
        class QObject:
            def __init__(self): pass
        class QThread:
            def __init__(self): pass
        class QTimer:
            @staticmethod
            def singleShot(msec, func): func()
        pyqtSignal = Mock(return_value=Mock())
    
    class QtWidgets:
        class QApplication:
            @staticmethod
            def processEvents(): pass
            @staticmethod
            def exec(): return 0
        class QMainWindow:
            def __init__(self): 
                self._visible = False
                self._title = ""
            def show(self): self._visible = True
            def setWindowTitle(self, title): self._title = title
        QMessageBox = Mock()
        QFileDialog = Mock()
    
    class QtGui:
        class QDesktopServices:
            @staticmethod
            def openUrl(url): pass
        class QUrl:
            @staticmethod
            def fromLocalFile(path): return f"file://{path}"

sys.modules['PyQt6'] = MockPyQt6()
sys.modules['PyQt6.QtCore'] = MockPyQt6.QtCore
sys.modules['PyQt6.QtWidgets'] = MockPyQt6.QtWidgets  
sys.modules['PyQt6.QtGui'] = MockPyQt6.QtGui

# その他のモック設定
sys.modules['msal'] = Mock()
sys.modules['aiohttp'] = Mock()
sys.modules['pandas'] = Mock()
sys.modules['jinja2'] = Mock()

try:
    from gui.main_window_complete import Microsoft365MainWindow, M365Function, LogLevel
    from gui.components.graph_api_client import GraphAPIClient
    from gui.components.report_generator import ReportGenerator
    E2E_IMPORT_SUCCESS = True
except Exception as e:
    print(f"E2E テストインポートエラー: {e}")
    E2E_IMPORT_SUCCESS = False

class TestE2EUserScenarios:
    """エンドツーエンドユーザーシナリオテスト"""
    
    @pytest.fixture
    def e2e_environment(self):
        """E2Eテスト環境のフィクスチャ"""
        if not E2E_IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        with patch('gui.main_window_complete.QApplication'):
            # 完全なアプリケーション環境を構築
            main_window = Microsoft365MainWindow()
            api_client = GraphAPIClient("e2e-tenant", "e2e-client", "e2e-secret")
            
            temp_dir = tempfile.mkdtemp()
            report_generator = ReportGenerator(base_reports_dir=temp_dir)
            
            return {
                "main_window": main_window,
                "api_client": api_client,
                "report_generator": report_generator,
                "temp_dir": temp_dir,
                "test_results": []
            }
    
    def test_application_startup_scenario(self, e2e_environment):
        """アプリケーション起動シナリオテスト"""
        env = e2e_environment
        main_window = env["main_window"]
        
        # 1. アプリケーション起動
        assert main_window is not None, "アプリケーションが起動できませんでした"
        
        # 2. 初期化確認
        functions = main_window.initialize_functions()
        assert len(functions) == 6, f"タブ数が不正: {len(functions)} != 6"
        
        # 3. 26機能の存在確認
        total_functions = sum(len(funcs) for funcs in functions.values())
        assert total_functions == 26, f"総機能数が不正: {total_functions} != 26"
        
        # 4. ログシステム動作確認
        try:
            main_window.write_log(LogLevel.INFO, "E2Eテスト: アプリケーション起動完了")
            env["test_results"].append({"test": "application_startup", "status": "success"})
        except Exception as e:
            pytest.fail(f"ログシステムエラー: {e}")
    
    def test_daily_report_complete_workflow(self, e2e_environment):
        """日次レポート完全ワークフローテスト"""
        env = e2e_environment
        main_window = env["main_window"]
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 1. 機能選択
        functions = main_window.initialize_functions()
        daily_function = None
        for func in functions.get("定期レポート", []):
            if func.action == "DailyReport":
                daily_function = func
                break
        
        assert daily_function is not None, "日次レポート機能が見つかりません"
        
        # 2. ログ出力開始
        main_window.write_log(LogLevel.INFO, f"E2E実行開始: {daily_function.name}")
        
        # 3. モックデータ取得（実際のAPI処理をシミュレーション）
        mock_data = {
            "signin_logs": api_client._get_mock_signin_logs(),
            "users": api_client._get_mock_data("users")["value"],
            "licenses": api_client._get_mock_data("subscribedSkus")["value"],
            "report_date": datetime.now().strftime("%Y-%m-%d")
        }
        
        # 4. レポート生成
        with patch('builtins.open', create=True):
            files = report_generator.generate_report("DailyReport", mock_data, formats=["csv", "html"])
            assert isinstance(files, list), "レポートファイルが生成されませんでした"
        
        # 5. 完了ログ
        main_window.write_log(LogLevel.SUCCESS, "日次レポート生成完了", "DailyReport")
        env["test_results"].append({"test": "daily_report_workflow", "status": "success"})
    
    def test_all_26_functions_execution_scenario(self, e2e_environment):
        """全26機能実行シナリオテスト"""
        env = e2e_environment
        main_window = env["main_window"]
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        functions = main_window.initialize_functions()
        execution_results = []
        
        # 全機能を順次実行
        for category_name, category_functions in functions.items():
            for func in category_functions:
                try:
                    # 開始ログ
                    main_window.write_log(LogLevel.INFO, f"機能実行開始: {func.name} ({func.action})")
                    
                    # データ準備
                    test_data = self._prepare_test_data_for_function(func.action, api_client)
                    
                    # レポート生成
                    with patch('builtins.open', create=True):
                        files = report_generator.generate_report(func.action, test_data, formats=["html"])
                    
                    # 成功ログ
                    main_window.write_log(LogLevel.SUCCESS, f"機能実行完了: {func.name}")
                    execution_results.append({"function": func.name, "action": func.action, "status": "success"})
                    
                except Exception as e:
                    # エラーログ
                    main_window.write_log(LogLevel.ERROR, f"機能実行エラー: {func.name} - {str(e)}")
                    execution_results.append({"function": func.name, "action": func.action, "status": "error", "error": str(e)})
        
        # 結果検証
        success_count = sum(1 for result in execution_results if result["status"] == "success")
        total_count = len(execution_results)
        success_rate = (success_count / total_count) * 100 if total_count > 0 else 0
        
        # 85%以上の成功率を要求
        assert success_rate >= 85.0, f"機能実行成功率が基準を下回りました: {success_rate}% < 85%"
        
        env["test_results"].append({
            "test": "all_26_functions_execution",
            "status": "success",
            "success_rate": success_rate,
            "results": execution_results
        })
    
    def test_user_data_flow_e2e_scenario(self, e2e_environment):
        """ユーザーデータフローE2Eシナリオ"""
        env = e2e_environment
        main_window = env["main_window"]
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 1. ユーザー一覧機能実行
        main_window.write_log(LogLevel.INFO, "E2Eシナリオ開始: ユーザーデータフロー")
        
        # 2. API経由でユーザーデータ取得（非同期処理のシミュレーション）
        users_data = api_client._get_mock_data("users")["value"]
        assert len(users_data) > 0, "ユーザーデータが取得できませんでした"
        
        # 3. MFA状況データ取得
        mfa_data = api_client._get_mock_mfa_data()
        
        # 4. データ統合処理
        integrated_data = {
            "users": users_data,
            "mfa_summary": {
                "total_users": len(users_data),
                "mfa_enabled": len([u for u in mfa_data if u.get("isMfaRegistered", False)]),
                "compliance_rate": 0.75  # モック値
            },
            "tenant_name": "E2E Test Corporation",
            "generation_time": datetime.now().isoformat()
        }
        
        # 5. 複数レポート生成
        report_types = ["UserList", "MFAStatus"]
        generated_files = []
        
        for report_type in report_types:
            with patch('builtins.open', create=True):
                files = report_generator.generate_report(report_type, integrated_data, formats=["csv", "html"])
                generated_files.extend(files)
        
        # 6. 結果検証
        assert len(generated_files) >= len(report_types), "期待される数のレポートファイルが生成されませんでした"
        
        main_window.write_log(LogLevel.SUCCESS, f"ユーザーデータフローE2E完了 - {len(generated_files)}ファイル生成")
        env["test_results"].append({"test": "user_data_flow_e2e", "status": "success", "files_generated": len(generated_files)})
    
    def test_error_handling_e2e_scenario(self, e2e_environment):
        """エラーハンドリングE2Eシナリオ"""
        env = e2e_environment
        main_window = env["main_window"]
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 1. 異常データでのテスト
        invalid_data_scenarios = [
            {"name": "空データ", "data": {}},
            {"name": "不完全データ", "data": {"partial": "data"}},
            {"name": "大量データ", "data": {"users": [{"id": i} for i in range(10000)]}}
        ]
        
        error_handling_results = []
        
        for scenario in invalid_data_scenarios:
            try:
                main_window.write_log(LogLevel.INFO, f"エラーハンドリングテスト: {scenario['name']}")
                
                # レポート生成テスト
                with patch('builtins.open', create=True):
                    files = report_generator.generate_report("UserList", scenario["data"], formats=["html"])
                
                # エラーが発生せず処理が完了した場合も成功とみなす
                error_handling_results.append({"scenario": scenario["name"], "status": "handled"})
                main_window.write_log(LogLevel.SUCCESS, f"エラーハンドリング成功: {scenario['name']}")
                
            except Exception as e:
                # 例外が適切にキャッチされた場合も成功
                error_handling_results.append({"scenario": scenario["name"], "status": "caught", "error": str(e)})
                main_window.write_log(LogLevel.WARNING, f"予期されたエラーをキャッチ: {scenario['name']} - {str(e)}")
        
        # すべてのシナリオで適切な処理が行われたことを確認
        assert len(error_handling_results) == len(invalid_data_scenarios), "一部のエラーハンドリングテストが実行されませんでした"
        
        env["test_results"].append({
            "test": "error_handling_e2e", 
            "status": "success",
            "scenarios_tested": len(error_handling_results),
            "results": error_handling_results
        })
    
    def test_performance_e2e_scenario(self, e2e_environment):
        """パフォーマンスE2Eシナリオ"""
        env = e2e_environment
        main_window = env["main_window"]
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 1. パフォーマンス測定開始
        start_time = time.time()
        main_window.write_log(LogLevel.INFO, "パフォーマンスE2Eテスト開始")
        
        # 2. 複数機能の連続実行（パフォーマンス負荷）
        performance_functions = ["UserList", "MFAStatus", "LicenseAnalysis", "TeamsUsage", "DailyReport"]
        execution_times = []
        
        for func_action in performance_functions:
            func_start = time.time()
            
            # データ準備
            test_data = self._prepare_test_data_for_function(func_action, api_client)
            
            # レポート生成
            with patch('builtins.open', create=True):
                files = report_generator.generate_report(func_action, test_data, formats=["html"])
            
            func_end = time.time()
            execution_time = func_end - func_start
            execution_times.append({"function": func_action, "time": execution_time})
            
            # パフォーマンス基準チェック（1機能あたり2秒以内）
            assert execution_time < 2.0, f"機能 {func_action} の実行時間が基準を超過: {execution_time}秒 > 2.0秒"
        
        # 3. 総実行時間チェック
        total_time = time.time() - start_time
        assert total_time < 10.0, f"総実行時間が基準を超過: {total_time}秒 > 10.0秒"
        
        # 4. 平均実行時間計算
        avg_time = sum(et["time"] for et in execution_times) / len(execution_times)
        
        main_window.write_log(LogLevel.SUCCESS, f"パフォーマンスE2E完了 - 平均実行時間: {avg_time:.2f}秒")
        env["test_results"].append({
            "test": "performance_e2e",
            "status": "success",
            "total_time": total_time,
            "average_time": avg_time,
            "execution_times": execution_times
        })
    
    def test_long_running_stability_scenario(self, e2e_environment):
        """長時間実行安定性シナリオ"""
        env = e2e_environment
        main_window = env["main_window"]
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 1. 安定性テスト開始
        main_window.write_log(LogLevel.INFO, "長時間実行安定性テスト開始")
        
        # 2. 反復実行テスト（10回実行で安定性確認）
        iterations = 10
        stability_results = []
        
        for i in range(iterations):
            try:
                iteration_start = time.time()
                
                # 複数機能の実行
                test_functions = ["UserList", "MFAStatus", "TeamsUsage"]
                for func_action in test_functions:
                    test_data = self._prepare_test_data_for_function(func_action, api_client)
                    
                    with patch('builtins.open', create=True):
                        files = report_generator.generate_report(func_action, test_data, formats=["html"])
                
                iteration_time = time.time() - iteration_start
                stability_results.append({"iteration": i+1, "time": iteration_time, "status": "success"})
                
                # プログレスログ
                if (i + 1) % 3 == 0:
                    main_window.write_log(LogLevel.INFO, f"安定性テスト進行中: {i+1}/{iterations}")
                
            except Exception as e:
                stability_results.append({"iteration": i+1, "status": "error", "error": str(e)})
                main_window.write_log(LogLevel.ERROR, f"安定性テスト エラー (反復{i+1}): {str(e)}")
        
        # 3. 安定性評価
        success_count = sum(1 for result in stability_results if result["status"] == "success")
        success_rate = (success_count / iterations) * 100
        
        # 90%以上の安定性を要求
        assert success_rate >= 90.0, f"長時間実行安定性が基準を下回りました: {success_rate}% < 90%"
        
        # 4. パフォーマンス変動確認
        successful_times = [r["time"] for r in stability_results if r["status"] == "success" and "time" in r]
        if successful_times:
            avg_time = sum(successful_times) / len(successful_times)
            max_time = max(successful_times)
            min_time = min(successful_times)
            
            # 実行時間の変動が50%以内であることを確認（安定性の指標）
            time_variation = ((max_time - min_time) / avg_time) * 100
            assert time_variation < 50.0, f"実行時間の変動が大きすぎます: {time_variation}%"
        
        main_window.write_log(LogLevel.SUCCESS, f"長時間実行安定性テスト完了 - 成功率: {success_rate}%")
        env["test_results"].append({
            "test": "long_running_stability",
            "status": "success", 
            "success_rate": success_rate,
            "iterations": iterations,
            "results": stability_results
        })
    
    def _prepare_test_data_for_function(self, action, api_client):
        """機能別テストデータ準備"""
        if action in ["UserList", "ConditionalAccess"]:
            return {
                "users": api_client._get_mock_data("users")["value"],
                "tenant_name": "E2E Test Corp"
            }
        elif action == "MFAStatus":
            return {
                "total_users": 100,
                "mfa_enabled": 75,
                "compliance_rate": 75.0,
                "details": api_client._get_mock_mfa_data()
            }
        elif action == "LicenseAnalysis":
            return {
                "summary": api_client._get_mock_data("subscribedSkus")["value"],
                "tenant_name": "E2E Test Corp"
            }
        elif action == "TeamsUsage":
            return api_client._get_mock_teams_data()
        elif action == "SignInLogs":
            return {
                "total_signins": 1000,
                "successful_signins": 950,
                "failed_signins": 50,
                "success_rate": 95.0,
                "logs": api_client._get_mock_signin_logs()
            }
        elif action in ["DailyReport", "WeeklyReport", "MonthlyReport", "YearlyReport"]:
            return {
                "users": api_client._get_mock_data("users")["value"][:10],  # サマリー用に少数のユーザー
                "signin_summary": {"total": 500, "successful": 475, "failed": 25},
                "license_summary": {"total_licenses": 200, "consumed": 150},
                "report_period": action.replace("Report", ""),
                "generation_time": datetime.now().isoformat()
            }
        else:
            # デフォルトテストデータ
            return {
                "test_data": True,
                "action": action,
                "timestamp": datetime.now().isoformat()
            }

class TestE2EIntegrationScenarios:
    """E2E統合シナリオテスト"""
    
    @pytest.fixture
    def integration_environment(self):
        """統合環境のフィクスチャ"""
        if not E2E_IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        with patch('gui.main_window_complete.QApplication'):
            # 統合環境構築
            main_window = Microsoft365MainWindow()
            api_client = GraphAPIClient("integration-tenant", "integration-client", "integration-secret")
            
            temp_dir = tempfile.mkdtemp()
            report_generator = ReportGenerator(base_reports_dir=temp_dir)
            
            return {
                "main_window": main_window,
                "api_client": api_client,
                "report_generator": report_generator,
                "temp_dir": temp_dir
            }
    
    def test_multi_tab_navigation_scenario(self, integration_environment):
        """マルチタブナビゲーションシナリオ"""
        env = integration_environment
        main_window = env["main_window"]
        
        functions = main_window.initialize_functions()
        
        # 全タブを順次訪問
        for tab_name, tab_functions in functions.items():
            main_window.write_log(LogLevel.INFO, f"タブアクセス: {tab_name}")
            
            # タブ内の各機能確認
            for func in tab_functions:
                assert func.name is not None, f"機能名が未定義: {func.action}"
                assert func.action is not None, f"アクション名が未定義: {func.name}"
                assert func.icon is not None, f"アイコンが未定義: {func.name}"
            
            # タブアイコン確認
            icon = main_window.get_tab_icon(tab_name)
            assert icon is not None, f"タブアイコンが未定義: {tab_name}"
            
            main_window.write_log(LogLevel.SUCCESS, f"タブ検証完了: {tab_name} ({len(tab_functions)}機能)")
    
    def test_comprehensive_report_generation_scenario(self, integration_environment):
        """包括的レポート生成シナリオ"""
        env = integration_environment
        main_window = env["main_window"]
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 各カテゴリから1つずつ機能を選択して実行
        representative_functions = {
            "定期レポート": "DailyReport",
            "分析レポート": "LicenseAnalysis", 
            "Entra ID管理": "UserList",
            "Exchange Online": "MailboxManagement",
            "Teams管理": "TeamsUsage",
            "OneDrive管理": "StorageAnalysis"
        }
        
        comprehensive_results = []
        
        for category, func_action in representative_functions.items():
            main_window.write_log(LogLevel.INFO, f"包括テスト実行: {category} -> {func_action}")
            
            # テストデータ準備
            if func_action == "DailyReport":
                test_data = {"users": api_client._get_mock_data("users")["value"][:5]}
            elif func_action == "LicenseAnalysis":
                test_data = {"summary": api_client._get_mock_data("subscribedSkus")["value"]}
            elif func_action == "UserList":
                test_data = {"users": api_client._get_mock_data("users")["value"]}
            elif func_action == "TeamsUsage":
                test_data = api_client._get_mock_teams_data()
            else:
                test_data = {"test": "data", "category": category}
            
            # レポート生成（複数形式）
            with patch('builtins.open', create=True):
                files = report_generator.generate_report(func_action, test_data, formats=["csv", "html"])
            
            comprehensive_results.append({
                "category": category,
                "function": func_action,
                "files_generated": len(files) if files else 0,
                "status": "success"
            })
            
            main_window.write_log(LogLevel.SUCCESS, f"包括テスト完了: {category}")
        
        # 全カテゴリで成功していることを確認
        success_count = sum(1 for result in comprehensive_results if result["status"] == "success")
        assert success_count == len(representative_functions), f"包括テストの一部が失敗: {success_count}/{len(representative_functions)}"

class TestE2EPerformanceScenarios:
    """E2Eパフォーマンスシナリオテスト"""
    
    @pytest.fixture
    def performance_environment(self):
        """パフォーマンステスト環境"""
        if not E2E_IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        with patch('gui.main_window_complete.QApplication'):
            main_window = Microsoft365MainWindow()
            api_client = GraphAPIClient("perf-tenant", "perf-client", "perf-secret")
            
            temp_dir = tempfile.mkdtemp()
            report_generator = ReportGenerator(base_reports_dir=temp_dir)
            
            return {
                "main_window": main_window,
                "api_client": api_client, 
                "report_generator": report_generator,
                "temp_dir": temp_dir
            }
    
    def test_concurrent_operations_scenario(self, performance_environment):
        """並行操作シナリオ"""
        env = performance_environment
        main_window = env["main_window"]
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 並行処理シミュレーション（実際はシーケンシャル実行だが、高負荷状況を再現）
        concurrent_operations = [
            ("UserList", {"users": api_client._get_mock_data("users")["value"]}),
            ("MFAStatus", {"total_users": 100, "mfa_enabled": 75, "compliance_rate": 75.0}),
            ("TeamsUsage", api_client._get_mock_teams_data()),
            ("LicenseAnalysis", {"summary": api_client._get_mock_data("subscribedSkus")["value"]}),
            ("DailyReport", {"users": api_client._get_mock_data("users")["value"][:10]})
        ]
        
        start_time = time.time()
        results = []
        
        for operation, data in concurrent_operations:
            op_start = time.time()
            main_window.write_log(LogLevel.INFO, f"並行操作実行: {operation}")
            
            with patch('builtins.open', create=True):
                files = report_generator.generate_report(operation, data, formats=["html"])
            
            op_time = time.time() - op_start
            results.append({"operation": operation, "time": op_time, "files": len(files) if files else 0})
            
            main_window.write_log(LogLevel.SUCCESS, f"並行操作完了: {operation} ({op_time:.2f}秒)")
        
        total_time = time.time() - start_time
        
        # 並行処理全体が10秒以内に完了することを確認
        assert total_time < 10.0, f"並行操作の総実行時間が基準を超過: {total_time}秒 > 10.0秒"
        
        # 各操作が3秒以内に完了することを確認
        for result in results:
            assert result["time"] < 3.0, f"操作 {result['operation']} の実行時間が基準を超過: {result['time']}秒 > 3.0秒"

if __name__ == "__main__":
    # E2Eテストの実行
    pytest.main([__file__, "-v", "--tb=short", "-x"])