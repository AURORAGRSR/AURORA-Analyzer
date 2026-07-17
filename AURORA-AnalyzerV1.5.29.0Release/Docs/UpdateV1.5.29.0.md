# AURORA Analyzer V1.5.29.0 更新说明

> **Windows 事件日志导出与智能诊断工具**
>
> 版本：V1.5.29.0Release · 构建时间：2026.07.17 · 作者：AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **警告**：本工具仅用于个人学习使用。请遵守当地法律法规。

---

## 目录

1. [版本概述](#1-版本概述)
2. [P1 级别：星场视差多层深度重塑](#2-p1-级别星场视差多层深度重塑)
3. [P2 级别：对话框视觉统一与 Overlay 架构移除](#3-p2-级别对话框视觉统一与-overlay-架构移除)
4. [P3 级别：权限选择时序前置](#4-p3-级别权限选择时序前置)
5. [P4 级别：UWP 文本过渡曲线与语言切换修复](#5-p4-级别uwp-文本过渡曲线与语言切换修复)
6. [P5 级别：智能模式状态文本位置修复](#6-p5-级别智能模式状态文本位置修复)
7. [P6 级别：键盘焦点与导航防抖统一](#7-p6-级别键盘焦点与导航防抖统一)
8. [P7 级别：星场视差性能优化（极光层 +50%）](#8-p7-级别星场视差性能优化极光层-50)
9. [兼容性保持](#9-兼容性保持)
10. [变更清单总览](#10-变更清单总览)

---

## 1. 版本概述

V1.5.29.0 是 AURORA-Analyzer 在 V1.5.28.5 渲染机制重构与控制台模式升级基础上的"视觉沉浸感与交互一致性"专项打磨版本。本次更新将 V1.5.28.6 ~ V1.5.28.29 期间陆续落地的多处动效、视差、对话框、语言切换与导航防抖修复统一打包发布，覆盖七大核心领域：星场视差多层深度重塑、对话框视觉统一与 Overlay 架构移除、权限选择时序前置、UWP 文本过渡曲线与语言切换修复、智能模式状态文本位置修复、键盘焦点与导航防抖统一、星场视差性能优化。PowerShell 引擎层保持兼容，所有命令行参数、环境变量接口和 syncHash 同步机制均维持不变。

在视差深度方面，V1.5.29.0 建立了完整的 7 级深度映射链路：Splash（0.00）→ MainForm view1（0.15）→ MainForm view2（0.30）→ ProMode（0.50）→ SmartMode（0.60）→ 对话框组（0.85）→ SolutionDetail（1.00），不增加渲染星星数，仅控制全局视差强度。MainForm 的深度由其内部 `CurrentInternalDepth` 属性动态决定，使跨视图切换返回 MainForm 时星场能落在正确的内部视图层级。

在对话框视觉方面，V1.5.29.0 将 5 个对话框窗口根 `UserControl` 移除 `Background` 属性（默认 null，不参与命中测试，鼠标事件穿透到壳星场），并移除 IAuroraOverlay 接口、PushOverlay/PopOverlay/RemoveOverlay 方法与 OverlayLayer Grid 全套 Overlay 基础设施。

在性能优化方面，V1.5.29.0 用"极光层 +50% alpha 增强"替代"近景星辉光"作为视差视觉反馈——固定开销、与星星数无关，避免原方案在大量星星时严重掉帧。

V1.5.29.0 通过以下核心策略实现了全面升级：

- **视差深度重塑**：7 级深度映射，消除三个"无视差"分支
- **对话框视觉统一**：5 个对话框背景透明化，Overlay 架构移除
- **权限时序前置**：ElevationDialog 从主窗体内部前置到 Splash 之后
- **UWP 动效精准匹配**：UWP 标准曲线，语言切换通知顺序重排
- **状态文本修复**：重试机制 + 布局检查 + X 上界检查
- **交互防抖统一**：ViewManager.IsNavigating 统一导航锁，5 个入口防重入
- **视差性能优化**：跳过 SoftGlow/DiffractionSpike，极光层 +50% 增强

本次更新是一个"视差深度全面重塑、对话框视觉统一、权限流程解耦、UWP 动效精准匹配、交互防抖统一"的版本。所有面向用户的命令行接口、环境变量和跨 Runspace 通信协议均保持完全兼容，确保现有脚本和工作流无需修改即可运行。

---

## 2. P1 级别：星场视差多层深度重塑

P1 级别的变更是将原 4 级深度方案扩展为 7 级深度映射。

### P1-1: 7 级深度映射

**问题**：原 4 级深度方案存在三个"无视差"分支：Splash（0.0）↔ MainForm（0.0）同处最深处、ProMode（0.35）↔ SmartMode（0.35）同处一个深度、MainForm 内部 view1（0.0）↔ view2（0.1）差值过小，导致这些切换几乎看不到星场变化。

**修复**：`ViewManager.GetViewDepth` 按视图类型返回 7 级深度值：SplashScreenView=0.00、MainFormView=CurrentInternalDepth（view1=0.15 / view2=0.30）、ProModeView=0.50、SmartModeView=0.60、ExportHistoryView/UndoViewerView/ElevationDialogView/SessionRestoreDialogView=0.85、SolutionDetailView=1.00。

**原因**：原 4 级方案深度差过小或同深度，视差不可见。

**影响范围**：`ViewManager.cs` GetViewDepth。

---

### P1-2: MainForm 内部动态深度

**变更**：`MainFormView.CurrentInternalDepth` 属性根据 `_viewModel.CurrentState` 动态返回：view1（LanguageSelection）=0.15、view2（ModeSelection）=0.30。使跨视图切换返回 MainForm 时星场能落在正确的内部视图层级。

**原因**：MainForm 内部两个视图需要不同的深度，否则返回 MainForm 时星场层级错误。

**影响范围**：`MainFormView.xaml.cs` CurrentInternalDepth。

---

### P1-3: 视差强度系数增强

**变更**：`AuroraStarfield.cs` 调整两个视差强度系数：径向位移系数 0.18 → 0.28（`pushAmount = parallaxSmooth * depth * 0.28`）、透明度衰减系数 0.5 → 0.62（`starOpacityMul = 1.0 - parallaxSmooth * depth * 0.62`）。

**原因**：原系数深度差异在视觉上不明显。

**影响范围**：`AuroraStarfield.cs` 视差绘制路径。

---

### P1-4: 视差时长动态对齐与 targetPhase 插值

**变更**：`StartParallaxCycle` 接收 `targetPhase` 参数，从 `_parallaxStartPhase` 平滑插值到 `_parallaxTargetPhase`。`ViewManager` 在 NavigateTo/NavigateBack 中计算 `targetPhase = GetViewDepth(newView/previous)` 并传入。视差总时长由 `ViewManager` 根据目标视图的退场 + 入场动画实际总时长动态计算（V1.5.28.7）。

**原因**：视差需要与视图切换动画完全同步。

**影响范围**：`AuroraStarfield.cs` StartParallaxCycle、`ViewManager.cs` NavigateTo/NavigateBack。

---

## 3. P2 级别：对话框视觉统一与 Overlay 架构移除

P2 级别的变更是 5 个对话框背景透明化并移除 Overlay 基础设施。

### P2-1: 对话框背景透明化

**问题**：5 个对话框窗口（ElevationDialogView、SessionRestoreDialogView、UndoViewerView、ExportHistoryView、SolutionDetailView）背景为不透明或半透明色，与 ProModeView/SmartModeView/MainFormView 的透明背景视觉割裂。

**修复**：5 个对话框根 `UserControl` 移除 `Background` 属性（默认 null）。默认 null 比 `Transparent` 更彻底：不仅视觉透明，还不参与命中测试，鼠标事件直接穿透到壳星场。

**原因**：对话框需要与主视图视觉一致，让全局星空贯穿。

**影响范围**：5 个对话框 `.xaml` 文件。

---

### P2-2: Overlay 基础设施移除

**变更**：移除全套 Overlay 基础设施：IAuroraOverlay 接口、PushOverlay/PopOverlay/RemoveOverlay 方法（从 ViewManager.cs）、OverlayLayer Grid（从 MainWindow.xaml）。MainWindow.xaml 现仅保留 AuroraStarfield 与 ContentControl 两个子元素。仅保留 IAuroraStaggerView 接口用于错峰入场动效。

**原因**：Overlay 架构与新的透明对话框方案冲突，且增加架构复杂度。

**影响范围**：`MainWindow.xaml`、`ViewManager.cs`、5 个对话框 `.cs` 文件。

---

## 4. P3 级别：权限选择时序前置

P3 级别的变更是将权限选择从主窗口内部前置到 Splash 之后。

### P3-1: 新启动流程

**变更**：启动流程改为 App 启动 → MainWindow 壳创建 → NavigateTo<SplashScreenView> → SplashScreen LoadingComplete → 检测 IsCurrentProcessElevated → 已提权直接 NavigateToMainForm / 未提权 ShowElevationDialogDirectly → ElevationDialogView（深度 0.85）→ OnElevationResult 处理 Elevate/ContinueNormal/Exit。

**原因**：权限选择原占用主窗口视图槽位，与主流程耦合。

**影响范围**：`App.xaml.cs` 启动流程。

---

### P3-2: 关键方法实现

**变更**：`SplashScreenView` 新增 ShowMainWindow（根据 IsCurrentProcessElevated 分流）、ShowElevationDialogDirectly（从 Splash 直接导航到 ElevationDialogView）、OnElevationResult（处理 Elevate/ContinueNormal/Exit）、NavigateToMainFormFromElevation（用 `NavigateTo<MainFormView>(true, true)` replaceCurrent 弹出 Elevation 并压入 MainForm，触发 0.85 → 0.15 深度视差）。

**原因**：权限对话框作为独立视图参与星场视差深度链路。

**影响范围**：`SplashScreenView.xaml.cs` ShowMainWindow/ShowElevationDialogDirectly/OnElevationResult/NavigateToMainFormFromElevation。

---

## 5. P4 级别：UWP 文本过渡曲线与语言切换修复

P4 级别的变更是采用 UWP 标准曲线并修复语言切换通知顺序。

### P4-1: UWP 标准过渡曲线

**变更**：`MainFormView.PlayElementSwitch` 采用 UWP 标准速度曲线：exitSpline=(0.7, 0.0, 0.3, 1.0) 退出曲线、enterSpline=(0.1, 0.9, 0.2, 1.0) 入场曲线、settleSpline=(0.45, 0.05, 0.55, 0.95) 收敛曲线。参数：exitMs=320、enterMs=640、overMs=420、位移 ±52px、退出缩放 0.92、过冲 1.08。

**原因**：原过渡曲线过于突兀，不够 UWP 风格。

**影响范围**：`MainFormView.xaml.cs` PlayElementSwitch。

---

### P4-2: 语言切换通知顺序重排

**问题**：`MainFormViewModel.OnSelectLanguage` 原顺序为 `SelectedLanguage → IsBusy → CurrentState（触发 AnimateViewTransition）→ OnPropertyChanged`，导致 `SmartModeInfoTitle` 等绑定在切换动画播放期间仍显示旧语言缓存。

**修复**：将全部 16 个 `OnPropertyChanged(...)` 通知前置到 `CurrentState` 赋值之前。包括 5 个按钮文本、2 个语言面板字段、4 个语言说明字段、4 个模式说明字段，最后才执行 `IsBusy = true` 与 `CurrentState = MainFormViewState.ModeSelection`。

**原因**：通知顺序错误导致动画期间显示旧语言。

**影响范围**：`MainFormViewModel.cs` OnSelectLanguage。

---

### P4-3: 缓存实例语言刷新

**问题**：ProModeView 与 SmartModeView 在 `_initialized=true`（NavigationCache 复用）时不刷新语言，导致从英文菜单点击智能模式或专业模式仍显示中文缓存。

**修复**：`ProModeView.Initialize` 与 `SmartModeView.Initialize` 新增 `language` 参数，在 `_initialized` 守卫之前同步刷新 `_viewModel.Language`。SmartModeView 在复用缓存实例时提前 return。

**原因**：缓存实例未同步刷新语言。

**影响范围**：`ProModeView.xaml.cs` Initialize、`SmartModeView.xaml.cs` Initialize。

---

## 6. P5 级别：智能模式状态文本位置修复

P5 级别的变更是修复智能模式 UWP 状态文本被挤压到右下角飞出的问题。

### P5-1: 重试机制与三层保护

**问题**：SmartModeView 的 UWP 状态文本（StatusText）在壳入场动画期间，因 `ProgressAnchor.ActualHeight/ActualWidth` 尚未完成布局，位置计算返回错误坐标，导致文本被定位到右下角甚至飞出可视区域。

**修复**：`BeginInvokeUpdateStatusTextPositionWithRetry` 加入三层保护：重试机制（最多 25 次、80ms 间隔，覆盖 1000ms 壳入场动画）、布局完成检查（`ActualHeight/ActualWidth <= 0` 返回 false）、自身缩放检查（`Math.Abs(s - 1.0) > 0.01` 返回 false）、X 上界检查（`targetX < ActualWidth`）。`UpdateStatusTextPosition` 在 `success == false` 时调度下一次重试定时器。

**原因**：壳入场动画期间布局未完成，位置计算错误。

**影响范围**：`SmartModeView.xaml.cs` BeginInvokeUpdateStatusTextPositionWithRetry、UpdateStatusTextPosition。

---

### P5-2: 重试参数演进

**变更**：重试参数从初版（V1.5.28.9）的 5 次 / 50ms 间隔（覆盖 250ms，不足以覆盖 1000ms 壳动画）演进到当前（V1.5.28.17）的 25 次 / 80ms 间隔（覆盖 2000ms，完全覆盖 1000ms 壳动画）。

**原因**：初版重试不足以覆盖壳入场动画时长。

**影响范围**：`SmartModeView.xaml.cs` 重试参数。

---

## 7. P6 级别：键盘焦点与导航防抖统一

P6 级别的变更是修复键盘焦点问题并用统一导航锁根除快速切换闪回。

### P6-1: 键盘焦点修复

**问题**：`MainFormView.AttachInfoHover` 仅绑定 `MouseEnter` 事件，键盘 Tab 焦点切换到按钮时，右侧说明文本不更新。

**修复**：提取公共悬停逻辑为 `focusHandler`，`MouseEnter` 与 `GotFocus` 共用同一处理器。5 个按钮（ChineseBtn、EnglishBtn、SmartModeBtn、ProModeBtn、ConsoleModeBtn）均同时绑定两个事件。

**原因**：仅绑定 MouseEnter 导致键盘焦点无响应。

**影响范围**：`MainFormView.xaml.cs` AttachInfoHover。

---

### P6-2: 统一导航锁

**问题**：ProModeView 使用本地 `_isSwitching` 标志防抖，其他视图无防抖，导致快速切换时退场动画被中断、`DiscreteDoubleKeyFrame` 起始值跳变，产生闪回。

**修复**：用 `ViewManager.IsNavigating` 公共属性（暴露内部 `_isNavigating` 字段）建立统一导航锁。ProModeView 移除本地 `_isSwitching` 标志，统一用 `ViewManager.IsNavigating`。所有导航入口在动画期间拒绝新请求。

**原因**：本地标志防抖不一致导致闪回。

**影响范围**：`ViewManager.cs` IsNavigating、`ProModeView.xaml.cs`。

---

### P6-3: 5 个导航入口防重入检查

**变更**：5 个导航入口加入 `if (ViewManager.Current.IsNavigating) return;` 防重入检查：SmartModeView 的 OnReturnToProRequested 与 OnShowUndoViewerRequested、ExportHistoryView 的 OnCloseRequested 与 OpenSolutionDetail、SolutionDetailView 的 OnCloseRequested。此外 ProModeView 的 OnShowHistoryRequested（886 行）与另一处导航（910 行）也使用同一守卫（V1.5.28.23）。

**原因**：退场动画期间的新导航请求导致闪回。

**影响范围**：`SmartModeView.xaml.cs`、`ExportHistoryView.xaml.cs`、`SolutionDetailView.xaml.cs`、`ProModeView.xaml.cs`。

---

## 8. P7 级别：星场视差性能优化（极光层 +50%）

P7 级别的变更是修复视差期间严重掉帧并用极光层增强替代星辉光。

### P7-1: 跳过 SoftGlow 与 DiffractionSpike

**问题**：原方案在视差期间为近景星星启用 SoftGlow（柔和辉光）与 DiffractionSpike（衍射星芒），但两者开销与星星数线性相关——`DrawSoftGlow` 每颗星星都要 PushTransform + DrawGeometry，在大量星星时导致严重掉帧。

**修复**：视差期间（`isParallaxCycling == true`）SoftGlow 与 DiffractionSpike 两个分支均被跳过。

**原因**：星辉光开销与星星数线性相关，导致掉帧。

**影响范围**：`AuroraStarfield.cs` DrawStars 的 SoftGlow/DiffractionSpike 分支。

---

### P7-2: DrawAurora 极光层 +50% alpha 增强

**变更**：作为视觉反馈替代，在 `DrawAurora` 极光层引入 +50% alpha 增强。视差期间（`_parallaxState == ParallaxState.Cycling`）计算 `parallaxBoost = 1.0 + pSmooth * 0.5`（最大 1.5），应用到每个极光 wisp 的 `localAlpha`。开销固定，与星星数无关。

**原因**：需要与星星数无关的视觉反馈替代星辉光。

**影响范围**：`AuroraStarfield.cs` DrawAurora 的 parallaxBoost 计算。

---

### P7-3: smoothstep 平滑过渡（V1.5.28.27）

**问题**：原 `parallaxBoost` 使用 `_viewParallaxPhase`（深度位置）作为动画进度，但 `_viewParallaxPhase` 是最终深度目标（如 0.15→0.30），不是动画进度 t（0→1）。导致 MainForm view1→view2 过渡时 `phase` 永久 < 0.25 总在"ramp-up"段无 ramp-down，且视差结束状态从 Cycling 切换到 Idle 时 `parallaxBoost` 从 1.5 跳回 1.0 产生亮度跳变。

**修复**：`parallaxBoost` 改用实际动画时间进度 `t`（0→1）配合 smoothstep 计算梯形曲线：ramp up 0→25%（pSmooth 0→1，parallaxBoost 1.0→1.5）、hold 25-75%（pSmooth=1，parallaxBoost=1.5）、ramp down 75-100%（pSmooth 1→0，parallaxBoost 1.5→1.0）。

**原因**：原实现导致亮度跳变与 MainForm 内部过渡异常。

**影响范围**：`AuroraStarfield.cs` DrawAurora 的 parallaxBoost 计算逻辑。

---

## 9. 兼容性保持

V1.5.29.0 在视差深度重塑与对话框视觉统一的同时，在以下方面保持了完全兼容：

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
| 星场星星数 | 视差深度重塑不增加渲染星星数，仅控制全局视差强度 |
| 对话框接口 | 对话框对外公共接口不变，仅内部背景与 Overlay 实现移除 |

---

## 10. 变更清单总览

| 编号 | 级别 | 变更描述 | 变更原因 | 影响范围 |
|------|------|----------|----------|----------|
| P1-1 | P1 | 7 级深度映射 | 原 4 级方案三个"无视差"分支 | ViewManager GetViewDepth |
| P1-2 | P1 | MainForm 内部动态深度 | 返回 MainForm 时星场层级正确 | MainFormView CurrentInternalDepth |
| P1-3 | P1 | 视差强度系数增强（0.18→0.28、0.5→0.62） | 原系数深度差异不明显 | AuroraStarfield 视差绘制 |
| P1-4 | P1 | 视差时长动态对齐与 targetPhase 插值 | 视差与视图切换动画同步 | AuroraStarfield StartParallaxCycle/ViewManager NavigateTo |
| P2-1 | P2 | 5 个对话框背景透明化 | 与主视图视觉一致 | 5 个对话框 .xaml |
| P2-2 | P2 | Overlay 基础设施移除 | 架构复杂度与透明方案冲突 | MainWindow.xaml/ViewManager.cs/5 个对话框 .cs |
| P3-1 | P3 | 新启动流程（Splash→Elevation→MainForm） | 权限与主流程解耦 | App.xaml.cs 启动流程 |
| P3-2 | P3 | SplashScreenView 关键方法实现 | 权限对话框参与视差深度链路 | SplashScreenView ShowMainWindow/ShowElevationDialogDirectly/OnElevationResult/NavigateToMainFormFromElevation |
| P4-1 | P4 | UWP 标准过渡曲线 | 原曲线过于突兀 | MainFormView PlayElementSwitch |
| P4-2 | P4 | 语言切换通知顺序重排 | 动画期间显示旧语言缓存 | MainFormViewModel OnSelectLanguage |
| P4-3 | P4 | 缓存实例语言刷新 | 缓存实例未同步语言 | ProModeView/SmartModeView Initialize |
| P5-1 | P5 | 状态文本重试机制与三层保护 | 壳动画期间布局未完成 | SmartModeView BeginInvokeUpdateStatusTextPositionWithRetry/UpdateStatusTextPosition |
| P5-2 | P5 | 重试参数演进（5/50ms → 25/80ms） | 初版重试不足 | SmartModeView 重试参数 |
| P6-1 | P6 | 键盘焦点修复（focusHandler 共用） | 仅 MouseEnter 导致键盘无响应 | MainFormView AttachInfoHover |
| P6-2 | P6 | 统一导航锁（IsNavigating） | 本地标志防抖不一致 | ViewManager IsNavigating/ProModeView |
| P6-3 | P6 | 5 个导航入口防重入检查 | 退场动画期间新导航导致闪回 | SmartModeView/ExportHistoryView/SolutionDetailView/ProModeView |
| P7-1 | P7 | 跳过 SoftGlow/DiffractionSpike | 星辉光开销与星星数线性相关 | AuroraStarfield DrawStars |
| P7-2 | P7 | DrawAurora 极光层 +50% alpha 增强 | 固定开销替代星辉光 | AuroraStarfield DrawAurora |
| P7-3 | P7 | smoothstep 平滑过渡（V1.5.28.27） | 原实现亮度跳变 | AuroraStarfield DrawAurora parallaxBoost |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *本工具仅供个人学习使用。请遵守当地法律法规。*
