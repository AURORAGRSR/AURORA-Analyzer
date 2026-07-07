<#
.SYNOPSIS
    AURORA 系统还原管理器 - Windows System Restore 支持
.DESCRIPTION
    提供系统还原点创建、查询、删除和还原功能
    支持修复命令执行前的系统保护
    支持撤销操作（Undo）
.NOTES
    版本：V1.4.27.5Release | 构建时间：2026.07.07
    作者：AURORA VelociRaptor-GR Dev PRJ.
    需要管理员权限才能创建系统还原点
    仅支持 Windows NT/2000/XP 及更高版本
    需要系统还原功能已启用
#>

#requires -Version 5.0
# 管理员权限检查已移至调用方 (RepairTools.ps1 L251)

param()

#region 全局变量

$script:RestoreLogDir = if ($PSScriptRoot) {
    Join-Path $PSScriptRoot "..\SessionCache\restorepoints"
} else {
    Join-Path $env:TEMP "AURORA-RestorePoints"
}

$script:RestoreMetadata = @{}

#endregion

#region 初始化函数

function Initialize-RestoreManager {
    <#
    .SYNOPSIS
        初始化还原管理器
    .DESCRIPTION
        创建必要的目录，检查系统还原能力
    #>
    
    try {
        # 创建还原点日志目录
        if (-not (Test-Path $script:RestoreLogDir)) {
            New-Item -ItemType Directory -Path $script:RestoreLogDir -Force | Out-Null
        }
        
        # 检查系统还原能力
        $capability = Test-RestorePointCapability
        
        Write-Host "✅ AURORA 还原管理器初始化完成" -ForegroundColor Green
        Write-Host "   系统还原支持：$(if ($capability.SystemRestoreEnabled) { '✅ 已启用' } else { '❌ 未启用' })"
        Write-Host "   管理员权限：$(if ($capability.IsAdmin) { '✅ 已获取' } else { '❌ 未获取' })"
        Write-Host "   日志目录：$script:RestoreLogDir"
        
        return $true
    } catch {
        Write-Warning "还原管理器初始化失败：$($_.Exception.Message)"
        return $false
    }
}

function Test-RestorePointCapability {
    <#
    .SYNOPSIS
        检查系统还原点创建能力
    .DESCRIPTION
        检查管理员权限、系统还原状态、WMI 访问能力
    .OUTPUTS
        Hashtable 包含能力检查结果
    #>
    
    $result = @{
        IsAdmin = $false
        SystemRestoreEnabled = $false
        WMIAccessible = $false
        CanCreateRestorePoint = $false
    }
    
    # 检查管理员权限
    try {
        $result.IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        $result.IsAdmin = $false
    }
    
    # 检查系统还原是否启用
    try {
        $restoreKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -ErrorAction Stop
        $result.SystemRestoreEnabled = $true
    } catch {
        $result.SystemRestoreEnabled = $false
    }
    
    # 检查 WMI 访问
    try {
        $null = Get-WmiObject -Namespace "root\default" -Class "SystemRestore" -ErrorAction Stop
        $result.WMIAccessible = $true
    } catch {
        $result.WMIAccessible = $false
    }
    
    # 综合判断
    $result.CanCreateRestorePoint = ($result.IsAdmin -and $result.WMIAccessible)
    
    return $result
}

#endregion

#region 系统还原点管理

function Create-SystemRestorePoint {
    <#
    .SYNOPSIS
        创建系统还原点
    .DESCRIPTION
        使用 Windows System Restore API 创建系统还原点
    .PARAMETER Description
        还原点描述
    .PARAMETER RestorePointType
        还原点类型：0=Application Install, 12=Device Driver Install, 10=Modify Settings
    .PARAMETER EventType
        事件类型：100=Begin System Change, 101=End System Change
    .PARAMETER Timeout
        创建超时（秒）
    .EXAMPLE
        Create-SystemRestorePoint -Description "Before Registry Repair"
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$Description,
        
        [int]$RestorePointType = 10,  # MODIFY_SETTINGS
        [int]$EventType = 100,        # BEGIN_SYSTEM_CHANGE
        [int]$Timeout = 300           # 5 分钟超时
    )
    
    Write-Host "🔄 正在创建系统还原点..." -ForegroundColor Cyan
    Write-Host "   描述：$Description"
    Write-Host "   类型：$(Get-RestorePointTypeName -Type $RestorePointType)"
    
    # 检查能力
    $capability = Test-RestorePointCapability
    if (-not $capability.CanCreateRestorePoint) {
        Write-Warning "无法创建系统还原点："
        if (-not $capability.IsAdmin) { Write-Warning "  - 需要管理员权限" }
        if (-not $capability.WMIAccessible) { Write-Warning "  - WMI 访问失败" }
        if (-not $capability.SystemRestoreEnabled) { Write-Warning "  - 系统还原未启用" }
        return $null
    }
    
    try {
        # 生成还原点 ID
        $restorePointId = "RP_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$(Get-Random -Maximum 999)"
        
        # 使用 WMI 创建还原点
        $startTime = Get-Date
        $systemRestore = Get-WmiObject -Namespace "root\default" -Class "SystemRestore"
        
        $result = $systemRestore.CreateRestorePoint($Description, $RestorePointType, $EventType)
        
        $elapsed = (New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds
        
        if ($result.ReturnValue -eq 0) {
            Write-Host "✅ 系统还原点创建成功 (耗时：$([Math]::Round($elapsed, 1))秒)" -ForegroundColor Green
            
            # 保存元数据
            $metadata = @{
                RestorePointId = $restorePointId
                SequenceNumber = $result.SequenceNumber
                CreatedAt = Get-Date -Format "o"
                Description = $Description
                Type = $RestorePointType
                ElapsedSeconds = [Math]::Round($elapsed, 1)
                Status = "Active"
            }
            
            Save-RestorePointMetadata -Metadata $metadata
            
            return $metadata
        } else {
            $errorMessage = Get-RestorePointError -Code $result.ReturnValue
            Write-Warning "创建系统还原点失败：$errorMessage (代码：$($result.ReturnValue))"
            return $null
        }
    } catch {
        Write-Warning "创建系统还原点失败：$($_.Exception.Message)"
        return $null
    }
}

function Get-SystemRestorePoints {
    <#
    .SYNOPSIS
        获取系统还原点列表
    .DESCRIPTION
        查询所有可用的系统还原点
    .OUTPUTS
        SystemRestore 对象数组
    .EXAMPLE
        Get-SystemRestorePoints
    #>
    
    try {
        $capability = Test-RestorePointCapability
        if (-not $capability.WMIAccessible) {
            Write-Warning "无法访问 WMI 获取还原点列表"
            return @()
        }
        
        $restorePoints = Get-WmiObject -Namespace "root\default" -Class "SystemRestore" | 
            Where-Object { $_.Description -like "*AURORA*" } |
            Sort-Object -Property CreationTime -Descending
        
        return $restorePoints
    } catch {
        Write-Warning "获取还原点列表失败：$($_.Exception.Message)"
        return @()
    }
}

function Remove-SystemRestorePoint {
    <#
    .SYNOPSIS
        删除系统还原点
    .DESCRIPTION
        删除指定的系统还原点（需要管理员权限）
    .PARAMETER SequenceNumber
        还原点序列号
    .EXAMPLE
        Remove-SystemRestorePoint -SequenceNumber 45
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [int]$SequenceNumber
    )
    
    Write-Host "🗑️ 正在删除系统还原点 (序列号：$SequenceNumber)..." -ForegroundColor Yellow
    
    $capability = Test-RestorePointCapability
    if (-not $capability.IsAdmin) {
        Write-Warning "删除系统还原点需要管理员权限"
        return $false
    }
    
    try {
        $systemRestore = Get-WmiObject -Namespace "root\default" -Class "SystemRestore"
        $result = $systemRestore.RemoveRestorePoint($SequenceNumber)
        
        if ($result.ReturnValue -eq 0) {
            Write-Host "✅ 还原点删除成功" -ForegroundColor Green
            return $true
        } else {
            $errorMessage = Get-RestorePointError -Code $result.ReturnValue
            Write-Warning "删除还原点失败：$errorMessage (代码：$($result.ReturnValue))"
            return $false
        }
    } catch {
        Write-Warning "删除还原点失败：$($_.Exception.Message)"
        return $false
    }
}

function Restore-System {
    <#
    .SYNOPSIS
        执行系统还原
    .DESCRIPTION
        将系统还原到指定的还原点
    .PARAMETER SequenceNumber
        还原点序列号
    .PARAMETER Confirm
        确认提示
    .EXAMPLE
        Restore-System -SequenceNumber 45
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [int]$SequenceNumber,
        
        [switch]$Confirm
    )
    
    if ($Confirm) {
        $response = Read-Host "⚠️ 系统还原将重启计算机，是否继续？(Y/N)"
        if ($response -ne 'Y' -and $response -ne 'y') {
            Write-Host "用户取消系统还原" -ForegroundColor Yellow
            return $false
        }
    }
    
    Write-Host "🔄 正在执行系统还原..." -ForegroundColor Cyan
    Write-Host "   目标还原点序列号：$SequenceNumber"
    
    $capability = Test-RestorePointCapability
    if (-not $capability.IsAdmin) {
        Write-Warning "系统还原需要管理员权限"
        return $false
    }
    
    try {
        $systemRestore = Get-WmiObject -Namespace "root\default" -Class "SystemRestore"
        $result = $systemRestore.Restore($SequenceNumber)
        
        if ($result.ReturnValue -eq 0) {
            Write-Host "✅ 系统还原已启动，计算机将重启" -ForegroundColor Green
            return $true
        } else {
            $errorMessage = Get-RestorePointError -Code $result.ReturnValue
            Write-Warning "系统还原失败：$errorMessage (代码：$($result.ReturnValue))"
            return $false
        }
    } catch {
        Write-Warning "系统还原失败：$($_.Exception.Message)"
        return $false
    }
}

#endregion

#region 辅助函数

function Get-RestorePointTypeName {
    param([int]$Type)
    
    $types = @{
        0 = "APPLICATION_INSTALL"
        1 = "APPLICATION_UNINSTALL"
        10 = "MODIFY_SETTINGS"
        12 = "DEVICE_DRIVER_INSTALL"
        13 = "DEVICE_DRIVER_ROLLBACK"
    }
    
    if ($types.ContainsKey($Type)) { return $types[$Type] } else { return "UNKNOWN ($Type)" }
}

function Get-RestorePointError {
    param([int]$Code)
    
    $errors = @{
        0 = "成功"
        -1 = "失败"
        -2 = "访问被拒绝"
        -3 = "不支持"
        -4 = "参数错误"
        -5 = "内存不足"
        -6 = "无效上下文"
        -2147221021 = "系统还原未启用"
    }
    
    if ($errors.ContainsKey($Code)) { return $errors[$Code] } else { return "未知错误 (代码：$Code)" }
}

function Save-RestorePointMetadata {
    param([hashtable]$Metadata)
    
    try {
        $metadataFile = Join-Path $script:RestoreLogDir "$($Metadata.RestorePointId).json"
        $Metadata | ConvertTo-Json -Depth 5 | Out-File $metadataFile -Encoding UTF8
    } catch {
        Write-Verbose "保存还原点元数据失败：$($_.Exception.Message)"
    }
}

function Get-RestorePointMetadata {
    param([string]$RestorePointId)
    
    try {
        $metadataFile = Join-Path $script:RestoreLogDir "${RestorePointId}.json"
        if (Test-Path $metadataFile) {
            return Get-Content $metadataFile -Raw | ConvertFrom-Json
        }
    } catch {
        Write-Verbose "读取还原点元数据失败：$($_.Exception.Message)"
    }
    
    return $null
}

#endregion

#region 导出函数

# 注意：本脚本作为模块使用，通过点号导入
# 函数在全局作用域中自动可用

#endregion
