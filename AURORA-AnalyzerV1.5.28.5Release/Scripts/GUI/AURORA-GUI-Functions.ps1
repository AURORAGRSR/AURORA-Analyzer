<#
.SYNOPSIS
    AURORA GUI 辅助函数模块
.DESCRIPTION
    从 AURORA-AnalyzerLauncherGUI.ps1 拆分的 GUI 辅助函数
    包含：字体辅助函数、目录完整性检测、进度条创建等
.NOTES
    版本：V1.5.28.5Release | 构建时间：2026.07.14
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>

# =========================================================
# 字体辅助函数
# =========================================================

function global:Get-EmojiFont {
    [CmdletBinding()]
    param(
        [float]$Size = 10,
        [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular
    )
    # 使用 FontHelper 获取 emoji 字体（带降级）
    try {
        return [FontHelper]::GetEmojiFont($Size, $Style)
    } catch {
        # 如果失败，返回一个安全的默认字体
        return New-Object System.Drawing.Font("Microsoft Sans Serif", $Size, $Style)
    }
}

function global:Get-MonospaceFont {
    [CmdletBinding()]
    param(
        [float]$Size = 10,
        [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular
    )
    try {
        return [FontHelper]::GetMonospaceFont($Size, $Style)
    } catch {
        return New-Object System.Drawing.Font("Courier New", $Size, $Style)
    }
}

function global:Get-SansSerifFont {
    [CmdletBinding()]
    param(
        [float]$Size = 10,
        [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular
    )
    try {
        return [FontHelper]::GetSansSerifFont($Size, $Style)
    } catch {
        return New-Object System.Drawing.Font("Microsoft Sans Serif", $Size, $Style)
    }
}

function global:Update-StarfieldStatusText {
    [CmdletBinding()]
    param(
        [StarfieldPanel]$Panel,
        [string]$NewText
    )
    # 使用反射调用 C# 对象的内部方法
    $method = $Panel.GetType().GetMethod("UpdateStatusText", [System.Reflection.BindingFlags]"Instance,NonPublic")
    if ($method) {
        $method.Invoke($Panel, @($NewText))
    }
}

function global:CreateAuroraProgressBar {
    [CmdletBinding()]
    $pb = New-Object AuroraProgressBar
    $pb.Size = New-Object System.Drawing.Size(300, 12)   # 尺寸
    $pb.Location = New-Object System.Drawing.Point(60, 90) # 位置
    $pb.Minimum = 0
    $pb.Maximum = 100
    $pb.Value = 0
    $pb.CornerRadius = 8
    return $pb
}

# =========================================================
# 目录完整性检测系统
# =========================================================

function Test-DirectoryIntegrity {
    param(
        [string]$rootDir,
        [switch]$ShowWarning = $false
    )

    # 定义所需文件列表（必需文件描述用于错误提示）
    $RequiredFiles = @{
        # 核心启动文件（根目录）
        "AURORA-Analyzer.exe"       = "主启动器（免密码启动 GUI）"
        "Scripts\AURORA-AnalyzerLauncherGUI.ps1"  = "主启动 GUI 脚本（界面与任务管理）"
        
        # PRO 模式统一引擎 (Phase 7: merged CHS/ENG into single engine)
        "Scripts\PRO\AURORA-AnalyzerPRO-Engine.ps1" = "PRO 模式统一日志导出引擎 (CHS/ENG)"
        
        # 智能诊断系统 (Phase 7: moved to Engines/)
        "Scripts\Engines\AURORA-SmartEngine.ps1"            = "智能诊断引擎"
        "Data\AURORA-TechData.json"              = "技术知识库（诊断规则）"
        
        # 进度管理系统（会话持久化与断点续传）(Phase 7: moved to Session/)
        "Scripts\Session\AURORA-ProgressManager.ps1"        = "进度管理器核心模块"
        "Scripts\Session\AURORA-ProgressManager-Integration.ps1" = "统一进度保存集成模块 (CHS/ENG)"
    }

    # 可选文件列表（警告而非错误）
    $OptionalFiles = @{
        "GAURORA.CHK.ENC"                  = "完整性验证文件（EXE 启动用）"
        "Resources\CascadiaMono.ttf"                  = "现代等宽字体文件（美化界面）"
        "version.txt"                          = "版本信息文件"
    }

    # 检测系统语言用于提示
    $UseChineseUI = $false
    try {
        $uiCulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture.Name
        if ($uiCulture -like "zh*") {
            $UseChineseUI = $true
        }
    } catch {
        Write-Warning "Non-critical operation failed: $($_.Exception.Message)"
        Write-Debug "Stack: $($_.ScriptStackTrace)"
    }

    $missingRequired = @()
    $missingOptional = @()
    $missingRequiredDesc = @()
    $missingOptionalDesc = @()

    # 检测必需文件（从根目录查找）
    foreach ($file in $RequiredFiles.Keys) {
        $filePath = Join-Path $rootDir $file
        if (-not (Test-Path $filePath)) {
            $missingRequired += $file
            $missingRequiredDesc += "$file  ($($RequiredFiles[$file]))"
        }
    }

    # 检测可选文件（从根目录查找）
    foreach ($file in $OptionalFiles.Keys) {
        $filePath = Join-Path $rootDir $file
        if (-not (Test-Path $filePath)) {
            $missingOptional += $file
            $missingOptionalDesc += "$file  ($($OptionalFiles[$file]))"
        }
    }

    # 返回检测是否有缺失
    if ($missingRequired.Count -gt 0) {
        if ($UseChineseUI) {
            $msg = "❌ 缺少必需文件！`n`n请确保以下文件与启动器在同一目录：`n`n"
            foreach ($item in $missingRequiredDesc) {
                $msg += "• $item`n"
            }
            if ($missingOptional.Count -gt 0) {
                $msg += "`n⚠️ 另外缺少可选文件（功能受限）：`n"
                foreach ($item in $missingOptionalDesc) {
                    $msg += "• $item`n"
                }
            }
            $result = [System.Windows.Forms.MessageBox]::Show(
                $msg,
                "AURORA 启动错误 - 目录完整性检测",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        } else {
            $msg = "❌ Missing required files!`n`nPlease ensure the following files are in the same directory as the launcher:`n`n"
            foreach ($item in $missingRequiredDesc) {
                $msg += "• $item`n"
            }
            if ($missingOptional.Count -gt 0) {
                $msg += "`n⚠️ Also missing optional files (features limited):`n"
                foreach ($item in $missingOptionalDesc) {
                    $msg += "• $item`n"
                }
            }
            $result = [System.Windows.Forms.MessageBox]::Show(
                $msg,
                "AURORA Startup Error - Directory Integrity Check",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
        return $false
    }

    # 可选文件警告（仅在 ShowWarning 时显示）
    if ($ShowWarning -and $missingOptional.Count -gt 0) {
        if ($UseChineseUI) {
            $msg = "⚠️ 缺少可选文件，部分功能可能受限：`n`n"
            foreach ($item in $missingOptionalDesc) {
                $msg += "• $item`n"
            }
            $msg += "`n是否继续启动？"
            $result = [System.Windows.Forms.MessageBox]::Show(
                $msg,
                "AURORA 启动警告",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                return $false
            }
        } else {
            $msg = "⚠️ Missing optional files, some features may be limited:`n`n"
            foreach ($item in $missingOptionalDesc) {
                $msg += "• $item`n"
            }
            $msg += "`nContinue startup?"
            $result = [System.Windows.Forms.MessageBox]::Show(
                $msg,
                "AURORA Startup Warning",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                return $false
            }
        }
    }

    return $true
}

# 注意：本文件作为脚本使用（通过 . 操作符导入），不需要 Export-ModuleMember
# 所有函数已声明为 global 作用域，可直接访问
