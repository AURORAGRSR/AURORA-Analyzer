$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AURORA Undo Backup Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$PSScriptRootParam = $PSScriptRoot
if (-not $PSScriptRootParam) {
    $PSScriptRootParam = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

$scriptDir = Join-Path $PSScriptRootParam "..\Scripts"
$undoManagerPath = Join-Path $scriptDir "Session\AURORA-UndoManager.ps1"

Write-Host "[Test 1] Load UndoManager" -ForegroundColor Yellow
Write-Host "   Path: $undoManagerPath" -ForegroundColor Gray
. $undoManagerPath

Write-Host ""
Write-Host "[Test 2] BackupDir Path Check" -ForegroundColor Yellow
Write-Host "   BackupDir: $script:BackupDir" -ForegroundColor Gray

$expectedPath = Join-Path $scriptDir "SessionCache\backup"
Write-Host "   Expected: $expectedPath" -ForegroundColor Gray

if ($script:BackupDir -eq $expectedPath) {
    Write-Host "   [PASS] Path is correct" -ForegroundColor Green
} else {
    Write-Host "   [FAIL] Path mismatch" -ForegroundColor Red
    Write-Host "   Actual  : $script:BackupDir" -ForegroundColor Red
}

Write-Host ""
Write-Host "[Test 3] Initialize Backup Directory" -ForegroundColor Yellow
$result = Initialize-UndoManager
if ($result) {
    Write-Host "   [PASS] Initialization successful" -ForegroundColor Green
} else {
    Write-Host "   [FAIL] Initialization failed" -ForegroundColor Red
}

Write-Host ""
Write-Host "[Test 4] Check Directory Exists" -ForegroundColor Yellow
if (Test-Path $script:BackupDir) {
    Write-Host "   [PASS] Directory exists" -ForegroundColor Green
    Write-Host "   Path: $script:BackupDir" -ForegroundColor Gray
} else {
    Write-Host "   [FAIL] Directory not found" -ForegroundColor Red
    Write-Host "   Expected: $script:BackupDir" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[Test 5] Write Permission Test" -ForegroundColor Yellow
try {
    $testFile = Join-Path $script:BackupDir "test_write.txt"
    "Test content" | Out-File $testFile -Encoding UTF8
    if (Test-Path $testFile) {
        Write-Host "   [PASS] Write successful" -ForegroundColor Green
        Remove-Item $testFile -Force
        Write-Host "   [PASS] Cleanup successful" -ForegroundColor Green
    } else {
        Write-Host "   [FAIL] File creation failed" -ForegroundColor Red
    }
} catch {
    Write-Host "   [FAIL] Write error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "[Test 6] Create Snapshot Directory" -ForegroundColor Yellow
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$snapshotId = "TEST_$timestamp`_001"
$snapshotDir = Join-Path $script:BackupDir $snapshotId

Write-Host "   Snapshot ID: $snapshotId" -ForegroundColor Gray
Write-Host "   Snapshot Dir: $snapshotDir" -ForegroundColor Gray

if (-not (Test-Path $snapshotDir)) {
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
    Write-Host "   [PASS] Snapshot directory created" -ForegroundColor Green
} else {
    Write-Host "   [WARN] Directory already exists" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[Test 7] Save Metadata" -ForegroundColor Yellow
$testSnapshot = @{
    SnapshotId = $snapshotId
    CreatedAt = Get-Date -Format "o"
    Type = "Test"
    BackupDir = $snapshotDir
    Items = @()
    Size = "0 KB"
    Status = "Active"
}

try {
    $metadataFile = Join-Path $snapshotDir "metadata.json"
    $testSnapshot | ConvertTo-Json -Depth 5 | Out-File $metadataFile -Encoding UTF8
    
    if (Test-Path $metadataFile) {
        Write-Host "   [PASS] Metadata file created" -ForegroundColor Green
        Write-Host "   File: $metadataFile" -ForegroundColor Gray
        
        $content = Get-Content $metadataFile -Raw | ConvertFrom-Json
        if ($content.SnapshotId -eq $snapshotId) {
            Write-Host "   [PASS] Metadata content verified" -ForegroundColor Green
        } else {
            Write-Host "   [FAIL] Metadata content mismatch" -ForegroundColor Red
        }
    } else {
        Write-Host "   [FAIL] Metadata file creation failed" -ForegroundColor Red
    }
} catch {
    Write-Host "   [FAIL] Save metadata error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Cleanup test data..." -ForegroundColor Gray
if (Test-Path $snapshotDir) {
    Remove-Item $snapshotDir -Recurse -Force
    Write-Host "   [PASS] Test snapshot directory deleted" -ForegroundColor Green
}
