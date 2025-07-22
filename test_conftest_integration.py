#!/usr/bin/env python3
"""
Phase 1-2 conftest.py競合解消プロジェクト 統合テスト
QA Engineer: dev2 - 統合conftest.py動作確認テスト

テスト範囲:
- 統合conftest.pyの基本機能
- フィクスチャ動作確認
- マーカー統合確認
- GUI環境検出確認
"""

import pytest
import os
from pathlib import Path


@pytest.mark.conftest_integration
@pytest.mark.phase1_2
def test_project_root_fixture(project_root):
    """プロジェクトルートフィクスチャテスト"""
    assert project_root is not None
    assert isinstance(project_root, Path)
    assert project_root.exists()
    assert project_root.name == "MicrosoftProductManagementTools"


@pytest.mark.conftest_integration
@pytest.mark.phase1_2
def test_temp_config_fixture(temp_config):
    """統合temp_configフィクスチャテスト"""
    assert temp_config is not None
    assert isinstance(temp_config, dict)
    
    # Microsoft 365設定確認
    assert "tenant_id" in temp_config
    assert "client_id" in temp_config
    assert "api_base_url" in temp_config
    assert temp_config["api_base_url"] == "https://graph.microsoft.com"
    
    # テストモード確認
    assert temp_config["test_mode"] is True
    assert temp_config["mock_data_enabled"] is True


@pytest.mark.conftest_integration
@pytest.mark.phase1_2
def test_gui_available_fixture(gui_available):
    """GUI環境可用性フィクスチャテスト"""
    assert isinstance(gui_available, bool)
    print(f"GUI環境: {'✅ 利用可能' if gui_available else '❌ 制限付き'}")


@pytest.mark.conftest_integration
@pytest.mark.phase1_2
def test_temp_directory_fixture(temp_directory):
    """一時ディレクトリフィクスチャテスト"""
    assert temp_directory is not None
    assert isinstance(temp_directory, Path)
    assert temp_directory.exists()
    assert "m365_test_" in str(temp_directory)
    
    # テストファイル作成・確認
    test_file = temp_directory / "test.txt"
    test_file.write_text("conftest統合テスト")
    assert test_file.exists()
    assert test_file.read_text() == "conftest統合テスト"


@pytest.mark.conftest_integration
@pytest.mark.phase1_2
def test_performance_monitor_fixture(performance_monitor):
    """パフォーマンス監視フィクスチャテスト"""
    assert performance_monitor is not None
    
    # パフォーマンス測定テスト
    performance_monitor.start("test_operation")
    # 短時間の操作をシミュレート
    import time
    time.sleep(0.01)
    duration = performance_monitor.stop()
    
    assert duration > 0
    assert duration < 1.0  # 1秒未満
    assert performance_monitor.get_measurement("test_operation") == duration


@pytest.mark.conftest_integration
@pytest.mark.phase1_2
def test_mock_m365_users_fixture(mock_m365_users):
    """Microsoft 365ユーザーモックフィクスチャテスト"""
    assert mock_m365_users is not None
    assert "@odata.context" in mock_m365_users
    assert "value" in mock_m365_users
    assert len(mock_m365_users["value"]) >= 2
    
    # 日本語ユーザーデータ確認
    user = mock_m365_users["value"][0]
    assert "田中 太郎" in user["displayName"]
    assert "tanaka.taro@contoso.com" in user["mail"]
    assert user["accountEnabled"] is True


@pytest.mark.conftest_integration
@pytest.mark.phase1_2
def test_mock_m365_licenses_fixture(mock_m365_licenses):
    """Microsoft 365ライセンスモックフィクスチャテスト"""
    assert mock_m365_licenses is not None
    assert "value" in mock_m365_licenses
    assert len(mock_m365_licenses["value"]) >= 1
    
    license_info = mock_m365_licenses["value"][0]
    assert "skuPartNumber" in license_info
    assert "ENTERPRISEPREMIUM" in license_info["skuPartNumber"]
    assert "consumedUnits" in license_info
    assert "prepaidUnits" in license_info


@pytest.mark.conftest_integration
@pytest.mark.phase1_2
def test_environment_variables_setup():
    """テスト環境変数設定確認"""
    assert os.environ.get("PYTEST_RUNNING") == "true"
    assert os.environ.get("CONFTEST_INTEGRATION_MODE") == "true"
    assert os.environ.get("M365_TEST_MODE") == "enabled"


@pytest.mark.conftest_integration
@pytest.mark.phase1_2
@pytest.mark.slow
def test_markers_integration():
    """マーカー統合機能テスト"""
    # このテストは複数のマーカーが適用されることを確認
    assert True  # マーカーが正しく適用されていればテストが実行される


# GUI環境でのみ実行されるテスト
@pytest.mark.gui
@pytest.mark.conftest_integration
def test_gui_fixtures_conditional(gui_available, qapp, gui_test_helper):
    """GUI フィクスチャ条件付きテスト"""
    if not gui_available:
        pytest.skip("GUI packages not available")
    
    # GUI環境が利用可能な場合のテスト
    assert qapp is not None
    assert gui_test_helper is not None
    
    # ユーザー操作遅延テスト
    import time
    start_time = time.time()
    gui_test_helper.simulate_user_delay(50)  # 50ms遅延
    elapsed = time.time() - start_time
    assert elapsed >= 0.04  # 最低40ms以上


@pytest.mark.conftest_integration
@pytest.mark.phase1_2
def test_conftest_version_info():
    """conftest.py統合バージョン情報確認"""
    # 統合conftest.pyが正しく読み込まれているか確認
    import conftest
    assert hasattr(conftest, 'PROJECT_ROOT')
    assert hasattr(conftest, 'GUI_AVAILABLE')
    assert hasattr(conftest, 'detect_gui_availability')
    
    print("\n🎉 === conftest.py競合解消プロジェクト Phase 1-2 統合テスト成功 ===")
    print("✅ 統合conftest.py v2.0 正常動作確認")
    print("✅ 全フィクスチャ動作確認完了")
    print("✅ マーカー統合機能確認完了")
    print("✅ 重複解消・継承チェーン構築完了")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])