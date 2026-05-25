# AURORA Analyzer V1.1.24.0 — 开发者技术手册

> **面向读者**: 开发者 / 安全研究员 / 逆向工程师 / 代码审计人员
> **文档定位**: 超详细源码级功能解析，覆盖架构设计、安全模型、模块实现、构建流程

---

## 目录

- [1. 项目概况](#1-项目概况)
- [2. v1.1.24.0 核心更新总览](#2-v11240-核心更新总览)
- [3. 完整模块架构](#3-完整模块架构)
  - [3.1 文件清单与职责](#31-文件清单与职责)
  - [3.2 模块依赖关系图](#32-模块依赖关系图)
- [4. GUI 架构深度解析](#4-gui-架构深度解析)
  - [4.1 Windows Forms 启动器](#41-windows-forms-启动器)
  - [4.2 PowerShell Runspace 多线程模型](#42-powershell-runspace-多线程模型)
  - [4.3 syncHash 跨线程通信](#43-synchas-跨线程通信)
  - [4.4 EventWaitHandle 事件驱动授权](#44-eventwaithandle-事件驱动授权)
  - [4.5 AuroraProgressBar 星空动画引擎](#45-auroraprogressbar-星空动画引擎)
  - [4.6 动态性能分级算法](#46-动态性能分级算法)
- [5. PRO 模式技术实现](#5-pro-模式技术实现)
  - [5.1 日志类型与导出模式](#51-日志类型与导出模式)
  - [5.2 高级筛选引擎](#52-高级筛选引擎)
  - [5.3 多格式输出管线](#53-多格式输出管线)
  - [5.4 智能权限管理](#54-智能权限管理)
  - [5.5 会话持久化与断点续传](#55-会话持久化与断点续传)
- [6. 智能诊断引擎](#6-智能诊断引擎)
  - [6.1 诊断规则知识库](#61-诊断规则知识库)
  - [6.2 异常时间窗口靶向锁定](#62-异常时间窗口靶向锁定)
  - [6.3 Minidump 蓝屏解析](#63-minidump-蓝屏解析)
  - [6.4 安全沙箱执行器](#64-安全沙箱执行器)
  - [6.5 五大诊断分类详解](#65-五大诊断分类详解)
- [7. Undo / 修复系统](#7-undo--修复系统)
  - [7.1 Windows System Restore API 集成](#71-windows-system-restore-api-集成)
  - [7.2 快速备份快照机制](#72-快速备份快照机制)
  - [7.3 修复命令日志审计](#73-修复命令日志审计)
  - [7.4 一键撤销实现](#74-一键撤销实现)
  - [7.5 修复历史查看器](#75-修复历史查看器)
- [8. 安全体系 — 纵深防御四层模型](#8-安全体系--纵深防御四层模型)
  - [8.1 第一层：构建时安全](#81-第一层构建时安全)
  - [8.2 第二层：启动安全](#82-第二层启动安全)
  - [8.3 第三层：运行时安全](#83-第三层运行时安全)
  - [8.4 第四层：多模块启动检测](#84-第四层多模块启动检测)
  - [8.5 RSA 握手协议详解](#85-rsa-握手协议详解)
- [9. 构建系统](#9-构建系统)
  - [9.1 build.ps1 全流程](#91-buildps1-全流程)
  - [9.2 C# 混淆编译](#92-c-混淆编译)
  - [9.3 打包与分发](#93-打包与分发)
- [10. 国际化架构](#10-国际化架构)
- [11. 性能与安全权衡设计](#11-性能与安全权衡设计)
- [12. 错误处理与日志](#12-错误处理与日志)

---

## 1. 项目概况

| 属性 | 值 |
|------|-----|
| **项目名称** | AURORA Analyzer |
| **版本** | V1.1.24.0 |
| **构建日期** | 2026-05-25 |
| **作者** | AURORA VelociRaptor-GR Dev PRJ. |
| **许可** | 仅供个人学习与研究使用 |
| **类型** | Windows 系统事件日志导出与智能诊断工具 |
| **核心语言** | C# (.NET Framework 4.x) + PowerShell 7+ |
| **目标平台** | Windows 10/11 x64 (需 .NET Framework 4.7.2+) |
| **最低权限** | 标准用户 (部分功能需管理员) |

### 核心能力矩阵

| 能力域 | 描述 | 技术栈 |
|--------|------|--------|
| 日志导出 | 8 种 Windows 事件日志类型，多格式输出 | PowerShell `Get-WinEvent` API |
| 智能诊断 | 100+ 规则知识图谱匹配 | JSON 规则引擎 + PowerShell |
| 蓝屏分析 | Minidump 自动解析 | Windows Debugger API |
| 系统修复 | 一键修复 5 大类系统问题 | PowerShell + Windows API |
| 撤销系统 | 双保险回滚（还原点 + 快照） | System Restore API + 注册表/文件备份 |
| 安全防护 | 四层纵深防御 | RSA-2048 + AES-256-CBC + PBKDF2 |
| 国际化 | 中英双语 | PowerShell Data File (.psd1) |
| GUI | Windows Forms 原生界面 | C# WinForms + 多线程 Runspace |

---

## 2. v1.1.24.0 核心更新总览

本版本从 v1.1.23.0 的单一密码验证体系，升级为**纵深防御四层安全模型**，具体变更如下：

### 安全架构升级

| 编号 | 更新项 | 类型 | 详细说明 |
|------|--------|------|----------|
| 1 | RSA-2048 非对称密钥 | **新增** | 每次构建自动生成新密钥对，私钥嵌入 EXE，公钥注入 PS1 |
| 2 | AES-256-CBC 会话加密 | **新增** | 保护哈希列表传输通道，抵御中间人嗅探 |
| 3 | 双重定时器 + FileSystemWatcher | **新增** | 3 秒固定 + 2-7 秒随机间隔，实时文件系统监控 |
| 4 | C# 离线元数据混淆 | **新增** | 类名/方法名重命名，增加反编译分析难度 |
| 5 | 反调试/反 Dump 检测 | **新增** | 检测 x64dbg、OllyDbg、Scylla、Phantom |
| 6 | Token 时效性验证 | **新增** | 60 秒过期窗口，5 秒时钟偏移容差 |
| 7 | 检查间隔优化 (10s → 3s) | **P0 修复** | 大幅缩短安全检测响应时间 |
| 8 | 移除 break 全量检查 | **P0 修复** | 修复早期退出导致漏检的安全漏洞 |
| 9 | 启动后 1 秒立即检查 | **新增** | 消除启动窗口期的安全真空 |
| 10 | 未授权文件注入检测 | **新增** | 检测核心目录中不应存在的外部文件 |

---

## 3. 完整模块架构

### 3.1 文件清单与职责

#### 3.1.1 核心启动模块

| 文件 | 类型 | 职责 | 持有秘密 |
|------|------|------|----------|
| `AURORA.Launcher-双击启动.exe` | C# 编译 PE | 启动入口，持有私钥、密码、反调试逻辑 | RSA 私钥、密码碎片、调试器黑名单 |
| `Scripts/AURORA-AnalyzerLauncherGUI.ps1` | PowerShell 脚本 | 主 GUI 界面，运行时监控调度 | RSA 公钥、完整性检查逻辑 |
| `Scripts/AURORA-GUI-Functions.ps1` | PowerShell 脚本 | GUI 辅助函数集 | 无 |
| `Scripts/Core/AURORA-AnimationCoreEngine.ps1` | PowerShell 脚本 | 星空动画引擎源码 | 无 |
| `Scripts/Core/AURORA-AnimationCoreEngine.dll` | .NET DLL | 动画引擎编译库 | 无 |

#### 3.1.2 PRO 模式模块

| 文件 | 类型 | 职责 |
|------|------|------|
| `Scripts/AURORA-AnalyzerPRO.ps1` | PowerShell 脚本 | 统一 PRO 入口，语言路由分发 |
| `Scripts/AURORA-AnalyzerCHSPRO.ps1` | PowerShell 脚本 | 中文专业版日志导出逻辑 |
| `Scripts/AURORA-AnalyzerENGPRO.ps1` | PowerShell 脚本 | 英文专业版日志导出逻辑 |

#### 3.1.3 智能诊断模块

| 文件 | 类型 | 职责 |
|------|------|------|
| `Scripts/AURORA-SmartEngine.ps1` | PowerShell 脚本 | 诊断引擎 v1.1.32，规则匹配与执行 |
| `Data/AURORA-TechData.json` | JSON 数据 | 技术知识库，100+ 诊断规则定义 |

#### 3.1.4 进度管理模块

| 文件 | 类型 | 职责 |
|------|------|------|
| `Scripts/AURORA-ProgressManager.ps1` | PowerShell 脚本 | 进度持久化核心，断点续传 |
| `Scripts/AURORA-ProgressManager-Integration.ps1` | PowerShell 脚本 | 双语言进度集成桥梁 |
| `Scripts/AURORA-ProgressManager-Integration-CHS.ps1` | PowerShell 脚本 | 中文进度界面集成 |
| `Scripts/AURORA-ProgressManager-Integration-ENG.ps1` | PowerShell 脚本 | 英文进度界面集成 |

#### 3.1.5 核心引擎模块

| 文件 | 类型 | 职责 |
|------|------|------|
| `Scripts/AURORA-CoreEngine.ps1` | PowerShell 脚本 | 共享核心引擎（权限、日志处理、文件操作、会话管理） |
| `Scripts/AURORA-Language.psd1` | PowerShell Data File | 集中式双语资源（144 条翻译） |

#### 3.1.6 Undo / 修复系统模块 (Phase 4.2)

| 文件 | 类型 | 职责 |
|------|------|------|
| `Scripts/AURORA-RestoreManager.ps1` | PowerShell 脚本 | Windows System Restore API 集成 |
| `Scripts/AURORA-RepairLogger.ps1` | PowerShell 脚本 | 修复命令日志记录器（审计追踪） |
| `Scripts/AURORA-UndoManager.ps1` | PowerShell 脚本 | 快速备份与还原（注册表/文件/服务） |
| `Scripts/AURORA-RepairTools.ps1` | PowerShell 脚本 | 修复工具集（Update、Defender、Telemetry 等） |
| `Scripts/AURORA-UndoViewer.ps1` | PowerShell 脚本 | 修复历史查看与撤销工具 |

#### 3.1.7 构建与安全文件

| 文件 | 类型 | 职责 |
|------|------|------|
| `build.ps1` | PowerShell 脚本 | 自动化构建系统 |
| `AURORA-build.bat` | Batch 文件 | 构建快捷入口 |
| `version.txt` | 文本文件 | 版本号存储 |
| `GAURORA.CHK.ENC` | 加密二进制 | AES 加密的 19 个核心文件 SHA256 哈希清单 |
| `desktop.ini` | 系统文件 | 文件夹图标美化 |

---

### 3.2 模块依赖关系图

```
AURORA.Launcher-双击启动.exe (C# 启动器)
    │
    ├──[RSA 握手]──► AURORA-AnalyzerLauncherGUI.ps1 (主 GUI)
    │                    │
    │                    ├──► AURORA-GUI-Functions.ps1 (GUI 辅助)
    │                    ├──► AURORA-AnimationCoreEngine.dll (动画)
    │                    │       └──► AURORA-AnimationCoreEngine.ps1 (源码)
    │                    │
    │                    ├──► AURORA-AnalyzerPRO.ps1 (PRO 入口)
    │                    │       ├──► AURORA-AnalyzerCHSPRO.ps1
    │                    │       └──► AURORA-AnalyzerENGPRO.ps1
    │                    │
    │                    ├──► AURORA-SmartEngine.ps1 (诊断引擎)
    │                    │       └──► AURORA-TechData.json (知识库)
    │                    │
    │                    ├──► AURORA-ProgressManager.ps1 (进度管理)
    │                    │       ├──► AURORA-ProgressManager-Integration.ps1
    │                    │       │       ├──► -Integration-CHS.ps1
    │                    │       │       └──► -Integration-ENG.ps1
    │                    │
    │                    ├──► AURORA-RestoreManager.ps1 (系统还原)
    │                    ├──► AURORA-RepairLogger.ps1 (修复日志)
    │                    ├──► AURORA-UndoManager.ps1 (撤销管理)
    │                    ├──► AURORA-RepairTools.ps1 (修复工具)
    │                    ├──► AURORA-UndoViewer.ps1 (历史查看)
    │                    │
    │                    ├──► AURORA-CoreEngine.ps1 (核心引擎)
    │                    └──► AURORA-Language.psd1 (双语资源)
    │
    └──[完整性检查]──► GAURORA.CHK.ENC (加密哈希清单)
```

---

## 4. GUI 架构深度解析

### 4.1 Windows Forms 启动器

`AURORA.Launcher-双击启动.exe` 是整个工具的入口点，由 C# 编写，使用 .NET Framework 的 Windows Forms 框架编译。

**启动流程:**

```
用户双击 EXE
    │
    ├─ 1. 反调试检测
    │     ├─ IsDebuggerPresent() API 调用
    │     └─ 进程枚举检测 (x64dbg, OllyDbg, Scylla, Phantom)
    │
    ├─ 2. 完整性检查
    │     ├─ 读取 GAURORA.CHK.ENC → AES-256-CBC 解密
    │     ├─ 19 个核心文件存在性检查
    │     └─ SHA256 逐文件比对
    │
    ├─ 3. 生成 RSA 认证 Token
    │     ├─ Nonce = GUID.NewGuid()
    │     ├─ Timestamp = DateTime.UtcNow
    │     ├─ 计算: TokenPayload = Nonce + ":" + Timestamp
    │     ├─ 签名: Signature = RSA-Sign(SHA256(TokenPayload), PrivateKey)
    │     └─ 序列化: Base64(Nonce:Timestamp:HashB64:Signature)
    │
    ├─ 4. 启动 PowerShell 进程
    │     ├─ 传入 Token 作为命令行参数
    │     ├─ 设置 GUI_Mode=1 环境变量
    │     └─ 传入 syncHash 引用
    │
    └─ 5. 等待握手确认 → 进入主循环
```

**C# 源码保护措施:**
- 密码通过 XOR + Shuffle 双重组混淆后嵌入源码
- RSA 私钥以碎片化字节数组形式存储
- 类名和方法名在编译前进行离线重命名混淆
- 编译目标强制指定为 x86 平台

### 4.2 PowerShell Runspace 多线程模型

主 GUI 使用 PowerShell Runspace 实现真正的多线程并发，而非传统的 PowerShell Job（进程级隔离）。

```
主线程 (MainForm)
    │
    ├── Runspace #1: Worker-Runspace
    │     └── 执行日志导出 / 诊断等耗时操作
    │
    ├── Runspace #2: Animation-Runspace
    │     └── AuroraProgressBar 星空动画渲染
    │
    ├── Runspace #3: Integrity-Monitor
    │     └── 双重定时器 + FileSystemWatcher 完整性监控
    │
    └── UI 线程: Windows Forms 消息泵
          └── 处理用户交互事件
```

**Runspace 创建伪代码:**

```powershell
$InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$InitialSessionState.Variables.Add(
    [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new(
        'syncHash', $syncHash, 'Shared state'
    )
)
$RunspacePool = [runspacefactory]::CreateRunspacePool($InitialSessionState)
$RunspacePool.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
$RunspacePool.SetMaxRunspaces(4)
$RunspacePool.Open()
```

### 4.3 syncHash 跨线程通信

`synchronized hashtable` 是 PowerShell 提供的线程安全字典，作为 GUI 线程与 Worker Runspace 之间的唯一通信桥梁。

**核心数据结构:**

```powershell
$syncHash = [hashtable]::Synchronized(@{
    # GUI → Worker 指令
    Command         = $null          # 'Export' | 'Diagnose' | 'Repair' | 'Undo'
    Parameters      = $null          # 命令参数包 (hashtable)
    CancelRequested = $false         # 取消标志
    
    # Worker → GUI 反馈
    Progress        = 0              # 进度百分比 (0-100)
    StatusMessage   = ""             # 状态描述文本
    IsCompleted     = $false         # 任务完成标志
    Result          = $null          # 结果数据
    Error           = $null          # 错误信息
    
    # 系统状态
    IsAdmin         = $false         # 是否管理员权限
    CurrentLanguage = "zh-CN"        # 当前语言
    GuiHandle       = [IntPtr]::Zero # 窗体句柄
    
    # 安全状态
    Token           = ""             # RSA 认证 Token
    TokenValidated  = $false         # Token 验证结果
    TamperDetected  = $false         # 篡改检测标志
})
```

**通信流程示例（日志导出）:**

```
GUI 线程:  $syncHash.Command = 'Export'
           $syncHash.Parameters = @{logType='System'; date='2026-05-25'}
           
Worker:    while(-not $syncHash.IsCompleted) {
               $cmd = $syncHash.Command
               if($cmd -eq 'Export') { ... }
           }
           
GUI 线程:  while(-not $syncHash.IsCompleted) {
               $progressBar.Value = $syncHash.Progress
               $statusLabel.Text  = $syncHash.StatusMessage
               [System.Windows.Forms.Application]::DoEvents()
           }
```

### 4.4 EventWaitHandle 事件驱动授权

为避免 CPU 空转轮询，授权系统采用 `EventWaitHandle` 实现零 CPU 占用的事件驱动模型。

```powershell
# 创建命名事件
$AuthEvent = [System.Threading.EventWaitHandle]::new(
    $false,                                                  # initialState
    [System.Threading.EventResetMode]::ManualReset,          # mode
    "AURORA_Auth_Event_$PID"                                 # 唯一名称
)

# Worker 等待授权
$AuthEvent.WaitOne()  # 阻塞，零 CPU

# GUI 线程发放授权
$syncHash.TokenValidated = $true
$AuthEvent.Set()       # 唤醒 Worker
$AuthEvent.Reset()     # 重置为未信号状态
```

### 4.5 AuroraProgressBar 星空动画引擎

`AURORA-AnimationCoreEngine.dll` 是一个自定义的 .NET 控件，继承自 `ProgressBar` 或 `Control`，实现极光星空背景特效。

**技术特性:**
- 基于 `System.Drawing.Graphics` 的 GDI+ 双缓冲渲染
- 粒子系统：数百个随机星点进行轨迹运动
- 动画帧率：通过 `System.Windows.Forms.Timer` 控制，默认 60 FPS
- 颜色方案：蓝紫渐变色调，模拟极光效果
- 性能自适应：根据系统性能分级调整粒子数量和帧率

**渲染管线:**

```csharp
// 伪代码
protected override void OnPaint(PaintEventArgs e) {
    // 1. 清空后台缓冲区
    backBuffer.Clear(Color.Black);
    
    // 2. 渲染极光光带 (正弦波叠加 + 透明度渐变)
    foreach (var band in auroraBands) {
        DrawAuroraBand(backBuffer, band);
    }
    
    // 3. 渲染星点粒子
    foreach (var star in stars) {
        star.Update(deltaTime);
        DrawStar(backBuffer, star);
    }
    
    // 4. 将后台缓冲区绘制到屏幕
    e.Graphics.DrawImage(backBufferImage, 0, 0);
}
```

### 4.6 动态性能分级算法

系统在启动时自动评估硬件能力，分为 4 个性能等级。

**评分公式:**

```
总评分 = CPU核心得分 × 0.35 + 内存得分 × 0.35 + 主频得分 × 0.30

其中:
- CPU核心得分 = min(核心数 / 8, 1.0) × 100
- 内存得分   = min(总内存GB / 16, 1.0) × 100
- 主频得分   = min(主频GHz / 3.5, 1.0) × 100
```

**分级阈值:**

| 等级 | 评分范围 | 动画粒子数 | 动画帧率 | 并发线程 |
|------|----------|-----------|----------|----------|
| **Extreme** | ≥ 90 | 300 | 60 FPS | 4 |
| **Performance** | 70-89 | 200 | 45 FPS | 3 |
| **Balanced** | 40-69 | 100 | 30 FPS | 2 |
| **Eco** | < 40 | 50 | 20 FPS | 1 |

---

## 5. PRO 模式技术实现

### 5.1 日志类型与导出模式

PRO 模式支持 8 种 Windows 事件日志类型的导出：

| 日志名称 | `Get-WinEvent -LogName` 参数 | 典型内容 |
|----------|------------------------------|----------|
| System | `System` | 系统服务、驱动、内核事件 |
| Application | `Application` | 应用程序错误、崩溃 |
| Security | `Security` | 登录审计、权限变更 |
| Setup | `Setup` | Windows 安装与更新 |
| DNS Server | `DNS Server` | DNS 查询与解析 |
| DHCP Server | `DHCP Server` | DHCP 租约信息 |
| Directory Service | `Directory Service` | AD 域控事件 |
| IIS Admin Service | `IIS-Admin` | IIS Web 服务器管理 |

**导出模式:**

| 模式 | 参数 | 描述 |
|------|------|------|
| 单日导出 | `-Date "2026-05-25"` | 导出指定日期的所有日志 |
| 日期范围导出 | `-From "2026-05-01" -To "2026-05-25"` | 导出日期范围内的日志 |
| ForceRescan | `-ForceRescan` | 忽略缓存，强制重新扫描导出 |

**路由机制 (AURORA-AnalyzerPRO.ps1):**

```powershell
param(
    [string]$Language = "CHS",
    [string]$LogType,
    [string]$Date,
    [string]$From,
    [string]$To,
    [switch]$ForceRescan
)

if ($Language -eq "CHS") {
    & "$PSScriptRoot\AURORA-AnalyzerCHSPRO.ps1" @PSBoundParameters
} else {
    & "$PSScriptRoot\AURORA-AnalyzerENGPRO.ps1" @PSBoundParameters
}
```

### 5.2 高级筛选引擎

PRO 模式支持在导出前对事件日志进行高级筛选，筛选参数通过 `FilterHashtable` 传递给 `Get-WinEvent`。

```powershell
$filterParams = @{
    LogName   = $LogType
    StartTime = $startDate
    EndTime   = $endDate
}

# 可选筛选器
if ($EventID) {
    $filterParams.ID = $EventID -split ',' | ForEach-Object { [int]$_.Trim() }
}
if ($ProviderName) {
    $filterParams.ProviderName = $ProviderName
}
if ($Level) {
    $filterParams.Level = $Level  # 1=Critical, 2=Error, 3=Warning, 4=Info, 5=Verbose
}

$events = Get-WinEvent -FilterHashtable $filterParams -MaxEvents $maxEvents
```

**Level 映射表:**

| 用户选项 | Level 值 | Windows 定义 |
|----------|----------|--------------|
| Critical | 1 | 关键错误 |
| Error | 2 | 错误 |
| Warning | 3 | 警告 |
| Information | 4 | 信息 |
| Verbose | 5 | 详细 |

### 5.3 多格式输出管线

导出的日志经过统一的数据转换管线，生成多种格式输出：

```
Get-WinEvent 原始数据
    │
    ├──[格式转换器]──────────────────────────────────────┐
    │                                                    │
    ├─► CSV 输出     →  系统_日志_20260525.csv          │
    ├─► JSON 输出    →  系统_日志_20260525.json         │
    ├─► XML 输出     →  系统_日志_20260525.xml          │
    ├─► 摘要报告     →  系统_日志_20260525_摘要.txt      │
    └─► 趋势分析     →  系统_日志_..._趋势分析.txt       │
                   →  系统_日志_..._趋势数据.csv        │
```

**JSON 输出结构:**

```json
{
  "ExportInfo": {
    "LogType": "System",
    "ExportDate": "2026-05-25",
    "TotalEvents": 15420,
    "FilterApplied": false,
    "ToolVersion": "1.1.24.0"
  },
  "Events": [
    {
      "TimeCreated": "2026-05-25T08:30:15.0000000Z",
      "Id": 1001,
      "Level": 4,
      "LevelDisplayName": "Information",
      "ProviderName": "Microsoft-Windows-Diagnostics-Performance",
      "MachineName": "DESKTOP-XXX",
      "Message": "..."
    }
  ]
}
```

**趋势分析算法:**

趋势分析按小时聚合事件计数，计算每个 EventID 的分布趋势。输出包括：
- 每小时事件总数折线图数据
- Top 10 高频 EventID 统计
- 关键错误事件占比趋势
- 事件级别分布饼图数据

### 5.4 智能权限管理

系统自动检测当前日志类型是否需要管理员权限，按需提权。

**权限检测逻辑:**

```powershell
$requiresAdmin = @('Security', 'Setup', 'Directory Service') -contains $LogType

if ($requiresAdmin -and -not ([Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator))) {
    
    # 重新以管理员身份启动
    $newProcess = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile -File `"$PSCommandPath`" $AllArgs" `
        -Verb RunAs -PassThru
    $newProcess.WaitForExit()
    exit
}
```

### 5.5 会话持久化与断点续传

`AURORA-ProgressManager.ps1` 实现完整的会话持久化机制，支持中断后恢复。

**会话数据结构 (Session JSON):**

```json
{
  "SessionId": "SESSION_20260525_105443_1875",
  "CreatedAt": "2026-05-25T10:54:43+08:00",
  "LastUpdated": "2026-05-25T11:05:20+08:00",
  "Status": "in_progress",
  "TaskType": "Export",
  "Parameters": {
    "LogType": "System",
    "From": "2026-01-01",
    "To": "2026-03-01"
  },
  "Progress": {
    "TotalEvents": 500000,
    "ProcessedEvents": 234567,
    "Percentage": 46.9,
    "CurrentChunk": 47,
    "TotalChunks": 100
  },
  "Checkpoints": [
    {"ChunkId": 45, "LastEventId": 654321, "Timestamp": "2026-05-25T11:05:20+08:00"}
  ],
  "OutputFiles": [
    "System_Log_20260101___20260301.csv",
    "System_Log_20260101___20260301.json"
  ]
}
```

**断点续传恢复逻辑:**

```powershell
function Resume-Session {
    param([string]$SessionId)
    
    $session = Get-Session -SessionId $SessionId
    if ($session.Status -eq 'completed') {
        Write-Warning "Session already completed"
        return
    }
    
    # 从最近的 checkpoint 恢复
    $lastCheckpoint = $session.Checkpoints | Sort-Object ChunkId -Descending | Select-Object -First 1
    
    # 重新执行，跳过已处理的 chunk
    Export-LogsInChunks `
        -LogType $session.Parameters.LogType `
        -From $session.Parameters.From `
        -To $session.Parameters.To `
        -SkipChunks ($lastCheckpoint.ChunkId) `
        -SessionId $SessionId
}
```

**缓存归档:**

- **active/**: 进行中的会话
- **archive/**: 已完成的会话（命名格式: `SESSION_{id}_{starttime}_{endtime}.json`）

---

## 6. 智能诊断引擎

### 6.1 诊断规则知识库

`Data/AURORA-TechData.json` 是诊断引擎的核心知识库，定义 100+ 条诊断规则，采用层级化 JSON 结构。

**规则定义格式:**

```json
{
  "version": "1.1.32",
  "categories": {
    "A": {
      "name": "系统稳定性",
      "description": "检测意外关机、系统崩溃、服务异常停止",
      "rules": [
        {
          "id": "A-001",
          "name": "意外关机检测",
          "severity": "critical",
          "eventIds": [41, 6008],
          "logSource": "System",
          "condition": "event.Count >= 3 AND event.TimeWindow <= 7d",
          "diagnosis": "在最近7天内检测到 {count} 次意外关机",
          "recommendation": "检查电源供应、散热系统和驱动程序",
          "repairAction": "CheckPowerAndThermal",
          "riskLevel": "medium"
        }
      ]
    }
  }
}
```

### 6.2 异常时间窗口靶向锁定

诊断引擎不盲目扫描全部日志，而是智能锁定异常时间窗口。

**时间窗口算法:**

```
1. 分析系统启动历史 (EventID 6005/6006)
2. 分析崩溃历史 (EventID 41/1001)
3. 计算关键窗口:
   - 崩溃前窗口: [CrashTime - 2h, CrashTime]
   - 启动后窗口: [BootTime, BootTime + 4h]
4. 合并重叠窗口
5. 仅在窗口内执行深度规则匹配
```

```powershell
function Get-AnomalyTimeWindows {
    $bootEvents  = Get-WinEvent -FilterHashtable @{LogName='System'; ID=6005,6006}
    $crashEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ID=41,1001}
    
    $windows = @()
    foreach ($crash in $crashEvents) {
        $windows += @{
            Start = $crash.TimeCreated.AddHours(-2)
            End   = $crash.TimeCreated
            Type  = 'CrashWindow'
        }
    }
    foreach ($boot in $bootEvents) {
        $windows += @{
            Start = $boot.TimeCreated
            End   = $boot.TimeCreated.AddHours(4)
            Type  = 'BootWindow'
        }
    }
    
    return Merge-OverlappingWindows -Windows $windows
}
```

### 6.3 Minidump 蓝屏解析

诊断引擎集成了 Minidump 文件自动解析能力。

**解析流程:**

```powershell
function Invoke-MinidumpAnalysis {
    param([string]$MinidumpPath = "$env:SystemRoot\Minidump")
    
    $dumps = Get-ChildItem -Path $MinidumpPath -Filter "*.dmp" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 5
    
    $results = @()
    foreach ($dump in $dumps) {
        # 使用 WinDbg API 或内置解析
        $info = @{
            FileName       = $dump.Name
            CrashTime      = $dump.LastWriteTime
            BugCheckCode   = $null
            BugCheckString = $null
            CausedByDriver = $null
            ProcessName    = $null
        }
        
        # 尝试解析 DMP 文件头获取 BugCheck 信息
        $stream = [System.IO.File]::OpenRead($dump.FullName)
        $reader = [System.IO.BinaryReader]::new($stream)
        # ... DMP 头部解析逻辑 ...
        $reader.Close()
        
        $results += $info
    }
    
    return $results
}
```

### 6.4 安全沙箱执行器

`Invoke-AuroraSafeAction` 是诊断引擎中的安全执行包装器，确保修复操作可追踪、可回滚。

**执行管线:**

```
Invoke-AuroraSafeAction -Action $repairAction
    │
    ├─ 1. 前置检查 (PreCheck)
    │     ├─ 验证操作目标存在
    │     ├─ 检查依赖服务状态
    │     └─ 评估影响范围
    │
    ├─ 2. 风险评估 (RiskAssessment)
    │     ├─ 查询规则库中的 riskLevel
    │     ├─ High → 需要用户显式确认
    │     ├─ Medium → 显示警告但可自动执行
    │     └─ Low → 静默自动执行
    │
    ├─ 3. 创建回滚点 (CreateRollbackPoint)
    │     ├─ 调用 UndoManager 创建备份快照
    │     └─ 记录操作前状态
    │
    ├─ 4. 执行操作 (ExecuteAction)
    │     ├─ 记录到 RepairLogger
    │     └─ 执行实际修复命令
    │
    └─ 5. 验证结果 (ValidateResult)
          ├─ 检查操作后状态
          └─ 生成执行报告
```

### 6.5 五大诊断分类详解

#### A 类 — 系统稳定性

| 规则 ID | 检测项 | 触发条件 | 严重级别 |
|---------|--------|----------|----------|
| A-001 | 意外关机 | EventID 41, 6008 ≥ 3次/7天 | Critical |
| A-002 | 系统服务崩溃 | EventID 7031, 7034 频繁出现 | Error |
| A-003 | 内核电源状态异常 | EventID 137, 179 | Warning |
| A-004 | Windows Update 失败 | EventID 20, 24, 31 | Warning |
| A-005 | 磁盘文件系统错误 | EventID 55, 137 | Error |
| A-006 | 系统时间跳变 | EventID 1 (Kernel-General) | Warning |

#### B 类 — 应用程序错误

| 规则 ID | 检测项 | 触发条件 | 严重级别 |
|---------|--------|----------|----------|
| B-001 | .NET Runtime 崩溃 | EventID 1000, 1026 | Error |
| B-002 | 应用程序挂起 | EventID 1002 | Warning |
| B-003 | WMI 错误 | EventID 10, 20 | Warning |
| B-004 | COM 组件错误 | EventID 10010 | Warning |
| B-005 | 服务控制管理器错误 | EventID 7000, 7009, 7011 | Error |

#### C 类 — 驱动程序问题

| 规则 ID | 检测项 | 触发条件 | 严重级别 |
|---------|--------|----------|----------|
| C-001 | 驱动加载失败 | EventID 219, 20001 | Warning |
| C-002 | 驱动超时/重置 | EventID 4101, 4109 | Error |
| C-003 | NDIS 网络驱动错误 | EventID 10400 | Warning |
| C-004 | 存储驱动错误 | EventID 11, 15, 51, 153 | Critical |

#### D 类 — 硬件故障预警

| 规则 ID | 检测项 | 触发条件 | 严重级别 |
|---------|--------|----------|----------|
| D-001 | 磁盘 SMART 预警 | EventID 7, 52 | Critical |
| D-002 | 磁盘坏块 | EventID 7, 51 | Critical |
| D-003 | 内存 ECC 纠错 | EventID 46, 47 | Error |
| D-004 | CPU 过热降频 | EventID 37 | Warning |
| D-005 | 网卡重置 | EventID 27, 10400 | Warning |

#### E 类 — 安全事件审计

| 规则 ID | 检测项 | 触发条件 | 严重级别 |
|---------|--------|----------|----------|
| E-001 | 暴力登录尝试 | EventID 4625 ≥ 5次/小时 | Critical |
| E-002 | 权限提升事件 | EventID 4672, 4673 | Warning |
| E-003 | 审计日志清除 | EventID 1102 | Critical |
| E-004 | 防火墙规则变更 | EventID 2003, 2004 | Warning |
| E-005 | 账户创建/删除 | EventID 4720, 4726 | Warning |
| E-006 | RDP 远程连接 | EventID 4624 (LogonType=10) | Info |

---

## 7. Undo / 修复系统

### 7.1 Windows System Restore API 集成

`AURORA-RestoreManager.ps1` 封装 Windows System Restore API，在用户执行修复前自动创建系统还原点。

**API 调用链:**

```powershell
function New-AuroraRestorePoint {
    param(
        [string]$Description = "AURORA Analyzer - Pre-Repair Restore Point",
        [string]$RestorePointType = "MODIFY_SETTINGS"
    )
    
    # 启用系统还原（如果未启用）
    Enable-ComputerRestore -Drive "C:\"
    
    # 创建还原点
    Checkpoint-Computer -Description $Description -RestorePointType $RestorePointType
    
    # 验证还原点创建成功
    $restorePoints = Get-ComputerRestorePoint |
        Where-Object { $_.Description -eq $Description } |
        Sort-Object CreationTime -Descending |
        Select-Object -First 1
    
    return @{
        SequenceNumber = $restorePoints.SequenceNumber
        CreationTime   = $restorePoints.CreationTime
        Description    = $Description
    }
}
```

**还原点限制:**
- 24 小时内仅允许创建 1 个系统还原点（Windows 限制）
- 如果 24 小时内已创建，自动跳过并记录日志
- 系统盘空间不足时提供警告

### 7.2 快速备份快照机制

`AURORA-UndoManager.ps1` 提供比系统还原更轻量级的快照备份。

**支持的备份目标类型:**

| 类型 | 备份方式 | 示例 |
|------|----------|------|
| **注册表项** | `reg export` → .reg 文件 | HKLM\SYSTEM\CurrentControlSet\Services\wuauserv |
| **注册表值** | `Get-ItemProperty` → JSON | 服务配置值 |
| **文件** | 复制到备份目录 | C:\Windows\System32\drivers\etc\hosts |
| **服务状态** | `Get-Service` → JSON | 服务启动类型、状态 |
| **计划任务** | `Get-ScheduledTask` → XML | 任务定义导出 |

**备份快照结构:**

```
Scripts\UndoBackups\
    └── UNDO_20260525_105443_1875\
        ├── manifest.json          # 快照清单
        ├── registry\
        │   ├── wuauserv_start.reg
        │   └── wuauserv_config.json
        ├── files\
        │   └── hosts.backup
        ├── services\
        │   └── services_state.json
        └── tasks\
            └── scheduled_tasks.xml
```

**manifest.json 结构:**

```json
{
  "SessionId": "UNDO_20260525_105443_1875",
  "CreatedAt": "2026-05-25T10:54:43+08:00",
  "RepairType": "DisableWindowsUpdate",
  "Backups": [
    {
      "Type": "RegistryKey",
      "Path": "HKLM\\SYSTEM\\CurrentControlSet\\Services\\wuauserv",
      "BackupFile": "registry\\wuauserv_start.reg",
      "OriginalState": "Start=3 (Manual)"
    }
  ],
  "Reversible": true
}
```

### 7.3 修复命令日志审计

`AURORA-RepairLogger.ps1` 记录每一次修复操作的完整审计追踪。

**日志记录结构:**

```powershell
function Write-RepairLog {
    param(
        [string]$SessionId,
        [string]$Command,
        [hashtable]$Parameters,
        [string]$Result,
        [string]$BackupPath,
        [string]$ErrorMessage
    )
    
    $entry = [PSCustomObject]@{
        Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        SessionId    = $SessionId
        Command      = $Command
        Parameters   = ($Parameters | ConvertTo-Json -Compress)
        Result       = $Result              # Success | Failed | Partial | Reverted
        BackupPath   = $BackupPath
        ErrorMessage = $ErrorMessage
        UserSID      = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        MachineName  = $env:COMPUTERNAME
    }
    
    $logFile = Join-Path $PSScriptRoot "..\Logs\repair_audit_$(Get-Date -Format 'yyyyMMdd').jsonl"
    $entry | ConvertTo-Json -Compress | Add-Content -Path $logFile
}
```

**审计日志格式 (JSONL):**

```jsonl
{"Timestamp":"2026-05-25 10:54:43.125","SessionId":"REPAIR_20260525_001","Command":"DisableWindowsUpdate","Parameters":"{...}","Result":"Success","BackupPath":"Scripts\\UndoBackups\\UNDO_20260525_105443_1875","ErrorMessage":null,"UserSID":"S-1-5-21-...","MachineName":"DESKTOP-XXX"}
{"Timestamp":"2026-05-25 10:55:01.882","SessionId":"REPAIR_20260525_001","Command":"EnableDefender","Parameters":"{...}","Result":"Failed","BackupPath":"Scripts\\UndoBackups\\UNDO_20260525_105501_XXXX","ErrorMessage":"Access Denied - 需要 TrustedInstaller 权限","UserSID":"S-1-5-21-...","MachineName":"DESKTOP-XXX"}
```

### 7.4 一键撤销实现

撤销操作支持按 SessionId 回滚所有关联的修复操作。

```powershell
function Invoke-AuroraUndo {
    param(
        [string]$SessionId,
        [switch]$Force
    )
    
    # 1. 加载快照清单
    $manifestPath = "Scripts\UndoBackups\$SessionId\manifest.json"
    if (-not (Test-Path $manifestPath)) {
        throw "Undo manifest not found: $SessionId"
    }
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    
    # 2. 风险确认
    if (-not $Force) {
        $confirm = Read-Host "即将撤销 Session [$SessionId] 的 {0} 项操作，确认? (Y/N)" -f $manifest.Backups.Count
        if ($confirm -ne 'Y') { return }
    }
    
    # 3. 逆序回滚（LIFO）
    $results = @()
    for ($i = $manifest.Backups.Count - 1; $i -ge 0; $i--) {
        $backup = $manifest.Backups[$i]
        try {
            switch ($backup.Type) {
                'RegistryKey' {
                    reg import "$UndoPath\$($backup.BackupFile)" *>$null
                }
                'File' {
                    Copy-Item "$UndoPath\$($backup.BackupFile)" $backup.Path -Force
                }
                'Service' {
                    $state = Get-Content "$UndoPath\$($backup.BackupFile)" | ConvertFrom-Json
                    Set-Service -Name $state.Name -StartupType $state.StartType
                }
            }
            $results += @{ Type=$backup.Type; Path=$backup.Path; Result='Restored' }
        }
        catch {
            $results += @{ Type=$backup.Type; Path=$backup.Path; Result='Failed'; Error=$_.Exception.Message }
        }
    }
    
    # 4. 更新审计日志
    Write-RepairLog -SessionId $SessionId -Command "Undo" -Parameters @{OriginalSession=$SessionId} `
        -Result $(if($results.Where({$_.Result -eq 'Failed'}).Count -eq 0){'Success'}else{'Partial'})
    
    return $results
}
```

### 7.5 修复历史查看器

`AURORA-UndoViewer.ps1` 提供交互式修复历史查看界面。

**功能特性:**
- 最近 20 条修复记录展示
- 按 SessionId / 日期时间 / 修复类型排序
- 状态标识图标（成功 ✓ / 失败 ✗ / 部分 ⚠ / 已撤销 ↩）
- 支持选择特定记录执行撤销操作
- 导出审计报告为 CSV 格式

---

## 8. 安全体系 — 纵深防御四层模型

### 8.1 第一层：构建时安全

构建时安全在 `build.ps1` 执行期间建立，确保从编译产出的那一刻起就受到保护。

#### 8.1.1 RSA-2048 密钥对生成

```powershell
$rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new(2048)
$privateKey = $rsa.ToXmlString($true)   # 包含私钥
$publicKey  = $rsa.ToXmlString($false)  # 仅公钥

# 私钥碎片化存储到 C# 源码
$privateKeyBytes = [System.Text.Encoding]::UTF8.GetBytes($privateKey)
$chunks = Split-BytesIntoChunks -Bytes $privateKeyBytes -ChunkSize 64

# 公钥注入 PS1
$publicKeyBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($publicKey))
```

#### 8.1.2 密码混淆算法

密码在嵌入 C# 源码前经过双重混淆：

```csharp
// 第一层: XOR 混淆
byte[] xorKey = { 0xA3, 0x7F, 0x12, 0x9B, 0x44, 0xC8, 0x3E, 0xD1 };
byte[] obscured = new byte[password.Length];
for (int i = 0; i < password.Length; i++)
    obscured[i] = (byte)(password[i] ^ xorKey[i % xorKey.Length]);

// 第二层: Fisher-Yates Shuffle
int[] indices = { 3, 7, 0, 5, 2, 6, 1, 4, ... }; // 基于种子的伪随机排列
byte[] shuffled = new byte[obscured.Length];
for (int i = 0; i < obscured.Length; i++)
    shuffled[indices[i]] = obscured[i];

// 存储: 将 shuffled 字节数组以十六进制形式写入源码
string hexPassword = BitConverter.ToString(shuffled).Replace("-", "");
// → string _p = "A3B7C292...";
```

#### 8.1.3 SHA256 哈希签名

```powershell
$coreFiles = @(
    "Scripts\AURORA-AnalyzerLauncherGUI.ps1",
    "Scripts\AURORA-GUI-Functions.ps1",
    "Scripts\AURORA-CoreEngine.ps1",
    "Scripts\AURORA-AnalyzerPRO.ps1",
    "Scripts\AURORA-AnalyzerCHSPRO.ps1",
    "Scripts\AURORA-AnalyzerENGPRO.ps1",
    "Scripts\AURORA-SmartEngine.ps1",
    "Scripts\AURORA-ProgressManager.ps1",
    "Scripts\AURORA-ProgressManager-Integration.ps1",
    "Scripts\AURORA-ProgressManager-Integration-CHS.ps1",
    "Scripts\AURORA-ProgressManager-Integration-ENG.ps1",
    "Scripts\AURORA-RestoreManager.ps1",
    "Scripts\AURORA-RepairLogger.ps1",
    "Scripts\AURORA-UndoManager.ps1",
    "Scripts\AURORA-RepairTools.ps1",
    "Scripts\AURORA-UndoViewer.ps1",
    "Scripts\AURORA-Language.psd1",
    "Scripts\Core\AURORA-AnimationCoreEngine.ps1",
    "Data\AURORA-TechData.json"
)

$hashes = @{}
foreach ($file in $coreFiles) {
    $fullPath = Join-Path $OutputDir $file
    $hash = (Get-FileHash -Path $fullPath -Algorithm SHA256).Hash
    $hashes[$file] = $hash
}
```

#### 8.1.4 AES-256-CBC 加密哈希清单

```powershell
# PBKDF2 密钥派生
$salt = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
$iterations = 100000
$deriveBytes = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($password, $salt, $iterations, 'SHA256')
$key = $deriveBytes.GetBytes(32)  # AES-256 密钥
$iv  = $deriveBytes.GetBytes(16)  # CBC 初始化向量

# AES 加密
$aes = [System.Security.Cryptography.Aes]::Create()
$aes.Key = $key
$aes.IV  = $iv
$aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
$aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

$plaintext = $hashes | ConvertTo-Json | [Text.Encoding]::UTF8.GetBytes($null)
$encryptor = $aes.CreateEncryptor()
$ciphertext = $encryptor.TransformFinalBlock($plaintext, 0, $plaintext.Length)

# 写入文件: Salt(32B) + IV(16B) + Ciphertext
[System.IO.File]::WriteAllBytes("$OutputDir\GAURORA.CHK.ENC", $salt + $iv + $ciphertext)
```

### 8.2 第二层：启动安全

#### 8.2.1 反调试检测 (C# 端)

```csharp
[DllImport("kernel32.dll")]
static extern bool IsDebuggerPresent();

[DllImport("kernel32.dll")]
static extern bool CheckRemoteDebuggerPresent(IntPtr hProcess, ref bool pbDebuggerPresent);

bool DetectDebugger() {
    // 1. Win32 API 检测
    if (IsDebuggerPresent()) return true;
    
    bool remoteDebugger = false;
    CheckRemoteDebuggerPresent(Process.GetCurrentProcess().Handle, ref remoteDebugger);
    if (remoteDebugger) return true;
    
    // 2. 进程枚举检测已知调试器
    string[] debuggers = { "x64dbg", "ollydbg", "scylla", "phantom", "windbg", "ida" };
    foreach (var proc in Process.GetProcesses()) {
        foreach (var dbg in debuggers) {
            if (proc.ProcessName.ToLower().Contains(dbg)) return true;
        }
    }
    
    return false;
}
```

#### 8.2.2 完整性验证流程

```
读取 GAURORA.CHK.ENC
    │
    ├─ 提取 Salt (前 32 字节)
    ├─ 提取 IV (接下来 16 字节)
    ├─ 提取 Ciphertext (剩余全部)
    │
    ├─ PBKDF2-SHA256 派生密钥 (password + salt, 100,000 iter)
    │
    ├─ AES-256-CBC 解密 → JSON 哈希清单
    │
    ├─ 检查 19 个核心文件是否存在
    │     └─ 任一缺失 → 终止启动
    │
    ├─ 逐文件计算 SHA256 并比对
    │     └─ 任一不匹配 → 终止启动
    │
    └─ 全部通过 → 允许启动
```

#### 8.2.3 清理操作

```powershell
# 启动完成后立即清理
Remove-Item Env:\AURORA_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:\AURORA_TEMP_DIR -ErrorAction SilentlyContinue
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
```

### 8.3 第三层：运行时安全

#### 8.3.1 双重定时器机制

```powershell
# 定时器 1: 固定 3 秒间隔
$timer1 = [System.Timers.Timer]::new(3000)
$timer1.AutoReset = $true
$timer1.add_Elapsed({ Invoke-IntegrityCheck -Mode 'Scheduled' })

# 定时器 2: 随机 2-7 秒间隔（反预测）
$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
function Get-RandomInterval {
    $bytes = [byte[]]::new(4)
    $rng.GetBytes($bytes)
    $randomMs = 2000 + ([BitConverter]::ToUInt32($bytes, 0) % 5000)
    return $randomMs
}
$timer2 = [System.Timers.Timer]::new((Get-RandomInterval))
$timer2.AutoReset = $false
$timer2.add_Elapsed({
    Invoke-IntegrityCheck -Mode 'Random'
    $timer2.Interval = Get-RandomInterval
    $timer2.Start()
})
```

#### 8.3.2 FileSystemWatcher 实时监控

```powershell
$watcher = [System.IO.FileSystemWatcher]::new()
$watcher.Path = $ScriptsDir
$watcher.IncludeSubdirectories = $true
$watcher.Filter = "*.*"
$watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor
                        [System.IO.NotifyFilters]::LastWrite -bor
                        [System.IO.NotifyFilters]::Size

# 监控事件注册
Register-ObjectEvent $watcher "Created"  -Action { On-FileCreated $EventArgs }  *>$null
Register-ObjectEvent $watcher "Changed"  -Action { On-FileChanged $EventArgs }  *>$null
Register-ObjectEvent $watcher "Deleted"  -Action { On-FileDeleted $EventArgs }  *>$null
Register-ObjectEvent $watcher "Renamed"  -Action { On-FileRenamed $EventArgs }  *>$null

# 监控文件扩展名
$watcher.Filter = "*.ps1"
$watcher.EnableRaisingEvents = $true
```

**监控文件类型:**

| 扩展名 | 原因 |
|--------|------|
| `.ps1` | PowerShell 脚本，最核心的保护对象 |
| `.json` | 诊断规则知识库 |
| `.xml` | 配置文件 |
| `.ico` | 图标资源（可被替换为恶意快捷方式） |
| `.exe` | 可执行文件 |
| `.enc` | 加密哈希清单 |

#### 8.3.3 四项检测逻辑

```powershell
function Invoke-IntegrityCheck {
    param([string]$Mode)
    
    $violations = @()
    
    # 检测 1: 文件计数检查
    $currentCount = (Get-ChildItem $ScriptsDir -Recurse -File).Count
    if ($currentCount -ne $expectedFileCount) {
        $violations += "文件计数不匹配: 期望 $expectedFileCount, 实际 $currentCount"
    }
    
    # 检测 2: 核心文件存在性
    foreach ($file in $coreFileList) {
        if (-not (Test-Path (Join-Path $BaseDir $file))) {
            $violations += "核心文件丢失: $file"
        }
    }
    
    # 检测 3: SHA256 哈希比对
    foreach ($file in $coreFileList) {
        $currentHash = (Get-FileHash (Join-Path $BaseDir $file) -Algorithm SHA256).Hash
        if ($currentHash -ne $expectedHashes[$file]) {
            $violations += "文件被篡改: $file (期望 $($expectedHashes[$file][0..7]), 实际 $($currentHash[0..7]))"
        }
    }
    
    # 检测 4: 未授权文件注入
    $allFiles = Get-ChildItem $ScriptsDir -Recurse -File | ForEach-Object {
        $_.FullName.Replace($BaseDir, '').TrimStart('\')
    }
    $unauthorizedFiles = $allFiles | Where-Object { $_ -notin $authorizedFileList }
    if ($unauthorizedFiles) {
        $violations += "检测到未授权文件: $($unauthorizedFiles -join ', ')"
    }
    
    if ($violations) {
        Invoke-TamperResponse -Violations $violations
    }
}
```

#### 8.3.4 篡改响应

```powershell
function Invoke-TamperResponse {
    param([string[]]$Violations)
    
    # 1. 记录违规详情
    $violations | ForEach-Object { Write-EventLog ... }
    
    # 2. 停止所有监控
    $timer1.Stop()
    $timer2.Stop()
    $watcher.EnableRaisingEvents = $false
    
    # 3. 通知 GUI 线程
    $syncHash.TamperDetected = $true
    $syncHash.Violations = $Violations
    
    # 4. 显示倒计时关闭对话框
    for ($i = 15; $i -gt 0; $i--) {
        $syncHash.StatusMessage = "安全异常: 程序将在 $i 秒后退出"
        Start-Sleep -Seconds 1
    }
    
    # 5. 强制退出
    [System.Environment]::Exit(1)
}
```

### 8.4 第四层：多模块启动检测

在 `AURORA-AnalyzerLauncherGUI.ps1` 中，启动时需要同时满足多项条件才能初始化：

```powershell
# 启动防护检查
function Test-StartupSecurity {
    # 检查 1: GUI_Mode 参数
    if ($env:AURORA_GUI_MODE -ne '1') {
        Write-Host "ERROR: 未授权的启动方式" -ForegroundColor Red
        Start-Sleep 5
        exit 1
    }
    
    # 检查 2: syncHash 全局变量
    if (-not $syncHash -or $syncHash.Count -eq 0) {
        Write-Host "ERROR: 缺少启动上下文" -ForegroundColor Red
        Start-Sleep 5
        exit 1
    }
    
    # 检查 3: RSA Token 验证
    if (-not (Test-RsaToken -Token $syncHash.Token)) {
        Write-Host "ERROR: Token 验证失败" -ForegroundColor Red
        Start-Sleep 5
        exit 1
    }
}
```

### 8.5 RSA 握手协议详解

RSA 握手是 EXE 启动器与 PS1 GUI 之间的认证协议，确保 PS1 脚本只能由授权的 EXE 启动。

**协议流程:**

```
┌──────────────────┐                      ┌──────────────────┐
│   C# EXE 启动器   │                      │  PowerShell GUI   │
│   (持有 RSA 私钥)  │                      │  (持有 RSA 公钥)   │
└────────┬─────────┘                      └────────┬─────────┘
         │                                         │
         │  1. 生成 Nonce (GUID)                    │
         │     Timestamp = DateTime.UtcNow          │
         │     Payload = Nonce + ":" + Timestamp    │
         │     HashB64 = SHA256(Payload) → Base64   │
         │     Signature = RSA-Sign(Hash, PrivKey)  │
         │     Token = Nonce:Timestamp:HashB64:Sig  │
         │                                         │
         │  2. 启动 PowerShell                      │
         │     传入 Token 作为参数                   │
         │  ──────────────────────────────────────► │
         │                                         │
         │                    3. 解析 Token          │
         │                       parts = Token.Split(':')
         │                       Nonce = parts[0]    │
         │                       Timestamp = parts[1]│
         │                       HashB64 = parts[2]  │
         │                       Signature = parts[3]│
         │                                         │
         │                    4. 验证时间戳           │
         │                       age = UtcNow - Timestamp
         │                       if age > 60s → 过期  │
         │                       if age < -5s → 时钟偏移│
         │                                         │
         │                    5. 验证签名             │
         │                       Payload = Nonce+":"+Timestamp
         │                       CalcHash = SHA256(Payload)
         │                       RSA-Verify(CalcHash, Sig, PubKey)
         │                                         │
         │                    6. 发送确认             │
         │  ◄────────────────────────────────────── │
         │        syncHash.TokenValidated = true    │
         │                                         │
         │  7. 等待确认超时 (10秒)                    │
         │     if 超时 → 终止 PowerShell             │
         │                                         │
         ▼                                         ▼
     主循环开始                                  GUI 初始化完成
```

**Token 格式:**

```
Base64(
    Nonce       (36 字符 GUID)
    :           (分隔符)
    Timestamp   (ISO 8601 UTC 时间戳)
    :           (分隔符)
    HashB64     (SHA256 哈希的 Base64)
    :           (分隔符)
    Signature   (RSA-2048 签名的 Base64)
)
```

**验证容差设计:**

| 场景 | 条件 | 处理 |
|------|------|------|
| Token 过期 | `age > 60s` | 拒绝，终止启动 |
| 时钟偏移（正向） | `0s < age ≤ 5s` | 视为异常容差，允许 |
| 时钟偏移（负向） | `-5s < age < 0s` | 远程时钟稍快，允许 |
| 重放攻击 | Nonce 已使用 | 拒绝 |
| 签名不匹配 | `RSA-Verify == false` | 拒绝 |

---

## 9. 构建系统

### 9.1 build.ps1 全流程

`build.ps1` 是整个项目的自动化构建脚本，完整流程如下：

```
┌─────────────────────────────────────────────────────────┐
│                    build.ps1 执行流程                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─ 1. 版本管理 ──────────────────────────────────┐    │
│  │    读取 version.txt → $version                  │    │
│  │    显示构建信息: "AURORA Analyzer v{version}"    │    │
│  └────────────────────────────────────────────────┘    │
│                         │                               │
│  ┌─ 2. 密码验证 ──────────────────────────────────┐    │
│  │    输入构建密码                                  │    │
│  │    强度验证: 8字符 + 大小写 + 数字 + 特殊字符     │    │
│  │    最多 3 次重试                                 │    │
│  │    验证通过 → 继续, 失败 → 退出                  │    │
│  └────────────────────────────────────────────────┘    │
│                         │                               │
│  ┌─ 3. 交互菜单 ──────────────────────────────────┐    │
│  │    [1] 完整构建                                 │    │
│  │    [2] 仅编译 C# 启动器                         │    │
│  │    [3] 仅打包 Release                           │    │
│  │    [4] 仅重新生成安全密钥                        │    │
│  │    [5] 退出                                     │    │
│  └────────────────────────────────────────────────┘    │
│                         │                               │
│  ┌─ 4. RSA 密钥生成 ──────────────────────────────┐    │
│  │    生成 RSA-2048 密钥对                          │    │
│  │    私钥 → 碎片化嵌入 C# 源码                     │    │
│  │    公钥 → Base64 注入 PS1 脚本                   │    │
│  └────────────────────────────────────────────────┘    │
│                         │                               │
│  ┌─ 5. 安全检查代码注入 ──────────────────────────┐    │
│  │    检测已有注入 → 更新密钥/替换占位符/首次注入    │    │
│  │    密码混淆 (XOR + Shuffle)                     │    │
│  │    反调试代码注入                               │    │
│  └────────────────────────────────────────────────┘    │
│                         │                               │
│  ┌─ 6. C# 编译 ──────────────────────────────────┐    │
│  │    定位 csc.exe ( .NET Framework )              │    │
│  │    类名/方法名混淆重命名                         │    │
│  │    编译参数:                                    │    │
│  │      -platform:x86                              │    │
│  │      -target:winexe                             │    │
│  │      -reference:System.Windows.Forms.dll        │    │
│  │      -out:AURORA.Launcher-双击启动.exe          │    │
│  └────────────────────────────────────────────────┘    │
│                         │                               │
│  ┌─ 7. 完整性签名 ───────────────────────────────┐    │
│  │    遍历 19 个核心文件 → SHA256                  │    │
│  │    PBKDF2-SHA256 密钥派生                       │    │
│  │    AES-256-CBC 加密 → GAURORA.CHK.ENC          │    │
│  └────────────────────────────────────────────────┘    │
│                         │                               │
│  ┌─ 8. 打包与分发 ───────────────────────────────┐    │
│  │    创建 Releases 文件夹                         │    │
│  │    复制核心文件到发布目录                        │    │
│  │    desktop.ini 文件夹美化                       │    │
│  │    ZIP 压缩归档                                │    │
│  │    输出: AURORA-AnalyzerV{version}Release.zip   │    │
│  └────────────────────────────────────────────────┘    │
│                         │                               │
│  ┌─ 9. 构建日志 ─────────────────────────────────┐    │
│  │    写入 build.log                               │    │
│  │    记录: 时间、版本、文件哈希、构建选项          │    │
│  └────────────────────────────────────────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 9.2 C# 混淆编译

**元数据混淆策略:**

```powershell
# build.ps1 中的混淆步骤
function Invoke-CSharpObfuscation {
    param([string]$SourceFile, [string]$OutputFile)
    
    $content = Get-Content $SourceFile -Raw
    
    # 替换规则映射表
    $obfuscationMap = @{
        'RsaValidator'      = Generate-RandomName
        'IntegrityChecker'  = Generate-RandomName
        'AntiDebugGuard'    = Generate-RandomName
        'TokenGenerator'    = Generate-RandomName
        'DecryptHashList'   = Generate-RandomName
        'ValidatePassword'  = Generate-RandomName
        'HandleShutdown'    = Generate-RandomName
    }
    
    foreach ($entry in $obfuscationMap.GetEnumerator()) {
        $content = $content -replace "\b$($entry.Key)\b", $entry.Value
    }
    
    Set-Content -Path $OutputFile -Value $content
}

function Generate-RandomName {
    $prefixes = @('Aurora', 'Core', 'Sys', 'Win', 'Net', 'Proc')
    $suffixes = @('Mgr', 'Util', 'Helper', 'Svc', 'Ctrl', 'Guard', 'Proxy')
    $prefix = $prefixes | Get-Random
    $suffix = $suffixes | Get-Random
    $numeric = Get-Random -Minimum 100 -Maximum 999
    return "${prefix}${suffix}${numeric}"
}
```

**C# 编译命令:**

```batch
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe ^
    /platform:x86 ^
    /target:winexe ^
    /reference:System.dll ^
    /reference:System.Windows.Forms.dll ^
    /reference:System.Drawing.dll ^
    /reference:System.Security.dll ^
    /out:"AURORA.Launcher-双击启动.exe" ^
    "launcher_obfuscated.cs"
```

### 9.3 打包与分发

**Release 目录结构:**

```
AURORA-AnalyzerV1.1.24.0Release/
    ├── AURORA.Launcher-双击启动.exe          # 启动器
    ├── GAURORA.CHK.ENC                       # 加密哈希清单
    ├── desktop.ini                           # 文件夹美化
    ├── version.txt                           # 版本号
    ├── Data/
    │   └── AURORA-TechData.json              # 诊断规则库
    ├── Docs/
    │   ├── README_V1.1.24.0.md               # 开发者文档
    │   ├── README_V1.1.24.0_EN.md            # 英文开发者文档
    │   ├── README_V1.1.24.0_Update.md        # 更新日志
    │   └── README_V1.1.24.0_Update_EN.md     # 英文更新日志
    ├── Resources/
    │   ├── AURORAICON.ico                    # 应用图标
    │   └── CascadiaMono.ttf                  # 字体文件
    └── Scripts/
        ├── Core/
        │   ├── AURORA-AnimationCoreEngine.dll # 动画引擎
        │   └── AURORA-AnimationCoreEngine.ps1 # 动画引擎源码
        ├── SessionCache/
        │   ├── active/                       # 活跃会话
        │   └── archive/                      # 归档会话
        ├── AURORA-AnalyzerLauncherGUI.ps1     # 主 GUI
        ├── AURORA-GUI-Functions.ps1           # GUI 辅助
        ├── AURORA-AnalyzerPRO.ps1             # PRO 入口
        ├── AURORA-AnalyzerCHSPRO.ps1          # 中文 PRO
        ├── AURORA-AnalyzerENGPRO.ps1          # 英文 PRO
        ├── AURORA-SmartEngine.ps1             # 智能诊断
        ├── AURORA-ProgressManager.ps1         # 进度管理
        ├── AURORA-ProgressManager-Integration.ps1
        ├── AURORA-ProgressManager-Integration-CHS.ps1
        ├── AURORA-ProgressManager-Integration-ENG.ps1
        ├── AURORA-CoreEngine.ps1              # 核心引擎
        ├── AURORA-Language.psd1               # 双语资源
        ├── AURORA-RestoreManager.ps1          # 系统还原
        ├── AURORA-RepairLogger.ps1            # 修复日志
        ├── AURORA-UndoManager.ps1             # 撤销管理
        ├── AURORA-RepairTools.ps1             # 修复工具
        └── AURORA-UndoViewer.ps1              # 历史查看
```

---

## 10. 国际化架构

AURORA Analyzer 使用 PowerShell Data File (`.psd1`) 作为集中式国际化资源文件。

**`AURORA-Language.psd1` 结构:**

```powershell
@{
    # 通用
    AppTitle       = @{ zh = "AURORA Analyzer";            en = "AURORA Analyzer" }
    AppVersion     = @{ zh = "版本";                       en = "Version" }
    AppAuthor      = @{ zh = "作者";                       en = "Author" }
    
    # 菜单
    MenuExport     = @{ zh = "日志导出";                   en = "Log Export" }
    MenuDiagnose   = @{ zh = "智能诊断";                   en = "Smart Diagnosis" }
    MenuRepair     = @{ zh = "系统修复";                   en = "System Repair" }
    MenuSettings   = @{ zh = "设置";                       en = "Settings" }
    MenuAbout      = @{ zh = "关于";                       en = "About" }
    
    # 日志类型
    LogTypeSystem       = @{ zh = "系统";                  en = "System" }
    LogTypeApplication  = @{ zh = "应用程序";              en = "Application" }
    LogTypeSecurity     = @{ zh = "安全";                  en = "Security" }
    LogTypeSetup        = @{ zh = "安装";                  en = "Setup" }
    LogTypeDNS          = @{ zh = "DNS 服务器";            en = "DNS Server" }
    LogTypeDHCP         = @{ zh = "DHCP 服务器";           en = "DHCP Server" }
    LogTypeDirectory    = @{ zh = "目录服务";              en = "Directory Service" }
    LogTypeIIS          = @{ zh = "IIS 管理";              en = "IIS Admin" }
    
    # 状态
    StatusRunning       = @{ zh = "运行中...";             en = "Running..." }
    StatusCompleted     = @{ zh = "完成";                  en = "Completed" }
    StatusFailed        = @{ zh = "失败";                  en = "Failed" }
    StatusCancelled     = @{ zh = "已取消";                en = "Cancelled" }
    
    # 诊断分类
    DiagCatA            = @{ zh = "系统稳定性";            en = "System Stability" }
    DiagCatB            = @{ zh = "应用程序错误";          en = "Application Errors" }
    DiagCatC            = @{ zh = "驱动程序问题";          en = "Driver Issues" }
    DiagCatD            = @{ zh = "硬件故障预警";          en = "Hardware Warnings" }
    DiagCatE            = @{ zh = "安全事件审计";          en = "Security Audit" }
    
    # ... 共 144 条翻译条目
}
```

**翻译函数:**

```powershell
function Get-AuroraText {
    param(
        [string]$Key,
        [string]$Language = $script:CurrentLanguage
    )
    
    if ($script:LanguageData.ContainsKey($Key)) {
        $entry = $script:LanguageData[$Key]
        if ($Language -eq 'zh') {
            return $entry.zh
        } else {
            return $entry.en
        }
    }
    
    return "[MISSING:$Key]"
}
```

---

## 11. 性能与安全权衡设计

### 安全检测性能开销

| 检测项 | 频率 | 单次耗时 (典型) | CPU 占用 |
|--------|------|-----------------|----------|
| 文件计数 | 3s + 随机 | < 5ms | ~0% |
| 文件存在性 | 3s + 随机 | < 10ms | ~0% |
| SHA256 哈希 | 3s + 随机 | 50-200ms | 1-3% |
| 未授权文件扫描 | 3s + 随机 | 20-50ms | ~0% |
| FileSystemWatcher | 持续 | 0ms (被动) | ~0% |

**总计开销:**
- CPU: 1-5% (单核)
- 内存: 20-50MB (包括 .NET Runtime)
- 磁盘: 每 3-7 秒读取约 500KB → 18MB/小时

### 性能优化策略

1. **哈希缓存**: 仅在 FileSystemWatcher 检测到变化后重新计算哈希
2. **文件列表缓存**: 预期文件列表在内存中，避免每次磁盘枚举
3. **增量检查**: 时钟定时器触发快照比对，FileSystemWatcher 触发增量更新
4. **异步 I/O**: 所有文件读取操作使用异步 API

---

## 12. 错误处理与日志

### 全局错误处理

```powershell
$ErrorActionPreference = 'Stop'

trap {
    $errorInfo = @{
        Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        ErrorMessage = $_.Exception.Message
        ErrorType    = $_.Exception.GetType().FullName
        StackTrace   = $_.ScriptStackTrace
        LineNumber   = $_.InvocationInfo.ScriptLineNumber
        ScriptName   = $_.InvocationInfo.ScriptName
        Command      = $_.InvocationInfo.MyCommand.Name
    }
    
    # 写入错误日志
    $errorInfo | ConvertTo-Json -Compress |
        Add-Content -Path "$BaseDir\error_$(Get-Date -Format 'yyyyMMdd').log"
    
    # 通知用户
    if ($syncHash) {
        $syncHash.Error = $errorInfo
        $syncHash.IsCompleted = $true
    }
    
    continue
}
```

### 日志文件层次

| 日志类型 | 路径 | 内容 | 保留策略 |
|----------|------|------|----------|
| 构建日志 | `build.log` | 构建时间、版本、哈希、选项 | 追加，手动清理 |
| 错误日志 | `error_YYYYMMDD.log` | 运行时错误堆栈 | 30 天 |
| 审计日志 | `Logs\repair_audit_YYYYMMDD.jsonl` | 修复操作审计追踪 | 永久保留 |
| 会话日志 | `Scripts\SessionCache\*.json` | 导出/诊断会话状态 | 完成→归档, 30天清理 |

---

> **文档版本**: V1.1.24.0
> **生成日期**: 2026-05-25
> **作者**: AURORA VelociRaptor-GR Dev PRJ.
> **许可**: 仅供个人学习与研究使用