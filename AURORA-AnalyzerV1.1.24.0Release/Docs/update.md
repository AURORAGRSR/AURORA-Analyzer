# AURORA Analyzer V1.1.24.0 — 更新日志 / Changelog

**发布日期 / Release Date:** 2026.05.25  
**当前版本 / Current Version:** V1.1.24.0  
**上一版本 / Previous Version:** V1.1.23.0  
**作者 / Author:** AURORA VelociRaptor-GR Dev PRJ.  
**更新类型 / Update Type:** 重大安全架构更新 (Major Security Architecture Release)

---

## 🔐 安全更新 / Security Updates

### 1. 安全验证体系完全重构 / Complete Security Authentication System Overhaul

**RSA-2048 非对称加密握手协议 / RSA-2048 Asymmetric Handshake Protocol**
> EXE 持有私钥签发 Token，PS1 持有公钥验签，实现不可伪造的启动认证。彻底杜绝中间人仿冒启动请求的可能性。
>
> The EXE holds the private key to sign tokens, while PS1 holds the public key to verify signatures, achieving unforgeable launch authentication. This completely eliminates the possibility of man-in-the-middle spoofing of launch requests.

**AES-256-CBC 会话加密层 / AES-256-CBC Session Encryption Layer**
> 使用 PBKDF2(Nonce, SessionSalt) 派生会话密钥，保护哈希列表在传输过程中的机密性。即使通信被截获，攻击者也无法解密文件哈希列表。
>
> Uses PBKDF2(Nonce, SessionSalt) to derive session keys, protecting the confidentiality of the hash list during transmission. Even if the communication is intercepted, attackers cannot decrypt the file hash list.

**Token 时效性验证机制 / Token Expiration Validation Mechanism**
> 60 秒过期窗口 + 5 秒时钟偏移容差，彻底防止重放攻击。每个 Token 在签发后 60 秒内有效，超时自动作废。
>
> 60-second expiration window with 5-second clock skew tolerance, completely preventing replay attacks. Each token is valid for 60 seconds after issuance, automatically invalidating upon timeout.

### 2. 反逆向工程保护 / Anti-Reverse Engineering Protection

**C# 离线元数据混淆 / C# Offline Metadata Obfuscation**
> 类名和私有方法名在编译时随机重命名（Main 方法保留），增加逆向分析难度。即使攻击者获取了二进制文件，也难以理解代码结构和逻辑。
>
> Class names and private method names are randomly renamed at compile time (Main method preserved), increasing the difficulty of reverse engineering analysis. Even if attackers obtain the binary, they cannot easily understand the code structure and logic.

**反调试 / 反 Dump 保护 / Anti-Debugging / Anti-Dump Protection**
> IsDebuggerPresent 检测 + x64dbg / OllyDbg / Scylla / Phantom 模块检测，检测到调试器即静默退出。多层次的检测机制确保常见的逆向工具无法附加到进程。
>
> IsDebuggerPresent detection combined with x64dbg / OllyDbg / Scylla / Phantom module detection — silent exit upon debugger detection. Multi-layered detection ensures common reverse engineering tools cannot attach to the process.

### 3. 密码保护强化 / Password Protection Hardening

**密码双重混淆方案 / Dual Password Obfuscation Scheme**
> XOR 掩码 + 随机位置重排 (Shuffle) 嵌入 C# 源码，三个独立数组需同时获取才能还原。任何单一数据源的泄露都不足以还原原始密码。
>
> XOR masking combined with random position shuffling embedded in C# source code — three independent arrays must be simultaneously obtained to reconstruct the password. Leakage of any single data source is insufficient to recover the original password.

**Session Derivation Salt / 会话派生盐值**
> 32 字节随机盐，每次构建独立生成，参与哈希列表的会话加密。确保即使主密码不变，每次构建的加密密钥也完全不同。
>
> 32-byte random salt, independently generated for each build, participating in session encryption of the hash list. Ensures that even if the master password remains unchanged, the encryption key is completely different for each build.

---

## 🔧 运行时完整性监控重大增强 / Runtime Integrity Monitoring — Major Enhancements

> **概述 / Overview:** 本版本对运行时完整性监控系统进行了 9 项 P0 级修复，将攻击窗口从 10 秒间隔缩短至 3 秒基础间隔 + 随机扰动，并新增 FileSystemWatcher 实现零延迟文件级响应。
>
> This version introduces 9 P0-level fixes to the runtime integrity monitoring system, reducing the attack window from 10-second intervals to 3-second base intervals with random perturbation, and adds FileSystemWatcher for zero-latency file-level responses.

| # | 变更 / Change | 详细说明 / Details |
|---|--------------|-------------------|
| 1 | **检查间隔缩短至 3 秒 / Check Interval Reduced to 3 Seconds** | 攻击窗口减少 70%，从每 10 秒一次缩短至每 3 秒一次。Attack window reduced by 70%, from every 10 seconds to every 3 seconds. |
| 2 | **随机间隔 Timer / Randomized Timer Interval** | 2–7 秒随机触发，增加攻击者时间窗口预测难度。2–7 second random trigger, increasing the difficulty of predicting the attack time window. |
| 3 | **移除 break 语句 / Removed break Statement** | 不再提前终止检查，确保所有 19 个文件全部验证完毕。No longer prematurely terminates checks, ensuring all 19 files are fully verified. |
| 4 | **文件计数检查 / File Count Pre-Check** | 作为第一道快速防线，发现缺失立即标记。Acts as the first line of rapid defense — immediately flags any missing file count mismatch. |
| 5 | **FileSystemWatcher 实时监控 / Real-time FileSystemWatcher Monitoring** | Changed / Deleted / Renamed / Created 事件零延迟响应。Zero-latency response to Changed, Deleted, Renamed, and Created events. |
| 6 | **未授权文件创建检测 / Unauthorized File Creation Detection** | 新文件不在白名单中立即触发告警。New files not in the whitelist immediately trigger alerts. |
| 7 | **启动后 1 秒立即检查 / 1-Second Post-Launch Immediate Check** | 填补启动窗口期的安全漏洞。Closes the security gap during the startup window period. |
| 8 | **篡改响应增强 / Tamper Response Enhancement** | 关闭 Splash 屏和主窗口防止 UI 欺骗，显示所有缺失 / 篡改文件详情。Closes splash screen and main window to prevent UI spoofing, displays details of all missing/tampered files. |
| 9 | **退出时资源清理 / Exit-time Resource Cleanup** | Timer 停止、Watcher 关闭、全局变量清空。Timer stops, Watcher disposes, global variables cleared. |

---

## 🚀 新功能 / New Features

### 构建系统增强 / Build System Enhancements

**智能安全代码注入 / Intelligent Security Code Injection**
> `build.ps1` 自动检测已有注入状态（更新密钥 / 替换占位符 / 首次注入），无需手动清除旧构建产物即可重新构建。
>
> `build.ps1` automatically detects existing injection state (update key / replace placeholder / first-time injection), allowing rebuilds without manually clearing old build artifacts.

**交互式密码输入增强 / Enhanced Interactive Password Input**
> SecureString 输入 + 密码强度验证（大写 + 小写 + 数字 + 特殊字符）+ 3 次重试机会，确保密码满足企业级强度要求。
>
> SecureString input combined with password strength validation (uppercase + lowercase + digits + special characters) and 3 retry attempts, ensuring the password meets enterprise-grade strength requirements.

**构建日志增强 / Enhanced Build Logging**
> 详细的步骤记录、时间统计、文件清单，便于审计和问题排查。
>
> Detailed step logging, timing statistics, and file manifests for audit and troubleshooting purposes.

**SHA256 兼容计算 / SHA256 Compatibility Calculation**
> 兼容 PowerShell 4.0 以下版本的哈希计算，扩大构建脚本的兼容范围。
>
> Hash calculation compatible with PowerShell versions below 4.0, broadening the build script's compatibility range.

**desktop.ini 文件夹美化 / desktop.ini Folder Beautification**
> 自动生成 `desktop.ini` 实现 Windows 文件夹图标定制，提升项目目录的专业观感。
>
> Automatically generates `desktop.ini` for Windows folder icon customization, enhancing the professional appearance of the project directory.

**RSA 密钥诊断工具 / RSA Key Diagnostic Tool**
> 新增 `diagnose-rsa.ps1`，用于诊断签名验证问题，快速定位加密握手失败原因。
>
> Added `diagnose-rsa.ps1` for diagnosing signature verification issues and quickly identifying the cause of encryption handshake failures.

---

## 🐛 修复 / Bug Fixes

| # | 问题 / Issue | 修复方案 / Resolution |
|---|-------------|----------------------|
| 1 | **PwOrder 数组生成 / PwOrder Array Generation** | 直接生成 C# 数组初始化字符串，修复花括号格式问题。Directly generates C# array initialization strings, fixing brace formatting issues. |
| 2 | **RSA 公钥更新正则 / RSA Public Key Update Regex** | 使用多行匹配正确识别和替换已有公钥。Uses multi-line matching to correctly identify and replace existing public keys. |
| 3 | **内存清理 / Memory Cleanup** | `Array.Clear` + 三重 `GC.Collect` 确保敏感数据从内存彻底清除。`Array.Clear` combined with triple `GC.Collect` ensures sensitive data is thoroughly removed from memory. |
| 4 | **模块启动检测 / Module Launch Detection** | 所有子模块（SmartEngine / PRO / RepairTools / UndoViewer）统一支持 RSA 令牌验证。All sub-modules (SmartEngine / PRO / RepairTools / UndoViewer) now uniformly support RSA token verification. |
| 5 | **完整性检查作用域 / Integrity Check Scope** | 使用 `script:` 作用域变量确保 Timer 闭包能正确访问检查状态。Uses `script:` scoped variables to ensure Timer closures correctly access check state. |

---

## 📋 安全能力审计 / Security Capability Audit

本版本配套生成《AURORA Analyzer V1.1.24.0 安全能力审计报告》，涵盖以下内容：

> This version is accompanied by the *AURORA Analyzer V1.1.24.0 Security Capability Audit Report*, covering the following content:

| 章节 / Section | 内容 / Content |
|---------------|----------------|
| 执行摘要与安全评分 / Executive Summary & Security Score | 综合评分 8.6/10，评定为企业级安全标准。Overall score 8.6/10, rated as enterprise-grade security standard. |
| 四层安全架构全景分析 / Four-Layer Security Architecture Analysis | 启动验证层 → 会话加密层 → 运行时监控层 → 静态防护层。Launch auth → Session encryption → Runtime monitoring → Static protection. |
| 密码学原语清单与强度评估 / Cryptographic Primitives Inventory | RSA-2048、AES-256-CBC、PBKDF2、SHA256 的完整强度评估。Full strength assessment of RSA-2048, AES-256-CBC, PBKDF2, SHA256. |
| 威胁模型与攻击场景演练 / Threat Model & Attack Scenario Walkthrough | 模拟重放攻击、中间人攻击、内存 Dump、逆向分析等攻击场景。Simulated replay attacks, MITM attacks, memory dumps, reverse engineering, and more. |
| 已发现问题与改进建议 / Identified Issues & Improvement Recommendations | 13 项已发现问题及分级改进建议。13 identified issues with tiered improvement recommendations. |

---

## 📊 变更统计 / Change Statistics

| 指标 / Metric | 数值 / Value |
|--------------|-------------|
| **安全更新 / Security Updates** | 7 |
| **重大改进 / Major Enhancements** | 9 |
| **新增功能 / New Features** | 6 |
| **Bug 修复 / Bug Fixes** | 5 |
| **总计变更项 / Total Changes** | 27 |

---

**版权声明 / Copyright:** &copy; 2026 AURORA VelociRaptor-GR Dev PRJ. All rights reserved.