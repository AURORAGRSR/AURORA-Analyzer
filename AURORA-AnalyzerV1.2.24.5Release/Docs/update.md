# AURORA Analyzer V1.2.24.5Release — 更新文档

> **构建时间**: 2026.06.01
> **版本代号**: Security Architecture Overhaul
> **适用范围**: `AURORA-AnalyzerLauncherGUI.ps1` / `build.ps1` / 所有安全相关子系统

---

## 一、版本概述

本次更新是一次**全面安全架构升级**，聚焦于修复启动阶段的安全漏洞与运行时稳定性问题。核心目标是：

1. 消除由内存访问错误导致的**间歇性闪退**（Access Violation）
2. 修复**看门狗时序竞争**导致的偶发启动失败
3. 强化**多进制纵深防御**链路，确保构建→启动→运行全生命周期安全

---

## 二、安全架构变更

### 2.1 RSA 密钥轮换

| 组件 | 变更前 | 变更后 |
|------|--------|--------|
| RSA 公钥 Modulus | `tF61rYipRTBERmH...` | `5wMKsJpF5BoHkv...` |
| SessionSalt | `qHI6yeoytN0LRm7e...` | `BqsDzvd9iEdvRySj...` |

**影响范围**: 所有 RSA 令牌签名验证、AES 会话密钥派生。旧版本 EXE 构建产物将无法通过新的令牌验证。**请重新构建 EXE 以确保兼容。**

### 2.2 文件完整性哈希表更新

16 个核心脚本的 SHA256 哈希值已全部刷新，反映当前代码状态：

- `AURORA-SmartEngine.ps1`
- `AURORA-CoreEngine.ps1`
- `AURORA-AnalyzerCHSPRO.ps1`
- `AURORA-ProgressManager.ps1`
- `AURORA-GUI-Functions.ps1`
- `AURORA-RepairTools.ps1`
- `AURORA-UndoManager.ps1`
- `AURORA-RestoreManager.ps1`
- `AURORA-RepairLogger.ps1`
- `AURORA-UndoViewer.ps1`
- `AURORA-AnalyzerPRO.ps1`
- `AURORA-ProgressManager-Integration.ps1`
- `AURORA-ProgressManager-Integration-CHS.ps1`
- `AURORA-ProgressManager-Integration-ENG.ps1`
- `Core\AURORA-AnimationCoreEngine.ps1`
- `Data\AURORA-TechData.json`

---

## 三、启动流程修复

### 3.1 看门狗环境变量时序修复

**问题**: `Clear-AuroraWatchdogEnv` 在读取 `$env:AURORA_WD_PIPE` 之前执行，导致管道名称始终为 `$null`，EXE 看门狗超时后杀死 PS1 进程，造成间歇性启动失败。

**修复**:

```powershell
# 修复前（错误顺序）
Clear-AuroraWatchdogEnv
$AURORA_WD_PIPE_NAME = $env:AURORA_WD_PIPE  # 此时已为 $null

# 修复后（正确顺序）
$AURORA_WD_PIPE_NAME = $env:AURORA_WD_PIPE
$AURORA_WD_SESSION = $env:AURORA_WD_SESSION
Clear-AuroraWatchdogEnv  # 安全清理
```

### 3.2 进程退出清理程序

新增 `Register-AuroraExitHandler` 函数，注册到 `PowerShell.Exiting` 和 `ProcessExit` 双事件：

- 自动关闭看门狗命名管道连接
- 停止看门狗 Runspace 和 PowerShell 实例
- 停止主引擎 Runspace
- 停止安全守卫定时器（`debuggerTimer`）
- 注销 WMI 进程创建监控（`debuggerWmiWatcher`）
- 清理所有 Aurora 相关环境变量

### 3.3 启动状态标志重置

启动时强制重置所有安全守卫状态标志，防止残留状态导致安全检测被绕过：

```powershell
$script:ExitCountdownStarted = $false
$script:DebuggerCheckCount = 0
$script:IntegrityCheckCount = 0
```

---

## 四、安全守卫（AuroraGuard）修复

### 4.1 ProcessHandleTracing — WOW64 兼容性

**问题**: 在 32 位进程（WOW64）中，`ProcessHandleTracing` 信息类返回值大小为 `IntPtr.Size`（4 字节），而非 `2 * IntPtr.Size`（8 字节）。分配过大的缓冲区并使用 `ReadInt64` 读取会导致越界访问。

**修复**:

```csharp
// 修复前
IntPtr tracingInfo = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(IntPtr)) * 2);
int result = NtQueryInformationProcess(hProcess, ProcessHandleTracing, tracingInfo,
    Marshal.SizeOf(typeof(IntPtr)) * 2, ref returnLength);
long count = Marshal.ReadInt64(tracingInfo);

// 修复后
IntPtr tracingInfo = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(IntPtr)));
int result = NtQueryInformationProcess(hProcess, ProcessHandleTracing, tracingInfo,
    Marshal.SizeOf(typeof(IntPtr)), ref returnLength);
long count = (long)Marshal.ReadIntPtr(tracingInfo);
```

### 4.2 CheckHardwareBreakpoints — 关键修复

这是导致**启动闪退**的根本原因。`CheckHardwareBreakpoints` 函数在 x64 路径上存在三个严重错误：

| 错误项 | 错误值 | 正确值 | 影响 |
|--------|--------|--------|------|
| ContextFlags 写入偏移 | `0` | `0x30` (48) | 覆盖了 CONTEXT 结构体头部，导致 `GetThreadContext` 行为未定义 |
| Dr0 寄存器偏移 | `0x3E0` (992) | `0x48` (72) | 读取了 CONTEXT 结构体之外的内存，触发 Access Violation |
| Dr 寄存器读取大小 | 4 字节 (Int32) | 8 字节 (Int64) | 在 x64 上仅读取了 Dr 寄存器的低 32 位 |

**x86 路径修复**: 移除 `CONTEXT_X86` 结构体 + `Marshal.StructureToPtr` 方式，改用原始缓冲区，避免 .NET 结构体对齐问题。

**x64 路径修复**:

```csharp
// 修复前
Marshal.WriteInt32(ctxBuffer, 0, (int)(CONTEXT_DEBUG_REGISTERS | CONTEXT_FULL));
int drOffset = 0x3E0;
uint dr0 = (uint)Marshal.ReadInt32(ctxBuffer, drOffset);

// 修复后
Marshal.WriteInt32(ctxBuffer, 0x30, (int)(CONTEXT_DEBUG_REGISTERS | CONTEXT_FULL));
int drOffset = 0x48;
long dr0 = Marshal.ReadInt64(ctxBuffer, drOffset);
```

**Windows x64 CONTEXT 结构布局（关键偏移）**:

| 偏移 | 大小 | 字段 |
|------|------|------|
| 0x00 | 4 | P1Home |
| 0x04 | 4 | P2Home |
| 0x08 | 4 | P3Home |
| 0x0C | 4 | P4Home |
| 0x10 | 4 | P5Home |
| 0x14 | 4 | P6Home |
| **0x30** | **4** | **ContextFlags** |
| 0x34 | 4 | MxCsr |
| 0x38 | 2 | SegCs |
| 0x3A | 2 | SegDs |
| ... | ... | ... |
| **0x48** | **8** | **Dr0** |
| **0x50** | **8** | **Dr1** |
| **0x58** | **8** | **Dr2** |
| **0x60** | **8** | **Dr3** |

### 4.3 GetDetectionReason — 诊断日志增强

新增 `DiagLog` 辅助函数，实现双重日志输出：

```csharp
private static void DiagLog(string msg)
{
    Console.Error.WriteLine(msg);            // 控制台实时输出（stderr，无缓冲）
    Console.Error.Flush();
    string logPath = Path.Combine(Path.GetTempPath(), "aurora_guard_diag.log");
    File.AppendAllText(logPath, DateTime.Now.ToString("HH:mm:ss.fff") + " " + msg);
}
```

在 `GetDetectionReason()` 每个检测步骤添加了完整的追踪日志，包括：
- 检测开始/成功/失败
- 异常类型和消息
- 最终检测结果

日志文件路径：`%TEMP%\aurora_guard_diag.log`

---

## 五、EXE 构建修复

### 5.1 环境变量传递

新增 `AURORA_LAUNCHED_BY_EXE = "1"` 环境变量，确保 PS1 进程能正确识别由 EXE 启动：

```csharp
psi.EnvironmentVariables["AURORA_LAUNCHED_BY_EXE"] = "1";
```

### 5.2 进程终止保护

所有 `ps1Proc.Kill()` 调用添加 `try-catch` 保护，防止进程已退出时抛出异常：

```csharp
// 修复前
ps1Proc.Kill();

// 修复后
try { ps1Proc.Kill(); } catch { }
```

### 5.3 控制台窗口设置

```csharp
CreateNoWindow = true  // 修复前为 false
```

### 5.4 移除 WaitForInputIdle

移除了 `ps1Proc.WaitForInputIdle(30000)` 调用，该调用造成管道服务器创建延迟，导致 PS1 重试全部在服务器就绪前完成。

---

## 六、AddScript 输出抑制

看门狗 Runspace 的 `AddScript` 调用添加 `$null =` 前缀，防止 PowerShell 对象 dump 到控制台输出：

```powershell
# 修复前
$AURORA_WD_PS.AddScript({ ... })

# 修复后
$null = $AURORA_WD_PS.AddScript({ ... })
```

---

## 七、构建与部署

**重新构建 EXE**:

```powershell
.\build.ps1
```

**⚠️ 重要提示**: 由于 RSA 密钥已轮换，旧版本 EXE 必须重新构建。所有脚本的 SHA256 哈希值也已更新，完整性验证将使用新的哈希表。

---

## 八、兼容性说明

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10 1809+ / Windows 11 / Windows Server 2019+ |
| 架构 | x64（推荐）/ x86（WOW64） |
| .NET Framework | 4.x（C# 5.0） |
| PowerShell | Windows PowerShell 5.1+ |

---

## 九、已知问题与限制

- `CheckHardwareBreakpoints` 的 `GetThreadContext` 调用在某些安全软件（如深度挂钩 ntdll 的 EDR 产品）下可能返回假阴性，这是设计预期——检测函数在异常时返回 `false` 而非导致崩溃。
- 诊断日志文件 `aurora_guard_diag.log` 会持续追加写入，建议定期清理。

---

*文档结束 — AURORA VelociRaptor-GR Dev PRJ.*