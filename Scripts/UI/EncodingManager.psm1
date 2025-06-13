# ================================================================================
# EncodingManager.psm1
# 文字化け対策と文字エンコーディング管理モジュール
# ================================================================================

# グローバル変数
$Script:OriginalOutputEncoding = $null
$Script:OriginalInputEncoding = $null
$Script:IsEncodingInitialized = $false

# 文字化け対策初期化関数
function Initialize-EncodingSupport {
    <#
    .SYNOPSIS
    文字化け対策のための文字エンコーディングを初期化

    .DESCRIPTION
    PowerShellコンソールの入出力エンコーディングを適切に設定し、Unicode文字の表示を改善

    .PARAMETER Force
    既に初期化済みでも強制的に再実行

    .EXAMPLE
    Initialize-EncodingSupport
    Initialize-EncodingSupport -Force
    #>
    
    param(
        [switch]$Force
    )
    
    if ($Script:IsEncodingInitialized -and -not $Force) {
        Write-Verbose "エンコーディング設定は既に初期化済みです。"
        return
    }
    
    try {
        # 元のエンコーディング設定を保存
        if ($null -eq $Script:OriginalOutputEncoding) {
            $Script:OriginalOutputEncoding = [Console]::OutputEncoding
        }
        
        if ($null -eq $Script:OriginalInputEncoding) {
            $Script:OriginalInputEncoding = [Console]::InputEncoding
        }
        
        # UTF-8エンコーディングを設定
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::InputEncoding = [System.Text.Encoding]::UTF8
        
        # PowerShell固有の設定
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            # PowerShell Core/7の場合
            $OutputEncoding = [System.Text.Encoding]::UTF8
        } else {
            # Windows PowerShell 5.1の場合
            $OutputEncoding = [System.Text.Encoding]::UTF8
        }
        
        $Script:IsEncodingInitialized = $true
        Write-Verbose "文字エンコーディングをUTF-8に設定しました。"
        
    } catch {
        Write-Warning "エンコーディング設定に失敗しました: $($_.Exception.Message)"
    }
}

# エンコーディング設定を復元する関数
function Restore-EncodingSupport {
    <#
    .SYNOPSIS
    文字エンコーディング設定を元に戻す

    .DESCRIPTION
    Initialize-EncodingSupportで変更したエンコーディング設定を元の状態に復元

    .EXAMPLE
    Restore-EncodingSupport
    #>
    
    try {
        if ($null -ne $Script:OriginalOutputEncoding) {
            [Console]::OutputEncoding = $Script:OriginalOutputEncoding
        }
        
        if ($null -ne $Script:OriginalInputEncoding) {
            [Console]::InputEncoding = $Script:OriginalInputEncoding
        }
        
        $Script:IsEncodingInitialized = $false
        Write-Verbose "エンコーディング設定を復元しました。"
        
    } catch {
        Write-Warning "エンコーディング設定の復元に失敗しました: $($_.Exception.Message)"
    }
}

# Unicode文字のサポート状況をテストする関数
function Test-UnicodeSupport {
    <#
    .SYNOPSIS
    現在の環境でのUnicode文字サポート状況をテスト

    .DESCRIPTION
    様々なUnicode文字を出力して表示可能かどうかをテスト

    .OUTPUTS
    PSCustomObject - Unicode文字サポート状況

    .EXAMPLE
    Test-UnicodeSupport
    #>
    
    $testChars = @{
        "BoxDrawing" = @("╔", "═", "╗", "║", "╚", "╝")
        "Symbols" = @("✓", "✗", "⚠", "ℹ", "🔒", "📊")
        "Japanese" = @("あ", "漢", "字", "「」")
        "Arrows" = @("←", "→", "↑", "↓", "⇒", "⇐")
    }
    
    $supportResult = [PSCustomObject]@{
        BoxDrawingSupported = $true
        SymbolsSupported = $true
        JapaneseSupported = $true
        ArrowsSupported = $true
        OverallSupport = "Unknown"
        TestedAt = Get-Date
        Environment = @{
            OutputEncoding = [Console]::OutputEncoding.EncodingName
            InputEncoding = [Console]::InputEncoding.EncodingName
            PowerShellVersion = $PSVersionTable.PSVersion
            Platform = $PSVersionTable.Platform
        }
    }
    
    try {
        # 実際のテストは視覚的確認が必要なため、エンコーディング情報のみ返す
        Write-Verbose "Unicode文字サポートテストを実行中..."
        
        # エンコーディングがUTF-8系かどうかでサポート状況を判定
        $isUTF8 = [Console]::OutputEncoding.EncodingName -like "*UTF*"
        
        if ($isUTF8) {
            $supportResult.OverallSupport = "Good"
        } else {
            $supportResult.OverallSupport = "Limited"
            $supportResult.BoxDrawingSupported = $false
            $supportResult.SymbolsSupported = $false
        }
        
    } catch {
        $supportResult.OverallSupport = "Poor"
        $supportResult.BoxDrawingSupported = $false
        $supportResult.SymbolsSupported = $false
        $supportResult.JapaneseSupported = $false
        $supportResult.ArrowsSupported = $false
    }
    
    return $supportResult
}

# ASCII代替文字マッピングを提供する関数
function Get-ASCIIAlternative {
    <#
    .SYNOPSIS
    Unicode文字のASCII代替文字を取得

    .DESCRIPTION
    Unicode文字が表示できない環境向けのASCII代替文字を提供

    .PARAMETER UnicodeChar
    変換対象のUnicode文字

    .OUTPUTS
    String - ASCII代替文字

    .EXAMPLE
    Get-ASCIIAlternative -UnicodeChar "✓"
    Get-ASCIIAlternative -UnicodeChar "╔"
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$UnicodeChar
    )
    
    $asciiMap = @{
        # ボックス描画文字
        "╔" = "+"
        "╗" = "+"
        "╚" = "+"
        "╝" = "+"
        "║" = "|"
        "═" = "="
        "╠" = "+"
        "╣" = "+"
        "╦" = "+"
        "╩" = "+"
        "╬" = "+"
        
        # 記号文字
        "✓" = "[OK]"
        "✗" = "[NG]"
        "⚠" = "[!]"
        "ℹ" = "[i]"
        "🔒" = "[LOCK]"
        "📊" = "[CHART]"
        "📈" = "[TREND]"
        "💰" = "[MONEY]"
        "🚨" = "[ALERT]"
        "📋" = "[LIST]"
        "🧮" = "[CALC]"
        
        # 矢印文字
        "←" = "<-"
        "→" = "->"
        "↑" = "^"
        "↓" = "v"
        "⇒" = "=>"
        "⇐" = "<="
        
        # 日本語括弧
        "「" = "["
        "」" = "]"
        "（" = "("
        "）" = ")"
    }
    
    if ($asciiMap.ContainsKey($UnicodeChar)) {
        return $asciiMap[$UnicodeChar]
    } else {
        return $UnicodeChar  # 代替文字がない場合は元の文字を返す
    }
}

# 安全な文字列出力関数
function Write-SafeString {
    <#
    .SYNOPSIS
    文字化けを考慮した安全な文字列出力

    .DESCRIPTION
    Unicode文字サポート状況に応じて適切な文字を選択して出力

    .PARAMETER Text
    出力するテキスト

    .PARAMETER ForegroundColor
    文字色

    .PARAMETER BackgroundColor
    背景色

    .PARAMETER NoNewline
    改行を抑制

    .EXAMPLE
    Write-SafeString -Text "✓ 処理完了" -ForegroundColor Green
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        
        [ConsoleColor]$ForegroundColor,
        [ConsoleColor]$BackgroundColor,
        [switch]$NoNewline
    )
    
    # Unicode文字を安全な文字に変換
    $safeText = $Text
    $unicodeSupport = Test-UnicodeSupport
    
    if ($unicodeSupport.OverallSupport -eq "Poor" -or $unicodeSupport.OverallSupport -eq "Limited") {
        # Unicode文字を ASCII 代替文字に変換
        $unicodeChars = @("╔", "╗", "╚", "╝", "║", "═", "✓", "✗", "⚠", "ℹ", "🔒", "📊", "📈", "💰", "🚨", "📋", "🧮", "←", "→", "↑", "↓", "⇒", "⇐", "「", "」")
        
        foreach ($char in $unicodeChars) {
            if ($safeText.Contains($char)) {
                $alternative = Get-ASCIIAlternative -UnicodeChar $char
                $safeText = $safeText.Replace($char, $alternative)
            }
        }
    }
    
    # Write-Hostパラメータの構築
    $writeParams = @{
        Object = $safeText
    }
    
    if ($PSBoundParameters.ContainsKey('ForegroundColor')) {
        $writeParams.ForegroundColor = $ForegroundColor
    }
    
    if ($PSBoundParameters.ContainsKey('BackgroundColor')) {
        $writeParams.BackgroundColor = $BackgroundColor
    }
    
    if ($NoNewline) {
        $writeParams.NoNewline = $true
    }
    
    Write-Host @writeParams
}

# ボックス描画関数
function Write-SafeBox {
    <#
    .SYNOPSIS
    文字化けを考慮した安全なボックス描画

    .DESCRIPTION
    Unicode対応状況に応じてボックス文字またはASCII文字でボックスを描画

    .PARAMETER Title
    ボックスのタイトル

    .PARAMETER Width
    ボックスの幅

    .PARAMETER Color
    ボックスの色

    .EXAMPLE
    Write-SafeBox -Title "Microsoft 365 管理ツール" -Width 60 -Color Blue
    #>
    
    param(
        [string]$Title = "",
        [int]$Width = 60,
        [ConsoleColor]$Color = "White"
    )
    
    $unicodeSupport = Test-UnicodeSupport
    
    if ($unicodeSupport.BoxDrawingSupported -and $unicodeSupport.OverallSupport -ne "Poor") {
        # Unicode文字でボックス描画
        $topLeft = "╔"
        $topRight = "╗"
        $bottomLeft = "╚"
        $bottomRight = "╝"
        $horizontal = "═"
        $vertical = "║"
    } else {
        # ASCII文字でボックス描画
        $topLeft = "+"
        $topRight = "+"
        $bottomLeft = "+"
        $bottomRight = "+"
        $horizontal = "="
        $vertical = "|"
    }
    
    # タイトルの長さ調整
    if ($Title.Length -gt ($Width - 4)) {
        $Title = $Title.Substring(0, $Width - 7) + "..."
    }
    
    # 上辺
    $topLine = $topLeft + ($horizontal * ($Width - 2)) + $topRight
    Write-Host $topLine -ForegroundColor $Color
    
    # タイトル行
    if ($Title) {
        $titlePadding = [math]::Floor(($Width - 2 - $Title.Length) / 2)
        $titleLine = $vertical + (" " * $titlePadding) + $Title + (" " * ($Width - 2 - $titlePadding - $Title.Length)) + $vertical
        Write-Host $titleLine -ForegroundColor $Color
    }
    
    # 下辺
    $bottomLine = $bottomLeft + ($horizontal * ($Width - 2)) + $bottomRight
    Write-Host $bottomLine -ForegroundColor $Color
}

# モジュール初期化時にエンコーディングを設定
if (-not $Script:IsEncodingInitialized) {
    Initialize-EncodingSupport
}

# エクスポートする関数
Export-ModuleMember -Function @(
    'Initialize-EncodingSupport',
    'Restore-EncodingSupport',
    'Test-UnicodeSupport',
    'Get-ASCIIAlternative',
    'Write-SafeString',
    'Write-SafeBox'
)