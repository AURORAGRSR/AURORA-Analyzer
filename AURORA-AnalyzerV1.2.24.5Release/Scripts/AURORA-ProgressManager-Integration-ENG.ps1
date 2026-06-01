#===========================================
# AURORA Progress Manager Integration Module - ENG Version
# For saving progress at key nodes in PRO script
# Version：V1.2.31Release
# Author: AURORA VelociRaptor-GR Dev PRJ.
# Build Time: 2026.06.01
# ==========================================

# Define progress checkpoints (PRO mode version - supports multi-log export)
# Fully matched with AURORA-AnalyzerENGPRO.ps1
$ProgressCheckpoints = @{
    "Initialized" = @{ Progress = 5; Stage = "Script Initialized" }
    "LogTypeSelected" = @{ Progress = 10; Stage = "Log Type Selected" }
    "DateRangeConfigured" = @{ Progress = 15; Stage = "Date Range Configured" }
    "PerformanceAssessed" = @{ Progress = 25; Stage = "Performance Assessment Complete" }
    "ProcessingStarted" = @{ Progress = 45; Stage = "Starting Log Processing" }
    "HighRiskScanComplete" = @{ Progress = 60; Stage = "High Risk Scan Complete" }
    "HealthAssessmentComplete" = @{ Progress = 70; Stage = "Health Assessment Complete" }
    "ExportModeSelected" = @{ Progress = 75; Stage = "Export Mode Selected" }
    "FetchingFullLog" = @{ Progress = 75; Stage = "Fetching Full Log" }
    "FullLogFetched" = @{ Progress = 80; Stage = "Full Log Fetched" }
    "ExportStarted" = @{ Progress = 85; Stage = "Starting Export" }
    "ExportComplete" = @{ Progress = 90; Stage = "All Logs Export Complete" }
    "TrendAnalysisComplete" = @{ Progress = 93; Stage = "Trend Analysis Complete" }
    "SmartAnalysisPending" = @{ Progress = 95; Stage = "Smart Analysis Pending" }
    "SmartAnalysisComplete" = @{ Progress = 98; Stage = "Smart Analysis Complete" }
    "Completed" = @{ Progress = 100; Stage = "Task Complete" }
}

# Save progress function
function Save-ENGProgress {
    param(
        [string]$SessionId,
        [string]$Checkpoint,
        [hashtable]$AdditionalData = @{},
        [switch]$CreateCheckpoint,
        [int]$CustomProgress = -1, # Support custom progress for multi-log processing
        [string]$CustomStage = "" # Support custom stage description
    )
    
    if (-not $ProgressCheckpoints.ContainsKey($Checkpoint)) {
        Write-Warning "[ProgressManager] Unknown checkpoint: $Checkpoint"
        return
    }
    
    $checkpoint = $ProgressCheckpoints[$Checkpoint]
    
    # Determine which progress and stage to use
    $progressToUse = if ($CustomProgress -ge 0 -and $CustomProgress -le 100) { $CustomProgress } else { $checkpoint.Progress }
    $stageToUse = if (-not [string]::IsNullOrWhiteSpace($CustomStage)) { $CustomStage } else { $checkpoint.Stage }
    
    Save-SessionProgress `
        -SessionId $SessionId `
        -Stage $stageToUse `
        -Progress $progressToUse `
        -AdditionalData $AdditionalData `
        -CreateCheckpoint:$CreateCheckpoint
    
    # Sync update to GUI progress bar
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        $global:syncHash.Progress = $progressToUse
        $global:syncHash.CurrentStatus = $stageToUse
    }
    
    Write-Verbose "[ProgressManager] Saved progress: $Checkpoint ($($progressToUse)%) - $stageToUse"
}

# Export functions
# Note: This script is dot-sourced, not a real module
# All functions are automatically available in global scope
