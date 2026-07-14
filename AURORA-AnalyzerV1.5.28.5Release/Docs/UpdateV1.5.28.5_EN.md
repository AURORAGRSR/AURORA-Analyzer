# AURORA Analyzer V1.5.28.5 Release Notes

> **Windows Event Log Export and Intelligent Diagnostic Tool**
>
> Version: V1.5.28.5Release · Build Date: 2026.07.14 · Author: AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **Warning**: This tool is intended for personal educational use only. Please comply with local laws and regulations.

---

## Table of Contents

1. [Version Overview](#1-version-overview)
2. [P1 Level: Security Update Batch Hardening](#2-p1-level-security-update-batch-hardening)
3. [P2 Level: Rendering Mechanism Refactor and Refresh Rate Adaptation](#3-p2-level-rendering-mechanism-refactor-and-refresh-rate-adaptation)
4. [P3 Level: Console Mode GUI/CLI Dual-Mode Compatibility](#4-p3-level-console-mode-guicli-dual-mode-compatibility)
5. [P4 Level: SMART SLI Smart Mode Invocation Bridge](#5-p4-level-smart-sli-smart-mode-invocation-bridge)
6. [P5 Level: PRO Mode Control Entrance Animation Time Jump Fix](#6-p5-level-pro-mode-control-entrance-animation-time-jump-fix)
7. [P6 Level: History View Hit Detection Mechanism Fix](#7-p6-level-history-view-hit-detection-mechanism-fix)
8. [P7 Level: Solution Entry Point Addition](#8-p7-level-solution-entry-point-addition)
9. [P8 Level: Bottom Buttons Staggered Entrance Animation Optimization](#9-p8-level-bottom-buttons-staggered-entrance-animation-optimization)
10. [P9 Level: Undo Manager Optimization and Fix](#10-p9-level-undo-manager-optimization-and-fix)
11. [P10 Level: Main Window Language Order and Detail Optimization](#11-p10-level-main-window-language-order-and-detail-optimization)
12. [Compatibility Preservation](#12-compatibility-preservation)
13. [Change Summary Table](#13-change-summary-table)

---

## 1. Version Overview

V1.5.28.5 is an AURORA-Analyzer release that builds upon the V1.5.28.0 view system reshaping with a rendering mechanism refactor and console mode usability upgrade. This update covers seven core domains: security update batch hardening, rendering mechanism refactor and refresh rate adaptation, console mode GUI/CLI dual-mode compatibility, SMART SLI smart mode invocation bridge, PRO mode animation fix, history view and solution view multiple optimizations, main window and global visual detail optimization. The PowerShell engine layer remains compatible, and all command-line parameters, environment variable interfaces, and the syncHash synchronization mechanism are preserved unchanged.

In rendering optimization, V1.5.28.5 establishes a complete GPU utilization optimization chain: startup probing (MaterialCapabilities.Probe probes GPU vendor/VRAM/D3D9Ex/ShaderEffect/remote session), dynamic tiering (Eco/Balanced/Performance/Extreme four tiers), render layer lazy subscription (CompositionTarget.Rendering subscribes on first registration, unsubscribes on last unregistration), backend three-level fallback chain (ShaderEffect HLSL → RtbBlurBackend), frequency adaptive throttling (10/15/20/30fps), remote session dual-path detection (GetSystemMetrics + WTSQuerySessionInformation).

In animation normalization, V1.5.28.5 corrects the timeScale denominator from 16.667 (60fps) to 22.222 (45fps), matching the actual average frame rate that DispatcherTimer achieves at Render priority due to Dispatcher queue scheduling jitter, making AuroraButton, AuroraTaskHUD, and AuroraProgressBar animation speeds consistent with design intent.

For console mode, V1.5.28.5 implements the complete smart repair flow in a pure console environment via the AURORA-SmartEngine-CLI.ps1 three-layer architecture (thread-safe syncHash + background Runspace executing SmartEngine + main thread polling responding to GUI events).

V1.5.28.5 achieves comprehensive upgrade through the following core strategies:

- **Security Hardening**: Patches privilege escalation command line parameter injection, Invoke-Expression command injection and cache poisoning, integrity check TOCTOU window
- **Rendering Refactor**: Six-in-one GPU utilization optimization mechanism, refresh rate adaptive normalization
- **Console Dual-Mode**: AURORA-SmartEngine-CLI.ps1 adaptation layer, all five GUI wait points handled
- **SMART SLI**: Console mode invokes Smart Mode
- **Animation Fix**: PRO mode dynamic fallback timer
- **Detection Fix**: Health score floating-point arithmetic, scan window dynamic expansion
- **Detail Optimization**: Language order, Splash layout, UWP status text, modal mask animation

This update is a "comprehensive rendering mechanism refactor, brand-new console mode usability, precise animation normalization matching, batch security hardening" release. All user-facing command-line interfaces, environment variables, and cross-Runspace communication protocols remain fully compatible, ensuring that existing scripts and workflows can run without modification.

---

## 2. P1 Level: Security Update Batch Hardening

P1-level changes patch multiple critical security vulnerabilities.

### P1-1: H-7 Privilege Escalation Command Line Parameter Injection Fix

**Issue**: View-AdminElevation.ps1 and View-ProMode.ps1 directly concatenated language and path parameters to the command line during restart elevation, without validation, posing command line metacharacter injection risk.

**Fix**: Added two validation functions:
- **Test-AuroraLanguageSafe**: Strict whitelist, only allows "CHS" or "ENG"
- **Test-AuroraPathSafe**: Rejects paths containing `[<>&|\`"$]` metacharacters, normalizes path to verify absolute path

Validation chain: View-AdminElevation.ps1 is dot-sourced by AURORA-AnalyzerLauncherGUI.ps1, exposing validators to all subsequently loaded scripts. View-ProMode.ps1 uses validation indirectly via Restart-WithAdmin (defined in View-AdminElevation.ps1).

**Reason**: Privilege escalation command line parameters were not validated.

**Impact Scope**: View-AdminElevation.ps1, View-ProMode.ps1, AURORA-AnalyzerLauncherGUI.ps1.

---

### P1-2: H-6 Invoke-Expression Command Injection and Cache Poisoning Fix

**Issue**: AURORA-SmartEngine.ps1 used Invoke-Expression in three places to execute command strings from JSON configuration, allowing attackers to inject arbitrary commands via tampered JSON. SecurityModule.ps1's integrity check cache also had a TOCTOU window.

**Fix**:
- **Test-AuroraCommandSafe**: Max command length 8192 chars, regex blacklist covering command execution, network, persistence, reflection injection, encoding bypass, process injection, WMI bypass, registry tampering, environment variable tampering
- **Invoke-AuroraSafeCommand**: Replaces Invoke-Expression with `[ScriptBlock]::Create($CommandStr)` + `& $sb`, audit log to `%LOCALAPPDATA%\AURORA\Logs\command_audit.log`
- **Three replacement sites**: pre_check (line 521), command (line 742), rollback_command (line 976)
- **_integrityCacheDuration = TimeSpan.Zero**: Eliminates TOCTOU window

**Reason**: Invoke-Expression executing unvalidated command strings, integrity check cache with TOCTOU window.

**Impact Scope**: AURORA-SmartEngine.ps1, AURORA-SecurityModule.ps1.

---

### P1-3: Encoding Fix

**Issue**: View-AdminElevation.ps1, View-ProMode.ps1, AURORA-AnalyzerLauncherGUI.ps1 had parsing anomalies on Chinese Windows.

**Fix**: Added UTF-8 BOM to all three scripts.

**Reason**: Missing UTF-8 BOM caused Chinese Windows parsing errors.

**Impact Scope**: View-AdminElevation.ps1, View-ProMode.ps1, AURORA-AnalyzerLauncherGUI.ps1.

---

## 3. P2 Level: Rendering Mechanism Refactor and Refresh Rate Adaptation

P2-level changes comprehensively refactor the graphics rendering pipeline.

### P2-1: Startup Probing

**Change**: App.xaml.cs executes a three-phase probe at startup: render mode selection (RenderMode.Default), initial tier (RenderCapability.Tier >> 16), hardware capability probe (MaterialCapabilities.Probe probing GPU vendor/VRAM/D3D9Ex/ShaderEffect/remote session).

**Reason**: Need to select the most suitable rendering strategy based on hardware capabilities.

**Impact Scope**: App.xaml.cs startup flow, MaterialCapabilities.cs Probe.

---

### P2-2: Dynamic Tiering

**Change**: Classifies into four performance tiers based on probe results: Eco (Tier==0 or remote session, 100ms/10fps), Balanced (low-end GPU, 66ms/15fps), Performance (mainstream GPU, 50ms/20fps), Extreme (high-end GPU, 33ms/30fps).

**Reason**: Different hardware capabilities require different rendering frequencies to balance quality and performance.

**Impact Scope**: AuroraMaterialPipeline.cs GetBackgroundCaptureThrottleMs.

---

### P2-3: Render Layer Lazy Subscription

**Change**: CompositionTarget.Rendering auto-subscribes on first AuroraMaterialComposer registration, unsubscribes on last Composer unregistration. `_isRenderingSubscribed` flag ensures subscription state consistency.

**Reason**: Prevents meaningless per-frame computation when all glass material components are invisible.

**Impact Scope**: AuroraMaterialPipeline.cs Register/Unregister.

---

### P2-4: Backend Three-Level Fallback Chain

**Change**: Blur backend uses three-level fallback: Tier==0 forces RtbBlurBackend (software rendering makes ShaderEffect slower on CPU) → Tier>=1 prefers ShaderEffectBackend (HLSL PS 3.0 GPU 9-tap gaussian blur) → final fallback RtbBlurBackend. ReloadBlurBackend triggers on GPU driver crash/power switch/remote session change.

**Reason**: Ensures a usable blur backend in all environments.

**Impact Scope**: AuroraMaterialPipeline.cs SelectBlurBackend/ReloadBlurBackend.

---

### P2-5: Remote Session Dual-Path Detection

**Change**: MaterialCapabilities.DetectRemoteSession uses dual-path detection: fast path GetSystemMetrics(SM_REMOTESESSION), accurate path WTSQuerySessionInformation(WTSConnectState). Only WTSActive=0 is treated as local session. Conservative non-remote assumption on failure. Forces DWM/ShaderEffect backend disable on remote detection.

**Reason**: RDP cannot properly render Acrylic and GPU ShaderEffect.

**Impact Scope**: MaterialCapabilities.cs DetectRemoteSession/Probe.

---

### P2-6: Animation Frame Rate Normalization (45fps Benchmark)

**Change**: Changed timeScale denominator from 16.667 (60fps) to 22.222 (45fps) in AuroraButton, AuroraTaskHUD, AuroraProgressBar, matching DispatcherTimer's actual average frame rate at Render priority. Eco mode uses 1.0 timeScale + 33ms throttle, no normalization.

**Reason**: Original 60fps benchmark mismatched actual 45fps average frame rate, causing animations to appear ~33% faster.

**Impact Scope**: AuroraButton.cs:725, AuroraTaskHUD.cs:257, AuroraProgressBar.cs:202.

---

## 4. P3 Level: Console Mode GUI/CLI Dual-Mode Compatibility

P3-level changes build the AURORA-SmartEngine-CLI.ps1 adaptation layer.

### P3-1: Three-Layer Architecture

**Change**: Pre-create thread-safe syncHash (`[hashtable]::Synchronized(@{})`, LogOutput uses `[System.Collections.ArrayList]::Synchronized(...)`) + background Runspace executing SmartEngine.ps1 (preserving original logic unmodified) + main thread polling syncHash responding to GUI events.

**Reason**: Enable SmartEngine to complete the full flow in a pure console environment.

**Impact Scope**: AURORA-SmartEngine-CLI.ps1 (new file).

---

### P3-2: Five GUI Wait Points Handled

**Change**: CLI adaptation layer handles SmartEngine's five blocking wait points: pre-elevation wait (RequiresElevation/ElevationAuthorized), authorization EventWaitHandle wait (AuthorizationEventName/Authorized), CSV export log confirmation (RequiresUserInput/UserInput), catch-branch elevation remediation, main menu event loop (IsHostAlive/UserInput/Authorized/PendingCommand).

**Reason**: SmartEngine's GUI wait points cannot trigger in console environment.

**Impact Scope**: AURORA-SmartEngine-CLI.ps1 polling state machine.

---

### P3-3: Polling State Machine and Encoding Fix

**Change**: Main loop contains complete polling state machine (4.3 elevation request/4.4 authorization request/4.5 CSV confirmation/4.7 menu input). Added UTF-8 BOM to resolve Chinese encoding errors. Fixed execution results not printing (premature status detection + Read-Host thread blocking), manual 'm' refresh required after privilege cancellation (missed state changes), duplicate menu printing (redundant logs + unhandled 'm' command).

**Reason**: CLI adaptation layer requires complete polling state machine and correct encoding handling.

**Impact Scope**: AURORA-SmartEngine-CLI.ps1 main loop, encoding handling.

---

### P3-4: Integration Points

**Change**: AURORA-SmartEngine-CLI.ps1 integrates into AURORA-AnalyzerPRO.ps1's -ConsoleMode branch, accessible via both performance upgrade dialog and MainForm View 2 console buttons.

**Reason**: Provide console mode entry point.

**Impact Scope**: AURORA-AnalyzerPRO.ps1 -ConsoleMode branch.

---

## 5. P4 Level: SMART SLI Smart Mode Invocation Bridge

P4-level changes add SMART SLI, enabling console mode to invoke Smart Mode.

### P4-1: SMART SLI Bridge

**Change**: Console mode gains the ability to invoke Smart Mode. SMART SLI works in concert with AURORA-SmartEngine-CLI.ps1 adaptation layer: when console mode launches SmartEngine, the CLI adaptation layer handles the five GUI wait points, while SMART SLI bridges console input to the smart mode's decision, authorization, and elevation workflows.

**Reason**: Enable console mode users to enjoy Smart Mode's automated repair capabilities.

**Impact Scope**: Console mode entry, SmartEngine invocation chain.

---

## 6. P5 Level: PRO Mode Control Entrance Animation Time Jump Fix

P5-level changes fix the sudden acceleration of trailing controls in PRO mode entrance animation.

### P5-1: Dynamic Fallback Timer

**Issue**: In ProModeView.PlayControlEnterAnimation's 16 controls, trailing controls (ExitButton delay 1120ms, MinimizeButton delay 1200ms) had their main animation (450ms) not yet completed when the fixed 1500ms fallback timer fired and force-reset ScaleTransform to terminal state, causing a "sudden acceleration" visual jump.

**Fix**: Changed fallback timer to dynamic calculation formula `fallbackMs = (tiles.Count - 1) * staggerMs + durationMs + bounceDurationMs + 100`. For 16 controls: (16-1) × 80 + 450 + 525 + 100 = 2275ms, ensuring all control animations complete before fallback triggers.

**Reason**: Fixed 1500ms fallback timer cannot accommodate 16 controls' total animation duration (2175ms).

**Impact Scope**: ProModeView.xaml.cs PlayControlEnterAnimation fallback timer.

---

## 7. P6 Level: History View Hit Detection Mechanism Fix

P6-level changes fix two issues in history view hit detection.

### P6-1: Health Score Floating-Point Arithmetic Fix

**Issue**: ExportHistoryService.ComputeHealthScore used integer division `totalIssues * 100 / totalEvents`. When totalIssues was small and totalEvents was large, integer division truncation resulted in zero deduction, incorrectly returning a health score of 100.

**Fix**: Extracted as public static method using floating-point arithmetic `(double)totalIssues * 100.0 / (double)totalEvents` + `Math.Round`. Weights critical=3, error=2, warning=1. HistoryMatchService calls the same method to ensure formula consistency.

**Reason**: Integer division truncates decimals, resulting in zero deduction.

**Impact Scope**: ExportHistoryService.cs ComputeHealthScore, HistoryMatchService.cs call chain.

---

### P6-2: Scan Window Dynamic Expansion

**Issue**: HistoryMatchService used a fixed 24h scan window. When exported log's time range exceeded 24h, freshly exported logs failed to match due to being outside the window.

**Fix**: Added ComputeScanWindowHours method to dynamically calculate window: default 24h, takes max(24h, span from DateRange start date to now), capped at 720h (30 days). Supports both single date (yyyyMMdd) and date range (start-end) formats.

**Reason**: Fixed 24h window cannot cover export time range.

**Impact Scope**: HistoryMatchService.cs ComputeScanWindowHours and Detect call chain.

---

## 8. P7 Level: Solution Entry Point Addition

P7-level changes refactor ShowMatchResult to "always provide entry to detail view regardless of hit/miss."

### P7-1: Unified Entry Design

**Change**: ExportHistoryView.ShowMatchResult refactored to `canShowDetail = true` (except on detection failure), always calls ShowGlassConfirm, on "Yes" calls OpenSolutionDetail.

**Reason**: Previously only provided entry on hit with solutions; no entry on miss to view comparison details.

**Impact Scope**: ExportHistoryView.xaml.cs ShowMatchResult.

---

### P7-2: Three Prompt Scenarios

**Change**: Hit with solutions (lists solutions guiding repair), hit without solutions (guides viewing comparison details), miss/state diverged (guides viewing comparison to check if historical issue still exists) — three scenarios with different prompt text.

**Reason**: Different scenarios require different guidance.

**Impact Scope**: ExportHistoryView.xaml.cs ShowMatchResult prompt text.

---

## 9. P8 Level: Bottom Buttons Staggered Entrance Animation Optimization

P8-level changes optimize bottom buttons entrance animation in history view and solution view.

### P8-1: ExportHistoryView Bottom Buttons Staggered Entrance

**Change**: Changed BottomButtons from overall Opacity/RenderTransform to each button having independent Opacity=0 + TransformGroup, added to control staggered entrance sequence (9 controls: BackBtn/TitleLabel/RefreshBtn/ListSection/DetailSection/DetectBtn/ExportBtn/OpenDirBtn/DeleteBtn). Parameters staggerMs=120, durationMs=675, bounceDurationMs=525, fallback timer 2260ms.

**Reason**: Previously all buttons appeared simultaneously, lacking rhythm.

**Impact Scope**: ExportHistoryView.xaml BottomButtons section, ExportHistoryView.xaml.cs PlayControlEnterAnimation.

---

### P8-2: SolutionDetailView Bottom Buttons Staggered Entrance

**Change**: SolutionDetailView bottom buttons synchronously adopt staggered entrance animation, each button with independent Opacity=0 + TransformGroup, with dynamic fallback timer ensuring complete animation playback.

**Reason**: Visual consistency with ExportHistoryView.

**Impact Scope**: SolutionDetailView.xaml, SolutionDetailView.xaml.cs.

---

## 10. P9 Level: Undo Manager Optimization and Fix

P9-level changes migrate UndoViewer from SolutionDetailView to SmartModeView, and unify RepairSession cross-mode recording.

### P9-1: UndoViewer Migration

**Change**: Migrated UndoViewer from SolutionDetailView to SmartModeView. SmartModeView.xaml adds UndoViewerButton (100×32), SmartModeViewModel.cs adds ShowUndoViewerCommand/ShowUndoViewerRequested/OnShowUndoViewer, SmartModeView.xaml.cs OnShowUndoViewerRequested constructs UndoViewerView. SolutionDetailView.xaml removes all UndoViewer-related code.

**Reason**: Most repair commands execute in SmartMode; UndoViewer was disconnected from primary execution scenario.

**Impact Scope**: SmartModeView.xaml/SmartModeViewModel.cs/SmartModeView.xaml.cs, SolutionDetailView.xaml, UndoViewerView.xaml/.cs.

---

### P9-2: RepairSession Cross-Mode Recording

**Change**: Both SmartMode and PRO mode call RecordRepairSession to record to RepairService. SmartModeViewModel.ShowResultModal and ProModeViewModel.ShowResultModal parse CommandResult Hashtable (ActionName/Result/Output/ExecutionTime/Command), call RecordRepairSession (RepairType.Custom, success detection via result.IndexOf("Success")). SmartEngine.ps1's CommandResult Hashtable must include `Command = $Command.command` field.

**Reason**: Ensure Undo Manager can display commands executed in all modes.

**Impact Scope**: SmartModeViewModel.cs ShowResultModal/RecordRepairSession, ProModeViewModel.cs ShowResultModal/RecordRepairSession, AURORA-SmartEngine.ps1 CommandResult.

---

### P9-3: UndoViewer Visual Alignment

**Change**: UndoViewerView aligns with FixExecutionOverlay visual style: semi-transparent dark mask (#E60A1428) + AuroraFrostedGlassBorder container, no independent starfield background, entrance/exit animations consistent with FixExecutionOverlay.

**Reason**: Visual unity with execution window.

**Impact Scope**: UndoViewerView.xaml, UndoViewerView.xaml.cs.

---

## 11. P10 Level: Main Window Language Order and Detail Optimization

P10-level changes are multiple visual and interaction detail optimizations.

### P10-1: Main Window Language List Order

**Change**: MainFormView.xaml adjusts language list order, placing "简体中文" (CHS) first and "English" (ENG) second.

**Reason**: Align with user habits.

**Impact Scope**: MainFormView.xaml:91-106.

---

### P10-2: Splash Text Layout Optimization

**Change**: Optimized SplashScreenView's text layout, making title, subtitle, and status text more visually balanced.

**Reason**: Splash text layout was crowded or offset.

**Impact Scope**: SplashScreenView.xaml.

---

### P10-3: UWP Status Text Optimization

**Change**: Optimized UWP-style status text synchronization and display, ensuring status updates correctly with SmartEngine progress.

**Reason**: Status text was out of sync with engine progress.

**Impact Scope**: Status text related views and ViewModels.

---

### P10-4: Modal Dialog Mask Animation and Visual Effects

**Change**: Optimized mask animations and visual effects for all modal dialogs (ModalOverlay/UserInputOverlay/MessageOverlay/FixExecutionOverlay/UndoViewerOverlay, etc.): unified mask opacity and color tone, optimized wind-up — scale-up — fade rhythm, unified glass container corner radius and highlight strokes, coordinated mask and content animation timing eliminating content jumps.

**Reason**: Modal dialog mask animation and visual effects were inconsistent.

**Impact Scope**: All modal dialog views.

---

## 12. Compatibility Preservation

While V1.5.28.5 refactors the rendering mechanism and upgrades console mode, it maintains full compatibility in the following areas:

| Compatibility Item | Description |
|--------------------|-------------|
| PowerShell 5.1 Compatibility | C# code continues to compile with C# 5.0 language version |
| Command Line Parameters | All command-line parameters remain fully compatible, no additions or removals |
| syncHash Synchronization | Cross-Runspace syncHash communication interface remains fully compatible |
| Environment Variable Interfaces | All environment variable interfaces remain fully compatible |
| Script Interfaces | PowerShell script engine interface unchanged (internal security hardening does not change external interfaces) |
| Material Pipeline | V5 material pipeline interface unchanged, AuroraFrostedGlassBorder/AuroraFrostedGlassCard behavior unchanged |
| Animation Interfaces | Control-level animation method signatures unchanged, AnimationHelper public methods unchanged |
| Glass Material Capture | Precision config unchanged (30fps/1/2 resolution/BlurRadius=2.5), frequency only adjusts on tier downgrade |
| Render Backend | Defaults to GPU hardware acceleration, only falls back on software rendering or remote session |

---

## 13. Change Summary Table

| ID | Level | Change Description | Reason | Impact Scope |
|----|-------|---------------------|--------|--------------|
| P1-1 | P1 | H-7 privilege escalation parameter injection fix | Unvalidated escalation parameters | View-AdminElevation/View-ProMode |
| P1-2 | P1 | H-6 Invoke-Expression injection and cache poisoning fix | Command injection and TOCTOU | AURORA-SmartEngine/AURORA-SecurityModule |
| P1-3 | P1 | Encoding fix (UTF-8 BOM) | Chinese Windows parsing errors | View-AdminElevation/View-ProMode/LauncherGUI |
| P2-1 | P2 | Startup probing | Select rendering strategy by hardware | App.xaml.cs/MaterialCapabilities |
| P2-2 | P2 | Dynamic tiering | Balance quality and performance | AuroraMaterialPipeline |
| P2-3 | P2 | Render layer lazy subscription | Prevent idle per-frame computation | AuroraMaterialPipeline Register/Unregister |
| P2-4 | P2 | Backend three-level fallback chain | Ensure availability in all environments | AuroraMaterialPipeline SelectBlurBackend |
| P2-5 | P2 | Remote session dual-path detection | RDP cannot render Acrylic | MaterialCapabilities DetectRemoteSession |
| P2-6 | P2 | Animation normalization 45fps | 60fps benchmark mismatched actual | AuroraButton/AuroraTaskHUD/AuroraProgressBar |
| P3-1 | P3 | CLI three-layer architecture | Complete flow in console environment | AURORA-SmartEngine-CLI.ps1 |
| P3-2 | P3 | Five GUI wait points handled | Console cannot trigger GUI waits | AURORA-SmartEngine-CLI.ps1 polling |
| P3-3 | P3 | Polling state machine and encoding fix | Complete state machine and correct encoding | AURORA-SmartEngine-CLI.ps1 main loop |
| P3-4 | P3 | CLI integration points | Provide console mode entry | AURORA-AnalyzerPRO.ps1 -ConsoleMode |
| P4-1 | P4 | SMART SLI bridge | Console invokes Smart Mode | Console mode entry |
| P5-1 | P5 | PRO dynamic fallback timer | Fixed 1500ms triggered too early | ProModeView PlayControlEnterAnimation |
| P6-1 | P6 | Health score floating-point arithmetic | Integer division truncation | ExportHistoryService/HistoryMatchService |
| P6-2 | P6 | Scan window dynamic expansion | Fixed 24h cannot cover | HistoryMatchService ComputeScanWindowHours |
| P7-1 | P7 | Unified entry design | No entry on miss | ExportHistoryView ShowMatchResult |
| P7-2 | P7 | Three prompt scenarios | Different guidance per scenario | ExportHistoryView ShowMatchResult text |
| P8-1 | P8 | ExportHistoryView bottom buttons stagger | Simultaneous appearance lacked rhythm | ExportHistoryView BottomButtons |
| P8-2 | P8 | SolutionDetailView bottom buttons stagger | Visual consistency | SolutionDetailView |
| P9-1 | P9 | UndoViewer migration | Disconnected from execution scenario | SmartModeView/SolutionDetailView |
| P9-2 | P9 | RepairSession cross-mode recording | Undo Manager incomplete | SmartModeViewModel/ProModeViewModel |
| P9-3 | P9 | UndoViewer visual alignment | Unity with execution window | UndoViewerView |
| P10-1 | P10 | Language list order | Align with user habits | MainFormView.xaml |
| P10-2 | P10 | Splash text layout | Layout crowded/offset | SplashScreenView |
| P10-3 | P10 | UWP status text | Status out of sync | Status text views |
| P10-4 | P10 | Modal mask animation and visuals | Inconsistent effects | All modal dialogs |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *This tool is intended for personal educational use only. Please comply with local laws and regulations.*
