# 日本語化対象ファイル一覧
## ITSMディレクトリ構造最適化プロジェクト

### 1. 日本語ファイル名変換対象

#### 1.1 tmux関連ドキュメント
| 現在のファイル名 | 変換後ファイル名 | 優先度 | 参照影響 |
|---|---|---|---|
| `tmux_Docs/tmux仕様書.md` | `tmux_Docs/tmux-specification.md` | High | 中 |
| `tmux_Docs/操作手順書.md` | `tmux_Docs/operation-manual.md` | High | 中 |
| `操作手順書.md` | `operation-manual.md` | High | 高 |

#### 1.2 Visual Verification関連
| 現在のファイル名 | 変換後ファイル名 | 優先度 | 参照影響 |
|---|---|---|---|
| `scripts/visual-verification/tmux使用ガイド.md` | `scripts/visual-verification/tmux-usage-guide.md` | Medium | 低 |
| `scripts/visual-verification/クイックリファレンス.md` | `scripts/visual-verification/quick-reference.md` | Medium | 低 |
| `scripts/visual-verification/スクリプト内容詳細.md` | `scripts/visual-verification/script-details.md` | Medium | 低 |
| `scripts/visual-verification/スクリプト操作手順書.md` | `scripts/visual-verification/script-operation-manual.md` | Medium | 低 |

### 2. ドキュメント内日本語ファイル名参照

#### 2.1 Docs/ディレクトリ内日本語ファイル名
| 現在のファイル名 | 変換後ファイル名 | 優先度 | 参照影響 |
|---|---|---|---|
| `Docs/01-Project-Overview/01-プロジェクト憲章.md` | `Docs/01-Project-Overview/01-project-charter.md` | High | 中 |
| `Docs/01-Project-Overview/02-開発チーム役割分担.md` | `Docs/01-Project-Overview/02-development-team-roles.md` | High | 中 |
| `Docs/02-Requirements/02-機能要件適合性確認手順.md` | `Docs/02-Requirements/02-functional-requirements-verification.md` | High | 中 |
| `Docs/02-Requirements/03-機能適合性確認書.md` | `Docs/02-Requirements/03-functional-compliance-confirmation.md` | High | 中 |

#### 2.2 Architecture関連
| 現在のファイル名 | 変換後ファイル名 | 優先度 | 参照影響 |
|---|---|---|---|
| `Docs/03-Architecture/01-データベース設計提案.md` | `Docs/03-Architecture/01-database-design-proposal.md` | High | 高 |
| `Docs/03-Architecture/03-データベース運用仕様書.md` | `Docs/03-Architecture/03-database-operation-specification.md` | High | 高 |

#### 2.3 Development関連
| 現在のファイル名 | 変換後ファイル名 | 優先度 | 参照影響 |
|---|---|---|---|
| `Docs/04-Development/01-ファイル構成管理.md` | `Docs/04-Development/01-file-structure-management.md` | High | 中 |
| `Docs/04-Development/03-フロントエンド開発ガイド.md` | `Docs/04-Development/03-frontend-development-guide.md` | High | 中 |

#### 2.4 Testing関連
| 現在のファイル名 | 変換後ファイル名 | 優先度 | 参照影響 |
|---|---|---|---|
| `Docs/05-Testing/01-テスト結果報告書.md` | `Docs/05-Testing/01-test-results-report.md` | Medium | 低 |
| `Docs/05-Testing/05-ユーザビリティテスト手順書.md` | `Docs/05-Testing/05-usability-test-procedure.md` | Medium | 低 |

### 3. 変換実行スクリプト

#### 3.1 一括変換スクリプト
```bash
#!/bin/bash
# 日本語ファイル名一括変換スクリプト
# ファイル名: convert-japanese-filenames.sh

echo "日本語ファイル名変換開始..."

# 変換マッピング定義
declare -A file_mapping=(
    # tmux関連
    ["tmux_Docs/tmux仕様書.md"]="tmux_Docs/tmux-specification.md"
    ["tmux_Docs/操作手順書.md"]="tmux_Docs/operation-manual.md"
    ["操作手順書.md"]="operation-manual.md"
    
    # Visual Verification関連
    ["scripts/visual-verification/tmux使用ガイド.md"]="scripts/visual-verification/tmux-usage-guide.md"
    ["scripts/visual-verification/クイックリファレンス.md"]="scripts/visual-verification/quick-reference.md"
    ["scripts/visual-verification/スクリプト内容詳細.md"]="scripts/visual-verification/script-details.md"
    ["scripts/visual-verification/スクリプト操作手順書.md"]="scripts/visual-verification/script-operation-manual.md"
    
    # Project Overview関連
    ["Docs/01-Project-Overview/01-プロジェクト憲章.md"]="Docs/01-Project-Overview/01-project-charter.md"
    ["Docs/01-Project-Overview/02-開発チーム役割分担.md"]="Docs/01-Project-Overview/02-development-team-roles.md"
    
    # Requirements関連
    ["Docs/02-Requirements/02-機能要件適合性確認手順.md"]="Docs/02-Requirements/02-functional-requirements-verification.md"
    ["Docs/02-Requirements/03-機能適合性確認書.md"]="Docs/02-Requirements/03-functional-compliance-confirmation.md"
    
    # Architecture関連
    ["Docs/03-Architecture/01-データベース設計提案.md"]="Docs/03-Architecture/01-database-design-proposal.md"
    ["Docs/03-Architecture/03-データベース運用仕様書.md"]="Docs/03-Architecture/03-database-operation-specification.md"
    
    # Development関連
    ["Docs/04-Development/01-ファイル構成管理.md"]="Docs/04-Development/01-file-structure-management.md"
    ["Docs/04-Development/03-フロントエンド開発ガイド.md"]="Docs/04-Development/03-frontend-development-guide.md"
    
    # Testing関連
    ["Docs/05-Testing/01-テスト結果報告書.md"]="Docs/05-Testing/01-test-results-report.md"
    ["Docs/05-Testing/05-ユーザビリティテスト手順書.md"]="Docs/05-Testing/05-usability-test-procedure.md"
)

# 変換実行
conversion_count=0
for old_name in "${!file_mapping[@]}"; do
    new_name="${file_mapping[$old_name]}"
    
    if [ -f "$old_name" ]; then
        # バックアップ作成
        cp "$old_name" "$old_name.backup"
        
        # ファイル名変換
        mv "$old_name" "$new_name"
        
        echo "✓ 変換完了: $old_name → $new_name"
        ((conversion_count++))
    else
        echo "⚠ ファイル未発見: $old_name"
    fi
done

echo "変換完了: $conversion_count 個のファイルを変換しました"
```

#### 3.2 参照更新スクリプト
```bash
#!/bin/bash
# 日本語ファイル名参照更新スクリプト
# ファイル名: update-japanese-references.sh

echo "日本語ファイル名参照更新開始..."

# 参照更新マッピング
declare -A reference_mapping=(
    ["tmux仕様書.md"]="tmux-specification.md"
    ["操作手順書.md"]="operation-manual.md"
    ["tmux使用ガイド.md"]="tmux-usage-guide.md"
    ["クイックリファレンス.md"]="quick-reference.md"
    ["スクリプト内容詳細.md"]="script-details.md"
    ["スクリプト操作手順書.md"]="script-operation-manual.md"
    ["プロジェクト憲章.md"]="project-charter.md"
    ["開発チーム役割分担.md"]="development-team-roles.md"
    ["機能要件適合性確認手順.md"]="functional-requirements-verification.md"
    ["機能適合性確認書.md"]="functional-compliance-confirmation.md"
    ["データベース設計提案.md"]="database-design-proposal.md"
    ["データベース運用仕様書.md"]="database-operation-specification.md"
    ["ファイル構成管理.md"]="file-structure-management.md"
    ["フロントエンド開発ガイド.md"]="frontend-development-guide.md"
    ["テスト結果報告書.md"]="test-results-report.md"
    ["ユーザビリティテスト手順書.md"]="usability-test-procedure.md"
)

# 全Markdownファイルの参照を更新
reference_count=0
for old_ref in "${!reference_mapping[@]}"; do
    new_ref="${reference_mapping[$old_ref]}"
    
    # Markdownファイル内の参照を更新
    find . -name "*.md" -exec sed -i "s|$old_ref|$new_ref|g" {} \;
    
    echo "✓ 参照更新完了: $old_ref → $new_ref"
    ((reference_count++))
done

# README.mdの特別更新
if [ -f "README.md" ]; then
    sed -i 's|操作手順書.md|operation-manual.md|g' README.md
    echo "✓ README.md 更新完了"
fi

echo "参照更新完了: $reference_count 個の参照を更新しました"
```

### 4. 変換前後影響調査

#### 4.1 参照関係調査コマンド
```bash
# 日本語ファイル名参照調査
#!/bin/bash
echo "日本語ファイル名参照調査開始..."

# 調査対象ファイル名リスト
japanese_files=(
    "tmux仕様書.md"
    "操作手順書.md"
    "tmux使用ガイド.md"
    "クイックリファレンス.md"
    "スクリプト内容詳細.md"
    "スクリプト操作手順書.md"
    "プロジェクト憲章.md"
    "開発チーム役割分担.md"
    "機能要件適合性確認手順.md"
    "機能適合性確認書.md"
    "データベース設計提案.md"
    "データベース運用仕様書.md"
    "ファイル構成管理.md"
    "フロントエンド開発ガイド.md"
    "テスト結果報告書.md"
    "ユーザビリティテスト手順書.md"
)

# 各ファイルの参照調査
for file in "${japanese_files[@]}"; do
    echo "=== $file の参照調査 ==="
    grep -r "$file" . --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null
    echo ""
done > japanese-references-analysis.txt

echo "参照調査完了: japanese-references-analysis.txt に結果を出力"
```

### 5. 変換実行チェックリスト

#### 5.1 変換前チェック
- [ ] 全対象ファイルの存在確認
- [ ] 参照関係調査完了
- [ ] バックアップ作成準備
- [ ] 変換スクリプト準備完了

#### 5.2 変換実行チェック
- [ ] High優先度ファイル変換完了
- [ ] Medium優先度ファイル変換完了
- [ ] 参照更新実行完了
- [ ] 変換結果確認完了

#### 5.3 変換後チェック
- [ ] 全変換ファイル存在確認
- [ ] 参照整合性確認
- [ ] 機能テスト実行
- [ ] ドキュメント生成確認

### 6. 完了基準

#### 6.1 技術的完了基準
- 全日本語ファイル名変換完了
- 参照整合性100%維持
- 機能テスト100%合格
- ドキュメント生成エラー0件

#### 6.2 運用完了基準
- 開発者向け変更通知完了
- 運用手順書更新完了
- 緊急時対応手順確認完了

### 7. 緊急時対応

#### 7.1 ロールバック手順
```bash
# 日本語ファイル名ロールバック
#!/bin/bash
echo "日本語ファイル名ロールバック開始..."

# バックアップファイルから復元
find . -name "*.backup" -exec bash -c 'mv "$1" "${1%.backup}"' _ {} \;

echo "ロールバック完了"
```

#### 7.2 問題発生時対応
1. 即座にロールバック実行
2. 問題原因調査
3. 修正版スクリプト作成
4. 再実行判断