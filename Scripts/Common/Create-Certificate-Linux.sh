#!/bin/bash

# ================================================================================
# Create-Certificate-Linux.sh
# Linux環境用Exchange Online PowerShell証明書作成スクリプト
# ================================================================================

set -e

# パラメータ設定
CERT_NAME="MiraiConstEXO"
ORG_NAME="みらい建設工業株式会社"
VALIDITY_DAYS=1095  # 3年
OUTPUT_DIR="/mnt/e/MicrosoftProductManagementTools/Certificates"
COUNTRY="JP"
STATE="Tokyo"
CITY="Tokyo"

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${GREEN}🔐 Exchange Online PowerShell用証明書を作成します${NC}"
echo -e "${YELLOW}組織名: ${ORG_NAME}${NC}"
echo -e "${YELLOW}有効期間: 3年（${VALIDITY_DAYS}日）${NC}"
echo -e "${YELLOW}出力先: ${OUTPUT_DIR}${NC}"

# 出力ディレクトリ作成
if [[ ! -d "${OUTPUT_DIR}" ]]; then
    mkdir -p "${OUTPUT_DIR}"
    echo -e "${GREEN}📁 証明書保存ディレクトリを作成: ${OUTPUT_DIR}${NC}"
fi

# OpenSSL確認
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}❌ OpenSSLがインストールされていません${NC}"
    echo -e "${YELLOW}インストール: sudo apt-get install openssl${NC}"
    exit 1
fi

try() {
    echo -e "${BLUE}🔧 証明書作成を開始します...${NC}"
    
    # 秘密キー生成
    echo -e "${CYAN}1. RSA秘密キー生成中...${NC}"
    openssl genrsa -out "${OUTPUT_DIR}/${CERT_NAME}.key" 2048
    
    # 証明書署名要求（CSR）作成
    echo -e "${CYAN}2. 証明書署名要求作成中...${NC}"
    openssl req -new -key "${OUTPUT_DIR}/${CERT_NAME}.key" -out "${OUTPUT_DIR}/${CERT_NAME}.csr" -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG_NAME}/CN=${CERT_NAME}"
    
    # 自己署名証明書作成
    echo -e "${CYAN}3. 自己署名証明書作成中...${NC}"
    openssl x509 -req -in "${OUTPUT_DIR}/${CERT_NAME}.csr" -signkey "${OUTPUT_DIR}/${CERT_NAME}.key" -out "${OUTPUT_DIR}/${CERT_NAME}.crt" -days ${VALIDITY_DAYS}
    
    # PKCS#12形式（PFX）作成
    echo -e "${CYAN}4. PKCS#12（PFX）ファイル作成中...${NC}"
    echo -e "${YELLOW}PFXファイル用パスワードを入力してください:${NC}"
    read -s PFX_PASSWORD
    echo -e "${YELLOW}パスワードを再入力してください:${NC}"
    read -s PFX_PASSWORD_CONFIRM
    
    if [[ "${PFX_PASSWORD}" != "${PFX_PASSWORD_CONFIRM}" ]]; then
        echo -e "${RED}❌ パスワードが一致しません${NC}"
        exit 1
    fi
    
    openssl pkcs12 -export -out "${OUTPUT_DIR}/${CERT_NAME}.pfx" -inkey "${OUTPUT_DIR}/${CERT_NAME}.key" -in "${OUTPUT_DIR}/${CERT_NAME}.crt" -passout pass:"${PFX_PASSWORD}"
    
    # DER形式（CER）作成
    echo -e "${CYAN}5. DER形式（CER）ファイル作成中...${NC}"
    openssl x509 -outform DER -in "${OUTPUT_DIR}/${CERT_NAME}.crt" -out "${OUTPUT_DIR}/${CERT_NAME}.cer"
    
    # 証明書情報取得
    echo -e "${CYAN}6. 証明書情報取得中...${NC}"
    THUMBPRINT=$(openssl x509 -in "${OUTPUT_DIR}/${CERT_NAME}.crt" -fingerprint -sha1 -noout | cut -d= -f2 | tr -d ':')
    SERIAL=$(openssl x509 -in "${OUTPUT_DIR}/${CERT_NAME}.crt" -serial -noout | cut -d= -f2)
    NOT_AFTER=$(openssl x509 -in "${OUTPUT_DIR}/${CERT_NAME}.crt" -enddate -noout | cut -d= -f2)
    
    # ファイル権限設定
    chmod 600 "${OUTPUT_DIR}/${CERT_NAME}.key"
    chmod 600 "${OUTPUT_DIR}/${CERT_NAME}.pfx"
    chmod 644 "${OUTPUT_DIR}/${CERT_NAME}.crt"
    chmod 644 "${OUTPUT_DIR}/${CERT_NAME}.cer"
    
    echo -e "${GREEN}✅ 証明書作成完了${NC}"
    echo ""
    echo -e "${CYAN}📋 証明書情報:${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}組織名:${NC} ${ORG_NAME}"
    echo -e "${WHITE}証明書名:${NC} ${CERT_NAME}"
    echo -e "${WHITE}拇印（SHA1）:${NC} ${THUMBPRINT}"
    echo -e "${WHITE}シリアル番号:${NC} ${SERIAL}"
    echo -e "${WHITE}有効期限:${NC} ${NOT_AFTER}"
    echo ""
    echo -e "${CYAN}📁 作成されたファイル:${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}秘密キー:${NC} ${OUTPUT_DIR}/${CERT_NAME}.key"
    echo -e "${WHITE}証明書（CRT）:${NC} ${OUTPUT_DIR}/${CERT_NAME}.crt"
    echo -e "${WHITE}証明書（CER）:${NC} ${OUTPUT_DIR}/${CERT_NAME}.cer"
    echo -e "${WHITE}PKCS#12（PFX）:${NC} ${OUTPUT_DIR}/${CERT_NAME}.pfx"
    echo -e "${WHITE}CSR:${NC} ${OUTPUT_DIR}/${CERT_NAME}.csr"
    
    echo ""
    echo -e "${YELLOW}⚙️ appsettings.json用設定:${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}\"CertificateThumbprint\": \"${THUMBPRINT}\"${NC}"
    
    echo ""
    echo -e "${YELLOW}📝 Azure ADでの設定手順:${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}1. Azure Portal → Azure Active Directory → アプリの登録${NC}"
    echo -e "${WHITE}2. 既存アプリ 22e5d6e4-805f-4516-af09-ff09c7c224c4 を選択${NC}"
    echo -e "${WHITE}3. [証明書とシークレット] → [証明書] → [証明書のアップロード]${NC}"
    echo -e "${WHITE}4. ファイル選択: ${OUTPUT_DIR}/${CERT_NAME}.cer${NC}"
    echo -e "${WHITE}5. 古い証明書（拇印: 94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6）を削除${NC}"
    
    echo ""
    echo -e "${YELLOW}🚀 次のコマンド:${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}# 設定ファイル更新${NC}"
    echo -e "${WHITE}pwsh -File Scripts/Common/Update-Certificate-Only.ps1 -NewCertificateThumbprint \"${THUMBPRINT}\"${NC}"
    echo ""
    echo -e "${CYAN}# 接続テスト${NC}"
    echo -e "${WHITE}./auto-test.sh --comprehensive${NC}"
    echo ""
    echo -e "${CYAN}# システム開始${NC}"
    echo -e "${WHITE}./start-all.sh${NC}"
    
    # 結果保存
    cat > "${OUTPUT_DIR}/certificate-info.txt" << EOF
証明書情報 - $(date '+%Y年%m月%d日 %H:%M:%S')
組織名: ${ORG_NAME}
証明書名: ${CERT_NAME}
拇印（SHA1）: ${THUMBPRINT}
シリアル番号: ${SERIAL}
有効期限: ${NOT_AFTER}
作成日時: $(date)

ファイル:
- ${OUTPUT_DIR}/${CERT_NAME}.key (秘密キー)
- ${OUTPUT_DIR}/${CERT_NAME}.crt (証明書)
- ${OUTPUT_DIR}/${CERT_NAME}.cer (Azure AD用)
- ${OUTPUT_DIR}/${CERT_NAME}.pfx (PowerShell用)

設定:
"CertificateThumbprint": "${THUMBPRINT}"
EOF

    echo ""
    echo -e "${GREEN}🎉 証明書作成プロセス完了！${NC}"
    echo -e "${YELLOW}証明書情報は ${OUTPUT_DIR}/certificate-info.txt に保存されました${NC}"
    
    return 0
}

# エラーハンドリング
if ! try; then
    echo -e "${RED}❌ 証明書作成エラーが発生しました${NC}"
    exit 1
fi