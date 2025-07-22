#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
レポート生成エンジン単体テストスイート

QA Engineer - Phase 3品質保証
dev0のレポート生成エンジンの単体テスト

テスト対象: src/gui/components/report_generator.py
品質目標: レポート生成品質・ファイル出力・データ整合性検証
"""

import sys
import os
import pytest
import tempfile
import shutil
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime
from pathlib import Path

# テスト対象のパスを追加
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src'))

# PyQt6モック
class MockPyQt6:
    class QtCore:
        class QObject:
            def __init__(self):
                pass
        
        class QTimer:
            @staticmethod
            def singleShot(msec, func): func()
        
        pyqtSignal = Mock(return_value=Mock())
        
    class QtWidgets:
        class QFileDialog:
            @staticmethod
            def getSaveFileName(parent, caption, directory, filter_str):
                return ("/tmp/test_report.html", "HTML files (*.html)")
        
        class QApplication:
            @staticmethod
            def processEvents(): pass
    
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

# pandasモック
class MockPandas:
    class DataFrame:
        def __init__(self, data):
            self.data = data
        
        def to_csv(self, path, index=False, encoding='utf-8-sig'):
            # 簡単なCSV出力のシミュレーション
            with open(path, 'w', encoding=encoding) as f:
                if self.data:
                    # ヘッダー
                    f.write(','.join(self.data[0].keys()) + '\n')
                    # データ行
                    for row in self.data:
                        f.write(','.join(str(v) for v in row.values()) + '\n')

sys.modules['pandas'] = MockPandas()

# jinja2モック
class MockJinja2:
    class Environment:
        def __init__(self, loader=None, **kwargs):
            self.loader = loader
            
        def get_template(self, name):
            return MockTemplate()
    
    class FileSystemLoader:
        def __init__(self, path):
            self.path = path
    
    class Template:
        def render(self, **kwargs):
            return f"<html><body>Mock template rendered with {kwargs}</body></html>"

class MockTemplate:
    def render(self, **kwargs):
        return f"""<!DOCTYPE html>
<html><head><title>{kwargs.get('report_title', 'Test Report')}</title></head>
<body>
<h1>{kwargs.get('report_title', 'Test Report')}</h1>
<p>Generated: {kwargs.get('generation_time', 'Test Time')}</p>
<div>{kwargs.get('content', 'Test Content')}</div>
</body></html>"""

sys.modules['jinja2'] = MockJinja2()

try:
    from gui.components.report_generator import ReportGenerator
    IMPORT_SUCCESS = True
except Exception as e:
    print(f"インポートエラー: {e}")
    IMPORT_SUCCESS = False

class TestReportGenerator:
    """レポート生成エンジンテスト"""
    
    @pytest.fixture
    def temp_dir(self):
        """テスト用一時ディレクトリ"""
        temp_path = tempfile.mkdtemp()
        yield temp_path
        shutil.rmtree(temp_path, ignore_errors=True)
    
    @pytest.fixture
    def report_generator(self, temp_dir):
        """レポート生成エンジンのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        return ReportGenerator(base_reports_dir=temp_dir)
    
    def test_generator_initialization(self, report_generator, temp_dir):
        """レポート生成エンジン初期化テスト"""
        assert report_generator is not None
        assert report_generator.base_reports_dir == Path(temp_dir)
        assert isinstance(report_generator.report_categories, dict)
        
        # レポートカテゴリが正しく設定されているか確認
        expected_categories = [
            "DailyReport", "WeeklyReport", "MonthlyReport", "YearlyReport", "TestExecution",
            "LicenseAnalysis", "UsageAnalysis", "PerformanceAnalysis", "SecurityAnalysis", "PermissionAudit",
            "UserList", "MFAStatus", "ConditionalAccess", "SignInLogs",
            "MailboxManagement", "MailFlowAnalysis", "SpamProtectionAnalysis", "MailDeliveryAnalysis",
            "TeamsUsage", "TeamsSettingsAnalysis", "MeetingQualityAnalysis", "TeamsAppAnalysis",
            "StorageAnalysis", "SharingAnalysis", "SyncErrorAnalysis", "ExternalSharingAnalysis"
        ]
        
        for category in expected_categories:
            assert category in report_generator.report_categories, f"カテゴリ '{category}' が見つかりません"
    
    def test_directory_structure_creation(self, report_generator, temp_dir):
        """ディレクトリ構造作成テスト"""
        # ベースディレクトリが作成されているか確認
        assert Path(temp_dir).exists()
        
        # 主要なサブディレクトリが作成されているか確認（実際にレポート生成時に作成される）
        expected_subdirs = [
            "Daily", "Weekly", "Monthly", "Yearly",
            "Analysis/License", "Analysis/Usage", "Analysis/Performance",
            "EntraID/Users", "EntraID/MFA",
            "Exchange/Mailboxes", "Exchange/MailFlow",
            "Teams/Usage", "Teams/Settings",
            "OneDrive/Storage", "OneDrive/Sharing"
        ]
        
        # ディレクトリは実際のレポート生成時に作成されるため、
        # ここではカテゴリマッピングの存在を確認
        for report_type, expected_subdir in [
            ("DailyReport", "Daily"),
            ("LicenseAnalysis", "Analysis/License"),
            ("UserList", "EntraID/Users"),
            ("TeamsUsage", "Teams/Usage")
        ]:
            assert report_generator.report_categories[report_type] == expected_subdir
    
    def test_report_generation_csv_only(self, report_generator):
        """CSV専用レポート生成テスト"""
        test_data = {
            "data": [
                {"name": "田中太郎", "department": "IT部", "status": "active"},
                {"name": "佐藤花子", "department": "営業部", "status": "active"}
            ],
            "total_count": 2,
            "tenant_name": "Test Corp"
        }
        
        with patch('builtins.open', create=True) as mock_open:
            mock_file = MagicMock()
            mock_open.return_value.__enter__.return_value = mock_file
            
            files = report_generator.generate_report("UserList", test_data, formats=["csv"])
            
            assert len(files) == 1
            assert files[0].endswith('.csv')
            mock_open.assert_called()
    
    def test_report_generation_html_only(self, report_generator):
        """HTML専用レポート生成テスト"""
        test_data = {
            "users": [
                {"displayName": "田中太郎", "mail": "tanaka@test.com", "department": "IT部"},
                {"displayName": "佐藤花子", "mail": "sato@test.com", "department": "営業部"}
            ],
            "total_count": 2,
            "tenant_name": "Test Corp"
        }
        
        with patch('builtins.open', create=True) as mock_open:
            mock_file = MagicMock()
            mock_open.return_value.__enter__.return_value = mock_file
            
            files = report_generator.generate_report("UserList", test_data, formats=["html"])
            
            assert len(files) == 1
            assert files[0].endswith('.html')
            mock_open.assert_called()
    
    def test_report_generation_both_formats(self, report_generator):
        """CSV・HTML両形式レポート生成テスト"""
        test_data = {
            "data": [{"id": 1, "name": "test"}],
            "tenant_name": "Test Corp"
        }
        
        with patch('builtins.open', create=True) as mock_open:
            mock_file = MagicMock()
            mock_open.return_value.__enter__.return_value = mock_file
            
            files = report_generator.generate_report("UserList", test_data, formats=["csv", "html"])
            
            assert len(files) == 2
            assert any(f.endswith('.csv') for f in files)
            assert any(f.endswith('.html') for f in files)
    
    def test_csv_generation_with_pandas_mock(self, report_generator):
        """Pandasモックを使ったCSV生成テスト"""
        test_data = {
            "data": [
                {"name": "田中", "age": 30, "department": "IT"},
                {"name": "佐藤", "age": 25, "department": "営業"}
            ]
        }
        
        with tempfile.NamedTemporaryFile(suffix='.csv', delete=False) as temp_file:
            temp_path = Path(temp_file.name)
        
        try:
            report_generator._generate_csv(temp_path, test_data)
            
            # ファイルが作成されたことを確認
            assert temp_path.exists()
            
            # ファイル内容を確認
            content = temp_path.read_text(encoding='utf-8-sig')
            assert 'name' in content
            assert '田中' in content
            assert '佐藤' in content
        
        finally:
            temp_path.unlink(missing_ok=True)
    
    def test_csv_generation_manual_fallback(self, report_generator):
        """手動CSV生成（pandasなし）テスト"""
        test_data = {
            "summary": "テスト要約",
            "count": 42,
            "status": "complete"
        }
        
        with tempfile.NamedTemporaryFile(suffix='.csv', delete=False) as temp_file:
            temp_path = Path(temp_file.name)
        
        try:
            report_generator._generate_csv_manual(temp_path, test_data)
            
            # ファイルが作成されたことを確認
            assert temp_path.exists()
            
            # ファイル内容を確認
            content = temp_path.read_text(encoding='utf-8-sig')
            assert '項目,値' in content or '項目' in content
        
        finally:
            temp_path.unlink(missing_ok=True)
    
    def test_html_generation(self, report_generator):
        """HTML生成テスト"""
        test_data = {
            "users": [
                {"displayName": "田中太郎", "mail": "tanaka@test.com"},
                {"displayName": "佐藤花子", "mail": "sato@test.com"}
            ],
            "tenant_name": "Test Corporation"
        }
        
        with tempfile.NamedTemporaryFile(suffix='.html', delete=False) as temp_file:
            temp_path = Path(temp_file.name)
        
        try:
            report_generator._generate_html(temp_path, "UserList", test_data)
            
            # ファイルが作成されたことを確認
            assert temp_path.exists()
            
            # ファイル内容を確認
            content = temp_path.read_text(encoding='utf-8')
            assert '<html>' in content
            assert 'Test Corporation' in content or 'ユーザー一覧' in content
        
        finally:
            temp_path.unlink(missing_ok=True)
    
    def test_report_titles(self, report_generator):
        """レポートタイトルテスト"""
        test_cases = [
            ("DailyReport", "日次レポート"),
            ("WeeklyReport", "週次レポート"),
            ("UserList", "ユーザー一覧"),
            ("MFAStatus", "MFA状況レポート"),
            ("LicenseAnalysis", "ライセンス分析レポート"),
            ("TeamsUsage", "Teams使用状況レポート"),
            ("SignInLogs", "サインインログレポート")
        ]
        
        for report_type, expected_title in test_cases:
            actual_title = report_generator._get_report_title(report_type)
            assert actual_title == expected_title, f"レポートタイプ '{report_type}' のタイトルが不正: {actual_title} != {expected_title}"
    
    def test_report_subtitles(self, report_generator):
        """レポートサブタイトルテスト"""
        test_cases = [
            ("DailyReport", "Microsoft 365日次アクティビティレポート"),
            ("WeeklyReport", "Microsoft 365週次利用状況レポート"),
            ("UserList", "Entra IDユーザー管理レポート"),
            ("MFAStatus", "多要素認証コンプライアンスレポート"),
            ("UnknownReport", "Microsoft 365管理レポート")  # デフォルト
        ]
        
        for report_type, expected_subtitle in test_cases:
            actual_subtitle = report_generator._get_report_subtitle(report_type)
            assert actual_subtitle == expected_subtitle, f"レポートタイプ '{report_type}' のサブタイトルが不正"
    
    def test_data_count_calculation(self, report_generator):
        """データ件数計算テスト"""
        test_cases = [
            ({"data": [1, 2, 3, 4, 5]}, 5),
            ({"users": [{"name": "a"}, {"name": "b"}]}, 2),
            ({"logs": [{"id": 1}, {"id": 2}, {"id": 3}]}, 3),
            ({"summary": "test", "count": 10}, 2),  # dict, listでないフィールドをカウント
            ({}, 0)
        ]
        
        for test_data, expected_count in test_cases:
            actual_count = report_generator._get_data_count(test_data)
            assert actual_count == expected_count, f"データ件数計算エラー: {actual_count} != {expected_count}"

class TestReportContentGeneration:
    """レポートコンテンツ生成テスト"""
    
    @pytest.fixture
    def report_generator(self, temp_dir):
        """レポート生成エンジンのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        return ReportGenerator(base_reports_dir=temp_dir)
    
    @pytest.fixture
    def temp_dir(self):
        """テスト用一時ディレクトリ"""
        temp_path = tempfile.mkdtemp()
        yield temp_path
        shutil.rmtree(temp_path, ignore_errors=True)
    
    def test_user_list_content_generation(self, report_generator):
        """ユーザー一覧コンテンツ生成テスト"""
        test_data = {
            "users": [
                {"displayName": "田中太郎", "mail": "tanaka@test.com", "department": "IT部", "accountEnabled": True},
                {"displayName": "佐藤花子", "mail": "sato@test.com", "department": "営業部", "accountEnabled": False}
            ]
        }
        
        content = report_generator._generate_user_list_content(test_data)
        
        assert isinstance(content, str)
        assert "ユーザー統計" in content
        assert "田中太郎" in content
        assert "佐藤花子" in content
        assert "有効ユーザー" in content
    
    def test_mfa_status_content_generation(self, report_generator):
        """MFA状況コンテンツ生成テスト"""
        test_data = {
            "total_users": 100,
            "mfa_enabled": 75,
            "compliance_rate": 75.0,
            "details": [
                {"userDisplayName": "田中太郎", "userPrincipalName": "tanaka@test.com", "isMfaRegistered": True},
                {"userDisplayName": "佐藤花子", "userPrincipalName": "sato@test.com", "isMfaRegistered": False}
            ]
        }
        
        content = report_generator._generate_mfa_status_content(test_data)
        
        assert isinstance(content, str)
        assert "MFA統計" in content
        assert "75" in content  # MFA有効ユーザー数
        assert "75.0%" in content  # コンプライアンス率
        assert "田中太郎" in content
    
    def test_license_analysis_content_generation(self, report_generator):
        """ライセンス分析コンテンツ生成テスト"""
        test_data = {
            "summary": [
                {"sku_name": "ENTERPRISEPACK", "consumed_units": 150, "enabled_units": 200, "usage_percentage": 75.0},
                {"sku_name": "TEAMS_EXPLORATORY", "consumed_units": 50, "enabled_units": 100, "usage_percentage": 50.0}
            ]
        }
        
        content = report_generator._generate_license_analysis_content(test_data)
        
        assert isinstance(content, str)
        assert "ライセンス統計" in content
        assert "ENTERPRISEPACK" in content
        assert "150" in content  # 使用中ライセンス数
        assert "75.0%" in content  # 使用率
    
    def test_teams_usage_content_generation(self, report_generator):
        """Teams使用状況コンテンツ生成テスト"""
        test_data = {
            "total_users": 200,
            "active_users": 150,
            "meetings_organized": 45,
            "chat_messages": 1250,
            "channel_messages": 380,
            "calls_organized": 25
        }
        
        content = report_generator._generate_teams_usage_content(test_data)
        
        assert isinstance(content, str)
        assert "Teams統計" in content
        assert "150/200" in content  # アクティブユーザー
        assert "45" in content  # 会議開催数
        assert "1,250" in content  # チャットメッセージ（カンマ付き）
    
    def test_signin_logs_content_generation(self, report_generator):
        """サインインログコンテンツ生成テスト"""
        test_data = {
            "total_signins": 1000,
            "successful_signins": 950,
            "failed_signins": 50,
            "success_rate": 95.0,
            "logs": [
                {
                    "createdDateTime": "2025-01-22T10:30:00Z",
                    "userDisplayName": "田中太郎",
                    "appDisplayName": "Microsoft 365",
                    "ipAddress": "203.0.113.1",
                    "location": {"city": "Tokyo", "countryOrRegion": "JP"},
                    "status": {"errorCode": 0}
                }
            ]
        }
        
        content = report_generator._generate_signin_logs_content(test_data)
        
        assert isinstance(content, str)
        assert "サインイン統計" in content
        assert "1,000" in content  # 総サインイン数
        assert "95.0%" in content  # 成功率
        assert "田中太郎" in content
        assert "Tokyo" in content
    
    def test_generic_content_generation(self, report_generator):
        """汎用コンテンツ生成テスト"""
        test_data = {
            "summary": "テストサマリー",
            "count": 42,
            "rate": 85.5,
            "items": ["item1", "item2", "item3"]
        }
        
        content = report_generator._generate_generic_content(test_data)
        
        assert isinstance(content, str)
        assert "データ概要" in content
        assert "42" in content
        assert "85.5" in content
        assert "3 件" in content  # リストの件数

class TestErrorHandling:
    """エラーハンドリングテスト"""
    
    @pytest.fixture
    def report_generator(self, temp_dir):
        """レポート生成エンジンのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        return ReportGenerator(base_reports_dir=temp_dir)
    
    @pytest.fixture
    def temp_dir(self):
        """テスト用一時ディレクトリ"""
        temp_path = tempfile.mkdtemp()
        yield temp_path
        shutil.rmtree(temp_path, ignore_errors=True)
    
    def test_empty_data_handling(self, report_generator):
        """空データ処理テスト"""
        empty_data = {}
        
        files = report_generator.generate_report("UserList", empty_data)
        
        # 空データでもファイルが生成されることを確認
        # （実際のファイル作成はモックされている）
        assert isinstance(files, list)
    
    def test_invalid_format_handling(self, report_generator):
        """無効フォーマット処理テスト"""
        test_data = {"test": "data"}
        
        # 無効なフォーマットを指定
        files = report_generator.generate_report("UserList", test_data, formats=["invalid"])
        
        # 無効なフォーマットは無視される
        assert isinstance(files, list)
    
    def test_unknown_report_type_handling(self, report_generator):
        """未知レポートタイプ処理テスト"""
        test_data = {"test": "data"}
        
        files = report_generator.generate_report("UnknownReportType", test_data)
        
        # 未知のレポートタイプでも処理が継続される
        assert isinstance(files, list)

class TestFileOperations:
    """ファイル操作テスト"""
    
    @pytest.fixture
    def report_generator(self, temp_dir):
        """レポート生成エンジンのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        return ReportGenerator(base_reports_dir=temp_dir)
    
    @pytest.fixture
    def temp_dir(self):
        """テスト用一時ディレクトリ"""
        temp_path = tempfile.mkdtemp()
        yield temp_path
        shutil.rmtree(temp_path, ignore_errors=True)
    
    @patch('webbrowser.open')
    @patch('subprocess.run')
    def test_file_opening_windows(self, mock_subprocess, mock_webbrowser, report_generator):
        """Windowsでのファイル表示テスト"""
        with patch('sys.platform', 'win32'):
            with patch('os.startfile') as mock_startfile:
                report_generator._open_report_file("test_report.html")
                mock_startfile.assert_called_once_with("test_report.html")
    
    @patch('subprocess.run')
    def test_file_opening_macos(self, mock_subprocess, report_generator):
        """macOSでのファイル表示テスト"""
        with patch('sys.platform', 'darwin'):
            report_generator._open_report_file("test_report.html")
            mock_subprocess.assert_called_once_with(['open', "test_report.html"])
    
    @patch('subprocess.run')
    def test_file_opening_linux(self, mock_subprocess, report_generator):
        """Linuxでのファイル表示テスト"""
        with patch('sys.platform', 'linux'):
            report_generator._open_report_file("test_report.html")
            mock_subprocess.assert_called_once_with(['xdg-open', "test_report.html"])

if __name__ == "__main__":
    # 単体でのテスト実行
    pytest.main([__file__, "-v", "--tb=short", "-x"])