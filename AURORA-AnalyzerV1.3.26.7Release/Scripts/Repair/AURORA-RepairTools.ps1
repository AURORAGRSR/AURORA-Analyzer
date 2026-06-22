<#
.SYNOPSIS
    AURORA 修复工具集（带 Undo 支持）
.DESCRIPTION
    提供系统修复功能，所有修复操作都支持撤销
    支持系统还原点和快速备份两种 Undo 方式
.PARAMETER RepairType
    指定修复类型
.PARAMETER Target
    修复目标
.PARAMETER CreateRestorePoint
    是否创建系统还原点
.PARAMETER UseBackupSnapshot
    是否使用快速备份快照
.PARAMETER GUI_Mode
    开关参数。标记是否在 GUI 模式下运行。
.NOTES
    版本：V1.3.26.7Release | 构建时间：2026.06.22
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>

Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("DisableWindowsUpdate", "EnableDefender", "DisableTelemetry", "ResetNetwork", "CleanSystem", "Custom")]
    [string]$RepairType,
    
    [string]$Target,
    
    [switch]$CreateRestorePoint,
    
    [switch]$UseBackupSnapshot,
    
    [switch]$GUI_Mode
)

# ==========================================
# 🔒 启动检测（统一使用 LaunchGuard 模块）
# ==========================================
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$parentDir = Split-Path $scriptDir -Parent  # Scripts 根目录

# 导入 CoreEngine（提供 Invoke-SafeExit）
$coreEnginePath = Join-Path (Join-Path $parentDir "Core") "AURORA-CoreEngine.ps1"
if (Test-Path $coreEnginePath) {
    . $coreEnginePath
} else {
    throw "Core engine not found: $coreEnginePath"
}

# 导入 LaunchGuard（提供 Assert-AuroraLaunchContext）
$launchGuardPath = Join-Path (Join-Path $parentDir "Core") "AURORA-LaunchGuard.ps1"
if (Test-Path $launchGuardPath) {
    . $launchGuardPath
    Assert-AuroraLaunchContext -Params $PSBoundParameters
} else {
    # Fallback: 原始启动检测逻辑
    $isLaunchedByGUI = $false
    if ($GUI_Mode) { $isLaunchedByGUI = $true }
    if (-not $isLaunchedByGUI -and (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
        $isLaunchedByGUI = $true
    }
    if (-not $isLaunchedByGUI) {
        $TokenPath = $env:AURORA_TOKEN_PATH
        if (-not [string]::IsNullOrWhiteSpace($TokenPath) -and (Test-Path $TokenPath)) {
            try {
                $tokenContent = Get-Content $TokenPath -Raw -Encoding UTF8
                $parts = $tokenContent -split ':', 4
                if ($parts.Count -eq 4 -and (Get-Command Test-RSATokenSignature -ErrorAction SilentlyContinue)) {
                    if (Test-RSATokenSignature -Nonce $parts[0] -Timestamp $parts[1] -HashPayload $parts[2] -Signature $parts[3]) {
                        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                        if (($now - $parts[1]) -lt 60 -and ($now - $parts[1]) -gt -5) {
                            $isLaunchedByGUI = $true
                        }
                    }
                }
            } catch {
                Write-Warning "Launch context token validation failed: $($_.Exception.Message)"
            }
        }
    }
    if (-not $isLaunchedByGUI) {
        Write-Host "  This script cannot be run directly!" -ForegroundColor Red
        Start-Sleep -Seconds 5
        Invoke-SafeExit -ExitCode 1
    }
}

# 导入 RestoreManager（需要管理员权限）
$restoreManagerPath = Join-Path $scriptDir "AURORA-RestoreManager.ps1"
if (Test-Path $restoreManagerPath) {
    . $restoreManagerPath
}

# 导入 RepairLogger
$repairLoggerPath = Join-Path $scriptDir "AURORA-RepairLogger.ps1"
if (Test-Path $repairLoggerPath) {
    . $repairLoggerPath
}

# 导入 UndoManager（位于 Session 目录）
$undoManagerPath = Join-Path (Join-Path $parentDir "Session") "AURORA-UndoManager.ps1"
if (Test-Path $undoManagerPath) {
    . $undoManagerPath
}

# ==========================================
# 🔧 修复函数定义
# ==========================================

function Invoke-WindowsUpdateRepair {
    param([string]$Action = "Disable")
    
    Write-Host "`n[修复] 正在配置 Windows Update 设置..." -ForegroundColor Cyan
    
    $registryChanges = @()
    
    if ($Action -eq "Disable") {
        # 禁用 Windows Update
        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $regPath -Name "NoAutoUpdate" -Value 1 -Force
        $registryChanges += @{ Path = $regPath; Name = "NoAutoUpdate"; Value = 1 }
        
        Set-ItemProperty -Path $regPath -Name "AUOptions" -Value 1 -Force
        $registryChanges += @{ Path = $regPath; Name = "AUOptions"; Value = 1 }
        
        Write-Host "  ✅ 已禁用自动更新" -ForegroundColor Green
    } else {
        # 启用 Windows Update
        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        
        if (Test-Path $regPath) {
            Remove-ItemProperty -Path $regPath -Name "NoAutoUpdate" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $regPath -Name "AUOptions" -Force -ErrorAction SilentlyContinue
        }
        
        Write-Host "  ✅ 已启用自动更新" -ForegroundColor Green
    }
    
    return $registryChanges
}

function Invoke-DefenderRepair {
    param([string]$Action = "Enable")
    
    Write-Host "`n[修复] 正在配置 Windows Defender..." -ForegroundColor Cyan
    
    $registryChanges = @()
    
    if ($Action -eq "Enable") {
        # 启用 Defender
        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
        
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $regPath -Name "DisableAntiSpyware" -Value 0 -Force
        $registryChanges += @{ Path = $regPath; Name = "DisableAntiSpyware"; Value = 0 }
        
        Write-Host "  ✅ 已启用 Windows Defender" -ForegroundColor Green
    } else {
        # 禁用 Defender（不推荐）
        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
        
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $regPath -Name "DisableAntiSpyware" -Value 1 -Force
        $registryChanges += @{ Path = $regPath; Name = "DisableAntiSpyware"; Value = 1 }
        
        Write-Host "  ⚠️ 已禁用 Windows Defender（系统安全性降低）" -ForegroundColor Yellow
    }
    
    return $registryChanges
}

function Invoke-TelemetryRepair {
    param([string]$Action = "Disable")
    
    Write-Host "`n[修复] 正在配置遥测设置..." -ForegroundColor Cyan
    
    $registryChanges = @()
    
    if ($Action -eq "Disable") {
        # 禁用遥测
        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $regPath -Name "AllowTelemetry" -Value 0 -Force
        $registryChanges += @{ Path = $regPath; Name = "AllowTelemetry"; Value = 0 }
        
        Write-Host "  ✅ 已禁用 Windows 遥测" -ForegroundColor Green
    } else {
        # 启用遥测
        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        
        if (Test-Path $regPath) {
            Remove-ItemProperty -Path $regPath -Name "AllowTelemetry" -Force -ErrorAction SilentlyContinue
        }
        
        Write-Host "  ✅ 已启用 Windows 遥测" -ForegroundColor Green
    }
    
    return $registryChanges
}

function Invoke-NetworkReset {
    Write-Host "`n[修复] 正在重置网络配置..." -ForegroundColor Cyan
    
    $changes = @()
    
    # 重置 Winsock
    Write-Host "  📡 重置 Winsock 目录..." -ForegroundColor Yellow
    $process = Start-Process "netsh.exe" -ArgumentList "winsock reset" -Wait -NoNewWindow -PassThru
    $changes += @{ Action = "WinsockReset"; ExitCode = $process.ExitCode }
    
    # 重置 TCP/IP
    Write-Host "  📡 重置 TCP/IP 协议..." -ForegroundColor Yellow
    $process = Start-Process "netsh.exe" -ArgumentList "int ip reset" -Wait -NoNewWindow -PassThru
    $changes += @{ Action = "TcpIpReset"; ExitCode = $process.ExitCode }
    
    # 刷新 DNS
    Write-Host "  📡 刷新 DNS 缓存..." -ForegroundColor Yellow
    $process = Start-Process "ipconfig.exe" -ArgumentList "/flushdns" -Wait -NoNewWindow -PassThru
    $changes += @{ Action = "DnsFlush"; ExitCode = $process.ExitCode }
    
    Write-Host "  ✅ 网络重置完成（可能需要重启）" -ForegroundColor Green
    
    return $changes
}

# ==========================================
# 🚀 主执行流程
# ==========================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  AURORA 修复工具 V1.0" -ForegroundColor Cyan
Write-Host "  支持 Undo 撤销功能" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 检查管理员权限
$isAdmin = Test-AdminRequired -LogType $RepairType
if (-not $isAdmin) {
    Write-Host "❌ 需要管理员权限才能执行修复操作" -ForegroundColor Red
    Write-Host "   请以管理员身份运行此脚本" -ForegroundColor Yellow
    Invoke-SafeExit -ExitCode 1
}

Write-Host "✅ 管理员权限检查通过`n" -ForegroundColor Green

# 初始化模块
Initialize-UndoManager

# 开始修复会话
$session = Start-RepairSession -RepairType $RepairType -Target $Target -CreateRestorePoint:$CreateRestorePoint

Write-Host "`n📋 修复会话信息:" -ForegroundColor Cyan
Write-Host "   会话 ID: $($session.SessionId)" -ForegroundColor White
Write-Host "   修复类型：$($session.RepairType)" -ForegroundColor White
Write-Host "   修复目标：$($session.Target)" -ForegroundColor White
Write-Host "   开始时间：$($session.StartedAt)" -ForegroundColor Gray

# 创建备份快照（如果启用）
if ($UseBackupSnapshot) {
    Write-Host "`n📦 正在创建快速备份快照..." -ForegroundColor Cyan
    
    $snapshotParams = @{
        Type = "Registry"
        Paths = @()
    }
    
    # 根据修复类型确定备份路径
    switch ($RepairType) {
        "DisableWindowsUpdate" {
            $snapshotParams.Paths = @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate")
        }
        "EnableDefender" {
            $snapshotParams.Paths = @("HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender")
        }
        "DisableTelemetry" {
            $snapshotParams.Paths = @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection")
        }
    }
    
    if ($snapshotParams.Paths.Count -gt 0) {
        $snapshot = Create-BackupSnapshot @snapshotParams
        
        if ($snapshot) {
            $session.BackupSnapshotId = $snapshot.SnapshotId
            Write-Host "   ✅ 备份快照已创建：$($snapshot.SnapshotId)" -ForegroundColor Green
            Write-Host "   备份大小：$($snapshot.Size)" -ForegroundColor Gray
        }
    }
}

# 执行修复操作
Write-Host "`n🔧 开始执行修复..." -ForegroundColor Cyan

$repairSuccess = $true
$registryChanges = @()

try {
    switch ($RepairType) {
        "DisableWindowsUpdate" {
            $registryChanges = Invoke-WindowsUpdateRepair -Action "Disable"
        }
        "EnableDefender" {
            $registryChanges = Invoke-DefenderRepair -Action "Enable"
        }
        "DisableTelemetry" {
            $registryChanges = Invoke-TelemetryRepair -Action "Disable"
        }
        "ResetNetwork" {
            $changes = Invoke-NetworkReset
        }
        "CleanSystem" {
            Write-Host "  🧹 清理系统临时文件..." -ForegroundColor Yellow
            $tempPath = $env:TEMP
            if (Test-Path $tempPath) {
                Get-ChildItem -Path $tempPath -Directory -Force | ForEach-Object {
                    Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
                Get-ChildItem -Path $tempPath -File -Force | Remove-Item -Force -ErrorAction SilentlyContinue
                Write-Host "  ✅ 临时文件清理完成" -ForegroundColor Green
            }
        }
        "Custom" {
            if ($Target) {
                # 命令白名单映射表
                $allowedCommands = @{
                    "ClearEventLogs"     = { Clear-EventLog -LogName Application, System, Security -ErrorAction SilentlyContinue }
                    "ResetNetworkStack"  = { netsh int ip reset | Out-Null; netsh winsock reset | Out-Null }
                    "FlushDNS"           = { Clear-DnsClientCache -ErrorAction SilentlyContinue }
                    "RepairSystemFiles"  = { sfc /scannow }
                    "CleanTempFiles"     = { Get-ChildItem $env:TEMP -Directory -Force | ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }; Get-ChildItem $env:TEMP -File -Force | Remove-Item -Force -ErrorAction SilentlyContinue }
                    "ResetWindowsStore"  = { wsreset.exe }
                }
                
                if ($allowedCommands.ContainsKey($Target)) {
                    Write-Host "  🔧 执行自定义修复：$Target" -ForegroundColor Yellow
                    Log-RepairCommand -SessionId $session.SessionId -Command $Target -Status "Success"
                    & $allowedCommands[$Target]
                } else {
                    Write-Host "  ❌ 不支持的自定义命令：$Target" -ForegroundColor Red
                    Write-Host "  支持的命令：$($allowedCommands.Keys -join ', ')" -ForegroundColor Yellow
                    $repairSuccess = $false
                }
            } else {
                Write-Host "  ❌ 自定义修复需要指定 Target 参数" -ForegroundColor Red
                $repairSuccess = $false
            }
        }
    }
} catch {
    Write-Host "  ❌ 修复执行失败：$($_.Exception.Message)" -ForegroundColor Red
    $repairSuccess = $false
}

# 记录修复命令
if ($repairSuccess) {
    Log-RepairCommand -SessionId $session.SessionId -Command $RepairType -Parameters @{ Target = $Target } -Status "Success"
} else {
    Log-RepairCommand -SessionId $session.SessionId -Command $RepairType -Parameters @{ Target = $Target } -Status "Failed"
}

# 完成修复会话
if ($repairSuccess) {
    Complete-RepairSession -SessionId $session.SessionId -Status "Success" -BackupSnapshotId $session.BackupSnapshotId
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  ✅ 修复成功完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    Write-Host "`n📊 会话摘要:" -ForegroundColor Cyan
    Write-Host "   执行命令数：$($session.CommandsExecuted)" -ForegroundColor White
    
    if ($session.RestorePointId) {
        Write-Host "   系统还原点：✅ 已创建 ($($session.RestorePointId))" -ForegroundColor Green
    }
    
    if ($session.BackupSnapshotId) {
        Write-Host "   快速备份：✅ 已创建 ($($session.BackupSnapshotId))" -ForegroundColor Green
    }
    
    if ($session.CanUndo) {
        Write-Host "`n🔄 此修复可以撤销" -ForegroundColor Cyan
        Write-Host "   使用以下命令撤销：" -ForegroundColor Gray
        Write-Host "   Undo-RepairSession -SessionId `"$($session.SessionId)`"" -ForegroundColor Yellow
    }
} else {
    Complete-RepairSession -SessionId $session.SessionId -Status "Failed"
    
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "  ❌ 修复失败" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
}

Write-Host ""
