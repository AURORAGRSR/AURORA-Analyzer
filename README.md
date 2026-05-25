# AURORA Analyzer V1.1.24.0 — Developer Technical Specification

**Version:** V1.1.24.0\
**Build Date:** 2026.05.25\
**Author:** AURORA VelociRaptor-GR Dev PRJ.\
**License:** For personal learning and research use only\
**Type:** Windows System Event Log Export & Intelligent Diagnostics Tool

***

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [v1.1.24.0 Core Update: Defense-in-Depth Security](#2-v11240-core-update-defense-in-depth-security)
3. [System Architecture](#3-system-architecture)
4. [Module-Level Technical Reference](#4-module-level-technical-reference)
5. [Security System — Complete Specification](#5-security-system--complete-specification)
6. [Build System (build.ps1) — Complete Reference](#6-build-system-buildps1--complete-reference)
7. [Encryption & Cryptographic Primitives](#7-encryption--cryptographic-primitives)
8. [GUI Architecture & Runspace Model](#8-gui-architecture--runspace-model)
9. [PRO Mode Export Engine](#9-pro-mode-export-engine)
10. [Smart Diagnostics Engine (SmartEngine)](#10-smart-diagnostics-engine-smartengine)
11. [Undo / Repair System (Phase 4.2)](#11-undo--repair-system-phase-42)
12. [Progress Manager & Session Persistence](#12-progress-manager--session-persistence)
13. [Animation Core Engine (Phase 5)](#13-animation-core-engine-phase-5)
14. [Bilingual Infrastructure](#14-bilingual-infrastructure)
15. [Performance Tiering System](#15-performance-tiering-system)
16. [Threat Model & Attack Surface Analysis](#16-threat-model--attack-surface-analysis)
17. [Version History](#17-version-history)

***

## 1. Project Overview

AURORA Analyzer is a professional Windows system event log export and intelligent diagnostics tool written in PowerShell (5.1+) and C# (.NET Framework 4.x). It integrates advanced log analysis, knowledge-base-driven diagnostics, autonomous repair suggestions, system restore/undo capabilities, and a real-time integrity monitoring system.

### 1.1 Key Statistics

| Metric                         | Value                                                                                                   |
| ------------------------------ | ------------------------------------------------------------------------------------------------------- |
| Total Core Files               | 19 (SHA256-signed)                                                                                      |
| Total Source Lines (estimated) | \~40,000+ lines                                                                                         |
| Supported Log Types            | 8 (System, Application, Security, Setup, DNS Server, DHCP Server, Directory Service, IIS Admin Service) |
| Diagnostic Rule Categories     | 5 (System Stability, Application Errors, Driver Issues, Hardware Faults, Security Audits)               |
| Diagnostic Rules               | 100+                                                                                                    |
| Output Formats                 | CSV, JSON, XML, Summary Report (TXT), Trend Analysis (TXT + CSV)                                        |
| Supported Languages            | 2 (Chinese / English) — 144 translation entries                                                         |
| Performance Tiers              | 4 (Eco, Balanced, Performance, Extreme)                                                                 |
| Repair Operation Types         | 5 (DisableWindowsUpdate, EnableDefender, DisableTelemetry, ResetNetwork, CleanSystem)                   |
| Security Layers                | 4 (Build-Time, Launch-Time, Runtime, Multi-Module Launch Detection)                                     |

### 1.2 System Requirements

| Requirement    | Minimum                | Recommended      |
| -------------- | ---------------------- | ---------------- |
| OS             | Windows 10/11 (64-bit) | Windows 11 22H2+ |
| PowerShell     | 5.1                    | 5.1+             |
| .NET Framework | 4.0+                   | 4.8              |
| RAM            | 4 GB                   | 8 GB+            |
| CPU            | 2-core                 | 4-core+          |
| Disk           | 50 MB available        | SSD storage      |

***

## 2. v1.1.24.0 Core Update: Defense-in-Depth Security

The v1.1.24.0 release represents a **complete security system rebuild**, upgrading from a single-password verification model to a **Defense-in-Depth Four-Layer Security Model**. This is the most significant architectural change in AURORA Analyzer's history.

### 2.1 What Changed

| Aspect                         | v1.1.23.0 (Previous)         | v1.1.24.0 (Current)                        |
| ------------------------------ | ---------------------------- | ------------------------------------------ |
| Authentication                 | Single password verification | RSA-2048 asymmetric handshake              |
| Hash list transport            | Plain text in memory         | AES-256-CBC session encryption             |
| Integrity check interval       | 10 seconds                   | 3 seconds (fixed) + 2-7 seconds (random)   |
| File checking                  | Break on first mismatch      | Full-file checking (no break)              |
| Monitoring method              | Single timer                 | Dual timer + FileSystemWatcher             |
| Reverse engineering protection | None                         | Anti-debugger + anti-dump + C# obfuscation |
| Replay protection              | None                         | Token 60-second expiry + Nonce             |
| Unauthorized file injection    | Not detected                 | Real-time Created event monitoring         |
| Post-launch check              | None                         | 1-second immediate integrity check         |

### 2.2 Ten Critical Security Items

1. **RSA-2048 asymmetric key pair** — Per-build key generation for EXE↔PS1 secure handshake protocol
2. **AES-256-CBC session encryption layer** — Hash list transport protection between EXE and PS1
3. **Dual timer + FileSystemWatcher** — Real-time runtime integrity monitoring (3s fixed + 2-7s random + filesystem events)
4. **C# offline metadata obfuscation** — Class and method name randomization during build
5. **Anti-debugging/anti-dump detection** — Detects x64dbg, OllyDbg, Scylla, Phantom
6. **Token time-based validation** — 60-second expiry window with 5-second clock skew tolerance
7. **Check interval optimization** — Reduced from 10s to 3s (P0 fix, 70% attack window reduction)
8. **Full-file checking** — Removed `break` statements for complete file hash verification (P0 fix)
9. **1-second post-launch check** — Immediate integrity verification after PS1 startup
10. **Unauthorized file injection detection** — FileSystemWatcher Created event with whitelist validation

***

## 3. System Architecture

### 3.1 Directory Structure

```
AURORA-Analyzer-Factory/
├── AURORA.Launcher-双击启动.exe    # C# Windows Forms entry point
├── GAURORA.CHK.ENC                 # AES-256-CBC encrypted hash list
├── version.txt                     # Semantic version string
├── build.ps1                       # Complete build orchestration script
├── build.log                       # Build session log
├── desktop.ini                     # Windows folder customization
│
├── Data/
│   └── AURORA-TechData.json        # Diagnostic rule knowledge base (JSON)
│
├── Resources/
│   ├── AURORAICON.ico              # Application icon
│   └── CascadiaMono.ttf            # UI monospace font
│
├── Scripts/
│   ├── AURORA-AnalyzerLauncherGUI.ps1      # Main GUI (RSA public key + runtime monitoring)
│   ├── AURORA-AnalyzerPRO.ps1              # PRO mode unified entry
│   ├── AURORA-AnalyzerCHSPRO.ps1           # Chinese PRO export engine (~7,767 lines)
│   ├── AURORA-AnalyzerENGPRO.ps1           # English PRO export engine (~7,500 lines)
│   ├── AURORA-SmartEngine.ps1              # Smart diagnostics engine v1.1.32
│   ├── AURORA-CoreEngine.ps1               # Shared core engine
│   ├── AURORA-GUI-Functions.ps1            # GUI helper functions
│   ├── AURORA-Language.psd1                # Bilingual resource file (144 entries)
│   ├── AURORA-ProgressManager.ps1          # Session persistence & checkpoint resume
│   ├── AURORA-ProgressManager-Integration.ps1
│   ├── AURORA-ProgressManager-Integration-CHS.ps1
│   ├── AURORA-ProgressManager-Integration-ENG.ps1
│   ├── AURORA-RestoreManager.ps1           # Windows System Restore API wrapper
│   ├── AURORA-RepairLogger.ps1             # Repair operation audit trail
│   ├── AURORA-UndoManager.ps1              # Fast backup & restore (registry/files/services)
│   ├── AURORA-RepairTools.ps1              # Repair toolset entry point
│   ├── AURORA-UndoViewer.ps1               # Repair history viewer & undo tool
│   ├── Core/
│   │   └── AURORA-AnimationCoreEngine.ps1  # Animation core engine (C# + PowerShell)
│   └── SessionCache/
│       ├── active/                         # Current active sessions
│       ├── checkpoints/                    # Checkpoint backups
│       └── archive/                        # Completed session archives
│
├── UserLogs/                               # Exported log output directory
│   └── *.csv, *.json, *.xml, *.txt
│
├── Docs/                                   # Documentation
├── test/                                   # Test scripts (14 test files)
└── Releases/                               # Build ZIP output
```

### 3.2 Component Dependency Graph

```
┌──────────────────────────────────────┐
│   AURORA.Launcher-双击启动.exe       │
│   (C# WinForms, RSA Private Key)     │
└──────────────┬───────────────────────┘
               │ RSA Token + Launch
               ▼
┌──────────────────────────────────────┐
│   AURORA-AnalyzerLauncherGUI.ps1     │
│   (RSA Public Key, Runtime Monitor)  │
└───┬──────┬──────┬──────┬──────┬─────┘
    │      │      │      │      │
    ▼      ▼      ▼      ▼      ▼
┌──────┐┌──────┐┌──────┐┌──────┐┌────────────┐
│PRO   ││Smart ││Repair││Undo  ││Animation   │
│Engine││Engine││Tools ││Viewer││Core Engine │
└──┬───┘└──┬───┘└──┬───┘└──┬───┘└────────────┘
   │       │       │       │
   ▼       ▼       ▼       ▼
┌──────────────────────────────────────┐
│   Shared Dependencies:               │
│   CoreEngine, Language.psd1,         │
│   ProgressManager, GUI-Functions     │
└──────────────────────────────────────┘
```

### 3.3 File Size Reference

| File                           | Approximate Size | Role                      |
| ------------------------------ | ---------------- | ------------------------- |
| AURORA.Launcher-双击启动.exe       | \~50-100 KB      | C# compiled entry point   |
| AURORA-AnalyzerLauncherGUI.ps1 | \~10,000+ lines  | Main GUI + security       |
| AURORA-AnalyzerCHSPRO.ps1      | \~7,767 lines    | Chinese PRO export engine |
| AURORA-AnalyzerENGPRO.ps1      | \~7,500 lines    | English PRO export engine |
| AURORA-SmartEngine.ps1         | \~1,500+ lines   | Smart diagnostics engine  |
| AURORA-CoreEngine.ps1          | \~486 lines      | Shared core engine        |
| AURORA-GUI-Functions.ps1       | \~220 lines      | GUI helper functions      |
| AURORA-AnimationCoreEngine.ps1 | \~800+ lines     | Animation core engine     |
| AURORA-Language.psd1           | \~250 lines      | Bilingual resources       |
| AURORA-ProgressManager.ps1     | \~400+ lines     | Session persistence       |
| build.ps1                      | \~1,185 lines    | Build orchestration       |

***

## 4. Module-Level Technical Reference

### 4.1 AURORA.Launcher-双击启动.exe (C# Entry Point)

**Technology Stack:**

- C# 5.0 (compiled via .NET Framework csc.exe)
- Target: x86 platform, Windows Forms (windowless/background)
- Classes: `AuroraLauncher` (obfuscated to `a_<random8chars>` in v1.1.24.0)

**Key Responsibilities:**

1. Anti-debugger detection (`IsDebuggerPresent()`)
2. Anti-dump module scanning (x64dbg.dll, x32dbg.dll, ollydbg.dll, scylla.dll, phantom.dll)
3. Core file existence verification (19 files in `RequiredFiles[]`)
4. `GAURORA.CHK.ENC` decryption and SHA256 hash verification
5. RSA-2048 token generation and signing
6. AES-256-CBC session encryption for hash list transport
7. PowerShell process launch with environment variables
8. Post-launch memory cleanup and environment variable removal

**Embedded Secrets (build-time injected):**

- `RsaPrivateKeyXml` — RSA-2048 private key (XML format)
- `PwXorMask` — 16-byte XOR obfuscation mask
- `PwEncrypted` — XOR+Shuffle obfuscated password bytes
- `PwOrder` — Password byte position permutation array
- `DerivationSalt` — 32-byte session derivation salt

**Compilation Command:**

```
csc.exe /out:AURORA.Launcher-双击启动.exe /target:winexe /platform:x86
        /reference:System.Windows.Forms.dll
        /win32icon:Resources\AURORAICON.ico
        AuroraLauncher.cs
```

**Anti-Debugging Implementation:**

```csharp
[DllImport("kernel32.dll")]
static extern bool IsDebuggerPresent();

[DllImport("kernel32.dll")]
static extern IntPtr GetModuleHandle(string lpModuleName);

static bool CheckAntiDump()
{
    string[] suspiciousModules = { "x64dbg.dll", "x32dbg.dll",
        "ollydbg.dll", "scylla.dll", "phantom.dll" };
    foreach (string module in suspiciousModules)
    {
        if (GetModuleHandle(module) != IntPtr.Zero)
            return false;
    }
    return true;
}

[STAThread]
static void Main()
{
    if (IsDebuggerPresent()) return;  // Silent exit
    if (!CheckAntiDump()) return;     // Silent exit
    // ... continue launch sequence
}
```

### 4.2 AURORA-AnalyzerLauncherGUI.ps1 (Main GUI)

**Technology Stack:**

- PowerShell 5.1+
- Windows Forms (System.Windows.Forms)
- Multi-threaded via PowerShell Runspaces
- `syncHash` synchronized hashtable for cross-thread communication
- `EventWaitHandle` for event-driven authorization (zero CPU polling)

**Key Parameters:**

```powershell
Param(
    [switch]$LaunchedByExe
)
```

**RSA Public Key Injection (build-time):**

```powershell
$global:AURORA_PublicKeyXml = @'
<RSAKeyValue><Modulus>[2048-bit modulus Base64]</Modulus>
<Exponent>AQAB</Exponent></RSAKeyValue>
'@
```

**Runtime Integrity Monitoring (Lines 422-741):**

- `$global:IntegrityCheckInterval = 3000` (milliseconds, 3s)
- `$script:runtimeIntegrityTimer` — Fixed 3-second timer
- `$script:randomIntegrityTimer` — Random 2-7 second timer
- `$script:fileWatcher` — FileSystemWatcher on root directory
  - Filter: `*.ps1,*.json,*.xml,*.ico,*.exe,*.enc`
  - NotifyFilter: FileName | Size | LastWrite
  - IncludeSubdirectories: true
- Four integrity checks: file count, existence, SHA256 hash, unauthorized file creation

**Tamper Response Protocol:**

1. Stop all monitoring timers and FileSystemWatcher
2. Close splash screen and main window
3. Display 15-second countdown warning dialog
4. List all missing and tampered files
5. Program exits after countdown

**Performance Profiler (Lines 91-145):**

```powershell
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$ramGB = [Math]::Round($cs.TotalPhysicalMemory / 1GB)
$logicalCores = $cpu.NumberOfLogicalProcessors
$baseClock = $cpu.MaxClockSpeed

$perfScore = ($logicalCores * 15) + ($ramGB * 5) +
    ([Math]::Max(0, ($baseClock - 2000) / 100))

if ($perfScore -ge 240)       { $global:AuroraPerfTier = "Extreme" }
elseif ($perfScore -ge 120)   { $global:AuroraPerfTier = "Performance" }
elseif ($perfScore -ge 70)    { $global:AuroraPerfTier = "Balanced" }
else                           { $global:AuroraPerfTier = "Eco" }
```

### 4.3 AURORA-CoreEngine.ps1 (Shared Core Engine)

**Functions:**

| Function                    | Purpose                                       |
| --------------------------- | --------------------------------------------- |
| `Test-AdminRequired`        | Check if a log type requires admin privileges |
| `Invoke-ElevationCheck`     | Request admin elevation via syncHash/GUI      |
| `Write-AuroraLog`           | Unified logging (GUI syncHash or console)     |
| `Read-AuroraInput`          | Get user input via syncHash or Read-Host      |
| `New-StreamWriterOperation` | Safe StreamWriter with directory creation     |
| `Get-SafeFilePath`          | Path traversal prevention validator           |
| `Save-ProgressSafe`         | Progress persistence to filesystem            |
| `Get-ProgressInfo`          | Load previously saved progress                |
| `Manage-Session`            | Session recovery/restart logic                |
| `Get-SystemInfo`            | System environment probe                      |
| `Initialize-Engine`         | Core engine bootstrap                         |

**Global Variable Guard:**

```powershell
if ($global:AURORA_CoreEngine_Loaded -eq $true) { return }
$global:AURORA_CoreEngine_Loaded = $true
```

**Admin-Required Log Types:**

```powershell
$script:AdminRequiredLogTypes = @(
    "Security", "Setup", "DNS Server", "DHCP Server",
    "Directory Service", "IIS Admin Service"
)
```

### 4.4 AURORA-AnalyzerPRO.ps1 (PRO Mode Unified Entry)

**Role:** Language-aware routing dispatcher. Detects user UI culture and delegates to either CHSPRO or ENGPRO.

**Version:** \~200 lines

**Flow:**

1. Receive parameters (LogType, StartTime, EndTime, etc.)
2. Detect `[System.Threading.Thread]::CurrentThread.CurrentUICulture.Name`
3. If culture starts with "zh" → route to `AURORA-AnalyzerCHSPRO.ps1`
4. Otherwise → route to `AURORA-AnalyzerENGPRO.ps1`
5. Forward all parameters to the target engine

### 4.5 AURORA-AnalyzerCHSPRO.ps1 / AURORA-AnalyzerENGPRO.ps1

**Role:** Full-featured professional log export engines with identical logic but separate language resources.

**Supported Log Types (8):**

1. System
2. Application
3. Security (admin required)
4. Setup (admin required)
5. DNS Server (admin required)
6. DHCP Server (admin required)
7. Directory Service (admin required)
8. IIS Admin Service (admin required)

**Export Modes:**

- Single Day — Quick export for a specific date
- Date Range — Batch export across multiple dates (e.g., 6 months)
- ForceRescan — Ignore cached results

**Advanced Filtering:**

- EventID filter
- ProviderName filter
- Level filter (Critical / Error / Warning / Information / Verbose)

**Output Formats (per log type):**

1. `{LogType}_日志_{YYYYMMDD}___{YYYYMMDD}.csv`
2. `{LogType}_日志_{YYYYMMDD}___{YYYYMMDD}.json`
3. `{LogType}_日志_{YYYYMMDD}___{YYYYMMDD}.xml`
4. `{LogType}_日志_{YYYYMMDD}___{YYYYMMDD}_摘要.txt` (Summary Report)
5. `{LogType}_日志_{YYYYMMDD}_至_{YYYYMMDD}_趋势分析.txt` (Trend Analysis)
6. `{LogType}_日志_{YYYYMMDD}_至_{YYYYMMDD}_趋势数据.csv` (Trend Data)

***

## 5. Security System — Complete Specification

### 5.1 Four-Layer Defense-in-Depth Architecture

```
┌──────────────────────────────────────────────────────────┐
│              Layer 1: Build-Time Security                 │
│  Key Generation → Password Obfuscation → File Hashing     │
│  → PBKDF2 Derivation → AES-256 Encryption → C# Injection  │
│  → Symbol Obfuscation → Recompilation                    │
├──────────────────────────────────────────────────────────┤
│              Layer 2: Launch-Time Security                │
│  Anti-Debug → File Existence → Decrypt CHK → SHA256      │
│  → RSA Token → AES Session → PS1 Launch                  │
├──────────────────────────────────────────────────────────┤
│              Layer 3: Runtime Security                    │
│  Dual Timers (3s + 2-7s) → FileSystemWatcher →           │
│  Count Check → Existence Check → SHA256 → Injection Det   │
│  → Tamper Response (15s countdown → Exit)                │
├──────────────────────────────────────────────────────────┤
│           Layer 4: Multi-Module Launch Detection          │
│  GUI_Mode → syncHash → RSA Token → 5s countdown exit     │
└──────────────────────────────────────────────────────────┘
```

### 5.2 Layer 1: Build-Time Security (build.ps1 Steps \[0.5]-\[5])

#### 5.2.1 RSA-2048 Key Pair Generation

```powershell
$rsaProvider = New-Object System.Security.Cryptography.RSACryptoServiceProvider(2048)
$RsaPrivateKeyRaw = $rsaProvider.ToXmlString($true)   # Embed in EXE
$RsaPublicKeyRaw  = $rsaProvider.ToXmlString($false)   # Inject into PS1
```

#### 5.2.2 Password XOR+Shuffle Obfuscation

```powershell
$passwordBytes = [Text.Encoding]::UTF8.GetBytes($MasterPassword)
$xorMask = New-Object byte[] 16  # Random 16-byte mask
$pwShuffled = New-Object byte[] $pwLen
$pwOrder = 0..($pwLen - 1) | Sort-Object { Get-Random }

for ($i = 0; $i -lt $pwLen; $i++) {
    $pwShuffled[$i] = $passwordBytes[$pwOrder[$i]] -bxor $xorMask[$i % 16]
}
```

**C# Deobfuscation (runtime):**

```csharp
static string GetMasterPassword()
{
    byte[] decrypted = new byte[PwEncrypted.Length];
    for (int i = 0; i < PwEncrypted.Length; i++)
        decrypted[PwOrder[i]] = (byte)(PwEncrypted[i] ^ PwXorMask[i % PwXorMask.Length]);
    return Encoding.UTF8.GetString(decrypted);
}
```

#### 5.2.3 SHA256 Hash Signing (19 Core Files)

```
Format: {sha256_lowercase_hex} {relative_path}\r\n
```

**Protected Files List:**

1. `Scripts\AURORA-AnalyzerLauncherGUI.ps1`
2. `Scripts\AURORA-AnalyzerENGPRO.ps1`
3. `Scripts\AURORA-AnalyzerCHSPRO.ps1`
4. `Scripts\AURORA-SmartEngine.ps1`
5. `Data\AURORA-TechData.json`
6. `Scripts\AURORA-ProgressManager.ps1`
7. `Scripts\AURORA-ProgressManager-Integration-CHS.ps1`
8. `Scripts\AURORA-ProgressManager-Integration-ENG.ps1`
9. `Scripts\AURORA-GUI-Functions.ps1`
10. `Scripts\AURORA-CoreEngine.ps1`
11. `Scripts\AURORA-Language.psd1`
12. `Scripts\AURORA-AnalyzerPRO.ps1`
13. `Scripts\AURORA-ProgressManager-Integration.ps1`
14. `Scripts\AURORA-RestoreManager.ps1`
15. `Scripts\AURORA-RepairLogger.ps1`
16. `Scripts\AURORA-UndoManager.ps1`
17. `Scripts\AURORA-RepairTools.ps1`
18. `Scripts\AURORA-UndoViewer.ps1`
19. `Scripts\Core\AURORA-AnimationCoreEngine.ps1`

#### 5.2.4 GAURORA.CHK.ENC Encryption

```
Encryption Pipeline:
  Plain hash list → PBKDF2-SHA256(Password, Salt, 100,000 iterations) → AES-256-CBC key
  → AES-256-CBC encrypt → Base64 encode → Write to GAURORA.CHK.ENC

Binary Format:
  [Salt: 16 bytes] [IV: 16 bytes] [AES-256-CBC Ciphertext: variable length]
  → Full blob Base64-encoded for storage
```

```powershell
# Key Derivation
$pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
    $MasterPassword, $salt, 100000,
    [System.Security.Cryptography.HashAlgorithmName]::SHA256
)
$keyBytes = $pbkdf2.GetBytes(32)

# Encryption
$aes = [Security.Cryptography.Aes]::Create()
$aes.Key = $keyBytes
$aes.GenerateIV()  # Random 16-byte IV
$enc = $aes.CreateEncryptor().TransformFinalBlock(...)

# Assembly
$final = Salt + IV + Ciphertext
[Convert]::ToBase64String($final) → GAURORA.CHK.ENC
```

#### 5.2.5 C# Offline Metadata Obfuscation

**Process:**

1. Compile original C# source → temporary EXE
2. Load assembly via `[System.Reflection.Assembly]::Load()`
3. Generate random class name: `a_` + 8 random lowercase ASCII chars
4. Generate random method names: `c_` + 6 chars (CRC), `d_` + 6 chars (anti-dump)
5. Replace in source: `class AuroraLauncher` → `class a_xxxxxxxx`
6. Replace method calls and declarations
7. **Main() is NOT renamed** (C# entry point requirement)
8. Recompile with obfuscated source → final EXE
9. Original EXE discarded, temporary files cleaned

```powershell
$randomChars = -join (1..8 | ForEach-Object {
    [char](Get-Random -Minimum 97 -Maximum 123)
})
$obfClassName = "a_$randomChars"
$CsCodeObf = $CsCode.Replace("class AuroraLauncher", "class $obfClassName")
$CsCodeObf = $CsCodeObf.Replace("CalculateCrc32(", "$obfCrc(")
$CsCodeObf = $CsCodeObf.Replace("CheckAntiDump()", "$obfCheck()")
```

**Note:** When obfuscation is applied, CRC32 self-check is disabled. When obfuscation fails, fallback to CRC32 self-check.

### 5.3 Layer 2: Launch-Time Security (EXE Main)

#### 5.3.1 Anti-Debugging & Anti-Dump Detection

```csharp
if (IsDebuggerPresent()) return;           // Silent exit
if (!CheckAntiDump()) return;              // Silent exit
// Modules checked: x64dbg.dll, x32dbg.dll, ollydbg.dll, scylla.dll, phantom.dll
```

#### 5.3.2 Component Existence Verification

```csharp
foreach (string file in RequiredFiles)
{
    if (!File.Exists(Path.Combine(dir, file)))
    {
        MessageBox.Show("Error: Missing component:\n" + file, ...);
        return;
    }
}
```

#### 5.3.3 File Integrity Verification

```csharp
// 1. Read GAURORA.CHK.ENC → Base64 decode
// 2. Extract Salt[0..15], IV[16..31], Cipher[32..]
// 3. PBKDF2-SHA256(Password, Salt, 100,000) → 32-byte key
// 4. AES-256-CBC decrypt → hash list plaintext
// 5. For each file: SHA256 hash → compare with expected
// 6. File ORDER also validated (index-based comparison)
// 7. Any mismatch → error dialog and exit
```

#### 5.3.4 EXE→PS1 RSA Handshake Protocol (New in v1.1.24.0)

```
┌──────────────── EXE (C#, holds Private Key) ────────────────┐
│                                                               │
│  1. Generate random Nonce (GUID without dashes)               │
│  2. Get current UTC timestamp (Unix seconds)                  │
│  3. Derive session key:                                       │
│     sessionKey = PBKDF2(Nonce, "AU_SESSION_2026_SALT_V1", 1000) │
│  4. Generate random 16-byte Session IV                        │
│  5. AES-256-CBC encrypt hash list plaintext:                  │
│     Cipher = AES(PlainHashList, sessionKey, sessionIV)        │
│  6. Construct HashPayload = sessionIV + Cipher              │
│  7. HashB64 = Base64(HashPayload)                             │
│  8. RSA-SHA256 sign:                                          │
│     Signature = RSASign(Nonce:Timestamp:HashB64, SHA256)      │
│  9. Write Token file (%TEMP%\aurora_token_{GUID}.tok):        │
│     {Nonce}:{Timestamp}:{HashB64}:{Signature}                 │
│  10. Write HashList file (%TEMP%\aurora_hash_{GUID}.tmp)      │
│  11. Set env vars: AURORA_TOKEN_PATH, AURORA_HASH_PATH       │
│  12. Launch PowerShell with GUI script                         │
│  13. Clear env vars, Array.Clear all sensitive buffers        │
│  14. Triple GC.Collect()                                       │
│                                                               │
└───────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────── PS1 (holds Public Key) ──────────────────────┐
│                                                               │
│  1. Read env var AURORA_TOKEN_PATH                            │
│  2. Parse Token: Nonce, Timestamp, HashB64, Signature          │
│  3. RSA-SHA256 verify:                                        │
│     rsa.VerifyData(Nonce:Timestamp:HashB64, Signature, SHA256) │
│  4. Timestamp validation: (now - timestamp) < 60 seconds      │
│     Allow 5-second clock skew tolerance (age > -5)             │
│  5. Derive sessionKey = PBKDF2(Nonce, AES_SALT, 1000)         │
│  6. AES-256-CBC decrypt HashPayload → hash list plaintext      │
│  7. Populate ExpectedFileHashes dictionary                     │
│  8. Launch runtime integrity monitoring                       │
│  9. Clean up temp token files                                  │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

### 5.4 Layer 3: Runtime Security (PS1 LauncherGUI)

#### 5.4.1 Dual Timer System

| Timer                   | Interval                | Purpose                          |
| ----------------------- | ----------------------- | -------------------------------- |
| `runtimeIntegrityTimer` | 3,000 ms (fixed)        | Primary periodic integrity check |
| `randomIntegrityTimer`  | 2,000-7,000 ms (random) | Unpredictable secondary check    |

#### 5.4.2 FileSystemWatcher Configuration

| Property              | Value                                  |
| --------------------- | -------------------------------------- |
| Path                  | Root project directory                 |
| Filter                | `*.ps1,*.json,*.xml,*.ico,*.exe,*.enc` |
| IncludeSubdirectories | `true`                                 |
| NotifyFilter          | `FileName \| Size \| LastWrite`        |
| Events monitored      | Changed, Deleted, Renamed, Created     |

**Event Handling Delays:**

- Changed/Deleted/Renamed: 200 ms delay before integrity check
- Created: 500 ms delay, then check against whitelist

#### 5.4.3 Integrity Check Logic (Four Checks)

```powershell
$script:checkIntegrity = {
    # Check 1: File Count Verification
    #   actualCount != expectedCount → TAMPERED

    # Check 2: Per-File Existence
    #   foreach file in ExpectedFileHashes.Keys:
    #     Test-Path failure → TAMPERED (continue checking)

    # Check 3: Per-File SHA256 Hash Comparison
    #   foreach file in ExpectedFileHashes.Keys:
    #     actualHash != expectedHash → TAMPERED (continue checking)

    # Check 4: FileSystemWatcher Created Events
    #   New file not in whitelist → TAMPERED
}
```

**Key P0 Fixes:**

- Removed all `break` statements — now checks ALL files every time
- If tampering is detected, collects ALL missing/tampered file names for the alert

#### 5.4.4 Tamper Response Protocol

```
TAMPER DETECTED →
  1. Stop the triggering timer/event source
  2. Stop runtimeIntegrityTimer
  3. Stop randomIntegrityTimer
  4. Stop FileSystemWatcher (EnableRaisingEvents = false)
  5. Close splash screen (if open)
  6. Close main window (if open)
  7. Display 15-second countdown warning window:
     - Lists all MISSING files (red marker)
     - Lists all TAMPERED files (yellow marker)
  8. After 15 seconds → program exits
```

#### 5.4.5 Post-Launch Immediate Check

```powershell
# 1,000 ms after PS1 startup → execute first integrity check
# Bridges the gap between startup and first timer tick
```

### 5.5 Layer 4: Multi-Module Launch Detection

Every sub-module (SmartEngine, PRO, RepairTools, UndoViewer) includes identical launch detection logic:

```powershell
# Detection Method 1: GUI_Mode parameter check
if ($GUI_Mode) { $isLaunchedByGUI = $true }

# Detection Method 2: syncHash global variable check
if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
    $isLaunchedByGUI = $true
}

# Detection Method 3: RSA Token verification (final fallback)
$TokenPath = $env:AURORA_TOKEN_PATH
if (Test-Path $TokenPath) {
    $tokenContent = Get-Content $TokenPath -Raw -Encoding UTF8
    $parts = $tokenContent -split ':', 4
    if (Test-RSATokenSignature -Nonce $parts[0] -Timestamp $parts[1]
        -HashPayload $parts[2] -Signature $parts[3])
    {
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if (($now - $parts[1]) -lt 60 -and ($now - $parts[1]) -gt -5) {
            $isLaunchedByGUI = $true
        }
    }
}

# If NOT launched by GUI → 5-second countdown → exit
if (-not $isLaunchedByGUI) {
    Write-Host "This script cannot be run directly!" -ForegroundColor Red
    Start-Sleep -Seconds 5
    exit 1
}
```

### 5.6 Memory Cleanup Procedures

**C# EXE (post-launch):**

```csharp
Array.Clear(keyBytes, 0, keyBytes.Length);
masterPassword = null;
Array.Clear(PwXorMask, 0, PwXorMask.Length);
Array.Clear(PwEncrypted, 0, PwEncrypted.Length);
Array.Clear(sessionKey, 0, sessionKey.Length);
Array.Clear(sessionIv, 0, sessionIv.Length);
GC.Collect();
GC.WaitForPendingFinalizers();
GC.Collect();
```

**PS1 (post-verification):**

```powershell
$global:PassedHashListFromExe = $null
$script:ExpectedFileHashes.Clear()
```

***

## 6. Build System (build.ps1) — Complete Reference

### 6.1 Build Pipeline Stages

| Stage  | Description                                   | Output                                          |
| ------ | --------------------------------------------- | ----------------------------------------------- |
| \[0.5] | RSA key pair generation                       | Private + Public key XML                        |
| \[0.7] | Pre-inject security code into LauncherGUI.ps1 | Updated PS1 with RSA public key                 |
| \[0]   | Check required files exist                    | All 19 files verified                           |
| \[1]   | Calculate SHA256 hashes                       | Hash list in memory                             |
| \[2]   | Generate plain text check data                | In-memory byte array                            |
| \[3]   | AES-256-CBC encrypt with PBKDF2               | `GAURORA.CHK.ENC`                               |
| \[4]   | Decryption verification round-trip            | Confirmation                                    |
| \[5]   | Generate C# code + compile + obfuscate        | `AURORA.Launcher-双击启动.exe`                      |
| \[6]   | Folder customization                          | `desktop.ini`                                   |
| \[7]   | Post-build verification                       | All files confirmed                             |
| \[8]   | Interactive ZIP packaging                     | `Releases/AURORA_Analyzer_vX.X.X.X_Release.zip` |

### 6.2 Version Management

```powershell
# Read from version.txt
$VersionFile = Join-Path $PSScriptRoot "version.txt"
$CurrentVersion = Get-Content $VersionFile -Raw

# Auto-increment (--IncrementVersion switch)
$VersionParts = $CurrentVersion -split "\."
$Minor++
$CurrentVersion = "$Major.$Minor"
```

### 6.3 Password Strength Validation

```powershell
function Test-PasswordStrength {
    # Requirements:
    # - Minimum 8 characters
    # - At least one uppercase letter
    # - At least one lowercase letter
    # - At least one digit
    # - At least one special character
    # Returns: $true / $false
}

function Test-PasswordWithRetry {
    # Retries: 3
    # Input: Read-Host -AsSecureString
    # Validates: Test-PasswordStrength
}
```

### 6.4 Smart Security Code Injection

The build script intelligently handles three cases for LauncherGUI.ps1:

1. **Already injected with RSA keys** → Update RSA public key and SessionSalt (regex replace)
2. **Has placeholder functions** → Replace placeholder `Test-RSATokenSignature` / `Decrypt-HashListFromToken` with real implementations
3. **First-time injection** → Insert full security block after `Param(...)` block

### 6.5 C# Compilation

```powershell
# Find compiler
$cscPaths = @(
    "${env:windir}\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "${env:windir}\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)

# First compilation (un-obfuscated)
& $csc /out:$ExePath /target:winexe /platform:x86 \
    /reference:"System.Windows.Forms.dll" $iconArg $CsPath

# Recompile with obfuscated symbol names
& $csc /out:$ExePathObf /target:winexe /platform:x86 \
    /reference:"System.Windows.Forms.dll" \
    /reference:"System.Reflection.dll" $iconArg $CsPathObf
```

### 6.6 CRC32 Self-Check (Non-Obfuscated Fallback)

When obfuscation is not applied, a CRC32 self-check is embedded:

```powershell
$crc32 = Calculate-CRC32($exeBytes)
$crcHex = "0x$($crc32.ToString('X8'))"
$CsCode2 = $CsCode.Replace("const uint ExpectedCrc32 = 0x00000000;",
    "const uint ExpectedCrc32 = $crcHex;")
```

### 6.7 desktop.ini Folder Customization

```ini
[.ShellClassInfo]
IconResource=Resources\AURORAICON.ico,0
InfoTip=AURORA Analyzer v{version} - Windows Event Log Export and Smart Diagnostics Tool
IconFile=Resources\AURORAICON.ico
IconIndex=0
[ViewState]
FolderType=Documents
```

Applied via:

```powershell
attrib +h +s "desktop.ini"
attrib +r "{ScriptDir}"
```

### 6.8 ZIP Release Packaging

```powershell
$ReleasesDir = Join-Path $ScriptDir "Releases"
$ZipFileName = "AURORA_Analyzer_v$CurrentVersion`_Release.zip"
Compress-Archive -Path $ZipFiles -DestinationPath $ZipPath -Force
```

**Packaged files include:** EXE, CHK.ENC, all 19 PS1/JSON files, icon, font, desktop.ini, version.txt.

***

## 7. Encryption & Cryptographic Primitives

### 7.1 Primitive Inventory

| Primitive   | Algorithm                | Parameters                                                    | Purpose                                   |       Security Rating      |
| ----------- | ------------------------ | ------------------------------------------------------------- | ----------------------------------------- | :------------------------: |
| RSA         | RSA                      | 2048-bit, PKCS#1 v1.5 padding, SHA256                         | EXE↔PS1 handshake signature               |          ✅ Strong          |
| AES         | AES                      | 256-bit, CBC mode, PKCS7 padding                              | Hash list encryption + Session encryption |          ✅ Strong          |
| PBKDF2      | Rfc2898DeriveBytes       | SHA256, 100,000 iterations (CHK) / 1,000 iterations (session) | Password/AES key derivation               |          ✅ Strong          |
| SHA256      | SHA-256                  | Standard                                                      | File integrity hashing                    |          ✅ Strong          |
| XOR+Shuffle | Custom                   | 16-byte mask + permutation                                    | Password static obfuscation               | ⚠️ Weak (obfuscation only) |
| Random IV   | RNGCryptoServiceProvider | 16 bytes                                                      | AES initialization vector                 |          ✅ Strong          |
| Random Salt | RNGCryptoServiceProvider | 16 bytes (CHK) / 32 bytes (session)                           | PBKDF2 salt                               |          ✅ Strong          |
| CRC32       | IEEE 802.3               | —                                                             | EXE self-integrity (fallback)             |   ⚠️ Weak (checksum only)  |

### 7.2 Key Lifecycle

```
BUILD PHASE:
  RSA Key Pair → Private XML → embedded in C# EXE → compiled binary
  RSA Key Pair → Public XML  → injected into PS1 script
  Master Password → XOR+Shuffle → embedded in C# EXE
  PBKDF2 Salt → random → embedded in C# EXE
  Derivation Salt → random → embedded in PS1 script

RUNTIME PHASE (EXE):
  XOR+Shuffle deobfuscate → Master Password (in memory)
  PBKDF2(Password, Salt, 100k) → AES key → decrypt CHK.ENC
  Generate Nonce → PBKDF2(Nonce, AesSalt, 1k) → Session Key
  Generate random IV → AES encrypt hash list → HashPayload
  RSA sign(Nonce:Timestamp:HashPayload) → Signature
  Write Token → Launch PS1 → Array.Clear all keys → GC.Collect

RUNTIME PHASE (PS1):
  Read Token → RSA verify → timestamp check (<60s)
  PBKDF2(Nonce, AesSalt, 1k) → Session Key → AES decrypt HashPayload
  Populate ExpectedFileHashes → Launch runtime monitoring
```

### 7.3 Data Format Specifications

**GAURORA.CHK.ENC:**

```
Base64( Salt[16] + IV[16] + AES-256-CBC(HashList, PBKDF2(Password, Salt, 100000, SHA256)) )
```

**RSA Token File:**

```
{Nonce}:{UTC_Timestamp}:{Base64(IV[16] + AES-256-CBC(HashList, SessionKey))}:{Base64(RSA_Sign(Nonce:Timestamp:HashPayload, SHA256))}
```

**Hash List Plaintext:**

```
{sha256_lowercase_hex} {relative_path}\r\n
{sha256_lowercase_hex} {relative_path}\r\n
...
```

***

## 8. GUI Architecture & Runspace Model

### 8.1 Runspace Architecture

```
┌──────────────────────────┐
│   Main PowerShell Thread  │
│   (Windows Forms GUI)     │
│                           │
│   - Form event loop       │
│   - UI rendering          │
│   - User interaction      │
│   - Timer management      │
│   - syncHash orchestrator │
└──────────┬───────────────┘
           │
           │ syncHash (Synchronized Hashtable)
           │ EventWaitHandle (Authorization)
           │
┌──────────▼───────────────┐
│   Worker Runspace         │
│   (Background Tasks)      │
│                           │
│   - Log export execution  │
│   - Smart diagnostics     │
│   - Repair operations     │
│   - Progress updates      │
└───────────────────────────┘
```

### 8.2 syncHash Communication Protocol

The `$global:syncHash` is a synchronized hashtable that serves as the communication bridge between the GUI thread and worker Runspaces:

| Key                      | Type   | Direction  | Purpose                       |
| ------------------------ | ------ | ---------- | ----------------------------- |
| `LogOutput`              | string | Worker→GUI | Real-time log text            |
| `Progress`               | int    | Worker→GUI | Progress percentage (0-100)   |
| `CurrentStatus`          | string | Worker→GUI | Current operation description |
| `RequestElevation`       | bool   | Worker→GUI | Admin elevation request flag  |
| `ElevationAuthorized`    | bool?  | GUI→Worker | User's elevation decision     |
| `UserInput`              | string | GUI→Worker | User input response           |
| `IsHostAlive`            | bool   | GUI→Worker | GUI liveness heartbeat        |
| `ShowSessionRecoveryHUD` | bool   | Worker→GUI | Session recovery prompt flag  |
| `SessionRestored`        | bool   | GUI→Worker | User chose to restore         |
| `SessionRestarted`       | bool   | GUI→Worker | User chose to restart         |

### 8.3 Authorization System

Uses `EventWaitHandle` instead of polling loops — zero CPU overhead:

```powershell
# Worker requests elevation → sets flag → waits on EventWaitHandle
$global:syncHash.RequestElevation = $true
# GUI detects flag → shows dialog → sets response → signals EventWaitHandle
$global:syncHash.ElevationAuthorized = $true
```

***

## 9. PRO Mode Export Engine

### 9.1 Input Parameters

```powershell
Param(
    [string]$OutputPath,
    [hashtable]$GUIParams,
    [hashtable]$hash,
    [string]$Language = "CHS",
    [switch]$GUI_Mode,
    [string]$LogType,
    [string]$Level,
    [string]$EventId,
    [string]$ProviderName,
    $StartTime,
    $EndTime,
    [string[]]$LogTypes,
    [switch]$ForceRescan
)
```

### 9.2 Export Pipeline

```
1. Date Selection (GUI dialog or parameter)
2. Permission Check (admin required for Security/Setup/DNS/DHCP/AD/IIS)
3. Log Query (Get-WinEvent with FilterHashtable)
4. Data Processing (sort, deduplicate, enrich)
5. Multi-Format Output:
   - CSV (structured, Excel-compatible)
   - JSON (machine-readable, full schema)
   - XML (structured, XSD-compatible)
   - Summary Report (human-readable text)
   - Trend Analysis (statistical aggregation)
6. Progress Checkpoint Save (for resume capability)
7. Open output folder on completion
```

### 9.3 Performance Estimates

| Log Type    | 24-Hour Export Time              |
| ----------- | -------------------------------- |
| System      | \~5-10 seconds                   |
| Application | \~3-8 seconds                    |
| Security    | \~10-20 seconds (admin required) |
| Setup       | \~2-5 seconds                    |
| DNS Server  | \~2-8 seconds                    |

***

## 10. Smart Diagnostics Engine (SmartEngine)

### 10.1 Version & Parameters

**Version:** v1.1.32Release (2026.05.18)

```powershell
Param(
    [string]$OutputPath,
    [hashtable]$GUIParams,
    [hashtable]$hash,
    [string]$Language = "CHS",
    [switch]$GUI_Mode,
    [string]$LogType, [string]$Level,
    [string]$EventId, [string]$ProviderName,
    $StartTime, $EndTime,
    [string[]]$LogTypes,
    [switch]$FromPRO,
    [switch]$FromGUI,
    [string]$ExportedLogPath
)
```

### 10.2 Diagnostic Pipeline

```
Phase 1: Environment Sensing
  → Detect system uptime
  → Detect recent crashes (Event ID 41/6008)
  → If crash: lock 2-hour window before crash
  → If no crash: routine 24-hour check

Phase 2: Log Extraction
  → Concurrent high-risk log extraction
  → Minidump (.dmp) file auto-discovery
  → Minidump parsing (BugCheck code, parameters)

Phase 3: Knowledge Graph Matching
  → Load AURORA-TechData.json
  → Dual-index pre-lookup (EventID + Provider)
  → Candidate set generation
  → Regex exact matching against log content

Phase 4: Repair Terminal
  → Display matched issues with severity
  → Present repair suggestions
  → One-click repair execution
  → Secure sandbox execution via Invoke-AuroraSafeAction
```

### 10.3 Diagnostic Rule Categories

| Category    | Focus              | Example Rules                                              |
| ----------- | ------------------ | ---------------------------------------------------------- |
| **Class A** | System Stability   | Unexpected shutdowns (EventID 41, 6008), BSOD analysis     |
| **Class B** | Application Errors | .NET runtime crashes, application hangs, service failures  |
| **Class C** | Driver Issues      | Driver load failures, timeout detections, IRQL errors      |
| **Class D** | Hardware Faults    | Disk errors, memory errors, WHEA events                    |
| **Class E** | Security Audits    | Failed logins, privilege escalations, audit policy changes |

### 10.4 Minidump Analysis

**Supported BugCheck Codes (20+):**

- `0x0000000A` — IRQL\_NOT\_LESS\_OR\_EQUAL
- `0x0000001E` — KMODE\_EXCEPTION\_NOT\_HANDLED
- `0x0000003B` — SYSTEM\_SERVICE\_EXCEPTION
- `0x0000007E` — SYSTEM\_THREAD\_EXCEPTION\_NOT\_HANDLED
- `0x00000116` — VIDEO\_TDR\_ERROR
- `0x00000124` — WHEA\_UNCORRECTABLE\_ERROR
- `0x00000133` — DPC\_WATCHDOG\_VIOLATION
- `0x00000050` — PAGE\_FAULT\_IN\_NONPAGED\_AREA
- `0x000000D1` — DRIVER\_IRQL\_NOT\_LESS\_OR\_EQUAL
- `0x00000109` — CRITICAL\_STRUCTURE\_CORRUPTION
- ... and more

### 10.5 Secure Sandbox Executor

```powershell
function Invoke-AuroraSafeAction {
    # Flow:
    # 1. Pre-Check: Validate operation safety
    # 2. Risk Assessment: Classify risk level (Low/Medium/High)
    # 3. Authorization: User confirmation dialog
    # 4. Execute: Run repair command
    # 5. Verify: Check post-execution state
    # 6. Rollback: Auto-rollback on failure
}
```

***

## 11. Undo / Repair System (Phase 4.2)

### 11.1 Component Overview

| Module         | File                        | Role                                            |
| -------------- | --------------------------- | ----------------------------------------------- |
| RestoreManager | `AURORA-RestoreManager.ps1` | Windows System Restore API wrapper              |
| UndoManager    | `AURORA-UndoManager.ps1`    | Fast backup snapshots (registry/files/services) |
| RepairLogger   | `AURORA-RepairLogger.ps1`   | Repair audit trail & session logging            |
| RepairTools    | `AURORA-RepairTools.ps1`    | Repair operation entry point                    |
| UndoViewer     | `AURORA-UndoViewer.ps1`     | History viewer & undo UI                        |

### 11.2 Dual Protection Strategy

```
Protection Layer 1: System Restore Points (Windows System Restore API)
  → WMI: root\default\SystemRestore
  → Requires admin + System Restore enabled
  → Full system state snapshot
  → Requires reboot to restore

Protection Layer 2: Fast Backup Snapshots
  → Registry export (.reg files)
  → File copy backup
  → Service configuration export (JSON)
  → No reboot required for undo
  → Snapshot ID: BS_{YYYYMMDD}_{HHmmss}_{random3digits}
```

### 11.3 Repair Operation Types

| RepairType             | Target                 | Description                         |
| ---------------------- | ---------------------- | ----------------------------------- |
| `DisableWindowsUpdate` | Windows Update Service | Disable automatic updates           |
| `EnableDefender`       | Windows Defender       | Re-enable Windows Defender          |
| `DisableTelemetry`     | Telemetry Services     | Disable diagnostic data collection  |
| `ResetNetwork`         | Network Stack          | Reset TCP/IP, Winsock, DNS cache    |
| `CleanSystem`          | System Cleanup         | Temp files, event logs, recycle bin |
| `Custom`               | User-defined           | Custom repair command               |

### 11.4 Repair Session Lifecycle

```
Start-RepairSession(RepairType, Target)
  → Session ID: RS_{YYYYMMDD}_{HHmmss}_{random3digits}
  → Create Restore Point (if enabled)
  → Create Backup Snapshot (registry/files/services)
  → Execute Repair Commands
  → Verify Results
  → Log-SystemRestoreResult (success/failure)
  → Complete-RepairSession (mark undoable)

Undo-RepairSession(SessionId)
  → Option A: SystemRestore (requires reboot)
  → Option B: FastBackupRestore (instant)
  → Mark session as "Undone"
```

### 11.5 RepairLogger Audit Trail

Each repair session records:

- `SessionId` — Unique identifier
- `StartTime` / `EndTime` — Timestamps
- `RepairType` — Operation category
- `Target` — Specific target description
- `CommandsExecuted` — Array of PowerShell commands
- `RestorePointId` — System Restore Point sequence number (if created)
- `BackupSnapshotId` — Fast backup snapshot ID (if created)
- `Result` — Success / Failed / Partial
- `Undoable` — Boolean flag

### 11.6 UndoViewer Features

| Action    | Description                                               |
| --------- | --------------------------------------------------------- |
| `List`    | Show last 20 repair sessions with status indicators       |
| `View`    | Detailed view of a specific session                       |
| `Details` | Full command log and backup paths                         |
| `Undo`    | Execute undo for a session (restore point or fast backup) |
| `Cleanup` | Remove old sessions and expired backups                   |

***

## 12. Progress Manager & Session Persistence

### 12.1 Version & Architecture

**Version:** V1.1.31Release (2026.05.14)

**Cache Directory Structure:**

```
Scripts/SessionCache/
├── active/          # Currently active sessions (JSON)
├── checkpoints/     # Checkpoint backups
└── archive/         # Completed sessions (archived)
```

### 12.2 Session File Format

```json
{
  "SessionId": "SESSION_{YYYYMMDD}_{HHmmss}_{random4digits}",
  "Stage": "Exporting|Analyzing|Reporting|Completed|Failed",
  "Progress": 0-100,
  "LogType": "System",
  "StartTime": "ISO8601",
  "LastUpdated": "ISO8601",
  "Checkpoints": [
    { "Stage": "...", "Progress": 0, "Timestamp": "..." }
  ],
  "Parameters": {
    "StartTime": "...",
    "EndTime": "...",
    "Filters": { ... }
  }
}
```

### 12.3 Key Functions

| Function                     | Description                                 |
| ---------------------------- | ------------------------------------------- |
| `Initialize-ProgressManager` | Setup cache directories, 7-day auto-expiry  |
| `New-AuroraSession`          | Create new session record                   |
| `Save-AuroraProgress`        | Save progress with retry logic (3 attempts) |
| `Create-AuroraCheckpoint`    | Snapshot current state as checkpoint        |
| `Get-RecoverableSession`     | Find latest incomplete session              |
| `Restore-AuroraSession`      | Restore session from archive                |
| `Complete-AuroraSession`     | Mark session as complete, move to archive   |
| `Cleanup-ExpiredSessions`    | Remove sessions older than 7 days           |

### 12.4 Checkpoint Stages

```
Checkpoint_Starting    → "Preparing to start"
Checkpoint_Exporting   → "Exporting logs"
Checkpoint_Analyzing   → "Analyzing patterns"
Checkpoint_Reporting   → "Generating reports"
Checkpoint_Completed   → "Export completed"
Checkpoint_Failed      → "Export failed"
```

### 12.5 Integration Modules

| Module                                       | Language | Purpose                      |
| -------------------------------------------- | -------- | ---------------------------- |
| `AURORA-ProgressManager-Integration.ps1`     | Agnostic | Unified progress integration |
| `AURORA-ProgressManager-Integration-CHS.ps1` | Chinese  | Chinese PRO integration      |
| `AURORA-ProgressManager-Integration-ENG.ps1` | English  | English PRO integration      |

***

## 13. Animation Core Engine (Phase 5)

### 13.1 Architecture

The animation engine is split into two layers:

1. **C# Compiled Layer** (`AURORA-AnimationCoreEngine.ps1` → `AURORA-AnimationCoreEngine.dll`)
   - Embedded C# via `Add-Type`
   - Compiled to DLL on first load (cached)
   - Performance-critical rendering logic
2. **PowerShell Layer** (same file)
   - UI control instantiation
   - Animation orchestration
   - Event binding

### 13.2 C# Type Definitions

```csharp
// Enums
public enum PerformanceTier { Eco = 0, Balanced = 1, Performance = 2, Extreme = 3 }
public enum EasingType { Linear, EaseInCubic, EaseOutCubic, EaseInOutCubic }

// Static Configuration
public static class AuroraRenderEngine
{
    // Performance-tiered settings:
    // Eco:        30 FPS, 80 stars, 0 particles, no effects
    // Balanced:   60 FPS, 180 stars, 30 particles, basic effects
    // Performance: 60 FPS, 350 stars, 80 particles, all effects
    // Extreme:    60 FPS, 600 stars, 150 particles, all effects
}

// Animation Framework
public abstract class Animation { public abstract bool Update(); }
public interface IAnimatable {
    void SetAnimationValue(string propertyName, float value);
    void Invalidate();
}

// Animation Types
public class AnimationManager      // Timer-driven animation scheduler
public class FloatAnimation        // Value interpolation with easing
public class GlareSweepAnimation   // Progress bar glow sweep
public static class AURORA_Animation  // Global animation singleton
```

### 13.3 C# Loading Strategy

```powershell
$engineDll = Join-Path $engineDir "AURORA-AnimationCoreEngine.dll"

# Attempt to load existing DLL
if (Test-Path $engineDll) {
    try {
        Add-Type -Path $engineDll -ErrorAction Stop
        $loaded = $true
    } catch {
        # DLL in use or corrupt → delete and recompile
        Remove-Item $engineDll -Force
    }
}

# Fallback: compile on-the-fly
if (-not $loaded) {
    Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
    // ... embedded C# source ...
'@
}
```

### 13.4 Easing Functions

```csharp
// Cubic easing implementations
EaseInCubic:     easedProgress = progress³
EaseOutCubic:    easedProgress = 1 - (1 - progress)³
EaseInOutCubic:  if progress < 0.5 → 4 * progress³
                 else → 1 - 4 * (1 - progress)³
```

All animations run at \~16ms intervals (\~60 FPS) via `AnimationManager`'s internal timer.

***

## 14. Bilingual Infrastructure

### 14.1 Language Resource File

**File:** `Scripts/AURORA-Language.psd1`\
**Version:** V1.1.13Release (2026.05.14)\
**Entries:** 144 translations (72 per language)

### 14.2 Resource Categories

| Category                | Key Prefix                               | Entries |
| ----------------------- | ---------------------------------------- | ------- |
| Startup Detection       | `Launcher_*`, `Method_*`, `Closing_Soon` | 5       |
| Permission Request      | `Admin_*`                                | 5       |
| Date Selection          | `Date_*`                                 | 3       |
| Export Progress         | `Export_*`                               | 4       |
| Analysis Progress       | `Analyze_*`                              | 3       |
| Report Generation       | `Report_*`                               | 3       |
| Error Messages          | `Error_*`                                | 4       |
| PRO Mode Specific       | `PRO_*`                                  | 8       |
| SmartEngine Integration | `SmartEngine_*`                          | 2       |
| Progress Manager        | `Checkpoint_*`                           | 6       |

### 14.3 Usage Pattern

```powershell
# Load language resources
$langResource = Import-LocalizedData -FileName "AURORA-Language.psd1"
$L = $langResource[$Language]  # $Language = "CHS" or "ENG"

# Usage with string formatting
Write-Host ($L["Export_Done"] -f $recordCount)
Write-Host $L["Launcher_Required"]
```

### 14.4 Language Auto-Detection

```powershell
$uiCulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture.Name
$useChinese = $uiCulture -like "zh*"
$Language = if ($useChinese) { "CHS" } else { "ENG" }
```

### 14.5 Progress Manager Bilingual Support

The ProgressManager module contains its own embedded bilingual strings (76 entries in `Get-LocalizedString`) for session management messages, independent of the shared Language.psd1 resource file.

***

## 15. Performance Tiering System

### 15.1 Scoring Algorithm

```powershell
$perfScore = ($logicalCores * 15) + ($ramGB * 5) +
    ([Math]::Max(0, ($baseClock - 2000) / 100))
```

**Component Weights:**

- CPU Cores: ×15 multiplier (dominant factor)
- RAM: ×5 multiplier (secondary factor)
- Base Clock: Bonus points above 2000 MHz (minor factor)

### 15.2 Tier Thresholds

| Tier            | Score Range | Example Hardware    | Star Count | Particle Count | FPS |
| --------------- | :---------: | ------------------- | :--------: | :------------: | :-: |
| **Eco**         |     < 70    | 2-core, 4 GB RAM    |     80     |        0       |  30 |
| **Balanced**    |    70-119   | 4-core, 8 GB RAM    |     180    |       30       |  60 |
| **Performance** |   120-239   | 6-core, 16 GB RAM   |     350    |       80       |  60 |
| **Extreme**     |    ≥ 240    | 8-core+, 32 GB+ RAM |     600    |       150      |  60 |

### 15.3 Effect Enablement by Tier

| Effect              | Eco | Balanced | Performance | Extreme |
| ------------------- | :-: | :------: | :---------: | :-----: |
| PathGradientShadows |  ❌  |     ✅    |      ✅      |    ✅    |
| Particle System     |  ❌  |     ✅    |      ✅      |    ✅    |
| Dynamic Sweep       |  ❌  |     ❌    |      ✅      |    ✅    |
| Complex Glow        |  ❌  |     ❌    |      ✅      |    ✅    |

### 15.4 Environment Variable Passthrough

```powershell
# PS1 sets:
$env:AURORA_PERF_TIER = $global:AuroraPerfTier

# C# DLL reads:
string tierStr = Environment.GetEnvironmentVariable("AURORA_PERF_TIER");
```

***

## 16. Threat Model & Attack Surface Analysis

### 16.1 STRIDE Coverage

| Threat Category            | Defense Mechanism                                         | Status |
| -------------------------- | --------------------------------------------------------- | :----: |
| **S**poofing               | RSA signature verification (EXE→PS1 handshake)            |    ✅   |
| **T**ampering              | SHA256 hash verification + real-time FileSystemWatcher    |    ✅   |
| **R**epudiation            | RepairLogger audit trail (SessionId + timestamps)         |    ✅   |
| **I**nformation Disclosure | AES-256-CBC encryption, memory cleanup, temp file cleanup |    ✅   |
| **D**enial of Service      | File count checks detect mass deletion                    |    ✅   |
| **E**levation of Privilege | On-demand admin elevation with user authorization         |    ✅   |

### 16.2 Attack Scenario Walkthroughs

**Scenario 1: Replace SmartEngine.ps1**

```
Attacker replaces Scripts\AURORA-SmartEngine.ps1
→ FileSystemWatcher detects Changed event (≤200ms)
→ Next timer tick (≤3s): SHA256 mismatch detected
→ Tamper alert: all monitoring stopped, 15s countdown, exit
RESULT: ATTACK FAILED
```

**Scenario 2: Delete 3 Core Files Simultaneously**

```
Attacker deletes 3 of 19 files
→ FileSystemWatcher detects Deleted events
→ File count check: 16 ≠ 19 → TAMPERED
→ All missing files listed in alert
RESULT: ATTACK FAILED
```

**Scenario 3: Reverse Engineer EXE, Extract Private Key**

```
Attacker decompiles EXE (must bypass obfuscation + anti-debug)
→ Extracts RSA private key
→ Attempts to forge token
→ 60-second timestamp window already expired
→ Even within window: new Nonce prevents replay
RESULT: ATTACK REQUIRES ADVANCED RE SKILLS + TIME CONSTRAINT
```

**Scenario 4: Directly Run SmartEngine.ps1**

```
User/attacker double-clicks AURORA-SmartEngine.ps1
→ No GUI_Mode parameter → check 1 fails
→ No syncHash global variable → check 2 fails
→ No RSA token → check 3 fails
→ "This script cannot be run directly!" → 5s countdown → exit
RESULT: ATTACK FAILED
```

**Scenario 5: Inject Malicious .ps1 File**

```
Attacker creates malicious.ps1 in Scripts directory
→ FileSystemWatcher detects Created event (≤500ms)
→ File not in expected whitelist (19 core files)
→ TAMPERED flag triggered
→ Creates detection → tamper alert → exit
RESULT: ATTACK FAILED
```

### 16.3 Known Limitations

| Limitation                       | Impact                                             | Mitigation                             |
| -------------------------------- | -------------------------------------------------- | -------------------------------------- |
| AES-CBC (no authentication)      | Ciphertext tampering could cause decryption errors | Format validation after decrypt        |
| XOR obfuscation (not encryption) | Advanced reverse engineering can recover password  | Binary compilation barrier             |
| FileSystemWatcher high-load drop | May miss events under extreme I/O load             | Dual timer periodic checks as fallback |
| Token via filesystem             | High-privilege process could read temp token       | 60s expiry + immediate deletion        |
| No Authenticode signing          | EXE lacks digital certificate                      | Planned for future release             |

### 16.4 Security Scorecard

| Dimension                  |  Score (/10) |
| -------------------------- | :----------: |
| Anti-Tampering (Integrity) |      9.0     |
| Anti-Reverse Engineering   |      7.5     |
| Cryptographic Strength     |      9.0     |
| Anti-Replay                |      9.0     |
| Communication Security     |      9.5     |
| Privilege Isolation        |      7.5     |
| Runtime Protection         |      8.5     |
| **Overall**                | **8.6 / 10** |

***

## 17. Version History

### V1.1.24.0 (2026.05.25) — Current Version

**Security System Rebuild:**

- ✅ RSA-2048 asymmetric key pair generation (per-build)
- ✅ EXE↔PS1 secure handshake protocol with token validation
- ✅ AES-256-CBC session encryption layer for hash list transport
- ✅ Dual timer system (3s fixed + 2-7s random interval)
- ✅ FileSystemWatcher real-time integrity monitoring
- ✅ C# offline metadata obfuscation (class/method name randomization)
- ✅ Anti-debugging/anti-dump detection (x64dbg, OllyDbg, Scylla, Phantom)
- ✅ Token 60-second time-based validation with 5s clock skew tolerance
- ✅ 1-second post-launch immediate integrity check
- ✅ Unauthorized file injection detection via FileSystemWatcher
- ✅ P0 Fix: Check interval optimized from 10s to 3s (70% reduction)
- ✅ P0 Fix: Removed break statements for full file hash checking
- ✅ Smart security code injection (detect existing → update → replace → first-time)
- ✅ Session Derivation Salt per-build randomization

### V1.1.23.0 (2026.05.19)

- Complete bilingual support (Chinese/English)
- Phase 4.2 Undo Support System (RestoreManager, UndoManager, RepairLogger, RepairTools, UndoViewer)
- Phase 5 Animation Engine Decoupling (AURORA-AnimationCoreEngine)
- Automatic Minidump blue screen file analysis
- Knowledge base cache mechanism (CliXML serialization)
- Performance optimization: dual-index pre-lookup + candidate set exact matching
- Security enhancement: pre-check + risk assessment + rollback mechanism
- UI beautification: folder icon + desktop.ini configuration
- Build optimization: automatic ZIP packaging + version management
- Bug fix: GUI authorization polling CPU usage (switched to EventWaitHandle)

### V1.1.22.0

- Added progress manager (breakpoint resume)
- Added multi-log type support
- Optimized log export performance

### V1.1.0Release

- Initial public release
- Basic log export functionality
- Smart diagnostics engine v1.0

***

## Appendix A: Test Scripts Inventory

| Test File                                   | Purpose                         |
| ------------------------------------------- | ------------------------------- |
| `test/Test-ProgressManager.ps1`             | Progress manager unit test      |
| `test/Test-ProgressManager-Load.ps1`        | Progress manager load test      |
| `test/Test-ProgressManager-Integration.ps1` | Progress integration test       |
| `test/Test-ProgressManager-ENG.ps1`         | English progress test           |
| `test/Test-ProgressManager-Bilingual.ps1`   | Bilingual progress test         |
| `test/Test-Bilingual.ps1`                   | Bilingual support test          |
| `test/Test-UndoBackup.ps1`                  | Undo backup test                |
| `test/Test-RealBackup.ps1`                  | Real backup test                |
| `test/AURORA-UndoTest.ps1`                  | Undo manager test               |
| `test/Test-Verification.ps1`                | Verification test               |
| `test/Test-Runtime-Tamper.ps1`              | Runtime tamper simulation       |
| `test/Test-Runtime-Tamper-Fixed.ps1`        | Runtime tamper (fixed version)  |
| `test/test-rsa-verification.ps1`            | RSA verification test           |
| `test/Remove-BOM.ps1`                       | BOM removal utility             |
| `Diagnose-IntegrityCheck.ps1`               | Integrity check diagnostic tool |
| `Test-IntegrityFix.ps1`                     | Integrity fix test              |
| `diagnose-rsa.ps1`                          | RSA diagnostic tool             |
| `Remove-BOM.ps1`                            | BOM removal script              |

***

## Appendix B: Security Component Code Index

| Component                     | Location                                                                                                                                                           | Lines |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----- |
| C# Complete Source (template) | \[build.ps1]\(file:///e:/PC SOFT/优化软件/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/build.ps1#L501-L778)                                                   | 278   |
| RSA Token Signing (C#)        | \[build.ps1]\(file:///e:/PC SOFT/优化软件/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/build.ps1#L694-L742)                                                   | 49    |
| RSA Public Key Verify (PS1)   | \[AURORA-AnalyzerLauncherGUI.ps1]\(file:///e:/PC SOFT/优化软件/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/Scripts/AURORA-AnalyzerLauncherGUI.ps1#L10-L73)   | 64    |
| Runtime Integrity Monitor     | \[AURORA-AnalyzerLauncherGUI.ps1]\(file:///e:/PC SOFT/优化软件/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/Scripts/AURORA-AnalyzerLauncherGUI.ps1#L422-L741) | 320   |
| Multi-Module Launch Detection | SmartEngine:L30-L111, PRO:L71-L98, RepairTools:L46-L72, UndoViewer:L38-L67                                                                                         | —     |
| Build: Key Generation         | \[build.ps1]\(file:///e:/PC SOFT/优化软件/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/build.ps1#L143-L162)                                                   | 20    |
| Build: Password Obfuscation   | \[build.ps1]\(file:///e:/PC SOFT/优化软件/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/build.ps1#L164-L188)                                                   | 25    |
| Build: CHK.ENC Encryption     | \[build.ps1]\(file:///e:/PC SOFT/优化软件/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/build.ps1#L421-L455)                                                   | 35    |
| Build: Obfuscation Pipeline   | \[build.ps1]\(file:///e:/PC SOFT/优化软件/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/build.ps1#L825-L910)                                                   | 86    |

***

*Document Version: V1.1.24.0 | Last Updated: 2026.05.25 | Author: AURORA VelociRaptor-GR Dev PRJ.*
