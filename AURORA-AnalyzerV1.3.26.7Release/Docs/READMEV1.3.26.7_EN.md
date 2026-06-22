# AURORA Analyzer

> **Windows Event Log Export & Smart Diagnostic Analysis Tool**
>
> Version: V1.3.26.7 Release · Build Date: 2026.06.16
>
> Tech Stack: PowerShell 5.1 + .NET Framework 4.x + C#
>
> Author: AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ This tool is for personal learning use only. Please comply with local laws and regulations.

---

## Introduction

AURORA Analyzer is a system event log export and intelligent diagnostic analysis tool designed for the Windows platform. It automatically collects and exports over ten types of Windows event logs, then performs in-depth analysis using a built-in knowledge graph-driven diagnostic engine that connects seemingly unrelated events into complete cause-and-effect chains — ultimately telling you "what happened" and "how to fix it."

Whether you are a casual computer user or a professional system administrator, AURORA Analyzer provides powerful yet accessible diagnostic capabilities.

## Key Features

### Smart Diagnosis

- **Knowledge Graph Powered** — Rich built-in diagnostic rule base supporting event ID matching, severity scoring (1-10), and cause-effect analysis
- **Multi-Dimensional Scanning** — System file integrity, service status, registry health, disk I/O, memory & CPU, network configuration, event logs
- **One-Click Repair** — Automatically executes repairs after diagnosis, creating System Restore points and quick backup snapshots before each repair
- **Undo Management** — All repair operations are reversible with precise rollback to pre-operation state

### PRO Graphical Mode

- **Multi-Format Log Export** — CSV / JSON / XML / TXT output formats
- **Trend Analysis** — Time-series trend visualization with auto-generated trend data
- **Multi-Source Log Comparison** — Simultaneous analysis of system, application, security logs, and more
- **Interactive Filtering** — Flexible filtering by event level, source, and time range

### System Repair Toolkit

- Enhanced SFC, DISM image repair, disk error repair, network configuration reset
- Windows Update fix, Storage Sense optimization, registry repair, power plan optimization
- Custom operations (command whitelist mode)
- Automatic System Restore point and quick backup snapshot creation before each repair

### Session Resume

- Automatic persistence of diagnosis/repair progress
- Resume from interruption point after unexpected termination
- Displays interruption days to help users make informed decisions

### Security Mechanisms

- **RSA-2048 Signature Verification** — Automatic verification of all core module file integrity on startup
- **Runtime Guard** — Continuous monitoring for debuggers, reverse engineering tools, memory tampering, and code injection
- **Watchdog Heartbeat** — Communication with external watchdog process
- **Elevation Security Tokens** — AES-256-CBC encrypted recovery chain for UAC elevation scenarios
- **Two-Stage Security Architecture** — Security module itself verified through cryptographically signed CHK.ENC file
- **Command Whitelist** — Custom repair mode eliminates code injection risk

### User Experience

- **Modern GUI** — Dynamic starfield background, ripple feedback, magnetic buttons, particle progress bar
- **Bilingual** — Simplified Chinese / English with runtime dynamic switching
- **Performance Adaptive** — Automatically selects Extreme/Performance/Balanced/Eco mode based on hardware
- **Session Resume** — Progress persistence with recovery after unexpected interruption

## Architecture Overview

AURORA Analyzer uses a modular architecture with 9 clear module layers:

```
Scripts/
├── Core/          ← Core Engine (animation engine, shared utilities, infrastructure)
├── Security/      ← Security Module (RSA verification, runtime guard, watchdog)
├── UI/
│   ├── Controls/  ← Control Library (custom UI controls, animation library)
│   └── Views/     ← Views (main interface, PRO interface, splash screen, dialogs)
├── Engines/       ← Smart Engine (intelligent diagnostic engine)
├── PRO/           ← PRO Mode (PRO engine and entry point)
├── Session/       ← Session Management (progress persistence, undo management)
├── Repair/        ← Repair Tools (repair tools, repair logger, restore manager)
└── GUI/           ← GUI Helpers (GUI utility functions, language resources)
```

Each module is loaded on-demand, has a single responsibility, well-defined interfaces, and supports independent maintenance and extension.

## V1.3.26.7 Highlights

V1.3.26.7 is a quality-centric comprehensive fix release addressing 53 issues (18 Critical + 35 High):

### Critical Fixes

- **Integrity Monitoring** — Changed from FileSystemWatcher event subscription to timer-polling approach, fixing the monitor filter mismatch that caused monitoring to be completely non-functional. Added 64KB buffer and concurrent lock protection.
- **Registry Restoration** — Fixed missing PassThru parameter in Start-Process that caused the registry restoration feature to never work correctly.
- **CleanSystem Repair** — Fixed use of invalid cmdlet that caused the system cleanup feature to be completely non-functional.
- **Code Injection Prevention** — Custom repair mode changed from Invoke-Expression to a command whitelist mapping table.
- **PRO Parameter Passing** — Fixed PRO engine parameters not being passed from the entry point, causing all user selections to be ignored.
- **Function Signature Conflict** — Fixed PRO engine and CoreEngine functions with the same name but different signatures. Renamed with PRO prefix and updated all 11 call sites.
- **Atomic Write** — Changed from delete-then-move to File.Replace for true atomic replacement, with retry and backup mechanisms.
- **CSV Column Misalignment** — Data column changed from conditional to always-present, fixing dynamic column misalignment.
- **Log Output Restored** — Fixed Write-SmartLog extra parameter causing log output to fail completely.
- **Health Level Localization** — Hardcoded Chinese text replaced with language resource file lookups.

### Security Enhancements

- SecurityModule added to integrity monitoring (two-stage architecture + CHK.ENC signature verification)
- IO exception changed from cache fallback to secure-fail mode
- Watchdog cleanup added to abnormal exit path
- Backup snapshot ID correctly propagated, undo function no longer loses backup information

### Code Quality

- Eliminated `return if (...)` illegal syntax
- Fixed multiple undefined variable issues: `$techData`, `$lightEvents`, `$dragAction`, etc.
- Removed `#requires -RunAsAdministrator` in favor of runtime checks
- Eliminated function redefinitions
- CoreEngine and SecurityModule imported earlier in PRO entry point

See [UpdateV1.3.26.7Release.md](UpdateV1.3.26.7Release.md) (Chinese) and [UpdateV1.3.26.7Release_EN.md](UpdateV1.3.26.7Release_EN.md) (English) for full details.

## Quick Start

### Recommended

Double-click `AURORA-Analyzer.exe`. The program completes security verification and performance detection automatically before entering the main interface.

### Console

```powershell
.\Scripts\AURORA-AnalyzerLauncherGUI.ps1
```

### With Language

```powershell
.\Scripts\AURORA-AnalyzerLauncherGUI.ps1 -Language "en-US"
```

## System Requirements

| Item | Minimum | Recommended |
|------|---------|-------------|
| Operating System | Windows 10 1809+ | Windows 11 22H2+ |
| Processor | Dual-core 1.5 GHz | Quad-core 2.5 GHz+ |
| Memory | 4 GB | 8 GB+ |
| Architecture | x64 (required) | x64 |
| .NET Framework | 4.x | 4.8 |
| PowerShell | 5.1 | 5.1 |

## Build Instructions

Use the `build.ps1` script in the project root directory:

```powershell
.\build.ps1
```

The build script performs the following:

- Injects version number into all .ps1 files
- Computes SHA-256 hashes for all core modules
- Generates RSA-signed GAURORA.CHK.ENC integrity verification database
- Builds AURORA-Analyzer.exe using C# compiler (with CRC32 self-check)
- Secure memory cleanup (zeroing key variables)

## Project Structure

| Directory | Description |
|-----------|-------------|
| `Scripts/` | Core script modules (25 independent module files) |
| `Data/` | Diagnostic knowledge graph and technical data cache |
| `Resources/` | Icons, fonts, and other resource files |
| `Tests/` | Unit tests and integration test scripts |
| `Docs/` | Architecture documents and audit reports |
| `FixPlan/` | Code audit reports and fix plan documents |

## Documentation

- [V1.3.26.7 User Manual (Chinese)](ReadmeV1.3.26.7Release.md)
- [V1.3.26.7 User Manual (English)](ReadmeV1.3.26.7Release_EN.md)
- [V1.3.26.7 Release Notes (Chinese)](UpdateV1.3.26.7Release.md)
- [V1.3.26.7 Release Notes (English)](UpdateV1.3.26.7Release_EN.md)
- [Final Fix Plan](FixPlan/AURORA-Final-Fix-Plan.md)
- [Fix Verification Report](FixPlan/AURORA-Fix-Verification-Report.md)
- [Fix Side-Effect Analysis](FixPlan/AURORA-Fix-SideEffect-Analysis.md)
- [Remaining Issues Assessment](AURORA-Remaining-Issues-Assessment.md)

## Version History

| Version | Date | Codename | Key Updates |
|---------|------|----------|-------------|
| **V1.3.26.7** | 2026.06.16 | Comprehensive Quality Release | 53 fixes: integrity monitoring, registry restoration, PRO parameter passing, code injection prevention, atomic write |
| V1.3.26.6 | 2026.06.08 | Architectural Quality Polish | Error handling convention, Timer lifecycle management, safe exit mechanism, structured telemetry |
| V1.3.26.5 | 2026.06.08 | Complete Architectural Decoupling | Modular architecture refactoring, 9 layers / 25 files, security module independence, view separation |
| V1.2.25.0 | 2026.06.02 | GUI Animation Overhaul | Ripple feedback, magnetic buttons, smooth progress bar, easing library expanded to 20 curves |
| V1.1.24.5 | 2026.05 | Starlight | Starfield background, light sweep animation, particle progress bar |
| V1.0.0.0 | Early 2026 | First Light | Initial release: smart diagnosis + basic repair features |

## License

This tool is provided "AS IS" for personal learning and research use only.

**Terms of Use:**

- Do not use for any unauthorized system operations or in violation of local laws and regulations
- System repair operations may affect system stability. Please back up important data before performing repairs.
- The author is not responsible for any direct or indirect damages resulting from the use of this tool.
- Exported event logs may contain sensitive information. Please handle them carefully.

## Acknowledgments

Thank you to all users who have provided feedback, reported bugs, and suggested features.

---

*AURORA VelociRaptor-GR Dev PRJ. · V1.3.26.7 Release · 2026.06.16*