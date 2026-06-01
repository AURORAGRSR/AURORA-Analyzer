# AURORA Analyzer V1.2.24.5Release — 技术文档

> **面向受众**: 安全研究者 / 逆向工程师 / 社区贡献者 / 高级开发者
> **文档定位**: 深入技术细节，解析架构设计与安全实现，适合专业研究与二次开发

***

## 目录

- [1. 项目概述](#1-项目概述)
- [2. 安全架构全景](#2-安全架构全景)
  - [2.1 纵深防御层次模型](#21-纵深防御层次模型)
  - [2.2 密钥层次结构](#22-密钥层次结构)
  - [2.3 认证与验证链路](#23-认证与验证链路)
- [3. 核心子系统](#3-核心子系统)
  - [3.1 RSA 令牌验证系统](#31-rsa-令牌验证系统)
  - [3.2 EXE 看门狗双工通信](#32-exe-看门狗双工通信)
  - [3.3 AuroraGuard 运行时守护](#33-auroraguard-运行时守护)
  - [3.4 文件完整性验证](#34-文件完整性验证)
- [4. v1.2.24.5 安全升级详解](#4-v12245-安全升级详解)
  - [4.1 密钥轮换与密码学加固](#41-密钥轮换与密码学加固)
  - [4.2 启动流程时序修复](#42-启动流程时序修复)
  - [4.3 CheckHardwareBreakpoints 内存布局修复](#43-checkhardwarebreakpoints-内存布局修复)
  - [4.4 WOW64 兼容性修复](#44-wow64-兼容性修复)
  - [4.5 诊断可观测性增强](#45-诊断可观测性增强)
- [5. 反调试与反分析技术栈](#5-反调试与反分析技术栈)
  - [5.1 调试器 API 检测](#51-调试器-api-检测)
  - [5.2 硬件断点检测](#52-硬件断点检测)
  - [5.3 PEB 分析](#53-peb-分析)
  - [5.4 线程隐藏](#54-线程隐藏)
- [6. 构建系统](#6-构建系统)
  - [6.1 build.ps1 构建流程](#61-buildps1-构建流程)
  - [6.2 管道通信协议](#62-管道通信协议)
- [7. 攻击面分析](#7-攻击面分析)
  - [7.1 已知攻击向量](#71-已知攻击向量)
  - [7.2 缓解措施](#72-缓解措施)
- [8. 贡献指南](#8-贡献指南)

***

## 1. 项目概述

AURORA Analyzer 是一个基于 PowerShell / C# 混合架构的 Windows 系统诊断工具。项目采用 **PS1 脚本 + C# 内嵌类型 + C# EXE 加载器** 的三层架构：

```
┌─────────────────────────────────────────┐
│  AURORA-Analyzer.exe (C# EXE 加载器)     │
│  - RSA 令牌生成与签名                     │
│  - Named Pipe 看门狗服务器                 │
│  - 进程生命周期管理                         │
└──────────────┬──────────────────────────┘
               │ Process.Start + 环境变量注入
┌──────────────▼──────────────────────────┐
│  AURORA-AnalyzerLauncherGUI.ps1          │
│  - GUI 主入口 (Windows Forms)             │
│  - AuroraGuard (C# 内嵌类型)               │
│  - AuroraExitCountdown (C# 内嵌类型)       │
│  - 看门狗客户端 + Runspace                  │
│  - 性能分级引擎                             │
└──────────────┬──────────────────────────┘
               │ Dot-sourcing
┌──────────────▼──────────────────────────┐
│  核心引擎脚本 (16 个 .ps1 文件)             │
│  - SmartEngine / CoreEngine              │
│  - RepairTools / UndoManager             │
│  - ProgressManager / AnimationCore       │
│  - 所有文件受 SHA256 完整性哈希保护         │
└─────────────────────────────────────────┘
```

**技术栈**:

| 层 | 语言 | 运行时 |
|----|------|--------|
| EXE 加载器 | C# | .NET Framework 4.x (编译为目标 EXE) |
| GUI Launcher | PowerShell + 内嵌 C# | Windows PowerShell 5.1+ |
| 核心引擎 | PowerShell | Windows PowerShell 5.1+ |

---

## 2. 安全架构全景

### 2.1 纵深防御层次模型

```
Layer 0: 构建时保护
  ├── RSA 密钥对 (构建工具持有私钥签名令牌)
  ├── SHA256 完整性哈希表 (硬编码于 AuroraGuard)
  └── 令牌时效性控制 (60 秒窗口)

Layer 1: 启动验证
  ├── RSA 令牌签名验证 (SHA256 + PKCS#1 v1.5)
  ├── 哈希列表解密 (AES-256-CBC + PBKDF2 会话密钥)
  └── 启动环境健全性检查 (非调试环境)

Layer 2: IPC 安全
  ├── Named Pipe 双向认证 (命名管道)
  ├── HMAC-SHA256 挑战-响应协议
  └── 双向心跳检测 (单次失败即终止)

Layer 3: 运行时守护
  ├── 调试器 API 检测 (IsDebuggerPresent + NtQueryInformationProcess)
  ├── 硬件断点检测 (Dr0-Dr3 寄存器扫描)
  ├── PEB 分析 (NtGlobalFlag 标志位)
  ├── 进程名扫描 (90+ 已知调试工具)
  ├── DLL 注入检测 (模块路径分析)
  └── 持续性轮询 (每 3 秒 + WMI 实时事件)

Layer 4: 退出清理
  ├── 双事件注册 (PowerShell.Exiting + ProcessExit)
  ├── 资源级联释放 (Pipe → Runspace → Timer → WMI)
  └── 环境变量零化
```

### 2.2 密钥层次结构

```
Master Secret (RSA 私钥, 仅构建工具持有)
    │
    ├──签──→ RSA Token (SHA256 签名, 60 秒时效)
    │         │
    │         └──派生──→ AES Session Key (PBKDF2, Nonce, AU_SESSION_2026_SALT_V1)
    │                       │
    │                       └──解密──→ Hash Manifest (SHA256 列表)
    │
    └──签──→ EXE 内嵌验证逻辑 (RSA 公钥硬编码于 PS1)
```

### 2.3 认证与验证链路

```
EXE 构建时:
  1. 生成 Random Nonce (32 hex chars)
  2. 计算所有核心脚本的 SHA256 哈希
  3. PBKDF2(Nonce, AesSalt) → AES Session Key
  4. AES-256-CBC 加密哈希列表 → HashPayload
  5. RSA-SHA256 签名(Nonce:Timestamp:HashPayload) → Signature
  6. 写入令牌文件: Nonce:Timestamp:HashPayload:Signature

PS1 启动时:
  1. 读取 $env:AURORA_TOKEN_PATH → 令牌文件
  2. 解析 Nonce:Timestamp:HashPayload:Signature
  3. RSA 公钥验证签名 (SHA256, PKCS#1 v1.5)
  4. 检查时间戳 (|now - timestamp| < 60s)
  5. PBKDF2(Nonce, AesSalt) → AES Session Key
  6. AES-256-CBC 解密 HashPayload → 哈希清单
  7. AuroraGuard.Initialize(baseDir) → 存储基准目录
  8. AuroraGuard.CheckIntegrity() → 逐文件验证 SHA256

EXE-PS1 看门狗握手:
  1. EXE 生成 NamedPipeServerStream (随机名称)
  2. 环境变量注入 → PS1 通过 NamedPipeClientStream 连接
  3. EXE 发送 HMAC 密钥 (49 字节握手指令: 0x10 + 密钥)
  4. PS1 存储 HMAC 密钥，进入看门狗响应循环
  5. 周期性挑战: EXE 发送 0x03 + 16B Nonce + 8B Timestamp
  6. PS1 响应: HMAC-SHA256(Nonce) + 8B Uptime + 32B SelfHash
  7. EXE 验证 HMAC → 不匹配则 Kill(ps1Proc)
```

---

## 3. 核心子系统

### 3.1 RSA 令牌验证系统

**实现位置**: [AURORA-AnalyzerLauncherGUI.ps1:17-77](file:///e%3A/PC%20SOFT/%E4%BC%98%E5%8C%96%E8%BD%AF%E4%BB%B6/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/Scripts/AURORA-AnalyzerLauncherGUI.ps1#L17-L77)

**关键参数**:

| 参数 | 值 | 用途 |
|------|-----|------|
| 签名算法 | RSA-SHA256 + PKCS#1 v1.5 | 令牌签名 |
| 公钥格式 | XML (Modulus + Exponent) | 内嵌于 PS1 |
| 会话密钥派生 | PBKDF2 (Rfc2898DeriveBytes) | 1000 迭代 |
| AES 模式 | AES-256-CBC, PKCS7 Padding | 哈希列表加密 |
| 令牌有效期 | 60 秒 (|age| < 60) | 防重放 |

**签名输入格式**: `{Nonce}:{Timestamp}:{HashPayload}`

### 3.2 EXE 看门狗双工通信

**实现位置**: [build.ps1:928-1020](file:///e%3A/PC%20SOFT/%E4%BC%98%E5%8C%96%E8%BD%AF%E4%BB%B6/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/build.ps1#L928-L1020) / [AURORA-AnalyzerLauncherGUI.ps1:342-470](file:///e%3A/PC%20SOFT/%E4%BC%98%E5%8C%96%E8%BD%AF%E4%BB%B6/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/Scripts/AURORA-AnalyzerLauncherGUI.ps1#L342-L470)

**命名管道协议**:

| 指令 | 方向 | 载荷 | 描述 |
|------|------|------|------|
| `0x10` | EXE→PS1 | 32B HMAC 密钥 | 初始化握手 |
| `0x03` | EXE→PS1 | 16B Nonce + 8B Timestamp | 周期挑战 |
| `0x03` | PS1→EXE | 32B HMAC + 8B Uptime + 32B SelfHash | 挑战响应 |

**管道命名规则**: `AURORA_WD_{8 hex chars}` (UUID 派生)

### 3.3 AuroraGuard 运行时守护

**实现位置**: [AURORA-AnalyzerLauncherGUI.ps1:497-1037](file:///e%3A/PC%20SOFT/%E4%BC%98%E5%8C%96%E8%BD%AF%E4%BB%B6/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/Scripts/AURORA-AnalyzerLauncherGUI.ps1#L497-L1037)

**检测层次**:

```
CheckDebuggerAPIs()
  ├── IsDebuggerPresent()                     // kernel32
  ├── CheckRemoteDebuggerPresent()            // kernel32
  ├── NtQueryInformationProcess(DebugPort)    // ntdll, Class=7
  ├── NtQueryInformationProcess(DebugFlags)   // ntdll, Class=31
  ├── NtQueryInformationProcess(HandleTracing)// ntdll, Class=34
  ├── CheckPEBNtGlobalFlag()                  // PEB.NtGlobalFlag
  └── CheckHardwareBreakpoints()              // GetThreadContext + Dr0-Dr3

CheckDebuggerProcesses()
  └── Process.GetProcesses() 枚举 → 匹配 90+ 已知调试器名称

CheckDLLInjection()
  └── Process.Modules 枚举 → 非系统/非框架 DLL 路径分析

CheckIntegrity()
  └── 16 个核心文件的 SHA256 哈希比对 (10 秒缓存)
```

### 3.4 文件完整性验证

**验证文件列表**: 16 个核心脚本 + 1 个数据文件

**实现细节**:

```csharp
// 缓存机制: 10 秒内重复调用返回缓存结果
private static readonly TimeSpan _integrityCacheDuration = TimeSpan.FromSeconds(10);
private static readonly object _integrityLock = new object();

// 读取重试: 最多 3 次 (处理文件锁定场景)
while (retryCount < maxRetry)
{
    try
    {
        using (var sha = SHA256.Create())
        {
            byte[] hash = sha.ComputeHash(File.ReadAllBytes(path));
            actual = BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
        }
        hashOk = true;
        break;
    }
    catch (IOException) { retryCount++; Thread.Sleep(100 * retryCount); }
}
```

---

## 4. v1.2.24.5 安全升级详解

### 4.1 密钥轮换与密码学加固

**变更详情**:

| 组件 | v1.2.20.5 | v1.2.24.5 | 安全影响 |
|------|-----------|-----------|----------|
| RSA Modulus | `tF61rYipRTBERmH...` | `5wMKsJpF5BoHkv...` | 防止旧密钥泄漏影响 |
| SessionSalt | `qHI6yeoytN0LRm7e...` | `BqsDzvd9iEdvRySj...` | 会话密钥空间更新 |

**轮换原因**: 安全审计发现需要遵循密钥周期性轮换的最佳实践，确保即使旧的构建产物或密钥材料被泄露，也无法影响当前版本。

### 4.2 启动流程时序修复

**问题根因**: 这是一个经典的 **TOCTOU (Time-of-Check-Time-of-Use)** 变种问题，但方向相反——在检查之前执行了清理操作。

```powershell
# Bug: Clear-AuroraWatchdogEnv 先于环境变量读取执行
# State: $env:AURORA_WD_PIPE 存在 → Clear 清零 → 读取时已为 $null

# Fix: 先保存到脚本变量 (词法作用域)，再清理环境
$AURORA_WD_PIPE_NAME = $env:AURORA_WD_PIPE      # 保存
$AURORA_WD_SESSION = $env:AURORA_WD_SESSION      # 保存
Clear-AuroraWatchdogEnv                           # 安全清理
```

**时序图**:

```
修复前 (间歇失败):
EXE ──Start PS1──→ PS1 ──Clear Env──→ PS1 ──Read Env ($null)──→ Skip Watchdog
EXE ──Wait Pipe──→ Timeout ──→ Kill(PS1) ──→ 启动失败

修复后 (稳定):
EXE ──Start PS1──→ PS1 ──Read Env (保存)──→ PS1 ──Clear Env──→ Connect Pipe
EXE ──Wait Pipe──→ Connected ──→ Handshake ──→ 启动成功
```

### 4.3 CheckHardwareBreakpoints 内存布局修复

这是本次升级的**核心修复**。Windows x64 的 `CONTEXT` 结构体在内存中的布局与直观预期不同，原代码使用了错误的偏移量。

**Windows x64 CONTEXT 结构布局** (简化, 关键字段):

```
Offset  Size  Field
------  ----  -----
0x0000   4    P1Home
0x0004   4    P2Home
0x0008   4    P3Home
0x000C   4    P4Home
0x0010   4    P5Home
0x0014   4    P6Home
0x0018   4    ??? (padding / alignment)
0x001C   4    ??? (padding / alignment)
0x0020   4    ??? (padding / alignment)
0x0024   4    ??? (padding / alignment)
0x0028   4    ??? (padding / alignment)
0x002C   4    ??? (padding / alignment)
0x0030   4    ContextFlags  ← 正确的 ContextFlags 位置!
0x0034   4    MxCsr
0x0038   2    SegCs
0x003A   2    SegDs
0x003C   2    SegEs
0x003E   2    SegFs
0x0040   2    SegGs
0x0042   2    SegSs
0x0044   4    EFlags
0x0048   8    Dr0          ← 正确的 Dr0 位置!
0x0050   8    Dr1
0x0058   8    Dr2
0x0060   8    Dr3
0x0068   8    Dr6
0x0070   8    Dr7
...
(总大小: 1232 字节)
```

**三个错误的级联效应**:

1. `ContextFlags` 写入 `ctxBuffer[0]` → 覆盖了 `P1Home` 区域 → `GetThreadContext` 收到未正确初始化的 ContextFlags → 行为未定义
2. `Dr0` 从 `ctxBuffer[0x3E0]` (992) 读取 → 远超 CONTEXT 的 1232 字节范围中调试寄存器的位置 → **触发 Access Violation**
3. `ReadInt32` (4 字节) 读取 x64 的 8 字节寄存器 → 仅获取低 32 位 → 检测不完整

### 4.4 WOW64 兼容性修复

**ProcessHandleTracing 的架构差异**:

| 架构 | 返回值大小 | 读取方式 |
|------|-----------|----------|
| Native x86 | 4 字节 | `Marshal.ReadInt32` |
| Native x64 | 8 字节 | `Marshal.ReadInt64` |
| WOW64 (x86 on x64) | 4 字节 | `Marshal.ReadInt32` |

**问题**: 原代码在 WOW64 下分配了 `2 × IntPtr.Size = 8` 字节的缓冲区，但实际返回值仅为 4 字节。虽然这不会直接导致崩溃，但 `ReadInt64` 读取了未初始化的高 32 位。

**修复**: 缓冲区大小改为 `IntPtr.Size` (自适应 4/8 字节)，读取使用 `Marshal.ReadIntPtr` (自适应平台)。

### 4.5 诊断可观测性增强

**新增 `DiagLog` 函数**:

```csharp
private static void DiagLog(string msg)
{
    // 双通道输出:
    // 1. stderr — 无缓冲，实时可见 (即使进程即将崩溃)
    // 2. 文件 — 持久化到 %TEMP%\aurora_guard_diag.log
    Console.Error.WriteLine(msg);
    Console.Error.Flush();
    string logPath = Path.Combine(Path.GetTempPath(), "aurora_guard_diag.log");
    File.AppendAllText(logPath, DateTime.Now.ToString("HH:mm:ss.fff") + " " + msg);
}
```

**设计考量**:
- 使用 `Console.Error` (stderr) 而非 `Console.Out` (stdout)，因为 stderr 默认无缓冲，确保崩溃时最后一条日志能输出
- 同时写文件防止控制台关闭后日志丢失
- `Flush()` 强制立即写入，避免缓冲延迟

---

## 5. 反调试与反分析技术栈

### 5.1 调试器 API 检测

| 检测方法 | API | 检测原理 |
|----------|-----|----------|
| IsDebuggerPresent | kernel32 | 读取 PEB.BeingDebugged 标志 |
| CheckRemoteDebuggerPresent | kernel32 | 同上，支持检查其他进程 |
| NtQueryInformationProcess(DebugPort) | ntdll | 进程调试端口非零表示被调试 |
| NtQueryInformationProcess(DebugFlags) | ntdll | DebugFlags 中第 0 位为 0 表示被调试 |
| NtQueryInformationProcess(HandleTracing) | ntdll | 句柄追踪计数异常高表示可疑活动 |

### 5.2 硬件断点检测

**原理**: 硬件调试器通过设置 CPU 调试寄存器 (Dr0-Dr7) 实现断点。通过 `GetThreadContext` 读取当前线程上下文，检查 Dr0-Dr3 是否非零。

**x64 正确实现**:

```csharp
int ctxSize = 1232;  // sizeof(CONTEXT) on Windows x64
IntPtr ctxBuffer = Marshal.AllocHGlobal(ctxSize);

// ContextFlags 位于偏移 0x30
Marshal.WriteInt32(ctxBuffer, 0x30, (int)(CONTEXT_DEBUG_REGISTERS | CONTEXT_FULL));

if (GetThreadContext(GetCurrentThread(), ctxBuffer))
{
    // Dr0 位于偏移 0x48, 每个 Dr 寄存器占 8 字节
    long dr0 = Marshal.ReadInt64(ctxBuffer, 0x48);
    long dr1 = Marshal.ReadInt64(ctxBuffer, 0x50);
    long dr2 = Marshal.ReadInt64(ctxBuffer, 0x58);
    long dr3 = Marshal.ReadInt64(ctxBuffer, 0x60);
    if (dr0 != 0 || dr1 != 0 || dr2 != 0 || dr3 != 0)
        return true;  // 硬件断点被设置
}
```

**x86 正确实现**:

```csharp
int ctxSize = 716;  // sizeof(CONTEXT) on Windows x86
IntPtr ctxBuffer = Marshal.AllocHGlobal(ctxSize);

Marshal.WriteInt32(ctxBuffer, 0, (int)(CONTEXT_DEBUG_REGISTERS | CONTEXT_FULL));

if (GetThreadContext(GetCurrentThread(), ctxBuffer))
{
    // Dr0 位于偏移 4 (紧接 ContextFlags)
    uint dr0 = (uint)Marshal.ReadInt32(ctxBuffer, 4);
    ...
}
```

### 5.3 PEB 分析

**NtGlobalFlag 检测**:

当进程被调试器启动时，Windows 会在 PEB 的 `NtGlobalFlag` 字段设置以下标志组合：

```
FLG_HEAP_ENABLE_TAIL_CHECK   (0x10)
FLG_HEAP_ENABLE_FREE_CHECK   (0x20)
FLG_HEAP_VALIDATE_PARAMETERS (0x40)
───────────────────────────────────
组合标志: 0x70
```

如果 `(NtGlobalFlag & 0x70) == 0x70`，表示进程很可能被调试器启动。

**PEB 访问方式**: 通过 `NtQueryInformationProcess(ProcessBasicInformation)` 获取 `PROCESS_BASIC_INFORMATION`，从中读取 PEB 基址，再读取 `PEB + NtGlobalFlag` 偏移。

| 架构 | PBI 中 PEB 偏移 | NtGlobalFlag 偏移 |
|------|----------------|-------------------|
| x86 | 4 | 0x68 |
| x64 | 8 | 0xBC |

### 5.4 线程隐藏

**API**: `NtSetInformationThread(GetCurrentThread(), ThreadHideFromDebugger, 0, 0)`

**原理**: 设置 `ThreadHideFromDebugger` (0x11) 信息类后，调试器将无法接收该线程的调试事件。如果调试器尝试继续执行，线程会直接退出。

**调用时机**: 在 `VerifyOrDie()` 第一步执行，作为第一道防线。

---

## 6. 构建系统

### 6.1 build.ps1 构建流程

```
build.ps1
  │
  ├── 1. 生成 Random Nonce + Token
  │     ├── 计算所有核心脚本 SHA256
  │     ├── PBKDF2(Nonce, AesSalt) → AES Key
  │     ├── AES-256-CBC 加密哈希列表
  │     └── RSA-SHA256 签名 → Token 文件
  │
  ├── 2. 编译 C# EXE 加载器
  │     ├── Add-Type + CSharpCodeProvider
  │     ├── 嵌入: RSA 公钥 / Master Password / 哈希表
  │     └── 编译为 AURORA-Analyzer.exe
  │
  ├── 3. 生成 Watchdog HMAC 密钥
  │     └── PBKDF2(MasterPassword, WdHmacSalt, 10000) → 32 字节
  │
  ├── 4. 启动 PS1 子进程
  │     ├── ProcessStartInfo 配置
  │     │   ├── FileName: "powershell.exe"
  │     │   ├── Arguments: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden"
  │     │   ├── UseShellExecute: false
  │     │   └── CreateNoWindow: true
  │     ├── 环境变量注入:
  │     │   ├── AURORA_WD_PIPE (管道名称)
  │     │   ├── AURORA_WD_SESSION (会话 ID)
  │     │   └── AURORA_LAUNCHED_BY_EXE = 1
  │     └── Process.Start()
  │
  ├── 5. 看门狗管道服务器循环
  │     ├── 等待 PS1 连接 (3 次重试, 8000ms 超时)
  │     ├── 发送 HMAC 密钥 (0x10 指令)
  │     ├── 周期挑战循环 (每 10000ms 发送 0x03 指令)
  │     └── HMAC 验证失败 → Kill(PS1)
  │
  └── 6. 进程退出处理
        └── 所有 Kill() 用 try-catch 保护
```

### 6.2 管道通信协议

**握手包格式**:

```
Byte 0:   0x10 (指令码)
Byte 1-32: HMAC 密钥 (32 字节)
Byte 33-48: Guid Session ID (16 字节)
─────────────────────────────────
总计: 49 字节
```

**挑战包格式 (发送)**:

```
Byte 0:   0x03 (挑战指令)
Byte 1-16: 随机 Nonce (16 字节)
Byte 17-24: 时间戳 (8 字节, Unix 毫秒)
─────────────────────────────────
总计: 25 字节
```

**响应包格式**:

```
Byte 0-31:  HMAC-SHA256(Nonce) (32 字节)
Byte 32-39: 系统运行时间 (8 字节, 毫秒)
Byte 40-71: PS1 自身 SHA256 (32 字节)
─────────────────────────────────
总计: 72 字节
```

---

## 7. 攻击面分析

### 7.1 已知攻击向量

| 攻击向量 | 难度 | 已有缓解措施 |
|----------|------|-------------|
| 替换核心脚本 | 中 | SHA256 完整性验证 |
| 附加调试器 | 中 | 5 种 API 检测 + 硬件断点扫描 |
| DLL 注入 | 中 | 模块路径分析 |
| 篡改 Token 文件 | 高 | RSA-SHA256 签名 (需要私钥) |
| 重放旧 Token | 高 | 60 秒时效限制 |
| Hook ntdll 绕过 NtQueryInformationProcess | 高 | 硬件断点检测 + PEB 直接读取 |
| 修改内存中的 AuroraGuard | 高 | 看门狗双向 HMAC 心跳 |
| 进程替换 | 高 | 看门狗通过管道监控 PS1 存活 |

### 7.2 缓解措施

1. **纵深防御**: 即使某一层被绕过，后续层次仍能检测
2. **加密绑定**: RSA 令牌将哈希清单与构建时 Nonce 绑定
3. **时间窗口**: 60 秒时效限制防止 Token 重放
4. **双向验证**: 看门狗不仅验证 PS1，PS1 也通过 HMAC 响应证明其完整性
5. **异常容忍**: 所有检测函数在异常时返回安全默认值 (false/无威胁)

---

## 8. 贡献指南

**构建环境**:

```powershell
# 构建命令
.\build.ps1

# 跳过签名 (仅测试)
.\build.ps1 -SkipSigning
```

**代码规范**:

- C# 部分: .NET Framework 4.x, C# 5.0 语法 (兼容 PS1 的 Add-Type)
- PowerShell 部分: 兼容 Windows PowerShell 5.1 (非跨平台 PowerShell Core)
- 内嵌 C#: 使用 `@"..."@` here-string, 引用程序集需显式指定 `-ReferencedAssemblies`
- 安全代码: 所有 Native API 调用必须有 try-catch 和 finally 资源释放

**调试方法**:

- 控制台窗口: 将 `CreateNoWindow` 设为 `false` 查看输出
- 诊断日志: `%TEMP%\aurora_guard_diag.log`
- 单独测试安全守卫: 在 PS1 中直接调用 `[AuroraGuard]::GetDetectionReason()`

**更新完整性哈希**:

修改核心脚本后，需重新计算 SHA256 并更新 `_expected` 字典。推荐使用 build.ps1 自动完成。

---

*AURORA VelociRaptor-GR Dev PRJ. — 2026.06.01*