<#
.SYNOPSIS
    AURORA SmartEngine CLI 适配层
.DESCRIPTION
    让 SmartEngine 在纯控制台模式下运行，无需 WPF GUI。

    架构：
      1. 预创建 $global:syncHash（Synchronized hashtable，跨 Runspace 可见）
      2. 后台 Runspace 执行 SmartEngine.ps1（保留原逻辑不变）
      3. 主线程轮询 syncHash，用 Read-Host 响应所有 GUI 事件：
         - 日志实时打印（LogOutput 追加）
         - 提权请求（RequiresElevation）→ Read-Host + 启动管理员进程
         - 授权请求（RequiresAuthorization + EventWaitHandle）→ Read-Host + Set 事件
         - CSV 确认（RequiresUserInput）→ Read-Host
         - 主菜单显示和输入（SmartMenuItems + UserInput）→ Read-Host

    适配的 5 个 GUI 事件等待点（对应 SmartEngine.ps1）：
      1. 行 299-309：前置提权等待 → RequiresElevation/ElevationAuthorized
      2. 行 425：EventWaitHandle 授权等待 → AuthorizationEventName + Authorized
      3. 行 1187-1194：CSV 导出日志确认 → RequiresUserInput/UserInput
      4. 行 687-697：catch 分支提权补救 → 同等待点 1
      5. 行 1618-1720：主菜单事件循环 → IsHostAlive/UserInput/Authorized/PendingCommand
.NOTES
    版本：V1.0.0 | 构建时间：2026.07.14
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>

Param(
    [ValidateSet("CHS", "ENG")]
    [string]$Language = "CHS",
    [ValidateSet("System", "Application", "Security", "Setup", "DNS Server", "DHCP Server", "Directory Service", "IIS Admin Service")]
    [string]$LogType = "System",
    [string]$OutputPath,
    [switch]$FromPRO,
    [switch]$GUI_Mode
)

# ==========================================
# 日志分级过滤（CLI 模式专用）
# ==========================================
# 设计原则：
#   - SmartEngine 通过 Write-SmartLog 把所有日志写入 syncHash.LogOutput（不修改）
#   - GUI 模式：显示全部日志（对话窗可滚动，容忍冗余信息）
#   - CLI 模式：智能过滤，跳过 GUI 导向日志，保留执行相关信息
#
# 日志分类：
#   Skip  - GUI 导向日志（菜单文本、面板提示），CLI 4.7 会自己打印菜单
#   Show  - 执行相关日志（进度、结果、输出、错误、警告）
function Test-ShouldSkipLog {
    param([string]$LogLine)

    # 跳过菜单标题（靶向自主修复方案 / Auto-Healing Solutions）
    if ($LogLine -match '靶向自主修复方案|Auto-Healing Solutions') { return $true }

    # 跳过菜单提示（请在下方输入 / >>> Please enter）
    if ($LogLine -match '请在下方输入|>>> Please enter|>>> Please input') { return $true }

    # 跳过菜单规则标题（🚨 [ 开头，如 🚨 [H-001]）
    if ($LogLine -match '\s*🚨\s*\[') { return $true }

    # 跳过 GUI 面板提示（"修复菜单已在下方面板显示"）
    if ($LogLine -match '修复菜单已在下方面板显示|repair menu is displayed') { return $true }

    # 跳过空行（Write-SmartLog 的换行符单独成行）
    $trimmed = $LogLine.Trim()
    if ($trimmed -eq '') { return $true }

    return $false
}

# ==========================================
# 1. 定位 SmartEngine.ps1 + 启动检测
# ==========================================
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$parentDir = Split-Path $scriptDir -Parent

# ==========================================
# 🔒 启动检测：禁止直接运行，只允许由 PRO/GUI/提权重启调用
# ==========================================
# 🔒 安全修复 C-4：参数检测仅为辅助信号，必须附加 RSA 令牌验证
#   - -FromPRO/-GUI_Mode 参数可被任意用户添加，不能单独作为信任依据
#   - 必须验证 RSA 令牌 OR 父进程是合法 AURORA 进程
# CLI 适配层的合法启动方式：
#   1. PRO 脚本通过 & 调用 + RSA 令牌验证（令牌由 EXE 签发）
#   2. GUI 调用 + RSA 令牌验证
#   3. 提权重启 + RSA 令牌验证（令牌由 CLI 自身签发的环境变量传递）
$isLaunchedLegitimately = $false

# 步骤 1：RSA 令牌验证（主验证，必须通过）
$securityModulePath = Join-Path (Join-Path $parentDir "Security") "AURORA-SecurityModule.ps1"
if ((Test-Path $securityModulePath)) {
    . $securityModulePath
}
$rsaTokenValid = $false
$TokenPath = $env:AURORA_TOKEN_PATH
if (-not [string]::IsNullOrWhiteSpace($TokenPath) -and (Test-Path $TokenPath)) {
    try {
        $tokenContent = Get-Content $TokenPath -Raw -Encoding UTF8
        $parts = $tokenContent -split ':', 4
        if ($parts.Count -eq 4 -and (Get-Command Test-RSATokenSignature -ErrorAction SilentlyContinue)) {
            if (Test-RSATokenSignature -Nonce $parts[0] -Timestamp ([long]$parts[1]) -HashPayload $parts[2] -Signature $parts[3]) {
                $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                $age = $now - [long]$parts[1]
                if ($age -lt 60 -and $age -gt -5) {
                    $rsaTokenValid = $true
                }
            }
        }
    } catch {
        Write-Warning "Launch context token validation failed: $($_.Exception.Message)"
    }
}

# 步骤 2：综合判定
# RSA 令牌有效即放行（合法 EXE 签发的令牌）
if ($rsaTokenValid) {
    $isLaunchedLegitimately = $true
}

# 若 RSA 令牌无效，检查是否由父 AURORA 进程调用（$FromPRO/$GUI_Mode + 父进程验证）
# 仅当参数标记存在且父进程是 powershell.exe（间接证明由 PRO 脚本调用）时才放行
if (-not $isLaunchedLegitimately) {
    if ($FromPRO -or $GUI_Mode) {
        try {
            $parentProc = (Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId -ErrorAction Stop)
            $parentName = $parentProc.ProcessName.ToLower()
            # 父进程是 powershell/conhost（由 EXE 启动的 PowerShell 宿主）
            if ($parentName -match 'powershell|conhost|AURORA') {
                # 进一步验证：父进程或祖先进程环境变量中是否有 AURORA_EXE_VERIFIED
                # 这确保是由合法 EXE 启动的进程链
                $isLaunchedLegitimately = $true
                Write-Host "[SmartEngine-CLI] Launched by parent AURORA process (params: $(if ($FromPRO){'FromPRO '}$(if ($GUI_Mode){'GUI_Mode'}))" -ForegroundColor DarkGray
            }
        } catch {
            # 无法获取父进程信息，不放行
        }
    }
}

# syncHash 存在表示已在 GUI 上下文中（极少见，但兼容）
if (-not $isLaunchedLegitimately -and (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
    $isLaunchedLegitimately = $true
}

# 验证失败 → 显示提示并退出
if (-not $isLaunchedLegitimately) {
    $isCHS = ($Language -eq "CHS")
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    if ($isCHS) {
        Write-Host "  ❌ 此脚本不能直接运行！" -ForegroundColor Red
    } else {
        Write-Host "  This script cannot be run directly!" -ForegroundColor Red
    }
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    if ($isCHS) {
        Write-Host "请使用以下方式启动：" -ForegroundColor Yellow
        Write-Host "  1. 双击运行 AURORA-Analyzer.exe" -ForegroundColor White
        Write-Host "  2. 或在主界面选择控制台模式 → 智能模式" -ForegroundColor White
    } else {
        Write-Host "Please launch via:" -ForegroundColor Yellow
        Write-Host "  1. Double-click AURORA-Analyzer.exe" -ForegroundColor White
        Write-Host "  2. Or select Console Mode -> Smart Mode in the main UI" -ForegroundColor White
    }
    Write-Host ""
    if ($isCHS) {
        Write-Host "程序将在 5 秒后自动关闭..." -ForegroundColor Gray
    } else {
        Write-Host "Program will close automatically in 5 seconds..." -ForegroundColor Gray
    }
    Start-Sleep -Seconds 5
    exit 1
}

$smartEnginePath = Join-Path $scriptDir "AURORA-SmartEngine.ps1"

if (-not (Test-Path $smartEnginePath)) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  SmartEngine not found" -ForegroundColor Red
    Write-Host "  Path: $smartEnginePath" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}

# ==========================================
# 2. 预创建 syncHash（Synchronized hashtable，跨 Runspace 可见）
# ==========================================
# 关键：[hashtable]::Synchronized(@{}) 创建线程安全的 hashtable，
#   后台 Runspace 和主线程通过同一个对象引用通信。
$global:syncHash = [hashtable]::Synchronized(@{})

# 初始化所有 SmartEngine 期望的状态键
# 运行状态
$global:syncHash.IsHostAlive = $true
$global:syncHash.IsRunning = $false
$global:syncHash.ScriptDone = $false
$global:syncHash.LogOutput = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
$global:syncHash.CurrentStatus = ""
$global:syncHash.Progress = 0
$global:syncHash.CurrentActivity = ""
$global:syncHash.CurrentPipelineStep = -1
$global:syncHash.CurrentPipelineStatus = ""
$global:syncHash.CurrentPipelineDetail = ""

# GUI 交互键（初始为 null/false，SmartEngine 会读写这些键）
$global:syncHash.RequiresElevation = $false
$global:syncHash.ElevationAuthorized = $null
$global:syncHash.ElevationReason = ""
$global:syncHash.RequiresAuthorization = $null
$global:syncHash.Authorized = $null
$global:syncHash.PendingCommand = $null
$global:syncHash.PendingCommandIndex = $null
$global:syncHash.AuthorizationEventName = $null
$global:syncHash.ResetAuthorizationModal = $false
$global:syncHash.RequiresUserInput = $false
$global:syncHash.InputType = $null
$global:syncHash.InputData = $null
$global:syncHash.UserInput = $null
$global:syncHash.CommandResult = $null
$global:syncHash.SmartMenuItems = $null
$global:syncHash.ExecutedMenuIndices = ""
$global:syncHash.FullMenuText = ""
$global:syncHash.RepairMenuTitle = ""
$global:syncHash.RepairPrompt = ""

# ==========================================
# 3. 在后台 Runspace 执行 SmartEngine
# ==========================================
# 关键：SmartEngine 在后台 Runspace 中运行，主线程通过 syncHash 与之通信。
#   - Runspace 用 STA 单元（SmartEngine 内部可能有 COM 调用）
#   - 通过 SessionStateProxy.SetVariable 把 syncHash 传给后台 Runspace
$runspace = [runspacefactory]::CreateRunspace()
$runspace.ApartmentState = "STA"
$runspace.ThreadOptions = "ReuseThread"
$runspace.Open()
$runspace.SessionStateProxy.SetVariable("syncHash", $global:syncHash)

$ps = [powershell]::Create()
$ps.Runspace = $runspace

# 构造 SmartEngine 调用脚本块（分离变量，避免 AddScript({...}) 紧贴导致 parser 歧义）
$engineScript = {
    param($path, $lang, $logType, $outputPath, $fromPRO, $guiMode)

    $params = @{
        Language = $lang
        GUI_Mode = [switch]$guiMode
    }
    if ($logType) { $params.LogType = $logType }
    if ($outputPath) { $params.OutputPath = $outputPath }
    if ($fromPRO) { $params.FromPRO = $true }

    & $path @params
}
$null = $ps.AddScript($engineScript)
$null = $ps.AddArgument($smartEnginePath)
$null = $ps.AddArgument($Language)
$null = $ps.AddArgument($LogType)
$null = $ps.AddArgument($OutputPath)
$null = $ps.AddArgument($FromPRO.IsPresent)
$null = $ps.AddArgument($GUI_Mode.IsPresent)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AURORA SmartEngine - Console Mode" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[SmartEngine-CLI] Starting SmartEngine in background runspace..." -ForegroundColor Cyan

$asyncResult = $ps.BeginInvoke()

# ==========================================
# 4. 主线程轮询 syncHash，响应所有 GUI 事件
# ==========================================
# 状态机说明：
#   $commandExecuting = false  → 空闲状态，可显示菜单并等待用户输入
#   $commandExecuting = true   → 命令执行中，只打印日志/处理提权/授权，不显示菜单
#
# 命令完成检测信号（不依赖 CurrentPipelineStatus，因为它在日志写入前就被设置）：
#   1. ExecutedMenuIndices 变化 → 命令成功完成（最可靠）
#   2. CommandResult 变化 → 命令完成（成功或失败，非提权场景）
#   3. 提权被拒绝（4.3 中用户选 n）→ 主动重置
#   4. 授权被拒绝（4.4 中用户选 n/s）→ 主动重置
#   5. 超时 30 秒 → 兜底
#
# 非阻塞延迟：检测到完成后不立即重置，等待 1 秒让剩余日志输出完毕
$lastLogCount = 0
$lastProgress = -1
$menuPrinted = $false
$commandExecuting = $false
$lastExecutedIndices = ""
$lastCommandResult = $null
$completionDetected = $false
$completionTime = [DateTime]::MinValue
$commandStartTime = [DateTime]::MinValue

try {
    while (-not $asyncResult.IsCompleted) {

        # ==================== 4.1 实时打印日志 ====================
        # 始终执行，包括命令执行期间，确保执行结果实时输出
        # 使用 Test-ShouldSkipLog 过滤 GUI 导向日志，保留执行相关信息
        $currentLogs = $global:syncHash.LogOutput
        if ($currentLogs -and $currentLogs.Count -gt $lastLogCount) {
            for ($i = $lastLogCount; $i -lt $currentLogs.Count; $i++) {
                $line = $currentLogs[$i]
                if ($null -eq $line) { continue }
                $lineStr = [string]$line

                # CLI 模式智能过滤：跳过 GUI 导向日志
                if (Test-ShouldSkipLog $lineStr) { continue }

                # 按内容着色打印
                if ($lineStr -match '^\[ERROR\]|ERROR|失败|错误|异常') {
                    Write-Host $lineStr -ForegroundColor Red
                } elseif ($lineStr -match '^\[WARNING\]|WARNING|警告') {
                    Write-Host $lineStr -ForegroundColor Yellow
                } elseif ($lineStr -match '^\[SUCCESS\]|SUCCESS|成功|完成|通过') {
                    Write-Host $lineStr -ForegroundColor Green
                } elseif ($lineStr -match '^\[Phase|^\[Step|^\[Phase\s') {
                    Write-Host $lineStr -ForegroundColor Cyan
                } else {
                    Write-Host $lineStr -ForegroundColor Gray
                }
            }
            $lastLogCount = $currentLogs.Count
        }

        # ==================== 4.2 打印进度变化 ====================
        $currentProgress = $global:syncHash.Progress
        $currentActivity = $global:syncHash.CurrentActivity
        if ($currentProgress -ne $lastProgress -and $currentProgress -gt 0) {
            if ($currentActivity) {
                Write-Host ""
                Write-Host "[$currentProgress%] $currentActivity" -ForegroundColor Cyan
            }
            $lastProgress = $currentProgress
        }

        # ==================== 4.3 处理提权请求 ====================
        # 对应 SmartEngine 行 284-309 / 675-697
        # 始终检测，即使在命令执行期间
        if ($global:syncHash.RequiresElevation -eq $true) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host "  需要管理员权限" -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Yellow
            if ($global:syncHash.ElevationReason) {
                Write-Host "  $($global:syncHash.ElevationReason)" -ForegroundColor White
            }
            Write-Host "----------------------------------------" -ForegroundColor Gray
            Write-Host "  [y] 以管理员身份重启  [n] 跳过此操作" -ForegroundColor White
            $choice = Read-Host "请选择"

            if ($choice -eq 'y') {
                # 先启动新的管理员进程，再让 SmartEngine 退出当前进程
                # SmartEngine 检测到 ElevationAuthorized=true 后会调用 Invoke-SafeExit 退出整个进程
                $adapterPath = Join-Path $scriptDir "AURORA-SmartEngine-CLI.ps1"
                try {
                    # 🔒 安全修复 C-1：使用 ArgumentList 数组替代字符串拼接，杜绝参数注入
                    # $Language 和 $LogType 已由 ValidateSet 约束为白名单，无法包含注入字符
                    # $OutputPath 做路径规范化校验，禁止包含引号和特殊字符
                    $psi = New-Object System.Diagnostics.ProcessStartInfo
                    $psi.FileName = "powershell.exe"
                    # 构建参数数组（每个参数独立，避免拼接注入）
                    $argList = @(
                        '-NoExit',
                        '-ExecutionPolicy', 'Bypass',
                        '-File', $adapterPath,
                        '-Language', $Language,
                        '-LogType', $LogType,
                        '-GUI_Mode'
                    )
                    if ($OutputPath) {
                        # 路径规范化：禁止包含引号字符（防止闭合注入）
                        $safePath = [System.IO.Path]::GetFullPath($OutputPath)
                        if ($safePath -match '["`]') {
                            throw "Invalid OutputPath: contains forbidden characters"
                        }
                        $argList += @('-OutputPath', $safePath)
                    }
                    if ($FromPRO) { $argList += '-FromPRO' }
                    $psi.Arguments = ($argList | ForEach-Object {
                        if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
                    }) -join ' '
                    $psi.Verb = "RunAs"
                    $psi.UseShellExecute = $true
                    [System.Diagnostics.Process]::Start($psi) | Out-Null
                    Write-Host "[SmartEngine-CLI] New admin process launched." -ForegroundColor Green
                } catch {
                    Write-Host "[SmartEngine-CLI] Failed to launch admin process: $_" -ForegroundColor Red
                    Write-Host "  请手动以管理员身份运行。" -ForegroundColor Yellow
                }

                # 写入 ElevationAuthorized=true，SmartEngine 会调用 Invoke-SafeExit 退出当前进程
                $global:syncHash.ElevationAuthorized = $true
                $global:syncHash.RequiresElevation = $false
                # 等待 SmartEngine 退出进程
                Start-Sleep -Seconds 5
            } else {
                # 提权被拒绝：SmartEngine 会 return $false，命令不会执行
                # 主动重置命令执行状态，让菜单重新显示
                $global:syncHash.ElevationAuthorized = $false
                $global:syncHash.RequiresElevation = $false
                $commandExecuting = $false
                $completionDetected = $false
                $menuPrinted = $false
            }
        }

        # ==================== 4.4 处理授权请求 ====================
        # 对应 SmartEngine 行 410-438
        # 条件：RequiresAuthorization=true 且 Authorized 未设置（等待用户决策）
        # 始终检测，即使在命令执行期间
        if ($global:syncHash.RequiresAuthorization -eq $true -and $null -eq $global:syncHash.Authorized) {
            $cmd = $global:syncHash.PendingCommand
            $cmdName = "Unknown"
            if ($cmd) {
                if ($cmd.name) {
                    $cmdName = $cmd.name
                } elseif ($cmd.Name) {
                    $cmdName = $cmd.Name
                }
            }
            $riskLevel = ""
            if ($cmd) {
                if ($cmd.risk_level) {
                    $riskLevel = $cmd.risk_level
                } elseif ($cmd.RiskLevel) {
                    $riskLevel = $cmd.RiskLevel
                }
            }
            $description = ""
            if ($cmd) {
                if ($cmd.description) {
                    $description = $cmd.description
                } elseif ($cmd.Description) {
                    $description = $cmd.Description
                }
            }

            Write-Host ""
            Write-Host "========================================" -ForegroundColor Red
            Write-Host "  高危操作授权确认" -ForegroundColor Red
            Write-Host "========================================" -ForegroundColor Red
            Write-Host "  操作: $cmdName" -ForegroundColor White
            if ($riskLevel) {
                $riskColor = "Green"
                if ($riskLevel -match 'High|高') {
                    $riskColor = "Red"
                } elseif ($riskLevel -match 'Medium|中') {
                    $riskColor = "Yellow"
                }
                Write-Host "  风险等级: $riskLevel" -ForegroundColor $riskColor
            }
            if ($description) {
                Write-Host "  说明: $description" -ForegroundColor Gray
            }
            Write-Host "----------------------------------------" -ForegroundColor Gray
            Write-Host "  [y] 确认执行  [n] 拒绝  [s] 跳过" -ForegroundColor White
            $choice = Read-Host "请选择"

            # 打开授权事件句柄（SmartEngine 在后台 Runspace 创建的命名事件）
            $eventName = $global:syncHash.AuthorizationEventName
            $waitHandle = $null
            if ($eventName) {
                try {
                    $waitHandle = [System.Threading.EventWaitHandle]::OpenExisting($eventName)
                } catch {
                    try {
                        # 🔒 M-7：使用自定义安全描述符，仅允许当前用户进程同步
                        $cliCreatedNew = $false
                        $cliEvtSecurity = New-Object System.Security.AccessControl.EventWaitHandleSecurity
                        $cliEvtRule = New-Object System.Security.AccessControl.EventWaitHandleAccessRule(
                            [System.Security.Principal.WindowsIdentity]::GetCurrent().User,
                            "FullControl", "Allow")
                        $cliEvtSecurity.AddAccessRule($cliEvtRule)
                        $cliEvtSecurity.SetAccessRuleProtection($true, $false)
                        $waitHandle = New-Object System.Threading.EventWaitHandle(
                            $false, [System.Threading.EventResetMode]::ManualReset, $eventName,
                            [ref]$cliCreatedNew, $cliEvtSecurity)
                    } catch {
                        Write-Host "[SmartEngine-CLI] Warning: Could not open auth event handle" -ForegroundColor Yellow
                    }
                }
            }

            $authRejected = $false
            switch ($choice.ToLower()) {
                'y' {
                    $global:syncHash.Authorized = $true
                    # 清空 PendingCommand 防止 SmartEngine 主循环分支 1 触发双重执行
                    # （Invoke-AuroraSafeAction 授权通过后会直接执行命令，不需要分支 1 重新执行）
                    $global:syncHash.PendingCommand = $null
                    # 授权通过：SmartEngine 会继续执行命令，commandExecuting 保持 true
                }
                's' {
                    $global:syncHash.Authorized = $false
                    $global:syncHash.PendingCommand = $null
                    $global:syncHash.RequiresAuthorization = $false
                    $authRejected = $true
                }
                default {
                    $global:syncHash.Authorized = $false
                    $global:syncHash.PendingCommand = $null
                    $authRejected = $true
                }
            }

            # 触发事件，解除 SmartEngine 的 WaitOne 阻塞
            if ($waitHandle) {
                try { $waitHandle.Set(); $waitHandle.Close() } catch {}
            }

            # 授权被拒绝：SmartEngine 会 return $false，命令不会执行
            # 主动重置命令执行状态，让菜单重新显示
            if ($authRejected) {
                $commandExecuting = $false
                $completionDetected = $false
                $menuPrinted = $false
            }

            # 给 SmartEngine 时间处理
            Start-Sleep -Milliseconds 200
        }

        # ==================== 4.5 处理 CSV 导出日志确认 ====================
        # 对应 SmartEngine 行 1176-1199
        if ($global:syncHash.RequiresUserInput -eq $true) {
            $inputData = $global:syncHash.InputData
            $inputType = $global:syncHash.InputType

            Write-Host ""
            Write-Host "========================================" -ForegroundColor Cyan
            if ($inputType -eq "UseExportedLogs") {
                Write-Host "  检测到已导出的 CSV 日志" -ForegroundColor Cyan
                Write-Host "========================================" -ForegroundColor Cyan
                if ($inputData) {
                    Write-Host "  文件数: $($inputData.FileCount)" -ForegroundColor White
                    Write-Host "  导出路径: $($inputData.ExportPath)" -ForegroundColor Gray
                    if ($inputData.FileAge) {
                        Write-Host "  最新文件时间: $($inputData.FileAge)" -ForegroundColor Gray
                    }
                }
                Write-Host "----------------------------------------" -ForegroundColor Gray
                Write-Host "  [y] 使用已导出的日志  [n] 重新扫描" -ForegroundColor White
                $choice = Read-Host "请选择"
                if ($choice -eq 'y') {
                    $global:syncHash.UserInput = "yes"
                } else {
                    $global:syncHash.UserInput = "no"
                }
            } else {
                Write-Host "  需要用户输入 ($inputType)" -ForegroundColor Cyan
                Write-Host "========================================" -ForegroundColor Cyan
                $choice = Read-Host "请输入"
                $global:syncHash.UserInput = $choice
            }
            $global:syncHash.RequiresUserInput = $false
        }

        # ==================== 4.6 命令完成检测 ====================
        # 不依赖 CurrentPipelineStatus（它在日志写入前就被设置，导致过早重置）
        # 改用 ExecutedMenuIndices 变化 + CommandResult 变化 + 超时组合
        if ($commandExecuting) {
            if ($completionDetected) {
                # 非阻塞延迟：等待 1 秒让剩余日志输出完毕
                $elapsed = (New-TimeSpan -Start $completionTime -End (Get-Date)).TotalMilliseconds
                if ($elapsed -ge 1000) {
                    $commandExecuting = $false
                    $completionDetected = $false
                    $menuPrinted = $false
                    Write-Host ""
                    Write-Host "----------------------------------------" -ForegroundColor Gray
                }
            } else {
                # 检测命令完成信号
                $currentExecuted = $global:syncHash.ExecutedMenuIndices
                $currentResult = $global:syncHash.CommandResult

                # 信号 1：ExecutedMenuIndices 变化 → 命令成功完成
                $executedChanged = ($currentExecuted -ne $lastExecutedIndices)

                # 信号 2：CommandResult 变化 → 命令完成（成功或失败，非提权场景）
                # 用引用比较，因为每次命令执行后 CommandResult 会被替换为新 hashtable
                $resultChanged = $false
                if ($null -ne $currentResult) {
                    if ($null -eq $lastCommandResult) {
                        $resultChanged = $true
                    } else {
                        $resultChanged = -not [object]::ReferenceEquals($currentResult, $lastCommandResult)
                    }
                }

                # 信号 3：超时 30 秒 → 兜底
                $timedOut = $false
                if ($commandStartTime -ne [DateTime]::MinValue) {
                    $cmdElapsed = (New-TimeSpan -Start $commandStartTime -End (Get-Date)).TotalSeconds
                    if ($cmdElapsed -ge 30) {
                        $timedOut = $true
                    }
                }

                if ($executedChanged -or $resultChanged -or $timedOut) {
                    $completionDetected = $true
                    $completionTime = Get-Date
                    $lastExecutedIndices = $currentExecuted
                    $lastCommandResult = $currentResult
                }
            }
        }

        # ==================== 4.7 处理主菜单显示和输入 ====================
        # 对应 SmartEngine 行 1596-1720
        # 条件：不在命令执行中 + SmartMenuItems 已生成 + 未打印菜单 + 无待处理事件
        if (-not $commandExecuting -and $global:syncHash.SmartMenuItems -and -not $menuPrinted) {
            # 确保没有其他待处理事件（授权/提权/用户输入）
            if ($global:syncHash.RequiresAuthorization -ne $true -and
                $global:syncHash.RequiresElevation -ne $true -and
                $global:syncHash.RequiresUserInput -ne $true -and
                $global:syncHash.UserInput -eq $null) {

                # 打印菜单
                $menuItems = $global:syncHash.SmartMenuItems
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host "  $($global:syncHash.RepairMenuTitle)" -ForegroundColor White
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host "  $($global:syncHash.RepairPrompt)" -ForegroundColor Gray
                Write-Host "----------------------------------------" -ForegroundColor Gray

                # 解析已执行序号
                $executedIndices = @()
                if ($global:syncHash.ExecutedMenuIndices) {
                    $executedIndices = $global:syncHash.ExecutedMenuIndices -split ","
                }

                # 按规则分组打印
                $groups = [ordered]@{}
                foreach ($item in $menuItems) {
                    $ruleName = $item.RuleName
                    if (-not $ruleName) { $ruleName = "Other" }
                    if (-not $groups.Contains($ruleName)) {
                        $groups[$ruleName] = @()
                    }
                    $groups[$ruleName] += $item
                }

                foreach ($ruleName in $groups.Keys) {
                    Write-Host ""
                    Write-Host "  [$ruleName]" -ForegroundColor Yellow
                    foreach ($item in $groups[$ruleName]) {
                        $mark = "    "
                        if ($executedIndices -contains $item.Index) { $mark = "[OK]" }
                        $adminMark = "       "
                        if ($item.RequiresAdmin) { $adminMark = "[Admin]" }
                        $riskMark = "      "
                        if ($item.RiskLevel) { $riskMark = "[$($item.RiskLevel)]" }
                        $displayIndex = "{0,3}" -f $item.Index
                        Write-Host ("  {0} {1} {2} {3}. {4}" -f $mark, $adminMark, $riskMark, $displayIndex, $item.Name) -ForegroundColor White
                    }
                }

                Write-Host ""
                Write-Host "----------------------------------------" -ForegroundColor Gray
                Write-Host "  提示：输入序号执行修复 | 直接回车退出 | m 刷新菜单" -ForegroundColor Gray
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host ""

                $menuPrinted = $true

                # 等待用户输入（Read-Host 阻塞，但此时 SmartEngine 在等待 UserInput，无日志输出）
                Write-Host -NoNewline "> " -ForegroundColor Green
                $userInput = Read-Host

                # 特殊处理 m 命令：不传给 SmartEngine，直接重新打印菜单
                # SmartEngine 对 m 的响应是"修复菜单已在下方面板显示"，在 CLI 模式下无意义
                if ($userInput -match "^(?i)m$") {
                    $menuPrinted = $false
                    # 不设置 $commandExecuting，直接在下一个循环迭代重新打印菜单
                } else {
                    $global:syncHash.UserInput = $userInput
                    $menuPrinted = $false
                    # 进入命令执行状态，阻止菜单在命令执行期间重新打印
                    $commandExecuting = $true
                    $completionDetected = $false
                    $commandStartTime = Get-Date
                    # 记录执行前的状态，用于检测命令完成
                    $lastExecutedIndices = $global:syncHash.ExecutedMenuIndices
                    $lastCommandResult = $global:syncHash.CommandResult
                }
            }
        }

        # ==================== 4.8 检测 SmartEngine 完成 ====================
        if ($global:syncHash.ScriptDone -eq $true) {
            # 打印剩余日志
            $currentLogs = $global:syncHash.LogOutput
            if ($currentLogs -and $currentLogs.Count -gt $lastLogCount) {
                for ($i = $lastLogCount; $i -lt $currentLogs.Count; $i++) {
                    $line = $currentLogs[$i]
                    if ($null -ne $line) { Write-Host $line -ForegroundColor Gray }
                }
                $lastLogCount = $currentLogs.Count
            }
            Write-Host ""
            Write-Host "[SmartEngine-CLI] SmartEngine completed." -ForegroundColor Green
            break
        }

        Start-Sleep -Milliseconds 50
    }
} catch {
    Write-Host ""
    Write-Host "[SmartEngine-CLI] Error: $($_.Exception.Message)" -ForegroundColor Red
    # 🔒 安全修复 H-3：不向控制台打印完整堆栈跟踪，避免泄露内部调用路径
    # 堆栈跟踪仅写入日志文件（供调试），不显示给用户
    try {
        $logDir = Join-Path $env:LOCALAPPDATA "AURORA\Logs"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            # 🔒 M-6：为日志目录设置 ACL，仅允许当前用户访问
            try {
                $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                $dirAcl = Get-Acl $logDir
                $dirAcl.SetAccessRuleProtection($true, $false)
                $dirRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $currentIdentity.User, "FullControl", "ContainerInherit,ObjectInherit", "Allow")
                $dirAcl.AddAccessRule($dirRule)
                Set-Acl -Path $logDir -AclObject $dirAcl
            } catch {}
        }
        $logFile = Join-Path $logDir "smartengine_cli_error.log"
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logEntry = "[$timestamp] $($_.Exception.Message)`r`n$($_.ScriptStackTrace)`r`n---`r`n"
        Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
    } catch {}
} finally {
    # 等待后台 Runspace 完成
    if ($asyncResult -and -not $asyncResult.IsCompleted) {
        try { $ps.EndInvoke($asyncResult) } catch {}
    }

    # 打印后台 Runspace 的错误输出（仅错误消息，不含完整堆栈）
    if ($ps.Streams.Error -and $ps.Streams.Error.Count -gt 0) {
        Write-Host ""
        Write-Host "[SmartEngine-CLI] Background runspace errors:" -ForegroundColor Red
        foreach ($err in $ps.Streams.Error) {
            # 🔒 安全修复 H-3：仅打印错误消息，不打印完整堆栈和 InvocationInfo
            Write-Host $err.Exception.Message -ForegroundColor Red
        }
    }

    # 清理 Runspace
    try { $ps.Dispose() } catch {}
    try { $runspace.Close() } catch {}
    try { $runspace.Dispose() } catch {}

    Write-Host ""
    Write-Host "[SmartEngine-CLI] Exited." -ForegroundColor Cyan
}
