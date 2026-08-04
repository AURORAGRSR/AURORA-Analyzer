# AURORA Analyzer V1.6.30.1 Update Notes

> **Windows Event Log Export and Intelligent Diagnostic Tool**
>
> Version: V1.6.30.1Release · Build Date: 2026.08.04 · Author: AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **Warning**: This tool is intended for personal educational use only. Please comply with local laws and regulations.

---

## Table of Contents

1. [Version Overview](#1-version-overview)
2. [Solution Detail View Execution Window Comprehensive Refactor](#2-solution-detail-view-execution-window-comprehensive-refactor)
3. [P0 Level Defect Fixes (6 items)](#3-p0-level-defect-fixes-6-items)
4. [P1 Level Defect Fixes (12 items)](#4-p1-level-defect-fixes-12-items)
5. [Composite Cross-Audit Newly Discovered Low-Risk Defects (3 items)](#5-composite-cross-audit-newly-discovered-low-risk-defects-3-items)
6. [History Analysis and Report Export Experience Upgrade](#6-history-analysis-and-report-export-experience-upgrade)
7. [Compatibility Maintained](#7-compatibility-maintained)
8. [Change List Overview](#8-change-list-overview)

---

## 1. Version Overview

V1.6.30.1 is an AURORA-Analyzer release focused on "execution flow robustness and rollback-loop completeness", building upon the solution-detail-view execution window optimization. This update covers three core areas: comprehensive refactor of the solution-detail-view execution window, a full audit fix pass (6 P0 + 12 P1 + 3 newly-discovered low-risk audit defects), and unified encapsulation of GlassDialogAnimation.

For the execution window refactor, V1.6.30.1 upgrades the solution-detail-view execution UI to a step-timeline + log dual-pane layout, and introduces a Process.Kill-based whole-process-tree cancellation mechanism, a FailureAction.Abort/Continue/AskUser three-state failure-handling model, progress interpolation and remaining-time estimation driven by the average duration of already-executed commands, and an EvaluatePreCheck pre-validation that filters out solutions with no executable commands.

For rollback-loop completeness, V1.6.30.1 fixes critical defects including non-retryable undo failures, orphaned disk-snapshot accumulation from expired sessions, missing terminal-state protection, and Continue mode skipping RollbackCommand and leaving dirty state — ensuring the undo path is a fully closed loop from trigger to cleanup.

For animation unification, V1.6.30.1 migrates 10 inline glass-dialog animations into the GlassDialogAnimation utility class, eliminating 11+ duplicate implementations, and adds an `onSafetyTimerCreated` callback overload for the ProModeView ModalOverlay reuse scenario.

V1.6.30.1 achieves comprehensive upgrades through the following core strategies:

- **Solution-detail-view execution window comprehensive refactor**: dual-pane layout, process-tree cancellation, three-state failure handling, progress estimation, pre-validation filtering
- **P0 defect fixes (6 items)**: Unloaded deadlock, non-retryable undo, CTS leak, _exitHandle not Disposed, exit without fallback, _pendingEnterTimers not cleared
- **P1 defect fixes (12 items)**: terminal-state protection, disk-snapshot cleanup, orphaned-snapshot loading, success-semantics contradiction, Continue-mode rollback, snapshot trigger conditions, registry-path extraction, cancellation-token propagation, event unsubscription, GlassDialogAnimation unified encapsulation
- **Composite cross-audit fixes (3 items)**: empty-solution semantics, terminal-state BackupSnapshotId override, UI not refreshing after Undo

This update is a "eradicate deadlocks and leaks in execution-flow robustness, cover orphaned snapshots in rollback-loop completeness" release. All user-facing command-line interfaces, environment variables, and cross-Runspace communication protocols remain fully compatible, ensuring existing scripts and workflows run without modification.

---

## 2. Solution Detail View Execution Window Comprehensive Refactor

V1.6.30.1 comprehensively refactors the execution window of the solution detail view (SolutionDetailView), upgrading from a single-pane log to a step-timeline + log dual-pane layout, and introducing four core mechanisms: process-tree cancellation, three-state failure handling, progress estimation, and pre-validation filtering.

### 2-1: Step Timeline + Log Dual-Pane Layout

**Change**: The execution window is upgraded to a dual-pane layout with a step timeline on the left and a real-time log on the right. The left timeline shows each step's status in execution order (pending / executing / success / failed / skipped), while the right pane scrolls command output in real time.

**Reason**: The original single-pane log could not present execution progress and detailed output simultaneously, forcing the user to shift focus between progress and logs.

**Impact Scope**: `SolutionDetailView.xaml.cs` execution window layout.

---

### 2-2: Cancel Terminates Child Processes (Process.Kill Whole Process Tree)

**Change**: On cancellation, the whole process tree is terminated via Process.Kill, ensuring child processes do not keep running after the parent is cancelled.

**Reason**: The original cancel logic only terminated the top-level process; child processes kept running and consuming resources, causing continuous log output after cancellation and process-handle leaks.

**Impact Scope**: `SolutionDetailView.xaml.cs` cancellation logic.

---

### 2-3: Failure Continue/Abort Choice (FailureAction Three States)

**Change**: Introduces a FailureAction.Abort/Continue/AskUser three-state failure-handling model. When a command fails, AskUser pops up a dialog asking the user to choose Abort (abort all subsequent commands) or Continue (skip the current command and keep executing).

**Reason**: The original failure handling only supported aborting, unable to continue subsequent steps when a non-critical command failed.

**Impact Scope**: `SolutionDetailView.xaml.cs` OnFixCommandFailure, `FixExecutionService.cs` ExecuteCommands.

---

### 2-4: Progress Interpolation + Time Estimation

**Change**: Based on the average duration of already-executed commands, remaining time is estimated and the progress bar advances smoothly via interpolation during command execution, avoiding the bar getting stuck on one step.

**Reason**: The original progress only jumped after a command completed; during long-running commands the bar stalled, degrading the user experience.

**Impact Scope**: `SolutionDetailView.xaml.cs` progress update logic.

---

### 2-5: Pre-Validation of No Executable Commands (EvaluatePreCheck Early Filtering)

**Change**: Before execution, EvaluatePreCheck is called for pre-validation to filter out solutions with no executable commands up front, avoiding the discovery of an empty solution only after entering the execution flow.

**Reason**: The original solution detected no-executable-command cases only after the execution flow started, wasting resources and producing an abrupt user experience.

**Impact Scope**: `FixExecutionService.cs` EvaluatePreCheck, `SolutionDetailView.xaml.cs` execution entry.

---

## 3. P0 Level Defect Fixes (6 items)

The P0 level change fixes high-risk defects such as deadlocks, leaks, and missing fallbacks in the execution flow and view lifecycle.

### P0-1: OnFixCommandFailure Unloaded Deadlock

**Problem**: In `SolutionDetailView.xaml.cs` OnFixCommandFailure, the `_fixCts.Token.Register` callback fires after the View is Unloaded, and the token has been Disposed, causing a deadlock.

**Fix**: Register `_fixCts.Token.Register(() => tcs.TrySetResult(FailureAction.Abort))`, catch `System.ObjectDisposedException` and Abort directly; change all `tcs.SetResult` to `TrySetResult` to guarantee idempotency.

**Reason**: The Token Register callback firing after Unloaded threw an uncaught ObjectDisposedException.

**Impact Scope**: `SolutionDetailView.xaml.cs` OnFixCommandFailure.

---

### P0-2: Non-Retryable Undo Failure

**Problem**: `RepairService.cs` UndoRepairSession sets `CanUndo=false` and `Status=Failed` on undo failure, leaving the user unable to retry the undo.

**Fix**: On undo failure, keep `CanUndo=true` and the original Status (only set `FailureReason="UndoFailed"`); CompleteRepairSession expired cleanup is linked to disk-snapshot cleanup (executed outside the lock); App.OnStartup calls `CleanupExpiredSnapshots(7)` to clean orphaned snapshots.

**Reason**: CanUndo was incorrectly cleared after an undo failure, and expired sessions did not clean disk snapshots, causing orphan accumulation.

**Impact Scope**: `RepairService.cs` UndoRepairSession / CompleteRepairSession, `App.OnStartup`.

---

### P0-3: Retry Does Not Clean Old CTS Leak

**Problem**: `SolutionDetailView.xaml.cs` ShowFixExecutionOverlay creates a new CTS on retry but does not Cancel+Dispose the old instance.

**Fix**: Cancel+Dispose the old instance before creating a new CTS.

**Reason**: The old CTS not being cleaned on retry caused a CancellationTokenSource leak.

**Impact Scope**: `SolutionDetailView.xaml.cs` ShowFixExecutionOverlay.

---

### P0-4: 6 Views' _exitHandle Not Disposed in OnUnloaded

**Problem**: The `_exitHandle` (StaggerExitHelper dual-timer handle) of ProModeView/SmartModeView/SplashScreenView/ExportHistoryView/SolutionDetailView/SessionRestoreDialogView is not Disposed in OnUnloaded.

**Fix**: All 6 views' OnUnloaded now add `_exitHandle.Dispose()`.

**Reason**: The DispatcherTimer inside ExitTimerHandle was not Disposed, causing a timer leak.

**Impact Scope**: OnUnloaded of `ProModeView.xaml.cs`, `SmartModeView.xaml.cs`, `SplashScreenView.xaml.cs`, `ExportHistoryView.xaml.cs`, `SolutionDetailView.xaml.cs`, `SessionRestoreDialogView.xaml.cs`.

---

### P0-5: MainFormView.PlayStaggerExit Has No Fallback

**Problem**: `MainFormView.PlayStaggerExit` relies on the PlayTitleExit callback to drive the subsequent flow; if the callback does not fire, the entire exit flow gets stuck.

**Fix**: Add an `_exitHandle` field, change the PlayTitleExit callback to an empty lambda, and have onCompleted + state restoration scheduled by StaggerExitHelper.ScheduleExit; Dispose `_exitHandle` in OnUnloaded.

**Reason**: A broken callback chain left the exit flow without a fallback.

**Impact Scope**: `MainFormView.xaml.cs` PlayStaggerExit.

---

### P0-6: SolutionDetailView._pendingEnterTimers Not Cleared in OnUnloaded

**Problem**: The DispatcherTimers in the `SolutionDetailView._pendingEnterTimers` list are not stopped in OnUnloaded.

**Fix**: OnUnloaded now adds a `CancelPendingEnterTimers()` call.

**Reason**: Entrance timers still firing after the view was unloaded caused abnormal state.

**Impact Scope**: `SolutionDetailView.xaml.cs` OnUnloaded.

---

## 4. P1 Level Defect Fixes (12 items)

The P1 level change fixes medium-risk defects in the rollback loop, execution semantics, and event subscription.

### P1-1: CompleteRepairSession Terminal-State Protection

**Problem**: `CompleteRepairSession` does not check whether the current state is already terminal, and directly overwrites Status/CanUndo.

**Fix**: If already in a terminal state (Undone/Success/Failed/Cancelled/PartialSuccess), only FinishedAt is updated; Status/CanUndo/BackupSnapshotId are not overwritten.

**Reason**: A terminal-state session being overwritten by non-terminal fields caused state regression.

**Impact Scope**: `RepairService.cs` CompleteRepairSession.

---

### P1-2: Memory Eviction Does Not Clean Disk Snapshots

**Problem**: `CompleteRepairSession` does not clean the corresponding disk snapshots when evicting expired in-memory sessions.

**Fix**: During expired cleanup, snapshot IDs are collected and `UndoManagerService.RemoveBackupSnapshot` is called outside the lock.

**Reason**: After in-memory sessions were evicted, disk snapshots were left behind as orphans.

**Impact Scope**: `RepairService.cs` CompleteRepairSession.

---

### P1-3: UndoViewerViewModel.Refresh() Does Not Load Disk Snapshots

**Problem**: After a process restart, orphaned snapshots on disk are not visible in the UndoViewer UI.

**Fix**: `Refresh()` calls `UndoManagerService.LoadAllSnapshots()` to load orphaned disk snapshots and creates a placeholder RepairSessionInfo for display (`RepairType.Custom` + `Target="OrphanedSnapshot"`).

**Reason**: UndoViewer only loaded in-memory sessions; orphaned disk snapshots were invisible to the user, preventing manual cleanup.

**Impact Scope**: `UndoViewerViewModel.cs` Refresh().

---

### P1-5: overallSuccess Contradicts PartialSuccess

**Problem**: When all commands are skipped, `overallSuccess=true` but the status is `PartialSuccess` — a semantic contradiction.

**Fix**: `overallSuccess = executedCount > 0 && successCount == executedCount && skippedCount == 0`.

**Reason**: The original overallSuccess calculation did not exclude the all-skipped scenario, leaving overallSuccess true under a PartialSuccess status.

**Impact Scope**: `FixExecutionService.cs` ExecuteCommands.

---

### P1-6: Continue Mode Does Not Execute RollbackCommand

**Problem**: Continue mode skips the failed command but does not execute its RollbackCommand, leaving dirty state that triggers cascading failures.

**Fix**: In Continue mode, execute the failed command's RollbackCommand (if any) before skipping it.

**Reason**: Skipping a failed command without rolling back its already-executed side effects caused subsequent commands to run on dirty state, triggering cascading failures.

**Impact Scope**: `FixExecutionService.cs` ExecuteCommands.

---

### P1-7: Snapshot Trigger Conditions Do Not Match Comments

**Problem**: `needSnapshot` only checks RollbackCommand, not whether the command text involves the registry, files, or services.

**Fix**: `needSnapshot` now checks RollbackCommand or whether the command text involves HKLM/HKCU/HKCR/HKU/HKCC/Set-Service/Start-Service/Stop-Service/sc.exe.

**Reason**: The snapshot trigger conditions were incomplete; some commands that modified system state did not trigger a snapshot, leaving no rollback baseline on undo.

**Impact Scope**: `FixExecutionService.cs` ExecuteCommands.

---

### P1-8: Crude Registry Path Extraction

**Problem**: Only HKLM/HKCU were supported, separators did not cover multi-statement commands, and a single pass missed paths.

**Fix**: Support all five major registry drives (HKLM/HKCU/HKCR/HKU/HKCC), add `;` and `\n` as separators to cover multi-statement commands, and loop to extract all matching paths.

**Reason**: Incomplete registry path extraction caused missing snapshot metadata, preventing precise location of registry changes on undo.

**Impact Scope**: `FixExecutionService.cs` ExtractRegistryPaths.

---

### P1-9: EvaluatePreCheck Passes CancellationToken.None

**Problem**: User cancellation is ineffective during pre_check.

**Fix**: Pass the actual `cancellationToken` instead of `CancellationToken.None`.

**Reason**: Ignoring the cancellation token during pre-validation prevented the user from interrupting a long-running pre_check.

**Impact Scope**: `FixExecutionService.cs` EvaluatePreCheck.

---

### P1-10: ProModeView Events Not Unsubscribed

**Problem**: 9 ViewModel events in ProModeView are not unsubscribed in OnUnloaded.

**Fix**: OnUnloaded unsubscribes ConsoleLines.CollectionChanged + SuspendPolling (under NavigationCache reuse mode, other command events are retained; OnLoaded re-subscribes ConsoleLines).

**Reason**: Event subscription residue under NavigationCache reuse caused a ViewModel/View lifecycle mismatch, triggering duplicate callbacks and memory leaks.

**Impact Scope**: `ProModeView.xaml.cs` OnUnloaded/OnLoaded.

---

### P1-11: SmartModeView Events Not Unsubscribed + No SuspendPolling

**Problem**: 6 ViewModel events in SmartModeView are not unsubscribed + SuspendPolling is not called.

**Fix**: OnUnloaded unsubscribes ConsoleLines.CollectionChanged + SuspendPolling; OnLoaded re-subscribes.

**Reason**: Event subscription residue + polling not suspended caused the ViewModel to keep polling an unloaded View, triggering cross-thread exceptions and resource waste.

**Impact Scope**: `SmartModeView.xaml.cs` OnUnloaded/OnLoaded.

---

### P1-12/B4: GlassDialogAnimation Zero Callers

**Problem**: The GlassDialogAnimation utility class had zero callers, with 11+ inline duplicate implementations of the same animation recipe.

**Fix**: All 10 glass-dialog animations are migrated to GlassDialogAnimation (8 overlay+contentBorder sites use PlayGlassEnter/PlayGlassExit, 2 Window-level sites use PlayWindowExit). PlayGlassExit gains an `onSafetyTimerCreated` callback overload to support the ProModeView ModalOverlay reuse scenario.

**Reason**: After encapsulation the utility had zero callers; 11+ inline implementations violated DRY, incurring high maintenance cost and inconsistent behavior.

**Impact Scope**: `GlassDialogAnimation.cs`, SolutionDetailView×2/SmartModeView/ProModeView/UndoViewerView/ExportHistoryView/ElevationDialogView/SessionRestoreDialogView/ReportCompareView/TrendView/PasswordDialogView/PerformanceDiagnosticsView/PerformanceUpgradeDialogView.

---

## 5. Composite Cross-Audit Newly Discovered Low-Risk Defects (3 items)

Building on the P0/P1 fixes, composite cross-audit cross-validated across modules and newly discovered 3 low-risk defects, fixing them in the same pass.

### Audit A-1: Empty-Solution Status / Success Semantics Contradiction

**Problem**: For an empty solution (all filtered by pre_check), `isPartial` did not include `executedCount==0`, so the status was `Success` but `overallSuccess=false`.

**Fix**: `isPartial` now adds an `executedCount==0` check; an empty solution should be PartialSuccess.

**Reason**: An empty solution was misclassified as Success, contradicting overallSuccess=false — inconsistent semantics.

**Impact Scope**: `FixExecutionService.cs` ExecuteCommands.

---

### Audit B-1: Terminal-State Protection Branch Still Updates BackupSnapshotId

**Problem**: The `CompleteRepairSession` terminal-state protection branch still updates BackupSnapshotId; after UndoRepairSession cleans disk snapshots, a delayed CompleteRepairSession re-sets the deleted snapshot ID.

**Fix**: The terminal-state protection branch removes BackupSnapshotId/RestorePointId assignment, updating only FinishedAt.

**Reason**: The terminal-state branch still writing the snapshot ID caused a deleted snapshot to be re-referenced, producing a dangling pointer in the undo path.

**Impact Scope**: `RepairService.cs` CompleteRepairSession.

---

### Audit E-2: UI Does Not Refresh After Undo Success

**Problem**: `RepairSessionInfo` is a POCO that does not implement INotifyPropertyChanged; after Undo succeeds, the underlying object's Status/CanUndo have changed but the UI binding is unaware.

**Fix**: After `Undo()` succeeds, manually raise PropertyChanged for SelectedSession/CanUndoSelected/IsSessionSelected.

**Reason**: POCO property changes do not notify the UI, leaving the interface state inconsistent with the data after a successful undo.

**Impact Scope**: `UndoViewerViewModel.cs` Undo().

---

## 6. History Analysis and Report Export Experience Upgrade

V1.6.30.1 upgrades the history view analysis entry and the report export dialog, covering six improvements: a unified Analyze button with dynamic icon feedback, a multi-select sync refresh fix, a cross-archive trend data source fix, a report format mutual exclusion fix, a report export bilingual adaptation, and format option card hover feedback.

### H-1: Unified Analysis Button with Dynamic Icon Feedback

**Change**: Merged the "Trend" and "Timeline" bottom buttons in the history view into a single "Analyze" button. Button text and icon dynamically switch based on selected archive count: 0 selected → "Analyze" (magnifier icon, disabled); 1 selected → "Timeline" (clock icon, single-archive internal event distribution); ≥2 selected → "Trend" (rising line chart icon, cross-archive health evolution). Extended `AuroraButton` with `IconGeometry`/`IconSize`/`IconTextGap` dependency properties for icon+text combined rendering, with a zero-allocation hot path (`Geometry.Freeze` + cached `Brush`/`Pen`) and backward-compatible defaults (`IconGeometry` defaults to `null`).

**Reason**: Two separate buttons cluttered the bottom bar and required users to know in advance which analysis suited their selection; a single context-aware button reduces cognitive load and adapts automatically.

**Impact Scope**: `AuroraButton.cs`, `ExportHistoryViewModel.cs`, `ExportHistoryView.xaml`.

---

### H-2: Multi-Select Sync Refresh Fix

**Change**: Added a `NotifySelectionBatchCompleted()` public method to the ViewModel, called by the View after `ResumeSelectedEntriesNotifications()`, to refresh button text/icons/batch-delete text.

**Reason**: `SuspendSelectedEntriesNotifications` suspended `CollectionChanged` during batch sync of `SelectedEntries`, causing `OnSelectedEntriesChanged` to never fire and leaving button text/icons stale.

**Impact Scope**: `ExportHistoryViewModel.cs`, `ExportHistoryView.xaml.cs`.

---

### H-3: Cross-Archive Trend Data Source Fix

**Change**: Changed the `BuildTrendData` data source from `_entries` (all archives) to `_selectedEntries` (selected archives).

**Reason**: `BuildTrendData` iterated all archives instead of the selected subset, causing the trend chart to show full history rather than the selected data.

**Impact Scope**: `ExportHistoryViewModel.cs`.

---

### H-4: Report Format Mutual Exclusion Fix

**Change**: Added `GroupName="ReportFormatGroup"` to all three `RadioButton`s in `ReportFormatDialogView` for cross-container mutual exclusion; supplemented the `SelectedFormat` setter to raise `PropertyChanged` for the corresponding `Is*Selected` properties.

**Reason**: The three `RadioButton`s belonged to different `Grid` parent containers, and WPF's default mutual-exclusion scope is the same parent, causing exclusion failure (all lit up simultaneously).

**Impact Scope**: `ReportFormatDialogView.xaml`, `ReportFormatDialogViewModel.cs`.

---

### H-5: Report Export Bilingual Adaptation

**Change**: `ReportFormatDialogViewModel` constructor now accepts an `isChinese` parameter; added `IsChinese`/`LanguageName` properties; all `LanguageService.IsChinese`/`CurrentLanguageName` references in the View replaced with ViewModel properties; `ExportHistoryView` passes `_viewModel.IsChinese` when constructing the dialog. Establishes a unified language chain: `ExportHistoryViewModel._language` → `ReportFormatDialogViewModel._isChinese` → `ReportGeneratorService` → `HtmlReportExporter`/`XlsxReportExporter`.

**Reason**: `ReportFormatDialogViewModel` depended on the global `LanguageService.IsChinese` while `ExportHistoryViewModel` uses its own `_language` field, causing language desynchronization (main interface English but dialog Chinese).

**Impact Scope**: `ReportFormatDialogViewModel.cs`, `ReportFormatDialogView.xaml.cs`, `ExportHistoryView.xaml.cs`.

---

### H-6: Format Option Card Mouse Hover Feedback

**Change**: Changed card `Background`/`BorderBrush` to named `SolidColorBrush` instances; used `ColorAnimation` (200ms) for hover fade-in/fade-out + selection-state smooth transition. Four-state color design: unselected base (Bg #221E2D40, Border #551E2D40), unselected hover (Bg #331E2D40, Border #881E2D40), selected base (Bg #334DA0E8, Border #FF4DA0E8), selected hover (Bg #4450A8E8, Border #FF4DA0E8).

**Reason**: The three format option cards had no hover feedback, and `HighlightSelectedOption` created a new `SolidColorBrush` each time, causing abrupt visual transitions and per-allocation GC pressure.

**Impact Scope**: `ReportFormatDialogView.xaml`, `ReportFormatDialogView.xaml.cs`.

---

## 7. Compatibility Maintained

While hardening the execution flow and completing the rollback loop, V1.6.30.1 maintains full compatibility in the following areas:

| Compatibility Item | Notes |
|--------------------|-------|
| C# 5 syntax | C# code still compiles with C# 5.0 language version, no higher-version syntax dependency |
| .NET Framework 4.x | Target framework unchanged; build toolchain MSBuild v4.8.9221.0 unchanged |
| PowerShell 5.1 compatibility | PowerShell script engine interface and command compatibility unchanged |
| Command-line parameters | All command-line parameters fully compatible, no additions or removals |
| syncHash synchronization | Cross-Runspace syncHash interface fully compatible |
| Environment variable interface | All environment variable interfaces fully compatible |
| IAuroraStaggerView interface | Interface signatures unchanged; only internal timer management and exit-scheduling implementation optimized |
| V5 material pipeline | V5 material pipeline interface unchanged; AuroraFrostedGlassBorder/AuroraFrostedGlassCard behavior unchanged |
| Glass material capture precision | Precision config unchanged (30fps / 1/2 resolution / BlurRadius=2.5) |
| GlassDialogAnimation encapsulation | Animation recipe identical to original inline implementation; only consolidated into the utility class |
| Rollback loop | Undo interface and RepairSessionInfo structure unchanged; only terminal-state protection and orphan cleanup added |

---

## 8. Change List Overview

| ID | Level | Change Description | Reason | Impact Scope |
|------|------|----------|----------|----------|
| 2-1 | Refactor | Step timeline + log dual-pane layout | Single pane could not show progress and output together | SolutionDetailView execution window layout |
| 2-2 | Refactor | Cancel terminates child processes (Process.Kill process tree) | Child process residue caused handle leaks | SolutionDetailView cancellation logic |
| 2-3 | Refactor | FailureAction.Abort/Continue/AskUser three-state failure handling | Original only supported abort, could not continue | SolutionDetailView OnFixCommandFailure / FixExecutionService ExecuteCommands |
| 2-4 | Refactor | Progress interpolation + time estimation (based on avg duration) | Progress stalled during long commands | SolutionDetailView progress update |
| 2-5 | Refactor | EvaluatePreCheck pre-validation filters empty solutions | Discovering empty solution after execution was abrupt | FixExecutionService EvaluatePreCheck / SolutionDetailView execution entry |
| P0-1 | P0 | OnFixCommandFailure Token.Register uses TrySetResult + catch ObjectDisposedException | Unloaded + Disposed token caused deadlock | SolutionDetailView OnFixCommandFailure |
| P0-2 | P0 | Undo failure keeps CanUndo + expired cleanup links disk snapshot + startup cleans orphans | Non-retryable undo and orphan accumulation | RepairService UndoRepairSession/CompleteRepairSession / App.OnStartup |
| P0-3 | P0 | Cancel+Dispose old CTS before retry | Old CTS not cleaned caused leak | SolutionDetailView ShowFixExecutionOverlay |
| P0-4 | P0 | 6 views' OnUnloaded add _exitHandle.Dispose() | DispatcherTimer not Disposed, timer leak | ProModeView/SmartModeView/SplashScreenView/ExportHistoryView/SolutionDetailView/SessionRestoreDialogView OnUnloaded |
| P0-5 | P0 | MainFormView.PlayStaggerExit adds _exitHandle + StaggerExitHelper.ScheduleExit scheduling | Broken callback chain, no exit fallback | MainFormView PlayStaggerExit |
| P0-6 | P0 | OnUnloaded adds CancelPendingEnterTimers() | Entrance timers firing after unload | SolutionDetailView OnUnloaded |
| P1-1 | P1 | CompleteRepairSession terminal-state protection only updates FinishedAt | Terminal state overwritten by non-terminal fields | RepairService CompleteRepairSession |
| P1-2 | P1 | Expired cleanup calls RemoveBackupSnapshot outside lock | Disk snapshots left after memory eviction | RepairService CompleteRepairSession |
| P1-3 | P1 | Refresh() loads orphaned disk snapshots as placeholders | Orphaned snapshots invisible after restart | UndoViewerViewModel Refresh() |
| P1-5 | P1 | overallSuccess adds executedCount>0 && skippedCount==0 check | All-skipped semantics contradiction | FixExecutionService ExecuteCommands |
| P1-6 | P1 | Continue mode executes RollbackCommand before skipping | Skipping failed command left dirty state, cascading failure | FixExecutionService ExecuteCommands |
| P1-7 | P1 | needSnapshot checks registry/service command text | Snapshot trigger conditions did not match comments | FixExecutionService ExecuteCommands |
| P1-8 | P1 | Registry paths support five drives + multi-statement separators, loop extraction | Crude extraction missed paths | FixExecutionService ExtractRegistryPaths |
| P1-9 | P1 | EvaluatePreCheck passes actual cancellationToken | Cancellation ineffective during pre-check | FixExecutionService EvaluatePreCheck |
| P1-10 | P1 | ProModeView OnUnloaded unsubscribes + SuspendPolling | 9 events not unsubscribed | ProModeView OnUnloaded/OnLoaded |
| P1-11 | P1 | SmartModeView OnUnloaded unsubscribes + SuspendPolling | 6 events not unsubscribed + polling not suspended | SmartModeView OnUnloaded/OnLoaded |
| P1-12/B4 | P1 | 10 glass-dialog animations migrated to GlassDialogAnimation + onSafetyTimerCreated overload | Utility had zero callers, 11+ duplicates | GlassDialogAnimation.cs + 12 views |
| Audit A-1 | Audit | isPartial adds executedCount==0 check | Empty solution Success contradicted overallSuccess=false | FixExecutionService ExecuteCommands |
| Audit B-1 | Audit | Terminal-state branch removes BackupSnapshotId/RestorePointId assignment | Deleted snapshot re-referenced | RepairService CompleteRepairSession |
| Audit E-2 | Audit | Undo() manually raises PropertyChanged after success | POCO does not notify UI, no refresh after undo | UndoViewerViewModel Undo() |
| H-1 | Enhancement | Merged Trend/Timeline into unified Analyze button with dynamic icon/text switching + AuroraButton IconGeometry/IconSize/IconTextGap DPs | Two separate buttons cluttered UI and required advance knowledge of analysis type | AuroraButton.cs / ExportHistoryViewModel.cs / ExportHistoryView.xaml |
| H-2 | Fix | Added NotifySelectionBatchCompleted() called after ResumeSelectedEntriesNotifications() | SuspendSelectedEntriesNotifications suppressed CollectionChanged, OnSelectedEntriesChanged never fired | ExportHistoryViewModel.cs / ExportHistoryView.xaml.cs |
| H-3 | Fix | BuildTrendData data source changed from _entries to _selectedEntries | Trend chart showed full history instead of selected archives | ExportHistoryViewModel.cs |
| H-4 | Fix | Added GroupName="ReportFormatGroup" to 3 RadioButtons + SelectedFormat setter raises PropertyChanged for Is*Selected | RadioButtons in different Grid parents, WPF default exclusion scope failed | ReportFormatDialogView.xaml / ReportFormatDialogViewModel.cs |
| H-5 | Fix | ReportFormatDialogViewModel accepts isChinese param + IsChinese/LanguageName properties; ExportHistoryView passes _viewModel.IsChinese | Global LanguageService.IsChinese desynced from ExportHistoryViewModel._language | ReportFormatDialogViewModel.cs / ReportFormatDialogView.xaml.cs / ExportHistoryView.xaml.cs |
| H-6 | Fix | Format card Background/BorderBrush → named SolidColorBrush + ColorAnimation 200ms hover/selection fade | No hover feedback + per-alloc SolidColorBrush caused abrupt transitions and GC pressure | ReportFormatDialogView.xaml / ReportFormatDialogView.xaml.cs |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *This tool is for personal educational use only. Please comply with local laws and regulations.*
