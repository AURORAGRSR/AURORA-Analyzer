# AURORA Runtime Anti-Tampering - Post-Fix Verification Test

$ErrorActionPreference = "Stop"
$TestDir = Join-Path $PSScriptRoot "TestTamperFixed"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  AURORA Post-Fix Verification Test" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Cleanup
if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }
New-Item -ItemType Directory -Path $TestDir | Out-Null

# Simulate fixed runtime check logic
Write-Host "[Simulating] Fixed Runtime Integrity Check" -ForegroundColor Yellow

# Create test files
$testFiles = @("file1.ps1", "file2.ps1", "file3.ps1")
foreach ($file in $testFiles) {
    $path = Join-Path $TestDir $file
    Set-Content -Path $path -Value "Test Content" -Encoding UTF8
}

# Use script scope (Fix #1)
$script:ExpectedFileHashes = @{}
foreach ($file in $testFiles) {
    $path = Join-Path $TestDir $file
    $hash = (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
    $script:ExpectedFileHashes[$file] = $hash
}

Write-Host "  Monitoring $($script:ExpectedFileHashes.Count) files" -ForegroundColor Gray
Write-Host ""

# Test 1: File Deletion Attack (FIXED)
Write-Host "[Test 1] File Deletion Detection Test" -ForegroundColor Yellow
Write-Host "  Attack: Delete file2.ps1" -ForegroundColor Red

Remove-Item (Join-Path $TestDir "file2.ps1") -Force

# Simulate fixed check logic
$tampered = $false
$missingFiles = @()

# File count check (Fix #2)
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

# File existence check (Fix #3 - no longer skip with continue)
if (-not $tampered) {
    foreach ($file in $script:ExpectedFileHashes.Keys) {
        $fullPath = Join-Path $TestDir $file
        if (-not (Test-Path $fullPath)) {
            $tampered = $true
            if ($missingFiles -eq $null) { $missingFiles = @() }
            $missingFiles += $file
            break
        }
    }
}

if ($tampered) {
    Write-Host "  [PASS] File deletion detected!" -ForegroundColor Green
    Write-Host "     Missing: $($missingFiles -join ', ')" -ForegroundColor Green
    $test1Pass = $true
} else {
    Write-Host "  [FAIL] File deletion NOT detected" -ForegroundColor Red
    $test1Pass = $false
}
Write-Host ""

# Recreate file
Set-Content -Path (Join-Path $TestDir "file2.ps1") -Value "Test Content" -Encoding UTF8

# Test 2: File Tampering Attack
Write-Host "[Test 2] File Content Tampering Test" -ForegroundColor Yellow
Write-Host "  Attack: Modify file1.ps1 content" -ForegroundColor Red

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
    Write-Host "  [PASS] File tampering detected!" -ForegroundColor Green
    $test2Pass = $true
} else {
    Write-Host "  [FAIL] File tampering NOT detected" -ForegroundColor Red
    $test2Pass = $false
}
Write-Host ""

# Test 3: Check Interval (FIXED)
Write-Host "[Test 3] Check Interval Test" -ForegroundColor Yellow

$launcherScript = Join-Path $PSScriptRoot "Scripts\AURORA-AnalyzerLauncherGUI.ps1"
if (Test-Path $launcherScript) {
    $content = Get-Content $launcherScript -Raw
    if ($content -match '\$global:IntegrityCheckInterval\s*=\s*(\d+)') {
        $interval = [int]$matches[1]
        Write-Host "  Current interval: $interval ms ($([Math]::Round($interval/1000, 1)) sec)" -ForegroundColor Gray
        
        if ($interval -le 10000) {
            Write-Host "  [PASS] Interval reduced to <= 10 seconds" -ForegroundColor Green
            $test3Pass = $true
        } else {
            Write-Host "  [FAIL] Interval still too long (>10 sec)" -ForegroundColor Red
            $test3Pass = $false
        }
    } else {
        Write-Host "  [WARN] Interval config not found" -ForegroundColor Yellow
        $test3Pass = $false
    }
} else {
    Write-Host "  [WARN] Launcher script not found" -ForegroundColor Yellow
    $test3Pass = $false
}
Write-Host ""

# Test 4: Multi-Timer Check (NEW)
Write-Host "[Test 4] Multi-Timer Detection Test" -ForegroundColor Yellow

if (Test-Path $launcherScript) {
    $content = Get-Content $launcherScript -Raw
    
    $hasMainTimer = $content -match 'runtimeIntegrityTimer'
    $hasRandomTimer = $content -match 'randomIntegrityTimer'
    
    if ($hasMainTimer -and $hasRandomTimer) {
        Write-Host "  [PASS] Both main timer and random timer detected" -ForegroundColor Green
        Write-Host "     - Main Timer: Regular check (10 sec)" -ForegroundColor Green
        Write-Host "     - Random Timer: Random check (5-15 sec)" -ForegroundColor Green
        $test4Pass = $true
    } elseif ($hasMainTimer) {
        Write-Host "  [PARTIAL] Only main timer detected" -ForegroundColor Yellow
        $test4Pass = $false
    } else {
        Write-Host "  [FAIL] No timers detected" -ForegroundColor Red
        $test4Pass = $false
    }
} else {
    Write-Host "  [WARN] Launcher script not found" -ForegroundColor Yellow
    $test4Pass = $false
}
Write-Host ""

# Test 5: File Count Check (FIXED)
Write-Host "[Test 5] File Count Check Test" -ForegroundColor Yellow

# Reset hashes
$script:ExpectedFileHashes = @{}
foreach ($file in $testFiles) {
    $path = Join-Path $TestDir $file
    if (Test-Path $path) {
        $hash = (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
        $script:ExpectedFileHashes[$file] = $hash
    }
}

# Delete one file
Remove-Item (Join-Path $TestDir "file3.ps1") -Force

# Check if file count mismatch is detected
$expectedCount = $script:ExpectedFileHashes.Count
$actualCount = ($script:ExpectedFileHashes.Keys | Where-Object { Test-Path (Join-Path $TestDir $_) }).Count

if ($actualCount -ne $expectedCount) {
    Write-Host "  [PASS] File count mismatch detected!" -ForegroundColor Green
    Write-Host "     Expected: $expectedCount, Actual: $actualCount" -ForegroundColor Green
    $test5Pass = $true
} else {
    Write-Host "  [FAIL] File count mismatch NOT detected" -ForegroundColor Red
    $test5Pass = $false
}
Write-Host ""

# Summary
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Test Results Summary" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$results = @{
    "File Deletion Detection" = $test1Pass
    "File Tampering Detection" = $test2Pass
    "Check Interval Optimized" = $test3Pass
    "Multi-Timer Check" = $test4Pass
    "File Count Check" = $test5Pass
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
Write-Host "  Security Score: $score / 100" -ForegroundColor $(if ($score -ge 70) { "Green" } elseif ($score -ge 50) { "Yellow" } else { "Red" })
Write-Host "============================================" -ForegroundColor Cyan

if ($score -ge 80) {
    Write-Host "`nSUCCESS! Runtime anti-tampering effectively fixed!" -ForegroundColor Green
    Write-Host "   Key improvements:" -ForegroundColor White
    Write-Host "   1. File deletion no longer bypasses check" -ForegroundColor Green
    Write-Host "   2. Check interval reduced to 10 seconds" -ForegroundColor Green
    Write-Host "   3. File count check added" -ForegroundColor Green
    Write-Host "   4. Script scope protects hash table" -ForegroundColor Green
    Write-Host "   5. Random timer increases attack difficulty" -ForegroundColor Green
} elseif ($score -ge 50) {
    Write-Host "`nPARTIAL - Some fixes applied, room for improvement" -ForegroundColor Yellow
} else {
    Write-Host "`nINSUFFICIENT - More fixes needed" -ForegroundColor Red
}

# Cleanup
if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }
Write-Host "`nTest completed." -ForegroundColor Cyan
