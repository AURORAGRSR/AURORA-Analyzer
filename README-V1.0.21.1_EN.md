# AURORA Analyzer V1.0.21.1

> **Windows Event Log Export · Intelligent Diagnostics · Autonomous Repair Engine**
>
> *AURORA VelociRaptor-GR Dev PRJ.*

---

## Project Overview

AURORA Analyzer is a comprehensive event log analysis, intelligent diagnostics, and autonomous repair toolchain for Windows systems. It exports high-risk events (Critical/Error/Warning) from Windows Event Log, generates structured reports (CSV/JSON/XML/TXT), and performs pattern matching against a local knowledge graph to automatically provide executable repair commands.

The project uses a **PowerShell 5.1 + C# Inline Compilation** hybrid architecture. All components are single-file self-contained designs, using synchronized hash tables (`syncHash`) for real-time inter-process communication across Runspaces.

---

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
│          ExportSystemEventLauncherGUI.ps1                 │
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
│ .ps1     │ │ .ps1     │ │  .ps1 (V3.1)           │
│ ~=CN Ver │ │ ~=EN Ver │ │  4-Phase Diagnostic    │
└────┬─────┘ └────┬─────┘ └───────────┬────────────┘
     │            │                   │
     └────────────┼───────────────────┘
                  │
     ┌────────────┼────────────┐
     ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────────────┐
│Progress  │ │Integr    │ │AURORA-TechData   │
│Manager   │ │-CHS/ENG  │ │.json (V3.0)      │
│.ps1      │ │.ps1      │ │6 Diagnostic Rules│
└──────────┘ └──────────┘ └──────────────────┘
```

---

## Module Details

### 1. ExportSystemEventLauncherGUI.ps1 (GUI Main Controller)

**Version**: V19.1Release | **Lines**: ~40,000

#### Startup Flow

| Step | Function | Technical Implementation |
|------|------|----------|
| ① | Hardware Performance Probe | `Get-CimInstance Win32_Processor / Win32_ComputerSystem`, weighted scoring |
| ② | Password Verification | AES-256-CBC decrypt `GAURORA.CHK.ENC`, SHA256 key derivation |
| ③ | C# Control Compilation | `Add-Type` inline compile AuroraProgressBar, TechButton, etc. |
| ④ | GUI Form Construction | WinForms borderless window, DPI-aware, Win32 API drag support |
| ⑤ | User Interaction | Log type selection, date range, export mode, trend analysis toggle |

#### Hardware Performance Tiering (`AuroraPerfTier`)

```powershell
$perfScore = ($logicalCores × 15) + ($ramGB × 5) + max(0, (baseClock - 2000) / 100)
```

| Tier | Score | Configuration | Rendering Features |
|------|------|------|----------|
| **Extreme** | ≥240 | 8-core+ 32G+ | 600 stars / 150 particles / complex halo / dynamic scan |
| **Performance** | ≥120 | 6-core 16G | 350 stars / 80 particles / halo on / dynamic scan |
| **Balanced** | ≥70 | 4-core 8G | 180 stars / 30 particles / shadow on |
| **Eco** | <70 | Legacy devices | 80 stars / no particles / basic mode |

#### C# Inline Custom Controls

| Control | Function |
|------|------|
| `AuroraProgressBar` | Rounded gradient progress bar with halo scan animation and particle system |
| `TechButton` | Tech-style dynamic button |
| `AuroraRenderEngine` | Static rendering engine, precomputes FPS/particle count based on hardware tier |
| `AuroraPrivilegeIndicator` | Administrator privilege status indicator |
| `AuroraTaskHUD` | Real-time task execution heads-up display (pipeline step visualization) |
| `AuroraResultModal` | Command execution result modal popup |
| `AuroraDecisionModal` | High-risk operation authorization decision popup |
| `AuroraRestoreModal` | Incomplete session recovery popup |
| `AuroraConsoleBox` | Embedded console output box (smart log echo) |
| `AuroraInputBox` | User command input box |

#### Animation System

- **Halo Scan**: UWP-style cyclic speed logic (odd-even cycle variable speed)
- **Particle System**: Randomly generated particles with 1~2.5s lifetime, Brownian drift
- **Starfield Background**: Random starfield particles based on performance tier
- **Dynamic FPS**: `1000 / TargetFPS` adaptive timer interval

---

### 2. ExportSystemEventLogsCHSPro.ps1 / ExportSystemEventLogsENGPro.ps1 (PRO Export Engine)

**Version**: V12.1Release | **Language**: Chinese / English (fully symmetric architecture)

#### Parameter System

```powershell
Param(
    [string]$OutputPath,        # Output directory (default: .\UserLogs)
    [switch]$AutoOpen,          # Auto-open folder after export
    [ValidateSet("System","Application","Security","Setup",
                 "DNS Server","DHCP Server","Directory Service",
                 "IIS Admin Service")]
    [string]$LogType = "System",# Log type
    [switch]$Silent,            # Silent mode
    [string]$EventId,           # Event ID filter
    [string]$ProviderName,      # Event source filter
    [ValidateSet("Critical","Error","Warning","Information","Verbose")]
    [string]$Level,             # Level filter
    [datetime]$StartTime,       # Start time
    [datetime]$EndTime,         # End time
    [switch]$ForceRescan,       # Force rescan
    [ValidateSet("SingleDay","DateRange")]
    [string]$ExportMode,        # Export mode (single day/date range)
    [ValidateSet("HighRiskOnly","Full")]
    [string]$ExportScope,       # Export scope (high risk only/full)
    [switch]$TrendAnalysis,     # Trend analysis
    [switch]$GUI_Mode           # GUI mode flag
)
```

#### Function Catalog (39 Key Functions)

**Session & State Management**
| Function | Function |
|------|------|
| `Save-ProgressSafe` | Safe progress save (GUI sync + session persistence) |
| `Write-AuroraLog` | Log writing (dual channel: console + GUI syncHash) |
| `Get-AuroraInteraction` | GUI interactive input (suspend waiting for user input) |

**Privilege Management**
| Function | Function |
|------|------|
| `Test-AdminRequired` | Determine if log type requires admin privileges |
| `Invoke-ElevationCheck` | On-demand UAC elevation (GUI mode requests auth via syncHash) |

**File & I/O**
| Function | Function |
|------|------|
| `New-StreamWriterOperation` | Thread-safe file writing (with retry mechanism) |
| `Get-SafeFilePath` | Path safety handling (illegal character replacement) |
| `Optimize-FileOperations` | Parallel file operation optimization |

**Performance Assessment & Resource Scheduling**
| Function | Function |
|------|------|
| `Get-ResourceOptimizedStrategy` | Adaptive strategy calculation based on system resources |
| `Get-IntelligentCacheStrategy` | Intelligent cache strategy (freshness + hit rate calculation) |
| `Get-DiskPerformance` | Disk I/O performance assessment |
| `Get-SystemPerformanceScore` | Comprehensive performance score (CPU + RAM + Disk I/O) |
| `Get-OptimalChunkSize` | Dynamic chunk size calculation |
| `Get-OptimalParallelism` | Dynamic parallelism calculation |
| `Get-SystemLoad` | CPU/RAM current load monitoring |
| `Get-MemoryUsage` | Process memory usage statistics |

**Cache System**
| Function | Function |
|------|------|
| `Test-CacheMatch` | Cache hit test (log type + time range + filter) |
| `Show-CacheInfo` | Cache file info display |
| `Get-CacheUsageChoice` | User cache usage decision interaction |
| `Test-CacheIntegrity` | Cache integrity verification |
| `Initialize-Cache` | Cache directory initialization |
| `Get-CacheKey` | Cache key generation |
| `Get-CachedLogData` | Cache data read |
| `Set-CachedLogData` | Cache data write |
| `Clear-LogCache` | Cache cleanup |
| `Get-OptimalCacheSize` | Dynamic cache size based on system resources |

**Data Compression**
| Function | Function |
|------|------|
| `Compress-Data` | Data compression (memory stream) |
| `Expand-CompressedData` | Compressed data decompression |

**Knowledge Graph Engine**
| Function | Function |
|------|------|
| `Load-KnowledgeBase` | Load AURORA-TechData.json |
| `New-KnowledgeBaseIndex` | Build precompiled index (EventID/Source/Keyword 3D) |
| `Get-KnowledgeBaseSolution` | Single event→solution mapping (with SHA256 cache key) |
| `Get-LocalizedKnowledgeBaseSolution` | Localized solution query |
| `Get-LocalizedKnowledgeBaseSolutions` | Batch localized query |
| `Get-KnowledgeBasePriority` | Get event fix priority |
| `Get-BatchKnowledgeBaseSolutions` | Batch Runspace concurrent knowledge graph matching |
| `Get-BatchKnowledgeBasePriorities` | Batch priority calculation |

**Log Analysis & Reporting**
| Function | Function |
|------|------|
| `Get-HighRiskEvents` | High-risk event scanning (with Runspace multi-threaded chunking) |
| `Get-FullSystemLog` | Full system log retrieval |
| `New-LogReport` | Summary/trend analysis report generation |
| `New-AdvancedLogPatternAnalysis` | Advanced log pattern recognition |
| `New-LogTrendAnalysis` | Log trend analysis (event frequency time series) |
| `Write-CustomProgress` | Custom progress display |

**Object Pool (Memory Optimization)**
| Function | Function |
|------|------|
| `New-ObjectPool` | Create typed object pool |
| `Get-ObjectFromPool` | Get object from pool |
| `Return-ObjectToPool` | Return object to pool |
| `Clear-ObjectPool` | Clear object pool |
| `Get-ObjectPoolStatus` | Object pool status query |

#### Output Artifacts (per Log Type)

| File | Format | Description |
|------|------|------|
| `{LogType}_Log_{Date}.csv` | CSV (BOM UTF-8) | Raw event data |
| `{LogType}_Log_{Date}.json` | JSON | Structured event data |
| `{LogType}_Log_{Date}.xml` | XML | Standard event log XML |
| `{LogType}_Log_{Date}_Summary.txt` | Plain text | Structured summary report |
| `{LogType}_Log_{Date}_TrendAnalysis.txt` | Plain text | Trend analysis report |
| `{LogType}_Log_{Date}_TrendData.csv` | CSV | Trend raw data |

---

### 3. AURORA-SmartEngine.ps1 (Intelligent Diagnostic Engine)

**Version**: V3.1 Smart Release | **Language**: Bilingual (CHS/ENG) | **Lines**: ~1,035

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
  ├── PRO mode CSV import (deprecated time window filter)
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
  ┌──────────────────────────────────────┐
  │ 0. Clear authorization status         │
  └──────────────────────────────────────┘
              │
              ▼
  ┌──────────────────────────────────────┐
  │ 1. Pre-check (pre_check)             │
  │    · Admin privilege detection        │
  │    · Custom pre-condition script exec │
  │    · If not provided → pass directly  │
  └──────────────────────────────────────┘
              │
              ▼
  ┌──────────────────────────────────────┐
  │ 2. Risk Assessment & Authorization   │
  │    · auto_execute=true → skip        │
  │    · auto_execute=false → set        │
  │      syncHash.RequiresAuthorization  │
  │      wait GUI user confirm (30s TO)  │
  └──────────────────────────────────────┘
              │
              ▼
  ┌──────────────────────────────────────┐
  │ 3. Command Execution                 │
  │    · type="powershell" → Invoke-Expr │
  │    · type="cmd" → Process Start      │
  │    · Capture stdout/stderr + ExitCode│
  │    · Privilege error special (740)   │
  │    · Output truncation (≤10 lines)   │
  └──────────────────────────────────────┘
              │
              ▼
  ┌──────────────────────────────────────┐
  │ 4. Rollback (Command.rollback)       │
  │    · Execute rollback script          │
  │    · Rollback timeout + output display│
  └──────────────────────────────────────┘
```

#### PRO Mode Data Transfer

Smart Engine supports receiving exported log paths directly from PRO engine, prioritizing CSV file loading in Phase 2 to avoid redundant `Get-WinEvent` calls. Key parameters:

- `-FromPRO`: Flag for PRO mode invocation
- `-ExportedLogPath`: PRO exported `UserLogs` directory path
- CSV field mapping: `TimeCreated` → event time, `LevelDisplayName` → level number (CHS/ENG support)

---

### 4. AURORA-ProgressManager.ps1 (Session Persistence System)

**Version**: V3.1 Smart Release | **Language**: Bilingual Support

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

| Function | Signature | Description |
|------|------|------|
| `Initialize-CacheDirectory` | `(ToolPath) → bool` | Initialize cache directory structure, with write permission test |
| `New-Session` | `(SessionType, Metadata) → SessionId` | Create `SESSION_yyyyMMdd_HHmmss_xxxx` |
| `Save-SessionProgress` | `(SessionId, Stage, Progress, Data, -CreateCheckpoint)` | Save progress (retry + StreamWriter atomic write) |
| `Restore-SessionProgress` | `(SessionId?) → hashtable` | Restore session (auto-find latest incomplete, 7-day expiry) |
| `Remove-SessionProgress` | `(SessionId, -Archive)` | Delete/archive session (with checkpoint cleanup) |
| `Complete-Session` | `(SessionId, -Archive)` | Mark 100% complete, clean null/empty fields |
| `Get-LatestPendingSession` | `() → SessionId` | Find latest incomplete session (Status=Active or Progress<100) |
| `Test-PendingSession` | `() → bool` | Check if pending session exists |
| `Invoke-CacheCleanup` | `(RetentionDays=7) → cleanedCount` | Cleanup expired (active/checkpoint 7d, archive 30d) |
| `Get-SessionStatistics` | `() → hashtable` | Get cache stats (sessions/checkpoints/archives/total size) |
| `Get-LocalizedString` | `(Key, args...) → string` | Bilingual localization string (with placeholder safe formatting) |

#### File I/O Safety Design

- **Retry Mechanism**: Max 3 times, exponential backoff (100ms × retryCount)
- **Atomic Write**: Delete old file → `File.Create()` → `StreamWriter` → `Flush()` → `Close()`
- **Safe Read**: `File.Open(Read)` → `StreamReader` → `ReadToEnd()`
- **Encoding**: UTF-8 No-BOM (`System.Text.UTF8Encoding($false)`)

---

### 5. AURORA-ProgressManager-Integration-CHS.ps1 / -ENG.ps1 (Integration Layer)

Defines 16 key checkpoints covering all PRO engine phases from initialization to task completion:

| Checkpoint | Progress | Phase Description |
|--------|------|----------|
| `Initialized` | 5% | Script initialization complete |
| `LogTypeSelected` | 10% | Log type selected |
| `DateRangeConfigured` | 15% | Date range configured |
| `PerformanceAssessed` | 25% | Performance assessment complete |
| `ProcessingStarted` | 45% | Started processing log files |
| `HighRiskScanComplete` | 60% | High-risk event scan complete |
| `HealthAssessmentComplete` | 70% | System health assessment complete |
| `ExportModeSelected` | 75% | Export mode selected |
| `FetchingFullLog` | 75% | Fetching full log |
| `FullLogFetched` | 80% | Full log fetched |
| `ExportStarted` | 85% | Exporting logs |
| `ExportComplete` | 90% | All logs exported |
| `TrendAnalysisComplete` | 93% | Trend analysis complete |
| `SmartAnalysisPending` | 95% | Waiting for smart analysis |
| `SmartAnalysisComplete` | 98% | Smart analysis complete |
| `Completed` | 100% | Task complete |

---

### 6. AURORA-TechData.json (Knowledge Graph)

**Version**: V3.0 | **Rules**: 6 categories × N rules

#### Classification System

| ID | Chinese Name | English | Typical Rules |
|----|--------|---------|----------|
| **A** | 系统稳定性 | System Stability | Event 41 unexpected shutdown, 1001 blue screen, 1000 app crash, 1026 .NET exception, 7 disk error, 6008 abnormal shutdown, 100 slow boot |
| **B** | 驱动与硬件 | Drivers & Hardware | Event 14 GPU driver timeout (TDR), 15 driver not loaded |
| **C** | 网络与通信 | Network & Communication | Event 1002 DHCP IP acquisition failure, 1014 DNS name resolution timeout, 2004 resource exhaustion |
| **D** | Windows 更新与安装 | Windows Update & Installation | Event 10004 update failure, 20 installation failure |
| **E** | 安全与身份 | Security & Identity | Event 4625 login failure (brute force detection) |
| **F** | 应用与服务 | Applications & Services | Event 371 print spooler error |

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

---

### 7. build.ps1 + AURORA-build.bat (Secure Distribution Build System)

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

| File | Description |
|------|------|
| `AURORA.Launcher-双击启动.exe` | Main executable (C# Windowless EXE) |
| `ExportSystemEventLauncherGUI.ps1` | GUI main controller |
| `ExportSystemEventLogsCHSPro.ps1` | PRO Chinese export engine |
| `ExportSystemEventLogsENGPro.ps1` | PRO English export engine |
| `AURORA-SmartEngine.ps1` | Intelligent diagnostic repair engine |
| `AURORA-TechData.json` | Diagnostic knowledge graph |
| `AURORA-ProgressManager.ps1` | Session persistence system |
| `AURORA-ProgressManager-Integration-CHS.ps1` | Chinese integration layer |
| `AURORA-ProgressManager-Integration-ENG.ps1` | English integration layer |
| `GAURORA.CHK.ENC` | Encrypted integrity check file |

---

## Technical Features Summary

### Concurrency & Performance

| Feature | Implementation |
|------|------|
| Runspace Multi-threading | PowerShell RunspacePool, main thread ↔ sub-thread via `[hashtable]::Synchronized(@{})` |
| Dynamic Chunking | `Get-OptimalChunkSize` adaptive based on CPU cores and RAM capacity |
| Dynamic Parallelism | `Get-OptimalParallelism` adaptive based on CPU cores |
| Object Pool | `New-ObjectPool` / `Get-ObjectFromPool` / `Return-ObjectToPool` reduce GC pressure |
| Batch Knowledge Graph Matching | `Get-BatchKnowledgeBaseSolutions` Runspace concurrent query |

### Security & Authorization

| Feature | Implementation |
|------|------|
| File Integrity Check | C# EXE SHA256 verifies all required files at startup |
| Password Protection | AES-256-CBC encrypted check file, SHA256 key derivation |
| Admin Privilege On-Demand | GUI requests via syncHash → user decision → restart with elevation |
| High-Risk Operation Authorization | `AuroraDecisionModal` holographic popup, user逐项 confirms |
| Risk Level Labeling | Each command labeled `risk_level`: Low / Medium / High |

### GUI Rendering

| Feature | Implementation |
|------|------|
| Adaptive Performance Tier | 4-tier config (Eco/Balanced/Performance/Extreme) |
| C# Inline Compiled Controls | PowerShell `Add-Type -TypeDefinition` directly compiles C# classes |
| Particle Animation System | `List<Particle>` per-frame Age/LifeTime/X/Y update |
| Halo Scan Animation | PathGradientBrush dynamic position + UWP-style variable speed logic |
| Starfield Background | Random generation + lifecycle + transparency gradient |

### Fault Tolerance & Recovery

| Feature | Implementation |
|------|------|
| Session Checkpoint Resume | ProgressManager saves all 16 checkpoint states |
| File Write Retry | Max 3 times + exponential backoff delay |
| Cache Degradation | Tool directory unwritable → TEMP degradation |
| Rollback Mechanism | Command execution failure → auto-execute `rollback_command` |
| Session Expiry Cleanup | Active/Checkpoint 7 days, Archive 30 days |

---

## System Requirements

| Item | Minimum Requirement |
|------|----------|
| Operating System | Windows 10 / Windows 11 / Windows Server 2016+ |
| PowerShell | 5.1+ |
| .NET Framework | 4.x (for C# control compilation and EXE compilation) |
| Privileges | Basic logs don't require admin; Security/Setup/DNS/DHCP etc. require |
| Memory | ≥ 4GB (Eco tier); ≥ 8GB recommended (Balanced+) |

---

## Project Structure

### Release Version Directory Structure (v0.21.1+)

```
ExportSystemEvent - Factory/
├──  Scripts/                          # Core script directory
│   ├── ExportSystemEventLauncherGUI.ps1       # WinForms GUI main controller (~40K lines)
│   ├── ExportSystemEventLogsCHSPro.ps1        # PRO Chinese export engine
│   ├── ExportSystemEventLogsENGPro.ps1        # PRO English export engine
│   ├── AURORA-SmartEngine.ps1                 # Intelligent diagnostic & repair engine
│   ├── AURORA-ProgressManager.ps1             # Session persistence & checkpoint resume
│   ├── AURORA-ProgressManager-Integration-CHS.ps1  # Chinese progress integration
│   └── AURORA-ProgressManager-Integration-ENG.ps1  # English progress integration
├──  Data/                             # Data file directory
│   ├── AURORA-TechData.json                   # Diagnostic knowledge graph (6 major rule categories)
│   └── version.txt                            # Version file
├── 📁 Resources/                        # Resource file directory
│   ├── AURORAICON.ico                         # Application icon
│   └── CascadiaMono.ttf                       # UI font
├── AURORA.Launcher-双击启动.exe          # C# Windowless EXE launcher
├── GAURORA.CHK.ENC                        # AES-256 encrypted check file
├── desktop.ini                            # Folder customization config
├── build.ps1                              # Build script (6-step build pipeline)
├── AURORA-build.bat                       # Build batch entry point
├── SessionCache/                          # Session cache directory (auto-created at runtime)
│   ├── active/
│   ├── checkpoints/
│   └── archive/
└── Releases/                              # Build artifacts (ZIP release packages)
```

### Development Directory (Development Environment Only)

```
ExportSystemEvent - Factory/
├── ... (above release files)
├── test/                                  # Test scripts
│   ├── Remove-BOM.ps1
│   ├── Test-Bilingual.ps1
│   ├── Test-ProgressManager*.ps1
│   └── Test-ProgressManager-Integration.ps1
├── Remove-BOM.ps1                         # UTF-8 BOM management tool
├── build.log                              # Build log
└── Task.txt                               # Development memo
```

---

## Startup Methods

```
Method 1 (Recommended): Double-click AURORA.Launcher-双击启动.exe
Method 2: powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File Scripts\ExportSystemEventLauncherGUI.ps1
```

> All scripts have built-in startup protection, prohibiting direct double-click `.ps1` execution, enforcing GUI startup.

---

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

---

## License

This tool is for personal learning use only.

---

*© 2026 AURORA VelociRaptor-GR Dev PRJ. | Version 1.0.21.1 | Build 2026.05.09*
