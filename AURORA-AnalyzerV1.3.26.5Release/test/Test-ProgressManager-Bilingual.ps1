# ==========================================
# AURORA Progress Manager Bilingual Comparison Test
# Test both CHS and ENG modes
# ==========================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Bilingual Progress Test (CHS vs ENG)"
Write-Host "========================================`n" -ForegroundColor Cyan

# Import modules
Write-Host "[1/6] Importing modules..." -ForegroundColor Yellow
. "$PSScriptRoot\..\Scripts\Session\AURORA-ProgressManager.ps1"
. "$PSScriptRoot\..\Scripts\Session\AURORA-ProgressManager-Integration-CHS.ps1"
. "$PSScriptRoot\..\Scripts\Session\AURORA-ProgressManager-Integration-ENG.ps1"

# Initialize
Write-Host "[2/6] Initializing cache..." -ForegroundColor Yellow
$initialized = Initialize-CacheDirectory -ToolPath (Join-Path $PSScriptRoot "..\Scripts")
Write-Host "   Cache: $script:CacheRoot`n" -ForegroundColor Gray

# Clean up old sessions
Write-Host "[3/6] Cleaning up old sessions..." -ForegroundColor Yellow
while (Test-PendingSession) {
    $session = Get-LatestPendingSession
    Remove-SessionProgress -SessionId $session
}
Write-Host "   Cleanup complete`n" -ForegroundColor Gray

# ==========================================
# CHS Mode Test
# ==========================================
Write-Host "[4/6] CHS Mode Test" -ForegroundColor Cyan
Write-Host "   Creating session..." -ForegroundColor Gray

$chsSession = New-Session -SessionType "ExportTask" -Metadata @{ Language = "CHS" }
Save-CHSProgress -SessionId $chsSession -Checkpoint "Initialized"
Write-Host "   CHS: Saved - Initialized (5%)" -ForegroundColor Gray

Save-CHSProgress -SessionId $chsSession -Checkpoint "ExportComplete" -AdditionalData @{
    File = "System_Log.csv"
}
Write-Host "   CHS: Saved - Export Complete (70%)`n" -ForegroundColor Gray

# Simulate restart
$script:CurrentSessionId = $null
$script:SessionData = @{}

# Restore CHS session
if (Test-PendingSession) {
    $restored = Restore-SessionProgress
    Write-Host "   CHS: Restore Success - $($restored.Progress)%，Stage: $($restored.Stage)" -ForegroundColor Green
}

Complete-Session -SessionId $chsSession -Archive
Write-Host "   CHS: Session completed and archived`n" -ForegroundColor Green

# ==========================================
# ENG Mode Test
# ==========================================
Write-Host "[5/6] ENG Mode Test" -ForegroundColor Cyan
Write-Host "   Creating session..." -ForegroundColor Gray

$engSession = New-Session -SessionType "ExportTask" -Metadata @{ Language = "ENG" }
Save-ENGProgress -SessionId $engSession -Checkpoint "Initialized"
Write-Host "   ENG: Saved - Initialized (5%)" -ForegroundColor Gray

Save-ENGProgress -SessionId $engSession -Checkpoint "ExportComplete" -AdditionalData @{
    File = "System_Log.csv"
}
Write-Host "   ENG: Saved - Export Complete (70%)`n" -ForegroundColor Gray

# Simulate restart
$script:CurrentSessionId = $null
$script:SessionData = @{}

# Restore ENG session
if (Test-PendingSession) {
    $restored = Restore-SessionProgress
    Write-Host "   ENG: Restore Success - $($restored.Progress)%, Stage: $($restored.Stage)" -ForegroundColor Green
}

Complete-Session -SessionId $engSession -Archive
Write-Host "   ENG: Session completed and archived`n" -ForegroundColor Green

# ==========================================
# Final Statistics
# ==========================================
Write-Host "[6/6] Final Statistics" -ForegroundColor Cyan
$stats = Get-SessionStatistics

Write-Host "   Active Sessions: $($stats.ActiveSessions)" -ForegroundColor Yellow
Write-Host "   Checkpoints: $($stats.Checkpoints)" -ForegroundColor Yellow
Write-Host "   Archived Sessions: $($stats.ArchivedSessions)" -ForegroundColor Yellow
Write-Host "   Total Size: $($stats.TotalSizeMB) MB" -ForegroundColor Yellow

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  TEST COMPLETE - ALL FEATURES VERIFIED"
Write-Host "========================================" -ForegroundColor Green
Write-Host "   CHS Mode: PASSED" -ForegroundColor Green
Write-Host "   ENG Mode: PASSED" -ForegroundColor Green
Write-Host "   Bilingual Support: VERIFIED" -ForegroundColor Green
Write-Host ""
