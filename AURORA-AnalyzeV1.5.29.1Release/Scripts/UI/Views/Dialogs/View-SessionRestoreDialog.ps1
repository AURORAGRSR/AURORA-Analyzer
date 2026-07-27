<#
.SYNOPSIS
    AURORA 进度恢复对话框
.DESCRIPTION
    进度恢复对话框（复用 PRO 模式视觉和动画）
.NOTES
    版本：V1.5.29.1Release | 构建时间：2026.07.27
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>
# ====== 进度恢复对话框（复用 PRO 模式视觉和动画） ======
function Show-SessionRestoreDialog {
    param(
        [System.Windows.Forms.Form]$ParentForm,
        [StarfieldPanel]$ParentBackground,
        [hashtable]$SessionData
    )
    
    # 在语言选择之前，使用系统语言作为默认
    $systemLanguage = if ((Get-UICulture).Name -like 'zh*') { 'CHS' } else { 'ENG' }
    $currentLanguage = $systemLanguage
    
    # 双语资源
    $resources = @{
        CHS = @{
            Title = "AURORA - 会话恢复 / Session Recovery"
            Subtitle = "🔄 检测到未完成的会话"
            SessionInfo = "会话信息"
            SessionID = "会话 ID:"
            Progress = "已保存进度:"
            Stage = "当前阶段:"
            SavedAt = "保存时间:"
            AgeDays = "已挂起:"
            Options = "恢复选项"
            Restore = "恢复进度继续执行"
            RestoreDesc = "从上次中断的位置继续，已完成的数据将保留"
            Restart = "重新开始新会话"
            RestartDesc = "放弃之前的进度，从头开始新的导出任务"
            RestoreButton = "恢复进度 (_R)"
            RestartButton = "重新开始 (_N)"
        }
        ENG = @{
            Title = "AURORA - Session Recovery"
            Subtitle = "🔄 Incomplete Session Detected"
            SessionInfo = "Session Information"
            SessionID = "Session ID:"
            Progress = "Saved Progress:"
            Stage = "Current Stage:"
            SavedAt = "Saved At:"
            AgeDays = "Suspended For:"
            Options = "Recovery Options"
            Restore = "Resume Session"
            RestoreDesc = "Continue from where you left off, completed data will be retained"
            Restart = "Start New Session"
            RestartDesc = "Discard previous progress and start a new export task from beginning"
            RestoreButton = "&Resume Session"
            RestartButton = "&Start New"
        }
    }
    
    $res = $resources[$currentLanguage]
    
    # 创建恢复窗口
    $restoreForm = New-Object System.Windows.Forms.Form
    $restoreForm.Text = $res.Title
    $restoreForm.ClientSize = New-Object System.Drawing.Size(750, 750)
    $restoreForm.StartPosition = "CenterParent"
    $restoreForm.FormBorderStyle = 'None'
    $restoreForm.MaximizeBox = $false
    $restoreForm.MinimizeBox = $false
    $restoreForm.TopMost = $true
    $restoreForm.BackColor = [System.Drawing.Color]::Black
    $restoreForm.ShowInTaskbar = $false
    $restoreForm.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)
    
    # 使用 StarfieldPanel 作为背景
    $restoreBackground = New-Object StarfieldPanel
    $restoreBackground.Dock = "Fill"
    $restoreBackground.TextX = 375
    $restoreBackground.TextY = 700
    $restoreBackground.Enabled = $true
    $restoreBackground.TextAlignment = [System.Drawing.StringAlignment]::Center
    
    # 标题标签（UWP自绘控件）- 走 UWP 飞入动画 + 自动文本切换
    $restoreTitleLabel = New-Object UWPText
    $restoreTitleLabel.TextOnly = $res.Subtitle
    $restoreTitleLabel.Font = Get-EmojiFont -Size 18 -Style ([System.Drawing.FontStyle]::Bold)
    $restoreTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 255)
    $restoreTitleLabel.BackColor = [System.Drawing.Color]::Transparent
    $restoreTitleLabel.Size = New-Object System.Drawing.Size(400, 45)
    $restoreTitleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $restoreTitleLabel.TextAlign = [System.Drawing.StringAlignment]::Near
    $restoreTitleLabel.Add_MouseDown($dragAction)
    
    $restoreInfoLabel = New-Object System.Windows.Forms.Label
    $restoreInfoLabel.Text = if ($currentLanguage -eq 'CHS') { "您可以选择恢复之前的进度，或者重新开始新会话" } else { "You can choose to resume previous progress or start a new session" }
    $restoreInfoLabel.Font = Get-EmojiFont -Size 9.5
    $restoreInfoLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
    $restoreInfoLabel.BackColor = [System.Drawing.Color]::Transparent
    $restoreInfoLabel.Size = New-Object System.Drawing.Size(500, 50)
    $restoreInfoLabel.Location = New-Object System.Drawing.Point(20, 65)
    $restoreInfoLabel.TextAlign = 'TopLeft'
    
    # 会话信息标题（UWP自绘控件）- 走 UWP 飞入动画 + 自动文本切换
    $sessionInfoTitle = New-Object UWPText
    $sessionInfoTitle.TextOnly = $res.SessionInfo
    $sessionInfoTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
    $sessionInfoTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 255)
    $sessionInfoTitle.BackColor = [System.Drawing.Color]::Transparent
    $sessionInfoTitle.Size = New-Object System.Drawing.Size(690, 30)
    $sessionInfoTitle.Location = New-Object System.Drawing.Point(30, 130)
    $sessionInfoTitle.TextAlign = [System.Drawing.StringAlignment]::Near
    $sessionInfoTitle.Add_MouseDown($dragAction)
    
    # 分隔线
    $infoSep = New-Object System.Windows.Forms.Label
    $infoSep.BackColor = [System.Drawing.Color]::FromArgb(80, 100, 120)
    $infoSep.AutoSize = $false
    $infoSep.Size = New-Object System.Drawing.Size(690, 1)
    $infoSep.Location = New-Object System.Drawing.Point(30, 160)
    
    $sessionInfoContent = New-Object AuroraConsoleBox
    $ageDaysText = if ($currentLanguage -eq 'CHS') { '天' } else { 'days' }
    $sessionInfoContent.Text = "$($res.SessionID) $($SessionData.SessionId)`n" +
                               "$($res.Progress) $($SessionData.Progress)%`n" +
                               "$($res.Stage) $($SessionData.Stage)`n" +
                               "$($res.SavedAt) $($SessionData.LastUpdated)`n" +
                               "$($res.AgeDays) $($SessionData.AgeInDays) $ageDaysText"
    $sessionInfoContent.Size = New-Object System.Drawing.Size(690, 115)
    $sessionInfoContent.Location = New-Object System.Drawing.Point(30, 165)
    
    # 恢复选项标题（UWP自绘控件）- 走 UWP 飞入动画 + 自动文本切换
    $restoreOptionTitle = New-Object UWPText
    $restoreOptionTitle.TextOnly = $res.Restore
    $restoreOptionTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
    $restoreOptionTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 255)
    $restoreOptionTitle.BackColor = [System.Drawing.Color]::Transparent
    $restoreOptionTitle.Size = New-Object System.Drawing.Size(690, 30)
    $restoreOptionTitle.Location = New-Object System.Drawing.Point(30, 305)
    $restoreOptionTitle.TextAlign = [System.Drawing.StringAlignment]::Near
    $restoreOptionTitle.Add_MouseDown($dragAction)
    
    $restoreOptionDesc = New-Object AuroraConsoleBox
    $restoreOptionDesc.Text = $res.RestoreDesc
    $restoreOptionDesc.Size = New-Object System.Drawing.Size(690, 80)
    $restoreOptionDesc.Location = New-Object System.Drawing.Point(30, 335)
    
    # 重新开始选项标题（UWP自绘控件）- 走 UWP 飞入动画 + 自动文本切换
    $restartOptionTitle = New-Object UWPText
    $restartOptionTitle.TextOnly = $res.Restart
    $restartOptionTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
    $restartOptionTitle.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $restartOptionTitle.BackColor = [System.Drawing.Color]::Transparent
    $restartOptionTitle.Size = New-Object System.Drawing.Size(690, 30)
    $restartOptionTitle.Location = New-Object System.Drawing.Point(30, 420)
    $restartOptionTitle.TextAlign = [System.Drawing.StringAlignment]::Near
    $restartOptionTitle.Add_MouseDown($dragAction)
    
    $restartOptionDesc = New-Object AuroraConsoleBox
    $restartOptionDesc.Text = $res.RestartDesc
    $restartOptionDesc.Size = New-Object System.Drawing.Size(690, 80)
    $restartOptionDesc.Location = New-Object System.Drawing.Point(30, 450)
    
    # 恢复按钮 - 使用 TechButton
    $restoreButton = New-Object TechButton
    $restoreButton.Text = $res.RestoreButton
    $restoreButton.SetBounds(20, 561, 340, 48)
    
    # 重新开始按钮 - 使用 TechButton
    $restartButton = New-Object TechButton
    $restartButton.Text = $res.RestartButton
    $restartButton.SetBounds(390, 561, 340, 48)
    
    # 按钮点击事件处理 - 带 UWP 退出动画
    $restoreButton.Add_Click({
        try {
            $restoreButton.Enabled = $false
            $restartButton.Enabled = $false
            
            $exitAnimations = @()
            $exitAnimations += Start-UwpExitAnimation -Control $restoreTitleLabel -DurationMs 300 -OffsetY 30 -StaggerDelay 0
            $exitAnimations += Start-UwpExitAnimation -Control $restoreInfoLabel -DurationMs 300 -OffsetY 30 -StaggerDelay 30
            $exitAnimations += Start-UwpExitAnimation -Control $sessionInfoTitle -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $infoSep -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $sessionInfoContent -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $restoreOptionTitle -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $restoreOptionDesc -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $restartOptionTitle -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $restartOptionDesc -DurationMs 300 -OffsetY 40 -StaggerDelay 120
            $exitAnimations += Start-UwpExitAnimation -Control $restoreButton -DurationMs 300 -OffsetY 40 -StaggerDelay 150
            $exitAnimations += Start-UwpExitAnimation -Control $restartButton -DurationMs 300 -OffsetY 40 -StaggerDelay 180
            
            for ($i = 0; $i -lt 25; $i++) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 10
            }
            
            Start-MainWindowExitAnimation -Form $restoreForm
            
            for ($i = 0; $i -lt 50; $i++) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 10
            }
        } catch { Write-AuroraLog "还原表单动画处理失败: $($_.Exception.Message)" -Level "Warning" }
        $restoreForm.DialogResult = 'OK'
        $restoreForm.Close()
    })
    
    $restartButton.Add_Click({
        try {
            $restoreButton.Enabled = $false
            $restartButton.Enabled = $false
            
            $exitAnimations = @()
            $exitAnimations += Start-UwpExitAnimation -Control $restoreTitleLabel -DurationMs 300 -OffsetY 30 -StaggerDelay 0
            $exitAnimations += Start-UwpExitAnimation -Control $restoreInfoLabel -DurationMs 300 -OffsetY 30 -StaggerDelay 30
            $exitAnimations += Start-UwpExitAnimation -Control $sessionInfoTitle -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $infoSep -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $sessionInfoContent -DurationMs 300 -OffsetY 40 -StaggerDelay 60
            $exitAnimations += Start-UwpExitAnimation -Control $restoreOptionTitle -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $restoreOptionDesc -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $restartOptionTitle -DurationMs 300 -OffsetY 40 -StaggerDelay 90
            $exitAnimations += Start-UwpExitAnimation -Control $restartOptionDesc -DurationMs 300 -OffsetY 40 -StaggerDelay 120
            $exitAnimations += Start-UwpExitAnimation -Control $restoreButton -DurationMs 300 -OffsetY 40 -StaggerDelay 150
            $exitAnimations += Start-UwpExitAnimation -Control $restartButton -DurationMs 300 -OffsetY 40 -StaggerDelay 180
            
            for ($i = 0; $i -lt 25; $i++) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 10
            }
            
            Start-MainWindowExitAnimation -Form $restoreForm
            
            for ($i = 0; $i -lt 50; $i++) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 10
            }
        } catch { Write-AuroraLog "还原表单动画处理失败: $($_.Exception.Message)" -Level "Warning" }
        $restoreForm.DialogResult = 'Abort'
        $restoreForm.Close()
    })
    
    # 添加控件到窗体
    $restoreForm.Controls.Add($restoreBackground)
    $restoreBackground.Controls.Add($restoreTitleLabel)
    $restoreBackground.Controls.Add($restoreInfoLabel)
    $restoreBackground.Controls.Add($sessionInfoTitle)
    $restoreBackground.Controls.Add($infoSep)
    $restoreBackground.Controls.Add($sessionInfoContent)
    $restoreBackground.Controls.Add($restoreOptionTitle)
    $restoreBackground.Controls.Add($restoreOptionDesc)
    $restoreBackground.Controls.Add($restartOptionTitle)
    $restoreBackground.Controls.Add($restartOptionDesc)
    $restoreBackground.Controls.Add($restoreButton)
    $restoreBackground.Controls.Add($restartButton)
    
    # 无边框拖动支持
    $dragAction = {
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            [Win32Helper]::ReleaseCapture()
            [Win32Helper]::SendMessage($restoreForm.Handle, [Win32Helper]::WM_NCLBUTTONDOWN, [Win32Helper]::HT_CAPTION, 0)
        }
    }
    
    $restoreBackground.Add_MouseDown($dragAction)
    $restoreTitleLabel.Add_MouseDown($dragAction)
    $restoreInfoLabel.Add_MouseDown($dragAction)
    $sessionInfoTitle.Add_MouseDown($dragAction)
    $sessionInfoContent.Add_MouseDown($dragAction)
    $restoreOptionTitle.Add_MouseDown($dragAction)
    $restoreOptionDesc.Add_MouseDown($dragAction)
    $restartOptionTitle.Add_MouseDown($dragAction)
    $restartOptionDesc.Add_MouseDown($dragAction)
    
    # 键盘导航
    $restoreButton.TabIndex = 0
    $restartButton.TabIndex = 1
    $restoreForm.AcceptButton = $restoreButton
    $restoreForm.CancelButton = $restartButton
    
    # ====== 新增：在窗体显示前，先隐藏所有参与动效的控件，彻底杜绝闪烁 ======
    # 所有控件都参与飞入动画，UWPText 标题控件在动画结束后才显示文本
    $animControls = @($restoreTitleLabel, $restoreInfoLabel, $sessionInfoTitle, $infoSep, $sessionInfoContent, $restoreOptionTitle, $restoreOptionDesc, $restartOptionTitle, $restartOptionDesc, $restoreButton, $restartButton)
    foreach ($c in $animControls) { if ($null -ne $c) { $c.Visible = $false } }
    
    $restoreForm.Add_Shown({
        Start-MainWindowAnimation -Form $restoreForm
        [System.Windows.Forms.Application]::DoEvents()
        
        $restoreForm.SuspendLayout()
        
        # === UWP 飞入动画：标题同步入场 ===
        Start-UwpEnterAnimation -Control $restoreTitleLabel -TargetLocation $restoreTitleLabel.Location -ParentForm $restoreForm -DurationMs 450 -OffsetY 40 -DelayMs 50
        Start-UwpEnterAnimation -Control $restoreInfoLabel -TargetLocation $restoreInfoLabel.Location -ParentForm $restoreForm -DurationMs 450 -OffsetY 40 -DelayMs 80
        
        Start-UwpEnterAnimation -Control $sessionInfoTitle -TargetLocation $sessionInfoTitle.Location -ParentForm $restoreForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        Start-UwpEnterAnimation -Control $infoSep -TargetLocation $infoSep.Location -ParentForm $restoreForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        Start-UwpEnterAnimation -Control $sessionInfoContent -TargetLocation $sessionInfoContent.Location -ParentForm $restoreForm -DurationMs 400 -OffsetY 50 -DelayMs 170
        
        Start-UwpEnterAnimation -Control $restoreOptionTitle -TargetLocation $restoreOptionTitle.Location -ParentForm $restoreForm -DurationMs 400 -OffsetY 50 -DelayMs 200
        Start-UwpEnterAnimation -Control $restoreOptionDesc -TargetLocation $restoreOptionDesc.Location -ParentForm $restoreForm -DurationMs 400 -OffsetY 50 -DelayMs 200
        Start-UwpEnterAnimation -Control $restartOptionTitle -TargetLocation $restartOptionTitle.Location -ParentForm $restoreForm -DurationMs 400 -OffsetY 50 -DelayMs 200
        Start-UwpEnterAnimation -Control $restartOptionDesc -TargetLocation $restartOptionDesc.Location -ParentForm $restoreForm -DurationMs 400 -OffsetY 50 -DelayMs 200
        
        Start-UwpEnterAnimation -Control $restoreButton -TargetLocation $restoreButton.Location -ParentForm $restoreForm -DurationMs 400 -OffsetY 50 -DelayMs 250
        Start-UwpEnterAnimation -Control $restartButton -TargetLocation $restartButton.Location -ParentForm $restoreForm -DurationMs 400 -OffsetY 50 -DelayMs 250
        
        foreach ($c in $animControls) { if ($null -ne $c) { $c.Visible = $true } }
        $restoreForm.ResumeLayout()
    }.GetNewClosure())
    
    # ====== 新增：在窗体显示前隐藏所有动效控件，彻底消除第一帧的闪烁 ======
    foreach ($c in $animControls) { if ($null -ne $c) { $c.Visible = $false } }
    
    # ====== 核心修复：确保窗体初始完全透明，完美承接主窗口淡入动效 ======
    $restoreForm.Opacity = 0.0
    
    # 显示对话框
    $result = $restoreForm.ShowDialog()
    
    # ====== 关键修复：等待所有UWP动效播放完成后再返回 ======
    # 动画总时长：窗口淡入600ms + 控件飞入最长延迟250ms + 控件动画时长450ms = 约1300ms
    # 在高性能机器上，如果不等待就返回，会导致回显内容与动画竞争CPU资源，造成动效阻塞
    for ($i = 0; $i -lt 130; $i++) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 10
    }
    
    # 清理
    $restoreForm.Dispose()
    
    return $result
}
