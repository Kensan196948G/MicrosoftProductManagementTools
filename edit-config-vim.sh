#!/bin/bash

# Microsoft製品運用管理ツール - Vim設定ファイル編集
# ITSM/ISO27001/27002準拠 - Vim/Viスタイル編集

set -e

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
CONFIG_FILE="${PROJECT_ROOT}/Config/appsettings.json"

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

show_vim_help() {
    clear
    echo -e "${CYAN}=================================================================================${NC}"
    echo -e "${WHITE}      Microsoft製品運用管理ツール - Vim設定編集ガイド${NC}"
    echo -e "${CYAN}=================================================================================${NC}"
    echo ""
    echo -e "${GREEN}📝 設定ファイル: ${CONFIG_FILE}${NC}"
    echo -e "${GREEN}📅 最終更新: $(date '+%Y年%m月%d日 %H:%M:%S')${NC}"
    echo ""
    echo -e "${YELLOW}【Vim基本操作】${NC}"
    echo -e "  ${WHITE}i${NC}        - 挿入モード開始（カーソル位置から入力開始）"
    echo -e "  ${WHITE}a${NC}        - 挿入モード開始（カーソル位置の次から入力開始）"
    echo -e "  ${WHITE}o${NC}        - 新しい行を下に作成して挿入モード"
    echo -e "  ${WHITE}O${NC}        - 新しい行を上に作成して挿入モード"
    echo -e "  ${WHITE}ESC${NC}      - ノーマルモードに戻る"
    echo ""
    echo -e "${YELLOW}【移動コマンド】${NC}"
    echo -e "  ${WHITE}h, j, k, l${NC} - 左、下、上、右に移動"
    echo -e "  ${WHITE}w${NC}        - 次の単語の先頭に移動"
    echo -e "  ${WHITE}b${NC}        - 前の単語の先頭に移動"
    echo -e "  ${WHITE}gg${NC}       - ファイルの先頭に移動"
    echo -e "  ${WHITE}G${NC}        - ファイルの末尾に移動"
    echo -e "  ${WHITE}:数字${NC}    - 指定行番号に移動（例: :10）"
    echo ""
    echo -e "${YELLOW}【編集コマンド】${NC}"
    echo -e "  ${WHITE}x${NC}        - 1文字削除"
    echo -e "  ${WHITE}dd${NC}       - 1行削除"
    echo -e "  ${WHITE}yy${NC}       - 1行コピー"
    echo -e "  ${WHITE}p${NC}        - ペースト"
    echo -e "  ${WHITE}u${NC}        - アンドゥ（元に戻す）"
    echo -e "  ${WHITE}Ctrl+r${NC}   - リドゥ（やり直し）"
    echo ""
    echo -e "${YELLOW}【検索・置換】${NC}"
    echo -e "  ${WHITE}/文字列${NC}  - 前方検索"
    echo -e "  ${WHITE}?文字列${NC}  - 後方検索"
    echo -e "  ${WHITE}n${NC}        - 次の検索結果"
    echo -e "  ${WHITE}N${NC}        - 前の検索結果"
    echo -e "  ${WHITE}:%s/old/new/g${NC} - 全置換（例: :%s/test/prod/g）"
    echo ""
    echo -e "${YELLOW}【保存・終了】${NC}"
    echo -e "  ${WHITE}:w${NC}       - 保存"
    echo -e "  ${WHITE}:q${NC}       - 終了"
    echo -e "  ${WHITE}:wq${NC}      - 保存して終了"
    echo -e "  ${WHITE}:q!${NC}      - 強制終了（保存しない）"
    echo -e "  ${WHITE}ZZ${NC}       - 保存して終了（ショートカット）"
    echo ""
    echo -e "${YELLOW}【JSON編集のコツ】${NC}"
    echo -e "  ${GREEN}•${NC} JSON構文エラーを避けるため、括弧とカンマに注意"
    echo -e "  ${GREEN}•${NC} 文字列は必ず\"\"で囲む"
    echo -e "  ${GREEN}•${NC} 最後の項目にはカンマを付けない"
    echo -e "  ${GREEN}•${NC} インデント（字下げ）を揃える"
    echo ""
    echo -e "${YELLOW}【重要な設定項目】${NC}"
    echo -e "  ${GREEN}•${NC} ${WHITE}EntraID.TenantId${NC}     - Azure ADテナントID"
    echo -e "  ${GREEN}•${NC} ${WHITE}EntraID.ClientId${NC}     - アプリケーションID"
    echo -e "  ${GREEN}•${NC} ${WHITE}General.OrganizationName${NC} - 組織名"
    echo -e "  ${GREEN}•${NC} ${WHITE}General.Environment${NC}   - 環境（Production/Test）"
    echo ""
    echo -e "${CYAN}=================================================================================${NC}"
    echo -e "${WHITE}Enterキーを押してVimエディターを開始...${NC}"
    read -r
}

# バックアップ作成
create_backup() {
    local backup_file="${CONFIG_FILE}.backup.$(date '+%Y%m%d_%H%M%S')"
    cp "${CONFIG_FILE}" "${backup_file}"
    echo -e "${GREEN}✅ バックアップ作成: ${backup_file}${NC}"
}

# JSON構文チェック
validate_json() {
    if python3 -m json.tool "${CONFIG_FILE}" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ JSON構文チェック: 正常${NC}"
        return 0
    else
        echo -e "${RED}❌ JSON構文チェック: エラー検出${NC}"
        echo -e "${YELLOW}💡 構文エラーがあります。修正してください。${NC}"
        return 1
    fi
}

# 変更内容の確認
show_changes() {
    echo -e "${CYAN}=================================================================================${NC}"
    echo -e "${WHITE}      設定ファイル編集後の確認${NC}"
    echo -e "${CYAN}=================================================================================${NC}"
    echo ""
    
    # JSON構文チェック
    if validate_json; then
        echo ""
        echo -e "${GREEN}📋 現在の主要設定:${NC}"
        echo ""
        
        # 主要設定項目を表示
        if command -v jq >/dev/null 2>&1; then
            echo -e "${WHITE}組織名:${NC} $(jq -r '.General.OrganizationName // "未設定"' "${CONFIG_FILE}")"
            echo -e "${WHITE}環境:${NC} $(jq -r '.General.Environment // "未設定"' "${CONFIG_FILE}")"
            echo -e "${WHITE}テナントID:${NC} $(jq -r '.EntraID.TenantId // "未設定"' "${CONFIG_FILE}")"
            echo -e "${WHITE}言語:${NC} $(jq -r '.General.LanguageCode // "未設定"' "${CONFIG_FILE}")"
        else
            echo -e "${YELLOW}詳細確認にはjqコマンドが必要です${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}✅ 設定ファイル更新完了！${NC}"
    else
        echo ""
        echo -e "${RED}⚠️  JSON構文エラーがあります。再編集が必要です。${NC}"
        echo -e "${YELLOW}再編集しますか？ (y/N): ${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            edit_with_vim
        fi
    fi
}

# Vim編集実行
edit_with_vim() {
    echo -e "${BLUE}Vimエディターで設定ファイルを開きます...${NC}"
    sleep 1
    
    # Vimで編集実行
    vim "${CONFIG_FILE}"
    
    echo ""
    echo -e "${GREEN}Vimエディター終了${NC}"
    
    # 編集後の確認
    show_changes
}

# メイン実行
main() {
    cd "${PROJECT_ROOT}"
    
    # ファイル存在確認
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo -e "${RED}❌ 設定ファイルが見つかりません: ${CONFIG_FILE}${NC}"
        exit 1
    fi
    
    # Vim利用可能性確認
    if ! command -v vim >/dev/null 2>&1; then
        echo -e "${RED}❌ Vimエディターがインストールされていません${NC}"
        echo -e "${YELLOW}💡 インストール方法:${NC}"
        echo -e "    ${WHITE}sudo apt install vim${NC}     # Ubuntu/Debian"
        echo -e "    ${WHITE}sudo yum install vim${NC}     # CentOS/RHEL"
        echo -e "    ${WHITE}brew install vim${NC}         # macOS"
        exit 1
    fi
    
    # 操作ガイド表示
    show_vim_help
    
    # バックアップ作成
    create_backup
    
    # Vim編集開始
    edit_with_vim
}

# スクリプト実行
main "$@"