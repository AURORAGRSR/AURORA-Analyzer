# AURORA Analyzer V1.1.24.1 Release — User Guide

**Version:** V1.1.24.1\
**Release Date:** 2026.05.27\
**Author:** AURORA VelociRaptor-GR Dev PRJ.\
**Platform:** Windows 7/8/10/11 (x64)\
**Requirements:** .NET Framework 4.7.2+, PowerShell 5.1+

***

## 🎯 Quick Start

### Method 1: Double-click EXE Launch (Recommended)

```
Double-click: AURORA.Launcher-双击启动.exe
```

✅ **Advantages:**

- Automatic administrator privilege handling
- No password verification required
- Complete security protection chain

### Method 2: PowerShell Launch

```powershell
# Right-click → "Run with PowerShell"
```

⚠️ **Note:** Password verification required on first launch (contact administrator for password)

***

## 🆕 V1.1.24.1 New Features Highlights

### 1. 🛡️ Full-Link Security Monitoring

> **Security no longer "pauses" during Professional Graphics Mode operation**\
> Even when analyzing logs in Professional Graphics Mode (typically 5-30 minutes), the program continues to monitor file integrity, ensuring the entire usage process remains under security protection.

### 2. ⚠️ User-Friendly Security Alerts

> **No more "sudden disappearance" when tampering is detected**\
> The program displays a 15-second countdown warning window, clearly showing which files were tampered with or missing, giving you ample time to understand the issue.

### 3. 📝 Clean Console Logs

> **No more scrolling! Logs display on a single line**\
> Integrity check logs now refresh in-place, showing check count and time, making them both beautiful and easy to track.

***

## 🔧 Key Features

### 1. Intelligent Log Analysis

- **Supported Log Types:**
  - System
  - Application
  - Security
  - Setup
  - DNS Server, DHCP Server, Directory Service, IIS Admin Service
- **Analysis Modes:**
  - 📊 **Single-Day Quick Scan** - Quickly view key events for the current day
  - 📈 **Date Range Deep Analysis** - Custom time period trend analysis
  - 🎯 **High-Risk Events Priority** - Show only errors, warnings, and critical events

### 2. Professional Graphics Mode

- **Real-time Progress Visualization** - Dynamic glare sweep progress bar + particle effects
- **Bilingual Interface** - Automatic Chinese/English switching
- **Smart Diagnosis Integration** - One-click switch to smart repair mode

### 3. Smart Diagnosis & Auto-Repair

- **Automatic Problem Identification** - Intelligent matching based on event ID, source, and level
- **Repair Suggestion Generation** - Executable solutions provided for each issue
- **One-Click Repair** - Support for batch applying repair solutions

***

## 🔐 Security Notes

### Launch Authentication

This tool uses **RSA-2048 + AES-256** dual encryption verification:

- ✅ EXE launcher holds private key, generates one-time Token
- ✅ PowerShell script holds public key, verifies Token legitimacy
- ✅ Token automatically expires after 60 seconds, preventing replay attacks

### Runtime Monitoring

- **Dual Timer Checks** - Regular check every 3 seconds + random check every 2-7 seconds
- **File Watcher** - Real-time file change detection (<100ms response)
- **19 Core Files** - All critical components under monitoring

### If You See Warning Window

```
⚠️ AURORA Security Alert

Program integrity has been compromised, detected the following issues:
- Missing files: Scripts\AURORA-CoreEngine.ps1
- Tampered files: Scripts\AURORA-AnalyzerPRO.ps1

Program will exit automatically in 15 seconds.
```

**What to Do:**

1. ⏰ Take a photo of tampered files within 15 seconds
2. 🔄 Re-download the complete installation package
3. 🧹 Delete old version, re-extract to clean directory
4. 📧 Contact administrator to report the issue

***

## 📊 Output Files Description

After analysis completes, the following files are generated in the `UserLogs` directory:

| File                                 | Description                      | Format |
| ------------------------------------ | -------------------------------- | ------ |
| `System_Log_Date.json`               | Structured log data              | JSON   |
| `System_Log_Date.xml`                | Importable to Event Viewer       | XML    |
| `System_Log_Date.csv`                | Importable to Excel for analysis | CSV    |
| `System_Log_Date_Summary.txt`        | Human-readable summary           | Text   |
| `System_Log_Date_Trend_Analysis.txt` | Periodic trend report            | Text   |
| `System_Log_Date_Trend_Data.csv`     | Trend chart data                 | CSV    |

***

## ❓ Frequently Asked Questions (FAQ)

### Q1: Why is password verification required?

**A:** To prevent unauthorized users from directly running PowerShell scripts and bypassing EXE launcher security verification. Password is set by administrator during build.

### Q2: What if "File Tampered" alert appears?

**A:**

1. Don't panic, this is the protection mechanism working
2. Check if you manually modified script files
3. If false positive, re-download official version
4. If actual tampering detected, disconnect network immediately and contact administrator

### Q3: Professional Graphics Mode won't open?

**A:** V1.1.24.1 has fixed this issue. If still unable to open, check:

- Whether antivirus software is blocking
- Whether running as administrator
- Check console for error messages

### Q4: Log analysis too slow?

**A:**

- Select "High-Risk Events Priority" mode, analyze only critical events
- Narrow date range (recommended within 7 days)
- Close other CPU-intensive programs

***

## 🆘 Troubleshooting

### Issue 1: "Encryption verification file not found" on launch

**Solution:**

```
Ensure these files are in the same directory:
- AURORA.Launcher-双击启动.exe
- GAURORA.CHK.ENC
- Scripts\AURORA-AnalyzerLauncherGUI.ps1
```

### Issue 2: No output files after analysis completes

**Solution:**

1. Check if `UserLogs` folder exists
2. Verify current user has write permissions
3. Check console for error messages
4. Try running as administrator

### Issue 3: Smart Repair Mode cannot identify issues

**Solution:**

1. Ensure log files have been exported
2. Launch smart repair from PRO mode (not directly)
3. Check if log type is supported

***

## 📞 Get Help

### Support Channels

<https://github.com/AURORAGRSR/AURORA-Analyzer/tree/ReleaseVersion>

### When Reporting Issues, Please Provide

- ✅ Software version number (displayed on launch screen)
- ✅ Windows version and PowerShell version
- ✅ Complete error message screenshots
- ✅ Steps to reproduce the issue

***

## 📋 Version History

| Version   | Release Date | Key Updates                                                                    |
| --------- | ------------ | ------------------------------------------------------------------------------ |
| V1.1.24.1 | 2026.05.27   | Full-link security monitoring, warning window optimization, log cleanup        |
| V1.1.24.0 | 2026.05.25   | RSA encryption system, anti-reverse engineering, enhanced real-time monitoring |
| V1.1.23.0 | 2026.05.14   | Bilingual support, smart repair mode, Undo Manager                             |

***

## ⚖️ License & Disclaimer

**License:** Proprietary (All Rights Reserved)\
**Copyright:** © 2026 AURORA VelociRaptor-GR Dev PRJ.

**Disclaimer:**

> This tool is for educational and research purposes only. The author is not responsible for any data loss, system damage, or other losses caused by using this tool. By using this tool, you agree to assume all risks.

***

**Last Updated:** 2026.05.27\
**Document Version:** 1.0
