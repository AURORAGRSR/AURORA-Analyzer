<#
.SYNOPSIS
    AURORA 共享核心引擎
.DESCRIPTION
    CHSPRO 和 ENGPRO 共享的核心功能模块
    包含：配置参数、工具函数、日志处理、权限管理、会话管理
.NOTES
    版本：V1.5.29.0Release | 构建时间：2026.07.16
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>

param(
    [string]$Language = "CHS"  # 语言选择：CHS 或 ENG
)

# ==========================================
# 🔒 防止重复导入标志
# ==========================================
# 如果已经导入过，直接跳过，避免重复注册函数和重复初始化
if ($global:AURORA_CoreEngine_Loaded -eq $true) {
    return
}
$global:AURORA_CoreEngine_Loaded = $true

# ==========================================
# 📦 全局配置参数
# ==========================================

# 需要管理员权限的日志类型
$script:AdminRequiredLogTypes = @(
    "Security", "Setup", "DNS Server", "DHCP Server", 
    "Directory Service", "IIS Admin Service"
)

# 日志类型映射表（英文显示名）
$LogTypeDisplayNames = @{
    "Application" = "Application"
    "System" = "System"
    "Security" = "Security"
    "Setup" = "Setup"
    "OpenSSH" = "OpenSSH"
    "PowerShell" = "PowerShell"
    "Windows Update" = "Windows Update"
    "DNS Server" = "DNS Server"
    "DHCP Server" = "DHCP Server"
    "Directory Service" = "Directory Service"
    "IIS Admin Service" = "IIS Admin Service"
}

# 进度保存目录
$ProgressSaveDir = if ($PSScriptRoot) {
    $tempPath = Join-Path $PSScriptRoot "..\Temp"
    if (Test-Path $tempPath) {
        Resolve-Path $tempPath
    } else {
        $env:TEMP
    }
} else {
    $env:TEMP
}

# ==========================================
# 🛡️ 权限管理函数
# ==========================================

<#
.SYNOPSIS
    检查指定日志类型是否需要管理员权限
.DESCRIPTION
    返回布尔值，指示日志类型是否需要管理员权限
.PARAMETER LogType
    日志类型名称
#>
function Test-AdminRequired {
    param([string]$LogType)
    return $script:AdminRequiredLogTypes -contains $LogType
}

<#
.SYNOPSIS
    执行提权检查并在需要时请求用户授权
.DESCRIPTION
    通过 syncHash 与 GUI 通信，请求管理员权限授权
.PARAMETER FeatureName
    需要提权的功能名称
.PARAMETER LogType
    需要提权的日志类型
.PARAMETER Timeout
    等待用户响应的超时时间（秒）
#>
function Invoke-ElevationCheck {
    param(
        [string]$FeatureName,
        [string]$LogType,
        [int]$Timeout = 30
    )
    
    # 仅在 GUI 环境下通过 syncHash 通信
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        $global:syncHash.RequestElevation = $true
        $global:syncHash.ElevationReason = "$FeatureName 需要管理员权限才能访问 $($LogType) 日志"
        $global:syncHash.ElevationLogType = $LogType
        $global:syncHash.ElevationAuthorized = $null
        
        $startTime = Get-Date
        $elapsed = 0
        
        while ($null -eq $global:syncHash.ElevationAuthorized -and $elapsed -lt $timeout) {
            Start-Sleep -Milliseconds 100
            $elapsed = (New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds
        }
        
        if ($global:syncHash.ElevationAuthorized -eq $true) {
            return $true
        } else {
            return $false
        }
    }
    
    # 非 GUI 环境下默认返回 false
    return $false
}

# ==========================================
# 📝 日志处理函数
# ==========================================

<#
.SYNOPSIS
    统一的日志写入函数
.DESCRIPTION
    将日志信息写入控制台和 syncHash（如果存在）
.PARAMETER Message
    日志消息
.PARAMETER Level
    日志级别：Info, Warning, Error, Success
#>
function Write-AuroraLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [ValidateSet('Debug', 'Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info',

        [string]$Source = 'General',

        [hashtable]$Data
    )

    # 颜色映射
    $colorMap = @{
        "Debug"   = "DarkGray"
        "Info"    = "White"
        "Warning" = "Yellow"
        "Error"   = "Red"
        "Success" = "Green"
    }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $sourceTag = if ($Source -ne 'General') { "[$Source] " } else { "" }
    $coloredMsg = "[$timestamp] [$Level] ${sourceTag}$Message"

    # 检测是否在 GUI 环境下（通过 syncHash 判断）
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        # GUI 环境：只写入 syncHash，Runspace 中重写的 Write-Host 会处理显示
        $global:syncHash.LogOutput += "$coloredMsg`n"
    } else {
        # 非 GUI 环境：直接写入控制台
        Write-Host $coloredMsg -ForegroundColor $colorMap[$Level]
    }

    # P1-3: 统一写入结构化日志（如果源不是自己避免无限循环）
    if ($Source -ne 'StructuredLog') {
        Write-AuroraStructuredLog -Message $Message -Level $Level -Source $Source -Data $Data
    }
}

# Structured log configuration
$script:AuroraLogConfig = @{
    LogDirectory  = Join-Path $env:LOCALAPPDATA "AURORA\Logs"
    LogLevel      = "Info"
    MaxFileCount  = 10
    EnableFileLog = $true
    EnableConsole = $true
}

function Write-AuroraStructuredLog {
    <#
    .SYNOPSIS
        写入结构化日志
    .DESCRIPTION
        统一的结构化日志函数，支持 CSV 文件持久化（PS 5.1 兼容）。
        支持日志级别过滤和日志文件轮转。
        注意：此函数仅负责文件写入，控制台输出由 Write-AuroraLog 处理。
    .PARAMETER Message
        日志消息
    .PARAMETER Level
        日志级别：Debug, Info, Warning, Error, Success
    .PARAMETER Source
        日志来源模块
    .PARAMETER Data
        附加数据（哈希表）
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet("Debug", "Info", "Warning", "Error", "Success")]
        [string]$Level = "Info",
        [string]$Source = "General",
        [hashtable]$Data
    )
    
    $levelOrder = @{ Debug = 0; Info = 1; Warning = 2; Error = 3; Success = 1 }
    if ($levelOrder[$Level] -lt $levelOrder[$script:AuroraLogConfig.LogLevel]) {
        return
    }
    
    # File output only (console output is handled by Write-AuroraLog)
    if ($script:AuroraLogConfig.EnableFileLog) {
        try {
            $logDir = $script:AuroraLogConfig.LogDirectory
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
                # 🔒 M-6：为日志目录设置 ACL，仅允许当前用户访问
                # 防止其他进程读取堆栈跟踪和异常详情
                try {
                    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                    $dirAcl = Get-Acl $logDir
                    $dirAcl.SetAccessRuleProtection($true, $false)
                    $dirRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        $currentIdentity.User, "FullControl", "ContainerInherit,ObjectInherit", "Allow")
                    $dirAcl.AddAccessRule($dirRule)
                    Set-Acl -Path $logDir -AclObject $dirAcl
                } catch {}
            }
            
            $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffzzz"
            $logFile = Join-Path $logDir "aurora_$(Get-Date -Format 'yyyyMMdd').log"
            $logEntry = [PSCustomObject]@{
                Timestamp = $timestamp
                Level     = $Level
                Source    = $Source
                Message   = $Message
                PID       = $PID
                Data      = if ($Data) { $Data | ConvertTo-Json -Depth 2 } else { "" }
            }
            $logEntry | Export-Csv -Path $logFile -Append -NoTypeInformation -Encoding UTF8
            
            # Log rotation
            $logFiles = @(Get-ChildItem $logDir -Filter "aurora_*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
            if ($logFiles.Count -gt $script:AuroraLogConfig.MaxFileCount) {
                $logFiles | Select-Object -First ($logFiles.Count - $script:AuroraLogConfig.MaxFileCount) | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Debug "Structured log file write failed: $($_.Exception.Message)"
        }
    }
}

function Get-AuroraVersion {
    <#
    .SYNOPSIS
        获取 AURORA Analyzer 版本号
    .DESCRIPTION
        从 version.txt 读取版本号并格式化为 Vx.x.x.xRelease 格式
    .RETURNS
        版本字符串，如 "V1.3.26.0Release"
    #>
    $versionFile = Join-Path (Split-Path $PSScriptRoot -Parent) "version.txt"
    if (Test-Path $versionFile) {
        $ver = (Get-Content $versionFile -Raw).Trim()
        return "V${ver}Release"
    }
    return "Unknown"
}

function Invoke-SafeExit {
    <#
    .SYNOPSIS
        安全退出进程（触发 finally 块和事件处理器）
    .DESCRIPTION
        使用 [Environment]::Exit() 替代 Stop-Process -Force，
        确保 finally 块、事件处理器和会话保存正常执行
    .PARAMETER ExitCode
        退出代码，默认 1
    #>
    param([int]$ExitCode = 1)
    
    Write-AuroraLog "Safe exit triggered (code: $ExitCode)" -Level "Warning"
    
    # 清理看门狗定时器
    if ($script:watchdogTimer) { try { $script:watchdogTimer.Stop(); $script:watchdogTimer.Dispose() } catch {} }
    if ($script:heartbeatTimer) { try { $script:heartbeatTimer.Stop(); $script:heartbeatTimer.Dispose() } catch {} }
    
    # 清理完整性监控
    if ($script:fileWatcher) { try { $script:fileWatcher.EnableRaisingEvents = $false; $script:fileWatcher.Dispose() } catch {} }
    if ($script:runtimeIntegrityTimer) { try { $script:runtimeIntegrityTimer.Stop(); $script:runtimeIntegrityTimer.Dispose() } catch {} }
    if ($script:randomIntegrityTimer) { try { $script:randomIntegrityTimer.Stop(); $script:randomIntegrityTimer.Dispose() } catch {} }
    
    try {
        [Environment]::Exit($ExitCode)
    } catch {
        Write-AuroraLog "Safe exit failed, forcing termination" -Level "Error"
        Stop-Process -Id $PID -Force
    }
}

function Convert-SafeDateTime {
    <#
    .SYNOPSIS
        安全转换日期值
    .DESCRIPTION
        支持 ASP.NET JSON 格式、ISO 8601、datetime 类型等多种日期格式，
        带 .NET 版本 fallback 兼容
    .PARAMETER Value
        日期值（字符串或 datetime）
    .RETURNS
        datetime 对象，失败返回 $null
    #>
    param($Value)
    
    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) { return $Value }
    
    # ASP.NET JSON format: \/Date(1234567890)\/
    if ($Value -is [string] -and $Value -match '\\/Date\((\d+)\)\\/') {
        $ts = [long]$matches[1]
        if ([System.DateTimeOffset].GetMethod('FromUnixTimeMilliseconds')) {
            return [DateTimeOffset]::FromUnixTimeMilliseconds($ts).LocalDateTime
        } else {
            $unixEpoch = [datetime]'1970-01-01T00:00:00'
            return $unixEpoch.AddMilliseconds($ts).ToLocalTime()
        }
    }
    
    # Try standard parsing (ISO 8601, local formats, etc.)
    $result = [datetime]::MinValue
    if ([datetime]::TryParse($Value, [ref]$result)) {
        return $result
    }
    
    Write-Debug "Failed to parse date value: $Value"
    return $null
}

<#
.SYNOPSIS
    提示用户输入
.DESCRIPTION
    通过 syncHash 与 GUI 通信，获取用户输入
.PARAMETER PromptMessage
    提示消息
#>
function Read-AuroraInput {
    param([string]$PromptMessage)
    
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        Write-AuroraLog "等待用户输入..." -Level "Info"
        $global:syncHash.UserInput = $null
        
        # 等待用户输入
        $waitStart = Get-Date
        $timeoutMs = 300000  # 5 minutes
        while ($null -eq $global:syncHash.UserInput) {
            Start-Sleep -Milliseconds 100
            if ($global:syncHash.IsHostAlive -eq $false) {
                Invoke-SafeExit -ExitCode 1
            }
            if ((Get-Date) - $waitStart -gt [TimeSpan]::FromMilliseconds($timeoutMs)) {
                Write-AuroraLog "Input timeout after 5 minutes. Exiting." -Level "Error"
                Invoke-SafeExit -ExitCode 1
            }
        }
        
        $response = $global:syncHash.UserInput
        $global:syncHash.UserInput = $null
        return $response
    }
    
    # 非 GUI 环境下使用 Read-Host
    return Read-Host $PromptMessage
}

# ==========================================
# 💾 文件操作函数
# ==========================================

<#
.SYNOPSIS
    安全的 StreamWriter 操作
.DESCRIPTION
    处理文件创建、写入和错误处理
.PARAMETER FilePath
    文件路径
.PARAMETER Action
    操作类型：Create, Append
.PARAMETER Content
    写入内容（可选）
#>
function New-StreamWriterOperation {
    param(
        [string]$FilePath,
        [string]$Action = "Create",
        [string]$Content = ""
    )
    
    try {
        # 确保目录存在
        $dir = Split-Path -Parent $FilePath
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        # 创建 StreamWriter
        $mode = if ($Action -eq "Append") { "Append" } else { "Create" }
        $stream = [System.IO.File]::Open($FilePath, $mode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.AutoFlush = $true
        
        if (-not [string]::IsNullOrEmpty($Content)) {
            $writer.Write($Content)
        }
        
        return $writer
    } catch {
        Write-AuroraLog "文件操作失败：$_" -Level "Error"
        return $null
    }
}

<#
.SYNOPSIS
    获取安全的文件路径（避免路径遍历攻击）
.DESCRIPTION
    验证并规范化文件路径
.PARAMETER BasePath
    基础路径
.PARAMETER RelativePath
    相对路径
#>
function Get-SafeFilePath {
    param(
        [string]$BasePath,
        [string]$RelativePath
    )
    
    $fullPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($BasePath, $RelativePath))
    
    # 🔒 安全修复 H-1：路径遍历绕过防护
    # 1. 确保 BasePath 以目录分隔符结尾，避免 C:\App 匹配 C:\Application\evil
    # 2. 使用 OrdinalIgnoreCase 比较（Windows 文件系统大小写不敏感）
    $safeBase = $BasePath.TrimEnd('\', '/') + '\'
    if (-not $fullPath.StartsWith($safeBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Invalid path"
    }
    
    return $fullPath
}

# ==========================================
# 📊 进度管理函数
# ==========================================

<#
.SYNOPSIS
    安全保存进度
.DESCRIPTION
    将进度信息保存到文件系统，带错误处理
.PARAMETER SessionId
    会话 ID
.PARAMETER Stage
    当前阶段
.PARAMETER Progress
    进度百分比
.PARAMETER LogType
    日志类型
#>
function Save-ProgressSafe {
    param(
        [string]$SessionId,
        [string]$Stage,
        [int]$Progress,
        [string]$LogType
    )
    
    try {
        if (-not (Test-Path $ProgressSaveDir)) {
            New-Item -ItemType Directory -Path $ProgressSaveDir -Force | Out-Null
        }
        
        $progressFile = Join-Path $ProgressSaveDir "$SessionId.progress"
        $content = @"
SessionId=$SessionId
Stage=$Stage
Progress=$Progress
LogType=$LogType
LastUpdated=$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
        
        [System.IO.File]::WriteAllText($progressFile, $content, [System.Text.Encoding]::UTF8)
        
        # 更新 syncHash（如果存在）
        if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
            $global:syncHash.Progress = $Progress
            $global:syncHash.CurrentStatus = $Stage
        }
        
        return $true
    } catch {
        Write-AuroraLog "保存进度失败：$_" -Level "Error"
        return $false
    }
}

<#
.SYNOPSIS
    加载进度信息
.DESCRIPTION
    从文件系统加载之前保存的进度
.PARAMETER SessionId
    会话 ID
#>
function Get-ProgressInfo {
    param([string]$SessionId)
    
    try {
        $progressFile = Join-Path $ProgressSaveDir "$SessionId.progress"
        
        if (Test-Path $progressFile) {
            $content = Get-Content $progressFile -Raw
            $lines = $content -split "`n"
            $progress = @{}
            
            foreach ($line in $lines) {
                if ($line -match "^(.+?)=(.+)$") {
                    $progress[$matches[1]] = $matches[2]
                }
            }
            
            return $progress
        }
    } catch {
        Write-AuroraLog "加载进度失败：$_" -Level "Error"
    }
    
    return $null
}

# ==========================================
# 🔄 会话管理函数
# ==========================================

<#
.SYNOPSIS
    管理会话恢复
.DESCRIPTION
    检测并处理挂起的会话，提供恢复或重新开始选项
.PARAMETER SessionId
    会话 ID
#>
function Manage-Session {
    param([string]$SessionId)
    
    $progress = Get-ProgressInfo -SessionId $SessionId
    
    if ($progress -and $progress.Progress -lt 100) {
        $lastUpdated = [DateTime]$progress.LastUpdated
        $ageInDays = (New-TimeSpan -Start $lastUpdated -End (Get-Date)).TotalDays
        
        Write-AuroraLog "检测到未完成的会话：" -Level "Warning"
        Write-AuroraLog "  阶段：$($progress.Stage)" -Level "Info"
        Write-AuroraLog "  进度：$($progress.Progress)%" -Level "Info"
        Write-AuroraLog "  已挂起：$([Math]::Round($ageInDays, 1)) 天" -Level "Info"
        
        # 通过 syncHash 通知 GUI 显示恢复 HUD
        if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
            $global:syncHash.ShowSessionRecoveryHUD = $true
            $global:syncHash.RestoredSessionId = $SessionId
            $global:syncHash.RestoredStage = $progress.Stage
            $global:syncHash.RestoredProgress = [int]$progress.Progress
            $global:syncHash.RestoredLastUpdated = $progress.LastUpdated
            $global:syncHash.RestoredAgeInDays = [Math]::Round($ageInDays, 1)
            
            # 等待用户决策
            while (-not $global:syncHash.SessionRestored -and -not $global:syncHash.SessionRestarted) {
                Start-Sleep -Milliseconds 100
                if ($global:syncHash.IsHostAlive -eq $false) {
                    Invoke-SafeExit -ExitCode 1
                }
            }
            
            if ($global:syncHash.SessionRestarted -eq $true) {
                Write-AuroraLog "用户选择重新开始" -Level "Info"
                return "Restart"
            } elseif ($global:syncHash.SessionRestored -eq $true) {
                Write-AuroraLog "用户选择恢复进度" -Level "Success"
                return "Restore"
            }
        } else {
            # 非 GUI 环境
            Write-Host "是否恢复进度？(Y/N): " -NoNewline
            $choice = Read-Host
            if ($choice -eq "Y" -or $choice -eq "y") {
                return "Restore"
            } else {
                return "Restart"
            }
        }
    }
    
    return "None"
}

# ==========================================
# 💻 系统信息函数
# ==========================================

<#
.SYNOPSIS
    获取系统基本信息
.DESCRIPTION
    返回系统版本、PowerShell 版本等信息
#>
function Get-SystemInfo {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $psVersion = $PSVersionTable.PSVersion.ToString()
        
        return @{
            OSVersion = $os.Version
            OSName = $os.Caption
            PowerShellVersion = $psVersion
            Is64Bit = [Environment]::Is64BitOperatingSystem
        }
    } catch {
        return @{
            OSVersion = "Unknown"
            OSName = "Unknown"
            PowerShellVersion = $psVersion
            Is64Bit = $false
        }
    }
}

# ==========================================
# 🎯 引擎初始化
# ==========================================

<#
.SYNOPSIS
    统一的安全操作执行函数
.DESCRIPTION
    执行操作并统一处理异常，支持日志记录、清理操作和错误恢复。
    替代代码中大量空 catch 块，提供一致的异常处理策略。
.PARAMETER Operation
    要执行的操作（ScriptBlock）
.PARAMETER OperationName
    操作名称，用于日志记录
.PARAMETER LogLevel
    异常日志级别：Info, Warning, Error
.PARAMETER Cleanup
    清理操作（ScriptBlock），在异常发生且 Operation 失败时执行
.PARAMETER ContinueOnError
    是否在异常后继续执行（不重新抛出）
.PARAMETER DebugMode
    是否记录详细堆栈跟踪（默认使用全局 $global:AURORA_DebugMode）
.EXAMPLE
    Invoke-SafeOperation -Operation { Remove-Item $path -Force } -OperationName "删除临时文件" -LogLevel "Warning" -ContinueOnError
#>
function Invoke-SafeOperation {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Operation,
        
        [Parameter(Mandatory=$true)]
        [string]$OperationName,
        
        [ValidateSet("Info", "Warning", "Error", "Debug")]
        [string]$LogLevel = "Error",
        
        [scriptblock]$Cleanup = $null,
        
        [switch]$ContinueOnError,
        
        [switch]$DebugMode
    )
    
    try {
        & $Operation
        return $true
    } catch {
        $errorMsg = "操作 '$OperationName' 失败: $($_.Exception.Message)"
        Write-AuroraLog $errorMsg -Level $LogLevel
        
        # 记录详细错误信息（仅在调试模式）
        if ($DebugMode -or $global:AURORA_DebugMode -eq $true) {
            Write-AuroraLog "堆栈跟踪: $($_.ScriptStackTrace)" -Level "Debug"
        }
        
        # 执行清理操作
        if ($null -ne $Cleanup) {
            try {
                & $Cleanup
            } catch {
                Write-AuroraLog "清理操作失败: $($_.Exception.Message)" -Level "Warning"
            }
        }
        
        if (-not $ContinueOnError) {
            throw
        }
        
        return $false
    }
}

<#
.SYNOPSIS
    初始化 Core Engine
.DESCRIPTION
    执行环境检查和初始化操作
#>
function Initialize-Engine {
    Write-AuroraLog "正在初始化 AURORA Core Engine..." -Level "Info"
    
    # 环境检查
    $sysInfo = Get-SystemInfo
    Write-AuroraLog "系统：$($sysInfo.OSName) ($($sysInfo.OSVersion))" -Level "Info"
    Write-AuroraLog "PowerShell: v$($sysInfo.PowerShellVersion)" -Level "Info"
    Write-AuroraLog "架构：$(if ($sysInfo.Is64Bit) { "x64" } else { "x86" })" -Level "Info"
    
    # 验证进度保存目录
    if (-not (Test-Path $ProgressSaveDir)) {
        try {
            New-Item -ItemType Directory -Path $ProgressSaveDir -Force | Out-Null
            Write-AuroraLog "已创建进度保存目录：$ProgressSaveDir" -Level "Success"
        } catch {
            Write-AuroraLog "无法创建进度保存目录，将使用 TEMP: $_" -Level "Warning"
            $script:ProgressSaveDir = $env:TEMP
        }
    }
    
    Write-AuroraLog "Core Engine 初始化完成" -Level "Success"
}

# 注意：本文件作为脚本使用（通过 . 操作符导入），不需要 Export-ModuleMember
# 所有函数和变量已声明为 script 或 global 作用域，可直接访问

# ==========================================
# 📊 结构化遥测 (P2-3)
# ==========================================

<#
.SYNOPSIS
    写入结构化遥测事件
.DESCRIPTION
    统一的遥测记录函数，支持日志文件持久化与会话透传。
    用于性能监控、功能使用统计和故障诊断。
.PARAMETER Event
    遥测事件哈希表，建议包含：EventType, Success, DurationMs, SessionId 等
.PARAMETER EventType
    事件类型（快捷方式，自动合并到 Event）
.EXAMPLE
    Write-AuroraTelemetry -Event @{
        EventType   = 'RepairExecuted'
        RepairType  = $RepairType
        Success     = $true
        DurationMs  = $executionTime.TotalMilliseconds
        SessionId   = $sessionId
    }
#>
function Write-AuroraTelemetry {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'Event', Mandatory)]
        [hashtable]$Event,

        [Parameter(ParameterSetName = 'Quick', Mandatory)]
        [string]$EventType,

        [Parameter(ParameterSetName = 'Quick')]
        [bool]$Success = $true,

        [Parameter(ParameterSetName = 'Quick')]
        [double]$DurationMs = 0
    )

    if ($PSCmdlet.ParameterSetName -eq 'Quick') {
        $Event = @{
            EventType  = $EventType
            Success    = $Success
            DurationMs = $DurationMs
        }
    }

    # 补充系统信息
    if (-not $Event.ContainsKey('OSVersion')) {
        $Event['OSVersion'] = [Environment]::OSVersion.VersionString
    }
    if (-not $Event.ContainsKey('PSVersion')) {
        $Event['PSVersion'] = $PSVersionTable.PSVersion.ToString()
    }
    if (-not $Event.ContainsKey('Timestamp')) {
        $Event['Timestamp'] = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fff'
    }

    # 写入日志文件
    try {
        $telemetryDir = Join-Path $env:LOCALAPPDATA "AURORA\Telemetry"
        if (-not (Test-Path $telemetryDir)) {
            New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null
            # 🔒 M-6：为遥测目录设置 ACL，仅允许当前用户访问
            try {
                $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                $telAcl = Get-Acl $telemetryDir
                $telAcl.SetAccessRuleProtection($true, $false)
                $telRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $currentIdentity.User, "FullControl", "ContainerInherit,ObjectInherit", "Allow")
                $telAcl.AddAccessRule($telRule)
                Set-Acl -Path $telemetryDir -AclObject $telAcl
            } catch {}
        }

        $telemetryFile = Join-Path $telemetryDir "telemetry_$(Get-Date -Format 'yyyyMMdd').csv"
        $entry = [PSCustomObject]$Event
        $entry | Export-Csv -Path $telemetryFile -Append -NoTypeInformation -Encoding UTF8

        # 日志轮转（保留最多 7 天）
        $oldFiles = @(Get-ChildItem $telemetryDir -Filter "telemetry_*.csv" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
        if ($oldFiles.Count -gt 7) {
            $oldFiles | Select-Object -First ($oldFiles.Count - 7) | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-AuroraLog "Telemetry write failed: $($_.Exception.Message)" -Level "Warning" -Source "Telemetry"
    }

    # 透传给 GUI（如果存在）
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        $global:syncHash.TelemetryEvents += $Event
    }
}
