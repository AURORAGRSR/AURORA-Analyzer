# AURORA Analyzer — V1.3.26.5Release Update Notes

**Version:** V1.3.26.5Release
**Code Name:** Aurora Architecture Refactoring
**Build Time:** 2026.06.08
**Theme:** Complete Architectural Decoupling

---

## 1. Version Overview

V1.3.26.5Release is a major architectural refactoring focused on complete modular decoupling. It introduces **no new user-facing features** but represents the most significant internal restructuring in the project's history. The codebase has been transformed from approximately **10,000+ lines in a single monolithic file** to **22+ files across 9 clean module layers**.

This is a **foundational update** — the architectural investment that sets the stage for faster feature development, easier community contribution, and a sustainable codebase going forward.

### Key Metrics at a Glance

| Metric | V1.2.25.0 | V1.3.26.5 |
|--------|-----------|-----------|
| LauncherGUI.ps1 size | ~10,000+ lines | ~1,092 lines |
| Module layers | 5 | 9 |
| Total .ps1 files | ~12 | 22+ |
| UI dialog files | 0 | 4 |
| Build target files | 16 | 22+ |
| Guard-protected files | 16 | 23 |
| New file types (.psd1) | 0 | 1 |

---

## 2. Architecture Decoupling: Monolith to Modular

### 2.1 Before/After File Tree Comparison

**Before (V1.2.25.0) — Single Monolith + Loose Scripts:**

```
Scripts/
├── AURORA-AnalyzerLauncherGUI.ps1     ← ~10,000+ lines; contains ALL UI, security,
│                                          animation, view logic, PRO features
├── Engines/
│   └── AURORA-SmartEngine.ps1
├── Core/
│   ├── AURORA-CoreEngine.ps1
│   └── AURORA-AnimationCoreEngine.ps1
├── Session/
│   ├── AURORA-ProgressManager.ps1
│   └── AURORA-UndoManager.ps1
├── Repair/
│   └── AURORA-RepairTools.ps1
├── GUI/
│   └── AURORA-GUI-Functions.ps1
└── PRO/
    └── AURORA-AnalyzerPRO.ps1
```

**After (V1.3.26.5) — 9-Layer Modular Architecture:**

```
Scripts/
├── AURORA-AnalyzerLauncherGUI.ps1        ← Orchestrator only; ~1,092 lines
│
├── Core/
│   ├── AURORA-CoreEngine.ps1              (shared core engine)
│   ├── AURORA-AnimationCoreEngine.ps1     (animation engine)
│   └── AURORA-AnimationCoreEngine.dll     (compiled C# helper DLL)
│
├── Security/                              ← [NEW LAYER]
│   └── AURORA-SecurityModule.ps1          (RSA, AuroraGuard, watchdog, exit)
│
├── UI/Controls/                           ← [NEW LAYER]
│   ├── AURORA-UIControls.ps1              (TechButton, ProgressBar, StarfieldPanel)
│   └── AURORA-Animations.ps1              (animation orchestration helpers)
│
├── UI/Views/                              ← [NEW LAYER]
│   ├── View-MainForm.ps1                  (main form UI; 1,100+ lines)
│   ├── View-SplashScreen.ps1              (splash screen)
│   ├── View-ProMode.ps1                   (PRO mode result window)
│   └── Dialogs/
│       ├── View-SessionRestoreDialog.ps1  (session recovery)
│       ├── View-ElevationDialog.ps1       (admin elevation request)
│       ├── View-PermissionInfo.ps1        (permission information)
│       └── View-AdminElevation.ps1        (elevation state management)
│
├── Engines/
│   └── AURORA-SmartEngine.ps1
│
├── PRO/
│   ├── AURORA-AnalyzerPRO-Engine.ps1      ← [NEW — unified CHS/ENG]
│   └── AURORA-AnalyzerPRO.ps1
│
├── Session/
│   ├── AURORA-ProgressManager.ps1
│   ├── AURORA-ProgressManager-Integration.ps1
│   ├── AURORA-UndoManager.ps1
│   └── AURORA-UndoViewer.ps1
│
├── Repair/
│   ├── AURORA-RepairTools.ps1
│   ├── AURORA-RepairLogger.ps1
│   └── AURORA-RestoreManager.ps1
│
└── GUI/
    ├── AURORA-GUI-Functions.ps1           (expanded)
    └── AURORA-Language.psd1               ← [NEW — centralized i18n]
```

### 2.2 Module-Level Decoupling Details

#### AURORA-SecurityModule.ps1 (NEW — ~1,000+ lines)

**Extracted from:** `AURORA-AnalyzerLauncherGUI.ps1`

This is the largest extraction. All security-sensitive code that was previously interleaved with UI logic now lives in a dedicated, auditable module.

**What it contains:**

- **RSA public key** — built into the module as a compile-time constant
- **RSA token verification** — `Test-RSATokenSignature` function for signed-token trust establishment
- **AES hash list decryption** — `Decrypt-HashListFromToken` for decrypting file-integrity hash lists from signed tokens
- **AuroraGuard C# embedded runtime guardian** — compiled at load time via `Add-Type`:
  - 9+ debugger detection methods (IsDebuggerPresent, NtGlobalFlag, CheckRemoteDebuggerPresent, CloseHandle anti-anti-debug, PEB BeingDebugged, NtQueryInformationProcess, OutputDebugString exploit, hardware breakpoint scanning, timing-based detection)
  - Anti-dump protection
  - Hardware breakpoint detection (DR0–DR3, DR7 scan via GetThreadContext)
  - FileSystemWatcher-based integrity monitoring (detects unauthorized file modifications in real time)
- **Watchdog environment cleanup** — `Clear-AuroraWatchdogEnv` removes all Named Pipe artifacts, environment variables, and Runspace handles
- **Exit handler registration** — `Register-AuroraExitHandler` ensures cleanup runs on script termination
- **P0 state flag reset** — `ExitCountdownStarted`, `DebuggerCheckCount`, `IntegrityCheckCount` reset to safe defaults before any guard initialization
- **Watchdog client Named Pipe connection** — with exponential-backoff retry logic
- **Launch-time file integrity verification** — `Test-FileIntegrity` with SHA256 hashing against the injected hash dictionary
- **Runtime integrity monitoring system** — `Initialize-RuntimeIntegrityCheck` with dual timers (10s startup window + 60s periodic), FileSystemWatcher, and startup check timer

**Why this matters:**
Before, security logic was scattered across 3,000+ lines of a monolithic file, intermixed with button event handlers and form creation. Now, the security module is isolated, testable, and auditable independently of UI code.

---

#### AURORA-UIControls.ps1 (NEW)

**Extracted from:** `AURORA-AnalyzerLauncherGUI.ps1`

**What it contains:**

| Control | Type | Description |
|---------|------|-------------|
| **TechButton** | C# embedded WinForms control | Ripple click feedback with gradual expansion + fade-out; magnetic snap with radius detection + progressive interpolation; glass-morphism 3-state color scheme (Normal/Hover/Active with backdrop-blur emulation); transition mode protection to prevent concurrent animation corruption |
| **AuroraProgressBar** | C# embedded WinForms control | Smooth progress transitions via `_displayProgress` animation engine; integrated particle system with glow animation; rounded-corner rendering; dual-track (determinate + indeterminate) display modes |
| **StarfieldPanel** | C# embedded WinForms control | Background particle system (300+ stars with individual velocity vectors, parallax depth layers); overlaid status text rendering with fade transitions |
| **AuroraExitCountdown** | C# embedded WinForms form | 15-second tamper-alert countdown dialog with Markdown text support; auto-exit on timer expiry |

**Before/After:**
- **Before:** Each control's C# source was inlined directly in LauncherGUI.ps1, often duplicated when used in multiple contexts. Finding a button bug meant searching through 10,000 lines.
- **After:** Each control is defined in exactly one place with a clear public API. Debugging a ripple animation bug means looking at one file of a few hundred lines.

---

#### AURORA-Animations.ps1 (NEW)

**Extracted from:** `AURORA-AnalyzerLauncherGUI.ps1`

Contains animation helper functions for coordinating multi-view transitions:

- `Invoke-PanelSlideIn` / `Invoke-PanelSlideOut` — orchestrated panel transitions with easing functions
- `Invoke-ModalFadeIn` / `Invoke-ModalFadeOut` — modal dialog fade orchestration
- `Start-TransitionSequence` — chains multiple animations into a coordinated sequence

**Why this matters:** Before, animation code was duplicated across splash screen, main form, and PRO mode handlers. Now, a single set of functions serves all views consistently.

---

#### View-MainForm.ps1 (NEW — ~1,100+ lines)

**Extracted from:** `AURORA-AnalyzerLauncherGUI.ps1`

The largest single extraction. Contains the complete main form lifecycle:

| Section | Lines | Content |
|---------|-------|---------|
| Form initialization | ~150 | Window creation, size, position, icon, title bar customization |
| Control creation | ~300 | All buttons, labels, panels, progress bars, starfield backgrounds |
| Layout | ~200 | Docking, anchoring, tab order, responsive resize behavior |
| Event handlers | ~350 | Click handlers for all interactive elements, timer tick handlers, form load/close events |
| Mode switching | ~100 | Smart mode → PRO mode → Repair mode → Minimal mode transitions |
| Elevation integration | ~50 | Admin elevation status bar updates, UAC state reflection |

**Key architectural change:**
- **Before:** `$global:syncHash["MainForm"]` was created, populated, and managed inline in LauncherGUI, interleaved with security checks and token verification
- **After:** `View-MainForm.ps1` exposes `New-MainForm -syncHash $syncHash` — a clean factory function that accepts the shared state hashtable and returns a fully configured form

---

#### View-SplashScreen.ps1 (NEW)

**Extracted from:** `AURORA-AnalyzerLauncherGUI.ps1`

**Contents:**
- Starfield particle animation with version overlay
- Version information display (version number, build date, code name)
- Loading progress indicator with animated dots
- Fade-in transition with configurable duration
- `Show-AuroraSplashScreen -syncHash $syncHash -Version $version` factory function

**Before:** Splash screen creation was ~200 lines embedded in the main script's startup sequence. **After:** A focused 80-line module with a single public entry point.

---

#### View-ProMode.ps1 (NEW)

**Extracted from:** `AURORA-AnalyzerLauncherGUI.ps1`

**Contents:**
- PRO mode result display window with scrollable RichTextBox output
- Formatted log display with color-coded severity levels
- Export controls (copy to clipboard, save to file)
- Real-time output streaming from child Runspace
- `Show-ProModeWindow -syncHash $syncHash` factory function

---

#### 4 Dialog Views (ALL NEW)

| File | Purpose | Key Interaction |
|------|---------|-----------------|
| `View-SessionRestoreDialog.ps1` | Session recovery dialog | Resume/Restart choice; session age display (e.g., "Session from 2 hours ago"); progress preview showing how much work can be recovered |
| `View-ElevationDialog.ps1` | Admin elevation request | Reason display ("AURORA needs administrator privileges to scan system files"); Authorize/Deny buttons with graceful decline path |
| `View-PermissionInfo.ps1` | Permission information display | Read-only informational panel explaining why elevation is needed and what AURORA does not access |
| `View-AdminElevation.ps1` | Admin elevation state management | Monitors and reflects UAC state changes in real time; updates status bar indicator; handles elevation timeout scenarios |

---

#### AURORA-AnalyzerPRO-Engine.ps1 (NEW — ~290 KB)

**Purpose:** Unified CHS/ENG PRO engine replacing two separate language-specific versions.

**Before:**
```
(No unified PRO engine existed.)
PRO logic was split across:
- LauncherGUI.ps1 (export logic, parameter passing)
- AURORA-AnalyzerPRO.ps1 (CHS analysis routines)
- Inline code for English mode variants
```

**After:**
- Single engine loaded by child Runspaces in PRO mode
- Language-agnostic core logic with localization hooks to `AURORA-Language.psd1`
- Clean separation: `AURORA-AnalyzerPRO.ps1` is the thin front-end, `AURORA-AnalyzerPRO-Engine.ps1` is the heavy-lifting engine

---

#### AURORA-Language.psd1 (NEW)

**Purpose:** Centralized bilingual (CHS/ENG) resource dictionary.

**Before:**
```
# Strings scattered across the entire codebase:
Write-Host "正在初始化..."      # LauncherGUI.ps1 line 234
Write-Host "Initializing..."    # LauncherGUI.ps1 line 567 (duplicated!)
$label.Text = "扫描进度"         # View code line 891
```

**After:**
```powershell
# Single source of truth:
$lang = Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName "AURORA-Language.psd1"
Write-Host $lang.Initializing           # → "正在初始化..." or "Initializing..."
$label.Text = $lang.ScanProgress       # → "扫描进度" or "Scan Progress"
```

**Scale:** 100+ translation entries covering all user-visible strings in the application.

---

#### AURORA-GUI-Functions.ps1 (EXPANDED)

**New additions:**

| Function | Purpose |
|----------|---------|
| `Test-DirectoryIntegrity` | Validates that all required directories exist and are writable; checks for tampering with directory structure |
| `Get-EmojiFont` | Cross-platform emoji font detection (Segoe UI Emoji on Windows, Noto Color Emoji on Linux) |
| `Get-MonospaceFont` | Monospace font detection cascade (Cascadia Code → Consolas → Courier New) |
| `Get-SansSerifFont` | Sans-serif font detection cascade (Segoe UI → Arial → Helvetica) |
| `CreateAuroraProgressBar` | Factory helper that creates a configured AuroraProgressBar with standard settings |
| `Update-StarfieldStatusText` | Thread-safe status text update for StarfieldPanel from any Runspace |

---

#### AURORA-CoreEngine.ps1 (EXPANDED)

**New additions:**

| Function | Purpose |
|----------|---------|
| `Invoke-SafeOperation` | Unified safe execution wrapper: runs a scriptblock with automatic try/catch, structured error logging, and optional cleanup callback |
| `Write-AuroraStructuredLog` | CSV file-persistent logging with timestamp, severity, module, and message columns |
| `Get-AuroraVersion` | Returns the version string with validation against expected format |
| `Invoke-SafeExit` | Graceful exit: triggers all registered exit handlers, flushes logs, disposes Runspaces, and exits with the correct code |
| `Convert-SafeDateTime` | Multi-format date parsing: handles ISO 8601, US locale, Chinese locale, and Unix timestamps |
| `$global:AURORA_CoreEngine_Loaded` | Duplicate import prevention guard — prevents accidental re-dot-sourcing across Runspaces |

---

#### AURORA-ProgressManager.ps1 (EXPANDED)

**New additions:**

| Feature | Description |
|---------|-------------|
| **SessionCache directory structure** | Three-tier cache: `active/` (current session), `checkpoints/` (named save points), `archive/` (completed sessions) |
| **7-day auto-expiry mechanism** | Sessions older than 7 days are automatically cleaned up on next launch; configurable via `$AuroraSessionMaxAgeDays` |
| **Full bilingual support** | All progress labels, status messages, and error texts routed through `Get-LocalizedString` with CHS/ENG dictionary lookup |
| **Structured checkpoint metadata** | Each checkpoint now stores timestamp, mode, progress percentage, and file count in a companion JSON metadata file |

---

## 3. Security Fixes

### 3.1 AURORA-SEC-2026-001: Elevation Token Security Fix

| Aspect | Detail |
|--------|--------|
| **Severity** | High |
| **Category** | Trust-chain break on UAC elevation |
| **CVE-style ID** | AURORA-SEC-2026-001 |

**Problem:**
When the EXE launcher spawns an elevated PowerShell process (via UAC), the original non-elevated process and the new elevated process share the same temporary directory. The RSA token file created by the EXE was getting deleted by the original (non-elevated) process's cleanup code during its shutdown sequence, leaving the newly elevated instance **without a valid trust token**.

**Attack Surface:**
An attacker who could influence timing (e.g., by delaying the elevated process startup) could cause the token to be deleted before the elevated process reads it, forcing a fallback to password-only verification — weakening the overall trust chain.

**Fix (LauncherGUI.ps1, lines 142–195):**
A new `-ElevationTokenPath` parameter was introduced. The EXE now:
1. Creates a **separate AES-encrypted elevation token** (distinct from the main RSA token)
2. Passes the path to this token via command-line argument to the elevated process
3. The elevated process reads, decrypts, and validates this token independently
4. Token validity is **120 seconds** from creation
5. The elevated process's `Clear-AuroraWatchdogEnv` explicitly disposes this token file on clean exit

**Verification Flow:**
```
EXE → Create RSA token → Create AES elevation token → Spawn elevated PS
                                                           ↓
Elevated PS → Read elevation token → Decrypt AES → Validate token age
                                                           ↓
                           [Valid] → Continue with trust chain
                         [Expired] → Fallback: password verification required
```

---

### 3.2 P0: Startup State Flag Reset

| Aspect | Detail |
|--------|--------|
| **Severity** | Critical |
| **Location** | LauncherGUI.ps1, lines 238–242 |

**Problem:**
Three security-critical global state flags — `ExitCountdownStarted`, `DebuggerCheckCount`, and `IntegrityCheckCount` — persist in the global scope. If AURORA exits uncleanly (crash, forced kill, power loss), these flags can retain their non-default values:

- `ExitCountdownStarted = $true` → Security guard skips tamper detection entirely
- `DebuggerCheckCount > 0` → AuroraGuard anti-debug checks may be bypassed
- `IntegrityCheckCount > 0` → File integrity verification skipped

On the next launch (in the same PowerShell process or via EXE watchdog reuse), the guard would silently skip critical checks.

**Fix:**
Explicitly set all three flags to their safe defaults (`$false`, `0`, `0`) at the very top of the initialization sequence — **before** any security guard initialization or watchdog connection.

```powershell
# P0: Reset all state flags before any security initialization
$global:ExitCountdownStarted = $false
$global:DebuggerCheckCount    = 0
$global:IntegrityCheckCount   = 0
```

---

### 3.3 P0: Watchdog Resource Cleanup

| Aspect | Detail |
|--------|--------|
| **Severity** | Critical |
| **Location** | LauncherGUI.ps1, lines 1048–1087 |

**Problem:**
Three watchdog resources — **NamedPipeClientStream**, **Runspace**, and **PowerShell instance** — were not being properly disposed on application exit. These objects could persist in the process memory:

- The Named Pipe remains half-open from the client side
- The Runspace holds a live PowerShell session reference
- On next launch, the EXE watchdog detects the stale connection and **refuses to connect**

**Fix:**
Added a comprehensive cleanup block executed during `Register-AuroraExitHandler`:

```powershell
# Dispose watchdog pipe client
if ($global:AuroraWatchdogPipe -ne $null) {
    try { $global:AuroraWatchdogPipe.Close(); $global:AuroraWatchdogPipe.Dispose() }
    catch { }
    $global:AuroraWatchdogPipe = $null
}

# Dispose watchdog Runspace
if ($global:AuroraWatchdogRunspace -ne $null) {
    try { $global:AuroraWatchdogRunspace.Dispose() }
    catch { }
    $global:AuroraWatchdogRunspace = $null
}

# Dispose watchdog PowerShell instance
if ($global:AuroraWatchdogPS -ne $null) {
    try { $global:AuroraWatchdogPS.Dispose() }
    catch { }
    $global:AuroraWatchdogPS = $null
}
```

---

### 3.4 P0: Unverified Launch Flag Protection

| Aspect | Detail |
|--------|--------|
| **Severity** | Critical |
| **Location** | LauncherGUI.ps1, lines 197–210 |

**Problem:**
An attacker who can control the command-line arguments to `powershell.exe` could provide `-LaunchedByExe` as a parameter. This flag, if accepted without verification, bypasses:
- RSA token signature verification
- Password verification
- All AuroraGuard runtime integrity checks

**Attack Vector:**
```
powershell.exe -File "AURORA-AnalyzerLauncherGUI.ps1" -LaunchedByExe
```

The script would see `-LaunchedByExe` was passed and assume the EXE verified everything.

**Fix:**
After all RSA token AND elevation token verification attempts have been exhausted, the flag undergoes a final sanity check:

```powershell
# Force-reset if no hash list was successfully obtained
if ($IsLaunchedByExe -and (-not $global:HashListObtained)) {
    $IsLaunchedByExe = $false
}
```

If `IsLaunchedByExe` is still `$true` but no hash list was successfully decrypted from any token, the flag is **forcibly reset to `$false`** and the user must provide the password.

---

### 3.5 P1: Environment Variable Cleanup Gap

| Aspect | Detail |
|--------|--------|
| **Severity** | Medium |
| **Location** | SecurityModule.ps1 → `Clear-AuroraWatchdogEnv` |

**Problem:**
`AURORA_LAUNCHED_BY_EXE` and three other environment variables were being set but not cleaned up on exit. If the same PowerShell process was used to launch AURORA a second time, the stale environment variables could cause incorrect assumptions about EXE verification state.

**Fix:**
Added these four variables to the `Clear-AuroraWatchdogEnv` cleanup list:

```
AURORA_LAUNCHED_BY_EXE
AURORA_TOKEN_PATH
AURORA_EXE_VERIFIED
AURORA_HASH_PATH
```

---

### 3.6 P2: Duplicate Assembly Loading Prevention

| Aspect | Detail |
|--------|--------|
| **Severity** | Low |
| **Location** | LauncherGUI.ps1, lines 882–887 |

**Problem:**
`Add-Type -AssemblyName System.Windows.Forms` and `Add-Type -AssemblyName System.Drawing` could be executed multiple times if multiple modules independently requested them. PowerShell's `Add-Type` does not silently deduplicate — repeated calls can cause type conflicts and assembly load errors.

**Fix:**
Added pre-load checks using `[AppDomain]::CurrentDomain.GetAssemblies()`:

```powershell
# Prevent duplicate assembly loading
$loadedAssemblies = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetName().Name }
if ('System.Windows.Forms' -notin $loadedAssemblies) {
    Add-Type -AssemblyName System.Windows.Forms
}
if ('System.Drawing' -notin $loadedAssemblies) {
    Add-Type -AssemblyName System.Drawing
}
```

---

## 4. Build System Updates

### 4.1 Phase 6 Module Path Updates

The build system (`build.ps1`) has been updated to reflect the new modular architecture:

| Build Component | V1.2.25.0 | V1.3.26.5 |
|-----------------|-----------|-----------|
| `$RequiredFiles` array | ~16 entries | 22+ entries |
| C# EXE `RequiredFiles` | ~16 entries | 22+ entries (synced) |
| `$ZipFiles` array | ~16 entries | 22+ entries with new directory structure |
| Hash calculation targets | ~16 files | 22+ files |

All hash calculations and integrity checks now cover every module file in the expanded directory tree.

### 4.2 C# Guard Hash Injection Target Changed

| Aspect | Before | After |
|--------|--------|-------|
| **Injection target** | `AURORA-AnalyzerLauncherGUI.ps1` | `Security/AURORA-SecurityModule.ps1` |
| **Reason** | Guard code lived in the launcher | Guard code now lives in SecurityModule |
| **Exclusion** | None (guard guarded itself) | SecurityModule.ps1 is excluded from the hash list (a guard cannot guard itself) |
| **Protected count** | 16 files | 23 files |

The guard hash dictionary is injected as a placeholder token during build, then replaced with actual SHA256 hashes during the compilation step. The exclusion of `AURORA-SecurityModule.ps1` from the guarded file list eliminates the self-referential hash problem that existed in V1.2.25.0.

### 4.3 Version Synchronization

Build step `[0.8/6]` now scans all 22+ script files for version strings using three regex patterns:

| Pattern | Target format | Example match |
|---------|--------------|---------------|
| Chinese version line | `版本\s*[:：]\s*V[\d.]+` | `版本: V1.3.26.5Release` |
| English version line | `Version\s*[:：]\s*V[\d.]+` | `Version: V1.3.26.5Release` |
| LauncherGUI comment | `#\s*V[\d.]+` | `# V1.3.26.5Release` |

All matched strings are replaced with the current build version, ensuring every module reports a consistent version identity.

---

## 5. Module Dependency Graph

```
AURORA-AnalyzerLauncherGUI.ps1 (Orchestrator — 1,092 lines)
│
├── [Load Order 1]  GUI/AURORA-GUI-Functions.ps1
├── [Load Order 2]  Core/AURORA-AnimationCoreEngine.ps1 (+ .dll)
├── [Load Order 3]  Core/AURORA-CoreEngine.ps1
├── [Load Order 4]  Security/AURORA-SecurityModule.ps1
├── [Load Order 5]  UI/Controls/AURORA-UIControls.ps1
├── [Load Order 6]  UI/Views/View-SplashScreen.ps1
├── [Load Order 7]  Session/AURORA-ProgressManager.ps1
├── [Load Order 8]  UI/Views/Dialogs/View-SessionRestoreDialog.ps1
├── [Load Order 9]  UI/Views/Dialogs/View-ElevationDialog.ps1
├── [Load Order 10] UI/Views/Dialogs/View-PermissionInfo.ps1
├── [Load Order 11] UI/Views/Dialogs/View-AdminElevation.ps1
├── [Load Order 12] UI/Views/View-MainForm.ps1
├── [Load Order 13] UI/Views/View-ProMode.ps1
└── [Load Order 14] UI/Controls/AURORA-Animations.ps1
```

**Load order rationale:**
1. `GUI-Functions` loads first — provides font helpers and directory integrity checks needed by subsequent modules
2. `AnimationCoreEngine` loads second — C# DLL is loaded once and cached
3. `CoreEngine` loads third — `$global:AURORA_CoreEngine_Loaded` guard set before other modules attempt to import
4. `SecurityModule` loads fourth — must be ready before any view creates controlled UI elements
5. `UIControls` loads fifth — C# WinForms controls compiled once, reused by all views
6. Views load in dependency order: Splash (no deps) → dialogs → MainForm (uses all controls and dialogs) → ProMode (uses MainForm patterns)

**Runtime Dependencies (loaded by child Runspaces on demand):**

```
PRO Runspace:
  PRO/AURORA-AnalyzerPRO-Engine.ps1
    └── GUI/AURORA-Language.psd1

Smart Mode Runspace:
  Engines/AURORA-SmartEngine.ps1
    └── Core/AURORA-CoreEngine.ps1 (already loaded; guard prevents re-import)

Repair Runspace:
  Repair/AURORA-RepairTools.ps1
    ├── Repair/AURORA-RestoreManager.ps1
    ├── Repair/AURORA-RepairLogger.ps1
    └── Session/AURORA-UndoManager.ps1

Session Runspace:
  Session modules load Repair modules on demand via dynamic dot-sourcing
```

**Communication pattern:** All modules communicate through `$global:syncHash`, a synchronized hashtable. No module directly references another module's internal functions. This prevents circular dependencies and makes modules independently testable.

---

## 6. Code Quality Improvements

| Improvement | Before | After |
|-------------|--------|-------|
| **Duplicate Import Prevention** | No guards; multiple `Add-Type` calls for the same assembly; dot-sourcing could re-execute module code | `$global:AURORA_CoreEngine_Loaded` and similar flags prevent accidental re-import across Runspaces; assembly pre-load checks prevent type conflicts |
| **Unified Logging** | Mix of `Write-Host`, `Write-Output`, and ad-hoc log files with inconsistent formats | `Write-AuroraLog` for console output; `Write-AuroraStructuredLog` for CSV-persistent file logging — used consistently across all 22+ modules |
| **Unified Safe Execution** | Scattered try-catch blocks with inconsistent error handling, missing cleanup in error paths | `Invoke-SafeOperation -ScriptBlock { ... } -Cleanup { ... }` pattern replaces all ad-hoc error handling with consistent logging, error propagation, and guaranteed cleanup |
| **Consistent Error Handling** | Each module implemented its own error handling (or none at all); error messages were inconsistent across modules | All modules follow the same pattern: `Invoke-SafeOperation` wrapper → structured log entry → user-friendly message from language dictionary |
| **Single Responsibility** | LauncherGUI.ps1 handled bootstrapping, security, UI creation, event handling, PRO mode, and animation — all in one file | Each file has one clear responsibility; the `UI/Views/` and `UI/Controls/` layers enforce strict separation of concerns |
| **Reduced Coupling** | Functions in different "modules" frequently called each other directly via hard dependencies | Modules communicate only through `$syncHash`; internal function signatures are private to each module; public entry points are factory functions that take `$syncHash` as a parameter |
| **Bilingual Foundation** | Translation strings were inline string literals scattered across the codebase; adding a new language required finding and replacing every instance | All user-facing strings centralized in `AURORA-Language.psd1`; adding a new language requires translating one file; all modules reference `$lang.KeyName` |

---

## 7. Compatibility

| Compatibility Area | Status |
|--------------------|--------|
| **Backward compatibility with V1.2.25.0** | ✅ Full backward compatibility |
| **Existing functionality** | ✅ Preserved without modification |
| **GAURORA.CHK.ENC check files** | ✅ Still valid; no format change |
| **SessionCache data** | ✅ Compatible; new 7-day expiry is additive, not destructive |
| **Animation engine DLL** | ✅ Binary backward compatible |
| **Build scripts** | ✅ Same interface: `AURORA-build.bat /generate` |
| **Password verification** | ✅ Unchanged |
| **EXE launcher** | ✅ Compatible; new `-ElevationTokenPath` parameter is additive |

---

## 8. File Change Statistics

| Category | V1.2.25.0 | V1.3.26.5 | Change |
|----------|-----------|-----------|--------|
| Total .ps1 files | ~12 | 22+ | **+83%** |
| Module layers | 5 | 9 | **+80%** |
| LauncherGUI.ps1 size | ~10,000+ lines | ~1,092 lines | **−89%** |
| New .psd1 files | 0 | 1 | **NEW** |
| New UI dialog files | 0 | 4 | **NEW** |
| Build target files | 16 | 22+ | **+37%** |
| Guard-protected files | 16 | 23 | **+44%** |
| New module directories | — | `Security/`, `UI/Controls/`, `UI/Views/Dialogs/` | **3 NEW** |

---

## 9. What This Enables Going Forward

The modular architecture unlocks several capabilities that were impractical with the monolithic codebase:

| Future Capability | Enabled By |
|-------------------|------------|
| **Unit testing** | Each module has a single responsibility and communicates through `$syncHash`; modules can be tested in isolation |
| **Community contributions** | Contributors can work on individual modules without understanding the entire 10,000-line codebase |
| **Plugin architecture** | New views can be added to `UI/Views/` and registered in the load order without modifying existing code |
| **Language pack contributions** | Adding a new language requires translating one `.psd1` file (100+ entries) |
| **Independent security audits** | Security-sensitive code is isolated in `Security/AURORA-SecurityModule.ps1` — auditable without wading through UI code |
| **Parallel feature development** | Multiple developers can work on different module layers simultaneously without merge conflicts |
| **Faster build iteration** | Only changed modules need to be re-hashed and re-packaged, not the entire codebase |

---

## 10. Known Limitations (Unchanged from V1.2.25.0)

These are pre-existing limitations that have been preserved through the refactoring to maintain backward compatibility:

- AES-256-CBC encryption uses a static IV (design constraint for EXE ↔ PS interop)
- Session cache is per-machine, not roaming-profile-aware (Windows limitation)
- Some C# embedded controls use `System.Windows.Forms.Timer` (STA thread requirement)
- Exit countdown timer uses `[System.Threading.Thread]::Sleep` (acceptable for exit path, not used during normal operation)

---

*Document generated: 2026.06.09*
*Corresponding release: AURORA Analyzer V1.3.26.5Release (Aurora Architecture Refactoring)*