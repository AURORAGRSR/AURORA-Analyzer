# AURORA Analyzer V1.3.26.5 — 完全架构解耦版

> **Windows Event Log Export & Smart Diagnostic Tool**
>
> 版本：V1.3.26.5Release · 构建时间：2026.06.08 · 作者：AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **警告**：本工具仅用于个人学习使用。请遵守当地法律法规。

---

## 目录

1. [项目概述](#1-项目概述)
2. [架构解耦详解](#2-架构解耦详解)
3. [安全架构全景](#3-安全架构全景)
4. [核心子系统深度解析](#4-核心子系统深度解析)
5. [GUI 架构](#5-gui-架构)
6. [智能诊断引擎](#6-智能诊断引擎)
7. [会话与进度管理](#7-会话与进度管理)
8. [构建系统](#8-构建系统)
9. [性能分级系统](#9-性能分级系统)
10. [跨线程通信](#10-跨线程通信)
11. [技术栈总结](#11-技术栈总结)
12. [攻击面分析](#12-攻击面分析)
13. [贡献指南](#13-贡献指南)

---

## 1. 项目概述

### 1.1 简介

AURORA Analyzer 是一款面向 Windows 平台的系统事件日志导出与智能诊断分析工具。它能够导出 Windows Event Log 中的 Application、System、Security、Setup 等十余种日志类型，并通过内置的知识图谱引擎进行智能碰撞分析，自动定位系统异常并提供修复建议。在 V1.3.26.5 版本中，项目完成了从单体脚本到完全模块化架构的根本性重构。

### 1.2 架构全景图

```
                         ┌─────────────────────────────────┐
                         │       AURORA-Analyzer.exe       │
                         │     (C# .NET Framework 4.x)     │
                         │     看门狗 / 启动验证 / IPC      │
                         └─────────────┬───────────────────┘
                                       │ 启动 + 令牌传递
                                       ▼
                         ┌─────────────────────────────────┐
                         │ AURORA-AnalyzerLauncherGUI.ps1  │
                         │     主启动器 / 编排层             │
                         └─────────────┬───────────────────┘
                                       │ dot-source (. 操作符)
              ┌────────────────────────┼────────────────────────────┐
              │                        │                            │
              ▼                        ▼                            ▼
    ┌─────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
    │     Core/       │    │     Security/       │    │     UI/Controls/    │
    │ 核心引擎层       │    │ 安全模块             │    │  UI 控件库           │
    ├─────────────────┤    ├─────────────────────┤    ├─────────────────────┤
    │ CoreEngine      │    │ RSA 令牌验证         │    │ UIControls          │
    │ AnimationEngine │    │ AES 会话加密         │    │ (TechButton/        │
    │                 │    │ AuroraGuard C# 守卫  │    │  ProgressBar/       │
    └────────┬────────┘    │ 看门狗客户端          │    │  StarfieldPanel)    │
             │             │ 退出处理程序          │    │ Animations          │
             │             └──────────┬───────────┘    └──────────┬──────────┘
             │                        │                           │
             ▼                        ▼                           ▼
    ┌─────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
    │    Engines/     │    │      Session/       │    │     UI/Views/       │
    │  引擎层          │    │   会话管理           │    │   视图层             │
    ├─────────────────┤    ├─────────────────────┤    ├─────────────────────┤
    │ SmartEngine     │    │ ProgressManager     │    │ View-MainForm       │
    │ (4 阶段诊断管线) │    │ ProgressManager-    │    │ View-SplashScreen   │
    │                 │    │   Integration       │    │ View-ProMode        │
    └────────┬────────┘    │ UndoManager         │    │ View-SessionRestore │
             │             │ UndoViewer          │    │ View-Elevation      │
             │             └──────────┬──────────┘    │ View-PermissionInfo │
             │                        │               │ View-AdminElevation │
             ▼                        │               └──────────┬──────────┘
    ┌─────────────────┐               │                          │
    │      PRO/       │               │               ┌──────────┴──────────┐
    │   PRO 模式       │               │               │     Repair/        │
    ├─────────────────┤               │               │   修复工具           │
    │ PRO-Engine      │               │               ├────────────────────┤
    │ (290KB+         │               │               │ RepairTools         │
    │  统一 CHS/ENG)  │               │               │ RepairLogger        │
    │ PRO Entry       │               │               │ RestoreManager      │
    └────────┬────────┘               │               └─────────────────────┘
             │                        │
             └────────────┬───────────┘
                          ▼
               ┌─────────────────────┐
               │       GUI/          │
               │     GUI 辅助         │
               ├─────────────────────┤
               │ GUI-Functions       │
               │ Language.psd1       │
               │   (双语资源)         │
               └─────────────────────┘

                          ┌─────────────┐
                          │    Data/    │
                          ├─────────────┤
                          │ TechData    │
                          │   .json     │
                          │   .cache    │
                          │   .clixml   │
                          └─────────────┘
```

### 1.3 核心指标

| 指标 | 解耦前 | 解耦后 |
|------|--------|--------|
| 独立模块数 | ~3 个 | 22+ 个 .ps1 文件 |
| 模块层级 | 平面 | 11 层 |
| 最大文件代码行数 | 5000+ | 1100+ |
| 安全代码位置 | 混合在主脚本 | 完全独立 SecurityModule |
| UI 视图定位 | 内联匿名函数 | 独立 View 文件 |
| 语言资源 | 分散硬编码 | 集中 .psd1 资源字典 |
| 模块加载方式 | 单一脚本 | 有序 dot-source + 依赖链 |

---

## 2. 架构解耦详解

V1.3.26.5 版本的核心主题是「完全架构解耦」——将原本整合在一个庞然大物 `LauncherGUI.ps1` 中的所有功能，按照职责边界拆分为独立的模块文件，每个模块专注于单一职责。

### 2.1 解耦总览

```
解耦前（单体）：
  LauncherGUI.ps1 (5000+ 行)
  ├── 安全验证代码（RSA / AES / 密码）
  ├── 看门狗 IPC 客户端
  ├── 完整性检查定时器
  ├── 自定义 UI 控件 (TechButton / ProgressBar / StarfieldPanel)
  ├── Splash 启动画面
  ├── 主窗体 (1100+ 行)
  ├── PRO 模式窗口
  ├── 4 个对话框
  ├── 动画引擎 (C# 内嵌 DLL)
  ├── 智能引擎调用
  ├── 进度管理器
  ├── 语言资源 (内联)
  └── GUI 辅助函数

解耦后（V1.3.26.5）：
  LauncherGUI.ps1 (~1090 行) — 仅负责编排与加载
  ├── Core/AURORA-CoreEngine.ps1
  ├── Core/AURORA-AnimationCoreEngine.ps1
  ├── Security/AURORA-SecurityModule.ps1
  ├── UI/Controls/AURORA-UIControls.ps1
  ├── UI/Controls/AURORA-Animations.ps1
  ├── UI/Views/View-SplashScreen.ps1
  ├── UI/Views/View-MainForm.ps1
  ├── UI/Views/View-ProMode.ps1
  ├── UI/Views/Dialogs/View-SessionRestoreDialog.ps1
  ├── UI/Views/Dialogs/View-ElevationDialog.ps1
  ├── UI/Views/Dialogs/View-PermissionInfo.ps1
  ├── UI/Views/Dialogs/View-AdminElevation.ps1
  ├── Engines/AURORA-SmartEngine.ps1
  ├── PRO/AURORA-AnalyzerPRO-Engine.ps1
  ├── PRO/AURORA-AnalyzerPRO.ps1
  ├── Session/AURORA-ProgressManager.ps1
  ├── Session/AURORA-ProgressManager-Integration.ps1
  ├── Session/AURORA-UndoManager.ps1
  ├── Session/AURORA-UndoViewer.ps1
  ├── Repair/AURORA-RepairTools.ps1
  ├── Repair/AURORA-RepairLogger.ps1
  ├── Repair/AURORA-RestoreManager.ps1
  ├── GUI/AURORA-GUI-Functions.ps1
  └── GUI/AURORA-Language.psd1
```

### 2.2 各模块层详解

#### 2.2.1 `Core/` — 核心引擎层

| 文件 | 职责 | 关键函数 |
|------|------|----------|
| `AURORA-CoreEngine.ps1` | 共享核心引擎 | `Invoke-SafeOperation`, `Write-AuroraLog`, `Write-AuroraStructuredLog`, `Get-SystemInfo`, `Initialize-Engine`, `Convert-SafeDateTime`, `Manage-Session`, `Invoke-ElevationCheck`, `Save-ProgressSafe`, `Get-ProgressInfo` |
| `AURORA-AnimationCoreEngine.ps1` | 动画核心引擎 | C# 内嵌 DLL 编译加载, `AuroraRenderEngine`, `EasingType` 枚举 (20 种缓动函数), `FloatAnimation`, `IAnimatable` 接口 |

**解耦成就**：
- `CoreEngine` 从脚本内部混合代码中抽离，提供 `Invoke-SafeOperation` 统一安全操作执行包装器（带重试/清理/错误恢复），`Write-AuroraLog` 统一日志输出（自动检测 GUI/非 GUI 环境并路由到 syncHash 或 Write-Host）。
- `AnimationCoreEngine` 从主脚本中分离，使用嵌入式 C# DLL 编译模式：优先从磁盘加载已编译 DLL，若加载失败则运行时重新编译（`Add-Type`）。支持 4 种性能层级的渲染参数自动适配。

#### 2.2.2 `Security/` — 安全模块

| 文件 | 职责 | 关键内容 |
|------|------|----------|
| `AURORA-SecurityModule.ps1` | 安全模块 | RSA 公钥 (构建时注入), `Test-RSATokenSignature`, `Decrypt-HashListFromToken`, `Clear-AuroraWatchdogEnv`, `Register-AuroraExitHandler`, AuroraGuard C# 嵌入式运行时守卫 (750 行 C# 代码), `AuroraExitCountdown` 倒计时窗口类 |

**解耦成就**：
- RSA 密钥、SessionSalt、AesSalt 全部集中在 SecurityModule 中，构建时通过 `build.ps1` 自动注入。
- AuroraGuard C# 类（~750 行）从 LauncherGUI 中完全剥离，独立于 SecurityModule 维护。
- 看门狗环境清理函数 `Clear-AuroraWatchdogEnv` 和退出处理程序 `Register-AuroraExitHandler` 独立管理，支持 PowerShell.Exiting 事件和 AppDomain.ProcessExit 事件双重注册。

#### 2.2.3 `UI/Controls/` — UI 控件库

| 文件 | 职责 | 关键控件 |
|------|------|----------|
| `AURORA-UIControls.ps1` | 自定义 UI 控件 | `TechButton` (波纹效果 + 磁吸动画), `AuroraProgressBar` (平滑过渡), `StarfieldPanel` (粒子星空背景) |
| `AURORA-Animations.ps1` | 动画辅助函数 | 控件动画辅助、缓动函数桥接 |

**解耦成就**：
- 三个自定义控件（TechButton、AuroraProgressBar、StarfieldPanel）从主脚本中剥离为独立控件库。
- TechButton 实现鼠标波纹扩散效果 + 磁吸（snap）动画。
- AuroraProgressBar 支持从当前值平滑过渡到目标值。
- StarfieldPanel 基于性能层级动态调整粒子数和帧率。

#### 2.2.4 `UI/Views/` — 视图层

| 文件 | 职责 | 代码规模 |
|------|------|----------|
| `View-MainForm.ps1` | 主窗体 | 1100+ 行 |
| `View-SplashScreen.ps1` | 启动画面（带星空动画） | ~200 行 |
| `View-ProMode.ps1` | PRO 模式窗口 | ~300 行 |
| `Dialogs/View-SessionRestoreDialog.ps1` | 会话恢复对话框 | ~150 行 |
| `Dialogs/View-ElevationDialog.ps1` | 管理员权限提升对话框 | ~100 行 |
| `Dialogs/View-PermissionInfo.ps1` | 权限信息提示对话框 | ~80 行 |
| `Dialogs/View-AdminElevation.ps1` | 管理员提权管理对话框 | ~120 行 |

**解耦成就**：
- 所有 UI 布局、事件处理、表单逻辑从主脚本中分离，每个 View 文件通过 `function` 返回一个 Form 对象供主启动器使用。
- 主窗体 1100+ 行单独文件，包含完整的事件处理逻辑。
- 4 个对话框各自独立，通过 syncHash 与 PRO/SmartEngine 通信。

#### 2.2.5 `Engines/` — 引擎层

| 文件 | 职责 | 代码规模 |
|------|------|----------|
| `AURORA-SmartEngine.ps1` | 智能诊断引擎 | 1720+ 行 |

**解耦成就**：
- SmartEngine 从 PRO 模式中完全独立，作为共享引擎供 PRO 和 GUI 直接调用。
- 支持双语 (CHS/ENG)、4 阶段诊断管线、知识图谱碰撞、沙箱自动修复。
- 启动时自主检测调用方（GUI/PRO），防止直接运行。

#### 2.2.6 `PRO/` — PRO 模式

| 文件 | 职责 | 代码规模 |
|------|------|----------|
| `AURORA-AnalyzerPRO-Engine.ps1` | 统一 CHS/ENG PRO 引擎 | 290KB+ |
| `AURORA-AnalyzerPRO.ps1` | PRO 模式入口点 | ~100 行 |

**解耦成就**：
- PRO 引擎从混合代码中独立，实现 CHS/ENG 统一（合并了此前分离的两个语言版本）。
- PRO 入口点仅负责参数解析和引擎调用，引擎文件承载全部业务逻辑。

#### 2.2.7 `Session/` — 会话管理

| 文件 | 职责 |
|------|------|
| `AURORA-ProgressManager.ps1` | 会话持久化与断点续传 |
| `AURORA-ProgressManager-Integration.ps1` | 进度管理器集成层 |
| `AURORA-UndoManager.ps1` | 快速备份与恢复撤销 |
| `AURORA-UndoViewer.ps1` | 撤销管理器与查看器 |

**解耦成就**：
- SessionCache 目录结构：`active/` (活动会话) → `checkpoints/` (检查点备份) → `archive/` (已归档).
- 7 天自动过期机制。
- 完整双语支持（内建 70+ 条双语字符串）。

#### 2.2.8 `Repair/` — 修复工具

| 文件 | 职责 |
|------|------|
| `AURORA-RepairTools.ps1` | 修复工具集 (DisableWindowsUpdate, EnableDefender, DisableTelemetry, ResetNetwork, CleanSystem, Custom) |
| `AURORA-RepairLogger.ps1` | 修复会话日志记录 |
| `AURORA-RestoreManager.ps1` | 系统还原点管理 |

**解耦成就**：
- 6 种修复操作完全独立，通过 UndoManager 实现可撤销。
- RestoreManager 创建系统还原点作为安全网。

#### 2.2.9 `GUI/` — GUI 辅助

| 文件 | 职责 |
|------|------|
| `AURORA-GUI-Functions.ps1` | GUI 辅助函数 (字体加载、目录完整性检查、进度条、语言检测) |
| `AURORA-Language.psd1` | 集中式双语资源字典 (CHS/ENG) |

**解耦成就**：
- 语言资源从各处硬编码字符串集中到单一 .psd1 文件，分为 CHS 和 ENG 两套完整映射。
- 字体管理 (CascadiaMono.ttf 等宽字体、Emoji 字体检测) 统一为独立函数。

### 2.3 加载顺序与依赖关系

在 `AURORA-AnalyzerLauncherGUI.ps1` 中，所有模块通过 `.` (dot-source) 操作符按以下顺序加载：

```
1.  $scriptDir 和 $rootDir 路径计算
2.  GUI/AURORA-GUI-Functions.ps1        ← 基础 GUI 辅助
3.  Core/AURORA-AnimationCoreEngine.ps1 ← 动画引擎（C# DLL 编译）
4.  Core/AURORA-CoreEngine.ps1          ← 核心引擎
5.  Security/AURORA-SecurityModule.ps1  ← 安全模块（依赖 CoreEngine）
6.  [硬件性能探针]                       ← 内联检测
7.  [EXE 看门狗连接]                     ← 内联 IPC 握手
8.  [密码验证]                           ← 内联（条件触发）
9.  [完整性检查初始化]                    ← 内联
10. UI/Controls/AURORA-UIControls.ps1   ← UI 控件库
11. Session/AURORA-ProgressManager.ps1  ← 会话管理
12. UI/Views/View-SplashScreen.ps1      ← 启动画面
13. UI/Views/Dialogs/*.ps1              ← 4 个对话框
14. UI/Views/View-MainForm.ps1          ← 主窗体
15. UI/Views/View-ProMode.ps1           ← PRO 窗口
16. UI/Controls/AURORA-Animations.ps1   ← 动画辅助
```

**依赖链关键约束**：
- `SecurityModule` 必须在 `CoreEngine` 之后加载（依赖 `Invoke-SafeOperation` 和 `Write-AuroraLog`）。
- `UIControls` 必须在 Views 之前加载（View 文件中引用控件类型）。
- `ProgressManager` 必须在 Splash 之后、MainForm 之前初始化（以便在 PRO 模式启动前创建 SessionCache）。

---

## 3. 安全架构全景

AURORA Analyzer 实现了 **6 层纵深防御模型**，从构建时到运行时形成完整的信任链。

```
┌─────────────────────────────────────────────────────────────┐
│                    AURORA 6-Layer Defense                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Layer 0 ─┤ 构建时 (Build-time)                            │
│            │   RSA 2048 密钥对生成                           │
│            │   SHA256 完整性哈希计算                         │
│            │   主密码混淆存储 (XOR+随机排列)                  │
│            │   SessionSalt 随机生成                          │
│            │   60 秒令牌时间窗口                              │
│                                                             │
│   Layer 1 ─┤ 启动验证 (Startup Verification)                │
│            │   RSA 令牌签名验证 (SHA256 + PKCS#1 v1.5)       │
│            │   AES-256-CBC 哈希列表解密                      │
│            │   环境健全性检查                                  │
│                                                             │
│   Layer 2 ─┤ IPC 安全 (Inter-Process Communication)         │
│            │   Named Pipe 双向认证                            │
│            │   HMAC-SHA256 挑战-响应                          │
│            │   双向心跳 (单次失败 = 终止)                      │
│                                                             │
│   Layer 3 ─┤ 运行时守卫 (Runtime Guardian)                  │
│            │   调试器 API 检测                                │
│            │     └─ IsDebuggerPresent                        │
│            │     └─ CheckRemoteDebuggerPresent               │
│            │     └─ NtQueryInformationProcess (DebugPort)    │
│            │     └─ NtQueryInformationProcess (DebugFlags)   │
│            │     └─ NtQueryInformationProcess (HandleTracing)│
│            │   反 Dump                                       │
│            │     └─ 可疑模块检测 (x64dbg, ollydbg, dnSpy..)  │
│            │   DLL 注入检测                                   │
│            │   WMI 实时进程监控 (零延迟)                       │
│            │   FileSystemWatcher 完整性监控                   │
│                                                             │
│   Layer 4 ─┤ 密码验证 (Password Verification)               │
│            │   PBKDF2-SHA256 (100k 迭代)                     │
│            │   AES-256-CBC 加密检查文件 (GAURORA.CHK.ENC)    │
│            │   密码强度强制校验 (8+ 字符, 大小写+数字+特殊)    │
│                                                             │
│   Layer 5 ─┤ C# EXE 看门狗 (Watchdog)                       │
│            │   Named Pipe 服务端                             │
│            │   HMAC-SHA256 挑战-响应                          │
│            │   进程生命周期管理                                │
│            │   验证失败直接 Kill                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3.1 信任链流程

```
EXE 启动
  ├─ [自检] FullAntiDebugCheck() → 检查调试器 API + 反 Dump
  ├─ [解密] PBKDF2-SHA256 解密 GAURORA.CHK.ENC → 获取哈希列表
  ├─ [验证] SHA256 文件哈希逐一比对 (RequiredFiles × 26)
  ├─ [签名] RSA 私钥签名令牌 (nonce + timestamp + hashB64)
  ├─ [加密] AES-256-CBC 加密哈希列表
  ├─ [启动] PowerShell 子进程 → LauncherGUI.ps1
  └─ [看门狗] NamedPipe 心跳开始

PS1 启动
  ├─ [验证] RSA 公钥验证 EXE 签名的令牌
  ├─ [解密] AES 解密哈希列表
  ├─ [连接] 看门狗 Named Pipe 握手
  ├─ [守卫] AuroraGuard C# 运行时完整性扫描
  ├─ [监控] FileSystemWatcher 实时文件变化监控
  ├─ [轮询] 定时器每 3s + 随机间隔 SHA256 哈希比对
  └─ [心跳] 看门狗 Runspace 响应 EXE 挑战
```

---

## 4. 核心子系统深度解析

### 4.1 RSA 令牌验证系统

#### 4.1.1 工作流程

```
┌──────────────────────┐         ┌──────────────────────┐
│   AURORA-Analyzer.exe │         │   LauncherGUI.ps1    │
│      (C# 客户端)       │         │   (PowerShell 站点)    │
└──────────┬───────────┘         └──────────┬───────────┘
           │                                │
           │  ① 生成随机 Nonce (GUID)        │
           │  ② 获取当前 UTC 时间戳           │
           │  ③ AES-256-CBC 加密哈希列表      │
           │  ④ RSA-SHA256 签名:              │
           │     Sig = RSASign(              │
           │       SHA256(nonce:ts:hashB64), │
           │       PrivateKey, PKCS#1 v1.5)  │
           │  ⑤ 写令牌文件:                   │
           │     nonce:timestamp:hashB64:sig │
           │  ⑥ 环境变量传递路径               │
           │     AURORA_TOKEN_PATH=...        │
           │                                 │
           │        ─── 启动 PS1 ────→       │
           │                                 │
           │                         ⑧ 读取令牌文件
           │                         ⑨ 解析 nonce:ts:hashB64:sig
           │                         ⑩ RSA 公钥验签
           │                         ⑪ 检查时间窗口 (60s)
           │                         ⑫ PBKDF2(nonce) → AES Key
           │                         ⑬ AES-256-CBC 解密哈希列表
           │                         ⑭ 清理令牌文件
           │                                 │
           ◄──────── 看门狗连接 ────────     │
```

#### 4.1.2 关键代码路径

- **签名生成** (EXE C# 端):
  ```
  RSA-SHA256 + PKCS#1 v1.5 签名
  签名输入: nonce + ":" + timestamp + ":" + hashPayloadB64
  ```

- **签名验证** (PS1 SecurityModule):
  ```powershell
  function Test-RSATokenSignature {
      # RSA.FromXmlString(公钥) → VerifyData(SHA256, PKCS#1 v1.5)
  }
  ```

- **时间窗口**：60 秒有效期，容忍 5 秒时钟偏差 (`$age -lt 60 -and $age -gt -5`)

#### 4.1.3 提权安全令牌 (AURORA-SEC-2026-001)

UAC 提权时环境变量会被清空，导致信任链断裂。解决方案：

```
  旧进程 (Non-Admin)             新进程 (Admin)
  ────────────────              ──────────────
  ① 生成 ElevationToken:        ④ 建 ElevationTokenPath 参数读取
     nonce:timestamp:payload        nonce:timestamp:payloadB64
     (AES-256-CBC 加密)          ⑤ PBKDF2(nonce) → AES Key 解密
  ② Base64 编码               ⑥ 验证解密内容包含
  ③ 通过命令行参数传递              "AURORA-AnalyzerLauncherGUI.ps1"
      -ElevationTokenPath         ⑦ 信任链恢复
```

### 4.2 看门狗 IPC (EXE ↔ PS1)

#### 4.2.1 协议设计

```
┌──────────────────────────────────────────────────────┐
│              Named Pipe Protocol                     │
├──────────────────────────────────────────────────────┤
│                                                      │
│  Handshake Phase:                                    │
│    EXE → PS1:  [0x10][HMAC_KEY:32][SESSION_ID:16]    │
│    PS1 → EXE:  [0x11]  (ACK)                         │
│                                                      │
│  Challenge-Response Phase:                            │
│    EXE → PS1:  [0x03][NONCE:16][TIMESTAMP:8]         │
│    PS1 → EXE:  [0x04][HMAC_RESP:32][UPTIME:8][       │
│                      FILE_HASH:32]                    │
│                                                      │
│  Timers:                                             │
│    固定间隔: 5000ms                                    │
│    随机间隔: 2000-7000ms (防时序分析)                   │
│    PS1 响应超时: 3000ms                                │
│    PS1 连接超时: 8000ms (+ 4000ms/重试)               │
│                                                      │
│  Fail Policy:                                        │
│    单次 HMAC 不匹配 → failCount++                     │
│    单次超时        → failCount++                     │
│    failCount ≥ 3   → EXE.Kill(PS1_Process)          │
│    PS1 read(0)     → 断开连接                          │
│                                                      │
└──────────────────────────────────────────────────────┘
```

#### 4.2.2 PS1 端看门狗 Runspace

PS1 端看门狗响应运行在一个独立的 PowerShell Runspace 中（`[runspacefactory]::CreateRunspace()`），确保：
- 不阻塞主 UI 线程
- 即使主线程繁忙也能及时响应挑战
- HMAC 密钥仅存在于 Runspace 闭包中
- 响应包含系统运行时间 (uptime) 和自身文件哈希，供 EXE 端交叉验证

### 4.3 AuroraGuard — C# 嵌入式运行时守卫

#### 4.3.1 架构

`AuroraGuard` 是一个运行时编译的 C# 类（~750 行），通过 `Add-Type -TypeDefinition` 加载到 PowerShell AppDomain 中。守卫的哈希值在构建时由 `build.ps1` 注入 `SecurityModule.ps1`。

#### 4.3.2 检测能力矩阵

| 检测方法 | 实现 | 威胁等级 |
|----------|------|----------|
| `IsDebuggerPresent()` | Win32 API | 基础 |
| `CheckRemoteDebuggerPresent()` | Win32 API | 中级 |
| `NtQueryInformationProcess(ProcessDebugPort)` | NT API | 中级 |
| `NtQueryInformationProcess(ProcessDebugFlags)` | NT API | 中级 |
| `NtQueryInformationProcess(ProcessHandleTracing)` | NT API | 高级 |
| `NtQueryInformationProcess(ProcessBasicInformation)` → PEB.NtGlobalFlag | PEB 读取 | 高级 |
| `GetThreadContext()` + DR0-DR3 硬件断点扫描 | 硬件断点检测 | 高级 |
| `NtSetInformationThread(ThreadHideFromDebugger)` | 反向反调试 | 高级 |
| 进程名扫描 (30+ 调试器进程) | 进程枚举 | 中级 |
| DLL 注入检测 | 模块枚举 + 关键词匹配 | 中级 |

#### 4.3.3 容错机制

- 启用时连续 **2 次**检测到同一威胁才触发警报（防止偶发误报）
- `CheckIntegrity()` 对单文件进行 3 次重试（处理文件占用）
- 完整性检查结果缓存 10 秒（避免频繁磁盘 I/O）
- 诊断日志写入 `%TEMP%\aurora_guard_diag.log`（可供安全审计）

#### 4.3.4 WMI 实时进程监控

通过 `Win32_ProcessStartTrace` 事件订阅实现零延迟调试器进程启动检测：
```powershell
$wmiQuery = "SELECT * FROM Win32_ProcessStartTrace"
$wmiWatcher = New-Object System.Management.ManagementEventWatcher
```
当任何已知调试器进程启动时，立即触发 15 秒倒计时退出。

### 4.4 文件完整性系统

#### 4.4.1 多层完整性监控

```
┌─────────────────────────────────────────────┐
│          Integrity Monitoring Layers        │
├─────────────────────────────────────────────┤
│                                             │
│  L1: 启动时完整性检查                          │
│      ├─ Test-FileIntegrity (一次性)           │
│      └─ 检查失败时继续运行（降级模式）          │
│                                             │
│  L2: 定时器轮询 (固定间隔)                      │
│      ├─ runtimeIntegrityTimer: 3000ms         │
│      └─ 当前文件计数 ≠ 预期 → 触发警报          │
│                                             │
│  L3: 定时器轮询 (随机间隔)                      │
│      ├─ randomIntegrityTimer: 2000-7000ms     │
│      └─ SHA256 重新计算 + LastWriteTime 优化   │
│                                             │
│  L4: FileSystemWatcher (事件驱动)             │
│      ├─ Changed / Deleted / Renamed / Created │
│      └─ 监控模式: *.ps1,*.json,*.xml,*.ico,   │
│          *.exe,*.enc + 子目录递归               │
│                                             │
│  L5: AuroraGuard.CheckIntegrity() (C#)       │
│      ├─ 23 个文件独立哈希表                      │
│      └─ 从 PowerShell 和 C# 两端交叉验证          │
│                                             │
└─────────────────────────────────────────────┘
```

#### 4.4.2 LastWriteTime 优化

为避免每次定时器触发都重新计算所有文件的 SHA256（磁盘密集型），使用 `FileLastCheckTime` 哈希表缓存各文件的最后写入时间。仅当文件的 `LastWriteTime` 变化时才重新计算哈希。

#### 4.4.3 篡改响应

检测到篡改时的标准响应序列：
1. 停止所有完整性检查定时器
2. 禁用 FileSystemWatcher
3. 隐藏所有 UI 窗体 (mainForm, proForm, splash)
4. 显示 `AuroraExitCountdown` 模态倒计时窗口
5. 15 秒后调用 `[Environment]::Exit(1)`

---

## 5. GUI 架构

### 5.1 动画引擎

#### 5.1.1 C# 内嵌 DLL 架构

动画引擎 `AURORA-AnimationCoreEngine` 采用混合加载模式：
- 优先从磁盘加载预编译的 `AURORA-AnimationCoreEngine.dll`
- 若 DLL 被占用或不存在，则运行时重新编译 C# 源码

#### 5.1.2 缓动函数列表 (EasingType 枚举)

```
┌─────────────────────────────────────────────┐
│          20 Easing Functions                │
├─────────────────────────────────────────────┤
│ Linear          EaseInSine                   │
│ EaseInCubic     EaseOutSine                  │
│ EaseOutCubic    EaseInOutSine               │
│ EaseInOutCubic  EaseInExpo                  │
│ EaseInQuad      EaseOutExpo                  │
│ EaseOutQuad     EaseInOutExpo               │
│ EaseInOutQuad   EaseInCirc                  │
│ EaseInQuart     EaseOutCirc                  │
│ EaseOutQuart    EaseInOutCirc               │
│ EaseInOutQuart  EaseInBack                  │
│                 EaseOutBack                  │
│                 EaseInOutBack               │
└─────────────────────────────────────────────┘
```

#### 5.1.3 性能自适应渲染

`AuroraRenderEngine` 静态构造函数根据性能层级自动配置：

| 参数 | Eco | Balanced | Performance | Extreme |
|------|-----|----------|-------------|---------|
| TargetFPS | 30 | 60 | 60 | 60 |
| StarCount | 80 | 180 | 350 | 600 |
| ParticleCount | 0 | 30 | 80 | 150 |
| ComplexGlow | ❌ | ❌ | ✅ | ✅ |
| PathGradientShadows | ❌ | ✅ | ✅ | ✅ |
| ParticleSystem | ❌ | ✅ | ✅ | ✅ |
| DynamicSweep | ❌ | ❌ | ✅ | ✅ |

### 5.2 自定义控件

#### 5.2.1 TechButton

- **波纹效果**：鼠标点击时从点击位置向外扩散圆形波纹
- **磁吸动画**：按钮悬停时从当前位置平滑过渡到目标位置
- 使用 `Timer` 驱动帧级动画更新

#### 5.2.2 AuroraProgressBar

- **平滑过渡**：进度值变化时从当前值缓动到目标值
- 支持垂直/水平方向
- 渐变色填充

#### 5.2.3 StarfieldPanel

- **粒子系统**：星空背景动画，粒子在 3D 空间中旋转和移动
- 基于性能层级动态调整粒子数量
- 在 SplashScreen 和 MainForm 背景中使用

### 5.3 视图层架构

```
LauncherGUI.ps1 (启动器)
  ├─ View-SplashScreen.ps1      ← Show-AuroraSplash
  │     └─ StarfieldPanel 动画
  │
  ├─ View-SessionRestoreDialog.ps1 ← Show-SessionRestoreDialog
  │                                   (通过 syncHash 触发)
  ├─ View-ElevationDialog.ps1      ← Show-ElevationDialog
  ├─ View-PermissionInfo.ps1       ← Show-PermissionInfo
  ├─ View-AdminElevation.ps1       ← Show-AdminElevation
  │
  ├─ View-MainForm.ps1             ← New-AuroraMainForm
  │     ├─ StarfieldPanel 背景
  │     ├─ TechButton × N
  │     ├─ AuroraProgressBar
  │     ├─ 日志类型选择面板
  │     ├─ 状态文本指示器
  │     └─ 事件处理 → syncHash / 直接调用
  │
  └─ View-ProMode.ps1              ← New-ProModeWindow
        ├─ RichTextBox 日志输出
        ├─ 进度指示器
        └─ 用户交互控制
```

### 5.4 双语资源系统

`AURORA-Language.psd1` 采用两级嵌套哈希表结构：

```powershell
@{
    CHS = @{
        "Key_1" = "中文值1"
        "Key_2" = "中文值2"
    }
    ENG = @{
        "Key_1" = "English Value 1"
        "Key_2" = "English Value 2"
    }
}
```

语言选择通过系统 `CurrentUICulture` 自动检测或手动指定 `$Language` 参数。

---

## 6. 智能诊断引擎

### 6.1 4 阶段诊断管线

```
┌────────────────────────────────────────────────────────────┐
│          SmartEngine 4-Phase Diagnostic Pipeline           │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Phase 1: 系统体征检测 (Vitals Detection)                   │
│    ├─ 操作系统版本与架构                                     │
│    ├─ 已安装更新                                            │
│    ├─ 磁盘空间 / 内存 / CPU 使用率                           │
│    ├─ 服务运行状态                                          │
│    └─ 关键系统文件完整性                                     │
│                                                            │
│  Phase 2: 并发日志提取 (Concurrent Log Extraction)           │
│    ├─ PowerShell Runspace 并发池                            │
│    ├─ 支持 10+ 日志类型                                      │
│    ├─ 时间范围过滤                                           │
│    ├─ 事件 ID 过滤                                           │
│    ├─ 多格式输出 (CSV / JSON / XML / TXT)                    │
│    └─ 管理员权限自动检测与提权请求                             │
│                                                            │
│  Phase 3: 知识图谱碰撞 (Knowledge Graph Collision)           │
│    ├─ 加载 AURORA-TechData.json                             │
│    ├─ 事件 ID 模式匹配                                       │
│    ├─ 时间序列关联分析                                       │
│    ├─ 严重程度评分                                           │
│    └─ 根因分析链                                             │
│                                                            │
│  Phase 4: 沙箱自动修复 (Auto-Healing Sandbox)               │
│    ├─ 修复操作封装                                           │
│    ├─ 操作前自动备份 (UndoManager)                           │
│    ├─ 系统还原点创建 (RestoreManager)                        │
│    ├─ 操作后验证                                             │
│    └─ 失败回滚                                               │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### 6.2 知识图谱 (AURORA-TechData.json)

- **格式**：JSON 格式的诊断规则库
- **缓存**：预编译为 `AURORA-TechData.cache.clixml` (PowerShell CLIXML 序列化格式) 加速加载
- **规则结构**：事件 ID + 严重程度 + 诊断描述 + 修复建议 + 关联规则
- **双语支持**：每条规则包含 CHS/ENG 双语言版本

### 6.3 沙箱执行器

```
    操作请求
       │
       ▼
  ┌──────────────┐    成功    ┌──────────────┐
  │ UndoManager  ├──────────►│   执行操作    │
  │ (备份当前状态) │           └──────┬───────┘
  └──────────────┘                  │
       ▲                    ┌───────┴───────┐
       │                    │  操作后验证    │
       │                    └───────┬───────┘
       │                 ┌──────────┴──────────┐
       │                 │                     │
       │             成功 ▼                失败 ▼
       │        ┌────────────┐      ┌────────────┐
       │        │  提交操作   │      │  自动回滚   │
       │        └────────────┘      └─────┬──────┘
       │                                  │
       └──────────────────────────────────┘
```

---

## 7. 会话与进度管理

### 7.1 SessionCache 目录结构

```
SessionCache/
├── active/                    # 当前活动会话
│   ├── session_<id>.json     # 会话状态
│   └── session_<id>.data     # 会话数据
├── checkpoints/               # 检查点备份
│   └── session_<id>_ckpt_<n>.json
└── archive/                   # 已完成会话归档
    └── session_<id>_completed.json
```

**过期策略**：7 天自动过期，`Cleanup-ExpiredSessions` 在启动时运行。

### 7.2 断点续传工作流

```
启动
  │
  ├─ Initialize-CacheDirectory → 创建/验证 SessionCache 目录
  │
  ├─ Find-PendingSession → 扫描 active/ 寻找未完成会话
  │
  ├─ [发现未完成会话?]
  │     │
  │    是 └─→ syncHash.ShowSessionRecoveryHUD = true
  │          │
  │          ├─ 用户选择 [恢复]
  │          │     ├─ Restore-Session → 加载进度
  │          │     ├─ syncHash.RestoredSessionId = ...
  │          │     └─ PRO/SmartEngine 从断点继续
  │          │
  │          └─ 用户选择 [重新开始]
  │                ├─ Remove-Session → 清除旧进度
  │                └─ 创建新会话
  │
  否 └─→ 创建新会话
  │
  ▼
  [执行过程中]
  ├─ Save-Progress → 每次阶段变更时保存
  ├─ Create-Checkpoint → 定期创建检查点
  └─ Archive-Session → 完成时归档
```

### 7.3 Undo 系统

| 组件 | 功能 |
|------|------|
| `AURORA-UndoManager.ps1` | 操作前自动快照 (文件系统/注册表)，操作失败后恢复 |
| `AURORA-UndoViewer.ps1` | 可视化撤销历史，支持手动回滚 |
| `AURORA-RestoreManager.ps1` | Windows 系统还原点创建与管理 |

---

## 8. 构建系统

### 8.1 build.ps1 构建管线

```
┌──────────────────────────────────────────────────────────┐
│              build.ps1 Build Pipeline                     │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  [0]    密码强度校验 (8+ 字符, 大小写+数字+特殊, 3次重试)   │
│  [0.5]  RSA 2048 密钥对生成 (RSACryptoServiceProvider)    │
│  [0.7]  安全代码注入 → SecurityModule.ps1                 │
│           ├─ RSA 公钥替换 (首次 / 更新)                    │
│           └─ SessionSalt 替换                             │
│  [0.8]  版本号注入 (VxxxRelease → 所有 .ps1 文件)          │
│  [1]    SHA256 哈希计算 (RequiredFiles × 26)               │
│  [2]    明文检查数据生成 (hash + path 列表)                 │
│  [2.5]  AuroraGuard C# 哈希注入 → SecurityModule.ps1      │
│           └─ 23 个文件哈希注入 Dictionary                 │
│  [3]    AES-256-CBC 加密                                  │
│           ├─ PBKDF2-SHA256 (100k 迭代) 密钥派生            │
│           └─ 输出: Salt(16) + IV(16) + Cipher → GAURORA   │
│  [4]    加密一致性验证 (解密回环测试)                        │
│  [5]    C# 源码生成 + EXE 编译                             │
│           ├─ 密码混淆 (XOR + 随机排列)                      │
│           ├─ 源码符号混淆 (类名/方法名随机化)                │
│           ├─ csc.exe 编译 (x86, winexe)                    │
│           └─ CRC32 自校验嵌入 (非混淆模式)                   │
│  [6]    文件夹美化 (desktop.ini + 图标)                     │
│  [7]    构建后验证 (所有文件存在性检查)                      │
│  [8]    ZIP 打包 (可选, 用户交互确认)                       │
│  [最后]  内存安全清理 (密钥 / 密码归零)                      │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### 8.2 密码混淆存储

EXE 中的主密码不直接存储明文，而是经过以下混淆：

```
原始密码: "MySecureP@ss1"
  ↓ UTF8 编码
[0x4D, 0x79, ..., 0x31]
  ↓ 随机排列顺序 (PwOrder)
[0x31, 0x4D, ...]    ← 顺序被打乱
  ↓ XOR 掩码 (16 字节随机)
[0x31^M0, 0x4D^M1, ...]
  ↓ Base64
PwEncryptedB64 = "..."

存储：PwXorMaskB64 + PwEncryptedB64 + PwOrder
恢复：XOR → 按 PwOrder 反向排列 → UTF8 解码
```

### 8.3 C# 符号混淆

构建时对 C# 源码的类名和方法名进行随机化（仅在不启用完整混淆降级方案时）：

| 原始符号 | 混淆后示例 |
|----------|-----------|
| `class AuroraLauncher` | `class a_xyzabcd` |
| `CalculateCrc32()` | `c_defghi()` |
| `CheckAntiDump()` | `d_jklmno()` |
| `CheckDebuggerAPIs()` | `e_pqrstu()` |
| `FullAntiDebugCheck()` | `f_vwxyzab()` |

### 8.4 版本管理

- **version.txt**：存储当前版本号
- **`-IncrementVersion`**：构建时自动递增最后一位
- **版本注入**：正则匹配所有 .ps1 文件中的 `# 版本：VxxxRelease` / `# Version：VxxxRelease` 注释并替换

---

## 9. 性能分级系统

### 9.1 硬件检测算法

```powershell
# 算力加权评分公式：
$ramGB = TotalPhysicalMemory / 1GB
$logicalCores = NumberOfLogicalProcessors
$baseClock = MaxClockSpeed (MHz)

$perfScore = ($logicalCores × 15) + ($ramGB × 5) + max(0, ($baseClock - 2000) / 100)
```

### 9.2 分级阈值

| 级别 | 评分范围 | 典型硬件 | 特征 |
|------|----------|----------|------|
| **Eco** (节能) | < 70 | 双核, 4GB RAM, 低频 | 最小粒子, 30FPS |
| **Balanced** (均衡) | 70-119 | 四核, 8GB RAM | 标准粒子, 60FPS |
| **Performance** (性能) | 120-239 | 六核, 16GB RAM | 高级效果, 全开 |
| **Extreme** (发烧) | ≥ 240 | 八核+, 32GB+ RAM | 全部特效, 600 星星 |

### 9.3 性能数据注入路径

```
Hardware Detection (LauncherGUI.ps1)
  ↓ 设置环境变量
[Environment]::SetEnvironmentVariable("AURORA_PERF_TIER", $tier)
  ↓ C# 静态构造函数读取
AuroraRenderEngine 自动配置 FPS / 粒子 / 特效
```

---

## 10. 跨线程通信

### 10.1 syncHash 架构

AURORA 采用全局同步哈希表 (`[hashtable]::Synchronized()`) 作为唯一跨线程通信通道：

```
┌─────────────────────┐          ┌─────────────────────────┐
│    GUI 线程 (STA)    │          │  PRO/SmartEngine Runspace│
│  MainForm + Timers  │  ◄─────► │  (后台线程)              │
└─────────┬───────────┘          └─────────┬───────────────┘
          │                                │
          └──────────┬─────────────────────┘
                     │ 读写
                     ▼
          ┌─────────────────────┐
          │  $global:syncHash   │
          │  Synchronized()     │
          ├─────────────────────┤
          │  IsHostAlive        │  GUI → PRO: 控制生命周期
          │  IsRunning          │  PRO → GUI: 执行状态
          │  ScriptDone         │  PRO → GUI: 完成标记
          │  LogOutput          │  PRO → GUI: 日志流
          │  Progress           │  PRO → GUI: 进度 0-100
          │  CurrentActivity    │  PRO → GUI: 活动描述
          │  CurrentStatus      │  PRO → GUI: 状态消息
          │  UserInput          │  GUI → PRO: 用户输入
          │  IsAdmin            │  GUI → PRO: 管理员标记
          │  RequiresElevation  │  PRO → GUI: 提权请求
          │  ElevationReason    │  PRO → GUI: 提权原因
          │  ElevationAuthorized│  GUI → PRO: 提权授权
          │  SessionRestored    │  GUI → PRO: 恢复标记
          │  SessionRestarted   │  GUI → PRO: 重启标记
          │  ShowSessionRecovery│  PRO → GUI: 显示 HUD
          └─────────────────────┘
```

### 10.2 线程安全

- `.NET` 的 `[hashtable]::Synchronized()` 为所有读写操作提供原子性保证
- GUI 定时器 (WinForms Timer) 运行在主 UI 线程，安全读取 `syncHash`
- PRO Runspace 运行在独立线程，安全写入 `syncHash`
- `UserInput` 字段使用轮询模式 (`while ($null -eq $global:syncHash.UserInput)`)

---

## 11. 技术栈总结

| 层次 | 技术 | 用途 |
|------|------|------|
| **启动器** | C# 5.0 / .NET Framework 4.x | EXE 封装、看门狗、反调试 |
| **主逻辑** | PowerShell 5.0+ | GUI、引擎、工具 |
| **GUI 框架** | .NET Windows Forms | 窗体、控件、绘图 |
| **加密** | RSA 2048 + AES-256-CBC + PBKDF2-SHA256 | 令牌、密码、哈希列表 |
| **IPC** | .NET Named Pipe + HMAC-SHA256 | EXE ↔ PS1 看门狗 |
| **序列化** | JSON + CLIXML | 知识图谱、会话数据 |
| **并发** | PowerShell Runspace | 诊断管线、看门狗 |
| **动画** | C# 内嵌 DLL + GDI+ | 缓动、粒子、渲染 |
| **字体** | CascadiaMono.ttf (等宽) + Microsoft YaHei UI | UI 显示 |
| **构建** | PowerShell + csc.exe | 编译、签名、打包 |
| **编译目标** | x86 (32-bit) | 最大兼容性 |

**依赖项**：
- Windows Vista SP2 或更高版本
- PowerShell 5.0 或更高版本
- .NET Framework 4.x (Windows 10+ 内置)
- 管理员权限（Security 日志导出）

---

## 12. 攻击面分析

### 12.1 攻击向量与缓解

| 攻击向量 | 风险 | 缓解措施 |
|----------|------|----------|
| **直接运行 .ps1 绕过 EXE 验证** | 中 | SmartEngine 检测调用方，密码验证兜底 |
| **篡改 .ps1 文件** | 高 | SHA256 完整性检查 × 5 层 (启动时 + 定时器 × 2 + FileSystemWatcher + AuroraGuard) |
| **调试器附加** | 高 | 9 种反调试检测 + WMI 实时进程监控 |
| **DLL 注入** | 中 | 模块枚举 + 关键词检测 |
| **内存 Dump** | 中 | 反 Dump 模块检测 + 密码 XOR 混淆 |
| **中间人替换 EXE** | 高 | RSA 公钥签名验证 + 60s 时间窗口 |
| **环境变量伪造** | 高 | RSA 令牌必须被公钥验证，未验证标记被强制重置 |
| **UAC 提权断链** | 中 | ElevationToken 二次验证 (AES-256-CBC) |
| **时序攻击看门狗** | 低 | 随机挑战间隔 (2-7s) + 最多 3 次失败 |
| **暴力破解密码** | 低 | PBKDF2-SHA256 100k 迭代 + 密码强度强制校验 |
| **知识图谱投毒** | 低 | JSON 和 .cache.clixml 均在完整性哈希保护下 |
| **供应链攻击** | 低 | 所有文件哈希在构建时生成并加密存储 |

### 12.2 信任模型

```
信任根: build.ps1 构建环境（离线）
  ├─ 生成 RSA 密钥对 → 私钥仅保留在构建机器
  ├─ SHA256 哈希所有文件 → 加密存储
  ├─ 编译 EXE（嵌入密码 + 反调试）
  └─ 分发 ZIP（所有文件 + 加密校验文件）

分发:
  ├─ EXE: 自校验 + 启动 PS1 子进程
  ├─ PS1: 验签 EXE 令牌 + 文件完整性 × 5 层
  └─ 数据: 知识图谱受完整性保护
```

### 12.3 已知局限性

1. **PowerShell 脚本本质**：.ps1 文件可被文本编辑器查看，无法做到真正的代码混淆（但 AuroraGuard C# 部分已编译为 IL）
2. **用户态反调试**：无法防御内核级调试器（如 WinDbg 内核模式）
3. **内存窃取**：密码在使用时存在于内存中，足够高级的攻击者可以通过物理内存访问提取
4. **x86 编译**：32 位进程内存地址空间更小，可能更易受攻击，但保证了最大兼容性

---

## 13. 贡献指南

### 13.1 模块开发规范

1. **单一职责**：每个 .ps1 文件只负责一个功能领域
2. **命名约定**：
   - Core 模块：`AURORA-XxxEngine.ps1`
   - Security 模块：`AURORA-SecurityModule.ps1`
   - UI 控件：`AURORA-UIControls.ps1` / `AURORA-Animations.ps1`
   - 视图文件：`View-Xxx.ps1`（对话框：`Dialogs/View-Xxx.ps1`）
   - PRO 模块：`AURORA-AnalyzerPRO*.ps1`
   - 会话模块：`AURORA-ProgressManager*.ps1` / `AURORA-Undo*.ps1`
   - 修复模块：`AURORA-Repair*.ps1` / `AURORA-Restore*.ps1`
   - GUI 辅助：`AURORA-GUI-Functions.ps1` / `AURORA-Language.psd1`
3. **加载顺序**：新增模块必须在 `LauncherGUI.ps1` 中按正确依赖顺序注册
4. **双语支持**：所有用户可见字符串必须通过 `AURORA-Language.psd1` 或内建双语函数实现

### 13.2 安全模块开发注意事项

- 安全模块（`AURORA-SecurityModule.ps1`）中的 RSA 公钥和 SessionSalt 通过 `build.ps1` 自动注入，**不要手动修改**
- AuroraGuard 哈希字典（`_expected` Dictionary）也在构建时自动注入
- 新增文件必须添加到 `build.ps1` 的 `$RequiredFiles` 数组中
- AuroraGuard 的 `$guardTargetFiles` 必须与 `$RequiredFiles` 同步更新（但排除 SecurityModule 自身）

### 13.3 构建前检查清单

- [ ] 所有新文件已添加到 `build.ps1` → `$RequiredFiles`
- [ ] 所有新文件已添加到 `build.ps1` → `$guardTargetFiles`
- [ ] 视图文件已在 `LauncherGUI.ps1` 中 dot-source
- [ ] 依赖顺序正确（CoreEngine → SecurityModule → UIControls → Views）
- [ ] 双语字符串已注册到 `AURORA-Language.psd1`
- [ ] 测试通过：`Test-Bilingual.ps1`, `Test-ProgressManager.ps1`, `Test-Verification.ps1`

### 13.4 测试

项目提供丰富的测试套件，位于 `test/` 目录：

| 测试文件 | 测试目标 |
|----------|----------|
| `Test-Bilingual.ps1` | 双语系统完整性 |
| `Test-ProgressManager.ps1` | 进度管理器核心功能 |
| `Test-ProgressManager-Integration.ps1` | 进度管理器集成 |
| `Test-ProgressManager-Load.ps1` | 进度加载性能 |
| `Test-ProgressManager-Bilingual.ps1` | 进度管理器双语 |
| `Test-UndoBackup.ps1` | 撤销备份 |
| `Test-RealBackup.ps1` | 真实备份测试 |
| `Test-Verification.ps1` | 完整性验证 |
| `Test-Runtime-Tamper.ps1` | 运行时篡改检测 |
| `Test-PRO-Merge.ps1` | PRO 引擎合并验证 |
| `AURORA-UndoTest.ps1` | 撤销系统集成测试 |
| `test-rsa-verification.ps1` | RSA 验证流程 |
| `check_brackets.ps1` | 括号/语法完整性 |

---

## 附录 A：文件清单

### 核心运行时文件

```
AURORA-Analyzer.exe                          ← C# EXE 启动器 (x86, winexe)
GAURORA.CHK.ENC                              ← AES-256 加密的哈希列表
version.txt                                  ← 版本号
Scripts/
├── AURORA-AnalyzerLauncherGUI.ps1           ← 主启动器 / 编排层
├── Core/
│   ├── AURORA-CoreEngine.ps1                 ← 共享核心引擎
│   ├── AURORA-AnimationCoreEngine.ps1        ← 动画核心引擎
│   └── AURORA-AnimationCoreEngine.dll        ← 动画 C# DLL (可选)
├── Security/
│   └── AURORA-SecurityModule.ps1             ← 安全模块
├── UI/
│   ├── Controls/
│   │   ├── AURORA-UIControls.ps1             ← 自定义 UI 控件
│   │   └── AURORA-Animations.ps1             ← 动画辅助
│   └── Views/
│       ├── View-MainForm.ps1                 ← 主窗体
│       ├── View-SplashScreen.ps1             ← 启动画面
│       ├── View-ProMode.ps1                  ← PRO 模式窗口
│       └── Dialogs/
│           ├── View-SessionRestoreDialog.ps1
│           ├── View-ElevationDialog.ps1
│           ├── View-PermissionInfo.ps1
│           └── View-AdminElevation.ps1
├── Engines/
│   └── AURORA-SmartEngine.ps1                ← 智能诊断引擎
├── PRO/
│   ├── AURORA-AnalyzerPRO-Engine.ps1         ← PRO 引擎 (290KB+)
│   └── AURORA-AnalyzerPRO.ps1                ← PRO 入口
├── Session/
│   ├── AURORA-ProgressManager.ps1             ← 进度管理器
│   ├── AURORA-ProgressManager-Integration.ps1 ← 进度集成
│   ├── AURORA-UndoManager.ps1                ← 撤销管理
│   └── AURORA-UndoViewer.ps1                 ← 撤销查看器
├── Repair/
│   ├── AURORA-RepairTools.ps1                 ← 修复工具
│   ├── AURORA-RepairLogger.ps1                ← 修复日志
│   └── AURORA-RestoreManager.ps1              ← 还原点管理
└── GUI/
    ├── AURORA-GUI-Functions.ps1               ← GUI 辅助函数
    └── AURORA-Language.psd1                   ← 双语资源字典
Data/
├── AURORA-TechData.json                       ← 知识图谱 (JSON)
└── AURORA-TechData.cache.clixml               ← 知识图谱缓存
Resources/
├── AURORAICON.ico                             ← 应用图标
└── CascadiaMono.ttf                           ← 等宽字体
```

### 构建相关文件

```
build.ps1                                     ← 主构建脚本
AURORA-build.bat                              ← 构建批处理 (备用)
cache.txt                                     ← 构建缓存
test-version-regex.ps1                         ← 版本正则测试
test/                                         ← 测试套件 (~17 个测试)
Docs/                                         ← 设计文档 (10+ 篇)
.github/workflows/build.yml                   ← CI 配置
```

---

## 附录 B：版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| V1.2.25.0 | - | 初始发布版 |
| V1.3.26.0 | 2026.06 | 架构解耦 Phase 1-5 |
| V1.3.26.5 | 2026.06.08 | 完全架构解耦 (11 层 22+ 文件) |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *本工具仅供个人学习使用。请遵守当地法律法规。*