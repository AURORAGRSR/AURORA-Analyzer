# ==========================================
# 🚀 AURORA Core Engine - 共享核心引擎
# ==========================================
# 版本：v1.1.0Release
# 构建时间：2026.05.14
# 用途：CHSPRO 和 ENGPRO 共享的核心功能模块
# 包含：配置参数、工具函数、日志处理、权限管理、会话管理
# ==========================================

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
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    # 颜色映射
    $colorMap = @{
        "Info" = "White"
        "Warning" = "Yellow"
        "Error" = "Red"
        "Success" = "Green"
    }
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $coloredMsg = "[$timestamp] [$Level] $Message"
    
    # 检测是否在 GUI 环境下（通过 syncHash 判断）
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        # GUI 环境：只写入 syncHash，Runspace 中重写的 Write-Host 会处理显示
        $global:syncHash.LogOutput += "$coloredMsg`n"
    } else {
        # 非 GUI 环境：直接写入控制台
        Write-Host $coloredMsg -ForegroundColor $colorMap[$Level]
    }
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
        while ($null -eq $global:syncHash.UserInput) {
            Start-Sleep -Milliseconds 100
            if ($global:syncHash.IsHostAlive -eq $false) {
                Stop-Process -Id $PID -Force
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
    
    # 确保路径在 BasePath 内
    if (-not $fullPath.StartsWith($BasePath)) {
        throw "无效的路径：$RelativePath"
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
                    Stop-Process -Id $PID -Force
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
