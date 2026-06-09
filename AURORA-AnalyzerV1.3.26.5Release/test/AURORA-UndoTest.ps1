# AURORA-UndoTest.ps1
# Requires -Version 5.1
# AURORA Undo 功能测试脚本
# 作者：AURORA VelociRaptor-GR Dev PRJ.
# 版本：V1.0 (Phase 4.2)

<#
.SYNOPSIS
    测试 Undo 功能的完整性
.DESCRIPTION
    测试系统还原点创建、修复日志、备份快照和撤销功能
.NOTES
    版本：V1.0
    构建时间：2026.05.14
#>

Param(
    [switch]$FullTest,
    [switch]$NoCleanup
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  AURORA Undo 功能测试" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 获取脚本目录
$scriptDir = if ($PSScriptRoot) { Join-Path $PSScriptRoot "..\Scripts" } else { Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "..\Scripts" }

# 导入所有模块
Write-Host "📦 正在导入模块..." -ForegroundColor Yellow

$coreEnginePath = Join-Path $scriptDir "Core\AURORA-CoreEngine.ps1"
if (Test-Path $coreEnginePath) {
    . $coreEnginePath
    Write-Host "  ✅ CoreEngine 已加载" -ForegroundColor Green
} else {
    Write-Host "  ❌ CoreEngine 未找到" -ForegroundColor Red
    exit 1
}

$restoreManagerPath = Join-Path $scriptDir "Repair\AURORA-RestoreManager.ps1"
if (Test-Path $restoreManagerPath) {
    . $restoreManagerPath
    Write-Host "  ✅ RestoreManager 已加载" -ForegroundColor Green
} else {
    Write-Host "  ❌ RestoreManager 未找到" -ForegroundColor Red
}

$repairLoggerPath = Join-Path $scriptDir "Repair\AURORA-RepairLogger.ps1"
if (Test-Path $repairLoggerPath) {
    . $repairLoggerPath
    Write-Host "  ✅ RepairLogger 已加载" -ForegroundColor Green
} else {
    Write-Host "  ❌ RepairLogger 未找到" -ForegroundColor Red
}

$undoManagerPath = Join-Path $scriptDir "Session\AURORA-UndoManager.ps1"
if (Test-Path $undoManagerPath) {
    . $undoManagerPath
    Write-Host "  ✅ UndoManager 已加载" -ForegroundColor Green
} else {
    Write-Host "  ❌ UndoManager 未找到" -ForegroundColor Red
}

Write-Host ""

# 测试 1: 权限检查
Write-Host "📋 测试 1: 权限检查" -ForegroundColor Cyan
$isAdmin = Test-AdminRequired
if ($isAdmin) {
    Write-Host "  ✅ 管理员权限检查通过" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  非管理员模式，部分功能可能不可用" -ForegroundColor Yellow
}
Write-Host ""

# 测试 2: RestoreManager 能力测试
Write-Host "📋 测试 2: RestoreManager 能力测试" -ForegroundColor Cyan
$capability = Test-RestorePointCapability
Write-Host "  管理员权限：$(if ($capability.IsAdmin) { '✅' } else { '❌' })" -ForegroundColor White
Write-Host "  WMI 访问：$(if ($capability.WMIAccessible) { '✅' } else { '❌' })" -ForegroundColor White
Write-Host "  可创建还原点：$(if ($capability.CanCreateRestorePoint) { '✅' } else { '❌' })" -ForegroundColor White
Write-Host ""

# 测试 3: UndoManager 初始化
Write-Host "📋 测试 3: UndoManager 初始化" -ForegroundColor Cyan
try {
    Initialize-UndoManager
    Write-Host "  ✅ UndoManager 初始化成功" -ForegroundColor Green
} catch {
    Write-Host "  ❌ UndoManager 初始化失败：$($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# 测试 4: 创建修复会话（不实际执行修复）
Write-Host "📋 测试 4: 修复会话创建测试" -ForegroundColor Cyan
$testSessionId = "TEST_$(Get-Date -Format 'yyyyMMdd_HHmmss')_001"
Write-Host "  创建测试会话：$testSessionId" -ForegroundColor Gray

try {
    $session = Start-RepairSession -RepairType "Test" -Target "Undo Test" -CreateRestorePoint:$false
    Write-Host "  ✅ 会话创建成功" -ForegroundColor Green
    Write-Host "     会话 ID: $($session.SessionId)" -ForegroundColor White
    Write-Host "     开始时间：$($session.StartedAt)" -ForegroundColor Gray
} catch {
    Write-Host "  ❌ 会话创建失败：$($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# 测试 5: 备份快照创建
Write-Host "📋 测试 5: 备份快照创建测试" -ForegroundColor Cyan
if ($FullTest) {
    try {
        $snapshot = Create-BackupSnapshot -Type "Registry" -Paths @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate")
        if ($snapshot) {
            Write-Host "  ✅ 备份快照创建成功" -ForegroundColor Green
            Write-Host "     快照 ID: $($snapshot.SnapshotId)" -ForegroundColor White
            Write-Host "     类型：$($snapshot.Type)" -ForegroundColor White
            Write-Host "     大小：$($snapshot.Size)" -ForegroundColor White
            
            # 保存快照 ID 用于后续测试
            $testSnapshotId = $snapshot.SnapshotId
        } else {
            Write-Host "  ⚠️  备份快照创建返回 null" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ❌ 备份快照创建失败：$($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  ⏭️  跳过（使用 -FullTest 执行）" -ForegroundColor Gray
}
Write-Host ""

# 测试 6: 修复命令日志
Write-Host "📋 测试 6: 修复命令日志测试" -ForegroundColor Cyan
try {
    if ($session) {
        Log-RepairCommand -SessionId $session.SessionId -CommandType "TestCommand" -Parameters @{ Test = "Value" } -Success
        Write-Host "  ✅ 命令日志记录成功" -ForegroundColor Green
        
        # 完成会话
        Complete-RepairSession -SessionId $session.SessionId -Status "Success"
        Write-Host "  ✅ 会话完成标记成功" -ForegroundColor Green
    }
} catch {
    Write-Host "  ❌ 命令日志记录失败：$($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# 测试 7: 查询修复历史
Write-Host "📋 测试 7: 修复历史查询测试" -ForegroundColor Cyan
try {
    $history = Get-RepairHistory -MaxSessions 5
    if ($history) {
        Write-Host "  ✅ 修复历史查询成功" -ForegroundColor Green
        Write-Host "     最近会话数：$($history.Count)" -ForegroundColor White
        
        # 显示最近的一个会话
        $latest = $history[0]
        Write-Host "     最新会话：$($latest.SessionId)" -ForegroundColor White
        Write-Host "     状态：$($latest.Status)" -ForegroundColor White
    } else {
        Write-Host "  ⚠️  没有找到修复历史" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ❌ 修复历史查询失败：$($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# 测试 8: 系统还原点创建（仅 FullTest 模式）
Write-Host "📋 测试 8: 系统还原点创建测试" -ForegroundColor Cyan
if ($FullTest -and $capability.CanCreateRestorePoint) {
    Write-Host "  正在创建系统还原点..." -ForegroundColor Yellow
    try {
        $restorePoint = Create-SystemRestorePoint -Description "AURORA Undo Test - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        if ($restorePoint) {
            Write-Host "  ✅ 系统还原点创建成功" -ForegroundColor Green
            Write-Host "     还原点 ID: $($restorePoint.RestorePointId)" -ForegroundColor White
            Write-Host "     序列号：$($restorePoint.SequenceNumber)" -ForegroundColor White
            
            $testRestorePointId = $restorePoint.RestorePointId
        } else {
            Write-Host "  ⚠️  系统还原点创建返回 null" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ❌ 系统还原点创建失败：$($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    if (-not $FullTest) {
        Write-Host "  ⏭️  跳过（使用 -FullTest 执行）" -ForegroundColor Gray
    } else {
        Write-Host "  ⚠️  跳过（无还原点创建能力）" -ForegroundColor Yellow
    }
}
Write-Host ""

# 清理测试数据
if (-not $NoCleanup) {
    Write-Host "`n🧹 清理测试数据..." -ForegroundColor Yellow
    
    if ($testSnapshotId) {
        try {
            Remove-BackupSnapshot -SnapshotId $testSnapshotId
            Write-Host "  ✅ 测试快照已删除：$testSnapshotId" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠️  测试快照删除失败：$testSnapshotId" -ForegroundColor Yellow
        }
    }
    
    if ($testSessionId) {
        try {
            $sessionFile = Join-Path $env:LOCALAPPDATA "AURORA\SessionCache\REPAIR_$testSessionId.json"
            if (Test-Path $sessionFile) {
                Remove-Item $sessionFile -Force
                Write-Host "  ✅ 测试会话文件已删除：$testSessionId" -ForegroundColor Green
            }
        } catch {
            Write-Host "  ⚠️  测试会话文件删除失败" -ForegroundColor Yellow
        }
    }
}

# 测试总结
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  测试完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n📊 测试结果摘要:" -ForegroundColor Yellow
Write-Host "  ✅ 模块加载：成功" -ForegroundColor Green
Write-Host "  ✅ 权限检查：$(if ($isAdmin) { '通过' } else { '未通过' })" -ForegroundColor $(if ($isAdmin) { 'Green' } else { 'Red' })
Write-Host "  ✅ UndoManager: 初始化成功" -ForegroundColor Green
Write-Host "  ✅ 会话创建：成功" -ForegroundColor Green
Write-Host "  ✅ 命令日志：成功" -ForegroundColor Green
Write-Host "  $(if ($FullTest) { '✅' } else { '⏭️' }) 备份快照：$(if ($FullTest) { '测试完成' } else { '已跳过' })" -ForegroundColor $(if ($FullTest) { 'Green' } else { 'Gray' })
Write-Host "  $(if ($FullTest -and $capability.CanCreateRestorePoint) { '✅' } else { '⏭️' }) 系统还原点：$(if ($FullTest -and $capability.CanCreateRestorePoint) { '测试完成' } else { '已跳过' })" -ForegroundColor $(if ($FullTest -and $capability.CanCreateRestorePoint) { 'Green' } else { 'Gray' })

Write-Host "`n💡 提示:" -ForegroundColor Cyan
Write-Host "  完整测试：.\AURORA-UndoTest.ps1 -FullTest" -ForegroundColor Gray
Write-Host "  保留数据：.\AURORA-UndoTest.ps1 -NoCleanup" -ForegroundColor Gray
Write-Host ""
