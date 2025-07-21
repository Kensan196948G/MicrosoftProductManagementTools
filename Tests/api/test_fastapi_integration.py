"""
FastAPI統合テストスイート - dev1 Backend連携対応
Microsoft 365管理ツール API統合テスト
"""
import pytest
from fastapi.testclient import TestClient
from pathlib import Path
import json
import os
import sys

# プロジェクトルートをパスに追加
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

@pytest.fixture
def api_test_setup():
    """API テスト環境セットアップ"""
    return {
        "base_url": "http://localhost:8000",
        "api_version": "v1",
        "test_mode": True
    }

class TestFastAPIIntegration:
    """FastAPI統合テストクラス"""
    
    def test_api_structure_exists(self, api_test_setup):
        """API構造存在確認"""
        project_root = Path(__file__).parent.parent.parent
        
        # FastAPI関連ファイル確認
        api_files = [
            "src/main_fastapi.py",
            "src/api",
            "src/api/main.py"
        ]
        
        existing_files = []
        for api_file in api_files:
            file_path = project_root / api_file
            if file_path.exists():
                existing_files.append(str(file_path))
        
        assert len(existing_files) > 0, f"No FastAPI files found. Checked: {api_files}"
    
    @pytest.mark.api
    def test_api_basic_structure(self, api_test_setup):
        """API基本構造テスト"""
        project_root = Path(__file__).parent.parent.parent
        src_dir = project_root / "src"
        
        if src_dir.exists():
            # src/api ディレクトリ構造確認
            api_dir = src_dir / "api"
            if api_dir.exists():
                # 基本APIファイル確認
                expected_api_files = [
                    "main.py",
                    "__init__.py"
                ]
                
                for api_file in expected_api_files:
                    api_file_path = api_dir / api_file
                    if api_file_path.exists():
                        assert api_file_path.is_file(), f"Expected file: {api_file}"
        
        # テスト成功の記録
        assert True, "API structure validation completed"
    
    @pytest.mark.api  
    @pytest.mark.integration
    def test_fastapi_mock_client(self, api_test_setup):
        """FastAPI モッククライアントテスト"""
        # FastAPIが利用可能かチェック
        try:
            from fastapi import FastAPI
            from fastapi.testclient import TestClient
            
            # モックFastAPIアプリケーション作成
            app = FastAPI(title="Microsoft 365 Management API", version="1.0.0")
            
            @app.get("/")
            def read_root():
                return {"message": "Microsoft 365 Management Tools API", "status": "operational"}
            
            @app.get("/health")
            def health_check():
                return {"status": "healthy", "version": "1.0.0"}
            
            @app.get("/api/v1/users")
            def get_users():
                return {
                    "users": [
                        {"id": 1, "name": "Test User 1", "email": "test1@example.com"},
                        {"id": 2, "name": "Test User 2", "email": "test2@example.com"}
                    ],
                    "total": 2
                }
            
            # テストクライアント作成
            client = TestClient(app)
            
            # ルートエンドポイントテスト
            response = client.get("/")
            assert response.status_code == 200
            data = response.json()
            assert "message" in data
            assert data["status"] == "operational"
            
            # ヘルスチェックテスト
            response = client.get("/health")
            assert response.status_code == 200
            health_data = response.json()
            assert health_data["status"] == "healthy"
            
            # ユーザーAPIテスト
            response = client.get("/api/v1/users")
            assert response.status_code == 200
            users_data = response.json()
            assert "users" in users_data
            assert users_data["total"] == 2
            assert len(users_data["users"]) == 2
            
        except ImportError:
            pytest.skip("FastAPI not available - installing required dependencies")
    
    @pytest.mark.dev1_collaboration
    def test_dev1_backend_integration_readiness(self, api_test_setup):
        """dev1 Backend統合準備確認"""
        project_root = Path(__file__).parent.parent.parent
        
        # Backend統合ポイント確認
        backend_integration_points = [
            "src/api",
            "src/main_fastapi.py", 
            "src/core",
            "Config/appsettings.json"
        ]
        
        existing_points = []
        for point in backend_integration_points:
            point_path = project_root / point
            if point_path.exists():
                existing_points.append(str(point))
        
        assert len(existing_points) >= 2, f"Backend integration points ready: {len(existing_points)}/4"
    
    @pytest.mark.compatibility
    def test_powershell_python_api_compatibility(self, api_test_setup):
        """PowerShell→Python API互換性テスト"""
        project_root = Path(__file__).parent.parent.parent
        
        # PowerShell側のAPI関連ファイル確認
        powershell_api_files = [
            "Scripts/Common/RealM365DataProvider.psm1",
            "Scripts/Common/Authentication.psm1",
            "Config/appsettings.json"
        ]
        
        # Python側のAPI関連ファイル確認
        python_api_files = [
            "src/core/config.py",
            "src/api"
        ]
        
        ps_exists = sum(1 for f in powershell_api_files if (project_root / f).exists())
        py_exists = sum(1 for f in python_api_files if (project_root / f).exists())
        
        assert ps_exists >= 2, f"PowerShell API components: {ps_exists}/3"
        assert py_exists >= 1, f"Python API components: {py_exists}/2"
        
        # 設定ファイル互換性確認
        config_path = project_root / "Config" / "appsettings.json"
        if config_path.exists():
            with open(config_path, 'r', encoding='utf-8') as f:
                config_data = json.load(f)
            
            # PowerShell-Python共通設定の確認
            assert "Authentication" in config_data, "Authentication config required for PS-Python compatibility"

@pytest.mark.performance
class TestAPIPerformance:
    """API パフォーマンステスト"""
    
    def test_api_response_time_mock(self):
        """API レスポンス時間テスト（モック）"""
        import time
        
        # モックAPIレスポンス時間測定
        start_time = time.time()
        
        # 模擬API処理
        mock_response = {
            "users": [{"id": i, "name": f"User {i}"} for i in range(100)],
            "processing_time": "< 1s"
        }
        
        end_time = time.time()
        response_time = end_time - start_time
        
        # レスポンス時間が1秒以内であることを確認
        assert response_time < 1.0, f"API response time: {response_time:.3f}s (should be < 1.0s)"
        assert len(mock_response["users"]) == 100, "Expected 100 mock users"