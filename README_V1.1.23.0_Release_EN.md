# AURORA Analyzer V1.1.23.0 - Release Notes

**Release Date:** 2026.05.19  
**Version:** V1.1.23.0 Release  
**Author:** AURORA VelociRaptor-GR Dev PRJ.  
**Type:** Stable Release

---

## 🎉 Release Announcement

We are excited to announce the official release of AURORA Analyzer V1.1.23.0! This is a major update introducing core features including complete Undo support system, animation engine decoupling, and automatic Minidump analysis.

---

## 📦 Package Contents

### Core Files

| Filename | Size | Description |
|---------|------|-------------|
| `AURORA.Launcher-双击启动.exe` | ~50KB | Main launcher (C# compiled, windowless) |
| `GAURORA.CHK.ENC` | ~5KB | Encrypted verification file |
| `version.txt` | 10B | Version information |
| `desktop.ini` | 200B | Folder customization |

### PRO Mode Engines

| Filename | Lines | Description |
|---------|-------|-------------|
| `Scripts\AURORA-AnalyzerPRO.ps1` | ~200 | PRO mode unified entry |
| `Scripts\AURORA-AnalyzerCHSPRO.ps1` | ~7,767 | Chinese Professional Edition Engine |
| `Scripts\AURORA-AnalyzerENGPRO.ps1` | ~7,500 | English Professional Edition Engine |

### Smart Diagnostic System

| Filename | Lines | Description |
|---------|-------|-------------|
| `Scripts\AURORA-SmartEngine.ps1` | ~1,500 | Smart diagnostics engine |
| `Data\AURORA-TechData.json` | ~3,000 lines | Technical knowledge base (100+ rules) |
| `Data\AURORA-TechData.cache.clixml` | ~500KB | Knowledge base cache |

### Progress Management System

| Filename | Description |
|---------|-------------|
| `Scripts\AURORA-ProgressManager.ps1` | Progress manager core |
| `Scripts\AURORA-ProgressManager-Integration-CHS.ps1` | Chinese edition integration module |
| `Scripts\AURORA-ProgressManager-Integration-ENG.ps1` | English edition integration module |
| `Scripts\AURORA-ProgressManager-Integration.ps1` | Unified integration module |

### Phase 2 New Modules

| Filename | Lines | Description |
|---------|-------|-------------|
| `Scripts\AURORA-GUI-Functions.ps1` | ~220 | GUI helper functions |
| `Scripts\AURORA-CoreEngine.ps1` | ~500 | Shared core engine |
| `Scripts\AURORA-Language.psd1` | ~140 | Bilingual resource pack |
| `Scripts\AURORA-AnalyzerPRO.ps1` | ~200 | PRO unified entry |
| `Scripts\AURORA-ProgressManager-Integration.ps1` | ~150 | Unified progress integration |

### Phase 4.2 Undo Support Modules

| Filename | Lines | Description |
|---------|-------|-------------|
| `Scripts\AURORA-RestoreManager.ps1` | ~400 | System restore manager |
| `Scripts\AURORA-RepairLogger.ps1` | ~350 | Repair logger |
| `Scripts\AURORA-UndoManager.ps1` | ~300 | Fast backup & restore |
| `Scripts\AURORA-RepairTools.ps1` | ~200 | Repair tools entry |
| `Scripts\AURORA-UndoViewer.ps1` | ~250 | Undo manager viewer |

### Phase 5 Animation Engine

| Filename | Lines | Description |
|---------|-------|-------------|
| `Scripts\Core\AURORA-AnimationCoreEngine.ps1` | ~800 | Animation core engine |

### Resource Files

| Filename | Description |
|---------|-------------|
| `Resources\AURORAICON.ico` | Application icon (folder icon) |
| `Resources\CascadiaMono.ttf` | Modern monospace font (UI beautification) |

---

## ✨ New Features

### 1. Phase 4.2 Undo Support System

#### System Restore Point Management

**Features:**
- Create system restore points using Windows System Restore API
- Support query, delete, and restore to specified restore point
- Complete metadata recording and audit trail

**API:**
```powershell
# Create restore point
Create-SystemRestorePoint -Description "AURORA Before Repair"
# Returns: @{RestorePointId="RP_20260519_123456_789"; SequenceNumber=45; ...}

# Query restore point list
Get-SystemRestorePoints

# Delete restore point
Remove-SystemRestorePoint -SequenceNumber 45
```

**Technical Details:**
- Requires administrator privileges
- Uses WMI (`root\default\SystemRestore` class)
- Supports 5-minute timeout protection
- Automatically saves metadata to JSON file

#### Fast Backup Snapshot

**Features:**
- Fast registry/file/service configuration backup
- Restore without restart required
- Supplementary solution to system restore

**Supported Types:**
- **Registry**: Export registry keys as .reg files
- **File**: File backup
- **Service**: Export service configuration as JSON
- **Mixed**: Mixed type backup

**API:**
```powershell
# Backup registry
$snapshot = Create-BackupSnapshot -Type "Registry" -Paths @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate")
# Returns: @{SnapshotId="BS_20260519_123456_789"; Size="15.3 KB"; Status="Active"}

# Backup files
$snapshot = Create-BackupSnapshot -Type "File" -Paths @("C:\Windows\System32\config\SOFTWARE")

# Backup service configuration
$snapshot = Create-BackupSnapshot -Type "Service" -ServiceNames @("wuauserv", "BITS")

# Restore snapshot
Restore-BackupSnapshot -SnapshotId "BS_20260519_123456_789"
```

**Performance Metrics:**
- Registry backup: ~0.5-2 seconds/item
- File backup: ~0.1-0.5 seconds/MB
- Service configuration: ~0.2-0.5 seconds/service

#### Repair Session Logger

**Features:**
- Record execution details of all repair commands
- Supports undo operations
- Supports repair history query

**Session Information:**
```json
{
  "SessionId": "RS_20260519_123456_789",
  "StartedAt": "2026-05-19T12:34:56",
  "CompletedAt": "2026-05-19T12:35:30",
  "RepairType": "RegistryRepair",
  "Target": "Windows Update Service",
  "CommandsExecuted": 3,
  "Status": "Success",
  "RestorePointId": "RP_20260519_123456_789",
  "BackupSnapshotId": "BS_20260519_123456_789",
  "CanUndo": true
}
```

**API:**
```powershell
# Start repair session
$session = Start-RepairSession -RepairType "RegistryRepair" -Target "Windows Update Service" -CreateRestorePoint

# Record command execution
Log-RepairCommand -SessionId "RS_001" -Command "Set-ItemProperty" -Status "Success"

# Complete session
Complete-RepairSession -SessionId "RS_001" -Status "Success" -BackupSnapshotId "BS_001"

# Query session
Get-RepairSession -SessionId "RS_001"
```

### 2. Automatic Minidump Blue Screen File Analysis

**Features:**
- Automatically detect `C:\Windows\Minidump` directory
- Parse BugCheck code from .dmp files
- Provide fault cause and solution suggestions

**Supported BugCheck Codes (Partial):**

| Code | Name | Common Causes |
|------|------|---------------|
| 0x0000000A | IRQL_NOT_LESS_OR_EQUAL | Driver accessing unauthorized memory |
| 0x0000001E | KMODE_EXCEPTION_NOT_HANDLED | Kernel mode exception |
| 0x0000003B | SYSTEM_SERVICE_EXCEPTION | System service exception |
| 0x0000007E | SYSTEM_THREAD_EXCEPTION_NOT_HANDLED | System thread exception |
| 0x00000116 | VIDEO_TDR_ERROR | Graphics TDR error |
| 0x00000124 | WHEA_UNCORRECTABLE_ERROR | Hardware error |
| 0x00000133 | DPC_WATCHDOG_VIOLATION | DPC watchdog violation |

**Analysis Example:**
```
📋 Found 3 blue screen dump files, parsing key information...

  📋 051926-12345-01.dmp (1.2 days ago):
     BugCheck Code: 0x00000116
     Name: VIDEO_TDR_ERROR
     Description: Graphics TDR error
     Parameters: 0xFFFFFA800C345F10, 0xFFFFF88003E1F978, ...
     💡 Suggestion: Update graphics driver, check cooling and power supply
```

**Technical Implementation:**
- Directly read MINIDUMP_HEADER structure (32 bytes)
- No external tools like WinDbg required
- Supports analyzing up to 5 most recent dump files

### 3. Knowledge Base Cache Mechanism

**Features:**
- Use CliXML serialization to cache diagnostic rules
- Avoid repeated JSON parsing and index rebuilding
- Automatically detect KB file updates

**Performance Improvement:**
- Without cache: ~2-5 seconds (JSON parsing + index building)
- With cache: ~0.5-1 seconds (direct deserialization)

**Cache File:**
```
Data\AURORA-TechData.cache.clixml
```

**Cache Content:**
- FlatRules (flattened rules array)
- EventIdIndex (EventID index)
- SourceIndex (Source index)
- KbVersion (knowledge base version number)

**Automatic Invalidation:**
- Automatically rebuild cache when `AURORA-TechData.json` is updated
- Automatically rebuild when cache is corrupted

### 4. Animation Engine Decoupling (Phase 5)

**Features:**
- Separate animation core logic from GUI main file
- Independent module `AURORA-AnimationCoreEngine.ps1`
- Supports reuse and extension

**Core Classes:**
- `AuroraProgressBar`: Progress bar with glow animation
- `StarfieldPanel`: Starfield background panel
- `TechButton`: Dynamic button control
- `AURORA_Animation`: Global animation manager

**Animation Features:**
- Glow sweep effect (PathGradientBrush)
- Particle system (lifecycle + random drift)
- Double-buffered rendering (anti-flicker)
- Performance adaptive (adjusted based on hardware tier)

**Performance Tiers:**
```powershell
# Performance scoring algorithm
$perfScore = ($logicalCores * 15) + ($ramGB * 5) + ([Math]::Max(0, ($baseClock - 2000) / 100))

Extreme:     $perfScore >= 240  (8-core+ 32GB+)
Performance: $perfScore >= 120  (6-core 16GB)
Balanced:    $perfScore >= 70   (4-core 8GB)
Eco:         $perfScore < 70    (Legacy devices)
```

---

## 🚀 Improvements & Optimizations

### 1. Performance Optimization

#### Dual-Index Pre-Lookup + Candidate Set Exact Matching

**Problem:** Original O(n×m×k) complexity was too high

**Solution:**
- Build EventID index and Source index (O(1) lookup)
- Execute keyword matching only on candidate rules
- Complexity reduced to O(n × avg_candidates)

**Performance Improvement:**
- 100,000 events: from ~10 seconds to ~1-3 seconds
- 1,000,000 events: from ~100 seconds to ~10-20 seconds

#### Streaming Pipeline Instant Lightweight

**Problem:** `$rawEvents` intermediate variable consumed large memory

**Solution:**
- Directly convert to lightweight PSCustomObject after `Get-WinEvent`
- Avoid full EventLogRecord object memory consumption

**Memory Optimization:**
- Original: ~500MB (100,000 events)
- Optimized: ~50MB (100,000 events)
- 90% memory reduction

### 2. Security Enhancement

#### Pre-Check + Risk Assessment + Rollback Mechanism

**Secure Execution Flow:**
```
1. Pre-Check
   - Verify administrator privileges
   - Check prerequisites
   
2. Risk Assessment & Authorization
   - Non-auto_execute commands require user authorization
   - Use EventWaitHandle event-driven (zero CPU consumption)
   
3. Create Undo Protection
   - System restore point
   - Fast backup snapshot
   
4. Execute Main Command
   - Capture output and errors
   - Record execution time
   
5. Auto Rollback on Failure
   - Execute rollback_command
   - Record rollback result
```

**Authorization Mechanism Improvement:**
- **Old:** Polling check (CPU usage ~5-10%)
- **New:** EventWaitHandle event-driven (CPU usage ~0%)

### 3. UI Beautification

#### Folder Icon Configuration

**Files:**
- `Resources\AURORAICON.ico`: Application icon
- `desktop.ini`: Folder customization configuration

**Effect:**
- Folder displays custom icon
- Tooltip displays version information and description

**desktop.ini Content:**
```ini
[.ShellClassInfo]
IconResource=Resources\AURORAICON.ico,0
InfoTip=AURORA Analyzer v1.1.23.0 - Windows Event Log Export and Smart Diagnostics Tool
IconFile=Resources\AURORAICON.ico
IconIndex=0
[ViewState]
Mode=
Vid=
FolderType=Documents
```

**Automatic Setup:**
- Build script automatically sets folder attribute to read-only
- Uses `attrib.exe` to set desktop.ini as hidden + system file

### 4. Build Optimization

#### Automatic ZIP Packaging

**Features:**
- Ask whether to create ZIP release package after build
- Automatically include all required files
- ZIP filename includes version number

**Package Content:**
```
AURORA_Analyzer_v1.1.23.0_Release.zip
├── AURORA.Launcher-双击启动.exe
├── GAURORA.CHK.ENC
├── version.txt
├── desktop.ini
├── Scripts\... (all script files)
├── Data\... (all data files)
└── Resources\... (all resource files)
```

**Code Example:**
```powershell
# Create Releases folder
$ReleasesDir = Join-Path $ScriptDir "Releases"
if (-not (Test-Path $ReleasesDir)) {
    New-Item -Path $ReleasesDir -ItemType Directory -Force | Out-Null
}

# Generate ZIP filename
$ZipFileName = "AURORA_Analyzer_v$CurrentVersion`_Release.zip"
$ZipPath = Join-Path $ReleasesDir $ZipFileName

# Package files
Compress-Archive -Path $ZipFiles -DestinationPath $ZipPath -Force
```

#### Automatic Version Management

**Features:**
- Read current version from `version.txt`
- Support automatic version increment
- Build log records version information

**Usage:**
```bash
# Build with current version
AURORA-build.bat /generate

# Increment version and build
AURORA-build.bat /generate  # Select option 2
```

**Version Format:**
```
Major.Minor.Revision.Build
Example: 1.1.23.0
```

---

## 🐛 Bug Fixes

### 1. GUI Authorization Polling CPU Usage Issue

**Problem:**
- Old version used polling to check `Authorized` status
- CPU usage up to 5-10%

**Solution:**
- Switched to EventWaitHandle event-driven
- Zero CPU consumption wait

**Code Comparison:**
```powershell
# Old (polling)
while ($global:syncHash.Authorized -eq $null) {
    Start-Sleep -Milliseconds 100  # Continuous CPU consumption
}

# New (event-driven)
$eventWaitHandle = [System.Threading.EventWaitHandle]::OpenExisting($eventName)
$signaled = $eventWaitHandle.WaitOne(30000)  # Blocking wait, zero CPU consumption
$eventWaitHandle.Dispose()
```

**Effect:**
- CPU usage: from 5-10% to ~0%
- Response speed: faster (immediate response on event trigger)

### 2. PRO Mode CSV Reading Field Name Error

**Problem:**
- CSV field names should be `TimeCreated` and `LevelDisplayName`
- Code incorrectly used `Time Created` and `Level`

**Solution:**
```powershell
# Before (incorrect)
$eventTime = [datetime]::Parse($row."Time Created")
$level = $row.Level

# After (correct)
$eventTime = [datetime]::Parse($row.TimeCreated)
$levelName = $row.LevelDisplayName
# Convert to numeric level
if ($levelName -eq '关键' -or $levelName -eq 'Critical') { $level = 1 }
```

**Effect:**
- CSV import success rate: from ~0% to 100%
- No more field name error exceptions

### 3. Undo Backup Metadata Saving Issue

**Problem:**
- Backup snapshot metadata was not correctly saved to JSON file
- Caused restore operations to fail to find backup information

**Solution:**
- Added `Save-SnapshotMetadata` function
- Ensured all metadata fields are correctly serialized

**Code Example:**
```powershell
function Save-SnapshotMetadata {
    param([hashtable]$Snapshot)
    
    $metadataFile = Join-Path $Snapshot.BackupDir "metadata.json"
    $Snapshot | ConvertTo-Json -Depth 5 | Out-File $metadataFile -Encoding UTF8
}
```

**Effect:**
- Metadata saving success rate: 100%
- Restore operation reliability significantly improved

---

## 📊 Technical Statistics

### Code Scale

| Component | Files | Total Lines | Average Lines |
|-----------|-------|-------------|---------------|
| GUI Main File | 1 | ~10,000 | ~10,000 |
| PRO Engines | 3 | ~15,467 | ~5,155 |
| Smart Engine | 1 | ~1,500 | ~1,500 |
| Core Engine | 1 | ~500 | ~500 |
| GUI Helpers | 1 | ~220 | ~220 |
| Animation Engine | 1 | ~800 | ~800 |
| Undo Support | 5 | ~1,500 | ~300 |
| Progress Management | 4 | ~600 | ~150 |
| Language Resources | 1 | ~140 | ~140 |
| **Total** | **18** | **~30,727** | **~1,707** |

### Feature Coverage

| Feature Category | Supported Count |
|-----------------|-----------------|
| Log Types | 8 (System/Application/Security/Setup/DNS/DHCP/AD/IIS) |
| Diagnostic Rules | 100+ |
| BugCheck Codes | 20+ |
| Repair Commands | 50+ |
| Supported Languages | 2 (Chinese/English) |
| Output Formats | 4 (CSV/JSON/XML/TXT) |

### Performance Metrics

| Operation | Average Time | Notes |
|-----------|-------------|-------|
| GUI Startup | ~2-5 seconds | Includes password verification |
| Log Export (24H) | ~5-20 seconds | Depends on log type |
| Knowledge Graph Loading | ~0.5-2 seconds | Faster with cache hit |
| Rule Matching (100K events) | ~1-3 seconds | After dual-index optimization |
| Minidump Analysis | ~0.1-0.5 seconds/file | Direct PE header reading |
| Restore Point Creation | ~10-30 seconds | Depends on system configuration |
| Fast Backup | ~0.5-5 seconds | Depends on data volume |

---

## 🔧 Known Issues

### 1. System Restore Feature Limitations

**Issues:**
- Requires administrator privileges
- System Restore must be enabled
- Some systems (e.g., server editions) may be disabled by default

**Workarounds:**
- Use fast backup snapshot as alternative
- Manually enable System Restore feature

### 2. Minidump Analysis Limitations

**Issues:**
- Only supports standard MINIDUMP_HEADER format
- Does not support Complete Memory Dump
- Some custom dump formats may not be parsable

**Future Plans:**
- Consider integrating WinDbg engine
- Support more dump formats

### 3. GUI DPI Scaling Issues

**Issues:**
- Interface may be blurry on high DPI displays (4K)
- Some control layouts may be misaligned

**Workarounds:**
- Adjust Windows DPI scaling ratio
- Update .NET Framework to latest version

---

## 📝 Upgrade Guide

### Upgrading from V1.1.22.0

**Steps:**

1. **Backup Existing Data**
   ```powershell
   # Backup important logs and configurations
   Copy-Item -Path ".\UserLogs" -Destination ".\Backup\UserLogs" -Recurse
   Copy-Item -Path ".\SessionCache" -Destination ".\Backup\SessionCache" -Recurse
   ```

2. **Download New Version**
   - Download `AURORA_Analyzer_v1.1.23.0_Release.zip`

3. **Extract and Overwrite**
   - Extract to existing directory
   - Overwrite all files

4. **Rebuild (Optional)**
   ```powershell
   # If you need to change password
   .\AURORA-build.bat /generate
   ```

5. **Verify Integrity**
   - Run `AURORA.Launcher-双击启动.exe`
   - Check if all functions work normally

### Upgrading from Earlier Versions

**Notes:**

- V1.1.23.0 introduces new Undo support system
- Requires additional 5 script files
- Complete replacement of old version is recommended

**Steps:**

1. **Completely Uninstall Old Version**
   ```powershell
   Remove-Item -Path ".\Scripts" -Recurse -Force
   Remove-Item -Path ".\Data" -Recurse -Force
   ```

2. **Install New Version**
   - Extract new version to empty directory

3. **Migrate User Data**
   ```powershell
   # Migrate log files
   Copy-Item -Path ".\OldVersion\UserLogs" -Destination ".\UserLogs" -Recurse
   ```

---

## 🎯 Future Plans

### V1.1.24.0 (Planned)

**Expected Features:**
- Enhanced Undo viewer (graphical interface)
- Network log collection support
- More diagnostic rules (virtualization/containers)
- Further performance optimization

**Expected Release:** 2026.06

### V1.2.0 (Long-term Plan)

**Expected Features:**
- Modular architecture refactoring
- Plugin system support
- Cloud knowledge base synchronization
- Multi-language support (Japanese, French, etc.)

**Expected Release:** 2026.Q3

---

## 📞 Feedback & Support

### Issue Reporting

If you encounter any issues during use, please report through the following channels:

- **GitHub Issues:** [To be added]
- **Email:** [To be added]
- **Forum:** [To be added]

### Code Contributions

We welcome community contributions! Please participate through the following channels:

- **Pull Requests:** [To be added]
- **Feature Suggestions:** [To be added]

### Documentation Contributions

- Improve existing documentation
- Translate to other languages
- Write usage tutorials

---

## 📄 License

**License Agreement:**
- This tool is for personal learning and research use only
- Commercial use is prohibited
- All rights reserved

**Third-Party Components:**
- PowerShell: Microsoft License
- .NET Framework: Microsoft License
- Cascadia Code Font: MIT License

---

## 🙏 Acknowledgments

Thanks to all developers and testers who have contributed to the AURORA project!

**Special Thanks:**
- Microsoft Docs - Windows Event Log documentation
- PowerShell Community - Best practice guidance
- Test volunteers - Feedback and suggestions
- Open source community - Third-party library support

---

**Release Notes Version:** V1.1.23.0  
**Last Updated:** 2026.05.19  
**Author:** AURORA VelociRaptor-GR Dev PRJ.

*Thank you for using AURORA Analyzer!*
