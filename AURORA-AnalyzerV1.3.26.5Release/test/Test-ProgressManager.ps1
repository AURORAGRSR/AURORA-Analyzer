# ==========================================
# AURORA 进度管理器测试脚本
# 用于验证进度管理器的基本功能
# ==========================================

[CmdletBinding()]
param(
    [switch]$TestBasic,
    [switch]$TestSaveRestore,
    [switch]$TestCleanup,
    [switch]$All
)

# 导入进度管理器
. "$PSScriptRoot\..\Scripts\Session\AURORA-ProgressManager.ps1"

# 初始化缓存目录
Write-Host "`n=== 初始化缓存目录 ===" -ForegroundColor Cyan
$toolPath = Join-Path $PSScriptRoot "..\Scripts"
$initialized = Initialize-CacheDirectory -ToolPath $toolPath
Write-Host "初始化结果：$initialized" -ForegroundColor $(if ($initialized) { 'Green' } else { 'Red' })
Write-Host "缓存根目录：$script:CacheRoot" -ForegroundColor Yellow
Write-Host "活动目录：$script:ActiveDir" -ForegroundColor Yellow
Write-Host "检查点目录：$script:CheckpointsDir" -ForegroundColor Yellow
Write-Host "归档目录：$script:ArchiveDir" -ForegroundColor Yellow

# 测试 1: 基础功能测试
if ($TestBasic -or $All) {
    Write-Host "`n=== 测试 1: 创建会话 ===" -ForegroundColor Cyan
    $sessionId = New-Session -SessionType "TestTask" -Metadata @{ TestName = "BasicTest" }
    Write-Host "会话 ID: $sessionId" -ForegroundColor Green
    
    Write-Host "`n=== 测试 1: 保存进度 ===" -ForegroundColor Cyan
    Save-SessionProgress -SessionId $sessionId -Stage "Testing" -Progress 25 -AdditionalData @{ TestField = "TestData" }
    Write-Host "进度已保存" -ForegroundColor Green
    
    Write-Host "`n=== 测试 1: 创建检查点 ===" -ForegroundColor Cyan
    Save-SessionProgress -SessionId $sessionId -Stage "Checkpoint" -Progress 50 -CreateCheckpoint
    Write-Host "检查点已创建" -ForegroundColor Green
    
    Write-Host "`n=== 测试 1: 获取统计信息 ===" -ForegroundColor Cyan
    $stats = Get-SessionStatistics
    Write-Host "活动会话数：$($stats.ActiveSessions)" -ForegroundColor Yellow
    Write-Host "检查点数：$($stats.Checkpoints)" -ForegroundColor Yellow
    Write-Host "归档会话数：$($stats.ArchivedSessions)" -ForegroundColor Yellow
    Write-Host "总大小：$($stats.TotalSizeMB) MB" -ForegroundColor Yellow
    
    # 清理测试会话
    Remove-SessionProgress -SessionId $sessionId
    Write-Host "`n测试会话已清理" -ForegroundColor Yellow
}

# 测试 2: 保存与恢复测试
if ($TestSaveRestore -or $All) {
    Write-Host "`n=== 测试 2: 保存与恢复 ===" -ForegroundColor Cyan
    
    # 创建并保存会话
    $sessionId = New-Session -SessionType "ExportTask" -Metadata @{ LogType = "System" }
    Write-Host "创建会话：$sessionId" -ForegroundColor Green
    
    Save-SessionProgress -SessionId $sessionId -Stage "Initialized" -Progress 5 -AdditionalData @{ ExportedFiles = @("file1.csv", "file2.json") }
    Start-Sleep -Milliseconds 500
    Save-SessionProgress -SessionId $sessionId -Stage "Configuring" -Progress 20
    Start-Sleep -Milliseconds 500
    Save-SessionProgress -SessionId $sessionId -Stage "Exporting" -Progress 60
    Start-Sleep -Milliseconds 500
    Save-SessionProgress -SessionId $sessionId -Stage "Analyzing" -Progress 80 -CreateCheckpoint
    
    Write-Host "`n会话进度已保存" -ForegroundColor Green
    
    # 模拟程序重启：清除内存中的会话信息
    $script:CurrentSessionId = $null
    $script:SessionData = @{}
    
    Write-Host "`n模拟程序重启，内存已清空" -ForegroundColor Yellow
    
    # 检测并恢复会话
    if (Test-PendingSession) {
        Write-Host "`n检测到未完成的会话" -ForegroundColor Cyan
        $restoredSession = Restore-SessionProgress
        
        if ($restoredSession) {
            Write-Host "`n=== 恢复成功 ===" -ForegroundColor Green
            Write-Host "会话 ID: $($restoredSession.SessionId)" -ForegroundColor Yellow
            Write-Host "进度：$($restoredSession.Progress)%" -ForegroundColor Yellow
            Write-Host "阶段：$($restoredSession.Stage)" -ForegroundColor Yellow
            Write-Host "已挂起：$($restoredSession.AgeInDays) 天" -ForegroundColor Yellow
            
            if ($restoredSession.Data.ExportedFiles) {
                Write-Host "导出数据：$($restoredSession.Data.ExportedFiles -join ', ')" -ForegroundColor Yellow
            }
            
            # 完成会话
            Complete-Session -SessionId $restoredSession.SessionId -Archive
            Write-Host "`n会话已完成并归档" -ForegroundColor Green
        }
    } else {
        Write-Host "`n未找到可恢复的会话" -ForegroundColor Yellow
    }
}

# 测试 3: 清理功能测试
if ($TestCleanup -or $All) {
    Write-Host "`n=== 测试 3: 清理过期缓存 ===" -ForegroundColor Cyan
    
    # 创建一些测试会话
    1..3 | ForEach-Object {
        $sessionId = New-Session -SessionType "Test" -Metadata @{ Test = $_ }
        Save-SessionProgress -SessionId $sessionId -Stage "Test" -Progress ($_ * 10)
        
        # 修改文件时间以模拟过期
        $activeFile = Join-Path $script:ActiveDir "${sessionId}.json"
        if (Test-Path $activeFile) {
            $oldTime = (Get-Date).AddDays(-10)
            (Get-Item $activeFile).LastWriteTime = $oldTime
        }
    }
    
    Write-Host "创建了 3 个过期的测试会话" -ForegroundColor Yellow
    
    # 执行清理
    $cleanedCount = Invoke-CacheCleanup -RetentionDays 7
    Write-Host "清理了 $cleanedCount 个文件" -ForegroundColor Green
    
    # 显示清理后的统计
    $stats = Get-SessionStatistics
    Write-Host "`n清理后统计:" -ForegroundColor Cyan
    Write-Host "活动会话数：$($stats.ActiveSessions)" -ForegroundColor Yellow
    Write-Host "总大小：$($stats.TotalSizeMB) MB" -ForegroundColor Yellow
}

# 显示最终统计
Write-Host "`n=== 最终统计 ===" -ForegroundColor Cyan
$stats = Get-SessionStatistics
Write-Host "活动会话：$($stats.ActiveSessions)" -ForegroundColor Yellow
Write-Host "检查点：$($stats.Checkpoints)" -ForegroundColor Yellow
Write-Host "归档会话：$($stats.ArchivedSessions)" -ForegroundColor Yellow
Write-Host "总大小：$($stats.TotalSizeMB) MB" -ForegroundColor Yellow

Write-Host "`n✅ 测试完成!" -ForegroundColor Green
Write-Host "`n提示：使用以下参数运行特定测试:" -ForegroundColor Cyan
Write-Host "  -TestBasic     : 测试基础功能" -ForegroundColor Gray
Write-Host "  -TestSaveRestore: 测试保存与恢复" -ForegroundColor Gray
Write-Host "  -TestCleanup   : 测试清理功能" -ForegroundColor Gray
Write-Host "  -All           : 运行所有测试" -ForegroundColor Gray
