# AURORA Analyzer V1.4.27.5 Release Notes

> **Windows Event Log Export and Intelligent Diagnostic Tool**
>
> Version: V1.4.27.5Release · Build Date: 2026.07.07 · Author: AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **Warning**: This tool is intended for personal educational use only. Please comply with local laws and regulations.

---

## Table of Contents

1. [Version Overview](#1-version-overview)
2. [P1 Level: Window Enter Animation Unification](#2-p1-level-window-enter-animation-unification)
3. [P2 Level: Window Exit Animation Unification](#3-p2-level-window-exit-animation-unification)
4. [P3 Level: Dialog Window Animation Porting](#4-p3-level-dialog-window-animation-porting)
5. [P4 Level: V5 Glass Material Pipeline Optimization](#5-p4-level-v5-glass-material-pipeline-optimization)
6. [P5 Level: Material Optical Layer Refinement](#6-p5-level-material-optical-layer-refinement)
7. [P6 Level: Jelly Elastic Animation System](#7-p6-level-jelly-elastic-animation-system)
8. [P7 Level: AuroraButton Jelly Rebound](#8-p7-level-aurorabutton-jelly-rebound)
9. [P8 Level: Defect Fixes](#9-p8-level-defect-fixes)
10. [Compatibility Preservation](#10-compatibility-preservation)
11. [Change Summary Table](#11-change-summary-table)

---

## 1. Version Overview

V1.4.27.5 is a comprehensive upgrade release for AURORA Analyzer's animation and material systems. This update covers three core domains: Window Scale Animation Unification, V5 Glass Material Pipeline Optimization (BlurRadius 12→8, BlurSaturation 1.0→1.4, async pipeline 4ms→1.5ms/frame, MaxShaderBlurRadius 8→40), and Jelly Elastic Animation System (hover-exit jelly rebound ~271ms, iOS bounce release, 11 new easing curve classes). The PowerShell engine layer remains compatible, and all command-line parameters, environment variable interfaces, and the syncHash synchronization mechanism are preserved unchanged.

In the area of window scale animation, prior to this version each window's parameters were inconsistent: SplashScreen used enter 1.15→1.0, exit 1.0→1.15 (scale-up departure); MainFormView and ProModeView used enter 1.1→1.0, exit 1.0→0.85 (scale-down departure); ElevationDialogView used enter 1.08→1.0, exit 1.0→0.85; SessionRestoreDialogView had no window-level animation at all; PerformanceUpgradeDialogView used scale-down enter 0.92→1.0 and simple fade-out exit.

V1.4.27.5 achieves comprehensive upgrade through the following core strategies:

- **Enter Unification**: All windows' enter scale unified to 1.15→1.0 (scale-down convergence), with Opacity 0→1 fade-in. Dialog windows use 400ms UwpExpoOutEase easing; main window and PRO mode use 600ms AuroraCustomBackEase easing.
- **Exit Unification**: All windows' exit scale unified to 1.0→1.15 (scale-up departure), with Opacity 1→0 fade-out. Uniformly using 800ms QuadraticEase/CubicEase EaseOut easing.
- **Starfield Lock Unification**: All windows uniformly use IsWindowAnimating to lock starfield background to degraded rendering during enter/exit animations, and Closed events uniformly call StopAnimation to prevent timer leaks.
- **V5 Glass Material Pipeline Optimization**: Fixed RtbBlurBackend hardcoded blur radius and redundant throttle, raised ShaderEffectBackend MaxShaderBlurRadius to 40, calibrated AuroraFluentGlass preset (BlurRadius 12→8, BlurSaturation 1.0→1.4), async-ified render pipeline (UI thread 4ms→1.5ms/frame).
- **14 Optical Layer Refinement**: BodyLayer environment color mixing, SpecularLayer dual light spot + breathing drift, FresnelLayer 4-direction linear gradient rewrite, BevelLayer 4-segment gradient, EdgeHighlightLayer peak reduction, new CausticsLayer and IridescenceLayer.
- **Jelly Elastic Animation System**: AuroraButton hover-exit three-phase jelly rebound (~271ms), iOS bounce release feedback, magnet snap changed to pure EaseOutCubic, control staggered enter 1.07 overshoot convergence, window liquid glass micro-rebound, 11 new easing curve classes.

This update is an "animation and material comprehensive upgrade, bottom-layer compatible" release. All user-facing command-line interfaces, environment variables, and cross-Runspace communication protocols remain fully compatible, ensuring that existing scripts and workflows can run without modification.

---

## 2. P1 Level: Window Enter Animation Unification

P1-level changes unify all windows' enter scale to 1.15→1.0.

### P1-1: Dialog Window Enter Unification (400ms UwpExpoOutEase)

ElevationDialogView, SessionRestoreDialogView, and PerformanceUpgradeDialogView uniformly adopt enter parameters identical to SplashScreen: ScaleTransform 1.15→1.0, Opacity 0→1, 400ms, UwpExpoOutEase (EaseIn) easing. On completion, unlocks starfield and launches control-level staggered enter.

**Reason for Change**: The three dialog windows' enter animation parameters were inconsistent (1.08→1.0, no animation, 0.92→1.0), lacking unity. Unified to Splash style, all dialogs share the same enter visual language.

**Impact Scope**: Enter animations for ElevationDialogView, SessionRestoreDialogView, PerformanceUpgradeDialogView.

---

### P1-2: MainFormView Enter Unification (600ms AuroraCustomBackEase)

MainFormView constructor's preset initial scale is increased from ScaleX=1.1, ScaleY=1.1 to ScaleX=1.15, ScaleY=1.15. PlayWindowEnterAnimation's scale animation start point is changed from 1.1 to 1.15, retaining 600ms duration and AuroraCustomBackEase easing curve.

**Reason for Change**: MainFormView's enter starting scale of 1.1 was inconsistent with SplashScreen's 1.15. Unified to 1.15, all windows share the same enter starting amplitude.

**Impact Scope**: MainFormView's enter animation.

---

### P1-3: ProModeView Enter Unification (600ms AuroraCustomBackEase)

AnimationHelper.PlayProModeWindowEnter's scale animation start point is changed from 1.1 to 1.15, retaining 600ms duration and AuroraCustomBackEase easing curve.

**Reason for Change**: ProModeView's enter starting scale of 1.1 was inconsistent with SplashScreen's 1.15.

**Impact Scope**: ProModeView's enter animation.

---

### P1-4: AnimationHelper.PlayMainWindowEnter Unification

AnimationHelper.PlayMainWindowEnter's scale animation start point is changed from 1.1 to 1.15, retaining 600ms duration and AuroraCustomBackEase easing. This method is used by AuroraExitCountdownView and other windows.

**Reason for Change**: PlayMainWindowEnter's starting scale of 1.1 was inconsistent with Splash style.

**Impact Scope**: All windows using PlayMainWindowEnter.

---

## 3. P2 Level: Window Exit Animation Unification

P2-level changes unify all windows' exit scale to 1.0→1.15 (scale-up departure), replacing the previous 1.0→0.85 (scale-down departure).

### P2-1: MainFormView Exit Unification

MainFormView.PlayWindowScaleAndFadeOut's scale animation is changed from 1.0→0.85 to 1.0→1.15, duration extended from 450ms to 800ms, scale easing changed from CubicEase EaseIn to QuadraticEase EaseOut, fade easing changed from CubicEase EaseIn to CubicEase EaseOut.

**Reason for Change**: MainFormView's scale-down departure (1.0→0.85) was opposite in direction to SplashScreen's scale-up departure (1.0→1.15). Unified to scale-up, all windows share the same exit visual language — "turning into starlight and fading away" rather than "collapsing toward center."

**Impact Scope**: MainFormView's exit animation, including normal exit and PRO mode switching.

---

### P2-2: ProModeView Exit Unification

AnimationHelper.PlayMainWindowExit's scale animation is changed from 1.0→0.85 to 1.0→1.15, duration extended from 450ms to 800ms, scale easing changed from CubicEase EaseIn to QuadraticEase EaseOut, fade easing changed from CubicEase EaseIn to CubicEase EaseOut.

**Reason for Change**: ProModeView exits through PlayMainWindowExit, whose scale-down direction was opposite to Splash style.

**Impact Scope**: ProModeView's exit animation.

---

### P2-3: Dialog Window Exit Unification

ElevationDialogView, SessionRestoreDialogView, and PerformanceUpgradeDialogView's exit scale is unified to 1.0→1.15, 800ms, QuadraticEase/CubicEase EaseOut. ElevationDialogView previously used 1.0→0.85 scale-down; SessionRestoreDialogView had no exit animation; PerformanceUpgradeDialogView used only 180ms simple fade-out.

**Reason for Change**: The three dialogs' exit animations were inconsistent and did not match Splash style. Unified, all windows' exits present the "scale-up dissipation" visual language.

**Impact Scope**: Exit animations for all three dialog windows.

---

## 4. P3 Level: Dialog Window Animation Porting

P3-level changes cover porting the complete Splash-style animation lifecycle to dialog windows that previously lacked animations.

### P3-1: ElevationDialogView RenderTransform Level Fix

ElevationDialogView's RenderTransform is moved from RootGrid to Window level, with TransformGroup (ScaleTransform + TranslateTransform) added to Window.RenderTransform. XAML presets ScaleTransform ScaleX="1.15" ScaleY="1.15" to avoid first-frame flicker.

**Reason for Change**: When RenderTransform was on RootGrid, the OnLoaded animation code operating on this.RenderTransform could not find the target transform, causing the initial scale to never be recovered.

**Impact Scope**: ElevationDialogView's enter/exit animations.

---

### P3-2: SessionRestoreDialogView Complete Animation Porting

SessionRestoreDialogView adds a complete enter/exit animation lifecycle: Window-level RenderTransform, XAML preset ScaleTransform 1.15, OnLoaded enter animation (1.15→1.0, 400ms), PlayWindowExitAnimation exit animation (1.0→1.15, 800ms), Closed event StopAnimation cleanup.

**Reason for Change**: Previously this window had no window-level animation at all; appearance and disappearance were instantaneous.

**Impact Scope**: SessionRestoreDialogView's complete animation lifecycle.

---

### P3-3: PerformanceUpgradeDialogView Animation Upgrade

PerformanceUpgradeDialogView's XAML ScaleTransform initial value is changed from 1.10 to 1.15, enter animation from 0.92→1.0 (scale-down style) to 1.15→1.0 (scale-down convergence), exit from 180ms simple fade-out to 1.0→1.15 scale-up departure 800ms. Adds IsWindowAnimating starfield lock and Closed event StopAnimation cleanup.

**Reason for Change**: Scale-down enter was opposite to Splash style; simple fade-out exit lacked ceremony.

**Impact Scope**: PerformanceUpgradeDialogView's enter/exit animations.

---

### P3-4: Starfield Lock Mechanism Unification

All dialog windows set StarfieldBg.IsWindowAnimating = true in OnLoaded (locked during enter animation), unlock on completion; lock when exit animation starts, call StopAnimation in Closed event.

**Reason for Change**: Some dialog windows previously did not use IsWindowAnimating locking, causing starfield full-effect rendering during window scale animations leading to performance degradation; not calling StopAnimation caused DispatcherTimer leaks.

**Impact Scope**: Starfield background rendering and timer lifecycle for all dialog windows.

---

## 5. P4 Level: V5 Glass Material Pipeline Optimization

P4-level changes cover V5 material pipeline blur backend fixes, material preset calibration, and pipeline architecture improvements.

### P4-1: RtbBlurBackend Hardcoded Blur Radius Fix

Removed the hardcoded `CaptureBlurRadius=3.0` in RtbBlurBackend, replaced with the actual incoming blurRadius parameter × CaptureScale for resolution compensation.

**Reason for Change**: The hardcoded 3.0 fixed all material styles' blur radius to an equivalent 6px, unable to reflect different presets' BlurRadius differences.

**Impact Scope**: RtbBlurBackend.cs lines 257-260.

---

### P4-2: RtbBlurBackend Redundant Throttle Removal

Removed RtbBlurBackend's internal 33ms throttle logic. The pipeline already throttles uniformly via `BackgroundCaptureThrottleMs=33ms`; RTB's internal duplicate throttle caused worst-case ~66ms latency, making aurora blur tracking visibly laggy.

**Reason for Change**: Double-layer throttling caused visible delay in aurora blur during window movement.

**Impact Scope**: RtbBlurBackend.cs lines 113-116.

---

### P4-3: RtbBlurBackend Async Render Pipeline

Changed blur rendering from synchronous to an async two-stage pipeline: UI thread capture (~1.5ms) + background thread Task.Run blur (~2.5ms), reducing UI thread CPU cost from 4ms/frame to 1.5ms/frame.

**Reason for Change**: Synchronous rendering caused the UI thread to block for 4ms on each background capture frame, affecting animation smoothness.

**Impact Scope**: RtbBlurBackend.cs lines 155-174.

---

### P4-4: ShaderEffectBackend MaxShaderBlurRadius Increase

Raised MaxShaderBlurRadius from 8.0 to 40.0, avoiding truncation of high-blur presets (BlurRadius=12 → 12/0.5=24 was truncated to 8). Also added compensation for the 2× visual magnification of blur radius at 1/2 resolution: `shaderEffect.BlurRadius = Math.Min(blurRadius / RenderScale, MaxShaderBlurRadius)`.

**Reason for Change**: High-blur presets being truncated made the glass blur effect inconspicuous.

**Impact Scope**: ShaderEffectBackend.cs lines 41, 138.

---

### P4-5: AuroraMaterialPipeline Shared Capture Parameters

Changed shared capture blur radius from hardcoded 6.0 to the maximum of all registered Composers' `Preset.BlurRadius`; shared saturation takes the maximum of all Composers' `BlurSaturation`.

**Reason for Change**: The hardcoded 6.0 could not adapt to different material styles' blur requirements.

**Impact Scope**: AuroraMaterialPipeline.cs lines 493-506.

---

### P4-6: MaterialStylePreset Calibration (AuroraFluentGlass)

BlurRadius 12→8 (blur doubled too strong after backend fix), BlurSaturation 1.0→1.4 (Mica vibrance +40%), NoiseAmplitude 0.04→0.07 (crosses IsAnimating threshold), RimLightStrength 0.3→0.35. Added complete optical parameters: TintColor(90,200,255), TintStrength 0.15, FresnelStrength 0.25, SpecularStrength 0.5, ChromaticAberration 0.4, RefractionStrength 0.3, BevelDepth 0.6, CausticsStrength 0.35, IridescenceStrength 0.3, etc.

**Reason for Change**: Old preset parameters were incomplete; blur doubled too strong after backend fix; insufficient saturation made the glass appear grayish.

**Impact Scope**: MaterialStylePreset.cs lines 100-120.

---

## 6. P5 Level: Material Optical Layer Refinement

P5-level changes cover per-layer parameter fine-tuning of the 14 optical layers.

### P5-1: BodyLayer Environment Color Mixing

Color mixing changed from pure TintColor constant cold blue to 60% AmbientColor + 40% TintColor. depthFactor 0.6→0.68, bottomAlpha coefficient 0.7→0.78, bottom darkening coefficient 0.7→0.66, border alpha 35→45, directional border alpha 70→55.

**Reason for Change**: Pure TintColor constant cold blue could not respond to ambient color changes, lacking natural feel.

**Impact Scope**: BodyLayer.cs lines 87-97, 104, 106, 114, 149, 175-176.

---

### P5-2: SpecularLayer Dual Light Spot + Breathing Drift

Added secondary light spot (0.72, 0.78) in lower-right quadrant, SecondaryStrengthRatio=0.4. Main spot sin drift (DriftAmplitude=0.02, DriftSpeed=0.0008, ~8 second period). IsBreathing=true for continuous repaint. Color 75% white + 25% AmbientColor.

**Reason for Change**: Old single light spot lacked dynamism; specular highlight was too static.

**Impact Scope**: SpecularLayer.cs lines 47-56, 89, 147-149.

---

### P5-3: FresnelLayer 4-Direction Linear Gradient Rewrite

Rewrote from single RadialGradientBrush to 4 LinearGradientBrush (top/bottom/left/right). Light-facing group (top/left) BrightCoeff=150, back-light group (bottom/right) DimCoeff=30. Band width = 50% of short side. Light-facing group cool color, back-light group warm color (color temperature shift).

**Reason for Change**: Single radial gradient could not express directional fresnel effect, lacking light layering.

**Impact Scope**: FresnelLayer.cs lines 15-27, 40-41, 45, 104-114.

---

### P5-4: BevelLayer 4-Segment Gradient Upgrade

Order 100→95 (swapped with EdgeHighlight). Top depth pen from 2-segment → 4-segment white gradient (peak 80→45→16→0), bottom depth pen from 2-segment → 4-segment black gradient (0→15→45→90). Added top incident highlight band (height=bevelDepth×3.5, peak 130, mid 55) and bottom reflection band (height=bevelDepth×2.5, reflMid 28, reflPeak 45).

**Reason for Change**: 2-segment gradient transitions were harsh, lacking bevel stereoscopic feel.

**Impact Scope**: BevelLayer.cs lines 69, 175-243.

---

### P5-5: EdgeHighlightLayer Peak Reduction

Order 95→100 (swapped with Bevel). BasePeakAlpha 90→60, BrightnessModulation 80→40 (old peak 90-170 was too strong, forming white edges). GaussianSigma 0.22→0.19 (sharper peak), highlight band width 2.0→2.2. IsFlowing independent animation property for continuous 60fps repaint.

**Reason for Change**: Old peak was too high, forming visible white edges on glass edges, not refined enough.

**Impact Scope**: EdgeHighlightLayer.cs lines 58, 63-64, 71, 98, 227.

---

### P5-6: ChromaticLayer/RefractionLayer Reordering

ChromaticLayer Order 40→105 (moved above Body to avoid attenuation), PeakAlphaCoeff 40→80. RefractionLayer Order 30→62 (moved above Body), peak 80→100, back-light side 30→35.

**Reason for Change**: Chromatic aberration and refraction were attenuated under Body, making visual effects inconspicuous.

**Impact Scope**: ChromaticLayer.cs lines 86, 58; RefractionLayer.cs lines 97, 50, 53.

---

### P5-7: New CausticsLayer and IridescenceLayer

CausticsLayer (new in V1.4.29 optical enhancement): Order=75, pre-generates 128×128 sin/cos interference texture, IsFlowing for continuous displacement, BaseOpacity 0.35→0.50. IridescenceLayer: PeakAlphaCoeff 55→75.

**Reason for Change**: Caustics and iridescence are important optical features of real glass; old version lacked them.

**Impact Scope**: CausticsLayer.cs (new file); IridescenceLayer.cs line 39.

---

### P5-8: Other Layer Parameter Optimization

GlowLayer peak 90→100, mid 0.4→0.5, rate 9.0→1.5 (ceremonial feel). InnerGlowLayer peak 60→78→90, strength 0.20→0.30. TintLayer peak 25→30, low 5→7 (brighten ~20%).

**Reason for Change**: Per-layer parameter fine-tuning to coordinate with overall optical effect unity.

**Impact Scope**: GlowLayer.cs, InnerGlowLayer.cs, TintLayer.cs.

---

## 7. P6 Level: Jelly Elastic Animation System

P6-level changes cover the introduction of control-level and window-level jelly elastic animations.

### P6-1: Control Staggered Enter Overshoot Convergence (PlayMetroStaggerEnter)

Scale overshoot peak changed from 1.0 to 0→1.07 (V1.5 overshoot). After main animation reaches 1.07, appends rebound convergence to 1.0, rebound duration 525ms, easing QuarticEase EaseOut, triggered via DispatcherTimer after durationMs.

**Reason for Change**: Old control enter had no overshoot, lacking the elastic texture of liquid glass.

**Impact Scope**: AnimationHelper.cs PlayMetroStaggerEnter lines 688-732.

---

### P6-2: Panel Enter Overshoot Convergence (PlayPanelEnter)

Scale changed from 0.92→1.0 to 0.92→1.07 (V1.5 overshoot), duration 360ms. Appends 1.07→1.0 jelly spring-in, 525ms QuarticEase EaseOut.

**Reason for Change**: Panel enter had no overshoot, inconsistent with control staggered enter style.

**Impact Scope**: AnimationHelper.cs PlayPanelEnter lines 476-509.

---

### P6-3: Window Enter Liquid Glass Micro-Rebound (PlayMainWindowEnter)

After window scale 1.15→1.0 completes, appends liquid glass micro-rebound: first segment 1.0→1.03 (120ms QuadraticEase EaseOut), second segment 1.03→1.0 (280ms QuarticEase EaseOut).

**Reason for Change**: Window enter scale linear convergence to 1.0 lacked elastic finish.

**Impact Scope**: AnimationHelper.cs PlayMainWindowEnter lines 169-208.

---

### P6-4: Window Exit Elastic Wind-Up (PlayMainWindowExit)

Exit changed from monotonic scale-up to first micro-shrink wind-up then scale-up departure: wind-up 1.0→0.97 (80ms QuadraticEase EaseOut), scale-up departure 0.97→1.15 (720ms QuadraticEase EaseOut), fade-out 1→0 (800ms CubicEase EaseOut).

**Reason for Change**: Monotonic scale-up lacked the "wind-up release" elastic feel.

**Impact Scope**: AnimationHelper.cs PlayMainWindowExit lines 225-252.

---

### P6-5: iOS Bounce Button Tap Feedback (PlayIOSTapSpring)

Added iOS-style bounce tap feedback, 300ms three-phase keyframe: 0-60% 1.0→0.96 (CubicEase EaseIn light press), 60-85% 0.96→1.02 (CubicEase EaseOut first overshoot), 85-100% 1.02→1.0 (QuadraticEase EaseOut convergence).

**Reason for Change**: Old button tap had no elastic feedback, lacking tactile feel.

**Impact Scope**: AnimationHelper.cs PlayIOSTapSpring lines 755-783.

---

### P6-6: Easing Curve Library 11 New Classes

Added AuroraCustomEasing.cs (5 classes: AuroraCustomBackEase, AuroraSpringEase, AuroraElasticEaseOut, AuroraElasticEaseIn, AuroraBounceEaseOut) and UwpEasingCurves.cs (6 classes: UwpStandardEase, UwpAccelEase, UwpDecelEase, UwpExpoOutEase, UwpDampedEase, IOSBounceEase).

**Reason for Change**: Old version only used WPF built-in easing, unable to accurately reproduce UWP/iOS style curves.

**Impact Scope**: AuroraCustomEasing.cs (new file), UwpEasingCurves.cs (new file).

---

## 8. P7 Level: AuroraButton Jelly Rebound

P7-level changes cover AuroraButton's jelly elastic interaction animations.

### P7-1: Hover-Exit Jelly Rebound (V1.5 Liquid Glass New)

Added `_hoverExitSpringProgress` / `_hoverExitSpringActive` fields. On mouse leave, triggers three-phase jelly rebound (total duration ~271ms): 0→0.35 1.05→0.96 (EaseOutCubic inertial undershoot), 0.35→0.65 0.96→1.02 (EaseInOutQuad elastic recovery), 0.65→1.0 1.02→1.0 (EaseOutQuart graceful return). Cancelled immediately on re-hover.

**Reason for Change**: Old hover-exit linear regression to 1.0 lacked jelly elasticity.

**Impact Scope**: AuroraButton.cs lines 84-85, 535-551, 580-588, 912-939.

---

### P7-2: iOS Bounce Release Feedback

Added `_iosReleaseSpringProgress` / `_iosReleaseSpringActive` fields. Triggered on PreviewMouseUp / KeyUp(Enter/Space), 600ms 0→1: 0..0.5 0.98→1.02 (EaseOutCubic slight overshoot), 0.5..1.0 1.02→1.0 (EaseOutQuad convergence). Amplitude 2%.

**Reason for Change**: Button release lacked bounce tactile feel.

**Impact Scope**: AuroraButton.cs lines 76-77, 353-354, 383-384, 565-573, 940-959.

---

### P7-3: Magnet Snap Improvement

Old UwpDampedEase three-segment interpolation (3.5% overshoot) changed to pure EaseOutCubic `1-(1-t)³`, no overshoot, no reverse offset, 500ms.

**Reason for Change**: Old magnet offset would cross center to opposite side, "first rebound, then swing to the other end" felt deliberate.

**Impact Scope**: AuroraButton.cs lines 801-823.

---

### P7-4: Aurora Ambient Color Injection

Added `_ambientColor` / `_ambientStrength` / `_ambientTargetStrength` / `_ambientPhase` fields and `EnableAmbientColorInjection` property. UpdateAmbientInjection() samples aurora color each frame + three-state strength progression (Normal 0 / Hover 0.50 / Press 0.80).

**Reason for Change**: Old buttons did not respond to ambient color, inconsistent with glass material's ambient color mixing.

**Impact Scope**: AuroraButton.cs lines 185-191, 677.

---

## 9. P8 Level: Defect Fixes

P8-level changes cover key defects fixed in this version.

### P8-1: ElevationDialogView Control Size Anomaly

**Issue**: ElevationDialogView's RenderTransform was placed on RootGrid, but the OnLoaded animation code operated on this.RenderTransform (Window level). The Window level had no RenderTransform, so the animation silently failed, and RootGrid's 1.10x scale was never recovered, causing all controls to appear 10% larger.

**Fix**: Moved RenderTransform and ScaleTransform from RootGrid to Window level.

**Reason**: RenderTransform level did not match the animation code's operating target.

**Impact Scope**: All control sizes in ElevationDialogView.

---

### P8-2: SessionRestoreDialogView C# 5 Compatibility

**Issue**: SessionRestoreDialogView.xaml.cs used C# 6's ?. null-conditional operator (three instances), causing CS1525/CS1003 errors under the C# 5 compiler.

**Fix**: Replaced x?.Method() with if (x != null) x.Method() syntax.

**Reason**: The project uses C# 5.0 language version for compilation, ensuring PowerShell 5.1 compatibility.

**Impact Scope**: SessionRestoreDialogView.xaml.cs compilation.

---

### P8-3: Starfield DispatcherTimer Leak

**Issue**: Some dialog windows did not call StarfieldBg.StopAnimation() after closing, causing the starfield's DispatcherTimer to continue refreshing in the background, leading to memory leaks.

**Fix**: All windows' Closed events uniformly call StarfieldBg.StopAnimation().

**Reason**: Missing Closed event cleanup logic.

**Impact Scope**: Post-close behavior for ElevationDialogView, SessionRestoreDialogView, PerformanceUpgradeDialogView.

---

## 10. Compatibility Preservation

Although V1.4.27.5 has undergone a comprehensive animation and material system upgrade, it maintains full compatibility with V1.4.27.1 in the following aspects:

| Compatibility Item | Description |
|--------------------|-------------|
| PowerShell 5.1 Compatibility | C# code continues to use C# 5.0 language version, ensuring operation in PowerShell 5.1 environment |
| Command-Line Parameters | All command-line parameters are fully compatible, with no additions or removals |
| syncHash Synchronization Mechanism | The cross-Runspace communication syncHash interface is fully compatible |
| Environment Variable Interface | All environment variable interfaces are fully compatible |
| Script Interface | PowerShell script engine requires no modification |
| Material Pipeline | V5 material pipeline params optimized, but UseV5Pipeline switch behavior unchanged; UseV5Pipeline=false can still fall back to v4 path |
| Material Layer Interface | 14 optical layer interfaces and registration mechanism unchanged, only params adjusted |
| Control Animation Interface | Control-level animation method signatures and invocation unchanged, only internal easing params adjusted |

---

## 11. Change Summary Table

| No. | Tier | Change Description | Reason for Change | Impact Scope |
|-----|------|-------------------|-------------------|--------------|
| P1-1 | P1 | Dialog enter unified to 1.15→1.0 | Three dialogs had inconsistent enter parameters | ElevationDialog/SessionRestore/PerformanceUpgrade enter |
| P1-2 | P1 | MainFormView enter 1.1→1.15 | Starting scale inconsistent with Splash | MainFormView enter |
| P1-3 | P1 | ProModeView enter 1.1→1.15 | Starting scale inconsistent with Splash | ProModeView enter |
| P1-4 | P1 | PlayMainWindowEnter 1.1→1.15 | Starting scale inconsistent with Splash | AuroraExitCountdown and other windows enter |
| P2-1 | P2 | MainFormView exit 1.0→0.85 changed to 1.0→1.15 | Scale-down opposite to Splash scale-up | MainFormView exit |
| P2-2 | P2 | PlayMainWindowExit 1.0→0.85 changed to 1.0→1.15 | Scale-down opposite to Splash scale-up | ProModeView exit |
| P2-3 | P2 | Dialog exit unified to 1.0→1.15 | Three dialogs had inconsistent exit parameters | ElevationDialog/SessionRestore/PerformanceUpgrade exit |
| P3-1 | P3 | ElevationDialog RenderTransform moved to Window level | Animation couldn't find target on RootGrid | ElevationDialog enter/exit |
| P3-2 | P3 | SessionRestoreDialog complete animation porting | Previously had no window-level animation | SessionRestoreDialog complete lifecycle |
| P3-3 | P3 | PerformanceUpgradeDialog animation upgrade | Scale-down enter and simple fade-out inconsistent with Splash | PerformanceUpgradeDialog enter/exit |
| P3-4 | P3 | Starfield lock mechanism unification | Some windows didn't lock starfield or clean up timers | All dialog windows' starfield background |
| P4-1 | P4 | RtbBlurBackend hardcoded blur radius fix | Hardcoded 3.0 fixed all styles' blur | RtbBlurBackend blur radius |
| P4-2 | P4 | RtbBlurBackend redundant throttle removal | Double-layer throttle caused ~66ms latency | RtbBlurBackend throttle |
| P4-3 | P4 | RtbBlurBackend async render pipeline | Sync rendering blocked UI thread 4ms/frame | RtbBlurBackend render performance |
| P4-4 | P4 | ShaderEffectBackend MaxShaderBlurRadius 8→40 | High-blur presets truncated | ShaderEffectBackend blur truncation |
| P4-5 | P4 | AuroraMaterialPipeline shared capture parameters | Hardcoded 6.0 couldn't adapt to different styles | AuroraMaterialPipeline shared parameters |
| P4-6 | P4 | MaterialStylePreset calibration | Blur doubled too strong, saturation insufficient | AuroraFluentGlass preset |
| P5-1 | P5 | BodyLayer environment color mixing | Pure TintColor constant cold blue didn't respond to ambient color | BodyLayer color mixing |
| P5-2 | P5 | SpecularLayer dual light spot + breathing drift | Single light spot lacked dynamism | SpecularLayer light spot and drift |
| P5-3 | P5 | FresnelLayer 4-direction linear gradient rewrite | Single radial gradient lacked directionality | FresnelLayer gradient structure |
| P5-4 | P5 | BevelLayer 4-segment gradient upgrade | 2-segment gradient transitions were harsh | BevelLayer gradient segments |
| P5-5 | P5 | EdgeHighlightLayer peak reduction | Peak too high formed white edges | EdgeHighlightLayer peak parameters |
| P5-6 | P5 | Chromatic/Refraction layer reordering | Attenuated under Body | Chromatic/Refraction layer ordering |
| P5-7 | P5 | New CausticsLayer and IridescenceLayer | Caustics and iridescence optical features missing | CausticsLayer/IridescenceLayer |
| P5-8 | P5 | Other layer parameter optimization | Coordinate with overall optical effect unity | Glow/InnerGlow/TintLayer |
| P6-1 | P6 | Control staggered enter overshoot convergence | Old version had no overshoot, lacked elasticity | PlayMetroStaggerEnter |
| P6-2 | P6 | Panel enter overshoot convergence | Panel enter had no overshoot | PlayPanelEnter |
| P6-3 | P6 | Window enter liquid glass micro-rebound | Linear convergence lacked elastic finish | PlayMainWindowEnter |
| P6-4 | P6 | Window exit elastic wind-up | Monotonic scale-up lacked wind-up feel | PlayMainWindowExit |
| P6-5 | P6 | iOS bounce button tap feedback | Old tap had no elastic feedback | PlayIOSTapSpring |
| P6-6 | P6 | Easing curve library 11 new classes | WPF built-in easing couldn't reproduce UWP/iOS | AuroraCustomEasing/UwpEasingCurves |
| P7-1 | P7 | Hover-exit jelly rebound | Linear regression lacked jelly elasticity | AuroraButton hover exit |
| P7-2 | P7 | iOS bounce release feedback | Button release lacked bounce tactile feel | AuroraButton release feedback |
| P7-3 | P7 | Magnet snap improvement | Old overshoot to opposite side felt deliberate | AuroraButton magnet rebound |
| P7-4 | P7 | Aurora ambient color injection | Buttons didn't respond to ambient color | AuroraButton ambient color injection |
| P8-1 | P8 | ElevationDialog control size anomaly fix | RenderTransform level error | ElevationDialog control sizes |
| P8-2 | P8 | SessionRestoreDialog C# 5 compatibility fix | Used C# 6 ?. operator | SessionRestoreDialog compilation |
| P8-3 | P8 | Starfield DispatcherTimer leak fix | Closed event didn't call StopAnimation | Dialog windows' post-close behavior |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *This tool is intended for personal educational use only. Please comply with local laws and regulations.*
