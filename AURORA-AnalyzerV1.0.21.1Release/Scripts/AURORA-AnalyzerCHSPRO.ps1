#AURORA-AnalyzerCHSPRO.ps1
#Requires -Version 5.1
# WARNING: 本工具仅用于个人学习使用。
# PowerShell Version: 5.1
<#
.SYNOPSIS
    Windows 系统事件日志导出与智能分析工具
.DESCRIPTION
    支持按单日或日期范围导出 System 日志，生成结构化摘要报告与 CSV 原始数据。
    自动识别错误、警告、严重事件，并评估系统健康状态。
.PARAMETER OutputPath
    可选。指定输出目录。默认为 当前工作目录\UserLogs。
.PARAMETER AutoOpen
    开关参数。导出完成后自动打开输出文件夹。
.PARAMETER LogType
    可选。指定日志类型。默认为 System。
.PARAMETER GUI_Mode
    开关参数。标记是否在GUI模式下运行。
.NOTES
    版本: V12.1Release
    作者: AURORA VelociRaptor-GR Dev PRJ.
    构建时间: 2026.05.09
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
# 🔒 启动检测：只允许由GUI启动，禁止直接运行
# ==========================================
$isLaunchedByGUI = $false

# 检测方式1: 检查是否有GUI_Mode参数
if ($GUI_Mode) {
    $isLaunchedByGUI = $true
}

# 检测方式2: 检查是否有全局syncHash变量
if (-not $isLaunchedByGUI -and (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
    $isLaunchedByGUI = $true
}

# 如果不是由GUI启动，则显示提示并退出
if (-not $isLaunchedByGUI) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  ❌ 此脚本不能直接运行！" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "请使用以下方式启动：" -ForegroundColor Yellow
    Write-Host "  1. 双击运行 AURORA.Launcher-双击启动.exe" -ForegroundColor White
    Write-Host "  2. 或者运行 AURORA-AnalyzerLauncherGUI.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "程序将在5秒后自动关闭..." -ForegroundColor Gray
    
    Start-Sleep -Seconds 5
    exit 1
}

# === 导入进度管理器 ===
# 获取脚本所在目录（兼容 Runspace 环境）
$progressManagerDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
. "$progressManagerDir\AURORA-ProgressManager.ps1"
. "$progressManagerDir\AURORA-ProgressManager-Integration-CHS.ps1"

# === 初始化进度管理器 ===
$null = Initialize-CacheDirectory -ToolPath $progressManagerDir

# === 会话管理变量 ===
$sessionId = $null
$restoreMode = $false

# === 辅助函数：安全保存进度 ===
function Save-ProgressSafe {
    param(
        [string]$Checkpoint,
        [hashtable]$AdditionalData = @{},
        [int]$CustomProgress = -1,
        [string]$CustomStage = ""
    )
    try {
        if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
            if ($CustomProgress -ge 0 -and $CustomProgress -le 100) {
                $global:syncHash.Progress = $CustomProgress
            }
            if (-not [string]::IsNullOrWhiteSpace($CustomStage)) {
                $global:syncHash.CurrentStatus = $CustomStage
            }
        }
        if ($sessionId) {
            $params = @{
                SessionId = $sessionId
                Checkpoint = $Checkpoint
                AdditionalData = $AdditionalData
            }
            if ($CustomProgress -ge 0 -and $CustomProgress -le 100) {
                $params['CustomProgress'] = $CustomProgress
            }
            if (-not [string]::IsNullOrWhiteSpace($CustomStage)) {
                $params['CustomStage'] = $CustomStage
            }
            Save-CHSProgress @params
        }
    }
    catch {
        Write-Verbose "[ProgressManager] 保存进度失败：$_"
    }
}

# === 按需提权检测函数 ===
$script:AdminRequiredLogTypes = @("Security", "Setup", "DNS Server", "DHCP Server", "Directory Service", "IIS Admin Service")

function Test-AdminRequired {
    param([string]$LogType)
    return $script:AdminRequiredLogTypes -contains $LogType
}

function Invoke-ElevationCheck {
    param(
        [string]$LogType,
        [string]$FeatureName,
        [switch]$Silent
    )
    
    # 检查是否需要管理员权限
    if (-not (Test-AdminRequired -LogType $LogType)) {
        return $true
    }
    
    # 检查当前是否具有管理员权限
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        return $true
    }
    
    # 没有权限，触发 GUI 提权请求
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        # GUI 模式：设置提权请求标志
        $global:syncHash.RequestElevation = $true
        $global:syncHash.ElevationReason = "$FeatureName 需要管理员权限才能访问 $($LogType) 日志"
        $global:syncHash.ElevationLogType = $LogType
        $global:syncHash.ElevationAuthorized = $null
        
        Write-Host "⚠️ 访问 $($LogType) 日志需要管理员权限" -ForegroundColor Yellow
        Write-Host "   正在请求提权..." -ForegroundColor Cyan
        
        # 等待用户决策
        $timeout = 300  # 30 秒超时
        $elapsed = 0
        while ($null -eq $global:syncHash.ElevationAuthorized -and $elapsed -lt $timeout) {
            Start-Sleep -Milliseconds 100
            $elapsed += 100
        }
        
        if ($global:syncHash.ElevationAuthorized -eq $true) {
            Write-Host "✅ 用户授权提权，正在重启..." -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 用户拒绝提权，将跳过 $($LogType) 日志访问" -ForegroundColor Red
            return $false
        }
    } else {
        # 控制台模式：直接提示
        Write-Host "⚠️ 访问 $($LogType) 日志需要管理员权限" -ForegroundColor Yellow
        Write-Host "   请以管理员身份重新运行本工具" -ForegroundColor Cyan
        return $false
    }
}

# === 【核心修复 3/3】PRO 脚本负责检测会话，GUI 负责显示 HUD，通过 syncHash 通信 ===
if (Test-PendingSession) {
    if (-not $Silent) {
        Write-Host "`n🔄 检测到未完成的会话" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        # 恢复会话获取详细信息
        $restoredSession = Restore-SessionProgress
        
        if ($restoredSession) {
            $sessionId = $restoredSession.SessionId
            
            Write-Host "会话 ID: $($sessionId)" -ForegroundColor White
            Write-Host "已保存进度：$($restoredSession.Progress)%" -ForegroundColor Yellow
            Write-Host "当前阶段：$($restoredSession.Stage)" -ForegroundColor Yellow
            Write-Host "保存时间：$($restoredSession.Data.LastUpdated)" -ForegroundColor Gray
            Write-Host "已挂起天数：$($restoredSession.AgeInDays) 天`n" -ForegroundColor Gray
            
            # GUI 模式：通知 GUI 显示 HUD 并等待用户选择
            # 使用 GUI_Mode 参数或 syncHash 变量来判断 GUI 环境
            if ($GUI_Mode -or (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
                # 通知 GUI 显示会话恢复 HUD
                $global:syncHash.ShowSessionRecoveryHUD = $true
                $global:syncHash.RestoredSessionId = $sessionId
                $global:syncHash.RestoredStage = $restoredSession.Stage
                $global:syncHash.RestoredProgress = $restoredSession.Progress
                $global:syncHash.RestoredLastUpdated = $restoredSession.LastUpdated
                $global:syncHash.RestoredAgeInDays = $restoredSession.AgeInDays
                
                Write-Host "⏳ 等待用户在 GUI 上做出选择..." -ForegroundColor Cyan
                
                # 等待 GUI 用户选择（SessionRestored 或 SessionRestarted）
                $waitTimeout = 30000  # 30 秒超时
                $waitStart = Get-Date
                while (-not $global:syncHash.SessionRestored -and -not $global:syncHash.SessionRestarted) {
                    Start-Sleep -Milliseconds 100
                    # 紧急避险：如果 GUI 关闭或超时，退出
                    if ($global:syncHash.IsHostAlive -eq $false) {
                        Write-Host "GUI 已关闭，退出..." -ForegroundColor Red
                        exit 1
                    }
                    if ((Get-Date) - $waitStart -gt [TimeSpan]::FromMilliseconds($waitTimeout)) {
                        Write-Host "⚠️ 等待用户选择超时，假设重新开始..." -ForegroundColor Yellow
                        $restoreMode = $false
                        break
                    }
                }
                
                # 检查用户选择
                if ($global:syncHash.SessionRestarted -eq $true) {
                    Write-Host "🔄 用户选择重新开始，清除会话..." -ForegroundColor Cyan
                    $restoreMode = $false
                    $sessionId = $null
                    Remove-SessionProgress -SessionId $restoredSession.SessionId
                } elseif ($global:syncHash.SessionRestored -eq $true) {
                    Write-Host "✅ 用户选择恢复会话，继续执行..." -ForegroundColor Green
                    $restoreMode = $true
                    
                    # 从恢复的会话数据中恢复关键变量
                    $restoredData = $restoredSession.Data
                    if ($restoredData) {
                        # 恢复 Scopes 数组（最重要，包含 StartTime、EndTime、LogType 等）
                        if ($restoredData.Scopes) {
                            # 处理 Scopes 可能是单个对象而不是数组的情况
                            $tempScopes = $restoredData.Scopes
                            if ($tempScopes -is [System.Management.Automation.PSCustomObject] -or $tempScopes -is [hashtable]) {
                                $scopes = @($tempScopes)
                            } else {
                                $scopes = $tempScopes
                            }
                            
                            # 确保 scopes 是数组
                            if (-not $scopes -or $scopes.Count -eq 0) {
                                $scopes = @($restoredData.Scopes)
                            }
                            
                            Write-Host "   ✅ 已恢复日志范围数据 ($($scopes.Count) 个范围)" -ForegroundColor Green
                            
                            # 处理特殊的日期格式 \/Date(...)\/
                            for ($i = 0; $i -lt $scopes.Count; $i++) {
                                $scopeItem = $scopes[$i]
                                
                                # 转换 StartTime
                                if ($scopeItem.StartTime -match '\\/Date\((\d+)\)\\/') {
                                    $timestamp = [long]$matches[1]
                                    $scopes[$i].StartTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                                }
                                
                                # 转换 EndTime
                                if ($scopeItem.EndTime -match '\\/Date\((\d+)\)\\/') {
                                    $timestamp = [long]$matches[1]
                                    $scopes[$i].EndTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                                }
                            }
                        }
                        
                        # 恢复单独的时间范围（备用，如果 Scopes 不存在）
                        if (-not $scopes) {
                            $restoreStartTime = $null
                            $restoreEndTime = $null
                            
                            # 尝试从单独字段恢复
                            if ($restoredData.StartTime -and $restoredData.EndTime) {
                                # 处理特殊日期格式
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
                                    ReportTitle = if ($restoredData.ReportTitle) { $restoredData.ReportTitle } else { "System 日志日报" }
                                })
                            }
                        }
                        
                        # 恢复 LogType
                        if ($restoredData.LogType) {
                            $LogType = $restoredData.LogType
                        }
                        
                        # 恢复 ExportMode
                        if ($restoredData.ExportMode) {
                            $ExportMode = $restoredData.ExportMode
                        }
                        
                        # 恢复 ExportScope
                        if ($restoredData.ExportScope) {
                            $ExportScope = $restoredData.ExportScope
                        }
                        
                        # 恢复性能分数和分块大小
                        if ($restoredData.PerformanceScore) {
                            $performanceScore = $restoredData.PerformanceScore
                        }
                        if ($restoredData.ChunkSize) {
                            $optimalChunkSize = $restoredData.ChunkSize
                        }
                        
                        # === 【断点续传修复】恢复导出选择相关变量 ===
                        if ($restoredData.ExportChoice) {
                            $exportChoice = $restoredData.ExportChoice
                            Write-Host "   ✅ 已恢复导出模式选择: $exportChoice" -ForegroundColor Green
                        }
                        if ($restoredData.ReportMode) {
                            $reportMode = $restoredData.ReportMode
                        }
                        
                        # 恢复高危事件数据（用于跳过扫描后仍然有数据）
                        if ($restoredData.HighRiskEventCount -and -not (Get-Variable -Name "highRiskEvents" -ErrorAction SilentlyContinue)) {
                            # 注意：highRiskEvents 可能无法完全恢复，但至少恢复统计数
                            $totalHigh = $restoredData.HighRiskEventCount
                            $critical = $restoredData.CriticalEvents
                            $errors = $restoredData.ErrorEvents
                            $warnings = $restoredData.WarningEvents
                            $totalEventCount = $restoredData.TotalEventCount
                        }
                        
                        # 恢复健康评估数据
                        if ($restoredData.HealthScore) {
                            $healthScore = $restoredData.HealthScore
                            $healthLevel = $restoredData.HealthLevel
                            $healthStatus = $restoredData.HealthStatus
                        }
                    }
                }
            } else {
                # 控制台模式：直接询问用户
                Write-Host "`n[会话恢复] 检测到未完成的会话" -ForegroundColor Cyan
                Write-Host "  1) 恢复会话（从上次保存点继续）" -ForegroundColor White
                Write-Host "  2) 重新开始（放弃之前的进度）" -ForegroundColor White
                $choice = Read-Host "请选择 (1 或 2)"
                
                if ($choice -ne "1") {
                    Write-Host "🔄 用户选择重新开始，清除会话..." -ForegroundColor Cyan
                    $restoreMode = $false
                    Remove-SessionProgress -SessionId $restoredSession.SessionId
                } else {
                    Write-Host "✅ 用户选择恢复会话，继续执行..." -ForegroundColor Green
                    $restoreMode = $true
                    
                    # 从恢复的会话数据中恢复关键变量（与 GUI 模式相同）
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
                        
                        # === 【断点续传修复】恢复导出选择相关变量 ===
                        if ($restoredData.ExportChoice) {
                            $exportChoice = $restoredData.ExportChoice
                            Write-Host "   ✅ 已恢复导出模式选择: $exportChoice" -ForegroundColor Green
                        }
                        if ($restoredData.ReportMode) {
                            $reportMode = $restoredData.ReportMode
                        }
                        
                        # 恢复高危事件数据
                        if ($restoredData.HighRiskEventCount -and -not (Get-Variable -Name "highRiskEvents" -ErrorAction SilentlyContinue)) {
                            $totalHigh = $restoredData.HighRiskEventCount
                            $critical = $restoredData.CriticalEvents
                            $errors = $restoredData.ErrorEvents
                            $warnings = $restoredData.WarningEvents
                            $totalEventCount = $restoredData.TotalEventCount
                        }
                        
                        # 恢复健康评估数据
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

# === 创建新会话（如果不是恢复模式）===
if (-not $restoreMode) {
    $sessionId = New-Session -SessionType "ExportTask" -Metadata @{
        LogType = $LogType
        ExportMode = $ExportMode
        ExportScope = $ExportScope
    }
    # 保存初始化进度
    Save-ProgressSafe -Checkpoint "Initialized" -AdditionalData @{
        LogType = $LogType
        ExportMode = $ExportMode
        ExportScope = $ExportScope
    }
}

# === 自适应交互拦截器函数 ===
function Get-AuroraInteraction {
    param (
        [string]$PromptMessage,
        [switch]$IsChoice
    )
    
    # 检测是否运行在 GUI 环境 (通过检查是否存在注入的 syncHash)
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        
        # ====== 新增：将早期交互无缝桥接到前端状态栏 ======
        $global:syncHash.CurrentActivity = "0/4 任务配置"
        $global:syncHash.CurrentStatus = $PromptMessage
        
        # ====== 视觉优化：使用λ引导符，移除聊天机器人感 ======
        $timestamp = [datetime]::Now.ToString('HH:mm:ss')
        $global:syncHash.LogOutput += "`n[$timestamp] > 请进行输入: $PromptMessage`n"
        
        # 清空之前的旧输入
        $global:syncHash.UserInput = $null 
        
        # 挂起当前后台线程，等待 GUI 填入数据
        while ($null -eq $global:syncHash.UserInput) {
            Start-Sleep -Milliseconds 100
            # 紧急避险：如果 GUI 意外关闭，强制自尽防止僵尸进程
            if ($global:syncHash.IsHostAlive -eq $false) { Stop-Process -Id $PID -Force }
        }
        
        # 获取数据并清空槽位
        $response = $global:syncHash.UserInput
        $global:syncHash.UserInput = $null 
        return $response
    }
    else {
        # 原生控制台模式：直接使用 Read-Host
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

# 设置控制套背景为黑色 (增加静默调用保护)
if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsOutputRedirected) {
    try {
        $Host.UI.RawUI.BackgroundColor = 'Black'
        Clear-Host
    } catch {}
}

# 检查PowerShell版本
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "❌ 本工具需要 PowerShell 5.0 或更高版本。" -ForegroundColor Red
    Write-Host "💡 建议：升级到 Windows 10 或安装 Windows Management Framework 5.1。" -ForegroundColor Yellow
    if (-not $Silent) {
        if ($null -eq (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
            Write-Host "`n按 Enter 键退出" -ForegroundColor Gray
            Read-Host | Out-Null
        }
    }
    exit 1
}

# 检查Windows版本
$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -lt 6) {
    Write-Host "❌ 本工具需要 Windows Vista 或更高版本。" -ForegroundColor Red
    Write-Host "💡 建议：升级到 Windows 10 或 Windows 11。" -ForegroundColor Yellow
    if (-not $Silent) {
        if ($null -eq (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
            Write-Host "`n按 Enter 键退出" -ForegroundColor Gray
            Read-Host | Out-Null
        }
    }
    exit 1
}

#region 居中 PowerShell 控制台窗口（仅 Windows）
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
        # 忽略错误（如在非控制台环境运行）
    }
}
#endregion

# === 全局设置 ===
# === 全局设置 (环境自适应加固) ===
try {
    if (-not [Console]::IsOutputRedirected) {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    }
} catch {}
$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'

#region 功能函数

# 通用StreamWriter处理函数
function New-StreamWriterOperation {
    <#
    .SYNOPSIS
        通用StreamWriter操作函数
    .DESCRIPTION
        提供统一的StreamWriter创建、使用和清理功能，确保文件写入操作的安全性和资源的正确释放
    .PARAMETER FilePath
        要写入的文件路径
    .PARAMETER ScriptBlock
        包含写入操作的脚本块，该脚本块将接收StreamWriter对象作为参数
    .RETURNS
        布尔值，表示操作是否成功完成
    .EXAMPLE
        # 示例：使用StreamWriter写入文本到文件
        $result = New-StreamWriterOperation -FilePath "C:\temp\output.txt" -ScriptBlock {
            param($writer)
            $writer.WriteLine("Hello, World!")
            $writer.WriteLine("This is a test.")
        }
        
        if ($result) {
            Write-Host "文件写入成功" -ForegroundColor Green
        } else {
            Write-Host "文件写入失败" -ForegroundColor Red
        }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock
    )
    
    # 重试机制配置
    $maxRetries = 5
    $retryCount = 0
    $retryDelay = 200  # 毫秒
    
    while ($retryCount -lt $maxRetries) {
        try {
            $retryCount++
            
            # 如果文件存在，先尝试删除（避免文件锁定）
            if (Test-Path $FilePath) {
                try {
                    [System.IO.File]::Delete($FilePath)
                } catch {
                    Write-Verbose "[StreamWriter] 无法删除旧文件，等待 $retryDelay ms... (尝试 $retryCount/$maxRetries)"
                    Start-Sleep -Milliseconds $retryDelay
                }
            }
            
            # 创建StreamWriter
            $streamWriter = New-Object System.IO.StreamWriter($FilePath, $false, [System.Text.Encoding]::UTF8, 65536)
            try {
                # 执行写入操作
                & $ScriptBlock $streamWriter
            } finally {
                # 确保关闭StreamWriter
                $streamWriter.Close()
            }
            
            Write-Verbose "[StreamWriter] 文件写入成功: $FilePath (尝试 $retryCount/$maxRetries)"
            return $true
            
        } catch {
            $errorMsg = $_.Exception.Message
            
            # 检查是否是文件锁定错误
            if ($errorMsg -match "can't open file for write|used by another process|being used by another process") {
                Write-Verbose "[StreamWriter] 文件被占用，等待 $retryDelay ms... (尝试 $retryCount/$maxRetries)"
                
                if ($retryCount -lt $maxRetries) {
                    Start-Sleep -Milliseconds ($retryDelay * $retryCount)
                    continue
                }
            }
            
            Write-Host "`n写入文件失败: $errorMsg" -ForegroundColor Red
            Write-Verbose "[StreamWriter] 错误详情: $($_.Exception.GetType().FullName)"
            return $false
        }
    }
    
    Write-Host "`n写入文件失败: 已达到最大重试次数 ($maxRetries 次)" -ForegroundColor Red
    return $false
}

# 通用文件路径处理函数
function Get-SafeFilePath {
    <#
    .SYNOPSIS
        生成安全的文件路径
    .DESCRIPTION
        清理文件名中的不安全字符并组合路径，同时将日志类型转换为中文名称以提高可读性
    .PARAMETER BasePath
        基础路径，文件将保存在此目录下
    .PARAMETER LogType
        日志类型，如 "System"、"Application" 等
    .PARAMETER DatePart
        日期部分，用于构建文件名
    .PARAMETER Extension
        文件扩展名，如 ".txt"、".csv" 等
    .RETURNS
        安全的文件路径，包含中文日志类型名称和清理后的文件名
    .EXAMPLE
        # 示例：生成系统日志的安全文件路径
        $basePath = "C:\Logs"
        $logType = "System"
        $datePart = "20260408"
        $extension = ".txt"
        
        $safePath = Get-SafeFilePath -BasePath $basePath -LogType $logType -DatePart $datePart -Extension $extension
        # 输出: C:\Logs\系统_日志_20260408.txt
    #>
    param(
        [string]$BasePath,
        [string]$LogType,
        [string]$DatePart,
        [string]$Extension
    )
    
    # 日志类型中文映射
    $logTypeMap = @{
        "System" = "系统"
        "Application" = "应用程序"
        "Security" = "安全"
        "Setup" = "安装"
        "DNS Server" = "DNS服务器"
        "DHCP Server" = "DHCP服务器"
        "Directory Service" = "活动目录"
        "IIS Admin Service" = "IIS服务器"
    }
    
    # 获取中文日志类型名称
    $chineseLogType = if ($logTypeMap.ContainsKey($LogType)) {
        $logTypeMap[$LogType]
    } else {
        $LogType
    }
    
    # 清理文件名中的不安全字符
    $safeLogType = $chineseLogType -replace '[^a-zA-Z0-9\u4e00-\u9fa5]', '_'
    $safeDatePart = $DatePart -replace '[^a-zA-Z0-9_]', '_'
    
    return [System.IO.Path]::Combine($BasePath, "${safeLogType}_日志_${safeDatePart}${Extension}")
}

function Get-ResourceOptimizedStrategy {
    <#
    .SYNOPSIS
        根据系统性能和资源状态获取优化策略
    .DESCRIPTION
        根据系统性能分数、内存使用、系统负载等因素，为不同任务类型（日志扫描或报告生成）提供优化策略，包括并行度、分块大小、压缩设置和缓存大小等参数
    .PARAMETER PerformanceScore
        系统性能分数 (0-100)，分数越高表示系统性能越好
    .PARAMETER TaskType
        任务类型：LogScanning（日志扫描）或 ReportGeneration（报告生成）
    .RETURNS
        包含优化策略的哈希表，包括性能等级、具体策略参数和系统资源信息
    .EXAMPLE
        # 示例：获取日志扫描任务的优化策略
        $performanceScore = 85
        $taskType = "LogScanning"
        
        $strategy = Get-ResourceOptimizedStrategy -PerformanceScore $performanceScore -TaskType $taskType
        Write-Host "性能等级: $($strategy.PerformanceLevel)"
        Write-Host "并行度: $($strategy.Strategy.Parallelism)"
        Write-Host "分块大小: $($strategy.Strategy.ChunkSize)"
        Write-Host "是否压缩: $($strategy.Strategy.Compression)"
        Write-Host "缓存大小: $($strategy.Strategy.CacheSize)"
    #>
    param(
        [ValidateRange(0, 100)]
        [int]$PerformanceScore,
        [ValidateSet("LogScanning", "ReportGeneration")]
        [string]$TaskType
    )
    
    try {
        # 验证参数
        if ($PerformanceScore -lt 0 -or $PerformanceScore -gt 100) {
            throw "PerformanceScore must be between 0 and 100"
        }
        
        if ([string]::IsNullOrWhiteSpace($TaskType)) {
            throw "TaskType cannot be empty"
        }
        
        if ($TaskType -ne "LogScanning" -and $TaskType -ne "ReportGeneration") {
            throw "TaskType must be either 'LogScanning' or 'ReportGeneration'"
        }
        
        # 资源状态评估
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
        
        # 任务类型定义
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
        
        # 性能等级判断 - 主要基于PerformanceScore，仅在资源严重受限情况下微调
        # 首先根据PerformanceScore确定基础等级
        $baseLevel = if ($PerformanceScore -ge 80) {
            "HighPerformance"
        } elseif ($PerformanceScore -ge 50) {
            "MediumPerformance"
        } else {
            "LowPerformance"
        }
        
        # 仅在资源约束极为严重时才降低等级
        $performanceLevel = $baseLevel
        if ($baseLevel -eq "HighPerformance" -and ($memoryUsage -ge 80 -or $systemLoad -ge 80)) {
            # 内存或CPU使用率极高 - 降级为Medium
            $performanceLevel = "MediumPerformance"
        } elseif ($baseLevel -eq "MediumPerformance" -and ($memoryUsage -ge 90 -or $systemLoad -ge 90)) {
            # 资源使用率极端高 - 降级为Low
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
        # 返回默认策略
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
        根据系统性能和数据大小获取智能缓存策略
    .DESCRIPTION
        根据系统性能分数和数据大小，智能决定是否压缩数据以及缓存配置，以平衡性能和内存使用
    .PARAMETER PerformanceScore
        系统性能分数 (0-100)，分数越高表示系统性能越好
    .PARAMETER DataSizeKB
        数据大小（KB），用于评估是否需要压缩
    .RETURNS
        包含缓存策略的哈希表，包括是否压缩、缓存大小和过期时间
    .EXAMPLE
        # 示例：获取智能缓存策略
        $performanceScore = 70
        $dataSizeKB = 25000  # 25MB
        
        $cacheStrategy = Get-IntelligentCacheStrategy -PerformanceScore $performanceScore -DataSizeKB $dataSizeKB
        Write-Host "是否压缩: $($cacheStrategy.Compression)"
        Write-Host "缓存大小: $($cacheStrategy.CacheSize)"
        Write-Host "过期时间: $($cacheStrategy.ExpiryMinutes) 分钟"
    #>
    param(
        [ValidateRange(0, 100)]
        [int]$PerformanceScore,
        [ValidateRange(0, [int]::MaxValue)]
        [int]$DataSizeKB
    )
    
    try {
        # 验证参数
        if ($PerformanceScore -lt 0 -or $PerformanceScore -gt 100) {
            throw "PerformanceScore must be between 0 and 100"
        }
        
        if ($DataSizeKB -lt 0) {
            throw "DataSizeKB must be non-negative"
        }
        
        # 高性能机器缓存策略
        if ($PerformanceScore -ge 80) {
            return @{
                "Compression" = $DataSizeKB -gt 50000  # 仅对大于50MB的数据压缩
                "CacheSize" = 100  # 更大的缓存容量
                "ExpiryMinutes" = 60  # 更长的缓存过期时间
            }
        }
        # 中等性能机器
        elseif ($PerformanceScore -ge 50) {
            return @{
                "Compression" = $DataSizeKB -gt 20000  # 仅对大于20MB的数据压缩
                "CacheSize" = 50
                "ExpiryMinutes" = 30
            }
        }
        # 低性能机器
        else {
            return @{
                "Compression" = $DataSizeKB -gt 5000  # 对大于5MB的数据压缩
                "CacheSize" = 20
                "ExpiryMinutes" = 15
            }
        }
    }
    catch {
        Write-Debug "Error in Get-IntelligentCacheStrategy: $($_.Exception.Message)"
        # 返回默认缓存策略
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
        根据系统性能优化文件操作
    .DESCRIPTION
        根据系统性能分数，返回优化的文件操作参数，包括缓冲区大小、是否使用并行I/O、写入批次大小和是否使用异步写入
    .PARAMETER PerformanceScore
        系统性能分数 (0-100)，分数越高表示系统性能越好
    .RETURNS
        包含文件操作优化参数的哈希表，包括缓冲区大小、是否使用并行I/O、写入批次大小和是否使用异步写入
    .EXAMPLE
        # 示例：获取文件操作优化参数
        $performanceScore = 80
        
        $fileOps = Optimize-FileOperations -PerformanceScore $performanceScore
        Write-Host "缓冲区大小: $($fileOps.BufferSize) 字节"
        Write-Host "是否使用并行I/O: $($fileOps.ParallelIO)"
        Write-Host "写入批次大小: $($fileOps.WriteBatchSize)"
        Write-Host "是否使用异步写入: $($fileOps.AsyncWrite)"
    #>
    param(
        [ValidateRange(0, 100)]
        [int]$PerformanceScore
    )
    
    try {
        # 验证参数
        if ($PerformanceScore -lt 0 -or $PerformanceScore -gt 100) {
            throw "PerformanceScore must be between 0 and 100"
        }
        
        # 高性能机器使用更激进的I/O策略
        if ($PerformanceScore -ge 80) {
            return @{
                "BufferSize" = 131072  # 128KB缓冲区
                "ParallelIO" = $true    # 并行I/O操作
                "WriteBatchSize" = 10000 # 更大的写入批次
                "AsyncWrite" = $true     # 异步写入
            }
        }
        # 中等性能机器
        elseif ($PerformanceScore -ge 50) {
            return @{
                "BufferSize" = 65536  # 64KB缓冲区
                "ParallelIO" = $false
                "WriteBatchSize" = 5000
                "AsyncWrite" = $false
            }
        }
        # 低性能机器
        else {
            return @{
                "BufferSize" = 32768  # 32KB缓冲区
                "ParallelIO" = $false
                "WriteBatchSize" = 1000
                "AsyncWrite" = $false
            }
        }
    }
    catch {
        Write-Debug "Error in Optimize-FileOperations: $($_.Exception.Message)"
        # 返回默认文件操作参数
        return @{
            "BufferSize" = 65536  # 64KB缓冲区
            "ParallelIO" = $false
            "WriteBatchSize" = 5000
            "AsyncWrite" = $false
        }
    }
}

function Get-DiskPerformance {
    <#
    .SYNOPSIS
        检测磁盘性能并返回详细信息
    .DESCRIPTION
        检测磁盘类型、读写速度、响应时间和健康状态，包括判断是否为SSD，并计算磁盘性能分数
    .RETURNS
        包含磁盘性能信息的哈希表，包括磁盘列表、总体性能数据和性能分数
    .EXAMPLE
        # 示例：获取磁盘性能信息
        $diskInfo = Get-DiskPerformance
        Write-Host "磁盘性能分数: $($diskInfo.Score)/50"
        
        foreach ($drive in $diskInfo.Drives) {
            Write-Host "磁盘: $($drive.Model)"
            Write-Host "  大小: $($drive.SizeGB) GB"
            Write-Host "  接口: $($drive.InterfaceType)"
            Write-Host "  是否SSD: $($drive.IsSSD)"
        }
        
        if ($diskInfo.TotalPerformance) {
            Write-Host "平均响应时间: $($diskInfo.TotalPerformance.AvgDiskSecPerTransfer) 秒"
            Write-Host "读取速度: $($diskInfo.TotalPerformance.DiskReadBytesPerSec) 字节/秒"
            Write-Host "写入速度: $($diskInfo.TotalPerformance.DiskWriteBytesPerSec) 字节/秒"
        }
    #>
    try {
        $diskInfo = @{}
        
        # 获取磁盘基本信息
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
                
                # 尝试检测是否为SSD
                try {
                    # 方法1：使用Get-PhysicalDisk cmdlet（如果可用）
                    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
                        $physicalDisk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq $disk.Index }
                        if ($physicalDisk -and $physicalDisk.MediaType -eq "SSD") {
                            $driveInfo.IsSSD = $true
                        }
                    }
                    
                    # 方法2：检查磁盘型号是否包含SSD关键词
                    if (-not $driveInfo.IsSSD -and $disk.Model) {
                        $ssdKeywords = @("SSD", "Solid State", "NVMe", "PCIe")
                        foreach ($keyword in $ssdKeywords) {
                            if ($disk.Model -like "*$keyword*") {
                                $driveInfo.IsSSD = $true
                                break
                            }
                        }
                    }
                    
                    # 方法3：通过响应时间判断（备用方法）
                    if (-not $driveInfo.IsSSD) {
                        $perfData = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk | Where-Object { $_.Name -like "*$($disk.DeviceID.Replace('\\.\\', ''))*" }
                        if ($perfData -and $perfData.AvgDiskSecPerTransfer -lt 0.005) {
                            $driveInfo.IsSSD = $true
                        }
                    }
                } catch {
                    # 忽略错误
                }
                
                $diskInfo.Drives += $driveInfo
            }
        }
        
        # 获取总体磁盘性能
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
        
        # 计算磁盘性能分数
        $diskScore = 40 # 基础分数
        
        # 根据磁盘类型调整分数
        if ($diskInfo.Drives) {
            $hasSSD = $diskInfo.Drives | Where-Object { $_.IsSSD } | Measure-Object | Select-Object -ExpandProperty Count
            if ($hasSSD -gt 0) {
                $diskScore += 10 # SSD加分
            }
        }
        
        # 根据响应时间调整分数
        if ($diskInfo.TotalPerformance -and $diskInfo.TotalPerformance.AvgDiskSecPerTransfer) {
            $responseTime = $diskInfo.TotalPerformance.AvgDiskSecPerTransfer
            if ($responseTime -lt 0.005) {
                $diskScore += 5 # 优秀响应时间
            } elseif ($responseTime -lt 0.01) {
                $diskScore += 2 # 良好响应时间
            } elseif ($responseTime -gt 0.05) {
                $diskScore -= 5 # 较差响应时间
            }
        }
        
        # 确保分数在合理范围内
        $diskScore = [math]::Max(20, [math]::Min(50, $diskScore))
        $diskInfo.Score = $diskScore
        
        return $diskInfo
    } catch {
        Write-Debug "Error in Get-DiskPerformance: $($_.Exception.Message)"
        # 返回默认磁盘信息
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
        检测系统性能并返回性能分数
    .DESCRIPTION
        通过检测CPU核心数、内存大小和磁盘速度来评估系统性能，生成一个0-100的性能分数
    .RETURNS
        性能分数 (0-100)，分数越高表示系统性能越好
    .EXAMPLE
        # 示例：获取系统性能分数
        $performanceScore = Get-SystemPerformanceScore
        Write-Host "系统性能分数: $performanceScore/100"
        
        if ($performanceScore -ge 80) {
            Write-Host "系统性能优秀" -ForegroundColor Green
        } elseif ($performanceScore -ge 60) {
            Write-Host "系统性能良好" -ForegroundColor Yellow
        } else {
            Write-Host "系统性能一般" -ForegroundColor Red
        }
    #>
    try {
        # 获取CPU信息
        $cpuInfos = Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, MaxClockSpeed
        
        # 处理多个处理器的情况
        if ($cpuInfos -is [array]) {
            # 使用第一个处理器的信息
            $cpuInfo = $cpuInfos[0]
            $cpuName = $cpuInfo.Name
            $cpuCores = $cpuInfos | Measure-Object -Property NumberOfCores -Sum | Select-Object -ExpandProperty Sum
            $baseCpuSpeed = $cpuInfo.MaxClockSpeed
        } else {
            # 单个处理器的情况
            $cpuInfo = $cpuInfos
            $cpuName = $cpuInfo.Name
            $cpuCores = $cpuInfo.NumberOfCores
            $baseCpuSpeed = $cpuInfo.MaxClockSpeed
        }
        
        # 获取实时CPU频率
        try {
            $cpuPerformance = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation | 
                Where-Object {$_.Name -eq "_Total"} | 
                Select-Object -ExpandProperty PercentProcessorPerformance
            
            # 计算实时CPU频率（基于基础频率的百分比）
            $currentCpuSpeed = [math]::Round($baseCpuSpeed * ($cpuPerformance / 100), 0)
        } catch {
            # 无法获取实时频率时使用基础频率
            $currentCpuSpeed = $baseCpuSpeed
        }
        
        # 获取内存信息
        $memoryInfo = Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory
        $totalMemoryGB = [math]::Round($memoryInfo.TotalPhysicalMemory / 1GB, 2)
        
        # 获取磁盘性能信息
        $diskInfo = Get-DiskPerformance
        $diskScore = $diskInfo.Score
        
        # 非静默模式下显示系统信息
        if (-not $Silent) {
            Write-Host "处理器：$cpuName $cpuCores 核心 @ $currentCpuSpeed MHz (基础: $baseCpuSpeed MHz)" -ForegroundColor Cyan
            Write-Host "内存容量：$totalMemoryGB GB" -ForegroundColor Cyan
            Write-Host "磁盘性能分数：$diskScore/50" -ForegroundColor Cyan
            if ($diskInfo.Drives) {
                $ssdCount = $diskInfo.Drives | Where-Object { $_.IsSSD } | Measure-Object | Select-Object -ExpandProperty Count
                $hddCount = $diskInfo.Drives.Count - $ssdCount
                Write-Host "磁盘配置：$ssdCount 个 SSD, $hddCount 个 HDD" -ForegroundColor Cyan
            }
            Write-Host "正在计算性能分数..." -ForegroundColor Yellow
        }
        
        # 计算性能分数
        $cpuScore = [math]::Min(30, $cpuCores * 5 + $currentCpuSpeed / 100)
        $memoryScore = [math]::Min(30, $totalMemoryGB * 2)
        
        $totalScore = [math]::Min(100, $cpuScore + $memoryScore + $diskScore)
        
        # 非静默模式下显示性能分数
        if (-not $Silent) {
            Write-Host "您的性能分数为：$([Math]::Round($totalScore, 1))/100" -ForegroundColor Green
        }
        
        return $totalScore
    }
    catch {
        # 出错时返回默认分数
        return 50
    }
}

# 获取最佳分块大小
function Get-OptimalChunkSize {
    <#
    .SYNOPSIS
        根据系统性能和日志量计算最佳分块大小
    .DESCRIPTION
        根据系统性能分数、预计日志量、内存使用情况、磁盘速度和系统负载计算最佳的时间分块大小，以优化日志处理性能
    .PARAMETER PerformanceScore
        系统性能分数 (0-100)，分数越高表示系统性能越好
    .PARAMETER LogType
        日志类型，如 "System"、"Application" 等
    .RETURNS
        最佳分块大小（小时），用于日志处理的时间分块
    .EXAMPLE
        # 示例：获取最佳分块大小
        $performanceScore = 75
        $logType = "System"
        
        $chunkSize = Get-OptimalChunkSize -PerformanceScore $performanceScore -LogType $logType
        Write-Host "最佳分块大小: $chunkSize 小时/块"
    #>
    param(
        [int]$PerformanceScore,
        [string]$LogType
    )
    
    try {
        # 参数验证
        if ($PerformanceScore -lt 0 -or $PerformanceScore -gt 100) {
            Write-Debug "性能分数超出范围，使用默认值 50"
            $PerformanceScore = 50
        }
        
        # 根据日志类型估计日志量
        $logVolumeFactor = switch ($LogType) {
            "Security" { 3.0 }  # 安全日志通常较大
            "DNS Server" { 2.5 }  # DNS服务器日志较大
            "DHCP Server" { 2.0 }  # DHCP服务器日志中等偏大
            "Application" { 1.5 }  # 应用日志中等
            "System" { 1.0 }  # 系统日志较小
            "Directory Service" { 1.8 }  # 活动目录日志中等偏大
            "IIS Admin Service" { 1.6 }  # IIS日志中等
            "Setup" { 0.5 }  # 安装日志通常较小
            "Forwarded Events" { 2.0 }  # 转发事件日志较大
            "Windows PowerShell" { 1.2 }  # PowerShell日志中等
            "Microsoft-Windows-TaskScheduler/Operational" { 1.0 }  # 任务计划程序日志
            default { 1.0 }
        }
        
        # 根据性能分数计算基础分块大小（更精细的区间）
        $baseChunkSize = if ($PerformanceScore -ge 90) {
            6  # 极高性能系统使用更大分块
        } elseif ($PerformanceScore -ge 80) {
            4  # 高性能系统使用较大分块
        } elseif ($PerformanceScore -ge 65) {
            3  # 中高性能系统使用中等偏大分块
        } elseif ($PerformanceScore -ge 50) {
            2  # 中等性能系统使用中等分块
        } elseif ($PerformanceScore -ge 30) {
            1.5  # 中低性能系统使用较小分块
        } else {
            1  # 低性能系统使用最小分块
        }
        
        # 根据日志量调整分块大小
        $adjustedChunkSize = [math]::Max(0.5, $baseChunkSize / $logVolumeFactor)
        
        # 获取系统状态
        $memoryUsage = Get-MemoryUsage
        $systemLoad = Get-SystemLoad
        
        # 根据内存使用情况调整分块大小
        if ($memoryUsage -gt 80) {
            # 内存使用高，使用更小的分块
            $adjustedChunkSize = [math]::Max(0.25, $adjustedChunkSize * 0.5)
        } elseif ($memoryUsage -gt 60) {
            # 内存使用中等，使用稍小的分块
            $adjustedChunkSize = [math]::Max(0.5, $adjustedChunkSize * 0.75)
        }
        
        # 根据系统负载调整分块大小
        if ($systemLoad -gt 80) {
            # 系统负载高，使用更小的分块
            $adjustedChunkSize = [math]::Max(0.25, $adjustedChunkSize * 0.6)
        } elseif ($systemLoad -gt 60) {
            # 系统负载中等，使用稍小的分块
            $adjustedChunkSize = [math]::Max(0.5, $adjustedChunkSize * 0.8)
        }
        
        # 尝试获取磁盘速度信息并调整分块大小
        try {
            $diskInfo = Get-DiskPerformance
            if ($diskInfo.TotalPerformance -and $diskInfo.TotalPerformance.AvgDiskSecPerTransfer -gt 0) {
                # 磁盘响应时间越短，分块可以越大
                $diskResponseTime = $diskInfo.TotalPerformance.AvgDiskSecPerTransfer
                if ($diskResponseTime -lt 0.005) {
                    # 高速磁盘，增大分块大小
                    $adjustedChunkSize = [math]::Min(12, $adjustedChunkSize * 1.5)
                } elseif ($diskResponseTime -gt 0.02) {
                    # 低速磁盘，减小分块大小
                    $adjustedChunkSize = [math]::Max(0.25, $adjustedChunkSize * 0.7)
                }
            }
            
            # 根据磁盘类型调整分块大小
            if ($diskInfo.Drives) {
                $hasSSD = $diskInfo.Drives | Where-Object { $_.IsSSD } | Measure-Object | Select-Object -ExpandProperty Count
                if ($hasSSD -gt 0) {
                    # SSD可以处理更大的分块
                    $adjustedChunkSize = [math]::Min(12, $adjustedChunkSize * 1.2)
                }
            }
        } catch {
            # 磁盘性能检测失败，使用默认值
            Write-Debug "磁盘性能检测失败：$($_.Exception.Message)"
        }
        
        # 计算最佳并行度（仅用于显示）
        $cpuInfos = Get-CimInstance Win32_Processor
        
        # 处理多个处理器的情况
        if ($cpuInfos -is [array]) {
            # 计算总核心数
            $cpuCores = $cpuInfos | Measure-Object -Property NumberOfCores -Sum | Select-Object -ExpandProperty Sum
            $logicalProcessors = $cpuInfos | Measure-Object -Property NumberOfLogicalProcessors -Sum | Select-Object -ExpandProperty Sum
        } else {
            # 单个处理器的情况
            $cpuCores = $cpuInfos.NumberOfCores
            $logicalProcessors = $cpuInfos.NumberOfLogicalProcessors
        }
        
        $optimalThreads = Get-OptimalParallelism -CpuCores $cpuCores -TaskType "IOIntensive"
        
        # 非静默模式下显示最佳分块大小和线程数
        if (-not $Silent) {
            Write-Host "使用最佳分块大小：$([Math]::Round($adjustedChunkSize, 2)) 小时/块" -ForegroundColor Green
            Write-Host "根据系统负载使用 $optimalThreads/$logicalProcessors 个线程" -ForegroundColor Green
            if ($memoryUsage -gt 60) {
                Write-Host "内存使用：$memoryUsage%，已调整分块大小以减少内存占用" -ForegroundColor Yellow
            }
            if ($systemLoad -gt 60) {
                Write-Host "系统负载：$systemLoad%，已调整分块大小以减少系统压力" -ForegroundColor Yellow
            }
        }
        
        return $adjustedChunkSize
    } catch {
        Write-Debug "计算最佳分块大小时出错：$($_.Exception.Message)"
        # 出错时返回默认值
        return 2.0
    }
}

# 缓存管理
$script:logCache = @{}
$script:cacheExpiryMinutes = 30  # 缓存过期时间（分钟）
$script:minCacheSize = 5  # 最小缓存项数

# 缓存匹配函数
function Test-CacheMatch {
    <#
    .SYNOPSIS
        检查缓存是否匹配当前查询条件
    .DESCRIPTION
        根据日志类型、时间范围和过滤条件检查是否存在匹配的缓存数据
    .PARAMETER LogType
        日志类型
    .PARAMETER StartTime
        开始时间
    .PARAMETER EndTime
        结束时间
    .PARAMETER EventId
        事件ID（可选）
    .PARAMETER ProviderName
        事件提供程序名称（可选）
    .PARAMETER Level
        事件级别（可选）
    .RETURNS
        包含匹配结果、缓存项和缓存键的哈希表
    .EXAMPLE
        # 示例：检查缓存是否匹配
        $matchResult = Test-CacheMatch -LogType "System" -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
        if ($matchResult.Match) {
            Write-Host "找到匹配的缓存数据"
        } else {
            Write-Host "没有找到匹配的缓存数据"
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
    
    # 生成当前查询的缓存键
    $cacheLogType = if ($LogType -eq "系统") { "System" } elseif ($LogType -eq "应用程序") { "Application" } else { $LogType }
    $cacheKey = Get-CacheKey -LogType "$cacheLogType-HighRisk" -StartTime $StartTime -EndTime $EndTime -EventId $EventId -ProviderName $ProviderName -Level $Level
    
    # 检查缓存是否存在
    if ($script:logCache.ContainsKey($cacheKey)) {
        $cachedItem = $script:logCache[$cacheKey]
        
        # 验证缓存是否过期
        if ((Get-Date) - $cachedItem.Time -lt [TimeSpan]::FromMinutes($script:cacheExpiryMinutes)) {
            # 验证缓存数据完整性
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

# 显示缓存信息函数
function Show-CacheInfo {
    <#
    .SYNOPSIS
        显示缓存信息
    .DESCRIPTION
        显示缓存项的详细信息，包括创建时间、数据数量、原始大小、压缩大小、压缩率和过期时间
    .PARAMETER CacheItem
        缓存项对象
    .EXAMPLE
        # 示例：显示缓存信息
        $cacheItem = $script:logCache[$cacheKey]
        Show-CacheInfo -CacheItem $cacheItem
    #>
    param([object]$CacheItem)
    
    Write-AuroraLog "`n【缓存信息】" -Color Cyan
    Write-AuroraLog "创建时间: $($CacheItem.Time.ToString('yyyy-MM-dd HH:mm:ss'))" -Color Green
    Write-AuroraLog "数据数量: $($CacheItem.Data.Count) 条事件" -Color Green
    if ($CacheItem.OriginalSize) {
        Write-AuroraLog "原始大小: $([Math]::Round($CacheItem.OriginalSize, 2)) MB" -Color Green
    }
    if ($CacheItem.CompressedSize) {
        Write-AuroraLog "压缩大小: $([Math]::Round($CacheItem.CompressedSize, 2)) MB" -Color Green
    }
    if ($CacheItem.CompressionRatio) {
        Write-AuroraLog "压缩率: $($CacheItem.CompressionRatio)%" -Color Green
    }
    Write-AuroraLog "缓存过期时间: $($CacheItem.Time.AddMinutes($script:cacheExpiryMinutes).ToString('yyyy-MM-dd HH:mm:ss'))" -Color Yellow
}

# 获取缓存使用选择函数
function Get-CacheUsageChoice {
    <#
    .SYNOPSIS
        获取用户是否使用缓存的选择
    .DESCRIPTION
        显示缓存信息并提示用户是否使用缓存数据，支持静默模式
    .PARAMETER CacheItem
        缓存项对象
    .RETURNS
        布尔值，表示是否使用缓存数据
    .EXAMPLE
        # 示例：获取缓存使用选择
        $cacheItem = $script:logCache[$cacheKey]
        $useCache = Get-CacheUsageChoice -CacheItem $cacheItem
        if ($useCache) {
            Write-AuroraLog "使用缓存数据" -Color Green
        } else {
            Write-AuroraLog "不使用缓存数据，重新获取" -Color Yellow
        }
    #>
    param([object]$CacheItem)
    
    # 检查是否在静默模式下运行
    if ($Silent) {
        # 静默模式：直接使用缓存
        return $true
    }
    
    Show-CacheInfo -CacheItem $CacheItem
    
    $maxRetries = 3
    $retryCount = 0
    
    while ($retryCount -lt $maxRetries) {
        $choice = Get-AuroraInteraction -PromptMessage "`n是否使用缓存数据？(Y/N) [默认: Y]"
        
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -like 'Y*') {
            return $true
        } elseif ($choice -like 'N*') {
            return $false
        } else {
            $retryCount++
            $remaining = $maxRetries - $retryCount
            if ($remaining -gt 0) {
                Write-AuroraLog "`n❌ 无效输入！请输入 Y 或 N（剩余尝试次数：$remaining）" -Color Red
            } else {
                Write-AuroraLog "`n❌ 输入错误次数过多，默认使用缓存。" -Color Red
                return $true
            }
        }
    }
}

# 缓存验证函数
function Test-CacheIntegrity {
    <#
    .SYNOPSIS
        验证缓存数据的完整性
    .DESCRIPTION
        验证缓存项的数据结构、类型、数量和数据项结构是否有效
    .PARAMETER CacheItem
        缓存项对象
    .RETURNS
        布尔值，表示缓存数据是否完整有效
    .EXAMPLE
        # 示例：验证缓存完整性
        $cacheItem = $script:logCache[$cacheKey]
        $isValid = Test-CacheIntegrity -CacheItem $cacheItem
        if ($isValid) {
            Write-Host "缓存数据完整有效"
        } else {
            Write-Host "缓存数据无效或已损坏"
        }
    #>
    param([object]$CacheItem)
    
    try {
        # 验证缓存数据结构
        if (-not $CacheItem -or -not $CacheItem.Data) {
            return $false
        }
        
        # 验证数据类型
        if ($CacheItem.Data -isnot [array] -and $CacheItem.Data -isnot [System.Collections.Generic.List[object]]) {
            return $false
        }
        
        # 验证数据数量
        if ($CacheItem.Data.Count -lt 1) {
            return $false
        }
        
        # 验证数据项结构
        $firstItem = $CacheItem.Data | Select-Object -First 1
        if (-not $firstItem -or -not $firstItem.PSObject.Properties["Id"] -or -not $firstItem.PSObject.Properties["TimeCreated"]) {
            return $false
        }
        
        return $true
    } catch {
        return $false
    }
}

# 根据系统内存动态调整最大缓存项数
$os = Get-CimInstance Win32_OperatingSystem
$totalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB / 1024, 2)

if ($totalMemoryGB -lt 8) {
    $script:maxCacheSize = 10  # 8GB内存以下
} elseif ($totalMemoryGB -lt 16) {
    $script:maxCacheSize = 20  # 8-16GB内存
} else {
    $script:maxCacheSize = 50  # 16GB内存以上
}

# 对象池管理
$script:objectPools = @{}
$script:objectPoolLock = New-Object System.Object

# 知识图谱相关全局变量
$script:knowledgeBase = $null
$script:knowledgeBaseLoaded = $false  # 强制重新加载知识库
$script:knowledgeBaseCache = @{}
$script:knowledgeBaseIndex = @{}
$script:knowledgeBaseLastLoaded = $null  # 清除上次加载时间
$script:knowledgeBaseExpiryMinutes = 30

# 全局RunspacePool管理
$script:runspacePool = $null
$script:runspacePoolCreated = $false

# 知识图谱加载函数
function Load-KnowledgeBase {
    <#
    .SYNOPSIS
        加载知识图谱文件
    .DESCRIPTION
        从JSON文件加载知识图谱数据并创建索引以加快查询速度
    .RETURNS
        布尔值，表示加载是否成功
    .EXAMPLE
        # 示例：加载知识图谱
        $loadSuccess = Load-KnowledgeBase
        if ($loadSuccess) {
            Write-Host "知识图谱加载成功" -ForegroundColor Green
        } else {
            Write-Host "知识图谱加载失败" -ForegroundColor Red
        }
    #>
    try {
        # 知识图谱文件路径（在 Data 目录）
        $kbPath = [System.IO.Path]::Combine($PSScriptRoot, "..\Data\AURORA-TechData.json")
        
        # 检查文件是否存在
        if (-not (Test-Path -Path $kbPath)) {
            Write-Host "❌ 知识图谱文件未找到: $kbPath" -ForegroundColor Red
            return $false
        }
        
        # 读取并解析JSON文件
        $jsonContent = Get-Content -Path $kbPath -Encoding UTF8 -ErrorAction Stop
        $script:knowledgeBase = $jsonContent | ConvertFrom-Json -ErrorAction Stop
        
        # 创建索引以加快查询速度
        New-KnowledgeBaseIndex
        
        $script:knowledgeBaseLoaded = $true
        $script:knowledgeBaseLastLoaded = Get-Date
        
        Write-Host "✅ 知识图谱加载成功，包含 $($script:knowledgeBase.categories.Count) 个分类" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ 加载知识图谱时出错: $($_.Exception.Message)" -ForegroundColor Red
        $script:knowledgeBaseLoaded = $false
        return $false
    }
}

function New-KnowledgeBaseIndex {
    <#
    .SYNOPSIS
        为知识图谱创建索引
    .DESCRIPTION
        基于事件ID、源和关键词创建索引以加快查询速度
    .EXAMPLE
        # 示例：创建知识图谱索引
        New-KnowledgeBaseIndex
        Write-Host "知识图谱索引创建完成" -ForegroundColor Green
    #>
    try {
        # 重置索引
        $script:knowledgeBaseIndex = @{
            EventId = @{}
            Source = @{}
            Keyword = @{}
        }
        
        # 遍历所有知识图谱项目
        foreach ($category in $script:knowledgeBase.categories) {
            foreach ($item in $category.items) {
                # 按事件ID索引 - 确保使用int类型
                foreach ($eventId in $item.event_ids) {
                    $eventIdInt = [int]$eventId
                    if (-not $script:knowledgeBaseIndex.EventId.ContainsKey($eventIdInt)) {
                        $script:knowledgeBaseIndex.EventId[$eventIdInt] = @()
                    }
                    $script:knowledgeBaseIndex.EventId[$eventIdInt] += $item
                }
                
                # 按源索引
                if ($item.source) {
                    $sourceKey = $item.source.ToLower()
                    if (-not $script:knowledgeBaseIndex.Source.ContainsKey($sourceKey)) {
                        $script:knowledgeBaseIndex.Source[$sourceKey] = @()
                    }
                    $script:knowledgeBaseIndex.Source[$sourceKey] += $item
                }
                
                # 按关键词索引
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
        
        Write-Host "✅ 知识图谱索引创建成功" -ForegroundColor Green
    } catch {
        Write-Host "❌ 创建知识图谱索引时出错: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-KnowledgeBaseSolution {
    <#
    .SYNOPSIS
        根据事件信息查询知识图谱解决方案
    .DESCRIPTION
        根据事件ID、源和消息内容查询知识图谱解决方案，支持加权匹配和优先级排序
    .PARAMETER Event
        事件对象
    .RETURNS
        匹配的知识图谱解决方案数组
    .EXAMPLE
        # 示例：查询知识图谱解决方案
        $event = Get-WinEvent -LogName System -MaxEvents 1
        $solutions = Get-KnowledgeBaseSolution -Event $event
        if ($solutions.Count -gt 0) {
            Write-Host "找到 $($solutions.Count) 个解决方案" -ForegroundColor Green
            foreach ($solution in $solutions) {
                Write-Host "解决方案: $($solution.name)" -ForegroundColor Cyan
                Write-Host "优先级: $($solution.priority)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "未找到解决方案" -ForegroundColor Red
        }
    #>
    param(
        [object]$Event
    )
    
    try {
        # 确保知识图谱已加载
        if (-not $script:knowledgeBaseLoaded) {
            $loadSuccess = Load-KnowledgeBase
            if (-not $loadSuccess) {
                return @()
            }
        }
        
        # 检查知识图谱是否过期
        if ($script:knowledgeBaseLastLoaded -and ((Get-Date) - $script:knowledgeBaseLastLoaded).TotalMinutes -gt $script:knowledgeBaseExpiryMinutes) {
            $loadSuccess = Load-KnowledgeBase
            if (-not $loadSuccess) {
                return @()
            }
        }
        
        # 🟢 核心防御：安全提取 Message，防止损坏的日志抛出异常导致整个匹配中断
        $msgText = ""
        try {
            if ($null -ne $Event.Message) { $msgText = $Event.Message }
        } catch { Write-Debug "无法读取事件消息" }

        # 生成缓存键 - 使用轻量级的 GetHashCode() 提高性能
        $rawKey = "$($Event.Id)-$($Event.ProviderName)-$msgText"
        $cacheKey = $rawKey.GetHashCode().ToString("X")
        
        # 尝试从缓存获取
        if ($script:knowledgeBaseCache.ContainsKey($cacheKey)) {
            $cachedData = $script:knowledgeBaseCache[$cacheKey].Data
            if ($cachedData) {
                return $cachedData
            } else {
                # 缓存中的数据为 $null，返回空数组
                return @()
            }
        }
        
        $solutionScores = @{}
        
        # 1. 按事件ID匹配（权重：100，精确匹配）- 处理类型不匹配
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
                # 尝试用字符串类型查找
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
        
        # 2. 按源匹配（权重：50，类别匹配）
        if ($Event.ProviderName) {
            $sourceKey = $Event.ProviderName.ToLower()
            
            # 首先尝试精确匹配
            if ($script:knowledgeBaseIndex.Source.ContainsKey($sourceKey)) {
                foreach ($item in $script:knowledgeBaseIndex.Source[$sourceKey]) {
                    $key = $item.rule_id
                    if (-not $solutionScores.ContainsKey($key)) {
                        $solutionScores[$key] = @{ Item = $item; Score = 0 }
                    }
                    $solutionScores[$key].Score += 50
                }
            } else {
                # 尝试去掉 "Microsoft-Windows-" 前缀后匹配
                $sourceKeyWithoutPrefix = $sourceKey -replace '^microsoft-windows-', ''
                if ($script:knowledgeBaseIndex.Source.ContainsKey($sourceKeyWithoutPrefix)) {
                    foreach ($item in $script:knowledgeBaseIndex.Source[$sourceKeyWithoutPrefix]) {
                        $key = $item.rule_id
                        if (-not $solutionScores.ContainsKey($key)) {
                            $solutionScores[$key] = @{ Item = $item; Score = 0 }
                        }
                        $solutionScores[$key].Score += 45  # 稍微降低权重，因为不是精确匹配
                    }
                } else {
                    # 尝试反向匹配：在知识库来源前加上 "Microsoft-Windows-" 前缀
                    foreach ($kbSource in $script:knowledgeBaseIndex.Source.Keys) {
                        $prefixedKbSource = "microsoft-windows-$kbSource"
                        if ($sourceKey -eq $prefixedKbSource) {
                            foreach ($item in $script:knowledgeBaseIndex.Source[$kbSource]) {
                                $key = $item.rule_id
                                if (-not $solutionScores.ContainsKey($key)) {
                                    $solutionScores[$key] = @{ Item = $item; Score = 0 }
                                }
                                $solutionScores[$key].Score += 45  # 稍微降低权重，因为不是精确匹配
                            }
                            break
                        }
                    }
                }
            }
        }
        
        # 3. 按关键词匹配（权重：10/每个匹配，模糊匹配）
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
        
        # 4. 构建最终结果：按匹配分数降序 + 优先级降序排序
        $matchingSolutions = $solutionScores.Values | 
                             Sort-Object -Property @{Expression={$_.Score}; Descending=$true}, 
                                                   @{Expression={$_.Item.priority}; Descending=$true} | 
                             ForEach-Object { $_.Item }
        
        # 确保返回空数组而不是 $null
        if (-not $matchingSolutions) {
            $matchingSolutions = @()
        }
        
        # 缓存结果 - 存储为包含Data和Time的结构
        $script:knowledgeBaseCache[$cacheKey] = @{
            Data = $matchingSolutions
            Time = Get-Date
        }
        
        # 限制缓存大小 - 按Time排序清理旧缓存
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
        Write-Debug "查询知识图谱时出错: $($_.Exception.Message)"
        return @()
    }
}

# 函数：获取本地化的知识图谱解决方案
function Get-LocalizedKnowledgeBaseSolution {
    <#
    .SYNOPSIS
        根据语言获取本地化的知识图谱解决方案
    .DESCRIPTION
        返回带有语言特定字段的知识图谱解决方案
    .PARAMETER Solution
        知识图谱解决方案对象
    .RETURNS
        本地化的知识图谱解决方案
    .EXAMPLE
        # 示例：获取本地化的知识图谱解决方案
        $event = Get-WinEvent -LogName System -MaxEvents 1
        $solutions = Get-KnowledgeBaseSolution -Event $event
        if ($solutions.Count -gt 0) {
            $localizedSolution = Get-LocalizedKnowledgeBaseSolution -Solution $solutions[0]
            Write-Host "本地化解决方案: $($localizedSolution.name)" -ForegroundColor Cyan
        }
    #>
    param(
        [object]$Solution
    )
    
    try {
        # 对于CHSPRO，使用中文字段
        $localizedSolution = @{
            rule_id = $Solution.rule_id
            name = $Solution.name
            event_ids = $Solution.event_ids
            source = $Solution.source
            message_keywords = $Solution.message_keywords
            severity = $Solution.severity
            description = $Solution.description
            causes = $Solution.causes
            solutions = $Solution.solutions
            commands = $Solution.commands
            recommended_action = $Solution.recommended_action
            priority = $Solution.priority
            applies_to = $Solution.applies_to
        }
        
        return $localizedSolution
    } catch {
        Write-Debug "本地化知识图谱解决方案时出错: $($_.Exception.Message)"
        return $Solution
    }
}

# 函数：获取本地化的知识图谱解决方案数组
function Get-LocalizedKnowledgeBaseSolutions {
    <#
    .SYNOPSIS
        根据语言获取本地化的知识图谱解决方案数组
    .DESCRIPTION
        返回带有语言特定字段的知识图谱解决方案数组
    .PARAMETER Solutions
        知识图谱解决方案对象数组
    .RETURNS
        本地化的知识图谱解决方案数组
    .EXAMPLE
        # 示例：获取本地化的知识图谱解决方案数组
        $event = Get-WinEvent -LogName System -MaxEvents 1
        $solutions = Get-KnowledgeBaseSolution -Event $event
        $localizedSolutions = Get-LocalizedKnowledgeBaseSolutions -Solutions $solutions
        Write-Host "找到 $($localizedSolutions.Count) 个本地化解决方案" -ForegroundColor Green
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
        Write-Debug "本地化知识图谱解决方案数组时出错: $($_.Exception.Message)"
        return $Solutions
    }
}

function Get-KnowledgeBasePriority {
    <#
    .SYNOPSIS
        从知识图谱获取事件优先级
    .DESCRIPTION
        根据事件ID和源从知识图谱获取优先级
    .PARAMETER Event
        事件对象
    .RETURNS
        优先级值 (0-100)，无匹配时返回默认值
    .EXAMPLE
        # 示例：获取事件优先级
        $event = Get-WinEvent -LogName System -MaxEvents 1
        $priority = Get-KnowledgeBasePriority -Event $event
        Write-Host "事件优先级: $priority" -ForegroundColor Yellow
    #>
    param(
        [object]$Event
    )
    
    try {
        $solutions = Get-KnowledgeBaseSolution -Event $Event
        if ($solutions.Count -gt 0) {
            # 返回最高优先级
            return ($solutions | Sort-Object priority -Descending | Select-Object -First 1).priority
        }
        
        # 默认优先级
        return 50
    } catch {
        Write-Debug "获取知识图谱优先级时出错: $($_.Exception.Message)"
        return 50
    }
}

function Get-BatchKnowledgeBaseSolutions {
    <#
    .SYNOPSIS
        批量查询知识图谱解决方案（单线程高速版本）
    .DESCRIPTION
        放弃导致对象序列化损坏的多线程架构，使用单线程直接调用 Get-KnowledgeBaseSolution，确保100%命中
    .PARAMETER Events
        事件对象数组
    .PARAMETER ThreadCount
        保留参数以兼容其他函数的调用（已废弃）
    .RETURNS
        包含事件及其对应解决方案的哈希表
    #>
    param(
        [array]$Events,
        [int]$ThreadCount = 4  # 保留参数以兼容其他函数的调用
    )
    
    try {
        $finalResult = @{}
        
        # 放弃导致序列化损坏的多线程，直接使用单线程哈希表极速匹配
        foreach ($event in $Events) {
            # 直接调用已经完美封装好的单线程查找函数
            $solutions = Get-KnowledgeBaseSolution -Event $event
            
            # 确保无论是否命中，都返回数组
            if ($solutions) {
                $finalResult[$event] = @($solutions)
            } else {
                $finalResult[$event] = @()
            }
        }
        
        return $finalResult
    } catch {
        Write-Debug "批量知识图谱查询时出错: $($_.Exception.Message)"
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
        批量并行获取事件优先级
    .DESCRIPTION
        使用并行处理批量获取多个事件的优先级，提高性能
    .PARAMETER Events
        事件对象数组
    .PARAMETER ThreadCount
        并行线程数
    .RETURNS
        包含事件及其对应优先级的哈希表
    .EXAMPLE
        # 示例：批量获取事件优先级
        $events = Get-WinEvent -LogName System -MaxEvents 10
        $prioritiesMap = Get-BatchKnowledgeBasePriorities -Events $events -ThreadCount 4
        foreach ($event in $events) {
            $priority = $prioritiesMap[$event]
            Write-Host "事件 ID $($event.Id) 优先级: $priority" -ForegroundColor Yellow
        }
    #>
    param(
        [array]$Events,
        [int]$ThreadCount = 4
    )
    
    try {
        # 批量获取解决方案
        $solutionsMap = Get-BatchKnowledgeBaseSolutions -Events $Events -ThreadCount $ThreadCount
        
        # 计算每个事件的优先级
        $priorities = @{}
        foreach ($event in $Events) {
            $solutions = $solutionsMap[$event]
            if ($solutions.Count -gt 0) {
                # 返回最高优先级
                $priorities[$event] = ($solutions | Sort-Object priority -Descending | Select-Object -First 1).priority
            } else {
                # 默认优先级
                $priorities[$event] = 50
            }
        }
        
        return $priorities
    } catch {
        Write-Debug "批量优先级获取时出错: $($_.Exception.Message)"
        # 返回默认优先级
        $priorities = @{}
        foreach ($event in $Events) {
            $priorities[$event] = 50
        }
        return $priorities
    }
}

# 缓存状态检查和初始化函数
function Initialize-Cache {
    <#
    .SYNOPSIS
        检查并初始化缓存状态
    .DESCRIPTION
        验证缓存结构是否正确，清理过期缓存项，根据内存使用情况动态调整缓存大小
    .PARAMETER Force
        开关参数，强制重新初始化缓存
    .RETURNS
        布尔值，表示初始化是否成功
    .EXAMPLE
        # 示例：初始化缓存
        $initSuccess = Initialize-Cache
        if ($initSuccess) {
            Write-Host "缓存初始化成功" -ForegroundColor Green
        } else {
            Write-Host "缓存初始化失败" -ForegroundColor Red
        }
    #>
    param(
        [switch]$Force
    )
    
    try {
        # 验证缓存结构
        if ($script:logCache -eq $null) {
            $script:logCache = @{}
        }
        
        # 清理过期缓存项
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
                # 无效缓存项
                $keysToRemove += $key
            }
        }
        
        # 移除过期或无效的缓存项
        foreach ($key in $keysToRemove) {
            $script:logCache.Remove($key)
        }
        
        # 动态调整缓存大小
        $optimalCacheSize = Get-OptimalCacheSize
        
        # 限制缓存大小
        if ($script:logCache.Count -gt $optimalCacheSize) {
            $oldestKeys = $script:logCache.GetEnumerator() | Sort-Object { $_.Value.Time } | Select-Object -First ($script:logCache.Count - $optimalCacheSize) -ExpandProperty Key
            foreach ($key in $oldestKeys) {
                $script:logCache.Remove($key)
            }
        }
        
        # 清理内存
        [System.GC]::Collect()
        
        return $true
    } catch {
        Write-Debug "Error initializing cache: $($_.Exception.Message)"
        # 缓存初始化失败，重置缓存
        $script:logCache = @{}
        return $false
    }
}

# 对象池管理函数
function New-ObjectPool {
    <#
    .SYNOPSIS
        创建新的对象池
    .DESCRIPTION
        创建一个新的对象池，用于管理可重用对象，提高性能和资源利用率
    .PARAMETER PoolName
        对象池名称
    .PARAMETER ObjectType
        对象类型
    .PARAMETER InitialSize
        初始池大小，默认为5
    .PARAMETER MaxSize
        最大池大小，默认为20
    .PARAMETER ObjectFactory
        对象创建工厂函数，用于创建新对象
    .EXAMPLE
        # 示例：创建对象池
        $objectFactory = { New-Object System.Text.StringBuilder }
        New-ObjectPool -PoolName "StringBuilderPool" -ObjectType "StringBuilder" -InitialSize 5 -MaxSize 20 -ObjectFactory $objectFactory
        Write-Host "对象池创建成功" -ForegroundColor Green
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
            # 验证参数
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
            
            # 初始化对象池
            $pool = @{
                Name = $PoolName
                Type = $ObjectType
                MaxSize = $MaxSize
                Objects = New-Object System.Collections.Generic.Queue[object]
                Factory = $ObjectFactory
                Lock = New-Object System.Object
            }
            
            # 预创建初始对象
            for ($i = 0; $i -lt $InitialSize; $i++) {
                try {
                    $object = & $ObjectFactory
                    if ($object) {
                        $pool.Objects.Enqueue($object)
                    }
                } catch {
                    $errorMessage = "创建对象池 $PoolName 时失败: $($_.Exception.Message)"
                    Write-Debug $errorMessage
                }
            }
            
            # 存储对象池
            $script:objectPools[$PoolName] = $pool
            Write-Debug "Created object pool $PoolName with $($pool.Objects.Count) initial objects"
            return $pool
        }
    } catch {
        $errorMessage = "创建对象池时出错: $($_.Exception.Message)"
        Write-Error $errorMessage
        return $null
    }
}

function Get-ObjectFromPool {
    <#
    .SYNOPSIS
        从对象池获取对象
    .DESCRIPTION
        从对象池获取一个可用对象，如果池为空则创建新对象
    .PARAMETER PoolName
        对象池名称
    .EXAMPLE
        # 示例：从对象池获取对象
        $stringBuilder = Get-ObjectFromPool -PoolName "StringBuilderPool"
        $stringBuilder.Append("Hello, ")
        $stringBuilder.Append("World!")
        Write-Host $stringBuilder.ToString()
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
                    # 池为空，创建新对象
                    $object = & $pool.Factory
                    if ($object) {
                        Write-Debug "Created new object for pool $PoolName"
                    }
                    return $object
                }
            }
        }
    } catch {
        $errorMessage = "从对象池获取对象时出错: $($_.Exception.Message)"
        Write-Debug $errorMessage
        return $null
    }
}

function Return-ObjectToPool {
    <#
    .SYNOPSIS
        将对象返回对象池
    .DESCRIPTION
        将使用完毕的对象返回对象池，以便重用，提高资源利用率
    .PARAMETER PoolName
        对象池名称
    .PARAMETER Object
        要返回的对象
    .EXAMPLE
        # 示例：将对象返回对象池
        $stringBuilder = Get-ObjectFromPool -PoolName "StringBuilderPool"
        try {
            $stringBuilder.Append("Hello, World!")
            Write-Host $stringBuilder.ToString()
        } finally {
            Return-ObjectToPool -PoolName "StringBuilderPool" -Object $stringBuilder
        }
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
        $errorMessage = "Error returning object to pool: $($_.Exception.Message)"
        Write-Debug $errorMessage
    }
}

function Clear-ObjectPool {
    <#
    .SYNOPSIS
        清理对象池
    .DESCRIPTION
        清空指定对象池中的所有对象，释放资源
    .PARAMETER PoolName
        对象池名称
    .EXAMPLE
        # 示例：清理对象池
        Clear-ObjectPool -PoolName "StringBuilderPool"
        Write-Host "对象池已清理" -ForegroundColor Green
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
        $errorMessage = "清理对象池时出错: $($_.Exception.Message)"
        Write-Debug $errorMessage
    }
}

function Get-ObjectPoolStatus {
    <#
    .SYNOPSIS
        获取对象池状态
    .DESCRIPTION
        获取指定对象池的当前状态，包括名称、类型、当前大小和最大大小
    .PARAMETER PoolName
        对象池名称
    .EXAMPLE
        # 示例：获取对象池状态
        $status = Get-ObjectPoolStatus -PoolName "StringBuilderPool"
        if ($status) {
            Write-Host "对象池名称: $($status.Name)"
            Write-Host "对象类型: $($status.Type)"
            Write-Host "当前大小: $($status.CurrentSize)"
            Write-Host "最大大小: $($status.MaxSize)"
        } else {
            Write-Host "对象池不存在" -ForegroundColor Red
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
        $errorMessage = "获取对象池状态时出错: $($_.Exception.Message)"
        Write-Debug $errorMessage
        return $null
    }
}

# 获取当前系统内存使用情况
function Get-MemoryUsage {
    <#
    .SYNOPSIS
        获取当前系统内存使用情况
    .DESCRIPTION
        返回当前内存使用百分比和详细内存信息
    .PARAMETER Detailed
        开关参数，返回详细内存信息
    .RETURNS
        内存使用百分比 (0-100) 或包含详细信息的哈希表
    .EXAMPLE
        # 示例：获取内存使用情况
        $memoryUsage = Get-MemoryUsage
        Write-Host "内存使用: $memoryUsage%" -ForegroundColor Yellow
        
        # 示例：获取详细内存信息
        $detailedMemory = Get-MemoryUsage -Detailed
        Write-Host "总内存: $($detailedMemory.TotalMemoryMB) MB"
        Write-Host "可用内存: $($detailedMemory.FreeMemoryMB) MB"
        Write-Host "已用内存: $($detailedMemory.UsedMemoryMB) MB"
        Write-Host "内存使用: $($detailedMemory.MemoryUsagePercent)%"
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
        根据内存使用情况计算最佳缓存大小
    .DESCRIPTION
        根据当前内存使用情况调整缓存大小，内存使用越低，缓存大小越大
    .RETURNS
        最佳缓存大小（项数）
    .EXAMPLE
        # 示例：获取最佳缓存大小
        $optimalSize = Get-OptimalCacheSize
        Write-Host "最佳缓存大小: $optimalSize 项" -ForegroundColor Green
    #>
    $memoryUsage = Get-MemoryUsage
    
    if ($memoryUsage -lt 50) {
        # 内存使用低，使用较大缓存
        return $script:maxCacheSize
    } elseif ($memoryUsage -lt 70) {
        # 内存使用中等，使用中等缓存
        return [Math]::Round(($script:maxCacheSize + $script:minCacheSize) / 2)
    } else {
        # 内存使用高，使用较小缓存
        return $script:minCacheSize
    }
}

function Get-SystemLoad {
    <#
    .SYNOPSIS
        获取当前系统负载
    .DESCRIPTION
        根据CPU使用率返回当前系统负载百分比
    .RETURNS
        系统负载百分比 (0-100)
    .EXAMPLE
        # 示例：获取系统负载
        $systemLoad = Get-SystemLoad
        Write-Host "系统负载: $systemLoad%" -ForegroundColor Yellow
    #>
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty LoadPercentage
        return $cpu
    } catch {
        # 出错时返回默认值
        return 50
    }
}

function Get-OptimalParallelism {
    <#
    .SYNOPSIS
        根据系统负载和CPU核心数计算最佳并行度
    .DESCRIPTION
        根据当前系统负载、CPU物理核心数、逻辑核心数（超线程）、内存使用和磁盘性能调整并行度，以获得最佳性能
    .PARAMETER CpuCores
        CPU物理核心数
    .PARAMETER TaskType
        任务类型：IOIntensive（IO密集型）或 CPUIntensive（CPU密集型）
    .RETURNS
        最佳并行度（线程数）
    .EXAMPLE
        # 示例：获取IO密集型任务的最佳并行度
        $cpuCores = (Get-CimInstance Win32_Processor).NumberOfCores
        $optimalThreads = Get-OptimalParallelism -CpuCores $cpuCores -TaskType "IOIntensive"
        Write-Host "最佳并行度: $optimalThreads 线程" -ForegroundColor Green
    #>
    param(
        [ValidateRange(1, [int]::MaxValue)]
        [int]$CpuCores,
        
        [ValidateSet("IOIntensive", "CPUIntensive")]
        [string]$TaskType = "IOIntensive"
    )
    
    try {
        # 验证参数
        if ($CpuCores -lt 1) {
            throw "CpuCores must be at least 1"
        }
        
        # 获取CPU信息，包括逻辑核心数（超线程）
        $cpuInfos = Get-CimInstance Win32_Processor
        
        # 处理多个处理器的情况
        if ($cpuInfos -is [array]) {
            # 计算总逻辑核心数
            $logicalProcessors = $cpuInfos | Measure-Object -Property NumberOfLogicalProcessors -Sum | Select-Object -ExpandProperty Sum
        } else {
            # 单个处理器的情况
            $logicalProcessors = $cpuInfos.NumberOfLogicalProcessors
        }
        
        $hasHyperThreading = $logicalProcessors -gt $CpuCores
        
        $systemLoad = Get-SystemLoad
        $memoryUsage = Get-MemoryUsage
        
        # 获取内存信息
        $memoryInfo = Get-CimInstance Win32_ComputerSystem
        $totalMemoryGB = [math]::Round($memoryInfo.TotalPhysicalMemory / 1GB, 2)
        
        # 获取磁盘性能信息
        $diskInfo = Get-DiskPerformance
        
        # 根据任务类型、是否支持超线程计算最大线程数
        $baseMaxThreads = if ($TaskType -eq "IOIntensive") {
            # IO密集型任务，可以利用更多线程
            if ($hasHyperThreading) {
                # 超线程情况下，使用逻辑核心数的80%以获得最佳性能
                $calculatedThreads = [Math]::Round($logicalProcessors * 0.8)
                # 根据内存大小调整最大线程数
                $maxThreadsBasedOnMemory = [Math]::Max(4, [Math]::Min(64, [Math]::Round($totalMemoryGB / 2)))
                [Math]::Min($calculatedThreads, $maxThreadsBasedOnMemory)
            } else {
                # 无超线程情况下，使用物理核心数的120%
                $calculatedThreads = [Math]::Round($CpuCores * 1.2)
                # 根据内存大小调整最大线程数
                $maxThreadsBasedOnMemory = [Math]::Max(2, [Math]::Min(32, [Math]::Round($totalMemoryGB / 4)))
                [Math]::Min($calculatedThreads, $maxThreadsBasedOnMemory)
            }
        } else {
            # CPU密集型任务，应限制线程数
            if ($hasHyperThreading) {
                # 超线程情况下，使用逻辑核心数的60%
                $calculatedThreads = [Math]::Round($logicalProcessors * 0.6)
                # 根据内存大小调整最大线程数
                $maxThreadsBasedOnMemory = [Math]::Max(2, [Math]::Min(32, [Math]::Round($totalMemoryGB / 4)))
                [Math]::Min($calculatedThreads, $maxThreadsBasedOnMemory)
            } else {
                # 无超线程情况下，使用物理核心数
                $calculatedThreads = $CpuCores
                # 根据内存大小调整最大线程数
                $maxThreadsBasedOnMemory = [Math]::Max(2, [Math]::Min(32, [Math]::Round($totalMemoryGB / 4)))
                [Math]::Min($calculatedThreads, $maxThreadsBasedOnMemory)
            }
        }
        
        $maxThreads = $baseMaxThreads
        
        # 根据系统负载调整
        if ($systemLoad -lt 30) {
            # 系统负载低，使用最大并行度
            $adjustedThreads = $maxThreads
        } elseif ($systemLoad -lt 70) {
            # 系统负载中等，使用中等并行度
            $adjustedThreads = [Math]::Max(1, [Math]::Round($maxThreads * 0.75))
        } else {
            # 系统负载高，使用最小并行度
            $adjustedThreads = [Math]::Max(1, [Math]::Round($maxThreads * 0.5))
        }
        
        # 根据内存使用调整
        if ($memoryUsage -gt 80) {
            $adjustedThreads = [Math]::Max(1, [Math]::Round($adjustedThreads * 0.7))
        } elseif ($memoryUsage -gt 60) {
            $adjustedThreads = [Math]::Max(1, [Math]::Round($adjustedThreads * 0.9))
        }
        
        # 根据磁盘性能调整
        if ($diskInfo.Score -gt 45) {
            # 磁盘性能好，可以增加线程数
            $adjustedThreads = [Math]::Min($maxThreads, [Math]::Round($adjustedThreads * 1.1))
        } elseif ($diskInfo.Score -lt 35) {
            # 磁盘性能差，减少线程数
            $adjustedThreads = [Math]::Max(1, [Math]::Round($adjustedThreads * 0.8))
        }
        
        return $adjustedThreads
    } catch {
        Write-Debug "Error in Get-OptimalParallelism: $($_.Exception.Message)"
        # 返回默认线程数
        return [Math]::Max(2, $CpuCores)
    }
}

function New-AdvancedLogPatternAnalysis {
    <#
    .SYNOPSIS
        执行高级日志模式分析
    .DESCRIPTION
        识别日志数据中的模式，包括重复事件、基于时间的模式、异常、事件关联分析、趋势预测
    .PARAMETER Events
        要分析的日志事件
    .RETURNS
        模式分析结果，包含模式、异常、时间模式、关联分析、趋势和提供程序分析
    .EXAMPLE
        # 示例：执行高级日志模式分析
        $events = Get-WinEvent -LogName System -MaxEvents 100
        $analysisResult = New-AdvancedLogPatternAnalysis -Events $events
        Write-Host "分析完成，找到 $($analysisResult.Summary.TotalEvents) 个事件"
        Write-Host "重复模式: $($analysisResult.Summary.RepetitivePatterns) 个"
        Write-Host "异常: $($analysisResult.Summary.Anomalies) 个"
        Write-Host "时间模式: $($analysisResult.Summary.TimePatterns) 个"
        Write-Host "关联分析: $($analysisResult.Summary.Correlations) 个"
    #>
    param(
        [object]$Events
    )
    
    # 增强输入验证
    try {
        if (!$Events) {
            return @{
                Patterns = @()
                Anomalies = @()
                TimePatterns = @()
                Correlations = @()
                Trends = @()
                ProviderAnalysis = @()
                Summary = "没有事件可分析"
            }
        }
        
        # 确保Events是可枚举对象
        if ($Events -isnot [System.Collections.IEnumerable] -or $Events.Count -eq 0) {
            return @{
                Patterns = @()
                Anomalies = @()
                TimePatterns = @()
                Correlations = @()
                Trends = @()
                ProviderAnalysis = @()
                Summary = "没有事件可分析"
            }
        }
        
        # 验证Events对象结构
        $firstEvent = $Events | Select-Object -First 1
        if (!$firstEvent -or !$firstEvent.PSObject.Properties["Id"] -or !$firstEvent.PSObject.Properties["TimeCreated"] -or !$firstEvent.PSObject.Properties["ProviderName"]) {
            return @{
                Patterns = @()
                Anomalies = @()
                TimePatterns = @()
                Correlations = @()
                Trends = @()
                ProviderAnalysis = @()
                Summary = "事件对象结构无效"
            }
        }
        
        Write-Host "`n【正在执行高级日志模式分析...】" -ForegroundColor Cyan
        
        # 1. 识别重复事件
        $repetitivePatterns = @()
        # 性能优化：对于大型事件集合使用哈希表
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
        
        # 2. 识别基于时间的模式
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
        
        # 3. 识别异常
        $anomalies = @()
        
        # 检查高严重性事件
        $criticalEvents = $Events | Where-Object { $_.Level -eq 1 }  # 严重事件
        foreach ($event in $criticalEvents) {
            $anomalies += @{
                EventId = $event.Id
                TimeCreated = $event.TimeCreated
                ProviderName = $event.ProviderName
                Message = $event.Message
                Severity = "严重"
                Type = "高严重性事件"
            }
        }
        
        # 检查异常事件频率
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
                                TimeSpan = "$($timeSpan.TotalMinutes.ToString('F2')) 分钟"
                                Type = "高频率事件"
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
                                TimeSpan = "$($timeSpan.TotalMinutes.ToString('F2')) 分钟"
                                Type = "高频率事件"
                            }
                        }
                    }
                }
            }
        }
        
        # 4. 事件关联分析（优化版）
        $correlations = @()
        try {
            # 按时间顺序排序事件
            $sortedEvents = $Events | Sort-Object TimeCreated
            
            # 优化的关联分析算法
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
                
                # 如果找到相关事件
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
            Write-Debug "事件关联分析失败: $($_.Exception.Message)"
            # 关联分析失败，继续执行其他分析
        }
        
        # 5. 趋势预测（增强版）
        $trends = @()
        try {
            # 按日期分组事件
            $eventsByDate = $Events | Group-Object { $_.TimeCreated.Date }
            
            # 计算每日事件数
            $dailyEventCounts = @()
            foreach ($group in $eventsByDate) {
                $dailyEventCounts += @{
                    Date = $group.Name
                    Count = $group.Count
                }
            }
            
            # 按日期排序
            $dailyEventCounts = $dailyEventCounts | Sort-Object Date
            
            # 增强的趋势预测
            if ($dailyEventCounts.Count -ge 3) {
                # 计算平均值
                $totalCount = $dailyEventCounts | Measure-Object -Property Count -Sum | Select-Object -ExpandProperty Sum
                $averageCount = $totalCount / $dailyEventCounts.Count
                
                # 计算趋势斜率
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
                
                # 计算斜率
                $slope = 0
                if ($n * $sumX2 - $sumX * $sumX -ne 0) {
                    $slope = ($n * $sumXY - $sumX * $sumY) / ($n * $sumX2 - $sumX * $sumX)
                }
                
                # 计算趋势方向
                if ($slope -gt 0.1) {
                    $trendDirection = "上升"
                } elseif ($slope -lt -0.1) {
                    $trendDirection = "下降"
                } else {
                    $trendDirection = "稳定"
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
            Write-Debug "趋势预测失败: $($_.Exception.Message)"
            # 趋势预测失败，继续执行其他分析
        }
        
        # 6. 扩展分析：按事件提供程序分析
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
            Write-Debug "提供程序分析失败: $($_.Exception.Message)"
        }
        
        # 7. 生成摘要
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
        
        # 返回分析结果
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
        Write-Debug "高级日志模式分析失败: $($_.Exception.Message)"
        # 分析失败，返回默认结果
        return @{
            Patterns = @()
            Anomalies = @()
            TimePatterns = @()
            Correlations = @()
            Trends = @()
            ProviderAnalysis = @()
            Summary = "分析失败: $($_.Exception.Message)"
        }
    }
}

function Get-CacheKey {
    <#
    .SYNOPSIS
        生成缓存键
    .DESCRIPTION
        根据日志类型、时间范围和过滤条件生成唯一的缓存键，用于缓存管理
    .PARAMETER LogType
        日志类型
    .PARAMETER StartTime
        开始时间
    .PARAMETER EndTime
        结束时间
    .PARAMETER EventId
        事件ID
    .PARAMETER ProviderName
        事件提供程序名称
    .PARAMETER Level
        事件级别
    .RETURNS
        唯一的缓存键
    .EXAMPLE
        # 示例：生成缓存键
        $cacheKey = Get-CacheKey -LogType "System" -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) -EventId "10016" -ProviderName "Microsoft-Windows-DistributedCOM" -Level "Error"
        Write-Host "缓存键: $cacheKey"
    #>
    param(
        [string]$LogType,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [string]$EventId = "",
        [string]$ProviderName = "",
        [string]$Level = ""
    )
    
    # 对参数进行编码，避免特殊字符冲突
    $encodedLogType = [uri]::EscapeDataString($LogType)
    $encodedEventId = [uri]::EscapeDataString($EventId)
    $encodedProviderName = [uri]::EscapeDataString($ProviderName)
    $encodedLevel = [uri]::EscapeDataString($Level)
    
    # 生成唯一键
    $key = "$encodedLogType|$($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))|$($EndTime.ToString('yyyy-MM-dd HH:mm:ss'))|$encodedEventId|$encodedProviderName|$encodedLevel"
    return $key
}

function Get-CachedLogData {
    <#
    .SYNOPSIS
        从缓存中获取日志数据
    .DESCRIPTION
        根据缓存键从缓存中获取日志数据，如果缓存过期则返回$null
    .PARAMETER CacheKey
        缓存键
    .PARAMETER Silent
        静默模式，不输出缓存相关的信息
    .RETURNS
        缓存的日志数据或$null
    .EXAMPLE
        # 示例：从缓存中获取日志数据
        $cacheKey = Get-CacheKey -LogType "System" -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
        $cachedData = Get-CachedLogData -CacheKey $cacheKey
        if ($cachedData) {
            Write-Host "从缓存中获取到 $($cachedData.Count) 条日志数据" -ForegroundColor Green
        } else {
            Write-Host "缓存中没有找到数据或缓存已过期" -ForegroundColor Yellow
        }
    #>
    param(
        [string]$CacheKey,
        [switch]$Silent = $false
    )
    
    if ($script:logCache.ContainsKey($CacheKey)) {
        $cachedItem = $script:logCache[$CacheKey]
        $cacheTime = $cachedItem.Time
        $compressedData = $cachedItem.Data
        
        # 检查缓存是否过期
        if ((Get-Date) - $cacheTime -lt [TimeSpan]::FromMinutes($script:cacheExpiryMinutes)) {
            if (-not $Silent) {
                Write-Host "从缓存中获取数据..." -ForegroundColor Cyan
            }
            
            # 解压缩数据
            try {
                $decompressedData = Expand-CompressedData -CompressedData $compressedData
                return $decompressedData
            } catch {
                # 解压缩失败，移除缓存项
                $script:logCache.Remove($CacheKey)
                return $null
            }
        } else {
            # 缓存过期，移除
            $script:logCache.Remove($CacheKey)
            return $null
        }
    }
    return $null
}

function Set-CachedLogData {
    <#
    .SYNOPSIS
        将日志数据存入缓存
    .DESCRIPTION
        将日志数据和时间戳存入缓存，并根据内存使用情况动态清理缓存，支持数据压缩
    .PARAMETER CacheKey
        缓存键
    .PARAMETER Data
        要缓存的日志数据
    .PARAMETER CacheStrategy
        缓存策略对象，包含压缩设置等
    .PARAMETER Silent
        静默模式，不输出缓存相关的信息
    .EXAMPLE
        # 示例：将日志数据存入缓存
        $cacheKey = Get-CacheKey -LogType "System" -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
        $events = Get-WinEvent -LogName System -MaxEvents 100
        $cacheStrategy = Get-IntelligentCacheStrategy -PerformanceScore 75 -DataSizeKB 10000
        Set-CachedLogData -CacheKey $cacheKey -Data $events -CacheStrategy $cacheStrategy
        Write-Host "日志数据已存入缓存" -ForegroundColor Green
    #>
    param(
        [string]$CacheKey,
        [object]$Data,
        [object]$CacheStrategy,
        [switch]$Silent = $false
    )
    
    # 清理内存
    if (-not $Silent) {
        Write-CustomProgress -Activity "处理缓存" -Status "正在清理内存..." -PercentComplete 10
    }
    [System.GC]::Collect()
    
    # 监控内存使用
    $memoryUsage = Get-MemoryUsage
    if (-not $Silent) {
        Write-CustomProgress -Activity "处理缓存" -Status "正在监控内存使用... $memoryUsage%" -PercentComplete 20
    }
    
    # 数据大小评估
    $dataCount = if ($Data -is [array] -or $Data -is [System.Collections.Generic.List[object]]) { $Data.Count } else { 1 }
    if (-not $Silent) {
        Write-CustomProgress -Activity "处理缓存" -Status "正在评估数据大小... $dataCount 条事件" -PercentComplete 30
    }
    
    # 使用智能缓存策略
    $shouldCompress = $cacheStrategy.Compression
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Fastest
    $dataSize = 0
    
    try {
        if (-not $Silent) {
            Write-CustomProgress -Activity "处理缓存" -Status "正在分析数据大小..." -PercentComplete 40
        }
        
        # 估算数据大小（避免耗时的JSON转换）
        $dataSize = if ($Data -is [array] -or $Data -is [System.Collections.Generic.List[object]]) {
            # 基于事件数量估算大小，每条事件平均约1KB
            $Data.Count * 1024
        } else {
            # 单个对象约1KB
            1024
        }
        
        # 只有当缓存策略允许压缩时，才考虑其他因素
        if ($cacheStrategy.Compression) {
            # 获取可用内存
            $os = Get-CimInstance Win32_OperatingSystem
            $totalMemory = $os.TotalVisibleMemorySize / 1MB
            $freeMemory = $os.FreePhysicalMemory / 1MB
            $availableMemory = $freeMemory
            
            # 激进的压缩决策逻辑
            # 只有当数据大小超过可用内存的20%时才进行压缩
            if ($dataSize -gt $availableMemory * 1024 * 1024 * 0.2) {
                $shouldCompress = $true
                # 对于需要压缩的数据，使用快速压缩模式
                $compressionLevel = [System.IO.Compression.CompressionLevel]::Fastest
            } else {
                $shouldCompress = false
            }
            
            # 根据内存使用调整处理策略
            if ($memoryUsage -gt 80) {
                Write-CustomProgress -Activity "处理缓存" -Status "内存使用较高，采用保守处理策略..." -PercentComplete 45
                # 对于内存使用高的情况，强制压缩
                $shouldCompress = $true
                $compressionLevel = [System.IO.Compression.CompressionLevel]::Fastest
            }
        } else {
            # 缓存策略不允许压缩，直接设置为false
            $shouldCompress = false
        }
    } catch {
        # 转换失败，默认不压缩
        $shouldCompress = $false
    }
    
    # 压缩数据
    if ($shouldCompress) {
        try {
            # 分块处理大数据并并行压缩
            $compressedData = $null
            if ($dataCount -gt 10000) {
                # 大数据分块处理
                $chunkSize = 5000
                $chunks = Split-Array -InputArray $Data -Size $chunkSize
                $totalChunks = $chunks.Count
                $compressedChunks = @()
                
                # 并行压缩实现
                $threadCount = [Math]::Max(1, [Math]::Min(8, $totalChunks))
                $runspacePool = Get-RunspacePool -ThreadCount $threadCount
                $jobs = @()
                
                foreach ($chunk in $chunks) {
                    $powershell = [PowerShell]::Create()
                    $powershell.RunspacePool = $runspacePool
                    $powershell.AddScript({ param($data, $level) 
                        . "$PSScriptRoot\AURORA-AnalyzerCHSPRO.ps1"
                        return Compress-Data -Data $data -CompressionLevel $level
                    }).AddArgument($chunk).AddArgument($compressionLevel)
                    
                    $job = $powershell.BeginInvoke()
                    $jobs += @{ PowerShell = $powershell; Job = $job }
                }
                
                # 收集并行压缩结果
                $currentChunk = 0
                while ($jobs.Count -gt 0) {
                    $completedJobs = $jobs | Where-Object { $_.Job.IsCompleted }
                    
                    foreach ($job in $completedJobs) {
                        try {
                            $compressedChunk = $job.PowerShell.EndInvoke($job.Job)
                            $compressedChunks += $compressedChunk
                        } catch {
                            # 压缩失败，使用原始数据
                            $compressedChunks += $chunk
                        } finally {
                            $job.PowerShell.Dispose()
                        }
                        
                        $currentChunk++
                        $percent = [Math]::Round(50 + ($currentChunk / $totalChunks) * 30)
                        if (-not $Silent) {
                            Write-CustomProgress -Activity "处理缓存" -Status "正在压缩数据块 $currentChunk/$totalChunks" -PercentComplete $percent -CurrentItem $currentChunk -TotalItems $totalChunks -CurrentTask "压缩数据块 $currentChunk"
                        }
                    }
                    
                    $jobs = $jobs | Where-Object { -not $_.Job.IsCompleted }
                    Start-Sleep -Milliseconds 100
                }
                
                # 关闭RunspacePool
                Close-RunspacePool -Silent $true
                
                # 合并压缩结果
                $compressedData = $compressedChunks
            } else {
                # 小数据直接处理
                if (-not $Silent) {
                    Write-CustomProgress -Activity "处理缓存" -Status "正在压缩数据..." -PercentComplete 70
                }
                $compressedData = Compress-Data -Data $Data -CompressionLevel $compressionLevel
            }
            
            # 计算数据大小的估计值
            if (-not $Silent) {
                Write-CustomProgress -Activity "处理缓存" -Status "正在计算压缩率..." -PercentComplete 80
            }
            $jsonData = $Data | ConvertTo-Json -Depth 10 -Compress -WarningAction SilentlyContinue
            $originalSize = $jsonData.Length / 1MB
            $compressedSize = $compressedData.Length / 1MB
            $compressionRatio = [Math]::Round(($originalSize - $compressedSize) / $originalSize * 100, 2)
            
            if (-not $Silent) {
                Write-CustomProgress -Activity "处理缓存" -Status "压缩完成，压缩率: $compressionRatio%" -PercentComplete 85
            }
        } catch {
            # 压缩失败，使用原始数据
            $compressedData = $Data
            # 计算数据大小的估计值
            try {
                $jsonData = $Data | ConvertTo-Json -Depth 10 -Compress -WarningAction SilentlyContinue
                $originalSize = $jsonData.Length / 1MB
            } catch {
                $originalSize = 0
            }
            $compressedSize = $originalSize
            $compressionRatio = 0
            
            if (-not $Silent) {
                Write-CustomProgress -Activity "处理缓存" -Status "压缩失败，使用原始数据" -PercentComplete 85
            }
        }
    } else {
        # 不压缩数据
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
            Write-CustomProgress -Activity "处理缓存" -Status "数据较小或内存充足，直接存储" -PercentComplete 85
        }
    }
    
    if (-not $Silent) {
        Write-CustomProgress -Activity "处理缓存" -Status "正在存储到缓存..." -PercentComplete 90
    }
    
    $script:logCache[$CacheKey] = @{
        Time = Get-Date
        Data = $compressedData
        OriginalSize = $originalSize
        CompressedSize = $compressedSize
        CompressionRatio = $compressionRatio
        LastAccessed = Get-Date
    }
    
    # 清理过期缓存（超过24小时）
    $expiryTime = (Get-Date).AddHours(-24)
    $expiredKeys = $script:logCache.GetEnumerator() | Where-Object { $_.Value.Time -lt $expiryTime } | Select-Object -ExpandProperty Key
    foreach ($key in $expiredKeys) {
        $script:logCache.Remove($key)
    }
    
    # 检查内存使用情况
    $memoryUsage = Get-MemoryUsage
    
    # 根据内存使用情况限制缓存大小
    $optimalCacheSize = Get-OptimalCacheSize
    if ($script:logCache.Count -gt $optimalCacheSize) {
        # 移除最旧的缓存项
        $oldestKey = $script:logCache.GetEnumerator() | Sort-Object { $_.Value.Time } | Select-Object -First 1 -ExpandProperty Key
        $script:logCache.Remove($oldestKey)
        if (-not $Silent) {
            Write-CustomProgress -Activity "处理缓存" -Status "已根据内存使用情况调整缓存大小为 $optimalCacheSize 项" -PercentComplete 95
        }
    }
    
    # 当内存使用超过80%时，强制清理一半的缓存
    if ($memoryUsage -gt 80) {
        $currentCount = $script:logCache.Count
        $targetCount = [Math]::Max(1, [Math]::Round($currentCount / 2))
        if ($currentCount -gt $targetCount) {
            $keysToRemove = $script:logCache.GetEnumerator() | Sort-Object { $_.Value.Time } | Select-Object -First ($currentCount - $targetCount) -ExpandProperty Key
            foreach ($key in $keysToRemove) {
                $script:logCache.Remove($key)
            }
            if (-not $Silent) {
                Write-CustomProgress -Activity "处理缓存" -Status "内存使用过高，已清理部分缓存，当前缓存项数：$targetCount" -PercentComplete 95
            }
        }
    }
    
    if (-not $Silent) {
        Write-CustomProgress -Activity "处理缓存" -Status "缓存处理完成！" -PercentComplete 100
        
        # 输出最终结果
        if ($compressionRatio -gt 0) {
            Write-Host "`n数据已压缩并存入缓存（压缩率：$compressionRatio%）..." -ForegroundColor Cyan
        } else {
            Write-Host "`n数据已存入缓存..." -ForegroundColor Cyan
        }
    }
}

function Compress-Data {
    <#
    .SYNOPSIS
        压缩数据
    .DESCRIPTION
        使用Gzip压缩数据，减少内存占用
    .PARAMETER Data
        要压缩的数据
    .PARAMETER CompressionLevel
        压缩级别（Optimal、Fastest、NoCompression）
    .RETURNS
        压缩后的数据（Base64编码的字符串）
    .EXAMPLE
        # 示例：压缩数据
        $data = @(1, 2, 3, 4, 5)
        $compressedData = Compress-Data -Data $data -CompressionLevel "Fastest"
        Write-Host "压缩后数据长度: $($compressedData.Length)" -ForegroundColor Green
    #>
    param(
        [object]$Data,
        [System.IO.Compression.CompressionLevel]$CompressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    )
    
    try {
        # 验证输入参数
        if ($null -eq $Data) {
            throw "输入数据不能为空"
        }
        
        # 将对象转换为JSON
        $jsonData = $Data | ConvertTo-Json -Depth 10 -Compress
        
        # 将JSON转换为字节数组
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonData)
        
        # 创建内存流
        $memoryStream = New-Object System.IO.MemoryStream
        try {
            # 创建Gzip流
            $gzipStream = New-Object System.IO.Compression.GzipStream($memoryStream, $CompressionLevel)
            try {
                # 写入数据
                $gzipStream.Write($bytes, 0, $bytes.Length)
            } finally {
                # 确保Gzip流关闭
                if ($gzipStream) {
                    $gzipStream.Close()
                }
            }
            
            # 获取压缩后的字节数组
            $compressedBytes = $memoryStream.ToArray()
        } finally {
            # 确保内存流关闭
            if ($memoryStream) {
                $memoryStream.Close()
            }
        }
        
        # 将字节数组转换为Base64字符串
        return [Convert]::ToBase64String($compressedBytes)
    } catch {
        throw "压缩数据时出错: $($_.Exception.Message)"
    }
}

function Expand-CompressedData {
    <#
    .SYNOPSIS
        解压缩数据
    .DESCRIPTION
        解压缩之前压缩的数据
    .PARAMETER CompressedData
        压缩的数据（Base64编码的字符串）
    .RETURNS
        解压缩后的数据
    .EXAMPLE
        # 示例：解压缩数据
        $data = @(1, 2, 3, 4, 5)
        $compressedData = Compress-Data -Data $data
        $expandedData = Expand-CompressedData -CompressedData $compressedData
        Write-Host "解压缩后数据: $($expandedData -join ', ')" -ForegroundColor Green
    #>
    param(
        [string]$CompressedData
    )
    
    try {
        # 验证输入参数
        if ([string]::IsNullOrEmpty($CompressedData)) {
            throw "输入数据不能为空"
        }
        
        # 验证Base64字符串
        try {
            [Convert]::FromBase64String($CompressedData) | Out-Null
        } catch {
            throw "输入数据不是有效的Base64字符串"
        }
        
        # 将Base64字符串转换为字节数组
        $compressedBytes = [Convert]::FromBase64String($CompressedData)
        
        # 创建内存流
        $memoryStream = New-Object System.IO.MemoryStream($compressedBytes)
        try {
            # 创建Gzip流
            $gzipStream = New-Object System.IO.Compression.GzipStream($memoryStream, [System.IO.Compression.CompressionMode]::Decompress)
            try {
                # 创建读取器
                $streamReader = New-Object System.IO.StreamReader($gzipStream)
                try {
                    # 读取解压缩后的数据
                    $jsonData = $streamReader.ReadToEnd()
                } finally {
                    # 确保读取器关闭
                    if ($streamReader) {
                        $streamReader.Close()
                    }
                }
            } finally {
                # 确保Gzip流关闭
                if ($gzipStream) {
                    $gzipStream.Close()
                }
            }
        } finally {
            # 确保内存流关闭
            if ($memoryStream) {
                $memoryStream.Close()
            }
        }
        
        # 将JSON转换回对象
        return $jsonData | ConvertFrom-Json
    } catch {
        throw "解压缩数据时出错: $($_.Exception.Message)"
    }
}

function Clear-LogCache {
    <#
    .SYNOPSIS
        清除所有缓存
    .DESCRIPTION
        清除所有日志缓存，释放内存
    .PARAMETER Silent
        是否静默执行，不显示输出信息
    .RETURNS
        布尔值，表示清除操作是否成功
    .EXAMPLE
        # 示例：清除日志缓存
        $clearSuccess = Clear-LogCache
        if ($clearSuccess) {
            Write-Host "日志缓存已清除" -ForegroundColor Green
        } else {
            Write-Host "日志缓存清除失败" -ForegroundColor Red
        }
    #>
    param(
        [switch]$Silent = $false
    )
    
    try {
        # 检查缓存是否存在
        if ($script:logCache) {
            $beforeCount = $script:logCache.Count
            $script:logCache.Clear()
            $afterCount = $script:logCache.Count
            
            if (-not $Silent) {
                Write-Host "缓存已清除，清除前 $beforeCount 项，清除后 $afterCount 项" -ForegroundColor Cyan
            }
            return $true
        } else {
            if (-not $Silent) {
                Write-Host "缓存不存在，无需清除" -ForegroundColor Yellow
            }
            return $false
        }
    } catch {
        if (-not $Silent) {
            Write-Host "清除缓存时出错: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $false
    }
}

function Split-Array {
    <#
    .SYNOPSIS
        将数组分割成指定大小的批次
    .DESCRIPTION
        将一个大数组分割成多个指定大小的小数组，用于并行处理
    .PARAMETER InputArray
        要分割的输入数组
    .PARAMETER Size
        每个批次的大小
    .RETURNS
        分割后的数组批次
    .EXAMPLE
        # 示例：分割数组
        $inputArray = 1..100
        $batches = Split-Array -InputArray $inputArray -Size 20
        Write-Host "数组已分割成 $($batches.Count) 个批次" -ForegroundColor Green
        foreach ($i in 0..($batches.Count-1)) {
            Write-Host "批次 $($i+1): $($batches[$i] -join ', ')" -ForegroundColor Cyan
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
        获取或创建全局RunspacePool
    .DESCRIPTION
        获取现有的RunspacePool，如果不存在则创建一个新的，用于并行处理任务
    .PARAMETER ThreadCount
        线程数
    .RETURNS
        RunspacePool对象
    .EXAMPLE
        # 示例：获取RunspacePool
        $runspacePool = Get-RunspacePool -ThreadCount 4
        Write-Host "RunspacePool创建成功，线程数: 4" -ForegroundColor Green
    #>
    param(
        [int]$ThreadCount
    )
    
    try {
        # 验证参数
        if ($ThreadCount -lt 1) {
            throw "线程数必须大于0"
        }
        
        # 检查RunspaceFactory类型是否可用
        if (-not ([System.Management.Automation.Runspaces.RunspaceFactory])) {
            throw "当前PowerShell版本不支持RunspacePool"
        }
        
        # 合理性检查：线程数不应超过处理器核心数的2倍
        $maxThreads = [System.Environment]::ProcessorCount * 2
        if ($ThreadCount -gt $maxThreads) {
            Write-Warning "线程数 $ThreadCount 超过推荐最大值 $maxThreads，可能会影响性能"
        }
        
        # 检查是否需要创建新的RunspacePool
        if (!$script:runspacePoolCreated -or $script:runspacePool -eq $null -or $script:runspacePool.IsDisposed) {
            # 创建新的RunspacePool
            $script:runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $ThreadCount)
            $script:runspacePool.Open()
            $script:runspacePoolCreated = $true
            Write-Debug "已创建新的RunspacePool，线程数: $ThreadCount"
        }
        
        return $script:runspacePool
    } catch {
        Write-Error "创建RunspacePool时出错: $($_.Exception.Message)"
        return $null
    }
}

# 基于TPL的并行处理函数
function Invoke-ParallelTask {
    <#
    .SYNOPSIS
        基于TPL实现的并行任务处理
    .DESCRIPTION
        使用Task Parallel Library (TPL) 并行处理任务，支持动态线程管理和任务优先级
    .PARAMETER Tasks
        要执行的任务列表，每个任务包含ScriptBlock和Parameters
    .PARAMETER ThreadCount
        线程数
    .PARAMETER TaskPriority
        任务优先级 (Low, Normal, High)
    .PARAMETER ProgressActivity
        进度活动名称
    .PARAMETER ThreadAdjustmentInterval
        线程调整间隔（毫秒）
    .PARAMETER Silent
        是否静默模式
    .PARAMETER DynamicThreadManagement
        是否启用动态线程管理
    .RETURNS
        任务执行结果
    .EXAMPLE
        # 示例：执行并行任务
        $tasks = @()
        for ($i = 1; $i -le 10; $i++) {
            $tasks += @{
                ScriptBlock = { param($number) Start-Sleep 1; return "Task $number completed" }
                Parameters = @($i)
            }
        }
        $results = Invoke-ParallelTask -Tasks $tasks -ThreadCount 4 -ProgressActivity "执行并行任务"
        Write-Host "并行任务执行完成，共完成 $($results.Count) 个任务" -ForegroundColor Green
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
        # 验证参数
        if (-not $Tasks -or $Tasks.Count -eq 0) {
            return @()
        }
        
        # 确保线程数合理
        $maxThreads = [System.Environment]::ProcessorCount * 2
        $initialThreadCount = [Math]::Min($ThreadCount, $maxThreads)
        $initialThreadCount = [Math]::Max(1, $initialThreadCount)
        $currentThreadCount = $initialThreadCount
        
        if (-not $Silent) {
            Write-Host "[TPL并行处理] 初始线程数: $currentThreadCount, 任务数: $($Tasks.Count)" -ForegroundColor Cyan
        }
        
        # 创建线程安全的结果集合
        Add-Type -AssemblyName System.Collections.Concurrent
        $results = New-Object System.Collections.Concurrent.ConcurrentBag[object]
        
        # 创建任务数组
        $taskObjects = @()
        $processedTasks = 0
        $totalTasks = $Tasks.Count
        $isProcessing = $true
        
        # 动态线程管理变量
        $lastThreadAdjustment = Get-Date
        $threadAdjustmentLock = New-Object System.Object
        
        # 配置并行选项
        $parallelOptions = New-Object System.Threading.Tasks.ParallelOptions
        $parallelOptions.MaxDegreeOfParallelism = $currentThreadCount
        
        # 执行并行任务
        foreach ($task in $Tasks) {
            try {
                # 执行任务
                $result = & $task.ScriptBlock @($task.Parameters)
                
                # 添加结果到线程安全集合
                if ($result) {
                    $results.Add($result)
                }
            }
            catch {
                # 忽略单个任务的错误
                Write-Debug "执行任务时出错: $($_.Exception.Message)"
            }
            finally {
                # 更新进度
                $completed = [System.Threading.Interlocked]::Increment([ref]$processedTasks)
                
                if (-not $Silent) {
                    $percent = [Math]::Min(100, [Math]::Round(($completed / $totalTasks) * 100))
                    Write-CustomProgress -Activity $ProgressActivity -Status "已完成 $completed/$totalTasks 个任务" -PercentComplete $percent -CurrentItem $completed -TotalItems $totalTasks
                }
            }
        }
        
        # 确保显示100%进度
        if (-not $Silent) {
            Write-CustomProgress -Activity $ProgressActivity -Status "已完成 $totalTasks/$totalTasks 个任务" -PercentComplete 100
        }
        
        # 转换结果为数组
        return @($results)
    }
    catch {
        Write-Error "并行任务执行时出错: $($_.Exception.Message)"
        return @()
    }
}

function Close-RunspacePool {
    <#
    .SYNOPSIS
        关闭全局RunspacePool
    .DESCRIPTION
        关闭并释放RunspacePool资源，释放系统资源
    .PARAMETER Silent
        是否静默执行，不显示输出信息
    .RETURNS
        布尔值，表示关闭操作是否成功
    .EXAMPLE
        # 示例：关闭RunspacePool
        $closeSuccess = Close-RunspacePool
        if ($closeSuccess) {
            Write-Host "RunspacePool已成功关闭" -ForegroundColor Green
        } else {
            Write-Host "RunspacePool关闭失败" -ForegroundColor Red
        }
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
                Write-Debug "RunspacePool已成功关闭并释放"
            }
            return $true
        } else {
            if (-not $Silent) {
                Write-Debug "RunspacePool不存在或已被释放，无需关闭"
            }
            return $false
        }
    } catch {
        if (-not $Silent) {
            Write-Error "关闭RunspacePool时出错: $($_.Exception.Message)"
        }
        return $false
    }
}

function New-LogTrendAnalysis {
    <#
    .SYNOPSIS
        分析日志趋势，生成趋势报告
    .DESCRIPTION
        分析历史日志数据，计算趋势指标，生成趋势报告，包括健康分数、趋势分析和预测
    .PARAMETER ExportPath
        输出目录
    .PARAMETER LogType
        日志类型，如 "System"、"Application" 等
    .PARAMETER Days
        分析的天数
    .PARAMETER StartDate
        开始日期
    .PARAMETER EndDate
        结束日期
    .PARAMETER PerformanceScore
        系统性能分数
    .PARAMETER OptimalChunkSize
        最佳分块大小
    .PARAMETER EventId
        事件ID
    .PARAMETER ProviderName
        事件提供程序名称
    .PARAMETER Level
        事件级别
    .EXAMPLE
        # 示例：分析日志趋势
        $exportPath = "C:\Logs"
        $logType = "System"
        $days = 7
        New-LogTrendAnalysis -ExportPath $exportPath -LogType $logType -Days $days
        Write-Host "日志趋势分析完成，报告已保存至 $exportPath" -ForegroundColor Green
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
    

    
    # 确保天数大于0
    if ($Days -le 0) {
        $Days = 7
    }
    
    $trendData = @()
    
    # 如果提供了开始和结束日期，使用它们
    if ($StartDate -and $EndDate) {
        $startDate = $StartDate
        $endDate = $EndDate
    } else {
        # 否则使用当前日期减去指定天数
        $endDate = Get-Date
        $startDate = $endDate.AddDays(-$Days + 1)
    }
    
    # 确保开始日期小于结束日期
    if ($startDate -gt $endDate) {
        $temp = $startDate
        $startDate = $endDate
        $endDate = $temp
    }
    
    # 动态计算分析间隔，确保分析粒度合理
    $totalDays = ($endDate - $startDate).Days + 1
    $intervalDays = [Math]::Max(1, [Math]::Min(7, [Math]::Floor($totalDays / 10)))
    $totalIntervals = [Math]::Ceiling($totalDays / $intervalDays)
    
    # 使用顺序处理分析时间段
    for ($i = 0; $i -lt $totalIntervals; $i++) {
        $intervalStartDate = $startDate.AddDays($i * $intervalDays)
        $intervalEndDate = $intervalStartDate.AddDays($intervalDays).AddTicks(-1)
        
        # 确保不超过结束日期
        if ($intervalEndDate -gt $endDate) {
            $intervalEndDate = $endDate
        }
        
        Write-CustomProgress -Activity "分析日志趋势" -Status "正在分析 $($intervalStartDate.ToString('yyyy-MM-dd')) 至 $($intervalEndDate.ToString('yyyy-MM-dd')) 的日志" -PercentComplete ([Math]::Round(($i / $totalIntervals) * 100)) -CurrentItem $i -TotalItems $totalIntervals -CurrentTask "分析时间段 $i"
        # 强制刷新输出缓冲区
        [System.Console]::Out.Flush()
        
        try {
            # 使用缓存的扫描数据而不是重新调用Get-HighRiskEvents
            # 转换日志类型为英文以确保缓存键一致性
            $cacheLogType = if ($LogType -eq "系统") { "System" } elseif ($LogType -eq "应用程序") { "Application" } else { $LogType }
            # 使用完整的日期范围作为缓存键，而不是时间段
            $cacheKey = Get-CacheKey -LogType "$cacheLogType-HighRisk" -StartTime $startDate -EndTime $endDate -EventId $EventId -ProviderName $ProviderName -Level $Level
            
            # 尝试从缓存获取数据
            $cachedData = Get-CachedLogData -CacheKey $cacheKey -Silent $true
            
            # 统计事件级别
            $criticalCount = 0
            $errorCount = 0
            $warningCount = 0
            if ($cachedData) {
                # 过滤当前时间段内的事件
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
                # 缓存不可用时直接调用Get-WinEvent，与ENGPRO版本保持一致
                $filterHashtable = @{ LogName = $LogType; StartTime = $intervalStartDate; EndTime = $intervalEndDate; Level = 1,2,3 }
                
                # 添加事件ID过滤（如果提供）
                if (![string]::IsNullOrWhiteSpace($EventId)) {
                    $eventIds = $EventId -split ',' | ForEach-Object { $_.Trim() }
                    if ($eventIds.Count -gt 0) {
                        $filterHashtable["Id"] = $eventIds
                    }
                }
                
                # 添加事件提供程序过滤（如果提供）
                if (![string]::IsNullOrWhiteSpace($ProviderName)) {
                    $filterHashtable["ProviderName"] = $ProviderName
                }
                
                # 获取所有匹配的高危事件
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
            
            # 计算健康分数（改进算法：考虑事件频率、系统性能和历史数据）
            # 基础问题分数计算
            $totalIssues = $criticalCount * 3 + $errorCount * 2 + $warningCount
            
            # 计算事件频率因子（基于每小时事件数）
            $hoursInInterval = ($intervalEndDate - $intervalStartDate).TotalHours
            $eventsPerHour = if ($hoursInInterval -gt 0) {
                ($criticalCount + $errorCount + $warningCount) / $hoursInInterval
            } else {
                0
            }
            
            # 频率因子：事件频率越高，健康分数降低越多
            $frequencyFactor = if ($eventsPerHour -gt 10) {
                1.5  # 高频率事件
            } elseif ($eventsPerHour -gt 5) {
                1.2  # 中等频率事件
            } else {
                1.0  # 低频率事件
            }
            
            # 根据系统性能调整健康分数
            $performanceFactor = if ($PerformanceScore -gt 0) {
                [Math]::Max(0.5, $PerformanceScore / 100)
            } else {
                1.0
            }
            
            # 计算基础健康分数
            $baseHealthScore = 100 - ($totalIssues * $performanceFactor * $frequencyFactor)
            
            # 添加系统资源使用因素
            $memoryUsage = Get-MemoryUsage
            $systemLoad = Get-SystemLoad
            $diskInfo = Get-DiskPerformance
            
            # 资源使用调整因子
            $resourceFactor = 1.0
            if ($memoryUsage -gt 80 -or $systemLoad -gt 80) {
                $resourceFactor = 1.1  # 资源使用高，降低健康分数
            } elseif ($memoryUsage -lt 40 -and $systemLoad -lt 40) {
                $resourceFactor = 0.9  # 资源使用低，提高健康分数
            }
            
            # 最终健康分数
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
            Write-Debug "分析 $($intervalStartDate.ToString('yyyy-MM-dd')) 至 $($intervalEndDate.ToString('yyyy-MM-dd')) 的日志时出错: $($_.Exception.Message)"
            # 添加空数据
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
    
    # 确保显示100%进度
    Write-CustomProgress -Activity "分析日志趋势" -Status "分析完成" -PercentComplete 100
    # 强制刷新输出缓冲区
    [System.Console]::Out.Flush()
    # 添加换行符，确保后续输出不会覆盖进度条
    Write-Host ""
    
    # 生成趋势报告
    $reportContent = @"
日志趋势分析报告
报告日期 : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
日志类型 : $LogType
分析范围 : $($startDate.ToString('yyyy-MM-dd')) 至 $($endDate.ToString('yyyy-MM-dd'))
分析天数 : $totalDays
分析间隔 : $intervalDays 天
==================================================

【每日事件统计】
"@
    
    foreach ($data in $trendData) {
        $reportContent += "`n时间段: $($data.Date.ToString('yyyy-MM-dd')) 至 $($data.EndDate.ToString('yyyy-MM-dd'))"
        $reportContent += "`n  严重: $($data.Critical) 条"
        $reportContent += "`n  错误: $($data.Error) 条"
        $reportContent += "`n  警告: $($data.Warning) 条"
        $reportContent += "`n  健康分数: $($data.HealthScore)/100"
        $reportContent += "`n"
    }
    
    # 计算趋势指标
    try {
        if ($trendData.Count -gt 0) {
            # 确保所有数据项都有正确的属性
            $validTrendData = $trendData | Where-Object { 
                $_ -ne $null -and 
                $_.HealthScore -ne $null -and 
                $_.TotalIssues -ne $null 
            }
            
            if ($validTrendData.Count -gt 0) {
                # 计算平均健康分数
                $totalHealthScore = 0
                foreach ($item in $validTrendData) {
                    $totalHealthScore += $item.HealthScore
                }
                $avgHealthScore = [Math]::Round($totalHealthScore / $validTrendData.Count, 2)
                
                # 计算最高和最低健康分数
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
                # 确保最低健康分数有值
                if ($minHealthScore -eq $null) {
                    $minHealthScore = 100
                }
                
                # 计算总问题数
                $totalIssues = 0
                foreach ($item in $validTrendData) {
                    $totalIssues += $item.TotalIssues
                }
                
                # 高级趋势分析：线性回归和统计分析
                $n = $validTrendData.Count
                if ($n -ge 2) {
                    $sumX = 0
                    $sumY = 0
                    $sumXY = 0
                    $sumX2 = 0
                    $sumY2 = 0
                    
                    for ($i = 0; $i -lt $n; $i++) {
                        $x = $i
                        $y = $validTrendData[$i].HealthScore
                        $sumX += $x
                        $sumY += $y
                        $sumXY += $x * $y
                        $sumX2 += $x * $x
                        $sumY2 += $y * $y
                    }
                    
                    # 计算斜率
                    $slope = 0
                    if ($n * $sumX2 - $sumX * $sumX -ne 0) {
                        $slope = ($n * $sumXY - $sumX * $sumY) / ($n * $sumX2 - $sumX * $sumX)
                    }
                    
                    # 计算相关系数（衡量趋势的强度）
                    $correlation = 0
                    if ($n * $sumX2 - $sumX * $sumX -ne 0 -and $n * $sumY2 - $sumY * $sumY -ne 0) {
                        $correlation = ($n * $sumXY - $sumX * $sumY) / [Math]::Sqrt(($n * $sumX2 - $sumX * $sumX) * ($n * $sumY2 - $sumY * $sumY))
                    }
                    
                    # 分析趋势
                    $trendStrength = [Math]::Abs($correlation)
                    if ($slope -gt 1) {
                        $healthTrend = if ($trendStrength -gt 0.7) { "显著上升趋势" } else { "轻微上升趋势" }
                    } elseif ($slope -gt 0) {
                        $healthTrend = "轻微上升趋势"
                    } elseif ($slope -lt -1) {
                        $healthTrend = if ($trendStrength -gt 0.7) { "显著下降趋势" } else { "轻微下降趋势" }
                    } elseif ($slope -lt 0) {
                        $healthTrend = "轻微下降趋势"
                    } else {
                        $healthTrend = "稳定趋势"
                    }
                    
                    # 预测未来趋势（简单线性预测）
                    $predictedHealthScore = $sumY / $n
                    if ($slope -ne 0) {
                        $predictedHealthScore = $validTrendData[-1].HealthScore + $slope * 2  # 预测未来2个时间段
                        $predictedHealthScore = [Math]::Max(0, [Math]::Min(100, $predictedHealthScore))
                    }
                } else {
                    # 简单趋势分析
                    $firstHealthScore = $validTrendData[0].HealthScore
                    $lastHealthScore = $validTrendData[-1].HealthScore
                    $healthTrend = if ($lastHealthScore -gt $firstHealthScore) {
                        "上升趋势"
                    } elseif ($lastHealthScore -lt $firstHealthScore) {
                        "下降趋势"
                    } else {
                        "稳定趋势"
                    }
                    $predictedHealthScore = $lastHealthScore
                }
            } else {
                # 当没有有效数据时的默认值
                $avgHealthScore = 100
                $maxHealthScore = 100
                $minHealthScore = 100
                $totalIssues = 0
                $healthTrend = "稳定趋势"
            }
        } else {
            # 当没有数据时的默认值
            $avgHealthScore = 100
            $maxHealthScore = 100
            $minHealthScore = 100
            $totalIssues = 0
            $healthTrend = "稳定趋势"
        }
    } catch {
        # 发生错误时使用默认值
        Write-Debug "计算趋势指标时出错: $($_.Exception.Message)"
        $avgHealthScore = 100
        $maxHealthScore = 100
        $minHealthScore = 100
        $totalIssues = 0
        $healthTrend = "稳定趋势"
    }
    
    $reportContent += "`n【趋势分析】"
    $reportContent += "`n平均健康分数: $avgHealthScore/100"
    $reportContent += "`n最高健康分数: $maxHealthScore/100"
    $reportContent += "`n最低健康分数: $minHealthScore/100"
    $reportContent += "`n总问题数: $totalIssues"
    $reportContent += "`n健康趋势: $healthTrend"
    if ($predictedHealthScore) {
        $reportContent += "`n预测健康分数: $([Math]::Round($predictedHealthScore, 2))/100"
    }
    
    # 生成健康建议
    if ($avgHealthScore -ge 80) {
        $reportContent += "`n`n【健康建议】系统状态良好，继续保持。"
        if ($healthTrend -like "*下降*" -and $predictedHealthScore -lt 80) {
            $reportContent += "`n虽然当前状态良好，但检测到下降趋势，建议关注系统变化。"
        }
    } elseif ($avgHealthScore -ge 60) {
        $reportContent += "`n`n【健康建议】系统状态一般，建议定期检查。"
        if ($healthTrend -like "*下降*" -and $predictedHealthScore -lt 60) {
            $reportContent += "`n检测到下降趋势，建议加强系统监控，及时处理潜在问题。"
        } elseif ($healthTrend -like "*上升*") {
            $reportContent += "`n检测到上升趋势，继续保持当前的维护策略。"
        }
    } else {
        $reportContent += "`n`n【健康建议】系统状态较差，建议立即检查。"
        if ($healthTrend -like "*下降*" -and $predictedHealthScore -lt 50) {
            $reportContent += "`n检测到严重下降趋势，建议立即进行系统诊断和维护。"
        }
    }
    
    # 保存趋势报告
    try {
        # 日志类型中文映射
        $logTypeMap = @{
            "System" = "系统"
            "Application" = "应用程序"
            "Security" = "安全"
            "Setup" = "安装"
            "DNS Server" = "DNS服务器"
            "DHCP Server" = "DHCP服务器"
            "Directory Service" = "活动目录"
            "IIS Admin Service" = "IIS服务器"
        }
        
        # 获取中文日志类型名称
        $chineseLogType = if ($logTypeMap.ContainsKey($LogType)) {
            $logTypeMap[$LogType]
        } else {
            $LogType
        }
        
        # 清理文件名中的不安全字符
        $safeLogType = $chineseLogType -replace '[^a-zA-Z0-9\u4e00-\u9fa5]', '_'
        $datePart = "$($startDate.ToString('yyyyMMdd'))_至_$($endDate.ToString('yyyyMMdd'))"
        
        $trendPath = [System.IO.Path]::Combine($ExportPath, "${safeLogType}_日志_${datePart}_趋势分析.txt")
        $reportContent | Out-File -FilePath $trendPath -Encoding UTF8 -ErrorAction Stop
        Write-Host "`n趋势分析报告已保存至：$trendPath" -ForegroundColor Cyan
        
        # 保存趋势数据为CSV，便于后续分析
        $csvPath = [System.IO.Path]::Combine($ExportPath, "${safeLogType}_日志_${datePart}_趋势数据.csv")
        
        # 确保trendData包含有效数据
        if ($trendData.Count -gt 0) {
            # 使用更可靠的方式写入CSV
            $headers = "Date,EndDate,Critical,Error,Warning,TotalIssues,HealthScore"
            $headers | Out-File -FilePath $csvPath -Encoding UTF8 -Force
            
            foreach ($item in $trendData) {
                $line = "$($item.Date.ToString('yyyy-MM-dd HH:mm:ss')),$($item.EndDate.ToString('yyyy-MM-dd HH:mm:ss')),$($item.Critical),$($item.Error),$($item.Warning),$($item.TotalIssues),$($item.HealthScore)"
                $line | Out-File -FilePath $csvPath -Encoding UTF8 -Append
            }
            Write-Host "趋势数据已保存至：$csvPath" -ForegroundColor Cyan
        } else {
            Write-Host "趋势数据为空，未生成CSV文件" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "保存趋势报告失败：$($_.Exception.Message)" -ForegroundColor Red
        Write-Host "建议：检查输出目录权限或磁盘空间。" -ForegroundColor Yellow
    }
    
    Write-Host "`n【趋势分析完成】" -ForegroundColor Green
    # 不返回数据，避免在命令行中打印出原始数据
    return
}

function Test-LogAccess {
    <#
    .SYNOPSIS
        测试日志访问权限
    .DESCRIPTION
        测试是否有权限访问指定的事件日志
    .PARAMETER LogName
        日志名称，默认为 "System"
    .RETURNS
        布尔值，表示是否有权限访问日志
    .EXAMPLE
        # 示例：测试系统日志访问权限
        $canAccess = Test-LogAccess -LogName "System"
        if ($canAccess) {
            Write-Host "有权限访问系统日志" -ForegroundColor Green
        } else {
            Write-Host "无权限访问系统日志" -ForegroundColor Red
        }
    #>
    param([string]$LogName = "System")
    try {
        # 尝试获取日志，最多获取1个事件
        $null = Get-WinEvent -LogName $LogName -MaxEvents 1 -ErrorAction Stop
        return $true
    }
    catch {
        # 处理不同类型的错误
        if ($_.Exception.Message -like "*拒绝访问*" -or $_.Exception.Message -like "*Access is denied*" -or $_.Exception.Message -like "*unauthorized operation*") {
            # 权限错误
            if ($LogName -eq "Security") {
                Write-Host "❌ 无权访问 $LogName 事件日志。" -ForegroundColor Red
                Write-Host "👉 Security日志需要管理员权限才能访问，请以“管理员身份运行”PowerShell，或选择其他日志类型。" -ForegroundColor Yellow
            } else {
                Write-Host "❌ 无权访问 $LogName 事件日志。" -ForegroundColor Red
                Write-Host "👉 请以“管理员身份运行”PowerShell，或选择其他不需要管理员权限的日志类型。" -ForegroundColor Yellow
            }
        }
        elseif ($_.Exception.Message -like "*找不到*" -or $_.Exception.Message -like "*No matches found*") {
            # 日志不存在
            Write-Host "❌ 找不到 $LogName 日志。" -ForegroundColor Red
        }
        else {
            # 其他错误
            Write-Host "❌ 访问 $LogName 日志时出错：$($_.Exception.Message)" -ForegroundColor Red
        }
        return $false
    }
}

function Get-UserDateScope {
    <#
    .SYNOPSIS
        获取用户选择的日志类型和日期范围
    .DESCRIPTION
        交互式获取用户选择的日志类型、导出模式和日期范围，支持事件过滤选项
    .PARAMETER DefaultLogType
        默认日志类型，默认为 "System"
    .RETURNS
        包含日志类型、开始时间、结束时间、日期部分和报告标题的哈希表
    .EXAMPLE
        # 示例：获取用户日期范围
        $scope = Get-UserDateScope -DefaultLogType "System"
        Write-Host "选择的日志类型: $($scope.LogType)" -ForegroundColor Cyan
        Write-Host "开始时间: $($scope.StartTime)" -ForegroundColor Cyan
        Write-Host "结束时间: $($scope.EndTime)" -ForegroundColor Cyan
        Write-Host "报告标题: $($scope.ReportTitle)" -ForegroundColor Cyan
    #>
    param([string]$DefaultLogType = "System")
    
    # 核心修复：如果 DefaultLogType 为空字符串（GUI 传递），则强制使用 "System"
    if ([string]::IsNullOrWhiteSpace($DefaultLogType)) {
        $DefaultLogType = "System"
    }
    
    $maxRetries = 5
    $retryCount = 0
    $selectedLogTypes = @($DefaultLogType)
    
    # 定义日志类型映射
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
    
    # 选择日志类型（支持多选）
    while ($retryCount -lt $maxRetries) {
        Write-Host "`n【请选择日志类型】" -ForegroundColor Yellow
        Write-Host "1: System (系统)" -ForegroundColor Green
        Write-Host "2: Application (应用程序)" -ForegroundColor Green
        Write-Host "3: Security (安全) - 需要管理员权限" -ForegroundColor Yellow
        Write-Host "4: Setup (安装) - 需要管理员权限" -ForegroundColor Yellow
        Write-Host "5: DNS Server (DNS服务器) - 需要管理员权限" -ForegroundColor Yellow
        Write-Host "6: DHCP Server (DHCP服务器) - 需要管理员权限" -ForegroundColor Yellow
        Write-Host "7: Active Directory (活动目录) - 需要管理员权限" -ForegroundColor Yellow
        Write-Host "8: IIS (Web服务器) - 需要管理员权限" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "💡 提示：可选择多个日志类型，用逗号或空格分隔（如：1,2 或 1 2）" -ForegroundColor Cyan
        
        $logChoice = Get-AuroraInteraction -PromptMessage "`n请输入选项 (1-8)，直接回车则使用默认: $DefaultLogType"
        
        # 解析多选输入
        if ([string]::IsNullOrWhiteSpace($logChoice)) {
            $selectedLogTypes = @($DefaultLogType)
        }
        else {
            # 分割输入（支持逗号、空格、分号作为分隔符）
            $choices = $logChoice -split '[,\s;]+' | Where-Object { $_ }
            $selectedLogTypes = @()
            foreach ($choice in $choices) {
                if ($logTypeMap.ContainsKey($choice.Trim())) {
                    $selectedLogTypes += $logTypeMap[$choice.Trim()]
                }
            }
            $selectedLogTypes = $selectedLogTypes | Select-Object -Unique
        }
        
        # 验证至少选择了一个日志类型
        if ($selectedLogTypes.Count -eq 0) {
            Write-Host "`n❌ 未选择任何有效的日志类型，请重新输入！" -ForegroundColor Red
            $retryCount++
            continue
        }
        
        # 验证所有选择的日志类型是否存在且可访问
        $allValid = $true
        foreach ($logType in $selectedLogTypes) {
            if (-not (Test-LogAccess -LogName $logType)) {
                $allValid = $false
                break
            }
        }
        
        if ($allValid) {
            Write-Host "`n✅ 已选择日志类型: $($selectedLogTypes -join ', ')" -ForegroundColor Green
            break
        }
        else {
            $retryCount++
            if ($retryCount -ge $maxRetries) {
                Write-Host "`n🛑 输入错误次数过多，程序即将退出..." -ForegroundColor Red
                Write-Host "`n按 Enter 键退出" -ForegroundColor Gray
                Read-Host | Out-Null
                exit 1
            }
        }
    }
    
    $retryCount = 0
    while ($retryCount -lt $maxRetries) {
        Write-Host "`n【请选择导出模式】" -ForegroundColor Yellow
        Write-Host "1: 单日导出（例如：2026-01-21）" -ForegroundColor Green
        Write-Host "2: 日期范围导出（起止日期，格式：YYYY-MM-DD）" -ForegroundColor Green
        $mode = Get-AuroraInteraction -PromptMessage "`n请输入选项 (1 或 2)"
        if ($mode -eq '1') {
            $today = (Get-Date).Date
            $inputDate = Get-AuroraInteraction -PromptMessage "`n请输入日期 (格式：YYYY-MM-DD)，直接回车则导出今日日志"
            if ([string]::IsNullOrWhiteSpace($inputDate)) {
                $target = $today
            }
            else {
                try {
                    $target = [DateTime]::ParseExact($inputDate.Trim(), 'yyyy-MM-dd', $null).Date
                    if ($target -gt (Get-Date).Date) {
                        Write-Host "❌ 日期不能是未来日期！" -ForegroundColor Red
                        $retryCount++; continue
                    }
                }
                catch {
                    Write-Host "❌ 日期格式错误！请使用 YYYY-MM-DD 格式（例如：2026-01-21）。" -ForegroundColor Red
                    $retryCount++; continue
                }
            }
            # 创建 scope 数组，为每个选择的日志类型创建一个 scope
            $scopes = @()
            foreach ($logType in $selectedLogTypes) {
                $scopes += @{ 
                    StartTime   = $target
                    EndTime     = $target.AddDays(1).AddTicks(-1)
                    DatePart    = $target.ToString('yyyyMMdd')
                    ReportTitle = "$logType 日志日报 - $($target.ToString('yyyy-MM-dd'))"
                    LogType     = $logType
                }
            }
        }
        elseif ($mode -eq '2') {
            $startInput = Get-AuroraInteraction -PromptMessage "`n请输入起始日期 (格式：YYYY-MM-DD)"
            $endInput = Get-AuroraInteraction -PromptMessage "请输入结束日期 (格式：YYYY-MM-DD)"
            try {
                $startDate = [DateTime]::ParseExact($startInput.Trim(), 'yyyy-MM-dd', $null).Date
                $endDate = [DateTime]::ParseExact($endInput.Trim(), 'yyyy-MM-dd', $null).Date
                if ($startDate -gt (Get-Date).Date -or $endDate -gt (Get-Date).Date) {
                    Write-Host "❌ 日期不能是未来日期！" -ForegroundColor Red
                    $retryCount++; continue
                }
                if ($startDate -gt $endDate) {
                    Write-Host "⚠️ 起始日期不能晚于结束日期！" -ForegroundColor Yellow
                    $retryCount++; continue
                }
            }
            catch {
                Write-Host "❌ 日期格式错误！两个日期都必须是 YYYY-MM-DD 格式。" -ForegroundColor Red
                $retryCount++; continue
            }
            # 创建 scope 数组，为每个选择的日志类型创建一个 scope
            $scopes = @()
            foreach ($logType in $selectedLogTypes) {
                $scopes += @{ 
                    StartTime   = $startDate
                    EndTime     = $endDate.AddDays(1).AddTicks(-1)
                    DatePart    = "$($startDate.ToString('yyyyMMdd'))_至_$($endDate.ToString('yyyyMMdd'))"
                    ReportTitle = "$logType 日志报告 - $($startDate.ToString('yyyy-MM-dd')) 至 $($endDate.ToString('yyyy-MM-dd'))"
                    LogType     = $logType
                }
            }
        }
        else {
            Write-Host "❌ 无效选项！请输入 1 或 2。" -ForegroundColor Red
            $retryCount++; continue
        }
        
        # 添加事件过滤选项（对所有日志类型应用相同的过滤条件）
        Write-Host "`n【事件过滤选项】" -ForegroundColor Yellow
        Write-Host "1: 无过滤（默认）" -ForegroundColor Green
        Write-Host "2: 按事件 ID 过滤" -ForegroundColor Green
        Write-Host "3: 按事件提供程序过滤" -ForegroundColor Green
        Write-Host "4: 按事件级别过滤" -ForegroundColor Green
        $filterChoice = Get-AuroraInteraction -PromptMessage "`n请选择过滤选项 (1-4)，直接回车则使用默认: 1"
        
        # 定义过滤参数
        $filterEventId = $null
        $filterProviderName = $null
        $filterLevel = $null
        
        switch ($filterChoice) {
            '2' {
                $filterEventId = Get-AuroraInteraction -PromptMessage "`n请输入事件 ID（多个 ID 用逗号分隔）"
                if ([string]::IsNullOrWhiteSpace($filterEventId)) {
                    $filterEventId = $null
                }
            }
            '3' {
                $filterProviderName = Get-AuroraInteraction -PromptMessage "`n请输入事件提供程序名称"
                if ([string]::IsNullOrWhiteSpace($filterProviderName)) {
                    $filterProviderName = $null
                }
            }
            '4' {
                Write-Host "`n请选择事件级别：" -ForegroundColor Yellow
                Write-Host "1: 严重 (Critical)" -ForegroundColor Red
                Write-Host "2: 错误 (Error)" -ForegroundColor Red
                Write-Host "3: 警告 (Warning)" -ForegroundColor Yellow
                Write-Host "4: 信息 (Information)" -ForegroundColor Green
                Write-Host "5: 详细 (Verbose)" -ForegroundColor Gray
                $levelChoice = Get-AuroraInteraction -PromptMessage "`n请输入选项 (1-5)"
                $levelMap = @{'1' = '1'; '2' = '2'; '3' = '3'; '4' = '4'; '5' = '5'}
                if ($levelMap.ContainsKey($levelChoice)) {
                    $filterLevel = $levelMap[$levelChoice]
                }
            }
        }
        
        # 应用过滤条件到所有 scope
        for ($i = 0; $i -lt $scopes.Count; $i++) {
            if ($filterEventId) { $scopes[$i].EventId = $filterEventId }
            if ($filterProviderName) { $scopes[$i].ProviderName = $filterProviderName }
            if ($filterLevel) { $scopes[$i].Level = $filterLevel }
        }
        
        # 返回 scope 数组 - 核心修复：使用 @() 强制保持数组类型，防止单个元素时被解包
        return @($scopes)
    }
    Write-Host "`n🛑 输入错误次数过多，程序即将退出..." -ForegroundColor Red
    Write-Host "`n按 Enter 键退出" -ForegroundColor Gray
    Read-Host | Out-Null
    exit 1
}

# 全局变量来跟踪当前活动名称和进度行
$script:currentActivity = ""
$script:progressLines = @{}
$script:progressStartTime = @{}
$script:progressLastUpdate = @{}
$script:progressLastPercent = @{}
$script:progressSpeed = @{}
$script:progressRemaining = @{}
$script:activityLineMap = @{}

# 知识库相关全局变量
$script:knowledgeBase = $null
$script:knowledgeBaseLoaded = $false
$script:knowledgeBaseCache = @{}
$script:knowledgeBaseIndex = @{}
$script:knowledgeBaseLastLoaded = $null
$script:knowledgeBaseExpiryMinutes = 30
$script:knowledgeBaseCacheExpiryMinutes = 60  # 知识库缓存过期时间
$script:knowledgeBaseCacheMaxSize = 2000  # 最大缓存项数

function Load-KnowledgeBase {
    <#
    .SYNOPSIS
        加载知识库文件
    .DESCRIPTION
        从JSON文件加载知识库数据，并创建索引以加速查询
    .RETURNS
        布尔值，表示加载是否成功
    #>
    try {
        # 知识库文件路径（在 Data 目录）
        $kbPath = [System.IO.Path]::Combine($PSScriptRoot, "..\Data\AURORA-TechData.json")
        
        # 检查文件是否存在
        if (-not (Test-Path -Path $kbPath)) {
            Write-Host "❌ 知识库文件不存在: $kbPath" -ForegroundColor Red
            return $false
        }
        
        # 读取并解析JSON文件
        $jsonContent = Get-Content -Path $kbPath -Encoding UTF8 -ErrorAction Stop
        $script:knowledgeBase = $jsonContent | ConvertFrom-Json -ErrorAction Stop
        
        # 创建索引以加速查询
        New-KnowledgeBaseIndex
        
        $script:knowledgeBaseLoaded = $true
        $script:knowledgeBaseLastLoaded = Get-Date
        
        Write-Host "✅ 知识库加载成功，包含 $($script:knowledgeBase.categories.Count) 个类别" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ 加载知识库时出错: $($_.Exception.Message)" -ForegroundColor Red
        $script:knowledgeBaseLoaded = $false
        return $false
    }
}

function New-KnowledgeBaseIndex {
    <#
    .SYNOPSIS
        为知识库创建索引
    .DESCRIPTION
        创建基于事件ID、来源和关键字的索引，以加速查询
    #>
    try {
        # 重置索引
        $script:knowledgeBaseIndex = @{
            EventId = @{}
            Source = @{}
            Keyword = @{}
        }
        
        # 遍历所有知识库条目
        foreach ($category in $script:knowledgeBase.categories) {
            foreach ($item in $category.items) {
                # 按事件ID索引 - 确保使用int类型
                foreach ($eventId in $item.event_ids) {
                    $eventIdInt = [int]$eventId
                    if (-not $script:knowledgeBaseIndex.EventId.ContainsKey($eventIdInt)) {
                        $script:knowledgeBaseIndex.EventId[$eventIdInt] = @()
                    }
                    $script:knowledgeBaseIndex.EventId[$eventIdInt] += $item
                }
                
                # 按来源索引
                if ($item.source) {
                    $sourceKey = $item.source.ToLower()
                    if (-not $script:knowledgeBaseIndex.Source.ContainsKey($sourceKey)) {
                        $script:knowledgeBaseIndex.Source[$sourceKey] = @()
                    }
                    $script:knowledgeBaseIndex.Source[$sourceKey] += $item
                }
                
                # 按关键字索引
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
        
        Write-Host "✅ 知识库索引创建完成" -ForegroundColor Green
    } catch {
        Write-Host "❌ 创建知识库索引时出错: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-KnowledgeBaseSolution {
    <#
    .SYNOPSIS
        根据事件信息查询知识库解决方案
    .DESCRIPTION
        基于事件ID、来源和消息内容查询知识库中的解决方案，采用加权匹配和优先级排序
    .PARAMETER Event
        事件对象
    .RETURNS
        匹配的知识库解决方案数组
    .EXAMPLE
        # 示例：获取事件的知识库解决方案
        $event = Get-WinEvent -LogName System -MaxEvents 1
        $solutions = Get-KnowledgeBaseSolution -Event $event
        if ($solutions.Count -gt 0) {
            Write-Host "为事件ID $($event.Id)找到 $($solutions.Count) 个解决方案" -ForegroundColor Green
        } else {
            Write-Host "未找到事件ID $($event.Id)的解决方案" -ForegroundColor Yellow
        }
    #>
    param(
        [object]$Event
    )
    
    try {
        # 确保知识库已加载
        if (-not $script:knowledgeBaseLoaded) {
            $loadSuccess = Load-KnowledgeBase
            if (-not $loadSuccess) {
                return @()
            }
        }
        
        # 检查知识库是否过期
        if ($script:knowledgeBaseLastLoaded -and ((Get-Date) - $script:knowledgeBaseLastLoaded).TotalMinutes -gt $script:knowledgeBaseExpiryMinutes) {
            $loadSuccess = Load-KnowledgeBase
            if (-not $loadSuccess) {
                return @()
            }
        }
        
        # 🟢 核心防御：安全提取 Message，防止损坏的日志导致整个匹配中断
        $msgText = ""
        try {
            if ($null -ne $Event.Message) { $msgText = $Event.Message }
        } catch { Write-Debug "无法读取事件消息" }

        # 生成缓存键 - 使用完整消息的SHA256哈希，避免缓存冲突
        $rawKey = "$($Event.Id)-$($Event.ProviderName)-$msgText"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($rawKey)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($bytes)
        $cacheKey = [System.BitConverter]::ToString($hashBytes) -replace '-', ''
        
        # 尝试从缓存获取
        if ($script:knowledgeBaseCache.ContainsKey($cacheKey)) {
            $cachedData = $script:knowledgeBaseCache[$cacheKey].Data
            if ($cachedData) {
                return $cachedData
            } else {
                # 缓存数据是 $null，返回空数组
                return @()
            }
        }
        
        $solutionScores = @{}
        
        # 1. 按 Event ID 匹配（权重：100，精确匹配）- 处理类型不匹配
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
                # 尝试 string 类型
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
        
        # 2. 按 Source 匹配（权重：50，分类匹配）
        if ($Event.ProviderName) {
            $sourceKey = $Event.ProviderName.ToLower()
            
            # 首先尝试精确匹配
            if ($script:knowledgeBaseIndex.Source.ContainsKey($sourceKey)) {
                foreach ($item in $script:knowledgeBaseIndex.Source[$sourceKey]) {
                    $key = $item.rule_id
                    if (-not $solutionScores.ContainsKey($key)) {
                        $solutionScores[$key] = @{ Item = $item; Score = 0 }
                    }
                    $solutionScores[$key].Score += 50
                }
            } else {
                # 尝试移除 "Microsoft-Windows-" 前缀后匹配
                $sourceKeyWithoutPrefix = $sourceKey -replace '^microsoft-windows-', ''
                if ($script:knowledgeBaseIndex.Source.ContainsKey($sourceKeyWithoutPrefix)) {
                    foreach ($item in $script:knowledgeBaseIndex.Source[$sourceKeyWithoutPrefix]) {
                        $key = $item.rule_id
                        if (-not $solutionScores.ContainsKey($key)) {
                            $solutionScores[$key] = @{ Item = $item; Score = 0 }
                        }
                        $solutionScores[$key].Score += 45  # 略低的权重，因为不是精确匹配
                    }
                } else {
                    # 尝试反向：给 KB 源添加 "Microsoft-Windows-" 前缀并匹配
                    foreach ($kbSource in $script:knowledgeBaseIndex.Source.Keys) {
                        $prefixedKbSource = "microsoft-windows-$kbSource"
                        if ($sourceKey -eq $prefixedKbSource) {
                            foreach ($item in $script:knowledgeBaseIndex.Source[$kbSource]) {
                                $key = $item.rule_id
                                if (-not $solutionScores.ContainsKey($key)) {
                                    $solutionScores[$key] = @{ Item = $item; Score = 0 }
                                }
                                $solutionScores[$key].Score += 45  # 略低的权重，因为不是精确匹配
                            }
                            break
                        }
                    }
                }
            }
        }
        
        # 3. 按关键词匹配（每个匹配项权重：10，模糊匹配）
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
        
        # 4. 构建最终结果：按匹配分数降序 + 优先级降序排序
        $matchingSolutions = $solutionScores.Values | 
                             Sort-Object -Property @{Expression={$_.Score}; Descending=$true}, 
                                                   @{Expression={$_.Item.priority}; Descending=$true} | 
                             ForEach-Object { $_.Item }
        
        # 确保返回空数组而不是 $null
        if (-not $matchingSolutions) {
            $matchingSolutions = @()
        }
        
        # 缓存结果 - 存储为包含 Data 和 Time 的结构
        $script:knowledgeBaseCache[$cacheKey] = @{
            Data = $matchingSolutions
            Time = Get-Date
        }
        
        # 限制缓存大小 - 按时间排序清理旧缓存
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
        Write-Debug "查询知识库时出错: $($_.Exception.Message)"
        return @()
    }
}

function Get-KnowledgeBasePriority {
    <#
    .SYNOPSIS
        根据知识库获取事件优先级
    .DESCRIPTION
        基于事件ID和来源从知识库中获取优先级
    .PARAMETER Event
        事件对象
    .RETURNS
        优先级值（0-100），如果没有匹配则返回默认值
    #>
    param(
        [object]$Event
    )
    
    try {
        $solutions = Get-KnowledgeBaseSolution -Event $Event
        if ($solutions.Count -gt 0) {
            # 返回最高优先级
            return ($solutions | Sort-Object priority -Descending | Select-Object -First 1).priority
        }
        
        # 默认优先级
        return 50
    } catch {
        Write-Debug "获取知识库优先级时出错: $($_.Exception.Message)"
        return 50
    }
}

function Get-BatchKnowledgeBaseSolutions {
    <#
    .SYNOPSIS
        批量并行查询知识库解决方案
    .DESCRIPTION
        批量处理多个事件的知识库查询，使用并行处理提高性能
    .PARAMETER Events
        事件对象数组
    .PARAMETER ThreadCount
        并行线程数
    .RETURNS
        包含事件和对应解决方案的哈希表
    #>
    param(
        [array]$Events,
        [int]$ThreadCount = 4
    )
    
    try {
        # 确保知识库已加载
        if (-not $script:knowledgeBaseLoaded) {
            $loadSuccess = Load-KnowledgeBase
            if (-not $loadSuccess) {
                # 如果加载失败，返回空结果
                $result = @{}
                foreach ($event in $Events) {
                    $result[$event] = @()
                }
                return $result
            }
        }
        
        # 检查知识库是否过期
        if ($script:knowledgeBaseLastLoaded -and ((Get-Date) - $script:knowledgeBaseLastLoaded).TotalMinutes -gt $script:knowledgeBaseExpiryMinutes) {
            $loadSuccess = Load-KnowledgeBase
            if (-not $loadSuccess) {
                # 如果加载失败，返回空结果
                $result = @{}
                foreach ($event in $Events) {
                    $result[$event] = @()
                }
                return $result
            }
        }
        
        # 使用线程安全的集合存储结果
        Add-Type -AssemblyName System.Collections.Concurrent
        $threadSafeResults = New-Object System.Collections.Concurrent.ConcurrentDictionary[object, object]
        
        # 计算最佳线程数
        $optimalThreadCount = [Math]::Min($ThreadCount, $Events.Count, [Environment]::ProcessorCount)
        if ($optimalThreadCount -lt 1) {
            $optimalThreadCount = 1
        }
        
        # 创建RunspacePool
        $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $optimalThreadCount)
        $runspacePool.Open()
        
        $jobs = @()
        
        # 为每个事件创建一个任务
        foreach ($event in $Events) {
            $powershell = [PowerShell]::Create()
            $powershell.RunspacePool = $runspacePool
            
            # 添加脚本块
            $powershell.AddScript({
                param($event, $knowledgeBaseLoaded, $knowledgeBaseIndex, $knowledgeBaseCache, $knowledgeBaseExpiryMinutes, $knowledgeBaseLastLoaded)
                
                try {
                    # 生成缓存键
                    $cacheKey = "$($event.Id)-$($event.ProviderName)-$($event.Message.Substring(0, [Math]::Min(100, $event.Message.Length)))"
                    $cacheKey = $cacheKey -replace '[^a-zA-Z0-9]', '_'
                    
                    # 尝试从缓存获取
                    if ($knowledgeBaseCache.ContainsKey($cacheKey)) {
                        $cachedItem = $knowledgeBaseCache[$cacheKey]
                        # 检查缓存是否过期
                        if ($cachedItem.Time -and ((Get-Date) - $cachedItem.Time).TotalMinutes -lt 60) {
                            return @{ Event = $event; Solutions = $cachedItem.Data }
                        }
                    }
                    
                    # ====== 核心重构：严格交集校验 (Strict AND) ======
                    # 1. 圈定候选规则
                    $candidates = @()
                    if ($event.Id -and $knowledgeBaseIndex.EventId.ContainsKey($event.Id)) {
                        $candidates += $knowledgeBaseIndex.EventId[$event.Id]
                    }
                    if ($event.ProviderName) {
                        $sourceKey = $event.ProviderName.ToLower()
                        if ($knowledgeBaseIndex.Source.ContainsKey($sourceKey)) {
                            $candidates += $knowledgeBaseIndex.Source[$sourceKey]
                        }
                    }
                    $candidates = $candidates | Sort-Object rule_id -Unique
                    
                    $matchingSolutions = @()
                    
                    # 2. 严格校验证据链
                    foreach ($rule in $candidates) {
                        $isMatch = $true
                        
                        if ($rule.event_ids -and $rule.event_ids.Count -gt 0) {
                            if ($rule.event_ids -notcontains $event.Id) { $isMatch = $false }
                        }
                        
                        if ($isMatch -and $rule.source) {
                            if ($event.ProviderName -notmatch "(?i)$($rule.source)") { $isMatch = $false }
                        }
                        
                        if ($isMatch -and $rule.message_keywords -and $rule.message_keywords.Count -gt 0) {
                            $messageLower = if ($event.Message) { $event.Message.ToLower() } else { "" }
                            $keywordMatch = $false
                            foreach ($kw in $rule.message_keywords) {
                                if ($messageLower -like "*$($kw.ToLower())*") {
                                    $keywordMatch = $true
                                    break
                                }
                            }
                            if (-not $keywordMatch) { $isMatch = $false }
                        }
                        
                        if ($isMatch) {
                            $matchingSolutions += $rule
                        }
                    }
                    
                    return @{ Event = $event; Solutions = $matchingSolutions }
                } catch {
                    Write-Debug "批量查询知识库时出错: $($_.Exception.Message)"
                    return @{ Event = $event; Solutions = @() }
                }
            }).AddArgument($event).AddArgument($script:knowledgeBaseLoaded).AddArgument($script:knowledgeBaseIndex).AddArgument($script:knowledgeBaseCache).AddArgument($script:knowledgeBaseExpiryMinutes).AddArgument($script:knowledgeBaseLastLoaded)
            
            $job = $powershell.BeginInvoke()
            # 🟢 核心修复 1：在主线程的 Job 记录中保存原生的 Event 引用！
            $jobs += @{ PowerShell = $powershell; Job = $job; OriginalEvent = $event }
        }
        
        # 等待所有任务完成并收集结果
        foreach ($job in $jobs) {
            try {
                $result = $job.PowerShell.EndInvoke($job.Job)
                if ($result -and $result.Event) {
                    $threadSafeResults.TryAdd($result.Event, $result.Solutions)
                    
                    # 更新缓存
                    $cacheKey = "$($result.Event.Id)-$($result.Event.ProviderName)-$($result.Event.Message.Substring(0, [Math]::Min(100, $result.Event.Message.Length)))"
                    $cacheKey = $cacheKey -replace '[^a-zA-Z0-9]', '_'
                    $script:knowledgeBaseCache[$cacheKey] = @{
                        Time = Get-Date
                        Data = $result.Solutions
                    }
                }
            } catch {
                Write-Debug "处理批量查询结果时出错: $($_.Exception.Message)"
            } finally {
                $job.PowerShell.Dispose()
            }
        }
        
        # 关闭RunspacePool
        $runspacePool.Close()
        $runspacePool.Dispose()
        
        # 清理过期缓存
        $currentTime = Get-Date
        $keysToRemove = @()
        foreach ($key in $script:knowledgeBaseCache.Keys) {
            $cachedItem = $script:knowledgeBaseCache[$key]
            if ($cachedItem.Time -and ((Get-Date) - $cachedItem.Time).TotalMinutes -ge $script:knowledgeBaseCacheExpiryMinutes) {
                $keysToRemove += $key
            }
        }
        foreach ($key in $keysToRemove) {
            $script:knowledgeBaseCache.Remove($key)
        }
        
        # 限制缓存大小
        if ($script:knowledgeBaseCache.Count -gt $script:knowledgeBaseCacheMaxSize) {
            $oldestKeys = $script:knowledgeBaseCache.GetEnumerator() | Sort-Object { $_.Value.Time } | Select-Object -First ($script:knowledgeBaseCache.Count - $script:knowledgeBaseCacheMaxSize) -ExpandProperty Key
            foreach ($key in $oldestKeys) {
                $script:knowledgeBaseCache.Remove($key)
            }
        }
        
        # 转换为普通哈希表
        $finalResult = @{}
        foreach ($event in $Events) {
            if ($threadSafeResults.ContainsKey($event)) {
                $finalResult[$event] = $threadSafeResults[$event]
            } else {
                $finalResult[$event] = @()
            }
        }
        
        return $finalResult
    } catch {
        Write-Debug "批量查询知识库时出错: $($_.Exception.Message)"
        # 返回空结果
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
        批量并行获取事件优先级
    .DESCRIPTION
        批量处理多个事件的优先级获取，使用并行处理提高性能
    .PARAMETER Events
        事件对象数组
    .PARAMETER ThreadCount
        并行线程数
    .RETURNS
        包含事件和对应优先级的哈希表
    #>
    param(
        [array]$Events,
        [int]$ThreadCount = 4
    )
    
    try {
        # 批量获取解决方案
        $solutionsMap = Get-BatchKnowledgeBaseSolutions -Events $Events -ThreadCount $ThreadCount
        
        # 计算每个事件的优先级
        $priorities = @{}
        foreach ($event in $Events) {
            $solutions = $solutionsMap[$event]
            if ($solutions.Count -gt 0) {
                # 返回最高优先级
                $priorities[$event] = ($solutions | Sort-Object priority -Descending | Select-Object -First 1).priority
            } else {
                # 默认优先级
                $priorities[$event] = 50
            }
        }
        
        return $priorities
    } catch {
        Write-Debug "批量获取优先级时出错: $($_.Exception.Message)"
        # 返回默认优先级
        $priorities = @{}
        foreach ($event in $Events) {
            $priorities[$event] = 50
        }
        return $priorities
    }
}

function Write-CustomProgress {
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
    # 检查是否在控制台中运行
    if ($Host.Name -ne 'ConsoleHost') {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
        return
    }
    
    # 初始化进度跟踪
    if (-not $script:progressStartTime.ContainsKey($Activity)) {
        $script:progressStartTime[$Activity] = Get-Date
        $script:progressLastUpdate[$Activity] = Get-Date
        $script:progressLastPercent[$Activity] = 0
        # 为每个活动初始化行号映射
        $script:activityLineMap[$Activity] = @{ dataLine = 0; detailLine = 0; speedLine = 0; barLine = 0 }
    }
    
    # 计算处理速度和预计剩余时间
    $elapsedTime = (Get-Date) - $script:progressStartTime[$Activity]
    $elapsedSeconds = $elapsedTime.TotalSeconds
    $timeSinceLastUpdate = (Get-Date) - $script:progressLastUpdate[$Activity]
    
    # 初始化速度和剩余时间变量
    $speed = 0
    $estimatedRemaining = ""
    
    # 每2秒更新一次速度和剩余时间
    if ($timeSinceLastUpdate.TotalSeconds -ge 2 -or $PercentComplete -eq 100) {
        if ($elapsedSeconds -gt 0 -and $PercentComplete -gt 0 -and $TotalItems -gt 0) {
            $speed = [Math]::Round(($PercentComplete / 100) * $TotalItems / $elapsedSeconds, 2)
            if ($PercentComplete -lt 100) {
                $estimatedTotalSeconds = $elapsedSeconds * (100 / $PercentComplete)
                $estimatedRemainingSeconds = $estimatedTotalSeconds - $elapsedSeconds
                if ($estimatedRemainingSeconds -gt 0) {
                    $timespan = New-TimeSpan -Seconds $estimatedRemainingSeconds
                    $estimatedRemaining = "预计剩余: $($timespan.ToString() -replace '\.[0-9]+', '')"
                }
            }
        }
        
        $script:progressLastUpdate[$Activity] = Get-Date
        $script:progressLastPercent[$Activity] = $PercentComplete
        # 保存当前速度和剩余时间
        $script:progressSpeed[$Activity] = $speed
        $script:progressRemaining[$Activity] = $estimatedRemaining
    } else {
        # 使用之前保存的速度和剩余时间
        if ($script:progressSpeed.ContainsKey($Activity)) {
            $speed = $script:progressSpeed[$Activity]
        }
        if ($script:progressRemaining.ContainsKey($Activity)) {
            $estimatedRemaining = $script:progressRemaining[$Activity]
        }
    }
    
    # 根据终端宽度计算进度条长度
    try {
        $consoleWidth = $Host.UI.RawUI.BufferSize.Width
        # 为活动和状态文本留出空间
        $availableWidth = $consoleWidth - 5
        $progressBarLength = [Math]::Max(10, [Math]::Min(50, $availableWidth - 10))
    } catch {
        # 如果无法确定终端宽度，使用默认值
        $consoleWidth = 120
        $progressBarLength = 30
    }
    $completedLength = [Math]::Max(0, [Math]::Min($progressBarLength, [Math]::Round($progressBarLength * $PercentComplete / 100)))
    $remainingLength = $progressBarLength - $completedLength
    
    # 构建进度条 - 使用更美观的字符
    $completedChars = "█" * $completedLength
    $remainingChars = "░" * $remainingLength
    $progressBar = "$completedChars$remainingChars"
    
    # 限制输出长度为控制台宽度
    $maxOutputLength = [Math]::Min(110, $consoleWidth - 5)
    
    # 添加空格确保覆盖整行
    $progressBar = $progressBar.PadRight($maxOutputLength)
    $clearLine = " " * $maxOutputLength
    
    # 当活动名称改变或首次调用时只输出活动名称
    if ($Activity -ne $script:currentActivity) {
        $script:currentActivity = $Activity
        # 确保活动切换时添加换行，避免与之前的输出重叠
        Write-Host ""
        Write-Host "[$Activity]" -ForegroundColor Cyan
        # 输出空行作为详细信息、速度和进度条行
        Write-Host ""
        Write-Host ""
        Write-Host ""
        # 记录当前活动的行号
        $currentY = $Host.UI.RawUI.CursorPosition.Y - 3  # 减去3行，因为我们刚刚输出了3个空行
        $script:activityLineMap[$Activity] = @{ dataLine = $currentY; detailLine = $currentY + 1; speedLine = $currentY + 2; barLine = $currentY + 3 }
        # 强制刷新输出缓冲区
        [System.Console]::Out.Flush()
    }
    
    # 确保活动行映射存在
    if (-not $script:activityLineMap.ContainsKey($Activity)) {
        # 如果活动行映射不存在，重新初始化
        $currentY = $Host.UI.RawUI.CursorPosition.Y
        $script:activityLineMap[$Activity] = @{ dataLine = $currentY; detailLine = $currentY + 1; speedLine = $currentY + 2; barLine = $currentY + 3 }
    }
    
    # 使用光标位置回到活动对应的数据行，实现原地刷新
    $hostUI = $Host.UI.RawUI
    $cursorPosition = $hostUI.CursorPosition
    $clearLine = " " * $maxOutputLength
    
    try {
        # 保存当前光标位置
        $originalCursorPosition = $hostUI.CursorPosition
        
        # 更新数据行（主要状态信息）
        $cursorPosition.Y = $script:activityLineMap[$Activity].dataLine
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # 清除数据行
        Write-Host -NoNewline $clearLine
        # 回到行首
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # 写入新的数据信息
        $mainStatus = $Status
        if ($CurrentTask) {
            $mainStatus += " | 当前任务: $CurrentTask"
        }
        # 仅当状态中不包含进度信息时才添加
        if ($CurrentItem -gt 0 -and $TotalItems -gt 0 -and $Status -notmatch "进度:") {
            $mainStatus += " | 进度: $CurrentItem/$TotalItems"
        } elseif ($CurrentItem -gt 0 -and $TotalItems -eq 0 -and $Status -notmatch "已处理:") {
            $mainStatus += " | 已处理: $CurrentItem 项"
        }
        # 限制长度
        if ($mainStatus.Length -gt $maxOutputLength) {
            $mainStatus = $mainStatus.Substring(0, $maxOutputLength)
        }
        Write-Host -NoNewline $mainStatus -ForegroundColor Cyan
        
        # 更新详细信息行
        $cursorPosition.Y = $script:activityLineMap[$Activity].detailLine
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # 清除详细信息行
        Write-Host -NoNewline $clearLine
        # 回到行首
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # 写入详细信息
        $detailStatus = ""
        if ($CurrentItem -gt 0 -and $TotalItems -gt 0) {
            $detailStatus += "完成度: $PercentComplete%"
        }
        # 限制长度
        if ($detailStatus.Length -gt $maxOutputLength) {
            $detailStatus = $detailStatus.Substring(0, $maxOutputLength)
        }
        if ($detailStatus) {
            Write-Host -NoNewline $detailStatus -ForegroundColor Cyan
        }
        
        # 更新速度信息行（独立显示速度和剩余时间）
        $cursorPosition.Y = $script:activityLineMap[$Activity].speedLine
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # 清除速度信息行
        Write-Host -NoNewline $clearLine
        # 回到行首
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # 写入速度信息
        $speedStatus = ""
        if ($speed -gt 0) {
            $speedStatus += "速度: $speed 项/秒"
        }
        if ($estimatedRemaining) {
            if ($speedStatus) {
                $speedStatus += " | $estimatedRemaining"
            } else {
                $speedStatus += $estimatedRemaining
            }
        }
        # 限制长度
        if ($speedStatus.Length -gt $maxOutputLength) {
            $speedStatus = $speedStatus.Substring(0, $maxOutputLength)
        }
        if ($speedStatus) {
            Write-Host -NoNewline $speedStatus -ForegroundColor Cyan
        }
        
        # 更新进度条行
        $cursorPosition.Y = $script:activityLineMap[$Activity].barLine
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # 清除进度条行
        Write-Host -NoNewline $clearLine
        # 回到行首
        $cursorPosition.X = 0
        $hostUI.CursorPosition = $cursorPosition
        # 写入新的进度条
        Write-Host -NoNewline $progressBar -ForegroundColor Cyan
        
        # 恢复原始光标位置
        $hostUI.CursorPosition = $originalCursorPosition
    } catch {
        # 如果光标位置设置失败，使用简单的输出方式
        # 确保每次输出都添加换行，避免重叠
        Write-Host "`n$mainStatus" -ForegroundColor Cyan
        if ($detailStatus) {
            Write-Host "$detailStatus" -ForegroundColor Cyan
        }
        if ($speedStatus) {
            Write-Host "$speedStatus" -ForegroundColor Cyan
        }
        Write-Host "$progressBar" -ForegroundColor Cyan
    }
    
    # 强制刷新输出缓冲区
    [System.Console]::Out.Flush()
}

function Get-HighRiskEvents {
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
    # 计算总时间范围（小时）
    $totalHours = [Math]::Ceiling(($EndTime - $StartTime).TotalHours)
    $currentHour = 0
    
    # 生成缓存键（使用英文日志类型名称确保与ENGPRO版本一致）
    $cacheLogType = if ($LogType -eq "系统") { "System" } elseif ($LogType -eq "应用程序") { "Application" } else { $LogType }
    $cacheKey = Get-CacheKey -LogType "$cacheLogType-HighRisk" -StartTime $StartTime -EndTime $EndTime -EventId $EventId -ProviderName $ProviderName -Level $Level
    
    # 尝试从缓存获取数据
    if (-not $ForceRescan) {
        $cachedData = Get-CachedLogData -CacheKey $cacheKey -Silent $Silent
        if ($cachedData -and $cachedData.Count -gt 0) {
            # 获取总日志数
            $totalEventsCacheKey = Get-CacheKey -LogType "$cacheLogType-Full" -StartTime $StartTime -EndTime $EndTime -EventId $EventId -ProviderName $ProviderName -Level $Level
            $totalEventsData = Get-CachedLogData -CacheKey $totalEventsCacheKey -Silent $true
            $totalEventCount = if ($totalEventsData) { $totalEventsData.Count } else { 0 }
            
            if (-not $Silent) {
                Write-Host "`n【高危事件扫描完成】共发现 $($cachedData.Count) 条高危事件" -ForegroundColor Green
            }
            return $cachedData
        }
    } else {
        if (-not $Silent) {
            Write-Host "`n【强制重新扫描】跳过缓存，直接扫描事件..." -ForegroundColor Yellow
        }
    }
    
    # 初始化总日志数为0，在扫描过程中逐步获取
    $totalEventCount = 0
    $totalEventsRetrieved = $false
    
    if (-not $Silent) {
        Write-CustomProgress -Activity "正在扫描高危事件（严重/错误/警告）" -Status "初始化..." -PercentComplete 0
    }
    
    try {
        # 使用传入的性能分数和最佳分块大小，如果没有传入则计算
        if ($PerformanceScore -eq 0) {
            $performanceScore = Get-SystemPerformanceScore
        }
        if ($OptimalChunkSize -eq 0) {
            $optimalChunkSize = Get-OptimalChunkSize -PerformanceScore $performanceScore -LogType $LogType
        }
        
        # 先获取总日志数
        if (-not $Silent) {
            Write-CustomProgress -Activity "正在扫描高危事件（严重/错误/警告）" -Status "正在获取总日志数..." -PercentComplete 20
            # 强制刷新输出缓冲区
            [System.Console]::Out.Flush()
        }
        
        # 暂时将总高危事件数设置为0，在扫描完成后再更新
        $totalEventCount = 0
        $totalEventsRetrieved = $false
        
        if (-not $Silent) {
            Write-CustomProgress -Activity "正在扫描高危事件（严重/错误/警告）" -Status "初始化完成，开始扫描..." -PercentComplete 40
            # 强制刷新输出缓冲区
            [System.Console]::Out.Flush()
        }
        
        # 分块扫描高危事件
        $step = [TimeSpan]::FromHours($optimalChunkSize)
        $cur = $StartTime
        
        # 生成所有分块
        $chunks = @()
        while ($cur -lt $EndTime) {
            $nxt = [datetime][Math]::Min(($cur + $step).Ticks, $EndTime.Ticks)
            $chunks += @{ StartTime = $cur; EndTime = $nxt }
            $cur = $nxt
        }
        
        $totalChunks = $chunks.Count
        $processedChunks = 0
        
        # 使用线程安全的集合存储结果
        $allEvents = New-Object 'System.Collections.Generic.List[object]'
        
        # 使用最佳并行度设置
        if (!$logScanningStrategy) {
            # Default strategy if not provided, based on performance score
            $logScanningStrategy = Get-ResourceOptimizedStrategy -PerformanceScore $performanceScore -TaskType "LogScanning"
        }

        # 获取CPU核心数
        $cpuInfos = Get-CimInstance Win32_Processor
        $cpuCores = if ($cpuInfos -is [array]) {
            $cpuInfos | Measure-Object -Property NumberOfCores -Sum | Select-Object -ExpandProperty Sum
        } else {
            $cpuInfos.NumberOfCores
        }

        # 使用Get-OptimalParallelism计算最佳并行度
        $optimalThreads = Get-OptimalParallelism -CpuCores $cpuCores
        $threadCount = [Math]::Max(1, [Math]::Min($optimalThreads, $totalChunks))
        
        # 监控内存使用情况 - 优化高性能系统的内存监控逻辑
        $memoryUsage = Get-MemoryUsage
        if ($performanceScore -ge 80) {
            # 高性能系统，内存监控更宽松
            if ($memoryUsage -gt 90) {
                $threadCount = [Math]::Max(1, [Math]::Round($threadCount * 0.7))
            } elseif ($memoryUsage -gt 80) {
                $threadCount = [Math]::Max(1, [Math]::Round($threadCount * 0.9))
            }
        } else {
            # 原有的内存监控逻辑
            if ($memoryUsage -gt 80) {
                $threadCount = [Math]::Max(1, [Math]::Round($threadCount * 0.5))
            } elseif ($memoryUsage -gt 60) {
                $threadCount = [Math]::Max(1, [Math]::Round($threadCount * 0.75))
            }
        }
        
        if (-not $Silent) {
            Write-Host "`n[系统资源监控] 并行线程数: $threadCount, 内存使用率: $memoryUsage%" -ForegroundColor Cyan
        }
        

        
        # 优化：批处理分块，减少任务创建开销
        $batchSize = 5  # 每批处理的分块数
        $batches = @()
        for ($i = 0; $i -lt $chunks.Count; $i += $batchSize) {
            $end = [Math]::Min($i + $batchSize, $chunks.Count)
            $batchChunks = $chunks[$i..($end - 1)]
            $batches += @{ Chunks = $batchChunks; Start = $batchChunks[0].StartTime; End = $batchChunks[-1].EndTime; Index = $i }
        }
        
        $totalBatches = $batches.Count
        $processedBatches = 0
        
        # 获取或创建全局RunspacePool
        $runspacePool = Get-RunspacePool -ThreadCount $threadCount
        
        $jobs = @()
        
        # 为每个批次创建一个任务
        foreach ($batch in $batches) {
            # Convert log type to English if it's in Chinese
            $cacheLogType = if ($LogType -eq "系统") { "System" } elseif ($LogType -eq "应用程序") { "Application" } else { $LogType }
            
            $scriptBlock = {
                param($batchChunks, $logType, $eventId, $providerName, $level)
                
                try {
                    $batchEvents = New-Object 'System.Collections.Generic.List[object]'
                    
                    foreach ($chunk in $batchChunks) {
                        # 直接在 Get-WinEvent 中过滤严重、错误、警告事件
                        $filterHashtable = @{
                            LogName = $logType;
                            StartTime = $chunk.StartTime;
                            EndTime = $chunk.EndTime;
                            Level = 1, 2, 3
                        }
                        
                        # 获取符合条件的事件
                        $chunkEvents = Get-WinEvent -FilterHashtable $filterHashtable -ErrorAction SilentlyContinue
                        
                        # 进一步过滤
                        if ($chunkEvents) {
                            # 确保$chunkEvents是数组
                            if ($chunkEvents -isnot [array]) {
                                $chunkEvents = @($chunkEvents)
                            }
                            
                            # 按事件 ID 过滤
                            if (![string]::IsNullOrWhiteSpace($eventId)) {
                                $eventIds = $eventId -split ',' | ForEach-Object { $_.Trim() }
                                $chunkEvents = $chunkEvents | Where-Object { $eventIds -contains $_.Id.ToString() }
                            }
                            
                            # 按事件提供程序过滤（使用通配符匹配）
                            if (![string]::IsNullOrWhiteSpace($providerName)) {
                                $chunkEvents = $chunkEvents | Where-Object { $_.ProviderName -like "*$providerName*" }
                            }
                            
                            # 按事件级别过滤（仅当Level参数不为空且在1-3之间时）
                            if (![string]::IsNullOrWhiteSpace($level)) {
                                $levelInt = 0
                                if ([int]::TryParse($level, [ref]$levelInt) -and $levelInt -ge 1 -and $levelInt -le 3) {
                                    $chunkEvents = $chunkEvents | Where-Object { 
                                        $eventLevel = if ($null -eq $_.Level) { 0 } else { [int]$_.Level }
                                        $eventLevel -eq $levelInt 
                                    }
                                }
                            }
                            
                            # 确保返回的是有效的事件
                            if ($chunkEvents.Count -gt 0) {
                                # 过滤掉$null 元素并确保数组类型
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
                    # 忽略单个批次的错误，继续扫描
                    Write-Debug "扫描批次时出错: $($_.Exception.Message)"
                    return @()
                }
            }
            
            $powershell = [PowerShell]::Create()
            $powershell.RunspacePool = $runspacePool
            $powershell.AddScript($scriptBlock).AddArgument($batch.Chunks).AddArgument($cacheLogType).AddArgument($EventId).AddArgument($ProviderName).AddArgument($Level)
            
            $job = $powershell.BeginInvoke()
            $jobs += @{ PowerShell = $powershell; Job = $job; Batch = $batch }
        }
        
        # 等待所有任务完成并收集结果
        $processedBatches = 0
        # ====== 核心修复：在循环外部声明计数器 ======
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
                    # 忽略错误，继续处理
                }
                finally {
                    $job.PowerShell.Dispose()
                }
                
                $processedBatches++
                $processedChunks = $processedBatches * $batchSize
                if ($processedChunks -gt $totalChunks) {
                    $processedChunks = $totalChunks
                }
                
                # ====== 核心修复：每处理 40 条数据，或者到达最后一条时，才通知前端一次 ======
                $throttleCounter++
                if ($throttleCounter % 40 -eq 0 -or $throttleCounter -eq $totalChunks) {
                    if (-not $Silent) {
                        $percent = [Math]::Min(100, [Math]::Round(($processedChunks / $totalChunks) * 100))
                        Write-CustomProgress -Activity "正在扫描高危事件（严重/错误/警告）" -Status "已扫描 $processedChunks/$totalChunks 块，发现 $($allEvents.Count) 条高危事件" -PercentComplete $percent -CurrentItem $processedChunks -TotalItems $totalChunks -CurrentTask "扫描块 $processedChunks"
                        # 强制刷新输出缓冲区，确保进度条实时更新
                        [System.Console]::Out.Flush()
                    }
                }
            }
            
            $jobs = $jobs | Where-Object { -not $_.Job.IsCompleted }
            Start-Sleep -Milliseconds 100
        }
        
        # 关闭RunspacePool
        Close-RunspacePool -Silent $true
        
        # 扫描完成后，更新总高危事件数为实际发现的事件数
        $totalEventCount = $allEvents.Count
        
        # 确保最后显示100%进度
        if (-not $Silent) {
            Write-CustomProgress -Activity "正在扫描高危事件（严重/错误/警告）" -Status "已扫描 $totalChunks/$totalChunks 块，发现 $($allEvents.Count) 条高危事件" -PercentComplete 100
            # 强制刷新输出缓冲区
            [System.Console]::Out.Flush()
            # 等待一小段时间确保进度条完全显示
            Start-Sleep -Milliseconds 1000
        }
        
        # 批量处理知识库查询，为事件添加优先级信息
        if ($allEvents.Count -gt 0) {
            if (-not $Silent) {
                Write-Host "`n[知识库分析] 正在批量处理 $($allEvents.Count) 条事件的知识库查询..." -ForegroundColor Cyan
            }
            
            # 使用批量并行查询函数
            $priorities = Get-BatchKnowledgeBasePriorities -Events $allEvents -ThreadCount $threadCount
            
            # 为每个事件添加优先级信息
            foreach ($event in $allEvents) {
                try {
                    $priority = $priorities[$event]
                    Add-Member -InputObject $event -NotePropertyName "KnowledgeBasePriority" -NotePropertyValue $priority -Force
                } catch {
                    # 忽略错误，继续处理
                }
            }
            
            if (-not $Silent) {
                Write-Host "[知识库分析] 批量处理完成" -ForegroundColor Green
            }
        }
        
        # 注意：不再关闭RunspacePool，留作后续使用
        
        # 将结果存入缓存
        if (!$cacheStrategy) {
            # Default cache strategy if not provided
            $cacheStrategy = Get-IntelligentCacheStrategy -PerformanceScore $performanceScore -DataSizeKB 10000
        }
        Set-CachedLogData -CacheKey $cacheKey -Data $allEvents -CacheStrategy $cacheStrategy -Silent $Silent
        
        # 完成后添加换行
        if (-not $Silent) {
            Write-Host "`n【高危事件扫描完成】共发现 $($allEvents.Count) 条高危事件" -ForegroundColor Green
        }
        return $allEvents
    }
    catch {
        Write-Host "`n扫描过程中发生错误：$($_.Exception.Message)" -ForegroundColor Red
        # 即使发生错误，也返回已收集的事件
        return $allEvents
    }
}

function Get-FullSystemLog {
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
    # 生成缓存键（使用英文日志类型名称确保与ENGPRO版本一致）
    $cacheLogType = if ($LogType -eq "系统") { "System" } elseif ($LogType -eq "应用程序") { "Application" } else { $LogType }
    $cacheKey = Get-CacheKey -LogType "$cacheLogType-Full" -StartTime $StartTime -EndTime $EndTime -EventId $EventId -ProviderName $ProviderName -Level $Level
    
    # 尝试从缓存获取数据
    $cachedData = Get-CachedLogData -CacheKey $cacheKey -Silent $Silent
    if ($cachedData -and $cachedData.Count -gt 0) {
        if (-not $Silent) {
            Write-Host "`n【完整 $LogType 日志读取完成】共采集 $($cachedData.Count) 条事件" -ForegroundColor Green
        }
        return $cachedData
    }
    
    # 尝试从高危事件扫描的缓存中获取数据（如果完整日志缓存不存在）
    $highRiskCacheKey = Get-CacheKey -LogType "$cacheLogType-HighRisk" -StartTime $StartTime -EndTime $EndTime -EventId $EventId -ProviderName $ProviderName -Level $Level
    $highRiskCachedData = Get-CachedLogData -CacheKey $highRiskCacheKey -Silent $Silent
    if ($highRiskCachedData -and $highRiskCachedData.Count -gt 0) {
        if (-not $Silent) {
            Write-Host "`n【完整 $LogType 日志读取完成】从高危事件缓存中获取数据，共采集 $($highRiskCachedData.Count) 条事件" -ForegroundColor Green
        }
        # 将高危事件缓存数据存入完整日志缓存，以便后续使用
        if (-not $Silent) {
            Set-CachedLogData -CacheKey $cacheKey -Data $highRiskCachedData
        } else {
            # 静默模式下直接存入缓存，不显示输出
            $script:logCache[$cacheKey] = @{
                Time = Get-Date
                Data = $highRiskCachedData
            }
            # 根据内存使用情况限制缓存大小
            $optimalCacheSize = Get-OptimalCacheSize
            if ($script:logCache.Count -gt $optimalCacheSize) {
                # 移除最旧的缓存项
                $oldestKey = $script:logCache.GetEnumerator() | Sort-Object { $_.Value.Time } | Select-Object -First 1 -ExpandProperty Key
                $script:logCache.Remove($oldestKey)
            }
        }
        return $highRiskCachedData
    }
    
    if (-not $Silent) {
        Write-CustomProgress -Activity "正在读取完整 $LogType 日志" -Status "初始化..." -PercentComplete 0
        # 强制刷新输出缓冲区
        [System.Console]::Out.Flush()
    }
    
    # 使用传入的总日志数，如果没有传入则尝试获取
    $totalEventCount = $TotalEventCount
    if ($totalEventCount -eq 0) {
        if (-not $Silent) {
            Write-CustomProgress -Activity "正在读取完整 $LogType 日志" -Status "正在获取总日志数..." -PercentComplete 20
            # 强制刷新输出缓冲区
            [System.Console]::Out.Flush()
        }
        
        # 尝试从缓存获取总日志数
        $totalEventsCacheKey = Get-CacheKey -LogType "$cacheLogType-Full" -StartTime $StartTime -EndTime $EndTime -EventId $EventId -ProviderName $ProviderName -Level $Level
        $totalEventsData = Get-CachedLogData -CacheKey $totalEventsCacheKey -Silent $true
        if ($totalEventsData) {
            $totalEventCount = $totalEventsData.Count
        } else {
            # 如果缓存不存在，直接获取总日志数
            try {
                # 构建过滤条件
                $filterHashtable = @{ LogName = $LogType; StartTime = $StartTime; EndTime = $EndTime }
                
                # 添加事件ID过滤（如果提供）
                if (![string]::IsNullOrWhiteSpace($EventId)) {
                    $eventIds = $EventId -split ',' | ForEach-Object { $_.Trim() }
                    if ($eventIds.Count -gt 0) {
                        $filterHashtable["Id"] = $eventIds
                    }
                }
                
                # 添加事件提供程序过滤（如果提供）
                if (![string]::IsNullOrWhiteSpace($ProviderName)) {
                    $filterHashtable["ProviderName"] = $ProviderName
                }
                
                # 添加事件级别过滤（如果提供）
                if (![string]::IsNullOrWhiteSpace($Level)) {
                    $levelInt = 0
                    if ([int]::TryParse($Level, [ref]$levelInt)) {
                        $filterHashtable["Level"] = $levelInt
                    }
                }
                
                # 获取总日志数
                $totalEvents = Get-WinEvent -FilterHashtable $filterHashtable -ErrorAction SilentlyContinue
                $totalEventCount = if ($totalEvents) { $totalEvents.Count } else { 0 }
            } catch {
                # 忽略错误，使用0作为默认值
                $totalEventCount = 0
            }
        }
        
        if (-not $Silent) {
            # 显示获取总日志数的进度
            Write-CustomProgress -Activity "正在读取完整 $LogType 日志" -Status "已获取总日志数: $totalEventCount" -PercentComplete 40
            # 强制刷新输出缓冲区
            [System.Console]::Out.Flush()
        }
    } else {
        # 使用传入的总日志数，显示确认信息
        if (-not $Silent) {
            Write-CustomProgress -Activity "正在读取完整 $LogType 日志" -Status "使用已获取的总日志数: $totalEventCount" -PercentComplete 40
            # 强制刷新输出缓冲区
            [System.Console]::Out.Flush()
        }
    }
    
    # 直接获取所有事件，不使用分块处理
    $all = New-Object System.Collections.Generic.List[object]
    $errorCount = 0
    
    try {
        # 构建过滤条件
        $filterHashtable = @{ LogName = $LogType; StartTime = $StartTime; EndTime = $EndTime }
        
        # 添加事件ID过滤（如果提供）
        if (![string]::IsNullOrWhiteSpace($EventId)) {
            $eventIds = $EventId -split ',' | ForEach-Object { $_.Trim() }
            if ($eventIds.Count -gt 0) {
                $filterHashtable["Id"] = $eventIds
            }
        }
        
        # 添加事件提供程序过滤（如果提供）
        if (![string]::IsNullOrWhiteSpace($ProviderName)) {
            $filterHashtable["ProviderName"] = $ProviderName
        }
        
        # 添加事件级别过滤（如果提供）
        if (![string]::IsNullOrWhiteSpace($Level)) {
            $levelInt = 0
            if ([int]::TryParse($Level, [ref]$levelInt)) {
                $filterHashtable["Level"] = $levelInt
            }
        }
        
        # 直接获取所有事件
        if (-not $Silent) {
            Write-CustomProgress -Activity "正在读取完整 $LogType 日志" -Status "正在直接获取所有事件..." -PercentComplete 60
            # 强制刷新输出缓冲区
            [System.Console]::Out.Flush()
        }
        
        # 尝试使用FilterHashtable获取事件
        $events = Get-WinEvent -FilterHashtable $filterHashtable -ErrorAction SilentlyContinue
        
        # 如果FilterHashtable失败，尝试使用FilterXPath
        if (!$events) {
            # 构建XPath查询
            $xpathQuery = "*[System[TimeCreated[@SystemTime >= '$($StartTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.000Z'))' and @SystemTime <= '$($EndTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.999Z'))']]"
            
            # 添加事件ID过滤
            if (![string]::IsNullOrWhiteSpace($EventId)) {
                $eventIds = $EventId -split ',' | ForEach-Object { $_.Trim() }
                if ($eventIds.Count -gt 0) {
                    $idFilter = $eventIds -join ' or ' 
                    $xpathQuery = "*[System[($idFilter) and TimeCreated[@SystemTime >= '$($StartTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.000Z'))' and @SystemTime <= '$($EndTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.999Z'))']]"
                }
            }
            
            $events = Get-WinEvent -LogName $LogType -FilterXPath $xpathQuery -ErrorAction SilentlyContinue
        }
        
        # 处理获取到的事件
        if ($events) {
            # 确保结果是数组
            if ($events -is [array]) {
                # 过滤掉$null元素
                $validEvents = $events | Where-Object { $_ -ne $null }
                if ($validEvents.Count -gt 0) {
                    $all.AddRange($validEvents)
                }
            } else {
                # 单个事件的情况
                if ($events -ne $null) {
                    $all.Add($events)
                }
            }
        }
    } catch {
        $errorCount++
        if (-not $Silent) {
            Write-Host "`n读取事件时出错: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # 确保最后显示正确的进度
    if (-not $Silent) {
        # 基于实际采集的事件数计算最终进度
        if ($totalEventCount -gt 0) {
            $finalPercent = [Math]::Min(100, [Math]::Round(($all.Count / $totalEventCount) * 100))
            Write-CustomProgress -Activity "正在读取完整 $LogType 日志" -Status "已采集 $($all.Count)/$totalEventCount 条事件 | 读取完成" -PercentComplete $finalPercent
        } else {
            Write-CustomProgress -Activity "正在读取完整 $LogType 日志" -Status "已采集 $($all.Count) 条事件 | 读取完成" -PercentComplete 100
        }
        # 强制刷新输出缓冲区
        [System.Console]::Out.Flush()
    }
    
    # 将结果存入缓存
    if (-not $Silent) {
        Set-CachedLogData -CacheKey $cacheKey -Data $all
    } else {
        # 静默模式下直接存入缓存，不显示输出
        $script:logCache[$cacheKey] = @{
            Time = Get-Date
            Data = $all
        }
        # 根据内存使用情况限制缓存大小
        $optimalCacheSize = Get-OptimalCacheSize
        if ($script:logCache.Count -gt $optimalCacheSize) {
            # 移除最旧的缓存项
            $oldestKey = $script:logCache.GetEnumerator() | Sort-Object { $_.Value.Time } | Select-Object -First 1 -ExpandProperty Key
            $script:logCache.Remove($oldestKey)
        }
    }
    
    # 完成后添加换行
    if (-not $Silent) {
        Write-Host "`n【完整 $LogType 日志读取完成】共采集 $($all.Count) 条事件" -ForegroundColor Green
        
        if ($errorCount -gt 0) {
            Write-Host "`n读取过程中遇到 $errorCount 个错误，但已尽力收集所有可用事件。" -ForegroundColor Yellow
        }
    }
    
    return $all
}

function New-LogReport {
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
        Write-Host "`n⚠️ 未发现有效事件，无法生成报告。" -ForegroundColor Yellow
        return
    }
    
    # 过滤掉无效事件 - 接受所有有必要属性的事件，不仅限于 EventLogRecord 类型
    $validEvents = $Events | Where-Object { 
        $_ -ne $null -and 
        $_.Id -ne $null -and 
        $_.ProviderName -ne $null 
    }
    if ($validEvents.Count -eq 0) {
        Write-Host "`n⚠️ 未发现有效事件，无法生成报告。" -ForegroundColor Yellow
        return
    }
    
    # 使用过滤后的有效事件
    $Events = $validEvents

    # 优化：预计算系统信息，减少重复调用
    $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption
    $computerName = $env:COMPUTERNAME
    $exportTime = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    
    # 优化：获取时间范围
    $firstEvent = $Events | Sort-Object TimeCreated | Select-Object -First 1
    $lastEvent = $Events | Sort-Object TimeCreated | Select-Object -Last 1
    $firstEventTime = if ($firstEvent.TimeCreated) { $firstEvent.TimeCreated } else { Get-Date }
    $lastEventTime = if ($lastEvent.TimeCreated) { $lastEvent.TimeCreated } else { Get-Date }
    $timeRange = "$($firstEventTime.ToString('yyyy-MM-dd HH:mm')) 至 $($lastEventTime.ToString('yyyy-MM-dd HH:mm'))"
    
    # 执行高级模式分析
    $patternAnalysis = New-AdvancedLogPatternAnalysis -Events $Events
    
    # 优化：使用StringBuilder构建报告内容，提高性能
    $reportContent = New-Object System.Text.StringBuilder
    $null = $reportContent.AppendLine($ReportTitle)
    $null = $reportContent.AppendLine("计算机名称 : $computerName")
    $null = $reportContent.AppendLine("操作系统 : $osInfo")
    $null = $reportContent.AppendLine("导出时间 : $exportTime")
    $null = $reportContent.AppendLine("工具版本 : V11.5")
    $null = $reportContent.AppendLine("==================================================")
    $null = $reportContent.AppendLine("时间范围 : $timeRange")
    $null = $reportContent.AppendLine("总事件数 : $($Events.Count)")
    $null = $reportContent.AppendLine()
    $null = $reportContent.AppendLine("【高级模式分析摘要】")
    $null = $reportContent.AppendLine("重复模式 : $($patternAnalysis.Summary.RepetitivePatterns)")
    $null = $reportContent.AppendLine("时间模式 : $($patternAnalysis.Summary.TimePatterns)")
    $null = $reportContent.AppendLine("检测到的异常 : $($patternAnalysis.Summary.Anomalies)")
    $null = $reportContent.AppendLine()
    $null = $reportContent.AppendLine("【事件级别摘要】")

    # 优化：使用泛型字典提高性能
    $levelCounts = New-Object 'System.Collections.Generic.Dictionary[string, int]'
    $errorCount = 0
    $warningCount = 0
    $criticalCount = 0
    $idCounts = New-Object 'System.Collections.Generic.Dictionary[int, int]'
    $providerCounts = New-Object 'System.Collections.Generic.Dictionary[string, int]'

    # 预定义级别名称映射，避免重复计算
    $levelNames = @{
        0 = "信息"
        1 = "严重"
        2 = "错误"
        3 = "警告"
        4 = "详细"
        5 = "始终记录"
    }

    # 优化：批量处理事件数据
    $totalEvents = $Events.Count
    $currentEvent = 0
    $updateInterval = [Math]::Max(1, [Math]::Min(100, $totalEvents / 10))
    
    foreach ($e in $Events) {
        $currentEvent++
        
        # 每处理一定数量的事件更新一次进度
        if ($currentEvent % $updateInterval -eq 0) {
            $percent = [Math]::Min(100, [Math]::Round(($currentEvent / $totalEvents) * 100))
            Write-CustomProgress -Activity "生成报告" -Status "正在分析事件数据 $currentEvent/$totalEvents" -PercentComplete $percent -CurrentItem $currentEvent -TotalItems $totalEvents -CurrentTask "分析事件 $currentEvent"
        }
        
        $level = if ($null -eq $e.Level) { 0 } else { [int]$e.Level }
        if ($levelNames.ContainsKey($level)) {
            $levelName = $levelNames[$level]
        }
        else {
            $levelName = "未知(Level=$level)"
        }
        
        # 使用TryAdd方法提高性能
        if (!$levelCounts.ContainsKey($levelName)) {
            $levelCounts[$levelName] = 0
        }
        $levelCounts[$levelName]++
        
        $eventId = if ($e.Id) { $e.Id } else { 0 }
        if (!$idCounts.ContainsKey($eventId)) {
            $idCounts[$eventId] = 0
        }
        $idCounts[$eventId]++
        
        $eventProvider = if ($e.ProviderName) { $e.ProviderName } else { '<无提供程序信息>' }
        if (!$providerCounts.ContainsKey($eventProvider)) {
            $providerCounts[$eventProvider] = 0
        }
        $providerCounts[$eventProvider]++

        # 统计错误、警告和严重事件
        switch ($level) {
            1 { $criticalCount++ }
            2 { $errorCount++ }
            3 { $warningCount++ }
        }
    }

    # 优化：使用StringBuilder添加统计信息
    $levelCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        $null = $reportContent.AppendLine("  $($_.Key) : $($_.Value) 条")
    }

    $null = $reportContent.AppendLine()
    $null = $reportContent.AppendLine("【高频事件 ID（Top 10）】")
    $idCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
        $null = $reportContent.AppendLine("  事件ID $($_.Key) : $($_.Value) 条")
    }

    $null = $reportContent.AppendLine()
    $null = $reportContent.AppendLine("【主要事件提供程序（Top 10）】")
    $providerCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
        $null = $reportContent.AppendLine("  $($_.Key) : $($_.Value) 条")
    }

    # === 系统健康评估 ===
    # 计算健康评分
    $totalEvents = $Events.Count
    $severeCount = $criticalCount + $errorCount
    $totalIssues = $criticalCount * 3 + $errorCount * 2 + $warningCount
    
    # 基于事件数量和严重程度计算健康评分
    if ($totalEvents -gt 0) {
        $healthScore = [Math]::Max(0, 100 - ($totalIssues * 100 / $totalEvents))
    } else {
        $healthScore = 100
    }
    
    # 健康等级评估
    if ($healthScore -ge 90) {
        $healthLevel = "优秀"
        $healthStatus = "系统状态：优秀 —— 运行稳定，无明显异常！"
        $consoleColor = 'Green'
    } elseif ($healthScore -ge 70) {
        $healthLevel = "良好"
        $healthStatus = "系统状态：良好 —— 存在少量异常，建议定期检查！"
        $consoleColor = 'Yellow'
    } elseif ($healthScore -ge 50) {
        $healthLevel = "一般"
        $healthStatus = "系统状态：一般 —— 存在较多异常，需要关注！"
        $consoleColor = 'Yellow'
    } else {
        $healthLevel = "较差"
        $healthStatus = "系统状态：较差 —— 存在大量异常，建议立即检查！"
        $consoleColor = 'Red'
    }
    
    if ($errorCount -gt 0 -or $warningCount -gt 0 -or $criticalCount -gt 0) {
        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine("【发现问题】")
        $null = $reportContent.AppendLine("错误事件 : $errorCount 条")
        $null = $reportContent.AppendLine("警告事件 : $warningCount 条")
        $null = $reportContent.AppendLine("严重事件 : $criticalCount 条")
        $null = $reportContent.AppendLine("健康评分 : $([Math]::Round($healthScore, 1))/100")
        $null = $reportContent.AppendLine("健康等级 : $healthLevel")

        if ($errorCount -gt 0) {
            $null = $reportContent.AppendLine()
            $null = $reportContent.AppendLine()
            $null = $reportContent.AppendLine("【最近 10 条错误事件】")
            $recentErrors = $Events | Where-Object {
                $lvl = if ($null -eq $_.Level) { 0 } else { [int]$_.Level }
                $lvl -eq 2
            } | Sort-Object TimeCreated -Descending | Select-Object -First 10

            foreach ($e in $recentErrors) {
                $msg = if ($e.Message) { 
                    ($e.Message -replace '[\r\n\t\|" ]', ' ').Trim()
                }
                else { '<无消息内容>' }
                if ($msg.Length -gt 512) { $msg = $msg.Substring(0, 502) + ' [已截断]' }
                $null = $reportContent.AppendLine("时间: $($e.TimeCreated)")
                $null = $reportContent.AppendLine("事件ID: $($e.Id)")
                $null = $reportContent.AppendLine("来源: $($e.ProviderName)")
                $null = $reportContent.AppendLine("描述: $msg")
                $null = $reportContent.AppendLine()
            }
        }

        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine($healthStatus)
        
        # 添加知识库解决方案部分
        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine("【知识库解决方案】")
        $null = $reportContent.AppendLine("基于知识库的智能分析和解决方案推荐：")
        
        # 收集高危事件的知识库解决方案（只处理严重、错误、警告事件）
        $allSolutions = @{}
        $highRiskEvents = $Events | Where-Object {
            $level = if ($null -eq $_.Level) { 0 } else { [int]$_.Level }
            $level -in 1, 2, 3  # 严重、错误、警告
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
        
        # 按优先级排序并显示前10个解决方案
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
                $null = $reportContent.AppendLine("$i. 事件ID: $($item.EventId), 来源: $($item.ProviderName)")
                $null = $reportContent.AppendLine("   ==================================================")
                foreach ($sol in $item.Solutions) {
                    # 获取本地化的解决方案
                    $localizedSol = Get-LocalizedKnowledgeBaseSolution -Solution $sol
                    
                    $null = $reportContent.AppendLine("   📋 问题: $($localizedSol.name)")
                    $null = $reportContent.AppendLine("   ⚠️ 严重程度: $($localizedSol.severity)")
                    $null = $reportContent.AppendLine("   🎯 优先级: $($localizedSol.priority)")
                    $null = $reportContent.AppendLine("   🔍 原因:")
                    if ($localizedSol.causes -is [array]) {
                        foreach ($cause in $localizedSol.causes) {
                            $null = $reportContent.AppendLine("      - $cause")
                        }
                    } else {
                        $null = $reportContent.AppendLine("      - $($localizedSol.causes)")
                    }
                    $null = $reportContent.AppendLine("   ✅ 解决方案:")
                    if ($localizedSol.solutions -is [array]) {
                        foreach ($solution in $localizedSol.solutions) {
                            $null = $reportContent.AppendLine("      - $solution")
                        }
                    } else {
                        $null = $reportContent.AppendLine("      - $($localizedSol.solutions)")
                    }
                    $null = $reportContent.AppendLine("   📌 建议操作: $($localizedSol.recommended_action)")
                    
                    # 添加 commands 信息
                    if ($localizedSol.commands -and $localizedSol.commands.Count -gt 0) {
                        $null = $reportContent.AppendLine("   💻 建议执行命令:")
                        $commandIndex = 1
                        foreach ($command in $localizedSol.commands) {
                            $risk = if ($command.risk_level) { "($($command.risk_level))" } else { "" }
                            $elevation = if ($command.elevation_required) { "[需要管理员权限]" } else { "" }
                            $note = if ($command.note) { " - $($command.note)" } else { "" }
                            $null = $reportContent.AppendLine("      $commandIndex. $($command.name) $risk $elevation$note")
                            $null = $reportContent.AppendLine("        命令: $($command.command)")
                            # 添加分隔符，最后一个命令除外
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
            $null = $reportContent.AppendLine("未找到相关知识库解决方案。")
        }
    }
    else {
        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine()
        $null = $reportContent.AppendLine("【系统状态】健康 —— 未检测到错误、警告或严重事件！")
        $null = $reportContent.AppendLine("健康评分 : 100/100")
        $null = $reportContent.AppendLine("健康等级 : 优秀")
    }

    # 保存文件
    try {
        # 优化：使用通用函数生成安全的文件路径
        $txtPath = Get-SafeFilePath -BasePath $ExportPath -LogType $LogType -DatePart $DatePart -Extension "_摘要.txt"
        $reportContent.ToString() | Out-File -FilePath $txtPath -Encoding UTF8 -ErrorAction Stop
        Write-Host "`n摘要报告已保存至：$txtPath" -ForegroundColor Cyan

        $csvPath = Get-SafeFilePath -BasePath $ExportPath -LogType $LogType -DatePart $DatePart -Extension ".csv"
        
        # 优化：使用通用StreamWriter操作函数
        $csvSuccess = New-StreamWriterOperation -FilePath $csvPath -ScriptBlock {
            param($streamWriter)
            
            # 写入CSV头
            $streamWriter.WriteLine("TimeCreated,Id,LevelDisplayName,ProviderName,Message")
            
            # 并行处理事件数据
            $totalEvents = $Events.Count
            $currentEvent = 0
            $batchSize = 1000
            $updateInterval = 100
            
            # 根据系统性能确定并行度
            $optimalParallelism = Get-OptimalParallelism
            $threadCount = [Math]::Min($optimalParallelism, 8) # 限制最大线程数
            
            if ($totalEvents -gt 1000 -and $threadCount -gt 1) {
                # 对于大量事件使用并行处理
                Write-Host "`n使用并行处理加速CSV数据生成..." -ForegroundColor Cyan
                
                # 将事件分割成批次
                $eventBatches = Split-Array -InputArray $Events -Size 500
                $processedBatches = @()
                $batchCount = $eventBatches.Count
                $currentBatch = 0
                
                # 并行处理每个批次
                $totalProcessed = 0
                $batchSize = 500
                $startTime = Get-Date
                
                foreach ($batch in $eventBatches) {
                    $currentBatch++
                    $batchStartTime = Get-Date
                    
                    # 处理当前批次
                    $processedBatch = $batch | ForEach-Object {
                        $totalProcessed++
                        $percent = [Math]::Min(100, [Math]::Round(($totalProcessed / $totalEvents) * 100))
                        
                        # 每处理10个事件更新一次进度
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
                                    $estimatedRemaining = "预计剩余: $($timespan.ToString() -replace '\.[0-9]+', '')"
                                }
                            }
                            
                            $status = "正在生成CSV数据 $totalProcessed/$totalEvents"
                            Write-CustomProgress -Activity "保存报告" -Status $status -PercentComplete $percent -CurrentItem $totalProcessed -TotalItems $totalEvents -CurrentTask "处理事件 $totalProcessed"
                        }
                        
                        $e = $_
                        $timeCreated = if ($e.TimeCreated) { $e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss') } else { '<无时间信息>' }
                        $id = if ($e.Id) { $e.Id } else { 0 }
                        $levelDisplayName = if ($e.LevelDisplayName) { $e.LevelDisplayName } else { '<无级别信息>' }
                        $providerName = if ($e.ProviderName) { $e.ProviderName } else { '<无提供程序信息>' }
                        $message = if ($e.Message) { 
                            $msg = $e.Message -replace '[\r\n\t\|" ]', ' '
                            if ($msg.Length -gt 512) { $msg = $msg.Substring(0, 502) + ' [已截断]' }
                            $msg
                        } else { '<无消息内容>' }
                        
                        # 确保CSV格式正确
                        $message = $message -replace '"', '""'
                        '"' + $timeCreated + '","' + $id + '","' + $levelDisplayName + '","' + $providerName + '","' + $message + '"'
                    }
                    
                    # 写入处理后的批次
                    $streamWriter.Write(($processedBatch -join "`n"))
                    $streamWriter.WriteLine()
                }
            } else {
                # 对于少量事件使用串行处理
                $batch = @()
                foreach ($e in $Events) {
                    $currentEvent++
                    
                    # 每100条更新一次进度条
                    if ($currentEvent % $updateInterval -eq 0) {
                        $percent = [Math]::Min(100, [Math]::Round(($currentEvent / $totalEvents) * 100))
                        Write-CustomProgress -Activity "保存报告" -Status "正在写入CSV数据 $currentEvent/$totalEvents" -PercentComplete $percent -CurrentItem $currentEvent -TotalItems $totalEvents -CurrentTask "写入事件 $currentEvent"
                    }
                    
                    $timeCreated = if ($e.TimeCreated) { $e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss') } else { '<无时间信息>' }
                    $id = if ($e.Id) { $e.Id } else { 0 }
                    $levelDisplayName = if ($e.LevelDisplayName) { $e.LevelDisplayName } else { '<无级别信息>' }
                    $providerName = if ($e.ProviderName) { $e.ProviderName } else { '<无提供程序信息>' }
                    $message = if ($e.Message) { 
                        $msg = $e.Message -replace '[\r\n\t\|" ]', ' '
                        if ($msg.Length -gt 512) { $msg = $msg.Substring(0, 502) + ' [已截断]' }
                        $msg
                    } else { '<无消息内容>' }
                    
                    # 确保CSV格式正确
                    $message = $message -replace '"', '""'
                    $csvLine = '"' + $timeCreated + '","' + $id + '","' + $levelDisplayName + '","' + $providerName + '","' + $message + '"'
                    
                    # 添加到批处理
                    $batch += $csvLine
                    
                    # 批处理满时写入
                    if ($batch.Count -eq $batchSize) {
                        $streamWriter.Write(($batch -join "`n"))
                        $streamWriter.WriteLine()
                        $batch = @()
                    }
                }
                
                # 写入剩余数据
                if ($batch.Count -gt 0) {
                    $streamWriter.Write(($batch -join "`n"))
                    $streamWriter.WriteLine()
                }
            }
            
            # 显示CSV导出完成
            Write-CustomProgress -Activity "保存报告" -Status "CSV导出完成" -PercentComplete 100
            # 强制刷新输出缓冲区
            [System.Console]::Out.Flush()
        }
        
        if (-not $csvSuccess) {
            Write-Host "`nCSV导出失败" -ForegroundColor Red
        }
        

        
        # 导出为JSON格式
        $jsonPath = Get-SafeFilePath -BasePath $ExportPath -LogType $LogType -DatePart $DatePart -Extension ".json"
        
        # 优化：使用通用StreamWriter操作函数
        $jsonSuccess = New-StreamWriterOperation -FilePath $jsonPath -ScriptBlock {
            param($streamWriter)
            
            Write-CustomProgress -Activity "保存报告" -Status "正在生成JSON数据..." -PercentComplete 0
            $totalEvents = $Events.Count
            $currentEvent = 0
            $batchSize = 500
            $batch = @()
            $updateInterval = 100
            
            # 预计算常用值
            $computerName = $env:COMPUTERNAME.Replace('"', '\"')
            $exportTime = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            $timeRange = "$($firstEventTime.ToString('yyyy-MM-dd HH:mm')) to $($lastEventTime.ToString('yyyy-MM-dd HH:mm'))".Replace('"', '\"')
            
            # 写入JSON头部
            $streamWriter.WriteLine('{')
            $streamWriter.WriteLine('  "ReportTitle": "' + $ReportTitle.Replace('"', '\"') + '",')
            $streamWriter.WriteLine('  "ComputerName": "' + $computerName + '",')
            $streamWriter.WriteLine('  "OperatingSystem": "' + $osInfo.Replace('"', '\"') + '",')
            $streamWriter.WriteLine('  "ExportTime": "' + $exportTime + '",')
            $streamWriter.WriteLine('  "TimeRange": "' + $timeRange + '",')
            $streamWriter.WriteLine('  "TotalEvents": ' + $Events.Count + ',')
            $streamWriter.WriteLine('  "Events": [')
            
            # 批处理写入事件数据
            $firstEvent = $true
            foreach ($e in $Events) {
                $currentEvent++
                
                # 每100条更新一次进度条
                if ($currentEvent % $updateInterval -eq 0) {
                    $percent = [Math]::Min(100, [Math]::Ceiling(($currentEvent / $totalEvents) * 100))
                    Write-CustomProgress -Activity "保存报告" -Status "正在生成JSON数据 $currentEvent/$totalEvents" -PercentComplete $percent -CurrentItem $currentEvent -TotalItems $totalEvents -CurrentTask "处理事件 $currentEvent"
                }
                
                # 构建事件JSON
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
                if ($e.LevelDisplayName) { $levelDisplayNameValue = '"' + $e.LevelDisplayName.Replace('"', '\"') + '"' } else { $levelDisplayNameValue = 'null' }
                $eventJson += '"LevelDisplayName": ' + $levelDisplayNameValue + ','
                if ($e.ProviderName) { $providerNameValue = '"' + $e.ProviderName.Replace('"', '\"') + '"' } else { $providerNameValue = 'null' }
                $eventJson += '"ProviderName": ' + $providerNameValue + ','
                if ($e.Message) { $messageValue = '"' + ($e.Message -replace '[\r\n\t]', ' ' -replace '"', '\"') + '"' } else { $messageValue = 'null' }
                $eventJson += '"Message": ' + $messageValue
                $eventJson += '}'
                
                # 添加到批处理
                $batch += $eventJson
                
                # 批处理满时写入
                if ($batch.Count -eq $batchSize) {
                    $streamWriter.Write(($batch -join "`n"))
                    $batch = @()
                }
            }
            
            # 写入剩余数据
            if ($batch.Count -gt 0) {
                $streamWriter.Write(($batch -join "`n"))
            }
            
            # 写入JSON尾部
            $streamWriter.WriteLine()
            $streamWriter.WriteLine('  ]')
            $streamWriter.WriteLine('}')
            # 确保所有数据都写入文件
            $streamWriter.Flush()
            
            Write-CustomProgress -Activity "保存报告" -Status "JSON导出完成" -PercentComplete 100
            # 强制刷新输出缓冲区
            [System.Console]::Out.Flush()
        }
        
        if (-not $jsonSuccess) {
            Write-Host "`n导出JSON格式失败" -ForegroundColor Yellow
        }
        
        # 导出为XML格式
        $xmlPath = Get-SafeFilePath -BasePath $ExportPath -LogType $LogType -DatePart $DatePart -Extension ".xml"
        
        # 优化：使用通用StreamWriter操作函数
        $xmlSuccess = New-StreamWriterOperation -FilePath $xmlPath -ScriptBlock {
            param($streamWriter)
            
            Write-CustomProgress -Activity "保存报告" -Status "正在生成XML数据..." -PercentComplete 0
            $totalEvents = $Events.Count
            $currentEvent = 0
            $batchSize = 1000
            $batch = @()
            $updateInterval = 100
            
            # 预计算常用值
            $computerName = $env:COMPUTERNAME
            $exportTime = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            $timeRange = "$($firstEventTime.ToString('yyyy-MM-dd HH:mm')) to $($lastEventTime.ToString('yyyy-MM-dd HH:mm'))"
            
            # 写入XML头部
            $streamWriter.WriteLine('<?xml version="1.0" encoding="UTF-8"?>')
            $streamWriter.WriteLine('<LogReport>')
            $streamWriter.WriteLine('    <ReportTitle>' + $ReportTitle + '</ReportTitle>')
            $streamWriter.WriteLine('    <ComputerName>' + $computerName + '</ComputerName>')
            $streamWriter.WriteLine('    <OperatingSystem>' + $osInfo + '</OperatingSystem>')
            $streamWriter.WriteLine('    <ExportTime>' + $exportTime + '</ExportTime>')
            $streamWriter.WriteLine('    <TimeRange>' + $timeRange + '</TimeRange>')
            $streamWriter.WriteLine('    <TotalEvents>' + $Events.Count + '</TotalEvents>')
            $streamWriter.WriteLine('    <Events>')
            
            # 批处理写入事件数据
            foreach ($e in $Events) {
                $currentEvent++
                
                # 每100条更新一次进度条
                if ($currentEvent % $updateInterval -eq 0) {
                    $percent = [Math]::Min(100, [Math]::Round(($currentEvent / $totalEvents) * 100))
                    Write-CustomProgress -Activity "保存报告" -Status "正在生成XML数据 $currentEvent/$totalEvents" -PercentComplete $percent -CurrentItem $currentEvent -TotalItems $totalEvents -CurrentTask "处理事件 $currentEvent"
                }
                
                $timeCreated = if ($e.TimeCreated) { $e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
                $id = if ($e.Id) { $e.Id } else { 0 }
                $level = if ($e.Level) { $e.Level } else { 0 }
                $levelDisplayName = if ($e.LevelDisplayName) { $e.LevelDisplayName } else { '' }
                $providerName = if ($e.ProviderName) { $e.ProviderName } else { '' }
                $message = if ($e.Message) { $e.Message -replace '[\r\n\t]', ' ' } else { '' }
                
                # 构建事件XML
                $eventXml = ''
                $eventXml += '        <Event>'
                $eventXml += '            <TimeCreated>' + $timeCreated + '</TimeCreated>'
                $eventXml += '            <Id>' + $id + '</Id>'
                $eventXml += '            <Level>' + $level + '</Level>'
                $eventXml += '            <LevelDisplayName>' + $levelDisplayName + '</LevelDisplayName>'
                $eventXml += '            <ProviderName>' + $providerName + '</ProviderName>'
                $eventXml += '            <Message>' + $message + '</Message>'
                $eventXml += '        </Event>'
                
                # 添加到批处理
                $batch += $eventXml
                
                # 批处理满时写入
                if ($batch.Count -eq $batchSize) {
                    $streamWriter.Write(($batch -join "`n"))
                    $batch = @()
                }
            }
            
            # 写入剩余数据
            if ($batch.Count -gt 0) {
                $streamWriter.Write(($batch -join "`n"))
            }
            
            # 写入XML尾部
            $streamWriter.WriteLine()
            $streamWriter.WriteLine('    </Events>')
            $streamWriter.WriteLine('</LogReport>')
            
            # 直接输出XML导出完成消息
            Write-CustomProgress -Activity "保存报告" -Status "XML导出完成" -PercentComplete 100
            # 强制刷新输出缓冲区
            [System.Console]::Out.Flush()
            # 添加换行，确保后续输出不会覆盖进度条
            Write-Host ""
            # 强制刷新输出缓冲区
            [System.Console]::Out.Flush()
        }
        
        if (-not $xmlSuccess) {
            # 静默处理XML导出错误，避免显示多余的debug信息
        }
        
        # 强制刷新输出缓冲区
        [System.Console]::Out.Flush()
        # 添加换行，确保已导出消息单独占一行
        Write-Host "`n已导出:" -ForegroundColor Cyan
        Write-Host "  CSV: $csvPath" -ForegroundColor Cyan
        Write-Host "  JSON: $jsonPath" -ForegroundColor Cyan
        Write-Host "  XML: $xmlPath" -ForegroundColor Cyan
    }
    catch {
        Write-Host '保存失败: ' $($_.Exception.Message) -ForegroundColor Red
        Write-Host '请检查目录权限或磁盘空间。' -ForegroundColor Yellow
    }
}
#endregion

#region 主流程
try {
    # --- 权限预检 ---
    if (-not (Test-LogAccess -LogName $LogType)) {
        exit 1
    }

    # 静默模式检查
    if (-not $Silent) {
        Write-Host "/// AURORA 2026 VelociRaptor-GR 版权所有 ///" -ForegroundColor DarkCyan
        Write-Host "/// Windows 系统事件日志导出与智能分析工具 ///" -ForegroundColor DarkCyan
        Write-Host "///请稍后... 正在检测当前系统日期...///" -ForegroundColor Cyan
        $Today = Get-Date
        Write-Host "📅 检测完成! 当前日期为: $($Today.ToString('yyyy-MM-dd'))///" -ForegroundColor Cyan
        
        # 初始化缓存
        Write-Host "///正在检查缓存状态...///" -ForegroundColor Cyan
        $null = Initialize-Cache
        Write-Host "///缓存状态检查完成!///" -ForegroundColor Cyan
    } else {
        # 静默模式下也需要初始化缓存
        $null = Initialize-Cache
    }

    # --- 解析输出路径 ---
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        # 使用脚本所在目录的父目录（根目录）作为默认输出路径
        $outDir = [System.IO.Path]::Combine($PSScriptRoot, "..\UserLogs")
    } else {
        # 增强路径验证，防止路径注入攻击
        try {
            # 获取完整路径并验证
            $outDir = [System.IO.Path]::GetFullPath($OutputPath)
            
            # 确保路径不包含危险字符
            $invalidChars = [System.IO.Path]::GetInvalidPathChars()
            foreach ($char in $invalidChars) {
                if ($outDir.Contains($char)) {
                    throw "路径包含无效字符: $char"
                }
            }
            
            # 确保路径不是相对路径（已通过GetFullPath处理）
            # 确保路径长度在合理范围内
            if ($outDir.Length -gt 260) {
                throw "路径长度超过Windows限制（260字符）"
            }
        } catch {
            if (-not $Silent) {
                Write-Host "❌ 无效的输出路径: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "💡 建议：使用有效的本地路径。" -ForegroundColor Yellow
            }
            exit 1
        }
    }

    # 增强输出目录权限验证
    try {
        # 检查目录是否存在
        if (!(Test-Path $outDir)) {
            # 尝试创建目录，确保路径合法
            try {
                New-Item -Path $outDir -ItemType Directory -Force | Out-Null
                if (-not $Silent) {
                    Write-Host "📁 已创建输出目录：$outDir" -ForegroundColor Green
                }
            } catch {
                throw "无法创建输出目录: $($_.Exception.Message)"
            }
        }
        
        # 验证目录确实存在且是目录
        if (!(Test-Path $outDir -PathType Container)) {
            throw "指定的路径不是有效的目录"
        }
        
        # 测试写入权限
        $testFile = [System.IO.Path]::Combine($outDir, "test_write_permission.txt")
        try {
            "Test" | Out-File -FilePath $testFile -Encoding UTF8 -ErrorAction Stop
            # 测试读取权限
            $content = Get-Content -Path $testFile -ErrorAction Stop
            # 测试删除权限
            Remove-Item -Path $testFile -Force -ErrorAction Stop
        } catch {
            throw "无写入权限: $($_.Exception.Message)"
        }
        
        # 验证目录可执行权限
        if (-not (Test-Path $outDir -PathType Container)) {
            throw "无法访问目录"
        }
    }
    catch {
        if (-not $Silent) {
            Write-Host "❌ 无权限访问输出目录：$outDir" -ForegroundColor Red
            Write-Host "💡 建议：选择一个具有写入权限的目录。" -ForegroundColor Yellow
            Write-Host "📝 错误详情：$($_.Exception.Message)" -ForegroundColor Gray
        }
        exit 1
    }

    # --- 获取日期范围 ---
    if ($restoreMode -and $restoredSession) {
        # 会话恢复模式：从会话数据中重建 scopes
        if (-not $Silent) {
            Write-Host "`n🔄 正在从会话恢复数据中重建任务范围..." -ForegroundColor Cyan
        }
        
        # 尝试从会话数据中恢复 scopes
        if ($restoredSession.Data -and $restoredSession.Data.Scopes) {
            $tempScopes = $restoredSession.Data.Scopes
            
            # 处理 Scopes 可能是单个对象而不是数组的情况
            if ($tempScopes -is [System.Management.Automation.PSCustomObject] -or $tempScopes -is [hashtable]) {
                $scopes = @($tempScopes)
            } else {
                $scopes = $tempScopes
            }
            
            # 确保 scopes 是数组
            if (-not $scopes -or $scopes.Count -eq 0) {
                $scopes = @($restoredSession.Data.Scopes)
            }
            
            # 处理特殊的日期格式 \/Date(...)\/
            for ($i = 0; $i -lt $scopes.Count; $i++) {
                $scopeItem = $scopes[$i]
                
                # 转换 StartTime
                if ($scopeItem.StartTime -match '\\/Date\((\d+)\)\\/') {
                    $timestamp = [long]$matches[1]
                    $scopes[$i].StartTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                }
                
                # 转换 EndTime
                if ($scopeItem.EndTime -match '\\/Date\((\d+)\)\\/') {
                    $timestamp = [long]$matches[1]
                    $scopes[$i].EndTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                }
            }
            
            if (-not $Silent) {
                Write-Host "   ✅ 成功恢复 $($scopes.Count) 个日志任务范围" -ForegroundColor Green
            }
        } else {
            # 备用方案：如果会话数据中没有 scopes，则使用默认值
            if (-not $Silent) {
                Write-Host "   ⚠️ 会话数据中没有找到任务范围，将使用默认值" -ForegroundColor Yellow
            }
            $today = (Get-Date).Date
            # 核心修复：确保 LogType 不为空，使用参数默认值
            $defaultLogType = if ([string]::IsNullOrWhiteSpace($LogType)) { "System" } else { $LogType }
            $scopes = @( @{ 
                StartTime   = $today
                EndTime     = $today.AddDays(1).AddTicks(-1)
                DatePart    = $today.ToString('yyyyMMdd')
                ReportTitle = "$defaultLogType 日志日报 - $($today.ToString('yyyy-MM-dd'))"
                LogType     = $defaultLogType
                EventId     = $EventId
                ProviderName = $ProviderName
                Level       = $Level
            } )
        }
    }
    elseif ($Silent) {
        # 静默模式：优先使用命令行参数（只支持单个日志类型）
        if ($StartTime -and $EndTime) {
            # 使用命令行传递的日期参数
            $startDate = $StartTime
            $endDate = $EndTime.AddDays(1).AddTicks(-1)  # 设置为当天的最后一刻
            $datePart = "$($startDate.ToString('yyyyMMdd'))_至_$($endDate.ToString('yyyyMMdd'))"
            $reportTitle = "$LogType 日志报告 - $($startDate.ToString('yyyy-MM-dd')) 至 $($endDate.ToString('yyyy-MM-dd'))"
        } else {
            # 使用默认值（当前日期）
            $today = (Get-Date).Date
            $startDate = $today
            $endDate = $today.AddDays(1).AddTicks(-1)
            $datePart = $today.ToString('yyyyMMdd')
            $reportTitle = "$LogType 日志日报 - $($today.ToString('yyyy-MM-dd'))"
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
        } )
    } else {
        # 交互式模式：获取用户输入（支持多个日志类型）
        $scopes = Get-UserDateScope -DefaultLogType $LogType
        
        # 从命令行参数覆盖过滤条件（应用到所有 scope）
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
        
        # 保存进度：日志类型和日期范围已配置（保存第一个 scope）
        Save-ProgressSafe -Checkpoint "LogTypeSelected" -AdditionalData @{
            LogType = $scopes[0].LogType
            StartTime = $scopes[0].StartTime
            EndTime = $scopes[0].EndTime
            Scopes = $scopes  # 保存完整的 scopes 数组到会话数据中
        }
        Save-ProgressSafe -Checkpoint "DateRangeConfigured"
        
        # 按需提权检查：检查所有选择的日志类型是否需要管理员权限
        $needAdmin = $false
        foreach ($s in $scopes) {
            if ($s.LogType -in $script:AdminRequiredLogTypes) {
                $needAdmin = $true
                break
            }
        }
        
        if ($needAdmin) {
            $elevationResult = Invoke-ElevationCheck -LogType $scopes[0].LogType -FeatureName "日志导出"
            if (-not $elevationResult) {
                Write-Host "`n💡 提示：您可以选择 System 或 Application 日志类型继续使用普通模式。" -ForegroundColor Yellow
                Write-Host "   正在退出当前操作..." -ForegroundColor Gray
                exit 0
            }
        }
    }

    # === 【核心修复】全面验证和修复 scopes 变量 ===
    # 确保 scopes 变量有效，无论是否是恢复模式
    if (-not $scopes -or $scopes.Count -eq 0) {
        Write-Host "`n⚠️ scopes 变量无效，正在使用默认值..." -ForegroundColor Yellow
        $today = (Get-Date).Date
        $defaultLogType = if ([string]::IsNullOrWhiteSpace($LogType)) { "System" } else { $LogType }
        $scopes = @(@{
            StartTime = $today
            EndTime = $today.AddDays(1).AddTicks(-1)
            LogType = $defaultLogType
            DatePart = $today.ToString('yyyyMMdd')
            ReportTitle = "$defaultLogType 日志日报 - $($today.ToString('yyyy-MM-dd'))"
        })
    } else {
        # 处理 Scopes 可能是单个对象而不是数组的情况
        if ($scopes -is [System.Management.Automation.PSCustomObject] -or $scopes -is [hashtable]) {
            Write-Host "`n⚠️ 检测到 scopes 是单个对象，正在转换为数组..." -ForegroundColor Yellow
            $scopes = @($scopes)
        }
        
        # 确保 scopes 是数组
        if (-not $scopes -or $scopes.Count -eq 0) {
            Write-Host "`n⚠️ scopes 仍然无效，正在使用默认值..." -ForegroundColor Yellow
            $today = (Get-Date).Date
            $defaultLogType = if ([string]::IsNullOrWhiteSpace($LogType)) { "System" } else { $LogType }
            $scopes = @(@{
                StartTime = $today
                EndTime = $today.AddDays(1).AddTicks(-1)
                LogType = $defaultLogType
                DatePart = $today.ToString('yyyyMMdd')
                ReportTitle = "$defaultLogType 日志日报 - $($today.ToString('yyyy-MM-dd'))"
            })
        } else {
            # 处理特殊的日期格式 \/Date(...)\/
            for ($i = 0; $i -lt $scopes.Count; $i++) {
                $scopeItem = $scopes[$i]
                
                # 转换 StartTime
                if ($scopeItem.StartTime -match '\\/Date\((\d+)\)\\/') {
                    $timestamp = [long]$matches[1]
                    $scopes[$i].StartTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                    Write-Host "`n⚠️ 已转换 scopes[$i] 的 StartTime" -ForegroundColor Yellow
                }
                
                # 转换 EndTime
                if ($scopeItem.EndTime -match '\\/Date\((\d+)\)\\/') {
                    $timestamp = [long]$matches[1]
                    $scopes[$i].EndTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).LocalDateTime
                    Write-Host "⚠️ 已转换 scopes[$i] 的 EndTime" -ForegroundColor Yellow
                }
                
                # 确保 StartTime 和 EndTime 不是 null
                if (-not $scopes[$i].StartTime -or -not $scopes[$i].EndTime) {
                    $today = (Get-Date).Date
                    if (-not $scopes[$i].StartTime) {
                        $scopes[$i].StartTime = $today
                        Write-Host "⚠️ scopes[$i] 的 StartTime 为 null，已设置为今天" -ForegroundColor Yellow
                    }
                    if (-not $scopes[$i].EndTime) {
                        $scopes[$i].EndTime = $today.AddDays(1).AddTicks(-1)
                        Write-Host "⚠️ scopes[$i] 的 EndTime 为 null，已设置为今天结束" -ForegroundColor Yellow
                    }
                }
                
                # 确保 LogType 有值
                if ([string]::IsNullOrWhiteSpace($scopes[$i].LogType)) {
                    $scopes[$i].LogType = if ([string]::IsNullOrWhiteSpace($LogType)) { "System" } else { $LogType }
                    Write-Host "⚠️ scopes[$i] 的 LogType 为空，已设置为默认值" -ForegroundColor Yellow
                }
            }
        }
    }
    
    Write-Host "`n✅ scopes 验证完成，共 $($scopes.Count) 个范围" -ForegroundColor Green

    # === 新逻辑：先评估系统性能，再扫描高危事件 ===
    if (-not $Silent) {
        Write-Host "`n【正在评估系统性能...】" -ForegroundColor Cyan
    }
    # ====== 新增：同步性能评估状态给 GUI ======
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        $global:syncHash.CurrentActivity = "1/4 环境准备与初始化"
        $global:syncHash.CurrentStatus = "正在评估系统性能与硬件资源..."
    }
    # 评估系统性能并计算最佳分块大小
    $performanceScore = Get-SystemPerformanceScore
    $optimalChunkSize = Get-OptimalChunkSize -PerformanceScore $performanceScore -LogType $scopes[0].LogType
    
    # 获取资源优化策略
    $logScanningStrategy = Get-ResourceOptimizedStrategy -PerformanceScore $performanceScore -TaskType "LogScanning"
    $reportGenerationStrategy = Get-ResourceOptimizedStrategy -PerformanceScore $performanceScore -TaskType "ReportGeneration"
    
    # 获取智能缓存策略
    $cacheStrategy = Get-IntelligentCacheStrategy -PerformanceScore $performanceScore -DataSizeKB 10000
    
    # 获取文件操作优化参数
    $fileOperationParams = Optimize-FileOperations -PerformanceScore $performanceScore
    
    if (-not $Silent) {
        Write-Host "`n【资源优化策略】" -ForegroundColor Cyan
        Write-Host "性能等级: $($logScanningStrategy.PerformanceLevel)" -ForegroundColor Green
        Write-Host "日志扫描并行度: $($logScanningStrategy.Strategy.Parallelism)" -ForegroundColor Green
        Write-Host "报告生成并行度: $($reportGenerationStrategy.Strategy.Parallelism)" -ForegroundColor Green
        Write-Host "缓存压缩: $($cacheStrategy.Compression)" -ForegroundColor Green
        Write-Host "I/O 缓冲区大小：$($fileOperationParams.BufferSize) bytes" -ForegroundColor Green
    }
    
    # 保存进度：性能评估完成
    Save-ProgressSafe -Checkpoint "PerformanceAssessed" -AdditionalData @{
        PerformanceScore = $performanceScore
        ChunkSize = $optimalChunkSize
    }
    
    # 保存选择的选项（只在第一个 scope 询问，后续 scope 使用相同选择）
    # === 【断点续传修复】：不要重置这些变量如果已经从会话中恢复
    if ($restoreMode -and $exportChoice) {
        if (-not $Silent) {
            Write-Host "`n💡 使用已恢复的导出选择：$exportChoice" -ForegroundColor Cyan
        }
    } else {
        $exportChoice = $null  # "HighRisk" 或 "Full" 或 "Skip"
    }
    if (-not ($restoreMode -and $trendAnalysisChoice)) {
        $trendAnalysisChoice = $null  # "Y" 或 "N"
    }
    $useCacheChoices = @{}  # 记录每个日志类型的缓存选择

    # === 循环处理每个 scope ===
    for ($scopeIndex = 0; $scopeIndex -lt $scopes.Count; $scopeIndex++) {
        $scope = $scopes[$scopeIndex]
        
        # === 【断点续传修复】高危事件扫描 ===
        $skipHighRiskScan = $false
        
        if ($restoreMode -and $restoredSession.Progress -ge 60) {
            Write-Host "`n✅ 跳过：高危事件扫描已完成（恢复进度 $($restoredSession.Progress)% >= 60%）" -ForegroundColor Green
            
            # 从恢复的会话中还原统计数据
            if ($restoredSession.Data.HighRiskEventCount) {
                $totalHigh = $restoredSession.Data.HighRiskEventCount
                $critical = $restoredSession.Data.CriticalEvents
                $errors = $restoredSession.Data.ErrorEvents
                $warnings = $restoredSession.Data.WarningEvents
                $totalEventCount = $restoredSession.Data.TotalEventCount
                
                Write-Host "   从会话恢复：$totalHigh 条高危事件（严重：$critical, 错误：$errors, 警告：$warnings）" -ForegroundColor Cyan
            }
            
            $skipHighRiskScan = $true
        }
        
        if (-not $skipHighRiskScan) {
        # === 【断点续传修复：高危事件扫描开始】===
        
        # 计算动态进度（45% - 70%，在处理多个日志时平滑过渡）
        if ($scopes.Count -gt 1) {
            $baseProgress = 45
            $targetProgress = 70
            $singleStep = ($targetProgress - $baseProgress) / $scopes.Count
            $currentProgress = [Math]::Round($baseProgress + ($singleStep * $scopeIndex))
            Save-ProgressSafe -Checkpoint "ProcessingStarted" -CustomProgress $currentProgress -CustomStage "正在处理 $($scope.LogType) ($($scopeIndex + 1)/$($scopes.Count))"
        }
        
        if (-not $Silent) {
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "  [$($scopeIndex + 1)/$($scopes.Count)] 正在处理：$($scope.LogType)" -ForegroundColor White
            Write-Host "========================================" -ForegroundColor Cyan
        }

        # 检查是否有匹配的缓存
        $cacheMatch = Test-CacheMatch -LogType $scope.LogType -StartTime $scope.StartTime -EndTime $scope.EndTime -EventId $scope.EventId -ProviderName $scope.ProviderName -Level $scope.Level
        
        if ($cacheMatch.Match) {
            # 检查是否已经有针对该日志类型的缓存选择
            if ($useCacheChoices.ContainsKey($scope.LogType)) {
                $useCache = $useCacheChoices[$scope.LogType]
            } else {
                # 首次询问用户
                $useCache = Get-CacheUsageChoice -CacheItem $cacheMatch.CacheItem
                $useCacheChoices[$scope.LogType] = $useCache
            }
            
            if ($useCache) {
                # 使用缓存数据
                $highRiskEvents = $cacheMatch.CacheItem.Data
                Write-Host "`n【使用缓存数据】" -ForegroundColor Cyan
            } else {
                # 实时扫描
                if (-not $Silent) {
                    Write-Host "`n【正在扫描所选范围内的高危事件...】" -ForegroundColor Cyan
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
            # 无匹配缓存，实时扫描
            if (-not $Silent) {
                Write-Host "`n【无匹配缓存，正在扫描所选范围内的高危事件...】" -ForegroundColor Cyan
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

        # 获取总日志数（从缓存中获取，避免重复计算）
        $totalEventCount = 0
        $totalEventsCacheKey = Get-CacheKey -LogType "$($scope.LogType)-Full" -StartTime $scope.StartTime -EndTime $scope.EndTime -EventId $scope.EventId -ProviderName $scope.ProviderName -Level $scope.Level
        $totalEventsData = Get-CachedLogData -CacheKey $totalEventsCacheKey -Silent $true
        if ($totalEventsData) {
            $totalEventCount = $totalEventsData.Count
        } else {
            # 如果缓存不存在，尝试直接获取总日志数
            try {
                $totalEvents = Get-WinEvent -FilterHashtable @{ LogName = $scope.LogType; StartTime = $scope.StartTime; EndTime = $scope.EndTime } -ErrorAction SilentlyContinue
                $totalEventCount = if ($totalEvents) { $totalEvents.Count } else { 0 }
            } catch {
                $totalEventCount = 0
            }
        }

        # 显示扫描摘要
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

        # 保存进度：高危事件扫描完成
        $scanProgress = 60
        Save-ProgressSafe -Checkpoint "HighRiskScanComplete" -CustomProgress $scanProgress -CustomStage "高危事件扫描完成，发现 $totalHigh 条高危事件" -AdditionalData @{
            HighRiskEventCount = $totalHigh
            TotalEventCount = $totalEventCount
            CriticalEvents = $critical
            ErrorEvents = $errors
            WarningEvents = $warnings
        }
        }
        # === 【断点续传修复：高危事件扫描结束】===

        # === 【断点续传修复】系统健康评估 ===
        $skipHealthAssessment = $false
        
        if ($restoreMode -and $restoredSession.Progress -ge 70) {
            Write-Host "`n✅ 跳过：系统健康评估已完成（恢复进度 $($restoredSession.Progress)% >= 70%）" -ForegroundColor Green
            
            # 从恢复的会话中还原健康评估数据
            if ($restoredSession.Data.HealthScore) {
                $healthScore = $restoredSession.Data.HealthScore
                $healthLevel = $restoredSession.Data.HealthLevel
                $healthStatus = $restoredSession.Data.HealthStatus
                
                # 根据健康等级设置颜色
                if ($healthLevel -eq "优秀") {
                    $consoleColor = 'Green'
                } elseif ($healthLevel -eq "良好") {
                    $consoleColor = 'Yellow'
                } elseif ($healthLevel -eq "一般") {
                    $consoleColor = 'Yellow'
                } else {
                    $consoleColor = 'Red'
                }
                
                if (-not $Silent) {
                    Write-Host "   从会话恢复：健康评分 $([Math]::Round($healthScore, 1))/100 | 等级：$healthLevel" -ForegroundColor Cyan
                    Write-Host "   $healthStatus" -ForegroundColor $consoleColor
                }
            }
            
            $skipHealthAssessment = $true
        }
        
        if (-not $skipHealthAssessment) {
        # === 【断点续传修复：健康评估开始】===
        
        if (-not $Silent) {
            Write-Host "`n【扫描完成】" -ForegroundColor Green
            Write-Host "发现：$critical 条严重事件，$errors 条错误，$warnings 条警告（共 $totalHigh 条高危事件）" -ForegroundColor Yellow
            if ($totalEventCount -gt 0) {
                Write-Host "总日志数：$totalEventCount 条" -ForegroundColor Cyan
            }
            
            # === 系统健康评估 ===
            # 计算健康评分
            $totalIssues = $critical * 3 + $errors * 2 + $warnings
            $healthScore = 100
            if ($totalEventCount -gt 0) {
                $healthScore = [Math]::Max(0, 100 - ($totalIssues * 100 / $totalEventCount))
            }
            
            # 健康等级评估
            if ($healthScore -ge 90) {
                $healthLevel = "优秀"
                $healthStatus = "系统状态：优秀 —— 运行稳定，无明显异常！"
                $consoleColor = 'Green'
            } elseif ($healthScore -ge 70) {
                $healthLevel = "良好"
                $healthStatus = "系统状态：良好 —— 存在少量异常，建议定期检查！"
                $consoleColor = 'Yellow'
            } elseif ($healthScore -ge 50) {
                $healthLevel = "一般"
                $healthStatus = "系统状态：一般 —— 存在较多异常，需要关注！"
                $consoleColor = 'Yellow'
            } else {
                $healthLevel = "较差"
                $healthStatus = "系统状态：较差 —— 存在大量异常，建议立即检查！"
                $consoleColor = 'Red'
            }
            
            Write-Host "`n【系统健康评估】" -ForegroundColor Yellow
            Write-Host "错误: $errors | 警告: $warnings | 严重: $critical" -ForegroundColor Gray
            Write-Host "健康评分: $([Math]::Round($healthScore, 1))/100 | 健康等级: $healthLevel" -ForegroundColor Cyan
            Write-Host $healthStatus -ForegroundColor $consoleColor
        }
        
        # 保存进度：系统健康评估完成
        $healthProgress = 70
        Save-ProgressSafe -Checkpoint "HealthAssessmentComplete" -CustomProgress $healthProgress -CustomStage "系统健康评估完成" -AdditionalData @{
            HealthScore = $healthScore
            HealthLevel = $healthLevel
            HealthStatus = $healthStatus
        }
        }
        # === 【断点续传修复：健康评估结束】===

        # 决定导出什么
        if ($restoreMode -and $exportChoice) {
            # === 【断点续传修复】已恢复导出选择，直接使用 ===
            if (-not $Silent) {
                Write-Host "`n💡 使用已恢复的导出模式：$exportChoice" -ForegroundColor Cyan
            }
            
            # 设置对应的 reportMode
            if ($exportChoice -eq "HighRisk") {
                $reportMode = "仅高危事件"
            } else {
                $reportMode = "完整 $($scope.LogType) 日志"
            }
        } elseif ($Silent) {
            # 静默模式：根据参数选择导出范围
            if ($ExportScope -eq "HighRiskOnly") {
                $events = $highRiskEvents
                $reportMode = "仅高危事件"
            } else {
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
                $reportMode = "完整 $($scope.LogType) 日志"
            }
        } else {
            if ($null -eq $exportChoice) {
                # 第一次询问用户
                if ($totalHigh -eq 0) {
                    Write-Host "`n💡 未发现高危事件。" -ForegroundColor Cyan
                    
                    $maxRetries = 3
                    $retryCount = 0
                    $choice = $null
                    while ($retryCount -lt $maxRetries -and $null -eq $choice) {
                        $tempChoice = Get-AuroraInteraction -PromptMessage "`n按 Enter 导出完整日志，或输入 'skip' 取消"
                        if ([string]::IsNullOrWhiteSpace($tempChoice)) {
                            $exportChoice = "Full"
                            $choice = ""
                        } elseif ($tempChoice -like 'skip*') {
                            Write-Host "`n操作已被用户取消。" -ForegroundColor Gray
                            exit 0
                        } else {
                            $retryCount++
                            $remaining = $maxRetries - $retryCount
                            if ($remaining -gt 0) {
                                Write-Host "`n❌ 无效输入！请按 Enter 导出完整日志，或输入 'skip' 取消（剩余尝试次数：$remaining）" -ForegroundColor Red
                            } else {
                                Write-Host "`n❌ 输入错误次数过多，默认导出完整日志。" -ForegroundColor Red
                                $exportChoice = "Full"
                                $choice = ""
                            }
                        }
                    }
                }
                else {
                    $maxRetries = 3
                    $retryCount = 0
                    $choice = $null
                    while ($retryCount -lt $maxRetries -and $null -eq $choice) {
                        $tempChoice = Get-AuroraInteraction -PromptMessage "`n按 Enter 仅导出高危事件，或输入 '1' 导出完整日志"
                        if ([string]::IsNullOrWhiteSpace($tempChoice)) {
                            $exportChoice = "HighRisk"
                            $choice = ""
                        } elseif ($tempChoice -eq '1') {
                            $exportChoice = "Full"
                            $choice = "1"
                        } else {
                            $retryCount++
                            $remaining = $maxRetries - $retryCount
                            if ($remaining -gt 0) {
                                Write-Host "`n❌ 无效输入！请按 Enter 仅导出高危事件，或输入 '1' 导出完整日志（剩余尝试次数：$remaining）" -ForegroundColor Red
                            } else {
                                Write-Host "`n❌ 输入错误次数过多，默认仅导出高危事件。" -ForegroundColor Red
                                $exportChoice = "HighRisk"
                                $choice = ""
                            }
                        }
                    }
                }
            } else {
                if (-not $Silent) {
                    Write-Host "`n💡 使用之前选择的导出模式：$exportChoice" -ForegroundColor Cyan
                }
            }
        }
        
        # === 【断点续传修复】统一处理导出逻辑 ===
        # 只有在恢复模式且进度<80，或者非恢复模式时才执行
        if ((-not $restoreMode) -or ($restoredSession.Progress -lt 80)) {
            if ($exportChoice -eq "HighRisk") {
                $events = $highRiskEvents
                $reportMode = "仅高危事件"
                
                # 保存进度：已选择导出模式
                Save-ProgressSafe -Checkpoint "ExportModeSelected" -CustomProgress 75 -CustomStage "已选择导出模式：$reportMode" -AdditionalData @{
                    ExportChoice = $exportChoice
                    ReportMode = $reportMode
                }
            } else {
                # 保存进度：正在获取完整日志
                Save-ProgressSafe -Checkpoint "FetchingFullLog" -CustomProgress 75 -CustomStage "正在获取完整 $($scope.LogType) 日志" -AdditionalData @{
                    ExportChoice = $exportChoice
                    ReportMode = "完整 $($scope.LogType) 日志"
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
                $reportMode = "完整 $($scope.LogType) 日志"
                
                # 保存进度：已获取完整日志
                Save-ProgressSafe -Checkpoint "FullLogFetched" -CustomProgress 80 -CustomStage "已获取完整 $($scope.LogType) 日志，共 $($events.Count) 条事件" -AdditionalData @{
                    ExportChoice = $exportChoice
                    ReportMode = $reportMode
                    FullLogEventCount = $events.Count
                }
            }
        }

        # === 【断点续传修复】日志导出 ===
        $skipExport = $false
        
        if ($restoreMode -and $restoredSession.Progress -ge 85) {
            Write-Host "`n✅ 跳过：日志导出已完成（恢复进度 $($restoredSession.Progress)% >= 85%）" -ForegroundColor Green
            $skipExport = $true
        }
        
        if (-not $skipExport) {
        # === 【断点续传修复：日志导出开始】===
        
        if (-not $Silent) {
            Write-Host "`n【正在导出：$reportMode】" -ForegroundColor Cyan
        }

        # 保存进度：开始导出
        Save-ProgressSafe -Checkpoint "ExportStarted" -CustomProgress 85 -CustomStage "正在导出：$reportMode"

        # --- 生成报告 ---
        New-LogReport -Events $events -ReportTitle $scope.ReportTitle -DatePart $scope.DatePart -ExportPath $outDir -LogType $scope.LogType
        
        # 保存进度：日志导出完成（最后一个 scope 保存进度）
        if ($scopeIndex -eq $scopes.Count - 1) {
            Save-ProgressSafe -Checkpoint "ExportComplete" -AdditionalData @{
                ExportPath = $outDir
                EventCount = $events.Count
                ExportMode = $ExportMode
            }
        }
        }
        # === 【断点续传修复：日志导出结束】===

        # === 【断点续传修复】趋势分析 ===
        $skipTrendAnalysis = $false
        
        if ($restoreMode -and $restoredSession.Progress -ge 93) {
            Write-Host "`n✅ 跳过：趋势分析已完成（恢复进度 $($restoredSession.Progress)% >= 93%）" -ForegroundColor Green
            $skipTrendAnalysis = $true
        }
        
        if (-not $skipTrendAnalysis) {
        # === 【断点续传修复：趋势分析开始】===

        # --- 趋势分析选项 ---
        if ($Silent) {
            if ($TrendAnalysis) {
                $dateRangeDays = ($scope.EndTime - $scope.StartTime).Days + 1
                New-LogTrendAnalysis -ExportPath $outDir -LogType $scope.LogType -StartDate $scope.StartTime -EndDate $scope.EndTime -PerformanceScore $performanceScore -OptimalChunkSize $optimalChunkSize -EventId $scope.EventId -ProviderName $scope.ProviderName -Level $scope.Level
            }
        } else {
            if ($null -eq $trendAnalysisChoice) {
                $maxRetries = 3
                $retryCount = 0
                $choice = $null
                while ($retryCount -lt $maxRetries -and $null -eq $choice) {
                    $tempChoice = Get-AuroraInteraction -PromptMessage '是否进行日志趋势分析？(Y/N) [默认: N]'
                    if ([string]::IsNullOrWhiteSpace($tempChoice) -or $tempChoice -like 'N*') {
                        $trendAnalysisChoice = "N"
                        $choice = "N"
                    } elseif ($tempChoice -like 'Y*') {
                        $trendAnalysisChoice = "Y"
                        $choice = "Y"
                    } else {
                        $retryCount++
                        $remaining = $maxRetries - $retryCount
                        if ($remaining -gt 0) {
                            Write-Host '无效输入！请输入 Y 或 N（剩余尝试次数：' $remaining '）' -ForegroundColor Red
                        } else {
                            Write-Host '输入错误次数过多，跳过趋势分析。' -ForegroundColor Red
                            $trendAnalysisChoice = "N"
                            $choice = "N"
                        }
                    }
                }
            }
            
            if ($trendAnalysisChoice -like 'Y*') {
                $dateRangeDays = ($scope.EndTime - $scope.StartTime).Days + 1
                New-LogTrendAnalysis -ExportPath $outDir -LogType $scope.LogType -StartDate $scope.StartTime -EndDate $scope.EndTime -PerformanceScore $performanceScore -OptimalChunkSize $optimalChunkSize -EventId $scope.EventId -ProviderName $scope.ProviderName -Level $scope.Level
                
                # 保存进度：趋势分析完成（最后一个 scope 保存进度）
                if ($scopeIndex -eq $scopes.Count - 1) {
                    Save-ProgressSafe -Checkpoint "TrendAnalysisComplete"
                }
            }
        }
        }
        # === 【断点续传修复：趋势分析结束】===
    }
    
    # 保存进度：等待智能分析（所有 scope 处理完后保存）
    # 只有在非恢复模式，或者恢复模式且进度<95时才保存
    if ((-not $restoreMode) -or ($restoredSession.Progress -lt 95)) {
        Save-ProgressSafe -Checkpoint "SmartAnalysisPending" -AdditionalData @{
            ExportPath = $outDir
        }
    }

    # --- 打开文件夹 ---
    # 只有在非恢复模式，或者恢复模式且进度<90时才执行
    if ((-not $restoreMode) -or ($restoredSession.Progress -lt 90)) {
        $choice = "N" # 默认值
        if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
            # GUI 模式下，直接通过之前传入的参数或者不自动打开，避免阻塞
            $choice = if ($AutoOpen) { "Y" } else { "N" }
        } else {
            # 只有在纯控制台模式下，才允许使用 Read-Host
            if (-not $Silent) {
                 $choice = Read-Host "`n是否打开输出文件夹？(Y/N)"
            }
        }
        if ($AutoOpen -or $choice -like 'Y*') {
            if (Test-Path $outDir) {
                Start-Process explorer.exe -ArgumentList $outDir
                if (-not $Silent) {
                    Write-Host "📂 正在打开输出文件夹..." -ForegroundColor Cyan
                }
            }
        }
    }

    # === 【断点续传修复】智能分析 ===
    $skipSmartAnalysis = $false
    
    if ($restoreMode -and $restoredSession.Progress -ge 95) {
        # 进度>=95说明已经等待过智能分析了，直接跳过
        Write-Host "`n✅ 跳过：智能分析已处理过（恢复进度 $($restoredSession.Progress)% >= 95%）" -ForegroundColor Green
        $skipSmartAnalysis = $true
    }
    
    if (-not $skipSmartAnalysis) {
    # === 【断点续传修复：智能分析开始】===
    
    # =========================================================
    # 🚀 调用 AURORA 智能模式分析已导出的日志
    # =========================================================
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        # 仅在 GUI 模式下调用
        Write-Host "`n🧠 正在调用 AURORA 智能诊断引擎..." -ForegroundColor Cyan
        
        try {
            # 显示确认对话框
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "  智能诊断分析可用" -ForegroundColor White
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "`n📊 已检测到导出的 CSV 文件：" -ForegroundColor Yellow
            Write-Host "   位置：$outDir" -ForegroundColor Gray
            
            # 统计 CSV 文件数量
            $csvCount = (Get-ChildItem -Path $outDir -Filter "*_Log_*.csv" -File -ErrorAction SilentlyContinue).Count
            $csvCount += (Get-ChildItem -Path $outDir -Filter "*_日志_*.csv" -File -ErrorAction SilentlyContinue).Count
            
            if ($csvCount -gt 0) {
                Write-Host "   文件：找到 $csvCount 个 CSV 文件" -ForegroundColor Green
            } else {
                Write-Host "   文件：未找到 CSV 文件" -ForegroundColor Red
            }
            
            Write-Host "`n🔍 智能模式将执行：" -ForegroundColor Cyan
            Write-Host "   ✓ 加载已导出的 CSV 文件" -ForegroundColor White
            Write-Host "   ✓ 知识库靶向碰撞分析" -ForegroundColor White
            Write-Host "   ✓ 提供自主修复方案" -ForegroundColor White
            
            Write-Host "`n⚡ 是否立即启动智能诊断分析？" -ForegroundColor Yellow
            Write-Host "========================================`n" -ForegroundColor Cyan
            
            # 请求确认（通过 GUI 对话框或控制台输入）
            $userConfirmed = $false
            
            if ($null -ne (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
                # GUI 模式：通过 syncHash 请求用户确认
                Write-Host "📋 正在等待用户确认..." -ForegroundColor Gray
                
                # 设置授权请求标志
                $global:syncHash.ResetAuthorizationModal = $true  # 先强制重置状态
                
                # 给 GUI 一点时间来重置状态
                Start-Sleep -Milliseconds 100
                
                $global:syncHash.SmartAnalysisRequested = $true
                $global:syncHash.SmartAnalysisAuthorized = $null  # 重置为 null，等待用户决策
                
                # 等待 GUI 响应
                $waitCount = 0
                $maxWaitCount = 600
                while ($global:syncHash.SmartAnalysisAuthorized -eq $null -and 
                       $waitCount -lt $maxWaitCount) {
                    Start-Sleep -Milliseconds 50
                    $waitCount++
                }
                
                # 记录等待情况
                if ($waitCount -lt $maxWaitCount) {
                    Write-Host "✅ GUI 已响应智能分析请求（等待了 $($waitCount * 50)ms）" -ForegroundColor Green
                } else {
                    Write-Host "⚠️ GUI 响应超时（等待了 30 秒），继续执行..." -ForegroundColor Yellow
                }
                
                # 读取用户决策
                $userConfirmed = ($global:syncHash.SmartAnalysisAuthorized -eq $true)
                
                # 清理标志
                $global:syncHash.SmartAnalysisRequested = $false
                
                if ($userConfirmed) {
                    Write-Host "`n✅ 用户确认，开始智能分析..." -ForegroundColor Green
                } else {
                    Write-Host "`n⏭️ 用户跳过智能分析。" -ForegroundColor Yellow
                }
            }
            else {
                # 控制台模式：使用 Read-Host
                try {
                    $confirmChoice = Read-Host "   是否开始智能分析？(Y/N) [默认：Y]"
                    $userConfirmed = ([string]::IsNullOrWhiteSpace($confirmChoice) -or $confirmChoice -like 'Y*')
                }
                catch {
                    Write-Host "⚠️ 检测到非交互式环境，自动启动智能分析..." -ForegroundColor Yellow
                    $userConfirmed = $true  # 默认确认
                }
            }
            
            if ($userConfirmed) {
                # 用户确认，执行智能分析
                Write-Host "`n📖 正在加载智能引擎..." -ForegroundColor Cyan
                
                # 构建智能模式参数
                $smartParams = @{
                    Language = "CHS"  # 默认中文，可根据 GUI 语言调整
                    FromPRO = $true   # 标记从 PRO 模式调用
                    ExportedLogPath = $outDir  # 传递导出的日志目录
                }
                
                # 检查智能引擎文件是否存在
                $smartEnginePath = "$PSScriptRoot\AURORA-SmartEngine.ps1"
                if (Test-Path $smartEnginePath) {
                    # 执行智能引擎
                    & $smartEnginePath @smartParams
                    
                    Write-Host "`n✅ 智能诊断分析完成！" -ForegroundColor Green
                    
                    # 保存进度：智能分析完成
                    Save-ProgressSafe -Checkpoint "SmartAnalysisComplete"
                } else {
                    Write-Host "⚠️ 未找到智能引擎文件，跳过智能分析。" -ForegroundColor Yellow
                    Write-Host "   预期路径：$smartEnginePath" -ForegroundColor Gray
                }
            } else {
                # 用户取消
                Write-Host "`n⏭️ 已跳过智能分析。" -ForegroundColor Yellow
                Write-Host "   如需分析，可手动运行 AURORA-SmartEngine.ps1" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "⚠️ 调用智能引擎失败：$($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "   不影响已导出的日志结果。" -ForegroundColor Gray
        }
    }
    }
    # === 【断点续传修复：智能分析结束】===

    if (-not $Silent) {
        Write-Host "`n✅ 操作完成！感谢使用本工具。" -ForegroundColor Green
        
        # 保存最终进度
        Save-ProgressSafe -Checkpoint "Completed"
        
        # 标记会话完成并归档
        if ($sessionId) {
            Complete-Session -SessionId $sessionId -Archive
            Write-Verbose "[ProgressManager] 会话已完成并归档：$sessionId"
        }
        
        # 仅在非 GUI 的独立控制台模式下，才要求按回车退出
        if ($null -eq (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
            Write-Host "`n 按 Enter 键退出" -ForegroundColor Gray
            Read-Host | Out-Null
        }
    }
}
catch {
    if (-not $Silent) {
        Write-Host "`n❌ 发生错误：$($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Message -match '拒绝访问|Access is denied') {
            Write-Host "💡 建议：以“管理员身份运行”PowerShell 以获取完整日志权限。" -ForegroundColor Yellow
        }
        # 仅在非 GUI 的独立控制台模式下，才要求按回车退出
        if ($null -eq (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
            Write-Host "`n按 Enter 键退出" -ForegroundColor Gray
            Read-Host | Out-Null
        }
    }
    exit 1
}
#endregion