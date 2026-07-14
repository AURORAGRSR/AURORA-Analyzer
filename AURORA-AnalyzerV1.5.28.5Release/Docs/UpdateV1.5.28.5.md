# AURORA Analyzer V1.5.28.5 更新说明

> **Windows 事件日志导出与智能诊断工具**
>
> 版本：V1.5.28.5Release · 构建时间：2026.07.14 · 作者：AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **警告**：本工具仅用于个人学习使用。请遵守当地法律法规。

---

## 目录

1. [版本概述](#1-版本概述)
2. [P1 级别：安全更新批量加固](#2-p1-级别安全更新批量加固)
3. [P2 级别：渲染机制重构与刷新率自适应](#3-p2-级别渲染机制重构与刷新率自适应)
4. [P3 级别：控制台模式 GUI/CLI 双模式兼容](#4-p3-级别控制台模式-guicli-双模式兼容)
5. [P4 级别：SMART SLI 智能模式调用桥](#5-p4-级别smart-sli-智能模式调用桥)
6. [P5 级别：PRO 模式控件入场动效时间跳变修复](#6-p5-级别pro-模式控件入场动效时间跳变修复)
7. [P6 级别：历史视图命中检测机制修复](#7-p6-级别历史视图命中检测机制修复)
8. [P7 级别：解决方案入口新增](#8-p7-级别解决方案入口新增)
9. [P8 级别：底部按钮错峰入场动效优化](#9-p8-级别底部按钮错峰入场动效优化)
10. [P9 级别：撤销管理器优化与修复](#10-p9-级别撤销管理器优化与修复)
11. [P10 级别：主窗口语言顺序与细节优化](#11-p10-级别主窗口语言顺序与细节优化)
12. [兼容性保持](#12-兼容性保持)
13. [变更清单总览](#13-变更清单总览)

---

## 1. 版本概述

V1.5.28.5 是 AURORA-Analyzer 在 V1.5.28.0 视图重塑基础上的渲染机制重构与控制台模式易用性升级版本。本次更新覆盖七大核心领域：安全更新批量加固、渲染机制重构与刷新率自适应、控制台模式 GUI/CLI 双模式兼容、SMART SLI 智能模式调用桥、PRO 模式动效修复、历史视图与解决方案视图多项优化、主窗口与全局视觉细节优化。PowerShell 引擎层保持兼容，所有命令行参数、环境变量接口和 syncHash 同步机制均维持不变。

在渲染优化方面，V1.5.28.5 建立了完整的 GPU 利用优化链路：启动时探测（MaterialCapabilities.Probe 探测 GPU 厂商/显存/D3D9Ex/ShaderEffect/远程会话）、动态分级（Eco/Balanced/Performance/Extreme 四档）、渲染层级惰性订阅（CompositionTarget.Rendering 首注册订阅、末注销退订）、后端三级回退链（ShaderEffect HLSL → RtbBlurBackend）、频率自适应节流（10/15/20/30fps）、远程会话双路检测（GetSystemMetrics + WTSQuerySessionInformation）。

在动效归一化方面，V1.5.28.5 将 timeScale 分母从 16.667（60fps）修正为 22.222（45fps），匹配 DispatcherTimer 在 Render 优先级下因队列调度抖动产生的实际平均帧率，让 AuroraButton、AuroraTaskHUD、AuroraProgressBar 的动效速度与设计预期一致。

在控制台模式方面，V1.5.28.5 通过 AURORA-SmartEngine-CLI.ps1 三层架构（线程安全 syncHash + 后台 Runspace 执行 SmartEngine + 主线程轮询响应 GUI 事件）实现了纯控制台环境下的完整智能修复流程。

V1.5.28.5 通过以下核心策略实现了全面升级：

- **安全加固**：修补提权命令行参数注入、Invoke-Expression 命令注入与缓存投毒、完整性校验 TOCTOU 窗口
- **渲染重构**：六位一体 GPU 利用优化机制，刷新率自适应归一化
- **控制台双模式**：AURORA-SmartEngine-CLI.ps1 适配层，五个 GUI 等待点全部接管
- **SMART SLI**：控制台模式调用智能模式
- **动效修复**：PRO 模式动态兜底定时器
- **检测修复**：健康分浮点运算、扫描窗口动态扩展
- **细节优化**：语言顺序、Splash 布局、UWP 状态文本、模态遮罩动效

本次更新是一个"渲染机制全面重构、控制台模式易用性全新打造、动效归一化精准匹配、安全加固批量落地"的版本。所有面向用户的命令行接口、环境变量和跨 Runspace 通信协议均保持完全兼容，确保现有脚本和工作流无需修改即可运行。

---

## 2. P1 级别：安全更新批量加固

P1 级别的变更是修补多个关键安全漏洞。

### P1-1: H-7 提权命令行参数注入修复

**问题**：View-AdminElevation.ps1 和 View-ProMode.ps1 在重启提权时，将语言参数和路径参数直接拼接到命令行，未做校验，存在命令行元字符注入风险。

**修复**：新增两个校验函数：
- **Test-AuroraLanguageSafe**：严格白名单，仅允许 "CHS" 或 "ENG"
- **Test-AuroraPathSafe**：拒绝包含 `[<>&|\`"$]` 元字符的路径，规范化路径验证绝对路径

校验链：View-AdminElevation.ps1 被 AURORA-AnalyzerLauncherGUI.ps1 dot-source 引入，暴露校验函数给所有后续脚本。View-ProMode.ps1 通过 Restart-WithAdmin 间接使用校验。

**原因**：提权命令行参数未做校验。

**影响范围**：View-AdminElevation.ps1、View-ProMode.ps1、AURORA-AnalyzerLauncherGUI.ps1。

---

### P1-2: H-6 Invoke-Expression 命令注入与缓存投毒修复

**问题**：AURORA-SmartEngine.ps1 三处使用 Invoke-Expression 执行 JSON 配置中的命令字符串，攻击者可通过篡改 JSON 注入任意命令。同时 SecurityModule.ps1 的完整性校验缓存存在 TOCTOU 窗口。

**修复**：
- **Test-AuroraCommandSafe**：最大命令长度 8192 字符，正则黑名单覆盖命令执行、网络、持久化、反射注入、编码绕过、进程注入、WMI 绕过、注册表篡改、环境变量篡改
- **Invoke-AuroraSafeCommand**：替换 Invoke-Expression 为 `[ScriptBlock]::Create($CommandStr)` + `& $sb`，审计日志记录到 `%LOCALAPPDATA%\AURORA\Logs\command_audit.log`
- **三处替换**：pre_check（521 行）、command（742 行）、rollback_command（976 行）
- **_integrityCacheDuration = TimeSpan.Zero**：消除 TOCTOU 窗口

**原因**：Invoke-Expression 执行未校验的命令字符串，完整性校验缓存存在 TOCTOU 窗口。

**影响范围**：AURORA-SmartEngine.ps1、AURORA-SecurityModule.ps1。

---

### P1-3: 编码修复

**问题**：View-AdminElevation.ps1、View-ProMode.ps1、AURORA-AnalyzerLauncherGUI.ps1 在中文 Windows 上解析异常。

**修复**：为三个脚本添加 UTF-8 BOM。

**原因**：缺少 UTF-8 BOM 导致中文 Windows 解析错误。

**影响范围**：View-AdminElevation.ps1、View-ProMode.ps1、AURORA-AnalyzerLauncherGUI.ps1。

---

## 3. P2 级别：渲染机制重构与刷新率自适应

P2 级别的变更是对图形渲染管线进行全面重构。

### P2-1: 启动时探测

**变更**：App.xaml.cs 在应用启动时执行三阶段探测：渲染模式选择（RenderMode.Default）、初始分级（RenderCapability.Tier >> 16）、硬件能力探测（MaterialCapabilities.Probe 探测 GPU 厂商/显存/D3D9Ex/ShaderEffect/远程会话）。

**原因**：需要根据硬件能力选择最合适的渲染策略。

**影响范围**：App.xaml.cs 启动流程、MaterialCapabilities.cs Probe。

---

### P2-2: 动态分级

**变更**：根据探测结果划分四个性能挡位：Eco（Tier==0 或远程会话，100ms/10fps）、Balanced（低端 GPU，66ms/15fps）、Performance（主流 GPU，50ms/20fps）、Extreme（高端 GPU，33ms/30fps）。

**原因**：不同硬件能力需要不同的渲染频率平衡画质与性能。

**影响范围**：AuroraMaterialPipeline.cs GetBackgroundCaptureThrottleMs。

---

### P2-3: 渲染层级惰性订阅

**变更**：CompositionTarget.Rendering 在首个 AuroraMaterialComposer 注册时自动订阅，最后一个 Composer 注销时退订。`_isRenderingSubscribed` 标志确保订阅状态一致性。

**原因**：杜绝所有玻璃材质组件不可见时的无意义每帧计算。

**影响范围**：AuroraMaterialPipeline.cs Register/Unregister。

---

### P2-4: 后端三级回退链

**变更**：模糊后端采用三级回退：Tier==0 强制 RtbBlurBackend（软件渲染下 ShaderEffect 在 CPU 运行更慢）→ Tier>=1 优先 ShaderEffectBackend（HLSL PS 3.0 GPU 9 抽头高斯模糊）→ 最终回退 RtbBlurBackend。ReloadBlurBackend 在 GPU 驱动崩溃/电源切换/远程会话变化时触发。

**原因**：确保各种环境下都有可用的模糊后端。

**影响范围**：AuroraMaterialPipeline.cs SelectBlurBackend/ReloadBlurBackend。

---

### P2-5: 远程会话双路检测

**变更**：MaterialCapabilities.DetectRemoteSession 采用双路检测：快速路径 GetSystemMetrics(SM_REMOTESESSION)、精确路径 WTSQuerySessionInformation(WTSConnectState)。仅 WTSActive=0 视为本地会话。检测失败保守假设非远程。检测到远程时强制禁用 DWM/ShaderEffect 后端。

**原因**：RDP 无法正确渲染 Acrylic 和 GPU ShaderEffect。

**影响范围**：MaterialCapabilities.cs DetectRemoteSession/Probe。

---

### P2-6: 动效帧率归一化（45fps 基准）

**变更**：将 AuroraButton、AuroraTaskHUD、AuroraProgressBar 的 timeScale 分母从 16.667（60fps）改为 22.222（45fps），匹配 DispatcherTimer 在 Render 优先级下的实际平均帧率。Eco 模式下使用 1.0 timeScale + 33ms 节流，不进行归一化。

**原因**：原 60fps 基准与实际 45fps 平均帧率不匹配，导致动效视觉速度快约 33%。

**影响范围**：AuroraButton.cs:725、AuroraTaskHUD.cs:257、AuroraProgressBar.cs:202。

---

## 4. P3 级别：控制台模式 GUI/CLI 双模式兼容

P3 级别的变更是全新打造 AURORA-SmartEngine-CLI.ps1 适配层。

### P3-1: 三层架构

**变更**：预创建线程安全 syncHash（`[hashtable]::Synchronized(@{})`，LogOutput 使用 `[System.Collections.ArrayList]::Synchronized(...)`）+ 后台 Runspace 执行 SmartEngine.ps1（保留原始逻辑不做修改）+ 主线程轮询 syncHash 响应 GUI 事件。

**原因**：让 SmartEngine 在纯控制台环境下也能完成完整流程。

**影响范围**：AURORA-SmartEngine-CLI.ps1（新增文件）。

---

### P3-2: 五个 GUI 等待点接管

**变更**：CLI 适配层接管 SmartEngine 的五个阻塞等待点：预提权等待（RequiresElevation/ElevationAuthorized）、授权 EventWaitHandle 等待（AuthorizationEventName/Authorized）、CSV 导出日志确认（RequiresUserInput/UserInput）、catch 分支提权补救、主菜单事件循环（IsHostAlive/UserInput/Authorized/PendingCommand）。

**原因**：SmartEngine 的 GUI 等待点在控制台环境下无法触发。

**影响范围**：AURORA-SmartEngine-CLI.ps1 轮询状态机。

---

### P3-3: 轮询状态机与编码修复

**变更**：主循环包含完整的轮询状态机（4.3 提权请求/4.4 授权请求/4.5 CSV 确认/4.7 菜单输入）。添加 UTF-8 BOM 解决中文编码错误。修复执行结果不打印（过早状态检测 + Read-Host 线程阻塞）、提权取消后需手动 'm' 刷新（状态变更遗漏）、菜单重复打印（冗余日志 + 'm' 命令未处理）。

**原因**：CLI 适配层需要完整的轮询状态机和正确的编码处理。

**影响范围**：AURORA-SmartEngine-CLI.ps1 主循环、编码处理。

---

### P3-4: 接入点

**变更**：AURORA-SmartEngine-CLI.ps1 集成到 AURORA-AnalyzerPRO.ps1 的 -ConsoleMode 分支，性能升级对话框和 MainForm View 2 控制台按钮均可访问。

**原因**：提供控制台模式的入口。

**影响范围**：AURORA-AnalyzerPRO.ps1 -ConsoleMode 分支。

---

## 5. P4 级别：SMART SLI 智能模式调用桥

P4 级别的变更是新增 SMART SLI，让控制台模式也能调用智能模式。

### P4-1: SMART SLI 桥接

**变更**：控制台模式新增调用智能模式的能力。SMART SLI 与 AURORA-SmartEngine-CLI.ps1 适配层协同工作，控制台模式启动 SmartEngine 时，CLI 适配层接管五个 GUI 等待点，SMART SLI 负责将控制台输入路由到智能模式的决策、授权、提权等流程。

**原因**：让控制台模式用户也能享受智能模式的自动化修复能力。

**影响范围**：控制台模式入口、SmartEngine 调用链。

---

## 6. P5 级别：PRO 模式控件入场动效时间跳变修复

P5 级别的变更是修复 PRO 模式尾部控件入场动画突然加速的问题。

### P5-1: 动态兜底定时器

**问题**：ProModeView.PlayControlEnterAnimation 的 16 个控件中，尾部控件（ExitButton 延迟 1120ms、MinimizeButton 延迟 1200ms）的主动画（450ms）尚未完成时，固定 1500ms 兜底定时器就触发并强制重置 ScaleTransform 到终态，导致动画"突然加速"的视觉跳变。

**修复**：将兜底定时器改为动态计算公式 `fallbackMs = (tiles.Count - 1) * staggerMs + durationMs + bounceDurationMs + 100`。对于 16 个控件：(16-1) × 80 + 450 + 525 + 100 = 2275ms，确保所有控件动画完成后再触发兜底。

**原因**：固定 1500ms 兜底定时器无法适配 16 个控件的总动画时长（2175ms）。

**影响范围**：ProModeView.xaml.cs PlayControlEnterAnimation 兜底定时器。

---

## 7. P6 级别：历史视图命中检测机制修复

P6 级别的变更是修复历史视图命中检测的两个问题。

### P6-1: 健康分浮点运算修复

**问题**：ExportHistoryService.ComputeHealthScore 使用整数除法 `totalIssues * 100 / totalEvents`，当 totalIssues 较小且 totalEvents 较大时，整数除法截断导致扣分为 0，健康分错误返回 100。

**修复**：提取为公共静态方法，使用浮点运算 `(double)totalIssues * 100.0 / (double)totalEvents` + `Math.Round`。权重 critical=3、error=2、warning=1。HistoryMatchService 调用同一方法确保公式一致。

**原因**：整数除法截断小数导致扣分为 0。

**影响范围**：ExportHistoryService.cs ComputeHealthScore、HistoryMatchService.cs 调用链。

---

### P6-2: 扫描窗口动态扩展

**问题**：HistoryMatchService 使用固定 24h 扫描窗口，当导出日志的时间范围超过 24h 时，刚导出的日志因超出窗口而匹配失败。

**修复**：新增 ComputeScanWindowHours 方法动态计算窗口：默认 24h，取 max(24h, DateRange 起始日期到现在的跨度)，上限 720h（30 天）。支持单日期（yyyyMMdd）和日期范围（start-end）两种格式。

**原因**：固定 24h 窗口无法覆盖导出时间范围。

**影响范围**：HistoryMatchService.cs ComputeScanWindowHours 及 Detect 调用链。

---

## 8. P7 级别：解决方案入口新增

P7 级别的变更是重构 ShowMatchResult 为"无论命中与否都提供进入详情的入口"。

### P7-1: 统一入口设计

**变更**：ExportHistoryView.ShowMatchResult 重构为 `canShowDetail = true`（除检测失败外），始终调用 ShowGlassConfirm，用户选"Yes"即调用 OpenSolutionDetail。

**原因**：此前仅在命中且有方案时才提供入口，未命中时用户无法查看对比详情。

**影响范围**：ExportHistoryView.xaml.cs ShowMatchResult。

---

### P7-2: 三种提示场景

**变更**：命中且有方案（列出方案引导修复）、命中但无方案（引导查看对比详情）、未命中/状态分歧（引导查看对比确认历史问题是否仍存在）三种场景提供不同的提示文案。

**原因**：不同场景需要不同的引导语。

**影响范围**：ExportHistoryView.xaml.cs ShowMatchResult 提示文案。

---

## 9. P8 级别：底部按钮错峰入场动效优化

P8 级别的变更是优化历史视图和解决方案视图底部按钮的入场动效。

### P8-1: ExportHistoryView 底部按钮错峰入场

**变更**：将 BottomButtons 从整体 Opacity/RenderTransform 改为每个按钮独立 Opacity=0 + TransformGroup，加入控件交错入场序列（9 个控件：BackBtn/TitleLabel/RefreshBtn/ListSection/DetailSection/DetectBtn/ExportBtn/OpenDirBtn/DeleteBtn）。参数 staggerMs=120、durationMs=675、bounceDurationMs=525，兜底定时器 2260ms。

**原因**：此前所有按钮同时出现，缺乏节奏感。

**影响范围**：ExportHistoryView.xaml BottomButtons 区、ExportHistoryView.xaml.cs PlayControlEnterAnimation。

---

### P8-2: SolutionDetailView 底部按钮错峰入场

**变更**：SolutionDetailView 底部按钮同步采用错峰入场动效，每个按钮独立 Opacity=0 + TransformGroup，配合动态兜底定时器确保动画完整播放。

**原因**：与 ExportHistoryView 视觉一致性。

**影响范围**：SolutionDetailView.xaml、SolutionDetailView.xaml.cs。

---

## 10. P9 级别：撤销管理器优化与修复

P9 级别的变更是将 UndoViewer 从 SolutionDetailView 迁移到 SmartModeView，并统一 RepairSession 跨模式记录。

### P9-1: UndoViewer 迁移

**变更**：UndoViewer 从 SolutionDetailView 迁移到 SmartModeView。SmartModeView.xaml 新增 UndoViewerButton（100×32），SmartModeViewModel.cs 新增 ShowUndoViewerCommand/ShowUndoViewerRequested/OnShowUndoViewer，SmartModeView.xaml.cs OnShowUndoViewerRequested 构造 UndoViewerView。SolutionDetailView.xaml 移除所有 UndoViewer 相关代码。

**原因**：大部分修复命令在 SmartMode 执行，UndoViewer 与主要执行场景脱节。

**影响范围**：SmartModeView.xaml/SmartModeViewModel.cs/SmartModeView.xaml.cs、SolutionDetailView.xaml、UndoViewerView.xaml/.cs。

---

### P9-2: RepairSession 跨模式记录

**变更**：SmartMode 和 PRO 模式均调用 RecordRepairSession 记录到 RepairService。SmartModeViewModel.ShowResultModal 和 ProModeViewModel.ShowResultModal 解析 CommandResult Hashtable（ActionName/Result/Output/ExecutionTime/Command），调用 RecordRepairSession（RepairType.Custom，检测成功 via result.IndexOf("成功")/"Success"）。SmartEngine.ps1 的 CommandResult Hashtable 必须包含 `Command = $Command.command` 字段。

**原因**：确保撤销管理器能展示所有模式执行的命令。

**影响范围**：SmartModeViewModel.cs ShowResultModal/RecordRepairSession、ProModeViewModel.cs ShowResultModal/RecordRepairSession、AURORA-SmartEngine.ps1 CommandResult。

---

### P9-3: UndoViewer 视觉对齐

**变更**：UndoViewerView 对齐 FixExecutionOverlay 视觉风格：半透明深色遮罩（#E60A1428）+ AuroraFrostedGlassBorder 容器，无独立星空背景，入场/退场动效与 FixExecutionOverlay 一致。

**原因**：与执行窗口视觉统一。

**影响范围**：UndoViewerView.xaml、UndoViewerView.xaml.cs。

---

## 11. P10 级别：主窗口语言顺序与细节优化

P10 级别的变更是多项视觉与交互细节优化。

### P10-1: 主窗口语言列表顺序

**变更**：MainFormView.xaml 调整语言列表顺序，"简体中文"（CHS）置于首位、"English"（ENG）置于次位。

**原因**：符合用户使用习惯。

**影响范围**：MainFormView.xaml:91-106。

---

### P10-2: Splash 文字布局优化

**变更**：优化 SplashScreenView 的文字布局，让标题、副标题、状态文本在视觉上更均衡。

**原因**：启动画面文字布局拥挤或偏移。

**影响范围**：SplashScreenView.xaml。

---

### P10-3: UWP 状态文本优化

**变更**：优化 UWP 风格状态文本的同步与显示，确保状态随 SmartEngine 进度正确更新。

**原因**：状态文本与引擎进度不同步。

**影响范围**：状态文本相关视图与 ViewModel。

---

### P10-4: 模态对话框遮罩动效与视觉效果

**变更**：优化所有模态对话框（ModalOverlay/UserInputOverlay/MessageOverlay/FixExecutionOverlay/UndoViewerOverlay 等）的遮罩动效与视觉效果：遮罩透明度与色调统一，入场退场的蓄力—放大—淡出节奏优化，玻璃容器圆角与高光描边视觉统一，遮罩与内容动效时序协调消除内容跳变。

**原因**：模态对话框遮罩动效与视觉效果不统一。

**影响范围**：所有模态对话框视图。

---

## 12. 兼容性保持

V1.5.28.5 在渲染机制重构和控制台模式升级的同时，在以下方面保持了完全兼容：

| 兼容项 | 说明 |
|--------|------|
| PowerShell 5.1 兼容 | C# 代码仍使用 C# 5.0 语言版本编译 |
| 命令行参数 | 所有命令行参数完全兼容，无新增或移除 |
| syncHash 同步机制 | 跨 Runspace 通信的 syncHash 接口完全兼容 |
| 环境变量接口 | 所有环境变量接口完全兼容 |
| 脚本接口 | PowerShell 脚本引擎接口不变（内部安全加固不改变外部接口） |
| 材质管线 | V5 材质管线接口不变，AuroraFrostedGlassBorder/AuroraFrostedGlassCard 行为不变 |
| 动效接口 | 控件级动效方法签名不变，AnimationHelper 公共方法不变 |
| 玻璃材质捕获 | 精度配置不变（30fps/1/2 分辨率/BlurRadius=2.5），仅挡位降级时调整频率 |
| 渲染后端 | 默认仍优先 GPU 硬件加速，仅软件渲染或远程会话时回退 |

---

## 13. 变更清单总览

| 编号 | 级别 | 变更描述 | 变更原因 | 影响范围 |
|------|------|----------|----------|----------|
| P1-1 | P1 | H-7 提权命令行参数注入修复 | 提权参数未校验 | View-AdminElevation/View-ProMode |
| P1-2 | P1 | H-6 Invoke-Expression 注入与缓存投毒修复 | 命令注入与 TOCTOU | AURORA-SmartEngine/AURORA-SecurityModule |
| P1-3 | P1 | 编码修复（UTF-8 BOM） | 中文 Windows 解析错误 | View-AdminElevation/View-ProMode/LauncherGUI |
| P2-1 | P2 | 启动时探测 | 根据硬件能力选择渲染策略 | App.xaml.cs/MaterialCapabilities |
| P2-2 | P2 | 动态分级 | 平衡画质与性能 | AuroraMaterialPipeline |
| P2-3 | P2 | 渲染层级惰性订阅 | 杜绝无意义每帧计算 | AuroraMaterialPipeline Register/Unregister |
| P2-4 | P2 | 后端三级回退链 | 确保各种环境可用 | AuroraMaterialPipeline SelectBlurBackend |
| P2-5 | P2 | 远程会话双路检测 | RDP 无法渲染 Acrylic | MaterialCapabilities DetectRemoteSession |
| P2-6 | P2 | 动效帧率归一化 45fps | 60fps 基准与实际不匹配 | AuroraButton/AuroraTaskHUD/AuroraProgressBar |
| P3-1 | P3 | CLI 三层架构 | 控制台环境完成流程 | AURORA-SmartEngine-CLI.ps1 |
| P3-2 | P3 | 五个 GUI 等待点接管 | 控制台无法触发 GUI 等待 | AURORA-SmartEngine-CLI.ps1 轮询 |
| P3-3 | P3 | 轮询状态机与编码修复 | 完整状态机和正确编码 | AURORA-SmartEngine-CLI.ps1 主循环 |
| P3-4 | P3 | CLI 接入点 | 提供控制台模式入口 | AURORA-AnalyzerPRO.ps1 -ConsoleMode |
| P4-1 | P4 | SMART SLI 桥接 | 控制台调用智能模式 | 控制台模式入口 |
| P5-1 | P5 | PRO 动态兜底定时器 | 固定 1500ms 过早触发 | ProModeView PlayControlEnterAnimation |
| P6-1 | P6 | 健康分浮点运算 | 整数除法截断 | ExportHistoryService/HistoryMatchService |
| P6-2 | P6 | 扫描窗口动态扩展 | 固定 24h 无法覆盖 | HistoryMatchService ComputeScanWindowHours |
| P7-1 | P7 | 统一入口设计 | 未命中时无入口 | ExportHistoryView ShowMatchResult |
| P7-2 | P7 | 三种提示场景 | 不同场景不同引导 | ExportHistoryView ShowMatchResult 文案 |
| P8-1 | P8 | ExportHistoryView 底部按钮错峰 | 同时出现无节奏 | ExportHistoryView BottomButtons |
| P8-2 | P8 | SolutionDetailView 底部按钮错峰 | 视觉一致性 | SolutionDetailView |
| P9-1 | P9 | UndoViewer 迁移 | 与执行场景脱节 | SmartModeView/SolutionDetailView |
| P9-2 | P9 | RepairSession 跨模式记录 | 撤销管理器展示不全 | SmartModeViewModel/ProModeViewModel |
| P9-3 | P9 | UndoViewer 视觉对齐 | 与执行窗口统一 | UndoViewerView |
| P10-1 | P10 | 语言列表顺序 | 符合使用习惯 | MainFormView.xaml |
| P10-2 | P10 | Splash 文字布局 | 布局拥挤偏移 | SplashScreenView |
| P10-3 | P10 | UWP 状态文本 | 状态不同步 | 状态文本视图 |
| P10-4 | P10 | 模态遮罩动效与视觉 | 效果不统一 | 所有模态对话框 |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *本工具仅供个人学习使用。请遵守当地法律法规。*
