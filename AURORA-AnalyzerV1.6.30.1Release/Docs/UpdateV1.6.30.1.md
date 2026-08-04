# AURORA Analyzer V1.6.30.1 更新说明

> **Windows 事件日志导出与智能诊断工具**
>
> 版本：V1.6.30.1Release · 构建时间：2026.08.04 · 作者：AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **警告**：本工具仅用于个人学习使用。请遵守当地法律法规。

---

## 目录

1. [版本概述](#1-版本概述)
2. [解决方案视图执行窗口全面重构](#2-解决方案视图执行窗口全面重构)
3. [P0 级缺陷修复（6 项）](#3-p0-级缺陷修复6-项)
4. [P1 级缺陷修复（12 项）](#4-p1-级缺陷修复12-项)
5. [复合交叉审计新发现并修复的低危缺陷（3 项）](#5-复合交叉审计新发现并修复的低危缺陷3-项)
6. [历史分析与报告导出体验升级](#6-历史分析与报告导出体验升级)
7. [兼容性保持](#7-兼容性保持)
8. [变更清单总览](#8-变更清单总览)

---

## 1. 版本概述

V1.6.30.1 是 AURORA-Analyzer 在解决方案视图执行窗口优化基础上的"执行流程健壮性与回滚闭环完整性"专项加固版本。本次更新覆盖三大核心领域：解决方案视图执行窗口全面重构、完整审计修复（6 P0 + 12 P1 + 3 审计新发现低危缺陷）、GlassDialogAnimation 统一封装。

在执行窗口重构方面，V1.6.30.1 将解决方案视图执行界面升级为步骤时间线+日志双栏布局，引入 Process.Kill 整个进程树的取消机制、FailureAction.Abort/Continue/AskUser 三态失败处理、基于已执行命令平均耗时的进度插值与剩余时间预估，以及 EvaluatePreCheck 预校验过滤无可执行命令的方案。

在回滚闭环完整性方面，V1.6.30.1 修复了撤销失败不可重试、过期会话磁盘快照孤儿累积、终态保护缺失、Continue 模式不执行回滚命令留下脏状态等关键缺陷，确保撤销链路从触发到清理的全流程闭环。

在动画统一封装方面，V1.6.30.1 将 10 处玻璃弹窗内联动画统一迁移至 GlassDialogAnimation 工具类，消除 11+ 处重复实现，并为 ProModeView ModalOverlay 复用场景增加 onSafetyTimerCreated 回调重载。

V1.6.30.1 通过以下核心策略实现了全面升级：

- **解决方案视图执行窗口全面重构**：双栏布局、进程树取消、三态失败处理、进度预估、预校验过滤
- **P0 级缺陷修复（6 项）**：Unloaded 死锁、撤销不可重试、CTS 泄漏、_exitHandle 未 Dispose、退场无兜底、_pendingEnterTimers 未清空
- **P1 级缺陷修复（12 项）**：终态保护、磁盘快照清理、孤儿快照加载、成功语义矛盾、Continue 回滚、快照触发条件、注册表路径提取、取消令牌传递、事件取消订阅、GlassDialogAnimation 统一封装
- **复合交叉审计修复（3 项）**：空方案语义、终态 BackupSnapshotId 覆盖、Undo 后 UI 不刷新

本次更新是一个"执行流程健壮性根除死锁泄漏、回滚闭环完整性覆盖孤儿快照"的版本。所有面向用户的命令行接口、环境变量和跨 Runspace 通信协议均保持完全兼容，确保现有脚本和工作流无需修改即可运行。

---

## 2. 解决方案视图执行窗口全面重构

V1.6.30.1 对解决方案视图（SolutionDetailView）的执行窗口进行了全面重构，从单栏日志升级为步骤时间线+日志双栏布局，并引入进程树取消、三态失败处理、进度预估与预校验过滤四项核心机制。

### 2-1: 步骤时间线+日志双栏布局

**变更**：执行窗口升级为左侧步骤时间线、右侧实时日志的双栏布局。左侧时间线按执行顺序展示各步骤状态（待执行/执行中/成功/失败/跳过），右侧实时滚动展示命令输出日志。

**原因**：原单栏日志无法同时呈现执行进度与详细输出，用户需在进度与日志间反复切换视线。

**影响范围**：`SolutionDetailView.xaml.cs` 执行窗口布局。

---

### 2-2: 取消终止子进程（Process.Kill 整个进程树）

**变更**：取消执行时通过 Process.Kill 终止整个进程树，确保子进程不会在父进程取消后继续运行残留。

**原因**：原取消逻辑仅终止顶层进程，子进程仍持续运行并占用资源，导致取消后日志持续输出、进程句柄泄漏。

**影响范围**：`SolutionDetailView.xaml.cs` 取消逻辑。

---

### 2-3: 失败继续/中止选择（FailureAction 三态）

**变更**：引入 FailureAction.Abort/Continue/AskUser 三态失败处理模型。命令执行失败时，AskUser 弹窗询问用户选择 Abort（中止后续所有命令）或 Continue（跳过当前命令继续执行）。

**原因**：原失败处理仅支持中止，无法在非关键命令失败时继续执行后续步骤。

**影响范围**：`SolutionDetailView.xaml.cs` OnFixCommandFailure、`FixExecutionService.cs` ExecuteCommands。

---

### 2-4: 进度插值+预估时间

**变更**：基于已执行命令的平均耗时估算剩余时间，进度条在命令执行期间进行插值平滑推进，避免进度卡在某一步骤不动。

**原因**：原进度仅在命令完成后跳变，长时间命令执行期间进度条停滞，用户体验差。

**影响范围**：`SolutionDetailView.xaml.cs` 进度更新逻辑。

---

### 2-5: 预校验无可执行命令（EvaluatePreCheck 提前过滤）

**变更**：执行前调用 EvaluatePreCheck 预校验，提前过滤无可执行命令的方案，避免进入执行流程后才发现空方案。

**原因**：原方案在执行流程启动后才检测到无可执行命令，浪费资源且用户体验突兀。

**影响范围**：`FixExecutionService.cs` EvaluatePreCheck、`SolutionDetailView.xaml.cs` 执行入口。

---

## 3. P0 级缺陷修复（6 项）

P0 级别的变更是修复执行流程与视图生命周期中的死锁、泄漏与无兜底等高危缺陷。

### P0-1: OnFixCommandFailure Unloaded 死锁

**问题**：`SolutionDetailView.xaml.cs` OnFixCommandFailure 中 `_fixCts.Token.Register` 回调在 View Unloaded 后触发，token 已 Dispose 导致死锁。

**修复**：注册 `_fixCts.Token.Register(() => tcs.TrySetResult(FailureAction.Abort))`，catch `System.ObjectDisposedException` 直接 Abort；所有 `tcs.SetResult` 改为 `TrySetResult` 保证幂等。

**原因**：Token Register 回调在 Unloaded 后触发 ObjectDisposedException 未被捕获。

**影响范围**：`SolutionDetailView.xaml.cs` OnFixCommandFailure。

---

### P0-2: 撤销失败不可重试

**问题**：`RepairService.cs` UndoRepairSession 撤销失败时设 `CanUndo=false` 且 `Status=Failed`，用户无法重试撤销操作。

**修复**：撤销失败时保留 `CanUndo=true` 和原 Status（仅设 `FailureReason="UndoFailed"`）；CompleteRepairSession 过期清理联动磁盘快照清理（锁外执行）；App.OnStartup 调用 `CleanupExpiredSnapshots(7)` 清理孤儿快照。

**原因**：撤销失败后 CanUndo 被错误清除，且过期会话不清理磁盘快照导致孤儿累积。

**影响范围**：`RepairService.cs` UndoRepairSession / CompleteRepairSession、`App.OnStartup`。

---

### P0-3: 重试不清理旧 CTS 泄漏

**问题**：`SolutionDetailView.xaml.cs` ShowFixExecutionOverlay 重试时创建新 CTS 但未 Cancel+Dispose 旧实例。

**修复**：创建新 CTS 前 Cancel+Dispose 旧实例。

**原因**：重试场景旧 CTS 未清理导致 CancellationTokenSource 泄漏。

**影响范围**：`SolutionDetailView.xaml.cs` ShowFixExecutionOverlay。

---

### P0-4: 6 视图 _exitHandle 未在 OnUnloaded Dispose

**问题**：ProModeView/SmartModeView/SplashScreenView/ExportHistoryView/SolutionDetailView/SessionRestoreDialogView 的 `_exitHandle`（StaggerExitHelper 双定时器句柄）在 OnUnloaded 未 Dispose。

**修复**：6 个视图的 OnUnloaded 均添加 `_exitHandle.Dispose()`。

**原因**：ExitTimerHandle 内部 DispatcherTimer 未 Dispose 导致定时器泄漏。

**影响范围**：`ProModeView.xaml.cs`、`SmartModeView.xaml.cs`、`SplashScreenView.xaml.cs`、`ExportHistoryView.xaml.cs`、`SolutionDetailView.xaml.cs`、`SessionRestoreDialogView.xaml.cs` 的 OnUnloaded。

---

### P0-5: MainFormView.PlayStaggerExit 无 fallback 兜底

**问题**：`MainFormView.PlayStaggerExit` 依赖 PlayTitleExit 回调驱动后续流程，回调未触发时整个退场流程卡死。

**修复**：添加 `_exitHandle` 字段，PlayTitleExit 回调改为空 lambda，onCompleted+状态恢复由 StaggerExitHelper.ScheduleExit 调度；OnUnloaded Dispose `_exitHandle`。

**原因**：回调链断裂导致退场流程无兜底。

**影响范围**：`MainFormView.xaml.cs` PlayStaggerExit。

---

### P0-6: SolutionDetailView._pendingEnterTimers 在 OnUnloaded 未清空

**问题**：`SolutionDetailView._pendingEnterTimers` 列表中的 DispatcherTimer 在 OnUnloaded 未停止。

**修复**：OnUnloaded 添加 `CancelPendingEnterTimers()` 调用。

**原因**：入场定时器在视图卸载后仍触发导致状态异常。

**影响范围**：`SolutionDetailView.xaml.cs` OnUnloaded。

---

## 4. P1 级缺陷修复（12 项）

P1 级别的变更是修复回滚闭环、执行语义与事件订阅等中危缺陷。

### P1-1: CompleteRepairSession 终态保护

**问题**：`CompleteRepairSession` 不检查当前状态是否为终态，直接覆盖 Status/CanUndo。

**修复**：已是终态（Undone/Success/Failed/Cancelled/PartialSuccess）则仅更新 FinishedAt，不覆盖 Status/CanUndo/BackupSnapshotId。

**原因**：终态会话被非终态字段覆盖导致状态回退。

**影响范围**：`RepairService.cs` CompleteRepairSession。

---

### P1-2: 内存驱逐不清理磁盘快照

**问题**：`CompleteRepairSession` 过期清理内存会话时不清理对应的磁盘快照。

**修复**：过期清理时收集快照 ID，锁外调用 `UndoManagerService.RemoveBackupSnapshot`。

**原因**：内存会话驱逐后磁盘快照残留成为孤儿。

**影响范围**：`RepairService.cs` CompleteRepairSession。

---

### P1-3: UndoViewerViewModel.Refresh() 不加载磁盘快照

**问题**：进程重启后磁盘上的孤儿快照在 UndoViewer UI 不可见。

**修复**：`Refresh()` 中调用 `UndoManagerService.LoadAllSnapshots()` 加载磁盘孤儿快照，创建占位 RepairSessionInfo 展示（`RepairType.Custom` + `Target="OrphanedSnapshot"`）。

**原因**：UndoViewer 仅加载内存会话，磁盘孤儿快照对用户不可见导致无法手动清理。

**影响范围**：`UndoViewerViewModel.cs` Refresh()。

---

### P1-5: overallSuccess 与 PartialSuccess 矛盾

**问题**：全部跳过时 `overallSuccess=true` 但状态=`PartialSuccess`，语义矛盾。

**修复**：`overallSuccess = executedCount > 0 && successCount == executedCount && skippedCount == 0`。

**原因**：原 overallSuccess 计算未排除全部跳过场景，导致 PartialSuccess 状态下 overallSuccess 仍为 true。

**影响范围**：`FixExecutionService.cs` ExecuteCommands。

---

### P1-6: Continue 模式不执行 RollbackCommand

**问题**：Continue 模式跳过失败命令但不执行其 RollbackCommand，留下脏状态引发连锁失败。

**修复**：Continue 模式跳过失败命令前先执行其 RollbackCommand（若有）。

**原因**：跳过失败命令时未回滚已执行的副作用，后续命令在脏状态下执行引发连锁失败。

**影响范围**：`FixExecutionService.cs` ExecuteCommands。

---

### P1-7: 快照触发条件与注释不符

**问题**：`needSnapshot` 仅检查 RollbackCommand，未检查命令文本涉及注册表/文件/服务。

**修复**：`needSnapshot` 检查 RollbackCommand 或命令文本涉及 HKLM/HKCU/HKCR/HKU/HKCC/Set-Service/Start-Service/Stop-Service/sc.exe。

**原因**：快照触发条件覆盖不全，部分涉及系统状态变更的命令未触发快照，撤销时无回滚基线。

**影响范围**：`FixExecutionService.cs` ExecuteCommands。

---

### P1-8: 注册表路径提取简陋

**问题**：仅支持 HKLM/HKCU，分隔符不覆盖多语句命令，单次提取漏路径。

**修复**：支持 HKLM/HKCU/HKCR/HKU/HKCC 五大注册表驱动器，分隔符增加 `;` `\n` 覆盖多语句命令，循环提取所有匹配路径。

**原因**：注册表路径提取覆盖不全导致快照元数据缺失，撤销时无法精准定位注册表变更。

**影响范围**：`FixExecutionService.cs` ExtractRegistryPaths。

---

### P1-9: EvaluatePreCheck 传 CancellationToken.None

**问题**：pre_check 期间用户取消无效。

**修复**：传入实际 `cancellationToken` 替代 `CancellationToken.None`。

**原因**：预校验阶段忽略取消令牌导致用户无法中断长时间运行的 pre_check。

**影响范围**：`FixExecutionService.cs` EvaluatePreCheck。

---

### P1-10: ProModeView 事件未取消订阅

**问题**：ProModeView 9 个 ViewModel 事件在 OnUnloaded 未取消订阅。

**修复**：OnUnloaded 取消 ConsoleLines.CollectionChanged 订阅 + SuspendPolling（NavigationCache 复用模式下其他命令事件保留，OnLoaded 重新订阅 ConsoleLines）。

**原因**：NavigationCache 复用模式下事件订阅残留导致 ViewModel 与 View 生命周期错配，引发重复回调与内存泄漏。

**影响范围**：`ProModeView.xaml.cs` OnUnloaded/OnLoaded。

---

### P1-11: SmartModeView 事件未取消+SuspendPolling

**问题**：SmartModeView 6 个 ViewModel 事件未取消+未 SuspendPolling。

**修复**：OnUnloaded 取消 ConsoleLines.CollectionChanged + SuspendPolling，OnLoaded 重新订阅。

**原因**：事件订阅残留 + 轮询未挂起导致 ViewModel 持续轮询已卸载的 View，引发跨线程异常与资源浪费。

**影响范围**：`SmartModeView.xaml.cs` OnUnloaded/OnLoaded。

---

### P1-12/B4: GlassDialogAnimation 零调用

**问题**：GlassDialogAnimation 工具类零调用，11+ 处内联重复实现相同动画配方。

**修复**：10 处玻璃弹窗动画全部迁移至 GlassDialogAnimation（8 处 overlay+contentBorder 用 PlayGlassEnter/PlayGlassExit，2 处 Window 级用 PlayWindowExit）。PlayGlassExit 增加 `onSafetyTimerCreated` 回调重载，支持 ProModeView ModalOverlay 复用场景。

**原因**：工具类封装后零调用，11+ 处内联实现违反 DRY 原则，维护成本高且行为易不一致。

**影响范围**：`GlassDialogAnimation.cs`，SolutionDetailView×2/SmartModeView/ProModeView/UndoViewerView/ExportHistoryView/ElevationDialogView/SessionRestoreDialogView/ReportCompareView/TrendView/PasswordDialogView/PerformanceDiagnosticsView/PerformanceUpgradeDialogView。

---

## 5. 复合交叉审计新发现并修复的低危缺陷（3 项）

复合交叉审计在 P0/P1 修复基础上，通过跨模块交叉验证新发现 3 项低危缺陷并同步修复。

### 审计 A-1: 空方案状态/成功语义矛盾

**问题**：空方案（pre_check 全过滤）`isPartial` 未包含 `executedCount==0`，导致状态=`Success` 但 `overallSuccess=false`。

**修复**：`isPartial` 增加 `executedCount==0` 判断，空方案应为 PartialSuccess。

**原因**：空方案被误判为 Success 与 overallSuccess=false 矛盾，语义不一致。

**影响范围**：`FixExecutionService.cs` ExecuteCommands。

---

### 审计 B-1: 终态保护分支仍更新 BackupSnapshotId

**问题**：`CompleteRepairSession` 终态保护分支仍更新 BackupSnapshotId，UndoRepairSession 清理磁盘快照后延迟的 CompleteRepairSession 会重新设置已删除快照 ID。

**修复**：终态保护分支移除 BackupSnapshotId/RestorePointId 赋值，仅更新 FinishedAt。

**原因**：终态保护分支仍写快照 ID 导致已删除快照被重新引用，撤销链路出现悬空指针。

**影响范围**：`RepairService.cs` CompleteRepairSession。

---

### 审计 E-2: Undo 成功后 UI 不刷新

**问题**：`RepairSessionInfo` 是 POCO 不实现 INotifyPropertyChanged，Undo 成功后底层对象 Status/CanUndo 已变但 UI 绑定不感知。

**修复**：`Undo()` 成功后手动触发 SelectedSession/CanUndoSelected/IsSessionSelected 的 PropertyChanged。

**原因**：POCO 对象属性变更不通知 UI，导致撤销成功后界面状态与数据不一致。

**影响范围**：`UndoViewerViewModel.cs` Undo()。

---

## 6. 历史分析与报告导出体验升级

V1.6.30.1 对历史分析界面与报告导出对话框进行了 6 项体验升级，覆盖分析按钮合并、多选同步刷新、跨归档趋势数据源、报告格式互斥选择、报告导出双语适配、格式选项卡片鼠标反馈六个方向。

### H-1: 分析按钮合并与动态图标反馈

**变更**：将历史界面底部"趋势"和"时间线"两个按钮合并为统一的"分析"按钮，按钮文本和图标随选中归档数量动态切换（0 条→"分析"放大镜禁用，1 条→"时间线"时钟，≥2 条→"趋势"折线）。`AuroraButton` 扩展 `IconGeometry`/`IconSize`/`IconTextGap` 三个依赖属性支持图标+文本组合渲染，零分配热路径（`Geometry.Freeze` + 缓存 Brush/Pen），向后兼容（`IconGeometry` 默认 null）。

**原因**：原双按钮占用底部空间且需用户自行判断使用哪种分析视图。

**影响范围**：`AuroraButton.cs`、`ExportHistoryViewModel.cs`、`ExportHistoryView.xaml`。

---

### H-2: 多选同步刷新修复

**变更**：ViewModel 新增 `NotifySelectionBatchCompleted()` 公开方法，View 在 `ResumeSelectedEntriesNotifications()` 后调用，补刷按钮文本/图标/批量删除文本。

**原因**：`SuspendSelectedEntriesNotifications` 批量同步 `SelectedEntries` 期间 `CollectionChanged` 被挂起，导致 `OnSelectedEntriesChanged` 从未触发，按钮文本/图标不更新。

**影响范围**：`ExportHistoryViewModel.cs`、`ExportHistoryView.xaml.cs`。

---

### H-3: 跨归档趋势数据源修复

**变更**：`BuildTrendData` 数据源由 `_entries`（全部归档）改为 `_selectedEntries`（选中的归档）。

**原因**：原逻辑遍历全部归档而非选中的归档，导致选中 2 条归档却展示全量历史趋势。

**影响范围**：`ExportHistoryViewModel.cs`。

---

### H-4: 报告格式互斥选择修复

**变更**：`ReportFormatDialogView` 三个 RadioButton 添加 `GroupName="ReportFormatGroup"` 实现跨父容器互斥；配合 `SelectedFormat` setter 补发 `Is*Selected` 的 `PropertyChanged` 通知。

**原因**：三个 RadioButton 分属不同 Grid 父容器，WPF 默认互斥范围是同一父容器，导致互斥失效（点全亮）。

**影响范围**：`ReportFormatDialogView.xaml`、`ReportFormatDialogViewModel.cs`。

---

### H-5: 报告导出双语适配

**变更**：`ReportFormatDialogViewModel` 构造函数接收 `isChinese` 参数，新增 `IsChinese`/`LanguageName` 属性；View 中所有 `LanguageService.IsChinese`/`CurrentLanguageName` 改用 ViewModel 属性；`ExportHistoryView` 传入 `_viewModel.IsChinese`。语言传递链路统一：`ExportHistoryViewModel._language` → `ReportFormatDialogViewModel._isChinese` → `ReportGeneratorService` → `HtmlReportExporter`/`XlsxReportExporter`。

**原因**：`ReportFormatDialogViewModel` 依赖全局 `LanguageService.IsChinese`，而 `ExportHistoryViewModel` 用自己的 `_language` 字段，两者不同步导致主界面英文但对话框中文。

**影响范围**：`ReportFormatDialogViewModel.cs`、`ReportFormatDialogView.xaml.cs`、`ExportHistoryView.xaml.cs`。

---

### H-6: 格式选项卡片鼠标反馈

**变更**：选项卡片 `Background`/`BorderBrush` 改为命名 `SolidColorBrush`，用 `ColorAnimation`（200ms）实现 hover 渐亮/渐灭 + 选中态平滑过渡。四态色值：非选中基态(Bg #221E2D40, Border #551E2D40)、非选中 hover(Bg #331E2D40, Border #881E2D40)、选中基态(Bg #334DA0E8, Border #FF4DA0E8)、选中 hover(Bg #4450A8E8, Border #FF4DA0E8)。

**原因**：三个格式选项卡片无 hover 反馈，且 `HighlightSelectedOption` 每次 `new SolidColorBrush` 覆盖，视觉生硬且有 GC 压力。

**影响范围**：`ReportFormatDialogView.xaml`、`ReportFormatDialogView.xaml.cs`。

---

## 7. 兼容性保持

V1.6.30.1 在执行流程加固与回滚闭环完善的同时，在以下方面保持了完全兼容：

| 兼容项 | 说明 |
|--------|------|
| C# 5 语法 | C# 代码仍使用 C# 5.0 语言版本编译，无高版本语法依赖 |
| .NET Framework 4.x | 目标框架不变，构建工具链 MSBuild v4.8.9221.0 不变 |
| PowerShell 5.1 兼容 | PowerShell 脚本引擎接口与命令兼容性不变 |
| 命令行参数 | 所有命令行参数完全兼容，无新增或移除 |
| syncHash 同步机制 | 跨 Runspace 通信的 syncHash 接口完全兼容 |
| 环境变量接口 | 所有环境变量接口完全兼容 |
| IAuroraStaggerView 接口 | 接口签名不变，仅内部定时器管理与退场调度实现优化 |
| V5 材质管线 | V5 材质管线接口不变，AuroraFrostedGlassBorder/AuroraFrostedGlassCard 行为不变 |
| 玻璃材质捕获精度 | 精度配置不变（30fps/1/2 分辨率/BlurRadius=2.5） |
| GlassDialogAnimation 封装 | 动画配方与原内联实现完全一致，仅收口至工具类统一调用 |
| 回滚闭环 | 撤销接口与 RepairSessionInfo 结构不变，仅补全终态保护与孤儿清理 |

---

## 8. 变更清单总览

| 编号 | 级别 | 变更描述 | 变更原因 | 影响范围 |
|------|------|----------|----------|----------|
| 2-1 | 重构 | 步骤时间线+日志双栏布局 | 单栏无法同时呈现进度与输出 | SolutionDetailView 执行窗口布局 |
| 2-2 | 重构 | 取消终止子进程（Process.Kill 进程树） | 子进程残留导致句柄泄漏 | SolutionDetailView 取消逻辑 |
| 2-3 | 重构 | FailureAction.Abort/Continue/AskUser 三态失败处理 | 原仅支持中止无法继续后续步骤 | SolutionDetailView OnFixCommandFailure / FixExecutionService ExecuteCommands |
| 2-4 | 重构 | 进度插值+预估时间（基于平均耗时） | 长命令期间进度停滞 | SolutionDetailView 进度更新 |
| 2-5 | 重构 | EvaluatePreCheck 预校验过滤空方案 | 执行后才发现空方案体验突兀 | FixExecutionService EvaluatePreCheck / SolutionDetailView 执行入口 |
| P0-1 | P0 | OnFixCommandFailure Token.Register 改 TrySetResult + catch ObjectDisposedException | Unloaded 后 token Dispose 触发死锁 | SolutionDetailView OnFixCommandFailure |
| P0-2 | P0 | 撤销失败保留 CanUndo + 过期清理联动磁盘快照 + 启动清理孤儿快照 | 撤销不可重试且孤儿快照累积 | RepairService UndoRepairSession/CompleteRepairSession / App.OnStartup |
| P0-3 | P0 | 重试前 Cancel+Dispose 旧 CTS | 旧 CTS 未清理导致泄漏 | SolutionDetailView ShowFixExecutionOverlay |
| P0-4 | P0 | 6 视图 OnUnloaded 添加 _exitHandle.Dispose() | DispatcherTimer 未 Dispose 定时器泄漏 | ProModeView/SmartModeView/SplashScreenView/ExportHistoryView/SolutionDetailView/SessionRestoreDialogView OnUnloaded |
| P0-5 | P0 | MainFormView.PlayStaggerExit 添加 _exitHandle + StaggerExitHelper.ScheduleExit 调度 | 回调链断裂退场无兜底卡死 | MainFormView PlayStaggerExit |
| P0-6 | P0 | OnUnloaded 添加 CancelPendingEnterTimers() | 入场定时器卸载后仍触发 | SolutionDetailView OnUnloaded |
| P1-1 | P1 | CompleteRepairSession 终态保护仅更新 FinishedAt | 终态被非终态字段覆盖 | RepairService CompleteRepairSession |
| P1-2 | P1 | 过期清理锁外调用 RemoveBackupSnapshot | 内存驱逐后磁盘快照残留 | RepairService CompleteRepairSession |
| P1-3 | P1 | Refresh() 加载磁盘孤儿快照占位展示 | 进程重启后孤儿快照不可见 | UndoViewerViewModel Refresh() |
| P1-5 | P1 | overallSuccess 增加 executedCount>0 && skippedCount==0 判断 | 全部跳过时语义矛盾 | FixExecutionService ExecuteCommands |
| P1-6 | P1 | Continue 模式跳过前先执行 RollbackCommand | 跳过失败命令留下脏状态连锁失败 | FixExecutionService ExecuteCommands |
| P1-7 | P1 | needSnapshot 检查注册表/服务命令文本 | 快照触发条件与注释不符 | FixExecutionService ExecuteCommands |
| P1-8 | P1 | 注册表路径支持五大驱动器+多语句分隔符循环提取 | 路径提取简陋漏路径 | FixExecutionService ExtractRegistryPaths |
| P1-9 | P1 | EvaluatePreCheck 传实际 cancellationToken | 预校验期间取消无效 | FixExecutionService EvaluatePreCheck |
| P1-10 | P1 | ProModeView OnUnloaded 取消订阅+SuspendPolling | 9 个事件未取消订阅 | ProModeView OnUnloaded/OnLoaded |
| P1-11 | P1 | SmartModeView OnUnloaded 取消订阅+SuspendPolling | 6 个事件未取消+未挂起轮询 | SmartModeView OnUnloaded/OnLoaded |
| P1-12/B4 | P1 | 10 处玻璃弹窗动画迁移至 GlassDialogAnimation + onSafetyTimerCreated 重载 | 工具类零调用 11+ 处重复实现 | GlassDialogAnimation.cs + 12 个视图 |
| 审计A-1 | 审计 | isPartial 增加 executedCount==0 判断 | 空方案 Success 与 overallSuccess=false 矛盾 | FixExecutionService ExecuteCommands |
| 审计B-1 | 审计 | 终态保护分支移除 BackupSnapshotId/RestorePointId 赋值 | 已删除快照被重新引用 | RepairService CompleteRepairSession |
| 审计E-2 | 审计 | Undo() 成功后手动触发 PropertyChanged | POCO 不通知 UI 撤销后不刷新 | UndoViewerViewModel Undo() |
| H-1 | 体验升级 | 分析按钮合并+动态图标反馈（IconGeometry/IconSize/IconTextGap） | 双按钮占用空间且需用户自行判断分析视图 | AuroraButton.cs / ExportHistoryViewModel.cs / ExportHistoryView.xaml |
| H-2 | 修复 | NotifySelectionBatchCompleted 批量同步后补刷按钮文本/图标 | CollectionChanged 挂起导致 OnSelectedEntriesChanged 不触发 | ExportHistoryViewModel.cs / ExportHistoryView.xaml.cs |
| H-3 | 修复 | BuildTrendData 数据源改为 _selectedEntries | 遍历 _entries 全部归档而非选中归档 | ExportHistoryViewModel.cs |
| H-4 | 修复 | RadioButton 添加 GroupName 跨容器互斥 | 分属不同 Grid 父容器导致互斥失效 | ReportFormatDialogView.xaml / ReportFormatDialogViewModel.cs |
| H-5 | 修复 | ReportFormatDialogViewModel 接收 isChinese 参数统一语言链路 | 全局 LanguageService 与 ViewModel _language 不同步 | ReportFormatDialogViewModel.cs / ReportFormatDialogView.xaml.cs / ExportHistoryView.xaml.cs |
| H-6 | 体验升级 | 格式卡片命名 Brush+ColorAnimation hover 过渡 | 无 hover 反馈+new brush 覆盖生硬 | ReportFormatDialogView.xaml / ReportFormatDialogView.xaml.cs |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *本工具仅供个人学习使用。请遵守当地法律法规。*
