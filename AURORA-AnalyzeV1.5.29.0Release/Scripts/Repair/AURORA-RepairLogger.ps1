<#
.SYNOPSIS
    AURORA 修复命令日志记录器
.DESCRIPTION
    记录所有修复命令的执行细节
    支持撤销操作（Undo）
    支持修复历史查询
.NOTES
    版本：V1.5.29.0Release | 构建时间：2026.07.16
    作者：AURORA VelociRaptor-GR Dev PRJ.
    与 RestoreManager 配合使用
    提供完整的修复操作审计追踪
#>

#requires -Version 5.0

param()

#region 全局变量

$script:RepairLogDir = if ($PSScriptRoot) {
    Join-Path $PSScriptRoot "..\SessionCache\repairlogs"
} else {
    Join-Path $env:TEMP "AURORA-RepairLogs"
}

$script:CurrentRepairSession = $null

#endregion

#region 初始化函数

function Initialize-RepairLogger {
    <#
    .SYNOPSIS
        初始化修复日志记录器
    .DESCRIPTION
        创建必要的目录和文件结构
    #>
    
    try {
        # 创建修复日志目录
        if (-not (Test-Path $script:RepairLogDir)) {
            New-Item -ItemType Directory -Path $script:RepairLogDir -Force | Out-Null
        }
        
        Write-Host "✅ AURORA 修复日志记录器初始化完成" -ForegroundColor Green
        Write-Host "   日志目录：$script:RepairLogDir"
        
        return $true
    } catch {
        Write-Warning "修复日志记录器初始化失败：$($_.Exception.Message)"
        return $false
    }
}

#endregion

#region 修复会话管理

function Start-RepairSession {
    <#
    .SYNOPSIS
        开始修复会话
    .DESCRIPTION
        创建新的修复会话，记录开始时间和基本信息
    .PARAMETER RepairType
        修复类型（如 RegistryRepair, ServiceRepair, FileRepair）
    .PARAMETER Target
        修复目标描述
    .PARAMETER CreateRestorePoint
        是否创建系统还原点
    .OUTPUTS
        修复会话对象
    .EXAMPLE
        Start-RepairSession -RepairType "RegistryRepair" -Target "Windows Update Service"
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$RepairType,
        
        [Parameter(Mandatory=$true)]
        [string]$Target,
        
        [switch]$CreateRestorePoint
    )
    
    # 生成会话 ID
    $sessionId = "RS_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$(Get-Random -Maximum 999)"
    
    $session = @{
        SessionId = $sessionId
        StartedAt = Get-Date -Format "o"
        CompletedAt = $null
        RepairType = $RepairType
        Target = $Target
        Description = "修复 $Target - $RepairType"
        CommandsExecuted = 0
        Commands = @()
        Status = "InProgress"  # InProgress, Success, Failed, Partial, Undone
        RestorePointId = $null
        BackupSnapshotId = $null
        CanUndo = $false
        ErrorMessage = $null
    }
    
    Write-Host "🔧 开始修复会话：$sessionId" -ForegroundColor Cyan
    Write-Host "   类型：$RepairType"
    Write-Host "   目标：$Target"
    
    # 创建系统还原点（如果请求）
    if ($CreateRestorePoint) {
        Write-Host "   正在创建系统还原点..." -ForegroundColor Yellow
        
        # 导入 RestoreManager
        $restoreManagerPath = Join-Path $PSScriptRoot "AURORA-RestoreManager.ps1"
        if (Test-Path $restoreManagerPath) {
            if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                Write-Warning "RestoreManager requires administrator privileges. Some functions may not work."
            }
            . $restoreManagerPath
            
            $restorePoint = Create-SystemRestorePoint -Description "AURORA Before Repair: $Target"
            if ($restorePoint) {
                $session.RestorePointId = $restorePoint.RestorePointId
                Write-Host "   ✅ 还原点已创建：$($restorePoint.RestorePointId)" -ForegroundColor Green
            }
        }
    }
    
    # 设置当前会话
    $script:CurrentRepairSession = $session
    
    return $session
}

function Log-RepairCommand {
    <#
    .SYNOPSIS
        记录修复命令
    .DESCRIPTION
        记录单个修复命令的执行信息
    .PARAMETER SessionId
        会话 ID
    .PARAMETER Command
        执行的命令
    .PARAMETER Parameters
        命令参数
    .PARAMETER Status
        执行状态（Success, Failed, Skipped）
    .PARAMETER ErrorMessage
        错误信息（如果失败）
    .PARAMETER AffectedItems
        受影响的项（如注册表路径、服务名等）
    .EXAMPLE
        Log-RepairCommand -SessionId "RS_001" -Command "Set-ItemProperty" -Parameters @{...}
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionId,
        
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [hashtable]$Parameters = @{},
        
        [ValidateSet("Success", "Failed", "Skipped")]
        [string]$Status = "Success",
        
        [string]$ErrorMessage,
        
        [string[]]$AffectedItems = @()
    )
    
    # 获取或创建会话
    $session = Get-RepairSession -SessionId $SessionId
    if (-not $session) {
        Write-Warning "未找到修复会话：$SessionId"
        return $false
    }
    
    # 创建命令记录
    $commandLog = @{
        CommandId = "CMD_$(Get-Date -Format 'HHmmss')_$(Get-Random -Maximum 999)"
        ExecutedAt = Get-Date -Format "o"
        Command = $Command
        Parameters = $Parameters
        Status = $Status
        ErrorMessage = $ErrorMessage
        AffectedItems = $AffectedItems
        CanUndo = ($Status -eq "Success")  # 只有成功的命令可以撤销
    }
    
    # 添加到会话
    $session.Commands += $commandLog
    $session.CommandsExecuted++
    
    if ($Status -eq "Failed") {
        $session.Status = "Partial"
        if (-not $session.ErrorMessage) {
            $session.ErrorMessage = "命令执行失败：$Command"
        }
    }
    
    # 保存会话
    Save-RepairSession -Session $session
    
    Write-Verbose "已记录命令：$Command (状态：$Status)"
    
    return $true
}

function Complete-RepairSession {
    <#
    .SYNOPSIS
        完成修复会话
    .DESCRIPTION
        标记会话完成，更新状态
    .PARAMETER SessionId
        会话 ID
    .PARAMETER Status
        最终状态（Success, Failed, Partial）
    .PARAMETER BackupSnapshotId
        备份快照 ID（用于 Undo）
    .EXAMPLE
        Complete-RepairSession -SessionId "RS_001" -Status "Success"
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionId,
        
        [ValidateSet("Success", "Failed", "Partial")]
        [string]$Status = "Success",
        
        [string]$BackupSnapshotId
    )
    
    $session = Get-RepairSession -SessionId $SessionId
    if (-not $session) {
        Write-Warning "未找到修复会话：$SessionId"
        return $false
    }
    
    $session.CompletedAt = Get-Date -Format "o"
    $session.Status = $Status
    $session.BackupSnapshotId = $BackupSnapshotId
    $session.CanUndo = ($Status -eq "Success" -and (-not [string]::IsNullOrEmpty($BackupSnapshotId) -or -not [string]::IsNullOrEmpty($session.RestorePointId)))
    
    # 保存会话
    Save-RepairSession -Session $session
    
    Write-Host "✅ 修复会话完成：$SessionId" -ForegroundColor Green
    Write-Host "   状态：$Status"
    Write-Host "   执行命令数：$($session.CommandsExecuted)"
    Write-Host "   可撤销：$(if ($session.CanUndo) { '✅ 是' } else { '❌ 否' })"
    
    # 清除当前会话
    $script:CurrentRepairSession = $null
    
    return $true
}

#endregion

#region 会话查询和管理

function Get-RepairSession {
    <#
    .SYNOPSIS
        获取修复会话
    .DESCRIPTION
        从文件或内存中获取修复会话
    .PARAMETER SessionId
        会话 ID
    .OUTPUTS
        修复会话对象
    .EXAMPLE
        Get-RepairSession -SessionId "RS_001"
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionId
    )
    
    # 检查内存中的当前会话
    if ($script:CurrentRepairSession -and $script:CurrentRepairSession.SessionId -eq $SessionId) {
        return $script:CurrentRepairSession
    }
    
    # 从文件读取
    try {
        $sessionFile = Join-Path $script:RepairLogDir "${SessionId}.json"
        if (Test-Path $sessionFile) {
            return Get-Content $sessionFile -Raw | ConvertFrom-Json
        }
    } catch {
        Write-Verbose "读取修复会话失败：$($_.Exception.Message)"
    }
    
    return $null
}

function Get-RepairHistory {
    <#
    .SYNOPSIS
        获取修复历史
    .DESCRIPTION
        获取所有修复会话的历史记录
    .PARAMETER LastDays
        最近 N 天的记录（默认 7 天）
    .PARAMETER Status
        按状态过滤
    .OUTPUTS
        修复会话数组
    .EXAMPLE
        Get-RepairHistory -LastDays 7
    #>
    
    param(
        [int]$LastDays = 7,
        
        [ValidateSet("Success", "Failed", "Partial", "Undone")]
        [string]$Status
    )
    
    try {
        $cutoffDate = (Get-Date).AddDays(-$LastDays)
        $sessions = @()
        
        # 读取所有会话文件
        $sessionFiles = Get-ChildItem -Path $script:RepairLogDir -Filter "*.json" -ErrorAction SilentlyContinue
        
        foreach ($file in $sessionFiles) {
            try {
                $session = Get-Content $file.FullName -Raw | ConvertFrom-Json
                
                # 过滤日期
                $sessionDate = [DateTime]$session.StartedAt
                if ($sessionDate -lt $cutoffDate) {
                    continue
                }
                
                # 过滤状态
                if ($Status -and $session.Status -ne $Status) {
                    continue
                }
                
                $sessions += $session
            } catch {
                Write-Verbose "读取会话文件失败 $($file.Name): $($_.Exception.Message)"
            }
        }
        
        # 按时间排序
        return $sessions | Sort-Object -Property StartedAt -Descending
    } catch {
        Write-Warning "获取修复历史失败：$($_.Exception.Message)"
        return @()
    }
}

function Undo-RepairSession {
    <#
    .SYNOPSIS
        撤销修复会话
    .DESCRIPTION
        撤销指定的修复会话
    .PARAMETER SessionId
        会话 ID
    .PARAMETER UseSystemRestore
        是否使用系统还原（否则使用快速备份）
    .EXAMPLE
        Undo-RepairSession -SessionId "RS_001"
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionId,
        
        [switch]$UseSystemRestore
    )
    
    $session = Get-RepairSession -SessionId $SessionId
    if (-not $session) {
        Write-Warning "未找到修复会话：$SessionId"
        return $false
    }
    
    if (-not $session.CanUndo) {
        Write-Warning "该修复会话不支持撤销"
        return $false
    }
    
    Write-Host "🔄 正在撤销修复会话：$SessionId" -ForegroundColor Cyan
    Write-Host "   类型：$($session.RepairType)"
    Write-Host "   目标：$($session.Target)"
    
    # 选择撤销方式
    if ($UseSystemRestore -and $session.RestorePointId) {
        Write-Host "   使用系统还原..." -ForegroundColor Yellow
        
        # 导入 RestoreManager
        $restoreManagerPath = Join-Path $PSScriptRoot "AURORA-RestoreManager.ps1"
        if (Test-Path $restoreManagerPath) {
            if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                Write-Warning "RestoreManager requires administrator privileges. Some functions may not work."
            }
            . $restoreManagerPath
            
            # 获取还原点元数据
            $restorePoint = Get-RestorePointMetadata -RestorePointId $session.RestorePointId
            if ($restorePoint) {
                # 提示用户确认
                $response = Read-Host "⚠️ 系统还原将重启计算机，是否继续？(Y/N)"
                if ($response -eq 'Y' -or $response -eq 'y') {
                    Restore-System -SequenceNumber $restorePoint.SequenceNumber
                }
            }
        }
    } elseif ($session.BackupSnapshotId) {
        Write-Host "   使用快速备份还原..." -ForegroundColor Yellow
        
        # 导入 UndoManager（位于 Session 目录）
        $parentDir = Split-Path $PSScriptRoot -Parent  # Scripts 根目录
        $undoManagerPath = Join-Path (Join-Path $parentDir "Session") "AURORA-UndoManager.ps1"
        if (Test-Path $undoManagerPath) {
            . $undoManagerPath
            
            Restore-BackupSnapshot -SnapshotId $session.BackupSnapshotId
        }
    } else {
        Write-Warning "未找到可用的还原方式"
        return $false
    }
    
    # 更新会话状态
    $session.Status = "Undone"
    $session.UndoneAt = Get-Date -Format "o"
    Save-RepairSession -Session $session
    
    Write-Host "✅ 撤销完成" -ForegroundColor Green
    
    return $true
}

#endregion

#region 辅助函数

function Save-RepairSession {
    param([hashtable]$Session)
    
    try {
        $sessionFile = Join-Path $script:RepairLogDir "$($Session.SessionId).json"
        $Session | ConvertTo-Json -Depth 10 | Out-File $sessionFile -Encoding UTF8
    } catch {
        Write-Warning "保存修复会话失败：$($_.Exception.Message)"
    }
}

#endregion

#region 导出函数

# 注意：本脚本作为模块使用，通过点号导入
# 函数在全局作用域中自动可用

#endregion
