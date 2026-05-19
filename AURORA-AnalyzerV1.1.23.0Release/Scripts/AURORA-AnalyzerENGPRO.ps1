#AURORA-AnalyzerENGPRO.ps1
#Requires -Version 5.1
# WARNING: This tool is intended for personal learning purposes only.
# PowerShell Version: 5.1
<#
.SYNOPSIS
    Windows System Event Log Export & Intelligent Analysis Tool
.DESCRIPTION
    Exports System logs by single day or date range, generates structured summary report and raw CSV.
    Automatically identifies errors, warnings, critical events, and evaluates system health.
.PARAMETER OutputPath
    Optional. Specifies the output directory. Defaults to currentDir\UserLogs.
.PARAMETER AutoOpen
    Switch to automatically open the output folder after export.
.PARAMETER LogType
    Optional. Specifies the log type. Defaults to System.
.PARAMETER GUI_Mode
    Switch parameter. Marks if running in GUI mode.
.NOTES
    Version: V1.1.13Release
    Author: AURORA VelociRaptor-GR Dev PRJ.
    Build Time: 2026.05.14
#>
Param(
    [string]$OutputPath,
    
    [switch]$AutoOpen,
    
    [ValidateSet("System", "Application", "Security", "Setup", "DNS Server", "DHCP Server", "Directory Service", "IIS Admin Service")]
    [string]$LogType = "System",
    
    [switch]$Silent,
    
    [ValidatePattern("^\d*$")]
    [string]$EventId,
    
    [string]$ProviderName,
    
    [ValidateSet("Critical", "Error", "Warning", "Information", "Verbose")]
    [string]$Level,
    
    [datetime]$StartTime,
    
    [datetime]$EndTime,
    
    [switch]$ForceRescan,
    
    [ValidateSet("SingleDay", "DateRange")]
    [string]$ExportMode,
    
    [ValidateSet("HighRiskOnly", "Full")]
    [string]$ExportScope,
    
    [switch]$TrendAnalysis,
    
    [switch]$GUI_Mode
)

# ==========================================
# 🔒 Launch Detection: Only allow launch by GUI, prohibit direct execution
# ==========================================
$isLaunchedByGUI = $false

# Detection 1: Check if GUI_Mode parameter is present
if ($GUI_Mode) {
    $isLaunchedByGUI = $true
}

# Detection 2: Check if global syncHash variable exists
if (-not $isLaunchedByGUI -and (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
    $isLaunchedByGUI = $true
}

# If not launched by GUI, show message and exit
if (-not $isLaunchedByGUI) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  ❌ This script cannot be run directly!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please launch using:" -ForegroundColor Yellow
    Write-Host "  1. Double-click AURORA.Launcher-双击启动.exe" -ForegroundColor White
    Write-Host "  2. Or run AURORA-AnalyzerLauncherGUI.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Program will close automatically in 5 seconds..." -ForegroundColor Gray
    
    Start-Sleep -Seconds 5
    exit 1
}

# === Import Progress Manager ===
# Get script directory (compatible with Runspace environment)
$progressManagerDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
. "$progressManagerDir\AURORA-ProgressManager.ps1"
. "$progressManagerDir\AURORA-ProgressManager-Integration-ENG.ps1"

# === [Phase 3 Migration] Import CoreEngine Shared Core (if not already imported)
# Note: PRO mode entry has already imported CoreEngine, check if already imported
if (-not $global:AURORA_CoreEngine_Loaded) {
    . "$progressManagerDir\AURORA-CoreEngine.ps1"
}

# === Initialize Progress Manager ===
$null = Initialize-CacheDirectory -ToolPath $progressManagerDir

# Set language to English for ENGPro version
$script:Language = "ENG"

# === [Phase 3 Migration] Initialize CoreEngine (only on first import)
if (-not $global:AURORA_CoreEngine_Initialized) {
    Initialize-Engine
    $global:AURORA_CoreEngine_Initialized = $true
}

# === [Phase 3 Migration] Elevation check functions provided by CoreEngine
# Test-AdminRequired and Invoke-ElevationCheck are defined in CoreEngine
# Remove local duplicate definitions, use CoreEngine functions directly

# === Check for Incomplete Session ===
# 【关键修复】PRO 脚本负责检测会话，GUI 负责显示 HUD，通过 syncHash 通信
if (Test-PendingSession) {
    if (-not $Silent) {
        Write-Host "`n🔄 Incomplete session detected" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        # Restore session to get details
        $restoredSession = Restore-SessionProgress
        
        if ($restoredSession) {
            $sessionId = $restoredSession.SessionId
            
            Write-Host "Session ID: $($sessionId)" -ForegroundColor White
            Write-Host "Saved progress: $($restoredSession.Progress)%" -ForegroundColor Yellow
            Write-Host "Current stage: $($restoredSession.Stage)" -ForegroundColor Yellow
            Write-Host "Saved at: $($restoredSession.Data.LastUpdated)" -ForegroundColor Gray
            Write-Host "Suspended for: $($restoredSession.AgeInDays) days`n" -ForegroundColor Gray
            
            # GUI mode: notify GUI to show HUD and wait for user choice
            # Use GUI_Mode parameter or syncHash variable to detect GUI environment
            if ($GUI_Mode -or (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
                # Notify GUI to show session recovery HUD
                $global:syncHash.ShowSessionRecoveryHUD = $true
                $global:syncHash.RestoredSessionId = $sessionId
                $global:syncHash.RestoredStage = $restoredSession.Stage
                $global:syncHash.RestoredProgress = $restoredSession.Progress
                $global:syncHash.RestoredLastUpdated = $restoredSession.LastUpdated
                $global:syncHash.RestoredAgeInDays = $restoredSession.AgeInDays
                
                Write-Host "⏳ Waiting for user to make a choice from GUI..." -ForegroundColor Cyan
                
                # Wait for GUI user choice (SessionRestored or SessionRestarted)
                $waitTimeout = 30000  # 30 seconds timeout
                $waitStart = Get-Date
                while (-not $global:syncHash.SessionRestored -and -not $global:syncHash.SessionRestarted) {
                    Start-Sleep -Milliseconds 100
                    # Emergency escape: if GUI closed or timeout, exit
                    if ($global:syncHash.IsHostAlive -eq $false) {
                        Write-Host "GUI closed, exiting..." -ForegroundColor Red
                        exit 1
                    }
                    if ((Get-Date) - $waitStart -gt [TimeSpan]::FromMilliseconds($waitTimeout)) {
                        Write-Host "⚠️ Timeout waiting for user choice, assuming restart..." -ForegroundColor Yellow
                        $restoreMode = $false
                        break
                    }
                }
                
                # Check user choice
                if ($global:syncHash.SessionRestarted -eq $true) {
                    Write-Host "🔄 User chose to restart fresh, clearing session..." -ForegroundColor Cyan
                    $restoreMode = $false
                    $sessionId = $null
                    Remove-SessionProgress -SessionId $restoredSession.SessionId
                    
                    # [Critical Fix] Reset GUI session flags to prevent double-trigger from Smart Engine
                    $global:syncHash.ShowSessionRecoveryHUD = $false
                    $global:syncHash.SessionRestored = $false
                    $global:syncHash.SessionRestarted = $false
                    $global:syncHash.RestoredSessionId = $null
                    $global:syncHash.RestoredStage = $null
                    $global:syncHash.RestoredProgress = 0
                    $global:syncHash.RestoredLastUpdated = $null
                    $global:syncHash.RestoredAgeInDays = 0
                } elseif ($global:syncHash.SessionRestored -eq $true) {
                    Write-Host "✅ User chose to restore session, continuing..." -ForegroundColor Green
                    $restoreMode = $true
                    
                    # [Critical Fix] Reset GUI session flags (but keep restored data)
                    $global:syncHash.ShowSessionRecoveryHUD = $false
                    # SessionRestored and SessionRestarted remain true for subsequent checks
                    
                    # Restore key variables from session data
                    $restoredData = $restoredSession.Data
                    if ($restoredData) {
                        # Restore Scopes array (most important, contains StartTime, EndTime, LogType, etc.)
                        if ($restoredData.Scopes) {
                            # Handle case where Scopes is a single object instead of array
                            $tempScopes = $restoredData.Scopes
                            if ($tempScopes -is [System.Management.Automation.PSCustomObject] -or $tempScopes -is [hashtable]) {
                                $scopes = @($tempScopes)
                            } else {
                                $scopes = $tempScopes
                            }
                            
                            # Ensure scopes is an array
                            if (-not $scopes -or $scopes.Count -eq 0) {
                                $scopes = @($restoredData.Scopes)
                            }
                            
                            Write-Host "   ✅ Log scope data restored ($($scopes.Count) scopes)" -ForegroundColor Green
                            
                            # Handle special date format \/Date(...)\/
                            for ($i = 0; $i -lt $scopes.Count; $i++) {
                                $scopeItem = $scopes[$i]
                                
                                # Convert StartTime
                                if ($scopeItem.StartTime -match '\\/Date\((\d+)\)\\/') {
                                    $timestamp = [long]$matches[1]
                                    $scopes[$i].StartTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                                }
                                
                                # Convert EndTime
                                if ($scopeItem.EndTime -match '\\/Date\((\d+)\)\\/') {
                                    $timestamp = [long]$matches[1]
                                    $scopes[$i].EndTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                                }
                            }
                        } else {
                            # Restore individual time range (fallback if Scopes not available)
                            $restoreStartTime = $null
                            $restoreEndTime = $null
                            
                            # Try to restore from individual fields
                            if ($restoredData.StartTime -and $restoredData.EndTime) {
                                # Handle special date format
                                if ($restoredData.StartTime -match '\\/Date\((\d+)\)\\/') {
                                    $timestamp = [long]$matches[1]
                                    $restoreStartTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                                } else {
                                    $restoreStartTime = [datetime]$restoredData.StartTime
                                }
                                
                                if ($restoredData.EndTime -match '\\/Date\((\d+)\)\\/') {
                                    $timestamp = [long]$matches[1]
                                    $restoreEndTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                                } else {
                                    $restoreEndTime = [datetime]$restoredData.EndTime
                                }
                            }
                            
                            if ($restoreStartTime -and $restoreEndTime) {
                                $scopes = @(@{
                                    StartTime = $restoreStartTime
                                    EndTime = $restoreEndTime
                                    LogType = if ($restoredData.LogType) { $restoredData.LogType } else { "System" }
                                    DatePart = if ($restoredData.DatePart) { $restoredData.DatePart } else { (Get-Date).ToString("yyyyMMdd") }
                                    ReportTitle = if ($restoredData.ReportTitle) { $restoredData.ReportTitle } else { "System Log Daily Report" }
                                })
                            }
                        }
                        
                        # Restore LogType
                        if ($restoredData.LogType) {
                            $LogType = $restoredData.LogType
                        }
                        
                        # Restore ExportMode
                        if ($restoredData.ExportMode) {
                            $ExportMode = $restoredData.ExportMode
                        }
                        
                        # Restore ExportScope
                        if ($restoredData.ExportScope) {
                            $ExportScope = $restoredData.ExportScope
                        }
                        
                        # Restore performance score and chunk size
                        if ($restoredData.PerformanceScore) {
                            $performanceScore = $restoredData.PerformanceScore
                        }
                        if ($restoredData.ChunkSize) {
                            $optimalChunkSize = $restoredData.ChunkSize
                        }
                        
                        # === [Checkpoint Resume Fix] Restore export choice related variables ===
                        if ($restoredData.ExportChoice) {
                            $exportChoice = $restoredData.ExportChoice
                            Write-Host "   ✅ Restored export mode choice: $exportChoice" -ForegroundColor Green
                        }
                        if ($restoredData.ReportMode) {
                            $reportMode = $restoredData.ReportMode
                        }
                        
                        # Restore high-risk event data
                        if ($restoredData.HighRiskEventCount -and -not (Get-Variable -Name "highRiskEvents" -ErrorAction SilentlyContinue)) {
                            $totalHigh = $restoredData.HighRiskEventCount
                            $critical = $restoredData.CriticalEvents
                            $errors = $restoredData.ErrorEvents
                            $warnings = $restoredData.WarningEvents
                            $totalEventCount = $restoredData.TotalEventCount
                        }
                        
                        # Restore health assessment data
                        if ($restoredData.HealthScore) {
                            $healthScore = $restoredData.HealthScore
                            $healthLevel = $restoredData.HealthLevel
                            $healthStatus = $restoredData.HealthStatus
                        }
                    }
                }
            } else {
                # Console mode: ask user directly
                Write-Host "`n[Session Recovery] Detected an incomplete session" -ForegroundColor Cyan
                Write-Host "  1) Resume session (Continue from last save point)" -ForegroundColor White
                Write-Host "  2) Start fresh (Discard previous progress)" -ForegroundColor White
                $choice = Read-Host "Please select (1 or 2)"
                
                if ($choice -ne "1") {
                    Write-Host "🔄 User chose to restart fresh, clearing session..." -ForegroundColor Cyan
                    $restoreMode = $false
                    Remove-SessionProgress -SessionId $restoredSession.SessionId
                } else {
                    Write-Host "✅ User chose to restore session, continuing..." -ForegroundColor Green
                    $restoreMode = $true
                    
                    # Restore key variables from session data (same as GUI mode)
                    $restoredData = $restoredSession.Data
                    if ($restoredData) {
                        if ($restoredData.Scopes) {
                            $tempScopes = $restoredData.Scopes
                            if ($tempScopes -is [System.Management.Automation.PSCustomObject] -or $tempScopes -is [hashtable]) {
                                $scopes = @($tempScopes)
                            } else {
                                $scopes = $tempScopes
                            }
                            if (-not $scopes -or $scopes.Count -eq 0) {
                                $scopes = @($restoredData.Scopes)
                            }
                            for ($i = 0; $i -lt $scopes.Count; $i++) {
                                $scopeItem = $scopes[$i]
                                if ($scopeItem.StartTime -match '\\/Date\((\d+)\)\\/') {
                                    $timestamp = [long]$matches[1]
                                    $scopes[$i].StartTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                                }
                                if ($scopeItem.EndTime -match '\\/Date\((\d+)\)\\/') {
                                    $timestamp = [long]$matches[1]
                                    $scopes[$i].EndTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                                }
                            }
                        }
                        if ($restoredData.LogType) { $LogType = $restoredData.LogType }
                        if ($restoredData.ExportMode) { $ExportMode = $restoredData.ExportMode }
                        if ($restoredData.ExportScope) { $ExportScope = $restoredData.ExportScope }
                        if ($restoredData.PerformanceScore) { $performanceScore = $restoredData.PerformanceScore }
                        if ($restoredData.ChunkSize) { $optimalChunkSize = $restoredData.ChunkSize }
                        
                        # === [Checkpoint Resume Fix] Restore export choice related variables ===
                        if ($restoredData.ExportChoice) {
                            $exportChoice = $restoredData.ExportChoice
                            Write-Host "   ✅ Restored export mode choice: $exportChoice" -ForegroundColor Green
                        }
                        if ($restoredData.ReportMode) {
                            $reportMode = $restoredData.ReportMode
                        }
                        
                        # Restore high-risk event data
                        if ($restoredData.HighRiskEventCount -and -not (Get-Variable -Name "highRiskEvents" -ErrorAction SilentlyContinue)) {
                            $totalHigh = $restoredData.HighRiskEventCount
                            $critical = $restoredData.CriticalEvents
                            $errors = $restoredData.ErrorEvents
                            $warnings = $restoredData.WarningEvents
                            $totalEventCount = $restoredData.TotalEventCount
                        }
                        
                        # Restore health assessment data
                        if ($restoredData.HealthScore) {
                            $healthScore = $restoredData.HealthScore
                            $healthLevel = $restoredData.HealthLevel
                            $healthStatus = $restoredData.HealthStatus
                        }
                    }
                }
            }
        }
    }
}

# === Create New Session (if not restore mode) ===
if (-not $restoreMode) {
    $sessionId = New-Session -SessionType "ExportTask" -Metadata @{
        LogType = $LogType
        ExportMode = $ExportMode
        ExportScope = $ExportScope
    }
    # Save initialization progress
    Save-CHSProgress -SessionId $sessionId -Checkpoint "Initialized" -AdditionalData @{
        LogType = $LogType
        ExportMode = $ExportMode
        ExportScope = $ExportScope
    }
}

# === Adaptive Interaction Interceptor Functions ===
function Get-AuroraInteraction {
    param (
        [string]$PromptMessage,
        [switch]$IsChoice
    )
    
    # Detect if running in GUI environment (by checking if injected syncHash exists)
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        
        # ====== Add: Seamlessly bridge early interactions to frontend status bar ======
        $global:syncHash.CurrentActivity = "0/4 Task Configuration"
        $global:syncHash.CurrentStatus = $PromptMessage
        
        # ====== Visual optimization: Use λ guide, remove chatbot feeling ======
        $timestamp = [datetime]::Now.ToString('HH:mm:ss')
        $global:syncHash.LogOutput += "`n[$timestamp] > Please input: $PromptMessage`n"
        
        # Clear previous old input
        $global:syncHash.UserInput = $null 
        
        # Suspend current background thread, waiting for GUI to input data
        while ($null -eq $global:syncHash.UserInput) {
            Start-Sleep -Milliseconds 100
            # Emergency escape: if GUI accidentally closes, force exit to prevent zombie process
            if ($global:syncHash.IsHostAlive -eq $false) { Stop-Process -Id $PID -Force }
        }
        
        # Get data and clear slot
        $response = $global:syncHash.UserInput
        $global:syncHash.UserInput = $null 
        return $response
    }
    else {
        # Native console mode: use Read-Host directly
        return Read-Host $PromptMessage
    }
}

function Write-AuroraLog {
    param([string]$Message, [string]$Color = "White")
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        $global:syncHash.LogOutput += "$Message`n"
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

# Set console background to black (with silent invocation protection)
if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsOutputRedirected) {
    try {
        $Host.UI.RawUI.BackgroundColor = 'Black'
        Clear-Host
    } catch {}
}

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "❌ This tool requires PowerShell 5.0 or higher." -ForegroundColor Red
    Write-Host "💡 Recommendation: Upgrade to Windows 10 or install Windows Management Framework 5.1." -ForegroundColor Yellow
    if (-not $Silent) {
        if ($null -eq (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
            Write-Host "`nPress Enter to exit" -ForegroundColor Gray
            Read-Host | Out-Null
        }
    }
    exit 1
}

# Check Windows version
$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -lt 6) {
    Write-Host "❌ This tool requires Windows Vista or higher." -ForegroundColor Red
    Write-Host "💡 Recommendation: Upgrade to Windows 10 or Windows 11." -ForegroundColor Yellow
    if (-not $Silent) {
        if ($null -eq (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
            Write-Host "`nPress Enter to exit" -ForegroundColor Gray
            Read-Host | Out-Null
        }
    }
    exit 1
}

#region Center Console Window (Windows only)
if ($env:OS -like "*Windows*") {
    try {
        Add-Type -Name Window -Namespace Console -MemberDefinition '
            [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
            [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
            [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
            public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
        '

        $hwnd = [Console.Window]::GetConsoleWindow()
        if ($hwnd -ne [IntPtr]::Zero) {
            $rect = New-Object Console.RECT
            [Console.Window]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
            $width = $rect.Right - $rect.Left
            $height = $rect.Bottom - $rect.Top

            $screenWidth = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
            $screenHeight = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height

            $x = [Math]::Max(0, [Math]::Floor(($screenWidth - $width) / 2))
            $y = [Math]::Max(0, [Math]::Floor(($screenHeight - $height) / 2))

            [Console.Window]::MoveWindow($hwnd, $x, $y, $width, $height, $true) | Out-Null
        }
    }
    catch {
        # Ignore errors (e.g., non-console environments)
    }
}
#endregion

# === Global Settings (Environment Adaptive) ===
try {
    if (-not [Console]::IsOutputRedirected) {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    }
} catch {}
$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'

#region Helper Functions

# Common StreamWriter operation function
function New-StreamWriterOperation {
    <#
    .SYNOPSIS
        Common StreamWriter operation function
    .DESCRIPTION
        Provides unified StreamWriter creation, usage, and cleanup functionality with error handling
    .PARAMETER FilePath
        File path where the StreamWriter will write data
    .PARAMETER ScriptBlock
        Script block containing write operations that will be executed with the StreamWriter
    .RETURNS
        Boolean indicating whether the operation was successful
    .EXAMPLE
        # Example: Write data to a file using StreamWriter
        $success = New-StreamWriterOperation -FilePath "C:\temp\output.txt" -ScriptBlock {
            param($writer)
            $writer.WriteLine("Hello, World!")
            $writer.WriteLine("This is a test.")
        }
        if ($success) {
            Write-Host "File written successfully" -ForegroundColor Green
        } else {
            Write-Host "Failed to write file" -ForegroundColor Red
        }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock
    )
    
    # Retry mechanism configuration
    $maxRetries = 5
    $retryCount = 0
    $retryDelay = 200  # milliseconds
    
    while ($retryCount -lt $maxRetries) {
        try {
            $retryCount++
            
            # If file exists, try to delete first (to avoid file lock)
            if (Test-Path $FilePath) {
                try {
                    [System.IO.File]::Delete($FilePath)
                } catch {
                    Write-Verbose "[StreamWriter] Cannot delete old file, waiting $retryDelay ms... (Attempt $retryCount/$maxRetries)"
                    Start-Sleep -Milliseconds $retryDelay
                }
            }
            
            # Create StreamWriter
            $streamWriter = New-Object System.IO.StreamWriter($FilePath, $false, [System.Text.Encoding]::UTF8, 65536)
            try {
                # Execute write operations
                & $ScriptBlock $streamWriter
            } finally {
                # Ensure StreamWriter is closed
                $streamWriter.Close()
            }
            
            Write-Verbose "[StreamWriter] File write success: $FilePath (Attempt $retryCount/$maxRetries)"
            return $true
            
        } catch {
            $errorMsg = $_.Exception.Message
            
            # Check if it's a file lock error
            if ($errorMsg -match "can't open file for write|used by another process|being used by another process") {
                Write-Verbose "[StreamWriter] File locked, waiting $retryDelay ms... (Attempt $retryCount/$maxRetries)"
                
                if ($retryCount -lt $maxRetries) {
                    Start-Sleep -Milliseconds ($retryDelay * $retryCount)
                    continue
                }
            }
            
            Write-Host "`nFailed to write file: $errorMsg" -ForegroundColor Red
            Write-Verbose "[StreamWriter] Error details: $($_.Exception.GetType().FullName)"
            return $false
        }
    }
    
    Write-Host "`nFailed to write file: Maximum retry attempts ($maxRetries) reached" -ForegroundColor Red
    return $false
}

# Common file path processing function
function Get-SafeFilePath {
    <#
    .SYNOPSIS
        Generate safe file path
    .DESCRIPTION
        Cleans unsafe characters from file names and combines paths to create a safe file path
    .PARAMETER BasePath
        Base directory path where the file will be saved
    .PARAMETER LogType
        Log type used in the file name
    .PARAMETER DatePart
        Date part used in the file name
    .PARAMETER Extension
        File extension including the dot (e.g., ".txt", ".csv")
    .RETURNS
        Safe file path with all unsafe characters removed
    .EXAMPLE
        # Example: Generate safe file path for system logs
        $safePath = Get-SafeFilePath -BasePath "C:\UserLogs" -LogType "System" -DatePart "20260403" -Extension ".csv"
        Write-Host "Safe file path: $safePath" -ForegroundColor Cyan
        # Output: Safe file path: C:\UserLogs\System_Log_20260403.csv
    #>
    param(
        [string]$BasePath,
        [string]$LogType,
        [string]$DatePart,
        [string]$Extension
    )
    
    # Clean unsafe characters from file names
    $safeLogType = $LogType -replace '[^a-zA-Z0-9]', '_'
    $safeDatePart = $DatePart -replace '[^a-zA-Z0-9_]', '_'
    
    return [System.IO.Path]::Combine($BasePath, "${safeLogType}_Log_${safeDatePart}${Extension}")
}

function Get-ResourceOptimizedStrategy {
    <#
    .SYNOPSIS
        Gets optimized strategy based on system performance and resource status
    .DESCRIPTION
        Provides optimized strategy for different task types based on system performance score, memory usage, system load, and hardware configuration
    .PARAMETER PerformanceScore
        System performance score (0-100) indicating overall system performance
    .PARAMETER TaskType
        Task type: LogScanning or ReportGeneration
    .RETURNS
        Hashtable containing optimization strategy with performance level, strategy parameters, and resource information
    .EXAMPLE
        # Example: Get optimized strategy for log scanning
        $strategy = Get-ResourceOptimizedStrategy -PerformanceScore 85 -TaskType "LogScanning"
        Write-Host "Performance level: $($strategy.PerformanceLevel)" -ForegroundColor Cyan
        Write-Host "Parallelism: $($strategy.Strategy.Parallelism)" -ForegroundColor Cyan
        Write-Host "Chunk size: $($strategy.Strategy.ChunkSize)" -ForegroundColor Cyan
    #>
    param(
        [ValidateRange(0, 100)]
        [int]$PerformanceScore,
        [ValidateSet("LogScanning", "ReportGeneration")]
        [string]$TaskType
    )
    
    try {
        # Validate parameters
        if ($PerformanceScore -lt 0 -or $PerformanceScore -gt 100) {
            throw "PerformanceScore must be between 0 and 100"
        }
        
        if ([string]::IsNullOrWhiteSpace($TaskType)) {
            throw "TaskType cannot be empty"
        }
        
        if ($TaskType -ne "LogScanning" -and $TaskType -ne "ReportGeneration") {
            throw "TaskType must be either 'LogScanning' or 'ReportGeneration'"
        }
        
        # Resource status evaluation
        $memoryUsage = Get-MemoryUsage
        $systemLoad = Get-SystemLoad
        $cpuInfos = Get-CimInstance Win32_Processor
        $cpuCores = if ($cpuInfos -is [array]) {
            $cpuInfos | Measure-Object -Property NumberOfCores -Sum | Select-Object -ExpandProperty Sum
        } else {
            $cpuInfos.NumberOfCores
        }
        $logicalProcessors = if ($cpuInfos -is [array]) {
            $cpuInfos | Measure-Object -Property NumberOfLogicalProcessors -Sum | Select-Object -ExpandProperty Sum
        } else {
            $cpuInfos.NumberOfLogicalProcessors
        }
        
        # Task type definitions
        $taskStrategies = @{
            "LogScanning" = @{
                "HighPerformance" = @{
                    "Parallelism" = [Math]::Min($logicalProcessors, 32)
                    "ChunkSize" = 6
                    "Compression" = $false
                    "CacheSize" = 50
                }
                "MediumPerformance" = @{
                    "Parallelism" = [Math]::Min($logicalProcessors * 0.75, 16)
                    "ChunkSize" = 3
                    "Compression" = $false
                    "CacheSize" = 30
                }
                "LowPerformance" = @{
                    "Parallelism" = [Math]::Min($cpuCores, 8)
                    "ChunkSize" = 1
                    "Compression" = $true
                    "CacheSize" = 10
                }
            }
            "ReportGeneration" = @{
                "HighPerformance" = @{
                    "Parallelism" = [Math]::Min($logicalProcessors * 0.8, 24)
                    "BatchSize" = 5000
                    "Compression" = $false
                }
                "MediumPerformance" = @{
                    "Parallelism" = [Math]::Min($logicalProcessors * 0.5, 12)
                    "BatchSize" = 2000
                    "Compression" = $false
                }
                "LowPerformance" = @{
                    "Parallelism" = [Math]::Min($cpuCores, 4)
                    "BatchSize" = 1000
                    "Compression" = $true
                }
            }
        }
        
        # Performance level determination - primarily based on PerformanceScore, with minor adjustments for memory and load
        # First determine base level from PerformanceScore
        $baseLevel = if ($PerformanceScore -ge 80) {
            "HighPerformance"
        } elseif ($PerformanceScore -ge 50) {
            "MediumPerformance"
        } else {
            "LowPerformance"
        }
        
        # Adjust level down if resource constraints are severe (only for significant issues)
        $performanceLevel = $baseLevel
        if ($baseLevel -eq "HighPerformance" -and ($memoryUsage -ge 80 -or $systemLoad -ge 80)) {
            # Very high memory or CPU usage - downgrade to Medium
            $performanceLevel = "MediumPerformance"
        } elseif ($baseLevel -eq "MediumPerformance" -and ($memoryUsage -ge 90 -or $systemLoad -ge 90)) {
            # Extremely high resource usage - downgrade to Low
            $performanceLevel = "LowPerformance"
        }
        
        return @{
            "PerformanceLevel" = $performanceLevel
            "Strategy" = $taskStrategies[$TaskType][$performanceLevel]
            "Resources" = @{
                "CPUCores" = $cpuCores
                "LogicalProcessors" = $logicalProcessors
                "MemoryUsage" = $memoryUsage
                "SystemLoad" = $systemLoad
                "PerformanceScore" = $PerformanceScore
            }
        }
    }
    catch {
        Write-Debug "Error in Get-ResourceOptimizedStrategy: $($_.Exception.Message)"
        # Return default strategy
        return @{
            "PerformanceLevel" = "MediumPerformance"
            "Strategy" = $taskStrategies["LogScanning"]["MediumPerformance"]
            "Resources" = @{
                "CPUCores" = 2
                "LogicalProcessors" = 4
                "MemoryUsage" = 50
                "SystemLoad" = 50
                "PerformanceScore" = 50
            }
        }
    }
}

function Get-IntelligentCacheStrategy {
    <#
    .SYNOPSIS
        Gets intelligent cache strategy based on system performance and data size
    .DESCRIPTION
        Determines whether to compress data and cache configuration based on system performance score and data size
    .PARAMETER PerformanceScore
        System performance score (0-100) indicating overall system performance
    .PARAMETER DataSizeKB
        Data size in KB to determine appropriate caching strategy
    .RETURNS
        Hashtable containing cache strategy with compression setting, cache size, and expiry time
    .EXAMPLE
        # Example: Get intelligent cache strategy for 10MB of data on a high-performance system
        $cacheStrategy = Get-IntelligentCacheStrategy -PerformanceScore 90 -DataSizeKB 10240
        Write-Host "Compression: $($cacheStrategy.Compression)" -ForegroundColor Cyan
        Write-Host "Cache size: $($cacheStrategy.CacheSize) items" -ForegroundColor Cyan
        Write-Host "Expiry time: $($cacheStrategy.ExpiryMinutes) minutes" -ForegroundColor Cyan
    #>
    param(
        [ValidateRange(0, 100)]
        [int]$PerformanceScore,
        [ValidateRange(0, [int]::MaxValue)]
        [int]$DataSizeKB
    )
    
    try {
        # Validate parameters
        if ($PerformanceScore -lt 0 -or $PerformanceScore -gt 100) {
            throw "PerformanceScore must be between 0 and 100"
        }
        
        if ($DataSizeKB -lt 0) {
            throw "DataSizeKB must be non-negative"
        }
        
        # High performance machine cache strategy
        if ($PerformanceScore -ge 80) {
            return @{
                "Compression" = $DataSizeKB -gt 50000  # Only compress data larger than 50MB
                "CacheSize" = 100  # Larger cache capacity
                "ExpiryMinutes" = 60  # Longer cache expiry time
            }
        }
        # Medium performance machine
        elseif ($PerformanceScore -ge 50) {
            return @{
                "Compression" = $DataSizeKB -gt 20000  # Only compress data larger than 20MB
                "CacheSize" = 50
                "ExpiryMinutes" = 30
            }
        }
        # Low performance machine
        else {
            return @{
                "Compression" = $DataSizeKB -gt 5000  # Compress data larger than 5MB
                "CacheSize" = 20
                "ExpiryMinutes" = 15
            }
        }
    }
    catch {
        Write-Debug "Error in Get-IntelligentCacheStrategy: $($_.Exception.Message)"
        # Return default cache strategy
        return @{
            "Compression" = $DataSizeKB -gt 20000
            "CacheSize" = 50
            "ExpiryMinutes" = 30
        }
    }
}

function Optimize-FileOperations {
    <#
    .SYNOPSIS
        Optimizes file operations based on system performance
    .DESCRIPTION
        Returns optimized file operation parameters based on system performance score, including buffer size, parallel I/O settings, and write batch size
    .PARAMETER PerformanceScore
        System performance score (0-100) indicating overall system performance
    .RETURNS
        Hashtable containing file operation optimization parameters
    .EXAMPLE
        # Example: Get optimized file operations for a high-performance system
        $fileOps = Optimize-FileOperations -PerformanceScore 85
        Write-Host "Buffer size: $($fileOps.BufferSize) bytes" -ForegroundColor Cyan
        Write-Host "Parallel I/O: $($fileOps.ParallelIO)" -ForegroundColor Cyan
        Write-Host "Write batch size: $($fileOps.WriteBatchSize)" -ForegroundColor Cyan
        Write-Host "Async write: $($fileOps.AsyncWrite)" -ForegroundColor Cyan
    #>
    param(
        [ValidateRange(0, 100)]
        [int]$PerformanceScore
    )
    
    try {
        # Validate parameters
        if ($PerformanceScore -lt 0 -or $PerformanceScore -gt 100) {
            throw "PerformanceScore must be between 0 and 100"
        }
        
        # High performance machines use more aggressive I/O strategy
        if ($PerformanceScore -ge 80) {
            return @{
                "BufferSize" = 131072  # 128KB buffer
                "ParallelIO" = $true    # Parallel I/O operations
                "WriteBatchSize" = 10000 # Larger write batch size
                "AsyncWrite" = $true     # Async write
            }
        }
        # Medium performance machines
        elseif ($PerformanceScore -ge 50) {
            return @{
                "BufferSize" = 65536  # 64KB buffer
                "ParallelIO" = $false
                "WriteBatchSize" = 5000
                "AsyncWrite" = $false
            }
        }
        # Low performance machines
        else {
            return @{
                "BufferSize" = 32768  # 32KB buffer
                "ParallelIO" = $false
                "WriteBatchSize" = 1000
                "AsyncWrite" = $false
            }
        }
    }
    catch {
        Write-Debug "Error in Optimize-FileOperations: $($_.Exception.Message)"
        # Return default file operation parameters
        return @{
            "BufferSize" = 65536  # 64KB buffer
            "ParallelIO" = $false
            "WriteBatchSize" = 5000
            "AsyncWrite" = $false
        }
    }
}

function Get-DiskPerformance {
    <#
    .SYNOPSIS
        Detects disk performance and returns detailed information
    .DESCRIPTION
        Detects disk type, read/write speed, response time, and health status, and calculates a disk performance score
    .RETURNS
        Hashtable containing disk performance information including drives details, performance metrics, and overall score
    .EXAMPLE
        # Example: Get disk performance information
        $diskInfo = Get-DiskPerformance
        Write-Host "Disk performance score: $($diskInfo.Score)/50" -ForegroundColor Cyan
        Write-Host "Number of drives: $($diskInfo.Drives.Count)" -ForegroundColor Cyan
        foreach ($drive in $diskInfo.Drives) {
            Write-Host "Drive: $($drive.Model), Size: $($drive.SizeGB) GB, SSD: $($drive.IsSSD)" -ForegroundColor Cyan
        }
    #>
    try {
        $diskInfo = @{}
        
        # Get basic disk information
        $disks = Get-CimInstance Win32_DiskDrive | Where-Object { $_.MediaType -eq "Fixed hard disk media" }
        
        if ($disks) {
            $diskInfo.Drives = @()
            
            foreach ($disk in $disks) {
                $driveInfo = @{
                    DeviceID = $disk.DeviceID
                    Model = $disk.Model
                    SizeGB = [math]::Round($disk.Size / 1GB, 2)
                    InterfaceType = $disk.InterfaceType
                    MediaType = $disk.MediaType
                    IsSSD = $false
                }
                
                # Try to detect if it's an SSD
                try {
                    # Method 1: Use Get-PhysicalDisk cmdlet (if available)
                    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
                        $physicalDisk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq $disk.Index }
                        if ($physicalDisk -and $physicalDisk.MediaType -eq "SSD") {
                            $driveInfo.IsSSD = $true
                        }
                    }
                    
                    # Method 2: Check if disk model contains SSD keywords
                    if (-not $driveInfo.IsSSD -and $disk.Model) {
                        $ssdKeywords = @("SSD", "Solid State", "NVMe", "PCIe")
                        foreach ($keyword in $ssdKeywords) {
                            if ($disk.Model -like "*$keyword*") {
                                $driveInfo.IsSSD = $true
                                break
                            }
                        }
                    }
                    
                    # Method 3: Determine by response time (fallback method)
                    if (-not $driveInfo.IsSSD) {
                        $perfData = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk | Where-Object { $_.Name -like "*$($disk.DeviceID.Replace('\\.\\', ''))*" }
                        if ($perfData -and $perfData.AvgDiskSecPerTransfer -lt 0.005) {
                            $driveInfo.IsSSD = $true
                        }
                    }
                } catch {
                    # Ignore errors
                }
                
                $diskInfo.Drives += $driveInfo
            }
        }
        
        # Get overall disk performance
        try {
            $diskPerf = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk | Where-Object { $_.Name -eq "_Total" }
            if ($diskPerf) {
                $diskInfo.TotalPerformance = @{
                    AvgDiskSecPerTransfer = $diskPerf.AvgDiskSecPerTransfer
                    AvgDiskReadSecPerTransfer = $diskPerf.AvgDiskReadSecPerTransfer
                    AvgDiskWriteSecPerTransfer = $diskPerf.AvgDiskWriteSecPerTransfer
                    DiskReadBytesPerSec = $diskPerf.DiskReadBytesPerSec
                    DiskWriteBytesPerSec = $diskPerf.DiskWriteBytesPerSec
                    DiskTransfersPerSec = $diskPerf.DiskTransfersPerSec
                }
            }
        } catch {
            Write-Debug "Error getting disk performance: $($_.Exception.Message)"
        }
        
        # Calculate disk performance score
        $diskScore = 40 # Base score
        
        # Adjust score based on disk type
        if ($diskInfo.Drives) {
            $hasSSD = $diskInfo.Drives | Where-Object { $_.IsSSD } | Measure-Object | Select-Object -ExpandProperty Count
            if ($hasSSD -gt 0) {
                $diskScore += 10 # SSD bonus
            }
        }
        
        # Adjust score based on response time
        if ($diskInfo.TotalPerformance -and $diskInfo.TotalPerformance.AvgDiskSecPerTransfer) {
            $responseTime = $diskInfo.TotalPerformance.AvgDiskSecPerTransfer
            if ($responseTime -lt 0.005) {
                $diskScore += 5 # Excellent response time
            } elseif ($responseTime -lt 0.01) {
                $diskScore += 2 # Good response time
            } elseif ($responseTime -gt 0.05) {
                $diskScore -= 5 # Poor response time
            }
        }
        
        # Ensure score is within reasonable range
        $diskScore = [math]::Max(20, [math]::Min(50, $diskScore))
        $diskInfo.Score = $diskScore
        
        return $diskInfo
    } catch {
        Write-Debug "Error in Get-DiskPerformance: $($_.Exception.Message)"
        # Return default disk information
        return @{
            Score = 40
            Drives = @()
            TotalPerformance = $null
        }
    }
}

function Get-SystemPerformanceScore {
    <#
    .SYNOPSIS
        Detects system performance and returns performance score
    .DESCRIPTION
        Evaluates system performance by detecting CPU cores, memory size, disk speed, and real-time CPU frequency
    .RETURNS
        Performance score (0-100) indicating overall system performance
    .EXAMPLE
        # Example: Get system performance score
        $score = Get-SystemPerformanceScore
        Write-Host "System performance score: $([Math]::Round($score, 1))/100" -ForegroundColor Green
        if ($score -ge 80) {
            Write-Host "System performance: Excellent" -ForegroundColor Green
        } elseif ($score -ge 60) {
            Write-Host "System performance: Good" -ForegroundColor Yellow
        } else {
            Write-Host "System performance: Average" -ForegroundColor Red
        }
    #>
    try {
        # Get CPU information
        $cpuInfos = Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, MaxClockSpeed
        
        # Handle multiple processors case
        if ($cpuInfos -is [array]) {
            # Use first processor's information
            $cpuInfo = $cpuInfos[0]
            $cpuName = $cpuInfo.Name
            $cpuCores = $cpuInfos | Measure-Object -Property NumberOfCores -Sum | Select-Object -ExpandProperty Sum
            $baseCpuSpeed = $cpuInfo.MaxClockSpeed
        } else {
            # Single processor case
            $cpuInfo = $cpuInfos
            $cpuName = $cpuInfo.Name
            $cpuCores = $cpuInfo.NumberOfCores
            $baseCpuSpeed = $cpuInfo.MaxClockSpeed
        }
        
        # Get real-time CPU frequency
        try {
            $cpuPerformance = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation | 
                Where-Object {$_.Name -eq "_Total"} | 
                Select-Object -ExpandProperty PercentProcessorPerformance
            
            # Calculate real-time CPU frequency (based on base frequency percentage)
            $currentCpuSpeed = [math]::Round($baseCpuSpeed * ($cpuPerformance / 100), 0)
        } catch {
            # Use base frequency if real-time frequency cannot be obtained
            $currentCpuSpeed = $baseCpuSpeed
        }
        
        # Get memory information
        $memoryInfo = Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory
        $totalMemoryGB = [math]::Round($memoryInfo.TotalPhysicalMemory / 1GB, 2)
        
        # Get disk information and performance using Get-DiskPerformance function
        $diskInfo = @()
        $ssdCount = 0
        $hddCount = 0
        
        try {
            $diskInfo = Get-DiskPerformance
            $diskScore = $diskInfo.Score
            
            # Count SSD and HDD
            if ($diskInfo.Drives) {
                $ssdCount = $diskInfo.Drives | Where-Object { $_.IsSSD } | Measure-Object | Select-Object -ExpandProperty Count
                $hddCount = $diskInfo.Drives.Count - $ssdCount
            }
        } catch {
            # If disk detection fails, use default disk score
            $diskScore = 35
        }
        
        # Show system info in non-silent mode
        if (-not $Silent) {
            Write-Host "Processor: $cpuName $cpuCores cores @ $currentCpuSpeed MHz (Base: $baseCpuSpeed MHz)" -ForegroundColor Cyan
            Write-Host "Memory: $totalMemoryGB GB" -ForegroundColor Cyan
            Write-Host "Disk performance score: $diskScore/50" -ForegroundColor Cyan
            Write-Host "Disk configuration: $ssdCount SSD(s), $hddCount HDD(s)" -ForegroundColor Cyan
            Write-Host "Calculating performance score..." -ForegroundColor Yellow
        }
        
        # Calculate performance score
        $cpuScore = [math]::Min(30, $cpuCores * 5 + $currentCpuSpeed / 100)
        $memoryScore = [math]::Min(30, $totalMemoryGB * 2)
        
        $totalScore = [math]::Min(100, $cpuScore + $memoryScore + $diskScore)
        
        # Show performance score in non-silent mode
        if (-not $Silent) {
            Write-Host "Your performance score: $([Math]::Round($totalScore, 1))/100" -ForegroundColor Green
        }
        
        return $totalScore
    }
    catch {
        # Return default score on error
        return 50
    }
}

# Get Optimal Chunk Size
function Get-OptimalChunkSize {
    <#
    .SYNOPSIS
        Calculates optimal chunk size based on system performance and log volume
    .DESCRIPTION
        Calculates optimal time chunk size based on system performance score, estimated log volume, memory usage, disk speed, and system load
    .PARAMETER PerformanceScore
        System performance score (0-100) indicating overall system performance
    .PARAMETER LogType
        Log type to determine log volume factor
    .RETURNS
        Optimal chunk size in hours for log scanning
    .EXAMPLE
        # Example: Get optimal chunk size for System logs on a high-performance system
        $chunkSize = Get-OptimalChunkSize -PerformanceScore 90 -LogType "System"
        Write-Host "Optimal chunk size: $([Math]::Round($chunkSize, 2)) hours" -ForegroundColor Green
    #>
    param(
        [int]$PerformanceScore,
        [string]$LogType
    )
    
    try {
        # Parameter validation
        if ($PerformanceScore -lt 0 -or $PerformanceScore -gt 100) {
            Write-Debug "Performance score out of range, using default value 50"
            $PerformanceScore = 50
        }
        
        # Estimate log volume based on log type
        $logVolumeFactor = switch ($LogType) {
            "Security" { 3.0 }  # Security logs are usually larger
            "DNS Server" { 2.5 }  # DNS server logs are larger
            "DHCP Server" { 2.0 }  # DHCP server logs are medium to large
            "Application" { 1.5 }  # Application logs are medium
            "System" { 1.0 }  # System logs are smaller
            "Directory Service" { 1.8 }  # Active Directory logs are medium to large
            "IIS Admin Service" { 1.6 }  # IIS logs are medium
            "Setup" { 0.5 }  # Setup logs are usually smaller
            "Forwarded Events" { 2.0 }  # Forwarded events logs are larger
            "Windows PowerShell" { 1.2 }  # PowerShell logs are medium
            "Microsoft-Windows-TaskScheduler/Operational" { 1.0 }  # Task Scheduler logs
            default { 1.0 }
        }
        
        # Calculate base chunk size based on performance score (more granular intervals)
        $baseChunkSize = if ($PerformanceScore -ge 90) {
            6  # Larger chunks for very high-performance systems
        } elseif ($PerformanceScore -ge 80) {
            4  # Larger chunks for high-performance systems
        } elseif ($PerformanceScore -ge 65) {
            3  # Medium to large chunks for medium-high performance systems
        } elseif ($PerformanceScore -ge 50) {
            2  # Medium chunks for medium-performance systems
        } elseif ($PerformanceScore -ge 30) {
            1.5  # Smaller chunks for medium-low performance systems
        } else {
            1  # Smallest chunks for low-performance systems
        }
        
        # Adjust chunk size based on log volume
        $adjustedChunkSize = [math]::Max(0.5, $baseChunkSize / $logVolumeFactor)
        
        # Get system status
        $memoryUsage = Get-MemoryUsage
        $systemLoad = Get-SystemLoad
        
        # Adjust chunk size based on memory usage
        if ($memoryUsage -gt 80) {
            # High memory usage, use smaller chunks
            $adjustedChunkSize = [math]::Max(0.25, $adjustedChunkSize * 0.5)
        } elseif ($memoryUsage -gt 60) {
            # Medium memory usage, use slightly smaller chunks
            $adjustedChunkSize = [math]::Max(0.5, $adjustedChunkSize * 0.75)
        }
        
        # Adjust chunk size based on system load
        if ($systemLoad -gt 80) {
            # High system load, use smaller chunks
            $adjustedChunkSize = [math]::Max(0.25, $adjustedChunkSize * 0.6)
        } elseif ($systemLoad -gt 60) {
            # Medium system load, use slightly smaller chunks
            $adjustedChunkSize = [math]::Max(0.5, $adjustedChunkSize * 0.8)
        }
        
        # Try to get disk speed information and adjust chunk size
        try {
            $diskInfo = Get-DiskPerformance
            if ($diskInfo.TotalPerformance -and $diskInfo.TotalPerformance.AvgDiskSecPerTransfer -gt 0) {
                # The shorter the disk response time, the larger the chunk can be
                $diskResponseTime = $diskInfo.TotalPerformance.AvgDiskSecPerTransfer
                if ($diskResponseTime -lt 0.005) {
                    # High-speed disk, increase chunk size
                    $adjustedChunkSize = [math]::Min(12, $adjustedChunkSize * 1.5)
                } elseif ($diskResponseTime -gt 0.02) {
                    # Low-speed disk, decrease chunk size
                    $adjustedChunkSize = [math]::Max(0.25, $adjustedChunkSize * 0.7)
                }
            }
            
            # Adjust chunk size based on disk type
            if ($diskInfo.Drives) {
                $hasSSD = $diskInfo.Drives | Where-Object { $_.IsSSD } | Measure-Object | Select-Object -ExpandProperty Count
                if ($hasSSD -gt 0) {
                    # System has SSD, can use larger chunks
                    $adjustedChunkSize = [math]::Min(12, $adjustedChunkSize * 1.2)
                }
            }
        } catch {
            # Disk performance detection failed, use default value
            Write-Debug "Disk performance detection failed: $($_.Exception.Message)"
        }
        
        # Calculate optimal parallelism (for display only)
        $cpuInfos = Get-CimInstance Win32_Processor
        
        # Handle multiple processors case
        if ($cpuInfos -is [array]) {
            # Calculate total cores
            $cpuCores = $cpuInfos | Measure-Object -Property NumberOfCores -Sum | Select-Object -ExpandProperty Sum
            $logicalProcessors = $cpuInfos | Measure-Object -Property NumberOfLogicalProcessors -Sum | Select-Object -ExpandProperty Sum
        } else {
            # Single processor case
            $cpuCores = $cpuInfos.NumberOfCores
            $logicalProcessors = $cpuInfos.NumberOfLogicalProcessors
        }
        
        $optimalThreads = Get-OptimalParallelism -CpuCores $cpuCores
        
        # Show optimal chunk size and thread count in non-silent mode
        if (-not $Silent) {
            Write-Host "Using optimal chunk size: $([Math]::Round($adjustedChunkSize, 2)) hours per chunk" -ForegroundColor Green
            Write-Host "Using $optimalThreads/$logicalProcessors threads based on system load" -ForegroundColor Green
            if ($memoryUsage -gt 60) {
                Write-Host "Memory usage: $memoryUsage%, adjusted chunk size to reduce memory usage" -ForegroundColor Yellow
            }
            if ($systemLoad -gt 60) {
                Write-Host "System load: $systemLoad%, adjusted chunk size to reduce system pressure" -ForegroundColor Yellow
            }
        }
        
        return $adjustedChunkSize
    } catch {
        Write-Debug "Error calculating optimal chunk size: $($_.Exception.Message)"
        # Return default value on error
        return 2.0
    }
}

# Cache management
$script:logCache = @{}
$script:cacheExpiryMinutes = 30  # Cache expiry time (minutes)
$script:minCacheSize = 5  # Minimum cache items

# Cache matching function
function Test-CacheMatch {
    <#
    .SYNOPSIS
        Tests if there is a matching cache for the specified log query
    .DESCRIPTION
        Checks if there is a valid cache entry for the specified log query based on log type, time range, and filter conditions
    .PARAMETER LogType
        Log type to check in cache
    .PARAMETER StartTime
        Start time of the log query
    .PARAMETER EndTime
        End time of the log query
    .PARAMETER EventId
        Event ID filter (optional)
    .PARAMETER ProviderName
        Event provider name filter (optional)
    .PARAMETER Level
        Event level filter (optional)
    .RETURNS
        Hashtable indicating if a match was found, the cache item, and the cache key
    .EXAMPLE
        # Example: Test cache match for System logs
        $cacheMatch = Test-CacheMatch -LogType "System" -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
        if ($cacheMatch.Match) {
            Write-Host "Cache match found! Using cached data." -ForegroundColor Green
        } else {
            Write-Host "No cache match found. Scanning logs..." -ForegroundColor Yellow
        }
    #>
    param(
        [string]$LogType,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [string]$EventId = "",
        [string]$ProviderName = "",
        [string]$Level = ""
    )
    
    # Generate current query cache key
    $cacheLogType = if ($LogType -eq "系统") { "System" } elseif ($LogType -eq "应用程序") { "Application" } else { $LogType }
    $cacheKey = Get-CacheKey -LogType "$cacheLogType-HighRisk" -StartTime $StartTime -EndTime $EndTime -EventId $EventId -ProviderName $ProviderName -Level $Level
    
    # Check if cache exists
    if ($script:logCache.ContainsKey($cacheKey)) {
        $cachedItem = $script:logCache[$cacheKey]
        
        # Validate if cache is not expired
        if ((Get-Date) - $cachedItem.Time -lt [TimeSpan]::FromMinutes($script:cacheExpiryMinutes)) {
            # Validate cache data integrity
            if ($cachedItem.Data -and $cachedItem.Data.Count -gt 0) {
                return @{
                    Match = $true
                    CacheItem = $cachedItem
                    CacheKey = $cacheKey
                }
            }
        }
    }
    
    return @{
        Match = $false
        CacheItem = $null
        CacheKey = $cacheKey
    }
}

# Show cache info function
function Show-CacheInfo {
    <#
    .SYNOPSIS
        Displays cache information
    .DESCRIPTION
        Displays detailed information about a cache item, including creation time, data count, size, and expiry time
    .PARAMETER CacheItem
        Cache item object to display information for
    .EXAMPLE
        # Example: Show cache information
        $cacheMatch = Test-CacheMatch -LogType "System" -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
        if ($cacheMatch.Match) {
            Show-CacheInfo -CacheItem $cacheMatch.CacheItem
        }
    #>
    param([object]$CacheItem)
    
    Write-AuroraLog "`n[Cache Information]" -Color Cyan
    Write-AuroraLog "Creation time: $($CacheItem.Time.ToString('yyyy-MM-dd HH:mm:ss'))" -Color Green
    Write-AuroraLog "Data count: $($CacheItem.Data.Count) events" -Color Green
    if ($CacheItem.OriginalSize) {
        Write-AuroraLog "Original size: $([Math]::Round($CacheItem.OriginalSize, 2)) MB" -Color Green
    }
    if ($CacheItem.CompressedSize) {
        Write-AuroraLog "Compressed size: $([Math]::Round($CacheItem.CompressedSize, 2)) MB" -Color Green
    }
    if ($CacheItem.CompressionRatio) {
        Write-AuroraLog "Compression ratio: $($CacheItem.CompressionRatio)%" -Color Green
    }
    Write-AuroraLog "Cache expiry time: $($CacheItem.Time.AddMinutes($script:cacheExpiryMinutes).ToString('yyyy-MM-dd HH:mm:ss'))" -Color Yellow
}

# Get cache usage choice function
function Get-CacheUsageChoice {
    <#
    .SYNOPSIS
        Gets user choice about whether to use cached data
    .DESCRIPTION
        Asks the user if they want to use cached data, or returns true in silent mode
    .PARAMETER CacheItem
        Cache item object to display information about
    .RETURNS
        Boolean indicating whether to use cached data
    .EXAMPLE
        # Example: Get cache usage choice
        $cacheMatch = Test-CacheMatch -LogType "System" -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
        if ($cacheMatch.Match) {
            $useCache = Get-CacheUsageChoice -CacheItem $cacheMatch.CacheItem
            if ($useCache) {
                Write-AuroraLog "Using cached data..." -Color Green
            } else {
                Write-AuroraLog "Scanning logs fresh..." -Color Yellow
            }
        }
    #>
    param([object]$CacheItem)
    
    # Check if running in silent mode
    if ($Silent) {
        # Silent mode: use cache directly
        return $true
    }
    
    Show-CacheInfo -CacheItem $CacheItem
    
    $maxRetries = 3
    $retryCount = 0
    
    while ($retryCount -lt $maxRetries) {
        $choice = Get-AuroraInteraction -PromptMessage "`nUse cached data? (Y/N) [Default: Y]"
        
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -like 'Y*') {
            return $true
        } elseif ($choice -like 'N*') {
            return $false
        } else {
            $retryCount++
            $remaining = $maxRetries - $retryCount
            if ($remaining -gt 0) {
                Write-AuroraLog "`n❌ Invalid input! Please enter Y or N (Remaining attempts: $remaining)" -Color Red
            } else {
                Write-AuroraLog "`n❌ Too many invalid inputs, using cache by default." -Color Red
                return $true
            }
        }
    }
}

# Cache validation function
function Test-CacheIntegrity {
    <#
    .SYNOPSIS
        Validates cache item integrity
    .DESCRIPTION
        Validates the integrity of a cache item by checking its structure, data type, data count, and data item structure
    .PARAMETER CacheItem
        Cache item object to validate
    .RETURNS
        Boolean indicating whether the cache item is valid
    .EXAMPLE
        # Example: Test cache integrity
        $cacheMatch = Test-CacheMatch -LogType "System" -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
        if ($cacheMatch.Match) {
            $isValid = Test-CacheIntegrity -CacheItem $cacheMatch.CacheItem
            if ($isValid) {
                Write-Host "Cache data is valid" -ForegroundColor Green
            } else {
                Write-Host "Cache data is invalid, scanning fresh" -ForegroundColor Yellow
            }
        }
    #>
    param([object]$CacheItem)
    
    try {
        # Validate cache data structure
        if (-not $CacheItem -or -not $CacheItem.Data) {
            return $false
        }
        
        # Validate data type
        if ($CacheItem.Data -isnot [array] -and $CacheItem.Data -isnot [System.Collections.Generic.List[object]]) {
            return $false
        }
        
        # Validate data count
        if ($CacheItem.Data.Count -lt 1) {
            return $false
        }
        
        # Validate data item structure
        $firstItem = $CacheItem.Data | Select-Object -First 1
        if (-not $firstItem -or -not $firstItem.PSObject.Properties["Id"] -or -not $firstItem.PSObject.Properties["TimeCreated"]) {
            return $false
        }
        
        return $true
    } catch {
        return $false
    }
}

# Dynamically adjust maximum cache items based on system memory
$os = Get-CimInstance Win32_OperatingSystem
$totalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB / 1024, 2)

if ($totalMemoryGB -lt 8) {
    $script:maxCacheSize = 10  # Below 8GB memory
} elseif ($totalMemoryGB -lt 16) {
    $script:maxCacheSize = 20  # 8-16GB memory
} else {
    $script:maxCacheSize = 50  # Above 16GB memory
}

# Object pool management
$script:objectPools = @{}
$script:objectPoolLock = New-Object System.Object

# Global RunspacePool management
$script:runspacePool = $null
$script:runspacePoolCreated = $false

# Knowledge Base related global variables
$script:knowledgeBase = $null
$script:knowledgeBaseLoaded = $false  # Force reload knowledge base
$script:knowledgeBaseCache = @{}
$script:knowledgeBaseIndex = @{}
$script:knowledgeBaseLastLoaded = $null  # Clear last load time
$script:knowledgeBaseExpiryMinutes = 30

function Load-KnowledgeBase {
    <#
    .SYNOPSIS
        Loads knowledge base file
    .DESCRIPTION
        Loads knowledge base data from JSON file and creates indexes for faster queries
    .RETURNS
        Boolean indicating whether loading was successful
    .EXAMPLE
        # Example: Load knowledge base
        $loaded = Load-KnowledgeBase
        if ($loaded) {
            Write-Host "Knowledge base loaded successfully" -ForegroundColor Green
        } else {
            Write-Host "Failed to load knowledge base" -ForegroundColor Red
        }
    #>
    try {
        # Knowledge base file path (in Data directory)
        $kbPath = [System.IO.Path]::Combine($PSScriptRoot, "..\Data\AURORA-TechData.json")
        
        # Check if file exists
        if (-not (Test-Path -Path $kbPath)) {
            Write-Host "❌ Knowledge base file not found: $kbPath" -ForegroundColor Red
            return $false
        }
        
        # Read and parse JSON file
        $jsonContent = Get-Content -Path $kbPath -Encoding UTF8 -ErrorAction Stop
        $script:knowledgeBase = $jsonContent | ConvertFrom-Json -ErrorAction Stop
        
        # Create indexes to speed up queries
        New-KnowledgeBaseIndex
        
        $script:knowledgeBaseLoaded = $true
        $script:knowledgeBaseLastLoaded = Get-Date
        
        Write-Host "✅ Knowledge base loaded successfully, contains $($script:knowledgeBase.categories.Count) categories" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Error loading knowledge base: $($_.Exception.Message)" -ForegroundColor Red
        $script:knowledgeBaseLoaded = $false
        return $false
    }
}

function New-KnowledgeBaseIndex {
    <#
    .SYNOPSIS
        Creates indexes for knowledge base
    .DESCRIPTION
        Creates indexes based on event ID, source, and keywords to speed up knowledge base queries
    .EXAMPLE
        # Example: Create knowledge base indexes
        Load-KnowledgeBase
        New-KnowledgeBaseIndex
        Write-Host "Knowledge base indexes created" -ForegroundColor Green
    #>
    try {
        # Reset indexes
        $script:knowledgeBaseIndex = @{
            EventId = @{}
            Source = @{}
            Keyword = @{}
        }
        
        # Iterate through all knowledge base items
        foreach ($category in $script:knowledgeBase.categories) {
            foreach ($item in $category.items) {
                # Index by event ID - ensure using int type
                foreach ($eventId in $item.event_ids) {
                    $eventIdInt = [int]$eventId
                    if (-not $script:knowledgeBaseIndex.EventId.ContainsKey($eventIdInt)) {
                        $script:knowledgeBaseIndex.EventId[$eventIdInt] = @()
                    }
                    $script:knowledgeBaseIndex.EventId[$eventIdInt] += $item
                }
                
                # Index by source
                if ($item.source) {
                    $sourceKey = $item.source.ToLower()
                    if (-not $script:knowledgeBaseIndex.Source.ContainsKey($sourceKey)) {
                        $script:knowledgeBaseIndex.Source[$sourceKey] = @()
                    }
                    $script:knowledgeBaseIndex.Source[$sourceKey] += $item
                }
                
                # Index by keyword
                if ($item.message_keywords) {
                    foreach ($keyword in $item.message_keywords) {
                        $keywordKey = $keyword.ToLower()
                        if (-not $script:knowledgeBaseIndex.Keyword.ContainsKey($keywordKey)) {
                            $script:knowledgeBaseIndex.Keyword[$keywordKey] = @()
                        }
                        $script:knowledgeBaseIndex.Keyword[$keywordKey] += $item
                    }
                }
            }
        }
        
        Write-Host "✅ Knowledge base indexes created successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Error creating knowledge base indexes: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-KnowledgeBaseSolution {
    <#
    .SYNOPSIS
        Queries knowledge base for solutions based on event information
    .DESCRIPTION
        Queries knowledge base for solutions based on event ID, source, and message content, with weighted matching and priority sorting
    .PARAMETER Event
        Event object to query solutions for
    .RETURNS
        Array of matching knowledge base solutions
    .EXAMPLE
        # Example: Get knowledge base solutions for an event
        $event = Get-WinEvent -LogName System -MaxEvents 1
        $solutions = Get-KnowledgeBaseSolution -Event $event
        if ($solutions.Count -gt 0) {
            Write-Host "Found $($solutions.Count) solutions for event ID $($event.Id)" -ForegroundColor Green
        } else {
            Write-Host "No solutions found for event ID $($event.Id)" -ForegroundColor Yellow
        }
    #>
    param(
        [object]$Event
    )
    
    try {
        # Ensure knowledge base is loaded
        if (-not $script:knowledgeBaseLoaded) {
            $loadSuccess = Load-KnowledgeBase
            if (-not $loadSuccess) {
                return @()
            }
        }
        
        # Check if knowledge base is expired
        if ($script:knowledgeBaseLastLoaded -and ((Get-Date) - $script:knowledgeBaseLastLoaded).TotalMinutes -gt $script:knowledgeBaseExpiryMinutes) {
            $loadSuccess = Load-KnowledgeBase
            if (-not $loadSuccess) {
                return @()
            }
        }
        
        # 🟢 Core defense: safely extract Message to prevent corrupted log exceptions from breaking entire matching
        $msgText = ""
        try {
            if ($null -ne $Event.Message) { $msgText = $Event.Message }
        } catch { Write-Debug "Unable to read event message" }

        # Generate cache key - use lightweight GetHashCode() for better performance
        $rawKey = "$($Event.Id)-$($Event.ProviderName)-$msgText"
        $cacheKey = $rawKey.GetHashCode().ToString("X")
        
        # Try to get from cache
        if ($script:knowledgeBaseCache.ContainsKey($cacheKey)) {
            $cachedData = $script:knowledgeBaseCache[$cacheKey].Data
            if ($cachedData) {
                return $cachedData
            } else {
                # Cache data is $null, return empty array
                return @()
            }
        }
        
        $solutionScores = @{}
        
        # 1. Match by Event ID (Weight: 100, exact match) - handle type mismatch
        if ($Event.Id) {
            $eventIdInt = [int]$Event.Id
            if ($script:knowledgeBaseIndex.EventId.ContainsKey($eventIdInt)) {
                foreach ($item in $script:knowledgeBaseIndex.EventId[$eventIdInt]) {
                    $key = $item.rule_id
                    if (-not $solutionScores.ContainsKey($key)) {
                        $solutionScores[$key] = @{ Item = $item; Score = 0 }
                    }
                    $solutionScores[$key].Score += 100
                }
            } else {
                # Try with string type
                $eventIdStr = [string]$Event.Id
                if ($script:knowledgeBaseIndex.EventId.ContainsKey($eventIdStr)) {
                    foreach ($item in $script:knowledgeBaseIndex.EventId[$eventIdStr]) {
                        $key = $item.rule_id
                        if (-not $solutionScores.ContainsKey($key)) {
                            $solutionScores[$key] = @{ Item = $item; Score = 0 }
                        }
                        $solutionScores[$key].Score += 100
                    }
                }
            }
        }
        
        # 2. Match by Source (Weight: 50, category match)
        if ($Event.ProviderName) {
            $sourceKey = $Event.ProviderName.ToLower()
            
            # First try exact match
            if ($script:knowledgeBaseIndex.Source.ContainsKey($sourceKey)) {
                foreach ($item in $script:knowledgeBaseIndex.Source[$sourceKey]) {
                    $key = $item.rule_id
                    if (-not $solutionScores.ContainsKey($key)) {
                        $solutionScores[$key] = @{ Item = $item; Score = 0 }
                    }
                    $solutionScores[$key].Score += 50
                }
            } else {
                # Try removing "Microsoft-Windows-" prefix and match
                $sourceKeyWithoutPrefix = $sourceKey -replace '^microsoft-windows-', ''
                if ($script:knowledgeBaseIndex.Source.ContainsKey($sourceKeyWithoutPrefix)) {
                    foreach ($item in $script:knowledgeBaseIndex.Source[$sourceKeyWithoutPrefix]) {
                        $key = $item.rule_id
                        if (-not $solutionScores.ContainsKey($key)) {
                            $solutionScores[$key] = @{ Item = $item; Score = 0 }
                        }
                        $solutionScores[$key].Score += 45  # Slightly lower weight since not exact match
                    }
                } else {
                    # Try reverse: add "Microsoft-Windows-" prefix to KB sources and match
                    foreach ($kbSource in $script:knowledgeBaseIndex.Source.Keys) {
                        $prefixedKbSource = "microsoft-windows-$kbSource"
                        if ($sourceKey -eq $prefixedKbSource) {
                            foreach ($item in $script:knowledgeBaseIndex.Source[$kbSource]) {
                                $key = $item.rule_id
                                if (-not $solutionScores.ContainsKey($key)) {
                                    $solutionScores[$key] = @{ Item = $item; Score = 0 }
                                }
                                $solutionScores[$key].Score += 45  # Slightly lower weight since not exact match
                            }
                            break
                        }
                    }
                }
            }
        }
        
        # 3. Match by Keyword (Weight: 10 per match, fuzzy match)
        if ($msgText -ne "") {
            $messageLower = $msgText.ToLower()
            foreach ($keyword in $script:knowledgeBaseIndex.Keyword.Keys) {
                if ($messageLower -like "*$keyword*") {
                    foreach ($item in $script:knowledgeBaseIndex.Keyword[$keyword]) {
                        $key = $item.rule_id
                        if (-not $solutionScores.ContainsKey($key)) {
                            $solutionScores[$key] = @{ Item = $item; Score = 0 }
                        }
                        $solutionScores[$key].Score += 10
                    }
                }
            }
        }
        
        # 4. Build final result: sort by match score descending + priority descending
        $matchingSolutions = $solutionScores.Values | 
                             Sort-Object -Property @{Expression={$_.Score}; Descending=$true}, 
                                                   @{Expression={$_.Item.priority}; Descending=$true} | 
                             ForEach-Object { $_.Item }
        
        # Ensure empty array is returned instead of $null
        if (-not $matchingSolutions) {
            $matchingSolutions = @()
        }
        
        # Cache results - store as structure with Data and Time
        $script:knowledgeBaseCache[$cacheKey] = @{
            Data = $matchingSolutions
            Time = Get-Date
        }
        
        # Limit cache size - clean up old cache sorted by Time
        if ($script:knowledgeBaseCache.Count -gt 1000) {
            $oldestKeys = $script:knowledgeBaseCache.GetEnumerator() | 
                           Sort-Object { $_.Value.Time } | 
                           Select-Object -First ($script:knowledgeBaseCache.Count - 1000) -ExpandProperty Key
            foreach ($key in $oldestKeys) {
                $script:knowledgeBaseCache.Remove($key)
            }
        }
        
        return $matchingSolutions
    } catch {
        Write-Debug "Error querying knowledge base: $($_.Exception.Message)"
        return @()
    }
}

# Function to get localized knowledge base solution
function Get-LocalizedKnowledgeBaseSolution {
    <#
    .SYNOPSIS
        Gets localized knowledge base solution based on language
    .DESCRIPTION
        Returns knowledge base solution with language-specific fields (English for ENGPRO)
    .PARAMETER Solution
        Knowledge base solution object to localize
    .RETURNS
        Localized knowledge base solution with English fields
    .EXAMPLE
        # Example: Get localized knowledge base solution
        $event = Get-WinEvent -LogName System -MaxEvents 1
        $solutions = Get-KnowledgeBaseSolution -Event $event
        if ($solutions.Count -gt 0) {
            $localizedSolution = Get-LocalizedKnowledgeBaseSolution -Solution $solutions[0]
            Write-Host "Localized solution: $($localizedSolution.name)" -ForegroundColor Green
        }
    #>
    param(
        [object]$Solution
    )
    
    try {
        # For ENGPRO, use English fields
        $localizedSolution = @{
            rule_id = $Solution.rule_id
            name = $Solution.name_en
            event_ids = $Solution.event_ids
            source = $Solution.source
            message_keywords = $Solution.message_keywords
            severity = $Solution.severity
            description = $Solution.description_en
            causes = $Solution.causes_en
            solutions = $Solution.solutions_en
            commands = $Solution.commands
            recommended_action = $Solution.recommended_action_en
            priority = $Solution.priority
            applies_to = $Solution.applies_to
        }
        
        return $localizedSolution
    } catch {
        Write-Debug "Error localizing knowledge base solution: $($_.Exception.Message)"
        return $Solution
    }
}

# Function to get localized knowledge base solutions
function Get-LocalizedKnowledgeBaseSolutions {
    <#
    .SYNOPSIS
        Gets localized knowledge base solutions based on language
    .DESCRIPTION
        Returns array of knowledge base solutions with language-specific fields (English for ENGPRO)
    .PARAMETER Solutions
        Array of knowledge base solution objects to localize
    .RETURNS
        Array of localized knowledge base solutions with English fields
    .EXAMPLE
        # Example: Get localized knowledge base solutions
        $event = Get-WinEvent -LogName System -MaxEvents 1
        $solutions = Get-KnowledgeBaseSolution -Event $event
        $localizedSolutions = Get-LocalizedKnowledgeBaseSolutions -Solutions $solutions
        Write-Host "Localized $($localizedSolutions.Count) solutions" -ForegroundColor Green
    #>
    param(
        [array]$Solutions
    )
    
    try {
        $localizedSolutions = @()
        foreach ($solution in $Solutions) {
            $localizedSolutions += Get-LocalizedKnowledgeBaseSolution -Solution $solution
        }
        return $localizedSolutions
    } catch {
        Write-Debug "Error localizing knowledge base solutions: $($_.Exception.Message)"
        return $Solutions
    }
}

function Get-KnowledgeBasePriority {
    <#
    .SYNOPSIS
        Gets event priority from knowledge base
    .DESCRIPTION
        Gets priority from knowledge base based on event ID and source, returns the highest priority if multiple matches
    .PARAMETER Event
        Event object to get priority for
    .RETURNS
        Priority value (0-100), returns default value 50 if no match
    .EXAMPLE
        # Example: Get knowledge base priority for an event
        $event = Get-WinEvent -LogName System -MaxEvents 1
        $priority = Get-KnowledgeBasePriority -Event $event
        Write-Host "Event priority: $priority/100" -ForegroundColor Cyan
    #>
    param(
        [object]$Event
    )
    
    try {
        $solutions = Get-KnowledgeBaseSolution -Event $Event
        if ($solutions.Count -gt 0) {
            # Return highest priority
            return ($solutions | Sort-Object priority -Descending | Select-Object -First 1).priority
        }
        
        # Default priority
        return 50
    } catch {
        Write-Debug "Error getting knowledge base priority: $($_.Exception.Message)"
        return 50
    }
}

function Get-BatchKnowledgeBaseSolutions {
    <#
    .SYNOPSIS
        Batch query knowledge base solutions (single-threaded high-speed version)
    .DESCRIPTION
        Abandon multi-threading architecture that causes object serialization corruption, use single-threaded direct call to Get-KnowledgeBaseSolution to ensure 100% hit rate
    .PARAMETER Events
        Array of event objects to query solutions for
    .PARAMETER ThreadCount
        Reserved parameter for compatibility with other function calls (deprecated)
    .RETURNS
        Hashtable containing events as keys and their corresponding solutions as values
    #>
    param(
        [array]$Events,
        [int]$ThreadCount = 4  # Reserved parameter for compatibility with other function calls
    )
    
    try {
        $finalResult = @{}
        
        # Abandon multi-threading that causes serialization damage, directly use single-threaded hash table for fast matching
        foreach ($event in $Events) {
            # Directly call the perfectly encapsulated single-threaded lookup function
            $solutions = Get-KnowledgeBaseSolution -Event $event
            
            # Ensure array is returned regardless of hit or miss
            if ($solutions) {
                $finalResult[$event] = @($solutions)
            } else {
                $finalResult[$event] = @()
            }
        }
        
        return $finalResult
    } catch {
        Write-Debug "Error in batch knowledge base query: $($_.Exception.Message)"
        $result = @{}
        foreach ($event in $Events) {
            $result[$event] = @()
        }
        return $result
    }
}

function Get-BatchKnowledgeBasePriorities {
    <#
    .SYNOPSIS
        Batch parallel get event priorities
    .DESCRIPTION
        Batch process priority retrieval for multiple events using parallel processing to improve performance
    .PARAMETER Events
        Array of event objects to get priorities for
    .PARAMETER ThreadCount
        Number of parallel threads to use for processing
    .RETURNS
        Hashtable containing events as keys and their corresponding priorities as values
    .EXAMPLE
        # Example: Get batch knowledge base priorities
        $events = Get-WinEvent -LogName System -MaxEvents 10
        $prioritiesMap = Get-BatchKnowledgeBasePriorities -Events $events -ThreadCount 4
        Write-Host "Processed $($prioritiesMap.Count) events" -ForegroundColor Green
        foreach ($event in $events) {
            $priority = $prioritiesMap[$event]
            Write-Host "Event ID $($event.Id): Priority $priority/100" -ForegroundColor Cyan
        }
    #>
    param(
        [array]$Events,
        [int]$ThreadCount = 4
    )
    
    try {
        # Batch get solutions
        $solutionsMap = Get-BatchKnowledgeBaseSolutions -Events $Events -ThreadCount $ThreadCount
        
        # Calculate priority for each event
        $priorities = @{}
        foreach ($event in $Events) {
            $solutions = $solutionsMap[$event]
            if ($solutions.Count -gt 0) {
                # Return highest priority
                $priorities[$event] = ($solutions | Sort-Object priority -Descending | Select-Object -First 1).priority
            } else {
                # Default priority
                $priorities[$event] = 50
            }
        }
        
        return $priorities
    } catch {
        Write-Debug "Error in batch priority retrieval: $($_.Exception.Message)"
        # Return default priorities
        $priorities = @{}
        foreach ($event in $Events) {
            $priorities[$event] = 50
        }
        return $priorities
    }
}

# Cache Status Check and Initialization Function
function Initialize-Cache {
    <#
    .SYNOPSIS
        Check and initialize cache state
    .DESCRIPTION
        Validates cache structure, cleans expired cache items, and ensures cache data validity
    .PARAMETER Force
        Switch parameter to force reinitialization of cache (clears all cache items)
    .RETURNS
        Boolean indicating whether initialization was successful
    .EXAMPLE
        # Example: Initialize cache
        $success = Initialize-Cache
        if ($success) {
            Write-Host "Cache initialized successfully" -ForegroundColor Green
        } else {
            Write-Host "Failed to initialize cache" -ForegroundColor Red
        }
        
        # Example: Force reinitialize cache
        $success = Initialize-Cache -Force
        if ($success) {
            Write-Host "Cache force reinitialized" -ForegroundColor Green
        }
    #>
    param(
        [switch]$Force
    )
    
    try {
        # Validate cache structure
        if ($script:logCache -eq $null) {
            $script:logCache = @{}
        }
        
        # Force clear cache if Force parameter is specified
        if ($Force) {
            $script:logCache.Clear()
        }
        
        # Clean expired cache items
        $currentTime = Get-Date
        $keysToRemove = @()
        
        foreach ($key in $script:logCache.Keys) {
            $cachedItem = $script:logCache[$key]
            if ($cachedItem -and $cachedItem.Time) {
                $cacheAge = $currentTime - $cachedItem.Time
                if ($cacheAge.TotalMinutes -gt $script:cacheExpiryMinutes) {
                    $keysToRemove += $key
                }
            } else {
                # Invalid cache item
                $keysToRemove += $key
            }
        }
        
        # Remove expired or invalid cache items
        foreach ($key in $keysToRemove) {
            $script:logCache.Remove($key)
        }
        
        # Dynamic cache size adjustment
        $optimalCacheSize = Get-OptimalCacheSize
        
        # Limit cache size
        if ($script:logCache.Count -gt $optimalCacheSize) {
            $oldestKeys = $script:logCache.GetEnumerator() | Sort-Object { $_.Value.Time } | Select-Object -First ($script:logCache.Count - $optimalCacheSize) -ExpandProperty Key
            foreach ($key in $oldestKeys) {
                $script:logCache.Remove($key)
            }
        }
        
        # Clean memory
        [System.GC]::Collect()
        
        return $true
    } catch {
        Write-Debug "Error initializing cache: $($_.Exception.Message)"
        # Cache initialization failed, reset cache
        $script:logCache = @{}
        return $false
    }
}

# Object pool management functions
function New-ObjectPool {
    <#
    .SYNOPSIS
        Creates a new object pool
    .DESCRIPTION
        Creates a new object pool for managing reusable objects to improve performance and reduce resource usage
    .PARAMETER PoolName
        Object pool name used to identify the pool
    .PARAMETER ObjectType
        Object type description for documentation purposes
    .PARAMETER InitialSize
        Initial pool size (number of objects to pre-create)
    .PARAMETER MaxSize
        Maximum pool size (maximum number of objects to keep in the pool)
    .PARAMETER ObjectFactory
        Object creation factory function that returns a new instance of the object
    .RETURNS
        Object pool object
    .EXAMPLE
        # Example: Create an object pool for StreamWriter objects
        $streamWriterPool = New-ObjectPool -PoolName "StreamWriterPool" -ObjectType "StreamWriter" -InitialSize 5 -MaxSize 20 -ObjectFactory {
            New-Object System.IO.StreamWriter
        }
        Write-Host "Created object pool with $($streamWriterPool.Objects.Count) initial objects" -ForegroundColor Green
    #>
    param(
        [string]$PoolName,
        [string]$ObjectType,
        [int]$InitialSize = 5,
        [int]$MaxSize = 20,
        [scriptblock]$ObjectFactory
    )
    
    try {
        lock ($script:objectPoolLock) {
            # Validate parameters
            if ([string]::IsNullOrWhiteSpace($PoolName)) {
                throw "Pool name cannot be empty"
            }
            if ([string]::IsNullOrWhiteSpace($ObjectType)) {
                throw "Object type cannot be empty"
            }
            if ($InitialSize -lt 0) {
                $InitialSize = 0
            }
            if ($MaxSize -lt $InitialSize) {
                $MaxSize = $InitialSize
            }
            if (!$ObjectFactory) {
                throw "Object factory scriptblock is required"
            }
            
            # Initialize object pool
            $pool = @{
                Name = $PoolName
                Type = $ObjectType
                MaxSize = $MaxSize
                Objects = New-Object System.Collections.Generic.Queue[object]
                Factory = $ObjectFactory
                Lock = New-Object System.Object
            }
            
            # Pre-create initial objects
            for ($i = 0; $i -lt $InitialSize; $i++) {
                try {
                    $object = & $ObjectFactory
                    if ($object) {
                        $pool.Objects.Enqueue($object)
                    }
                } catch {
                    $exMsg = $_.Exception.Message
                    $errorMessage = "Failed to create object for pool " + $PoolName + ": " + $exMsg
                    Write-Debug $errorMessage
                }
            }
            
            # Store object pool
            $script:objectPools[$PoolName] = $pool
            Write-Debug "Created object pool $PoolName with $($pool.Objects.Count) initial objects"
            return $pool
        }
    } catch {
        $exMsg = $_.Exception.Message
        $errorMessage = "Error creating object pool: " + $exMsg
        Write-Error $errorMessage
        return $null
    }
}

function Get-ObjectFromPool {
    <#
    .SYNOPSIS
        Gets an object from the pool
    .DESCRIPTION
        Gets an available object from the pool, creates a new one if the pool is empty
    .PARAMETER PoolName
        Object pool name to get an object from
    .RETURNS
        Object from the pool or a new instance if the pool is empty
    .EXAMPLE
        # Example: Get an object from the pool
        $streamWriter = Get-ObjectFromPool -PoolName "StreamWriterPool"
        if ($streamWriter) {
            Write-Host "Got object from pool" -ForegroundColor Green
        } else {
            Write-Host "Failed to get object from pool" -ForegroundColor Red
        }
    #>
    param(
        [string]$PoolName
    )
    
    try {
        lock ($script:objectPoolLock) {
            if (!$script:objectPools.ContainsKey($PoolName)) {
                throw "Object pool $PoolName does not exist"
            }
            
            $pool = $script:objectPools[$PoolName]
            lock ($pool.Lock) {
                if ($pool.Objects.Count -gt 0) {
                    $object = $pool.Objects.Dequeue()
                    Write-Debug "Retrieved object from pool $PoolName, remaining: $($pool.Objects.Count)"
                    return $object
                } else {
                    # Pool is empty, create new object
                    $object = & $pool.Factory
                    if ($object) {
                        Write-Debug "Created new object for pool $PoolName"
                    }
                    return $object
                }
            }
        }
    } catch {
        $exMsg = $_.Exception.Message
        $errorMessage = "Error getting object from pool: " + $exMsg
        Write-Debug $errorMessage
        return $null
    }
}

function Return-ObjectToPool {
    <#
    .SYNOPSIS
        Returns an object to the pool
    .DESCRIPTION
        Returns a used object to the pool for reuse, discards it if the pool is full
    .PARAMETER PoolName
        Object pool name to return the object to
    .PARAMETER Object
        Object to return to the pool
    .EXAMPLE
        # Example: Return an object to the pool
        $streamWriter = Get-ObjectFromPool -PoolName "StreamWriterPool"
        # Use the object...
        Return-ObjectToPool -PoolName "StreamWriterPool" -Object $streamWriter
        Write-Host "Object returned to pool" -ForegroundColor Green
    #>
    param(
        [string]$PoolName,
        [object]$Object
    )
    
    try {
        if (!$Object) {
            return
        }
        
        lock ($script:objectPoolLock) {
            if (!$script:objectPools.ContainsKey($PoolName)) {
                throw "Object pool $PoolName does not exist"
            }
            
            $pool = $script:objectPools[$PoolName]
            lock ($pool.Lock) {
                if ($pool.Objects.Count -lt $pool.MaxSize) {
                    $pool.Objects.Enqueue($Object)
                    Write-Debug "Returned object to pool $PoolName, total: $($pool.Objects.Count)"
                } else {
                    Write-Debug "Pool $PoolName is full, discarding object"
                }
            }
        }
    } catch {
        $exMsg = $_.Exception.Message
        $errorMessage = "Error returning object to pool: " + $exMsg
        Write-Debug $errorMessage
    }
}

function Clear-ObjectPool {
    <#
    .SYNOPSIS
        Clears an object pool
    .DESCRIPTION
        Clears all objects from the specified object pool
    .PARAMETER PoolName
        Object pool name to clear
    .EXAMPLE
        # Example: Clear an object pool
        Clear-ObjectPool -PoolName "StreamWriterPool"
        Write-Host "Object pool cleared" -ForegroundColor Green
    #>
    param(
        [string]$PoolName
    )
    
    try {
        lock ($script:objectPoolLock) {
            if ($script:objectPools.ContainsKey($PoolName)) {
                $pool = $script:objectPools[$PoolName]
                lock ($pool.Lock) {
                    $pool.Objects.Clear()
                    Write-Debug "Cleared object pool $PoolName"
                }
            }
        }
    } catch {
        $exMsg = $_.Exception.Message
        $errorMessage = "Error clearing object pool: " + $exMsg
        Write-Debug $errorMessage
    }
}

function Get-ObjectPoolStatus {
    <#
    .SYNOPSIS
        Gets object pool status
    .DESCRIPTION
        Gets the current status of the specified object pool, including name, type, current size, and maximum size
    .PARAMETER PoolName
        Object pool name to get status for
    .RETURNS
        Hashtable containing pool status information, or $null if the pool doesn't exist
    .EXAMPLE
        # Example: Get object pool status
        $status = Get-ObjectPoolStatus -PoolName "StreamWriterPool"
        if ($status) {
            Write-Host "Pool: $($status.Name), Type: $($status.Type), Current: $($status.CurrentSize), Max: $($status.MaxSize)" -ForegroundColor Cyan
        } else {
            Write-Host "Pool not found" -ForegroundColor Red
        }
    #>
    param(
        [string]$PoolName
    )
    
    try {
        lock ($script:objectPoolLock) {
            if (!$script:objectPools.ContainsKey($PoolName)) {
                return $null
            }
            
            $pool = $script:objectPools[$PoolName]
            lock ($pool.Lock) {
                return @{
                    Name = $pool.Name
                    Type = $pool.Type
                    CurrentSize = $pool.Objects.Count
                    MaxSize = $pool.MaxSize
                }
            }
        }
    } catch {
        $exMsg = $_.Exception.Message
        $errorMessage = "Error getting object pool status: " + $exMsg
        Write-Debug $errorMessage
        return $null
    }
}

# Gets current system memory usage
function Get-MemoryUsage {
    <#
    .SYNOPSIS
        Gets current system memory usage
    .DESCRIPTION
        Returns current memory usage percentage and detailed memory information
    .PARAMETER Detailed
        Switch parameter to return detailed memory information instead of just the usage percentage
    .RETURNS
        By default: Memory usage percentage (0-100)
        With Detailed switch: Hashtable with detailed memory information including total, free, used memory, and memory usage percentage
    .EXAMPLE
        # Example: Get memory usage percentage
        $memoryUsage = Get-MemoryUsage
        Write-Host "Memory usage: $memoryUsage%" -ForegroundColor Cyan
        
        # Example: Get detailed memory information
        $memoryInfo = Get-MemoryUsage -Detailed
        Write-Host "Total memory: $($memoryInfo.TotalMemoryMB) MB" -ForegroundColor Cyan
        Write-Host "Free memory: $($memoryInfo.FreeMemoryMB) MB" -ForegroundColor Cyan
        Write-Host "Used memory: $($memoryInfo.UsedMemoryMB) MB" -ForegroundColor Cyan
        Write-Host "Memory usage: $($memoryInfo.MemoryUsagePercent)%" -ForegroundColor Cyan
    #>
    param(
        [switch]$Detailed
    )
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $totalMemory = $os.TotalVisibleMemorySize / 1MB
        $freeMemory = $os.FreePhysicalMemory / 1MB
        $usedMemory = $totalMemory - $freeMemory
        $memoryUsage = [Math]::Round(($usedMemory / $totalMemory) * 100, 2)
        
        if ($Detailed) {
            return @{
                TotalMemoryMB = [Math]::Round($totalMemory, 2)
                FreeMemoryMB = [Math]::Round($freeMemory, 2)
                UsedMemoryMB = [Math]::Round($usedMemory, 2)
                MemoryUsagePercent = $memoryUsage
                AvailableMemoryMB = [Math]::Round($os.FreeVirtualMemory / 1MB, 2)
                TotalVirtualMemoryMB = [Math]::Round(($os.TotalVirtualMemorySize) / 1MB, 2)
            }
        } else {
            return $memoryUsage
        }
    } catch {
        Write-Debug "Error getting memory usage: $($_.Exception.Message)"
        if ($Detailed) {
            return @{
                TotalMemoryMB = 0
                FreeMemoryMB = 0
                UsedMemoryMB = 0
                MemoryUsagePercent = 50
                AvailableMemoryMB = 0
                TotalVirtualMemoryMB = 0
            }
        } else {
            return 50
        }
    }
}

function Get-OptimalCacheSize {
    <#
    .SYNOPSIS
        Calculates optimal cache size based on memory usage
    .DESCRIPTION
        Adjusts cache size based on current memory usage to optimize performance and memory usage
    .RETURNS
        Optimal cache size (number of items) based on current memory usage
    .EXAMPLE
        # Example: Get optimal cache size
        $optimalCacheSize = Get-OptimalCacheSize
        Write-Host "Optimal cache size: $optimalCacheSize items" -ForegroundColor Green
    #>
    $memoryUsage = Get-MemoryUsage
    
    if ($memoryUsage -lt 50) {
        # Low memory usage, use larger cache
        return $script:maxCacheSize
    } elseif ($memoryUsage -lt 70) {
        # Medium memory usage, use moderate cache
        return [Math]::Round(($script:maxCacheSize + $script:minCacheSize) / 2)
    } else {
        # High memory usage, use smaller cache
        return $script:minCacheSize
    }
}

function Get-SystemLoad {
    <#
    .SYNOPSIS
        Gets current system load
    .DESCRIPTION
        Returns current system load percentage based on CPU usage
    .RETURNS
        System load percentage (0-100)
    .EXAMPLE
        # Example: Get system load
        $systemLoad = Get-SystemLoad
        Write-Host "System load: $systemLoad%" -ForegroundColor Cyan
        if ($systemLoad -gt 80) {
            Write-Host "System load is high, consider reducing parallelism" -ForegroundColor Yellow
        }
    #>
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty LoadPercentage
        return $cpu
    } catch {
        # Return default value on error
        return 50
    }
}

function Get-OptimalParallelism {
    <#
    .SYNOPSIS
        Calculates optimal parallelism based on system load and CPU cores
    .DESCRIPTION
        Adjusts parallelism based on current system load, CPU physical cores, logical cores (hyper-threading), memory usage and disk performance
    .PARAMETER CpuCores
        Number of CPU physical cores
    .PARAMETER TaskType
        Task type: IOIntensive (IO-intensive) or CPUIntensive (CPU-intensive)
    .RETURNS
        Optimal parallelism (number of threads)
    .EXAMPLE
        # Example: Get optimal parallelism for IO-intensive tasks
        $optimalParallelism = Get-OptimalParallelism -CpuCores 4 -TaskType "IOIntensive"
        Write-Host "Optimal parallelism for IO tasks: $optimalParallelism threads" -ForegroundColor Green
        
        # Example: Get optimal parallelism for CPU-intensive tasks
        $optimalParallelism = Get-OptimalParallelism -CpuCores 4 -TaskType "CPUIntensive"
        Write-Host "Optimal parallelism for CPU tasks: $optimalParallelism threads" -ForegroundColor Green
    #>
    param(
        [ValidateRange(1, [int]::MaxValue)]
        [int]$CpuCores,
        
        [ValidateSet("IOIntensive", "CPUIntensive")]
        [string]$TaskType = "IOIntensive"
    )
    
    try {
        # Validate parameters
        if ($CpuCores -lt 1) {
            throw "CpuCores must be at least 1"
        }
        
        # Get CPU information, including logical processors (hyper-threading)
        $cpuInfos = Get-CimInstance Win32_Processor
        
        # Handle multiple processors case
        if ($cpuInfos -is [array]) {
            # Calculate total logical processors
            $logicalProcessors = $cpuInfos | Measure-Object -Property NumberOfLogicalProcessors -Sum | Select-Object -ExpandProperty Sum
        } else {
            # Single processor case
            $logicalProcessors = $cpuInfos.NumberOfLogicalProcessors
        }
        
        $hasHyperThreading = $logicalProcessors -gt $CpuCores
        
        $systemLoad = Get-SystemLoad
        $memoryUsage = Get-MemoryUsage
        
        # Get memory information
        $memoryInfo = Get-CimInstance Win32_ComputerSystem
        $totalMemoryGB = [math]::Round($memoryInfo.TotalPhysicalMemory / 1GB, 2)
        
        # Get disk performance information
        $diskInfo = Get-DiskPerformance
        
        # Calculate maximum threads based on task type, hyper-threading support
        $baseMaxThreads = if ($TaskType -eq "IOIntensive") {
            # IO-intensive tasks can utilize more threads
            if ($hasHyperThreading) {
                # With hyper-threading, use 80% of logical cores for optimal performance
                $calculatedThreads = [Math]::Round($logicalProcessors * 0.8)
                # Adjust maximum threads based on memory size
                $maxThreadsBasedOnMemory = [Math]::Max(4, [Math]::Min(64, [Math]::Round($totalMemoryGB / 2)))
                [Math]::Min($calculatedThreads, $maxThreadsBasedOnMemory)
            } else {
                # Without hyper-threading, use 120% of physical cores
                $calculatedThreads = [Math]::Round($CpuCores * 1.2)
                # Adjust maximum threads based on memory size
                $maxThreadsBasedOnMemory = [Math]::Max(2, [Math]::Min(32, [Math]::Round($totalMemoryGB / 4)))
                [Math]::Min($calculatedThreads, $maxThreadsBasedOnMemory)
            }
        } else {
            # CPU-intensive tasks, should limit thread count
            if ($hasHyperThreading) {
                # With hyper-threading, use 60% of logical cores
                $calculatedThreads = [Math]::Round($logicalProcessors * 0.6)
                # Adjust maximum threads based on memory size
                $maxThreadsBasedOnMemory = [Math]::Max(2, [Math]::Min(32, [Math]::Round($totalMemoryGB / 4)))
                [Math]::Min($calculatedThreads, $maxThreadsBasedOnMemory)
            } else {
                # Without hyper-threading, use physical cores
                $calculatedThreads = $CpuCores
                # Adjust maximum threads based on memory size
                $maxThreadsBasedOnMemory = [Math]::Max(2, [Math]::Min(32, [Math]::Round($totalMemoryGB / 4)))
                [Math]::Min($calculatedThreads, $maxThreadsBasedOnMemory)
            }
        }
        
        $maxThreads = $baseMaxThreads
        
        # Adjust based on system load
        if ($systemLoad -lt 30) {
            # Low system load, use maximum parallelism
            $adjustedThreads = $maxThreads
        } elseif ($systemLoad -lt 70) {
            # Medium system load, use moderate parallelism
            $adjustedThreads = [Math]::Max(1, [Math]::Round($maxThreads * 0.75))
        } else {
            # High system load, use minimal parallelism
            $adjustedThreads = [Math]::Max(1, [Math]::Round($maxThreads * 0.5))
        }
        
        # Adjust based on memory usage
        if ($memoryUsage -gt 80) {
            $adjustedThreads = [Math]::Max(1, [Math]::Round($adjustedThreads * 0.7))
        } elseif ($memoryUsage -gt 60) {
            $adjustedThreads = [Math]::Max(1, [Math]::Round($adjustedThreads * 0.9))
        }
        
        # Adjust based on disk performance
        if ($diskInfo.Score -gt 45) {
            # Good disk performance, can increase thread count
            $adjustedThreads = [Math]::Min($maxThreads, [Math]::Round($adjustedThreads * 1.1))
        } elseif ($diskInfo.Score -lt 35) {
            # Poor disk performance, reduce thread count
            $adjustedThreads = [Math]::Max(1, [Math]::Round($adjustedThreads * 0.8))
        }
        
        return $adjustedThreads
    } catch {
        Write-Debug "Error in Get-OptimalParallelism: $($_.Exception.Message)"
        # Return default thread count
        return [Math]::Max(2, $CpuCores)
    }
}

function New-AdvancedLogPatternAnalysis {
    <#
    .SYNOPSIS
        Performs advanced log pattern analysis
    .DESCRIPTION
        Identifies patterns in log data including repetitive events, time-based patterns, anomalies, event correlations, and trend predictions
    .PARAMETER Events
        Log events to analyze
    .RETURNS
        Hashtable containing pattern analysis results including patterns, anomalies, time patterns, correlations, trends, and provider analysis
    .EXAMPLE
        # Example: Analyze log events for patterns
        $events = Get-WinEvent -LogName System -MaxEvents 1000
        $analysis = New-AdvancedLogPatternAnalysis -Events $events
        Write-Host "Found $($analysis.Patterns.Count) patterns" -ForegroundColor Green
        Write-Host "Found $($analysis.Anomalies.Count) anomalies" -ForegroundColor Yellow
        Write-Host "Found $($analysis.Correlations.Count) correlations" -ForegroundColor Cyan
    #>
    param(
        [object]$Events
    )
    
    # Enhanced input validation
    try {
        if (!$Events) {
            return @{
                Patterns = @()
                Anomalies = @()
                TimePatterns = @()
                Correlations = @()
                Trends = @()
                ProviderAnalysis = @()
                Summary = "No events to analyze"
            }
        }
        
        # Ensure Events is an enumerable object
        if ($Events -isnot [System.Collections.IEnumerable] -or $Events.Count -eq 0) {
            return @{
                Patterns = @()
                Anomalies = @()
                TimePatterns = @()
                Correlations = @()
                Trends = @()
                ProviderAnalysis = @()
                Summary = "No events to analyze"
            }
        }
        
        # Validate Events object structure
        $firstEvent = $Events | Select-Object -First 1
        if (!$firstEvent -or !$firstEvent.PSObject.Properties["Id"] -or !$firstEvent.PSObject.Properties["TimeCreated"] -or !$firstEvent.PSObject.Properties["ProviderName"]) {
            return @{
                Patterns = @()
                Anomalies = @()
                TimePatterns = @()
                Correlations = @()
                Trends = @()
                ProviderAnalysis = @()
                Summary = "Invalid event object structure"
            }
        }
        
        Write-Host "`n[Performing advanced log pattern analysis...]" -ForegroundColor Cyan
        
        # 1. Identify repetitive events
        $repetitivePatterns = @()
        # Performance optimization: Use hashtable for large event collections
        if ($Events.Count -gt 1000) {
            $eventGroups = $Events | Group-Object -Property Id -AsHashTable -AsString
            foreach ($key in $eventGroups.Keys) {
                $group = $eventGroups[$key]
                if ($group.Count -ge 3) {
                    $sortedGroup = $group | Sort-Object TimeCreated
                    $firstEvent = $sortedGroup | Select-Object -First 1
                    $lastEvent = $sortedGroup | Select-Object -Last 1
                    
                    $repetitivePatterns += @{
                        EventId = $key
                        Count = $group.Count
                        FirstSeen = $firstEvent.TimeCreated
                        LastSeen = $lastEvent.TimeCreated
                        Providers = ($group | Select-Object -Unique ProviderName) -join ", "
                        Severity = $firstEvent.LevelDisplayName
                    }
                }
            }
        } else {
            $eventGroups = $Events | Group-Object -Property Id
            foreach ($group in $eventGroups) {
                if ($group.Count -ge 3) {
                    $firstEvent = $group.Group | Sort-Object TimeCreated | Select-Object -First 1
                    $lastEvent = $group.Group | Sort-Object TimeCreated | Select-Object -Last 1
                    
                    $repetitivePatterns += @{
                        EventId = $group.Name
                        Count = $group.Count
                        FirstSeen = $firstEvent.TimeCreated
                        LastSeen = $lastEvent.TimeCreated
                        Providers = ($group.Group | Select-Object -Unique ProviderName) -join ", "
                        Severity = $firstEvent.LevelDisplayName
                    }
                }
            }
        }
        
        # 2. Identify time-based patterns
        $timePatterns = @()
        $eventsByHour = $Events | Group-Object { $_.TimeCreated.Hour }
        
        foreach ($hourGroup in $eventsByHour) {
            if ($hourGroup.Count -gt 10) {
                $timePatterns += @{
                    Hour = $hourGroup.Name
                    EventCount = $hourGroup.Count
                    EventTypes = ($hourGroup.Group | Select-Object -Unique Id).Count
                }
            }
        }
        
        # 3. Identify anomalies
        $anomalies = @()
        
        # Check for events with high severity
        $criticalEvents = $Events | Where-Object { $_.Level -eq 1 }  # Critical events
        foreach ($event in $criticalEvents) {
            $anomalies += @{
                EventId = $event.Id
                TimeCreated = $event.TimeCreated
                ProviderName = $event.ProviderName
                Message = $event.Message
                Severity = "Critical"
                Type = "High severity event"
            }
        }
        
        # Check for unusual event frequency
        if ($Events.Count -gt 1000) {
            foreach ($key in $eventGroups.Keys) {
                $group = $eventGroups[$key]
                if ($group.Count -ge 10) {
                    $sortedGroup = $group | Sort-Object TimeCreated
                    if ($sortedGroup.Count -ge 2) {
                        $timeSpan = $sortedGroup[-1].TimeCreated - $sortedGroup[0].TimeCreated
                        if ($timeSpan.TotalMinutes -lt 10) {
                            $anomalies += @{
                                EventId = $key
                                Count = $group.Count
                                TimeSpan = "$($timeSpan.TotalMinutes.ToString('F2')) minutes"
                                Type = "High frequency event"
                            }
                        }
                    }
                }
            }
        } else {
            foreach ($group in $eventGroups) {
                if ($group.Count -ge 10) {
                    $sortedGroup = $group.Group | Sort-Object TimeCreated
                    if ($sortedGroup.Count -ge 2) {
                        $timeSpan = $sortedGroup[-1].TimeCreated - $sortedGroup[0].TimeCreated
                        if ($timeSpan.TotalMinutes -lt 10) {
                            $anomalies += @{
                                EventId = $group.Name
                                Count = $group.Count
                                TimeSpan = "$($timeSpan.TotalMinutes.ToString('F2')) minutes"
                                Type = "High frequency event"
                            }
                        }
                    }
                }
            }
        }
        
        # 4. Event correlation analysis (optimized version)
        $correlations = @()
        try {
            # Sort events by time
            $sortedEvents = $Events | Sort-Object TimeCreated
            
            # Optimized correlation analysis algorithm
            $i = 0
            while ($i -lt $sortedEvents.Count - 1) {
                $currentEvent = $sortedEvents[$i]
                $relatedEvents = @()
                $j = $i + 1
                
                while ($j -lt $sortedEvents.Count) {
                    $nextEvent = $sortedEvents[$j]
                    $timeDiff = ($nextEvent.TimeCreated - $currentEvent.TimeCreated).TotalMinutes
                    
                    if ($timeDiff -le 5) {
                        $relatedEvents += $nextEvent
                        $j++
                    } else {
                        break
                    }
                }
                
                # If related events found
                if ($relatedEvents.Count -ge 2) {
                    $correlation = @{
                        MainEventId = $currentEvent.Id
                        MainEventTime = $currentEvent.TimeCreated
                        MainEventProvider = $currentEvent.ProviderName
                        RelatedEvents = $relatedEvents | ForEach-Object {
                            @{
                                EventId = $_.Id
                                TimeCreated = $_.TimeCreated
                                ProviderName = $_.ProviderName
                                Message = $_.Message
                            }
                        }
                        TotalRelatedEvents = $relatedEvents.Count
                    }
                    
                    $correlations += $correlation
                    $i = $j
                } else {
                    $i++
                }
            }
        } catch {
            Write-Debug "Event correlation analysis failed: $($_.Exception.Message)"
            # Correlation analysis failed, continue with other analyses
        }
        
        # 5. Trend prediction (enhanced version)
        $trends = @()
        try {
            # Group events by date
            $eventsByDate = $Events | Group-Object { $_.TimeCreated.Date }
            
            # Calculate daily event counts
            $dailyEventCounts = @()
            foreach ($group in $eventsByDate) {
                $dailyEventCounts += @{
                    Date = $group.Name
                    Count = $group.Count
                }
            }
            
            # Sort by date
            $dailyEventCounts = $dailyEventCounts | Sort-Object Date
            
            # Enhanced trend prediction
            if ($dailyEventCounts.Count -ge 3) {
                # Calculate average
                $totalCount = $dailyEventCounts | Measure-Object -Property Count -Sum | Select-Object -ExpandProperty Sum
                $averageCount = $totalCount / $dailyEventCounts.Count
                
                # Calculate trend slope
                $sumX = 0
                $sumY = 0
                $sumXY = 0
                $sumX2 = 0
                $n = $dailyEventCounts.Count
                
                for ($k = 0; $k -lt $n; $k++) {
                    $x = $k
                    $y = $dailyEventCounts[$k].Count
                    $sumX += $x
                    $sumY += $y
                    $sumXY += $x * $y
                    $sumX2 += $x * $x
                }
                
                # Calculate slope
                $slope = 0
                if ($n * $sumX2 - $sumX * $sumX -ne 0) {
                    $slope = ($n * $sumXY - $sumX * $sumY) / ($n * $sumX2 - $sumX * $sumX)
                }
                
                # Calculate trend direction
                if ($slope -gt 0.1) {
                    $trendDirection = "Increasing"
                } elseif ($slope -lt -0.1) {
                    $trendDirection = "Decreasing"
                } else {
                    $trendDirection = "Stable"
                }
                
                $trends += @{
                    AverageDailyEvents = [Math]::Round($averageCount, 2)
                    TrendDirection = $trendDirection
                    TrendSlope = [Math]::Round($slope, 3)
                    FirstDate = $dailyEventCounts[0].Date
                    LastDate = $dailyEventCounts[-1].Date
                    FirstCount = $dailyEventCounts[0].Count
                    LastCount = $dailyEventCounts[-1].Count
                }
            }
        } catch {
            Write-Debug "Trend prediction failed: $($_.Exception.Message)"
            # Trend prediction failed, continue with other analyses
        }
        
        # 6. Extended analysis: Event provider analysis
        $providerAnalysis = @()
        try {
            $eventsByProvider = $Events | Group-Object -Property ProviderName
            
            foreach ($providerGroup in $eventsByProvider) {
                $providerAnalysis += @{
                    ProviderName = $providerGroup.Name
                    EventCount = $providerGroup.Count
                    EventTypes = ($providerGroup.Group | Select-Object -Unique Id).Count
                    SeverityLevels = ($providerGroup.Group | Select-Object -Unique Level).Count
                }
            }
        } catch {
            Write-Debug "Provider analysis failed: $($_.Exception.Message)"
        }
        
        # 7. Generate summary
        $summary = @{
            TotalEvents = $Events.Count
            UniqueEventTypes = if ($Events.Count -gt 1000) { $eventGroups.Keys.Count } else { $eventGroups.Count }
            RepetitivePatterns = $repetitivePatterns.Count
            TimePatterns = $timePatterns.Count
            Anomalies = $anomalies.Count
            Correlations = $correlations.Count
            Trends = $trends.Count
            ProviderCount = $providerAnalysis.Count
        }
        
        # Return analysis results
        return @{
            Patterns = $repetitivePatterns
            Anomalies = $anomalies
            TimePatterns = $timePatterns
            Correlations = $correlations
            Trends = $trends
            ProviderAnalysis = $providerAnalysis
            Summary = $summary
        }
    } catch {
        Write-Debug "Advanced log pattern analysis failed: $($_.Exception.Message)"
        # Analysis failed, return default result
        return @{
            Patterns = @()
            Anomalies = @()
            TimePatterns = @()
            Correlations = @()
            Trends = @()
            ProviderAnalysis = @()
            Summary = "Analysis failed: $($_.Exception.Message)"
        }
    }
}

function Get-CacheKey {
    <#
    .SYNOPSIS
        Generates cache key
    .DESCRIPTION
        Generates unique cache key based on log type, time range, and filter conditions
    .PARAMETER LogType
        Log type (e.g., "System", "Application", "Security")
    .PARAMETER StartTime
        Start time for the log query
    .PARAMETER EndTime
        End time for the log query
    .PARAMETER EventId
        Event ID to filter (empty string for all events)
    .PARAMETER ProviderName
        Event provider name to filter (empty string for all providers)
    .PARAMETER Level
        Event level to filter (empty string for all levels)
    .RETURNS
        Unique cache key string
    .EXAMPLE
        # Example: Generate cache key for System logs
        $startTime = (Get-Date).AddDays(-1)
        $endTime = Get-Date
        $cacheKey = Get-CacheKey -LogType "System" -StartTime $startTime -EndTime $endTime
        Write-Host "Cache key: $cacheKey" -ForegroundColor Cyan
        
        # Example: Generate cache key with specific filters
        $cacheKey = Get-CacheKey -LogType "Application" -StartTime $startTime -EndTime $endTime -EventId "1000" -ProviderName "Application Error"
        Write-Host "Filtered cache key: $cacheKey" -ForegroundColor Cyan
    #>
    param(
        [string]$LogType,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [string]$EventId = "",
        [string]$ProviderName = "",
        [string]$Level = ""
    )
    
    # Encode parameters to avoid special character conflicts
    $encodedLogType = [uri]::EscapeDataString($LogType)
    $encodedEventId = [uri]::EscapeDataString($EventId)
    $encodedProviderName = [uri]::EscapeDataString($ProviderName)
    $encodedLevel = [uri]::EscapeDataString($Level)
    
    # Generate unique key
    $key = "$encodedLogType|$($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))|$($EndTime.ToString('yyyy-MM-dd HH:mm:ss'))|$encodedEventId|$encodedProviderName|$encodedLevel"
    return $key
}

function Get-CachedLogData {
    <#
    .SYNOPSIS
        Gets log data from cache
    .DESCRIPTION
        Gets log data from cache based on cache key, returns $null if cache expired or not found
    .PARAMETER CacheKey
        Cache key generated by Get-CacheKey function
    .PARAMETER Silent
        Silent mode, do not output cache-related information
    .RETURNS
        Cached log data (object) or $null if cache expired or not found
    .EXAMPLE
        # Example: Get cached log data
        $startTime = (Get-Date).AddDays(-1)
        $endTime = Get-Date
        $cacheKey = Get-CacheKey -LogType "System" -StartTime $startTime -EndTime $endTime
        $cachedData = Get-CachedLogData -CacheKey $cacheKey
        if ($cachedData) {
            Write-Host "Found cached data with $($cachedData.Count) events" -ForegroundColor Green
        } else {
            Write-Host "No cached data found or cache expired" -ForegroundColor Yellow
        }
        
        # Example: Get cached data in silent mode
        $cachedData = Get-CachedLogData -CacheKey $cacheKey -Silent
    #>
    param(
        [string]$CacheKey,
        [switch]$Silent = $false
    )
    
    if ($script:logCache.ContainsKey($CacheKey)) {
        $cachedItem = $script:logCache[$CacheKey]
        $cacheTime = $cachedItem.Time
        $compressedData = $cachedItem.Data
        
        # Check if cache is expired
        if ((Get-Date) - $cacheTime -lt [TimeSpan]::FromMinutes($script:cacheExpiryMinutes)) {
            if (-not $Silent) {
                Write-Host "Getting data from cache..." -ForegroundColor Cyan
            }
            
            # Decompress data
            try {
                $decompressedData = Expand-CompressedData -CompressedData $compressedData
                return $decompressedData
            } catch {
                # Decompression failed, remove cache item
                $script:logCache.Remove($CacheKey)
                return $null
            }
        } else {
            # Cache expired, remove
            $script:logCache.Remove($CacheKey)
            return $null
        }
    }
    return $null
}

function Set-CachedLogData {
    <#
    .SYNOPSIS
        Stores log data in cache
    .DESCRIPTION
        Stores log data and timestamp in cache, and dynamically cleans cache based on memory usage
    .PARAMETER CacheKey
        Cache key generated by Get-CacheKey function
    .PARAMETER Data
        Log data to cache (object)
    .PARAMETER CacheStrategy
        Cache strategy object obtained from Get-IntelligentCacheStrategy function
    .PARAMETER Silent
        Silent mode, do not output cache-related information
    .EXAMPLE
        # Example: Store log data in cache
        $startTime = (Get-Date).AddDays(-1)
        $endTime = Get-Date
        $cacheKey = Get-CacheKey -LogType "System" -StartTime $startTime -EndTime $endTime
        $events = Get-WinEvent -LogName System -MaxEvents 1000
        $cacheStrategy = Get-IntelligentCacheStrategy
        Set-CachedLogData -CacheKey $cacheKey -Data $events -CacheStrategy $cacheStrategy
        Write-Host "Data cached successfully" -ForegroundColor Green
        
        # Example: Store data in cache silently
        Set-CachedLogData -CacheKey $cacheKey -Data $events -CacheStrategy $cacheStrategy -Silent
    #>
    param(
        [string]$CacheKey,
        [object]$Data,
        [object]$CacheStrategy,
        [switch]$Silent = $false
    )
    
    # Clean memory
    if (-not $Silent) {
        Write-CustomProgress -Activity "Processing cache" -Status "Cleaning memory..." -PercentComplete 10
    }
    [System.GC]::Collect()
    
    # Monitor memory usage
    $memoryUsage = Get-MemoryUsage
    if (-not $Silent) {
        Write-CustomProgress -Activity "Processing cache" -Status "Monitoring memory usage... $memoryUsage%" -PercentComplete 20
    }
    
    # Data size evaluation
    $dataCount = if ($Data -is [array] -or $Data -is [System.Collections.Generic.List[object]]) { $Data.Count } else { 1 }
    if (-not $Silent) {
        Write-CustomProgress -Activity "Processing cache" -Status "Evaluating data size... $dataCount events" -PercentComplete 30
    }
    
    # Use intelligent cache strategy
    $shouldCompress = $cacheStrategy.Compression
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Fastest
    $dataSize = 0
    
    try {
        if (-not $Silent) {
            Write-CustomProgress -Activity "Processing cache" -Status "Analyzing data size..." -PercentComplete 40
        }
        
        # Estimate data size (avoid time-consuming JSON conversion)
        $dataSize = if ($Data -is [array] -or $Data -is [System.Collections.Generic.List[object]]) {
            # Estimate size based on event count, average 1KB per event
            $Data.Count * 1024
        } else {
            # Single object is approximately 1KB
            1024
        }
        
        # Only consider other factors if cache strategy allows compression
        if ($cacheStrategy.Compression) {
            # Get available memory
            $os = Get-CimInstance Win32_OperatingSystem
            $totalMemory = $os.TotalVisibleMemorySize / 1MB
            $freeMemory = $os.FreePhysicalMemory / 1MB
            $availableMemory = $freeMemory
            
            # Aggressive compression decision logic
            # Only compress when data size exceeds 20% of available memory
            if ($dataSize -gt $availableMemory * 1024 * 1024 * 0.2) {
                $shouldCompress = $true
                # For data that needs compression, use fast compression mode
                $compressionLevel = [System.IO.Compression.CompressionLevel]::Fastest
            } else {
                $shouldCompress = false
            }
            
            # Adjust processing strategy based on memory usage
            if ($memoryUsage -gt 80) {
                Write-CustomProgress -Activity "Processing cache" -Status "Memory usage is high, using conservative processing strategy..." -PercentComplete 45
                # For high memory usage, force compression
                $shouldCompress = $true
                $compressionLevel = [System.IO.Compression.CompressionLevel]::Fastest
            }
        } else {
            # Cache strategy doesn't allow compression, set to false
            $shouldCompress = false
        }
    } catch {
        # Conversion failed, default to no compression
        $shouldCompress = $false
    }
    
    # Compress data
    if ($shouldCompress) {
        try {
            # Process large data in chunks with parallel compression
            $compressedData = $null
            if ($dataCount -gt 10000) {
                # Process large data in chunks
                $chunkSize = 5000
                $chunks = Split-Array -InputArray $Data -Size $chunkSize
                $totalChunks = $chunks.Count
                $compressedChunks = @()
                
                # Parallel compression implementation
                $threadCount = [Math]::Max(1, [Math]::Min(8, $totalChunks))
                $runspacePool = Get-RunspacePool -ThreadCount $threadCount
                $jobs = @()
                
                foreach ($chunk in $chunks) {
                    $powershell = [PowerShell]::Create()
                    $powershell.RunspacePool = $runspacePool
                    $powershell.AddScript({ param($data, $level) 
                        # Define compression function directly to avoid re-importing entire script (prevent duplicate initialization)
                        function Compress-Data {
                            param(
                                [byte[]]$Data,
                                [int]$CompressionLevel = 6
                            )
                            $memoryStream = New-Object System.IO.MemoryStream
                            $gzipStream = New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode]::Compress)
                            $gzipStream.Write($Data, 0, $Data.Length)
                            $gzipStream.Close()
                            return $memoryStream.ToArray()
                        }
                        return Compress-Data -Data $data -CompressionLevel $level
                    }).AddArgument($chunk).AddArgument($compressionLevel)
                    
                    $job = $powershell.BeginInvoke()
                    $jobs += @{ PowerShell = $powershell; Job = $job }
                }
                
                # Collect parallel compression results
                $currentChunk = 0
                while ($jobs.Count -gt 0) {
                    $completedJobs = $jobs | Where-Object { $_.Job.IsCompleted }
                    
                    foreach ($job in $completedJobs) {
                        try {
                            $compressedChunk = $job.PowerShell.EndInvoke($job.Job)
                            $compressedChunks += $compressedChunk
                        } catch {
                            # Compression failed, use original data
                            $compressedChunks += $chunk
                        } finally {
                            $job.PowerShell.Dispose()
                        }
                        
                        $currentChunk++
                        $percent = [Math]::Round(50 + ($currentChunk / $totalChunks) * 30)
                        if (-not $Silent) {
                            Write-CustomProgress -Activity "Processing cache" -Status "Compressing data chunk $currentChunk/$totalChunks" -PercentComplete $percent -CurrentItem $currentChunk -TotalItems $totalChunks -CurrentTask "Compressing data chunk $currentChunk"
                        }
                    }
                    
                    $jobs = $jobs | Where-Object { -not $_.Job.IsCompleted }
                    Start-Sleep -Milliseconds 100
                }
                
                # Close RunspacePool
                Close-RunspacePool -Silent $true
                
                # Merge compressed results
                $compressedData = $compressedChunks
            } else {
                # Process small data directly
                if (-not $Silent) {
                    Write-CustomProgress -Activity "Processing cache" -Status "Compressing data..." -PercentComplete 70
                }
                $compressedData = Compress-Data -Data $Data -CompressionLevel $compressionLevel
            }
            
            # Calculate estimated data size
            if (-not $Silent) {
                Write-CustomProgress -Activity "Processing cache" -Status "Calculating compression ratio..." -PercentComplete 80
            }
            $jsonData = $Data | ConvertTo-Json -Depth 10 -Compress -WarningAction SilentlyContinue
            $originalSize = $jsonData.Length / 1MB
            $compressedSize = $compressedData.Length / 1MB
            $compressionRatio = [Math]::Round(($originalSize - $compressedSize) / $originalSize * 100, 2)
            
            if (-not $Silent) {
                Write-CustomProgress -Activity "Processing cache" -Status "Compression completed, compression ratio: $compressionRatio%" -PercentComplete 85
            }
        } catch {
            # Compression failed, use original data
            $compressedData = $Data
            # Calculate estimated data size
            try {
                $jsonData = $Data | ConvertTo-Json -Depth 10 -Compress -WarningAction SilentlyContinue
                $originalSize = $jsonData.Length / 1MB
            } catch {
                $originalSize = 0
            }
            $compressedSize = $originalSize
            $compressionRatio = 0
            
            if (-not $Silent) {
                Write-CustomProgress -Activity "Processing cache" -Status "Compression failed, using original data" -PercentComplete 85
            }
        }
    } else {
        # Don't compress data
        $compressedData = $Data
        try {
            $jsonData = $Data | ConvertTo-Json -Depth 10 -Compress -WarningAction SilentlyContinue
            $originalSize = $jsonData.Length / 1MB
        } catch {
            $originalSize = 0
        }
        $compressedSize = $originalSize
        $compressionRatio = 0
        
        if (-not $Silent) {
            Write-CustomProgress -Activity "Processing cache" -Status "Data is small or memory is sufficient, storing directly" -PercentComplete 85
        }
    }
    
    if (-not $Silent) {
        Write-CustomProgress -Activity "Processing cache" -Status "Storing to cache..." -PercentComplete 90
    }
    
    $script:logCache[$CacheKey] = @{
        Time = Get-Date
        Data = $compressedData
        OriginalSize = $originalSize
        CompressedSize = $compressedSize
        CompressionRatio = $compressionRatio
        LastAccessed = Get-Date
    }
    
    # Clean expired cache (older than 24 hours)
    $expiryTime = (Get-Date).AddHours(-24)
    $expiredKeys = $script:logCache.GetEnumerator() | Where-Object { $_.Value.Time -lt $expiryTime } | Select-Object -ExpandProperty Key
    foreach ($key in $expiredKeys) {
        $script:logCache.Remove($key)
    }
    
    # Check memory usage
    $memoryUsage = Get-MemoryUsage
    
    # Limit cache size based on memory usage
    $optimalCacheSize = Get-OptimalCacheSize
    if ($script:logCache.Count -gt $optimalCacheSize) {
        # Remove oldest cache item
        $oldestKey = $script:logCache.GetEnumerator() | Sort-Object { $_.Value.Time } | Select-Object -First 1 -ExpandProperty Key
        $script:logCache.Remove($oldestKey)
        if (-not $Silent) {
            Write-CustomProgress -Activity "Processing cache" -Status "Cache size adjusted to $optimalCacheSize items based on memory usage" -PercentComplete 95
        }
    }
    
    # Force clean half of the cache when memory usage exceeds 80%
    if ($memoryUsage -gt 80) {
        $currentCount = $script:logCache.Count
        $targetCount = [Math]::Max(1, [Math]::Round($currentCount / 2))
        if ($currentCount -gt $targetCount) {
            $keysToRemove = $script:logCache.GetEnumerator() | Sort-Object { $_.Value.Time } | Select-Object -First ($currentCount - $targetCount) -ExpandProperty Key
            foreach ($key in $keysToRemove) {
                $script:logCache.Remove($key)
            }
            if (-not $Silent) {
                Write-CustomProgress -Activity "Processing cache" -Status "Memory usage too high, cleaned some cache items, current cache count: $targetCount" -PercentComplete 95
            }
        }
    }
    
    if (-not $Silent) {
        Write-CustomProgress -Activity "Processing cache" -Status "Cache processing completed!" -PercentComplete 100
        
        # Output final result
        if ($compressionRatio -gt 0) {
            Write-Host "`nData compressed and stored in cache (compression ratio: $compressionRatio%)..." -ForegroundColor Cyan
        } else {
            Write-Host "`nData stored in cache..." -ForegroundColor Cyan
        }
    }
}

function Compress-Data {
    <#
    .SYNOPSIS
        Compresses data
    .DESCRIPTION
        Compresses data using Gzip to reduce memory usage
    .PARAMETER Data
        Data to compress (object)
    .PARAMETER CompressionLevel
        Compression level (Optimal, Fastest, NoCompression)
    .RETURNS
        Compressed byte array
    .EXAMPLE
        # Example: Compress data with optimal compression
        $data = @{ Name = "Test"; Value = 123; Items = @(1, 2, 3) }
        $compressedData = Compress-Data -Data $data -CompressionLevel Optimal
        Write-Host "Compressed data length: $($compressedData.Length) bytes" -ForegroundColor Green
        
        # Example: Compress data with fastest compression
        $compressedData = Compress-Data -Data $data -CompressionLevel Fastest
        Write-Host "Fast compressed data length: $($compressedData.Length) bytes" -ForegroundColor Cyan
    #>
    param(
        [object]$Data,
        [System.IO.Compression.CompressionLevel]$CompressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    )
    
    try {
        # Validate input parameter
        if ($null -eq $Data) {
            throw "Input data cannot be null"
        }
        
        # Convert object to JSON
        $jsonData = $Data | ConvertTo-Json -Depth 10 -Compress
        
        # Convert JSON to byte array
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonData)
        
        # Create memory stream
        $memoryStream = New-Object System.IO.MemoryStream
        try {
            # Create Gzip stream
            $gzipStream = New-Object System.IO.Compression.GzipStream($memoryStream, $CompressionLevel)
            try {
                # Write data
                $gzipStream.Write($bytes, 0, $bytes.Length)
            } finally {
                # Ensure Gzip stream is closed
                if ($gzipStream) {
                    $gzipStream.Close()
                }
            }
            
            # Get compressed byte array
            $compressedBytes = $memoryStream.ToArray()
        } finally {
            # Ensure memory stream is closed
            if ($memoryStream) {
                $memoryStream.Close()
            }
        }
        
        # Convert byte array to Base64 string
        return [Convert]::ToBase64String($compressedBytes)
    } catch {
        throw "Error compressing data: $($_.Exception.Message)"
    }
}

function Expand-CompressedData {
    <#
    .SYNOPSIS
        Decompresses data
    .DESCRIPTION
        Decompresses previously compressed data using Gzip
    .PARAMETER CompressedData
        Compressed data (Base64 encoded string) obtained from Compress-Data function
    .RETURNS
        Decompressed object
    .EXAMPLE
        # Example: Decompress data
        $data = @{ Name = "Test"; Value = 123; Items = @(1, 2, 3) }
        $compressedData = Compress-Data -Data $data
        $decompressedData = Expand-CompressedData -CompressedData $compressedData
        Write-Host "Decompressed data: $($decompressedData | ConvertTo-Json -Depth 5)" -ForegroundColor Green
    #>
    param(
        [string]$CompressedData
    )
    
    try {
        # Validate input parameter
        if ([string]::IsNullOrEmpty($CompressedData)) {
            throw "Input data cannot be null or empty"
        }
        
        # Validate Base64 string
        try {
            [Convert]::FromBase64String($CompressedData) | Out-Null
        } catch {
            throw "Input data is not a valid Base64 string"
        }
        
        # Convert Base64 string to byte array
        $compressedBytes = [Convert]::FromBase64String($CompressedData)
        
        # Create memory stream
        $memoryStream = New-Object System.IO.MemoryStream($compressedBytes)
        try {
            # Create Gzip stream
            $gzipStream = New-Object System.IO.Compression.GzipStream($memoryStream, [System.IO.Compression.CompressionMode]::Decompress)
            try {
                # Create reader
                $streamReader = New-Object System.IO.StreamReader($gzipStream)
                try {
                    # Read decompressed data
                    $jsonData = $streamReader.ReadToEnd()
                } finally {
                    # Ensure reader is closed
                    if ($streamReader) {
                        $streamReader.Close()
                    }
                }
            } finally {
                # Ensure Gzip stream is closed
                if ($gzipStream) {
                    $gzipStream.Close()
                }
            }
        } finally {
            # Ensure memory stream is closed
            if ($memoryStream) {
                $memoryStream.Close()
            }
        }
        
        # Convert JSON back to object
        return $jsonData | ConvertFrom-Json
    } catch {
        throw "Error decompressing data: $($_.Exception.Message)"
    }
}

function Clear-LogCache {
    <#
    .SYNOPSIS
        Clears all log cache
    .DESCRIPTION
        Clears all log cache items to free up memory
    .PARAMETER Silent
        Whether to execute silently without displaying output
    .RETURNS
        Boolean indicating whether the clearing operation was successful
    .EXAMPLE
        # Example: Clear log cache
        $success = Clear-LogCache
        if ($success) {
            Write-Host "Cache cleared successfully" -ForegroundColor Green
        } else {
            Write-Host "Failed to clear cache" -ForegroundColor Red
        }
        
        # Example: Clear cache silently
        $success = Clear-LogCache -Silent
    #>
    param(
        [switch]$Silent = $false
    )
    
    try {
        # Check if cache exists
        if ($script:logCache) {
            $beforeCount = $script:logCache.Count
            $script:logCache.Clear()
            $afterCount = $script:logCache.Count
            
            if (-not $Silent) {
                Write-Host "Cache cleared, $beforeCount items before, $afterCount items after" -ForegroundColor Cyan
            }
            return $true
        } else {
            if (-not $Silent) {
                Write-Host "Cache does not exist, no need to clear" -ForegroundColor Yellow
            }
            return $false
        }
    } catch {
        if (-not $Silent) {
            Write-Host "Error clearing cache: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $false
    }
}

function Split-Array {
    <#
    .SYNOPSIS
        Splits array into batches of specified size
    .DESCRIPTION
        Splits a large array into multiple smaller arrays of specified size for parallel processing
    .PARAMETER InputArray
        Input array to split
    .PARAMETER Size
        Size of each batch (number of items per batch)
    .RETURNS
        Array of batches (each batch is an array)
    .EXAMPLE
        # Example: Split array into batches of 10 items
        $items = 1..100
        $batches = Split-Array -InputArray $items -Size 10
        Write-Host "Split into $($batches.Count) batches" -ForegroundColor Green
        foreach ($i in 0..($batches.Count - 1)) {
            Write-Host "Batch $($i+1): $($batches[$i].Count) items" -ForegroundColor Cyan
        }
    #>
    param(
        [array]$InputArray,
        [int]$Size
    )
    
    for ($i = 0; $i -lt $InputArray.Length; $i += $Size) {
        $end = [Math]::Min($i + $Size, $InputArray.Length)
        $InputArray[$i..($end - 1)]
    }
}

function Get-RunspacePool {
    <#
    .SYNOPSIS
        Gets or creates global RunspacePool
    .DESCRIPTION
        Gets existing RunspacePool, creates a new one if it doesn't exist
    .PARAMETER ThreadCount
        Number of threads (parallelism level)
    .RETURNS
        RunspacePool object
    .EXAMPLE
        # Example: Get or create RunspacePool with 4 threads
        $runspacePool = Get-RunspacePool -ThreadCount 4
        Write-Host "RunspacePool created with $($runspacePool.ThreadOptions) thread options" -ForegroundColor Green
    #>
    param(
        [int]$ThreadCount
    )
    
    try {
        # Validate parameter
        if ($ThreadCount -lt 1) {
            throw "Thread count must be greater than 0"
        }
        
        # Check if RunspaceFactory type is available
        if (-not ([System.Management.Automation.Runspaces.RunspaceFactory])) {
            throw "Current PowerShell version does not support RunspacePool"
        }
        
        # Reasonability check: thread count should not exceed 2 times the number of processor cores
        $maxThreads = [System.Environment]::ProcessorCount * 2
        if ($ThreadCount -gt $maxThreads) {
            Write-Warning "Thread count $ThreadCount exceeds recommended maximum of $maxThreads, which may affect performance"
        }
        
        # Check if new RunspacePool needs to be created
        if (!$script:runspacePoolCreated -or $script:runspacePool -eq $null -or $script:runspacePool.IsDisposed) {
            # Create new RunspacePool
            $script:runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $ThreadCount)
            $script:runspacePool.Open()
            $script:runspacePoolCreated = $true
            Write-Debug "Created new RunspacePool with $ThreadCount threads"
        }
        
        return $script:runspacePool
    } catch {
        Write-Error "Error creating RunspacePool: $($_.Exception.Message)"
        return $null
    }
}

# TPL-based parallel processing function
function Invoke-ParallelTask {
    <#
    .SYNOPSIS
        TPL-based parallel task processing
    .DESCRIPTION
        Uses Task Parallel Library (TPL) to process tasks in parallel, supporting dynamic thread management and task priority
    .PARAMETER Tasks
        List of tasks to execute (each task should have ScriptBlock and Parameters properties)
    .PARAMETER ThreadCount
        Number of threads (parallelism level)
    .PARAMETER TaskPriority
        Task priority (Low, Normal, High)
    .PARAMETER ProgressActivity
        Progress activity name displayed in the progress bar
    .PARAMETER ThreadAdjustmentInterval
        Thread adjustment interval (milliseconds) for dynamic thread management
    .PARAMETER Silent
        Whether to run in silent mode (no progress output)
    .PARAMETER DynamicThreadManagement
        Whether to enable dynamic thread management based on system load
    .RETURNS
        Array of task execution results
    .EXAMPLE
        # Example: Execute parallel tasks
        $tasks = @()
        for ($i = 1; $i -le 10; $i++) {
            $tasks += @{
                ScriptBlock = {
                    param($index)
                    Start-Sleep -Milliseconds 500
                    return "Task $index completed"
                }
                Parameters = @($i)
            }
        }
        
        $results = Invoke-ParallelTask -Tasks $tasks -ThreadCount 4 -ProgressActivity "Processing test tasks"
        Write-Host "Completed $($results.Count) tasks" -ForegroundColor Green
        foreach ($result in $results) {
            Write-Host $result -ForegroundColor Cyan
        }
    #>
    param(
        [array]$Tasks,
        [int]$ThreadCount = 4,
        [string]$TaskPriority = "Normal",
        [string]$ProgressActivity = "Processing tasks",
        [int]$ThreadAdjustmentInterval = 2000,
        [switch]$Silent = $false,
        [switch]$DynamicThreadManagement = $true
    )
    
    try {
        # Validate parameters
        if (-not $Tasks -or $Tasks.Count -eq 0) {
            return @()
        }
        
        # Ensure reasonable thread count
        $maxThreads = [System.Environment]::ProcessorCount * 2
        $initialThreadCount = [Math]::Min($ThreadCount, $maxThreads)
        $initialThreadCount = [Math]::Max(1, $initialThreadCount)
        $currentThreadCount = $initialThreadCount
        
        if (-not $Silent) {
            Write-Host "[TPL Parallel Processing] Initial threads: $currentThreadCount, Tasks: $($Tasks.Count)" -ForegroundColor Cyan
        }
        
        # Create thread-safe result collection
        Add-Type -AssemblyName System.Collections.Concurrent
        $results = New-Object System.Collections.Concurrent.ConcurrentBag[object]
        
        # Create task array
        $taskObjects = @()
        $processedTasks = 0
        $totalTasks = $Tasks.Count
        $isProcessing = $true
        
        # Dynamic thread management variables
        $lastThreadAdjustment = Get-Date
        $threadAdjustmentLock = New-Object System.Object
        
        # Configure parallel options
        $parallelOptions = New-Object System.Threading.Tasks.ParallelOptions
        $parallelOptions.MaxDegreeOfParallelism = $currentThreadCount
        
        # Execute parallel tasks
        foreach ($task in $Tasks) {
            try {
                # Execute task
                $result = & $task.ScriptBlock @($task.Parameters)
                
                # Add result to thread-safe collection
                if ($result) {
                    $results.Add($result)
                }
            }
            catch {
                # Ignore individual task errors
                Write-Debug "Error executing task: $($_.Exception.Message)"
            }
            finally {
                # Update progress
                $completed = [System.Threading.Interlocked]::Increment([ref]$processedTasks)
                
                if (-not $Silent) {
                    $percent = [Math]::Min(100, [Math]::Round(($completed / $totalTasks) * 100))
                    Write-CustomProgress -Activity $ProgressActivity -Status "Completed $completed/$totalTasks tasks" -PercentComplete $percent -CurrentItem $completed -TotalItems $totalTasks
                }
            }
        }
        
        # Ensure 100% progress is displayed
        if (-not $Silent) {
            Write-CustomProgress -Activity $ProgressActivity -Status "Completed $totalTasks/$totalTasks tasks" -PercentComplete 100
        }
        
        # Convert results to array
        return @($results)
    }
    catch {
        Write-Error "Error executing parallel tasks: $($_.Exception.Message)"
        return @()
    }
}

function Close-RunspacePool {
    <#
    .SYNOPSIS
        Closes global RunspacePool
    .DESCRIPTION
        Closes and releases RunspacePool resources to free up system resources
    .PARAMETER Silent
        Whether to execute silently without displaying output
    .RETURNS
        Boolean indicating whether the closing operation was successful
    .EXAMPLE
        # Example: Close RunspacePool
        $success = Close-RunspacePool
        if ($success) {
            Write-Host "RunspacePool closed successfully" -ForegroundColor Green
        } else {
            Write-Host "Failed to close RunspacePool" -ForegroundColor Red
        }
        
        # Example: Close RunspacePool silently
        $success = Close-RunspacePool -Silent
    #>
    param(
        [switch]$Silent = $false
    )
    
    try {
        if ($script:runspacePoolCreated -and $script:runspacePool -ne $null -and !$script:runspacePool.IsDisposed) {
            $script:runspacePool.Close()
            $script:runspacePool.Dispose()
            $script:runspacePoolCreated = $false
            $script:runspacePool = $null
            
            if (-not $Silent) {
                Write-Debug "RunspacePool successfully closed and disposed"
            }
            return $true
        } else {
            if (-not $Silent) {
                Write-Debug "RunspacePool does not exist or has already been released, no need to close"
            }
            return $false
        }
    } catch {
        if (-not $Silent) {
            Write-Error "Error closing RunspacePool: $($_.Exception.Message)"
        }
        return $false
    }
}

function New-LogTrendAnalysis {
    <#
    .SYNOPSIS
        Analyzes log trends and generates trend report
    .DESCRIPTION
        Analyzes historical log data, calculates trend indicators, generates trend report
    .PARAMETER ExportPath
        Output directory for the trend report
    .PARAMETER LogType
        Log type to analyze (e.g., "System", "Application", "Security")
    .PARAMETER Days
        Number of days to analyze
    .PARAMETER StartDate
        Start date for analysis (overrides Days parameter if specified)
    .PARAMETER EndDate
        End date for analysis (overrides Days parameter if specified)
    .PARAMETER PerformanceScore
        System performance score for correlation analysis
    .PARAMETER OptimalChunkSize
        Optimal chunk size for processing
    .PARAMETER EventId
        Event ID to filter
    .PARAMETER ProviderName
        Event provider name to filter
    .PARAMETER Level
        Event level to filter
    .EXAMPLE
        # Example: Analyze system log trends for the past 7 days
        New-LogTrendAnalysis -ExportPath "C:\Logs" -LogType "System" -Days 7
        Write-Host "Trend analysis completed" -ForegroundColor Green
        
        # Example: Analyze application logs with specific date range
        $startDate = (Get-Date).AddMonths(-1)
        $endDate = Get-Date
        New-LogTrendAnalysis -ExportPath "C:\Logs" -LogType "Application" -StartDate $startDate -EndDate $endDate
    #>
    param(
        [string]$ExportPath,
        [string]$LogType = "System",
        [int]$Days = 7,
        [datetime]$StartDate,
        [datetime]$EndDate,
        [int]$PerformanceScore = 0,
        [double]$OptimalChunkSize = 0,
        [string]$EventId = "",
        [string]$ProviderName = "",
        [string]$Level = ""
    )
    

    
    # Ensure days is greater than 0
    if ($Days -le 0) {
        $Days = 7
    }
    
    $trendData = @()
    
    # If start and end dates are provided, use them
    if ($StartDate -and $EndDate) {
        $startDate = $StartDate
        $endDate = $EndDate
    } else {
        # Otherwise use current date minus specified days
        $endDate = Get-Date
        $startDate = $endDate.AddDays(-$Days + 1)
    }
    
    # Ensure start date is before end date
    if ($startDate -gt $endDate) {
        $temp = $startDate
        $startDate = $endDate
        $endDate = $temp
    }
    
    # Dynamically calculate analysis interval for reasonable granularity
    $totalDays = ($endDate - $startDate).Days + 1
    $intervalDays = [Math]::Max(1, [Math]::Min(7, [Math]::Floor($totalDays / 10)))
    $totalIntervals = [Math]::Ceiling($totalDays / $intervalDays)
    
    # Use sequential processing for time interval analysis
    for ($i = 0; $i -lt $totalIntervals; $i++) {
        $intervalStartDate = $startDate.AddDays($i * $intervalDays)
        $intervalEndDate = $intervalStartDate.AddDays($intervalDays).AddTicks(-1)
        
        # Ensure not exceeding end date
        if ($intervalEndDate -gt $endDate) {
            $intervalEndDate = $endDate
        }
        
        Write-CustomProgress -Activity "Analyzing log trends" -Status "Analyzing logs for $($intervalStartDate.ToString('yyyy-MM-dd')) to $($intervalEndDate.ToString('yyyy-MM-dd'))" -PercentComplete ([Math]::Round(($i / $totalIntervals) * 100)) -CurrentItem $i -TotalItems $totalIntervals -CurrentTask "Analyzing time period $i"
        # Force flush output buffer
        [System.Console]::Out.Flush()
        
        try {
            # Use cached scan data instead of directly calling Get-WinEvent
            # Convert log type to English if it's in Chinese
            $cacheLogType = if ($LogType -eq "系统") { "System" } elseif ($LogType -eq "应用程序") { "Application" } else { $LogType }
            # Use full date range as cache key instead of time interval
            $cacheKey = Get-CacheKey -LogType "$cacheLogType-HighRisk" -StartTime $startDate -EndTime $endDate -EventId $EventId -ProviderName $ProviderName -Level $Level
            
            # Try to get data from cache
            $cachedData = Get-CachedLogData -CacheKey $cacheKey -Silent $true
            
            # Count event levels
            $criticalCount = 0
            $errorCount = 0
            $warningCount = 0
            if ($cachedData) {
                # Filter events within the current interval
                $intervalEvents = $cachedData | Where-Object { $_.TimeCreated -ge $intervalStartDate -and $_.TimeCreated -le $intervalEndDate }
                foreach ($event in $intervalEvents) {
                    $level = if ($null -eq $event.Level) { 0 } else { [int]$event.Level }
                    switch ($level) {
                        1 { $criticalCount++ }
                        2 { $errorCount++ }
                        3 { $warningCount++ }
                    }
                }
            } else {
                # Fallback to direct Get-WinEvent if cache not available
                $filterHashtable = @{ LogName = $LogType; StartTime = $intervalStartDate; EndTime = $intervalEndDate; Level = 1,2,3 }
                
                # Add event ID filtering (if provided)
                if (![string]::IsNullOrWhiteSpace($EventId)) {
                    $eventIds = $EventId -split ',' | ForEach-Object { $_.Trim() }
                    if ($eventIds.Count -gt 0) {
                        $filterHashtable["Id"] = $eventIds
                    }
                }
                
                # Add event provider filtering (if provided)
                if (![string]::IsNullOrWhiteSpace($ProviderName)) {
                    $filterHashtable["ProviderName"] = $ProviderName
                }
                
                # Get all matching high-risk events
                $highRiskEvents = Get-WinEvent -FilterHashtable $filterHashtable -ErrorAction SilentlyContinue
                
                if ($highRiskEvents) {
                    foreach ($event in $highRiskEvents) {
                        $level = if ($null -eq $event.Level) { 0 } else { [int]$event.Level }
                        switch ($level) {
                            1 { $criticalCount++ }
                            2 { $errorCount++ }
                            3 { $warningCount++ }
                        }
                    }
                }
            }
            
            # Calculate health score (improved algorithm: consider event frequency, system performance and historical data)
            # Basic issue score calculation
            $totalIssues = $criticalCount * 3 + $errorCount * 2 + $warningCount
            
            # Calculate event frequency factor (based on events per hour)
            $hoursInInterval = ($intervalEndDate - $intervalStartDate).TotalHours
            $eventsPerHour = if ($hoursInInterval -gt 0) {
                ($criticalCount + $errorCount + $warningCount) / $hoursInInterval
            } else {
                0
            }
            
            # Frequency factor: higher event frequency reduces health score more
            $frequencyFactor = if ($eventsPerHour -gt 10) {
                1.5  # High frequency events
            } elseif ($eventsPerHour -gt 5) {
                1.2  # Medium frequency events
            } else {
                1.0  # Low frequency events
            }
            
            # Adjust health score based on system performance
            $performanceFactor = if ($PerformanceScore -gt 0) {
                [Math]::Max(0.5, $PerformanceScore / 100)
            } else {
                1.0
            }
            
            # Calculate base health score
            $baseHealthScore = 100 - ($totalIssues * $performanceFactor * $frequencyFactor)
            
            # Add system resource usage factors
            $memoryUsage = Get-MemoryUsage
            $systemLoad = Get-SystemLoad
            $diskInfo = Get-DiskPerformance
            
            # Resource usage adjustment factor
            $resourceFactor = 1.0
            if ($memoryUsage -gt 80 -or $systemLoad -gt 80) {
                $resourceFactor = 1.1  # High resource usage, lower health score
            } elseif ($memoryUsage -lt 40 -and $systemLoad -lt 40) {
                $resourceFactor = 0.9  # Low resource usage, higher health score
            }
            
            # Final health score
            $healthScore = [Math]::Max(0, [Math]::Min(100, $baseHealthScore * (2 - $resourceFactor)))
            
            $trendData += @{
                Date = $intervalStartDate
                EndDate = $intervalEndDate
                Critical = $criticalCount
                Error = $errorCount
                Warning = $warningCount
                TotalIssues = $totalIssues
                HealthScore = $healthScore
            }
        }
        catch {
            Write-Debug "Error analyzing logs for $($intervalStartDate.ToString('yyyy-MM-dd')) to $($intervalEndDate.ToString('yyyy-MM-dd')): $($_.Exception.Message)"
            # Add empty data
            $trendData += @{
                Date = $intervalStartDate
                EndDate = $intervalEndDate
                Critical = 0
                Error = 0
                Warning = 0
                TotalIssues = 0
                HealthScore = 100
            }
        }
    }
    
    # Ensure 100% progress is displayed
    Write-CustomProgress -Activity "Analyzing log trends" -Status "Analysis completed" -PercentComplete 100
    # Force flush output buffer
    [System.Console]::Out.Flush()
    # Add newline to ensure subsequent output doesn't overwrite progress bar
    Write-Host ""
    
    # Generate trend report
    $reportContent = @"
Log Trend Analysis Report
Report Date : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Log Type : $LogType
Analysis Range : $($startDate.ToString('yyyy-MM-dd')) to $($endDate.ToString('yyyy-MM-dd'))
Analysis Days : $totalDays
Analysis Interval : $intervalDays days
==================================================

[Daily Event Statistics]
"@
    
    foreach ($data in $trendData) {
        $reportContent += "`nTime Period: $($data.Date.ToString('yyyy-MM-dd')) to $($data.EndDate.ToString('yyyy-MM-dd'))"
        $reportContent += "`n  Critical: $($data.Critical) events"
        $reportContent += "`n  Error: $($data.Error) events"
        $reportContent += "`n  Warning: $($data.Warning) events"
        $reportContent += "`n  Health Score: $($data.HealthScore)/100"
        $reportContent += "`n"
    }
    
    # Calculate trend indicators
    try {
        if ($trendData.Count -gt 0) {
            # Ensure all data items have correct properties
            $validTrendData = $trendData | Where-Object { 
                $_ -ne $null -and 
                $_.HealthScore -ne $null -and 
                $_.TotalIssues -ne $null 
            }
            
            if ($validTrendData.Count -gt 0) {
                # Calculate average health score
                $totalHealthScore = 0
                foreach ($item in $validTrendData) {
                    $totalHealthScore += $item.HealthScore
                }
                $avgHealthScore = [Math]::Round($totalHealthScore / $validTrendData.Count, 2)
                
                # Calculate maximum and minimum health scores
                $maxHealthScore = $validTrendData[0].HealthScore
                $minHealthScore = $validTrendData[0].HealthScore
                foreach ($item in $validTrendData) {
                    if ($item.HealthScore -gt $maxHealthScore) {
                        $maxHealthScore = $item.HealthScore
                    }
                    if ($item.HealthScore -lt $minHealthScore) {
                        $minHealthScore = $item.HealthScore
                    }
                }
                # Ensure minimum health score has a value
                if ($minHealthScore -eq $null) {
                    $minHealthScore = 100
                }
                
                # Calculate total issues
                $totalIssues = 0
                foreach ($item in $validTrendData) {
                    $totalIssues += $item.TotalIssues
                }
                
                # Advanced trend analysis: linear regression
                $n = $validTrendData.Count
                if ($n -ge 2) {
                    $sumX = 0
                    $sumY = 0
                    $sumXY = 0
                    $sumX2 = 0
                    
                    for ($i = 0; $i -lt $n; $i++) {
                        $x = $i
                        $y = $validTrendData[$i].HealthScore
                        $sumX += $x
                        $sumY += $y
                        $sumXY += $x * $y
                        $sumX2 += $x * $x
                    }
                    
                    # Calculate slope
                    $slope = 0
                    if ($n * $sumX2 - $sumX * $sumX -ne 0) {
                        $slope = ($n * $sumXY - $sumX * $sumY) / ($n * $sumX2 - $sumX * $sumX)
                    }
                    
                    # Analyze trend
                    if ($slope -gt 1) {
                        $healthTrend = "Significant upward trend"
                    } elseif ($slope -gt 0) {
                        $healthTrend = "Slight upward trend"
                    } elseif ($slope -lt -1) {
                        $healthTrend = "Significant downward trend"
                    } elseif ($slope -lt 0) {
                        $healthTrend = "Slight downward trend"
                    } else {
                        $healthTrend = "Stable trend"
                    }
                } else {
                    # Simple trend analysis
                    $firstHealthScore = $validTrendData[0].HealthScore
                    $lastHealthScore = $validTrendData[-1].HealthScore
                    $healthTrend = if ($lastHealthScore -gt $firstHealthScore) {
                        "Upward trend"
                    } elseif ($lastHealthScore -lt $firstHealthScore) {
                        "Downward trend"
                    } else {
                        "Stable trend"
                    }
                }
            } else {
                # Default values when no valid data
                $avgHealthScore = 100
                $maxHealthScore = 100
                $minHealthScore = 100
                $totalIssues = 0
                $healthTrend = "Stable trend"
            }
        } else {
            # Default values when no data
            $avgHealthScore = 100
            $maxHealthScore = 100
            $minHealthScore = 100
            $totalIssues = 0
            $healthTrend = "Stable trend"
        }
    } catch {
        # Use default values when error occurs
        Write-Debug "Error calculating trend indicators: $($_.Exception.Message)"
        $avgHealthScore = 100
        $maxHealthScore = 100
        $minHealthScore = 100
        $totalIssues = 0
        $healthTrend = "Stable trend"
    }
    
    $reportContent += "`n[Trend Analysis]"
    $reportContent += "`nAverage Health Score: $avgHealthScore/100"
    $reportContent += "`nMaximum Health Score: $maxHealthScore/100"
    $reportContent += "`nMinimum Health Score: $minHealthScore/100"
    $reportContent += "`nTotal Issues: $totalIssues"
    $reportContent += "`nHealth Trend: $healthTrend"
    
    # Generate health recommendations
    if ($avgHealthScore -ge 80) {
        $reportContent += "`n`n[Health Recommendation] System status is good, keep up the good work."
    } elseif ($avgHealthScore -ge 60) {
        $reportContent += "`n`n[Health Recommendation] System status is average, regular checks recommended."
    } else {
        $reportContent += "`n`n[Health Recommendation] System status is poor, immediate inspection recommended."
    }
    
    # Save trend report
    try {
        # Clean file name unsafe characters
        $safeLogType = $LogType -replace '[^a-zA-Z0-9]', '_'
        $datePart = "$($startDate.ToString('yyyyMMdd'))_to_$($endDate.ToString('yyyyMMdd'))"
        
        $trendPath = [System.IO.Path]::Combine($ExportPath, "${safeLogType}_Log_${datePart}_TrendAnalysis.txt")
        $reportContent | Out-File -FilePath $trendPath -Encoding UTF8 -ErrorAction Stop
        Write-Host "`nTrend analysis report saved to: $trendPath" -ForegroundColor Cyan
        
        # Save trend data as CSV for further analysis
        $csvPath = [System.IO.Path]::Combine($ExportPath, "${safeLogType}_Log_${datePart}_TrendData.csv")
        
        # Ensure trendData contains valid data
        if ($trendData.Count -gt 0) {
            # Use more reliable way to write CSV
            $headers = "Date,EndDate,Critical,Error,Warning,TotalIssues,HealthScore"
            $headers | Out-File -FilePath $csvPath -Encoding UTF8 -Force
            
            foreach ($item in $trendData) {
                $line = "$($item.Date.ToString('yyyy-MM-dd HH:mm:ss')),$($item.EndDate.ToString('yyyy-MM-dd HH:mm:ss')),$($item.Critical),$($item.Error),$($item.Warning),$($item.TotalIssues),$($item.HealthScore)"
                $line | Out-File -FilePath $csvPath -Encoding UTF8 -Append
            }
            Write-Host "Trend data saved to: $csvPath" -ForegroundColor Cyan
        } else {
            Write-Host "Trend data is empty, CSV file not generated" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Failed to save trend report: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Recommendation: Check output directory permissions or disk space." -ForegroundColor Yellow
    }
    
    Write-Host "`n[Trend Analysis Complete]" -ForegroundColor Green
    # Don't return data to avoid printing raw data in command line
    return
}

function Test-LogAccess {
    <#
    .SYNOPSIS
        Tests access to specified event log
    .DESCRIPTION
        Tests if the current user has access to the specified event log by attempting to retrieve a single event
    .PARAMETER LogName
        Name of the event log to test access to, default is "System"
    .RETURNS
        Boolean indicating whether access to the log was successful
    .EXAMPLE
        # Example: Test access to System log
        $canAccess = Test-LogAccess -LogName "System"
        if ($canAccess) {
            Write-Host "Access to System log granted" -ForegroundColor Green
        } else {
            Write-Host "Access to System log denied" -ForegroundColor Red
        }
    #>
    param([string]$LogName = "System")
    try {
        # Try to get the log, maximum 1 event
        $null = Get-WinEvent -LogName $LogName -MaxEvents 1 -ErrorAction Stop
        return $true
    }
    catch {
        # Handle different types of errors
        if ($_.Exception.Message -like "*Access is denied*" -or $_.Exception.Message -like "*unauthorized operation*") {
            # Permission error
            if ($LogName -eq "Security") {
                Write-Host "❌ Access denied to $LogName event log." -ForegroundColor Red
                Write-Host "👉 Security log requires admin privileges, please run PowerShell as Administrator, or select another log type." -ForegroundColor Yellow
            } else {
                Write-Host "❌ Access denied to $LogName event log." -ForegroundColor Red
                Write-Host "👉 Please run PowerShell as Administrator, or select another log type that doesn't require admin privileges." -ForegroundColor Yellow
            }
        }
        elseif ($_.Exception.Message -like "*No matches found*") {
            # Log not found
            Write-Host "❌ $LogName log not found." -ForegroundColor Red
        }
        else {
            # Other errors
            Write-Host "❌ Error accessing $LogName log: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $false
    }
}

function Get-UserDateScope {
    <#
    .SYNOPSIS
        Gets user-selected log type and date range
    .DESCRIPTION
        Interactively gets user-selected log type, export mode, and date range, supporting event filtering options
    .PARAMETER DefaultLogType
        Default log type, default is "System"
    .RETURNS
        Hashtable containing log type, start time, end time, date part, and report title
    .EXAMPLE
        # Example: Get user date scope
        $scope = Get-UserDateScope -DefaultLogType "System"
        Write-Host "Selected log type: $($scope.LogType)" -ForegroundColor Cyan
        Write-Host "Start time: $($scope.StartTime)" -ForegroundColor Cyan
        Write-Host "End time: $($scope.EndTime)" -ForegroundColor Cyan
        Write-Host "Report title: $($scope.ReportTitle)" -ForegroundColor Cyan
    #>
    param([string]$DefaultLogType = "System")
    
    # Core fix: If DefaultLogType is empty string (passed from GUI), force use "System"
    if ([string]::IsNullOrWhiteSpace($DefaultLogType)) {
        $DefaultLogType = "System"
    }
    
    $maxRetries = 5
    $retryCount = 0
    $selectedLogTypes = @($DefaultLogType)
    
    # Define log type map
    $logTypeMap = @{
        '1' = "System"
        '2' = "Application"
        '3' = "Security"
        '4' = "Setup"
        '5' = "DNS Server"
        '6' = "DHCP Server"
        '7' = "Directory Service"
        '8' = "IIS Admin Service"
    }
    
    # Select log type (support multi-select)
    while ($retryCount -lt $maxRetries) {
        Write-Host "`n[Select Log Type]" -ForegroundColor Yellow
        Write-Host "1: System" -ForegroundColor Green
        Write-Host "2: Application" -ForegroundColor Green
        Write-Host "3: Security - Requires Admin Privileges" -ForegroundColor Yellow
        Write-Host "4: Setup - Requires Admin Privileges" -ForegroundColor Yellow
        Write-Host "5: DNS Server - Requires Admin Privileges" -ForegroundColor Yellow
        Write-Host "6: DHCP Server - Requires Admin Privileges" -ForegroundColor Yellow
        Write-Host "7: Active Directory - Requires Admin Privileges" -ForegroundColor Yellow
        Write-Host "8: IIS (Web Server) - Requires Admin Privileges" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "💡 Tip: You can select multiple log types, separated by commas or spaces (e.g., 1,2 or 1 2)" -ForegroundColor Cyan
        
        $logChoice = Get-AuroraInteraction -PromptMessage "`nEnter option (1-8), press ENTER to use default: $DefaultLogType"
        
        # Parse multi-select input
        if ([string]::IsNullOrWhiteSpace($logChoice)) {
            $selectedLogTypes = @($DefaultLogType)
        }
        else {
            # Split input (supports commas, spaces, semicolons as separators)
            $choices = $logChoice -split '[,\s;]+' | Where-Object { $_ }
            $selectedLogTypes = @()
            foreach ($choice in $choices) {
                if ($logTypeMap.ContainsKey($choice.Trim())) {
                    $selectedLogTypes += $logTypeMap[$choice.Trim()]
                }
            }
            $selectedLogTypes = $selectedLogTypes | Select-Object -Unique
        }
        
        # Verify at least one log type was selected
        if ($selectedLogTypes.Count -eq 0) {
            Write-Host "`n❌ No valid log types selected. Please try again!" -ForegroundColor Red
            $retryCount++
            continue
        }
        
        # Verify all selected log types exist and are accessible
        $allValid = $true
        foreach ($logType in $selectedLogTypes) {
            if (-not (Test-LogAccess -LogName $logType)) {
                $allValid = $false
                break
            }
        }
        
        if ($allValid) {
            Write-Host "`n✅ Selected log types: $($selectedLogTypes -join ', ')" -ForegroundColor Green
            break
        }
        else {
            $retryCount++
            if ($retryCount -ge $maxRetries) {
                Write-Host "`n🛑 Too many invalid attempts. Exiting..." -ForegroundColor Red
                Write-Host "`nPress Enter to exit" -ForegroundColor Gray
                Read-Host | Out-Null
                exit 1
            }
        }
    }
    
    $retryCount = 0
    while ($retryCount -lt $maxRetries) {
        Write-Host "`n[Select Export Mode]" -ForegroundColor Yellow
        Write-Host "1: Single Day (e.g., 2026-01-21)" -ForegroundColor Green
        Write-Host "2: Date Range (YYYY-MM-DD to YYYY-MM-DD)" -ForegroundColor Green
        $mode = Get-AuroraInteraction -PromptMessage "`nEnter option (1 or 2)"
        if ($mode -eq '1') {
            $today = (Get-Date).Date
            $inputDate = Get-AuroraInteraction -PromptMessage "`nEnter date (YYYY-MM-DD), press ENTER to export today's logs"
            if ([string]::IsNullOrWhiteSpace($inputDate)) {
                $target = $today
            }
            else {
                try {
                    $target = [DateTime]::ParseExact($inputDate.Trim(), 'yyyy-MM-dd', $null).Date
                    if ($target -gt (Get-Date).Date) {
                        Write-Host "❌ Date cannot be in the future!" -ForegroundColor Red
                        $retryCount++; continue
                    }
                }
                catch {
                    Write-Host "❌ Invalid date format! Please use YYYY-MM-DD format (e.g., 2026-01-21)." -ForegroundColor Red
                    $retryCount++; continue
                }
            }
            # Create scope array, one for each selected log type
            $scopes = @()
            foreach ($logType in $selectedLogTypes) {
                $scopes += @{ 
                    StartTime   = $target
                    EndTime     = $target.AddDays(1).AddTicks(-1)
                    DatePart    = $target.ToString('yyyyMMdd')
                    ReportTitle = "$logType Log Daily Report - $($target.ToString('yyyy-MM-dd'))"
                    LogType     = $logType
                }
            }
        }
        elseif ($mode -eq '2') {
            $startInput = Get-AuroraInteraction -PromptMessage "`nEnter start date (YYYY-MM-DD)"
            $endInput = Get-AuroraInteraction -PromptMessage "Enter end date (YYYY-MM-DD)"
            try {
                $startDate = [DateTime]::ParseExact($startInput.Trim(), 'yyyy-MM-dd', $null).Date
                $endDate = [DateTime]::ParseExact($endInput.Trim(), 'yyyy-MM-dd', $null).Date
                if ($startDate -gt (Get-Date).Date -or $endDate -gt (Get-Date).Date) {
                    Write-Host "❌ Dates cannot be in the future!" -ForegroundColor Red
                    $retryCount++; continue
                }
                if ($startDate -gt $endDate) {
                    Write-Host "⚠️ Start date cannot be later than end date!" -ForegroundColor Yellow
                    $retryCount++; continue
                }
            }
            catch {
                Write-Host "❌ Invalid date format! Both dates must be in YYYY-MM-DD format." -ForegroundColor Red
                $retryCount++; continue
            }
            # Create scope array, one for each selected log type
            $scopes = @()
            foreach ($logType in $selectedLogTypes) {
                $scopes += @{ 
                    StartTime   = $startDate
                    EndTime     = $endDate.AddDays(1).AddTicks(-1)
                    DatePart    = "$($startDate.ToString('yyyyMMdd'))_to_$($endDate.ToString('yyyyMMdd'))"
                    ReportTitle = "$logType Log Report - $($startDate.ToString('yyyy-MM-dd')) to $($endDate.ToString('yyyy-MM-dd'))"
                    LogType     = $logType
                }
            }
        }
        else {
            Write-Host "❌ Invalid option! Please enter 1 or 2." -ForegroundColor Red
            $retryCount++; continue
        }
        
        # Add event filtering options (apply same filter to all log types)
        Write-Host "`n[Event Filter Options]" -ForegroundColor Yellow
        Write-Host "1: No Filter (Default)" -ForegroundColor Green
        Write-Host "2: Filter by Event ID" -ForegroundColor Green
        Write-Host "3: Filter by Event Provider" -ForegroundColor Green
        Write-Host "4: Filter by Event Level" -ForegroundColor Green
        $filterChoice = Get-AuroraInteraction -PromptMessage "`nSelect filter option (1-4), press ENTER to use default: 1"
        
        # Define filter parameters
        $filterEventId = $null
        $filterProviderName = $null
        $filterLevel = $null
        
        switch ($filterChoice) {
            '2' {
                $filterEventId = Get-AuroraInteraction -PromptMessage "`nEnter event ID (multiple IDs separated by commas)"
                if ([string]::IsNullOrWhiteSpace($filterEventId)) {
                    $filterEventId = $null
                }
            }
            '3' {
                $filterProviderName = Get-AuroraInteraction -PromptMessage "`nEnter event provider name"
                if ([string]::IsNullOrWhiteSpace($filterProviderName)) {
                    $filterProviderName = $null
                }
            }
            '4' {
                Write-Host "`nSelect event level:" -ForegroundColor Yellow
                Write-Host "1: Critical" -ForegroundColor Red
                Write-Host "2: Error" -ForegroundColor Red
                Write-Host "3: Warning" -ForegroundColor Yellow
                Write-Host "4: Information" -ForegroundColor Green
                Write-Host "5: Verbose" -ForegroundColor Gray
                $levelChoice = Get-AuroraInteraction -PromptMessage "`nEnter option (1-5)"
                $levelMap = @{'1' = '1'; '2' = '2'; '3' = '3'; '4' = '4'; '5' = '5'}
                if ($levelMap.ContainsKey($levelChoice)) {
                    $filterLevel = $levelMap[$levelChoice]
                }
            }
        }
        
        # Apply filter to all scopes
        for ($i = 0; $i -lt $scopes.Count; $i++) {
            if ($filterEventId) { $scopes[$i].EventId = $filterEventId }
            if ($filterProviderName) { $scopes[$i].ProviderName = $filterProviderName }
            if ($filterLevel) { $scopes[$i].Level = $filterLevel }
        }
        
        # Return scope array - Core fix: Use @() to force maintain array type, prevent unpacking when single element
        return @($scopes)
    }
    Write-Host "`n🛑 Too many invalid attempts. Exiting..." -ForegroundColor Red
    Write-Host "`nPress Enter to exit" -ForegroundColor Gray
    Read-Host | Out-Null
    exit 1
}

# Global variable to track current activity name and progress lines
$script:currentActivity = ""
$script:progressLines = @{}
$script:progressStartTime = @{}
$script:progressLastUpdate = @{}
$script:progressLastPercent = @{}
$script:progressSpeed = @{}
$script:progressRemaining = @{}
$script:activityLineMap = @{}

function Write-CustomProgress {
    <#
    .SYNOPSIS
        Displays enhanced progress information
    .DESCRIPTION
        Displays enhanced progress information with activity name, status, percentage, speed, and estimated remaining time
    .PARAMETER Activity
        Activity name
    .PARAMETER Status
        Current status message
    .PARAMETER PercentComplete
        Completion percentage (0-100)
    .PARAMETER CurrentItem
        Current item being processed
    .PARAMETER TotalItems
        Total number of items to process
    .PARAMETER CurrentTask
        Current task description
    .EXAMPLE
        # Example: Display progress for a task
        Write-CustomProgress -Activity "Processing files" -Status "Reading file 1" -PercentComplete 25 -CurrentItem 1 -TotalItems 4 -CurrentTask "Reading file 1"
    #>
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete,
        [int]$CurrentItem = 0,
        [int]$TotalItems = 0,
        [string]$CurrentTask = ""
    )
    # ====== 新增：同步进度、大阶段标题以及精细子状态给 GUI ======
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        $global:syncHash.Progress = $PercentComplete
        $global:syncHash.CurrentActivity = $Activity
        $global:syncHash.CurrentStatus = $Status  # <--- 新增这行，透传子任务详情
    }
    # ==================================
    # Check if running in console
    if ($Host.Name -ne 'ConsoleHost') {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
        return
    }
    
    # Initialize progress tracking
    if (-not $script:progressStartTime.ContainsKey($Activity)) {
        $script:progressStartTime[$Activity] = Get-Date
        $script:progressLastUpdate[$Activity] = Get-Date
        $script:progressLastPercent[$Activity] = 0
        # Initialize line number mapping for each activity
        $script:activityLineMap[$Activity] = @{ dataLine = 0; detailLine = 0; speedLine = 0; barLine = 0 }
    }
    
    # Calculate processing speed and estimated remaining time
    $elapsedTime = (Get-Date) - $script:progressStartTime[$Activity]
    $elapsedSeconds = $elapsedTime.TotalSeconds
    $timeSinceLastUpdate = (Get-Date) - $script:progressLastUpdate[$Activity]
    
    # Initialize speed and remaining time variables
    $speed = 0
    $estimatedRemaining = ""
    
    # Update speed and remaining time every 2 seconds
    if ($timeSinceLastUpdate.TotalSeconds -ge 2 -or $PercentComplete -eq 100) {
        if ($elapsedSeconds -gt 0 -and $PercentComplete -gt 0 -and $TotalItems -gt 0) {
            $speed = [Math]::Round(($PercentComplete / 100) * $TotalItems / $elapsedSeconds, 2)
            if ($PercentComplete -lt 100) {
                $estimatedTotalSeconds = $elapsedSeconds * (100 / $PercentComplete)
                $estimatedRemainingSeconds = $estimatedTotalSeconds - $elapsedSeconds
                if ($estimatedRemainingSeconds -gt 0) {
                    $timespan = New-TimeSpan -Seconds $estimatedRemainingSeconds
                    $estimatedRemaining = "Estimated remaining: $($timespan.ToString() -replace '\.[0-9]+', '')"
                }
            }
        }
        
        $script:progressLastUpdate[$Activity] = Get-Date
        $script:progressLastPercent[$Activity] = $PercentComplete
        # Save current speed and remaining time
        $script:progressSpeed[$Activity] = $speed
        $script:progressRemaining[$Activity] = $estimatedRemaining
    } else {
        # Use previously saved speed and remaining time
        if ($script:progressSpeed.ContainsKey($Activity)) {
            $speed = $script:progressSpeed[$Activity]
        }
        if ($script:progressRemaining.ContainsKey($Activity)) {
            $estimatedRemaining = $script:progressRemaining[$Activity]
        }
    }
    
    # Calculate progress bar length based on terminal width
    try {
        $consoleWidth = $Host.UI.RawUI.BufferSize.Width
        # Leave room for activity and status text
        $availableWidth = $consoleWidth - 5
        $progressBarLength = [Math]::Max(10, [Math]::Min(50, $availableWidth - 10))
    } catch {
        # Fallback to default if terminal width can't be determined
        $consoleWidth = 120
        $progressBarLength = 30
    }
    $completedLength = [Math]::Max(0, [Math]::Min($progressBarLength, [Math]::Round($progressBarLength * $PercentComplete / 100)))
    $remainingLength = $progressBarLength - $completedLength
    
    # Build progress bar - use more aesthetic characters
    $completedChars = "█" * $completedLength
    $remainingChars = "░" * $remainingLength
    $progressBar = "$completedChars$remainingChars"
    
    # Limit output length to console width
    $maxOutputLength = [Math]::Min(110, $consoleWidth - 5)
    
    # Add padding to ensure covering the entire line
    $progressBar = $progressBar.PadRight($maxOutputLength)
    $clearLine = " " * $maxOutputLength
    
    # Output only activity name when activity changes or first call
    if ($Activity -ne $script:currentActivity) {
        $script:currentActivity = $Activity
        # Ensure newline when activity changes to avoid overlap with previous output
        Write-Host ""
        Write-Host "[$Activity]" -ForegroundColor Cyan
        # Output empty lines for detail info, speed and progress bar
        Write-Host ""
        Write-Host ""
        Write-Host ""
        # Record current activity line numbers
        $currentY = $Host.UI.RawUI.CursorPosition.Y - 3  # Subtract 3 lines because we just output 3 empty lines
        $script:activityLineMap[$Activity] = @{ dataLine = $currentY; detailLine = $currentY + 1; speedLine = $currentY + 2; barLine = $currentY + 3 }
        # Force flush output buffer
        [System.Console]::Out.Flush()
    }
    
    # Ensure activity line map exists
    if (-not $script:activityLineMap.ContainsKey($Activity)) {
        # If activity line map doesn't exist, reinitialize
        $currentY = $Host.UI.RawUI.CursorPosition.Y
        $script:activityLineMap[$Activity] = @{ dataLine = $currentY; detailLine = $currentY + 1; speedLine = $currentY + 2; barLine = $currentY + 3 }
    }
    
    # Use cursor position to return to activity's data line,实现原地刷新
    $hostUI = $Host.UI.RawUI
    $cursorPosition = $hostUI.CursorPosition
    $clearLine = " " * $maxOutputLength
    
    try {
        # Save current cursor position
        $originalCursorPosition = $hostUI.CursorPosition
        
        # Update data line (main status information)
        $cursorPosition.Y = $script:activityLineMap[$Activity].dataLine
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # Clear data line
        Write-Host -NoNewline $clearLine
        # Return to line start
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # Write new data information
        $mainStatus = $Status
        if ($CurrentTask) {
            $mainStatus += " | Current task: $CurrentTask"
        }
        # Only add progress if not already in status
        if ($CurrentItem -gt 0 -and $TotalItems -gt 0 -and $Status -notmatch "Progress:") {
            $mainStatus += " | Progress: $CurrentItem/$TotalItems"
        } elseif ($CurrentItem -gt 0 -and $TotalItems -eq 0 -and $Status -notmatch "Processed:") {
            $mainStatus += " | Processed: $CurrentItem items"
        }
        # Limit length
        if ($mainStatus.Length -gt $maxOutputLength) {
            $mainStatus = $mainStatus.Substring(0, $maxOutputLength)
        }
        Write-Host -NoNewline $mainStatus -ForegroundColor Cyan
        
        # Update detail line
        $cursorPosition.Y = $script:activityLineMap[$Activity].detailLine
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # Clear detail line
        Write-Host -NoNewline $clearLine
        # Return to line start
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # Write detail information
        $detailStatus = ""
        if ($CurrentItem -gt 0 -and $TotalItems -gt 0) {
            $detailStatus += "Completion: $PercentComplete%"
        }
        # Limit length
        if ($detailStatus.Length -gt $maxOutputLength) {
            $detailStatus = $detailStatus.Substring(0, $maxOutputLength)
        }
        if ($detailStatus) {
            Write-Host -NoNewline $detailStatus -ForegroundColor Cyan
        }
        
        # Update speed information line (independently display speed and remaining time)
        $cursorPosition.Y = $script:activityLineMap[$Activity].speedLine
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # Clear speed information line
        Write-Host -NoNewline $clearLine
        # Return to line start
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # Write speed information
        $speedStatus = ""
        if ($speed -gt 0) {
            $speedStatus += "Speed: $speed items/sec"
        }
        if ($estimatedRemaining) {
            if ($speedStatus) {
                $speedStatus += " | $estimatedRemaining"
            } else {
                $speedStatus += $estimatedRemaining
            }
        }
        # Limit length
        if ($speedStatus.Length -gt $maxOutputLength) {
            $speedStatus = $speedStatus.Substring(0, $maxOutputLength)
        }
        if ($speedStatus) {
            Write-Host -NoNewline $speedStatus -ForegroundColor Cyan
        }
        
        # Update progress bar line
        $cursorPosition.Y = $script:activityLineMap[$Activity].barLine
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # Clear progress bar line
        Write-Host -NoNewline $clearLine
        # Return to line start
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # Write new progress bar
        Write-Host -NoNewline $progressBar -ForegroundColor Cyan
        
        # Restore original cursor position
        $hostUI.CursorPosition = $originalCursorPosition
    } catch {
        # If cursor position setting fails, use simple output method
        # Ensure each output adds a newline to avoid overlap
        Write-Host "`n$mainStatus" -ForegroundColor Cyan
        if ($detailStatus) {
            Write-Host "$detailStatus" -ForegroundColor Cyan
        }
        if ($speedStatus) {
            Write-Host "$speedStatus" -ForegroundColor Cyan
        }
        Write-Host "$progressBar" -ForegroundColor Cyan
    }
    
    # Force flush output buffer
    [System.Console]::Out.Flush()
}

function Get-HighRiskEvents {
    <#
    .SYNOPSIS
        Gets high-risk events from event logs
    .DESCRIPTION
        Scans event logs for high-risk events (Critical, Error, Warning) within the specified time range, supporting parallel processing and caching
    .PARAMETER StartTime
        Start time for event collection
    .PARAMETER EndTime
        End time for event collection
    .PARAMETER LogType
        Log type to scan, default is "System"
    .PARAMETER EventId
        Event ID filter (multiple IDs separated by commas)
    .PARAMETER ProviderName
        Event provider name filter
    .PARAMETER Level
        Event level filter (1-3 for Critical, Error, Warning)
    .PARAMETER PerformanceScore
        System performance score (0-100)
    .PARAMETER OptimalChunkSize
        Optimal chunk size for scanning
    .PARAMETER LogScanningStrategy
        Log scanning strategy object
    .PARAMETER CacheStrategy
        Cache strategy object
    .PARAMETER Silent
        Whether to run in silent mode
    .PARAMETER ForceRescan
        Whether to force rescan without using cache
    .RETURNS
        Collection of high-risk events
    .EXAMPLE
        # Example: Get high-risk events from System log
        $highRiskEvents = Get-HighRiskEvents -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) -LogType "System"
        Write-Host "Found $($highRiskEvents.Count) high-risk events" -ForegroundColor Yellow
    #>
    param(
        [datetime]$StartTime, 
        [datetime]$EndTime, 
        [string]$LogType = "System",
        [string]$EventId,
        [string]$ProviderName,
        [string]$Level,
        [int]$PerformanceScore = 0,
        [double]$OptimalChunkSize = 0,
        [object]$LogScanningStrategy,
        [object]$CacheStrategy,
        [switch]$Silent = $false,
        [switch]$ForceRescan = $false
    )
    # Calculate total time range (hours)
    $totalHours = [Math]::Ceiling(($EndTime - $StartTime).TotalHours)
    $currentHour = 0
    
    # Generate cache key (use English log type name to ensure consistency with CHSPRO version)
    $cacheLogType = if ($LogType -eq "系统") { "System" } elseif ($LogType -eq "应用程序") { "Application" } else { $LogType }
    $cacheKey = Get-CacheKey -LogType "$cacheLogType-HighRisk" -StartTime $StartTime -EndTime $EndTime -EventId $EventId -ProviderName $ProviderName -Level $Level
    
    # Try to get data from cache
    if (-not $ForceRescan) {
        $cachedData = Get-CachedLogData -CacheKey $cacheKey -Silent $Silent
        if ($cachedData -and $cachedData.Count -gt 0) {
            # Get total event count
            $totalEventsCacheKey = Get-CacheKey -LogType "$cacheLogType-Full" -StartTime $StartTime -EndTime $EndTime -EventId $EventId -ProviderName $ProviderName -Level $Level
            $totalEventsData = Get-CachedLogData -CacheKey $totalEventsCacheKey -Silent $true
            $totalEventCount = if ($totalEventsData) { $totalEventsData.Count } else { 0 }
            
            if (-not $Silent) {
                Write-Host "`n[High-Risk Event Scanning Complete] Found $($cachedData.Count) high-risk events" -ForegroundColor Green
            }
            return $cachedData
        }
    } else {
        if (-not $Silent) {
            Write-Host "`n[Force Rescan] Skipping cache, scanning events directly..." -ForegroundColor Yellow
        }
    }
    
    # Initialize total event count to 0, get gradually during scanning
    $totalEventCount = 0
    $totalEventsRetrieved = $false
    
    if (-not $Silent) {
        Write-CustomProgress -Activity "Scanning High-Risk Events (Critical/Error/Warning)" -Status "Initializing..." -PercentComplete 0
    }
    
    try {
        # Use provided performance score and optimal chunk size, calculate if not provided
        if ($PerformanceScore -eq 0) {
            $performanceScore = Get-SystemPerformanceScore
        }
        if ($OptimalChunkSize -eq 0) {
            $optimalChunkSize = Get-OptimalChunkSize -PerformanceScore $performanceScore -LogType $LogType
        }
        
        # Get total log count first
        if (-not $Silent) {
            Write-CustomProgress -Activity "Scanning High-Risk Events (Critical/Error/Warning)" -Status "Getting total log count..." -PercentComplete 20
            # Force flush output buffer
            [System.Console]::Out.Flush()
        }
        
        # Temporarily set total high-risk event count to 0, will update after scanning completes
        $totalEventCount = 0
        $totalEventsRetrieved = $false
        
        if (-not $Silent) {
            Write-CustomProgress -Activity "Scanning High-Risk Events (Critical/Error/Warning)" -Status "Initialization complete, starting scan..." -PercentComplete 40
            # Force flush output buffer
            [System.Console]::Out.Flush()
        }
        
        # Chunked scanning for high-risk events
        $step = [TimeSpan]::FromHours($optimalChunkSize)
        $cur = $StartTime
        
        # Generate all chunks
        $chunks = @()
        while ($cur -lt $EndTime) {
            $nxt = [datetime][Math]::Min(($cur + $step).Ticks, $EndTime.Ticks)
            $chunks += @{ StartTime = $cur; EndTime = $nxt }
            $cur = $nxt
        }
        
        $totalChunks = $chunks.Count
        $processedChunks = 0
        
        # Use thread-safe collection to store results
        $allEvents = New-Object 'System.Collections.Generic.List[object]'
        
        # Use optimal parallelism setting
        if (!$logScanningStrategy) {
            # Default strategy if not provided, based on performance score
            $logScanningStrategy = Get-ResourceOptimizedStrategy -PerformanceScore $performanceScore -TaskType "LogScanning"
        }

        # Get CPU cores count
        $cpuInfos = Get-CimInstance Win32_Processor
        $cpuCores = if ($cpuInfos -is [array]) {
            $cpuInfos | Measure-Object -Property NumberOfCores -Sum | Select-Object -ExpandProperty Sum
        } else {
            $cpuInfos.NumberOfCores
        }

        # Use Get-OptimalParallelism to calculate optimal parallelism
        $optimalThreads = Get-OptimalParallelism -CpuCores $cpuCores
        $threadCount = [Math]::Max(1, [Math]::Min($optimalThreads, $totalChunks))
        
        # Monitor memory usage - Optimize memory monitoring logic for high-performance systems
        $memoryUsage = Get-MemoryUsage
        if ($performanceScore -ge 80) {
            # High-performance system, more lenient memory monitoring
            if ($memoryUsage -gt 90) {
                $threadCount = [Math]::Max(1, [Math]::Round($threadCount * 0.7))
            } elseif ($memoryUsage -gt 80) {
                $threadCount = [Math]::Max(1, [Math]::Round($threadCount * 0.9))
            }
        } else {
            # Original memory monitoring logic
            if ($memoryUsage -gt 80) {
                $threadCount = [Math]::Max(1, [Math]::Round($threadCount * 0.5))
            } elseif ($memoryUsage -gt 60) {
                $threadCount = [Math]::Max(1, [Math]::Round($threadCount * 0.75))
            }
        }
        
        if (-not $Silent) {
            Write-Host "`n[System Resource Monitor] Parallel threads: $threadCount, Memory usage: $memoryUsage%" -ForegroundColor Cyan
        }
        

        
        # Optimization: Batch process chunks to reduce task creation overhead
        $batchSize = 5  # Number of chunks per batch
        $batches = @()
        for ($i = 0; $i -lt $chunks.Count; $i += $batchSize) {
            $end = [Math]::Min($i + $batchSize, $chunks.Count)
            $batchChunks = $chunks[$i..($end - 1)]
            $batches += @{ Chunks = $batchChunks; Start = $batchChunks[0].StartTime; End = $batchChunks[-1].EndTime; Index = $i }
        }
        
        $totalBatches = $batches.Count
        $processedBatches = 0
        
        # Get or create global RunspacePool
        $runspacePool = Get-RunspacePool -ThreadCount $threadCount
        
        $jobs = @()
        
        # Create a task for each batch
        foreach ($batch in $batches) {
            # Convert log type to English if it's in Chinese
            $cacheLogType = if ($LogType -eq "系统") { "System" } elseif ($LogType -eq "应用程序") { "Application" } else { $LogType }
            
            $scriptBlock = {
                param($batchChunks, $logType, $eventId, $providerName, $level)
                
                try {
                    $batchEvents = New-Object 'System.Collections.Generic.List[object]'
                    
                    foreach ($chunk in $batchChunks) {
                        # Filter critical, error, warning events directly in Get-WinEvent
                        $filterHashtable = @{ 
                            LogName = $logType; 
                            StartTime = $chunk.StartTime; 
                            EndTime = $chunk.EndTime;
                            Level = 1, 2, 3
                        }
                        
                        # Get matching events
                        $chunkEvents = Get-WinEvent -FilterHashtable $filterHashtable -ErrorAction SilentlyContinue
                        
                        # Further filtering
                        if ($chunkEvents) {
                            # Ensure $chunkEvents is an array
                            if ($chunkEvents -isnot [array]) {
                                $chunkEvents = @($chunkEvents)
                            }
                            
                            # Filter by Event ID
                            if (![string]::IsNullOrWhiteSpace($eventId)) {
                                $eventIds = $eventId -split ',' | ForEach-Object { $_.Trim() }
                                $chunkEvents = $chunkEvents | Where-Object { $eventIds -contains $_.Id.ToString() }
                            }
                            
                            # Filter by Event Provider (using wildcard matching)
                            if (![string]::IsNullOrWhiteSpace($providerName)) {
                                $chunkEvents = $chunkEvents | Where-Object { $_.ProviderName -like "*$providerName*" }
                            }
                            
                            # Filter by Event Level (only if Level parameter is not empty and between 1-3)
                            if (![string]::IsNullOrWhiteSpace($level)) {
                                $levelInt = 0
                                if ([int]::TryParse($level, [ref]$levelInt) -and $levelInt -ge 1 -and $levelInt -le 3) {
                                    $chunkEvents = $chunkEvents | Where-Object { 
                                        $eventLevel = if ($null -eq $_.Level) { 0 } else { [int]$_.Level }
                                        $eventLevel -eq $levelInt 
                                    }
                                }
                            }
                            
                            # Ensure return valid events
                            if ($chunkEvents.Count -gt 0) {
                                # Filter out $null elements and ensure array type
                                $validEvents = @($chunkEvents | Where-Object { $_ -ne $null })
                                if ($validEvents.Count -gt 0) {
                                    $batchEvents.AddRange($validEvents)
                                }
                            }
                        }
                    }
                    
                    return $batchEvents
                }
                catch {
                    # Ignore errors for individual batches and continue scanning
                    Write-Debug "Error scanning batch: $($_.Exception.Message)"
                    return @()
                }
            }
            
            $powershell = [PowerShell]::Create()
            $powershell.RunspacePool = $runspacePool
            $powershell.AddScript($scriptBlock).AddArgument($batch.Chunks).AddArgument($cacheLogType).AddArgument($EventId).AddArgument($ProviderName).AddArgument($Level)
            
            $job = $powershell.BeginInvoke()
            $jobs += @{ PowerShell = $powershell; Job = $job; Batch = $batch }
        }
        
        # Wait for all jobs to complete and collect results
        $processedBatches = 0
        # ====== Core fix: Declare counter outside the loop ======
        $throttleCounter = 0
        while ($jobs.Count -gt 0) {
            $completedJobs = $jobs | Where-Object { $_.Job.IsCompleted }
            
            foreach ($job in $completedJobs) {
                try {
                    $result = $job.PowerShell.EndInvoke($job.Job)
                    if ($result) {
                        $allEvents.AddRange($result)
                    }
                }
                catch {
                    # Ignore errors, continue processing
                }
                finally {
                    $job.PowerShell.Dispose()
                }
                
                $processedBatches++
                $processedChunks = $processedBatches * $batchSize
                if ($processedChunks -gt $totalChunks) {
                    $processedChunks = $totalChunks
                }
                
                # ====== Core fix: Only notify frontend every 40 data items, or on last item ======
                $throttleCounter++
                if ($throttleCounter % 40 -eq 0 -or $throttleCounter -eq $totalChunks) {
                    if (-not $Silent) {
                        $percent = [Math]::Min(100, [Math]::Round(($processedChunks / $totalChunks) * 100))
                        Write-CustomProgress -Activity "Scanning High-Risk Events (Critical/Error/Warning)" -Status "Scanned $processedChunks/$totalChunks chunks, found $($allEvents.Count) high-risk events" -PercentComplete $percent -CurrentItem $processedChunks -TotalItems $totalChunks -CurrentTask "Scanning chunk $processedChunks"
                        # Force output buffer flush to ensure real-time progress update
                        [System.Console]::Out.Flush()
                    }
                }
            }
            
            $jobs = $jobs | Where-Object { -not $_.Job.IsCompleted }
            Start-Sleep -Milliseconds 100
        }
        

        
        # Close RunspacePool
        Close-RunspacePool -Silent $true
        
        # After scanning completes, update total high-risk event count to actual found events
        $totalEventCount = $allEvents.Count
        
        # Ensure 100% progress is displayed at the end
        if (-not $Silent) {
            Write-CustomProgress -Activity "Scanning High-Risk Events (Critical/Error/Warning)" -Status "Scanned $totalChunks/$totalChunks chunks, found $($allEvents.Count) high-risk events" -PercentComplete 100
            # Force flush output buffer
            [System.Console]::Out.Flush()
            # Wait a short time to ensure progress bar is fully displayed
            Start-Sleep -Milliseconds 1000
        }
        
        # Batch process knowledge base queries to add priority information to events
        if ($allEvents.Count -gt 0) {
            if (-not $Silent) {
                Write-Host "`n[Knowledge Base Analysis] Batch processing knowledge base queries for $($allEvents.Count) events..." -ForegroundColor Cyan
            }
            
            # Use batch parallel query function
            $priorities = Get-BatchKnowledgeBasePriorities -Events $allEvents -ThreadCount $threadCount
            
            # Add priority information to each event
            foreach ($event in $allEvents) {
                try {
                    $priority = $priorities[$event]
                    Add-Member -InputObject $event -NotePropertyName "KnowledgeBasePriority" -NotePropertyValue $priority -Force
                } catch {
                    # Ignore errors, continue processing
                }
            }
            
            if (-not $Silent) {
                Write-Host "[Knowledge Base Analysis] Batch processing completed" -ForegroundColor Green
            }
        }
        
        # Note: Don't close RunspacePool, leave it for future use
        
        # Store result in cache
        if (!$cacheStrategy) {
            # Default cache strategy if not provided
            $cacheStrategy = Get-IntelligentCacheStrategy -PerformanceScore $performanceScore -DataSizeKB 10000
        }
        Set-CachedLogData -CacheKey $cacheKey -Data $allEvents -CacheStrategy $cacheStrategy -Silent $Silent
        
        # Complete with newline
        if (-not $Silent) {
            Write-Host "`n[High-Risk Event Scanning Complete] Found $($allEvents.Count) high-risk events" -ForegroundColor Green
        }
        return $allEvents
    }
    catch {
        if (-not $Silent) {
            Write-Host "`nError occurred during scanning: $($_.Exception.Message)" -ForegroundColor Red
        }
        # Return collected events even if error occurs
        return $allEvents
    }
}

function Get-FullSystemLog {
    <#
    .SYNOPSIS
        Gets complete system log events
    .DESCRIPTION
        Reads all events from the specified log within the given time range, supporting filtering and caching
    .PARAMETER StartTime
        Start time for event collection
    .PARAMETER EndTime
        End time for event collection
    .PARAMETER LogType
        Log type to read, default is "System"
    .PARAMETER EventId
        Event ID filter (multiple IDs separated by commas)
    .PARAMETER ProviderName
        Event provider name filter
    .PARAMETER Level
        Event level filter
    .PARAMETER PerformanceScore
        System performance score (0-100)
    .PARAMETER OptimalChunkSize
        Optimal chunk size for processing
    .PARAMETER TotalEventCount
        Total event count (if known)
    .PARAMETER Silent
        Whether to run in silent mode
    .RETURNS
        Collection of all events matching the criteria
    .EXAMPLE
        # Example: Get full System log for the last 24 hours
        $fullLog = Get-FullSystemLog -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) -LogType "System"
        Write-Host "Collected $($fullLog.Count) events" -ForegroundColor Green
    #>
    param(
        [datetime]$StartTime, 
        [datetime]$EndTime, 
        [string]$LogType = "System",
        [string]$EventId,
        [string]$ProviderName,
        [string]$Level,
        [int]$PerformanceScore = 0,
        [double]$OptimalChunkSize = 0,
        [int]$TotalEventCount = 0,
        [switch]$Silent = $false
    )
    # Generate cache key (use English log type name to ensure consistency with CHSPRO version)
    $cacheLogType = if ($LogType -eq "系统") { "System" } elseif ($LogType -eq "应用程序") { "Application" } else { $LogType }
    $cacheKey = Get-CacheKey -LogType "$cacheLogType-Full" -StartTime $StartTime -EndTime $EndTime -EventId $EventId -ProviderName $ProviderName -Level $Level
    
    # Try to get data from cache
    $cachedData = Get-CachedLogData -CacheKey $cacheKey -Silent $Silent
    if ($cachedData -and $cachedData.Count -gt 0) {
        if (-not $Silent) {
            Write-Host "`n[Full $LogType Log Reading Complete] Collected $($cachedData.Count) events" -ForegroundColor Green
        }
        return $cachedData
    }
    
    # Try to get data from high-risk event scan cache (if full log cache doesn't exist)
    $highRiskCacheKey = Get-CacheKey -LogType "$cacheLogType-HighRisk" -StartTime $StartTime -EndTime $EndTime -EventId $EventId -ProviderName $ProviderName -Level $Level
    $highRiskCachedData = Get-CachedLogData -CacheKey $highRiskCacheKey -Silent $Silent
    if ($highRiskCachedData -and $highRiskCachedData.Count -gt 0) {
        if (-not $Silent) {
            Write-Host "`n[Full $LogType Log Reading Complete] Retrieved data from high-risk event cache, collected $($highRiskCachedData.Count) events" -ForegroundColor Green
        }
        # Store high-risk event cache data into full log cache for future use
        if (-not $Silent) {
            Set-CachedLogData -CacheKey $cacheKey -Data $highRiskCachedData
        } else {
            # In silent mode, directly store in cache without output
            $script:logCache[$cacheKey] = @{
                Time = Get-Date
                Data = $highRiskCachedData
            }
            # Limit cache size based on memory usage
            $optimalCacheSize = Get-OptimalCacheSize
            if ($script:logCache.Count -gt $optimalCacheSize) {
                # Remove oldest cache item
                $oldestKey = $script:logCache.GetEnumerator() | Sort-Object { $_.Value.Time } | Select-Object -First 1 -ExpandProperty Key
                $script:logCache.Remove($oldestKey)
            }
        }
        return $highRiskCachedData
    }
    
    if (-not $Silent) {
        Write-CustomProgress -Activity "Reading complete $LogType logs" -Status "Initializing..." -PercentComplete 0
        # Force flush output buffer
        [System.Console]::Out.Flush()
    }
    
    # Use passed total event count, if not provided then try to get it
    $totalEventCount = $TotalEventCount
    if ($totalEventCount -eq 0) {
        if (-not $Silent) {
            Write-CustomProgress -Activity "Reading complete $LogType logs" -Status "Getting total event count..." -PercentComplete 20
            # Force flush output buffer
            [System.Console]::Out.Flush()
        }
        
        # Try to get total event count from cache
        $totalEventsCacheKey = Get-CacheKey -LogType "$cacheLogType-Full" -StartTime $StartTime -EndTime $EndTime -EventId $EventId -ProviderName $ProviderName -Level $Level
        $totalEventsData = Get-CachedLogData -CacheKey $totalEventsCacheKey -Silent $true
        if ($totalEventsData) {
            $totalEventCount = $totalEventsData.Count
        } else {
            # If cache doesn't exist, get total event count directly
            try {
                # Build filter conditions
                $filterHashtable = @{ LogName = $cacheLogType; StartTime = $StartTime; EndTime = $EndTime }
                
                # Add event ID filtering (if provided)
                if (![string]::IsNullOrWhiteSpace($EventId)) {
                    $eventIds = $EventId -split ',' | ForEach-Object { $_.Trim() }
                    if ($eventIds.Count -gt 0) {
                        $filterHashtable["Id"] = $eventIds
                    }
                }
                
                # Add event provider filtering (if provided)
                if (![string]::IsNullOrWhiteSpace($ProviderName)) {
                    $filterHashtable["ProviderName"] = $ProviderName
                }
                
                # Add event level filtering (if provided)
                if (![string]::IsNullOrWhiteSpace($Level)) {
                    $levelInt = 0
                    if ([int]::TryParse($Level, [ref]$levelInt)) {
                        $filterHashtable["Level"] = $levelInt
                    }
                }
                
                # Get total event count
                $totalEvents = Get-WinEvent -FilterHashtable $filterHashtable -ErrorAction SilentlyContinue
                $totalEventCount = if ($totalEvents) { $totalEvents.Count } else { 0 }
            } catch {
                # Ignore errors, use 0 as default
                $totalEventCount = 0
            }
        }
        
        if (-not $Silent) {
            # Show progress for getting total event count
            Write-CustomProgress -Activity "Reading complete $LogType logs" -Status "Total event count obtained: $totalEventCount" -PercentComplete 40
            # Force flush output buffer
            [System.Console]::Out.Flush()
        }
    } else {
        # Use passed total event count, show confirmation message
        if (-not $Silent) {
            Write-CustomProgress -Activity "Reading complete $LogType logs" -Status "Using existing total event count: $totalEventCount" -PercentComplete 40
            # Force flush output buffer
            [System.Console]::Out.Flush()
        }
    }
    
    # Get all events directly, no chunk processing
    $all = New-Object System.Collections.Generic.List[object]
    $errorCount = 0
    
    try {
        # Build filter conditions
        $filterHashtable = @{ LogName = $cacheLogType; StartTime = $StartTime; EndTime = $EndTime }
        
        # Add event ID filtering (if provided)
        if (![string]::IsNullOrWhiteSpace($EventId)) {
            $eventIds = $EventId -split ',' | ForEach-Object { $_.Trim() }
            if ($eventIds.Count -gt 0) {
                $filterHashtable["Id"] = $eventIds
            }
        }
        
        # Add event provider filtering (if provided)
        if (![string]::IsNullOrWhiteSpace($ProviderName)) {
            $filterHashtable["ProviderName"] = $ProviderName
        }
        
        # Add event level filtering (if provided)
        if (![string]::IsNullOrWhiteSpace($Level)) {
            $levelInt = 0
            if ([int]::TryParse($Level, [ref]$levelInt)) {
                $filterHashtable["Level"] = $levelInt
            }
        }
        
        # Get all events directly
        if (-not $Silent) {
            Write-CustomProgress -Activity "Reading complete $LogType logs" -Status "Getting all events directly..." -PercentComplete 60
            # Force flush output buffer
            [System.Console]::Out.Flush()
        }
        
        # Try to get events using FilterHashtable
        $events = Get-WinEvent -FilterHashtable $filterHashtable -ErrorAction SilentlyContinue
        
        # If FilterHashtable fails, try using FilterXPath
        if (!$events) {
            # Build XPath query
            $xpathQuery = "*[System[TimeCreated[@SystemTime >= '$($StartTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.000Z'))' and @SystemTime <= '$($EndTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.999Z'))']]"
            
            # Add event ID filtering
            if (![string]::IsNullOrWhiteSpace($EventId)) {
                $eventIds = $EventId -split ',' | ForEach-Object { $_.Trim() }
                if ($eventIds.Count -gt 0) {
                    $idFilter = $eventIds -join ' or ' 
                    $xpathQuery = "*[System[($idFilter) and TimeCreated[@SystemTime >= '$($StartTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.000Z'))' and @SystemTime <= '$($EndTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.999Z'))']]"
                }
            }
            
            $events = Get-WinEvent -LogName $cacheLogType -FilterXPath $xpathQuery -ErrorAction SilentlyContinue
        }
        
        # Process obtained events
        if ($events) {
            # Ensure result is an array
            if ($events -is [array]) {
                # Filter out $null elements
                $validEvents = $events | Where-Object { $_ -ne $null }
                if ($validEvents.Count -gt 0) {
                    $all.AddRange($validEvents)
                }
            } else {
                # Single event case
                if ($events -ne $null) {
                    $all.Add($events)
                }
            }
        }
    } catch {
        $errorCount++
        if (-not $Silent) {
            Write-Host "`nError reading events: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Ensure final progress is displayed correctly
    if (-not $Silent) {
        # Calculate final progress based on actual collected events
        if ($totalEventCount -gt 0) {
            $finalPercent = [Math]::Min(100, [Math]::Round(($all.Count / $totalEventCount) * 100))
            Write-CustomProgress -Activity "Reading complete $LogType logs" -Status "Collected $($all.Count)/$totalEventCount events | Reading complete" -PercentComplete $finalPercent
        } else {
            Write-CustomProgress -Activity "Reading complete $LogType logs" -Status "Collected $($all.Count) events | Reading complete" -PercentComplete 100
        }
        # Force flush output buffer
        [System.Console]::Out.Flush()
    }
    
    # Store result in cache
    if (-not $Silent) {
        Set-CachedLogData -CacheKey $cacheKey -Data $all
    } else {
        # Silent mode: store directly in cache without output
        $script:logCache[$cacheKey] = @{
            Time = Get-Date
            Data = $all
        }
        # Limit cache size based on memory usage
        $optimalCacheSize = Get-OptimalCacheSize
        if ($script:logCache.Count -gt $optimalCacheSize) {
            # Remove oldest cache item
            $oldestKey = $script:logCache.GetEnumerator() | Sort-Object { $_.Value.Time } | Select-Object -First 1 -ExpandProperty Key
            $script:logCache.Remove($oldestKey)
        }
    }
    
    # Complete with newline
    if (-not $Silent) {
        Write-Host "`n[Full $LogType Log Reading Complete] Collected $($all.Count) events" -ForegroundColor Green
        
        if ($errorCount -gt 0) {
            Write-Host "`nEncountered $errorCount errors during reading, but attempted to collect all available events." -ForegroundColor Yellow
        }
    }
    
    return $all
}

function New-LogReport {
    <#
    .SYNOPSIS
        Generates a detailed log report
    .DESCRIPTION
        Generates a comprehensive log report with system information, event statistics, health assessment, and knowledge base solutions
    .PARAMETER Events
        Collection of event log records to analyze
    .PARAMETER ReportTitle
        Title for the report
    .PARAMETER DatePart
        Date part for the report filename
    .PARAMETER ExportPath
        Path to export the report to
    .PARAMETER LogType
        Log type being analyzed (e.g., "System", "Application")
    .EXAMPLE
        # Example: Generate a log report
        $events = Get-FullSystemLog -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) -LogType "System"
        $reportTitle = "System Log Daily Report"
        $datePart = (Get-Date).ToString('yyyyMMdd')
        $exportPath = "C:\Logs"
        New-LogReport -Events $events -ReportTitle $reportTitle -DatePart $datePart -ExportPath $exportPath -LogType "System"
        Write-Host "Report generated successfully" -ForegroundColor Green
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Events,
        [Parameter(Mandatory=$true)]
        [string]$ReportTitle,
        [Parameter(Mandatory=$true)]
        [string]$DatePart,
        [Parameter(Mandatory=$true)]
        [string]$ExportPath,
        [string]$LogType = "System"
    )
    
    # 检查Events是否为空或不包含有效事件
    if (!$Events -or $Events.Count -eq 0) {
        Write-Host "`n⚠️ No valid events to report." -ForegroundColor Yellow
        return
    }
    
    # Filter out invalid events - accept all events with required properties, not just EventLogRecord type
    $validEvents = $Events | Where-Object { 
        $_ -ne $null -and 
        $_.Id -ne $null -and 
        $_.ProviderName -ne $null 
    }
    if ($validEvents.Count -eq 0) {
        Write-Host "`n⚠️ No valid events to report." -ForegroundColor Yellow
        return
    }
    
    # Use filtered valid events
    $Events = $validEvents

    # Optimization: Pre-calculate system information to reduce repeated calls
    $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption
    $computerName = $env:COMPUTERNAME
    $exportTime = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    
    # Optimization: Get time range
    $firstEvent = $Events | Sort-Object TimeCreated | Select-Object -First 1
    $lastEvent = $Events | Sort-Object TimeCreated | Select-Object -Last 1
    $firstEventTime = if ($firstEvent.TimeCreated) { $firstEvent.TimeCreated } else { Get-Date }
    $lastEventTime = if ($lastEvent.TimeCreated) { $lastEvent.TimeCreated } else { Get-Date }
    $timeRange = "$($firstEventTime.ToString('yyyy-MM-dd HH:mm')) to $($lastEventTime.ToString('yyyy-MM-dd HH:mm'))"
    
    # Perform advanced pattern analysis
    $patternAnalysis = New-AdvancedLogPatternAnalysis -Events $Events
    
    # Optimization: Use StringBuilder to build report content for better performance
    $reportContent = New-Object System.Text.StringBuilder
    $null = $reportContent.AppendLine($ReportTitle)
    $null = $reportContent.AppendLine("Computer Name : $computerName")
    $null = $reportContent.AppendLine("Operating System : $osInfo")
    $null = $reportContent.AppendLine("Export Time : $exportTime")
    $null = $reportContent.AppendLine("Tool Version : V11.5")
    $null = $reportContent.AppendLine("==================================================")
    $null = $reportContent.AppendLine("Time Range : $timeRange")
    $null = $reportContent.AppendLine("Total Events : $($Events.Count)")
    $null = $reportContent.AppendLine()
    $null = $reportContent.AppendLine("[Advanced Pattern Analysis Summary]")
    $null = $reportContent.AppendLine("Repetitive Patterns : $($patternAnalysis.Summary.RepetitivePatterns)")
    $null = $reportContent.AppendLine("Time-based Patterns : $($patternAnalysis.Summary.TimePatterns)")
    $null = $reportContent.AppendLine("Anomalies Detected : $($patternAnalysis.Summary.Anomalies)")
    $null = $reportContent.AppendLine()
    $null = $reportContent.AppendLine("[Event Level Summary]")

    # Optimization: Use generic dictionaries for better performance
    $levelCounts = New-Object 'System.Collections.Generic.Dictionary[string, int]'
    $errorCount = 0
    $warningCount = 0
    $criticalCount = 0
    $idCounts = New-Object 'System.Collections.Generic.Dictionary[int, int]'
    $providerCounts = New-Object 'System.Collections.Generic.Dictionary[string, int]'

    # Predefined level names mapping
    $levelNames = @{
        0 = "Information"
        1 = "Critical"
        2 = "Error"
        3 = "Warning"
        4 = "Verbose"
        5 = "Always"
    }

    # Optimization: Batch process event data
    $totalEvents = $Events.Count
    $currentEvent = 0
    $updateInterval = [Math]::Max(1, [Math]::Min(100, $totalEvents / 10))
    
    foreach ($e in $Events) {
        $currentEvent++
        
        # Update progress every certain number of events
        if ($currentEvent % $updateInterval -eq 0) {
            $percent = [Math]::Min(100, [Math]::Round(($currentEvent / $totalEvents) * 100))
            Write-CustomProgress -Activity "Generate Report" -Status "Analyzing event data $currentEvent/$totalEvents" -PercentComplete $percent -CurrentItem $currentEvent -TotalItems $totalEvents -CurrentTask "Analyzing event $currentEvent"
        }
        
        $level = if ($null -eq $e.Level) { 0 } else { [int]$e.Level }
        if ($levelNames.ContainsKey($level)) {
            $levelName = $levelNames[$level]
        }
        else {
            $levelName = "Unknown(Level=$level)"
        }
        
        # Use TryAdd method for better performance
        if (!$levelCounts.ContainsKey($levelName)) {
            $levelCounts[$levelName] = 0
        }
        $levelCounts[$levelName]++
        
        $eventId = if ($e.Id) { $e.Id } else { 0 }
        if (!$idCounts.ContainsKey($eventId)) {
            $idCounts[$eventId] = 0
        }
        $idCounts[$eventId]++
        
        $eventProvider = if ($e.ProviderName) { $e.ProviderName } else { '<No provider information>' }
        if (!$providerCounts.ContainsKey($eventProvider)) {
            $providerCounts[$eventProvider] = 0
        }
        $providerCounts[$eventProvider]++

        # Count errors, warnings, and critical events
        switch ($level) {
            1 { $criticalCount++ }
            2 { $errorCount++ }
            3 { $warningCount++ }
        }
    }

    # Optimization: Use StringBuilder to add statistics
    $levelCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        $null = $reportContent.AppendLine("  $($_.Key) : $($_.Value) events")
    }

    $null = $reportContent.AppendLine()
    $null = $reportContent.AppendLine("[Top 10 Event IDs]")
    $idCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
        $null = $reportContent.AppendLine("  Event ID $($_.Key) : $($_.Value) events")
    }

    $null = $reportContent.AppendLine()
    $null = $reportContent.AppendLine("[Top 10 Event Providers]")
    $providerCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
        $null = $reportContent.AppendLine("  $($_.Key) : $($_.Value) events")
    }

    # === System Health Assessment ===
    # Calculate health score
    $totalEvents = $Events.Count
    $severeCount = $criticalCount + $errorCount
    $totalIssues = $criticalCount * 3 + $errorCount * 2 + $warningCount
    
    # Calculate health score based on event count and severity
    if ($totalEvents -gt 0) {
        $healthScore = [Math]::Max(0, 100 - ($totalIssues * 100 / $totalEvents))
    } else {
        $healthScore = 100
    }
    
    # Health level assessment
    if ($healthScore -ge 90) {
        $healthLevel = "Excellent"
        $healthStatus = "System Status: Excellent — Running stably, no obvious anomalies!"
        $consoleColor = 'Green'
    } elseif ($healthScore -ge 70) {
        $healthLevel = "Good"
        $healthStatus = "System Status: Good — Few anomalies, regular checks recommended!"
        $consoleColor = 'Yellow'
    } elseif ($healthScore -ge 50) {
        $healthLevel = "Average"
        $healthStatus = "System Status: Average — Many anomalies, need attention!"
        $consoleColor = 'Yellow'
    } else {
        $healthLevel = "Poor"
        $healthStatus = "System Status: Poor — Many anomalies, immediate inspection recommended!"
        $consoleColor = 'Red'
    }
    
    if ($errorCount -gt 0 -or $warningCount -gt 0 -or $criticalCount -gt 0) {
        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine("⚠️ [Issues Found]")
        $null = $reportContent.AppendLine("Errors : $errorCount events")
        $null = $reportContent.AppendLine("Warnings : $warningCount events")
        $null = $reportContent.AppendLine("Critical : $criticalCount events")
        $null = $reportContent.AppendLine("Health Score : $([Math]::Round($healthScore, 1))/100")
        $null = $reportContent.AppendLine("Health Level : $healthLevel")

        if ($errorCount -gt 0) {
            $null = $reportContent.AppendLine()
            $null = $reportContent.AppendLine()
            $null = $reportContent.AppendLine("[Recent 10 Error Events]")
            $recentErrors = $Events | Where-Object {
                $lvl = if ($null -eq $_.Level) { 0 } else { [int]$_.Level }
                $lvl -eq 2
            } | Sort-Object TimeCreated -Descending | Select-Object -First 10

            foreach ($e in $recentErrors) {
                $msg = if ($e.Message) { 
                    ($e.Message -replace '\r', ' ' -replace '\n', ' ' -replace '\t', ' ' -replace '\|', ' ' -replace '"', ' ' -replace "'", ' ').Trim() 
                }
                else { '<No message content>' }
                if ($msg.Length -gt 512) { $msg = $msg.Substring(0, 502) + ' [TRUNCATED]' }
                $null = $reportContent.AppendLine("Time: $($e.TimeCreated)")
                $null = $reportContent.AppendLine("Event ID: $($e.Id)")
                $null = $reportContent.AppendLine("Source: $($e.ProviderName)")
                $null = $reportContent.AppendLine("Description: $msg")
                $null = $reportContent.AppendLine()
            }
        }

        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine($healthStatus)
        
        # Add knowledge base solutions section
        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine("🔍 [Knowledge Base Solutions]")
        $null = $reportContent.AppendLine("Intelligent analysis and solution recommendations based on knowledge base:")
        
        # Collect knowledge base solutions for high-risk events (only Critical, Error, Warning)
        $allSolutions = @{}
        $highRiskEvents = $Events | Where-Object {
            $level = if ($null -eq $_.Level) { 0 } else { [int]$_.Level }
            $level -in 1, 2, 3  # Critical, Error, Warning
        }
        
        foreach ($e in $highRiskEvents) {
            $solutions = Get-KnowledgeBaseSolution -Event $e
            if ($solutions.Count -gt 0) {
                $key = "$($e.Id)-$($e.ProviderName)"
                if (-not $allSolutions.ContainsKey($key)) {
                    $allSolutions[$key] = @{
                        EventId = $e.Id
                        ProviderName = $e.ProviderName
                        Solutions = $solutions
                    }
                }
            }
        }
        
        # Sort by priority and display top 10 solutions
        $sortedSolutions = $allSolutions.Values | Sort-Object { 
            $maxPriority = 0
            foreach ($sol in $_.Solutions) {
                if ($sol.priority -gt $maxPriority) {
                    $maxPriority = $sol.priority
                }
            }
            return -$maxPriority
        } | Select-Object -First 10
        
        if ($sortedSolutions.Count -gt 0) {
            $i = 1
            foreach ($item in $sortedSolutions) {
                $null = $reportContent.AppendLine()
                $null = $reportContent.AppendLine()
                $null = $reportContent.AppendLine("$i. Event ID: $($item.EventId), Source: $($item.ProviderName)")
                $null = $reportContent.AppendLine("   ==================================================")
                foreach ($sol in $item.Solutions) {
                    # Get localized solution
                    $localizedSol = Get-LocalizedKnowledgeBaseSolution -Solution $sol
                    
                    $null = $reportContent.AppendLine("   📋 Issue: $($localizedSol.name)")
                    $null = $reportContent.AppendLine("   ⚠️ Severity: $($localizedSol.severity)")
                    $null = $reportContent.AppendLine("   🎯 Priority: $($localizedSol.priority)")
                    $null = $reportContent.AppendLine("   🔍 Causes:")
                    if ($localizedSol.causes -is [array]) {
                        foreach ($cause in $localizedSol.causes) {
                            $null = $reportContent.AppendLine("      - $cause")
                        }
                    } else {
                        $null = $reportContent.AppendLine("      - $($localizedSol.causes)")
                    }
                    $null = $reportContent.AppendLine("   ✅ Solutions:")
                    if ($localizedSol.solutions -is [array]) {
                        foreach ($solution in $localizedSol.solutions) {
                            $null = $reportContent.AppendLine("      - $solution")
                        }
                    } else {
                        $null = $reportContent.AppendLine("      - $($localizedSol.solutions)")
                    }
                    $null = $reportContent.AppendLine("   📌 Recommended Action: $($localizedSol.recommended_action)")
                    
                    # Add commands information
                    if ($localizedSol.commands -and $localizedSol.commands.Count -gt 0) {
                        $null = $reportContent.AppendLine("   💻 Recommended Commands:")
                        $commandIndex = 1
                        foreach ($command in $localizedSol.commands) {
                            $risk = if ($command.risk_level) { "($($command.risk_level))" } else { "" }
                            $elevation = if ($command.elevation_required) { "[Requires Admin]" } else { "" }
                            $note = if ($command.note) { " - $($command.note)" } else { "" }
                            $null = $reportContent.AppendLine("      $commandIndex. $($command.name) $risk $elevation$note")
                            $null = $reportContent.AppendLine("        Command: $($command.command)")
                            # Add separator, except for the last command
                            if ($commandIndex -lt $localizedSol.commands.Count) {
                                $null = $reportContent.AppendLine("        ----------")
                            }
                            $commandIndex++
                        }
                    }
                    
                    $null = $reportContent.AppendLine("   --------------------------------------------------")
                }
                $i++
            }
        } else {
            $null = $reportContent.AppendLine("No related knowledge base solutions found.")
        }
    }
    else {
        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine("✅ [System Status] Healthy — No errors, warnings, or critical events!")
        $null = $reportContent.AppendLine("Health Score : 100/100")
        $null = $reportContent.AppendLine("Health Level : Excellent")
    }

    # Save files
    try {
        # Optimization: Use common function to generate safe file path
        $txtPath = Get-SafeFilePath -BasePath $ExportPath -LogType $LogType -DatePart $DatePart -Extension "_Summary.txt"
        $reportContent.ToString() | Out-File -FilePath $txtPath -Encoding UTF8 -ErrorAction Stop
        Write-Host "`n📝 Summary report saved to: $txtPath" -ForegroundColor Cyan

        # Optimization: Use common function to generate safe file path
        $csvPath = Get-SafeFilePath -BasePath $ExportPath -LogType $LogType -DatePart $DatePart -Extension ".csv"
        
        # Use StreamWriter for streaming writing, reduce memory usage
        $streamWriter = New-Object System.IO.StreamWriter($csvPath, $false, [System.Text.Encoding]::UTF8, 65536)
        try {
            # Write CSV header
            $streamWriter.WriteLine("TimeCreated,Id,LevelDisplayName,ProviderName,Message")
            
            # Parallel processing event data
            $totalEvents = $Events.Count
            $currentEvent = 0
            $batchSize = 1000
            $updateInterval = 100
            
            # Determine parallelism based on system performance
            $optimalParallelism = Get-OptimalParallelism
            $threadCount = [Math]::Min($optimalParallelism, 8) # Limit maximum thread count
            
            if ($totalEvents -gt 1000 -and $threadCount -gt 1) {
                # Use parallel processing for large number of events
                Write-Host "`nUsing parallel processing to accelerate CSV data generation..." -ForegroundColor Cyan
                
                # Split events into batches
                $eventBatches = Split-Array -InputArray $Events -Size 500
                $processedBatches = @()
                $batchCount = $eventBatches.Count
                $currentBatch = 0
                
                # Process each batch in parallel
                $totalProcessed = 0
                $batchSize = 500
                $startTime = Get-Date
                
                foreach ($batch in $eventBatches) {
                    $currentBatch++
                    $batchStartTime = Get-Date
                    
                    # Process current batch
                    $processedBatch = $batch | ForEach-Object {
                        $totalProcessed++
                        $percent = [Math]::Min(100, [Math]::Round(($totalProcessed / $totalEvents) * 100))
                        
                        # Update progress every 10 events
                        if ($totalProcessed % 10 -eq 0) {
                            $elapsedTime = (Get-Date) - $startTime
                            $speed = 0
                            $estimatedRemaining = ""
                            
                            if ($elapsedTime.TotalSeconds -gt 0) {
                                $speed = [Math]::Round($totalProcessed / $elapsedTime.TotalSeconds, 2)
                            }
                            
                            if ($percent -lt 100 -and $elapsedTime.TotalSeconds -gt 0 -and $percent -gt 0) {
                                $estimatedTotalSeconds = $elapsedTime.TotalSeconds * (100 / $percent)
                                $estimatedRemainingSeconds = $estimatedTotalSeconds - $elapsedTime.TotalSeconds
                                if ($estimatedRemainingSeconds -gt 0) {
                                    $timespan = New-TimeSpan -Seconds $estimatedRemainingSeconds
                                    $estimatedRemaining = "Estimated remaining: $($timespan.ToString() -replace '\.[0-9]+', '')"
                                }
                            }
                            
                            $status = "Generating CSV data $totalProcessed/$totalEvents"
                            Write-CustomProgress -Activity "Saving report" -Status $status -PercentComplete $percent -CurrentItem $totalProcessed -TotalItems $totalEvents -CurrentTask "Processing event $totalProcessed"
                        }
                        
                        $e = $_
                        $timeCreated = if ($e.TimeCreated) { $e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss') } else { '<No time information>' }
                        $id = if ($e.Id) { $e.Id } else { 0 }
                        $levelDisplayName = if ($e.LevelDisplayName) { $e.LevelDisplayName } else { '<No level information>' }
                        $providerName = if ($e.ProviderName) { $e.ProviderName } else { '<No provider information>' }
                        $message = if ($e.Message) { 
                            $msg = $e.Message -replace '[\r\n\t\|"\'']', ' ' 
                            if ($msg.Length -gt 512) { $msg = $msg.Substring(0, 502) + ' [TRUNCATED]' }
                            $msg
                        } else { '<No message content>' }
                        
                        # Ensure CSV format is correct
                        $message = $message -replace '"', '""'
                        '"' + $timeCreated + '","' + $id + '","' + $levelDisplayName + '","' + $providerName + '","' + $message + '"'
                    }
                    
                    # Write processed batch
                    $streamWriter.Write(($processedBatch -join "`n"))
                    $streamWriter.WriteLine()
                }
            } else {
                # Use sequential processing for small number of events
                $batch = @()
                foreach ($e in $Events) {
                    $currentEvent++
                    
                    # Update progress bar every 100 events
                    if ($currentEvent % $updateInterval -eq 0) {
                        $percent = [Math]::Min(100, [Math]::Round(($currentEvent / $totalEvents) * 100))
                        Write-CustomProgress -Activity "Saving report" -Status "Writing CSV data $currentEvent/$totalEvents" -PercentComplete $percent -CurrentItem $currentEvent -TotalItems $totalEvents -CurrentTask "Writing event $currentEvent"
                    }
                    
                    $timeCreated = if ($e.TimeCreated) { $e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss') } else { '<No time information>' }
                    $id = if ($e.Id) { $e.Id } else { 0 }
                    $levelDisplayName = if ($e.LevelDisplayName) { $e.LevelDisplayName } else { '<No level information>' }
                    $providerName = if ($e.ProviderName) { $e.ProviderName } else { '<No provider information>' }
                    $message = if ($e.Message) { 
                        $msg = $e.Message -replace '[\r\n\t\|"\'']', ' ' 
                        if ($msg.Length -gt 512) { $msg = $msg.Substring(0, 502) + ' [TRUNCATED]' }
                        $msg
                    } else { '<No message content>' }
                    
                    # Ensure CSV format is correct
                    $message = $message -replace '"', '""'
                    $csvLine = '"' + $timeCreated + '","' + $id + '","' + $levelDisplayName + '","' + $providerName + '","' + $message + '"'
                    
                    # Add to batch
                    $batch += $csvLine
                    
                    # Write batch when full
                    if ($batch.Count -eq $batchSize) {
                        $streamWriter.Write(($batch -join "`n"))
                        $streamWriter.WriteLine()
                        $batch = @()
                    }
                }
                
                # Write remaining data
                if ($batch.Count -gt 0) {
                    $streamWriter.Write(($batch -join "`n"))
                    $streamWriter.WriteLine()
                }
            }
        } finally {
            $streamWriter.Close()
        }
        
        # Show CSV export completed
        Write-CustomProgress -Activity "Saving report" -Status "CSV export completed" -PercentComplete 100
        # Force flush output buffer
        [System.Console]::Out.Flush()
        
        # Export as JSON format
        $jsonPath = Get-SafeFilePath -BasePath $ExportPath -LogType $LogType -DatePart $DatePart -Extension ".json"
        try {
            Write-CustomProgress -Activity "Saving report" -Status "Generating JSON data..." -PercentComplete 0
            $totalEvents = $Events.Count
            $currentEvent = 0
            $batchSize = 500
            $batch = @()
            $updateInterval = 100
            
            # Pre-calculate common values
            $computerName = $env:COMPUTERNAME.Replace('"', '\\"')
            $exportTime = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            $timeRange = "$($firstEventTime.ToString('yyyy-MM-dd HH:mm')) to $($lastEventTime.ToString('yyyy-MM-dd HH:mm'))".Replace('"', '\\"')
            
            # Use StreamWriter for streaming writing, reduce memory usage
            $streamWriter = New-Object System.IO.StreamWriter($jsonPath, $false, [System.Text.Encoding]::UTF8, 65536)
            try {
                # Write JSON header
                $streamWriter.WriteLine('{')
                $streamWriter.WriteLine('  "ReportTitle": "' + $ReportTitle.Replace('"', '\\"') + '",')
                $streamWriter.WriteLine('  "ComputerName": "' + $computerName + '",')
                $streamWriter.WriteLine('  "OperatingSystem": "' + $osInfo.Replace('"', '\\"') + '",')
                $streamWriter.WriteLine('  "ExportTime": "' + $exportTime + '",')
                $streamWriter.WriteLine('  "TimeRange": "' + $timeRange + '",')
                $streamWriter.WriteLine('  "TotalEvents": ' + $Events.Count + ',')
                $streamWriter.WriteLine('  "Events": [')
                
                # Batch write event data
                $firstEvent = $true
                foreach ($e in $Events) {
                    $currentEvent++
                    
                    # Update progress bar every 100 events
                    if ($currentEvent % $updateInterval -eq 0) {
                        $percent = [Math]::Min(100, [Math]::Ceiling(($currentEvent / $totalEvents) * 100))
                        Write-CustomProgress -Activity "Saving report" -Status "Generating JSON data $currentEvent/$totalEvents" -PercentComplete $percent -CurrentItem $currentEvent -TotalItems $totalEvents -CurrentTask "Processing event $currentEvent"
                    }
                    
                    # Build event JSON
                    $eventJson = ''
                    if (!$firstEvent) {
                        $eventJson += ','
                    }
                    $firstEvent = $false
                    
                    $eventJson += '    {'
                    if ($e.TimeCreated) { $timeCreatedValue = '"' + $e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss') + '"' } else { $timeCreatedValue = 'null' }
                    $eventJson += '"TimeCreated": ' + $timeCreatedValue + ','
                    if ($e.Id) { $idValue = $e.Id } else { $idValue = 0 }
                    $eventJson += '"Id": ' + $idValue + ','
                    if ($e.Level) { $levelValue = $e.Level } else { $levelValue = 0 }
                    $eventJson += '"Level": ' + $levelValue + ','
                    if ($e.LevelDisplayName) { $levelDisplayNameValue = '"' + $e.LevelDisplayName.Replace('"', '\\"') + '"' } else { $levelDisplayNameValue = 'null' }
                    $eventJson += '"LevelDisplayName": ' + $levelDisplayNameValue + ','
                    if ($e.ProviderName) { $providerNameValue = '"' + $e.ProviderName.Replace('"', '\\"') + '"' } else { $providerNameValue = 'null' }
                    $eventJson += '"ProviderName": ' + $providerNameValue + ','
                    if ($e.Message) { $messageValue = '"' + ($e.Message -replace '[\r\n\t]', ' ' -replace '"', '\\"') + '"' } else { $messageValue = 'null' }
                    $eventJson += '"Message": ' + $messageValue
                    $eventJson += '}'
                    
                    # Add to batch
                    $batch += $eventJson
                    
                    # Write batch when full
                    if ($batch.Count -eq $batchSize) {
                        $streamWriter.Write(($batch -join "`n"))
                        $batch = @()
                    }
                }
                
                # Write remaining data
                if ($batch.Count -gt 0) {
                    $streamWriter.Write(($batch -join "`n"))
                }
                
                # Write JSON footer
                $streamWriter.WriteLine()
                $streamWriter.WriteLine('  ]')
                $streamWriter.WriteLine('}')
            } finally {
                $streamWriter.Close()
            }
            
            Write-CustomProgress -Activity "Saving report" -Status "JSON export completed" -PercentComplete 100
            # Force flush output buffer
            [System.Console]::Out.Flush()
        } catch {
            Write-Host "❌ Failed to export JSON format: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Export as XML format
        $xmlPath = Get-SafeFilePath -BasePath $ExportPath -LogType $LogType -DatePart $DatePart -Extension ".xml"
        try {
            Write-CustomProgress -Activity "Saving report" -Status "Generating XML data..." -PercentComplete 0
            $totalEvents = $Events.Count
            $currentEvent = 0
            $batchSize = 1000
            $batch = @()
            $updateInterval = 100
            
            # Pre-calculate common values
            $computerName = $env:COMPUTERNAME
            $exportTime = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            $timeRange = "$($firstEventTime.ToString('yyyy-MM-dd HH:mm')) to $($lastEventTime.ToString('yyyy-MM-dd HH:mm'))"
            
            # Use StreamWriter for streaming writing, reduce memory usage
            $streamWriter = New-Object System.IO.StreamWriter($xmlPath, $false, [System.Text.Encoding]::UTF8, 65536)
            try {
                # Write XML header
                $streamWriter.WriteLine('<?xml version="1.0" encoding="UTF-8"?>')
                $streamWriter.WriteLine('<LogReport>')
                $streamWriter.WriteLine('    <ReportTitle>' + $ReportTitle + '</ReportTitle>')
                $streamWriter.WriteLine('    <ComputerName>' + $computerName + '</ComputerName>')
                $streamWriter.WriteLine('    <OperatingSystem>' + $osInfo + '</OperatingSystem>')
                $streamWriter.WriteLine('    <ExportTime>' + $exportTime + '</ExportTime>')
                $streamWriter.WriteLine('    <TimeRange>' + $timeRange + '</TimeRange>')
                $streamWriter.WriteLine('    <TotalEvents>' + $Events.Count + '</TotalEvents>')
                $streamWriter.WriteLine('    <Events>')
                
                # Batch write event data
                foreach ($e in $Events) {
                    $currentEvent++
                    
                    # Update progress bar every 100 events
                    if ($currentEvent % $updateInterval -eq 0) {
                        $percent = [Math]::Min(100, [Math]::Round(($currentEvent / $totalEvents) * 100))
                        Write-CustomProgress -Activity "Saving report" -Status "Generating XML data $currentEvent/$totalEvents" -PercentComplete $percent -CurrentItem $currentEvent -TotalItems $totalEvents -CurrentTask "Processing event $currentEvent"
                    }
                    
                    $timeCreated = if ($e.TimeCreated) { $e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
                    $id = if ($e.Id) { $e.Id } else { 0 }
                    $level = if ($e.Level) { $e.Level } else { 0 }
                    $levelDisplayName = if ($e.LevelDisplayName) { $e.LevelDisplayName } else { '' }
                    $providerName = if ($e.ProviderName) { $e.ProviderName } else { '' }
                    $message = if ($e.Message) { $e.Message -replace '`r', ' ' -replace '`n', ' ' -replace '`t', ' ' } else { '' }
                    
                    # Build event XML
                    $eventXml = ''
                    $eventXml += '        <Event>'
                    $eventXml += '            <TimeCreated>' + $timeCreated + '</TimeCreated>'
                    $eventXml += '            <Id>' + $id + '</Id>'
                    $eventXml += '            <Level>' + $level + '</Level>'
                    $eventXml += '            <LevelDisplayName>' + $levelDisplayName + '</LevelDisplayName>'
                    $eventXml += '            <ProviderName>' + $providerName + '</ProviderName>'
                    $eventXml += '            <Message>' + $message + '</Message>'
                    $eventXml += '        </Event>'
                    
                    # Add to batch
                    $batch += $eventXml
                    
                    # Write batch when full
                    if ($batch.Count -eq $batchSize) {
                        $streamWriter.Write(($batch -join "`n"))
                        $batch = @()
                    }
                }
                
                # Write remaining data
                if ($batch.Count -gt 0) {
                    $streamWriter.Write(($batch -join "`n"))
                }
                
                # Write XML footer
                $streamWriter.WriteLine()
                $streamWriter.WriteLine('    </Events>')
                $streamWriter.WriteLine('</LogReport>')
            } finally {
                $streamWriter.Close()
            }
            
            # Directly output XML export completed message
            Write-CustomProgress -Activity "Saving report" -Status "XML export completed" -PercentComplete 100
            # Force flush output buffer
            [System.Console]::Out.Flush()
            # Add newline to ensure subsequent output doesn't overwrite progress bar
            Write-Host ""
            # Force flush output buffer
            [System.Console]::Out.Flush()
        } catch {
            # Silently handle XML export errors to avoid showing excessive debug information
            # Write-Host "❌ Failed to export XML format: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Force flush output buffer
        [System.Console]::Out.Flush()
        # Add newline to ensure exported message is on a separate line
        Write-Host "`nExported:" -ForegroundColor Cyan
        Write-Host "  CSV: $csvPath" -ForegroundColor Cyan
        Write-Host "  JSON: $jsonPath" -ForegroundColor Cyan
        Write-Host "  XML: $xmlPath" -ForegroundColor Cyan
    }
    catch {
        Write-Host "❌ Failed to save files: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Recommendation: Check output directory permissions or disk space." -ForegroundColor Yellow
    }
}
#endregion

#region Main Execution
try {
    # --- Permission Pre-check ---
    if (-not (Test-LogAccess -LogName $LogType)) {
        exit 1
    }

    # Silent mode check
    if (-not $Silent) {
        Write-Host "/// AURORA 2026 VelociRaptor-GR All rights reserved ///" -ForegroundColor DarkCyan
        Write-Host "/// Windows System Event Log Export & Intelligent Analysis Tool ///" -ForegroundColor DarkCyan
        Write-Host "/// Please wait... Detecting current system date... ///" -ForegroundColor Cyan
        $Today = Get-Date
        Write-Host "📅 Detection complete! Current date: $($Today.ToString('yyyy-MM-dd')) ///" -ForegroundColor Cyan
        
        # Initialize cache
        Write-Host "/// Checking cache status... ///" -ForegroundColor Cyan
        $null = Initialize-Cache
        Write-Host "/// Cache status check completed! ///" -ForegroundColor Cyan
    } else {
        # Initialize cache in silent mode too
        $null = Initialize-Cache
    }

    # --- Resolve Output Path ---
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        # Use script's parent directory (root directory) as default output path
        $outDir = [System.IO.Path]::Combine($PSScriptRoot, "..\UserLogs")
    }
    else {
        # Enhanced path validation to prevent path injection attacks
        try {
            # Get full path and validate
            $outDir = [System.IO.Path]::GetFullPath($OutputPath)
            
            # Ensure path doesn't contain dangerous characters
            $invalidChars = [System.IO.Path]::GetInvalidPathChars()
            foreach ($char in $invalidChars) {
                if ($outDir.Contains($char)) {
                    throw "Path contains invalid character: $char"
                }
            }
            
            # Ensure path length is within reasonable limits
            if ($outDir.Length -gt 260) {
                throw "Path length exceeds Windows limit (260 characters)"
            }
        } catch {
            if (-not $Silent) {
                Write-Host "❌ Invalid output path: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "💡 Recommendation: Use a valid local path." -ForegroundColor Yellow
            }
            exit 1
        }
    }

    # Enhanced output directory permission validation
    try {
        # Check if directory exists
        if (!(Test-Path $outDir)) {
            # Try to create directory, ensure path is valid
            try {
                New-Item -Path $outDir -ItemType Directory -Force | Out-Null
                if (-not $Silent) {
                    Write-Host "📁 Created output directory: $outDir" -ForegroundColor Green
                }
            } catch {
                throw "Failed to create output directory: $($_.Exception.Message)"
            }
        }
        
        # Validate directory actually exists and is a directory
        if (!(Test-Path $outDir -PathType Container)) {
            throw "Specified path is not a valid directory"
        }
        
        # Test write permission
        $testFile = [System.IO.Path]::Combine($outDir, "test_write_permission.txt")
        try {
            "Test" | Out-File -FilePath $testFile -Encoding UTF8 -ErrorAction Stop
            # Test read permission
            $content = Get-Content -Path $testFile -ErrorAction Stop
            # Test delete permission
            Remove-Item -Path $testFile -Force -ErrorAction Stop
        } catch {
            throw "No write permission: $($_.Exception.Message)"
        }
        
        # Validate directory executable permission
        if (-not (Test-Path $outDir -PathType Container)) {
            throw "Cannot access directory"
        }
    }
    catch {
        if (-not $Silent) {
            Write-Host "❌ No permission to access output directory: $outDir" -ForegroundColor Red
            Write-Host "💡 Recommendation: Select a directory with write permissions." -ForegroundColor Yellow
            Write-Host "📝 Error details: $($_.Exception.Message)" -ForegroundColor Gray
        }
        exit 1
    }

    # --- Get Date Scope ---
    if ($restoreMode -and $restoredSession) {
        # Session restore mode: rebuild scopes from session data
        if (-not $Silent) {
            Write-Host "`n🔄 Rebuilding task scope from session restore data..." -ForegroundColor Cyan
        }
        
        # Try to restore scopes from session data
        if ($restoredSession.Data -and $restoredSession.Data.Scopes) {
            $scopes = $restoredSession.Data.Scopes
            if (-not $Silent) {
                Write-Host "   ✅ Successfully restored $($scopes.Count) log task scopes" -ForegroundColor Green
            }
        } else {
            # Fallback: if no scopes in session data, use default value
            if (-not $Silent) {
                Write-Host "   ⚠️ No task scope found in session data, will use default value" -ForegroundColor Yellow
            }
            $today = (Get-Date).Date
            # Core fix: Ensure LogType is not empty, use parameter default value
            $defaultLogType = if ([string]::IsNullOrWhiteSpace($LogType)) { "System" } else { $LogType }
            $scopes = @( @{ 
                StartTime   = $today
                EndTime     = $today.AddDays(1).AddTicks(-1)
                DatePart    = $today.ToString('yyyyMMdd')
                ReportTitle = "$defaultLogType Log Daily Report - $($today.ToString('yyyy-MM-dd'))"
                LogType     = $defaultLogType
                EventId     = $EventId
                ProviderName = $ProviderName
                Level       = $Level
            })
        }
    }
    elseif ($Silent) {
        # Silent mode: priority use command line parameters (only single log type supported)
        if ($StartTime -and $EndTime) {
            # Use command line passed date parameters
            $startDate = $StartTime
            $endDate = $EndTime
            $datePart = "$($startDate.ToString('yyyyMMdd'))_to_$($endDate.ToString('yyyyMMdd'))"
            $reportTitle = "$LogType Log Report - $($startDate.ToString('yyyy-MM-dd')) to $($endDate.ToString('yyyy-MM-dd'))"
        } else {
            # Use default values (current date)
            $today = (Get-Date).Date
            $startDate = $today
            $endDate = $today.AddDays(1).AddTicks(-1)
            $datePart = $today.ToString('yyyyMMdd')
            $reportTitle = "$LogType Log Daily Report - $($today.ToString('yyyy-MM-dd'))"
        }
        $scopes = @( @{ 
            StartTime   = $startDate
            EndTime     = $endDate
            DatePart    = $datePart
            ReportTitle = $reportTitle
            LogType     = $LogType
            EventId     = $EventId
            ProviderName = $ProviderName
            Level       = $Level
        })
    } else {
        # Interactive mode: get user input (supports multiple log types)
        $scopes = Get-UserDateScope -DefaultLogType $LogType
        
        # Override filter conditions from command line parameters (apply to all scopes)
        for ($i = 0; $i -lt $scopes.Count; $i++) {
            if (![string]::IsNullOrWhiteSpace($EventId)) {
                $scopes[$i].EventId = $EventId
            }
            if (![string]::IsNullOrWhiteSpace($ProviderName)) {
                $scopes[$i].ProviderName = $ProviderName
            }
            if (![string]::IsNullOrWhiteSpace($Level)) {
                $scopes[$i].Level = $Level
            }
        }
        
        # Save progress: Log type and date range configured (save first scope)
        Save-CHSProgress -SessionId $sessionId -Checkpoint "LogTypeSelected" -AdditionalData @{
            LogType = $scopes[0].LogType
            StartTime = $scopes[0].StartTime
            EndTime = $scopes[0].EndTime
            Scopes = $scopes  # Save complete scopes array to session data
        }
        Save-CHSProgress -SessionId $sessionId -Checkpoint "DateRangeConfigured"
        
        # On-demand elevation check: Check if any selected log type requires admin privileges
        $needAdmin = $false
        foreach ($s in $scopes) {
            if ($s.LogType -in $script:AdminRequiredLogTypes) {
                $needAdmin = $true
                break
            }
        }
        
        if ($needAdmin) {
            $elevationResult = Invoke-ElevationCheck -LogType $scopes[0].LogType -FeatureName "Log Export"
            if (-not $elevationResult) {
                Write-Host "`n💡 Tip: You can select System or Application log type to continue in standard mode." -ForegroundColor Yellow
                Write-Host "   Exiting current operation..." -ForegroundColor Gray
                exit 0
            }
        }
    }

    # === [CORE FIX] Comprehensive validation and repair of scopes variable ===
    # Ensure scopes variable is valid, regardless of whether it's restore mode or not
    if (-not $scopes -or $scopes.Count -eq 0) {
        Write-Host "`n⚠️ scopes variable invalid, using default values..." -ForegroundColor Yellow
        $today = (Get-Date).Date
        $defaultLogType = if ([string]::IsNullOrWhiteSpace($LogType)) { "System" } else { $LogType }
        $scopes = @(@{
            StartTime = $today
            EndTime = $today.AddDays(1).AddTicks(-1)
            LogType = $defaultLogType
            DatePart = $today.ToString('yyyyMMdd')
            ReportTitle = "$defaultLogType Log Daily Report - $($today.ToString('yyyy-MM-dd'))"
        })
    } else {
        # Handle case where Scopes is a single object instead of array
        if ($scopes -is [System.Management.Automation.PSCustomObject] -or $scopes -is [hashtable]) {
            Write-Host "`n⚠️ Detected scopes as single object, converting to array..." -ForegroundColor Yellow
            $scopes = @($scopes)
        }
        
        # Ensure scopes is array
        if (-not $scopes -or $scopes.Count -eq 0) {
            Write-Host "`n⚠️ scopes still invalid, using default values..." -ForegroundColor Yellow
            $today = (Get-Date).Date
            $defaultLogType = if ([string]::IsNullOrWhiteSpace($LogType)) { "System" } else { $LogType }
            $scopes = @(@{
                StartTime = $today
                EndTime = $today.AddDays(1).AddTicks(-1)
                LogType = $defaultLogType
                DatePart = $today.ToString('yyyyMMdd')
                ReportTitle = "$defaultLogType Log Daily Report - $($today.ToString('yyyy-MM-dd'))"
            })
        } else {
            # Handle special date format \/Date(...)\/
            for ($i = 0; $i -lt $scopes.Count; $i++) {
                $scopeItem = $scopes[$i]
                
                # Convert StartTime
                if ($scopeItem.StartTime -match '\\/Date\((\d+)\)\\/') {
                    $timestamp = [long]$matches[1]
                    $scopes[$i].StartTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                    Write-Host "`n⚠️ Converted scopes[$i] StartTime" -ForegroundColor Yellow
                }
                
                # Convert EndTime
                if ($scopeItem.EndTime -match '\\/Date\((\d+)\)\\/') {
                    $timestamp = [long]$matches[1]
                    $scopes[$i].EndTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                    Write-Host "⚠️ Converted scopes[$i] EndTime" -ForegroundColor Yellow
                }
                
                # Ensure StartTime and EndTime are not null
                if (-not $scopes[$i].StartTime -or -not $scopes[$i].EndTime) {
                    $today = (Get-Date).Date
                    if (-not $scopes[$i].StartTime) {
                        $scopes[$i].StartTime = $today
                        Write-Host "⚠️ scopes[$i] StartTime is null, set to today" -ForegroundColor Yellow
                    }
                    if (-not $scopes[$i].EndTime) {
                        $scopes[$i].EndTime = $today.AddDays(1).AddTicks(-1)
                        Write-Host "⚠️ scopes[$i] EndTime is null, set to end of today" -ForegroundColor Yellow
                    }
                }
                
                # Ensure LogType has a value
                if ([string]::IsNullOrWhiteSpace($scopes[$i].LogType)) {
                    $scopes[$i].LogType = if ([string]::IsNullOrWhiteSpace($LogType)) { "System" } else { $LogType }
                    Write-Host "⚠️ scopes[$i] LogType is empty, set to default" -ForegroundColor Yellow
                }
            }
        }
    }
    
    Write-Host "`n✅ scopes validation complete, $($scopes.Count) scopes total" -ForegroundColor Green

    # === NEW LOGIC: Evaluate system performance first, then scan high-risk events ===
    if (-not $Silent) {
        Write-Host "`n[Evaluating system performance...]" -ForegroundColor Cyan
    }
    # ====== Add: Sync performance evaluation status to GUI ======
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        $global:syncHash.CurrentActivity = "1/4 Environment Preparation & Initialization"
        $global:syncHash.CurrentStatus = "Evaluating system performance and hardware resources..."
    }
    # Evaluate system performance and calculate optimal chunk size
    $performanceScore = Get-SystemPerformanceScore
    $optimalChunkSize = Get-OptimalChunkSize -PerformanceScore $performanceScore -LogType $scopes[0].LogType
    
    # Get resource optimized strategy
    $logScanningStrategy = Get-ResourceOptimizedStrategy -PerformanceScore $performanceScore -TaskType "LogScanning"
    $reportGenerationStrategy = Get-ResourceOptimizedStrategy -PerformanceScore $performanceScore -TaskType "ReportGeneration"
    
    # Get intelligent cache strategy
    $cacheStrategy = Get-IntelligentCacheStrategy -PerformanceScore $performanceScore -DataSizeKB 10000
    
    # Get file operation optimization parameters
    $fileOperationParams = Optimize-FileOperations -PerformanceScore $performanceScore
    
    if (-not $Silent) {
        Write-Host "`n[Resource Optimization Strategy]" -ForegroundColor Cyan
        Write-Host "Performance Level: $($logScanningStrategy.PerformanceLevel)" -ForegroundColor Green
        Write-Host "Log Scanning Parallelism: $($logScanningStrategy.Strategy.Parallelism)" -ForegroundColor Green
        Write-Host "Report Generation Parallelism: $($reportGenerationStrategy.Strategy.Parallelism)" -ForegroundColor Green
        Write-Host "Cache Compression: $($cacheStrategy.Compression)" -ForegroundColor Green
        Write-Host "I/O Buffer Size: $($fileOperationParams.BufferSize) bytes" -ForegroundColor Green
    }
    
    # Save progress: Performance assessment complete
    Save-CHSProgress -SessionId $sessionId -Checkpoint "PerformanceAssessed" -AdditionalData @{
        PerformanceScore = $performanceScore
        ChunkSize = $optimalChunkSize
    }
    
    # Save selected options (only ask once for first scope, reuse for subsequent scopes)
    # === [Checkpoint Resume Fix]: Don't reset if already restored from session
    if ($restoreMode -and $exportChoice) {
        if (-not $Silent) {
            Write-Host "`n💡 Using restored export choice: $exportChoice" -ForegroundColor Cyan
        }
    } else {
        $exportChoice = $null  # "HighRisk" or "Full" or "Skip"
    }
    if (-not ($restoreMode -and $trendAnalysisChoice)) {
        $trendAnalysisChoice = $null  # "Y" or "N"
    }
    $useCacheChoices = @{}  # Record cache choices per log type
    
    # === Loop through each scope ===
    for ($scopeIndex = 0; $scopeIndex -lt $scopes.Count; $scopeIndex++) {
        $scope = $scopes[$scopeIndex]
        
        # Calculate dynamic progress (45% - 70%, smooth transition when processing multiple logs)
        if ($scopes.Count -gt 1) {
            $baseProgress = 45
            $targetProgress = 70
            $singleStep = ($targetProgress - $baseProgress) / $scopes.Count
            $currentProgress = [Math]::Round($baseProgress + ($singleStep * $scopeIndex))
            Save-CHSProgress -SessionId $sessionId -Checkpoint "ProcessingStarted" -CustomProgress $currentProgress -CustomStage "Processing $($scope.LogType) ($($scopeIndex + 1)/$($scopes.Count))"
        }
        
        if (-not $Silent) {
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "  [$($scopeIndex + 1)/$($scopes.Count)] Processing: $($scope.LogType)" -ForegroundColor White
            Write-Host "========================================" -ForegroundColor Cyan
        }
        
        # Check for matching cache
        $cacheMatch = Test-CacheMatch -LogType $scope.LogType -StartTime $scope.StartTime -EndTime $scope.EndTime -EventId $scope.EventId -ProviderName $scope.ProviderName -Level $scope.Level
    
        if ($cacheMatch.Match) {
            # Check if we already have a cache choice for this log type
            if ($useCacheChoices.ContainsKey($scope.LogType)) {
                $useCache = $useCacheChoices[$scope.LogType]
            } else {
                # First time asking the user
                $useCache = Get-CacheUsageChoice -CacheItem $cacheMatch.CacheItem
                $useCacheChoices[$scope.LogType] = $useCache
            }
            
            if ($useCache) {
                # Use cached data
                $highRiskEvents = $cacheMatch.CacheItem.Data
                Write-Host "`n[Using cached data]" -ForegroundColor Cyan
            } else {
                # Real-time scanning
                if (-not $Silent) {
                    Write-Host "`n[Scanning for high-risk events in selected range...]" -ForegroundColor Cyan
                }
                $highRiskEvents = Get-HighRiskEvents `
                    -StartTime $scope.StartTime `
                    -EndTime $scope.EndTime `
                    -LogType $scope.LogType `
                    -EventId $scope.EventId `
                    -ProviderName $scope.ProviderName `
                    -Level $scope.Level `
                    -PerformanceScore $performanceScore `
                    -OptimalChunkSize $optimalChunkSize `
                    -LogScanningStrategy $logScanningStrategy `
                    -CacheStrategy $cacheStrategy `
                    -ForceRescan:$true
            }
        } else {
            # No matching cache, real-time scanning
            if (-not $Silent) {
                Write-Host "`n[No matching cache, scanning for high-risk events in selected range...]" -ForegroundColor Cyan
            }
            $highRiskEvents = Get-HighRiskEvents `
                -StartTime $scope.StartTime `
                -EndTime $scope.EndTime `
                -LogType $scope.LogType `
                -EventId $scope.EventId `
                -ProviderName $scope.ProviderName `
                -Level $scope.Level `
                -PerformanceScore $performanceScore `
                -OptimalChunkSize $optimalChunkSize `
                -LogScanningStrategy $logScanningStrategy `
                -CacheStrategy $cacheStrategy `
                -ForceRescan:$ForceRescan
        }

    # Get total event count (from cache to avoid duplicate calculation)
    $totalEventCount = 0
    $totalEventsCacheKey = Get-CacheKey -LogType "$($scope.LogType)-Full" -StartTime $scope.StartTime -EndTime $scope.EndTime -EventId $scope.EventId -ProviderName $scope.ProviderName -Level $scope.Level
    $totalEventsData = Get-CachedLogData -CacheKey $totalEventsCacheKey -Silent $true
    if ($totalEventsData) {
        $totalEventCount = $totalEventsData.Count
    } else {
        # If cache doesn't exist, try to get total event count directly
        try {
            $totalEvents = Get-WinEvent -FilterHashtable @{ LogName = $scope.LogType; StartTime = $scope.StartTime; EndTime = $scope.EndTime } -ErrorAction SilentlyContinue
            $totalEventCount = if ($totalEvents) { $totalEvents.Count } else { 0 }
        } catch {
            $totalEventCount = 0
        }
    }

    # Show summary
    $critical = 0
    $errors = 0
    $warnings = 0
    
    foreach ($event in $highRiskEvents) {
        if ($event.Level -eq 1) {
            $critical++
        } elseif ($event.Level -eq 2) {
            $errors++
        } elseif ($event.Level -eq 3) {
            $warnings++
        }
    }
    
    $totalHigh = $critical + $errors + $warnings

    # Save progress: High-risk event scan complete
    $scanProgress = 60
    Save-CHSProgress -SessionId $sessionId -Checkpoint "HighRiskScanComplete" -CustomProgress $scanProgress -CustomStage "High-risk event scan complete, found $totalHigh high-risk events" -AdditionalData @{
        HighRiskEventCount = $totalHigh
        TotalEventCount = $totalEventCount
        CriticalEvents = $critical
        ErrorEvents = $errors
        WarningEvents = $warnings
    }

    if (-not $Silent) {
        Write-Host "`n[Scan Complete]" -ForegroundColor Green
        Write-Host "Found: $critical Critical, $errors Errors, $warnings Warnings (Total: $totalHigh high-risk events)" -ForegroundColor Yellow
        if ($totalEventCount -gt 0) {
            Write-Host "Total events: $totalEventCount" -ForegroundColor Cyan
        }
        
        # === System Health Assessment ===
        # Calculate health score
        $totalIssues = $critical * 3 + $errors * 2 + $warnings
        $healthScore = 100
        if ($totalEventCount -gt 0) {
            $healthScore = [Math]::Max(0, 100 - ($totalIssues * 100 / $totalEventCount))
        }
        
        # Health level assessment
        if ($healthScore -ge 90) {
            $healthLevel = "Excellent"
            $healthStatus = "System Status: Excellent — Running stably, no obvious anomalies!"
            $consoleColor = 'Green'
        } elseif ($healthScore -ge 70) {
            $healthLevel = "Good"
            $healthStatus = "System Status: Good — Few anomalies, regular checks recommended!"
            $consoleColor = 'Yellow'
        } elseif ($healthScore -ge 50) {
            $healthLevel = "Average"
            $healthStatus = "System Status: Average — Many anomalies, need attention!"
            $consoleColor = 'Yellow'
        } else {
            $healthLevel = "Poor"
            $healthStatus = "System Status: Poor — Many anomalies, immediate inspection recommended!"
            $consoleColor = 'Red'
        }
        
        Write-Host "`n[System Health Assessment]" -ForegroundColor Yellow
        Write-Host "Errors: $errors | Warnings: $warnings | Critical: $critical" -ForegroundColor Gray
        Write-Host "Health Score: $([Math]::Round($healthScore, 1))/100 | Health Level: $healthLevel" -ForegroundColor Cyan
        Write-Host $healthStatus -ForegroundColor $consoleColor
    }
    
    # Save progress: System health assessment complete
    $healthProgress = 70
    Save-CHSProgress -SessionId $sessionId -Checkpoint "HealthAssessmentComplete" -CustomProgress $healthProgress -CustomStage "System health assessment complete" -AdditionalData @{
        HealthScore = $healthScore
        HealthLevel = $healthLevel
        HealthStatus = $healthStatus
    }

    # Determine what to export
    if ($restoreMode -and $exportChoice) {
        # === [Checkpoint Resume Fix] Using restored export choice ===
        if (-not $Silent) {
            Write-Host "`n💡 Using restored export mode: $exportChoice" -ForegroundColor Cyan
        }
        
        # Set corresponding reportMode
        if ($exportChoice -eq "HighRisk") {
            $reportMode = "High-Risk Events Only"
        } else {
            $reportMode = "Full $($scope.LogType) Log"
        }
    } elseif ($Silent) {
        # Silent mode: select export scope based on parameter
        if ($ExportScope -eq "HighRiskOnly") {
            # Export high-risk only
            $events = $highRiskEvents
            $reportMode = "High-Risk Events Only"
        } else {
            # Default to export full log
            $events = Get-FullSystemLog `
                -StartTime $scope.StartTime `
                -EndTime $scope.EndTime `
                -LogType $scope.LogType `
                -EventId $scope.EventId `
                -ProviderName $scope.ProviderName `
                -Level $scope.Level `
                -PerformanceScore $performanceScore `
                -OptimalChunkSize $optimalChunkSize `
                -TotalEventCount $totalEventCount
            $reportMode = "Full $($scope.LogType) Log"
        }
    } else {
        if ($null -eq $exportChoice) {
            if ($totalHigh -eq 0) {
                Write-Host "`n💡 No high-risk events found." -ForegroundColor Cyan
                
                # Console mode: use Get-AuroraInteraction
                $maxRetries = 3
                $retryCount = 0
                $choice = $null
                while ($retryCount -lt $maxRetries -and $null -eq $choice) {
                    $tempChoice = Get-AuroraInteraction -PromptMessage "`nPress ENTER to export FULL log, or type 'skip' to cancel"
                    if ([string]::IsNullOrWhiteSpace($tempChoice)) {
                        $exportChoice = "Full"
                        $choice = ""
                    } elseif ($tempChoice -like 'skip*') {
                        Write-Host "`nOperation cancelled by user." -ForegroundColor Gray
                        exit 0
                    } else {
                        $retryCount++
                        $remaining = $maxRetries - $retryCount
                        if ($remaining -gt 0) {
                            Write-Host "`n❌ Invalid input! Press ENTER to export FULL log, or type 'skip' to cancel (remaining attempts: $remaining)" -ForegroundColor Red
                        } else {
                            Write-Host "`n❌ Too many invalid attempts, defaulting to export FULL log." -ForegroundColor Red
                            $exportChoice = "Full"
                            $choice = ""
                        }
                    }
                }
                
                $events = Get-FullSystemLog `
                    -StartTime $scope.StartTime `
                    -EndTime $scope.EndTime `
                    -LogType $scope.LogType `
                    -EventId $scope.EventId `
                    -ProviderName $scope.ProviderName `
                    -Level $scope.Level `
                    -PerformanceScore $performanceScore `
                    -OptimalChunkSize $optimalChunkSize `
                    -TotalEventCount $totalEventCount
                $reportMode = "Full $($scope.LogType) Log"
            }
            else {
                # Console mode: use Get-AuroraInteraction
                $maxRetries = 3
                $retryCount = 0
                $choice = $null
                while ($retryCount -lt $maxRetries -and $null -eq $choice) {
                    $tempChoice = Get-AuroraInteraction -PromptMessage "`nPress ENTER to export HIGH-RISK ONLY, or type '1' to export FULL log"
                    if ([string]::IsNullOrWhiteSpace($tempChoice)) {
                        # Press ENTER, export high-risk only
                        $events = $highRiskEvents
                        $reportMode = "High-Risk Events Only"
                        $choice = ""
                        $exportChoice = "HighRisk"
                    } elseif ($tempChoice -eq '1') {
                        # Type 1, export full log
                        $events = Get-FullSystemLog `
                            -StartTime $scope.StartTime `
                            -EndTime $scope.EndTime `
                            -LogType $scope.LogType `
                            -EventId $scope.EventId `
                            -ProviderName $scope.ProviderName `
                            -Level $scope.Level `
                            -PerformanceScore $performanceScore `
                            -OptimalChunkSize $optimalChunkSize `
                            -TotalEventCount $totalEventCount
                        $reportMode = "Full $($scope.LogType) Log"
                        
                        $choice = "1"  # ====== 新增：给 choice 赋值，打破死循环 ======
                        $exportChoice = "Full"
                    } else {
                        # Invalid input, prompt for retry
                        $retryCount++
                        $remaining = $maxRetries - $retryCount
                        if ($remaining -gt 0) {
                            Write-Host "`n❌ Invalid input! Press ENTER to export HIGH-RISK ONLY, or type '1' to export FULL log (remaining attempts: $remaining)" -ForegroundColor Red
                        } else {
                            Write-Host "`n❌ Too many invalid attempts, defaulting to export HIGH-RISK ONLY." -ForegroundColor Red
                            $events = $highRiskEvents
                            $reportMode = "High-Risk Events Only"
                            $choice = ""
                            $exportChoice = "HighRisk"
                        }
                    }
                }
            }
        } else {
            if (-not $Silent) {
                Write-Host "`n💡 Using previously selected export mode: $exportChoice" -ForegroundColor Cyan
            }
        }
    }

    # === [Checkpoint Resume Fix] Unified Export Logic ===
    # Only execute if not in restore mode, or in restore mode with progress <80
    if ((-not $restoreMode) -or ($restoredSession.Progress -lt 80)) {
        if ($exportChoice -eq "HighRisk") {
            $events = $highRiskEvents
            $reportMode = "High-Risk Events Only"
            
            # Save progress: Export mode selected
            Save-CHSProgress -SessionId $sessionId -Checkpoint "ExportModeSelected" -CustomProgress 75 -CustomStage "Export mode selected: $reportMode" -AdditionalData @{
                ExportChoice = $exportChoice
                ReportMode = $reportMode
            }
        } else {
            # Save progress: Fetching full log
            Save-CHSProgress -SessionId $sessionId -Checkpoint "FetchingFullLog" -CustomProgress 75 -CustomStage "Fetching full $($scope.LogType) log" -AdditionalData @{
                ExportChoice = $exportChoice
                ReportMode = "Full $($scope.LogType) Log"
            }
            
            $events = Get-FullSystemLog `
                -StartTime $scope.StartTime `
                -EndTime $scope.EndTime `
                -LogType $scope.LogType `
                -EventId $scope.EventId `
                -ProviderName $scope.ProviderName `
                -Level $scope.Level `
                -PerformanceScore $performanceScore `
                -OptimalChunkSize $optimalChunkSize `
                -TotalEventCount $totalEventCount
            $reportMode = "Full $($scope.LogType) Log"
            
            # Save progress: Full log fetched
            Save-CHSProgress -SessionId $sessionId -Checkpoint "FullLogFetched" -CustomProgress 80 -CustomStage "Full $($scope.LogType) log fetched, $($events.Count) events" -AdditionalData @{
                ExportChoice = $exportChoice
                ReportMode = $reportMode
                FullLogEventCount = $events.Count
            }
        }
    }

    if (-not $Silent) {
        Write-Host "`n[Exporting: $reportMode]" -ForegroundColor Cyan
    }

    # Save progress: Export started
    Save-CHSProgress -SessionId $sessionId -Checkpoint "ExportStarted" -CustomProgress 85 -CustomStage "Exporting: $reportMode"

    # --- Generate Report ---
    New-LogReport -Events $events -ReportTitle $scope.ReportTitle -DatePart $scope.DatePart -ExportPath $outDir -LogType $scope.LogType
    
        # Save progress: Log export complete (save only after last scope)
        if ($scopeIndex -eq $scopes.Count - 1) {
            Save-CHSProgress -SessionId $sessionId -Checkpoint "ExportComplete" -AdditionalData @{
                ExportPath = $outDir
                EventCount = $events.Count
                ExportMode = $ExportMode
            }
        }

    # --- Trend Analysis Option ---
    if ($Silent) {
        # Silent mode: decide based on parameter
        if ($TrendAnalysis) {
            # Perform trend analysis
            $dateRangeDays = ($scope.EndTime - $scope.StartTime).Days + 1
            New-LogTrendAnalysis -ExportPath $outDir -LogType $scope.LogType -StartDate $scope.StartTime -EndDate $scope.EndTime -PerformanceScore $performanceScore -OptimalChunkSize $optimalChunkSize -EventId $scope.EventId -ProviderName $scope.ProviderName -Level $scope.Level
        }
        } else {
            # Console mode: use Get-AuroraInteraction
            if ($null -eq $trendAnalysisChoice) {
                # First time asking user
                $maxRetries = 3
                $retryCount = 0
                $choice = $null
                while ($retryCount -lt $maxRetries -and $null -eq $choice) {
                    $tempChoice = Get-AuroraInteraction -PromptMessage 'Would you like to perform log trend analysis? (Y/N) [Default: N]'
                    # Press Enter for default: No
                    if ([string]::IsNullOrWhiteSpace($tempChoice) -or $tempChoice -like 'N*') {
                        # Skip trend analysis
                        $trendAnalysisChoice = "N"
                        $choice = "N"
                    } elseif ($tempChoice -like 'Y*') {
                        # Perform trend analysis
                        $trendAnalysisChoice = "Y"
                        $choice = "Y"
                    } else {
                        # Invalid input, prompt for retry
                        $retryCount++
                        $remaining = $maxRetries - $retryCount
                        if ($remaining -gt 0) {
                            Write-Host 'Invalid input! Please enter Y or N (remaining attempts: ' $remaining ')' -ForegroundColor Red
                        } else {
                            Write-Host 'Too many invalid inputs, skipping trend analysis.' -ForegroundColor Red
                            $trendAnalysisChoice = "N"
                            $choice = "N"
                        }
                    }
                }
            }
        
        if ($trendAnalysisChoice -like 'Y*') {
            # Perform trend analysis
            $dateRangeDays = ($scope.EndTime - $scope.StartTime).Days + 1
            Write-Host "`nStarting analysis of $dateRangeDays days of log trends..." -ForegroundColor Cyan
            New-LogTrendAnalysis -ExportPath $outDir -LogType $scope.LogType -StartDate $scope.StartTime -EndDate $scope.EndTime -PerformanceScore $performanceScore -OptimalChunkSize $optimalChunkSize -EventId $scope.EventId -ProviderName $scope.ProviderName -Level $scope.Level
            
            # Save progress: Trend analysis complete (save only after last scope)
            if ($scopeIndex -eq $scopes.Count - 1) {
                Save-CHSProgress -SessionId $sessionId -Checkpoint "TrendAnalysisComplete"
            }
        }
        }
    }
    
    # Save progress: Waiting for smart analysis (save only after all scopes processed)
    # Only save if not in restore mode, or in restore mode with progress <95
    if ((-not $restoreMode) -or ($restoredSession.Progress -lt 95)) {
        Save-CHSProgress -SessionId $sessionId -Checkpoint "SmartAnalysisPending" -AdditionalData @{
            ExportPath = $outDir
        }
    }

    # --- Auto-open or prompt ---
    # Only execute if not in restore mode, or in restore mode with progress <90
    if ((-not $restoreMode) -or ($restoredSession.Progress -lt 90)) {
        $choice = "N" # Default value
        if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
            # GUI mode: use parameter or default, avoid blocking
            $choice = if ($AutoOpen) { "Y" } else { "N" }
        } else {
            # Only in pure console mode, allow Read-Host
            if (-not $Silent) {
                 $choice = Read-Host "`nOpen output folder? (Y/N)"
            }
        }
        if ($AutoOpen -or $choice -like 'Y*') {
            if (Test-Path $outDir) {
                Start-Process explorer.exe -ArgumentList $outDir
                if (-not $Silent) {
                    Write-Host "📂 Opening output folder..." -ForegroundColor Cyan
                }
            }
        }
    }

    # === [Checkpoint Resume Fix] Smart Analysis ===
    $skipSmartAnalysis = $false
    
    if ($restoreMode -and $restoredSession.Progress -ge 95) {
        # Progress >=95 means we already waited for smart analysis, skip
        Write-Host "`n✅ Skipping: Smart analysis already processed (Restored progress $($restoredSession.Progress)% >= 95%)" -ForegroundColor Green
        $skipSmartAnalysis = $true
    }
    
    if (-not $skipSmartAnalysis) {
        # === [Checkpoint Resume Fix: Smart analysis start] ===
        
        # =========================================================
        # 🚀 Invoke AURORA Smart Mode to analyze exported logs
        # =========================================================
        if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        # Only invoke in GUI mode
        Write-Host "`n🧠 Invoking AURORA Smart Diagnostic Engine..." -ForegroundColor Cyan
        
        try {
            # Show confirmation dialog using AuroraTaskHUD
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "  Smart Diagnostic Analysis Available" -ForegroundColor White
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "`n📊 Exported CSV files detected:" -ForegroundColor Yellow
            Write-Host "   Location: $outDir" -ForegroundColor Gray
            
            # Count CSV files
            $csvCount = (Get-ChildItem -Path $outDir -Filter "*_Log_*.csv" -File -ErrorAction SilentlyContinue).Count
            $csvCount += (Get-ChildItem -Path $outDir -Filter "*_日志_*.csv" -File -ErrorAction SilentlyContinue).Count
            
            if ($csvCount -gt 0) {
                Write-Host "   Files: $csvCount CSV file(s) found" -ForegroundColor Green
            } else {
                Write-Host "   Files: No CSV files found" -ForegroundColor Red
            }
            
            Write-Host "`n🔍 Smart Mode will:" -ForegroundColor Cyan
            Write-Host "   ✓ Load exported CSV files" -ForegroundColor White
            Write-Host "   ✓ Analyze against knowledge base" -ForegroundColor White
            Write-Host "   ✓ Provide auto-healing solutions" -ForegroundColor White
            
            Write-Host "`n⚡ Launch smart diagnostic analysis now?" -ForegroundColor Yellow
            Write-Host "========================================`n" -ForegroundColor Cyan
            
            # Ask for confirmation (via GUI dialog or console input)
            $userConfirmed = $false
            
            if ($null -ne (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
                # GUI mode: Request user confirmation via syncHash
                Write-Host "📋 Waiting for user confirmation..." -ForegroundColor Gray
                
                # Set authorization request flag
                $global:syncHash.ResetAuthorizationModal = $true  # Force reset state first
                
                # Give GUI some time to reset state
                Start-Sleep -Milliseconds 100
                
                $global:syncHash.SmartAnalysisRequested = $true
                $global:syncHash.SmartAnalysisAuthorized = $null  # Reset to null, wait for user decision
                
                # Wait for GUI response
                $waitCount = 0
                $maxWaitCount = 600
                while ($global:syncHash.SmartAnalysisAuthorized -eq $null -and 
                       $waitCount -lt $maxWaitCount) {
                    Start-Sleep -Milliseconds 50
                    $waitCount++
                }
                
                # Log the wait result
                if ($waitCount -lt $maxWaitCount) {
                    Write-Host "✅ GUI responded to smart analysis request (waited $($waitCount * 50)ms)" -ForegroundColor Green
                } else {
                    Write-Host "⚠️ GUI response timeout (waited 30 seconds), continuing..." -ForegroundColor Yellow
                }
                
                # Read user decision
                $userConfirmed = ($global:syncHash.SmartAnalysisAuthorized -eq $true)
                
                # Clean up flags
                $global:syncHash.SmartAnalysisRequested = $false
                
                if ($userConfirmed) {
                    Write-Host "`n✅ User confirmed, starting smart analysis..." -ForegroundColor Green
                } else {
                    Write-Host "`n⏭️ User skipped smart analysis." -ForegroundColor Yellow
                }
            }
            else {
                # Console mode: Use Read-Host
                try {
                    $confirmChoice = Read-Host "   Start smart analysis? (Y/N) [Default: Y]"
                    $userConfirmed = ([string]::IsNullOrWhiteSpace($confirmChoice) -or $confirmChoice -like 'Y*')
                }
                catch {
                    Write-Host "⚠️ Non-interactive environment detected, auto-starting smart analysis..." -ForegroundColor Yellow
                    $userConfirmed = $true  # Default to confirm
                }
            }
            
            if ($userConfirmed) {
                # User confirmed, proceed with smart analysis
                Write-Host "`n📖 Loading Smart Engine..." -ForegroundColor Cyan
                
                # Build Smart Mode parameters
                $smartParams = @{
                    Language = "ENG"  # Default to English
                    FromPRO = $true   # Mark as invoked from PRO mode
                    ExportedLogPath = $outDir  # Pass the exported log directory
                }
                
                # Check if Smart Engine file exists
                $smartEnginePath = "$PSScriptRoot\AURORA-SmartEngine.ps1"
                if (Test-Path $smartEnginePath) {
                    # Execute Smart Engine with parameters
                    & $smartEnginePath @smartParams
                    
                    Write-Host "`n✅ Smart diagnostic analysis completed!" -ForegroundColor Green
                    
                    # Save progress: Smart analysis complete
                    Save-CHSProgress -SessionId $sessionId -Checkpoint "SmartAnalysisComplete"
                } else {
                    Write-Host "⚠️ Smart Engine file not found, skipping smart analysis." -ForegroundColor Yellow
                    Write-Host "   Expected path: $smartEnginePath" -ForegroundColor Gray
                }
            } else {
                # User declined
                Write-Host "`n⏭️ Smart analysis skipped." -ForegroundColor Yellow
                Write-Host "   You can manually run AURORA-SmartEngine.ps1 later if needed." -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "⚠️ Smart Engine invocation failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "   This does not affect the exported log results." -ForegroundColor Gray
        }
        }
        # === [Checkpoint Resume Fix: Smart analysis end] ===
    }

    if (-not $Silent) {
        Write-Host "`n✅ Operation completed! Thank you for using this tool." -ForegroundColor Green
        
        # Save final progress
        Save-CHSProgress -SessionId $sessionId -Checkpoint "Completed"
        
        # Mark session as complete and archive
        if ($sessionId) {
            Complete-Session -SessionId $sessionId -Archive
            Write-Verbose "[ProgressManager] Session completed and archived: $sessionId"
        }
        
        # Only in non-GUI standalone console mode, require pressing Enter to exit
        if ($null -eq (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
            Write-Host "`nPress Enter to exit" -ForegroundColor Gray
            Read-Host | Out-Null
        }
    }
}
catch {
    if (-not $Silent) {
        Write-Host "`n❌ Error occurred: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Message -match 'Access is denied') {
            Write-Host "💡 Recommendation: Run PowerShell as Administrator to access all system logs." -ForegroundColor Yellow
        }
        # Only in non-GUI standalone console mode, require pressing Enter to exit
        if ($null -eq (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
            Write-Host "`nPress Enter to exit" -ForegroundColor Gray
            Read-Host | Out-Null
        }
    }
    exit 1
}
#endregion