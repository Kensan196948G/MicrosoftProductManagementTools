"""
PowerShell to Python コンバーター
PowerShellスクリプトをPythonコードに自動変換する移行ツール
"""

import re
import ast
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass
from enum import Enum


class ConversionLevel(Enum):
    """変換レベル"""
    BASIC = "basic"          # 基本的な構文変換のみ
    INTERMEDIATE = "intermediate"  # API呼び出しも含む
    ADVANCED = "advanced"    # 完全な機能変換


@dataclass
class ConversionRule:
    """変換ルール定義"""
    pattern: str
    replacement: str
    description: str
    level: ConversionLevel
    multiline: bool = False


class PowerShellToPythonConverter:
    """PowerShellからPythonへの変換エンジン"""
    
    def __init__(self, conversion_level: ConversionLevel = ConversionLevel.INTERMEDIATE):
        self.conversion_level = conversion_level
        self.conversion_rules = self._initialize_rules()
        self.import_statements = set()
        self.warnings = []
        
    def _initialize_rules(self) -> List[ConversionRule]:
        """変換ルールの初期化"""
        rules = [
            # 基本的な変数変換
            ConversionRule(
                pattern=r'\$([a-zA-Z_]\w*)',
                replacement=r'\1',
                description="変数の$記号を削除",
                level=ConversionLevel.BASIC
            ),
            
            # 文字列補間
            ConversionRule(
                pattern=r'"([^"]*)\$([a-zA-Z_]\w*)([^"]*)"',
                replacement=r'f"\1{\2}\3"',
                description="文字列補間をf-stringに変換",
                level=ConversionLevel.BASIC
            ),
            
            # 配列定義
            ConversionRule(
                pattern=r'@\((.*?)\)',
                replacement=r'[\1]',
                description="配列をリストに変換",
                level=ConversionLevel.BASIC
            ),
            
            # ハッシュテーブル
            ConversionRule(
                pattern=r'@{([^}]+)}',
                replacement=self._convert_hashtable,
                description="ハッシュテーブルを辞書に変換",
                level=ConversionLevel.BASIC
            ),
            
            # 関数定義
            ConversionRule(
                pattern=r'function\s+([A-Z][a-zA-Z]*)-([A-Z][a-zA-Z]*)\s*{',
                replacement=r'def \1_\2():',
                description="関数定義をPython形式に変換",
                level=ConversionLevel.BASIC,
                multiline=True
            ),
            
            # パラメータ定義
            ConversionRule(
                pattern=r'param\s*\(\s*\[([^\]]+)\]\s*\$([a-zA-Z_]\w*)\s*\)',
                replacement=r'def function(\2: \1):',
                description="パラメータ定義を関数引数に変換",
                level=ConversionLevel.BASIC
            ),
            
            # if文
            ConversionRule(
                pattern=r'if\s*\((.*?)\)\s*{',
                replacement=r'if \1:',
                description="if文の変換",
                level=ConversionLevel.BASIC
            ),
            
            # foreach文
            ConversionRule(
                pattern=r'foreach\s*\(\s*\$([a-zA-Z_]\w*)\s+in\s+\$([a-zA-Z_]\w*)\s*\)\s*{',
                replacement=r'for \1 in \2:',
                description="foreach文をfor文に変換",
                level=ConversionLevel.BASIC
            ),
            
            # try-catch
            ConversionRule(
                pattern=r'try\s*{',
                replacement=r'try:',
                description="try文の変換",
                level=ConversionLevel.BASIC
            ),
            
            ConversionRule(
                pattern=r'}\s*catch\s*{',
                replacement=r'except Exception as e:',
                description="catch文の変換",
                level=ConversionLevel.BASIC
            ),
            
            # Write-Host
            ConversionRule(
                pattern=r'Write-Host\s+"([^"]+)"',
                replacement=r'print("\1")',
                description="Write-Hostをprintに変換",
                level=ConversionLevel.BASIC
            ),
            
            # コメント
            ConversionRule(
                pattern=r'#(.*)$',
                replacement=r'#\1',
                description="コメントはそのまま",
                level=ConversionLevel.BASIC
            ),
            
            # 比較演算子
            ConversionRule(
                pattern=r'-eq',
                replacement=r'==',
                description="等価演算子",
                level=ConversionLevel.BASIC
            ),
            
            ConversionRule(
                pattern=r'-ne',
                replacement=r'!=',
                description="不等価演算子",
                level=ConversionLevel.BASIC
            ),
            
            ConversionRule(
                pattern=r'-gt',
                replacement=r'>',
                description="大なり演算子",
                level=ConversionLevel.BASIC
            ),
            
            ConversionRule(
                pattern=r'-lt',
                replacement=r'<',
                description="小なり演算子",
                level=ConversionLevel.BASIC
            ),
            
            # 論理演算子
            ConversionRule(
                pattern=r'-and',
                replacement=r'and',
                description="AND演算子",
                level=ConversionLevel.BASIC
            ),
            
            ConversionRule(
                pattern=r'-or',
                replacement=r'or',
                description="OR演算子",
                level=ConversionLevel.BASIC
            ),
            
            ConversionRule(
                pattern=r'-not',
                replacement=r'not',
                description="NOT演算子",
                level=ConversionLevel.BASIC
            ),
            
            # Microsoft 365 API変換（中級レベル）
            ConversionRule(
                pattern=r'Connect-MgGraph',
                replacement=self._convert_graph_connect,
                description="Graph API接続",
                level=ConversionLevel.INTERMEDIATE
            ),
            
            ConversionRule(
                pattern=r'Get-MgUser',
                replacement=self._convert_get_user,
                description="ユーザー取得",
                level=ConversionLevel.INTERMEDIATE
            ),
            
            # ファイル操作
            ConversionRule(
                pattern=r'Get-Content\s+"([^"]+)"',
                replacement=r'Path("\1").read_text()',
                description="ファイル読み込み",
                level=ConversionLevel.INTERMEDIATE
            ),
            
            ConversionRule(
                pattern=r'Set-Content\s+-Path\s+"([^"]+)"\s+-Value\s+"([^"]+)"',
                replacement=r'Path("\1").write_text("\2")',
                description="ファイル書き込み",
                level=ConversionLevel.INTERMEDIATE
            ),
        ]
        
        # レベルに応じてルールをフィルタリング
        return [r for r in rules if r.level.value <= self.conversion_level.value]
    
    def _convert_hashtable(self, match) -> str:
        """ハッシュテーブルを辞書に変換"""
        content = match.group(1)
        # key=value形式を"key": valueに変換
        items = []
        for item in content.split(';'):
            if '=' in item:
                key, value = item.split('=', 1)
                key = key.strip()
                value = value.strip()
                items.append(f'"{key}": {value}')
        return '{' + ', '.join(items) + '}'
    
    def _convert_graph_connect(self, match) -> str:
        """Graph API接続の変換"""
        self.import_statements.add("from msal import PublicClientApplication")
        self.import_statements.add("from msgraph import GraphServiceClient")
        return """# Graph API接続
app = PublicClientApplication(client_id=config['EntraID']['ClientId'])
graph_client = GraphServiceClient(credentials=app)"""
    
    def _convert_get_user(self, match) -> str:
        """ユーザー取得の変換"""
        self.import_statements.add("from msgraph import GraphServiceClient")
        return "graph_client.users.get()"
    
    def convert_file(self, ps_file_path: Path, output_path: Optional[Path] = None) -> str:
        """PowerShellファイルをPythonに変換"""
        # ファイル読み込み
        ps_content = ps_file_path.read_text(encoding='utf-8')
        
        # 変換実行
        py_content = self.convert_script(ps_content)
        
        # 出力パスが指定されていれば保存
        if output_path:
            output_path.write_text(py_content, encoding='utf-8')
            
        return py_content
    
    def convert_script(self, ps_script: str) -> str:
        """PowerShellスクリプトをPythonに変換"""
        self.import_statements.clear()
        self.warnings.clear()
        
        # 基本的なインポートを追加
        self.import_statements.add("#!/usr/bin/env python3")
        self.import_statements.add('"""')
        self.import_statements.add("自動変換されたPythonスクリプト")
        self.import_statements.add("元ファイル: PowerShellスクリプト")
        self.import_statements.add('"""')
        self.import_statements.add("")
        self.import_statements.add("from pathlib import Path")
        self.import_statements.add("import json")
        self.import_statements.add("import os")
        self.import_statements.add("import sys")
        
        # 変換処理
        converted = ps_script
        for rule in self.conversion_rules:
            if callable(rule.replacement):
                # 関数による置換
                converted = re.sub(rule.pattern, rule.replacement, converted, 
                                 flags=re.MULTILINE if rule.multiline else 0)
            else:
                # 単純な文字列置換
                converted = re.sub(rule.pattern, rule.replacement, converted,
                                 flags=re.MULTILINE if rule.multiline else 0)
        
        # インデントの調整
        converted = self._adjust_indentation(converted)
        
        # インポート文を先頭に追加
        imports = '\n'.join(sorted(self.import_statements))
        
        # 警告を追加
        if self.warnings:
            warnings = "\n# 警告:\n# " + "\n# ".join(self.warnings)
        else:
            warnings = ""
        
        return f"{imports}\n\n{warnings}\n\n{converted}"
    
    def _adjust_indentation(self, code: str) -> str:
        """インデントを調整"""
        lines = code.split('\n')
        adjusted_lines = []
        indent_level = 0
        
        for line in lines:
            stripped = line.strip()
            
            # インデントを減らす条件
            if stripped.startswith(('else:', 'elif', 'except:', 'finally:')):
                indent_level = max(0, indent_level - 1)
            
            # 現在のインデントレベルで行を追加
            if stripped:
                adjusted_lines.append('    ' * indent_level + stripped)
            else:
                adjusted_lines.append('')
            
            # インデントを増やす条件
            if stripped.endswith(':'):
                indent_level += 1
            
            # 波括弧の処理（PowerShellの残骸）
            if stripped == '}':
                indent_level = max(0, indent_level - 1)
                adjusted_lines[-1] = ''  # 波括弧は削除
        
        return '\n'.join(adjusted_lines)
    
    def analyze_conversion_complexity(self, ps_file_path: Path) -> Dict[str, Any]:
        """変換の複雑さを分析"""
        ps_content = ps_file_path.read_text(encoding='utf-8')
        
        analysis = {
            'file_path': str(ps_file_path),
            'total_lines': len(ps_content.split('\n')),
            'functions': len(re.findall(r'function\s+\w+-\w+', ps_content)),
            'cmdlets': len(re.findall(r'[A-Z][a-zA-Z]+-[A-Z][a-zA-Z]+', ps_content)),
            'complexity': 'low',
            'estimated_effort': '1-2 hours',
            'manual_review_required': []
        }
        
        # 複雑な要素をチェック
        complex_patterns = {
            'COM objects': r'New-Object\s+-ComObject',
            'WMI queries': r'Get-WmiObject|Get-CimInstance',
            'Registry access': r'Get-ItemProperty.*HKLM:|HKCU:',
            'Pipeline operations': r'\|.*\|.*\|',
            'Background jobs': r'Start-Job|Receive-Job',
            '.NET types': r'\[System\.',
            'P/Invoke': r'Add-Type.*-MemberDefinition'
        }
        
        for name, pattern in complex_patterns.items():
            if re.search(pattern, ps_content):
                analysis['manual_review_required'].append(name)
        
        # 複雑さの評価
        if len(analysis['manual_review_required']) > 3:
            analysis['complexity'] = 'high'
            analysis['estimated_effort'] = '1-2 days'
        elif len(analysis['manual_review_required']) > 0:
            analysis['complexity'] = 'medium'
            analysis['estimated_effort'] = '4-8 hours'
        
        return analysis
    
    def batch_convert(self, source_dir: Path, output_dir: Path, 
                     file_pattern: str = "*.ps1") -> List[Dict[str, Any]]:
        """ディレクトリ内のPowerShellファイルを一括変換"""
        results = []
        output_dir.mkdir(parents=True, exist_ok=True)
        
        for ps_file in source_dir.glob(file_pattern):
            try:
                # 出力ファイル名を決定
                py_file = output_dir / ps_file.with_suffix('.py').name
                
                # 変換実行
                self.convert_file(ps_file, py_file)
                
                # 結果を記録
                results.append({
                    'source': str(ps_file),
                    'output': str(py_file),
                    'status': 'success',
                    'warnings': self.warnings.copy()
                })
                
            except Exception as e:
                results.append({
                    'source': str(ps_file),
                    'output': None,
                    'status': 'error',
                    'error': str(e)
                })
        
        return results


class PowerShellBridge:
    """PowerShellとPythonの相互運用ブリッジ"""
    
    def __init__(self):
        import subprocess
        self.subprocess = subprocess
        self.pwsh_exe = self._find_powershell()
        
    def _find_powershell(self) -> str:
        """利用可能なPowerShellを検索"""
        candidates = ['pwsh', 'powershell', 'pwsh.exe', 'powershell.exe']
        
        for candidate in candidates:
            try:
                result = self.subprocess.run(
                    [candidate, '-Version'],
                    capture_output=True,
                    text=True
                )
                if result.returncode == 0:
                    return candidate
            except FileNotFoundError:
                continue
                
        raise RuntimeError("PowerShellが見つかりません")
    
    def execute_command(self, command: str, return_json: bool = True) -> Any:
        """PowerShellコマンドを実行"""
        if return_json:
            command = f"{command} | ConvertTo-Json -Depth 10"
        
        result = self.subprocess.run(
            [self.pwsh_exe, '-Command', command],
            capture_output=True,
            text=True,
            encoding='utf-8'
        )
        
        if result.returncode != 0:
            raise RuntimeError(f"PowerShellエラー: {result.stderr}")
        
        if return_json and result.stdout:
            import json
            return json.loads(result.stdout)
        
        return result.stdout
    
    def execute_script(self, script_path: str, parameters: Dict[str, Any] = None) -> Any:
        """PowerShellスクリプトを実行"""
        cmd = [self.pwsh_exe, '-File', script_path]
        
        if parameters:
            for key, value in parameters.items():
                cmd.extend([f'-{key}', str(value)])
        
        result = self.subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding='utf-8'
        )
        
        if result.returncode != 0:
            raise RuntimeError(f"スクリプトエラー: {result.stderr}")
        
        return result.stdout
    
    def import_module(self, module_path: str) -> None:
        """PowerShellモジュールをインポート"""
        command = f"Import-Module '{module_path}' -Force"
        self.execute_command(command, return_json=False)
    
    def call_function(self, function_name: str, **kwargs) -> Any:
        """PowerShell関数を呼び出す"""
        params = []
        for key, value in kwargs.items():
            if isinstance(value, bool):
                if value:
                    params.append(f"-{key}")
            else:
                params.append(f"-{key} '{value}'")
        
        command = f"{function_name} {' '.join(params)}"
        return self.execute_command(command)


def main():
    """コマンドライン実行用エントリーポイント"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="PowerShellからPythonへの変換ツール"
    )
    parser.add_argument(
        'source',
        type=Path,
        help='変換元のPowerShellファイルまたはディレクトリ'
    )
    parser.add_argument(
        '-o', '--output',
        type=Path,
        help='出力先のファイルまたはディレクトリ'
    )
    parser.add_argument(
        '-l', '--level',
        choices=['basic', 'intermediate', 'advanced'],
        default='intermediate',
        help='変換レベル'
    )
    parser.add_argument(
        '-a', '--analyze',
        action='store_true',
        help='変換の複雑さを分析'
    )
    
    args = parser.parse_args()
    
    # コンバーターのインスタンス化
    converter = PowerShellToPythonConverter(
        ConversionLevel(args.level)
    )
    
    if args.analyze:
        # 複雑さ分析
        if args.source.is_file():
            analysis = converter.analyze_conversion_complexity(args.source)
            print(json.dumps(analysis, indent=2, ensure_ascii=False))
        else:
            print("分析はファイルに対してのみ実行できます")
        return
    
    if args.source.is_file():
        # 単一ファイルの変換
        output = converter.convert_file(args.source, args.output)
        if not args.output:
            print(output)
    else:
        # ディレクトリの一括変換
        if not args.output:
            print("ディレクトリ変換には出力先を指定してください")
            return
        
        results = converter.batch_convert(args.source, args.output)
        print(f"変換完了: {len(results)}ファイル")
        
        # エラーがあれば表示
        errors = [r for r in results if r['status'] == 'error']
        if errors:
            print(f"\nエラー: {len(errors)}件")
            for error in errors:
                print(f"  - {error['source']}: {error['error']}")


if __name__ == '__main__':
    main()