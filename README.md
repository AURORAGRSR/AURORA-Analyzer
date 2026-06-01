# AURORA Analyzer V1.2.24.5Release — Technical Documentation

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
- [4. v1.2.24.5 Security Upgrade Details](#4-v12245-security-upgrade-details)
  - [4.1 Key Rotation & Cryptographic Hardening](#41-key-rotation--cryptographic-hardening)
  - [4.2 Launch Flow Timing Fix](#42-launch-flow-timing-fix)
  - [4.3 CheckHardwareBreakpoints Memory Layout Fix](#43-checkhardwarebreakpoints-memory-layout-fix)
  - [4.4 WOW64 Compatibility Fix](#44-wow64-compatibility-fix)
  - [4.5 Diagnostic Observability Enhancement](#45-diagnostic-observability-enhancement)
- [5. Anti-Debugging & Anti-Analysis Techniques](#5-anti-debugging--anti-analysis-techniques)
  - [5.1 Debugger API Detection](#51-debugger-api-detection)
  - [5.2 Hardware Breakpoint Detection](#52-hardware-breakpoint-detection)
  - [5.3 PEB Analysis](#53-peb-analysis)
  - [5.4 Thread Hiding](#54-thread-hiding)
- [6. Build System](#6-build-system)
  - [6.1 build.ps1 Build Pipeline](#61-buildps1-build-pipeline)
  - [6.2 Pipe Communication Protocol](#62-pipe-communication-protocol)
- [7. Attack Surface Analysis](#7-attack-surface-analysis)
  - [7.1 Known Attack Vectors](#71-known-attack-vectors)
  - [7.2 Mitigation Measures](#72-mitigation-measures)
- [8. Contributing](#8-contributing)

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
│  - AuroraExitCountdown (embedded C# type) │
│  - Watchdog client + Runspace             │
│  - Performance tiering engine             │
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

| Layer        | Language                 | Runtime                                     |
| ------------ | ------------------------ | ------------------------------------------- |
| EXE Loader   | C#                       | .NET Framework 4.x (compiled to target EXE) |
| GUI Launcher | PowerShell + Embedded C# | Windows PowerShell 5.1+                     |
| Core Engines | PowerShell               | Windows PowerShell 5.1+                     |

***

## 2. Security Architecture

### 2.1 Defense-in-Depth Model

```
Layer 0: Build-Time Protection
  ├── RSA key pair (private key held by build tool for token signing)
  ├── SHA256 integrity hash table (hardcoded in AuroraGuard)
  └── Token time-to-live (60-second window)

Layer 1: Launch Verification
  ├── RSA token signature verification (SHA256 + PKCS#1 v1.5)
  ├── Hash manifest decryption (AES-256-CBC + PBKDF2 session key)
  └── Launch environment sanity check (non-debugging context)

Layer 2: IPC Security
  ├── Named Pipe mutual authentication
  ├── HMAC-SHA256 challenge-response protocol
  └── Bidirectional heartbeat (single failure = termination)

Layer 3: Runtime Sentinel
  ├── Debugger API detection (IsDebuggerPresent + NtQueryInformationProcess)
  ├── Hardware breakpoint detection (Dr0-Dr3 register scan)
  ├── PEB analysis (NtGlobalFlag)
  ├── Process name scan (90+ known debugger names)
  ├── DLL injection detection (module path analysis)
  └── Continuous polling (every 3 seconds + WMI real-time events)

Layer 4: Exit Cleanup
  ├── Dual event registration (PowerShell.Exiting + ProcessExit)
  ├── Cascading resource release (Pipe → Runspace → Timer → WMI)
  └── Environment variable zeroization
```

### 2.2 Key Hierarchy

```
Master Secret (RSA private key, held only by build tool)
    │
    ├──sign──→ RSA Token (SHA256 signature, 60s TTL)
    │          │
    │          └──derive──→ AES Session Key (PBKDF2, Nonce, AU_SESSION_2026_SALT_V1)
    │                          │
    │                          └──decrypt──→ Hash Manifest (SHA256 list)
    │
    └──sign──→ EXE-embedded verification logic (RSA public key hardcoded in PS1)
```

### 2.3 Authentication & Verification Chain

```
Build Time:
  1. Generate Random Nonce (32 hex chars)
  2. Compute SHA256 hashes for all core scripts
  3. PBKDF2(Nonce, AesSalt) → AES Session Key
  4. AES-256-CBC encrypt hash list → HashPayload
  5. RSA-SHA256 sign(Nonce:Timestamp:HashPayload) → Signature
  6. Write token file: Nonce:Timestamp:HashPayload:Signature

PS1 Startup:
  1. Read $env:AURORA_TOKEN_PATH → token file
  2. Parse Nonce:Timestamp:HashPayload:Signature
  3. RSA public key verify signature (SHA256, PKCS#1 v1.5)
  4. Check timestamp (|now - timestamp| < 60s)
  5. PBKDF2(Nonce, AesSalt) → AES Session Key
  6. AES-256-CBC decrypt HashPayload → hash manifest
  7. AuroraGuard.Initialize(baseDir) → store base directory
  8. AuroraGuard.CheckIntegrity() → per-file SHA256 verification

EXE-PS1 Watchdog Handshake:
  1. EXE creates NamedPipeServerStream (random name)
  2. Environment variable injection → PS1 connects via NamedPipeClientStream
  3. EXE sends HMAC key (49-byte handshake: 0x10 + key)
  4. PS1 stores HMAC key, enters watchdog response loop
  5. Periodic challenge: EXE sends 0x03 + 16B Nonce + 8B Timestamp
  6. PS1 responds: HMAC-SHA256(Nonce) + 8B Uptime + 32B SelfHash
  7. EXE verifies HMAC → mismatch triggers Kill(ps1Proc)
```

***

## 3. Core Subsystems

### 3.1 RSA Token Verification

**Implementation**: [AURORA-AnalyzerLauncherGUI.ps1:17-77](file:///e%3A/PC%20SOFT/%E4%BC%98%E5%8C%96%E8%BD%AF%E4%BB%B6/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/Scripts/AURORA-AnalyzerLauncherGUI.ps1#L17-L77)

**Key Parameters**:

| Parameter              | Value                       | Purpose              | <br /> | <br />            |
| ---------------------- | --------------------------- | -------------------- | :----- | :---------------- |
| Signature Algorithm    | RSA-SHA256 + PKCS#1 v1.5    | Token signing        | <br /> | <br />            |
| Public Key Format      | XML (Modulus + Exponent)    | Embedded in PS1      | <br /> | <br />            |
| Session Key Derivation | PBKDF2 (Rfc2898DeriveBytes) | 1000 iterations      | <br /> | <br />            |
| AES Mode               | AES-256-CBC, PKCS7 Padding  | Hash list encryption | <br /> | <br />            |
| Token TTL              | 60 seconds (                | age                  | < 60)  | Replay prevention |

**Signature Input Format**: `{Nonce}:{Timestamp}:{HashPayload}`

### 3.2 EXE Watchdog Duplex Communication

**Implementation**: [build.ps1:928-1020](file:///e%3A/PC%20SOFT/%E4%BC%98%E5%8C%96%E8%BD%AF%E4%BB%B6/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/build.ps1#L928-L1020) / [AURORA-AnalyzerLauncherGUI.ps1:342-470](file:///e%3A/PC%20SOFT/%E4%BC%98%E5%8C%96%E8%BD%AF%E4%BB%B6/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/Scripts/AURORA-AnalyzerLauncherGUI.ps1#L342-L470)

**Named Pipe Protocol**:

| Command | Direction | Payload                             | Description        |
| ------- | --------- | ----------------------------------- | ------------------ |
| `0x10`  | EXE→PS1   | 32B HMAC Key                        | Handshake init     |
| `0x03`  | EXE→PS1   | 16B Nonce + 8B Timestamp            | Periodic challenge |
| `0x03`  | PS1→EXE   | 32B HMAC + 8B Uptime + 32B SelfHash | Challenge response |

**Pipe Naming**: `AURORA_WD_{8 hex chars}` (UUID-derived)

### 3.3 AuroraGuard Runtime Sentinel

**Implementation**: [AURORA-AnalyzerLauncherGUI.ps1:497-1037](file:///e%3A/PC%20SOFT/%E4%BC%98%E5%8C%96%E8%BD%AF%E4%BB%B6/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/Scripts/AURORA-AnalyzerLauncherGUI.ps1#L497-L1037)

**Detection Hierarchy**:

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
  └── Process.GetProcesses() enumeration → match 90+ known debugger names

CheckDLLInjection()
  └── Process.Modules enumeration → non-system/non-framework DLL path analysis

CheckIntegrity()
  └── SHA256 hash comparison for 16 core files (10-second cache)
```

### 3.4 File Integrity Verification

**Verified Files**: 16 core scripts + 1 data file

**Implementation Details**:

```csharp
// Cache: repeated calls within 10 seconds return cached result
private static readonly TimeSpan _integrityCacheDuration = TimeSpan.FromSeconds(10);
private static readonly object _integrityLock = new object();

// Read retry: up to 3 attempts (handles file locking scenarios)
while (retryCount < maxRetry)
{
    try
    {
        using (var sha = SHA256.Create())
        {
            byte[] hash = sha.ComputeHash(File.ReadAllBytes(path));
            actual = BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
        }
        hashOk = true;
        break;
    }
    catch (IOException) { retryCount++; Thread.Sleep(100 * retryCount); }
}
```

***

## 4. v1.2.24.5 Security Upgrade Details

### 4.1 Key Rotation & Cryptographic Hardening

**Changes**:

| Component   | v1.2.20.5             | v1.2.24.5             | Security Impact                 |
| ----------- | --------------------- | --------------------- | ------------------------------- |
| RSA Modulus | `tF61rYipRTBERmH...`  | `5wMKsJpF5BoHkv...`   | Prevents old key leakage impact |
| SessionSalt | `qHI6yeoytN0LRm7e...` | `BqsDzvd9iEdvRySj...` | Session key space refresh       |

**Rationale**: Security audit identified the need to follow periodic key rotation best practices, ensuring that even if old build artifacts or key material are compromised, they cannot affect the current version.

### 4.2 Launch Flow Timing Fix

**Root Cause**: A variant of the classic **TOCTOU (Time-of-Check-Time-of-Use)** problem — but in the reverse direction: cleanup was performed before the read.

```powershell
# Bug: Clear-AuroraWatchdogEnv executed before environment variable read
# State: $env:AURORA_WD_PIPE exists → Clear zeroes it → Read returns $null

# Fix: Save to script variables (lexical scope) first, then clean environment
$AURORA_WD_PIPE_NAME = $env:AURORA_WD_PIPE      # Save
$AURORA_WD_SESSION = $env:AURORA_WD_SESSION      # Save
Clear-AuroraWatchdogEnv                           # Safe cleanup
```

**Timing Diagram**:

```
Before (intermittent failure):
EXE ──Start PS1──→ PS1 ──Clear Env──→ PS1 ──Read Env ($null)──→ Skip Watchdog
EXE ──Wait Pipe──→ Timeout ──→ Kill(PS1) ──→ Startup failure

After (stable):
EXE ──Start PS1──→ PS1 ──Read Env (save)──→ PS1 ──Clear Env──→ Connect Pipe
EXE ──Wait Pipe──→ Connected ──→ Handshake ──→ Startup success
```

### 4.3 CheckHardwareBreakpoints Memory Layout Fix

This is the **critical fix** of this release. The Windows x64 `CONTEXT` structure layout in memory differs from intuitive expectations, and the original code used incorrect offsets.

**Windows x64 CONTEXT Structure Layout** (simplified, key fields):

```
Offset  Size  Field
------  ----  -----
0x0000   4    P1Home
0x0004   4    P2Home
0x0008   4    P3Home
0x000C   4    P4Home
0x0010   4    P5Home
0x0014   4    P6Home
0x0018   4    Padding/alignment
0x001C   4    Padding/alignment
0x0020   4    Padding/alignment
0x0024   4    Padding/alignment
0x0028   4    Padding/alignment
0x002C   4    Padding/alignment
0x0030   4    ContextFlags  ← Correct ContextFlags position!
0x0034   4    MxCsr
0x0038   2    SegCs
0x003A   2    SegDs
0x003C   2    SegEs
0x003E   2    SegFs
0x0040   2    SegGs
0x0042   2    SegSs
0x0044   4    EFlags
0x0048   8    Dr0          ← Correct Dr0 position!
0x0050   8    Dr1
0x0058   8    Dr2
0x0060   8    Dr3
0x0068   8    Dr6
0x0070   8    Dr7
...
(Total size: 1232 bytes)
```

**Cascading Effect of the Three Errors**:

1. `ContextFlags` written to `ctxBuffer[0]` → overwrites `P1Home` area → `GetThreadContext` receives an uninitialized ContextFlags → undefined behavior
2. `Dr0` read from `ctxBuffer[0x3E0]` (992) → far beyond the debug register position within the 1232-byte CONTEXT → **triggers Access Violation**
3. `ReadInt32` (4 bytes) reading x64 8-byte registers → only captures lower 32 bits → incomplete detection

### 4.4 WOW64 Compatibility Fix

**ProcessHandleTracing Architecture Differences**:

| Architecture       | Return Value Size | Read Method         |
| ------------------ | ----------------- | ------------------- |
| Native x86         | 4 bytes           | `Marshal.ReadInt32` |
| Native x64         | 8 bytes           | `Marshal.ReadInt64` |
| WOW64 (x86 on x64) | 4 bytes           | `Marshal.ReadInt32` |

**Problem**: The original code allocated a buffer of `2 × IntPtr.Size = 8` bytes under WOW64, but the actual return value is only 4 bytes. While this doesn't directly cause a crash, `ReadInt64` reads uninitialized upper 32 bits.

**Fix**: Buffer size changed to `IntPtr.Size` (adaptive 4/8 bytes), read method changed to `Marshal.ReadIntPtr` (platform-adaptive).

### 4.5 Diagnostic Observability Enhancement

**New** **`DiagLog`** **Function**:

```csharp
private static void DiagLog(string msg)
{
    // Dual-channel output:
    // 1. stderr — unbuffered, real-time visible (even during imminent crash)
    // 2. File — persisted to %TEMP%\aurora_guard_diag.log
    Console.Error.WriteLine(msg);
    Console.Error.Flush();
    string logPath = Path.Combine(Path.GetTempPath(), "aurora_guard_diag.log");
    File.AppendAllText(logPath, DateTime.Now.ToString("HH:mm:ss.fff") + " " + msg);
}
```

**Design Considerations**:

- Uses `Console.Error` (stderr) over `Console.Out` (stdout) because stderr is unbuffered by default, ensuring the last log line is output even during a crash
- Simultaneous file write prevents log loss when the console closes
- `Flush()` forces immediate write to avoid buffering delay

***

## 5. Anti-Debugging & Anti-Analysis Techniques

### 5.1 Debugger API Detection

| Method                                   | API      | Principle                                                  |
| ---------------------------------------- | -------- | ---------------------------------------------------------- |
| IsDebuggerPresent                        | kernel32 | Reads PEB.BeingDebugged flag                               |
| CheckRemoteDebuggerPresent               | kernel32 | Same as above, supports checking other processes           |
| NtQueryInformationProcess(DebugPort)     | ntdll    | Non-zero debug port = being debugged                       |
| NtQueryInformationProcess(DebugFlags)    | ntdll    | Bit 0 of DebugFlags = 0 means being debugged               |
| NtQueryInformationProcess(HandleTracing) | ntdll    | Abnormally high handle tracing count = suspicious activity |

### 5.2 Hardware Breakpoint Detection

**Principle**: Hardware debuggers set breakpoints via CPU debug registers (Dr0-Dr7). By calling `GetThreadContext` to read the current thread context, we check if Dr0-Dr3 are non-zero.

**Correct x64 Implementation**:

```csharp
int ctxSize = 1232;  // sizeof(CONTEXT) on Windows x64
IntPtr ctxBuffer = Marshal.AllocHGlobal(ctxSize);

// ContextFlags at offset 0x30
Marshal.WriteInt32(ctxBuffer, 0x30, (int)(CONTEXT_DEBUG_REGISTERS | CONTEXT_FULL));

if (GetThreadContext(GetCurrentThread(), ctxBuffer))
{
    // Dr0 at offset 0x48, each Dr register is 8 bytes
    long dr0 = Marshal.ReadInt64(ctxBuffer, 0x48);
    long dr1 = Marshal.ReadInt64(ctxBuffer, 0x50);
    long dr2 = Marshal.ReadInt64(ctxBuffer, 0x58);
    long dr3 = Marshal.ReadInt64(ctxBuffer, 0x60);
    if (dr0 != 0 || dr1 != 0 || dr2 != 0 || dr3 != 0)
        return true;  // Hardware breakpoint detected
}
```

**Correct x86 Implementation**:

```csharp
int ctxSize = 716;  // sizeof(CONTEXT) on Windows x86
IntPtr ctxBuffer = Marshal.AllocHGlobal(ctxSize);

Marshal.WriteInt32(ctxBuffer, 0, (int)(CONTEXT_DEBUG_REGISTERS | CONTEXT_FULL));

if (GetThreadContext(GetCurrentThread(), ctxBuffer))
{
    // Dr0 at offset 4 (immediately after ContextFlags)
    uint dr0 = (uint)Marshal.ReadInt32(ctxBuffer, 4);
    ...
}
```

### 5.3 PEB Analysis

**NtGlobalFlag Detection**:

When a process is launched by a debugger, Windows sets the following flag combination in the PEB `NtGlobalFlag` field:

```
FLG_HEAP_ENABLE_TAIL_CHECK   (0x10)
FLG_HEAP_ENABLE_FREE_CHECK   (0x20)
FLG_HEAP_VALIDATE_PARAMETERS (0x40)
───────────────────────────────────
Combined flags: 0x70
```

If `(NtGlobalFlag & 0x70) == 0x70`, the process was likely launched by a debugger.

**PEB Access**: Via `NtQueryInformationProcess(ProcessBasicInformation)` to obtain `PROCESS_BASIC_INFORMATION`, from which the PEB base address is read, then `PEB + NtGlobalFlag` offset.

| Architecture | PEB offset in PBI | NtGlobalFlag offset |
| ------------ | ----------------- | ------------------- |
| x86          | 4                 | 0x68                |
| x64          | 8                 | 0xBC                |

### 5.4 Thread Hiding

**API**: `NtSetInformationThread(GetCurrentThread(), ThreadHideFromDebugger, 0, 0)`

**Principle**: Setting the `ThreadHideFromDebugger` (0x11) information class prevents the debugger from receiving debug events for this thread. If the debugger attempts to resume execution, the thread exits directly.

**Call Timing**: First step in `VerifyOrDie()`, serving as the initial line of defense.

***

## 6. Build System

### 6.1 build.ps1 Build Pipeline

```
build.ps1
  │
  ├── 1. Generate Random Nonce + Token
  │     ├── Compute SHA256 for all core scripts
  │     ├── PBKDF2(Nonce, AesSalt) → AES Key
  │     ├── AES-256-CBC encrypt hash manifest
  │     └── RSA-SHA256 sign → Token file
  │
  ├── 2. Compile C# EXE Loader
  │     ├── Add-Type + CSharpCodeProvider
  │     ├── Embed: RSA public key / Master Password / hash table
  │     └── Compile to AURORA-Analyzer.exe
  │
  ├── 3. Generate Watchdog HMAC Key
  │     └── PBKDF2(MasterPassword, WdHmacSalt, 10000) → 32 bytes
  │
  ├── 4. Launch PS1 Subprocess
  │     ├── ProcessStartInfo Configuration
  │     │   ├── FileName: "powershell.exe"
  │     │   ├── Arguments: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden"
  │     │   ├── UseShellExecute: false
  │     │   └── CreateNoWindow: true
  │     ├── Environment Variable Injection:
  │     │   ├── AURORA_WD_PIPE (pipe name)
  │     │   ├── AURORA_WD_SESSION (session ID)
  │     │   └── AURORA_LAUNCHED_BY_EXE = 1
  │     └── Process.Start()
  │
  ├── 5. Watchdog Pipe Server Loop
  │     ├── Wait for PS1 connection (3 retries, 8000ms timeout)
  │     ├── Send HMAC key (0x10 command)
  │     ├── Periodic challenge loop (every 10000ms, send 0x03)
  │     └── HMAC verification failure → Kill(PS1)
  │
  └── 6. Process Exit Handling
        └── All Kill() calls protected with try-catch
```

### 6.2 Pipe Communication Protocol

**Handshake Packet Format**:

```
Byte 0:     0x10 (command code)
Byte 1-32:  HMAC key (32 bytes)
Byte 33-48: Guid Session ID (16 bytes)
─────────────────────────────────
Total: 49 bytes
```

**Challenge Packet Format (Send)**:

```
Byte 0:     0x03 (challenge command)
Byte 1-16:  Random Nonce (16 bytes)
Byte 17-24: Timestamp (8 bytes, Unix milliseconds)
─────────────────────────────────
Total: 25 bytes
```

**Response Packet Format**:

```
Byte 0-31:  HMAC-SHA256(Nonce) (32 bytes)
Byte 32-39: System uptime (8 bytes, milliseconds)
Byte 40-71: PS1 self SHA256 (32 bytes)
─────────────────────────────────
Total: 72 bytes
```

***

## 7. Attack Surface Analysis

### 7.1 Known Attack Vectors

| Attack Vector                                  | Difficulty | Existing Mitigations                             |
| ---------------------------------------------- | ---------- | ------------------------------------------------ |
| Replace core scripts                           | Medium     | SHA256 integrity verification                    |
| Attach debugger                                | Medium     | 5 API detections + hardware breakpoint scan      |
| DLL injection                                  | Medium     | Module path analysis                             |
| Tamper with token file                         | High       | RSA-SHA256 signature (requires private key)      |
| Replay old token                               | High       | 60-second TTL                                    |
| Hook ntdll to bypass NtQueryInformationProcess | High       | Hardware breakpoint detection + direct PEB reads |
| Modify AuroraGuard in memory                   | High       | Watchdog bidirectional HMAC heartbeat            |
| Process replacement                            | High       | Watchdog monitors PS1 liveness via pipe          |

### 7.2 Mitigation Measures

1. **Defense in Depth**: Even if one layer is bypassed, subsequent layers still detect
2. **Cryptographic Binding**: RSA token binds the hash manifest to the build-time Nonce
3. **Time Windowing**: 60-second TTL prevents token replay
4. **Bidirectional Verification**: Watchdog verifies PS1; PS1 proves integrity via HMAC response
5. **Exception Tolerance**: All detection functions return safe defaults (false/no threat) on error

***

## 8. Contributing

**Build Environment**:

```powershell
# Build command
.\build.ps1

# Skip signing (testing only)
.\build.ps1 -SkipSigning
```

**Code Conventions**:

- C# portions: .NET Framework 4.x, C# 5.0 syntax (compatible with PS1 Add-Type)
- PowerShell portions: Windows PowerShell 5.1 (not cross-platform PowerShell Core)
- Embedded C#: Use `@"..."@` here-strings; reference assemblies via `-ReferencedAssemblies`
- Security code: All Native API calls must have try-catch and finally resource release

**Debugging Methods**:

- Console window: Set `CreateNoWindow = false` to view output
- Diagnostic logs: `%TEMP%\aurora_guard_diag.log`
- Isolated security guard test: Call `[AuroraGuard]::GetDetectionReason()` directly in PS1

**Updating Integrity Hashes**:

After modifying core scripts, recompute SHA256 and update the `_expected` dictionary. Use build.ps1 to automate this process.

***

*AURORA VelociRaptor-GR Dev PRJ. — 2026.06.01*
