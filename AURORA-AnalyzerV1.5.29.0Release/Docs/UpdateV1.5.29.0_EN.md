# AURORA Analyzer V1.5.29.0 Update Notes

> **Windows Event Log Export and Intelligent Diagnostic Tool**
>
> Version: V1.5.29.0Release · Build Date: 2026.07.17 · Author: AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **Warning**: This tool is intended for personal educational use only. Please comply with local laws and regulations.

---

## Table of Contents

1. [Version Overview](#1-version-overview)
2. [P1 Level: Starfield Parallax Multi-Level Depth Reshape](#2-p1-level-starfield-parallax-multi-level-depth-reshape)
3. [P2 Level: Dialog Visual Unification and Overlay Architecture Removal](#3-p2-level-dialog-visual-unification-and-overlay-architecture-removal)
4. [P3 Level: Permission Selection Timing Relocation](#4-p3-level-permission-selection-timing-relocation)
5. [P4 Level: UWP Text Transition Curves and Language Switch Fix](#5-p4-level-uwp-text-transition-curves-and-language-switch-fix)
6. [P5 Level: Smart Mode Status Text Position Fix](#6-p5-level-smart-mode-status-text-position-fix)
7. [P6 Level: Keyboard Focus and Navigation Anti-Bounce Unification](#7-p6-level-keyboard-focus-and-navigation-anti-bounce-unification)
8. [P7 Level: Starfield Parallax Performance Optimization (Aurora Layer +50%)](#8-p7-level-starfield-parallax-performance-optimization-aurora-layer-50)
9. [Compatibility Preservation](#9-compatibility-preservation)
10. [Change List Overview](#10-change-list-overview)

---

## 1. Version Overview

V1.5.29.0 is an AURORA-Analyzer special polish release focused on "visual immersion and interaction consistency", building upon the V1.5.28.5 rendering mechanism refactor and console mode upgrade. This update packages the animation, parallax, dialog, language switch, and navigation anti-bounce fixes that landed incrementally across V1.5.28.6 ~ V1.5.28.29, covering seven core areas: starfield parallax multi-level depth reshape, dialog visual unification and Overlay architecture removal, permission selection timing relocation, UWP text transition curves and language switch fix, smart mode status text position fix, keyboard focus and navigation anti-bounce unification, and starfield parallax performance optimization. The PowerShell engine layer remains compatible — all command-line parameters, environment variable interfaces, and the syncHash synchronization mechanism remain unchanged.

For parallax depth, V1.5.29.0 establishes a complete 7-level depth mapping chain: Splash (0.00) → MainForm view1 (0.15) → MainForm view2 (0.30) → ProMode (0.50) → SmartMode (0.60) → dialog group (0.85) → SolutionDetail (1.00), without increasing the rendered star count — only controlling the global parallax intensity. MainForm's depth is dynamically determined by its internal `CurrentInternalDepth` property, so the starfield lands on the correct internal view level when returning to MainForm across view switches.

For dialog visuals, V1.5.29.0 removes the `Background` attribute from the 5 dialog windows' root `UserControl` (defaults to null, non-participating in hit testing, mouse events pass through to the shell starfield), and removes the entire Overlay infrastructure including the IAuroraOverlay interface, PushOverlay/PopOverlay/RemoveOverlay methods, and the OverlayLayer Grid.

For performance optimization, V1.5.29.0 replaces "near-star glow" with "aurora layer +50% alpha boost" as the parallax visual feedback — fixed cost, independent of star count, avoiding the severe frame drops of the original scheme with large star counts.

V1.5.29.0 achieves comprehensive upgrade through the following core strategies:

- **Parallax depth reshape**: 7-level depth mapping, eliminating three "no-parallax" branches
- **Dialog visual unification**: 5 dialogs background transparentized, Overlay architecture removed
- **Permission timing relocation**: ElevationDialog relocated from inside the main window to after Splash
- **Precise UWP animation matching**: UWP standard curves, language switch notification sequence reordered
- **Status text fix**: Retry mechanism + layout check + X upper bound check
- **Unified interaction anti-bounce**: ViewManager.IsNavigating unified navigation lock, 5 entry point anti-reentry
- **Parallax performance optimization**: Skip SoftGlow/DiffractionSpike, aurora layer +50% boost

This update is a "comprehensive parallax depth reshape, dialog visual unification, permission flow decoupling, precise UWP animation matching, unified interaction anti-bounce" release. All user-facing command-line interfaces, environment variables, and cross-Runspace communication protocols remain fully compatible, ensuring existing scripts and workflows run without modification.

---

## 2. P1 Level: Starfield Parallax Multi-Level Depth Reshape

The P1 level change expands the original 4-level depth scheme into a 7-level depth mapping.

### P1-1: 7-Level Depth Mapping

**Problem**: The original 4-level depth scheme had three "no-parallax" branches: Splash (0.0) ↔ MainForm (0.0) both at the deepest level, ProMode (0.35) ↔ SmartMode (0.35) at the same depth, MainForm internal view1 (0.0) ↔ view2 (0.1) difference too small, making starfield changes almost invisible during these switches.

**Fix**: `ViewManager.GetViewDepth` returns 7-level depth values by view type: SplashScreenView=0.00, MainFormView=CurrentInternalDepth (view1=0.15 / view2=0.30), ProModeView=0.50, SmartModeView=0.60, ExportHistoryView/UndoViewerView/ElevationDialogView/SessionRestoreDialogView=0.85, SolutionDetailView=1.00.

**Reason**: The original 4-level scheme had too small depth differences or same depths, making parallax invisible.

**Impact Scope**: `ViewManager.cs` GetViewDepth.

---

### P1-2: MainForm Internal Dynamic Depth

**Change**: The `MainFormView.CurrentInternalDepth` property dynamically returns based on `_viewModel.CurrentState`: view1 (LanguageSelection)=0.15, view2 (ModeSelection)=0.30. So the starfield lands on the correct internal view level when returning to MainForm across view switches.

**Reason**: MainForm's two internal views need different depths, otherwise the starfield level is wrong when returning to MainForm.

**Impact Scope**: `MainFormView.xaml.cs` CurrentInternalDepth.

---

### P1-3: Parallax Intensity Coefficient Boost

**Change**: `AuroraStarfield.cs` adjusts two parallax intensity coefficients: radial displacement coefficient 0.18 → 0.28 (`pushAmount = parallaxSmooth * depth * 0.28`), transparency attenuation coefficient 0.5 → 0.62 (`starOpacityMul = 1.0 - parallaxSmooth * depth * 0.62`).

**Reason**: The original coefficients made depth differences visually inconspicuous.

**Impact Scope**: `AuroraStarfield.cs` parallax rendering path.

---

### P1-4: Parallax Duration Dynamic Alignment and targetPhase Interpolation

**Change**: `StartParallaxCycle` accepts a `targetPhase` parameter, smoothly interpolating from `_parallaxStartPhase` to `_parallaxTargetPhase`. `ViewManager` computes `targetPhase = GetViewDepth(newView/previous)` in NavigateTo/NavigateBack and passes it in. The total parallax duration is dynamically computed by `ViewManager` based on the target view's actual exit + entrance animation total duration (V1.5.28.7).

**Reason**: Parallax needs to be fully synchronized with the view switch animation.

**Impact Scope**: `AuroraStarfield.cs` StartParallaxCycle, `ViewManager.cs` NavigateTo/NavigateBack.

---

## 3. P2 Level: Dialog Visual Unification and Overlay Architecture Removal

The P2 level change transparentizes 5 dialog backgrounds and removes the Overlay infrastructure.

### P2-1: Dialog Background Transparentization

**Problem**: The 5 dialog windows (ElevationDialogView, SessionRestoreDialogView, UndoViewerView, ExportHistoryView, SolutionDetailView) had opaque or translucent backgrounds, visually disconnected from the transparent backgrounds of ProModeView/SmartModeView/MainFormView.

**Fix**: The 5 dialogs' root `UserControl` removes the `Background` attribute (defaults to null). Default null is more thorough than `Transparent`: not only visually transparent, but also non-participating in hit testing — mouse events pass through directly to the shell starfield.

**Reason**: Dialogs need to be visually consistent with main views, letting the global starfield flow through.

**Impact Scope**: 5 dialog `.xaml` files.

---

### P2-2: Overlay Infrastructure Removal

**Change**: Removes the entire Overlay infrastructure: IAuroraOverlay interface, PushOverlay/PopOverlay/RemoveOverlay methods (from ViewManager.cs), OverlayLayer Grid (from MainWindow.xaml). MainWindow.xaml now retains only AuroraStarfield and ContentControl as child elements. Only the IAuroraStaggerView interface is retained for staggered entrance animations.

**Reason**: The Overlay architecture conflicted with the new transparent dialog scheme and added architectural complexity.

**Impact Scope**: `MainWindow.xaml`, `ViewManager.cs`, 5 dialog `.cs` files.

---

## 4. P3 Level: Permission Selection Timing Relocation

The P3 level change relocates permission selection from inside the main window to after Splash.

### P3-1: New Startup Flow

**Change**: The startup flow changes to App startup → MainWindow shell creation → NavigateTo<SplashScreenView> → SplashScreen LoadingComplete → detect IsCurrentProcessElevated → elevated goes directly to NavigateToMainForm / not elevated goes to ShowElevationDialogDirectly → ElevationDialogView (depth 0.85) → OnElevationResult handles Elevate/ContinueNormal/Exit.

**Reason**: Permission selection originally occupied a main window view slot, coupled with the main flow.

**Impact Scope**: `App.xaml.cs` startup flow.

---

### P3-2: Key Method Implementation

**Change**: `SplashScreenView` adds ShowMainWindow (branches based on IsCurrentProcessElevated), ShowElevationDialogDirectly (navigates directly from Splash to ElevationDialogView), OnElevationResult (handles Elevate/ContinueNormal/Exit), NavigateToMainFormFromElevation (uses `NavigateTo<MainFormView>(true, true)` replaceCurrent to pop Elevation and push MainForm, triggering 0.85 → 0.15 depth parallax).

**Reason**: The permission dialog participates in the starfield parallax depth chain as an independent view.

**Impact Scope**: `SplashScreenView.xaml.cs` ShowMainWindow/ShowElevationDialogDirectly/OnElevationResult/NavigateToMainFormFromElevation.

---

## 5. P4 Level: UWP Text Transition Curves and Language Switch Fix

The P4 level change adopts UWP standard curves and fixes the language switch notification sequence.

### P4-1: UWP Standard Transition Curves

**Change**: `MainFormView.PlayElementSwitch` adopts UWP standard speed curves: exitSpline=(0.7, 0.0, 0.3, 1.0) exit curve, enterSpline=(0.1, 0.9, 0.2, 1.0) entrance curve, settleSpline=(0.45, 0.05, 0.55, 0.95) settle curve. Parameters: exitMs=320, enterMs=640, overMs=420, displacement ±52px, exit scale 0.92, overshoot 1.08.

**Reason**: The original transition curve was too abrupt, not UWP-style.

**Impact Scope**: `MainFormView.xaml.cs` PlayElementSwitch.

---

### P4-2: Language Switch Notification Sequence Reorder

**Problem**: `MainFormViewModel.OnSelectLanguage` original sequence was `SelectedLanguage → IsBusy → CurrentState (triggers AnimateViewTransition) → OnPropertyChanged`, causing `SmartModeInfoTitle` and other bindings to still show old language cache during the switch animation.

**Fix**: All 16 `OnPropertyChanged(...)` notifications are moved before the `CurrentState` assignment. Includes 5 button texts, 2 language panel fields, 4 language description fields, 4 mode description fields, then finally `IsBusy = true` and `CurrentState = MainFormViewState.ModeSelection`.

**Reason**: Wrong notification sequence caused old language display during animation.

**Impact Scope**: `MainFormViewModel.cs` OnSelectLanguage.

---

### P4-3: Cached Instance Language Refresh

**Problem**: ProModeView and SmartModeView did not refresh language when `_initialized=true` (NavigationCache reuse), causing Chinese cache to still display when clicking Smart Mode or Pro Mode from the English menu.

**Fix**: `ProModeView.Initialize` and `SmartModeView.Initialize` add a `language` parameter, synchronizing `_viewModel.Language` before the `_initialized` guard. SmartModeView returns early when reusing a cached instance.

**Reason**: Cached instances did not sync language refresh.

**Impact Scope**: `ProModeView.xaml.cs` Initialize, `SmartModeView.xaml.cs` Initialize.

---

## 6. P5 Level: Smart Mode Status Text Position Fix

The P5 level change fixes the issue where Smart mode UWP status text was squeezed to the bottom-right corner and flew out.

### P5-1: Retry Mechanism and Three-Layer Protection

**Problem**: SmartModeView's UWP status text (StatusText) during the shell entrance animation, because `ProgressAnchor.ActualHeight/ActualWidth` layout was not yet complete, the position calculation returned wrong coordinates, causing the text to be positioned at the bottom-right corner or even fly out of the visible area.

**Fix**: `BeginInvokeUpdateStatusTextPositionWithRetry` adds three layers of protection: retry mechanism (up to 25 times, 80ms interval, covering 1000ms shell entrance animation), layout completion check (`ActualHeight/ActualWidth <= 0` returns false), self scale check (`Math.Abs(s - 1.0) > 0.01` returns false), X upper bound check (`targetX < ActualWidth`). `UpdateStatusTextPosition` schedules the next retry timer when `success == false`.

**Reason**: Layout was not complete during shell entrance animation, position calculation was wrong.

**Impact Scope**: `SmartModeView.xaml.cs` BeginInvokeUpdateStatusTextPositionWithRetry, UpdateStatusTextPosition.

---

### P5-2: Retry Parameter Evolution

**Change**: Retry parameters evolved from the initial version (V1.5.28.9) of 5 times / 50ms interval (covering 250ms, insufficient to cover 1000ms shell animation) to the current (V1.5.28.17) 25 times / 80ms interval (covering 2000ms, fully covering 1000ms shell animation).

**Reason**: The initial retry was insufficient to cover the shell entrance animation duration.

**Impact Scope**: `SmartModeView.xaml.cs` retry parameters.

---

## 7. P6 Level: Keyboard Focus and Navigation Anti-Bounce Unification

The P6 level change fixes the keyboard focus issue and uses a unified navigation lock to eradicate quick-switch flashback.

### P6-1: Keyboard Focus Fix

**Problem**: `MainFormView.AttachInfoHover` only bound the `MouseEnter` event — when keyboard Tab focus switched to a button, the right-side explanatory text did not update.

**Fix**: Extracts the common hover logic into a `focusHandler`, shared by `MouseEnter` and `GotFocus`. All 5 buttons (ChineseBtn, EnglishBtn, SmartModeBtn, ProModeBtn, ConsoleModeBtn) bind both events.

**Reason**: Only binding MouseEnter caused keyboard focus to be unresponsive.

**Impact Scope**: `MainFormView.xaml.cs` AttachInfoHover.

---

### P6-2: Unified Navigation Lock

**Problem**: ProModeView used a local `_isSwitching` flag for anti-bounce, other views had no anti-bounce, causing exit animation interruption during quick switching and `DiscreteDoubleKeyFrame` start value jumps, producing flashback.

**Fix**: Uses the `ViewManager.IsNavigating` public property (exposing the internal `_isNavigating` field) to establish a unified navigation lock. ProModeView removes the local `_isSwitching` flag, uniformly uses `ViewManager.IsNavigating`. All navigation entry points reject new requests during animation.

**Reason**: Inconsistent local flag anti-bounce caused flashback.

**Impact Scope**: `ViewManager.cs` IsNavigating, `ProModeView.xaml.cs`.

---

### P6-3: 5 Navigation Entry Point Anti-Reentry Checks

**Change**: 5 navigation entry points add `if (ViewManager.Current.IsNavigating) return;` anti-reentry checks: SmartModeView's OnReturnToProRequested and OnShowUndoViewerRequested, ExportHistoryView's OnCloseRequested and OpenSolutionDetail, SolutionDetailView's OnCloseRequested. Additionally, ProModeView's OnShowHistoryRequested (line 886) and another navigation point (line 910) use the same guard (V1.5.28.23).

**Reason**: New navigation requests during exit animation caused flashback.

**Impact Scope**: `SmartModeView.xaml.cs`, `ExportHistoryView.xaml.cs`, `SolutionDetailView.xaml.cs`, `ProModeView.xaml.cs`.

---

## 8. P7 Level: Starfield Parallax Performance Optimization (Aurora Layer +50%)

The P7 level change fixes severe frame drops during parallax and replaces star glow with aurora layer boost.

### P7-1: Skip SoftGlow and DiffractionSpike

**Problem**: The original scheme enabled SoftGlow (soft glow) and DiffractionSpike (diffraction spikes) for near stars during parallax, but both costs scale linearly with star count — `DrawSoftGlow` requires PushTransform + DrawGeometry per star, causing severe frame drops with large star counts.

**Fix**: Both SoftGlow and DiffractionSpike branches are skipped during parallax (`isParallaxCycling == true`).

**Reason**: Star glow cost scales linearly with star count, causing frame drops.

**Impact Scope**: `AuroraStarfield.cs` DrawStars SoftGlow/DiffractionSpike branches.

---

### P7-2: DrawAurora Aurora Layer +50% Alpha Boost

**Change**: As a visual feedback replacement, introduces a +50% alpha boost in the `DrawAurora` aurora layer. During parallax (`_parallaxState == ParallaxState.Cycling`), computes `parallaxBoost = 1.0 + pSmooth * 0.5` (max 1.5), applied to each aurora wisp's `localAlpha`. Fixed cost, independent of star count.

**Reason**: Need a visual feedback replacement independent of star count.

**Impact Scope**: `AuroraStarfield.cs` DrawAurora parallaxBoost computation.

---

### P7-3: smoothstep Smoothing (V1.5.28.27)

**Problem**: The original `parallaxBoost` used `_viewParallaxPhase` (depth position) as animation progress, but `_viewParallaxPhase` is the final depth target (e.g. 0.15→0.30), not animation progress t (0→1). This caused MainForm view1→view2 transitions to have `phase` permanently < 0.25, always in the "ramp-up" segment with no ramp-down, and when parallax ended and state transitioned from Cycling to Idle, `parallaxBoost` jumped from 1.5 back to 1.0, producing a brightness discontinuity.

**Fix**: `parallaxBoost` now uses actual animation time progress `t` (0→1) with smoothstep to compute a trapezoidal curve: ramp up 0→25% (pSmooth 0→1, parallaxBoost 1.0→1.5), hold 25-75% (pSmooth=1, parallaxBoost=1.5), ramp down 75-100% (pSmooth 1→0, parallaxBoost 1.5→1.0).

**Reason**: The original implementation caused brightness discontinuity and abnormal MainForm internal transitions.

**Impact Scope**: `AuroraStarfield.cs` DrawAurora parallaxBoost computation logic.

---

## 9. Compatibility Preservation

V1.5.29.0 maintains full compatibility in the following aspects while reshaping parallax depth and unifying dialog visuals:

| Compatibility Item | Description |
|--------------------|-------------|
| PowerShell 5.1 compatibility | C# code still compiled using C# 5.0 language version |
| Command-line parameters | All command-line parameters fully compatible, no additions or removals |
| syncHash synchronization mechanism | syncHash interface for cross-Runspace communication fully compatible |
| Environment variable interfaces | All environment variable interfaces fully compatible |
| Script interfaces | PowerShell script engine interface unchanged |
| Material pipeline | V5 material pipeline interface unchanged, AuroraFrostedGlassBorder/AuroraFrostedGlassCard behavior unchanged |
| Animation interfaces | Control-level animation method signatures unchanged, AnimationHelper public methods unchanged |
| Glass material capture | Precision config unchanged (30fps/1/2 resolution/BlurRadius=2.5) |
| Render backend | Default still prefers GPU hardware acceleration, only falls back on software rendering or remote session |
| Starfield star count | Parallax depth reshape does not increase rendered star count, only controls global parallax intensity |
| Dialog interfaces | Dialog public interfaces unchanged, only internal background and Overlay implementation removed |

---

## 10. Change List Overview

| ID | Level | Change Description | Change Reason | Impact Scope |
|----|-------|---------------------|---------------|--------------|
| P1-1 | P1 | 7-level depth mapping | Original 4-level scheme had three "no-parallax" branches | ViewManager GetViewDepth |
| P1-2 | P1 | MainForm internal dynamic depth | Correct starfield level when returning to MainForm | MainFormView CurrentInternalDepth |
| P1-3 | P1 | Parallax intensity coefficient boost (0.18→0.28, 0.5→0.62) | Original coefficients made depth differences inconspicuous | AuroraStarfield parallax rendering |
| P1-4 | P1 | Parallax duration dynamic alignment and targetPhase interpolation | Synchronize parallax with view switch animation | AuroraStarfield StartParallaxCycle/ViewManager NavigateTo |
| P2-1 | P2 | 5 dialog background transparentization | Visual consistency with main views | 5 dialog .xaml files |
| P2-2 | P2 | Overlay infrastructure removal | Architecture complexity conflicted with transparent scheme | MainWindow.xaml/ViewManager.cs/5 dialog .cs files |
| P3-1 | P3 | New startup flow (Splash→Elevation→MainForm) | Decouple permission from main flow | App.xaml.cs startup flow |
| P3-2 | P3 | SplashScreenView key method implementation | Permission dialog participates in parallax depth chain | SplashScreenView ShowMainWindow/ShowElevationDialogDirectly/OnElevationResult/NavigateToMainFormFromElevation |
| P4-1 | P4 | UWP standard transition curves | Original curve too abrupt | MainFormView PlayElementSwitch |
| P4-2 | P4 | Language switch notification sequence reorder | Old language cache displayed during animation | MainFormViewModel OnSelectLanguage |
| P4-3 | P4 | Cached instance language refresh | Cached instances did not sync language | ProModeView/SmartModeView Initialize |
| P5-1 | P5 | Status text retry mechanism and three-layer protection | Layout incomplete during shell animation | SmartModeView BeginInvokeUpdateStatusTextPositionWithRetry/UpdateStatusTextPosition |
| P5-2 | P5 | Retry parameter evolution (5/50ms → 25/80ms) | Initial retry insufficient | SmartModeView retry parameters |
| P6-1 | P6 | Keyboard focus fix (focusHandler shared) | Only MouseEnter caused keyboard unresponsive | MainFormView AttachInfoHover |
| P6-2 | P6 | Unified navigation lock (IsNavigating) | Inconsistent local flag anti-bounce | ViewManager IsNavigating/ProModeView |
| P6-3 | P6 | 5 navigation entry point anti-reentry checks | New navigation during exit animation caused flashback | SmartModeView/ExportHistoryView/SolutionDetailView/ProModeView |
| P7-1 | P7 | Skip SoftGlow/DiffractionSpike | Star glow cost linear with star count | AuroraStarfield DrawStars |
| P7-2 | P7 | DrawAurora aurora layer +50% alpha boost | Fixed cost replacement for star glow | AuroraStarfield DrawAurora |
| P7-3 | P7 | smoothstep smoothing (V1.5.28.27) | Original implementation had brightness discontinuity | AuroraStarfield DrawAurora parallaxBoost |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *This tool is intended for personal educational use only. Please comply with local laws and regulations.*
