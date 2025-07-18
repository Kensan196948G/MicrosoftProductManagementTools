"""
PowerShell to Python 移行ツール
PowerShellスクリプトをPythonコードに自動変換する
"""

import re
import ast
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any
import logging
from dataclasses import dataclass
from enum import Enum


logger = logging.getLogger(__name__)


class ConversionLevel(Enum):
    """変換レベル"""
    FULL = "full"          # 完全なPython実装
    BRIDGE = "bridge"      # PowerShellブリッジ経由
    HYBRID = "hybrid"      # ハイブリッド実装


@dataclass
class ConversionRule:
    """変換ルール"""
    pattern: str           # 正規表現パターン
    replacement: str       # 置換文字列またはコールバック
    level: ConversionLevel # 変換レベル
    description: str       # ルールの説明


@dataclass
class ConversionResult:
    """変換結果"""
    python_code: str
    imports: List[str]
    warnings: List[str]
    bridge_calls: List[str]
    conversion_level: ConversionLevel


class PowerShellToPythonConverter:
    """PowerShellからPythonへの変換エンジン"""
    
    def __init__(self, conversion_level: ConversionLevel = ConversionLevel.HYBRID):
        self.conversion_level = conversion_level
        self.conversion_rules = self._init_conversion_rules()
        self.type_mappings = self._init_type_mappings()
        self.cmdlet_mappings = self._init_cmdlet_mappings()
        
    def _init_conversion_rules(self) -> List[ConversionRule]:
        """変換ルールの初期化"""
        return [
            # 変数
            ConversionRule(
                r'\$([a-zA-Z_]\w*)',
                r'\1',
                ConversionLevel.FULL,
                "変数の$記号を削除"
            ),
            
            # 文字列展開
            ConversionRule(
                r'"([^"]*)\$([a-zA-Z_]\w*)([^"]*)"',
                r'f"\1{\2}\3"',
                ConversionLevel.FULL,
                "文字列内の変数展開をf-stringに変換"
            ),
            
            # 配列
            ConversionRule(
                r'@\((.*?)\)',
                r'[\1]',
                ConversionLevel.FULL,
                "配列表記を変換"
            ),
            
            # ハッシュテーブル
            ConversionRule(
                r'@\{(.*?)\}',
                self._convert_hashtable,
                ConversionLevel.FULL,
                "ハッシュテーブルを辞書に変換"
            ),
            
            # 条件演算子
            ConversionRule(
                r'-eq\b', '==', ConversionLevel.FULL, "等価演算子"
            ),
            ConversionRule(
                r'-ne\b', '!=', ConversionLevel.FULL, "不等価演算子"
            ),
            ConversionRule(
                r'-gt\b', '>', ConversionLevel.FULL, "より大きい"
            ),
            ConversionRule(
                r'-lt\b', '<', ConversionLevel.FULL, "より小さい"
            ),
            ConversionRule(
                r'-ge\b', '>=', ConversionLevel.FULL, "以上"
            ),
            ConversionRule(
                r'-le\b', '<=', ConversionLevel.FULL, "以下"
            ),
            ConversionRule(
                r'-and\b', 'and', ConversionLevel.FULL, "論理AND"
            ),
            ConversionRule(
                r'-or\b', 'or', ConversionLevel.FULL, "論理OR"
            ),
            ConversionRule(
                r'-not\b', 'not', ConversionLevel.FULL, "論理NOT"
            ),
            
            # null値
            ConversionRule(
                r'\$null\b', 'None', ConversionLevel.FULL, "null値"
            ),
            
            # ブール値
            ConversionRule(
                r'\$true\b', 'True', ConversionLevel.FULL, "true値"
            ),
            ConversionRule(
                r'\$false\b', 'False', ConversionLevel.FULL, "false値"
            ),
        ]
    
    def _init_type_mappings(self) -> Dict[str, str]:
        """型マッピングの初期化"""
        return {
            '[string]': 'str',
            '[int]': 'int',
            '[int32]': 'int',
            '[int64]': 'int',
            '[float]': 'float',
            '[double]': 'float',
            '[bool]': 'bool',
            '[array]': 'list',
            '[hashtable]': 'dict',
            '[datetime]': 'datetime',
            '[pscustomobject]': 'dict',
        }
    
    def _init_cmdlet_mappings(self) -> Dict[str, Dict[str, Any]]:
        """コマンドレットマッピングの初期化"""
        return {
            # ファイル操作
            'Get-Content': {
                'python': 'open().read()',
                'import': None,
                'bridge': False
            },
            'Set-Content': {
                'python': 'open().write()',
                'import': None,
                'bridge': False
            },
            'Test-Path': {
                'python': 'Path().exists()',
                'import': 'from pathlib import Path',
                'bridge': False
            },
            'Get-ChildItem': {
                'python': 'Path().iterdir()',
                'import': 'from pathlib import Path',
                'bridge': False
            },
            'New-Item': {
                'python': 'Path().mkdir()',
                'import': 'from pathlib import Path',
                'bridge': False
            },
            'Remove-Item': {
                'python': 'Path().unlink()',
                'import': 'from pathlib import Path',
                'bridge': False
            },
            
            # 出力
            'Write-Host': {
                'python': 'print',
                'import': None,
                'bridge': False
            },
            'Write-Output': {
                'python': 'return',
                'import': None,
                'bridge': False
            },
            'Write-Error': {
                'python': 'logger.error',
                'import': 'import logging',
                'bridge': False
            },
            'Write-Warning': {
                'python': 'logger.warning',
                'import': 'import logging',
                'bridge': False
            },
            
            # Microsoft 365
            'Get-MgUser': {
                'python': 'bridge.get_users',
                'import': 'from core.powershell_bridge import PowerShellBridge',
                'bridge': True
            },
            'Get-MgGroup': {
                'python': 'bridge.call_function("Get-MgGroup")',
                'import': 'from core.powershell_bridge import PowerShellBridge',
                'bridge': True
            },
            'Connect-MgGraph': {
                'python': 'bridge.connect_graph',
                'import': 'from core.powershell_bridge import PowerShellBridge',
                'bridge': True
            },
            'Get-Mailbox': {
                'python': 'bridge.get_mailboxes',
                'import': 'from core.powershell_bridge import PowerShellBridge',
                'bridge': True
            },
            
            # データ処理
            'Select-Object': {
                'python': '[{k: d[k] for k in keys} for d in data]',
                'import': None,
                'bridge': False
            },
            'Where-Object': {
                'python': 'filter(lambda x: condition, data)',
                'import': None,
                'bridge': False
            },
            'Sort-Object': {
                'python': 'sorted(data, key=lambda x: x[key])',
                'import': None,
                'bridge': False
            },
            'ForEach-Object': {
                'python': 'for item in data:',
                'import': None,
                'bridge': False
            },
            
            # JSON操作
            'ConvertTo-Json': {
                'python': 'json.dumps',
                'import': 'import json',
                'bridge': False
            },
            'ConvertFrom-Json': {
                'python': 'json.loads',
                'import': 'import json',
                'bridge': False
            },
        }
    
    def convert_file(self, ps_file: Path) -> ConversionResult:
        """PowerShellファイルをPythonに変換"""
        logger.info(f"Converting {ps_file}")
        
        with open(ps_file, 'r', encoding='utf-8') as f:
            ps_code = f.read()
        
        return self.convert_code(ps_code, ps_file.name)
    
    def convert_code(self, ps_code: str, filename: str = "converted.py") -> ConversionResult:
        """PowerShellコードをPythonに変換"""
        imports = set()
        warnings = []
        bridge_calls = []
        
        # 関数定義の変換
        python_code = self._convert_functions(ps_code)
        
        # パラメータブロックの変換
        python_code = self._convert_parameters(python_code)
        
        # 制御構造の変換
        python_code = self._convert_control_structures(python_code)
        
        # 基本的な構文変換
        for rule in self.conversion_rules:
            if isinstance(rule.replacement, str):
                python_code = re.sub(rule.pattern, rule.replacement, python_code)
            else:
                python_code = re.sub(rule.pattern, rule.replacement, python_code)
        
        # コマンドレットの変換
        python_code, cmdlet_imports, cmdlet_bridges = self._convert_cmdlets(python_code)
        imports.update(cmdlet_imports)
        bridge_calls.extend(cmdlet_bridges)
        
        # 型キャストの変換
        python_code = self._convert_type_casts(python_code)
        
        # パイプラインの変換
        python_code = self._convert_pipelines(python_code)
        
        # インポート文の追加
        if imports:
            import_block = '\n'.join(sorted(imports))
            python_code = f"{import_block}\n\n{python_code}"
        
        # ヘッダーコメントの追加
        header = f'"""\n自動変換されたPythonコード\n元ファイル: {filename}\n"""\n\n'
        python_code = header + python_code
        
        return ConversionResult(
            python_code=python_code,
            imports=list(imports),
            warnings=warnings,
            bridge_calls=bridge_calls,
            conversion_level=self.conversion_level
        )
    
    def _convert_functions(self, code: str) -> str:
        """関数定義を変換"""
        # function Name-Style { } → def name_style():
        def convert_function(match):
            func_name = match.group(1)
            body = match.group(2)
            
            # PowerShellの命名規則をPythonスタイルに変換
            py_name = self._convert_function_name(func_name)
            
            # パラメータを抽出
            param_match = re.search(r'param\s*\((.*?)\)', body, re.DOTALL)
            if param_match:
                params = self._parse_parameters(param_match.group(1))
                param_str = ', '.join(params)
                body = body.replace(param_match.group(0), '')
            else:
                param_str = ''
            
            # インデント調整
            body_lines = body.strip().split('\n')
            indented_body = '\n'.join('    ' + line for line in body_lines)
            
            return f"def {py_name}({param_str}):\n{indented_body}"
        
        pattern = r'function\s+([A-Z][a-zA-Z0-9-]+)\s*\{(.*?)\}'
        return re.sub(pattern, convert_function, code, flags=re.DOTALL)
    
    def _convert_function_name(self, ps_name: str) -> str:
        """PowerShell関数名をPython形式に変換"""
        # Get-Something → get_something
        parts = ps_name.split('-')
        if len(parts) == 2:
            verb, noun = parts
            return f"{verb.lower()}_{noun.lower()}"
        else:
            # キャメルケースをスネークケースに
            s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', ps_name)
            return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()
    
    def _convert_parameters(self, code: str) -> str:
        """パラメータブロックを変換"""
        # param([string]$Name = "Default") → name: str = "Default"
        def convert_param(match):
            full_match = match.group(0)
            params = match.group(1)
            
            param_list = self._parse_parameters(params)
            
            # 関数のシグネチャとして使用される場合はそのまま返す
            if 'def ' in code[:match.start()]:
                return ', '.join(param_list)
            
            # スタンドアロンのparamブロックは変数定義に変換
            assignments = []
            for param in param_list:
                if '=' in param:
                    name, default = param.split('=', 1)
                    assignments.append(f"{name.strip()} = {default.strip()}")
                else:
                    assignments.append(f"{param} = None")
            
            return '\n'.join(assignments)
        
        pattern = r'param\s*\((.*?)\)'
        return re.sub(pattern, convert_param, code, flags=re.DOTALL)
    
    def _parse_parameters(self, params_str: str) -> List[str]:
        """パラメータ文字列を解析"""
        params = []
        for param in params_str.split(','):
            param = param.strip()
            if not param:
                continue
            
            # 型注釈を抽出
            type_match = re.match(r'\[([^\]]+)\]\s*\$(\w+)(?:\s*=\s*(.+))?', param)
            if type_match:
                ps_type = type_match.group(1)
                name = type_match.group(2)
                default = type_match.group(3)
                
                py_type = self.type_mappings.get(f'[{ps_type.lower()}]', 'Any')
                
                if default:
                    params.append(f"{name}: {py_type} = {default}")
                else:
                    params.append(f"{name}: {py_type}")
            else:
                # 型注釈なし
                var_match = re.match(r'\$(\w+)(?:\s*=\s*(.+))?', param)
                if var_match:
                    name = var_match.group(1)
                    default = var_match.group(2)
                    
                    if default:
                        params.append(f"{name} = {default}")
                    else:
                        params.append(name)
        
        return params
    
    def _convert_control_structures(self, code: str) -> str:
        """制御構造を変換"""
        # if文
        code = re.sub(
            r'if\s*\((.*?)\)\s*\{',
            r'if \1:',
            code
        )
        
        # elseif → elif
        code = re.sub(
            r'elseif\s*\((.*?)\)\s*\{',
            r'elif \1:',
            code
        )
        
        # else
        code = re.sub(
            r'else\s*\{',
            r'else:',
            code
        )
        
        # foreach
        code = re.sub(
            r'foreach\s*\(\s*\$(\w+)\s+in\s+\$(\w+)\s*\)\s*\{',
            r'for \1 in \2:',
            code
        )
        
        # while
        code = re.sub(
            r'while\s*\((.*?)\)\s*\{',
            r'while \1:',
            code
        )
        
        # switch (簡単なケース)
        code = self._convert_switch_statement(code)
        
        # try-catch
        code = re.sub(
            r'try\s*\{',
            r'try:',
            code
        )
        code = re.sub(
            r'catch\s*(?:\[(.*?)\])?\s*\{',
            r'except \1:',
            code
        )
        code = re.sub(
            r'finally\s*\{',
            r'finally:',
            code
        )
        
        # 波括弧の削除（インデントベースに）
        # 注: 実際の実装では適切なインデント処理が必要
        code = re.sub(r'\}', '', code)
        
        return code
    
    def _convert_switch_statement(self, code: str) -> str:
        """switch文をif-elif-elseに変換"""
        def convert_switch(match):
            var = match.group(1)
            cases = match.group(2)
            
            # ケースを解析
            case_pattern = r'"([^"]+)"\s*\{([^}]+)\}'
            case_matches = re.findall(case_pattern, cases)
            
            if not case_matches:
                return match.group(0)
            
            result = []
            for i, (value, action) in enumerate(case_matches):
                if i == 0:
                    result.append(f"if {var} == '{value}':\n    {action.strip()}")
                else:
                    result.append(f"elif {var} == '{value}':\n    {action.strip()}")
            
            # default ケース
            default_match = re.search(r'default\s*\{([^}]+)\}', cases)
            if default_match:
                result.append(f"else:\n    {default_match.group(1).strip()}")
            
            return '\n'.join(result)
        
        pattern = r'switch\s*\(\s*\$(\w+)\s*\)\s*\{(.*?)\}'
        return re.sub(pattern, convert_switch, code, flags=re.DOTALL)
    
    def _convert_cmdlets(self, code: str) -> Tuple[str, set, list]:
        """コマンドレットを変換"""
        imports = set()
        bridge_calls = []
        
        for cmdlet, mapping in self.cmdlet_mappings.items():
            if cmdlet in code:
                if mapping['import']:
                    imports.add(mapping['import'])
                
                if mapping['bridge']:
                    bridge_calls.append(cmdlet)
                    if self.conversion_level == ConversionLevel.FULL:
                        # 完全変換モードでもブリッジが必要な場合は警告
                        logger.warning(f"{cmdlet} requires PowerShell bridge")
                
                # 単純な置換（実際はより複雑な処理が必要）
                code = code.replace(cmdlet, mapping['python'])
        
        return code, imports, bridge_calls
    
    def _convert_type_casts(self, code: str) -> str:
        """型キャストを変換"""
        for ps_type, py_type in self.type_mappings.items():
            # [type]$var → type(var)
            pattern = rf'{re.escape(ps_type)}\s*\$(\w+)'
            replacement = rf'{py_type}(\1)'
            code = re.sub(pattern, replacement, code)
        
        return code
    
    def _convert_pipelines(self, code: str) -> str:
        """パイプラインを変換"""
        # 簡単なパイプラインの変換
        # Get-ChildItem | Where-Object {$_.Name -like "*.txt"}
        # → [f for f in Path().iterdir() if f.name.endswith('.txt')]
        
        # 注: 完全な実装は複雑なため、ここでは基本的な例のみ
        pipeline_pattern = r'([^|]+)\s*\|\s*([^|]+)'
        
        def convert_pipeline(match):
            source = match.group(1).strip()
            operation = match.group(2).strip()
            
            # 基本的な変換ロジック
            if 'Where-Object' in operation:
                return f"filter(lambda x: condition, {source})"
            elif 'Select-Object' in operation:
                return f"[item for item in {source}]"
            elif 'ForEach-Object' in operation:
                return f"for item in {source}:"
            else:
                return match.group(0)
        
        return re.sub(pipeline_pattern, convert_pipeline, code)
    
    def _convert_hashtable(self, match) -> str:
        """ハッシュテーブルを辞書に変換"""
        content = match.group(1)
        # key = value → "key": value
        items = []
        for item in content.split(';'):
            item = item.strip()
            if '=' in item:
                key, value = item.split('=', 1)
                key = key.strip()
                value = value.strip()
                # キーをクォート
                if not (key.startswith('"') or key.startswith("'")):
                    key = f'"{key}"'
                items.append(f'{key}: {value}')
        
        return '{' + ', '.join(items) + '}'
    
    def analyze_script(self, ps_file: Path) -> Dict[str, Any]:
        """スクリプトを分析して移行の複雑さを評価"""
        with open(ps_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        analysis = {
            'file': str(ps_file),
            'lines': len(content.splitlines()),
            'functions': len(re.findall(r'function\s+\w+', content)),
            'cmdlets': {},
            'complexity': 'low',
            'bridge_required': [],
            'estimated_effort': 'low'
        }
        
        # 使用されているコマンドレットを分析
        for cmdlet in self.cmdlet_mappings:
            count = content.count(cmdlet)
            if count > 0:
                analysis['cmdlets'][cmdlet] = count
                if self.cmdlet_mappings[cmdlet]['bridge']:
                    analysis['bridge_required'].append(cmdlet)
        
        # 複雑さの評価
        if len(analysis['bridge_required']) > 5:
            analysis['complexity'] = 'high'
            analysis['estimated_effort'] = 'high'
        elif len(analysis['bridge_required']) > 2:
            analysis['complexity'] = 'medium'
            analysis['estimated_effort'] = 'medium'
        
        # 特殊な構造の検出
        if 'System.Windows.Forms' in content:
            analysis['gui_present'] = True
            analysis['complexity'] = 'high'
        
        if '.NET' in content or '[System.' in content:
            analysis['dotnet_interop'] = True
            analysis['complexity'] = 'high'
        
        return analysis


# 使用例
if __name__ == '__main__':
    converter = PowerShellToPythonConverter(ConversionLevel.HYBRID)
    
    # サンプルPowerShellコード
    sample_ps = '''
    function Get-UserReport {
        param(
            [string]$Department = "All",
            [int]$MaxResults = 100
        )
        
        $users = Get-MgUser -All | Where-Object { $_.Department -eq $Department }
        
        foreach ($user in $users) {
            if ($user.AccountEnabled -eq $true) {
                Write-Host "Active user: $($user.DisplayName)"
            }
        }
        
        return $users | Select-Object -First $MaxResults
    }
    '''
    
    result = converter.convert_code(sample_ps)
    print("=== 変換結果 ===")
    print(result.python_code)
    print("\n=== インポート ===")
    print(result.imports)
    print("\n=== ブリッジ呼び出し ===")
    print(result.bridge_calls)