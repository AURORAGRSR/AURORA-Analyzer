# AURORA Analyzer v1.1.22.0 Developer Documentation

> **Windows Event Log Export · Intelligent Diagnostics · Autonomous Repair Engine**
>
> **Version**: 1.1.22.0 | **Build Date**: 2026.05.14 | **Author**: AURORA VelociRaptor-GR Dev PRJ.

***

## Project Overview

AURORA Analyzer is a comprehensive event log analysis, intelligent diagnostics, and autonomous repair toolchain for Windows systems. It exports high-risk events (Critical/Error/Warning) from Windows Event Log, generates structured reports (CSV/JSON/XML/TXT), and performs pattern matching against a local knowledge graph to automatically provide executable repair commands.

The project uses a **PowerShell 5.1 + C# Inline Compilation** hybrid architecture. All components are single-file self-contained designs, using synchronized hash tables (`syncHash`) for real-time inter-process communication across Runspaces.

***

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│               AURORA.Launcher-双击启动.exe               │
│          (C# Compiled Windowless EXE Launcher)           │
│          SHA256 Integrity Check + AES-256-CBC Decrypt    │
└─────────────────────┬────────────────────────────────────┘
                      │ Environment Variable AURORA_LAUNCHED_BY_EXE=1
                      ▼
┌──────────────────────────────────────────────────────────┐
│          AURORA-AnalyzerLauncherGUI.ps1                   │
│          (WinForms GUI Main Controller, ~40K Lines)       │
│  · Hardware Performance Tier Probe (AuroraPerfTier)       │
│  · Password Verification Entry (GAURORA.CHK.ENC AES)     │
│  · C# Inline Compiled Custom Controls                    │
│  · Particle Animation Engine / Starfield Background      │
│  · Session Recovery (AuroraRestoreModal)                  │
│  · Authorization Decision Modal (AuroraDecisionModal)    │
│  · Runspace Sub-thread Task Scheduling                    │
└──┬──────────────┬──────────────────┬─────────────────────┘
   │              │                  │
   ▼              ▼                  ▼
┌──────────┐ ┌──────────┐ ┌────────────────────────┐
│ CHSPro   │ │ ENGPro   │ │  AURORA-SmartEngine    │
│ .ps1     │ │ .ps1     │ │  .ps1 (V1.1.31Release) │
│ ~=CN Ver │ │ ~=EN Ver │ │  4-Phase Diagnostic    │
└────┬─────┘ └────┬─────┘ └───────────┬────────────┘
     │            │                   │
     └────────────┼───────────────────┘
                  │
     ┌────────────┼────────────┐
     ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────────────┐
│Progress  │ │Integr    │ │AURORA-TechData   │
│Manager   │ │-CHS/ENG  │ │.json (V3.1)      │
└──────────┘ └──────────┘ └──────────────────┘
```

***

## Module Details

### 1. AURORA-AnalyzerLauncherGUI.ps1 (GUI Main Controller)

**Version**: V1.1.19.5Release | **Lines**: \~40,000

#### Startup Flow

| Step | Function                   | Technical Implementation                                                   |
| ---- | -------------------------- | -------------------------------------------------------------------------- |
| ①    | Hardware Performance Probe | `Get-CimInstance Win32_Processor / Win32_ComputerSystem`, weighted scoring |
| ②    | Password Verification      | AES-256-CBC decrypt `GAURORA.CHK.ENC`, SHA256 key derivation               |
| ③    | C# Control Compilation     | `Add-Type` inline compile AuroraProgressBar, TechButton, etc.              |
| ④    | GUI Form Construction      | WinForms borderless window, DPI-aware, Win32 API drag support              |
| ⑤    | User Interaction           | Log type selection, date range, export mode, trend analysis toggle         |

#### Hardware Performance Tiering (`AuroraPerfTier`)

```powershell
$perfScore = ($logicalCores × 15) + ($ramGB × 5) + max(0, (baseClock - 2000) / 100)
```

| Tier            | Score | Configuration  | Rendering Features                                      |
| --------------- | ----- | -------------- | ------------------------------------------------------- |
| **Extreme**     | ≥240  | 8-core+ 32G+   | 600 stars / 150 particles / complex halo / dynamic scan |
| **Performance** | ≥120  | 6-core 16G     | 350 stars / 80 particles / halo on / dynamic scan       |
| **Balanced**    | ≥70   | 4-core 8G      | 180 stars / 30 particles / shadow on                    |
| **Eco**         | <70   | Legacy devices | 80 stars / no particles / basic mode                    |

#### C# Inline Custom Controls

| Control                    | Function                                                                       |
| -------------------------- | ------------------------------------------------------------------------------ |
| `AuroraProgressBar`        | Rounded gradient progress bar with halo scan animation and particle system     |
| `TechButton`               | Tech-style dynamic button                                                      |
| `AuroraRenderEngine`       | Static rendering engine, precomputes FPS/particle count based on hardware tier |
| `AuroraPrivilegeIndicator` | Administrator privilege status indicator                                       |
| `AuroraTaskHUD`            | Real-time task execution heads-up display (pipeline step visualization)        |
| `AuroraResultModal`        | Command execution result modal popup                                           |
| `AuroraDecisionModal`      | High-risk operation authorization decision popup                               |
| `AuroraRestoreModal`       | Incomplete session recovery popup                                              |
| `AuroraConsoleBox`         | Embedded console output box (smart log echo)                                   |
| `AuroraInputBox`           | User command input box                                                         |

#### Animation System

- **Halo Scan**: UWP-style cyclic speed logic (odd-even cycle variable speed)
- **Particle System**: Randomly generated particles with 1\~2.5s lifetime, Brownian drift
- **Starfield Background**: Random starfield particles based on performance tier
- **Dynamic FPS**: `1000 / TargetFPS` adaptive timer interval

***

### 2. AURORA-AnalyzerPRO.ps1 (Unified PRO Mode Entry Point)

**Version**: V1.1.13Release

#### Features

- Unified PRO mode entry point with bilingual support
- Language control via `$Language` parameter (CHS or ENG)
- Built-in startup detection, prohibits direct execution
- Automatic loading of language resources, core engine, and progress manager

#### Parameter System

```powershell
Param(
    [ValidateSet("CHS", "ENG")]
    [string]$Language = "CHS",
    
    [string]$OutputPath,
    [switch]$AutoOpen,
    
    [ValidateSet("System", "Application", "Security", "Setup", 
                 "DNS Server", "DHCP Server", "Directory Service", 
                 "IIS Admin Service")]
    [string]$LogType = "System",
    
    [switch]$GUI_Mode,
    # ... other parameters
)
```

#### Execution Flow

```powershell
# 1. Startup detection (prohibit direct execution)
# 2. Load language resources (AURORA-Language.psd1)
# 3. Import core engine (AURORA-CoreEngine.ps1)
# 4. Import progress manager (AURORA-ProgressManager.ps1)
# 5. Based on Language parameter:
#    - CHS → Load AURORA-AnalyzerCHSPRO.ps1
#    - ENG → Load AURORA-AnalyzerENGPRO.ps1
```

***

### 3. AURORA-AnalyzerCHSPRO.ps1 / AURORA-AnalyzerENGPRO.ps1 (PRO Export Engine)

**Version**: V1.1.13Release | **Language**: Chinese / English (fully symmetric architecture)

#### Core Function Modules

**Session & State Management**

- `Save-ProgressSafe`: Safe progress save (GUI sync + session persistence)
- `Write-AuroraLog`: Log writing (dual channel: console + GUI syncHash)
- `Get-AuroraInteraction`: GUI interactive input (suspend waiting for user input)

**Privilege Management**

- `Test-AdminRequired`: Determine if log type requires admin privileges
- `Invoke-ElevationCheck`: On-demand UAC elevation (GUI mode requests auth via syncHash)

**File & I/O**

- `New-StreamWriterOperation`: Thread-safe file writing (with retry mechanism)
- `Get-SafeFilePath`: Path safety handling (illegal character replacement)

**Performance Assessment & Resource Scheduling**

- `Get-ResourceOptimizedStrategy`: Adaptive strategy calculation based on system resources
- `Get-IntelligentCacheStrategy`: Intelligent cache strategy (freshness + hit rate calculation)
- `Get-DiskPerformance`: Disk I/O performance assessment
- `Get-SystemPerformanceScore`: Comprehensive performance score (CPU + RAM + Disk I/O)

**Cache System**

- `Test-CacheMatch`: Cache hit test (log type + time range + filter)
- `Get-CacheKey`: Cache key generation
- `Get-CachedLogData`: Cache data read
- `Set-CachedLogData`: Cache data write
- `Clear-LogCache`: Cache cleanup

**Knowledge Graph Engine**

- `Load-KnowledgeBase`: Load AURORA-TechData.json
- `New-KnowledgeBaseIndex`: Build precompiled index (EventID/Source/Keyword 3D)
- `Get-KnowledgeBaseSolution`: Single event→solution mapping (with SHA256 cache key)
- `Get-BatchKnowledgeBaseSolutions`: Batch Runspace concurrent knowledge graph matching

#### Output Artifacts (per Log Type)

| File                                     | Format          | Description               |
| ---------------------------------------- | --------------- | ------------------------- |
| `{LogType}_Log_{Date}.csv`               | CSV (BOM UTF-8) | Raw event data            |
| `{LogType}_Log_{Date}.json`              | JSON            | Structured event data     |
| `{LogType}_Log_{Date}.xml`               | XML             | Standard event log XML    |
| `{LogType}_Log_{Date}_Summary.txt`       | Plain text      | Structured summary report |
| `{LogType}_Log_{Date}_TrendAnalysis.txt` | Plain text      | Trend analysis report     |
| `{LogType}_Log_{Date}_TrendData.csv`     | CSV             | Trend raw data            |

***

### 4. AURORA-CoreEngine.ps1 (Shared Core Engine)

**Version**: V1.1.0Release

#### Function Modules

**Privilege Management Functions**

- `Test-AdminRequired`: Check if specified log type requires administrator privileges
- `Invoke-ElevationCheck`: Execute elevation check and request user authorization when needed

**Log Processing Functions**

- `Write-AuroraLog`: Unified log writing function
- `Read-AuroraInput`: Communicate with GUI via syncHash to get user input

**File Operation Functions**

- `New-StreamWriterOperation`: Thread-safe file write operation
- `Get-SafeFilePath`: Get safe file path

**Progress Management Functions**

- `Save-ProgressSafe`: Safe progress save
- `Get-ProgressInfo`: Get progress information

**Session Management Functions**

- `Manage-Session`: Session management

**System Information Functions**

- `Get-SystemInfo`: Get system information

#### Prevent Repeated Import Mechanism

```powershell
if ($global:AURORA_CoreEngine_Loaded -eq $true) {
    return
}
$global:AURORA_CoreEngine_Loaded = $true
```

***

### 5. AURORA-SmartEngine.ps1 (Intelligent Diagnostic Engine)

**Version**: V1.1.31Release | **Language**: Bilingual (CHS/ENG) | **Lines**: \~1,035

#### 4-Phase Diagnostic Pipeline

```
Phase 1: Detect System Vital Signs
  ├── OS information extraction
  ├── Uptime calculation
  ├── Hard crash tracing (EventID 41/6008)
  ├── Intelligent time window decision
  │   ├── Crash within 48H → Precise lock 2H before
  │   ├── <2H uptime → Push back 4H startup check
  │   └── Stable operation → Routine 24H inspection
  └── Minidump blue screen dump detection

Phase 2: Concurrent Anomaly Log Extraction
  ├── PRO mode CSV import (prioritize using exported CSV files)
  ├── Real-time Get-WinEvent extraction (Level 1/2/3)
  ├── Log type detection report
  ├── Missing log warnings
  └── Memory lightweight (keep only Id/ProviderName/Message)

Phase 3: Knowledge Graph Targeted Matching
  ├── JSON graph loading
  ├── Polymorphic Source (array/string compatibility)
  ├── Precompiled Regex (IgnoreCase)
  ├── O(n×m) ultra-fast matching: EventID → Source → Keywords
  └── Sort by Priority descending

Phase 4: Intelligent Autonomous Repair & Interactive Terminal
  ├── Safe sandbox executor (Invoke-AuroraSafeAction)
  │   ├── Step 0: Pre-check
  │   ├── Step 1: Privilege detection (Admin Elevation Check)
  │   ├── Step 2: Risk assessment & authorization
  │   └── Step 3: Command execution (PowerShell/CMD dual channel)
  │       ├── Normal CMD → Process Start (capture stdout/stderr)
  │       ├── Special commands (ms-settings:/cpl/msc/mdsched) → Start-Process
  │       └── ExitCode check
  ├── Step 4: Rollback on failure
  ├── Interactive menu persistence (syncHash.FullMenuText cache)
  └── GUI command loop monitoring (syncHash.UserInput)
```

#### `Invoke-AuroraSafeAction` Safe Sandbox Executor

```
Execution Flow:
  1. Clear authorization status
  2. Pre-check (pre_check)
     · Admin privilege detection
     · Custom pre-condition script execution
     · If not provided → pass directly
  3. Risk Assessment & Authorization
     · auto_execute=true → skip
     · auto_execute=false → set syncHash.RequiresAuthorization
       wait GUI user confirm (30s TO)
  4. Command Execution
     · type="powershell" → Invoke-Expression
     · type="cmd" → Process Start
     · Capture stdout/stderr + ExitCode
     · Privilege error special handling (740)
     · Output truncation display (≤10 lines)
  5. Rollback (Command.rollback)
     · Execute rollback script
     · Rollback timeout + output display
```

***

### 6. AURORA-ProgressManager.ps1 (Session Persistence System)

**Version**: V1.1.31Release | **Language**: Bilingual Support

#### Cache Directory Structure

```
SessionCache/
├── active/          ← Current active session JSON
├── checkpoints/     ← Checkpoint backup JSON
└── archive/         ← Completed session archive JSON (30-day auto cleanup)
```

#### Degradation Strategy

```
Tool directory writable?
  ├── YES → SessionCache\ (tool directory)
  └── NO  → %TEMP%\AURORA_Sessions\ (degradation)
```

#### Function Interfaces

| Function                    | Signature                                               | Description                                                      |
| --------------------------- | ------------------------------------------------------- | ---------------------------------------------------------------- |
| `Initialize-CacheDirectory` | `(ToolPath) → bool`                                     | Initialize cache directory structure, with write permission test |
| `New-Session`               | `(SessionType, Metadata) → SessionId`                   | Create `SESSION_yyyyMMdd_HHmmss_xxxx`                            |
| `Save-SessionProgress`      | `(SessionId, Stage, Progress, Data, -CreateCheckpoint)` | Save progress (retry + StreamWriter atomic write)                |
| `Restore-SessionProgress`   | `(SessionId?) → hashtable`                              | Restore session (auto-find latest incomplete, 7-day expiry)      |
| `Remove-SessionProgress`    | `(SessionId, -Archive)`                                 | Delete/archive session (with checkpoint cleanup)                 |
| `Complete-Session`          | `(SessionId, -Archive)`                                 | Mark 100% complete, clean null/empty fields                      |
| `Get-LatestPendingSession`  | `() → SessionId`                                        | Find latest incomplete session (Status=Active or Progress<100)   |
| `Test-PendingSession`       | `() → bool`                                             | Check if pending session exists                                  |
| `Invoke-CacheCleanup`       | `(RetentionDays=7) → cleanedCount`                      | Cleanup expired (active/checkpoint 7d, archive 30d)              |
| `Get-SessionStatistics`     | `() → hashtable`                                        | Get cache stats (sessions/checkpoints/archives/total size)       |
| `Get-LocalizedString`       | `(Key, args...) → string`                               | Bilingual localization string (with placeholder safe formatting) |

#### File I/O Safety Design

- **Retry Mechanism**: Max 3 times, exponential backoff (100ms × retryCount)
- **Atomic Write**: Delete old file → `File.Create()` → `StreamWriter` → `Flush()` → `Close()`
- **Safe Read**: `File.Open(Read)` → `StreamReader` → `ReadToEnd()`
- **Encoding**: UTF-8 No-BOM (`System.Text.UTF8Encoding($false)`)

***

### 7. AURORA-ProgressManager-Integration-CHS.ps1 / -ENG.ps1 (Integration Layer)

Defines 16 key checkpoints covering all PRO engine phases from initialization to task completion:

| Checkpoint                 | Progress | Phase Description                 |
| -------------------------- | -------- | --------------------------------- |
| `Initialized`              | 5%       | Script initialization complete    |
| `LogTypeSelected`          | 10%      | Log type selected                 |
| `DateRangeConfigured`      | 15%      | Date range configured             |
| `PerformanceAssessed`      | 25%      | Performance assessment complete   |
| `ProcessingStarted`        | 45%      | Started processing log files      |
| `HighRiskScanComplete`     | 60%      | High-risk event scan complete     |
| `HealthAssessmentComplete` | 70%      | System health assessment complete |
| `ExportModeSelected`       | 75%      | Export mode selected              |
| `FetchingFullLog`          | 75%      | Fetching full log                 |
| `FullLogFetched`           | 80%      | Full log fetched                  |
| `ExportStarted`            | 85%      | Exporting logs                    |
| `ExportComplete`           | 90%      | All logs exported                 |
| `TrendAnalysisComplete`    | 93%      | Trend analysis complete           |
| `SmartAnalysisPending`     | 95%      | Waiting for smart analysis        |
| `SmartAnalysisComplete`    | 98%      | Smart analysis complete           |
| `Completed`                | 100%     | Task complete                     |

***

### 8. AURORA-TechData.json (Knowledge Graph)

**Version**: V3.1 | **Rules**: 6 categories × N rules

#### Classification System

| ID    | Chinese Name  | English                       | Typical Rules                                                                                                                            |
| ----- | ------------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **A** | 系统稳定性         | System Stability              | Event 41 unexpected shutdown, 1001 blue screen, 1000 app crash, 1026 .NET exception, 7 disk error, 6008 abnormal shutdown, 100 slow boot |
| **B** | 驱动与硬件         | Drivers & Hardware            | Event 14 GPU driver timeout (TDR), 15 driver not loaded                                                                                  |
| **C** | 网络与通信         | Network & Communication       | Event 1002 DHCP IP acquisition failure, 1014 DNS name resolution timeout, 2004 resource exhaustion                                       |
| **D** | Windows 更新与安装 | Windows Update & Installation | Event 10004 update failure, 20 installation failure                                                                                      |
| **E** | 安全与身份         | Security & Identity           | Event 4625 login failure (brute force detection)                                                                                         |
| **F** | 应用与服务         | Applications & Services       | Event 371 print spooler error                                                                                                            |

#### Rule Structure

```json
{
  "rule_id": "A-001",
  "name": "意外关机/内核电源错误",
  "name_en": "Unexpected Shutdown/Kernel Power Error",
  "event_ids": [41],
  "source": "Kernel-Power",
  "message_keywords": ["bugcheck", "unexpectedly", "shutdown"],
  "severity": "Critical",
  "description": "...",
  "description_en": "...",
  "causes": [...],
  "causes_en": [...],
  "solutions": [...],
  "solutions_en": [...],
  "recommended_action": "...",
  "recommended_action_en": "...",
  "priority": 100,
  "applies_to": ["Windows 10", "Windows 11", "Windows Server 2016+"],
  "commands": [
    {
      "name": "运行系统文件检查器",
      "name_en": "Run System File Checker",
      "command": "sfc /scannow",
      "type": "cmd",
      "elevation_required": true,
      "risk_level": "Low",
      "auto_execute": false,
      "pre_check": "$true",
      "rollback_command": ""
    }
  ]
}
```

#### Smart Engine Graph Preprocessing

In Phase 3, Smart Engine performs three operations on the graph:

1. **Flattening**: Multi-level nested JSON → 1D `$flatRules` array
2. **Polymorphic Compatibility**: `source` field compatible with string/array formats
3. **Precompilation**: `[regex]::new()` precompiles all keywords, `RegexOptions::IgnoreCase`

***

### 9. build.ps1 + AURORA-build.bat (Secure Distribution Build System)

#### Build Pipeline

```
[0/5] Check required files (8-file integrity verification)
  ↓
[1/5] Calculate SHA256 hashes (all required files)
  ↓
[2/5] Generate plain text check file (ANSI No-BOM)
  ├── File hash list
  └── PASSWORD_HASH=Base64(SHA256)
  ↓
[3/5] AES-256-CBC encryption (random IV)
  ├── Key = SHA256(master password)
  └── Output: GAURORA.CHK.ENC (Base64)
  ↓
[4/5] Decryption verification (ensure encryption/decryption consistency)
  ↓
[5/5] C# source generation → csc.exe compilation
  ├── Embed Base64 key → AuroraLauncher.cs
  ├── /target:winexe (no console window)
  ├── /platform:x86
  ├── /win32icon:AURORAICON.ico
  └── Output: AURORA.Launcher-双击启动.exe
  ↓
[Optional] ZIP release packaging → Releases\AURORA_Analyzer_vX.X_Release.zip
```

#### Distribution File List

**Core Files**:

| File                       | Description                         |
| -------------------------- | ----------------------------------- |
| `AURORA.Launcher-双击启动.exe` | Main executable (C# Windowless EXE) |
| `GAURORA.CHK.ENC`          | Encrypted integrity check file      |
| `version.txt`              | Version info file (1.1.22.0)        |

**Scripts**:

| File                                                 | Description                                             |
| ---------------------------------------------------- | ------------------------------------------------------- |
| `Scripts\AURORA-AnalyzerLauncherGUI.ps1`             | GUI main controller (\~40K lines)                       |
| `Scripts\AURORA-AnalyzerPRO.ps1`                     | PRO mode unified entry point                            |
| `Scripts\AURORA-AnalyzerCHSPRO.ps1`                  | PRO Chinese export engine                               |
| `Scripts\AURORA-AnalyzerENGPRO.ps1`                  | PRO English export engine                               |
| `Scripts\AURORA-CoreEngine.ps1`                      | Shared core engine                                      |
| `Scripts\AURORA-SmartEngine.ps1`                     | Intelligent diagnostic & repair engine (V1.1.31Release) |
| `Scripts\AURORA-ProgressManager.ps1`                 | Session persistence system (V1.1.31Release)             |
| `Scripts\AURORA-ProgressManager-Integration.ps1`     | Unified integration layer                               |
| `Scripts\AURORA-ProgressManager-Integration-CHS.ps1` | Chinese integration layer                               |
| `Scripts\AURORA-ProgressManager-Integration-ENG.ps1` | English integration layer                               |
| `Scripts\AURORA-Language.psd1`                       | Bilingual resource file                                 |
| `Scripts\AURORA-GUI-Functions.ps1`                   | GUI auxiliary functions                                 |
| `Scripts\AURORA-RestoreManager.ps1`                  | System restore manager                                  |
| `Scripts\AURORA-RepairLogger.ps1`                    | Repair logger                                           |
| `Scripts\AURORA-RepairTools.ps1`                     | Repair tools                                            |
| `Scripts\AURORA-UndoManager.ps1`                     | Undo manager                                            |
| `Scripts\AURORA-UndoViewer.ps1`                      | Undo viewer                                             |

**Data Files**:

| File                                | Description                       |
| ----------------------------------- | --------------------------------- |
| `Data\AURORA-TechData.json`         | Diagnostic knowledge graph (V3.1) |
| `Data\AURORA-TechData.cache.clixml` | Technical data cache              |

**Resources**:

| File                         | Description      |
| ---------------------------- | ---------------- |
| `Resources\AURORAICON.ico`   | Application icon |
| `Resources\CascadiaMono.ttf` | UI font          |

**UserLogs Directory** (Generated at Runtime):

| File                           | Description                  |
| ------------------------------ | ---------------------------- |
| `UserLogs\*.csv`               | CSV format log export files  |
| `UserLogs\*.json`              | JSON format log export files |
| `UserLogs\*.xml`               | XML format log export files  |
| `UserLogs\*_Summary.txt`       | Structured summary reports   |
| `UserLogs\*_TrendAnalysis.txt` | Trend analysis reports       |
| `UserLogs\*_TrendData.csv`     | Trend raw data               |

**Other Files**:

| File               | Description                        |
| ------------------ | ---------------------------------- |
| `build.ps1`        | Build script (for developers)      |
| `AURORA-build.bat` | Build batch entry (for developers) |
| `Remove-BOM.ps1`   | UTF-8 BOM removal tool             |

**test Directory** (For development/debugging):

| File                             | Description                         |
| -------------------------------- | ----------------------------------- |
| `test\AURORA-UndoTest.ps1`       | Undo functionality test script      |
| `test\Remove-BOM.ps1`            | BOM removal test script             |
| `test\Test-Bilingual.ps1`        | Bilingual functionality test script |
| `test\Test-ProgressManager*.ps1` | Progress manager test script series |

***

## Technical Features Summary

### Concurrency & Performance

| Feature                        | Implementation                                                                         |
| ------------------------------ | -------------------------------------------------------------------------------------- |
| Runspace Multi-threading       | PowerShell RunspacePool, main thread ↔ sub-thread via `[hashtable]::Synchronized(@{})` |
| Dynamic Chunking               | `Get-OptimalChunkSize` adaptive based on CPU cores and RAM capacity                    |
| Dynamic Parallelism            | `Get-OptimalParallelism` adaptive based on CPU cores                                   |
| Object Pool                    | `New-ObjectPool` / `Get-ObjectFromPool` / `Return-ObjectToPool` reduce GC pressure     |
| Batch Knowledge Graph Matching | `Get-BatchKnowledgeBaseSolutions` Runspace concurrent query                            |

### Security & Authorization

| Feature                           | Implementation                                                     |
| --------------------------------- | ------------------------------------------------------------------ |
| File Integrity Check              | C# EXE SHA256 verifies all required files at startup               |
| Password Protection               | AES-256-CBC encrypted check file, SHA256 key derivation            |
| Admin Privilege On-Demand         | GUI requests via syncHash → user decision → restart with elevation |
| High-Risk Operation Authorization | `AuroraDecisionModal` holographic popup, user 逐项 confirms          |
| Risk Level Labeling               | Each command labeled `risk_level`: Low / Medium / High             |

### GUI Rendering

| Feature                     | Implementation                                                      |
| --------------------------- | ------------------------------------------------------------------- |
| Adaptive Performance Tier   | 4-tier config (Eco/Balanced/Performance/Extreme)                    |
| C# Inline Compiled Controls | PowerShell `Add-Type -TypeDefinition` directly compiles C# classes  |
| Particle Animation System   | `List<Particle>` per-frame Age/LifeTime/X/Y update                  |
| Halo Scan Animation         | PathGradientBrush dynamic position + UWP-style variable speed logic |
| Starfield Background        | Random generation + lifecycle + transparency gradient               |

### Fault Tolerance & Recovery

| Feature                   | Implementation                                              |
| ------------------------- | ----------------------------------------------------------- |
| Session Checkpoint Resume | ProgressManager saves all 16 checkpoint states              |
| File Write Retry          | Max 3 times + exponential backoff delay                     |
| Cache Degradation         | Tool directory unwritable → TEMP degradation                |
| Rollback Mechanism        | Command execution failure → auto-execute `rollback_command` |
| Session Expiry Cleanup    | Active/Checkpoint 7 days, Archive 30 days                   |

***

## System Requirements

| Item             | Minimum Requirement                                                  |
| ---------------- | -------------------------------------------------------------------- |
| Operating System | Windows 10 / Windows 11 / Windows Server 2016+                       |
| PowerShell       | 5.1+                                                                 |
| .NET Framework   | 4.x (for C# control compilation and EXE compilation)                 |
| Privileges       | Basic logs don't require admin; Security/Setup/DNS/DHCP etc. require |
| Memory           | ≥ 4GB (Eco tier); ≥ 8GB recommended (Balanced+)                      |

***

## Project Structure

### Release Version Directory Structure (v1.1.22.0+)

```
AURORA-Analyzer-Factory/
├──  Scripts/                          # Core script directory
│   ├── AURORA-AnalyzerLauncherGUI.ps1         # WinForms GUI main controller (~40K lines)
│   ├── AURORA-AnalyzerPRO.ps1                 # PRO mode unified entry point
│   ├── AURORA-AnalyzerCHSPRO.ps1              # PRO Chinese export engine
│   ├── AURORA-AnalyzerENGPRO.ps1              # PRO English export engine
│   ├── AURORA-CoreEngine.ps1                  # Shared core engine
│   ├── AURORA-SmartEngine.ps1                 # Intelligent diagnostic & repair engine
│   ├── AURORA-ProgressManager.ps1             # Session persistence & checkpoint resume
│   ├── AURORA-ProgressManager-Integration.ps1        # Unified integration layer
│   ├── AURORA-ProgressManager-Integration-CHS.ps1  # Chinese progress integration
│   ├── AURORA-ProgressManager-Integration-ENG.ps1  # English progress integration
│   ├── AURORA-Language.psd1                   # Bilingual resource file
│   ├── AURORA-RestoreManager.ps1              # System restore manager
│   ├── AURORA-RepairLogger.ps1                # Repair logger
│   ├── AURORA-RepairTools.ps1                 # Repair tools
│   ├── AURORA-UndoManager.ps1                 # Undo manager
│   ├── AURORA-UndoViewer.ps1                  # Undo viewer
│   └── AURORA-GUI-Functions.ps1               # GUI auxiliary functions
├──  Data/                             # Data file directory
│   ├── AURORA-TechData.json                   # Diagnostic knowledge graph (6 major rule categories)
│   └── AURORA-TechData.cache.clixml           # Technical data cache
├──  Resources/                        # Resource file directory
│   ├── AURORAICON.ico                         # Application icon
│   └── CascadiaMono.ttf                       # UI font
├──  UserLogs/                         # Log output directory (generated at runtime)
├──  SessionCache/                     # Session cache directory (auto-created at runtime)
│   ├── active/
│   ├── checkpoints/
│   └── archive/
├── AURORA.Launcher-双击启动.exe          # C# Windowless EXE launcher
├── GAURORA.CHK.ENC                        # AES-256 encrypted check file
├── version.txt                            # Version file (1.1.22.0)
├── build.ps1                              # Build script
└── AURORA-build.bat                       # Build batch entry point
```

***

## Startup Methods

```powershell
# Method 1 (Recommended): Double-click AURORA.Launcher-双击启动.exe

# Method 2: PowerShell command
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden `
  -File Scripts\AURORA-AnalyzerLauncherGUI.ps1
```

> All scripts have built-in startup protection, prohibiting direct double-click `.ps1` execution, enforcing GUI startup.

***

## Build

```cmd
REM Build with current version
AURORA-build.bat /generate

REM Increment version and build
build.ps1 -IncrementVersion
```

Build artifacts:

- `AURORA.Launcher-双击启动.exe` (Windowless EXE with embedded key)
- `GAURORA.CHK.ENC` (AES-256-CBC encrypted check file)
- `Releases\AURORA_Analyzer_vX.X_Release.zip` (optional)

***

## Communication Protocol

### GUI ↔ Backend syncHash Global Synchronized Hash Table

```powershell
$global:syncHash = [hashtable]::Synchronized(@{
    IsHostAlive         = $true       # GUI alive flag
    IsRunning           = $true       # Running status
    LogOutput           = ""          # Log output buffer
    Progress            = 0           # Progress percentage
    CurrentStatus       = ""          # Current status text
    CurrentActivity     = ""          # Current activity description
    UserInput           = $null       # User input
    RequestElevation    = $false      # Request elevation flag
    ElevationAuthorized = $null       # Elevation authorization result
    ShowSessionRecoveryHUD = $false   # Show recovery HUD
    SessionRestored     = $false      # User chose to restore
    SessionRestarted    = $false      # User chose to restart
})
```

***

## License

This tool is for personal learning use only.

***

*© 2026 AURORA VelociRaptor-GR Dev PRJ. | Version 1.1.22.0 | Build 2026.05.14*
