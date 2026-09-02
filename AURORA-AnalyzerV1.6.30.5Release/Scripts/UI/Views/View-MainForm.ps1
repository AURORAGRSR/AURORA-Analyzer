<#
.SYNOPSIS
    AURORA 主语言选择窗口
.DESCRIPTION
    主语言选择窗口（固定尺寸 400x480，无边框）
.NOTES
    版本：V1.6.30.5Release | 构建时间：2026.09.02
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>
# ====== 主语言选择窗口（固定尺寸 400x480，无边框）======
function ShowMainForm {
    # 🔴 修复：获取 Scripts 目录用于构建脚本路径（不覆盖主文件的 $scriptDir）
    $ScriptsDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)  # 从 PSScriptRoot 直接计算，向上两级到 Scripts 目录
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "AURORA System Log Analyzer>>>Select Language • 选择语言"
    $form.ClientSize = New-Object System.Drawing.Size(400, 480)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'None'  # ←←← 关键：无边框
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::Black

    # === 替换背景：使用 StarfieldPanel ===
    $background = New-Object StarfieldPanel
    $background.Dock = "Fill"
    $form.Controls.Add($background)

    # ====== 支持无边框窗口拖拽 ======
    $dragAction = {
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            [Win32Helper]::ReleaseCapture()
            # 让系统认为当前按住的是标题栏
            [Win32Helper]::SendMessage($form.Handle, [Win32Helper]::WM_NCLBUTTONDOWN, [Win32Helper]::HT_CAPTION, 0)
        }
    }
    $background.Add_MouseDown($dragAction)

    # === 清除主窗口 StarfieldPanel 的默认加载文本 ===
    #Update-StarfieldStatusText -Panel $background -NewText ""

    # 按钮创建函数
    function CreateButton {
        param(
            [string]$Text,
            [int]$TargetTop
        )
        $btn = New-Object TechButton
        $btn.Text = $Text
        
        # === 关键：禁用自动大小和布局 ===
        $btn.AutoSize = $false
        $btn.Anchor = 'None'
        
        # === 关键：使用 SetBounds 强制固定位置和尺寸 ===
        $btn.SetBounds(60, $TargetTop - 20, 280, 48)
        
        # 初始隐藏
        $btn.Visible = $false
        
        return $btn
    }

    # ====== 视图 1：语言选择（3个元素）======
    # 标题（UWP自绘控件）
    $titleLabel = New-Object UWPText
    $titleLabel.TextOnly = "请根据当前系统环境选择语言版本"
    $titleLabel.Location = New-Object System.Drawing.Point(60, 45)
    $titleLabel.Size = New-Object System.Drawing.Size(280, 45)
    $titleLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 12, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $titleLabel.BackColor = [System.Drawing.Color]::Transparent
    $titleLabel.TextAlign = [System.Drawing.StringAlignment]::Center
    $titleLabel.Visible = $false
    $titleLabel.Anchor = 'None'
    $titleLabel.Add_MouseDown($dragAction)
    $background.Controls.Add($titleLabel)

    $btnEng = CreateButton -Text "English" -TargetTop 180
    $btnChs = CreateButton -Text "简体中文" -TargetTop 260 
    $btnExit = CreateButton -Text "退出-Exit" -TargetTop 340 

    # 设置 Tab 键顺序
    $btnEng.TabIndex = 0
    $btnChs.TabIndex = 1
    $btnExit.TabIndex = 2

    # ====== 视图 2：模式选择（4个元素）======
    $styleTitleLabel = New-Object UWPText
    $styleTitleLabel.TextOnly = "请选择模式 / Select Mode"
    $styleTitleLabel.Location = New-Object System.Drawing.Point(40, 45)
    $styleTitleLabel.Size = New-Object System.Drawing.Size(320, 45)
    $styleTitleLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 12, [System.Drawing.FontStyle]::Bold)
    $styleTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $styleTitleLabel.BackColor = [System.Drawing.Color]::Transparent
    $styleTitleLabel.TextAlign = [System.Drawing.StringAlignment]::Center
    $styleTitleLabel.Visible = $false
    $styleTitleLabel.Anchor = 'None'
    $styleTitleLabel.Add_MouseDown($dragAction)
    $background.Controls.Add($styleTitleLabel)

    $btnSmart = CreateButton -Text "智能诊断与自主修复模式"  -TargetTop 110
    $btnGUI = CreateButton -Text "专业图形模式"  -TargetTop 190
    $btnConsole = CreateButton -Text "控制台模式" -TargetTop 270 
    $btnBack = CreateButton -Text "返回" -TargetTop 350 

    # 设置 Tab 键顺序
    $btnSmart.TabIndex = 0
    $btnGUI.TabIndex = 1
    $btnConsole.TabIndex = 2
    $btnBack.TabIndex = 3

    $script:selectedLanguage = ""
    $script:selectedMode = ""
    $script:launched = $false
    # 新增：用于跟踪当前所处的视图层级 (1=语言选择, 2=模式选择, 3=智能模式子菜单)
    $script:currentView = 1

    # ====== P1-2: Timer 生命周期集中管理 ======
    $script:ActiveTimers = [System.Collections.Generic.List[System.Windows.Forms.Timer]]::new()

    function Register-AuroraTimer {
        [CmdletBinding()]
        param([System.Windows.Forms.Timer]$Timer)
        $script:ActiveTimers.Add($Timer)
        return $Timer
    }

    function Dispose-AllAuroraTimers {
        foreach ($timer in $script:ActiveTimers) {
            try {
                $timer.Stop()
                $timer.Dispose()
            } catch {
                Write-AuroraLog "Timer dispose failed: $($_.Exception.Message)" -Level "Warning"
            }
        }
        $script:ActiveTimers.Clear()
    }

    # 通用退出动画函数
    function Start-ExitAnimationSequence {
        param(
            [System.Windows.Forms.Form]$Form,
            [System.Windows.Forms.Control]$TitleLabel,
            [System.Windows.Forms.Control]$BtnSmart,
            [System.Windows.Forms.Control]$BtnEng,
            [System.Windows.Forms.Control]$BtnChs,
            [System.Windows.Forms.Control]$BtnExit
        )
        
        try {
            # 启动退出动画 - 关键：设置 StaggerDelay (延迟) 和 IsButton 标志
            # 标题：无延迟，普通飞出
            Start-UwpExitAnimation -Control $TitleLabel -DurationMs 450 -OffsetY 40 -StaggerDelay 0 -IsButton $false
            
            # 按钮 1 (Smart): 延迟 50ms
            Start-UwpExitAnimation -Control $BtnSmart -DurationMs 400 -OffsetY 50 -StaggerDelay 50 -IsButton $true
            
            # 按钮 2 (English): 延迟 100ms
            Start-UwpExitAnimation -Control $BtnEng -DurationMs 400 -OffsetY 50 -StaggerDelay 100 -IsButton $true
            
            # 按钮 3 (CHS): 延迟 150ms
            Start-UwpExitAnimation -Control $BtnChs -DurationMs 400 -OffsetY 50 -StaggerDelay 150 -IsButton $true
            
            # 按钮 4 (Exit 自身): 延迟 200ms，最后消失
            Start-UwpExitAnimation -Control $BtnExit -DurationMs 400 -OffsetY 50 -StaggerDelay 200 -IsButton $true
        } catch {
            # 忽略动画错误，继续执行
        }

        # 动画结束后执行窗口退出动画并关闭程序
        $exitTimer = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
        $exitTimer.Interval = 650 # 先等UWP退出动画完成
        # 关键修复：将 Form 引用存入 Timer.Tag，彻底避免 PowerShell 嵌套闭包捕获失败导致 $null
        $exitTimer.Tag = $Form
        $exitTimer.Add_Tick({
            $this.Stop()
            $this.Dispose()
            
            try {
                # 从 Tag 取回 Form（比闭包捕获更可靠），ExitOnComplete 让动效完成后自行终止进程
                Start-MainWindowExitAnimation -Form $this.Tag -ExitOnComplete
            } catch {
                [System.Environment]::Exit(0)
            }
        }.GetNewClosure())
        $exitTimer.Start()
    }

    # ====== 视图 2 → 视图 3 前进逻辑（智能模式按钮事件）======
    $btnSmart.Add_Click({
        if (-not $script:launched -and -not $Global:IsViewTransitioning) {
            # 标记正在进行视图切换，防止重复触发
            $Global:IsViewTransitioning = $true
            
            # 禁用所有按钮的磁吸效果，防止与视图切换动效冲突
            $btnSmart.SetTransitionMode($true)
            $btnEng.SetTransitionMode($true)
            $btnChs.SetTransitionMode($true)
            $btnExit.SetTransitionMode($true)
            $btnGUI.SetTransitionMode($true)
            $btnConsole.SetTransitionMode($true)
            $btnBack.SetTransitionMode($true)
            
            # 记录选择
            $script:selectedMode = "SMART"

            # 0. 立即停止所有正在运行的动画并恢复控件状态
            Stop-AllAnimations -RestoreState
            
            # 0.3 核心修复：立即隐藏所有控件，防止RestoreState导致的闪现
            $titleLabel.Visible = $false
            $btnSmart.Visible = $false
            $btnEng.Visible = $false
            $btnChs.Visible = $false
            $btnExit.Visible = $false
            $styleTitleLabel.Visible = $false
            $btnGUI.Visible = $false
            $btnConsole.Visible = $false
            $btnBack.Visible = $false
            
            # 0.5 关键：强制重置所有控件到原始位置（确保每次动画都从正确位置开始）
            $titleLabel.Location = New-Object System.Drawing.Point(60, 45)
            $titleLabel.Size = New-Object System.Drawing.Size(280, 45)
            $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
            
            $btnSmart.Location = New-Object System.Drawing.Point(60, 110)
            $btnSmart.Size = New-Object System.Drawing.Size(280, 48)
            $btnSmart.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
            
            $btnEng.Location = New-Object System.Drawing.Point(60, 190)
            $btnEng.Size = New-Object System.Drawing.Size(280, 48)
            $btnEng.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
            
            $btnChs.Location = New-Object System.Drawing.Point(60, 270)
            $btnChs.Size = New-Object System.Drawing.Size(280, 48)
            $btnChs.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
            
            $btnExit.Location = New-Object System.Drawing.Point(60, 350)
            $btnExit.Size = New-Object System.Drawing.Size(280, 48)
            $btnExit.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
            
            $styleTitleLabel.Location = New-Object System.Drawing.Point(40, 45)
            $styleTitleLabel.Size = New-Object System.Drawing.Size(320, 45)
            $styleTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
            
            $btnGUI.Location = New-Object System.Drawing.Point(60, 190)
            $btnGUI.Size = New-Object System.Drawing.Size(280, 48)
            $btnGUI.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
            
            $btnConsole.Location = New-Object System.Drawing.Point(60, 270)
            $btnConsole.Size = New-Object System.Drawing.Size(280, 48)
            $btnConsole.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
            
            $btnBack.Location = New-Object System.Drawing.Point(60, 350)
            $btnBack.Size = New-Object System.Drawing.Size(280, 48)
            $btnBack.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
            
            # 0.6 保存重置后的控件状态
            Save-ControlState -Control $titleLabel
            Save-ControlState -Control $btnSmart
            Save-ControlState -Control $btnEng
            Save-ControlState -Control $btnChs
            Save-ControlState -Control $btnExit
            Save-ControlState -Control $styleTitleLabel
            Save-ControlState -Control $btnGUI
            Save-ControlState -Control $btnConsole
            Save-ControlState -Control $btnBack
            
            # 1. 立即禁用视图 2 的所有按钮，防误触
            $btnSmart.Enabled = $false; $btnGUI.Enabled = $false; $btnConsole.Enabled = $false; $btnBack.Enabled = $false
            
            # 2. 依次飞出视图 2
            try {
                Start-UwpExitAnimation -Control $styleTitleLabel -DurationMs 400 -OffsetY 40 -StaggerDelay 0 -IsButton $false
                Start-UwpExitAnimation -Control $btnSmart -DurationMs 400 -OffsetY 50 -StaggerDelay 50 -IsButton $true
                Start-UwpExitAnimation -Control $btnGUI -DurationMs 400 -OffsetY 50 -StaggerDelay 100 -IsButton $true
                Start-UwpExitAnimation -Control $btnConsole -DurationMs 400 -OffsetY 50 -StaggerDelay 150 -IsButton $true
                Start-UwpExitAnimation -Control $btnBack -DurationMs 400 -OffsetY 50 -StaggerDelay 200 -IsButton $true
            } catch { Write-AuroraLog "退出动画清理失败: $($_.Exception.Message)" -Level "Warning" }

            # 3. 异步切换视图
            $waitTimer = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
            $waitTimer.Interval = 650
            $waitTimer.Add_Tick({
                $this.Stop()
                $this.Dispose()
                
                try {
                    # 1. 隐藏视图1的控件
                    $titleLabel.Visible = $false
                    $btnSmart.Visible = $false
                    $btnEng.Visible = $false
                    $btnChs.Visible = $false
                    $btnExit.Visible = $false
                    
                    # 2. 先隐藏所有视图2的控件，防止旧状态闪现，然后启用它们
                    $styleTitleLabel.Visible = $false
                    $btnGUI.Visible = $false
                    $btnConsole.Visible = $false
                    $btnBack.Visible = $false
                    $styleTitleLabel.Enabled = $true
                    $btnGUI.Enabled = $true
                    $btnConsole.Enabled = $false
                    $btnBack.Enabled = $true

                    # 3. 设置视图3的按钮位置
                    $btnGUI.Location = New-Object System.Drawing.Point(60, 140)
                    $btnBack.Location = New-Object System.Drawing.Point(60, 220)

                    # 4. 根据当前语言设置按钮文本
                    if ($script:selectedLanguage -eq "ENG") {
                        $btnGUI.Text = "Professional GUI"
                        $btnBack.Text = "Back"
                    } else {
                        $btnGUI.Text = "专业图形模式"
                        $btnBack.Text = "返回"
                    }

                    # 4. 触发视图2的飞入动画（Smart模式只有GUI和返回按钮有动画）
                    Start-UwpEnterAnimation -Control $styleTitleLabel -TargetLocation (New-Object System.Drawing.Point(40, 45)) -ParentForm $form -DurationMs 400 -OffsetY 100 -DelayMs 0
                    Start-UwpEnterAnimation -Control $btnGUI -TargetLocation (New-Object System.Drawing.Point(60, 140)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 100
                    Start-UwpEnterAnimation -Control $btnBack -TargetLocation (New-Object System.Drawing.Point(60, 220)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 150
                    
                    # 4. 更新视图状态
                    $script:currentView = 3
                    
                    # 关键修复：保持 IsViewTransitioning=true 直到飞入动画完全结束
                    # 最长动画：350ms + 150ms 延迟 = 500ms，额外加 100ms 缓冲 = 600ms
                    # 使用定时器延迟恢复，不阻塞 UI 线程
                    # 检查是否已存在定时器（避免重复创建）
                    if ($null -eq $Global:MagneticRestoreTimer -or -not $Global:MagneticRestoreTimer.Enabled) {
                        $Global:MagneticRestoreTimer = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
                        $Global:MagneticRestoreTimer.Interval = 600
                        $Global:MagneticRestoreTimer.Add_Tick({
                            $this.Stop()
                            $this.Dispose()
                            $btnSmart.SetTransitionMode($false)
                            $btnEng.SetTransitionMode($false)
                            $btnChs.SetTransitionMode($false)
                            $btnExit.SetTransitionMode($false)
                            $btnGUI.SetTransitionMode($false)
                            $btnConsole.SetTransitionMode($false)
                            $btnBack.SetTransitionMode($false)
                            $Global:MagneticRestoreTimer = $null
                        })
                        $Global:MagneticRestoreTimer.Start()
                    }
                    
                    # 设置视图切换完成（但磁吸仍被禁用，等待定时器恢复）
                    $Global:IsViewTransitioning = $false
                } catch { 
                    $Global:IsViewTransitioning = $false
                    # 异常情况下立即恢复磁吸效果
                    $btnSmart.SetTransitionMode($false)
                    $btnEng.SetTransitionMode($false)
                    $btnChs.SetTransitionMode($false)
                    $btnExit.SetTransitionMode($false)
                    $btnGUI.SetTransitionMode($false)
                    $btnConsole.SetTransitionMode($false)
                    $btnBack.SetTransitionMode($false)
                }
            })
            $waitTimer.Start()
        }
    })

    # ====== P1-1: 统一语言选择过渡逻辑（消除 ENG/CHS ~340 行 DRY 违规）======
    function Start-LanguageTransition {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateSet("ENG", "CHS")]
            [string]$Language
        )

        if ($script:launched -or $Global:IsViewTransitioning) { return }
        $Global:IsViewTransitioning = $true

        # 禁用所有按钮的磁吸效果
        @($btnSmart, $btnEng, $btnChs, $btnExit, $btnGUI, $btnConsole, $btnBack) | ForEach-Object {
            $_.SetTransitionMode($true)
        }

        $script:selectedLanguage = $Language

        # 停止动画并隐藏所有控件
        Stop-AllAnimations -RestoreState
        @($titleLabel, $btnEng, $btnChs, $btnExit, $styleTitleLabel, $btnSmart, $btnGUI, $btnConsole, $btnBack) | ForEach-Object {
            $_.Visible = $false
        }

        # 强制重置所有控件到原始位置
        $titleLabel.Location = New-Object System.Drawing.Point(60, 45)
        $titleLabel.Size = New-Object System.Drawing.Size(280, 45)
        $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
        $btnEng.Location = New-Object System.Drawing.Point(60, 160)
        $btnEng.Size = New-Object System.Drawing.Size(280, 48)
        $btnEng.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
        $btnChs.Location = New-Object System.Drawing.Point(60, 240)
        $btnChs.Size = New-Object System.Drawing.Size(280, 48)
        $btnChs.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
        $btnExit.Location = New-Object System.Drawing.Point(60, 320)
        $btnExit.Size = New-Object System.Drawing.Size(280, 48)
        $btnExit.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
        $styleTitleLabel.Location = New-Object System.Drawing.Point(40, 45)
        $styleTitleLabel.Size = New-Object System.Drawing.Size(320, 45)
        $styleTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
        $btnSmart.Location = New-Object System.Drawing.Point(60, 110)
        $btnSmart.Size = New-Object System.Drawing.Size(280, 48)
        $btnSmart.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
        $btnGUI.Location = New-Object System.Drawing.Point(60, 190)
        $btnGUI.Size = New-Object System.Drawing.Size(280, 48)
        $btnGUI.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
        $btnConsole.Location = New-Object System.Drawing.Point(60, 270)
        $btnConsole.Size = New-Object System.Drawing.Size(280, 48)
        $btnConsole.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
        $btnBack.Location = New-Object System.Drawing.Point(60, 350)
        $btnBack.Size = New-Object System.Drawing.Size(280, 48)
        $btnBack.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)

        # 保存重置后的控件状态
        @($titleLabel, $btnEng, $btnChs, $btnExit, $styleTitleLabel, $btnSmart, $btnGUI, $btnConsole, $btnBack) | ForEach-Object {
            Save-ControlState -Control $_
        }

        # 禁用视图 1 按钮
        $btnEng.Enabled = $false; $btnChs.Enabled = $false; $btnExit.Enabled = $false

        # 依次飞出视图 1
        try {
            Start-UwpExitAnimation -Control $titleLabel -DurationMs 400 -OffsetY 40 -StaggerDelay 0 -IsButton $false
            Start-UwpExitAnimation -Control $btnEng -DurationMs 400 -OffsetY 50 -StaggerDelay 50 -IsButton $true
            Start-UwpExitAnimation -Control $btnChs -DurationMs 400 -OffsetY 50 -StaggerDelay 100 -IsButton $true
            Start-UwpExitAnimation -Control $btnExit -DurationMs 400 -OffsetY 50 -StaggerDelay 150 -IsButton $true
        } catch { Write-AuroraLog "退出动画清理失败: $($_.Exception.Message)" -Level "Warning" }

        # 异步切换视图
        $waitTimer = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
        $waitTimer.Interval = 650
        $waitTimer.Add_Tick({
            $this.Stop()
            $this.Dispose()

            try {
                # 隐藏视图1控件
                @($titleLabel, $btnEng, $btnChs, $btnExit) | ForEach-Object { $_.Visible = $false }

                # 隐藏视图2控件并启用
                @($styleTitleLabel, $btnSmart, $btnGUI, $btnConsole, $btnBack) | ForEach-Object { $_.Visible = $false }
                $styleTitleLabel.Enabled = $true
                $btnSmart.Enabled = $true
                $btnGUI.Enabled = $true
                $btnConsole.Enabled = $true
                $btnBack.Enabled = $true

                # 根据语言设置按钮文本
                if ($script:selectedLanguage -eq "ENG") {
                    $btnSmart.Text = "Smart Auto-Healing"
                    $btnGUI.Text = "Professional GUI"
                    $btnConsole.Text = "Console Mode"
                    $btnBack.Text = "Back"
                } else {
                    $btnSmart.Text = "智能诊断与自主修复模式"
                    $btnGUI.Text = "专业图形模式"
                    $btnConsole.Text = "控制台模式"
                    $btnBack.Text = "返回"
                }

                # 触发视图2飞入动画
                Start-UwpEnterAnimation -Control $styleTitleLabel -TargetLocation (New-Object System.Drawing.Point(40, 45)) -ParentForm $form -DurationMs 400 -OffsetY 100 -DelayMs 0
                Start-UwpEnterAnimation -Control $btnSmart -TargetLocation (New-Object System.Drawing.Point(60, 110)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 50
                Start-UwpEnterAnimation -Control $btnGUI -TargetLocation (New-Object System.Drawing.Point(60, 190)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 100
                Start-UwpEnterAnimation -Control $btnConsole -TargetLocation (New-Object System.Drawing.Point(60, 270)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 150
                Start-UwpEnterAnimation -Control $btnBack -TargetLocation (New-Object System.Drawing.Point(60, 350)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 200

                $script:currentView = 2
                $Global:IsViewTransitioning = $false

                # 延迟恢复磁吸效果
                $magneticTimer = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
                $magneticTimer.Interval = 650
                $magneticTimer.Add_Tick({
                    $this.Stop()
                    $this.Dispose()
                    @($btnSmart, $btnEng, $btnChs, $btnExit, $btnGUI, $btnConsole, $btnBack) | ForEach-Object {
                        $_.SetTransitionMode($false)
                    }
                })
                $magneticTimer.Start()
            } catch {
                $Global:IsViewTransitioning = $false
                @($btnSmart, $btnEng, $btnChs, $btnExit, $btnGUI, $btnConsole, $btnBack) | ForEach-Object {
                    $_.SetTransitionMode($false)
                }
            }
        })
        $waitTimer.Start()
    }

    $btnEng.Add_Click({ Start-LanguageTransition -Language "ENG" })
    $btnChs.Add_Click({ Start-LanguageTransition -Language "CHS" })

    # 退出按钮事件
    $btnExit.Add_Click({
        $btnExit.Enabled = $false
        
        # 定义简化的退出动画序列，不包含 btnSmart
        try {
            # 启动退出动画 - 关键：设置 StaggerDelay (延迟) 和 IsButton 标志
            # 标题：无延迟，普通飞出
            Start-UwpExitAnimation -Control $titleLabel -DurationMs 450 -OffsetY 40 -StaggerDelay 0 -IsButton $false
            
            # 按钮 1 (English): 延迟 50ms
            Start-UwpExitAnimation -Control $btnEng -DurationMs 400 -OffsetY 50 -StaggerDelay 50 -IsButton $true
            
            # 按钮 2 (CHS): 延迟 100ms
            Start-UwpExitAnimation -Control $btnChs -DurationMs 400 -OffsetY 50 -StaggerDelay 100 -IsButton $true
            
            # 按钮 3 (Exit 自身): 延迟 150ms，最后消失
            Start-UwpExitAnimation -Control $btnExit -DurationMs 400 -OffsetY 50 -StaggerDelay 150 -IsButton $true
        } catch {
            # 忽略动画错误，继续执行
        }

        # 动画结束后执行窗口退出动画并关闭程序
        $exitTimer = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
        $exitTimer.Interval = 650 # 先等UWP退出动画完成
        # 关键修复：将 Form 引用存入 Timer.Tag，彻底避免 PowerShell 嵌套闭包捕获失败导致 $null
        $exitTimer.Tag = $form
        $exitTimer.Add_Tick({
            $this.Stop()
            $this.Dispose()
            
            try {
                # 从 Tag 取回 Form（比闭包捕获更可靠），ExitOnComplete 让动效完成后自行终止进程
                Start-MainWindowExitAnimation -Form $this.Tag -ExitOnComplete
            } catch {
                [System.Environment]::Exit(0)
            }
        }.GetNewClosure())
        $exitTimer.Start()
    })

    # ====== 动态后退逻辑（支持 视图3->视图2 以及 视图2->视图1）======
    $btnBack.Add_Click({
        if (-not $Global:IsViewTransitioning) {
            $Global:IsViewTransitioning = $true
            
            # 禁用所有按钮的磁吸效果，防止与视图切换动效冲突
            $btnSmart.SetTransitionMode($true)
            $btnEng.SetTransitionMode($true)
            $btnChs.SetTransitionMode($true)
            $btnExit.SetTransitionMode($true)
            $btnGUI.SetTransitionMode($true)
            $btnConsole.SetTransitionMode($true)
            $btnBack.SetTransitionMode($true)
            
            # 1. 立即停止所有正在运行的动画并恢复控件状态
            Stop-AllAnimations -RestoreState
            
            # 2. 立即隐藏所有控件，防止状态残留闪现
            $titleLabel.Visible = $false
            $btnEng.Visible = $false
            $btnChs.Visible = $false
            $btnExit.Visible = $false
            $styleTitleLabel.Visible = $false
            $btnSmart.Visible = $false
            $btnGUI.Visible = $false
            $btnConsole.Visible = $false
            $btnBack.Visible = $false

            # ==========================================
            # 场景 A：从 视图 3（智能模式子菜单）返回 视图 2
            # ==========================================
            if ($script:currentView -eq 3) {
                
                # 强制重置视图 3 控件的当前位置（防止上次飞入位置错乱）
                $styleTitleLabel.Location = New-Object System.Drawing.Point(40, 45)
                $btnGUI.Location = New-Object System.Drawing.Point(60, 140)
                $btnBack.Location = New-Object System.Drawing.Point(60, 220)
                Save-ControlState -Control $styleTitleLabel
                Save-ControlState -Control $btnGUI
                Save-ControlState -Control $btnBack
                
                # 禁用当前按钮
                $btnGUI.Enabled = $false
                $btnBack.Enabled = $false

                # 依次飞出视图 3 的控件
                try {
                    Start-UwpExitAnimation -Control $styleTitleLabel -DurationMs 400 -OffsetY 40 -StaggerDelay 0 -IsButton $false
                    Start-UwpExitAnimation -Control $btnGUI -DurationMs 400 -OffsetY 50 -StaggerDelay 50 -IsButton $true
                    Start-UwpExitAnimation -Control $btnBack -DurationMs 400 -OffsetY 50 -StaggerDelay 100 -IsButton $true
                } catch { Write-AuroraLog "退出动画清理失败: $($_.Exception.Message)" -Level "Warning" }

                # 异步切回视图 2
                $waitTimer = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
                $waitTimer.Interval = 600
                $waitTimer.Add_Tick({
                    $this.Stop()
                    $this.Dispose()
                    
                    $script:currentView = 2  # 状态回退到视图 2
                    $script:selectedMode = $null  # 【关键修复】清除之前的模式选择，防止从视图 3 返回后错误触发智能模式
                    
                    try {
                        # 隐藏旧控件，启用目标控件
                        $styleTitleLabel.Visible = $false; $btnGUI.Visible = $false; $btnBack.Visible = $false
                        $styleTitleLabel.Enabled = $true
                        $btnSmart.Enabled = $true
                        $btnGUI.Enabled = $true
                        $btnConsole.Enabled = $true
                        $btnBack.Enabled = $true

                        # 恢复视图 2 的标准排版位置
                        $styleTitleLabel.Location = New-Object System.Drawing.Point(40, 45)
                        $btnSmart.Location = New-Object System.Drawing.Point(60, 110)
                        $btnGUI.Location = New-Object System.Drawing.Point(60, 190)
                        $btnConsole.Location = New-Object System.Drawing.Point(60, 270)
                        $btnBack.Location = New-Object System.Drawing.Point(60, 350)
                        
                        # 动态恢复按钮文字
                        if ($script:selectedLanguage -eq "ENG") {
                            $btnSmart.Text = "Smart Auto-Healing"
                            $btnGUI.Text = "Professional GUI"
                            $btnConsole.Text = "Console Mode"
                            $btnBack.Text = "Back"
                        } else {
                            $btnSmart.Text = "智能诊断与自主修复模式"
                            $btnGUI.Text = "专业图形模式"
                            $btnConsole.Text = "控制台模式"
                            $btnBack.Text = "返回"
                        }

                        # 触发视图 2 飞入动画
                        Start-UwpEnterAnimation -Control $styleTitleLabel -TargetLocation (New-Object System.Drawing.Point(40, 45)) -ParentForm $form -DurationMs 400 -OffsetY 100 -DelayMs 0
                        Start-UwpEnterAnimation -Control $btnSmart -TargetLocation (New-Object System.Drawing.Point(60, 110)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 50
                        Start-UwpEnterAnimation -Control $btnGUI -TargetLocation (New-Object System.Drawing.Point(60, 190)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 100
                        Start-UwpEnterAnimation -Control $btnConsole -TargetLocation (New-Object System.Drawing.Point(60, 270)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 150
                        Start-UwpEnterAnimation -Control $btnBack -TargetLocation (New-Object System.Drawing.Point(60, 350)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 200
                        
                        $Global:IsViewTransitioning = $false
                        # 关键修复：延迟恢复磁吸效果，等待飞入动画完成后启用
                        # 最长动画：350ms + 200ms 延迟 = 550ms，额外加 100ms 缓冲 = 650ms
                        $magneticRestoreTimer = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
                        $magneticRestoreTimer.Interval = 650
                        $magneticRestoreTimer.Add_Tick({
                            $this.Stop()
                            $this.Dispose()
                            $btnSmart.SetTransitionMode($false)
                            $btnEng.SetTransitionMode($false)
                            $btnChs.SetTransitionMode($false)
                            $btnExit.SetTransitionMode($false)
                            $btnGUI.SetTransitionMode($false)
                            $btnConsole.SetTransitionMode($false)
                            $btnBack.SetTransitionMode($false)
                        })
                        $magneticRestoreTimer.Start()
                    } catch { $Global:IsViewTransitioning = $false }
                })
                $waitTimer.Start()
            }
            # ==========================================
            # 场景 B：从 视图 2（模式选择）返回 视图 1
            # ==========================================
            else {
                
                # 强制重置视图 2 控件到原始位置
                $styleTitleLabel.Location = New-Object System.Drawing.Point(40, 45)
                $btnSmart.Location = New-Object System.Drawing.Point(60, 110)
                $btnGUI.Location = New-Object System.Drawing.Point(60, 190)
                $btnConsole.Location = New-Object System.Drawing.Point(60, 270)
                $btnBack.Location = New-Object System.Drawing.Point(60, 350)
                Save-ControlState -Control $styleTitleLabel
                Save-ControlState -Control $btnSmart
                Save-ControlState -Control $btnGUI
                Save-ControlState -Control $btnConsole
                Save-ControlState -Control $btnBack
                
                # 禁用视图 2 按钮
                $btnSmart.Enabled = $false; $btnGUI.Enabled = $false; $btnConsole.Enabled = $false; $btnBack.Enabled = $false

                # 依次飞出视图 2
                try {
                    Start-UwpExitAnimation -Control $styleTitleLabel -DurationMs 400 -OffsetY 40 -StaggerDelay 0 -IsButton $false
                    Start-UwpExitAnimation -Control $btnSmart -DurationMs 400 -OffsetY 50 -StaggerDelay 50 -IsButton $true
                    Start-UwpExitAnimation -Control $btnGUI -DurationMs 400 -OffsetY 50 -StaggerDelay 100 -IsButton $true
                    Start-UwpExitAnimation -Control $btnConsole -DurationMs 400 -OffsetY 50 -StaggerDelay 150 -IsButton $true
                    Start-UwpExitAnimation -Control $btnBack -DurationMs 400 -OffsetY 50 -StaggerDelay 200 -IsButton $true
                } catch { Write-AuroraLog "退出动画清理失败: $($_.Exception.Message)" -Level "Warning" }

                # 异步切回视图 1
                $waitTimer = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
                $waitTimer.Interval = 600
                $waitTimer.Add_Tick({
                    $this.Stop()
                    $this.Dispose()
                    
                    # 彻底重置状态
                    $script:launched = $false
                    $script:selectedLanguage = $null
                    $script:selectedMode = $null
                    $script:currentView = 1  # 状态回退到视图 1
                    
                    try {
                        $styleTitleLabel.Visible = $false; $btnSmart.Visible = $false; $btnGUI.Visible = $false; $btnConsole.Visible = $false; $btnBack.Visible = $false
                        $btnEng.Enabled = $true; $btnChs.Enabled = $true; $btnExit.Enabled = $true

                        Start-UwpEnterAnimation -Control $titleLabel -TargetLocation (New-Object System.Drawing.Point(60, 45)) -ParentForm $form -DurationMs 400 -OffsetY 100 -DelayMs 0
                        Start-UwpEnterAnimation -Control $btnEng -TargetLocation (New-Object System.Drawing.Point(60, 160)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 50
                        Start-UwpEnterAnimation -Control $btnChs -TargetLocation (New-Object System.Drawing.Point(60, 240)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 100
                        Start-UwpEnterAnimation -Control $btnExit -TargetLocation (New-Object System.Drawing.Point(60, 320)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 150
                        
                        $Global:IsViewTransitioning = $false
                        # 关键修复：延迟恢复磁吸效果，等待飞入动画完成后启用
                        $restoreTimer5 = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
                        $restoreTimer5.Interval = 600
                        $restoreTimer5.Add_Tick({
                            $this.Stop()
                            $this.Dispose()
                            $btnSmart.SetTransitionMode($false)
                            $btnEng.SetTransitionMode($false)
                            $btnChs.SetTransitionMode($false)
                            $btnExit.SetTransitionMode($false)
                            $btnGUI.SetTransitionMode($false)
                            $btnConsole.SetTransitionMode($false)
                            $btnBack.SetTransitionMode($false)
                        })
                        $restoreTimer5.Start()
                    } catch { $Global:IsViewTransitioning = $false }
                })
                $waitTimer.Start()
            }
        }
    })



    # ====== 视图 2 和视图 3 - GUI模式启动事件 ======
    $btnGUI.Add_Click({
        if (-not $script:launched -and -not $Global:IsViewTransitioning) {
            # 标记正在进行视图切换，防止重复触发
            $Global:IsViewTransitioning = $true
            $script:launched = $true
            
            # 禁用所有按钮的磁吸效果，防止与视图切换动效冲突
            $btnSmart.SetTransitionMode($true)
            $btnEng.SetTransitionMode($true)
            $btnChs.SetTransitionMode($true)
            $btnExit.SetTransitionMode($true)
            $btnGUI.SetTransitionMode($true)
            $btnConsole.SetTransitionMode($true)
            $btnBack.SetTransitionMode($true)
            
            # 0. 立即停止所有正在运行的动画并恢复控件状态
            Stop-AllAnimations -RestoreState
            
            # 禁用所有按钮防止重复点击
            $btnSmart.Enabled = $false
            $btnGUI.Enabled = $false
            $btnConsole.Enabled = $false
            $btnBack.Enabled = $false
            
            # 根据当前视图决定飞出动画
            $isView3 = $script:currentView -eq 3
            
            # 视图2或3飞出动画
            try {
                Start-UwpExitAnimation -Control $styleTitleLabel -DurationMs 450 -OffsetY 40 -StaggerDelay 0 -IsButton $false
                if ($isView3) {
                    Start-UwpExitAnimation -Control $btnGUI -DurationMs 400 -OffsetY 50 -StaggerDelay 50 -IsButton $true
                    Start-UwpExitAnimation -Control $btnBack -DurationMs 400 -OffsetY 50 -StaggerDelay 100 -IsButton $true
                } else {
                    Start-UwpExitAnimation -Control $btnSmart -DurationMs 400 -OffsetY 50 -StaggerDelay 50 -IsButton $true
                    Start-UwpExitAnimation -Control $btnGUI -DurationMs 400 -OffsetY 50 -StaggerDelay 100 -IsButton $true
                    Start-UwpExitAnimation -Control $btnConsole -DurationMs 400 -OffsetY 50 -StaggerDelay 150 -IsButton $true
                    Start-UwpExitAnimation -Control $btnBack -DurationMs 400 -OffsetY 50 -StaggerDelay 200 -IsButton $true
                }
            } catch { Write-AuroraLog "退出动画清理失败: $($_.Exception.Message)" -Level "Warning" }
            
            # 等待动画完成后启动
            $launchTimer = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
            $launchTimer.Interval = 600
            $launchTimer.Add_Tick({
                $this.Stop()
                $this.Dispose()
                
                try {
                    # 挂起星空引擎并隐藏主窗口
                    if ($background -ne $null) { $background.StopAnimation() }
                    # 🔧 核心修复：不要关闭主窗体，只隐藏它
                    # 原因：ShowProMode 需要应用程序消息循环，如果主窗体被关闭，消息循环会终止
                    if ($form -ne $null) { 
                        $form.Hide()
                    }
                    
                    # 根据选择启动对应模式
                    if ($script:selectedMode -eq "SMART") {
                        # 启动智能诊断与自主修复模式引擎
                        $smartScript = Join-Path $ScriptsDir "Engines\AURORA-SmartEngine.ps1"
                        if (Test-Path $smartScript) {
                            # 🔐 P0 修复：根据用户选择的语言来决定智能模式的语言，而不是根据文件是否存在
                            if ($script:selectedLanguage -eq "ENG") {
                                try { ShowProMode -ScriptPath $smartScript -Title "Smart Auto-Healing" -Language "ENG" -FromGUI $true } catch { Write-Host "[ShowProMode ERROR] $($_.Exception.Message)" -ForegroundColor Red; Write-Host "[ShowProMode Stack] $($_.ScriptStackTrace)" -ForegroundColor Red }
                            } else {
                                try { ShowProMode -ScriptPath $smartScript -Title "智能诊断与自主修复模式" -Language "CHS" -FromGUI $true } catch { Write-Host "[ShowProMode ERROR] $($_.Exception.Message)" -ForegroundColor Red; Write-Host "[ShowProMode Stack] $($_.ScriptStackTrace)" -ForegroundColor Red }
                            }
                        } else {
                            Write-Host "[ERROR] Smart Engine script not found: $smartScript" -ForegroundColor Red
                        }
                    } else {
                        # 定义 PRO 模式统一入口脚本路径
                        $proScript = Join-Path $ScriptsDir "PRO\AURORA-AnalyzerPRO.ps1"
                        
                        if ($proScript -ne $null -and (Test-Path $proScript)) {
                            try { 
                                ShowProMode -ScriptPath $proScript -Title "PRO Mode ($($script:selectedLanguage))" -Language $script:selectedLanguage -FromGUI $true
                            } catch { 
                                Write-Host "[ShowProMode ERROR] $($_.Exception.Message)" -ForegroundColor Red
                                Write-Host "[ShowProMode Stack] $($_.ScriptStackTrace)" -ForegroundColor Red
                            }
                        } else {
                            Write-Host "[ERROR] PRO mode script not found: $proScript" -ForegroundColor Red
                        }
                    }
                    
                    # 核心修复：ShowProMode 是阻塞式调用，不应该在这里 Exit
                    # 只有当 ShowProMode 返回后才退出（正常情况下它不会返回，除非出错）
                    [Environment]::Exit(0)
                } catch {
                    Write-Host "[ERROR] Launch failed: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "[ERROR] StackTrace: $($_.ScriptStackTrace)" -ForegroundColor Red
                    # 异常情况下恢复磁吸效果
                    $btnSmart.SetTransitionMode($false)
                    $btnEng.SetTransitionMode($false)
                    $btnChs.SetTransitionMode($false)
                    $btnExit.SetTransitionMode($false)
                    $btnGUI.SetTransitionMode($false)
                    $btnConsole.SetTransitionMode($false)
                    $btnBack.SetTransitionMode($false)
                }
            })
            $launchTimer.Start()
        }
    })

    # ====== 视图 2 - 控制台模式启动事件 ======
    $btnConsole.Add_Click({
        if (-not $script:launched -and -not $Global:IsViewTransitioning) {
            # 标记正在进行视图切换，防止重复触发
            $Global:IsViewTransitioning = $true
            $script:launched = $true
            
            # 禁用所有按钮的磁吸效果，防止与视图切换动效冲突
            $btnSmart.SetTransitionMode($true)
            $btnEng.SetTransitionMode($true)
            $btnChs.SetTransitionMode($true)
            $btnExit.SetTransitionMode($true)
            $btnGUI.SetTransitionMode($true)
            $btnConsole.SetTransitionMode($true)
            $btnBack.SetTransitionMode($true)
            
            # 0. 立即停止所有正在运行的动画并恢复控件状态
            Stop-AllAnimations -RestoreState
            
            # 禁用所有按钮防止重复点击
            $btnSmart.Enabled = $false
            $btnGUI.Enabled = $false
            $btnConsole.Enabled = $false
            $btnBack.Enabled = $false
            
            # 视图2飞出动画
            try {
                Start-UwpExitAnimation -Control $styleTitleLabel -DurationMs 450 -OffsetY 40 -StaggerDelay 0 -IsButton $false
                Start-UwpExitAnimation -Control $btnSmart -DurationMs 400 -OffsetY 50 -StaggerDelay 50 -IsButton $true
                Start-UwpExitAnimation -Control $btnGUI -DurationMs 400 -OffsetY 50 -StaggerDelay 100 -IsButton $true
                Start-UwpExitAnimation -Control $btnConsole -DurationMs 400 -OffsetY 50 -StaggerDelay 150 -IsButton $true
                Start-UwpExitAnimation -Control $btnBack -DurationMs 400 -OffsetY 50 -StaggerDelay 200 -IsButton $true
            } catch { Write-AuroraLog "退出动画清理失败: $($_.Exception.Message)" -Level "Warning" }
            
            # 等待动画完成后启动
            $launchTimer = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
            $launchTimer.Interval = 600
            $launchTimer.Add_Tick({
                $this.Stop()
                $this.Dispose()
                
                try {
                    # 挂起星空引擎并隐藏主窗口
                    if ($background -ne $null) { $background.StopAnimation() }
                    if ($form -ne $null) { $form.Hide() }
                    
                    # 定义 PRO 模式统一入口脚本路径
                    $proScript = Join-Path $ScriptsDir "PRO\AURORA-AnalyzerPRO.ps1"
                    
                    # 启动控制台模式
                    if ($proScript -ne $null -and (Test-Path $proScript)) {
                        Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$proScript`"", "-GUI_Mode", "-Language", $script:selectedLanguage
                    } else {
                        Write-Host "[ERROR] PRO mode script not found: $proScript" -ForegroundColor Red
                    }
                    
                    # 退出主窗口
                    [Environment]::Exit(0)
                } catch { Write-AuroraLog "表单退出处理失败: $($_.Exception.Message)" -Level "Warning" }
            })
            $launchTimer.Start()
        }
    })

    # 支持无边框窗口拖拽
    $form.Add_Load({
    
    # 关键修复：初始进场时禁用磁吸效果，防止飞入动画期间被鼠标劫持
    $btnEng.SetTransitionMode($true)
    $btnChs.SetTransitionMode($true)
    $btnExit.SetTransitionMode($true)
    $btnSmart.SetTransitionMode($true)
    $btnGUI.SetTransitionMode($true)
    $btnConsole.SetTransitionMode($true)
    $btnBack.SetTransitionMode($true)
    
    # === 先添加所有控件到背景面板 ===
    $background.Controls.Add($btnEng)
    $background.Controls.Add($btnChs)
    $background.Controls.Add($btnExit)
    $background.Controls.Add($btnSmart)
    $background.Controls.Add($btnGUI)
    $background.Controls.Add($btnConsole)
    $background.Controls.Add($btnBack)

    # === 关键：先隐藏所有视图1的控件，防止直接显示，让动画函数来处理 ===
    $titleLabel.Visible = $false
    $btnEng.Visible = $false
    $btnChs.Visible = $false
    $btnExit.Visible = $false
    
    # 视图2保持隐藏
    $styleTitleLabel.Visible = $false
    $btnSmart.Visible = $false
    $btnGUI.Visible = $false
    $btnConsole.Visible = $false
    $btnBack.Visible = $false

    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 10

    # === 启动视图1的UWP飞入动画 ===
    # 标题
    Start-UwpEnterAnimation -Control $titleLabel -TargetLocation (New-Object System.Drawing.Point(60, 45)) -ParentForm $form -DurationMs 400 -OffsetY 100 -DelayMs 150
    
    # 按钮 1 (English) - 目标位置160，与重置位置一致
    Start-UwpEnterAnimation -Control $btnEng -TargetLocation (New-Object System.Drawing.Point(60, 160)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 300
    
    # 按钮 2 (CHS) - 目标位置240，与重置位置一致
    Start-UwpEnterAnimation -Control $btnChs -TargetLocation (New-Object System.Drawing.Point(60, 240)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 400
    
    # 按钮 3 (Exit) - 目标位置320，与重置位置一致
    Start-UwpEnterAnimation -Control $btnExit -TargetLocation (New-Object System.Drawing.Point(60, 320)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 500
    
    # 关键修复：延迟恢复磁吸效果，等待飞入动画完成后再启用
    # 最长动画：350ms + 500ms 延迟 = 850ms，额外加 100ms 缓冲 = 950ms
    if ($null -eq $Global:MagneticRestoreTimer -or -not $Global:MagneticRestoreTimer.Enabled) {
        $Global:MagneticRestoreTimer = Register-AuroraTimer (New-Object System.Windows.Forms.Timer)
        $Global:MagneticRestoreTimer.Interval = 950
        $Global:MagneticRestoreTimer.Add_Tick({
            $this.Stop()
            $this.Dispose()
            $btnEng.SetTransitionMode($false)
            $btnChs.SetTransitionMode($false)
            $btnExit.SetTransitionMode($false)
            $btnSmart.SetTransitionMode($false)
            $btnGUI.SetTransitionMode($false)
            $btnConsole.SetTransitionMode($false)
            $btnBack.SetTransitionMode($false)
            $Global:MagneticRestoreTimer = $null
        })
        $Global:MagneticRestoreTimer.Start()
    }
})

    # P1-2: 绑定 Timer 集中清理 + 退出清理逻辑到窗体关闭事件
    $form.Add_FormClosing({
        Dispose-AllAuroraTimers
        if ($script:cleanupAction) {
            & $script:cleanupAction
        }
    })
    
    # 注册到全局变量，供完整性监控关闭主窗口
    $global:mainForm = $form

    # 显示表单并添加窗口级动画
    Start-MainWindowAnimation -Form $form
    # 运行消息循环
    [System.Windows.Forms.Application]::Run($form)
    $form.Dispose()
}
