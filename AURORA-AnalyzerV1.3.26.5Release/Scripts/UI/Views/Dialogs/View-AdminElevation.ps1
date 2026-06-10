<#
.SYNOPSIS
    AURORA 提权重启功能
.DESCRIPTION
    提权重启功能
.NOTES
    版本：V1.3.26.5Release | 构建时间：2026.06.08
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>
# ====== 提权重启功能 ======
function Restart-WithAdmin {
    try {
        # 🔴 关键修复：使用 $global:MainScriptPath 而不是 $PSCommandPath
        # 因为 Restart-WithAdmin 在 View-AdminElevation.ps1 中定义，$PSCommandPath 返回的是 View-AdminElevation.ps1 的路径
        # 而我们需要的是 AURORA-AnalyzerLauncherGUI.ps1 的路径
        $scriptPath = $global:MainScriptPath
        if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
            # 回退方案：通过相对路径计算
            $scriptPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "Scripts\AURORA-AnalyzerLauncherGUI.ps1"
        }
        
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        if ($IsLaunchedByExe) {
            $arguments += " -LaunchedByExe"
        }
        
        # 传递语言参数
        if ($script:selectedLanguage) {
            $arguments += " -Language $($script:selectedLanguage)"
        } elseif ($env:AURORA_LANGUAGE) {
            $arguments += " -Language $($env:AURORA_LANGUAGE)"
        }
        
        # 🔐 P0修复（AURORA-SEC-2026-001）：生成提权安全令牌
        # 使用当前已验证的哈希列表加密后传递给提权进程
        # 解决 RSA 令牌文件被旧进程删除导致信任链断裂的问题
        $elevationTokenGenerated = $false
        if ($null -ne $global:PassedHashListFromExe -and $global:PassedHashListFromExe.Length -gt 0) {
            try {
                $elevNonce = [guid]::NewGuid().ToString("N")
                $elevTimestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                
                $elevKey = (New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
                    $elevNonce,
                    $global:AURORA_AesSalt,
                    1000,
                    [System.Security.Cryptography.HashAlgorithmName]::SHA256
                )).GetBytes(32)
                
                $elevAes = [System.Security.Cryptography.Aes]::Create()
                $elevAes.Key = $elevKey
                $elevAes.GenerateIV()
                $elevIv = $elevAes.IV
                
                $elevPlainBytes = [System.Text.Encoding]::UTF8.GetBytes($global:PassedHashListFromExe)
                $elevCipher = $elevAes.CreateEncryptor().TransformFinalBlock($elevPlainBytes, 0, $elevPlainBytes.Length)
                
                $elevPayload = $elevIv + $elevCipher
                $elevPayloadB64 = [Convert]::ToBase64String($elevPayload)
                $elevTokenContent = "$elevNonce`:$elevTimestamp`:$elevPayloadB64"
                
                $elevTokenFile = Join-Path $env:TEMP "aurora_elev_$([guid]::NewGuid().ToString("N")).tok"
                [System.IO.File]::WriteAllText($elevTokenFile, $elevTokenContent, [System.Text.Encoding]::UTF8)
                
                $arguments += " -ElevationTokenPath `"$elevTokenFile`""
                $elevationTokenGenerated = $true
                Write-Host "[安全] 提权令牌已生成" -ForegroundColor Green
            } catch {
                Write-Host "[安全] 提权令牌生成失败：$($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # 🔐 如果没有提权令牌，尝试传递原始安全环境变量作为回退
        # 注意：RSA 令牌文件可能在旧进程中已被删除，此处仅作尽力传递
        if (-not $elevationTokenGenerated) {
            if ($env:AURORA_TOKEN_PATH) {
                $arguments += " -TokenPath `"$($env:AURORA_TOKEN_PATH)`""
            }
            if ($env:AURORA_HASH_PATH) {
                $arguments += " -HashPath `"$($env:AURORA_HASH_PATH)`""
            }
        }
        
        Write-Host " 提权参数：$arguments" -ForegroundColor Gray
        Write-Host " 脚本路径：$scriptPath" -ForegroundColor Gray
        
        # 🔴 关键修复：提权前清理看门狗 Runspace，防止新进程启动时 EXE 看门狗检测到残留会话
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
    
        $AURORA_WATCHDOG_ACTIVE = $false
        [Environment]::SetEnvironmentVariable("AURORA_WD_PIPE", $null)
        [Environment]::SetEnvironmentVariable("AURORA_WD_SESSION", $null)
        
        # 🔴 修复：等待管道完全关闭，防止新进程连接失败
        Write-Host "[提权] 等待命名管道关闭..." -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 300
        
        $processInfo = Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -PassThru
        Write-Host " 新进程 ID: $($processInfo.Id)" -ForegroundColor Green
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host " 提权失败错误：$errorMsg" -ForegroundColor Red
        
        [System.Windows.Forms.MessageBox]::Show(
            $(if ($script:selectedLanguage -eq "CHS") {
                "提权已取消，将继续以普通用户模式运行。`n`n错误详情：$errorMsg`n`n如需管理员权限，请右键点击 AURORA-Analyzer.exe，选择'以管理员身份运行'。"
            } else {
                "Elevation cancelled, will continue with standard user mode.`n`nError: $errorMsg`n`nTo run as administrator, right-click AURORA-Analyzer.exe and select 'Run as administrator'."
            }),
            $(if ($script:selectedLanguage -eq "CHS") { "提示" } else { "Information" }),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return $false
    }
}
