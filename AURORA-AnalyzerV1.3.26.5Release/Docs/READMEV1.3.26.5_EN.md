# AURORA Analyzer V1.3.26.5 — Complete Architectural Decoupling

> **Windows Event Log Export & Smart Diagnostic Tool**  
> Version: V1.3.26.5 Release | Build: 2026.06.08  
> Author: AURORA VelociRaptor-GR Dev PRJ.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture Decoupling Details](#2-architecture-decoupling-details)
3. [Security Architecture — 6-Layer Defense Model](#3-security-architecture--6-layer-defense-model)
4. [Core Subsystem Deep Dive](#4-core-subsystem-deep-dive)
5. [GUI Architecture](#5-gui-architecture)
6. [Smart Diagnostic Engine](#6-smart-diagnostic-engine)
7. [Session & Progress Management](#7-session--progress-management)
8. [Build System](#8-build-system)
9. [Performance Tier System](#9-performance-tier-system)
10. [Cross-Thread Communication](#10-cross-thread-communication)
11. [Technology Stack Summary](#11-technology-stack-summary)
12. [Attack Surface Analysis](#12-attack-surface-analysis)
13. [Contribution Guide](#13-contribution-guide)

---

## 1. Project Overview

### 1.1 Project Identity

| Property | Value |
|---|---|
| **Project Name** | AURORA Analyzer |
| **Current Version** | V1.3.26.5 |
| **Key Theme** | Complete Architectural Decoupling |
| **Entry Point** | `AURORA-Analyzer.exe` (C# .NET Framework 4.x, C# 5.0) → `AURORA-AnalyzerLauncherGUI.ps1` |
| **Build System** | `build.ps1` — RSA key injection, AES-256 encryption, C# compilation, ZIP packaging |
| **Target OS** | Windows Vista / 7 / 8 / 8.1 / 10 / 11 |
| **Required Runtime** | PowerShell 5.0+ |
| **Languages** | Full CHS/ENG bilingual support |

### 1.2 Architecture Overview (ASCII Art)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AURORA-Analyzer.exe (C#)                            │
│                   [Named Pipe Server / Watchdog / RSA Signer]               │
│                              │   Launch + Token                            │
│                              ▼                                              │
│              AURORA-AnalyzerLauncherGUI.ps1 (Orchestrator)                  │
│   ┌────────────┬────────────┬────────────┬────────────┬────────────────┐   │
│   │            │            │            │            │                │   │
│   ▼            ▼            ▼            ▼            ▼                ▼   │
│ ┌──────┐  ┌──────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐│
│ │CORE  │  │SEC   │  │UI/CTRL   │  │UI/VIEWS  │  │ENGINES   │  │PRO       ││
│ │Layer │  │Layer │  │Layer     │  │Layer     │  │Layer     │  │Layer     ││
│ ├──────┤  ├──────┤  ├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤│
│ │Core  │  │RSA   │  │UIControls│  │MainForm  │  │SmartEng  │  │PRO-Eng   ││
│ │Engine│  │Token │  │Anims     │  │Splash    │  │(1720+ln) │  │(290KB+)  ││
│ │Anim  │  │AES   │  │          │  │ProMode   │  │          │  │PRO-Entry ││
│ │Core  │  │Guard │  │          │  │Dialogs×4 │  │          │  │          ││
│ └──────┘  └──────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘│
│                                                                             │
│ ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐                    │
│ │SESSION   │  │REPAIR    │  │GUI       │  │DATA      │                    │
│ │Layer     │  │Layer     │  │Layer     │  │Layer     │                    │
│ ├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤                    │
│ │Progress  │  │Repair    │  │GUI-Funcs │  │TechData  │                    │
│ │Manager   │  │Tools     │  │Language  │  │.json     │                    │
│ │UndoMan   │  │RepairLog │  │.psd1     │  │.clixml   │                    │
│ │UndoView  │  │Restore   │  │          │  │          │                    │
│ │ProgInt   │  │Manager   │  │          │  │          │                    │
│ └──────────┘  └──────────┘  └──────────┘  └──────────┘                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.3 Key Decoupling Achievements (V1.3.26.5)

The V1.3.26.5 release represents a **complete architectural overhaul** of what was previously a monolithic single-file application. The original `AURORA-AnalyzerLauncherGUI.ps1` has been split into **10 distinct module layers** comprising **22+ individual `.ps1` / `.psd1` files**:

| Before | After |
|---|---|
| **1 monolithic file** (~8000+ lines) | **22+ modular files** organized in 10 layers |
| Security code inline with GUI code | `Security/AURORA-SecurityModule.ps1` |
| UI views inline with business logic | `UI/Views/*.ps1` (6 files) |
| Custom controls inline in launcher | `UI/Controls/*.ps1` (2 files) |
| Animation engine embedded in GUI | `Core/AURORA-AnimationCoreEngine.ps1` + `.dll` |
| Smart diagnostics mixed with launcher | `Engines/AURORA-SmartEngine.ps1` |
| PRO logic inline in launcher | `PRO/AURORA-AnalyzerPRO-Engine.ps1` + `.ps1` |
| Session logic scattered | `Session/*.ps1` (4 files) |
| Repair logic fragmented | `Repair/*.ps1` (3 files) |
| Language strings hardcoded | `GUI/AURORA-Language.psd1` (centralized) |
| GUI helpers duplicated | `GUI/AURORA-GUI-Functions.ps1` |

---

## 2. Architecture Decoupling Details

### 2.1 Core Layer (`Scripts/Core/`)

The core engine layer provides shared infrastructure used across all modules. It is loaded first and must be available before any other module.

| File | Size | Purpose |
|---|---|---|
| `AURORA-CoreEngine.ps1` | ~600+ lines | Shared core engine — `Invoke-SafeOperation`, `Write-AuroraLog`, progress/session management, system info collection, permission management (`Test-AdminRequired`, `Invoke-ElevationCheck`), configuration parameters |
| `AURORA-AnimationCoreEngine.ps1` | ~450+ lines | Animation engine — C# embedded DLL compilation, `PerformanceTier` enum, `AuroraRenderEngine` static configuration, `AnimationManager`, `FloatAnimation`, 19 easing functions, `IAnimatable` interface |

**Key design patterns:**
- Guard against duplicate imports via `$global:AURORA_CoreEngine_Loaded` flag
- `Invoke-SafeOperation` wraps all critical code paths with try/catch/log semantics
- Animation DLL is either loaded from pre-compiled `AURORA-AnimationCoreEngine.dll` or compiled on-the-fly via `Add-Type`

### 2.2 Security Layer (`Scripts/Security/`)

The security module is the **critical trust anchor** of the entire application. It is loaded after CoreEngine (dependency: `Invoke-SafeOperation`, `Write-AuroraLog`).

| File | Size | Purpose |
|---|---|---|
| `AURORA-SecurityModule.ps1` | ~1000+ lines | RSA token verification (2048-bit), AES-256-CBC session encryption, **AuroraGuard** C# embedded runtime guardian (debugger detection, anti-dump, FileSystemWatcher integrity monitoring), watchdog client functions, exit handler registration, environment cleanup |

**Security injection points (build-time):**
- `$global:AURORA_PublicKeyXml` — RSA public key injected by `build.ps1`
- `$global:AURORA_SessionSalt` — Random 32-byte derivation salt injected per build
- AuroraGuard `_expected` dictionary — 23 SHA256 hashes injected per build

### 2.3 UI/Controls Layer (`Scripts/UI/Controls/`)

| File | Size | Purpose |
|---|---|---|
| `AURORA-UIControls.ps1` | ~500+ lines | Custom C# controls — `TechButton` (ripple effect + magnetic snap to cursor), `AuroraProgressBar` (smooth transitions, particle system, glow sweep), `StarfieldPanel` (animated starfield background with particles), `Win32Helper` (borderless window drag support) |
| `AURORA-Animations.ps1` | ~300+ lines | PowerShell animation helpers — `Save-ControlState`/`Restore-ControlState`, `Stop-AllAnimations`, UWP-style float opacity/location/size animation wrappers, global animation timer management |

**TechButton features:**
- Mouse-enter magnetic snap (button slides toward cursor)
- Ripple effect on click (expanding circle)
- Dark glass aesthetic with gradient border
- `SetBounds()` forced positioning (disables auto-layout)

**AuroraProgressBar features:**
- Round-cornered track with cyan gradient fill
- Dynamic glow sweep using `PathGradientBrush`
- Particle system: white glowing particles with lifecycle and random drift
- Smooth progress interpolation (`_progressAnimSpeed = 0.12f`)
- High-performance double-buffered rendering

**StarfieldPanel features:**
- Procedurally generated starfield background
- Performance-tier-aware star count (80–600 stars)
- Optional particle system (0–150 particles)
- Text overlay capability
- Mouse drag support for borderless windows

### 2.4 UI/Views Layer (`Scripts/UI/Views/`)

| File | Size | Purpose |
|---|---|---|
| `View-MainForm.ps1` | ~1100+ lines | Main language selection form (400×480 fixed, borderless, StarfieldPanel background, TechButton controls, view transition animations) |
| `View-SplashScreen.ps1` | ~300+ lines | Splash screen with starfield animation, version display, loading sequence |
| `View-ProMode.ps1` | ~400+ lines | PRO mode configuration window with advanced export options |
| `Dialogs/View-SessionRestoreDialog.ps1` | ~200+ lines | Session recovery dialog — resume vs. restart choice |
| `Dialogs/View-ElevationDialog.ps1` | ~150+ lines | Admin elevation request dialog |
| `Dialogs/View-PermissionInfo.ps1` | ~100+ lines | Permission information display dialog |
| `Dialogs/View-AdminElevation.ps1` | ~150+ lines | Admin elevation management UI |

**View design principles:**
- All views reference controls from `UI/Controls/` layer
- Animations delegated to `UI/Controls/AURORA-Animations.ps1`
- View transition state tracked via `$Global:IsViewTransitioning` flag
- Control states saved/restored during transitions

### 2.5 Engines Layer (`Scripts/Engines/`)

| File | Size | Purpose |
|---|---|---|
| `AURORA-SmartEngine.ps1` | ~1720+ lines | Smart diagnostic engine — bilingual (CHS/ENG), 4-phase pipeline: vitals detection → concurrent log extraction → knowledge graph collision → auto-healing sandbox with rollback |

**Detailed in [Section 6](#6-smart-diagnostic-engine).**

### 2.6 PRO Layer (`Scripts/PRO/`)

| File | Size | Purpose |
|---|---|---|
| `AURORA-AnalyzerPRO-Engine.ps1` | ~290KB+ | Unified CHS/ENG PRO engine — advanced log export, filtering, trend analysis, CSV/JSON/XML multi-format output |
| `AURORA-AnalyzerPRO.ps1` | ~200+ lines | PRO mode entry point — parameter dispatch, startup guard |

### 2.7 Session Layer (`Scripts/Session/`)

| File | Size | Purpose |
|---|---|---|
| `AURORA-ProgressManager.ps1` | ~600+ lines | Session persistence & checkpoint/resume — `SessionCache` with `active/checkpoints/archive` structure, 7-day auto-expiry, bilingual support |
| `AURORA-ProgressManager-Integration.ps1` | ~100+ lines | Progress manager integration glue — bridges ProgressManager with GUI lifecycle |
| `AURORA-UndoManager.ps1` | ~300+ lines | Fast backup & restore — registry, file, service snapshots, backup directory management |
| `AURORA-UndoViewer.ps1` | ~200+ lines | Undo viewer UI — snapshot browsing, selective restore |

**Session cache structure:**
```
SessionCache/
├── active/          # Current active session
├── checkpoints/     # Checkpoint backups
└── archive/         # Completed session archives
```

### 2.8 Repair Layer (`Scripts/Repair/`)

| File | Size | Purpose |
|---|---|---|
| `AURORA-RepairTools.ps1` | ~500+ lines | Repair operations — `DisableWindowsUpdate`, `EnableDefender`, `DisableTelemetry`, `ResetNetwork`, `CleanSystem`, `Custom`, all with undo support |
| `AURORA-RepairLogger.ps1` | ~200+ lines | Repair session logger — structured logging for repair operations |
| `AURORA-RestoreManager.ps1` | ~200+ lines | System restore point management — create/delete/list restore points |

### 2.9 GUI Layer (`Scripts/GUI/`)

| File | Size | Purpose |
|---|---|---|
| `AURORA-GUI-Functions.ps1` | ~300+ lines | GUI helper functions — font loading (`CascadiaMono.ttf`), directory integrity checks, progress bar management |
| `AURORA-Language.psd1` | ~400+ lines | Centralized bilingual resource dictionary — `CHS` and `ENG` hashtables covering all UI strings |

**Language dictionary structure:**
```powershell
@{
    CHS = @{
        "Launcher_Required" = "❌ 此脚本不能直接运行！"
        "Use_Launcher"      = "请使用以下方式启动："
        # ... 100+ entries
    }
    ENG = @{
        "Launcher_Required" = "❌ This script cannot be run directly!"
        "Use_Launcher"      = "Please launch using:"
        # ... 100+ entries
    }
}
```

### 2.10 Data Layer (`Data/`)

| File | Purpose |
|---|---|
| `AURORA-TechData.json` | Knowledge graph — diagnostic rules, event ID patterns, severity mappings, repair suggestions |
| `AURORA-TechData.cache.clixml` | Precompiled cache — PowerShell-serialized version for faster loading |

### 2.11 Resources (`Resources/`)

| File | Purpose |
|---|---|
| `AURORAICON.ico` | Application icon |
| `CascadiaMono.ttf` | Monospace font for log display |

### 2.12 Launcher Entry Point

**`AURORA-AnalyzerLauncherGUI.ps1`** — The main launcher that orchestrates all modules. Responsibilities:

1. Module loading in dependency order (GUI-Functions → AnimationCore → CoreEngine → SecurityModule)
2. Hardware performance profiling and tier assignment
3. RSA token verification and hash list decryption
4. Elevation token validation (post-UAC trust chain recovery)
5. Watchdog Named Pipe client connection and HMAC challenge-response loop
6. AuroraGuard initialization and file integrity verification
7. Password-based fallback authentication (PBKDF2 + AES-256-CBC)
8. Splash screen display with starfield animation
9. View orchestration and lifecycle management
10. Global `syncHash` initialization for cross-thread communication

---

## 3. Security Architecture — 6-Layer Defense Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    AURORA 6-Layer Defense Model                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Layer 0: BUILD-TIME                                             │
│  ├─ RSA 2048 key pair generation                                │
│  ├─ SHA256 integrity hashes (23 files)                          │
│  ├─ 60-second token window for RSA signatures                   │
│  ├─ Password obfuscation: XOR shuffle + random mask             │
│  └─ C# EXE compilation with embedded private key                │
│                                                                  │
│  Layer 1: STARTUP VERIFICATION                                   │
│  ├─ RSA token signature (SHA256 + PKCS#1 v1.5)                  │
│  ├─ AES-256-CBC hash list decryption (PBKDF2-SHA256 100k)       │
│  ├─ Environment sanity check (debugger env vars, system state)   │
│  ├─ Elevation token validation (120s window)                    │
│  └─ Anti-forgery: -LaunchedByExe flag requires RSA proof        │
│                                                                  │
│  Layer 2: IPC SECURITY                                           │
│  ├─ Windows Named Pipe bidirectional authentication             │
│  ├─ HMAC-SHA256 challenge-response protocol                     │
│  ├─ Bidirectional heartbeat (single failure = terminate)        │
│  ├─ Session-specific HMAC key (random 32 bytes)                 │
│  └─ 3 retry attempts with 500ms delay                           │
│                                                                  │
│  Layer 3: RUNTIME GUARDIAN (AuroraGuard C#)                     │
│  ├─ Debugger API detection (4 methods)                          │
│  │   ├─ IsDebuggerPresent()                                     │
│  │   ├─ CheckRemoteDebuggerPresent()                            │
│  │   ├─ NtQueryInformationProcess(ProcessDebugPort)             │
│  │   └─ NtQueryInformationProcess(ProcessDebugFlags)            │
│  ├─ Anti-dump: ThreadHideFromDebugger for critical threads      │
│  ├─ Debugger process name scan (28 known debuggers)             │
│  ├─ Hardware breakpoint detection (DR0–DR7 registers)           │
│  ├─ FileSystemWatcher integrity monitoring                     │
│  └─ Timed integrity re-verification (10s cache)                 │
│                                                                  │
│  Layer 4: PASSWORD VERIFICATION                                  │
│  ├─ PBKDF2-SHA256 (100,000 iterations)                          │
│  ├─ AES-256-CBC encrypted check file (GAURORA.CHK.ENC)          │
│  ├─ Salt + IV prepended to ciphertext                           │
│  ├─ Decryption verification before granting access              │
│  └─ 3 master password retry attempts                            │
│                                                                  │
│  Layer 5: C# EXE WATCHDOG                                       │
│  ├─ Named Pipe server (created by EXE)                          │
│  ├─ HMAC-SHA256 challenge-response                              │
│  ├─ Process lifecycle management                                │
│  ├─ Kill on HMAC failure or heartbeat timeout                   │
│  ├─ Response data: uptime + self-file SHA256                    │
│  └─ Watcher thread in separate Runspace (STA)                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Core Subsystem Deep Dive

### 4.1 RSA Token Verification

**Purpose:** The C# EXE signs a launch token before spawning the PowerShell process. The PS1 script verifies this token to confirm it was launched by a legitimate, untampered EXE.

**Token format:**
```
<Nonce>:<UnixTimestamp>:<AES-Encrypted-HashList-Base64>:<RSA-Signature-Base64>
```

**Verification flow:**

```
EXE (Launch)                              PS1 (Startup)
     │                                         │
     ├─ Generate random 16-byte Nonce          │
     ├─ Build hash list (SHA256 of all files)  │
     ├─ Encrypt hash list:                     │
     │    PBKDF2(Nonce, AU_SALT, 100k) → AES Key│
     │    Random IV + AES-256-CBC Encrypt      │
     ├─ Sign with RSA-2048 private key:        │
     │    RSA.SignData(Nonce:Timestamp:EncHash) │
     ├─ Write token to temp file               │
     ├─ Set AURORA_TOKEN_PATH env var          │
     └─ Launch powershell.exe ... ──────────►  │
                                               ├─ Read token from env var path
                                               ├─ Verify RSA signature:
                                               │    RSA.VerifyData(SHA256, PKCS#1 v1.5)
                                               ├─ Check timestamp window (±60s)
                                               ├─ Decrypt hash list:
                                               │    PBKDF2(Nonce, AU_SALT, 100k) → Key
                                               │    AES-256-CBC Decrypt
                                               └─ Compare hashes with current files
```

**Crypto parameters:**

| Parameter | Value |
|---|---|
| RSA key size | 2048 bits |
| Signature algorithm | SHA256 + PKCS#1 v1.5 padding |
| Token validity window | 60 seconds (with 5s clock skew tolerance) |
| AES mode | CBC with PKCS7 padding |
| Key derivation | PBKDF2-SHA256, 100,000 iterations |
| AES key size | 256 bits (32 bytes) |
| IV | Random 16 bytes, prepended to ciphertext |

**Key injection (build-time):**
1. `build.ps1` generates a fresh RSA-2048 key pair per build
2. Public key is injected into `AURORA-SecurityModule.ps1` (`$global:AURORA_PublicKeyXml`)
3. Private key is embedded into the C# EXE source code (compiled into IL)
4. After injection, SecurityModule's hash is recalculated for the hash list

### 4.2 Watchdog Named Pipe IPC (Layer 2 + Layer 5)

**Architecture:**

```
┌──────────────────────────┐      ┌──────────────────────────┐
│   AURORA-Analyzer.exe    │      │  PowerShell Process       │
│   (C# .NET Framework)    │      │  (LauncherGUI.ps1)        │
│                          │      │                          │
│  ┌────────────────────┐  │      │  ┌────────────────────┐  │
│  │ NamedPipeServer    │◄─┼──────┼──│ NamedPipeClient    │  │
│  │ Stream             │  │      │  │ Stream             │  │
│  └────────────────────┘  │      │  └────────────────────┘  │
│                          │      │                          │
│  ┌────────────────────┐  │      │  ┌────────────────────┐  │
│  │ Challenge-Response  │  │      │  │ Watchdog Runspace  │  │
│  │ (every N seconds)   │──┼──────┼─►│ (STA Thread)       │  │
│  │                      │  │      │  │ HMAC-SHA256       │  │
│  │ On failure:          │  │      │  │ Response Handler  │  │
│  │ KillProcess()       │  │      │  └────────────────────┘  │
│  └────────────────────┘  │      └──────────────────────────┘
└──────────────────────────┘
```

**Handshake protocol:**

```
PS1 Client                                  EXE Server
    │                                           │
    │──── Connect(NamedPipe) ──────────────────►│
    │◄─── 49 bytes: [0x10][32-byte HMAC Key]───│
    │         [16-byte Session ID]              │
    │                                           │
    │──── 1 byte ACK: [0x11] ─────────────────►│
    │                                           │
    │    ╔═══ Watchdog Heartbeat Loop ═══╗     │
    │◄── [0x03][16-byte Nonce][8-byte TS]──│───│
    │                                           │
    │───► 73 bytes: [0x04]                      │
    │    [32-byte HMAC-SHA256(Nonce)]           │
    │    [8-byte System Uptime]                 │
    │    [32-byte SHA256(Self-File)]            │
    └                                           ┘
```

**Response content verified by EXE:**
- HMAC-SHA256 of the challenge nonce (proves possession of the session key)
- System uptime (detects process injection via restart anomalies)
- SHA256 hash of the PS1 launcher script (detects on-disk tampering)

**Failure handling:**
- Single HMAC mismatch → EXE terminates the PowerShell process
- Heartbeat timeout (4s read timeout) → EXE terminates the PowerShell process
- 3 connection retry attempts with 500ms delay before giving up
- If watchdog connection fails, the PS1 continues in "standalone mode" (but Layer 1/3/4 security still applies)

### 4.3 AuroraGuard Runtime Guardian (Layer 3)

**AuroraGuard** is a C# class compiled at runtime via `Add-Type` into the PowerShell runspace. It provides multiple overlapping anti-tamper mechanisms.

**Debugger detection (4 layers):**

```csharp
// Level 1: Win32 API
IsDebuggerPresent()                              // User-mode debugger check

// Level 2: Remote debugger
CheckRemoteDebuggerPresent(GetCurrentProcess())   // Remote debugging session

// Level 3: NtQueryInformationProcess - DebugPort
NtQueryInformationProcess(hProcess, 7, ...)       // Kernel debug port check

// Level 4: NtQueryInformationProcess - DebugFlags
NtQueryInformationProcess(hProcess, 31, ...)      // Debug flags in EPROCESS
```

**Process name scan (28 known debuggers):**
```
windbg, windbgx, windbgpreview, cdb, ntsd, x64dbg, x32dbg,
dbgx, dbgx.shell, ida, ida64, idag, idag64, idaw, idaw64,
ollydbg, x64ollydbg, immunitydebugger, ghidra, ghidrarun,
radare2, r2, rizin, rz, dbgshell, mdb, mdbx,
vsjitdebugger, mdbg, cordebug, dnspy, dnspy64,
scylla, scyllahide, titancall, phant0m
```

**Hardware breakpoint detection:**
```csharp
// Suspend all threads, read DR0-DR7 debug registers
// Non-zero values indicate hardware breakpoints are set
CONTEXT ctx = new CONTEXT { ContextFlags = CONTEXT_DEBUG_REGISTERS };
GetThreadContext(hThread, ref ctx);
if (ctx.Dr0 != 0 || ctx.Dr1 != 0 || ctx.Dr2 != 0 || ctx.Dr3 != 0)
    // Hardware breakpoint detected
```

**File integrity monitoring:**

```csharp
// 23 files tracked via SHA256 hashes (injected at build-time)
private static readonly Dictionary<string, string> _expected = new Dictionary<string, string>
{
    { "Scripts\\UI\\Controls\\AURORA-UIControls.ps1", "<SHA256>" },
    { "Scripts\\UI\\Controls\\AURORA-Animations.ps1", "<SHA256>" },
    // ... 21 more files
};

// Re-verified every 10 seconds (with caching to reduce I/O)
// Mismatch triggers immediate process termination
```

**Timed integrity re-verification:**
- `_integrityCacheDuration = 10 seconds`
- After cache expires, all 23 files are re-hashed and compared
- Thread-safe via `lock(_integrityLock)`
- Failure = immediate `Environment.Exit(1)`

### 4.4 Password Verification (Layer 4)

When not launched by the EXE (or RSA token verification fails), the system falls back to password authentication:

```
User Input → PBKDF2-SHA256(100k iter, 16-byte random salt) → AES-256-CBC Key
                                                                    │
GAURORA.CHK.ENC → Base64 Decode → [Salt 16B][IV 16B][Ciphertext]  │
                                                                    ▼
                                        AES-256-CBC Decrypt → Plain Text Hash List
                                                                    │
                                                                    ▼
                                        Compare with live SHA256 hashes of all 23 files
```

**GAURORA.CHK.ENC structure:**
```
[16 bytes Salt | 16 bytes AES-IV | N bytes AES-CBC Ciphertext] → Base64 Encoded
```

**Password strength requirements:**
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 digit
- At least 1 special character
- Maximum 3 retry attempts

---

## 5. GUI Architecture

### 5.1 Animation Engine (`AURORA-AnimationCoreEngine`)

The animation engine is implemented as a C# embedded DLL (compiled at runtime or loaded from pre-compiled `.dll`).

**Performance Tier Configuration:**

| Tier | Target FPS | Star Count | Particle Count | Complex Glow | Path Gradient | Dynamic Sweep |
|---|---|---|---|---|---|---|
| **Eco** | 30 FPS | 80 | 0 | ✗ | ✗ | ✗ |
| **Balanced** | 60 FPS | 180 | 30 | ✗ | ✓ | ✗ |
| **Performance** | 60 FPS | 350 | 80 | ✓ | ✓ | ✓ |
| **Extreme** | 60 FPS | 600 | 150 | ✓ | ✓ | ✓ |

**Easing function library (19 functions):**

| Category | Functions |
|---|---|
| Linear | `Linear` |
| Cubic | `EaseInCubic`, `EaseOutCubic`, `EaseInOutCubic` |
| Quadratic | `EaseInQuad`, `EaseOutQuad`, `EaseInOutQuad` |
| Quartic | `EaseInQuart`, `EaseOutQuart`, `EaseInOutQuart` |
| Quintic | `EaseInQuint`, `EaseOutQuint`, `EaseInOutQuint` |
| Elastic | `EaseInElastic`, `EaseOutElastic`, `EaseInOutElastic` |
| Bounce | `EaseInBounce`, `EaseOutBounce`, `EaseInOutBounce` |

**AnimationManager pattern:**
```csharp
var mgr = new AnimationManager();
mgr.AddAnimation(new FloatAnimation(
    startValue: 0.0f,
    targetValue: 1.0f,
    duration: 0.5f,          // 500ms
    onUpdate: (val) => { control.Opacity = val; },
    easingType: EasingType.EaseOutCubic,
    onComplete: () => { /* transition finished */ }
));
```

### 5.2 Custom Controls

**TechButton:**
- Dark glass aesthetic: `Color.FromArgb(80, 120, 200, 255)` base background
- Ripple effect: expanding circle animation on click (`_rippleRadius`, `_rippleAlpha`)
- Magnetic snap: button slides toward mouse cursor on hover (interpolation toward target Y)
- Corner radius: 8px rounded rectangle path
- Hover state: gradient border glow intensifies

**AuroraProgressBar:**
- Track: semi-transparent deep space blue (`Color.FromArgb(100, 60, 100, 160)`)
- Fill: cyan to teal gradient
- Glow sweep: `PathGradientBrush` traveling across the filled region (UWP-style animation, `_glowSpeed = 0.025f`)
- Particles: `List<Particle>` with lifetime decay, random velocity, and alpha fade
- Smooth display value interpolation (LERP toward `_value`)

**StarfieldPanel:**
- Procedural star generation with random positions, sizes, and brightness
- Twinkling effect via random alpha oscillation
- Full-panel mouse drag support for borderless window movement
- Text status overlay capability

### 5.3 View Layer Architecture

```
View-SplashScreen.ps1
    │
    ▼
View-MainForm.ps1  ───────┬──────► View-ProMode.ps1
    │                      │
    ├── Dialogs/View-SessionRestoreDialog.ps1
    ├── Dialogs/View-ElevationDialog.ps1
    ├── Dialogs/View-PermissionInfo.ps1
    └── Dialogs/View-AdminElevation.ps1
```

**View transition system:**
1. `$Global:IsViewTransitioning = $true` — blocks concurrent transitions
2. `Stop-AllAnimations -RestoreState` — stops active animations, restores control states
3. Controls fade out (UWP opacity animation)
4. Container cleared, new view created
5. New controls fade in (staggered delays)
6. `$Global:IsViewTransitioning = $false`

### 5.4 Animation Helpers (`AURORA-Animations.ps1`)

**Control state preservation:**
```powershell
Save-ControlState -Control $button    # Save Location, Size, ForeColor, Visible
# ... animation code ...
Restore-ControlState -Control $button # Restore original state
```

**Global animation management:**
- `$Global:AnimationTimers` — tracks all active animation timers
- `Stop-AllAnimations` — stops all or per-control animations with optional state restoration

---

## 6. Smart Diagnostic Engine

### 6.1 Four-Phase Pipeline

```
┌──────────────────────────────────────────────────────────────────────┐
│                 AURORA Smart Diagnostic Pipeline                      │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  PHASE 1: VITALS DETECTION                                           │
│  ├─ System hardware enumeration (CPU, RAM, Disk, GPU)                │
│  ├─ OS version and patch level detection                             │
│  ├─ Running process inventory                                        │
│  ├─ Network connectivity test                                        │
│  └─ Windows Event Log channel probe                                  │
│                                                                       │
│  PHASE 2: CONCURRENT LOG EXTRACTION                                  │
│  ├─ Multi-log-type parallel extraction (System, Application,         │
│  │   Security, Setup, OpenSSH, PowerShell, Windows Update,           │
│  │   DNS Server, DHCP Server, Directory Service, IIS Admin)          │
│  ├─ Event ID filtering and time-range windowing                     │
│  ├─ Provider name filtering                                          │
│  ├─ Multi-format export (CSV, JSON, XML, TXT summary)               │
│  └─ Trend analysis generation (time-series event frequency)          │
│                                                                       │
│  PHASE 3: KNOWLEDGE GRAPH COLLISION                                  │
│  ├─ Load AURORA-TechData.json (or .cache.clixml)                     │
│  ├─ Match extracted events against diagnostic rules                  │
│  ├─ Severity classification (Critical/Error/Warning/Info)            │
│  ├─ Pattern correlation across event IDs                             │
│  └─ Root cause inference engine                                      │
│                                                                       │
│  PHASE 4: AUTO-HEALING SANDBOX                                       │
│  ├─ Invoke-AuroraSafeAction wrapper                                  │
│  ├─ Pre-action safety checks:                                        │
│  │   ├─ Risk assessment (Destructive/Reversible/Safe)               │
│  │   ├─ Admin privilege verification                                │
│  │   └─ System restore point creation (optional)                    │
│  ├─ Undo snapshot creation (Registry, File, Service)                 │
│  ├─ Command execution with timeout                                   │
│  ├─ Result verification and logging                                  │
│  └─ Rollback on failure (restore from undo snapshot)                 │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

### 6.2 Knowledge Graph (`AURORA-TechData.json`)

The knowledge graph is the diagnostic rule database:

```json
{
  "rules": [
    {
      "eventId": 41,
      "provider": "Microsoft-Windows-Kernel-Power",
      "severity": "Critical",
      "pattern": "The system has rebooted without cleanly shutting down",
      "diagnosis": "Unexpected shutdown detected. Possible causes: power failure, hardware issue, driver crash.",
      "repair": [
        { "action": "CheckDisk", "safe": true },
        { "action": "SFCScan", "safe": true },
        { "action": "UpdateDrivers", "safe": false, "requiresAdmin": true }
      ]
    }
  ]
}
```

### 6.3 Sandbox Executor (`Invoke-AuroraSafeAction`)

```powershell
function Invoke-AuroraSafeAction {
    param(
        [PSObject]$Command,       # Repair command object
        [string]$Language = "CHS" # Bilingual output
    )
    # Flow:
    # 1. Import RestoreManager (admin only) + RepairLogger
    # 2. Risk assessment: Destructive / Reversible / Safe
    # 3. Create undo snapshot (Registry/File/Service)
    # 4. Execute command with timeout
    # 5. Log result to RepairLogger
    # 6. On failure: rollback via UndoManager
    # 7. Return result status to GUI via syncHash
}
```

### 6.4 Startup Guard

SmartEngine enforces 4 independent launch checks:
1. `$GUI_Mode` switch parameter
2. Global `$global:syncHash` variable presence
3. `$hash` parameter validation (must be internal)
4. RSA token verification (same as LauncherGUI)

All checks must confirm the engine was launched by the GUI before execution proceeds.

---

## 7. Session & Progress Management

### 7.1 Progress Manager (`AURORA-ProgressManager.ps1`)

**Cache directory structure:**
```
SessionCache/
├── active/                    # Current active session
│   └── {session-id}.json      # Session data (progress, stage, params)
├── checkpoints/               # Checkpoint backups
│   └── {session-id}_cp{}.json # Checkpoint snapshots
└── archive/                   # Completed sessions
    └── {session-id}.json      # Archived session record
```

**Session lifecycle:**

```
Create-Session ──► Save-Progress ──► Create-Checkpoint ──► Complete-Session
       │                  │                    │                    │
       ▼                  ▼                    ▼                    ▼
   active/             active/             checkpoints/          archive/
   {id}.json           {id}.json           {id}_cp1.json         {id}.json
```

**Key functions:**

| Function | Description |
|---|---|
| `Initialize-ProgressManager` | Set up cache directories with tool/TEMP fallback |
| `New-AuroraSession` | Create session with unique ID, store initial state |
| `Save-AuroraProgress` | Save current progress percentage + stage name |
| `Create-AuroraCheckpoint` | Create a named checkpoint snapshot |
| `Find-LatestSession` | Locate most recent recoverable session |
| `Restore-AuroraSession` | Restore session data from disk |
| `Complete-AuroraSession` | Archive completed session, clean active |
| `Clean-ExpiredSessions` | Remove sessions older than 7 days |

**Location strategy:**
1. Primary: Tool directory `SessionCache/` (writable check required)
2. Fallback: `%TEMP%\AURORA-SessionCache\` (always writable)

**Bilingual support:**
All log messages use `Get-LocalizedString` with `$script:Language` context switching.

### 7.2 Undo Manager (`AURORA-UndoManager.ps1`)

**Backup types:**

| Type | Target | Backup Content |
|---|---|---|
| `Registry` | Registry paths | Key + values exported as `.reg` |
| `File` | File paths | File content copied to backup dir |
| `Service` | Service names | Current config + startup type |

**Snapshot lifecycle:**
```
Create-BackupSnapshot ─► Store to BackupDir
     │
     ├── Repair succeeds → optional cleanup
     │
     └── Repair fails → Restore-BackupSnapshot (instant rollback)
```

**Backup directory:** `SessionCache\backup\`

### 7.3 Undo Viewer (`AURORA-UndoViewer.ps1`)

Provides a browseable interface for viewing and selectively restoring backup snapshots. Integrates with the main GUI view system.

---

## 8. Build System

### 8.1 `build.ps1` Pipeline

```
┌──────────────────────────────────────────────────────────────────┐
│                    build.ps1 Pipeline (6 Steps)                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  [PRE] Version Management                                        │
│  ├─ Read version.txt                                             │
│  ├─ Optional auto-increment (-IncrementVersion)                   │
│  └─ Initialize build.log                                         │
│                                                                   │
│  [0.5] RSA Key Generation                                        │
│  ├─ RSACryptoServiceProvider(2048)                                │
│  ├─ Export private + public XML                                  │
│  ├─ Password obfuscation: XOR shuffle + random 16-byte mask      │
│  └─ Generate session derivation salt (32 random bytes)           │
│                                                                   │
│  [0.7] Pre-injection → SecurityModule                            │
│  ├─ Inject RSA public key                                         │
│  ├─ Inject session salt                                           │
│  └─ Verify injection succeeded                                    │
│                                                                   │
│  [0] Required Files Check                                        │
│  └─ Verify all 23+ files exist                                   │
│                                                                   │
│  [0.8] Version Injection                                         │
│  └─ Synchronize version tag across all scripts                    │
│                                                                   │
│  [1] SHA256 Hash Calculation                                     │
│  ├─ Hash all required files (SHA256)                             │
│  └─ Generate hash list: "<hash> <relative_path>"                 │
│                                                                   │
│  [2.5] C# AuroraGuard Hash Injection                             │
│  ├─ Inject 23 SHA256 hashes into SecurityModule's                │
│  │   AuroraGuard._expected dictionary                            │
│  ├─ Re-hash SecurityModule (content changed)                      │
│  └─ Update hash list with new SecurityModule hash                 │
│                                                                   │
│  [2] Generate Plain Text Check Data                              │
│  └─ Hash lines → plain bytes                                     │
│                                                                   │
│  [3] AES-256-CBC Encryption                                      │
│  ├─ PBKDF2-SHA256 (100,000 iterations)                           │
│  ├─ Random 16-byte salt                                          │
│  ├─ Random IV                                                    │
│  └─ Output: GAURORA.CHK.ENC (Base64)                             │
│                                                                   │
│  [4] Encryption Verification                                     │
│  ├─ Decrypt GAURORA.CHK.ENC                                       │
│  └─ Verify content contains expected file names                   │
│                                                                   │
│  [5] C# EXE Compilation                                          │
│  ├─ Generate C# source with embedded:                            │
│  │   ├─ RSA private key                                          │
│  │   ├─ Password obfuscation data                                │
│  │   ├─ Session salt                                             │
│  │   ├─ Required file list                                       │
│  │   ├─ Named Pipe watchdog server                               │
│  │   └─ RSA signing logic                                        │
│  ├─ Compile via csc.exe (C# compiler)                            │
│  ├─ Target: .NET Framework 4.x, C# 5.0                           │
│  ├─ Windowless (Windows Application, no console)                 │
│  └─ Embed icon (AURORAICON.ico)                                  │
│                                                                   │
│  [6] ZIP Packaging                                               │
│  ├─ Package all files into AURORA-V{version}.zip                 │
│  ├─ Maintain directory structure                                  │
│  └─ Write build summary to build.log                             │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 8.2 Master Password Requirements

The build process requires a master password with the following constraints:

| Requirement | Detail |
|---|---|
| Minimum length | 8 characters |
| Uppercase | At least 1 |
| Lowercase | At least 1 |
| Digit | At least 1 |
| Special character | At least 1 (non-alphanumeric) |
| Max retries | 3 attempts |

The password is used to:
1. Derive the AES-256 encryption key for `GAURORA.CHK.ENC` (via PBKDF2-SHA256, 100k iterations)
2. Embed obfuscated password verification data into the C# EXE

### 8.3 C# EXE Compilation Details

**Compiler:** `csc.exe` (C# Compiler from .NET Framework)

**References:**
- `System.dll`
- `System.Core.dll`
- `System.Windows.Forms.dll`
- `System.Security.dll`

**Embedded data:**
- RSA-2048 private key (XML format, used for signing launch tokens)
- Password obfuscation data: XOR mask + shuffled bytes + order array
- Session derivation salt (32 bytes)
- Complete file list for file-existence checks

**Output configuration:**
- Windowless application (no console window)
- Custom icon: `AURORAICON.ico`
- Single-file EXE output

### 8.4 ZIP Packaging

The final build step creates a distribution ZIP archive containing:
- `AURORA-Analyzer.exe` (compiled C# launcher)
- `Scripts/` directory (all 22+ PS1/PSD1 files with directory structure preserved)
- `Data/` directory (`AURORA-TechData.json`, `AURORA-TechData.cache.clixml`)
- `Resources/` directory (`AURORAICON.ico`, `CascadiaMono.ttf`)
- `GAURORA.CHK.ENC` (encrypted integrity check file)

---

## 9. Performance Tier System

### 9.1 Hardware Detection

On startup, the launcher profiles the system hardware to determine the optimal performance tier:

```powershell
# Hardware enumeration (time-limited to prevent WMI hang)
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

$ramGB = [Math]::Round($cs.TotalPhysicalMemory / 1GB)
$logicalCores = $cpu.NumberOfLogicalProcessors
$baseClock = $cpu.MaxClockSpeed  # MHz

# Scoring algorithm
$perfScore = ($logicalCores * 15) + ($ramGB * 5) + ([Math]::Max(0, ($baseClock - 2000) / 100))
```

### 9.2 Tier Thresholds

| Tier | Score Threshold | Typical Hardware | Features |
|---|---|---|---|
| **Eco** | `< 70` | Dual-core, 4GB RAM, low clock | 30 FPS, 80 stars, no particles, no complex effects |
| **Balanced** | `70–119` | Quad-core, 8GB RAM | 60 FPS, 180 stars, 30 particles, path gradient |
| **Performance** | `120–239` | Hexa-core, 16GB RAM | 60 FPS, 350 stars, 80 particles, all effects |
| **Extreme** | `≥ 240` | Octa-core+, 32GB+ RAM | 60 FPS, 600 stars, 150 particles, all effects maxed |

### 9.3 Tier Propagation

The detected tier is injected as a process-level environment variable:
```powershell
[Environment]::SetEnvironmentVariable("AURORA_PERF_TIER", $global:AuroraPerfTier)
```

This is read by the C# animation engine via:
```csharp
string tierStr = Environment.GetEnvironmentVariable("AURORA_PERF_TIER");
```

The `AuroraRenderEngine` static constructor configures all rendering parameters based on this tier, ensuring the animation system automatically adapts to the hardware without any runtime overhead.

---

## 10. Cross-Thread Communication

### 10.1 syncHash Mechanism

AURORA uses a **global synchronized hashtable** (`$global:syncHash`) as the primary cross-thread communication channel between:
- The main GUI thread (Windows Forms STA thread)
- PRO/SmartEngine Runspaces (background PowerShell runspaces)
- Watchdog Runspace (dedicated background thread)

```powershell
# GUI thread creates the syncHash
$global:syncHash = [hashtable]::Synchronized(@{
    # UI State
    WindowState = "Idle"           # Idle, Loading, Processing, Error
    CurrentStage = ""              # Current processing stage name
    ProgressPercent = 0            # 0-100

    # Cross-thread signals
    RequestElevation = $false      # GUI requests admin elevation
    ElevationGranted = $false      # User approved elevation
    ShouldExit = $false            # Signal to shut down

    # Data channels
    OutputData = $null             # Engine → GUI: result data
    RepairResults = $null          # Repair outcomes
    ErrorMessage = $null           # Error propagation

    # Session
    SessionChoice = $null          # "resume" or "restart"
    SessionTimeoutEpoch = 0        # Timeout tracking
})
```

### 10.2 Communication Patterns

**GUI → Engine:**
```powershell
$global:syncHash.RequestElevation = $true     # Signal elevation needed
while (-not $global:syncHash.ElevationGranted) # Wait for response
{ Start-Sleep -Milliseconds 100 }
```

**Engine → GUI:**
```powershell
$global:syncHash.ProgressPercent = 45
$global:syncHash.CurrentStage = "Extracting Security logs..."
```

**Session Recovery:**
```powershell
# Engine sets session data
$global:syncHash.SessionData = @{ ... }
$global:syncHash.SessionTimeoutEpoch = [DateTimeOffset]::UtcNow.AddSeconds(30)

# GUI reads and displays dialog, sets choice
$global:syncHash.SessionChoice = "resume"
```

### 10.3 Thread Safety

PowerShell's `[hashtable]::Synchronized()` provides built-in thread safety via `SyncRoot` locking. All read/write operations on `syncHash` are atomic at the .NET level, preventing race conditions between the STA GUI thread and background Runspaces.

---

## 11. Technology Stack Summary

| Category | Technology | Version / Details |
|---|---|---|
| **Entry Point** | C# .NET Framework | 4.x, C# 5.0 language level |
| **Main Script** | PowerShell | 5.0+ |
| **GUI Framework** | Windows Forms (WinForms) | System.Windows.Forms |
| **Animation** | C# embedded DLL | Custom FloatAnimation engine |
| **Cryptography** | .NET `System.Security.Cryptography` | RSA-2048, AES-256-CBC, SHA256, HMAC-SHA256, PBKDF2 |
| **IPC** | Windows Named Pipes | `System.IO.Pipes.NamedPipeClientStream/ServerStream` |
| **Threading** | PowerShell Runspaces | STA + MTA apartments |
| **Build** | PowerShell + C# Compiler | `csc.exe`, `Add-Type` |
| **Data Serialization** | JSON + CLIXML | TechData.json, PowerShell Export-CliXml |
| **Font** | Cascadia Mono | Embedded `.ttf` resource |
| **Anti-Debug** | Win32 Native API | P/Invoke: kernel32.dll, ntdll.dll |
| **Anti-Dump** | Windows NT API | `NtSetInformationThread(ThreadHideFromDebugger)` |
| **File Monitoring** | .NET `FileSystemWatcher` | Runtime integrity watching |
| **WMI/CIM** | `Get-CimInstance` | Hardware profiling |

---

## 12. Attack Surface Analysis

### 12.1 Attack Vectors and Mitigations

| Attack Vector | Risk | Mitigation Layer |
|---|---|---|
| **PS1 file tampering (on-disk)** | HIGH | Layer 1 (RSA hash verification), Layer 3 (AuroraGuard integrity check), Layer 4 (password check) |
| **PS1 file tampering (in-memory)** | HIGH | Layer 3 (AuroraGuard periodic re-verification every 10s) |
| **Direct PS1 execution (bypassing EXE)** | HIGH | Layer 1 (RSA token must exist), Layer 4 (password requirement), SmartEngine startup guard |
| **Debugger attachment** | HIGH | Layer 3 (4 debugger API checks), process name scan (28 tools) |
| **Hardware breakpoints** | HIGH | Layer 3 (DR0–DR7 register scan) |
| **DLL injection / code cave** | HIGH | Layer 3 (anti-dump, ThreadHideFromDebugger) |
| **Process dumping** | HIGH | Layer 3 (anti-dump via ThreadHideFromDebugger) |
| **Named Pipe spoofing** | MEDIUM | Layer 2 (HMAC-SHA256 session key, bidirectional auth) |
| **Token replay attack** | MEDIUM | Layer 1 (60s timestamp window, single-use token file) |
| **UAC bypass (elevation spoofing)** | MEDIUM | Layer 1 (elevation token: 120s window, AES-256 encrypted payload) |
| **Brute-force password** | LOW | Layer 4 (PBKDF2 100k iterations, 3 retry limit) |
| **WMI/CIM injection** | LOW | Time-limited queries, fallback to default tier |
| **Watchdog process kill** | MEDIUM | Layer 5 (EXE monitors process handle, kill on heartbeat loss) |
| **Language/encoding bypass** | LOW | `Get-Command Test-RSATokenSignature` existence check |

### 12.2 Known Limitations

1. **PowerShell script transparency:** All PS1 source code is visible as plaintext on disk. Defense relies on integrity verification, not obfuscation.
2. **Runspace isolation:** AuroraGuard compiled in the main Runspace is not automatically visible in child Runspaces. SmartEngine adds a secondary `VerifyOrDie()` call on startup.
3. **Token cleanup race condition:** If the EXE process deletes the token file before the elevated PS1 process reads it, the elevation trust chain breaks. Mitigated by the elevation token (`AURORA-SEC-2026-001` fix).
4. **Single-point watchdog:** One EXE instance watches one PS1 process. Multiple concurrent launches require multiple watchdog instances.

### 12.3 Security Assumptions

- The build environment is trusted (private key never leaves the build machine)
- The master password is known only to the build operator / distributor
- The target Windows system's `csc.exe` compiler is trusted
- The initial EXE binary (`AURORA-Analyzer.exe`) is distributed through a trusted channel

---

## 13. Contribution Guide

### 13.1 Module Development Guidelines

1. **Follow the layer separation model.** New code must be placed in the appropriate layer directory:
   - Core utilities → `Scripts/Core/`
   - Security features → `Scripts/Security/`
   - UI components → `Scripts/UI/Controls/` or `Scripts/UI/Views/`
   - Engine logic → `Scripts/Engines/`
   - PRO features → `Scripts/PRO/`
   - Session logic → `Scripts/Session/`
   - Repair tools → `Scripts/Repair/`
   - Language strings → `Scripts/GUI/AURORA-Language.psd1`

2. **Implement startup guards in all engine modules:**
   ```powershell
   if (-not $isLaunchedByGUI) {
       Write-Host "This script cannot be run directly"
       exit 1
   }
   ```

3. **Use `Invoke-SafeOperation` for all file/crypto/system operations:**
   ```powershell
   Invoke-SafeOperation -Operation {
       # Critical code here
   } -OperationName "Descriptive Name" -ContinueOnError
   ```

4. **Use `Write-AuroraLog` for all logging:**
   ```powershell
   Write-AuroraLog "Message" -Level "Info|Warning|Error"
   ```

5. **Add bilingual support** by adding entries to `AURORA-Language.psd1`.

6. **Update `build.ps1` `$RequiredFiles` array** when adding new files.

7. **Add to `$guardTargetFiles` in `build.ps1`** if the new file should be integrity-monitored by AuroraGuard.

### 13.2 Build Process

```powershell
# Normal build
.\build.ps1

# Build with version auto-increment
.\build.ps1 -IncrementVersion
```

### 13.3 Testing

Test scripts are located in the `test/` directory:

| Test File | Purpose |
|---|---|
| `Test-Verification.ps1` | Full security verification test |
| `Test-Bilingual.ps1` | Bilingual support validation |
| `Test-ProgressManager.ps1` | Progress/session manager tests |
| `Test-ProgressManager-Integration.ps1` | Integration tests for progress manager |
| `Test-ProgressManager-Load.ps1` | Load/stress tests for session persistence |
| `Test-UndoBackup.ps1` | Undo backup system tests |
| `Test-RealBackup.ps1` | Real backup scenario tests |
| `AURORA-UndoTest.ps1` | Undo manager unit tests |
| `Test-PRO-Merge.ps1` | PRO engine merge validation |
| `Test-Runtime-Tamper.ps1` | Runtime tamper detection tests |
| `Test-Runtime-Tamper-Fixed.ps1` | Runtime tamper detection (post-fix) |
| `test-rsa-verification.ps1` | RSA token verification tests |
| `Remove-BOM.ps1` | BOM removal utility |
| `check_brackets.ps1` | Bracket/parenthesis syntax checker |

### 13.4 File Structure Reference

```
AURORA-Analyzer-Factory/
├── AURORA-Analyzer.exe                  # Compiled C# launcher
├── build.ps1                            # Build system
├── AURORA-build.bat                     # Build batch shortcut
├── version.txt                          # Version marker
├── build.log                            # Build output log
├── cache.txt                            # Build cache
├── GAURORA.CHK.ENC                      # Encrypted integrity check
├── Data/
│   ├── AURORA-TechData.json             # Knowledge graph
│   └── AURORA-TechData.cache.clixml     # Precompiled cache
├── Resources/
│   ├── AURORAICON.ico                   # Application icon
│   └── CascadiaMono.ttf                 # Monospace font
├── Scripts/
│   ├── AURORA-AnalyzerLauncherGUI.ps1   # Main launcher
│   ├── Core/
│   │   ├── AURORA-CoreEngine.ps1
│   │   └── AURORA-AnimationCoreEngine.ps1
│   ├── Security/
│   │   └── AURORA-SecurityModule.ps1
│   ├── UI/
│   │   ├── Controls/
│   │   │   ├── AURORA-UIControls.ps1
│   │   │   └── AURORA-Animations.ps1
│   │   └── Views/
│   │       ├── View-MainForm.ps1
│   │       ├── View-SplashScreen.ps1
│   │       ├── View-ProMode.ps1
│   │       └── Dialogs/
│   │           ├── View-SessionRestoreDialog.ps1
│   │           ├── View-ElevationDialog.ps1
│   │           ├── View-PermissionInfo.ps1
│   │           └── View-AdminElevation.ps1
│   ├── Engines/
│   │   └── AURORA-SmartEngine.ps1
│   ├── PRO/
│   │   ├── AURORA-AnalyzerPRO-Engine.ps1
│   │   └── AURORA-AnalyzerPRO.ps1
│   ├── Session/
│   │   ├── AURORA-ProgressManager.ps1
│   │   ├── AURORA-ProgressManager-Integration.ps1
│   │   ├── AURORA-UndoManager.ps1
│   │   └── AURORA-UndoViewer.ps1
│   ├── Repair/
│   │   ├── AURORA-RepairTools.ps1
│   │   ├── AURORA-RepairLogger.ps1
│   │   └── AURORA-RestoreManager.ps1
│   └── GUI/
│       ├── AURORA-GUI-Functions.ps1
│       └── AURORA-Language.psd1
├── UserLogs/                            # Sample exported log data
├── Docs/                                # Internal documentation
├── test/                                # Test scripts
└── .github/workflows/                   # CI/CD configuration
```

---

> **Document Version:** 1.0  
> **Compatible With:** AURORA Analyzer V1.3.26.5  
> **Last Updated:** 2026-06-09  
> **Language:** English (Technical Documentation for Community)