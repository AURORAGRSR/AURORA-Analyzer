# AURORA-ProgressManager-Integration.ps1
# 统一的进度管理器集成模块（合并 CHS 和 ENG 版本）
# 作者：AURORA VelociRaptor-GR Dev PRJ.
# 版本：V1.1.31Release
# 构建时间：2026.05.14

# ==========================================
# 双语 Checkpoint 配置表
# ==========================================
$PROCheckpoints = @{
    CHS = @(
        @{ Key = "Starting";        Description = "准备启动";           Progress = 5;  }
        @{ Key = "Exporting";       Description = "正在导出日志";       Progress = 30; }
        @{ Key = "Analyzing";       Description = "正在分析模式";       Progress = 60; }
        @{ Key = "Reporting";       Description = "正在生成报告";       Progress = 85; }
        @{ Key = "Completed";       Description = "导出完成";           Progress = 100; }
        @{ Key = "Failed";          Description = "导出失败";           Progress = 100; }
    )
    ENG = @(
        @{ Key = "Starting";        Description = "Preparing to start"; Progress = 5;  }
        @{ Key = "Exporting";       Description = "Exporting logs";     Progress = 30; }
        @{ Key = "Analyzing";       Description = "Analyzing patterns"; Progress = 60; }
        @{ Key = "Reporting";       Description = "Generating report";  Progress = 85; }
        @{ Key = "Completed";       Description = "Export completed";   Progress = 100; }
        @{ Key = "Failed";          Description = "Export failed";      Progress = 100; }
    )
}

# ==========================================
# 保存进度（安全版本）
# ==========================================
function Save-PROProgress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CheckpointKey,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$ExtraData = @{},
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("CHS", "ENG")]
        [string]$Language = "CHS"
    )
    
    # 查找对应的 checkpoint
    $checkpoint = $PROCheckpoints[$Language] | Where-Object { $_.Key -eq $CheckpointKey }
    if (-not $checkpoint) {
        Write-Warning "Checkpoint '$CheckpointKey' not found for language '$Language'"
        return
    }
    
    # 构建会话数据
    $sessionData = @{
        SessionId      = Get-Date -Format "yyyyMMdd_HHmmss_fff"
        Language       = $Language
        CheckpointKey  = $CheckpointKey
        Description    = $checkpoint.Description
        Progress       = $checkpoint.Progress
        Timestamp      = Get-Date -Format "o"
        ToolType       = "PRO"
        ExtraData      = $ExtraData
    }
    
    # 保存进度
    Save-ProgressSafe -SessionData $sessionData
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

# 导出函数
Export-ModuleMember -Function Save-PROProgress, Get-PROCheckpointDescription, Get-PROCheckpointProgress
