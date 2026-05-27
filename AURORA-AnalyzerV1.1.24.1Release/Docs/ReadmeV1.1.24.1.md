# AURORA Analyzer V1.1.24.1 — 开发者技术手册

> **面向读者**: 开发者 / 安全研究员 / 逆向工程师 / 代码审计人员
> **文档定位**: 超详细源码级功能解析，覆盖架构设计、安全模型、模块实现、构建流程

***

## 目录

- [1. 项目概况](#1-项目概况)
- [2. v1.1.24.1 核心更新总览](#2-v11241-核心更新总览)
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
  - [5.4 智能权限管理 — 提权安全令牌](#54-智能权限管理--提权安全令牌)
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
- [8. 安全体系 — 纵深防御五层模型](#8-安全体系--纵深防御五层模型)
  - [8.1 第一层：构建时安全](#81-第一层构建时安全)
  - [8.2 第二层：启动安全](#82-第二层启动安全)
  - [8.3 第三层：运行时安全](#83-第三层运行时安全)
  - [8.4 第四层：多模块启动检测](#84-第四层多模块启动检测)
  - [8.5 第五层：Named Pipe 看门狗守护 🆕](#85-第五层named-pipe-看门狗守护-)
  - [8.6 C# 嵌入式完整性守卫 (AuroraGuard) 🆕](#86-c-嵌入式完整性守卫-auroraguard-)
  - [8.7 提权安全令牌 (AURORA-SEC-2026-001) 🆕](#87-提权安全令牌-aurora-sec-2026-001-)
  - [8.8 反伪造启动参数保护 🆕](#88-反伪造启动参数保护-)
- [9. 构建系统](#9-构建系统)
  - [9.1 build.ps1 全流程](#91-buildps1-全流程)
  - [9.2 C# 混淆编译](#92-c-混淆编译)
  - [9.3 AuroraGuard 哈希注入 (2.5/6) 🆕](#93-auroraguard-哈希注入-256-)
  - [9.4 打包与分发](#94-打包与分发)
- [10. 国际化架构](#10-国际化架构)
- [11. 性能与安全权衡设计 — LastWriteTime 优化 🆕](#11-性能与安全权衡设计--lastwritetime-优化-)
- [12. 错误处理与日志](#12-错误处理与日志)

***

## 1. 项目概况

| 属性       | 值                                           |
| -------- | ------------------------------------------- |
| **项目名称** | AURORA Analyzer                             |
| **版本**   | V1.1.24.1                                   |
| **构建日期** | 2026-05-27                                  |
| **作者**   | AURORA VelociRaptor-GR Dev PRJ.             |
| **许可**   | 仅供个人学习与研究使用                                 |
| **类型**   | Windows 系统事件日志导出与智能诊断工具                     |
| **核心语言** | C# (.NET Framework 4.x) + PowerShell 7+     |
| **目标平台** | Windows 10/11 x64 (需 .NET Framework 4.7.2+) |
| **最低权限** | 标准用户 (部分功能需管理员)                             |

### 核心能力矩阵

| 能力域  | 描述                       | 技术栈                             |
| ---- | ------------------------ | ------------------------------- |
| 日志导出 | 8 种 Windows 事件日志类型，多格式输出 | PowerShell `Get-WinEvent` API   |
| 智能诊断 | 100+ 规则知识图谱匹配            | JSON 规则引擎 + PowerShell          |
| 蓝屏分析 | Minidump 自动解析            | Windows Debugger API            |
| 系统修复 | 一键修复 5 大类系统问题            | PowerShell + Windows API        |
| 撤销系统 | 双保险回滚（还原点 + 快照）          | System Restore API + 注册表/文件备份   |
| 安全防护 | 五层纵深防御                   | RSA-2048 + AES-256-CBC + PBKDF2 + HMAC-SHA256 + Named Pipe |
| 国际化  | 中英双语                     | PowerShell Data File (.psd1)    |
| GUI  | Windows Forms 原生界面       | C# WinForms + 多线程 Runspace      |

***

## 2. v1.1.24.1 核心更新总览

本版本从 v1.1.24.0 的四层纵深防御模型升级为**五层纵深防御模型**，新增 Named Pipe 看门狗守护和 C# 嵌入式完整性守卫。具体变更如下：

### 安全架构升级

| 编号 | 更新项                       | 类型        | 详细说明                             |
| -- | ------------------------- | --------- | -------------------------------- |
| 1  | Named Pipe 看门狗守护           | **新增**    | EXE↔PS1 HMAC-SHA256 双向挑战-响应心跳，第五层独立防御 |
| 2  | C# 嵌入式完整性守卫 (AuroraGuard)  | **新增**    | 运行时编译 IL，16 个核心子模块 SHA256 验证    |
| 3  | 提权安全令牌 (AURORA-SEC-2026-001) | **P0 修复** | 独立 AES-256-CBC 令牌，120s 过期，解决提权信任链断裂 |
| 4  | 反伪造 -LaunchedByExe 保护       | **P0 修复** | 伪造参数检测，令牌无效时强制重置安全状态            |
| 5  | LastWriteTime 快速筛选         | **P2 优化** | 跳过未修改文件的 SHA256 计算，CPU 开销降低 95%   |
| 6  | C# 内嵌倒计时告警窗口               | **重构**    | 替代 PowerShell Timer，消除作用域和稳定性问题   |
| 7  | Assembly 重复加载检查            | **修复**    | 避免重复 Add-Type 导致的报错               |
| 8  | AuroraGuard 哈希注入 (build.ps1) | **新增**    | 构建时自动注入 16 个子模块 SHA256 哈希到 C# 源码  |
| 9  | 智能安全代码注入增强                | **增强**    | 支持首次注入、密钥更新、哈希更新三种模式             |
| 10 | 纵深防御升级：四层 → 五层              | **架构升级**   | 新增独立进程级看门狗保护                     |

***

## 3. 完整模块架构

### 3.1 文件清单与职责

#### 3.1.1 核心启动模块

| 文件                                            | 类型            | 职责                 | 持有秘密               |
| --------------------------------------------- | ------------- | ------------------ | ------------------ |
| `AURORA.Launcher-双击启动.exe`                    | C# 编译 PE      | 启动入口，持有私钥、密码、反调试逻辑、看门狗服务端 | RSA 私钥、密码碎片、调试器黑名单、Watchdog HMAC 密钥 |
| `Scripts/AURORA-AnalyzerLauncherGUI.ps1`      | PowerShell 脚本 | 主 GUI 界面，运行时监控调度，AuroraGuard 承载 | RSA 公钥、完整性检查逻辑、AuroraGuard IL 代码 |
| `Scripts/AURORA-GUI-Functions.ps1`            | PowerShell 脚本 | GUI 辅助函数集          | 无                  |
| `Scripts/Core/AURORA-AnimationCoreEngine.ps1` | PowerShell 脚本 | 星空动画引擎源码           | 无                  |
| `Scripts/Core/AURORA-AnimationCoreEngine.dll` | .NET DLL      | 动画引擎编译库            | 无                  |

#### 3.1.2 PRO 模式模块

| 文件                                  | 类型            | 职责               |
| ----------------------------------- | ------------- | ---------------- |
| `Scripts/AURORA-AnalyzerPRO.ps1`    | PowerShell 脚本 | 统一 PRO 入口，语言路由分发 |
| `Scripts/AURORA-AnalyzerCHSPRO.ps1` | PowerShell 脚本 | 中文专业版日志导出逻辑      |
| `Scripts/AURORA-AnalyzerENGPRO.ps1` | PowerShell 脚本 | 英文专业版日志导出逻辑      |

#### 3.1.3 智能诊断模块

| 文件                               | 类型            | 职责                   |
| -------------------------------- | ------------- | -------------------- |
| `Scripts/AURORA-SmartEngine.ps1` | PowerShell 脚本 | 诊断引擎 v1.1.32，规则匹配与执行 |
| `Data/AURORA-TechData.json`      | JSON 数据       | 技术知识库，100+ 诊断规则定义    |

#### 3.1.4 进度管理模块

| 文件                                                   | 类型            | 职责           |
| ---------------------------------------------------- | ------------- | ------------ |
| `Scripts/AURORA-ProgressManager.ps1`                 | PowerShell 脚本 | 进度持久化核心，断点续传 |
| `Scripts/AURORA-ProgressManager-Integration.ps1`     | PowerShell 脚本 | 双语言进度集成桥梁    |
| `Scripts/AURORA-ProgressManager-Integration-CHS.ps1` | PowerShell 脚本 | 中文进度界面集成     |
| `Scripts/AURORA-ProgressManager-Integration-ENG.ps1` | PowerShell 脚本 | 英文进度界面集成     |

#### 3.1.5 核心引擎模块

| 文件                              | 类型                   | 职责                        |
| ------------------------------- | -------------------- | ------------------------- |
| `Scripts/AURORA-CoreEngine.ps1` | PowerShell 脚本        | 共享核心引擎（权限、日志处理、文件操作、会话管理） |
| `Scripts/AURORA-Language.psd1`  | PowerShell Data File | 集中式双语资源（144 条翻译）          |

#### 3.1.6 Undo / 修复系统模块 (Phase 4.2)

| 文件                                  | 类型            | 职责                                 |
| ----------------------------------- | ------------- | ---------------------------------- |
| `Scripts/AURORA-RestoreManager.ps1` | PowerShell 脚本 | Windows System Restore API 集成      |
| `Scripts/AURORA-RepairLogger.ps1`   | PowerShell 脚本 | 修复命令日志记录器（审计追踪）                    |
| `Scripts/AURORA-UndoManager.ps1`    | PowerShell 脚本 | 快速备份与还原（注册表/文件/服务）                 |
| `Scripts/AURORA-RepairTools.ps1`    | PowerShell 脚本 | 修复工具集（Update、Defender、Telemetry 等） |
| `Scripts/AURORA-UndoViewer.ps1`     | PowerShell 脚本 | 修复历史查看与撤销工具                        |

#### 3.1.7 构建与安全文件

| 文件                 | 类型            | 职责                           |
| ------------------ | ------------- | ---------------------------- |
| `build.ps1`        | PowerShell 脚本 | 自动化构建系统（含 AuroraGuard 哈希注入） |
| `AURORA-build.bat` | Batch 文件      | 构建快捷入口                       |
| `version.txt`      | 文本文件          | 版本号存储                        |
| `GAURORA.CHK.ENC`  | 加密二进制         | AES 加密的 19 个核心文件 SHA256 哈希清单 |
| `desktop.ini`      | 系统文件          | 文件夹图标美化                      |

***

### 3.2 模块依赖关系图

```
AURORA.Launcher-双击启动.exe (C# 启动器)
    │
    ├──[RSA 握手 + Named Pipe 看门狗]──► AURORA-AnalyzerLauncherGUI.ps1 (主 GUI)
    │    │                                   │
    │    │                                   ├──[AuroraGuard IL] 16模块完整性验证
    │    │                                   │
    │    │                                   ├──► AURORA-GUI-Functions.ps1 (GUI 辅助)
    │    │                                   ├──► AURORA-AnimationCoreEngine.dll (动画)
    │    │                                   │       └──► AURORA-AnimationCoreEngine.ps1 (源码)
    │    │                                   │
    │    │                                   ├──► AURORA-AnalyzerPRO.ps1 (PRO 入口)
    │    │                                   │       ├──► AURORA-AnalyzerCHSPRO.ps1
    │    │                                   │       └──► AURORA-AnalyzerENGPRO.ps1
    │    │                                   │
    │    │                                   ├──► AURORA-SmartEngine.ps1 (诊断引擎)
    │    │                                   │       └──► AURORA-TechData.json (知识库)
    │    │                                   │
    │    │                                   ├──► AURORA-ProgressManager.ps1 (进度管理)
    │    │                                   │       ├──► AURORA-ProgressManager-Integration.ps1
    │    │                                   │       │       ├──► -Integration-CHS.ps1
    │    │                                   │       │       └──► -Integration-ENG.ps1
    │    │                                   │
    │    │                                   ├──► AURORA-RestoreManager.ps1 (系统还原)
    │    │                                   ├──► AURORA-RepairLogger.ps1 (修复日志)
    │    │                                   ├──► AURORA-UndoManager.ps1 (撤销管理)
    │    │                                   ├──► AURORA-RepairTools.ps1 (修复工具)
    │    │                                   ├──► AURORA-UndoViewer.ps1 (历史查看)
    │    │                                   │
    │    │                                   ├──► AURORA-CoreEngine.ps1 (核心引擎)
    │    │                                   └──► AURORA-Language.psd1 (双语资源)
    │    │
    │    └──[完整性检查]──► GAURORA.CHK.ENC (加密哈希清单)
    │
    └──[Watchdog 协议]──► Named Pipe: AURORA_WD_{8位随机ID}
            双向 HMAC-SHA256 挑战-响应心跳
```

***

## 4. GUI 架构深度解析

### 4.1 Windows Forms 启动器

`AURORA.Launcher-双击启动.exe` 是整个工具的入口点，由 C# 编写，使用 .NET Framework 的 Windows Forms 框架编译。

**启动流程 (v1.1.24.1 增强版):**

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
    ├─ 3.5 🆕 生成提权安全令牌 (ElevationToken)
    │     └─ AES-256-CBC 加密的哈希列表 + Nonce + Timestamp，120s 过期
    │
    ├─ 4. 🆕 启动 Named Pipe 看门狗服务端
    │     ├─ 生成唯一管道名: AURORA_WD_{8位随机ID}
    │     ├─ 生成 SessionID
    │     ├─ 派生 HMAC 密钥: PBKDF2-SHA256(Password, WdSalt, 10000iter)
    │     └─ 设置环境变量传递管道名和SessionID
    │
    ├─ 5. 启动 PowerShell 进程
    │     ├─ 传入 Token 作为命令行参数
    │     ├─ 传入 ElevationTokenPath
    │     ├─ 设置 GUI_Mode=1 环境变量
    │     ├─ 传入看门狗管道名和 SessionID
    │     └─ 传入 syncHash 引用
    │
    ├─ 6. 🆕 Named Pipe 握手
    │     ├─ 等待 PS1 连接 (15s 超时)
    │     ├─ 发送: [0x10] [32B HMAC Key] [16B SessionID]
    │     ├─ 接收: [0x11] ACK
    │     └─ 握手失败 → Kill PS1 进程
    │
    ├─ 7. 等待 RSA 握手确认
    │
    └─ 8. 🆕 启动看门狗双定时器
          ├─ 固定 5s 间隔挑战
          └─ 随机 2-7s 间隔挑战
```

**C# 源码保护措施:**

- 密码通过 XOR + Shuffle 双重组混淆后嵌入源码
- RSA 私钥以碎片化字节数组形式存储
- Watchdog HMAC 盐值嵌入源码
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
    │     ├── 双重定时器 + FileSystemWatcher 完整性监控
    │     ├── AuroraGuard.VerifyOrDie() C# 嵌入式验证
    │     └── 🆕 Named Pipe 看门狗客户端心跳响应
    │
    ├── Runspace #4: Watchdog-Client 🆕
    │     └── NamedPipeClientStream 连接看门狗服务端
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

**核心数据结构 (v1.1.24.1 增强):**

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
    
    # 🆕 看门狗状态
    WdPipeName      = ""             # Named Pipe 名称
    WdSessionId     = ""             # 看门狗会话 ID
    WdHmacKey       = $null          # HMAC-SHA256 密钥 (会话结束后清除)
    WdConnected     = $false         # 看门狗连接状态
})
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
protected override void OnPaint(PaintEventArgs e) {
    backBuffer.Clear(Color.Black);
    foreach (var band in auroraBands) { DrawAuroraBand(backBuffer, band); }
    foreach (var star in stars) { star.Update(deltaTime); DrawStar(backBuffer, star); }
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

| 等级              | 评分范围  | 动画粒子数 | 动画帧率   | 并发线程 |
| --------------- | ----- | ----- | ------ | ---- |
| **Extreme**     | ≥ 90  | 300   | 60 FPS | 4    |
| **Performance** | 70-89 | 200   | 45 FPS | 3    |
| **Balanced**    | 40-69 | 100   | 30 FPS | 2    |
| **Eco**         | < 40  | 50    | 20 FPS | 1    |

***

## 5. PRO 模式技术实现

### 5.1 日志类型与导出模式

PRO 模式支持 8 种 Windows 事件日志类型的导出：

| 日志名称              | `Get-WinEvent -LogName` 参数 | 典型内容          |
| ----------------- | -------------------------- | ------------- |
| System            | `System`                   | 系统服务、驱动、内核事件  |
| Application       | `Application`              | 应用程序错误、崩溃     |
| Security          | `Security`                 | 登录审计、权限变更     |
| Setup             | `Setup`                    | Windows 安装与更新 |
| DNS Server        | `DNS Server`               | DNS 查询与解析     |
| DHCP Server       | `DHCP Server`              | DHCP 租约信息     |
| Directory Service | `Directory Service`        | AD 域控事件       |
| IIS Admin Service | `IIS-Admin`                | IIS Web 服务器管理 |

**导出模式:**

| 模式          | 参数                                    | 描述            |
| ----------- | ------------------------------------- | ------------- |
| 单日导出        | `-Date "2026-05-27"`                  | 导出指定日期的所有日志   |
| 日期范围导出      | `-From "2026-05-01" -To "2026-05-27"` | 导出日期范围内的日志    |
| ForceRescan | `-ForceRescan`                        | 忽略缓存，强制重新扫描导出 |

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

if ($EventID) {
    $filterParams.ID = $EventID -split ',' | ForEach-Object { [int]$_.Trim() }
}
if ($ProviderName) {
    $filterParams.ProviderName = $ProviderName
}
if ($Level) {
    $filterParams.Level = $Level
}

$events = Get-WinEvent -FilterHashtable $filterParams -MaxEvents $maxEvents
```

**Level 映射表:**

| 用户选项        | Level 值 | Windows 定义 |
| ----------- | ------- | ---------- |
| Critical    | 1       | 关键错误       |
| Error       | 2       | 错误         |
| Warning     | 3       | 警告         |
| Information | 4       | 信息         |
| Verbose     | 5       | 详细         |

### 5.3 多格式输出管线

```
Get-WinEvent 原始数据
    │
    ├──[格式转换器]──────────────────────────────────────┐
    │                                                    │
    ├─► CSV 输出     →  系统_日志_20260527.csv          │
    ├─► JSON 输出    →  系统_日志_20260527.json         │
    ├─► XML 输出     →  系统_日志_20260527.xml          │
    ├─► 摘要报告     →  系统_日志_20260527_摘要.txt      │
    └─► 趋势分析     →  系统_日志_..._趋势分析.txt       │
                   →  系统_日志_..._趋势数据.csv        │
```

**JSON 输出结构:**

```json
{
  "ExportInfo": {
    "LogType": "System",
    "ExportDate": "2026-05-27",
    "TotalEvents": 15420,
    "FilterApplied": false,
    "ToolVersion": "1.1.24.1"
  },
  "Events": [
    {
      "TimeCreated": "2026-05-27T08:30:15.0000000Z",
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

### 5.4 智能权限管理 — 提权安全令牌

> 🆕 **v1.1.24.1 新增:** 增加了独立的提权安全令牌机制，解决 UAC 提权后信任链断裂的 P0 安全问题。

**问题背景:**
当用户执行需要管理员权限的操作时，PowerShell 通过 `Start-Process -Verb RunAs` 提权重启。此时旧进程的 RSA 令牌文件会被清理，导致提权后的进程无法验证 EXE 身份。

**解决方案:**

```
EXE 启动时生成 ElevationToken
    │
    ├─ Nonce = GUID.NewGuid()  (128-bit)
    ├─ Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
    ├─ AES-256-CBC 加密哈希列表 (独立密钥，从 Password + Nonce 派生)
    ├─ 写入 ElevationToken 文件
    └─ 传入 PS1: -ElevationTokenPath <path>
    
提权的 PS1 进程
    │
    ├─ 读取 ElevationToken 文件
    ├─ 验证时间戳: |now - timestamp| < 120s
    ├─ 从 Password + Nonce 派生 AES 密钥
    ├─ 解密哈希列表
    ├─ 比对文件哈希
    └─ 验证通过后立即删除令牌文件
```

**安全性:**
- 令牌仅包含加密的哈希列表，不含密码或私钥
- 120 秒独立过期窗口（比标准 60 秒更长，补偿提权延迟）
- 解密失败 → 回退到密码验证路径
- 令牌文件在验证通过后立即删除

```powershell
$requiresAdmin = @('Security', 'Setup', 'Directory Service') -contains $LogType

if ($requiresAdmin -and -not ([Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator))) {
    
    # 重新以管理员身份启动，携带提权令牌路径
    $newProcess = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile -File `"$PSCommandPath`" $AllArgs -ElevationTokenPath `"$ElevationTokenPath`"" `
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
  "SessionId": "SESSION_20260527_105443_1875",
  "CreatedAt": "2026-05-27T10:54:43+08:00",
  "LastUpdated": "2026-05-27T11:05:20+08:00",
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
    {"ChunkId": 45, "LastEventId": 654321, "Timestamp": "2026-05-27T11:05:20+08:00"}
  ],
  "OutputFiles": [
    "System_Log_20260101___20260301.csv",
    "System_Log_20260101___20260301.json"
  ]
}
```

**缓存归档:**

- **active/**: 进行中的会话
- **archive/**: 已完成的会话（命名格式: `SESSION_{id}_{starttime}_{endtime}.json`）

***

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

```
1. 分析系统启动历史 (EventID 6005/6006)
2. 分析崩溃历史 (EventID 41/1001)
3. 计算关键窗口:
   - 崩溃前窗口: [CrashTime - 2h, CrashTime]
   - 启动后窗口: [BootTime, BootTime + 4h]
4. 合并重叠窗口
5. 仅在窗口内执行深度规则匹配
```

### 6.3 Minidump 蓝屏解析

诊断引擎集成了 Minidump 文件自动解析能力，通过 `System.IO.BinaryReader` 解析 DMP 文件头部的 BugCheck 信息。

### 6.4 安全沙箱执行器

`Invoke-AuroraSafeAction` 是诊断引擎中的安全执行包装器，确保修复操作可追踪、可回滚。

```
Invoke-AuroraSafeAction -Action $repairAction
    │
    ├─ 1. 前置检查 → 2. 风险评估 → 3. 创建回滚点 → 4. 执行操作 → 5. 验证结果
```

### 6.5 五大诊断分类详解

#### A 类 — 系统稳定性

| 规则 ID | 检测项               | 触发条件                       | 严重级别     |
| ----- | ----------------- | -------------------------- | -------- |
| A-001 | 意外关机              | EventID 41, 6008 ≥ 3次/7天   | Critical |
| A-002 | 系统服务崩溃            | EventID 7031, 7034 频繁出现    | Error    |
| A-003 | 内核电源状态异常          | EventID 137, 179           | Warning  |
| A-004 | Windows Update 失败 | EventID 20, 24, 31         | Warning  |
| A-005 | 磁盘文件系统错误          | EventID 55, 137            | Error    |
| A-006 | 系统时间跳变            | EventID 1 (Kernel-General) | Warning  |

#### B 类 — 应用程序错误

| 规则 ID | 检测项             | 触发条件                     | 严重级别    |
| ----- | --------------- | ------------------------ | ------- |
| B-001 | .NET Runtime 崩溃 | EventID 1000, 1026       | Error   |
| B-002 | 应用程序挂起          | EventID 1002             | Warning |
| B-003 | WMI 错误          | EventID 10, 20           | Warning |
| B-004 | COM 组件错误        | EventID 10010            | Warning |
| B-005 | 服务控制管理器错误       | EventID 7000, 7009, 7011 | Error   |

#### C 类 — 驱动程序问题

| 规则 ID | 检测项         | 触发条件                    | 严重级别     |
| ----- | ----------- | ----------------------- | -------- |
| C-001 | 驱动加载失败      | EventID 219, 20001      | Warning  |
| C-002 | 驱动超时/重置     | EventID 4101, 4109      | Error    |
| C-003 | NDIS 网络驱动错误 | EventID 10400           | Warning  |
| C-004 | 存储驱动错误      | EventID 11, 15, 51, 153 | Critical |

#### D 类 — 硬件故障预警

| 规则 ID | 检测项         | 触发条件              | 严重级别     |
| ----- | ----------- | ----------------- | -------- |
| D-001 | 磁盘 SMART 预警 | EventID 7, 52     | Critical |
| D-002 | 磁盘坏块        | EventID 7, 51     | Critical |
| D-003 | 内存 ECC 纠错   | EventID 46, 47    | Error    |
| D-004 | CPU 过热降频    | EventID 37        | Warning  |
| D-005 | 网卡重置        | EventID 27, 10400 | Warning  |

#### E 类 — 安全事件审计

| 规则 ID | 检测项      | 触发条件                        | 严重级别     |
| ----- | -------- | --------------------------- | -------- |
| E-001 | 暴力登录尝试   | EventID 4625 ≥ 5次/小时        | Critical |
| E-002 | 权限提升事件   | EventID 4672, 4673          | Warning  |
| E-003 | 审计日志清除   | EventID 1102                | Critical |
| E-004 | 防火墙规则变更  | EventID 2003, 2004          | Warning  |
| E-005 | 账户创建/删除  | EventID 4720, 4726          | Warning  |
| E-006 | RDP 远程连接 | EventID 4624 (LogonType=10) | Info     |

***

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
    Enable-ComputerRestore -Drive "C:\"
    Checkpoint-Computer -Description $Description -RestorePointType $RestorePointType
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

### 7.2 快速备份快照机制

`AURORA-UndoManager.ps1` 提供比系统还原更轻量级的快照备份。

**支持的备份目标类型:**

| 类型       | 备份方式                      | 示例                                              |
| -------- | ------------------------- | ----------------------------------------------- |
| **注册表项** | `reg export` → .reg 文件    | HKLM\SYSTEM\CurrentControlSet\Services\wuauserv |
| **注册表值** | `Get-ItemProperty` → JSON | 服务配置值                                           |
| **文件**   | 复制到备份目录                   | C:\Windows\System32\drivers\etc\hosts           |
| **服务状态** | `Get-Service` → JSON      | 服务启动类型、状态                                       |
| **计划任务** | `Get-ScheduledTask` → XML | 任务定义导出                                          |

**备份快照结构:**

```
Scripts\UndoBackups\
    └── UNDO_20260527_105443_1875\
        ├── manifest.json
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

### 7.3 修复命令日志审计

`AURORA-RepairLogger.ps1` 记录每一次修复操作的完整审计追踪，采用 JSONL 格式。

```jsonl
{"Timestamp":"2026-05-27 10:54:43.125","SessionId":"REPAIR_20260527_001","Command":"DisableWindowsUpdate","Result":"Success","UserSID":"S-1-5-21-...","MachineName":"DESKTOP-XXX"}
```

### 7.4 一键撤销实现

撤销操作支持按 SessionId 回滚所有关联的修复操作，采用 LIFO 逆序回滚策略。

### 7.5 修复历史查看器

`AURORA-UndoViewer.ps1` 提供交互式修复历史查看界面，支持按 SessionId / 日期时间 / 修复类型排序，状态标识图标，以及导出审计报告为 CSV 格式。

***

## 8. 安全体系 — 纵深防御五层模型

> 🆕 **v1.1.24.1 重大升级:** 从 v1.1.24.0 的四层模型扩展为**五层模型**，新增 Named Pipe 看门狗守护和 C# 嵌入式完整性守卫。

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

密码在嵌入 C# 源码前经过双重混淆：XOR 混淆 → Fisher-Yates Shuffle。

```csharp
// 第一层: XOR 混淆
byte[] obscured = new byte[password.Length];
for (int i = 0; i < password.Length; i++)
    obscured[i] = (byte)(password[i] ^ xorKey[i % xorKey.Length]);

// 第二层: Fisher-Yates Shuffle
for (int i = 0; i < obscured.Length; i++)
    shuffled[indices[i]] = obscured[i];
```

#### 8.1.3 🆕 Watchdog HMAC 盐值嵌入

```powershell
# 生成单独的看门狗 HMAC 盐值
$wdSalt = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
$wdSaltHex = [BitConverter]::ToString($wdSalt).Replace("-", "")
# → 注入 C#: static readonly byte[] WdHmacSalt = { 0xXX, 0xXX, ... };
```

#### 8.1.4 SHA256 哈希清单生成

```powershell
$coreFiles = @(
    "Scripts\AURORA-AnalyzerLauncherGUI.ps1",
    "Scripts\AURORA-GUI-Functions.ps1",
    "Scripts\AURORA-CoreEngine.ps1",
    # ... 共 19 个文件
    "Data\AURORA-TechData.json"
)

$hashes = @{}
foreach ($file in $coreFiles) {
    $fullPath = Join-Path $OutputDir $file
    $hash = (Get-FileHash -Path $fullPath -Algorithm SHA256).Hash
    $hashes[$file] = $hash
}
```

#### 8.1.5 AES-256-CBC 加密哈希清单

```powershell
$salt = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
$iterations = 100000
$deriveBytes = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($password, $salt, $iterations, 'SHA256')
$key = $deriveBytes.GetBytes(32)
$iv  = $deriveBytes.GetBytes(16)

$aes = [System.Security.Cryptography.Aes]::Create()
$aes.Key = $key; $aes.IV = $iv; $aes.Mode = CBC; $aes.Padding = PKCS7

$encryptor = $aes.CreateEncryptor()
$ciphertext = $encryptor.TransformFinalBlock($plaintext, 0, $plaintext.Length)

# Salt(32B) + IV(16B) + Ciphertext
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
    if (IsDebuggerPresent()) return true;
    bool remoteDebugger = false;
    CheckRemoteDebuggerPresent(Process.GetCurrentProcess().Handle, ref remoteDebugger);
    if (remoteDebugger) return true;
    
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
    ├─ 🆕 密钥有效加载 → 储存以备 AuroraGuard 使用
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
Remove-Item Env:\AURORA_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:\AURORA_TEMP_DIR -ErrorAction SilentlyContinue
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
```

### 8.3 第三层：运行时安全

#### 8.3.1 双重定时器机制 + LastWriteTime 优化 🆕

```powershell
# 定时器 1: 固定 3 秒间隔
$timer1 = [System.Timers.Timer]::new(3000)
$timer1.AutoReset = $true
$timer1.add_Elapsed({ Invoke-IntegrityCheck -Mode 'Scheduled' })

# 定时器 2: 随机 2-7 秒间隔（反预测）
$timer2 = [System.Timers.Timer]::new((Get-RandomInterval))
$timer2.AutoReset = $false
$timer2.add_Elapsed({
    Invoke-IntegrityCheck -Mode 'Random'
    $timer2.Interval = Get-RandomInterval
    $timer2.Start()
})
```

#### 8.3.2 🆕 LastWriteTime 快速筛选

```powershell
# v1.1.24.1 新增: 先检查 LastWriteTime，仅在文件修改时才计算 SHA256
foreach ($file in $coreFileList) {
    $fullPath = Join-Path $BaseDir $file
    $currentLWT = (Get-Item $fullPath).LastWriteTimeUtc
    
    if ($currentLWT -eq $lastKnownWriteTimes[$file]) {
        # 文件未修改，跳过 SHA256计算 → 节省 ~50-200ms/文件
        continue
    }
    
    # 文件被修改过，执行完整验证
    $currentHash = (Get-FileHash $fullPath -Algorithm SHA256).Hash
    if ($currentHash -ne $expectedHashes[$file]) {
        $violations += "文件被篡改: $file"
    }
    
    # 更新已知的时间戳
    $lastKnownWriteTimes[$file] = $currentLWT
}
```

**性能对比:**

| 场景 | v1.1.24.0 | v1.1.24.1 | 优化 |
|------|-----------|-----------|------|
| 稳定运行 (19文件未修改) | ~200ms SHA256 × 19 = ~3800ms | ~0ms (仅时间戳比较) | **99%+** |
| 1个文件修改 | ~200ms × 19 = ~3800ms | ~200ms × 1 = ~200ms | **94%** |
| CPU 持续占用 | 中等 | 接近零 | **显著降低** |

#### 8.3.3 FileSystemWatcher 实时监控

```powershell
$watcher = [System.IO.FileSystemWatcher]::new()
$watcher.Path = $ScriptsDir
$watcher.Filter = "*.ps1"
$watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor
                        [System.IO.NotifyFilters]::LastWrite -bor
                        [System.IO.NotifyFilters]::Size
```

**监控文件类型:** `.ps1` `.json` `.xml` `.ico` `.exe` `.enc`

#### 8.3.4 四项检测逻辑

```powershell
function Invoke-IntegrityCheck {
    param([string]$Mode)
    
    $violations = @()
    
    # 检测 1: 文件计数检查
    # 检测 2: 核心文件存在性
    # 检测 3: SHA256 哈希比对 (带 LastWriteTime 快速筛选)
    # 检测 4: 未授权文件注入检测
    
    if ($violations) {
        Invoke-TamperResponse -Violations $violations
    }
}
```

#### 8.3.5 🆕 C# 内嵌倒计时告警窗口

```csharp
// v1.1.24.1: 替代 PowerShell Timer 实现
public class AuroraExitCountdown : Form
{
    private System.Windows.Forms.Timer _timer;
    private Label _lblCountdown;
    private int _secondsRemaining = 15;
    
    // 深色主题: 暗红背景 + 白色文字
    // 最后 5 秒红色警告
    // TopMost = true
}
```

**为什么改用 C#:**
- PowerShell Timer 存在作用域问题（跨 Runspace 不可访问）
- 倒计时精度受 PowerShell 垃圾回收影响
- C# WinForms `System.Windows.Forms.Timer` 运行在 UI 线程，时序稳定

#### 8.3.6 篡改响应

```powershell
function Invoke-TamperResponse {
    param([string[]]$Violations)
    
    # 1. 记录违规详情
    # 2. 停止所有监控
    # 3. 通知 GUI 线程
    # 4. 🆕 显示 C# 倒计时关闭对话框 (15s)
    # 5. 强制退出
    [System.Environment]::Exit(1)
}
```

### 8.4 第四层：多模块启动检测

启动时需要同时满足多项条件才能初始化（GUI_Mode + syncHash + RSA Token），防止恶意模块注入或伪造启动参数。

#### 🆕 反伪造 -LaunchedByExe 参数保护

```powershell
# 攻击者可通过命令行参数 -LaunchedByExe 伪造启动来源
# 绕过完整的 RSA/AES 安全验证

if ($IsLaunchedByExe -eq $true -and $PassedHashListFromExe -eq $null) {
    # 发现伪造: 参数为真但没有任何有效令牌验证通过
    $IsLaunchedByExe = $false
    Write-Warning "AURORA-SEC: Invalid launch context detected - resetting security state"
    # 清除所有环境变量标记
    # 强制走密码验证路径
}
```

### 8.5 第五层：Named Pipe 看门狗守护 🆕

> **这是 v1.1.24.1 最核心的新增安全功能。** 在 EXE 端新增一个完全独立的 Named Pipe 看门狗服务端，与 PS1 脚本建立双向 HMAC-SHA256 挑战-响应心跳通道。即使所有 PS1 层面的验证被绕过，EXE 仍能独立检测异常并终止进程。

#### 8.5.1 Named Pipe 通信架构

```
┌─────────────────────────────┐     Named Pipe      ┌──────────────────────────────┐
│  AURORA.Launcher.exe (占有私钥) │ ◄═══════════════► │  PS1脚本 (占有公钥/完整性检查)           │
│                               │   AURORA_WD_{8位ID}  │                                │
│  [看门狗服务端]                   │                    │  [看门狗客户端]                    │
│  NamedPipeServerStream         │  ▸ [0x10] 握手      │  NamedPipeClientStream          │
│  PBKDF2 HMAC密钥派生            │  ◂ [0x11] ACK      │  接收HMAC密钥                    │
│  双定时器 挑战发送                │  ▸ [0x03] 挑战      │  计算HMAC响应                    │
│  Kill PS1 进程 (独立权限)        │  ◂ [0x04] 响应      │  携带自SHA256                    │
└─────────────────────────────┘                      └──────────────────────────────┘
```

#### 8.5.2 协议帧格式

```
握手:
  EXE → PS1: [0x10] [32字节 HMAC密钥] [16字节 UTF8 SessionID]   = 49字节
  PS1 → EXE: [0x11]                                              = 1字节 ACK

挑战-响应:
  EXE → PS1: [0x03] [16字节 CSPRNG Nonce] [8字节 UTC Unix时间戳] = 25字节
  PS1 → EXE: [0x04] [32字节 HMAC(Nonce,Key)] [8字节 系统运行秒数] [32字节 PS1脚本自SHA256] = 73字节
```

#### 8.5.3 HMAC 密钥派生 (C# EXE端)

```csharp
// PBKDF2-SHA256(MasterPassword, WdHmacSalt, 10,000 iterations) → 32-byte HMAC key
byte[] wdHmacKey;
using (var pbkdf2 = new Rfc2898DeriveBytes(masterPassword, WdHmacSalt, 10000, HashAlgorithmName.SHA256))
{
    wdHmacKey = pbkdf2.GetBytes(32);
}
```

#### 8.5.4 挑战-响应机制

```csharp
// 挑战生成 (固定间隔 + 随机间隔)
byte[] challengeNonce = new byte[16];  // CSPRNG 生成
byte[] ts            = new byte[8];   // UTC Unix时间戳

// 响应验证
byte[] expectedHmac;
using (var hmac = new HMACSHA256(wdHmacKey))
{
    expectedHmac = hmac.ComputeHash(receivedNonce);
}

// 比较 EXE 期望的 HMAC vs PS1 返回的 HMAC
if (!ConstantTimeCompare(expectedHmac, receivedHmac))
{
    wdFailCount++;  // 连续3次失败 → Kill
}
```

#### 8.5.5 双定时器设计

```csharp
// 定时器 1: 固定 5 秒间隔
var wdFixedTimer = new System.Timers.Timer(5000);

// 定时器 2: 随机 2-7 秒间隔 (反预测)
int randomMs = 2000 + rng.Next(0, 5000);
var wdRandomTimer = new System.Timers.Timer(randomMs);
```

#### 8.5.6 PS1 端自哈希计算

```powershell
# PS1收到挑战命令 [0x03] 后
# 计算自身脚本的 SHA256 作为响应的一部分
$selfPath = $PSCommandPath
$selfSha256 = (Get-FileHash -Path $selfPath -Algorithm SHA256).Hash
$selfSha256Bytes = [byte[]]::new(32)
for ($i = 0; $i -lt 32; $i++) {
    $selfSha256Bytes[$i] = [Convert]::ToByte($selfSha256.Substring($i * 2, 2), 16)
}

# 计算 HMAC(Nonce, Key)
$hmac = [System.Security.Cryptography.HMACSHA256]::new($wdHmacKey)
$responseHmac = $hmac.ComputeHash($challengeNonce)

# 发送响应: [0x04] [32B HMAC] [8B Uptime] [32B SelfSHA256]
```

#### 8.5.7 失败处理

```csharp
const int WdMaxFailCount = 3;           // 连续3次失败
const int WdConnectTimeoutMs = 15000;    // 连接超时 15s
const int WdResponseTimeoutMs = 3000;    // 响应超时 3s

if (wdFailCount >= WdMaxFailCount)
{
    // 1. 关闭 Named Pipe
    // 2. Kill PS1 进程
    ps1Proc.Kill();
    // 3. 清理资源
    // 4. 优雅退出
}
```

#### 8.5.8 攻击模型覆盖

| 攻击手段 | 看门狗如何防御 |
|---------|-------------|
| 注释所有 PS1 验证代码 | EXE 端独立检测，挑战-响应绕过 PS1 |
| 替换 PS1 脚本文件 | 自 SHA256 不匹配 → 3 次失败 → Kill |
| 注入内存 Hook | Named Pipe 心跳丢失 → 超时 → Kill |
| DLL 注入 | EXE 进程受 C# 编译保护，Watchdog 不受影响 |

### 8.6 C# 嵌入式完整性守卫 (AuroraGuard) 🆕

> **概述:** 在 LauncherGUI.ps1 中嵌入运行时编译的 C# IL 代码块 `AuroraGuard`，对 16 个核心子模块进行独立的 SHA256 完整性验证。编译为 IL 指令后难以分析/修改，跨 Runspace 可见。

#### 8.6.1 代码架构

```csharp
// Add-Type 嵌入 LauncherGUI.ps1
Add-Type @"
using System;
using System.IO;
using System.Security.Cryptography;

public class AuroraGuard
{
    private static readonly Dictionary<string, string> _expected = new Dictionary<string, string>
    {
        // 🆕 以下哈希值在构建时由 build.ps1 [2.5/6] 自动注入
        {"Scripts\\AURORA-SmartEngine.ps1", "AG_PLACEHOLDER_AURORA_SMART_ENGINE..."},
        {"Scripts\\AURORA-CoreEngine.ps1", "AG_PLACEHOLDER_AURORA_CORE_ENGINE..."},
        // ... 共 16 个模块
        
        // 安全: 占位符与真实 SHA256 长度相同
    };

    public static bool VerifyOrDie()
    {
        string baseDir = AppDomain.CurrentDomain.BaseDirectory;
        int violations = 0;
        
        foreach (var kv in _expected)
        {
            string filePath = Path.Combine(baseDir, kv.Key);
            if (!File.Exists(filePath)) { violations++; continue; }
            
            using (var sha256 = SHA256.Create())
            using (var stream = File.OpenRead(filePath))
            {
                byte[] hash = sha256.ComputeHash(stream);
                string hashString = BitConverter.ToString(hash).Replace("-", "");
                if (!string.Equals(hashString, kv.Value, StringComparison.OrdinalIgnoreCase))
                {
                    violations++;
                }
            }
        }
        
        return violations == 0;  // true = 所有文件通过验证
    }
}
"@ -ReferencedAssemblies "System.Core"
```

#### 8.6.2 验证覆盖范围

| 序号 | 保护文件 | 模块职责 |
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

#### 8.6.3 技术特性

- **跨 Runspace 可见**: `Add-Type` 编译后定义在整个 PowerShell 会话中
- **调用友好**: `[AuroraGuard]::VerifyOrDie()` 可从任何子模块调用
- **降级运行**: 加载失败不影响正常功能
- **构建时注入**: 哈希值在 `build.ps1 [2.5/6]` 步骤自动替换占位符
- **IL 级保护**: 编译后的代码难以通过文本搜索发现和修改

### 8.7 提权安全令牌 (AURORA-SEC-2026-001) 🆕

> **P0 级安全修复。** 详见 [5.4 节](#54-智能权限管理--提权安全令牌)。

**核心设计:**
- AES-256-CBC 加密的哈希列表
- 120 秒独立过期窗口
- 通过命令行参数传递（绕过 UAC 环境变量清空）
- 验证通过后立即删除

### 8.8 反伪造启动参数保护 🆕

```
检测逻辑:
  if (IsLaunchedByExe == true AND PassedHashListFromExe == null)
      → 重置 IsLaunchedByExe = false
      → 清除所有环境变量标记
      → 强制走密码验证路径
```

***

## 9. 构建系统

### 9.1 build.ps1 全流程

```
[1/6] 初始化构建环境
[2/6] 写入 C# 源码到 LauncherBuilder
    [2.5/6] 🆕 注入 AuroraGuard SHA256 哈希
[3/6] 编译 C# 源码 → AURORA.Launcher-双击启动.exe
[4/6] 构建 Scripts\ 目录
[5/6] 🆕 智能安全代码注入
[6/6] 打包 → ZIP 发布
```

### 9.2 C# 混淆编译

`build.ps1` 使用 `csc.exe` (C# Compiler) 编译启动器。编译目标强制指定为 x86 平台。类名和方法名在编译前进行离线重命名混淆。

### 9.3 AuroraGuard 哈希注入 (2.5/6) 🆕

> **v1.1.24.1 新增:** build.ps1 新增 `[2.5/6]` 步骤，自动注入 AuroraGuard 哈希值。

```powershell
# [2.5/6] 注入 AuroraGuard SHA256 哈希
Write-Host "[2.5/6] 注入 AuroraGuard SHA256 哈希..." -ForegroundColor Cyan

$auroraGuardPlaceholders = @{
    "AG_PLACEHOLDER_AURORA_SMART_ENGINE"             = $hashes["Scripts\AURORA-SmartEngine.ps1"]
    "AG_PLACEHOLDER_AURORA_CORE_ENGINE"              = $hashes["Scripts\AURORA-CoreEngine.ps1"]
    "AG_PLACEHOLDER_AURORA_CHSPRO"                   = $hashes["Scripts\AURORA-AnalyzerCHSPRO.ps1"]
    "AG_PLACEHOLDER_AURORA_PROGRESS_MANAGER"         = $hashes["Scripts\AURORA-ProgressManager.ps1"]
    "AG_PLACEHOLDER_AURORA_GUI_FUNCTIONS"            = $hashes["Scripts\AURORA-GUI-Functions.ps1"]
    "AG_PLACEHOLDER_AURORA_REPAIR_TOOLS"             = $hashes["Scripts\AURORA-RepairTools.ps1"]
    "AG_PLACEHOLDER_AURORA_UNDO_MANAGER"             = $hashes["Scripts\AURORA-UndoManager.ps1"]
    "AG_PLACEHOLDER_AURORA_RESTORE_MANAGER"          = $hashes["Scripts\AURORA-RestoreManager.ps1"]
    "AG_PLACEHOLDER_AURORA_REPAIR_LOGGER"            = $hashes["Scripts\AURORA-RepairLogger.ps1"]
    "AG_PLACEHOLDER_AURORA_UNDO_VIEWER"              = $hashes["Scripts\AURORA-UndoViewer.ps1"]
    "AG_PLACEHOLDER_AURORA_ANALYZER_PRO"             = $hashes["Scripts\AURORA-AnalyzerPRO.ps1"]
    "AG_PLACEHOLDER_AURORA_PROGRESS_INTEGRATION"     = $hashes["Scripts\AURORA-ProgressManager-Integration.ps1"]
    "AG_PLACEHOLDER_AURORA_PROGRESS_INTEGRATION_CHS" = $hashes["Scripts\AURORA-ProgressManager-Integration-CHS.ps1"]
    "AG_PLACEHOLDER_AURORA_PROGRESS_INTEGRATION_ENG" = $hashes["Scripts\AURORA-ProgressManager-Integration-ENG.ps1"]
    "AG_PLACEHOLDER_AURORA_ANIMATION_CORE_ENGINE"    = $hashes["Scripts\Core\AURORA-AnimationCoreEngine.ps1"]
    "AG_PLACEHOLDER_AURORA_TECHDATA"                 = $hashes["Data\AURORA-TechData.json"]
}

foreach ($kv in $auroraGuardPlaceholders.GetEnumerator()) {
    $launcherGuiContent = $launcherGuiContent -replace $kv.Key, $kv.Value
}
```

### 9.4 打包与分发

构建完成后，`build.ps1` 自动打包为 `AURORA-AnalyzerV1.1.24.1Release.zip`。

---

## 10. 国际化架构

`AURORA-Language.psd1` 是集中式双语资源文件，包含 144 条翻译条目。

**键命名规范:** `Section_Category_Key`

```powershell
@{
    # GUI 菜单
    Nav_LogExport_zh    = "日志导出"
    Nav_LogExport_en    = "Log Export"
    Nav_SmartDiagnose_zh = "智能诊断"
    Nav_SmartDiagnose_en = "Smart Diagnose"
    
    # 🆕 看门狗消息
    Watchdog_Connected_zh    = "安全守护已建立"
    Watchdog_Connected_en    = "Security watchdog established"
    Watchdog_Failed_zh       = "安全守护连接失败"
    Watchdog_Failed_en       = "Security watchdog connection failed"
}
```

---

## 11. 性能与安全权衡设计 — LastWriteTime 优化 🆕

> **v1.1.24.1 新增:** 完整性检查循环中引入 LastWriteTime 快速筛选，解决连续 SHA256 计算导致的 CPU 占用问题。

```powershell
# 维护已知的最后写入时间
$lastKnownWriteTimes = @{}

foreach ($file in $coreFileList) {
    $fullPath = Join-Path $BaseDir $file
    $currentLWT = (Get-Item $fullPath).LastWriteTimeUtc
    
    if ($lastKnownWriteTimes.ContainsKey($file) -and 
        $currentLWT -eq $lastKnownWriteTimes[$file]) {
        continue  # 跳过 SHA256，节省 ~50-200ms/文件
    }
    
    $lastKnownWriteTimes[$file] = $currentLWT
    $currentHash = (Get-FileHash $fullPath -Algorithm SHA256).Hash
    
    if ($currentHash -ne $expectedHashes[$file]) {
        $violations += "文件被篡改: $file"
    }
}
```

**安全权衡分析:**
- LastWriteTime 可被伪造（`SetFileTime` API），但伪造后 SHA256 验证仍会触发
- 时间戳筛选是**性能优化**，不是**安全替代**
- 即便攻击者伪造 LastWriteTime，SHA256 也会在首次比对时检出
- FileSystemWatcher 实时监控覆盖所有文件写入事件

---

## 12. 错误处理与日志

- 所有脚本使用 Try-Catch-Finally 块
- 错误信息双语输出
- 安全异常单独记录

---

> **文档版本:** V1.1.24.1
> **日期:** 2026-05-27
> **作者:** AURORA VelociRaptor-GR Dev PRJ.
> **许可:** 仅供个人学习与研究使用