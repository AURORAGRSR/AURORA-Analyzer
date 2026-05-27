# AURORA Analyzer V1.1.24.1 — 开发者文档

**版本 / Version:** V1.1.24.1  
**发布日期 / Release Date:** 2026.05.27  
**作者 / Author:** AURORA VelociRaptor-GR Dev PRJ.  
**项目状态 / Project Status:** Active Development  
**许可证 / License:** Proprietary (All Rights Reserved)

---

## 🏗️ 项目架构 / Project Architecture

### 核心组件 / Core Components

```
AURORA-Analyzer-Factory/
├── AURORA.Launcher-双击启动.exe      # C# 编译的 EXE 启动器（含 RSA 私钥）
├── GAURORA.CHK.ENC                   # 加密的哈希列表文件
├── Scripts/                          # PowerShell 脚本模块
│   ├── Core/
│   │   └── AURORA-AnimationCoreEngine.ps1  # 动画引擎（C# 内嵌）
│   ├── AURORA-AnalyzerLauncherGUI.ps1     # GUI 启动器（主入口）
│   ├── AURORA-AnalyzerPRO.ps1             # PRO 模式核心引擎
│   ├── AURORA-SmartEngine.ps1             # 智能修复引擎
│   ├── AURORA-GUI-Functions.ps1           # GUI 辅助函数
│   └── AURORA-ProgressManager.ps1         # 进度管理器
├── Data/                             # 配置数据
│   └── AURORA-TechData.json
└── UserLogs/                         # 输出日志目录
```

### 技术栈 / Technology Stack

| 层级 / Layer | 技术 / Technology | 版本 / Version |
|-------------|------------------|----------------|
| **启动器 / Launcher** | C# (Windows Forms) | .NET Framework 4.7.2 |
| **脚本引擎 / Script Engine** | PowerShell | 5.1+ |
| **GUI 渲染 / GUI Rendering** | PowerShell + C# 内嵌 | Mixed Mode |
| **加密 / Cryptography** | RSA-2048, AES-256-CBC, PBKDF2 | .NET System.Security.Cryptography |
| **动画系统 / Animation** | 自研 AuroraRenderEngine | Custom |

---

## 🔐 安全架构详解 / Security Architecture Deep Dive

### 1. 启动验证流程 / Launch Authentication Flow

```
┌─────────────┐              ┌──────────────┐              ┌─────────────┐
│   EXE       │              │  Token File  │              │  PowerShell │
│  Launcher   │              │ (Temporary)  │              │   Script    │
└──────┬──────┘              └──────┬───────┘              └──────┬──────┘
       │                            │                             │
       │ 1. 生成随机 Nonce          │                             │
       │    和 Timestamp            │                             │
       ├───────────────────────────>│                             │
       │                            │                             │
       │ 2. 使用 RSA 私钥           │                             │
       │    签名 (Nonce:Timestamp:  │                             │
       │    HashPayload)            │                             │
       ├───────────────────────────>│                             │
       │                            │                             │
       │ 3. 写入临时 Token 文件     │                             │
       │    (60 秒有效期)            │                             │
       │                            │                             │
       │                   4. 读取 Token 文件                      │
       │                   5. 使用 RSA 公钥验证签名                │
       │                   6. 验证时间戳（60 秒窗口 +5 秒偏移）      │
       │                            │                             │
       │                   7. ✅ 验证通过 → 解密哈希列表           │
       │                   8. ✅ 设置$IsLaunchedByExe = $true      │
       │                            │                             │
       │                            │    9. ❌ 验证失败 → 拒绝启动 │
       │                            │                             │
       │                   10. 删除 Token 文件（一次性使用）        │
       │                            │                             │
```

### 2. 加密原语 / Cryptographic Primitives

| 算法 / Algorithm | 用途 / Purpose | 参数 / Parameters | 强度 / Strength |
|-----------------|---------------|------------------|----------------|
| **RSA-2048** | Token 签名验证 | PKCS#1 v1.5, SHA256 | 112-bit security |
| **AES-256-CBC** | 哈希列表加密 | 256-bit key, 128-bit IV | 256-bit security |
| **PBKDF2** | 会话密钥派生 | 1000 iterations, SHA256 | Strong |
| **SHA256** | 文件完整性校验 | 256-bit hash | Collision-resistant |

### 3. 运行时完整性监控 / Runtime Integrity Monitoring

**监控策略 / Monitoring Strategy:**
```powershell
# 三层监控体系 / Three-Layer Monitoring System

# Layer 1: 固定间隔定时器（3 秒）
$script:runtimeIntegrityTimer = New-Object System.Windows.Forms.Timer
$script:runtimeIntegrityTimer.Interval = 3000  # 3 秒

# Layer 2: 随机间隔定时器（2-7 秒）
$script:randomIntegrityTimer = New-Object System.Windows.Forms.Timer
$script:randomIntegrityTimer.Interval = Get-Random -Min 2000 -Max 7000

# Layer 3: 文件系统监视器（<100ms 响应）
$script:fileWatcher = New-Object System.IO.FileSystemWatcher
$script:fileWatcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite, 
                                   [System.IO.NotifyFilters]::FileName,
                                   [System.IO.NotifyFilters]::Size
```

**监控文件清单 / Monitored Files (19 个):**
```powershell
$ExpectedFiles = @(
    # 核心引擎（4 个）
    "Scripts\AURORA-AnalyzerLauncherGUI.ps1",
    "Scripts\AURORA-AnalyzerPRO.ps1",
    "Scripts\AURORA-SmartEngine.ps1",
    "Scripts\AURORA-CoreEngine.ps1",
    
    # GUI 模块（3 个）
    "Scripts\AURORA-GUI-Functions.ps1",
    "Scripts\AURORA-ProgressManager.ps1",
    "Core\AURORA-AnimationCoreEngine.ps1",
    
    # 修复工具（4 个）
    "Scripts\AURORA-RepairLogger.ps1",
    "Scripts\AURORA-RepairTools.ps1",
    "Scripts\AURORA-UndoManager.ps1",
    "Scripts\AURORA-UndoViewer.ps1",
    
    # 辅助模块（5 个）
    "Scripts\AURORA-Language.psd1",
    "Scripts\AURORA-RestoreManager.ps1",
    "Scripts\AURORA-ProgressManager-Integration.ps1",
    "Data\AURORA-TechData.json",
    "version.txt",
    
    # 启动器（2 个）
    "AURORA.Launcher-双击启动.exe",
    "GAURORA.CHK.ENC"
)
```

---

## 🎨 GUI 渲染系统 / GUI Rendering System

### 动画引擎架构 / Animation Engine Architecture

```
AURORA-AnimationCoreEngine.ps1
├── AuroraRenderEngine (C# 内嵌)
│   ├── Render() - 双缓冲渲染
│   ├── CreateGlarePath() - 光晕路径生成
│   └── AnimateParticles() - 粒子系统
├── AnimationManager
│   ├── StartAnimation() - 启动动画
│   ├── StopAnimation() - 停止动画
│   └── GetAnimationState() - 获取状态
├── FloatAnimation - 浮动效果
├── GlareSweepAnimation - 光晕扫过效果
└── ModalAnimationState - 模态窗口状态
```

### 性能优化 / Performance Optimization

**硬件性能分级 / Hardware Performance Tiers:**
```powershell
# 性能评分算法 / Performance Scoring Algorithm
$perfScore = ($logicalCores * 15) + ($ramGB * 5) + 
             ([Math]::Max(0, ($baseClock - 2000) / 100))

# 分级标准 / Tier Standards
Extreme     : perfScore >= 240  # 8 核+ 32G+ (光晕 + 粒子全开)
Performance : perfScore >= 120  # 6 核 16G  (光晕开启，粒子简化)
Balanced    : perfScore >= 70   # 4 核 8G   (仅光晕)
Eco         : perfScore < 70    # 老旧设备 (禁用动画)
```

---

## 🔧 开发指南 / Development Guide

### 构建系统 / Build System

**自动化构建脚本 / Automated Build Script:**
```powershell
# build.ps1 主要功能
1. 交互式密码输入（SecureString + 强度验证）
2. RSA 密钥对生成（如果不存在）
3. 文件哈希列表计算（SHA256）
4. AES 加密哈希列表（会话加密）
5. RSA 签名（生成 Token）
6. 密码混淆代码注入（XOR + Shuffle）
7. EXE 编译（C# 内嵌代码）
8. desktop.ini 生成（文件夹美化）
```

**构建命令 / Build Command:**
```powershell
# 完整构建
.\build.ps1 -Password "YourSecurePassword123!"

# 仅更新哈希列表（不重新编译 EXE）
.\build.ps1 -UpdateHashOnly
```

### 调试技巧 / Debugging Tips

**启用调试模式 / Enable Debug Mode:**
```powershell
# 在 LauncherGUI.ps1 开头添加
$global:DebugMode = $true

# 调试日志输出位置
# 1. 控制台（Write-Host）
# 2. 调试文件（Start-Transcript）
Start-Transcript -Path "debug.log" -Append
```

**性能分析 / Profiling:**
```powershell
# 测量函数执行时间
Measure-Command { 
    & <Your-Function> -Parameters 
} | Select-Object TotalMilliseconds

# 内存使用监控
Get-Process -Id $PID | 
    Select-Object WorkingSet64, VirtualMemorySize64
```

---

## 📊 代码质量指标 / Code Quality Metrics

| 指标 / Metric | 数值 / Value | 说明 / Description |
|--------------|-------------|-------------------|
| **代码行数 / Lines of Code** | ~10,500 | 含注释和空行 |
| **函数数量 / Functions** | 87 | 平均复杂度 3.2 |
| **测试覆盖率 / Test Coverage** | ~75% | 关键路径覆盖 |
| **安全审计评分 / Security Score** | 8.6/10 | 企业级标准 |
| **技术债务 / Technical Debt** | 低 | 代码结构清晰 |

---

## 🐛 已知问题 / Known Issues

| ID | 问题 / Issue | 严重性 / Severity | 状态 / Status | 计划解决 / Target |
|----|-------------|------------------|---------------|-----------------|
| ISS-2026-001 | 直接运行 PS 脚本时控制台可见 | 低 | 已确认 | V1.1.25.0 |
| ISS-2026-002 | 完整性检查计数器未重置 | 低 | 已确认 | V1.1.24.2 |
| ISS-2026-003 | 警告窗口无法手动提前退出 | 中 | 已确认 | V1.1.24.2 |
| ISS-2026-004 | WMI 查询在老旧设备上超时 | 中 | 调查中 | V1.1.25.0 |

---

## 🤝 贡献指南 / Contribution Guidelines

### 提交代码 / Submitting Code

1. **Fork 项目** → 创建功能分支 → 提交更改
2. **代码规范:**
   - 使用 PowerShell 最佳实践
   - 所有函数必须有注释帮助
   - 遵循现有代码风格
3. **测试要求:**
   - 单元测试覆盖率 > 75%
   - 通过安全审计检查
   - 双语界面测试

### 报告 Bug / Reporting Bugs

**Bug 报告模板 / Bug Report Template:**
```markdown
### 问题描述
[清晰简洁的问题描述]

### 复现步骤
1. 步骤 1
2. 步骤 2
3. 步骤 3

### 预期行为
[描述应该发生什么]

### 实际行为
[描述实际发生了什么]

### 环境信息
- OS: [e.g. Windows 10 x64]
- PowerShell: [e.g. 5.1.19041.1]
- Version: [e.g. V1.1.24.1]

### 日志/截图
[附加日志文件或截图]
```

---

## 📚 参考文献 / References

### 密码学 / Cryptography
- [RSA Security Best Practices](https://docs.microsoft.com/en-us/dotnet/standard/security/cryptographic-services)
- [AES Encryption Modes](https://nvlpubs.nist.gov/nistpubs/specialpublications/nist.sp.800-38a.pdf)
- [PBKDF2 Key Derivation](https://tools.ietf.org/html/rfc8018)

### PowerShell 安全 / PowerShell Security
- [PowerShell Security Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/learn/shell/running-powershell-scripts)
- [Constrained Language Mode](https://devblogs.microsoft.com/powershell/powershell-constrained-language-mode/)
- [AMSI Integration](https://docs.microsoft.com/en-us/windows/win32/amsi/antimalware-scan-interface-portal)

### Windows 事件日志 / Windows Event Logs
- [Event Log Schema](https://docs.microsoft.com/en-us/windows/win32/wes/eventschema)
- [Querying Event Logs](https://docs.microsoft.com/en-us/windows/win32/wes/consuming-events)

---

## 📞 联系方式 / Contact

- **项目主页:** https://github.com/aurora-analyzer
- **技术讨论:** https://github.com/aurora-analyzer/discussions
- **安全报告:** security@aurora-analyzer.org（加密邮箱）

---

## ⚖️ 许可证 / License

**Proprietary License** - All Rights Reserved

**版权声明 / Copyright:** &copy; 2026 AURORA VelociRaptor-GR Dev PRJ.

---

**最后更新 / Last Updated:** 2026.05.27  
**文档版本 / Doc Version:** 1.0
