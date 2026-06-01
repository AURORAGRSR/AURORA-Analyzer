# AURORA Analyzer — 完整功能概述

> **版本**: V1.2.24.5Release
> **构建时间**: 2026.06.01
> **项目代号**: AURORA VelociRaptor-GR Dev PRJ.
> **文档类型**: 工具完整功能概述（面向所有受众）

---

## 目录

- [1. 项目简介](#1-项目简介)
- [2. 架构全景](#2-架构全景)
- [3. 三种运行模式](#3-三种运行模式)
- [4. 功能模块详解](#4-功能模块详解)
  - [4.1 日志导出系统](#41-日志导出系统)
  - [4.2 智能诊断引擎](#42-智能诊断引擎)
  - [4.3 系统修复工具集](#43-系统修复工具集)
  - [4.4 撤销与还原系统](#44-撤销与还原系统)
  - [4.5 进度管理与断点续传](#45-进度管理与断点续传)
- [5. 安全架构](#5-安全架构)
- [6. 技术规格](#6-技术规格)
- [7. 构建与部署](#7-构建与部署)
- [8. 文件清单](#8-文件清单)

---

## 1. 项目简介

**AURORA Analyzer** 是一款面向 Windows 系统的高级诊断与日志分析工具。它能够：

- 📊 **自动导出** Windows 事件日志为 CSV / JSON / XML / TXT 格式
- 🔍 **智能诊断** 系统稳定性、性能瓶颈、网络异常、安全漏洞、硬件故障
- 🔧 **一键修复** Windows Update、Defender、网络栈、系统文件等常见问题
- ↩️ **安全回滚** 修复前自动备份，支持注册表/文件/服务级精确撤销
- 🛡️ **纵深防御** 从构建到运行全生命周期安全保护

### 核心设计理念

| 理念 | 实现方式 |
|------|----------|
| **零依赖** | 纯 PowerShell + 内嵌 C#，无需安装任何第三方运行时 |
| **本地安全** | 所有数据在本地处理，不连接互联网，不上传任何信息 |
| **不可篡改** | RSA 签名 + SHA256 完整性验证 + HMAC 看门狗双向心跳 |
| **可逆操作** | 每次修复自动创建快照，支持注册表/文件/服务三级回滚 |

---

## 2. 架构全景

```
┌─────────────────────────────────────────────────┐
│              AURORA-Analyzer.exe                 │
│         (C# EXE 加载器 / 看门狗服务器)              │
│  · RSA 令牌生成  · 命名管道通信  · 进程生命周期管理   │
└────────────────────┬────────────────────────────┘
                     │ 环境变量注入 + 命名管道
┌────────────────────▼────────────────────────────┐
│       AURORA-AnalyzerLauncherGUI.ps1             │
│     (PowerShell GUI 启动器 + 安全守护核心)         │
│  · 语言选择界面  · 模式选择  · AuroraGuard 运行时守护 │
│  · 性能分级  · 看门狗客户端  · 退出处理               │
└────────────────────┬────────────────────────────┘
                     │ Dot-sourcing 调用
     ┌───────────────┼───────────────┐
     ▼               ▼               ▼
┌─────────┐  ┌──────────┐  ┌──────────────┐
│ 智能模式  │  │ 专业图形  │  │  控制台模式    │
│ Smart   │  │   GUI    │  │   Console     │
│ Engine  │  │  Mode    │  │    Mode       │
└────┬────┘  └────┬─────┘  └──────┬───────┘
     │            │               │
     └────────────┼───────────────┘
                  ▼
┌─────────────────────────────────────────────────┐
│              16 个核心引擎脚本                      │
│  · SmartEngine  · CoreEngine  · RepairTools      │
│  · UndoManager  · RestoreManager  · RepairLogger  │
│  · ProgressManager  · AnimationCoreEngine  · GUI  │
│  · 中/英文专业版引擎  · UndoViewer                    │
│  · 所有文件受 SHA256 完整性哈希保护                   │
└─────────────────────────────────────────────────┘
```

---

## 3. 三种运行模式

AURORA Analyzer 启动后首先进行语言选择（中文/英文），然后提供三种运行模式：

### 3.1 智能诊断与自主修复模式

**适用场景**: 快速排查问题，自动化诊断与修复

启动 `AURORA-SmartEngine.ps1`，执行全自动流程：

1. 扫描系统日志，匹配知识库中的问题模式
2. 自动分析蓝屏 Minidump 文件
3. 生成诊断报告并给出修复建议
4. 在用户确认后执行自动修复

**特点**: 无需手动操作，适合普通用户快速解决问题。

### 3.2 专业图形模式

**适用场景**: 专业用户需要精细控制每个功能

启动 `AURORA-AnalyzerCHSPRO.ps1` 或 `AURORA-AnalyzerENGPRO.ps1`，提供完整的图形化操作界面，包括：

- 日志导出面板（按类型/时间/级别/事件ID筛选）
- 智能诊断面板（5 大类别，含知识库规则匹配）
- 系统修复面板（5 类修复 + 自定义修复）
- 撤销还原面板（历史记录查看 + 精确回滚）
- 进度管理面板（会话列表 + 断点续传）

**特点**: 功能最全面，适合专业 IT 运维人员。

### 3.3 控制台模式

**适用场景**: 脚本化操作、远程管理、自动化集成

在 PowerShell 控制台中运行，适合：

- 批量处理多台电脑的日志
- 集成到自动化运维脚本
- 低资源环境下的运行

**特点**: 轻量级，可脚本化，适合高级用户。

---

## 4. 功能模块详解

### 4.1 日志导出系统

**实现引擎**: `AURORA-AnalyzerCHSPRO.ps1` / `AURORA-AnalyzerENGPRO.ps1`

#### 支持的事件日志类型

| 日志类型 | Windows 日志名称 | 典型用途 |
|----------|-----------------|----------|
| 系统日志 | System | 排查驱动错误、服务崩溃、内核事件 |
| 应用程序日志 | Application | 排查软件崩溃、安装失败、.NET 错误 |
| 安全日志 | Security | 审计登录记录、权限变更、安全策略 |
| 安装日志 | Setup | 排查软件安装/卸载失败、Windows 更新安装 |
| 转发事件 | ForwardedEvents | 集中管理多台计算机的事件日志 |

#### 筛选与导出选项

| 功能 | 说明 |
|------|------|
| 时间范围筛选 | 选择起始和结束日期，精确到分钟 |
| 事件级别筛选 | 严重、错误、警告、信息、详细 |
| 事件 ID 筛选 | 精确匹配特定事件 ID（如蓝屏事件 1001） |
| 来源筛选 | 按服务名称或驱动程序名称筛选 |
| 关键词搜索 | 在日志消息内容中搜索关键词 |
| 最大条目限制 | 控制导出文件大小 |

#### 导出格式

| 格式 | 特点 | 推荐场景 |
|------|------|----------|
| **CSV** | 兼容 Excel、WPS，易于排序和筛选 | 自己分析、发给同事 |
| **JSON** | 结构化数据，可编程处理 | 开发者、自动化工具对接 |
| **XML** | 完整 Windows 事件格式，保留所有字段 | 发给微软技术支持 |
| **TXT** | 纯文本，最小体积 | 快速查看、邮件发送 |

#### 导出目录

所有导出文件默认保存在 `UserLogs\` 目录下，按时间戳自动命名，便于管理。

---

### 4.2 智能诊断引擎

**实现引擎**: `AURORA-SmartEngine.ps1`
**知识库**: `Data\AURORA-TechData.json`（v3.1，2026-05-14 更新）

#### 五大诊断类别

| 类别 | 检查内容 | 常见问题示例 |
|------|----------|-------------|
| **A. 系统稳定性** | 系统崩溃、蓝屏、意外关机、内核错误 | 驱动冲突、电源不稳、硬件故障 |
| **B. 性能诊断** | 启动慢、响应卡顿、磁盘高占用、内存泄漏 | 启动项过多、磁盘碎片、服务超时 |
| **C. 网络诊断** | WiFi 断连、DNS 失败、网络受限、代理异常 | 驱动问题、Winsock 损坏、防火墙规则 |
| **D. 安全审计** | 暴力登录、权限提升、病毒扫描、安全策略变更 | 系统被入侵、账户被盗、恶意软件 |
| **E. 硬件诊断** | 磁盘错误、内存错误、CPU 过热、USB 异常 | 硬盘坏道、内存故障、散热不良 |

#### 知识库系统

诊断引擎内置了 **AURORA 技术知识库（v3.1）**，包含大量已知问题的诊断规则，每条规则包括：

- **规则 ID**: 唯一标识（如 A-001 表示系统稳定性类别第 1 条规则）
- **匹配条件**: 事件 ID、来源、消息关键词
- **严重程度**: Critical / Error / Warning / Information
- **问题描述**: 中英双语，通俗易懂
- **可能原因**: 3-5 条常见原因
- **解决方案**: 3-5 条具体操作建议
- **推荐操作**: 优先执行的修复步骤
- **自动修复命令**: 可选的一键修复命令（含风险等级和回滚命令）

**知识库覆盖范围**: Windows 10 / Windows 11 / Windows Server 2016+

**v3.1 新增**: USB 故障诊断、虚拟化问题检测、.NET 运行时错误、TLS/SSL 证书问题、组策略冲突诊断

#### 蓝屏分析

- 自动定位 `C:\Windows\Minidump\` 中的蓝屏转储文件
- 解析蓝屏错误代码（BugCheck Code）
- 识别导致蓝屏的驱动程序
- 关联知识库中的解决方案

---

### 4.3 系统修复工具集

**实现引擎**: `AURORA-RepairTools.ps1`

#### 修复类型

| 修复类型 | 参数值 | 修复内容 |
|----------|--------|----------|
| **Windows Update 修复** | `DisableWindowsUpdate` | 重置更新组件、清除更新缓存、修复更新服务 |
| **Defender 修复** | `EnableDefender` | 修复 Windows Defender 服务、重置安全策略 |
| **遥测清理** | `DisableTelemetry` | 清理 Windows 遥测数据、优化隐私设置 |
| **网络重置** | `ResetNetwork` | 重置 TCP/IP 协议栈、清除 DNS 缓存、重置 Winsock |
| **系统清理** | `CleanSystem` | 清理临时文件、修复系统文件、整理磁盘 |
| **自定义修复** | `Custom` | 指定目标执行自定义修复命令 |

#### 修复前保护机制

每次修复操作前，系统自动执行以下保护：

1. **系统还原点** (`CreateRestorePoint`): 创建 Windows 系统还原点，可回滚整个系统状态
2. **快速备份快照** (`UseBackupSnapshot`): 精确备份即将修改的注册表项、文件、服务状态

#### 修复安全保障

- 修复命令需管理员权限执行
- 每条修复命令定义了风险等级（Low / Medium / High）
- 高风险命令需要用户二次确认
- 所有修复操作记录到 `AURORA-RepairLogger.ps1` 日志

---

### 4.4 撤销与还原系统

**实现引擎**: `AURORA-UndoManager.ps1` / `AURORA-UndoViewer.ps1`

#### 三级备份体系

| 备份级别 | 备份内容 | 恢复方式 |
|----------|----------|----------|
| **注册表备份** | 修改前后的注册表键值 | 精确恢复到修改前的值 |
| **文件备份** | 修改前后的文件副本 | 替换回原始文件 |
| **服务备份** | 服务的启动类型和状态 | 恢复服务的原始配置 |

#### 快照管理

- **创建快照**: `Create-BackupSnapshot` — 在修复前自动创建，包含所有即将修改的资源
- **恢复快照**: `Restore-BackupSnapshot` — 一键恢复到快照创建时的状态
- **快照完整性**: `Test-BackupIntegrity` — 验证备份数据的完整性
- **快照删除**: `Remove-BackupSnapshot` — 清理不需要的旧快照

#### 撤销查看器

`AURORA-UndoViewer.ps1` 提供图形化的撤销历史查看界面：

- 显示所有修复会话列表
- 查看每个会话的详细修改内容
- 修改前后值对比
- 一键撤销或保留

#### 系统还原点

除了快速备份快照，AURORA Analyzer 还在每次修复前创建 Windows 系统还原点，提供额外的系统级安全网。

---

### 4.5 进度管理与断点续传

**实现引擎**: `AURORA-ProgressManager.ps1`

#### 会话管理

| 功能 | 函数 | 说明 |
|------|------|------|
| 创建会话 | `New-Session` | 开始新任务时创建会话记录 |
| 保存进度 | `Save-SessionProgress` | 自动保存当前完成百分比和阶段 |
| 恢复进度 | `Restore-SessionProgress` | 从中断处恢复任务 |
| 删除会话 | `Remove-SessionProgress` | 清理已完成的会话 |
| 查询待处理 | `Get-LatestPendingSession` | 获取最近未完成的会话 |
| 检查状态 | `Test-PendingSession` | 检查是否有未完成的任务 |
| 完成标记 | `Complete-Session` | 标记会话为已完成 |
| 统计信息 | `Get-SessionStatistics` | 查看所有会话的汇总统计 |

#### 断点续传机制

- 进度自动保存到本地文件（`.cache.clixml` 格式）
- 即使程序关闭或系统重启，下次打开可恢复
- 支持同时管理多个进行中的任务
- 每个任务记录：会话 ID、任务类型、当前阶段、完成百分比、保存时间

---

## 5. 安全架构

AURORA Analyzer 采用 **五层纵深防御** 模型，从构建到运行全程保护：

### 第一层：构建时保护

- **RSA 密钥对**: 构建工具持有私钥，用于签名令牌；PS1 内嵌公钥用于验证
- **SHA256 完整性哈希**: 16 个核心脚本的哈希值硬编码于 AuroraGuard
- **令牌时效性**: 60 秒有效期，防止 Token 重放攻击

### 第二层：启动验证

- **RSA 令牌签名验证**: SHA256 + PKCS#1 v1.5
- **AES 会话密钥派生**: PBKDF2 + AES-256-CBC 解密哈希清单
- **文件完整性验证**: 逐文件 SHA256 比对

### 第三层：IPC 安全

- **命名管道双向认证**: `AURORA_WD_{8 hex}` 随机管道名
- **HMAC-SHA256 挑战-响应**: EXE 周期性发送挑战，PS1 必须正确响应
- **双向心跳检测**: 单次失败即终止进程

### 第四层：运行时守护（AuroraGuard）

- **调试器 API 检测**: IsDebuggerPresent、CheckRemoteDebuggerPresent、NtQueryInformationProcess（DebugPort / DebugFlags / HandleTracing）
- **硬件断点检测**: GetThreadContext 读取 CPU Dr0-Dr3 调试寄存器
- **PEB 分析**: 读取 NtGlobalFlag 判断是否被调试器启动
- **进程名扫描**: 枚举 90+ 已知调试工具进程名
- **DLL 注入检测**: 分析非系统模块路径
- **线程隐藏**: NtSetInformationThread(ThreadHideFromDebugger)
- **持续性轮询**: 每 3 秒 + WMI 实时进程创建事件

### 第五层：退出清理

- **双事件注册**: PowerShell.Exiting + ProcessExit
- **资源级联释放**: 管道 → Runspace → 定时器 → WMI 监控 → 环境变量

---

## 6. 技术规格

### 系统要求

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| 操作系统 | Windows 10 1809+ | Windows 11 |
| 架构 | x64 / x86 (WOW64) | x64 |
| 处理器 | 双核 1.5 GHz | 四核 2.0 GHz+ |
| 内存 | 4 GB | 8 GB+ |
| 磁盘空间 | 200 MB | 500 MB+ |
| .NET Framework | 4.x | 4.8 |
| PowerShell | Windows PowerShell 5.1+ | Windows PowerShell 5.1+ |

### 性能分级

AURORA Analyzer 启动时自动检测硬件配置，选择最优性能等级：

| 等级 | 硬件要求 | 并行度 | 内存策略 |
|------|----------|--------|----------|
| **Extreme（发烧级）** | 8 核+ / 32GB+ RAM | 全并行 | 激进缓存 |
| **Performance（性能级）** | 6 核 / 16GB RAM | 4 线程 | 均衡缓存 |
| **Balanced（均衡级）** | 4 核 / 8GB RAM | 2 线程 | 适度缓存 |
| **Eco（节能级）** | 老旧设备 | 单线程 | 最小缓存 |

### 技术栈

| 层 | 语言 | 运行时 | 关键依赖 |
|----|------|--------|----------|
| EXE 加载器 | C# | .NET Framework 4.x | System.Diagnostics.Process, System.IO.Pipes |
| GUI Launcher | PowerShell + 内嵌 C# | Windows PowerShell 5.1 | System.Windows.Forms, System.Drawing |
| 安全守卫 | 内嵌 C# (Add-Type) | .NET Framework 4.x | ntdll.dll, kernel32.dll (P/Invoke) |
| 核心引擎 | PowerShell | Windows PowerShell 5.1 | 无第三方依赖 |

---

## 7. 构建与部署

### 构建命令

```powershell
# 标准构建
.\build.ps1

# 跳过签名（仅测试）
.\build.ps1 -SkipSigning
```

### 构建流程

1. **令牌生成**: 计算所有核心脚本 SHA256 → PBKDF2 派生 AES 密钥 → 加密哈希清单 → RSA 签名
2. **EXE 编译**: CSharpCodeProvider 编译 C# 加载器 → 嵌入 RSA 公钥/主密码/哈希表
3. **HMAC 密钥生成**: PBKDF2(MasterPassword, WdHmacSalt, 10000) → 32 字节密钥
4. **输出**: `AURORA-Analyzer.exe` + 令牌文件

### 部署要求

- 将整个项目目录（含 Scripts\、Data\、Core\ 子目录）复制到目标电脑
- 以**管理员权限**运行 `AURORA-Analyzer.exe`
- 首次运行会自动进行安全验证

---

## 8. 文件清单

### 核心脚本（16 个，受完整性保护）

| 文件 | 功能 |
|------|------|
| `AURORA-AnalyzerLauncherGUI.ps1` | GUI 启动器 + 安全守卫 + 看门狗客户端 |
| `AURORA-SmartEngine.ps1` | 智能诊断引擎 |
| `AURORA-CoreEngine.ps1` | 核心引擎 |
| `AURORA-AnalyzerCHSPRO.ps1` | 中文专业版引擎 |
| `AURORA-ProgressManager.ps1` | 进度管理器 |
| `AURORA-GUI-Functions.ps1` | GUI 功能函数库 |
| `AURORA-RepairTools.ps1` | 修复工具集 |
| `AURORA-UndoManager.ps1` | 撤销管理器 |
| `AURORA-RestoreManager.ps1` | 还原管理器 |
| `AURORA-RepairLogger.ps1` | 修复日志记录器 |
| `AURORA-UndoViewer.ps1` | 撤销查看器 |
| `AURORA-AnalyzerPRO.ps1` | 通用专业版引擎 |

### 扩展脚本

| 文件 | 功能 |
|------|------|
| `AURORA-ProgressManager-Integration.ps1` | 进度管理器集成 |
| `AURORA-ProgressManager-Integration-CHS.ps1` | 进度管理器中文集成 |
| `AURORA-ProgressManager-Integration-ENG.ps1` | 进度管理器英文集成 |
| `Core\AURORA-AnimationCoreEngine.ps1` | 动画引擎核心 |

### 数据文件

| 文件 | 功能 |
|------|------|
| `Data\AURORA-TechData.json` | 技术知识库（v3.1） |
| `Data\AURORA-TechData.cache.clixml` | 知识库缓存 |

### 构建与文档

| 文件 | 功能 |
|------|------|
| `build.ps1` | EXE 构建脚本 |
| `update.md` / `update_EN.md` | 版本更新日志 |
| `READMEV1.2.24.5Release.md` / `_EN.md` | 用户手册 |
| `READMEV1.2.24.5.md` / `_EN.md` | 技术文档 |
| `AURORA-Analyzer-Overview.md` / `_EN.md` | 完整功能概述 |

---

*AURORA VelociRaptor-GR Dev PRJ. — 2026.06.01*