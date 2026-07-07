<#
.SYNOPSIS
    AURORA 权限选择对话框
.DESCRIPTION
    权限选择二级窗口（复用 PRO 模式视觉和动画）
.NOTES
    版本：V1.4.27.1Release | 构建时间：2026.07.06
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>
# ====== 权限选择二级窗口（复用 PRO 模式视觉和动画） ======
function Show-ElevationDialog {
    # 双语资源
    $resources = @{
        CHS = @{
            Title = "AURORA - 运行模式选择 / Execution Mode Selection"
            Subtitle = "🛡️运行模式选择"
            Info = "检测到当前以普通用户权限运行`n`n请选择您希望使用的运行模式："
            NormalMode = "🟢 普通用户模式（当前）"
            NormalFeatures = "✅ 查看系统日志（System Log）`n✅ 查看应用程序日志（Application Log）`n✅ 性能评估与分析`n✅ 日志导出（CSV/JSON/XML）`n✅ 趋势分析`n✅ 知识库扫描"
            NormalLimited = "⚠️  以下功能将会受限：`n`n  ⚠️  安全日志（Security Log）`n  ⚠️  安装日志（Setup Log）`n  ⚠️  系统修复操作`n  ⚠️  深度智能诊断`n  ⚠️  自主修复建议"
            AdminMode = "🛡️ 管理员模式（推荐）"
            AdminFeatures = "✅ 包含普通模式所有功能`n✅ 完整日志访问（系统/应用/安全/安装）`n✅ 系统修复与优化操作`n✅ 深度智能诊断`n✅ 自主修复建议`n✅ 完整系统健康评估"
            ElevateButton = "🛡️ 切换到管理员模式（推荐）"
            ContinueButton = "继续使用普通模式"
            ExitButton = "退出程序"
            StatusText = "请选择运行模式"
        }
        ENG = @{
            Title = "AURORA - Execution Mode Selection"
            Subtitle = "🛡️  Execution Mode Selection"
            Info = "Running with standard user privileges detected`n`nPlease select your preferred execution mode:"
            NormalMode = "🟢 Standard User Mode (Current)"
            NormalFeatures = "✅ View System Log`n✅ View Application Log`n✅ Performance Assessment & Analysis`n✅ Log Export (CSV/JSON/XML)`n✅ Trend Analysis`n✅ Knowledge Base Scan"
            NormalLimited = "⚠️  Limited Features：`n`n  ⚠️  Security Log`n  ⚠️  Setup Log`n  ⚠️  System Repair Operations`n  ⚠️  Deep Smart Diagnosis`n  ⚠️  Auto-Healing Recommendations"
            AdminMode = "🛡️ Administrator Mode (Recommended)"
            AdminFeatures = "✅ All features in Standard Mode`n✅ Full log access (System/Application/Security/Setup)`n✅ System repair & optimization operations`n✅ Deep smart diagnosis`n✅ Auto-healing recommendations`n✅ Complete system health assessment"
            ElevateButton = "🛡️ Switch to Administrator Mode (Recommended)"
            ContinueButton = "Continue with Standard Mode"
            ExitButton = "Exit Program"
            StatusText = "Please select execution mode"
        }
    }
    
    # 在语言选择之前，使用系统语言作为默认
    $systemLanguage = if ((Get-UICulture).Name -like 'zh*') { 'CHS' } else { 'ENG' }
    $currentLanguage = $systemLanguage  # 使用系统语言作为默认
    $res = $resources[$currentLanguage]
    
    # 创建权限选择窗口（与 PRO 模式相同的尺寸和样式）
    $elevateForm = New-Object System.Windows.Forms.Form
    $elevateForm.Text = $res.Title
    $elevateForm.ClientSize = New-Object System.Drawing.Size(750, 750)  # 与 PRO 窗口相同
    $elevateForm.StartPosition = "CenterScreen"
    $elevateForm.FormBorderStyle = 'None'
    $elevateForm.MaximizeBox = $false
    $elevateForm.MinimizeBox = $false
    $elevateForm.TopMost = $true
    $elevateForm.BackColor = [System.Drawing.Color]::Black
    $elevateForm.ShowInTaskbar = $false
    $elevateForm.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)
    
    # 使用 StarfieldPanel 作为背景（与 PRO 模式一致）
    $elevateBackground = New-Object StarfieldPanel
    $elevateBackground.Dock = "Fill"
    $elevateBackground.TextX = 375
    $elevateBackground.TextY = 685
    $elevateBackground.Enabled = $true
    $elevateBackground.TextAlignment = [System.Drawing.StringAlignment]::Center
    
    # 标题标签（UWP自绘控件）- 走 UWP 飞入动画 + 自动文本切换
    # 无边框拖动支持
    $dragAction = {
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            [Win32Helper]::ReleaseCapture()
            [Win32Helper]::SendMessage($elevateForm.Handle, [Win32Helper]::WM_NCLBUTTONDOWN, [Win32Helper]::HT_CAPTION, 0)
        }
    }
    
    $permTitleLabel = New-Object UWPText
    $permTitleLabel.TextOnly = $res.Subtitle
    $permTitleLabel.Font = Get-EmojiFont -Size 18 -Style ([System.Drawing.FontStyle]::Bold)
    $permTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 255)
    $permTitleLabel.BackColor = [System.Drawing.Color]::Transparent
    $permTitleLabel.Size = New-Object System.Drawing.Size(400, 45)
    $permTitleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $permTitleLabel.TextAlign = [System.Drawing.StringAlignment]::Near
    $permTitleLabel.Add_MouseDown($dragAction)
    
    $permInfoLabel = New-Object System.Windows.Forms.Label
    $permInfoLabel.Text = $res.Info
    $permInfoLabel.Font = Get-EmojiFont -Size 9.5
    $permInfoLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
    $permInfoLabel.BackColor = [System.Drawing.Color]::Transparent
    $permInfoLabel.Size = New-Object System.Drawing.Size(500, 50)
    $permInfoLabel.Location = New-Object System.Drawing.Point(20, 65)
    $permInfoLabel.TextAlign = 'TopLeft'
    
    # 普通模式标题（UWP自绘控件）- 走 UWP 飞入动画 + 自动文本切换
    $normalTitle = New-Object UWPText
    $normalTitle.TextOnly = $res.NormalMode
    $normalTitle.Font = Get-EmojiFont -Size 12 -Style ([System.Drawing.FontStyle]::Bold)
    $normalTitle.ForeColor = [System.Drawing.Color]::FromArgb(100, 255, 150)
    $normalTitle.BackColor = [System.Drawing.Color]::Transparent
    $normalTitle.Size = New-Object System.Drawing.Size(450, 35)
    $normalTitle.Location = New-Object System.Drawing.Point(30, 125)
    $normalTitle.TextAlign = [System.Drawing.StringAlignment]::Near
    $normalTitle.Add_MouseDown($dragAction)
    
    # 分隔线
    $normalSep = New-Object System.Windows.Forms.Label
    $normalSep.BackColor = [System.Drawing.Color]::FromArgb(80, 100, 120)
    $normalSep.AutoSize = $false
    $normalSep.Size = New-Object System.Drawing.Size(690, 1)
    $normalSep.Location = New-Object System.Drawing.Point(30, 160)
    
    # 功能列表（左右两个 AuroraConsoleBox）
    $normalFeatures = New-Object AuroraConsoleBox
    $normalFeatures.Text = $res.NormalFeatures
    $normalFeatures.Size = New-Object System.Drawing.Size(340, 210)
    $normalFeatures.Location = New-Object System.Drawing.Point(25, 165)
    
    $normalLimited = New-Object AuroraConsoleBox
    $normalLimited.Text = $res.NormalLimited
    $normalLimited.Size = New-Object System.Drawing.Size(360, 210)
    $normalLimited.Location = New-Object System.Drawing.Point(365, 165)
    
    # 管理员模式标题（UWP自绘控件）- 走 UWP 飞入动画 + 自动文本切换
    $adminTitle = New-Object UWPText
    $adminTitle.TextOnly = $res.AdminMode
    $adminTitle.Font = Get-EmojiFont -Size 12 -Style ([System.Drawing.FontStyle]::Bold)
    $adminTitle.ForeColor = [System.Drawing.Color]::FromArgb(255, 220, 150)
    $adminTitle.BackColor = [System.Drawing.Color]::Transparent
    $adminTitle.Size = New-Object System.Drawing.Size(450, 35)
    $adminTitle.Location = New-Object System.Drawing.Point(30, 400)
    $adminTitle.TextAlign = [System.Drawing.StringAlignment]::Near
    $adminTitle.Add_MouseDown($dragAction)
    
    # 分隔线
    $adminSep = New-Object System.Windows.Forms.Label
    $adminSep.BackColor = [System.Drawing.Color]::FromArgb(80, 100, 120)
    $adminSep.AutoSize = $false
    $adminSep.Size = New-Object System.Drawing.Size(690, 1)
    $adminSep.Location = New-Object System.Drawing.Point(30, 435)
    
    # 功能列表（单个 AuroraConsoleBox）
    $adminFeatures = New-Object AuroraConsoleBox
    $adminFeatures.Text = $res.AdminFeatures
    $adminFeatures.Size = New-Object System.Drawing.Size(690, 150)
    $adminFeatures.Location = New-Object System.Drawing.Point(30, 440)
    
    # 退出按钮 - 使用 TechButton
    $exitButton = New-Object TechButton
    $exitButton.Text = $res.ExitButton
    $exitButton.SetBounds(20, 621, 230, 48)
    
    # 切换到管理员模式按钮 - 使用 TechButton
    $elevateButton = New-Object TechButton
    $elevateButton.Text = $res.ElevateButton
    $elevateButton.SetBounds(260, 621, 230, 48)
    
    # 继续使用普通模式按钮 - 使用 TechButton
    $continueButton = New-Object TechButton
    $continueButton.Text = $res.ContinueButton
    $continueButton.SetBounds(500, 621, 230, 48)
    
    # 按钮点击事件处理 - 带 UWP 退出动画
    $exitButton.Add_Click({
        try {
            $exitButton.Enabled = $false
            $elevateButton.Enabled = $false
            $continueButton.Enabled = $false
            
            $exitAnimations = @()
            $exitAnimations += Start-UwpExitAnimation -Control $permTitleLabel -DurationMs 300 -OffsetY 30 -StaggerDelay 0
            $exitAnimations += Start-UwpExitAnimation -Control $permInfoLabel -DurationMs 300 -OffsetY 30 -StaggerDelay 30
            $exitAnimations += Start-UwpExitAnimation -Control $normalTitle -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $normalSep -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $normalFeatures -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $normalLimited -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $adminTitle -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $adminSep -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $adminFeatures -DurationMs 300 -OffsetY 40 -StaggerDelay 120
            $exitAnimations += Start-UwpExitAnimation -Control $exitButton -DurationMs 300 -OffsetY 40 -StaggerDelay 150
            $exitAnimations += Start-UwpExitAnimation -Control $elevateButton -DurationMs 300 -OffsetY 40 -StaggerDelay 150
            $exitAnimations += Start-UwpExitAnimation -Control $continueButton -DurationMs 300 -OffsetY 40 -StaggerDelay 180
            
            for ($i = 0; $i -lt 25; $i++) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 10
            }
            
            Start-MainWindowExitAnimation -Form $elevateForm
            
            for ($i = 0; $i -lt 50; $i++) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 10
            }
        } catch { Write-AuroraLog "提权表单动画处理失败: $($_.Exception.Message)" -Level "Warning" }
        $elevateForm.DialogResult = 'Cancel'
        $elevateForm.Close()
    })
    
    # 按钮点击事件处理 - 带 UWP 退出动画
    $elevateButton.Add_Click({
        try {
            $exitButton.Enabled = $false
            $elevateButton.Enabled = $false
            $continueButton.Enabled = $false
            
            $exitAnimations = @()
            $exitAnimations += Start-UwpExitAnimation -Control $permTitleLabel -DurationMs 300 -OffsetY 30 -StaggerDelay 0
            $exitAnimations += Start-UwpExitAnimation -Control $permInfoLabel -DurationMs 300 -OffsetY 30 -StaggerDelay 30
            $exitAnimations += Start-UwpExitAnimation -Control $normalTitle -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $normalSep -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $normalFeatures -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $normalLimited -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $adminTitle -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $adminSep -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $adminFeatures -DurationMs 300 -OffsetY 40 -StaggerDelay 120
            $exitAnimations += Start-UwpExitAnimation -Control $exitButton -DurationMs 300 -OffsetY 40 -StaggerDelay 150
            $exitAnimations += Start-UwpExitAnimation -Control $elevateButton -DurationMs 300 -OffsetY 40 -StaggerDelay 150
            $exitAnimations += Start-UwpExitAnimation -Control $continueButton -DurationMs 300 -OffsetY 40 -StaggerDelay 180
            
            for ($i = 0; $i -lt 25; $i++) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 10
            }
            
            Start-MainWindowExitAnimation -Form $elevateForm
            
            for ($i = 0; $i -lt 50; $i++) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 10
            }
        } catch { Write-AuroraLog "提权表单动画处理失败: $($_.Exception.Message)" -Level "Warning" }
        $elevateForm.DialogResult = 'OK'
        $elevateForm.Close()
    })
    
    $continueButton.Add_Click({
        try {
            $exitButton.Enabled = $false
            $elevateButton.Enabled = $false
            $continueButton.Enabled = $false
            
            $exitAnimations = @()
            $exitAnimations += Start-UwpExitAnimation -Control $permTitleLabel -DurationMs 300 -OffsetY 30 -StaggerDelay 0
            $exitAnimations += Start-UwpExitAnimation -Control $permInfoLabel -DurationMs 300 -OffsetY 30 -StaggerDelay 30
            $exitAnimations += Start-UwpExitAnimation -Control $normalTitle -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $normalSep -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $normalFeatures -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $normalLimited -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $adminTitle -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $adminSep -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $adminFeatures -DurationMs 300 -OffsetY 40 -StaggerDelay 120
            $exitAnimations += Start-UwpExitAnimation -Control $exitButton -DurationMs 300 -OffsetY 40 -StaggerDelay 150
            $exitAnimations += Start-UwpExitAnimation -Control $elevateButton -DurationMs 300 -OffsetY 40 -StaggerDelay 150
            $exitAnimations += Start-UwpExitAnimation -Control $continueButton -DurationMs 300 -OffsetY 40 -StaggerDelay 180
            
            for ($i = 0; $i -lt 25; $i++) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 10
            }
            
            Start-MainWindowExitAnimation -Form $elevateForm
            
            for ($i = 0; $i -lt 50; $i++) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 10
            }
        } catch { Write-AuroraLog "提权表单动画处理失败: $($_.Exception.Message)" -Level "Warning" }
        $elevateForm.DialogResult = 'Abort'
        $elevateForm.Close()
    })
    
    # 添加控件到窗体（直接添加到 StarfieldPanel）
    $elevateForm.Controls.Add($elevateBackground)
    $elevateBackground.Controls.Add($permTitleLabel)
    $elevateBackground.Controls.Add($permInfoLabel)
    $elevateBackground.Controls.Add($normalTitle)
    $elevateBackground.Controls.Add($normalSep)
    $elevateBackground.Controls.Add($normalFeatures)
    $elevateBackground.Controls.Add($normalLimited)
    $elevateBackground.Controls.Add($adminTitle)
    $elevateBackground.Controls.Add($adminSep)
    $elevateBackground.Controls.Add($adminFeatures)
    $elevateBackground.Controls.Add($exitButton)
    $elevateBackground.Controls.Add($elevateButton)
    $elevateBackground.Controls.Add($continueButton)
    
    $elevateBackground.Add_MouseDown($dragAction)
    $permTitleLabel.Add_MouseDown($dragAction)
    $permInfoLabel.Add_MouseDown($dragAction)
    $normalTitle.Add_MouseDown($dragAction)
    $normalFeatures.Add_MouseDown($dragAction)
    $normalLimited.Add_MouseDown($dragAction)
    $adminTitle.Add_MouseDown($dragAction)
    $adminFeatures.Add_MouseDown($dragAction)
    
    # 键盘导航
    $exitButton.TabIndex = 0
    $elevateButton.TabIndex = 1
    $continueButton.TabIndex = 2
    $elevateForm.AcceptButton = $elevateButton
    $elevateForm.CancelButton = $exitButton
    
    # 底部状态文本 - 延迟到 Add_Shown 中与标题同步设置
    # Update-StarfieldStatusText -Panel $elevateBackground -NewText $res.StatusText
    
    # ====== 新增：在窗体显示前，先隐藏所有参与动效的控件，彻底杜绝闪烁 ======
    # 所有控件都参与飞入动画，UWPText 标题控件在动画结束后才显示文本
    $animControls = @($permTitleLabel, $permInfoLabel, $normalTitle, $normalSep, $normalFeatures, $normalLimited, $adminTitle, $adminSep, $adminFeatures, $exitButton, $elevateButton, $continueButton)
    foreach ($c in $animControls) { if ($null -ne $c) { $c.Visible = $false } }
    
    $elevateForm.Add_Shown({
        Start-MainWindowAnimation -Form $elevateForm
        [System.Windows.Forms.Application]::DoEvents()
        
        $elevateForm.SuspendLayout()
        
        # === UWP 飞入动画：标题与状态文本同步入场 ===
        # 主标题飞入 + 底部状态文本同时触发，标题使用 UWPText 的 _pendingText 机制在动画结束后自动显示文本
        Start-UwpEnterAnimation -Control $permTitleLabel -TargetLocation $permTitleLabel.Location -ParentForm $elevateForm -DurationMs 450 -OffsetY 40 -DelayMs 50
        Update-StarfieldStatusText -Panel $elevateBackground -NewText $res.StatusText
        
        Start-UwpEnterAnimation -Control $permInfoLabel -TargetLocation $permInfoLabel.Location -ParentForm $elevateForm -DurationMs 450 -OffsetY 40 -DelayMs 80
        
        # 普通模式标题 + 分隔线 + 内容 - 第二组同步
        Start-UwpEnterAnimation -Control $normalTitle -TargetLocation $normalTitle.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        Start-UwpEnterAnimation -Control $normalSep -TargetLocation $normalSep.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        Start-UwpEnterAnimation -Control $normalFeatures -TargetLocation $normalFeatures.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        Start-UwpEnterAnimation -Control $normalLimited -TargetLocation $normalLimited.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 170
        
        # 管理员模式标题 + 分隔线 + 内容 - 第三组同步
        Start-UwpEnterAnimation -Control $adminTitle -TargetLocation $adminTitle.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 200
        Start-UwpEnterAnimation -Control $adminSep -TargetLocation $adminSep.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 200
        Start-UwpEnterAnimation -Control $adminFeatures -TargetLocation $adminFeatures.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 220
        
        Start-UwpEnterAnimation -Control $exitButton -TargetLocation $exitButton.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 260
        Start-UwpEnterAnimation -Control $elevateButton -TargetLocation $elevateButton.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 290
        Start-UwpEnterAnimation -Control $continueButton -TargetLocation $continueButton.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 320
        
        foreach ($c in $animControls) { if ($null -ne $c) { $c.Visible = $true } }
        $elevateForm.ResumeLayout()
    }.GetNewClosure())
    
    # ====== 新增：在窗体显示前隐藏所有动效控件，彻底消除第一帧的闪烁 ======
    foreach ($c in $animControls) { if ($null -ne $c) { $c.Visible = $false } }
    
    # ====== 核心修复：确保窗体初始完全透明，完美承接主窗口淡入动效 ======
    $elevateForm.Opacity = 0.0
    
    # 显示对话框
    $result = $elevateForm.ShowDialog()
    
    # ====== 关键修复：等待所有UWP动效播放完成后再返回 ======
    # 动画总时长：窗口淡入600ms + 控件飞入最长延迟250ms + 控件动画时长450ms = 约1300ms
    # 在高性能机器上，如果不等待就返回，会导致回显内容与动画竞争CPU资源，造成动效阻塞
    for ($i = 0; $i -lt 130; $i++) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 10
    }
    
    # 清理
    $elevateForm.Dispose()
    
    # 返回用户选择
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return "Elevate"
    } elseif ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
        return "Exit"
    } else {
        return "Continue"
    }
}
