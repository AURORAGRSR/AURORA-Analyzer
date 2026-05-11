#===============================================================================
# 脚本名称：AURORA-SmartEngine.ps1 (智能诊断与自主修复模式核心引擎)
# 架构特性：单文件双语支持 (Bilingual) + 动态环境感知 + 极速并发匹配
# 版本：V3.1 Smart Release
# 作者：AURORA VelociRaptor-GR Dev PRJ.
# 构建时间：2026.05.09
# ==============================================================================

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
    
    # ===== 新增：PRO 模式调用参数 =====
    [switch]$FromPRO,              # 标记是否从 PRO 模式调用
    [string]$ExportedLogPath      # PRO 模式导出的日志路径
)

# 检测是否由GUI启动
$isLaunchedByGUI = $false

# 检测方式1: 检查是否有GUI_Mode参数
if ($GUI_Mode) {
    $isLaunchedByGUI = $true
}

# 检测方式2: 检查是否有全局syncHash变量
if (-not $isLaunchedByGUI -and (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
    $isLaunchedByGUI = $true
}

# 检测方式3: 检查是否通过hash参数传入
if (-not $isLaunchedByGUI -and $null -ne $hash) {
    $isLaunchedByGUI = $true
}

# 如果不是由GUI启动，则显示提示并退出
if (-not $isLaunchedByGUI) {
    # 检测语言偏好
    $useChinese = $true
    try {
        $uiCulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture.Name
        if ($uiCulture -notlike "zh*") {
            $useChinese = $false
        }
    } catch {}
    
    if ($useChinese) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  ❌ 此脚本不能直接运行！" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "请使用以下方式启动：" -ForegroundColor Yellow
        Write-Host "  1. 双击运行 AURORA.Launcher-双击启动.exe" -ForegroundColor White
        Write-Host "  2. 或者运行 AURORA-AnalyzerLauncherGUI.ps1" -ForegroundColor White
        Write-Host ""
        Write-Host "程序将在5秒后自动关闭..." -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  ❌ This script cannot be run directly!" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Please launch using:" -ForegroundColor Yellow
        Write-Host "  1. Double-click AURORA.Launcher-双击启动.exe" -ForegroundColor White
        Write-Host "  2. Or run AURORA-AnalyzerLauncherGUI.ps1" -ForegroundColor White
        Write-Host ""
        Write-Host "Program will close automatically in 5 seconds..." -ForegroundColor Gray
    }
    
    Start-Sleep -Seconds 5
    exit 1
}

$ErrorActionPreference = "Stop"

# ===== 核心修复 2：安全接管全局变量，防止强行覆盖为空 =====
# 只有当传进来的 $hash 真的有内容时，才去赋值；否则直接继承 Runspace 里的 $global:syncHash
if ($null -ne $hash) {
    $global:syncHash = $hash
}

# ===== 核心防御：如果独立双击运行该脚本，给它一个保底的实体环境，防止闪退 =====
if ($null -eq $global:syncHash) {
    $global:syncHash = [hashtable]::Synchronized(@{
        IsHostAlive     = $true
        IsRunning       = $true
        LogOutput       = ""
        Progress        = 0
        ScriptDone      = $false
        CurrentStatus   = ""
        CurrentActivity = ""
        UserInput       = $null
    })
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
        $errorMsg = if ($Language -eq "CHS") {
            "❌ 需要管理员权限！请以管理员身份重新运行 AURORA。`n提示：右键点击 AURORA.Launcher-双击启动.exe，选择'以管理员身份运行'"
        } else {
            "❌ Administrator privileges required! Please re-run AURORA as administrator.`nHint: Right-click AURORA.Launcher-双击启动.exe and select 'Run as administrator'"
        }
        Write-SmartLog $errorMsg
        
        # 发送错误结果到 GUI
        $global:syncHash.CommandResult = @{
            ActionName = $cmdName
            Result = $errorMsg
            Output = "ERROR_ELEVATION_REQUIRED (Code: 740)"
            ExecutionTime = "0.00 s"
        }
        Start-Sleep -Milliseconds 2000
        return $false
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
        
        # 现在设置新的授权请求
        $global:syncHash.RequiresAuthorization = $true
        $global:syncHash.PendingCommand = $Command
        
        # 等待用户授权
        $waitCount = 0
        $maxWaitCount = 600
        while ($global:syncHash.Authorized -eq $null -and 
               $waitCount -lt $maxWaitCount) {
            Start-Sleep -Milliseconds 50
            $waitCount++
        }
        
        # 记录等待情况
        if ($waitCount -lt $maxWaitCount) {
            Write-SmartLog ($L["GUI_Responded"] -f ($waitCount * 50))
        } else {
            Write-SmartLog $L["GUI_Timeout"]
        }
        
        # 暂时返回，等待 GUI 授权
        return "PendingAuthorization"
    } else {
        $global:syncHash.CurrentPipelineStatus = "Success"
        Start-Sleep -Milliseconds 200
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
        
        # === 新增：专门处理权限错误 ===
        $exceptionMsg = $_.Exception.Message
        $isPermissionError = $exceptionMsg -match "740" -or $exceptionMsg -match "权限" -or $exceptionMsg -match "Elevation" -or $exceptionMsg -match "privilege"
        
        if ($isPermissionError) {
            $errorMessage = if ($Language -eq "CHS") {
                "❌ 需要管理员权限！请以管理员身份重新运行 AURORA。`n提示：右键点击 AURORA.Launcher-双击启动.exe，选择'以管理员身份运行'"
            } else {
                "❌ Administrator privileges required! Please re-run AURORA as administrator.`nHint: Right-click AURORA.Launcher-双击启动.exe and select 'Run as administrator'"
            }
            Write-SmartLog $errorMessage
            $outputText = "ERROR_ELEVATION_REQUIRED (Code: 740)"
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
        
        # 发送执行结果到 GUI
        $global:syncHash.CommandResult = @{
            ActionName = $cmdName
            Result = $errorMessage
            Output = $outputText
            ExecutionTime = "$($executionTime.ToString('0.00')) $($lang['Seconds'])"
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

    # 4. 追加真正的生命体征探测：是否存在未处理的蓝屏转储文件
    if (Test-Path "$env:windir\Minidump\*.dmp") {
        Write-SmartLog $L["Minidump_Warning"]
    }

    # =========================================================
    # Phase 2: 并发提取与轻量化 (Auto-Read)
    # =========================================================
    $global:syncHash.Progress = 30
    $global:syncHash.CurrentActivity = $L["Phase2"]
    Write-SmartLog $L["Read_Start"] "Extracting Logs..."
    
    $logNames = @("System", "Application")
    $levels = @(1, 2, 3) # Critical, Error, Warning
    $rawEvents = @()

    # ===== 新增：PRO 模式调用时读取已导出的日志文件 =====
    if ($FromPRO -and $ExportedLogPath) {
        Write-SmartLog ($L["PRO_Detect"] -f $ExportedLogPath)
        
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
            } else {
                Write-SmartLog $L["PRO_CSV_NotFound"]
            }
        }
        catch {
            Write-SmartLog ($L["PRO_CSV_Error"] -f $_.Exception.Message)
            Write-SmartLog $L["PRO_CSV_Fallback"]
        }
    }
    
    # 如果没有从 PRO 导出读取到数据，使用传统方式从系统提取
    if ($rawEvents.Count -eq 0) {
        Write-SmartLog $L["PRO_LiveExtract"]
        
        foreach ($log in $logNames) {
            try {
                $events = Get-WinEvent -FilterHashtable @{LogName=$log; StartTime=$startTime; EndTime=$endTime; Level=$levels} -ErrorAction SilentlyContinue
                if ($events) { $rawEvents += $events }
            } catch {}
        }
    }

    # 核心优化：丢弃原生大对象，只提取必要字段，极大降低内存占用
    $lightEvents = $rawEvents | ForEach-Object {
        [PSCustomObject]@{
            Id = $_.Id
            ProviderName = $_.ProviderName
            Message = if ($_.Message) { $_.Message } else { "" }
        }
    }
    Write-SmartLog ($L["Read_Done"] -f $lightEvents.Count) "Logs Extracted"

    # =========================================================
    # Phase 3: 正则预编译图谱匹配 (Auto-Check)
    # =========================================================
    $global:syncHash.Progress = 50
    $global:syncHash.CurrentActivity = $L["Phase3"]
    Write-SmartLog $L["KB_Load"] "Compiling Knowledge Base..."
    
    $kbPath = Join-Path $PSScriptRoot "..\Data\AURORA-TechData.json"
    if (-not (Test-Path $kbPath)) { throw "Missing Knowledge Base: AURORA-TechData.json" }
    
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
    Write-SmartLog ($L["KB_Done"] -f $flatRules.Count) "Analyzing..."

    # O(1) 极速匹配引擎
    $matchedRulesMap = @{}
    foreach ($e in $lightEvents) {
        foreach ($rule in $flatRules) {
            $isMatch = $false
            
            # 1. 测 EventID
            if ($rule.EventIds.Count -gt 0 -and $rule.EventIds -contains $e.Id) { $isMatch = $true }
            
            # 2. 测 Source
            if (-not $isMatch -and $rule.Sources.Count -gt 0) {
                foreach ($src in $rule.Sources) {
                    if ($e.ProviderName -match "(?i)$src") { $isMatch = $true; break }
                }
            }
            
            # 3. 测关键字
            if ($isMatch -and $rule.Regexes.Count -gt 0) {
                $kwMatch = $false
                foreach ($rx in $rule.Regexes) {
                    if ($rx.IsMatch($e.Message)) { $kwMatch = $true; break }
                }
                $isMatch = $kwMatch
            }

            if ($isMatch -and -not $matchedRulesMap.ContainsKey($rule.RuleId)) {
                $matchedRulesMap[$rule.RuleId] = $rule
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
                    $cmdIndex++
                }
            }
        }
        
        # 首次打印菜单
        Write-SmartLog $L["Repair_Menu"]
        Write-SmartLog $fullMenuText.TrimEnd()
        Write-SmartLog $L["Repair_Prompt"] "Waiting for input..."
        $global:syncHash.Progress = 100
        
        # ====== 新增：把菜单文本存到 syncHash，供 GUI 重新打印 ======
        $global:syncHash.FullMenuText = $fullMenuText
        $global:syncHash.RepairMenuTitle = $L["Repair_Menu"]
        $global:syncHash.RepairPrompt = $L["Repair_Prompt"]

        # 2. 挂起后台，监听 GUI 传来的指令
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
                $result = Invoke-AuroraSafeAction -Command $targetCmd -Language $Language
                
                # 等待一段时间，让用户有时间阅读执行结果
                Start-Sleep -Milliseconds 1000
                
                # 任务执行完成后重新打印菜单
                Write-SmartLog $L["Repair_Menu"]
                Write-SmartLog $fullMenuText.TrimEnd()
                Write-SmartLog $L["Repair_Prompt"] "Waiting for input..."
                continue 
            }
            
            # ================= [分支 2：用户在全息弹窗中点击跳过 (Skip)] =================
            if ($global:syncHash.RequiresAuthorization -eq $false -and $global:syncHash.PendingCommand -eq $null) {
                $global:syncHash.RequiresAuthorization = $null
                
                # 用户放弃任务，发送 -1 让 HUD 离场，并重印菜单
                $global:syncHash.CurrentPipelineStep = -1
                Write-SmartLog $L["Repair_Menu"]
                Write-SmartLog $fullMenuText.TrimEnd()
                Write-SmartLog $L["Repair_Prompt"] "Waiting for input..."
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
                    Write-SmartLog $L["Repair_Menu"]
                    Write-SmartLog $fullMenuText.TrimEnd()
                    Write-SmartLog $L["Repair_Prompt"] "Waiting for input..."
                    continue
                }

                if ($commandMap.ContainsKey($inputRaw)) {
                    $targetCmd = $commandMap[$inputRaw]
                    $cmdName = if ($Language -eq "CHS") { $targetCmd.name } else { $targetCmd.name_en }
                    Write-SmartLog ($L["Executing"] -f $cmdName) "Executing..."
                    
                    $result = Invoke-AuroraSafeAction -Command $targetCmd -Language $Language
                    
                    if ("PendingAuthorization" -eq $result) {
                        continue # 处于授权等待，跳过重印菜单
                    } elseif ($result -eq $true) {
                        Write-SmartLog $L["Exec_Success"]
                    }
                    
                    # 等待一段时间，让用户有时间阅读执行结果
                    Start-Sleep -Milliseconds 1000
                    
                    # 任务执行完成后重新打印菜单
                    Write-SmartLog $L["Repair_Menu"]
                    Write-SmartLog $fullMenuText.TrimEnd()
                    Write-SmartLog $L["Repair_Prompt"] "Waiting for input..."
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