<#
.SYNOPSIS
    AURORA 动画核心引擎
.DESCRIPTION
    AURORA 动画核心引擎独立模块
    包含：渲染引擎配置、动画管理器、动画基类、FloatAnimation、EasingType、IAnimatable 接口
.NOTES
    版本：V1.3.26.5Release | 构建时间：2026.06.08
    作者：AURORA VelociRaptor-GR Dev PRJ.
    变更：缓动函数库扩展至16种 + 动态计时器间隔优化
#>

param()

$engineDir = Split-Path -Parent $PSCommandPath
$engineDll = Join-Path $engineDir "AURORA-AnimationCoreEngine.dll"

# 尝试加载现有 DLL，如果被占用则删除并重新编译
$loaded = $false
if (Test-Path $engineDll) {
    try {
        Add-Type -Path $engineDll -ErrorAction Stop
        $loaded = $true
    } catch {
        try {
            Remove-Item $engineDll -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Non-critical operation failed: $($_.Exception.Message)"
            Write-Debug "Stack: $($_.ScriptStackTrace)"
        }
    }
}

# 如果没加载成功，就编译
if (-not $loaded) {
    Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'

using System;
using System.Collections.Generic;
using System.Windows.Forms;

public enum PerformanceTier { Eco = 0, Balanced = 1, Performance = 2, Extreme = 3 }

public static class AuroraRenderEngine
{
    public static PerformanceTier CurrentTier { get; private set; }

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

public enum EasingType
{
    Linear,
    EaseInCubic,
    EaseOutCubic,
    EaseInOutCubic,
    EaseInQuad,
    EaseOutQuad,
    EaseInOutQuad,
    EaseInQuart,
    EaseOutQuart,
    EaseInOutQuart,
    EaseInQuint,
    EaseOutQuint,
    EaseInOutQuint,
    EaseInElastic,
    EaseOutElastic,
    EaseInOutElastic,
    EaseInBounce,
    EaseOutBounce,
    EaseInOutBounce
}

public abstract class Animation
{
    public abstract bool Update();
}

public interface IAnimatable
{
    void SetAnimationValue(string propertyName, float value);
    void Invalidate();
}

public class AnimationManager
{
    private Timer _timer;
    private List<Animation> _animations;
    private bool _isRunning;

    public AnimationManager()
    {
        _timer = new Timer { Interval = AuroraRenderEngine.GetTimerInterval() };
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
        _elapsed += 0.016f;
        float progress = Math.Min(1.0f, _elapsed / _duration);
        float easedProgress = progress;
        
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
            case EasingType.EaseInQuad:
                easedProgress = progress * progress;
                break;
            case EasingType.EaseOutQuad:
                easedProgress = 1 - (1 - progress) * (1 - progress);
                break;
            case EasingType.EaseInOutQuad:
                if (progress < 0.5f)
                    easedProgress = 2 * progress * progress;
                else
                    easedProgress = 1 - 2 * (1 - progress) * (1 - progress);
                break;
            case EasingType.EaseInQuart:
                easedProgress = (float)Math.Pow(progress, 4);
                break;
            case EasingType.EaseOutQuart:
                easedProgress = 1 - (float)Math.Pow(1 - progress, 4);
                break;
            case EasingType.EaseInOutQuart:
                if (progress < 0.5f)
                    easedProgress = 8 * (float)Math.Pow(progress, 4);
                else
                    easedProgress = 1 - 8 * (float)Math.Pow(1 - progress, 4);
                break;
            case EasingType.EaseInQuint:
                easedProgress = (float)Math.Pow(progress, 5);
                break;
            case EasingType.EaseOutQuint:
                easedProgress = 1 - (float)Math.Pow(1 - progress, 5);
                break;
            case EasingType.EaseInOutQuint:
                if (progress < 0.5f)
                    easedProgress = 16 * (float)Math.Pow(progress, 5);
                else
                    easedProgress = 1 - 16 * (float)Math.Pow(1 - progress, 5);
                break;
            case EasingType.EaseInElastic:
                if (progress <= 0f || progress >= 1f) { easedProgress = progress; break; }
                {
                    float p = 0.3f;
                    float s = p / 4f;
                    easedProgress = -(float)Math.Pow(2, 10 * progress - 10) * (float)Math.Sin((progress - 1 - s) * (2 * Math.PI) / p);
                }
                break;
            case EasingType.EaseOutElastic:
                if (progress <= 0f || progress >= 1f) { easedProgress = progress; break; }
                {
                    float p = 0.3f;
                    float s = p / 4f;
                    easedProgress = (float)Math.Pow(2, -10 * progress) * (float)Math.Sin((progress - s) * (2 * Math.PI) / p) + 1;
                }
                break;
            case EasingType.EaseInOutElastic:
                if (progress <= 0f || progress >= 1f) { easedProgress = progress; break; }
                {
                    float p = 0.3f * 1.5f;
                    float s = p / 4f;
                    if (progress < 0.5f)
                    {
                        float t = progress * 2;
                        easedProgress = 0.5f * (-(float)Math.Pow(2, 10 * t - 10) * (float)Math.Sin((t - 1 - s) * (2 * Math.PI) / p));
                    }
                    else
                    {
                        float t = progress * 2 - 1;
                        easedProgress = 0.5f * ((float)Math.Pow(2, -10 * t) * (float)Math.Sin((t - s) * (2 * Math.PI) / p) + 2);
                    }
                }
                break;
            case EasingType.EaseInBounce:
                easedProgress = 1 - EaseOutBounceHelper(1 - progress);
                break;
            case EasingType.EaseOutBounce:
                easedProgress = EaseOutBounceHelper(progress);
                break;
            case EasingType.EaseInOutBounce:
                if (progress < 0.5f)
                    easedProgress = (1 - EaseOutBounceHelper(1 - progress * 2)) * 0.5f;
                else
                    easedProgress = EaseOutBounceHelper(progress * 2 - 1) * 0.5f + 0.5f;
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

    private static float EaseOutBounceHelper(float t)
    {
        float n1 = 7.5625f;
        float d1 = 2.75f;
        if (t < 1f / d1)
            return n1 * t * t;
        else if (t < 2f / d1)
            return n1 * (t -= 1.5f / d1) * t + 0.75f;
        else if (t < 2.5f / d1)
            return n1 * (t -= 2.25f / d1) * t + 0.9375f;
        else
            return n1 * (t -= 2.625f / d1) * t + 0.984375f;
    }
}

public static class AURORA_Animation
{
    private static AnimationManager _instance;

    public static AnimationManager Manager
    {
        get
        {
            if (_instance == null)
            {
                _instance = new AnimationManager();
            }
            return _instance;
        }
    }

    public static void Add(Animation a) { Manager.AddAnimation(a); }
    public static void Remove(Animation a) { Manager.RemoveAnimation(a); }
    public static void Clear() { Manager.Clear(); }
}

public class GlareSweepAnimation : Animation
{
    private IAnimatable _target;
    private string _propertyName;
    private float _startProgress;
    private float _targetProgress;
    private float _currentProgress;
    private float _duration;
    private float _elapsed;
    private Action _onComplete;

    public GlareSweepAnimation(IAnimatable target, string propertyName,
                               float startProgress, float targetProgress, float duration,
                               Action onComplete = null)
    {
        _target = target;
        _propertyName = propertyName;
        _startProgress = startProgress;
        _targetProgress = targetProgress;
        _currentProgress = startProgress;
        _duration = duration;
        _elapsed = 0;
        _onComplete = onComplete;
    }

    public override bool Update()
    {
        _elapsed += 0.016f;
        float progress = Math.Min(1.0f, _elapsed / _duration);

        float easedProgress = 1 - (float)Math.Pow(1 - progress, 3);
        _currentProgress = _startProgress + (_targetProgress - _startProgress) * easedProgress;

        _target.SetAnimationValue(_propertyName, _currentProgress);
        _target.Invalidate();

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

public enum ModalFadeState { Hidden, FadingIn, Idle, FadingOut }

public class ModalAnimationState
{
    public float GlobalPhase;
    public float GlobalAlpha;
    public ModalFadeState FadeState;

    public float[] HoverProg;
    public float[] PressProg;
    public bool[] IsHovered;
    public bool[] IsPressed;

    public int ButtonCount { get; private set; }

    public ModalAnimationState(int buttonCount)
    {
        ButtonCount = buttonCount;
        HoverProg = new float[buttonCount];
        PressProg = new float[buttonCount];
        IsHovered = new bool[buttonCount];
        IsPressed = new bool[buttonCount];
        FadeState = ModalFadeState.Hidden;
    }

    public void Reset()
    {
        FadeState = ModalFadeState.FadingIn;
        GlobalAlpha = 0f;
        GlobalPhase = 0f;
        Array.Clear(HoverProg, 0, HoverProg.Length);
        Array.Clear(PressProg, 0, PressProg.Length);
        Array.Clear(IsHovered, 0, IsHovered.Length);
        Array.Clear(IsPressed, 0, IsPressed.Length);
    }

    public int Tick(float delta = 0.05f)
    {
        GlobalPhase += delta;
        if (GlobalPhase > Math.PI * 2) GlobalPhase -= (float)(Math.PI * 2);

        float fadeSpeed = 0.08f;
        if (FadeState == ModalFadeState.FadingIn)
        {
            GlobalAlpha = Math.Min(1.0f, GlobalAlpha + fadeSpeed);
            if (GlobalAlpha >= 1.0f) { FadeState = ModalFadeState.Idle; return 1; }
        }
        else if (FadeState == ModalFadeState.FadingOut)
        {
            GlobalAlpha = Math.Max(0f, GlobalAlpha - fadeSpeed);
            if (GlobalAlpha <= 0f) { FadeState = ModalFadeState.Hidden; return 2; }
        }

        float btnSpeed = 0.12f;
        for (int i = 0; i < ButtonCount; i++)
        {
            HoverProg[i] = Clamp01(HoverProg[i] + (IsHovered[i] ? btnSpeed : -btnSpeed));
            PressProg[i] = Clamp01(PressProg[i] + (IsPressed[i] ? btnSpeed : -btnSpeed));
        }
        return 0;
    }

    private float Clamp01(float v)
    {
        if (v < 0f) return 0f;
        if (v > 1f) return 1f;
        return v;
    }
}

public class ModalTimerAnimation : Animation
{
    private ModalAnimationState _state;
    private Action<ModalAnimationState> _onTick;
    private Action _onHidden;

    public ModalTimerAnimation(ModalAnimationState state, Action<ModalAnimationState> onTick, Action onHidden = null)
    {
        _state = state;
        _onTick = onTick;
        _onHidden = onHidden;
    }

    public override bool Update()
    {
        _state.Tick();
        _onTick(_state);
        if (_state.FadeState == ModalFadeState.Hidden)
        {
            if (_onHidden != null) _onHidden.Invoke();
        }
        return true;
    }
}

public class LoopAnimation : Animation
{
    private Action _onTick;

    public LoopAnimation(Action onTick)
    {
        _onTick = onTick;
    }

    public override bool Update()
    {
        _onTick();
        return true;
    }
}

'@ -Language CSharp -OutputAssembly $engineDll
    Write-Host "[动画引擎] 编译完成：$engineDll" -ForegroundColor Cyan
}

# 导出程序集路径，供后续 Add-Type 使用
$global:AURORA_Animation_Assembly = $engineDll



























