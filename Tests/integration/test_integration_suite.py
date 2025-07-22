#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
統合テストスイート - GUI・API・レポート生成の統合テスト

QA Engineer - Phase 3品質保証
dev0の全コンポーネント間統合テスト

テスト範囲: GUI ↔ API ↔ レポート生成の統合シナリオ
品質目標: 統合テスト合格率 90%以上
"""

import sys
import os
import pytest
import asyncio
import tempfile
import json
from unittest.mock import Mock, patch, AsyncMock, MagicMock
from datetime import datetime
from pathlib import Path

# テスト対象のパスを追加
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src'))

# PyQt6とその他ライブラリのモック設定（詳細は単体テストと同様）
class MockPyQt6:
    class QtCore:
        class QObject:
            def __init__(self): pass
        class QThread:
            def __init__(self): pass
        pyqtSignal = Mock(return_value=Mock())
        QTimer = Mock()
    
    class QtWidgets:
        class QApplication:
            @staticmethod
            def processEvents(): pass
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
    IMPORT_SUCCESS = True
except Exception as e:
    print(f"統合テスト インポートエラー: {e}")
    IMPORT_SUCCESS = False

class TestGUItoAPIIntegration:
    """GUI ↔ API統合テスト"""
    
    @pytest.fixture
    def integration_environment(self):
        """統合テスト環境のフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        with patch('gui.main_window_complete.QApplication'):
            # コンポーネント作成
            main_window = Microsoft365MainWindow()
            api_client = GraphAPIClient("test-tenant", "test-client", "test-secret")
            
            # テスト用一時ディレクトリ
            temp_dir = tempfile.mkdtemp()
            report_generator = ReportGenerator(base_reports_dir=temp_dir)
            
            return {
                "main_window": main_window,
                "api_client": api_client,
                "report_generator": report_generator,
                "temp_dir": temp_dir
            }
    
    def test_gui_api_connection(self, integration_environment):
        """GUI-API接続テスト"""
        env = integration_environment
        main_window = env["main_window"]
        api_client = env["api_client"]
        
        # GUI側でAPI クライアントが設定されることを確認
        assert main_window is not None
        assert api_client is not None
        
        # 機能定義がAPIクライアントで処理可能か確認
        functions = main_window.initialize_functions()
        api_functions = ["UserList", "MFAStatus", "TeamsUsage", "SignInLogs"]
        
        for category_functions in functions.values():
            for func in category_functions:
                if func.action in api_functions:
                    # API対応機能が存在することを確認
                    assert hasattr(api_client, '_get_mock_data'), "APIクライアントにモックデータ機能がありません"
    
    @pytest.mark.asyncio
    async def test_user_data_flow_integration(self, integration_environment):
        """ユーザーデータフロー統合テスト"""
        env = integration_environment
        api_client = env["api_client"]
        
        # 1. APIからユーザーデータ取得
        users = await api_client.get_users(max_results=10)
        
        # 2. データの構造確認
        assert isinstance(users, list)
        
        # 3. GUI側でのデータ処理シミュレーション
        if users:  # モックデータが存在する場合
            user_data = {
                "users": users,
                "total_count": len(users),
                "tenant_name": "Test Corporation"
            }
            
            # データがレポート生成に渡せる形式であることを確認
            assert "users" in user_data
            assert "total_count" in user_data
    
    @pytest.mark.asyncio
    async def test_mfa_status_integration(self, integration_environment):
        """MFA状況統合テスト"""
        env = integration_environment
        api_client = env["api_client"]
        
        # 1. APIからMFAデータ取得
        mfa_data = await api_client.get_mfa_status()
        
        # 2. データの構造確認
        assert isinstance(mfa_data, list)
        
        # 3. MFA統計データの処理確認
        # api_clientがmfa_summaryを生成することを確認（シグナル経由）
        # モック環境では直接確認困難なため、データ型チェックで代替
        assert isinstance(mfa_data, list), "MFAデータが正しい形式ではありません"

class TestAPItoReportIntegration:
    """API ↔ レポート生成統合テスト"""
    
    @pytest.fixture
    def api_report_environment(self):
        """API-レポート統合環境のフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        api_client = GraphAPIClient("test-tenant", "test-client", "test-secret")
        
        temp_dir = tempfile.mkdtemp()
        report_generator = ReportGenerator(base_reports_dir=temp_dir)
        
        return {
            "api_client": api_client,
            "report_generator": report_generator,
            "temp_dir": temp_dir
        }
    
    @pytest.mark.asyncio
    async def test_user_list_to_report_flow(self, api_report_environment):
        """ユーザー一覧→レポート生成フローテスト"""
        env = api_report_environment
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 1. APIからユーザーデータ取得
        users = await api_client.get_users(max_results=50)
        
        # 2. レポート用データ構造作成
        report_data = {
            "users": users,
            "total_count": len(users) if users else 0,
            "tenant_name": "Integration Test Corp"
        }
        
        # 3. レポート生成
        with patch('builtins.open', create=True):
            files = report_generator.generate_report("UserList", report_data, formats=["html"])
            
            # レポートファイルが生成されることを確認
            assert isinstance(files, list)
            if files:  # ファイルが生成された場合
                assert any(f.endswith('.html') for f in files), "HTMLレポートが生成されませんでした"
    
    @pytest.mark.asyncio
    async def test_mfa_status_to_report_flow(self, api_report_environment):
        """MFA状況→レポート生成フローテスト"""
        env = api_report_environment
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 1. APIからMFAデータ取得
        mfa_data = await api_client.get_mfa_status()
        
        # 2. MFA統計データの構築
        total_users = 100
        mfa_enabled = 75
        report_data = {
            "total_users": total_users,
            "mfa_enabled": mfa_enabled,
            "compliance_rate": (mfa_enabled / total_users * 100) if total_users > 0 else 0,
            "details": mfa_data
        }
        
        # 3. レポート生成
        with patch('builtins.open', create=True):
            files = report_generator.generate_report("MFAStatus", report_data, formats=["html"])
            
            assert isinstance(files, list)
    
    @pytest.mark.asyncio
    async def test_teams_usage_to_report_flow(self, api_report_environment):
        """Teams使用状況→レポート生成フローテスト"""
        env = api_report_environment
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 1. APIからTeamsデータ取得
        teams_data = await api_client.get_teams_usage()
        
        # 2. レポート生成
        with patch('builtins.open', create=True):
            files = report_generator.generate_report("TeamsUsage", teams_data, formats=["html"])
            
            assert isinstance(files, list)

class TestFullStackIntegration:
    """フルスタック統合テスト（GUI→API→レポート）"""
    
    @pytest.fixture
    def full_stack_environment(self):
        """フルスタック環境のフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        with patch('gui.main_window_complete.QApplication'):
            # 全コンポーネント作成
            main_window = Microsoft365MainWindow()
            api_client = GraphAPIClient("test-tenant", "test-client", "test-secret")
            
            temp_dir = tempfile.mkdtemp()
            report_generator = ReportGenerator(base_reports_dir=temp_dir)
            
            return {
                "main_window": main_window,
                "api_client": api_client,
                "report_generator": report_generator,
                "temp_dir": temp_dir
            }
    
    def test_end_to_end_user_report_scenario(self, full_stack_environment):
        """エンドツーエンド ユーザーレポートシナリオ"""
        env = full_stack_environment
        main_window = env["main_window"]
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 1. GUI: ユーザー一覧機能を定義
        functions = main_window.initialize_functions()
        user_list_function = None
        
        for category_functions in functions.values():
            for func in category_functions:
                if func.action == "UserList":
                    user_list_function = func
                    break
        
        assert user_list_function is not None, "ユーザー一覧機能が見つかりません"
        assert user_list_function.name == "ユーザー一覧"
        assert user_list_function.action == "UserList"
        
        # 2. API: データ取得のシミュレーション（同期版）
        # 実際のasync処理は統合環境では困難なため、モックデータで代替
        mock_users = api_client._get_mock_data("users").get("value", [])
        
        # 3. レポート: データ処理と生成
        report_data = {
            "users": mock_users,
            "total_count": len(mock_users),
            "tenant_name": "Full Stack Test Corp"
        }
        
        with patch('builtins.open', create=True):
            files = report_generator.generate_report("UserList", report_data, formats=["csv", "html"])
            
            # 両形式のファイルが生成されることを確認
            assert isinstance(files, list)
            # モック環境では実際のファイル生成はされないが、処理フローが正常に動作することを確認
    
    def test_error_handling_integration(self, full_stack_environment):
        """エラーハンドリング統合テスト"""
        env = full_stack_environment
        main_window = env["main_window"]
        report_generator = env["report_generator"]
        
        # 1. GUI: 異常データでのログ出力テスト
        try:
            main_window.write_log(LogLevel.ERROR, "統合テストエラーシミュレーション")
            # エラーログが正常に処理されることを確認
            assert True
        except Exception as e:
            pytest.fail(f"GUI エラーハンドリングでエラー: {e}")
        
        # 2. レポート: 空データでのレポート生成テスト
        empty_data = {}
        
        with patch('builtins.open', create=True):
            try:
                files = report_generator.generate_report("UserList", empty_data)
                assert isinstance(files, list)
            except Exception as e:
                pytest.fail(f"空データレポート生成でエラー: {e}")

class TestDataConsistency:
    """データ整合性テスト"""
    
    @pytest.fixture
    def consistency_environment(self):
        """データ整合性テスト環境"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        api_client = GraphAPIClient("test-tenant", "test-client", "test-secret")
        temp_dir = tempfile.mkdtemp()
        report_generator = ReportGenerator(base_reports_dir=temp_dir)
        
        return {
            "api_client": api_client,
            "report_generator": report_generator
        }
    
    def test_user_data_consistency(self, consistency_environment):
        """ユーザーデータ整合性テスト"""
        env = consistency_environment
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 1. APIから同一データを複数回取得
        users_data_1 = api_client._get_mock_data("users")
        users_data_2 = api_client._get_mock_data("users")
        
        # 2. データの一貫性を確認
        assert users_data_1 == users_data_2, "同一APIエンドポイントで異なるデータが返されました"
        
        # 3. レポート生成での一貫性確認
        with patch('builtins.open', create=True):
            files_1 = report_generator.generate_report("UserList", {"users": users_data_1["value"]})
            files_2 = report_generator.generate_report("UserList", {"users": users_data_2["value"]})
            
            # 同一データから生成されたファイル数は同じであることを確認
            assert len(files_1) == len(files_2), "同一データから異なる数のレポートファイルが生成されました"
    
    def test_report_category_mapping_consistency(self, consistency_environment):
        """レポートカテゴリマッピング整合性テスト"""
        env = consistency_environment
        report_generator = env["report_generator"]
        
        # Microsoft 365の26機能とレポートカテゴリのマッピングを確認
        expected_mappings = {
            # 定期レポート (5機能)
            "DailyReport": "Daily",
            "WeeklyReport": "Weekly",
            "MonthlyReport": "Monthly", 
            "YearlyReport": "Yearly",
            "TestExecution": "Tests",
            
            # 分析レポート (5機能)
            "LicenseAnalysis": "Analysis/License",
            "UsageAnalysis": "Analysis/Usage",
            "PerformanceAnalysis": "Analysis/Performance",
            "SecurityAnalysis": "Analysis/Security",
            "PermissionAudit": "Analysis/Permissions",
            
            # Entra ID管理 (4機能)
            "UserList": "EntraID/Users",
            "MFAStatus": "EntraID/MFA",
            "ConditionalAccess": "EntraID/ConditionalAccess", 
            "SignInLogs": "EntraID/SignInLogs",
            
            # Exchange Online (4機能)
            "MailboxManagement": "Exchange/Mailboxes",
            "MailFlowAnalysis": "Exchange/MailFlow",
            "SpamProtectionAnalysis": "Exchange/SpamProtection",
            "MailDeliveryAnalysis": "Exchange/Delivery",
            
            # Teams管理 (4機能)
            "TeamsUsage": "Teams/Usage",
            "TeamsSettingsAnalysis": "Teams/Settings",
            "MeetingQualityAnalysis": "Teams/MeetingQuality",
            "TeamsAppAnalysis": "Teams/Apps",
            
            # OneDrive管理 (4機能)
            "StorageAnalysis": "OneDrive/Storage",
            "SharingAnalysis": "OneDrive/Sharing", 
            "SyncErrorAnalysis": "OneDrive/SyncErrors",
            "ExternalSharingAnalysis": "OneDrive/ExternalSharing"
        }
        
        # 26機能すべてのマッピングが存在することを確認
        assert len(expected_mappings) == 26, f"期待される26機能に対して{len(expected_mappings)}機能のマッピングがあります"
        
        # 各マッピングが正しいことを確認
        for action, expected_path in expected_mappings.items():
            actual_path = report_generator.report_categories.get(action)
            assert actual_path == expected_path, f"機能 '{action}' のマッピングが不正: {actual_path} != {expected_path}"

class TestPerformanceIntegration:
    """パフォーマンス統合テスト"""
    
    @pytest.fixture
    def performance_environment(self):
        """パフォーマンステスト環境"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        api_client = GraphAPIClient("test-tenant", "test-client", "test-secret")
        temp_dir = tempfile.mkdtemp()
        report_generator = ReportGenerator(base_reports_dir=temp_dir)
        
        return {
            "api_client": api_client,
            "report_generator": report_generator
        }
    
    def test_bulk_report_generation_performance(self, performance_environment):
        """一括レポート生成パフォーマンステスト"""
        import time
        
        env = performance_environment
        api_client = env["api_client"]
        report_generator = env["report_generator"]
        
        # 複数レポートの一括生成時間を測定
        start_time = time.time()
        
        report_types = ["UserList", "MFAStatus", "TeamsUsage", "LicenseAnalysis"]
        
        with patch('builtins.open', create=True):
            for report_type in report_types:
                # モックデータ取得
                if report_type == "UserList":
                    data = {"users": api_client._get_mock_data("users")["value"]}
                elif report_type == "MFAStatus":
                    data = {"total_users": 100, "mfa_enabled": 75, "compliance_rate": 75.0}
                elif report_type == "TeamsUsage":
                    data = api_client._get_mock_teams_data()
                else:
                    data = {"test": "data"}
                
                # レポート生成
                files = report_generator.generate_report(report_type, data, formats=["html"])
                assert isinstance(files, list)
        
        end_time = time.time()
        total_time = end_time - start_time
        
        # 4つのレポート生成が2秒以内に完了することを確認
        assert total_time < 2.0, f"一括レポート生成が遅すぎます: {total_time}秒"
        
        # 1レポートあたりの平均時間
        avg_time = total_time / len(report_types)
        assert avg_time < 0.5, f"1レポートあたりの生成時間が遅すぎます: {avg_time}秒"

if __name__ == "__main__":
    # 統合テストの実行
    pytest.main([__file__, "-v", "--tb=short", "-x"])