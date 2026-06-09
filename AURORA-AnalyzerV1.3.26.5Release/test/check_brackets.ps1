$content = Get-Content 'e:\PC SOFT\优化软件\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory\Scripts\PRO\AURORA-AnalyzerPRO-Engine.ps1' -Raw
$tokens = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)

# 统计代码中的花括号（排除字符串和注释）
$codeTokens = $tokens | Where-Object { $_.Type -ne 'String' -and $_.Type -ne 'Comment' }
$codeContent = ($codeTokens | ForEach-Object { $content.Substring($_.Start, $_.Length) }) -join ''

$leftBrace = ($codeContent -split '\{' ).Length - 1
$rightBrace = ($codeContent -split '\}').Length - 1

Write-Host "花括号（代码中）: 左=$leftBrace 右=$rightBrace 差=$($leftBrace - $rightBrace)"
Write-Host "字符串Token: $(($tokens | Where-Object { $_.Type -eq 'String' }).Count)"
Write-Host "注释Token: $(($tokens | Where-Object { $_.Type -eq 'Comment' }).Count)"
Write-Host "总Token: $($tokens.Count)"

# 测试语法
try {
    $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
    if ($errors.Count -eq 0) {
        Write-Host "✅ 语法检查通过"
    } else {
        Write-Host "❌ 语法错误: $($errors.Count) 个"
        $errors | Select-Object -First 5 | ForEach-Object { Write-Host "  $($_.Message) 行:$($_.Extent.StartLineNumber)" }
    }
} catch {
    Write-Host "❌ 解析失败: $($_.Exception.Message)"
}
