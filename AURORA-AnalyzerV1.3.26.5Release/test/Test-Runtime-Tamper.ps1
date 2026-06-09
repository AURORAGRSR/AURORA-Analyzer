# ============================================================================
# AURORA Runtime Anti-Tampering Effectiveness Test
# ============================================================================

$ErrorActionPreference = "Stop"
$TestDir = Join-Path $PSScriptRoot "TestTamper"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  AURORA Runtime Anti-Tampering Test" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Cleanup
if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }
New-Item -ItemType Directory -Path $TestDir | Out-Null

# ============================================================================
# Test 1: Global Variable Accessibility
# ============================================================================
Write-Host "[Test 1] Global Variable Protection Test" -ForegroundColor Yellow

$global:ExpectedFileHashes = @{
    "test1.ps1" = "abc123"
    "test2.ps1" = "def456"
}

Write-Host "  Attack: Modifying `$global:ExpectedFileHashes" -ForegroundColor Red
try {
    $global:ExpectedFileHashes["test1.ps1"] = "hacked_hash"
    Write-Host "  [FAIL] Successfully modified (DANGEROUS!)" -ForegroundColor Red
    $test1Pass = $false
} catch {
    Write-Host "  [PASS] Modification blocked (SAFE)" -ForegroundColor Green
    $test1Pass = $true
}

Write-Host "  Attack: Clearing hash table" -ForegroundColor Red
try {
    $global:ExpectedFileHashes.Clear()
    Write-Host "  [FAIL] Successfully cleared (DANGEROUS!)" -ForegroundColor Red
    $test2Pass = $false
} catch {
    Write-Host "  [PASS] Clear blocked (SAFE)" -ForegroundColor Green
    $test2Pass = $true
}

# Restore
$global:ExpectedFileHashes = @{
    "test1.ps1" = "abc123"
    "test2.ps1" = "def456"
}

# ============================================================================
# Test 2: File Hash Detection
# ============================================================================
Write-Host "`n[Test 2] File Hash Detection Test" -ForegroundColor Yellow

$testFile = Join-Path $TestDir "test.ps1"
Set-Content -Path $testFile -Value "Original Content" -Encoding UTF8
$originalHash = (Get-FileHash $testFile -Algorithm SHA256).Hash.ToLower()

Write-Host "  Original hash: $($originalHash.Substring(0, 40))..." -ForegroundColor Gray

Set-Content -Path $testFile -Value "Hacked Content" -Encoding UTF8
$modifiedHash = (Get-FileHash $testFile -Algorithm SHA256).Hash.ToLower()

if ($originalHash -ne $modifiedHash) {
    Write-Host "  [PASS] Hash change detected (SAFE)" -ForegroundColor Green
    $test3Pass = $true
} else {
    Write-Host "  [FAIL] Hash not changed (HASH COLLISION?)" -ForegroundColor Red
    $test3Pass = $false
}

# ============================================================================
# Test 3: File Deletion Bypass (CRITICAL!)
# ============================================================================
Write-Host "`n[Test 3] File Deletion Bypass Test" -ForegroundColor Yellow

$testFile2 = Join-Path $TestDir "test2.ps1"
Set-Content -Path $testFile2 -Value "Test" -Encoding UTF8
$fullPath = $testFile2

Write-Host "  Simulating runtime check logic..." -ForegroundColor Gray
Write-Host "  Attack: Deleting monitored file" -ForegroundColor Red
Remove-Item $testFile2 -Force

# Reproduce the EXACT logic from AURORA-AnalyzerLauncherGUI.ps1 line 424
if (-not (Test-Path $fullPath)) {
    Write-Host "  [CRITICAL] File missing - check SKIPPED (continue statement)" -ForegroundColor Red
    Write-Host "  [FAIL] File deletion BYPASSES check! SERIOUS VULNERABILITY!" -ForegroundColor Red
    $test4Pass = $false
} else {
    Write-Host "  [PASS] File exists, hash check continues" -ForegroundColor Green
    $test4Pass = $true
}

# ============================================================================
# Test 4: Memory Variable Enumeration
# ============================================================================
Write-Host "`n[Test 4] Memory Variable Exposure Test" -ForegroundColor Yellow

$sensitiveData = @{
    Hashes = $global:ExpectedFileHashes
    Keys = "AES_KEY_SECRET"
}

Write-Host "  Attack: Enumerating global variables..." -ForegroundColor Red
$globalVars = Get-Variable -Scope Global
$sensitiveVars = $globalVars | Where-Object { 
    $_.Name -like "*Hash*" -or $_.Name -like "*Key*" -or $_.Name -like "*Token*"
}

if ($sensitiveVars.Count -gt 0) {
    Write-Host "  [FAIL] Found $($sensitiveVars.Count) sensitive variables" -ForegroundColor Red
    Write-Host "     Variables: $($sensitiveVars.Name -join ', ')" -ForegroundColor Yellow
    $test5Pass = $false
} else {
    Write-Host "  [PASS] No sensitive variables found" -ForegroundColor Green
    $test5Pass = $true
}

# ============================================================================
# Summary
# ============================================================================
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  Test Results Summary" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan

$results = @{
    "Global Variable Protection" = $test1Pass -and $test2Pass
    "File Hash Detection" = $test3Pass
    "File Deletion Bypass" = $test4Pass
    "Memory Variable Protection" = $test5Pass
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

if ($score -lt 50) {
    Write-Host "`n[WARNING] Runtime anti-tampering has CRITICAL vulnerabilities!" -ForegroundColor Red
    Write-Host "Recommendations:" -ForegroundColor Yellow
    Write-Host "  1. Use private scope for hash table" -ForegroundColor White
    Write-Host "  2. Add file existence check (not just hash)" -ForegroundColor White
    Write-Host "  3. Reduce check interval (current: 60s is too long)" -ForegroundColor White
    Write-Host "  4. Add multiple check points" -ForegroundColor White
    Write-Host "  5. Use secure string for sensitive data" -ForegroundColor White
}

# Cleanup
if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }
Write-Host "`nTest completed." -ForegroundColor Cyan
