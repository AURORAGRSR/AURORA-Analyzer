# 测试构建脚本的版本号注入逻辑
$tests = @(
    @{
        Name = "旧格式 (# 版本：V...)"
        Content = "# 版本：V1.3.26.6Release | 构建时间：2026.06.08`n# 作者：AURORA"
    },
    @{
        Name = "新格式 - 缩进版 (<# #> 块内)"
        Content = "<#`n.SYNOPSIS`n    测试模块`n.NOTES`n    版本：V1.3.26.6Release | 构建时间：2026.06.08`n    作者：AURORA`n#>"
    },
    @{
        Name = "LauncherGUI 格式"
        Content = "# LauncherGUI Version: V1.3.26.6 | 构建时间：2026.06.08"
    }
)

$patterns = @(
    '(?m)^\s*#?\s*版本：V[^\r\n]+',
    '(?m)^\s*#?\s*Version：V[^\r\n]+',
    '(?m)^\s*#?\s*LauncherGUI Version: V[^\r\n]+'
)

$versionTag = "V1.3.26.7Release"

$allPassed = $true
foreach ($test in $tests) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "测试: $($test.Name)" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    
    $content = $test.Content
    $modified = $false
    foreach ($pattern in $patterns) {
        if ($content -match $pattern) {
            $original = $matches[0]
            $replacement = $