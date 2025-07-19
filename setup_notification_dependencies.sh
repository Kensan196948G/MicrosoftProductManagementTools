#!/bin/bash

# Microsoft 365 Tools - 通知システム依存関係セットアップ
# Microsoft Teams + Gmail 通知に必要なパッケージをインストール

set -euo pipefail

# 色付きログ関数
print_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

print_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

print_warning() {
    echo -e "\e[33m[WARNING]\e[0m $1"
}

print_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# OS検出
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/redhat-release ]; then
        OS="Red Hat Enterprise Linux"
        VER=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+')
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    print_info "検出されたOS: $OS $VER"
}

# パッケージインストール関数
install_packages() {
    print_info "通知システム用パッケージのインストールを開始します..."
    
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            print_info "Ubuntu/Debian系OSを検出しました"
            
            # パッケージリスト更新
            print_info "パッケージリストを更新中..."
            sudo apt-get update -qq
            
            # メール送信パッケージインストール
            print_info "sendemail（推奨メール送信ツール）をインストール中..."
            sudo apt-get install -y sendemail libnet-ssleay-perl libio-socket-ssl-perl
            
            print_info "msmtp（代替メール送信ツール）をインストール中..."
            sudo apt-get install -y msmtp msmtp-mta
            
            # curl（Teams通知用）
            print_info "curl（Teams Webhook用）をインストール中..."
            sudo apt-get install -y curl
            
            # その他のユーティリティ
            print_info "その他のユーティリティをインストール中..."
            sudo apt-get install -y jq bc
            
            print_success "Ubuntu/Debian用パッケージのインストールが完了しました"
            ;;
            
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            print_info "RHEL系OSを検出しました"
            
            # EPEL有効化
            print_info "EPELリポジトリを有効化中..."
            sudo dnf install -y epel-release || sudo yum install -y epel-release
            
            # パッケージインストール
            print_info "sendemailをインストール中..."
            sudo dnf install -y sendemail || sudo yum install -y sendemail
            
            print_info "msmtpをインストール中..."
            sudo dnf install -y msmtp || sudo yum install -y msmtp
            
            print_info "curlをインストール中..."
            sudo dnf install -y curl jq bc || sudo yum install -y curl jq bc
            
            print_success "RHEL系用パッケージのインストールが完了しました"
            ;;
            
        *"SUSE"*|*"openSUSE"*)
            print_info "SUSE系OSを検出しました"
            
            print_info "zypper経由でパッケージをインストール中..."
            sudo zypper install -y sendemail msmtp curl jq bc
            
            print_success "SUSE系用パッケージのインストールが完了しました"
            ;;
            
        *"Arch"*)
            print_info "Arch Linux系OSを検出しました"
            
            print_info "pacman経由でパッケージをインストール中..."
            sudo pacman -S --noconfirm msmtp curl jq bc
            
            print_warning "sendemailはAURからインストールする必要があります"
            print_info "手動インストール: yay -S sendemail"
            
            print_success "Arch Linux用パッケージのインストールが完了しました"
            ;;
            
        "Darwin")
            print_info "macOSを検出しました"
            
            if command -v brew >/dev/null 2>&1; then
                print_info "Homebrew経由でパッケージをインストール中..."
                brew install msmtp curl jq
                
                print_warning "sendemailはHomebrewでは利用できません。msmtpを使用します"
                print_success "macOS用パッケージのインストールが完了しました"
            else
                print_error "Homebrewがインストールされていません"
                print_info "Homebrewをインストールしてください: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                return 1
            fi
            ;;
            
        *)
            print_warning "未知のOS: $OS"
            print_info "手動でパッケージをインストールしてください:"
            print_info "  - sendemail または msmtp（メール送信用）"
            print_info "  - curl（Teams Webhook用）"
            print_info "  - jq（JSON処理用）"
            print_info "  - bc（計算用）"
            ;;
    esac
}

# インストール確認
verify_installation() {
    print_info "インストールされたパッケージの確認を行います..."
    
    # sendemail確認
    if command -v sendemail >/dev/null 2>&1; then
        print_success "sendemail: インストール済み ($(sendemail -version 2>&1 | head -1))"
    else
        print_warning "sendemail: 未インストール"
    fi
    
    # msmtp確認
    if command -v msmtp >/dev/null 2>&1; then
        print_success "msmtp: インストール済み ($(msmtp --version | head -1))"
    else
        print_warning "msmtp: 未インストール"
    fi
    
    # curl確認
    if command -v curl >/dev/null 2>&1; then
        print_success "curl: インストール済み ($(curl --version | head -1))"
    else
        print_error "curl: 未インストール（Teams通知に必要）"
    fi
    
    # jq確認
    if command -v jq >/dev/null 2>&1; then
        print_success "jq: インストール済み ($(jq --version))"
    else
        print_warning "jq: 未インストール（JSON処理用）"
    fi
    
    # bc確認
    if command -v bc >/dev/null 2>&1; then
        print_success "bc: インストール済み"
    else
        print_warning "bc: 未インストール（計算用）"
    fi
    
    # Python確認
    if command -v python3 >/dev/null 2>&1; then
        print_success "python3: インストール済み ($(python3 --version))"
    else
        print_error "python3: 未インストール（JSON処理に必要）"
    fi
}

# Gmail設定ガイド表示
show_gmail_setup_guide() {
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "📧 Gmail アプリパスワード設定ガイド"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Googleアカウント設定 (https://myaccount.google.com/) にアクセス"
    echo "2. 左メニューから「セキュリティ」をクリック"
    echo "3. 「Googleへのログイン」セクションで「2段階認証プロセス」を有効化"
    echo "4. 「アプリパスワード」をクリック"
    echo "5. 「アプリを選択」→「メール」を選択"
    echo "6. 「デバイスを選択」→「その他（カスタム名）」を選択"
    echo "7. 名前に「Microsoft 365 Tools」と入力"
    echo "8. 「生成」をクリック"
    echo "9. 表示された16桁のパスワードをメモ"
    echo "10. Config/notification_config.json の app_password に設定"
    echo ""
    print_warning "⚠️ 通常のGoogleパスワードではなく、専用のアプリパスワードを使用してください"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Teams設定ガイド表示
show_teams_setup_guide() {
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "📱 Microsoft Teams Webhook設定ガイド"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Microsoft Teamsで通知を受信したいチャンネルを開く"
    echo "2. チャンネル名の横の「...」→「コネクタ」をクリック"
    echo "3. 「Incoming Webhook」を検索して「構成」をクリック"
    echo "4. 名前に「Microsoft 365 Tools」を設定"
    echo "5. 必要に応じてアイコンをアップロード"
    echo "6. 「作成」をクリック"
    echo "7. 生成されたWebhook URLをコピー"
    echo "8. Config/notification_config.json の webhook に設定"
    echo ""
    echo "例: https://yourcompany.webhook.office.com/webhookb2/..."
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# メイン実行
main() {
    echo ""
    print_info "🚀 Microsoft 365 Tools 通知システム セットアップ"
    echo ""
    
    # OS検出
    detect_os
    echo ""
    
    # パッケージインストール
    case "${1:-install}" in
        "install")
            install_packages
            echo ""
            verify_installation
            echo ""
            show_gmail_setup_guide
            echo ""
            show_teams_setup_guide
            echo ""
            print_success "🎉 セットアップが完了しました！"
            print_info "次の手順："
            print_info "1. Config/notification_config.json を編集"
            print_info "2. ./notification_system_enhanced.sh test でテスト実行"
            print_info "3. ./notification_system_enhanced.sh validate で設定確認"
            ;;
        "verify")
            verify_installation
            ;;
        "gmail-guide")
            show_gmail_setup_guide
            ;;
        "teams-guide")
            show_teams_setup_guide
            ;;
        "help")
            echo "使用方法:"
            echo "  $0 [install|verify|gmail-guide|teams-guide|help]"
            echo ""
            echo "コマンド:"
            echo "  install      - 必要なパッケージをインストール（デフォルト）"
            echo "  verify       - インストール状況を確認"
            echo "  gmail-guide  - Gmail設定ガイドを表示"
            echo "  teams-guide  - Teams設定ガイドを表示"
            echo "  help         - このヘルプを表示"
            ;;
        *)
            print_error "未知のコマンド: $1"
            print_info "使用方法については '$0 help' を実行してください"
            exit 1
            ;;
    esac
}

# スクリプト実行
main "$@"