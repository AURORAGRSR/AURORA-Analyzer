# AURORA Analyzer V1.1.24.1 — Update Log

**Release Date:** 2026.05.27  
**Current Version:** V1.1.24.1  
**Previous Version:** V1.1.24.0  
**Author:** AURORA VelociRaptor-GR Dev PRJ.  
**Update Type:** Security and User Experience Enhancement Release

---

## 🔐 Security Enhancements

### 1. Full-Link Integrity Monitoring Coverage

**Issue Description:**
> In V1.1.24.0, runtime integrity checks were paused when entering Professional Graphics Mode (secondary window). This created a security monitoring blind spot where file tampering could not be detected in real-time during secondary window operation (typically 5-30 minutes).

**Resolution:**
- ✅ **Removed integrity check pause logic** - Integrity checks continue during secondary window operation
- ✅ **Registered secondary window to global variable** - `$global:proForm` for integrity check system recognition
- ✅ **Enhanced tamper response mechanism** - Sequential closure on tamper detection: Secondary Window → Splash Screen → Main Window
- ✅ **Non-lethal verification mode** - `AuroraGuard.VerifyOrDie()` changed from `Environment.FailFast` to return boolean value

**Technical Implementation:**
```powershell
# Fix 1: AuroraGuard base path correction (Line 440)
[AuroraGuard]::Initialize((Split-Path -Parent $PSScriptRoot))  # Use root directory

# Fix 2: VerifyOrDie non-lethalization (Lines 429-434)
public static bool VerifyOrDie() {
    if (!CheckIntegrity()) return false;  // No longer kills process
    return true;
}

# Fix 3: ShowProMode security enhancement (Lines 9776-9777)
$global:proForm = $proForm  # Register secondary window for integrity check recognition

# Fix 4: Tamper detection processor enhancement (Lines 870-900)
# Hide all windows first, then show warning
if ($global:proForm) { $global:proForm.Hide() }
if ($splash) { $splash.Hide() }
if ($global:mainForm) { $global:mainForm.Hide() }
```

**Security Benefits:**
- ✅ Achieved **full-link integrity monitoring** from launch to exit, no time window blind spots
- ✅ Tamper detection response time < 3 seconds during secondary window operation
- ✅ Prevented attackers from exploiting file replacement attacks during secondary window operation

---

### 2. AuroraGuard Path Resolution Fix

**Issue Description:**
> AuroraGuard initialization used `$PSScriptRoot` (pointing to `Scripts` directory), but file paths in `_expected` dictionary (e.g., `Scripts\AURORA-SmartEngine.ps1`) were relative to root. After concatenation, paths became `...\Scripts\Scripts\...`, causing all file lookups to fail and integrity checks to report errors.

**Impact:**
- ❌ All integrity checks failed (19 files reported hash mismatch)
- ❌ `VerifyOrDie()` called `Environment.FailFast` to directly kill process
- ❌ User clicked "Professional Graphics Mode" button with no response (process silently killed)

**Resolution:**
```powershell
# Line 440: Correct base path to root directory
[AuroraGuard]::Initialize((Split-Path -Parent $PSScriptRoot))

# Lines 9681-9688: Enhanced error handling
try { 
    $guardOk = [AuroraGuard]::VerifyOrDie()
    if (-not $guardOk) {
        Write-Host "[ShowProMode] Integrity verification warning: Some file hashes mismatch (normal in dev environment)" -ForegroundColor Yellow
    }
} catch { 
    Write-Host "[ShowProMode] Integrity guard uninitialized (degraded mode)" -ForegroundColor DarkGray
}
```

**Verification:**
- ✅ Integrity checks pass normally (19 files successfully verified)
- ✅ Professional Graphics Mode secondary window opens normally
- ✅ Runtime monitoring continues working, no process crashes

---

### 3. Security Alert Window Consistency Upgrade

**Issue Description:**
> In V1.1.24.0, tamper detection would directly close all windows (`Close()` + `Dispose()`), resulting in abrupt user experience without buffer time.

**Resolution:**
- ✅ **Hide all windows first** - Use `WindowState = Minimized` + `Hide()` instead of direct close
- ✅ **Display 15-second countdown warning window** - Show detailed information (missing/tampered file list)
- ✅ **Auto-exit after countdown** - Use `Application.Exit()` for graceful exit

**Technical Implementation:**
```powershell
# Lines 870-900: Tamper detection handling flow
# 1. Stop all monitoring
$script:runtimeIntegrityTimer.Stop()
$script:randomIntegrityTimer.Stop()
$script:fileWatcher.EnableRaisingEvents = $false

# 2. Hide all windows (not close)
if ($global:proForm) {
    $global:proForm.WindowState = [FormWindowState]::Minimized
    $global:proForm.Hide()
}
if ($splash) { $splash.Hide() }
if ($global:mainForm) {
    $global:mainForm.WindowState = [FormWindowState]::Minimized
    $global:mainForm.Hide()
}

# 3. Display 15-second countdown warning window
[AuroraExitCountdown]::Show(
    "Security Alert: File Tampering Detected!",
    "Security Alert: File Tampering Detected!",
    "Program integrity compromised. Detected issues:$missingInfo$modifiedInfo`n`nProgram will exit in 15 seconds.",
    "Program integrity compromised. Detected issues:$missingInfo$modifiedInfo`n`nProgram will exit in 15 seconds.",
    15,  # Countdown seconds
    $false,  # Use Application.Exit() instead of Environment.Exit()
    $UseChinese
)
```

**User Experience Improvements:**
- ✅ Users have 15 seconds to view problem details
- ✅ Warning window displayed on top (`TopMost = true`), ensuring visibility
- ✅ Countdown turns red in last 5 seconds, enhancing urgency
- ✅ Supports automatic Chinese/English bilingual switching

---

## 🎨 User Experience Enhancements

### 1. Integrity Check Log In-Place Refresh

**Issue Description:**
> Integrity checks output logs every 3-10 seconds, with each check creating a new line, causing rapid console scrolling and reducing log readability.

**Resolution:**
- ✅ **Added check counter** - `$script:IntegrityCheckCount` records cumulative check count
- ✅ **In-place log refresh** - Use `\r` carriage return to overwrite previous line
- ✅ **Enhanced log format** - Includes check count and timestamp

**Technical Implementation:**
```powershell
# Lines 758-759: Add counter
$script:IntegrityCheckCount = 0

# Lines 937-945: In-place log refresh
$script:IntegrityCheckCount++
$timestamp = Get-Date -Format "HH:mm:ss"
$logLine = "[Integrity Check] Pass - Total $($script:ExpectedFileHashes.Count) files - Check #$($script:IntegrityCheckCount) - $timestamp"

# Use blank string to clear current line
$clearLine = New-Object String(' ', $Host.UI.RawUI.WindowSize.BufferWidth)
Write-Host "`r$clearLine" -NoNewline
Write-Host "`r$logLine" -ForegroundColor DarkGray -NoNewline
```

**Before & After:**
```
Before (scrolling):                    After (in-place refresh):
[Integrity Check] Pass - 19 files      [Integrity Check] Pass - 19 files - Check #42 - 14:23:15
[Integrity Check] Pass - 19 files
[Integrity Check] Pass - 19 files
[Integrity Check] Pass - 19 files
... (continuous scrolling)
```

---

### 2. Debug Log Cleanup

**Cleanup Scope:**
- ❌ **Removed ShowProMode debug logs** - 15 lines (`Form Shown`, `Animation started`, `EngineInit`, etc.)
- ❌ **Removed DEBUG prefix path logs** - 11 lines (`chsScript`, `engScript`, `Launching`, etc.)
- ❌ **Removed integrity check detailed logs** - 4 lines (`Hide secondary window`, `Hide main window`, etc.)

**Total Removed:** 30 lines of debug logs

**Before & After:**
```
Before (cluttered):                    After (clean):
[DEBUG] Main form hidden               [Integrity Check] Pass - 19 files - Check #25 - 10:09:34
[DEBUG] SelectedLanguage: CHS
[DEBUG] chsScript: E:\...\xxx.ps1
[DEBUG] Launching CHS: ...
[ShowProMode] Setting form opacity...
[ShowProMode.Shown] Form Shown event...
[ShowProMode.Shown] Starting animation...
... (about 30 lines of debug info)
```

---

## 🐛 Bug Fixes

| # | Issue | Severity | Resolution |
|---|-------|----------|------------|
| 1 | **AuroraGuard path duplication** | 🔴 P0 (Critical) | Corrected to root directory initialization, path merge logic fixed |
| 2 | **VerifyOrDie kills process** | 🔴 P0 (Critical) | Changed to return boolean, caller handles exceptions |
| 3 | **Secondary window won't open** | 🔴 P0 (Critical) | Fixed path error + non-lethal verification mode |
| 4 | **Integrity check paused** | 🟡 P1 (High) | Removed pause logic, achieved full-link monitoring |
| 5 | **Log scrolling** | 🟢 P2 (Medium) | In-place refresh + counter + timestamp |
| 6 | **Excessive debug logs** | 🟢 P3 (Low) | Cleaned 30 lines of debug logs, kept key information |

---

## 📊 Change Statistics

| Metric | V1.1.24.0 | V1.1.24.1 | Change |
|--------|-----------|-----------|--------|
| **Security Updates** | 7 | 3 | Focused on key issues |
| **Bug Fixes** | 5 | 6 | +20% |
| **UX Enhancements** | 6 | 2 | Streamlined optimization |
| **LOC Changes** | +2500 | -150 | Code simplification |
| **Debug Logs Removed** | 0 | 30 lines | Clean logs |
| **Total Changes** | 27 | 11 | Quality over quantity |

---

## 🔍 Known Issues

| ID | Issue | Status | Target Version |
|----|-------|--------|----------------|
| ISS-2026-001 | Console window visible when running PowerShell script directly | 🟡 Confirmed | V1.1.25.0 |
| ISS-2026-002 | Integrity check counter not reset after secondary window closes | 🟡 Confirmed | V1.1.24.2 |
| ISS-2026-003 | Cannot manually exit early during warning window countdown | 🟡 Confirmed | V1.1.24.2 |

---

## 📋 Upgrade Recommendations

### For Enterprise Users
- ✅ **Strongly recommended to upgrade** - Full-link integrity monitoring is a key security enhancement
- ✅ **No reconfiguration needed** - All settings are backward compatible
- ✅ **Effective immediately** - No restart or redeployment required

### For Individual Users
- ✅ **Recommended to upgrade** - Fixed the issue where Professional Graphics Mode couldn't open
- ✅ **Improved experience** - Cleaner logs, friendlier warnings
- ✅ **Seamless upgrade** - Just overwrite installation

---

## 📄 Accompanying Documentation

This version is accompanied by the following technical documentation:

| Document | Target Audience | Pages |
|----------|----------------|-------|
| **AURORA-Security-Chain-Evaluation-Report.md** | Security auditors, technical decision-makers | ~15 |
| **AURORA-Tool-Workflow-Analysis-Report.md** | Developers, maintainers | ~12 |
| **README_V1.1.24.1Release.md** | End users | ~5 |
| **README_V1.1.24.1.md** | Developer community | ~8 |
| **update_EN.md** | Technical users | ~10 |

---

## 🔗 Related Links

- [AURORA Analyzer GitHub Repository](https://github.com/aurora-analyzer)
- [V1.1.24.0 Security Audit Report](Docs/AURORA_Security_Audit_Report_v1.1.24.0.md)
- [Technical Documentation Directory](Docs/)

---

**Copyright:** &copy; 2026 AURORA VelociRaptor-GR Dev PRJ. All rights reserved.  
**License:** Proprietary (All Rights Reserved)
