<#
.SYNOPSIS
    AURORA Undo 查看器和管理工具
.DESCRIPTION
    查看所有修复会话历史，支持撤销操作
    支持系统还原点和快速备份两种撤销方式
.PARAMETER SessionId
    可选。指定要查看或撤销的会话 ID
.PARAMETER Action
    指定操作类型：View, Undo, List, Details
.PARAMETER UseSystemRestore
    开关参数。使用系统还原点撤销（需要重启）
.PARAMETER GUI_Mode
    开关参数。标记是否在 GUI 模式下运行。
.NOTES
    版本：V1.3.26.7Release | 构建时间：2026.06.22
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>

Param(
    [string]$SessionId,
    
    [ValidateSet("View", "Undo", "List", "Details", "Cleanup")]
    [string]$Action = "List",
    
    [switch]$UseSystemRestore,
    
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

# 导入 RepairLogger
$repairLoggerPath = Join-Path (Join-Path $parentDir "Repair") "AURORA-RepairLogger.ps1"
if (Test-Path $repairLoggerPath) {
    . $repairLoggerPath
}

# 导入 UndoManager（同目录）
$undoManagerPath = Join-Path $scriptDir "AURORA-UndoManager.ps1"
if (Test-Path $undoManagerPath) {
    . $undoManagerPath
}

# ==========================================
# 📋 显示函数
# ==========================================

function Show-SessionList {
    param([int]$MaxSessions = 20)
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  AURORA 修复会话列表" -ForegroundColor Cyan
    Write-Host "  (最近 $MaxSessions 条记录)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # 获取最近的修复会话
    $sessions = Get-RepairHistory -MaxSessions $MaxSessions
    
    if (-not $sessions -or $sessions.Count -eq 0) {
        Write-Host "没有找到修复会话记录" -ForegroundColor Gray
        return
    }
    
    # 显示表格头部
    Write-Host ("{0,-35} {1,-20} {2,-15} {3,-10} {4,-10}" -f "会话 ID", "修复类型", "时间", "状态", "可撤销") -ForegroundColor Yellow
    Write-Host ("{0,-35} {1,-20} {2,-15} {3,-10} {4,-10}" -f "-" * 35, "-" * 20, "-" * 15, "-" * 10, "-" * 10) -ForegroundColor Gray
    
    # 显示每个会话
    foreach ($session in $sessions) {
        $canUndo = if ($session.CanUndo) { "✅ 是" } else { "❌ 否" }
        
        $statusIcon = switch ($session.Status) {
            "Success" { "✅" }
            "Failed" { "❌" }
            "Partial" { "⚠️" }
            "Undone" { "🔄" }
            "InProgress" { "⏳" }
            default { "•" }
        }
        
        $time = if ($session.CompletedAt) {
            (Get-Date $session.CompletedAt).ToString("MM-dd HH:mm")
        } else {
            (Get-Date $session.StartedAt).ToString("MM-dd HH:mm")
        }
        
        Write-Host ("{0,-35} {1,-20} {2,-15} {3,-10} {4,-10}" -f 
            $session.SessionId,
            $session.RepairType,
            $time,
            "$statusIcon $($session.Status)",
            $canUndo
        ) -ForegroundColor White
    }
    
    Write-Host "`n💡 提示:" -ForegroundColor Cyan
    Write-Host "  查看详细：AURORA-UndoViewer.ps1 -Action Details -SessionId <会话 ID>" -ForegroundColor Gray
    Write-Host "  撤销操作：AURORA-UndoViewer.ps1 -Action Undo -SessionId <会话 ID>" -ForegroundColor Gray
    Write-Host "  清理记录：AURORA-UndoViewer.ps1 -Action Cleanup" -ForegroundColor Gray
}

function Show-SessionDetails {
    param([Parameter(Mandatory=$true)][string]$SessionId)
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  修复会话详细信息" -ForegroundColor Cyan
    Write-Host "  会话 ID: $SessionId" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # 获取会话详情
    $session = Get-RepairSession -SessionId $SessionId
    
    if (-not $session) {
        Write-Host "❌ 未找到会话：$SessionId" -ForegroundColor Red
        return
    }
    
    # 基本信息
    Write-Host "📋 基本信息:" -ForegroundColor Yellow
    Write-Host "  会话 ID:      $($session.SessionId)" -ForegroundColor White
    Write-Host "  修复类型：    $($session.RepairType)" -ForegroundColor White
    Write-Host "  修复目标：    $($session.Target)" -ForegroundColor White
    Write-Host "  开始时间：    $($session.StartedAt)" -ForegroundColor Gray
    Write-Host "  完成时间：    $($session.CompletedAt)" -ForegroundColor Gray
    Write-Host "  状态：        $($session.Status)" -ForegroundColor White
    
    # 还原点信息
    Write-Host "`n📦 备份信息:" -ForegroundColor Yellow
    if ($session.RestorePointId) {
        Write-Host "  系统还原点：✅ 已创建 ($($session.RestorePointId))" -ForegroundColor Green
        
        # 获取还原点详情
        $restorePoint = Get-RestorePointMetadata -RestorePointId $session.RestorePointId
        if ($restorePoint) {
            Write-Host "    描述：$($restorePoint.Description)" -ForegroundColor Gray
            Write-Host "    类型：$($restorePoint.Type)" -ForegroundColor Gray
            Write-Host "    过期时间：$($restorePoint.ExpiresAt)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  系统还原点：❌ 未创建" -ForegroundColor Gray
    }
    
    if ($session.BackupSnapshotId) {
        Write-Host "  快速备份：  ✅ 已创建 ($($session.BackupSnapshotId))" -ForegroundColor Green
        
        # 获取备份快照详情
        $snapshot = Get-SnapshotMetadata -SnapshotId $session.BackupSnapshotId
        if ($snapshot) {
            Write-Host "    类型：$($snapshot.Type)" -ForegroundColor Gray
            Write-Host "    大小：$($snapshot.Size)" -ForegroundColor Gray
            Write-Host "    项目数：$($snapshot.Items.Count)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  快速备份：  ❌ 未创建" -ForegroundColor Gray
    }
    
    # 撤销能力
    Write-Host "`n🔄 撤销能力:" -ForegroundColor Yellow
    if ($session.CanUndo) {
        Write-Host "  状态：✅ 可以撤销" -ForegroundColor Green
        
        if ($session.RestorePointId) {
            Write-Host "  方式 1: 系统还原（需要重启）" -ForegroundColor Cyan
        }
        if ($session.BackupSnapshotId) {
            Write-Host "  方式 2: 快速备份（无需重启）" -ForegroundColor Cyan
        }
        
        Write-Host "`n⚡ 撤销命令:" -ForegroundColor Yellow
        Write-Host "  # 使用快速备份（推荐）" -ForegroundColor Gray
        Write-Host "  Undo-RepairSession -SessionId `"$SessionId`"" -ForegroundColor White
        Write-Host ""
        Write-Host "  # 使用系统还原点" -ForegroundColor Gray
        Write-Host "  Undo-RepairSession -SessionId `"$SessionId`" -UseSystemRestore" -ForegroundColor White
    } else {
        Write-Host "  状态：❌ 无法撤销" -ForegroundColor Red
        
        if ($session.Status -eq "Failed") {
            Write-Host "  原因：修复失败，无需撤销" -ForegroundColor Gray
        } elseif ($session.Status -eq "Undone") {
            Write-Host "  原因：已经撤销" -ForegroundColor Gray
        }
    }
    
    # 执行的命令
    if ($session.Commands -and $session.Commands.Count -gt 0) {
        Write-Host "`n🔧 执行的命令:" -ForegroundColor Yellow
        Write-Host "  总命令数：$($session.CommandsExecuted)" -ForegroundColor White
        
        foreach ($cmd in $session.Commands) {
            $icon = if ($cmd.Success) { "✅" } else { "❌" }
            Write-Host "    $icon $($cmd.CommandType) - $($cmd.ExecutedAt)" -ForegroundColor White
        }
    }
}

function Invoke-SessionUndo {
    param([Parameter(Mandatory=$true)][string]$SessionId)
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  执行撤销操作" -ForegroundColor Cyan
    Write-Host "  会话 ID: $SessionId" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # 获取会话信息
    $session = Get-RepairSession -SessionId $SessionId
    
    if (-not $session) {
        Write-Host "❌ 未找到会话：$SessionId" -ForegroundColor Red
        return
    }
    
    if (-not $session.CanUndo) {
        Write-Host "❌ 此会话无法撤销" -ForegroundColor Red
        
        if ($session.Status -eq "Undone") {
            Write-Host "   原因：已经撤销过了" -ForegroundColor Gray
        } elseif ($session.Status -eq "Failed") {
            Write-Host "   原因：修复失败，无需撤销" -ForegroundColor Gray
        }
        
        return
    }
    
    # 确认撤销
    Write-Host "⚠️  警告：撤销操作将恢复系统到修复前的状态" -ForegroundColor Yellow
    Write-Host ""
    
    if ($UseSystemRestore) {
        Write-Host "📌 撤销方式：系统还原点（需要重启）" -ForegroundColor Cyan
        Write-Host "   还原点 ID: $($session.RestorePointId)" -ForegroundColor Gray
    } elseif ($session.BackupSnapshotId) {
        Write-Host "📌 撤销方式：快速备份（无需重启）" -ForegroundColor Cyan
        Write-Host "   快照 ID: $($session.BackupSnapshotId)" -ForegroundColor Gray
    } else {
        Write-Host "❌ 没有可用的还原方式" -ForegroundColor Red
        return
    }
    
    Write-Host ""
    Write-Host "按 [Y] 确认撤销，按 [N] 取消：" -ForegroundColor Yellow
    $confirm = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    if ($confirm.VirtualKeyCode -ne 89) {  # 89 = Y
        Write-Host "❌ 撤销已取消" -ForegroundColor Gray
        return
    }
    
    # 执行撤销
    Write-Host "`n🔄 正在执行撤销..." -ForegroundColor Cyan
    
    try {
        $result = Undo-RepairSession -SessionId $SessionId -UseSystemRestore:$UseSystemRestore
        
        if ($result) {
            Write-Host "`n========================================" -ForegroundColor Green
            Write-Host "  ✅ 撤销成功！" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            
            if ($UseSystemRestore) {
                Write-Host "`n⚠️  系统将在 10 秒后重启以完成还原..." -ForegroundColor Yellow
                Start-Sleep -Seconds 10
                Restart-Computer -Force
            }
        } else {
            Write-Host "`n❌ 撤销失败" -ForegroundColor Red
            Write-Host "   错误信息：$result" -ForegroundColor Gray
        }
    } catch {
        Write-Host "`n❌ 撤销过程发生错误" -ForegroundColor Red
        Write-Host "   错误：$($_.Exception.Message)" -ForegroundColor Gray
    }
}

function Invoke-SessionCleanup {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  清理过期会话记录" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # 这里可以实现清理过期会话的逻辑
    # 目前只显示统计信息
    
    $allSessions = Get-RepairHistory -MaxSessions 1000
    
    if (-not $allSessions) {
        Write-Host "没有会话记录需要清理" -ForegroundColor Gray
        return
    }
    
    $totalSessions = $allSessions.Count
    $undoneSessions = ($allSessions | Where-Object { $_.Status -eq "Undone" }).Count
    $failedSessions = ($allSessions | Where-Object { $_.Status -eq "Failed" }).Count
    $successSessions = ($allSessions | Where-Object { $_.Status -eq "Success" }).Count
    
    Write-Host "📊 会话统计:" -ForegroundColor Yellow
    Write-Host "  总会话数：$totalSessions" -ForegroundColor White
    Write-Host "  成功：$successSessions" -ForegroundColor Green
    Write-Host "  失败：$failedSessions" -ForegroundColor Red
    Write-Host "  已撤销：$undoneSessions" -ForegroundColor Cyan
    
    Write-Host "`n💡 提示:" -ForegroundColor Cyan
    Write-Host "  清理功能尚未实现，手动删除 SessionCache 目录中的 JSON 文件" -ForegroundColor Gray
}

# ==========================================
# 🚀 主执行流程
# ==========================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  AURORA Undo 查看器 V1.0" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 根据 Action 执行不同操作
switch ($Action) {
    "List" {
        Show-SessionList
    }
    "Details" {
        if ($SessionId) {
            Show-SessionDetails -SessionId $SessionId
        } else {
            Write-Host "❌ 需要指定 SessionId 参数" -ForegroundColor Red
            Write-Host "   使用：AURORA-UndoViewer.ps1 -Action Details -SessionId <会话 ID>" -ForegroundColor Yellow
        }
    }
    "Undo" {
        if ($SessionId) {
            Invoke-SessionUndo -SessionId $SessionId
        } else {
            Write-Host "❌ 需要指定 SessionId 参数" -ForegroundColor Red
            Write-Host "   使用：AURORA-UndoViewer.ps1 -Action Undo -SessionId <会话 ID>" -ForegroundColor Yellow
        }
    }
    "Cleanup" {
        Invoke-SessionCleanup
    }
    "View" {
        # 默认显示列表
        Show-SessionList
    }
}

Write-Host ""
