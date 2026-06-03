#===========================================
# AURORA 进度管理器集成模块 - CHS 版
# 用于在 PRO 脚本关键节点保存进度
# 版本：V1.2.31Release
# 作者：AURORA VelociRaptor-GR Dev PRJ.
# 构建时间：2026.06.01
# ==========================================

# 定义进度保存点（PRO模式版本 - 支持多日志导出）
# 与 AURORA-AnalyzerCHSPRO.ps1 完全匹配
$ProgressCheckpoints = @{
    "Initialized" = @{ Progress = 5; Stage = "脚本初始化完成" }
    "LogTypeSelected" = @{ Progress = 10; Stage = "日志类型已选择" }
    "DateRangeConfigured" = @{ Progress = 15; Stage = "日期范围已配置" }
    "PerformanceAssessed" = @{ Progress = 25; Stage = "性能评估完成" }
    "ProcessingStarted" = @{ Progress = 45; Stage = "开始处理日志文件" }
    "HighRiskScanComplete" = @{ Progress = 60; Stage = "高危事件扫描完成" }
    "HealthAssessmentComplete" = @{ Progress = 70; Stage = "系统健康评估完成" }
    "ExportModeSelected" = @{ Progress = 75; Stage = "导出模式已选择" }
    "FetchingFullLog" = @{ Progress = 75; Stage = "正在获取完整日志" }
    "FullLogFetched" = @{ Progress = 80; Stage = "完整日志已获取" }
    "ExportStarted" = @{ Progress = 85; Stage = "正在导出日志" }
    "ExportComplete" = @{ Progress = 90; Stage = "所有日志导出完成" }
    "TrendAnalysisComplete" = @{ Progress = 93; Stage = "趋势分析完成" }
    "SmartAnalysisPending" = @{ Progress = 95; Stage = "等待智能分析" }
    "SmartAnalysisComplete" = @{ Progress = 98; Stage = "智能分析完成" }
    "Completed" = @{ Progress = 100; Stage = "任务完成" }
}

# 保存进度函数
function Save-CHSProgress {
    param(
        [string]$SessionId,
        [string]$Checkpoint,
        [hashtable]$AdditionalData = @{},
        [switch]$CreateCheckpoint,
        [int]$CustomProgress = -1, # 支持自定义进度（用于多日志处理）
        [string]$CustomStage = "" # 支持自定义阶段描述
    )
    
    if (-not $ProgressCheckpoints.ContainsKey($Checkpoint)) {
        Write-Warning "[ProgressManager] 未知的检查点：$Checkpoint"
        return
    }
    
    $checkpoint = $ProgressCheckpoints[$Checkpoint]
    
    # 确定要使用的进度值和阶段描述
    $progressToUse = if ($CustomProgress -ge 0 -and $CustomProgress -le 100) { $CustomProgress } else { $checkpoint.Progress }
    $stageToUse = if (-not [string]::IsNullOrWhiteSpace($CustomStage)) { $CustomStage } else { $checkpoint.Stage }
    
    Save-SessionProgress `
        -SessionId $SessionId `
        -Stage $stageToUse `
        -Progress $progressToUse `
        -AdditionalData $AdditionalData `
        -CreateCheckpoint:$CreateCheckpoint
    
    # 同步更新GUI进度条
    if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
        $global:syncHash.Progress = $progressToUse
        $global:syncHash.CurrentStatus = $stageToUse
    }
    
    Write-Verbose "[ProgressManager] 保存进度：$Checkpoint ($($progressToUse)%) - $stageToUse"
}

# 注意：本脚本使用点号导入，不使用 Export-ModuleMember
# 函数在全局作用域中自动可用
