# ================================================================================
# サンプルデータ生成スクリプト
# Microsoft 365統合管理ツール用テストデータ
# ================================================================================

# サンプルデータ生成関数
function Generate-SampleReportData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportType,
        
        [Parameter(Mandatory = $false)]
        [int]$RecordCount = 100
    )
    
    # 共通データ
    $departments = @("営業部", "開発部", "総務部", "人事部", "経理部", "マーケティング部", "システム部", "カスタマーサポート部")
    $userNames = @(
        "田中太郎", "鈴木花子", "佐藤次郎", "高橋美咲", "渡辺健一", 
        "伊藤光子", "山田和也", "中村真理", "小林秀樹", "加藤明美",
        "吉田昌子", "山本健二", "松本由美", "井上雅人", "木村優子"
    )
    $offices = @("東京本社", "大阪支社", "名古屋支社", "福岡支社", "札幌支社", "仙台支社")
    $licenses = @("Microsoft 365 E3", "Microsoft 365 E5", "Office 365 E1", "Business Premium", "Business Standard")
    
    $data = @()
    
    switch ($ReportType) {
        "UserActivity" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $data += [PSCustomObject]@{
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    メールアドレス = "user$i@contoso.com"
                    最終ログイン = (Get-Date).AddDays(-(Get-Random -Minimum 0 -Maximum 30)).ToString("yyyy-MM-dd HH:mm:ss")
                    ログイン回数 = Get-Random -Minimum 10 -Maximum 200
                    メール送信数 = Get-Random -Minimum 5 -Maximum 150
                    メール受信数 = Get-Random -Minimum 20 -Maximum 500
                    OneDrive使用量GB = [math]::Round((Get-Random -Minimum 0.1 -Maximum 50.0), 2)
                    アクティブステータス = @("アクティブ", "アクティブ", "アクティブ", "非アクティブ")[(Get-Random -Maximum 4)]
                    MFA状態 = @("有効", "有効", "有効", "無効")[(Get-Random -Maximum 4)]
                    リスクレベル = @("低", "低", "中", "高")[(Get-Random -Maximum 4)]
                }
            }
        }
        
        "SecurityReport" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $data += [PSCustomObject]@{
                    発生日時 = (Get-Date).AddDays(-(Get-Random -Minimum 0 -Maximum 90)).ToString("yyyy-MM-dd HH:mm:ss")
                    イベントタイプ = @("不審なログイン", "権限昇格", "外部共有", "データダウンロード", "設定変更")[(Get-Random -Maximum 5)]
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    IPアドレス = "$(Get-Random -Minimum 1 -Maximum 255).$(Get-Random -Minimum 1 -Maximum 255).$(Get-Random -Minimum 1 -Maximum 255).$(Get-Random -Minimum 1 -Maximum 255)"
                    場所 = @("日本", "日本", "日本", "中国", "ロシア", "アメリカ", "不明")[(Get-Random -Maximum 7)]
                    デバイス = @("Windows 10", "Windows 11", "macOS", "iOS", "Android", "不明")[(Get-Random -Maximum 6)]
                    リスクレベル = @("低", "中", "高", "重大")[(Get-Random -Maximum 4)]
                    対応状況 = @("対応済み", "調査中", "未対応", "自動ブロック")[(Get-Random -Maximum 4)]
                    詳細 = @("通常と異なる場所からのアクセス", "短時間での複数回ログイン試行", "大量データのダウンロード", "管理者権限の使用")[(Get-Random -Maximum 4)]
                }
            }
        }
        
        "LicenseUsage" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $licenseType = $licenses[(Get-Random -Maximum $licenses.Count)]
                $assigned = Get-Random -Minimum 50 -Maximum 200
                $total = $assigned + (Get-Random -Minimum 10 -Maximum 50)
                
                $data += [PSCustomObject]@{
                    ライセンス種別 = $licenseType
                    総ライセンス数 = $total
                    割当済み = $assigned
                    利用可能 = $total - $assigned
                    利用率 = [math]::Round(($assigned / $total * 100), 1)
                    月額コスト = switch ($licenseType) {
                        "Microsoft 365 E5" { 6650 }
                        "Microsoft 365 E3" { 4500 }
                        "Office 365 E1" { 1400 }
                        "Business Premium" { 3300 }
                        default { 2200 }
                    }
                    最終更新日 = (Get-Date).AddDays(-(Get-Random -Minimum 0 -Maximum 7)).ToString("yyyy-MM-dd")
                    次回更新日 = (Get-Date).AddMonths((Get-Random -Minimum 1 -Maximum 12)).ToString("yyyy-MM-dd")
                    自動更新 = @("有効", "無効")[(Get-Random -Maximum 2)]
                    コスト最適化可能 = if ((Get-Random -Maximum 100) -lt 30) { "可能" } else { "不要" }
                }
            }
        }
        
        "MailboxUsage" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $sizeGB = [math]::Round((Get-Random -Minimum 0.5 -Maximum 50.0), 2)
                $quotaGB = 50
                
                $data += [PSCustomObject]@{
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    メールアドレス = "user$i@contoso.com"
                    メールボックスサイズGB = $sizeGB
                    クォータGB = $quotaGB
                    使用率 = [math]::Round(($sizeGB / $quotaGB * 100), 1)
                    アイテム数 = Get-Random -Minimum 1000 -Maximum 50000
                    送信メール数_日 = Get-Random -Minimum 5 -Maximum 100
                    受信メール数_日 = Get-Random -Minimum 20 -Maximum 200
                    スパムメール数_日 = Get-Random -Minimum 0 -Maximum 50
                    アーカイブ有効 = @("有効", "無効")[(Get-Random -Maximum 2)]
                    訴訟ホールド = @("有効", "無効", "無効", "無効")[(Get-Random -Maximum 4)]
                    最終アクセス = (Get-Date).AddDays(-(Get-Random -Minimum 0 -Maximum 7)).ToString("yyyy-MM-dd HH:mm:ss")
                }
            }
        }
        
        "TeamsActivity" {
            for ($i = 1; $i -le $RecordCount; $i++) {
                $data += [PSCustomObject]@{
                    ユーザー名 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    チーム参加数 = Get-Random -Minimum 1 -Maximum 20
                    プライベートチャネル数 = Get-Random -Minimum 0 -Maximum 10
                    チャットメッセージ数_週 = Get-Random -Minimum 10 -Maximum 500
                    会議参加数_週 = Get-Random -Minimum 0 -Maximum 30
                    会議主催数_週 = Get-Random -Minimum 0 -Maximum 10
                    通話時間_分_週 = Get-Random -Minimum 0 -Maximum 600
                    画面共有回数_週 = Get-Random -Minimum 0 -Maximum 20
                    ファイル共有数_週 = Get-Random -Minimum 0 -Maximum 50
                    最終アクティビティ = (Get-Date).AddDays(-(Get-Random -Minimum 0 -Maximum 7)).ToString("yyyy-MM-dd HH:mm:ss")
                    デバイス = @("Desktop", "Mobile", "Web", "Desktop/Mobile")[(Get-Random -Maximum 4)]
                    アクティビティレベル = @("高", "中", "低", "非アクティブ")[(Get-Random -Maximum 4)]
                }
            }
        }
        
        default {
            # 汎用データ
            for ($i = 1; $i -le $RecordCount; $i++) {
                $data += [PSCustomObject]@{
                    ID = "REC-$('{0:D6}' -f $i)"
                    名前 = $userNames[(Get-Random -Maximum $userNames.Count)]
                    部署 = $departments[(Get-Random -Maximum $departments.Count)]
                    値1 = Get-Random -Minimum 1 -Maximum 100
                    値2 = [math]::Round((Get-Random -Minimum 0.0 -Maximum 100.0), 2)
                    ステータス = @("正常", "警告", "エラー", "保留")[(Get-Random -Maximum 4)]
                    作成日 = (Get-Date).AddDays(-(Get-Random -Minimum 0 -Maximum 365)).ToString("yyyy-MM-dd")
                    更新日 = (Get-Date).AddDays(-(Get-Random -Minimum 0 -Maximum 30)).ToString("yyyy-MM-dd HH:mm:ss")
                }
            }
        }
    }
    
    return $data
}

# HTMLレポート生成関数
function Generate-SampleHTMLReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportType,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [int]$RecordCount = 100
    )
    
    # サンプルデータ生成
    $data = Generate-SampleReportData -ReportType $ReportType -RecordCount $RecordCount
    
    # テンプレート読み込み
    $templatePath = Join-Path $PSScriptRoot "..\HTML\report-template.html"
    $template = Get-Content $templatePath -Raw
    
    # メタデータ
    $reportName = switch ($ReportType) {
        "UserActivity" { "ユーザーアクティビティレポート" }
        "SecurityReport" { "セキュリティレポート" }
        "LicenseUsage" { "ライセンス使用状況レポート" }
        "MailboxUsage" { "メールボックス使用状況レポート" }
        "TeamsActivity" { "Teams アクティビティレポート" }
        default { "汎用レポート" }
    }
    
    # ヘッダー生成
    $headers = ($data[0].PSObject.Properties.Name | ForEach-Object {
        "<th>$_</th>"
    }) -join "`n"
    
    # データ行生成
    $rows = $data | ForEach-Object {
        $row = $_
        $cells = $row.PSObject.Properties.Value | ForEach-Object {
            $value = $_
            # ステータスやレベルに応じてバッジ適用
            $cellContent = switch -Regex ($value) {
                "^(正常|アクティブ|有効|低)$" { "<span class='badge badge-success'>$value</span>" }
                "^(警告|中)$" { "<span class='badge badge-warning'>$value</span>" }
                "^(エラー|非アクティブ|無効|高)$" { "<span class='badge badge-danger'>$value</span>" }
                "^(重大)$" { "<span class='badge badge-danger'>$value</span>" }
                default { $value }
            }
            "<td>$cellContent</td>"
        }
        "<tr>$($cells -join '')</tr>"
    }
    $tableData = $rows -join "`n"
    
    # JavaScriptパス
    $jsPath = "../../JavaScript/report-functions.js"
    
    # テンプレート置換
    $html = $template -replace "{{REPORT_NAME}}", $reportName
    $html = $html -replace "{{GENERATED_DATE}}", (Get-Date).ToString("yyyy年MM月dd日 HH:mm:ss")
    $html = $html -replace "{{TOTAL_RECORDS}}", $data.Count
    $html = $html -replace "{{TABLE_HEADERS}}", "<tr>$headers</tr>"
    $html = $html -replace "{{TABLE_DATA}}", $tableData
    $html = $html -replace "{{PS_VERSION}}", $PSVersionTable.PSVersion
    $html = $html -replace "{{TOOL_VERSION}}", "v2.0"
    $html = $html -replace "{{JS_PATH}}", $jsPath
    
    # ファイル出力
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    
    # CSV版も生成
    $csvPath = $OutputPath -replace "\.html$", ".csv"
    $data | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8BOM
    
    return @{
        HTMLPath = $OutputPath
        CSVPath = $csvPath
        RecordCount = $data.Count
    }
}

# 実行例
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "サンプルレポート生成中..." -ForegroundColor Cyan
    
    $outputDir = Join-Path $PSScriptRoot "..\Samples"
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }
    
    # 各種レポートタイプのサンプル生成
    $reportTypes = @("UserActivity", "SecurityReport", "LicenseUsage", "MailboxUsage", "TeamsActivity")
    
    foreach ($type in $reportTypes) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $outputPath = Join-Path $outputDir "${type}_Sample_${timestamp}.html"
        
        Write-Host "生成中: $type" -ForegroundColor Yellow
        $result = Generate-SampleHTMLReport -ReportType $type -OutputPath $outputPath -RecordCount 100
        
        Write-Host "✅ 完了: $($result.HTMLPath)" -ForegroundColor Green
        Write-Host "   CSV: $($result.CSVPath)" -ForegroundColor Gray
    }
    
    Write-Host "`n✨ すべてのサンプルレポートが生成されました！" -ForegroundColor Green
    Write-Host "出力先: $outputDir" -ForegroundColor Cyan
}