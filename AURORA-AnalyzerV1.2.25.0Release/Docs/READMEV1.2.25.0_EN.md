# AURORA Analyzer V1.2.25.0Release — Technical Documentation

> **Target Audience**: Security Researchers / Reverse Engineers / Community Contributors / Advanced Developers
> **Document Focus**: In-depth technical details, architecture analysis, and security implementation — suitable for professional research and secondary development

***

## Table of Contents

- [1. Project Overview](#1-project-overview)
- [2. Security Architecture](#2-security-architecture)
  - [2.1 Defense-in-Depth Model](#21-defense-in-depth-model)
  - [2.2 Key Hierarchy](#22-key-hierarchy)
  - [2.3 Authentication & Verification Chain](#23-authentication--verification-chain)
- [3. Core Subsystems](#3-core-subsystems)
  - [3.1 RSA Token Verification](#31-rsa-token-verification)
  - [3.2 EXE Watchdog Duplex Communication](#32-exe-watchdog-duplex-communication)
  - [3.3 AuroraGuard Runtime Sentinel](#33-auroraguard-runtime-sentinel)
  - [3.4 File Integrity Verification](#34-file-integrity-verification)
- [4. GUI Animation Engine Architecture](#4-gui-animation-engine-architecture)
  - [4.1 Animation Core Engine](#41-animation-core-engine)
  - [4.2 Easing System Deep Dive](#42-easing-system-deep-dive)
  - [4.3 Custom Control Layer](#43-custom-control-layer)
- [5. v1.2.25.0 Animation System Upgrade Details](#5-v12250-animation-system-upgrade-details)
  - [5.1 Easing Library Expansion](#51-easing-library-expansion)
  - [5.2 Dynamic Frame Rate Adaptation Fix](#52-dynamic-frame-rate-adaptation-fix)
  - [5.3 Ripple Animation System](#53-ripple-animation-system)
  - [5.4 Magnetic Snap System](#54-magnetic-snap-system)
  - [5.5 Smooth Progress Bar Transitions](#55-smooth-progress-bar-transitions)
- [6. Anti-Debugging & Anti-Analysis Techniques](#6-anti-debugging--anti-analysis-techniques)
- [7. Build System](#7-build-system)
- [8. Attack Surface Analysis](#8-attack-surface-analysis)
- [9. Contributing](#9-contributing)

***

## 1. Project Overview

AURORA Analyzer is a Windows system diagnostics tool built on a **PowerShell / C# hybrid architecture**. The project employs a three-layer architecture of **PS1 Script + Embedded C# Types + C# EXE Loader**:

```
┌─────────────────────────────────────────┐
│  AURORA-Analyzer.exe (C# EXE Loader)     │
│  - RSA token generation & signing        │
│  - Named Pipe watchdog server            │
│  - Process lifecycle management           │
└──────────────┬──────────────────────────┘
               │ Process.Start + env var injection
┌──────────────▼──────────────────────────┐
│  AURORA-AnalyzerLauncherGUI.ps1          │
│  - GUI entry point (Windows Forms)        │
│  - AuroraGuard (embedded C# type)         │
│  - Watchdog client + Runspace             │
│  - Performance tiering + animation engine │
│  - TechButton / AuroraProgressBar /       │
│    StarfieldPanel custom controls         │
└──────────────┬──────────────────────────┘
               │ Dot-sourcing
┌──────────────▼──────────────────────────┐
│  Core Engine Scripts (16 .ps1 files)      │
│  - SmartEngine / CoreEngine              │
│  - RepairTools / UndoManager             │
│  - ProgressManager / AnimationCore       │
│  - All files protected by SHA256 hashes  │
└─────────────────────────────────────────┘
```

**Technology Stack**:

| Layer | Language | Runtime |
|-------|----------|---------|
| EXE Loader | C# | .NET Framework 4.x (compiled to target EXE) |
| GUI Launcher | PowerShell + Embedded C# | Windows PowerShell 5.1+ |
| Core Engines | PowerShell | Windows PowerShell 5.1+ |
| Animation Engine | Embedded C# (Add-Type compiled to DLL) | .NET Framework 4.x |

---

## 2. Security Architecture

### 2.1 Defense-in-Depth Model

```
Layer 0: Build-Time Protection
  ├── RSA key pair (build tool holds private key for signing tokens)
  ├── SHA256 integrity hash table (hardcoded in AuroraGuard)
  └── Token timeliness control (60-second window)

Layer 1: Launch Verification
  ├── RSA token signature verification (SHA256 + PKCS#1 v1.5)
  ├── Hash list decryption (AES-256-CBC + PBKDF2 session key)
  └── Launch environment sanity check (non-debug environment)

Layer 2: IPC Security
  ├── Named Pipe mutual authentication
  ├── HMAC-SHA256 challenge-response protocol
  └── Bidirectional heartbeat (single failure = termination)

Layer 3: Runtime Sentinel
  ├── Debugger API detection (IsDebuggerPresent + NtQueryInformationProcess)
  ├── Hardware breakpoint detection (Dr0-Dr3 register scan)
  ├── PEB analysis (NtGlobalFlag bits)
  ├── Process name scan (90+ known debug tools)
  ├── DLL injection detection (module path analysis)
  └── Continuous polling (every 3 seconds + WMI real-time events)

Layer 4: Exit Cleanup
  ├── Dual event registration (PowerShell.Exiting + ProcessExit)
  ├── Resource cascade release (Pipe → Runspace → Timer → WMI)
  └── Environment variable zeroization
```

### 2.2 Key Hierarchy

```
Master Secret (RSA private key, held only by build tool)
    │
    ├──sign──→ RSA Token (SHA256 signature, 60-second validity)
    │         │
    │         └──derive──→ AES Session Key (PBKDF2, Nonce, AU_SESSION_2026_SALT_V1)
    │                       │
    │                       └──decrypt──→ Hash Manifest (SHA256 list)
    │
    └──sign──→ EXE embedded verification logic (RSA public key hardcoded in PS1)
```

### 2.3 Authentication & Verification Chain

```
EXE Build Time:
  1. Generate Random Nonce (32 hex chars)
  2. Compute SHA256 hashes of all core scripts
  3. PBKDF2(Nonce, AesSalt) → AES Session Key
  4. AES-256-CBC encrypt hash list → HashPayload
  5. RSA-SHA256 sign(Nonce:Timestamp:HashPayload) → Signature
  6. Write token file: Nonce:Timestamp:HashPayload:Signature

PS1 Launch Time:
  1. Read $env:AURORA_TOKEN_PATH → token file
  2. Parse Nonce:Timestamp:HashPayload:Signature
  3. RSA public key verify signature (SHA256, PKCS#1 v1.5)
  4. Check timestamp (|now - timestamp| < 60s)
  5. PBKDF2(Nonce, AesSalt) → AES Session Key
  6. AES-256-CBC decrypt HashPayload → hash manifest
  7. AuroraGuard.Initialize(baseDir) → store base directory
  8. AuroraGuard.CheckIntegrity() → verify SHA256 per file

EXE-PS1 Watchdog Handshake:
  1. EXE creates NamedPipeServerStream (random name)
  2. Environment variable injection → PS1 connects via NamedPipeClientStream
  3. EXE sends HMAC key (49-byte handshake: 0x10 + key)
  4. PS1 stores HMAC key, enters watchdog response loop
  5. Periodic challenge: EXE sends 0x03 + 16B Nonce + 8B Timestamp
  6. PS1 responds: HMAC-SHA256(Nonce) + 8B Uptime + 32B SelfHash
  7. EXE verifies HMAC → mismatch = Kill(ps1Proc)
```

---

## 3. Core Subsystems

### 3.1 RSA Token Verification

**Key Parameters**:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| Signing Algorithm | RSA-SHA256 + PKCS#1 v1.5 | Token signing |
| Public Key Format | XML (Modulus + Exponent) | Embedded in PS1 |
| Session Key Derivation | PBKDF2 (Rfc2898DeriveBytes) | 1000 iterations |
| AES Mode | AES-256-CBC, PKCS7 Padding | Hash list encryption |
| Token Validity | 60 seconds (｜age｜ < 60) | Anti-replay |

### 3.2 EXE Watchdog Duplex Communication

**Named Pipe Protocol**:

| Command | Direction | Payload | Description |
|---------|-----------|---------|-------------|
| `0x10` | EXE→PS1 | 32B HMAC Key | Initial handshake |
| `0x03` | EXE→PS1 | 16B Nonce + 8B Timestamp | Periodic challenge |
| `0x03` | PS1→EXE | 32B HMAC + 8B Uptime + 32B SelfHash | Challenge response |

### 3.3 AuroraGuard Runtime Sentinel

**Detection Layers**:

```
CheckDebuggerAPIs()
  ├── IsDebuggerPresent()                     // kernel32
  ├── CheckRemoteDebuggerPresent()            // kernel32
  ├── NtQueryInformationProcess(DebugPort)    // ntdll, Class=7
  ├── NtQueryInformationProcess(DebugFlags)   // ntdll, Class=31
  ├── NtQueryInformationProcess(HandleTracing)// ntdll, Class=34
  ├── CheckPEBNtGlobalFlag()                  // PEB.NtGlobalFlag
  └── CheckHardwareBreakpoints()              // GetThreadContext + Dr0-Dr3

CheckDebuggerProcesses()
  └── Process.GetProcesses() enumeration → match 90+ debugger names

CheckDLLInjection()
  └── Process.Modules enumeration → non-system/non-framework DLL analysis

CheckIntegrity()
  └── SHA256 hash comparison of 16 core files (10-second cache)
```

### 3.4 File Integrity Verification

```csharp
// 10-second cache for repeated calls
private static readonly TimeSpan _integrityCacheDuration = TimeSpan.FromSeconds(10);
private static readonly object _integrityLock = new object();

// Up to 3 retries for file-locked scenarios
while (retryCount < maxRetry)
{
    using (var sha = SHA256.Create())
    {
        byte[] hash = sha.ComputeHash(File.ReadAllBytes(path));
        actual = BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
    }
    hashOk = true;
    break;
}
```

---

## 4. GUI Animation Engine Architecture

### 4.1 Animation Core Engine

**Location**: [Core\AURORA-AnimationCoreEngine.ps1](file:///e%3A/PC%20SOFT/%E4%BC%98%E5%8C%96%E8%BD%AF%E4%BB%B6/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/Scripts/Core/AURORA-AnimationCoreEngine.ps1)

**Architecture**:

```
┌───────────────────────────────────────────────────────────┐
│                  Application Layer (PowerShell)             │
│  ┌──────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  TechButton  │  │ AuroraProgressBar│  │StarfieldPanel│ │
│  └──────────────┘  └─────────────────┘  └──────────────┘ │
└───────────────────────────────────────────────────────────┘
                            ↓
┌───────────────────────────────────────────────────────────┐
│              Animation Engine (AURORA-AnimationCoreEngine)   │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  AURORA_Animation (static facade) → AnimationManager│  │
│  │  ├── FloatAnimation (value interpolation)           │  │
│  │  ├── GlareSweepAnimation (glare sweep)              │  │
│  │  ├── ModalTimerAnimation (modal dialog)             │  │
│  │  └── LoopAnimation (infinite loop)                  │  │
│  └─────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────┐  │
│  │     AuroraRenderEngine (performance tier + FPS)      │  │
│  └─────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────┘
                            ↓
┌───────────────────────────────────────────────────────────┐
│                   Rendering (GDI+ / WinForms)                │
│  ┌──────────────┐  ┌───────────────┐  ┌────────────────┐ │
│  │ DoubleBuffer │  │PathGradient   │  │LinearGradient  │ │
│  └──────────────┘  └───────────────┘  └────────────────┘ │
└───────────────────────────────────────────────────────────┘
```

**Core Classes & Interfaces**:

| Type | Role | Notes |
|------|------|-------|
| `AuroraRenderEngine` | Static config class | Performance tier params, FPS control |
| `AnimationManager` | Scheduler | Timer-driven animation loop, lifecycle management |
| `Animation` (abstract) | Base class | Abstract base with `Update()` template method |
| `FloatAnimation` | Numeric animation | Float interpolation supporting 20 easing types |
| `GlareSweepAnimation` | Glare sweep | IAnimatable-based specialized glare |
| `ModalTimerAnimation` | Modal animation | Infinite loop fade in/out for modals |
| `LoopAnimation` | Loop animation | Generic infinite loop (ripples, magnetic, etc.) |
| `IAnimatable` | Interface | Decouples controls from animation engine |
| `AURORA_Animation` | Facade class | Singleton static facade, simplified API |

**Performance Tier System** (`AuroraRenderEngine`):

Hardware scoring:
```powershell
$perfScore = ($logicalCores * 15) + ($ramGB * 5) + ([Math]::Max(0, ($baseClock - 2000) / 100))
```

| Score | Tier | TargetFPS | StarCount | ParticleCount | Effects Level |
|-------|------|-----------|-----------|---------------|---------------|
| >= 240 | Extreme | 60 | 600 | 150 | Full |
| >= 120 | Performance | 60 | 350 | 80 | High |
| >= 70 | Balanced | 60 | 180 | 30 | Medium |
| < 70 | Eco | 30 | 80 | 0 | Minimal |

### 4.2 Easing System Deep Dive

**EasingType Enum (20 Types)**:

| Group | Members | Math Characteristic |
|-------|---------|-------------------|
| Linear | Linear | `f(t) = t` |
| Cubic | EaseIn / Out / InOut | `f(t) = t³` variants |
| Quad | EaseIn / Out / InOut | `f(t) = t²` variants |
| Quart | EaseIn / Out / InOut | `f(t) = t⁴` variants |
| Quint | EaseIn / Out / InOut | `f(t) = t⁵` variants |
| Elastic | EaseIn / Out / InOut | Exponential decay × sine |
| Bounce | EaseIn / Out / InOut | Piecewise quadratic bounce |

**EaseOutBounceHelper**:

```csharp
private static float EaseOutBounceHelper(float t)
{
    float n1 = 7.5625f;
    float d1 = 2.75f;
    if (t < 1f / d1) return n1 * t * t;
    else if (t < 2f / d1) return n1 * (t -= 1.5f / d1) * t + 0.75f;
    else if (t < 2.5f / d1) return n1 * (t -= 2.25f / d1) * t + 0.9375f;
    else return n1 * (t -= 2.625f / d1) * t + 0.984375f;
}
```

**Elastic Implementation**:

```csharp
// EaseOutElastic
float p = 0.3f;        // period
float s = p / 4f;      // phase offset
easedProgress = (float)Math.Pow(2, -10 * progress) 
              * (float)Math.Sin((progress - s) * (2 * Math.PI) / p) + 1;
```

### 4.3 Custom Control Layer

**TechButton — Dynamic Tech Button**:

| Property | Animation Range | Duration | Easing Type |
|----------|----------------|----------|-------------|
| `_hoverProgress` | 0→1 | 300ms | EaseOutCubic |
| `_glowProgress` | 0→1 | 300ms | EaseOutCubic |
| `_pressProgress` | 0→1 | 200ms | EaseOutCubic |
| `_glareProgress` | -0.3→1.3 | 1500ms | EaseOutCubic |
| `_ripples[]` (V1.2 new) | Dynamic | Continuous | Asymptotic expansion |
| `_magneticOffsetX/Y` (V1.2 new) | 0→±17.5px | Real-time | `MAGNETIC_SMOOTH` |

**9-Layer Paint Structure**:

| Layer | Content | Technique |
|-------|---------|-----------|
| 1 | Outer Glow | PathGradientBrush |
| 2 | Shadow | PathGradientBrush |
| 3 | Body Gradient | LinearGradientBrush |
| 4 | Glare Sweep | PathGradientBrush |
| 5 | Border | Pen |
| 6 | Inner Glow | PathGradientBrush |
| 7 | Press Shadow | PathGradientBrush |
| 8 | Text | DrawString |
| 9 | **Ripples** (V1.2 new) | SolidBrush circle |

**AuroraProgressBar — Particle Progress Bar**:

UWP-style glow scan + particle system + smooth progress transition. Particle params: max 40, lifetime 1.0~2.5s, drift speed ±0.2px/frame.

**StarfieldPanel — Cinematic Starfield Background**:

- 80-600 stars (performance tiered) with cinematic fly-in and supernova burst
- Mouse interaction glow (60px sensing range)
- Dynamic meteor generation (0.009 probability/frame, 12-point trail)
- Deep space background particles (edge→center movement)

---

## 5. v1.2.25.0 Animation System Upgrade Details

### 5.1 Easing Library Expansion

**Change**: Easing functions expanded from 4 Cubic curves to 20 types, adding Quad, Quart, Quint, Elastic, and Bounce series.

**FloatAnimation.Update() switch branches**: ~25 lines → ~100 lines, 3 new EaseOutBounceHelper calls.

**Design Considerations**:
- Default easing remains `EaseOutCubic` for backward compatibility
- EaseOutBounceHelper uses classic piecewise quadratic (n1=7.5625, d1=2.75), aligned with industry standards
- Elastic easing uses standard exponential decay × sine composite, parameters from common CSS `cubic-bezier` configurations

### 5.2 Dynamic Frame Rate Adaptation Fix

**Root Cause**: In V1.1.24.5, `AnimationManager` constructor hardcoded `Interval = 16`, rendering `GetTimerInterval()`'s 33ms (30FPS) for Eco mode ineffective.

**Fix**: Changed `new Timer { Interval = 16 }` to `new Timer { Interval = AuroraRenderEngine.GetTimerInterval() }`

**Performance Impact**:

| Mode | Before | After | CPU Savings |
|------|--------|-------|-------------|
| Eco | 16ms/tick (60FPS) | 33ms/tick (30FPS) | ~50% |
| Balanced+ | 16ms/tick (60FPS) | 16ms/tick (60FPS) | 0% |

This is the **smallest code change with the largest practical benefit** — just one line.

### 5.3 Ripple Animation System

**New Ripple Class** (TechButton private inner class):

```csharp
private class Ripple
{
    public PointF Origin;
    public float Radius;
    public float MaxRadius;
    public float Alpha;
    public bool IsDead;
    
    public void Update(float deltaTime)
    {
        this.Radius += (this.MaxRadius - this.Radius) * 0.15f;
        this.Alpha -= 0.03f;
        if (this.Alpha <= 0f || this.Radius >= this.MaxRadius * 0.95f)
            this.IsDead = true;
    }
}
```

**Lifecycle**:
1. User clicks → OnMouseClick creates Ripple → added to `_ripples` list
2. LoopAnimation updates all ripples each frame → asymptotic expansion + opacity decay
3. Death condition met → removed from list
4. Active ripple count > 0 → triggers Invalidate() → OnPaint layer 9 rendering

**Rendering**: Uses `Color.FromArgb((int)(ripple.Alpha * 80), 200, 255, 255)` cyan semi-transparent solid circle.

### 5.4 Magnetic Snap System

**Parameters**:

```csharp
const float MAGNETIC_RADIUS   = 135f;   // sensing radius
const float MAGNETIC_STRENGTH = 0.35f;  // magnetic pull
const float MAGNETIC_SMOOTH   = 0.08f;  // interpolation smoothing
const float MAGNETIC_MAX_OFFSET = 17.5f;// max displacement
```

**State Machine**:

```
MouseMove (within sensing radius)
  → Compute direction vector + offset magnitude
  → Progressive interpolation: offset += (target - offset) * MAGNETIC_SMOOTH
  → Location = baseLocation + offset

MouseMove (outside sensing radius)
  → target = (0, 0)
  → Progressive zero-out

MouseLeave
  → FloatAnimation-animated zero-out
  → Prevent abrupt jumps

View Transition (SetTransitionMode)
  → Immediate forced zero-out
  → Protect layout system from interference
```

**Base Position Protection**:

OnLocationChanged only updates `_baseLocation` when magnetic offset is near zero:

```csharp
float currentMagOffset = (float)Math.Sqrt(
    _magneticOffsetX * _magneticOffsetX + 
    _magneticOffsetY * _magneticOffsetY);
if (currentMagOffset < 0.5f)
{
    _baseLocation = this.Location;
}
```

This prevents `_baseLocation` from being polluted during the magnetic return animation, ensuring the correct baseline across multiple magnetic operations.

### 5.5 Smooth Progress Bar Transitions

**Core Change**: Introduced `_displayProgress` intermediate variable for smooth `_value` → rendering transition.

```csharp
// In UpdateAnimation()
float targetProgress = (_value - _minimum) / range;
_displayProgress += (targetProgress - _displayProgress) * 0.12f;
if (Math.Abs(diff) < 0.001f) _displayProgress = targetProgress; // snap on convergence

// In OnPaint()
float progress = _displayProgress;  // use smoothed value
```

**Particle Sync**: Particle generation now uses `_displayProgress > 0` instead of `progress > 0`; fill width uses `w * _displayProgress` — ensuring particles and fill are perfectly synchronized.

---

## 6. Anti-Debugging & Anti-Analysis Techniques

### Debugger API Detection

| Method | API | Detection Principle |
|--------|-----|---------------------|
| IsDebuggerPresent | kernel32 | Reads PEB.BeingDebugged flag |
| CheckRemoteDebuggerPresent | kernel32 | Same, supports checking other processes |
| NtQueryInformationProcess(DebugPort) | ntdll | Non-zero debug port = being debugged |
| NtQueryInformationProcess(DebugFlags) | ntdll | Bit 0 = 0 in DebugFlags = being debugged |
| NtQueryInformationProcess(HandleTracing) | ntdll | High handle tracing count = suspicious |

### Hardware Breakpoint Detection

Reads CPU debug registers (Dr0-Dr3) via `GetThreadContext`, checking for non-zero values.

**x64 CONTEXT Key Offsets**:

| Offset | Size | Field |
|--------|------|-------|
| 0x30 | 4 | ContextFlags |
| 0x48 | 8 | Dr0 |
| 0x50 | 8 | Dr1 |
| 0x58 | 8 | Dr2 |
| 0x60 | 8 | Dr3 |

### PEB Analysis

The `0x70` flag combination = `FLG_HEAP_ENABLE_TAIL_CHECK | FLG_HEAP_ENABLE_FREE_CHECK | FLG_HEAP_VALIDATE_PARAMETERS` — typically set by debuggers.

### Thread Hiding

`NtSetInformationThread(GetCurrentThread(), ThreadHideFromDebugger, 0, 0)` — prevents the debugger from receiving debug events for this thread.

---

## 7. Build System

```powershell
# Standard build
.\build.ps1

# Skip signing (testing only)
.\build.ps1 -SkipSigning
```

**Build Pipeline**:

```
build.ps1
  ├── 1. Token Generation: SHA256 → PBKDF2 AES Key → AES-256-CBC encrypt → RSA sign
  ├── 2. EXE Compilation: CSharpCodeProvider → embed RSA public key/master password/hash table
  ├── 3. HMAC Key: PBKDF2(MasterPassword, WdHmacSalt, 10000) → 32 bytes
  ├── 4. Launch PS1 child process + environment variable injection
  └── 5. Watchdog pipe server loop
```

---

## 8. Attack Surface Analysis

| Attack Vector | Difficulty | Existing Mitigation |
|---------------|------------|---------------------|
| Replace core scripts | Medium | SHA256 integrity verification |
| Attach debugger | Medium | 5 API detections + hardware breakpoint scan |
| DLL injection | Medium | Module path analysis |
| Tamper with token file | High | RSA-SHA256 signature (requires private key) |
| Replay old token | High | 60-second time window |
| Hook ntdll | High | Hardware breakpoint detection + direct PEB read |
| Modify AuroraGuard in memory | High | Watchdog bidirectional HMAC heartbeat |
| Process replacement | High | Watchdog monitors PS1 liveness via pipe |

---

## 9. Contributing

**Build Environment**:

```powershell
.\build.ps1
```

**Code Standards**:

- C#: .NET Framework 4.x, C# 5.0 syntax (compatible with Add-Type)
- PowerShell: Compatible with Windows PowerShell 5.1
- Embedded C#: Use `@"..."@` here-string, explicitly specify `-ReferencedAssemblies`
- Security code: All Native API calls must have try-catch and finally resource cleanup

**Debugging**:

- Diagnostic log: `%TEMP%\aurora_guard_diag.log`
- Animation DLL: `Core\AURORA-AnimationCoreEngine.dll` (delete to trigger recompile)
- Test security guard standalone: `[AuroraGuard]::GetDetectionReason()`

**Animation Debugging**:

- Delete `Core\AURORA-AnimationCoreEngine.dll` to trigger recompilation
- Set env var `AURORA_PERF_TIER` to switch performance tiers (Eco / Balanced / Performance / Extreme)
- TechButton click cooldown: `ClickCooldown = 500`

---

*AURORA VelociRaptor-GR Dev PRJ. — 2026.06.02*