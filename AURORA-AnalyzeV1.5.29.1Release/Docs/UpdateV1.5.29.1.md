# AURORA Analyzer V1.5.29.1 更新说明

> **Windows 事件日志导出与智能诊断工具**
>
> 版本：V1.5.29.1Release · 构建时间：2026.07.27 · 作者：AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **警告**：本工具仅用于个人学习使用。请遵守当地法律法规。

---

## 目录

1. [版本概述](#1-版本概述)
2. [P1 级别：快速切换闪回修复（_pendingEnterTimers 模式）](#2-p1-级别快速切换闪回修复_pendingentertimers-模式)
3. [P2 级别：星场纵深视觉优化（星点放大 + 视差参数回调）](#3-p2-级别星场纵深视觉优化星点放大--视差参数回调)
4. [P3 级别：流星式光晕拖尾系统](#4-p3-级别流星式光晕拖尾系统)
5. [P4 级别：视图深度重分配](#5-p4-级别视图深度重分配)
6. [P5 级别：管理员路径瞬移修复（前置视差方案）](#6-p5-级别管理员路径瞬移修复前置视差方案)
7. [P6 级别：模式切换轮询状态隔离修复](#7-p6-级别模式切换轮询状态隔离修复)
8. [P7 级别：Runspace 复用作用域与引擎快速完成稳定性修复](#8-p7-级别runspace-复用作用域与引擎快速完成稳定性修复)
9. [兼容性保持](#9-兼容性保持)
10. [变更清单总览](#10-变更清单总览)

---

## 1. 版本概述

V1.5.29.1 是 AURORA-Analyzer 在 V1.5.29.0 多层深度视差重塑基础上的"纵深视觉表现力与切换稳健性"专项打磨版本。本次更新覆盖六大核心领域：快速切换闪回修复、星场纵深视觉优化、流星式光晕拖尾系统、视图深度重分配、管理员路径瞬移修复、模式切换轮询状态隔离修复。PowerShell 引擎层保持兼容，所有命令行参数、环境变量接口和 syncHash 同步机制均维持不变。

在纵深拖尾方面，V1.5.29.1 建立了完整的速度驱动模型：拖尾长度由归一化速度驱动，方向适配 zoomOut/zoomIn，EMA 平滑消除帧间抖动，软阈值过渡消除闪烁，视差结束立即消失。

在视图深度方面，V1.5.29.1 重新分配 5 个对话框/详情视图深度：ExportHistory 0.70、UndoViewer 0.78、Elevation 0.82、SessionRestore 0.86、SolutionDetail 0.95，消除同级视图零跨度切换。

在切换稳健性方面，V1.5.29.1 用 `_pendingEnterTimers` 列表统一管理入场定时器生命周期，确保退场动画启动前取消所有未完成的入场定时器。

V1.5.29.1 通过以下核心策略实现了全面升级：

- **快速切换闪回修复**：6 个视图统一 `_pendingEnterTimers` 模式
- **星场纵深视觉优化**：星点放大 + 视差参数回调
- **流星式光晕拖尾**：LinearGradientBrush 渐变，速度驱动，EMA 平滑
- **视图深度重分配**：5 个视图深度拉开，消除零跨度
- **管理员路径瞬移修复**：前置视差方案，500ms 冲到 0.30 再启动 NavigateTo
- **模式切换轮询状态隔离修复**：StartSyncHashPolling 重置 _pollingSuspended 标志，修复控制台不回显与进度卡 50%
- **Runspace 复用作用域与引擎快速完成稳定性修复**：SmartEngine 加 Get-Command 保护、强制推进 Progress=100、SecurityModule 哈希清单同步

本次更新是一个"纵深视觉表现力全面提升、切换稳健性根除闪回"的版本。所有面向用户的命令行接口、环境变量和跨 Runspace 通信协议均保持完全兼容，确保现有脚本和工作流无需修改即可运行。

---

## 2. P1 级别：快速切换闪回修复（_pendingEnterTimers 模式）

P1 级别的变更是修复快速切换时控件闪现回原位的问题。

### P1-1: 闪回根因

**问题**：`PlayControlEnterAnimation` 创建的 `DispatcherTimer`（per-tile 错峰定时器、fallback 兜底定时器、listDelay 列表项延迟定时器）是 fire-and-forget 的。若用户在入场动画期间点击切换按钮触发 `PlayStaggerExit`，这些待触发的定时器会在退场动画进行中触发：per-tile 定时器调用 `BeginAnimation` 覆盖退场动画，fallback 定时器直接强制 `tile.Opacity=1` + `ScaleX=1` + `Y=0`，listDelay 定时器触发 `PlayListItemEnterAnimation` 让列表项重新入场。

**修复**：统一对齐 ProModeView 标杆的 `_pendingEnterTimers` 模式——添加字段跟踪待触发定时器，添加 `CancelPendingEnterTimers()` 方法统一停止，`PlayControlEnterAnimation` 注册定时器到列表，`PlayControlExitAnimation` 开头调用 `CancelPendingEnterTimers()`。

**原因**：fire-and-forget 定时器在退场动画期间触发导致状态覆盖。

**影响范围**：6 个视图的 `.xaml.cs` 文件。

---

### P1-2: 修复覆盖的 6 个视图

**变更**：6 个 IAuroraStaggerView 视图统一引入 `_pendingEnterTimers` 模式：ProModeView（per-tile + fallback）、SmartModeView（per-tile + fallback）、ExportHistoryView（per-tile + fallback + listDelay）、SolutionDetailView（per-tile + fallback）、ElevationDialogView（per-tile + fallback）、SessionRestoreDialogView（per-tile + fallback）。

**原因**：6 个视图都有 fire-and-forget 入场定时器，存在闪回风险。

**影响范围**：`ProModeView.xaml.cs`、`SmartModeView.xaml.cs`、`ExportHistoryView.xaml.cs`、`SolutionDetailView.xaml.cs`、`ElevationDialogView.xaml.cs`、`SessionRestoreDialogView.xaml.cs`。

---

### P1-3: 未修复视图评估

**变更**：3 个视图经评估后判定无需修复：MainFormView（内部状态切换为主，退场仅按钮+标题错峰，覆盖风险低）、SplashScreenView（一次性启动场景，无快速切换路径）、UndoViewerView（退场用 `_closeSafetyTimer` 兜底，无 per-tile 入场定时器链）。

**原因**：这 3 个视图不存在 fire-and-forget 入场定时器覆盖退场动画的风险。

**影响范围**：无。

---

## 3. P2 级别：星场纵深视觉优化（星点放大 + 视差参数回调）

P2 级别的变更是优化星场纵深运动的视觉表现力。

### P2-1: 星点放大与增亮

**变更**：`AuroraStarfield.cs` 调整星点尺寸与亮度参数：Size 基础系数 0.8→1.1（整体放大约 37%）、CurrentRenderSize 初始 0.55×→0.7×（入场即明显）、BaseAlpha 上限 130→180（亮星比例提升）。

**原因**：纵深运动期间星点体积小、亮度低，运动反馈不醒目。

**影响范围**：`AuroraStarfield.cs` DrawStars。

---

### P2-2: 视差参数回调

**变更**：视差参数经过多轮调优最终回调到平衡值：push 位移 0.28→0.30（中间值 0.36，-17% 减少扑面冲击）、scale 缩放 0.4→0.45（中间值 0.6，-25% 减少放大冲击）、opacity 暗化 0.62→0.25（亮度从 38% 回升到 75%）。

**原因**：opacity 0.62 是"不够亮眼"的直接原因——视差期间星星亮度被砍掉近三分之二；push 0.36 和 scale 0.6 产生过激冲动感。

**影响范围**：`AuroraStarfield.cs` 视差绘制路径。

---

## 4. P3 级别：流星式光晕拖尾系统

P3 级别的变更是为星场纵深运动引入流星式光晕拖尾。

### P3-1: 拖尾形态选择

**变更**：评估四种拖尾形态（彗星拖尾、速度线、残影叠加、光晕拉长）后选择 LinearGradientBrush 渐变光晕拖尾（彗星尾形态），透明端在 tail、亮端在 head，Pen 宽度与星点尺寸联动。

**原因**：彗星尾形态方向感强、视觉质感好，性能成本可接受（每星 new Brush，但视差仅 2.7 秒）。

**影响范围**：`AuroraStarfield.cs` OnRender 拖尾绘制。

---

### P3-2: 触发条件

**变更**：拖尾仅在视差期间（`isParallaxCycling && _parallaxVelocity > 0.0002`）+ 近景星（Depth > 0.6，约 150-200 颗）绘制。视差结束立即消失（Idle 态不绘制）。

**原因**：仅近景星需要拖尾强化方向感，远景星保持圆形强化层次感；Idle 态不绘制保留静谧感。

**影响范围**：`AuroraStarfield.cs` OnRender 拖尾分支。

---

### P3-3: 速度驱动模型与归一化

**变更**：拖尾长度由归一化速度驱动：`trailLen = (absoluteVelocity / parallaxSpan) × depth × 1500`。归一化后，无论跨度大小，拖尾峰值长度一致。

**原因**：小深度差场景（如 MainForm→ProMode 0.15→0.50）绝对速度低，拖尾会被削得太短。归一化让小深度差也有足够拖尾可见度。

**影响范围**：`AuroraStarfield.cs` OnRender 拖尾长度计算。

---

### P3-4: 拖尾方向适配

**变更**：新增 `_parallaxDirection` 字段（+1=zoomOut / -1=zoomIn），在 `StartParallaxCycle` 中根据目标相位与起始相位的差值判断：zoomOut 时拖尾端指向中心，zoomIn 时拖尾端指向外。

**原因**：原实现拖尾方向固定，zoomIn 时方向错误。

**影响范围**：`AuroraStarfield.cs` StartParallaxCycle、OnRender 拖尾方向计算。

---

### P3-5: EMA 平滑与软阈值过渡

**变更**：EMA 指数移动平均（α=0.3）消除帧间隔抖动：`_parallaxVelocitySmooth = _parallaxVelocitySmooth × 0.7 + _parallaxVelocity × 0.3`。软阈值过渡消除硬阈值切变闪烁：归一化速度 <0.0002 不绘制，0.0002~0.001 线性 0→1 过渡，>0.001 满强度。Idle 态 `_parallaxVelocitySmooth *= 0.5` 每帧减半，2-3 帧内归零。

**原因**：帧间隔抖动导致拖尾长度闪动；硬阈值切变导致拖尾出现/消失闪烁；Idle 残留导致下帧闪烁。

**影响范围**：`AuroraStarfield.cs` 动画推进逻辑、OnRender 拖尾强度计算。

---

### P3-6: 拖尾倍率调优

**变更**：拖尾倍率从 1200 降到 600，避免"火箭喷火"感。

**原因**：1200 倍率拖尾过长，视觉上像火箭喷火；600 倍率拖尾适中，自然灵动。

**影响范围**：`AuroraStarfield.cs` OnRender 拖尾长度倍率。

---

## 5. P4 级别：视图深度重分配

P4 级别的变更是重新分配 5 个对话框/详情视图的深度。

### P4-1: 同级视图零跨度问题

**问题**：V1.5.29.0 的 5 个对话框/详情视图都堆在 0.85，相互切换跨度为 0：历史→撤销 0.00、权限→会话 0.00、历史→详情 0.15（纵深过弱）、专业→智能 0.10（弱纵深）。

**修复**：重新分配深度：ExportHistoryView 0.85→0.70、UndoViewerView 0.85→0.78、ElevationDialogView 0.85→0.82、SessionRestoreDialogView 0.85→0.86、SolutionDetailView 1.00→0.95。

**原因**：同级视图零跨度导致切换无纵深反馈。

**影响范围**：`ViewManager.cs` GetViewDepth。

---

### P4-2: 新跨度对比

**变更**：新跨度：历史→详情 0.15→0.25（+67%）、历史→撤销 0.00→0.08（从无到有）、权限→会话 0.00→0.04（从无到有）、主窗口→历史 0.70→0.55（仍为强穿梭）、ProMode→历史 0.35→0.20（轻量弹窗感）。

**原因**：拉开同级视图深度，让每一次点击都有可见纵深反馈。

**影响范围**：`ViewManager.cs` GetViewDepth。

---

## 6. P5 级别：管理员路径瞬移修复（前置视差方案）

P5 级别的变更是修复管理员路径 Splash→MainForm 星场瞬移问题。

### P5-1: 瞬移根因

**问题**：管理员路径（已提权进程）跳过 ElevationDialog（深度 0.82），导致 Splash(0.0)→MainForm(0.15) 视差跨度仅 0.15。星场运动量被 Splash 退场和 MainForm 入场动画遮挡后，视觉上像"突然跳到新位置"。非管理员路径 Splash→ElevationDialog(0.82)→MainForm 跨度大，运动量充足，表现正常。

**修复**：采用前置视差方案——在 NavigateTo 之前先让星场单独跑 500ms 冲到 0.30，让用户清晰看到星场运动，然后再启动 Splash 退场 + MainForm 入场。星场运动分两段：0.0→0.30（前置，可见）→0.15（MainForm 入场期间，回落）。

**原因**：跨度 0.15 太小，运动量被遮挡，用户感知不到中间过程。

**影响范围**：`SplashScreenView.xaml.cs` NavigateToMainForm。

---

### P5-2: 时序设计

**变更**：T=0 前置视差启动 0.0→0.30（500ms）→T=500 启动 NavigateTo + Splash 退场（800ms）+ 视差 0.30→0.15（2700ms）→T=1300 Splash 退场完成切 Content + MainForm 入场（800ms）→T=3200 视差结束停在 0.15。

**原因**：让星场运动在 Splash 退场前就被用户感知到，不再有"卡一下然后跳"的瞬移感。

**影响范围**：`SplashScreenView.xaml.cs` NavigateToMainForm。

---

## 7. P6 级别：模式切换轮询状态隔离修复

P6 级别的变更是修复从智能模式返回主窗口再进入专业模式后控制台不回显、进度卡 50% 的问题。

### P6-1: 轮询标志状态泄漏

**问题**：`ProModeViewModel.StartSyncHashPolling()` 方法在启动 syncHash 轮询定时器时，没有重置 `_pollingSuspended` 标志为 `false`。该标志在 SmartMode 完成后被 `SuspendPolling()` 设为 `true`，返回 MainForm 时 `OnUnloaded` 再次设置（保持 true），重入 ProMode 时 `ResetForReentry()` 因 `IsRunning=false` 走重置分支不恢复轮询（正确，脚本已结束），但标志保持 true。用户点"开始分析"后 `StartSyncHashPolling()` 启动定时器，但 `ProcessSyncHashSnapshot` 检测到 `_pollingSuspended=true` 直接 return，导致日志/进度/ScriptDone 全部不被处理，控制台不回显、进度卡 50%，只能靠"强行停止"的 finally 块 `FlushRemainingLogOutput` 强制读取。

**修复**：`StartSyncHashPolling` 开头重置 `_pollingSuspended = false`，确保每次启动轮询时标志是干净的。

**原因**：`_pollingSuspended` 标志的生命周期有缺口，`SuspendPolling` 设 true 但 `StartSyncHashPolling` 没有对应重置。

**影响范围**：`ProModeViewModel.cs` StartSyncHashPolling。

---

### P6-2: ClearConsole 异步清空时序错误

**变更**：`ClearConsole` 从异步 `BeginInvoke` 改为同步 `Invoke`/直接调用。

**原因**：异步 `BeginInvoke` 排队的 `ConsoleLines.Clear()` 会在后续同步 `Add` 的内容之后执行，导致刚显示的日志被异步清空覆盖，用户看到"内容闪一下后消失"。

**影响范围**：`ProModeViewModel.cs` ClearConsole。

---

### P6-3: AppendConsoleLine 跨线程处理

**变更**：`AppendConsoleLine` 用 `Dispatcher.CheckAccess()` 严格判断线程，UI 线程直接 `ConsoleLines.Add`，非 UI 线程用 `BeginInvoke(Loaded)` 切回。

**原因**：`ObservableCollection.Add` 在非 UI 线程调用不抛异常但 `CollectionChanged` 通知不传播到 UI 线程的 Binding，导致日志写入但控制台不更新。

**影响范围**：`ProModeViewModel.cs`、`SmartModeViewModel.cs` AppendConsoleLine。

---

### P6-4: DispatcherTimer 被 Render 饿死

**变更**：`_syncHashTimer` 回调用 `Dispatcher.Invoke`（同步）替代 `BeginInvoke`（异步）。

**原因**：`BeginInvoke(Loaded)` 仍被 AuroraStarfield 的 `CompositionTarget.Rendering` 持续渲染工作推迟，`ProcessSyncHashSnapshot` 永远轮不到执行。

**影响范围**：`ProModeViewModel.cs`、`SmartModeViewModel.cs` 轮询回调。

---

### P6-5: LogOutput 为空时误清屏

**变更**：`ProcessSyncHashSnapshot` 中 LogOutput 为空或变短时不再调用 `ClearConsole()`，只重置 `_lastLogLength`。

**原因**：引擎在 Phase 之间可能重置 LogOutput，导致刚显示的日志被清空。

**影响范围**：`ProModeViewModel.cs`、`SmartModeViewModel.cs` ProcessSyncHashSnapshot。

---

## 8. P7 级别：Runspace 复用作用域与引擎快速完成稳定性修复

P7 级别的变更是修复先运行专业模式终止后再运行智能模式的 Assert-AuroraLaunchContext 报错，以及进度概率性卡 50% 的问题。

### P7-1: Assert-AuroraLaunchContext 命令未找到

**问题**：先运行专业模式终止后再运行智能模式，出现"无法将"Assert-AuroraLaunchContext"项识别为 cmdlet、函数、脚本文件或可运行程序的名称"报错。`AURORA-SmartEngine.ps1` 直接调用 `Assert-AuroraLaunchContext`，没有 `Get-Command` 存在性检查（`PRO-Engine.ps1` 有此保护，SmartEngine 缺失）。Runspace 复用场景下，ProMode 终止 PRO Engine 后全局变量 `$AURORA_LaunchGuard_Loaded=true` 残留，虽然 `LaunchGuard.ps1` 已移除 return 防止跳过函数定义，但 Runspace 状态污染可能导致 dot-source 不完整执行，直接调用触发 CommandNotFoundException。

**修复**：对齐 PRO-Engine 的防御性调用，先 `Get-Command` 检查函数是否存在再调用。

**原因**：SmartEngine 缺少 Get-Command 保护，Runspace 复用导致函数定义缺失触发 CommandNotFoundException。

**影响范围**：`Scripts\Engines\AURORA-SmartEngine.ps1`（第 45-61 行，LaunchGuard 调用保护）。

---

### P7-2: 进度概率性卡 50%

**问题**：直接进智能模式不报错，但进度卡 50% 和 100% 是看概率的，有时候 100% 有时候 50%。SmartEngine 执行很快时（1 秒内完成），Progress 从 50→80→100 快速变化。轮询采样到 Progress=50 后 SmartEngine 瞬间完成设置 `ScriptDone=true`，但下次轮询检测到 `ScriptDone=true` 时若 `IsRunning` 已被其他路径重置为 false，`OnScriptComplete` 不会被调用，Progress=100 未设置。

**修复**：`SmartModeViewModel.cs` 的 `ProcessSyncHashSnapshot` 中，检测到 `ScriptDone=true` 时，无论 `IsRunning` 状态如何，都强制设置 `Progress=100`，然后再判断是否调用 `OnScriptComplete`。

**原因**：引擎快速完成时轮询采样时序问题，IsRunning 已重置导致 OnScriptComplete 未调用。

**影响范围**：`AURORA.Wpf\ViewModels\SmartModeViewModel.cs`（第 690-707 行，ProcessSyncHashSnapshot）。

---

### P7-3: SecurityModule 哈希清单同步

**问题**：修改 `LaunchGuard.ps1` 和 `SmartEngine.ps1` 后，`SecurityModule.ps1` 中的哈希清单不匹配。`_integrityCacheDuration = TimeSpan.Zero`（无缓存），每次 CheckIntegrity 都重新校验，哈希不匹配会导致 VerifyOrDie 返回 false，SmartEngine 强制退出。

**修复**：更新 `AURORA-SecurityModule.ps1` 中两个文件的 SHA256 哈希：`AURORA-LaunchGuard.ps1` 从 `35fc9ce7ea399c6995fa0f8f22249a248522e2d7562733bf951b11118cad057f` 更新为 `40b25a683e722486766aad4c5c9cfbee17f23cc932c18d18b87f43c4a67d062c`；`AURORA-SmartEngine.ps1` 从 `e703e7c14d9f9b9bbd51233b157ba966b9e678d76deec1d6c711dc6a8a82a63e` 更新为 `d29fdfd850c207f679073a3c9ffa1e8c2c6854ec302316c4d68b70ba7e1af485`。

**原因**：脚本修改后哈希不匹配导致 VerifyOrDie 强制退出。

**影响范围**：`Scripts\Security\AURORA-SecurityModule.ps1`（第 188 行和第 201 行，哈希清单）。

---

## 9. 兼容性保持

V1.5.29.1 在纵深视觉优化与切换稳健性修复的同时，在以下方面保持了完全兼容：

| 兼容项 | 说明 |
|--------|------|
| PowerShell 5.1 兼容 | C# 代码仍使用 C# 5.0 语言版本编译 |
| 命令行参数 | 所有命令行参数完全兼容，无新增或移除 |
| syncHash 同步机制 | 跨 Runspace 通信的 syncHash 接口完全兼容 |
| 环境变量接口 | 所有环境变量接口完全兼容 |
| 脚本接口 | PowerShell 脚本引擎接口不变 |
| 材质管线 | V5 材质管线接口不变，AuroraFrostedGlassBorder/AuroraFrostedGlassCard 行为不变 |
| 动效接口 | 控件级动效方法签名不变，AnimationHelper 公共方法不变 |
| 玻璃材质捕获 | 精度配置不变（30fps/1/2 分辨率/BlurRadius=2.5） |
| 渲染后端 | 默认仍优先 GPU 硬件加速，仅软件渲染或远程会话时回退 |
| 星场星星数 | 纵深优化不增加渲染星星数，仅调整尺寸/亮度/拖尾 |
| 视图接口 | IAuroraStaggerView 接口不变，仅内部定时器管理实现优化 |
| 拖尾 GC 权衡 | 视差期间约 150 星 × 每星 new 1 Brush + 2 GradientStop + 1 Pen，但视差仅 2.7 秒且已跳过光晕/星芒/星座连线等昂贵渲染，GC 压力可接受 |
| 轮询状态隔离 | _pollingSuspended 标志在 StartSyncHashPolling 时重置，不影响现有 SuspendPolling/ResumePolling 接口 |

---

## 10. 变更清单总览

| 编号 | 级别 | 变更描述 | 变更原因 | 影响范围 |
|------|------|----------|----------|----------|
| P1-1 | P1 | _pendingEnterTimers 模式修复闪回 | fire-and-forget 定时器覆盖退场动画 | 6 个视图 .xaml.cs |
| P1-2 | P1 | 6 个视图统一修复 | 所有视图都有闪回风险 | ProModeView/SmartModeView/ExportHistoryView/SolutionDetailView/ElevationDialogView/SessionRestoreDialogView |
| P1-3 | P1 | 3 个视图评估无需修复 | 不存在定时器覆盖风险 | MainFormView/SplashScreenView/UndoViewerView |
| P2-1 | P2 | 星点放大与增亮（Size 0.8→1.1、BaseAlpha 130→180） | 纵深运动期间星点不醒目 | AuroraStarfield DrawStars |
| P2-2 | P2 | 视差参数回调（push 0.30、scale 0.45、opacity 0.25） | opacity 0.62 太暗、push/scale 过激 | AuroraStarfield 视差绘制 |
| P3-1 | P3 | LinearGradientBrush 渐变光晕拖尾 | 强化运动方向感 | AuroraStarfield OnRender |
| P3-2 | P3 | 触发条件（视差期间 + Depth>0.6） | 仅近景星需要拖尾 | AuroraStarfield OnRender 拖尾分支 |
| P3-3 | P3 | 归一化速度驱动 | 小深度差拖尾被削短 | AuroraStarfield OnRender 拖尾长度 |
| P3-4 | P3 | 拖尾方向适配（zoomOut/zoomIn） | 原方向固定 zoomIn 错误 | AuroraStarfield StartParallaxCycle/OnRender |
| P3-5 | P3 | EMA 平滑 + 软阈值过渡 | 帧间抖动 + 硬切闪烁 | AuroraStarfield 动画推进/OnRender |
| P3-6 | P3 | 拖尾倍率 1200→600 | 避免火箭喷火感 | AuroraStarfield OnRender 拖尾倍率 |
| P4-1 | P4 | 5 个视图深度重分配 | 同级视图零跨度 | ViewManager GetViewDepth |
| P4-2 | P4 | 新跨度对比 | 每次点击都有纵深反馈 | ViewManager GetViewDepth |
| P5-1 | P5 | 管理员路径前置视差修复 | 跨度 0.15 太小星场瞬移 | SplashScreenView NavigateToMainForm |
| P5-2 | P5 | 前置视差时序设计 | 让星场运动在 Splash 退场前可见 | SplashScreenView NavigateToMainForm |
| P6-1 | P6 | StartSyncHashPolling 重置 _pollingSuspended=false | 标志泄漏导致轮询被跳过 | ProModeViewModel StartSyncHashPolling |
| P6-2 | P6 | ClearConsole 改为同步执行 | 异步清空时序覆盖后续 Add | ProModeViewModel ClearConsole |
| P6-3 | P6 | AppendConsoleLine 用 CheckAccess 严格判断线程 | 跨线程 CollectionChanged 不传播 | ProModeViewModel/SmartModeViewModel AppendConsoleLine |
| P6-4 | P6 | _syncHashTimer 回调用 Dispatcher.Invoke 替代 BeginInvoke | 异步派发被 Render 饿死 | ProModeViewModel/SmartModeViewModel 轮询回调 |
| P6-5 | P6 | LogOutput 为空时不清屏只重置 _lastLogLength | 引擎 Phase 间重置 LogOutput 误清屏 | ProModeViewModel/SmartModeViewModel ProcessSyncHashSnapshot |
| P7-1 | P7 | SmartEngine 加 Get-Command 检查再调用 Assert-AuroraLaunchContext | Runspace 复用导致函数定义缺失触发 CommandNotFoundException | AURORA-SmartEngine.ps1 LaunchGuard 调用 |
| P7-2 | P7 | 检测 ScriptDone=true 时强制设置 Progress=100 | 引擎快速完成时轮询采样时序导致 OnScriptComplete 未调用 | SmartModeViewModel ProcessSyncHashSnapshot |
| P7-3 | P7 | 更新 LaunchGuard 和 SmartEngine 的 SHA256 哈希 | 脚本修改后哈希不匹配导致 VerifyOrDie 强制退出 | AURORA-SecurityModule.ps1 哈希清单 |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *本工具仅供个人学习使用。请遵守当地法律法规。*
