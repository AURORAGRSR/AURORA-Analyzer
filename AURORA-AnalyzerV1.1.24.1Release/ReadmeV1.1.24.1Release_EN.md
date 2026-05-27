# AURORA Analyzer V1.1.24.1 — User Manual

> **Target Audience**: General Users / System Administrators / IT Operations
> **Document Purpose**: Ultra-detailed feature guide, easy to read and understand, focusing on functionality and practical value

***

## Table of Contents

- [1. Welcome to AURORA Analyzer](#1-welcome-to-aurora-analyzer)
- [2. Quick Start](#2-quick-start)
  - [2.1 System Requirements](#21-system-requirements)
  - [2.2 Installation & Launch](#22-installation--launch)
  - [2.3 Interface Overview](#23-interface-overview)
- [3. Log Export](#3-log-export)
  - [3.1 Supported Log Types](#31-supported-log-types)
  - [3.2 Export Range Selection](#32-export-range-selection)
  - [3.3 Advanced Filtering](#33-advanced-filtering)
  - [3.4 Export Formats](#34-export-formats)
  - [3.5 Viewing Export Results](#35-viewing-export-results)
- [4. Smart Diagnosis](#4-smart-diagnosis)
  - [4.1 What Is Smart Diagnosis](#41-what-is-smart-diagnosis)
  - [4.2 Five Diagnostic Categories Explained](#42-five-diagnostic-categories-explained)
  - [4.3 BSOD Analysis](#43-bsod-analysis)
  - [4.4 Reading Diagnostic Reports](#44-reading-diagnostic-reports)
- [5. System Repair](#5-system-repair)
  - [5.1 Supported Repair Types](#51-supported-repair-types)
  - [5.2 Pre-Repair Protection](#52-pre-repair-protection)
  - [5.3 How to Execute Repairs](#53-how-to-execute-repairs)
- [6. Undo & Restore](#6-undo--restore)
  - [6.1 Undoing Repair Operations](#61-undoing-repair-operations)
  - [6.2 Viewing Repair History](#62-viewing-repair-history)
  - [6.3 System Restore Points](#63-system-restore-points)
- [7. Progress Management & Resume](#7-progress-management--resume)
  - [7.1 Auto-Save Sessions](#71-auto-save-sessions)
  - [7.2 Resuming Interrupted Tasks](#72-resuming-interrupted-tasks)
- [8. What's New in v1.1.24.1](#8-whats-new-in-v11241)
  - [8.1 Security Upgrade: Five-Layer Defense-in-Depth](#81-security-upgrade-five-layer-defense-in-depth)
  - [8.2 Performance Optimizations](#82-performance-optimizations)
  - [8.3 Stability Fixes](#83-stability-fixes)
- [9. FAQ & Common Scenarios](#9-faq--common-scenarios)
  - [9.1 How to Diagnose Frequent BSODs](#91-how-to-diagnose-frequent-bsods)
  - [9.2 How to Diagnose a Slow System](#92-how-to-diagnose-a-slow-system)
  - [9.3 How to Check for Intrusions](#93-how-to-check-for-intrusions)
  - [9.4 Exporting Logs for Technical Support](#94-exporting-logs-for-technical-support)
- [10. Performance Tiers](#10-performance-tiers)
- [11. Language Switching](#11-language-switching)
- [12. Security & Privacy](#12-security--privacy)
- [13. Support & Feedback](#13-support--feedback)

***

## 1. Welcome to AURORA Analyzer

**AURORA Analyzer** is a powerful Windows system diagnostics and log analysis tool. Its core mission is to help you:

| Need            | What AURORA Analyzer Does For You                        |
| ------------- | -------------------------------------------- |
| 🔍 **Diagnose System Issues** | Automatically scan system logs to identify root causes of BSODs, crashes, and slowdowns |
| 📊 **Export System Logs** | Export Windows event logs to CSV / JSON / XML format for easy analysis |
| 🔧 **One-Click Repair** | Automatically fix Windows Update issues, Defender misconfigurations, network anomalies and more |
| 📋 **Health Reports** | Generate detailed system health assessment reports with trend analysis and recommendations |
| ↩️ **Safe Rollback** | Auto-create backups and system restore points before each repair, ensuring you can always undo |
| 🛡️ **Security Auditing** | Check security logs for brute-force login attempts, privilege escalation, and more |

### Core Value

- **No more digging through thousands of log entries in Event Viewer** — AURORA Analyzer filters and analyzes for you
- **No more Googling BSOD codes** — Automatically parses Minidump files and tells you which driver caused the crash
- **Mistakes are reversible** — Every repair is automatically backed up, one-click undo
- **Export progress is never lost** — Even if you close the program, resume from where you left off next time
- **Five-layer defense-in-depth** — Tamper-proof from build to runtime, with bank-grade security protection

***

## 2. Quick Start

### 2.1 System Requirements

| Item                 | Minimum               | Recommended         |
| ------------------ | ------------------ | ---------------- |
| **OS**           | Windows 10 (1809+) | Windows 11 22H2+ |
| **.NET Framework** | 4.7.2              | 4.8+             |
| **PowerShell**     | 5.1 (built-in)           | PowerShell 7+    |
| **RAM**             | 4 GB               | 8 GB+            |
| **Disk Space**           | 100 MB             | 500 MB+ (for log export) |
| **Permissions**             | Standard user               | Administrator (full features)      |

> 💡 **Tip**: Most features work with standard user permissions. Only exporting security logs and system repairs require admin rights — the program will prompt you for elevation automatically.

### 2.2 Installation & Launch

**Just two steps:**

1. **Extract** `AURORA-AnalyzerV1.1.24.1Release.zip` to any directory
2. **Double-click** `AURORA.Launcher-双击启动.exe` to launch

> ⚠️ **Note**:
>
> - Do not modify or delete any files in the program directory, or the program will refuse to launch
> - If your antivirus blocks it on first run, add an exception (this tool contains no malicious code)
> - Do not run directly from within the archive — always extract first

**After launching you will see:**

- A main interface with a starfield animation background
- A top menu bar for switching between function modules
- A bottom status bar showing current system info and performance tier

### 2.3 Interface Overview

```
┌─────────────────────────────────────────────────┐
│  AURORA Analyzer V1.1.24.1          [— □ ✕]     │
├─────────────────────────────────────────────────┤
│  [Log Export] [Diagnosis] [Repair] [History] [Settings] │
├─────────────────────────────────────────────────┤
│                                                 │
│         Main content area (changes based on selected module) │
│         · Log type selection                    │
│         · Date range selection                  │
│         · Progress bar                          │
│         · Action buttons                        │
│                                                 │
├─────────────────────────────────────────────────┤
│  Status: Ready  |  Admin: Yes/No  |  Language: English  │
└─────────────────────────────────────────────────┘
```

***

## 3. Log Export

This is AURORA Analyzer's most core function — helping you export Windows system event logs for analysis.

### 3.1 Supported Log Types

AURORA Analyzer supports exporting **8 types** of Windows event logs:

| Log Type                   | Contents                  | Typical Use               |
| ---------------------- | --------------------- | -------------------- |
| **System**        | Service start/stop, driver loading, kernel events   | Troubleshoot BSODs, system crashes, driver issues       |
| **Application** | App crashes, errors, installation events          | Troubleshoot app crashes, installation failures          |
| **Security**      | Login audit, privilege changes, account management        | Security auditing, intrusion detection         |
| **Setup**         | Windows update installation, component installation     | Troubleshoot Windows Update failures |
| **DNS Server**            | DNS query and resolution records           | DNS troubleshooting             |
| **DHCP Server**           | DHCP IP address assignment records        | Network address allocation issues             |
| **Directory Service**               | Active Directory domain controller events | Enterprise domain management              |
| **IIS Admin**             | IIS Web server management events       | Web server operations            |

> 💡 **Most common choice**: If you're unsure, start with "System" logs — they contain 90% of everyday problem information.

### 3.2 Export Range Selection

Three export range options:

**① Single Day Export** — Export all logs for a specific day. Best for "what went wrong today".

**② Date Range Export** — Export logs from a start date to an end date. Best for analyzing trends over a period.

**③ Force Rescan** — Ignore previous cache and re-export from scratch. Use when you suspect the previous export was incomplete.

### 3.3 Advanced Filtering

If you only need specific types of events, use advanced filtering:

| Filter              | Purpose         | Example                               |
| ---------------- | ---------- | -------------------------------- |
| **EventID**      | Export only specific event IDs  | `1001, 41, 6008` (system diagnostics + unexpected shutdowns)    |
| **ProviderName** | Export only events from a specific source | `Microsoft-Windows-Kernel-Power` |
| **Level**        | Export only events of a specific level | `Critical`, `Error`    |

**Level Descriptions:**

| Level          | Meaning      | Example            |
| ----------- | ------- | ------------- |
| Critical    | System-level critical error | Kernel crash, unexpected shutdown     |
| Error       | Component runtime error  | Service start failure, app crash   |
| Warning     | Potential issue warning  | Low disk space, driver nearing expiration |
| Information | General operation record  | Service started successfully, update installed |
| Verbose     | Debug-level detail | Developer debugging logs   |

> 💡 **Tip**: When troubleshooting, start with `Critical + Error`. Expand to `Warning` if no cause is found.

### 3.4 Export Formats

Each export automatically generates multiple file formats:

| File              | Format         | Use                 | Open With                       |
| --------------- | ---------- | ------------------ | --------------------------- |
| `*_Log_*.csv`    | CSV Table     | Data analysis and charting in Excel | Excel / WPS / Google Sheets |
| `*_Log_*.json`   | JSON Structured Data | Programmatic processing, import into other tools        | Any text editor / programming language              |
| `*_Log_*.xml`    | XML Structured Data  | Windows Event Viewer compatible  | Event Viewer / Browser                 |
| `*_Log_*_Summary.txt` | Plain Text Summary      | Quick overview             | Notepad / any text editor               |
| `*_Trend_Analysis.txt`    | Plain Text Report      | View event trends and distribution          | Notepad / any text editor               |
| `*_Trend_Data.csv`    | CSV Data     | Raw trend analysis data           | Excel / WPS                 |

**Output Location**: All files are saved in the `UserLogs\` folder within the program directory.

### 3.5 Viewing Export Results

After export, you can:

1. **View directly in the program**: A summary window pops up after completion
2. **Open folder**: Click the "Open Output Folder" button
3. **Analyze in Excel**: Double-click the CSV file to sort by EventID, filter by time range, or create pivot tables

***

## 4. Smart Diagnosis

### 4.1 What Is Smart Diagnosis

Smart Diagnosis is the "brain" of AURORA Analyzer. Unlike traditional tools that just list logs, it **automatically analyzes log content to find problems and provide fix recommendations**.

**Diagnosis Flow:**

```
① Scan system logs
    ↓
② Lock onto anomaly time windows (around crashes, after boots)
    ↓
③ Match 100+ diagnostic rules
    ↓
④ Analyze BSOD dump files (Minidump)
    ↓
⑤ Generate diagnostic report
    ↓
⑥ Recommend repair actions
```

**Diagnostic report includes:**

- List of discovered issues (sorted by severity)
- Detailed description of each issue (time, frequency, impact)
- Root cause analysis
- Recommended repair actions

### 4.2 Five Diagnostic Categories Explained

#### 🅰️ System Stability

| Diagnostic Item               | What It Detects         | Common Causes            |
| --------------------- | ------------ | --------------- |
| **Unexpected Shutdowns**              | Frequent unexpected power loss   | Power issues, CPU overheating, motherboard failure |
| **System Service Crashes**            | Core services stopping repeatedly   | System file corruption, driver conflicts     |
| **Kernel Power Anomalies**            | CPU power/frequency anomalies | Improper power settings, insufficient cooling     |
| **Windows Update Failures** | Repeated update failures   | Update component corruption, network issues     |
| **Disk File System Errors**          | Disk read/write errors   | Bad sectors, loose data cable      |
| **System Time Drift**            | Abnormal clock drift   | CMOS battery exhaustion, motherboard issue   |

#### 🅱️ Application Errors

| Diagnostic Item          | What It Detects             | Common Causes         |
| ------------ | ---------------- | ------------ |
| **App Crashes**     | Frequent .NET app crashes    | Missing runtimes, insufficient permissions   |
| **App Hangs**     | Frequent unresponsiveness        | Low memory, deadlocks, resource conflicts |
| **WMI Errors**   | Windows Management Instrumentation failures | WMI repository corruption    |
| **COM Errors** | COM component call failures     | Registry corruption, missing DLLs |

#### 🅲 Driver Issues

Driver issues are the most common cause of BSODs:

| Diagnostic Item        | What It Detects        | Common Causes             |
| ---------- | ----------- | ---------------- |
| **Driver Load Failure** | Drivers failing to load    | Driver signing issues, incompatibility       |
| **GPU Driver Timeout** | GPU driver frequent resets  | GPU overheating, driver version incompatibility, overclocking  |
| **Network Driver Error** | NIC driver anomalies    | Driver version issues, NIC hardware failure    |
| **Storage Driver Error** | Storage controller driver errors | Driver conflicts, RAID configuration error |

#### 🅳 Hardware Failure Warning

Detect issues before hardware fails completely:

| Diagnostic Item             | What It Detects           | Recommended Action                 |
| --------------- | -------------- | -------------------- |
| **Disk SMART Warning** | Disk self-reporting health issues     | ⚠️ **Backup data immediately**, prepare disk replacement |
| **Disk Bad Sectors**        | Bad sectors appearing       | Run chkdsk, backup important files     |
| **Memory ECC Corrections**        | Frequent ECC corrections   | Check RAM sticks, may need replacement         |
| **CPU Thermal Throttling**    | CPU throttling due to overheating | Clean dust, check cooling fan          |
| **NIC Frequent Resets**      | NIC repeatedly disconnecting/resetting     | Update NIC driver, check cable          |

#### 🅴 Security Event Audit

| Diagnostic Item         | What It Detects          | Severity            |
| ----------- | ------------- | --------------- |
| **Brute Force Logins**    | Repeated login attempts   | 🔴 Critical — potential ongoing attack |
| **Privilege Escalation**    | Unauthorized privilege elevation | 🟡 Warning — possible malware |
| **Audit Log Cleared**  | Security log has been cleared    | 🔴 Critical — typical intrusion evidence |
| **Firewall Rule Changes** | Firewall rules modified    | 🟡 Warning — verify legitimacy  |
| **Account Creation/Deletion** | Unknown account changes     | 🟡 Warning — check account origin  |

### 4.3 BSOD Analysis

When your computer blue screens, AURORA Analyzer can:

1. **Automatically scan** `C:\Windows\Minidump\` folder for dump files
2. **Parse** dump file headers to extract: crash time, BugCheck code, likely offending driver, running process at the time
3. **Match** against the knowledge base of known BSOD causes
4. **Recommend** updating/uninstalling the offending driver or performing system repairs

### 4.4 Reading Diagnostic Reports

Diagnostic reports use colors and icons to indicate severity:

| Icon | Level     | Meaning     | What You Should Do     |
| -- | ------ | ------ | ---------- |
| 🔴 | **Critical** | Needs immediate attention | Follow the repair recommendation immediately |
| 🟠 | **High**  | Clear issue exists | Address soon to prevent escalation  |
| 🟡 | **Medium**  | Potential risk   | Understand the cause, address when convenient  |
| 🔵 | **Low**  | Optimization suggestion   | Optional, does not affect usage |

***

## 5. System Repair

### 5.1 Supported Repair Types

AURORA Analyzer can help you one-click fix these common system problems:

#### 🔧 Disable Windows Update (temporarily pause auto-updates)

- Stops Windows Update service, disables auto-update scheduled tasks, modifies group policy settings

#### 🔧 Enable Windows Defender (restore antivirus)

- Restores Defender service to auto-start, removes third-party registry restrictions, restarts related security services

#### 🔧 Disable Telemetry & Data Collection

- Disables Connected User Experiences and Telemetry service, sets telemetry level to "Security" (minimum), disables related scheduled tasks

#### 🔧 Reset Network Settings

- Resets Winsock catalog, resets TCP/IP stack, flushes DNS cache, resets Windows Firewall rules

#### 🔧 System Cleanup

- Clears temporary files, empties Recycle Bin, cleans Windows Update cache, cleans thumbnail cache

### 5.2 Pre-Repair Protection

**Your safety is our top priority.** Before each repair, AURORA Analyzer automatically:

```
├─ ✅ Create System Restore Point
│     └── Roll back the entire system state in Windows Recovery Environment
│
├─ ✅ Create Quick Backup Snapshot
│     ├── Backup registry keys about to be modified
│     ├── Backup files about to be modified
│     └── Record current service states
│
├─ ✅ Record Audit Log
│     └── Detailed record: who, when, what, result
│
└─ ✅ Risk Assessment
      └── High-risk operations require additional confirmation
```

> 🛡️ **Dual protection**: Even if one recovery method fails, the other can still help you roll back.

### 5.3 How to Execute Repairs

1. Click the **"System Repair"** tab
2. Select the repair type from the list
3. Click **"Execute Repair"**
4. Confirm risk warning (if any)
5. Wait for repair to complete
6. View the repair result report

***

## 6. Undo & Restore

"Being able to undo mistakes" is one of AURORA Analyzer's core design principles.

### 6.1 Undoing Repair Operations

1. Click the **"Repair History"** tab
2. Find the repair operation you want to undo
3. Select the record, click **"Undo This Operation"**
4. Confirm the undo
5. The system restores all modified registry keys, files, and services in reverse order

### 6.2 Viewing Repair History

The repair history viewer shows:

| Column             | Content                           |
| ------------- | ---------------------------- |
| **Time**        | Precise time of repair execution                    |
| **Operation**        | Type of repair performed                      |
| **Result**        | ✓ Success / ✗ Failed / ⚠ Partial / ↩ Reverted |
| **Details**        | What was repaired                      |
| **SessionId** | Unique identifier (useful for technical support)                 |

### 6.3 System Restore Points

If you chose to use system restore points as protection:

- Search "Create a restore point" in Windows
- Click "System Restore"
- Select the restore point created by AURORA Analyzer
- Follow the wizard to roll back

> ⚠️ **Note**: System restore points roll back the entire system to the state when the point was created.

***

## 7. Progress Management & Resume

### 7.1 Auto-Save Sessions

When exporting large volumes of logs (e.g., 6 months of system logs), it can take a long time. AURORA Analyzer automatically saves progress:

- Checkpoints are recorded after **each data chunk** is processed
- Progress is never lost even if the program closes unexpectedly
- Session files are saved in `Scripts\SessionCache\active\`

### 7.2 Resuming Interrupted Tasks

If the program closes during an export (due to crash, shutdown, or manual closure), it will:

1. Auto-detect the unfinished session
2. Prompt "Found unfinished task, continue?"
3. Selecting "Continue" resumes from the interruption point
4. Already exported data is not reprocessed

> 💡 **Practical scenario**: Power goes out while exporting 5 million log entries. After power returns, relaunch the program, click "Continue" — and it picks up right where it left off.

***

## 8. What's New in v1.1.24.1

v1.1.24.1 introduces significant security hardening on top of v1.1.24.0. Key changes include:

### 8.1 Security Upgrade: Five-Layer Defense-in-Depth

v1.1.24.0 established a four-layer defense-in-depth system. v1.1.24.1 adds a **fifth layer — Watchdog Guardian**, achieving full tamper-proof protection from build to runtime.

#### 🛡️ New Fifth Layer: Independent Watchdog Guardian

- An independent "heartbeat" communication pipe is established between the EXE and PowerShell script
- Even if an attacker bypasses all PowerShell-level verifications, the EXE-side watchdog still independently detects anomalies
- After 3 consecutive heartbeat anomalies, the process is forcefully terminated

**What this means for you:** Your tool now has "bodyguard"-level security — even if someone tries to tamper with the program at runtime, the watchdog will detect and stop it within seconds.

#### 🔍 C# Embedded Integrity Verification

- New C# code block compiled into machine instructions performs integrity verification on 16 core functional modules
- Compiled IL code is significantly harder to analyze and modify than regular script code
- Current version hash values are automatically injected at build time, ensuring "this version verifies these files"

**What this means for you:** Core functional modules of the program are protected at the compiled-code level — attackers cannot bypass security checks by simply modifying script code.

#### 🔐 Elevation Security Token

- Fixed a security verification vulnerability that could occur during admin privilege operations
- An independent security token is generated when performing operations requiring admin rights
- 120-second independent validity period ensures the elevated process can still correctly verify identity

**What this means for you:** When using admin rights to export security logs, the program's identity verification is not interrupted — continuous protection throughout.

#### 🚫 Anti-Spoofing Launch Parameter Protection

- Fixed a vulnerability where attackers could bypass all security verification by forging launch parameters
- If forged launch parameters are detected, the program forces a security state reset

**What this means for you:** Even if advanced attackers try to deceive the program through command-line arguments, it will be immediately detected and refused.

### 8.2 Performance Optimizations

- **Integrity check CPU usage reduced by up to 95%**: New file modification time pre-check — only computes full hashes when files actually change
- **Near-zero CPU overhead during stable runtime**: Skips expensive SHA256 calculations for unmodified files
- **More stable alert window**: Switched to C# native controls, resolving countdown instability issues

### 8.3 Stability Fixes

- Fixed a P0-level issue where security verification could break during admin elevation
- Fixed errors caused by duplicate component loading in certain scenarios
- Optimized security cleanup logic for exception scenarios
- Improved countdown display stability in alert windows

***

## 9. FAQ & Common Scenarios

### 9.1 How to Diagnose Frequent BSODs

**Scenario**: Computer blue-screens 1-2 times daily lately.

**Steps using AURORA Analyzer:**

1. Open the program, click **"Smart Diagnosis"**
2. Click **"Start Diagnosis"**
3. The program automatically: scans BSOD records in system logs (EventID 41, 1001), analyzes Minidump dump files, checks driver load/unload events around BSODs
4. Check the diagnosis report, focusing on: **BSOD code**, **suspected offending driver**, **BSOD frequency trend**
5. Update or roll back the offending driver based on recommendations

**Common BSOD Code Quick Reference:**

| BSOD Code | Possible Cause | Recommendation |
| ------------------------------- | --------- | --------------- |
| `DRIVER_IRQL_NOT_LESS_OR_EQUAL` | Driver conflict | Update/rollback driver |
| `MEMORY_MANAGEMENT` | Memory fault | Run memory diagnostics |
| `KERNEL_SECURITY_CHECK_FAILURE` | Driver/system file corruption | Run sfc /scannow |
| `CRITICAL_PROCESS_DIED` | Critical process crash | Check disk/system files |
| `DPC_WATCHDOG_VIOLATION` | Storage driver issue | Update SSD firmware/driver |

### 9.2 How to Diagnose a Slow System

1. Click **"Log Export"** → Select "System" → Choose last month's date range → Filter `Warning` + `Error` only
2. Export and open CSV, focusing on: EventID 10010 (COM timeout), 153 (disk retries), 129 (storage driver resets), 7011 (service timeout)
3. Then use **"Smart Diagnosis"** for automated analysis

### 9.3 How to Check for Intrusions

1. Click **"Smart Diagnosis"** → View **Category E (Security Event Audit)** report
2. Focus on: EventID 4625 (excessive login failures = brute force), 4624 LogonType=10 (RDP connections), 4720/4726 (account changes), 1102 (audit log cleared — ⚠️ highly suspicious)
3. If anomalies found: disconnect from network, change all passwords, run full virus scan, export diagnostic report for security professionals

### 9.4 Exporting Logs for Technical Support

1. Click **"Log Export"** → Select "Application" → Enter the problem time range → Advanced filter: ProviderName = vendor name, Level = Error + Warning → Export
2. Package all files from the `UserLogs` folder and send to technical support

***

## 10. Performance Tiers

AURORA Analyzer automatically evaluates your computer's performance at startup and adjusts animations and resource usage. No manual configuration needed.

| Tier                 | Suitable For                  | Animation         | Notes           |
| -------------------- | --------------------- | ------------ | ------------ |
| **Extreme**     | 8 cores+ / 16GB+ / 3.5GHz+ | Full starfield, 60FPS | High-end gaming / workstation |
| **Performance** | 4-8 cores / 8-16GB         | Smooth animation, 45FPS   | Mid-to-high-end PC        |
| **Balanced**    | 2-4 cores / 4-8GB          | Basic animation, 30FPS   | Standard office PC       |
| **Eco**         | Low-spec / VM              | Simplified animation, 20FPS   | Older devices / VMs   |

> 💡 Performance tier **does not affect** core log export and diagnosis functionality — only UI animation smoothness.

***

## 11. Language Switching

AURORA Analyzer supports bilingual Chinese and English interfaces.

**How to switch:**

1. Click the **"Settings"** tab
2. Select **"中文"** or **"English"** under language settings
3. UI switches instantly, no restart needed

> 💡 Language switching affects all interface text, export file names, diagnostic reports, etc.

***

## 12. Security & Privacy

### How We Protect Your Data

| Protection      | Description                 |
| --------- | ------------------ |
| **Local Only**  | All operations are performed locally, no internet connection    |
| **No Data Upload** | Your log data is never sent to any server    |
| **No Data Collection** | No personal or system information is collected     |
| **File Encryption**  | Core configuration files are stored encrypted         |
| **Tamper Protection**   | Five-layer defense-in-depth: tamper-proof, debug-proof, injection-proof |
| **Watchdog Guardian** | Independent EXE process monitoring, real-time anomaly detection |

### What You Should Know

- Exported log files (CSV/JSON/XML) are stored in **plain text** — keep them secure
- If you exported security logs, they may contain your computer name and username
- Before sharing diagnostic reports, verify they don't contain sensitive information
- It is recommended to delete files in the `UserLogs` folder when not in use

***

## 13. Support & Feedback

### Version Information

| Item   | Content                              |
| ---- | ------------------------------- |
| Current Version | **V1.1.24.1**                   |
| Build Date | 2026-05-27                      |
| Author   | AURORA VelociRaptor-GR Dev PRJ. |

### Having Issues?

If you encounter problems:

1. **Check first**: Are all files properly extracted? Is the directory structure intact?
2. **Key files**: Ensure `AURORA.Launcher-双击启动.exe` and `GAURORA.CHK.ENC` are in the same directory
3. **Permission issues**: Try running as administrator
4. **Antivirus**: Add the program directory to your antivirus whitelist

### License Statement

This software is for **personal learning and research use only**. Commercial use is prohibited.

***

> **Document Version**: V1.1.24.1
> **Date**: 2026-05-27
> **Author**: AURORA VelociRaptor-GR Dev PRJ.
> **License**: For personal learning and research use only