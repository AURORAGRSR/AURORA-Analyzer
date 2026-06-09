$PSScriptRootParam = $PSScriptRoot
if (-not $PSScriptRootParam) {
    $PSScriptRootParam = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

$scriptDir = Join-Path $PSScriptRootParam "..\Scripts"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AURORA Undo Real Backup Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 导入 UndoManager
Write-Host "[Step 1] Load UndoManager" -ForegroundColor Yellow
. (Join-Path $scriptDir "Session\AURORA-UndoManager.ps1")

# 初始化
Write-Host ""
Write-Host "[Step 2] Initialize UndoManager" -ForegroundColor Yellow
Initialize-UndoManager

# 创建一个测试文件用于备份
Write-Host ""
Write-Host "[Step 3] Create test file for backup" -ForegroundColor Yellow
$testDir = Join-Path $PSScriptRootParam "test_backup_source"
$testFile = Join-Path $testDir "test_config.txt"

if (-not (Test-Path $testDir)) {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
}
"This is a test configuration file for backup" | Out-File $testFile -Encoding UTF8
Write-Host "   Created: $testFile" -ForegroundColor Gray

# 创建备份快照
Write-Host ""
Write-Host "[Step 4] Create backup snapshot" -ForegroundColor Yellow
Write-Host "   Backup type: File" -ForegroundColor Gray
Write-Host "   File path: $testFile" -ForegroundColor Gray

$snapshot = Create-BackupSnapshot -Type "File" -Paths @($testFile)

if ($snapshot) {
    Write-Host ""
    Write-Host "[Step 5] Verify backup" -ForegroundColor Yellow
    Write-Host "   Snapshot ID: $($snapshot.SnapshotId)" -ForegroundColor Cyan
    Write-Host "   Snapshot Dir: $($snapshot.BackupDir)" -ForegroundColor Cyan
    Write-Host "   Items Count: $($snapshot.Items.Count)" -ForegroundColor Cyan
    Write-Host "   Size: $($snapshot.Size)" -ForegroundColor Cyan
    
    # 列出备份目录内容
    Write-Host ""
    Write-Host "[Step 6] List backup directory contents" -ForegroundColor Yellow
    $backupFiles = Get-ChildItem -Path $snapshot.BackupDir -Recurse
    foreach ($file in $backupFiles) {
        Write-Host "   $($file.FullName)" -ForegroundColor Gray
    }
    
    # 验证备份文件内容
    if ($snapshot.Items.Count -gt 0) {
        $backupItem = $snapshot.Items[0]
        Write-Host ""
        Write-Host "[Step 7] Verify backup file content" -ForegroundColor Yellow
        Write-Host "   Original: $($backupItem.OriginalPath)" -ForegroundColor Gray
        Write-Host "   Backup: $($backupItem.BackupFile)" -ForegroundColor Gray
        
        if (Test-Path $backupItem.BackupFile) {
            $content = Get-Content $backupItem.BackupFile -Raw
            Write-Host "   Content: $content" -ForegroundColor Gray
            Write-Host "   [PASS] Backup file exists and readable" -ForegroundColor Green
        } else {
            Write-Host "   [FAIL] Backup file not found!" -ForegroundColor Red
        }
    }
} else {
    Write-Host "   [FAIL] Snapshot creation failed!" -ForegroundColor Red
}

# 清理
Write-Host ""
Write-Host "[Cleanup] Remove test files" -ForegroundColor Yellow
if (Test-Path $testDir) {
    Remove-Item $testDir -Recurse -Force
    Write-Host "   Removed test source directory" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Check backup directory:" -ForegroundColor Yellow
Write-Host "   $script:BackupDir" -ForegroundColor Gray
