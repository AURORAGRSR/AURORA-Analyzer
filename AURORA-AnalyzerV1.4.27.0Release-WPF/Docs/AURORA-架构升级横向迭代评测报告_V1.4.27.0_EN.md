# AURORA-Analyzer Architecture Upgrade Horizontal Iterative Review Report

> **Review Date**: 2026-06-30
> **Review Scope**: V1.3.26.7Release (WinForm GDI+) → V1.4.27.0Release (WPF) Full Architecture Comparison
> **Review Methodology**: File-by-file deep reading + Architecture dimension horizontal comparison + Control-level itemized verification
> **Reviewer**: Senior Architecture Analyst

---

## Table of Contents

1. [Version Overview](#1-version-overview)
2. [Architecture Comparison](#2-architecture-comparison)
3. [Control System Comparison](#3-control-system-comparison)
4. [Animation System Comparison](#4-animation-system-comparison)
5. [Performance System Comparison](#5-performance-system-comparison)
6. [Visual Design Comparison](#6-visual-design-comparison)
7. [Security Comparison](#7-security-comparison)
8. [Code Quality Comparison](#8-code-quality-comparison)
9. [Summary and Outlook](#9-summary-and-outlook)

---

## 1. Version Overview

### V1.3.26.7Release (PowerShell + WinForm GDI+)

V1.3.26.7 is the final stable version of AURORA-Analyzer in the WinForm era. The entire system is built on PowerShell scripts, with the UI layer dynamically creating WinForm controls through the `System.Windows.Forms` assembly, and all visual effects relying on GDI+ `OnPaint` events for per-frame rendering. Architecturally, it manifests as a "script-driven GUI" pattern — the LauncherGUI script at approximately 10,000 lines embeds C# code compiled via `Add-Type`, shouldering all responsibilities including security checks, animation rendering, and session management. The CHSPRO and ENGPRO language variants contain approximately 6,000 lines of semantic duplication, with modules imported implicitly through dot-sourcing and a global `syncHash` hashtable serving as the "poor man's IPC" for inter-process communication.

### V1.4.27.0Release (PowerShell + WPF)

V1.4.27.0 represents a fundamental architectural refactoring. The UI layer has been completely migrated from WinForm GDI+ to the WPF framework, adopting an independent control library project `AURORA.Wpf.csproj` compiled in C# 5.0. The overall architecture follows the MVVM pattern, with a three-layer separation of View (XAML declarative UI), ViewModel (data binding and commands), and Service (business logic). The PowerShell engine is embedded into the WPF process via `System.Management.Automation.Runspaces.RunspacePool`, utilizing `Hashtable.Synchronized` for cross-Runspace state synchronization. Language support has been consolidated from dual .ps1 files into a single engine plus `LanguageService` (based on .resx resource files) for unified management.

---

## 2. Architecture Comparison

| Dimension | V1.3.26.7 WinForm | V1.4.27.0 WPF |
|-----------|-------------------|---------------|
| UI Framework | WinForm GDI+, PowerShell scripts dynamically create controls via `Add-Type`, all UI assembled by scripts at runtime | WPF XAML declarative UI, C# compiled control library (`AURORA.Wpf.csproj`), design-time and runtime separated |
| Architecture Pattern | Event-driven, no clear layering. LauncherGUI mixes GUI construction, security checks, animation rendering, and session management | MVVM pattern: View (XAML) / ViewModel (data binding + `RelayCommand`) / Service (business logic) with three-layer separation |
| Rendering Pipeline | GDI+ `OnPaint` per-frame drawing, CPU rendering. Each control independently manages `Timer`-driven repaint loops | WPF retained-mode rendering, GPU-accelerated. Driven by `CompositionTarget.Rendering` (vsync-aligned), `OnRender` triggered only when needed |
| PowerShell Integration | Single Runspace communicating via pipeline, `syncHash` hashtable polling for GUI responses | `RunspacePool` parallel execution, `Hashtable.Synchronized` shared state, `EventWaitHandle` event-driven authorization |
| Animation System | PowerShell `Timer`-driven, per-frame updates to `Left`/`Top`/`Opacity` properties, unstable frame rate | `Storyboard` + `EasingFunction` (window entry/exit) and `CompositionTarget.Rendering` (background/button effects) dual-drive architecture |
| Language Support | Dual .ps1 files (CHSPRO/ENGPRO), ~6,000 lines of duplication, structural drift risk | Single engine + `LanguageService` (.resx resource files), runtime switching, zero duplication |
| Performance Tiers | PowerShell script detects hardware via `Get-CimInstance`, global variable `$global:AuroraPerfTier` controls | C# WMI hardware detection (`ManagementObjectSearcher`), environment variable `AURORA_PERF_TIER` + static class `AuroraRenderEngine` controls |
| Security Mechanism | PowerShell script validation, environment variable trust chain, anti-debugging detection implemented in scripts | C# `IntegrityGuardService` + RSA token verification + AES-256-CBC elevation tokens + anti-debugging + `WatchdogService` watchdog |
| Dependency Management | Dot-source implicit imports, dependent on import order, no explicit dependency declarations | C# project references (`.csproj`), NuGet package management, explicit compile-time dependencies |
| Engineering Maturity | Script-level engineering, `build.ps1` injects keys via regex replacement, version number hardcoded in 5+ locations | Professional .NET project, `Build-Aurora.ps1` / `build-wpf.ps1` build scripts, MSBuild compilation, GitHub Actions CI |

### Detailed Analysis

**UI Framework Upgrade**: The migration from WinForm to WPF is not merely a framework replacement, but a fundamental change in the rendering model. WinForm uses Immediate Mode — every `OnPaint` event must redraw all content, and all visual states (hover, press, animation progress) are manually tracked by the developer and redrawn frame by frame. WPF uses Retained Mode — the visual tree is maintained by the framework, the GPU handles compositing and rasterization, and developers only need to declare visual elements and bind states through dependency properties; the framework automatically handles dirty region repainting. This is particularly evident in AuroraButton's 17 animation effects: the WinForm version required maintaining 17 Timer state variables and computing each one in `OnPaint`, while the WPF version advances all animation progress uniformly through `OnAnimationTick`, with `OnRender` responsible only for drawing — logic is cleanly separated.

**MVVM Architecture**: V1.4.27.0 introduces a complete MVVM layering. The `ViewModels/` directory contains 10 ViewModels (`MainViewModel`, `ProModeViewModel`, `SplashScreenViewModel`, `ElevationDialogViewModel`, etc.), implementing `INotifyPropertyChanged` through the `ObservableObject` base class and `ICommand` binding through `RelayCommand`. The `Views/` directory contains corresponding XAML views and code-behind. The `Services/` directory contains 15 service classes covering PowerShell hosting, integrity guarding, language management, session caching, repair, recovery, and undo management — all business domains.

---

## 3. Control System Comparison

### 3.1 AuroraButton (formerly TechButton)

AuroraButton is the core representative of the control system upgrade, fully migrated from WinForm GDI+ custom drawing to the WPF `FrameworkElement` inheritance hierarchy.

**WinForm Version (TechButton)**: Derived from `Button`, overrides the `OnPaint` method, using GDI+ `Graphics` objects for all drawing. All 17 animation details (hover scale 5%, color interpolation, light sweep, magnetic offset, press scale 3%, ripple, state machine, focus animation, outer glow, path gradient shadow, inner diffuse highlight, mouse-leave rebound, click cooldown, long-press detection, keyboard events, loading dashed ring, success/failure icons) are updated frame by frame through independent `Timer` objects that modify corresponding property variables, then drawn layer by layer in `OnPaint` based on current state. Since GDI+ does not support blur effects, all "glows" are simulated through multiple layers of semi-transparent ellipses superimposed.

**WPF Version (AuroraButton)**: Inherits from `Button`, fully retains all 17 animation effects, and adds the following key features:

- **Aurora Ambient Color Injection**: Obtains the button's absolute Y coordinate in the window via `TransformToAncestor(Window)`, calls the `AuroraStarfield.SampleAuroraColorAt(ny, timePhase)` static method to sample the aurora layer color at the current position, and injects it into the glass body. Normal state intensity 0 (no injection), Hover state intensity 0.50 (glass strongly reveals aurora color), Press state intensity 0.80 (pressed into the aurora, glass inner layer tinted). Uses a `RadialGradientBrush` (offset toward the bottom center, simulating the refraction feel of aurora seeping upward from below), with peak alpha at 150, smoothly interpolated through `_ambientStrength`.

- **iOS-Style Bouncy Release Feedback**: When released from a press, triggers a 600ms dual-phase rebound animation — scale overshoots from 0.97 to 1.04 before converging to 1.0. Split into two phases: the first half (progress 0→0.5) goes from 0.98 to 1.02 (EaseOutCubic overshoot), the second half (progress 0.5→1.0) converges from 1.02 to 1.0 (EaseOutQuad). Amplitude is controlled within 2%, just enough to suggest elasticity without feeling cartoonish.

- **Enabled/Disabled Gradient Transition**: Achieves smooth interpolation when IsEnabled toggles through `_disabledProgress` (0 = fully enabled / bright glass, 1 = fully disabled / gray glass). All alpha channels use `Lerp(bright_value, dark_value, _disabledProgress)` rather than ternary hard switches, completely eliminating the instant "gray ↔ bright" jump. Transition speed is `_animSpeed * 0.5`, completing in approximately 0.3 seconds.

- **Micro-Noise Frosted Texture**: A 128×128 seamless grayscale noise map (`WriteableBitmap`), grayscale range 110–155, fixed seed (Random(42)) ensuring all buttons share the same texture. Overlaid at 4% opacity on the glass body, using `Lazy<ImageBrush>` static lazy loading for singleton sharing. Breaks the "plastic feel" of solid color gradients, simulating the micro-diffuse reflection graininess of real frosted glass surface irregularities.

- **Skewed Light Sweep**: On top of the WinForm horizontal light sweep (gradient rectangle + TranslateTransform horizontal translation), adds a `SkewTransform(-20°)` to make the light band sweep diagonally across the button. Visual difference: horizontal sweep looks like a "searchlight", skewed sweep looks like "sunlight through venetian blinds" — more natural and sophisticated. Light sweep parameters remain: 2400ms duration, -0.6→1.6 travel range, EaseOutCubic easing, 5-segment Gaussian attenuation gradient (transparent → light white → pure white → light white → transparent).

**Draw Order** (back to front): Soft drop shadow (outside magnetic offset) → Frosted glass body (semi-transparent cool blue-white gradient, alpha 60→40) → Micro-noise texture → Gradient border highlight → Inner shadow sidewall (deep purple-black refraction) → Diffuse highlight (Fake Blur horizontal fog) → Aurora ambient color injection → Outer glow (gradually brightening and dimming, following `_glowProgress`) → Skewed light sweep → Press inner shadow → Ripple (filled ellipse) → Text → Focus dashed border → Loading/Success/Failure icons.

### 3.2 AuroraStarfield (formerly StarfieldPanel)

**WinForm Version (StarfieldPanel)**: `Panel` subclass, GDI+ drawing of star twinkling, fly-in, meteors, deep-space particles, and mouse glow. Driven by `Timer` frame loop, each frame calling `Invalidate` to trigger `OnPaint`. Aurora effects are absent (deep space background is a solid color gradient), stars are monochrome white dots without trails, constellation lines, or parallax depth.

**WPF Version (AuroraStarfield)**: `FrameworkElement` inheritance, implementing the following major upgrades:

- **CompositionTarget.Rendering 60fps Drive**: Replaces `DispatcherTimer`, aligns with the display refresh rate, avoiding Dispatcher scheduling jitter. Uses `Stopwatch` to calculate real inter-frame time delta (`_frameClock`), all animations based on real-time stepping (`LastFrameMs`), fully decoupled from rendering frame rate.

- **Frame Rate Normalization to 30fps Baseline**: The original WinForms version designed all animation constants around approximately 30fps. WPF actually runs at 60fps, so `_animationTimeScale = clampedMs / 33.333` restores all per-frame animations (aurora, meteors, text transitions) to the original speed, avoiding 2× "fast-forward".

- **Pre-Generated RadialGradientBrush Cache Pool**: The original aurora rendering scheme created 80 `RadialGradientBrush` objects plus 520 `GradientStop` objects per frame, imposing enormous GC pressure. The optimized version pre-generates 2 sets of frozen Brushes per aurora layer (main glow + core radiance), adjusting only the `Brush.Opacity` property at runtime for overall transparency, creating 0 new objects per frame.

- **Brush Caching Eliminates GC Pressure**: `_starBrushCache[256]` plus `_glowBrushCache[256]` pre-create 256 grayscale levels of `SolidColorBrush`, and `_particleBrushCache[121]` covers alpha 0–120. All drawing operations fetch Brushes from cache indices with zero allocation.

- **5-Layer Dynamic Aurora Curtains**: HSV color space (green/cyan/blue-purple/pink-purple/cyan-green), 24 radial glow spots distributed along 6 layers of non-harmonic sine wave superposition paths (frequency 0.003–0.230), MRO vertical alpha modulation (parabolic attenuation), MaxAlpha 145/120/100/85/70 decreasing top to bottom.

- **New Effects**: Star trails (soft elliptical particles, opacity modulated by BaseAlpha), constellation lines (mouse-following dynamic topology, rebuilt every 30 frames, soft glow + main line dual-layer overlay), parallax depth (0.2–1.0, driving size/velocity/entry proportion), star color temperature (5-segment distribution: ice blue 55% / pure white 20% / aurora cyan-green 13% / aurora purple 8% / warm orange 4%), organic twinkling (dual sine wave superposition, fundamental frequency + 2.3× irrational harmonic, never repeating).

- **Twinkling Fade-In Entry**: Single star entry takes 3.5s (EaseOutQuint easing), volume grows slowly from 55% to 100%, staggered 0–5500ms (90% random + 10% radial bias), total spread approximately 5.5s, decoupled from rendering frame rate. Trails and glow rendering are skipped during entry, resulting in extremely low performance overhead.

### 3.3 AuroraConsoleBox (formerly AuroraConsoleBox)

**WinForm Version**: `RichTextBox` derivative, `FormattedText` line-by-line rendering. When new content arrives, it is directly appended to the text box with automatic scrolling to the bottom. No entry animation.

**WPF Version**: `Control` subclass, implementing the following upgrades:

- **Frosted Glass Background**: Fully integrates the `AuroraGlassMaterial` material scheme — dual-layer drop shadow (contact shadow + ambient diffusion) + true blurred background (drawn from shared cache via `DrawImage`, 1/2 resolution `RenderTargetBitmap` + `BlurEffect`) + glass body gradient (`CachedConsoleBodyBrush`, zero allocation) + surface overlay (noise + aurora tinting + top highlight + dual-layer edge + thickness vignette).

- **Batch Row Refresh 50ms Throttling**: Dispatches flush via `Dispatcher.BeginInvoke(Render)`, `_flushScheduled` prevents re-entry, `MinFlushIntervalMs = 33ms` (30fps) throttling. In meteor (PowerShell progress bar) scenarios with 30–100 rows per second, multiple `CollectionChanged` events are merged into a single flush, avoiding per-frame full `OnRender` redraws.

- **Incremental Text Wrapping**: Only wraps newly added text, not existing text. Complexity drops from O(n²) to O(m²) (where m is the number of new characters, typically < 500). In meteor output scenarios, each flush adds only 1–10 new lines.

- **UWP-Style Text Slide-In Animation**: New lines slide in from 1.0 line height below, color transitions from light blue-purple (180,220,255) to normal white, with a 1.5px bright blue top highlight line and a cool blue outer glow around the periphery. Old lines are pushed upward by 0.65 line height. Easing approximates CubicEase EaseOut (`progress += (1-progress) * 0.10`), duration approximately 380ms.

- **320ms Batch Delay + 260ms Smooth Scrolling**: `PendingFlushDelayMs = 320ms` allows high-frequency arriving lines to aggregate into 3–6 line batches, visually appearing as "paragraphs". `SmoothScrollDuration = 260ms` with EaseOutCubic easing makes information changes non-jarring.

### 3.4 AuroraProgressBar (formerly CreateAuroraProgressBar)

**WinForm Version**: Custom `Panel`, drawing track, fill, glow sweep, and particle effects via GDI+. Particles are relatively coarse (large glowing dots scattering randomly).

**WPF Version**: `FrameworkElement` inheritance, fully implementing the AuroraButton-equivalent glass material scheme:

- **Complete Glass Material**: Soft drop shadow (radial gradient shadow, iOS-style) + Glass track (indigo-purple → deep purple-black gradient, alpha 70→25) + Micro-noise texture + Top highlight stroke (alpha 160→40) + Inner shadow sidewall (deep purple-black refraction) + Inner diffuse highlight (Fake Blur horizontal fog).

- **Skewed Light Sweep**: Shares the same `SkewTransform(-20°)` + gradient rectangle (5-segment Gaussian attenuation, peak alpha 235) scheme with AuroraButton. Additionally overlays an aurora cyan-green tint (alpha 80), reinforcing the "aurora" theme.

- **Progress Leading Edge Glow Point**: Outer glow (aurora cyan-green `RadialGradientBrush`, alpha 170) extends to `height * 1.6`, center highlight (alpha 250) is smaller and whiter, simulating "light flow reaching the endpoint".

- **Particle Refinement**: Strictly limits quantity (< 20), reduces diffusion range (horizontal drift 0.15, vertical drift 0.1), shortens lifespan to 0.6–1.6s, changes color to aurora cyan-green (160,255,220), and increases alpha to 160.

### 3.5 AuroraFrostedGlassBorder (New)

AuroraFrostedGlassBorder is an entirely new frosted glass container control introduced in V1.4.27.0, providing unified infrastructure for the application's glass aesthetic. It inherits from `Border` and automatically registers/unregisters with the `AuroraGlassMaterial` shared material system through `Loaded`/`Unloaded` events.

**Four-Layer Rendering Architecture**:

1. **Dual-Layer Drop Shadow**: The `AuroraGlassMaterial.DrawDualShadow` method draws a contact shadow (`RadialGradientBrush`, Center 0.5/0.5, RadiusX/Y 0.6) and an ambient diffusion shadow (larger `RadialGradientBrush`, lower alpha), simulating iOS-style physical depth.

2. **True Blurred Background**: `AuroraGlassMaterial.DrawBlurredBackground` draws the blurred background image from the shared cache. Blur capture is centrally managed by `AuroraGlassMaterial` — 30fps throttled, 1/2 resolution `RenderTargetBitmap` + `BlurEffect` (equivalent radius=6), all glass controls share the same blur result. When no glass controls are active, RTB.Render is completely skipped, zero overhead before Splash/MainForm entry.

3. **Glass Body Gradient**: Uses `AuroraGlassMaterial.CachedGlassBodyBrush` (statically cached, Frozen), a cool blue-white gradient, alpha 50→30, allowing the blurred background to show through and present a frosted texture.

4. **Glass Surface Overlay**: `AuroraGlassMaterial.DrawGlassOverlay` draws four overlay layers in a single pass — noise (8% alpha shared texture) + aurora tinting (sampling `AuroraStarfield.SampleAuroraColorAt` by Y position, `RadialGradientBrush` 4-segment attenuation) + top highlight (alpha 120→0) + dual-layer edge highlight (outer alpha 80→0, inner alpha 30→0) + thickness refraction vignette (`CombinedGeometry.Exclude` ring, deep purple-black alpha 50). All Brushes and Pens are pre-created and Frozen, achieving zero allocation.

### 3.6 AuroraTaskHUD (New)

AuroraTaskHUD is an entirely new task status panel control introduced in V1.4.27.0, used to visually display the current step progress during the repair workflow.

**Core Design**:

- **Horizontal 4-Step Nodes**: Fixed display of 4 step nodes (Environment Detection → Risk Assessment → Targeted Repair → Verification Result), connected by linking lines. Node spacing adapts to control width (`Math.Min(55, (width - 40) / 3)`).

- **Four-State System**: Pending (dark gray solid circle, radius 4px), Running (cyan pulse breathing animation, outer ring 8px + inner core 4px, driven by `sin(breathingValue)`), Success (green solid circle + outer ring, entry with pop animation `EaseOutCubic` + expanding halo), Error (red solid circle + outer ring, entry with pop animation + horizontal shake `sin(progress * 6π) * (1-progress)`).

- **Text Slide-In Animation**: Same text transition state machine as AuroraStarfield — FadingOut (old text slides left 10px, `easeInCubic`) → FadingIn (new text slides in from right 10px, `easeOutCubic`). Text color follows the status color of the currently active node.

- **Frosted Glass Material**: Fully integrates the `AuroraGlassMaterial` four-layer rendering — dual-layer drop shadow + true blurred background + glass body + surface overlay (noise + aurora tinting + highlight + edge + vignette). Maintains visual consistency with `AuroraFrostedGlassBorder` and `AuroraConsoleBox`.

---

## 4. Animation System Comparison

### 4.1 WinForm: Timer-Driven Frame-by-Frame Animation

V1.3.26.7's animation system relied entirely on the PowerShell `System.Windows.Forms.Timer` component. Each control requiring animation independently maintained one or more Timers, updating `Left`, `Top`, `Opacity`, `Size`, and other properties frame by frame in Tick events. This approach had the following inherent problems:

- Unstable frame rate: Timer precision is limited by Windows message pump scheduling (typical precision 15–30ms), and frame rate drops significantly under UI load.
- Dispersed animation logic: Each animation's start value, target value, easing calculation, and duration were scattered across various Timer Tick handlers without a unified animation abstraction.
- Lack of easing functions: All transitions used linear interpolation or simple `+=` advancement, without standard easing curves (EaseIn, EaseOut, BackEase, etc.).

### 4.2 WPF: Dual-Drive Animation Architecture

V1.4.27.0's animation system adopts a dual-drive architecture, selecting the optimal animation mechanism based on different scenarios:

**Storyboard + EasingFunction Drive**: Used for top-level animations such as window entry/exit and view transitions. `DoubleAnimation` / `DoubleAnimationUsingKeyFrames` are declaratively defined in XAML, combined with WPF's built-in `EasingFunctionBase` derived classes (`BackEase`, `CubicEase`, `PowerEase`, `SineEase`) to implement precise easing curves. Storyboards are driven by the WPF animation clock, independent of the UI thread, unaffected by rendering load.

**CompositionTarget.Rendering Drive**: Used for per-frame animations requiring real-time responsiveness — starfield background (star twinkling, meteors, aurora phase), button effects (magnetic attraction, light sweep, ripple, hover/press progress), and progress bar glow.

**4-Stage View Transition Animation**: View transitions (e.g., from main interface to ProMode) employ a carefully choreographed 4-stage sequence animation:

1. **Old Button Exit**: Left-side buttons fade out + slide left one by one, 50ms apart, `BackEase` ease-out.
2. **Old Panel + Title Exit**: Old panel `Opacity` and `TranslateTransform.Y` animate simultaneously, title fades out.
3. **New Panel + Title Entry**: New panel fades in from below, title fades in from above, `CubicEase` ease-out.
4. **New Button Entry**: New buttons slide in from the left one by one, `BackEase` ease-in, elastic overshoot.

During view transitions, the `AuroraTextBlock`'s `IsTextTransitionEnabled` protection mechanism ensures that text does not trigger its own transition animation during panel switching, avoiding visual chaos caused by double animation overlay.

**UWP-Style Easing Curves**: `AuroraCustomEasing.cs` implements standard easing curves from the UWP design language (`UwpEasingCurves.cs`), including `UwpDampedEase` (critically damped spring), `UwpExponentialEase` (exponential decay), and `UwpCubicEase` (cubic). These easing curves give animations a "native Microsoft" fluidity, consistent with the Fluent Design style.

---

## 5. Performance System Comparison

### 5.1 Performance Tier System

| Tier | Target FPS | Particle System | Complex Glow | Dynamic Light Sweep | Path Gradient Shadow | Applicable Scenario |
|------|-----------|----------------|--------------|---------------------|----------------------|---------------------|
| Eco | 30FPS | Off | Off | Off | Off | Low-end hardware / VM, ensures basic runnability |
| Balanced | 60FPS | Off | Off | Off | On | Mid-range hardware, smooth basic effects |
| Performance | 60FPS | On | Off | On | On | High-end hardware, full effects (except complex glow) |
| Extreme | 60FPS | On | On | On | On | Top-tier hardware, all effects enabled |

**WinForm Version**: Performance tiers were determined by PowerShell scripts querying hardware info via `Get-CimInstance` (CPU core count, total memory), computing a score and then setting the global variable `$global:AuroraPerfTier`. Each control read this variable in the script to determine parameters such as particle count and animation frame rate. Detection logic was scattered throughout LauncherGUI, mixed with UI construction code.

**WPF Version**: Performance tiers are centrally managed by the C# static class `AuroraRenderEngine`. The `DetectPerformanceTier` method queries WMI via `ManagementObjectSearcher` (`Win32_ComputerSystem`, `Win32_Processor`), with a scoring algorithm of: cores × 15 + memory (GB) × 5 + base frequency overflow bonus. Score ≥ 240 is Extreme, ≥ 120 is Performance, ≥ 70 is Balanced, otherwise Eco. Detection results are written to process-level environment variables via `Environment.SetEnvironmentVariable("AURORA_PERF_TIER", tier)`, allowing all C# engine layer code to read at maximum speed.

**WPF New Feature**: User-upgradable tiers. When auto-detection yields Eco or Balanced, the system prompts the user via `PerformanceUpgradeDialogView` asking whether to upgrade to the next tier. Upon user confirmation, `AuroraRenderEngine.SetTier(newTier)` is called for real-time switching — re-applying effect toggles, updating environment variables, and all controls automatically adapt to the new tier in the next frame.

### 5.2 Differentiated Effect Toggles

The WPF version implements finely differentiated effect toggles, rather than the WinForm version's binary "all-on/all-off" logic:

- **Particle System**: Enabled only in Performance and Extreme tiers. Affects particle generation and drawing in AuroraProgressBar.
- **Complex Glow**: Enabled only in Extreme tier. Affects AuroraStarfield's `DrawSoftGlow` (`RadialGradientBrush` glow) and AuroraButton's outer glow. This is the most expensive effect — each `DrawSoftGlow` creates a new `RadialGradientBrush` plus 3 `GradientStop` objects.
- **Dynamic Light Sweep**: Enabled in Performance and Extreme tiers. Affects AuroraButton's skewed light sweep and AuroraProgressBar's glow sweep.
- **Path Gradient Shadow**: Enabled in Balanced and above tiers. Affects the `EnablePathGradientShadows` toggle for all controls.

### 5.3 Brush Caching and Zero-Allocation Strategy

The core of WPF version's performance optimization lies in eliminating runtime GC pressure:

- **Frozen Brush Zero Allocation**: In `AuroraGlassMaterial`, all Brushes that do not change per frame (top highlight, outer border, inner shadow, bevel, contact shadow, ambient diffusion, glass body, console body) are pre-created, filled with `GradientStop` objects, and `Freeze()` is called. Frozen Brushes can be safely shared by any thread, and the CLR does not allocate managed memory for them.

- **RadialGradientBrush Pre-Generated Pool**: AuroraStarfield's aurora rendering pre-generates 2 sets of `RadialGradientBrush` per aurora layer (main glow + core radiance), with `GradientStop` alpha ratios fixed, and only `Brush.Opacity` adjusted at runtime. Reduced from 80 `new RadialGradientBrush` + 520 `new GradientStop` per frame to 0 object allocations.

- **SolidColorBrush Cache Arrays**: `_starBrushCache[256]`, `_glowBrushCache[256]`, `_particleBrushCache[121]` pre-create `SolidColorBrush` objects covering the full alpha range. All drawing operations fetch Brushes by array index with zero allocation.

### 5.4 Frosted Glass Refresh Throttling

`AuroraGlassMaterial`'s blurred background capture is the most expensive operation in the entire application — requiring `RenderTargetBitmap.Render` to capture the entire window's visual tree, then applying `BlurEffect`. The WPF version minimizes its performance impact through the following strategies:

- **30fps Throttling**: Blur capture maximum frequency is 30fps (33ms interval), not 60fps. The human eye is insensitive to the update frequency of frosted glass backgrounds; 30fps is sufficiently smooth.
- **1/2 Resolution**: `RenderTargetBitmap` captures at `ActualWidth/2 × ActualHeight/2` resolution, then upscales through `BlurEffect` blur. Resolution drops to 1/4, significantly reducing Rendering time, with equivalent blur radius=6.
- **Skip When No Glass Controls**: During SplashScreen and MainForm entry animations, no glass controls are registered, so `NotifyStarfieldRedrawn` returns immediately with zero overhead. This allows Storyboards to monopolize the UI thread, ensuring smooth entry animations.
- **Shared Cache**: All glass controls (`AuroraFrostedGlassBorder`, `AuroraConsoleBox`, `AuroraTaskHUD`) share the same blurred background image, drawn directly via `dc.DrawImage`, without needing individual captures.

---

## 6. Visual Design Comparison

### 6.1 WinForm: Pure GDI+ Single-Layer Rendering

V1.3.26.7's visual presentation relied entirely on the GDI+ `Graphics` object. All visual effects were simulated through the following methods:

- Semi-transparent gradients: Achieved via `Color.FromArgb(alpha, r, g, b)` setting the alpha channel.
- Glow/Luminescence: Simulated through multiple layers of semi-transparent ellipses superimposed, without true blur.
- Shadows: Simulated through offset-drawn semi-transparent black rectangles.
- Highlights: Simulated through white gradient rectangles drawn at the top.

This approach has clear limitations: no true blur effect (GDI+ does not support `BlurEffect`), all "frosted glass" feel could only be approximated by lowering alpha + overlaying cool-tone gradients, visually presenting a "plastic translucency" rather than "frosted glass" texture.

### 6.2 WPF: Multi-Layer Frosted Glass Material

V1.4.27.0's visual presentation uses `AuroraGlassMaterial` as infrastructure, achieving true multi-layer frosted glass material:

- **True Blurred Background**: `VisualBrush` + `RenderTargetBitmap` + `BlurEffect` (`KernelType.Gaussian`, `RenderingBias.Quality`) achieves true background blur. The starfield, aurora, buttons, and other elements behind the glass are Gaussian-blurred, presenting a genuine "behind frosted glass" visual effect.

- **Micro-Noise Texture**: A 128×128 seamless grayscale noise map (`WriteableBitmap`), overlaid at 4%–8% opacity on the glass surface, simulating the micro-diffuse reflection graininess of real frosted glass. Fixed seed (`Random(42)`) ensures all glass controls share the same texture for visual consistency.

- **Aurora Ambient Color Injection**: The glass material is not a fixed color, but dynamically samples the aurora layer color at the current Y position via `AuroraStarfield.SampleAuroraColorAt(ny, timePhase)`, injecting it into the glass surface. Aurora tinting breathes slowly with aurora phase (`timePhase`) in the 0.85–1.0 range, and the glass color subtly shifts over time as if "refracting" the aurora behind it.

- **Dual-Layer Drop Shadow**: Contact shadow (small-range dark `RadialGradientBrush`, simulating the dark area of a physical contact surface) and ambient diffusion (larger range lighter, simulating ambient light scattering). The dual-layer overlay is closer to real physical lighting than a single-layer shadow, making the control "float" above the background rather than "stick" to it.

- **iOS-Style Luster**: All glass controls have a 1px–1.2px white gradient stroke at the top (alpha 180→15), simulating the sharp reflection of real glass edges. Combined with the inner shadow sidewall (deep purple-black refraction color), it forms a "light-dark" thickness boundary, squeezing a three-dimensional bevel illusion onto a two-dimensional plane.

### 6.3 Visual Comparison Summary

| Dimension | V1.3.26.7 WinForm | V1.4.27.0 WPF |
|-----------|-------------------|---------------|
| Background Blur | No true blur, approximated by translucency + cool gradient | True Gaussian blur (`BlurEffect`), real-time background blur |
| Glass Texture | "Plastic translucency" feel | "Frosted glass" feel, noise texture + aurora tinting + edge highlight |
| Shadows | Single-layer offset rectangle | Dual-layer drop shadow (contact + ambient diffusion), `RadialGradientBrush` |
| Color System | Fixed cool blue-white | Dynamic aurora ambient color injection, sampled by Y position, time-phase breathing |
| Starfield | Solid color background + white dots | 5-layer aurora + star color temperature + parallax depth + trails + constellation lines |
| Lighting Effects | Multi-layer semi-transparent ellipse overlay | `RadialGradientBrush` soft glow + `BlurEffect` outer glow |

---

## 7. Security Comparison

### 7.1 WinForm: PowerShell Script-Level Security

V1.3.26.7's security mechanisms were entirely implemented at the PowerShell script level:

- Startup detection: Determined whether the system was legitimately launched by the EXE by checking if the `$global:syncHash` variable exists. This check could be bypassed by a malicious script setting the global variable before execution.
- File integrity: SHA-256 hash computed via `Get-FileHash` and compared against a hardcoded whitelist, but the whitelist itself was stored in the script, and tampering with the script would bypass the check.
- Trust chain: RSA public key embedded in the script, AES session key derived via PBKDF2 (with only 1,000 iterations, inconsistent with the 100,000 iterations used during build-time encryption).
- Anti-debugging: The `AuroraGuard` class was compiled from C# code via `Add-Type` in PowerShell, detecting `IsDebuggerPresent`, `CheckRemoteDebuggerPresent`, `NtQueryInformationProcess`, etc.

### 7.2 WPF: C# Compile-Level Security

V1.4.27.0's security mechanisms have migrated to the C# compilation layer, significantly enhancing security strength and engineering maturity:

- **IntegrityGuardService**: Complete C# static class implementation, including:
  - 24+ file SHA-256 whitelist verification (covering core engine, security modules, PRO engine, UI controls, animations, repair, Session, and other key files)
  - Runtime integrity monitoring dual-timer (3s periodic + 2–7s random scan)
  - Consecutive 2-confirmation mechanism (`_consecutiveDetectionCount`, preventing false positives)
  - Engine-level secondary integrity check (`_engineIntegrityVerified`)
  - Anti-debugging detection (`IsDebuggerPresent`, `CheckRemoteDebuggerPresent`, PEB `NtGlobalFlag`, hardware breakpoint registers Dr0–Dr3, 30+ debugger process name enumeration)

- **RSA Token Verification**: `RsaTokenService` provides RSA asymmetric encryption-based token issuance and verification, ensuring the trust chain integrity of the elevation workflow.

- **AES-256-CBC Elevation Tokens**: `ElevationTokenService` uses AES-256-CBC mode to encrypt elevation tokens, which contain metadata such as timestamps, session IDs, and permission scopes.

- **Watchdog Service**: `WatchdogService` performs heartbeat detection via named pipe (`AURORA_WD_PIPE`), with session identifier isolation and a 30s timeout automatic restart mechanism. On process exit, pipe resources are safely cleaned up through `IDisposable`.

- **Process Exit Safe Cleanup**: `PowerShellHostService` implements `IDisposable`, calling `_runspacePool.Dispose()` in `Dispose` to clean up all Runspaces. `ElevationTokenService` uses `Array.Clear` via its `Clear` method to zero out key arrays.

### 7.3 Security Comparison Summary

| Dimension | V1.3.26.7 WinForm | V1.4.27.0 WPF |
|-----------|-------------------|---------------|
| Integrity Verification | PowerShell script whitelist, bypassable by script tampering | C# compile-level `IntegrityGuardService`, dual-timer continuous monitoring |
| Trust Chain | RSA public key embedded in script, AES PBKDF2 1,000 iterations | RSA + AES-256-CBC + timestamp tokens, engineered service classes |
| Anti-Debugging | PowerShell-embedded C#, limited detection methods | Full C# implementation, multi-layer detection (PEB, hardware breakpoints, process enumeration) |
| Process Security | `Stop-Process -Force` immediate termination, skips finally cleanup | `IDisposable` pattern, Watchdog Named Pipe heartbeat, safe cleanup |
| Code Protection | Script source visible, XOR obfuscated passwords | IL-compiled `.exe`, significantly higher decompilation difficulty |

---

## 8. Code Quality Comparison

### 8.1 WinForm: Script-Level Engineering

V1.3.26.7's code exhibits typical "script mindset":

- **Single-file monolithic functions**: LauncherGUI at approximately 10,000 lines, mixing embedded C# code, GUI construction, security checks, animation rendering, and session management. PRO engine at approximately 7,800 lines, containing 76+ functions.
- **CHSPRO and ENGPRO duplication**: The two language variants contain approximately 6,000 lines of semantic duplication, with structural drift already present (ENGPRO has unique functions such as `Show-CacheInfo` and `Get-CacheUsageChoice` that CHSPRO lacks).
- **Dot-source implicit dependencies**: All modules are imported via `. "$scriptDir\Module.ps1"`, with dependency relationships entirely reliant on the implicit assumption of "correct import order", and no static analysis tool can detect the dependency chain.
- **Global variable pollution**: `$global:syncHash`, `$global:AuroraPerfTier`, `$global:AURORA_PublicKeyXml`, and others are scattered across modules without centralized management.
- **syncHash polling communication**: GUI and backend communicate via `while ($null -eq $syncHash['UserInput']) { Start-Sleep -Milliseconds 100 }` polling with no timeout protection.

### 8.2 WPF: MVVM Engineering

V1.4.27.0's code reflects professional .NET engineering practices:

- **MVVM Layering**: View (`Views/` directory, XAML + code-behind) → ViewModel (`ViewModels/` directory, data binding + commands) → Service (`Services/` directory, business logic). Single responsibility, each file has a clear role.

- **Dependency Injection**: ViewModels receive Service dependencies through constructor injection (e.g., `MainViewModel` injects `PowerShellHostService`, `SessionCacheService`, `RepairService`, etc.), rather than using global variables.

- **WeakReference to Avoid Memory Leaks**: Event subscriptions use weak reference patterns to prevent event sources from holding strong references to subscribers that would prevent garbage collection.

- **IDisposable Resource Management**: `PowerShellHostService`, `WatchdogService`, and others implement `IDisposable`, releasing `RunspacePool`, `CancellationTokenSource`, `Timer`, and other unmanaged resources in `Dispose`.

- **ObservableObject Base Class**: All ViewModels inherit from `ObservableObject`, implementing `INotifyPropertyChanged` uniformly through `SetProperty<T>(ref field, value, propertyName)`, avoiding repetitive boilerplate code.

- **RelayCommand Command Pattern**: Implements `ICommand` through `RelayCommand`, supporting `Action<object>` execution and `Func<object, bool>` condition checking, moving UI interaction logic from View to ViewModel.

- **Value Converters**: The `Infrastructure/` directory contains 8 value converters (`BooleanToVisibilityConverter`, `InverseBoolConverter`, `StringToVisibilityConverter`, etc.), converting data-bound values to UI properties and eliminating logic from code-behind.

- **Language Service**: `LanguageService` is based on .NET `ResourceManager` + `.resx` resource files, supporting runtime switching (`SetLanguage("CHS"/"ENG")`), with localized text obtained via `Loc["Key"]` indexing. Completely eliminates the CHSPRO/ENGPRO dual-file duplication.

- **Theme System**: The `Themes/` directory contains `AuroraTheme.xaml`, `Brushes.xaml`, `Styles.xaml`, `Templates.xaml`, and `Animations.xaml`, with all colors, fonts, control templates, and animation resources centrally defined, supporting global skinning.

### 8.3 Code Quality Comparison Summary

| Dimension | V1.3.26.7 WinForm | V1.4.27.0 WPF |
|-----------|-------------------|---------------|
| Architecture Pattern | Event-driven, no layering, god object | MVVM three-layer separation, dependency injection |
| File Size | Single file ~10,000 lines / ~7,800 lines | Single file < 2,000 lines, clear responsibilities |
| Language Management | Dual .ps1 files, 6,000 lines duplicated | Single engine + `.resx` resource files |
| Dependency Management | Dot-source implicit dependencies | `.csproj` compile-time references, NuGet package management |
| Resource Management | No explicit cleanup, `Stop-Process -Force` | `IDisposable` pattern, `WeakReference` |
| Code Reuse | Function-level copy-paste | Base class `ObservableObject`, `RelayCommand`, value converters |
| Testability | No module boundaries, cannot be independently tested | Service classes independently mockable, ViewModels unit-testable |
| Version Control | Version number hardcoded in 5+ locations | Assembly version centrally managed (`AssemblyInfo`) |

---

## 9. Summary and Outlook

### 9.1 Core Value of the Architecture Upgrade

The upgrade from V1.3.26.7 to V1.4.27.0 is a **fundamental architectural refactoring**, not a simple framework replacement. Its core value is reflected in the following five aspects:

**A Qualitative Leap in Rendering Capability**: From GDI+ CPU rendering to WPF GPU acceleration, from immediate mode to retained mode, from single-layer translucency to multi-layer true-blur frosted glass material. This is not merely a performance improvement (GPU compositing vs. CPU per-pixel drawing), but a generational leap in visual expressiveness — true Gaussian blur, aurora ambient color injection, micro-noise texture, dual-layer drop shadow, and iOS-style luster are effects that were fundamentally impossible under GDI+.

**A Leap in Engineering Maturity**: From "script mindset" (dot-source implicit dependencies, global variable communication, source-injection builds, monolithic single files) to "software engineering" (MVVM layering, dependency injection, IDisposable resource management, compile-time type checking, CI/CD pipeline). The maintainability, testability, and extensibility of the code have been fundamentally elevated.

**A Definitive Resolution of the Language Architecture**: From CHSPRO/ENGPRO dual-file 6,000-line duplication (with structural drift already present) to a single engine plus `LanguageService` unified management. This was the largest technical debt of the V1.3.26.7 era, and V1.4.27.0 eradicates it in one stroke.

**Engineering of Security Mechanisms**: From PowerShell script-level security checks (bypassable) to C# compile-level `IntegrityGuardService` (dual-timer continuous monitoring, consecutive confirmation mechanism, multi-layer anti-debugging). Security strength has been elevated from "script-level" to "compile-level".

**Unification of Visual Consistency**: All glass controls (`AuroraFrostedGlassBorder`, `AuroraConsoleBox`, `AuroraTaskHUD`) share the `AuroraGlassMaterial` infrastructure, ensuring completely consistent visual style. In the WinForm era, each control independently implemented its own "glass effect", inevitably resulting in subtle visual differences.

### 9.2 Remaining Challenges

Despite the great success of the architecture upgrade, the following areas still have room for improvement:

- **syncHash Communication Pattern Not Fundamentally Changed**: V1.4.27.0 still uses `Hashtable.Synchronized` as the communication bridge between the PowerShell engine and the WPF frontend. Although upgraded from `$global:syncHash` to `PowerShellHostService.SharedSyncHash` (static field + explicit initialization), the communication pattern is still polling rather than event-driven, and key names are still magic strings.

- **PowerShell 5.1 Dependency**: The system still requires PowerShell 5.1 and cannot leverage native parallel features such as `ForEach-Object -Parallel` from PowerShell 7+. The `RunspacePool` parallel processing framework, while complete, has higher code complexity than the PowerShell 7 native solution.

- **C# 5.0 Language Limitations**: Due to targeting .NET Framework 4.8, the C# version is limited to 5.0. Multiple places in the code show the necessity of using additional helper classes (such as `NeighborEntry` and `PendingConn` as tuple substitutes, `NeighborEntryComparer` as a lambda comparator substitute) due to the absence of C# 7+ features (tuples, pattern matching, local functions).

- **No Unit Test Coverage**: Although the MVVM architecture makes unit testing possible (Services are mockable, ViewModels are independently testable), the project has not yet introduced a testing framework (such as xUnit or NUnit). This is a critical step from "testable" to "tested".

### 9.3 Future Evolution Directions

Short-term (1–2 months):

- Introduce the xUnit unit testing framework and write test cases for core Services and ViewModels
- Upgrade syncHash communication from polling to Event-Driven (`EventWaitHandle` or `IProgress<T>`)
- Unify magic string key names as enums or constants

Medium-term (3–6 months):

- Evaluate the feasibility of migrating to .NET 8+ and PowerShell 7+, leveraging `ForEach-Object -Parallel` to simplify parallel code
- Introduce Serilog or NLog structured logging systems to replace the current string-concatenation logging
- Implement Authenticode code signing to replace the current custom integrity verification

Long-term (6–12 months):

- Explore Avalonia UI or .NET MAUI cross-platform solutions to extend AURORA-Analyzer to Linux/macOS
- Implement a plugin architecture to support third-party extended diagnostic rules
- Establish a complete CI/CD pipeline (automated testing → build → signing → release)

---

> **Review Conclusion**: V1.4.27.0 has achieved a qualitative transformation at the architectural level from "script-level tool" to "professional-grade .NET application". MVVM layering, WPF rendering pipeline, C# compile-level security, unified language service, and frosted glass material system — every improvement precisely addresses the core pain points of the V1.3.26.7 era. This is not only AURORA-Analyzer's most significant architecture upgrade to date, but also lays a solid engineering foundation for future evolution.