# AURORA Analyzer V1.2.25.0Release — User Manual

> **Version**: V1.2.25.0 Release
> **Build**: 2026.06.02
> **Codename**: GUI Animation System Overhaul
> **Platform**: Windows 10 / 11 / Windows Server 2019+

---

## Quick Start

### First Time?

1. **Double-click** `AURORA-Analyzer.exe`
2. The tool automatically completes security verification and performance detection
3. In the clean graphical interface, select the function you need

### Feature Overview

| Feature | Description | For |
|---------|-------------|-----|
| Smart Diagnostics | One-click system scan with auto repair suggestions | All users |
| System Repair | Multiple repair tools with undo support | All users |
| System Optimization | Optimize system performance, boost speed | Advanced users |
| PRO Graphical Mode | Professional-grade visual tools, advanced diagnostics | Power users |
| Console Mode | Quick command-line diagnostics, lightweight | Developers |

---

## What's New — GUI Animation System Overhaul

V1.2.25.0 is a **major visual experience upgrade**. We've redesigned all button interaction animations for a smoother, more premium feel.

### New Features

#### 1. Ripple Click Feedback
When you click a button, a beautiful cyan ripple spreads outward from the click point — delivering a refined Material Design touch sensation.

#### 2. Magnetic Snap Buttons
As you move your mouse over buttons, they subtly lean toward the cursor like a magnet, giving you a pleasing "sticky" tactile feel. This is the macOS Dock-style interaction effect.

#### 3. Smooth Progress Bar Transitions
Progress bars no longer jump abruptly — they now glide smoothly to the target value with silky animations, making the visual experience much more comfortable.

#### 4. Expanded Animation Curves
The underlying animation engine has been expanded from 4 to 20 easing curves, laying the foundation for even more animation upgrades in the future.

#### 5. Performance Optimization
In Eco performance mode, CPU usage is reduced by approximately 50%, ensuring smooth operation even on low-end machines.

---

## System Requirements

| Item | Minimum | Recommended |
|------|---------|-------------|
| OS | Windows 10 1809+ | Windows 11 22H2+ |
| Processor | Dual-core 1.5GHz | Quad-core 2.5GHz+ |
| RAM | 4 GB | 8 GB+ |
| Architecture | x64 | x64 |
| .NET Framework | 4.x | 4.8 |
| PowerShell | 5.1 | 5.1 |

---

## Usage Guide

### Smart Diagnostics Mode

1. After launching, click **"Smart Diagnostics"**
2. The tool automatically scans your system, including:
   - System file integrity
   - Service status
   - Registry health
   - Disk space usage
   - Memory & CPU status
3. Review the diagnostic report after the scan
4. Select items to repair based on suggestions

### PRO Graphical Mode

PRO mode provides professional-grade visual diagnostic tools:

1. Select **"PRO Graphical Mode"** from the launch screen
2. Choose diagnostic modules from the left panel
3. View real-time data visualization on the right
4. Export diagnostic reports as needed

### Console Mode

For developers or quick diagnostics:

```powershell
.\AURORA-AnalyzerLauncherGUI.ps1 -Console
```

### System Repair

The tool provides various repair tools, including:

- System file check & repair (enhanced SFC)
- Disk error repair (enhanced CHKDSK)
- Network configuration reset
- Windows Update repair
- Storage Sense optimization

**All repair operations support undo** — if a repair causes issues, you can one-click undo within the tool.

---

## Performance Tiers

The tool automatically selects the appropriate performance tier based on your hardware:

| Tier | For | Effects Level | Notes |
|------|-----|---------------|-------|
| Extreme | High-end PCs | Full effects | Complete starfield, particles, full frame rate |
| Performance | Mid-to-high PCs | High effects | Optimized starfield, partial particles |
| Balanced | Mid-range PCs | Medium effects | Moderate visual effects |
| Eco | Low-end PCs | Minimal effects | Half frame rate, no particles, lowest CPU |

You can also manually set the performance tier via the `AURORA_PERF_TIER` environment variable: `Eco` / `Balanced` / `Performance` / `Extreme`.

---

## FAQ

### Q: The tool crashes immediately after launch?

A: This is usually due to security verification failure. Please ensure:
- You are using an officially built EXE
- No core script files have been modified
- Close any debuggers or reverse engineering tools

### Q: What if a repair causes system issues?

A: The tool has a built-in **Undo Manager** — find the "Undo Last Repair" function. Additionally, the tool automatically creates a system restore point before each repair.

### Q: Interface animations are laggy?

A: The tool automatically detects your hardware and adjusts performance. If still laggy, manually set `AURORA_PERF_TIER=Eco`.

### Q: How do I update to the latest version?

A: Simply replace all files. The tool's file integrity verification will automatically detect version matching.

---

## Security Notice

AURORA Analyzer uses multi-layer security protection against tampering:

- Automatically verifies integrity of all core files at startup
- Continuously detects debuggers and reverse engineering tools at runtime
- All repair operations have safe rollback mechanisms

For security researchers, please refer to the [Technical Documentation](file:///e%3A/PC%20SOFT/%E4%BC%98%E5%8C%96%E8%BD%AF%E4%BB%B6/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/Docs/READMEV1.2.25.0_EN.md) for detailed security architecture.

---

## Version History

| Version | Date | Major Updates |
|---------|------|---------------|
| V1.2.25.0 | 2026.06.02 | GUI animation overhaul: ripple feedback, magnetic snap, smooth progress bars, easing library expanded to 20 types |
| V1.1.24.5 | 2026.05 | Starfield background, glare sweep animation, particle progress bar |
| V1.0 | Early 2026 | Initial release, smart diagnostics + basic repair |

---

## Disclaimer

This tool is provided "as is" without any express or implied warranties. Please ensure you have backed up important data before using this tool for system repair operations. The author assumes no liability for any direct or indirect damages caused by the use of this tool.

---

*AURORA VelociRaptor-GR Dev PRJ.*