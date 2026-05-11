# AURORA Analyzer v0.21.1 Release Notes

> **Making Windows Event Logs No Longer Obscure — One-Click Export, Intelligent Diagnostics, Autonomous Repair**

***

## Welcome to AURORA Analyzer

AURORA Analyzer is a system health diagnostic tool designed for Windows users. It dives deep into Windows event logs to automatically identify root causes of blue screens, freezes, crashes, network issues, and presents them in clear, easy-to-understand reports. Even more powerful, it includes a built-in "Autonomous Repair Engine" that can execute verified repair operations with one click—whether running system file checks, cleaning disks, or diagnosing driver issues.

You no longer need to search for the meaning of error codes or remember obscure commands like `sfc /scannow` or `DISM`. AURORA will automatically tell you what's wrong with your system, how serious it is, how to fix it—you just need to click to confirm.

***

## What AURORA Can Do

### One-Click Windows Event Log Export

Windows records thousands of event logs daily in the background, containing critical information about system operation. But these logs are usually scattered across different locations and difficult to read. AURORA helps you:

- One-click export of 8 log types including System, Application, Security, and more
- Support for single-day or custom date range export
- Automatic filtering of high-risk events (Critical, Error, Warning), no need to search through massive information
- Output formats include CSV spreadsheets, JSON structured data, XML standard format, and TXT readable summary reports

### Intelligent System Health Diagnostics

AURORA includes a "Smart Diagnostic Engine" that automatically analyzes your computer status like a system expert:

- **Automatic System Uptime Detection**: Determines if your computer just booted, is running stably, or recently had an abnormal restart
- **Intelligent Time Window Decision**: If blue screen or unexpected shutdown is detected, automatically narrows analysis scope to precisely locate logs from 2 hours before crash
- **Minidump Blue Screen Dump Detection**: Actively checks for unanalyzed blue screen memory dump files in the system
- **Knowledge Graph Matching**: Compares extracted events against built-in 6-category diagnostic rule database to identify all matching known issues

### Autonomous Repair Engine

This is AURORA's core capability. After diagnosing system issues, it doesn't just tell you "there's a problem"—it will:

- List all matched issues, sorted by severity from high to low
- Each issue includes detailed **cause analysis**, **solutions**, and **executable commands**
- Each command is labeled with **risk level** (Low/Medium/High), so you clearly understand the safety of each operation
- Commands requiring administrator privileges are specially marked with [Admin] tag
- High-risk operations trigger **holographic authorization popups**, requiring your逐项 confirmation before execution
- Supports **automatic rollback** on operation failure, maximizing system safety

Built-in diagnostic rules cover six domains:

| Domain             | Typical Examples                       |
| ------------------ | -------------------------------------- |
| **System Stability**      | Unexpected shutdown, blue screen, app crash, disk error, slow boot |
| **Drivers & Hardware**    | GPU driver timeout, device driver not properly loaded |
| **Network & Communication** | DHCP IP acquisition failure, DNS resolution timeout, network resource exhaustion |
| **Windows Update** | Update installation failure |
| **Security & Identity** | Login failures (brute force detection support) |
| **Applications & Services** | Print spooler errors |

### Trend Analysis

Beyond single diagnostics, AURORA supports **trend analysis** of logs. It statistics the frequency changes of various error events over time, helping you determine:

- Whether a problem is worsening or has resolved itself
- Whether a recent system update introduced new issues
- Early signs of hardware failure

### Checkpoint Resume — No Fear of Midway Exit

Exporting large amounts of logs may take some time. AURORA includes a built-in **Session Persistence System** that automatically saves current task progress. If interrupted (e.g., accidentally closing the window), next startup will detect the incomplete task and ask if you want to continue from the checkpoint. Progress information is retained for 7 days, then automatically cleaned up.

### Bilingual Support (Chinese/English)

AURORA automatically switches interface language based on your Windows system language. Chinese users see complete Chinese interface and Chinese reports, English users see English version. Regardless of language, functionality and experience are identical.

***

## Getting Started

### Step 1: Launch the Program

You have two launch options:

1. **Recommended**: Double-click `AURORA.Launcher-双击启动.exe`, the program launches silently with GUI, no command window flashing
2. **Alternative**: If you're familiar with PowerShell, you can execute the corresponding `.ps1` startup script in the tool directory

> ⚠️ Note: Do NOT double-click `.ps1` files directly! All scripts have built-in startup protection and must be launched via EXE launcher or GUI script.

### Step 2: Select Logs to Analyze

After launch, you'll see an exquisite graphical interface where you can:

1. **Select Log Type**: System (default) is the best starting point for most diagnostic scenarios. You can also select Application to troubleshoot software crashes
2. **Set Date Range**: Choose "Today" for quick current problem diagnosis, or customize start/end dates to investigate historical issues
3. **Select Export Mode**:
   - Single Day Mode: Quick analysis of problems on a specific day
   - Date Range Mode: Analyze problem trends over a period
4. **Select Export Scope**:
   - High Risk Events Only: Export only error and warning level events, fast with high information density
   - Full Export: Export all level events (including informational), more comprehensive data
5. **Trend Analysis**: Check to generate time-series frequency change reports

### Step 3: View Results and Execute Repairs

After export and analysis complete:

- **Summary Report** tells you overall system health status and event statistics
- Click "Start Smart Analysis" button, AURORA's smart engine performs deep diagnostics on exported logs
- If issues are found, displays detailed problem list with corresponding one-click repair commands
- You can select repair operations one by one—low-risk operations execute automatically, high-risk operations popup confirmation window for your decision

***

## System Requirements

AURORA is designed with compatibility in mind, aiming to run smoothly on various Windows PC configurations:

- **Operating System**: Windows 10, Windows 11, Windows Server 2016 or later
- **PowerShell**: 5.1 or higher (built-in by default on Windows 10/11)
- **.NET Framework**: 4.x (usually pre-installed on system)
- **Memory**: 4GB or more recommended (8GB+ for better experience)

For lower-spec computers, AURORA automatically detects hardware performance and reduces interface animation effects, ensuring the tool itself doesn't become a system burden.

***

## System Requirements Details

| Requirement         | Minimum Configuration       | Recommended Configuration         |
| ------------------- | --------------------------- | --------------------------------- |
| Operating System    | Windows 10                  | Windows 11                        |
| PowerShell          | 5.1                         | 5.1+                              |
| Memory              | 4GB                         | 8GB+                              |
| Privileges          | Standard User               | Administrator (for Security logs) |

> 💡 Tip: System and Application logs can be exported without administrator privileges. Only protected logs like Security, Setup, DNS Server, DHCP Server, Directory Service, and IIS Admin Service require administrator privileges. When you select these log types, AURORA automatically requests elevation.

***

## File Description

After downloading and extracting, you'll see these files:

| File                                           | Purpose                           |
| ---------------------------------------------- | --------------------------------- |
| `AURORA.Launcher-双击启动.exe`                   | Main program launcher, double-click to run |
| `ExportSystemEventLauncherGUI.ps1`           | GUI main program                  |
| `ExportSystemEventLogsCHSPro.ps1`            | Chinese version log export engine |
| `ExportSystemEventLogsENGPro.ps1`            | English version log export engine |
| `AURORA-SmartEngine.ps1`                     | Intelligent diagnostic & repair engine |
| `AURORA-TechData.json`                       | Diagnostic knowledge base (6 major diagnostic rule categories) |
| `AURORA-ProgressManager.ps1`                 | Task progress save & restore      |
| `AURORA-ProgressManager-Integration-CHS.ps1` | Chinese progress integration      |
| `AURORA-ProgressManager-Integration-ENG.ps1` | English progress integration      |
| `GAURORA.CHK.ENC`                            | Integrity check file (do not delete) |

> ⚠️ Important: Do NOT delete or move any files. All files must remain in the same directory, otherwise the program cannot start properly.

***

## Frequently Asked Questions

**Q: What if I get "Unable to verify encrypted file" on startup?**

A: This usually means you're directly double-clicking a `.ps1` file to launch. Instead, double-click `AURORA.Launcher-双击启动.exe` to start.

**Q: Why can't I export Security logs?**

A: Security logs are protected by Windows and require administrator privileges to access. Right-click the EXE and select "Run as Administrator" when launching.

**Q: Where are exported files saved?**

A: By default, saved in the `UserLogs` folder under the tool directory. This folder opens automatically after export completes.

**Q: What does trend analysis show?**

A: Trend analysis statistics frequency changes of various event types (Critical, Error, Warning) over the selected time range, helping you determine if system problems are worsening or have returned to normal.

**Q: What's the difference between "Smart Analysis" and normal export?**

A: Normal export converts raw logs into readable report formats. Smart analysis goes further, using built-in 6-category diagnostic rule database to deeply match each high-risk event, providing specific repair suggestions and executable operation commands.

**Q: Is executing repair operations safe?**

A: AURORA labels each command with risk level. Low-risk operations (like querying system temperature, viewing startup items) execute automatically. High-risk operations (like CHKDSK disk repair) popup confirmation window, requiring your authorization before execution. Operations also automatically rollback on failure.

***

## Version Information

- **Version**: 0.21.1
- **Build Date**: 2026.05.09
- **License**: This tool is for personal learning use only

***

## Technical Support

If you have any questions or suggestions, feel free to contact the developer. I'm continuously improving AURORA, hoping it enables every Windows user to manage and maintain their system like an expert.

***

*Making Windows diagnostics simple and elegant — AURORA Analyzer*
