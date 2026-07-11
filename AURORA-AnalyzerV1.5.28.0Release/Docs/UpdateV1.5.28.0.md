# AURORA Analyzer V1.5.28.0 更新说明

> **Windows 事件日志导出与智能诊断工具**
>
> 版本：V1.5.28.0Release · 构建时间：2026.07.10 · 作者：AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **警告**：本工具仅用于个人学习使用。请遵守当地法律法规。

---

## 目录

1. [版本概述](#1-版本概述)
2. [P1 级别：完全统一的极光动效设计](#2-p1-级别完全统一的极光动效设计)
3. [P2 级别：全新统一设计的视图布局](#3-p2-级别全新统一设计的视图布局)
4. [P3 级别：智能模式专属视图 SmartModeView](#4-p3-级别智能模式专属视图-smartmodeview)
5. [P4 级别：全新历史视图 ExportHistoryView](#5-p4-级别全新历史视图-exporthistoryview)
6. [P5 级别：全新解决方案视图 SolutionDetailView](#6-p5-级别全新解决方案视图-solutiondetailview)
7. [P6 级别：视图切换与窗口交接机制](#7-p6-级别视图切换与窗口交接机制)
8. [P7 级别：缺陷修复](#8-p7-级别缺陷修复)
9. [P8 级别：功能逻辑审计批量修复](#9-p8-级别功能逻辑审计批量修复)
10. [兼容性保持](#10-兼容性保持)
11. [变更清单总览](#11-变更清单总览)

---

## 1. 版本概述

V1.5.28.0 是 AURORA Analyzer 的视图体系与动效语言全面重塑版本。本次更新覆盖五大核心领域：完全统一的极光动效设计、全新统一设计的视图布局、智能模式全新的专属视图、全新的历史视图、全新的解决方案视图。PowerShell 引擎层保持兼容，所有命令行参数、环境变量接口和 syncHash 同步机制均维持不变。

在动效统一方面，V1.5.28.0 将此前各视图参差不齐的入场/退场/切换参数收敛为统一契约：窗口入场统一为 Scale 1.15→1.0（600ms AuroraCustomBackEase EaseOut）+ Opacity 0→1（600ms CubicEase EaseOut）；窗口退场统一为蓄力 1.0→0.97（80ms）→放大离开 0.97→1.15（720ms）+ 淡出 800ms；控件交错入场统一为 80ms 交错 + 450ms 主动画（0→1.07）+ 525ms 果冻收敛（1.07→1.0）；模态进出统一为三通道 UWP 动画；所有视图配备 1500ms 兜底定时器。

在视图布局方面，V1.5.28.0 为所有视图建立了统一的布局语汇：无边框透明窗口外壳、AuroraStarfield 星空背景层、AuroraFrostedGlassBorder 玻璃容器、3:2 左右分栏、极光自绘滚动条、统一的模态覆盖层模式。

V1.5.28.0 通过以下核心策略实现了全面升级：

- **动效统一**：所有视图的窗口级、控件级、模态级动效收敛为统一参数契约，覆盖入场、退场、切换、交错入场、模态进出全生命周期
- **布局统一**：建立无边框透明窗口 + 星空背景 + 玻璃容器 + 3:2 分栏 + 极光滚动条的统一布局语汇
- **SmartModeView 独立窗口**：从 ProModeView 内嵌面板重构为 1000×700 独立窗口，控制台与可执行修复项左右分栏，圆角玻璃模态
- **ExportHistoryView 全新视图**：历史归档列表 + 健康概览 + 指纹信号 + 当前对比检测入口
- **SolutionDetailView 全新视图**：指标对比表格 + 解决方案列表 + 规则详情 + 一键修复执行入口
- **窗口交接机制**：ProMode↔SmartMode、ExportHistory↔SolutionDetail 采用独立窗口交接，避免双 ViewModel 冲突
- **缺陷修复**：ConsoleBox 背景放大、SmartMode 键名不匹配、PROENGINE 误触发 SmartEngine

本次更新是一个"视图体系全面重塑、动效语言完全统一、底层接口保持兼容"的版本。所有面向用户的命令行接口、环境变量和跨 Runspace 通信协议均保持完全兼容，确保现有脚本和工作流无需修改即可运行。

---

## 2. P1 级别：完全统一的极光动效设计

P1 级别的变更是将所有视图的动效统一到同一套参数契约。

### P1-1: 窗口级入场动效统一

所有窗口（SplashScreenView、MainFormView、ProModeView、SmartModeView、ExportHistoryView、SolutionDetailView、ElevationDialogView、SessionRestoreDialogView、PerformanceUpgradeDialogView、PermissionInfoView）的入场统一为 ScaleTransform 1.15→1.0（600ms AuroraCustomBackEase EaseOut）+ Opacity 0→1（600ms CubicEase EaseOut）。Window 级别 RenderTransformOrigin=0.5,0.5，TransformGroup 内含 ScaleTransform + TranslateTransform。XAML 预设 ScaleTransform ScaleX=1.15 ScaleY=1.15 避免首帧闪烁。入场期间 StarfieldBg.IsWindowAnimating=true 锁定星空降级渲染。

**变更原因**：此前各窗口入场起始缩放参差不齐（1.08、1.1、1.15、0.92），缓动曲线也不统一。统一后所有窗口共享同一入场视觉语言。

**影响范围**：所有视图的窗口入场动画。

---

### P1-2: 窗口级退场动效统一

所有窗口的退场统一为"蓄力—放大离开—淡出"三段式：蓄力 Scale 1.0→0.97（80ms QuadraticEase EaseOut）→放大离开 0.97→1.15（720ms QuadraticEase EaseOut）+淡出 Opacity 1→0（800ms CubicEase EaseOut）。退场流程设置 IsHitTestVisible=false 防止重复触发，StarfieldBg.IsWindowAnimating=true 锁定星空，完成后执行收尾回调。

**变更原因**：此前部分窗口退场为缩小消退（1.0→0.85），与放大冲出方向相反。统一为放大冲出后，所有窗口的退场呈现"化为星光远去"的统一视觉语言。

**影响范围**：所有视图的窗口退场动画。

---

### P1-3: 控件级交错入场动效统一

所有视图的控件交错入场统一为 80ms 交错 + 450ms 主动画 + 525ms 果冻收敛。相邻 tile 延迟 80ms（staggerMs=80），主动画 Scale 0→1.07（450ms CubicEase EaseOut），Opacity 0→1（450ms CubicEase EaseOut），Y 偏移 100→0。果冻收敛 1.07→1.0（525ms QuarticEase EaseOut）。玻璃材质 tile 的 Scale 起点从 0 改为 1.0（避免逐帧模糊纹理重计算抖动）。

**变更原因**：此前各视图的控件交错入场参数不一致（staggerMs 30/80，durationMs 320/450，过冲目标 1.0/1.07）。统一后所有视图的控件入场节奏一致。

**影响范围**：SmartModeView、ExportHistoryView、SolutionDetailView、ProModeView 等所有视图的控件交错入场。

---

### P1-4: 模态对话框动效统一

模态覆盖层（ModalOverlay、UserInputOverlay、MessageOverlay）的进出动效统一为三通道 UWP 动画。入场：覆盖层 Opacity 0→1，内容 Scale 0.92→1.07→1.0（360ms CubicEase + 525ms QuarticEase 收敛），Y 24→0。退场：内容 Scale 1.0→0.97 蓄力（80ms）→0.97→1.15 离开（720ms），Y 0→-16，覆盖层 Opacity 1→0（800ms CubicEase EaseOut）。

**变更原因**：此前各视图的模态动效参数不一致。统一后所有模态对话框共享同一进出动效语言。

**影响范围**：SmartModeView.AnimateModalOverlay、ExportHistoryView.ShowGlassMessage/ShowGlassConfirm、SolutionDetailView 模态方法。

---

### P1-5: 1500ms 兜底定时器

所有视图的控件交错入场均配备 1500ms 兜底定时器。触发后强制停止所有 tile 动画，重置 Opacity=1、ScaleX/ScaleY=1.0、Translate X/Y=0。

**变更原因**：当 Dispatcher 定时器因线程繁忙或窗口 Hide/Show 未触发时，ScaleTransform 卡在中间值导致 ConsoleBox 背景放大缺陷。兜底定时器强制重置变换状态，从根本上消除该问题。

**影响范围**：SmartModeView、ExportHistoryView、SolutionDetailView、ProModeView 等所有视图的控件交错入场。

---

### P1-6: 视图切换动效

ProModeView 与 SmartModeView、ExportHistoryView 与 SolutionDetailView 之间的视图切换采用专属切换动效。切出（PlaySwitchOutAnimation）：Scale 1.0→0.97 蓄力（80ms）→0.97→1.15 离开（720ms）+ Opacity 1→0（800ms），完成回调构造目标窗口。切入（PlaySwitchInAnimation）：Scale 1.1→1.0（600ms CubicEase EaseOut）+ Opacity 0→1（500ms CubicEase EaseOut），重新注册 AuroraMaterialPipeline 背景源，恢复轮询。

**变更原因**：视图切换需要区别于冷启动入场的更轻量再入场曲线。切入使用 1.1 起始缩放（而非 1.15）和 CubicEase 缓动（而非 AuroraCustomBackEase）。

**影响范围**：ProModeView.PlaySwitchOutAnimation/PlaySwitchInAnimation、ExportHistoryView.OpenSolutionDetail。

---

## 3. P2 级别：全新统一设计的视图布局

P2 级别的变更是为所有视图建立统一的布局语汇。

### P2-1: 无边框透明窗口外壳统一

所有视图共享无边框透明窗口外壳：WindowStyle=None、AllowsTransparency=True、Background=Transparent、ResizeMode=NoResize、RenderTransformOrigin=0.5,0.5，预装 TransformGroup（ScaleTransform + TranslateTransform）。窗口尺寸约定：MainForm 400×480、SplashScreen 420×190、Elevation/ProMode 750×750、PermissionInfo 520×520、SmartMode/ExportHistory/SolutionDetail 1000×700。

**变更原因**：统一窗口外壳确保所有视图的视觉骨架一致。

**影响范围**：所有视图的窗口定义。

---

### P2-2: AuroraStarfield 星空背景层统一

AuroraStarfield 作为所有视图的通用背景层，同时是 AuroraMaterialPipeline 的注册背景源。暴露 IsWindowAnimating 属性，在窗口动画期间切换到降级渲染模式。

**变更原因**：统一星空背景层确保所有视图的背景视觉一致，并提供动画期间的性能优化机制。

**影响范围**：所有视图的背景层。

---

### P2-3: AuroraFrostedGlassBorder 玻璃容器统一

所有内容分区使用 AuroraFrostedGlassBorder 毛玻璃容器（裸用 CornerRadius=8 用于内容分区，AuroraFrostedGlassCard 样式 CornerRadius=12 用于模态对话框），渲染 4 层玻璃效果。

**变更原因**：统一玻璃容器确保所有视图的内容分区视觉一致。

**影响范围**：所有视图的内容容器。

---

### P2-4: 3:2 左右分栏布局

SmartModeView、ExportHistoryView、SolutionDetailView 三个全新视图的主内容区统一采用 3:2 左右分栏（列定义 3*/12/2*）。

**变更原因**：统一分栏比例确保三个全新视图的布局节奏一致。

**影响范围**：SmartModeView、ExportHistoryView、SolutionDetailView 的主内容区。

---

### P2-5: 极光自绘滚动条统一

统一的 AuroraScrollBarStyle + AuroraScrollViewerStyle 在 SmartModeView、ExportHistoryView、SolutionDetailView、ProModeView 中复用。

**变更原因**：统一滚动条确保所有视图的滚动交互细节一致。

**影响范围**：SmartModeView、ExportHistoryView、SolutionDetailView、ProModeView 的滚动条。

---

### P2-6: 模态覆盖层模式统一

所有主要视图共享模态覆盖层模式：根级 Grid Background=#800A1428 Visibility=Collapsed，内含 AuroraFrostedGlassBorder 应用 AuroraFrostedGlassCard 样式，内部 3 行网格（标题 + 可滚动正文 + 确认/取消按钮行）。

**变更原因**：统一模态覆盖层确保所有视图的对话框视觉一致。

**影响范围**：所有主要视图的模态对话框。

---

## 4. P3 级别：智能模式专属视图 SmartModeView

P3 级别的变更是将智能模式从 ProModeView 内嵌面板重构为 1000×700 独立窗口。

### P3-1: SmartModeView 独立窗口架构

SmartModeView 重构为 1000×700 无边框透明独立窗口，WindowStartupLocation=CenterScreen。根 Grid 层叠 AuroraStarfield 星空背景 + Margin=24 内容区，4 行定义：标题栏（Auto）/左右分栏主体（*）/进度条（Auto）/底部操作栏（Auto）。

**变更原因**：原内嵌面板空间受限，独立窗口提供更专注、更宽敞的操作空间。

**影响范围**：SmartModeView.xaml、SmartModeView.xaml.cs。

---

### P3-2: SmartModeView 左右分栏布局

主体区 3:2 左右分栏（3*/12/2*）。左栏 ConsoleGlass：AuroraFrostedGlassBorder（CornerRadius=8）包裹 AuroraConsoleBox，控制台固定高度等于主体全高确保 BlurLayer 采样稳定。右栏 MenuGlass：AuroraFrostedGlassBorder（CornerRadius=8，Padding=14,12）含菜单标题 + ScrollViewer 中的 ItemsControl 绑定 SmartMenuItems。

**变更原因**：左右分栏布局让控制台输出与可执行修复项并排展示，信息获取更高效。

**影响范围**：SmartModeView.xaml 主体区布局。

---

### P3-3: SmartModeView 菜单项卡片布局

每个 SmartMenuItem 通过 DataTemplate 渲染为两行卡片。第一行命令信息：索引号（13pt 加粗 #82B4E1FF）+ 命令名（13pt 白色，截断）+ "✓"执行标记（14pt 加粗 #60E090）。第二行规则名+标签：规则名（11pt #8090A8）+ 标签 StackPanel（RiskLevelText #A0C4E0、AdminTag #E0B060、AuthTag #60C080）。状态样式 DataTrigger：IsExecuted=True→Opacity 0.4，IsExecuting=True→Opacity 0.6。

**变更原因**：两行卡片布局让每个修复项的命令信息和规则标签一目了然。

**影响范围**：SmartModeView.xaml 菜单项 DataTemplate。

---

### P3-4: SmartModeView 圆角玻璃模态

ModalOverlay 和 UserInputOverlay 的 ModalGlass/UserInputGlass 升级为 AuroraFrostedGlassCard 样式（CornerRadius=12）。ModalOverlay：Padding=28，MinWidth=400，MaxWidth=580，MaxHeight=520。UserInputOverlay：MinWidth=400，MaxWidth=520，含 TextBox（Consolas 13pt）。

**变更原因**：圆角玻璃模态与整体视觉语言保持一致。

**影响范围**：SmartModeView.xaml 模态覆盖层。

---

### P3-5: ShowSmartModeRequested 事件模式

ProModeViewModel 触发 ShowSmartModeRequested 事件取代原 IsSmartMenuVisible 标志。ProModeView.OnShowSmartModeRequested 播放 PlaySwitchOutAnimation，完成回调构造 SmartModeView 并 Show，设置 smartView.Owner=this，订阅 smartView.Closed += OnSmartModeClosed。

**变更原因**：事件模式解耦 ViewModel 与 View，避免 ViewModel 直接控制视图可见性。

**影响范围**：ProModeViewModel.cs、ProModeView.xaml.cs。

---

## 5. P4 级别：全新历史视图 ExportHistoryView

P4 级别的变更是创建全新的日志历史管理视图。

### P4-1: ExportHistoryView 布局设计

1000×700 无边框透明窗口，WindowStartupLocation=CenterOwner。根 Grid 层叠 AuroraStarfield（StarCount=100）+ Margin=24 内容区，3 行定义：标题栏（BackBtn + TitleLabel）/主体 3:2 左右分栏/底部操作栏（DetectBtn/ExportBtn/OpenDirBtn/DeleteBtn）。

**变更原因**：提供独立的日志历史管理界面。

**影响范围**：ExportHistoryView.xaml、ExportHistoryView.xaml.cs（新增文件）。

---

### P4-2: 历史列表展示

左栏 ListSection（AuroraFrostedGlassBorder CornerRadius=8）：标题行 + ListBox 绑定 Entries/SelectedEntry。每条记录 ItemTemplate 渲染：归档时间（11pt 加粗白色）+ 健康分数彩色 Ellipse（8×8）+ LogType + 健康分数数值 + 事件计数序列（CriticalEvents 红色"C"、ErrorEvents 琥珀色"E"、WarningEvents 强调色"W"）。ListBoxItem 模板 Border CornerRadius=6，悬停 #22FFFFFF，选中 #33FFFFFF + AuroraAccentBrush 边框。

**变更原因**：让每条历史记录的关键信息一目了然。

**影响范围**：ExportHistoryView.xaml 历史列表区。

---

### P4-3: 历史详情与健康概览

右栏 DetailSection（AuroraFrostedGlassBorder CornerRadius=8）：顶部 HealthOverviewPanel（Border 背景 #11000000 CornerRadius=6 Padding 14,10）展示健康分数大数值（28pt 加粗 + 彩色 Ellipse）、等级/日志类型/日期范围、Critical/Error/Warning 计数列。底部 DetailScrollViewer 两张卡片：基本信息卡（归档时间/总事件数/文件列表）+ 指纹信息卡（StrongSignals EventId|Source×Count、WeakSignals Keyword×Count、Hash 字符串）。

**变更原因**：提供历史归档的完整详情和指纹信号信息。

**影响范围**：ExportHistoryView.xaml 历史详情区。

---

### P4-4: 检测与对比入口

底部 DetectBtn 触发 DetectCurrentCommand，执行扫描 + 指纹匹配产生 MatchBundle。ShowMatchResult 构建详细文本包含五部分：概览、上下文对比、强信号对比（命中/未命中 [√]/[×] 及历史/当前计数）、弱信号对比、修复方案/说明。匹配成功且有解决方案 → Yes/No 确认玻璃对话框 → "Yes"调用 OpenSolutionDetail。

**变更原因**：提供当前日志与历史归档的指纹匹配对比能力。

**影响范围**：ExportHistoryView.xaml.cs DetectCurrentCommand、ShowMatchResult、OpenSolutionDetail。

---

## 6. P5 级别：全新解决方案视图 SolutionDetailView

P5 级别的变更是创建全新的解决方案详情视图。

### P5-1: SolutionDetailView 布局设计

1000×700 无边框透明窗口，WindowStartupLocation=CenterOwner。根 Grid 层叠 AuroraStarfield（StarCount=100）+ Margin=24 内容区，3 行定义：标题栏（TitleLabel + CloseBtn）/主体 3:2 左右分栏/底部操作栏（ExecuteFixButton + CloseButton）。

**变更原因**：提供独立的解决方案详情展示界面。

**影响范围**：SolutionDetailView.xaml、SolutionDetailView.xaml.cs（新增文件）。

---

### P5-2: 对比表格

左栏 CompareSection（AuroraFrostedGlassBorder CornerRadius=8）：3 列对比表格（指标/历史/当前），4 行数据（Health 按 HistoryHealthBrush/CurrentHealthBrush 着色、EventCount、Critical AuroraErrorBrush、Error AuroraWarningBrush）+ 匹配分数行 + SolutionList ListBox（每项 Rule.RuleId + Rule.Name + MatchScore P0 格式）。

**变更原因**：清晰展示历史与当前的指标差异和匹配的解决方案。

**影响范围**：SolutionDetailView.xaml 对比区。

---

### P5-3: 规则详情与修复命令

右栏 DetailSection（AuroraFrostedGlassBorder CornerRadius=8）含 DetailScrollViewer，展示选中规则完整信息：规则名（15pt 加粗）+ RuleId/Severity/Priority + Description/Causes/Solutions/RecommendedAction（null 门控）+ 修复命令 ItemsControl（每条命令在 #11FFFFFF 圆角 Border 中展示 Name+TypeText+RiskLevel+Consolas CommandText+ElevationText+ExecuteModeText）。

**变更原因**：提供规则的完整详情和修复命令信息。

**影响范围**：SolutionDetailView.xaml 详情区。

---

### P5-4: 方案切换动效

选择不同解决方案触发 PlaySolutionDetailTransition（方向性滑动）：退出 200ms Scale 1.0→0.97 + Translate 0→-12*dir + Opacity 1→0；进入 680ms Scale 0.97→1.025→1.0 + Translate 32*dir→0 + Opacity 0→1，KeySplines (0.7,0,0.9,0.4)/(0.05,0.85,0.15,1)/(0.30,0,0.55,1)。同时触发 PlaySolutionItemFeedback（列表项 1.0→1.035→1.0 微回弹）。

**变更原因**：让方案切换充满质感。

**影响范围**：SolutionDetailView.xaml.cs PlaySolutionDetailTransition、PlaySolutionItemFeedback。

---

### P5-5: 一键修复执行

ExecuteFixCommand 打开 FixExecutionDialog，提供一键执行选中规则的所有修复命令，并支持通过 Undo 管理器回滚操作（基于 FixExecutionService）。

**变更原因**：提供从诊断到修复的完整闭环。

**影响范围**：SolutionDetailView.xaml.cs ExecuteFixCommand。

---

## 7. P6 级别：视图切换与窗口交接机制

P6 级别的变更是采用独立的窗口交接机制取代原地的可见性切换。

### P6-1: 独立窗口 ViewModel 交接

模式切换使用"隐藏宿主 + 显示从属窗口 + 关闭后恢复"模式：宿主视图播放切出动效后 Hide，构造从属窗口设置 Owner=宿主，从属窗口接管 syncHash 交互避免双 ViewModel 冲突，从属窗口关闭时宿主恢复（Show + 切入动效 + 重新注册 AuroraMaterialPipeline 背景源 + 恢复轮询）。

**变更原因**：原地可见性切换会导致双 ViewModel 同时操作 syncHash 产生冲突。独立窗口交接机制让每个视图拥有独立的 ViewModel 和 syncHash 交互周期。

**影响范围**：ProModeView↔SmartModeView、ExportHistoryView↔SolutionDetailView 切换。

---

### P6-2: ProModeView ↔ SmartModeView 切换

ProModeViewModel 触发 ShowSmartModeRequested → ProModeView.OnShowSmartModeRequested 播放 PlaySwitchOutAnimation → 完成回调构造 SmartModeView 并 Show → SmartModeView.OnWindowLoaded 调用 StartPolling 播放入场动效 → 返回时 SmartModeView.PlayWindowExitAnimation 退场并 Close → ProModeView.OnSmartModeClosed 播放 PlaySwitchInAnimation 重新注册背景源恢复轮询。

**变更原因**：SmartModeView 独立窗口需要完整的切换生命周期管理。

**影响范围**：ProModeView.xaml.cs OnShowSmartModeRequested、OnSmartModeClosed；SmartModeView.xaml.cs OnWindowLoaded、PlayWindowExitAnimation。

---

### P6-3: ExportHistoryView ↔ SolutionDetailView 切换

ExportHistoryView.OpenSolutionDetail 播放退场动效（Scale 1.0→1.15 + Opacity 1→0，500ms CubicEase）后 Hide → 构造 SolutionDetailView ShowDialog → SolutionDetailView 关闭后 ExportHistoryView 恢复（Show + Scale 1.15→1.0 + Opacity 0→1，500ms）。

**变更原因**：SolutionDetailView 独立窗口需要完整的切换生命周期管理。

**影响范围**：ExportHistoryView.xaml.cs OpenSolutionDetail。

---

### P6-4: 背景源重注册

切入动效完成时调用 AuroraMaterialPipeline.Current.SetBackgroundSource(StarfieldBg) 重新注册玻璃材质背景源。

**变更原因**：窗口 Hide 期间背景源可能失效，重注册确保玻璃材质能正确采样星空背景。

**影响范围**：ProModeView.PlaySwitchInAnimation、ExportHistoryView 恢复逻辑。

---

## 8. P7 级别：缺陷修复

P7 级别的变更涵盖本次版本中修复的关键缺陷。

### P7-1: ConsoleBox 背景放大问题

**问题**：AURORACONSOLE 在缩小后背景工作出现视觉异常，背景被放大了好几倍。根因是 ConsoleBox 入场动画的 ScaleTransform 残留——动画使用两个 DispatcherTimer 实现 0→1.07→1.0 的缩放效果，但当定时器因 Dispatcher 繁忙或窗口 Hide/Show 未触发时，ScaleTransform 卡在中间值（如 0 或 1.07），原兜底定时器仅重置 Opacity 未重置缩放，导致 BlurLayer 的 CroppedBitmap 裁剪区域过小，拉伸后产生放大效果。

**修复**：在 ProModeView.xaml.cs 的兜底定时器中，除重置 Opacity=1 外，额外添加 ScaleTransform.ScaleX/ScaleY=1.0 和 TranslateTransform.Y=0 的强制重置。该修复随后升级为所有视图统一的 1500ms 兜底定时器机制。

**原因**：入场动画定时器未触发时 ScaleTransform 残留中间值。

**影响范围**：ProModeView.xaml.cs 兜底定时器；所有视图的控件交错入场。

---

### P7-2: SmartMode 键名不匹配导致回显失败

**问题**：SmartModeViewModel 的 syncHash 键名与 SmartEngine 实际键名不匹配，导致授权信号失败、SmartEngine 阻塞在 WaitOne(30000) 30 秒超时，对话框因 Hashtable 解析错误显示空白。

**修复**：纠正 ProcessSyncHashSnapshot 中的键名（如 SmartAnalysisAuthRequired → SmartAnalysisRequested、RequiresDecision → RequiresAuthorization，移除 MenuWaiting），新增 RequiresElevation 检测和 InputType=="UseExportedLogs" 分支。修复 CloseModal 授权信号。修复对话框显示（ShowDecisionModal 的 PendingCommand 解析、ShowResultModal 的 resultObj.ToString() 正确解析 ActionName/Result/Output/ExecutionTime，新增 ShowElevationModal 和 ShowExportedLogsModal）。

**原因**：ViewModel 与 Engine 的 syncHash 键名不一致。

**影响范围**：SmartModeViewModel.cs ProcessSyncHashSnapshot、CloseModal、ShowDecisionModal、ShowResultModal、ShowElevationModal、ShowExportedLogsModal。

---

### P7-3: PROENGINE 误触发 SmartEngine

**问题**：在 PROENGINE 运行后返回主窗口，再运行先前执行过的 SMARTENGINE 时，错误地启动智能模式视图。根因是 PowerShell 会话中残留的 syncHash.SmartMenuItems 数据。

**修复**：在 ProModeViewModel 的 StartAnalysisAsync 方法中添加清理逻辑——每次新分析会话开始时清除 SmartMenuItems、ExecutedMenuIndices，重置签名，设置 IsSmartMenuVisible=false。

**原因**：PowerShell 会话中残留的智能菜单数据导致误触发。

**影响范围**：ProModeViewModel.cs StartAnalysisAsync。

---

## 9. P8 级别：功能逻辑审计批量修复

P8 级别的变更涵盖基于功能逻辑审计报告的 28 项批量修复（5 高 / 15 中 / 7 低），覆盖窗口切换与生命周期管理、Engine 通信与 syncHash 一致性、命令状态与 CanExecute、动画状态、数据绑定与集合线程安全五大领域。所有修复均已通过 MSBuild v4.0.30319 编译验证，零错误。

### P8-1: SmartModeViewModel ScriptComplete→ScriptDone 键名修复（P0）

**问题**：SmartModeViewModel.ProcessSyncHashSnapshot 检测 `snapshot.ContainsKey("ScriptComplete")`，但 AURORA-SmartEngine.ps1 实际写入的是 `$global:syncHash.ScriptDone`。键名不匹配导致 SmartModeViewModel 永远检测不到脚本完成，IsRunning 可能永远为 true。

**修复**：将 `"ScriptComplete"` 改为 `"ScriptDone"`，并调用新增的 OnScriptComplete() 方法。

**原因**：ViewModel 与 Engine 的 syncHash 键名不一致。

**影响范围**：SmartModeViewModel.cs ProcessSyncHashSnapshot。

---

### P8-2: SmartModeViewModel 缺失 OnScriptComplete 完整逻辑（P0）

**问题**：ProModeViewModel.OnScriptComplete() 包含完整完成逻辑（清理 RequiresUserInput、更新 UI、MarkAllTasksSuccess、完成对话框、归档），但 SmartModeViewModel 完全没有 OnScriptComplete 方法，检测到完成时仅执行 `IsScriptComplete = true; IsRunning = false;`。

**修复**：新增 OnScriptComplete() 方法，对齐 ProModeViewModel 实现：清除 RequiresUserInput/RequiresAuthorization/RequiresElevation 残留、Progress=100、MarkAllTasksSuccess、显示完成提示对话框。

**原因**：SmartModeViewModel 完成流程缺失清理和 UI 更新。

**影响范围**：SmartModeViewModel.cs OnScriptComplete、MarkAllTasksSuccess。

---

### P8-3: PlaySwitchInAnimation 重入保护失效（P0）

**问题**：PlaySwitchInAnimation 入口仅检查 `if (_isSwitching) return;` 但未设置 `_isSwitching = true`，500ms 淡入动画期间重入保护形同虚设。用户快速点击"历史"或"返回智能模式"按钮时，PlaySwitchOutAnimation 被调用中断正在播放的 fadeIn 动画，导致 IsHitTestVisible=true 和 IsWindowAnimating=false 永远不执行。

**修复**：入口立即设置 `_isSwitching = true`，在 fadeIn.Completed 回调和 catch 块中重置 `_isSwitching = false`。

**原因**：重入保护标志未在入口设置。

**影响范围**：ProModeView.xaml.cs PlaySwitchInAnimation。

---

### P8-4: PlaySwitchOutAnimation fadeOut.Completed 不触发导致窗口永久隐藏（P0）

**问题**：PlaySwitchOutAnimation 的 fadeOut.Completed 回调负责重置 `_isSwitching = false` 和执行 onComplete。如果 fadeOut 被外部代码中断（如 PlayWindowExitAnimation），Completed 事件不触发，ProModeView 卡在 Opacity=0、不可见、不可交互状态。

**修复**：增加 900ms 兜底 DispatcherTimer（fadeOut 800ms + 100ms 容差），若 Completed 未触发则强制执行清理和 onComplete。

**原因**：WPF 动画被中断时 Completed 事件不触发。

**影响范围**：ProModeView.xaml.cs PlaySwitchOutAnimation。

---

### P8-5: ProModeViewModel 轮询切换竞态窗口（P1）

**问题**：SuspendPolling() 调用 StopSyncHashPolling() 内部 Dispose 掉 System.Threading.Timer，但 Timer.Dispose() 不等待正在执行的回调完成。约 50ms 竞态窗口内，ProModeViewModel 和 SmartModeViewModel 的 ProcessSyncHashSnapshot 可能先后执行同一份状态键，导致双重弹窗。

**修复**：添加 `private volatile bool _pollingSuspended;` 字段，SuspendPolling 先设 `_pollingSuspended = true` 再 StopSyncHashPolling，ProcessSyncHashSnapshot 入口检查 `if (_pollingSuspended) return;`。

**原因**：System.Threading.Timer.Dispose() 存在竞态窗口。

**影响范围**：ProModeViewModel.cs SuspendPolling/ResumePolling/ProcessSyncHashSnapshot。

---

### P8-6: SmartModeView 关闭后自动重开（P1）

**问题**：OnSmartModeClosed 调用 ResumePolling() 后，ProModeViewModel 重新轮询 syncHash。若 SmartEngine 在 SmartModeView 打开期间写入了新的 SmartMenuItems（签名变化），ProcessSyncHashSnapshot 会调用 ScheduleSmartMenuVisibleDeferred(600) 自动重开 SmartModeView。

**修复**：在 OnSmartModeClosed 中调用新增的 `MarkJustReturnedFromSmartMode()` 方法设置 `_justReturnedFromSmartMode` 标志，ScheduleSmartMenuVisibleDeferred 的 timer 回调中检查此标志，若为 true 则跳过触发并重置标志。StartAnalysisAsync 中也重置此标志。

**原因**：SmartEngine 残留菜单签名变化导致自动重开。

**影响范围**：ProModeViewModel.cs MarkJustReturnedFromSmartMode/ScheduleSmartMenuVisibleDeferred/StartAnalysisAsync；ProModeView.xaml.cs OnSmartModeClosed。

---

### P8-7: ResumePolling 与 PlaySwitchInAnimation 时序不当（P1）

**问题**：OnSmartModeClosed 先调用 PlaySwitchInAnimation() 再调用 ResumePolling()，轮询回调可能在窗口淡入动画期间触发模态对话框。

**修复**：PlaySwitchInAnimation 增加 `Action onCompleteAfterFadeIn` 参数，ResumePolling 延迟到 fadeIn.Completed 回调中执行。catch 路径也执行回调。

**原因**：轮询与动画时序竞争。

**影响范围**：ProModeView.xaml.cs PlaySwitchInAnimation/OnSmartModeClosed。

---

### P8-8: SmartModeViewModel.IsRunning setter 未调用 InvalidateRequerySuggested（P1）

**问题**：SmartModeViewModel.IsRunning setter 仅调用 SetProperty，未调用 CommandManager.InvalidateRequerySuggested()，导致 ExecuteStopCommand 和 SmartMenuExecuteCommand 在 IsRunning 变化时不会立即重新评估。

**修复**：setter 中增加 `CommandManager.InvalidateRequerySuggested()`。

**原因**：与 ProModeViewModel.IsRunning setter 不一致。

**影响范围**：SmartModeViewModel.cs IsRunning setter。

---

### P8-9: OnShowHistoryRequested catch 分支 _isSwitching 卡死（P1）

**问题**：OnShowHistoryRequested 的 catch 块调用 Hide() 并创建 ExportHistoryView，若异常发生在 PlaySwitchOutAnimation 内部 `_isSwitching = true` 赋值之后，_isSwitching 仍为 true，OnHistoryViewClosed 中 PlaySwitchInAnimation 会因 `if (_isSwitching) return;` 直接返回，ProModeView 永久隐藏。

**修复**：catch 块中显式重置 `_isSwitching = false`。

**原因**：异常路径下标志未重置。

**影响范围**：ProModeView.xaml.cs OnShowHistoryRequested。

---

### P8-10: SmartModeViewModel 缺失 ResetAuthorizationModal/ShowSessionRecoveryHUD 处理（P2）

**问题**：ProModeViewModel 在 ProcessSyncHashSnapshot 中处理了 ResetAuthorizationModal 和 ShowSessionRecoveryHUD，但 SmartModeViewModel 中无匹配。这两个键在 SmartEngine 运行期间也可能被设置。

**修复**：ModalAction 枚举新增 SessionRestore；ProcessSyncHashSnapshot 新增 0a/0b 分支处理 ResetAuthorizationModal（强制关闭已显示模态）和 ShowSessionRecoveryHUD（显示会话恢复对话框）；新增 ShowSessionRestoreModal 方法；CloseModal 新增 SessionRestore 的 confirm/cancel 分支（写 SessionRestored=true 或 SessionRestarted=true）。

**原因**：SmartModeViewModel 与 ProModeViewModel syncHash 处理分支不对齐。

**影响范围**：SmartModeViewModel.cs ModalAction/ProcessSyncHashSnapshot/ShowSessionRestoreModal/CloseModal。

---

### P8-11: CancelAnalysis 无法中断 SmartEngine 的 WaitOne(30000)（P2）

**问题**：CancelAnalysis 仅调用 CancellationTokenSource.Cancel()，未调用 SignalAuthorizationEvent()。但 SmartEngine 的授权等待使用 EventWaitHandle.WaitOne(30000)，CancellationToken 无法中断 EventWaitHandle，用户取消后 SmartEngine 继续等待 30 秒超时。

**修复**：CancelAnalysis 中额外调用 `_psHost.SignalAuthorizationEvent()`，并设置 `Authorized=false`、`RequiresAuthorization=false`、`SmartAnalysisAuthorized=false`，让 SmartEngine 立即收到拒绝信号。

**原因**：EventWaitHandle 不可被 CancellationToken 中断。

**影响范围**：ProModeViewModel.cs CancelAnalysis。

---

### P8-12: SmartModeViewModel 首次轮询全量日志重放（P2）

**问题**：SmartModeViewModel._lastLogLength 初始化为 0，StartPolling 首次获取 snapshot 时 LogOutput 可能已包含 ProModeViewModel 运行期间累积的全部日志，全部历史日志作为 delta 处理导致控制台一次性涌入大量历史行。

**修复**：StartPolling 中首次轮询前读取当前 LogOutput 长度并赋值给 _lastLogLength，跳过历史日志只处理增量。

**原因**：_lastLogLength 未初始化为当前日志长度。

**影响范围**：SmartModeViewModel.cs StartPolling。

---

### P8-13: ProModeViewModel SuspendPolling 未停止 flush timer（P2）

**问题**：SuspendPolling() 仅停止 _syncHashTimer，未停止 _consoleFlushTimer。若 SuspendPolling 时 _pendingLines 中仍有待处理行，_consoleFlushTimer 会在 SmartModeView 打开期间继续修改 ConsoleLines。

**修复**：SuspendPolling 中增加 `StopConsoleFlushTimer()` 调用，ResumePolling 中增加 `StartConsoleFlushTimer()` 调用。

**原因**：SuspendPolling 未同步停止控制台刷新定时器。

**影响范围**：ProModeViewModel.cs SuspendPolling/ResumePolling。

---

### P8-14: SmartMenuItems Clear+Add 导致 UI 闪烁（P2）

**问题**：两个 ViewModel 在 SmartMenuItems 变化时先 Clear() 再循环 Add()，触发 1+N 次 CollectionChanged，每次都可能导致 UI 重布局。

**修复**：改为 `new ObservableCollection<SmartMenuItem>(items)` 一次性创建新集合并替换引用，通过 OnPropertyChanged 通知整体替换，UI 仅收到一次通知。

**原因**：Clear+Add 触发多次 CollectionChanged 导致闪烁。

**影响范围**：ProModeViewModel.cs ProcessSyncHashSnapshot；SmartModeViewModel.cs ProcessSyncHashSnapshot。

---

### P8-15: CanReturnToSmartMode 状态转换不完整（P2）

**问题**：CanReturnToSmartMode 在 ScheduleSmartMenuVisibleDeferred 中设为 true 后从不设为 false。SmartEngine 完成所有修复并退出后，用户点击"返回智能模式"会打开一个没有活动引擎的空 SmartModeView。

**修复**：OnScriptComplete 中设置 `CanReturnToSmartMode = false`。

**原因**：SmartEngine 退出后按钮未禁用。

**影响范围**：ProModeViewModel.cs OnScriptComplete。

---

### P8-16: TaskStates 不支持动态扩展（P2）

**问题**：两个 ViewModel 的 TaskStates 初始化为 4 个元素，若引擎写入 CurrentPipelineStep = 5，代码静默忽略，HUD 不更新。

**修复**：检测到 `step >= 0` 时先 `while (step >= TaskStates.Count) TaskStates.Add(Pending);` 动态扩展，再设置状态。

**原因**：TaskStates 固定长度无法适配引擎动态步骤。

**影响范围**：ProModeViewModel.cs ProcessSyncHashSnapshot；SmartModeViewModel.cs SyncTaskStates。

---

### P8-17: SmartModeViewModel.ConsoleLines 无行数上限保护（P2）

**问题**：SmartModeViewModel.OnConsoleFlush 每次最多处理 200 行，但没有对 ConsoleLines 总行数做上限保护。对比 ProModeViewModel.FlushPendingLines 有 `while (ConsoleLines.Count > 500) ConsoleLines.RemoveAt(0);` 的上限保护。

**修复**：OnConsoleFlush 末尾增加 `while (ConsoleLines.Count > 500) ConsoleLines.RemoveAt(0);`。

**原因**：与 ProModeViewModel 不一致，缺少内存上限保护。

**影响范围**：SmartModeViewModel.cs OnConsoleFlush。

---

### P8-18: EventWaitHandle 句柄泄漏（P2）

**问题**：ProModeViewModel.StartAnalysisAsync 每次调用 _psHost.CreateAuthorizationEvent()，内部每次都 new EventWaitHandle(...)，若上一次创建的 _authorizationEvent 未被 Dispose，旧句柄泄漏。

**修复**：CreateAuthorizationEvent 中先 Dispose 旧句柄再创建新的。

**原因**：未清理旧句柄直接创建新句柄。

**影响范围**：PowerShellHostService.cs CreateAuthorizationEvent。

---

### P8-19: ExportLogCommand CanExecute 不响应 ConsoleLines.Count 变化（P2）

**问题**：ExportLogCommand 的 CanExecute 为 `() => ConsoleLines != null && ConsoleLines.Count > 0`，ObservableCollection.Count 变化时不会自动触发 CommandManager.InvalidateRequerySuggested。

**修复**：OnConsoleFlush 批量添加行后调用 `CommandManager.InvalidateRequerySuggested()`。

**原因**：集合 Count 变化不自动刷新命令状态。

**影响范围**：SmartModeViewModel.cs OnConsoleFlush。

---

### P8-20: AuroraConsoleBox 右键复制报错（ExternalException）

**问题**：AuroraConsoleBox 右键"复制所有终端日志"触发 `Clipboard.SetText(text)`，内部不重试，剪贴板被其他进程锁定时抛出 System.Runtime.InteropServices.ExternalException（错误码 255,255,255）。

**修复**：改为 `Clipboard.SetDataObject(text, true)`，内部重试 10 次。添加 Debug.WriteLine 错误日志。

**原因**：Clipboard.SetText 不重试，剪贴板被占用时抛异常。

**影响范围**：AuroraConsoleBox.cs CopyAllToClipboard。

---

### P8-21: AuroraConsoleBox 右键菜单文字白色（全局隐式样式覆盖）

**问题**：AuroraConsoleBox 右键菜单文字视觉上为白色，多次修复无效。根因是 AuroraTheme.xaml 全局隐式 TextBlock 样式（Foreground=#E8F4FF）在 Application.Resources 中优先级最高。ContextMenu 是 Popup，Popup 的 Resources 查找链不经过 ContextMenu 本身，直接跳到 Application.Resources，所以在 contextMenu.Resources 中添加的隐式样式无法覆盖。

**修复**：不依赖隐式样式覆盖，直接在 MenuItem.Header 中使用 TextBlock 并显式设置 `Foreground = Brushes.Black`（本地值优先级最高，高于任何样式）。

**原因**：WPF Popup 的 Resources 查找链跳过 Popup 本身，隐式样式覆盖无效。

**影响范围**：AuroraConsoleBox.cs ContextMenu 构建逻辑。

---

### P8-22: SmartModeView UWP 状态文本未正确同步

**问题**：SmartModeView 的 StatusText 不随 SmartEngine 进度更新。根因是 SmartEngine 不写 `StatusText` 键，只写 `CurrentPipelineDetail` 和 `Progress`。

**修复**：ProcessSyncHashSnapshot 中 StatusText 从 `CurrentPipelineDetail` 派生，回退到 `Progress` 百分比（`{0:F0}%`）。

**原因**：ViewModel 期望的键名与 Engine 实际写入的键名不一致。

**影响范围**：SmartModeViewModel.cs ProcessSyncHashSnapshot。

---

### P8-23: PlaySwitchInAnimation 异常路径 _controlsAnimated 卡住（P3）

**问题**：_controlsAnimated 在 PlayControlEnterAnimation 入口设为 true 后永不重置。若动画失败且兜底 timer 也失败，控件永久不可见且无法重试。

**修复**：PlaySwitchInAnimation 中重置 `_controlsAnimated = false`，让控件入场动画在窗口恢复时重新播放。

**原因**：异常路径下标志未重置。

**影响范围**：ProModeView.xaml.cs PlaySwitchInAnimation。

---

## 10. 兼容性保持

V1.5.28.0 虽然视图体系发生了全面重塑，但在以下方面保持了完全兼容：

| 兼容项 | 说明 |
|--------|------|
| PowerShell 5.1 兼容 | C# 代码仍使用 C# 5.0 语言版本编译，确保在 PowerShell 5.1 环境中运行 |
| 命令行参数 | 所有命令行参数完全兼容，无新增或移除 |
| syncHash 同步机制 | 跨 Runspace 通信的 syncHash 接口完全兼容（SmartMode 内部键名已纠正为与 SmartEngine 一致） |
| 环境变量接口 | 所有环境变量接口完全兼容 |
| 脚本接口 | PowerShell 脚本引擎无需任何修改 |
| 材质管线 | V5 材质管线接口不变，AuroraFrostedGlassBorder/AuroraFrostedGlassCard 行为不变 |
| 动效接口 | 控件级动效方法签名不变，AnimationHelper 公共方法不变 |
| 玻璃材质捕获 | AuroraGlassMaterial 保持 30fps（SharedBgUpdateMs=33）、1/2 分辨率（CaptureScale=0.5）、BlurRadius=2.5 的精度配置 |

---

## 11. 变更清单总览

| 编号 | 级别 | 变更描述 | 变更原因 | 影响范围 |
|------|------|----------|----------|----------|
| P1-1 | P1 | 窗口级入场动效统一 | 各窗口入场参数参差不齐 | 所有视图窗口入场 |
| P1-2 | P1 | 窗口级退场动效统一 | 部分窗口退场方向相反 | 所有视图窗口退场 |
| P1-3 | P1 | 控件级交错入场动效统一 | 各视图控件入场参数不一致 | 所有视图控件交错入场 |
| P1-4 | P1 | 模态对话框动效统一 | 各视图模态动效参数不一致 | 所有视图模态对话框 |
| P1-5 | P1 | 1500ms 兜底定时器 | ScaleTransform 残留导致背景放大 | 所有视图控件交错入场 |
| P1-6 | P1 | 视图切换动效 | 切换需区别于冷启动的轻量再入场 | ProMode/ExportHistory 切换 |
| P2-1 | P2 | 无边框透明窗口外壳统一 | 统一视觉骨架 | 所有视图窗口定义 |
| P2-2 | P2 | AuroraStarfield 星空背景层统一 | 统一背景视觉 | 所有视图背景层 |
| P2-3 | P2 | AuroraFrostedGlassBorder 玻璃容器统一 | 统一内容分区视觉 | 所有视图内容容器 |
| P2-4 | P2 | 3:2 左右分栏布局 | 统一三个全新视图布局节奏 | SmartMode/ExportHistory/SolutionDetail |
| P2-5 | P2 | 极光自绘滚动条统一 | 统一滚动交互细节 | SmartMode/ExportHistory/SolutionDetail/ProMode |
| P2-6 | P2 | 模态覆盖层模式统一 | 统一对话框视觉 | 所有主要视图模态对话框 |
| P3-1 | P3 | SmartModeView 独立窗口架构 | 内嵌面板空间受限 | SmartModeView |
| P3-2 | P3 | SmartModeView 左右分栏布局 | 控制台与修复项并排展示 | SmartModeView 主体区 |
| P3-3 | P3 | SmartModeView 菜单项卡片布局 | 命令信息和规则标签一目了然 | SmartModeView 菜单项 DataTemplate |
| P3-4 | P3 | SmartModeView 圆角玻璃模态 | 与整体视觉语言一致 | SmartModeView 模态覆盖层 |
| P3-5 | P3 | ShowSmartModeRequested 事件模式 | 解耦 ViewModel 与 View | ProModeViewModel/ProModeView |
| P4-1 | P4 | ExportHistoryView 布局设计 | 提供独立历史管理界面 | ExportHistoryView |
| P4-2 | P4 | 历史列表展示 | 关键信息一目了然 | ExportHistoryView 历史列表区 |
| P4-3 | P4 | 历史详情与健康概览 | 提供完整详情和指纹信号 | ExportHistoryView 历史详情区 |
| P4-4 | P4 | 检测与对比入口 | 提供指纹匹配对比能力 | ExportHistoryView DetectCurrentCommand |
| P5-1 | P5 | SolutionDetailView 布局设计 | 提供独立解决方案界面 | SolutionDetailView |
| P5-2 | P5 | 对比表格 | 清晰展示指标差异和解决方案 | SolutionDetailView 对比区 |
| P5-3 | P5 | 规则详情与修复命令 | 提供规则完整详情 | SolutionDetailView 详情区 |
| P5-4 | P5 | 方案切换动效 | 让方案切换充满质感 | SolutionDetailView PlaySolutionDetailTransition |
| P5-5 | P5 | 一键修复执行 | 提供诊断到修复闭环 | SolutionDetailView ExecuteFixCommand |
| P6-1 | P6 | 独立窗口 ViewModel 交接 | 避免双 ViewModel syncHash 冲突 | ProMode↔SmartMode、ExportHistory↔SolutionDetail |
| P6-2 | P6 | ProModeView ↔ SmartModeView 切换 | SmartModeView 独立窗口生命周期 | ProModeView/SmartModeView 切换 |
| P6-3 | P6 | ExportHistoryView ↔ SolutionDetailView 切换 | SolutionDetailView 独立窗口生命周期 | ExportHistoryView/SolutionDetailView 切换 |
| P6-4 | P6 | 背景源重注册 | 窗口 Hide 期间背景源失效 | ProModeView.PlaySwitchInAnimation |
| P7-1 | P7 | ConsoleBox 背景放大问题修复 | ScaleTransform 残留中间值 | ProModeView 兜底定时器/所有视图控件入场 |
| P7-2 | P7 | SmartMode 键名不匹配修复 | ViewModel 与 Engine syncHash 键名不一致 | SmartModeViewModel |
| P7-3 | P7 | PROENGINE 误触发 SmartEngine 修复 | 残留智能菜单数据误触发 | ProModeViewModel.StartAnalysisAsync |
| P8-1 | P8 | ScriptComplete→ScriptDone 键名修复 | ViewModel 与 Engine 键名不一致 | SmartModeViewModel.ProcessSyncHashSnapshot |
| P8-2 | P8 | 新增 OnScriptComplete 完整逻辑 | 完成流程缺失清理和 UI 更新 | SmartModeViewModel.OnScriptComplete |
| P8-3 | P8 | PlaySwitchInAnimation 重入保护失效 | _isSwitching 未在入口设置 | ProModeView.PlaySwitchInAnimation |
| P8-4 | P8 | PlaySwitchOutAnimation 兜底定时器 | fadeOut.Completed 中断不触发 | ProModeView.PlaySwitchOutAnimation |
| P8-5 | P8 | 轮询切换竞态窗口修复 | Timer.Dispose() 存在竞态 | ProModeViewModel.SuspendPolling/ProcessSyncHashSnapshot |
| P8-6 | P8 | SmartModeView 关闭后自动重开修复 | 残留菜单签名变化误触发 | ProModeViewModel.ScheduleSmartMenuVisibleDeferred |
| P8-7 | P8 | ResumePolling 延迟到 fadeIn.Completed | 轮询与动画时序竞争 | ProModeView.PlaySwitchInAnimation/OnSmartModeClosed |
| P8-8 | P8 | IsRunning setter 调用 InvalidateRequerySuggested | 命令状态不立即刷新 | SmartModeViewModel.IsRunning setter |
| P8-9 | P8 | OnShowHistoryRequested catch 重置 _isSwitching | 异常路径下标志未重置 | ProModeView.OnShowHistoryRequested |
| P8-10 | P8 | 新增 ResetAuthorizationModal/ShowSessionRecoveryHUD 处理 | syncHash 处理分支不对齐 | SmartModeViewModel.ProcessSyncHashSnapshot/CloseModal |
| P8-11 | P8 | CancelAnalysis 调用 SignalAuthorizationEvent | EventWaitHandle 不可被 Cancel 中断 | ProModeViewModel.CancelAnalysis |
| P8-12 | P8 | StartPolling 初始化 _lastLogLength | 全量历史日志作为 delta 涌入 | SmartModeViewModel.StartPolling |
| P8-13 | P8 | SuspendPolling 停止 flush timer | 控制台刷新定时器未同步停止 | ProModeViewModel.SuspendPolling/ResumePolling |
| P8-14 | P8 | SmartMenuItems 批量替换避免闪烁 | Clear+Add 触发 N+1 次 CollectionChanged | 两个 ViewModel.ProcessSyncHashSnapshot |
| P8-15 | P8 | CanReturnToSmartMode 在 ScriptDone 后设 false | SmartEngine 退出后按钮未禁用 | ProModeViewModel.OnScriptComplete |
| P8-16 | P8 | TaskStates 动态扩展 | 固定长度无法适配引擎动态步骤 | 两个 ViewModel 的 TaskStates 处理 |
| P8-17 | P8 | ConsoleLines 上限保护 500 行 | 缺少内存上限保护 | SmartModeViewModel.OnConsoleFlush |
| P8-18 | P8 | EventWaitHandle 句柄泄漏修复 | 未清理旧句柄直接创建新句柄 | PowerShellHostService.CreateAuthorizationEvent |
| P8-19 | P8 | ExportLogCommand CanExecute 响应 Count 变化 | 集合 Count 变化不自动刷新命令状态 | SmartModeViewModel.OnConsoleFlush |
| P8-20 | P8 | AuroraConsoleBox 复制改用 SetDataObject | SetText 不重试，剪贴板被占用时抛异常 | AuroraConsoleBox.CopyAllToClipboard |
| P8-21 | P8 | AuroraConsoleBox 右键菜单文字白色修复 | Popup Resources 查找链跳过 Popup 本身 | AuroraConsoleBox.ContextMenu 构建 |
| P8-22 | P8 | SmartModeView 状态文本从 CurrentPipelineDetail 派生 | Engine 不写 StatusText 键 | SmartModeViewModel.ProcessSyncHashSnapshot |
| P8-23 | P8 | PlaySwitchInAnimation 重置 _controlsAnimated | 异常路径下标志未重置 | ProModeView.PlaySwitchInAnimation |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *本工具仅供个人学习使用。请遵守当地法律法规。*
