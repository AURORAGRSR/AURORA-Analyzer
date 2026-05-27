# AURORA Analyzer V1.1.24.1 — 更新日志 / Changelog

**发布日期 / Release Date:** 2026.05.27
**当前版本 / Current Version:** V1.1.24.1
**上一版本 / Previous Version:** V1.1.24.0
**作者 / Author:** AURORA VelociRaptor-GR Dev PRJ.
**更新类型 / Update Type:** 安全加固与纵深防御增强 (Security Hardening & Defense-in-Depth Enhancement)

---

## 🛡️ 新增安全功能 / New Security Features

### 1. 命名管道看门狗守护 / Named Pipe Watchdog Guardian

> **概述 / Overview:** 在原有的 RSA 握手协议之上，新增了 EXE ↔ PS1 双向 HMAC-SHA256 挑战-响应心跳监测机制。即使所有 PS1 层面的验证被注释或绕过，EXE 看门狗仍能检测到异常并终止进程。这是纵深防御模型中的**第五层独立防护**。
>
> On top of the existing RSA handshake protocol, a bidirectional HMAC-SHA256 challenge-response heartbeat mechanism between the EXE and PS1 has been added. Even if all PS1-level verifications are commented out or bypassed, the EXE watchdog can still detect anomalies and terminate the process. This forms an **independent fifth defense layer** in the defense-in-depth model.

**核心机制 / Core Mechanism:**

| 组件 / Component | 描述 / Description |
|---|---|
| **HMAC 密钥派生 / HMAC Key Derivation** | PBKDF2-SHA256(MasterPassword, WatchdogSalt, 10,000 iterations) → 32 字节 HMAC 密钥。每次构建独立生成。PBKDF2-SHA256(MasterPassword, WatchdogSalt, 10,000 iterations) → 32-byte HMAC key. Independently generated per build. |
| **Named Pipe 通信 / Named Pipe Communication** | `AURORA_WD_{8位随机ID}` 命名管道，PipeDirection.InOut，Byte 传输模式。`AURORA_WD_{8-char random ID}` named pipe, PipeDirection.InOut, Byte transmission mode. |
| **握手协议 / Handshake Protocol** | EXE → PS1: `[0x10] [32B HMAC Key] [16B SessionID]`；PS1 → EXE: `[0x11]` ACK 确认。EXE → PS1: `[0x10] [32B HMAC Key] [16B SessionID]`; PS1 → EXE: `[0x11]` ACK confirm. |
| **挑战-响应 / Challenge-Response** | EXE: `[0x03] [16B Nonce] [8B Timestamp]` → PS1: `[0x04] [32B HMAC(Nonce,Key)] [8B SystemUptime] [32B SelfSHA256]` |
| **双定时器 / Dual Timer** | 5 秒固定间隔 + 2-7 秒随机间隔。5-second fixed interval + 2-7 second random interval. |
| **失败阈值 / Failure Threshold** | 连续 3 次失败 → EXE 立即 Kill PS1 进程。3 consecutive failures → EXE immediately kills the PS1 process. |
| **超时保护 / Timeout Protection** | 连接超时 15 秒，响应超时 3 秒。Connect timeout 15 seconds, response timeout 3 seconds. |

**攻击模型覆盖 / Attack Model Coverage:**

- 攻击者注释所有 PS1 验证代码 → EXE 看门狗独立检测 → Kill 进程
- 攻击者替换 PS1 脚本 → 自哈希不匹配 → 挑战失败 → Kill 进程
- 攻击者注入 Hook → 心跳丢失 → 3 次失败 → Kill 进程

---

### 2. C# 嵌入式完整性守卫 / Embedded C# Integrity Guard (AuroraGuard)

> **概述 / Overview:** 在 LauncherGUI.ps1 中新增了运行时编译的 C# IL 代码块 `AuroraGuard`，对 16 个核心子模块进行独立的 SHA256 完整性验证。由于编译为本地 IL 指令，比纯 PowerShell 代码更难分析和修改。哈希值在构建时由 `build.ps1` 安全注入。
>
> Added a runtime-compiled C# IL code block `AuroraGuard` in LauncherGUI.ps1 that performs independent SHA256 integrity verification of 16 sub-module core files. Being compiled to native IL instructions, it is significantly harder to analyze and modify than pure PowerShell code. Hash values are securely injected by `build.ps1` at build time.

**验证覆盖范围 / Verification Coverage:**

| 序号 | 保护文件 / Protected File | 说明 |
|:--:|---|
| 1 | `Scripts\AURORA-SmartEngine.ps1` | 智能诊断引擎 |
| 2 | `Scripts\AURORA-CoreEngine.ps1` | 共享核心引擎 |
| 3 | `Scripts\AURORA-AnalyzerCHSPRO.ps1` | 中文 PRO 导出 |
| 4 | `Scripts\AURORA-ProgressManager.ps1` | 进度持久化管理 |
| 5 | `Scripts\AURORA-GUI-Functions.ps1` | GUI 辅助函数 |
| 6 | `Scripts\AURORA-RepairTools.ps1` | 修复工具集 |
| 7 | `Scripts\AURORA-UndoManager.ps1` | 撤销管理 |
| 8 | `Scripts\AURORA-RestoreManager.ps1` | 系统还原 |
| 9 | `Scripts\AURORA-RepairLogger.ps1` | 修复日志审计 |
| 10 | `Scripts\AURORA-UndoViewer.ps1` | 修复历史查看 |
| 11 | `Scripts\AURORA-AnalyzerPRO.ps1` | PRO 模式入口 |
| 12 | `Scripts\AURORA-ProgressManager-Integration.ps1` | 进度集成桥梁 |
| 13 | `Scripts\AURORA-ProgressManager-Integration-CHS.ps1` | 中文进度集成 |
| 14 | `Scripts\AURORA-ProgressManager-Integration-ENG.ps1` | 英文进度集成 |
| 15 | `Scripts\Core\AURORA-AnimationCoreEngine.ps1` | 动画引擎 |
| 16 | `Data\AURORA-TechData.json` | 诊断知识库 |

**技术特性 / Technical Characteristics:**
- `Add-Type` 运行时编译为 IL，跨 Runspace 可见
- `VerifyOrDie()` 方法返回 `bool`，子模块可主动调用
- 构建时自动注入哈希值（build.ps1 `[2.5/6]` 步骤）
- 加载失败时降级运行（不影响正常功能）

---

## 🔧 运行时完整性监控增强 / Runtime Integrity Monitoring Enhancements

### 3. 提权安全令牌 (AURORA-SEC-2026-001) / Elevation Security Token

> **概述 / Overview:** P0级安全修复。当用户执行需要管理员权限的操作（如导出安全日志）时，PowerShell 进程通过 UAC 提权重启。原版 RSA 令牌文件会被旧进程清理，导致提权后的进程无法验证 EXE 身份（信任链断裂）。
>
> P0-level security fix. When users perform operations requiring admin privileges (e.g., exporting security logs), the PowerShell process restarts with UAC elevation. The original RSA token file gets cleaned up by the old process, causing the elevated process to be unable to verify the EXE identity (trust chain break).

**实现方案 / Implementation:**

| 步骤 / Step | 描述 / Description |
|---|---|
| **1. 令牌生成** | EXE 启动前生成独立的提权令牌文件，包含 Nonce + Timestamp + AES-256-CBC 加密的哈希列表。Before launching, EXE generates a separate elevation token file with Nonce + Timestamp + AES-256-CBC encrypted hash list. |
| **2. 参数传递** | 通过 `-ElevationTokenPath` 命令行参数传递令牌路径，绕过 UAC 环境变量清空。Paths are passed via `-ElevationTokenPath` command-line argument, bypassing UAC environment variable clearing. |
| **3. 独立解密** | 提权的 PS1 进程使用令牌中的 Nonce 独立派生 AES 密钥解密哈希列表，不依赖已删除的 RSA 令牌。The elevated PS1 process independently derives the AES key using the Nonce in the token to decrypt the hash list, without depending on the now-deleted RSA token. |
| **4. 时效控制** | 120 秒独立过期窗口（比标准 60 秒更长，补偿提权延迟）。120-second independent expiration window (longer than the standard 60 seconds, compensating for elevation delay). |

**安全性 / Security:**
- 令牌仅包含加密的哈希列表，不包含密码或私钥
- 验证通过后立即删除令牌文件
- 解密失败（密钥不匹配/过期）→ 回退到密码验证路径

---

### 4. 反伪造启动参数保护 / Anti-Spoofing Launch Parameter Protection

> **概述 / Overview:** 修复了一个安全漏洞：攻击者可通过伪造 `-LaunchedByExe` 命令行参数，绕过所有 RSA/AES 安全验证。现在如果该参数为真但没有有效令牌验证通过，系统将强制重置安全状态。
>
> Fixed a security vulnerability where an attacker could forge the `-LaunchedByExe` command-line parameter to bypass all RSA/AES security verification. Now, if this parameter is true but no valid token has passed validation, the system forces a security state reset.

```
检测逻辑 / Detection Logic:
  if (IsLaunchedByExe == true AND PassedHashListFromExe == null)
      → 重置 IsLaunchedByExe = false
      → 清除所有环境变量标记
      → 强制走密码验证路径
```

---

### 5. LastWriteTime 快速筛选优化 / LastWriteTime Pre-Check Optimization

> **概述 / Overview:** P2 级性能优化。在完整性检查循环中，先检查文件的 `LastWriteTime`，只有当修改时间发生变化时才执行完整的 SHA256 哈希计算。大幅减少 19 个文件每 3 秒的重复哈希开销。
>
> P2-level performance optimization. In the integrity check loop, the file's `LastWriteTime` is checked first, and the full SHA256 hash calculation is only performed when the modification time has changed. Significantly reduces the repeated hashing overhead of 19 files every 3 seconds.

**效果 / Effect:**
- 文件未修改时：跳过 SHA256，仅比较时间戳 → ~0ms
- 文件修改时：完整 SHA256 验证 → 50-200ms/文件
- 稳定运行时（无文件变化）：CPU 开销降至接近零

---

## 🎨 界面增强 / UI Enhancements

### 6. C# 内嵌倒计时告警窗口 / C# Embedded Countdown Alert Window

> **概述 / Overview:** 将完整性检查的告警窗口从 PowerShell Timer 实现改为 C# 内嵌类 `AuroraExitCountdown`，避免 PowerShell Timer 作用域问题和倒计时不稳定。
>
> Changed the integrity check alert window from PowerShell Timer implementation to the C# embedded class `AuroraExitCountdown`, avoiding PowerShell Timer scope issues and countdown instability.

**特性 / Features:**
- 深色主题告警窗口（暗红背景 + 白色文字）
- 最后 5 秒红色倒计时警告
- 中英双语支持
- TopMost 置顶确保用户可见
- `Show()` 非模态显示 + 计时器驱动

---

## 🔨 构建系统增强 / Build System Enhancements

### 7. AuroraGuard 哈希注入 / AuroraGuard Hash Injection

> **概述 / Overview:** `build.ps1` 新增 `[2.5/6]` 步骤，将当前构建的 16 个子模块 SHA256 哈希自动注入 LauncherGUI.ps1 的 `AuroraGuard` C# 源代码中，替换占位符哈希值。
>
> `build.ps1` adds a `[2.5/6]` step that automatically injects the current build's 16 sub-module SHA256 hashes into the `AuroraGuard` C# source code in LauncherGUI.ps1, replacing placeholder hash values.

### 8. 智能安全代码注入增强 / Enhanced Intelligent Security Code Injection

> **概述 / Overview:** 增强了 build.ps1 的安全代码注入逻辑，现在能够自动检测并更新 AuroraGuard 的 `_expected` 字典中的哈希值，以及正确替换占位符函数。支持首次注入、密钥更新和哈希更新三种模式。
>
> Enhanced the security code injection logic in build.ps1, which now automatically detects and updates hash values in AuroraGuard's `_expected` dictionary, and correctly replaces placeholder functions. Supports three modes: first-time injection, key update, and hash update.

---

## 🐛 修复 / Bug Fixes

| # | 问题 / Issue | 修复方案 / Resolution |
|---|-------------|----------------------|
| 1 | **UAC 提权信任链断裂 / UAC Elevation Trust Chain Break** | 独立提权安全令牌，120 秒过期窗口。Independent elevation security token with 120-second expiration window. |
| 2 | **伪造 -LaunchedByExe 参数 / Forged -LaunchedByExe Parameter** | 令牌验证失败时强制重置安全状态。Force reset security state when token validation fails. |
| 3 | **重复 Add-Type 加载 / Duplicate Add-Type Loading** | 检查 System.Windows.Forms 和 System.Drawing 是否已加载，避免重复加载报错。Check if assemblies are already loaded before calling Add-Type. |
| 4 | **PowerShell Timer 倒计时不稳定 / PowerShell Timer Countdown Instability** | 改用 C# 内嵌类 `AuroraExitCountdown`。Switched to C# embedded class `AuroraExitCountdown`. |
| 5 | **完整性检查 CPU 持续高占用 / Integrity Check Sustained High CPU** | LastWriteTime 快速筛选，跳过未修改文件的 SHA256 计算。LastWriteTime pre-check skips SHA256 for unmodified files. |

---

## 📊 变更统计 / Change Statistics

| 指标 / Metric | 数值 / Value |
|--------------|-------------|
| **新增安全功能 / New Security Features** | 3 |
| **安全修复 / Security Fixes** | 3 |
| **性能优化 / Performance Optimizations** | 1 |
| **UI 增强 / UI Enhancements** | 1 |
| **构建系统增强 / Build System Enhancements** | 2 |
| **Bug 修复 / Bug Fixes** | 5 |
| **总计变更项 / Total Changes** | 15 |

---

## 🔐 纵深防御升级总结 / Defense-in-Depth Upgrade Summary

V1.1.24.0 的纵深防御模型从四层扩展为**五层**：

```
🛡️ 第一层：构建时安全 (Build-Time)         — RSA 密钥 + 密码混淆 + SHA256 签名
🛡️ 第二层：启动安全 (Launch-Time)          — 反调试 + AES 解密 + RSA 握手
🛡️ 第三层：运行时安全 (Runtime)            — 双定时器 + FileSystemWatcher + 完整性检查
🛡️ 第四层：多模块启动检测 (Multi-Module)    — GUI_Mode + syncHash + RSA Token
🛡️ 第五层：看门狗守护 (Watchdog) — 🆕     — Named Pipe HMAC 挑战-响应 + 独立进程 Kill
```

**新增第五层防御的特性 / Characteristics of the New Fifth Defense Layer:**
- 完全独立于 PS1 脚本层面，由 C# EXE 原生控制
- 即使 PS1 层所有验证被绕过，看门狗仍能独立检测
- 挑战-响应携带 PS1 脚本自哈希，不可伪造
- 连续失败阈值 + 超时机制，多层容错

---

**版权声明 / Copyright:** &copy; 2026 AURORA VelociRaptor-GR Dev PRJ. All rights reserved.