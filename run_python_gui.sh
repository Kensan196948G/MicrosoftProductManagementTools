#!/bin/bash
# ================================================================================
# Microsoft 365 統合管理ツール - Python GUI 起動スクリプト (Linux/macOS)
# 完全版 Python Edition v2.0 - PowerShell GUI完全互換
# ================================================================================

set -e

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# スクリプトのパスを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_MAIN_SCRIPT="$SCRIPT_DIR/src/main.py"

# バナー表示
echo -e "${CYAN}================================================================================${NC}"
echo -e "${YELLOW}🚀 Microsoft 365 統合管理ツール - 完全版 Python Edition v2.0${NC}"
echo -e "${GREEN}   PowerShell GUI完全互換 - 26機能搭載${NC}"
echo -e "${CYAN}================================================================================${NC}"

# ヘルプ表示
show_help() {
    echo -e "${WHITE}使用方法:${NC}"
    echo -e "  $0 [オプション]"
    echo -e ""
    echo -e "${WHITE}オプション:${NC}"
    echo -e "  --cli                   CLI モードで起動"
    echo -e "  --install-deps          Python パッケージを自動インストール"
    echo -e "  --test                  テストモード（実際には起動しない）"
    echo -e "  --debug                 デバッグモード"
    echo -e "  --help                  このヘルプを表示"
    echo -e ""
    echo -e "${WHITE}例:${NC}"
    echo -e "  $0                      # GUI モードで起動"
    echo -e "  $0 --cli                # CLI モードで起動"
    echo -e "  $0 --install-deps       # 依存関係をインストールしてGUI起動"
    echo -e "  $0 --cli --debug        # CLI デバッグモードで起動"
}

# Python バージョンチェック
check_python_version() {
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        echo -e "${RED}❌ Python が見つかりません。${NC}"
        return 1
    fi
    
    local version_output
    version_output=$($PYTHON_CMD --version 2>&1)
    
    if [[ $version_output =~ Python\ ([0-9]+)\.([0-9]+) ]]; then
        local major=${BASH_REMATCH[1]}
        local minor=${BASH_REMATCH[2]}
        
        if [[ $major -ge 3 && $minor -ge 9 ]]; then
            echo -e "${GREEN}✅ Python バージョン確認: $version_output${NC}"
            return 0
        else
            echo -e "${RED}❌ Python 3.9以上が必要です。現在: $version_output${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Python バージョンの確認に失敗しました。${NC}"
        return 1
    fi
}

# 仮想環境の確認
check_virtual_environment() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo -e "${GREEN}✅ 仮想環境が有効です: $VIRTUAL_ENV${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  仮想環境が検出されません。グローバル環境を使用します。${NC}"
        return 1
    fi
}

# 必要なパッケージのインストール
install_python_dependencies() {
    echo -e "${YELLOW}📦 Python パッケージのインストール中...${NC}"
    
    local packages=(
        "PyQt6"
        "msal"
        "pandas"
        "jinja2"
        "requests"
        "python-dateutil"
        "pytz"
    )
    
    for package in "${packages[@]}"; do
        echo -e "${CYAN}  インストール中: $package${NC}"
        if $PYTHON_CMD -m pip install "$package" --upgrade > /dev/null 2>&1; then
            echo -e "${GREEN}  ✅ $package インストール完了${NC}"
        else
            echo -e "${RED}  ❌ $package インストール失敗${NC}"
        fi
    done
}

# パラメータ解析
CLI_MODE=false
INSTALL_DEPS=false
TEST_MODE=false
DEBUG_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --cli)
            CLI_MODE=true
            shift
            ;;
        --install-deps)
            INSTALL_DEPS=true
            shift
            ;;
        --test)
            TEST_MODE=true
            shift
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}不明なオプション: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# メイン処理
main() {
    # 作業ディレクトリを変更
    cd "$SCRIPT_DIR"
    
    # Python バージョンチェック
    if ! check_python_version; then
        echo -e "${RED}Python 3.9以上をインストールしてください。${NC}"
        echo -e "${YELLOW}ダウンロード: https://www.python.org/downloads/${NC}"
        exit 1
    fi
    
    # 仮想環境チェック
    check_virtual_environment
    
    # 依存関係のインストール
    if [[ "$INSTALL_DEPS" == true ]]; then
        install_python_dependencies
    fi
    
    # メインスクリプトの存在確認
    if [[ ! -f "$PYTHON_MAIN_SCRIPT" ]]; then
        echo -e "${RED}❌ メインスクリプトが見つかりません: $PYTHON_MAIN_SCRIPT${NC}"
        exit 1
    fi
    
    # 起動モード決定
    local arguments=()
    
    if [[ "$CLI_MODE" == true ]]; then
        arguments+=("cli")
        echo -e "${CYAN}📋 CLI モードで起動中...${NC}"
    else
        echo -e "${CYAN}🖥️  GUI モードで起動中...${NC}"
    fi
    
    if [[ "$DEBUG_MODE" == true ]]; then
        arguments+=("--debug")
        echo -e "${YELLOW}🐛 デバッグモードが有効です${NC}"
    fi
    
    # Python アプリケーション起動
    echo -e "${GREEN}🚀 アプリケーション起動中...${NC}"
    
    if [[ "$TEST_MODE" == true ]]; then
        echo -e "${MAGENTA}テストモード: $PYTHON_CMD \"$PYTHON_MAIN_SCRIPT\" ${arguments[*]}${NC}"
    else
        if $PYTHON_CMD "$PYTHON_MAIN_SCRIPT" "${arguments[@]}"; then
            echo -e "${GREEN}✅ アプリケーション正常終了${NC}"
        else
            echo -e "${RED}❌ アプリケーション異常終了 (終了コード: $?)${NC}"
            exit 1
        fi
    fi
}

# メイン実行
main "$@"