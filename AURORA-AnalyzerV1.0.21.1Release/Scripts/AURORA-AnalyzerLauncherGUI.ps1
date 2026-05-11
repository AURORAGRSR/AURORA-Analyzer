# WARNING: 本工具仅用于个人学习使用。
# 构建自.NET Framework 4.x 的 C# 5.0
# LauncherGUI Version: V19.1Release
# 作者：AURORA VelociRaptor-GR Dev PRJ. y| 构建时间：2026.05.09

# ==========================================
# 🔒 启动检测与密码验证
# ==========================================

Param(
    [switch]$LaunchedByExe
)

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

# 检测是否由EXE启动
$IsLaunchedByExe = $LaunchedByExe -or ($env:AURORA_LAUNCHED_BY_EXE -eq "1")
if (-not $IsLaunchedByExe) {
    # 需要密码验证
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    # GAURORA.CHK.ENC 在根目录
    $EncChkPath = Join-Path $rootDir "GAURORA.CHK.ENC"
    
    if (-not (Test-Path $EncChkPath)) {
        [System.Windows.Forms.MessageBox]::Show(
            "未找到加密验证文件！`n请确保所有文件完整。",
            "AURORA 启动错误",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit 1
    }
    
    # 检测系统语言，选择提示语言
    $UseChinese = $false
    try {
        $uiCulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture.Name
        if ($uiCulture -like "zh*") {
            $UseChinese = $true
        }
    } catch {}
    
    # 创建密码输入窗体
    $PasswordForm = New-Object System.Windows.Forms.Form
    $PasswordForm.Text = if ($UseChinese) { "AURORA - 密码验证" } else { "AURORA - Password Verification" }
    $PasswordForm.Size = New-Object System.Drawing.Size(400, 200)
    $PasswordForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $PasswordForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $PasswordForm.MaximizeBox = $false
    $PasswordForm.MinimizeBox = $false
    $PasswordForm.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 36)
    $PasswordForm.ForeColor = [System.Drawing.Color]::White
    
    # 标题标签
    $TitleLabel = New-Object System.Windows.Forms.Label
    $TitleLabel.Text = if ($UseChinese) { "请输入启动密码" } else { "Please enter startup password" }
    $TitleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $TitleLabel.Size = New-Object System.Drawing.Size(360, 25)
    $TitleLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10, [System.Drawing.FontStyle]::Bold)
    $TitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(176, 205, 249)
    
    # 密码输入框
    $PasswordTextBox = New-Object System.Windows.Forms.TextBox
    $PasswordTextBox.PasswordChar = '*'
    $PasswordTextBox.Location = New-Object System.Drawing.Point(20, 55)
    $PasswordTextBox.Size = New-Object System.Drawing.Size(340, 25)
    $PasswordTextBox.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)
    
    # 提示标签
    $HintLabel = New-Object System.Windows.Forms.Label
    $HintLabel.Text = if ($UseChinese) { "提示：您正在直接启动GUI，使用EXE启动可跳过验证" } else { "Hint: You are launching directly, use EXE to skip verification." }
    $HintLabel.Location = New-Object System.Drawing.Point(20, 85)
    $HintLabel.Location = New-Object System.Drawing.Point(20, 85)
    $HintLabel.Size = New-Object System.Drawing.Size(360, 20)
    $HintLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
    $HintLabel.ForeColor = [System.Drawing.Color]::FromArgb(155, 136, 114, 227)
    
    # 确定按钮
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Text = if ($UseChinese) { "确定" } else { "OK" }
    $OKButton.Location = New-Object System.Drawing.Point(260, 115)
    $OKButton.Size = New-Object System.Drawing.Size(100, 35)
    $OKButton.BackColor = [System.Drawing.Color]::FromArgb(16, 140, 222)
    $OKButton.ForeColor = [System.Drawing.Color]::White
    $OKButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $OKButton.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9, [System.Drawing.FontStyle]::Bold)
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    
    # 取消按钮
    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Text = if ($UseChinese) { "取消" } else { "Cancel" }
    $CancelButton.Location = New-Object System.Drawing.Point(150, 115)
    $CancelButton.Size = New-Object System.Drawing.Size(100, 35)
    $CancelButton.BackColor = [System.Drawing.Color]::FromArgb(80, 84, 96)
    $CancelButton.ForeColor = [System.Drawing.Color]::White
    $CancelButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $CancelButton.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    
    # 添加控件
    $PasswordForm.Controls.Add($TitleLabel)
    $PasswordForm.Controls.Add($PasswordTextBox)
    $PasswordForm.Controls.Add($HintLabel)
    $PasswordForm.Controls.Add($OKButton)
    $PasswordForm.Controls.Add($CancelButton)
    $PasswordForm.AcceptButton = $OKButton
    $PasswordForm.CancelButton = $CancelButton
    
    # 显示窗体
    $PasswordResult = $PasswordForm.ShowDialog()
    
    if ($PasswordResult -ne [System.Windows.Forms.DialogResult]::OK) {
        exit 1
    }
    
    # 读取并解密GAURORA.CHK.ENC获取密码哈希
    try {
        $EncContent = Get-Content $EncChkPath -Raw -Encoding ASCII
        $EncBytes = [Convert]::FromBase64String($EncContent)
        if ($EncBytes.Length -lt 17) {
            throw "Invalid encrypted data"
        }
        
        # 尝试解密 - 需要用户输入的密码
        $UserPassword = $PasswordTextBox.Text
        $KeyBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($UserPassword))
        
        $Iv = $EncBytes[0..15]
        $Cipher = $EncBytes[16..($EncBytes.Length - 1)]
        
        $Aes = [System.Security.Cryptography.Aes]::Create()
        $Aes.Key = $KeyBytes
        $Aes.IV = $Iv
        $Aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $Aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        
        $Decryptor = $Aes.CreateDecryptor()
        $PlainBytes = $Decryptor.TransformFinalBlock($Cipher, 0, $Cipher.Length)
        $PlainText = [System.Text.Encoding]::Default.GetString($PlainBytes)
        
        # 解密成功，继续执行
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
        exit 1
    }
}

# === 加载 .NET Windows Forms 与绘图核心库 ===
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

# ====== 无边框窗口拖拽支持 - Win32 API 声明 ======
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Helper {
    public const int WM_NCLBUTTONDOWN = 0xA1;
    public const int HT_CAPTION = 0x2;

    [DllImport("user32.dll")]
    public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);

    [DllImport("user32.dll")]
    public static extern bool ReleaseCapture();
}
"@

# ====== 自定义控件定义：AuroraProgressBar（进度条） + TechButton（动态按钮）======
# 使用 C# 内联编译方式，在 PowerShell 中动态创建两个高性能自绘控件
Add-Type -ReferencedAssemblies System.Drawing, System.Windows.Forms -TypeDefinition @"

// ==========================================
// C# 基础 using 语句（必须放在最前面）
// ==========================================
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Windows.Forms;

// ==========================================
// ⚙️ AURORA 渲染引擎配置中枢
// ==========================================
public enum PerformanceTier { Eco = 0, Balanced = 1, Performance = 2, Extreme = 3 }

public static class AuroraRenderEngine
{
    public static PerformanceTier CurrentTier { get; private set; }

    // 预计算的渲染参数
    public static int TargetFPS { get; private set; }
    public static int StarCount { get; private set; }
    public static int ParticleCount { get; private set; }
    public static bool EnableComplexGlow { get; private set; }
    public static bool EnablePathGradientShadows { get; private set; }
    public static bool EnableParticleSystem { get; private set; }
    public static bool EnableDynamicSweep { get; private set; }

    static AuroraRenderEngine()
    {
        string tierStr = Environment.GetEnvironmentVariable("AURORA_PERF_TIER");
        switch (tierStr)
        {
            case "Eco": CurrentTier = PerformanceTier.Eco; break;
            case "Performance": CurrentTier = PerformanceTier.Performance; break;
            case "Extreme": CurrentTier = PerformanceTier.Extreme; break;
            default: CurrentTier = PerformanceTier.Balanced; break;
        }

        switch (CurrentTier)
        {
            case PerformanceTier.Eco:
                TargetFPS = 30; StarCount = 80; ParticleCount = 0;
                EnableComplexGlow = false; EnablePathGradientShadows = false; 
                EnableParticleSystem = false; EnableDynamicSweep = false;
                break;
            case PerformanceTier.Balanced:
                TargetFPS = 60; StarCount = 180; ParticleCount = 30;
                EnableComplexGlow = false; EnablePathGradientShadows = true; 
                EnableParticleSystem = true; EnableDynamicSweep = false;
                break;
            case PerformanceTier.Performance:
                TargetFPS = 60; StarCount = 350; ParticleCount = 80;
                EnableComplexGlow = true; EnablePathGradientShadows = true; 
                EnableParticleSystem = true; EnableDynamicSweep = true;
                break;
            case PerformanceTier.Extreme:
                TargetFPS = 60; StarCount = 600; ParticleCount = 150;
                EnableComplexGlow = true; EnablePathGradientShadows = true; 
                EnableParticleSystem = true; EnableDynamicSweep = true;
                break;
        }
    }

    public static int GetTimerInterval() { return 1000 / TargetFPS; }
}

// =============== AURORA PROGRESS BAR ===============
// 特性：
// - 圆角轨道 + 青绿色渐变填充
// - 动态光晕扫过进度区域（PathGradientBrush 实现）
// - 粒子系统：随光晕生成白色发光粒子，带生命周期与随机漂移
// - 高性能双缓冲绘制，避免闪烁

public class AuroraProgressBar : Control {
    // --- 字段定义 ---
    private float _value = 0;               // 当前进度值
    private float _minimum = 0;             // 最小值
    private float _maximum = 100;           // 最大值
    private Color _trackColor = Color.FromArgb(100, 60, 100, 160); // 轨道背景色（深空蓝）
    private int _cornerRadius = 8;        // 圆角半径
    private List<Particle> _particles = new List<Particle>(); // 粒子列表
    private Random _rand = new Random();  // 随机数生成器
    private float _glowPosition = -0.3f;  // 光晕当前位置（归一化坐标，-0.3 表示起始于左侧外）
    private Timer _timer;                 // 动画定时器
    private int _glowLoopCount = 0;       // 光晕循环次数
    private float _glowSpeed = 0.025f;    // 光晕基础速度（UWP风格速度）

    // --- 属性封装（支持数据绑定与自动重绘）---
    public float Value {
        get { return _value; }
        set { _value = Math.Max(_minimum, Math.Min(_maximum, value)); Invalidate(); }
    }

    public float Minimum {
        get { return _minimum; }
        set { _minimum = value; if (_value < _minimum) Value = _minimum; }
    }

    public float Maximum {
        get { return _maximum; }
        set { _maximum = value; if (_value > _maximum) Value = _maximum; }
    }

    public Color TrackColor {
        get { return _trackColor; }
        set { _trackColor = value; Invalidate(); }
    }

    public int CornerRadius {
        get { return _cornerRadius; }
        set { _cornerRadius = value; Invalidate(); }
    }

    // --- 构造函数：初始化控件样式与动画定时器 ---
    public AuroraProgressBar() {
        // 启用高级绘制模式：禁用默认 WM_PAINT、启用用户绘制、双缓冲、重绘时调整大小、不透明
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | 
                 ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Opaque, true);
        // 创建动态FPS的动画定时器
        _timer = new Timer();
        _timer.Interval = AuroraRenderEngine.GetTimerInterval();
        _timer.Tick += (s, e) => { UpdateAnimation(); Invalidate(); };
        _timer.Start();
        // 初始化时设置控件区域
        UpdateRegion();
    }

    // --- 重写 OnResize 方法，设置控件区域为圆角矩形 ---
    protected override void OnResize(EventArgs e) {
        base.OnResize(e);
        UpdateRegion();
    }

    // --- 更新控件区域为圆角矩形 ---
    private void UpdateRegion() {
        using (var path = CreateRoundedRect(ClientRectangle, _cornerRadius)) {
            Region oldRegion = this.Region;
            this.Region = new Region(path);
            if (oldRegion != null) {
                oldRegion.Dispose();
            }
        }
    }

    // --- 资源释放：确保定时器和Region被正确关闭 ---
    protected override void Dispose(bool disposing) {
        if (disposing) {
            if (_timer != null) {
                _timer.Stop();
                _timer.Dispose();
            }
            if (this.Region != null) {
                this.Region.Dispose();
            }
        }
        base.Dispose(disposing);
    }

    // --- 动画更新逻辑：移动光晕 + 生成/老化粒子 ---
    private void UpdateAnimation() {
        try {
            // 光晕从左向右循环移动（-0.3 → 1.3）
            // UWP风格速度逻辑：第一遍正常速度，第二遍加速，循环
            if (_glowLoopCount % 2 == 0) {
                // 偶数次循环（第1、3、5...次）：正常速度
                _glowPosition += _glowSpeed;
            } else {
                // 奇数次循环（第2、4、6...次）：加速
                _glowPosition += _glowSpeed * 2;
            }
            
            if (_glowPosition > 1.3f) {
                _glowPosition = -0.3f;
                _glowLoopCount++;
            }

            // 计算当前进度比例
            float range = Math.Max(1, _maximum - _minimum);
            float progress = (float)(_value - _minimum) / range;

            // === 粒子生成优化点 1：最多允许 40 个粒子（原为 15）===
            if (AuroraRenderEngine.EnableParticleSystem && progress > 0 && _rand.NextDouble() < 0.85 && _particles.Count < 40) {
                if (ClientRectangle.Width > 0 && ClientRectangle.Height > 0) {
                    float w = ClientRectangle.Width;
                    float glowX = _glowPosition * w;
                    float filledWidth = w * progress;
                    // 仅在光晕位于已填充区域内时生成粒子
                    if (glowX >= 0 && glowX <= filledWidth) {
                        float x = glowX + (float)(_rand.NextDouble() * 12 - 6); // ±6 像素偏移
                        float y = (float)_rand.NextDouble() * ClientRectangle.Height;
                        // === 优化点 2：粒子寿命延长至 1.0~2.5 秒（原为 0.5~1.5）===
                        float life = (float)(_rand.NextDouble() * 1.5 + 1.0);
                        _particles.Add(new Particle(x, y, life));
                    }
                }
            }

            // 更新所有粒子状态并移除超龄粒子
            for (int i = _particles.Count - 1; i >= 0; i--) {
                try {
                    var p = _particles[i];
                p.Age += 0.0267f; // 每帧增加年龄
                    // 微小随机漂移（模拟流体扰动）
                    p.X += (float)(_rand.NextDouble() * 0.4 - 0.2);
                    p.Y += (float)(_rand.NextDouble() * 0.3 - 0.15);
                    if (p.Age >= p.Lifetime) _particles.RemoveAt(i);
                } catch { }
            }
        } catch { }
    }

    // --- 自定义绘制逻辑 ---
    protected override void OnPaint(PaintEventArgs e) {
        var g = e.Graphics;
        // 启用高质量抗锯齿与插值
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;

        Rectangle bounds = ClientRectangle;
        if (bounds.Width <= 0 || bounds.Height <= 0) return;

        // 0. 清除整个控件区域（防止鬼影）
        g.Clear(Color.Transparent);

        // 1. 绘制轨道背景（圆角矩形）
        using (var path = CreateRoundedRect(bounds, _cornerRadius))
        using (var brush = new SolidBrush(_trackColor)) {
            g.FillPath(brush, path);
        }

        // 2. 绘制进度填充（青绿三色渐变）
        float range = Math.Max(1, _maximum - _minimum);
        float progress = (float)(_value - _minimum) / range;
        if (progress > 0 && bounds.Width > 0 && bounds.Height > 0) {
            int fillW = (int)(bounds.Width * progress);
            if (fillW > 0) {
                Rectangle fillRect = new Rectangle(bounds.X, bounds.Y, fillW, bounds.Height);
                using (var path = CreateRoundedRect(fillRect, _cornerRadius)) {
                    ColorBlend blend = new ColorBlend();
                    blend.Positions = new float[] { 0f, 0.5f, 1f };
                    blend.Colors = new Color[] {
                        Color.FromArgb(176, 205, 249), // 浅蓝
                        Color.FromArgb(96, 155, 244),  // 中蓝
                        Color.FromArgb(109, 249, 75)   // 青绿（Aurora 主色）
                    };
                    using (var brush = new LinearGradientBrush(fillRect, Color.White, Color.White, LinearGradientMode.Horizontal)) {
                        brush.InterpolationColors = blend;
                        g.FillPath(brush, path);
                    }
                }
            }
        }

        // 3. 绘制动态光晕（PathGradientBrush 实现中心亮、边缘透明）
        if (bounds.Width > 0 && bounds.Height > 0) {
            float glowCenter = _glowPosition * bounds.Width;
            if (glowCenter >= -40 && glowCenter <= bounds.Width + 40) {
                int glowW = Math.Max(80, Math.Min(160, bounds.Width / 8)); // 光晕长度自适应
                Rectangle glowRect = new Rectangle((int)(glowCenter - glowW / 2), 0, glowW, bounds.Height);
                using (var path = CreateRoundedRect(glowRect, _cornerRadius)) {
                    using (var brush = new PathGradientBrush(path)) {
                        brush.CenterColor = Color.FromArgb(180, 255, 255, 255); // 半透明白色
                        brush.SurroundColors = new Color[] { Color.Transparent };
                        g.FillPath(brush, path);
                    }
                }
            }
        }

        // 4. 绘制粒子（优化点 3 & 4：更亮、更大）
        foreach (var p in _particles) {
            float alphaFactor = (1 - p.Age / p.Lifetime);
            float alpha = alphaFactor * 200; // === 优化点 3：基础不透明度提升 ===
            if (alpha > 10) {
                float size = 1f + (alphaFactor * 1f); // === 优化点 4：粒子尺寸增大至最大 2px ===
                using (var brush = new SolidBrush(Color.FromArgb((int)alpha, 200, 200, 200))) {
                    g.FillEllipse(brush, p.X - size/2, p.Y - size/2, size, size);
                }
                // 可选：添加微弱发光边框增强立体感
                using (var pen = new Pen(Color.FromArgb((int)(alpha * 0.7), 200, 255, 200), 0.5f)) {
                    g.DrawEllipse(pen, p.X - size/2, p.Y - size/2, size, size);
                }
            }
        }
    }

    // --- 辅助方法：创建圆角矩形路径 ---
    private GraphicsPath CreateRoundedRect(Rectangle rect, int radius) {
        var path = new GraphicsPath();
        
        // ====== 核心修复：防崩溃安全锁 ======
        if (radius <= 0 || rect.Width <= radius * 2 || rect.Height <= radius * 2) {
            path.AddRectangle(rect);
            return path;
        }
        int d = radius * 2;
        path.AddArc(rect.X, rect.Y, d, d, 180, 90);
        path.AddLine(rect.X + radius, rect.Y, rect.Right - radius, rect.Y);
        path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90);
        path.AddLine(rect.Right, rect.Y + radius, rect.Right, rect.Bottom - radius);
        path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
        path.AddLine(rect.Right - radius, rect.Bottom, rect.X + radius, rect.Bottom);
        path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90);
        path.AddLine(rect.X, rect.Bottom - radius, rect.X, rect.Y + radius);
        path.CloseFigure();
        return path;
    }

    // --- 粒子类：轻量级结构存储位置、年龄、寿命 ---
    private class Particle {
        public float X, Y;
        public float Age = 0;
        public readonly float Lifetime;
        public Particle(float x, float y, float life) {
            X = x;
            Y = y;
            Lifetime = life;
        }
    }
}

///////////////////////////////////////////////////////////////////////////////

// =============== TECH BUTTON（极光玻璃风格动态按钮）===============
// 特性：
// - 垂直青紫渐变背景（Base / Hover / Press 三种状态）
// - 鼠标悬停触发动态扫光（单次、非循环），即使鼠标移出也完整播放
// - 按下时轻微缩放 + 投影，悬停时轻微放大 + 内发光（现在也能完整淡出！）
// - 弹性动画（ease-out cubic）实现平滑过渡
// - 统一的动画管理器，优化性能

// 动画管理器：统一管理所有动画
public class AnimationManager
{
    private Timer _timer;
    private List<Animation> _animations;
    private bool _isRunning;

    public AnimationManager()
    {
        _timer = new Timer { Interval = 16 }; // ~60 FPS
        _timer.Tick += OnTimerTick;
        _animations = new List<Animation>();
        _isRunning = false;
    }

    public void AddAnimation(Animation animation)
    {
        _animations.Add(animation);
        if (!_isRunning)
        {
            _timer.Start();
            _isRunning = true;
        }
    }

    public void RemoveAnimation(Animation animation)
    {
        _animations.Remove(animation);
        if (_animations.Count == 0 && _isRunning)
        {
            _timer.Stop();
            _isRunning = false;
        }
    }

    public void Clear()
    {
        _animations.Clear();
        if (_isRunning)
        {
            _timer.Stop();
            _isRunning = false;
        }
    }

    private void OnTimerTick(object sender, EventArgs e)
    {
        for (int i = _animations.Count - 1; i >= 0; i--)
        {
            var animation = _animations[i];
            if (!animation.Update())
            {
                _animations.RemoveAt(i);
            }
        }

        if (_animations.Count == 0 && _isRunning)
        {
            _timer.Stop();
            _isRunning = false;
        }
    }

    public void Dispose()
    {
        if (_timer != null)
        {
            _timer.Stop();
            _timer.Dispose();
        }
        _animations.Clear();
    }
}

// 动画基类
public abstract class Animation
{
    public abstract bool Update(); // 返回 true 表示动画继续，false 表示动画结束
}

// 按钮状态枚举
public enum ButtonState
{
    Normal,
    Hover,
    Press,
    Disabled,
    Loading,
    Success,
    Failure
}

// 按钮状态机
public class ButtonStateMachine
{
    private ButtonState _currentState;
    private TechButton _button;

    public ButtonStateMachine(TechButton button)
    {
        _button = button;
        _currentState = ButtonState.Normal;
    }

    public void TransitionTo(ButtonState newState)
    {
        if (_currentState == newState)
            return;

        _currentState = newState;
        _button.Invalidate();
    }

    public ButtonState CurrentState {
        get { return _currentState; }
    }
}

// 缓动函数类型
public enum EasingType
{
    Linear,
    EaseInCubic,
    EaseOutCubic,
    EaseInOutCubic
}

// 具体动画实现
public class FloatAnimation : Animation
{
    private float _startValue;
    private float _targetValue;
    private float _currentValue;
    private float _duration;
    private float _elapsed;
    private Action<float> _onUpdate;
    private Action _onComplete;
    private EasingType _easingType;

    public FloatAnimation(float startValue, float targetValue, float duration, Action<float> onUpdate, EasingType easingType = EasingType.EaseOutCubic, Action onComplete = null)
    {
        _startValue = startValue;
        _targetValue = targetValue;
        _currentValue = startValue;
        _duration = duration;
        _elapsed = 0;
        _onUpdate = onUpdate;
        _onComplete = onComplete;
        _easingType = easingType;
    }

    public override bool Update()
    {
        _elapsed += 0.016f; // 16ms per frame
        float progress = Math.Min(1.0f, _elapsed / _duration);
        float easedProgress = progress;
        
        // 根据缓动类型计算进度
        switch (_easingType)
        {
            case EasingType.EaseInCubic:
                easedProgress = (float)Math.Pow(progress, 3);
                break;
            case EasingType.EaseOutCubic:
                easedProgress = 1 - (float)Math.Pow(1 - progress, 3);
                break;
            case EasingType.EaseInOutCubic:
                if (progress < 0.5f)
                    easedProgress = 4 * (float)Math.Pow(progress, 3);
                else
                    easedProgress = 1 - 4 * (float)Math.Pow(1 - progress, 3);
                break;
        }
        
        _currentValue = _startValue + (_targetValue - _startValue) * easedProgress;
        
        _onUpdate(_currentValue);
        
        if (progress >= 1.0f)
            {
                if (_onComplete != null)
                {
                    _onComplete.Invoke();
                }
                return false;
            }
        
        return true;
    }
}

// === 字体降级工具类 ===
public static class FontHelper
{
    private static readonly string[] EmojiFonts = { "Segoe UI Emoji", "Segoe UI Symbol", "Microsoft YaHei UI", "Microsoft Sans Serif" };
    private static readonly string[] MonoFonts = { "Cascadia Mono", "Consolas", "Courier New", "Lucida Console" };
    private static readonly string[] SansSerifFonts = { "Microsoft YaHei UI", "Segoe UI", "Microsoft Sans Serif", "Arial" };
    
    public static Font GetEmojiFont(float size, FontStyle style = FontStyle.Regular)
    {
        foreach (string fontName in EmojiFonts)
        {
            try { return new Font(fontName, size, style); }
            catch { continue; }
        }
        return new Font("Microsoft Sans Serif", size, style);
    }
    
    public static Font GetMonospaceFont(float size, FontStyle style = FontStyle.Regular)
    {
        foreach (string fontName in MonoFonts)
        {
            try { return new Font(fontName, size, style); }
            catch { continue; }
        }
        return new Font("Courier New", size, style);
    }
    
    public static Font GetSansSerifFont(float size, FontStyle style = FontStyle.Regular)
    {
        foreach (string fontName in SansSerifFonts)
        {
            try { return new Font(fontName, size, style); }
            catch { continue; }
        }
        return new Font("Microsoft Sans Serif", size, style);
    }
    
    public static Font GetFont(string[] fontNames, float size, FontStyle style = FontStyle.Regular)
    {
        foreach (string fontName in fontNames)
        {
            try { return new Font(fontName, size, style); }
            catch { continue; }
        }
        return new Font("Microsoft Sans Serif", size, style);
    }
    
    public static bool IsFontInstalled(string fontName)
    {
        try
        {
            using (Font font = new Font(fontName, 10))
            {
                return font.Name.Equals(fontName, StringComparison.InvariantCultureIgnoreCase);
            }
        }
        catch { return false; }
    }
}

public class TechButton : Control, System.Windows.Forms.IButtonControl
{
    // --- DialogResult 属性 ---
    private System.Windows.Forms.DialogResult _dialogResult = System.Windows.Forms.DialogResult.None;
    
    public System.Windows.Forms.DialogResult DialogResult {
        get { return _dialogResult; }
        set { _dialogResult = value; }
    }
    
    // --- 实现 IButtonControl 接口 ---
    private bool _isDefault = false;
    
    public void NotifyDefault(bool value)
    {
        _isDefault = value;
        Invalidate();
    }
    
    public void PerformClick()
    {
        OnClick(EventArgs.Empty);
    }
    
    // --- 状态标志与动画参数 ---
    private ButtonStateMachine _stateMachine;
    private AnimationManager _animationManager;
    
    private float _hoverProgress = 0f;       // 悬停缩放动画进度（0~1）
    private float _pressProgress = 0f;       // 按下动画进度
    private float _hoverColorProgress = 0f;  // 悬停颜色过渡进度
    private float _glowProgress = 0f;        // 内发光独立进度（0~1）
    private float _glareProgress = -0.3f;    // 扫光位置（-0.3 起始）
    private bool _isGlareSweepRunning = false;

    private Point _clickPoint;
    private DateTime _pressStartTime;
    private bool _isLongPress = false;
    private Timer _longPressTimer;
    private DateTime _lastClickTime = DateTime.MinValue;
    private const int ClickCooldown = 500; // 点击冷却时间，单位：毫秒
    private bool _isProcessingClick = false; // 标记是否正在处理点击事件，防止超快速点击

    // --- 颜色定义：玻璃质感三态配色 ---
    private static readonly Color GlassBaseTop = Color.FromArgb(173,252,220);
    private static readonly Color GlassBaseBottom = Color.FromArgb(16,140,222);//157,137,237
    private static readonly Color GlassHoverTop = Color.FromArgb(187,187,187);//176, 205, 249
    private static readonly Color GlassHoverBottom = Color.FromArgb(7,76,181);//174,124,251
    private static readonly Color GlassPressTop = Color.FromArgb(103,107,118);
    private static readonly Color GlassPressBottom = Color.FromArgb(9,9,127);

    private static Color ColorLerp(Color color1, Color color2, float amount)
    {
        amount = Math.Max(0, Math.Min(1, amount));
        int r = (int)(color1.R + (color2.R - color1.R) * amount);
        int g = (int)(color1.G + (color2.G - color1.G) * amount);
        int b = (int)(color1.B + (color2.B - color1.B) * amount);
        int a = (int)(color1.A + (color2.A - color1.A) * amount);
        return Color.FromArgb(a, r, g, b);
    }

    private static Color GetTopColor(bool isPressed, float progress)
    {
        return isPressed ? ColorLerp(GlassBaseTop, GlassPressTop, progress) : ColorLerp(GlassBaseTop, GlassHoverTop, progress);
    }

    private static Color GetBottomColor(bool isPressed, float progress)
    {
        return isPressed ? ColorLerp(GlassBaseBottom, GlassPressBottom, progress) : ColorLerp(GlassBaseBottom, GlassHoverBottom, progress);
    }

    public TechButton()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        this.Font = FontHelper.GetEmojiFont(10f);
        this.ForeColor = Color.FromArgb(255,255,255);
        this.Size = new Size(280, 48);
        this.Cursor = Cursors.Hand;
        this.TabStop = true;

        // 初始化状态机和动画管理器
        _stateMachine = new ButtonStateMachine(this);
        _animationManager = new AnimationManager();
        
        // 初始化长按定时器
        _longPressTimer = new Timer { Interval = 500 };
        _longPressTimer.Tick += OnLongPressTimerTick;
        
        // 初始化时设置控件区域
        UpdateRegion();
    }
    
    // 扫光动画类
    private class GlareSweepAnimation : Animation
    {
        private TechButton _button;
        private float _startProgress;
        private float _targetProgress;
        private float _currentProgress;
        private float _duration;
        private float _elapsed;
        
        public GlareSweepAnimation(TechButton button, float startProgress, float targetProgress, float duration)
        {
            _button = button;
            _startProgress = startProgress;
            _targetProgress = targetProgress;
            _currentProgress = startProgress;
            _duration = duration;
            _elapsed = 0;
        }
        
        public override bool Update()
        {
            _elapsed += 0.016f; // 16ms per frame
            float progress = Math.Min(1.0f, _elapsed / _duration);
            
            // 使用 ease-out cubic
            float easedProgress = 1 - (float)Math.Pow(1 - progress, 3);
            _currentProgress = _startProgress + (_targetProgress - _startProgress) * easedProgress;
            
            _button._glareProgress = _currentProgress;
            _button.Invalidate();
            
            if (progress >= 1.0f)
            {
                _button._isGlareSweepRunning = false;
                return false;
            }
            
            return true;
        }
    }
    
    private void StartGlareSweep()
    {
        if (!AuroraRenderEngine.EnableDynamicSweep) return;
        
        if (!_isGlareSweepRunning)
        {
            _isGlareSweepRunning = true;
            _glareProgress = -0.3f;
            var animation = new GlareSweepAnimation(this, -0.3f, 1.3f, 1.5f);
            _animationManager.AddAnimation(animation);
        }
    }
    
    private void OnLongPressTimerTick(object sender, EventArgs e)
    {
        _longPressTimer.Stop();
        if (ClientRectangle.Contains(PointToClient(Cursor.Position)))
        {
            _isLongPress = true;
            _stateMachine.TransitionTo(ButtonState.Press);
            // 触发长按事件
            OnLongPress(EventArgs.Empty);
        }
    }
    
    // 长按事件
    public event EventHandler LongPress;
    protected virtual void OnLongPress(EventArgs e)
    {
        if (LongPress != null)
        {
            LongPress.Invoke(this, e);
        }
    }

    // --- 键盘事件处理 ---
    protected override bool IsInputKey(Keys keyData)
    {
        if (keyData == Keys.Enter || keyData == Keys.Space)
        {
            return true;
        }
        return base.IsInputKey(keyData);
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space)
        {
            _stateMachine.TransitionTo(ButtonState.Press);
            _pressProgress = 0f;
            var animation = new FloatAnimation(0f, 1f, 0.3f, (value) => {
                _pressProgress = value;
                Invalidate();
            });
            _animationManager.AddAnimation(animation);
        }
    }

    protected override void OnKeyUp(KeyEventArgs e)
    {
        base.OnKeyUp(e);
        if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space)
        {
            _stateMachine.TransitionTo(ButtonState.Hover);
            _pressProgress = 0f;
            Invalidate();
        }
    }

    protected override void OnGotFocus(EventArgs e)
    {
        base.OnGotFocus(e);
        _stateMachine.TransitionTo(ButtonState.Hover);
        _hoverProgress = 0f;
        _hoverColorProgress = 0f;
        _glowProgress = 0f;
        
        // 启动悬停动画
        var hoverAnimation = new FloatAnimation(0f, 1f, 0.3f, (value) => {
            _hoverProgress = value;
            _hoverColorProgress = value;
            _glowProgress = value;
            Invalidate();
        });
        _animationManager.AddAnimation(hoverAnimation);
        
        // 启动扫光动画
        StartGlareSweep();
    }

    protected override void OnLostFocus(EventArgs e)
    {
        base.OnLostFocus(e);
        _stateMachine.TransitionTo(ButtonState.Normal);
        
        // 清除所有现有的动画，避免悬停动画与恢复动画冲突
        _animationManager.Clear();
        
        // 根据当前的hover进度动态调整恢复动画的持续时间
        // 当hover进度很小时，恢复动画应该更快完成，避免瞬间掠过时的不自然效果
        float currentProgress = Math.Max(_hoverProgress, _hoverColorProgress);
        float duration = Math.Max(0.1f, currentProgress * 0.3f); // 最小100ms，最大300ms
        
        // 启动恢复动画，使用 EaseInCubic 缓动函数，使动画更加自然
        var restoreAnimation = new FloatAnimation(currentProgress, 0f, duration, (value) => {
            _hoverProgress = value;
            _hoverColorProgress = value;
            _glowProgress = value;
            Invalidate();
        }, EasingType.EaseInCubic, () => {
            // 动画完成时确保所有进度值被重置为0，避免状态残留
            _hoverProgress = 0f;
            _hoverColorProgress = 0f;
            _glowProgress = 0f;
            Invalidate();
        });
        _animationManager.AddAnimation(restoreAnimation);
    }

    // --- 重写 OnResize 方法，设置控件区域为圆角矩形 ---
    protected override void OnResize(EventArgs e) {
        base.OnResize(e);
        UpdateRegion();
    }

    // --- 更新控件区域为圆角矩形 ---
    private void UpdateRegion() {
        using (var path = CreateRoundedRect(ClientRectangle, 12)) {
            Region oldRegion = this.Region;
            this.Region = new Region(path);
            if (oldRegion != null) {
                oldRegion.Dispose();
            }
        }
    }

    protected override void OnMouseEnter(EventArgs e)
    {
        base.OnMouseEnter(e);
        _stateMachine.TransitionTo(ButtonState.Hover);
        _hoverProgress = 0f;
        _hoverColorProgress = 0f;
        _glowProgress = 0f;
        
        // 清除现有的动画，确保新的动画能够正确启动
        _animationManager.Clear();
        
        // 启动悬停动画
        var hoverAnimation = new FloatAnimation(0f, 1f, 0.3f, (value) => {
            _hoverProgress = value;
            _hoverColorProgress = value;
            _glowProgress = value;
            Invalidate();
        });
        _animationManager.AddAnimation(hoverAnimation);
        
        // 检查扫光动画是否已经完成
        // 如果扫光动画已经完成，或者扫光进度已经达到终点，启动新的扫光动画
        if (!_isGlareSweepRunning || _glareProgress >= 1.3f)
        {
            // 重置扫光动画状态
            _isGlareSweepRunning = false;
            _glareProgress = -0.3f;
            
            // 启动扫光动画
            StartGlareSweep();
        }
        else
        {
            // 如果扫光动画正在播放，继续使用当前的进度值
            // 重新启动扫光动画，使用当前的进度值
            var glareAnimation = new GlareSweepAnimation(this, _glareProgress, 1.3f, 1.5f);
            _animationManager.AddAnimation(glareAnimation);
        }
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        _stateMachine.TransitionTo(ButtonState.Normal);
        
        // 清除所有现有的动画，避免悬停动画与恢复动画冲突
        // 这是解决快速移出时状态残留的关键
        _animationManager.Clear();
        
        // 即使鼠标移出，也要完成当前正在进行的扫光动画
        // 重新启动扫光动画，使用当前的进度值
        if (_isGlareSweepRunning && _glareProgress < 1.3f)
        {
            float remainingProgress = 1.3f - _glareProgress;
            float totalProgress = 1.3f - (-0.3f);
            float remainingDuration = (remainingProgress / totalProgress) * 1.5f; // 1.5f 是扫光动画的总时长
            
            var glareAnimation = new GlareSweepAnimation(this, _glareProgress, 1.3f, remainingDuration);
            _animationManager.AddAnimation(glareAnimation);
        }
        
        // 根据当前的hover进度动态调整恢复动画的持续时间
        // 当hover进度很小时，恢复动画应该更快完成，避免瞬间掠过时的不自然效果
        float currentProgress = Math.Max(_hoverProgress, _hoverColorProgress);
        float duration = Math.Max(0.1f, currentProgress * 0.3f); // 最小100ms，最大300ms
        
        // 启动恢复动画，使用 EaseInCubic 缓动函数，使动画更加自然
        var restoreAnimation = new FloatAnimation(currentProgress, 0f, duration, (value) => {
            _hoverProgress = value;
            _hoverColorProgress = value;
            _glowProgress = value;
            Invalidate();
        }, EasingType.EaseInCubic, () => {
            // 动画完成时确保所有进度值被重置为0，避免状态残留
            _hoverProgress = 0f;
            _hoverColorProgress = 0f;
            _glowProgress = 0f;
            Invalidate();
        });
        _animationManager.AddAnimation(restoreAnimation);
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        _stateMachine.TransitionTo(ButtonState.Press);
        _clickPoint = e.Location;
        _pressProgress = 0f;
        _pressStartTime = DateTime.Now;
        _isLongPress = false;
        
        // 启动长按检测
        _longPressTimer.Start();
        
        // 启动按下动画
        var pressAnimation = new FloatAnimation(0f, 1f, 0.2f, (value) => {
            _pressProgress = value;
            Invalidate();
        });
        _animationManager.AddAnimation(pressAnimation);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        _longPressTimer.Stop();
        
        if (!_isLongPress)
        {
            _stateMachine.TransitionTo(ButtonState.Hover);
            _pressProgress = 0f;
            Invalidate();
        }
    }
    
    protected override void OnClick(EventArgs e)
    {
        // 检查是否正在处理点击事件，防止超快速点击
        if (_isProcessingClick)
        {
            return;
        }
        
        // 检查点击冷却时间，防止短时间内重复触发
        DateTime now = DateTime.Now;
        if ((now - _lastClickTime).TotalMilliseconds >= ClickCooldown)
        {
            try
            {
                // 标记正在处理点击事件
                _isProcessingClick = true;
                
                // 更新最后点击时间
                _lastClickTime = now;
                
                // 调用基类 OnClick 来触发事件
                base.OnClick(e);
            }
            finally
            {
                // 无论如何都要重置处理状态
                _isProcessingClick = false;
            }
        }
    }

   protected override void OnPaint(PaintEventArgs e)
{
    var g = e.Graphics;
    g.SmoothingMode = SmoothingMode.AntiAlias;
    g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
    Rectangle bounds = ClientRectangle;
    if (bounds.Width <= 0 || bounds.Height <= 0) return;

    bool isPressed = _stateMachine.CurrentState == ButtonState.Press;
    bool isHover = _stateMachine.CurrentState == ButtonState.Hover;
    bool isDisabled = _stateMachine.CurrentState == ButtonState.Disabled;

    // === 1. 背景渐变 ===
    Color topColor = isPressed ? GetTopColor(true, _pressProgress) : GetTopColor(false, _hoverColorProgress);
    Color bottomColor = isPressed ? GetBottomColor(true, _pressProgress) : GetBottomColor(false, _hoverColorProgress);
    
    // 如果禁用，使用禁用颜色
    if (isDisabled)
    {
        topColor = Color.FromArgb(200, 200, 200);
        bottomColor = Color.FromArgb(150, 150, 150);
    }
    
    using (var bgPath = CreateRoundedRect(bounds, 12))
    using (var gradient = new LinearGradientBrush(bounds, topColor, bottomColor, LinearGradientMode.Vertical))
    {
        g.FillPath(gradient, bgPath);
    }

    // === 2. 【强化】外发光（模拟玻璃边缘反光）===
    // 使用更亮、更宽的光晕，增强“透光”感
    if (AuroraRenderEngine.EnableComplexGlow && isHover && !isDisabled)
    {
        Rectangle outerGlowBounds = new Rectangle(bounds.X - 4, bounds.Y - 4, bounds.Width + 8, bounds.Height + 8);
        using (var outerGlowPath = CreateRoundedRect(outerGlowBounds, 16))
        using (var outerGlowBrush = new PathGradientBrush(outerGlowPath))
        {
            outerGlowBrush.CenterColor = Color.FromArgb(80, 190, 255, 255); // 更亮青蓝
            outerGlowBrush.SurroundColors = new[] { Color.Transparent };
            g.FillPath(outerGlowBrush, outerGlowPath);
        }
    }

    // === 3. 【增强】底部投影（带模糊过渡）===
    // 投影稍大且柔和，增加悬浮深度
    if (AuroraRenderEngine.EnablePathGradientShadows)
    {
        using (var shadowPath = CreateRoundedRect(new Rectangle(-4, 8, bounds.Width + 8, bounds.Height + 4), 16))
        using (var shadowBrush = new PathGradientBrush(shadowPath))
        {
            shadowBrush.CenterColor = Color.FromArgb(30, 0, 0, 0);
            shadowBrush.SurroundColors = new[] { Color.Transparent };
            g.FillPath(shadowBrush, shadowPath);
        }
    }

    // === 4. 动态扫光（完整播放）===
    if (!isPressed && !isDisabled && _glareProgress <= 1.3f)
    {
        float glarePos = _glareProgress;
        int diagonal = (int)Math.Sqrt(bounds.Width * bounds.Width + bounds.Height * bounds.Height);
        int offset = (int)(glarePos * diagonal * 2 - diagonal);

        using (GraphicsPath glarePath = new GraphicsPath())
        {
            Point[] points = {
                new Point(-diagonal + offset, -20),
                new Point(20 + offset, -diagonal),
                new Point(diagonal + offset, 20),
                new Point(-20 + offset, diagonal)
            };
            glarePath.AddPolygon(points);

            using (PathGradientBrush glareBrush = new PathGradientBrush(points))
            {
                glareBrush.CenterColor = Color.FromArgb(160, 200, 255, 220);
                glareBrush.SurroundColors = new Color[] { Color.Transparent };
                g.FillPath(glareBrush, glarePath);
            }
        }
    }

    // === 5. 缩放变换 ===
    float scale = 1.0f;
    if (isHover)
    {
        float easeOutCubic = 1 - (float)Math.Pow(1 - _hoverProgress, 3);
        scale = 1.0f + easeOutCubic * 0.05f;
    }
    else if (isPressed)
    {
        float easeOutCubic = 1 - (float)Math.Pow(1 - _pressProgress, 3);
        scale = 1.0f - easeOutCubic * 0.03f;
    }

    var oldTransform = g.Transform;
    try
    {
        float centerX = bounds.Width / 2f;
        float centerY = bounds.Height / 2f;
        g.TranslateTransform(centerX, centerY);
        g.ScaleTransform(scale, scale);
        g.TranslateTransform(-centerX, -centerY);

        // === 6. 内发光：横向光带（非圆形）===
        if (_glowProgress > 0f && !isDisabled)
        {
            float glowHeightRatio = 0.7f;
            int glowHeight = Math.Max(4, (int)(bounds.Height * glowHeightRatio));
            int glowWidth = bounds.Width;

            Rectangle glowRect = new Rectangle(
                0,
                (bounds.Height - glowHeight) / 2,
                glowWidth,
                glowHeight
            );

            using (var glowPath = CreateRoundedRect(glowRect, 8))
            using (var brush = new PathGradientBrush(glowPath))
            {
                int alpha = (int)(_glowProgress * 180);
                brush.CenterColor = Color.FromArgb(alpha, 200, 255, 255);
                brush.SurroundColors = new[] { Color.Transparent };
                g.FillPath(brush, glowPath);
            }
        }

        // === 7. 按下状态阴影（下沉感）===
        if (AuroraRenderEngine.EnablePathGradientShadows && isPressed)
        {
            int shadowOffset = 2 + (int)(_pressProgress * 2);
            using (var shadowPath = CreateRoundedRect(new Rectangle(-4, shadowOffset + 4, bounds.Width + 8, bounds.Height + 4), 16))
            using (var brush = new PathGradientBrush(shadowPath))
            {
                int alpha = (int)(_pressProgress * 50);
                brush.CenterColor = Color.FromArgb(alpha, 0, 0, 0);
                brush.SurroundColors = new[] { Color.Transparent };
                g.FillPath(brush, shadowPath);
            }
        }
    }
    finally
    {
        g.Transform = oldTransform;
    }

    // === 8. 绘制文字（独立变换）===
    StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
    var oldTextTransform = g.Transform;
    try
    {
        float centerX = bounds.Width / 2f;
        float centerY = bounds.Height / 2f;
        g.TranslateTransform(centerX, centerY);
        g.ScaleTransform(scale, scale);
        g.TranslateTransform(-centerX, -centerY);
        
        // 禁用状态下的文字颜色
        Color textColor = isDisabled ? Color.FromArgb(100, 100, 100) : ForeColor;
        g.DrawString(Text, Font, new SolidBrush(textColor), bounds, sf);
    }
    finally
    {
        g.Transform = oldTextTransform;
    }

    // === 9. 绘制焦点框 ===
    if (this.Focused)
    {
        using (Pen focusPen = new Pen(Color.FromArgb(200, 255, 255, 255), 2))
        {
            focusPen.DashStyle = System.Drawing.Drawing2D.DashStyle.Dot;
            Rectangle focusRect = new Rectangle(4, 4, bounds.Width - 8, bounds.Height - 8);
            using (GraphicsPath focusPath = CreateRoundedRect(focusRect, 8))
            {
                g.DrawPath(focusPen, focusPath);
            }
        }
    }

    // === 10. 绘制加载状态 ===
    if (_stateMachine.CurrentState == ButtonState.Loading)
    {
        // 绘制加载动画（简单的圆形旋转）
        float loadingSize = Math.Min(bounds.Width, bounds.Height) * 0.6f;
        float loadingX = (bounds.Width - loadingSize) / 2;
        float loadingY = (bounds.Height - loadingSize) / 2;
        
        using (Pen loadingPen = new Pen(Color.White, 2))
        {
            loadingPen.DashStyle = System.Drawing.Drawing2D.DashStyle.Dot;
            g.DrawEllipse(loadingPen, loadingX, loadingY, loadingSize, loadingSize);
        }
    }

    // === 11. 绘制成功/失败状态 ===
    if (_stateMachine.CurrentState == ButtonState.Success)
    {
        // 绘制成功图标（简单的对勾）
        float iconSize = Math.Min(bounds.Width, bounds.Height) * 0.6f;
        float iconX = (bounds.Width - iconSize) / 2;
        float iconY = (bounds.Height - iconSize) / 2;
        
        using (Pen successPen = new Pen(Color.FromArgb(0, 200, 0), 3))
        {
            g.DrawLine(successPen, iconX + iconSize * 0.2f, iconY + iconSize * 0.5f, iconX + iconSize * 0.4f, iconY + iconSize * 0.7f);
            g.DrawLine(successPen, iconX + iconSize * 0.4f, iconY + iconSize * 0.7f, iconX + iconSize * 0.8f, iconY + iconSize * 0.3f);
        }
    }
    else if (_stateMachine.CurrentState == ButtonState.Failure)
    {
        // 绘制失败图标（简单的叉号）
        float iconSize = Math.Min(bounds.Width, bounds.Height) * 0.6f;
        float iconX = (bounds.Width - iconSize) / 2;
        float iconY = (bounds.Height - iconSize) / 2;
        
        using (Pen failurePen = new Pen(Color.FromArgb(200, 0, 0), 3))
        {
            g.DrawLine(failurePen, iconX + iconSize * 0.2f, iconY + iconSize * 0.2f, iconX + iconSize * 0.8f, iconY + iconSize * 0.8f);
            g.DrawLine(failurePen, iconX + iconSize * 0.8f, iconY + iconSize * 0.2f, iconX + iconSize * 0.2f, iconY + iconSize * 0.8f);
        }
    }
}

    // 状态管理方法
    public void SetLoading()
    {
        _stateMachine.TransitionTo(ButtonState.Loading);
        Invalidate();
    }
    
    public void SetSuccess()
    {
        _stateMachine.TransitionTo(ButtonState.Success);
        Invalidate();
    }
    
    public void SetFailure()
    {
        _stateMachine.TransitionTo(ButtonState.Failure);
        Invalidate();
    }
    
    public void SetNormal()
    {
        _stateMachine.TransitionTo(ButtonState.Normal);
        Invalidate();
    }
    
    public void SetDisabled(bool disabled)
    {
        _stateMachine.TransitionTo(disabled ? ButtonState.Disabled : ButtonState.Normal);
        Invalidate();
    }

    protected override void OnPaintBackground(PaintEventArgs e) { }

    private GraphicsPath CreateRoundedRect(Rectangle rect, int radius)
    {
        GraphicsPath path = new GraphicsPath();
        
        // ====== 核心修复：如果控件尺寸过小，不足以画圆角，直接返回直角矩形，防止 GDI+ 路径崩溃 ======
        if (radius <= 0 || rect.Width <= radius * 2 || rect.Height <= radius * 2) { 
            path.AddRectangle(rect); 
            return path; 
        }
        int d = radius * 2;
        path.AddArc(rect.X, rect.Y, d, d, 180, 90);
        path.AddLine(rect.X + radius, rect.Y, rect.Right - radius, rect.Y);
        path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90);
        path.AddLine(rect.Right, rect.Y + radius, rect.Right, rect.Bottom - radius);
        path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
        path.AddLine(rect.Right - radius, rect.Bottom, rect.X + radius, rect.Bottom);
        path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90);
        path.AddLine(rect.X, rect.Bottom - radius, rect.X, rect.Y + radius);
        path.CloseFigure();
        return path;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            if (_animationManager != null) {
                _animationManager.Dispose();
            }
            if (_longPressTimer != null) {
                _longPressTimer.Stop();
                _longPressTimer.Dispose();
            }
            if (this.Region != null) {
                this.Region.Dispose();
            }
        }
        base.Dispose(disposing);
    }
}

// ==================================================================================================================
// ====== AuroraPrivilegeIndicator：透明玻璃风格权限指示器 ======
// 特性：
// - 透明玻璃背景（与 AuroraConsoleBox 一致）
// - 固定边框效果（无悬停动画）
// - 状态图标和文字
public class AuroraPrivilegeIndicator : Control
{
    private string _statusText = "";
    private Color _statusColor = Color.FromArgb(255, 180, 100);
    private Font _statusFont;
    private Font _iconFont;
    private Color _bgColor = Color.FromArgb(120, 10, 14, 28);
    private Color _borderColor = Color.FromArgb(90, 100, 180, 255);
    private int _cornerRadius = 10;
    
    public string StatusText
    {
        get { return _statusText; }
        set { _statusText = value; Invalidate(); }
    }
    
    public Color StatusColor
    {
        get { return _statusColor; }
        set { _statusColor = value; Invalidate(); }
    }
    
    public bool IsAdminMode { get; set; }
    
    public AuroraPrivilegeIndicator()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                 ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw |
                 ControlStyles.SupportsTransparentBackColor, true);
        this.BackColor = Color.Transparent;
        
        _statusFont = new Font("Microsoft YaHei UI", 9.5f, FontStyle.Bold);
        _iconFont = new Font("Segoe UI Emoji", 10.5f, FontStyle.Bold);
        IsAdminMode = false;
    }
    
    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
        
        Rectangle bounds = ClientRectangle;
        if (bounds.Width <= 0 || bounds.Height <= 0) return;
        
        using (var path = CreateRoundedRectPath(bounds, _cornerRadius))
        {
            // 背景色（固定透明度，无动画）
            using (var brush = new SolidBrush(_bgColor))
            {
                g.FillPath(brush, path);
            }
            
            // 边框（固定样式，无动画）
            using (var borderPen = new Pen(Color.FromArgb(255, _borderColor.R, _borderColor.G, _borderColor.B), 1.5f))
            {
                g.DrawPath(borderPen, path);
            }
        }
        
        // 绘制状态图标和文字
        string icon = IsAdminMode ? "🛡️" : "⚠️";
        SizeF iconSize = g.MeasureString(icon, _iconFont);
        SizeF textSize = g.MeasureString(_statusText, _statusFont);
        int centerY = (bounds.Height - (int)Math.Max(iconSize.Height, textSize.Height)) / 2 + 1;
        
        using (var iconBrush = new SolidBrush(_statusColor))
        {
            g.DrawString(icon, _iconFont, iconBrush, 12, centerY);
        }
        
        using (var textBrush = new SolidBrush(_statusColor))
        {
            g.DrawString(_statusText, _statusFont, textBrush, 12 + (int)iconSize.Width + 8, centerY);
        }
    }
    
    private System.Drawing.Drawing2D.GraphicsPath CreateRoundedRectPath(Rectangle rect, int radius)
    {
        var path = new System.Drawing.Drawing2D.GraphicsPath();
        if (radius <= 0 || rect.Width <= radius * 2 || rect.Height <= radius * 2)
        {
            path.AddRectangle(rect);
            return path;
        }
        int d = radius * 2;
        path.AddArc(rect.X, rect.Y, d, d, 180, 90);
        path.AddLine(rect.X + radius, rect.Y, rect.Right - radius, rect.Y);
        path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90);
        path.AddLine(rect.Right, rect.Y + radius, rect.Right, rect.Bottom - radius);
        path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
        path.AddLine(rect.Right - radius, rect.Bottom, rect.X + radius, rect.Bottom);
        path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90);
        path.AddLine(rect.X, rect.Bottom - radius, rect.X, rect.Y + radius);
        path.CloseFigure();
        return path;
    }
    
    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            if (_statusFont != null) _statusFont.Dispose();
            if (_iconFont != null) _iconFont.Dispose();
        }
        base.Dispose(disposing);
    }
}

// ==================================================================================================================
// ====== 新增：AuroraTaskHUD 横向状态面板 ======
public enum TaskState { Pending, Running, Success, Error }
public enum TextTransitionState { Idle, FadingOut, FadingIn }

public class AuroraTaskHUD : Control
{
    private class TaskItem
    {
        public TaskState State;
        public string Text;
        public string DetailText;

        public TaskItem(TaskState state, string text)
        {
            State = state;
            Text = text;
            DetailText = "";
        }
    }

    private List<TaskItem> _tasks;
    private Timer _animationTimer;
    private float _breathingValue = 0f;
    private float _breathingSpeed = 0.05f;

    // UWP 文本动画状态
    private string _currentText = "";
    private string _nextText = "";
    private TextTransitionState _transitionState = TextTransitionState.Idle;
    private float _transitionProgress = 0f;
    
    // 语言属性
    private string _language = "CHS";
    public string Language
    {
        get { return _language; }
        set 
        { 
            if (_language != value)
            {
                _language = value;
                InitializeTasks();
            }
        }
    }

    public AuroraTaskHUD()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw, true);
        SetStyle(ControlStyles.SupportsTransparentBackColor, true);
        this.BackColor = Color.Transparent;
        
        // 调整为更扁长的横向尺寸
        this.Size = new Size(240, 80);
        this.Visible = false;

        InitializeTasks();

        _animationTimer = new Timer { Interval = 16 };
        _animationTimer.Tick += (s, e) =>
        {
            _breathingValue += _breathingSpeed;
            if (_breathingValue > Math.PI * 2) _breathingValue -= (float)(Math.PI * 2);

            // 文本滑动动画更新
            float transitionSpeed = 0.08f; 
            if (_transitionState == TextTransitionState.FadingOut)
            {
                _transitionProgress = Math.Min(1.0f, _transitionProgress + transitionSpeed);
                if (_transitionProgress >= 1.0f)
                {
                    _transitionState = TextTransitionState.FadingIn;
                    _transitionProgress = 0f;
                }
            }
            else if (_transitionState == TextTransitionState.FadingIn)
            {
                _transitionProgress = Math.Min(1.0f, _transitionProgress + transitionSpeed);
                if (_transitionProgress >= 1.0f)
                {
                    _transitionState = TextTransitionState.Idle;
                    _currentText = _nextText;
                    _nextText = "";
                    _transitionProgress = 0f;
                }
            }
            Invalidate();
        };
        _animationTimer.Start();
    }
    
    private void InitializeTasks()
    {
        _tasks = new List<TaskItem>();
        
        if (_language == "ENG")
        {
            _tasks.Add(new TaskItem(TaskState.Pending, "1. Detecting System Vitals"));
            _tasks.Add(new TaskItem(TaskState.Pending, "2. Risk Assessment"));
            _tasks.Add(new TaskItem(TaskState.Pending, "3. Executing Repair"));
            _tasks.Add(new TaskItem(TaskState.Pending, "4. Verification"));
        }
        else
        {
            _tasks.Add(new TaskItem(TaskState.Pending, "1. 正在进行环境侦测"));
            _tasks.Add(new TaskItem(TaskState.Pending, "2. 正在进行风险评估"));
            _tasks.Add(new TaskItem(TaskState.Pending, "3. 正在尝试定向自动修复"));
            _tasks.Add(new TaskItem(TaskState.Pending, "4. 正在验证修复结果"));
        }
    }

    public void SetStepStatus(int stepIndex, TaskState state, string detailText = "")
    {
        if (stepIndex >= 0 && stepIndex < _tasks.Count)
        {
            var task = _tasks[stepIndex];
            task.State = state;
            
            // 构造需要显示的完整文本（主标题 + 细节）
            string fullText = task.Text;
            if (!string.IsNullOrEmpty(detailText)) {
                fullText += " - " + detailText;
            }

            if (_currentText != fullText && _nextText != fullText)
            {
                _nextText = fullText;
                if (string.IsNullOrEmpty(_currentText)) {
                    _transitionState = TextTransitionState.FadingIn;
                } else {
                    _transitionState = TextTransitionState.FadingOut;
                }
                _transitionProgress = 0f;
            }
            Invalidate();
        }
    }
    
    public void SetLanguage(string language)
    {
        this.Language = language;
    }

    private float EaseInCubic(float t) { return t * t * t; }
    private float EaseOutCubic(float t) { return 1f - (float)Math.Pow(1f - t, 3); }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;

        Rectangle bounds = ClientRectangle;
        if (bounds.Width <= 0 || bounds.Height <= 0) return;

        // 1. 极光背景 (横向圆角)
        using (var path = CreateRoundedRect(bounds, 12))
        {
            using (var bgBrush = new SolidBrush(Color.FromArgb(140, 8, 12, 25))) { g.FillPath(bgBrush, path); }
            using (var topHighlight = new LinearGradientBrush(bounds, Color.FromArgb(80, 100, 200, 255), Color.Transparent, LinearGradientMode.Vertical))
            using (var highlightPen = new Pen(topHighlight, 1f)) { g.DrawPath(highlightPen, path); }
        }

        // 2. 横向绘制状态节点
        int startX = 20;
        int nodeY = 25;
        int nodeSpacing = 55;

        // 绘制连接线
        using (var linePen = new Pen(Color.FromArgb(80, 150, 180, 200), 2f)) {
            g.DrawLine(linePen, startX, nodeY, startX + nodeSpacing * (_tasks.Count - 1), nodeY);
        }

        Color currentHighlightColor = Color.FromArgb(100, 220, 255);

        for (int i = 0; i < _tasks.Count; i++)
        {
            var task = _tasks[i];
            int nodeX = startX + i * nodeSpacing;

            switch (task.State)
            {
                case TaskState.Pending:
                    using (var b = new SolidBrush(Color.FromArgb(255, 50, 60, 80))) g.FillEllipse(b, nodeX - 4, nodeY - 4, 8, 8);
                    break;
                case TaskState.Running:
                    float pulse = 1.0f + 0.3f * (float)Math.Sin(_breathingValue);
                    int outerSize = (int)(16 * pulse);
                    using (var glowBrush = new SolidBrush(Color.FromArgb(80, 0, 212, 255)))
                        g.FillEllipse(glowBrush, nodeX - outerSize/2, nodeY - outerSize/2, outerSize, outerSize);
                    using (var coreBrush = new SolidBrush(Color.FromArgb(255, 0, 212, 255)))
                        g.FillEllipse(coreBrush, nodeX - 4, nodeY - 4, 8, 8);
                    currentHighlightColor = Color.FromArgb(255, 180, 220, 255);
                    break;
                case TaskState.Success:
                    using (var coreBrush = new SolidBrush(Color.FromArgb(255, 109, 249, 75))) g.FillEllipse(coreBrush, nodeX - 5, nodeY - 5, 10, 10);
                    using (var ringPen = new Pen(Color.FromArgb(120, 109, 249, 75), 2)) g.DrawEllipse(ringPen, nodeX - 8, nodeY - 8, 16, 16);
                    break;
                case TaskState.Error:
                    using (var coreBrush = new SolidBrush(Color.FromArgb(255, 255, 80, 80))) g.FillEllipse(coreBrush, nodeX - 5, nodeY - 5, 10, 10);
                    using (var ringPen = new Pen(Color.FromArgb(150, 255, 80, 80), 2)) g.DrawEllipse(ringPen, nodeX - 8, nodeY - 8, 16, 16);
                    currentHighlightColor = Color.FromArgb(255, 255, 150, 150);
                    break;
            }
        }

        // 3. 绘制动态变化的 UWP 文本 (显示在图标下方)
        int textY = 48;
        using (var font = new Font("Microsoft YaHei UI", 8.5f, FontStyle.Bold))
        {
            if ((_transitionState == TextTransitionState.FadingOut || _transitionState == TextTransitionState.Idle) && !string.IsNullOrEmpty(_currentText))
            {
                float progress = _transitionState == TextTransitionState.FadingOut ? _transitionProgress : 0f;
                float eased = EaseInCubic(progress);
                float drawX = 15f - (eased * 10f); // 缩短滑动距离
                int alpha = (int)(255 * (1f - eased));
                if (alpha > 0) using (var b = new SolidBrush(Color.FromArgb(alpha, currentHighlightColor))) g.DrawString(_currentText, font, b, drawX, textY);
            }

            if (_transitionState == TextTransitionState.FadingIn && !string.IsNullOrEmpty(_nextText))
            {
                float progress = _transitionProgress;
                float eased = EaseOutCubic(progress);
                float drawX = 15f + (10f * (1f - eased));
                int alpha = (int)(255 * eased);
                if (alpha > 0) using (var b = new SolidBrush(Color.FromArgb(alpha, currentHighlightColor))) g.DrawString(_nextText, font, b, drawX, textY);
            }
        }
    }

    private GraphicsPath CreateRoundedRect(Rectangle rect, int radius) { 
        GraphicsPath path = new GraphicsPath();
        if (radius <= 0 || rect.Width <= radius * 2 || rect.Height <= radius * 2) { path.AddRectangle(rect); return path; }
        int d = radius * 2;
        path.AddArc(rect.X, rect.Y, d, d, 180, 90); path.AddLine(rect.X + radius, rect.Y, rect.Right - radius, rect.Y);
        path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90); path.AddLine(rect.Right, rect.Y + radius, rect.Right, rect.Bottom - radius);
        path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90); path.AddLine(rect.Right - radius, rect.Bottom, rect.X + radius, rect.Bottom);
        path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90); path.AddLine(rect.X, rect.Bottom - radius, rect.X, rect.Y + radius);
        path.CloseFigure(); return path;
    }
    protected override void Dispose(bool disposing) { if (disposing && _animationTimer != null) { _animationTimer.Stop(); _animationTimer.Dispose(); } base.Dispose(disposing); }
}

// ==================================================================================================================
// ====== 新增：AuroraResultModal 执行结果展示叠加层 (带极光效果) ======
public class AuroraResultModal : Control
{
    private string _actionName = "";
    private string _result = "";
    private string _output = "";
    private string _executionTime = "";
    private string _language = "CHS";
    
    // 全局透明度状态
    private float _globalAlpha = 0f;
    private enum ModalFadeState { Hidden, FadingIn, Idle, FadingOut }
    private ModalFadeState _fadeState = ModalFadeState.Hidden;
    
    // UWP标题切换动画
    private enum TextTransitionState { Idle, FadingOut, FadingIn }
    private TextTransitionState _titleTransitionState = TextTransitionState.Idle;
    private float _titleTransitionProgress = 0f;
    private string _titleCurrent = "ℹ️ 执行结果";
    private string _titleNext = "ℹ️ 执行结果";
    
    public Rectangle CloseButtonRect { get; private set; }
    public Rectangle OutputAreaRect { get; private set; }
    
    // 虚拟按钮动效状态变量
    private bool _isCloseHovered = false;
    private bool _isClosePressed = false;
    private float _closeHoverProg = 0f;
    private float _closePressProg = 0f;
    
    // 滚动相关变量
    private bool _isDragging = false;
    private Point _lastMousePos;
    private int _scrollOffset = 0;
    private int _maxScrollOffset = 0;
    private const int SCROLL_SPEED = 20;

    private Timer _animTimer;
    private float _globalPhase = 0f;
    
    // Emoji 字体支持
    private Font _textFont;
    private Font _emojiFont;

    public event EventHandler OnClose;
    
    // 辅助方法：创建圆角矩形
    private GraphicsPath CreateRoundedRect(Rectangle rect, int radius)
    {
        GraphicsPath path = new GraphicsPath();
        int diameter = radius * 2;
        Rectangle arcRect = new Rectangle(rect.X, rect.Y, diameter, diameter);
        // 左上角
        path.AddArc(arcRect, 180, 90);
        // 右上角
        arcRect.X = rect.Right - diameter;
        path.AddArc(arcRect, 270, 90);
        // 右下角
        arcRect.Y = rect.Bottom - diameter;
        path.AddArc(arcRect, 0, 90);
        // 左下角
        arcRect.X = rect.Left;
        path.AddArc(arcRect, 90, 90);
        path.CloseFigure();
        return path;
    }
    
    // 辅助方法：绘制高级虚拟按钮
    private void DrawAdvancedVirtualButton(Graphics g, Rectangle rect, string text, Color baseColor, float hoverProgress, float pressProgress)
    {
        // 计算按钮状态
        float scale = 1.0f + (hoverProgress * 0.04f) - (pressProgress * 0.05f);
        int centerX = rect.X + rect.Width / 2;
        int centerY = rect.Y + rect.Height / 2;
        int scaledWidth = (int)(rect.Width * scale);
        int scaledHeight = (int)(rect.Height * scale);
        Rectangle scaledRect = new Rectangle(
            centerX - scaledWidth / 2,
            centerY - scaledHeight / 2,
            scaledWidth,
            scaledHeight
        );
        
        // 绘制按钮背景
        using (GraphicsPath path = CreateRoundedRect(scaledRect, 8))
        {
            // 基础颜色
            Color buttonColor = Color.FromArgb(
                baseColor.R + (int)(hoverProgress * 30),
                baseColor.G + (int)(hoverProgress * 30),
                baseColor.B + (int)(hoverProgress * 30)
            );
            
            using (SolidBrush brush = new SolidBrush(buttonColor))
            {
                g.FillPath(brush, path);
            }
            
            // 发光边框
            if (hoverProgress > 0.1f)
            {
                float glowAlpha = hoverProgress * 150;
                using (Pen glowPen = new Pen(Color.FromArgb((int)glowAlpha, 100, 200, 255), 2f))
                {
                    g.DrawPath(glowPen, path);
                }
            }
        }
        
        // 绘制文字
        using (Font font = new Font("Microsoft YaHei UI", 10, FontStyle.Bold))
        using (SolidBrush textBrush = new SolidBrush(Color.White))
        {
            StringFormat sf = new StringFormat
            {
                Alignment = StringAlignment.Center,
                LineAlignment = StringAlignment.Center
            };
            g.DrawString(text, font, textBrush, scaledRect, sf);
        }
    }

    public AuroraResultModal()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        SetStyle(ControlStyles.SupportsTransparentBackColor, true);
        this.BackColor = Color.Transparent; 
        this.Dock = DockStyle.Fill;
        this.Visible = false;
        this.TabStop = true; // 确保可以接受 Tab 键聚焦

        _animTimer = new Timer { Interval = 16 }; // ~60 FPS
        _animTimer.Tick += (s, e) => {
            _globalPhase += 0.05f;
            if (_globalPhase > Math.PI * 2) _globalPhase -= (float)(Math.PI * 2);

            // 全局透明度过渡逻辑
            float fadeSpeed = 0.08f;
            if (_fadeState == ModalFadeState.FadingIn) {
                _globalAlpha = Math.Min(1.0f, _globalAlpha + fadeSpeed);
                if (_globalAlpha >= 1.0f) {
                    _fadeState = ModalFadeState.Idle;
                }
            } else if (_fadeState == ModalFadeState.FadingOut) {
                _globalAlpha = Math.Max(0f, _globalAlpha - fadeSpeed);
                if (_globalAlpha <= 0f) {
                    _fadeState = ModalFadeState.Hidden;
                    this.Visible = false;
                }
            }

            // 虚拟按钮独立缓动逻辑 (Hover & Press)
            float btnSpeed = 0.12f;
            _closeHoverProg = Math.Max(0f, Math.Min(1f, _closeHoverProg + (_isCloseHovered ? btnSpeed : -btnSpeed)));
            _closePressProg = Math.Max(0f, Math.Min(1f, _closePressProg + (_isClosePressed ? btnSpeed : -btnSpeed)));
            
            // UWP标题切换动画
            float textSpeed = 0.08f;
            if (_titleTransitionState == TextTransitionState.FadingOut) {
                _titleTransitionProgress = Math.Min(1.0f, _titleTransitionProgress + textSpeed);
                if (_titleTransitionProgress >= 1.0f) {
                    _titleTransitionState = TextTransitionState.FadingIn;
                    _titleCurrent = _titleNext;
                    _titleTransitionProgress = 0f;
                }
            } else if (_titleTransitionState == TextTransitionState.FadingIn) {
                _titleTransitionProgress = Math.Min(1.0f, _titleTransitionProgress + textSpeed);
                if (_titleTransitionProgress >= 1.0f) {
                    _titleTransitionState = TextTransitionState.Idle;
                    _titleTransitionProgress = 0f;
                }
            }

            Invalidate();
        };
        _animTimer.Start();

        // 鼠标事件接管
        this.MouseMove += (s, e) => {
            if (CloseButtonRect.Width > 0 && CloseButtonRect.Contains(e.Location)) {
                _isCloseHovered = true;
            } else {
                _isCloseHovered = false;
            }
            
            // 处理滚动拖动
            if (_isDragging && OutputAreaRect.Width > 0 && OutputAreaRect.Contains(e.Location)) {
                int deltaY = e.Y - _lastMousePos.Y;
                _scrollOffset += deltaY;
                _scrollOffset = Math.Max(0, Math.Min(_maxScrollOffset, _scrollOffset));
                _lastMousePos = e.Location;
                Invalidate();
            }
        };

        this.MouseDown += (s, e) => {
            if (e.Button == MouseButtons.Left) {
                if (CloseButtonRect.Width > 0 && CloseButtonRect.Contains(e.Location)) {
                    _isClosePressed = true;
                } else if (OutputAreaRect.Width > 0 && OutputAreaRect.Contains(e.Location)) {
                    _isDragging = true;
                    _lastMousePos = e.Location;
                }
            }
        };

        this.MouseUp += (s, e) => {
            if (e.Button == MouseButtons.Left) {
                if (_isClosePressed && CloseButtonRect.Width > 0 && CloseButtonRect.Contains(e.Location) && OnClose != null) {
                    OnClose(this, EventArgs.Empty);
                }
                _isClosePressed = false;
                _isDragging = false;
            }
        };

        this.MouseLeave += (s, e) => { 
            _isCloseHovered = false; 
            _isClosePressed = false;
            _isDragging = false;
        };
        
        // 添加鼠标滚轮事件处理
        this.MouseWheel += (s, e) => {
            if (OutputAreaRect.Contains(this.PointToClient(Cursor.Position))) {
                _scrollOffset -= e.Delta / 120 * SCROLL_SPEED;
                _scrollOffset = Math.Max(0, Math.Min(_maxScrollOffset, _scrollOffset));
                Invalidate();
            }
        };
        
        // 添加键盘事件处理
        this.KeyDown += (s, e) => {
            switch (e.KeyCode) {
                case Keys.Enter:
                case Keys.Space:
                case Keys.Escape:
                    // 触发关闭按钮
                    if (OnClose != null) OnClose(this, EventArgs.Empty);
                    e.Handled = true;
                    break;
            }
        };
        
        // 初始化字体
        _emojiFont = FontHelper.GetEmojiFont(11.0f);
        _textFont = FontHelper.GetSansSerifFont(11.0f);
    }

    public void FadeInModal() {
        this.Visible = true;
        _fadeState = ModalFadeState.FadingIn;
        _globalAlpha = 0f;
        this.Focus(); // 让控件获取焦点，键盘事件才能生效
    }

    public void FadeOutModal() {
        _fadeState = ModalFadeState.FadingOut;
    }

    public void UpdateInfo(string actionName, string result, string output, string executionTime, string lang) {
        _language = lang;
        string newTitle = "";
        if (_language == "CHS") {
            newTitle = "ℹ️ 执行结果";
        } else {
            newTitle = "ℹ️ Execution Result";
        }
        
        // 触发标题切换动画
        _titleNext = newTitle;
        if (_titleCurrent != newTitle) {
            _titleTransitionState = TextTransitionState.FadingOut;
            _titleTransitionProgress = 0f;
        }
        
        _actionName = actionName;
        _result = result;
        _output = output;
        _executionTime = executionTime;
    }
    
    private string GetActionLabel() {
        return _language == "CHS" ? "操作: " : "Action: ";
    }
    
    private string GetResultLabel() {
        return _language == "CHS" ? "结果: " : "Result: ";
    }
    
    private string GetTimeLabel() {
        return _language == "CHS" ? "执行时间: " : "Execution Time: ";
    }
    
    private string GetCloseButtonText() {
        return _language == "CHS" ? "关闭" : "Close";
    }
    
    private float EaseOutCubic(float t) {
        return 1f - (float)Math.Pow(1f - t, 3);
    }
    
    private float EaseInCubic(float t) {
        return t * t * t;
    }

    protected override void OnPaint(PaintEventArgs e) {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;

        // 全屏暗化遮罩
        using (var dimBrush = new SolidBrush(Color.FromArgb((int)(180 * _globalAlpha), 5, 8, 15))) { g.FillRectangle(dimBrush, ClientRectangle); }

        int pW = 700;
        // 使用 ease-out 缓动算法计算当前的展开比例
        float unfoldEased = 1f - (float)Math.Pow(1f - _globalAlpha, 3);
        // 高度随透明度动态展开，最小4px防止GDI+崩溃
        int currentHeight = Math.Max(4, (int)(600 * unfoldEased));
        int pX = (this.Width - pW) / 2;
        int pY = (this.Height - currentHeight) / 2;
        Rectangle pRect = new Rectangle(pX, pY, pW, currentHeight);

        // 中央面板
        using (var path = CreateRoundedRect(pRect, 16)) {
            using (var bgBrush = new SolidBrush(Color.FromArgb((int)(240 * _globalAlpha), 15, 20, 35))) { g.FillPath(bgBrush, path); }
            float pulse = 1.0f + 0.5f * (float)Math.Sin(_globalPhase);
            int alpha = (int)((100 + 50 * pulse) * _globalAlpha);
            using (var topHighlight = new LinearGradientBrush(pRect, Color.FromArgb(alpha, 60, 180, 255), Color.Transparent, LinearGradientMode.Vertical))
            using (var highlightPen = new Pen(topHighlight, 2f)) { g.DrawPath(highlightPen, path); }
        }

        // 标题部分 - UWP 文本切换动效
        using (var titleFont = new Font("Microsoft YaHei UI", 13, FontStyle.Bold)) {
            StringFormat sf = new StringFormat { Alignment = StringAlignment.Center };
            
            // 绘制旧标题淡出
            if ((_titleTransitionState == TextTransitionState.FadingOut || _titleTransitionState == TextTransitionState.Idle) && !string.IsNullOrEmpty(_titleCurrent)) {
                float prog = _titleTransitionState == TextTransitionState.FadingOut ? _titleTransitionProgress : 0f;
                float eased = EaseInCubic(prog);
                float drawX = (float)pX - (eased * 20f) + pW / 2f - g.MeasureString(_titleCurrent, titleFont).Width / 2f;
                int alpha = (int)(255 * (1f - eased) * _globalAlpha);
                if (alpha > 0) {
                    using (var brush = new SolidBrush(Color.FromArgb(alpha, 100, 200, 255))) {
                        DrawTextWithEmoji(g, _titleCurrent, drawX, pY + 20, brush, titleFont);
                    }
                }
            }
            
            // 绘制新标题淡入
            if (_titleTransitionState == TextTransitionState.FadingIn && !string.IsNullOrEmpty(_titleNext)) {
                float prog = _titleTransitionProgress;
                float eased = EaseOutCubic(prog);
                float drawX = (float)pX + (20f * (1f - eased)) + pW / 2f - g.MeasureString(_titleNext, titleFont).Width / 2f;
                int alpha = (int)(255 * eased * _globalAlpha);
                if (alpha > 0) {
                    using (var brush = new SolidBrush(Color.FromArgb(alpha, 100, 200, 255))) {
                        DrawTextWithEmoji(g, _titleNext, drawX, pY + 20, brush, titleFont);
                    }
                }
            } else if (_titleTransitionState == TextTransitionState.Idle) {
                // 静态时的标题
                float drawX = pX + pW / 2f - g.MeasureString(_titleCurrent, titleFont).Width / 2f;
                using (var titleBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), 100, 200, 255))) {
                    using (var glowBrush = new SolidBrush(Color.FromArgb((int)(100 * _globalAlpha), 100, 200, 255))) {
                        for (int i = -1; i <= 1; i++) {
                            for (int j = -1; j <= 1; j++) {
                                if (i != 0 || j != 0) {
                                    DrawTextWithEmoji(g, _titleCurrent, drawX + i, pY + 20 + j, glowBrush, titleFont);
                                }
                            }
                        }
                    }
                    DrawTextWithEmoji(g, _titleCurrent, drawX, pY + 20, titleBrush, titleFont);
                }
            }
        }
        using (var linePen = new Pen(Color.FromArgb((int)(80 * _globalAlpha), 255, 255, 255), 1)) { g.DrawLine(linePen, pX + 30, pY + 65, pX + pW - 30, pY + 65); }

        // 操作名称 - 优化布局
        int textX = pX + 30; int actY = pY + 85;
        using (var contentFont = new Font("Microsoft YaHei UI", 11, FontStyle.Bold))
        using (var contentBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), 255, 255, 255))) {
            // 自动换行处理
            string actionText = GetActionLabel() + _actionName;
            SizeF textSize = g.MeasureString(actionText, contentFont, pW - 60);
            int lines = (int)Math.Ceiling(textSize.Width / (pW - 60));
            g.DrawString(actionText, contentFont, contentBrush, new RectangleF(textX, actY, pW - 60, lines * 20), new StringFormat());
            actY += lines * 20;
        }

        // 执行结果 - 优化布局，成功时用绿色
        int resultY = actY;
        bool isSuccess = _result.Contains("成功") || _result.Contains("Success") || _result.Contains("successful");
        using (var resultFont = new Font("Microsoft YaHei UI", 11))
        using (var resultBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), isSuccess ? 109 : 255, isSuccess ? 249 : 100, isSuccess ? 75 : 100))) {
            // 自动换行处理
            string resultText = GetResultLabel() + _result;
            SizeF textSize = g.MeasureString(resultText, resultFont, pW - 60);
            int lines = (int)Math.Ceiling(textSize.Width / (pW - 60));
            g.DrawString(resultText, resultFont, resultBrush, new RectangleF(textX, resultY, pW - 60, lines * 20), new StringFormat());
            resultY += lines * 20;
        }

        // 执行时间 - 优化布局
        int timeY = resultY;
        using (var timeFont = new Font("Microsoft YaHei UI", 10))
        using (var timeBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), 180, 180, 180))) {
            g.DrawString(GetTimeLabel() + _executionTime, timeFont, timeBrush, textX, timeY);
        }

        // 输出内容
        int outputY = timeY + 20;
        int outputHeight = Math.Max(1, currentHeight - (outputY - pY) - 60); // 核心修复：防止高度为负数导致 GDI+ FillRectangle 崩溃
        OutputAreaRect = new Rectangle(pX + 25, outputY, pW - 50, outputHeight);
        
        using (var outputFont = new Font("Consolas", 9))
        using (var outputBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), 200, 200, 200))) {
            // 绘制输出内容，支持自动换行
            string[] outputLines = _output.Split(new string[] { "\n" }, StringSplitOptions.None);
            int lineHeight = (int)g.MeasureString("Test", outputFont).Height;
            
            // 计算最大宽度
            int maxWidth = pW - 60;
            
            // 处理每一行，进行自动换行
            List<string> wrappedLines = new List<string>();
            foreach (string line in outputLines) {
                string trimmedLine = line.Trim();
                if (!string.IsNullOrEmpty(trimmedLine)) {
                    // 检查是否需要换行
                    SizeF textSize = g.MeasureString(trimmedLine, outputFont);
                    if (textSize.Width <= maxWidth) {
                        wrappedLines.Add(trimmedLine);
                    } else {
                        // 进行手动换行
                        char[] delimiters = new char[] { ' ', ':', ';', ',', '.' };
                        string[] words = trimmedLine.Split(delimiters);
                        string currentLine = "";
                        
                        foreach (string word in words) {
                            string testLine = currentLine + (currentLine.Length > 0 ? " " : "") + word;
                            SizeF testSize = g.MeasureString(testLine, outputFont);
                            
                            if (testSize.Width <= maxWidth) {
                                currentLine = testLine;
                            } else {
                                if (!string.IsNullOrEmpty(currentLine)) {
                                    wrappedLines.Add(currentLine);
                                }
                                currentLine = word;
                            }
                        }
                        
                        if (!string.IsNullOrEmpty(currentLine)) {
                            wrappedLines.Add(currentLine);
                        }
                    }
                } else {
                    wrappedLines.Add("");
                }
            }
            
            int maxLines = outputHeight / lineHeight;
            
            // 计算最大滚动偏移量
            int totalHeight = wrappedLines.Count * lineHeight;
            _maxScrollOffset = Math.Max(0, totalHeight - outputHeight);
            
            // 确保滚动偏移量在有效范围内
            _scrollOffset = Math.Max(0, Math.Min(_maxScrollOffset, _scrollOffset));
            
            // 绘制输出内容
            int startLine = _scrollOffset / lineHeight;
            int endLine = Math.Min(startLine + maxLines, wrappedLines.Count);
            
            for (int i = startLine; i < endLine; i++) {
                string line = wrappedLines[i];
                if (!string.IsNullOrEmpty(line)) {
                    int drawY = outputY + (i - startLine) * lineHeight;
                    g.DrawString(line, outputFont, outputBrush, textX, drawY);
                }
            }
        }
        
        // 绘制滚动条 (核心修复：增加 outputHeight > 20 的安全限制，防止除零或负数异常)
        if (_maxScrollOffset > 0 && outputHeight > 20) {
            int scrollBarWidth = 8;
            int scrollBarX = pX + pW - 30;
            int scrollBarY = outputY;
            int scrollBarHeight = outputHeight;
            
            // 绘制滚动条背景
            using (var scrollBarBgBrush = new SolidBrush(Color.FromArgb((int)(100 * _globalAlpha), 50, 50, 70))) {
                g.FillRectangle(scrollBarBgBrush, scrollBarX, scrollBarY, scrollBarWidth, scrollBarHeight);
            }
            
            // 计算滚动条滑块高度和位置
            int sliderHeight = Math.Max(20, (int)((float)scrollBarHeight * (float)outputHeight / (outputHeight + _maxScrollOffset)));
            int sliderY = scrollBarY + (int)((float)(scrollBarHeight - sliderHeight) * (float)_scrollOffset / _maxScrollOffset);
            
            // 绘制滚动条滑块
            using (var sliderBrush = new SolidBrush(Color.FromArgb((int)(200 * _globalAlpha), 100, 150, 200))) {
                g.FillRectangle(sliderBrush, scrollBarX, sliderY, scrollBarWidth, sliderHeight);
            }
        }

        // 关闭按钮
        int btnW = 120; int btnH = 40;
        CloseButtonRect = new Rectangle(pX + (pW - btnW) / 2, pY + currentHeight - 60, btnW, btnH);
        DrawAdvancedVirtualButton(g, CloseButtonRect, GetCloseButtonText(), Color.FromArgb(100, 100, 150), _closeHoverProg, _closePressProg);
    }
    
    // ====== Emoji 处理方法 ======
    private bool IsEmojiOrModifier(char c) {
        if (c == ' ') return false;
        if (char.IsHighSurrogate(c) || char.IsLowSurrogate(c)) return true;
        if (c == '\u200D' || (c >= '\uFE00' && c <= '\uFE0F') || (c >= '\u20D0' && c <= '\u20FF')) return true;
        if (c == '\u2139' || c == '\u26A0' || c == '\u2757' || c == '\u2699') return true;
        if ((c >= '\u2600' && c <= '\u27BF') || (c >= '\u2300' && c <= '\u23FF') || 
            (c >= '\u25A0' && c <= '\u25FF') || (c >= '\u2190' && c <= '\u21FF') || 
            (c >= '\u2B00' && c <= '\u2BFF') || (c >= '\u203C' && c <= '\u2049')) {
            return true;
        }
        return false;
    }
    
    private void DrawTextWithEmoji(Graphics g, string text, float x, float y, SolidBrush brush, Font baseFont) {
        if (string.IsNullOrEmpty(text)) return;
        
        // 直接使用 Segoe UI Emoji 字体绘制整段文本
        Font emojiFont = null;
        try {
            emojiFont = new Font("Segoe UI Emoji", baseFont.Size, baseFont.Style);
        } catch {
            emojiFont = baseFont;
        }
        
        // 简单策略：整段文本使用 emoji 字体绘制
        g.DrawString(text, emojiFont, brush, new PointF(x, y), StringFormat.GenericTypographic);
        
        if (emojiFont != null && emojiFont != baseFont) {
            emojiFont.Dispose();
        }
    }
    
    protected override void Dispose(bool disposing) { 
        if (disposing) {
            if (_animTimer != null) { _animTimer.Stop(); _animTimer.Dispose(); }
            if (_textFont != null) { _textFont.Dispose(); }
            if (_emojiFont != null) { _emojiFont.Dispose(); }
        }
        base.Dispose(disposing); 
    }
}

// ====== 新增：AuroraDecisionModal 全息高危授权叠加层 (带极光虚拟动效按钮) ======
public class AuroraDecisionModal : Control
{
    private string _actionName = "";
    private string _nextActionName = "";
    private string _riskLevel = "";
    private string _nextRiskLevel = "";
    private string _language = "CHS";
    
    // 文本过渡动画
    private enum TextTransitionState { Idle, FadingOut, FadingIn }
    private TextTransitionState _transitionState = TextTransitionState.Idle;
    private float _transitionProgress = 0f;
    
    // 标题过渡动画
    private TextTransitionState _titleTransitionState = TextTransitionState.Idle;
    private float _titleTransitionProgress = 0f;
    private string _titleCurrent = "⚠️ 修复操作授权申请";
    private string _titleNext = "⚠️ 修复操作授权申请";
    
    // ====== 新增：全局透明度状态 ======
    private float _globalAlpha = 0f;
    private enum ModalFadeState { Hidden, FadingIn, Idle, FadingOut }
    private ModalFadeState _fadeState = ModalFadeState.Hidden;
    
    public Rectangle AuthorizeButtonRect { get; private set; }
    public Rectangle SkipButtonRect { get; private set; }
    
    // 虚拟按钮动效状态变量
    private bool _isAuthHovered = false;
    private bool _isSkipHovered = false;
    private bool _isAuthPressed = false;
    private bool _isSkipPressed = false;
    
    private float _authHoverProg = 0f;
    private float _skipHoverProg = 0f;
    private float _authPressProg = 0f;
    private float _skipPressProg = 0f;

    private Timer _animTimer;
    private float _globalPhase = 0f;
    
    // Emoji 字体支持
    private Font _textFont;
    private Font _emojiFont;

    public event EventHandler OnAuthorize;
    public event EventHandler OnSkip;

    public AuroraDecisionModal()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        SetStyle(ControlStyles.SupportsTransparentBackColor, true);
        this.BackColor = Color.Transparent; 
        this.Dock = DockStyle.Fill;
        this.Visible = false;
        this.TabStop = true; // 确保可以接受 Tab 键聚焦

        _animTimer = new Timer { Interval = 16 }; // ~60 FPS
        _animTimer.Tick += (s, e) => {
            _globalPhase += 0.05f;
            if (_globalPhase > Math.PI * 2) _globalPhase -= (float)(Math.PI * 2);

            // ====== 新增：全局透明度过渡逻辑 ======
            float fadeSpeed = 0.08f;
            if (_fadeState == ModalFadeState.FadingIn) {
                _globalAlpha = Math.Min(1.0f, _globalAlpha + fadeSpeed);
                if (_globalAlpha >= 1.0f) {
                    _fadeState = ModalFadeState.Idle;
                }
            } else if (_fadeState == ModalFadeState.FadingOut) {
                _globalAlpha = Math.Max(0f, _globalAlpha - fadeSpeed);
                if (_globalAlpha <= 0f) {
                    _fadeState = ModalFadeState.Hidden;
                    this.Visible = false;
                }
            }

            // 1. 标题 UWP 文字滑动逻辑
            float textSpeed = 0.08f;
            if (_titleTransitionState == TextTransitionState.FadingOut) {
                _titleTransitionProgress = Math.Min(1.0f, _titleTransitionProgress + textSpeed);
                if (_titleTransitionProgress >= 1.0f) {
                    _titleTransitionState = TextTransitionState.FadingIn;
                    _titleCurrent = _titleNext;
                    _titleTransitionProgress = 0f;
                }
            } else if (_titleTransitionState == TextTransitionState.FadingIn) {
                _titleTransitionProgress = Math.Min(1.0f, _titleTransitionProgress + textSpeed);
                if (_titleTransitionProgress >= 1.0f) {
                    _titleTransitionState = TextTransitionState.Idle;
                    _titleTransitionProgress = 0f;
                }
            }
            
            // 2. 内容文字 UWP 滑动逻辑
            if (_transitionState == TextTransitionState.FadingOut) {
                _transitionProgress = Math.Min(1.0f, _transitionProgress + textSpeed);
                if (_transitionProgress >= 1.0f) { _transitionState = TextTransitionState.FadingIn; _transitionProgress = 0f; }
            } else if (_transitionState == TextTransitionState.FadingIn) {
                _transitionProgress = Math.Min(1.0f, _transitionProgress + textSpeed);
                if (_transitionProgress >= 1.0f) {
                    _transitionState = TextTransitionState.Idle;
                    _actionName = _nextActionName; _riskLevel = _nextRiskLevel; _transitionProgress = 0f;
                }
            }

            // 3. 虚拟按钮独立缓动逻辑 (Hover & Press)
            float btnSpeed = 0.12f;
            _authHoverProg = Math.Max(0f, Math.Min(1f, _authHoverProg + (_isAuthHovered ? btnSpeed : -btnSpeed)));
            _skipHoverProg = Math.Max(0f, Math.Min(1f, _skipHoverProg + (_isSkipHovered ? btnSpeed : -btnSpeed)));
            _authPressProg = Math.Max(0f, Math.Min(1f, _authPressProg + (_isAuthPressed ? btnSpeed : -btnSpeed)));
            _skipPressProg = Math.Max(0f, Math.Min(1f, _skipPressProg + (_isSkipPressed ? btnSpeed : -btnSpeed)));

            Invalidate();
        };
        _animTimer.Start();

        // 鼠标事件接管
        this.MouseMove += (s, e) => {
            bool newAuth = AuthorizeButtonRect.Contains(e.Location);
            bool newSkip = SkipButtonRect.Contains(e.Location);
            if (newAuth != _isAuthHovered || newSkip != _isSkipHovered) {
                _isAuthHovered = newAuth; _isSkipHovered = newSkip;
            }
        };

        this.MouseDown += (s, e) => {
            if (e.Button == MouseButtons.Left) {
                if (AuthorizeButtonRect.Contains(e.Location)) _isAuthPressed = true;
                if (SkipButtonRect.Contains(e.Location)) _isSkipPressed = true;
            }
        };

        this.MouseUp += (s, e) => {
            if (e.Button == MouseButtons.Left) {
                if (_isAuthPressed && AuthorizeButtonRect.Contains(e.Location) && OnAuthorize != null) OnAuthorize(this, EventArgs.Empty);
                if (_isSkipPressed && SkipButtonRect.Contains(e.Location) && OnSkip != null) OnSkip(this, EventArgs.Empty);
                _isAuthPressed = false;
                _isSkipPressed = false;
            }
        };

        this.MouseLeave += (s, e) => { 
            _isAuthHovered = false; _isSkipHovered = false; 
            _isAuthPressed = false; _isSkipPressed = false;
        };
        
        // 添加键盘事件处理
        this.KeyDown += (s, e) => {
            switch (e.KeyCode) {
                case Keys.Enter:
                case Keys.Space:
                    // 触发当前高亮按钮
                    if (_isAuthHovered && OnAuthorize != null) OnAuthorize(this, EventArgs.Empty);
                    else if (_isSkipHovered && OnSkip != null) OnSkip(this, EventArgs.Empty);
                    e.Handled = true;
                    break;
                case Keys.Escape:
                    // 触发跳过按钮
                    if (OnSkip != null) OnSkip(this, EventArgs.Empty);
                    e.Handled = true;
                    break;
                case Keys.Tab:
                    // 切换按钮焦点
                    if (e.Shift) {
                        // Shift+Tab 切换到上一个按钮
                        if (_isAuthHovered) {
                            _isAuthHovered = false;
                            _isSkipHovered = true;
                        } else {
                            _isSkipHovered = false;
                            _isAuthHovered = true;
                        }
                    } else {
                        // Tab 切换到下一个按钮
                        if (_isAuthHovered) {
                            _isAuthHovered = false;
                            _isSkipHovered = true;
                        } else {
                            _isSkipHovered = false;
                            _isAuthHovered = true;
                        }
                    }
                    Invalidate();
                    e.Handled = true;
                    break;
            }
        };
        
        // 初始化字体
        _emojiFont = FontHelper.GetEmojiFont(11.0f);
        _textFont = FontHelper.GetSansSerifFont(11.0f);
    }

    // ====== 新增：淡入淡出控制方法 ======
    public void FadeInModal()
    {
        this.Visible = true;
        _fadeState = ModalFadeState.FadingIn;
        _globalAlpha = 0f;
        _isAuthHovered = true; // 默认聚焦授权按钮
        this.Focus(); // 让控件获取焦点，键盘事件才能生效
    }

    public void FadeOutModal()
    {
        _fadeState = ModalFadeState.FadingOut;
    }

    public void UpdateInfo(string actionName, string riskLevel, string lang) {
        _language = lang;
        string newTitle = lang == "CHS" ? "⚠️ 修复操作授权申请" : "⚠️ Repair Operation Authorization Request";
        
        // 更新标题并触发动画
        _titleNext = newTitle;
        if (_titleCurrent != newTitle) {
            _titleTransitionState = TextTransitionState.FadingOut;
            _titleTransitionProgress = 0f;
        }
        
        _nextActionName = actionName; _nextRiskLevel = riskLevel;
        if (string.IsNullOrEmpty(_actionName)) { _transitionState = TextTransitionState.FadingIn; } 
        else { _transitionState = TextTransitionState.FadingOut; }
        _transitionProgress = 0f;
    }
    
    private float EaseInCubic(float t) { return t * t * t; }
    private float EaseOutCubic(float t) { return 1f - (float)Math.Pow(1f - t, 3); }

    private Color ColorLerp(Color c1, Color c2, float amount) {
        amount = Math.Max(0, Math.Min(1, amount));
        return Color.FromArgb(
            (int)(c1.A + (c2.A - c1.A) * amount), (int)(c1.R + (c2.R - c1.R) * amount),
            (int)(c1.G + (c2.G - c1.G) * amount), (int)(c1.B + (c2.B - c1.B) * amount)
        );
    }
    
    private Color GetRiskColor(string riskLevel) {
        if (string.IsNullOrEmpty(riskLevel)) return Color.FromArgb(80, 80, 80);
        
        string level = riskLevel.ToLower();
        if (level.Contains("high") || level.Contains("高")) {
            return Color.FromArgb(255, 80, 80);
        } else if (level.Contains("medium") || level.Contains("中")) {
            return Color.FromArgb(255, 200, 80);
        } else if (level.Contains("low") || level.Contains("低")) {
            return Color.FromArgb(80, 200, 80);
        }
        return Color.FromArgb(80, 80, 80);
    }
    
    private string GetRiskDisplayText(string riskLevel) {
        if (string.IsNullOrEmpty(riskLevel)) return "";
        
        string level = riskLevel.ToLower();
        if (_language == "CHS") {
            if (level.Contains("high") || level.Contains("高")) return "🔴 当前操作风险评估等级：高";
            if (level.Contains("medium") || level.Contains("中")) return "🟡 当前操作风险评估等级：中";
            if (level.Contains("low") || level.Contains("低")) return "🟢 当前操作风险评估等级：低";
            return "⚪ 当前操作风险评估等级：" + riskLevel;
        } else {
            if (level.Contains("high") || level.Contains("高")) return "🔴 Current Operation Risk Assessment Level: High";
            if (level.Contains("medium") || level.Contains("中")) return "🟡 Current Operation Risk Assessment Level: Medium";
            if (level.Contains("low") || level.Contains("低")) return "🟢 Current Operation Risk Assessment Level: Low";
            return "⚪ Current Operation Risk Assessment Level: " + riskLevel;
        }
    }
    
    private string GetAuthorizeButtonText() {
        return _language == "CHS" ? "授权执行 [ENTER]" : "Authorize [ENTER]";
    }
    
    private string GetSkipButtonText() {
        return _language == "CHS" ? "跳过此修复 [ESC]" : "Skip [ESC]";
    }
    
    private string GetActionLabel() {
        return _language == "CHS" ? "准备执行的修复操作：" : "Repair Operation to Execute: ";
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;

        // 全屏暗化遮罩
        using (var dimBrush = new SolidBrush(Color.FromArgb((int)(180 * _globalAlpha), 5, 8, 15))) { g.FillRectangle(dimBrush, ClientRectangle); }

        int pW = 520;
        // 使用 ease-out 缓动算法计算当前的展开比例
        float unfoldEased = 1f - (float)Math.Pow(1f - _globalAlpha, 3);
        // 高度随透明度动态展开，最小4px防止GDI+崩溃
        int currentHeight = Math.Max(4, (int)(240 * unfoldEased));
        int pX = (this.Width - pW) / 2;
        int pY = (this.Height - currentHeight) / 2;
        Rectangle pRect = new Rectangle(pX, pY, pW, currentHeight);

        // 确定当前风险颜色
        string currentRiskLevel = !string.IsNullOrEmpty(_riskLevel) ? _riskLevel : _nextRiskLevel;
        Color riskColor = GetRiskColor(currentRiskLevel);

        // 中央面板
        using (var path = CreateRoundedRect(pRect, 16)) {
            using (var bgBrush = new SolidBrush(Color.FromArgb((int)(240 * _globalAlpha), 15, 20, 35))) { g.FillPath(bgBrush, path); }
            float pulse = 1.0f + 0.5f * (float)Math.Sin(_globalPhase);
            int alpha = (int)((100 + 50 * pulse) * _globalAlpha);
            using (var topHighlight = new LinearGradientBrush(pRect, Color.FromArgb(alpha, riskColor.R, riskColor.G, riskColor.B), Color.Transparent, LinearGradientMode.Vertical))
            using (var highlightPen = new Pen(topHighlight, 2f)) { g.DrawPath(highlightPen, path); }
        }

        // 文字部分 - 标题 UWP 切换动画
        using (var titleFont = new Font("Microsoft YaHei UI", 13, FontStyle.Bold)) {
            StringFormat sf = new StringFormat { Alignment = StringAlignment.Center };
            
            // 绘制旧标题淡出
            if ((_titleTransitionState == TextTransitionState.FadingOut || _titleTransitionState == TextTransitionState.Idle) && !string.IsNullOrEmpty(_titleCurrent)) {
                float prog = _titleTransitionState == TextTransitionState.FadingOut ? _titleTransitionProgress : 0f;
                float eased = EaseInCubic(prog);
                float drawX = (float)pX - (eased * 20f) + pW / 2f - g.MeasureString(_titleCurrent, titleFont).Width / 2f;
                int alpha = (int)(255 * (1f - eased) * _globalAlpha);
                if (alpha > 0) {
                    using (var brush = new SolidBrush(Color.FromArgb(alpha, riskColor.R, riskColor.G, riskColor.B))) {
                        DrawTextWithEmoji(g, _titleCurrent, drawX, pY + 20, brush, titleFont);
                    }
                }
            }
            
            // 绘制新标题淡入
            if (_titleTransitionState == TextTransitionState.FadingIn && !string.IsNullOrEmpty(_titleNext)) {
                float prog = _titleTransitionProgress;
                float eased = EaseOutCubic(prog);
                float drawX = (float)pX + (20f * (1f - eased)) + pW / 2f - g.MeasureString(_titleNext, titleFont).Width / 2f;
                int alpha = (int)(255 * eased * _globalAlpha);
                if (alpha > 0) {
                    using (var brush = new SolidBrush(Color.FromArgb(alpha, riskColor.R, riskColor.G, riskColor.B))) {
                        DrawTextWithEmoji(g, _titleNext, drawX, pY + 20, brush, titleFont);
                    }
                }
            } else if (_titleTransitionState == TextTransitionState.Idle) {
                // 静态时的标题
                float drawX = pX + pW / 2f - g.MeasureString(_titleCurrent, titleFont).Width / 2f;
                using (var titleBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), riskColor.R, riskColor.G, riskColor.B))) {
                    DrawTextWithEmoji(g, _titleCurrent, drawX, pY + 20, titleBrush, titleFont);
                }
            }
        }
        using (var linePen = new Pen(Color.FromArgb((int)(80 * _globalAlpha), 255, 255, 255), 1)) { g.DrawLine(linePen, pX + 30, pY + 65, pX + pW - 30, pY + 65); }

        int textX = pX + 30; int actY = pY + 85; int riskY = pY + 120;
        using (var contentFont = new Font("Microsoft YaHei UI", 11))
        using (var boldFont = new Font("Microsoft YaHei UI", 11, FontStyle.Bold)) {
            if ((_transitionState == TextTransitionState.FadingOut || _transitionState == TextTransitionState.Idle) && !string.IsNullOrEmpty(_actionName)) {
                float prog = _transitionState == TextTransitionState.FadingOut ? _transitionProgress : 0f;
                float eased = EaseInCubic(prog); float drawX = textX - (eased * 20f); int alpha = (int)(255 * (1f - eased) * _globalAlpha);
                if (alpha > 0) {
                    string labelText = GetActionLabel();
                    float labelWidth = g.MeasureString(labelText, contentFont, new PointF(0,0), StringFormat.GenericTypographic).Width;
                    using (var labelBrush = new SolidBrush(Color.FromArgb(alpha, 200, 200, 255))) DrawTextWithEmoji(g, labelText, drawX, actY, labelBrush, contentFont);
                    using (var b = new SolidBrush(Color.FromArgb(alpha, Color.White))) g.DrawString(_actionName, boldFont, b, new PointF(drawX + labelWidth, actY));
                    Color rc = GetRiskColor(_riskLevel);
                    using (var rb = new SolidBrush(Color.FromArgb(alpha, rc.R, rc.G, rc.B))) DrawTextWithEmoji(g, GetRiskDisplayText(_riskLevel), drawX, riskY, rb, contentFont);
                }
            }
            if (_transitionState == TextTransitionState.FadingIn && !string.IsNullOrEmpty(_nextActionName)) {
                float prog = _transitionProgress; float eased = EaseOutCubic(prog); float drawX = textX + (20f * (1f - eased)); int alpha = (int)(255 * eased * _globalAlpha);
                if (alpha > 0) {
                    string labelText = GetActionLabel();
                    float labelWidth = g.MeasureString(labelText, contentFont, new PointF(0,0), StringFormat.GenericTypographic).Width;
                    using (var labelBrush = new SolidBrush(Color.FromArgb(alpha, 200, 200, 255))) DrawTextWithEmoji(g, labelText, drawX, actY, labelBrush, contentFont);
                    using (var b = new SolidBrush(Color.FromArgb(alpha, Color.White))) g.DrawString(_nextActionName, boldFont, b, new PointF(drawX + labelWidth, actY));
                    Color rc = GetRiskColor(_nextRiskLevel);
                    using (var rb = new SolidBrush(Color.FromArgb(alpha, rc.R, rc.G, rc.B))) DrawTextWithEmoji(g, GetRiskDisplayText(_nextRiskLevel), drawX, riskY, rb, contentFont);
                }
            }
        }

        // 虚拟按钮坐标
        int btnW = 180; int btnH = 45;
        AuthorizeButtonRect = new Rectangle(pX + 60, pY + currentHeight - 65, btnW, btnH);
        SkipButtonRect = new Rectangle(pX + pW - btnW - 60, pY + currentHeight - 65, btnW, btnH);

        DrawAdvancedVirtualButton(g, AuthorizeButtonRect, GetAuthorizeButtonText(), Color.FromArgb(20, 180, 100), _authHoverProg, _authPressProg);
        DrawAdvancedVirtualButton(g, SkipButtonRect, GetSkipButtonText(), Color.FromArgb(180, 50, 50), _skipHoverProg, _skipPressProg);
    }

    // 核心渲染引擎：全功能复刻 TechButton 动效
    private void DrawAdvancedVirtualButton(Graphics g, Rectangle rect, string text, Color baseColor, float hoverProg, float pressProg)
    {
        float easeHover = EaseOutCubic(hoverProg);
        float easePress = EaseOutCubic(pressProg);

        // 1. 矩阵变换实现真实缩放动效 (Hover放大，Press缩小)
        float scale = 1.0f + (easeHover * 0.04f) - (easePress * 0.05f);
        var oldTransform = g.Transform;
        float cx = rect.X + rect.Width / 2f;
        float cy = rect.Y + rect.Height / 2f;
        
        g.TranslateTransform(cx, cy);
        g.ScaleTransform(scale, scale);
        g.TranslateTransform(-cx, -cy);

        // 2. 绘制动态阴影
        int shadowOffset = 2 + (int)(easePress * 3);
        Rectangle shadowRect = new Rectangle(rect.X - 4, rect.Y + shadowOffset + 4, rect.Width + 8, rect.Height + 6);
        using (var shadowPath = CreateRoundedRect(shadowRect, 12))
        using (var pgb = new PathGradientBrush(shadowPath)) {
            pgb.CenterColor = Color.FromArgb((int)((40 + easeHover * 20) * _globalAlpha), 0, 0, 0);
            pgb.SurroundColors = new[] { Color.Transparent };
            g.FillPath(pgb, shadowPath);
        }

        // 3. 绘制发光外晕 (Hover 触发)
        if (easeHover > 0) {
            Rectangle glowRect = new Rectangle(rect.X - 6, rect.Y - 6, rect.Width + 12, rect.Height + 12);
            using (var glowPath = CreateRoundedRect(glowRect, 14))
            using (var pgb = new PathGradientBrush(glowPath)) {
                pgb.CenterColor = Color.FromArgb((int)(80 * easeHover * _globalAlpha), baseColor);
                pgb.SurroundColors = new[] { Color.Transparent };
                g.FillPath(pgb, glowPath);
            }
        }

        // 4. 绘制主体玻璃渐变
        using (var path = CreateRoundedRect(rect, 8))
        {
            Color topColor = ColorLerp(Color.FromArgb((int)(80 * _globalAlpha), baseColor), Color.FromArgb((int)(160 * _globalAlpha), baseColor), easeHover);
            Color bottomColor = ColorLerp(Color.FromArgb((int)(30 * _globalAlpha), baseColor), Color.FromArgb((int)(80 * _globalAlpha), baseColor), easeHover);
            if (easePress > 0) {
                topColor = ColorLerp(topColor, Color.FromArgb((int)(60 * _globalAlpha), baseColor), easePress);
                bottomColor = ColorLerp(bottomColor, Color.FromArgb((int)(20 * _globalAlpha), baseColor), easePress);
            }

            using (var brush = new LinearGradientBrush(rect, topColor, bottomColor, LinearGradientMode.Vertical)) {
                g.FillPath(brush, path);
            }

            // [Press 反馈] 按下时的 CRT 扫描横向暗纹，加深物理阻尼与电子感
            if (easePress > 0) {
                Region oldClip = g.Clip;
                g.SetClip(path); // 核心：限制在圆角按钮内部，防止网格溢出

                using (var gridPen = new Pen(Color.FromArgb((int)(60 * easePress * _globalAlpha), 0, 0, 0), 1f)) {
                    for (int scanY = rect.Y; scanY < rect.Bottom; scanY += 4) {
                        g.DrawLine(gridPen, rect.X, scanY, rect.Right, scanY);
                    }
                }

                g.Clip = oldClip; // 恢复裁剪区域，以免影响后面的边框和文字绘制
            }

            // 5. 呼吸发光边框
            if (easeHover > 0) {
                float pulse = 0.5f + 0.5f * (float)Math.Sin(_globalPhase * 2f); // 加快呼吸频率
                using (var pen = new Pen(Color.FromArgb((int)(180 * easeHover * pulse * _globalAlpha), Color.White), 1.5f)) {
                    g.DrawPath(pen, path);
                }
            } else {
                using (var pen = new Pen(Color.FromArgb((int)(100 * _globalAlpha), baseColor), 1.2f)) { g.DrawPath(pen, path); }
            }

            // 6. 文字绘制
            using (var f = new Font("Microsoft YaHei UI", 10, FontStyle.Bold))
            using (var b = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), Color.White))) {
                StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
                g.DrawString(text, f, b, rect, sf);
            }
        }

        // 恢复坐标系
        g.Transform = oldTransform;
    }
    
    private GraphicsPath CreateRoundedRect(Rectangle rect, int radius) { 
        GraphicsPath path = new GraphicsPath();
        if (radius <= 0 || rect.Width <= radius * 2 || rect.Height <= radius * 2) { path.AddRectangle(rect); return path; }
        int d = radius * 2;
        path.AddArc(rect.X, rect.Y, d, d, 180, 90); path.AddLine(rect.X + radius, rect.Y, rect.Right - radius, rect.Y);
        path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90); path.AddLine(rect.Right, rect.Y + radius, rect.Right, rect.Bottom - radius);
        path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90); path.AddLine(rect.Right - radius, rect.Bottom, rect.X + radius, rect.Bottom);
        path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90); path.AddLine(rect.X, rect.Bottom - radius, rect.X, rect.Y + radius);
        path.CloseFigure(); return path;
    }
    
    // ====== Emoji 处理方法 ======
    private bool IsEmojiOrModifier(char c) {
        if (c == ' ') return false;
        if (char.IsHighSurrogate(c) || char.IsLowSurrogate(c)) return true;
        if (c == '\u200D' || (c >= '\uFE00' && c <= '\uFE0F') || (c >= '\u20D0' && c <= '\u20FF')) return true;
        if (c == '\u2139' || c == '\u26A0' || c == '\u2757' || c == '\u2699') return true;
        if ((c >= '\u2600' && c <= '\u27BF') || (c >= '\u2300' && c <= '\u23FF') || 
            (c >= '\u25A0' && c <= '\u25FF') || (c >= '\u2190' && c <= '\u21FF') || 
            (c >= '\u2B00' && c <= '\u2BFF') || (c >= '\u203C' && c <= '\u2049')) {
            return true;
        }
        return false;
    }
    
    private void DrawTextWithEmoji(Graphics g, string text, float x, float y, SolidBrush brush, Font baseFont) {
        if (string.IsNullOrEmpty(text)) return;
        float currentX = x;
        int i = 0;
        
        // 根据 baseFont 创建对应大小的 Emoji 字体
        Font emojiFont = FontHelper.GetFont(new[] { "Segoe UI Emoji", "Segoe UI Symbol" }, baseFont.Size, baseFont.Style);
        
        while (i < text.Length) {
            bool isEmoji = IsEmojiOrModifier(text[i]);
            int clusterLength = 1;
            while (i + clusterLength < text.Length) {
                char nextChar = text[i + clusterLength];
                bool nextIsEmoji = IsEmojiOrModifier(nextChar);
                if (nextChar == '\uFE0F' || nextChar == '\u200D') {
                    // 强制归入当前 cluster
                } else if (nextIsEmoji != isEmoji) {
                    break;
                }
                clusterLength++;
            }
            string segment = text.Substring(i, clusterLength);
            Font font = isEmoji ? emojiFont : baseFont;
            g.DrawString(segment, font, brush, new PointF(currentX, y), StringFormat.GenericTypographic);
            SizeF size = g.MeasureString(segment, font, new PointF(0, 0), StringFormat.GenericTypographic);
            currentX += size.Width;
            i += clusterLength;
        }
        
        if (emojiFont != null && emojiFont != baseFont) {
            emojiFont.Dispose();
        }
    }
    
    protected override void Dispose(bool disposing) { 
        if (disposing) {
            if (_animTimer != null) { _animTimer.Stop(); _animTimer.Dispose(); }
            if (_textFont != null) { _textFont.Dispose(); }
            if (_emojiFont != null) { _emojiFont.Dispose(); }
        }
        base.Dispose(disposing); 
    }
}

// ==================================================================================================================
// ====== 新增：AuroraRestoreModal 会话恢复 HUD 叠加层（复用 AuroraDecisionModal 视觉风格） ======
public class AuroraRestoreModal : Control
{
    private string _sessionId = "";
    private string _stage = "";
    private int _progress = 0;
    private string _lastUpdated = "";
    private int _ageInDays = 0;
    private string _language = "CHS";
    
    // 全局透明度状态
    private float _globalAlpha = 0f;
    private enum ModalFadeState { Hidden, FadingIn, Idle, FadingOut }
    private ModalFadeState _fadeState = ModalFadeState.Hidden;
    
    public Rectangle RestoreButtonRect { get; private set; }
    public Rectangle RestartButtonRect { get; private set; }
    
    // 虚拟按钮动效状态
    private bool _isRestoreHovered = false;
    private bool _isRestartHovered = false;
    private bool _isRestorePressed = false;
    private bool _isRestartPressed = false;
    
    private float _restoreHoverProg = 0f;
    private float _restartHoverProg = 0f;
    private float _restorePressProg = 0f;
    private float _restartPressProg = 0f;

    private Timer _animTimer;
    private float _globalPhase = 0f;

    private Font _textFont;
    private Font _emojiFont;
    private Font _titleFont;

    public event EventHandler OnRestore;
    public event EventHandler OnRestart;

    public AuroraRestoreModal()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        SetStyle(ControlStyles.SupportsTransparentBackColor, true);
        this.BackColor = Color.Transparent; 
        this.Dock = DockStyle.Fill;
        this.Visible = false;
        this.TabStop = true;

        _animTimer = new Timer { Interval = 16 };
        _animTimer.Tick += (s, e) => {
            _globalPhase += 0.05f;
            if (_globalPhase > Math.PI * 2) _globalPhase -= (float)(Math.PI * 2);

            // 全局透明度过渡逻辑
            float fadeSpeed = 0.08f;
            if (_fadeState == ModalFadeState.FadingIn) {
                _globalAlpha = Math.Min(1.0f, _globalAlpha + fadeSpeed);
                if (_globalAlpha >= 1.0f) {
                    _fadeState = ModalFadeState.Idle;
                }
            } else if (_fadeState == ModalFadeState.FadingOut) {
                _globalAlpha = Math.Max(0f, _globalAlpha - fadeSpeed);
                if (_globalAlpha <= 0f) {
                    _fadeState = ModalFadeState.Hidden;
                    this.Visible = false;
                }
            }

            // 虚拟按钮独立缓动逻辑
            float btnSpeed = 0.12f;
            _restoreHoverProg = Math.Max(0f, Math.Min(1f, _restoreHoverProg + (_isRestoreHovered ? btnSpeed : -btnSpeed)));
            _restartHoverProg = Math.Max(0f, Math.Min(1f, _restartHoverProg + (_isRestartHovered ? btnSpeed : -btnSpeed)));
            _restorePressProg = Math.Max(0f, Math.Min(1f, _restorePressProg + (_isRestorePressed ? btnSpeed : -btnSpeed)));
            _restartPressProg = Math.Max(0f, Math.Min(1f, _restartPressProg + (_isRestartPressed ? btnSpeed : -btnSpeed)));

            Invalidate();
        };
        _animTimer.Start();

        this.MouseMove += (s, e) => {
            bool newRestore = RestoreButtonRect.Contains(e.Location);
            bool newRestart = RestartButtonRect.Contains(e.Location);
            if (newRestore != _isRestoreHovered || newRestart != _isRestartHovered) {
                _isRestoreHovered = newRestore; _isRestartHovered = newRestart;
            }
        };

        this.MouseDown += (s, e) => {
            if (e.Button == MouseButtons.Left) {
                if (RestoreButtonRect.Contains(e.Location)) _isRestorePressed = true;
                if (RestartButtonRect.Contains(e.Location)) _isRestartPressed = true;
            }
        };

        this.MouseUp += (s, e) => {
            if (e.Button == MouseButtons.Left) {
                if (_isRestorePressed && RestoreButtonRect.Contains(e.Location) && OnRestore != null) OnRestore(this, EventArgs.Empty);
                if (_isRestartPressed && RestartButtonRect.Contains(e.Location) && OnRestart != null) OnRestart(this, EventArgs.Empty);
                _isRestorePressed = false;
                _isRestartPressed = false;
            }
        };

        this.MouseLeave += (s, e) => { 
            _isRestoreHovered = false; _isRestartHovered = false; 
            _isRestorePressed = false; _isRestartPressed = false;
        };
        
        this.KeyDown += (s, e) => {
            switch (e.KeyCode) {
                case Keys.Enter:
                    if (_isRestoreHovered && OnRestore != null) OnRestore(this, EventArgs.Empty);
                    else if (_isRestartHovered && OnRestart != null) OnRestart(this, EventArgs.Empty);
                    e.Handled = true;
                    break;
                case Keys.Tab:
                    if (e.Shift) {
                        if (_isRestoreHovered) { _isRestoreHovered = false; _isRestartHovered = true; } 
                        else { _isRestartHovered = false; _isRestoreHovered = true; }
                    } else {
                        if (_isRestoreHovered) { _isRestoreHovered = false; _isRestartHovered = true; } 
                        else { _isRestartHovered = false; _isRestoreHovered = true; }
                    }
                    Invalidate();
                    e.Handled = true;
                    break;
            }
        };
        
        _emojiFont = FontHelper.GetEmojiFont(11.0f);
        _textFont = FontHelper.GetSansSerifFont(10.0f);
        _titleFont = FontHelper.GetSansSerifFont(13.0f, FontStyle.Bold);
    }

    public void FadeInModal()
    {
        this.Visible = true;
        _fadeState = ModalFadeState.FadingIn;
        _globalAlpha = 0f;
        _isRestoreHovered = true;
        this.Focus();
    }

    public void FadeOutModal()
    {
        _fadeState = ModalFadeState.FadingOut;
    }

    public void UpdateInfo(string sessionId, string stage, int progress, string lastUpdated, int ageInDays, string lang) {
        _language = lang;
        _sessionId = sessionId;
        _stage = stage;
        _progress = progress;
        _lastUpdated = lastUpdated;
        _ageInDays = ageInDays;
    }
    
    private float EaseInCubic(float t) { return t * t * t; }
    private float EaseOutCubic(float t) { return 1f - (float)Math.Pow(1f - t, 3); }

    private Color ColorLerp(Color c1, Color c2, float amount) {
        amount = Math.Max(0, Math.Min(1, amount));
        return Color.FromArgb(
            (int)(c1.A + (c2.A - c1.A) * amount), (int)(c1.R + (c2.R - c1.R) * amount),
            (int)(c1.G + (c2.G - c1.G) * amount), (int)(c1.B + (c2.B - c1.B) * amount)
        );
    }
    
    private string GetTitleText() {
        return _language == "CHS" ? "🔄 会话恢复 - Session Recovery" : "🔄 Session Recovery";
    }
    
    private string GetSessionInfoTitle() {
        return _language == "CHS" ? "📊 会话信息" : "📊 Session Information";
    }
    
    private string GetSessionIdLabel() {
        return _language == "CHS" ? "会话 ID:" : "Session ID:";
    }
    
    private string GetProgressLabel() {
        return _language == "CHS" ? "进度:" : "Progress:";
    }
    
    private string GetStageLabel() {
        return _language == "CHS" ? "当前阶段:" : "Current Stage:";
    }
    
    private string GetSavedAtLabel() {
        return _language == "CHS" ? "保存时间:" : "Saved At:";
    }
    
    private string GetAgeLabel() {
        return _language == "CHS" ? "已挂起:" : "Suspended:";
    }
    
    private string GetDaysText() {
        return _language == "CHS" ? "天" : "days";
    }
    
    private string GetRestoreButtonText() {
        return _language == "CHS" ? "恢复进度继续执行" : "Resume Session";
    }
    
    private string GetRestartButtonText() {
        return _language == "CHS" ? "重新开始新会话" : "Start New Session";
    }
    
    private bool IsEmojiOrModifier(char c) {
        uint code = (uint)c;
        if (code >= 0x1F300 && code <= 0x1F9FF) return true;
        if (code >= 0x2600 && code <= 0x26FF) return true;
        if (code >= 0x2700 && code <= 0x27BF) return true;
        if (code >= 0x1F100 && code <= 0x1F1FF) return true;
        if (code >= 0xFE00 && code <= 0xFE0F) return true;
        if (code >= 0x200D && code <= 0x200D) return true;
        if (code >= 0x1F680 && code <= 0x1F6FF) return true;
        if (code >= 0x1F900 && code <= 0x1F9FF) return true;
        if (code >= 0x231A && code <= 0x231B) return true;
        if (code >= 0x23E9 && code <= 0x23F3) return true;
        if (code >= 0x23F8 && code <= 0x23FA) return true;
        if (code >= 0x25AA && code <= 0x25AB) return true;
        if (code >= 0x25B6 && code <= 0x25B6) return true;
        if (code >= 0x25C0 && code <= 0x25C0) return true;
        if (code >= 0x25FB && code <= 0x25FE) return true;
        if (code >= 0x2614 && code <= 0x2615) return true;
        if (code >= 0x2648 && code <= 0x2653) return true;
        if (code >= 0x267F && code <= 0x267F) return true;
        if (code >= 0x2693 && code <= 0x2693) return true;
        if (code >= 0x26A1 && code <= 0x26A1) return true;
        if (code >= 0x26AA && code <= 0x26AB) return true;
        if (code >= 0x26BD && code <= 0x26BE) return true;
        if (code >= 0x26C4 && code <= 0x26C5) return true;
        if (code >= 0x26CE && code <= 0x26CE) return true;
        if (code >= 0x26D4 && code <= 0x26D4) return true;
        if (code >= 0x26EA && code <= 0x26EA) return true;
        if (code >= 0x26F2 && code <= 0x26F3) return true;
        if (code >= 0x26F5 && code <= 0x26F5) return true;
        if (code >= 0x26FA && code <= 0x26FA) return true;
        if (code >= 0x26FD && code <= 0x26FD) return true;
        if (code >= 0x2702 && code <= 0x2702) return true;
        if (code >= 0x2705 && code <= 0x2705) return true;
        if (code >= 0x2708 && code <= 0x270D) return true;
        if (code >= 0x270F && code <= 0x270F) return true;
        if (code >= 0x2712 && code <= 0x2712) return true;
        if (code >= 0x2714 && code <= 0x2714) return true;
        if (code >= 0x2716 && code <= 0x2716) return true;
        if (code >= 0x271D && code <= 0x271D) return true;
        if (code >= 0x2721 && code <= 0x2721) return true;
        if (code >= 0x2728 && code <= 0x2728) return true;
        if (code >= 0x2733 && code <= 0x2734) return true;
        if (code >= 0x2744 && code <= 0x2744) return true;
        if (code >= 0x2747 && code <= 0x2747) return true;
        if (code >= 0x274C && code <= 0x274C) return true;
        if (code >= 0x274E && code <= 0x274E) return true;
        if (code >= 0x2753 && code <= 0x2755) return true;
        if (code >= 0x2757 && code <= 0x2757) return true;
        if (code >= 0x2763 && code <= 0x2764) return true;
        if (code >= 0x2795 && code <= 0x2797) return true;
        if (code >= 0x27A1 && code <= 0x27A1) return true;
        if (code >= 0x27B0 && code <= 0x27B0) return true;
        if (code >= 0x27BF && code <= 0x27BF) return true;
        if (code >= 0x2934 && code <= 0x2935) return true;
        if (code >= 0x2B05 && code <= 0x2B07) return true;
        if (code >= 0x2B1B && code <= 0x2B1C) return true;
        if (code >= 0x2B50 && code <= 0x2B50) return true;
        if (code >= 0x2B55 && code <= 0x2B55) return true;
        if (code >= 0x3030 && code <= 0x3030) return true;
        if (code >= 0x303D && code <= 0x303D) return true;
        if (code >= 0x3297 && code <= 0x3297) return true;
        if (code >= 0x3299 && code <= 0x3299) return true;
        return false;
    }
    
    private void DrawTextWithEmoji(Graphics g, string text, float x, float y, SolidBrush brush, Font baseFont) {
        if (string.IsNullOrEmpty(text)) return;
        
        // 直接使用 Segoe UI Emoji 字体绘制整段文本
        Font emojiFont = null;
        try {
            emojiFont = new Font("Segoe UI Emoji", baseFont.Size, baseFont.Style);
        } catch {
            emojiFont = baseFont;
        }
        
        // 简单策略：整段文本使用 emoji 字体绘制
        g.DrawString(text, emojiFont, brush, new PointF(x, y), StringFormat.GenericTypographic);
        
        if (emojiFont != null && emojiFont != baseFont) {
            emojiFont.Dispose();
        }
    }
    
    private void DrawStringWithEmoji(Graphics g, string text, Font font, SolidBrush brush, PointF point, Font emojiFont) {
        DrawTextWithEmoji(g, text, point.X, point.Y, brush, font);
    }
    
    private void DrawStringWithEmoji(Graphics g, string text, Font font, SolidBrush brush, RectangleF rect, Font emojiFont, StringFormat sf) {
        DrawTextWithEmoji(g, text, rect.X, rect.Y + (rect.Height - font.GetHeight(g)) / 2, brush, font);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;

        // 全屏暗化遮罩
        using (var dimBrush = new SolidBrush(Color.FromArgb((int)(180 * _globalAlpha), 5, 8, 15))) { g.FillRectangle(dimBrush, ClientRectangle); }

        int pW = 600;
        float unfoldEased = 1f - (float)Math.Pow(1f - _globalAlpha, 3);
        int currentHeight = Math.Max(4, (int)(380 * unfoldEased));
        int pX = (this.Width - pW) / 2;
        int pY = (this.Height - currentHeight) / 2;
        Rectangle pRect = new Rectangle(pX, pY, pW, currentHeight);

        // 中央面板
        using (var path = CreateRoundedRect(pRect, 16)) {
            using (var bgBrush = new SolidBrush(Color.FromArgb((int)(240 * _globalAlpha), 15, 20, 35))) { g.FillPath(bgBrush, path); }
            float pulse = 1.0f + 0.5f * (float)Math.Sin(_globalPhase);
            int alpha = (int)((100 + 50 * pulse) * _globalAlpha);
            using (var topHighlight = new LinearGradientBrush(pRect, Color.FromArgb(alpha, 0, 255, 255), Color.Transparent, LinearGradientMode.Vertical))
            using (var highlightPen = new Pen(topHighlight, 2f)) { g.DrawPath(highlightPen, path); }
        }

        // 标题
        string titleText = GetTitleText();
        using (var titleBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), 0, 255, 255))) {
            StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            DrawStringWithEmoji(g, titleText, _titleFont, titleBrush, new RectangleF(pX, pY + 20, pW, 30), _emojiFont, sf);
        }
        
        using (var linePen = new Pen(Color.FromArgb((int)(80 * _globalAlpha), 255, 255, 255), 1)) { 
            g.DrawLine(linePen, pX + 30, pY + 60, pX + pW - 30, pY + 60); 
        }

        // 会话信息标题
        string infoTitle = GetSessionInfoTitle();
        using (var infoTitleBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), 0, 255, 255))) {
            DrawStringWithEmoji(g, infoTitle, _titleFont, infoTitleBrush, new PointF(pX + 30, pY + 75), _emojiFont);
        }

        // 会话信息内容
        int textY = pY + 110;
        int lineHeight = 30;
        using (var contentBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), 200, 200, 255))) {
            string sessionIdLabel = GetSessionIdLabel();
            float labelWidth = g.MeasureString(sessionIdLabel, _textFont, new PointF(0,0), StringFormat.GenericTypographic).Width;
            DrawStringWithEmoji(g, sessionIdLabel, _textFont, contentBrush, new PointF(pX + 30, textY), _emojiFont);
            using (var valueBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), Color.White))) {
                g.DrawString(_sessionId, _textFont, valueBrush, new PointF(pX + 30 + labelWidth + 10, textY));
            }
        }
        
        textY += lineHeight;
        using (var contentBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), 200, 200, 255))) {
            string progressLabel = GetProgressLabel();
            float labelWidth = g.MeasureString(progressLabel, _textFont, new PointF(0,0), StringFormat.GenericTypographic).Width;
            DrawStringWithEmoji(g, progressLabel, _textFont, contentBrush, new PointF(pX + 30, textY), _emojiFont);
            using (var valueBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), 0, 255, 255))) {
                g.DrawString(_progress.ToString() + "%", _textFont, valueBrush, new PointF(pX + 30 + labelWidth + 10, textY));
            }
        }
        
        textY += lineHeight;
        using (var contentBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), 200, 200, 255))) {
            string stageLabel = GetStageLabel();
            float labelWidth = g.MeasureString(stageLabel, _textFont, new PointF(0,0), StringFormat.GenericTypographic).Width;
            DrawStringWithEmoji(g, stageLabel, _textFont, contentBrush, new PointF(pX + 30, textY), _emojiFont);
            using (var valueBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), Color.White))) {
                g.DrawString(_stage, _textFont, valueBrush, new PointF(pX + 30 + labelWidth + 10, textY));
            }
        }
        
        textY += lineHeight;
        using (var contentBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), 200, 200, 255))) {
            string savedAtLabel = GetSavedAtLabel();
            float labelWidth = g.MeasureString(savedAtLabel, _textFont, new PointF(0,0), StringFormat.GenericTypographic).Width;
            DrawStringWithEmoji(g, savedAtLabel, _textFont, contentBrush, new PointF(pX + 30, textY), _emojiFont);
            using (var valueBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), Color.White))) {
                g.DrawString(_lastUpdated, _textFont, valueBrush, new PointF(pX + 30 + labelWidth + 10, textY));
            }
        }
        
        textY += lineHeight;
        using (var contentBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), 200, 200, 255))) {
            string ageLabel = GetAgeLabel();
            float labelWidth = g.MeasureString(ageLabel, _textFont, new PointF(0,0), StringFormat.GenericTypographic).Width;
            DrawStringWithEmoji(g, ageLabel, _textFont, contentBrush, new PointF(pX + 30, textY), _emojiFont);
            using (var valueBrush = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), Color.White))) {
                g.DrawString(_ageInDays.ToString() + " " + GetDaysText(), _textFont, valueBrush, new PointF(pX + 30 + labelWidth + 10, textY));
            }
        }

        // 按钮区域
        int btnW = 220; int btnH = 48;
        int btnY = pY + currentHeight - 70;
        RestoreButtonRect = new Rectangle(pX + 60, btnY, btnW, btnH);
        RestartButtonRect = new Rectangle(pX + pW - btnW - 60, btnY, btnW, btnH);

        DrawAdvancedVirtualButton(g, RestoreButtonRect, GetRestoreButtonText(), Color.FromArgb(20, 180, 100), _restoreHoverProg, _restorePressProg);
        DrawAdvancedVirtualButton(g, RestartButtonRect, GetRestartButtonText(), Color.FromArgb(180, 100, 100, 100), _restartHoverProg, _restartPressProg);
    }

    private void DrawAdvancedVirtualButton(Graphics g, Rectangle rect, string text, Color baseColor, float hoverProg, float pressProg)
    {
        float easeHover = EaseOutCubic(hoverProg);
        float easePress = EaseOutCubic(pressProg);

        float scale = 1.0f + (easeHover * 0.04f) - (easePress * 0.05f);
        var oldTransform = g.Transform;
        float cx = rect.X + rect.Width / 2f;
        float cy = rect.Y + rect.Height / 2f;
        
        g.TranslateTransform(cx, cy);
        g.ScaleTransform(scale, scale);
        g.TranslateTransform(-cx, -cy);

        int shadowOffset = 2 + (int)(easePress * 3);
        Rectangle shadowRect = new Rectangle(rect.X - 4, rect.Y + shadowOffset + 4, rect.Width + 8, rect.Height + 6);
        using (var shadowPath = CreateRoundedRect(shadowRect, 12))
        using (var pgb = new PathGradientBrush(shadowPath)) {
            pgb.CenterColor = Color.FromArgb((int)((40 + easeHover * 20) * _globalAlpha), 0, 0, 0);
            pgb.SurroundColors = new[] { Color.Transparent };
            g.FillPath(pgb, shadowPath);
        }

        if (easeHover > 0) {
            Rectangle glowRect = new Rectangle(rect.X - 6, rect.Y - 6, rect.Width + 12, rect.Height + 12);
            using (var glowPath = CreateRoundedRect(glowRect, 14))
            using (var pgb = new PathGradientBrush(glowPath)) {
                pgb.CenterColor = Color.FromArgb((int)(80 * easeHover * _globalAlpha), baseColor);
                pgb.SurroundColors = new[] { Color.Transparent };
                g.FillPath(pgb, glowPath);
            }
        }

        using (var path = CreateRoundedRect(rect, 8))
        {
            Color topColor = ColorLerp(Color.FromArgb((int)(80 * _globalAlpha), baseColor), Color.FromArgb((int)(160 * _globalAlpha), baseColor), easeHover);
            Color bottomColor = ColorLerp(Color.FromArgb((int)(30 * _globalAlpha), baseColor), Color.FromArgb((int)(80 * _globalAlpha), baseColor), easeHover);
            if (easePress > 0) {
                topColor = ColorLerp(topColor, Color.FromArgb((int)(60 * _globalAlpha), baseColor), easePress);
                bottomColor = ColorLerp(bottomColor, Color.FromArgb((int)(20 * _globalAlpha), baseColor), easePress);
            }

            using (var brush = new LinearGradientBrush(rect, topColor, bottomColor, LinearGradientMode.Vertical)) {
                g.FillPath(brush, path);
            }

            if (easePress > 0) {
                Region oldClip = g.Clip;
                g.SetClip(path);
                using (var gridPen = new Pen(Color.FromArgb((int)(60 * easePress * _globalAlpha), 0, 0, 0), 1f)) {
                    for (int scanY = rect.Y; scanY < rect.Bottom; scanY += 4) {
                        g.DrawLine(gridPen, rect.X, scanY, rect.Right, scanY);
                    }
                }
                g.Clip = oldClip;
            }

            if (easeHover > 0) {
                float pulse = 0.5f + 0.5f * (float)Math.Sin(_globalPhase * 2f);
                using (var pen = new Pen(Color.FromArgb((int)(180 * easeHover * pulse * _globalAlpha), Color.White), 1.5f)) {
                    g.DrawPath(pen, path);
                }
            } else {
                using (var pen = new Pen(Color.FromArgb((int)(100 * _globalAlpha), baseColor), 1.2f)) { g.DrawPath(pen, path); }
            }

            using (var f = new Font("Microsoft YaHei UI", 10, FontStyle.Bold))
            using (var b = new SolidBrush(Color.FromArgb((int)(255 * _globalAlpha), Color.White))) {
                StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
                g.DrawString(text, f, b, rect, sf);
            }
        }

        g.Transform = oldTransform;
    }
    
    private GraphicsPath CreateRoundedRect(Rectangle rect, int radius) { 
        GraphicsPath path = new GraphicsPath();
        if (radius <= 0 || rect.Width <= radius * 2 || rect.Height <= radius * 2) { path.AddRectangle(rect); return path; }
        int d = radius * 2;
        path.AddArc(rect.X, rect.Y, d, d, 180, 90); path.AddLine(rect.X + radius, rect.Y, rect.Right - radius, rect.Y);
        path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90); path.AddLine(rect.Right, rect.Y + radius, rect.Right, rect.Bottom - radius);
        path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90); path.AddLine(rect.Right - radius, rect.Bottom, rect.X + radius, rect.Bottom);
        path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90); path.AddLine(rect.X, rect.Bottom - radius, rect.X, rect.Y + radius);
        path.CloseFigure(); return path;
    }
    
    protected override void Dispose(bool disposing) { 
        if (disposing) {
            if (_animTimer != null) { _animTimer.Stop(); _animTimer.Dispose(); }
            if (_textFont != null) { _textFont.Dispose(); }
            if (_emojiFont != null) { _emojiFont.Dispose(); }
            if (_titleFont != null) { _titleFont.Dispose(); }
        }
        base.Dispose(disposing); 
    }
}

// ==================================================================================================================
// ====== 新增：AuroraConsoleBox 半透明回显文本框 ======
public class AuroraConsoleBox : Control
{
    private string _text = "";
    private List<string> _wrappedLines = new List<string>();
    private int _scrollOffset = 0;
    private int _maxScrollOffset = 0;
    private Font _textFont;
    private Font _emojiFont;
    private Font _fallbackFont;
    private Color _bgColor = Color.FromArgb(140, 12, 16, 32); 
    private Bitmap _bgCache; 
    private Color _textColor = Color.FromArgb(220, 235, 255); 
    private Color _borderColor = Color.FromArgb(80, 100, 180, 255);
    private Color _scrollBarColor = Color.FromArgb(100, 150, 200, 255);
    private Color _scrollBarBgColor = Color.FromArgb(50, 20, 30, 50);
    private int _cornerRadius = 12;
    private int _scrollBarWidth = 10;
    private int _scrollBarThumbHeight = 40;
    private bool _isDraggingScrollBar = false;
    private int _dragStartY = 0;
    private int _dragStartOffset = 0;
    
    // 文字选择相关
    private int _selectionStart = 0;
    private int _selectionLength = 0;
    private int _dragStartCharIndex = 0;
    private bool _isSelecting = false;
    private ContextMenuStrip _contextMenu;

    // === 🚀 核心修复：定义全局统一的精确测量格式，强制测量空格 ===
    private StringFormat GetAccurateStringFormat() {
        StringFormat sf = new StringFormat(StringFormat.GenericTypographic);
        sf.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces;
        return sf;
    }

    public AuroraConsoleBox()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | 
                 ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw, true);
        SetStyle(ControlStyles.SupportsTransparentBackColor, true);
        this.BackColor = Color.Transparent;
        
        _textFont = FontHelper.GetMonospaceFont(10.0f);
        _emojiFont = FontHelper.GetEmojiFont(10.0f);
        _fallbackFont = FontHelper.GetMonospaceFont(10.0f);
        
        SetStyle(ControlStyles.Selectable, true);
        this.MouseWheel += AuroraConsoleBox_MouseWheel;
        this.MouseDown += AuroraConsoleBox_MouseDown;
        this.MouseMove += AuroraConsoleBox_MouseMove;
        this.MouseUp += AuroraConsoleBox_MouseUp;
        this.MouseClick += AuroraConsoleBox_MouseClick;
        
        _contextMenu = new ContextMenuStrip();
        ToolStripMenuItem copyItem = new ToolStripMenuItem("复制所有终端日志");
        copyItem.Click += (s, e) => { if (!string.IsNullOrEmpty(_text)) { System.Windows.Forms.Clipboard.SetText(_text); } };
        _contextMenu.Items.Add(copyItem);
        this.ContextMenuStrip = _contextMenu;
    }
    
    private void AuroraConsoleBox_MouseWheel(object sender, MouseEventArgs e)
    {
        int lineHeight = (int)_textFont.GetHeight();
        int scrollAmount = e.Delta > 0 ? -3 : 3;
        _scrollOffset = Math.Max(0, Math.Min(_maxScrollOffset, _scrollOffset + scrollAmount));
        Invalidate();
    }
    
    private void AuroraConsoleBox_MouseDown(object sender, MouseEventArgs e)
    {
        Rectangle scrollBarRect = GetScrollBarRectangle();
        if (scrollBarRect.Contains(e.Location))
        {
            _isDraggingScrollBar = true;
            _dragStartY = e.Y;
            _dragStartOffset = _scrollOffset;
            this.Capture = true;
        }
        else if (e.Button == MouseButtons.Left)
        {
            // 获取焦点，使输入框自动失焦
            this.Focus();
            
            // 开始文字选择
            _isSelecting = true;
            _dragStartCharIndex = GetCharIndexFromMousePosition(e.Location);
            _selectionStart = _dragStartCharIndex;
            _selectionLength = 0;
            this.Capture = true;
            Invalidate();
        }
    }
    
    private void AuroraConsoleBox_MouseMove(object sender, MouseEventArgs e)
    {
        if (_isDraggingScrollBar && _maxScrollOffset > 0)
        {
            int lineHeight = (int)_textFont.GetHeight();
            int trackHeight = this.ClientRectangle.Height - _scrollBarThumbHeight;
            int deltaY = e.Y - _dragStartY;
            int deltaOffset = (int)((float)deltaY / trackHeight * _maxScrollOffset);
            _scrollOffset = Math.Max(0, Math.Min(_maxScrollOffset, _dragStartOffset + deltaOffset));
            Invalidate();
        }
        else if (_isSelecting)
        {
            // 更新选择区域
            int currentCharIndex = GetCharIndexFromMousePosition(e.Location);
            if (currentCharIndex >= _dragStartCharIndex)
            {
                _selectionStart = _dragStartCharIndex;
                _selectionLength = currentCharIndex - _dragStartCharIndex;
            }
            else
            {
                _selectionStart = currentCharIndex;
                _selectionLength = _dragStartCharIndex - currentCharIndex;
            }
            Invalidate();
        }
    }
    
    private void AuroraConsoleBox_MouseUp(object sender, MouseEventArgs e)
    {
        _isDraggingScrollBar = false;
        _isSelecting = false;
        this.Capture = false;
    }
    
    private void AuroraConsoleBox_MouseClick(object sender, MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left)
        {
            // 点击时取消选择
            _selectionLength = 0;
            Invalidate();
        }
    }
    
    private int GetCharIndexFromMousePosition(Point mousePos)
    {
        if (string.IsNullOrEmpty(_text) || _wrappedLines.Count == 0)
            return 0;
        
        using (var g = this.CreateGraphics())
        {
            float lineHeight = _textFont.GetHeight(g);
            int textWidth = this.ClientRectangle.Width - _scrollBarWidth - 20;
            
            // 计算点击的行
            int clickedLine = _scrollOffset + (int)(mousePos.Y / lineHeight);
            if (clickedLine < 0) clickedLine = 0;
            if (clickedLine >= _wrappedLines.Count) clickedLine = _wrappedLines.Count - 1;
            
            // 计算点击的字符
            string line = _wrappedLines[clickedLine];
            if (string.IsNullOrEmpty(line))
                return 0;
            
            // 找到行中的字符位置
            int charIndex = 0;
            for (int i = 1; i <= line.Length; i++)
            {
                SizeF size = g.MeasureString(line.Substring(0, i), _textFont);
                if (size.Width > mousePos.X - 10)
                {
                    charIndex = i - 1;
                    break;
                }
                charIndex = i;
            }
            
            // 转换为原始文本中的索引
            int totalIndex = 0;
            for (int i = 0; i < clickedLine; i++)
            {
                totalIndex += _wrappedLines[i].Length + 1; // +1 for newline
            }
            totalIndex += charIndex;
            
            return Math.Min(totalIndex, _text.Length);
        }
    }
    
    private Rectangle GetScrollBarRectangle()
    {
        return new Rectangle(
            this.ClientRectangle.Width - _scrollBarWidth - 2,
            2,
            _scrollBarWidth,
            this.ClientRectangle.Height - 4
        );
    }

    public override string Text
    {
        get { return _text; }
        set 
        { 
            _text = value;
            WrapText();
            UpdateScrollOffset();
            Invalidate();
        }
    }

    public void AppendText(string text)
    {
        _text += text;
        WrapText();
        UpdateScrollOffset();
        Invalidate();
    }

    public void ScrollToCaret()
    {
        _scrollOffset = _maxScrollOffset;
        Invalidate();
    }
    
    // 兼容原有代码的属性
    public int SelectionStart 
    { 
        get { return _text.Length; } 
        set { } 
    }
    
    private void WrapText() {
        _wrappedLines.Clear();
        if (string.IsNullOrEmpty(_text)) return;
        
        using (var g = this.CreateGraphics()) using (var sf = GetAccurateStringFormat()) {
            int maxWidth = this.ClientRectangle.Width - _scrollBarWidth - 20;
            if (maxWidth <= 0) return;
            
            // === 🚀 核心修复：彻底消灭潜伏的 \r 幽灵，保证每行干干净净 ===
            // 强制干掉会让 GDI+ 崩溃的不可见变体选择器 \uFE0F
            string cleanText = _text.Replace("\r\n", "\n").Replace("\r", "").Replace("\uFE0F", "");
            string[] originalLines = cleanText.Split(new[] { '\n' });
            
            foreach (string line in originalLines) {
                if (string.IsNullOrEmpty(line)) { _wrappedLines.Add(""); continue; }
                string remaining = line;
                while (!string.IsNullOrEmpty(remaining)) {
                    int charsFit = 0;
                    for (int i = 1; i <= remaining.Length; i++) {
                        if (i < remaining.Length && char.IsHighSurrogate(remaining[i - 1])) { i++; }
                        string subStr = remaining.Substring(0, i);
                        SizeF size = g.MeasureString(subStr, _textFont, new PointF(0,0), sf);
                        if (size.Width > maxWidth) { charsFit = (i > 1 && char.IsLowSurrogate(remaining[i - 1])) ? i - 2 : i - 1; break; }
                        charsFit = i;
                    }
                    if (charsFit <= 0) charsFit = 1; 
                    if (charsFit >= remaining.Length) { _wrappedLines.Add(remaining); break; }
                    
                    int spaceIndex = remaining.LastIndexOf(' ', Math.Min(charsFit, remaining.Length - 1));
                    if (spaceIndex > 0 && (charsFit - spaceIndex) <= 15) {
                        _wrappedLines.Add(remaining.Substring(0, spaceIndex));
                        remaining = remaining.Substring(spaceIndex + 1);
                    } else {
                        _wrappedLines.Add(remaining.Substring(0, charsFit));
                        remaining = remaining.Substring(charsFit);
                    }
                }
            }
        }
    }
    
    private void UpdateScrollOffset() {
        if (this.Height <= 0) return;
        float lineHeight = _textFont.GetHeight();
        // 扣除 35 像素，强制缩小可见行数的判定，让滚动条能滚得更深！
        int visibleLines = Math.Max(1, (int)((this.Height - 35) / lineHeight));
        _maxScrollOffset = Math.Max(0, _wrappedLines.Count - visibleLines);
        _scrollOffset = Math.Min(_scrollOffset, _maxScrollOffset);
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        WrapText();
        UpdateScrollOffset();
        UpdateBackgroundCache();
        Invalidate();
    }
    
    private void UpdateBackgroundCache()
    {
        if (this.ClientRectangle.Width <= 0 || this.ClientRectangle.Height <= 0)
            return;
            
        // 释放旧缓存
        if (_bgCache != null)
        {
            _bgCache.Dispose();
            _bgCache = null;
        }
        
        // 创建新缓存
        _bgCache = new Bitmap(this.ClientRectangle.Width, this.ClientRectangle.Height);
        using (var g = Graphics.FromImage(_bgCache))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            
            Rectangle rect = this.ClientRectangle;
            
            // 绘制半透明背景（圆角矩形）
            using (var bgPath = CreateRoundedRect(rect, _cornerRadius))
            {
                using (var bgBrush = new SolidBrush(_bgColor))
                {
                    g.FillPath(bgBrush, bgPath);
                }
                
                // 绘制发光边框
                using (var borderPen = new Pen(_borderColor, 1.5f))
                {
                    g.DrawPath(borderPen, bgPath);
                }
            }
        }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        
        Rectangle rect = this.ClientRectangle;
        if (rect.Width <= 0 || rect.Height <= 0) return;
        
        // 调整绘制区域，给滚动条留空间
        int textWidth = rect.Width - (_maxScrollOffset > 0 ? _scrollBarWidth + 4 : 0);
        Rectangle drawRect = new Rectangle(rect.X, rect.Y, textWidth, rect.Height);
        
        // 1. 使用缓存的背景（如果存在）
        if (_bgCache != null)
        {
            g.DrawImage(_bgCache, 0, 0);
        }
        else
        {
            // 后备方案：直接绘制背景
            using (var bgPath = CreateRoundedRect(rect, _cornerRadius))
            {
                using (var bgBrush = new SolidBrush(_bgColor))
                {
                    g.FillPath(bgBrush, bgPath);
                }
                using (var borderPen = new Pen(_borderColor, 1.5f))
                {
                    g.DrawPath(borderPen, bgPath);
                }
            }
        }
        
        if (_wrappedLines.Count > 0) {
            float lineHeight = _textFont.GetHeight(g);
            float y = 10f;
            
            // 修复 SelectionCharIndex 的偏移
            int charIndex = 0;
            for(int i = 0; i < _scrollOffset; i++) { charIndex += _wrappedLines[i].Length + 1; }
            
            using (var sf = GetAccurateStringFormat()) {
                for (int i = _scrollOffset; i < _wrappedLines.Count; i++) {
                    // 放宽到整个控件的高度，允许最后一行完整露出来
                    if (y > drawRect.Height + 5) break;
                    
                    string line = _wrappedLines[i];
                    if (!string.IsNullOrEmpty(line)) {
                        int lineStartChar = charIndex;
                        int lineEndChar = charIndex + line.Length;
                        
                        if (_selectionLength > 0) {
                            int selectionEnd = _selectionStart + _selectionLength;
                            int highlightStart = Math.Max(lineStartChar, _selectionStart) - lineStartChar;
                            int highlightEnd = Math.Min(lineEndChar, selectionEnd) - lineStartChar;
                            
                            if (highlightStart < highlightEnd) {
                                string highlightText = line.Substring(highlightStart, highlightEnd - highlightStart);
                                SizeF highlightSize = g.MeasureString(line.Substring(0, highlightStart), _textFont, new PointF(0,0), sf);
                                SizeF selectedSize = g.MeasureString(highlightText, _textFont, new PointF(0,0), sf);
                                using (var highlightBrush = new SolidBrush(Color.FromArgb(100, 100, 150, 255))) {
                                    g.FillRectangle(highlightBrush, 10f + highlightSize.Width, y, selectedSize.Width, lineHeight);
                                }
                            }
                        }
                        using (var textBrush = new SolidBrush(_textColor)) { DrawTextWithEmoji(g, line, 10f, y, textBrush, sf); }
                    }
                    charIndex += line.Length + 1; 
                    y += lineHeight;
                }
            }
        }
        
        // 4. 绘制自绘滚动条
        if (_maxScrollOffset > 0)
        {
            Rectangle scrollBarRect = GetScrollBarRectangle();
            
            // 绘制滚动条背景
            using (var bgBrush = new SolidBrush(_scrollBarBgColor))
            {
                g.FillRectangle(bgBrush, scrollBarRect);
            }
            
            // 计算滚动条滑块位置和高度
            int trackHeight = scrollBarRect.Height - _scrollBarThumbHeight;
            int thumbY = scrollBarRect.Top + (int)((float)_scrollOffset / _maxScrollOffset * trackHeight);
            
            // 绘制滑块
            Rectangle thumbRect = new Rectangle(scrollBarRect.Left, thumbY, scrollBarRect.Width, _scrollBarThumbHeight);
            using (var thumbBrush = new SolidBrush(_scrollBarColor))
            {
                g.FillRectangle(thumbBrush, thumbRect);
            }
            
            // 滑块边框
            using (var thumbPen = new Pen(Color.FromArgb(150, 200, 230, 255), 1))
            {
                g.DrawRectangle(thumbPen, thumbRect);
            }
        }
    }

    private GraphicsPath CreateRoundedRect(Rectangle rect, int radius)
    {
        GraphicsPath path = new GraphicsPath();
        if (radius <= 0 || rect.Width <= radius * 2 || rect.Height <= radius * 2) 
        { 
            path.AddRectangle(rect); 
            return path; 
        }
        int d = radius * 2;
        path.AddArc(rect.X, rect.Y, d, d, 180, 90); 
        path.AddLine(rect.X + radius, rect.Y, rect.Right - radius, rect.Y);
        path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90); 
        path.AddLine(rect.Right, rect.Y + radius, rect.Right, rect.Bottom - radius);
        path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90); 
        path.AddLine(rect.Right - radius, rect.Bottom, rect.X + radius, rect.Bottom);
        path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90); 
        path.AddLine(rect.X, rect.Bottom - radius, rect.X, rect.Y + radius);
        path.CloseFigure(); 
        return path;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            if (_textFont != null) { _textFont.Dispose(); }
            if (_emojiFont != null) { _emojiFont.Dispose(); }
            if (_fallbackFont != null) { _fallbackFont.Dispose(); }
            if (_bgCache != null) { _bgCache.Dispose(); }
            if (_contextMenu != null) { _contextMenu.Dispose(); }
        }
        base.Dispose(disposing);
    }
    
    private bool IsEmojiOrModifier(char c) {
        // 空格绝不是 Emoji
        if (c == ' ') return false;
        
        // 代理对（所有 BMP 之外的复杂 Emoji，如 🚀）
        if (char.IsHighSurrogate(c) || char.IsLowSurrogate(c)) return true;
        
        // 变体选择器 (U+FE0F等) 和 零宽连字号 (ZWJ, U+200D)
        if (c == '\u200D' || (c >= '\uFE00' && c <= '\uFE0F') || (c >= '\u20D0' && c <= '\u20FF')) return true;

        // 常见符号和 Emoji 区块 (涵盖 ⚙ 等)
        if ((c >= '\u2600' && c <= '\u27BF') ||  // 杂项符号与装饰符号
            (c >= '\u2300' && c <= '\u23FF') ||  // 技术符号
            (c >= '\u25A0' && c <= '\u25FF') ||  // 几何图形
            (c >= '\u2190' && c <= '\u21FF') ||  // 箭头
            (c >= '\u2B00' && c <= '\u2BFF') ||  // 杂项符号和箭头
            (c >= '\u203C' && c <= '\u2049')) {  // 标点符号
            return true;
        }
        return false;
    }
    
    private void DrawTextWithEmoji(Graphics g, string text, float x, float y, SolidBrush brush, StringFormat sf) {
        if (string.IsNullOrEmpty(text)) return;
        float currentX = x;
        int i = 0;
        
        while (i < text.Length) {
            bool isEmoji = IsEmojiOrModifier(text[i]);
            int clusterLength = 1;
            
            while (i + clusterLength < text.Length) {
                char nextChar = text[i + clusterLength];
                bool nextIsEmoji = IsEmojiOrModifier(nextChar);
                if (nextChar == '\uFE0F' || nextChar == '\u200D') {
                    // 强制归属
                } else if (nextIsEmoji != isEmoji) { break; }
                clusterLength++;
            }

            string segment = text.Substring(i, clusterLength);
            Font font = isEmoji ? _emojiFont : _textFont;
            
            g.DrawString(segment, font, brush, new PointF(currentX, y), sf);
            SizeF size = g.MeasureString(segment, font, new PointF(0, 0), sf);
            currentX += size.Width;

            i += clusterLength;
        }
    }
}

// ==================================================================================================================
// ====== 新增：AuroraInputBox 半透明输入框 ======
public class AuroraInputBox : Control
{
    private string _text = "";
    private int _caretPosition = 0;
    private Font _textFont;
    private Color _bgColor = Color.FromArgb(160, 15, 20, 35); // 半透明背景
    private Color _textColor = Color.White;
    private Color _borderColor = Color.FromArgb(80, 100, 180, 255);
    private Color _focusColor = Color.FromArgb(109, 249, 75); // 极光绿
    private int _cornerRadius = 8;
    private bool _isFocused = false;
    private Timer _caretTimer;
    private float _caretAlpha = 1f; // 光标透明度，用于渐亮渐灭动效
    private bool _caretFadeIn = true; // 光标淡入淡出方向
    private Timer _underlineAnimTimer;
    private float _underlineProgress = 0f;
    private float _underlineAnimStart = 0f;
    private float _underlineAnimTarget = 0f;
    private float _underlineAnimTime = 0f;
    private const float _underlineAnimDuration = 0.55f; // 动画持续时间（秒），强化丝滑阻尼感
    
    // 缓存渐变画笔，避免频繁创建
    private LinearGradientBrush _underlineBrush = null;
    private bool _brushNeedsUpdate = true;

    // 自定义事件：回车键按下
    public event EventHandler EnterPressed;

    public AuroraInputBox()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | 
                 ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw, true);
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.Selectable, true);
        this.BackColor = Color.Transparent;
        this.TabStop = true;
        
        _textFont = new Font("Consolas", 13f, FontStyle.Regular);
        
        // 鼠标点击获取焦点
        this.MouseDown += (s, e) => {
            if (e.Button == MouseButtons.Left) {
                this.Focus();
            }
        };
        
        // 光标渐亮渐灭定时器（优雅的呼吸效果）
        _caretTimer = new Timer();
        _caretTimer.Interval = 30; // 约 33fps，平滑的渐变效果
        _caretTimer.Tick += (s, e) => {
            if (_caretFadeIn) {
                _caretAlpha += 0.04f;
                if (_caretAlpha >= 1f) {
                    _caretAlpha = 1f;
                    _caretFadeIn = false;
                }
            } else {
                _caretAlpha -= 0.04f;
                if (_caretAlpha <= 0.3f) {
                    _caretAlpha = 0.3f;
                    _caretFadeIn = true;
                }
            }
            // 只重绘光标区域，避免触发父控件重绘
            // 简化：直接重绘整个控件，避免在定时器中创建 GDI+ 对象
            this.Invalidate();
        };
        
        // 优雅的下划线展开动效定时器（使用UWP缓动）
        _underlineAnimTimer = new Timer();
        _underlineAnimTimer.Interval = 16; // 60fps
        
        _underlineAnimTimer.Tick += (s, e) => {
            _underlineAnimTime += 0.016f; // 每帧增加16ms
            
            float t = Math.Min(_underlineAnimTime / _underlineAnimDuration, 1f);
            float easedT = EaseOutCubic(t); // UWP缓动：先快后慢
            
            _underlineProgress = _underlineAnimStart + (_underlineAnimTarget - _underlineAnimStart) * easedT;
            
            if (t >= 1f) {
                _underlineProgress = _underlineAnimTarget;
                _underlineAnimTimer.Stop();
            }
            // 优化：只重绘下划线所在区域，避免触发父控件重绘
            int underlineHeight = 8;
            int underlineY = this.Height - underlineHeight - 6;
            Rectangle underlineRect = new Rectangle(0, underlineY, this.Width, underlineHeight);
            this.Invalidate(underlineRect);
        };
    }
    
    // UWP EaseOutQuart 缓动函数：标准四次方缓动，极速启动，柔和刹车
    private float EaseOutCubic(float t) {
        return 1.0f - (float)Math.Pow(1.0f - t, 4);
    }

    public override string Text
    {
        get { return _text; }
        set 
        { 
            _text = value;
            _caretPosition = Math.Min(_caretPosition, _text.Length);
            Invalidate();
        }
    }

    protected override void OnEnter(EventArgs e)
    {
        _isFocused = true;
        _caretAlpha = 1f;
        _caretTimer.Start();
        // 启动下划线点亮动画（使用缓动）
        _underlineAnimStart = _underlineProgress;
        _underlineAnimTarget = 1f;
        _underlineAnimTime = 0f;
        _underlineAnimTimer.Start();
        Invalidate();
        base.OnEnter(e);
    }

    protected override void OnLeave(EventArgs e)
    {
        _isFocused = false;
        _caretTimer.Stop();
        // 启动下划线熄灭动画（使用缓动）
        _underlineAnimStart = _underlineProgress;
        _underlineAnimTarget = 0f;
        _underlineAnimTime = 0f;
        _underlineAnimTimer.Start();
        Invalidate();
        base.OnLeave(e);
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        this.Focus();
        base.OnMouseDown(e);
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Enter)
        {
            if (EnterPressed != null)
            {
                EnterPressed(this, EventArgs.Empty);
            }
            e.Handled = true;
            return;
        }
        
        if (e.KeyCode == Keys.Back && _caretPosition > 0)
        {
            _text = _text.Remove(_caretPosition - 1, 1);
            _caretPosition--;
            Invalidate();
        }
        else if (e.KeyCode == Keys.Delete && _caretPosition < _text.Length)
        {
            _text = _text.Remove(_caretPosition, 1);
            Invalidate();
        }
        else if (e.KeyCode == Keys.Left && _caretPosition > 0)
        {
            _caretPosition--;
            Invalidate();
        }
        else if (e.KeyCode == Keys.Right && _caretPosition < _text.Length)
        {
            _caretPosition++;
            Invalidate();
        }
        else if (e.KeyCode == Keys.Home)
        {
            _caretPosition = 0;
            Invalidate();
        }
        else if (e.KeyCode == Keys.End)
        {
            _caretPosition = _text.Length;
            Invalidate();
        }
        base.OnKeyDown(e);
    }

    protected override void OnKeyPress(KeyPressEventArgs e)
    {
        if (char.IsControl(e.KeyChar) && e.KeyChar != '\b' && e.KeyChar != (char)127)
        {
            base.OnKeyPress(e);
            return;
        }
        
        if (e.KeyChar == '\b') return; // 已在 OnKeyDown 处理
        
        _text = _text.Insert(_caretPosition, e.KeyChar.ToString());
        _caretPosition++;
        Invalidate();
        base.OnKeyPress(e);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        if (e == null || e.Graphics == null) return;
        
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        
        Rectangle rect = this.ClientRectangle;
        if (rect.Width <= 0 || rect.Height <= 0) return;
        
        // 1. 绘制半透明背景（圆角矩形）
        using (var bgPath = CreateRoundedRect(rect, _cornerRadius))
        {
            using (var bgBrush = new SolidBrush(_bgColor))
            {
                g.FillPath(bgBrush, bgPath);
            }
            
            // 2. 绘制基础边框
            Color borderColor = _borderColor;
            using (var borderPen = new Pen(borderColor, 1f))
            {
                g.DrawPath(borderPen, bgPath);
            }
        }
        
        // 3. 优雅的展开式下划线动效（使用缓存的渐变画笔）
        if (_underlineProgress > 0f)
        {
            float underlineWidth = rect.Width * _underlineProgress;
            float underlineX = rect.X + (rect.Width - underlineWidth) / 2f;
            float underlineY = rect.Bottom - 2f;
            
            // 渐变下划线 - 缓存画笔以减少内存分配
            if (_underlineBrush == null || _brushNeedsUpdate)
            {
                if (_underlineBrush != null)
                {
                    _underlineBrush.Dispose();
                }
                
                _underlineBrush = new LinearGradientBrush(
                    new PointF(rect.X, underlineY), 
                    new PointF(rect.X + rect.Width, underlineY),
                    Color.Transparent,
                    _focusColor);
                
                _brushNeedsUpdate = false;
            }
            
            if (_underlineBrush != null)
            {
                ColorBlend cb = new ColorBlend();
                cb.Positions = new float[] { 0f, 0.1f, 0.9f, 1f };
                cb.Colors = new Color[] { 
                    Color.Transparent, 
                    Color.FromArgb((int)(200 * _underlineProgress), _focusColor),
                    Color.FromArgb((int)(200 * _underlineProgress), _focusColor),
                    Color.Transparent
                };
                _underlineBrush.InterpolationColors = cb;
                
                using (var pen = new Pen(_underlineBrush, 2f))
                {
                    g.DrawLine(pen, underlineX, underlineY, underlineX + underlineWidth, underlineY);
                }
            }
        }
        
        // 4. 绘制文本
        float textY = (rect.Height - _textFont.GetHeight(g)) / 2f;
        if (!string.IsNullOrEmpty(_text))
        {
            using (var textBrush = new SolidBrush(_textColor))
            {
                g.DrawString(_text, _textFont, textBrush, new PointF(12f, textY));
            }
        }
        
        // 5. 绘制光标（渐亮渐灭动效）
        if (_isFocused)
        {
            float caretX = 12f;
            if (_caretPosition > 0 && _caretPosition <= _text.Length)
            {
                string subText = _text.Substring(0, _caretPosition);
                using (var sf = new StringFormat(StringFormat.GenericTypographic))
                {
                    sf.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces;
                    SizeF size = g.MeasureString(subText, _textFont, new PointF(0,0), sf);
                    caretX += size.Width;
                }
            }
            
            // 光标向后偏移一格，避免被输入的字符挡住
            caretX += 4f;
            
            // 渐亮渐灭的光标效果
            int caretAlpha = (int)(255 * _caretAlpha);
            using (var caretPen = new Pen(Color.FromArgb(caretAlpha, _focusColor.R, _focusColor.G, _focusColor.B), 2f))
            {
                g.DrawLine(caretPen, caretX, textY + 2, caretX, textY + _textFont.GetHeight(g) - 4);
            }
        }
    }

    private GraphicsPath CreateRoundedRect(Rectangle rect, int radius)
    {
        GraphicsPath path = new GraphicsPath();
        if (radius <= 0 || rect.Width <= radius * 2 || rect.Height <= radius * 2) 
        { 
            path.AddRectangle(rect); 
            return path; 
        }
        int d = radius * 2;
        path.AddArc(rect.X, rect.Y, d, d, 180, 90); 
        path.AddLine(rect.X + radius, rect.Y, rect.Right - radius, rect.Y);
        path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90); 
        path.AddLine(rect.Right, rect.Y + radius, rect.Right, rect.Bottom - radius);
        path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90); 
        path.AddLine(rect.Right - radius, rect.Bottom, rect.X + radius, rect.Bottom);
        path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90); 
        path.AddLine(rect.X, rect.Bottom - radius, rect.X, rect.Y + radius);
        path.CloseFigure(); 
        return path;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            if (_caretTimer != null) { _caretTimer.Stop(); _caretTimer.Dispose(); }
            if (_underlineAnimTimer != null) { _underlineAnimTimer.Stop(); _underlineAnimTimer.Dispose(); }
            if (_textFont != null) { _textFont.Dispose(); }
            if (_underlineBrush != null) { _underlineBrush.Dispose(); }
        }
        base.Dispose(disposing);
    }
}

// ==================================================================================================================
// ====== 新增：StarfieldPanel 背景控件（动态星河 + 鼠标光晕交互 + 电影感飞入）======
public class StarfieldPanel : Control
{
    private List<Star> _stars;
    private List<Meteor> _meteors;
    private List<DeepSpaceParticle> _particles;
    private List<Point> _constellationPoints;
    private static Random _rand = new Random();
    private Timer _timer;
    private float _gradientOffset = 0f;
    private Point _mousePos = new Point(-1000, -1000);
    
    // Brush 缓存，减少 GC 压力
    private SolidBrush[] _starBrushCache;
    private SolidBrush[] _glowBrushCache;

    // === 【V13.8】UWP风格文本滑入动画字段 (非重叠版) ===
    private string _currentText = "";
    private string _nextText = "";
    private enum TextTransitionState { Idle, FadingOut, Waiting, FadingIn }
    private TextTransitionState _transitionState = TextTransitionState.Idle;
    private float _transitionProgress = 0f;
    private const float GAP_DURATION = 0.1f;

    // 文本样式和位置
    private Font _statusFont;
    private readonly Color _textColor = Color.FromArgb(220, 230, 255);
    public float TextX { get; set; }
    public float TextY { get; set; }
    public StringAlignment TextAlignment { get; set; }

    public StarfieldPanel()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | 
                 ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw | 
                 ControlStyles.OptimizedDoubleBuffer, true);
        SetStyle(ControlStyles.SupportsTransparentBackColor, true);
        this.BackColor = Color.Transparent;
        _stars = new List<Star>();
        _meteors = new List<Meteor>();
        _particles = new List<DeepSpaceParticle>();
        _constellationPoints = new List<Point>();
        // 延迟初始化星星，直到第一次绘制时

        // 初始化属性
        TextX = 50f;
        TextY = 90f;
        TextAlignment = StringAlignment.Near;

        _timer = new Timer();
        _timer.Interval = AuroraRenderEngine.GetTimerInterval(); // 动态FPS
        _timer.Tick += OnTimerTick;
        _timer.Start();

        // 初始字体设置
        _statusFont = FontHelper.GetEmojiFont(10f, FontStyle.Bold);
        _timer.Tick += OnTextAnimationTick;

        this.MouseMove += OnMouseMove;
        this.MouseLeave += OnMouseLeave;
        
        // 初始化 Brush 缓存
        InitializeBrushCache();
    }
    
    private void InitializeBrushCache()
    {
        // 创建星星颜色缓存（青色系）
        _starBrushCache = new SolidBrush[256];
        for (int i = 0; i < 256; i++)
        {
            _starBrushCache[i] = new SolidBrush(Color.FromArgb(i, 220, 255, 255));
        }
        
        // 创建光晕颜色缓存（淡青色系）
        _glowBrushCache = new SolidBrush[256];
        for (int i = 0; i < 256; i++)
        {
            _glowBrushCache[i] = new SolidBrush(Color.FromArgb(i, 170, 220, 255));
        }
    }

    // ===== 新增：暴露给 PowerShell 的外部引擎控制接口 =====
    public void StopAnimation()
    {
        if (_timer != null && _timer.Enabled)
        {
            _timer.Stop();
        }
    }

    public void StartAnimation()
    {
        if (_timer != null && !_timer.Enabled)
        {
            _timer.Start();
        }
    }

    // 新增：设置字体方法
    public void SetFont(System.Drawing.Font font)
    {
        if (font != null)
        {
            _statusFont = font;
            Invalidate();
        }
    }

    private bool _isWindowAnimating = false;
    public bool IsWindowAnimating
    {
        get { return _isWindowAnimating; }
        set { _isWindowAnimating = value; }
    }

    private void OnTextAnimationTick(object sender, EventArgs e)
    {
        const float transitionSpeed = 0.06f;
        switch (_transitionState)
        {
            case TextTransitionState.FadingOut:
                _transitionProgress = Math.Min(1.0f, _transitionProgress + transitionSpeed);
                if (_transitionProgress >= 1.0f)
                {
                    _transitionState = TextTransitionState.Waiting;
                    _transitionProgress = 0f;
                }
                break;
            case TextTransitionState.Waiting:
                _transitionProgress = Math.Min(1.0f, _transitionProgress + transitionSpeed);
                if (_transitionProgress >= GAP_DURATION)
                {
                    _transitionState = TextTransitionState.FadingIn;
                    _transitionProgress = 0f;
                    // 注意：这里不再赋值！
                    // _currentText = _nextText; // <-- 移除此行
                    // _nextText = "";           // <-- 移除此行
                }
                break;
            case TextTransitionState.FadingIn:
                _transitionProgress = Math.Min(1.0f, _transitionProgress + transitionSpeed);
                if (_transitionProgress >= 1.0f)
                {
                    _transitionState = TextTransitionState.Idle;
                    // 在动画完全结束后，再更新数据模型
                    _currentText = _nextText;
                    _nextText = "";
                }
                break;
        }
        Invalidate();
    }

    private void UpdateStatusText(string newText)
    {
        if (_currentText != newText)
        {
            _nextText = newText;
            _transitionState = TextTransitionState.FadingOut;
            _transitionProgress = 0f;
            Invalidate();
        }
    }


    private void OnTimerTick(object sender, EventArgs e)
    {
        try {
            _gradientOffset += 0.002f;
            if (_gradientOffset > 1f) _gradientOffset -= 1f;

            // 流星生成
            if (_rand.NextDouble() < 0.009)
            {
                if (ClientRectangle.Width > 0 && ClientRectangle.Height > 0) {
                    int width = ClientRectangle.Width;
                    int height = ClientRectangle.Height;
                    float startX = (float)_rand.NextDouble() * width;
                    float startY = -20f - (float)_rand.NextDouble() * 50f;
                    float speed = 4f + (float)_rand.NextDouble() * 8f;
                    float angle = (float)(_rand.NextDouble() * Math.PI / 3);
                    float vx = (float)(speed * Math.Sin(angle));
                    float vy = (float)(speed * Math.Cos(angle));
                    _meteors.Add(new Meteor(startX, startY, vx, vy, 50));
                }
            }

            // === 电影感飞入：弧线轨迹 + 视差 + 超新星爆发效果 ===
            foreach (Star star in _stars)
            {
                try {
                    // 处理入场延迟
                    if (star.entranceDelay > 0)
                    {
                        star.entranceDelay--;
                        continue; // 跳过当前帧
                    }
                    
                    // 处理透明度渐变
                    if (star.entranceAlpha < 1f)
                    {
                        star.entranceAlpha = Math.Min(1f, star.entranceAlpha + 0.02f);
                    }
                    
                    if (!star.HasSettled)
                    {
                        star.EaseProgress = Math.Min(1f, star.EaseProgress + 0.025f);
                        float t = star.EaseProgress;
                        float eased = 1 - (float)Math.Pow(1 - t, 3); // easeOutCubic - 先快后慢的缓动

                        // 直接更新 X/Y（原始方式）
                        star.X = star.StartX + (star.TargetX - star.StartX) * eased;
                        star.Y = star.StartY + (star.TargetY - star.StartY) * eased;

                        // 在飞入过程中逐渐增加超新星亮度
                        star.SupernovaProgress = eased;

                        if (star.EaseProgress >= 1f)
                        {
                            star.HasSettled = true;
                            star.SettleTimer = 30; // 着陆闪光
                            star.HighlightDelay = _rand.Next(20, 100); // 随机延迟 20~100 帧（≈0.3~1.6秒）
                            star.HighlightProgress = 0f;
                        }
                    }
                    else
                    {
                        // 处理超新星爆发效果：到达位置后渐暗
                        if (star.IsSupernovaActive)
                        {
                            // 超新星衰减阶段：逐渐恢复到正常亮度
                            star.SupernovaProgress = Math.Max(0f, star.SupernovaProgress - 0.03f);
                            if (star.SupernovaProgress <= 0f)
                            {
                                star.IsSupernovaActive = false;
                            }
                        }

                        // 处理高亮延迟
                        if (star.HighlightDelay > 0)
                        {
                            star.HighlightDelay--;
                        }
                        else if (star.HighlightProgress > 0f)
                        {
                            // 高亮逐渐减弱
                            star.HighlightProgress = Math.Max(0f, star.HighlightProgress - 0.01f);
                        }
                        // 增强常规状态下的随机点亮效果
                        else if (_rand.NextDouble() < 0.015)
                        {
                            // 随机重置高亮进度，产生更明显的闪烁效果
                            star.HighlightProgress = 0.5f + (float)_rand.NextDouble() * 0.5f;
                            star.HighlightDelay = _rand.Next(15, 80); // 更短的延迟，让效果更频繁
                        }

                        // 正常漂移（飞入完成后）
                        if (ClientRectangle.Width > 0 && ClientRectangle.Height > 0) {
                            star.X += star.VelocityX;
                            star.Y += star.VelocityY;
                            if (star.X <= 0 || star.X >= ClientRectangle.Width) star.VelocityX *= -0.8f;
                            if (star.Y <= 0 || star.Y >= ClientRectangle.Height) star.VelocityY *= -0.8f;
                            star.X = Math.Max(0, Math.Min(ClientRectangle.Width, star.X));
                            star.Y = Math.Max(0, Math.Min(ClientRectangle.Height, star.Y));
                        }
                    }

                    // 闪烁 & 鼠标交互（不变）
                    star.BlinkPhase += star.BlinkSpeed;
                    if (star.BlinkPhase > Math.PI * 2) star.BlinkPhase -= (float)(Math.PI * 2);

                    // === 鼠标交互光晕（恢复 V14.1 原始强度）===
                    float dx = star.X - _mousePos.X;
                    float dy = star.Y - _mousePos.Y;
                    float dist = (float)Math.Sqrt(dx * dx + dy * dy);
                    if (dist < 60f)
                    {
                        star.GlowFactor = Math.Min(1f, star.GlowFactor + 0.08f + (1f - dist / 60f) * 0.04f);
                    }
                    else
                    {
                        star.GlowFactor = Math.Max(0f, star.GlowFactor - 0.05f);
                    }
                } catch { }
            } // ←←← 关键：foreach 循环在此正确结束！

            // 更新流星
            for (int i = _meteors.Count - 1; i >= 0; i--)
            {
                try {
                    _meteors[i].Update();
                    if (!_meteors[i].IsAlive()) _meteors.RemoveAt(i);
                } catch { }
            }

            // 更新深空粒子
            for (int i = 0; i < _particles.Count; i++)
            {
                try {
                    _particles[i].Update(ClientRectangle);
                } catch { }
            }

            Invalidate();
        } catch { }
    }

    private void OnMouseMove(object sender, MouseEventArgs e)
    {
        _mousePos = e.Location;
    }

    private void OnMouseLeave(object sender, EventArgs e)
    {
        _mousePos = new Point(-1000, -1000);
    }

    private void InitializeStars()
    {
        _stars.Clear();
        _particles.Clear();

        int starCount = AuroraRenderEngine.StarCount; // 动态星星数量
        int particleCount = AuroraRenderEngine.ParticleCount; // 动态粒子数量
        int width = Math.Max(1, this.Width);
        int height = Math.Max(1, this.Height);

        for (int i = 0; i < starCount; i++)
        {
            float targetX, targetY;
            // 恢复均匀分布的星星生成逻辑
            targetX = (float)_rand.NextDouble() * width;
            targetY = (float)_rand.NextDouble() * height;
            
            float size = (float)(_rand.NextDouble() * 2.5 + 0.5);
            float baseAlpha = (float)(_rand.NextDouble() * 100 + 30); // 增加基础亮度
            float velX = ((float)_rand.NextDouble() - 0.5f) * 0.15f;
            float velY = ((float)_rand.NextDouble() - 0.5f) * 0.15f;

            // === 从中心深处飞出：计算起点 ===
            float centerX2 = width / 2f;
            float centerY2 = height / 2f;
            // 计算从中心到目标点的方向
            float angleToTarget = (float)Math.Atan2(targetY - centerY2, targetX - centerX2);
            // 起点距离中心较近（中心深处）
            float distance = (float)(_rand.NextDouble() * 50 + 20); // 20-70像素，模拟中心深处

            float offsetX = (float)Math.Cos(angleToTarget) * distance;
            float offsetY = (float)Math.Sin(angleToTarget) * distance;

            // 初始位置设为中心附近（深处）
            float startX = centerX2 + offsetX;
            float startY = centerY2 + offsetY;

            _stars.Add(new Star(targetX, targetY, size, baseAlpha, velX, velY, startX, startY));
        }

        for (int i = 0; i < particleCount; i++) // 动态粒子数量
        {
            float x, y;
            // 优化中心粒子分布：减少中心区域的粒子密度
            do {
                x = (float)_rand.NextDouble() * width;
                y = (float)_rand.NextDouble() * height;
                // 计算到中心的距离
                float centerX = width / 2f;
                float centerY = height / 2f;
                float distanceToCenter = (float)Math.Sqrt(Math.Pow(x - centerX, 2) + Math.Pow(y - centerY, 2));
                // 中心区域（半径为宽度的1/2）的粒子生成概率大幅降低
                if (distanceToCenter > width / 2 || _rand.NextDouble() < 0.1) {
                    break; // 非中心区域或中心区域的更小概率事件
                }
            } while (true);
            _particles.Add(new DeepSpaceParticle(x, y));
        }
    }

    private static int ClampColor(int value)
    {
        return Math.Max(0, Math.Min(255, value));
    }

    
    // ===== 新增：专业的缓动函数 =====
    private static float EaseOutCubic(float t)
    {
        return 1.0f - (float)Math.Pow(1.0f - t, 3.0f);
    }

    // ===== 新增：easeInCubic，作为 easeOutCubic 的镜像 =====
    private static float EaseInCubic(float t)
    {
        return (float)Math.Pow(t, 3.0f);
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        // 只有在 !IsWindowAnimating 时，才允许调用 InitializeStars()
        if (!IsWindowAnimating)
        {
            InitializeStars();
        }
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;

        Rectangle rect = ClientRectangle;
        if (rect.Width <= 0 || rect.Height <= 0) return;
        
        // 第一次绘制时初始化星星，确保尺寸正确
        if (_stars.Count == 0)
        {
            InitializeStars();
        }

        // === 1. 极光背景 ===
        using (GraphicsPath path = new GraphicsPath())
        {
            path.AddRectangle(rect);
            using (PathGradientBrush brush = new PathGradientBrush(path))
            {
                float t = _gradientOffset;
                int red = ClampColor((int)(30 + 20 * Math.Sin(t * Math.PI * 2)));
                int green = ClampColor((int)(100 + 90 * Math.Sin(t * Math.PI * 2 + 1.2)));
                int blue = ClampColor((int)(140 + 80 * Math.Sin(t * Math.PI * 2 + 2.5)));
                Color centerColor = Color.FromArgb(255, red, green, blue);
                brush.CenterColor = centerColor;
                brush.SurroundColors = new Color[] {
                    Color.FromArgb(255, 10, 20, 55),
                    Color.FromArgb(255, 15, 30, 60),
                    Color.FromArgb(255, 20, 80, 100),
                    Color.FromArgb(255, 25, 70, 90)
                };
                g.FillPath(brush, path);
            }
        }

        // === 2. 星座连线 ===
        _constellationPoints.Clear();
        int maxPoints = 8;
        for (int i = 0; i < _stars.Count && _constellationPoints.Count < maxPoints; i++)
        {
            if (_stars[i].GlowFactor > 0.5f)
            {
                _constellationPoints.Add(new Point((int)_stars[i].X, (int)_stars[i].Y));
            }
        }
        if (_constellationPoints.Count >= 2)
        {
            using (Pen pen = new Pen(Color.FromArgb(60, 150, 255), 1.2f))
            {
                g.DrawLines(pen, _constellationPoints.ToArray());
            }
        }

        // === 3. 绘制星星 ===
        foreach (Star star in _stars)
        {
            float blinkIntensity = (float)Math.Sin(star.BlinkPhase) * 0.3f + 0.7f;
            blinkIntensity = Math.Max(0.3f, blinkIntensity);

            float highlightFactor = star.HasSettled ? star.HighlightProgress : 0f;
            
            // 添加超新星爆发效果
            float supernovaFactor = star.IsSupernovaActive ? star.SupernovaProgress : 0f;
            float totalBrightness = Math.Min(1.8f,
                star.BaseBrightness * blinkIntensity * (1.0f + highlightFactor * 0.4f) +
                star.GlowFactor * 1.2f +
                supernovaFactor * 0.75f // 超新星爆发的额外亮度（减少一半）
            );

            if (star.HasSettled && star.SettleTimer > 0)
            {
                float pulse = star.SettleTimer > 20 ? 1.3f : (star.SettleTimer / 20f) * 0.3f + 1.0f;
                totalBrightness = Math.Min(1.8f, totalBrightness * pulse);
            }

            float currentAlpha = Math.Min(255f, totalBrightness * 255f * star.entranceAlpha);
            float currentSize = star.Size;

            if (currentAlpha > 8)
            {
                // 绘制星星（使用缓存的 Brush）
                int starAlphaIdx = Math.Max(0, Math.Min(255, (int)currentAlpha));
                g.FillEllipse(_starBrushCache[starAlphaIdx], star.X - currentSize / 2, star.Y - currentSize / 2, currentSize, currentSize);

                // 绘制光晕（使用缓存的 Brush）
                if (AuroraRenderEngine.EnableComplexGlow && (star.GlowFactor > 0.1f || highlightFactor > 0.3f || supernovaFactor > 0.1f))
                {
                    float glowSize = currentSize * (1.0f + Math.Min(1.8f, 
                        star.GlowFactor * 1.8f + 
                        highlightFactor * 0.3f +
                        supernovaFactor * 1.0f // 超新星爆发的额外光晕（减少一半）
                    ));
                    float glowAlpha = Math.Min(120f, 
                        ((star.GlowFactor * 90f) + 
                        (highlightFactor * 25f) +
                        (supernovaFactor * 60f)) * star.entranceAlpha // 应用透明度渐变
                    );
                    if (glowAlpha > 20)
                    {
                        int glowAlphaIdx = Math.Max(0, Math.Min(255, (int)glowAlpha));
                        g.FillEllipse(_glowBrushCache[glowAlphaIdx], star.X - glowSize / 2, star.Y - glowSize / 2, glowSize, glowSize);
                    }
                }
            }
        }

        // === 4. 批量绘制深空粒子 ===
        using (GraphicsPath particlePath = new GraphicsPath())
        {
            for (int i = 0; i < _particles.Count; i++)
            {
                DeepSpaceParticle p = _particles[i];
                if (p.Alpha > 0)
                {
                    particlePath.AddEllipse(p.X - p.Size / 2, p.Y - p.Size / 2, p.Size, p.Size);
                }
            }
            if (particlePath.PointCount > 0)
            {
                using (SolidBrush particleBrush = new SolidBrush(Color.FromArgb(255, 255, 255)))
                {
                    g.FillPath(particleBrush, particlePath);
                }
            }
        }

        // === 5. 绘制流星 ===
        foreach (Meteor meteor in _meteors)
        {
            float alpha = (1f - meteor.CurrentLife / (float)meteor.LifeSpan) * 255f;
            if (alpha <= 5) continue;

            // 绘制流星尾迹
            for (int j = 0; j < meteor.Trail.Count; j++)
            {
                float fade = 1f - j / (float)meteor.Trail.Count;
                float currentAlpha = alpha * fade * 0.8f;
                if (currentAlpha < 10) continue;
                float size = meteor.Size * (1f - j / (float)meteor.Trail.Count);
                using (SolidBrush trailBrush = new SolidBrush(Color.FromArgb((int)currentAlpha, 150, 220, 255)))
                {
                    g.FillEllipse(trailBrush, meteor.Trail[j].X - size / 2, meteor.Trail[j].Y - size / 2, size, size);
                }
            }

            // 绘制流星头部
            float headAlpha = Math.Min(255f, alpha * 1.5f);
            using (SolidBrush headBrush = new SolidBrush(Color.FromArgb((int)headAlpha, 255, 255, 255)))
            {
                g.FillEllipse(headBrush, meteor.X - meteor.Size / 2, meteor.Y - meteor.Size / 2, meteor.Size, meteor.Size);
            }

            // 绘制尾迹连线
            if (meteor.Trail.Count >= 2)
            {
                using (Pen pen = new Pen(Color.FromArgb((int)(alpha * 0.4f), 180, 230, 255), 0.8f))
                {
                    g.DrawLines(pen, meteor.Trail.ToArray());
                }
            }
        }

        // === 【V14.4】UWP 风格文本动画 - 对称缓动 + 无缝衔接 ===
        // ===== 在此处声明并初始化 StringFormat =====
        StringFormat sf = new StringFormat();
        sf.LineAlignment = StringAlignment.Center;
        sf.Alignment = TextAlignment;
        // ==========================================

        if (_transitionState == TextTransitionState.Idle)
        {
            // 空闲状态：直接绘制当前文本
            if (!string.IsNullOrEmpty(_currentText))
            {
                using (SolidBrush brush = new SolidBrush(_textColor))
                {
                    g.DrawString(_currentText, _statusFont, brush, TextX, TextY, sf);
                }
            }
        }
        else
        {
            // 动画状态：同时管理新旧文本
            
            // 1. 绘制正在淡出的旧文本（使用 easeInCubic）
            if (_transitionState == TextTransitionState.FadingOut)
            {
                float progress = _transitionProgress;
                float easedProgress = EaseInCubic(progress); // 淡出用 ease-in: 慢 -> 快
                float oldTextX = TextX - (easedProgress * 20f); // 向左滑出
                float oldAlpha = (1f - easedProgress) * 255f;     // 同步淡出
                if (oldAlpha > 0 && !string.IsNullOrEmpty(_currentText))
                {
                    using (SolidBrush brush = new SolidBrush(Color.FromArgb((int)oldAlpha, _textColor)))
                    {
                        g.DrawString(_currentText, _statusFont, brush, oldTextX, TextY, sf);
                    }
                }
            }

            // 2. 绘制正在淡入的新文本（使用 easeOutCubic）
            if (_transitionState == TextTransitionState.FadingIn)
            {
                float progress = _transitionProgress;
                float easedProgress = EaseOutCubic(progress); // 淡入用 ease-out: 快 -> 慢
                float newTextX = TextX + (1f - easedProgress) * 20f; // 从右侧滑入
                float newAlpha = easedProgress * 255f;              // 同步淡入
                if (newAlpha > 0 && !string.IsNullOrEmpty(_nextText)) // <-- 关键：绘制 _nextText
                {
                    using (SolidBrush brush = new SolidBrush(Color.FromArgb((int)newAlpha, _textColor)))
                    {
                        g.DrawString(_nextText, _statusFont, brush, newTextX, TextY, sf); // <-- 关键：绘制 _nextText
                    }
                }
            }
        }
        base.OnPaint(e);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            if (_timer != null)
            {
                _timer.Stop();
                _timer.Dispose();
            }
            if (_statusFont != null)
            {
                _statusFont.Dispose();
            }
            if (_stars != null)
            {
                _stars.Clear();
            }
            if (_meteors != null)
            {
                _meteors.Clear();
            }
            if (_particles != null)
            {
                _particles.Clear();
            }
            if (_constellationPoints != null)
            {
                _constellationPoints.Clear();
            }
            // 释放 Brush 缓存
            if (_starBrushCache != null)
            {
                foreach (var brush in _starBrushCache)
                {
                    brush.Dispose();
                }
                _starBrushCache = null;
            }
            if (_glowBrushCache != null)
            {
                foreach (var brush in _glowBrushCache)
                {
                    brush.Dispose();
                }
                _glowBrushCache = null;
            }
        }
        base.Dispose(disposing);
    }

    // ========== 内部类 ==========
    private class Star
    {
        // === 原始字段（必须保留！）===
        public float X, Y; // 实际位置（动画直接修改）
        public readonly float TargetX, TargetY;
        public readonly float StartX, StartY;
        public readonly float Size;
        public readonly float BaseAlpha;
        public readonly float BaseBrightness;
        public float VelocityX, VelocityY;
        public float GlowFactor;
        public readonly float GlowFadeSpeed = 0.05f;
        public float BlinkPhase;
        public float BlinkSpeed;
        public float EaseProgress = 0f;
        public bool HasSettled = false;
        public int SettleTimer = 0; // 着陆闪光计时器

        // === 新增：用于控制飞入后的随机高亮 ===
        public int HighlightDelay = 0; // 延迟多少帧后开始高亮
        public float HighlightProgress = 0f; // 高亮进度 [0~1]
        
        // === 新增：超新星爆发效果 ===
        public float SupernovaProgress = 0f; // 超新星爆发进度 [0~1]
        public bool IsSupernovaActive = true; // 是否处于超新星爆发状态
        
        // === 新增：错峰飞入效果 ===
        public int entranceDelay = 0; // 入场延迟帧数
        public float entranceAlpha = 0f; // 入场透明度渐变

        public Star(float targetX, float targetY, float size, float baseAlpha, float velocityX, float velocityY, float startX, float startY)
        {
            this.TargetX = targetX;
            this.TargetY = targetY;
            this.StartX = startX;
            this.StartY = startY;
            this.X = startX; // 初始位置 = 起点
            this.Y = startY;
            this.Size = size;
            this.BaseAlpha = baseAlpha;
            this.BaseBrightness = baseAlpha / 255f;
            this.VelocityX = velocityX;
            this.VelocityY = velocityY;
            this.GlowFactor = 0f;
            this.BlinkPhase = (float)_rand.NextDouble() * (float)Math.PI * 2;
            this.BlinkSpeed = 0.02f + (float)_rand.NextDouble() * 0.03f;
            this.entranceDelay = _rand.Next(0, 200); // 增加延迟范围，0-200帧的随机延迟
            this.entranceAlpha = 0f; // 初始透明度为0
        }
    }

    private class Meteor
    {
        public float X, Y;
        public float VX, VY;
        public int LifeSpan;
        public int CurrentLife;
        public float Size;
        public List<PointF> Trail = new List<PointF>();

        public Meteor(float x, float y, float vx, float vy, int lifespanFrames)
        {
            X = x;
            Y = y;
            VX = vx;
            VY = vy;
            LifeSpan = lifespanFrames;
            CurrentLife = 0;
            Size = 1.5f + (float)_rand.NextDouble() * 2.5f;
            Trail.Capacity = 12;
        }

        public void Update()
        {
            X += VX;
            Y += VY;
            CurrentLife++;
            Trail.Add(new PointF(X, Y));
            if (Trail.Count > 12) Trail.RemoveAt(0);
        }

        public bool IsAlive()
        {
            return CurrentLife < LifeSpan;
        }
    }

    private class DeepSpaceParticle
    {
        public float X, Y;
        public float VX, VY;
        public int Alpha;
        public float Size;

        public DeepSpaceParticle(float x, float y)
        {
            X = x;
            Y = y;
            // 从边缘向中心移动的方向
            float centerX = 210f; // 假设中心位置
            float centerY = 95f;
            float angle = (float)Math.Atan2(centerY - y, centerX - x);
            float speed = 0.03f + (float)_rand.NextDouble() * 0.03f;
            VX = (float)Math.Cos(angle) * speed;
            VY = (float)Math.Sin(angle) * speed;
            Alpha = _rand.Next(60, 120); // 降低透明度
            Size = 0.3f + (float)_rand.NextDouble() * 1.0f; // 减小尺寸
        }

        public void Update(Rectangle bounds)
        {
            X += VX;
            Y += VY;
            // 边界处理：当粒子到达中心区域后重新从边缘生成
            float centerX = bounds.Width / 2f;
            float centerY = bounds.Height / 2f;
            float distanceToCenter = (float)Math.Sqrt(Math.Pow(X - centerX, 2) + Math.Pow(Y - centerY, 2));
            if (distanceToCenter < 50) // 到达中心区域
            {
                // 从边缘随机位置重新生成
                float angle = (float)(_rand.NextDouble() * Math.PI * 2);
                float distance = (float)(_rand.NextDouble() * 50 + Math.Max(bounds.Width, bounds.Height) / 2);
                X = centerX + (float)Math.Cos(angle) * distance;
                Y = centerY + (float)Math.Sin(angle) * distance;
                // 重新计算移动方向
                angle = (float)Math.Atan2(centerY - Y, centerX - X);
                float speed = 0.03f + (float)_rand.NextDouble() * 0.03f;
                VX = (float)Math.Cos(angle) * speed;
                VY = (float)Math.Sin(angle) * speed;
            }
        }
    }
}



"@ -Language CSharp


# === PowerShell 辅助函数：创建带降级的字体 ===
function global:Get-EmojiFont {
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

# === PowerShell 辅助函数：创建等宽字体 ===
function global:Get-MonospaceFont {
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

# === PowerShell 辅助函数：创建无衬线字体 ===
function global:Get-SansSerifFont {
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

# === PowerShell 辅助函数：更新 StarfieldPanel 的状态文本 ===
function global:Update-StarfieldStatusText {
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

# === PowerShell 辅助函数：创建 AuroraProgressBar 实例 ===
function global:CreateAuroraProgressBar {
    $pb = New-Object AuroraProgressBar
    $pb.Size = New-Object System.Drawing.Size(300, 12)   # 尺寸
    $pb.Location = New-Object System.Drawing.Point(60, 90) # 位置
    $pb.Minimum = 0
    $pb.Maximum = 100
    $pb.Value = 0
    $pb.CornerRadius = 8
    return $pb
}

# === #############################################################################
# 🔍 完善的目录完整性检测系统
###############################################################################
# === 获取脚本目录
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
# 根目录是 Scripts 的父目录（EXE 所在目录）
$rootDir = Split-Path -Parent $scriptDir
$ScriptsDir = Join-Path $rootDir "Scripts"
$DataDir = Join-Path $rootDir "Data"
$ResourcesDir = Join-Path $rootDir "Resources"
$engScript = Join-Path $ScriptsDir "AURORA-AnalyzerENGPRO.ps1"
$chsScript = Join-Path $ScriptsDir "AURORA-AnalyzerCHSPRO.ps1"

# === 定义所需文件列表（必需文件描述用于错误提示）
# 使用子目录结构: Scripts\, Data\, Resources\
$RequiredFiles = @{
    # 核心启动文件（根目录）
    "AURORA.Launcher-双击启动.exe"       = "主启动器（免密码启动 GUI）"
    "Scripts\AURORA-AnalyzerLauncherGUI.ps1"  = "主启动 GUI 脚本（界面与任务管理）"
    
    # PRO 模式核心引擎
    "Scripts\AURORA-AnalyzerENGPRO.ps1"    = "英文专业版日志导出引擎"
    "Scripts\AURORA-AnalyzerCHSPRO.ps1"    = "中文专业版日志导出引擎"
    
    # 智能诊断系统
    "Scripts\AURORA-SmartEngine.ps1"            = "智能诊断引擎"
    "Data\AURORA-TechData.json"              = "技术知识库（诊断规则）"
    
    # 进度管理系统（会话持久化与断点续传）
    "Scripts\AURORA-ProgressManager.ps1"        = "进度管理器核心模块"
    "Scripts\AURORA-ProgressManager-Integration-CHS.ps1" = "中文版进度保存集成模块"
    "Scripts\AURORA-ProgressManager-Integration-ENG.ps1" = "英文版进度保存集成模块"
}

# === 可选文件列表（警告而非错误）
$OptionalFiles = @{
    "GAURORA.CHK.ENC"                  = "完整性验证文件（EXE 启动用）"
    "Resources\CascadiaMono.ttf"                  = "现代等宽字体文件（美化界面）"
    "version.txt"                          = "版本信息文件"
}

# === 检测系统语言用于提示
$UseChineseUI = $false
try {
    $uiCulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture.Name
    if ($uiCulture -like "zh*") {
        $UseChineseUI = $true
    }
} catch {}

# === 目录完整性检测函数
function Test-DirectoryIntegrity {
    param([switch]$ShowWarning = $false)

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

    # 可选文件警告（仅在ShowWarning时显示）
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

# === 加载必要的程序集用于界面显示
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
} catch {
    # 忽略错误，可能已加载
}

# === 执行目录完整性检测
if (-not (Test-DirectoryIntegrity -ShowWarning)) {
    exit 1
}

# === 检查管理员权限 ===
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# === 【核心修复 1/3】提前初始化进度管理器（在 PRO 模式启动前创建 SessionCache）===
# 导入进度管理器核心模块
. "$scriptDir\AURORA-ProgressManager.ps1"
# 初始化缓存目录（优先使用工具目录，降级到 TEMP）
$null = Initialize-CacheDirectory -ToolPath $scriptDir

# === 全局同步哈希表：主 UI 线程和后台 Runspace 之间的唯一数据通道 ===
$global:syncHash = [hashtable]::Synchronized(@{
    IsHostAlive  = $true       # 控制后台线程生命周期
    IsRunning    = $false      # 标记 PRO 脚本是否正在执行
    LogOutput    = ""          # 接收来自 PRO 脚本的日志输出 (UI 定时器读取)
    Progress     = 0           # 接收进度百分比 (0-100)
    UserInput    = $null       # GUI 向 PRO 脚本发送的用户输入指令
    ScriptDone   = $false      # 标记脚本是否彻底执行完毕
    IsAdmin      = $isAdmin    # 记录是否有管理员权限
    
    # 【核心修复 2/3】新增：会话恢复标志（用于异步进度恢复检测）
    SessionRestored = $false   # 标记用户选择恢复进度
    SessionRestarted = $false  # 标记用户选择重新开始
    RestoredSessionId = $null  # 恢复的会话 ID
    RestoredStage = $null      # 恢复的阶段
    RestoredProgress = 0       # 恢复的进度百分比
    HasPendingSession = $false # 标记是否有待恢复的会话
    RestoredLastUpdated = $null # 会话最后更新时间
    RestoredAgeInDays = 0      # 会话已挂起天数
})

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
$logoLabel.Text = "AURORA 2026`nVelociRaptor-GR"
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

# 动画参数：总时长 1180ms（原 812ms × 1.45）
$durationMs = 1180
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
    $elapsedMs = $sw.ElapsedMilliseconds
    if ($elapsedMs -ge $durationMs) { break }

    # 帧率控制：确保每帧间隔至少 frameIntervalMs
    if ($elapsedMs - $lastFrameTime -lt $frameIntervalMs) {
        Start-Sleep -Milliseconds 1
        continue
    }
    $lastFrameTime = $elapsedMs

    $t = [Math]::Min(1.0, $elapsedMs / $durationMs)
    $time = $t * 1.50 # 时间拉伸，增强慢动作效果

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
$splash.Size = New-Object System.Drawing.Size($baseW, $baseH)
$x = [Math]::Max(0, ($wa.Width - $baseW) / 2)
$y = [Math]::Max(0, ($wa.Height - $baseH) / 2)
$splash.Location = New-Object System.Drawing.Point($x, $y)
$splash.Opacity = 1.0

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
$targetDurationMs = 15000  # 目标总时长：15 秒
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
    catch { }

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
# === 【UWP 风格退出动画】轻微放大 + 缓动淡出（替代简单淡出）===
# ===================================================================
$durationMs = 550
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

# 清理资源
$splash.Visible = $false
Start-Sleep -Milliseconds 50
$splash.Dispose()

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
    
    # 标题标签（直接放在 StarfieldPanel 上）
    $restoreTitleLabel = New-Object System.Windows.Forms.Label
    $restoreTitleLabel.Text = $res.Subtitle
    $restoreTitleLabel.Font = Get-EmojiFont -Size 18 -Style ([System.Drawing.FontStyle]::Bold)
    $restoreTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 255)
    $restoreTitleLabel.BackColor = [System.Drawing.Color]::Transparent
    $restoreTitleLabel.Size = New-Object System.Drawing.Size(400, 45)
    $restoreTitleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $restoreTitleLabel.TextAlign = 'MiddleLeft'
    
    $restoreInfoLabel = New-Object System.Windows.Forms.Label
    $restoreInfoLabel.Text = if ($currentLanguage -eq 'CHS') { "您可以选择恢复之前的进度，或者重新开始新会话" } else { "You can choose to resume previous progress or start a new session" }
    $restoreInfoLabel.Font = Get-EmojiFont -Size 9.5
    $restoreInfoLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
    $restoreInfoLabel.BackColor = [System.Drawing.Color]::Transparent
    $restoreInfoLabel.Size = New-Object System.Drawing.Size(500, 50)
    $restoreInfoLabel.Location = New-Object System.Drawing.Point(20, 65)
    $restoreInfoLabel.TextAlign = 'TopLeft'
    
    # 会话信息标题
    $sessionInfoTitle = New-Object System.Windows.Forms.Label
    $sessionInfoTitle.Text = $res.SessionInfo
    $sessionInfoTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
    $sessionInfoTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 255)
    $sessionInfoTitle.BackColor = [System.Drawing.Color]::Transparent
    $sessionInfoTitle.Size = New-Object System.Drawing.Size(690, 30)
    $sessionInfoTitle.Location = New-Object System.Drawing.Point(30, 130)
    $sessionInfoTitle.TextAlign = 'MiddleLeft'
    
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
    
    # 恢复选项标题
    $restoreOptionTitle = New-Object System.Windows.Forms.Label
    $restoreOptionTitle.Text = $res.Restore
    $restoreOptionTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
    $restoreOptionTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 255)
    $restoreOptionTitle.BackColor = [System.Drawing.Color]::Transparent
    $restoreOptionTitle.Size = New-Object System.Drawing.Size(690, 30)
    $restoreOptionTitle.Location = New-Object System.Drawing.Point(30, 305)
    $restoreOptionTitle.TextAlign = 'MiddleLeft'
    
    $restoreOptionDesc = New-Object AuroraConsoleBox
    $restoreOptionDesc.Text = $res.RestoreDesc
    $restoreOptionDesc.Size = New-Object System.Drawing.Size(690, 80)
    $restoreOptionDesc.Location = New-Object System.Drawing.Point(30, 335)
    
    # 重新开始选项标题
    $restartOptionTitle = New-Object System.Windows.Forms.Label
    $restartOptionTitle.Text = $res.Restart
    $restartOptionTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
    $restartOptionTitle.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $restartOptionTitle.BackColor = [System.Drawing.Color]::Transparent
    $restartOptionTitle.Size = New-Object System.Drawing.Size(690, 30)
    $restartOptionTitle.Location = New-Object System.Drawing.Point(30, 420)
    $restartOptionTitle.TextAlign = 'MiddleLeft'
    
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
        } catch {}
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
        } catch {}
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
    $animControls = @($restoreTitleLabel, $restoreInfoLabel, $sessionInfoTitle, $infoSep, $sessionInfoContent, $restoreOptionTitle, $restoreOptionDesc, $restartOptionTitle, $restartOptionDesc, $restoreButton, $restartButton)
    foreach ($c in $animControls) { if ($null -ne $c) { $c.Visible = $false } }
    
    $restoreForm.Add_Shown({
        Start-MainWindowAnimation -Form $restoreForm
        [System.Windows.Forms.Application]::DoEvents()
        
        $restoreForm.SuspendLayout()
        
        Start-UwpEnterAnimation -Control $restoreTitleLabel -TargetLocation $restoreTitleLabel.Location -ParentForm $restoreForm -DurationMs 450 -OffsetY 40 -DelayMs 50
        Start-UwpEnterAnimation -Control $restoreInfoLabel -TargetLocation $restoreInfoLabel.Location -ParentForm $restoreForm -DurationMs 450 -OffsetY 40 -DelayMs 100
        
        Start-UwpEnterAnimation -Control $sessionInfoTitle -TargetLocation $sessionInfoTitle.Location -ParentForm $restoreForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        Start-UwpEnterAnimation -Control $infoSep -TargetLocation $infoSep.Location -ParentForm $restoreForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        Start-UwpEnterAnimation -Control $sessionInfoContent -TargetLocation $sessionInfoContent.Location -ParentForm $restoreForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        
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
    
    # 标题标签（直接放在 StarfieldPanel 上）
    $permTitleLabel = New-Object System.Windows.Forms.Label
    $permTitleLabel.Text = $res.Subtitle
    $permTitleLabel.Font = Get-EmojiFont -Size 18 -Style ([System.Drawing.FontStyle]::Bold)
    $permTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 255)
    $permTitleLabel.BackColor = [System.Drawing.Color]::Transparent
    $permTitleLabel.Size = New-Object System.Drawing.Size(400, 45)
    $permTitleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $permTitleLabel.TextAlign = 'MiddleLeft'
    
    $permInfoLabel = New-Object System.Windows.Forms.Label
    $permInfoLabel.Text = $res.Info
    $permInfoLabel.Font = Get-EmojiFont -Size 9.5
    $permInfoLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
    $permInfoLabel.BackColor = [System.Drawing.Color]::Transparent
    $permInfoLabel.Size = New-Object System.Drawing.Size(500, 50)
    $permInfoLabel.Location = New-Object System.Drawing.Point(20, 65)
    $permInfoLabel.TextAlign = 'TopLeft'
    
    # 普通模式标题
    $normalTitle = New-Object System.Windows.Forms.Label
    $normalTitle.Text = $res.NormalMode
    $normalTitle.Font = Get-EmojiFont -Size 12 -Style ([System.Drawing.FontStyle]::Bold)
    $normalTitle.ForeColor = [System.Drawing.Color]::FromArgb(100, 255, 150)
    $normalTitle.BackColor = [System.Drawing.Color]::Transparent
    $normalTitle.Size = New-Object System.Drawing.Size(450, 35)
    $normalTitle.Location = New-Object System.Drawing.Point(30, 125)
    $normalTitle.TextAlign = 'MiddleLeft'
    
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
    
    # 管理员模式标题
    $adminTitle = New-Object System.Windows.Forms.Label
    $adminTitle.Text = $res.AdminMode
    $adminTitle.Font = Get-EmojiFont -Size 12 -Style ([System.Drawing.FontStyle]::Bold)
    $adminTitle.ForeColor = [System.Drawing.Color]::FromArgb(255, 220, 150)
    $adminTitle.BackColor = [System.Drawing.Color]::Transparent
    $adminTitle.Size = New-Object System.Drawing.Size(450, 35)
    $adminTitle.Location = New-Object System.Drawing.Point(30, 400)
    $adminTitle.TextAlign = 'MiddleLeft'
    
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
    
    # 切换到管理员模式按钮 - 使用 TechButton
    $elevateButton = New-Object TechButton
    $elevateButton.Text = $res.ElevateButton
    $elevateButton.SetBounds(20, 621, 340, 48)
    
    # 继续使用普通模式按钮 - 使用 TechButton
    $continueButton = New-Object TechButton
    $continueButton.Text = $res.ContinueButton
    $continueButton.SetBounds(390, 621, 340, 48)
    
    # 按钮点击事件处理 - 带 UWP 退出动画
    $elevateButton.Add_Click({
        try {
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
        } catch {}
        $elevateForm.DialogResult = 'OK'
        $elevateForm.Close()
    })
    
    $continueButton.Add_Click({
        try {
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
        } catch {}
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
    $elevateBackground.Controls.Add($elevateButton)
    $elevateBackground.Controls.Add($continueButton)
    
    # 无边框拖动支持
    $dragAction = {
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            [Win32Helper]::ReleaseCapture()
            [Win32Helper]::SendMessage($elevateForm.Handle, [Win32Helper]::WM_NCLBUTTONDOWN, [Win32Helper]::HT_CAPTION, 0)
        }
    }
    
    $elevateBackground.Add_MouseDown($dragAction)
    $permTitleLabel.Add_MouseDown($dragAction)
    $permInfoLabel.Add_MouseDown($dragAction)
    $normalTitle.Add_MouseDown($dragAction)
    $normalFeatures.Add_MouseDown($dragAction)
    $normalLimited.Add_MouseDown($dragAction)
    $adminTitle.Add_MouseDown($dragAction)
    $adminFeatures.Add_MouseDown($dragAction)
    
    # 键盘导航
    $elevateButton.TabIndex = 0
    $continueButton.TabIndex = 1
    $elevateForm.AcceptButton = $elevateButton
    $elevateForm.CancelButton = $continueButton
    
    # 底部状态文本
    Update-StarfieldStatusText -Panel $elevateBackground -NewText $res.StatusText
    
    # ====== 新增：在窗体显示前，先隐藏所有参与动效的控件，彻底杜绝闪烁 ======
    $animControls = @($permTitleLabel, $permInfoLabel, $normalTitle, $normalSep, $normalFeatures, $normalLimited, $adminTitle, $adminSep, $adminFeatures, $elevateButton, $continueButton)
    foreach ($c in $animControls) { if ($null -ne $c) { $c.Visible = $false } }
    
    $elevateForm.Add_Shown({
        Start-MainWindowAnimation -Form $elevateForm
        [System.Windows.Forms.Application]::DoEvents()
        
        $elevateForm.SuspendLayout()
        
        Start-UwpEnterAnimation -Control $permTitleLabel -TargetLocation $permTitleLabel.Location -ParentForm $elevateForm -DurationMs 450 -OffsetY 40 -DelayMs 50
        Start-UwpEnterAnimation -Control $permInfoLabel -TargetLocation $permInfoLabel.Location -ParentForm $elevateForm -DurationMs 450 -OffsetY 40 -DelayMs 100
        
        Start-UwpEnterAnimation -Control $normalTitle -TargetLocation $normalTitle.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        Start-UwpEnterAnimation -Control $normalSep -TargetLocation $normalSep.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        Start-UwpEnterAnimation -Control $normalFeatures -TargetLocation $normalFeatures.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        Start-UwpEnterAnimation -Control $normalLimited -TargetLocation $normalLimited.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 150
        
        Start-UwpEnterAnimation -Control $adminTitle -TargetLocation $adminTitle.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 200
        Start-UwpEnterAnimation -Control $adminSep -TargetLocation $adminSep.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 200
        Start-UwpEnterAnimation -Control $adminFeatures -TargetLocation $adminFeatures.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 200
        
        Start-UwpEnterAnimation -Control $elevateButton -TargetLocation $elevateButton.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 250
        Start-UwpEnterAnimation -Control $continueButton -TargetLocation $continueButton.Location -ParentForm $elevateForm -DurationMs 400 -OffsetY 50 -DelayMs 250
        
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
    } else {
        return "Continue"
    }
}

# ====== 权限说明信息对话框 ======
function Show-PermissionInfo {
    param(
        [System.Windows.Forms.Form]$ParentForm
    )
    
    # 使用系统语言作为默认
    $systemLanguage = if ((Get-UICulture).Name -like 'zh*') { 'CHS' } else { 'ENG' }
    $currentLanguage = $systemLanguage
    
    $infoMsg = if ($currentLanguage -eq "CHS") {
        "AURORA 需要管理员权限的原因：`n`n" +
        "1. 查看安全日志（Security Log）`n" +
        "   - 记录系统安全事件`n" +
        "   - Windows 限制访问`n`n" +
        "2. 查看安装日志（Setup Log）`n" +
        "   - 记录 Windows 安装事件`n" +
        "   - 需要管理员权限`n`n" +
        "3. 系统修复操作`n" +
        "   - 修改系统配置`n" +
        "   - 执行修复命令`n`n" +
        "4. 深度智能诊断`n" +
        "   - 访问系统核心信息`n" +
        "   - 执行深度分析`n`n" +
        "💡 提示：提权后，所有功能将完全可用。"
    } else {
        "Reasons AURORA needs administrator privileges：`n`n" +
        "1. Security Log Access`n" +
        "   - Records system security events`n" +
        "   - Restricted by Windows`n`n" +
        "2. Setup Log Access`n" +
        "   - Records Windows installation events`n" +
        "   - Requires admin privileges`n`n" +
        "3. System Repair Operations`n" +
        "   - Modify system configuration`n" +
        "   - Execute repair commands`n`n" +
        "4. Deep Smart Diagnosis`n" +
        "   - Access core system information`n" +
        "   - Perform deep analysis`n`n" +
        "💡 Tip: After elevation, all features will be fully available."
    }
    
    [System.Windows.Forms.MessageBox]::Show(
        $infoMsg,
        $(if ($currentLanguage -eq "CHS") { "为什么需要管理员权限" } else { "Why Administrator Privileges Are Needed" }),
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}

# ====== 提权重启功能 ======
function Restart-WithAdmin {
    try {
        # 直接使用 Start-Process 请求 UAC 提权
        $scriptPath = $PSCommandPath
        
        # 保留原始启动参数（如果是 EXE 启动的，需要传递 -LaunchedByExe）
        # 关键修复：添加 -ExecutionPolicy Bypass 绕过执行策略限制
        # 关键修复：添加 -WindowStyle Hidden 隐藏控制台窗口
        $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        if ($IsLaunchedByExe) {
            $arguments += " -LaunchedByExe"
        }
        
        Write-Host " 提权参数：$arguments" -ForegroundColor Gray
        Write-Host " 脚本路径：$scriptPath" -ForegroundColor Gray
        
        $processInfo = Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -PassThru
        Write-Host " 新进程 ID: $($processInfo.Id)" -ForegroundColor Green
        return $true
    }
    catch {
        # 显示详细错误信息
        $errorMsg = $_.Exception.Message
        Write-Host " 提权失败错误：$errorMsg" -ForegroundColor Red
        
        # 用户取消了 UAC 对话框
        [System.Windows.Forms.MessageBox]::Show(
            $(if ($script:selectedLanguage -eq "CHS") {
                "提权已取消，将继续以普通用户模式运行。`n`n错误详情：$errorMsg`n`n如需管理员权限，请右键点击 AURORA.Launcher-双击启动.exe，选择'以管理员身份运行'。"
            } else {
                "Elevation cancelled, will continue with standard user mode.`n`nError: $errorMsg`n`nTo run as administrator, right-click AURORA.Launcher-双击启动.exe and select 'Run as administrator'."
            }),
            $(if ($script:selectedLanguage -eq "CHS") { "提示" } else { "Information" }),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return $false
    }
}

# ====== 主语言选择窗口（固定尺寸 400x480，无边框）======
function ShowMainForm {
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
    # 标题
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "请根据当前系统环境选择语言版本"
    $titleLabel.Location = New-Object System.Drawing.Point(60, 45)
    $titleLabel.Size = New-Object System.Drawing.Size(280, 45)
    $titleLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 12, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $titleLabel.BackColor = [System.Drawing.Color]::Transparent
    $titleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $titleLabel.AutoSize = $false
    $titleLabel.Visible = $false
    $titleLabel.Anchor = 'None'
    $background.Controls.Add($titleLabel)

    $btnEng = CreateButton -Text "English" -TargetTop 180
    $btnChs = CreateButton -Text "简体中文" -TargetTop 260 
    $btnExit = CreateButton -Text "退出-Exit" -TargetTop 340 

    # 设置 Tab 键顺序
    $btnEng.TabIndex = 0
    $btnChs.TabIndex = 1
    $btnExit.TabIndex = 2

    # ====== 视图 2：模式选择（4个元素）======
    $styleTitleLabel = New-Object System.Windows.Forms.Label
    $styleTitleLabel.Text = "请选择模式 / Select Mode"
    $styleTitleLabel.Location = New-Object System.Drawing.Point(40, 45)
    $styleTitleLabel.Size = New-Object System.Drawing.Size(320, 45)
    $styleTitleLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 12, [System.Drawing.FontStyle]::Bold)
    $styleTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $styleTitleLabel.BackColor = [System.Drawing.Color]::Transparent
    $styleTitleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $styleTitleLabel.AutoSize = $false
    $styleTitleLabel.Visible = $false
    $styleTitleLabel.Anchor = 'None'
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
        $exitTimer = New-Object System.Windows.Forms.Timer
        $exitTimer.Interval = 650 # 先等UWP退出动画完成
        $exitTimer.Add_Tick({
            $this.Stop()
            $this.Dispose()
            
            # 完整播放退出动画（同步阻塞450ms）
            try {
                Start-MainWindowExitAnimation -Form $Form
                
                # 等待退出动画完成后再退出程序
                $finalTimer = New-Object System.Windows.Forms.Timer
                $finalTimer.Interval = 500 # 等待主窗口退出动画完成
                $finalTimer.Add_Tick({
                    $this.Stop()
                    $this.Dispose()
                    [System.Environment]::Exit(0)
                }.GetNewClosure())
                $finalTimer.Start()
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
            } catch {}

            # 3. 异步切换视图
            $waitTimer = New-Object System.Windows.Forms.Timer
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
                    # 5. 视图切换完成
                    $Global:IsViewTransitioning = $false
                } catch { 
                    $Global:IsViewTransitioning = $false
                }
            })
            $waitTimer.Start()
        }
    })

    $btnEng.Add_Click({
        if (-not $script:launched -and -not $Global:IsViewTransitioning) {
            # 标记正在进行视图切换，防止重复触发
            $Global:IsViewTransitioning = $true
            
            # 记录选择
            $script:selectedLanguage = "ENG"
            # 注意：不应该在这里设置 selectedMode，因为这是语言选择，不是模式选择

            # 0. 立即停止所有正在运行的动画并恢复控件状态
            Stop-AllAnimations -RestoreState
            
            # 0.3 核心修复：立即隐藏所有控件，防止RestoreState导致的闪现
            $titleLabel.Visible = $false
            $btnEng.Visible = $false
            $btnChs.Visible = $false
            $btnExit.Visible = $false
            $styleTitleLabel.Visible = $false
            $btnSmart.Visible = $false
            $btnGUI.Visible = $false
            $btnConsole.Visible = $false
            $btnBack.Visible = $false
            
            # 0.5 关键：强制重置所有控件到原始位置（确保每次动画都从正确位置开始）
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
            
            # 0.6 保存重置后的控件状态
            Save-ControlState -Control $titleLabel
            Save-ControlState -Control $btnEng
            Save-ControlState -Control $btnChs
            Save-ControlState -Control $btnExit
            Save-ControlState -Control $styleTitleLabel
            Save-ControlState -Control $btnSmart
            Save-ControlState -Control $btnGUI
            Save-ControlState -Control $btnConsole
            Save-ControlState -Control $btnBack
            
            # 1. 立即禁用视图 1 的所有按钮，防误触
            $btnEng.Enabled = $false; $btnChs.Enabled = $false; $btnExit.Enabled = $false
            
            # 2. 依次飞出视图 1
            try {
                Start-UwpExitAnimation -Control $titleLabel -DurationMs 400 -OffsetY 40 -StaggerDelay 0 -IsButton $false
                Start-UwpExitAnimation -Control $btnEng -DurationMs 400 -OffsetY 50 -StaggerDelay 50 -IsButton $true
                Start-UwpExitAnimation -Control $btnChs -DurationMs 400 -OffsetY 50 -StaggerDelay 100 -IsButton $true
                Start-UwpExitAnimation -Control $btnExit -DurationMs 400 -OffsetY 50 -StaggerDelay 150 -IsButton $true
            } catch {}

            # 3. 异步切换视图
            $waitTimer = New-Object System.Windows.Forms.Timer
            $waitTimer.Interval = 650
            $waitTimer.Add_Tick({
                $this.Stop()
                $this.Dispose()
                
                try {
                    # 1. 隐藏视图1的控件
                    $titleLabel.Visible = $false
                    $btnEng.Visible = $false
                    $btnChs.Visible = $false
                    $btnExit.Visible = $false
                    
                    # 2. 先隐藏所有视图2的控件，防止旧状态闪现，然后启用它们
                    $styleTitleLabel.Visible = $false
                    $btnSmart.Visible = $false
                    $btnGUI.Visible = $false
                    $btnConsole.Visible = $false
                    $btnBack.Visible = $false
                    $styleTitleLabel.Enabled = $true
                    $btnSmart.Enabled = $true
                    $btnGUI.Enabled = $true
                    $btnConsole.Enabled = $true
                    $btnBack.Enabled = $true

                    # 3. 根据选择的语言动态设置按钮文本
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

                    # 4. 触发视图2的飞入动画
                    Start-UwpEnterAnimation -Control $styleTitleLabel -TargetLocation (New-Object System.Drawing.Point(40, 45)) -ParentForm $form -DurationMs 400 -OffsetY 100 -DelayMs 0
                    Start-UwpEnterAnimation -Control $btnSmart -TargetLocation (New-Object System.Drawing.Point(60, 110)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 50
                    Start-UwpEnterAnimation -Control $btnGUI -TargetLocation (New-Object System.Drawing.Point(60, 190)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 100
                    Start-UwpEnterAnimation -Control $btnConsole -TargetLocation (New-Object System.Drawing.Point(60, 270)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 150
                    Start-UwpEnterAnimation -Control $btnBack -TargetLocation (New-Object System.Drawing.Point(60, 350)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 200
                    
                    # 5. 更新视图状态
                    $script:currentView = 2
                    # 6. 视图切换完成
                    $Global:IsViewTransitioning = $false
                } catch { 
                    $Global:IsViewTransitioning = $false
                }
            })
            $waitTimer.Start()
        }
    })

    $btnChs.Add_Click({
        if (-not $script:launched -and -not $Global:IsViewTransitioning) {
            # 标记正在进行视图切换，防止重复触发
            $Global:IsViewTransitioning = $true
            
            # 记录选择
            $script:selectedLanguage = "CHS"
            # 注意：不应该在这里设置 selectedMode，因为这是语言选择，不是模式选择

            # 0. 立即停止所有正在运行的动画并恢复控件状态
            Stop-AllAnimations -RestoreState
            
            # 0.3 核心修复：立即隐藏所有控件，防止RestoreState导致的闪现
            $titleLabel.Visible = $false
            $btnEng.Visible = $false
            $btnChs.Visible = $false
            $btnExit.Visible = $false
            $styleTitleLabel.Visible = $false
            $btnSmart.Visible = $false
            $btnGUI.Visible = $false
            $btnConsole.Visible = $false
            $btnBack.Visible = $false
            
            # 0.5 关键：强制重置所有控件到原始位置（确保每次动画都从正确位置开始）
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
            
            # 0.6 保存重置后的控件状态
            Save-ControlState -Control $titleLabel
            Save-ControlState -Control $btnEng
            Save-ControlState -Control $btnChs
            Save-ControlState -Control $btnExit
            Save-ControlState -Control $styleTitleLabel
            Save-ControlState -Control $btnSmart
            Save-ControlState -Control $btnGUI
            Save-ControlState -Control $btnConsole
            Save-ControlState -Control $btnBack
            
            # 1. 立即禁用视图 1 的所有按钮，防误触
            $btnEng.Enabled = $false; $btnChs.Enabled = $false; $btnExit.Enabled = $false
            
            # 2. 依次飞出视图 1
            try {
                Start-UwpExitAnimation -Control $titleLabel -DurationMs 400 -OffsetY 40 -StaggerDelay 0 -IsButton $false
                Start-UwpExitAnimation -Control $btnEng -DurationMs 400 -OffsetY 50 -StaggerDelay 50 -IsButton $true
                Start-UwpExitAnimation -Control $btnChs -DurationMs 400 -OffsetY 50 -StaggerDelay 100 -IsButton $true
                Start-UwpExitAnimation -Control $btnExit -DurationMs 400 -OffsetY 50 -StaggerDelay 150 -IsButton $true
            } catch {}

            # 3. 异步切换视图
            $waitTimer = New-Object System.Windows.Forms.Timer
            $waitTimer.Interval = 650
            $waitTimer.Add_Tick({
                $this.Stop()
                $this.Dispose()
                
                try {
                    # 1. 隐藏视图1的控件
                    $titleLabel.Visible = $false
                    $btnEng.Visible = $false
                    $btnChs.Visible = $false
                    $btnExit.Visible = $false
                    
                    # 2. 先隐藏所有视图2的控件，防止旧状态闪现，然后启用它们
                    $styleTitleLabel.Visible = $false
                    $btnSmart.Visible = $false
                    $btnGUI.Visible = $false
                    $btnConsole.Visible = $false
                    $btnBack.Visible = $false
                    $styleTitleLabel.Enabled = $true
                    $btnSmart.Enabled = $true
                    $btnGUI.Enabled = $true
                    $btnConsole.Enabled = $true
                    $btnBack.Enabled = $true

                    # 3. 根据选择的语言动态设置按钮文本
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

                    # 4. 触发视图2的飞入动画
                    Start-UwpEnterAnimation -Control $styleTitleLabel -TargetLocation (New-Object System.Drawing.Point(40, 45)) -ParentForm $form -DurationMs 400 -OffsetY 100 -DelayMs 0
                    Start-UwpEnterAnimation -Control $btnSmart -TargetLocation (New-Object System.Drawing.Point(60, 110)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 50
                    Start-UwpEnterAnimation -Control $btnGUI -TargetLocation (New-Object System.Drawing.Point(60, 190)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 100
                    Start-UwpEnterAnimation -Control $btnConsole -TargetLocation (New-Object System.Drawing.Point(60, 270)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 150
                    Start-UwpEnterAnimation -Control $btnBack -TargetLocation (New-Object System.Drawing.Point(60, 350)) -ParentForm $form -DurationMs 350 -OffsetY 100 -DelayMs 200
                    
                    # 5. 更新视图状态
                    $script:currentView = 2
                    # 6. 视图切换完成
                    $Global:IsViewTransitioning = $false
                } catch { 
                    $Global:IsViewTransitioning = $false
                }
            })
            $waitTimer.Start()
        }
    })

    # 退出按钮事件
    $btnExit.Add_Click({
        $btnExit.Enabled = $false
        
        # ⚠️ 核心修复：显式将父作用域的 $form 赋值给局部变量
        # 强制其进入当前作用域，这样才能被后续的 .GetNewClosure() 成功捕获，防止传入 $null
        $targetForm = $form
        
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
        $exitTimer = New-Object System.Windows.Forms.Timer
        $exitTimer.Interval = 650 # 先等UWP退出动画完成
        $exitTimer.Add_Tick({
            $this.Stop()
            $this.Dispose()
            
            # 完整播放退出动画（同步阻塞450ms）
            try {
                # 💡 在这里使用成功捕获的 $targetForm
                Start-MainWindowExitAnimation -Form $targetForm
                
                # 等待退出动画完成后再退出程序
                $finalTimer = New-Object System.Windows.Forms.Timer
                $finalTimer.Interval = 500 # 等待主窗口退出动画完成
                $finalTimer.Add_Tick({
                    $this.Stop()
                    $this.Dispose()
                    [System.Environment]::Exit(0)
                }.GetNewClosure())
                $finalTimer.Start()
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
                } catch {}

                # 异步切回视图 2
                $waitTimer = New-Object System.Windows.Forms.Timer
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
                } catch {}

                # 异步切回视图 1
                $waitTimer = New-Object System.Windows.Forms.Timer
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
            } catch {}
            
            # 等待动画完成后启动
            $launchTimer = New-Object System.Windows.Forms.Timer
            $launchTimer.Interval = 600
            $launchTimer.Add_Tick({
                $this.Stop()
                $this.Dispose()
                
                try {
                    # 挂起星空引擎并隐藏主窗口
                    if ($background -ne $null) { $background.StopAnimation() }
                    if ($form -ne $null) { $form.Hide() }
                    
                    # 根据选择启动对应模式
                    if ($script:selectedMode -eq "SMART") {
                        # 启动智能诊断与自主修复模式引擎
                        $smartScript = Join-Path $ScriptsDir "AURORA-SmartEngine.ps1"
                        if (Test-Path $smartScript) {
                            if ($script:selectedLanguage -eq "ENG") {
                                ShowProMode -ScriptPath $smartScript -Title "Smart Auto-Healing" -Language "ENG"
                            } else {
                                ShowProMode -ScriptPath $smartScript -Title "智能诊断与自主修复模式" -Language "CHS"
                            }
                        }
                    } elseif ($script:selectedLanguage -eq "ENG" -and $engScript -ne $null) {
                        ShowProMode -ScriptPath $engScript -Title "English Mode" -Language "ENG"
                    } elseif ($script:selectedLanguage -eq "CHS" -and $chsScript -ne $null) {
                        ShowProMode -ScriptPath $chsScript -Title "简体中文模式" -Language "CHS"
                    }
                    
                    # 退出主窗口
                    [System.Environment].Exit(0)
                } catch {}
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
            } catch {}
            
            # 等待动画完成后启动
            $launchTimer = New-Object System.Windows.Forms.Timer
            $launchTimer.Interval = 600
            $launchTimer.Add_Tick({
                $this.Stop()
                $this.Dispose()
                
                try {
                    # 挂起星空引擎并隐藏主窗口
                    if ($background -ne $null) { $background.StopAnimation() }
                    if ($form -ne $null) { $form.Hide() }
                    
                    # 启动控制台模式
                    $consoleScriptPath = if ($script:selectedLanguage -eq "CHS" -and $chsScript -ne $null) { $chsScript } else { $engScript }
                    if ($consoleScriptPath -ne $null) {
                        Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$consoleScriptPath`"", "-GUI_Mode"
                    }
                    
                    # 退出主窗口
                    [System.Environment].Exit(0)
                } catch {}
            })
            $launchTimer.Start()
        }
    })

    # 支持无边框窗口拖拽
    $form.Add_Load({
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
})

    # 显示表单并添加窗口级动画
    Start-MainWindowAnimation -Form $form
    # 运行消息循环
    [System.Windows.Forms.Application]::Run($form)
    $form.Dispose()
}



# ====== PRO脚本运行窗口 - 多线程优化版 ======
function ShowProMode {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$Language
    )

    # 创建PRO模式窗口
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

    # 标题
    $proTitleLabel = New-Object System.Windows.Forms.Label
    $proTitleLabel.Text = $Title
    $proTitleLabel.Location = New-Object System.Drawing.Point(50, 15)
    $proTitleLabel.Size = New-Object System.Drawing.Size(650, 35)
    $proTitleLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 14, [System.Drawing.FontStyle]::Bold)
    $proTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $proTitleLabel.BackColor = [System.Drawing.Color]::Transparent
    $proTitleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $proTitleLabel.AutoSize = $false
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
    
    # 1. 指示标签
    $inputPanelLabel = New-Object System.Windows.Forms.Label
    if ($Language -eq "CHS") { $inputPanelLabel.Text = ">>> 终端指令输入" } else { $inputPanelLabel.Text = ">>> Terminal Input" }
    $inputPanelLabel.Location = New-Object System.Drawing.Point(50, 570)
    $inputPanelLabel.Size = New-Object System.Drawing.Size(250, 20)
    $inputPanelLabel.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
    $inputPanelLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
    $inputPanelLabel.BackColor = [System.Drawing.Color]::Transparent
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
        } else {
            # 普通高危操作授权
            $global:syncHash.Authorized = $true
            $global:syncHash.RequiresAuthorization = $false  # 强制清除请求标记，防止 UI 轮询重入
            
            # 💥 新增：添加调试日志
            if ($Language -eq "CHS") {
                $global:syncHash.LogOutput += "`n✅ 用户已授权，继续执行修复...`n"
            } else {
                $global:syncHash.LogOutput += "`n✅ User authorized, continuing execution...`n"
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
        } else {
            # 普通高危操作跳过
            $global:syncHash.Authorized = $false  # 💥 核心修复：设置 Authorized = false
            $global:syncHash.RequiresAuthorization = $false
            $global:syncHash.PendingCommand = $null
            
            if ($Language -eq "CHS") {
                $global:syncHash.LogOutput += "`n⚠️ 用户拒绝授权，操作已取消...`n"
            } else {
                $global:syncHash.LogOutput += "`n⚠️ User denied authorization, operation cancelled...`n"
            }
            
            # 菜单重新打印由后台脚本处理，这里只更新状态文本
            $statusText = if ($Language -eq "CHS") { "等待输入" } else { "Waiting for input" }
            Update-StarfieldStatusText -Panel $proBackground -NewText $statusText
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
        
        # 设置重新开始标志（使用syncHash中已存储的数据）
        $global:syncHash.SessionRestarted = $true
        
        if ($Language -eq "CHS") {
            $global:syncHash.LogOutput += "🔄 已清除旧会话，将开始新任务`n"
        } else {
            $global:syncHash.LogOutput += "🔄 Old session cleared, starting new task`n"
        }
    }.GetNewClosure())



    # 定义追加输出的函数
    function global:Append-Output {
        param([string]$Text)
        if ($Text) {
            try {
                $consoleBox.AppendText($Text)
                $consoleBox.ScrollToCaret()
            } catch {}
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
                } catch {}
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
            } catch {}

            $proExitTimer1 = New-Object System.Windows.Forms.Timer
            $proExitTimer1.Interval = 500 # 先等UWP控件退出动画完成
            $proExitTimer1.Tag = @{ ProForm = $targetProForm }
            $proExitTimer1.Add_Tick({
                $timer = $this
                $data = $timer.Tag
                $timer.Stop(); $timer.Dispose()
                
                # 播放二级窗口级退出动画（同步阻塞450ms）
                if ($null -ne $data.ProForm -and -not $data.ProForm.IsDisposed) {
                    try { Start-MainWindowExitAnimation -Form $data.ProForm } catch {}
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
        if ($null -ne $uiTimer) { try { $uiTimer.Stop() } catch {} }
        
        # 2. 通知后台 Runspace 立即自尽
        try {
            if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
                $global:syncHash.IsHostAlive = $false
            }
        } catch {}
        
        # 3. ====== 核心修复：只 Stop，不 Dispose，防止抛出访问异常 ======
        if ($global:ActivePS) { 
            try { $global:ActivePS.Stop() } catch {}
        }
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
        [System.Windows.Forms.Application]::DoEvents()

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
                    . "$scriptDir\AURORA-ProgressManager.ps1"
                    
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
                        $global:syncHash.LogOutput += "💡 提示：右键点击 AURORA.Launcher-双击启动.exe，选择'以管理员身份运行'可获取完整权限`n"
                    }
                } else {
                    if ($global:syncHash.IsAdmin) {
                        $global:syncHash.LogOutput += "✅ Administrator Privileges: Granted - All features available`n"
                    } else {
                        $global:syncHash.LogOutput += "⚠️ Administrator Privileges: Not Granted - Some features limited`n"
                        $global:syncHash.LogOutput += "💡 Hint: Right-click AURORA.Launcher-双击启动.exe and select 'Run as administrator' for full access`n"
                    }
                }
                
                # 提取 GUI 控件参数 
                $guiParams = @{
                    LogType = ""; Level = ""; EventId = ""; ProviderName = ""; StartTime = $null; EndTime = $null
                }
                
                $workDir = Split-Path -Path $ScriptPath -Parent

                # ==========================================
                # 优化：快速创建后台 Runspace
                # ==========================================
                $runspace = [runspacefactory]::CreateRunspace()
                $runspace.ApartmentState = "STA"  # 改为STA以更好地支持启动Windows GUI应用程序
                $runspace.ThreadOptions = "ReuseThread"
                $runspace.Open()
                
                $ps = [powershell]::Create().AddScript({
                    param($path, $workingDirectory, $paramsFromGUI, $hash, $Language, $PerfTier)
                    try {
                        $global:syncHash = $hash
                        function global:Write-Host {
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
                $proProgressBar.Value = 100
                $actionButton.Enabled = $true
            }
        })
        $engineInitTimer.Start()
    })

    # ====== 新增：在窗体显示前隐藏所有动效控件，彻底消除第一帧的闪烁 ======
    $animControls = @($proTitleLabel, $consoleBox, $proProgressBar, $inputPanelLabel, $inputTextBox, $sendButton, $hintLabel, $actionButton)
    foreach ($c in $animControls) { if ($null -ne $c) { $c.Visible = $false } }



    # ====== 核心修复：确保窗体初始完全透明，完美承接主窗口淡入动效 ======
    $proForm.Opacity = 0.0

    # 运行消息循环
    $proForm.Visible = $true
    [System.Windows.Forms.Application]::DoEvents()
    while ($proForm.Visible) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 50
    }

    # 清理
    $uiTimer.Stop()
    $uiTimer.Dispose()
    
    if ($global:ActivePS -and -not $global:ActivePS.IsCompleted) {
        try { $global:ActivePS.Stop() } catch {}
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
}

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
    } catch {}
}

function global:Restore-ControlState {
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
    } catch {}
}

function global:Stop-AllAnimations {
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
            } catch {}
        }
        
        # 如果指定了 Control，更新数组保留其他动画
        if ($PSBoundParameters.ContainsKey('Control')) {
            $Global:AnimationTimers = $newTimers
        } else {
            # 否则清空数组
            $Global:AnimationTimers = @()
        }
    } catch {}
}


function global:Start-UwpEnterAnimation {
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
    $Control.ForeColor = [System.Drawing.Color]::FromArgb(0, $originalForeColor.R, $originalForeColor.G, $originalForeColor.B)
    
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
            $data.Control.ForeColor = $data.OriginalForeColor
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
        $data.Control.ForeColor = [System.Drawing.Color]::FromArgb($alpha, $data.OriginalForeColor.R, $data.OriginalForeColor.G, $data.OriginalForeColor.B)
    }.GetNewClosure())
    $timer.Start()
    
    # 添加到全局动画列表
    $Global:AnimationTimers += $timer
}

function global:Start-UwpExitAnimation {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Control,
        [int]$DurationMs = 350,
        [float]$EndScale = 0.8
    )

    $originalLocation = $Control.Location
    $originalSize = $Control.Size
    $originalForeColor = $Control.ForeColor
    $originalVisible = $Control.Visible

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16

    $timer.Tag = @{
        Control = $Control; OriginalLocation = $originalLocation; OriginalSize = $originalSize
        OriginalForeColor = $originalForeColor; OriginalVisible = $originalVisible
        EndScale = $EndScale; DurationMs = $DurationMs
        StartTime = [DateTime]::Now; HasStarted = $false
    }

    $timer.add_Tick({
        $currentTimer = $this
        $data = $currentTimer.Tag
        $now = [DateTime]::Now

        if (-not $data.HasStarted) {
            $data.HasStarted = $true
            $data.RealStartTime = $now
        }

        $elapsed = ($now - $data.RealStartTime).TotalMilliseconds
        $progress = [Math]::Min(1.0, $elapsed / $data.DurationMs)

        if ($progress -ge 1.0) {
            $data.Control.Visible = $false
            $data.Control.Location = $data.OriginalLocation
            $data.Control.Size = $data.OriginalSize
            $data.Control.ForeColor = $data.OriginalForeColor
            $currentTimer.Stop()
            return
        }

        $eased = [Math]::Pow(1 - $progress, 4)

        $scale = 1.0 - ((1.0 - $data.EndScale) * (1 - $eased))
        
        $newWidth = [int]($data.OriginalSize.Width * $scale)
        $newHeight = [int]($data.OriginalSize.Height * $scale)
        if ($newWidth -lt 1) { $newWidth = 1 }
        if ($newHeight -lt 1) { $newHeight = 1 }

        $targetCenterX = $data.OriginalLocation.X + ($data.OriginalSize.Width / 2)
        $targetCenterY = $data.OriginalLocation.Y + ($data.OriginalSize.Height / 2)

        $data.Control.Location = New-Object System.Drawing.Point([int]($targetCenterX - ($newWidth / 2)), [int]($targetCenterY - ($newHeight / 2)))
        $data.Control.Size = New-Object System.Drawing.Size($newWidth, $newHeight)

        $alpha = [int][Math]::Max(0, 255 * $eased)
        $data.Control.ForeColor = [System.Drawing.Color]::FromArgb($alpha, $data.OriginalForeColor.R, $data.OriginalForeColor.G, $data.OriginalForeColor.B)
    }.GetNewClosure())
    $timer.Start()

    # 添加到全局动画列表
    $Global:AnimationTimers += $timer
}

# ===================================================================
# === UWP 输入框底边丝滑动画 - 从中心向两侧展开/收起 ===
# ===================================================================
function global:Start-UnderlineAnimation {
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
    param([System.Windows.Forms.Form]$Form)
    
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
            if ($null -ne $data.Form -and -not $data.Form.IsDisposed) {
                try { $data.Form.Opacity = 0 } catch {}
            }
            $this.Stop()
            $this.Dispose()
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
                exit 0
            } else {
                Write-Host "⚠️ 提权失败或被取消，将继续以普通用户模式运行" -ForegroundColor Yellow
            }
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
    exit 1
}
