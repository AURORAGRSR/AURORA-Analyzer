<#
.SYNOPSIS
    AURORA PRO 模式入口点
.DESCRIPTION
    Windows 系统事件日志导出与智能分析工具（统一 PRO 模式）
    支持单日或日期范围导出 System/Application/Security 日志
    生成结构化摘要报告和 CSV 原始数据
    自动识别错误、警告、严重事件并评估系统健康状态
    语言参数化：通过 $Language 参数支持 CHS 和 ENG
.PARAMETER Language
    语言选择：CHS 或 ENG。默认为 CHS。
.PARAMETER OutputPath
    可选。指定输出目录。默认为当前工作目录\UserLogs。
.PARAMETER AutoOpen
    导出完成后自动打开输出文件夹的开关。
.PARAMETER LogType
    可选。指定日志类型。默认为 System。
.PARAMETER GUI_Mode
    开关参数。标记是否在 GUI 模式下运行。
.NOTES
    版本：V1.5.29.0Release | 构建时间：2026.07.17
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>

Param(
    [ValidateSet("CHS", "ENG")]
    [string]$Language = "CHS",
    
    [string]$OutputPath,
    
    [switch]$AutoOpen,
    
    [ValidateSet("System", "Application", "Security", "Setup", "DNS Server", "DHCP Server", "Directory Service", "IIS Admin Service")]
    [string]$LogType = "System",
    
    [switch]$Silent,
    
    [ValidatePattern("^\d*$")]
    [string]$EventId,
    
    [string]$ProviderName,
    
    [ValidateSet("", "Critical", "Error", "Warning", "Information", "Verbose")]
    [string]$Level,
    
    [datetime]$StartTime,
    
    [datetime]$EndTime,
    
    [switch]$ForceRescan,
    
    [ValidateSet("SingleDay", "DateRange")]
    [string]$ExportMode,
    
    [ValidateSet("HighRiskOnly", "Full")]
    [string]$ExportScope,
    
    [switch]$TrendAnalysis,

    [switch]$GUI_Mode,

    # [控制台模式推荐] 低配机器通过性能升级弹窗进入控制台模式时传入。
    #   - 启动后打印菜单让用户选择「智能模式」或「专业模式」
    #   - 当前「智能模式」控制台版仍在开发中，会输出友好提示后走 PRO 专业流程
    #   - 「专业模式」直接走 PRO Engine 流程
    [switch]$ConsoleMode
)

# ==========================================
# 📚 加载语言资源（必须在启动检测之前）
# ==========================================
$scriptsDir = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition) }
$languageResourcePath = Join-Path $scriptsDir "GUI\AURORA-Language.psd1"

if (Test-Path $languageResourcePath) {
    $langResource = Import-LocalizedData -FileName "AURORA-Language.psd1" -BaseDirectory (Join-Path $scriptsDir "GUI")
    $L = $langResource[$Language]
    if (-not $L) {
        Write-Warning "Language '$Language' not found, falling back to CHS"
        $L = $langResource["CHS"]
    }
} else {
    Write-Warning "Language resource not found, using CHS"
    # 定义最小化的后备语言包
    $L = @{
        "Launcher_Required" = "❌ 此脚本不能直接运行！"
        "Use_Launcher" = "请使用以下方式启动："
        "Method_1" = "双击运行 AURORA-Analyzer.exe"
        "Method_2" = "  2. 或运行 AURORA-AnalyzerLauncherGUI.ps1"
        "Closing_Soon" = "程序将在 5 秒后自动关闭..."
        "Separator" = "========================================"
    }
}

# ==========================================
# 🔐 导入安全模块（确保 Test-RSATokenSignature 在启动检测前可用）
# ==========================================
# 🔴 修复：$scriptDir 未定义会导致 Split-Path 抛出 "Path 参数不能为 null" 错误
$scriptsDir = Split-Path $PSScriptRoot -Parent
$securityModulePath = Join-Path (Join-Path $scriptsDir "Security") "AURORA-SecurityModule.ps1"
if (Test-Path $securityModulePath) {
    . $securityModulePath
}

# ==========================================
# 🔒 启动检测：只允许由 GUI 启动，禁止直接运行
# ==========================================
$isLaunchedByGUI = $false

# 检测方式 1: 检查是否有 GUI_Mode 参数
if ($GUI_Mode) {
    $isLaunchedByGUI = $true
}

# 检测方式 2: 检查是否有全局 syncHash 变量
if (-not $isLaunchedByGUI -and (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
    $isLaunchedByGUI = $true
}

# 检测方式 3: RSA 令牌验证（由合法 EXE 签发的令牌）
if (-not $isLaunchedByGUI) {
    $TokenPath = $env:AURORA_TOKEN_PATH
    if (-not [string]::IsNullOrWhiteSpace($TokenPath) -and (Test-Path $TokenPath)) {
        try {
            $tokenContent = Get-Content $TokenPath -Raw -Encoding UTF8
            $parts = $tokenContent -split ':', 4
            if ($parts.Count -eq 4 -and (Get-Command Test-RSATokenSignature -ErrorAction SilentlyContinue)) {
                if (Test-RSATokenSignature -Nonce $parts[0] -Timestamp $parts[1] -HashPayload $parts[2] -Signature $parts[3]) {
                    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                    $age = $now - $parts[1]
                    if ($age -lt 60 -and $age -gt -5) {
                        $isLaunchedByGUI = $true
                    }
                }
            }
        } catch {
            Write-Warning "Non-critical operation failed: $($_.Exception.Message)"
            Write-Debug "Stack: $($_.ScriptStackTrace)"
        }
    }
}

# ==========================================
# 📦 导入核心引擎（提前导入，确保 Invoke-SafeExit 等函数在启动检测前可用）
# ==========================================
$coreEnginePath = Join-Path $scriptsDir "Core\AURORA-CoreEngine.ps1"
if (Test-Path $coreEnginePath) {
    . $coreEnginePath
} else {
    throw "Core engine not found: $coreEnginePath"
}

# 如果不是由 GUI 启动，则显示提示并退出
if (-not $isLaunchedByGUI) {
    Write-Host ""
    Write-Host $L['Separator'] -ForegroundColor Cyan
    Write-Host $L['Launcher_Required'] -ForegroundColor Red
    Write-Host $L['Separator'] -ForegroundColor Cyan
    Write-Host ""
    Write-Host $L['Use_Launcher'] -ForegroundColor Yellow
    Write-Host $L['Method_1'] -ForegroundColor White
    Write-Host $L['Method_2'] -ForegroundColor White
    Write-Host ""
    Write-Host $L['Closing_Soon'] -ForegroundColor Gray
    
    Start-Sleep -Seconds 5
    # 🔒 安全修复 M-4：退出逻辑加兜底，与 LaunchGuard 保持一致
    if (Get-Command Invoke-SafeExit -ErrorAction SilentlyContinue) {
        Invoke-SafeExit -ExitCode 1
    } else {
        [Environment]::Exit(1)
    }
}

# ==========================================
# 📈 导入进度管理器
# ==========================================
. "$scriptsDir\Session\AURORA-ProgressManager.ps1"
. "$scriptsDir\Session\AURORA-ProgressManager-Integration.ps1"

# === 初始化进度管理器 ===
$null = Initialize-CacheDirectory -ToolPath $scriptsDir

# ==========================================
# 🚀 主执行流程 - 载入统一 PRO 引擎（AURORA-AnalyzerPRO-Engine.ps1）
# ==========================================
Write-Host "[PRO] Starting AURORA PRO Mode (Language: $Language)" -ForegroundColor Cyan

# 设置语言上下文，供引擎使用
$script:Language = $Language
$script:Loc = $L

# 设置脚本级变量供 PRO-Engine 使用
$script:PRO_Language      = $Language
$script:PRO_OutputPath    = if ($OutputPath)    { $OutputPath }    else { $null }
$script:PRO_AutoOpen      = $AutoOpen.IsPresent
$script:PRO_LogType       = $LogType
$script:PRO_EventId       = $EventId
$script:PRO_ProviderName  = $ProviderName
$script:PRO_Level         = $Level
$script:PRO_StartTime     = if ($StartTime)     { $StartTime }     else { $null }
$script:PRO_EndTime       = if ($EndTime)       { $EndTime }       else { $null }
$script:PRO_ForceRescan   = $ForceRescan.IsPresent
$script:PRO_ExportMode    = $ExportMode
$script:PRO_ExportScope   = $ExportScope
$script:PRO_TrendAnalysis = $TrendAnalysis.IsPresent
$script:PRO_GUI_Mode      = $GUI_Mode.IsPresent
$script:PRO_Silent        = $Silent.IsPresent

# ==========================================
# 🎛 [控制台模式推荐] 智能/专业模式菜单选择
# ==========================================
# 当 -ConsoleMode 启用时，先打印菜单让用户选择「智能模式」或「专业模式」。
#   - 智能模式：当前控制台版仍在开发中，输出友好提示后走 PRO 专业流程
#   - 专业模式：直接走 PRO Engine 流程
# 这部分逻辑独立成块，便于后续扩展 SmartEngine CLI 适配层时替换。
if ($ConsoleMode) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    if ($Language -eq "ENG") {
        Write-Host "  AURORA Console Mode - Select Engine" -ForegroundColor White
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  [1] Smart Mode   (Auto-Healing Console - Coming Soon)" -ForegroundColor Yellow
        Write-Host "  [2] Pro Mode     (Full PRO Engine - Available)" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Recommended for low-spec machines: Console Mode skips" -ForegroundColor Gray
        Write-Host "  all WPF rendering pipeline (glass material, starfield, animations)." -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host "  AURORA 控制台模式 - 引擎选择" -ForegroundColor White
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  [1] 智能模式   (智能诊断与自主修复 - 控制台版开发中)" -ForegroundColor Yellow
        Write-Host "  [2] 专业模式   (完整 PRO 引擎 - 可用)" -ForegroundColor Green
        Write-Host ""
        Write-Host "  低配机器推荐：控制台模式跳过全部 WPF 渲染管线" -ForegroundColor Gray
        Write-Host "  (玻璃材质、星空、动画)，直接运行分析引擎。" -ForegroundColor Gray
        Write-Host ""
    }

    $consoleChoice = $null
    try {
        $consoleChoice = Read-Host "请选择模式 (1/2) [默认: 2=专业模式]"
    } catch {
        # 非交互环境，使用默认值
        $consoleChoice = ""
    }

    if ($consoleChoice -eq "1") {
        # 智能模式：调用 SmartEngine CLI 适配层
        # CLI 适配层在后台 Runspace 执行 SmartEngine.ps1，主线程用 Read-Host 响应所有 GUI 事件
        $smartCliPath = Join-Path $scriptsDir "Engines\AURORA-SmartEngine-CLI.ps1"
        if (Test-Path $smartCliPath) {
            Write-Host ""
            if ($Language -eq "ENG") {
                Write-Host "[Console] Launching SmartEngine CLI Adapter..." -ForegroundColor Green
            } else {
                Write-Host "[Console] 启动 SmartEngine CLI 适配层..." -ForegroundColor Green
            }
            Write-Host ""

            # 构造调用参数
            $smartCliParams = @{
                Language = $Language
                GUI_Mode = $true
            }
            if ($LogType)     { $smartCliParams.LogType = $LogType }
            if ($OutputPath)  { $smartCliParams.OutputPath = $OutputPath }
            $smartCliParams.FromPRO = $true

            # 调用 SmartEngine CLI 适配层（阻塞直到 SmartEngine 执行完毕）
            & $smartCliPath @smartCliParams

            # SmartEngine CLI 适配层执行完毕后退出（不继续加载 PRO 引擎）
            exit 0
        } else {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Red
            if ($Language -eq "ENG") {
                Write-Host "  SmartEngine CLI adapter not found" -ForegroundColor Red
                Write-Host "  Path: $smartCliPath" -ForegroundColor Gray
                Write-Host "  Falling back to PRO Engine." -ForegroundColor Yellow
            } else {
                Write-Host "  SmartEngine CLI 适配层未找到" -ForegroundColor Red
                Write-Host "  路径: $smartCliPath" -ForegroundColor Gray
                Write-Host "  回退到 PRO 专业模式。" -ForegroundColor Yellow
            }
            Write-Host "========================================" -ForegroundColor Red
            Write-Host ""
        }
    } else {
        # 专业模式（默认）
        Write-Host ""
        if ($Language -eq "ENG") {
            Write-Host "[Console] Launching PRO Engine (Professional Mode)..." -ForegroundColor Green
        } else {
            Write-Host "[Console] 启动 PRO 专业引擎..." -ForegroundColor Green
        }
        Write-Host ""
    }
}

# 载入统一 PRO 引擎（语言参数化，无需 CHSPRO/ENGPRO 分裂）
$unifiedEnginePath = Join-Path $scriptsDir "PRO\AURORA-AnalyzerPRO-Engine.ps1"
if (Test-Path $unifiedEnginePath) {
    Write-Host "[PRO] Loading Unified PRO Engine..." -ForegroundColor Green
    . $unifiedEnginePath
} else {
    throw "Unified PRO Engine not found: $unifiedEnginePath"
}
