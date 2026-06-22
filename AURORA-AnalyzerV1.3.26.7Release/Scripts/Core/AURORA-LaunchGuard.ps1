<#
.SYNOPSIS
    AURORA 统一启动守卫模块
.DESCRIPTION
    消除 6 个脚本文件中重复的"禁止直接运行"检测逻辑。
    提供 GUI_Mode 检测、syncHash 检测、RSA 令牌验证的统一入口。
.NOTES
    版本：V1.3.26.7Release | 创建时间：2026-06-22
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>

# ==========================================
# 🔒 防止重复导入标志
# ==========================================
if ($global:AURORA_LaunchGuard_Loaded -eq $true) {
    return
}
$global:AURORA_LaunchGuard_Loaded = $true

<#
.SYNOPSIS
    统一启动上下文验证
.DESCRIPTION
    检测当前脚本是否由 AURORA GUI 合法启动。
    依次尝试 GUI_Mode 参数 → syncHash 全局变量 → RSA 令牌验证。
    如果所有检测均失败，显示多语言提示并安全退出。
.PARAMETER Params
    脚本的参数字典（用于检查 GUI_Mode）
.PARAMETER LanguageResource
    多语言资源哈希表（用于显示退出提示）
.PARAMETER TimeoutSeconds
    退出前等待秒数（默认 5）
.EXAMPLE
    Assert-AuroraLaunchContext -Params $PSBoundParameters -LanguageResource $script:LanguageResource
#>
function Assert-AuroraLaunchContext {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [hashtable]$Params = @{},

        [Parameter()]
        [hashtable]$LanguageResource,

        [Parameter()]
        [int]$TimeoutSeconds = 5
    )

    $isLaunchedByGUI = $false

    # 检测 1: GUI_Mode 参数
    if ($Params.ContainsKey('GUI_Mode') -and $Params['GUI_Mode']) {
        $isLaunchedByGUI = $true
    }

    # 检测 2: syncHash 全局变量
    if (-not $isLaunchedByGUI -and (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue)) {
        $isLaunchedByGUI = $true
    }

    # 检测 3: RSA 令牌验证（由合法 EXE 签发的令牌）
    if (-not $isLaunchedByGUI) {
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
                            $isLaunchedByGUI = $true
                        }
                    }
                }
            } catch {
                Write-Warning "Launch context token validation failed: $($_.Exception.Message)"
                Write-Debug "Stack: $($_.ScriptStackTrace)"
            }
        }
    }

    # 验证失败 → 显示提示并退出
    if (-not $isLaunchedByGUI) {
        if ($LanguageResource) {
            $L = $LanguageResource
            Write-Host ""
            Write-Host $L['Separator'] -ForegroundColor Cyan
            Write-Host $L['Launcher_Required'] -ForegroundColor Red
            Write-Host $L['Separator'] -ForegroundColor Cyan
            Write-Host ""
            Write-Host $L['Use_Launcher'] -ForegroundColor Yellow
            Write-Host $L['Method_1'] -ForegroundColor White
            if ($L.ContainsKey('Method_2')) {
                Write-Host $L['Method_2'] -ForegroundColor White
            }
            Write-Host ""
            Write-Host $L['Closing_Soon'] -ForegroundColor Gray
        } else {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "  This script cannot be run directly!" -ForegroundColor Red
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Please use the following to launch:" -ForegroundColor Yellow
            Write-Host "Double-click AURORA-Analyzer.exe" -ForegroundColor White
            Write-Host ""
            Write-Host "Program will close automatically in 5 seconds..." -ForegroundColor Gray
        }

        Start-Sleep -Seconds $TimeoutSeconds

        if (Get-Command Invoke-SafeExit -ErrorAction SilentlyContinue) {
            Invoke-SafeExit -ExitCode 1
        } else {
            [Environment]::Exit(1)
        }
    }

    return $isLaunchedByGUI
}
