# AURORA Analyzer V1.5.29.1 Update Notes

> **Windows Event Log Export and Intelligent Diagnostic Tool**
>
> Version: V1.5.29.1Release · Build Date: 2026.07.27 · Author: AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **Warning**: This tool is intended for personal educational use only. Please comply with local laws and regulations.

---

## Table of Contents

1. [Version Overview](#1-version-overview)
2. [P1 Level: Quick-Switch Flashback Fix (_pendingEnterTimers Pattern)](#2-p1-level-quick-switch-flashback-fix-_pendingentertimers-pattern)
3. [P2 Level: Starfield Depth Visual Optimization (Star Enlargement + Parallax Parameter Rollback)](#3-p2-level-starfield-depth-visual-optimization-star-enlargement--parallax-parameter-rollback)
4. [P3 Level: Meteor-Style Halo Trail System](#4-p3-level-meteor-style-halo-trail-system)
5. [P4 Level: View Depth Reallocation](#5-p4-level-view-depth-reallocation)
6. [P5 Level: Admin Path Teleport Fix (Pre-Parallax Scheme)](#6-p5-level-admin-path-teleport-fix-pre-parallax-scheme)
7. [P6 Level: Mode-Switch Polling State Isolation Fix](#7-p6-level-mode-switch-polling-state-isolation-fix)
8. [P7 Level: Runspace Reuse Scope and Fast-Completing Engine Stability Fix](#8-p7-level-runspace-reuse-scope-and-fast-completing-engine-stability-fix)
9. [Compatibility Maintained](#9-compatibility-maintained)
10. [Change List Overview](#10-change-list-overview)

---

## 1. Version Overview

V1.5.29.1 is an AURORA-Analyzer release focused on "depth visual expressiveness and switching robustness", building upon the V1.5.29.0 multi-level depth parallax reshape. This update covers six core areas: quick-switch flashback fix, starfield depth visual optimization, meteor-style halo trail system, view depth reallocation, admin path teleport fix, and mode-switch polling state isolation fix. The PowerShell engine layer remains compatible; all command-line parameters, environment variable interfaces, and the syncHash synchronization mechanism remain unchanged.

For depth trails, V1.5.29.1 establishes a complete velocity-driven model: trail length is driven by normalized velocity, direction adapts to zoomOut/zoomIn, EMA smoothing eliminates inter-frame jitter, soft-threshold transition eliminates flicker, and the trail disappears immediately when parallax ends.

For view depth, V1.5.29.1 reallocates 5 dialog/detail view depths: ExportHistory 0.70, UndoViewer 0.78, Elevation 0.82, SessionRestore 0.86, SolutionDetail 0.95, eliminating zero-span switches between peer views.

For switching robustness, V1.5.29.1 uses the `_pendingEnterTimers` list to uniformly manage the entrance timer lifecycle, ensuring all unfinished entrance timers are canceled before the exit animation starts.

V1.5.29.1 achieves comprehensive upgrades through the following core strategies:

- **Quick-switch flashback fix**: 6 views uniformly adopt the `_pendingEnterTimers` pattern
- **Starfield depth visual optimization**: Star enlargement + parallax parameter rollback
- **Meteor-style halo trail**: LinearGradientBrush gradient, velocity-driven, EMA-smoothed
- **View depth reallocation**: 5 view depths spread out, eliminating zero-span
- **Admin path teleport fix**: Pre-parallax scheme, 500ms dash to 0.30 then NavigateTo
- **Mode-switch polling state isolation fix**: StartSyncHashPolling resets the _pollingSuspended flag, fixing console non-echo and progress stuck at 50%
- **Runspace reuse scope and fast-completing engine stability fix**: SmartEngine adds Get-Command guard before LaunchGuard call, forces Progress=100 on completion signal, and syncs SecurityModule hash list

This update is a "comprehensive depth visual expressiveness upgrade, switching robustness flashback eradication" release. All user-facing command-line interfaces, environment variables, and cross-Runspace communication protocols remain fully compatible, ensuring existing scripts and workflows run without modification.

---

## 2. P1 Level: Quick-Switch Flashback Fix (_pendingEnterTimers Pattern)

The P1 level change fixes the issue of controls flashing back to their original position during quick switching.

### P1-1: Flashback Root Cause

**Problem**: The `DispatcherTimer` instances created by `PlayControlEnterAnimation` (per-tile stagger timers, fallback backup timers, listDelay list-item delay timers) are fire-and-forget. If the user clicks a switch button during the entrance animation to trigger `PlayStaggerExit`, these pending timers fire while the exit animation is in progress: per-tile timers call `BeginAnimation` overriding the exit animation, fallback timers directly force `tile.Opacity=1` + `ScaleX=1` + `Y=0`, and listDelay timers trigger `PlayListItemEnterAnimation` to re-enter list items.

**Fix**: Uniformly aligns with the ProModeView benchmark `_pendingEnterTimers` pattern — add a field to track pending timers, add a `CancelPendingEnterTimers()` method to uniformly stop them, `PlayControlEnterAnimation` registers timers to the list, and `PlayControlExitAnimation` calls `CancelPendingEnterTimers()` at the start.

**Reason**: Fire-and-forget timers firing during the exit animation cause state override.

**Impact Scope**: 6 views' `.xaml.cs` files.

---

### P1-2: 6 Fixed Views

**Change**: 6 IAuroraStaggerView views uniformly adopt the `_pendingEnterTimers` pattern: ProModeView (per-tile + fallback), SmartModeView (per-tile + fallback), ExportHistoryView (per-tile + fallback + listDelay), SolutionDetailView (per-tile + fallback), ElevationDialogView (per-tile + fallback), SessionRestoreDialogView (per-tile + fallback).

**Reason**: All 6 views have fire-and-forget entrance timers with flashback risk.

**Impact Scope**: `ProModeView.xaml.cs`, `SmartModeView.xaml.cs`, `ExportHistoryView.xaml.cs`, `SolutionDetailView.xaml.cs`, `ElevationDialogView.xaml.cs`, `SessionRestoreDialogView.xaml.cs`.

---

### P1-3: Unfixed View Assessment

**Change**: 3 views were evaluated as not needing fix: MainFormView (mostly internal state switches; exit only staggers buttons + title; low override risk), SplashScreenView (one-time startup scenario; no quick-switch path), UndoViewerView (exit uses `_closeSafetyTimer` as backup; no per-tile entrance timer chain).

**Reason**: These 3 views do not have the risk of fire-and-forget entrance timers overriding the exit animation.

**Impact Scope**: None.

---

## 3. P2 Level: Starfield Depth Visual Optimization (Star Enlargement + Parallax Parameter Rollback)

The P2 level change optimizes the visual expressiveness of starfield depth motion.

### P2-1: Star Enlargement and Brightening

**Change**: `AuroraStarfield.cs` adjusts star size and brightness parameters: Size base coefficient 0.8→1.1 (~37% overall enlargement), CurrentRenderSize initial 0.55×→0.7× (visible immediately on entrance), BaseAlpha upper limit 130→180 (higher bright-star ratio).

**Reason**: During depth motion, stars were too small and dim, making motion feedback not prominent.

**Impact Scope**: `AuroraStarfield.cs` DrawStars.

---

### P2-2: Parallax Parameter Rollback

**Change**: Parallax parameters went through multiple rounds of tuning, finally rolling back to balanced values: push displacement 0.28→0.30 (intermediate 0.36, -17% reducing in-your-face impact), scale 0.4→0.45 (intermediate 0.6, -25% reducing enlargement impact), opacity dimming 0.62→0.25 (brightness recovers from 38% to 75%).

**Reason**: opacity 0.62 was the direct cause of "not eye-catching enough" — during parallax, star brightness was cut by nearly two-thirds; push 0.36 and scale 0.6 produced excessive impact feel.

**Impact Scope**: `AuroraStarfield.cs` parallax render path.

---

## 4. P3 Level: Meteor-Style Halo Trail System

The P3 level change introduces a meteor-style halo trail for starfield depth motion.

### P3-1: Trail Form Selection

**Change**: After evaluating four trail forms (comet trail, speed line, afterimage overlay, halo elongation), selected the LinearGradientBrush gradient halo trail (comet tail form), with the transparent end at tail and bright end at head, Pen width linked to star size.

**Reason**: The comet tail form has strong direction sense and good visual texture, with acceptable performance cost (new Brush per star, but parallax is only 2.7s).

**Impact Scope**: `AuroraStarfield.cs` OnRender trail drawing.

---

### P3-2: Trigger Conditions

**Change**: The trail is only drawn during parallax (`isParallaxCycling && _parallaxVelocity > 0.0002`) + for near-field stars (Depth > 0.6, ~150-200 stars). It disappears immediately when parallax ends (not drawn in Idle state).

**Reason**: Only near-field stars need trails to reinforce direction sense; far-field stars stay circular to reinforce hierarchy; not drawing in Idle preserves tranquility.

**Impact Scope**: `AuroraStarfield.cs` OnRender trail branch.

---

### P3-3: Velocity-Driven Model and Normalization

**Change**: Trail length is driven by normalized velocity: `trailLen = (absoluteVelocity / parallaxSpan) × depth × 1500`. After normalization, regardless of span size, the peak trail length is consistent.

**Reason**: Small depth-difference scenes (e.g., MainForm→ProMode 0.15→0.50) have low absolute velocity, so trails would be shortened too much. Normalization ensures small depth differences also have sufficient trail visibility.

**Impact Scope**: `AuroraStarfield.cs` OnRender trail length calculation.

---

### P3-4: Trail Direction Adaptation

**Change**: A new `_parallaxDirection` field (+1=zoomOut / -1=zoomIn) is added, judged in `StartParallaxCycle` based on the difference between target phase and start phase: zoomOut points the trail end toward center, zoomIn points the trail end outward.

**Reason**: The original implementation had a fixed trail direction, which was wrong for zoomIn.

**Impact Scope**: `AuroraStarfield.cs` StartParallaxCycle, OnRender trail direction calculation.

---

### P3-5: EMA Smoothing and Soft-Threshold Transition

**Change**: EMA exponential moving average (α=0.3) eliminates inter-frame jitter: `_parallaxVelocitySmooth = _parallaxVelocitySmooth × 0.7 + _parallaxVelocity × 0.3`. Soft-threshold transition eliminates hard-threshold cutoff flicker: normalized velocity <0.0002 not drawn, 0.0002~0.001 linear 0→1 transition, >0.001 full intensity. In Idle state, `_parallaxVelocitySmooth *= 0.5` halves every frame, zeroing out within 2-3 frames.

**Reason**: Inter-frame jitter caused trail length flicker; hard-threshold cutoff caused trail appear/disappear flicker; Idle residue caused next-frame flicker.

**Impact Scope**: `AuroraStarfield.cs` animation advance logic, OnRender trail intensity calculation.

---

### P3-6: Trail Multiplier Tuning

**Change**: Trail multiplier reduced from 1200 to 600, avoiding the "rocket exhaust" feel.

**Reason**: The 1200 multiplier made the trail too long, visually like rocket exhaust; the 600 multiplier makes the trail moderate and naturally vivid.

**Impact Scope**: `AuroraStarfield.cs` OnRender trail length multiplier.

---

## 5. P4 Level: View Depth Reallocation

The P4 level change reallocates the depths of 5 dialog/detail views.

### P4-1: Peer View Zero-Span Problem

**Problem**: V1.5.29.0's 5 dialog/detail views were all piled at 0.85, with zero span between mutual switches: History→Undo 0.00, Permission→Session 0.00, History→Detail 0.15 (depth too weak), Pro→Smart 0.10 (weak depth).

**Fix**: Reallocated depths: ExportHistoryView 0.85→0.70, UndoViewerView 0.85→0.78, ElevationDialogView 0.85→0.82, SessionRestoreDialogView 0.85→0.86, SolutionDetailView 1.00→0.95.

**Reason**: Peer view zero-span caused switches to have no depth feedback.

**Impact Scope**: `ViewManager.cs` GetViewDepth.

---

### P4-2: New Span Comparison

**Change**: New spans: History→Detail 0.15→0.25 (+67%), History→Undo 0.00→0.08 (from none to present), Permission→Session 0.00→0.04 (from none to present), Main→History 0.70→0.55 (still strong shuttle), ProMode→History 0.35→0.20 (lightweight popup feel).

**Reason**: Spread out peer view depths so every click has visible depth feedback.

**Impact Scope**: `ViewManager.cs` GetViewDepth.

---

## 6. P5 Level: Admin Path Teleport Fix (Pre-Parallax Scheme)

The P5 level change fixes the starfield teleport issue on the admin path's Splash→MainForm.

### P5-1: Teleport Root Cause

**Problem**: The admin path (elevated process) skips ElevationDialog (depth 0.82), leaving the Splash(0.0)→MainForm(0.15) parallax span at only 0.15. After the starfield motion is occluded by the Splash exit and MainForm entrance animations, it visually looks like "suddenly jumping to a new position". The non-admin path Splash→ElevationDialog(0.82)→MainForm has a large span with sufficient motion, performing normally.

**Fix**: Adopts the pre-parallax scheme — before NavigateTo, first let the starfield run alone for 500ms to dash to 0.30, letting the user clearly see starfield motion, then start Splash exit + MainForm entrance. The starfield motion splits into two segments: 0.0→0.30 (pre, visible) →0.15 (during MainForm entrance, falls back).

**Reason**: The 0.15 span is too small; motion is occluded, and the user cannot perceive the intermediate process.

**Impact Scope**: `SplashScreenView.xaml.cs` NavigateToMainForm.

---

### P5-2: Timeline Design

**Change**: T=0 pre-parallax starts 0.0→0.30 (500ms) → T=500 NavigateTo starts + Splash exit (800ms) + parallax 0.30→0.15 (2700ms) → T=1300 Splash exit completes, Content switches + MainForm entrance (800ms) → T=3200 parallax ends, settles at 0.15.

**Reason**: Lets the user perceive starfield motion before Splash exits, eliminating the "stuck then jump" teleport feel.

**Impact Scope**: `SplashScreenView.xaml.cs` NavigateToMainForm.

---

## 7. P6 Level: Mode-Switch Polling State Isolation Fix

The P6 level change fixes the issue where, after returning from Smart Mode to the main window and re-entering Pro Mode, the console no longer echoes output and progress is stuck at 50%.

### P6-1: Polling Flag State Leak

**Problem**: The `ProModeViewModel.StartSyncHashPolling()` method does not reset the `_pollingSuspended` flag to `false` when starting the syncHash polling timer. The flag is set to `true` by `SuspendPolling()` after SmartMode completes, set again (kept true) by `OnUnloaded` when returning to MainForm, and on re-entry into ProMode, `ResetForReentry()` takes the reset branch (because `IsRunning=false`) and does not resume polling (correct — the script has ended), but the flag remains true. After the user clicks "Start Analysis", `StartSyncHashPolling()` starts the timer, but `ProcessSyncHashSnapshot` detects `_pollingSuspended=true` and returns immediately, so logs/progress/ScriptDone are all left unprocessed — the console does not echo and progress is stuck at 50%. Only the `FlushRemainingLogOutput` forced read in the "Force Stop" finally block can recover any output.

**Fix**: `StartSyncHashPolling` now resets `_pollingSuspended = false` at its start, ensuring the flag is clean every time polling starts.

**Reason**: The `_pollingSuspended` flag's lifecycle has a gap — `SuspendPolling` sets it to true but `StartSyncHashPolling` has no corresponding reset.

**Impact Scope**: `ProModeViewModel.cs` StartSyncHashPolling.

---

### P6-2: ClearConsole Async Clear Timing Error

**Change**: `ClearConsole` changed from async `BeginInvoke` to synchronous `Invoke`/direct call.

**Reason**: The `ConsoleLines.Clear()` queued by async `BeginInvoke` executes after subsequently `Add`-ed content (synchronous), so the just-displayed logs get wiped by the async clear — the user sees "content flashes then disappears".

**Impact Scope**: `ProModeViewModel.cs` ClearConsole.

---

### P6-3: AppendConsoleLine Cross-Thread Handling

**Change**: `AppendConsoleLine` now uses `Dispatcher.CheckAccess()` to strictly determine the thread — on the UI thread it calls `ConsoleLines.Add` directly; on non-UI threads it switches back via `BeginInvoke(Loaded)`.

**Reason**: `ObservableCollection.Add` called from a non-UI thread does not throw, but the `CollectionChanged` notification does not propagate to the UI thread's Binding, so logs are written but the console never updates.

**Impact Scope**: `ProModeViewModel.cs`, `SmartModeViewModel.cs` AppendConsoleLine.

---

### P6-4: DispatcherTimer Starved by Render

**Change**: The `_syncHashTimer` callback now uses `Dispatcher.Invoke` (synchronous) instead of `BeginInvoke` (asynchronous).

**Reason**: `BeginInvoke(Loaded)` is still deferred by AuroraStarfield's `CompositionTarget.Rendering` continuous rendering work, so `ProcessSyncHashSnapshot` never gets a turn to execute.

**Impact Scope**: `ProModeViewModel.cs`, `SmartModeViewModel.cs` polling callback.

---

### P6-5: Mistaken Clear When LogOutput Is Empty

**Change**: In `ProcessSyncHashSnapshot`, when LogOutput is empty or becomes shorter, `ClearConsole()` is no longer called — only `_lastLogLength` is reset.

**Reason**: The engine may reset LogOutput between Phases, which would wipe out the just-displayed logs.

**Impact Scope**: `ProModeViewModel.cs`, `SmartModeViewModel.cs` ProcessSyncHashSnapshot.

---

## 8. P7 Level: Runspace Reuse Scope and Fast-Completing Engine Stability Fix

The P7 level change fixes the Assert-AuroraLaunchContext error when running Pro Mode first then terminating and running Smart Mode, and the probabilistic 50% progress stuck issue when the smart engine completes very quickly.

### P7-1: Assert-AuroraLaunchContext Command Not Found

**Problem**: Running Pro Mode first, then terminating it and running Smart Mode produces the error "The term 'Assert-AuroraLaunchContext' is not recognized as the name of a cmdlet, function, script file, or operable program." SmartEngine.ps1 calls Assert-AuroraLaunchContext directly without a Get-Command existence check (PRO-Engine.ps1 has this protection, SmartEngine lacks it). Under Runspace reuse, after ProMode terminates PRO Engine, the global variable $AURORA_LaunchGuard_Loaded=true persists. Although LaunchGuard.ps1 already removed the `return` to prevent skipping the function definition, Runspace state pollution can cause dot-source to execute incompletely, and the direct call triggers CommandNotFoundException.

**Fix**: Align with PRO-Engine's defensive call pattern — check Get-Command for function existence before calling Assert-AuroraLaunchContext.

**Reason**: The direct call without an existence check cannot tolerate Runspace state pollution where the function definition is lost.

**Impact Scope**: `AURORA-SmartEngine.ps1` LaunchGuard call site (lines 45-61).

---

### P7-2: Probabilistic 50% Progress Stuck

**Change**: In SmartModeViewModel.cs ProcessSyncHashSnapshot, when ScriptDone=true is detected, force Progress=100 regardless of IsRunning state, then decide whether to call OnScriptComplete.

**Reason**: When SmartEngine completes very quickly (within 1 second), Progress changes rapidly from 50→80→100. The poll samples Progress=50, then SmartEngine instantly completes and sets ScriptDone=true. On the next poll, if IsRunning has already been reset to false by another path, OnScriptComplete is not called and Progress=100 is never set.

**Impact Scope**: `SmartModeViewModel.cs` ProcessSyncHashSnapshot (lines 690-707).

---

### P7-3: SecurityModule Hash List Sync

**Change**: Update the SHA256 hashes of both files in AURORA-SecurityModule.ps1:
- AURORA-LaunchGuard.ps1: 35fc9ce7ea399c6995fa0f8f22249a248522e2d7562733bf951b11118cad057f → 40b25a683e722486766aad4c5c9cfbee17f23cc932c18d18b87f43c4a67d062c
- AURORA-SmartEngine.ps1: e703e7c14d9f9b9bbd51233b157ba966b9e678d76deec1d6c711dc6a8a82a63e → d29fdfd850c207f679073a3c9ffa1e8c2c6854ec302316c4d68b70ba7e1af485

**Reason**: After modifying LaunchGuard.ps1 and SmartEngine.ps1, the hash list in SecurityModule.ps1 no longer matches. _integrityCacheDuration = TimeSpan.Zero (no cache), so CheckIntegrity re-verifies every time. A hash mismatch causes VerifyOrDie to return false, forcing SmartEngine to exit.

**Impact Scope**: `AURORA-SecurityModule.ps1` hash list (lines 188 and 201).

---

## 9. Compatibility Maintained

While performing depth visual optimization and switching robustness fixes, V1.5.29.1 maintains full compatibility in the following areas:

| Compatibility Item | Notes |
|--------------------|-------|
| PowerShell 5.1 compatibility | C# code still compiles with C# 5.0 language version |
| Command-line parameters | All command-line parameters fully compatible, no additions or removals |
| syncHash synchronization | Cross-Runspace syncHash interface fully compatible |
| Environment variable interface | All environment variable interfaces fully compatible |
| Script interface | PowerShell script engine interface unchanged |
| Material pipeline | V5 material pipeline interface unchanged; AuroraFrostedGlassBorder/AuroraFrostedGlassCard behavior unchanged |
| Animation interface | Control-level animation method signatures unchanged; AnimationHelper public methods unchanged |
| Glass material capture | Precision config unchanged (30fps / 1/2 resolution / BlurRadius=2.5) |
| Render backend | Default still prefers GPU hardware acceleration; only falls back on software rendering or remote session |
| Starfield star count | Depth optimization does not increase rendered star count; only adjusts size/brightness/trail |
| View interface | IAuroraStaggerView interface unchanged; only internal timer management implementation optimized |
| Trail GC trade-off | During parallax, ~150 stars × 1 new Brush + 2 GradientStop + 1 Pen per star per frame, but parallax is only 2.7s and already skips halo/spike/constellation-line rendering, so GC pressure is acceptable |
| Polling state isolation | The _pollingSuspended flag is reset when StartSyncHashPolling starts; does not affect the existing SuspendPolling/ResumePolling interface |

---

## 10. Change List Overview

| ID | Level | Change Description | Reason | Impact Scope |
|------|------|----------|----------|----------|
| P1-1 | P1 | _pendingEnterTimers pattern fixes flashback | Fire-and-forget timers override exit animation | 6 views' .xaml.cs |
| P1-2 | P1 | 6 views uniformly fixed | All views have flashback risk | ProModeView/SmartModeView/ExportHistoryView/SolutionDetailView/ElevationDialogView/SessionRestoreDialogView |
| P1-3 | P1 | 3 views evaluated as not needing fix | No timer override risk | MainFormView/SplashScreenView/UndoViewerView |
| P2-1 | P2 | Star enlargement and brightening (Size 0.8→1.1, BaseAlpha 130→180) | Stars not prominent during depth motion | AuroraStarfield DrawStars |
| P2-2 | P2 | Parallax parameter rollback (push 0.30, scale 0.45, opacity 0.25) | opacity 0.62 too dark, push/scale too aggressive | AuroraStarfield parallax rendering |
| P3-1 | P3 | LinearGradientBrush gradient halo trail | Reinforce motion direction sense | AuroraStarfield OnRender |
| P3-2 | P3 | Trigger conditions (during parallax + Depth>0.6) | Only near-field stars need trail | AuroraStarfield OnRender trail branch |
| P3-3 | P3 | Normalized velocity drive | Small depth-difference trail shortened | AuroraStarfield OnRender trail length |
| P3-4 | P3 | Trail direction adaptation (zoomOut/zoomIn) | Original fixed direction wrong for zoomIn | AuroraStarfield StartParallaxCycle/OnRender |
| P3-5 | P3 | EMA smoothing + soft-threshold transition | Inter-frame jitter + hard-cut flicker | AuroraStarfield animation advance/OnRender |
| P3-6 | P3 | Trail multiplier 1200→600 | Avoid rocket exhaust feel | AuroraStarfield OnRender trail multiplier |
| P4-1 | P4 | 5 view depths reallocated | Peer views zero-span | ViewManager GetViewDepth |
| P4-2 | P4 | New span comparison | Every click has depth feedback | ViewManager GetViewDepth |
| P5-1 | P5 | Admin path pre-parallax fix | Span 0.15 too small, starfield teleport | SplashScreenView NavigateToMainForm |
| P5-2 | P5 | Pre-parallax timeline design | Make starfield motion visible before Splash exit | SplashScreenView NavigateToMainForm |
| P6-1 | P6 | StartSyncHashPolling resets _pollingSuspended=false | Flag leak caused polling to be skipped | ProModeViewModel StartSyncHashPolling |
| P6-2 | P6 | ClearConsole changed to synchronous execution | Async clear timing overrode subsequent Add | ProModeViewModel ClearConsole |
| P6-3 | P6 | AppendConsoleLine uses CheckAccess to strictly determine thread | Cross-thread CollectionChanged does not propagate | ProModeViewModel/SmartModeViewModel AppendConsoleLine |
| P6-4 | P6 | _syncHashTimer callback uses Dispatcher.Invoke instead of BeginInvoke | Async dispatch starved by Render | ProModeViewModel/SmartModeViewModel polling callback |
| P6-5 | P6 | When LogOutput is empty, do not clear console; only reset _lastLogLength | Engine resetting LogOutput between Phases mistakenly cleared console | ProModeViewModel/SmartModeViewModel ProcessSyncHashSnapshot |
| P7-1 | P7 | SmartEngine adds Get-Command check before calling Assert-AuroraLaunchContext | Runspace reuse caused function definition loss triggering CommandNotFoundException | AURORA-SmartEngine.ps1 LaunchGuard call |
| P7-2 | P7 | Force Progress=100 when ScriptDone=true detected | Polling sampling timing when engine completes quickly caused OnScriptComplete not called | SmartModeViewModel ProcessSyncHashSnapshot |
| P7-3 | P7 | Update SHA256 hashes of LaunchGuard and SmartEngine | Script modifications caused hash mismatch forcing VerifyOrDie exit | AURORA-SecurityModule.ps1 hash list |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *This tool is for personal educational use only. Please comply with local laws and regulations.*
