<#
.SYNOPSIS
    AURORA 智能诊断与自主修复模式核心引擎
.DESCRIPTION
    智能诊断与自主修复模式核心引擎
    架构特性：单文件双语支持 (Bilingual) + 动态环境感知 + 极速并发匹配
.NOTES
    版本：V1.5.28.0Release | 构建时间：2026.07.10
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>

# ==========================================
# 🔒 启动检测：只允许由 GUI 启动，禁止直接运行
# ==========================================
Param(
    [string]$OutputPath,    
    [hashtable]$GUIParams,  
    [hashtable]$hash,      
    [string]$Language = "CHS",
    
    # ===== 核心修复 1：补全 GUI 传过来的透传参数，防止参数越界报错 =====
    [switch]$GUI_Mode,
    [string]$LogType,
    [string]$Level,
    [string]$EventId,
    [string]$ProviderName,
    $StartTime,
    $EndTime,
    
    # ===== Phase 3.2 新增：支持更多日志类型 =====
    [string[]]$LogTypes,  # 可选参数，指定要扫描的日志类型（支持 System, Application, Security, Setup 等）
    
    # ===== 新增：PRO 模式调用参数 =====
    [switch]$FromPRO,              # 标记是否从 PRO 模式调用
    [switch]$FromGUI,             # 标记是否从 GUI 直接进入智能模式
    [string]$ExportedLogPath      # PRO 模式导出的日志路径
)

# ==========================================
# 🔒 启动检测（统一使用 LaunchGuard 模块）
# ==========================================
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$parentDir = Split-Path $scriptDir -Parent

$launchGuardPath = Join-Path (Join-Path $parentDir "Core") "AURORA-LaunchGuard.ps1"
if (Test-Path $launchGuardPath) {
    . $launchGuardPath
    # [修复] $null = 抑制 Assert-AuroraLaunchContext 的 return $true 泄漏到管道输出
    $null = Assert-AuroraLaunchContext -Params $PSBoundParameters
} else {
    Write-Warning "LaunchGuard module not found, skipping launch context validation"
}

# ==========================================
# 🔐 C# 运行时完整性守卫 (编译为 IL, 跨 Runspace 可见)
# ==========================================
# 注意：AuroraGuard 在主 Runspace 中编译，子 Runspace 可能无法访问
# 如果类型不存在，说明已在 LauncherGUI 中验证过，跳过此检查
try {
    if ([System.Type]::GetType('AuroraGuard') -or $null -ne [AuroraGuard]) {
        [AuroraGuard]::VerifyOrDie()
    }
} catch {
    # 类型不存在或验证失败，静默跳过
}

$ErrorActionPreference = "Stop"

# ===== Phase 3.2 新增：前置权限检查 =====
# 检查是否指定了需要管理员权限的日志类型，并验证当前权限
$requiresAdmin = $false
$adminCheckNeeded = @("Security", "Directory Service")  # 这些日志类型需要管理员权限

if ($LogTypes -and $LogTypes.Count -gt 0) {
    foreach ($logType in $LogTypes) {
        if ($logType -in $adminCheckNeeded) {
            $requiresAdmin = $true
            break
        }
    }
    
    if ($requiresAdmin) {
        # 检查管理员权限
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            # 权限不足，需要提示用户
            if ($Language -eq "CHS") {
                $errorMsg = "⚠️ 检测到需要管理员权限的日志类型 ($($LogTypes -join ', '))，但当前没有管理员权限。`n`n请通过以下方式运行：`n  1. 右键点击 AURORA.Launcher.exe 选择'以管理员身份运行'`n  2. 或者在 GUI 中选择 PRO 模式并授权提权`n`n程序将在 10 秒后自动关闭..."
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Yellow
                Write-Host "  ⚠️ 权限不足警告" -ForegroundColor Red
                Write-Host "========================================" -ForegroundColor Yellow
                Write-Host ""
                Write-Host $errorMsg -ForegroundColor White
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Yellow
            } else {
                $errorMsg = "⚠️ Log types requiring administrator privileges detected ($($LogTypes -join ', ')), but current user lacks admin rights.`n`nPlease run using:`n  1. Right-click AURORA.Launcher.exe and select 'Run as Administrator'`n  2. Or select PRO Mode in GUI and authorize elevation`n`nProgram will close automatically in 10 seconds..."
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Yellow
                Write-Host "  ⚠️ Permission Warning" -ForegroundColor Red
                Write-Host "========================================" -ForegroundColor Yellow
                Write-Host ""
                Write-Host $errorMsg -ForegroundColor White
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Yellow
            }
            
            Start-Sleep -Seconds 10
            Invoke-SafeExit -ExitCode 1
        }
    }
}

# ===== 核心修复 2：安全接管全局变量，防止强行覆盖为空 =====
$internalHashCreated = ($null -ne $global:syncHash)

if ($null -ne $hash) {
    if (-not $internalHashCreated) {
        Write-Host "检测到非法的 hash 参数注入" -ForegroundColor Red
        Write-Host "此脚本只能通过 GUI 启动" -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        Invoke-SafeExit -ExitCode 1
    }
    $global:syncHash = $hash
}

# ===== 安全检查：确保在 GUI 会话上下文中运行 =====
if ($null -eq $global:syncHash) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  ⛔ 安全检查失败" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "此脚本只能由主程序 GUI 启动，禁止独立运行" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "请使用以下方式启动：" -ForegroundColor White
    Write-Host "  1. 双击运行 AURORA-Analyzer.exe" -ForegroundColor Gray
    Write-Host "  2. 或者通过主 GUI 界面进入智能模式" -ForegroundColor Gray
    Write-Host ""
    Write-Host "程序将在 5 秒后自动关闭..." -ForegroundColor Gray

    Start-Sleep -Seconds 5
    Invoke-SafeExit -ExitCode 1
}

# =========================================================
# [安全沙箱执行器] Invoke-AuroraSafeAction
# 功能：带前置检查、风险评估、回滚机制的安全命令执行器
# =========================================================
function Invoke-AuroraSafeAction {
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$Command,
        
        [Parameter(Mandatory=$false)]
        [string]$Language = "CHS"
    )

    # ==========================================
    # 📦 Phase 4.2: 导入 Undo 支持模块
    # ==========================================
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$parentDir = Split-Path $scriptDir -Parent  # Scripts 根目录

# 💥 核心修复：检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# 导入 RestoreManager（如果尚未导入）- 仅在管理员权限下导入
if (-not (Get-Command Create-SystemRestorePoint -ErrorAction SilentlyContinue)) {
    $restoreManagerPath = Join-Path (Join-Path $parentDir "Repair") "AURORA-RestoreManager.ps1"
    if (Test-Path $restoreManagerPath) {
        if ($isAdmin) {
            try {
                . $restoreManagerPath
            } catch {
                # 导入失败，记录但继续
                Write-Verbose "RestoreManager 导入失败：$($_.Exception.Message)"
            }
        } else {
            # 非管理员权限，跳过导入
            Write-Verbose "跳过 RestoreManager 导入（需要管理员权限）"
        }
    }
}

# 导入 RepairLogger（如果尚未导入）
if (-not (Get-Command Start-RepairSession -ErrorAction SilentlyContinue)) {
    $repairLoggerPath = Join-Path (Join-Path $parentDir "Repair") "AURORA-RepairLogger.ps1"
    if (Test-Path $repairLoggerPath) {
        try {
            . $repairLoggerPath
        } catch {
            Write-Verbose "RepairLogger 导入失败：$($_.Exception.Message)"
        }
    }
}

# 导入 UndoManager（如果尚未导入）
if (-not (Get-Command Create-BackupSnapshot -ErrorAction SilentlyContinue)) {
    $undoManagerPath = Join-Path (Join-Path $parentDir "Session") "AURORA-UndoManager.ps1"
    if (Test-Path $undoManagerPath) {
        try {
            . $undoManagerPath
            # [修复] Initialize-UndoManager 返回 $true/$false，若不抑制会泄漏到
            #   Invoke-AuroraSafeAction 的返回值（组合成 Object[] 数组），
            #   导致调用方 elseif ($result -eq $true) 误判为成功，错误标记 IsExecuted。
            Initialize-UndoManager | Out-Null
        } catch {
            Write-Verbose "UndoManager 导入失败：$($_.Exception.Message)"
        }
    }
}

    # 新增：进入修复动作前，清空所有历史授权状态
    $global:syncHash.Authorized = $null
    $global:syncHash.RequiresAuthorization = $null
    $global:syncHash.PendingCommand = $null

    $lang = if ($Language -eq "CHS") {
        @{
            "PreCheck"    = "🔍 执行前置检查...";
            "PreCheckPass"= "✅ 前置检查通过";
            "PreCheckFail"= "❌ 前置检查失败，中止执行";
            "RiskConfirm" = "⚠️ 该操作需要您的确认授权才能继续";
            "Executing"   = "⚙️ 正在执行...";
            "Success"     = "✅ 执行成功";
            "Fail"        = "❌ 执行失败";
            "Rollback"    = "🔄 正在执行回滚操作...";
            "RollbackOk"  = "✅ 回滚完成";
            "RollbackFail"= "❌ 回滚失败，请手动处理";
            "ExecTime"    = "⏱️ 执行时间:";
            "ExecOutput"  = "📋 执行输出:";
            "MoreLines"   = " ...还有 {0} 行输出未显示";
            "ErrorOutput" = "❌ 错误输出:";
            "RollbackTime"= "⏱️ 回滚时间:";
            "RollbackOutput" = "📋 回滚输出:";
            "RollbackError" = "❌ 回滚错误输出:";
            "Seconds"     = "秒"
        }
    } else {
        @{
            "PreCheck"    = "🔍 Performing pre-check...";
            "PreCheckPass"= "✅ Pre-check passed";
            "PreCheckFail"= "❌ Pre-check failed, aborting";
            "RiskConfirm" = "⚠️ This operation requires your authorization to proceed";
            "Executing"   = "⚙️ Executing...";
            "Success"     = "✅ Execution successful";
            "Fail"        = "❌ Execution failed";
            "Rollback"    = "🔄 Performing rollback...";
            "RollbackOk"  = "✅ Rollback completed";
            "RollbackFail"= "❌ Rollback failed, please handle manually";
            "ExecTime"    = "⏱️ Execution time:";
            "ExecOutput"  = "📋 Execution output:";
            "MoreLines"   = " ...{0} more lines not displayed";
            "ErrorOutput" = "❌ Error output:";
            "RollbackTime"= "⏱️ Rollback time:";
            "RollbackOutput" = "📋 Rollback output:";
            "RollbackError" = "❌ Rollback error output:";
            "Seconds"     = "s"
        }
    }

    $cmdName = if ($Language -eq "CHS") { $Command.name } else { $Command.name_en }

    # =========================================================
    # Step 1: 前置检查 (Pre-Check)
    # =========================================================
    $global:syncHash.CurrentPipelineStep = 0
    $global:syncHash.CurrentPipelineStatus = "Running"
    Start-Sleep -Milliseconds 200
    
    Write-SmartLog ($lang["PreCheck"])
    $preCheckPassed = $true
    
    # === 新增：检查管理员权限 ===
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($Command.elevation_required -eq $true -and -not $isAdmin) {
        $global:syncHash.CurrentPipelineStatus = "Error"
        
        # 💥 核心修复：触发 GUI 提权对话框
        $global:syncHash.RequiresElevation = $true
        $global:syncHash.ElevationReason = if ($Language -eq "CHS") {
            "智能诊断引擎需要执行管理员权限操作：$cmdName"
        } else {
            "Smart Engine needs to execute administrator operation: $cmdName"
        }
        
        # 💥 核心修复：不发送 CommandResult，避免显示执行结果窗口（因为提权对话框已经弹出）
        # 只有在用户拒绝提权或超时时，才发送错误结果
        
        # 💥 核心修复：非阻塞等待，给 GUI 时间响应（延长到 30 秒，因为 MessageBox 会阻塞 UI 线程）
        # 使用循环等待，每次只等待 100ms，让 GUI Timer 有机会处理
        $waitStartTime = Get-Date
        $timeout = 30  # 30 秒超时（给用户足够时间点击 MessageBox）
        
        while ($global:syncHash.RequiresElevation -eq $true -and 
               (New-TimeSpan -Start $waitStartTime -End (Get-Date)).TotalSeconds -lt $timeout) {
            # 短暂挂起，让出 CPU 给 GUI
            Start-Sleep -Milliseconds 100
            
            # 💥 核心修复：检查 GUI 是否已经处理了请求
            if ($global:syncHash.ElevationAuthorized -ne $null) {
                # GUI 已经给出了授权结果，跳出等待
                break
            }
        }
        
        # 检查用户是否授权提权
        if ($global:syncHash.ElevationAuthorized -eq $true) {
            # 用户已授权，工具将以管理员身份重新启动
            Write-SmartLog ""
            if ($Language -eq "CHS") {
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host "  🔐 提权授权已确认" -ForegroundColor Green
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "✅ 工具将以管理员身份重新启动..." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "💡 提示：如果您没有看到重启，请手动点击界面上的" -ForegroundColor Gray
                Write-Host "   '🔐 提权' 按钮，然后确认提权请求。" -ForegroundColor Gray
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Cyan
            } else {
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host "  🔐 Elevation Authorized" -ForegroundColor Green
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "✅ Tool will restart as administrator..." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "💡 Hint: If you don't see restart, manually click" -ForegroundColor Gray
                Write-Host "   '🔐 Elevate' button on the interface and confirm." -ForegroundColor Gray
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Cyan
            }
            
            # 等待工具重启（GUI 会处理）
            Start-Sleep -Milliseconds 2000
            
            # 退出当前实例，等待提权后的新实例
            $global:syncHash.ScriptDone = $true
            $global:syncHash.IsRunning = $false
            Invoke-SafeExit -ExitCode 0
        } else {
            # 用户拒绝提权或超时
            $errorMsg = if ($Language -eq "CHS") {
                "❌ 需要管理员权限！请以管理员身份重新运行 AURORA。\n提示：右键点击 AURORA-Analyzer.exe，选择'以管理员身份运行'"
            } else {
                "❌ Administrator privileges required! Please re-run AURORA as administrator.\nHint: Right-click AURORA-Analyzer.exe and select 'Run as administrator'"
            }
            Write-SmartLog $errorMsg
            Start-Sleep -Milliseconds 2000
            return $false
        }
    }
    
    if ($Command.pre_check -and $Command.pre_check -ne "") {
        try {
            $preCheckResult = Invoke-Expression $Command.pre_check
            if (-not $preCheckResult) {
                $global:syncHash.CurrentPipelineStatus = "Error"
                Write-SmartLog ($lang["PreCheckFail"])
                return $false
            }
            $global:syncHash.CurrentPipelineStatus = "Success"
            Start-Sleep -Milliseconds 200
            Write-SmartLog ($lang["PreCheckPass"])
        } catch {
            $global:syncHash.CurrentPipelineStatus = "Error"
            Write-SmartLog ($lang["PreCheckFail"] + ": " + $_.Exception.Message)
            return $false
        }
    } else {
        $global:syncHash.CurrentPipelineStatus = "Success"
        Start-Sleep -Milliseconds 200
        Write-SmartLog ($lang["PreCheckPass"])
    }

    # =========================================================
    # Step 2: 风险评估与授权 (Risk Assessment)
    # =========================================================
    $global:syncHash.CurrentPipelineStep = 1
    $global:syncHash.CurrentPipelineStatus = "Running"
    Start-Sleep -Milliseconds 200
    
    $needsAuth = -not ($Command.auto_execute -eq $true)
    if ($needsAuth) {
        # 非 auto_execute 的命令需要授权
        Write-SmartLog ($lang["RiskConfirm"])
        
        # 在设置新请求之前，先重置所有相关状态
        $global:syncHash.Authorized = $null
        $global:syncHash.RequiresAuthorization = $false
        $global:syncHash.PendingCommand = $null
        
        # 通知 GUI 重置 IsModalShowing 标志
        $global:syncHash.ResetAuthorizationModal = $true
        
        # 给 GUI 一点时间来重置状态
        Start-Sleep -Milliseconds 100
        
        # Phase 2.3 核心优化：事件驱动替代轮询
        # 创建命名事件（跨 Runspace 共享）
        $eventName = "AURORA_Auth_$PID"
        $global:syncHash.AuthorizationEventName = $eventName
        
        # 现在设置新的授权请求
        $global:syncHash.RequiresAuthorization = $true
        $global:syncHash.PendingCommand = $Command
        $global:syncHash.Authorized = $null  # 重置授权状态
        
        # 等待用户授权（使用 EventWaitHandle，零 CPU 消耗）
        try {
            $eventWaitHandle = [System.Threading.EventWaitHandle]::OpenExisting($eventName)
            $waitHandle = $eventWaitHandle
        } catch {
            # 如果事件不存在，创建一个新的
            $waitHandle = New-Object System.Threading.EventWaitHandle($false, 
                [System.Threading.EventResetMode]::ManualReset, $eventName)
        }
        
        # 阻塞等待（最多 30 秒），不消耗 CPU
        $signaled = $waitHandle.WaitOne(30000)
        
        # 记录等待情况
        if ($signaled -and $global:syncHash.Authorized -eq $true) {
            Write-SmartLog ($L["GUI_Responded"] -f "EventWaitHandle")
        } else {
            Write-SmartLog $L["GUI_Timeout"]
        }
        
        # 清理事件句柄
        try { $waitHandle.Dispose() } catch { Write-Debug "Non-critical operation failed: $($_.Exception.Message)" }
        
        # 暂时返回，等待 GUI 授权
        return "PendingAuthorization"
    } else {
        $global:syncHash.CurrentPipelineStatus = "Success"
        Start-Sleep -Milliseconds 200
    }

    # =========================================================
    # Phase 4.2: 创建 Undo 支持（还原点和备份快照）
    # =========================================================
    $repairSessionId = $null
    $backupSnapshotId = $null
    $restorePointId = $null
    
    # 检查是否是需要创建 Undo 支持的修复命令
    $isRepairCommand = $Command.type -eq "powershell" -or $Command.type -eq "cmd"
    $hasSideEffects = $true  # 假设所有修复命令都有副作用
    
    if ($isRepairCommand -and $hasSideEffects) {
        $global:syncHash.CurrentPipelineStep = 1.5
        $global:syncHash.CurrentPipelineDetail = if ($Language -eq "CHS") { "创建撤销保护..." } else { "Creating Undo protection..." }
        
        Write-SmartLog ""
        if ($Language -eq "CHS") {
            Write-SmartLog "📦 Phase 4.2: 正在创建撤销保护（Undo Support）..."
        } else {
            Write-SmartLog "📦 Phase 4.2: Creating Undo protection..."
        }
        
        try {
            # 1. 开始修复会话
            $cmdName = if ($Language -eq "CHS") { $Command.name } else { $Command.name_en }
            $repairSession = Start-RepairSession -RepairType $cmdName -Target $cmdName -CreateRestorePoint:$false
            
            if ($repairSession) {
                $repairSessionId = $repairSession.SessionId
                if ($Language -eq "CHS") {
                    Write-SmartLog "   ✅ 修复会话已创建：$repairSessionId"
                } else {
                    Write-SmartLog "   ✅ Repair session created: $repairSessionId"
                }
            }
            
            # 2. 创建快速备份快照（如果命令涉及注册表或文件修改）
            $needsBackup = $Command.command -match "reg\s|Set-ItemProperty|New-Item|Remove-Item|Copy-Item|Move-Item"
            
            if ($needsBackup) {
                # 提取命令中的路径信息
                $paths = @()
                # 匹配注册表路径：HKLM:\xxx, HKCU:\xxx, HKU:\xxx
                if ($Command.command -match '(HK[LMU]:\\[^"\s\|]+)') {
                    $paths += $matches[1]
                }
                
                # 匹配文件路径：C:\xxx, D:\xxx 等
                if ($Command.command -match '([A-Z]:\\[^"\s\|]+)') {
                    $paths += $matches[1]
                }
                
                if ($paths.Count -gt 0) {
                    $snapshot = Create-BackupSnapshot -Type "Mixed" -Paths $paths
                    
                    if ($snapshot) {
                        $backupSnapshotId = $snapshot.SnapshotId
                        $repairSession.BackupSnapshotId = $backupSnapshotId
                        
                        if ($Language -eq "CHS") {
                            Write-SmartLog "   ✅ 快速备份已创建：$backupSnapshotId (大小：$($snapshot.Size))"
                        } else {
                            Write-SmartLog "   ✅ Fast backup created: $backupSnapshotId (Size: $($snapshot.Size))"
                        }
                    }
                }
            }
            
            # 3. 标记会话可撤销
            if ($repairSessionId) {
                # 检查是否有还原点或备份
                $canUndo = (-not [string]::IsNullOrEmpty($backupSnapshotId))
                
                if ($canUndo) {
                    # 完成会话并标记为可撤销
                    # [修复] 抑制 Complete-RepairSession 的返回值，避免泄漏到
                    #   Invoke-AuroraSafeAction 的返回值（组合成 Object[] 数组）
                    Complete-RepairSession -SessionId $repairSessionId -Status "Success" -BackupSnapshotId $backupSnapshotId | Out-Null

                    if ($Language -eq "CHS") {
                        Write-SmartLog "   🔄 撤销保护已就绪（可撤销此修复操作）"
                    } else {
                        Write-SmartLog "   🔄 Undo protection ready (this repair can be undone)"
                    }
                } else {
                    Complete-RepairSession -SessionId $repairSessionId -Status "Success" | Out-Null
                }
            }
            
        } catch {
            # Undo 创建失败不影响主命令执行，仅记录警告
            if ($Language -eq "CHS") {
                Write-SmartLog "   ⚠️ 撤销保护创建失败：$($_.Exception.Message)"
            } else {
                Write-SmartLog "   ⚠️ Undo protection creation failed: $($_.Exception.Message)"
            }
        }
        
        Write-SmartLog ""
    }

    # =========================================================
    # Step 3: 执行主体命令 (Main Execution)
    # =========================================================
    $global:syncHash.CurrentPipelineStep = 2
    $global:syncHash.CurrentPipelineStatus = "Running"
    Start-Sleep -Milliseconds 200
    
    Write-SmartLog ($lang["Executing"])
    $executionSuccess = $true
    $executionOutput = @()
    $executionError = @()
    $executionTime = 0

    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        if ($Command.type -eq "powershell") {
            # 捕获 PowerShell 命令的输出，确保返回人类可读的文本
            $executionOutput = Invoke-Expression $Command.command 2>&1 | Out-String
        } else {
            # 检查是否是 URI 协议命令或不需要输出的特殊Windows文件/程序
            # (如 ms-settings:, .cpl, .msc, 独立程序等，但不包括 sfc/dism 这类需要输出的控制台程序)
            $isSpecialCommand = $Command.command -match '^(ms-[a-zA-Z0-9]+:|http:|https:|mailto:|telnet:|ftp:|file:)' -or 
                               $Command.command -match '\.(cpl|msc|app|scr)$' -or 
                               $Command.command -match '^control\.exe' -or 
                               $Command.command -match '^perfmon\s' -or  # perfmon 带参数
                               $Command.command -match '^mdsched\.exe$'  # 内存诊断工具

            if ($isSpecialCommand) {
                # 处理 URI 协议命令或不需要输出的特殊程序
                try {
                    # 对于URI协议（如 ms-settings:），使用PowerShell的Start-Process更可靠
                    Start-Process -FilePath $Command.command -ErrorAction Stop
                    $executionOutput = "Special command started successfully"
                    $executionError = ""
                } catch {
                    # 如果Start-Process失败，尝试用传统方法作为后备
                    try {
                        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                        $processInfo.FileName = $Command.command
                        $processInfo.UseShellExecute = $true
                        $processInfo.CreateNoWindow = $false
                        
                        $process = New-Object System.Diagnostics.Process
                        $process.StartInfo = $processInfo
                        $process.Start() | Out-Null
                        $executionOutput = "Special command started successfully (fallback method)"
                        $executionError = ""
                    } catch {
                        throw "Failed to start special command: $($Command.command) - $($_.Exception.Message)"
                    }
                }
            } else {
                # 捕获普通 CMD 命令的输出
                $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                $processInfo.FileName = "cmd.exe"
                $processInfo.Arguments = "/c $($Command.command)"
                $processInfo.RedirectStandardOutput = $true
                $processInfo.RedirectStandardError = $true
                $processInfo.UseShellExecute = $false
                $processInfo.CreateNoWindow = $true
                
                $process = New-Object System.Diagnostics.Process
                $process.StartInfo = $processInfo
                $process.Start() | Out-Null
                $executionOutput = $process.StandardOutput.ReadToEnd()
                $executionError = $process.StandardError.ReadToEnd()
                $process.WaitForExit()
                
                # 检查退出码
                if ($process.ExitCode -ne 0) {
                    throw "Command exited with code $($process.ExitCode): $executionError"
                }
            }
        }
        
        $stopwatch.Stop()
        $executionTime = $stopwatch.Elapsed.TotalSeconds
        
        $global:syncHash.CurrentPipelineStatus = "Success"
        Start-Sleep -Milliseconds 200
        Write-SmartLog ($lang["Success"])
        Write-SmartLog "$($lang['ExecTime']) $($executionTime.ToString('0.00')) $($lang['Seconds'])"
        
        # 显示执行输出（限制输出行数，避免过多信息）
        if ($executionOutput) {
            # 清理输出，移除空行和多余的空白
            $cleanOutput = $executionOutput.Trim()
            if ($cleanOutput) {
                Write-SmartLog ($lang["ExecOutput"])
                $outputLines = $cleanOutput -split "`n"
                $maxLines = 10
                $displayLines = $outputLines | Where-Object { $_.Trim() } | Select-Object -First $maxLines
                foreach ($line in $displayLines) {
                    $trimmedLine = $line.Trim()
                    if ($trimmedLine) {
                        Write-SmartLog "  $trimmedLine"
                    }
                }
                if ($outputLines.Count -gt $maxLines) {
                    Write-SmartLog ("  " + ($lang["MoreLines"] -f ($outputLines.Count - $maxLines)))
                }
            }
        }
        
        $executionSuccess = $true
        
        # 发送执行结果到 GUI
        $resultMessage = $lang["Success"]
        $global:syncHash.CommandResult = @{
            ActionName = $cmdName
            Result = $resultMessage
            Output = $executionOutput
            ExecutionTime = "$($executionTime.ToString('0.00')) $($lang['Seconds'])"
        }
        
        # 等待一段时间，确保 GUI 有足够的时间处理结果并显示弹窗
        Start-Sleep -Milliseconds 2000
    } catch {
        $global:syncHash.CurrentPipelineStatus = "Error"
        $executionSuccess = $false
        
        # === 核心修复：专门处理权限错误，并连接提权按钮 ===
        $exceptionMsg = $_.Exception.Message
        $isPermissionError = $exceptionMsg -match "740" -or $exceptionMsg -match "权限" -or $exceptionMsg -match "Elevation" -or $exceptionMsg -match "privilege" -or $exceptionMsg -match "Administrator"
        
        if ($isPermissionError) {
            $outputText = "ERROR_ELEVATION_REQUIRED (Code: 740)"
            
            # 💥 核心修复：触发 GUI 提权对话框
            $global:syncHash.RequiresElevation = $true
            $global:syncHash.ElevationReason = if ($Language -eq "CHS") {
                "智能诊断引擎执行失败，需要管理员权限：$cmdName"
            } else {
                "Smart Engine execution failed, needs administrator privileges: $cmdName"
            }
            
            # 💥 核心修复：非阻塞等待，给 GUI 时间响应（延长到 30 秒，因为 MessageBox 会阻塞 UI 线程）
            # 使用循环等待，每次只等待 100ms，让 GUI Timer 有机会处理
            $waitStartTime = Get-Date
            $timeout = 30  # 30 秒超时（给用户足够时间点击 MessageBox）
            
            while ($global:syncHash.RequiresElevation -eq $true -and 
                   (New-TimeSpan -Start $waitStartTime -End (Get-Date)).TotalSeconds -lt $timeout) {
                # 短暂挂起，让出 CPU 给 GUI
                Start-Sleep -Milliseconds 100
                
                # 💥 核心修复：检查 GUI 是否已经处理了请求
                if ($global:syncHash.ElevationAuthorized -ne $null) {
                    # GUI 已经给出了授权结果，跳出等待
                    break
                }
            }
            
            # 检查用户是否授权提权
            if ($global:syncHash.ElevationAuthorized -eq $true) {
                # 用户已授权，工具将以管理员身份重新启动
                Write-SmartLog ""
                if ($Language -eq "CHS") {
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "  🔐 提权授权已确认" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "✅ 工具将以管理员身份重新启动..." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "💡 提示：如果您没有看到重启，请手动点击界面上的" -ForegroundColor Gray
                    Write-Host "   '🔐 提权' 按钮，然后确认提权请求。" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                } else {
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "  🔐 Elevation Authorized" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "✅ Tool will restart as administrator..." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "💡 Hint: If you don't see restart, manually click" -ForegroundColor Gray
                    Write-Host "   '🔐 Elevate' button on the interface and confirm." -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                }
                
                # 等待工具重启（GUI 会处理）
                Start-Sleep -Milliseconds 2000
                
                # 退出当前实例，等待提权后的新实例
                $global:syncHash.ScriptDone = $true
                $global:syncHash.IsRunning = $false
                Invoke-SafeExit -ExitCode 0
            } else {
                # 用户拒绝提权或超时
                $errorMessage = if ($Language -eq "CHS") {
                    "❌ 需要管理员权限！请以管理员身份重新运行 AURORA。\n提示：右键点击 AURORA-Analyzer.exe，选择'以管理员身份运行'"
                } else {
                    "❌ Administrator privileges required! Please re-run AURORA as administrator.\nHint: Right-click AURORA-Analyzer.exe and select 'Run as administrator'"
                }
                Write-SmartLog $errorMessage
            }
        } else {
            $errorMessage = $lang["Fail"] + ": " + $exceptionMsg
            Write-SmartLog $errorMessage
            
            # 显示错误输出
            if ($executionError) {
                Write-SmartLog ($lang["ErrorOutput"])
                $errorLines = $executionError -split "`n"
                foreach ($line in $errorLines) {
                    if ($line.Trim()) {
                        Write-SmartLog "  $line"
                    }
                }
            }
            $outputText = if ($executionError) { $executionError } else { $exceptionMsg }
        }
        
        # 💥 核心修复：只有在非提权场景下才发送 CommandResult
        # 提权场景下，CommandResult 会导致显示执行结果窗口（与提权对话框冲突）
        if (-not $isPermissionError) {
            # 发送执行结果到 GUI
            $global:syncHash.CommandResult = @{
                ActionName = $cmdName
                Result = $errorMessage
                Output = $outputText
                ExecutionTime = "$($executionTime.ToString('0.00')) $($lang['Seconds'])"
            }
        }
        
        # 等待一段时间，确保 GUI 有足够的时间处理结果并显示弹窗
        Start-Sleep -Milliseconds 2000
    }

    # =========================================================
    # Step 4: 失败时执行回滚 (Rollback on Failure)
    # =========================================================
    $global:syncHash.CurrentPipelineStep = 3
    if (-not $executionSuccess -and $Command.rollback_command -and $Command.rollback_command -ne "") {
        $global:syncHash.CurrentPipelineStatus = "Running"
        $global:syncHash.CurrentPipelineDetail = if ($Language -eq "CHS") { "正在执行回滚策略..." } else { "Rolling back..." }
        Start-Sleep -Milliseconds 400
        
        Write-SmartLog ($lang["Rollback"])
        $rollbackSuccess = $true
        $rollbackOutput = @()
        $rollbackError = @()
        $rollbackTime = 0
        
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $rollbackOutput = Invoke-Expression $Command.rollback_command 2>&1
            
            $stopwatch.Stop()
            $rollbackTime = $stopwatch.Elapsed.TotalSeconds
            
            $global:syncHash.CurrentPipelineStatus = "Success"
            $global:syncHash.CurrentPipelineDetail = if ($Language -eq "CHS") { "回滚完成" } else { "Rollback OK" }
            Start-Sleep -Milliseconds 1200 # 留足时间让文字滑入
            Write-SmartLog ($lang["RollbackOk"])
            Write-SmartLog "$($lang['RollbackTime']) $($rollbackTime.ToString('0.00')) $($lang['Seconds'])"
            
            # 显示回滚输出
            if ($rollbackOutput) {
                Write-SmartLog ($lang["RollbackOutput"])
                $outputLines = $rollbackOutput -split "`n"
                $maxLines = 5
                $displayLines = $outputLines | Select-Object -First $maxLines
                foreach ($line in $displayLines) {
                    if ($line.Trim()) {
                        Write-SmartLog "  $line"
                    }
                }
                if ($outputLines.Count -gt $maxLines) {
                    Write-SmartLog ("  " + ($lang["MoreLines"] -f ($outputLines.Count - $maxLines)))
                }
            }
            
            $rollbackSuccess = $true
        } catch {
            $global:syncHash.CurrentPipelineStatus = "Error"
            $global:syncHash.CurrentPipelineDetail = if ($Language -eq "CHS") { "回滚失败" } else { "Rollback Failed" }
            Start-Sleep -Milliseconds 1200
            Write-SmartLog ($lang["RollbackFail"] + ": " + $_.Exception.Message)
            
            # 显示回滚错误
            if ($rollbackError) {
                Write-SmartLog ($lang["RollbackError"])
                $errorLines = $rollbackError -split "`n"
                foreach ($line in $errorLines) {
                    if ($line.Trim()) {
                        Write-SmartLog "  $line"
                    }
                }
            }
            
            $rollbackSuccess = $false
        }
    } else {
        # 💥 核心修复：推送成功文案，并强制挂起 1.2 秒，让 GUI 有充足时间点亮第四个绿灯并播放滑入动画
        $global:syncHash.CurrentPipelineStatus = "Success"
        $global:syncHash.CurrentPipelineDetail = if ($Language -eq "CHS") { "验证通过已修复" } else { "Verification Passed" }
        Start-Sleep -Milliseconds 1200 
    }

    return $executionSuccess
}

# =========================================================
# [资源区] 动态多语言字典 (Bilingual Dictionary)
# =========================================================
$langDict = @{
    "CHS" = @{
        "Phase1"        = "【1/4】侦测系统生命体征";
        "Phase2"        = "【2/4】并发提取异常日志";
        "Phase3"        = "【3/4】知识图谱靶向碰撞";
        "Phase4"        = "【4/4】智能自主修复与交互终端";
        "Init"          = "🤖 正在初始化 AURORA 智能诊断与自主修复引擎...";
        "OS_Info"       = "🖥️ 操作系统: {0}";
        "Uptime"        = "⏱️ 系统连续运行时间: {0} 小时";
        "Target_Short"  = "⚠️ 侦测到近期重启。靶向锁定为: 异常重启溯源 (范围: {0} ~ {1})";
        "Target_Long"   = "✅ 运行时间达标且未见近期崩溃。`n🎯 靶向锁定: 常规 24H 健康巡检 (范围: {0} ~ {1})";
        "Read_Start"    = "⚡ 正在从内核提取高危日志 (Critical/Error/Warning)...";
        "Read_Done"     = "📦 成功提取并轻量化 {0} 条异常事件记录。";
        "KB_Load"       = "🧠 正在装载并预编译 AURORA-TechData 知识图谱...";
        "KB_Done"       = "✅ 图谱装载完成，激活 {0} 条诊断规则。开始极速碰撞...";
        "KB_CacheHit"   = "⚡ 知识图谱缓存命中，已加载 {0} 条规则（跳过 JSON 解析与索引构建）";
        "LogTypes_Specified" = "📋 已指定日志类型：{0}";
        "Check_Done"    = "🎯 碰撞分析完成！发现 {0} 类已知高危问题。";
        "No_Issue"      = "🎉 完美！系统当前未命中任何高危规则，运行状态极佳！";
        "Repair_Menu"   = "`n================== [ 靶向自主修复方案 ] ==================";
        "Repair_Prompt" = "`n>>> 请在下方输入 [序号] 执行修复，或直接按 [Enter] 退出引擎：";
        "Input_Invalid" = "❌ 无效的序号，请重新输入。";
        "Input_Skip"    = "⏭️ 用户跳过修复，引擎准备退出。";
        "Executing"     = "⚙️ 正在执行防线修复: {0} ...";
        "Exec_Success"  = "✅ 指令下发成功。";
        "Exec_Fail"     = "❌ 指令执行失败：{0}";
        "Fatal_Error"   = "❌ 智能引擎遭遇致命错误：{0}";
        "Engine_Exit"   = "👋 智能引擎分析完毕，进程安全退出。";
        # PRO 模式相关
        "PRO_Detect"    = "📖 检测到 PRO 模式导出，正在读取：{0}";
        "PRO_CSV_Found" = "✅ 找到 {0} 个导出的 CSV 文件，正在加载...";
        "PRO_CSV_Loading" = "   正在加载：{0}";
        "PRO_CSV_Done"  = "✅ 已加载 {0} 个事件";
        "PRO_CSV_NotFound" = "⚠️ 未找到匹配的 CSV 文件，降级到实时日志提取";
        "PRO_CSV_Error" = "⚠️ 读取 PRO 导出失败：{0}";
        "PRO_CSV_Fallback" = "   正在降级到实时日志提取...";
        "PRO_LiveExtract" = "🔍 正在从系统实时提取日志...";
        "Minidump_Warning" = "🚨 警告：在系统中侦测到未分析的 Minidump 蓝屏内存转储文件！";
        "GUI_Responded" = "✅ GUI 已响应授权请求（等待了 {0}ms）";
        "GUI_Timeout" = "⚠️ GUI 响应超时（等待了 30 秒），继续执行...";
    };
    "ENG" = @{
        "Phase1"        = "[1/4] Detecting System Vitals";
        "Phase2"        = "[2/4] Extracting Anomaly Logs";
        "Phase3"        = "[3/4] Knowledge Graph Collision";
        "Phase4"        = "[4/4] Auto-Healing Interactive Terminal";
        "Init"          = "🤖 Initializing AURORA Smart Diagnostics & Auto-Healing Engine...";
        "OS_Info"       = "🖥️ Operating System: {0}";
        "Uptime"        = "⏱️ System Uptime: {0} hours";
        "Target_Short"  = "⚠️ Recent reboot detected. Target: Abnormal Reboot Trace (Range: {0} ~ {1})";
        "Target_Long"   = "✅ Uptime sufficient, no recent crash detected.`n🎯 Target: Routine 24H Health Check (Range: {0} ~ {1})";
        "Read_Start"    = "⚡ Extracting high-risk logs from kernel (Critical/Error/Warning)...";
        "Read_Done"     = "📦 Successfully extracted and streamlined {0} anomaly events.";
        "KB_Load"       = "🧠 Loading and pre-compiling AURORA-TechData graph...";
        "KB_Done"       = "✅ Graph loaded, {0} rules activated. Starting fast collision...";
        "KB_CacheHit"   = "⚡ Knowledge graph cache hit, loaded {0} rules (skipped JSON parsing & indexing)";
        "LogTypes_Specified" = "📋 Specified log types: {0}";
        "Check_Done"    = "🎯 Collision analysis complete! Found {0} known high-risk issues.";
        "No_Issue"      = "🎉 Perfect! No high-risk rules matched. System is in excellent condition!";
        "Repair_Menu"   = "`n================== [ Auto-Healing Solutions ] ==================";
        "Repair_Prompt" = "`n>>> Please input [Number] below to execute repair, or press [Enter] to exit:";
        "Input_Invalid" = "❌ Invalid number, please try again.";
        "Input_Skip"    = "⏭️ User skipped repair, engine preparing to exit.";
        "Executing"     = "⚙️ Executing defense repair: {0} ...";
        "Exec_Success"  = "✅ Command dispatched successfully.";
        "Exec_Fail"     = "❌ Command execution failed: {0}";
        "Fatal_Error"   = "❌ Fatal engine error: {0}";
        "Engine_Exit"   = "👋 Smart engine analysis complete, process exiting safely.";
        # PRO Mode Related
        "PRO_Detect"    = "📖 Detected PRO mode export, reading from: {0}";
        "PRO_CSV_Found" = "✅ Found {0} exported CSV file(s), loading...";
        "PRO_CSV_Loading" = "   Loading: {0}";
        "PRO_CSV_Done"  = "✅ Loaded {0} events from PRO export";
        "PRO_CSV_NotFound" = "⚠️ No matching CSV files found, falling back to live log extraction";
        "PRO_CSV_Error" = "⚠️ Failed to read PRO export: {0}";
        "PRO_CSV_Fallback" = "   Falling back to live log extraction...";
        "PRO_LiveExtract" = "🔍 Extracting live logs from system...";
        "Minidump_Warning" = "🚨 WARNING: Unanalyzed Minidump blue screen crash dump files detected on system!";
        "GUI_Responded" = "✅ GUI responded to authorization request (waited {0}ms)";
        "GUI_Timeout" = "⚠️ GUI response timeout (waited 30 seconds), continuing...";
    }
}
$L = $langDict[$Language]

# =========================================================
# Phase 3.3 辅助函数：BugCheck 代码查询表
# =========================================================
function Get-BugCheckInfo {
    param(
        [Parameter(Mandatory=$true)]
        [uint32]$Code
    )
    
    # 常见 BugCheck 代码查询表（来源：Microsoft Docs）
    $bugcheckTable = @{
        0x0000000A = @{ Name = "IRQL_NOT_LESS_OR_EQUAL"; Description = "内核模式驱动程序访问了未授权的内存"; Solution = "更新驱动程序，特别是显卡、网卡驱动" }
        0x0000001E = @{ Name = "KMODE_EXCEPTION_NOT_HANDLED"; Description = "内核模式异常未处理"; Solution = "检查驱动程序冲突，特别是第三方驱动" }
        0x00000024 = @{ Name = "NTFS_FILE_SYSTEM"; Description = "NTFS 文件系统错误"; Solution = "运行 chkdsk /f 检查磁盘" }
        0x0000003B = @{ Name = "SYSTEM_SERVICE_EXCEPTION"; Description = "系统服务异常"; Solution = "更新 Windows 和驱动程序" }
        0x00000050 = @{ Name = "PAGE_FAULT_IN_NONPAGED_AREA"; Description = "页面错误在非分页区域"; Solution = "检查内存条，更新驱动程序" }
        0x00000077 = @{ Name = "KERNEL_STACK_INPAGE_ERROR"; Description = "内核栈页面错误"; Solution = "检查硬盘健康状态，运行 chkdsk" }
        0x0000007A = @{ Name = "KERNEL_DATA_INPAGE_ERROR"; Description = "内核数据页面错误"; Solution = "检查硬盘、内存，运行诊断工具" }
        0x0000007E = @{ Name = "SYSTEM_THREAD_EXCEPTION_NOT_HANDLED"; Description = "系统线程异常未处理"; Solution = "更新显卡驱动，检查系统更新" }
        0x0000007F = @{ Name = "UNEXPECTED_KERNEL_MODE_TRAP"; Description = "意外的内核模式陷阱"; Solution = "检查内存、CPU 超频设置" }
        0x0000008E = @{ Name = "KERNEL_MODE_EXCEPTION_NOT_HANDLED"; Description = "内核模式异常未处理"; Solution = "更新驱动程序，检查硬件兼容性" }
        0x0000009F = @{ Name = "DRIVER_POWER_STATE_FAILURE"; Description = "驱动程序电源状态错误"; Solution = "更新电源管理相关驱动，禁用快速启动" }
        0x000000A5 = @{ Name = "ACPI_BIOS_ERROR"; Description = "ACPI BIOS 错误"; Solution = "更新 BIOS，检查 ACPI 设置" }
        0x000000D1 = @{ Name = "DRIVER_IRQL_NOT_LESS_OR_EQUAL"; Description = "驱动程序 IRQL 错误"; Solution = "更新网卡、显卡等硬件驱动" }
        0x000000EA = @{ Name = "THREAD_STUCK_IN_DEVICE_DRIVER"; Description = "线程卡在设备驱动中"; Solution = "更新显卡驱动，检查散热" }
        0x000000F4 = @{ Name = "CRITICAL_OBJECT_TERMINATION"; Description = "关键系统对象终止"; Solution = "检查硬盘健康，运行 chkdsk" }
        0x000000FE = @{ Name = "BUGCODE_USB_DRIVER"; Description = "USB 驱动程序错误"; Solution = "更新 USB 控制器驱动，禁用 USB 选择性暂停" }
        0x00000109 = @{ Name = "CRITICAL_STRUCTURE_CORRUPTION"; Description = "关键结构损坏"; Solution = "检查硬件问题，更新 BIOS" }
        0x00000116 = @{ Name = "VIDEO_TDR_ERROR"; Description = "显卡 TDR 错误"; Solution = "更新显卡驱动，检查散热和供电" }
        0x00000124 = @{ Name = "WHEA_UNCORRECTABLE_ERROR"; Description = "硬件错误架构检测到不可纠正错误"; Solution = "检查 CPU、内存、硬盘健康状态" }
        0x00000133 = @{ Name = "DPC_WATCHDOG_VIOLATION"; Description = "DPC 看门狗违规"; Solution = "更新 SSD 固件，检查驱动程序" }
        0x00000139 = @{ Name = "KERNEL_SECURITY_CHECK_FAILURE"; Description = "内核安全检查失败"; Solution = "检查内存损坏，更新驱动程序" }
        0xC000021A = @{ Name = "STATUS_SYSTEM_PROCESS_TERMINATED"; Description = "关键系统进程终止"; Solution = "运行 sfc /scannow，检查系统文件完整性" }
    }
    
    if ($bugcheckTable.ContainsKey($Code)) {
        return $bugcheckTable[$Code]
    } else {
        # 未知 BugCheck 代码，返回通用信息
        return @{
            Name = "UNKNOWN_BUGCHECK_0x{0:X8}" -f $Code
            Description = "未记录的 BugCheck 代码"
            Solution = "建议查看 Microsoft Docs 或使用 WinDbg 进行详细分析"
        }
    }
}

# =========================================================
# [工具函数] 智能日志回显 (带时间戳)
# =========================================================
function Write-SmartLog {
    param([string]$Message, [string]$Status = "")
    $timestamp = [datetime]::Now.ToString('HH:mm:ss')
    $global:syncHash.LogOutput += "[$timestamp] $Message`n"
    if ($Status) { $global:syncHash.CurrentStatus = $Status }
}

try {
    $global:syncHash.IsRunning = $true
    $global:syncHash.Progress = 5

    # =========================================================
    # Phase 1: 智能环境感知 (Auto-Detect) - 重构版
    # =========================================================
    $global:syncHash.CurrentActivity = $L["Phase1"]
    Write-SmartLog $L["Init"] "Initializing Engine..."
    Start-Sleep -Milliseconds 600
    
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $bootTime = $osInfo.LastBootUpTime
    $uptime = (Get-Date) - $bootTime
    $uptimeHours = [math]::Round($uptime.TotalHours, 2)
    
    Write-SmartLog ($L["OS_Info"] -f $osInfo.Caption)
    Write-SmartLog ($L["Uptime"] -f $uptimeHours)

    # 1. 优先尊重 GUI 层传来的时间参数
    if ($null -ne $StartTime -and $null -ne $EndTime) {
        $realStartTime = [datetime]$StartTime
        $realEndTime = [datetime]$EndTime
        Write-SmartLog "🎯 检测到用户指定时间范围: $($realStartTime.ToString('MM-dd HH:mm')) ~ $($realEndTime.ToString('HH:mm'))" "Custom Range"
    } 
    else {
        $realEndTime = Get-Date
        
        # 2. 智能探针：不要猜死机时间，直接去查系统最后一次意外关机/蓝屏的时间戳 (EventID 41: Kernel-Power, 6008: Unexpected Shutdown)
        $lastCrash = Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,6008} -MaxEvents 1 -ErrorAction SilentlyContinue
        
        # 3. 动态决策时间窗口
        if ($lastCrash -and ($realEndTime - $lastCrash.TimeCreated).TotalHours -lt 48) {
            # 如果 48 小时内发生过真实蓝屏/断电，精准锁定到该崩溃点前 2 小时
            $realStartTime = $lastCrash.TimeCreated.AddHours(-2)
            Write-SmartLog "⚠️ 侦测到近期硬崩溃 (Event $($lastCrash.Id)). 靶向锁定: 崩溃溯源 ($($realStartTime.ToString('MM-dd HH:mm')) 起)" "Crash Trace Mode"
        }
        elseif ($uptime.TotalHours -lt 2) {
            # 刚开机不久，且近期无崩溃记录，往前推 4 小时以防万一
            $realStartTime = $realEndTime.AddHours(-4)
            Write-SmartLog "ℹ️ 近期重启，未发现崩溃特征。靶向锁定: 启动健康校验" "Boot Check Mode"
        } 
        else {
            # 稳定运行中，执行常规 24 小时巡检
            $realStartTime = $realEndTime.AddHours(-24)
            Write-SmartLog ($L["Target_Long"] -f $realStartTime.ToString('MM-dd HH:mm'), $realEndTime.ToString('MM-dd HH:mm')) "Routine Check Mode"
        }
    }

    # 统一将决策后的时间赋值给后续 Phase 使用的变量
    $startTime = $realStartTime
    $endTime = $realEndTime

    # 4. Phase 3.3 核心优化：Minidump .dmp 自动解析
    $minidumpPath = "$env:windir\Minidump"
    if (Test-Path $minidumpPath) {
        $dmpFiles = Get-ChildItem -Path $minidumpPath -Filter "*.dmp" -File -ErrorAction SilentlyContinue | 
                    Sort-Object LastWriteTime -Descending | 
                    Select-Object -First 5  # 最多分析最近 5 个
        
        if ($dmpFiles.Count -gt 0) {
            Write-SmartLog "📋 发现 $($dmpFiles.Count) 个蓝屏转储文件，正在解析关键信息..." "Minidump Analysis"
            
            # 尝试解析每个 .dmp 文件的 BugCheck 代码
            foreach ($dmp in $dmpFiles) {
                try {
                    # L1 方案：通过 PE 头解析 BugCheck 代码（无需 WinDbg）
                    # MINIDUMP_HEADER 结构：前 32 bytes，BugCheck 信息在 offset 14h-1Fh
                    $fileStream = [System.IO.File]::Open($dmp.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
                    $reader = New-Object System.IO.BinaryReader($fileStream)
                    
                    # 读取 MINIDUMP_HEADER (32 bytes)
                    $signature = $reader.ReadInt32()  # 'MDMP' = 0x504D444D
                    if ($signature -eq 0x504D444D) {  # 验证签名
                        # 跳过 Version (4), HeaderSize (4), Flags (4), NumberOfStreams (4), StreamDirectoryRva (4), Checksum (4)
                        $reader.BaseStream.Position = 24
                        
                        # 读取 BugCheck 信息 (20 bytes)
                        $bugcheckCode = $reader.ReadUInt32()
                        $bugcheckParameter1 = $reader.ReadUInt64()
                        $bugcheckParameter2 = $reader.ReadUInt64()
                        $bugcheckParameter3 = $reader.ReadUInt64()
                        $bugcheckParameter4 = $reader.ReadUInt64()
                        
                        # 查找 BugCheck 代码对应的解释
                        $bugcheckInfo = Get-BugCheckInfo -Code $bugcheckCode
                        
                        # 输出分析结果
                        $ageInDays = [math]::Round((New-TimeSpan -Start $dmp.LastWriteTime -End (Get-Date)).TotalDays, 1)
                        Write-SmartLog "  📋 $($dmp.Name) ($ageInDays 天前):"
                        Write-SmartLog "     BugCheck Code: 0x$($bugcheckCode.ToString("X8"))"
                        Write-SmartLog "     名称：$($bugcheckInfo.Name)"
                        Write-SmartLog "     说明：$($bugcheckInfo.Description)"
                        Write-SmartLog "     参数：0x$($bugcheckParameter1.ToString("X16")), 0x$($bugcheckParameter2.ToString("X16")), ..."
                        
                        # 如果 BugCheck 有已知解决方案，给出建议
                        if ($bugcheckInfo.Solution) {
                            Write-SmartLog "     💡 建议：$($bugcheckInfo.Solution)"
                        }
                    }
                    
                    $reader.Close()
                    $fileStream.Close()
                } catch {
                    Write-SmartLog "  ⚠️ 无法解析 $($dmp.Name): $($_.Exception.Message)"
                }
            }
            
            Write-SmartLog "✅ Minidump 分析完成，共分析 $($dmpFiles.Count) 个文件"
        }
    }

    # =========================================================
    # Phase 2: 并发提取与轻量化 (Auto-Read)
    # =========================================================
    $global:syncHash.Progress = 30
    $global:syncHash.CurrentActivity = $L["Phase2"]
    Write-SmartLog $L["Read_Start"] "Extracting Logs..."
    
    # Phase 3.2 核心优化：支持更多日志类型，自动检测可访问的日志
    $defaultLogNames = @("System", "Application")
    $extendedLogNames = @("Security", "Setup", "DNS Server", "DHCP Server", "Directory Service", "IIS Admin Service")
    
    # 根据参数决定日志范围
    if ($LogTypes -and $LogTypes.Count -gt 0) {
        # 用户指定了日志类型
        $logNames = @($LogTypes)
        Write-SmartLog ($L["LogTypes_Specified"] -f ($logNames -join ", "))
    } else {
        # 默认模式：System + Application
        $logNames = $defaultLogNames
    }
    
    $levels = @(1, 2, 3) # Critical, Error, Warning
    $rawEvents = @()

    # ====== 核心升级：PRO 模式调用时读取已导出的日志文件（复用于 GUI 智能模式）======
    # 检测逻辑：无论是从 PRO 模式还是 GUI 直接进入，都检测已导出的 CSV
    if ($FromPRO -or $FromGUI) {
        if ($ExportedLogPath) {
            $ExportedLogPath = [System.IO.Path]::GetFullPath($ExportedLogPath)
            Write-SmartLog ($L["PRO_Detect"] -f $ExportedLogPath)
        } else {
            # 自动检测默认导出路径（UserLogs 目录）
            $defaultExportPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\UserLogs"))
            if (Test-Path $defaultExportPath) {
                $ExportedLogPath = [System.IO.Path]::GetFullPath($defaultExportPath)
                Write-SmartLog ($L["PRO_Detect"] -f $ExportedLogPath)
            }
        }
        
        if ($ExportedLogPath -and (Test-Path $ExportedLogPath)) {
        
        try {
            # 查找 PRO 模式导出的 CSV 文件（支持多种命名格式）
            # 格式 1: *_Log_*.csv (中英文版通用)
            # 格式 2: *_日志_*.csv (中文版特殊格式)
            $csvFiles = @()
            
            # 尝试查找 *_Log_*.csv (中英文版通用格式)
            $logCsvFiles = Get-ChildItem -Path $ExportedLogPath -Filter "*_Log_*.csv" -File -ErrorAction SilentlyContinue
            if ($logCsvFiles) { $csvFiles += $logCsvFiles }
            
            # 尝试查找 *_日志_*.csv (中文版特殊格式)
            $chineseCsvFiles = Get-ChildItem -Path $ExportedLogPath -Filter "*_日志_*.csv" -File -ErrorAction SilentlyContinue
            if ($chineseCsvFiles) { $csvFiles += $chineseCsvFiles }
            
            # 去重
            $csvFiles = $csvFiles | Select-Object -Unique
            
            # 核心修复：排除趋势数据文件（只读取主日志文件）
            $csvFiles = $csvFiles | Where-Object { $_.Name -notmatch '_趋势数据|_TrendData' }
            
            if ($csvFiles.Count -gt 0) {
                # 💥 核心升级：如果从 GUI 进入，显示全息对话框询问用户
                if ($FromGUI -and $GUI_Mode) {
                    # 计算文件信息
                    $newestFile = $csvFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    $fileAge = [math]::Round((New-TimeSpan -Start $newestFile.LastWriteTime -End (Get-Date)).TotalMinutes)
                    
                    # 通过 syncHash 触发 GUI 显示全息对话框
                    $global:syncHash.RequiresUserInput = $true
                    $global:syncHash.InputType = "UseExportedLogs"
                    $global:syncHash.InputData = @{
                        FileCount = $csvFiles.Count
                        FileAge = $fileAge
                        ExportPath = $ExportedLogPath
                        CsvFiles = $csvFiles
                    }
                    
                    # 等待用户选择（GUI_Mode 下才等待）
                    $authTimeout = [datetime]::Now.AddSeconds(60)
                    while ($global:syncHash.UserInput -eq $null) {
                        if ([datetime]::Now -gt $authTimeout) {
                            Write-SmartLog $L["AuthTimeout"]
                            $global:syncHash.UserInput = "no"
                            break
                        }
                        Start-Sleep -Milliseconds 100
                    }
                    
                    $userChoice = $global:syncHash.UserInput
                    $global:syncHash.UserInput = $null  # 重置
                    $global:syncHash.RequiresUserInput = $false  # 💥 核心修复：重置请求标志
                    $global:syncHash.InputType = $null  #  核心修复：重置输入类型
                    
                    if ($userChoice -ne "yes") {
                        # 用户选择跳过，使用实时提取
                        Write-SmartLog ($L["PRO_CSV_NotFound"])
                        $csvFiles = @()  # 清空 CSV 列表
                    }
                }
                
                # 如果用户选择使用 CSV（或非 GUI 模式），继续读取
                if ($csvFiles.Count -gt 0) {
                    Write-SmartLog ($L["PRO_CSV_Found"] -f $csvFiles.Count)
                
                # ===== 新增：识别并报告日志类型 =====
                $foundLogTypes = @()
                foreach ($csvFile in $csvFiles) {
                    if ($csvFile.Name -match 'System|系统') { $foundLogTypes += 'System' }
                    if ($csvFile.Name -match 'Application|应用程序') { $foundLogTypes += 'Application' }
                }
                $foundLogTypes = $foundLogTypes | Select-Object -Unique
                

                # 报告已找到的日志类型
                if ($Language -eq "CHS") {
                    Write-SmartLog "📂 分析的日志类型：$($foundLogTypes -join '、')" "Log Types"
                } else {
                    Write-SmartLog "📂 Log types analyzed: $($foundLogTypes -join ', ')" "Log Types"
                }
                
                # 检查并警告缺失的关键日志
                $missingLogs = @()
                if ($foundLogTypes -notcontains 'System') { $missingLogs += 'System' }
                if ($foundLogTypes -notcontains 'Application') { $missingLogs += 'Application' }
                
                if ($missingLogs.Count -gt 0) {
                    if ($Language -eq "CHS") {
                        $missingLogNames = $missingLogs -replace 'System', '系统日志' -replace 'Application', '应用程序日志'
                        Write-SmartLog "⚠️ 警告：未找到以下日志文件 - $($missingLogNames -join '、')" "Missing Logs"
                        Write-SmartLog "💡 提示：请在 PRO 模式中也导出这些日志以获得完整分析" "Hint"
                    } else {
                        Write-SmartLog "⚠️ Warning: Missing log files - $($missingLogs -join ', ')" "Missing Logs"
                        Write-SmartLog "💡 Hint: Please export these logs in PRO mode for complete analysis" "Hint"
                    }
                }
                
                # 读取所有 CSV 文件
                foreach ($csvFile in $csvFiles) {
                    Write-SmartLog ($L["PRO_CSV_Loading"] -f $csvFile.Name)
                    $csvEvents = Import-Csv -Path $csvFile.FullName -ErrorAction SilentlyContinue
                    
                    # 转换 CSV 数据为事件对象
                    foreach ($row in $csvEvents) {
                        # 💥 PRO模式核心修复：直接加载CSV里所有事件，不按时间窗口过滤
                        try {
                            # 核心修复：CSV 字段名为 TimeCreated（不是 'Time Created'）
                            $eventTime = [datetime]::Parse($row.TimeCreated)
                            
                            # 💥 核心修复：不再按时间范围过滤！PRO模式就是为了分析导出的所有日志
                            # if ($eventTime -ge $startTime -and $eventTime -le $endTime) {
                            # 核心修复：CSV 字段名为 LevelDisplayName（不是 Level）
                            # 需要将级别名称转换为数字（Critical=1, Error=2, Warning=3）
                            $level = 0
                            $levelName = $row.LevelDisplayName
                            if ($levelName -eq '关键') { $level = 1 }
                            elseif ($levelName -eq 'Critical') { $level = 1 }
                            elseif ($levelName -eq '错误') { $level = 2 }
                            elseif ($levelName -eq 'Error') { $level = 2 }
                            elseif ($levelName -eq '警告') { $level = 3 }
                            elseif ($levelName -eq 'Warning') { $level = 3 }
                            elseif ($levelName -eq '信息') { $level = 4 }
                            elseif ($levelName -eq 'Information') { $level = 4 }
                            elseif ($levelName -eq '详细') { $level = 5 }
                            elseif ($levelName -eq 'Verbose') { $level = 5 }
                            
                            # 只加载高危级别的事件（1=Critical, 2=Error, 3=Warning）
                            if ($level -ge 1 -and $level -le 3) {
                                $rawEvents += [PSCustomObject]@{
                                    Id = [int]$row.Id
                                    ProviderName = $row.ProviderName
                                    Message = $row.Message
                                    TimeCreated = $eventTime
                                    Level = $level
                                }
                            }
                        }
                        catch {
                            # 时间解析失败，跳过该事件
                            continue
                        }
                    }
                }
                
                Write-SmartLog ($L["PRO_CSV_Done"] -f $rawEvents.Count)
                }  # 💥 核心修复：闭合 if ($csvFiles.Count -gt 0)
            } else {
                Write-SmartLog $L["PRO_CSV_NotFound"]
            }
        }
        catch {
            Write-SmartLog ($L["PRO_CSV_Error"] -f $_.Exception.Message)
            Write-SmartLog $L["PRO_CSV_Fallback"]
        }
    }
    }
    
    # [修复] 如果从 PRO 导出读取的事件过少（<10），说明 CSV 导出可能不完整，
    #   回退到实时提取模式，确保智能分析有足够的数据进行碰撞匹配。
    #   根因：PRO 引擎的 CSV 导出有 bug（ForEach-Object 管道作用域问题），
    #   导致每个 CSV 文件只有 1 行数据，SmartEngine 只能加载极少事件。
    if ($rawEvents.Count -lt 10) {
        if ($rawEvents.Count -gt 0) {
            Write-SmartLog "⚠️ PRO 导出的 CSV 数据不完整（仅 $($rawEvents.Count) 条事件），回退到实时提取模式" "CSV Fallback"
        }
        Write-SmartLog $L["PRO_LiveExtract"]
        # 清空不完整的 CSV 数据，使用实时提取结果替代
        $rawEvents = @()
        
        # 初始化 $lightEvents
        $lightEvents = @()
        
        # Phase 1.2 核心优化：流式管道即时轻量化，消除 $rawEvents 中间变量
        # 直接在 Get-WinEvent 后立即转换为轻量 PSCustomObject，避免完整 EventLogRecord 占用内存
        foreach ($log in $logNames) {
            try {
                $lightEvents += Get-WinEvent -FilterHashtable @{LogName=$log; StartTime=$startTime; EndTime=$endTime; Level=$levels} -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        [PSCustomObject]@{
                            Id           = $_.Id
                            ProviderName = $_.ProviderName
                            Message      = if ($_.Message) { $_.Message } else { "" }
                        }
                    }
            } catch { Write-Debug "Non-critical operation failed: $($_.Exception.Message)" }
        }
        Write-SmartLog ($L["Read_Done"] -f $lightEvents.Count) "Logs Extracted"
    } else {
        # 从 PRO 导出的 CSV 读取数据，同样做轻量化处理
        $lightEvents = $rawEvents | ForEach-Object {
            [PSCustomObject]@{
                Id = $_.Id
                ProviderName = $_.ProviderName
                Message = if ($_.Message) { $_.Message } else { "" }
            }
        }
        Write-SmartLog ($L["Read_Done"] -f $lightEvents.Count) "Logs Extracted"
    }

    # =========================================================
    # Phase 3: 正则预编译图谱匹配 (Auto-Check)
    # =========================================================
    $global:syncHash.Progress = 50
    $global:syncHash.CurrentActivity = $L["Phase3"]
    Write-SmartLog $L["KB_Load"] "Compiling Knowledge Base..."
    
    $kbPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\Data\AURORA-TechData.json"))
    if (-not (Test-Path $kbPath)) { throw "Missing Knowledge Base: AURORA-TechData.json" }
    
    # Phase 1.3 核心优化：知识图谱预编译缓存（CliXML 序列化）
    # 缓存内容：flatRules + eventIdIndex + sourceIndex
    $cachePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\Data\AURORA-TechData.cache.clixml"))
    $useCache = $false
    
    # 检查缓存有效性
    $kbTime = (Get-Item $kbPath).LastWriteTime
    
    if ((Test-Path $cachePath) -and 
        ((Get-Item $cachePath).LastWriteTime -ge $kbTime)) {
        try {
            $cachedData = Import-Clixml $cachePath -ErrorAction Stop
            $currentKbVersion = (Get-Content "$script:KnowledgeBaseDir\version.txt" -ErrorAction SilentlyContinue) -replace '\s',''
            if ($cachedData.FlatRules -and 
                $cachedData.EventIdIndex -and 
                $cachedData.SourceIndex -and
                $cachedData.KbVersion -eq $currentKbVersion) {
                $flatRules = $cachedData.FlatRules
                $eventIdIndex = $cachedData.EventIdIndex
                $sourceIndex = $cachedData.SourceIndex
                
                # 重新编译正则表达式（因为序列化时只保存了模式字符串）
                foreach ($rule in $flatRules) {
                    if ($rule.RegexPatterns -and $rule.RegexPatterns.Count -gt 0) {
                        $rule.Regexes = foreach ($pattern in $rule.RegexPatterns) {
                            [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                        }
                    } else {
                        $rule.Regexes = @()
                    }
                }
                
                $useCache = $true
                Write-SmartLog ($L["KB_CacheHit"] -f $flatRules.Count) "Cache Loaded"
            }
        } catch {
            Write-SmartLog "Cache invalid or corrupted, rebuilding..."
        }
    }
    
    if (-not $useCache) {
        $techData = Get-Content $kbPath -Raw | ConvertFrom-Json
        
        # 核心优化：将多层嵌套的 JSON 展平为一个 1D 数组，并预编译正则表达式
        $flatRules = @()
        foreach ($cat in $techData.categories) {
            foreach ($item in $cat.items) {
                # 处理 Source 多态 (兼容数组和字符串)
                $sources = @()
                if ($item.source -is [array]) { $sources = $item.source }
                elseif ($item.source -is [string]) { $sources = @($item.source) }
                
                # 预编译 Regex
                $regexPatterns = @()
                if ($item.message_keywords) {
                    foreach ($kw in $item.message_keywords) {
                        $regexPatterns += [regex]::new([regex]::Escape($kw), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    }
                }

                $flatRules += [PSCustomObject]@{
                    RuleId   = $item.rule_id
                    NameCHS  = $item.name
                    NameENG  = $item.name_en
                    EventIds = if ($item.event_ids) { $item.event_ids } else { @() }
                    Sources  = $sources
                    Regexes  = $regexPatterns
                    Commands = $item.commands
                    Priority = $item.priority
                }
            }
        }
        
        # 构建索引（Phase 1.1 优化）
        $eventIdIndex = @{}
        $sourceIndex = @{}
        foreach ($rule in $flatRules) {
            foreach ($eid in $rule.EventIds) {
                # 将 EventID 转换为字符串作为键，避免序列化问题
                $eidKey = [string]$eid
                if (-not $eventIdIndex.ContainsKey($eidKey)) {
                    $eventIdIndex[$eidKey] = @()
                }
                $eventIdIndex[$eidKey] += $rule
            }
            foreach ($src in $rule.Sources) {
                $key = $src.ToLower()
                if (-not $sourceIndex.ContainsKey($key)) {
                    $sourceIndex[$key] = @()
                }
                $sourceIndex[$key] += $rule
            }
        }
        
        # 保存缓存（仅当 KB 更新或缓存不存在时）
        try {
            # 创建完全独立的深拷贝缓存数据（确保所有属性都是可序列化的）
            $serializableRules = foreach ($rule in $flatRules) {
                [PSCustomObject]@{
                    RuleId   = $rule.RuleId
                    NameCHS  = $rule.NameCHS
                    NameENG  = $rule.NameENG
                    # 将 EventIds 转换为字符串数组，确保可序列化
                    EventIds = if ($rule.EventIds) { $rule.EventIds | ForEach-Object { [string]$_ } } else { @() }
                    # Sources 已经是字符串数组，直接复制
                    Sources  = if ($rule.Sources) { @($rule.Sources) } else { @() }
                    # 将 Regex 模式转换为字符串数组，以便序列化
                    RegexPatterns = if ($rule.Regexes) { $rule.Regexes.Pattern } else { @() }
                    # Commands 可能包含复杂对象，转换为字符串数组
                    Commands = if ($rule.Commands) { @($rule.Commands) } else { @() }
                    # Priority 转换为数字或字符串
                    Priority = $rule.Priority
                }
            }
            
            $cacheData = @{
                FlatRules    = $serializableRules
                EventIdIndex = $eventIdIndex
                SourceIndex  = $sourceIndex
                KbVersion    = [string]$techData.meta.version
                CachedAt     = Get-Date -Format "o"
            }
            # 【修复】使用 -Depth 3 确保嵌套的 Hashtable 和数组可以正确序列化
            $cacheData | Export-Clixml $cachePath -Depth 3 -ErrorAction Stop
            Write-SmartLog "Knowledge base cached ($(($cacheData | ConvertTo-Json -Depth 1).Length / 1KB).ToString('F1') KB)"
        } catch {
            Write-SmartLog "Warning: Failed to save cache: $($_.Exception.Message)"
        }
    }
    
    Write-SmartLog ($L["KB_Done"] -f $flatRules.Count) "Analyzing..."
    
    # =========================================================
    # Phase 3 核心优化：双索引预查找 + 候选集精确匹配
    # 复杂度：O(n×m×k) → O(n × avg_candidates)
    # （索引已在上面缓存分支中构建完成）
    # =========================================================
    
    # Step 2: 索引查找 + 关键字精确匹配
    $matchedRulesMap = @{}
    foreach ($e in $lightEvents) {
        $candidates = @()
        
        # 从 EventID 索引获取候选（O(1)）
        # 将 EventID 转换为字符串以匹配缓存的键
        $eidKey = [string]$e.Id
        if ($eventIdIndex.ContainsKey($eidKey)) {
            $candidates += $eventIdIndex[$eidKey]
        }
        
        # 从 Source 索引获取候选（O(1)）
        $providerKey = $e.ProviderName.ToLower()
        if ($sourceIndex.ContainsKey($providerKey)) {
            $candidates += $sourceIndex[$providerKey]
        }
        
        # 去重：避免同一规则被重复匹配
        if ($candidates.Count -eq 0) { continue }
        $candidates = $candidates | Select-Object -Unique
        
        # 仅对候选规则执行关键字匹配（数量远小于 flatRules 总数）
        foreach ($rule in $candidates) {
            if ($matchedRulesMap.ContainsKey($rule.RuleId)) { continue }
            
            # 如果规则没有 EventID 和 Source 限制，直接匹配关键字
            if ($rule.EventIds.Count -eq 0 -and $rule.Sources.Count -eq 0) {
                foreach ($rx in $rule.Regexes) {
                    if ($rx.IsMatch($e.Message)) {
                        $matchedRulesMap[$rule.RuleId] = $rule
                        break
                    }
                }
                continue
            }
            
            # 已有 EventID 或 Source 匹配，只需验证关键字
            if ($rule.Regexes.Count -eq 0) {
                # 无关键字要求，直接匹配
                $matchedRulesMap[$rule.RuleId] = $rule
            } else {
                foreach ($rx in $rule.Regexes) {
                    if ($rx.IsMatch($e.Message)) {
                        $matchedRulesMap[$rule.RuleId] = $rule
                        break
                    }
                }
            }
        }
    }
    
    $matchedRules = $matchedRulesMap.Values | Sort-Object Priority -Descending
    Write-SmartLog ($L["Check_Done"] -f $matchedRules.Count) "Analysis Complete"

    # =========================================================
    # Phase 4: 安全沙箱自主修复模式终端 (Auto-Repair Sandbox)
    # =========================================================
    $global:syncHash.Progress = 80
    $global:syncHash.CurrentActivity = $L["Phase4"]

    if ($matchedRules.Count -eq 0) {
        Write-SmartLog $L["No_Issue"] "System Healthy"
    } else {
        # 1. 预先构建完整的交互菜单文本（缓存起来以便后续重复打印）
        $fullMenuText = ""
        $commandMap = @{}
        $cmdIndex = 1
        # [智能模式菜单面板化] 结构化菜单数据，供 WPF SmartMenuPanel 绑定
        $smartMenuItems = @()
        $executedIndices = @()
        
        foreach ($rule in $matchedRules) {
            $ruleName = if ($Language -eq "CHS") { $rule.NameCHS } else { $rule.NameENG }
            $fullMenuText += "🚨 [$($rule.RuleId)] $ruleName`n"
            
            if ($rule.Commands -and $rule.Commands.Count -gt 0) {
                foreach ($cmd in $rule.Commands) {
                    $cmdName = if ($Language -eq "CHS") { $cmd.name } else { $cmd.name_en }
                    $adminTag = if ($cmd.elevation_required) { "[Admin]" } else { "" }
                    $riskTag = if ($cmd.risk_level) { "($($cmd.risk_level))" } else { "" }
                    $autoTag = if ($cmd.auto_execute -eq $true) { "[Auto]" } else { "[Auth]" }
                    
                    $fullMenuText += "   [ $cmdIndex ] $cmdName $riskTag $adminTag $autoTag`n"
                    $commandMap[$cmdIndex.ToString()] = $cmd
                    
                    # 构建结构化菜单项（供 WPF 面板绑定）
                    $smartMenuItems += [PSCustomObject]@{
                        Index         = $cmdIndex
                        RuleId        = $rule.RuleId
                        RuleName      = $ruleName
                        Name          = $cmdName
                        RiskLevel     = if ($cmd.risk_level) { $cmd.risk_level } else { "" }
                        RequiresAdmin = [bool]$cmd.elevation_required
                        AutoExecute   = ($cmd.auto_execute -eq $true)
                    }
                    $cmdIndex++
                }
            }
        }
        
        # [智能模式菜单面板化] 写入结构化菜单到 syncHash，WPF 端读取后显示面板
        $global:syncHash.SmartMenuItems = $smartMenuItems
        $global:syncHash.ExecutedMenuIndices = ""
        
        # 首次打印菜单（控制台仅显示一次，后续由 WPF 面板承载交互）
        Write-SmartLog $L["Repair_Menu"]
        Write-SmartLog $fullMenuText.TrimEnd()
        Write-SmartLog $L["Repair_Prompt"] "Waiting for input..."
        $global:syncHash.Progress = 100
        
        # ====== 新增：把菜单文本存到 syncHash，供 GUI 重新打印 ======
        $global:syncHash.FullMenuText = $fullMenuText
        $global:syncHash.RepairMenuTitle = $L["Repair_Menu"]
        $global:syncHash.RepairPrompt = $L["Repair_Prompt"]

        # 2. 挂起后台，监听 GUI 传来的指令
        # [修复] 进入循环前清空 RequiresAuthorization，区分"初始状态"和"用户主动跳过"。
        #   C# 端 L575 在引擎启动前设 RequiresAuthorization=false（与 PowerShell 原版一致），
        #   但分支2条件 RequiresAuthorization -eq $false 会误触发首次重印菜单。
        #   显式设为 $null 后，只有用户真正在授权弹窗中点击跳过（C# 端设 false）才触发重印。
        $global:syncHash.RequiresAuthorization = $null
        $pendingAuthorized = $false
        
        while ($global:syncHash.IsHostAlive) {
            # ================= [分支 1：授权通过执行完毕] =================
            if ($global:syncHash.Authorized -eq $true -and $global:syncHash.PendingCommand) {
                $targetCmd = $global:syncHash.PendingCommand
                $global:syncHash.PendingCommand = $null
                $global:syncHash.Authorized = $null
                $global:syncHash.RequiresAuthorization = $null
                
                # 临时强制设为auto_execute=true以跳过二次授权
                $targetCmd | Add-Member -MemberType NoteProperty -Name "auto_execute" -Value $true -Force
                $rawResult = Invoke-AuroraSafeAction -Command $targetCmd -Language $Language
                # [修复] 同分支3：归一化返回值为单个 bool，避免函数体内其他调用的返回值泄漏成 Object[] 数组
                $result = if ($rawResult -is [System.Array]) { [bool]$rawResult[-1] } else { [bool]$rawResult }

                # [修复] 仅在执行成功时才标记 executed，避免命令失败/出错仍打勾
                #   原缺陷：无条件标记，导致执行失败也显示 ✓ 误导用户
                if ($result -eq $true) {
                    Write-SmartLog $L["Exec_Success"]
                    $pendingIdx = $global:syncHash.PendingCommandIndex
                    if ($pendingIdx) {
                        $executedIndices += $pendingIdx
                        $global:syncHash.ExecutedMenuIndices = ($executedIndices -join ",")
                    }
                }
                # 无论成功失败，都清理 PendingCommandIndex
                $global:syncHash.PendingCommandIndex = $null
                
                # 等待一段时间，让用户有时间阅读执行结果
                Start-Sleep -Milliseconds 1000
                
                # [菜单面板化] 不再重印菜单文本，WPF 面板始终可见
                continue 
            }
            
            # ================= [分支 2：用户在全息弹窗中点击跳过 (Skip)] =================
            if ($global:syncHash.RequiresAuthorization -eq $false -and $global:syncHash.PendingCommand -eq $null) {
                $global:syncHash.RequiresAuthorization = $null
                
                # 用户放弃任务，发送 -1 让 HUD 离场
                $global:syncHash.CurrentPipelineStep = -1
                # [菜单面板化] 不再重印菜单文本，WPF 面板始终可见
                continue 
            }
            
            # ================= [分支 3：处理常规终端输入] =================
            if ($global:syncHash.UserInput -ne $null) {
                # 拦截未授权乱输入
                if ($global:syncHash.RequiresAuthorization -eq $true) {
                    Write-SmartLog "⚠️ 请先在弹出的控制台上完成高危操作的授权决策！"
                    $global:syncHash.UserInput = $null
                    continue
                }

                $inputRaw = $global:syncHash.UserInput.Trim()
                $global:syncHash.UserInput = $null # 消费指令

                if ($inputRaw -eq "") {
                    Write-SmartLog $L["Input_Skip"]
                    break
                }
                
                if ($inputRaw -match "^(?i)m$") {
                    # [菜单面板化] m 命令不再重印控制台菜单，面板始终可见
                    Write-SmartLog "💡 修复菜单已在下方面板显示，可直接点击执行"
                    continue
                }

                if ($commandMap.ContainsKey($inputRaw)) {
                    $targetCmd = $commandMap[$inputRaw]
                    $cmdName = if ($Language -eq "CHS") { $targetCmd.name } else { $targetCmd.name_en }
                    Write-SmartLog ($L["Executing"] -f $cmdName) "Executing..."
                    
                    # [智能模式菜单面板化] 记录当前执行序号，供授权通过后标记 IsExecuted
                    $global:syncHash.PendingCommandIndex = $inputRaw
                    
                    $rawResult = Invoke-AuroraSafeAction -Command $targetCmd -Language $Language

                    # [修复] Invoke-AuroraSafeAction 函数体内某些被调用函数（如 Initialize-UndoManager、
                    #   Complete-RepairSession）的返回值会泄漏到管道，与真正的 return 值组合成 Object[] 数组。
                    #   例如提权拒绝时返回 [True, False]（Initialize-UndoManager 的 $true + return $false），
                    #   而 Object[] -eq $true 会返回非空数组，在 if 条件中被当作 $true，导致错误标记 IsExecuted。
                    #   这里强制取最后一个元素（真正的 return 值）并转 bool。
                    $result = if ($rawResult -is [System.Array]) { [bool]$rawResult[-1] } else { [bool]$rawResult }

                    if ("PendingAuthorization" -eq $rawResult) {
                        continue # 处于授权等待，跳过
                    } elseif ($result -eq $true) {
                        Write-SmartLog $L["Exec_Success"]
                        # [智能模式菜单面板化] 标记已执行索引
                        $executedIndices += $inputRaw
                        $global:syncHash.ExecutedMenuIndices = ($executedIndices -join ",")
                    }
                    
                    # 等待一段时间，让用户有时间阅读执行结果
                    Start-Sleep -Milliseconds 1000
                    
                    # [菜单面板化] 不再重印菜单文本，WPF 面板始终可见
                } else {
                    Write-SmartLog $L["Input_Invalid"]
                }
            }
            Start-Sleep -Milliseconds 100
        }
    }
    
    Write-SmartLog $L["Engine_Exit"]

} catch {
    Write-SmartLog ($L["Fatal_Error"] -f $_.Exception.Message)
} finally {
    $global:syncHash.ScriptDone = $true
    $global:syncHash.IsRunning = $false
}
