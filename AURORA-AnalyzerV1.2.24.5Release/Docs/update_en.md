# AURORA Analyzer V1.2.24.5Release — Update Document

> **Build Date**: 2026.06.01
> **Codename**: Security Architecture Overhaul
> **Scope**: `AURORA-AnalyzerLauncherGUI.ps1` / `build.ps1` / All Security Subsystems

---

## I. Overview

This release constitutes a **comprehensive security architecture overhaul**, focused on resolving launch-phase security vulnerabilities and runtime stability issues. Core objectives:

1. Eliminate **intermittent crashes** (Access Violation) caused by memory access errors
2. Fix **watchdog race conditions** causing sporadic startup failures
3. Strengthen **multi-layer defense-in-depth** across the full lifecycle: Build → Launch → Runtime

---

## II. Security Architecture Changes

### 2.1 RSA Key Rotation

| Component | Previous | Current |
|-----------|----------|---------|
| RSA Public Key Modulus | `tF61rYipRTBERmH...` | `5wMKsJpF5BoHkv...` |
| SessionSalt | `qHI6yeoytN0LRm7e...` | `BqsDzvd9iEdvRySj...` |

**Impact**: All RSA token signature verification and AES session key derivation. Previous EXE builds will fail the new token verification. **Rebuild EXE to ensure compatibility.**

### 2.2 File Integrity Hash Table Update

SHA256 hashes for all 16 core scripts have been regenerated to reflect current code state:

- `AURORA-SmartEngine.ps1`
- `AURORA-CoreEngine.ps1`
- `AURORA-AnalyzerCHSPRO.ps1`
- `AURORA-ProgressManager.ps1`
- `AURORA-GUI-Functions.ps1`
- `AURORA-RepairTools.ps1`
- `AURORA-UndoManager.ps1`
- `AURORA-RestoreManager.ps1`
- `AURORA-RepairLogger.ps1`
- `AURORA-UndoViewer.ps1`
- `AURORA-AnalyzerPRO.ps1`
- `AURORA-ProgressManager-Integration.ps1`
- `AURORA-ProgressManager-Integration-CHS.ps1`
- `AURORA-ProgressManager-Integration-ENG.ps1`
- `Core\AURORA-AnimationCoreEngine.ps1`
- `Data\AURORA-TechData.json`

---

## III. Launch Flow Fixes

### 3.1 Watchdog Environment Variable Timing Fix

**Problem**: `Clear-AuroraWatchdogEnv` executed before reading `$env:AURORA_WD_PIPE`, causing the pipe name to always be `$null`. The EXE watchdog would timeout and kill the PS1 process, resulting in intermittent startup failures.

**Fix**:

```powershell
# Before (incorrect order)
Clear-AuroraWatchdogEnv
$AURORA_WD_PIPE_NAME = $env:AURORA_WD_PIPE  # Already $null at this point

# After (correct order)
$AURORA_WD_PIPE_NAME = $env:AURORA_WD_PIPE
$AURORA_WD_SESSION = $env:AURORA_WD_SESSION
Clear-AuroraWatchdogEnv  # Safe cleanup
```

### 3.2 Process Exit Cleanup Handler

Added `Register-AuroraExitHandler` function, registered to both `PowerShell.Exiting` and `ProcessExit` events:

- Auto-close watchdog named pipe connections
- Stop watchdog Runspace and PowerShell instances
- Stop main engine Runspace
- Stop security guard timer (`debuggerTimer`)
- Unregister WMI process creation monitor (`debuggerWmiWatcher`)
- Clean up all Aurora-related environment variables

### 3.3 Startup State Flag Reset

Force-reset all security guard state flags at startup to prevent stale state from bypassing security checks:

```powershell
$script:ExitCountdownStarted = $false
$script:DebuggerCheckCount = 0
$script:IntegrityCheckCount = 0
```

---

## IV. Security Guard (AuroraGuard) Fixes

### 4.1 ProcessHandleTracing — WOW64 Compatibility

**Problem**: Under 32-bit processes (WOW64), the `ProcessHandleTracing` information class returns data sized at `IntPtr.Size` (4 bytes), not `2 * IntPtr.Size` (8 bytes). Allocating an oversized buffer and using `ReadInt64` causes out-of-bounds access.

**Fix**:

```csharp
// Before
IntPtr tracingInfo = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(IntPtr)) * 2);
int result = NtQueryInformationProcess(hProcess, ProcessHandleTracing, tracingInfo,
    Marshal.SizeOf(typeof(IntPtr)) * 2, ref returnLength);
long count = Marshal.ReadInt64(tracingInfo);

// After
IntPtr tracingInfo = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(IntPtr)));
int result = NtQueryInformationProcess(hProcess, ProcessHandleTracing, tracingInfo,
    Marshal.SizeOf(typeof(IntPtr)), ref returnLength);
long count = (long)Marshal.ReadIntPtr(tracingInfo);
```

### 4.2 CheckHardwareBreakpoints — Critical Fix

This was the **root cause** of the launch crash. The `CheckHardwareBreakpoints` function had three critical errors on the x64 path:

| Error | Incorrect Value | Correct Value | Impact |
|--------|----------------|---------------|--------|
| ContextFlags Write Offset | `0` | `0x30` (48) | Overwrote CONTEXT structure header, causing undefined `GetThreadContext` behavior |
| Dr0 Register Offset | `0x3E0` (992) | `0x48` (72) | Read memory beyond the CONTEXT structure, triggering Access Violation |
| Dr Register Read Size | 4 bytes (Int32) | 8 bytes (Int64) | Only read the lower 32 bits of Dr registers on x64 |

**x86 Path Fix**: Removed `CONTEXT_X86` struct + `Marshal.StructureToPtr` approach, replaced with raw buffer to avoid .NET struct alignment issues.

**x64 Path Fix**:

```csharp
// Before
Marshal.WriteInt32(ctxBuffer, 0, (int)(CONTEXT_DEBUG_REGISTERS | CONTEXT_FULL));
int drOffset = 0x3E0;
uint dr0 = (uint)Marshal.ReadInt32(ctxBuffer, drOffset);

// After
Marshal.WriteInt32(ctxBuffer, 0x30, (int)(CONTEXT_DEBUG_REGISTERS | CONTEXT_FULL));
int drOffset = 0x48;
long dr0 = Marshal.ReadInt64(ctxBuffer, drOffset);
```

**Windows x64 CONTEXT Structure Layout (Key Offsets)**:

| Offset | Size | Field |
|--------|------|-------|
| 0x00 | 4 | P1Home |
| 0x04 | 4 | P2Home |
| 0x08 | 4 | P3Home |
| 0x0C | 4 | P4Home |
| 0x10 | 4 | P5Home |
| 0x14 | 4 | P6Home |
| **0x30** | **4** | **ContextFlags** |
| 0x34 | 4 | MxCsr |
| 0x38 | 2 | SegCs |
| 0x3A | 2 | SegDs |
| ... | ... | ... |
| **0x48** | **8** | **Dr0** |
| **0x50** | **8** | **Dr1** |
| **0x58** | **8** | **Dr2** |
| **0x60** | **8** | **Dr3** |

### 4.3 GetDetectionReason — Diagnostic Logging Enhancement

Added `DiagLog` helper function with dual-output logging:

```csharp
private static void DiagLog(string msg)
{
    Console.Error.WriteLine(msg);            // Real-time console output (stderr, unbuffered)
    Console.Error.Flush();
    string logPath = Path.Combine(Path.GetTempPath(), "aurora_guard_diag.log");
    File.AppendAllText(logPath, DateTime.Now.ToString("HH:mm:ss.fff") + " " + msg);
}
```

Each detection step in `GetDetectionReason()` now includes full trace logging:
- Detection start/success/failure
- Exception type and message
- Final detection result

Log file path: `%TEMP%\aurora_guard_diag.log`

---

## V. EXE Build Fixes

### 5.1 Environment Variable Propagation

Added `AURORA_LAUNCHED_BY_EXE = "1"` environment variable to ensure PS1 correctly identifies EXE-launched mode:

```csharp
psi.EnvironmentVariables["AURORA_LAUNCHED_BY_EXE"] = "1";
```

### 5.2 Process Termination Protection

All `ps1Proc.Kill()` calls wrapped in `try-catch` to prevent exceptions when the process has already exited:

```csharp
// Before
ps1Proc.Kill();

// After
try { ps1Proc.Kill(); } catch { }
```

### 5.3 Console Window Setting

```csharp
CreateNoWindow = true  // Was false previously
```

### 5.4 WaitForInputIdle Removal

Removed `ps1Proc.WaitForInputIdle(30000)` call, which caused pipe server creation delay, resulting in all PS1 retries completing before the server was ready.

---

## VI. AddScript Output Suppression

Watchdog Runspace `AddScript` call now prefixed with `$null =` to prevent PowerShell object dumps in console output:

```powershell
# Before
$AURORA_WD_PS.AddScript({ ... })

# After
$null = $AURORA_WD_PS.AddScript({ ... })
```

---

## VII. Build & Deployment

**Rebuild EXE**:

```powershell
.\build.ps1
```

**⚠️ Important**: Due to RSA key rotation, previous EXE builds must be rebuilt. All script SHA256 hashes have been updated; integrity verification will use the new hash table.

---

## VIII. Compatibility

| Item | Requirement |
|------|-------------|
| OS | Windows 10 1809+ / Windows 11 / Windows Server 2019+ |
| Architecture | x64 (recommended) / x86 (WOW64) |
| .NET Framework | 4.x (C# 5.0) |
| PowerShell | Windows PowerShell 5.1+ |

---

## IX. Known Issues & Limitations

- `CheckHardwareBreakpoints` `GetThreadContext` call may return false negatives under certain security software (e.g., EDR products that deeply hook ntdll). This is by design — detection functions return `false` on error rather than causing a crash.
- The diagnostic log file `aurora_guard_diag.log` appends continuously; periodic cleanup is recommended.

---

*End of Document — AURORA VelociRaptor-GR Dev PRJ.*