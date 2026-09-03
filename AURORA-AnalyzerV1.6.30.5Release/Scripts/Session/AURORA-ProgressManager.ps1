<#
.SYNOPSIS
    AURORA 进度管理器 - 会话持久化与断点续传系统
.DESCRIPTION
    提供完整的会话进度保存、恢复、归档和清理功能
    支持工具目录和 TEMP 目录降级方案
    支持 7 天自动过期机制
.NOTES
    版本：V1.6.30.5Release | 构建时间：2026.09.03
    作者：AURORA VelociRaptor-GR Dev PRJ.
    缓存目录结构说明：
        SessionCache\active\        - 当前活动会话
        SessionCache\checkpoints\   - 检查点备份
        SessionCache\archive\       - 已完成的会话归档
#>

#requires -Version 5.0

# 注意：本脚本通过 Invoke-Expression 加载，不能使用 [CmdletBinding()] 和 param()

# ==========================================
# 🔒 防止重复导入标志
# ==========================================
if ($global:AURORA_ProgressManager_Loaded -eq $true) {
    return
}
$global:AURORA_ProgressManager_Loaded = $true

# 用于存储所有会话数据的根目录
# 使用 $global: 作用域，确保跨 dot-source 文件可见
$global:AURORA_ProgressManager_CacheRoot = $null
$global:AURORA_ProgressManager_ActiveDir = $null
$global:AURORA_ProgressManager_CheckpointsDir = $null
$global:AURORA_ProgressManager_ArchiveDir = $null
$global:AURORA_ProgressManager_CurrentSessionId = $null
$global:AURORA_ProgressManager_SessionData = @{}
$global:AURORA_ProgressManager_IsInitialized = $false
$global:AURORA_ProgressManager_Language = "CHS"  # 默认中文，支持 CHS/ENG

#endregion

#region 双语支持函数

function Get-LocalizedString {
    param([string]$Key)
    
    $strings = @{
        "UsingToolCache" = @{ CHS = "使用工具目录缓存：{0}"; ENG = "Using tool directory cache: {0}" }
        "UsingTempCache" = @{ CHS = "使用 TEMP 目录缓存：{0}"; ENG = "Using TEMP directory cache: {0}" }
        "InitCacheFailed" = @{ CHS = "初始化缓存目录失败：{0}"; ENG = "Failed to initialize cache directory: {0}" }
        "ToolNotWritable" = @{ CHS = "工具目录不可写，使用 TEMP 降级方案"; ENG = "Tool directory not writable, using TEMP fallback" }
        "CreatingSession" = @{ CHS = "创建新会话：{0}"; ENG = "Creating new session: {0}" }
        "CreateSessionFailed" = @{ CHS = "创建会话失败：{0}"; ENG = "Failed to create session: {0}" }
        "NoSessionId" = @{ CHS = "未指定会话 ID"; ENG = "No session ID specified" }
        "SkippingNull" = @{ CHS = "跳过 null 值：{0}"; ENG = "Skipping null value: {0}" }
        "SkippingEmpty" = @{ CHS = "跳过空字符串值：{0}"; ENG = "Skipping empty string value: {0}" }
        "SavingProgress" = @{ CHS = "保存进度：{0} ({1}%) [尝试 {2}/{3}]"; ENG = "Saving progress: {0} ({1}%) [attempt {2}/{3}]" }
        "SaveFailed" = @{ CHS = "保存失败 (尝试 {0}/{1}): {2}"; ENG = "Save failed (attempt {0}/{1}): {2}" }
        "CheckpointCreated" = @{ CHS = "创建检查点：{0}"; ENG = "Checkpoint created: {0}" }
        "CheckpointFailed" = @{ CHS = "创建检查点失败：{0}"; ENG = "Failed to create checkpoint: {0}" }
        "SaveProgressFailed" = @{ CHS = "保存进度失败：{0}"; ENG = "Failed to save progress: {0}" }
        "NoRecoverableSession" = @{ CHS = "未找到可恢复的会话"; ENG = "No recoverable session found" }
        "SessionFileNotFound" = @{ CHS = "会话文件不存在：{0}"; ENG = "Session file not found: {0}" }
        "ReadSessionFailed" = @{ CHS = "读取会话文件失败：{0}"; ENG = "Failed to read session file: {0}" }
        "SessionExpired" = @{ CHS = "会话已过期（{0} 天）：{1}"; ENG = "Session expired ({0} days): {1}" }
        "RestoringSession" = @{ CHS = "恢复会话：{0} (进度：{1}%，阶段：{2})"; ENG = "Restoring session: {0} (progress: {1}%, stage: {2})" }
        "RestoreFailed" = @{ CHS = "恢复会话失败：{0}"; ENG = "Failed to restore session: {0}" }
        "ArchivingSession" = @{ CHS = "归档会话：{0} -> {1}"; ENG = "Archiving session: {0} -> {1}" }
        "DeletingSession" = @{ CHS = "删除会话：{0}"; ENG = "Deleting session: {0}" }
        "CleaningCheckpoints" = @{ CHS = "清理检查点：{0}"; ENG = "Cleaning checkpoints: {0}" }
        "CleanFailed" = @{ CHS = "清理会话失败：{0}"; ENG = "Failed to clean session: {0}" }
        "CannotReadSession" = @{ CHS = "无法读取会话文件 {0}: {1}"; ENG = "Cannot read session file {0}: {1}" }
        "SkippingCorrupt" = @{ CHS = "跳过损坏的会话文件：{0}"; ENG = "Skipping corrupt session file: {0}" }
        "FindSessionFailed" = @{ CHS = "查找会话失败：{0}"; ENG = "Failed to find session: {0}" }
        "CleaningNull" = @{ CHS = "清理空值字段：{0}"; ENG = "Cleaning null field: {0}" }
        "SessionCompleted" = @{ CHS = "会话完成：{0}"; ENG = "Session completed: {0}" }
        "CompleteFailed" = @{ CHS = "完成会话失败：{0}"; ENG = "Failed to complete session: {0}" }
        "CleaningExpired" = @{ CHS = "清理过期会话：{0}"; ENG = "Cleaning expired session: {0}" }
        "CleaningCheckpoint" = @{ CHS = "清理过期检查点：{0}"; ENG = "Cleaning expired checkpoint: {0}" }
        "CleaningArchive" = @{ CHS = "清理过期归档：{0}"; ENG = "Cleaning expired archive: {0}" }
        "CleanupDone" = @{ CHS = "清理完成，共清理 {0} 个文件"; ENG = "Cleanup completed, {0} files cleaned" }
        "CleanupFailed" = @{ CHS = "清理缓存失败：{0}"; ENG = "Failed to cleanup cache: {0}" }
    }
    
    if ($strings.ContainsKey($Key)) {
        $langData = $strings[$Key]
        $text = if ($langData.ContainsKey($global:AURORA_ProgressManager_Language)) { $langData[$global:AURORA_ProgressManager_Language] } else { $langData["CHS"] }
        
        if ($args.Count -gt 0) {
            # 安全地处理格式化
            try {
                # 计算文本中的占位符数量 {0}, {1}, {2}...
                $placeholderCount = [regex]::Matches($text, "\{\d+\}").Count
                if ($placeholderCount -eq 0) {
                    # 没有占位符，直接返回
                    return $text
                }
                
                # 获取所有参数并展平
                $allArgs = @()
                foreach ($arg in $args) {
                    if ($arg -is [array] -or $arg -is [System.Collections.IEnumerable] -and $arg -isnot [string]) {
                        foreach ($item in $arg) {
                            $allArgs += $item
                        }
                    } else {
                        $allArgs += $arg
                    }
                }
                
                # 确保参数数量匹配（或至少足够）
                if ($allArgs.Count -ge $placeholderCount) {
                    return [string]::Format($text, $allArgs[0..($placeholderCount-1)])
                } else {
                    Write-Warning "Not enough arguments for format string: $text, expected $placeholderCount, got $($allArgs.Count)"
                    return $text
                }
            } catch {
                Write-Warning "Format failed: text='$text', args count=$($args.Count), error=$($_.Exception.Message)"
                return $text  # 如果格式化失败，返回原始文本
            }
        }
        return $text
    }
    return $Key
}

#endregion

#region 初始化函数

function Initialize-CacheDirectory {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$ToolPath
    )
    
    process {
        try {
            # 优先使用工具目录
            if ($ToolPath -and (Test-Path $ToolPath)) {
                $primaryCache = Join-Path $ToolPath "SessionCache"
                
                try {
                    # 尝试创建目录结构
                    $dirs = @("active", "checkpoints", "archive")
                    foreach ($dir in $dirs) {
                        $testPath = Join-Path $primaryCache $dir
                        if (-not (Test-Path $testPath)) {
                            $null = New-Item -ItemType Directory -Path $testPath -Force -ErrorAction Stop
                        }
                        # 测试写入权限
                        $testFile = Join-Path $testPath ".write_test"
                        [System.IO.File]::WriteAllText($testFile, "test", [System.Text.UTF8Encoding]::new($false))
                        [System.IO.File]::Delete($testFile)
                    }
                    
                    # 工具目录可用
                    $global:AURORA_ProgressManager_CacheRoot = $primaryCache
                    $global:AURORA_ProgressManager_ActiveDir = Join-Path $primaryCache "active"
                    $global:AURORA_ProgressManager_CheckpointsDir = Join-Path $primaryCache "checkpoints"
                    $global:AURORA_ProgressManager_ArchiveDir = Join-Path $primaryCache "archive"
                    
                    Write-Verbose (Get-LocalizedString "UsingToolCache" $primaryCache)
                    return $true
                }
                catch {
                    Write-Verbose (Get-LocalizedString "ToolNotWritable")
                }
            }
            
            # 降级方案：使用 TEMP 目录
            $tempCache = Join-Path $env:TEMP "AURORA_Sessions"
            $dirs = @("active", "checkpoints", "archive")
            foreach ($dir in $dirs) {
                $testPath = Join-Path $tempCache $dir
                if (-not (Test-Path $testPath)) {
                    $null = New-Item -ItemType Directory -Path $testPath -Force
                }
            }
            
            $global:AURORA_ProgressManager_CacheRoot = $tempCache
            $global:AURORA_ProgressManager_ActiveDir = Join-Path $tempCache "active"
            $global:AURORA_ProgressManager_CheckpointsDir = Join-Path $tempCache "checkpoints"
            $global:AURORA_ProgressManager_ArchiveDir = Join-Path $tempCache "archive"
            
            Write-Verbose (Get-LocalizedString "UsingTempCache" $tempCache)
            return $true
        }
        catch {
            Write-Error (Get-LocalizedString "InitCacheFailed" $_.Exception.Message)
            return $false
        }
    }
}

#endregion

#region 会话管理函数

function New-Session {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$SessionType = "ExportTask",
        [hashtable]$Metadata = @{}
    )
    
    process {
        try {
            # 生成会话 ID：时间戳 + 随机数
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $random = Get-Random -Maximum 9999 -Minimum 1000
            $sessionId = "SESSION_${timestamp}_${random}"
            
            $global:AURORA_ProgressManager_CurrentSessionId = $sessionId
            $global:AURORA_ProgressManager_SessionData = @{
                SessionId = $sessionId
                SessionType = $SessionType
                CreatedAt = Get-Date -Format "o"
                LastUpdated = Get-Date -Format "o"
                Status = "Active"
                Progress = 0
                CurrentStage = "Initialized"
                Metadata = $Metadata
                Checkpoints = @()
            }
            
            Write-Verbose (Get-LocalizedString "CreatingSession" $sessionId)
            return $sessionId
        }
        catch {
            Write-Error (Get-LocalizedString "CreateSessionFailed" $_.Exception.Message)
            return $null
        }
    }
}

function Save-SessionProgress {
    [CmdletBinding()]
    param(
        [string]$SessionId = $global:AURORA_ProgressManager_CurrentSessionId,
        [string]$Stage,
        [int]$Progress = -1, # 默认值-1，表示不更新进度
        [hashtable]$AdditionalData = @{},
        [switch]$CreateCheckpoint
    )
    
    process {
        if (-not $SessionId) {
            Write-Warning (Get-LocalizedString "NoSessionId")
            return
        }
        
        try {
            # 更新会话数据
            $global:AURORA_ProgressManager_SessionData.LastUpdated = Get-Date -Format "o"
            
            if ($Stage) {
                $global:AURORA_ProgressManager_SessionData.CurrentStage = $Stage
            }
            
            # 只有当Progress >= 0时才更新（-1表示不更新）
            if ($Progress -ge 0) {
                $global:AURORA_ProgressManager_SessionData.Progress = $Progress
            }
            
            # 合并额外数据 - 过滤 null 和空字符串值
            foreach ($key in $AdditionalData.Keys) {
                $value = $AdditionalData[$key]
                # 过滤 null 值
                if ($value -eq $null) {
                    Write-Verbose (Get-LocalizedString "SkippingNull" $key)
                    continue
                }
                # 过滤空字符串
                if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
                    Write-Verbose (Get-LocalizedString "SkippingEmpty" $key)
                    continue
                }
                $global:AURORA_ProgressManager_SessionData[$key] = $value
            }
            
            # 保存活动会话 - 使用原子写入机制（Phase 4.1）
            # 诊断：检查目录是否存在
            if (-not $global:AURORA_ProgressManager_ActiveDir) {
                Write-Warning "活动目录路径为空"
                return
            }
            if (-not (Test-Path $global:AURORA_ProgressManager_ActiveDir)) {
                Write-Warning "活动目录不存在：$global:AURORA_ProgressManager_ActiveDir，尝试创建..."
                try {
                    $null = New-Item -ItemType Directory -Path $global:AURORA_ProgressManager_ActiveDir -Force -ErrorAction Stop
                } catch {
                    Write-Warning "创建目录失败：$($_.Exception.Message)"
                }
            }
            
            $activeFile = Join-Path $global:AURORA_ProgressManager_ActiveDir "${SessionId}.json"
            $tempFile = $activeFile + ".tmp"
            $maxRetries = 3
            $retryCount = 0
            $saved = $false
            
            $lastSaveError = $null
            while (-not $saved -and $retryCount -lt $maxRetries) {
                try {
                    $retryCount++
                    $jsonContent = $global:AURORA_ProgressManager_SessionData | ConvertTo-Json -Depth 10
                    
                    # 诊断：输出路径信息（改为 Warning 以便调试）
                    Write-Warning "尝试写入会话文件：$activeFile (尝试 $retryCount/$maxRetries)"
                    
                    # 【Phase 4.1 原子写入】先写入临时文件
                    $fileStream = [System.IO.File]::Create($tempFile)
                    try {
                        $writer = New-Object System.IO.StreamWriter($fileStream, [System.Text.UTF8Encoding]::new($false))
                        $writer.Write($jsonContent)
                        $writer.Flush()
                        $writer.Close()
                    } catch {
                        $fileStream.Close()
                        throw
                    }
                    
                    # 【Phase 4.1 原子写入】使用 File.Replace 实现真正原子替换
                    try {
                        if (Test-Path $activeFile) {
                            $backupFile = "$activeFile.bak"
                            [System.IO.File]::Replace($tempFile, $activeFile, $backupFile)
                            # 清理备份文件
                            if (Test-Path $backupFile) {
                                [System.IO.File]::Delete($backupFile)
                            }
                        } else {
                            [System.IO.File]::Move($tempFile, $activeFile)
                        }
                    } catch {
                        Write-Warning "原子写入失败: $($_.Exception.Message)"
                        throw
                    }
                    
                    $saved = $true
                    Write-Warning (Get-LocalizedString "SavingProgress" @($Stage, $Progress, $retryCount, $maxRetries))
                    
                } catch {
                    # 清理临时文件（如果存在）
                    if (Test-Path $tempFile) {
                        try {
                            [System.IO.File]::Delete($tempFile)
                        } catch {
                            Write-Warning "Non-critical operation failed: $($_.Exception.Message)"
                            Write-Debug "Stack: $($_.ScriptStackTrace)"
                        }
                    }
                    
                    $lastSaveError = $_.Exception.Message
                    Write-Warning (Get-LocalizedString "SaveFailed" @($retryCount, $maxRetries, $lastSaveError))
                    if ($retryCount -lt $maxRetries) {
                        Start-Sleep -Milliseconds (100 * $retryCount)
                    }
                }
            }
            
            if (-not $saved) {
                $errorMsg = if ($global:AURORA_ProgressManager_Language -eq "ENG") { "Failed to write session file after $maxRetries attempts" } else { "无法写入会话文件（已尝试 $maxRetries 次）" }
                throw "$errorMsg`nActiveDir=$global:AURORA_ProgressManager_ActiveDir`nActiveFile=$activeFile`nTempFile=$tempFile`nLastError=$lastSaveError"
            }
            
            # 创建检查点，仅在 $CreateCheckpoint 为 $true 时执行
            if ($CreateCheckpoint) {
                $checkpointFile = Join-Path $global:AURORA_ProgressManager_CheckpointsDir "${SessionId}_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                try {
                    $jsonContent = $global:AURORA_ProgressManager_SessionData | ConvertTo-Json -Depth 10
                    $fileStream = [System.IO.File]::Create($checkpointFile)
                    try {
                        $writer = New-Object System.IO.StreamWriter($fileStream, [System.Text.UTF8Encoding]::new($false))
                        try {
                            $writer.Write($jsonContent)
                            $writer.Flush()
                        } finally {
                            $writer.Close()
                        }
                    } finally {
                        $fileStream.Close()
                        $fileStream.Dispose()
                    }
                } catch {
                    Write-Error (Get-LocalizedString "CheckpointFailed" $_.Exception.Message)
                    throw
                }
                
                # 添加到检查点列表
                $global:AURORA_ProgressManager_SessionData.Checkpoints += @{
                    CreatedAt = Get-Date -Format "o"
                    Stage = $Stage
                    File = $checkpointFile
                }
                
                Write-Verbose (Get-LocalizedString "CheckpointCreated" $checkpointFile)
            }
        }
        catch {
            Write-Error (Get-LocalizedString "SaveProgressFailed" $_.Exception.Message)
            throw
        }
    }
}

function Restore-SessionProgress {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$SessionId
    )
    
    process {
        try {
            if (-not $SessionId) {
                # 查找最新的未完成会话
                $SessionId = Get-LatestPendingSession
            }
            
            if (-not $SessionId) {
                return $null
            }
            
            $activeFile = Join-Path $global:AURORA_ProgressManager_ActiveDir "${SessionId}.json"
            
            if (-not (Test-Path $activeFile)) {
                return $null
            }
            
            # 使用更安全的文件读取方式，确保文件被正确释放
            $jsonContent = $null
            try {
                $fileStream = [System.IO.File]::Open($activeFile, 'Open', 'Read', 'ReadWrite')
                $reader = New-Object System.IO.StreamReader($fileStream, [System.Text.Encoding]::UTF8)
                $jsonContent = $reader.ReadToEnd()
                $reader.Close()
                $fileStream.Close()
            } catch {
                return $null
            }
            
            $sessionData = $jsonContent | ConvertFrom-Json
            
            # 验证会话是否过期（7 天）
            $createdAt = [datetime]$sessionData.CreatedAt
            $age = (Get-Date) - $createdAt
            
            if ($age.Days -gt 7) {
                Remove-SessionProgress -SessionId $SessionId
                return $null
            }
            
            # 恢复会话 - 将 PSCustomObject 转换为 hashtable
            $global:AURORA_ProgressManager_CurrentSessionId = $SessionId
            $global:AURORA_ProgressManager_SessionData = @{}
            
            # 复制所有属性到 hashtable
            foreach ($prop in $sessionData.PSObject.Properties) {
                $global:AURORA_ProgressManager_SessionData[$prop.Name] = $prop.Value
            }
            
            return @{
                SessionId = $global:AURORA_ProgressManager_SessionData.SessionId
                Stage = $global:AURORA_ProgressManager_SessionData.CurrentStage
                Progress = $global:AURORA_ProgressManager_SessionData.Progress
                LastUpdated = $global:AURORA_ProgressManager_SessionData.LastUpdated
                Data = $global:AURORA_ProgressManager_SessionData
                AgeInDays = [math]::Round($age.TotalDays, 1)
            }
        }
        catch {
            Write-Error "Restore failed: $($_.Exception.Message)"
            return $null
        }
    }
}

function Remove-SessionProgress {
    [CmdletBinding()]
    param(
        [string]$SessionId,
        [switch]$Archive
    )
    
    process {
        try {
            if (-not $SessionId) {
                Write-Warning (Get-LocalizedString "NoSessionId")
                return
            }
            
            $activeFile = Join-Path $global:AURORA_ProgressManager_ActiveDir "${SessionId}.json"
            
            if ($Archive -and (Test-Path $activeFile)) {
                # 归档：移动到 archive 目录
                $archiveFile = Join-Path $global:AURORA_ProgressManager_ArchiveDir "${SessionId}_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                Move-Item -Path $activeFile -Destination $archiveFile -Force
                
                Write-Verbose (Get-LocalizedString "ArchivingSession" @($SessionId, $archiveFile))
            }
            elseif (Test-Path $activeFile) {
                # 删除活动会话
                Remove-Item -Path $activeFile -Force
                
                Write-Verbose (Get-LocalizedString "DeletingSession" $SessionId)
            }
            
            # 清理检查点
            if (-not $Archive) {
                $checkpointPattern = Join-Path $global:AURORA_ProgressManager_CheckpointsDir "${SessionId}_*.json"
                Get-Item -Path $checkpointPattern -ErrorAction SilentlyContinue | Remove-Item -Force
                
                Write-Verbose (Get-LocalizedString "CleaningCheckpoints" $SessionId)
            }
            
            # 重置当前会话
            if ($SessionId -eq $global:AURORA_ProgressManager_CurrentSessionId) {
                $global:AURORA_ProgressManager_CurrentSessionId = $null
                $global:AURORA_ProgressManager_SessionData = @{}
            }
        }
        catch {
            Write-Error (Get-LocalizedString "CleanFailed" $_.Exception.Message)
        }
    }
}

function Get-LatestPendingSession {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    process {
        try {
            # 查找所有活动会话
            $sessionFiles = Get-ChildItem -Path $global:AURORA_ProgressManager_ActiveDir -Filter "*.json" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending
            
            foreach ($file in $sessionFiles) {
                try {
                    # 使用更安全的文件读取方式
                    $content = $null
                    try {
                        $fileStream = [System.IO.File]::Open($file.FullName, 'Open', 'Read', 'ReadWrite')
                        try {
                            $reader = New-Object System.IO.StreamReader($fileStream, [System.Text.Encoding]::UTF8)
                            try {
                                $content = $reader.ReadToEnd()
                            } finally {
                                $reader.Close()
                            }
                        } finally {
                            $fileStream.Close()
                        }
                    } catch {
                        Write-Verbose (Get-LocalizedString "CannotReadSession" @($file.Name, $_.Exception.Message))
                        continue
                    }
                    
                    if ($content) {
                        $session = $content | ConvertFrom-Json
                        
                        # 返回第一个未完成的会话
                        if ($session.Status -eq "Active" -or $session.Progress -lt 100) {
                            return $session.SessionId
                        }
                    }
                }
                catch {
                    Write-Verbose (Get-LocalizedString "SkippingCorrupt" $file.Name)
                    continue
                }
            }
            
            return $null
        }
        catch {
            Write-Error (Get-LocalizedString "FindSessionFailed" $_.Exception.Message)
            return $null
        }
    }
}

function Test-PendingSession {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    process {
        $sessionId = Get-LatestPendingSession
        return [bool]$sessionId
    }
}

function Complete-Session {
    [CmdletBinding()]
    param(
        [string]$SessionId = $global:AURORA_ProgressManager_CurrentSessionId,
        [switch]$Archive
    )
    
    process {
        try {
            if (-not $SessionId) {
                Write-Warning (Get-LocalizedString "NoSessionId")
                return
            }
            
            # 在完成前清理会话数据中的 null 和空字符串值
            $keysToRemove = @()
            foreach ($key in $global:AURORA_ProgressManager_SessionData.Keys) {
                $value = $global:AURORA_ProgressManager_SessionData[$key]
                if ($value -eq $null) {
                    $keysToRemove += $key
                } elseif ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
                    $keysToRemove += $key
                }
            }
            foreach ($key in $keysToRemove) {
                Write-Verbose (Get-LocalizedString "CleaningNull" $key)
                $global:AURORA_ProgressManager_SessionData.Remove($key)
            }
            
            # 更新状态为完成
            Save-SessionProgress -SessionId $SessionId -Stage "Completed" -Progress 100 -AdditionalData @{
                Status = "Completed"
                CompletedAt = Get-Date -Format "o"
            }
            
            Write-Verbose (Get-LocalizedString "SessionCompleted" $SessionId)
            
            # 归档会话
            if ($Archive) {
                Remove-SessionProgress -SessionId $SessionId -Archive
            }
        }
        catch {
            Write-Error (Get-LocalizedString "CompleteFailed" $_.Exception.Message)
        }
    }
}

#endregion

#region 清理函数

function Invoke-CacheCleanup {
    [CmdletBinding()]
    param(
        [int]$RetentionDays = 7
    )
    
    process {
        try {
            $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
            $cleanedCount = 0
            
            # 清理过期的活动会话
            if (Test-Path $global:AURORA_ProgressManager_ActiveDir) {
                $oldSessions = Get-ChildItem -Path $global:AURORA_ProgressManager_ActiveDir -Filter "*.json" |
                    Where-Object { $_.LastWriteTime -lt $cutoffDate }
                
                foreach ($session in $oldSessions) {
                    Remove-Item -Path $session.FullName -Force
                    $cleanedCount++
                    Write-Verbose (Get-LocalizedString "CleaningExpired" $session.Name)
                }
            }
            
            # 清理过期的检查点
            if (Test-Path $global:AURORA_ProgressManager_CheckpointsDir) {
                $oldCheckpoints = Get-ChildItem -Path $global:AURORA_ProgressManager_CheckpointsDir -Filter "*.json" |
                    Where-Object { $_.LastWriteTime -lt $cutoffDate }
                
                foreach ($checkpoint in $oldCheckpoints) {
                    Remove-Item -Path $checkpoint.FullName -Force
                    $cleanedCount++
                    Write-Verbose (Get-LocalizedString "CleaningCheckpoint" $checkpoint.Name)
                }
            }
            
            # 归档保留超过 30 天的归档文件（可选）
            $archiveCutoff = (Get-Date).AddDays(-30)
            if (Test-Path $global:AURORA_ProgressManager_ArchiveDir) {
                $oldArchives = Get-ChildItem -Path $global:AURORA_ProgressManager_ArchiveDir -Filter "*.json" |
                    Where-Object { $_.LastWriteTime -lt $archiveCutoff }
                
                foreach ($archive in $oldArchives) {
                    Remove-Item -Path $archive.FullName -Force
                    $cleanedCount++
                    Write-Verbose (Get-LocalizedString "CleaningArchive" $archive.Name)
                }
            }
            
            Write-Verbose (Get-LocalizedString "CleanupDone" $cleanedCount)
            return $cleanedCount
        }
        catch {
            Write-Error (Get-LocalizedString "CleanupFailed" $_.Exception.Message)
            return 0
        }
    }
}

function Get-SessionStatistics {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    process {
        try {
            $stats = @{
                ActiveSessions = 0
                Checkpoints = 0
                ArchivedSessions = 0
                TotalSizeBytes = 0
            }
            
            if (Test-Path $global:AURORA_ProgressManager_ActiveDir) {
                $activeFiles = Get-ChildItem -Path $global:AURORA_ProgressManager_ActiveDir -Filter "*.json"
                $stats.ActiveSessions = $activeFiles.Count
                $stats.TotalSizeBytes += ($activeFiles | Measure-Object -Property Length -Sum).Sum
            }
            
            if (Test-Path $global:AURORA_ProgressManager_CheckpointsDir) {
                $checkpointFiles = Get-ChildItem -Path $global:AURORA_ProgressManager_CheckpointsDir -Filter "*.json"
                $stats.Checkpoints = $checkpointFiles.Count
                $stats.TotalSizeBytes += ($checkpointFiles | Measure-Object -Property Length -Sum).Sum
            }
            
            if (Test-Path $global:AURORA_ProgressManager_ArchiveDir) {
                $archiveFiles = Get-ChildItem -Path $global:AURORA_ProgressManager_ArchiveDir -Filter "*.json"
                $stats.ArchivedSessions = $archiveFiles.Count
                $stats.TotalSizeBytes += ($archiveFiles | Measure-Object -Property Length -Sum).Sum
            }
            
            $stats.TotalSizeMB = [math]::Round($stats.TotalSizeBytes / 1MB, 2)
            
            return $stats
        }
        catch {
            $errorMsg = if ($global:AURORA_ProgressManager_Language -eq "ENG") { "Failed to get session statistics: $($_.Exception.Message)" } else { "获取统计信息失败：$($_.Exception.Message)" }
            Write-Error "[ProgressManager] $errorMsg"
            return $null
        }
    }
}

#endregion

# 注意：本脚本使用点号导入，不使用 Export-ModuleMember
# 所有函数在全局作用域中自动可用
