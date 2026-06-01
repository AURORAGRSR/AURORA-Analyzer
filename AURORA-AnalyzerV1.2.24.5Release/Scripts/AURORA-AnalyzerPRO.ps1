# AURORA-AnalyzerPRO.ps1
# Requires -Version 5.1
# 统一的 PRO 模式入口文件（合并 CHSPRO 和 ENGPRO）
# 作者：AURORA VelociRaptor-GR Dev PRJ.
# 版本：V1.2.13Release
# 构建时间：2026.06.01

<#
.SYNOPSIS
    Windows 系统事件日志导出与智能分析工具（统一双语版）
.DESCRIPTION
    支持按单日或日期范围导出 System/Application/Security 等日志，生成结构化摘要报告与 CSV 原始数据。
    自动识别错误、警告、严重事件，并评估系统健康状态。
    支持双语（中文/英文），通过$Language 参数控制。
.PARAMETER Language
    指定界面语言。可选值：CHS（中文）, ENG（英文）。默认为 CHS。
.PARAMETER OutputPath
    可选。指定输出目录。默认为 当前工作目录\UserLogs。
.PARAMETER AutoOpen
    开关参数。导出完成后自动打开输出文件夹。
.PARAMETER LogType
    可选。指定日志类型。默认为 System。
.PARAMETER GUI_Mode
    开关参数。标记是否在 GUI 模式下运行。
.NOTES
    版本：V13.0 Unified
    构建时间：2026.05.14
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
    
    [ValidateSet("Critical", "Error", "Warning", "Information", "Verbose")]
    [string]$Level,
    
    [datetime]$StartTime,
    
    [datetime]$EndTime,
    
    [switch]$ForceRescan,
    
    [ValidateSet("SingleDay", "DateRange")]
    [string]$ExportMode,
    
    [ValidateSet("HighRiskOnly", "Full")]
    [string]$ExportScope,
    
    [switch]$TrendAnalysis,
    
    [switch]$GUI_Mode
)

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
        } catch {}
    }
}

# 如果不是由 GUI 启动，则显示提示并退出
if (-not $isLaunchedByGUI) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  ❌ 此脚本不能直接运行！" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "请使用以下方式启动：" -ForegroundColor Yellow
    Write-Host "双击运行 AURORA.Launcher-双击启动.exe" -ForegroundColor White
    Write-Host ""
    Write-Host "程序将在 5 秒后自动关闭..." -ForegroundColor Gray
    
    Start-Sleep -Seconds 5
    exit 1
}

# ==========================================
# 📚 加载语言资源
# ==========================================
$progressManagerDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$languageResourcePath = Join-Path $progressManagerDir "AURORA-Language.psd1"

if (Test-Path $languageResourcePath) {
    $langResource = Import-LocalizedData -FileName "AURORA-Language.psd1" -BaseDirectory $progressManagerDir
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
        "Method_1" = "双击运行 AURORA.Launcher.exe"
        "Closing_Soon" = "程序将在 5 秒后自动关闭..."
    }
}

# ==========================================
# 📦 导入核心引擎（仅导入，不初始化）
# ==========================================
$coreEnginePath = Join-Path $progressManagerDir "AURORA-CoreEngine.ps1"
if (Test-Path $coreEnginePath) {
    . $coreEnginePath
} else {
    throw "Core engine not found: $coreEnginePath"
}

# ==========================================
# 📈 导入进度管理器
# ==========================================
. "$progressManagerDir\AURORA-ProgressManager.ps1"
. "$progressManagerDir\AURORA-ProgressManager-Integration.ps1"

# === 初始化进度管理器 ===
$null = Initialize-CacheDirectory -ToolPath $progressManagerDir

# ==========================================
# 🚀 主执行流程 - 根据语言选择调用 CHSPRO 或 ENGPRO
# ==========================================
Write-Host "[PRO] Starting AURORA PRO Mode (Language: $Language)" -ForegroundColor Cyan

# 根据 Language 参数选择调用 CHSPRO 或 ENGPRO
# 注意：CHSPRO/ENGPRO 会负责初始化 CoreEngine，这里不再重复初始化
if ($Language -eq "CHS") {
    # 调用中文版 PRO
    Write-Host "[PRO] Loading Chinese Professional Edition..." -ForegroundColor Green
    . "$progressManagerDir\AURORA-AnalyzerCHSPRO.ps1"
} else {
    # 调用英文版 PRO
    Write-Host "[PRO] Loading English Professional Edition..." -ForegroundColor Green
    . "$progressManagerDir\AURORA-AnalyzerENGPRO.ps1"
}
