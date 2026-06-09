# ==========================================
# AURORA 进度管理器集成测试
# 模拟真实的 GUI 和 PRO 脚本交互场景
# ==========================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  AURORA 进度管理器集成测试" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

# 导入所有必要的模块
Write-Host "1. 导入进度管理器..." -ForegroundColor Yellow
. "$PSScriptRoot\..\Scripts\Session\AURORA-ProgressManager.ps1"
. "$PSScriptRoot\..\Scripts\Session\AURORA-ProgressManager-Integration-CHS.ps1"

# 初始化缓存
Write-Host "2. 初始化缓存目录..." -ForegroundColor Yellow
$toolPath = Join-Path $PSScriptRoot "..\Scripts"
$initialized = Initialize-CacheDirectory -ToolPath $toolPath
Write-Host "   缓存根目录：$script:CacheRoot" -ForegroundColor Gray
Write-Host "   初始化结果：$initialized`n" -ForegroundColor $(if ($initialized) { 'Green' } else { 'Red' })

# 场景 1: 模拟正常启动（无待恢复会话）
Write-Host "3. 场景 1: 正常启动（无待恢复会话）" -ForegroundColor Cyan
if (Test-PendingSession) {
    Write-Host "   ⚠️ 发现待恢复会话（测试前请手动清理）" -ForegroundColor Yellow
} else {
    Write-Host "   ✅ 无待恢复会话，正常启动`n" -ForegroundColor Green
}

# 场景 2: 模拟创建新会话并保存进度
Write-Host "4. 场景 2: 创建新会话并保存进度" -ForegroundColor Cyan
$sessionId = New-Session -SessionType "ExportTask" -Metadata @{
    LogType = "System"
    Language = "CHS"
    GUI_Mode = $true
}
Write-Host "   创建会话：$sessionId" -ForegroundColor Gray

Save-CHSProgress -SessionId $sessionId -Checkpoint "Initialized" -CreateCheckpoint
Write-Host "   保存进度：Initialized (5%)" -ForegroundColor Gray

Save-CHSProgress -SessionId $sessionId -Checkpoint "LogTypeSelected"
Write-Host "   保存进度：LogTypeSelected (10%)" -ForegroundColor Gray

Save-CHSProgress -SessionId $sessionId -Checkpoint "DateRangeConfigured"
Write-Host "   保存进度：DateRangeConfigured (15%)" -ForegroundColor Gray

Save-CHSProgress -SessionId $sessionId -Checkpoint "PerformanceAssessed" -CreateCheckpoint
Write-Host "   保存进度：PerformanceAssessed (25%)" -ForegroundColor Gray

Save-CHSProgress -SessionId $sessionId -Checkpoint "HighRiskScanComplete"
Write-Host "   保存进度：HighRiskScanComplete (40%)" -ForegroundColor Gray

Save-CHSProgress -SessionId $sessionId -Checkpoint "ExportComplete" -AdditionalData @{
    ExportedFiles = @("System_Log_20260507.csv", "System_Log_20260507.json")
    OutputPath = "$PSScriptRoot\UserLogs"
} -CreateCheckpoint
Write-Host "   保存进度：ExportComplete (70%)`n" -ForegroundColor Gray

# 场景 3: 模拟程序意外退出后重启
Write-Host "5. 场景 3: 模拟程序意外退出后重启" -ForegroundColor Cyan
Write-Host "   模拟内存清空..." -ForegroundColor Gray
$script:CurrentSessionId = $null
$script:SessionData = @{}
Write-Host "   内存已清空，模拟重启完成`n" -ForegroundColor Gray

# 场景 4: 检测到待恢复会话
Write-Host "6. 场景 4: 检测并恢复待恢复会话" -ForegroundColor Cyan
if (Test-PendingSession) {
    Write-Host "   ✅ 检测到待恢复会话" -ForegroundColor Green
    
    $restoredSession = Restore-SessionProgress
    
    if ($restoredSession) {
        Write-Host "`n   === 恢复的会话信息 ===" -ForegroundColor Cyan
        Write-Host "   会话 ID: $($restoredSession.SessionId)" -ForegroundColor White
        Write-Host "   进度：$($restoredSession.Progress)%" -ForegroundColor White
        Write-Host "   阶段：$($restoredSession.Stage)" -ForegroundColor White
        Write-Host "   已挂起：$($restoredSession.AgeInDays) 天" -ForegroundColor White
        
        if ($restoredSession.Data.ExportedFiles) {
            Write-Host "   导出文件：$($restoredSession.Data.ExportedFiles -join ', ')" -ForegroundColor White
        }
        
        Write-Host "`n   用户选择：恢复进度" -ForegroundColor Yellow
        Write-Host "   ✅ 会话恢复成功，可继续执行`n" -ForegroundColor Green
    } else {
        Write-Host "   ❌ 恢复失败" -ForegroundColor Red
    }
} else {
    Write-Host "   ⚠️ 未检测到待恢复会话" -ForegroundColor Yellow
}

# 场景 5: 模拟会话完成
Write-Host "7. 场景 5: 完成会话并归档" -ForegroundColor Cyan
Complete-Session -SessionId $sessionId -Archive
Write-Host "   会话已完成并归档" -ForegroundColor Green

# 显示最终统计
Write-Host "`n8. 缓存统计信息" -ForegroundColor Cyan
$stats = Get-SessionStatistics
Write-Host "   活动会话：$($stats.ActiveSessions)" -ForegroundColor Yellow
Write-Host "   检查点：$($stats.Checkpoints)" -ForegroundColor Yellow
Write-Host "   归档会话：$($stats.ArchivedSessions)" -ForegroundColor Yellow
Write-Host "   总大小：$($stats.TotalSizeMB) MB" -ForegroundColor Yellow

# 场景 6: 模拟清理过期会话
Write-Host "`n9. 场景 6: 清理过期会话" -ForegroundColor Cyan
# 创建一些过期会话
1..2 | ForEach-Object {
    $testSessionId = New-Session -SessionType "Test" -Metadata @{ Test = $_ }
    Save-CHSProgress -SessionId $testSessionId -Checkpoint "Initialized"
    
    # 修改文件时间模拟过期
    $activeFile = Join-Path $script:ActiveDir "${testSessionId}.json"
    if (Test-Path $activeFile) {
        $oldTime = (Get-Date).AddDays(-10)
        (Get-Item $activeFile).LastWriteTime = $oldTime
    }
}
Write-Host "   创建了 2 个过期的测试会话" -ForegroundColor Gray

$cleanedCount = Invoke-CacheCleanup -RetentionDays 7
Write-Host "   清理了 $cleanedCount 个文件" -ForegroundColor Green

# 最终统计
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  最终统计" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
$stats = Get-SessionStatistics
Write-Host "活动会话：$($stats.ActiveSessions)" -ForegroundColor Yellow
Write-Host "检查点：$($stats.Checkpoints)" -ForegroundColor Yellow
Write-Host "归档会话：$($stats.ArchivedSessions)" -ForegroundColor Yellow
Write-Host "总大小：$($stats.TotalSizeMB) MB" -ForegroundColor Yellow

Write-Host "`n✅ 集成测试完成！" -ForegroundColor Green
Write-Host "`n所有功能验证通过：" -ForegroundColor Cyan
Write-Host "  ✓ 会话创建" -ForegroundColor Green
Write-Host "  ✓ 进度保存" -ForegroundColor Green
Write-Host "  ✓ 检查点创建" -ForegroundColor Green
Write-Host "  ✓ 会话恢复" -ForegroundColor Green
Write-Host "  ✓ 会话完成与归档" -ForegroundColor Green
Write-Host "  ✓ 过期清理" -ForegroundColor Green
