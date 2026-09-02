# AURORA Analyzer

> **Windows Event Log Export & Intelligent Diagnostic Analysis Tool**
>
> Version: V1.6.30.5 Release · Tech Stack: WPF + .NET Framework 4.x + C# 5 + PowerShell 5.1
>
> Author: AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ This tool is for personal learning and research only. Please comply with local laws and regulations.

---

## 1. Introduction

AURORA Analyzer is a system event log export and intelligent diagnostic analysis tool designed specifically for the Windows platform. It can automatically collect and export more than a dozen types of Windows event logs (System, Application, Security, etc.), and then perform in-depth analysis on these logs through the built-in knowledge-graph-driven diagnostic engine, linking seemingly unrelated events into a complete causal chain, ultimately telling users "what really happened" and "how to fix it." Whether you are a casual computer user or an experienced system administrator, AURORA Analyzer provides powerful and easy-to-use diagnostic capabilities in a unified and elegant manner.

The tool adopts a WPF + .NET Framework 4.x single-process architecture, migrating and refactoring the engine logic, security mechanisms, and UI presentation layer originally scattered across PowerShell scripts into modular C# code, while retaining runtime capability equivalent to the original PowerShell diagnostic engine. All core modules are verified for integrity via RSA signatures at startup, and are continuously monitored during runtime by an anti-debug stack and file integrity guard, ensuring that the tool itself is not tampered with or reverse-engineered.

---

## 2. Target Audience

This tool is intended for all Windows users. For casual users, AURORA Analyzer provides an out-of-the-box "one-click diagnosis + one-click repair" workflow, complemented by a bilingual (Chinese/English) interface and graphical guidance, so it can be used without any command-line experience. For advanced users and system administrators, PRO mode provides a complete 17-stage diagnostic pipeline, multi-source log comparison, health scoring and historical fingerprint matching, along with deep features such as structured repair menus, undo management, system restore points, and export archiving. Whether the use case is daily health check, troubleshooting, or post-mortem analysis, the tool provides appropriate support at varying depths.

---

## 3. Core Features Overview

AURORA Analyzer's core capabilities can be summarized in five aspects. First, **intelligent diagnosis**: a rich knowledge-graph rule library is built in, supporting event ID matching, severity scoring (1–10), and causal analysis, linking scattered events into causal chains; a historical fingerprint matching engine compares current logs with historical archives using three-layer fingerprint comparison, providing a judgment of "whether a similar problem has occurred before" along with a system health score. Second, **multi-dimensional scanning**: covering system file integrity, service status, registry health, disk I/O, memory and CPU, network configuration, event logs, and many other dimensions. Third, **one-click repair**: after diagnosis completes, repairs can be automatically executed; system restore points and fast backup snapshots are automatically created before any repair, and all repair operations can be undone and precisely rolled back to the pre-operation state. Fourth, **session resumption**: diagnosis and repair progress is automatically persisted, so it can be resumed from the breakpoint after an unexpected interruption, with the number of interrupted days displayed to help users decide. Fifth, **security mechanisms**: from startup password, RSA-signed hash list, to UAC elevation token, a complete chain of trust is established; runtime protection is sustained through an anti-debug stack, file integrity guard, and watchdog heartbeat.

---

## 4. Startup Workflow

After launching AURORA Analyzer, the user goes through a carefully designed onboarding flow where every step balances security verification with visual experience.

**Splash Screen (SplashScreenView)** is the first screen the user sees. It displays the AURORA Analyzer title, version number, and performance tier label on a deep-space starfield background, cycling through 8 status messages via an aurora-glass progress bar (Initialize → Load diagnostic engine → Detect hardware → Prepare knowledge base → Complete). The progress bar advances at approximately 60 FPS using an easeOut curve, and automatically adjusts the startup duration multiplier based on the performance tier (ECO, PERFORMANCE, EXTREME).

**Startup password verification** follows immediately. The tool reads the `GAURORA.CHK.ENC` file, which encapsulates 16-byte Salt, 16-byte IV, and ciphertext in base64 form, derives a key via PBKDF2-SHA256 with 100,000 iterations, and then decrypts the hash list of core modules using AES-256-CBC + PKCS7 padding. The user enters the startup password in a 400×200 glass password dialog; only after verification passes can the main flow be entered. The dialog automatically selects Chinese or English based on the system CurrentUICulture, providing friendly error messages.

**UAC Elevation Dialog** appears when the user launches the tool with normal privileges. It presents a 720-wide card showing the functional differences between "Normal Mode" and "Administrator Mode" side by side, so the user clearly knows which additional repair operations become available after elevation (such as SFC, DISM, registry repair, etc.). The user can choose from three options: Elevate and Continue, Continue Normally, or Exit. If elevation is chosen, the tool restarts the process via `ElevationService` with `runas` Verb, and generates a 60-second-valid elevation token file via `ElevationTokenService` (encrypted with PBKDF2 100,000 iterations + AES-256-CBC, with file ACL restricted to the current user only). The new process restores the trust chain via this token, avoiding repeated password entry.

**Admin Path Pre-Parallax (V1.5.29.1)** is activated when the user already has administrator privileges. Because the admin path skips the UAC elevation dialog, the parallax span from Splash directly to the main window is only 0.15, and the starfield motion is occluded by exit/entrance animations, producing a "teleport" perception. V1.5.29.1 adopts a pre-parallax scheme: before starting NavigateTo, the starfield first runs alone for 500ms to dash to 0.30 depth, letting the user clearly perceive starfield motion, then starts Splash exit and main window entrance. The starfield motion splits into two segments (0.0→0.30→0.15) for a smooth transition.

After these three steps, the tool enters the main interface.

---

## 5. Main Interface and Mode Selection

The main interface (MainFormView) uses a two-stage state machine: first select the interface language, then select the operating mode.

**Language Selection Stage** displays a large-font title at the top of the view prompting the user to choose a language, with an AuroraButton list below. **Chinese comes first, English second** (matching Chinese users' habits). Clicking either button seamlessly switches the UI between Chinese and English at runtime, covering all UI text, diagnostic knowledge-base fields, checkpoint descriptions, HUD step labels, and dialog copy. **After language change (V1.6.30.5)**: MainFormView's Language property change syncs to `App.CurrentLanguage`, ensuring that subsequently shown glass overlay panels (Settings, Confirm-Exit, etc.) also use the new language — this is the baseline for shell-internal overlay multi-reuse synchronization.

**Mode Selection Stage** is entered after the language is selected. The tool offers two operating modes: **PRO mode** and **Smart mode**. Both modes share the same underlying diagnostic engine and repair service, but differ in interaction form and workflow depth to meet the needs of different user groups. The information panel on the left of the interface displays a short description of the currently selected mode in real time; the user can return to the previous stage at any time via the Back button.

The main window (MainWindow) serves as the unified shell, hosting the starfield control, main view host, privilege indicator, user-config button group, and confirm panel. **Top-right shell button group (V1.6.30.5)** — [Settings]⚙ and [Exit]✕, two AuroraButtons (36×36 hit area, ≥32 touch standard + `AutomationProperties.Name` accessibility), shown only on the mode-selection state. **Immediately hidden when entering other views** (Smart/PRO mode, history views, dialog views), avoiding persistent interference. **Settings panel** (`MotionSettingsDialogView`) and **Confirm-Exit panel** (`ExitConfirmDialogView`) are shell-internal glass overlays (UserControl hosted in RootGrid), same form as SolutionDetailView's glass message layer, with click-point-anchored growth (I-13). The AuroraPrivilegeIndicator intuitively shows the current process privilege level with a green shield (administrator) or orange shield (normal user), along with bilingual labels.

---

## 6. PRO Mode

PRO mode is a complete diagnostic pipeline for advanced users, using a 5-row grid layout: top title area, console echo area (AuroraConsoleBox), input panel, progress area (AuroraProgressBar + AuroraTaskHUD), and modal layer stack. The console and Task HUD are placed side by side so the user can track repair progress while observing real-time logs.

The complete diagnostic flow in PRO mode is divided into **17 checkpoint stages**, each with a bilingual description and progress percentage, persisted to disk via `SessionCacheService` to support resumption. These 17 stages are: Starting, Initialized, LogTypeSelected, DateRangeConfigured, PerformanceAssessed, Exporting, ProcessingStarted, FetchingFullLog, FullLogFetched, HighRiskScanComplete, HealthAssessmentComplete, ExportModeSelected, ExportStarted, Analyzing, Reporting, Completed, Failed. If any stage is interrupted (e.g., power loss, process killed, user-initiated close), the next launch will ask the user via `SessionRestoreDialogView` whether to "Restore" or "Restart", displaying the SessionId, current progress, stage, last update time, and elapsed days to help the user decide.

Under the hood, PRO mode runs a PowerShell RunspacePool (1–3 runspaces) in-process via `PowerShellHostService`, and uses `Hashtable.Synchronized()` to create a syncHash shared across runspaces, containing 30+ default keys (such as IsHostAlive, IsRunning, LogOutput, Progress, UserInput, IsAdmin, session resumption keys, authorization keys, pipeline keys, etc.). The engine continuously reads syncHash state via 13-key polling (50ms interval), and uses `DispatcherTimer` (50ms throttle) + `ConcurrentQueue` for batched console refresh, avoiding UI thread blocking caused by high-frequency logs.

PRO mode also includes a modal action state machine covering Elevate, UserInput, SmartAnalysis, ShowUserLogs, Decision, SessionRestore, ExportedLogs states. The ActionButton has three states: Execute / Stop / Retry. When switching from Smart mode back to PRO, a SuspendPolling / ResumePolling handshake ensures state consistency.

**Mode-switch polling state isolation (V1.5.29.1)** fixed the issue where, after returning from Smart mode to the main window and re-entering Pro mode, the console did not echo and progress was stuck at 50%. The root cause was that `StartSyncHashPolling` missed resetting the `_pollingSuspended` flag, causing all polling callbacks to be skipped. V1.5.29.1 resets this flag at the beginning of `StartSyncHashPolling`, ensuring a clean flag each time polling starts. It also fixed multiple related issues: "content flashes then disappears" caused by async ClearConsole, cross-thread CollectionChanged not propagating in AppendConsoleLine, and DispatcherTimer being starved by Render.

**Runspace reuse scope protection (V1.5.29.1)** fixed the issue where running Pro Mode first, then terminating it and running Smart Mode, produced an "Assert-AuroraLaunchContext command not found" error. The root cause was that the smart engine's LaunchGuard function call lacked a Get-Command existence check, and Runspace reuse caused the function definition to be lost. V1.5.29.1 aligns the smart engine with the pro engine's defensive call pattern — it now checks Get-Command for function existence before calling. It also fixes the polling sampling timing issue where progress was probabilistically stuck at 50% when the smart engine completes very quickly — Progress is now forced to 100% when the completion signal is detected, regardless of the running state.

---

## 7. Smart Mode

Smart mode is a lightweight repair entry point for casual users, using a 3:2 main split: AuroraConsoleBox on the left, structured SmartMenuItems on the right, and TaskHUD + ExecuteStopButton at the bottom.

Unlike PRO mode, which interacts through console text menus, Smart mode uses structured menu items (`SmartMenuItem`), each containing Index, RuleId, RuleName, Name, RiskLevel, RequiresAdmin, AutoExecute, IsExecuted (executed items show a ✓ checkmark), IsExecuting, and other fields. Display labels automatically append risk level (e.g., "(Low)"), admin tag ("[Admin]"), and authorization tag ("[Auto]" or "[Auth]"), letting the user clearly understand each operation's scope and permission requirements before execution.

Smart mode runs an independent SmartEngine underneath, driven by syncHash polling. When the user clicks the "Execute" button, `SmartModeViewModel.ExecuteNextPendingItem` sequentially batches all pending items where `AutoExecute=true`; during execution, `SyncTaskStates` synchronizes the HUD's 4-step status in real time. All repair results can be exported to a UTF-8 text file via `ExportLog`, making it easy for users to save or share with technical staff.

---

## 8. Diagnostic Engine

The diagnostic engine is the core intelligence of AURORA Analyzer, consisting of two complementary services: **rule-based knowledge-base matching** and **history-based fingerprint matching**.

**Knowledge-base matching (KnowledgeBaseService)** loads the diagnostic knowledge graph located at `Data/AURORA-TechData.json` (using lazy loading + caching strategy, supporting 6-level directory search). Each knowledge-base rule (KnowledgeBaseRule) contains bilingual fields: Name/NameEn, Description/DescriptionEn, Causes/CausesEn, Solutions/SolutionsEn, RecommendedAction/RecommendedActionEn, along with associated event IDs, sources, message keywords, priority, and a set of KnowledgeBaseCommand (each command containing Command, Type, Name, PreCheck, RollbackCommand, RiskLevel, ElevationRequired, AutoExecute, etc.). The matching algorithm uses three-layer scoring: strong signal = intersection of rule EventIds and current EventIds (weight 0.5), source matching = bidirectional Contains of rule Sources and current Sources (weight 0.2), weak signal = intersection of rule MessageKeywords and current keywords (weight 0.3). All rules with matchScore > 0 become candidates, sorted descending by matchScore × priority and returning the Top 5.

**Historical fingerprint matching (HistoryMatchService)** reads real-time event logs via the `EventLogReader` API (same API as Get-WinEvent), combined with XPath time filtering, dynamically computing the scan window (max of the user-configured DateRange and the default 24 hours, upper bound 30 days / 10,000 events). It extracts three-layer fingerprints from current logs: strong signal is the EventId+Source pair key (weight 0.7), weak signal is keywords extracted from error messages (filtered through 60+ stopwords, weight 0.3). Match threshold MatchThreshold=0.7, final score ComputeMatchScore = strongRate×0.7 + weakRate×0.3. A SHA256 16-hex fingerprint hash (top-5 strong + top-5 weak signals) is also computed for cross-export fingerprint comparison.

**System health scoring** is shared by both services via the formula: `health = 100 - (critical×3 + error×2 + warning) × 100 / totalEvents`. Health levels are divided into four tiers: ≥90 Excellent, ≥70 Good, ≥50 Fair, <50 Poor. This score is used both for historical comparison and for annotating each export archive with the system state at the time of export.

---

## 9. Repair Toolset

AURORA Analyzer provides a complete repair toolchain covering multiple aspects of the Windows system. All repair operations create a system restore point via `RestoreService` (based on WMI SystemRestore class) and a fast backup snapshot via `UndoManagerService` (four types: Registry / File / Service / Mixed) before execution, ensuring all operations can be undone and rolled back.

**Direct C# repair tools (RepairService)** include the following categories. **Windows Update control**: configures NoAutoUpdate=1, AUOptions=1 via registry key `SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU` to disable auto-update. **Defender protection**: sets DisableAntiSpyware=0 via registry key `SOFTWARE\Policies\Microsoft\Windows Defender` to enable Defender. **Telemetry control**: sets AllowTelemetry=0 via registry key `SOFTWARE\Policies\Microsoft\Windows\DataCollection` to disable telemetry. **Network reset**: resets network stack via `netsh winsock reset` + `netsh int ip reset` + `ipconfig /flushdns`. **System temp file cleanup**: cleans the `Path.GetTempPath()` directory. **SFC system file repair**: invokes `sfc.exe /scannow` (10-minute timeout). **Windows Store cache reset**: invokes `wsreset.exe` (60-second timeout). **Event log clearing**: clears Application / System / Security logs via `wevtutil cl`. **DNS flush**: via `ipconfig /flushdns`.

**Knowledge-base command execution (FixExecutionService)** is responsible for executing KnowledgeBaseCommands matched by the diagnostic engine. Command types support cmd (via `cmd.exe /c`) and powershell (via `powershell.exe -NoProfile -NonInteractive -Command`). Before execution, PreCheck is evaluated (a PowerShell expression whose non-empty output is considered passing), ElevationRequired is checked, and a warning is issued based on RiskLevel (High / Medium). Only commands with AutoExecute=true are auto-executed (conservative mode), preventing high-risk operations from being silently executed. On failure, RollbackCommand is automatically invoked (using the same type as the original command, avoiding PowerShell syntax being parsed by cmd.exe). The entire execution process is recorded via `RepairService`'s StartRepairSession / LogRepairCommand / CompleteRepairSession, and is made traceable in UndoViewer via `ProModeViewModel.RecordRepairSession`. The FixPhase state machine covers Starting / Executing / RolledBack / Completed / Skipped, and supports IProgress<FixProgress> and CancellationToken for real-time UI feedback and user cancellation.

**Execution window and rollback closed-loop hardening (V1.6.30.1)** comprehensively refactored the solution view execution window and hardened the rollback closed-loop. The execution window adopts a step-timeline + log dual-column layout, with the left side showing real-time FixPhase state machine progress and the right side synchronously echoing command logs. Failure handling supports Abort / Continue / AskUser three-state selection — Continue mode executes the failed command's RollbackCommand before skipping, preventing dirty-state cascade failures. Progress estimation calculates remaining time based on the average elapsed time of executed commands. Cancellation terminates the entire process tree via Process.Kill, avoiding orphan processes. EvaluatePreCheck passes the actual CancellationToken, making cancellation effective during pre_check. For the rollback closed-loop, CompleteRepairSession implements terminal-state protection (does not overwrite Status/CanUndo if already in a terminal state), expiry cleanup is linked to disk snapshot cleanup, and CleanupExpiredSnapshots(7) is called at startup to clean orphan snapshots. UndoViewerViewModel.Refresh() loads disk orphan snapshots for reconciliation, undo failure retains CanUndo=true for retry, and PropertyChanged is manually triggered after undo success to refresh the UI.

**System restore points (RestoreService)** are implemented based on the WMI SystemRestore class. CreateRestorePoint accepts description, restore point type, and event type parameters, mapped via RestorePointTypeName (APPLICATION_INSTALL, MODIFY_SETTINGS, DEVICE_DRIVER_INSTALL, etc.). Restore point metadata is saved as JSON to the SessionCache/restorepoints/ directory. GetRestorePoints filters AURORA-related restore points and sorts them descending by SequenceNumber, making it easy for users to locate restore points created by this tool. TestCapability checks administrator privileges, whether system restore is enabled (registry RPSessionInterval), and WMI accessibility.

---

## 10. Session Management and Undo

AURORA Analyzer's session management system consists of three complementary layers of services, ensuring that any diagnostic or repair operation can be interrupted, resumed, and undone.

**Progress checkpoints (CheckpointConfig + SessionCacheService)** define 17-stage checkpoint configuration (bilingual) for PRO mode. Whenever the engine enters a new stage, `SaveProgress` calls `SessionCacheService.SaveCheckpoint` to persist the current progress, supporting an additionalData dictionary (JSON-persisted). `SessionCacheService`'s directory structure is divided into three parts: active/ (active sessions), checkpoints/ (checkpoint archives), and archive/ (archived sessions). The .progress file stores SessionId, Stage, Progress, LastUpdated as key-value pairs. Sessions automatically expire and are archived after 7 days. All writes use atomic operations (File.Replace + .tmp + .bak), avoiding file corruption from crashes mid-write. The cache root directory resolves to Tools/Temp first, falling back to the system TEMP directory.

**Undo manager (UndoManagerService)** is responsible for creating and restoring fast backup snapshots. CreateBackupSnapshot creates a snapshot in a `BS_yyyyMMdd_HHmmss_xxx` directory. Backup types support Registry (via `reg.exe export` for backup, `reg.exe import` for restore), File (via File.Copy), Service (via `sc.exe qc` to dump service config to JSON, `sc.exe config` to restore start type, with ParseServiceStartType mapping sc.exe output to auto/demand/disabled/boot/system), and Mixed. TestBackupIntegrity verifies that backup files exist. RestoreBackupSnapshot restores all backup items in one pass. All JSON serialization is manually implemented (JsonEscape / JsonUnescape / JsonExtractString), avoiding external library dependencies.

**Undo viewer (UndoViewerView + UndoViewerViewModel)** presents historical sessions in a 720×500 glass dialog. The left ListView lists all RepairSessionInfo (obtained via `RepairService.GetAllSessions()`), and the right detail panel displays the command log of the selected session. The top statistics area shows total session count, success count, failure count, and undone count. Commands include Refresh, Undo (calls `UndoManagerService.RestoreBackupSnapshot`), Cleanup (deletes expired sessions), and View Details.

---

## 11. Export and History

AURORA Analyzer's export capability goes beyond "writing logs to files"; it includes a complete archiving and historical comparison mechanism.

**Export formats** are primarily JSON (containing complete event structures for subsequent analysis), with Smart mode also supporting export to UTF-8 text files (for user reading and sharing). The underlying PowerShell engine supports multi-log source merging via syncHash-controlled LogType such as "System+Application".

**Export history archiving (ExportHistoryService)** automatically archives after each analysis. The archive structure is `UserLogs/.history/{timestamp}/`, with each archive directory independently storing a `.metadata.json` (no global index required, facilitating cross-machine migration). The archiving process uses a snapshot diff mechanism: SnapshotFiles records all existing filenames and LastWriteTime before analysis; after completion, ArchiveExport compares against the snapshot—new filenames or updated LastWriteTime are treated as files from this export (crash logs CrashLog_*.log are excluded). Each archive computes three-layer fingerprints: strong signal is Top 10 EventId+Source pairs sorted by frequency (weight 100), weak signal is Top 10 error keywords (filtered through 60+ stopwords, weight 10), Context includes health score and critical/error/warning counts. The fingerprint hash is the first 16 hex of SHA256 (top-5 strong + top-5 weak), used for quick comparison across exports. LoadUnarchivedHistory also performs a fallback scan of un-archived JSON files in the UserLogs root directory, compatible with exports from previous versions.

**Export history viewer (ExportHistoryView + ExportHistoryViewModel)** displays archives in a list + detail split layout. List items display a health dot (Excellent=green, Good=blue, Fair=yellow, Poor=red), log type, and C/E/W count labels (Critical/Error/Warning). The detail area displays complete metadata, fingerprint cards, and command lists. Available commands include Refresh, Detect Current (real-time scan of un-archived files in the UserLogs directory), Delete (handles both archive directories and un-archived files), Open Directory (locate in File Explorer), and Export. All view transitions use the UWP fade-out delayed-commit pattern, avoiding content jumps.

**Solution detail dialog (SolutionDetailView + SolutionDetailViewModel)** displays the repair solutions matched by the diagnostic engine. The comparison area shows both historical and current health scores and event count differences, so the user can clearly see whether a problem has worsened or improved. The solution list displays all matched KnowledgeBaseCommands, supporting multi-select (CommandDisplayItem.IsSelected) for batch execution. The command area displays CloseCommand, ExecuteFixCommand, and ExecuteSelectedFixCommand. This ViewModel contains 30+ bilingual text properties; all transitions also use the UWP fade-out delayed-commit pattern (DetailExitRequested event + CommitPendingSolution).

**History analysis and report export experience upgrade (V1.6.30.1)** refined the history view's analysis entry and the report export dialog. The separate "Trend" and "Timeline" bottom buttons are merged into a single context-aware "Analyze" button whose text and icon switch dynamically based on selection: no selection shows "Analyze" (disabled), a single selected archive switches to "Timeline" for single-archive internal event distribution, and two or more switch to "Trend" for cross-archive health evolution. The cross-archive trend chart now correctly uses only the selected archives as its data source, and a post-batch notification handshake ensures the Analyze button's text, icon, and batch-delete label refresh immediately after multi-select operations. The report export dialog supports multi-format export with correct RadioButton mutual exclusion across layout containers, a unified per-ViewModel language chain that keeps the dialog and the exported HTML/Excel reports in sync with the main interface's language, and smooth 200ms ColorAnimation hover/selection feedback on the format option cards.

---

## 12. Security Mechanisms

AURORA Analyzer employs multi-layered protection in security, establishing a complete chain of trust from startup to runtime.

**Three-layer token chain**: Startup Password → RSA Token (hash list authorization) → Elevation Token. All three use PBKDF2-SHA256 with 100,000 iterations to derive keys, then encrypt using AES-256-CBC + PKCS7 padding, meeting modern encryption strength requirements. **PasswordService** reads the `GAURORA.CHK.ENC` file (base64-encapsulated Salt+IV+Cipher); VerifyPassword returns the decrypted hash list. **RsaTokenService** uses a hardcoded RSA public key XML to verify RSA-SHA256-PKCS1 signatures (format: `{nonce}:{timestamp}:{hashPayload}`); DecryptHashListFromToken derives a PBKDF2 key from the nonce and then decrypts using AES-256-CBC (IV = first 16 bytes of the payload). **ElevationTokenService** generates a 60-second-valid elevation token (format: `{nonce}:{timestamp}:{base64(iv+cipher)}`, valid when age < 60 and age > -5), with file ACL restricted to the current user only (SetAccessRuleProtection), and cleaned up via CleanupTokenFile after use.

**Integrity guard (IntegrityGuardService)** maintains a SHA256 hash whitelist of 27+ files (covering Core engine, Security, PRO, Smart, Animation, UI Views, WPF executables, assemblies, configs, XAML, etc.), verifying all core modules at startup to ensure they haven't been tampered with. During runtime, three types of Timers provide continuous monitoring: Timer1 polls file integrity every 3 seconds, Timer2 scans the environment at random 2–7 second intervals, and WMI Win32_ProcessStartTrace provides zero-latency process start notifications (administrator only). When an anomaly is detected, RecheckEngineIntegrity performs a 10-second debounce confirmation, and RecheckCoreEngineFiles immediately re-checks the 4 most critical files; if ConfirmDetection confirms 2 consecutive detections within a 5-second window, AuroraExitCountdown triggers a 15-second safe exit countdown, avoiding sustained confrontation with attackers. File hash computation uses 3 IO retries, avoiding false positives from transient IO errors.

**Anti-debug stack** implements 7 categories of detection. The first category calls IsDebuggerPresent to detect local debuggers; the second calls CheckRemoteDebuggerPresent to detect remote debuggers; the third queries NtQueryInformationProcess for ProcessDebugPort(0x7), ProcessHandleTracing(0x22), and ProcessDebugFlags(0x1F); the fourth checks the PEB.NtGlobalFlag offset (0x68 for x86, 0xBC for x64, debug flag 0x70); the fifth checks Dr0-Dr3 hardware breakpoint registers via GetThreadContext (716-byte CONTEXT for x86, 1232 bytes for x64); the sixth detects DLL injection (scanning non-system DLLs for keywords like inject/detour/spy); the seventh scans 30+ known debugger and reverse-engineering tool processes (windbg, x64dbg, ida, ollydbg, ghidra, radare2, dnspy, scylla, ilspy, processhacker, cheat engine, etc.). Additionally, HideThreadFromDebugger hides sensitive threads from debuggers via NtSetInformationThread(0x11).

**Elevation flow (ElevationService)**: when the user chooses to elevate, it first cleans up 6 environment variables (AURORA_WD_PIPE, AURORA_WD_SESSION, AURORA_LAUNCHED_BY_EXE, AURORA_TOKEN_PATH, AURORA_EXE_VERIFIED, AURORA_HASH_PATH), stops IntegrityGuardService runtime monitoring and waits 300ms for cleanup to complete, then restarts the process as administrator via ProcessStartInfo (Verb="runas", UseShellExecute=true). Command-line arguments include --launched-by-exe, --skip-splash, --language (optional), and --elevation-token-path. IsCurrentProcessElevated determines current privilege via WindowsPrincipal.IsInRole(Administrator).

---

## 13. Performance Adaptation

AURORA Analyzer automatically selects the most appropriate performance tier based on the user's hardware, avoiding lag on low-end machines and wasting performance on high-end ones.

**Performance tiers (AuroraRenderEngine.PerformanceTier)** include four levels: **Eco** disables all effects (particles, complex glow, sweep light, path shadows, meteors, starfield animation all off) at 30 FPS, suitable for devices scoring < 115; **Balanced** disables particles, complex glow, sweep light, and meteors at 60 FPS, keeping only path shadows and starfield animation, suitable for devices scoring 115–174; **Performance** enables particles, sweep light, and meteors at 60 FPS, disabling complex glow, suitable for devices scoring 175–279; **Extreme** enables all effects at 60 FPS, suitable for flagship devices scoring ≥ 280.

**Performance scoring formula v3** is `perfScore = (logicalCores × 20) + (ramGB × 10) + max(0, (baseClockMHz - 2000) / 100) + gpuScore`, where gpuScore comes from real GPU probing by MaterialCapabilities (via D3D9Ex device creation + WMI Win32_VideoController query), rather than a simple VRAM threshold. NVIDIA/AMD discrete graphics + D3D9Ex + 4GB+ VRAM scores 80, Intel integrated graphics + D3D9Ex scores 25, and 5–20 when D3D9Ex is unavailable. This real-hardware-capability-based scoring avoids the awkward situation of "looks advanced but actually lags."

**Performance diagnostics dialog (PerformanceDiagnosticsView)** is a 720×560 diagnostics window that displays complete hardware information (CPU, memory, GPU), real-time FPS sampled at 500ms intervals, 6 independently toggleable animation options (particles, complex glow, sweep light, path shadows, meteors, starfield animation), and a tier selector. The user can manually override the auto-detected tier; all changes are synchronized to AuroraRenderEngine in real time.

**Performance upgrade dialog (PerformanceUpgradeDialogView)** only appears for Eco / Balanced tier users. It is a 580×460 upgrade suggestion window displaying target tier information and expected improvements. For low-end machines, it also recommends using console mode (i.e., Smart mode) for a smoother experience. Performance / Extreme tier users will not see this dialog.

**Material preset tiers (MaterialStylePreset)** are automatically selected by tier: Eco/Balanced uses AuroraFluentGlass (BlurRadius=5), Performance uses AuroraFluentGlassPerformance (BlurRadius=6, FresnelStrength=0.35, RimLightStrength=0.45), Extreme uses AuroraFluentGlassExtreme (BlurRadius=7, FresnelStrength=0.55, RimLightStrength=0.65). Background capture throttling is also differentiated by tier: Eco=66ms (15fps), Balanced=50ms (20fps), Performance/Extreme=33ms (30fps), with further fallback to 100ms (10fps) for software rendering (RenderCapability.Tier=0).

**Remote session and VM optimization**: when MaterialCapabilities detects IsRemoteSession (RDP / VM environment), the GPU backend is forcibly disabled, falling back to RTB software blur, avoiding severe rendering lag in remote sessions without GPU acceleration.

---

## 14. Visual System

AURORA Analyzer's visual system is one of its most distinctive features; all rendering strictly follows the 60 FPS synchronization and zero-allocation hot-path principles.

**Starfield background (AuroraStarfield)** is the visual foundation of the entire UI. Star count is differentiated by tier: Eco=80, Balanced=180, Performance=350, Extreme=600. V1.5.29.1 increases the star Size base coefficient from 0.8 to 1.1 (~37% overall enlargement), CurrentRenderSize initial from 0.55× to 0.7× (visible immediately on entrance), and BaseAlpha upper limit from 130 to 180 (higher bright-star ratio), making stars more prominent and eye-catching during depth motion. The background includes 5 aurora curtain layers (AuroraCurtain), each with an independent Y position, hue (Hue), and max alpha: Layer 0 at Y=0.12 shows green (Hue=140, MaxAlpha=145), Layer 1 at Y=0.28 shows cyan (Hue=185, MaxAlpha=120), Layer 2 at Y=0.48 shows purple (Hue=270, MaxAlpha=100), Layer 3 at Y=0.68 shows magenta (Hue=320, MaxAlpha=85), Layer 4 at Y=0.85 shows green again (Hue=160, MaxAlpha=70). Meteors, 4-corner cross starbursts (Diffraction), and aurora Bloom glow are enabled only in Performance / Extreme tiers. Mouse movement triggers constellation lines (Connections, 30-frame throttle) and mouse glow (GlowFactor).

**Multi-level depth parallax system (V1.5.29.0 reshaped, V1.5.29.1 optimized)** maps different views to 7 depth levels: SplashScreen=0.00 → MainForm view1=0.15 → MainForm view2=0.30 → ProMode=0.50 → SmartMode=0.60 → dialog group (ExportHistory=0.70 / UndoViewer=0.78 / ElevationDialog=0.82 / SessionRestore=0.86) → SolutionDetail=0.95. V1.5.29.1 reallocated the depths of 5 dialog/detail views, eliminating zero-span switches between peer views, so every click has visible depth feedback. View switches use UwpStandardEase curves for smooth 2700ms transitions, avoiding abrupt level jumps. Parallax parameters push=0.30, scale=0.45, opacity=0.25 preserve the in-your-face feel while avoiding excessive impact; brightness recovers from V1.5.29.0's 38% to 75%.

**Meteor-style halo trail system (V1.5.29.1 new)** draws LinearGradientBrush gradient halo trails for near-field stars (Depth>0.6, ~150-200 stars) during parallax, reinforcing motion direction sense. Trail length is driven by normalized velocity (`trailLen = (absoluteVelocity / parallaxSpan) × depth × 600`), so a consistent peak trail is visible regardless of span size. Trail direction adapts to zoomOut/zoomIn: zoomOut points the tail toward center (stars come from center), zoomIn points the tail outward (stars come from outside). EMA exponential moving average (α=0.3) eliminates inter-frame jitter, and soft-threshold transition (0.0002~0.001 linear 0→1) eliminates hard-cut flicker when the trail appears/disappears. The trail naturally shortens with velocity decay ("retracts"), and disappears immediately when parallax ends, with no residual flicker. All animations are driven by CompositionTarget.Rendering (replacing DispatcherTimer), and use sine lookup tables (4096 entries + linear interpolation) and Brush caching to achieve zero-allocation hot paths (the per-star new Brush GC pressure during parallax is acceptable, since parallax is only 2.7s and already skips expensive rendering such as halo/spike/constellation lines).

**Aurora glass material (V5 material pipeline)** consists of AuroraMaterialPipeline (global singleton, subscribing to CompositionTarget.Rendering) + AuroraMaterialComposer (weak reference list, preventing memory leaks) + 15 ordered IMaterialLayers. The 15 layers from bottom to top are: ShadowLayer (soft shadow, iOS-style radial gradient, Order=10), BlurLayer (blurred background, samples shared cache, Order=20), TintLayer (tint layer, injects aurora color / system color / wallpaper color, Order=50), BodyLayer (glass body, semi-transparent gradient, Order=60), NoiseLayer (micro noise texture, Order=70), FresnelLayer (Fresnel edge glow, Order=80), SpecularLayer (specular highlight, tracks mouse position, Order=90), BevelLayer (bevel depth, 3D chamfer illusion, Order=100), EdgeHighlightLayer (edge highlight, aurora flow), InnerGlowLayer (inner glow), GlowLayer (outer glow, hover transition, Order=130), ChromaticLayer (chromatic aberration, pixel offset), RefractionLayer (refraction distortion), CausticsLayer (caustics light spots, V1.4.29), IridescenceLayer (iridescent interference, V1.4.29). The pipeline also implements mouse position injection (SpecularLayer tracking), 30-frame decay-and-stop-redraw after mouse leave, and per-layer render timing diagnostics (LayerTiming[]).

**Blur backends** provide 5 implementations: RtbBlurBackend (RenderTargetBitmap + BlurEffect, software blur, 1/2 resolution, as universal fallback), ShaderEffectBackend (WPF ShaderEffect, HLSL PS 3.0), DwmApi (DWM Acrylic Blur, Win10 17063+), D3DCompiler (d3dcompiler_47.dll, HLSL runtime compilation), AuroraBlurHlsl (HLSL shader source). AuroraGlassMaterial, as the v4 static helper class, implements geometry caching (CombinedGeometry + PathGeometry rebuilt only on size change), shared noise texture (128×128, 8% alpha, fixed seed), 60fps overlay refresh + 30fps blurred background capture (decoupled, conforming to project_memory constraints), and 1/2 resolution RTB.Render (960×540 max, equivalent radius=6).

**UWP standard animation system** provides a complete curve family: UwpStandardEase (cubic-bezier(0.8, 0, 0.2, 1)), UwpAccelEase ((0.7, 0, 1, 0.5)), UwpDecelEase ((0.1, 0.9, 0.2, 1)), UwpExpoOutEase ((0.16, 1.0, 0.3, 1.0)), UwpDampedEase (3-segment interpolation, 3.5% overshoot). AnimationHelper provides PlayUwpEnter (QuarticEase EaseOut, 0→1 Scale + 0→1 Opacity + Y offset), PlayUwpExit (3-stage keyframes: elastic pullback + accelerated dispersal + late fade-out), PlayMainWindowEnter (1.15→1.03→1.0 monotonic convergence + slight overshoot, 660ms+1100ms SineEase). All entrance animations strictly follow project_memory constraints: direct overshoot to 1.15 followed by 800ms convergence to 1.0, all exit animations scale from 1.0 to 1.15, Dialog RenderTransform is created in code (not XAML) to ensure reliability in PRO mode, RenderTransformOrigin = (0.5, 0.5) for centered scaling.

**Quick-switch flashback fix (V1.5.29.1)** uniformly introduces a `_pendingEnterTimers` tracking list for 6 IAuroraStaggerView views (ProMode, SmartMode, ExportHistory, SolutionDetail, ElevationDialog, SessionRestore). The DispatcherTimers created by entrance animations (per-tile stagger, fallback backup, listDelay list-item delay) were originally fire-and-forget; they would fire after the exit animation started and override the exit state, causing controls to flash back to their original position. V1.5.29.1 uniformly calls `CancelPendingEnterTimers()` before the exit animation starts, canceling all pending entrance timers and eradicating the quick-switch flashback issue.

**Glass dialog animation unified encapsulation (V1.6.30.1)** migrated 10 duplicated glass dialog entrance/exit animation implementations into the `GlassDialogAnimation` utility class. The entrance animation is a three-channel Scale 0.92→1.07→1.0 (360ms CubicEase + 525ms QuarticEase bounce) + TranslateY 24→0 + Opacity 0→1; the exit animation is a windup 1.0→0.97 (80ms QuadraticEase) → scale-away 0.97→1.15 (720ms QuadraticEase) + TranslateY 0→-16 + Opacity 1→0. The utility class provides three public methods: `PlayGlassEnter` (overlay+contentBorder entrance), `PlayGlassExit` (exit + onClosed callback + safety timer), and `PlayWindowExit` (Window-level exit), with an `onSafetyTimerCreated` callback overload supporting the ProModeView ModalOverlay reuse scenario. Animation duration constants are centrally managed (EnterScaleMs/EnterBounceMs/ExitWindupMs/ExitLeaveMs/ExitFadeMs/ExitSafetyMs) — any parameter adjustment requires modifying only one place.

**Custom control library** includes 9 core controls. **AuroraButton** is an aurora glass button with Normal/Hover/Press/Disabled/Loading/Success/Failure state machine, magnetic offset (radius 135, strength 0.35, max 17.5, smoothing 0.08), tilted sweep light (SkewTransform -20° + gradient rectangle, 2400ms), iOS Q-elastic release feedback (600ms), V1.5 liquid glass hover-leave jelly rebound (271ms), ripples (Lifetime 1.2s, easeOutCubic), 500ms click cooldown + 500ms long-press detection, aurora environment color injection (sampled by Y position), 15+ render layers, and keyboard focus glow (3 outer glow + 2 inner glow layers). **AuroraConsoleBox** is an aurora glass console echo box, integrated with the V5 material pipeline (corner radius 12, depth 0.5), implementing batched UWP slide-in entrance (_pendingLines cache + 33ms throttle flush, 910ms normal / 560ms meteor compressed), new-line animation (DampedPushEase displacement + SmoothEaseOut opacity + top highlight line + outer glow), UWP smooth scrolling (910ms SmoothEaseOut subpixel _scrollFraction), custom glass scrollbars (track + thumb + hover/drag states + outer glow), text selection + right-click menu "Copy all terminal logs" + Ctrl+C, FormattedText caching (steady-state zero-allocation), and size-change sampling freeze (IsSizeChangeFrozen). **AuroraTaskHUD** is a task status HUD with 4-step nodes (Environment Detection / Risk Assessment / Targeted Auto Repair / Verify Repair Results), TaskState enum (Pending / Running / Success / Error), text slide-in animation, and V5 material pipeline integration (corner radius 12, depth 0.6). **AuroraProgressBar** is an aurora glass progress bar with V5 material pipeline integration (configurable corner radius, depth 0.6), tilted sweep light, progress leading light point, and particle system (Performance/Extreme). **AuroraTextBlock** is an aurora text block with text switching animation (Idle→FadingOut→Waiting→FadingIn→Idle) and entrance animation state. **AuroraPrivilegeIndicator** is a privilege indicator showing a green shield + checkmark for administrators and an orange shield for normal users, with V5 material pipeline integration (corner radius 8, depth 0.6). **AuroraFrostedGlassBorder** is an aurora frosted glass border inheriting from Border (fully XAML-API compatible), with Depth DependencyProperty controlling EffectiveBlurRadius = Preset.BlurRadius × (0.3 + Depth × 1.4), and UseV5Pipeline toggle for switching between V5 pipeline and v4 AuroraGlassMaterial.

**Glass dialogs & click-point growth (V1.6.30.5, I-13)** All glass popups (Settings panel, Confirm-Exit panel, SolutionDetail message layer, ModalOverlay) now anchor the transform origin to the click position — `ComputeClickOrigin(clickPosition, contentBorder, referenceAncestor)` normalizes screen/window coordinates to contentBorder and clamps to 0.15–0.85, avoiding edge distortion. `PlayGlassEnter` expands from the mouse position per this origin, aligning with modern operating systems' "content grows from touch point" interaction intuition. **`MousePosition` dead-link cleanup (V1.6.30.5)** — `AuroraMaterialComposer` originally wrote `MousePosition` per frame but no downstream layer consumed it, creating architectural debt on the hot path; this version keeps the `SetMousePosition` API (for on-demand use) but per-frame updates trigger only when there is an actual consumer.

**AuroraFrostedGlassBorder & glass dialog motion pipeline (V1.6.30.5)** All 10+ duplicated glass dialog entrance/exit implementations (Settings, Confirm-Exit, SolutionDetail, ModalOverlay, etc.) are unified into the `GlassDialogAnimation` utility class (`PlayGlassEnter` / `PlayGlassExit` / `PlayWindowExit`), with all durations bound in real time to the user's motion-pace setting via `AuroraMotionSettings.Scale()`. Combined with `PlayChromeButtonExit` (staggered exit channel aligned with `PlayUwpExitSlow`: scale 1→0.85 + Y→130 + 70% late fade) and `ResetChromeButtonAnimations` (HoldEnd animation suppression of local values — flash regression fix), all motion polish corners are covered.

**Motion pace switch & three-track decoupling (V1.6.30.5)** New centralized config `AuroraMotionSettings` with `MotionRecipe.Graceful/Fast` dual-pace recipes (Graceful 800ms old-version full ritual / Fast 450ms compact-efficient), instant-effect via `EffectiveRecipe` priority chain (System reduce-animation > Eco tier > User pace). Container entrance, starfield parallax, and MainFormView internal switch — three tracks originally bound to one total budget (2700ms) — are now decoupled into independent timelines: starfield parallax reads `ParallaxFloorMs` (Graceful 2200ms / Fast 900ms) + tail (Graceful 1400ms); the starfield continues sliding through the remaining depth after the UI transition ends, longitudinal continuity preserved. Meanwhile, ~40 scattered motion sites (exit orchestration estimates, stagger rhythms, glass dialog durations, shell enter/exit, various dialog animations) are unified via the `Scale()` global scaling tool — switching pace consistently affects every corner, no more "fast here, slow there" fragmentation. See [Docs/UpdateV1.6.30.5_EN.md](./Docs/UpdateV1.6.30.5_EN.md) for details.

**Skeleton screen & DPI optimization (V1.6.30.5, I-16)** New PerMonitorV2 manifest (`app.manifest`) + window-level `UseLayoutRounding=True` (`MainWindow.xaml`) — 1px hairline highlights no longer blur under DPI scaling. `Styles.xaml` adds skeleton screen base styles (`AuroraSkeletonRowStyle` + `AuroraSkeletonShimmerBrush`) — Shimmer placeholder during list loading, preventing content jump.

---

## 15. Bilingual Support

AURORA Analyzer implements complete Chinese-English bilingual support, managed uniformly by `LanguageService`. This service loads the `AURORA.Wpf.Properties.Resources` resource files via ResourceManager (zh-CN for default Chinese, en for English), with CurrentLanguageName returning "CHS" / "ENG" to be compatible with the original PowerShell script conventions. It provides methods such as SetChinese / SetEnglish / SetLanguage / GetString / Format / TryGetString / GetStringForCulture, with runtime switching requiring no restart.

Bilingual coverage is extremely broad, including: all UI text (titles, descriptions, buttons, statuses, error prompts), all bilingual fields of KnowledgeBaseRule (Name/NameEn, Description/DescriptionEn, Causes/CausesEn, Solutions/SolutionsEn, RecommendedAction/RecommendedActionEn), 17-stage bilingual descriptions in CheckpointConfig, 4-step bilingual labels in AuroraTaskHUD, bilingual labels in AuroraPrivilegeIndicator, bilingual feature lists in ElevationDialog, and 30+ bilingual text properties in SolutionDetailViewModel. PasswordDialogViewModel also auto-detects language from CurrentUICulture, so the first launch displays the user's native language. The main interface language selection follows the order "Chinese first, English second," matching Chinese users' habits.

---

## 16. System Requirements

| Item | Minimum | Recommended |
|------|---------|-------------|
| Operating System | Windows 10 1809+ | Windows 11 22H2+ |
| Processor | Dual-core 1.5 GHz | Quad-core 2.5 GHz+ |
| Memory | 4 GB | 8 GB+ |
| Architecture | x64 (required) | x64 |
| .NET Framework | 4.x | 4.8 |
| PowerShell | 5.1 | 5.1 |

Remote sessions (RDP) and virtual machine environments are automatically detected, with the GPU backend forcibly disabled and falling back to software blur, ensuring usability.

---

## 17. Quick Start

The simplest way is to double-click `AURORA-AnalyzerWPF.exe` (WPF version) or `AURORA-Analyzer.exe` (classic PowerShell version) in the repository root. After launch, the tool sequentially completes startup password verification, performance detection, and (if needed) UAC elevation, then enters the main interface.

To launch from the command line, use the following:

```powershell
# WPF version
.\AURORA-AnalyzerWPF.exe

# Specify startup language
.\AURORA-AnalyzerWPF.exe --language en-US

# Skip splash screen
.\AURORA-AnalyzerWPF.exe --skip-splash
```

After entering the main interface, first select the interface language (Chinese or English), then select the operating mode: casual users are recommended to use **Smart mode** (structured menus, batch repair, simple operation), while advanced users are recommended to use **PRO mode** (17-stage complete pipeline, multi-source log comparison, in-depth analysis). Both modes support returning to the mode selection interface at any time via the Back button.

---

## 18. Project Structure

The repository uses a clear modular structure, with the main directories as follows:

| Directory | Description |
|-----------|-------------|
| `AURORA.Wpf/` | WPF version main project (MVVM + single-process architecture) |
| `AURORA.Wpf/Controls/` | Custom control library (9 controls including AuroraButton, AuroraConsoleBox, AuroraStarfield, etc.) |
| `AURORA.Wpf/Materials/` | V5 material pipeline (15 layers + 5 blur backends + 4 presets) |
| `AURORA.Wpf/Animation/` | Animation system (UWP easing curve family + custom easing) |
| `AURORA.Wpf/Services/` | Business service layer (20+ services including PowerShell host, repair, diagnostics, security, session, export, language, etc.) |
| `AURORA.Wpf/ViewModels/` | MVVM ViewModel layer |
| `AURORA.Wpf/Views/` | View layer (main interface, PRO, Smart, Splash, dialogs, etc.) |
| `AURORA.Wpf/Themes/` | Theme resources (AuroraTheme, Brushes, Animations, Styles, Templates) |
| `AURORA.Wpf/Infrastructure/` | Infrastructure (converters, ObservableObject, RelayCommand, etc.) |
| `Data/` | Diagnostic knowledge graph `AURORA-TechData.json` and cache |
| `Docs/` | Architecture documentation, audit reports, and historical READMEs |

---

## 19. Usage Notice

This tool is provided "AS IS" for personal learning and research only. Please read the following notes before use:

- Do not use this tool for any unauthorized system operations or purposes that violate local laws and regulations. System repair operations may affect the system; please back up important data before execution. The author is not responsible for any direct or indirect losses arising from the use of this tool.
- All repair operations automatically create system restore points and fast backup snapshots before execution, but users are still advised to manually confirm before executing high-risk operations (RiskLevel=High). All operations can be undone via UndoViewer or rolled back via Windows System Restore.
- Exported event logs may contain sensitive information (usernames, computer names, application paths, etc.). Please store them securely to prevent unauthorized disclosure.
- The tool activates anti-debug and integrity protection during runtime. If user security software (such as antivirus) raises false positives, this tool can be added to the whitelist; if users wish to analyze this tool for legitimate reverse-engineering research purposes, please contact the author through official channels.
- When running in remote sessions (RDP) or virtual machines, the tool automatically disables GPU acceleration; the visual experience may be slightly degraded, but functionality is completely equivalent.

---

## 20. Acknowledgments

Thanks to all users who have provided feedback, reported bugs, and suggested features. Every piece of feedback makes AURORA Analyzer better.

---

*AURORA VelociRaptor-GR Dev PRJ. · V1.6.30.5 Release*
