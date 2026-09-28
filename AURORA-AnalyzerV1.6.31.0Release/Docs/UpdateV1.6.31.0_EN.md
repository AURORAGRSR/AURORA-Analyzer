# AURORA Analyzer V1.6.31.0 Update Notes

> **Windows Event Log Export and Intelligent Diagnostic Tool**
>
> Version: V1.6.31.0Release · Build Date: 2026.09.28 · Author: AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **Warning**: This tool is for personal learning and research only. Please comply with local laws and regulations.

---

## Table of Contents

1. [Version Overview](#1-version-overview)
2. [All-New Aurora Starfield: Curtain Aurora & Depth Starfield](#2-all-new-aurora-starfield-curtain-aurora--depth-starfield)
3. [All-New Glass Material: Frosty Liquid Glass](#3-all-new-glass-material-frosty-liquid-glass)
4. [Security & Stability Enhancements](#4-security--stability-enhancements)
5. [Upgrade Notes](#5-upgrade-notes)
6. [Compatibility](#6-compatibility)
7. [Change Summary](#7-change-summary)

---

## 1. Version Overview

V1.6.31.0 is a **dual-theme release** for AURORA-Analyzer: on the visual side, it delivers morphology-level rebuilds of two core visual systems (the aurora starfield and the glass material); on the security side, it completes a full audit and systematic hardening of the launch trust chain.

### 1.1 Design Baselines

- **Aurora**: *AURORA Aurora Presentation Deep Reconstruction Design (V-B Curtainization)* — triggered by the user feedback "the aurora is too thin", it demonstrates why tuning parameters could never fix the old "beaded wisp" morphology and specifies the new "vertical-strand curtain" morphology;
- **Glass**: *AURORA Liquid Glass V-LG1.7 Implementation Report* — the concluding wave of seven rounds of texture calibration (V-LG1.1~V-LG1.7), rewriting the frosted blur kernel and switching the frosty recipe as a package;
- **Motion**: *AURORA UI/UX Motion System Comprehensive Review Report* (2026-09-28) — overall grade A-, confirming the existing three-track decoupling, recipe-driven rhythm, and performance safeguards; all starfield changes in this release land within the existing time base and performance framework;
- **Security**: full-chain audit of the launch trust chain (review archived in internal documents; per responsible-disclosure principles, not elaborated in this note).

### 1.2 Core Strategies

- **Change the model, not the parameters**: the aurora goes from "beaded ellipses" to "vertical-strand curtains", and the glass from "deep-space-blue tinted panel" to "icy white veil" — both were morphology bottlenecks that multiple rounds of parameter tuning could not break through;
- **Wholesale recipe switch**: the four glass parameters (blur / saturation / tint / frost) mutually reinforce each other and switch as a package rather than as isolated tweaks;
- **Inherited performance safeguards**: all new visuals are implemented within the existing three-tier performance strategy, 30fps glass capture throttling, and allocation-free hot paths;
- **Automated security hardening**: all security improvements take effect automatically through the build pipeline — zero user configuration.

### 1.3 Compatibility Constraints

All user-facing command-line interfaces, environment variables, UI interactions, and analysis features remain fully compatible; the visual system adapts automatically to performance tiers; the user preferences file (`Wpf\user-preferences.txt`) can be kept and reused.

---

## 2. All-New Aurora Starfield: Curtain Aurora & Depth Starfield

The starfield engine (`AuroraStarfield`, ~3400 lines) underwent a morphology-level rebuild in this cycle. The old aurora was essentially "a series of radial-gradient ellipses along a horizontal sine path" — an ellipse is an isotropically fading blob, and strung horizontally, no amount of radius/overlap/brightness tuning ever produced more than "a brighter horizontal thin band".

### 2-1: Curtain Aurora (Column Curtain Morphology)

**Changes**: each curtain is now composed of "N vertical strands + 1 glowing base", rebuilt after the physics of real aurorae:

- **Hanging form** — strands run vertically along "field lines", bottom alpha 255 brightest, top alpha 0 fading out (not isotropic decay);
- **Distinct top/bottom colors** — a new `TopHue` field implements the vertical color gradient: purple-red at the top (630nm emission of oxygen at high altitude), teal-green at the bottom (558nm at low altitude); each strand carries a four-stop vertical gradient (top 0 → upper-middle 80 → lower-middle 180 → bottom 255);
- **Strand independence** — each strand has its own phase offset (`phase + i × 0.41`) plus a low-frequency sinusoidal lateral perturbation (frequency ≈0.012, ±4-12px), turning "the whole curtain swaying in unison" into staggered flutter;
- **Dense center, sparse edges** — central strands peak at alpha 0.6 and edge strands at 0.3, naturally shaping the curtain silhouette;
- **Rendering cost** — each strand is a rectangle + vertical gradient, costing about half of one old wisp ellipse; gradient brushes are pre-generated and frozen per layer (5 gradients × 4 layers = 20), with only opacity updated at runtime — allocation-free hot path.

**Design baseline**: Curtain Reconstruction §0 diagnosis — "the morphological contradiction of beaded wisps cannot be reconciled by tuning"; all five visual characteristics of §1 (hanging / strands / distinct top-bottom colors / independent sway / glowing base) are implemented.

**Scope**: `Controls/AuroraStarfield.cs` `DrawCurtainColumns` (new), `DrawWispDiffusion` (old path extracted and retained for residual-glow layers), `AuroraLayerConfig` (+TopHue/IsColumnCurtain fields).

---

### 2-2: Four-Layer Curtain Depth & Motion Language

**Changes**:

- **Four curtain layers** — each layer with independent Y position, height fraction, hue, saturation, amplitude, and speed, stacking into depth rather than a flat plane;
- **Mixed motion drivers** — breathing + standing-wave pulsation + hue wandering + brightness breathing, all superimposed; flow direction reverses with phase ±1, layered with diagonal strand drift — farewell to constant horizontal movement;
- **Inter-layer dark breathing bands** — light-dark contrast as "the carrier of brilliance", preserving breathing dark rhythm between layers.

**Design baseline**: Motion review report §5.1 "Aurora design (user preference ✓)" — both "4 independently configured curtain layers" and "no persistent right-to-left horizontal drift" confirmed.

**Scope**: `Controls/AuroraStarfield.cs` AuroraLayerConfig four-layer configuration, curtain stops update logic.

---

### 2-3: Six-Level Depth Parallax & Trail Starfield

**Changes**:

- **View-switch depth** — stars mapped to 6 depth levels, tracking target phase / start phase / velocity direction; differentiated near/far motion + radial displacement + differentiated opacity;
- **Depth trails** — during parallax motion, near stars stretch into elliptical streaks along the direction of travel, EMA-smoothed to eliminate frame-interval jitter (like star trails in a tracking camera shot);
- **Idle depth breathing** — at rest, the starfield retains a barely perceptible depth micro-oscillation, keeping the scene alive rather than a static backdrop.

**Design baseline**: Motion review report §5.1 "Depth parallax (user preference ✓)".

**Scope**: `Controls/AuroraStarfield.cs` parallax state machine (L1052-1087), near/far rendering differentiation (L1813-1875), trail EMA fields.

---

### 2-4: Real-Time Base & Star Entry

**Changes**:

- **Stopwatch real-time stepping** — inter-frame millisecond deltas drive star updates, clamped to 1-64ms, normalized by `_animationTimeScale` to a 30fps base — animation speed is decoupled from render framerate, no "fast-forwarding" on high-refresh displays;
- **Static star entry** — newly spawned stars appear directly in a static initial state, skipping long easing and avoiding radial fly-in — no performance spikes in PRO mode.

**Design baseline**: Motion review report hard-constraint matrix #8/#9 (Stopwatch real-time stepping, avoid radial fly-in) — verified compliant.

**Scope**: `Controls/AuroraStarfield.cs` frame clock (L89-98, L1464-1480), star entry (L3261-3333).

---

### 2-5: Starfield Light Fog (Glass Synergy)

**Changes**: the starfield adds two slowly breathing, drifting deep-space light fogs, giving the glass "content to refract":

- Dual anchors — teal-green lower-center (~0.40W×0.62H, H≈170) + icy blue-violet upper-right (~0.72W×0.34H, H≈215);
- Hue ±8 wandering (~70s cycle) + anti-phase breathing (~27s cycle) + two layers drifting in opposite directions at different frequencies (depth);
- Fog brushes created at construction, hot path only updates stop colors, updates throttled to 30ms;
- Gating: Balanced tier and above with GPU tier >0 (skipped automatically on Eco / no GPU).

**Design baseline**: VLG1.7 report §2 root cause #4 — "empty deep-space regions give the glass nothing to refract"; §W6 starfield feeding fog.

**Scope**: `Controls/AuroraStarfield.cs` `DrawGlassFeedingFog` (new), `EnableGlassFeedingFog` fallback switch; `GlassDynamicsActive` linkage with `AuroraMaterialPipeline` capture throttling.

---

### 2-6: Three-Tier Performance Strategy

**Changes**:

- **Eco tier** — redraws every other frame; meteors/deep-space particles are double-gated by the animation switch + parallax state, with Eco stopping spawn and clearing;
- **Balanced tier** — keeps starfield animation, disables complex glow;
- **Performance tier** — everything enabled;
- Render event subscriptions are explicitly managed (auto-removed when idle), eliminating idle CPU drain.

**Design baseline**: Motion review report hard-constraint matrix #11 (Rendering unsubscribe at zero); all four performance safeguards verified compliant.

**Scope**: `Controls/AuroraStarfield.cs` Eco two-frame redraw (L1696-1706), particle gating (L1636-1706), render subscription management (L875-910); `Services/AuroraRenderEngine.cs` three-tier strategy.

---

## 3. All-New Glass Material: Frosty Liquid Glass

The glass system went through seven rounds of texture calibration (V-LG1.1~V-LG1.7), delivering the final **frosty glass** recipe — the glass reads as "a veil of icy white brighter than the background", replacing the old deep-space-blue tinted panel. The core lesson of those rounds: **adjusting any parameter in isolation gets cancelled out by the missing other pillars**, hence this release switches the recipe system as a whole.

### 3-1: Frosted Blur Kernel v2 (Ghost-Halo Root Fix)

**Changes**: the old `AuroraBlurHlsl` was a fixed-weight 9-tap kernel (w0=0.227/w1/w2 constants for σ≈2.0); `blurRadius` only enlarged sampling stride without rebuilding weights — at large radii the point spread function became a sharp center + concentric ghost halos. v2 rewrites it:

- Adaptive dual variants — σ≤2 takes 9-sample, σ>2 takes 13-sample, with weights **rebuilt from the target σ** via the bilinear merge formula (discrete weights exp(-d²/2σ²), adjacent-pair centroid merging, truncated-kernel normalization, σ clamped to 8.0);
- σ conversion contract — `σ = blurRadius × 0.5` (anchored to CSS `blur(R)≈σ=R/2`);
- The three tiers map to σ = 3.0/4.0/5.0, all on 13-sample;
- New `AURORA_BLUR_BACKEND=RTB/Shader` environment variable forces a specific blur backend (permanent QA comparison hook).

**Design baseline**: VLG1.7 report §2 root cause #2 (frosted-kernel ghosting) — "at σ=10 the PSF = 22.7% sharp core + halos".

**Scope**: `Materials/Backends/AuroraBlurHlsl.cs` (Source9/Source13 dual-variant rewrite), `Materials/Effects/AuroraBlurShaderEffect.cs` (ComputeLinearGaussian/SetKernel), `Materials/Backends/D3DCompiler.cs` (dual bytecode cache), `Materials/Backends/ShaderEffectBackend.cs`, `Materials/AuroraMaterialPipeline.cs` (backend-forcing hook).

---

### 3-2: Wholesale Frosty Recipe Switch

**Changes**: `MaterialStylePreset` three-tier presets reset as a package:

| Parameter | Balanced | Performance | Extreme | Old |
|-----------|----------|-------------|---------|-----|
| BlurRadius | 12 | 16 | 20 | 4/6/9 |
| BlurSaturation | 1.30 | 1.35 | 1.40 | 1.0 |
| TintStrength | 0.12 | 0.12 | 0.12 | 0.10 |
| TintColor | Icy white (235,244,255) | same | same | Deep-space blue (14,24,48) |
| DarkenStrength | 0.18 | 0.20 | 0.22 | 0.30/0.32/0.35 |

`LiquidWarpElement` aligned accordingly: scrim three-stage 0.13/0.08/0.05 (independent constants, previously a multiplier chain), Brightness 1.12→1.15, EdgeDesat 0.25→0.12, AberrationStep 0.14→0.12 (RGB ×1.0/×1.12/×1.24). Eco/Tier0 fallback paths automatically gain a "frosty lite" look via the icy Tint + Darken (zero layer-code changes).

**Design baseline**: VLG1.7 report §2 root cause #1 (systemic recipe absence) — "each parameter inevitably looks bad while the other pillars are missing"; §W2 recipe system reset.

**Scope**: `Materials/MaterialStylePreset.cs` three-tier presets, `Controls/LiquidWarpElement.cs` scrim/brightness/dispersion parameters.

---

### 3-3: Light Ring v2 & Inner-Highlight Trio

**Changes**:

- Main light ring opacity — RingAlpha33 150→170, RingAlpha66 210→230;
- Inner-highlight trio (a direct translation of the v13 box-shadow) — a 0.75px white outline all around at α140 + a 3px soft white gradient at the top edge at α60 (Absolute MappingMode fixed 3px falloff) + a 3px dark line at the bottom edge at α90;
- The trio is rebuilt and frozen with size changes; controls shorter than 12 units skip the top/bottom bands (thin-control adaptation).

**Design baseline**: VLG1.7 report §2 root cause #3 (missing inner highlights) — the reference implementation's inset trio was previously absent entirely.

**Scope**: `Controls/LiquidBorderOverlayElement.cs`.

---

### 3-4: Four Self-Contained Controls & Button Frosty Alignment

**Changes**:

- **New `LiquidBorderLite`** — an inline version of the light ring + trio (constants identical to OverlayElement), rendering in a cached frozen mode; thin-control light bands adapt their height (h×0.25 / h×0.2, skipping below 1px);
- **Four self-contained controls wired in** — the console box, task HUD, privilege indicator, and progress bar append light-ring rendering after their own glass composition (nested scenes get the ring from the outer glass, avoiding double-drawing);
- **AuroraButton frosty alignment** — glass body alpha 34/16→48/26 (hover 58/30→62/38), highlight start 195→205, plus a new top-edge inner highlight line (vertical gradient α120→0, 0.8px, cached brush/pen); IsSelected/IsDangerous semantic colors, aurora injection, hover/sweep/ripple all retained.

**Design baseline**: VLG1.7 report §W4/W5 — "app-wide consistency: four self-contained Composer controls + AuroraButton aligned to the frosty language".

**Scope**: `Controls/LiquidBorderLite.cs` (new + added to csproj), `Controls/AuroraConsoleBox.cs`, `Controls/AuroraTaskHUD.cs`, `Controls/AuroraPrivilegeIndicator.cs`, `Controls/AuroraProgressBar.cs`, `Controls/AuroraButton.cs`.

---

### 3-5: Glass Performance Safeguards (Inherited & Maintained)

**Changes**: the frosty recipe lands within the existing performance framework, with all safeguards verified compliant (motion review report §6):

| Safeguard | Measured |
|-----------|----------|
| Blur capture throttle | 33ms (30fps) |
| Capture resolution | 0.5×, capped at 960×540 |
| Throttle tiers | 66/50/33/100ms by performance tier |
| Render subscription mgmt | auto-unsubscribe at zero participants |
| View-switch anti-flicker | glass capture suspension window (Graceful=1000ms) |
| Effective blur radius | `Preset.BlurRadius × (0.3 + Depth×1.4)` depth-linked |

**Design baseline**: Motion review report §6 — all seven material-layer constraints compliant.

**Scope**: `Materials/AuroraMaterialPipeline.cs`, `Materials/RtbBlurBackend.cs`, `Materials/AuroraMaterialComposer.cs`, `Materials/AuroraMaterialSurface.cs`.

---

## 4. Security & Stability Enhancements

This release completed a full security audit and systematic hardening of the launch trust chain (build-time → launch-time → runtime → elevation chain). Following responsible-disclosure principles, this section only outlines directions of improvement without implementation details.

### 4-1: Enhanced Integrity Verification

**Direction**: a build-time integrity component (distributed with the release package) now performs both startup-time and runtime verification of all core files — including the main program and the security module itself — and refuses to run if verification fails. All improvements take effect automatically with the new build.

---

### 4-2: Upgraded Token Mechanisms

**Direction**: launch and elevation tokens gain significantly improved anti-replay and anti-tampering capabilities. The upgrade is fully transparent to users (tokens are inherently short-lived and single-use, with no cross-version consumption scenario).

---

### 4-3: Log Privacy Improvements

**Direction**: guard and token verification logs no longer output environment-sensitive information such as installation paths, with no loss of operability.

---

### 4-4: Hardened Build Pipeline

**Direction**: multiple artifact verification gates were added to the build pipeline (including the new compile and signature stages) — any failure aborts the build, preventing inconsistent artifacts from shipping. This affects the build process only; no new dependencies on target machines.

---

## 5. Upgrade Notes

1. **Use the complete new release package**: this version includes newly added security component files — replace the old version directory entirely. Do not mix with old files or partially overwrite, and do not delete any file from the package (mixing or missing files may cause the integrity check to block the program from running);
2. **Keep your preferences**: `Wpf\user-preferences.txt` can be retained when upgrading (language and other personalized settings carry over);
3. **Zero visual configuration**: the aurora starfield and glass material adapt automatically to performance tiers (Eco / Balanced / Performance / Extreme); lower-end machines downgrade automatically (Eco disables starfield animation and light fog; glass falls back to the frosty-lite path).

---

## 6. Compatibility

V1.6.31.0 strictly maintains the following compatibility constraints:

- **Command-line interface**: all existing arguments (`--launched-by-exe`, `--skip-splash`, `--language`, `--mode`, etc.) continue to work as in V1.6.30.5
- **Environment variables**: the existing environment variable protocol is unchanged
- **Cross-Runspace communication**: all syncHash keys remain compatible
- **Data files**: `Data/AURORA-TechData.json` and the `UserLogs/` directory structure are compatible; `Wpf\user-preferences.txt` can be kept
- **Runtime fallback**: system "reduce animation" and the Eco performance tier still force the fast pace, independent of the user pace setting

---

## 7. Change Summary

### 7-1: New

| Item | Path |
|------|------|
| Inline glass light-ring control (frosty alignment for four self-contained controls) | `Controls/LiquidBorderLite.cs` |
| Curtain aurora renderer (vertical strands + glowing base) | `Controls/AuroraStarfield.cs` DrawCurtainColumns |
| Starfield feeding light fog (dual-anchor breathing drift) | `Controls/AuroraStarfield.cs` DrawGlassFeedingFog |
| Forced blur-backend QA hook | `Materials/AuroraMaterialPipeline.cs` AURORA_BLUR_BACKEND |
| Release-package security component files | root directory (generated at build time) |

### 7-2: Rewritten / Refactored

| Item | Path |
|------|------|
| Frosted blur kernel (σ-rebuilt weights, 9/13 dual variants) | `Materials/Backends/AuroraBlurHlsl.cs`, `Materials/Effects/AuroraBlurShaderEffect.cs` |
| Wholesale frosty recipe reset (three tiers) | `Materials/MaterialStylePreset.cs` |
| Light ring v2 + inner-highlight trio | `Controls/LiquidBorderOverlayElement.cs` |
| Frost veil / brightness / dispersion parameter alignment | `Controls/LiquidWarpElement.cs` |
| Button frosty alignment (body opacity + top-edge inner highlight) | `Controls/AuroraButton.cs` |
| Starfield time base / parallax / trails / star entry / performance gating | `Controls/AuroraStarfield.cs` |

### 7-3: Visual Artifact Fixes (Starfield)

- Aurora horizontal-line / truncation fixes (independent masks)
- Horizontal strand modulation mask
- Stripe continuity during parallax

### 7-4: Security Hardening

- Updates to launch trust chain components (build pipeline, integrity verification, token mechanisms, launcher, security module) — not expanded per-file per responsible-disclosure principles

---

*AURORA VelociRaptor-GR Dev PRJ. · V1.6.31.0 Release*
