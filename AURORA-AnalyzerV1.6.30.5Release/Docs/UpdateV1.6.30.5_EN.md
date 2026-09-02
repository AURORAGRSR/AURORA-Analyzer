# AURORA Analyzer V1.6.30.5 Update Notes

> **Windows Event Log Export and Intelligent Diagnostic Tool**
>
> Version: V1.6.30.5Release · Build Date: 2026.09.02 · Author: AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **Warning**: This tool is for personal learning and research only. Please comply with local laws and regulations.

---

## Table of Contents

1. [Version Overview](#1-version-overview)
2. [Three-Track Motion Decoupling & Pace Switcher System](#2-three-track-motion-decoupling--pace-switcher-system)
3. [Shell Architecture & Settings/Confirm Panels](#3-shell-architecture--settingsconfirm-panels)
4. [Direct Launch & Startup Flow Refactor](#4-direct-launch--startup-flow-refactor)
5. [UI/UX Audit Issue Matrix Fixes (16 Items)](#5-uiux-audit-issue-matrix-fixes-16-items)
6. [Motion White Paper — Four-Phase Implementation](#6-motion-white-paper--four-phase-implementation)
7. [P0 Defect Fixes (4 Items)](#7-p0-defect-fixes-4-items)
8. [P1 Polish](#8-p1-polish)
9. [Build Hygiene](#9-build-hygiene)
10. [Compatibility](#10-compatibility)
11. [Change Summary](#11-change-summary)

---

## 1. Version Overview

V1.6.30.5 is a focused release for AURORA-Analyzer in three directions: **motion rhythm uniformity, shell architecture consistency, and startup flow streamlining**, while systematically fixing the 16-item matrix (I-01 through I-16) from the *AURORA-UIUX-Audit-2026-09-01* report and the four-phase transformation rulings from the *Modern Dynamic Response & Spatially-Decoupled Motion System Architecture Technical White Paper v2.1*.

### 1.1 Audit Baseline

The post-V1.6.30.1 deep audit gave an overall score of **6.1 / 10**, identifying three P0-grade user-experience risks:

- **Navigation transitions cannot be interrupted**: 2.6–2.9 second input black hole per view switch (I-01)
- **Each button redraws unconditionally per frame**: ~135 AuroraButton instances each subscribe to `CompositionTarget.Rendering` (I-02)
- **High-frequency startup ritual tax**: Splash→Language→Mode forced every launch, 5–8 seconds + 2 clicks (I-03)

### 1.2 Core Strategies

V1.6.30.5 delivers comprehensive upgrades via the following strategies:

- **Three-track decoupling + dual-pace recipes**: Container entrance, starfield parallax, and internal transitions each have independent timing; new "Graceful/Fast" pace recipes
- **Shell architecture refactor**: MainWindow unified shell + top-right [Settings][Exit] button group + settings/confirm panel triple-reuse
- **Direct launch refactor**: Only persists language, jumps to mode selection page after Splash — eliminates direct-launch stack residue BUG at the root
- **Systematic fix of all 16 UI/UX audit issues**: I-01 ~900ms interruptible navigation, I-02 rendering pipeline unification + static early-return, I-08 sweep intent detection, I-09 runtime reassessment, I-13 click-point growth, etc.
- **Four-phase white paper implementation**: Core transitions recipe-based, HoldEnd suppression regression fix, starfield parallax independent, cache handoff continuity

### 1.3 Compatibility Constraints

All user-facing command-line interfaces, environment variables, and cross-Runspace communication protocols remain fully compatible — existing scripts and workflows run unchanged.

---

## 2. Three-Track Motion Decoupling & Pace Switcher System

V1.6.30.5 reconstructs the animation system from "one-size-fits-all compression" to "user-selectable pace × independent tracks". Audit report I-01 noted navigation transitions taking 2.6–2.9 seconds uninterruptibly; the white paper noted starfield parallax was tied to foreground duration — both rooted in **all animation tracks being bound to a single total budget**.

### 2-1: Three-Track Decoupling — Parallax No Longer Bound to Transition Length

**Changes**:

- **ViewManager container entrance** restored to old 800ms graceful recipe (V1.5.28.19 original)
- **`CalculateParallaxDuration`** changed from hard-coded 2700→900ms to read recipe `ParallaxFloorMs` (Graceful 2200ms / Fast 900ms)
- New `ParallaxTailMs` tail (Graceful 1400ms) — starfield continues sliding through the remaining depth after the UI transition ends, preserving longitudinal continuity

**Audit/White Paper baseline**: White paper §0.1 noted old starfield 2700ms was tied to transition 2700ms; I-01 fix uniformly compressed to 900ms, which then destroyed the starfield traversal feel.

**Scope**: `Services/ViewManager.cs` `CalculateParallaxDuration`, `PlayContainerEnter`.

---

### 2-2: Dual-Pace Recipes (Graceful 800ms / Fast 450ms)

**Changes**: Two new `MotionRecipe` presets:

| Field | Graceful | Fast |
|------|----------|------|
| ContainerEnterMs | 800 | 450 |
| ContainerOvershootMs | 480 | 270 |
| TitleExitMs | 250 | 150 |
| TitleEnterMs | 400 | 200 |
| PanelEnterMs | 360 | 200 |
| StaggerMs | 80 | 25 |
| TileMs | 580 | 180 |
| ExitMs | 600 | 150 |
| GapMs | 80 | 20 |
| InitialTitleMs | 500 | 250 |
| ParallaxFloorMs | 2200 | 900 |
| ParallaxTailMs | 1400 | 0 |
| SuspendCaptureMs | 1000 | 500 |

**Audit/White Paper baseline**: Audit I-03 noted "the only mitigation is system-level reduce-animation; the app has no user-sensible motion pace switch" — this release delivers that user switch.

**Scope**: `Services/AuroraMotionSettings.cs` MotionRecipe static instances + `EffectiveRecipe` priority chain (System reduce-animation > Eco tier > User pace).

---

### 2-3: Global Scale() Tool — ~50 Scattered Motion Sites Unified

**Changes**: New `AuroraMotionSettings.Scale(ms)` and `FastFactor=0.35` constant. This release batches 40+ scattered sites:

- **MainFormView.PlayStaggerExit** (hard-coded 80/600/250/200 — completely pace-unaware, root cause of the original complaint)
- **7 `StaggerExitHelper.ScheduleExit` estimate sites** (Splash 800/1300, Smart 1200/1800, Pro 1400/2000, ExportHistory 1590/2200, SessionRestore 870/1400, SolutionDetail 1030/1600, MainForm formula)
- **Smart/Pro PlayControlExitAnimation exit params** (60/450)
- **`GlassDialogAnimation` all constants** (EnterScale/ExitWindup/ExitLeave/ExitFade/ExitSafety)
- **`AnimationHelper.PlayMainWindowEnter/Exit`** (Shell enter/exit 660/800ms keyframes)
- **7 dialog view scattered sites** (Elevation/ExportHistory/Trend/SolutionDetail/PerformanceDiagnostics/PerformanceUpgrade/ReportFormat)
- **Splash pre-parallax delay 500ms**, **Smart CoachMark 450/1900**

**Audit baseline**: Audit dimension 6.1 noted "100% of animation properties use composition-friendly channels" — motion rhythm uniformity extends the same principle.

**Scope**: ~40 scattered motion sites.

---

### 2-4: Instant Effect (No Restart, No Event Cascade)

**Changes**: Recipe switch takes effect through `EffectiveRecipe` property **read on every transition** — switching pace immediately applies to the next `ViewManager.NavigateTo` or `MainFormView.AnimateViewTransition`, no restart, no event subscriptions.

**Scope**: `Services/AuroraMotionSettings.cs` recipe table + all `EffectiveRecipe` readers.

---

## 3. Shell Architecture & Settings/Confirm Panels

V1.6.30.5 reconstructs MainWindow shell from "single bottom-right settings button" to "unified shell + top-right [Settings][Exit] button group + settings/confirm overlays". New settings and confirm panels are shell-internal glass overlays (UserControl hosted in MainWindow.RootGrid), same form as SolutionDetailView's glass message layer — independent transparent Window would prevent `AuroraFrostedGlassBorder` from sampling the main window background, causing material failure (root cause of the prior material BUG).

### 3-1: Top-Right Shell Button Group [Settings] [Exit]

**Changes**: Settings button migrated from bottom-right (36×36) to top-right; new ✕ exit button (36×36). The `ChromeButtonsPanel` group **only shows on MainFormView Mode Selection state** (audit I-10 touch target ≥32 + I-05 accessibility names).

- **Hide**: `HideChromeButtons()` at `PlayStaggerExit` start + immediate hide on Language page switch
- **Enter**: `PlayChromeButtonsEnter(staggerMs × children.Count)` at end of Mode Selection phase 4 stagger sequence, same `PlayMetroStaggerEnter` curve as in-panel buttons
- **Exit**: `PlayChromeButtonExit` per-button channel aligned with `PlayUwpExitSlow` (scale 1→0.85 + Y→130 + 70% late fade)

**Audit baseline**: Audit I-10 touch target ≥32, I-05 accessibility names; audit I-06 contrast insufficient addressed via AuroraButton replacement.

**Scope**: `Views/MainWindow.xaml(.cs)` ChromeButtonsPanel, `MainFormView.xaml.cs` PlayStaggerExit/AnimateViewTransition.

---

### 3-2: Settings Panel (MotionSettingsDialogView)

**Changes**: New `Views/Dialogs/MotionSettingsDialogView.xaml(.cs)`, shell-internal glass overlay (Panel.ZIndex=3). Four configurable items (motion pace radio, transition interruptibility, direct startup, performance tier status line read-only), all instant-effect and persisted to `user-preferences.txt`. `ContentBorder` uses `AuroraFrostedGlassBorder` (project material pipeline, same as SolutionDetailView), no solid base color — glass directly shows starfield and main window content. Mask uses 70% dim (`#B30A1428`, sufficient contrast over starfield+glass background). `PlayGlassEnter` anchors transform origin at `SettingsButton.PointToScreen` click point (I-13 click-point growth). Esc closes (I-04 lesson: real Window dialogs must respond to Esc).

**Audit baseline**: Audit I-04 missing Esc, I-06 insufficient contrast.

**Scope**: `Views/Dialogs/MotionSettingsDialogView.xaml(.cs)` (new), `MainWindow.xaml.cs` `OnSettingsClicked`.

---

### 3-3: Confirm-Exit Panel (ExitConfirmDialogView)

**Changes**: New `Views/Dialogs/ExitConfirmDialogView.xaml(.cs)`, shell-internal glass overlay (Panel.ZIndex=4, Confirm/Cancel + 70% dim + trigger-point growth + Esc). Unified entry `MainWindow.ShowExitConfirm(lang, screenClick, onConfirmed)`, triple-reuse:
1. **Mode page top-right exit button**: confirm → `RequestShellExitSafely()`
2. **ProModeView exit flow**: extract `PerformExitSequence` callback, only set `_isExiting=true` after confirm
3. **SmartModeView exit flow**: same as above

**Audit baseline**: Audit 2.4 noted "0 MessageBox at runtime, business feedback all inlined" — confirm-exit via glass modal aligns with this principle.

**Scope**: `Views/Dialogs/ExitConfirmDialogView.xaml(.cs)` (new), `MainWindow.xaml.cs` `ShowExitConfirm`, `ProModeView.xaml.cs` `RequestExitWithAnimation`, `SmartModeView.xaml.cs` `RequestExitWithAnimation`.

---

### 3-4: Panel Timing Fixes (No First-Open Flash + Reliable Dim + No Second-Enter Flash)

**Changes**:

1. **First-open flash**: Every overlay panel sets initial state in both XAML and `Show` method (`Opacity=0`, `Visibility=Visible`), avoiding the full panel rendering one frame before being pulled back to animation initial state
2. **Reliable dim**: `Show` explicitly resets `MaskBorder.Visibility=Visible`, since `PlayGlassExit` ReduceAnimations branch collapses the mask Border
3. **No second-enter flash**: WPF animation value precedence — last entrance animation's HoldEnd=1 still occupies properties, suppressing local `Opacity=0/Scale=0` so the button renders full state for one frame. `ResetChromeButtonAnimations` clears residual animations with `BeginAnimation(null)` before each entrance

**Scope**: `MotionSettingsDialogView`, `ExitConfirmDialogView`, MainWindow button group entrance.

---

## 4. Direct Launch & Startup Flow Refactor

V1.6.30.5 re-examines V1.5.29.1's direct-launch (remember last mode, jump directly to work view). Two root flaws emerged:

1. "Jump to ProMode at stack bottom" caused "back to main menu" to return to un-displayed ProModeView (singleton reuse, content empty) → white screen with only starfield
2. **First OnLoaded stacked with return transition** causing motion collision

**User decision**: New approach **only persists language, never mode**; jump to Mode Selection page (View 2) after Splash. Mode is something users actively select each launch; language is the low-frequency decision worth remembering. This eliminates un-displayed views from participating in navigation.

### 4-1: Jump to Mode Selection (Language-Only Persistence)

**Changes**: Preferences file `user-preferences.txt` persists only `Language` (CHS/ENG), not `Mode`. `App.TryDirectLaunchFromPreference()` startup chain:

1. Check `AuroraMotionSettings.SkipStartupWizard` (default on)
2. Read `LoadLanguage()`, continue if last language exists; else return false and run original full chain
3. Language priority: command-line `--language` explicit (`IsLanguagePreSelected`) > persisted preference > environment fallback
4. Call `MainFormView.InitializeWithLanguage(useLang)` silent fallback to Mode Selection page
5. `ViewManager.SetupDirectLaunchStack<MainFormView>(null)` clear stack to `[MainFormView]`

`MainFormView.SetInitialLanguageAndSkipToMode` silent fallback (no transition flow) — call `SetInitialLanguageAndSkipToMode(language)` sets `_selectedLanguage = language` then `OnPropertyChanged(string.Empty)` full notification + `CurrentState = ModeSelection`. MainFormView's `OnViewModelPropertyChanged` adds `!_isLoaded` guard — unmounted currentState changes don't play transitions.

**Audit baseline**: Audit I-03 "remember last language + mode, jump directly to mode page / work view".

**Scope**: `App.xaml.cs` `TryDirectLaunchFromPreference`, `MainFormViewModel.SetInitialLanguageAndSkipToMode`, `MainFormView.InitializeWithLanguage`/`OnViewModelPropertyChanged`, `ViewManager.SetupDirectLaunchStack`.

---

### 4-2: Preferences File Moved to App Directory (Transparency)

**Changes**: `UserPreferencesService` preferences file path changed from `%LOCALAPPDATA%\AURORA-Analyzer\user-preferences.txt` to `AppDomain.CurrentDomain.BaseDirectory\user-preferences.txt` (sibling of exe). When app directory is not writable (e.g., Program Files), write fails gracefully with logged error.

**Scope**: `Services/UserPreferencesService.cs` PreferencesDirectory/PreferencesFilePath.

---

## 5. UI/UX Audit Issue Matrix Fixes (16 Items)

V1.6.30.5 systematically fixes the 16 issues from the *AURORA-UIUX-Audit-2026-09-01* report.

### I-01 Navigation Transitions Uninterruptible ✅

**Problem**: `ViewManager._isNavigating` reject lock + serial "old exit → Content switch → new entrance", 2.6–2.9s input black hole per transition.

**Fix**: Generation token replaces reject lock — new navigation no longer rejected, overwrites old; old async callbacks compare token to determine expiry. MainFormView internal transition total from 2790ms to ~900ms (Graceful) / ~280ms (Fast); lock early-release at MainFormView phase 3 skeleton entrance start (only when `AllowInterrupt=true`). `AuroraMotionSettings.AllowInterrupt` switch (default on).

**Scope**: `Services/ViewManager.cs`, `Views/MainFormView.xaml.cs`.

---

### I-02 AuroraButton Per-Frame Unconditional Redraw ✅

**Problem**: 135 AuroraButton instances each subscribe to `CompositionTarget.Rendering`, non-Eco tier `InvalidateVisual()` every frame.

**Fix**: All non-Composer controls register through `IAuroraFrameParticipant` to `AuroraMaterialPipeline`, driven by single Pipeline `CompositionTarget.Rendering` callback. `IsFrameAnimationActive` static early-return (covers 12 animation states) — static buttons zero overhead. `IsVisibleChanged` event separately triggers InvalidateVisual to prevent "button text not drawn" regression. Color preservation: `AmbientRepaintDelta=6/255` drift-gated — sample every frame (cheap), redraw on demand (2-5 per second under slow aurora flow).

**Scope**: `Controls/AuroraButton.cs`, `Materials/AuroraMaterialPipeline.cs`.

---

### I-03 High-Frequency Startup Ritual Tax ✅

**Problem**: Every startup forces Splash→Language→Mode, no memory direct-entry, no `--mode` direct-entry.

**Fix**: See §4-1. Persist only language, jump to Mode Selection page (View 2) after Splash. `--mode <smart|pro|console>` direct retained as professional channel. `AuroraMotionSettings.SkipStartupWizard` switch.

**Scope**: `App.xaml.cs` TryDirectLaunchFromPreference + --mode direct chain.

---

### I-04 Global Keyboard Shortcut System ✅

**Problem**: 0 app-level KeyGestures; 4 real Window dialogs without Esc.

**Fix**: MainWindow shell-level `OnShellPreviewKeyDown` tunnel: Esc/Backspace/Alt+← return to previous; when overlay open, Esc closes it. PasswordDialog Esc closes. MotionSettingsDialogView & ExitConfirmDialogView (shell-internal overlays) Esc handled by shell.

**Scope**: `Views/MainWindow.xaml.cs`, `Views/Dialogs/PasswordDialogView.xaml.cs`, `Views/Dialogs/MotionSettingsDialogView.xaml.cs`, `Views/Dialogs/ExitConfirmDialogView.xaml.cs`.

---

### I-05 Screen Reader Semantics ✅

**Problem**: 135 buttons with 0 `AutomationProperties.Name`; no LiveSetting; no high-contrast adaptation.

**Fix**: AuroraButton built-in `OnCreateAutomationPeer` defaults to Text; AuroraPrivilegeIndicator + AuroraTaskHUD have established AutomationPeers. Settings button, exit button, dialog buttons explicitly set `AutomationProperties.Name`. StatusText `LiveSetting=Polite`. Shell Esc gives way to overlay.

**Partially complete**: High-contrast theme switching (further work needed).

**Scope**: `Controls/AuroraButton.cs`, `Controls/AuroraPrivilegeIndicator.cs`, `Controls/AuroraTaskHUD.cs`.

---

### I-06 Native Button Style Contrast ✅

**Problem**: Native Button foreground `#E8F4FF` over `#ADFCDC→#108CDE` gradient, 1.1-3.3:1 insufficient.

**Fix**: PasswordDialog Confirm/Cancel buttons already use AuroraButton. Settings/Exit overlay buttons all use AuroraButton (inherits I-05 automation + glass material).

**Scope**: `Views/Dialogs/PasswordDialogView.xaml`, `Views/Dialogs/MotionSettingsDialogView.xaml`, `Views/Dialogs/ExitConfirmDialogView.xaml`.

---

### I-07 Design Tokens Paper-Only (Partial)

**Problem**: Tokens.xaml 9 tokens with 0 references; 412 naked Margins; font size floor 11→12px.

**Fix**: This release did scattered font size corrections (11→12 in multiple places). Token gatekeeping + TypeScale 5 tiers (12/13/15/18/24) deferred to future iteration.

**Scope**: Multiple XAML files in `Views/` font size adjustments.

---

### I-08 Sweep Light No Intent Detection ✅

**Problem**: MouseEnter unconditionally starts 2400ms sweep, MouseLeave doesn't stop, no per-screen concurrency cap.

**Fix**: Hover ≥120ms required to start sweep (DispatcherTimer intent detection, prevents rapid hover triggering); MouseLeave 80ms linear fade (`_glareFadeOut`); focus loss also stops sweep. `EnableDynamicSweep` default off in Fast tier.

**Scope**: `Controls/AuroraButton.cs`.

---

### I-09 Reduce-Animation Read-Once + No In-App Switch ✅

**Problem**: `ReduceAnimations` only evaluated at startup; no in-app switch.

**Fix**: `SystemEvents.UserPreferenceChanged` subscription for runtime reassessment (`AuroraRenderEngine.cs:120-152`). In-app "motion pace" switch in settings panel. Settings panel status line shows current performance tier + system reduce-animation state.

**Scope**: `Services/AuroraRenderEngine.cs`, `Views/Dialogs/MotionSettingsDialogView`.

---

### I-10 Touch Targets ✅

**Problem**: 18×18 close buttons, 28×28 icon buttons.

**Fix**: Shell [Settings][Exit] buttons 36×36 (≥32 standard). Original 18×18/28×28 scattered sites not addressed (out of scope this release).

**Scope**: `Views/MainWindow.xaml` ChromeButtonsPanel.

---

### I-11 PlayPanelExit Hard-Reset Before Play ✅

**Problem**: `PlayPanelExit` forces `BeginAnimation(null)+Scale=1+Opacity=1`, interrupted entrance flashes back to full state.

**Fix**: Remove hard-reset block; read current animation values (including HoldEnd values) as exit starting point — aligned with `PlayUwpStandardExit` continuity philosophy.

**Scope**: `Animation/AnimationHelper.cs`.

---

### I-12 Velocity Inheritance / Retargeting (Infrastructure Built)

**Problem**: Only true spring k=32/c=6.5 used by Splash; three easing systems coexist.

**Fix**: Three-tier spring parameter family presets (k180/c22 ζ0.82, k120/c14 ζ0.64, k32/c6.5 ζ0.574) + `AuroraVelocityTracker`. Call-site integration deferred to future iteration.

**Scope**: `Animation/AuroraCustomEasing.cs`.

---

### I-13 Fixed Transform Origin (0.5,0.5) + MousePosition Dead Link ✅

**Problem**: Transform origin always center; MousePosition injection has no consumer (dead link).

**Fix**: `ComputeClickOrigin(clickPosition, contentBorder, referenceAncestor)` calculates normalized origin from click point (clamped 0.15-0.85). Settings/Exit overlays, SolutionDetailView glass message layer, ModalOverlay all connected. Composer MousePosition dead link cleanup (`AuroraMaterialComposer.cs:504, 594`) — keeps `SetMousePosition` API but Update no longer writes per-frame.

**Scope**: `Animation/GlassDialogAnimation.cs`, `Materials/AuroraMaterialComposer.cs`, `Views/Dialogs/SolutionDetailView.xaml.cs`.

---

### I-14 Starfield Parallax Duration Mismatch ✅

**Problem**: 2700ms constant doesn't match actual 2600-2900ms transitions.

**Fix**: See §2-1. From hard-coded 2700ms to recipe `ParallaxFloorMs` + `ParallaxTailMs`.

**Scope**: `Services/ViewManager.cs`.

---

### I-15 Button Color Triple Source (Partial)

**Problem**: Brushes/AuroraTheme/AuroraButton legacy constants coexist.

**Fix**: AuroraButton colors use `TryResolveColor` single source (`Application.Current.TryFindResource("AuroraGlassBaseTopColor")`), fallback constants retained for design-time/missing-merged-dict. ShaderEffectBackend "GPU blur" naming vs reality correction deferred.

**Scope**: `Controls/AuroraButton.cs`.

---

### I-16 UseLayoutRounding / PerMonitorV2 / Skeleton Screen (Partial)

**Problem**: No UseLayoutRounding; manifest missing PerMonitorV2; no skeleton screen.

**Fix**: New MainWindow.xaml window-level `UseLayoutRounding=True`; new app.manifest PerMonitorV2; Styles.xaml adds AuroraSkeletonRowStyle + AuroraSkeletonShimmerBrush. SaveFileDialog self-drawn progress modal deferred.

**Scope**: `Views/MainWindow.xaml`, `AURORA.Wpf/app.manifest`, `Themes/Styles.xaml`.

---

## 6. Motion White Paper — Four-Phase Implementation

V1.6.30.5 implements all four phases per White Paper v2.1 final rulings.

### 6-1: Phase 1 (Required) — Core Transition Recipe-Based + Content Pre-Mount + MainFormView ~2790ms Treatment

**Implementation**: Fully completed this release — container entrance recipe-based (§2-1), `CalculateParallaxDuration` recipe-based, MainFormView internal transition total from 2790ms → 900ms (Graceful) / 280ms (Fast). Lock early-release (I-01 fix).

**Ruling basis**: White paper §6.2 priority ① — novice users are the main user base and most sensitive to unresponsiveness.

---

### 6-2: Phase 2 (Deferrable) — Starfield Spring Damper

**Ruling deferred**: White paper §6.2 priority ③ — purely aesthetic; Eco/low-end machines don't see full effect.

**Note**: Not implemented this release. Starfield parallax recipe integration (§2-1) is necessary infrastructure, but physical model upgrade (impulse → spring) is deferred per white paper ruling.

---

### 6-3: Phase 3 (Value Restored) — Remove From to Eliminate Flashback + Cache Handoff Pairing

**Implementation**:

- **RemoveFrom eliminate flashback**: Exit side already landed in V1.5.28.25 (`AnimationHelper.cs:938-962`); entrance side 6 explicit `From` removed
- **Cache handoff pairing**: MainFormView phase 3 lock early-release paired with `_transitionGeneration` generation token (5 callback entry guards), enabling new entrance to hand off from current value

**Ruling basis**: White paper §6.2 priority ② — flashback/white screen is a "broken software" signal to novice users.

---

### 6-4: Phase 4 (Professional Channel Retained) — CLI One-Shot

**Implementation**: CLI `--mode <smart|pro|console>` direct retained (`AuroraWpfLauncher.cs` + `App.xaml.cs` `--mode` parsing), serving professional users.

**Note**: Launcher passthrough not done (white paper ruling ⑤ required; out of scope this release). Current `--mode` still usable when running Wpf\AURORA.Wpf.exe directly.

---

## 7. P0 Defect Fixes (4 Items)

P0 changes fix motion regressions, navigation BUGs, and rendering anomalies in startup flow.

### P0-1: Direct-Launch Mode Page Button Coloring Failure (Environment Color Sampling Cut by Static Early-Return)

**Problem**: In direct-launch Mode Selection page, button glass body color is 60-80% composed by `_ambientColor` (aurora-sampled color), but renders in default pale cyan `(220,255,255)` — only recovers on mouse hover (frame loop resumes, sampling gets real aurora color).

**Fix**: `OnPipelineFrame` static early-return branch retains environment color sampling (cheap lookup) + drift-gated redraw: `AmbientRepaintDelta=6/255`, sample color's max channel drift beyond threshold vs last draw triggers `InvalidateVisual`.

**Scope**: `Controls/AuroraButton.cs` OnPipelineFrame static branch.

---

### P0-2: Direct-Launch Reverts to Chinese (Startup Fallback Overrides Preference)

**Problem**: After selecting ENG and restarting via direct launch, Mode Selection page shows Chinese.

**Fix**: `TryDirectLaunchFromPreference` language priority inversion: command-line `IsLanguagePreSelected` > persisted preference > environment fallback. `MainFormView.OnViewModelPropertyChanged` Language branch adds `App.CurrentLanguage = _viewModel.SelectedLanguage` sync.

**Scope**: `App.xaml.cs` TryDirectLaunchFromPreference + OnStartup early fallback timing, `MainFormView.xaml.cs` Language PropertyChanged branch.

---

### P0-3: Navigation White Screen BUG (Direct-Launch Path Stack Residue)

**Problem**: From Splash to Smart/Pro mode, clicking "Back to Main Menu" returns to expired Splash (singleton reuse, empty content) → blank UI with only starfield.

**Fix**: V1.6.30.5 RC1 introduced `ViewManager.SetupDirectLaunchStack<TTop>(rootView)`: transition orchestration reuses NavigateTo (current view exit + TTop entrance + parallax), then rearanges stack to `[rootView, TTop]` after return. V1.6.30.5 final solution only persists language, jumping to MainFormView (View 2), eliminating direct-launch to ProMode stack residue from the root. `SetupDirectLaunchStack` retained as general stack-layout tool.

**Scope**: `ViewManager.SetupDirectLaunchStack`, `App.xaml.cs` TryDirectLaunchFromPreference.

---

### P0-4: Second-Entrance Flash (HoldEnd Animation Suppresses Local Initial State)

**Problem**: Switching from main window to Mode Selection page, settings button renders in full state for one frame, then pulled back by entrance animation.

**Fix**: Before each entrance playback, `BeginAnimation(null)` clears last entrance residual animations (HoldEnd=1 occupying properties), then resets initial state.

**Scope**: `MainWindow.cs` `PlayChromeButtonsEnter`, `ResetChromeButtonAnimations`.

---

## 8. P1 Polish

### P1-1: Dim Only Effective Once

**Fix**: `Show` method explicitly resets `MaskBorder.Visibility=Visible`. See §3-4.

---

### P1-2: Overlay Bilingual Failure

**Fix**: MainFormView.OnViewModelPropertyChanged Language branch adds `App.CurrentLanguage = _viewModel.SelectedLanguage` sync.

---

### P1-3: Settings Button Mismatch on Different Paths

**Fix**: Hide advanced to `PlayStaggerExit` start + immediate `HideChromeButtons()` on language page switch; entrance inserted at phase 4 stagger sequence tail.

---

### P1-4: Missing Exit Animation (Settings/Exit Buttons)

**Fix**: `HideChromeButtons` changed to recipe `ExitMs` staggered fade (Graceful 600ms / Fast 150ms), then Collapse + reset animation state.

---

### P1-5: Scattered Animation Durations All Recipe-Bound

~40 scattered animation sites via `AuroraMotionSettings.Scale()`, see §2-3. **Deliberately not bound**: AuroraTextBlock text switching default 300ms, MainForm hover intent detection 750ms, diagnostics FPS sampling 500ms (per scope ruling: micro-interactions/logic timers not under pace control).

---

## 9. Build Hygiene

### 9-1: Build-Aurora.ps1 Path Bug Fix

**Problem**: When `AURORA-build.bat` calls `Build-Aurora.ps1` across directories, `Split-Path -Parent $MyInvocation.MyCommand.Path` doesn't reach the csproj directory, prompting "Project file not found".

**Fix**: Script directory auto-ascends one level when csproj not found.

**Scope**: `AURORA.Wpf/Build-Aurora.ps1`.

---

### 9-2: MSB3088 Resource Cache Incompatibility

**Problem**: `obj/Release/GenerateResource.Cache` files generated by VS18 MSBuild are version-incompatible — v4.0 MSBuild (used by bat) reading such caches raises `warning MSB3088`.

**Fix**: Clear obj to let v4.0 MSBuild regenerate cache in its own format; warning disappears.

**Scope**: AURORA.Wpf/obj/.

---

## 10. Compatibility

V1.6.30.5 strictly preserves the following compatibility constraints:

- **Command-line interface**: All original command-line arguments (`--launched-by-exe`, `--skip-splash`, `--language`, `--mode`, etc.) continue working per V1.6.30.1 behavior
- **Environment variables**: AURORA_WD_PIPE, AURORA_WD_SESSION, AURORA_LAUNCHED_BY_EXE, AURORA_TOKEN_PATH, AURORA_EXE_VERIFIED, AURORA_hash_PATH unchanged
- **Cross-Runspace communication protocol**: syncHash 30+ keys (IsHostAlive, IsRunning, LogOutput, Progress, UserInput, IsAdmin, etc.) compatible
- **Data files**: `Data/AURORA-TechData.json`, `GAURORA.CHK.ENC`, `UserLogs/` directory structure compatible
- **Runtime degradation**: System "reduce animation", Eco performance tier still force Fast pace, independent of user setting

---

## 11. Change Summary

### 11-1: New (7 Items)

| Item | Path |
|------|------|
| Motion config center + recipe table + priority chain | `Services/AuroraMotionSettings.cs` |
| Settings panel (glass overlay) | `Views/Dialogs/MotionSettingsDialogView.xaml(.cs)` |
| Confirm-exit panel (glass overlay, triple-reuse) | `Views/Dialogs/ExitConfirmDialogView.xaml(.cs)` |
| Spring three-tier parameter family + VelocityTracker | `Animation/AuroraCustomEasing.cs` |
| Direct-launch stack layout tool | `ViewManager.SetupDirectLaunchStack` |
| PerMonitorV2 manifest | `AURORA.Wpf/app.manifest` |
| Skeleton screen base styles | `Themes/Styles.xaml` AuroraSkeletonRowStyle/AuroraSkeletonShimmerBrush |

### 11-2: Rewritten / Refactored (6 Items)

| Item | Path |
|------|------|
| MainFormView state machine recipe-bound + lock early-release + 5 token guards | `Views/MainFormView.xaml.cs` |
| ViewManager container entrance/parallax + generation token + interrupt switch | `Services/ViewManager.cs` |
| AuroraButton static early-return + environment color preservation + sweep intent detection | `Controls/AuroraButton.cs` |
| ProModeView/SmartModeView confirm-exit hookup + stagger entrance recipe-bound | `ProModeView.xaml.cs`, `SmartModeView.xaml.cs` |
| MainWindow shell button group + overlay coordination | `Views/MainWindow.xaml(.cs)` |
| Preferences storage moved to app directory | `Services/UserPreferencesService.cs` |

### 11-3: UI/UX Audit 16 Items

- I-01 ~900ms interruptible navigation ✅
- I-02 rendering pipeline unification + static early-return + color preservation ✅
- I-03 startup only persists language, jump to mode page ✅
- I-04 shell-level PreviewKeyDown Esc gives way ✅
- I-05 AuroraButton AutomationPeer + shell-level names ✅
- I-06 PasswordDialog/overlay all use AuroraButton ✅
- I-07 font size 11→12 scattered (gatekeeping deferred) Partial
- I-08 hover 120ms intent detection + 80ms fade stop ✅
- I-09 runtime reassessment + in-app pace switch ✅
- I-10 shell buttons 36×36 ✅
- I-11 remove hard-reset, read current value handoff ✅
- I-12 spring three-tier + VelocityTracker (integration pending) Infrastructure
- I-13 click-point growth ComputeClickOrigin + MousePosition dead link cleanup ✅
- I-14 parallax duration recipe-based ✅
- I-15 button color TryResolveColor single source Partial
- I-16 UseLayoutRounding + PerMonitorV2 + skeleton styles Partial

### 11-4: Motion White Paper Four Phases

- Phase 1 (core transition recipe-based + MainFormView treatment) ✅
- Phase 2 (starfield spring damper) Per ruling deferred
- Phase 3 (remove From + cache handoff) ✅
- Phase 4 (CLI direct retained) ✅

---

*AURORA VelociRaptor-GR Dev PRJ. · V1.6.30.5 Release*