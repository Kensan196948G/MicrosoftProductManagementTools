#!/bin/bash

# ================================================================================
# test_verification.sh
# Microsoft製品運用管理ツール - 構造検証スクリプト
# PowerShellが利用できない環境での代替検証
# ================================================================================

echo "======================================================================"
echo "Microsoft製品運用管理ツール - 構造検証を開始します"
echo "======================================================================"

# 基本ディレクトリの存在確認
echo ""
echo "■ ディレクトリ構造確認"
echo "----------------------------------------------------------------------"

dirs=(
    "Scripts/Common"
    "Scripts/AD" 
    "Scripts/EXO"
    "Scripts/EntraID"
    "Config"
    "Reports/Daily"
    "Reports/Weekly"
    "Reports/Monthly"
    "Reports/Yearly"
    "Logs"
    "Templates"
)

missing_dirs=0
for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "✓ $dir - 存在"
    else
        echo "✗ $dir - 不存在"
        ((missing_dirs++))
    fi
done

echo ""
echo "■ 重要なファイルの存在確認"
echo "----------------------------------------------------------------------"

files=(
    "Config/appsettings.json"
    "Templates/ReportTemplate.html"
    "CLAUDE.md"
    "README.md"
    "Scripts/Common/Common.psm1"
    "Scripts/Common/Authentication.psm1"
    "Scripts/Common/Logging.psm1"
    "Scripts/Common/ErrorHandling.psm1"
    "Scripts/Common/ReportGenerator.psm1"
    "Scripts/Common/ScheduledReports.ps1"
    "Scripts/Common/AutomatedTesting.ps1"
    "Scripts/Common/ManualTestReport.ps1"
)

missing_files=0
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        echo "✓ $file - 存在 ($size)"
    else
        echo "✗ $file - 不存在"
        ((missing_files++))
    fi
done

echo ""
echo "■ スクリプトファイルの存在確認"
echo "----------------------------------------------------------------------"

script_files=(
    "Scripts/AD/GroupManagement.ps1"
    "Scripts/AD/UserManagement.ps1"
    "Scripts/EXO/MailboxManagement.ps1"
    "Scripts/EXO/SecurityAnalysis.ps1"
    "Scripts/EntraID/TeamsOneDriveManagement.ps1"
    "Scripts/EntraID/UserSecurityManagement.ps1"
)

missing_scripts=0
for script in "${script_files[@]}"; do
    if [ -f "$script" ]; then
        size=$(du -h "$script" | cut -f1)
        echo "✓ $script - 存在 ($size)"
    else
        echo "✗ $script - 不存在"
        ((missing_scripts++))
    fi
done

echo ""
echo "■ 基本的な構文チェック（PowerShellファイル）"
echo "----------------------------------------------------------------------"

syntax_errors=0
for script in $(find Scripts -name "*.ps1" -o -name "*.psm1"); do
    if [ -f "$script" ]; then
        # 基本的な文字エンコーディングと改行コードチェック
        if file "$script" | grep -q "text"; then
            echo "✓ $script - テキストファイル（正常）"
        else
            echo "⚠ $script - バイナリファイルまたは不正なエンコーディング"
            ((syntax_errors++))
        fi
        
        # 基本的なPowerShell構文パターンチェック
        if grep -q "function\|param\|Import-Module\|\$" "$script"; then
            echo "  └ PowerShell構文パターン検出"
        else
            echo "  └ ⚠ PowerShell構文パターンが検出されません"
        fi
    fi
done

echo ""
echo "======================================================================"
echo "検証結果サマリー"
echo "======================================================================"

total_dirs=${#dirs[@]}
existing_dirs=$((total_dirs - missing_dirs))

total_files=${#files[@]}
existing_files=$((total_files - missing_files))

total_scripts=${#script_files[@]}
existing_scripts=$((total_scripts - missing_scripts))

echo "ディレクトリ: $existing_dirs/$total_dirs (不足: $missing_dirs)"
echo "重要ファイル: $existing_files/$total_files (不足: $missing_files)"
echo "スクリプトファイル: $existing_scripts/$total_scripts (不足: $missing_scripts)"
echo "構文エラー: $syntax_errors"

overall_status="正常"
exit_code=0

if [ $missing_dirs -gt 0 ] || [ $missing_files -gt 0 ] || [ $missing_scripts -gt 0 ]; then
    overall_status="要確認"
    exit_code=1
fi

if [ $syntax_errors -gt 0 ]; then
    overall_status="構文要確認"
    exit_code=2
fi

echo "全体ステータス: $overall_status"

echo ""
echo "======================================================================"
echo "ITSM/ISO27001/27002準拠 Microsoft製品運用管理ツール"
echo "構造検証完了 - $(date)"
echo "======================================================================"

exit $exit_code