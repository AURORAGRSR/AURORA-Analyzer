# AURORA Analyzer V1.4.27.1 Release Notes

> **Windows Event Log Export and Intelligent Diagnostic Tool**
>
> Version: V1.4.27.1Release · Build Date: 2026.07.03 · Author: AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **Warning**: This tool is intended for personal educational use only. Please comply with local laws and regulations.

---

## Table of Contents

1. [Version Overview](#1-version-overview)
2. [P1 Level: V5 Advanced Material Pipeline](#2-p1-level-v5-advanced-material-pipeline)
3. [P2 Level: Control V5 Pipeline Upgrade](#3-p2-level-control-v5-pipeline-upgrade)
4. [P3 Level: Glass Visual Optimization](#4-p3-level-glass-visual-optimization)
5. [P4 Level: Defect Fixes](#5-p4-level-defect-fixes)
6. [Compatibility Preservation](#6-compatibility-preservation)
7. [Change Summary Table](#7-change-summary-table)

---

## 1. Version Overview

V1.4.27.1 is a material system refinement release for AURORA Analyzer. The core change in this update is the introduction of the V5 advanced material pipeline, a comprehensive layered refactoring and visual tuning of the V1.4.27.0 four-layer glass rendering system. The PowerShell engine layer remains compatible, and all command-line parameters, environment variable interfaces, and the syncHash synchronization mechanism are preserved unchanged.

The AuroraGlassMaterial shared material system introduced in V1.4.27.0 achieved frosted glass effects through a four-layer rendering pipeline (dual drop shadows, true blurred background, glass body gradient, surface overlay). However, in actual use, the system exposed several visual defects: stretched and distorted backgrounds inside the glass, hard circular rings at edges, hover highlights concentrating only at the four corners, flat color sampling without depth, and choppy brightness transitions.

V1.4.27.1 resolves these issues through the following three core strategies:

- **V5 Material Pipeline Introduction**: Refactored the glass rendering from a four-layer flat pipeline into a nine-layer independent layered architecture (L1 Backend / L2 Layers / L3 Composer / L4 Controls), where each layer is computed independently and composited in order, decoupled from controls through the IMaterialSurfaceHost interface.
- **Deep Visual Detail Tuning**: Conducted repeated tuning of edge highlight distribution, color sampling layers, hover transition curves, and other visual details, introducing the EaseInOutCubic easing curve for a 3-second ceremonial transition.
- **Timing Race Defect Fix**: Fixed a隐蔽 defect where the background source was incorrectly cleared during window switching, causing the main interface glass blur to be missing.

This update is a "visual polishing, bottom-layer compatible" release. All user-facing command-line interfaces, environment variables, and cross-Runspace communication protocols remain fully compatible, ensuring that existing scripts and workflows can run without modification.

---

## 2. P1 Level: V5 Advanced Material Pipeline

P1-level changes are the core architectural introduction of the V5 material pipeline. This is a fundamental layered refactoring of the V1.4.27.0 four-layer rendering pipeline.

### P1-1: Nine-Layer Independent Rendering Architecture

V1.4.27.0's AuroraGlassMaterial coupled the four rendering layers (shadow, blur, gradient, noise) in a single class with hardcoded inter-layer parameters, making independent adjustment difficult. V1.4.27.1 decomposes this into nine independent IMaterialLayer implementations, rendered sequentially sorted by the Order property:

| Layer | Order | Responsibility |
|-------|-------|---------------|
| ShadowLayer | 10 | Dual drop shadow: outer soft glow + inner sharp boundary |
| BlurLayer | 20 | True blurred background: RenderTargetBitmap capture + GaussianBlur |
| TintLayer | 50 | Ambient tint: vertical dual-point gradient color sampling |
| BodyLayer | 60 | Glass body: rounded rectangle fill + soft border |
| NoiseLayer | 70 | Frosted noise: equal-brightness atlas + cross-fade |
| FresnelLayer | 80 | Fresnel edge reflection: 55% wide transition zone |
| BevelLayer | 100 | Bevel thickness: bright top + dark bottom for stereo edges |
| ScanlineLayer | 120 | Scanline texture (Holographic style only) |
| GlowLayer | 130 | Hover outer glow: 4-edge uniform highlight + ceremonial transition |

Each layer independently determines whether to participate in rendering through the IsEnabled interface, updates its internal state through the Update interface, and draws independently through the Render interface. Layers are decoupled, with all parameters driven through the MaterialStylePreset.

**Reason for Change**: V1.4.27.0's four-layer coupled architecture made it difficult to independently tune layer parameters and could not support differentiated material styles like Mica/Holographic. The nine-layer independent architecture allows each layer's parameters to be adjusted independently and supports runtime style switching through the preset system.

**Impact Scope**: Glass rendering for all controls using the V5 pipeline is scheduled through AuroraMaterialComposer's nine-layer rendering.

---

### P1-2: IMaterialSurfaceHost Interface and AuroraMaterialComposer

V1.4.27.1 introduces the IMaterialSurfaceHost interface, providing two material surface properties: CornerRadius and Depth. Controls implementing this interface can connect to the V5 pipeline.

AuroraMaterialComposer is the material compositor instance held by each V5 control, responsible for:
- Registering/unregistering with AuroraMaterialPipeline on Loaded/Unloaded
- Calling `_composer.Render(dc)` to delegate nine-layer rendering on OnRender
- Forwarding mouse position, size change, and other events
- Providing the UseV5Pipeline switch: true for V5 pipeline, false for V4 fallback

**Reason for Change**: V1.4.27.0's AuroraGlassMaterial was a global shared singleton, preventing controls from independently configuring material styles. The Composer pattern allows each control to hold an independent compositor instance, supporting independent material presets and state management.

**Impact Scope**: All controls upgraded to the V5 pipeline use AuroraMaterialComposer.

---

### P1-3: Four Material Style Presets

V1.4.27.1 defines four differentiated material styles through MaterialStylePreset, switchable at runtime via the MaterialKind enum:

| Style | Characteristics | Use Case |
|-------|----------------|----------|
| AuroraFluentGlass | Standard frosted glass, all nine layers enabled | Default style |
| LiquidGlass | Liquid glass, stronger fresnel and highlights | Highlighted interactive elements |
| Mica | Mica style, skips noise and blur layers, enables DWM Acrylic backend | Window-level backgrounds |
| Holographic | Holographic style, enables scanline layer | Sci-fi themes |

Each style controls parameters for each layer's blur radius, opacity, animation speed, glow intensity, etc., through independent parameter presets.

**Reason for Change**: V1.4.27.0 supported only a single glass style, unable to meet the differentiated visual needs of different UI elements. The preset system allows the same rendering pipeline to support multiple material expressions.

**Impact Scope**: All V5 controls can switch material styles through the MaterialKind property.

---

### P1-4: Five-Level Blur Backend Fallback Chain

V1.4.27.1 implements a five-level blur backend fallback chain, automatically selecting the optimal backend based on system capabilities:

| Priority | Backend | Description |
|----------|---------|-------------|
| 1 | DwmAcrylicBackend | Win11 DWM Acrylic/Mica (requires explicit window backdrop enablement) |
| 2 | ShaderEffectBackend | HLSL shader blur (CPU software rasterization) |
| 3 | RtbBlurBackend | RenderTargetBitmap + BlurEffect (implemented) |
| 4 | D3D9ExBackend | Direct3D 9Ex hardware blur (reserved) |
| 5 | SolidFallbackBackend | Solid color fallback (reserved) |

Remote sessions and virtual machine environments forcibly disable GPU backends, falling back to RTB software blur.

**Reason for Change**: V1.4.27.0 only used the RTB blur backend, unable to leverage DWM native Acrylic capability on Win11 systems. The multi-level fallback chain ensures the best available blur effect in all environments.

**Impact Scope**: Blur background rendering for all V5 controls.

---

## 3. P2 Level: Control V5 Pipeline Upgrade

P2-level changes cover the migration of controls in PRO mode from V4 rendering to the V5 pipeline. All upgrades follow a unified V5 migration pattern: implement the IMaterialSurfaceHost interface, use AuroraMaterialComposer, register/unregister with AuroraMaterialPipeline, forward mouse events, and provide V4 fallback.

### P2-1: AuroraConsoleBox V5 Upgrade

AuroraConsoleBox implements the IMaterialSurfaceHost interface, replacing the old four-step glass drawing in OnRender with `_composer.Render(dc)` delegation. Registers/unregisters with Pipeline on Loaded/Unloaded, forwards SetMousePosition on MouseMove, and notifies OnSizeChanged on OnRenderSizeChanged. When UseV5Pipeline=false, falls back to the AuroraGlassMaterial legacy path.

**Purpose**: Frosted glass background for the PRO mode console.

---

### P2-2: AuroraTaskHUD V5 Upgrade

AuroraTaskHUD is upgraded to the V5 pipeline following the same pattern as AuroraConsoleBox.

**Purpose**: Frosted glass background for the PRO mode task progress HUD.

---

### P2-3: AuroraPrivilegeIndicator V5 Upgrade

AuroraPrivilegeIndicator is upgraded to the V5 pipeline following the same pattern.

**Purpose**: Frosted glass background for the PRO mode privilege status indicator.

---

### P2-4: AuroraProgressBar V5 Upgrade

AuroraProgressBar's OnRender inserts `_composer.Render(dc)` at the beginning, replacing the old five-step manual drawing (shadow + track + noise + highlight + inner shadow), while preserving ProgressBar-specific logic such as progress fill, sweep light, leading-edge glow, and particles.

**Purpose**: Frosted glass background for the PRO mode progress bar.

---

## 4. P3 Level: Glass Visual Optimization

P3-level changes focus on visual detail tuning of the glass material. These changes do not affect functional behavior but significantly enhance visual quality and interaction ceremony.

### P3-1: Edge Highlight "Four-Corner-Only" Fix

V1.4.27.0's GlowLayer used a single RadialGradientBrush (RadiusX=RadiusY=0.62), producing circular isolines. Inside a rounded rectangle, circular isolines only approach the edge near the four corners, causing the corners to be brighter than the edge midpoints.

V1.4.27.1 changes GlowLayer to 4 LinearGradientBrushes, each responsible for one edge fading toward the center. The isolines become "distance to nearest edge," evenly distributed along the rounded rectangular edge. The four corners are overlaid by 2 adjacent brushes, slightly brighter but natural (physically correct corner reflection).

**Reason**: Circular radial gradient isolines only approach the edge at the four corners inside a rectangular control, causing uneven highlight distribution. Changing to four-edge linear gradients distributes isolines evenly along the edge.

---

### P3-2: Glass Color Vertical Gradient

V1.4.27.0's AuroraMaterialComposer sampled only the top Y position of the control for aurora color, using the same AmbientColor for the entire glass, making tall controls flat and lifeless.

V1.4.27.1 samples three Y positions (top, center, bottom) in Update, and TintLayer changes from RadialGradientBrush to LinearGradientBrush with 4 GradientStops: top edge fade-out → upper-middle peak(topColor) → lower-middle peak(bottomColor) → bottom edge fade-out, simulating the aurora's top-to-bottom hue shift.

**Reason**: Single sampling point caused flat color for tall controls. Three-point sampling + vertical linear gradient simulates real aurora hue layering.

---

### P3-3: Hover Transition Ceremony

V1.4.27.0's GlowLayer used pure exponential smoothing (rate=9.0, ~0.5s completion), transitioning too quickly without ceremony.

V1.4.27.1 introduces a _glowProgress progress variable (0..1) + EaseInOutCubic curve mapping. Rate reduced to 1.5 (~3s for 99% completion). The curve decelerates at both ends: the beginning is nearly imperceptible (only 3.2% strength at t=0.2), the middle progresses steadily, and the end converges gracefully.

**Reason**: Pure ease-out curve is fastest at the start and slowest at the end, lacking composure. EaseInOutCubic decelerates at both ends, with a 3-second transition providing more ceremony.

---

### P3-4: SpecularLayer Removal (Mouse-Following Highlight)

V1.4.27.0's SpecularLayer implemented a white highlight following the mouse position, but in actual use the visual effect was not noticeable and added per-frame Brush property update overhead.

V1.4.27.1 completely removes SpecularLayer (including the file, Composer registration, and HasActiveAnimation branches), preserving the SpecularStrength preset field to avoid breaking structural compatibility. Hover feedback is carried entirely by GlowLayer.

**Reason**: Mouse-following highlight had low actual visual value. Removal makes the visual expression purer and reduces unnecessary rendering overhead.

---

### P3-5: NoiseLayer Brightness Jump Fix

V1.4.27.0's NoiseLayer used an 8-frame atlas with increasing brightness (128→177), producing a per-second brightness drop when looping. Frame switching was integer hard-cut, causing abrupt jumps every 125ms.

V1.4.27.1 changes the atlas to per-frame independent random equal-brightness generation (average brightness fixed at 128), and implements cross-fade: continuous frame position + blend factor + dual brush overlay.

**Reason**: Increasing-brightness atlas + hard-cut frame switching caused periodic brightness jumps. Equal-brightness atlas + cross-fade eliminates jumps.

---

### P3-6: BodyLayer and FresnelLayer Edge Softening

V1.4.27.0's BodyLayer used a 1px white border (alpha=80), and FresnelLayer used a 15% narrow transition zone (0.85→0.95→1.0) with peak alpha=216, causing a visible hard circular ring at the glass edge.

V1.4.27.1 reduces BodyLayer border alpha to 35 and changes color to tint+40; FresnelLayer radius 0.5→0.62, transition zone widened to 55% (0.45→0.72→0.9→1.0), peak alpha reduced to 130.

**Reason**: Hard white border + narrow transition zone caused a visible hard ring. Reducing border alpha and widening the transition zone lets the edge blend naturally.

---

### P3-7: AuroraStarfield Weighted Color Sampling

V1.4.27.0's SampleAuroraColorAt used discrete layer selection (bestInfluence comparison), causing instant color jumps at layer transitions.

V1.4.27.1 changes to all-layer weighted RGB accumulation normalization: each layer is weighted by influence (raw²), modulated by breath, and finally normalized. Inter-layer transitions are smooth without jumps.

**Reason**: Discrete layer selection caused color mutations at switch points. Weighted blending achieves smooth inter-layer transitions.

---

## 5. P4 Level: Defect Fixes

P4-level changes cover key defects fixed in this version.

### P4-1: Window Switching Timing Race Fix

V1.4.27.0's AuroraStarfield.Unloaded unconditionally called ClearBackgroundSource(). In the startup chain splash→permission window→mainformview→pro, the old window's Unloaded could fire after the new window's SetBackgroundSource, incorrectly clearing the background source already registered by the new window. This caused mainformview's glass to fail to obtain blur sampling, showing transparent glass without blur.

V1.4.27.1's ClearBackgroundSource adds an optional source parameter, only clearing when the currently registered background source is itself. AuroraStarfield.Unloaded passes this.

**Reason**: Unconditional clearing caused old window's Unloaded to incorrectly clear the new window's background source. Identity verification ensures only the registered owner can clear.

**Impact Scope**: Background source handoff for all windows in the startup chain.

---

### P4-2: DwmAcrylicBackend Misselection Fix

V1.4.27.0's DwmAcrylicBackend.IsAvailable only probed platform capabilities (Win11 + DWM available) without checking whether ApplyWindowBackdrop had been called to enable Mica. This caused windows without Mica enabled (such as MainFormView) to select the DwmAcrylic backend, where CaptureAndBlur returned null and BlurLayer skipped rendering.

V1.4.27.1 adds a _backdropApplied flag, requiring IsAvailable to be true. When Mica is not enabled, falls back to ShaderEffect or RTB backend.

**Reason**: DwmAcrylicBackend is a window-level backend that requires Mica to be enabled first to provide blur. Should not be selected when Mica is not enabled.

**Impact Scope**: Blur backend selection for all windows without explicitly enabled Mica.

---

### P4-3: Animation Speed Parameter Ineffectiveness Fix

V1.4.27.0's GlowLayer used a fixed smoothFactor=0.15 (equivalent to rate=9.0) when DeltaMs<=0, completely bypassing the rate parameter. Additionally, AuroraMaterialComposer's first frame had DeltaMs of hundreds of milliseconds (_lastTimeMs=0), causing smoothFactor≈1.0 and _glowProgress to instantly jump to 1.0, skipping the entire transition animation.

V1.4.27.1's fallback also calculates based on rate (assuming 60fps), and clamps DeltaMs to a 100ms upper limit.

**Reason**: Fixed fallback value bypassed rate + first-frame DeltaMs transient caused animation to be skipped. Unified fallback logic + DeltaMs clamping ensures parameters take effect.

**Impact Scope**: Animation transitions for all layers using DeltaMs smoothing.

---

### P4-4: BlurLayer Background Stretch Fix

V1.4.27.0's BlurLayer stretched the entire starfield sample with Stretch=Fill to the surface rectangle when BackgroundSourceRect was empty or TransformToVisual failed, causing severe aspect ratio distortion.

V1.4.27.1 returns without drawing when there is no valid BackgroundSourceRect, and adds a PointToScreen + PointFromScreen fallback in AuroraMaterialComposer for TransformToVisual failures.

**Reason**: Degradation path stretched the entire image causing distortion. Returning without drawing + fallback coordinate calculation ensures correct cropping.

**Impact Scope**: Blur background rendering for all V5 controls.

---

### P4-5: PRO Mode Export Folder Path Fix

V1.4.27.0's ShowUserLogs used MyDocuments\AURORA\UserLogs, inconsistent with the PowerShell script's $PSScriptRoot\..\..\UserLogs path, causing the "Open Export Folder" button to fail to open the correct folder.

V1.4.27.1 implements a three-level path resolution: primary path (ScriptsRoot up one level + UserLogs) → fallback 1 (exe directory up 6 levels searching) → fallback 2 (MyDocuments\AURORA\UserLogs).

**Reason**: C# and PowerShell path inconsistency. Three-level resolution ensures the actual export directory is found.

**Impact Scope**: PRO mode completion dialog's "Open Export Folder" functionality.

---

## 6. Compatibility Preservation

Although V1.4.27.1 has undergone significant material system refactoring, it maintains full compatibility with V1.4.27.0 in the following aspects:

| Compatibility Item | Description |
|--------------------|-------------|
| PowerShell 5.1 Compatibility | C# code continues to use C# 5.0 language version, ensuring operation in PowerShell 5.1 environment |
| Command-Line Parameters | All command-line parameters are fully compatible, with no additions or removals |
| syncHash Synchronization Mechanism | The cross-Runspace communication syncHash interface is fully compatible |
| Environment Variable Interface | All environment variable interfaces are fully compatible |
| Script Interface | PowerShell script engine requires no modification |
| UseV5Pipeline Switch | When false, falls back to V4 AuroraGlassMaterial, ensuring backward compatibility |

---

## 7. Change Summary Table

| No. | Tier | Change Description | Reason for Change | Impact Scope |
|-----|------|-------------------|-------------------|--------------|
| P1-1 | P1 | V5 nine-layer independent rendering architecture | V4 four-layer coupling difficult to tune independently | Glass rendering for all V5 controls |
| P1-2 | P1 | IMaterialSurfaceHost + AuroraMaterialComposer | V4 global singleton cannot configure independently | All V5 controls |
| P1-3 | P1 | Four material style presets | Single style cannot meet differentiated needs | All V5 controls |
| P1-4 | P1 | Five-level blur backend fallback chain | RTB backend cannot leverage DWM Acrylic | Blur rendering for all V5 controls |
| P2-1 | P2 | AuroraConsoleBox V5 upgrade | Connect to V5 pipeline | PRO mode console |
| P2-2 | P2 | AuroraTaskHUD V5 upgrade | Connect to V5 pipeline | PRO mode task HUD |
| P2-3 | P2 | AuroraPrivilegeIndicator V5 upgrade | Connect to V5 pipeline | PRO mode privilege indicator |
| P2-4 | P2 | AuroraProgressBar V5 upgrade | Connect to V5 pipeline | PRO mode progress bar |
| P3-1 | P3 | Edge highlight "four-corner-only" fix | Circular radial gradient only approaches edge at corners | GlowLayer rendering |
| P3-2 | P3 | Glass color vertical gradient | Single sampling point causes flat color | TintLayer rendering |
| P3-3 | P3 | Hover transition ceremony | Pure exponential smoothing too fast | GlowLayer animation |
| P3-4 | P3 | SpecularLayer removal | Mouse-following highlight has no actual visual value | SpecularLayer removal |
| P3-5 | P3 | NoiseLayer brightness jump fix | Increasing-brightness atlas + hard-cut causes jumps | NoiseLayer rendering |
| P3-6 | P3 | BodyLayer + FresnelLayer edge softening | Hard white border + narrow transition causes hard ring | BodyLayer + FresnelLayer |
| P3-7 | P3 | AuroraStarfield weighted color sampling | Discrete layer selection causes color jumps | AuroraStarfield color sampling |
| P4-1 | P4 | Window switching timing race fix | Unconditional clearing loses new window's background source | Startup chain background source handoff |
| P4-2 | P4 | DwmAcrylicBackend misselection fix | Should not select this backend when Mica not enabled | Blur backend selection |
| P4-3 | P4 | Animation speed parameter ineffectiveness fix | Fixed fallback value + first-frame DeltaMs transient | All DeltaMs-smoothed animations |
| P4-4 | P4 | BlurLayer background stretch fix | Degradation path Stretch=Fill causes distortion | Blur background rendering |
| P4-5 | P4 | Export folder path fix | C# and PowerShell path inconsistency | PRO mode export functionality |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *This tool is intended for personal educational use only. Please comply with local laws and regulations.*
