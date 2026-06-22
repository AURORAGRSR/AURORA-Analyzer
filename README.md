# AURORA Analyzer V1.3.26.7 Release Notes

> **Windows Event Log Export & Smart Diagnostic Tool**
>
> Version: V1.3.26.7Release · Build Date: 2026.06.16 · Author: AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **WARNING**: This tool is for personal learning use only. Please comply with local laws and regulations.

***

## Table of Contents

1. [Version Overview](#1-version-overview)
2. [Critical Functional Fixes](#2-critical-functional-fixes)
3. [Security & Integrity Enhancements](#3-security--integrity-enhancements)
4. [Architecture & Code Quality Improvements](#4-architecture--code-quality-improvements)
5. [UI Experience Improvements](#5-ui-experience-improvements)
6. [PRO Mode Improvements](#6-pro-mode-improvements)
7. [Build System Improvements](#7-build-system-improvements)
8. [Fixed Issues Checklist](#8-fixed-issues-checklist)

***

## 1. Version Overview

V1.3.26.7 is a comprehensive quality improvement release built on top of V1.3.26.6. In V1.3.26.6, the project completed foundational architectural refinements including error handling conventions, resource lifecycle management, and structured observability. V1.3.26.7 focuses on eliminating critical functional defects, security vulnerabilities, and logical errors across all core modules through deep review and remediation.

This release addresses 53 issues, including 18 Critical-level and 35 High-level problems. The fix scope covers the integrity monitoring system, registry restoration, CleanSystem repair, PRO engine parameter passing, function signature conflicts, CSV log column misalignment, atomic write reliability, and code injection in custom repair operations. These fixes significantly improve the system's functional correctness, security, and stability.

Additionally, this release includes several code structure improvements, such as splitting multiple View dialogs and controls into independent files to enhance maintainability, eliminating multiple function redefinitions, and fixing several uninitialized variable runtime exceptions. V1.3.26.7 is a fix-centric quality release, and we recommend all users upgrade.

***

## 2. Critical Functional Fixes

### Integrity Monitoring System Fix

In previous versions, the file integrity monitoring feature was completely non-functional. The root cause was that .NET's `FileSystemWatcher.Filter` property does not support comma-separated multiple file extension patterns, yet the original code set the filter to `"*.ps1,*.json,*.xml,*.ico,*.exe,*.enc"`, which matched zero files — integrity monitoring never detected any file changes. In V1.3.26.7, the monitoring strategy has been changed from direct FileSystemWatcher event subscription to a timer-based polling approach combined with unauthorized file scanning. This approach is more stable and reliable, avoiding PowerShell Runspace issues when script blocks run on IOCP threads. A 64KB internal buffer, anti-self-trigger flag, and concurrent lock protection have also been added to prevent event storms and concurrent integrity checks caused by high-frequency file operations.

### Registry Restoration Fix

In V1.3.26.6 and earlier versions, the registry undo operation had a critical null reference exception defect. When calling `reg.exe import` to execute registry restoration, the `Start-Process` command was missing the `-PassThru` parameter, causing the returned process object to always be null. When subsequent code attempted to access `$process.ExitCode` to determine whether the restoration succeeded, a null reference exception was inevitable. This means the registry restoration feature never worked correctly. The fix adds the `-PassThru` parameter, ensuring the process object is properly returned and the exit code can be correctly obtained. Registry restoration now functions as intended.

### CleanSystem Repair Functionality Restored

The CleanSystem repair type was completely non-functional in previous versions because the code used `Remove-Force`, which is not a valid PowerShell command. The correct command in PowerShell is `Remove-Item -Force`. The fixed code uses a two-step approach — deleting directories first, then files — which avoids the "directory not empty" errors caused by pipeline-based recursive deletion. The system cleanup feature now correctly removes temporary files from the TEMP directory.

### Custom Repair Code Injection Vulnerability Fix

The custom repair mode previously used `Invoke-Expression` to execute user-specified command strings, which is a serious code injection vulnerability. An attacker could execute arbitrary PowerShell code by passing a maliciously crafted Target parameter. V1.3.26.7 replaces dynamic execution with a command whitelist mapping table, currently supporting six safe commands: clearing event logs, resetting the network stack, flushing DNS cache, repairing system files, cleaning temporary files, and resetting Windows Store. Commands outside the whitelist are rejected with a list of supported commands displayed. This fundamentally eliminates the code injection risk.

***

## 3. Security & Integrity Enhancements

### SecurityModule Added to Integrity Hash List

The original integrity check mechanism had a logical flaw — the list of files being checked did not include the security module itself, which performs the checking. This meant an attacker could modify the security module's code without being detected. V1.3.26.7 introduces a two-stage security architecture that stores the SecurityModule's hash in a cryptographically signed CHK.ENC file. When the EXE guard starts, it first reads and verifies the signature and hash in CHK.ENC, then performs the integrity check on SecurityModule.ps1, ensuring the reliability of the entire security check chain.

### Backup Snapshot ID Correctly Propagated

When a repair session completes, the previous version did not pass the backup snapshot ID to the `Complete-RepairSession` function. If a system snapshot was created before the repair, the snapshot ID would be lost, making the subsequent undo function unable to associate with the correct backup. The fixed code correctly passes `$session.BackupSnapshotId`, ensuring snapshot association information is not lost throughout the repair workflow.

### IO Exception Security Failure

When the integrity check encountered IO exceptions (such as file locks or disk errors), the original code fell back to the cached result from the previous check. This meant an attacker could bypass integrity verification by制造ing IO errors — as long as the previous check result was "normal," the check would pass even if files had been tampered with. V1.3.26.7 changes the IO exception scenario to a secure-fail mode: when uncertain, the check directly判定s verification as failed and triggers a security alert, no longer relying on stale cache results.

### Watchdog Cleanup Added to Abnormal Exit Path

In previous versions, if the program exited urgently through `Invoke-SafeExit` due to security events like integrity check failure or debugger detection, cleanup code for watchdog timers, file monitors, Runspaces, PowerShell instances, and WMI event subscriptions would be skipped. These residual resources could cause resource leaks and prevent the process from exiting properly. V1.3.26.7 adds complete resource cleanup logic to the `Invoke-SafeExit` function, ensuring all resources are properly released regardless of how the program exits. Additionally, the exit cleanup chain in LauncherGUI has been comprehensively enhanced, including environment variable cleanup, Runspace cleanup, PowerShell instance cleanup, pipe cleanup, and WMI event subscription cleanup.

***

## 4. Architecture & Code Quality Improvements

### Function Signature Conflict Fix

Two functions in the PRO engine (`New-StreamWriterOperation` and `Get-SafeFilePath`) had completely different signatures from their namesakes in CoreEngine, but they loaded in the same script scope, with the later-loaded version completely overriding the earlier one. This meant code calling the CoreEngine version actually executed the PRO version, passing wrong parameter types and causing runtime exceptions. V1.3.26.7 renames the PRO engine's two functions to `New-PROStreamWriterOperation` and `Get-PROSafeFilePath`, and updates all 11 call sites within the PRO engine. After the fix, CoreEngine's original function versions are restored, and external callers are no longer affected.

### `return if (...)` Syntax Fix

In two restoration management functions, the original code used the syntax `return if (...) { valueA } else { valueB }`, which is illegal in PowerShell — the `return` keyword must be followed by an expression or statement block. This caused both functions to always return null, leaving restore point type and error information permanently blank. The fix changes this to the standard `if (...) { return valueA } else { return valueB }` pattern, and the functions now correctly return their values.

### CSV Log Column Misalignment Fix

The structured logging system's CSV export had a column misalignment issue. In the original code, the `Data` column was conditional — it was only added to the log entry when the `$Data` parameter existed. The `Export-Csv -Append` command writes data according to the file's existing column headers, so if the first write did not have a Data column, subsequent writes with Data would write data into the wrong columns. V1.3.26.7 makes the Data column always present (writing an empty string when there's no data), ensuring the column structure is fixed from the first write and subsequent appended data will not be misaligned.

### Atomic Write Reliability Fix

The "atomic write" implementation for session saving had a data loss risk. The original code deleted the target file first, then moved the temp file — if the process crashed between the delete and move operations, the file would be permanently lost. Additionally, the original fix plan used `File.Move` to achieve overwriting, but in .NET Framework 4.x, `File.Move` throws an `IOException` when the target file exists — it does not automatically overwrite. V1.3.26.7 uses `[System.IO.File]::Replace()` for true atomic replacement. This method is atomic on the same volume and preserves the target file's metadata. A `FileNotFoundException` fallback (for first-time writes when the target doesn't exist) and a retry mechanism with a backup suffix have been added, ensuring session data is never lost or corrupted under any circumstances.

### Multiple Uninitialized Variable Fixes

Several runtime exceptions caused by undefined variables have been fixed. `$techData` was accessed in the cache hit path but never defined, causing the knowledge graph cache to always fail — now it reads the version number directly from `version.txt` for comparison. `$lightEvents` was uninitialized in strict mode, causing errors — now initialized with `@()`. `$dragAction` was undefined before mouse event binding, causing the window drag feature to fail — the definition has been moved before its first use.

### Admin Check Parameter Passing Fix

The `Test-AdminRequired` function requires a `$LogType` parameter by definition, but the call site passed no arguments, causing the admin privilege check to crash. V1.3.26.7 corrects the parameter passing at the call site. Additionally, the `Log-RepairCommand` function had a parameter name mismatch — the caller used `-CommandType` while the function definition expects `-Command` — this has been corrected to the proper parameter name, and repair operation logs now record correctly.

***

## 5. UI Experience Improvements

### Write-SmartLog Log Output Restored

Ten call sites in SmartEngine passed a `-ForegroundColor` parameter to `Write-SmartLog`, but the function only accepts `$Message` and `$Status` parameters. The extra parameter caused PowerShell to throw a `ParameterBindingException`, resulting in logs never being output. The fix removes all extra `-ForegroundColor` parameters, and SmartEngine's log output now displays correctly in the GUI's log area. This is a pure gain fix — the blank log output users saw in V1.3.26.6 will be restored to normal in V1.3.26.7.

### Function Redefinition Elimination

The `Start-UwpExitAnimation` function was defined twice in AURORA-Animations.ps1, with the later-loaded definition overriding the former, leading to unpredictable behavior. V1.3.26.7 removes the first redundant definition, ensuring each function has only one implementation and eliminating behavioral uncertainty.

### Elevation Dialog Drag Functionality Fix

The drag-to-move functionality of the elevation/restore dialogs was broken because the `$dragAction` variable was defined after its use. The fix moves the drag operation definition before the control binding, and dialogs can now be dragged normally.

### `#requires -RunAsAdministrator` Removal

The `#requires -RunAsAdministrator` directive in RestoreManager.ps1 would terminate script loading immediately in non-admin environments, leaving users without any friendly error message. V1.3.26.7 removes this directive and replaces it with a runtime admin check at the caller (RepairLogger.ps1), displaying a friendly warning message on load failure. This way, users starting in a non-admin environment see a clear "insufficient privileges" message rather than a direct crash.

***

## 6. PRO Mode Improvements

### PRO Engine Parameter Passing Fix

In V1.3.26.6, when the PRO entry point (AnalyzerPRO.ps1) loaded the PRO engine via dot-source, none of the command-line parameters (Language, LogType, EventId, StartTime, EndTime, etc.) were passed into the engine — it always ran with default values. This means all user selections made through the GUI — language, log type, time range — were completely ignored. V1.3.26.7 sets `$script:PRO_*` series script-level variables in the entry point file, and the PRO engine reads parameters from these variables upon loading, with reasonable default values as fallback. The PRO engine's internal startup guard check and language variable assignment have also been synchronized.

### Health Level Text Localization

In the PRO mode health assessment feature, level texts such as "优秀" (Excellent), "良好" (Good), "一般" (Fair), "较差" (Poor), and their corresponding status descriptions were all hardcoded in Chinese. In English mode, users still saw Chinese health level text — localization was completely ineffective. V1.3.26.7 adds health level key-value pairs in both Chinese and English to the language resource file (Language.psd1), and all hardcoded strings in the PRO engine have been replaced with values fetched from `$script:Loc`. Health level text now correctly follows the language setting when switching between Chinese and English.

### CoreEngine Imported Earlier

In the PRO entry point, the startup detection code called the `Invoke-SafeExit` function, but CoreEngine — which defines this function — was imported after the detection code. If startup detection triggered (e.g., illegal direct execution), the program would throw a "command not found" exception instead of displaying a friendly error message. V1.3.26.7 moves the CoreEngine import before the startup detection, ensuring all necessary functions are available before detection executes.

### SecurityModule Imported Earlier

The PRO entry point's RSA token verification called `Test-RSATokenSignature`, but the SecurityModule that defines this function was never imported. V1.3.26.7 imports SecurityModule before the startup detection, ensuring RSA token verification functions correctly.

***

## 7. Build System Improvements

### CRC32 Self-Check Embedding Fix

The CRC32 self-check value embedding logic in the build script had a defect: the placeholder string used for replacement might not exist in the C# template, causing the replace operation to do nothing — the EXE would always embed the default `0x00000000` value, making the CRC self-check feature completely non-functional. V1.3.26.7 corrects the CRC32 algorithm implementation to use the standard polynomial `0xEDB88320` for calculation and confirms the placeholder's existence.

### LauncherGUI Added to Integrity Monitoring

The integrity hash list in previous versions was missing the main launcher file (AURORA-AnalyzerLauncherGUI.ps1), meaning modifications to the launcher would not be detected by the C# integrity guard. V1.3.26.7 has added LauncherGUI to the build script's guard target file list, ensuring the integrity of the entire program chain can be monitored.

### Code Structure Optimization

V1.3.26.7 includes several code structure optimizations. Multiple View dialogs (elevation dialog, permission info dialog, session restore dialog, etc.) and UI controls have been split from the main launcher file into independent module files, improving code maintainability and readability. These splits do not affect any functional behavior — they purely improve code organization.

***

## 8. Fixed Issues Checklist

| ID    | Level | Issue Description                                                                                            | Fix                                                         |
| ----- | ----- | ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------- |
| P0-1  | P0    | FileSystemWatcher Filter doesn't support comma-separated multi-patterns, integrity monitoring non-functional | Changed to timer polling + concurrent lock + 64KB buffer    |
| P0-2  | P0    | Start-Process missing -PassThru, registry restoration $process always null                                   | Added -PassThru parameter                                   |
| P0-3  | P0    | Remove-Force is not a valid cmdlet, CleanSystem repair completely broken                                     | Changed to Remove-Item -Force, directories first then files |
| P0-4  | P0    | Complete-RepairSession not passing BackupSnapshotId, undo loses backup info                                  | Pass $session.BackupSnapshotId                              |
| P0-5  | P0    | return if (...) is illegal syntax in PowerShell, functions always return null                                | Changed to if (...) { return ... } else { return ... }      |
| P0-6  | P0    | #requires -RunAsAdministrator causes direct crash without message for non-admin                              | Removed directive, changed to runtime check                 |
| P0-7  | P0    | PRO entry point parameters not passed to engine, all user selections ignored                                 | $script:PRO\_\* variable passing + synchronized guard check |
| P0-8  | P0    | New-StreamWriterOperation / Get-SafeFilePath function signature conflicts                                    | Renamed with PRO prefix + 11 call sites fully updated       |
| P0-9  | P0    | CRC32 placeholder replacement failed, EXE always embeds default value                                        | Corrected algorithm + confirmed placeholder exists          |
| P0-10 | P0    | Integrity hash list excludes SecurityModule itself                                                           | Two-stage architecture + CHK.ENC signature verification     |
| P1-1  | P1    | CSV columns depend on first write, dynamic columns cause misalignment                                        | Data column always present                                  |
| P1-2  | P1    | $techData undefined causing cache hit path crash                                                             | Read version number from version.txt                        |
| P1-3  | P1    | GUI authorization wait has no timeout dead loop                                                              | Added 60-second timeout, default deny                       |
| P1-4  | P1    | $dragAction undefined before use                                                                             | Definition moved before first use                           |
| P1-5  | P1    | Start-UwpExitAnimation function defined twice                                                                | Removed first redundant definition                          |
| P1-6  | P1    | Test-AdminRequired call missing parameter                                                                    | Added -LogType parameter                                    |
| P1-7  | P1    | Log-RepairCommand parameter name mismatch                                                                    | Corrected to -Command + -Parameters                         |
| P1-8  | P1    | Atomic write delete-then-move not atomic, File.Move throws on existing target                                | Changed to File.Replace + FileNotFoundException fallback    |
| P1-10 | P1    | Health level text hardcoded in Chinese                                                                       | Added language keys + $script:Loc retrieval                 |
| P1-12 | P1    | SecurityModule never imported in PRO entry point                                                             | Imported before startup detection                           |
| P1-13 | P1    | Custom mode Invoke-Expression has code injection vulnerability                                               | Command whitelist mapping table replacement                 |
| P1-14 | P1    | Write-SmartLog extra -ForegroundColor causes log output failure                                              | Removed extra parameters                                    |
| P1-15 | P1    | $lightEvents uninitialized                                                                                   | Added @() initialization                                    |
| P1-16 | P1    | IO exception fallback to cache exploitable by attacker                                                       | Return false triggering security alert                      |
| C13   | P0    | Invoke-SafeExit called before CoreEngine import                                                              | CoreEngine imported earlier                                 |
| H36   | P2    | Watchdog cleanup not in abnormal exit path                                                                   | Invoke-SafeExit adds complete cleanup chain                 |

***

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *This tool is for personal learning use only. Please comply with local laws and regulations.*

