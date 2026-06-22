# AURORA Analyzer V1.3.26.7 Release — User Manual

> **Version**: V1.3.26.7 Release
> **Build Date**: 2026.06.16
> **Codename**: Comprehensive Quality Release
> **Supported Platforms**: Windows 10 1809+ / Windows 11 / Windows Server 2019+
> **Technical Architecture**: PowerShell 5.1 + .NET Framework 4.x + C# Hybrid

---

## Table of Contents

- [Quick Start](#quick-start)
- [Core Features](#core-features)
- [V1.3.26.7 Highlights](#v13267-highlights)
- [System Requirements](#system-requirements)
- [User Guide](#user-guide)
- [Performance Modes](#performance-modes)
- [Security Mechanisms](#security-mechanisms)
- [Frequently Asked Questions](#frequently-asked-questions)
- [Version History](#version-history)
- [Disclaimer](#disclaimer)

---

## Quick Start

### First Time User?

1. **Double-click** `AURORA-Analyzer.exe`
2. The tool automatically completes security verification and hardware performance detection
3. Wait for the splash screen to load (approximately 3-8 seconds, depending on your hardware)
4. Select the feature you need from the main interface

### Feature Overview

| Feature | Description | For |
|---------|-------------|-----|
| **Smart Diagnosis** | One-click system scan, knowledge graph-powered intelligent diagnosis, automatic repair suggestions and risk assessment | All users |
| **PRO Graphical Mode** | Professional visual log export and analysis tool with multi-dimensional data display | Advanced users / System administrators |
| **System Repair Toolkit** | Multiple repair tools with one-click undo (System Restore + quick backup snapshots) | All users |
| **Session Resume** | Progress persistence — resume from interruption point after unexpected termination | All users |
| **Console Mode** | Command-line quick diagnosis, lightweight and efficient, suitable for script integration | Developers / IT operations |

---

## Core Features

### Smart Diagnosis Mode

AURORA Analyzer's knowledge graph-driven smart diagnosis engine covers the following dimensions in a single scan:

- **System File Integrity** — Enhanced SFC/DISM-based verification
- **Service Status Analysis** — Key Windows service running status and anomaly detection
- **Registry Health** — Critical registry key integrity checks
- **Disk Space & I/O** — Space usage, fragmentation, read/write latency evaluation
- **Memory & CPU Status** — Real-time resource usage and abnormal process detection
- **Network Configuration** — DNS, IP, proxy, firewall rule health checks
- **Event Log Analysis** — Windows event log export, aggregation, and trend analysis

After diagnosis, the system generates a structured report categorized by severity (Critical / Warning / Information) with one-click repair entry points.

### PRO Graphical Mode

PRO mode provides professional-grade visual analysis for advanced users and system administrators:

- **Event Log Visual Export** — CSV / JSON / XML multi-format export
- **Trend Analysis Charts** — Time-series trend analysis with auto-generated trend data
- **Summary Reports** — Intelligent log summaries and key metric aggregation
- **Multi-Source Log Comparison** — Simultaneous analysis of system logs, application logs, and more
- **Interactive Filtering** — Flexible filtering by event level, source, and time range

### System Repair Toolkit

Built-in repair tools covering common Windows problem scenarios:

| Repair Tool | Description | Undo Support |
|-------------|-------------|-------------|
| Enhanced SFC | System file check and repair with automatic repair source | ✅ System Restore |
| DISM Image Repair | Windows image component store repair | ✅ System Restore |
| Disk Error Repair | Enhanced CHKDSK, deep disk scanning | ✅ Snapshot backup |
| Network Config Reset | Reset TCP/IP, Winsock, DNS cache | ✅ Config snapshot |
| Windows Update Fix | Clear update cache, reset update components | ✅ Service state snapshot |
| Storage Sense Optimization | Clean temp files, recycle bin, thumbnail cache | ✅ File list snapshot |
| Registry Repair | Critical registry key validation and repair | ✅ Registry backup |
| Power Plan Optimization | Detect and fix power configuration anomalies | ✅ Config snapshot |

**Before each repair operation, the tool automatically creates protection points**, including a System Restore point (via Windows System Protection) and a quick backup snapshot (tool-managed). If the system experiences issues after repair, you can **undo with one click**.

### Session Resume

- If a diagnosis/repair session is unexpectedly interrupted (power loss, crash, accidental close), the tool automatically detects incomplete sessions on next launch
- A session restore dialog shows the session phase, progress percentage, and days since interruption
- Choose to continue from the interruption point or abandon the session and start fresh
- Progress data is persisted to disk and survives restarts

---

## V1.3.26.7 Highlights

### Overview

V1.3.26.7 is a **quality-centric comprehensive fix release**. Built on top of the architectural refactoring and quality foundation completed in V1.3.26.6, this version conducts a deep review of all core modules and addresses 53 issues affecting functional correctness, security, and stability — including 18 Critical-level and 35 High-level problems.

In simple terms: **previous versions had complete functionality; V1.3.26.7 makes that functionality truly reliable.**

---

### 1. Integrity Monitoring Fully Restored

In previous versions, the file integrity monitoring feature was effectively non-functional. The root cause was that .NET's file watcher does not support comma-separated file extension patterns, meaning no files matched the filter. V1.3.26.7 replaces the event-based watcher with a more reliable timer-polling approach, adding a 64KB buffer and concurrent lock protection to ensure stable and accurate monitoring under high-frequency file operations.

---

### 2. Registry Restoration Fixed

A critical defect existed in the registry undo operation — when executing registry restoration, a missing parameter prevented the program from obtaining the actual execution result. This means the registry restoration feature never worked correctly. After the fix, restoration results are now properly obtained and validated, and the registry restoration feature functions as intended.

---

### 3. Custom Repair Security Hardening

The custom repair mode previously had a code injection risk — attackers could execute arbitrary code by crafting malicious commands. V1.3.26.7 introduces a command whitelist mechanism, currently supporting six safe operations: clearing event logs, resetting the network stack, flushing DNS cache, repairing system files, cleaning temporary files, and resetting Windows Store. Commands outside the whitelist are rejected, fundamentally eliminating code injection risk.

---

### 4. PRO Mode Parameter Passing Fixed

In previous versions, user selections made in the GUI — language, log type, time range — were not correctly passed to the PRO engine, causing it to always run with default values. This means user choices were effectively ignored. After the fix, all user settings are now correctly passed to the PRO engine, and language switching, log filtering, and other features work as expected.

---

### 5. Health Level Text Multi-Language Support

The PRO mode health assessment feature previously had level texts like "Excellent", "Good", "Fair", "Poor" and their status descriptions hardcoded in Chinese. In English mode, users still saw Chinese health level text. V1.3.26.7 moves all these texts to the language resource file, and health level text now correctly follows the language setting.

---

### 6. Log Output Restored

In previous versions, the smart engine's log output during execution was completely non-functional due to a parameter error — users saw a blank log area in the GUI. After the fix, all diagnosis and repair process logs now display normally, allowing users to monitor execution status in real time.

---

### 7. Session Data Security Enhanced

The "atomic write" mechanism for session saving previously had a data loss risk — if the program crashed during saving, session data could be permanently corrupted. V1.3.26.7 adopts a more reliable atomic replacement approach with retry logic and backup suffix support, ensuring session data is never lost under any circumstances.

---

### 8. Resource Cleanup Comprehensively Enhanced

In previous versions, if the program exited urgently due to security events, some system resources (timers, file monitors, background processes) cleanup code was skipped, potentially causing resource leaks. V1.3.26.7 adds complete resource cleanup logic to all exit paths, ensuring all resources are properly released regardless of how the program exits.

---

### 9. Multiple Runtime Exception Fixes

Fixed several runtime crashes caused by undefined variables, including: knowledge graph cache hit path crash, strict mode variable initialization errors, and elevation dialog drag functionality failure. These issues caused abnormal program exits in specific scenarios; after the fixes, the program runs more stably.

---

## System Requirements

| Item | Minimum | Recommended |
|------|---------|-------------|
| **Operating System** | Windows 10 1809+ | Windows 11 22H2+ |
| **Server OS** | Windows Server 2019+ | Windows Server 2022+ |
| **Processor** | Dual-core 1.5 GHz | Quad-core 2.5 GHz+ |
| **Memory** | 4 GB | 8 GB+ |
| **Architecture** | x64 (required) | x64 |
| **Disk Space** | 200 MB free | 500 MB+ (including log storage) |
| **.NET Framework** | 4.x (4.6.1 minimum) | 4.8 |
| **PowerShell** | 5.1 | 5.1 |
| **Administrator Rights** | Required for some features | Recommended to run as administrator |

### Unsupported Environments

- ❌ 32-bit (x86) systems
- ❌ Windows 7 / 8 / 8.1
- ❌ Windows 10 LTSC 2015 (1507) and earlier
- ❌ PowerShell 5.0 and below
- ❌ .NET Framework 4.5 and below
- ❌ ARM architecture (ARM64 Surface Pro X etc., untested)

---

## User Guide

### Starting the Tool

#### Method 1: Graphical Launch (Recommended)

Double-click `AURORA-Analyzer.exe`. The tool automatically completes security integrity verification, hardware performance detection, displays the splash screen, and enters the main interface.

#### Method 2: Console Launch

For developers or script integration scenarios:

```powershell
# Standard launch
.\Scripts\AURORA-AnalyzerLauncherGUI.ps1

# Console mode (no GUI)
.\Scripts\AURORA-AnalyzerLauncherGUI.ps1 -Console

# Launch with specific language
.\Scripts\AURORA-AnalyzerLauncherGUI.ps1 -Language "en-US"

# Skip splash screen
.\Scripts\AURORA-AnalyzerLauncherGUI.ps1 -NoSplash
```

---

### Smart Diagnosis Mode

1. Launch the tool and click **"Smart Diagnosis"** on the main interface
2. Select the diagnosis scope (full system scan / system files only / registry only / custom)
3. The tool begins automatic scanning with real-time progress display
4. Scan covers: system file integrity, service status, registry health, disk I/O, memory & CPU, network configuration, and event logs
5. After scanning, view the diagnosis report:
   - 🔴 **Critical** — Immediate action required
   - 🟡 **Warning** — Recommended to address
   - 🔵 **Information** — For reference only
6. Select items to repair and click **"One-Click Repair"**
7. The tool creates protection points automatically before executing repairs

---

### PRO Graphical Mode

PRO mode is designed for advanced users and system administrators:

1. Click **"PRO Graphical Mode"** on the main interface
2. Select log sources: System, Application, Security (requires admin rights)
3. Set filter criteria: time range, event level, event ID filter, source filter
4. Click **"Start Analysis"**
5. View results: summary panel, trend charts, event list
6. Export results: CSV / JSON / XML / TXT summary

---

### System Repair Toolkit

#### Executing Repairs

1. Select **"System Repair"** on the main interface
2. Browse available repair tools
3. Select needed tools (multiple selection supported)
4. Click **"Execute Repair"**
5. The tool creates protection points automatically
6. Wait for repair completion
7. View the repair result report

#### Undoing Repairs

If the system experiences issues after repair:

1. Open the tool and navigate to **"Repair History"** or **"Undo Management"**
2. Find the repair operation to undo
3. Click **"Undo"**
4. The tool restores system state from the protection point
5. Restart the system if required

---

### Session Resume

#### Automatic Session Saving

The tool automatically saves progress during diagnosis/repair. After each step, progress data is written to disk in the tool's data directory.

#### Resuming Interrupted Sessions

1. If the tool closes unexpectedly (crash, power loss, force quit)
2. Restart the tool
3. The tool automatically detects incomplete sessions
4. A **"Session Restore"** dialog appears, showing session phase, progress percentage, and days since interruption
5. Choose **"Continue"** to resume from the interruption point, or **"Abandon"** to discard and start fresh

---

### Console Mode

Console mode is suitable for developers needing quick diagnosis without loading the GUI:

```powershell
# Launch console mode
.\Scripts\AURORA-AnalyzerLauncherGUI.ps1 -Console

# Quick system scan
.\Scripts\AURORA-AnalyzerLauncherGUI.ps1 -Console -ScanOnly

# Export system event logs
.\Scripts\AURORA-AnalyzerLauncherGUI.ps1 -Console -ExportLogs -LogType System -Days 7
```

Console mode outputs plain text results, suitable for automation scripts or remote management workflows.

---

## Performance Modes

The tool automatically selects a performance mode based on your hardware, or you can adjust it manually:

| Mode | Suitable For | Effects | Description |
|------|-------------|---------|-------------|
| **Extreme** | High-end (i7/R7+, 16GB+, dedicated GPU) | Full effects | Complete starfield, particle effects, full-frame-rate animations |
| **Performance** | Mid-high (i5/R5+, 8GB+) | High effects | Optimized starfield, partial particle effects |
| **Balanced** | Mid-range (i3/R3+, 6GB+) | Medium effects | Moderate visual effects |
| **Eco** | Low-end / VMs | Minimal effects | Halved frame rate, no particles, lowest CPU usage |

### Manual Performance Mode Setting

Set the `AURORA_PERF_TIER` environment variable:

```powershell
# Temporary (current session only)
$env:AURORA_PERF_TIER = "Eco"

# Permanent (system-wide)
[System.Environment]::SetEnvironmentVariable("AURORA_PERF_TIER", "Eco", "Machine")
```

Valid values: `Eco` / `Balanced` / `Performance` / `Extreme`

---

## Security Mechanisms

AURORA Analyzer employs multi-layer security protection to prevent tampering and malicious exploitation:

### Layer 1: Startup Verification

On startup, all core module files undergo RSA-2048 signature verification, comparing against hashes recorded in the encrypted signature database. Any file modification, replacement, or corruption causes verification failure and the tool refuses to launch. V1.3.26.7 also adds the security module itself to the integrity monitoring scope, further strengthening the security chain.

### Layer 2: Runtime Guard

During operation, the tool continuously monitors the process space for common debuggers and reverse engineering tools, detects memory tampering and code injection, and maintains heartbeat communication with an external watchdog process.

### Layer 3: Operation Safety

Before each repair operation, protection points are automatically created (System Restore point + quick backup snapshot). The undo manager tracks all modifications and supports precise rollback. V1.3.26.7 enhances backup information association in the undo function to ensure snapshot IDs are never lost.

### Layer 4: Elevation Security

During administrator elevation, tokens are strictly isolated and immediately cleaned up after elevation completes. V1.3.26.7 also fixes the code injection vulnerability in custom repair mode with a command whitelist mechanism.

---

## Frequently Asked Questions

### Startup & Operation

<details>
<summary><b>Q: The tool crashes immediately after startup?</b></summary>

**A:** The most common cause is security verification failure. Please check:
- Are you using the officially built EXE file?
- Have any `.ps1` files in the `Scripts/` directory been modified?
- Are any debuggers or reverse engineering tools running?
- Has antivirus software mistakenly blocked the watchdog process? (Try adding an exclusion)

If the issue persists, check the build log for error details.
</details>

<details>
<summary><b>Q: How do I upgrade from V1.3.26.6 to V1.3.26.7?</b></summary>

**A:** **Simply replace all files.** Upgrade steps:
1. Back up the `UserLogs/` directory (if you need to keep historical logs)
2. Delete all old version files
3. Extract all V1.3.26.7 files to the same directory
4. If you kept old logs, put them back in `UserLogs/`
5. Launch the tool
</details>

### Smart Diagnosis

<details>
<summary><b>Q: Smart diagnosis scanning is slow?</b></summary>

**A:** Full system scan time depends on disk type (SSD ~2-5 minutes, HDD ~5-15 minutes), event log size, and number of installed applications. You can speed up by narrowing the scan scope.
</details>

<details>
<summary><b>Q: In previous versions, the log area was blank. Is it normal in V1.3.26.7?</b></summary>

**A:** Yes, it's now fixed. V1.3.26.7 resolved the log output failure — all logs from the smart engine now display correctly in the GUI log area.
</details>

### System Repair

<details>
<summary><b>Q: What if the system has issues after repair?</b></summary>

**A:** The tool has a comprehensive undo mechanism:
1. Reopen AURORA Analyzer
2. Navigate to **"Repair History"** or **"Undo Management"**
3. Find the problematic repair operation
4. Click **"Undo"**
5. The tool restores system state from the protection point

If you cannot launch the tool, use Windows System Restore from Safe Mode to revert to the pre-repair restore point.
</details>

<details>
<summary><b>Q: What commands are supported in Custom Repair?</b></summary>

**A:** For security reasons, V1.3.26.7's custom repair mode uses a command whitelist, currently supporting: clear event logs, reset network stack, flush DNS cache, repair system files, clean temporary files, and reset Windows Store. Contact the development team for additional operations.
</details>

### PRO Mode

<details>
<summary><b>Q: What's the difference between PRO Mode and Smart Diagnosis?</b></summary>

**A:** Smart Diagnosis is an automated diagnostic tool that analyzes system health and provides repair suggestions. PRO Mode is a professional-grade event log analysis tool focused on data visualization and export. They complement each other: Smart Diagnosis finds problems, PRO Mode digs deeper into log root causes.
</details>

<details>
<summary><b>Q: In previous versions, PRO Mode language/time range settings didn't work. What about now?</b></summary>

**A:** This is fixed in V1.3.26.7. User selections for language, log type, time range, etc. are now correctly passed to the PRO engine and work as expected.
</details>

### Other

<details>
<summary><b>Q: Does the tool collect my data?</b></summary>

**A:** **No.** AURORA Analyzer is a purely local tool. All diagnostic data and log analysis results are stored on your local disk. The tool contains no network reporting, telemetry, or data collection functionality.
</details>

<details>
<summary><b>Q: How do I report a bug?</b></summary>

**A:** Please provide: tool version (visible in the "About" section), Windows version (run `winver`), error logs from the build log, and reproduction steps. Submit this information through the project's issue channel.
</details>

---

## Version History

| Version | Date | Codename | Key Updates |
|---------|------|----------|-------------|
| **V1.3.26.7** | 2026.06.16 | Comprehensive Quality Release | 53 fixes: integrity monitoring, registry restoration, PRO parameter passing, code injection prevention, atomic write, log output restoration |
| V1.3.26.6 | 2026.06.08 | Architectural Quality Polish | Error handling convention, Timer lifecycle management, safe exit mechanism, structured telemetry |
| V1.3.26.5 | 2026.06.08 | Complete Architectural Decoupling | Modular architecture refactoring, 9 layers / 25 files, security module independence, view separation |
| V1.2.25.0 | 2026.06.02 | GUI Animation Overhaul | Ripple feedback, magnetic buttons, smooth progress bar, easing library expanded to 20 curves |
| V1.1.24.5 | 2026.05 | Starlight | Starfield background, light sweep animation, particle progress bar |
| V1.0.0.0 | Early 2026 | First Light | Initial release: smart diagnosis + basic repair features |

---

## Technical Information

| Item | Details |
|------|---------|
| **Project Name** | AURORA Analyzer |
| **Version** | 1.3.26.7 |
| **Build Date** | 2026-06-16 |
| **Codename** | Comprehensive Quality Release |
| **Main Launcher** | `Scripts/AURORA-AnalyzerLauncherGUI.ps1` |
| **Executable** | `AURORA-Analyzer.exe` |
| **Module Files** | 25 (excluding test tools) |
| **Programming Languages** | PowerShell 5.1 + C# (.NET Framework 4.x) |
| **Architecture** | x64 only |
| **Security Verification** | RSA-2048 signature + SHA-256 hash verification |
| **Animation Effects** | Ripple feedback, magnetic buttons, particle progress bar, starfield, light sweep |
| **Output Formats** | CSV / JSON / XML / TXT |
| **Language Support** | Simplified Chinese / English (runtime switching) |

---

## Data Storage

The tool stores data in the following locations:

| Directory | Purpose | Safe to Delete? |
|-----------|---------|-----------------|
| `UserLogs/` | Exported log files and analysis reports | ✅ Yes |
| `Data/` | Technical data cache, diagnostic knowledge graph | ⚠️ Tool will need to rebuild cache |
| `GAURORA.CHK.ENC` | File integrity verification database | ❌ No (security verification will fail) |
| `build.log` | Build and launch logs | ✅ Yes |
| `SessionCache/` | Session progress data | ⚠️ Incomplete sessions will be unrecoverable |

---

## Disclaimer

This tool is provided "AS IS" without any express or implied warranties.

**Before using this tool, please note:**

1. System repair operations may affect system stability. **It is strongly recommended to back up important data before performing any repairs.**
2. The tool's built-in undo mechanism is effective in most cases but cannot guarantee 100% recovery of all modifications.
3. The author is not responsible for any direct or indirect damages resulting from the use or inability to use this tool.
4. Event logs exported by PRO Mode may contain sensitive information (e.g., usernames, IP addresses). Please be mindful of privacy when sharing exported files.
5. This tool is for legitimate purposes only. Do not use on systems without authorization.

By using this tool, you acknowledge that you have read and agree to these terms.

---

## Acknowledgments

Thank you to all users who have provided feedback, reported bugs, and suggested features. Your support drives AURORA Analyzer's continuous improvement.

---

*AURORA VelociRaptor-GR Dev PRJ.*
*V1.3.26.7 Release — 2026.06.16 — Comprehensive Quality Release*