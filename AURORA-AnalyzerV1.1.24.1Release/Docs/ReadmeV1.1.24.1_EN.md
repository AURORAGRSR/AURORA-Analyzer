# AURORA Analyzer V1.1.24.1 — Developer Technical Manual

> **Target Audience**: Developers / Security Researchers / Reverse Engineers / Code Auditors
> **Document Purpose**: Ultra-detailed source-level functional analysis covering architecture design, security model, module implementation, and build process

***

## Table of Contents

- [1. Project Overview](#1-project-overview)
- [2. v1.1.24.1 Core Update Summary](#2-v11241-core-update-summary)
- [3. Complete Module Architecture](#3-complete-module-architecture)
  - [3.1 File Inventory & Responsibilities](#31-file-inventory--responsibilities)
  - [3.2 Module Dependency Graph](#32-module-dependency-graph)
- [4. GUI Architecture Deep Dive](#4-gui-architecture-deep-dive)
  - [4.1 Windows Forms Launcher](#41-windows-forms-launcher)
  - [4.2 PowerShell Runspace Multi-threading Model](#42-powershell-runspace-multi-threading-model)
  - [4.3 syncHash Cross-Thread Communication](#43-synchas-cross-thread-communication)
  - [4.4 EventWaitHandle Event-Driven Authorization](#44-eventwaithandle-event-driven-authorization)
  - [4.5 AuroraProgressBar Starfield Animation Engine](#45-auroraprogressbar-starfield-animation-engine)
  - [4.6 Dynamic Performance Tier Algorithm](#46-dynamic-performance-tier-algorithm)
- [5. PRO Mode Technical Implementation](#5-pro-mode-technical-implementation)
  - [5.1 Log Types & Export Modes](#51-log-types--export-modes)
  - [5.2 Advanced Filter Engine](#52-advanced-filter-engine)
  - [5.3 Multi-Format Output Pipeline](#53-multi-format-output-pipeline)
  - [5.4 Smart Permission Management — Elevation Security Token](#54-smart-permission-management--elevation-security-token)
  - [5.5 Session Persistence & Checkpoint Resume](#55-session-persistence--checkpoint-resume)
- [6. Smart Diagnostic Engine](#6-smart-diagnostic-engine)
  - [6.1 Diagnostic Rule Knowledge Base](#61-diagnostic-rule-knowledge-base)
  - [6.2 Anomaly Time Window Targeted Locking](#62-anomaly-time-window-targeted-locking)
  - [6.3 Minidump BSOD Parsing](#63-minidump-bsod-parsing)
  - [6.4 Secure Sandbox Executor](#64-secure-sandbox-executor)
  - [6.5 Five Diagnostic Categories in Detail](#65-five-diagnostic-categories-in-detail)
- [7. Undo / Repair System](#7-undo--repair-system)
  - [7.1 Windows System Restore API Integration](#71-windows-system-restore-api-integration)
  - [7.2 Quick Backup Snapshot Mechanism](#72-quick-backup-snapshot-mechanism)
  - [7.3 Repair Command Audit Logging](#73-repair-command-audit-logging)
  - [7.4 One-Click Undo Implementation](#74-one-click-undo-implementation)
  - [7.5 Repair History Viewer](#75-repair-history-viewer)
- [8. Security Architecture — Five-Layer Defense-in-Depth Model](#8-security-architecture--five-layer-defense-in-depth-model)
  - [8.1 Layer 1: Build-Time Security](#81-layer-1-build-time-security)
  - [8.2 Layer 2: Launch-Time Security](#82-layer-2-launch-time-security)
  - [8.3 Layer 3: Runtime Security](#83-layer-3-runtime-security)
  - [8.4 Layer 4: Multi-Module Launch Detection](#84-layer-4-multi-module-launch-detection)
  - [8.5 Layer 5: Named Pipe Watchdog Guardian 🆕](#85-layer-5-named-pipe-watchdog-guardian-)
  - [8.6 C# Embedded Integrity Guard (AuroraGuard) 🆕](#86-c-embedded-integrity-guard-auroraguard-)
  - [8.7 Elevation Security Token (AURORA-SEC-2026-001) 🆕](#87-elevation-security-token-aurora-sec-2026-001-)
  - [8.8 Anti-Spoofing Launch Parameter Protection 🆕](#88-anti-spoofing-launch-parameter-protection-)
- [9. Build System](#9-build-system)
  - [9.1 build.ps1 Full Process](#91-buildps1-full-process)
  - [9.2 C# Obfuscation Compilation](#92-c-obfuscation-compilation)
  - [9.3 AuroraGuard Hash Injection (2.5/6) 🆕](#93-auroraguard-hash-injection-256-)
  - [9.4 Packaging & Distribution](#94-packaging--distribution)
- [10. Internationalization Architecture](#10-internationalization-architecture)
- [11. Performance vs. Security Trade-off Design — LastWriteTime Optimization 🆕](#11-performance-vs-security-trade-off-design--lastwritetime-optimization-)
- [12. Error Handling & Logging](#12-error-handling--logging)

---

## 1. Project Overview

| Property | Value |
| -------- | ------------------------------------------- |
| **Project Name** | AURORA Analyzer |
| **Version** | V1.1.24.1 |
| **Build Date** | 2026-05-27 |
| **Author** | AURORA VelociRaptor-GR Dev PRJ. |
| **License** | For personal learning and research use only |
| **Type** | Windows System Event Log Export & Intelligent Diagnostic Tool |
| **Core Languages** | C# (.NET Framework 4.x) + PowerShell 7+ |
| **Target Platform** | Windows 10/11 x64 (.NET Framework 4.7.2+ required) |
| **Minimum Permissions** | Standard user (admin required for some features) |

### Core Capability Matrix

| Domain | Description | Technology Stack |
| ---- | ------------------------ | ------------------------------- |
| Log Export | 8 Windows event log types, multi-format output | PowerShell `Get-WinEvent` API |
| Smart Diagnosis | 100+ rule knowledge graph matching | JSON rule engine + PowerShell |
| BSOD Analysis | Automated Minidump parsing | Windows Debugger API |
| System Repair | One-click repair for 5 system issue categories | PowerShell + Windows API |
| Undo System | Dual-insurance rollback (restore point + snapshot) | System Restore API + registry/file backup |
| Security | Five-layer defense-in-depth | RSA-2048 + AES-256-CBC + PBKDF2 + HMAC-SHA256 + Named Pipe |
| I18n | Bilingual Chinese & English | PowerShell Data File (.psd1) |
| GUI | Windows Forms native UI | C# WinForms + multi-threaded Runspace |

---

## 2. v1.1.24.1 Core Update Summary

This version upgrades from v1.1.24.0's four-layer defense-in-depth model to a **five-layer defense-in-depth model**, adding Named Pipe Watchdog Guardian and C# Embedded Integrity Guard. Specific changes:

### Security Architecture Upgrades

| # | Update Item | Type | Detail |
| -- | ------------------------- | --------- | -------------------------------- |
| 1 | Named Pipe Watchdog Guardian | **NEW** | EXE↔PS1 bidirectional HMAC-SHA256 challenge-response heartbeat, independent 5th defense layer |
| 2 | C# Embedded Integrity Guard (AuroraGuard) | **NEW** | Runtime-compiled IL, SHA256 verification of 16 core sub-modules |
| 3 | Elevation Security Token (AURORA-SEC-2026-001) | **P0 FIX** | Independent AES-256-CBC token, 120s expiration, fixes elevation trust chain break |
| 4 | Anti-Spoofing -LaunchedByExe Protection | **P0 FIX** | Forged parameter detection, forces security state reset when token is invalid |
| 5 | LastWriteTime Pre-Check | **P2 OPT** | Skip SHA256 for unchanged files, 95% CPU overhead reduction |
| 6 | C# Embedded Countdown Alert Window | **REFACTOR** | Replaces PowerShell Timer, eliminates scope and stability issues |
| 7 | Assembly Duplicate Load Check | **FIX** | Prevents errors from duplicate Add-Type calls |
| 8 | AuroraGuard Hash Injection (build.ps1) | **NEW** | Auto-inject 16 sub-module SHA256 hashes into C# source at build time |
| 9 | Enhanced Smart Security Code Injection | **ENHANCE** | Supports first-time injection, key update, and hash update modes |
| 10 | Defense-in-Depth: 4 Layers → 5 Layers | **ARCH UPGRADE** | New independent process-level watchdog protection |

---

## 3. Complete Module Architecture

### 3.1 File Inventory & Responsibilities

#### 3.1.1 Core Launch Modules

| File | Type | Responsibility | Secrets Held |
| --------------------------------------------- | ------------- | ------------------ | ------------------ |
| `AURORA.Launcher-双击启动.exe` | C# Compiled PE | Entry point, holds private key, password, anti-debug logic, watchdog server | RSA private key, password fragments, debugger blacklist, Watchdog HMAC key |
| `Scripts/AURORA-AnalyzerLauncherGUI.ps1` | PowerShell Script | Main GUI, runtime monitoring dispatcher, AuroraGuard host | RSA public key, integrity check logic, AuroraGuard IL code |
| `Scripts/AURORA-GUI-Functions.ps1` | PowerShell Script | GUI helper functions | None |
| `Scripts/Core/AURORA-AnimationCoreEngine.ps1` | PowerShell Script | Starfield animation engine source | None |
| `Scripts/Core/AURORA-AnimationCoreEngine.dll` | .NET DLL | Animation engine compiled library | None |

#### 3.1.2 PRO Mode Modules

| File | Type | Responsibility |
| ----------------------------------- | ------------- | ---------------- |
| `Scripts/AURORA-AnalyzerPRO.ps1` | PowerShell Script | Unified PRO entry, language routing |
| `Scripts/AURORA-AnalyzerCHSPRO.ps1` | PowerShell Script | Chinese PRO log export logic |
| `Scripts/AURORA-AnalyzerENGPRO.ps1` | PowerShell Script | English PRO log export logic |

#### 3.1.3 Smart Diagnostics Module

| File | Type | Responsibility |
| -------------------------------- | ------------- | -------------------- |
| `Scripts/AURORA-SmartEngine.ps1` | PowerShell Script | Diagnostic engine v1.1.32, rule matching & execution |
| `Data/AURORA-TechData.json` | JSON Data | Technical knowledge base, 100+ diagnostic rule definitions |

#### 3.1.4 Progress Management Modules

| File | Type | Responsibility |
| ---------------------------------------------------- | ------------- | ------------ |
| `Scripts/AURORA-ProgressManager.ps1` | PowerShell Script | Progress persistence core, checkpoint resume |
| `Scripts/AURORA-ProgressManager-Integration.ps1` | PowerShell Script | Bilingual progress integration bridge |
| `Scripts/AURORA-ProgressManager-Integration-CHS.ps1` | PowerShell Script | Chinese progress UI integration |
| `Scripts/AURORA-ProgressManager-Integration-ENG.ps1` | PowerShell Script | English progress UI integration |

#### 3.1.5 Core Engine Modules

| File | Type | Responsibility |
| ------------------------------- | -------------------- | ------------------------- |
| `Scripts/AURORA-CoreEngine.ps1` | PowerShell Script | Shared core engine (permissions, log processing, file ops, session mgmt) |
| `Scripts/AURORA-Language.psd1` | PowerShell Data File | Centralized bilingual resources (144 translations) |

#### 3.1.6 Undo / Repair System Modules (Phase 4.2)

| File | Type | Responsibility |
| ----------------------------------- | ------------- | ---------------------------------- |
| `Scripts/AURORA-RestoreManager.ps1` | PowerShell Script | Windows System Restore API integration |
| `Scripts/AURORA-RepairLogger.ps1` | PowerShell Script | Repair command logger (audit trail) |
| `Scripts/AURORA-UndoManager.ps1` | PowerShell Script | Quick backup & restore (registry/files/services) |
| `Scripts/AURORA-RepairTools.ps1` | PowerShell Script | Repair toolset (Update, Defender, Telemetry, etc.) |
| `Scripts/AURORA-UndoViewer.ps1` | PowerShell Script | Repair history viewer & undo tool |

#### 3.1.7 Build & Security Files

| File | Type | Responsibility |
| ------------------ | ------------- | ---------------------------- |
| `build.ps1` | PowerShell Script | Automated build system (with AuroraGuard hash injection) |
| `AURORA-build.bat` | Batch File | Build shortcut entry |
| `version.txt` | Text File | Version number storage |
| `GAURORA.CHK.ENC` | Encrypted Binary | AES-encrypted SHA256 hash manifest of 19 core files |
| `desktop.ini` | System File | Folder icon customization |

---

### 3.2 Module Dependency Graph

```
AURORA.Launcher-双击启动.exe (C# Launcher)
    │
    ├──[RSA Handshake + Named Pipe Watchdog]──► AURORA-AnalyzerLauncherGUI.ps1 (Main GUI)
    │    │                                   │
    │    │                                   ├──[AuroraGuard IL] 16-module integrity verification
    │    │                                   │
    │    │                                   ├──► AURORA-GUI-Functions.ps1 (GUI Helpers)
    │    │                                   ├──► AURORA-AnimationCoreEngine.dll (Animation)
    │    │                                   │       └──► AURORA-AnimationCoreEngine.ps1 (Source)
    │    │                                   │
    │    │                                   ├──► AURORA-AnalyzerPRO.ps1 (PRO Entry)
    │    │                                   │       ├──► AURORA-AnalyzerCHSPRO.ps1
    │    │                                   │       └──► AURORA-AnalyzerENGPRO.ps1
    │    │                                   │
    │    │                                   ├──► AURORA-SmartEngine.ps1 (Diagnostic Engine)
    │    │                                   │       └──► AURORA-TechData.json (Knowledge Base)
    │    │                                   │
    │    │                                   ├──► AURORA-ProgressManager.ps1 (Progress Mgmt)
    │    │                                   │       ├──► AURORA-ProgressManager-Integration.ps1
    │    │                                   │       │       ├──► -Integration-CHS.ps1
    │    │                                   │       │       └──► -Integration-ENG.ps1
    │    │                                   │
    │    │                                   ├──► AURORA-RestoreManager.ps1 (System Restore)
    │    │                                   ├──► AURORA-RepairLogger.ps1 (Repair Log)
    │    │                                   ├──► AURORA-UndoManager.ps1 (Undo Mgmt)
    │    │                                   ├──► AURORA-RepairTools.ps1 (Repair Tools)
    │    │                                   ├──► AURORA-UndoViewer.ps1 (History Viewer)
    │    │                                   │
    │    │                                   ├──► AURORA-CoreEngine.ps1 (Core Engine)
    │    │                                   └──► AURORA-Language.psd1 (Bilingual Resources)
    │    │
    │    └──[Integrity Check]──► GAURORA.CHK.ENC (Encrypted Hash Manifest)
    │
    └──[Watchdog Protocol]──► Named Pipe: AURORA_WD_{8-char Random ID}
            Bidirectional HMAC-SHA256 Challenge-Response Heartbeat
```

---

## 4. GUI Architecture Deep Dive

### 4.1 Windows Forms Launcher

`AURORA.Launcher-双击启动.exe` is the entry point, written in C#, compiled with .NET Framework's Windows Forms.

**Launch Flow (v1.1.24.1 Enhanced):**

```
User Double-Clicks EXE
    │
    ├─ 1. Anti-Debug Detection
    │     ├─ IsDebuggerPresent() API call
    │     └─ Process enumeration (x64dbg, OllyDbg, Scylla, Phantom)
    │
    ├─ 2. Integrity Check
    │     ├─ Read GAURORA.CHK.ENC → AES-256-CBC decrypt
    │     ├─ 19 core file existence check
    │     └─ SHA256 per-file comparison
    │
    ├─ 3. Generate RSA Auth Token
    │     ├─ Nonce = GUID.NewGuid()
    │     ├─ Timestamp = DateTime.UtcNow
    │     └─ RSA-Sign(SHA256(Nonce:Timestamp))
    │
    ├─ 3.5 🆕 Generate Elevation Security Token
    │     └─ AES-256-CBC encrypted hash list + Nonce + Timestamp, 120s expiry
    │
    ├─ 4. 🆕 Start Named Pipe Watchdog Server
    │     ├─ Generate unique pipe name: AURORA_WD_{8-char random ID}
    │     ├─ Generate SessionID
    │     ├─ Derive HMAC key: PBKDF2-SHA256(Password, WdSalt, 10000iter)
    │     └─ Set environment variables for pipe name and SessionID
    │
    ├─ 5. Launch PowerShell Process
    │     ├─ Pass RSA Token as command-line argument
    │     ├─ Pass ElevationTokenPath
    │     ├─ Set GUI_Mode=1 environment variable
    │     ├─ Pass watchdog pipe name and SessionID
    │     └─ Pass syncHash reference
    │
    ├─ 6. 🆕 Named Pipe Handshake
    │     ├─ Wait for PS1 to connect (15s timeout)
    │     ├─ Send: [0x10] [32B HMAC Key] [16B SessionID]
    │     ├─ Receive: [0x11] ACK
    │     └─ Handshake failure → Kill PS1 process
    │
    ├─ 7. Wait for RSA Handshake Confirmation
    │
    └─ 8. 🆕 Start Watchdog Dual Timer
          ├─ Fixed 5s interval challenge
          └─ Random 2-7s interval challenge
```

**C# Source Protection Measures:**

- Password embedded via XOR + Shuffle dual obfuscation
- RSA private key stored as fragmented byte array
- Watchdog HMAC salt embedded in source
- Class and method names offline-renamed before compilation
- Compilation target forced to x86 platform

### 4.2 PowerShell Runspace Multi-threading Model

The main GUI uses PowerShell Runspace for true multi-threaded concurrency, rather than traditional PowerShell Jobs (process-level isolation).

```
Main Thread (MainForm)
    │
    ├── Runspace #1: Worker-Runspace
    │     └── Executes time-consuming operations (export, diagnosis)
    │
    ├── Runspace #2: Animation-Runspace
    │     └── AuroraProgressBar starfield animation rendering
    │
    ├── Runspace #3: Integrity-Monitor
    │     ├── Dual timers + FileSystemWatcher integrity monitoring
    │     ├── AuroraGuard.VerifyOrDie() C# embedded verification
    │     └── 🆕 Named Pipe watchdog client heartbeat response
    │
    ├── Runspace #4: Watchdog-Client 🆕
    │     └── NamedPipeClientStream connecting to watchdog server
    │
    └── UI Thread: Windows Forms message pump
          └── Handle user interaction events
```

### 4.3 syncHash Cross-Thread Communication

The `synchronized hashtable` is PowerShell's thread-safe dictionary, serving as the sole communication bridge between the GUI thread and Worker Runspaces.

**Core Data Structure (v1.1.24.1 Enhanced):**

```powershell
$syncHash = [hashtable]::Synchronized(@{
    Command         = $null
    Parameters      = $null
    CancelRequested = $false
    Progress        = 0
    StatusMessage   = ""
    IsCompleted     = $false
    Result          = $null
    Error           = $null
    IsAdmin         = $false
    CurrentLanguage = "zh-CN"
    GuiHandle       = [IntPtr]::Zero
    Token           = ""
    TokenValidated  = $false
    TamperDetected  = $false
    # 🆕 Watchdog state
    WdPipeName      = ""
    WdSessionId     = ""
    WdHmacKey       = $null
    WdConnected     = $false
})
```

### 4.4 EventWaitHandle Event-Driven Authorization

```powershell
$AuthEvent = [System.Threading.EventWaitHandle]::new(
    $false,
    [System.Threading.EventResetMode]::ManualReset,
    "AURORA_Auth_Event_$PID"
)
$AuthEvent.WaitOne()  # Blocking, zero CPU
```

### 4.5 AuroraProgressBar Starfield Animation Engine

Custom .NET control using GDI+ double-buffered rendering. Particle system: hundreds of random stars with trajectory motion. Color scheme: blue-purple gradient simulating aurora effect. Performance-adaptive: adjusts particle count and frame rate based on system performance tier.

### 4.6 Dynamic Performance Tier Algorithm

```
Total Score = CPU Core Score × 0.35 + RAM Score × 0.35 + Clock Score × 0.30

CPU Core Score = min(Cores / 8, 1.0) × 100
RAM Score      = min(TotalGB / 16, 1.0) × 100
Clock Score    = min(GHz / 3.5, 1.0) × 100
```

| Tier | Score Range | Particle Count | Frame Rate | Threads |
| --------------- | ----- | ----- | ------ | ---- |
| **Extreme** | ≥ 90 | 300 | 60 FPS | 4 |
| **Performance** | 70-89 | 200 | 45 FPS | 3 |
| **Balanced** | 40-69 | 100 | 30 FPS | 2 |
| **Eco** | < 40 | 50 | 20 FPS | 1 |

---

## 5. PRO Mode Technical Implementation

### 5.1 Log Types & Export Modes

PRO mode supports 8 Windows event log types:

| Log Name | `Get-WinEvent -LogName` Parameter | Typical Contents |
| ----------------- | -------------------------- | ------------- |
| System | `System` | System services, drivers, kernel events |
| Application | `Application` | App errors, crashes |
| Security | `Security` | Login audits, privilege changes |
| Setup | `Setup` | Windows installs & updates |
| DNS Server | `DNS Server` | DNS queries & resolution |
| DHCP Server | `DHCP Server` | DHCP lease info |
| Directory Service | `Directory Service` | AD domain controller events |
| IIS Admin Service | `IIS-Admin` | IIS web server management |

**Routing mechanism (AURORA-AnalyzerPRO.ps1):**

```powershell
if ($Language -eq "CHS") {
    & "$PSScriptRoot\AURORA-AnalyzerCHSPRO.ps1" @PSBoundParameters
} else {
    & "$PSScriptRoot\AURORA-AnalyzerENGPRO.ps1" @PSBoundParameters
}
```

### 5.2 Advanced Filter Engine

```powershell
$filterParams = @{
    LogName   = $LogType
    StartTime = $startDate
    EndTime   = $endDate
}
if ($EventID) { $filterParams.ID = $EventID -split ',' | % { [int]$_.Trim() } }
if ($ProviderName) { $filterParams.ProviderName = $ProviderName }
if ($Level) { $filterParams.Level = $Level }

$events = Get-WinEvent -FilterHashtable $filterParams -MaxEvents $maxEvents
```

### 5.3 Multi-Format Output Pipeline

```
Get-WinEvent Raw Data
    │
    ├─► CSV  → System_Log_20260527.csv
    ├─► JSON → System_Log_20260527.json
    ├─► XML  → System_Log_20260527.xml
    ├─► Summary → System_Log_20260527_Summary.txt
    └─► Trend → System_Log_..._Trend_Analysis.txt
              → System_Log_..._Trend_Data.csv
```

### 5.4 Smart Permission Management — Elevation Security Token

> 🆕 **New in v1.1.24.1:** Independent elevation security token mechanism fixes the P0 trust chain break issue during UAC elevation.

**Problem:** When users perform admin-required operations, PowerShell restarts with UAC elevation (`Start-Process -Verb RunAs`). The original RSA token file is cleaned up by the old process, leaving the elevated process unable to verify the EXE identity.

**Solution:**

```
EXE generates ElevationToken at launch
    │
    ├─ Nonce = GUID.NewGuid() (128-bit)
    ├─ Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
    ├─ AES-256-CBC encrypt hash list (independent key derived from Password + Nonce)
    ├─ Write ElevationToken file
    └─ Pass to PS1: -ElevationTokenPath <path>

Elevated PS1 process
    │
    ├─ Read ElevationToken file
    ├─ Verify timestamp: |now - timestamp| < 120s
    ├─ Derive AES key from Password + Nonce
    ├─ Decrypt hash list
    ├─ Compare file hashes
    └─ Delete token file immediately after successful verification
```

**Security:**
- Token contains only encrypted hash list, no passwords or private keys
- 120-second independent expiration window
- Decryption failure → falls back to password verification
- Token file deleted immediately after successful verification

### 5.5 Session Persistence & Checkpoint Resume

`AURORA-ProgressManager.ps1` implements full session persistence with checkpoint resume support.

- **active/**: In-progress sessions
- **archive/**: Completed sessions (format: `SESSION_{id}_{starttime}_{endtime}.json`)

---

## 6. Smart Diagnostic Engine

### 6.1 Diagnostic Rule Knowledge Base

`Data/AURORA-TechData.json` is the core knowledge base defining 100+ diagnostic rules in hierarchical JSON structure (version 1.1.32).

### 6.2 Anomaly Time Window Targeted Locking

The diagnostic engine intelligently locks onto anomaly time windows rather than blindly scanning all logs:

```
1. Analyze boot history (EventID 6005/6006)
2. Analyze crash history (EventID 41/1001)
3. Calculate key windows:
   - Pre-crash window: [CrashTime - 2h, CrashTime]
   - Post-boot window: [BootTime, BootTime + 4h]
4. Merge overlapping windows
5. Execute deep rule matching only within windows
```

### 6.3 Minidump BSOD Parsing

Uses `System.IO.BinaryReader` to parse DMP file headers for BugCheck information, driver lists, and running processes at crash time.

### 6.4 Secure Sandbox Executor

`Invoke-AuroraSafeAction` provides a secure execution wrapper ensuring repair operations are traceable and reversible:

```
PreCheck → RiskAssessment → CreateRollbackPoint → ExecuteAction → ValidateResult
```

### 6.5 Five Diagnostic Categories in Detail

| Category | Focus | Sample Rules |
|----------|-------|-------------|
| **A: System Stability** | Unexpected shutdowns, service crashes, kernel anomalies | A-001 through A-006 |
| **B: Application Errors** | .NET crashes, app hangs, WMI errors | B-001 through B-005 |
| **C: Driver Issues** | Load failures, timeouts, NDIS errors | C-001 through C-004 |
| **D: Hardware Warnings** | SMART warnings, bad sectors, ECC, thermal | D-001 through D-005 |
| **E: Security Audits** | Brute force, privilege escalation, audit log clearing | E-001 through E-006 |

---

## 7. Undo / Repair System

### 7.1 Windows System Restore API Integration

`AURORA-RestoreManager.ps1` wraps Windows System Restore API, automatically creating restore points before each repair.

- 24-hour cooldown: only 1 restore point per 24h (Windows limitation)
- Graceful skip if recent restore point exists

### 7.2 Quick Backup Snapshot Mechanism

`AURORA-UndoManager.ps1` provides lighter-weight snapshots:
- **Registry Keys**: `reg export` → .reg files
- **Registry Values**: `Get-ItemProperty` → JSON
- **Files**: Copy to backup directory
- **Service States**: `Get-Service` → JSON
- **Scheduled Tasks**: `Get-ScheduledTask` → XML

### 7.3 Repair Command Audit Logging

`AURORA-RepairLogger.ps1` records complete audit trails in JSONL format.

```jsonl
{"Timestamp":"2026-05-27 10:54:43.125","SessionId":"REPAIR_20260527_001","Command":"DisableWindowsUpdate","Result":"Success","UserSID":"S-1-5-21-...","MachineName":"DESKTOP-XXX"}
```

### 7.4 One-Click Undo Implementation

Supports per-SessionId rollback of all associated repair operations using LIFO (Last In, First Out) reverse-order strategy.

### 7.5 Repair History Viewer

Interactive viewer with sort by SessionId/DateTime/Type, status icons, and CSV export.

---

## 8. Security Architecture — Five-Layer Defense-in-Depth Model

> 🆕 **Major Upgrade in v1.1.24.1:** Expanded from v1.1.24.0's four-layer model to a **five-layer model**, adding Named Pipe Watchdog Guardian and C# Embedded Integrity Guard.

### 8.1 Layer 1: Build-Time Security

Established during `build.ps1` execution, ensuring protection from the moment of compilation.

#### 8.1.1 RSA-2048 Key Pair Generation

```powershell
$rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new(2048)
$privateKey = $rsa.ToXmlString($true)
$publicKey  = $rsa.ToXmlString($false)

# Fragment private key into C# source
$privateKeyBytes = [System.Text.Encoding]::UTF8.GetBytes($privateKey)
$chunks = Split-BytesIntoChunks -Bytes $privateKeyBytes -ChunkSize 64
```

#### 8.1.2 Password Obfuscation Algorithm

Dual obfuscation before embedding in C# source: XOR → Fisher-Yates Shuffle.

#### 8.1.3 🆕 Watchdog HMAC Salt Embedding

```powershell
$wdSalt = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
# → Injected into C#: static readonly byte[] WdHmacSalt = { 0xXX, 0xXX, ... };
```

#### 8.1.4 SHA256 Hash Manifest Generation

19 core file hashes computed and stored.

#### 8.1.5 AES-256-CBC Encrypted Hash Manifest

```powershell
# Salt(32B) + IV(16B) + Ciphertext → GAURORA.CHK.ENC
```

### 8.2 Layer 2: Launch-Time Security

#### 8.2.1 Anti-Debug Detection (C# Side)

```csharp
[DllImport("kernel32.dll")] static extern bool IsDebuggerPresent();
[DllImport("kernel32.dll")] static extern bool CheckRemoteDebuggerPresent(IntPtr hProcess, ref bool pbDebuggerPresent);

bool DetectDebugger() {
    if (IsDebuggerPresent()) return true;
    // Enumerate known debuggers: x64dbg, ollydbg, scylla, phantom, windbg, ida
    foreach (var proc in Process.GetProcesses()) {
        foreach (var dbg in debuggers) {
            if (proc.ProcessName.ToLower().Contains(dbg)) return true;
        }
    }
    return false;
}
```

#### 8.2.2 Integrity Verification Flow

```
Read GAURORA.CHK.ENC
    → Extract Salt (32B) → Extract IV (16B) → Extract Ciphertext
    → PBKDF2-SHA256 derive key (password + salt, 100,000 iter)
    → AES-256-CBC decrypt → JSON hash manifest
    → 🆕 Store decrypted hash for AuroraGuard use
    → Check 19 core files exist → Compute SHA256 → Compare
    → All passed → Allow launch
```

### 8.3 Layer 3: Runtime Security

#### 8.3.1 Dual Timer Mechanism + LastWriteTime Optimization 🆕

```powershell
$timer1 = [System.Timers.Timer]::new(3000)  # Fixed 3s
$timer2 = [System.Timers.Timer]::new((Get-RandomInterval))  # Random 2-7s
```

#### 8.3.2 🆕 LastWriteTime Pre-Check

```powershell
foreach ($file in $coreFileList) {
    $currentLWT = (Get-Item $fullPath).LastWriteTimeUtc
    if ($currentLWT -eq $lastKnownWriteTimes[$file]) {
        continue  # File unchanged, skip SHA256 → saves ~50-200ms/file
    }
    $lastKnownWriteTimes[$file] = $currentLWT
    $currentHash = (Get-FileHash $fullPath -Algorithm SHA256).Hash
    if ($currentHash -ne $expectedHashes[$file]) {
        $violations += "File tampered: $file"
    }
}
```

**Performance Comparison:**

| Scenario | v1.1.24.0 | v1.1.24.1 | Improvement |
|----------|-----------|-----------|-------------|
| Stable (19 files unchanged) | ~3800ms SHA256 | ~0ms (timestamp only) | **99%+** |
| 1 file modified | ~3800ms | ~200ms | **94%** |
| Sustained CPU | Medium | Near zero | **Significant** |

#### 8.3.3 FileSystemWatcher Real-Time Monitoring

Monitors `.ps1`, `.json`, `.xml`, `.ico`, `.exe`, `.enc` file changes.

#### 8.3.4 Four Detection Checks

File count check → Core file existence → SHA256 hash comparison (with LastWriteTime pre-check) → Unauthorized file injection detection.

#### 8.3.5 🆕 C# Embedded Countdown Alert Window

```csharp
public class AuroraExitCountdown : Form
{
    private System.Windows.Forms.Timer _timer;
    private int _secondsRemaining = 15;
    // Dark theme: dark red background + white text
    // Last 5 seconds: red countdown warning
    // TopMost = true
}
```

**Why C#:** PowerShell Timer has scope issues across Runspaces. C# WinForms `System.Windows.Forms.Timer` runs on the UI thread with stable timing.

#### 8.3.6 Tamper Response

```powershell
function Invoke-TamperResponse {
    # 1. Log violations
    # 2. Stop all monitoring
    # 3. Notify GUI thread
    # 4. 🆕 Show C# countdown dialog (15s)
    # 5. Force exit
    [System.Environment]::Exit(1)
}
```

### 8.4 Layer 4: Multi-Module Launch Detection

Multiple conditions must be satisfied simultaneously for initialization (GUI_Mode + syncHash + RSA Token), preventing malicious module injection or forged launch parameters.

#### 🆕 Anti-Spoofing -LaunchedByExe Parameter Protection

```powershell
if ($IsLaunchedByExe -eq $true -and $PassedHashListFromExe -eq $null) {
    $IsLaunchedByExe = $false
    Write-Warning "AURORA-SEC: Invalid launch context detected - resetting security state"
    # Clear all environment variable markers
    # Force password verification path
}
```

### 8.5 Layer 5: Named Pipe Watchdog Guardian 🆕

> **The most significant new security feature in v1.1.24.1.** A fully independent Named Pipe watchdog server on the EXE side establishes a bidirectional HMAC-SHA256 challenge-response heartbeat channel with the PS1 script. Even if all PS1-layer verifications are bypassed, the EXE can independently detect anomalies and terminate the process.

#### 8.5.1 Named Pipe Communication Architecture

```
┌─────────────────────────────┐     Named Pipe      ┌──────────────────────────────┐
│  AURORA.Launcher.exe (Private Key) │ ◄═══════════════► │  PS1 Script (Public Key/Integrity Check) │
│                               │   AURORA_WD_{8-char}  │                                │
│  [Watchdog Server]            │                    │  [Watchdog Client]            │
│  NamedPipeServerStream        │  ▸ [0x10] Handshake │  NamedPipeClientStream        │
│  PBKDF2 HMAC Key Derivation   │  ◂ [0x11] ACK       │  Receive HMAC Key             │
│  Dual Timer Challenge Send    │  ▸ [0x03] Challenge │  Compute HMAC Response        │
│  Kill PS1 Process (Independent)│  ◂ [0x04] Response  │  Carry Self-SHA256            │
└─────────────────────────────┘                      └──────────────────────────────┘
```

#### 8.5.2 Protocol Frame Format

```
Handshake:
  EXE → PS1: [0x10] [32B HMAC Key] [16B UTF8 SessionID]  = 49 bytes
  PS1 → EXE: [0x11]                                        = 1 byte ACK

Challenge-Response:
  EXE → PS1: [0x03] [16B CSPRNG Nonce] [8B UTC Unix Timestamp] = 25 bytes
  PS1 → EXE: [0x04] [32B HMAC(Nonce,Key)] [8B System Uptime Seconds] [32B PS1 Self-SHA256] = 73 bytes
```

#### 8.5.3 HMAC Key Derivation (C# EXE Side)

```csharp
byte[] wdHmacKey;
using (var pbkdf2 = new Rfc2898DeriveBytes(masterPassword, WdHmacSalt, 10000, HashAlgorithmName.SHA256))
{
    wdHmacKey = pbkdf2.GetBytes(32);
}
```

#### 8.5.4 Challenge-Response Mechanism

```csharp
// Challenge generation
byte[] challengeNonce = new byte[16];  // CSPRNG
byte[] ts = new byte[8];              // UTC Unix timestamp

// Response verification
byte[] expectedHmac;
using (var hmac = new HMACSHA256(wdHmacKey))
{
    expectedHmac = hmac.ComputeHash(receivedNonce);
}

if (!ConstantTimeCompare(expectedHmac, receivedHmac))
{
    wdFailCount++;  // 3 consecutive failures → Kill
}
```

#### 8.5.5 Dual Timer Design

```csharp
var wdFixedTimer = new System.Timers.Timer(5000);     // Fixed 5s
int randomMs = 2000 + rng.Next(0, 5000);              // Random 2-7s
var wdRandomTimer = new System.Timers.Timer(randomMs);
```

#### 8.5.6 PS1 Side Self-Hash Calculation

```powershell
$selfPath = $PSCommandPath
$selfSha256 = (Get-FileHash -Path $selfPath -Algorithm SHA256).Hash

$hmac = [System.Security.Cryptography.HMACSHA256]::new($wdHmacKey)
$responseHmac = $hmac.ComputeHash($challengeNonce)

# Send: [0x04] [32B HMAC] [8B Uptime] [32B SelfSHA256]
```

#### 8.5.7 Failure Handling

```csharp
const int WdMaxFailCount = 3;
const int WdConnectTimeoutMs = 15000;
const int WdResponseTimeoutMs = 3000;

if (wdFailCount >= WdMaxFailCount)
{
    ps1Proc.Kill();  // Independent process termination
}
```

#### 8.5.8 Attack Model Coverage

| Attack Vector | How Watchdog Defends |
|---------------|---------------------|
| Comment out all PS1 verification code | EXE-side independent detection, challenge-response bypasses PS1 |
| Replace PS1 script file | Self-SHA256 mismatch → 3 failures → Kill |
| Inject memory hooks | Named Pipe heartbeat lost → timeout → Kill |
| DLL injection | EXE process protected by C# compilation, watchdog unaffected |

### 8.6 C# Embedded Integrity Guard (AuroraGuard) 🆕

> Embedded runtime-compiled C# IL code block `AuroraGuard` in LauncherGUI.ps1 performing independent SHA256 integrity verification of 16 core sub-modules. Compiled to IL instructions makes analysis and modification significantly harder. Cross-Runspace visible.

#### 8.6.1 Code Architecture

```csharp
Add-Type @"
using System;
using System.IO;
using System.Security.Cryptography;

public class AuroraGuard
{
    private static readonly Dictionary<string, string> _expected = new Dictionary<string, string>
    {
        // 🆕 Hashes auto-injected by build.ps1 [2.5/6] at build time
        {"Scripts\\AURORA-SmartEngine.ps1", "AG_PLACEHOLDER_AURORA_SMART_ENGINE..."},
        // ... 16 modules total
    };

    public static bool VerifyOrDie()
    {
        string baseDir = AppDomain.CurrentDomain.BaseDirectory;
        int violations = 0;
        
        foreach (var kv in _expected)
        {
            string filePath = Path.Combine(baseDir, kv.Key);
            if (!File.Exists(filePath)) { violations++; continue; }
            
            using (var sha256 = SHA256.Create())
            using (var stream = File.OpenRead(filePath))
            {
                byte[] hash = sha256.ComputeHash(stream);
                string hashString = BitConverter.ToString(hash).Replace("-", "");
                if (!string.Equals(hashString, kv.Value, StringComparison.OrdinalIgnoreCase))
                    violations++;
            }
        }
        return violations == 0;
    }
}
"@ -ReferencedAssemblies "System.Core"
```

#### 8.6.2 Verification Coverage

| # | Protected File | Module Responsibility |
|:--:|-----|---|
| 1 | `Scripts\AURORA-SmartEngine.ps1` | Smart diagnostic engine |
| 2 | `Scripts\AURORA-CoreEngine.ps1` | Shared core engine |
| 3 | `Scripts\AURORA-AnalyzerCHSPRO.ps1` | Chinese PRO export |
| 4 | `Scripts\AURORA-ProgressManager.ps1` | Progress persistence mgmt |
| 5 | `Scripts\AURORA-GUI-Functions.ps1` | GUI helper functions |
| 6 | `Scripts\AURORA-RepairTools.ps1` | Repair toolset |
| 7 | `Scripts\AURORA-UndoManager.ps1` | Undo management |
| 8 | `Scripts\AURORA-RestoreManager.ps1` | System restore |
| 9 | `Scripts\AURORA-RepairLogger.ps1` | Repair log audit |
| 10 | `Scripts\AURORA-UndoViewer.ps1` | Repair history viewer |
| 11 | `Scripts\AURORA-AnalyzerPRO.ps1` | PRO mode entry |
| 12 | `Scripts\AURORA-ProgressManager-Integration.ps1` | Progress integration bridge |
| 13 | `Scripts\AURORA-ProgressManager-Integration-CHS.ps1` | Chinese progress integration |
| 14 | `Scripts\AURORA-ProgressManager-Integration-ENG.ps1` | English progress integration |
| 15 | `Scripts\Core\AURORA-AnimationCoreEngine.ps1` | Animation engine |
| 16 | `Data\AURORA-TechData.json` | Diagnostic knowledge base |

#### 8.6.3 Technical Characteristics

- **Cross-Runspace visible**: `Add-Type` defines the type for the entire PowerShell session
- **Callable**: `[AuroraGuard]::VerifyOrDie()` accessible from any sub-module
- **Graceful degradation**: Does not affect normal functionality if loading fails
- **Build-time injection**: Hashes auto-replaced at `build.ps1 [2.5/6]`
- **IL-level protection**: Compiled code hard to discover and modify via text search

### 8.7 Elevation Security Token (AURORA-SEC-2026-001) 🆕

> **P0 Security Fix.** See [Section 5.4](#54-smart-permission-management--elevation-security-token) for details.

- AES-256-CBC encrypted hash list
- 120-second independent expiration window
- Passed via command-line argument (bypasses UAC environment variable clearing)
- Deleted immediately after successful verification

### 8.8 Anti-Spoofing Launch Parameter Protection 🆕

```
Detection Logic:
  if (IsLaunchedByExe == true AND PassedHashListFromExe == null)
      → Reset IsLaunchedByExe = false
      → Clear all environment variable markers
      → Force password verification path
```

---

## 9. Build System

### 9.1 build.ps1 Full Process

```
[1/6] Initialize build environment
[2/6] Write C# source to LauncherBuilder
    [2.5/6] 🆕 Inject AuroraGuard SHA256 hashes
[3/6] Compile C# source → AURORA.Launcher-双击启动.exe
[4/6] Build Scripts\ directory
[5/6] 🆕 Smart security code injection
[6/6] Package → ZIP release
```

### 9.2 C# Obfuscation Compilation

`build.ps1` uses `csc.exe` (C# Compiler) to compile the launcher. Compilation target forced to x86 platform. Class and method names offline-renamed before compilation.

### 9.3 AuroraGuard Hash Injection (2.5/6) 🆕

> **New in v1.1.24.1:** build.ps1 adds step `[2.5/6]` to auto-inject AuroraGuard hashes.

```powershell
# [2.5/6] Inject AuroraGuard SHA256 hashes
$auroraGuardPlaceholders = @{
    "AG_PLACEHOLDER_AURORA_SMART_ENGINE"             = $hashes["Scripts\AURORA-SmartEngine.ps1"]
    "AG_PLACEHOLDER_AURORA_CORE_ENGINE"              = $hashes["Scripts\AURORA-CoreEngine.ps1"]
    # ... 16 placeholders total
}

foreach ($kv in $auroraGuardPlaceholders.GetEnumerator()) {
    $launcherGuiContent = $launcherGuiContent -replace $kv.Key, $kv.Value
}
```

### 9.4 Packaging & Distribution

After build completion, `build.ps1` auto-packages into `AURORA-AnalyzerV1.1.24.1Release.zip`.

---

## 10. Internationalization Architecture

`AURORA-Language.psd1` is the centralized bilingual resource file with 144 translation entries.

Key naming convention: `Section_Category_Key`

```powershell
@{
    Nav_LogExport_zh    = "日志导出"
    Nav_LogExport_en    = "Log Export"
    # 🆕 Watchdog messages
    Watchdog_Connected_zh  = "安全守护已建立"
    Watchdog_Connected_en  = "Security watchdog established"
    Watchdog_Failed_zh     = "安全守护连接失败"
    Watchdog_Failed_en     = "Security watchdog connection failed"
}
```

---

## 11. Performance vs. Security Trade-off Design — LastWriteTime Optimization 🆕

> **New in v1.1.24.1:** Introduces LastWriteTime pre-check in the integrity check loop to resolve sustained CPU usage from continuous SHA256 computation.

```powershell
$lastKnownWriteTimes = @{}

foreach ($file in $coreFileList) {
    $currentLWT = (Get-Item $fullPath).LastWriteTimeUtc
    
    if ($lastKnownWriteTimes.ContainsKey($file) -and 
        $currentLWT -eq $lastKnownWriteTimes[$file]) {
        continue  # Skip SHA256, saves ~50-200ms/file
    }
    
    $lastKnownWriteTimes[$file] = $currentLWT
    $currentHash = (Get-FileHash $fullPath -Algorithm SHA256).Hash
    
    if ($currentHash -ne $expectedHashes[$file]) {
        $violations += "File tampered: $file"
    }
}
```

**Security Trade-off Analysis:**
- LastWriteTime can be forged (`SetFileTime` API), but SHA256 verification still triggers on forged timestamps
- Timestamp pre-check is a **performance optimization**, not a **security replacement**
- Even if an attacker forges LastWriteTime, SHA256 catches it on the first comparison
- FileSystemWatcher real-time monitoring covers all file write events

---

## 12. Error Handling & Logging

- All scripts use Try-Catch-Finally blocks
- Error messages in bilingual output
- Security exceptions logged separately

---

> **Document Version**: V1.1.24.1
> **Date**: 2026-05-27
> **Author**: AURORA VelociRaptor-GR Dev PRJ.
> **License**: For personal learning and research use only