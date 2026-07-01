<#
.SYNOPSIS
    AURORA 动画引擎
.DESCRIPTION
    UWP 动画辅助函数 - 完整稳定性修复
    包含控件状态保存和恢复系统
.NOTES
    版本：V1.4.27.0Release | 构建时间：2026.07.01
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>
# ===================================================================
# === 【完美版】UWP 动画辅助函数 - 完整稳定性修复 ===
# ===================================================================

# 全局动画状态管理 - 简化版以提高稳定性
$Global:AnimationTimers = @()
$Global:ControlStates = @{}  # 存储控件原始状态
$Global:IsViewTransitioning = $false  # 标记是否正在进行视图切换

# ===================================================================
# === 控件状态保存和恢复系统 ===
# ===================================================================
function global:Save-ControlState {
    [CmdletBinding()]
    param([System.Windows.Forms.Control]$Control)
    
    # 安全检查：确保控件不为 null
    if (-not $Control) { return }
    
    try {
        $stateKey = $Control.GetHashCode().ToString()
        $Global:ControlStates[$stateKey] = @{
            Location = $Control.Location
            Size = $Control.Size
            ForeColor = $Control.ForeColor
            Visible = $Control.Visible
        }
    } catch { Write-AuroraLog "控件状态保存失败: $($_.Exception.Message)" -Level "Warning" }
}

function global:Restore-ControlState {
    [CmdletBinding()]
    param([System.Windows.Forms.Control]$Control)
    
    # 安全检查：确保控件不为 null
    if (-not $Control) { return }
    
    try {
        $stateKey = $Control.GetHashCode().ToString()
        if ($Global:ControlStates.ContainsKey($stateKey)) {
            $state = $Global:ControlStates[$stateKey]
            $Control.Location = $state.Location
            $Control.Size = $state.Size
            $Control.ForeColor = $state.ForeColor
            $Control.Visible = $state.Visible
        }
    } catch { Write-AuroraLog "控件状态恢复失败: $($_.Exception.Message)" -Level "Warning" }
}

function global:Stop-AllAnimations {
    [CmdletBinding()]
    param(
        [switch]$RestoreState,
        [System.Windows.Forms.Control]$Control
    )
    
    try {
        # 复制数组以安全遍历
        $timersCopy = @($Global:AnimationTimers)
        $newTimers = @()
        
        foreach ($timer in $timersCopy) {
            try {
                if ($timer -and $timer.Tag -and $timer.Tag.Control) {
                    # 如果指定了 Control，只停止该控件的动画
                    if ($PSBoundParameters.ContainsKey('Control') -and $timer.Tag.Control -ne $Control) {
                        $newTimers += $timer
                        continue
                    }
                    
                    if ($RestoreState) {
                        Restore-ControlState -Control $timer.Tag.Control
                    }
                    $timer.Stop()
                    $timer.Dispose()
                }
            } catch { Write-AuroraLog "动画定时器清理失败: $($_.Exception.Message)" -Level "Warning" }
        }
        
        # 如果指定了 Control，更新数组保留其他动画
        if ($PSBoundParameters.ContainsKey('Control')) {
            $Global:AnimationTimers = $newTimers
        } else {
            # 否则清空数组
            $Global:AnimationTimers = @()
        }
    } catch { Write-AuroraLog "动画定时器数组清理失败: $($_.Exception.Message)" -Level "Warning" }
}


function global:Start-UwpEnterAnimation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Control,
        [Parameter(Mandatory)][System.Drawing.Point]$TargetLocation,
        [System.Windows.Forms.Form]$ParentForm,
        [int]$DurationMs = 450,
        [int]$OffsetY = 100,
        [int]$DelayMs = 0,
        [float]$StartScale = 0
    )

    # 保存完整原始状态（关键修复）
    Save-ControlState -Control $Control

    $originalLocation = $Control.Location  # 新增：保存原始位置
    $originalSize = $Control.Size
    $originalForeColor = $Control.ForeColor

    # 安全计算初始尺寸，防止尺寸为 0 导致 GDI 崩溃
    $startWidth = [int]($originalSize.Width * $StartScale)
    $startHeight = [int]($originalSize.Height * $StartScale)
    if ($startWidth -lt 1) { $startWidth = 1 }
    if ($startHeight -lt 1) { $startHeight = 1 }
    $startSize = New-Object System.Drawing.Size($startWidth, $startHeight)

    $targetCenterX = $TargetLocation.X + ($originalSize.Width / 2)
    $startYCenter = $TargetLocation.Y + $OffsetY + ($startHeight / 2)
    $startX = [int]($targetCenterX - ($startWidth / 2))
    $startY = [int]($startYCenter - ($startHeight / 2))
    
    $Control.Location = New-Object System.Drawing.Point($startX, $startY)
    $Control.Size = $startSize
    # 特殊处理 UWPText 控件 - 使用自带动画状态
    if ($Control.GetType().Name -eq 'UWPText') {
        $Control.SetEnterAnimationState(0, 0, $StartScale, 0)
    } else {
        $Control.ForeColor = [System.Drawing.Color]::FromArgb(0, $originalForeColor.R, $originalForeColor.G, $originalForeColor.B)
    }
    
    # 核心修复：先隐藏控件！完全杜绝原地的"第一帧闪烁"
    $Control.Visible = $false

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16

    $timer.Tag = @{
        Control = $Control; TargetLocation = $TargetLocation; StartLocation = $Control.Location
        OriginalLocation = $originalLocation; OriginalSize = $originalSize; OriginalForeColor = $originalForeColor
        StartScale = $StartScale; DurationMs = $DurationMs; DelayMs = $DelayMs
        StartTime = [DateTime]::Now.AddMilliseconds($DelayMs); HasStarted = $false; HasMadeVisible = $false
    }

    # 核心修复：直接内联事件处理程序，避免闭包问题！
    $timer.add_Tick({
        # 显式绑定 Timer 到本地变量，防止上下文丢失
        $currentTimer = $this
        $data = $currentTimer.Tag
        $now = [DateTime]::Now

        if (-not $data.HasStarted) {
            if ($now -lt $data.StartTime) { return }
            $data.HasStarted = $true
            $data.RealStartTime = $now
        }

        # 核心修复：动画激活的瞬间才让控件显示，完美衔接
        if (-not $data.HasMadeVisible) {
            $data.Control.Visible = $true
            $data.HasMadeVisible = $true
        }

        $elapsed = ($now - $data.RealStartTime).TotalMilliseconds
        $progress = [Math]::Min(1.0, $elapsed / $data.DurationMs)

        if ($progress -ge 1.0) {
            $data.Control.Location = $data.TargetLocation
            $data.Control.Size = $data.OriginalSize
            # 特殊处理 UWPText 控件
            if ($data.Control.GetType().Name -eq 'UWPText') {
                $data.Control.ResetEnterAnimationState()
            } else {
                $data.Control.ForeColor = $data.OriginalForeColor
            }
            $currentTimer.Stop()
            $currentTimer.Dispose()
            return
        }

        $eased = 1 - [Math]::Pow(1 - $progress, 4)

        $currentY = $data.StartLocation.Y + (($data.TargetLocation.Y - $data.StartLocation.Y) * $eased)
        $scale = $data.StartScale + ((1.0 - $data.StartScale) * $eased)
        
        $newWidth = [int]($data.OriginalSize.Width * $scale)
        $newHeight = [int]($data.OriginalSize.Height * $scale)
        if ($newWidth -lt 1) { $newWidth = 1 }
        if ($newHeight -lt 1) { $newHeight = 1 }

        $targetCenterX = $data.TargetLocation.X + ($data.OriginalSize.Width / 2)
        $dynamicCenterY = $currentY + ($newHeight / 2)

        $data.Control.Location = New-Object System.Drawing.Point([int]($targetCenterX - ($newWidth / 2)), [int]($dynamicCenterY - ($newHeight / 2)))
        $data.Control.Size = New-Object System.Drawing.Size($newWidth, $newHeight)

        $alpha = [int][Math]::Min(255, 255 * $eased)
        # 特殊处理 UWPText 控件 - 使用自带动画状态
        if ($data.Control.GetType().Name -eq 'UWPText') {
            $data.Control.SetEnterAnimationState(0, $currentY - $data.TargetLocation.Y, $scale, $alpha)
        } else {
            $data.Control.ForeColor = [System.Drawing.Color]::FromArgb($alpha, $data.OriginalForeColor.R, $data.OriginalForeColor.G, $data.OriginalForeColor.B)
        }
    }.GetNewClosure())
    $timer.Start()
    
    # 添加到全局动画列表
    $Global:AnimationTimers += $timer
}

# ===================================================================
# === UWP 输入框底边丝滑动画 - 从中心向两侧展开/收起 ===
# ===================================================================
function global:Start-UnderlineAnimation {
    [CmdletBinding()]
    param(
        [System.Windows.Forms.Panel]$Panel,
        [bool]$Expand
    )
    # 停止之前可能正在运行的动画
    if ($Panel.Tag -ne $null) {
        $Panel.Tag.Stop()
        $Panel.Tag.Dispose()
    }
    
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16
    $Panel.Tag = $timer
    
    # 目标宽度和中心点 (原宽度480，X坐标50。中心点=290)
    $targetWidth = if ($Expand) { 480 } else { 0 }
    $centerX = 290 
    
    # ====== 核心修复：添加 .GetNewClosure() 以捕获 $Panel 等局部变量 ======
    $timer.Add_Tick({
        $currentW = $Panel.Width
        if ([Math]::Abs($currentW - $targetWidth) -lt 2) {
            $Panel.Width = $targetWidth
            $Panel.Left = [int]($centerX - ($targetWidth / 2))
            $this.Stop()
            $this.Dispose()
            return
        }
        
        $step = ($targetWidth - $currentW) * 0.25
        if ($step -gt 0 -and $step -lt 1) { $step = 1 }
        if ($step -lt 0 -and $step -gt -1) { $step = -1 }
        
        $newW = [int]($currentW + $step)
        $Panel.Width = $newW
        $Panel.Left = [int]($centerX - ($newW / 2))
    }.GetNewClosure())
    $timer.Start()
}

# ===================================================================
# === 【V15.1 优化版】UWP 电影级退出动画 - 弹性回拉 + 加速飞散 + 层次延迟 ====
# ===================================================================
function global:Start-UwpExitAnimation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Control,
        [int]$DurationMs = 350,
        [int]$OffsetY = 40,
        [float]$EndScale = 0.80,
        [int]$StaggerDelay = 0,
        [bool]$IsButton = $false
    )

    # 保存完整原始状态（关键修复）
    Save-ControlState -Control $Control

    # 核心修复：确保控件在开始退出动画时是可见的
    $Control.Visible = $true

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16
    $timer.Tag = @{
        Control = $Control; OriginalLocation = $Control.Location; OriginalSize = $Control.Size
        OriginalForeColor = $Control.ForeColor; OriginalVisible = $Control.Visible
        DurationMs = $DurationMs; OffsetY = $OffsetY; EndScale = $EndScale
        StartTime = [DateTime]::Now.AddMilliseconds($StaggerDelay); HasStarted = $false
    }

    # 核心修复：直接内联事件处理程序，避免闭包问题！
    $timer.add_Tick({
        # 显式绑定 Timer 到本地变量，防止上下文丢失
        $currentTimer = $this
        $data = $currentTimer.Tag
        $now = [DateTime]::Now

        if (-not $data.HasStarted) {
            if ($now -lt $data.StartTime) { return }
            $data.HasStarted = $true
        }

        $elapsed = ($now - $data.StartTime).TotalMilliseconds
        $progress = [Math]::Min(1.0, $elapsed / $data.DurationMs)

        if ($progress -ge 1.0) {
            $data.Control.Visible = $false
            $data.Control.Size = $data.OriginalSize 
            $data.Control.Location = $data.OriginalLocation
            $data.Control.ForeColor = $data.OriginalForeColor
            $currentTimer.Stop()
            $currentTimer.Dispose()
            return
        }

        $easedProgress = if ($progress -lt 0.1) { -0.05 * ($progress * 10) } else { [Math]::Pow(($progress - 0.1) / 0.9, 3) }
        $scaleFactor = if ($progress -lt 0.1) { 1.0 + (0.02 * ($progress * 10)) } else { 1.0 - ((1.0 - $data.EndScale) * [Math]::Pow(($progress - 0.1) / 0.9, 2.5)) }

        $currentY = $data.OriginalLocation.Y - ($easedProgress * $data.OffsetY)
        $newWidth = [int]($data.OriginalSize.Width * $scaleFactor)
        $newHeight = [int]($data.OriginalSize.Height * $scaleFactor)

        $centerX = $data.OriginalLocation.X + ($data.OriginalSize.Width / 2)
        
        $data.Control.Location = New-Object System.Drawing.Point([int]($centerX - ($newWidth / 2)), [int]($currentY - (($newHeight - $data.OriginalSize.Height) / 2)))
        $data.Control.Size = New-Object System.Drawing.Size($newWidth, $newHeight)

        if ($progress -gt 0.7) {
            $fadeProgress = ($progress - 0.7) / 0.3
            $alpha = [int][Math]::Max(0, 255 * (1.0 - $fadeProgress))
            $data.Control.ForeColor = [System.Drawing.Color]::FromArgb($alpha, $data.OriginalForeColor.R, $data.OriginalForeColor.G, $data.OriginalForeColor.B)
        }
    }.GetNewClosure())
    $timer.Start()
    
    # 添加到全局动画列表 - 使用安全的方法
    $Global:AnimationTimers += $timer
}

# ===================================================================
# === 【主窗口动效优化】添加窗口级淡入和缩放动画 ===
# ===================================================================
function global:Start-MainWindowAnimation {
    [CmdletBinding()]
    param([System.Windows.Forms.Form]$Form)
    
    $Form.Opacity = 0
    $originalSize = $Form.Size
    $Form.Size = New-Object System.Drawing.Size([int]($originalSize.Width * 1.1), [int]($originalSize.Height * 1.1))
    
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $x = [Math]::Max(0, ($wa.Width - $Form.Width) / 2)
    $y = [Math]::Max(0, ($wa.Height - $Form.Height) / 2)
    $Form.Location = New-Object System.Drawing.Point($x, $y)
    
    $Form.Visible = $true
    
    # ====== 核心：使用 Timer 替代 while 循环 ======
    # 先找到 StarfieldPanel 并锁定
    $bgPanel = $null
    foreach ($ctrl in $Form.Controls) {
        if ($ctrl -is [StarfieldPanel]) {
            $bgPanel = $ctrl
            $bgPanel.IsWindowAnimating = $true
            break
        }
    }
    
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16 # ~60FPS
    
    $timer.Tag = @{
        Form = $Form; OriginalSize = $originalSize; WorkArea = $wa; BgPanel = $bgPanel
        StartTime = [DateTime]::Now; DurationMs = 600
    }
    
    # 核心修复：直接内联事件处理程序，避免闭包问题！
    $timer.Add_Tick({
        $data = $this.Tag
        if ($null -eq $data.Form -or $data.Form.IsDisposed) {
            $this.Stop(); return
        }

        $elapsedMs = ([DateTime]::Now - $data.StartTime).TotalMilliseconds
        $t = [Math]::Min(1.0, $elapsedMs / $data.DurationMs)
        
        # 淡入：easeOutCubic
        $data.Form.Opacity = 1 - [Math]::Pow(1 - $t, 3)
        
        # 缩放：easeOutBack（带回弹效果）
        $scaleProgress = 1 - [Math]::Pow(1 - $t, 3) * (1 + 3 * $t)
        $scale = 1.1 - (0.1 * $scaleProgress)
        
        $newW = [int]($data.OriginalSize.Width * $scale)
        $newH = [int]($data.OriginalSize.Height * $scale)
        $newX = [Math]::Max(0, ($data.WorkArea.Width - $newW) / 2)
        $newY = [Math]::Max(0, ($data.WorkArea.Height - $newH) / 2)
        
        $data.Form.Size = New-Object System.Drawing.Size($newW, $newH)
        $data.Form.Location = New-Object System.Drawing.Point($newX, $newY)
        
        if ($t -ge 1.0) {
            $data.Form.Opacity = 1
            $data.Form.Size = $data.OriginalSize
            $data.Form.Location = New-Object System.Drawing.Point(
                [Math]::Max(0, ($data.WorkArea.Width - $data.OriginalSize.Width) / 2),
                [Math]::Max(0, ($data.WorkArea.Height - $data.OriginalSize.Height) / 2)
            )
            
            # 恢复星空引擎
            if ($null -ne $data.BgPanel) {
                $data.BgPanel.IsWindowAnimating = $false
                $data.BgPanel.Invalidate()
            }
            
            $this.Stop()
        }
    }.GetNewClosure())
    $timer.Start()
}

# ===================================================================
# === 【主窗口动效优化】添加窗口级退出动画 ===
# ===================================================================
function global:Start-MainWindowExitAnimation {
    [CmdletBinding()]
    param(
        [System.Windows.Forms.Form]$Form,
        [switch]$ExitOnComplete  # 仅在主窗口退出时启用，权限对话框等子窗口不应 Exit 进程
    )
    
    $originalSize = $Form.Size
    $originalLocation = $Form.Location
    
    # 先找到 StarfieldPanel 并锁定
    $bgPanel = $null
    foreach ($ctrl in $Form.Controls) {
        if ($ctrl -is [StarfieldPanel]) {
            $bgPanel = $ctrl
            $bgPanel.IsWindowAnimating = $true
            break
        }
    }
    
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16 # ~60FPS
    
    $timer.Tag = @{
        Form = $Form; OriginalSize = $originalSize; OriginalLocation = $originalLocation
        BgPanel = $bgPanel; StartTime = [DateTime]::Now; DurationMs = 450
        ExitOnComplete = $ExitOnComplete
    }
    
    # 核心修复：直接内联事件处理程序，避免闭包问题！
    $timer.Add_Tick({
        $data = $this.Tag
        if ($null -eq $data.Form -or $data.Form.IsDisposed) {
            $this.Stop(); return
        }

        $elapsedMs = ([DateTime]::Now - $data.StartTime).TotalMilliseconds
        $t = [Math]::Min(1.0, $elapsedMs / $data.DurationMs)
        
        # 淡出：easeInCubic
        $data.Form.Opacity = 1 - [Math]::Pow($t, 3)
        
        # 缩放：easeInCubic（缩小）
        $scale = 1.0 - (0.15 * [Math]::Pow($t, 3))
        
        $newW = [int]($data.OriginalSize.Width * $scale)
        $newH = [int]($data.OriginalSize.Height * $scale)
        
        # 保持中心对齐
        $centerX = $data.OriginalLocation.X + ($data.OriginalSize.Width / 2)
        $centerY = $data.OriginalLocation.Y + ($data.OriginalSize.Height / 2)
        
        $newX = [int]($centerX - ($newW / 2))
        $newY = [int]($centerY - ($newH / 2))
        
        $data.Form.Size = New-Object System.Drawing.Size($newW, $newH)
        $data.Form.Location = New-Object System.Drawing.Point($newX, $newY)
        
        if ($t -ge 1.0) {
            $this.Stop()
            $this.Dispose()
            if ($null -ne $data.Form -and -not $data.Form.IsDisposed) {
                try { $data.Form.Opacity = 0 } catch { Write-AuroraLog "表单退出动画失败: $($_.Exception.Message)" -Level "Warning" }
            }
            # 仅在主窗口退出时终止进程；子窗口（如权限对话框）退场后不应 Exit
            if ($data.ExitOnComplete) {
                [System.Environment]::Exit(0)
            }
        }
    }.GetNewClosure())
    $timer.Start()
}

# 启动主界面
try {
    # ====== 权限检测与提示 ======
    $script:IsAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    
    # 如果不是管理员，显示权限选择对话框
    if (-not $script:IsAdmin) {
        Write-Host "⚠️ 检测到普通用户权限，正在提示用户..." -ForegroundColor Yellow
        
        # 显示权限选择对话框（独立窗口，不需要父窗口）
        $choice = Show-ElevationDialog
        
        if ($choice -eq 'Elevate') {
            Write-Host "️ 用户选择切换到管理员模式，正在请求提权..." -ForegroundColor Cyan
            
            # 请求提权并重启
            if (Restart-WithAdmin) {
                Write-Host "✅ 提权成功，正在重启..." -ForegroundColor Green
                # 等待新进程启动后再退出当前进程
                Start-Sleep -Milliseconds 500
                Invoke-SafeExit -ExitCode 0
            } else {
                Write-Host "⚠️ 提权失败或被取消，将继续以普通用户模式运行" -ForegroundColor Yellow
            }
        } elseif ($choice -eq 'Exit') {
            Write-Host " 用户选择退出程序" -ForegroundColor Yellow
            Invoke-SafeExit -ExitCode 0
        } else {
            Write-Host "ℹ️ 用户选择继续使用普通模式" -ForegroundColor Gray
        }
    } else {
        Write-Host "🛡️ 已管理员权限运行" -ForegroundColor Green
    }
    
    # 继续启动主界面
    ShowMainForm
} catch {
    # 显示错误信息
    [System.Windows.Forms.MessageBox]::Show("发生错误: $($_.Exception.Message)", "错误", "OK", "Error")
    Invoke-SafeExit -ExitCode 1
}
