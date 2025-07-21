#!/bin/bash

# ITSM UI Panel Script
# UI/UX確認とフィードバック統合システム

# 設定
FRONTEND_URL="http://localhost:3000"
SCREENSHOT_DIR="./screenshots"
REPORT_DIR="./ui-reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 色定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ディレクトリ作成
mkdir -p "$SCREENSHOT_DIR" "$REPORT_DIR"

# 関数: スクリーンショット撮影（Puppeteer使用）
capture_screenshot() {
    local page_name=$1
    local url=$2
    local output_file="${SCREENSHOT_DIR}/${page_name}_${TIMESTAMP}.png"
    
    # Node.jsスクリプトを動的に生成
    cat > /tmp/capture_screenshot.js << 'EOF'
const puppeteer = require('puppeteer');

(async () => {
    const url = process.argv[2];
    const output = process.argv[3];
    
    try {
        const browser = await puppeteer.launch({
            headless: 'new',
            args: ['--no-sandbox', '--disable-setuid-sandbox']
        });
        const page = await browser.newPage();
        
        // デスクトップサイズ
        await page.setViewport({ width: 1920, height: 1080 });
        
        await page.goto(url, { waitUntil: 'networkidle2' });
        await page.screenshot({ path: output, fullPage: true });
        
        await browser.close();
        console.log('Screenshot saved:', output);
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
})();
EOF
    
    # Puppeteerがインストールされているか確認
    if ! npm list puppeteer &> /dev/null; then
        echo -e "${YELLOW}Installing Puppeteer...${NC}"
        npm install puppeteer
    fi
    
    # スクリーンショット撮影
    echo -e "${BLUE}Capturing screenshot: ${page_name}${NC}"
    if node /tmp/capture_screenshot.js "$url" "$output_file"; then
        echo -e "${GREEN}✓ Screenshot saved: $output_file${NC}"
        return 0
    else
        echo -e "${RED}✗ Screenshot capture failed${NC}"
        return 1
    fi
}

# 関数: UI品質チェック
check_ui_quality() {
    local report_file="${REPORT_DIR}/ui_quality_${TIMESTAMP}.md"
    
    echo -e "${BLUE}=== UI Quality Check ===${NC}\n"
    
    # レポートヘッダー
    cat > "$report_file" << EOF
# UI/UX Quality Report
**Date**: $(date)
**System**: ITSM準拠IT運用システム

## 自動チェック項目

### 1. アクセシビリティ
EOF
    
    # axe-coreによるアクセシビリティチェック
    cat > /tmp/accessibility_check.js << 'EOF'
const puppeteer = require('puppeteer');
const { AxePuppeteer } = require('@axe-core/puppeteer');

(async () => {
    const url = process.argv[2];
    
    try {
        const browser = await puppeteer.launch({ headless: 'new' });
        const page = await browser.newPage();
        await page.goto(url);
        
        const results = await new AxePuppeteer(page).analyze();
        
        console.log('Accessibility Issues:');
        console.log('- Violations:', results.violations.length);
        console.log('- Passes:', results.passes.length);
        
        if (results.violations.length > 0) {
            console.log('\nTop Issues:');
            results.violations.slice(0, 5).forEach(v => {
                console.log(`- ${v.description} (${v.impact})`);
            });
        }
        
        await browser.close();
    } catch (error) {
        console.error('Error:', error);
    }
})();
EOF
    
    # 必要なパッケージのインストール確認
    if ! npm list @axe-core/puppeteer &> /dev/null; then
        echo -e "${YELLOW}Installing accessibility tools...${NC}"
        npm install @axe-core/puppeteer
    fi
    
    # アクセシビリティチェック実行
    echo "Running accessibility check..."
    node /tmp/accessibility_check.js "$FRONTEND_URL" | tee -a "$report_file"
    
    echo -e "\n${GREEN}✓ Quality report saved: $report_file${NC}"
}

# 関数: UI課題フィードバック
create_feedback() {
    local issue_type=$1
    local description=$2
    local severity=$3
    local screenshot=$4
    
    local feedback_file="${REPORT_DIR}/feedback_${TIMESTAMP}.json"
    
    cat > "$feedback_file" << EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "type": "$issue_type",
    "description": "$description",
    "severity": "$severity",
    "screenshot": "$screenshot",
    "url": "$FRONTEND_URL",
    "reporter": "UI Panel System",
    "phase": "Phase 3 AI Integration"
}
EOF
    
    echo -e "${GREEN}✓ Feedback created: $feedback_file${NC}"
    
    # 開発チームに通知
    if [ -f "./send-message.sh" ]; then
        ./send-message.sh dev1 "【UI/UX課題検出】$issue_type - $description (重要度: $severity)"
    fi
}

# 関数: ビジュアルリグレッションテスト
visual_regression_test() {
    echo -e "${BLUE}=== Visual Regression Test ===${NC}\n"
    
    # ベースライン画像と比較
    local baseline_dir="./ui-baseline"
    mkdir -p "$baseline_dir"
    
    # 主要ページのスクリーンショット
    local pages=(
        "dashboard:/"
        "incidents:/incidents"
        "settings:/settings"
        "reports:/reports"
    )
    
    for page_info in "${pages[@]}"; do
        IFS=':' read -r page_name page_path <<< "$page_info"
        local url="${FRONTEND_URL}${page_path}"
        
        capture_screenshot "$page_name" "$url"
        
        # ベースラインとの比較（ImageMagick使用）
        if command -v compare &> /dev/null; then
            local baseline="${baseline_dir}/${page_name}_baseline.png"
            local current="${SCREENSHOT_DIR}/${page_name}_${TIMESTAMP}.png"
            local diff="${SCREENSHOT_DIR}/${page_name}_diff_${TIMESTAMP}.png"
            
            if [ -f "$baseline" ]; then
                echo "Comparing with baseline..."
                if compare -metric AE "$baseline" "$current" "$diff" 2>&1 | grep -q "^0$"; then
                    echo -e "${GREEN}✓ No visual changes detected${NC}"
                else
                    echo -e "${YELLOW}⚠ Visual changes detected${NC}"
                    create_feedback "visual_change" "Visual regression detected on $page_name" "medium" "$diff"
                fi
            else
                echo "Creating baseline..."
                cp "$current" "$baseline"
            fi
        fi
    done
}

# 関数: パフォーマンス監視
monitor_performance() {
    echo -e "${BLUE}=== Performance Monitoring ===${NC}\n"
    
    cat > /tmp/performance_check.js << 'EOF'
const puppeteer = require('puppeteer');

(async () => {
    const url = process.argv[2];
    
    try {
        const browser = await puppeteer.launch({ headless: 'new' });
        const page = await browser.newPage();
        
        // パフォーマンス計測開始
        await page.goto(url, { waitUntil: 'networkidle2' });
        
        const metrics = await page.metrics();
        const performanceTiming = JSON.parse(
            await page.evaluate(() => JSON.stringify(window.performance.timing))
        );
        
        // Web Vitals
        const navigationStart = performanceTiming.navigationStart;
        const FCP = performanceTiming.responseStart - navigationStart;
        const TTI = performanceTiming.domInteractive - navigationStart;
        const fullyLoaded = performanceTiming.loadEventEnd - navigationStart;
        
        console.log('Performance Metrics:');
        console.log(`- First Contentful Paint: ${FCP}ms`);
        console.log(`- Time to Interactive: ${TTI}ms`);
        console.log(`- Fully Loaded: ${fullyLoaded}ms`);
        console.log(`- JS Heap Size: ${(metrics.JSHeapUsedSize / 1048576).toFixed(2)}MB`);
        
        await browser.close();
    } catch (error) {
        console.error('Error:', error);
    }
})();
EOF
    
    node /tmp/performance_check.js "$FRONTEND_URL"
}

# 関数: 統合UIパネル
ui_panel() {
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║      ITSM UI/UX Control Panel          ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo "1. Capture Screenshots"
        echo "2. Run Accessibility Check"
        echo "3. Visual Regression Test"
        echo "4. Performance Monitoring"
        echo "5. Create UI Feedback"
        echo "6. Generate Full Report"
        echo "7. Open Frontend in Browser"
        echo "0. Exit"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                capture_screenshot "manual" "$FRONTEND_URL"
                read -p "Press Enter to continue..."
                ;;
            2)
                check_ui_quality
                read -p "Press Enter to continue..."
                ;;
            3)
                visual_regression_test
                read -p "Press Enter to continue..."
                ;;
            4)
                monitor_performance
                read -p "Press Enter to continue..."
                ;;
            5)
                read -p "Issue type: " issue_type
                read -p "Description: " description
                read -p "Severity (low/medium/high): " severity
                create_feedback "$issue_type" "$description" "$severity" ""
                read -p "Press Enter to continue..."
                ;;
            6)
                echo "Generating full UI/UX report..."
                check_ui_quality
                visual_regression_test
                monitor_performance
                echo -e "\n${GREEN}✓ Full report generated${NC}"
                read -p "Press Enter to continue..."
                ;;
            7)
                if [ -f "./tmux-url-helper.sh" ]; then
                    ./tmux-url-helper.sh open frontend
                else
                    xdg-open "$FRONTEND_URL" 2>/dev/null || open "$FRONTEND_URL" 2>/dev/null
                fi
                ;;
            0)
                echo "Exiting UI Panel..."
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# メイン処理
main() {
    case "${1:-}" in
        "screenshot"|"s")
            capture_screenshot "${2:-dashboard}" "${3:-$FRONTEND_URL}"
            ;;
        "check"|"c")
            check_ui_quality
            ;;
        "regression"|"r")
            visual_regression_test
            ;;
        "performance"|"p")
            monitor_performance
            ;;
        "feedback"|"f")
            create_feedback "${2:-general}" "${3:-UI issue}" "${4:-medium}" ""
            ;;
        "panel"|"")
            ui_panel
            ;;
        "help"|"h")
            echo "ITSM UI Panel - Usage:"
            echo "  $0 [panel]      - Open interactive UI panel"
            echo "  $0 screenshot   - Capture screenshot"
            echo "  $0 check        - Run UI quality check"
            echo "  $0 regression   - Visual regression test"
            echo "  $0 performance  - Performance monitoring"
            echo "  $0 feedback     - Create UI feedback"
            echo ""
            echo "Shortcuts:"
            echo "  s - screenshot"
            echo "  c - check"
            echo "  r - regression"
            echo "  p - performance"
            echo "  f - feedback"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            ;;
    esac
}

# スクリプト実行
main "$@"