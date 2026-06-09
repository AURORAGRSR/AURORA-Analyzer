# AURORA Analyzer V1.3.26.5 — Release Notes

> **Build Date:** 2026.06.08
> **Theme:** Complete Architectural Decoupling
> **Codename:** Project Aurora — Factory Release
> **Project:** AURORA Analyzer — Windows System Event Log Export & Smart Diagnostic Tool

---

## Table of Contents

1. [Overview](#overview)
2. [What's New — At a Glance](#whats-new--at-a-glance)
3. [Key Features](#key-features)
4. [V1.3.26.5 Update Highlights](#v13265-update-highlights)
   - [Before & After: Architecture Comparison](#before--after-architecture-comparison)
5. [System Requirements](#system-requirements)
6. [Quick Start](#quick-start)
7. [Usage Guide](#usage-guide)
   - [Smart Diagnostic Mode — Full Workflow](#smart-diagnostic-mode--full-workflow)
   - [PRO Visualization Mode — In Depth](#pro-visualization-mode--in-depth)
   - [Repair Toolkit — Deep Dive](#repair-toolkit--deep-dive)
   - [Repair & Undo Workflow](#repair--undo-workflow)
   - [Session Recovery Flow](#session-recovery-flow)
8. [Performance Modes](#performance-modes)
9. [Security Architecture](#security-architecture)
10. [Advanced Usage](#advanced-usage)
11. [Troubleshooting Common Issues](#troubleshooting-common-issues)
12. [FAQ](#faq)
13. [Data Storage & Privacy](#data-storage--privacy)
14. [Legal & Credits](#legal--credits)

---

## Overview

**AURORA Analyzer** is a professional-grade Windows system diagnostic and event log analysis tool. It combines a rich graphical user interface (GUI) with a powerful **PowerShell 5.1 + C# hybrid engine** running on **.NET Framework 4.x**, enabling both casual users and seasoned system administrators to scan, diagnose, repair, and export Windows system data with ease.

Whether you're troubleshooting a sluggish PC, preparing a forensic report, hardening system security, or just curious about what's happening under the hood — AURORA Analyzer bridges the gap between raw system internals and a polished, user-friendly experience.

### Who Is AURORA For?

| User Type | Typical Use Case |
|---|---|
| **Home Users** | One-click health check, clean up bloat, disable unwanted telemetry |
| **Gamers & Enthusiasts** | Tune performance, identify bottlenecks, disable background services |
| **IT Support / Help Desk** | Quickly diagnose client machines, generate standardized reports |
| **System Administrators** | Audit event logs, export forensic data, manage fleet health |
| **Security Analysts** | Event log forensics, integrity verification, anomaly detection |
| **Privacy-Conscious Users** | Disable telemetry, verify system integrity, audit running services |

### What Makes AURORA Different?

| Capability | AURORA Analyzer | Built-in Windows Tools |
|---|---|---|
| **One-click full system scan** | ✅ 7 dimensions, knowledge-graph powered | ❌ Manual, fragmented tools |
| **Auto-generated diagnosis report** | ✅ Plain-language explanations + severity ratings | ❌ Raw data only |
| **Visual log export (CSV/JSON/XML)** | ✅ Professional charts, trends, correlations | ❌ Text-only via Event Viewer |
| **Repair with Undo** | ✅ 6 repair types with snapshot rollback | ❌ No built-in undo |
| **Session checkpoint / resume** | ✅ Survive crashes, reboots, accidental closes | ❌ None |
| **Bilingual (EN / 中文)** | ✅ Auto-detect locale + manual override | ❌ Single language |
| **Offline & privacy-respecting** | ✅ Zero network connections, zero telemetry | ❌ Windows telemetry always on |

---

## What's New — At a Glance

This release is not just a feature update — it's a **ground-up architectural rebuild**. Here's what changed in one table:

| Area | Before (V1.3.25) | After (V1.3.26.5) |
|---|---|---|
| **Code architecture** | Single monolithic file (10,000+ lines) | 9 modular layers, 22+ independent files |
| **Security code** | Mixed with UI/diagnostic logic | Dedicated `SecurityModule.ps1` |
| **UI windows** | Embedded in main file | Independent view files per window |
| **PRO Mode** | Separate CHS/ENG code paths | Unified single engine, locale-aware |
| **Startup time** | ~4.2 seconds | ~2.8 seconds (-33%) |
| **Idle memory** | ~180 MB | ~145 MB (-19%) |
| **Module loading** | All-at-once parse | Lazy-load on demand |
| **Bug fixes** | — | 7 priority-level fixes (P0–P2) |
| **Security patches** | — | 4 security enhancements including critical elevation fix |

---

## Key Features

### 1. Smart Diagnostic Mode

The flagship feature of AURORA Analyzer. With a single click, the Smart Diagnostic Engine scans your system across **7 critical dimensions** and uses a knowledge-graph reasoning engine to identify, explain, and suggest fixes for detected issues.

**7 Diagnostic Dimensions — Detailed Breakdown:**

| # | Dimension | What It Checks | Common Issues Found |
|---|---|---|---|
| 1 | **System Files** | SFC integrity verification, DLL registration, missing manifests | Corrupted system files, broken DLL registrations, missing COM components |
| 2 | **Services** | Critical service status, dependency chains, startup type, failure counts | Disabled BITS, stopped Windows Update, broken dependency trees |
| 3 | **Registry** | Orphaned entries, startup autorun keys, policy misconfigurations | Broken uninstall entries, excessive Run keys, Group Policy conflicts |
| 4 | **Disk** | SMART attributes, free space thresholds, fragmentation levels, pending sectors | Failing drive (SMART warnings), critically low free space, reallocated sectors |
| 5 | **Memory** | Physical/virtual usage, commit charge, pool paged/non-paged, hard faults | Memory pressure, leak patterns, excessive paging activity |
| 6 | **CPU** | Sustained utilization, thermal throttling events, core parking state, DPC latency | Background process hogging CPU, thermal throttling active, high DPC/ISR time |
| 7 | **Event Logs** | System/Application/Security log patterns, BSOD dump analysis, audit failures | Recurring disk errors, service crash loops, failed login audit trails |

**Diagnosis Output Structure:**

Each finding in the report includes:
- A **severity indicator** (🟢 Info / 🟡 Warning / 🔴 Critical)
- A **human-readable title** summarizing the issue
- A **plain-language explanation** describing what's wrong and why it matters
- A **specific, actionable recommendation** — often with a one-click "Apply Fix" button
- **Knowledge-graph cross-references** linking related issues (e.g., a disk error linked to a service that depends on that disk)
- **External reference IDs** (Microsoft KB articles, Event ID documentation)

**Example Diagnosis:**

> 🔴 **Critical:** `wuauserv` (Windows Update) is stopped and disabled
>
> The Windows Update service is not running, which means your system is not receiving security patches. This was detected alongside a SMART warning on your system drive, which may indicate the service was disabled after disk-related update failures.
>
> **Recommendation:** First address the disk health issue, then re-enable Windows Update via AURORA's Repair Toolkit.
>
> **Linked Issues:** Disk SMART Warning (finding #4), CBS Log Errors (finding #1)
>
> _[Apply Fix] [Dismiss] [More Info]_

### 2. PRO Visualization Mode

Designed for power users, system administrators, and forensic analysts. PRO Mode gives you complete control over what data to export, how to filter it, and how to visualize the results.

**Export & Analysis Capabilities:**

- **Export Formats:** CSV (Excel-compatible), JSON (machine-readable), XML (structured)
- **Data Sources:** System, Application, Security, Setup, Forwarded Events logs, plus Performance Counters, WMI queries, and registry snapshots
- **Visualization Types:**
  - **Trend Charts** — event frequency over time, line/bar charts with configurable time windows
  - **Distribution Graphs** — event distribution by source, severity, or log type (pie/donut/bar)
  - **Correlation Matrices** — cross-reference events from different logs to find causal relationships
  - **Heat Maps** — activity density by hour-of-day and day-of-week
- **Filtering & Scoping:**
  - Date/time range (absolute or relative, e.g., "last 7 days")
  - Severity filter (Critical / Error / Warning / Information / Verbose)
  - Event source or provider name
  - Specific Event IDs or ID ranges
  - Keyword and full-text search within event messages
- **Batch Export:** Queue multiple export jobs with different filters and formats; run them in sequence with progress tracking
- **Historical Comparison:** Load a previous export as a baseline; PRO Mode highlights deviations, new patterns, and resolved issues between scans

**PRO Mode Use Cases:**

| Scenario | How PRO Mode Helps |
|---|---|
| **Pre-deployment audit** | Export full system state before deploying new software or updates |
| **Post-incident forensics** | Filter and export relevant event logs around an incident timestamp |
| **Compliance reporting** | Generate structured CSV/XML reports for auditors |
| **Trend analysis** | Run weekly exports and compare to spot degrading system health |
| **Capacity planning** | Export performance counters over time to predict resource needs |

### 3. System Repair Toolkit

AURORA Analyzer doesn't just diagnose — it fixes. The Repair Toolkit includes **6 repair types**, each with full **Undo support** via automatic snapshot creation before every change.

| Repair Type | What It Does | Typical Duration | Undo Method |
|---|---|---|---|
| **DisableWindowsUpdate** | Pauses updates, stops related services, disables scheduled tasks | ~15s | Restart services + re-enable tasks |
| **EnableDefender** | Restores Windows Defender services, registry keys, and Group Policy settings to defaults | ~20s | Revert to pre-repair registry + service state |
| **DisableTelemetry** | Sets telemetry level to "Security" (0), disables DiagTrack service, blocks known telemetry endpoints | ~10s | Restore original telemetry level + service state |
| **ResetNetwork** | Flushes DNS, releases/renews DHCP, resets Winsock catalog, restores Windows Firewall defaults | ~30–60s | Restore network config from snapshot |
| **CleanSystem** | Clears temp files, Windows Update cache, prefetch, recycle bin, browser caches, thumbnail cache | 1–5 min | File restoration from snapshot (larger files only) |
| **Custom** | Run any PowerShell script or command of your choice | Varies | Snapshot taken before execution |

**Undo Mechanism — Two-Layer Safety Net:**

1. **System Restore Point** — Created before every repair (leverages Windows System Restore infrastructure)
2. **AURORA Fast Snapshot** — AURORA's own lightweight snapshot captures key registry keys, service states, and file lists for instant rollback (typically < 5 seconds)

This dual-layer approach means even if one undo method fails, the other serves as a fallback.

### 4. Session Checkpoint & Resume

Never lose progress again. AURORA automatically saves your session state at every checkpoint so you can resume from any interruption — whether it's a crash, a forced reboot, or simply closing the app before you meant to.

**Session Features at a Glance:**

- **Auto-save triggers:** After every completed diagnostic dimension, after every repair, after every export
- **Manual checkpoint:** Press `Ctrl+S` or click "Save Checkpoint" at any time
- **Multiple sessions:** Store and manage multiple independent sessions (e.g., one per machine you service)
- **7-day auto-expiry:** Old sessions automatically expire to prevent data accumulation; configurable in settings
- **Resume with full context:** All scan results, repair history, export jobs, and UI state are restored exactly
- **Disk-aware:** If free disk space drops below 100 MB during a session, AURORA warns and switches to a minimal save mode

### 5. Bilingual Interface

AURORA Analyzer automatically detects your Windows display language and switches between **English** and **中文（简体）**. You can also manually override in Settings — no restart required. The language switch is instant and covers every UI element, including dynamically generated diagnosis text.

---

## V1.3.26.5 Update Highlights

This release represents a **fundamental architectural transformation**. We've taken the monolithic codebase and decomposed it into a clean, modular structure — improving maintainability, security, performance, and stability across the board.

### Category 1: Complete Architecture Decoupling

**Before:** All code resided in a single monolithic file (`LauncherGUI.ps1`) exceeding **10,000+ lines**. This made debugging, testing, and extending the codebase extremely difficult. A single change could cascade into unexpected breakage anywhere in the application.

**After:** The codebase is now organized into **9 clear module layers** containing **22+ independent `.ps1` files**, each with a single responsibility. The layered architecture enforces strict dependency direction: UI depends on Engines, Engines depend on Core; never the reverse.

**New Directory Structure:**

```
AURORA-Analyzer/
│
├── AURORA-Launcher.exe          ← Signed entry point
│
├── Core/                        ← Foundation layer (no UI dependencies)
│   ├── CoreEngine.ps1           ← Application lifecycle, module orchestration
│   └── AnimationEngine.ps1      ← GPU-accelerated transitions, effects, FPS management
│
├── Security/                    ← Isolation layer (zero external dependencies)
│   ├── SecurityModule.ps1       ← RSA verification, SHA-256 integrity, certificate validation
│   └── RuntimeGuardian.ps1      ← Anti-tamper watchdog, memory guard, process monitor
│
├── UI/
│   ├── Controls/                ← Reusable custom WinForms controls
│   │   ├── TechButton.ps1       ← Styled buttons with hover/click animations
│   │   ├── ProgressBar.ps1      ← Custom-drawn progress bars with glow effects
│   │   └── StarfieldPanel.ps1   ← Animated parallax background canvas
│   │
│   └── Views/                   ← Top-level windows & dialogs
│       ├── MainForm.ps1         ← Primary dashboard with tab navigation
│       ├── SplashScreen.ps1     ← Animated startup splash with progress
│       ├── ProMode.ps1          ← PRO mode workspace
│       ├── SettingsDialog.ps1   ← Application settings
│       ├── AboutDialog.ps1      ← Version info & credits
│       ├── RepairConfirmDialog.ps1 ← Repair safety confirmation
│       └── ExportOptionsDialog.ps1 ← PRO export configuration
│
├── Engines/                     ← Business logic layer
│   └── SmartDiagnosticEngine.ps1 ← 7-dimension scanner with knowledge graph
│
├── PRO/                         ← Professional export subsystem
│   ├── ProEngine.ps1            ← Export engine (CSV/JSON/XML generation)
│   └── ProEntry.ps1             ← PRO mode initialization & locale adapter
│
├── Session/                     ← State persistence subsystem
│   ├── SessionManager.ps1       ← Session lifecycle, auto-save, expiry management
│   ├── CheckpointManager.ps1    ← Checkpoint creation, serialization, restoration
│   └── UndoManager.ps1          ← Snapshot management, rollback execution
│
├── Repair/                      ← System repair subsystem
│   ├── RepairEngine.ps1         ← Repair type definitions & execution
│   ├── RepairLogger.ps1         ← Repair audit trail & history
│   └── RestoreManager.ps1       ← System restore point + fast snapshot management
│
└── GUI/                         ← Shared UI utilities
    ├── GuiHelpers.ps1           ← Common dialog helpers, DPI scaling, theming
    └── LanguageResources.ps1    ← Bilingual string tables for EN and zh-CN
```

### Category 2: Modular Directory Structure — Detailed Breakdown

Each directory now has a clear, single responsibility enforced by the architecture:

| Module | Files | Responsibility | Dependencies |
|---|---|---|---|
| **Core/** | 2 | Application bootstrap, lifecycle, and animation timing | None (base layer) |
| **Security/** | 2 | All security verification, integrity checks, and runtime protection | Core |
| **UI/Controls/** | 3 | Reusable custom WinForms controls with themed rendering | Core |
| **UI/Views/** | 7 | Every window, dialog, and form in the application | Core, UI/Controls, GUI |
| **Engines/** | 1 | Smart diagnostic scanning and knowledge-graph reasoning | Core, Security |
| **PRO/** | 2 | Professional export, formatting, visualization data generation | Core, Engines |
| **Session/** | 3 | Progress persistence, checkpoint, undo snapshot management | Core |
| **Repair/** | 3 | System repair execution, logging, system restore integration | Core, Session |
| **GUI/** | 2 | Shared helpers: dialogs, DPI scaling, themes, language strings | Core |

### Category 3: Security Module Independence

All security-critical code has been extracted into a dedicated **`SecurityModule.ps1`**. This includes:

- **RSA signature verification** — validates the launcher EXE signature against trusted public keys
- **SHA-256 file integrity** — every `.ps1` module is hashed on build; runtime verification catches any tampering
- **Runtime memory guard** — periodic integrity checks on in-memory code to detect injection attacks
- **Anti-tampering watchdog** — monitors file system changes to AURORA's own directory structure
- **Certificate chain validation** — improved with reduced false positives for enterprise CA environments

**Why this matters:** Security audits can now focus on a single file (plus `RuntimeGuardian.ps1`). Security patches no longer risk breaking UI or diagnostic code. The security module can be updated independently of the rest of the application.

### Category 4: View Separation

Every window and dialog is now an independent view file under `UI/Views/`. This is a dramatic improvement over the old approach where all UI code was interleaved with business logic in a 10,000-line file.

**7 Independent View Files:**

| File | Description | Lines (approx.) |
|---|---|---|
| `MainForm.ps1` | Primary dashboard — tab navigation, feature cards, status bar | ~600 |
| `SplashScreen.ps1` | Animated splash with module load progress, version display | ~200 |
| `ProMode.ps1` | PRO mode workspace with filter panel, preview, and export controls | ~500 |
| `SettingsDialog.ps1` | Language, performance tier, session expiry, security options | ~250 |
| `AboutDialog.ps1` | Version info, build date, engine versions, credits | ~150 |
| `RepairConfirmDialog.ps1` | Detailed repair description with safety confirmation | ~200 |
| `ExportOptionsDialog.ps1` | PRO export format, filter, and destination configuration | ~180 |

**Benefits of View Separation:**
- Each view can be **developed and tested independently**
- UI theming changes don't cascade into unexpected files
- New dialogs can be added by creating a single new file
- Code review is dramatically easier — reviewers see exactly what changed for a specific window

### Category 5: Smart Engine Independence

The Smart Diagnostic Engine is now a fully standalone module in `SmartDiagnosticEngine.ps1`. It exposes a clean API that can be:

- Called programmatically from any view or external script
- Unit-tested in isolation with mock system data
- Updated and patched without touching a single line of UI code
- Potentially reused in a future headless/CLI version or a scheduled-task mode

**Engine API (simplified):**
```powershell
# Import the engine
Import-Module ".\Engines\SmartDiagnosticEngine.ps1"

# Run a full 7-dimension scan
$results = Invoke-SmartDiagnostic -Dimensions All -Timeout 120

# Run a targeted scan
$results = Invoke-SmartDiagnostic -Dimensions @("Disk","Memory") -Timeout 60

# Get knowledge-graph explanations for a finding
$explanation = Get-DiagnosticExplanation -FindingId $results[0].Id
```

### Category 6: Unified PRO Build

Previously, Chinese (CHS) and English (ENG) versions of PRO Mode were separate code paths with significant duplication — a maintenance nightmare that led to locale-specific bugs (a feature working in English but broken in Chinese, or vice versa).

**The fix:** Both locales are now handled by a **single unified engine**. `ProEngine.ps1` generates locale-neutral data structures, and `ProEntry.ps1` handles locale-specific formatting at the presentation layer. This eliminates code duplication and guarantees feature parity across languages.

### Category 7: Performance Improvements

| Metric | Before (V1.3.25) | After (V1.3.26.5) | Improvement |
|---|---|---|---|
| **Code file complexity** | ~10,000 lines in 1 file | ~22 files, avg. ~450 lines each | Readability ⬆️ |
| **Module load strategy** | Parse entire codebase at startup | Lazy-load modules on demand | Smarter loading |
| **Cold startup time** | ~4.2 seconds | ~2.8 seconds | **-33%** |
| **Warm startup time (2nd launch)** | ~3.1 seconds | ~1.9 seconds | **-39%** |
| **Memory footprint (idle)** | ~180 MB | ~145 MB | **-19%** |
| **Memory footprint (during scan)** | ~320 MB | ~260 MB | **-19%** |
| **Module import validation** | Implicit, error-prone | Explicit `Import-Module` with dependency check | Reliability ⬆️ |

### Category 8: Security Enhancements

- **AURORA-SEC-2026-001 (P0):** Fixed a critical elevation token handling bug that could cause privilege escalation to fail silently. The launcher now validates the token integrity before proceeding and provides clear error messages if elevation fails.
- **P0 Watchdog Cleanup:** Multiple critical fixes to `RuntimeGuardian.ps1`: orphaned child processes on watchdog restart, handle leak in the file monitor watcher, race condition on rapid start/stop cycling.
- **Certificate Chain Validation:** Improved handling of enterprise CA environments and offline machines, reducing false "untrusted signature" warnings by ~90% in managed environments.
- **Anti-Tamper Detection:** Reduced false positives by excluding legitimate Windows processes (TrustedInstaller, TiWorker, etc.) from the suspicious-interaction monitor.

### Category 9: Stability Improvements

A systematic sweep of reported issues was addressed with priority-level triage:

| Priority | Issue | Impact | Fix Summary |
|---|---|---|---|
| **P0** | State management race condition during rapid scan ↔ repair cycling | Application crash or hung UI | Added state machine with mutex guarding state transitions |
| **P0** | Watchdog orphaned process leak on abnormal exit | Memory/resource leak, zombie processes accumulating | Proper `finally` blocks and process tree termination on exit |
| **P1** | Duplicate module imports causing symbol conflicts | Intermittent "command already exists" errors | `Import-Module` now checks for existing imports before loading |
| **P1** | Session corruption when disk is full during checkpoint save | Irrecoverable session data loss | Pre-flight disk space check + atomic write (write to temp, rename) |
| **P2** | Resource cleanup delay on application exit | Brief window where files remain locked | Synchronous cleanup on `FormClosing` event before process exit |
| **P2** | UI flicker during language switching at runtime | Visual glitch during language change | Double-buffered language swap with `SuspendLayout`/`ResumeLayout` |
| **P2** | Inconsistent FPS cap enforcement between Eco and Balanced | Eco mode occasionally running at 60 FPS | Fixed vsync timing calculation in `AnimationEngine.ps1` |

### Before & After: Architecture Comparison

**Architecture Before V1.3.26.5:**

```
LauncherGUI.ps1  (10,000+ lines)
    │
    ├── Mixed: UI rendering code
    ├── Mixed: Diagnostic engine logic
    ├── Mixed: Security checks
    ├── Mixed: PRO mode export logic
    ├── Mixed: Repair engine
    ├── Mixed: Session management
    ├── Mixed: Language strings
    └── Mixed: Everything else
```

**Architecture After V1.3.26.5:**

```
AURORA-Launcher.exe ──► Core/CoreEngine.ps1
                            │
              ┌─────────────┼─────────────┐
              │             │             │
         Security/     Engines/        Session/
              │             │             │
              │        ┌────┴────┐        │
              │        │         │        │
              │    PRO/     Repair/       │
              │        │         │        │
              └────────┼─────────┼────────┘
                       │         │
                    UI/Views/    │
                       │         │
                    UI/Controls/ │
                       │         │
                       └────┬────┘
                            │
                          GUI/
```

**Key architectural principles now enforced:**
- **Dependency direction:** UI → Engines → Core (never reverse)
- **Isolation:** Security has zero external dependencies
- **Lazy loading:** Modules loaded only when needed
- **Single responsibility:** Each file does exactly one thing

---

## System Requirements

| Component | Minimum | Recommended | Notes |
|---|---|---|---|
| **Operating System** | Windows 10 1809+ / Windows 11 / Windows Server 2019+ | Windows 11 23H2+ | LTSC and Server Core require desktop experience |
| **Processor** | Dual-core 1.5 GHz | Quad-core 2.5 GHz+ | Hyper-threading beneficial for parallel scans |
| **RAM** | 4 GB | 8 GB+ | Large event logs may require more memory during export |
| **Architecture** | **x64 only** | x64 | 32-bit (x86) is **not supported** |
| **.NET Framework** | 4.6.2 minimum | 4.8 | Included in Windows 10 1809+ by default |
| **PowerShell** | **5.1 (required)** | 5.1 | **Not compatible with PowerShell 7 (Core)** |
| **Disk Space** | 200 MB | 500 MB | Additional space for session data and exports |
| **Display** | 1280×720 | 1920×1080+ | DPI scaling supported (100%–200%) |

> **Important:** AURORA Analyzer requires PowerShell 5.1 — it is **not compatible** with PowerShell 7 (Core). This is by design, as the tool leverages .NET Framework-specific APIs (WinForms, WMI, System Restore) not available in cross-platform PowerShell. If both versions are installed, AURORA will automatically use PowerShell 5.1.

---

## Quick Start

Getting started with AURORA Analyzer takes just three steps:

### Step 1: Download & Verify

1. Download the latest release package: **`AURORA-Analyzer-V1.3.26.5.zip`**
2. Extract to a permanent location (e.g., `C:\Tools\AURORA-Analyzer\`)
3. Verify file integrity using the included `checksums.sha256` file:

```powershell
# In PowerShell, navigate to the extracted folder:
cd "C:\Tools\AURORA-Analyzer"
Get-FileHash -Algorithm SHA256 *.* | Format-Table -AutoSize
# Compare output against checksums.sha256
```

> **Do NOT run AURORA from a temporary folder, Downloads folder, or directly from the ZIP archive.** Extract to a permanent location first.

### Step 2: Launch

1. Right-click **`AURORA-Launcher.exe`**
2. Select **"Run as Administrator"** (required for full diagnostic and repair access)
3. The animated splash screen will appear while modules are loaded and verified
4. If prompted by Windows SmartScreen, click "More info" → "Run anyway" (this is normal for newly released software)

### Step 3: Run Your First Scan

1. From the main dashboard, click the large **"Smart Diagnostic"** button
2. Watch as the 7-dimension scan progresses (typically 30–90 seconds)
3. When the scan completes, review the color-coded report
4. Click any finding to expand its details — including a plain-language explanation and a suggested fix
5. Use the **"Apply Fix"** button next to any finding you want AURORA to repair automatically

---

## Usage Guide

### Smart Diagnostic Mode — Full Workflow

The Smart Diagnostic Mode follows a 7-step sequential workflow. Each step builds on the previous one, and findings in later steps may be linked to issues detected earlier via the knowledge graph.

| Step | Name | What Happens | Typical Duration |
|---|---|---|---|
| **1** | **Initialization** | Security verification, engine warm-up, scan target enumeration | < 2s |
| **2** | **System Files** | SFC verification, hash-check critical system DLLs, validate driver signatures | 10–30s |
| **3** | **Services** | Enumerate Windows services, check dependencies, compare against expected defaults | 5–15s |
| **4** | **Registry** | Scan Run/RunOnce keys, check Group Policy settings, detect orphaned COM registrations | 5–20s |
| **5** | **Disk & Memory** | Query SMART attributes via WMI, check free space, analyze commit charge and pool usage | 10–30s |
| **6** | **CPU & Performance** | Sample CPU utilization, check for thermal throttling events in event log, assess core parking | 5–15s |
| **7** | **Event Logs** | Parse System/Application/Security logs, correlate recurring patterns, analyze BSOD history | 10–60s |

**Total scan time:** ~30–90 seconds on modern hardware; up to 3 minutes on older systems with large event logs.

**Reading the Report:**

When the scan completes, you'll see a color-coded summary:
- 🟢 **Green category** — No issues detected in this dimension
- 🟡 **Yellow category** — Minor issues found; recommendations available
- 🔴 **Red category** — Critical issues detected; immediate attention recommended

Click any finding card to expand it. Expanded cards show the full diagnosis, the knowledge-graph explanation, linked findings, and an **"Apply Fix"** button where applicable.

**Scan Tips:**
- You can cancel a scan at any time — completed steps are saved to the session
- Click the **"⚙ Scan Options"** link to skip specific dimensions (e.g., skip Event Logs for a faster scan)
- Results are automatically saved to your session and persist across app restarts

### PRO Visualization Mode — In Depth

PRO Mode transforms AURORA from a diagnostic tool into a professional data export and analysis platform.

**Detailed PRO Mode Workflow:**

1. **Open PRO Mode:** Click the **"PRO Mode"** button on the main dashboard. The PRO workspace opens with a data-source tree on the left and a preview panel on the right.

2. **Select Data Sources:** Check the boxes for the data you want to export:
   - System event log
   - Application event log
   - Security event log
   - Setup event log
   - Forwarded Events
   - Performance counters (CPU, Memory, Disk, Network)
   - WMI system information snapshot
   - Registry key snapshots (specify paths)

3. **Apply Filters (Optional):**
   - **Time Range:** "Last hour" / "Last 24 hours" / "Last 7 days" / "Last 30 days" / Custom date range
   - **Severity:** Check boxes for Critical, Error, Warning, Information, Verbose
   - **Event IDs:** Enter specific IDs (e.g., "41,1001,6008" for crash-related events) or ID ranges (e.g., "1000-1999")
   - **Source:** Filter by event source/provider name
   - **Text Search:** Filter events containing specific keywords

4. **Choose Export Format:**
   - **CSV** — Best for Excel, Google Sheets, LibreOffice. Tabular, human-readable.
   - **JSON** — Best for scripting, Power BI, Python, data pipelines. Nested structure preserves event XML.
   - **XML** — Best for archival, other Windows tools, compliance. Preserves the exact event XML schema.

5. **Select Destination:** Choose where to save the export file and whether to auto-open it after completion.

6. **Execute Export:** Click **"Export"** — a progress bar tracks the operation. Large exports (100,000+ events) may take a minute or more.

7. **Analyze:**
   - Use the built-in **Trend Viewer** to visualize event patterns over time
   - Use **Compare Mode** to overlay the current export against a previous baseline
   - **Export the visualization** as a PNG image for reports

**PRO Mode Pro Tips:**
- Establish a **baseline** when your system is healthy; future exports can automatically compare against it
- For forensic analysis, export both CSV (for human review) and JSON (for scripted analysis)
- Use the text search filter to find specific error messages across all log sources simultaneously
- PRO Mode respects the same performance tier as the rest of the app; switch to Extreme for the smoothest chart rendering

### Repair Toolkit — Deep Dive

Each of the 6 repair types is designed to address a specific category of system configuration. Here's what each one actually does under the hood:

#### DisableWindowsUpdate
- Stops the `wuauserv` (Windows Update), `UsoSvc` (Update Orchestrator), and `WaaSMedicSvc` services
- Sets their startup type to "Disabled"
- Disables associated scheduled tasks in `\Microsoft\Windows\WindowsUpdate\`
- **Undo:** Re-enables services, restores original startup types, re-enables scheduled tasks

#### EnableDefender
- Checks if Defender is disabled by Group Policy or third-party antivirus registration
- Resets relevant registry keys under `HKLM\SOFTWARE\Policies\Microsoft\Windows Defender`
- Ensures `WinDefend`, `WdNisSvc`, `SecurityHealthService` services are running
- **Undo:** Restores previous registry values and service states

#### DisableTelemetry
- Sets `HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection\AllowTelemetry` to `0` (Security level only)
- Disables the `DiagTrack` (Connected User Experiences and Telemetry) service
- Optionally adds known telemetry endpoints to the hosts file for network-level blocking
- **Undo:** Restores original telemetry level, re-enables service if it was running

#### ResetNetwork
- Runs `ipconfig /flushdns` — clears DNS resolver cache
- Runs `ipconfig /release` and `ipconfig /renew` — refreshes DHCP lease
- Runs `netsh winsock reset` — resets Winsock catalog to clean state
- Runs `netsh int ip reset` — resets TCP/IP stack
- Restores Windows Firewall to default settings via `netsh advfirewall reset`
- **Undo:** Restores network configuration from snapshot (IP, DNS, firewall rules)

#### CleanSystem
- Clears `%TEMP%` and `C:\Windows\Temp`
- Clears Windows Update download cache (`C:\Windows\SoftwareDistribution\Download`)
- Clears Prefetch files (`C:\Windows\Prefetch`)
- Empties Recycle Bin
- Clears browser caches (Edge, Chrome, Firefox — if detected)
- Clears thumbnail cache
- Reports total space freed
- **Undo:** Files moved to a snapshot location (larger than a configurable threshold) can be restored; small temp files are permanently deleted

#### Custom
- Opens a script editor where you can enter any PowerShell script or command
- AURORA creates a full system snapshot before execution
- Output and errors are captured and displayed in the repair log
- **Undo:** Full snapshot rollback available

### Repair & Undo Workflow

All repairs in AURORA Analyzer are reversible. The undo mechanism uses two independent layers:

**Layer 1 — System Restore Point:** AURORA calls `Checkpoint-Computer` to create a Windows System Restore point. This captures the full system state and can be used even if AURORA itself is unavailable.

**Layer 2 — AURORA Fast Snapshot:** AURORA captures a lightweight JSON snapshot containing:
- Current state of all modified registry keys and values
- Service startup types and status of affected services
- File lists for files that will be modified or moved

Fast Snapshot rollback typically completes in under 5 seconds.

**Applying a Repair:**
1. Navigate to the **Repair Toolkit** tab
2. Select a repair type (e.g., "DisableTelemetry")
3. Review the detailed description of what will be changed (registry keys, services, files)
4. Click **"Apply Repair"**
5. The confirmation dialog shows a summary — review and click "Confirm"
6. AURORA creates both a System Restore Point and a Fast Snapshot
7. The repair executes; progress is shown in real time
8. A success/failure notification appears; the repair is logged to the Repair History

**Undoing a Repair:**
1. Navigate to **Session → Repair History**
2. Find the repair you want to reverse (sorted by date, most recent first)
3. Click the **"Undo"** button next to it
4. AURORA attempts the Fast Snapshot rollback first
5. If that succeeds, you're done in seconds. If not, AURORA offers to use the System Restore Point instead.
6. Verify the undo was successful — the repair entry moves to "Undone" status

> **Warning:** `ResetNetwork` may temporarily disconnect you from the internet for 30–60 seconds. This is normal and expected. If connectivity doesn't return after 60 seconds, reboot your computer.

### Session Recovery Flow

AURORA's session system handles three common interruption scenarios. In all cases, your progress is protected.

#### Scenario 1: Accidental Close
1. You close AURORA mid-scan by mistake (clicked X, pressed Alt+F4, etc.)
2. Re-launch AURORA — the splash screen detects the unfinished session
3. A dialog appears: **"An unfinished session was detected. Resume?"**
4. Click **"Resume"** — the main dashboard opens exactly where you left off
5. All completed scan dimensions, repair history, and export results are preserved
6. The in-progress scan step is re-run from the beginning of that step

#### Scenario 2: System Reboot (Update, Crash, Power Loss)
1. Windows forces a reboot while AURORA is running
2. After logging back in, launch AURORA
3. The session system detects the interrupted session from disk
4. The session state is restored from the most recent auto-saved checkpoint
5. Completed steps are displayed in green; the interrupted step is shown in yellow
6. You can choose to re-run just the interrupted step or restart the entire scan

#### Scenario 3: Application Crash
1. AURORA encounters an unexpected error and terminates
2. On re-launch, the crash recovery dialog appears with more detail:
   - What was happening when the crash occurred (scanning, repairing, exporting)
   - How much progress was saved
   - Whether any repairs were in progress
3. Options:
   - **"Resume Safely"** — Rolls back any incomplete repairs, then resumes from the last checkpoint
   - **"Resume As-Is"** — Resumes without rolling back (use only if you're sure the repair was safe)
   - **"Discard"** — Deletes the crashed session and starts fresh
4. If a repair was in progress during the crash, AURORA strongly recommends "Resume Safely"

**Session Management Tips:**
- Sessions auto-expire after 7 days (configurable: 3, 7, 14, or 30 days in Settings)
- You can manually delete old sessions from **Session → Manage Sessions**
- Each session stores scan results, repair history, PRO exports, and UI state
- Typical session size: 10–50 MB (grows with PRO exports and event log data)

---

## Performance Modes

AURORA Analyzer includes **4 performance tiers** to balance visual quality with system resource usage. The optimal mode is auto-detected based on your hardware, but you can override it manually.

| Mode | Target Hardware | FPS Cap | Visual Effects | CPU/GPU Usage |
|---|---|---|---|---|
| **Eco** 🌿 | Low-end PCs, VMs, laptops on battery | 30 FPS | Minimal — basic transitions only | Very low — near-zero GPU load |
| **Balanced** ⚖️ | Typical desktop or laptop (default) | 60 FPS | Standard — smooth animations, hover effects | Moderate — typical desktop app level |
| **Performance** 🚀 | High-end desktop with dedicated GPU | 60 FPS | Enhanced — particle effects, gradient rendering, parallax | Higher — leverages GPU for rendering |
| **Extreme** 🔥 | Enthusiast / workstation | 60 FPS | Full — animated starfield, glow effects, real-time reflections | Maximum — full GPU-accelerated rendering |

**Visual Effects by Tier:**

| Effect | Eco | Balanced | Performance | Extreme |
|---|---|---|---|---|
| Button hover animations | ❌ | ✅ | ✅ | ✅ |
| Progress bar glow | ❌ | ✅ | ✅ | ✅ |
| Tab transition animations | ❌ | ✅ | ✅ | ✅ |
| Splash screen animations | Minimal | Full | Full | Full |
| Particle effects | ❌ | ❌ | ✅ | ✅ |
| Parallax background | ❌ | ❌ | ✅ | ✅ |
| Animated starfield background | ❌ | ❌ | ❌ | ✅ |
| Real-time UI reflections | ❌ | ❌ | ❌ | ✅ |
| Gradient-rendered panels | ❌ | ❌ | ✅ | ✅ |

**Auto-Detection Logic:**

AURORA automatically selects a tier based on:
1. CPU core count and clock speed
2. Total system RAM
3. Presence and capability of a dedicated GPU
4. Whether the system is running on battery power
5. Available system resources at launch time

**Manual Override:**

1. Navigate to `%APPDATA%\AURORA-Analyzer\`
2. Open `config.json` in any text editor
3. Find or add the `"PerformanceTier"` key
4. Set its value to: `"Eco"`, `"Balanced"`, `"Performance"`, or `"Extreme"`
5. Save and restart AURORA

Example `config.json`:
```json
{
    "PerformanceTier": "Extreme",
    "Language": "Auto",
    "SessionExpiryDays": 7,
    "EnableMasterPassword": false
}
```

---

## Security Architecture

AURORA Analyzer implements a **4-layer defense-in-depth protection system** to ensure the software you're running is authentic and untampered.

### Layer 1: EXE Digital Signature Verification

The launcher executable (`AURORA-Launcher.exe`) is digitally signed with a code-signing certificate. Windows automatically verifies this signature before execution:
- If valid → execution proceeds normally
- If invalid or missing → Windows SmartScreen displays a warning
- If revoked → execution is blocked

**User action:** If you see a SmartScreen warning on first launch, verify you downloaded from an official source, then click "More info" → "Run anyway." On subsequent launches, the warning should not reappear.

### Layer 2: Module File Integrity (SHA-256)

All `.ps1` module files are hashed with SHA-256 during the build process. The expected hashes are embedded in the Security Module and also published in `checksums.sha256`.

**At startup, the Security Module:**
1. Computes the SHA-256 hash of every `.ps1` file in the AURORA directory
2. Compares each hash against the expected value
3. Any mismatch → alert dialog + execution blocked
4. All hashes match → execution proceeds

**Manual verification:**
```powershell
# Navigate to AURORA directory, then:
Get-ChildItem -Recurse -Filter "*.ps1" | Get-FileHash -Algorithm SHA256 | Format-Table -AutoSize
# Compare output against checksums.sha256
```

### Layer 3: Password Authentication (Optional)

For shared or enterprise environments, you can enable a master password:
- Administrative actions (repairs, system changes) require the password
- Failed attempts are logged and rate-limited (5 attempts → 5-minute lockout)
- Password is stored as a salted SHA-512 hash in the local config

### Layer 4: Runtime Guardian (Real-Time Protection)

`RuntimeGuardian.ps1` runs as a background monitor with four subsystems:

| Subsystem | What It Monitors | Response to Tampering |
|---|---|---|
| **Memory Integrity** | Code injection, hooking, unexpected memory modifications | Immediate lockdown + alert |
| **File System Watcher** | Changes to AURORA's own `.ps1` and `.dll` files | Re-verify hash; lockdown if mismatch |
| **Process Monitor** | Suspicious process interactions (DLL injection, handle duplication) | Log incident + alert |
| **Debugger Detection** | Unauthorized debugger attachment attempts | Block attachment + alert |

**If tampering is detected:**
1. The Guardian triggers an immediate UI lockdown — all buttons and inputs are disabled
2. A tamper alert dialog appears with details of what was detected
3. The user is advised to re-download AURORA from the official source
4. The alert is logged to the AURORA log file for later investigation

### Verifying an Authentic Copy — Checklist

- [ ] **Digital signature:** Right-click `AURORA-Launcher.exe` → Properties → Digital Signatures → should show a valid signature
- [ ] **SHA-256 checksums:** Run manual verification (see Layer 2 above) and compare against `checksums.sha256`
- [ ] **Download source:** Only download from official channels (our website or official GitHub releases)
- [ ] **File sizes:** Compare against the published file manifest; suspiciously different sizes are a red flag
- [ ] **No password prompts at unexpected times:** AURORA only asks for confirmation during repairs; unexpected password prompts may indicate tampering

> **⚠️ Security Warning:** Never download AURORA Analyzer from third-party "download portals," file-sharing sites, or unofficial mirrors. These copies may be modified to include malware, spyware, or backdoors. The only way to guarantee authenticity is to verify the digital signature and SHA-256 checksums against official sources.

---

## Advanced Usage

### Running Individual Engine Modules

Advanced users can leverage AURORA's modular architecture to run specific engine components directly from PowerShell, bypassing the GUI:

```powershell
# Navigate to AURORA directory
cd "C:\Tools\AURORA-Analyzer"

# Run only the disk health check
Import-Module ".\Engines\SmartDiagnosticEngine.ps1"
Invoke-SmartDiagnostic -Dimensions @("Disk") -OutputFormat Json | Out-File "disk-report.json"

# Run only the event log analyzer for the last 24 hours
Invoke-SmartDiagnostic -Dimensions @("EventLogs") -TimeWindow (Get-Date).AddDays(-1)

# Export security events to CSV (headless)
Import-Module ".\PRO\ProEngine.ps1"
Export-AuroraData -LogType Security -Format CSV -OutputPath ".\security-audit.csv" -TimeWindow 7
```

### Integrating with Scheduled Tasks

You can set up automated scans using Windows Task Scheduler:

1. Open **Task Scheduler** (`taskschd.msc`)
2. Create a new task with these settings:
   - **Trigger:** Weekly, or as desired
   - **Action:** Start a program → `powershell.exe`
   - **Arguments:**
     ```
     -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -Command "& 'C:\Tools\AURORA-Analyzer\Engines\SmartDiagnosticEngine.ps1'; Invoke-SmartDiagnostic -Dimensions All -OutputFormat Json | Out-File 'C:\AURORA-Reports\scan-$(Get-Date -Format yyyy-MM-dd).json'"
     ```
   - **Run with highest privileges:** ✅ Checked
3. The scan report will be saved to your specified output directory

### Custom Repair Scripts

The **Custom** repair type accepts any valid PowerShell. Here are some practical examples:

```powershell
# Example 1: Disable Cortana / web search
Get-AppxPackage *Microsoft.549981C3F2F10* | Remove-AppxPackage

# Example 2: Clear all event logs (useful before a fresh baseline)
wevtutil el | ForEach-Object { wevtutil cl "$_" }

# Example 3: Disable Xbox Game Bar
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f

# Example 4: Set DNS to Cloudflare
$adapter = Get-NetAdapter | Where-Object Status -eq "Up"
Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses ("1.1.1.1","1.0.0.1")
```

Each custom repair is automatically snapshotted and can be undone from Repair History.

---

## Troubleshooting Common Issues

### AURORA won't start at all

| Symptom | Likely Cause | Solution |
|---|---|---|
| Nothing happens when I double-click `AURORA-Launcher.exe` | Antivirus blocking execution | Check quarantine; add AURORA folder to exclusions; verify digital signature |
| "PowerShell execution policy" error | Restricted execution policy | Run `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force` as Admin |
| Splash screen appears then disappears | .NET Framework issue | Ensure .NET 4.6.2+ is installed: `Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"` |
| "This app can't run on your PC" | Running 32-bit Windows | AURORA requires x64 Windows |

### Startup hangs or crashes

| Symptom | Likely Cause | Solution |
|---|---|---|
| Hangs at "Loading Security Module..." | File integrity check failure | Re-extract ZIP; exclude AURORA folder from antivirus; verify checksums |
| Hangs at "Initializing UI..." | DPI or display issue | Try running at 100% DPI scaling; update graphics drivers |
| Memory error during startup | Insufficient RAM | Close other applications; switch to Eco mode in config.json |

### Diagnostic scan issues

| Symptom | Likely Cause | Solution |
|---|---|---|
| Scan stuck at "Event Logs" for > 3 minutes | Very large event logs | Cancel and re-run with Event Logs dimension unchecked; clear old logs |
| "Access Denied" on certain dimensions | Not running as Administrator | Re-launch as Administrator |
| Scan completes but shows no findings (all green) on a known-bad system | Event logs empty or cleared | Check if event logs were recently cleared; run `wevtutil el` to verify |

### Repair issues

| Symptom | Likely Cause | Solution |
|---|---|---|
| "Snapshot creation failed" | System Restore is disabled | Enable System Restore: `Enable-ComputerRestore -Drive "C:\"` |
| Repair seems to have no effect | Policy overriding the setting | Check Group Policy (gpedit.msc) — domain policies may override local changes |
| Undo failed | Snapshot data corrupted | Try System Restore manually: `rstrui.exe` |

### PRO Mode issues

| Symptom | Likely Cause | Solution |
|---|---|---|
| Export takes a very long time | Huge event logs without filters | Apply date range and severity filters to reduce scope |
| "Export failed" with no details | Disk full or path permissions issue | Check disk space; verify output path is writable |
| Trend chart is blank | No data matches filter criteria | Broaden filters; verify time range contains events |

---

## FAQ

### Startup & Installation

**Q: AURORA won't start — I get a PowerShell execution policy error.**

A: AURORA requires the execution policy to be at least `RemoteSigned`. Run this command as Administrator and try again:
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
```

**Q: The splash screen hangs at "Loading Security Module...".**

A: This usually indicates a file integrity check failure. Ensure all files are extracted from the ZIP (not run from within it) and that no antivirus software has quarantined any `.ps1` files. Add the AURORA folder to your antivirus exclusion list if the issue persists.

**Q: Do I need to install anything before using AURORA?**

A: No. AURORA is fully portable — just extract and run. The only prerequisites are PowerShell 5.1 and .NET Framework 4.6.2+, both of which ship with Windows 10 1809+.

**Q: Can I run AURORA from a USB drive?**

A: Yes! AURORA is fully portable. You can run it from any location, including external drives. Note that session data is still stored in `%APPDATA%\AURORA-Analyzer\` on the host machine, not on the USB drive.

---

### Smart Diagnostic

**Q: How long does a full diagnostic scan take?**

A: Typically 30–90 seconds on modern hardware. On older systems or machines with very large event logs, it can take up to 3 minutes. You can skip the Event Logs dimension for a faster scan (~20–45 seconds).

**Q: Will the diagnostic scan slow down my computer?**

A: AURORA runs at low process priority by default. You can continue using your computer normally during a scan. On very low-end hardware, you may notice a slight performance dip — switch to Eco mode before scanning if this is a concern.

**Q: Can I schedule automatic scans?**

A: Not yet through the GUI, but you can use Windows Task Scheduler with AURORA's modular engine (see [Advanced Usage](#advanced-usage)). Full scheduled-scan support is planned for a future release.

**Q: What do the severity levels mean?**

A:
- **Info (🟢):** An informational finding — nothing is wrong, but you might want to know about it (e.g., "Your system drive has 45% free space — no action needed")
- **Warning (🟡):** A potential issue that isn't critical now but could become problematic if left unaddressed (e.g., "System drive has 12% free space — consider cleaning up soon")
- **Critical (🔴):** An active issue likely impacting system stability, security, or performance — should be addressed promptly (e.g., "SMART reports imminent disk failure — back up your data immediately")

**Q: Can diagnostic results be exported?**

A: Yes! Switch to PRO Mode after a diagnostic scan and export the full findings as CSV, JSON, or XML. The export includes all finding details, severity ratings, knowledge-graph references, and suggested fixes.

---

### Repair Toolkit

**Q: Is it safe to use the repair tools?**

A: Yes. Every repair creates both a Windows System Restore Point and an AURORA Fast Snapshot before making any changes. If anything goes wrong, you can undo with a single click. As a best practice, back up important data before using any system tool for the first time.

**Q: What happens if I restart while a repair is in progress?**

A: AURORA detects incomplete repairs on next launch and automatically rolls them back to the pre-repair state. You'll see a notification explaining what happened, and you can re-apply the repair if desired.

**Q: Why does ResetNetwork disconnect my internet?**

A: The network reset clears your DNS cache, renews your DHCP lease, and resets the Winsock catalog and Windows Firewall. Temporary disconnection (30–60 seconds) is normal. If connectivity doesn't return, reboot your computer.

**Q: Can I create my own custom repair scripts?**

A: Yes! The **Custom** repair type accepts any PowerShell script or command. AURORA creates a full snapshot before execution and captures all output. See the [Advanced Usage](#advanced-usage) section for examples.

**Q: Does CleanSystem delete my personal files?**

A: No. CleanSystem targets only temporary and cached files: Windows temp folders, update caches, prefetch, recycle bin, browser caches, and thumbnails. Your documents, photos, and personal files are never touched.

---

### PRO Mode

**Q: What's the difference between Smart Diagnostic and PRO Mode?**

A: Smart Diagnostic is **guided and automated** — it scans, diagnoses, and suggests fixes. PRO Mode gives you **manual control** — you choose exactly what to export, in what format, and how to visualize it. Smart Diagnostic is for diagnosis; PRO Mode is for analysis and reporting.

**Q: Can PRO Mode exports be opened in Excel?**

A: Yes. CSV exports open directly in Excel, Google Sheets, or LibreOffice Calc. JSON exports work with Power BI, Python (pandas), R, and other data analysis tools.

**Q: How large can PRO exports get?**

A: No hard limit, but very large event logs (hundreds of thousands of entries) can produce multi-gigabyte export files. Use filters to narrow the scope. A typical week of events from a healthy system exports to about 5–20 MB in CSV format.

**Q: Can I compare two exports to see what changed?**

A: Yes! PRO Mode's **Compare Mode** loads a previous export as a baseline. The comparison report highlights new events, resolved events, and changes in event frequency patterns.

---

### Language & Localization

**Q: How do I change the language manually?**

A: Go to **Settings → Language** and select **English** or **中文（简体）**. The change takes effect immediately — no restart needed.

**Q: The auto-detection picked the wrong language.**

A: Auto-detection uses your Windows display language (`en-US`, `zh-CN`, etc.). You can manually override it in Settings. If your locale is consistently misdetected, please report it as a bug.

**Q: Are other languages planned?**

A: Currently English and Simplified Chinese are supported. Additional languages are under consideration for future releases based on user demand.

---

### Version & Updates

**Q: How do I know if I have the latest version?**

A: Open AURORA and go to **Help → About**. The version number and build date are displayed. Compare with the latest release on our official channels.

**Q: Can I upgrade without losing my settings?**

A: Yes. Your configuration and session data are in `%APPDATA%\AURORA-Analyzer\`, separate from the app directory. Extract the new version over the old files — your settings, repair history, and saved sessions are preserved.

**Q: I'm on an older version — should I upgrade?**

A: **Strongly yes.** V1.3.26.5 contains critical security fixes (P0 elevation token bug), major stability improvements (P0 watchdog fixes, P1 session corruption fix), and significant performance gains (-33% startup time, -19% memory). See the [Update Highlights](#v13265-update-highlights) for the full list.

---

### Privacy & Security

**Q: Does AURORA collect or send any data?**

A: **No.** AURORA Analyzer operates entirely offline. It makes zero outbound network connections. No telemetry, usage data, or diagnostic results are ever collected or transmitted. You can verify this with any network monitoring tool.

**Q: Is AURORA compatible with my antivirus?**

A: Yes, but some antivirus programs may flag AURORA's self-integrity checks or Runtime Guardian as suspicious (false positive). Add the AURORA folder to your AV exclusion list. Use the SHA-256 checksums to verify the files haven't actually been tampered with.

**Q: Can I use AURORA on Windows Server Core (no GUI)?**

A: The full GUI requires a desktop environment. However, individual engine modules can be called directly from PowerShell. See the [Advanced Usage](#advanced-usage) section for headless operation.

**Q: Does AURORA need internet access?**

A: No. AURORA works completely offline. No features require internet connectivity. This also means AURORA cannot automatically check for updates — you'll need to check our official channels manually.

---

### Other

**Q: My question isn't listed here.**

A: Check the official documentation or reach out through our support channels. When reporting issues, include:
- AURORA version (from Help → About)
- Windows version (run `winver`)
- A clear description of the problem
- Log files from `%APPDATA%\AURORA-Analyzer\logs\` if available

**Q: Can AURORA run alongside other diagnostic tools?**

A: Yes. AURORA is designed to coexist with other tools. It does not modify system state unless you explicitly apply a repair. Running multiple diagnostic tools simultaneously is fine — just avoid running multiple repair operations at the same time.

**Q: Uninstalling — how do I completely remove AURORA?**

A: Since AURORA is portable:
1. Delete the AURORA application folder
2. Delete `%APPDATA%\AURORA-Analyzer\` (contains config, sessions, logs)
3. That's it — no registry entries, no services, no uninstaller needed

---

## Data Storage & Privacy

AURORA Analyzer is built with a **privacy-first** philosophy. Here's exactly where data is stored and what it contains:

### Application Directory (portable)

| Location | Contents |
|---|---|
| `{AURORA folder}\*.ps1` | All application code |
| `{AURORA folder}\*.dll` | C# compiled assemblies |
| `{AURORA folder}\AURORA-Launcher.exe` | Signed launcher |
| `{AURORA folder}\checksums.sha256` | File integrity reference hashes |
| `{AURORA folder}\verify.ps1` | Manual verification script |

### User Data Directory (`%APPDATA%\AURORA-Analyzer\`)

| File/Folder | Contents | Contains Personal Data? |
|---|---|---|
| `config.json` | Language, performance tier, session expiry, master password hash | Only hashed password (if enabled) |
| `sessions\` | Scan results, diagnosis findings, repair history, export job records | **Yes** — system configuration and event log excerpts |
| `snapshots\` | Repair undo snapshots (registry keys, service states) | **Yes** — system configuration data |
| `exports\` | PRO Mode export files (CSV/JSON/XML) | **Yes** — exported event log and system data |
| `logs\` | Application log files | Minimal — operational logs only |
| `repair-log.json` | Repair audit trail (timestamp, type, success/fail) | No personal data |

### What AURORA NEVER Does

- ❌ Never makes network connections of any kind
- ❌ Never sends telemetry, analytics, or usage data
- ❌ Never reads or accesses your personal documents, photos, or files (only system locations)
- ❌ Never modifies system state without your explicit confirmation
- ❌ Never installs services, drivers, or background processes (Runtime Guardian runs only while AURORA is open)
- ❌ Never collects or transmits diagnostic results

---

## Legal & Credits

**AURORA Analyzer** is proprietary software. All rights reserved.

- **Engine:** PowerShell 5.1 + C# (.NET Framework 4.x)
- **UI Framework:** Windows Forms (WinForms) with custom-drawn controls
- **Platform:** Windows 10 1809+ / Windows 11 / Windows Server 2019+

This software is provided "as is" without warranty of any kind, express or implied. While every effort has been made to ensure safe and reliable operation, the authors assume no liability for data loss, system damage, or any other consequences arising from the use of this software. Always back up important data before using any system repair tools.

---

> **"See what your system has been hiding."**
> — The AURORA Team, June 2026