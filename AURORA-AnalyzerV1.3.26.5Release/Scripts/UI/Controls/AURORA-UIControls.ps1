<#
.SYNOPSIS
    AURORA UI 控件库
.DESCRIPTION
    无边框窗口拖拽支持、自定义 UI 控件等
.NOTES
    版本：V1.3.26.5Release | 构建时间：2026.06.08
    作者：AURORA VelociRaptor-GR Dev PRJ.
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
# 引用 AURORA-AnimationCoreEngine 程序集
$guiCsharpCode = @'

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
// =============== AURORA PROGRESS BAR ===============
// 特性：
// - 圆角轨道 + 青绿色渐变填充
// - 动态光晕扫过进度区域（PathGradientBrush 实现）
// - 粒子系统：随光晕生成白色发光粒子，带生命周期与随机漂移
// - 高性能双缓冲绘制，避免闪烁

public class AuroraProgressBar : Control {
    // --- 字段定义 ---
    private float _value = 0;               // 目标进度值
    private float _displayProgress = 0;     // 显示进度值（平滑过渡目标）
    private float _progressAnimSpeed = 0.12f; // 进度平滑过渡速度
    private float _minimum = 0;             // 最小值
    private float _maximum = 100;           // 最大值
    private Color _trackColor = Color.FromArgb(100, 60, 100, 160); // 轨道背景色（深空蓝）
    private int _cornerRadius = 8;        // 圆角半径
    private List<Particle> _particles = new List<Particle>(); // 粒子列表
    private Random _rand = new Random();  // 随机数生成器
    private float _glowPosition = -0.3f;  // 光晕当前位置（归一化坐标，-0.3 表示起始于左侧外）
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
        // 动画由全局 AURORA_Animation 引擎驱动
        AURORA_Animation.Add(new LoopAnimation(() => { UpdateAnimation(); Invalidate(); }));
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
            if (this.Region != null) {
                this.Region.Dispose();
            }
        }
        base.Dispose(disposing);
    }

    // --- 动画更新逻辑：移动光晕 + 平滑进度 + 生成/老化粒子 ---
    private void UpdateAnimation() {
        try {
            // 平滑过渡显示进度
            float range = Math.Max(1, _maximum - _minimum);
            float targetProgress = (float)(_value - _minimum) / range;
            float diff = targetProgress - _displayProgress;
            if (Math.Abs(diff) > 0.0005f)
            {
                _displayProgress += diff * _progressAnimSpeed;
                if (Math.Abs(diff) < 0.001f) _displayProgress = targetProgress;
            }

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

            // === 粒子生成优化点 1：最多允许 40 个粒子（原为 15）===
            if (AuroraRenderEngine.EnableParticleSystem && _displayProgress > 0 && _rand.NextDouble() < 0.85 && _particles.Count < 40) {
                if (ClientRectangle.Width > 0 && ClientRectangle.Height > 0) {
                    float w = ClientRectangle.Width;
                    float glowX = _glowPosition * w;
                    float filledWidth = w * _displayProgress;
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

            // 更新所有粒子状态
            foreach (var p in _particles) {
                p.Age += 0.0267f; // 每帧增加年龄
                // 微小随机漂移（模拟流体扰动）
                p.X += (float)(_rand.NextDouble() * 0.4 - 0.2);
                p.Y += (float)(_rand.NextDouble() * 0.3 - 0.15);
            }
            // 一次性移除所有超龄粒子（O(n) 总复杂度）
            _particles.RemoveAll(p => p.Age >= p.Lifetime);
        } catch { /* non-critical */ }
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

        // 2. 绘制进度填充（青绿三色渐变）- 使用平滑显示进度
        float range = Math.Max(1, _maximum - _minimum);
        float progress = _displayProgress;
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
// - 动画由 AURORA-AnimationCoreEngine 统一驱动

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

public class TechButton : Control, IAnimatable, System.Windows.Forms.IButtonControl
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
    private List<Animation> _myAnimations = new List<Animation>();
    private DateTime _lastClickTime = DateTime.MinValue;
    private const int ClickCooldown = 500; // 点击冷却时间，单位：毫秒
    private bool _isProcessingClick = false; // 标记是否正在处理点击事件，防止超快速点击

    // --- 涟漪效果 (Ripple) ---
    private List<Ripple> _ripples = new List<Ripple>();

    // --- 磁吸效果 (Magnetic Snap) ---
    private Point _baseLocation;  // 磁吸归位时的基准位置（动态更新，视图切换后会自动同步）
    private float _magneticOffsetX = 0f;
    private float _magneticOffsetY = 0f;
    private float _magneticTargetX = 0f;  // 目标偏移（平滑过渡用）
    private float _magneticTargetY = 0f;
    private const float MAGNETIC_RADIUS = 135f;  // 增大感应半径120f
    private const float MAGNETIC_STRENGTH = 0.35f;  // 磁力强度0.25f
    private const float MAGNETIC_SMOOTH = 0.08f;  // 平滑系数（降低至0.08，使磁吸位移更柔和、过渡更顺滑）
    private const float MAGNETIC_MAX_OFFSET = 17.5f;  // 最大磁吸偏移量（像素）
    private bool _isInTransition = false;  // 视图切换动画期间禁用磁吸，防止冲突

    // 公开方法：供 PowerShell 在视图切换时调用，启用/禁用磁吸
    public void SetTransitionMode(bool inTransition)
    {
        _isInTransition = inTransition;
        if (inTransition)
        {
            // 进入过渡模式：立即清除所有磁吸偏移
            _magneticOffsetX = 0f;
            _magneticOffsetY = 0f;
            _magneticTargetX = 0f;
            _magneticTargetY = 0f;
        }
    }

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

        // 初始化状态机（动画由全局 AURORA_Animation 管理）
        _stateMachine = new ButtonStateMachine(this);
        
        // 初始化长按定时器
        _longPressTimer = new Timer { Interval = 500 };
        _longPressTimer.Tick += OnLongPressTimerTick;
        
        // 初始化时设置控件区域
        UpdateRegion();

        // 初始化涟漪动画循环
        AURORA_Animation.Add(new LoopAnimation(() => {
            bool needsRedraw = false;
            for (int i = _ripples.Count - 1; i >= 0; i--) {
                _ripples[i].Update(0.016f);
                if (_ripples[i].IsDead) _ripples.RemoveAt(i);
                needsRedraw = true;
            }
            if (needsRedraw) Invalidate();
        }));
    }

    // 在控件添加到父容器后记录基准位置
    protected override void OnParentChanged(EventArgs e)
    {
        base.OnParentChanged(e);
        if (this.Parent != null)
        {
            _baseLocation = this.Location;
        }
    }

    // 关键：每次位置被外部（PowerShell）修改时，同步更新基准位置
    // 只在磁吸偏移接近零时更新，避免恢复动画过程中的中间位置污染 _baseLocation
    protected override void OnLocationChanged(EventArgs e)
    {
        base.OnLocationChanged(e);
        
        // 关键修复：只在磁吸偏移接近零时才更新基准位置
        // 这确保恢复动画过程中不会污染 _baseLocation
        float currentMagOffset = (float)Math.Sqrt(_magneticOffsetX * _magneticOffsetX + _magneticOffsetY * _magneticOffsetY);
        if (currentMagOffset < 0.5f)
        {
            _baseLocation = this.Location;
        }
    }
    
    // IAnimatable 接口实现 — 供动画引擎通过属性名修改控件动画值
    public void SetAnimationValue(string propertyName, float value)
    {
        switch (propertyName)
        {
            case "glareProgress": _glareProgress = value; break;
        }
    }

    private void ClearMyAnimations()
    {
        foreach (var a in _myAnimations)
        {
            AURORA_Animation.Remove(a);
        }
        _myAnimations.Clear();
    }

    private void TrackAnimation(Animation a)
    {
        _myAnimations.Add(a);
    }

    private void StartGlareSweep()
    {
        if (!AuroraRenderEngine.EnableDynamicSweep) return;
        
        if (!_isGlareSweepRunning)
        {
            _isGlareSweepRunning = true;
            _glareProgress = -0.3f;
            var animation = new GlareSweepAnimation(this, "glareProgress", -0.3f, 1.3f, 1.5f, onComplete: () => { _isGlareSweepRunning = false; });
            AURORA_Animation.Add(animation);
            TrackAnimation(animation);
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
            AURORA_Animation.Add(animation);
            TrackAnimation(animation);
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
        AURORA_Animation.Add(hoverAnimation);
        TrackAnimation(hoverAnimation);
        
        // 启动扫光动画
        StartGlareSweep();
    }

    protected override void OnLostFocus(EventArgs e)
    {
        base.OnLostFocus(e);
        _stateMachine.TransitionTo(ButtonState.Normal);
        
        // 清除本按钮的动画，避免悬停动画与恢复动画冲突
        ClearMyAnimations();
        
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
        AURORA_Animation.Add(restoreAnimation);
        TrackAnimation(restoreAnimation);
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
        
        // 清除本按钮的动画，确保新的动画能够正确启动
        ClearMyAnimations();

        // 启动悬停动画
        var hoverAnimation = new FloatAnimation(0f, 1f, 0.3f, (value) => {
            _hoverProgress = value;
            _hoverColorProgress = value;
            _glowProgress = value;
            Invalidate();
        });
        AURORA_Animation.Add(hoverAnimation);
        TrackAnimation(hoverAnimation);
        
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
            var glareAnimation = new GlareSweepAnimation(this, "glareProgress", _glareProgress, 1.3f, 1.5f);
            AURORA_Animation.Add(glareAnimation);
            TrackAnimation(glareAnimation);
        }
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        _stateMachine.TransitionTo(ButtonState.Normal);
        
        // 清除本按钮的动画，避免悬停动画与恢复动画冲突
        // 这是解决快速移出时状态残留的关键
        ClearMyAnimations();

        // 即使鼠标移出，也要完成当前正在进行的扫光动画
        // 重新启动扫光动画，使用当前的进度值
        if (_isGlareSweepRunning && _glareProgress < 1.3f)
        {
            float remainingProgress = 1.3f - _glareProgress;
            float totalProgress = 1.3f - (-0.3f);
            float remainingDuration = (remainingProgress / totalProgress) * 1.5f; // 1.5f 是扫光动画的总时长
            
            var glareAnimation = new GlareSweepAnimation(this, "glareProgress", _glareProgress, 1.3f, remainingDuration);
            AURORA_Animation.Add(glareAnimation);
            TrackAnimation(glareAnimation);
        }

        // 磁吸恢复：使用 FloatAnimation 平滑回到原始位置（0.5s 更柔和的回弹）
        float currentMagX = _magneticOffsetX;
        float currentMagY = _magneticOffsetY;
        var magneticRestore = new FloatAnimation(0f, 1f, 0.5f, (value) => {
            _magneticOffsetX = currentMagX * (1f - value);
            _magneticOffsetY = currentMagY * (1f - value);
            if (this.Parent != null)
            {
                int newX = _baseLocation.X + (int)_magneticOffsetX;
                int newY = _baseLocation.Y + (int)_magneticOffsetY;
                if (this.Location.X != newX || this.Location.Y != newY)
                {
                    this.Location = new Point(newX, newY);
                }
            }
        }, EasingType.EaseOutCubic, () => {
            _magneticOffsetX = 0f;
            _magneticOffsetY = 0f;
            if (this.Parent != null)
            {
                this.Location = _baseLocation;
            }
        });
        AURORA_Animation.Add(magneticRestore);
        TrackAnimation(magneticRestore);
        
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
        AURORA_Animation.Add(restoreAnimation);
        TrackAnimation(restoreAnimation);
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);

        // 视图切换动画期间禁用磁吸效果，防止与进出动效冲突
        if (_isInTransition) return;

        float centerX = Width / 2f;
        float centerY = Height / 2f;
        float dx = e.X - centerX;
        float dy = e.Y - centerY;
        float dist = (float)Math.Sqrt(dx * dx + dy * dy);

        if (dist < MAGNETIC_RADIUS && dist > 1f)
        {
            // 使用更简单的磁力模型：越靠近中心磁力越强，偏移线性变化
            float attractionRatio = 1f - (dist / MAGNETIC_RADIUS);  // 0~1
            float rawOffset = attractionRatio * MAGNETIC_MAX_OFFSET;
            _magneticTargetX = (dx / dist) * rawOffset;
            _magneticTargetY = (dy / dist) * rawOffset;
        }
        else
        {
            _magneticTargetX = 0f;
            _magneticTargetY = 0f;
        }

        // 平滑过渡到目标偏移（Lerp 风格）
        _magneticOffsetX += (_magneticTargetX - _magneticOffsetX) * MAGNETIC_SMOOTH;
        _magneticOffsetY += (_magneticTargetY - _magneticOffsetY) * MAGNETIC_SMOOTH;

        // 关键：实际修改控件位置，而非仅变换绘制
        if (this.Parent != null)
        {
            int newX = _baseLocation.X + (int)_magneticOffsetX;
            int newY = _baseLocation.Y + (int)_magneticOffsetY;
            if (this.Location.X != newX || this.Location.Y != newY)
            {
                this.Location = new Point(newX, newY);
            }
        }
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        _stateMachine.TransitionTo(ButtonState.Press);
        _clickPoint = e.Location;
        _pressProgress = 0f;
        _pressStartTime = DateTime.Now;
        _isLongPress = false;
        
        // 启动长按检测前先重置，防止快速点击时状态不一致
        _longPressTimer.Stop();
        _longPressTimer.Start();

        // 如果当前有磁吸偏移，先释放磁吸，避免位移状态下点击导致闪烁
        float currentMagOffset = (float)Math.Sqrt(_magneticOffsetX * _magneticOffsetX + _magneticOffsetY * _magneticOffsetY);
        if (currentMagOffset > 0.5f)
        {
            float savedMagX = _magneticOffsetX;
            float savedMagY = _magneticOffsetY;
            // 快速回弹动画（0.15s 快速归位）
            var magneticRelease = new FloatAnimation(0f, 1f, 0.15f, (value) => {
                _magneticOffsetX = savedMagX * (1f - value);
                _magneticOffsetY = savedMagY * (1f - value);
                if (this.Parent != null)
                {
                    int newX = _baseLocation.X + (int)_magneticOffsetX;
                    int newY = _baseLocation.Y + (int)_magneticOffsetY;
                    if (this.Location.X != newX || this.Location.Y != newY)
                    {
                        this.Location = new Point(newX, newY);
                    }
                }
                Invalidate();
            }, EasingType.EaseOutCubic, () => {
                _magneticOffsetX = 0f;
                _magneticOffsetY = 0f;
                _magneticTargetX = 0f;
                _magneticTargetY = 0f;
                if (this.Parent != null)
                {
                    this.Location = _baseLocation;
                }
            });
            AURORA_Animation.Add(magneticRelease);
            TrackAnimation(magneticRelease);
        }
        
        // 启动按下动画
        var pressAnimation = new FloatAnimation(0f, 1f, 0.2f, (value) => {
            _pressProgress = value;
            Invalidate();
        });
        AURORA_Animation.Add(pressAnimation);
        TrackAnimation(pressAnimation);

        // 创建涟漪效果
        if (_stateMachine.CurrentState != ButtonState.Disabled &&
            _stateMachine.CurrentState != ButtonState.Loading)
        {
            float maxRadius = Math.Max(Width, Height) * 1.5f;
            _ripples.Add(new Ripple(e.Location, maxRadius));
        }
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

        // === 6. 内部高光：横向柔光带 ===
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

    // === 7.5. 绘制涟漪效果 ===
    if (_ripples.Count > 0)
    {
        foreach (var ripple in _ripples)
        {
            Color rippleColor = Color.FromArgb(
                (int)(ripple.Alpha * 80), 200, 255, 255);
            using (var rippleBrush = new SolidBrush(rippleColor))
            {
                g.FillEllipse(rippleBrush,
                    ripple.Origin.X - ripple.Radius,
                    ripple.Origin.Y - ripple.Radius,
                    ripple.Radius * 2,
                    ripple.Radius * 2);
            }
        }
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

    // --- 涟漪类 (Ripple) ---
    private class Ripple
    {
        public PointF Origin;
        public float Radius;
        public float MaxRadius;
        public float Alpha;
        public float Age;
        public float Lifetime;

        public Ripple(PointF origin, float maxRadius)
        {
            Origin = origin;
            MaxRadius = maxRadius;
            Radius = 0f;
            Alpha = 1.0f;
            Age = 0f;
            Lifetime = 1.2f;  // 从 0.6s 延长到 1.2s，使涟漪扩散更慢更有仪式感
        }

        public void Update(float deltaTime)
        {
            Age += deltaTime;
            float progress = Age / Lifetime;
            float eased = 1 - (float)Math.Pow(1 - progress, 3);
            Radius = eased * MaxRadius;
            Alpha = 1f - progress;
        }

        public bool IsDead { get { return Age >= Lifetime; } }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
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
    private float _breathingValue = 0f;
    private float _breathingSpeed = 0.05f;

    // V2.0 状态图标动画
    private float _iconAnimProgress = 0f;
    private bool _showIconAnim = false;
    private int _iconAnimStepIndex = -1;

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

        // 动画由全局 AURORA_Animation 引擎驱动
        AURORA_Animation.Add(new LoopAnimation(() =>
        {
            _breathingValue += _breathingSpeed;
            if (_breathingValue > Math.PI * 2) _breathingValue -= (float)(Math.PI * 2);

            // V2.0 图标动画更新
            if (_showIconAnim)
            {
                _iconAnimProgress += 0.04f;
                if (_iconAnimProgress >= 1f)
                {
                    _showIconAnim = false;
                    _iconAnimProgress = 0f;
                }
            }

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
        }));
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
            TaskState oldState = task.State;
            task.State = state;

            // V2.0 触发图标动画
            if (oldState != state && (state == TaskState.Success || state == TaskState.Error))
            {
                _showIconAnim = true;
                _iconAnimProgress = 0f;
                _iconAnimStepIndex = stepIndex;
            }
            
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
                    bool animSuccess = (_showIconAnim && _iconAnimStepIndex == i);
                    if (animSuccess)
                    {
                        float eased = 1f - (float)Math.Pow(1f - _iconAnimProgress, 3);
                        float animSize = 10f * eased;
                        float animX = nodeX - animSize / 2;
                        float animY = nodeY - animSize / 2;
                        using (var coreBrush = new SolidBrush(Color.FromArgb(255, 109, 249, 75)))
                            g.FillEllipse(coreBrush, animX, animY, animSize, animSize);
                        float ringAlpha = (1f - _iconAnimProgress) * 120;
                        if (ringAlpha > 10) {
                            float ringSize = animSize * (2f - _iconAnimProgress);
                            using (var ringPen = new Pen(Color.FromArgb((int)ringAlpha, 109, 249, 75), 2f))
                                g.DrawEllipse(ringPen, nodeX - ringSize/2, nodeY - ringSize/2, ringSize, ringSize);
                        }
                    }
                    else
                    {
                        using (var coreBrush = new SolidBrush(Color.FromArgb(255, 109, 249, 75))) g.FillEllipse(coreBrush, nodeX - 5, nodeY - 5, 10, 10);
                        using (var ringPen = new Pen(Color.FromArgb(120, 109, 249, 75), 2)) g.DrawEllipse(ringPen, nodeX - 8, nodeY - 8, 16, 16);
                    }
                    break;
                case TaskState.Error:
                    bool animError = (_showIconAnim && _iconAnimStepIndex == i);
                    if (animError)
                    {
                        float eased = 1f - (float)Math.Pow(1f - _iconAnimProgress, 3);
                        float animSize = 10f * eased;
                        float shake = (float)Math.Sin(_iconAnimProgress * Math.PI * 6) * (1f - _iconAnimProgress) * 3f;
                        float animX = nodeX - animSize / 2 + shake;
                        float animY = nodeY - animSize / 2;
                        using (var coreBrush = new SolidBrush(Color.FromArgb(255, 255, 80, 80)))
                            g.FillEllipse(coreBrush, animX, animY, animSize, animSize);
                        float ringAlpha = (1f - _iconAnimProgress) * 150;
                        if (ringAlpha > 10) {
                            float ringSize = animSize * (2f - _iconAnimProgress);
                            using (var ringPen = new Pen(Color.FromArgb((int)ringAlpha, 255, 80, 80), 2f))
                                g.DrawEllipse(ringPen, nodeX - ringSize/2, nodeY - ringSize/2, ringSize, ringSize);
                        }
                    }
                    else
                    {
                        using (var coreBrush = new SolidBrush(Color.FromArgb(255, 255, 80, 80))) g.FillEllipse(coreBrush, nodeX - 5, nodeY - 5, 10, 10);
                        using (var ringPen = new Pen(Color.FromArgb(150, 255, 80, 80), 2)) g.DrawEllipse(ringPen, nodeX - 8, nodeY - 8, 16, 16);
                    }
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
    protected override void Dispose(bool disposing) { base.Dispose(disposing); }
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

    private ModalAnimationState _animState;
    private float _modalTransProgress = 1f;
    private static readonly float MODAL_TRANS_SPEED = 0.05f;
    
    // Emoji 字体支持
    private Font _textFont;
    private Font _emojiFont;
    // 缓存按钮字体，避免每次绘制时重复创建
    private Font _buttonFont;

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
        using (SolidBrush textBrush = new SolidBrush(Color.White))
        {
            StringFormat sf = new StringFormat
            {
                Alignment = StringAlignment.Center,
                LineAlignment = StringAlignment.Center
            };
            g.DrawString(text, _buttonFont, textBrush, scaledRect, sf);
        }
    }

    public AuroraResultModal()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        SetStyle(ControlStyles.SupportsTransparentBackColor, true);
        this.BackColor = Color.Transparent; 
        this.Dock = DockStyle.Fill;
        this.Visible = false;
        this.TabStop = true;

        // 初始化缓存字体
        try { _buttonFont = new Font("Microsoft YaHei UI", 10f, FontStyle.Bold); }
        catch { _buttonFont = new Font(FontFamily.GenericSansSerif, 10f, FontStyle.Bold); }
        
        _animState = new ModalAnimationState(1);
        AURORA_Animation.Add(new ModalTimerAnimation(_animState, (s) =>
        {
            if (s.FadeState == ModalFadeState.Hidden) { this.Visible = false; return; }

            // 虚拟按钮独立缓动逻辑 (Hover & Press)
            float btnSpeed = 0.12f;
            _closeHoverProg = Math.Max(0f, Math.Min(1f, _closeHoverProg + (_isCloseHovered ? btnSpeed : -btnSpeed)));
            _closePressProg = Math.Max(0f, Math.Min(1f, _closePressProg + (_isClosePressed ? btnSpeed : -btnSpeed)));
            
            // UWP标题切换动画 - 等待入场动效完成后再播放
            if (s.FadeState == ModalFadeState.Idle || s.FadeState == ModalFadeState.FadingOut) {
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
            }

            // V2.0 过渡动画进度
            if (s.FadeState == ModalFadeState.FadingIn)
                _modalTransProgress = Math.Min(1f, _modalTransProgress + MODAL_TRANS_SPEED);
            else if (s.FadeState == ModalFadeState.FadingOut)
                _modalTransProgress = Math.Max(0f, _modalTransProgress - MODAL_TRANS_SPEED);

            Invalidate();
        }));

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
        _animState.FadeState = ModalFadeState.FadingIn;
        _animState.GlobalAlpha = 0f;
        _modalTransProgress = 0f;
        this.Focus(); // 让控件获取焦点，键盘事件才能生效
    }

    public void FadeOutModal() {
        _animState.FadeState = ModalFadeState.FadingOut;
    }

    // V2.0 计算过渡变换
    private void ApplyTransitionTransform(Graphics g)
    {
        float eased = 1f - (float)Math.Pow(1f - _modalTransProgress, 3);
        float offsetX = 0f, offsetY = 0f, scale = 1f;

        switch (0) // SlideUp
        {
            default:
                offsetY = (1f - eased) * 200f;
                scale = 0.85f + eased * 0.15f;
                break;
        }

        if (Math.Abs(offsetX) > 0.1f || Math.Abs(offsetY) > 0.1f || Math.Abs(scale - 1f) > 0.001f)
        {
            g.TranslateTransform(offsetX, offsetY);
            float cx = ClientRectangle.Width / 2f;
            float cy = ClientRectangle.Height / 2f;
            g.TranslateTransform(cx, cy);
            g.ScaleTransform(scale, scale);
            g.TranslateTransform(-cx, -cy);
        }
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

        // 全屏暗化遮罩（在变换之前绘制，确保完整覆盖）
        using (var dimBrush = new SolidBrush(Color.FromArgb((int)(180 * _animState.GlobalAlpha), 5, 8, 15))) { g.FillRectangle(dimBrush, ClientRectangle); }

        // V2.0 过渡变换 (滑入+缩放，只作用于面板内容)
        try { ApplyTransitionTransform(g); } catch { /* non-critical */ }

        int pW = 700;
        // 使用 ease-out 缓动算法计算当前的展开比例
        float unfoldEased = 1f - (float)Math.Pow(1f - _animState.GlobalAlpha, 3);
        // 高度随透明度动态展开，最小4px防止GDI+崩溃
        int currentHeight = Math.Max(4, (int)(600 * unfoldEased));
        int pX = (this.Width - pW) / 2;
        int pY = (this.Height - currentHeight) / 2;
        Rectangle pRect = new Rectangle(pX, pY, pW, currentHeight);

        // 中央面板
        using (var path = CreateRoundedRect(pRect, 16)) {
            using (var bgBrush = new SolidBrush(Color.FromArgb((int)(240 * _animState.GlobalAlpha), 15, 20, 35))) { g.FillPath(bgBrush, path); }
            float pulse = 1.0f + 0.5f * (float)Math.Sin(_animState.GlobalPhase);
            int alpha = (int)((100 + 50 * pulse) * _animState.GlobalAlpha);
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
                int alpha = (int)(255 * (1f - eased) * _animState.GlobalAlpha);
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
                int alpha = (int)(255 * eased * _animState.GlobalAlpha);
                if (alpha > 0) {
                    using (var brush = new SolidBrush(Color.FromArgb(alpha, 100, 200, 255))) {
                        DrawTextWithEmoji(g, _titleNext, drawX, pY + 20, brush, titleFont);
                    }
                }
            } else if (_titleTransitionState == TextTransitionState.Idle) {
                // 静态时的标题
                float drawX = pX + pW / 2f - g.MeasureString(_titleCurrent, titleFont).Width / 2f;
                using (var titleBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 100, 200, 255))) {
                    using (var glowBrush = new SolidBrush(Color.FromArgb((int)(100 * _animState.GlobalAlpha), 100, 200, 255))) {
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
        using (var linePen = new Pen(Color.FromArgb((int)(80 * _animState.GlobalAlpha), 255, 255, 255), 1)) { g.DrawLine(linePen, pX + 30, pY + 65, pX + pW - 30, pY + 65); }

        // 操作名称 - 优化布局
        int textX = pX + 30; int actY = pY + 85;
        using (var contentFont = new Font("Microsoft YaHei UI", 11, FontStyle.Bold))
        using (var contentBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 255, 255, 255))) {
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
        using (var resultBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), isSuccess ? 109 : 255, isSuccess ? 249 : 100, isSuccess ? 75 : 100))) {
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
        using (var timeBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 180, 180, 180))) {
            g.DrawString(GetTimeLabel() + _executionTime, timeFont, timeBrush, textX, timeY);
        }

        // 输出内容
        int outputY = timeY + 20;
        int outputHeight = Math.Max(1, currentHeight - (outputY - pY) - 60); // 核心修复：防止高度为负数导致 GDI+ FillRectangle 崩溃
        OutputAreaRect = new Rectangle(pX + 25, outputY, pW - 50, outputHeight);
        
        using (var outputFont = new Font("Consolas", 9))
        using (var outputBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 200, 200, 200))) {
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
            using (var scrollBarBgBrush = new SolidBrush(Color.FromArgb((int)(100 * _animState.GlobalAlpha), 50, 50, 70))) {
                g.FillRectangle(scrollBarBgBrush, scrollBarX, scrollBarY, scrollBarWidth, scrollBarHeight);
            }
            
            // 计算滚动条滑块高度和位置
            int sliderHeight = Math.Max(20, (int)((float)scrollBarHeight * (float)outputHeight / (outputHeight + _maxScrollOffset)));
            int sliderY = scrollBarY + (int)((float)(scrollBarHeight - sliderHeight) * (float)_scrollOffset / _maxScrollOffset);
            
            // 绘制滚动条滑块
            using (var sliderBrush = new SolidBrush(Color.FromArgb((int)(200 * _animState.GlobalAlpha), 100, 150, 200))) {
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
            if (_textFont != null) { _textFont.Dispose(); }
            if (_emojiFont != null) { _emojiFont.Dispose(); }
            if (_buttonFont != null) { _buttonFont.Dispose(); }
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

    private ModalAnimationState _animState;
    private float _modalTransProgress = 1f;
    private static readonly float DECISION_TRANS_SPEED = 0.05f;
    
    // Emoji 字体支持
    private Font _textFont;
    private Font _emojiFont;
    private Font _buttonFont;

    public event EventHandler OnAuthorize;
    public event EventHandler OnSkip;

    public AuroraDecisionModal()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        SetStyle(ControlStyles.SupportsTransparentBackColor, true);
        this.BackColor = Color.Transparent; 
        this.Dock = DockStyle.Fill;
        this.Visible = false;
        this.TabStop = true;

        // 初始化缓存字体
        try { _buttonFont = new Font("Microsoft YaHei UI", 10f, FontStyle.Bold); }
        catch { _buttonFont = new Font(FontFamily.GenericSansSerif, 10f, FontStyle.Bold); }
        
        _animState = new ModalAnimationState(2);
        AURORA_Animation.Add(new ModalTimerAnimation(_animState, (s) =>
        {
            if (s.FadeState == ModalFadeState.Hidden) { this.Visible = false; return; }

            // 1. 标题 UWP 文字滑动逻辑 - 等待入场动效完成后再播放
            if (s.FadeState == ModalFadeState.Idle || s.FadeState == ModalFadeState.FadingOut) {
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
            }

            // 3. 虚拟按钮独立缓动逻辑 (Hover & Press)
            float btnSpeed = 0.12f;
            _authHoverProg = Math.Max(0f, Math.Min(1f, _authHoverProg + (_isAuthHovered ? btnSpeed : -btnSpeed)));
            _skipHoverProg = Math.Max(0f, Math.Min(1f, _skipHoverProg + (_isSkipHovered ? btnSpeed : -btnSpeed)));
            _authPressProg = Math.Max(0f, Math.Min(1f, _authPressProg + (_isAuthPressed ? btnSpeed : -btnSpeed)));
            _skipPressProg = Math.Max(0f, Math.Min(1f, _skipPressProg + (_isSkipPressed ? btnSpeed : -btnSpeed)));

            // V2.0 过渡动画进度
            if (s.FadeState == ModalFadeState.FadingIn)
                _modalTransProgress = Math.Min(1f, _modalTransProgress + DECISION_TRANS_SPEED);
            else if (s.FadeState == ModalFadeState.FadingOut)
                _modalTransProgress = Math.Max(0f, _modalTransProgress - DECISION_TRANS_SPEED);

            Invalidate();
        }));

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
        _animState.FadeState = ModalFadeState.FadingIn;
        _animState.GlobalAlpha = 0f;
        _modalTransProgress = 0f;
        _isAuthHovered = true; // 默认聚焦授权按钮
        this.Focus(); // 让控件获取焦点，键盘事件才能生效
    }

    public void FadeOutModal()
    {
        _animState.FadeState = ModalFadeState.FadingOut;
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

        // 全屏暗化遮罩（在变换之前绘制，确保完整覆盖）
        using (var dimBrush = new SolidBrush(Color.FromArgb((int)(180 * _animState.GlobalAlpha), 5, 8, 15))) { g.FillRectangle(dimBrush, ClientRectangle); }

        // V2.0 过渡变换（只作用于面板内容）
        try {
            float te = 1f - (float)Math.Pow(1f - _modalTransProgress, 3);
            float oy = (1f - te) * 200f;
            float ts = 0.85f + te * 0.15f;
            if (Math.Abs(oy) > 0.1f) { g.TranslateTransform(0, oy); }
            if (Math.Abs(ts - 1f) > 0.001f) {
                float cx = ClientRectangle.Width / 2f, cy = ClientRectangle.Height / 2f;
                g.TranslateTransform(cx, cy); g.ScaleTransform(ts, ts); g.TranslateTransform(-cx, -cy);
            }
        } catch { /* non-critical */ }

        int pW = 520;
        // 使用 ease-out 缓动算法计算当前的展开比例
        float unfoldEased = 1f - (float)Math.Pow(1f - _animState.GlobalAlpha, 3);
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
            using (var bgBrush = new SolidBrush(Color.FromArgb((int)(240 * _animState.GlobalAlpha), 15, 20, 35))) { g.FillPath(bgBrush, path); }
            float pulse = 1.0f + 0.5f * (float)Math.Sin(_animState.GlobalPhase);
            int alpha = (int)((100 + 50 * pulse) * _animState.GlobalAlpha);
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
                int alpha = (int)(255 * (1f - eased) * _animState.GlobalAlpha);
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
                int alpha = (int)(255 * eased * _animState.GlobalAlpha);
                if (alpha > 0) {
                    using (var brush = new SolidBrush(Color.FromArgb(alpha, riskColor.R, riskColor.G, riskColor.B))) {
                        DrawTextWithEmoji(g, _titleNext, drawX, pY + 20, brush, titleFont);
                    }
                }
            } else if (_titleTransitionState == TextTransitionState.Idle) {
                // 静态时的标题
                float drawX = pX + pW / 2f - g.MeasureString(_titleCurrent, titleFont).Width / 2f;
                using (var titleBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), riskColor.R, riskColor.G, riskColor.B))) {
                    DrawTextWithEmoji(g, _titleCurrent, drawX, pY + 20, titleBrush, titleFont);
                }
            }
        }
        using (var linePen = new Pen(Color.FromArgb((int)(80 * _animState.GlobalAlpha), 255, 255, 255), 1)) { g.DrawLine(linePen, pX + 30, pY + 65, pX + pW - 30, pY + 65); }

        int textX = pX + 30; int actY = pY + 85; int riskY = pY + 120;
        using (var contentFont = new Font("Microsoft YaHei UI", 11))
        using (var boldFont = new Font("Microsoft YaHei UI", 11, FontStyle.Bold)) {
            if ((_transitionState == TextTransitionState.FadingOut || _transitionState == TextTransitionState.Idle) && !string.IsNullOrEmpty(_actionName)) {
                float prog = _transitionState == TextTransitionState.FadingOut ? _transitionProgress : 0f;
                float eased = EaseInCubic(prog); float drawX = textX - (eased * 20f); int alpha = (int)(255 * (1f - eased) * _animState.GlobalAlpha);
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
                float prog = _transitionProgress; float eased = EaseOutCubic(prog); float drawX = textX + (20f * (1f - eased)); int alpha = (int)(255 * eased * _animState.GlobalAlpha);
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
            pgb.CenterColor = Color.FromArgb((int)((40 + easeHover * 20) * _animState.GlobalAlpha), 0, 0, 0);
            pgb.SurroundColors = new[] { Color.Transparent };
            g.FillPath(pgb, shadowPath);
        }

        // 3. 绘制发光外晕 (Hover 触发)
        if (easeHover > 0) {
            Rectangle glowRect = new Rectangle(rect.X - 6, rect.Y - 6, rect.Width + 12, rect.Height + 12);
            using (var glowPath = CreateRoundedRect(glowRect, 14))
            using (var pgb = new PathGradientBrush(glowPath)) {
                pgb.CenterColor = Color.FromArgb((int)(80 * easeHover * _animState.GlobalAlpha), baseColor);
                pgb.SurroundColors = new[] { Color.Transparent };
                g.FillPath(pgb, glowPath);
            }
        }

        // 4. 绘制主体玻璃渐变
        using (var path = CreateRoundedRect(rect, 8))
        {
            Color topColor = ColorLerp(Color.FromArgb((int)(80 * _animState.GlobalAlpha), baseColor), Color.FromArgb((int)(160 * _animState.GlobalAlpha), baseColor), easeHover);
            Color bottomColor = ColorLerp(Color.FromArgb((int)(30 * _animState.GlobalAlpha), baseColor), Color.FromArgb((int)(80 * _animState.GlobalAlpha), baseColor), easeHover);
            if (easePress > 0) {
                topColor = ColorLerp(topColor, Color.FromArgb((int)(60 * _animState.GlobalAlpha), baseColor), easePress);
                bottomColor = ColorLerp(bottomColor, Color.FromArgb((int)(20 * _animState.GlobalAlpha), baseColor), easePress);
            }

            using (var brush = new LinearGradientBrush(rect, topColor, bottomColor, LinearGradientMode.Vertical)) {
                g.FillPath(brush, path);
            }

            // [Press 反馈] 按下时的 CRT 扫描横向暗纹，加深物理阻尼与电子感
            if (easePress > 0) {
                Region oldClip = g.Clip;
                g.SetClip(path); // 核心：限制在圆角按钮内部，防止网格溢出

                using (var gridPen = new Pen(Color.FromArgb((int)(60 * easePress * _animState.GlobalAlpha), 0, 0, 0), 1f)) {
                    for (int scanY = rect.Y; scanY < rect.Bottom; scanY += 4) {
                        g.DrawLine(gridPen, rect.X, scanY, rect.Right, scanY);
                    }
                }

                g.Clip = oldClip; // 恢复裁剪区域，以免影响后面的边框和文字绘制
            }

            // 5. 呼吸发光边框
            if (easeHover > 0) {
                float pulse = 0.5f + 0.5f * (float)Math.Sin(_animState.GlobalPhase * 2f); // 加快呼吸频率
                using (var pen = new Pen(Color.FromArgb((int)(180 * easeHover * pulse * _animState.GlobalAlpha), Color.White), 1.5f)) {
                    g.DrawPath(pen, path);
                }
            } else {
                using (var pen = new Pen(Color.FromArgb((int)(100 * _animState.GlobalAlpha), baseColor), 1.2f)) { g.DrawPath(pen, path); }
            }

            // 6. 文字绘制
            using (var b = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), Color.White))) {
                StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
                g.DrawString(text, _buttonFont, b, rect, sf);
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
            if (_textFont != null) { _textFont.Dispose(); }
            if (_emojiFont != null) { _emojiFont.Dispose(); }
            if (_buttonFont != null) { _buttonFont.Dispose(); }
        }
        base.Dispose(disposing); 
    }
}

// ==================================================================================================================
// ====== 新增：AuroraExportedLogsModal 已导出日志确认 HUD 叠加层（复用 AuroraDecisionModal 视觉风格） ======
public class AuroraExportedLogsModal : Control
{
    private int _fileCount = 0;
    private int _fileAge = 0;
    private string _exportPath = "";
    private string[] _fileNames = new string[0];
    private string _language = "CHS";
    private bool _isCompletionPrompt = false;
    private string _completionPromptPath = "";
    
    // ====== 全局透明度状态 ======
    
    public Rectangle UseButtonRect { get; private set; }
    public Rectangle SkipButtonRect { get; private set; }
    
    // 虚拟按钮动效状态变量
    private bool _isUseHovered = false;
    private bool _isSkipHovered = false;
    private bool _isUsePressed = false;
    private bool _isSkipPressed = false;
    
    private float _useHoverProg = 0f;
    private float _skipHoverProg = 0f;
    private float _usePressProg = 0f;
    private float _skipPressProg = 0f;

    private ModalAnimationState _animState;
    private float _modalTransProgress = 1f;
    private static readonly float MODAL_TRANS_SPEED = 0.05f;
    
    private Font _textFont;
    private Font _emojiFont;
    private Font _buttonFont;

    public event EventHandler OnUse;
    public event EventHandler OnSkip;

    public AuroraExportedLogsModal()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        SetStyle(ControlStyles.SupportsTransparentBackColor, true);
        this.BackColor = Color.Transparent; 
        this.Dock = DockStyle.Fill;
        this.Visible = false;
        this.TabStop = true;

        // 初始化缓存字体
        try { _buttonFont = new Font("Microsoft YaHei UI", 10f, FontStyle.Bold); }
        catch { _buttonFont = new Font(FontFamily.GenericSansSerif, 10f, FontStyle.Bold); }
        
        _animState = new ModalAnimationState(2);
        AURORA_Animation.Add(new ModalTimerAnimation(_animState, (s) =>
        {
            if (s.FadeState == ModalFadeState.Hidden) { this.Visible = false; return; }

            // 按钮独立缓动逻辑
            float btnSpeed = 0.12f;
            _useHoverProg = Math.Max(0f, Math.Min(1f, _useHoverProg + (_isUseHovered ? btnSpeed : -btnSpeed)));
            _skipHoverProg = Math.Max(0f, Math.Min(1f, _skipHoverProg + (_isSkipHovered ? btnSpeed : -btnSpeed)));
            _usePressProg = Math.Max(0f, Math.Min(1f, _usePressProg + (_isUsePressed ? btnSpeed : -btnSpeed)));
            _skipPressProg = Math.Max(0f, Math.Min(1f, _skipPressProg + (_isSkipPressed ? btnSpeed : -btnSpeed)));

            // V2.0 过渡动画进度
            if (s.FadeState == ModalFadeState.FadingIn)
                _modalTransProgress = Math.Min(1f, _modalTransProgress + MODAL_TRANS_SPEED);
            else if (s.FadeState == ModalFadeState.FadingOut)
                _modalTransProgress = Math.Max(0f, _modalTransProgress - MODAL_TRANS_SPEED);

            Invalidate();
        }));

        this.MouseMove += (s, e) => {
            bool newUse = UseButtonRect.Contains(e.Location);
            bool newSkip = SkipButtonRect.Contains(e.Location);
            if (newUse != _isUseHovered || newSkip != _isSkipHovered) {
                _isUseHovered = newUse; _isSkipHovered = newSkip;
            }
        };

        this.MouseDown += (s, e) => {
            if (e.Button == MouseButtons.Left) {
                if (UseButtonRect.Contains(e.Location)) _isUsePressed = true;
                if (SkipButtonRect.Contains(e.Location)) _isSkipPressed = true;
            }
        };

        this.MouseUp += (s, e) => {
            if (e.Button == MouseButtons.Left) {
                if (_isUsePressed && UseButtonRect.Contains(e.Location) && OnUse != null) OnUse(this, EventArgs.Empty);
                if (_isSkipPressed && SkipButtonRect.Contains(e.Location) && OnSkip != null) OnSkip(this, EventArgs.Empty);
                _isUsePressed = false;
                _isSkipPressed = false;
            }
        };

        this.MouseLeave += (s, e) => { 
            _isUseHovered = false; _isSkipHovered = false; 
            _isUsePressed = false; _isSkipPressed = false;
        };
        
        this.KeyDown += (s, e) => {
            switch (e.KeyCode) {
                case Keys.Enter:
                case Keys.Space:
                    if (_isUseHovered && OnUse != null) OnUse(this, EventArgs.Empty);
                    else if (_isSkipHovered && OnSkip != null) OnSkip(this, EventArgs.Empty);
                    e.Handled = true;
                    break;
                case Keys.Escape:
                    if (OnSkip != null) OnSkip(this, EventArgs.Empty);
                    e.Handled = true;
                    break;
                case Keys.Tab:
                    if (e.Shift) {
                        if (_isUseHovered) {
                            _isUseHovered = false;
                            _isSkipHovered = true;
                        } else {
                            _isSkipHovered = false;
                            _isUseHovered = true;
                        }
                    } else {
                        if (_isUseHovered) {
                            _isUseHovered = false;
                            _isSkipHovered = true;
                        } else {
                            _isSkipHovered = false;
                            _isUseHovered = true;
                        }
                    }
                    Invalidate();
                    e.Handled = true;
                    break;
            }
        };
        
        _emojiFont = FontHelper.GetEmojiFont(11.0f);
        _textFont = FontHelper.GetSansSerifFont(11.0f);
    }

    public void FadeInModal()
    {
        this.Visible = true;
        _animState.FadeState = ModalFadeState.FadingIn;
        _animState.GlobalAlpha = 0f;
        _modalTransProgress = 0f;
        _isUseHovered = true;
        this.Focus();
    }

    public void FadeOutModal()
    {
        _animState.FadeState = ModalFadeState.FadingOut;
    }

    public void UpdateInfo(int fileCount, int fileAge, string exportPath, string[] fileNames, string lang) {
        _language = lang;
        _fileCount = fileCount;
        _fileAge = fileAge;
        _exportPath = exportPath;
        _fileNames = fileNames;
    }
    
    // ====== 完成提示模式 ======
    public bool IsCompletionPrompt { get { return _isCompletionPrompt; } }
    
    public void ShowCompletionPrompt(string exportPath, string lang) {
        _language = lang;
        _completionPromptPath = exportPath;
        _isCompletionPrompt = true;
        FadeInModal();
    }
    
    public void ResetCompletionMode() {
        _isCompletionPrompt = false;
        _completionPromptPath = "";
    }
    
    private float EaseOutCubic(float t) { return 1f - (float)Math.Pow(1f - t, 3); }

    private Color ColorLerp(Color c1, Color c2, float amount) {
        amount = Math.Max(0, Math.Min(1, amount));
        return Color.FromArgb(
            (int)(c1.A + (c2.A - c1.A) * amount), (int)(c1.R + (c2.R - c1.R) * amount),
            (int)(c1.G + (c2.G - c1.G) * amount), (int)(c1.B + (c2.B - c1.B) * amount)
        );
    }
    
    private string GetTitleText() {
        if (_isCompletionPrompt) {
            return _language == "CHS" ? "✅ 分析完成" : "✅ Analysis Complete";
        }
        return _language == "CHS" ? "📂 发现已导出的日志文件" : "📂 Exported Log Files Detected";
    }
    
    private string GetFileCountText() {
        if (_isCompletionPrompt) {
            return _language == "CHS" ? "所有分析任务已完成，结果已保存至 UserLogs 文件夹" : 
                                       "All analysis tasks completed. Results saved to UserLogs folder.";
        }
        if (_language == "CHS") {
            return string.Format("在 UserLogs 文件夹中发现 {0} 个已导出的日志文件（{1} 分钟前）", _fileCount, _fileAge);
        } else {
            return string.Format("Found {0} exported log file(s) in UserLogs folder ({1} minutes ago)", _fileCount, _fileAge);
        }
    }
    
    private string GetPathLabel() {
        return _language == "CHS" ? "路径：" : "Path: ";
    }
    
    private string GetFilesLabel() {
        return _language == "CHS" ? "文件：" : "Files: ";
    }
    
    private string GetQuestionText() {
        if (_isCompletionPrompt) {
            return _language == "CHS" ? "是否打开输出文件夹查看结果？" : 
                                       "Open output folder to view results?";
        }
        return _language == "CHS" ? 
            "是否使用这些已导出的文件进行分析？" : 
            "Use these exported files for analysis?";
    }
    
    private string GetUseButtonText() {
        if (_isCompletionPrompt) {
            return _language == "CHS" ? "是，打开文件夹 [ENTER]" : "Yes, Open Folder [ENTER]";
        }
        return _language == "CHS" ? "是，直接分析 [ENTER]" : "Yes, Analyze Now [ENTER]";
    }
    
    private string GetSkipButtonText() {
        if (_isCompletionPrompt) {
            return _language == "CHS" ? "否，关闭 [ESC]" : "No, Close [ESC]";
        }
        return _language == "CHS" ? "否，重新提取实时日志 [ESC]" : "No, Extract Live Logs [ESC]";
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;

        // 全屏暗化遮罩（在变换之前绘制，确保完整覆盖）
        using (var dimBrush = new SolidBrush(Color.FromArgb((int)(180 * _animState.GlobalAlpha), 5, 8, 15))) { g.FillRectangle(dimBrush, ClientRectangle); }

        // V2.0 过渡变换（只作用于面板内容）
        try {
            float te = 1f - (float)Math.Pow(1f - _modalTransProgress, 3);
            float oy = (1f - te) * 200f;
            float ts = 0.85f + te * 0.15f;
            if (Math.Abs(oy) > 0.1f) { g.TranslateTransform(0, oy); }
            if (Math.Abs(ts - 1f) > 0.001f) {
                float cx = ClientRectangle.Width / 2f, cy = ClientRectangle.Height / 2f;
                g.TranslateTransform(cx, cy); g.ScaleTransform(ts, ts); g.TranslateTransform(-cx, -cy);
            }
        } catch { /* non-critical */ }

        int pW = 560;
        float unfoldEased = 1f - (float)Math.Pow(1f - _animState.GlobalAlpha, 3);
        int panelBaseHeight = _isCompletionPrompt ? 220 : 280;
        int currentHeight = Math.Max(4, (int)(panelBaseHeight * unfoldEased));
        int pX = (this.Width - pW) / 2;
        int pY = (this.Height - currentHeight) / 2;
        Rectangle pRect = new Rectangle(pX, pY, pW, currentHeight);

        Color accentColor = Color.FromArgb(80, 180, 255);

        // 中央面板
        using (var path = CreateRoundedRect(pRect, 16)) {
            using (var bgBrush = new SolidBrush(Color.FromArgb((int)(240 * _animState.GlobalAlpha), 15, 20, 35))) { g.FillPath(bgBrush, path); }
            float pulse = 1.0f + 0.5f * (float)Math.Sin(_animState.GlobalPhase);
            int alpha = (int)((100 + 50 * pulse) * _animState.GlobalAlpha);
            using (var topHighlight = new LinearGradientBrush(pRect, Color.FromArgb(alpha, accentColor.R, accentColor.G, accentColor.B), Color.Transparent, LinearGradientMode.Vertical))
            using (var highlightPen = new Pen(topHighlight, 2f)) { g.DrawPath(highlightPen, path); }
        }

        // 标题
        using (var titleFont = new Font("Microsoft YaHei UI", 13, FontStyle.Bold)) {
            StringFormat sf = new StringFormat { Alignment = StringAlignment.Center };
            string title = GetTitleText();
            float drawX = pX + pW / 2f - g.MeasureString(title, titleFont).Width / 2f;
            using (var brush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), accentColor.R, accentColor.G, accentColor.B))) {
                DrawTextWithEmoji(g, title, drawX, pY + 20, brush, titleFont);
            }
        }
        
        using (var linePen = new Pen(Color.FromArgb((int)(80 * _animState.GlobalAlpha), 255, 255, 255), 1)) { g.DrawLine(linePen, pX + 30, pY + 65, pX + pW - 30, pY + 65); }

        // 内容文字
        int textX = pX + 30;
        int lineY = pY + 85;
        using (var contentFont = new Font("Microsoft YaHei UI", 10))
        using (var boldFont = new Font("Microsoft YaHei UI", 10, FontStyle.Bold)) {
            // 文件数量 / 完成提示
            string fileCountText = GetFileCountText();
            using (var brush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 200, 200, 255))) {
                DrawTextWithEmoji(g, fileCountText, textX, lineY, brush, contentFont);
            }
            lineY += 25;
            
            if (!_isCompletionPrompt) {
                // 路径（截断显示，避免超出对话框）—— 仅在非完成模式下显示
                string pathText = GetPathLabel() + _exportPath;
                float maxWidth = pW - textX - 30; // 留出右侧边距
                using (var brush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 180, 180, 180))) {
                    SizeF pathSize = g.MeasureString(pathText, contentFont);
                    if (pathSize.Width > maxWidth) {
                        // 路径太长，只显示最后两级目录
                        string shortPath = "...\\" + System.IO.Path.GetFileName(System.IO.Path.GetDirectoryName(_exportPath)) + "\\" + System.IO.Path.GetFileName(_exportPath);
                        pathText = GetPathLabel() + shortPath;
                    }
                    g.DrawString(pathText, contentFont, brush, new PointF(textX, lineY));
                }
                lineY += 22;
            }
            
            // 问题
            string questionText = GetQuestionText();
            using (var brush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 255, 220, 100))) {
                DrawTextWithEmoji(g, questionText, textX, lineY, brush, boldFont);
            }
        }

        // 按钮坐标
        int btnW = 200; int btnH = 45;
        UseButtonRect = new Rectangle(pX + 40, pY + currentHeight - 65, btnW, btnH);
        SkipButtonRect = new Rectangle(pX + pW - btnW - 40, pY + currentHeight - 65, btnW, btnH);

        DrawAdvancedVirtualButton(g, UseButtonRect, GetUseButtonText(), Color.FromArgb(20, 180, 100), _useHoverProg, _usePressProg);
        DrawAdvancedVirtualButton(g, SkipButtonRect, GetSkipButtonText(), Color.FromArgb(180, 50, 50), _skipHoverProg, _skipPressProg);
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
            pgb.CenterColor = Color.FromArgb((int)((40 + easeHover * 20) * _animState.GlobalAlpha), 0, 0, 0);
            pgb.SurroundColors = new[] { Color.Transparent };
            g.FillPath(pgb, shadowPath);
        }

        if (easeHover > 0) {
            Rectangle glowRect = new Rectangle(rect.X - 6, rect.Y - 6, rect.Width + 12, rect.Height + 12);
            using (var glowPath = CreateRoundedRect(glowRect, 14))
            using (var pgb = new PathGradientBrush(glowPath)) {
                pgb.CenterColor = Color.FromArgb((int)(80 * easeHover * _animState.GlobalAlpha), baseColor);
                pgb.SurroundColors = new[] { Color.Transparent };
                g.FillPath(pgb, glowPath);
            }
        }

        using (var path = CreateRoundedRect(rect, 8))
        {
            Color topColor = ColorLerp(Color.FromArgb((int)(80 * _animState.GlobalAlpha), baseColor), Color.FromArgb((int)(160 * _animState.GlobalAlpha), baseColor), easeHover);
            Color bottomColor = ColorLerp(Color.FromArgb((int)(30 * _animState.GlobalAlpha), baseColor), Color.FromArgb((int)(80 * _animState.GlobalAlpha), baseColor), easeHover);
            if (easePress > 0) {
                topColor = ColorLerp(topColor, Color.FromArgb((int)(60 * _animState.GlobalAlpha), baseColor), easePress);
                bottomColor = ColorLerp(bottomColor, Color.FromArgb((int)(20 * _animState.GlobalAlpha), baseColor), easePress);
            }

            using (var brush = new LinearGradientBrush(rect, topColor, bottomColor, LinearGradientMode.Vertical)) {
                g.FillPath(brush, path);
            }

            if (easePress > 0) {
                Region oldClip = g.Clip;
                g.SetClip(path);

                using (var gridPen = new Pen(Color.FromArgb((int)(60 * easePress * _animState.GlobalAlpha), 0, 0, 0), 1f)) {
                    for (int scanY = rect.Y; scanY < rect.Bottom; scanY += 4) {
                        g.DrawLine(gridPen, rect.X, scanY, rect.Right, scanY);
                    }
                }

                g.Clip = oldClip;
            }

            if (easeHover > 0) {
                float pulse = 0.5f + 0.5f * (float)Math.Sin(_animState.GlobalPhase * 2f);
                using (var pen = new Pen(Color.FromArgb((int)(180 * easeHover * pulse * _animState.GlobalAlpha), Color.White), 1.5f)) {
                    g.DrawPath(pen, path);
                }
            } else {
                using (var pen = new Pen(Color.FromArgb((int)(100 * _animState.GlobalAlpha), baseColor), 1.2f)) { g.DrawPath(pen, path); }
            }

            using (var b = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), Color.White))) {
                StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
                g.DrawString(text, _buttonFont, b, rect, sf);
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
            if (_textFont != null) { _textFont.Dispose(); }
            if (_emojiFont != null) { _emojiFont.Dispose(); }
            if (_buttonFont != null) { _buttonFont.Dispose(); }
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

    private ModalAnimationState _animState;
    private float _modalTransProgress = 1f;
    private static readonly float MODAL_TRANS_SPEED = 0.05f;

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

        _animState = new ModalAnimationState(2);
        AURORA_Animation.Add(new ModalTimerAnimation(_animState, (s) =>
        {
            if (s.FadeState == ModalFadeState.Hidden) { this.Visible = false; return; }

            // 虚拟按钮独立缓动逻辑
            float btnSpeed = 0.12f;
            _restoreHoverProg = Math.Max(0f, Math.Min(1f, _restoreHoverProg + (_isRestoreHovered ? btnSpeed : -btnSpeed)));
            _restartHoverProg = Math.Max(0f, Math.Min(1f, _restartHoverProg + (_isRestartHovered ? btnSpeed : -btnSpeed)));
            _restorePressProg = Math.Max(0f, Math.Min(1f, _restorePressProg + (_isRestorePressed ? btnSpeed : -btnSpeed)));
            _restartPressProg = Math.Max(0f, Math.Min(1f, _restartPressProg + (_isRestartPressed ? btnSpeed : -btnSpeed)));

            // V2.0 过渡动画进度
            if (s.FadeState == ModalFadeState.FadingIn)
                _modalTransProgress = Math.Min(1f, _modalTransProgress + MODAL_TRANS_SPEED);
            else if (s.FadeState == ModalFadeState.FadingOut)
                _modalTransProgress = Math.Max(0f, _modalTransProgress - MODAL_TRANS_SPEED);

            Invalidate();
        }));

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
        _animState.FadeState = ModalFadeState.FadingIn;
        _animState.GlobalAlpha = 0f;
        _modalTransProgress = 0f;
        _isRestoreHovered = true;
        this.Focus();
    }

    public void FadeOutModal()
    {
        _animState.FadeState = ModalFadeState.FadingOut;
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

        // 全屏暗化遮罩（在变换之前绘制，确保完整覆盖）
        using (var dimBrush = new SolidBrush(Color.FromArgb((int)(180 * _animState.GlobalAlpha), 5, 8, 15))) { g.FillRectangle(dimBrush, ClientRectangle); }

        // V2.0 过渡变换（只作用于面板内容）
        try {
            float te = 1f - (float)Math.Pow(1f - _modalTransProgress, 3);
            float oy = (1f - te) * 200f;
            float ts = 0.85f + te * 0.15f;
            if (Math.Abs(oy) > 0.1f) { g.TranslateTransform(0, oy); }
            if (Math.Abs(ts - 1f) > 0.001f) {
                float cx = ClientRectangle.Width / 2f, cy = ClientRectangle.Height / 2f;
                g.TranslateTransform(cx, cy); g.ScaleTransform(ts, ts); g.TranslateTransform(-cx, -cy);
            }
        } catch { /* non-critical */ }

        int pW = 600;
        float unfoldEased = 1f - (float)Math.Pow(1f - _animState.GlobalAlpha, 3);
        int currentHeight = Math.Max(4, (int)(380 * unfoldEased));
        int pX = (this.Width - pW) / 2;
        int pY = (this.Height - currentHeight) / 2;
        Rectangle pRect = new Rectangle(pX, pY, pW, currentHeight);

        // 中央面板
        using (var path = CreateRoundedRect(pRect, 16)) {
            using (var bgBrush = new SolidBrush(Color.FromArgb((int)(240 * _animState.GlobalAlpha), 15, 20, 35))) { g.FillPath(bgBrush, path); }
            float pulse = 1.0f + 0.5f * (float)Math.Sin(_animState.GlobalPhase);
            int alpha = (int)((100 + 50 * pulse) * _animState.GlobalAlpha);
            using (var topHighlight = new LinearGradientBrush(pRect, Color.FromArgb(alpha, 0, 255, 255), Color.Transparent, LinearGradientMode.Vertical))
            using (var highlightPen = new Pen(topHighlight, 2f)) { g.DrawPath(highlightPen, path); }
        }

        // 标题
        string titleText = GetTitleText();
        using (var titleBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 0, 255, 255))) {
            StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            DrawStringWithEmoji(g, titleText, _titleFont, titleBrush, new RectangleF(pX, pY + 20, pW, 30), _emojiFont, sf);
        }
        
        using (var linePen = new Pen(Color.FromArgb((int)(80 * _animState.GlobalAlpha), 255, 255, 255), 1)) { 
            g.DrawLine(linePen, pX + 30, pY + 60, pX + pW - 30, pY + 60); 
        }

        // 会话信息标题
        string infoTitle = GetSessionInfoTitle();
        using (var infoTitleBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 0, 255, 255))) {
            DrawStringWithEmoji(g, infoTitle, _titleFont, infoTitleBrush, new PointF(pX + 30, pY + 75), _emojiFont);
        }

        // 会话信息内容
        int textY = pY + 110;
        int lineHeight = 30;
        using (var contentBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 200, 200, 255))) {
            string sessionIdLabel = GetSessionIdLabel();
            float labelWidth = g.MeasureString(sessionIdLabel, _textFont, new PointF(0,0), StringFormat.GenericTypographic).Width;
            DrawStringWithEmoji(g, sessionIdLabel, _textFont, contentBrush, new PointF(pX + 30, textY), _emojiFont);
            using (var valueBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), Color.White))) {
                g.DrawString(_sessionId, _textFont, valueBrush, new PointF(pX + 30 + labelWidth + 10, textY));
            }
        }
        
        textY += lineHeight;
        using (var contentBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 200, 200, 255))) {
            string progressLabel = GetProgressLabel();
            float labelWidth = g.MeasureString(progressLabel, _textFont, new PointF(0,0), StringFormat.GenericTypographic).Width;
            DrawStringWithEmoji(g, progressLabel, _textFont, contentBrush, new PointF(pX + 30, textY), _emojiFont);
            using (var valueBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 0, 255, 255))) {
                g.DrawString(_progress.ToString() + "%", _textFont, valueBrush, new PointF(pX + 30 + labelWidth + 10, textY));
            }
        }
        
        textY += lineHeight;
        using (var contentBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 200, 200, 255))) {
            string stageLabel = GetStageLabel();
            float labelWidth = g.MeasureString(stageLabel, _textFont, new PointF(0,0), StringFormat.GenericTypographic).Width;
            DrawStringWithEmoji(g, stageLabel, _textFont, contentBrush, new PointF(pX + 30, textY), _emojiFont);
            using (var valueBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), Color.White))) {
                g.DrawString(_stage, _textFont, valueBrush, new PointF(pX + 30 + labelWidth + 10, textY));
            }
        }
        
        textY += lineHeight;
        using (var contentBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 200, 200, 255))) {
            string savedAtLabel = GetSavedAtLabel();
            float labelWidth = g.MeasureString(savedAtLabel, _textFont, new PointF(0,0), StringFormat.GenericTypographic).Width;
            DrawStringWithEmoji(g, savedAtLabel, _textFont, contentBrush, new PointF(pX + 30, textY), _emojiFont);
            using (var valueBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), Color.White))) {
                g.DrawString(_lastUpdated, _textFont, valueBrush, new PointF(pX + 30 + labelWidth + 10, textY));
            }
        }
        
        textY += lineHeight;
        using (var contentBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), 200, 200, 255))) {
            string ageLabel = GetAgeLabel();
            float labelWidth = g.MeasureString(ageLabel, _textFont, new PointF(0,0), StringFormat.GenericTypographic).Width;
            DrawStringWithEmoji(g, ageLabel, _textFont, contentBrush, new PointF(pX + 30, textY), _emojiFont);
            using (var valueBrush = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), Color.White))) {
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
            pgb.CenterColor = Color.FromArgb((int)((40 + easeHover * 20) * _animState.GlobalAlpha), 0, 0, 0);
            pgb.SurroundColors = new[] { Color.Transparent };
            g.FillPath(pgb, shadowPath);
        }

        if (easeHover > 0) {
            Rectangle glowRect = new Rectangle(rect.X - 6, rect.Y - 6, rect.Width + 12, rect.Height + 12);
            using (var glowPath = CreateRoundedRect(glowRect, 14))
            using (var pgb = new PathGradientBrush(glowPath)) {
                pgb.CenterColor = Color.FromArgb((int)(80 * easeHover * _animState.GlobalAlpha), baseColor);
                pgb.SurroundColors = new[] { Color.Transparent };
                g.FillPath(pgb, glowPath);
            }
        }

        using (var path = CreateRoundedRect(rect, 8))
        {
            Color topColor = ColorLerp(Color.FromArgb((int)(80 * _animState.GlobalAlpha), baseColor), Color.FromArgb((int)(160 * _animState.GlobalAlpha), baseColor), easeHover);
            Color bottomColor = ColorLerp(Color.FromArgb((int)(30 * _animState.GlobalAlpha), baseColor), Color.FromArgb((int)(80 * _animState.GlobalAlpha), baseColor), easeHover);
            if (easePress > 0) {
                topColor = ColorLerp(topColor, Color.FromArgb((int)(60 * _animState.GlobalAlpha), baseColor), easePress);
                bottomColor = ColorLerp(bottomColor, Color.FromArgb((int)(20 * _animState.GlobalAlpha), baseColor), easePress);
            }

            using (var brush = new LinearGradientBrush(rect, topColor, bottomColor, LinearGradientMode.Vertical)) {
                g.FillPath(brush, path);
            }

            if (easePress > 0) {
                Region oldClip = g.Clip;
                g.SetClip(path);
                using (var gridPen = new Pen(Color.FromArgb((int)(60 * easePress * _animState.GlobalAlpha), 0, 0, 0), 1f)) {
                    for (int scanY = rect.Y; scanY < rect.Bottom; scanY += 4) {
                        g.DrawLine(gridPen, rect.X, scanY, rect.Right, scanY);
                    }
                }
                g.Clip = oldClip;
            }

            if (easeHover > 0) {
                float pulse = 0.5f + 0.5f * (float)Math.Sin(_animState.GlobalPhase * 2f);
                using (var pen = new Pen(Color.FromArgb((int)(180 * easeHover * pulse * _animState.GlobalAlpha), Color.White), 1.5f)) {
                    g.DrawPath(pen, path);
                }
            } else {
                using (var pen = new Pen(Color.FromArgb((int)(100 * _animState.GlobalAlpha), baseColor), 1.2f)) { g.DrawPath(pen, path); }
            }

            using (var f = new Font("Microsoft YaHei UI", 10, FontStyle.Bold))
            using (var b = new SolidBrush(Color.FromArgb((int)(255 * _animState.GlobalAlpha), Color.White))) {
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
    private float _waveTime = 0f;  // V2.0 引力波时间
    
    // V2.0 动态星座系统
    private List<Constellation> _constellations = new List<Constellation>();
    private int _constellationUpdateCounter = 0;
    private const int CONSTELLATION_UPDATE_INTERVAL = 30;
    
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
        this.MouseClick += OnMouseClick;
        
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

            // V2.0 引力波时间
            _waveTime += 0.1f;

            // V2.0 动态星座更新
            _constellationUpdateCounter++;
            if (_constellationUpdateCounter >= CONSTELLATION_UPDATE_INTERVAL)
            {
                UpdateConstellations();
                _constellationUpdateCounter = 0;
            }

            // 星座连线淡入淡出平滑渐变（每帧更新）
            foreach (var c in _constellations)
            {
                foreach (var conn in c.Connections)
                {
                    // 计算目标透明度（基于距离衰减，使用平方反比更自然）
                    conn.TargetOpacity = Math.Max(0f, 1f - (float)Math.Pow(conn.CurrentDistance / (conn.MaxDistance * 1.5f), 2f));
                    
                    if (conn.FadingOut)
                    {
                        // 淡出消失：线性均匀降透明度，缓慢消散营造深邃感（~2~3秒）
                        conn.ExistProgress -= conn.ExistProgress * 0.015f;
                        if (conn.ExistProgress < 0.002f)
                        {
                            conn.ExistProgress = 0f;
                            conn.Opacity = 0f;
                            conn.IsConnected = false;
                            continue;
                        }
                        // 线性缓动：透明度均匀下降，避免 EaseInCubic 瞬间消失
                        conn.Opacity = conn.TargetOpacity * conn.ExistProgress;
                    }
                    else if (conn.Exists)
                    {
                        // 已存在的连线：缓慢平滑过渡到目标透明度
                        float diff = conn.TargetOpacity - conn.Opacity;
                        if (Math.Abs(diff) > 0.001f)
                        {
                            conn.Opacity += diff * 0.05f;
                            // 防止超调
                            if ((diff > 0 && conn.Opacity > conn.TargetOpacity) || (diff < 0 && conn.Opacity < conn.TargetOpacity))
                                conn.Opacity = conn.TargetOpacity;
                        }
                    }
                    else
                    {
                        // 新连线：缓慢渐变出现，柔和自然
                        conn.ExistProgress += (1f - conn.ExistProgress) * 0.035f;
                        if (conn.ExistProgress >= 0.99f)
                        {
                            conn.ExistProgress = 1f;
                            conn.Exists = true;
                        }
                        // 使用 EaseOutCubic 缓动
                        float eased = 1f - (float)Math.Pow(1f - conn.ExistProgress, 3);
                        conn.Opacity = conn.TargetOpacity * eased;
                    }
                    
                    conn.IsConnected = conn.Opacity > 0.005f;
                }
            }

            // 星座高亮动画更新（点击交互）
            foreach (var constellation in _constellations)
            {
                if (constellation.HighlightTimer > 0)
                {
                    constellation.HighlightTimer--;
                    // 使用 EaseOutCubic 缓动从高亮目标值平滑过渡到 0
                    if (constellation.HighlightTimer <= 0)
                    {
                        constellation.HighlightTarget = 0f;
                    }
                    float diff = constellation.HighlightTarget - constellation.HighlightAlpha;
                    constellation.HighlightAlpha += diff * 0.1f;
                    if (Math.Abs(diff) < 0.001f) constellation.HighlightAlpha = constellation.HighlightTarget;
                }
            }

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

                    // === V2.0 引力波交互 ===
                    float waveDist = (float)Math.Sqrt(dx * dx + dy * dy);
                    if (waveDist < 80f && waveDist > 1f && star.HasSettled)
                    {
                        // 引力强度（弱化至舒适水平）
                        float force = (1f - waveDist / 80f) * 0.08f;
                        float wavePhase = (float)(_waveTime + waveDist * 0.05f);
                        // 波动幅度（弱化）
                        float waveForce = force * (1f + 0.08f * (float)Math.Sin(wavePhase));
                        float nx = dx / waveDist;
                        float ny = dy / waveDist;
                        // 应用系数（弱化）
                        star.VelocityX -= nx * waveForce * 0.03f;
                        star.VelocityY -= ny * waveForce * 0.03f;
                        float maxSpeed = 1.2f;  // 降低最大速度限制
                        float spd = (float)Math.Sqrt(star.VelocityX * star.VelocityX + star.VelocityY * star.VelocityY);
                        if (spd > maxSpeed) { star.VelocityX = (star.VelocityX / spd) * maxSpeed; star.VelocityY = (star.VelocityY / spd) * maxSpeed; }
                        star.VelocityX *= 0.95f;
                        star.VelocityY *= 0.95f;
                    }

                    // === V2.0 拖尾记录 ===
                    float speed = (float)Math.Sqrt(star.VelocityX * star.VelocityX + star.VelocityY * star.VelocityY);
                    if (star.MaxTrailLength > 0 && (!star.HasSettled || speed > 0.15f))
                    {
                        star.TrailPositions.Enqueue(new PointF(star.X, star.Y));
                        if (star.TrailPositions.Count > star.MaxTrailLength)
                            star.TrailPositions.Dequeue();
                    }
                    else if (star.MaxTrailLength > 0 && star.TrailPositions.Count > 0)
                    {
                        star.TrailPositions.Dequeue();
                    }

                    // === V2.0 颜色温度更新 ===
                    star.ColorPhase += star.ColorSpeed;
                    if (star.ColorPhase > (float)Math.PI * 2)
                        star.ColorPhase -= (float)(Math.PI * 2);

                    // === V2.0 脉冲星更新 ===
                    if (star.IsPulsar)
                    {
                        star.PulsarPhase += star.PulsarSpeed;
                        if (star.PulsarPhase > (float)Math.PI * 2)
                            star.PulsarPhase -= (float)(Math.PI * 2);
                    }
                } catch { /* non-critical */ }
            } // ←←← 关键：foreach 循环在此正确结束！

            // 更新流星
            for (int i = _meteors.Count - 1; i >= 0; i--)
            {
                try {
                    _meteors[i].Update();
                    if (!_meteors[i].IsAlive()) _meteors.RemoveAt(i);
                } catch { /* non-critical */ }
            }

            // 更新深空粒子
            for (int i = 0; i < _particles.Count; i++)
            {
                try {
                    _particles[i].Update(ClientRectangle);
                } catch { /* non-critical */ }
            }

            Invalidate();
        } catch { /* non-critical */ }
    }

    private void OnMouseMove(object sender, MouseEventArgs e)
    {
        _mousePos = e.Location;
    }

    private void OnMouseLeave(object sender, EventArgs e)
    {
        _mousePos = new Point(-1000, -1000);
        
        // 主动触发星座连线平滑淡出，避免鼠标离开窗口时连线直接消失
        foreach (var c in _constellations)
        {
            foreach (var conn in c.Connections)
            {
                if (conn.Opacity > 0.01f)
                {
                    conn.FadingOut = true;  // 标记为淡出状态，触发每帧平滑衰减逻辑
                    // 保持当前 ExistProgress，让淡出过程从当前透明度开始平滑过渡
                    conn.Exists = false;
                }
            }
        }
    }

    private void OnMouseClick(object sender, MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left) return;
        
        // 检测点击是否命中星座（基于星星位置，判定半径 30px）
        foreach (var constellation in _constellations)
        {
            foreach (var star in constellation.Stars)
            {
                float dx = e.X - star.X;
                float dy = e.Y - star.Y;
                float dist = (float)Math.Sqrt(dx * dx + dy * dy);
                if (dist < 30f)
                {
                    // 触发高亮
                    constellation.HighlightTarget = 1.0f;
                    constellation.HighlightTimer = 180;  // 持续约 3 秒（60fps）
                    break;
                }
            }
        }
    }

    // V2.0 动态星座系统（重构连线逻辑：每个星星只连接最近的邻居，模拟真实星座）
    private void UpdateConstellations()
    {
        try {
            // 保存旧的星座连线状态用于平滑淡入淡出过渡
            var oldConnections = new Dictionary<string, Connection>();
            foreach (var c in _constellations)
            {
                foreach (var conn in c.Connections)
                {
                    string key = GetConnKey(conn.Star1, conn.Star2);
                    oldConnections[key] = conn;
                }
            }

            _constellations.Clear();
            // 筛选最亮的星星参与星座连线
            var brightStars = new List<Star>();
            for (int i = 0; i < _stars.Count && brightStars.Count < 10; i++)  // 最多 10 颗
            {
                if (_stars[i].BaseAlpha > 200 || _stars[i].GlowFactor > 0.6f)
                    brightStars.Add(_stars[i]);
            }
            if (brightStars.Count < 2) return;

            // 重构连线逻辑：每个星星只连接最近的 1-2 个邻居
            var usedConnections = new HashSet<string>();
            var allConnections = new List<Connection>();

            for (int i = 0; i < brightStars.Count; i++)
            {
                // 找到所有邻居并排序
                var neighbors = new List<Tuple<float, Star>>();
                for (int j = 0; j < brightStars.Count; j++)
                {
                    if (i == j) continue;
                    float dx = brightStars[i].X - brightStars[j].X;
                    float dy = brightStars[i].Y - brightStars[j].Y;
                    float dist = (float)Math.Sqrt(dx * dx + dy * dy);
                    // 只连接合理距离内的邻居（80~400px，星座连线更分散舒展）
                    if (dist >= 80f && dist <= 400f)
                    {
                        neighbors.Add(new Tuple<float, Star>(dist, brightStars[j]));
                    }
                }

                // 按距离排序，取最近的 1-2 个邻居
                neighbors.Sort((a, b) => a.Item1.CompareTo(b.Item1));
                int maxNeighbors = Math.Min(2, neighbors.Count);

                for (int n = 0; n < maxNeighbors; n++)
                {
                    float dist = neighbors[n].Item1;
                    Star neighbor = neighbors[n].Item2;
                    string key = GetConnKey(brightStars[i], neighbor);

                    if (usedConnections.Contains(key)) continue;  // 避免重复连线
                    usedConnections.Add(key);

                    var conn = new Connection(brightStars[i], neighbor, dist);
                    conn.CurrentDistance = dist;

                    // 淡入淡出过渡处理
                    if (oldConnections.ContainsKey(key))
                    {
                        var oldConn = oldConnections[key];
                        conn.Opacity = oldConn.Opacity;
                        conn.TargetOpacity = oldConn.TargetOpacity;
                        conn.Exists = oldConn.Exists;
                        conn.ExistProgress = oldConn.ExistProgress;
                        conn.FadingOut = false;  // 持续存在的连线不处于淡出状态
                    }
                    else
                    {
                        // 新出现的连线：从零开始快速渐变出现
                        conn.Opacity = 0f;
                        conn.TargetOpacity = Math.Max(0f, 1f - (dist / 100f));
                        conn.Exists = false;
                        conn.ExistProgress = 0f;
                        conn.FadingOut = false;
                    }

                    allConnections.Add(conn);
                }
            }

            // 将连线组织成星座
            if (allConnections.Count > 0)
            {
                var constellation = new Constellation();
                var addedStars = new HashSet<Star>();
                foreach (var conn in allConnections)
                {
                    if (!addedStars.Contains(conn.Star1)) { constellation.Stars.Add(conn.Star1); addedStars.Add(conn.Star1); }
                    if (!addedStars.Contains(conn.Star2)) { constellation.Stars.Add(conn.Star2); addedStars.Add(conn.Star2); }
                    constellation.Connections.Add(conn);
                    constellation.IsHighlighted = conn.Star1.GlowFactor > 0.4f || conn.Star2.GlowFactor > 0.4f;
                }
                _constellations.Add(constellation);
            }

            // 处理消失的连线：将其添加到临时列表中，让它们继续淡出
            foreach (var kvp in oldConnections)
            {
                if (!usedConnections.Contains(kvp.Key))
                {
                    // 该连线已不存在，使用 EaseInCubic 加速淡出
                    var fadingConn = kvp.Value;
                    fadingConn.Exists = false;
                    fadingConn.FadingOut = true;   // 标记为淡出状态，每帧更新将以此处理
                    fadingConn.ExistProgress = Math.Max(0.002f, fadingConn.ExistProgress - 0.01f);  // 降低初始衰减，延长淡出过程
                    // 线性缓动：透明度均匀下降
                    fadingConn.Opacity = fadingConn.TargetOpacity * fadingConn.ExistProgress;
                    fadingConn.IsConnected = fadingConn.Opacity > 0.005f;
                    if (fadingConn.IsConnected)
                    {
                        var tempConst = new Constellation();
                        tempConst.Stars.Add(fadingConn.Star1);
                        tempConst.Stars.Add(fadingConn.Star2);
                        tempConst.Connections.Add(fadingConn);
                        tempConst.IsHighlighted = false;
                        _constellations.Add(tempConst);
                    }
                }
            }
        } catch { /* non-critical */ }
    }

    // 获取连线的唯一键
    private string GetConnKey(Star s1, Star s2)
    {
        return Math.Min(s1.X, s2.X).ToString("F0") + "_" + 
               Math.Min(s1.Y, s2.Y).ToString("F0") + "_" + 
               Math.Max(s1.X, s2.X).ToString("F0") + "_" + 
               Math.Max(s1.Y, s2.Y).ToString("F0");
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

        // === 2. 动态星座连线（增强视觉强度：更亮、更粗、更精致） ===
        foreach (var constellation in _constellations)
        {
            if (constellation.Connections.Count == 0) continue;
            // 点击高亮叠加：HighlightAlpha 在 0~1 之间
            float highlightBlend = constellation.HighlightAlpha;
            // 基础透明度：非高亮 90，高亮 160，点击高亮额外增加
            int baseAlpha = constellation.IsHighlighted ? 160 : 90;
            if (highlightBlend > 0.01f)
            {
                baseAlpha = (int)(baseAlpha + (220 - baseAlpha) * highlightBlend);
            }
            foreach (var conn in constellation.Connections)
            {
                if (!conn.IsConnected && conn.Opacity < 0.01f) continue;
                int connAlpha = (int)(baseAlpha * conn.Opacity);
                // 颜色：点击高亮叠加白色光效
                int r, gr, b;
                if (highlightBlend > 0.01f)
                {
                    // 点击高亮：从青色渐变到亮白
                    r = (int)(150 + (255 - 150) * highlightBlend);
                    gr = (int)(200 + (255 - 200) * highlightBlend);
                    b = 255;
                }
                else if (constellation.IsHighlighted)
                {
                    r = 200; gr = 235; b = 255;
                }
                else
                {
                    r = 150; gr = 200; b = 255;
                }
                // 线条粗细：点击高亮加粗
                float lineWidth = constellation.IsHighlighted ? 2.0f : 1.3f;
                if (highlightBlend > 0.01f)
                {
                    lineWidth = Math.Max(lineWidth, 1.3f + highlightBlend * 1.2f);
                }
                using (Pen pen = new Pen(Color.FromArgb(connAlpha, r, gr, b), lineWidth))
                {
                    g.DrawLine(pen, conn.Star1.X, conn.Star1.Y, conn.Star2.X, conn.Star2.Y);
                }
            }
        }

        // === 2.5. V2.0 拖尾效果 ===
        foreach (Star star in _stars)
        {
            if (star.MaxTrailLength <= 0 || star.TrailPositions.Count < 2) continue;
            var trail = star.TrailPositions.ToArray();
            int count = trail.Length;
            // 增强拖尾基础亮度：入场时（未 settled）使用极高亮度，使拖尾非常醒目
            float entranceBonus = star.HasSettled ? 1.0f : 3.0f;  // 入场阶段拖尾亮度提升200%
            float baseTrailAlpha = star.BaseAlpha * star.entranceAlpha * 0.8f * entranceBonus;
            for (int i = 0; i < count - 1; i++)
            {
                float fade = (float)i / (float)count;
                float trailAlpha = baseTrailAlpha * fade;
                if (trailAlpha < 5) continue;
                // 进一步增大拖尾粒子尺寸（从 0.3~1.0 提升到 0.4~1.2）
                float trailSize = star.Size * (0.4f + fade * 0.8f);
                int alphaIdx = Math.Max(0, Math.Min(255, (int)trailAlpha));
                g.FillEllipse(_starBrushCache[alphaIdx],
                    trail[i].X - trailSize / 2, trail[i].Y - trailSize / 2,
                    trailSize, trailSize);
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
                supernovaFactor * 0.75f
            );

            // === V2.0 脉冲星效果 ===
            if (star.IsPulsar)
            {
                float pulsarPulse = (float)Math.Sin(star.PulsarPhase);
                totalBrightness *= (1f + star.PulsarAmplitude * pulsarPulse);
            }

            if (star.HasSettled && star.SettleTimer > 0)
            {
                float pulse = star.SettleTimer > 20 ? 1.3f : (star.SettleTimer / 20f) * 0.3f + 1.0f;
                totalBrightness = Math.Min(1.8f, totalBrightness * pulse);
            }

            float currentAlpha = Math.Min(255f, totalBrightness * 255f * star.entranceAlpha);
            float currentSize = star.Size;

            if (currentAlpha > 8)
            {
                // V2.0 颜色温度：Yellow/Orange 星使用着色绘制
                float colorVar = (float)Math.Sin(star.ColorPhase) * 0.2f;
                bool useColorTint = (star.ColorType == Star.StarColorType.Yellow || 
                                     star.ColorType == Star.StarColorType.Orange) && 
                                     currentAlpha > 40;
                if (useColorTint)
                {
                    int cr, cg, cb;
                    if (star.ColorType == Star.StarColorType.Yellow) {
                        cr = (int)(220 + colorVar * 35);
                        cg = (int)(220 + colorVar * 25);
                        cb = (int)(170 + colorVar * 60);
                    } else {
                        cr = (int)(230 + colorVar * 25);
                        cg = (int)(170 + colorVar * 50);
                        cb = (int)(110 + colorVar * 60);
                    }
                    cr = Math.Max(0, Math.Min(255, cr));
                    cg = Math.Max(0, Math.Min(255, cg));
                    cb = Math.Max(0, Math.Min(255, cb));
                    using (var tintBrush = new SolidBrush(Color.FromArgb((int)currentAlpha, cr, cg, cb)))
                    {
                        g.FillEllipse(tintBrush, star.X - currentSize / 2, star.Y - currentSize / 2, currentSize, currentSize);
                    }
                }
                else
                {
                    // 绘制星星（使用缓存的 Brush）
                    int starAlphaIdx = Math.Max(0, Math.Min(255, (int)currentAlpha));
                    g.FillEllipse(_starBrushCache[starAlphaIdx], star.X - currentSize / 2, star.Y - currentSize / 2, currentSize, currentSize);
                }

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

        // === V2.0 拖尾效果 ===
        public Queue<PointF> TrailPositions = new Queue<PointF>(20);  // 增大容量从16到20，适应更长的拖尾
        public int MaxTrailLength = 0;

        // === V2.0 颜色温度 ===
        public enum StarColorType { BlueWhite, White, Yellow, Orange }
        public StarColorType ColorType;
        public float ColorPhase;
        public float ColorSpeed;

        // === V2.0 脉冲星 ===
        public bool IsPulsar;
        public float PulsarPhase;
        public float PulsarSpeed;
        public float PulsarAmplitude;

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

            // V2.0 颜色温度初始化
            float tempRand = (float)_rand.NextDouble();
            if (tempRand < 0.15f) {
                this.ColorType = StarColorType.BlueWhite;
                this.ColorSpeed = 0.001f + (float)_rand.NextDouble() * 0.002f;
            } else if (tempRand < 0.50f) {
                this.ColorType = StarColorType.White;
                this.ColorSpeed = 0.0008f + (float)_rand.NextDouble() * 0.0015f;
            } else if (tempRand < 0.80f) {
                this.ColorType = StarColorType.Yellow;
                this.ColorSpeed = 0.0005f + (float)_rand.NextDouble() * 0.001f;
            } else {
                this.ColorType = StarColorType.Orange;
                this.ColorSpeed = 0.0003f + (float)_rand.NextDouble() * 0.0008f;
            }
            this.ColorPhase = (float)_rand.NextDouble() * (float)Math.PI * 2;

            // V2.0 脉冲星初始化
            if (_rand.NextDouble() < 0.08f) {
                this.IsPulsar = true;
                this.PulsarPhase = (float)_rand.NextDouble() * (float)Math.PI * 2;
                this.PulsarSpeed = 0.02f + (float)_rand.NextDouble() * 0.03f;
                this.PulsarAmplitude = 0.3f + (float)_rand.NextDouble() * 0.4f;
            }

            // V2.0 拖尾长度初始化
            this.MaxTrailLength = GetTrailLengthByTier();
        }

        private int GetTrailLengthByTier() {
            switch (AuroraRenderEngine.CurrentTier) {
                case PerformanceTier.Eco: return 0;
                case PerformanceTier.Balanced: return 6;   // 从 3 提升到 6
                case PerformanceTier.Performance: return 10; // 从 6 提升到 10
                case PerformanceTier.Extreme: return 15;    // 从 8 提升到 15
                default: return 8;
            }
        }
    }

    // V2.0 动态星座系统
    private class Constellation
    {
        public List<Star> Stars = new List<Star>();
        public List<Connection> Connections = new List<Connection>();
        public bool IsHighlighted;
        public float HighlightAlpha = 0f;     // 点击高亮透明度（0~1）
        public float HighlightTarget = 0f;    // 高亮目标值
        public int HighlightTimer = 0;        // 高亮计时器（帧数）
    }

    private class Connection
    {
        public Star Star1, Star2;
        public float MaxDistance;
        public float CurrentDistance;
        public float Opacity;
        public float TargetOpacity;
        public bool IsConnected;
        public bool Exists;  // 标记是否已存在（用于渐变出现）
        public float ExistProgress;  // 存在度渐变（0→1 出现，1→0 消失）
        public bool FadingOut;  // 标记是否正在淡出（消失），用于区分淡入/淡出动画

        public Connection(Star s1, Star s2, float dist)
        {
            Star1 = s1; Star2 = s2;
            MaxDistance = dist;
            CurrentDistance = dist;
            Opacity = 0f;  // 初始透明度为0，通过渐变出现
            TargetOpacity = Math.Max(0f, 1f - (dist / (dist * 1.5f)));
            IsConnected = false;
            Exists = false;
            ExistProgress = 0f;
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
            float centerX = 210f;
            float centerY = 95f;
            float angle = (float)Math.Atan2(centerY - y, centerX - x);
            float speed = 0.03f + (float)_rand.NextDouble() * 0.03f;
            VX = (float)Math.Cos(angle) * speed;
            VY = (float)Math.Sin(angle) * speed;
            Alpha = _rand.Next(60, 120);
            Size = 0.3f + (float)_rand.NextDouble() * 1.0f;
        }

        public void Update(Rectangle bounds)
        {
            X += VX;
            Y += VY;
            float centerX = bounds.Width / 2f;
            float centerY = bounds.Height / 2f;
            float distanceToCenter = (float)Math.Sqrt(Math.Pow(X - centerX, 2) + Math.Pow(Y - centerY, 2));
            if (distanceToCenter < 50)
            {
                float angle = (float)(_rand.NextDouble() * Math.PI * 2);
                float distance = (float)(_rand.NextDouble() * 50 + Math.Max(bounds.Width, bounds.Height) / 2);
                X = centerX + (float)Math.Cos(angle) * distance;
                Y = centerY + (float)Math.Sin(angle) * distance;
                angle = (float)Math.Atan2(centerY - Y, centerX - X);
                float speed = 0.03f + (float)_rand.NextDouble() * 0.03f;
                VX = (float)Math.Cos(angle) * speed;
                VY = (float)Math.Sin(angle) * speed;
            }
        }
    }
}

// ==========================================
// =============== UWPText（自绘UWP标题控件） ===============
// 特性：
// - 自绘文本，整个控件区域都可响应鼠标（支持无边框拖拽穿透）
// - 兼容 Start-UwpEnterAnimation / Start-UwpExitAnimation
// - 支持文本切换时的UWP滑动淡入淡出动效
// - 支持多行文本、左右对齐、前景色自定义

public class UWPText : Control {
    private string _text = "";
    private string _nextText = "";
    private string _pendingText = null;
    private bool _hasPendingText = false;
    private float _transitionProgress = 0f;
    private bool _isTransitioning = false;
    private int _transitionDurationMs = 300;
    private DateTime _transitionStartTime;
    private StringFormat _stringFormat;
    private Font _font;
    private Color _foreColor = Color.White;
    private float _enterOffsetX = 0f;
    private float _enterOffsetY = 0f;
    private float _enterScale = 1f;
    private int _enterAlpha = 255;
    private bool _isInEnterAnimation = false;

    public UWPText() {
        this.DoubleBuffered = true;
        this.SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.UserPaint |
                      ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
        this.BackColor = Color.Transparent;
        _stringFormat = new StringFormat();
        _stringFormat.LineAlignment = StringAlignment.Center;
        _stringFormat.Alignment = StringAlignment.Near;
        _stringFormat.Trimming = StringTrimming.EllipsisCharacter;
    }

    public new string Text {
        get { return _text; }
        set {
            if (_text != value) {
                if (_isInEnterAnimation) {
                    _pendingText = value;
                    _hasPendingText = true;
                } else {
                    StartTextTransition(value);
                }
            }
        }
    }

    public string TextOnly {
        get { return _text; }
        set { _text = value; }
    }

    public new Font Font {
        get { return _font ?? base.Font; }
        set { _font = value; base.Font = value; }
    }

    public new Color ForeColor {
        get { return _foreColor; }
        set { _foreColor = value; }
    }

    public StringAlignment TextAlign {
        get { return _stringFormat.Alignment; }
        set { _stringFormat.Alignment = value; }
    }

    public void StartTextTransition(string newText) {
        _nextText = newText;
        _transitionProgress = 0f;
        _isTransitioning = true;
        _transitionStartTime = DateTime.Now;
        this.Invalidate();
    }

    public void SetEnterAnimationState(float offsetX, float offsetY, float scale, int alpha) {
        _enterOffsetX = offsetX;
        _enterOffsetY = offsetY;
        _enterScale = scale;
        _enterAlpha = alpha;
        _isInEnterAnimation = true;
        this.Invalidate();
    }

    public void ResetEnterAnimationState() {
        _enterOffsetX = 0f;
        _enterOffsetY = 0f;
        _enterScale = 1f;
        _enterAlpha = 255;
        _isInEnterAnimation = false;
        this.Invalidate();

        if (_hasPendingText) {
            StartTextTransition(_pendingText);
            _pendingText = null;
            _hasPendingText = false;
        }
    }

    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;

        if (_isTransitioning) {
            DrawTransitionText(g);
        } else {
            DrawStaticText(g);
        }
    }

    private void DrawStaticText(Graphics g) {
        if (string.IsNullOrEmpty(_text) || _enterAlpha <= 0) return;

        g.TranslateTransform(_enterOffsetX, _enterOffsetY);
        g.ScaleTransform(_enterScale, _enterScale);

        int alpha = Math.Min(255, _enterAlpha);
        using (var brush = new SolidBrush(Color.FromArgb(alpha, _foreColor))) {
            RectangleF rect = new RectangleF(0, 0, this.Width / _enterScale, this.Height / _enterScale);
            g.DrawString(_text, _font ?? this.Font, brush, rect, _stringFormat);
        }
    }

    private void DrawTransitionText(Graphics g) {
        float elapsed = (float)(DateTime.Now - _transitionStartTime).TotalMilliseconds;
        _transitionProgress = Math.Min(1f, elapsed / _transitionDurationMs);

        if (_transitionProgress >= 1f) {
            _text = _nextText;
            _nextText = "";
            _isTransitioning = false;
            DrawStaticText(g);
            return;
        }

        float easedIn = 1f - (float)Math.Pow(1f - _transitionProgress, 3);
        float easedOut = (float)Math.Pow(1f - _transitionProgress, 3);

        // 绘制旧文本（淡出 + 向上滑动）
        if (!string.IsNullOrEmpty(_text) && easedOut > 0.01f) {
            int oldAlpha = (int)(255 * _enterAlpha / 255f * easedOut);
            float slideY = -20f * (1f - easedOut);
            using (var brush = new SolidBrush(Color.FromArgb(oldAlpha, _foreColor))) {
                RectangleF rect = new RectangleF(0, slideY, this.Width, this.Height);
                g.DrawString(_text, _font ?? this.Font, brush, rect, _stringFormat);
            }
        }

        // 绘制新文本（淡入 + 向下滑动）
        if (!string.IsNullOrEmpty(_nextText) && easedIn > 0.01f) {
            int newAlpha = (int)(255 * _enterAlpha / 255f * easedIn);
            float slideY = 20f * (1f - easedIn);
            using (var brush = new SolidBrush(Color.FromArgb(newAlpha, _foreColor))) {
                RectangleF rect = new RectangleF(0, slideY, this.Width, this.Height);
                g.DrawString(_nextText, _font ?? this.Font, brush, rect, _stringFormat);
            }
        }

        this.Invalidate();
    }

    protected override void Dispose(bool disposing) {
        if (_stringFormat != null) _stringFormat.Dispose();
        base.Dispose(disposing);
    }
}



'@
Write-Host "[GUI-CSharp] Compiling custom controls..." -ForegroundColor Cyan
try {
    $AURORA_Engine_Assembly = [System.Reflection.Assembly]::LoadFrom($global:AURORA_Animation_Assembly)
    Write-Host "[GUI-CSharp] Animation assembly loaded: $($AURORA_Engine_Assembly.FullName)" -ForegroundColor Cyan
    
    Add-Type -ReferencedAssemblies @("System.Drawing", "System.Windows.Forms", $AURORA_Engine_Assembly) -TypeDefinition $guiCsharpCode -Language CSharp -ErrorAction Stop
    Write-Host "[GUI-CSharp] Custom controls compiled successfully!" -ForegroundColor Green
} catch {
    Write-Host "[GUI-CSharp ERROR] Compilation failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "[GUI-CSharp ERROR] Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
    }
    Write-Host "[GUI-CSharp ERROR] StackTrace: $($_.ScriptStackTrace)" -ForegroundColor Red
    throw
}































