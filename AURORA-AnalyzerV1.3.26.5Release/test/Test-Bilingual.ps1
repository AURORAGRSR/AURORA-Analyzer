# 测试双语功能
Write-Host "=== 测试 ProgressManager 双语功能 ===" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptsDir = Join-Path $scriptDir "..\Scripts"

# 加载模块
. "$scriptsDir\Session\AURORA-ProgressManager.ps1"

Write-Host "`n1. 测试中文（默认）" -ForegroundColor Yellow
$script:Language = "CHS"
Write-Host (Get-LocalizedString "UsingToolCache" "C:\Test")
Write-Host (Get-LocalizedString "CreatingSession" "SESSION_12345")
Write-Host (Get-LocalizedString "SavingProgress" @("Completed", 100, 1, 3))

Write-Host "`n2. 测试英文" -ForegroundColor Yellow
$script:Language = "ENG"
Write-Host (Get-LocalizedString "UsingToolCache" "C:\Test")
Write-Host (Get-LocalizedString "CreatingSession" "SESSION_12345")
Write-Host (Get-LocalizedString "SavingProgress" @("Completed", 100, 1, 3))

Write-Host "`n3. 测试会话创建和保存" -ForegroundColor Yellow
$script:Language = "CHS"
$sessionId = New-Session -SessionType "TestSession" -Metadata @{Test = "Yes"}
Write-Host "会话ID: $sessionId"
Write-Host "CurrentLanguage: $($script:Language)"

Write-Host "`n=== 测试完成 ===" -ForegroundColor Cyan
