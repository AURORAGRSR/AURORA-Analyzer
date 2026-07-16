<#
.SYNOPSIS
    AURORA 进度管理器集成模块
.DESCRIPTION
    统一的进度管理器集成模块（合并 CHS 和 ENG 版本）
.NOTES
    版本：V1.5.29.0Release | 构建时间：2026.07.16
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>

# ==========================================
# 双语 Checkpoint 配置表
# ==========================================
$PROCheckpoints = @{
    CHS = @(
        @{ Key = "Starting";              Description = "准备启动";              Progress = 5;  }
        @{ Key = "Initialized";           Description = "初始化完成";            Progress = 10; }
        @{ Key = "LogTypeSelected";       Description = "已选择日志类型";        Progress = 15; }
        @{ Key = "DateRangeConfigured";   Description = "日期范围已配置";        Progress = 20; }
        @{ Key = "PerformanceAssessed";   Description = "性能评估完成";          Progress = 30; }
        @{ Key = "Exporting";             Description = "正在导出日志";          Progress = 40; }
        @{ Key = "ProcessingStarted";     Description = "开始处理日志";          Progress = 50; }
        @{ Key = "FetchingFullLog";       Description = "正在获取完整日志";      Progress = 60; }
        @{ Key = "FullLogFetched";        Description = "已获取完整日志";        Progress = 70; }
        @{ Key = "HighRiskScanComplete";  Description = "高危扫描完成";          Progress = 75; }
        @{ Key = "HealthAssessmentComplete"; Description = "健康评估完成";       Progress = 80; }
        @{ Key = "ExportModeSelected";    Description = "已选择导出模式";        Progress = 85; }
        @{ Key = "ExportStarted";         Description = "导出已开始";            Progress = 90; }
        @{ Key = "Analyzing";             Description = "正在分析模式";          Progress = 93; }
        @{ Key = "Reporting";             Description = "正在生成报告";          Progress = 96; }
        @{ Key = "Completed";             Description = "导出完成";              Progress = 100; }
        @{ Key = "Failed";                Description = "导出失败";              Progress = 100; }
    )
    ENG = @(
        @{ Key = "Starting";              Description = "Preparing to start";     Progress = 5;  }
        @{ Key = "Initialized";           Description = "Initialization complete"; Progress = 10; }
        @{ Key = "LogTypeSelected";       Description = "Log type selected";      Progress = 15; }
        @{ Key = "DateRangeConfigured";   Description = "Date range configured";  Progress = 20; }
        @{ Key = "PerformanceAssessed";   Description = "Performance assessed";   Progress = 30; }
        @{ Key = "Exporting";             Description = "Exporting logs";         Progress = 40; }
        @{ Key = "ProcessingStarted";     Description = "Processing started";     Progress = 50; }
        @{ Key = "FetchingFullLog";       Description = "Fetching full log";      Progress = 60; }
        @{ Key = "FullLogFetched";        Description = "Full log fetched";       Progress = 70; }
        @{ Key = "HighRiskScanComplete";  Description = "High-risk scan complete"; Progress = 75; }
        @{ Key = "HealthAssessmentComplete"; Description = "Health assessment complete"; Progress = 80; }
        @{ Key = "ExportModeSelected";    Description = "Export mode selected";   Progress = 85; }
        @{ Key = "ExportStarted";         Description = "Export started";         Progress = 90; }
        @{ Key = "Analyzing";             Description = "Analyzing patterns";     Progress = 93; }
        @{ Key = "Reporting";             Description = "Generating report";      Progress = 96; }
        @{ Key = "Completed";             Description = "Export completed";       Progress = 100; }
        @{ Key = "Failed";                Description = "Export failed";          Progress = 100; }
    )
}

# ==========================================
# 保存进度（安全版本）
# ==========================================
function Save-PROProgress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionId,
        
        [Parameter(Mandatory=$true)]
        [string]$Checkpoint,
        
        [Parameter(Mandatory=$false)]
        [int]$CustomProgress = -1,
        
        [Parameter(Mandatory=$false)]
        [string]$CustomStage = "",
        
        [Parameter(Mandatory=$false)]
        [hashtable]$AdditionalData = @{}
    )
    
    # 查找对应的 checkpoint
    $checkpoint = $PROCheckpoints[$script:Language] | Where-Object { $_.Key -eq $Checkpoint }
    
    # 使用自定义值或默认值
    $progress = if ($CustomProgress -ge 0) { $CustomProgress } elseif ($checkpoint) { $checkpoint.Progress } else { 0 }
    $description = if ($CustomStage) { $CustomStage } elseif ($checkpoint) { $checkpoint.Description } else { $Checkpoint }
    
    # 构建会话数据
    $sessionData = @{
        SessionId      = $SessionId
        Language       = $script:Language
        CheckpointKey  = $Checkpoint
        Description    = $description
        Progress       = $progress
        Timestamp      = Get-Date -Format "o"
        ToolType       = "PRO"
        ExtraData      = $AdditionalData
    }
    
    # 调用 Save-SessionProgress 保存到 SessionCache/active 目录
    Save-SessionProgress -SessionId $SessionId -Stage $description -Progress $progress -AdditionalData $AdditionalData
}

# ==========================================
# 获取 checkpoint 描述
# ==========================================
function Get-PROCheckpointDescription {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CheckpointKey,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("CHS", "ENG")]
        [string]$Language = "CHS"
    )
    
    $checkpoint = $PROCheckpoints[$Language] | Where-Object { $_.Key -eq $CheckpointKey }
    if ($checkpoint) {
        return $checkpoint.Description
    }
    return $CheckpointKey
}

# ==========================================
# 获取 checkpoint 进度百分比
# ==========================================
function Get-PROCheckpointProgress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CheckpointKey,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("CHS", "ENG")]
        [string]$Language = "CHS"
    )
    
    $checkpoint = $PROCheckpoints[$Language] | Where-Object { $_.Key -eq $CheckpointKey }
    if ($checkpoint) {
        return $checkpoint.Progress
    }
    return 0
}

# 注意：此文件通过 dot-source 导入，不是 PowerShell 模块，因此不需要 Export-ModuleMember
