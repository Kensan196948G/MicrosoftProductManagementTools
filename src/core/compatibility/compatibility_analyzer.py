"""
Compatibility Analyzer Module
PowerShell-Python間の互換性を詳細分析し、最適な移行戦略を提案

Dev2 - PowerShell Compatibility Developer による開発:
1. 既存PowerShellコードの自動解析
2. Python移行の複雑度評価
3. 互換性問題の自動検出
4. 最適化提案の生成
"""

import ast
import re
import json
import logging
from typing import Dict, List, Any, Optional, Tuple, Set
from pathlib import Path
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
import subprocess

logger = logging.getLogger(__name__)


class CompatibilityLevel(Enum):
    """互換性レベル"""
    FULL = "full"           # 完全互換
    HIGH = "high"           # 高互換（軽微な修正のみ）
    MEDIUM = "medium"       # 中互換（中程度の修正必要）
    LOW = "low"             # 低互換（大幅な修正必要）
    NONE = "none"           # 非互換（全面書き換え必要）


class ComplexityLevel(Enum):
    """移行複雑度"""
    SIMPLE = "simple"       # 単純（自動変換可能）
    MODERATE = "moderate"   # 中程度（半自動変換）
    COMPLEX = "complex"     # 複雑（手動変換必要）
    CRITICAL = "critical"   # 極めて複雑（アーキテクチャ変更必要）


@dataclass
class CompatibilityIssue:
    """互換性問題"""
    category: str
    severity: str  # "error", "warning", "info"
    description: str
    powershell_code: str
    suggested_python_code: Optional[str] = None
    line_number: Optional[int] = None
    fix_complexity: ComplexityLevel = ComplexityLevel.MODERATE
    auto_fixable: bool = False


@dataclass
class FunctionAnalysis:
    """関数分析結果"""
    name: str
    file_path: Path
    compatibility_level: CompatibilityLevel
    complexity_level: ComplexityLevel
    issues: List[CompatibilityIssue] = field(default_factory=list)
    dependencies: List[str] = field(default_factory=list)
    parameters: List[str] = field(default_factory=list)
    return_type: Optional[str] = None
    microsoft_apis_used: List[str] = field(default_factory=list)
    estimated_effort_hours: float = 0.0
    migration_priority: int = 1  # 1=高, 2=中, 3=低


@dataclass
class ModuleAnalysis:
    """モジュール分析結果"""
    name: str
    file_path: Path
    functions: List[FunctionAnalysis] = field(default_factory=list)
    imports: List[str] = field(default_factory=list)
    overall_compatibility: CompatibilityLevel = CompatibilityLevel.MEDIUM
    total_estimated_effort: float = 0.0


class PowerShellCodeAnalyzer:
    """PowerShellコードの詳細分析"""
    
    def __init__(self):
        # PowerShell特有のパターン
        self.powershell_patterns = {
            # Microsoft 365 APIパターン
            'graph_api_calls': r'(Get-Mg\w+|Connect-MgGraph|Invoke-MgGraphRequest)',
            'exchange_cmdlets': r'(Get-\w*Mailbox|Get-\w*Mail|Connect-ExchangeOnline)',
            'teams_cmdlets': r'(Get-Team|Get-TeamChannel|New-Team)',
            'sharepoint_cmdlets': r'(Get-PnP\w+|Connect-PnPOnline)',
            
            # PowerShell構文パターン
            'pipeline_usage': r'\|',
            'foreach_object': r'ForEach-Object|\%',
            'where_object': r'Where-Object|\?',
            'select_object': r'Select-Object',
            'hashtable_syntax': r'@\{[^}]*\}',
            'parameter_binding': r'\$\w+\.\w+',
            'automatic_variables': r'\$\?|\$_|\$\w+',
            'comparison_operators': r'-eq|-ne|-gt|-lt|-like|-match',
            
            # エラーハンドリング
            'try_catch': r'try\s*\{.*?\}\s*catch',
            'error_action': r'-ErrorAction\s+\w+',
            'error_variable': r'-ErrorVariable\s+\w+',
            
            # PowerShell特有の機能
            'splatting': r'@\w+',
            'here_strings': r'@["\']\s*\n.*?\n["\']\@',
            'script_blocks': r'\{[^}]*\}',
            'cmdlet_binding': r'\[CmdletBinding\(\)\]',
            'parameter_attributes': r'\[Parameter\([^)]*\)\]',
            
            # ファイルI/O
            'file_operations': r'(Get-Content|Set-Content|Out-File|Import-Csv|Export-Csv)',
            'path_operations': r'(Join-Path|Split-Path|Test-Path|Resolve-Path)',
            
            # 型キャスト
            'type_casting': r'\[\w+\]',
            'powershell_classes': r'class\s+\w+',
        }
        
        # Microsoft 365 API マッピング
        self.api_mappings = {
            'Get-MgUser': 'Microsoft Graph SDK for Python: graphServiceClient.users.get()',
            'Get-MgGroup': 'Microsoft Graph SDK for Python: graphServiceClient.groups.get()',
            'Get-Mailbox': 'Exchange Online PowerShell → REST API calls',
            'Get-Team': 'Microsoft Graph SDK for Python: graphServiceClient.teams.get()',
            'Connect-MgGraph': 'MSAL Python authentication',
            'Connect-ExchangeOnline': 'Exchange Online REST API authentication'
        }
        
        # 互換性ルール
        self.compatibility_rules = self._init_compatibility_rules()
    
    def _init_compatibility_rules(self) -> Dict[str, Dict[str, Any]]:
        """互換性判定ルールの初期化"""
        return {
            'high_compatibility': {
                'patterns': ['Get-MgUser', 'Get-MgGroup', 'simple variable assignments'],
                'score': 0.8,
                'description': 'Direct Python equivalent available'
            },
            'medium_compatibility': {
                'patterns': ['pipeline operations', 'basic cmdlets', 'file operations'],
                'score': 0.6,
                'description': 'Requires code restructuring but straightforward'
            },
            'low_compatibility': {
                'patterns': ['complex pipelines', 'PowerShell-specific features', 'cmdlet binding'],
                'score': 0.3,
                'description': 'Significant rewrite required'
            },
            'no_compatibility': {
                'patterns': ['PowerShell classes', 'advanced functions', 'module manifests'],
                'score': 0.1,
                'description': 'Complete redesign needed'
            }
        }
    
    def analyze_powershell_file(self, file_path: Path) -> ModuleAnalysis:
        """PowerShellファイルの包括的分析"""
        logger.info(f"Analyzing PowerShell file: {file_path}")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            logger.error(f"Failed to read file {file_path}: {e}")
            return ModuleAnalysis(name=file_path.stem, file_path=file_path)
        
        module_analysis = ModuleAnalysis(
            name=file_path.stem,
            file_path=file_path
        )
        
        # 関数の抽出と分析
        functions = self._extract_functions(content)
        for func_name, func_content, line_start in functions:
            func_analysis = self._analyze_function(
                func_name, func_content, file_path, line_start
            )
            module_analysis.functions.append(func_analysis)
        
        # インポート文の抽出
        module_analysis.imports = self._extract_imports(content)
        
        # 全体的な互換性レベルの計算
        module_analysis.overall_compatibility = self._calculate_overall_compatibility(
            module_analysis.functions
        )
        
        # 総工数見積もり
        module_analysis.total_estimated_effort = sum(
            func.estimated_effort_hours for func in module_analysis.functions
        )
        
        return module_analysis
    
    def _extract_functions(self, content: str) -> List[Tuple[str, str, int]]:
        """PowerShell関数の抽出"""
        functions = []
        
        # function キーワードでの関数定義
        function_pattern = r'function\s+([A-Za-z-]+)\s*(?:\([^)]*\))?\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}'
        matches = re.finditer(function_pattern, content, re.MULTILINE | re.DOTALL)
        
        for match in matches:
            func_name = match.group(1)
            func_body = match.group(2)
            line_start = content[:match.start()].count('\\n') + 1
            functions.append((func_name, func_body, line_start))
        
        # スクリプトブロック内の関数も検索
        script_block_pattern = r'\$\w+\s*=\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}'
        script_matches = re.finditer(script_block_pattern, content, re.MULTILINE | re.DOTALL)
        
        for match in script_matches:
            script_body = match.group(1)
            if 'function' in script_body.lower():
                # スクリプトブロック内の関数も抽出
                sub_functions = self._extract_functions(script_body)
                functions.extend(sub_functions)
        
        return functions
    
    def _analyze_function(self, func_name: str, func_content: str, 
                         file_path: Path, line_start: int) -> FunctionAnalysis:
        """個別関数の詳細分析"""
        analysis = FunctionAnalysis(
            name=func_name,
            file_path=file_path
        )
        
        # パターンマッチングによる特徴抽出
        features = self._extract_function_features(func_content)
        
        # 互換性レベルの決定
        analysis.compatibility_level = self._determine_compatibility_level(features)
        
        # 複雑度レベルの決定
        analysis.complexity_level = self._determine_complexity_level(features)
        
        # 互換性問題の特定
        analysis.issues = self._identify_compatibility_issues(func_content, line_start)
        
        # Microsoft 365 API使用の検出
        analysis.microsoft_apis_used = self._detect_microsoft_apis(func_content)
        
        # 依存関係の抽出
        analysis.dependencies = self._extract_dependencies(func_content)
        
        # パラメータの抽出
        analysis.parameters = self._extract_parameters(func_content)
        
        # 工数見積もり
        analysis.estimated_effort_hours = self._estimate_migration_effort(analysis)
        
        # 優先度の決定
        analysis.migration_priority = self._determine_migration_priority(analysis)
        
        return analysis
    
    def _extract_function_features(self, func_content: str) -> Dict[str, int]:
        """関数の特徴を抽出"""
        features = {}
        
        for pattern_name, pattern in self.powershell_patterns.items():
            matches = re.findall(pattern, func_content, re.IGNORECASE | re.MULTILINE)
            features[pattern_name] = len(matches)
        
        # その他の特徴
        features['lines_of_code'] = len(func_content.split('\\n'))
        features['comment_lines'] = len(re.findall(r'#.*', func_content))
        features['nested_depth'] = self._calculate_nesting_depth(func_content)
        
        return features
    
    def _calculate_nesting_depth(self, content: str) -> int:
        """ネスト深度の計算"""
        max_depth = 0
        current_depth = 0
        
        for char in content:
            if char == '{':
                current_depth += 1
                max_depth = max(max_depth, current_depth)
            elif char == '}':
                current_depth -= 1
        
        return max_depth
    
    def _determine_compatibility_level(self, features: Dict[str, int]) -> CompatibilityLevel:
        """互換性レベルの決定"""
        score = 1.0
        
        # Microsoft Graph API使用は高互換性
        if features.get('graph_api_calls', 0) > 0:
            score *= 0.9  # わずかに減点
        
        # Exchange cmdlets は中程度の互換性
        if features.get('exchange_cmdlets', 0) > 0:
            score *= 0.7
        
        # PowerShell特有の構文は互換性を下げる
        if features.get('pipeline_usage', 0) > 3:
            score *= 0.6
        
        if features.get('hashtable_syntax', 0) > 0:
            score *= 0.8
        
        if features.get('powershell_classes', 0) > 0:
            score *= 0.3
        
        if features.get('cmdlet_binding', 0) > 0:
            score *= 0.4
        
        # 複雑度による調整
        if features.get('nested_depth', 0) > 3:
            score *= 0.7
        
        if features.get('lines_of_code', 0) > 100:
            score *= 0.8
        
        # スコアに基づく判定
        if score >= 0.8:
            return CompatibilityLevel.FULL
        elif score >= 0.6:
            return CompatibilityLevel.HIGH
        elif score >= 0.4:
            return CompatibilityLevel.MEDIUM
        elif score >= 0.2:
            return CompatibilityLevel.LOW
        else:
            return CompatibilityLevel.NONE
    
    def _determine_complexity_level(self, features: Dict[str, int]) -> ComplexityLevel:
        """複雑度レベルの決定"""
        complexity_score = 0
        
        # 各要素の複雑度貢献
        complexity_score += features.get('nested_depth', 0) * 2
        complexity_score += features.get('pipeline_usage', 0) * 1
        complexity_score += features.get('lines_of_code', 0) / 20
        complexity_score += features.get('powershell_classes', 0) * 10
        complexity_score += features.get('cmdlet_binding', 0) * 5
        complexity_score += features.get('parameter_attributes', 0) * 3
        
        if complexity_score <= 5:
            return ComplexityLevel.SIMPLE
        elif complexity_score <= 15:
            return ComplexityLevel.MODERATE
        elif complexity_score <= 30:
            return ComplexityLevel.COMPLEX
        else:
            return ComplexityLevel.CRITICAL
    
    def _identify_compatibility_issues(self, func_content: str, line_start: int) -> List[CompatibilityIssue]:
        """互換性問題の特定"""
        issues = []
        lines = func_content.split('\\n')
        
        for i, line in enumerate(lines):
            line_number = line_start + i
            
            # PowerShell特有の演算子
            if re.search(r'-eq|-ne|-gt|-lt|-like|-match', line):
                issues.append(CompatibilityIssue(
                    category="operators",
                    severity="warning",
                    description="PowerShell comparison operators need conversion to Python",
                    powershell_code=line.strip(),
                    suggested_python_code=self._convert_operators(line.strip()),
                    line_number=line_number,
                    fix_complexity=ComplexityLevel.SIMPLE,
                    auto_fixable=True
                ))
            
            # パイプライン処理
            if '|' in line and not line.strip().startswith('#'):
                issues.append(CompatibilityIssue(
                    category="pipeline",
                    severity="warning",
                    description="PowerShell pipeline needs restructuring for Python",
                    powershell_code=line.strip(),
                    line_number=line_number,
                    fix_complexity=ComplexityLevel.MODERATE
                ))
            
            # ハッシュテーブル構文
            if re.search(r'@\{[^}]*\}', line):
                issues.append(CompatibilityIssue(
                    category="data_structures",
                    severity="info",
                    description="PowerShell hashtable can be converted to Python dict",
                    powershell_code=line.strip(),
                    suggested_python_code=self._convert_hashtable(line.strip()),
                    line_number=line_number,
                    fix_complexity=ComplexityLevel.SIMPLE,
                    auto_fixable=True
                ))
            
            # PowerShell特有のコマンドレット
            exchange_cmds = re.findall(r'(Get-Mailbox|Get-Mail\w+|Connect-ExchangeOnline)', line)
            for cmd in exchange_cmds:
                issues.append(CompatibilityIssue(
                    category="api_calls",
                    severity="error",
                    description=f"Exchange cmdlet {cmd} requires REST API implementation",
                    powershell_code=line.strip(),
                    line_number=line_number,
                    fix_complexity=ComplexityLevel.COMPLEX
                ))
        
        return issues
    
    def _convert_operators(self, line: str) -> str:
        """PowerShell演算子のPython変換"""
        conversions = {
            r'-eq': '==',
            r'-ne': '!=',
            r'-gt': '>',
            r'-lt': '<',
            r'-like': 'in',  # 簡略化
            r'-match': 're.match()'
        }
        
        converted = line
        for ps_op, py_op in conversions.items():
            converted = re.sub(ps_op, py_op, converted)
        
        return converted
    
    def _convert_hashtable(self, line: str) -> str:
        """PowerShellハッシュテーブルのPython辞書変換"""
        # 簡単な変換例
        if '@{' in line and '}' in line:
            return line.replace('@{', '{').replace('=', ':')
        return line
    
    def _detect_microsoft_apis(self, func_content: str) -> List[str]:
        """Microsoft 365 API使用の検出"""
        apis = []
        
        for api_pattern in ['Get-Mg\\w+', 'Connect-MgGraph', 'Get-Mailbox', 'Get-Team']:
            matches = re.findall(api_pattern, func_content)
            apis.extend(matches)
        
        return list(set(apis))  # 重複除去
    
    def _extract_dependencies(self, func_content: str) -> List[str]:
        """依存関係の抽出"""
        dependencies = []
        
        # Import-Module
        imports = re.findall(r'Import-Module\\s+([\\w\\.]+)', func_content)
        dependencies.extend(imports)
        
        # 外部関数呼び出し
        function_calls = re.findall(r'([A-Z][\\w-]+)\\s*\\(', func_content)
        dependencies.extend(function_calls)
        
        return list(set(dependencies))
    
    def _extract_parameters(self, func_content: str) -> List[str]:
        """パラメータの抽出"""
        params = []
        
        # param() ブロック
        param_block = re.search(r'param\\s*\\(([^)]+)\\)', func_content, re.DOTALL)
        if param_block:
            param_text = param_block.group(1)
            param_names = re.findall(r'\\$([\\w]+)', param_text)
            params.extend(param_names)
        
        # [Parameter] 属性
        param_attrs = re.findall(r'\\[Parameter[^\\]]*\\]\\s*\\$([\\w]+)', func_content)
        params.extend(param_attrs)
        
        return list(set(params))
    
    def _extract_imports(self, content: str) -> List[str]:
        """インポート文の抽出"""
        imports = []
        
        import_patterns = [
            r'Import-Module\\s+([\\w\\.]+)',
            r'using\\s+module\\s+([\\w\\.]+)',
            r'#requires\\s+-modules\\s+([\\w\\.,\\s]+)'
        ]
        
        for pattern in import_patterns:
            matches = re.findall(pattern, content, re.IGNORECASE)
            imports.extend(matches)
        
        return list(set(imports))
    
    def _estimate_migration_effort(self, analysis: FunctionAnalysis) -> float:
        """移行工数の見積もり（時間）"""
        base_hours = 2.0  # 基本工数
        
        # 複雑度による調整
        complexity_multipliers = {
            ComplexityLevel.SIMPLE: 1.0,
            ComplexityLevel.MODERATE: 2.0,
            ComplexityLevel.COMPLEX: 4.0,
            ComplexityLevel.CRITICAL: 8.0
        }
        
        # 互換性レベルによる調整
        compatibility_multipliers = {
            CompatibilityLevel.FULL: 0.5,
            CompatibilityLevel.HIGH: 1.0,
            CompatibilityLevel.MEDIUM: 2.0,
            CompatibilityLevel.LOW: 4.0,
            CompatibilityLevel.NONE: 8.0
        }
        
        # 問題数による調整
        issue_multiplier = 1.0 + (len(analysis.issues) * 0.2)
        
        # API使用による調整
        api_multiplier = 1.0 + (len(analysis.microsoft_apis_used) * 0.3)
        
        total_hours = (base_hours * 
                      complexity_multipliers[analysis.complexity_level] * 
                      compatibility_multipliers[analysis.compatibility_level] * 
                      issue_multiplier * 
                      api_multiplier)
        
        return round(total_hours, 1)
    
    def _determine_migration_priority(self, analysis: FunctionAnalysis) -> int:
        """移行優先度の決定（1=高, 2=中, 3=低）"""
        # 高優先度条件
        if (analysis.compatibility_level in [CompatibilityLevel.FULL, CompatibilityLevel.HIGH] and
            analysis.complexity_level in [ComplexityLevel.SIMPLE, ComplexityLevel.MODERATE]):
            return 1
        
        # 低優先度条件
        if (analysis.compatibility_level == CompatibilityLevel.NONE or
            analysis.complexity_level == ComplexityLevel.CRITICAL):
            return 3
        
        # その他は中優先度
        return 2
    
    def _calculate_overall_compatibility(self, functions: List[FunctionAnalysis]) -> CompatibilityLevel:
        """モジュール全体の互換性レベル計算"""
        if not functions:
            return CompatibilityLevel.MEDIUM
        
        compatibility_scores = {
            CompatibilityLevel.FULL: 5,
            CompatibilityLevel.HIGH: 4,
            CompatibilityLevel.MEDIUM: 3,
            CompatibilityLevel.LOW: 2,
            CompatibilityLevel.NONE: 1
        }
        
        total_score = sum(compatibility_scores[func.compatibility_level] for func in functions)
        average_score = total_score / len(functions)
        
        # 平均スコアから互換性レベルを決定
        if average_score >= 4.5:
            return CompatibilityLevel.FULL
        elif average_score >= 3.5:
            return CompatibilityLevel.HIGH
        elif average_score >= 2.5:
            return CompatibilityLevel.MEDIUM
        elif average_score >= 1.5:
            return CompatibilityLevel.LOW
        else:
            return CompatibilityLevel.NONE


class ProjectCompatibilityAnalyzer:
    """プロジェクト全体の互換性分析"""
    
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.code_analyzer = PowerShellCodeAnalyzer()
        
    def analyze_project(self) -> Dict[str, Any]:
        """プロジェクト全体の分析実行"""
        logger.info(f"Starting project analysis: {self.project_root}")
        
        # PowerShellファイルの検索
        powershell_files = list(self.project_root.rglob("*.ps1")) + list(self.project_root.rglob("*.psm1"))
        
        analysis_results = {
            'project_root': str(self.project_root),
            'analysis_timestamp': datetime.now().isoformat(),
            'total_files': len(powershell_files),
            'modules': [],
            'summary': {},
            'recommendations': []
        }
        
        # 各ファイルの分析
        for file_path in powershell_files:
            try:
                module_analysis = self.code_analyzer.analyze_powershell_file(file_path)
                analysis_results['modules'].append(self._serialize_module_analysis(module_analysis))
            except Exception as e:
                logger.error(f"Failed to analyze {file_path}: {e}")
        
        # サマリーの生成
        analysis_results['summary'] = self._generate_project_summary(analysis_results['modules'])
        
        # 推奨事項の生成
        analysis_results['recommendations'] = self._generate_recommendations(analysis_results)
        
        return analysis_results
    
    def _serialize_module_analysis(self, module: ModuleAnalysis) -> Dict[str, Any]:
        """ModuleAnalysisの辞書変換"""
        return {
            'name': module.name,
            'file_path': str(module.file_path),
            'overall_compatibility': module.overall_compatibility.value,
            'total_estimated_effort': module.total_estimated_effort,
            'imports': module.imports,
            'functions': [self._serialize_function_analysis(func) for func in module.functions]
        }
    
    def _serialize_function_analysis(self, func: FunctionAnalysis) -> Dict[str, Any]:
        """FunctionAnalysisの辞書変換"""
        return {
            'name': func.name,
            'compatibility_level': func.compatibility_level.value,
            'complexity_level': func.complexity_level.value,
            'estimated_effort_hours': func.estimated_effort_hours,
            'migration_priority': func.migration_priority,
            'microsoft_apis_used': func.microsoft_apis_used,
            'dependencies': func.dependencies,
            'parameters': func.parameters,
            'issues': [self._serialize_issue(issue) for issue in func.issues]
        }
    
    def _serialize_issue(self, issue: CompatibilityIssue) -> Dict[str, Any]:
        """CompatibilityIssueの辞書変換"""
        return {
            'category': issue.category,
            'severity': issue.severity,
            'description': issue.description,
            'powershell_code': issue.powershell_code,
            'suggested_python_code': issue.suggested_python_code,
            'line_number': issue.line_number,
            'fix_complexity': issue.fix_complexity.value,
            'auto_fixable': issue.auto_fixable
        }
    
    def _generate_project_summary(self, modules: List[Dict[str, Any]]) -> Dict[str, Any]:
        """プロジェクトサマリーの生成"""
        total_functions = sum(len(module['functions']) for module in modules)
        total_effort = sum(module['total_estimated_effort'] for module in modules)
        
        # 互換性レベル分布
        compatibility_dist = {}
        complexity_dist = {}
        priority_dist = {1: 0, 2: 0, 3: 0}
        
        for module in modules:
            for func in module['functions']:
                compat = func['compatibility_level']
                complexity = func['complexity_level']
                priority = func['migration_priority']
                
                compatibility_dist[compat] = compatibility_dist.get(compat, 0) + 1
                complexity_dist[complexity] = complexity_dist.get(complexity, 0) + 1
                priority_dist[priority] += 1
        
        # 問題統計
        total_issues = sum(len(func['issues']) for module in modules for func in module['functions'])
        auto_fixable_issues = sum(
            len([issue for issue in func['issues'] if issue['auto_fixable']])
            for module in modules for func in module['functions']
        )
        
        return {
            'total_modules': len(modules),
            'total_functions': total_functions,
            'total_estimated_effort_hours': round(total_effort, 1),
            'estimated_effort_weeks': round(total_effort / 40, 1),  # 40時間/週
            'compatibility_distribution': compatibility_dist,
            'complexity_distribution': complexity_dist,
            'priority_distribution': priority_dist,
            'total_issues': total_issues,
            'auto_fixable_issues': auto_fixable_issues,
            'manual_fix_required': total_issues - auto_fixable_issues
        }
    
    def _generate_recommendations(self, analysis: Dict[str, Any]) -> List[Dict[str, Any]]:
        """推奨事項の生成"""
        recommendations = []
        summary = analysis['summary']
        
        # 工数に基づく推奨
        if summary['total_estimated_effort_hours'] > 200:
            recommendations.append({
                'priority': 'high',
                'category': 'project_management',
                'title': '段階的移行戦略の採用',
                'description': f"総工数が{summary['total_estimated_effort_hours']}時間と大規模なため、段階的移行を推奨します。",
                'action_items': [
                    '高優先度機能の先行移行',
                    'ハイブリッド運用期間の設定',
                    '並行テスト環境の構築'
                ]
            })
        
        # 互換性に基づく推奨
        high_compat_ratio = summary['compatibility_distribution'].get('high', 0) / summary['total_functions']
        if high_compat_ratio > 0.6:
            recommendations.append({
                'priority': 'medium',
                'category': 'automation',
                'title': '自動変換ツールの活用',
                'description': f"高互換性機能が{high_compat_ratio:.1%}を占めるため、自動変換ツールの効果が期待できます。",
                'action_items': [
                    '自動変換ツールの開発・導入',
                    'コード変換ルールの策定',
                    '自動テスト体制の構築'
                ]
            })
        
        # 問題に基づく推奨
        auto_fix_ratio = summary['auto_fixable_issues'] / max(summary['total_issues'], 1)
        if auto_fix_ratio > 0.5:
            recommendations.append({
                'priority': 'medium',
                'category': 'tooling',
                'title': '自動修正ツールの優先開発',
                'description': f"自動修正可能な問題が{auto_fix_ratio:.1%}あるため、修正ツールの開発を優先することを推奨します。",
                'action_items': [
                    '自動修正ツールの開発',
                    'コードレビューパイプラインの構築',
                    '継続的インテグレーションの設定'
                ]
            })
        
        return recommendations
    
    def export_analysis_report(self, analysis_results: Dict[str, Any], output_path: Path):
        """分析レポートのエクスポート"""
        # JSON形式でエクスポート
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(analysis_results, f, indent=2, ensure_ascii=False)
        
        logger.info(f"Analysis report exported to: {output_path}")


def analyze_compatibility(project_root: Path) -> Dict[str, Any]:
    """プロジェクト互換性分析の実行（便利関数）"""
    analyzer = ProjectCompatibilityAnalyzer(project_root)
    return analyzer.analyze_project()