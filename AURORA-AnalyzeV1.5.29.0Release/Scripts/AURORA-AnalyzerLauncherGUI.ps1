<#
.SYNOPSIS
    AURORA 分析器 GUI 启动器
.DESCRIPTION
    Windows 系统事件日志导出与智能分析工具的图形界面启动程序
    构建自 .NET Framework 4.x 的 C# 5.0
.NOTES
    版本：V1.5.29.0Release | 构建时间：2026.07.16
    作者：AURORA VelociRaptor-GR Dev PRJ.
    警告：本工具仅用于个人学习使用。
#>

Param(
    [switch]$LaunchedByExe,
    [string]$TokenPath,           # 提权时传递的令牌路径
    [string]$ExeVerified,         # 提权时传递的 EXE 验证标志
    [string]$HashPath,            # 提权时传递的哈希列表路径
    [string]$ElevationTokenPath,   # P0修复：提权安全令牌路径（AURORA-SEC-2026-001）
    [string]$Language              # 界面语言（CHS/ENG），提权时传递
)

# ==========================================
# 统一错误行为约定
# ==========================================
$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'

# ==========================================
# 📦 获取脚本目录（必须在所有模块导入之前）
# ==========================================
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }

# 🔴 关键修复：在模块加载前定义 $rootDir，供 AURORA-GUI-Functions.ps1 使用
$rootDir = Split-Path -Parent $scriptDir

# 🔴 关键修复：保存主脚本路径，供 Restart-WithAdmin 函数使用（因为 $PSCommandPath 在点号导入的脚本中返回的是定义文件的路径）
$global:MainScriptPath = Join-Path $scriptDir "AURORA-AnalyzerLauncherGUI.ps1"

# ==========================================
# Security Module (moved to separate file)
# ==========================================

# ==========================================
# 📦 加载 GUI 辅助函数模块
# ==========================================

# 加载外部 GUI 辅助函数模块（避免代码冗余）
. "$scriptDir\GUI\AURORA-GUI-Functions.ps1"

# 加载动画核心引擎（AURORA-AnimationCoreEngine）
. "$scriptDir\Core\AURORA-AnimationCoreEngine.ps1"

# 加载 CoreEngine 共享核心引擎（提供 Invoke-SafeOperation 等统一工具函数）
# ⚠️ 必须在 SecurityModule 之前加载，因为 SecurityModule 依赖这些函数
. "$scriptDir\Core\AURORA-CoreEngine.ps1"

# 加载安全模块（依赖 CoreEngine 的 Invoke-SafeOperation 和 Write-AuroraLog）
. "$scriptDir\Security\AURORA-SecurityModule.ps1"

# ==========================================
# 🚀 极速硬件性能探针与动态分级 (Aurora Performance Profiler)
# ==========================================
$global:AuroraPerfTier = "Balanced" # 默认安全级别

try {
    # 限制查询时间，防止 WMI 卡死导致 GUI 启动白屏
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
    
    $ramGB = [Math]::Round($cs.TotalPhysicalMemory / 1GB)
    $logicalCores = $cpu.NumberOfLogicalProcessors
    $baseClock = $cpu.MaxClockSpeed # MHz

    # 算力加权评分算法：核心数(x15) + 内存(x5) + 主频溢出奖励
    $perfScore = ($logicalCores * 15) + ($ramGB * 5) + ([Math]::Max(0, ($baseClock - 2000) / 100))

    if ($perfScore -ge 240) {
        $global:AuroraPerfTier = "Extreme"     # 发烧级：8核+ 32G+
    } elseif ($perfScore -ge 120) {
        $global:AuroraPerfTier = "Performance" # 性能级：6核 16G
    } elseif ($perfScore -ge 70) {
        $global:AuroraPerfTier = "Balanced"    # 均衡级：4核 8G
    } else {
        $global:AuroraPerfTier = "Eco"         # 节能级：老旧设备
    }
} catch {
    $global:AuroraPerfTier = "Balanced"
}

# 注入进程级环境变量，供内嵌的 C# 引擎极速读取
[Environment]::SetEnvironmentVariable("AURORA_PERF_TIER", $global:AuroraPerfTier)

# 🔐 恢复提权传递的安全环境变量（UAC 会清空环境变量，需要从命令行参数恢复）
# 🔴 核心修复：不要立即清空环境变量，EXE 启动时通过环境变量传递令牌路径
# 仅当命令行参数显式传入时才覆盖环境变量，否则保留环境变量的值
if ($PSBoundParameters.ContainsKey('TokenPath') -and $TokenPath) {
    [Environment]::SetEnvironmentVariable("AURORA_TOKEN_PATH", $TokenPath)
}
if ($PSBoundParameters.ContainsKey('ExeVerified') -and $ExeVerified) {
    [Environment]::SetEnvironmentVariable("AURORA_EXE_VERIFIED", $ExeVerified)
}
if ($PSBoundParameters.ContainsKey('HashPath') -and $HashPath) {
    [Environment]::SetEnvironmentVariable("AURORA_HASH_PATH", $HashPath)
}
if ($PSBoundParameters.ContainsKey('ElevationTokenPath') -and $ElevationTokenPath) {
    [Environment]::SetEnvironmentVariable("AURORA_ELEVATION_TOKEN_PATH", $ElevationTokenPath)
}
if ($PSBoundParameters.ContainsKey('Language') -and $Language) {
    [Environment]::SetEnvironmentVariable("AURORA_LANGUAGE", $Language)
}

# 检测是否由 EXE 启动
# 优先信任 -LaunchedByExe 参数，但也接受环境变量（EXE 可能只设置环境变量）
# 注意：如果后续 RSA 令牌验证失败，会清理环境变量并重置此标志
$IsLaunchedByExe = [bool]$LaunchedByExe -or ($env:AURORA_LAUNCHED_BY_EXE -eq "1")

# ==========================================
# RSA 令牌验证 - 获取解密后的哈希列表
# ⚠️ 重要：无论启动方式都尝试解密哈希列表
# ==========================================
$TokenPath = $env:AURORA_TOKEN_PATH

if (-not [string]::IsNullOrWhiteSpace($TokenPath) -and (Test-Path $TokenPath)) {
    try {
        $tokenContent = Get-Content $TokenPath -Raw -Encoding UTF8

        $parts = $tokenContent -split ':'
        if ($parts.Count -ge 4) {
            $tokenNonce = $parts[0]
            $tokenTimestamp = [long]$parts[1]
            $tokenSignature = $parts[-1]
            $tokenHashB64 = $parts[2..($parts.Count - 2)] -join ':'

            if (Test-RSATokenSignature -Nonce $tokenNonce -Timestamp $tokenTimestamp -HashPayload $tokenHashB64 -Signature $tokenSignature) {
                $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                $age = $now - $tokenTimestamp

                if ($age -lt 60 -and $age -gt -5) {
                    $decryptedHashList = Decrypt-HashListFromToken -Nonce $tokenNonce -HashPayload $tokenHashB64
                    if ($null -ne $decryptedHashList -and $decryptedHashList.Length -gt 0) {
                        $IsLaunchedByExe = $true
                        $global:PassedHashListFromExe = $decryptedHashList
                        Write-Host "[安全] RSA 令牌验证通过" -ForegroundColor Green
                    }
                }
            }
        }
    } catch {
        Write-Host "[安全] 令牌处理异常：$($_.Exception.Message)" -ForegroundColor Red
    }

    try { Remove-Item $TokenPath -Force -ErrorAction SilentlyContinue } catch { Write-AuroraLog "令牌文件清理失败: $($_.Exception.Message)" -Level "Warning" }
}

# ==========================================
# 🔐 修复：提权安全令牌验证 (AURORA-SEC-2026-001)
# 解决提权后 RSA 令牌文件被旧进程删除导致信任链断裂的问题
# ==========================================
if ($ElevationTokenPath -and (Test-Path $ElevationTokenPath)) {
    try {
        $elevContent = Get-Content $ElevationTokenPath -Raw -Encoding UTF8
        $elevParts = $elevContent -split ':', 3
        if ($elevParts.Count -eq 3) {
            $elevNonce = $elevParts[0]
            $elevTimestamp = [long]$elevParts[1]
            $elevPayloadB64 = $elevParts[2]

            $elevAge = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $elevTimestamp
            if ($elevAge -gt 0 -and $elevAge -lt 60) {
                $elevPayload = [Convert]::FromBase64String($elevPayloadB64)
                if ($elevPayload.Length -gt 16) {
                    $elevIv = $elevPayload[0..15]
                    $elevCipher = $elevPayload[16..($elevPayload.Length - 1)]

                    $elevKey = (New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
                        $elevNonce,
                        $global:AURORA_AesSalt,
                        100000,
                        [System.Security.Cryptography.HashAlgorithmName]::SHA256
                    )).GetBytes(32)

                    $elevAes = [System.Security.Cryptography.Aes]::Create()
                    $elevAes.Key = $elevKey
                    $elevAes.IV = $elevIv
                    $elevAes.Mode = [System.Security.Cryptography.CipherMode]::CBC
                    $elevAes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

                    $elevPlainBytes = $elevAes.CreateDecryptor().TransformFinalBlock($elevCipher, 0, $elevCipher.Length)
                    $elevPlainText = [System.Text.Encoding]::UTF8.GetString($elevPlainBytes).TrimEnd("`r", "`n")

                    # 解析三部分内容：scriptPath:elevationToken:hashList
                    $elevParts2 = $elevPlainText -split ':', 3
                    if ($elevParts2.Count -ge 2 -and $elevParts2[0] -eq "AURORA-AnalyzerLauncherGUI.ps1") {
                        $IsLaunchedByExe = $true
                        # 提取哈希列表（第三部分）
                        if ($elevParts2.Count -ge 3) {
                            $global:PassedHashListFromExe = $elevParts2[2]
                        }
                        Write-Host "[安全] 提权令牌验证通过（令牌时效：$elevAge 秒）" -ForegroundColor Green
                    } else {
                        Write-Host "[安全] 提权令牌解密内容无效" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "[安全] 提权令牌已过期（时效：$elevAge 秒，最大允许：60秒）" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "[安全] 提权令牌验证异常：$($_.Exception.Message)" -ForegroundColor Red
    }

    try { Remove-Item $ElevationTokenPath -Force -ErrorAction SilentlyContinue } catch { Write-AuroraLog "提权令牌文件清理失败: $($_.Exception.Message)" -Level "Warning" }
}

# ==========================================
# 🔐 P0修复：如果 IsLaunchedByExe 来自命令行参数但既没有 RSA 令牌
# 也没有提权令牌验证通过，则重置为 $false 强制走密码验证
# 防止攻击者伪造 -LaunchedByExe 参数绕过所有安全验证
# ==========================================
if ($IsLaunchedByExe -and $null -eq $global:PassedHashListFromExe) {
    # [兼容提示] 检测旧版 AURORA-Analyzer.exe 启动器（V1.5.28.5 之前构建）
    #   旧启动器成功通过自身 GAURORA.CHK.ENC 哈希校验（设置了 AURORA_EXE_VERIFIED=1），
    #   但其内嵌的 RSA 私钥与当前脚本的新公钥不匹配 → RSA 令牌验签失败。
    #   场景特征：AURORA_EXE_VERIFIED=1 且令牌文件曾存在但验签未通过。
    if ($env:AURORA_EXE_VERIFIED -eq "1") {
        $lang = if ($Language) { $Language } elseif ($env:AURORA_LANGUAGE) { $env:AURORA_LANGUAGE } else { "CHS" }
        if ($lang -eq "ENG") {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host " [Compatibility Notice]" -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host " The launcher (AURORA-Analyzer.exe) that started this session" -ForegroundColor Yellow
            Write-Host " was built before V1.5.28.5 and its RSA key pair no longer" -ForegroundColor Yellow
            Write-Host " matches the current security module." -ForegroundColor Yellow
            Write-Host "" -ForegroundColor Yellow
            Write-Host " Recommended: Use 'AURORA-AnalyzerWPF.exe' (new launcher)" -ForegroundColor Cyan
            Write-Host " in the same directory instead, which does not require a password." -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host ""
        } else {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host " [兼容性提示]" -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host " 当前使用的启动器 (AURORA-Analyzer.exe) 为 V1.5.28.5 之前构建的旧版本，" -ForegroundColor Yellow
            Write-Host " 其内嵌的 RSA 密钥对与当前安全模块不匹配，无法通过令牌验证。" -ForegroundColor Yellow
            Write-Host "" -ForegroundColor Yellow
            Write-Host " 建议改用同目录下的 AURORA-AnalyzerWPF.exe（新版启动器）启动，" -ForegroundColor Cyan
            Write-Host " 该启动器无需输入密码。" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host ""
        }
    }
    Write-Host "[安全] 检测到未经验证的 -LaunchedByExe 标记，重置安全状态" -ForegroundColor Yellow
    $IsLaunchedByExe = $false
    [Environment]::SetEnvironmentVariable("AURORA_EXE_VERIFIED", $null)
    [Environment]::SetEnvironmentVariable("AURORA_HASH_PATH", $null)
    [Environment]::SetEnvironmentVariable("AURORA_TOKEN_PATH", $null)
    # 🔴 关键修复：清理 AURORA_LAUNCHED_BY_EXE 环境变量，防止同一 PowerShell 进程中第二次启动时误判
    [Environment]::SetEnvironmentVariable("AURORA_LAUNCHED_BY_EXE", $null)
}

# ==========================================
# 🔴 P0 修复：启动时强制清理残留看门狗资源 + 进程退出处理程序
# ==========================================
# ==========================================
# Watchdog cleanup and exit handler - moved to Security module
# ==========================================

# ==========================================
# 🔐 EXE 看门狗客户端 (Named Pipe 挑战 - 响应)
# 即使所有PS1验证被注释，EXE看门狗仍会检测并终止进程
# ⚠️ 关键：必须在 Clear-AuroraWatchdogEnv 之前读取环境变量！
# 因为 Clear-AuroraWatchdogEnv 会清除 AURORA_WD_PIPE 等变量
# ==========================================
$AURORA_WATCHDOG_ACTIVE = $false
$AURORA_WD_PIPE_NAME = $env:AURORA_WD_PIPE
$AURORA_WD_SESSION = $env:AURORA_WD_SESSION
$AURORA_WD_RETRY_COUNT = 0
$AURORA_WD_MAX_RETRY = 3
$AURORA_WD_RETRY_DELAY_MS = 500

# 启动时执行强制清理（看门狗环境变量已保存到脚本变量中，可以安全清理）
Clear-AuroraWatchdogEnv
# 注册退出处理程序
$script:AuroraExitHandlerRegistered = $false
Register-AuroraExitHandler

# 🔴 P0 修复：启动时重置所有状态标志，防止残留导致安全守卫被绕过
# 注意：必须在 AuroraGuard 初始化和看门狗连接之前重置
$script:ExitCountdownStarted = $false
$script:DebuggerCheckCount = 0
$script:IntegrityCheckCount = 0

if (-not [string]::IsNullOrWhiteSpace($AURORA_WD_PIPE_NAME)) {
    Write-Host "[看门狗] 正在连接命名管道：$AURORA_WD_PIPE_NAME" -ForegroundColor Cyan

    while ($AURORA_WD_RETRY_COUNT -lt $AURORA_WD_MAX_RETRY) {
        try {
            $retryTag = if ($AURORA_WD_RETRY_COUNT -gt 0) { "第 $($AURORA_WD_RETRY_COUNT + 1) 次尝试" } else { "" }
            $connectTimeout = 8000 + ($AURORA_WD_RETRY_COUNT * 4000)
            Write-Host "[看门狗] 尝试连接 $retryTag (超时：$connectTimeout ms)..." -ForegroundColor DarkGray

            $AURORA_WD_PIPE = New-Object System.IO.Pipes.NamedPipeClientStream(
                ".", $AURORA_WD_PIPE_NAME, [System.IO.Pipes.PipeDirection]::InOut)
            $AURORA_WD_PIPE.Connect($connectTimeout)

            # 初始化握手: 接收 HMAC 密钥
            $AURORA_WD_HANDSHAKE = New-Object byte[] 49
            $AURORA_WD_READ = 0
            $handshakeDeadline = [DateTime]::UtcNow.AddMilliseconds($connectTimeout)
            while ($AURORA_WD_READ -lt 49 -and [DateTime]::UtcNow -lt $handshakeDeadline) {
                if ($AURORA_WD_PIPE.CanRead) {
                    $AURORA_WD_READ += $AURORA_WD_PIPE.Read($AURORA_WD_HANDSHAKE, $AURORA_WD_READ, 49 - $AURORA_WD_READ)
                } else { Start-Sleep -Milliseconds 10 }
            }

            if ($AURORA_WD_HANDSHAKE[0] -ne 0x10) {
                $AURORA_WD_PIPE.Close()
                throw "看门狗握手协议错误"
            }

            # 提取 HMAC 密钥 (字节1-32) 和会话ID (字节33-48)
            $AURORA_WD_HMAC_KEY = New-Object byte[] 32
            [Array]::Copy($AURORA_WD_HANDSHAKE, 1, $AURORA_WD_HMAC_KEY, 0, 32)

            # 发送 ACK
            $AURORA_WD_ACK = New-Object byte[] 1
            $AURORA_WD_ACK[0] = 0x11
            $AURORA_WD_PIPE.Write($AURORA_WD_ACK, 0, 1)
            $AURORA_WD_PIPE.Flush()

            # 启动看门狗响应 Runspace
            $AURORA_WD_SCRIPT_PATH = $PSCommandPath
            $AURORA_WD_RUNSPACE = [runspacefactory]::CreateRunspace()
            $AURORA_WD_RUNSPACE.ApartmentState = "STA"
            $AURORA_WD_RUNSPACE.ThreadOptions = "ReuseThread"
            $AURORA_WD_RUNSPACE.Open()

            $AURORA_WD_PS = [powershell]::Create()
            $AURORA_WD_PS.Runspace = $AURORA_WD_RUNSPACE

            $null = $AURORA_WD_PS.AddScript({
                param($PIPE, $HMAC_KEY, $SELF_PATH)
                $ALIVE = $true
                $PIPE_READ_TIMEOUT = 4000

                while ($ALIVE -and $PIPE.IsConnected) {
                    try {
                        if (!$PIPE.CanRead) { Start-Sleep -Milliseconds 200; continue }

                        $CMD = New-Object byte[] 1
                        if ($PIPE.Read($CMD, 0, 1) -eq 0) { break }

                        if ($CMD[0] -eq 0x03) {
                            $NONCE = New-Object byte[] 16
                            $TS = New-Object byte[] 8
                            $OFF = 0
                            $DEADLINE = [DateTime]::UtcNow.AddMilliseconds($PIPE_READ_TIMEOUT)
                            while ($OFF -lt 16 -and [DateTime]::UtcNow -lt $DEADLINE) {
                                if ($PIPE.CanRead) { $OFF += $PIPE.Read($NONCE, $OFF, 16 - $OFF) }
                                else { Start-Sleep -Milliseconds 10 }
                            }
                            $OFF = 0
                            $DEADLINE = [DateTime]::UtcNow.AddMilliseconds($PIPE_READ_TIMEOUT)
                            while ($OFF -lt 8 -and [DateTime]::UtcNow -lt $DEADLINE) {
                                if ($PIPE.CanRead) { $OFF += $PIPE.Read($TS, $OFF, 8 - $OFF) }
                                else { Start-Sleep -Milliseconds 10 }
                            }

                            $HMAC = New-Object System.Security.Cryptography.HMACSHA256
                            $HMAC.Key = $HMAC_KEY
                            $HMAC_RESP = $HMAC.ComputeHash($NONCE)
                            $HMAC.Dispose()

                            $UPTIME = [BitConverter]::GetBytes([long](New-TimeSpan -Start (
                                Get-CimInstance Win32_OperatingSystem).LastBootUpTime -End (Get-Date)).TotalMilliseconds)

                            $FILE_HASH = New-Object byte[] 32
                            try {
                                if (Test-Path $SELF_PATH) {
                                    $FILE_HASH = (New-Object System.Security.Cryptography.SHA256Managed).ComputeHash(
                                        [System.IO.File]::ReadAllBytes($SELF_PATH))
                                }
                            } catch { Write-AuroraLog "看门狗文件哈希计算失败: $($_.Exception.Message)" -Level "Warning" }

                            $RESP = New-Object byte[] 73
                            $RESP[0] = 0x04
                            [Array]::Copy($HMAC_RESP, 0, $RESP, 1, 32)
                            [Array]::Copy($UPTIME, 0, $RESP, 33, 8)
                            [Array]::Copy($FILE_HASH, 0, $RESP, 41, 32)

                            if ($PIPE.IsConnected) {
                                $PIPE.Write($RESP, 0, 73)
                                $PIPE.Flush()
                            }
                        }
                    } catch {
                        Start-Sleep -Milliseconds 500
                    }
                }

                try { $PIPE.Close() } catch { Write-AuroraLog "看门狗管道关闭失败: $($_.Exception.Message)" -Level "Warning" }
            }).AddArgument($AURORA_WD_PIPE).AddArgument($AURORA_WD_HMAC_KEY).AddArgument($AURORA_WD_SCRIPT_PATH)

            $AURORA_WD_HANDLE = $AURORA_WD_PS.BeginInvoke()
            $AURORA_WATCHDOG_ACTIVE = $true

            Write-Host "[看门狗] 已连接 EXE 守护进程" -ForegroundColor Green
            break

        } catch {
            $AURORA_WD_RETRY_COUNT++
            Write-Host "[看门狗] 连接失败 (第 $AURORA_WD_RETRY_COUNT 次): $($_.Exception.Message)" -ForegroundColor Yellow

            # 清理失败的连接对象
            try {
                if ($AURORA_WD_PIPE -ne $null) {
                    if ($AURORA_WD_PIPE.IsConnected) { $AURORA_WD_PIPE.Close() }
                    $AURORA_WD_PIPE.Dispose()
                }
            } catch { Write-AuroraLog "看门狗连接清理失败: $($_.Exception.Message)" -Level "Warning" }

            if ($AURORA_WD_RETRY_COUNT -lt $AURORA_WD_MAX_RETRY) {
                Write-Host "[看门狗] 等待 $($AURORA_WD_RETRY_DELAY_MS)ms 后重试..." -ForegroundColor DarkGray
                Start-Sleep -Milliseconds $AURORA_WD_RETRY_DELAY_MS
            } else {
                Write-Host "[看门狗] 已达到最大重试次数，连接失败。为安全起见，进程将退出。" -ForegroundColor Red
                $AURORA_WATCHDOG_ACTIVE = $false
                Clear-AuroraWatchdogEnv
                # 🔒 安全修复 H-11：看门狗连接失败必须 fail-closed
                # 原方案 fail-open 允许攻击者通过阻断管道连接绕过所有看门狗保护
                # （HMAC 挑战-响应、文件哈希验证、运行时存活检测）
                Start-Sleep -Seconds 3
                [Environment]::Exit(1)
            }
        }
    }
}

# ==========================================
# C# embedded integrity guard - moved to Security module (lines 112-1034)
# ✅ 已在 AURORA-SecurityModule.ps1 中加载，此处仅作为标记
# ==========================================

# ==========================================
# 🔐 密码验证（非 EXE 启动时触发）
# ==========================================
if (-not $IsLaunchedByExe) {
    Write-Host "[信息] 非 EXE 启动模式，将请求密码验证" -ForegroundColor Gray
}

if (-not $IsLaunchedByExe) {
    $EncChkPath = Join-Path $scriptDir "..\GAURORA.CHK.ENC"
    
    if (-not (Test-Path $EncChkPath)) {
        [System.Windows.Forms.MessageBox]::Show(
            "未找到加密验证文件！`n请确保所有文件完整。",
            "AURORA 启动错误",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        Invoke-SafeExit -ExitCode 1
    }
    
    $PasswordForm = New-Object System.Windows.Forms.Form
    $PasswordForm.Text = if ($UseChinese) { "AURORA - 密码验证" } else { "AURORA - Password Verification" }
    $PasswordForm.Size = New-Object System.Drawing.Size(400, 200)
    $PasswordForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $PasswordForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $PasswordForm.MaximizeBox = $false
    $PasswordForm.MinimizeBox = $false
    $PasswordForm.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 36)
    $PasswordForm.ForeColor = [System.Drawing.Color]::White
    
    $TitleLabel = New-Object System.Windows.Forms.Label
    $TitleLabel.Text = if ($UseChinese) { "请输入启动密码" } else { "Please enter startup password" }
    $TitleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $TitleLabel.Size = New-Object System.Drawing.Size(360, 25)
    $TitleLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10, [System.Drawing.FontStyle]::Bold)
    $TitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(176, 205, 249)
    
    $PasswordTextBox = New-Object System.Windows.Forms.TextBox
    $PasswordTextBox.PasswordChar = '*'
    $PasswordTextBox.Location = New-Object System.Drawing.Point(20, 55)
    $PasswordTextBox.Size = New-Object System.Drawing.Size(340, 25)
    $PasswordTextBox.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)
    
    $HintLabel = New-Object System.Windows.Forms.Label
    $HintLabel.Text = if ($UseChinese) { "提示：您正在直接启动GUI，使用EXE启动可跳过验证" } else { "Hint: You are launching directly, use EXE to skip verification." }
    $HintLabel.Location = New-Object System.Drawing.Point(20, 85)
    $HintLabel.Size = New-Object System.Drawing.Size(360, 20)
    $HintLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
    $HintLabel.ForeColor = [System.Drawing.Color]::FromArgb(155, 136, 114, 227)
    
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Text = if ($UseChinese) { "确定" } else { "OK" }
    $OKButton.Location = New-Object System.Drawing.Point(260, 115)
    $OKButton.Size = New-Object System.Drawing.Size(100, 35)
    $OKButton.BackColor = [System.Drawing.Color]::FromArgb(16, 140, 222)
    $OKButton.ForeColor = [System.Drawing.Color]::White
    $OKButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $OKButton.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9, [System.Drawing.FontStyle]::Bold)
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    
    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Text = if ($UseChinese) { "取消" } else { "Cancel" }
    $CancelButton.Location = New-Object System.Drawing.Point(150, 115)
    $CancelButton.Size = New-Object System.Drawing.Size(100, 35)
    $CancelButton.BackColor = [System.Drawing.Color]::FromArgb(80, 84, 96)
    $CancelButton.ForeColor = [System.Drawing.Color]::White
    $CancelButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $CancelButton.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    
    $PasswordForm.Controls.Add($TitleLabel)
    $PasswordForm.Controls.Add($PasswordTextBox)
    $PasswordForm.Controls.Add($HintLabel)
    $PasswordForm.Controls.Add($OKButton)
    $PasswordForm.Controls.Add($CancelButton)
    $PasswordForm.AcceptButton = $OKButton
    $PasswordForm.CancelButton = $CancelButton
    
    $PasswordResult = $PasswordForm.ShowDialog()
    
    if ($PasswordResult -ne [System.Windows.Forms.DialogResult]::OK) {
        Invoke-SafeExit -ExitCode 1
    }
    
    try {
        $EncContent = Get-Content $EncChkPath -Raw -Encoding ASCII
        $EncBytes = [Convert]::FromBase64String($EncContent)
        if ($EncBytes.Length -lt 49) {
            throw "Invalid encrypted data (need Salt+IV+Cipher)"
        }
        
        $UserPassword = $PasswordTextBox.Text
        $Salt = $EncBytes[0..15]
        $Iv = $EncBytes[16..31]
        $Cipher = $EncBytes[32..($EncBytes.Length - 1)]
        
        $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
            $UserPassword,
            $Salt,
            100000,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )
        $KeyBytes = $pbkdf2.GetBytes(32)
        
        $Aes = [System.Security.Cryptography.Aes]::Create()
        $Aes.Key = $KeyBytes
        $Aes.IV = $Iv
        $Aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $Aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        
        $Decryptor = $Aes.CreateDecryptor()
        $PlainBytes = $Decryptor.TransformFinalBlock($Cipher, 0, $Cipher.Length)
        $PlainText = [System.Text.Encoding]::Default.GetString($PlainBytes)
        
        $global:PassedHashListFromExe = $PlainText
        
        $SuccessMsg = if ($UseChinese) { "密码验证成功！" } else { "Password verified successfully!" }
        [System.Windows.Forms.MessageBox]::Show(
            $SuccessMsg,
            "AURORA",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        $ErrorMsg = if ($UseChinese) { "密码错误！`n请重新输入。" } else { "Incorrect password!`nPlease try again." }
        [System.Windows.Forms.MessageBox]::Show(
            $ErrorMsg,
            "AURORA - 验证失败",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        Invoke-SafeExit -ExitCode 1
    }
}

# ==========================================
# 🔐 运行时完整性监控
# ==========================================

$global:IntegrityCheckInterval = 3000

function Test-FileIntegrity {
    param(
        [string]$DecryptedContent,
        [string]$BaseDir
    )
    
    $failedFiles = @()
    $script:ExpectedFileHashes = @{}
    
    $lines = $DecryptedContent -split "`r`n" | Where-Object { $_.Trim() -ne "" }
    foreach ($line in $lines) {
        $parts = $line -split ' ', 2
        if ($parts.Count -eq 2) {
            $script:ExpectedFileHashes[$parts[1]] = $parts[0].ToLower()
        }
    }
    
    foreach ($file in $script:ExpectedFileHashes.Keys) {
        $fullPath = Join-Path $BaseDir $file
        if (-not (Test-Path $fullPath)) {
            $failedFiles += $file
            continue
        }
        
        try {
            if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
                $hash = (Get-FileHash $fullPath -Algorithm SHA256).Hash.ToLower()
            } else {
                $sha256 = [System.Security.Cryptography.SHA256]::Create()
                $fileBytes = [System.IO.File]::ReadAllBytes($fullPath)
                $hashBytes = $sha256.ComputeHash($fileBytes)
                $hash = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
            }
            
            $expected = $script:ExpectedFileHashes[$file]
            if ($expected -and $hash -ne $expected) {
                $failedFiles += $file
            }
        } catch {
            $failedFiles += $file
        }
    }
    
    return @{
        Success = ($failedFiles.Count -eq 0)
        FailedFiles = $failedFiles
    }
}

function Initialize-RuntimeIntegrityCheck {
    param([string]$DecryptedContent)
    
    $script:FileLastCheckTime = @{}
    $script:IntegrityCheckCount = 0
    
    $lines = $DecryptedContent -split "`r`n" | Where-Object { $_.Trim() -ne "" }
    foreach ($line in $lines) {
        $parts = $line -split ' ', 2
        if ($parts.Count -eq 2) {
            $script:ExpectedFileHashes[$parts[1]] = $parts[0].ToLower()
            $script:FileLastCheckTime[$parts[1]] = $null
        }
    }
    
    if ($script:ExpectedFileHashes.Count -eq 0) { return }
    
    $script:CapturedRootDir = Split-Path -Parent $scriptDir
    
    $script:runtimeIntegrityTimer = New-Object System.Windows.Forms.Timer
    $script:runtimeIntegrityTimer.Interval = $global:IntegrityCheckInterval
    
    $script:randomIntegrityTimer = New-Object System.Windows.Forms.Timer
    $randomInterval = Get-Random -Minimum 2000 -Maximum 7000
    $script:randomIntegrityTimer.Interval = $randomInterval
    
    # 🔴 P1 修复：移除 FileSystemWatcher 直接事件订阅
    # PowerShell 脚本块作为 FileSystemWatcher 事件处理器时，事件在线程池 IOCP 线程触发，
    # 该线程没有 PowerShell Runspace，导致 PSInvalidOperationException 闪退。
    # 改用定时轮询 + 未授权文件扫描来替代实时文件监控。
    $script:guardFileExtensions = @('.ps1', '.json', '.xml', '.ico', '.exe', '.enc')
    $script:lastUnauthorizedScan = [DateTime]::MinValue
    $script:unauthorizedScanInterval = [TimeSpan]::FromSeconds(5)
    $script:knownUnauthorizedFiles = @{}   # 启动时已存在的未授权文件，避免误报
    $script:unauthorizedScanInitialized = $false
    
    $script:checkIntegrityLock = New-Object Object
    $script:integrityCheckInProgress = $false
    $script:checkIntegrity = {
        param($sender, $e)
        
        if ($script:integrityCheckInProgress) { return }
        if (-not [System.Threading.Monitor]::TryEnter($script:checkIntegrityLock, 0)) { return }
        try {
            $script:integrityCheckInProgress = $true
        
        $tampered = $false
        $missingFiles = @()
        $modifiedFiles = @()
        
        $expectedCount = $script:ExpectedFileHashes.Count
        $actualFiles = @()
        foreach ($file in $script:ExpectedFileHashes.Keys) {
            $fullPath = Join-Path $script:CapturedRootDir $file
            if (Test-Path $fullPath) {
                $actualFiles += $file
            }
        }
        $actualCount = $actualFiles.Count
        
        if ($actualCount -ne $expectedCount) {
            $missingFiles = $script:ExpectedFileHashes.Keys | Where-Object {
                -not (Test-Path (Join-Path $script:CapturedRootDir $_))
            }
            $tampered = $true
        }
        
        foreach ($file in $script:ExpectedFileHashes.Keys) {
            $fullPath = Join-Path $script:CapturedRootDir $file
            if (-not (Test-Path $fullPath)) { 
                $tampered = $true
                if ($missingFiles -eq $null) { $missingFiles = @() }
                $missingFiles += $file
            } else {
                $lastCheckTime = $script:FileLastCheckTime[$file]
                $currentWriteTime = (Get-Item $fullPath).LastWriteTime
                
                if ($lastCheckTime -eq $currentWriteTime) {
                    continue
                }
                
                try {
                    if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
                        $hash = (Get-FileHash $fullPath -Algorithm SHA256).Hash.ToLower()
                    } else {
                        $sha256 = [System.Security.Cryptography.SHA256]::Create()
                        $fileBytes = [System.IO.File]::ReadAllBytes($fullPath)
                        $hashBytes = $sha256.ComputeHash($fileBytes)
                        $hash = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
                    }
                    
                    $expected = $script:ExpectedFileHashes[$file]
                    if ($expected -and $hash -ne $expected) {
                        $tampered = $true
                        $modifiedFiles += $file
                    } else {
                        $script:FileLastCheckTime[$file] = $currentWriteTime
                    }
                } catch {
                    $tampered = $true
                    $modifiedFiles += $file
                }
            }
        }
        
        # 🔴 P1 修复：定时轮询检测未授权文件（替代 FileSystemWatcher.Created）
        $unauthorizedFile = $null
        $now = [DateTime]::Now
        if (-not $tampered -and ($now - $script:lastUnauthorizedScan) -ge $script:unauthorizedScanInterval) {
            $script:lastUnauthorizedScan = $now
            try {
                $allFiles = Get-ChildItem -Path $script:CapturedRootDir -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $script:guardFileExtensions -contains $_.Extension.ToLower() }
                foreach ($f in $allFiles) {
                    $relativePath = $f.FullName.Substring($script:CapturedRootDir.Length).TrimStart('\', '/')
                    if ($script:ExpectedFileHashes.ContainsKey($relativePath)) { continue }
                    
                    # 忽略常见运行时/日志目录，避免误报
                    if ($relativePath -like "UserLogs*" -or
                        $relativePath -like "*\SessionCache\*" -or
                        $relativePath -like "SessionCache\*" -or
                        $relativePath -like "Temp*" -or
                        $relativePath -like "build.log" -or
                        $relativePath -like "*.tmp") {
                        continue
                    }
                    
                    if (-not $script:unauthorizedScanInitialized) {
                        # 首次扫描：将已存在的未授权文件标记为已知，避免把构建产物当注入
                        $script:knownUnauthorizedFiles[$relativePath] = $true
                        continue
                    }
                    
                    if (-not $script:knownUnauthorizedFiles.ContainsKey($relativePath)) {
                        $unauthorizedFile = $relativePath
                        Write-Host "[Security] 检测到新增未授权文件: $relativePath" -ForegroundColor Yellow
                        break
                    }
                }
                $script:unauthorizedScanInitialized = $true
            } catch {
                Write-AuroraLog "未授权文件扫描失败: $($_.Exception.Message)" -Level "Warning"
            }
        }
        
        if ($tampered) {
            if ($null -ne $sender -and $null -ne $sender.Stop) { 
                try { $sender.Stop() } catch { Write-AuroraLog "完整性检查定时器停止失败: $($_.Exception.Message)" -Level "Warning" }
            }
            if ($script:runtimeIntegrityTimer) { $script:runtimeIntegrityTimer.Stop() }
            if ($script:randomIntegrityTimer) { $script:randomIntegrityTimer.Stop() }
            
            if ($global:proForm) {
                try {
                    if (-not $global:proForm.IsDisposed) {
                        $global:proForm.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
                        $global:proForm.Hide()
                    }
                } catch { Write-AuroraLog "proForm 隐藏失败: $($_.Exception.Message)" -Level "Warning" }
            }
            if ($splash) {
                try {
                    $splash.Hide()
                } catch { Write-AuroraLog "splash 隐藏失败: $($_.Exception.Message)" -Level "Warning" }
            }
            if ($global:mainForm) {
                try {
                    if (-not $global:mainForm.IsDisposed) {
                        $global:mainForm.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
                        $global:mainForm.Hide()
                    }
                } catch { Write-AuroraLog "mainForm 隐藏失败: $($_.Exception.Message)" -Level "Warning" }
            }
            
            $missingInfo = if ($missingFiles.Count -gt 0) {
                "`n🔴 缺失文件：`n" + ($missingFiles -join "`n  - ")
            } else { "" }
            
            $modifiedInfo = if ($modifiedFiles.Count -gt 0) {
                "`n🔴 篡改文件：`n" + ($modifiedFiles -join "`n  - ")
            } else { "" }
            
            Write-Host "[完整性检查] 检测到篡改！" -ForegroundColor Red
            Write-Host "  缺失文件数：$($missingFiles.Count)" -ForegroundColor Red
            Write-Host "  篡改文件数：$($modifiedFiles.Count)" -ForegroundColor Red
            
            if ($script:ExitCountdownStarted) { return }
            $script:ExitCountdownStarted = $true
            
            Write-Host "[Security Alert] Program will exit in 15 seconds..." -ForegroundColor Red
            [AuroraExitCountdown]::Show(
                " 安全警报：检测到文件篡改！",
                " Security Alert: File Tampering Detected!",
                "程序完整性已被破坏，检测到以下问题：$missingInfo$modifiedInfo`n`n程序将在 15 秒后自动退出。",
                "Program integrity compromised. Detected issues:$missingInfo$modifiedInfo`n`nProgram will exit in 15 seconds.",
                15,
                $true,
                $UseChinese
            )
        } elseif ($unauthorizedFile) {
            if ($null -ne $sender -and $null -ne $sender.Stop) { 
                try { $sender.Stop() } catch { Write-AuroraLog "完整性检查定时器停止失败: $($_.Exception.Message)" -Level "Warning" }
            }
            if ($script:runtimeIntegrityTimer) { $script:runtimeIntegrityTimer.Stop() }
            if ($script:randomIntegrityTimer) { $script:randomIntegrityTimer.Stop() }
            
            if ($global:proForm) {
                try {
                    if (-not $global:proForm.IsDisposed) {
                        $global:proForm.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
                        $global:proForm.Hide()
                    }
                } catch { Write-AuroraLog "proForm 隐藏失败: $($_.Exception.Message)" -Level "Warning" }
            }
            if ($splash) {
                try {
                    $splash.Hide()
                } catch { Write-AuroraLog "splash 隐藏失败: $($_.Exception.Message)" -Level "Warning" }
            }
            if ($global:mainForm) {
                try {
                    if (-not $global:mainForm.IsDisposed) {
                        $global:mainForm.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
                        $global:mainForm.Hide()
                    }
                } catch { Write-AuroraLog "mainForm 隐藏失败: $($_.Exception.Message)" -Level "Warning" }
            }
            
            if ($script:ExitCountdownStarted) { return }
            $script:ExitCountdownStarted = $true
            
            Write-Host "[Security Alert] Unauthorized file detected, program will exit in 15 seconds..." -ForegroundColor Red
            [AuroraExitCountdown]::Show(
                " 安全警报：检测到未授权文件！",
                " Security Alert: Unauthorized File Detected!",
                "检测到未授权文件：$unauthorizedFile`n程序可能已被注入恶意代码。`n`n程序将在 15 秒后自动退出。",
                "Unauthorized file detected: $unauthorizedFile`nProgram may have been injected with malicious code.`n`nProgram will exit in 15 seconds.",
                15,
                $true,
                $UseChinese
            )
        } else {
            $script:IntegrityCheckCount++
            $timestamp = Get-Date -Format "HH:mm:ss"
            $logLine = "[完整性检查] 通过 - 共 $($script:ExpectedFileHashes.Count) 个文件 - 第 $($script:IntegrityCheckCount) 次 - $timestamp"
            $clearLine = New-Object String(' ', $Host.UI.RawUI.WindowSize.BufferWidth)
            Write-Host "`r$clearLine" -NoNewline
            Write-Host "`r$logLine" -ForegroundColor DarkGray -NoNewline
        }
        } finally {
            $script:integrityCheckInProgress = $false
            [System.Threading.Monitor]::Exit($script:checkIntegrityLock)
        }
    }
    
    $script:runtimeIntegrityTimer.Add_Tick($script:checkIntegrity)
    $script:randomIntegrityTimer.Add_Tick($script:checkIntegrity)
    
    $script:runtimeIntegrityTimer.Start()
    $script:randomIntegrityTimer.Start()
    
    $startupCheckTimer = New-Object System.Windows.Forms.Timer
    $startupCheckTimer.Interval = 1000
    $startupCheckTimer.Add_Tick({
        param($sender, $e)
        if ($null -ne $sender) {
            try {
                $sender.Stop()
                $sender.Dispose()
            } catch { Write-AuroraLog "启动检查定时器清理失败: $($_.Exception.Message)" -Level "Warning" }
        }
        
        Write-Host "[启动检查] 执行启动后完整性检查..." -ForegroundColor Cyan
        & $script:checkIntegrity @($null, $null)
    })
    $startupCheckTimer.Start()
    
    $script:cleanupAction = {
        param($sender, $e)
        
        if ($script:runtimeIntegrityTimer) {
            $script:runtimeIntegrityTimer.Stop()
            $script:runtimeIntegrityTimer.Dispose()
        }
        if ($script:randomIntegrityTimer) {
            $script:randomIntegrityTimer.Stop()
            $script:randomIntegrityTimer.Dispose()
        }
        
        if ($global:PassedHashListFromExe) {
            $global:PassedHashListFromExe = $null
        }
        if ($script:ExpectedFileHashes) {
            $script:ExpectedFileHashes.Clear()
        }
    }
    
    $script:cleanupAction = $cleanupAction
}

# 提前声明 $splash 变量，防止完整性监控定时器在 Splash 创建前触发导致空引用
$splash = $null

# 启动时完整性检查（无论 EXE 启动还是密码验证启动）
if ($null -ne $global:PassedHashListFromExe -and $global:PassedHashListFromExe.Length -gt 0) {
    $integrityResult = Test-FileIntegrity -DecryptedContent $global:PassedHashListFromExe -BaseDir $rootDir

    if (-not $integrityResult.Success) {
        Write-Host "[警告] 启动时完整性检查发现异常文件：" -ForegroundColor Yellow
        $integrityResult.FailedFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }

        if ($env:AURORA_EXE_VERIFIED -eq "1") {
            Write-Host "[信息] EXE 验证已通过，将继续运行但功能受限" -ForegroundColor Gray
        } else {
            Write-Host "[警告] 请通过 AURORA-Analyzer.exe 启动以确保完整性" -ForegroundColor Yellow
        }
    }

    Initialize-RuntimeIntegrityCheck -DecryptedContent $global:PassedHashListFromExe
} else {
    Write-Host "[提示] 未能获取完整性校验数据" -ForegroundColor Gray

    if ($env:AURORA_EXE_VERIFIED -eq "1") {
        Write-Host "[信息] EXE 层验证已通过，将继续运行" -ForegroundColor Green
    } else {
        Write-Host "[注意] 建议通过 AURORA-Analyzer.exe 启动以获得安全保障" -ForegroundColor Yellow
    }
}

# === 加载 .NET Windows Forms 与绘图核心库 ===
# P2 修复：检查是否已加载，避免重复 Add-Type
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'System.Windows.Forms' })) {
    Add-Type -AssemblyName System.Windows.Forms
}
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'System.Drawing' })) {
    Add-Type -AssemblyName System.Drawing
}

# ====== 【可选】启用 DPI 感知与现代视觉样式（当前已注释，保留为参考）======
<#
# 启用 Windows XP 及以上系统的视觉样式（如主题、圆角等）
[System.Windows.Forms.Application]::EnableVisualStyles()
# 禁用 GDI+ 文本渲染兼容模式，提升文本清晰度
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# 若系统为 Windows 8 或更高（版本 >= 6.2），尝试启用进程级 DPI 感知
if ([Environment]::OSVersion.Version -ge (New-Object Version(6, 2))) {
    try {
        # 定义 C# 类调用 user32.dll 的 SetProcessDPIAware 函数
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
"@
        # 执行 DPI 感知设置（防止高 DPI 下界面模糊）
        [DpiHelper]::SetProcessDPIAware() | Out-Null
    } catch {
        # 忽略异常（如权限不足或 API 不可用）
    }
}
#>

# ==========================================
# UI Controls Library (moved to separate file)
# ==========================================
. "$scriptDir\UI\Controls\AURORA-UIControls.ps1"


# === 注意：以下函数已移至 AURORA-GUI-Functions.ps1 模块 ===
# - Get-EmojiFont
# - Get-MonospaceFont
# - Get-SansSerifFont
# - Update-StarfieldStatusText
# - CreateAuroraProgressBar
# 此处保留注释用于向后兼容性说明

# ==========================================
# Directory integrity check (using version from GUI-Functions)
# ==========================================
if (-not (Test-DirectoryIntegrity -rootDir $rootDir -ShowWarning)) {
    Invoke-SafeExit -ExitCode 1
}

# === 检查管理员权限 ===
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# === 【核心修复 1/3】提前初始化进度管理器（在 PRO 模式启动前创建 SessionCache）===
# 导入进度管理器核心模块
. "$scriptDir\Session\AURORA-ProgressManager.ps1"
# 初始化缓存目录（优先使用工具目录，降级到 TEMP）
$null = Initialize-CacheDirectory -ToolPath $scriptDir

# === #############################################################################
# 🔄 全局同步哈希表 (syncHash) - 跨线程通信标准接口
# 设计模式：Thread-Safe Synchronized Hashtable
# 用途：主 UI 线程 <-> 后台 Runspace 之间的唯一数据通道
# 访问模式：
#   - GUI 线程：读取 LogOutput/Progress 更新 UI，写入 UserInput 响应 PRO
#   - PRO 脚本：写入 Progress/LogOutput/CurrentActivity 报告状态，读取 UserInput 获取用户输入
# 线程安全：[hashtable]::Synchronized() 确保原子操作
# === #############################################################################
$global:syncHash = [hashtable]::Synchronized(@{
    # === 生命周期控制 ===
    IsHostAlive  = $true       # [GUI->PRO] 控制后台线程生命周期
    IsRunning    = $false      # [PRO->GUI] 标记 PRO 脚本是否正在执行
    ScriptDone   = $false      # [PRO->GUI] 标记脚本是否彻底执行完毕
    
    # === 日志输出流 ===
    LogOutput    = ""          # [PRO->GUI] 接收来自 PRO 脚本的日志输出 (UI 定时器读取)
    
    # === 进度报告 ===
    Progress     = 0           # [PRO->GUI] 接收进度百分比 (0-100)
    CurrentActivity = ""       # [PRO->GUI] 当前活动阶段描述（如 "0/4 任务配置"）
    CurrentStatus = ""         # [PRO->GUI] 当前状态消息
    
    # === 用户输入通道 ===
    UserInput    = $null       # [GUI->PRO] GUI 向 PRO 脚本发送的用户输入指令
    
    # === 权限管理 ===
    IsAdmin      = $isAdmin    # [GUI->PRO] 记录是否有管理员权限
    RequiresElevation = $false  # [PRO->GUI] 请求提权确认
    ElevationReason = ""       # [PRO->GUI] 提权原因描述
    ElevationLogType = ""      # [PRO->GUI] 需要提权的日志类型
    ElevationAuthorized = $null # [GUI->PRO] 用户提权授权结果 (true/false)
    
    # === 会话恢复系统 (Phase 2 核心修复) ===
    SessionRestored = $false   # [GUI->PRO] 标记用户选择恢复进度
    SessionRestarted = $false  # [GUI->PRO] 标记用户选择重新开始
    RestoredSessionId = $null  # [GUI->PRO] 恢复的会话 ID
    RestoredStage = $null      # [GUI->PRO] 恢复的阶段
    RestoredProgress = 0       # [GUI->PRO] 恢复的进度百分比
    HasPendingSession = $false # [GUI 内部] 标记是否有待恢复的会话
    RestoredLastUpdated = $null # [GUI->PRO] 会话最后更新时间
    RestoredAgeInDays = 0      # [GUI->PRO] 会话已挂起天数
    
    # === 会话恢复 HUD 显示控制 ===
    ShowSessionRecoveryHUD = $false  # [PRO->GUI] 触发会话恢复 HUD 显示
})

# ==========================================
# View: Splash Screen (moved to separate file)
# ==========================================
. "$scriptDir\UI\Views\View-SplashScreen.ps1"

# 清理资源
$splash.Visible = $false
Start-Sleep -Milliseconds 50
$splash.Dispose()

# ==========================================
# View: Session Restore Dialog (moved to separate file)
# ==========================================
. "$scriptDir\UI\Views\Dialogs\View-SessionRestoreDialog.ps1"


# ==========================================
# View: Elevation Dialog (moved to separate file)
# ==========================================
. "$scriptDir\UI\Views\Dialogs\View-ElevationDialog.ps1"

# ==========================================
# View: Permission Info Dialog (moved to separate file)
# ==========================================
. "$scriptDir\UI\Views\Dialogs\View-PermissionInfo.ps1"

# ==========================================
# View: Admin Elevation (moved to separate file)
# ==========================================
. "$scriptDir\UI\Views\Dialogs\View-AdminElevation.ps1"

# ==========================================
# View: Main Form (moved to separate file)
# ==========================================
. "$scriptDir\UI\Views\View-MainForm.ps1"



# ==========================================
# View: PRO Mode Window (moved to separate file)
# ==========================================
. "$scriptDir\UI\Views\View-ProMode.ps1"


# ==========================================
# Animation Helpers (moved to separate file)
# ==========================================
. "$scriptDir\UI\Controls\AURORA-Animations.ps1"

# === 清理看门狗环境变量 ===
if ($AURORA_WATCHDOG_ACTIVE) {
    [Environment]::SetEnvironmentVariable("AURORA_WD_PIPE", $null)
    [Environment]::SetEnvironmentVariable("AURORA_WD_SESSION", $null)
}

# === 完整清理看门狗 Runspace 和 PowerShell 对象 ===
# 🔴 关键修复：防止 Runspace 残留导致下次启动时 EXE 看门狗拒绝连接
if ($AURORA_WD_RUNSPACE -ne $null) {
    try {
        if ($AURORA_WD_RUNSPACE.IsOpen) {
            $AURORA_WD_RUNSPACE.Close()
        }
        $AURORA_WD_RUNSPACE.Dispose()
    } catch { Write-AuroraLog "Runspace清理失败: $($_.Exception.Message)" -Level "Warning" }
}
if ($AURORA_WD_PS -ne $null) {
    try {
        $AURORA_WD_PS.Dispose()
    } catch { Write-AuroraLog "PowerShell实例清理失败: $($_.Exception.Message)" -Level "Warning" }
}
if ($AURORA_WD_PIPE -ne $null) {
    try {
        if ($AURORA_WD_PIPE.IsConnected) {
            $AURORA_WD_PIPE.Close()
        }
        $AURORA_WD_PIPE.Dispose()
    } catch { Write-AuroraLog "Pipe清理失败: $($_.Exception.Message)" -Level "Warning" }
}

# 🔴 修复：清理 AuroraGuard 持续性检测定时器和 WMI 事件订阅
if ($script:debuggerTimer -ne $null) {
    try {
        $script:debuggerTimer.Enabled = $false
        $script:debuggerTimer.Stop()
        $script:debuggerTimer.Dispose()
        Write-Host "[退出清理] debuggerTimer 已释放" -ForegroundColor DarkGray
    } catch { Write-AuroraLog "调试器定时器清理失败: $($_.Exception.Message)" -Level "Warning" }
}
if ($script:debuggerWmiWatcher -ne $null) {
    try {
        Unregister-Event -SourceIdentifier $script:debuggerWmiWatcher.Name -ErrorAction SilentlyContinue
        Write-Host "[退出清理] WMI 事件订阅已取消" -ForegroundColor DarkGray
    } catch { Write-AuroraLog "WMI事件取消注册失败: $($_.Exception.Message)" -Level "Warning" }
}
$AURORA_WATCHDOG_ACTIVE = $false
