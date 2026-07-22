<#
.SYNOPSIS
    AURORA PRO 模式脚本运行窗口
.DESCRIPTION
    PRO 脚本运行窗口 - 多线程优化版
.NOTES
    版本：V1.5.29.0Release | 构建时间：2026.07.21
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>
# ====== PRO 脚本运行窗口 - 多线程优化版 ======
function ShowProMode {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$Language,
        [Parameter(Mandatory=$false)]
        [bool]$FromGUI = $false  # 💥 新增：是否为从 GUI 直接进入（启用 CSV 检测和全息对话框）
    )
    
    # 🔴 修复：获取 Scripts 目录和资源目录（不覆盖主文件的 $scriptDir）
    $ScriptsDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)  # 从 PSScriptRoot 直接计算，向上两级到 Scripts 目录
    $ResourcesDir = Join-Path (Split-Path -Parent $ScriptsDir) "Resources"  # Factory\Resources 目录
    
    # 创建 PRO 模式窗口
    $proForm = New-Object System.Windows.Forms.Form
    $proForm.Text = "AURORA System Log Analyzer>>>$Title"
    $proForm.ClientSize = New-Object System.Drawing.Size(750, 750)
    $proForm.StartPosition = "CenterScreen"
    $proForm.FormBorderStyle = 'None'
    $proForm.MaximizeBox = $false
    $proForm.MinimizeBox = $false
    $proForm.TopMost = $true
    $proForm.BackColor = [System.Drawing.Color]::Black

    # 使用 StarfieldPanel 作为背景
    $proBackground = New-Object StarfieldPanel
    $proBackground.Dock = "Fill"
    $proForm.Controls.Add($proBackground)

    # ====== 支持无边框窗口拖拽 ======
    $proDragAction = {
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            [Win32Helper]::ReleaseCapture()
            # 让系统认为当前按住的是标题栏
            [Win32Helper]::SendMessage($proForm.Handle, [Win32Helper]::WM_NCLBUTTONDOWN, [Win32Helper]::HT_CAPTION, 0)
        }
    }
    $proBackground.Add_MouseDown($proDragAction)

    # ====== 新增优化版：AuroraTaskHUD 横向状态面板 ======
    $TaskHUD = New-Object AuroraTaskHUD
    $TaskHUD.Size = New-Object System.Drawing.Size(240, 70)
    # 将位置调整到终止/关闭按钮 (X: 275) 的右侧空白区域
    $TaskHUD.Location = New-Object System.Drawing.Point(485, 650) 
    $TaskHUD.Visible = $false
    # 设置语言
    $TaskHUD.SetLanguage($Language)
    $proBackground.Controls.Add($TaskHUD)
    $TaskHUD.BringToFront() # 确保在星空和控制台的最上层

    # 标题（UWP自绘控件）- 走 UWP 飞入动画 + 自动文本切换
    $proTitleLabel = New-Object UWPText
    $proTitleLabel.TextOnly = $Title
    $proTitleLabel.Location = New-Object System.Drawing.Point(50, 15)
    $proTitleLabel.Size = New-Object System.Drawing.Size(650, 35)
    $proTitleLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 14, [System.Drawing.FontStyle]::Bold)
    $proTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $proTitleLabel.BackColor = [System.Drawing.Color]::Transparent
    $proTitleLabel.TextAlign = [System.Drawing.StringAlignment]::Center
    $proTitleLabel.Add_MouseDown($proDragAction)
    $proBackground.Controls.Add($proTitleLabel)

    # ====== 核心升级：动态私有字体加载引擎（带优雅降级）======
    $fontFile = Join-Path $ResourcesDir "CascadiaMono.ttf"
    $privateFonts = New-Object System.Drawing.Text.PrivateFontCollection
    $modernFontName = "Cascadia Mono"
    $usePrivateFont = $false

    # 尝试加载私有字体文件
    if (Test-Path $fontFile) {
        try {
            $privateFonts.AddFontFile($fontFile)
            if ($privateFonts.Families.Count -gt 0) {
                $modernFontName = $privateFonts.Families[0].Name
                $usePrivateFont = $true
            }
        } catch {
            # 静默失败，继续尝试其他字体
        }
    }

    # 安全获取已安装字体列表
    $installedFonts = @()
    try {
        $installedFonts = [System.Drawing.FontFamily]::Families.Name
    } catch {
        # 如果获取失败，使用空列表，将回退到默认字体
    }
    $hasModernFont = ($installedFonts -contains "Cascadia Mono") -or $usePrivateFont

    # ====== 上面的大框：输出回显区 (半透明 Aurora 风格) ======
    $consoleBox = New-Object AuroraConsoleBox
    $consoleBox.Location = New-Object System.Drawing.Point(50, 60)
    $consoleBox.Size = New-Object System.Drawing.Size(650, 450) # 高度扩展至 450
    $proBackground.Controls.Add($consoleBox)

    # ====== 中部状态区 (整体下沉紧贴回显区) ======
    $proProgressBar = CreateAuroraProgressBar
    $proProgressBar.Location = New-Object System.Drawing.Point(50, 525)
    $proProgressBar.Size = New-Object System.Drawing.Size(650, 12)
    $proProgressBar.Visible = $true
    $proProgressBar.Value = 0
    $proBackground.Controls.Add($proProgressBar)

    # ====== 激活 StarfieldPanel 的 UWP 状态文本引擎 ======
    $proBackground.TextX = 375 # X 居中 (750 / 2)
    $proBackground.TextY = 554 # Y 轴对齐到进度条下方
    $proBackground.TextAlignment = [System.Drawing.StringAlignment]::Center
    
    # 设置 StarfieldPanel 的字体为动态加载的字体
    if ($usePrivateFont) {
        $starfieldFont = New-Object System.Drawing.Font($privateFonts.Families[0], 10, [System.Drawing.FontStyle]::Bold)
    } elseif ($installedFonts -contains "Cascadia Mono") {
        $starfieldFont = New-Object System.Drawing.Font("Cascadia Mono", 10, [System.Drawing.FontStyle]::Bold)
    } else {
        $starfieldFont = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
    }
    $proBackground.SetFont($starfieldFont)
    
    # 初始状态文本
    $initText = if ($Language -eq "CHS") { "准备就绪" } else { "Ready" }
    Update-StarfieldStatusText -Panel $proBackground -NewText $initText

    # ====== 下面的交互区：终端指令输入 (废弃 inputPanel，实现无边框悬浮) ======
    
    # 1. 指示标签（UWP自绘控件）- 走 UWP 飞入动画 + 自动文本切换
    $inputPanelLabel = New-Object UWPText
    if ($Language -eq "CHS") { $inputPanelLabel.TextOnly = ">>> 终端指令输入" } else { $inputPanelLabel.TextOnly = ">>> Terminal Input" }
    $inputPanelLabel.Location = New-Object System.Drawing.Point(50, 570)
    $inputPanelLabel.Size = New-Object System.Drawing.Size(250, 20)
    $inputPanelLabel.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
    $inputPanelLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
    $inputPanelLabel.BackColor = [System.Drawing.Color]::Transparent
    $inputPanelLabel.TextAlign = [System.Drawing.StringAlignment]::Near
    $inputPanelLabel.Add_MouseDown($proDragAction)
    $proBackground.Controls.Add($inputPanelLabel)

    # 2. 半透明输入框 (Aurora 风格)
    $inputTextBox = New-Object AuroraInputBox
    $inputTextBox.Location = New-Object System.Drawing.Point(50, 595)
    $inputTextBox.Size = New-Object System.Drawing.Size(480, 32)
    $proBackground.Controls.Add($inputTextBox)

    # 3. 发送按钮
    $sendButton = New-Object TechButton
    if ($Language -eq "CHS") { $sendButton.Text = "发送-Send" } else { $sendButton.Text = "Send" }
    $sendButton.SetBounds(545, 590, 155, 38)
    $proBackground.Controls.Add($sendButton)

    # 5. 提示标签
    $hintLabel = New-Object System.Windows.Forms.Label
    if ($Language -eq "CHS") { $hintLabel.Text = "提示：输入指令后按回车(Enter)发送，直接回车使用默认值" } else { $hintLabel.Text = "Hint: Press Enter to send, empty for default value" }
    $hintLabel.Location = New-Object System.Drawing.Point(50, 630)
    $hintLabel.Size = New-Object System.Drawing.Size(630, 20)
    $hintLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
    $hintLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 130, 160)
    $hintLabel.BackColor = [System.Drawing.Color]::Transparent
    $proBackground.Controls.Add($hintLabel)

    # ====== 底部控制区：智能状态变形按钮 ======
    $actionButton = New-Object TechButton
    if ($Language -eq "CHS") { $actionButton.Text = "强行终止 -Abort" } else { $actionButton.Text = "Abort" }
    $actionButton.SetBounds(275, 660, 200, 48) # 坐标微调，确保绝对可见
    $actionButton.Tag = "Abort"
    $proBackground.Controls.Add($actionButton)
    $actionButton.BringToFront() # ====== 核心修复：强制置于绝对顶层，防止被遮挡 ======
    
    # ====== 新增：透明玻璃风格权限指示器（AuroraPrivilegeIndicator） ======
    $privilegeIndicator = New-Object AuroraPrivilegeIndicator
    $privilegeIndicator.Size = New-Object System.Drawing.Size(200, 40)
    $privilegeIndicator.Location = New-Object System.Drawing.Point(50, 665)
    $privilegeIndicator.IsAdminMode = $global:syncHash.IsAdmin
    $privilegeIndicator.StatusText = if ($global:syncHash.IsAdmin) {
        if ($Language -eq "CHS") { "管理员模式" } else { "Admin Mode" }
    } else {
        if ($Language -eq "CHS") { "普通用户模式" } else { "Standard Mode" }
    }
    $privilegeIndicator.StatusColor = if ($global:syncHash.IsAdmin) {
        [System.Drawing.Color]::FromArgb(100, 255, 150)
    } else {
        [System.Drawing.Color]::FromArgb(255, 180, 100)
    }
    $privilegeIndicator.Visible = $true
    $proBackground.Controls.Add($privilegeIndicator)
    
    # 提权按钮（仅在普通模式下显示）- 恢复使用 TechButton
    if (-not $global:syncHash.IsAdmin) {
        $elevateMiniButton = New-Object TechButton
        $elevateMiniButton.Text = if ($Language -eq "CHS") { "🔐 提权" } else { "🔐 Elevate" }
        $elevateMiniButton.Size = New-Object System.Drawing.Size(70, 28)
        # 关键修复：调整位置到权限指示器下方
        $elevateMiniButton.Location = New-Object System.Drawing.Point(50, 705)
        $elevateMiniButton.Tag = "Elevate"
        $elevateMiniButton.Add_Click({
            # 显示提权确认对话框
            $confirmMsg = if ($Language -eq "CHS") {
                "以管理员身份运行后，您可以：`n" +
                "  ✓ 查看安全日志`n" +
                "  ✓ 查看安装日志`n" +
                "  ✓ 执行系统修复`n" +
                "  ✓ 使用完整诊断功能`n`n" +
                "是否继续？"
            } else {
                "After running as administrator, you can:`n" +
                "  ✓ View Security Log`n" +
                "  ✓ View Setup Log`n" +
                "  ✓ Execute system repairs`n" +
                "  ✓ Use full diagnostic features`n`n" +
                "Continue?"
            }
            
            $title = if ($Language -eq "CHS") { "提权确认" } else { "Elevation Confirmation" }
            $result = [System.Windows.Forms.MessageBox]::Show($confirmMsg, $title, 
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question)
            
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                # 请求提权并重启（复用 Restart-WithAdmin 函数）
                try {
                    if (Restart-WithAdmin) {
                        # 等待新进程启动后再退出当前进程
                        Start-Sleep -Milliseconds 500
                        [System.Environment]::Exit(0)
                    }
                } catch {
                    $errorMsg = if ($Language -eq "CHS") { "提权失败：$($_.Exception.Message)" } else { "Elevation failed: $($_.Exception.Message)" }
                    [System.Windows.Forms.MessageBox]::Show($errorMsg, "Error", "OK", "Error")
                }
            }
        })
        $proBackground.Controls.Add($elevateMiniButton)
        # 关键修复：确保提权按钮在权限指示器之上
        $elevateMiniButton.BringToFront()
        # 初始隐藏，等待动画
        $elevateMiniButton.Visible = $false
        # 将提权按钮添加到动画控件数组
        $animControls += $elevateMiniButton
    }

    # ====== 新增优化版：全屏幕全息高危授权叠加层 ======
    $DecisionModal = New-Object AuroraDecisionModal
    $DecisionModal.Visible = $false
    # 💥 关键挂载点：必须加在 proBackground 上，并且 Dock=Fill
    $proBackground.Controls.Add($DecisionModal)
    $DecisionModal.BringToFront()
    
    # ====== 新增：创建 AuroraResultModal 执行结果展示控件 ======
    $ResultModal = New-Object AuroraResultModal
    $ResultModal.Visible = $false
    # 关键挂载点：必须加在 proBackground 上，并且 Dock=Fill
    $proBackground.Controls.Add($ResultModal)
    $ResultModal.BringToFront()
    
    # ====== 新增：创建 AuroraRestoreModal 会话恢复 HUD 叠加层 ======
    $RestoreModal = New-Object AuroraRestoreModal
    $RestoreModal.Visible = $false
    # 关键挂载点：必须加在 proBackground 上，并且 Dock=Fill
    $proBackground.Controls.Add($RestoreModal)
    $RestoreModal.BringToFront()
    
    # ====== 新增：创建 AuroraExportedLogsModal 已导出日志确认 HUD 叠加层 ======
    $ExportedLogsModal = New-Object AuroraExportedLogsModal
    $ExportedLogsModal.Visible = $false
    # 关键挂载点：必须加在 proBackground 上，并且 Dock=Fill
    $proBackground.Controls.Add($ExportedLogsModal)
    $ExportedLogsModal.BringToFront()

    # ====== 绑定 C# 内部虚拟按钮的事件 ======
    $DecisionModal.add_OnAuthorize({
        # 检查是否为智能分析请求
        if ($DecisionModal.Tag -eq "SmartAnalysis_Shown") {
            # 智能分析授权
            $global:syncHash.SmartAnalysisAuthorized = $true
            $global:syncHash.SmartAnalysisRequested = $false
            if ($Language -eq "CHS") {
                $global:syncHash.LogOutput += "`n✅ 用户已确认智能诊断分析...`n"
            } else {
                $global:syncHash.LogOutput += "`n✅ User confirmed smart diagnostic analysis...`n"
            }
            
            # 🔧 修复：智能分析授权之后也要重置 IsModalShowing 和 Tag
            $DecisionModal.FadeOutModal()
            Start-Sleep -Milliseconds 150
            $script:IsModalShowing = $false
            $DecisionModal.Tag = $null
            
            if ($Language -eq "CHS") {
                $global:syncHash.LogOutput += "✅ 智能分析授权对话框已关闭，状态已重置`n"
            } else {
                $global:syncHash.LogOutput += "✅ Smart analysis authorization dialog closed, state reset`n"
            }
            return
        }
        
        # 普通高危操作授权
        $global:syncHash.Authorized = $true
        $global:syncHash.RequiresAuthorization = $false  # 强制清除请求标记，防止 UI 轮询重入
        
        # 💥 新增：添加调试日志
        if ($Language -eq "CHS") {
            $global:syncHash.LogOutput += "`n✅ 用户已授权，继续执行修复...`n"
        } else {
            $global:syncHash.LogOutput += "`n✅ User authorized, continuing execution...`n"
        }
        
        # Phase 2.3 核心优化：触发 EventWaitHandle 信号（事件驱动）
        if ($global:syncHash.AuthorizationEventName) {
            try {
                $eventWaitHandle = [System.Threading.EventWaitHandle]::OpenExisting($global:syncHash.AuthorizationEventName)
                $eventWaitHandle.Set()  # 触发信号，唤醒等待的 Runspace
                $eventWaitHandle.Dispose()
            } catch {
                # 事件不存在或已关闭，忽略
            }
        }
        
        # 💥 核心修复：延迟重置 IsModalShowing，确保动画完成
        # 先隐藏控件，然后等待动画完成后再重置标志
        $DecisionModal.FadeOutModal()
        Start-Sleep -Milliseconds 150  # 等待 150ms 确保 FadeOut 动画开始
        
        # 释放互斥锁
        $script:IsModalShowing = $false
        $DecisionModal.Tag = $null
        
        # 💥 新增：调试日志
        if ($Language -eq "CHS") {
            $global:syncHash.LogOutput += "✅ 授权对话框已关闭，状态已重置`n"
        } else {
            $global:syncHash.LogOutput += "✅ Authorization dialog closed, state reset`n"
        }
    }.GetNewClosure())

    $DecisionModal.add_OnSkip({
        # 检查是否为智能分析请求
        if ($DecisionModal.Tag -eq "SmartAnalysis_Shown") {
            # 智能分析跳过
            $global:syncHash.SmartAnalysisAuthorized = $false
            $global:syncHash.SmartAnalysisRequested = $false
            if ($Language -eq "CHS") {
                $global:syncHash.LogOutput += "`n⏭️ 用户跳过智能诊断分析...`n"
            } else {
                $global:syncHash.LogOutput += "`n⏭️ User skipped smart diagnostic analysis...`n"
            }
            
            # 🔧 修复：智能分析跳过之后也要重置 IsModalShowing 和 Tag
            $DecisionModal.FadeOutModal()
            Start-Sleep -Milliseconds 150
            $script:IsModalShowing = $false
            $DecisionModal.Tag = $null
            
            if ($Language -eq "CHS") {
                $global:syncHash.LogOutput += "✅ 智能分析跳过对话框已关闭，状态已重置 (IsModalShowing=false)`n"
            } else {
                $global:syncHash.LogOutput += "✅ Smart analysis skip dialog closed, state reset (IsModalShowing=false)`n"
            }
            return
        }
        
        # 普通高危操作跳过
        $global:syncHash.Authorized = $false  # 💥 核心修复：设置 Authorized = false
        $global:syncHash.RequiresAuthorization = $false
        $global:syncHash.PendingCommand = $null
        
        if ($Language -eq "CHS") {
            $global:syncHash.LogOutput += "`n⚠️ 用户拒绝授权，操作已取消...`n"
        } else {
            $global:syncHash.LogOutput += "`n⚠️ User denied authorization, operation cancelled...`n"
        }
        
        # Phase 2.3 核心优化：触发 EventWaitHandle 信号（事件驱动）
        if ($global:syncHash.AuthorizationEventName) {
            try {
                $eventWaitHandle = [System.Threading.EventWaitHandle]::OpenExisting($global:syncHash.AuthorizationEventName)
                $eventWaitHandle.Set()  # 触发信号，唤醒等待的 Runspace
                $eventWaitHandle.Dispose()
            } catch {
                # 事件不存在或已关闭，忽略
            }
        }
        
        # 菜单重新打印由后台脚本处理，这里只更新状态文本
        $statusText = if ($Language -eq "CHS") { "等待输入" } else { "Waiting for input" }
        Update-StarfieldStatusText -Panel $proBackground -NewText $statusText
        
        # 💥 核心修复：延迟重置 IsModalShowing，确保动画完成
        # 先隐藏控件，然后等待动画完成后再重置标志
        $DecisionModal.FadeOutModal()
        Start-Sleep -Milliseconds 150  # 等待 150ms 确保 FadeOut 动画开始
        
        # 释放互斥锁
        $script:IsModalShowing = $false
        $DecisionModal.Tag = $null
        
        # 💥 新增：调试日志
        if ($Language -eq "CHS") {
            $global:syncHash.LogOutput += "✅ 跳过对话框已关闭，状态已重置`n"
        } else {
            $global:syncHash.LogOutput += "✅ Skip dialog closed, state reset`n"
        }
    }.GetNewClosure())
    
    # ====== 绑定 AuroraResultModal 关闭事件 ======
    $ResultModal.add_OnClose({
        $ResultModal.FadeOutModal()
        # 重置 Tag 属性，确保下次能够再次显示
        $ResultModal.Tag = $null
        
        # ====== 核心修复：关闭结果对话框后重置状态 ======
        # 1. 重置主状态为"等待输入"
        $global:syncHash.CurrentStatus = if ($Language -eq "CHS") { "Waiting for input..." } else { "Waiting for input..." }
        
        # 2. 隐藏 HUD 进度面板
        $global:syncHash.CurrentPipelineStep = -1
        $global:syncHash.CurrentPipelineStatus = $null
        $global:syncHash.CurrentPipelineDetail = $null
        
        # 3. 更新星场状态文本
        $statusText = if ($Language -eq "CHS") { "等待输入" } else { "Waiting for input" }
        Update-StarfieldStatusText -Panel $proBackground -NewText $statusText
        
        # 菜单重新打印由后台脚本处理
    }.GetNewClosure())
    
    # ====== 绑定 AuroraRestoreModal 事件 ======
    $RestoreModal.add_OnRestore({
        # 用户选择恢复进度
        $script:IsModalShowing = $false
        $RestoreModal.Tag = $null
        $RestoreModal.FadeOutModal()
        
        # 设置恢复标志（使用syncHash中已存储的数据）
        $global:syncHash.SessionRestored = $true
        
        if ($Language -eq "CHS") {
            $global:syncHash.LogOutput += "✅ 会话已恢复：进度 $($global:syncHash.RestoredProgress)%，阶段：$($global:syncHash.RestoredStage)`n"
            $global:syncHash.LogOutput += "💡 PRO 脚本将自动从断点继续执行`n"
        } else {
            $global:syncHash.LogOutput += "✅ Session restored: Progress $($global:syncHash.RestoredProgress)%, Stage: $($global:syncHash.RestoredStage)`n"
            $global:syncHash.LogOutput += "💡 PRO script will continue from breakpoint`n"
        }
    }.GetNewClosure())
    
    $RestoreModal.add_OnRestart({
        # 用户选择重新开始
        $script:IsModalShowing = $false
        $RestoreModal.Tag = $null
        $RestoreModal.FadeOutModal()
        
        # 设置重新开始标志（使用 syncHash 中已存储的数据）
        $global:syncHash.SessionRestarted = $true
        
        if ($Language -eq "CHS") {
            $global:syncHash.LogOutput += "🔄 已清除旧会话，将开始新任务`n"
        } else {
            $global:syncHash.LogOutput += "🔄 Old session cleared, starting new task`n"
        }
    }.GetNewClosure())
    
    # ====== 绑定 AuroraExportedLogsModal 事件 ======
    $ExportedLogsModal.add_OnUse({
        # 🔧 完成提示模式：打开 UserLogs 文件夹
        if ($ExportedLogsModal.IsCompletionPrompt) {
            $exportPath = [System.IO.Path]::Combine($ScriptsDir, "..\UserLogs")
            if (Test-Path $exportPath) {
                Start-Process explorer.exe -ArgumentList $exportPath
                if ($Language -eq "CHS") {
                    $global:syncHash.LogOutput += "📂 正在打开输出文件夹...`n"
                } else {
                    $global:syncHash.LogOutput += "📂 Opening output folder...`n"
                }
            }
            $script:IsModalShowing = $false
            $ExportedLogsModal.Tag = $null
            $ExportedLogsModal.ResetCompletionMode()
            $ExportedLogsModal.FadeOutModal()
            return
        }
        
        # 用户选择使用已导出的日志
        $script:IsModalShowing = $false
        $ExportedLogsModal.Tag = $null
        $ExportedLogsModal.FadeOutModal()
        
        # 设置用户输入为"yes"
        $global:syncHash.UserInput = "yes"
        
        if ($Language -eq "CHS") {
            $global:syncHash.LogOutput += "✅ 用户选择使用已导出的日志文件`n"
        } else {
            $global:syncHash.LogOutput += "✅ User chose to use exported log files`n"
        }
    }.GetNewClosure())
    
    $ExportedLogsModal.add_OnSkip({
        # 🔧 完成提示模式：仅关闭对话框
        if ($ExportedLogsModal.IsCompletionPrompt) {
            $script:IsModalShowing = $false
            $ExportedLogsModal.Tag = $null
            $ExportedLogsModal.ResetCompletionMode()
            $ExportedLogsModal.FadeOutModal()
            
            if ($Language -eq "CHS") {
                $global:syncHash.LogOutput += "⏭️ 用户选择不打开文件夹`n"
            } else {
                $global:syncHash.LogOutput += "⏭️ User chose not to open folder`n"
            }
            return
        }
        
        # 用户选择跳过，使用实时日志
        $script:IsModalShowing = $false
        $ExportedLogsModal.Tag = $null
        $ExportedLogsModal.FadeOutModal()
        
        # 设置用户输入为"no"
        $global:syncHash.UserInput = "no"
        
        if ($Language -eq "CHS") {
            $global:syncHash.LogOutput += "⏭️ 用户选择跳过，将实时提取日志`n"
        } else {
            $global:syncHash.LogOutput += "⏭️ User chose to skip, will extract live logs`n"
        }
    }.GetNewClosure())


    # 定义追加输出的函数
    function global:Append-Output {
        [CmdletBinding()]
        param([string]$Text)
        if ($Text) {
            try {
                $consoleBox.AppendText($Text)
                $consoleBox.ScrollToCaret()
            } catch { Write-AuroraLog "控制台输出更新失败: $($_.Exception.Message)" -Level "Warning" }
        }
    }

    $actionButton.Add_Click({
        $actionButton.Enabled = $false
        
        # ⚠️ 核心修复：显式捕获二级窗体变量
        $targetProForm = $proForm
        
        if ($actionButton.Tag -eq "Abort") {
            # ========================
            # 状态 A：强行终止逻辑
            # ========================
            $global:syncHash.IsHostAlive = $false
            if ($null -ne $uiTimer) { $uiTimer.Stop() }
            
            if ($global:syncHash.IsRunning -and $null -ne $global:ActivePS) {
                try {
                    if ($Language -eq "CHS") { Update-StarfieldStatusText -Panel $proBackground -NewText "已手动终止" }
                    else { Update-StarfieldStatusText -Panel $proBackground -NewText "Aborted" }
                    
                    $global:syncHash.LogOutput += "`n⚠️ 任务已由用户强制终止 / Task aborted by user...`n"
                    [System.Windows.Forms.Application]::DoEvents()
                    # 使用异步停止，立即释放主 UI 线程
                    $global:ActivePS.BeginStop($null, $null) | Out-Null
                } catch { Write-AuroraLog "任务终止失败: $($_.Exception.Message)" -Level "Warning" }
            }
            
            # 核心变身：逻辑执行完后，自己变成关闭按钮
            if ($Language -eq "CHS") { $actionButton.Text = "关闭-Close" } else { $actionButton.Text = "Close" }
            $actionButton.Tag = "Close"
            $actionButton.Enabled = $true
            $actionButton.Invalidate()  # 强制重绘以显示新文字

        } elseif ($actionButton.Tag -eq "Close") {
            # ========================
            # 状态 B：优雅退出逻辑
            # ========================

            try {
                # 恢复错峰坠落的优雅动效
                $delay = 0
                $exitControls = @($consoleBox, $proProgressBar, $inputPanelLabel, $inputTextBox, $sendButton, $hintLabel, $proTitleLabel, $actionButton, $privilegeIndicator, $TaskHUD)
                foreach ($ctrl in $exitControls) {
                    if ($null -ne $ctrl) {
                        Start-UwpExitAnimation -Control $ctrl -DurationMs 300 -OffsetY 50 -StaggerDelay $delay
                        $delay += 40
                    }
                }
                # 提权按钮（仅在普通模式下存在）
                if ($null -ne $elevateMiniButton) {
                    Start-UwpExitAnimation -Control $elevateMiniButton -DurationMs 300 -OffsetY 50 -StaggerDelay $delay
                }
            } catch { Write-AuroraLog "退出动画清理失败: $($_.Exception.Message)" -Level "Warning" }

            $proExitTimer1 = New-Object System.Windows.Forms.Timer
            $proExitTimer1.Interval = 500 # 先等UWP控件退出动画完成
            $proExitTimer1.Tag = @{ ProForm = $targetProForm }
            $proExitTimer1.Add_Tick({
                $timer = $this
                $data = $timer.Tag
                $timer.Stop(); $timer.Dispose()
                
                # 播放二级窗口级退出动画（同步阻塞450ms）
                if ($null -ne $data.ProForm -and -not $data.ProForm.IsDisposed) {
                    try { Start-MainWindowExitAnimation -Form $data.ProForm } catch { Write-AuroraLog "窗口退出动画失败: $($_.Exception.Message)" -Level "Warning" }
                }
                
                # 等待二级窗口退出动画完成后，再退出程序
                $proExitTimer2 = New-Object System.Windows.Forms.Timer
                $proExitTimer2.Interval = 500
                $proExitTimer2.Add_Tick({
                    $timer2 = $this
                    $timer2.Stop(); $timer2.Dispose()
                    [System.Environment]::Exit(0)
                })
                $proExitTimer2.Start()
            })
            $proExitTimer1.Start()
        }
    }.GetNewClosure())
    
    # 窗体关闭事件：添加彻底的清理逻辑
    $proForm.Add_FormClosing({
        # 1. 停止 UI 更新定时器
        if ($null -ne $uiTimer) { try { $uiTimer.Stop() } catch { Write-AuroraLog "UI定时器停止失败: $($_.Exception.Message)" -Level "Warning" } }
        
        # 2. 通知后台 Runspace 立即自尽
        try {
            if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
                $global:syncHash.IsHostAlive = $false
            }
        } catch { Write-AuroraLog "同步状态变量清理失败: $($_.Exception.Message)" -Level "Warning" }
        
        # 3. ====== 核心修复：只 Stop，不 Dispose，防止抛出访问异常 ======
        if ($global:ActivePS) { 
            try { $global:ActivePS.Stop() } catch { Write-AuroraLog "PowerShell进程终止失败: $($_.Exception.Message)" -Level "Warning" }
        }
        
        # 4. 🔐 P0 修复：执行安全组件清理 (Timers + FileSystemWatcher)
        try {
            if ($script:runtimeIntegrityTimer) {
                $script:runtimeIntegrityTimer.Stop()
                $script:runtimeIntegrityTimer.Dispose()
            }
            if ($script:randomIntegrityTimer) {
                $script:randomIntegrityTimer.Stop()
                $script:randomIntegrityTimer.Dispose()
            }
            if ($script:fileWatcher) {
                $script:fileWatcher.EnableRaisingEvents = $false
                $script:fileWatcher.Dispose()
            }
            if ($script:ExpectedFileHashes) {
                $script:ExpectedFileHashes.Clear()
            }
        } catch { Write-AuroraLog "脚本变量清理失败: $($_.Exception.Message)" -Level "Warning" }
    })

    # 发送按钮点击事件
    $sendButton.Add_Click({
        $inputText = $inputTextBox.Text.Trim()
        
        # 1. 直接将输入写入哈希表，允许传递空字符串 ""（后台检测到不再是 $null 即可放行）
        $global:syncHash.UserInput = $inputText
        
        # 2. 优化 UI 回显：如果为空，则显示一个提示标识，增强 UX
        if ($Language -eq "CHS") {
            $displayToken = if ($inputText -eq "") { "[按下了回车 / 使用默认值]" } else { $inputText }
            $global:syncHash.LogOutput += "👤 [$([datetime]::Now.ToString('HH:mm:ss'))] 你: $displayToken`n"
        } else {
            $displayToken = if ($inputText -eq "") { "[Pressed Enter / Use default value]" } else { $inputText }
            $global:syncHash.LogOutput += "👤 [$([datetime]::Now.ToString('HH:mm:ss'))] You: $displayToken`n"
        }
        
        # 3. 清空输入框并重获焦点
        $inputTextBox.Text = ""
        $inputTextBox.Focus()
    }.GetNewClosure())

    # 输入框回车事件
    $inputTextBox.add_EnterPressed({
        $inputText = $inputTextBox.Text.Trim()
        
        # 1. 直接将输入写入哈希表，允许传递空字符串 ""（后台检测到不再是 $null 即可放行）
        $global:syncHash.UserInput = $inputText
        
        # 2. 优化 UI 回显：如果为空，则显示一个提示标识，增强 UX
        if ($Language -eq "CHS") {
            $displayToken = if ($inputText -eq "") { "[按下了回车 / 使用默认值]" } else { $inputText }
            $global:syncHash.LogOutput += "👤 [$([datetime]::Now.ToString('HH:mm:ss'))] 你: $displayToken`n"
        } else {
            $displayToken = if ($inputText -eq "") { "[Pressed Enter / Use default value]" } else { $inputText }
            $global:syncHash.LogOutput += "👤 [$([datetime]::Now.ToString('HH:mm:ss'))] You: $displayToken`n"
        }
        
        # 3. 清空输入框并重获焦点
        $inputTextBox.Text = ""
        $inputTextBox.Focus()
    }.GetNewClosure())

    # 创建 UI Timer 用于轮询 syncHash
    $uiTimer = New-Object System.Windows.Forms.Timer
    $uiTimer.Interval = 50  # 50ms 刷新间隔，20 FPS，快速响应 PRO 脚本的请求

    $uiTimer.Add_Tick({
        # 修复 ObjectDisposedException 的安全检查
        if ($null -eq $consoleBox -or $consoleBox.IsDisposed) { return }
        if ($null -eq $proForm -or $proForm.IsDisposed) { return }
        
        # ====== 【核心修复】监听 PRO 脚本的会话恢复请求并显示 HUD ======
        # PRO 脚本检测到会话后设置 ShowSessionRecoveryHUD 标志，GUI 显示 HUD
        if ($global:syncHash.ShowSessionRecoveryHUD -eq $true -and $script:IsModalShowing -ne $true) {
            
            # 设置互斥锁
            $script:IsModalShowing = $true
            $RestoreModal.Tag = "Shown"
            
            # 更新恢复对话框信息（从 PRO 脚本传递的数据）
            $RestoreModal.UpdateInfo(
                $global:syncHash.RestoredSessionId,
                $global:syncHash.RestoredStage,
                $global:syncHash.RestoredProgress,
                $global:syncHash.RestoredLastUpdated,
                $global:syncHash.RestoredAgeInDays,
                $Language
            )
            
            # 显示恢复对话框
            $RestoreModal.BringToFront()
            $RestoreModal.FadeInModal()
            
            if ($Language -eq "CHS") {
                $global:syncHash.LogOutput += "💡 检测到未完成的会话，已显示恢复选项`n"
            } else {
                $global:syncHash.LogOutput += "💡 Incomplete session detected, showing recovery options`n"
            }
        }
        
        # ====== 新增：强制重置授权对话框状态检测 ======
        # 💥 核心修复：当 SmartEngine 发送重置请求时，强制清理所有相关状态
        if ($global:syncHash.ResetAuthorizationModal -eq $true) {
            # 清除重置标志
            $global:syncHash.ResetAuthorizationModal = $false
            
            # 强制重置所有状态
            $script:IsModalShowing = $false
            $DecisionModal.Tag = $null
            
            # 尝试淡出对话框（如果还在显示）
            try {
                $DecisionModal.FadeOutModal()
            } catch {
                # 忽略错误
            }
            
            # 添加调试日志
            if ($Language -eq "CHS") {
                $global:syncHash.LogOutput += "🔄 已强制重置授权对话框状态`n"
            } else {
                $global:syncHash.LogOutput += "🔄 Forced reset of authorization dialog state`n"
            }
        }
        
        # ====== 新增：心跳监听 - 检测高危操作授权请求 ======
        if ($global:syncHash.RequiresAuthorization -eq $true -and 
            $script:IsModalShowing -ne $true) {
            
            # 💥 核心修复：强制清除 Tag 状态，防止历史状态污染
            if ($DecisionModal.Tag -eq "Shown") {
                if ($Language -eq "CHS") {
                    $global:syncHash.LogOutput += "⚠️ 检测到 DecisionModal 状态异常，强制重置...`n"
                } else {
                    $global:syncHash.LogOutput += "⚠️ DecisionModal state anomaly detected, forcing reset...`n"
                }
            }
            $DecisionModal.Tag = $null
            
            # 停止可能正在进行的退出动画，防止动画冲突
            Stop-AllAnimations -Control $DecisionModal
            
            # 设置互斥锁
            $script:IsModalShowing = $true
            $DecisionModal.Tag = "Shown"
            $cmd = $global:syncHash.PendingCommand
            
            if ($cmd) {
                # 动态构造双语文本
                $actionStr = if ($Language -eq "CHS") { "动作: $($cmd.name)" } else { "Action: $($cmd.name_en)" }
                $rawRisk = if (-not [string]::IsNullOrWhiteSpace($cmd.risk_level)) { $cmd.risk_level.Trim() } else { "High" }
                $riskStr = if ($Language -eq "CHS") { "风险评估: $rawRisk" } else { "Risk Assessment: $rawRisk" }
                
                # 推送给控件重绘
                $DecisionModal.UpdateInfo($actionStr, $riskStr, $Language)
            }
            
            # 全屏遮罩直接淡入
            $DecisionModal.BringToFront()
            $DecisionModal.FadeInModal()
            
            # 💥 新增：添加调试日志确认 HUD 已拉起
            if ($Language -eq "CHS") {
                $global:syncHash.LogOutput += "✅ 授权 HUD 已成功拉起`n"
            } else {
                $global:syncHash.LogOutput += "✅ Authorization HUD displayed successfully`n"
            }
        }
        
        # ====== 💥 核心修复：监听智能引擎提权请求 ======
        if ($global:syncHash.RequiresElevation -eq $true) {
            # 💥 核心修复：立即重置请求标志，防止重复弹窗（关键！）
            $global:syncHash.RequiresElevation = $false
            $script:IsModalShowing = $false
            
            # 显示提权确认对话框
            $reason = $global:syncHash.ElevationReason
            if ([string]::IsNullOrWhiteSpace($reason)) {
                $reason = if ($Language -eq "CHS") { 
                    "智能诊断引擎需要管理员权限才能继续执行修复操作" 
                } else { 
                    "Smart Engine requires administrator privileges to continue" 
                }
            }
            
            # 显示提权确认对话框
            $confirmMsg = if ($Language -eq "CHS") {
                "🔐 管理员权限请求`n`n" +
                "$reason`n`n" +
                "是否以管理员身份重新启动工具并进入智能模式？`n`n" +
                "💡 提示：提权后工具将自动重启，并保留当前分析状态。"
            } else {
                "🔐 Administrator Privileges Request`n`n" +
                "$reason`n`n" +
                "Restart tool as administrator and enter Smart Mode?`n`n" +
                "💡 Hint: Tool will restart automatically and preserve current analysis state."
            }
            
            $title = if ($Language -eq "CHS") { "提权确认" } else { "Elevation Confirmation" }
            $result = [System.Windows.Forms.MessageBox]::Show($confirmMsg, $title, 
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question)
            
            # 根据用户选择设置授权结果
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                # 用户同意提权
                $global:syncHash.ElevationAuthorized = $true
                
                if ($Language -eq "CHS") {
                    $global:syncHash.LogOutput += "✅ 用户确认提权，正在准备重启...`n"
                } else {
                    $global:syncHash.LogOutput += "✅ User confirmed elevation, preparing restart...`n"
                }
                
                # 执行提权重启
                try {
                    $psi = New-Object System.Diagnostics.ProcessStartInfo
                    $psi.FileName = "powershell.exe"
                    $psi.Verb = "runas"
                    $psi.UseShellExecute = $true
                    
                    # 构建启动参数
                    $scriptPath = Join-Path $ScriptsDir "AURORA-AnalyzerLauncherGUI.ps1"

                    # 🔒 H-7：对脚本路径和语言参数做安全校验，防止命令行注入
                    # 1. 路径必须为绝对路径且不含命令行元字符
                    # 2. $Language 虽有 ValidateSet，仍做二次白名单校验防御绕过
                    if (-not (Test-Path $scriptPath)) {
                        throw "Elevation script path not found: $scriptPath"
                    }
                    try {
                        $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
                    } catch {
                        throw "Invalid script path: $scriptPath"
                    }
                    if ($scriptPath -match '[<>&|`"$]') {
                        throw "Script path contains unsafe characters"
                    }

                    # 二次校验 $Language 白名单
                    if ($Language -ne "CHS" -and $Language -ne "ENG") {
                        throw "Invalid language value: $Language"
                    }

                    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -LaunchedByExe"
                    
                    # 添加语言参数（已通过白名单校验，安全拼接）
                    $arguments += " -Language $Language"
                    
                    # 生成提权安全令牌 (AURORA-SEC-2026-001)
                    $elevationToken = [guid]::NewGuid().ToString("N")
                    $elevationTokenTimestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                    
                    # 💥 核心修复：使用 PBKDF2 从 nonce 派生密钥，与解密端保持一致
                    # 🔒 H-10：迭代次数从 1000 提升至 100000，防止 GPU 暴力破解
                    $elevationTokenKey = (New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
                        $elevationToken,  # nonce 作为密码
                        $global:AURORA_AesSalt,  # 使用全局 salt
                        100000,
                        [System.Security.Cryptography.HashAlgorithmName]::SHA256
                    )).GetBytes(32)  # 派生 32 字节密钥
                    
                    $elevationTokenIV = [System.Guid]::NewGuid().ToByteArray()  # 16 字节
                    
                    $aes = [System.Security.Cryptography.Aes]::Create()
                    $aes.Key = $elevationTokenKey
                    $aes.IV = $elevationTokenIV
                    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
                    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
                    
                    $encryptor = $aes.CreateEncryptor()
                    # 💥 核心修复：加密包含脚本路径和文件哈希列表的验证信息，确保提权重启后完整性检查可用
                    $hashList = $global:PassedHashListFromExe
                    $plainText = "AURORA-AnalyzerLauncherGUI.ps1:${elevationToken}:${hashList}"  # 包含脚本路径和哈希列表
                    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($plainText)
                    $cipherBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
                    
                    # 组合成令牌文件内容：Nonce:Timestamp:IV+Cipher(Base64)
                    $elevationTokenContent = "{0}:{1}:{2}" -f $elevationToken, $elevationTokenTimestamp, [Convert]::ToBase64String($elevationTokenIV + $cipherBytes)
                    
                    # 写入临时文件
                    $elevTokenFile = Join-Path $env:TEMP "aurora_elev_$([guid]::NewGuid().ToString("N")).tok"
                    [System.IO.File]::WriteAllText($elevTokenFile, $elevationTokenContent, [System.Text.Encoding]::UTF8)
                    # 🔒 M-5：为令牌文件设置 ACL，仅允许当前用户访问，防止其他进程读取/替换
                    try {
                        $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                        $acl = Get-Acl $elevTokenFile
                        $acl.SetAccessRuleProtection($true, $false)
                        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                            $currentIdentity.User, "FullControl", "Allow")
                        $acl.AddAccessRule($rule)
                        Set-Acl -Path $elevTokenFile -AclObject $acl
                    } catch {}
                    
                    $arguments += " -ElevationTokenPath `"$elevTokenFile`""
                    
                    $psi.Arguments = $arguments
                    
                    # 启动提权进程
                    [System.Diagnostics.Process]::Start($psi)
                    
                    if ($Language -eq "CHS") {
                        $global:syncHash.LogOutput += "✅ 提权进程已启动，当前实例将在 3 秒后关闭`n"
                    } else {
                        $global:syncHash.LogOutput += "✅ Elevated process started, current instance will close in 3s`n"
                    }
                    
                    # 等待 3 秒后关闭当前实例
                    $proExitTimer1 = New-Object System.Windows.Forms.Timer
                    $proExitTimer1.Interval = 3000
                    $proExitTimer1.Add_Tick({
                        $timer = $this
                        $timer.Stop(); $timer.Dispose()
                        $proForm.Close()
                        [System.Environment]::Exit(0)
                    })
                    $proExitTimer1.Start()
                    
                } catch {
                    $errorMsg = if ($Language -eq "CHS") { "提权失败：$($_.Exception.Message)" } else { "Elevation failed: $($_.Exception.Message)" }
                    [System.Windows.Forms.MessageBox]::Show($errorMsg, "Error", "OK", "Error")
                    $global:syncHash.ElevationAuthorized = $null
                    $script:IsModalShowing = $false
                }
            } else {
                # 用户拒绝提权
                $global:syncHash.ElevationAuthorized = $false
                $script:IsModalShowing = $false
                
                if ($Language -eq "CHS") {
                    $global:syncHash.LogOutput += "⏭️ 用户拒绝提权，将继续以普通用户模式运行`n"
                } else {
                    $global:syncHash.LogOutput += "⏭️ User denied elevation, will continue with standard user mode`n"
                }
            }
        }
        
        # ====== 新增：检测智能分析请求并显示对话框 ======
        # 💥 核心修复：移除 Tag 检查，仅依赖 IsModalShowing 标志，防止历史状态污染
        if ($global:syncHash.SmartAnalysisRequested -eq $true -and 
            $script:IsModalShowing -ne $true) {
            
            # 💥 核心修复：强制清除 Tag 状态，防止历史状态污染
            if ($DecisionModal.Tag -eq "SmartAnalysis_Shown") {
                if ($Language -eq "CHS") {
                    $global:syncHash.LogOutput += "⚠️ 检测到 DecisionModal 智能分析状态异常，强制重置...`n"
                } else {
                    $global:syncHash.LogOutput += "⚠️ DecisionModal smart analysis state anomaly detected, forcing reset...`n"
                }
            }
            $DecisionModal.Tag = $null
            
            # 停止可能正在进行的退出动画，防止动画冲突
            Stop-AllAnimations -Control $DecisionModal
            
            # 设置互斥锁
            $script:IsModalShowing = $true
            $DecisionModal.Tag = "SmartAnalysis_Shown"
            
            # 构造智能分析的双语文本
            if ($Language -eq "CHS") {
                $actionStr = "动作：智能诊断分析"
                $riskStr = "风险评估：Low"
            } else {
                $actionStr = "Action: Smart Diagnostic Analysis"
                $riskStr = "Risk Assessment: Low"
            }
            
            # 推送给控件重绘
            $DecisionModal.UpdateInfo($actionStr, $riskStr, $Language)
            
            # 全屏遮罩直接淡入
            $DecisionModal.BringToFront()
            $DecisionModal.FadeInModal()
            
            # 💥 新增：添加调试日志确认 HUD 已拉起
            if ($Language -eq "CHS") {
                $global:syncHash.LogOutput += "✅ 智能分析 HUD 已成功拉起`n"
            } else {
                $global:syncHash.LogOutput += "✅ Smart analysis HUD displayed successfully`n"
            }
        }
        
        # ====== 新增：检测已导出日志确认请求并显示 HUD ======
        if ($global:syncHash.RequiresUserInput -eq $true -and 
            $global:syncHash.InputType -eq "UseExportedLogs" -and 
            $script:IsModalShowing -ne $true) {
            
            # 设置互斥锁
            $script:IsModalShowing = $true
            $ExportedLogsModal.Tag = "Shown"
            
            # 从 InputData 获取信息
            $inputData = $global:syncHash.InputData
            if ($inputData) {
                $fileCount = $inputData.FileCount
                $fileAge = $inputData.FileAge
                $exportPath = $inputData.ExportPath
                $fileNames = $inputData.CsvFiles | Select-Object -ExpandProperty Name
                
                # 推送给控件重绘
                $ExportedLogsModal.UpdateInfo($fileCount, $fileAge, $exportPath, $fileNames, $Language)
                
                # 全屏遮罩直接淡入
                $ExportedLogsModal.BringToFront()
                $ExportedLogsModal.FadeInModal()
                
                if ($Language -eq "CHS") {
                    $global:syncHash.LogOutput += "✅ 已导出日志确认 HUD 已显示`n"
                } else {
                    $global:syncHash.LogOutput += "✅ Exported logs confirmation HUD displayed`n"
                }
            }
        }
        
        # ====== 新增：检测执行结果并显示 ======
        if ($global:syncHash.CommandResult) {
            # 停止可能正在进行的退出动画，防止动画冲突
            Stop-AllAnimations -Control $ResultModal
            
            $resultData = $global:syncHash.CommandResult
            
            if ($resultData) {
                # 推送给控件重绘
                $ResultModal.UpdateInfo($resultData.ActionName, $resultData.Result, $resultData.Output, $resultData.ExecutionTime, $Language)
                
                # 全屏遮罩直接淡入
                $ResultModal.BringToFront()
                $ResultModal.FadeInModal()
                
                # 清除结果数据，防止重复显示
                $global:syncHash.CommandResult = $null
            }
        }
        
        if ($global:syncHash.IsRunning -or $global:syncHash.LogOutput.Length -gt 0) {
            # 1. 更新控制台/文本框输出 (💥修复：消除换行符差异导致的无限重绘假死)
            $currentLog = $global:syncHash.LogOutput
            if ($currentLog -ne $null) {
                # 统一换行符进行严格比对
                $boxText = $consoleBox.Text -replace "`r`n", "`n"
                $hashLog = $currentLog -replace "`r`n", "`n"
                if ($boxText -ne $hashLog) {
                    $consoleBox.Text = $currentLog
                    $consoleBox.SelectionStart = $consoleBox.Text.Length
                    $consoleBox.ScrollToCaret()
                    $consoleBox.Invalidate()
                    #$proForm.Refresh()
                    [System.Windows.Forms.Application]::DoEvents()
                }
            }
            
            # ====== 核心升级：动态同步专业阶段标题与精细子任务 ======
            if ($null -ne $global:syncHash.CurrentActivity) {
                
                # 1. 文本净化：去掉【 和 】, 保留中间的字并加一个空格
                # 例如 "【1/4】初始化" 会变成 "1/4 初始化"
                $cleanActivity = $global:syncHash.CurrentActivity -replace '【', '' -replace '】', ' '
                
                # 2. 状态拼接：如果有更精细的子任务描述，拼接到后面
                $fineStatus = ""
                if (-not [string]::IsNullOrWhiteSpace($global:syncHash.CurrentStatus)) {
                    $fineStatus = " - $($global:syncHash.CurrentStatus)"
                }
                
                # 最终展示文本
                $finalDisplayText = "$cleanActivity$fineStatus"
                
                # 3. 避免重复渲染导致闪烁
                if ($finalDisplayText -ne $script:lastActivity) {
                    $script:lastActivity = $finalDisplayText
                    Update-StarfieldStatusText -Panel $proBackground -NewText $finalDisplayText
                }
            }
            
            # 2. 更新 AuroraProgressBar
            if ($null -ne $proProgressBar -and -not $proProgressBar.IsDisposed -and $proProgressBar.Value -ne $global:syncHash.Progress) {
                $proProgressBar.Value = $global:syncHash.Progress
            }
            
            # 3. 处理完成状态
            if ($global:syncHash.ScriptDone) {
                # 🔧 核心修复 1/2：在恢复 UI 状态之前，强制清除可能残留的 RequiresUserInput 标志
                if ($global:syncHash.RequiresUserInput -eq $true -or $global:syncHash.InputType -eq "UseExportedLogs") {
                    if ($Language -eq "CHS") {
                        $global:syncHash.LogOutput += "⚠️ [ScriptDone] 检测到残留的 RequiresUserInput/InputType 标志，强制清除...`n"
                    } else {
                        $global:syncHash.LogOutput += "⚠️ [ScriptDone] Detected残留 RequiresUserInput/InputType flags, forcing clear...`n"
                    }
                    $global:syncHash.RequiresUserInput = $false
                    $global:syncHash.InputType = $null
                    $global:syncHash.InputData = $null
                    $global:syncHash.UserInput = $null
                }
                
                # 🔧 调试：记录 IsModalShowing 状态
                if ($Language -eq "CHS") {
                    if ($script:IsModalShowing -eq $true) {
                        # 🔧 核心修复 3/3：检查是否有 Modal 真正在显示
                        $hasShowingModal = ($RestoreModal.Tag -eq "Shown" -or 
                                           $DecisionModal.Tag -eq "Shown" -or 
                                           $DecisionModal.Tag -eq "SmartAnalysis_Shown" -or 
                                           $ExportedLogsModal.Tag -eq "Shown")
                        
                        if (-not $hasShowingModal) {
                            $script:IsModalShowing = $false
                        }
                    }
                } else {
                    if ($script:IsModalShowing -eq $true) {
                        # 🔧 Core Fix 3/3: Check if any Modal is actually showing
                        $hasShowingModal = ($RestoreModal.Tag -eq "Shown" -or 
                                           $DecisionModal.Tag -eq "Shown" -or 
                                           $DecisionModal.Tag -eq "SmartAnalysis_Shown" -or 
                                           $ExportedLogsModal.Tag -eq "Shown")
                        
                        if (-not $hasShowingModal) {
                            $script:IsModalShowing = $false
                        }
                    }
                }
                
                # 恢复 UI 状态，例如启用开始按钮
                $global:syncHash.ScriptDone = $false # 重置状态
                $timestamp = [datetime]::Now.ToString('HH:mm:ss')
                if ($Language -eq "CHS") {
                    $global:syncHash.LogOutput += "`n[$timestamp] ✅ 系统任务执行完毕`n"
                    $global:syncHash.LogOutput += "`n✅ 分析任务已结束，请按关闭按钮退出。您可在当前目录的UserLogs文件夹中查看结果。`n"
                } else {
                    $global:syncHash.LogOutput += "`n[$timestamp] ✅ System Task Completed.`n"
                    $global:syncHash.LogOutput += "`n✅ Analysis task completed. Please click the Close button to exit. You can view the results in the UserLogs folder in the current directory.`n"
                }
                
                if ($Language -eq "CHS") {
                    Update-StarfieldStatusText -Panel $proBackground -NewText "完成"
                    $proTitleLabel.Text = "$Title - 完成"
                } else {
                    Update-StarfieldStatusText -Panel $proBackground -NewText "Complete"
                    $proTitleLabel.Text = "$Title - Complete"
                }
                
                if ($null -ne $proProgressBar -and -not $proProgressBar.IsDisposed) {
                    $proProgressBar.Value = 100
                }
                
                # 任务正常完成后，让按钮自动变身并启用
                if ($Language -eq "CHS") { $actionButton.Text = "关闭-Close" } else { $actionButton.Text = "Close" }
                $actionButton.Tag = "Close"
                $actionButton.Enabled = $true
                $actionButton.Invalidate()  # 强制重绘以显示新文字
                
                # 🔧 显示完成提示：是否打开 UserLogs 文件夹
                # 注意：完成提示模式不检查 Tag，只检查 IsModalShowing 状态
                if ($script:IsModalShowing -ne $true) {
                    $script:IsModalShowing = $true
                    $userLogsPath = [System.IO.Path]::Combine($ScriptsDir, "..\UserLogs")
                    $ExportedLogsModal.ShowCompletionPrompt($userLogsPath, $Language)
                    $ExportedLogsModal.BringToFront()
                } else {
                }
            }

            # ====== 新增：AuroraTaskHUD 状态更新 ======
            if ($null -ne $global:syncHash.CurrentPipelineStep) {
                $stepIndex = $global:syncHash.CurrentPipelineStep
                
                # 如果步骤为 -1，代表任务结束或被取消，优雅隐藏 HUD
                if ($stepIndex -eq -1) {
                    if ($TaskHUD.Tag -eq "Shown") {
                        $TaskHUD.Tag = $null
                        Start-UwpExitAnimation -Control $TaskHUD -DurationMs 350 -OffsetY 30 -EndScale 0.8
                    }
                } else {
                    # 当引擎开始运作时，显示 HUD
                    if ($TaskHUD.Tag -ne "Shown") {
                        $TaskHUD.Tag = "Shown"
                        $TaskHUD.Visible = $true
                        Start-UwpEnterAnimation -Control $TaskHUD -TargetLocation $TaskHUD.Location -ParentForm $proForm -DurationMs 450 -OffsetY 50 -DelayMs 0 -StartScale 0.8
                    }

                    # 更新任务状态
                    $status = $global:syncHash.CurrentPipelineStatus
                    $detailText = if ($null -ne $global:syncHash.CurrentPipelineDetail) { $global:syncHash.CurrentPipelineDetail } else { "" }
                    
                    if ($detailText -eq "" -and $null -ne $global:syncHash.PendingCommand) {
                        $detailText = if ($Language -eq "CHS") { $global:syncHash.PendingCommand.name } else { $global:syncHash.PendingCommand.name_en }
                    }

                    if ($status -eq "Running") {
                        $TaskHUD.SetStepStatus($stepIndex, 1, $detailText) # Running
                    } elseif ($status -eq "Success") {
                        $TaskHUD.SetStepStatus($stepIndex, 2, $detailText) # Success
                    } elseif ($status -eq "Error") {
                        $TaskHUD.SetStepStatus($stepIndex, 3, $detailText) # Error
                    } else {
                        $TaskHUD.SetStepStatus($stepIndex, 0, $detailText) # Pending
                    }
                }
            }
        }
    }.GetNewClosure())
    
    # ====== 新增：在窗体显示前，先隐藏所有参与动效的控件，彻底杜绝闪烁 ======
    $animControls = @($proTitleLabel, $consoleBox, $proProgressBar, $inputPanelLabel, $inputTextBox, $sendButton, $hintLabel, $actionButton, $privilegeIndicator)
    foreach ($c in $animControls) { if ($null -ne $c) { $c.Visible = $false } }

    $proForm.Add_Shown({
        # 1. 启动窗体级淡入 (耗时约 450ms，此时子控件为 Visible = false，绝对不会闪烁)
        Start-MainWindowAnimation -Form $proForm
        
        # 2. 挂起布局，瞬间将控件压扁为 0，然后恢复可见性
        $proForm.SuspendLayout()
        
        Start-UwpEnterAnimation -Control $proTitleLabel -TargetLocation $proTitleLabel.Location -ParentForm $proForm -DurationMs 450 -OffsetY 40 -DelayMs 50
        Start-UwpEnterAnimation -Control $consoleBox -TargetLocation $consoleBox.Location -ParentForm $proForm -DurationMs 450 -OffsetY 60 -DelayMs 100
        Start-UwpEnterAnimation -Control $proProgressBar -TargetLocation $proProgressBar.Location -ParentForm $proForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        Start-UwpEnterAnimation -Control $inputPanelLabel -TargetLocation $inputPanelLabel.Location -ParentForm $proForm -DurationMs 350 -OffsetY 40 -DelayMs 200
        Start-UwpEnterAnimation -Control $inputTextBox -TargetLocation $inputTextBox.Location -ParentForm $proForm -DurationMs 350 -OffsetY 40 -DelayMs 250
        Start-UwpEnterAnimation -Control $sendButton -TargetLocation $sendButton.Location -ParentForm $proForm -DurationMs 350 -OffsetY 40 -DelayMs 300
        Start-UwpEnterAnimation -Control $hintLabel -TargetLocation $hintLabel.Location -ParentForm $proForm -DurationMs 350 -OffsetY 40 -DelayMs 350
        Start-UwpEnterAnimation -Control $actionButton -TargetLocation $actionButton.Location -ParentForm $proForm -DurationMs 400 -OffsetY 50 -DelayMs 400
        Start-UwpEnterAnimation -Control $privilegeIndicator -TargetLocation $privilegeIndicator.Location -ParentForm $proForm -DurationMs 350 -OffsetY 30 -DelayMs 450
        # 提权按钮（仅在普通模式下存在）
        if ($null -ne $elevateMiniButton) {
            Start-UwpEnterAnimation -Control $elevateMiniButton -TargetLocation $elevateMiniButton.Location -ParentForm $proForm -DurationMs 350 -OffsetY 30 -DelayMs 500
        }

        # 将压扁后的控件设为可见，此时尺寸全为 0，所以肉眼依旧看不见
        foreach ($c in $animControls) { if ($null -ne $c) { $c.Visible = $true } }
        $proForm.ResumeLayout()

        # 3. 核心优化：快速启动引擎（减少等待时间，优化初始化流程）
        $engineInitTimer = New-Object System.Windows.Forms.Timer
        $engineInitTimer.Interval = 200
        $engineInitTimer.Add_Tick({
            $this.Stop()
            $this.Dispose()

            try {
                # 提前检查文件，减少延迟
                if (-not (Test-Path $ScriptPath)) {
                    if ($Language -eq "CHS") { Append-Output "`r`n错误: 脚本文件不存在: $ScriptPath`r`n" } 
                    else { Append-Output "`r`nError: Script file not found: $ScriptPath`r`n" }
                    Update-StarfieldStatusText -Panel $proBackground -NewText "发生错误"
                    $proTitleLabel.Text = "$Title - 错误"
                    $proProgressBar.Value = 100
                    $actionButton.Enabled = $true
                    return
                }

                if ($global:syncHash.IsRunning) { return }
                
                # ====== 【核心修复 3/3】先检测会话，如果有会话则暂停启动，等待用户选择 ======
                # 说明：改为同步检测会话，确保 HUD 优先显示，避免与 PRO 脚本的会话检测竞争
                $hasPendingSession = $false
                
                # 【关键修复】重置互斥锁和 Tag，确保 HUD 能够正常弹出
                $script:IsModalShowing = $false
                if ($null -ne $RestoreModal) {
                    $RestoreModal.Tag = $null
                }
                
                try {
                    # 直接在主线程检测会话（同步）- 使用点号导入替代 Invoke-Expression
                    . "$ScriptsDir\Session\AURORA-ProgressManager.ps1"
                    
                    if (Test-PendingSession) {
                        $restoredSession = Restore-SessionProgress
                        if ($restoredSession) {
                            $hasPendingSession = $true
                            $global:syncHash.RestoredSessionId = $restoredSession.SessionId
                            $global:syncHash.RestoredStage = $restoredSession.Stage
                            $global:syncHash.RestoredProgress = $restoredSession.Progress
                            $global:syncHash.RestoredLastUpdated = $restoredSession.LastUpdated
                            $global:syncHash.RestoredAgeInDays = $restoredSession.AgeInDays
                            $global:syncHash.HasPendingSession = $true
                            
                            if ($Language -eq "CHS") {
                                $global:syncHash.LogOutput = "💻 硬件评估层级: [$global:AuroraPerfTier]`n"
                                $global:syncHash.LogOutput += "🚀 开始初始化分析引擎...`n"
                            } else {
                                $global:syncHash.LogOutput = "💻 Hardware Tier: [$global:AuroraPerfTier]`n"
                                $global:syncHash.LogOutput += "🚀 Initializing analysis engine...`n"
                            }
                        }
                    }
                } catch {
                    if ($Language -eq "CHS") {
                        $global:syncHash.LogOutput += "⚠️ 检测会话进度失败：$_`n"
                    } else {
                        $global:syncHash.LogOutput += "⚠️ Session detection failed: $_`n"
                    }
                }
                
                # 启动 UI Timer
                $uiTimer.Start()
                
                if ($Language -eq "CHS") {
                    Append-Output "正在启动 $Title...`r`n"
                    if (-not $hasPendingSession) {
                        $global:syncHash.LogOutput = "💻 硬件评估层级: [$global:AuroraPerfTier]`n"
                        $global:syncHash.LogOutput += "🚀 开始初始化分析引擎...`n"
                    }
                    Update-StarfieldStatusText -Panel $proBackground -NewText "引擎启动中..."
                } else {
                    Append-Output "Starting $Title...`r`n"
                    if (-not $hasPendingSession) {
                        $global:syncHash.LogOutput = "💻 Hardware Tier: [$global:AuroraPerfTier]`n"
                        $global:syncHash.LogOutput += "🚀 Initializing analysis engine...`n"
                    }
                    Update-StarfieldStatusText -Panel $proBackground -NewText "Engine Starting..."
                }
                $proProgressBar.Value = 30
                
                # 初始化 syncHash
                $global:syncHash.IsRunning = $true
                $global:syncHash.ScriptDone = $false
                $global:syncHash.Progress = 0
                $global:syncHash.UserInput = $null
                $global:syncHash.Authorized = $null
                $global:syncHash.RequiresAuthorization = $null
                $global:syncHash.PendingCommand = $null
                # 【关键】添加 PRO 脚本会话恢复标志
                $global:syncHash.ShowSessionRecoveryHUD = $false
                $global:syncHash.SessionRestored = $false
                $global:syncHash.SessionRestarted = $false
                
                # 显示管理员权限状态提示
                if ($Language -eq "CHS") {
                    if ($global:syncHash.IsAdmin) {
                        $global:syncHash.LogOutput += "✅ 管理员权限：已获取 - 全部功能可用`n"
                    } else {
                        $global:syncHash.LogOutput += "⚠️ 管理员权限：未获取 - 部分功能受限`n"
                        $global:syncHash.LogOutput += "💡 提示：右键点击 AURORA-Analyzer.exe，选择'以管理员身份运行'可获取完整权限`n"
                    }
                } else {
                    if ($global:syncHash.IsAdmin) {
                        $global:syncHash.LogOutput += "✅ Administrator Privileges: Granted - All features available`n"
                    } else {
                        $global:syncHash.LogOutput += "⚠️ Administrator Privileges: Not Granted - Some features limited`n"
                        $global:syncHash.LogOutput += "💡 Hint: Right-click AURORA-Analyzer.exe and select 'Run as administrator' for full access`n"
                    }
                }
                
                # 提取 GUI 控件参数 
                $guiParams = @{
                    LogType = ""; Level = ""; EventId = ""; ProviderName = ""; StartTime = $null; EndTime = $null; FromGUI = $FromGUI
                }
                
                $workDir = Split-Path -Path $ScriptPath -Parent

                # ==========================================
                # 优化：快速创建后台 Runspace
                # ==========================================
                # 🔴 P0 修复：先检查 AuroraGuard 是否存在，防止绕过安全检测
                try {
                    # 修复：使用 -as [type] 检查类型是否存在（更可靠）
                    $guardType = 'AuroraGuard' -as [type]
                    if ($guardType -eq $null) {
                        # 二次检查：尝试直接使用 [AuroraGuard]
                        try {
                            [AuroraGuard]::GetDetectionReason() | Out-Null
                            $guardType = [AuroraGuard]
                        } catch {
                            Write-Host "[ShowProMode] AuroraGuard 未加载，拒绝进入 PRO 模式" -ForegroundColor Red
                            [System.Windows.Forms.MessageBox]::Show(
                                "安全守卫未初始化，无法进入 PRO 模式",
                                "安全错误",
                                [System.Windows.Forms.MessageBoxButtons]::OK,
                                [System.Windows.Forms.MessageBoxIcon]::Error
                            )
                            return
                        }
                    }
                    
                    $detectionReason = [AuroraGuard]::GetDetectionReason()
                    if ($detectionReason -ne "NONE") {
                        Write-Host "[安全守卫] 检测到威胁：$detectionReason" -ForegroundColor Red
                        
                        if (-not $script:ExitCountdownStarted) {
                            $script:ExitCountdownStarted = $true
                            
                            $reasonText = switch ($detectionReason) {
                                "DEBUGGER_API" { "调试器 API 检测" }
                                "DEBUGGER_PROCESS" { "调试工具进程检测" }
                                "DLL_INJECTION" { "DLL 注入检测" }
                                "INTEGRITY_FAILURE" { "文件完整性验证失败" }
                                default { "未知威胁" }
                            }
                            
                            Write-Host "[Security Alert] 检测到调试或注入，程序将在 15 秒后退出..." -ForegroundColor Red
                            [AuroraExitCountdown]::Show(
                                " 安全警报：$reasonText！",
                                " Security Alert: $detectionReason!",
                                "检测到程序正在被调试或注入：$reasonText`n`n程序将在 15 秒后自动退出。",
                                "Debugging or injection detected: $reasonText`n`nProgram will exit in 15 seconds.",
                                15,
                                $true,
                                $UseChinese
                            )
                        }
                        
                        $global:syncHash.LogOutput += "`n[安全守卫] 检测到运行环境威胁，已阻止进入 PRO 模式`n"
                        $global:syncHash.IsRunning = $false
                        $proProgressBar.Value = 100
                        $actionButton.Enabled = $true
                        if ($Language -eq "CHS") {
                            Update-StarfieldStatusText -Panel $proBackground -NewText "安全守卫已拦截"
                            $proTitleLabel.Text = "$Title - 已拦截"
                        } else {
                            Update-StarfieldStatusText -Panel $proBackground -NewText "Blocked by Guard"
                            $proTitleLabel.Text = "$Title - Blocked"
                        }
                        return
                    }
                } catch { 
                    Write-Host "[ShowProMode] 完整性守卫未初始化（降级模式）" -ForegroundColor DarkGray
                }
                $runspace = [runspacefactory]::CreateRunspace()
                $runspace.ApartmentState = "STA"  # 改为STA以更好地支持启动Windows GUI应用程序
                $runspace.ThreadOptions = "ReuseThread"
                $runspace.Open()
                
                $ps = [powershell]::Create().AddScript({
                    param($path, $workingDirectory, $paramsFromGUI, $hash, $Language, $PerfTier)
                    try {
                        $global:syncHash = $hash
                        function global:Write-Host {
                            [CmdletBinding()]
                            param (
                                [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)] $Object ,
                                [switch]$NoNewline ,
                                $ForegroundColor ,
                                $BackgroundColor
                            )
                            $text = if ($null -ne $Object) { $Object -join ' ' } else { ''  }
                            
                            # === 🚀 核心修复：精准的 ANSI/OSC 剥离正则 ===
                            # 1. 剥离标准的 CSI 序列 (如颜色 \x1b[31m, 清屏等)
                            #    只匹配真正有数字参数的转义序列，避免误匹配 [R 这样的正常文本
                            $text = $text -replace '(?:\x1B|`e|\\e|←)\[\d+(?:;\d+)*[a-zA-Z]', ''
                            
                            # 2. 剥离特殊的 OSC 序列 (如终端下发的当前路径通知 \x1b]9;4;9;"file://..."\x07)
                            $text = $text -replace '(?:\x1B|`e|\\e|←)\][\s\S]*?(?:\x07|\x1B\\|`e\\|\\e\\)', ''
                            # ===================================================

                            if (-not $NoNewline) { $text += "`n"  }
                            $global:syncHash.LogOutput += $text
                        }
                        Set-Location -Path $workingDirectory
                        
                        if ($Language -eq "CHS") { $hash.LogOutput += "⚙️ 参数交接成功，正在启动核心脚本...`n" } 
                        else { $hash.LogOutput += "⚙️ Parameter handover successful, starting core script...`n" }
                        
                        $scriptArgs = @{ GUI_Mode = $true; Language = $Language; PerfTier = $PerfTier }
                        if (-not [string]::IsNullOrWhiteSpace($paramsFromGUI.LogType)) { $scriptArgs["LogType"] = $paramsFromGUI.LogType }
                        if (-not [string]::IsNullOrWhiteSpace($paramsFromGUI.Level) -and $paramsFromGUI.Level -ne "All") { $scriptArgs["Level"] = $paramsFromGUI.Level }
                        if (-not [string]::IsNullOrWhiteSpace($paramsFromGUI.EventId)) { $scriptArgs["EventId"] = $paramsFromGUI.EventId }
                        if (-not [string]::IsNullOrWhiteSpace($paramsFromGUI.ProviderName)) { $scriptArgs["ProviderName"] = $paramsFromGUI.ProviderName }
                        if ($null -ne $paramsFromGUI.StartTime) { $scriptArgs["StartTime"] = $paramsFromGUI.StartTime }
                        if ($null -ne $paramsFromGUI.EndTime) { $scriptArgs["EndTime"] = $paramsFromGUI.EndTime }
                        
                        # 💥 核心升级：传递 FromGUI 参数（智能模式专用）
                        if ($paramsFromGUI.FromGUI) { $scriptArgs["FromGUI"] = $true }
                        
                        & $path @scriptArgs
                        
                    } catch {
                        $hash.LogOutput += "❌ 后台执行发生严重错误:`n$($_.Exception.Message)`n"
                    } finally {
                        $hash.ScriptDone = $true
                        $hash.IsRunning = $false
                    }
                }).AddArgument($ScriptPath).AddArgument($workDir).AddArgument($guiParams).AddArgument($global:syncHash).AddArgument($Language).AddArgument($global:AuroraPerfTier)
                
                $ps.Runspace = $runspace
                $asyncResult = $ps.BeginInvoke()
                
                $global:ActiveRunspace = $runspace
                $global:ActivePS = $ps
                
                # 更新进度条
                $proProgressBar.Value = 50
                
                # 更新状态文本
                if ($Language -eq "CHS") {
                    Update-StarfieldStatusText -Panel $proBackground -NewText "运行中..."
                } else {
                    Update-StarfieldStatusText -Panel $proBackground -NewText "Running..."
                }

            } catch {
                $global:syncHash.LogOutput += "`n❌ GUI主线程触发后台时发生异常: $($_.Exception.Message)`n"
                $global:syncHash.IsRunning = $false
                $proProgressBar.Value = 100
                $actionButton.Enabled = $true
            }
        })
        $engineInitTimer.Start()
    })

    # ====== 新增：在窗体显示前隐藏所有动效控件，彻底消除第一帧的闪烁 ======
    $animControls = @($proTitleLabel, $consoleBox, $proProgressBar, $inputPanelLabel, $inputTextBox, $sendButton, $hintLabel, $actionButton)
    foreach ($c in $animControls) { if ($null -ne $c) { $c.Visible = $false } }



    # ====== 核心修复：使用 Show() + 手动阻塞，而不是 ShowDialog() ======
    # 原因：ShowDialog() 创建的模态窗口可能与动画系统冲突
    # 正确做法：使用 Show() 显示窗体，然后用信号量阻塞等待窗体关闭
    $proForm.Opacity = 0.0

    # 🔐 安全增强：注册二级窗体到全局，供完整性检查识别并正确关闭
    $global:proForm = $proForm

    # 添加 FormClosing 事件标记
    $proForm.Add_FormClosing({
        # 标记窗体即将关闭
        $script:proFormClosing = $true
    })

    # 运行消息循环 - 使用 Show() + 手动阻塞
    $script:proFormClosing = $false
    $proForm.Show()
    
    # 使用 DoEvents 循环等待窗体关闭
    while (-not $script:proFormClosing) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 50
    }
    

    # 清理
    $uiTimer.Stop()
    $uiTimer.Dispose()
    
    if ($global:ActivePS -and -not $global:ActivePS.IsCompleted) {
        try { $global:ActivePS.Stop() } catch { Write-AuroraLog "PowerShell进程终止失败: $($_.Exception.Message)" -Level "Warning" }
    }
    if ($global:ActivePS) {
        $global:ActivePS.Dispose()
    }
    if ($global:ActiveRunspace) {
        $global:ActiveRunspace.Close()
        $global:ActiveRunspace.Dispose()
    }
    $proForm.Dispose()

    # 清理变量
    $global:ActivePS = $null
    $global:ActiveRunspace = $null

    # 重置同步哈希表
    $global:syncHash.IsHostAlive = $true
    $global:syncHash.IsRunning = $false
    $global:syncHash.LogOutput = ""
    $global:syncHash.Progress = 0
    $global:syncHash.UserInput = $null
    $global:syncHash.ScriptDone = $false
    $global:syncHash.HasPendingSession = $false
    $global:syncHash.ShowSessionRecoveryHUD = $false
    $global:syncHash.SessionRestored = $false
    $global:syncHash.SessionRestarted = $false
    $global:syncHash.RestoredSessionId = $null
    $global:syncHash.RestoredStage = 0
    $global:syncHash.RestoredProgress = 0
    $global:syncHash.RestoredLastUpdated = $null
    $global:syncHash.RestoredAgeInDays = $null
    $global:syncHash.Authorized = $null
    $global:syncHash.RequiresAuthorization = $null
    $global:syncHash.PendingCommand = $null
    $script:IsModalShowing = $false
    $global:IsViewTransitioning = $false
    $script:launched = $false
    
    # 🔐 安全增强：清理二级窗体全局引用
    $global:proForm = $null
    
    # 🔴 关键修复：清理看门狗 Runspace 和管道对象，防止残留导致下次启动失败
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
}
