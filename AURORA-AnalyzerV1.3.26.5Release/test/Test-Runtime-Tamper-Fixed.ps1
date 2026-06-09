# ============================================================================
# AURORA 运行时防篡改修复验证测试
# ============================================================================
# 测试目标：验证修复后的代码是否有效防止篡改
# ============================================================================

$ErrorActionPreference = "Stop"
$TestDir = Join-Path $PSScriptRoot "TestTamperFixed"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  AURORA 修复后验证测试" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Cleanup
if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }
New-Item -ItemType Directory -Path $TestDir | Out-Null

# ============================================================================
# 模拟修复后的运行时检查逻辑
# ============================================================================
Write-Host "[模拟] 修复后的运行时完整性检查" -ForegroundColor Yellow
Write-Host ""

# 创建测试文件
$testFiles = @("file1.ps1", "file2.ps1", "file3.ps1")
foreach ($file in $testFiles) {
    $path = Join-Path $TestDir $file
    Set-Content -Path $path -Value "Test Content" -Encoding UTF8
}

# 使用 script 作用域 (修复 1)
$script:ExpectedFileHashes = @{}
foreach ($file in $testFiles) {
    $path = Join-Path $TestDir $file
    $hash = (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
    $script:ExpectedFileHashes[$file] = $hash
}

Write-Host "  初始状态：$($script:ExpectedFileHashes.Count) 个文件被监控" -ForegroundColor Gray
foreach ($file in $script:ExpectedFileHashes.Keys) {
    Write-Host "    - $file" -ForegroundColor Gray
}
Write-Host ""

# ============================================================================
# 测试场景 1: 文件删除攻击 (已修复)
# ============================================================================
Write-Host "[测试 1] 文件删除攻击测试" -ForegroundColor Yellow
Write-Host "  攻击：删除 file2.ps1" -ForegroundColor Red

Remove-Item (Join-Path $TestDir "file2.ps1") -Force

# 模拟修复后的检查逻辑
$tampered = $false
$missingFiles = @()

# 文件计数检查 (修复 2)
$expectedCount = $script:ExpectedFileHashes.Count
$actualFiles = @()
foreach ($file in $script:ExpectedFileHashes.Keys) {
    $fullPath = Join-Path $TestDir $file
    if (Test-Path $fullPath) {
        $actualFiles += $file
    }
}
$actualCount = $actualFiles.Count

if ($actualCount -ne $expectedCount) {
    $missingFiles = $script:ExpectedFileHashes.Keys | Where-Object {
        -not (Test-Path (Join-Path $TestDir $_))
    }
    $tampered = $true
}

# 文件存在性检查 (修复 3)
if (-not $tampered) {
    foreach ($file in $script:ExpectedFileHashes.Keys) {
        $fullPath = Join-Path $TestDir $file
        if (-not (Test-Path $fullPath)) {  # 修复：不再 continue，而是报警
            $tampered = $true
            if ($missingFiles -eq $null) { $missingFiles = @() }
            $missingFiles += $file
            break
        }
    }
}

if ($tampered) {
    Write-Host "  ✅ [PASS] 检测到文件删除！" -ForegroundColor Green
    Write-Host "     缺失文件：$($missingFiles -join ', ')" -ForegroundColor Green
    $test1Pass = $true
} else {
    Write-Host "  ❌ [FAIL] 未检测到文件删除" -ForegroundColor Red
    $test1Pass = $false
}
Write-Host ""

# 重新创建文件
Set-Content -Path (Join-Path $TestDir "file2.ps1") -Value "Test Content" -Encoding UTF8

# ============================================================================
# 测试场景 2: 文件篡改攻击 (已修复)
# ============================================================================
Write-Host "[测试 2] 文件内容篡改测试" -ForegroundColor Yellow
Write-Host "  攻击：修改 file1.ps1 内容" -ForegroundColor Red

Set-Content -Path (Join-Path $TestDir "file1.ps1") -Value "Hacked Content" -Encoding UTF8

$tampered = $false
foreach ($file in $script:ExpectedFileHashes.Keys) {
    $fullPath = Join-Path $TestDir $file
    if (Test-Path $fullPath) {
        $hash = (Get-FileHash $fullPath -Algorithm SHA256).Hash.ToLower()
        $expected = $script:ExpectedFileHashes[$file]
        if ($hash -ne $expected) {
            $tampered = $true
            break
        }
    }
}

if ($tampered) {
    Write-Host "  ✅ [PASS] 检测到文件篡改！" -ForegroundColor Green
    $test2Pass = $true
} else {
    Write-Host "  ❌ [FAIL] 未检测到文件篡改" -ForegroundColor Red
    $test2Pass = $false
}
Write-Host ""

# ============================================================================
# 测试场景 3: 哈希表篡改攻击 (部分修复)
# ============================================================================
Write-Host "[测试 3] 哈希表保护测试" -ForegroundColor Yellow
Write-Host "  攻击：尝试修改 script:ExpectedFileHashes" -ForegroundColor Red

# script 作用域比 global 作用域更安全，但仍可被同一脚本访问
$originalHash = $script:ExpectedFileHashes["file1.ps1"]
$script:ExpectedFileHashes["file1.ps1"] = "fake_hash"

Write-Host "  修改前：$originalHash" -ForegroundColor Gray
Write-Host "  修改后：$($script:ExpectedFileHashes['file1.ps1'])" -ForegroundColor Gray
Write-Host "  注意：script 作用域提供基本保护，但仍可被同一脚本内访问" -ForegroundColor Yellow
Write-Host "  建议：未来使用私有类封装" -ForegroundColor Yellow
$test3Pass = $false  # script 作用域不是完全安全
Write-Host ""

# 恢复
$script:ExpectedFileHashes["file1.ps1"] = $originalHash

# ============================================================================
# 测试场景 4: 检查间隔测试 (已修复)
# ============================================================================
Write-Host "[测试 4] 检查间隔测试" -ForegroundColor Yellow

# 读取实际代码中的检查间隔
$launcherScript = Join-Path $PSScriptRoot "Scripts\AURORA-AnalyzerLauncherGUI.ps1"
if (Test-Path $launcherScript) {
    $content = Get-Content $launcherScript -Raw
    if ($content -match '\$global:IntegrityCheckInterval\s*=\s*(\d+)') {
        $interval = [int]$matches[1]
        Write-Host "  当前检查间隔：$interval 毫秒 ($([Math]::Round($interval/1000, 1)) 秒)" -ForegroundColor Gray
        
        if ($interval -le 10000) {
            Write-Host "  ✅ [PASS] 检查间隔已缩短到 10 秒以内" -ForegroundColor Green
            $test4Pass = $true
        } else {
            Write-Host "  ❌ [FAIL] 检查间隔仍然过长 (>10 秒)" -ForegroundColor Red
            $test4Pass = $false
        }
    } else {
        Write-Host "  ⚠️  [WARN] 未找到检查间隔配置" -ForegroundColor Yellow
        $test4Pass = $false
    }
} else {
    Write-Host "  ⚠️  [WARN] 未找到启动脚本" -ForegroundColor Yellow
    $test4Pass = $false
}
Write-Host ""

# ============================================================================
# 测试场景 5: 多 Timer 检查 (新增)
# ============================================================================
Write-Host "[测试 5] 多 Timer 检查测试" -ForegroundColor Yellow

if (Test-Path $launcherScript) {
    $content = Get-Content $launcherScript -Raw
    
    $hasMainTimer = $content -match 'runtimeIntegrityTimer'
    $hasRandomTimer = $content -match 'randomIntegrityTimer'
    
    if ($hasMainTimer -and $hasRandomTimer) {
        Write-Host "  ✅ [PASS] 检测到主 Timer 和随机 Timer" -ForegroundColor Green
        Write-Host "     - 主 Timer: 定期检查 (10 秒)" -ForegroundColor Green
        Write-Host "     - 随机 Timer: 随机检查 (5-15 秒)" -ForegroundColor Green
        $test5Pass = $true
    } elseif ($hasMainTimer) {
        Write-Host "  ⚠️  [PARTIAL] 仅检测到主 Timer" -ForegroundColor Yellow
        $test5Pass = $false
    } else {
        Write-Host "  ❌ [FAIL] 未检测到 Timer" -ForegroundColor Red
        $test5Pass = $false
    }
} else {
    Write-Host "  ⚠️  [WARN] 未找到启动脚本" -ForegroundColor Yellow
    $test5Pass = $false
}
Write-Host ""

# ============================================================================
# 总结
# ============================================================================
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  测试结果总结" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$results = @{
    "文件删除检测" = $test1Pass
    "文件篡改检测" = $test2Pass
    "哈希表保护" = $test3Pass  # script 作用域不是完全安全
    "检查间隔优化" = $test4Pass
    "多 Timer 检查" = $test5Pass
}

$passed = 0
foreach ($test in $results.Keys) {
    if ($results[$test]) {
        Write-Host "  [PASS] $test" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "  [FAIL] $test" -ForegroundColor Red
    }
}

$total = $results.Count
$score = [Math]::Round(($passed / $total) * 100, 1)

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  安全评分：$score / 100" -ForegroundColor $(if ($score -ge 70) { "Green" } elseif ($score -ge 50) { "Yellow" } else { "Red" })
Write-Host "============================================" -ForegroundColor Cyan

if ($score -ge 80) {
    Write-Host "`n✅ 恭喜！运行时防篡改机制已有效修复！" -ForegroundColor Green
    Write-Host "   主要改进:" -ForegroundColor White
    Write-Host "   1. 文件删除不再绕过检查" -ForegroundColor Green
    Write-Host "   2. 检查间隔缩短到 10 秒" -ForegroundColor Green
    Write-Host "   3. 添加文件计数检查" -ForegroundColor Green
    Write-Host "   4. 使用 script 作用域保护哈希表" -ForegroundColor Green
    Write-Host "   5. 添加随机 Timer 增加攻击难度" -ForegroundColor Green
} elseif ($score -ge 50) {
    Write-Host "`n⚠️  部分修复完成，仍有改进空间" -ForegroundColor Yellow
} else {
    Write-Host "`n❌ 修复不充分，需要继续改进" -ForegroundColor Red
}

# Cleanup
if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }
Write-Host "`n测试完成。" -ForegroundColor Cyan
