# AURORA Analyzer V1.1.24.1 — Developer Documentation

**Version:** V1.1.24.1  
**Release Date:** 2026.05.27  
**Author:** AURORA VelociRaptor-GR Dev PRJ.  
**Project Status:** Active Development  
**License:** Proprietary (All Rights Reserved)

---

## 🏗️ Project Architecture

### Core Components

```
AURORA-Analyzer-Factory/
├── AURORA.Launcher-双击启动.exe      # C# compiled EXE launcher (with RSA private key)
├── GAURORA.CHK.ENC                   # Encrypted hash list file
├── Scripts/                          # PowerShell script modules
│   ├── Core/
│   │   └── AURORA-AnimationCoreEngine.ps1  # Animation engine (C# embedded)
│   ├── AURORA-AnalyzerLauncherGUI.ps1     # GUI launcher (main entry point)
│   ├── AURORA-AnalyzerPRO.ps1             # PRO mode core engine
│   ├── AURORA-SmartEngine.ps1             # Smart repair engine
│   ├── AURORA-GUI-Functions.ps1           # GUI helper functions
│   └── AURORA-ProgressManager.ps1         # Progress manager
├── Data/                             # Configuration data
│   └── AURORA-TechData.json
└── UserLogs/                         # Output log directory
```

### Technology Stack

| Layer | Technology | Version |
|-------|------------|---------|
| **Launcher** | C# (Windows Forms) | .NET Framework 4.7.2 |
| **Script Engine** | PowerShell | 5.1+ |
| **GUI Rendering** | PowerShell + C# Embedded | Mixed Mode |
| **Cryptography** | RSA-2048, AES-256-CBC, PBKDF2 | .NET System.Security.Cryptography |
| **Animation System** | Custom AuroraRenderEngine | Custom |

---

## 🔐 Security Architecture Deep Dive

### 1. Launch Authentication Flow

```
┌─────────────┐              ┌──────────────┐              ┌─────────────┐
│   EXE       │              │  Token File  │              │  PowerShell │
│  Launcher   │              │ (Temporary)  │              │   Script    │
└──────┬──────┘              └──────┬───────┘              └──────┬──────┘
       │                            │                             │
       │ 1. Generate random Nonce   │                             │
       │    and Timestamp           │                             │
       ├───────────────────────────>│                             │
       │                            │                             │
       │ 2. Sign using RSA private  │                             │
       │    key (Nonce:Timestamp:   │                             │
       │    HashPayload)            │                             │
       ├───────────────────────────>│                             │
       │                            │                             │
       │ 3. Write temporary Token   │                             │
       │    file (60s validity)     │                             │
       │                            │                             │
       │                   4. Read Token file                      │
       │                   5. Verify signature using RSA public key│
       │                   6. Verify timestamp (60s window +5s skew)│
       │                            │                             │
       │                   7. ✅ Success → Decrypt hash list       │
       │                   8. ✅ Set $IsLaunchedByExe = $true      │
       │                            │                             │
       │                            │    9. ❌ Fail → Reject launch│
       │                            │                             │
       │                   10. Delete Token file (one-time use)    │
       │                            │                             │
```

### 2. Cryptographic Primitives

| Algorithm | Purpose | Parameters | Strength |
|-----------|---------|------------|----------|
| **RSA-2048** | Token signature verification | PKCS#1 v1.5, SHA256 | 112-bit security |
| **AES-256-CBC** | Hash list encryption | 256-bit key, 128-bit IV | 256-bit security |
| **PBKDF2** | Session key derivation | 1000 iterations, SHA256 | Strong |
| **SHA256** | File integrity hashing | 256-bit hash | Collision-resistant |

### 3. Runtime Integrity Monitoring

**Monitoring Strategy:**
```powershell
# Three-Layer Monitoring System

# Layer 1: Fixed interval timer (3 seconds)
$script:runtimeIntegrityTimer = New-Object System.Windows.Forms.Timer
$script:runtimeIntegrityTimer.Interval = 3000  # 3 seconds

# Layer 2: Randomized interval timer (2-7 seconds)
$script:randomIntegrityTimer = New-Object System.Windows.Forms.Timer
$script:randomIntegrityTimer.Interval = Get-Random -Min 2000 -Max 7000

# Layer 3: File system watcher (<100ms response)
$script:fileWatcher = New-Object System.IO.FileSystemWatcher
$script:fileWatcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite, 
                                   [System.IO.NotifyFilters]::FileName,
                                   [System.IO.NotifyFilters]::Size
```

**Monitored Files (19 total):**
```powershell
$ExpectedFiles = @(
    # Core engines (4 files)
    "Scripts\AURORA-AnalyzerLauncherGUI.ps1",
    "Scripts\AURORA-AnalyzerPRO.ps1",
    "Scripts\AURORA-SmartEngine.ps1",
    "Scripts\AURORA-CoreEngine.ps1",
    
    # GUI modules (3 files)
    "Scripts\AURORA-GUI-Functions.ps1",
    "Scripts\AURORA-ProgressManager.ps1",
    "Core\AURORA-AnimationCoreEngine.ps1",
    
    # Repair tools (4 files)
    "Scripts\AURORA-RepairLogger.ps1",
    "Scripts\AURORA-RepairTools.ps1",
    "Scripts\AURORA-UndoManager.ps1",
    "Scripts\AURORA-UndoViewer.ps1",
    
    # Helper modules (5 files)
    "Scripts\AURORA-Language.psd1",
    "Scripts\AURORA-RestoreManager.ps1",
    "Scripts\AURORA-ProgressManager-Integration.ps1",
    "Data\AURORA-TechData.json",
    "version.txt",
    
    # Launchers (2 files)
    "AURORA.Launcher-双击启动.exe",
    "GAURORA.CHK.ENC"
)
```

---

## 🎨 GUI Rendering System

### Animation Engine Architecture

```
AURORA-AnimationCoreEngine.ps1
├── AuroraRenderEngine (C# embedded)
│   ├── Render() - Double-buffered rendering
│   ├── CreateGlarePath() - Glare path generation
│   └── AnimateParticles() - Particle system
├── AnimationManager
│   ├── StartAnimation() - Start animation
│   ├── StopAnimation() - Stop animation
│   └── GetAnimationState() - Get state
├── FloatAnimation - Float effect
├── GlareSweepAnimation - Glare sweep effect
└── ModalAnimationState - Modal window state
```

### Performance Optimization

**Hardware Performance Tiers:**
```powershell
# Performance Scoring Algorithm
$perfScore = ($logicalCores * 15) + ($ramGB * 5) + 
             ([Math]::Max(0, ($baseClock - 2000) / 100))

# Tier Standards
Extreme     : perfScore >= 240  # 8-core+ 32G+ (Full glare + particles)
Performance : perfScore >= 120  # 6-core 16G  (Glare enabled, simplified particles)
Balanced    : perfScore >= 70   # 4-core 8G   (Glare only)
Eco         : perfScore < 70    # Legacy hardware (Animations disabled)
```

---

## 🔧 Development Guide

### Build System

**Automated Build Script:**
```powershell
# build.ps1 main features
1. Interactive password input (SecureString + strength validation)
2. RSA key pair generation (if not exists)
3. File hash list calculation (SHA256)
4. AES encrypt hash list (session encryption)
5. RSA signature (generate Token)
6. Password obfuscation code injection (XOR + Shuffle)
7. EXE compilation (C# embedded code)
8. desktop.ini generation (folder beautification)
```

**Build Commands:**
```powershell
# Full build
.\build.ps1 -Password "YourSecurePassword123!"

# Update hash list only (without recompiling EXE)
.\build.ps1 -UpdateHashOnly
```

### Debugging Tips

**Enable Debug Mode:**
```powershell
# Add at beginning of LauncherGUI.ps1
$global:DebugMode = $true

# Debug log output locations
# 1. Console (Write-Host)
# 2. Debug file (Start-Transcript)
Start-Transcript -Path "debug.log" -Append
```

**Performance Profiling:**
```powershell
# Measure function execution time
Measure-Command { 
    & <Your-Function> -Parameters 
} | Select-Object TotalMilliseconds

# Memory usage monitoring
Get-Process -Id $PID | 
    Select-Object WorkingSet64, VirtualMemorySize64
```

---

## 📊 Code Quality Metrics

| Metric | Value | Description |
|--------|-------|-------------|
| **Lines of Code** | ~10,500 | Including comments and blank lines |
| **Functions** | 87 | Average complexity 3.2 |
| **Test Coverage** | ~75% | Critical path coverage |
| **Security Audit Score** | 8.6/10 | Enterprise-grade standard |
| **Technical Debt** | Low | Clear code structure |

---

## 🐛 Known Issues

| ID | Issue | Severity | Status | Target |
|----|-------|----------|--------|--------|
| ISS-2026-001 | Console window visible when running PS script directly | Low | Confirmed | V1.1.25.0 |
| ISS-2026-002 | Integrity check counter not reset | Low | Confirmed | V1.1.24.2 |
| ISS-2026-003 | Cannot manually exit early during warning countdown | Medium | Confirmed | V1.1.24.2 |
| ISS-2026-004 | WMI query timeout on legacy devices | Medium | Investigating | V1.1.25.0 |

---

## 🤝 Contribution Guidelines

### Submitting Code

1. **Fork project** → Create feature branch → Commit changes
2. **Code Standards:**
   - Use PowerShell best practices
   - All functions must have comment help
   - Follow existing code style
3. **Testing Requirements:**
   - Unit test coverage > 75%
   - Pass security audit checks
   - Bilingual interface testing

### Reporting Bugs

**Bug Report Template:**
```markdown
### Problem Description
[Clear and concise problem description]

### Reproduction Steps
1. Step 1
2. Step 2
3. Step 3

### Expected Behavior
[Describe what should happen]

### Actual Behavior
[Describe what actually happened]

### Environment Information
- OS: [e.g. Windows 10 x64]
- PowerShell: [e.g. 5.1.19041.1]
- Version: [e.g. V1.1.24.1]

### Logs/Screenshots
[Attach log files or screenshots]
```

---

## 📚 References

### Cryptography
- [RSA Security Best Practices](https://docs.microsoft.com/en-us/dotnet/standard/security/cryptographic-services)
- [AES Encryption Modes](https://nvlpubs.nist.gov/nistpubs/specialpublications/nist.sp.800-38a.pdf)
- [PBKDF2 Key Derivation](https://tools.ietf.org/html/rfc8018)

### PowerShell Security
- [PowerShell Security Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/learn/shell/running-powershell-scripts)
- [Constrained Language Mode](https://devblogs.microsoft.com/powershell/powershell-constrained-language-mode/)
- [AMSI Integration](https://docs.microsoft.com/en-us/windows/win32/amsi/antimalware-scan-interface-portal)

### Windows Event Logs
- [Event Log Schema](https://docs.microsoft.com/en-us/windows/win32/wes/eventschema)
- [Querying Event Logs](https://docs.microsoft.com/en-us/windows/win32/wes/consuming-events)

---

## 📞 Contact

- **Project Homepage:** https://github.com/aurora-analyzer
- **Technical Discussions:** https://github.com/aurora-analyzer/discussions
- **Security Reports:** security@aurora-analyzer.org (encrypted email)

---

## ⚖️ License

**Proprietary License** - All Rights Reserved

**Copyright:** &copy; 2026 AURORA VelociRaptor-GR Dev PRJ.

---

**Last Updated:** 2026.05.27  
**Document Version:** 1.0
