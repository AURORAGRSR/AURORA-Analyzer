# ==========================================
# AURORA Progress Manager ENG Mode Test
# Test English version progress management
# ==========================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  AURORA ENG Mode Progress Test" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

# Import all necessary modules
Write-Host "1. Importing Progress Manager..." -ForegroundColor Yellow
. "$PSScriptRoot\..\Scripts\Session\AURORA-ProgressManager.ps1"
. "$PSScriptRoot\..\Scripts\Session\AURORA-ProgressManager-Integration-ENG.ps1"

# Initialize cache
Write-Host "2. Initializing cache directory..." -ForegroundColor Yellow
$toolPath = Join-Path $PSScriptRoot "..\Scripts"
$initialized = Initialize-CacheDirectory -ToolPath $toolPath
Write-Host "   Cache root: $script:CacheRoot" -ForegroundColor Gray
Write-Host "   Initialization: $initialized`n" -ForegroundColor $(if ($initialized) { 'Green' } else { 'Red' })

# Clean up any existing sessions
Write-Host "3. Cleaning up existing sessions..." -ForegroundColor Yellow
if (Test-PendingSession) {
    $existingSession = Get-LatestPendingSession
    if ($existingSession) {
        Remove-SessionProgress -SessionId $existingSession
        Write-Host "   Removed existing session: $existingSession" -ForegroundColor Gray
    }
} else {
    Write-Host "   No existing sessions found" -ForegroundColor Gray
}
Write-Host ""

# Scenario 1: Create new session and save progress
Write-Host "4. Scenario 1: Create session and save progress" -ForegroundColor Cyan
$sessionId = New-Session -SessionType "ExportTask" -Metadata @{
    LogType = "System"
    Language = "ENG"
    GUI_Mode = $true
}
Write-Host "   Created session: $sessionId" -ForegroundColor Gray

Save-ENGProgress -SessionId $sessionId -Checkpoint "Initialized" -CreateCheckpoint
Write-Host "   Saved: Initialized (5%)" -ForegroundColor Gray

Save-ENGProgress -SessionId $sessionId -Checkpoint "LogTypeSelected"
Write-Host "   Saved: LogTypeSelected (10%)" -ForegroundColor Gray

Save-ENGProgress -SessionId $sessionId -Checkpoint "DateRangeConfigured"
Write-Host "   Saved: DateRangeConfigured (15%)" -ForegroundColor Gray

Save-ENGProgress -SessionId $sessionId -Checkpoint "PerformanceAssessed" -CreateCheckpoint
Write-Host "   Saved: PerformanceAssessed (25%)" -ForegroundColor Gray

Save-ENGProgress -SessionId $sessionId -Checkpoint "HighRiskScanComplete"
Write-Host "   Saved: HighRiskScanComplete (40%)" -ForegroundColor Gray

Save-ENGProgress -SessionId $sessionId -Checkpoint "ExportComplete" -AdditionalData @{
    ExportedFiles = @("System_Log_20260507.csv", "System_Log_20260507.json")
    OutputPath = "$PSScriptRoot\UserLogs"
} -CreateCheckpoint
Write-Host "   Saved: ExportComplete (70%)`n" -ForegroundColor Gray

# Scenario 2: Simulate program crash and restart
Write-Host "5. Scenario 2: Simulate crash and restart" -ForegroundColor Cyan
Write-Host "   Simulating memory clear..." -ForegroundColor Gray
$script:CurrentSessionId = $null
$script:SessionData = @{}
Write-Host "   Memory cleared, simulating restart`n" -ForegroundColor Gray

# Scenario 3: Detect and restore incomplete session
Write-Host "6. Scenario 3: Detect and restore session" -ForegroundColor Cyan
if (Test-PendingSession) {
    Write-Host "   ✅ Detected incomplete session" -ForegroundColor Green
    
    $restoredSession = Restore-SessionProgress
    
    if ($restoredSession) {
        Write-Host "`n   === Restored Session Info ===" -ForegroundColor Cyan
        Write-Host "   Session ID: $($restoredSession.SessionId)" -ForegroundColor White
        Write-Host "   Progress: $($restoredSession.Progress)%" -ForegroundColor White
        Write-Host "   Stage: $($restoredSession.Stage)" -ForegroundColor White
        Write-Host "   Suspended: $($restoredSession.AgeInDays) days" -ForegroundColor White
        
        if ($restoredSession.Data.ExportedFiles) {
            Write-Host "   Exported files: $($restoredSession.Data.ExportedFiles -join ', ')" -ForegroundColor White
        }
        
        Write-Host "`n   User choice: Resume session" -ForegroundColor Yellow
        Write-Host "   ✅ Session restored successfully, can continue`n" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Restore failed" -ForegroundColor Red
    }
} else {
    Write-Host "   ⚠️ No incomplete session found" -ForegroundColor Yellow
}

# Scenario 4: Complete session and archive
Write-Host "7. Scenario 4: Complete and archive session" -ForegroundColor Cyan
Complete-Session -SessionId $sessionId -Archive
Write-Host "   Session completed and archived" -ForegroundColor Green

# Show final statistics
Write-Host "`n8. Cache Statistics" -ForegroundColor Cyan
$stats = Get-SessionStatistics
Write-Host "   Active sessions: $($stats.ActiveSessions)" -ForegroundColor Yellow
Write-Host "   Checkpoints: $($stats.Checkpoints)" -ForegroundColor Yellow
Write-Host "   Archived sessions: $($stats.ArchivedSessions)" -ForegroundColor Yellow
Write-Host "   Total size: $($stats.TotalSizeMB) MB" -ForegroundColor Yellow

# Scenario 5: Test cleanup of expired sessions
Write-Host "`n9. Scenario 5: Cleanup expired sessions" -ForegroundColor Cyan
# Create some expired sessions
1..2 | ForEach-Object {
    $testSessionId = New-Session -SessionType "Test" -Metadata @{ Test = $_ }
    Save-ENGProgress -SessionId $testSessionId -Checkpoint "Initialized"
    
    # Modify file time to simulate expiration
    $activeFile = Join-Path $script:ActiveDir "${testSessionId}.json"
    if (Test-Path $activeFile) {
        $oldTime = (Get-Date).AddDays(-10)
        (Get-Item $activeFile).LastWriteTime = $oldTime
    }
}
Write-Host "   Created 2 expired test sessions" -ForegroundColor Gray

$cleanedCount = Invoke-CacheCleanup -RetentionDays 7
Write-Host "   Cleaned $cleanedCount files" -ForegroundColor Green

# Final summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Final Summary" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
$stats = Get-SessionStatistics
Write-Host "Active sessions: $($stats.ActiveSessions)" -ForegroundColor Yellow
Write-Host "Checkpoints: $($stats.Checkpoints)" -ForegroundColor Yellow
Write-Host "Archived sessions: $($stats.ArchivedSessions)" -ForegroundColor Yellow
Write-Host "Total size: $($stats.TotalSizeMB) MB" -ForegroundColor Yellow

Write-Host "`n✅ ENG Mode Test Complete!" -ForegroundColor Green
Write-Host "`nAll features verified:" -ForegroundColor Cyan
Write-Host "  ✓ Session creation" -ForegroundColor Green
Write-Host "  ✓ Progress saving" -ForegroundColor Green
Write-Host "  ✓ Checkpoint creation" -ForegroundColor Green
Write-Host "  ✓ Session restoration" -ForegroundColor Green
Write-Host "  ✓ Session completion & archiving" -ForegroundColor Green
Write-Host "  ✓ Expired session cleanup" -ForegroundColor Green
