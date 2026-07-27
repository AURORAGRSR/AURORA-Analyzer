<#
.SYNOPSIS
    AURORA 启动画面
.DESCRIPTION
    启动画面（Splash Screen）：420x190，使用 StarfieldPanel 背景
.NOTES
    版本：V1.5.29.1Release | 构建时间：2026.07.27
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>
# ====== 启动画面（Splash Screen）：420x190，使用 StarfieldPanel 背景 ======
$splash = New-Object System.Windows.Forms.Form
$splash.Text = ""
$splash.ClientSize = New-Object System.Drawing.Size(420, 190)
$splash.StartPosition = "Manual"
$splash.FormBorderStyle = 'None'          # 无边框
$splash.ShowInTaskbar = $false
$splash.TopMost = $true
$splash.Opacity = 0                      # 初始完全透明
$splash.BackColor = [System.Drawing.Color]::Black 

# === 使用 StarfieldPanel 作为背景 ===
$starfieldBg = New-Object StarfieldPanel
$starfieldBg.Dock = "Fill"
$starfieldBg.SendToBack()  # 确保在最底层
$splash.Controls.Add($starfieldBg)


# Logo 标签 —— 直接加到 StarfieldPanel
$logoLabel = New-Object System.Windows.Forms.Label
$logoLabel.Text = "AURORA`nAnalyzer-V / RS"
$logoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$logoLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$logoLabel.Location = New-Object System.Drawing.Point(50, 30)  # X=50, Y=30
$logoLabel.Size = New-Object System.Drawing.Size(180, 50)
$logoLabel.AutoSize = $false
$logoLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$logoLabel.BackColor = [System.Drawing.Color]::Transparent
$starfieldBg.Controls.Add($logoLabel)


# 进度条
$progressBar = CreateAuroraProgressBar
$progressBar.Location = New-Object System.Drawing.Point(60, 120)  # 原来是 90，现在下移
$starfieldBg.Controls.Add($progressBar)

# 百分比标签
$percentLabel = New-Object System.Windows.Forms.Label
$percentLabel.Text = "0%"
$percentLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$percentLabel.ForeColor = [System.Drawing.Color]::FromArgb(240, 250, 255)
$percentLabel.Location = New-Object System.Drawing.Point(60, 140)  # Y=140
$percentLabel.Size = New-Object System.Drawing.Size(300, 20)
$percentLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$percentLabel.AutoSize = $false
$percentLabel.BackColor = [System.Drawing.Color]::Transparent
$starfieldBg.Controls.Add($percentLabel)

# ====== 新增：硬件性能评级指示器 (Splash Screen 左下角) ======
$tierLabel = New-Object System.Windows.Forms.Label
$tierLabel.AutoSize = $true
$tierLabel.Location = New-Object System.Drawing.Point(8, 168) # 左下角精确定位
$tierLabel.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
$tierLabel.BackColor = [System.Drawing.Color]::Transparent

# 根据探针评估的等级，动态赋予赛博朋克风格的配色和标签
switch ($global:AuroraPerfTier) {
    "Eco" {
        $tierLabel.Text = "[SYS: ECO-MODE]"
        $tierLabel.ForeColor = [System.Drawing.Color]::FromArgb(155, 155, 155) # 节能灰：低调降噪
    }
    "Balanced" {
        $tierLabel.Text = "[SYS: BALANCED]"
        $tierLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255) # 极光蓝：健康平稳
    }
    "Performance" {
        $tierLabel.Text = "[SYS: PERFORMANCE]"
        $tierLabel.ForeColor = [System.Drawing.Color]::FromArgb(109, 249, 75)  # 极光绿：AURORA 标志性高能状态
    }
    "Extreme" {
        $tierLabel.Text = "[SYS: EXTREME]"
        $tierLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 180, 75)  # 超载金：算力溢出
    }
}
$starfieldBg.Controls.Add($tierLabel)

# ====== 性能指示器（静态显示）======
$tierLabel.Location = New-Object System.Drawing.Point(8, 168) # 直接在目标位置

# === 【V13.8】动态状态消息列表 ===
$dynamicMessages = @(
    "正在检测-运行环境权限...",
    "正在验证 AURORA 运行时数字签名完整性...",
    "正在注册高 DPI 视觉清单...",
    "正在初始化 AURORA RenderCore V2.1...",
    "正在激活 AURORA-GFX StarfieldPanel...",
    "正在加载 AURORA-UX TechButton 交互模组...",
    "正在加载 AURORA-Logic Analyzer 日志模块...",
    "正在执行上下文安全校验...",
    "初始化完成！正在启动主界面..."
)
$currentMessageIndex = 0
$totalMessages = $dynamicMessages.Count

# 显示 Splash 并强制完成首次渲染
$splash.Show()
[System.Windows.Forms.Application]::DoEvents()

# === 【V14.3】新增：初始静默期（确保第一条消息可见）===
Start-Sleep -Milliseconds 400
[System.Windows.Forms.Application]::DoEvents()
# ==========================================================

# === 【V7.10】超慢速 iOS 弹入动画（仪式感级，比 V7.9 慢 45%）===
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$baseW, $baseH = 420, 190
$startScale = 1.10  # 起始放大 10%
$targetScale = 1.00 # 目标正常尺寸

# 初始透明大窗口
$splash.Size = New-Object System.Drawing.Size([int]($baseW * $startScale), [int]($baseH * $startScale))
$splash.Opacity = 0
$x = [Math]::Max(0, ($wa.Width - $splash.Width) / 2)
$y = [Math]::Max(0, ($wa.Height - $splash.Height) / 2)
$splash.Location = New-Object System.Drawing.Point($x, $y)
$splash.Visible = $true

# === V2.0 动态时长调整：根据性能等级自动缩放 ===
$perfMultiplier = 1.0
try {
    $perfTier = [AuroraRenderEngine]::CurrentTier
    switch ($perfTier) {
        'Eco'        { $perfMultiplier = 1.5 }
        'Balanced'   { $perfMultiplier = 1.0 }
        'Performance' { $perfMultiplier = 0.8 }
        'Extreme'    { $perfMultiplier = 0.6 }
    }
} catch { Write-AuroraLog "性能等级检测失败，使用默认值: $($_.Exception.Message)" -Level "Warning" }

# 动画参数：总时长 1600ms（更柔和的进入，根据性能等级动态调整）
$durationMs = [Math]::Round(1600 * $perfMultiplier)
$stiffness = 32.0   # 弹簧刚度
$damping = 6.5      # 阻尼系数
$frameIntervalMs = 12 # 高帧率（≈83 FPS）

# 弹簧物理预计算
$k = $stiffness
$c = $damping / 2
$omega = [Math]::Sqrt($k)
$zeta = $c / $omega
$hasOvershoot = $zeta -lt 1

# ====== 关键优化：使用高精度计时器提升动画流畅度 ======
$sw = New-Object System.Diagnostics.Stopwatch
$sw.Start()
$lastFrameTime = 0

while ($true) {
    # 🔐 检查 splash 屏是否已关闭
    if (-not $splash -or $splash.IsDisposed) { break }
    
    $elapsedMs = $sw.ElapsedMilliseconds
    if ($elapsedMs -ge $durationMs) { break }

    # 帧率控制：确保每帧间隔至少 frameIntervalMs
    if ($elapsedMs - $lastFrameTime -lt $frameIntervalMs) {
        Start-Sleep -Milliseconds 1
        continue
    }
    $lastFrameTime = $elapsedMs

    $t = [Math]::Min(1.0, $elapsedMs / $durationMs)
    $time = $t * 2.0 # 时间拉伸，增强慢动作效果

    # 淡入：easeOutQuint（结尾极度柔和）
    $opacityEase = 1 - [Math]::Pow(1 - $t, 5)
    $splash.Opacity = [Math]::Min(1.0, $opacityEase)

    # 弹簧缩放
    if ($t -eq 0) {
        $scale = $startScale
    }
    else {
        if ($hasOvershoot) {
            $omega_d = $omega * [Math]::Sqrt(1 - $zeta * $zeta)
            $decay = [Math]::Exp(-$zeta * $omega * $time)
            $oscillate = [Math]::Cos($omega_d * $time) + ($zeta / [Math]::Sqrt(1 - $zeta * $zeta)) * [Math]::Sin($omega_d * $time)
            $progress = 1 - $decay * $oscillate
        }
        else {
            $progress = 1 - [Math]::Exp(-$omega * $time)
        }
        $scale = $startScale + ($targetScale - $startScale) * $progress
    }

    # 限制缩放范围（允许轻微 undershoot 至 0.96x）
    $scale = [Math]::Max(0.96, [Math]::Min(1.12, $scale))

    # 重新居中
    $newW = [int]($baseW * $scale)
    $newH = [int]($baseH * $scale)
    $x = [Math]::Max(0, ($wa.Width - $newW) / 2)
    $y = [Math]::Max(0, ($wa.Height - $newH) / 2)
    $splash.Size = New-Object System.Drawing.Size($newW, $newH)
    $splash.Location = New-Object System.Drawing.Point($x, $y)

    [System.Windows.Forms.Application]::DoEvents()
}
$sw.Stop()

# 最终精准对齐（消除浮点误差）
if ($splash -and -not $splash.IsDisposed) {
    $splash.Size = New-Object System.Drawing.Size($baseW, $baseH)
    $x = [Math]::Max(0, ($wa.Width - $baseW) / 2)
    $y = [Math]::Max(0, ($wa.Height - $baseH) / 2)
    $splash.Location = New-Object System.Drawing.Point($x, $y)
    $splash.Opacity = 1.0
}

# ====== 关键优化：等待弹入动画完全稳定后再进入下一阶段 ======
# 弹簧动画可能有轻微余震，等待 100ms 确保视觉稳定
for ($i = 0; $i -lt 10; $i++) {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 10
}

# === 模拟加载进度（60FPS，精确 15 秒）===
# ===================================================================


# === 【V13.6】模拟加载进度 + 动态状态提示 (优化版) ===
# ===================================================================
$targetDurationMs = [Math]::Round(15000 * $perfMultiplier)  # 目标总时长：根据性能等级动态调整
$frameIntervalMs = 16.67  # 60FPS = 1000ms / 60 ≈ 16.67ms

# === 关键修改 1: 在循环开始前，立即显示第一条消息 ===
Update-StarfieldStatusText -Panel $starfieldBg -NewText $dynamicMessages[0]
$currentMessageIndex = 0

# 使用高精度计时器精确控制帧率
$sw = New-Object System.Diagnostics.Stopwatch
$sw.Start()
$lastFrameTime = 0

# 计算消息切换的时间间隔
$remainingMessages = $totalMessages - 1
$msPerMessage = if ($remainingMessages -gt 0) { $targetDurationMs / $remainingMessages } else { $targetDurationMs }

while ($true) {
    $elapsedMs = $sw.ElapsedMilliseconds
    if ($elapsedMs -ge $targetDurationMs) { break }
    
    # 帧率控制：确保每帧间隔至少 frameIntervalMs
    $timeSinceLastFrame = $elapsedMs - $lastFrameTime
    if ($timeSinceLastFrame -lt $frameIntervalMs) {
        $sleepMs = [Math]::Max(1, [Math]::Floor($frameIntervalMs - $timeSinceLastFrame))
        Start-Sleep -Milliseconds $sleepMs
        continue
    }
    $lastFrameTime = $elapsedMs
    
    # --- 更新进度条 ---
    $t = $elapsedMs / $targetDurationMs
    $progress = 100 * (1 - [Math]::Pow(1 - $t, 2.5))
    $clamped = [Math]::Min(100.0, $progress)
    try {
        $progressBar.Value = $clamped
        $percentLabel.Text = "{0:F2}%" -f $clamped
    }
    catch { Write-AuroraLog "进度条更新失败: $($_.Exception.Message)" -Level "Warning" }

    # --- 【V13.6】更新动态状态消息 (基于时间) ---
    if ($remainingMessages -gt 0) {
        $targetMessageIndex = [Math]::Min(
            $totalMessages - 1,
            [Math]::Floor($elapsedMs / $msPerMessage)
        )
        
        if ($targetMessageIndex -ne $currentMessageIndex) {
            $currentMessageIndex = $targetMessageIndex
            Update-StarfieldStatusText -Panel $starfieldBg -NewText $dynamicMessages[$currentMessageIndex]
        }
    }

    [System.Windows.Forms.Application]::DoEvents()
}
$sw.Stop()

# 完成加载
$progressBar.Value = 100
$percentLabel.Text = "100.00%"
Start-Sleep -Milliseconds 100

# ===================================================================
# === 【UWP 风格退出动画】轻微放大 + 缓动淡出（更柔和，800ms）===
# ===================================================================
$durationMs = [Math]::Round(800 * $perfMultiplier)
$endScale = 1.15
$frameIntervalMs = 10

# ====== 关键优化：使用高精度计时器提升动画流畅度 ======
$sw = New-Object System.Diagnostics.Stopwatch
$sw.Start()
$lastFrameTime = 0

while ($true) {
    $elapsedMs = $sw.ElapsedMilliseconds
    if ($elapsedMs -ge $durationMs) { break }

    # 帧率控制：确保每帧间隔至少 frameIntervalMs
    if ($elapsedMs - $lastFrameTime -lt $frameIntervalMs) {
        Start-Sleep -Milliseconds 1
        continue
    }
    $lastFrameTime = $elapsedMs

    $t = [Math]::Min(1.0, $elapsedMs / $durationMs)

    # 淡出：easeOutCubic
    $opacity = 1 - [Math]::Pow(1 - $t, 3)
    $splash.Opacity = 1.0 - $opacity

    # 放大：easeOutQuad
    $scaleProgress = 1 - [Math]::Pow(1 - $t, 2)
    $scale = 1.0 + ($endScale - 1.0) * $scaleProgress

    # 居中定位
    $newW = [int]($baseW * $scale)
    $newH = [int]($baseH * $scale)
    $x = [Math]::Max(0, ($wa.Width - $newW) / 2)
    $y = [Math]::Max(0, ($wa.Height - $newH) / 2)
    $splash.Size = New-Object System.Drawing.Size($newW, $newH)
    $splash.Location = New-Object System.Drawing.Point($x, $y)

    [System.Windows.Forms.Application]::DoEvents()
}
$sw.Stop()

# ====== 关键优化：确保退出动画完全完成后再清理 ======
# 等待 150ms 确保动画完全结束，避免视觉残留
for ($i = 0; $i -lt 15; $i++) {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 10
}
