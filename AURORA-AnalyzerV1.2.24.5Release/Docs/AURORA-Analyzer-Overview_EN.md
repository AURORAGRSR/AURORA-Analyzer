# AURORA Analyzer — Complete Feature Overview

> **Version**: V1.2.24.5Release
> **Build Date**: 2026.06.01
> **Project Codename**: AURORA VelociRaptor-GR Dev PRJ.
> **Document Type**: Complete feature overview (for all audiences)

---

## Table of Contents

- [1. Project Introduction](#1-project-introduction)
- [2. Architecture Overview](#2-architecture-overview)
- [3. Three Operating Modes](#3-three-operating-modes)
- [4. Feature Module Details](#4-feature-module-details)
  - [4.1 Log Export System](#41-log-export-system)
  - [4.2 Intelligent Diagnostics Engine](#42-intelligent-diagnostics-engine)
  - [4.3 System Repair Toolkit](#43-system-repair-toolkit)
  - [4.4 Undo & Restore System](#44-undo--restore-system)
  - [4.5 Progress Management & Resume](#45-progress-management--resume)
- [5. Security Architecture](#5-security-architecture)
- [6. Technical Specifications](#6-technical-specifications)
- [7. Build & Deployment](#7-build--deployment)
- [8. File Inventory](#8-file-inventory)

---

## 1. Project Introduction

**AURORA Analyzer** is an advanced Windows system diagnostics and log analysis tool. It enables you to:

- 📊 **Automatically export** Windows Event Logs to CSV / JSON / XML / TXT formats
- 🔍 **Intelligently diagnose** system stability issues, performance bottlenecks, network anomalies, security vulnerabilities, and hardware failures
- 🔧 **One-click repair** of Windows Update, Defender, network stack, system files, and other common issues
- ↩️ **Safely roll back** with auto-backup before every repair, supporting registry/file/service-level precise undo
- 🛡️ **Defense-in-depth** with full lifecycle security protection from build to runtime

### Core Design Principles

| Principle | Implementation |
|-----------|---------------|
| **Zero Dependencies** | Pure PowerShell + embedded C#, no third-party runtime required |
| **Local Security** | All data processed locally, no internet connection, no data uploads |
| **Tamper-Proof** | RSA signature + SHA256 integrity verification + HMAC watchdog bidirectional heartbeat |
| **Reversible Operations** | Auto-snapshot before every repair, three-tier rollback (registry/file/service) |

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────┐
│              AURORA-Analyzer.exe                 │
│         (C# EXE Loader / Watchdog Server)         │
│  · RSA Token Generation  · Named Pipe IPC       │
│  · Process Lifecycle Management                  │
└────────────────────┬────────────────────────────┘
                     │ Env var injection + Named Pipe
┌────────────────────▼────────────────────────────┐
│       AURORA-AnalyzerLauncherGUI.ps1             │
│    (PowerShell GUI Launcher + Security Core)      │
│  · Language selection  · Mode selection          │
│  · AuroraGuard runtime sentinel                  │
│  · Performance tiering  · Watchdog client        │
│  · Exit handler                                   │
└────────────────────┬────────────────────────────┘
                     │ Dot-sourcing
     ┌───────────────┼───────────────┐
     ▼               ▼               ▼
┌─────────┐  ┌──────────┐  ┌──────────────┐
│  Smart   │  │   Pro    │  │   Console    │
│  Mode    │  │ GUI Mode │  │     Mode     │
└────┬────┘  └────┬─────┘  └──────┬───────┘
     │            │               │
     └────────────┼───────────────┘
                  ▼
┌─────────────────────────────────────────────────┐
│            16 Core Engine Scripts                │
│  · SmartEngine  · CoreEngine  · RepairTools      │
│  · UndoManager  · RestoreManager  · RepairLogger │
│  · ProgressManager  · AnimationCoreEngine  · GUI │
│  · CHS/ENG Pro Engines  · UndoViewer             │
│  · All files protected by SHA256 integrity hash  │
└─────────────────────────────────────────────────┘
```

---

## 3. Three Operating Modes

Upon launch, AURORA Analyzer first prompts for language selection (Chinese / English), then offers three operating modes:

### 3.1 Smart Diagnostic & Auto-Repair Mode

**Use Case**: Quick troubleshooting with automated diagnosis and repair

Launches `AURORA-SmartEngine.ps1`, executing a fully automated workflow:

1. Scan system logs, matching patterns from the knowledge base
2. Automatically analyze Blue Screen Minidump files
3. Generate diagnostic reports with repair recommendations
4. Execute auto-repair upon user confirmation

**Characteristics**: No manual operation needed; ideal for general users seeking fast solutions.

### 3.2 Professional GUI Mode

**Use Case**: Professional users requiring granular control over each function

Launches `AURORA-AnalyzerCHSPRO.ps1` or `AURORA-AnalyzerENGPRO.ps1`, providing a complete graphical interface with:

- Log Export Panel (filter by type/time/level/event ID)
- Intelligent Diagnostics Panel (5 categories with knowledge base rule matching)
- System Repair Panel (5 repair types + custom repair)
- Undo/Restore Panel (history viewer + precise rollback)
- Progress Management Panel (session list + resume)

**Characteristics**: The most comprehensive mode; ideal for professional IT administrators.

### 3.3 Console Mode

**Use Case**: Scripted operations, remote management, automation integration

Runs within a PowerShell console, suitable for:

- Batch processing logs across multiple computers
- Integration into automated operations scripts
- Low-resource environments

**Characteristics**: Lightweight, scriptable; ideal for advanced users.

---

## 4. Feature Module Details

### 4.1 Log Export System

**Engine**: `AURORA-AnalyzerCHSPRO.ps1` / `AURORA-AnalyzerENGPRO.ps1`

#### Supported Event Log Types

| Log Type | Windows Log Name | Typical Use |
|----------|-----------------|-------------|
| System Log | System | Diagnose driver errors, service crashes, kernel events |
| Application Log | Application | Diagnose software crashes, install failures, .NET errors |
| Security Log | Security | Audit logins, permission changes, security policies |
| Setup Log | Setup | Diagnose software install/uninstall failures, Windows Update |
| Forwarded Events | ForwardedEvents | Centralized multi-computer event log management |

#### Filtering & Export Options

| Feature | Description |
|---------|-------------|
| Time Range Filter | Select start and end dates, precise to the minute |
| Level Filter | Critical, Error, Warning, Information, Verbose |
| Event ID Filter | Exact match for specific event IDs (e.g., BSOD event 1001) |
| Source Filter | Filter by service name or driver name |
| Keyword Search | Search keywords within log message content |
| Max Entry Limit | Control export file size |

#### Export Formats

| Format | Characteristics | Recommended For |
|--------|----------------|-----------------|
| **CSV** | Excel/WPS compatible, easy to sort and filter | Self-analysis, sharing with colleagues |
| **JSON** | Structured data, programmatically processable | Developers, automation tool integration |
| **XML** | Full Windows event format, preserves all fields | Submission to Microsoft support |
| **TXT** | Plain text, minimal size | Quick viewing, email attachment |

#### Export Directory

All exported files are saved to the `UserLogs\` directory by default, with automatic timestamp-based naming for easy management.

---

### 4.2 Intelligent Diagnostics Engine

**Engine**: `AURORA-SmartEngine.ps1`
**Knowledge Base**: `Data\AURORA-TechData.json` (v3.1, updated 2026-05-14)

#### Five Diagnostic Categories

| Category | What It Checks | Common Issue Examples |
|----------|----------------|----------------------|
| **A. System Stability** | Crashes, BSODs, unexpected shutdowns, kernel errors | Driver conflicts, power instability, hardware failure |
| **B. Performance** | Slow startups, lag, high disk usage, memory leaks | Too many startup items, disk fragmentation, service timeouts |
| **C. Network** | WiFi drops, DNS failures, network restrictions, proxy issues | Driver problems, Winsock corruption, firewall rules |
| **D. Security Audit** | Brute-force logins, privilege escalation, virus scans, policy changes | Compromised system, stolen credentials, malware |
| **E. Hardware** | Disk errors, memory errors, CPU overheating, USB anomalies | Bad sectors, memory faults, cooling issues |

#### Knowledge Base System

The diagnostic engine features a built-in **AURORA Technical Knowledge Base (v3.1)** with extensive diagnostic rules. Each rule includes:

- **Rule ID**: Unique identifier (e.g., A-001 = System Stability category, rule 1)
- **Match Conditions**: Event IDs, sources, message keywords
- **Severity**: Critical / Error / Warning / Information
- **Description**: Bilingual (Chinese/English), plain language
- **Possible Causes**: 3-5 common causes
- **Solutions**: 3-5 specific action recommendations
- **Recommended Action**: Priority repair step
- **Auto-Repair Command**: Optional one-click fix (with risk level and rollback command)

**Coverage**: Windows 10 / Windows 11 / Windows Server 2016+

**v3.1 Additions**: USB fault diagnosis, virtualization issue detection, .NET runtime errors, TLS/SSL certificate issues, Group Policy conflict diagnosis

#### Blue Screen Analysis

- Automatically locates Minidump files in `C:\Windows\Minidump\`
- Parses BugCheck codes
- Identifies the driver causing the crash
- Correlates with knowledge base solutions

---

### 4.3 System Repair Toolkit

**Engine**: `AURORA-RepairTools.ps1`

#### Repair Types

| Repair Type | Parameter | What It Does |
|-------------|-----------|--------------|
| **Windows Update Repair** | `DisableWindowsUpdate` | Reset update components, clear update cache, repair update service |
| **Defender Repair** | `EnableDefender` | Repair Windows Defender service, reset security policies |
| **Telemetry Cleanup** | `DisableTelemetry` | Clean Windows telemetry data, optimize privacy settings |
| **Network Reset** | `ResetNetwork` | Reset TCP/IP stack, clear DNS cache, reset Winsock |
| **System Cleanup** | `CleanSystem` | Clean temporary files, repair system files, optimize disk |
| **Custom Repair** | `Custom` | Execute custom repair commands against a specified target |

#### Pre-Repair Protection

Before every repair operation, the system automatically:

1. **System Restore Point** (`CreateRestorePoint`): Creates a Windows system restore point for full system state rollback
2. **Quick Backup Snapshot** (`UseBackupSnapshot`): Precisely backs up registry entries, files, and service states about to be modified

#### Repair Safety Guarantees

- Repair commands require Administrator privileges
- Every repair command has a defined risk level (Low / Medium / High)
- High-risk commands require user confirmation
- All repair operations logged to `AURORA-RepairLogger.ps1`

---

### 4.4 Undo & Restore System

**Engine**: `AURORA-UndoManager.ps1` / `AURORA-UndoViewer.ps1`

#### Three-Tier Backup Architecture

| Backup Tier | What's Backed Up | Recovery Method |
|-------------|-----------------|-----------------|
| **Registry Backup** | Registry key values before/after modification | Precise restoration to pre-modification values |
| **File Backup** | File copies before/after modification | Replace with original files |
| **Service Backup** | Service startup type and status | Restore original service configuration |

#### Snapshot Management

- **Create Snapshot**: `Create-BackupSnapshot` — Auto-created before repair, includes all resources about to be modified
- **Restore Snapshot**: `Restore-BackupSnapshot` — One-click restore to the snapshot state
- **Verify Integrity**: `Test-BackupIntegrity` — Validate backup data integrity
- **Delete Snapshot**: `Remove-BackupSnapshot` — Clean up obsolete snapshots

#### Undo Viewer

`AURORA-UndoViewer.ps1` provides a graphical undo history viewer:

- Display all repair session lists
- View detailed modifications per session
- Before/after value comparison
- One-click undo or keep

#### System Restore Points

In addition to quick backup snapshots, AURORA Analyzer creates Windows System Restore Points before each repair, providing an additional system-level safety net.

---

### 4.5 Progress Management & Resume

**Engine**: `AURORA-ProgressManager.ps1`

#### Session Management

| Function | Cmdlet | Description |
|----------|--------|-------------|
| Create Session | `New-Session` | Create a session record when starting a new task |
| Save Progress | `Save-SessionProgress` | Auto-save current completion percentage and stage |
| Restore Progress | `Restore-SessionProgress` | Resume a task from where it was interrupted |
| Delete Session | `Remove-SessionProgress` | Clean up completed sessions |
| Query Pending | `Get-LatestPendingSession` | Retrieve the most recent incomplete session |
| Check Status | `Test-PendingSession` | Check if there are pending tasks |
| Mark Complete | `Complete-Session` | Mark a session as completed |
| Statistics | `Get-SessionStatistics` | View aggregate statistics for all sessions |

#### Resume Mechanism

- Progress auto-saved to local files (`.cache.clixml` format)
- Recoverable even after program closure or system reboot
- Supports simultaneous management of multiple in-progress tasks
- Each task records: Session ID, task type, current stage, completion percentage, save timestamp

---

## 5. Security Architecture

AURORA Analyzer employs a **five-layer defense-in-depth** model protecting the full lifecycle from build to runtime:

### Layer 1: Build-Time Protection

- **RSA Key Pair**: Build tool holds private key for token signing; PS1 embeds public key for verification
- **SHA256 Integrity Hashes**: Hash values for 16 core scripts hardcoded in AuroraGuard
- **Token TTL**: 60-second validity window to prevent token replay attacks

### Layer 2: Launch Verification

- **RSA Token Signature Verification**: SHA256 + PKCS#1 v1.5
- **AES Session Key Derivation**: PBKDF2 + AES-256-CBC to decrypt the hash manifest
- **File Integrity Verification**: Per-file SHA256 comparison

### Layer 3: IPC Security

- **Named Pipe Mutual Authentication**: `AURORA_WD_{8 hex}` randomized pipe name
- **HMAC-SHA256 Challenge-Response**: EXE periodically sends challenges; PS1 must respond correctly
- **Bidirectional Heartbeat**: Single failure triggers process termination

### Layer 4: Runtime Sentinel (AuroraGuard)

- **Debugger API Detection**: IsDebuggerPresent, CheckRemoteDebuggerPresent, NtQueryInformationProcess (DebugPort / DebugFlags / HandleTracing)
- **Hardware Breakpoint Detection**: GetThreadContext reads CPU Dr0-Dr3 debug registers
- **PEB Analysis**: Check NtGlobalFlag to detect debugger-launched processes
- **Process Name Scan**: Enumerate 90+ known debugger tool process names
- **DLL Injection Detection**: Analyze non-system module paths
- **Thread Hiding**: NtSetInformationThread(ThreadHideFromDebugger)
- **Continuous Polling**: Every 3 seconds + WMI real-time process creation events

### Layer 5: Exit Cleanup

- **Dual Event Registration**: PowerShell.Exiting + ProcessExit
- **Cascading Resource Release**: Pipe → Runspace → Timer → WMI Monitor → Environment Variables

---

## 6. Technical Specifications

### System Requirements

| Item | Minimum | Recommended |
|------|---------|-------------|
| Operating System | Windows 10 1809+ | Windows 11 |
| Architecture | x64 / x86 (WOW64) | x64 |
| Processor | Dual-core 1.5 GHz | Quad-core 2.0 GHz+ |
| Memory | 4 GB | 8 GB+ |
| Disk Space | 200 MB | 500 MB+ |
| .NET Framework | 4.x | 4.8 |
| PowerShell | Windows PowerShell 5.1+ | Windows PowerShell 5.1+ |

### Performance Tiering

AURORA Analyzer automatically detects hardware configuration at startup and selects the optimal performance tier:

| Tier | Hardware Requirements | Parallelism | Memory Strategy |
|------|----------------------|-------------|-----------------|
| **Extreme** | 8+ cores / 32GB+ RAM | Full parallel | Aggressive caching |
| **Performance** | 6 cores / 16GB RAM | 4 threads | Balanced caching |
| **Balanced** | 4 cores / 8GB RAM | 2 threads | Moderate caching |
| **Eco** | Older hardware | Single thread | Minimal caching |

### Technology Stack

| Layer | Language | Runtime | Key Dependencies |
|-------|----------|---------|------------------|
| EXE Loader | C# | .NET Framework 4.x | System.Diagnostics.Process, System.IO.Pipes |
| GUI Launcher | PowerShell + Embedded C# | Windows PowerShell 5.1 | System.Windows.Forms, System.Drawing |
| Security Sentinel | Embedded C# (Add-Type) | .NET Framework 4.x | ntdll.dll, kernel32.dll (P/Invoke) |
| Core Engines | PowerShell | Windows PowerShell 5.1 | No third-party dependencies |

---

## 7. Build & Deployment

### Build Commands

```powershell
# Standard build
.\build.ps1

# Skip signing (testing only)
.\build.ps1 -SkipSigning
```

### Build Pipeline

1. **Token Generation**: Compute SHA256 for all core scripts → PBKDF2 derive AES key → Encrypt hash manifest → RSA sign
2. **EXE Compilation**: CSharpCodeProvider compile C# loader → Embed RSA public key/master password/hash table
3. **HMAC Key Generation**: PBKDF2(MasterPassword, WdHmacSalt, 10000) → 32-byte key
4. **Output**: `AURORA-Analyzer.exe` + token file

### Deployment Requirements

- Copy the entire project directory (including Scripts\, Data\, Core\ subdirectories) to the target computer
- Run `AURORA-Analyzer.exe` with **Administrator privileges**
- First run automatically performs security verification

---

## 8. File Inventory

### Core Scripts (16 files, integrity-protected)

| File | Function |
|------|----------|
| `AURORA-AnalyzerLauncherGUI.ps1` | GUI Launcher + Security Sentinel + Watchdog Client |
| `AURORA-SmartEngine.ps1` | Intelligent Diagnostics Engine |
| `AURORA-CoreEngine.ps1` | Core Engine |
| `AURORA-AnalyzerCHSPRO.ps1` | Chinese Professional Edition Engine |
| `AURORA-ProgressManager.ps1` | Progress Manager |
| `AURORA-GUI-Functions.ps1` | GUI Function Library |
| `AURORA-RepairTools.ps1` | Repair Toolkit |
| `AURORA-UndoManager.ps1` | Undo Manager |
| `AURORA-RestoreManager.ps1` | Restore Manager |
| `AURORA-RepairLogger.ps1` | Repair Logger |
| `AURORA-UndoViewer.ps1` | Undo Viewer |
| `AURORA-AnalyzerPRO.ps1` | Universal Professional Engine |

### Extension Scripts

| File | Function |
|------|----------|
| `AURORA-ProgressManager-Integration.ps1` | Progress Manager Integration |
| `AURORA-ProgressManager-Integration-CHS.ps1` | Progress Manager Chinese Integration |
| `AURORA-ProgressManager-Integration-ENG.ps1` | Progress Manager English Integration |
| `Core\AURORA-AnimationCoreEngine.ps1` | Animation Core Engine |

### Data Files

| File | Function |
|------|----------|
| `Data\AURORA-TechData.json` | Technical Knowledge Base (v3.1) |
| `Data\AURORA-TechData.cache.clixml` | Knowledge Base Cache |

### Build & Documentation

| File | Function |
|------|----------|
| `build.ps1` | EXE Build Script |
| `update.md` / `update_EN.md` | Version Changelog |
| `READMEV1.2.24.5Release.md` / `_EN.md` | User Manual |
| `READMEV1.2.24.5.md` / `_EN.md` | Technical Documentation |
| `AURORA-Analyzer-Overview.md` / `_EN.md` | Complete Feature Overview |

---

*AURORA VelociRaptor-GR Dev PRJ. — 2026.06.01*