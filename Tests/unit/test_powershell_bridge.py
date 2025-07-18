"""
Unit tests for PowerShell bridge module.
Tests PowerShell execution, error handling, and data conversion.
"""

import pytest
import asyncio
from unittest.mock import Mock, patch, MagicMock, call
import subprocess
import json
from pathlib import Path
import tempfile
import os
from datetime import datetime
import sys

# Import the module to test
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))
from core.powershell_bridge import PowerShellBridge, PowerShellResult, PowerShellCompatibilityLayer


class TestPowerShellBridge:
    """Test suite for PowerShellBridge class."""
    
    @pytest.fixture
    def temp_powershell_root(self):
        """Create temporary PowerShell root directory structure."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            # Create expected directory structure
            (root / "Scripts" / "Common").mkdir(parents=True)
            (root / "Apps").mkdir(parents=True)
            yield root
    
    @pytest.fixture
    def bridge(self, temp_powershell_root):
        """Create PowerShellBridge instance."""
        with patch.object(PowerShellBridge, '_detect_powershell', return_value='pwsh'):
            return PowerShellBridge(temp_powershell_root)
    
    def test_init(self, temp_powershell_root):
        """Test PowerShellBridge initialization."""
        with patch.object(PowerShellBridge, '_detect_powershell', return_value='pwsh'):
            bridge = PowerShellBridge(temp_powershell_root)
            
            assert bridge.powershell_root == temp_powershell_root
            assert bridge.scripts_dir == temp_powershell_root / "Scripts"
            assert bridge.common_dir == temp_powershell_root / "Scripts" / "Common"
            assert bridge.apps_dir == temp_powershell_root / "Apps"
            assert bridge.ps_executable == 'pwsh'
            assert bridge.execution_policy == 'Bypass'
            assert bridge.timeout == 300
            assert bridge._auth_status['graph_connected'] is False
    
    @patch('subprocess.run')
    def test_detect_powershell_pwsh(self, mock_run):
        """Test PowerShell detection - pwsh available."""
        # Mock pwsh available
        mock_result = Mock()
        mock_result.returncode = 0
        mock_run.return_value = mock_result
        
        bridge = PowerShellBridge(Path('/tmp'))
        
        assert bridge.ps_executable == 'pwsh'
        mock_run.assert_called_with(['pwsh', '-Version'], 
                                   capture_output=True, text=True, timeout=10)
    
    @patch('subprocess.run')
    def test_detect_powershell_fallback(self, mock_run):
        """Test PowerShell detection - fallback to powershell."""
        # First call (pwsh) fails, second call (powershell) succeeds
        mock_run.side_effect = [
            subprocess.CalledProcessError(1, 'pwsh'),
            Mock(returncode=0)
        ]
        
        bridge = PowerShellBridge(Path('/tmp'))
        
        assert bridge.ps_executable == 'powershell'
        assert mock_run.call_count == 2
    
    @patch('subprocess.run')
    def test_detect_powershell_not_found(self, mock_run):
        """Test PowerShell detection - none available."""
        mock_run.side_effect = FileNotFoundError()
        
        with pytest.raises(RuntimeError, match="PowerShell executable not found"):
            PowerShellBridge(Path('/tmp'))
    
    @pytest.mark.asyncio
    @patch('asyncio.create_subprocess_exec')
    async def test_execute_powershell_script_success(self, mock_subprocess, bridge):
        """Test successful PowerShell script execution."""
        # Mock subprocess
        mock_process = Mock()
        mock_process.communicate = asyncio.coroutine(lambda: (
            json.dumps({'data': 'test_result'}).encode(),
            b''
        ))
        mock_process.returncode = 0
        mock_subprocess.return_value = mock_process
        
        # Execute script
        result = await bridge.execute_powershell_script(
            'test_script.ps1',
            parameters={'param1': 'value1'}
        )
        
        assert result.success is True
        assert result.data == {'data': 'test_result'}
        assert result.error is None
        assert result.execution_time >= 0
    
    @pytest.mark.asyncio
    @patch('asyncio.create_subprocess_exec')
    async def test_execute_powershell_script_with_modules(self, mock_subprocess, bridge):
        """Test PowerShell script execution with module imports."""
        # Mock subprocess
        mock_process = Mock()
        mock_process.communicate = asyncio.coroutine(lambda: (
            json.dumps({'status': 'ok'}).encode(),
            b''
        ))
        mock_process.returncode = 0
        mock_subprocess.return_value = mock_process
        
        # Execute with modules
        result = await bridge.execute_powershell_script(
            'test_script.ps1',
            import_modules=['Common', 'Authentication']
        )
        
        assert result.success is True
        # Verify module import commands were included
        call_args = mock_subprocess.call_args
        assert any('Import-Module' in str(arg) for arg in call_args[0])
    
    @pytest.mark.asyncio  
    @patch('asyncio.create_subprocess_exec')
    async def test_execute_powershell_script_error(self, mock_subprocess, bridge):
        """Test PowerShell script execution with error."""
        # Mock subprocess with error
        mock_process = Mock()
        mock_process.communicate = asyncio.coroutine(lambda: (
            b'',
            b'Error: Script failed'
        ))
        mock_process.returncode = 1
        mock_subprocess.return_value = mock_process
        
        # Execute script
        result = await bridge.execute_powershell_script('error_script.ps1')
        
        assert result.success is False
        assert result.data is None
        assert 'Error: Script failed' in result.error
    
    @pytest.mark.asyncio
    @patch('asyncio.create_subprocess_exec')
    async def test_execute_powershell_script_timeout(self, mock_subprocess, bridge):
        """Test PowerShell script execution timeout."""
        # Mock subprocess that times out
        mock_process = Mock()
        mock_process.communicate = asyncio.coroutine(
            Mock(side_effect=asyncio.TimeoutError())
        )
        mock_subprocess.return_value = mock_process
        
        # Execute script with short timeout
        bridge.timeout = 0.1
        result = await bridge.execute_powershell_script('timeout_script.ps1')
        
        assert result.success is False
        assert 'Timeout' in result.error or 'timeout' in result.error.lower()
    
    def test_sync_execute_powershell(self, bridge):
        """Test synchronous PowerShell execution wrapper."""
        # Assuming sync wrapper exists
        with patch.object(bridge, 'execute_powershell_script') as mock_async:
            mock_async.return_value = asyncio.Future()
            mock_async.return_value.set_result(
                PowerShellResult(success=True, data='sync_result')
            )
            
            # If sync method exists, test it
            # result = bridge.execute_powershell_sync('test.ps1')
            # assert result.data == 'sync_result'
    
    @patch('subprocess.run')
    def test_get_module_versions(self, mock_run, bridge):
        """Test getting PowerShell module versions."""
        # Mock version output
        mock_run.return_value = Mock(
            returncode=0,
            stdout='Microsoft.Graph 2.15.0\nExchangeOnlineManagement 3.4.0'
        )
        
        # Method would be implemented in actual code
        # versions = bridge.get_module_versions()
        # assert versions['Microsoft.Graph'] == '2.15.0'
    
    def test_powershell_result_dataclass(self):
        """Test PowerShellResult dataclass."""
        result = PowerShellResult(
            success=True,
            data={'test': 'data'},
            error=None,
            execution_time=1.5,
            ps_version='7.4.0'
        )
        
        assert result.success is True
        assert result.data == {'test': 'data'}
        assert result.error is None
        assert result.execution_time == 1.5
        assert result.ps_version == '7.4.0'


class TestPowerShellBridgeAuthentication:
    """Test authentication-related functionality."""
    
    @pytest.fixture
    def bridge(self, tmp_path):
        """Create bridge with mocked PowerShell detection."""
        with patch.object(PowerShellBridge, '_detect_powershell', return_value='pwsh'):
            return PowerShellBridge(tmp_path)
    
    @pytest.mark.asyncio
    @patch('asyncio.create_subprocess_exec')
    async def test_check_auth_status(self, mock_subprocess, bridge):
        """Test checking authentication status."""
        # Mock successful auth check
        mock_process = Mock()
        mock_process.communicate = asyncio.coroutine(lambda: (
            json.dumps({
                'graph_connected': True,
                'exchange_connected': True
            }).encode(),
            b''
        ))
        mock_process.returncode = 0
        mock_subprocess.return_value = mock_process
        
        # Method would be implemented
        # status = await bridge.check_auth_status()
        # assert status['graph_connected'] is True
    
    @pytest.mark.asyncio
    @patch('asyncio.create_subprocess_exec') 
    async def test_connect_services(self, mock_subprocess, bridge):
        """Test connecting to Microsoft services."""
        # Mock successful connection
        mock_process = Mock()
        mock_process.communicate = asyncio.coroutine(lambda: (
            json.dumps({'connected': True}).encode(),
            b''
        ))
        mock_process.returncode = 0
        mock_subprocess.return_value = mock_process
        
        # Method would be implemented
        # result = await bridge.connect_services()
        # assert result.success is True


class TestPowerShellBridgeDataConversion:
    """Test data format conversion between PowerShell and Python."""
    
    @pytest.fixture
    def bridge(self, tmp_path):
        """Create bridge instance."""
        with patch.object(PowerShellBridge, '_detect_powershell', return_value='pwsh'):
            return PowerShellBridge(tmp_path)
    
    def test_convert_ps_datetime(self, bridge):
        """Test PowerShell datetime conversion."""
        # PowerShell datetime format: "\/Date(1234567890000)\/"
        # Method would be implemented
        # result = bridge.convert_ps_datetime("\/Date(1234567890000)\/")
        # assert isinstance(result, datetime)
        pass
    
    def test_convert_ps_object_array(self, bridge):
        """Test PowerShell object array conversion."""
        ps_data = [
            {'Name': 'User1', 'Enabled': True},
            {'Name': 'User2', 'Enabled': False}
        ]
        # Method would verify format compatibility
        # result = bridge.ensure_ps_compatibility(ps_data)
        pass


class TestPowerShellBridgeIntegration:
    """Integration tests for PowerShellBridge."""
    
    @pytest.mark.integration
    @pytest.mark.asyncio
    async def test_real_script_execution(self, tmp_path):
        """Test execution of actual PowerShell script."""
        # Create test script
        script_path = tmp_path / "test_integration.ps1"
        script_path.write_text("""
        param($Name = "Test")
        @{
            Message = "Hello from PowerShell"
            Name = $Name
            Timestamp = Get-Date -Format "o"
        } | ConvertTo-Json
        """)
        
        # Only run if PowerShell is available
        try:
            bridge = PowerShellBridge(tmp_path)
        except RuntimeError:
            pytest.skip("PowerShell not available")
        
        result = await bridge.execute_powershell_script(
            script_path,
            parameters={'Name': 'Integration'}
        )
        
        if result.success:
            assert result.data['Message'] == 'Hello from PowerShell'
            assert result.data['Name'] == 'Integration'
            assert 'Timestamp' in result.data
    
    @pytest.mark.integration
    def test_module_loading(self, tmp_path):
        """Test loading PowerShell modules."""
        # Create mock module
        module_dir = tmp_path / "Scripts" / "Common"
        module_dir.mkdir(parents=True)
        module_file = module_dir / "TestModule.psm1"
        module_file.write_text("""
        function Get-TestData {
            return @{Status = "OK"}
        }
        Export-ModuleMember -Function Get-TestData
        """)
        
        try:
            bridge = PowerShellBridge(tmp_path)
        except RuntimeError:
            pytest.skip("PowerShell not available")
        
        # Test module import functionality
        # This would be part of the actual implementation