# AURORA Analyzer V1.0.21.1

> **Windows 系统事件日志导出 · 智能诊断 · 自主修复引擎**
>
> *AURORA VelociRaptor-GR Dev PRJ.*

---

## 项目概述

AURORA Analyzer 是一套面向 Windows 系统的全方位事件日志分析、智能诊断与自主修复工具链。它能够从 Windows Event Log 中导出高危事件（Critical / Error / Warning），生成结构化报告（CSV / JSON / XML / TXT），并基于本地知识图谱进行模式碰撞匹配，自动给出可执行的修复指令。

项目采用 **PowerShell 5.1 + C# 内联编译** 混合架构，所有组件均为单文件自包含设计，通过同步哈希表（`syncHash`）实现跨 Runspace 的实时进程间通信。

---

## 架构概览

```
┌──────────────────────────────────────────────────────────┐
│               AURORA.Launcher-双击启动.exe               │
│          (C# 编译的 Windowless EXE 启动器)               │
│          SHA256 完整性校验 + AES-256-CBC 解密验证        │
└─────────────────────┬────────────────────────────────────┘
                      │ 环境变量 AURORA_LAUNCHED_BY_EXE=1
                      ▼
┌──────────────────────────────────────────────────────────┐
│          ExportSystemEventLauncherGUI.ps1                 │
│          (WinForms GUI 主控制器, ~10K 行)                 │
│  · 硬件性能分级探针 (AuroraPerfTier)                     │
│  · 密码验证入口 (GAURORA.CHK.ENC AES-256解密)            │
│  · C# 内联编译自定义控件 (AuroraProgressBar/TechButton)  │
│  · 粒子动画引擎 / 星空背景 / 动态光晕                    │
│  · 会话恢复 (AuroraRestoreModal)                         │
│  · 授权决策模态框 (AuroraDecisionModal)                  │
│  · Runspace 子线程任务调度                               │
└──┬──────────────┬──────────────────┬─────────────────────┘
   │              │                  │
   ▼              ▼                  ▼
┌──────────┐ ┌──────────┐ ┌────────────────────────┐
│ CHSPro   │ │ ENGPro   │ │  AURORA-SmartEngine    │
│ .ps1     │ │ .ps1     │ │  .ps1 (V3.1)           │
│ ~=英文版 │ │          │ │  4-Phase 诊断管线       │
└────┬─────┘ └────┬─────┘ └───────────┬────────────┘
     │            │                   │
     └────────────┼───────────────────┘
                  │
     ┌────────────┼────────────┐
     ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────────────┐
│Progress  │ │Integr    │ │AURORA-TechData   │
│Manager   │ │-CHS/ENG  │ │.json (V3.0)      │
│.ps1      │ │.ps1      │ │6类诊断规则库     │
└──────────┘ └──────────┘ └──────────────────┘
```

---

## 模块详解

### 1. ExportSystemEventLauncherGUI.ps1（GUI 主控制器）

**版本**: V19.1Release | **行数**: ~40,000

#### 启动流程

| 步骤 | 功能 | 技术实现 |
|------|------|----------|
| ① | 硬件性能探针 | `Get-CimInstance Win32_Processor / Win32_ComputerSystem`，算力加权评分 |
| ② | 密码验证 | AES-256-CBC 解密 `GAURORA.CHK.ENC`，SHA256 密钥派生 |
| ③ | C# 控件编译 | `Add-Type` 内联编译 AuroraProgressBar、TechButton 等自定义控件 |
| ④ | GUI 窗体构建 | WinForms 无边框窗口，DPI 感知，Win32 API 拖拽支持 |
| ⑤ | 用户交互 | 日志类型选择、日期范围、导出模式、趋势分析开关 |

#### 硬件性能分级 (`AuroraPerfTier`)

```powershell
$perfScore = ($logicalCores × 15) + ($ramGB × 5) + max(0, (baseClock - 2000) / 100)
```

| 级别 | 评分 | 配置 | 渲染特性 |
|------|------|------|----------|
| **Extreme** | ≥240 | 8核+ 32G+ | 600星 / 150粒子 / 复杂光晕 / 动态扫描 |
| **Performance** | ≥120 | 6核 16G | 350星 / 80粒子 / 光晕开启 / 动态扫描 |
| **Balanced** | ≥70 | 4核 8G | 180星 / 30粒子 / 阴影开启 |
| **Eco** | <70 | 老旧设备 | 80星 / 无粒子 / 基础模式 |

#### C# 内联自定义控件

| 控件 | 功能 |
|------|------|
| `AuroraProgressBar` | 圆角渐变进度条，带光晕扫描动画与粒子系统 |
| `TechButton` | 科技风格动态按钮 |
| `AuroraRenderEngine` | 静态渲染引擎，根据硬件等级预计算 FPS/粒子数等参数 |
| `AuroraPrivilegeIndicator` | 管理员权限状态指示器 |
| `AuroraTaskHUD` | 实时任务执行平视显示器（管道步骤可视化） |
| `AuroraResultModal` | 命令执行结果模态弹窗 |
| `AuroraDecisionModal` | 高危操作授权决策弹窗 |
| `AuroraRestoreModal` | 未完成会话恢复弹窗 |
| `AuroraConsoleBox` | 嵌入式控制台输出框（智能日志回显） |
| `AuroraInputBox` | 用户指令输入框 |

#### 动画系统

- **光晕扫描**: UWP 风格循环速度逻辑（奇偶循环变速）
- **粒子系统**: 随机生成生命周期 1~2.5 秒的发光粒子，带布朗漂移
- **星空背景**: 根据性能等级生成不同数量的随机星空粒子
- **动态 FPS**: `1000 / TargetFPS` 自适应定时器间隔

---

### 2. ExportSystemEventLogsCHSPro.ps1 / ExportSystemEventLogsENGPro.ps1（PRO 导出引擎）

**版本**: V12.1Release | **语言**: 中文版 / 英文版（架构完全对称）

#### 参数体系

```powershell
Param(
    [string]$OutputPath,        # 输出目录（默认: .\UserLogs）
    [switch]$AutoOpen,          # 导出后自动打开文件夹
    [ValidateSet("System","Application","Security","Setup",
                 "DNS Server","DHCP Server","Directory Service",
                 "IIS Admin Service")]
    [string]$LogType = "System",# 日志类型
    [switch]$Silent,            # 静默模式
    [string]$EventId,           # 事件ID过滤
    [string]$ProviderName,      # 事件源过滤
    [ValidateSet("Critical","Error","Warning","Information","Verbose")]
    [string]$Level,             # 级别过滤
    [datetime]$StartTime,       # 起始时间
    [datetime]$EndTime,         # 结束时间
    [switch]$ForceRescan,       # 强制重新扫描
    [ValidateSet("SingleDay","DateRange")]
    [string]$ExportMode,        # 导出模式（单日/日期范围）
    [ValidateSet("HighRiskOnly","Full")]
    [string]$ExportScope,       # 导出范围（仅高危/完整）
    [switch]$TrendAnalysis,     # 趋势分析
    [switch]$GUI_Mode           # GUI 模式标识
)
```

#### 函数清单（39 个关键函数）

**会话与状态管理**
| 函数 | 功能 |
|------|------|
| `Save-ProgressSafe` | 安全保存进度（GUI同步 + 会话持久化） |
| `Write-AuroraLog` | 日志写入（双通道：控制台 + GUI syncHash） |
| `Get-AuroraInteraction` | GUI 交互输入（挂起等待用户输入） |

**权限管理**
| 函数 | 功能 |
|------|------|
| `Test-AdminRequired` | 判断日志类型是否需要管理员权限 |
| `Invoke-ElevationCheck` | 按需 UAC 提权（GUI 模式通过 syncHash 请求授权） |

**文件与 I/O**
| 函数 | 功能 |
|------|------|
| `New-StreamWriterOperation` | 线程安全文件写入（带重试机制） |
| `Get-SafeFilePath` | 路径安全化处理（非法字符替换） |
| `Optimize-FileOperations` | 并行文件操作优化 |

**性能评估与资源调度**
| 函数 | 功能 |
|------|------|
| `Get-ResourceOptimizedStrategy` | 基于系统资源的自适应策略计算 |
| `Get-IntelligentCacheStrategy` | 智能缓存策略（新鲜度 + 命中率计算） |
| `Get-DiskPerformance` | 磁盘 I/O 性能评估 |
| `Get-SystemPerformanceScore` | 综合性能评分（CPU + 内存 + 磁盘 I/O） |
| `Get-OptimalChunkSize` | 动态分块大小计算 |
| `Get-OptimalParallelism` | 动态并行度计算 |
| `Get-SystemLoad` | CPU/内存当前负载监测 |
| `Get-MemoryUsage` | 进程内存使用量统计 |

**缓存系统**
| 函数 | 功能 |
|------|------|
| `Test-CacheMatch` | 缓存命中测试（日志类型 + 时间范围 + 筛选器） |
| `Show-CacheInfo` | 缓存文件信息展示 |
| `Get-CacheUsageChoice` | 用户缓存使用决策交互 |
| `Test-CacheIntegrity` | 缓存完整性校验 |
| `Initialize-Cache` | 缓存目录初始化 |
| `Get-CacheKey` | 缓存键生成 |
| `Get-CachedLogData` | 缓存数据读取 |
| `Set-CachedLogData` | 缓存数据写入 |
| `Clear-LogCache` | 缓存清理 |
| `Get-OptimalCacheSize` | 基于系统资源的动态缓存大小 |

**数据压缩**
| 函数 | 功能 |
|------|------|
| `Compress-Data` | 数据压缩（内存流） |
| `Expand-CompressedData` | 压缩数据解压 |

**知识图谱引擎**
| 函数 | 功能 |
|------|------|
| `Load-KnowledgeBase` | 加载 AURORA-TechData.json |
| `New-KnowledgeBaseIndex` | 构建预编译索引（EventID / Source / Keyword 三维） |
| `Get-KnowledgeBaseSolution` | 单事件→解决方案映射（含 SHA256 缓存键） |
| `Get-LocalizedKnowledgeBaseSolution` | 本地化解决方案查询 |
| `Get-LocalizedKnowledgeBaseSolutions` | 批量本地化查询 |
| `Get-KnowledgeBasePriority` | 获取事件修复优先级 |
| `Get-BatchKnowledgeBaseSolutions` | 批量 Runspace 并发知识图谱匹配 |
| `Get-BatchKnowledgeBasePriorities` | 批量优先级计算 |

**日志分析与报告**
| 函数 | 功能 |
|------|------|
| `Get-HighRiskEvents` | 高危事件扫描（含 Runspace 多线程分块） |
| `Get-FullSystemLog` | 完整系统日志拉取 |
| `New-LogReport` | 摘要/趋势分析报告生成 |
| `New-AdvancedLogPatternAnalysis` | 高级日志模式识别 |
| `New-LogTrendAnalysis` | 日志趋势分析（事件频率时序） |
| `Write-CustomProgress` | 自定义进度显示 |

**对象池（内存优化）**
| 函数 | 功能 |
|------|------|
| `New-ObjectPool` | 创建类型化对象池 |
| `Get-ObjectFromPool` | 从池中获取对象 |
| `Return-ObjectToPool` | 归还对象到池 |
| `Clear-ObjectPool` | 清空对象池 |
| `Get-ObjectPoolStatus` | 对象池状态查询 |

#### 输出产物（每种日志类型）

| 文件 | 格式 | 说明 |
|------|------|------|
| `{LogType}_Log_{Date}.csv` | CSV (BOM UTF-8) | 原始事件数据 |
| `{LogType}_Log_{Date}.json` | JSON | 结构化事件数据 |
| `{LogType}_Log_{Date}.xml` | XML | 标准事件日志 XML |
| `{LogType}_Log_{Date}_Summary.txt` | 纯文本 | 结构化摘要报告 |
| `{LogType}_Log_{Date}_TrendAnalysis.txt` | 纯文本 | 趋势分析报告 |
| `{LogType}_Log_{Date}_TrendData.csv` | CSV | 趋势原始数据 |

---

### 3. AURORA-SmartEngine.ps1（智能诊断引擎）

**版本**: V3.1 Smart Release | **语言**: 双语（CHS/ENG）| **行数**: ~1,035

#### 4 阶段诊断管线

```
Phase 1: 侦测系统生命体征
  ├── OS 信息提取
  ├── 运行时间计算
  ├── 硬崩溃溯源 (EventID 41/6008)
  ├── 时间窗口智能决策
  │   ├── 48H 内崩溃 → 精准锁定期前 2H
  │   ├── <2H 开机 → 前推 4H 启动校验
  │   └── 稳定运行 → 常规 24H 巡检
  └── Minidump 蓝屏转储探测

Phase 2: 并发提取异常日志
  ├── PRO 模式 CSV 导入（废弃时间窗口过滤）
  ├── 实时 Get-WinEvent 提取（Level 1/2/3）
  ├── 日志类型检测报告
  ├── 缺失日志警告
  └── 内存轻量化（只保留 Id/ProviderName/Message）

Phase 3: 知识图谱靶向碰撞
  ├── JSON 图谱装载
  ├── 多态 Source（数组/字符串兼容）
  ├── 预编译 Regex（IgnoreCase）
  ├── O(n×m) 极速匹配: EventID → Source → Keywords
  └── 按 Priority 降序排列

Phase 4: 智能自主修复与交互终端
  ├── 安全沙箱执行器 (Invoke-AuroraSafeAction)
  │   ├── Step 0: 前置检查 (Pre-Check)
  │   ├── Step 1: 权限检测 (Admin Elevation Check)
  │   ├── Step 2: 风险评估与授权 (Risk Assessment + User Auth)
  │   └── Step 3: 命令执行 (PowerShell/CMD 双通道)
  │       ├── 普通 CMD → Process Start (捕获 stdout/stderr)
  │       ├── 特殊命令 (ms-settings:/cpl/msc/mdsched) → Start-Process
  │       └── ExitCode 检查
  ├── Step 4: 失败回滚 (Rollback on Failure)
  ├── 交互菜单持久化（syncHash.FullMenuText 缓存）
  └── GUI 命令循环监听（syncHash.UserInput）
```

#### `Invoke-AuroraSafeAction` 安全沙箱执行器

```
执行流程:
  ┌──────────────────────────────────────┐
  │ 0. 清空授权状态                       │
  └──────────────────────────────────────┘
              │
              ▼
  ┌──────────────────────────────────────┐
  │ 1. 前置检查 (pre_check)              │
  │    · 管理员权限检测                   │
  │    · 自定义前置条件脚本执行            │
  │    · 若未提供 → 直接通过              │
  └──────────────────────────────────────┘
              │
              ▼
  ┌──────────────────────────────────────┐
  │ 2. 风险评估与授权                    │
  │    · auto_execute=true → 跳过        │
  │    · auto_execute=false → 设置       │
  │      syncHash.RequiresAuthorization  │
  │      等待 GUI 用户确认 (30s超时)     │
  └──────────────────────────────────────┘
              │
              ▼
  ┌──────────────────────────────────────┐
  │ 3. 命令执行                          │
  │    · type="powershell" → Invoke-Expr │
  │    · type="cmd" → Process Start      │
  │    · 捕获 stdout/stderr + ExitCode   │
  │    · 权限错误特殊处理 (740)          │
  │    · 输出截断显示 (≤10行)            │
  └──────────────────────────────────────┘
              │
              ▼
  ┌──────────────────────────────────────┐
  │ 4. 失败回滚 (Command.rollback)      │
  │    · 执行回滚脚本                    │
  │    · 回滚超时 + 输出展示             │
  └──────────────────────────────────────┘
```

#### PRO 模式数据传递

Smart Engine 支持从 PRO 引擎直接接收已导出的日志路径，在 Phase 2 中优先从 CSV 文件加载事件数据，避免重复的 `Get-WinEvent` 调用。关键参数：

- `-FromPRO`: 标记从 PRO 模式调用
- `-ExportedLogPath`: PRO 导出的 `UserLogs` 目录路径
- CSV 字段映射: `TimeCreated` → 事件时间, `LevelDisplayName` → 级别编号（支持中英文）

---

### 4. AURORA-ProgressManager.ps1（会话持久化系统）

**版本**: V3.1 Smart Release | **语言**: 双语支持

#### 缓存目录结构

```
SessionCache/
├── active/          ← 当前活动会话 JSON
├── checkpoints/     ← 检查点备份 JSON
└── archive/         ← 已完成会话归档 JSON（30天自动清理）
```

#### 降级策略

```
工具目录可写？
  ├── YES → SessionCache\ (工具目录)
  └── NO  → %TEMP%\AURORA_Sessions\ (降级方案)
```

#### 函数接口

| 函数 | 签名 | 说明 |
|------|------|------|
| `Initialize-CacheDirectory` | `(ToolPath) → bool` | 初始化缓存目录结构，含写入权限测试 |
| `New-Session` | `(SessionType, Metadata) → SessionId` | 创建 `SESSION_yyyyMMdd_HHmmss_xxxx` |
| `Save-SessionProgress` | `(SessionId, Stage, Progress, Data, -CreateCheckpoint)` | 保存进度（重试机制 + StreamWriter 原子写入） |
| `Restore-SessionProgress` | `(SessionId?) → hashtable` | 恢复会话（自动查找最新未完成会话，7天过期） |
| `Remove-SessionProgress` | `(SessionId, -Archive)` | 删除/归档会话（含检查点清理） |
| `Complete-Session` | `(SessionId, -Archive)` | 标记 100% 完成，清理 null/空值字段 |
| `Get-LatestPendingSession` | `() → SessionId` | 查找最新未完成会话（Status=Active 或 Progress<100） |
| `Test-PendingSession` | `() → bool` | 是否存在待恢复会话 |
| `Invoke-CacheCleanup` | `(RetentionDays=7) → cleanedCount` | 清理过期（active/checkpoint 7天，archive 30天） |
| `Get-SessionStatistics` | `() → hashtable` | 获取缓存统计（会话数/检查点数/归档数/总大小） |
| `Get-LocalizedString` | `(Key, args...) → string` | 双语本地化字符串（含占位符安全格式化） |

#### 文件 I/O 安全设计

- **重试机制**: 最多 3 次，指数退避（100ms × retryCount）
- **原子写入**: 先删除旧文件 → `File.Create()` → `StreamWriter` → `Flush()` → `Close()`
- **安全读取**: `File.Open(Read)` → `StreamReader` → `ReadToEnd()`
- **编码**: UTF-8 No-BOM (`System.Text.UTF8Encoding($false)`)

---

### 5. AURORA-ProgressManager-Integration-CHS.ps1 / -ENG.ps1（集成层）

定义了 16 个关键检查点，覆盖 PRO 引擎从初始化到任务完成的全部阶段：

| 检查点 | 进度 | 阶段描述 |
|--------|------|----------|
| `Initialized` | 5% | 脚本初始化完成 |
| `LogTypeSelected` | 10% | 日志类型已选择 |
| `DateRangeConfigured` | 15% | 日期范围已配置 |
| `PerformanceAssessed` | 25% | 性能评估完成 |
| `ProcessingStarted` | 45% | 开始处理日志文件 |
| `HighRiskScanComplete` | 60% | 高危事件扫描完成 |
| `HealthAssessmentComplete` | 70% | 系统健康评估完成 |
| `ExportModeSelected` | 75% | 导出模式已选择 |
| `FetchingFullLog` | 75% | 正在获取完整日志 |
| `FullLogFetched` | 80% | 完整日志已获取 |
| `ExportStarted` | 85% | 正在导出日志 |
| `ExportComplete` | 90% | 所有日志导出完成 |
| `TrendAnalysisComplete` | 93% | 趋势分析完成 |
| `SmartAnalysisPending` | 95% | 等待智能分析 |
| `SmartAnalysisComplete` | 98% | 智能分析完成 |
| `Completed` | 100% | 任务完成 |

---

### 6. AURORA-TechData.json（知识图谱）

**版本**: V3.0 | **规则数**: 6 大类 × N 条规则

#### 分类体系

| ID | 中文名 | English | 典型规则 |
|----|--------|---------|----------|
| **A** | 系统稳定性 | System Stability | Event 41 意外关机、1001 蓝屏、1000 程序崩溃、1026 .NET 异常、7 磁盘错误、6008 非正常关机、100 启动缓慢 |
| **B** | 驱动与硬件 | Drivers & Hardware | Event 14 显卡驱动超时(TDR)、15 驱动未加载 |
| **C** | 网络与通信 | Network & Communication | Event 1002 DHCP IP 获取失败、1014 DNS 名称解析超时、2004 资源耗尽 |
| **D** | Windows 更新与安装 | Windows Update & Installation | Event 10004 更新失败、20 安装失败 |
| **E** | 安全与身份 | Security & Identity | Event 4625 登录失败（暴力破解检测） |
| **F** | 应用与服务 | Applications & Services | Event 371 打印后台处理程序错误 |

#### 规则结构

```json
{
  "rule_id": "A-001",
  "name": "意外关机/内核电源错误",
  "name_en": "Unexpected Shutdown/Kernel Power Error",
  "event_ids": [41],
  "source": "Kernel-Power",
  "message_keywords": ["bugcheck", "unexpectedly", "shutdown"],
  "severity": "Critical",
  "description": "...",
  "description_en": "...",
  "causes": [...],
  "causes_en": [...],
  "solutions": [...],
  "solutions_en": [...],
  "recommended_action": "...",
  "recommended_action_en": "...",
  "priority": 100,
  "applies_to": ["Windows 10", "Windows 11", "Windows Server 2016+"],
  "commands": [
    {
      "name": "运行系统文件检查器",
      "name_en": "Run System File Checker",
      "command": "sfc /scannow",
      "type": "cmd",
      "elevation_required": true,
      "risk_level": "Low",
      "auto_execute": false,
      "pre_check": "$true",
      "rollback_command": ""
    }
  ]
}
```

#### Smart Engine 图谱预处理

在 Phase 3 中，Smart Engine 会对图谱做三件事：
1. **展平化**: 多层嵌套 JSON → 1D `$flatRules` 数组
2. **多态兼容**: `source` 字段兼容 string/array 两种格式
3. **预编译**: `[regex]::new()` 预编译所有 keywords，`RegexOptions::IgnoreCase`

---

### 7. build.ps1 + AURORA-build.bat（安全分发构建系统）

#### 构建管线

```
[0/5] 检查必需文件 (8个文件完整性验证)
  ↓
[1/5] 计算 SHA256 哈希 (所有必需文件的 SHA256)
  ↓
[2/5] 生成明文校验文件 (ANSI No-BOM)
  ├── 文件哈希列表
  └── PASSWORD_HASH=Base64(SHA256)
  ↓
[3/5] AES-256-CBC 加密 (随机 IV)
  ├── 密钥 = SHA256(主密码)
  └── 输出: GAURORA.CHK.ENC (Base64)
  ↓
[4/5] 解密验证 (保证加密/解密一致性)
  ↓
[5/5] C# 源码生成 → csc.exe 编译
  ├── 嵌入 Base64 密钥 → AuroraLauncher.cs
  ├── /target:winexe (无控制台窗口)
  ├── /platform:x86
  ├── /win32icon:AURORAICON.ico
  └── 输出: AURORA.Launcher-双击启动.exe
  ↓
[可选] ZIP 发布包打包 → Releases\AURORA_Analyzer_vX.X_Release.zip
```

#### 分发文件清单

| 文件 | 说明 |
|------|------|
| `AURORA.Launcher-双击启动.exe` | 主可执行文件（C# Windowless EXE） |
| `ExportSystemEventLauncherGUI.ps1` | GUI 主控制器 |
| `ExportSystemEventLogsCHSPro.ps1` | PRO 中文导出引擎 |
| `ExportSystemEventLogsENGPro.ps1` | PRO 英文导出引擎 |
| `AURORA-SmartEngine.ps1` | 智能诊断修复引擎 |
| `AURORA-TechData.json` | 诊断知识图谱 |
| `AURORA-ProgressManager.ps1` | 会话持久化系统 |
| `AURORA-ProgressManager-Integration-CHS.ps1` | 中文集成层 |
| `AURORA-ProgressManager-Integration-ENG.ps1` | 英文集成层 |
| `GAURORA.CHK.ENC` | 加密完整性校验文件 |

---

## 技术特性总结

### 并发与性能

| 特性 | 实现 |
|------|------|
| Runspace 多线程 | PowerShell RunspacePool，主线程 ↔ 子线程通过 `[hashtable]::Synchronized(@{})` 通信 |
| 动态分块 | `Get-OptimalChunkSize` 基于 CPU 核心数和内存容量自适应 |
| 动态并行度 | `Get-OptimalParallelism` 基于 CPU 核心数自适应 |
| 对象池 | `New-ObjectPool` / `Get-ObjectFromPool` / `Return-ObjectToPool` 减少 GC 压力 |
| 批量知识图谱匹配 | `Get-BatchKnowledgeBaseSolutions` Runspace 并发查询 |

### 安全与授权

| 特性 | 实现 |
|------|------|
| 文件完整性校验 | C# EXE 启动时 SHA256 校验所有必需文件 |
| 密码保护 | AES-256-CBC 加密校验文件，SHA256 密钥派生 |
| 管理员权限按需提权 | GUI 通过 syncHash 请求 → 用户决策 → 重启提权 |
| 高危操作授权 | `AuroraDecisionModal` 全息弹窗，用户逐项确认 |
| 风险等级标注 | 每条命令标注 `risk_level`: Low / Medium / High |

### GUI 渲染

| 特性 | 实现 |
|------|------|
| 自适应性能等级 | 4 级配置 (Eco/Balanced/Performance/Extreme) |
| C# 内联编译控件 | PowerShell `Add-Type -TypeDefinition` 直接编译 C# 类 |
| 粒子动画系统 | `List<Particle>` 每帧 Age/LifeTime/X/Y 更新 |
| 光晕扫描动画 | PathGradientBrush 动态位置 + UWP 风格变速逻辑 |
| 星空背景 | 随机生成+生命周期+透明度渐变 |

### 容错与恢复

| 特性 | 实现 |
|------|------|
| 会话断点续传 | ProgressManager 保存所有 16 个检查点状态 |
| 文件写入重试 | 最多 3 次 + 指数退避延迟 |
| 缓存降级 | 工具目录不可写 → TEMP 降级 |
| 回滚机制 | 命令执行失败 → 自动执行 `rollback_command` |
| 会话过期清理 | Active/Checkpoint 7 天，Archive 30 天 |

---

## 系统要求

| 项目 | 最低要求 |
|------|----------|
| 操作系统 | Windows 10 / Windows 11 / Windows Server 2016+ |
| PowerShell | 5.1+ |
| .NET Framework | 4.x（用于 C# 控件编译与 EXE 编译） |
| 权限 | 基础日志不需要管理员；Security/Setup/DNS/DHCP 等需要 |
| 内存 | ≥ 4GB（Eco 级别）；≥ 8GB 推荐（Balanced+） |

---

## 项目结构

### 发布版本目录结构 (v0.21.1+)

```
ExportSystemEvent - Factory/
├──  Scripts/                          # 核心脚本目录
│   ├── ExportSystemEventLauncherGUI.ps1       # WinForms GUI 主控制器 (~40K 行)
│   ├── ExportSystemEventLogsCHSPro.ps1        # PRO 中文导出引擎
│   ├── ExportSystemEventLogsENGPro.ps1        # PRO 英文导出引擎
│   ├── AURORA-SmartEngine.ps1                 # 智能诊断与修复引擎
│   ├── AURORA-ProgressManager.ps1             # 会话持久化与断点续传
│   ├── AURORA-ProgressManager-Integration-CHS.ps1  # 中文进度集成
│   └── AURORA-ProgressManager-Integration-ENG.ps1  # 英文进度集成
├──  Data/                             # 数据文件目录
│   ├── AURORA-TechData.json                   # 诊断知识图谱 (6 大类规则)
│   └── version.txt                            # 版本文件
├── 📁 Resources/                        # 资源文件目录
│   ├── AURORAICON.ico                         # 应用图标
│   └── CascadiaMono.ttf                       # UI 字体
├── AURORA.Launcher-双击启动.exe          # C# Windowless EXE 启动器
├── GAURORA.CHK.ENC                        # AES-256 加密校验文件
├── desktop.ini                            # 文件夹个性化配置
├── build.ps1                              # 构建脚本 (6 步构建管线)
├── AURORA-build.bat                       # 构建批处理入口
├── SessionCache/                          # 会话缓存目录（运行时自动创建）
│   ├── active/
│   ├── checkpoints/
│   └── archive/
└── Releases/                              # 构建产物 (ZIP 发布包)
```

### 开发目录（仅开发环境）

```
ExportSystemEvent - Factory/
├── ... (以上发布文件)
├── test/                                  # 测试脚本
│   ├── Remove-BOM.ps1
│   ├── Test-Bilingual.ps1
│   ├── Test-ProgressManager*.ps1
│   └── Test-ProgressManager-Integration.ps1
├── Remove-BOM.ps1                         # UTF-8 BOM 管理工具
├── build.log                              # 构建日志
└── Task.txt                               # 开发备忘录
```

---

## 启动方式

```
方式 1（推荐）: 双击 AURORA.Launcher-双击启动.exe
方式 2: powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File Scripts\ExportSystemEventLauncherGUI.ps1
```

> 所有脚本均内置启动保护，禁止直接双击 `.ps1` 运行，强制通过 GUI 启动。

---

## 构建

```cmd
REM 使用当前版本构建
AURORA-build.bat /generate

REM 递增版本并构建
build.ps1 -IncrementVersion
```

构建产物：
- `AURORA.Launcher-双击启动.exe`（嵌入密钥的 Windowless EXE）
- `GAURORA.CHK.ENC`（AES-256-CBC 加密校验文件）
- `Releases\AURORA_Analyzer_vX.X_Release.zip`（可选）

---

## 许可

本工具仅用于个人学习使用。

---

*© 2026 AURORA VelociRaptor-GR Dev PRJ. | Version 1.0.21.1 | Build 2026.05.09*
