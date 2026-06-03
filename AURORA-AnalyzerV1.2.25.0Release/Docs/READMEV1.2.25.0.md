# AURORA Analyzer V1.2.25.0Release — 技术文档

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
- [4. GUI 动效引擎架构](#4-gui-动效引擎架构)
  - [4.1 动画核心引擎](#41-动画核心引擎)
  - [4.2 缓动系统详解](#42-缓动系统详解)
  - [4.3 自定义控件层](#43-自定义控件层)
- [5. v1.2.25.0 动效系统升级详解](#5-v12250-动效系统升级详解)
  - [5.1 缓动函数库扩展](#51-缓动函数库扩展)
  - [5.2 动态帧率适配修复](#52-动态帧率适配修复)
  - [5.3 涟漪动画系统](#53-涟漪动画系统)
  - [5.4 磁吸交互系统](#54-磁吸交互系统)
  - [5.5 进度条平滑过渡](#55-进度条平滑过渡)
- [6. 反调试与反分析技术栈](#6-反调试与反分析技术栈)
- [7. 构建系统](#7-构建系统)
- [8. 攻击面分析](#8-攻击面分析)
- [9. 贡献指南](#9-贡献指南)

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
│  - 看门狗客户端 + Runspace                  │
│  - 性能分级引擎 + 动画引擎                   │
│  - TechButton / AuroraProgressBar /       │
│    StarfieldPanel 等自定义控件              │
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
| 动效引擎 | 内嵌 C# (Add-Type 编译为 DLL) | .NET Framework 4.x |

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

### 3.2 EXE 看门狗双工通信

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

## 4. GUI 动效引擎架构

### 4.1 动画核心引擎

**实现位置**: [Core\AURORA-AnimationCoreEngine.ps1](file:///e%3A/PC%20SOFT/%E4%BC%98%E5%8C%96%E8%BD%AF%E4%BB%B6/PowerShellBat/AURORA-Analyzer/AURORA-Analyzer-Factory/Scripts/Core/AURORA-AnimationCoreEngine.ps1)

**架构图**:

```
┌───────────────────────────────────────────────────────────┐
│                  应用层 (PowerShell)                       │
│  ┌──────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  TechButton  │  │ AuroraProgressBar│  │StarfieldPanel│ │
│  └──────────────┘  └─────────────────┘  └──────────────┘ │
└───────────────────────────────────────────────────────────┘
                            ↓
┌───────────────────────────────────────────────────────────┐
│         动画引擎层 (AURORA-AnimationCoreEngine)              │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  AURORA_Animation (静态门面)  ─→  AnimationManager  │  │
│  │  ├── FloatAnimation (数值插值)                      │  │
│  │  ├── GlareSweepAnimation (扫光)                     │  │
│  │  ├── ModalTimerAnimation (模态框)                   │  │
│  │  └── LoopAnimation (循环)                           │  │
│  └─────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────┐  │
│  │        AuroraRenderEngine (性能分级配置 + FPS 控制)    │  │
│  └─────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────┘
                            ↓
┌───────────────────────────────────────────────────────────┐
│                  渲染层 (GDI+ / WinForms)                   │
│  ┌──────────────┐  ┌───────────────┐  ┌────────────────┐ │
│  │ DoubleBuffer │  │PathGradient   │  │LinearGradient  │ │
│  └──────────────┘  └───────────────┘  └────────────────┘ │
└───────────────────────────────────────────────────────────┘
```

**核心类与接口**:

| 类型 | 角色 | 说明 |
|------|------|------|
| `AuroraRenderEngine` | 静态配置类 | 性能分级参数、FPS 控制 |
| `AnimationManager` | 调度器 | Timer 驱动的动画循环，管理动画生命周期 |
| `Animation` (abstract) | 基类 | 所有动画的抽象基类，定义 `Update()` 模板方法 |
| `FloatAnimation` | 数值动画 | 支持 20 种缓动的浮点值插值动画 |
| `GlareSweepAnimation` | 扫光动画 | 基于 IAnimatable 接口的专用扫光 |
| `ModalTimerAnimation` | 模态框动画 | 无限循环的模态框淡入淡出 |
| `LoopAnimation` | 循环动画 | 通用无限循环动画（涟漪、磁吸等） |
| `IAnimatable` | 接口 | 控件与动画引擎的解耦接口 |
| `AURORA_Animation` | 门面类 | 单例模式的静态门面，简化 API 调用 |

**性能分级系统** (`AuroraRenderEngine`):

硬件检测算法:
```powershell
$perfScore = ($logicalCores * 15) + ($ramGB * 5) + ([Math]::Max(0, ($baseClock - 2000) / 100))
```

| 评分阈值 | 性能等级 | TargetFPS | StarCount | ParticleCount | 特效级别 |
|---------|---------|-----------|-----------|---------------|---------|
| >= 240 | Extreme | 60 | 600 | 150 | 全特效 |
| >= 120 | Performance | 60 | 350 | 80 | 高特效 |
| >= 70 | Balanced | 60 | 180 | 30 | 中特效 |
| < 70 | Eco | 30 | 80 | 0 | 最小特效 |

### 4.2 缓动系统详解

**EasingType 枚举（20 种）**:

| 分组 | 成员 | 数学特征 |
|------|------|---------|
| Linear | Linear | `f(t) = t` |
| Cubic | EaseIn / Out / InOut | `f(t) = t³` 变体 |
| Quad | EaseIn / Out / InOut | `f(t) = t²` 变体 |
| Quart | EaseIn / Out / InOut | `f(t) = t⁴` 变体 |
| Quint | EaseIn / Out / InOut | `f(t) = t⁵` 变体 |
| Elastic | EaseIn / Out / InOut | 指数衰减正弦函数 |
| Bounce | EaseIn / Out / InOut | 分段二次弹跳函数 |

**Bounce 辅助函数**:

```csharp
private static float EaseOutBounceHelper(float t)
{
    float n1 = 7.5625f;
    float d1 = 2.75f;
    if (t < 1f / d1) return n1 * t * t;
    else if (t < 2f / d1) return n1 * (t -= 1.5f / d1) * t + 0.75f;
    else if (t < 2.5f / d1) return n1 * (t -= 2.25f / d1) * t + 0.9375f;
    else return n1 * (t -= 2.625f / d1) * t + 0.984375f;
}
```

**Elastic 实现原理**:

```csharp
// EaseOutElastic
float p = 0.3f;        // 周期
float s = p / 4f;      // 相位偏移
easedProgress = (float)Math.Pow(2, -10 * progress) 
              * (float)Math.Sin((progress - s) * (2 * Math.PI) / p) + 1;
```

### 4.3 自定义控件层

**TechButton — 动态科技按钮**:

| 属性 | 动画范围 | 动画时长 | 缓动类型 |
|------|---------|---------|---------|
| `_hoverProgress` | 0→1 | 300ms | EaseOutCubic |
| `_glowProgress` | 0→1 | 300ms | EaseOutCubic |
| `_pressProgress` | 0→1 | 200ms | EaseOutCubic |
| `_glareProgress` | -0.3→1.3 | 1500ms | EaseOutCubic |
| `_ripples[]` (V1.2 新增) | 动态 | 持续 | 渐近式扩展 |
| `_magneticOffsetX/Y` (V1.2 新增) | 0→±17.5px | 实时 | `MAGNETIC_SMOOTH` |

**9 层绘制结构**:

| 层级 | 绘制内容 | 技术 |
|------|---------|------|
| 1 | 外部光晕 | PathGradientBrush |
| 2 | 阴影 | PathGradientBrush |
| 3 | 主体渐变背景 | LinearGradientBrush |
| 4 | 扫光 | PathGradientBrush |
| 5 | 边框 | Pen |
| 6 | 内发光 | PathGradientBrush |
| 7 | 按下阴影 | PathGradientBrush |
| 8 | 文本 | DrawString |
| 9 | **涟漪** (V1.2 新增) | SolidBrush 圆形 |

**AuroraProgressBar — 粒子进度条**:

UWP 风格光晕扫描 + 粒子系统 + 平滑进度过渡。粒子参数: 最大 40 个，寿命 1.0~2.5 秒，漂移速度 ±0.2px/帧。

**StarfieldPanel — 电影感星空背景**:

- 80-600 颗星星 (性能分级)，带电影感飞入动画和超新星爆发效果
- 鼠标交互光晕 (60px 感应范围)
- 动态流星生成 (0.009 概率/帧，12 点尾迹)
- 深空背景粒子 (边缘→中心移动)

---

## 5. v1.2.25.0 动效系统升级详解

### 5.1 缓动函数库扩展

**变更详情**: 缓动函数从 4 种 Cubic 曲线扩展到 20 种，新增 Quad、Quart、Quint、Elastic、Bounce 全系列。

**FloatAnimation.Update() 的 switch 分支**: 从 ~25 行扩展到 ~100 行，新增 3 处 BounceHelper 调用。

**设计考量**:
- 保持默认缓动类型为 `EaseOutCubic`，确保向后兼容
- EaseOutBounceHelper 使用经典分段二次函数 (n1=7.5625, d1=2.75)，与行业标准一致
- Elastic 缓动使用标准指数衰减正弦复合函数，参数源自 CSS `cubic-bezier` 常用配置

### 5.2 动态帧率适配修复

**问题根因**: V1.1.24.5 中 `AnimationManager` 构造函数硬编码了 `Interval = 16`，导致 Eco 模式下 `GetTimerInterval()` 返回的 33ms (30FPS) 形同虚设。

**修复**: 将 `new Timer { Interval = 16 }` 改为 `new Timer { Interval = AuroraRenderEngine.GetTimerInterval() }`

**性能影响**:

| 模式 | 修复前 | 修复后 | CPU 节省 |
|------|--------|--------|---------|
| Eco | 16ms/tick (60FPS) | 33ms/tick (30FPS) | ~50% |
| Balanced+ | 16ms/tick (60FPS) | 16ms/tick (60FPS) | 0% |

这是本次升级中**代码改动最小但实际收益最大**的修复，仅一行代码变更。

### 5.3 涟漪动画系统

**新增 Ripple 类** (TechButton 内部私有类):

```csharp
private class Ripple
{
    public PointF Origin;
    public float Radius;
    public float MaxRadius;
    public float Alpha;
    public bool IsDead;
    
    public void Update(float deltaTime)
    {
        this.Radius += (this.MaxRadius - this.Radius) * 0.15f;
        this.Alpha -= 0.03f;
        if (this.Alpha <= 0f || this.Radius >= this.MaxRadius * 0.95f)
            this.IsDead = true;
    }
}
```

**生命周期**:
1. 用户点击 → OnMouseClick 创建 Ripple 实例 → 添加到 `_ripples` 列表
2. LoopAnimation 每帧更新所有涟漪 → 渐近式半径扩展 + 透明度衰减
3. 满足死亡条件 → 从列表移除
4. Active 涟漪数量 > 0 → 触发 Invalidate() → OnPaint 第 9 层绘制

**绘制**: 使用 `Color.FromArgb((int)(ripple.Alpha * 80), 200, 255, 255)` 青色半透明实心圆形，以涟漪 Origin 为中心，Radius 为半径。

### 5.4 磁吸交互系统

**磁吸参数**:

```csharp
const float MAGNETIC_RADIUS   = 135f;   // 感应半径
const float MAGNETIC_STRENGTH = 0.35f;  // 磁力强度
const float MAGNETIC_SMOOTH   = 0.08f;  // 平滑插值系数
const float MAGNETIC_MAX_OFFSET = 17.5f;// 最大位移
```

**状态机设计**:

```
MouseMove (在感应半径内)
  → 计算方向向量 + 偏移大小
  → 渐进插值: offset += (target - offset) * MAGNETIC_SMOOTH
  → Location = baseLocation + offset

MouseMove (在感应半径外)
  → target = (0, 0)
  → 渐进归零

MouseLeave
  → 使用 FloatAnimation 动画归零
  → 防止突兀跳变

视图切换 (SetTransitionMode)
  → 立即强制归零
  → 保护布局系统不受干扰
```

**边界保护设计**:

OnLocationChanged 中检查磁吸偏移是否接近零才更新 `_baseLocation`:

```csharp
float currentMagOffset = (float)Math.Sqrt(
    _magneticOffsetX * _magneticOffsetX + 
    _magneticOffsetY * _magneticOffsetY);
if (currentMagOffset < 0.5f)
{
    _baseLocation = this.Location;
}
```

这个设计非常精巧：防止在磁吸归位动画过程中污染 `_baseLocation`，确保多次磁吸操作的基准点始终正确。

### 5.5 进度条平滑过渡

**核心变更**: 引入 `_displayProgress` 中间变量，实现从 `_value` 到渲染的平滑过渡。

```csharp
// UpdateAnimation() 中
float targetProgress = (_value - _minimum) / range;
_displayProgress += (targetProgress - _displayProgress) * 0.12f;
if (Math.Abs(diff) < 0.001f) _displayProgress = targetProgress; // 收敛后对齐

// OnPaint() 中
float progress = _displayProgress;  // 使用平滑值
```

**粒子同步**: 粒子生成条件从 `progress > 0` 改为 `_displayProgress > 0`，填充宽度从 `w * progress` 改为 `w * _displayProgress`，确保粒子效果与进度填充视觉完全同步。

---

## 6. 反调试与反分析技术栈

### 调试器 API 检测

| 检测方法 | API | 检测原理 |
|----------|-----|----------|
| IsDebuggerPresent | kernel32 | 读取 PEB.BeingDebugged 标志 |
| CheckRemoteDebuggerPresent | kernel32 | 同上，支持检查其他进程 |
| NtQueryInformationProcess(DebugPort) | ntdll | 进程调试端口非零表示被调试 |
| NtQueryInformationProcess(DebugFlags) | ntdll | DebugFlags 中第 0 位为 0 表示被调试 |
| NtQueryInformationProcess(HandleTracing) | ntdll | 句柄追踪计数异常高表示可疑活动 |

### 硬件断点检测

通过 `GetThreadContext` 读取 CPU 调试寄存器 (Dr0-Dr3)，检查是否非零。

**x64 CONTEXT 关键偏移**:

| 偏移 | 大小 | 字段 |
|------|------|------|
| 0x30 | 4 | ContextFlags |
| 0x48 | 8 | Dr0 |
| 0x50 | 8 | Dr1 |
| 0x58 | 8 | Dr2 |
| 0x60 | 8 | Dr3 |

### PEB 分析

NtGlobalFlag 标志组合 `0x70` 表示 `FLG_HEAP_ENABLE_TAIL_CHECK | FLG_HEAP_ENABLE_FREE_CHECK | FLG_HEAP_VALIDATE_PARAMETERS`，这些标志通常由调试器设置。

### 线程隐藏

`NtSetInformationThread(GetCurrentThread(), ThreadHideFromDebugger, 0, 0)` 使调试器无法接收该线程的调试事件。

---

## 7. 构建系统

### 构建命令

```powershell
# 标准构建
.\build.ps1

# 跳过签名（仅测试）
.\build.ps1 -SkipSigning
```

### 构建流程

```
build.ps1
  ├── 1. 令牌生成: SHA256 → PBKDF2 AES Key → AES-256-CBC 加密 → RSA 签名
  ├── 2. EXE 编译: CSharpCodeProvider → 嵌入 RSA 公钥/主密码/哈希表
  ├── 3. HMAC 密钥: PBKDF2(MasterPassword, WdHmacSalt, 10000) → 32 字节
  ├── 4. 启动 PS1 子进程 + 环境变量注入
  └── 5. 看门狗管道服务器循环
```

---

## 8. 攻击面分析

| 攻击向量 | 难度 | 已有缓解措施 |
|----------|------|-------------|
| 替换核心脚本 | 中 | SHA256 完整性验证 |
| 附加调试器 | 中 | 5 种 API 检测 + 硬件断点扫描 |
| DLL 注入 | 中 | 模块路径分析 |
| 篡改 Token 文件 | 高 | RSA-SHA256 签名 (需要私钥) |
| 重放旧 Token | 高 | 60 秒时效限制 |
| Hook ntdll | 高 | 硬件断点检测 + PEB 直接读取 |
| 修改内存中的 AuroraGuard | 高 | 看门狗双向 HMAC 心跳 |
| 进程替换 | 高 | 看门狗通过管道监控 PS1 存活 |

---

## 9. 贡献指南

**构建环境**:

```powershell
.\build.ps1
```

**代码规范**:

- C# 部分: .NET Framework 4.x, C# 5.0 语法 (兼容 PS1 的 Add-Type)
- PowerShell 部分: 兼容 Windows PowerShell 5.1
- 内嵌 C#: 使用 `@"..."@` here-string，显式指定 `-ReferencedAssemblies`
- 安全代码: 所有 Native API 调用必须有 try-catch 和 finally 资源释放

**调试方法**:

- 诊断日志: `%TEMP%\aurora_guard_diag.log`
- 动画 DLL: `Core\AURORA-AnimationCoreEngine.dll` (删除后自动重编译)
- 单独测试安全守卫: `[AuroraGuard]::GetDetectionReason()`

**更新完整性哈希**:

修改核心脚本后，需重新计算 SHA256 并更新 `_expected` 字典，推荐使用 build.ps1 自动完成。

**动效调试方法**:

- 删除 `Core\AURORA-AnimationCoreEngine.dll` 触发重新编译
- 修改环境变量 `AURORA_PERF_TIER` 切换性能等级 (Eco / Balanced / Performance / Extreme)
- TechButton 点击冷却: `ClickCooldown = 500`

---

*AURORA VelociRaptor-GR Dev PRJ. — 2026.06.02*