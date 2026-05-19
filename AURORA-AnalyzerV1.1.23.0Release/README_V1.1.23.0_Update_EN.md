# AURORA Analyzer V1.1.23.0 - Update Guide

**Update Date:** 2026.05.19  
**Current Version:** V1.1.23.0  
**Previous Version:** V1.1.22.0  
**Author:** AURORA VelociRaptor-GR Dev PRJ.

---

## 📋 Table of Contents

1. [Update Overview](#-update-overview)
2. [Pre-Update Preparation](#-pre-update-preparation)
3. [Update Steps](#-update-steps)
4. [Post-Update Verification](#-post-update-verification)
5. [Rollback Guide](#-rollback-guide)
6. [New Modules Details](#-new-modules-details)
7. [FAQ](#-faq)

---

## 🎯 Update Overview

### Version Information

| Item | Details |
|------|---------|
| **New Version** | V1.1.23.0 |
| **Release Date** | 2026.05.19 |
| **Update Type** | Minor Release (Major Feature Update) |
| **Compatibility** | Backward compatible with V1.1.0+ |
| **Mandatory Update** | No (Recommended) |

### Update Highlights

✅ **Phase 4.2 Undo Support System** - Complete rollback protection mechanism  
✅ **Automatic Minidump Analysis** - Blue screen dump file automatic analysis  
✅ **Knowledge Base Cache** - 70% faster diagnostics  
✅ **Animation Engine Decoupling** - Modular architecture improvement  
✅ **Security Enhancement** - Pre-check + risk assessment + rollback mechanism  

### New Files List

This update will add the following files:

```
New Files (5 Phase 4.2 Modules):
├── Scripts\AURORA-RestoreManager.ps1           [New] System Restore Manager
├── Scripts\AURORA-RepairLogger.ps1             [New] Repair Logger
├── Scripts\AURORA-UndoManager.ps1              [New] Fast Backup & Restore
├── Scripts\AURORA-RepairTools.ps1              [New] Repair Tools Entry
└── Scripts\AURORA-UndoViewer.ps1               [New] Undo Manager Viewer

New Files (1 Phase 5 Module):
└── Scripts\Core\AURORA-AnimationCoreEngine.ps1 [New] Animation Core Engine

New/Updated Files:
├── Data\AURORA-TechData.cache.clixml           [Updated] Knowledge Base Cache
├── Resources\CascadiaMono.ttf                  [Updated] Font File (Optional)
└── version.txt                                 [Updated] Version Information
```

### Update Scale

| Item | Count |
|------|-------|
| New Files | 7 |
| Updated Files | 3 |
| New Code Lines | ~2,000 |
| Updated Code Lines | ~500 |
| New Features | 4 Major Features |
| Bug Fixes | 3 |

---

## ⚠️ Pre-Update Preparation

### 1. System Checklist

Before starting the update, complete the following checks:

#### ✅ System Compatibility Check

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Requirement: 5.1 or higher
# If lower than 5.1, please update Windows first
```

#### ✅ Disk Space Check

```powershell
# Check available disk space
Get-Volume | Select-Object DriveLetter, SizeRemaining, Size

# Requirement: At least 100MB free space
# Recommended: 500MB or more
```

#### ✅ Permission Check

```powershell
# Check administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "✅ Current user has administrator privileges" -ForegroundColor Green
} else {
    Write-Host "⚠️ Current user lacks administrator privileges (some features will be limited)" -ForegroundColor Yellow
}
```

#### ✅ System Restore Status Check

```powershell
# Check if System Restore is enabled
try {
    $restoreKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -ErrorAction Stop
    Write-Host "✅ System Restore is enabled" -ForegroundColor Green
} catch {
    Write-Host "⚠️ System Restore is not enabled (Undo features will be limited)" -ForegroundColor Yellow
    Write-Host "Tip: System Properties → System Protection → Enable System Restore" -ForegroundColor Cyan
}
```

### 2. Data Backup

#### Backup User Logs

```powershell
# Create backup directory
$backupDir = ".\Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

# Backup user logs
if (Test-Path ".\UserLogs") {
    Copy-Item -Path ".\UserLogs" -Destination "$backupDir\UserLogs" -Recurse
    Write-Host "✅ User logs backed up to: $backupDir\UserLogs" -ForegroundColor Green
}
```

#### Backup Session Cache

```powershell
# Backup session cache
if (Test-Path ".\SessionCache") {
    Copy-Item -Path ".\SessionCache" -Destination "$backupDir\SessionCache" -Recurse
    Write-Host "✅ Session cache backed up to: $backupDir\SessionCache" -ForegroundColor Green
}
```

#### Backup Configuration Files

```powershell
# Backup configurations
$configFiles = @(
    ".\version.txt",
    ".\Data\AURORA-TechData.json"
)

foreach ($file in $configFiles) {
    if (Test-Path $file) {
        Copy-Item -Path $file -Destination "$backupDir\$([System.IO.Path]::GetFileName($file))"
        Write-Host "✅ Configuration backed up: $file" -ForegroundColor Green
    }
}
```

### 3. Create System Restore Point (Recommended)

```powershell
# Run PowerShell as Administrator, then execute
Enable-ComputerRestore -Drive "$env:SystemDrive"

# Create system restore point
Checkpoint-Computer -Description "Before AURORA V1.1.23.0 Update" -RestorePointType "MODIFY_SETTINGS"

Write-Host "✅ System restore point created" -ForegroundColor Green
Write-Host "   Description: Before AURORA V1.1.23.0 Update" -ForegroundColor Cyan
```

---

## 📥 Update Steps

### Method 1: Overwrite Update (Recommended)

Suitable for updating from V1.1.20.0 or higher.

#### Step 1: Download New Version

Download `AURORA_Analyzer_v1.1.23.0_Release.zip` to local machine.

#### Step 2: Extract Files

```powershell
# Extract to temporary directory
$zipPath = "C:\Downloads\AURORA_Analyzer_v1.1.23.0_Release.zip"
$extractPath = "C:\Temp\AURORA_Update"

Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
```

#### Step 3: Close AURORA

Ensure AURORA program is completely closed:

```powershell
# Check if any AURORA processes are running
Get-Process | Where-Object {$_.Name -like "*AURORA*" -or $_.MainWindowTitle -like "*AURORA*"} | Stop-Process -Force
```

#### Step 4: Overwrite Update

```powershell
# Navigate to AURORA installation directory
cd "E:\PC SOFT\优化软件\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory"

# Copy new files
Copy-Item -Path "$extractPath\Scripts" -Destination ".\Scripts" -Recurse -Force
Copy-Item -Path "$extractPath\Data" -Destination ".\Data" -Recurse -Force
Copy-Item -Path "$extractPath\Resources" -Destination ".\Resources" -Recurse -Force

# Copy root directory files
Copy-Item -Path "$extractPath\AURORA.Launcher-双击启动.exe" -Destination ".\" -Force
Copy-Item -Path "$extractPath\GAURORA.CHK.ENC" -Destination ".\" -Force
Copy-Item -Path "$extractPath\version.txt" -Destination ".\" -Force
Copy-Item -Path "$extractPath\desktop.ini" -Destination ".\" -Force
```

#### Step 5: Verify Integrity

```powershell
# Run directory integrity check
.\Scripts\AURORA-AnalyzerLauncherGUI.ps1

# If startup succeeds, update is complete
```

### Method 2: Fresh Installation

Suitable for updating from earlier versions (V1.1.19.x or earlier).

#### Step 1: Completely Uninstall Old Version

```powershell
# Backup data (refer to Pre-Update Preparation)
$backupDir = ".\Backup_OldVersion_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

# Backup user data
Copy-Item -Path ".\UserLogs" -Destination "$backupDir\UserLogs" -Recurse
Copy-Item -Path ".\SessionCache" -Destination "$backupDir\SessionCache" -Recurse

# Delete old files
Remove-Item -Path ".\Scripts" -Recurse -Force
Remove-Item -Path ".\Data" -Recurse -Force
Remove-Item -Path ".\Resources" -Recurse -Force
Remove-Item -Path ".\AURORA.Launcher-双击启动.exe" -Force
Remove-Item -Path ".\GAURORA.CHK.ENC" -Force
Remove-Item -Path ".\desktop.ini" -Force
```

#### Step 2: Install New Version

```powershell
# Extract new version
$zipPath = "C:\Downloads\AURORA_Analyzer_v1.1.23.0_Release.zip"
Expand-Archive -Path $zipPath -DestinationPath "." -Force
```

#### Step 3: Restore User Data

```powershell
# Restore user logs
if (Test-Path "$backupDir\UserLogs") {
    Copy-Item -Path "$backupDir\UserLogs" -Destination ".\UserLogs" -Recurse
}

# Restore session cache
if (Test-Path "$backupDir\SessionCache") {
    Copy-Item -Path "$backupDir\SessionCache" -Destination ".\SessionCache" -Recurse
}
```

### Method 3: Update Using Build Script

Suitable for developers or advanced users.

#### Step 1: Get Source Code

```powershell
# If using Git
git pull origin main
```

#### Step 2: Run Build Script

```powershell
# Navigate to project directory
cd "E:\PC SOFT\优化软件\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory"

# Run build script
.\AURORA-build.bat /generate

# Or use PowerShell directly
.\build.ps1
```

#### Step 3: Enter Password

Follow prompts to enter master password (used for encrypted verification file).

#### Step 4: Select Version Options

```
Build Options:
1. Build with current version
2. Increment version and build

Please select: 1
```

#### Step 5: Automatic Packaging (Optional)

```
Do you want to create a ZIP release package? (Y/N, default N)
N
```

---

## ✅ Post-Update Verification

### 1. Version Check

```powershell
# Check version file
Get-Content .\version.txt

# Should display: 1.1.23.0
```

### 2. File Integrity Check

```powershell
# Check if required files exist
$requiredFiles = @(
    ".\AURORA.Launcher-双击启动.exe",
    ".\Scripts\AURORA-AnalyzerLauncherGUI.ps1",
    ".\Scripts\AURORA-AnalyzerPRO.ps1",
    ".\Scripts\AURORA-SmartEngine.ps1",
    ".\Scripts\AURORA-RestoreManager.ps1",      # New
    ".\Scripts\AURORA-RepairLogger.ps1",        # New
    ".\Scripts\AURORA-UndoManager.ps1",         # New
    ".\Scripts\AURORA-RepairTools.ps1",         # New
    ".\Scripts\AURORA-UndoViewer.ps1",          # New
    ".\Scripts\Core\AURORA-AnimationCoreEngine.ps1"  # New
)

$allExist = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file" -ForegroundColor Green
    } else {
        Write-Host "❌ $file (Missing)" -ForegroundColor Red
        $allExist = $false
    }
}

if ($allExist) {
    Write-Host "`n✅ All files integrity check passed" -ForegroundColor Green
} else {
    Write-Host "`n❌ Some files are missing, please update again" -ForegroundColor Red
}
```

### 3. Functional Testing

#### Test GUI Startup

```powershell
# Start GUI
.\AURORA.Launcher-双击启动.exe

# Check if it starts normally
# Should see main interface, no error messages
```

#### Test Undo Functionality

```powershell
# Import Undo module
.\Scripts\AURORA-UndoManager.ps1

# Initialize Undo manager
Initialize-UndoManager

# Should display:
# ✅ AURORA Undo Manager initialization complete
#    Backup directory: ...\SessionCache\backup
```

#### Test Animation Engine

```powershell
# Import animation engine
.\Scripts\Core\AURORA-AnimationCoreEngine.ps1

# Check if classes are available
[AuroraProgressBar]
[StarfieldPanel]
[AURORA_Animation]

# Should have no errors
```

### 4. Performance Benchmark

```powershell
# Test knowledge graph loading speed
Measure-Command {
    .\Scripts\AURORA-SmartEngine.ps1
}

# Should be < 1 second with cache hit
# Should be < 3 seconds without cache
```

---

## 🔙 Rollback Guide

If you encounter issues after update, follow these steps to rollback.

### Method 1: Using System Restore Point

**Prerequisite:** Created system restore point before update

#### Steps:

1. Open "System Properties"
2. Select "System Protection" tab
3. Click "System Restore"
4. Select restore point created before update
5. Follow wizard to complete restore

### Method 2: Using Backup Restore

**Prerequisite:** Backed up old version files before update

#### Steps:

```powershell
# Navigate to backup directory
cd ".\Backup_20260519_123456"

# Restore old version files
Copy-Item -Path ".\Scripts" -Destination "..\Scripts" -Recurse -Force
Copy-Item -Path ".\Data" -Destination "..\Data" -Recurse -Force
Copy-Item -Path ".\Resources" -Destination "..\Resources" -Recurse -Force

# Restore root directory files
Copy-Item -Path ".\AURORA.Launcher-双击启动.exe" -Destination "..\" -Force
Copy-Item -Path ".\GAURORA.CHK.ENC" -Destination "..\" -Force
```

### Method 3: Reinstall Old Version

**Prerequisite:** Have old version installation package

#### Steps:

1. Completely uninstall new version
2. Install old version (refer to installation guide)
3. Restore user data

---

## 📦 New Modules Details

### 1. AURORA-RestoreManager.ps1

**Purpose:** System restore point management

**Core Functions:**
```powershell
# Create system restore point
Create-SystemRestorePoint -Description "Before Repair"

# Query restore point list
Get-SystemRestorePoints

# Delete restore point
Remove-SystemRestorePoint -SequenceNumber 45

# Execute system restore
Restore-System -SequenceNumber 45
```

**Dependencies:**
- Administrator privileges
- WMI access permissions
- System Restore feature enabled

**Usage Example:**
```powershell
# Import module
.\Scripts\AURORA-RestoreManager.ps1

# Create restore point
$restorePoint = Create-SystemRestorePoint -Description "AURORA Test"

# Display information
Write-Host "Restore Point ID: $($restorePoint.RestorePointId)"
Write-Host "Sequence Number: $($restorePoint.SequenceNumber)"
```

### 2. AURORA-RepairLogger.ps1

**Purpose:** Repair session logging

**Core Functions:**
```powershell
# Start repair session
Start-RepairSession -RepairType "RegistryRepair" -Target "Windows Update"

# Record command execution
Log-RepairCommand -SessionId "RS_001" -Command "Set-ItemProperty" -Status "Success"

# Complete session
Complete-RepairSession -SessionId "RS_001" -Status "Success"

# Query session
Get-RepairSession -SessionId "RS_001"
```

**Log Format:**
```json
{
  "SessionId": "RS_20260519_123456_789",
  "StartedAt": "2026-05-19T12:34:56",
  "RepairType": "RegistryRepair",
  "Target": "Windows Update",
  "Commands": [...],
  "Status": "Success",
  "CanUndo": true
}
```

### 3. AURORA-UndoManager.ps1

**Purpose:** Fast backup and restore

**Core Functions:**
```powershell
# Initialize
Initialize-UndoManager

# Create backup snapshot
Create-BackupSnapshot -Type "Registry" -Paths @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate")

# Restore backup
Restore-BackupSnapshot -SnapshotId "BS_20260519_123456_789"
```

**Backup Types:**
- Registry: Registry backup
- File: File backup
- Service: Service configuration backup
- Mixed: Mixed backup

### 4. AURORA-RepairTools.ps1

**Purpose:** Repair tools entry

**Features:**
- Provides interactive repair menu
- Integrated Undo support
- Batch repair operations

### 5. AURORA-UndoViewer.ps1

**Purpose:** Undo manager viewer

**Features:**
- Graphical display of backup history
- One-click restore operations
- Detailed information view

### 6. AURORA-AnimationCoreEngine.ps1

**Purpose:** Animation core engine

**Core Classes:**
- `AuroraProgressBar`: Progress bar control
- `StarfieldPanel`: Starfield background
- `TechButton`: Dynamic button
- `AURORA_Animation`: Global animation manager

**Performance Tiers:**
```powershell
# Extreme: 8-core+ 32GB+
# Performance: 6-core 16GB
# Balanced: 4-core 8GB
# Eco: Legacy devices
```

---

## ❓ FAQ

### Q1: GUI Fails to Start After Update

**Possible Causes:**
- Incomplete file copy
- .NET Framework version too low
- Password verification failed

**Solutions:**
```powershell
# 1. Check file integrity
Test-Path ".\Scripts\AURORA-AnalyzerLauncherGUI.ps1"

# 2. Check .NET Framework version
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" |
    Get-ItemPropertyValue -Name Release

# Requirement: Release >= 378389 (.NET 4.5)

# 3. Rebuild (if password change needed)
.\AURORA-build.bat /generate
```

### Q2: Undo Functionality Unavailable

**Possible Causes:**
- Not running as administrator
- System Restore not enabled
- Backup directory permission issues

**Solutions:**
```powershell
# 1. Check administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# 2. Enable System Restore
Enable-ComputerRestore -Drive "$env:SystemDrive"

# 3. Check backup directory permissions
$acl = Get-Acl ".\SessionCache\backup"
$acl.Access
```

### Q3: Knowledge Graph Loading Slow

**Possible Causes:**
- Cache file corrupted
- KB file too large
- Disk performance issues

**Solutions:**
```powershell
# 1. Delete cache file (will auto-rebuild)
Remove-Item ".\Data\AURORA-TechData.cache.clixml" -Force

# 2. Restart AURORA (auto-rebuilds cache)

# 3. Check disk performance
Get-Volume | Select-Object DriveLetter, SizeRemaining
```

### Q4: Animation Effects Laggy

**Possible Causes:**
- Insufficient hardware performance
- Outdated graphics driver
- DPI scaling issues

**Solutions:**
```powershell
# 1. Check performance tier
$perfScore = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors * 15 + 
             (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB * 5

Write-Host "Performance Score: $perfScore"

# 2. Update graphics driver
# Visit graphics manufacturer website to download latest driver

# 3. Adjust DPI scaling
# System Settings → Display → Scale and layout
```

### Q5: Old Logs Lost After Update

**Possible Causes:**
- No backup before update
- Accidental deletion during overwrite installation

**Solutions:**
```powershell
# 1. Check backup directory
Get-ChildItem ".\Backup_*" -Directory

# 2. Restore log files
Copy-Item -Path ".\Backup_*\UserLogs" -Destination ".\UserLogs" -Recurse

# 3. If no backup, try data recovery software
# Recommended: Recuva, EaseUS Data Recovery
```

---

## 📞 Getting Help

### Official Documentation

- **Full Documentation:** `README_V1.1.23.0.md`
- **Release Notes:** `README_V1.1.23.0_Release.md`
- **Update Guide:** This document

### Technical Support

**Encountering Issues?**

1. Check log files:
   ```powershell
   Get-Content ".\UserLogs\*.txt" -Tail 50
   ```

2. Run diagnostic tools:
   ```powershell
   .\test\Test-Bilingual.ps1
   ```

3. Contact technical support:
   - GitHub Issues: [To be added]
   - Email: [To be added]

### Community Resources

- PowerShell Community Forums
- Windows Event Log Documentation
- System Restore Technical Documentation

---

## 📝 Update Changelog Summary

### V1.1.23.0 Changes

**New:**
- ✅ Phase 4.2 Undo Support System (5 modules)
- ✅ Phase 5 Animation Engine Decoupling
- ✅ Automatic Minidump Analysis
- ✅ Knowledge Base Cache Mechanism

**Improvements:**
- 🚀 Performance Optimization (Dual-Index Pre-Lookup)
- 🛡️ Security Enhancement (Pre-Check + Rollback)
- 🎨 UI Beautification (Folder Icon)
- 📦 Build Optimization (Automatic ZIP Packaging)

**Bug Fixes:**
- 🐛 GUI Authorization CPU Usage Issue
- 🐛 PRO Mode CSV Reading Error
- 🐛 Undo Backup Metadata Issue

**Known Issues:**
- ⚠️ System Restore requires administrator privileges
- ⚠️ Minidump analysis doesn't support complete dumps
- ⚠️ High DPI displays may appear blurry

---

**Update Guide Version:** V1.1.23.0  
**Last Updated:** 2026.05.19  
**Author:** AURORA VelociRaptor-GR Dev PRJ.

*Happy updating!*
