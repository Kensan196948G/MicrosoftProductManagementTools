"""
PowerShell to Python 移行ヘルパー
移行プロセスを支援するユーティリティとツール
"""

import os
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import json
import logging
from datetime import datetime
from dataclasses import dataclass, asdict
import ast

from .ps_to_py_converter import PowerShellToPythonConverter, ConversionLevel, ConversionResult


logger = logging.getLogger(__name__)


@dataclass
class MigrationStatus:
    """移行ステータス"""
    file_path: str
    original_lines: int
    converted_lines: int
    conversion_level: str
    bridge_dependencies: List[str]
    status: str  # 'pending', 'in_progress', 'completed', 'failed'
    notes: str
    timestamp: str


@dataclass
class MigrationPlan:
    """移行計画"""
    total_files: int
    phases: Dict[str, List[str]]
    dependencies: Dict[str, List[str]]
    estimated_effort: Dict[str, str]
    created_at: str


class MigrationHelper:
    """移行プロセスを管理するヘルパークラス"""
    
    def __init__(self, project_root: Path):
        self.project_root = Path(project_root)
        self.ps_root = self.project_root
        self.py_root = self.project_root / 'src'
        self.migration_dir = self.project_root / '.migration'
        self.migration_dir.mkdir(exist_ok=True)
        
        self.converter = PowerShellToPythonConverter(ConversionLevel.HYBRID)
        self.status_file = self.migration_dir / 'migration_status.json'
        self.plan_file = self.migration_dir / 'migration_plan.json'
        
        self._load_status()
    
    def _load_status(self):
        """移行ステータスを読み込み"""
        if self.status_file.exists():
            with open(self.status_file, 'r') as f:
                data = json.load(f)
                self.migration_status = {
                    k: MigrationStatus(**v) for k, v in data.items()
                }
        else:
            self.migration_status = {}
    
    def _save_status(self):
        """移行ステータスを保存"""
        data = {
            k: asdict(v) for k, v in self.migration_status.items()
        }
        with open(self.status_file, 'w') as f:
            json.dump(data, f, indent=2)
    
    def analyze_project(self) -> MigrationPlan:
        """プロジェクト全体を分析して移行計画を作成"""
        logger.info("Analyzing PowerShell project structure...")
        
        ps_files = list(self.ps_root.rglob("*.ps1")) + list(self.ps_root.rglob("*.psm1"))
        
        # ファイルを分類
        phases = {
            'phase1_core': [],      # コア機能（依存関係なし）
            'phase2_api': [],       # API統合
            'phase3_gui': [],       # GUI関連
            'phase4_scripts': []    # その他のスクリプト
        }
        
        dependencies = {}
        estimated_effort = {}
        
        for ps_file in ps_files:
            rel_path = ps_file.relative_to(self.ps_root)
            analysis = self.converter.analyze_script(ps_file)
            
            # フェーズ分類
            if 'Common' in str(rel_path) or 'Authentication' in str(rel_path):
                phases['phase1_core'].append(str(rel_path))
            elif 'GUI' in str(rel_path) or 'GuiApp' in str(rel_path):
                phases['phase3_gui'].append(str(rel_path))
            elif any(api in str(rel_path) for api in ['EXO', 'Graph', 'Teams', 'OneDrive']):
                phases['phase2_api'].append(str(rel_path))
            else:
                phases['phase4_scripts'].append(str(rel_path))
            
            # 依存関係
            if analysis['bridge_required']:
                dependencies[str(rel_path)] = analysis['bridge_required']
            
            # 工数見積もり
            estimated_effort[str(rel_path)] = analysis['estimated_effort']
        
        plan = MigrationPlan(
            total_files=len(ps_files),
            phases=phases,
            dependencies=dependencies,
            estimated_effort=estimated_effort,
            created_at=datetime.now().isoformat()
        )
        
        # 計画を保存
        with open(self.plan_file, 'w') as f:
            json.dump(asdict(plan), f, indent=2)
        
        return plan
    
    def migrate_file(self, ps_file: Path, force: bool = False) -> Tuple[bool, str]:
        """単一ファイルを移行"""
        rel_path = ps_file.relative_to(self.ps_root)
        status_key = str(rel_path)
        
        # ステータスチェック
        if status_key in self.migration_status and not force:
            status = self.migration_status[status_key]
            if status.status == 'completed':
                return True, f"Already migrated: {rel_path}"
        
        logger.info(f"Migrating {rel_path}...")
        
        try:
            # 変換実行
            result = self.converter.convert_file(ps_file)
            
            # 出力パスを決定
            py_path = self._determine_py_path(ps_file)
            py_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Pythonコードを保存
            with open(py_path, 'w', encoding='utf-8') as f:
                f.write(result.python_code)
            
            # ステータス更新
            self.migration_status[status_key] = MigrationStatus(
                file_path=str(rel_path),
                original_lines=len(ps_file.read_text().splitlines()),
                converted_lines=len(result.python_code.splitlines()),
                conversion_level=result.conversion_level.value,
                bridge_dependencies=result.bridge_calls,
                status='completed',
                notes=f"Converted to {py_path.relative_to(self.project_root)}",
                timestamp=datetime.now().isoformat()
            )
            
            self._save_status()
            
            # 変換後の検証
            if self._validate_python_code(py_path):
                return True, f"Successfully migrated: {rel_path} -> {py_path.relative_to(self.project_root)}"
            else:
                return False, f"Migration completed but validation failed: {rel_path}"
            
        except Exception as e:
            logger.error(f"Failed to migrate {rel_path}: {e}")
            
            self.migration_status[status_key] = MigrationStatus(
                file_path=str(rel_path),
                original_lines=len(ps_file.read_text().splitlines()),
                converted_lines=0,
                conversion_level='failed',
                bridge_dependencies=[],
                status='failed',
                notes=str(e),
                timestamp=datetime.now().isoformat()
            )
            
            self._save_status()
            return False, f"Failed to migrate {rel_path}: {e}"
    
    def _determine_py_path(self, ps_file: Path) -> Path:
        """PowerShellファイルパスから対応するPythonファイルパスを決定"""
        rel_path = ps_file.relative_to(self.ps_root)
        
        # ディレクトリマッピング
        if 'Scripts/Common' in str(rel_path):
            py_dir = self.py_root / 'common'
        elif 'Scripts/AD' in str(rel_path):
            py_dir = self.py_root / 'services' / 'active_directory'
        elif 'Scripts/EntraID' in str(rel_path):
            py_dir = self.py_root / 'services' / 'entra_id'
        elif 'Scripts/EXO' in str(rel_path):
            py_dir = self.py_root / 'services' / 'exchange'
        elif 'Scripts/Teams' in str(rel_path):
            py_dir = self.py_root / 'services' / 'teams'
        elif 'Scripts/OneDrive' in str(rel_path):
            py_dir = self.py_root / 'services' / 'onedrive'
        elif 'Apps' in str(rel_path):
            if 'Gui' in ps_file.stem:
                py_dir = self.py_root / 'gui'
            else:
                py_dir = self.py_root / 'cli'
        else:
            py_dir = self.py_root / 'scripts'
        
        # ファイル名変換
        py_name = self._convert_filename(ps_file.stem) + '.py'
        
        return py_dir / py_name
    
    def _convert_filename(self, ps_name: str) -> str:
        """PowerShellファイル名をPython形式に変換"""
        # GuiApp_Enhanced → gui_app_enhanced
        # Get-MailboxStatistics → get_mailbox_statistics
        
        # ハイフンをアンダースコアに
        name = ps_name.replace('-', '_')
        
        # キャメルケースをスネークケースに
        import re
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
        return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()
    
    def _validate_python_code(self, py_file: Path) -> bool:
        """生成されたPythonコードを検証"""
        try:
            with open(py_file, 'r') as f:
                code = f.read()
            
            # 構文チェック
            ast.parse(code)
            
            # 基本的なインポートチェック
            # 実際の実装では、より詳細な検証が必要
            
            return True
        except SyntaxError as e:
            logger.error(f"Syntax error in {py_file}: {e}")
            return False
        except Exception as e:
            logger.error(f"Validation error in {py_file}: {e}")
            return False
    
    def migrate_phase(self, phase: str) -> Dict[str, bool]:
        """特定フェーズのファイルを一括移行"""
        if not self.plan_file.exists():
            self.analyze_project()
        
        with open(self.plan_file, 'r') as f:
            plan = json.load(f)
        
        if phase not in plan['phases']:
            raise ValueError(f"Unknown phase: {phase}")
        
        results = {}
        for file_path in plan['phases'][phase]:
            ps_file = self.ps_root / file_path
            if ps_file.exists():
                success, message = self.migrate_file(ps_file)
                results[file_path] = success
                logger.info(message)
        
        return results
    
    def generate_compatibility_tests(self, ps_file: Path, py_file: Path) -> str:
        """PowerShellとPythonの互換性テストを生成"""
        test_code = f'''"""
互換性テスト: {ps_file.name} vs {py_file.name}
PowerShellとPythonの実装が同じ結果を返すことを確認
"""

import pytest
import asyncio
from pathlib import Path
import sys

# テスト対象のインポート
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))
from core.powershell_bridge import PowerShellBridge

# Pythonモジュールのインポート
# from ... import ...


class TestCompatibility:
    """PowerShell/Python互換性テスト"""
    
    @pytest.fixture
    def bridge(self):
        return PowerShellBridge()
    
    def test_function_output_match(self, bridge):
        """関数の出力が一致することを確認"""
        # PowerShell実行
        ps_result = bridge.execute_script("{ps_file}")
        
        # Python実行
        # py_result = python_function()
        
        # 結果の比較
        # assert ps_result.data == py_result
        pass
'''
        
        return test_code
    
    def create_migration_report(self) -> str:
        """移行レポートを生成"""
        report_lines = [
            "# PowerShell to Python 移行レポート",
            f"\n生成日時: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "\n## 概要\n"
        ]
        
        # ステータス集計
        total = len(self.migration_status)
        completed = sum(1 for s in self.migration_status.values() if s.status == 'completed')
        failed = sum(1 for s in self.migration_status.values() if s.status == 'failed')
        pending = sum(1 for s in self.migration_status.values() if s.status == 'pending')
        
        report_lines.extend([
            f"- 総ファイル数: {total}",
            f"- 完了: {completed} ({completed/total*100:.1f}%)",
            f"- 失敗: {failed}",
            f"- 未着手: {pending}",
            "\n## 詳細\n"
        ])
        
        # フェーズごとの進捗
        if self.plan_file.exists():
            with open(self.plan_file, 'r') as f:
                plan = json.load(f)
            
            for phase, files in plan['phases'].items():
                phase_completed = sum(
                    1 for f in files 
                    if f in self.migration_status and 
                    self.migration_status[f].status == 'completed'
                )
                report_lines.append(
                    f"\n### {phase}: {phase_completed}/{len(files)} 完了"
                )
                
                for file in files:
                    if file in self.migration_status:
                        status = self.migration_status[file]
                        emoji = "✅" if status.status == 'completed' else "❌" if status.status == 'failed' else "⏳"
                        report_lines.append(f"- {emoji} {file}")
        
        # ブリッジ依存関係
        report_lines.append("\n## PowerShellブリッジ依存関係\n")
        bridge_deps = {}
        for status in self.migration_status.values():
            if status.status == 'completed' and status.bridge_dependencies:
                for dep in status.bridge_dependencies:
                    bridge_deps[dep] = bridge_deps.get(dep, 0) + 1
        
        for dep, count in sorted(bridge_deps.items(), key=lambda x: x[1], reverse=True):
            report_lines.append(f"- {dep}: {count} ファイル")
        
        return '\n'.join(report_lines)
    
    def create_rollback_script(self) -> str:
        """ロールバックスクリプトを生成"""
        script = '''#!/usr/bin/env python3
"""
移行ロールバックスクリプト
生成されたPythonファイルを削除し、PowerShellファイルを復元
"""

import shutil
from pathlib import Path
import json

def rollback():
    migration_dir = Path(".migration")
    status_file = migration_dir / "migration_status.json"
    
    if not status_file.exists():
        print("No migration status found")
        return
    
    with open(status_file, 'r') as f:
        status = json.load(f)
    
    for file_info in status.values():
        if file_info['status'] == 'completed':
            # Pythonファイルを削除
            py_path = Path(file_info['notes'].split(' -> ')[1])
            if py_path.exists():
                py_path.unlink()
                print(f"Removed: {py_path}")
    
    print("Rollback completed")

if __name__ == '__main__':
    rollback()
'''
        return script


# 使用例
if __name__ == '__main__':
    helper = MigrationHelper(Path.cwd())
    
    # プロジェクト分析
    plan = helper.analyze_project()
    print(f"Total files to migrate: {plan.total_files}")
    
    # フェーズ1を移行
    # results = helper.migrate_phase('phase1_core')
    
    # レポート生成
    report = helper.create_migration_report()
    print(report)