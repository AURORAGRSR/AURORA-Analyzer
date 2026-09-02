# AURORA Analyzer V1.6.30.5 更新说明

> **Windows 事件日志导出与智能诊断工具**
>
> 版本：V1.6.30.5Release · 构建时间：2026.09.02 · 作者：AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **警告**：本工具仅用于个人学习使用。请遵守当地法律法规。

---

## 目录

1. [版本概述](#1-版本概述)
2. [动效三轨道解耦与挡位开关系统](#2-动效三轨道解耦与挡位开关系统)
3. [壳层架构与设置/确认面板](#3-壳层架构与设置确认面板)
4. [启动直达与启动流程重构](#4-启动直达与启动流程重构)
5. [UI/UX 审计问题矩阵修复（16 项）](#5-uiux-审计问题矩阵修复16-项)
6. [动效白皮书四阶段落地](#6-动效白皮书四阶段落地)
7. [P0 级缺陷修复（4 项）](#7-p0-级缺陷修复4-项)
8. [P1 级体验打磨](#8-p1-级体验打磨)
9. [工程清理与构建修复](#9-工程清理与构建修复)
10. [兼容性保持](#10-兼容性保持)
11. [变更清单总览](#11-变更清单总览)

---

## 1. 版本概述

V1.6.30.5 是 AURORA-Analyzer 在**动效节奏统一性、壳层架构一致性、启动流程精简性**三大方向上的专项打磨版本，同时系统性修复《AURORA-UIUX-Audit-2026-09-01》审计报告的 16 项问题矩阵（I-01~I-16）与《现代动态响应与空间解耦动效系统架构技术白皮书 v2.1》的四阶段改造裁决。

### 1.1 审计基线

V1.6.30.1 Release 完成后的 UI/UX 深度审计给出综合得分 **6.1 / 10**，识别出三个 P0 级最大体验风险：

- **导航转场不可打断且拒绝新输入**：单次切换 2.6–2.9 秒输入黑洞（I-01）
- **每按钮每帧无条件重绘**：135 个 AuroraButton 实例各自订阅 `CompositionTarget.Rendering`（I-02）
- **高频启动仪式税**：每次 Splash→语言→模式强制 5–8 秒 + 2 次点击（I-03）

### 1.2 本版本核心策略

V1.6.30.5 通过以下核心策略实现了全面升级：

- **三轨道解耦 + 双挡位配方**：容器入场、星场视差、内部切换各自独立时序，新增“优雅/快速”两档配方
- **壳层架构重构**：MainWindow 统一壳层 + 右上角 [设置][退出] 按钮组 + 设置/确认面板三处复用
- **启动直达重构**：只存语言、Splash 后直达模式选择页，从根消除直达栈残留 BUG
- **UI/UX 审计 16 项问题系统性修复**：I-01 导航 900ms 可打断、I-02 渲染管线合并 + 静态早退、I-08 扫光意图判定、I-09 运行时重估、I-13 点击点生长等
- **白皮书四阶段落地**：核心转场配方化、HoldEnd 压制回归修正、星场视差独立、Cache 接力续接

### 1.3 兼容性约束

所有面向用户的命令行接口、环境变量、跨 Runspace 通信协议保持完全兼容，现有脚本和工作流无需修改即可运行。

---

## 2. 动效三轨道解耦与挡位开关系统

V1.6.30.5 把动画系统从“一刀切压缩”重构为“用户可选档位 × 轨道独立”的现代动效框架。审计报告 I-01 指出导航转场 2.6-2.9 秒不可打断、白皮书指出星场视差被前景时长绑死——这两个问题的根源都是**所有动画轨道被同一个总预算绑死**。

### 2-1: 三轨道解耦——视差不被转场时长绑死

**变更**：

- **ViewManager 容器入场**恢复旧版 800ms 优雅配方（V1.5.28.19 原配方）
- **`CalculateParallaxDuration`** 从硬编码 2700→900ms 改为读配方 `ParallaxFloorMs`（优雅 2200ms / 快速 900ms）
- 新增 `ParallaxTailMs` 尾程（优雅 1400ms）——星场在 UI 转场结束后继续滑完剩余深度，纵深连续不割裂

**审计/白皮书基线**：白皮书 0.1 现状账本指出旧版星场 2700ms 与转场 2700ms 绑死；I-01 修复一刀切压到 900ms 后星场穿梭感消失。

**影响范围**：`Services/ViewManager.cs` `CalculateParallaxDuration`、`PlayContainerEnter`。

---

### 2-2: 双挡位配方（优雅 800ms / 快速 450ms）

**变更**：新增 `MotionRecipe.Graceful/Fast` 两套预设：

| 字段 | 优雅档 | 快速档 |
|------|--------|--------|
| ContainerEnterMs | 800 | 450 |
| ContainerOvershootMs | 480 | 270 |
| TitleExitMs | 250 | 150 |
| TitleEnterMs | 400 | 200 |
| PanelEnterMs | 360 | 200 |
| StaggerMs | 80 | 25 |
| TileMs | 580 | 180 |
| ExitMs | 600 | 150 |
| GapMs | 80（接近旧版 200）| 20 |
| InitialTitleMs | 500 | 250 |
| ParallaxFloorMs | 2200 | 900 |
| ParallaxTailMs | 1400 | 0 |
| SuspendCaptureMs | 1000 | 500 |

**审计/白皮书基线**：审计 I-03 指出“唯一减压出口是系统级减少动效，应用内无用户可感知的动效档位开关”——本轮落地用户挡位。

**影响范围**：`Services/AuroraMotionSettings.cs` MotionRecipe 静态实例 + `EffectiveRecipe` 优先级链（系统减少动画 > Eco 档 > 用户挡位）。

---

### 2-3: 全局缩放工具 Scale()——约 50 处散点动效统一联动

**变更**：新增 `AuroraMotionSettings.Scale(ms)` 与 `FastFactor=0.35` 常量。本轮批量接入 40+ 处散点：

- **MainFormView.PlayStaggerExit**（硬编码 80/600/250/200——完全不跟随挡位，主诉根因）
- **7 处 `StaggerExitHelper.ScheduleExit` 预估时长**（Splash 800/1300、Smart 1200/1800、Pro 1400/2000、ExportHistory 1590/2200、SessionRestore 870/1400、SolutionDetail 1030/1600、MainForm 公式值）
- **Smart/Pro PlayControlExitAnimation 退场参数**（60/450）
- **`GlassDialogAnimation` 全部常量**（EnterScale/ExitWindup/ExitLeave/ExitFade/ExitSafety）
- **`AnimationHelper.PlayMainWindowEnter/Exit`**（壳入场/退场 660/800ms 关键帧）
- **7 个对话视图散点**（Elevation/ExportHistory/Trend/SolutionDetail/PerformanceDiagnostics/PerformanceUpgrade/ReportFormat）
- **Splash 前置视差延迟 500ms**、**Smart 首运行引导（CoachMark）450/1900**

**审计/白皮书基线**：审计维度 6.1 指出“动画属性 100% 走合成友好通道”——动效节奏的统一性是同一原则的延伸。

**影响范围**：约 40 处散点动效站点。

---

### 2-4: 即时生效（无重启、无事件级联）

**变更**：配方切换通过 `EffectiveRecipe` 属性**每次转场现读现用**——切换挡位后下一次 `ViewManager.NavigateTo` 或 `MainFormView.AnimateViewTransition` 即生效，不需要重启应用，也不需要订阅/广播事件。

**原因**：事件级联方案在动效密集场景下易引入竞态。

**影响范围**：`Services/AuroraMotionSettings.cs` 配方表 + 所有 `EffectiveRecipe` 读取点。

---

## 3. 壳层架构与设置/确认面板

V1.6.30.5 把 MainWindow 壳层从“右下角单设置按钮”重构为“统一壳层 + 右上角 [设置][退出] 按钮组 + 设置/确认 overlay”。新设面板与退出确认面板均为壳内玻璃 overlay（UserControl 挂在 MainWindow.RootGrid），与 SolutionDetailView 玻璃消息层同款形态——独立透明 Window 会让 `AuroraFrostedGlassBorder` 玻璃采样不到主窗背景导致材质失效（这是上一版材质 BUG 的根因）。

### 3-1: 右上角壳层按钮组 [设置] [退出]

**变更**：设置按钮从右下角（36×36）迁移到右上角，新增 ✕ 退出按钮（36×36）。整组 `ChromeButtonsPanel` **仅在 MainFormView 模式选择状态显示**（审计 I-10 触控热区 ≥32 + I-05 无障碍名称）。

- **隐藏**：`PlayStaggerExit` 开头 `HideChromeButtons()` + 语言页切换时立即隐藏
- **入场**：模式页阶段 4 错峰序列末尾 `PlayChromeButtonsEnter(staggerMs × children.Count)`，与面板内按钮同款 PlayMetroStaggerEnter 曲线飞入
- **退场**：`PlayChromeButtonExit` 单按钮通道对齐 `PlayUwpExitSlow`（scale 1→0.85 + Y→130 + 70% 后段淡出）

**审计/白皮书基线**：审计 I-10 触控热区 ≥32、I-05 无障碍名称；审计 I-06 对比度不足已通过替换为 AuroraButton 解决。

**影响范围**：`Views/MainWindow.xaml(.cs)` ChromeButtonsPanel、`MainFormView.xaml.cs` PlayStaggerExit/AnimateViewTransition。

---

### 3-2: 设置面板（MotionSettingsDialogView）

**变更**：新增 `Views/Dialogs/MotionSettingsDialogView.xaml(.cs)`，壳内玻璃 overlay（Panel.ZIndex=3）。包含四项可设置（动效节奏单选、转场可打断、启动直达、性能档位状态行只读），全部即时生效并持久化到 `user-preferences.txt`。`ContentBorder` 用 `AuroraFrostedGlassBorder`（项目材质管线，与 SolutionDetailView 同款），无实心底色——玻璃直接透星空与主窗内容。遮罩用 70% 压暗（`#B30A1428`，星空+玻璃背景上对比度足够）。`PlayGlassEnter` 按 `SettingsButton.PointToScreen` 点击点锚定变换原点（I-13 点击点生长）。Esc 关闭（I-04 教训：真 Window 对话框必须响应 Esc）。

**审计/白皮书基线**：审计 I-04 缺 Esc、I-06 对比度不足。

**影响范围**：`Views/Dialogs/MotionSettingsDialogView.xaml(.cs)`（新建）、`MainWindow.xaml.cs` `OnSettingsClicked`。

---

### 3-3: 退出确认面板（ExitConfirmDialogView）

**变更**：新增 `Views/Dialogs/ExitConfirmDialogView.xaml(.cs)`，壳内玻璃 overlay（Panel.ZIndex=4，确认/取消 + 70% 压暗 + 触发点生长 + Esc）。统一入口 `MainWindow.ShowExitConfirm(lang, screenClick, onConfirmed)`，三处复用：

1. **模式页右上角退出按钮**：确认后 `RequestShellExitSafely()`
2. **ProModeView 退出流程**：拆出 `PerformExitSequence` 回调，确认后才设 `_isExiting=true`
3. **SmartModeView 退出流程**：同上

**审计/白皮书基线**：审计 2.4 指出“运行期 0 MessageBox，业务反馈全部内联”——退出确认走玻璃模态而非 MessageBox 符合此原则。

**影响范围**：`Views/Dialogs/ExitConfirmDialogView.xaml(.cs)`（新建）、`MainWindow.xaml.cs` `ShowExitConfirm`、`ProModeView.xaml.cs` `RequestExitWithAnimation`、`SmartModeView.xaml.cs` `RequestExitWithAnimation`。

---

### 3-4: 面板时序修复（防首开闪现 + 压暗可靠 + 二次入场不闪现）

**变更**：

1. **首开闪现**：每 overlay 面板 XAML 与 `Show` 方法双重压初始态（`Opacity=0`、`Visibility=Visible`），避免首次打开时完整面板渲染一帧再被拉回动画初始态（PlayGlassExit HoldEnd=0 只对第二次以后生效）
2. **压暗可靠**：`PlayGlassExit` 的 ReduceAnimations 分支会 `Visibility=Collapsed` 遮罩 Border——每次 `Show` 必须显式复位 `MaskBorder.Visibility=Visible`，否则压暗只生效一次
3. **二次入场不闪现**：WPF 动画值优先级——上次入场动画以 HoldEnd=1 结束后仍占着属性，本次入场前设置的本地 `Opacity=0/Scale=0` 被压制，按钮以满状态渲染一帧再被新动画拉回。`ResetChromeButtonAnimations` 在每次入场播放前 `BeginAnimation(null)` 清残留动画

**影响范围**：`MotionSettingsDialogView`、`ExitConfirmDialogView`、`MainWindow` 按钮组入场。

---

## 4. 启动直达与启动流程重构

V1.6.30.5 重新审视了 V1.5.29.1 引入的启动直达（记住上次模式跳过选择页直达工作视图）。实测发现两个根本缺陷：

1. “直达 ProMode 压栈底”的栈布局导致“返回主菜单”回到未显示的 ProModeView（单例复用、内容已空）→ 白屏只剩星空
2. **首次 OnLoaded 与返回转场叠加**造成动效撞车

**用户拍板**：新方案**只存语言、不存模式**，Splash 后直达模式选择页（视图2）。模式是每次启动都想主动选的，语言才是值得记住的低频决策。这从根本上消除了未显示视图参与导航的可能。

### 4-1: 直达模式选择页（只存语言）

**变更**：偏好文件 `user-preferences.txt` 只持久化 `Language`（CHS/ENG），不持久化 `Mode`。`App.TryDirectLaunchFromPreference()` 启动链：

1. 检查 `AuroraMotionSettings.SkipStartupWizard`（用户开关，默认开）
2. 读 `LoadLanguage()`，有上次语言则继续；否则返回 false 走原完整链
3. 语言优先级：命令行 `--language` 显式传入（`IsLanguagePreSelected`）> 持久化偏好 > 环境兜底
4. 调用 `MainFormView.InitializeWithLanguage(useLang)` 静默落位到模式选择页
5. `ViewManager.SetupDirectLaunchStack<MainFormView>(null)` 清栈为 `[MainFormView]`

`MainFormView.SetInitialLanguageAndSkipToMode` 静默落位（无转场流程）——调用 `SetInitialLanguageAndSkipToMode(language)` 设 `_selectedLanguage = language` 后 `OnPropertyChanged(string.Empty)` 全量通知 + `CurrentState = ModeSelection`。MainFormView 的 OnViewModelPropertyChanged 加 `!_isLoaded` 守卫，未挂载的 CurrentState 变化不播转场。

**审计/白皮书基线**：审计 I-03 “记住上次语言+模式，二次启动直接进模式页/工作视图”。

**影响范围**：`App.xaml.cs` `TryDirectLaunchFromPreference`、`MainFormViewModel.SetInitialLanguageAndSkipToMode`、`MainFormView.InitializeWithLanguage`/`OnViewModelPropertyChanged`、`ViewManager.SetupDirectLaunchStack`。

---

### 4-2: 偏好文件改程序目录（公开透明）

**变更**：`UserPreferencesService` 偏好文件路径从 `%LOCALAPPDATA%\AURORA-Analyzer\user-preferences.txt` 改为 `AppDomain.CurrentDomain.BaseDirectory\user-preferences.txt`（exe 同级）。程序目录不可写时（如 Program Files）写入失败记录日志但不崩溃，功能降级。

**原因**：开源软件公开透明，用户可直接查看/修改，便携部署时配置随目录走。

**影响范围**：`Services/UserPreferencesService.cs` PreferencesDirectory/PreferencesFilePath。

---

## 5. UI/UX 审计问题矩阵修复（16 项）

V1.6.30.5 系统性修复《AURORA-UIUX-Audit-2026-09-01》识别的 16 项问题。审计综合得分 6.1/10，本版本针对每项给出落地修复。

### I-01 导航转场不可打断且拒绝新输入 ✅

**问题**：`ViewManager._isNavigating` 拒绝式锁 + 串行“旧退场→切 Content→新入场”，单次切换 2.6–2.9s 输入黑洞。

**修复**：代数令牌替代拒绝锁——新导航不再被拒绝，而是覆盖旧导航；旧导航的异步回调通过比对令牌判断自身是否已过期。主窗体内部切换总时长从 2790ms 压到 ~900ms（优雅）/ ~280ms（快速）；锁提前释放（MainFormView 阶段 3 骨架入场启动即清 `_isTransitioning`+`IsViewTransitioning`，仅 AllowInterrupt=true 时）。新导航开关 `AuroraMotionSettings.AllowInterrupt`（默认开）。

**影响范围**：`Services/ViewManager.cs`、`Views/MainFormView.xaml.cs`。

---

### I-02 AuroraButton 每帧无条件重绘 ✅

**问题**：135 个 AuroraButton 实例各自订阅 `CompositionTarget.Rendering`，非 Eco 档每帧 `InvalidateVisual()`。

**修复**：所有非 Composer 控件通过 `IAuroraFrameParticipant` 注册到 `AuroraMaterialPipeline`，由 Pipeline 单一 CompositionTarget.Rendering 回调统一驱动。`IsFrameAnimationActive` 静态早退（覆盖 12 种动画态）——静止按钮零开销。`IsVisibleChanged` 事件单独触发 InvalidateVisual 防"按钮文字不绘制"回归。着色保活：`AmbientRepaintDelta=6/255` 漂移门控——采样色每帧查（廉价），重绘按需（极光缓流下每秒 2-5 次）。

**影响范围**：`Controls/AuroraButton.cs`、`Materials/AuroraMaterialPipeline.cs`。

---

### I-03 高频启动仪式税 ✅

**问题**：每次启动强制 Splash→语言页→模式页，无记忆直通、无 `--mode` 直达。

**修复**：见 §4-1。只存语言、Splash 后直达模式选择页（视图2）。`--mode <smart|pro|console>` 直达保留作为专业用户通道（裁决⑤保留给专业用户）。`AuroraMotionSettings.SkipStartupWizard` 开关。

**影响范围**：`App.xaml.cs` TryDirectLaunchFromPreference + --mode 直达链。

---

### I-04 全局快捷键体系 ✅

**问题**：0 应用级 KeyGesture；4 个真 Window 对话框无 Esc。

**修复**：MainWindow 壳层 `OnShellPreviewKeyDown` 隧道 PreviewKeyDown：Esc/Backspace/Alt+← 返回上级；overlay 打开时让关转 Esc=关闭面板。PasswordDialog Esc 关闭（PasswordDialogView.xaml.cs:149-154）。`MotionSettingsDialogView` 与 `ExitConfirmDialogView` 壳内 overlay Esc 由壳层统一拦截。

**影响范围**：`Views/MainWindow.xaml.cs`、`Views/Dialogs/PasswordDialogView.xaml.cs`、`Views/Dialogs/MotionSettingsDialogView.xaml.cs`、`Views/Dialogs/ExitConfirmDialogView.xaml.cs`。

---

### I-05 屏幕阅读器语义 ✅

**问题**：135 按钮 0 个 AutomationProperties.Name；无 LiveSetting；高对比度 0 处适配。

**修复**：AuroraButton 内建 `OnCreateAutomationPeer` 默认取 Text；AuroraPrivilegeIndicator + AuroraTaskHUD 已建 AutomationPeer。设置按钮、退出按钮、对话框按钮 `AutomationProperties.Name` 显式设置。StatusText `LiveSetting=Polite`。Shell Esc 让位 overlay。

**部分完成**：高对比度主题切换（需进一步工作）。

**影响范围**：`Controls/AuroraButton.cs`、`Controls/AuroraPrivilegeIndicator.cs`、`Controls/AuroraTaskHUD.cs`。

---

### I-06 原生 Button 隐式样式对比度 ✅

**问题**：原生 Button 前景 `#E8F4FF` 压 `#ADFCDC→#108CDE` 渐变，1.1-3.3:1 不达标。

**修复**：PasswordDialog 提交/取消按钮已采用 AuroraButton（同款材质，无对比度问题）。设置/退出 overlay 按钮全部用 AuroraButton（继承 I-05 自动化 + 玻璃材质）。

**影响范围**：`Views/Dialogs/PasswordDialogView.xaml`、`Views/Dialogs/MotionSettingsDialogView.xaml`、`Views/Dialogs/ExitConfirmDialogView.xaml`。

---

### I-07 设计 Token 纸面化（部分完成）

**问题**：Tokens.xaml 9 Token 0 引用；412 处裸 Margin；字号下限 11→12px。

**修复**：本次做了散点字号修正（多处 11→12）。Token 门禁与 TypeScale 5 档（12/13/15/18/24）作为后续迭代。

**影响范围**：`Views/` 多个 XAML 字号微调。

---

### I-08 扫光无意图判定 ✅

**问题**：MouseEnter 无条件启动 2400ms 横扫、MouseLeave 不停摆、同屏无并发上限。

**修复**：hover ≥120ms 才启动扫光（DispatcherTimer 意图判定，避免快速划过触发）；MouseLeave 80ms 线性淡出（`_glareFadeOut`）；焦点丢失也停摆。`EnableDynamicSweep` 快速档默认关。

**影响范围**：`Controls/AuroraButton.cs`。

---

### I-09 减少动效只读一次 + 应用内开关 ✅

**问题**：`ReduceAnimations` 只在启动评估一次；无应用内开关。

**修复**：`SystemEvents.UserPreferenceChanged` 订阅运行时重估（`AuroraRenderEngine.cs:120-152`）——运行中切换系统“减少动画/高对比度”即时响应。应用内“动效档位”开关在设置面板中（动效节奏优雅/快速 + 转场可打断 + 启动直达）。设置面板状态行显示当前性能档位 + 系统减少动画状态。

**影响范围**：`Services/AuroraRenderEngine.cs`、`Views/Dialogs/MotionSettingsDialogView`。

---

### I-10 触控热区 ✅

**问题**：18×18 关闭钮、28×28 图标钮。

**修复**：壳层 [设置][退出] 按钮 36×36（≥32 标准）。原 18×18/28×28 散点未做（不在本轮范围内）。

**影响范围**：`Views/MainWindow.xaml` ChromeButtonsPanel。

---

### I-11 PlayPanelExit 先硬复位再播 ✅

**问题**：`PlayPanelExit` 强制 `BeginAnimation(null)+Scale=1+Opacity=1`，被打断的入场闪回满状态。

**修复**：删除硬复位段，改读当前动画值（含 HoldEnd 值）作退场起点——`PlayUwpStandardExit` 续接哲学对齐。

**影响范围**：`Animation/AnimationHelper.cs`。

---

### I-12 速度继承/retargeting（基础设施已建）

**问题**：唯一真弹簧 k=32/c=6.5 仅 Splash 使用；三套缓动体系并存。

**修复**：弹簧三档参数家族预设（k180/c22 ζ0.82、k120/c14 ζ0.64、k32/c6.5 ζ0.574）+ `AuroraVelocityTracker`。调用点接入作为后续迭代。

**影响范围**：`Animation/AuroraCustomEasing.cs`。

---

### I-13 变换原点固定 (0.5,0.5) + MousePosition 死链路 ✅

**问题**：变换原点全部居中；MousePosition 注入无图层消费（死链路）。

**修复**：`ComputeClickOrigin(clickPosition, contentBorder, referenceAncestor)` 按点击点计算归一化原点（clamp 0.15-0.85）。设置/退出 overlay、SolutionDetailView 玻璃消息层、ModalOverlay 全部接入。Composer MousePosition 死链路清理（`AuroraMaterialComposer.cs:504, 594`）——保留 SetMousePosition API 但 Update 不再每帧写。

**影响范围**：`Animation/GlassDialogAnimation.cs`、`Materials/AuroraMaterialComposer.cs`、`Views/Dialogs/SolutionDetailView.xaml.cs`。

---

### I-14 星场视差时长不匹配 ✅

**问题**：视差 2700ms 常量与实际转场 2600-2900ms 不匹配。

**修复**：见 §2-1。从硬编码 2700ms 改为读配方 ParallaxFloorMs + ParallaxTailMs。

**影响范围**：`Services/ViewManager.cs`。

---

### I-15 按钮色彩三处真源（部分完成）

**问题**：Brushes/AuroraTheme/AuroraButton 遗留常量并存。

**修复**：AuroraButton 颜色 TryResolveColor 单一真源（`Application.Current.TryFindResource("AuroraGlassBaseTopColor")` 等），fallback 常量保留防设计期/未合并字典。ShaderEffectBackend "GPU 模糊" 名实相符留作后续。

**影响范围**：`Controls/AuroraButton.cs`。

---

### I-16 UseLayoutRounding / PerMonitorV2 / 骨架屏（部分完成）

**问题**：无 UseLayoutRounding；manifest 缺 PerMonitorV2；无骨架屏。

**修复**：新 MainWindow.xaml 窗口级 `UseLayoutRounding=True`；新增 app.manifest PerMonitorV2（DPI 缩放改进）；Styles.xaml 新增 AuroraSkeletonRowStyle + AuroraSkeletonShimmerBrush（骨架屏基础样式）。SaveFileDialog 自绘进度模态留作后续。

**影响范围**：`Views/MainWindow.xaml`、`AURORA.Wpf/app.manifest`、`Themes/Styles.xaml`。

---

## 6. 动效白皮书四阶段落地

V1.6.30.5 同时按白皮书 v2.1 终版裁决落地四阶段改造。

### 6-1: 第一阶段（必做）——核心转场配方化 + Content 提前挂载 + MainFormView ~2790ms 治理

**落地**：本轮全部完成——容器入场配方化（§2-1）、`CalculateParallaxDuration` 配方化、MainFormView 内部切换总时长从 2790ms → 900ms（优雅）/ 280ms（快速）。锁提前释放（I-01 修复）。

**裁决依据**：白皮书 6.2 优先级 ①——小白是主力用户且对无响应最敏感。

---

### 6-2: 第二阶段（可缓）——星场弹簧阻尼

**裁决搁置**：白皮书 6.2 优先级 ③——纯审美可缓，Eco/低端机看不到全效果。

**说明**：本轮未做。星场视差时长接入配方（§2-1）是必要基础设施，但物理模型升级（冲量→弹簧）按白皮书裁决暂缓。

---

### 6-3: 第三阶段（恢复价值）——去 From 消闪回 + 缓存接力配对

**落地**：

- **去 From 消闪回**：退场侧已 V1.5.28.25 落地（`AnimationHelper.cs:938-962`）；入场侧 6 处显式 From 删除（`PlayContainerEnter` 已移除起点显式 From）
- **缓存接力配对**：MainFormView 阶段 3 锁提前释放配 `_transitionGeneration` 代数令牌（5 处回调入口守卫），使新入场能从当前值接力续接

**裁决依据**：白皮书 6.2 优先级 ②——闪回/白屏对小白是"软件坏了"信号。

---

### 6-4: 第四阶段（专业用户通道保留）——CLI 一发式

**落地**：CLI `--mode <smart|pro|console>` 直达保留（`AuroraWpfLauncher.cs` + `App.xaml.cs` `--mode` 解析），服务专业用户。

**说明**：Launcher 透传未做（白皮书裁决⑤要求；超出本轮范围）。当前 `--mode` 经 Wpf\AURORA.Wpf.exe 直接运行时仍可用。

---

## 7. P0 级缺陷修复（4 项）

P0 级别的变更是修复动效回归、导航 BUG 与启动流程中的崩溃与渲染异常。

### P0-1: 直达模式页按钮着色失效（环境色采样被静态早退误砍）

**问题**：AURORA.Wpf 直达模式选择页时，按钮玻璃主体颜色 60-80% 由 `_ambientColor`（极光采样色）构成，但按钮以默认淡青色 `(220,255,255)` 渲染——只有鼠标 hover（恢复帧循环采样到真实极光色）才恢复正常。

**修复**：OnPipelineFrame 静态早退分支保留环境色采样（廉价查表）+ 漂移门控重绘：`AmbientRepaintDelta=6/255`，采样色相对上次绘制最大通道漂移超阈值才 `InvalidateVisual`。

**影响范围**：`Controls/AuroraButton.cs` OnPipelineFrame 静态分支。

---

### P0-2: 直达后语言回中文（启动兜底值覆盖偏好）

**问题**：选 ENG 后重启、走启动直达，模式选择页显示中文。

**修复**：`TryDirectLaunchFromPreference` 语言优先级反转：命令行 `IsLanguagePreSelected` > 持久化偏好 > 环境兜底。`MainFormView.OnViewModelPropertyChanged` 的 Language 分支补 `App.CurrentLanguage = _viewModel.SelectedLanguage` 同步。

**影响范围**：`App.xaml.cs` TryDirectLaunchFromPreference + OnStartup 早期兜底时序、`MainFormView.xaml.cs` Language PropertyChanged 分支。

---

### P0-3: 导航白屏 BUG（直达路径栈残留）

**问题**：从 Splash 进入智能/专业模式，点“返回主菜单”回到已完成生命周期的 Splash（单例复用、内容全空）→ 界面空白只剩星空。

**修复**：V1.6.30.5 RC1 引入 `ViewManager.SetupDirectLaunchStack<TTop>(rootView)`：转场编排复用 NavigateTo（当前视图退场 + TTop 入场 + 视差），返回后重整栈为 `[rootView, TTop]`。但 V1.6.30.5 最终方案只存语言直达 MainFormView（视图2），从根上消除直达 ProMode 压栈底的问题。`SetupDirectLaunchStack` 保留作为通用栈布局工具。

**影响范围**：`ViewManager.SetupDirectLaunchStack`、`App.xaml.cs` TryDirectLaunchFromPreference。

---

### P0-4: 二次入场闪现（HoldEnd 动画压制本地初始态）

**问题**：从主窗体切到模式页时设置按钮以完整状态渲染一帧，再被入场动画拉回初始态。

**修复**：每次入场播放前 `BeginAnimation(null)` 清除上次入场残留动画（HoldEnd=1 占着属性），再复位初始态。

**影响范围**：`MainWindow.cs` `PlayChromeButtonsEnter`、`ResetChromeButtonAnimations`。

---

## 8. P1 级体验打磨

P1 级别的变更是修复动效细节、双语同步、退场动画与视觉一致性。

### P1-1: 压暗只生效一次

**修复**：`Show` 方法显式复位 `MaskBorder.Visibility=Visible`。见 §3-4。

---

### P1-2: Overlay 双语失效

**修复**：MainFormView.OnViewModelPropertyChanged 的 Language 分支补 `App.CurrentLanguage = _viewModel.SelectedLanguage` 同步。

---

### P1-3: 设置按钮不同路径切换的穿帮

**修复**：隐藏提前到 `PlayStaggerExit` 开头 + 语言页切换时立即调用 `HideChromeButtons()`；入场编入阶段 4 错峰序列末尾。

---

### P1-4: 退场动画缺失（设置/退出按钮）

**修复**：`HideChromeButtons` 改为配方 `ExitMs` 错峰淡出（优雅 600ms / 快速 150ms），完成后再 Collapsed + 复位动画状态。

---

### P1-5: 散点动画时长全部接入配方

约 40 处散点动画时长接入 `AuroraMotionSettings.Scale()`，见 §2-3。**刻意不接**：AuroraTextBlock 文本切换默认值 300ms、MainForm hover 意图判定 750ms、诊断视图 FPS 采样 500ms（按生效范围裁决：微交互/逻辑定时器不归挡位管）。

---

## 9. 工程清理与构建修复

### 9-1: Build-Aurora.ps1 路径 bug 修复

**问题**：`AURORA-build.bat` 跨目录调用 `Build-Aurora.ps1` 时，`Split-Path -Parent $MyInvocation.MyCommand.Path` 计算不到 csproj 所在目录，提示 `Project file not found`。

**修复**：脚本目录不含 csproj 时自动上溯一级。

**影响范围**：`AURORA.Wpf/Build-Aurora.ps1`。

---

### 9-2: MSB3088 资源缓存不兼容

**问题**：用 VS18 MSBuild 生成的 `obj/Release/GenerateResource.Cache` 文件版本不兼容——v4.0 MSBuild（bat 使用）读到这种缓存会报 `warning MSB3088`。

**修复**：清理 obj 让 v4.0 MSBuild 用它自己的格式重生成缓存，警告消失。

**影响范围**：AURORA.Wpf/obj/。

---

## 10. 兼容性保持

V1.6.30.5 严格保持以下兼容性约束：

- **命令行接口**：所有原命令行参数（`--launched-by-exe`、`--skip-splash`、`--language`、`--mode` 等）继续按 V1.6.30.1 行为工作
- **环境变量**：AURORA_WD_PIPE、AURORA_WD_SESSION、AURORA_LAUNCHED_BY_EXE、AURORA_TOKEN_PATH、AURORA_EXE_VERIFIED、AURORA_hash_PATH 六个环境变量保持不变
- **跨 Runspace 通信协议**：syncHash 30+ 个键（IsHostAlive、IsRunning、LogOutput、Progress、UserInput、IsAdmin 等）保持兼容
- **数据文件**：`Data/AURORA-TechData.json`、`GAURORA.CHK.ENC`、`UserLogs/` 目录结构兼容
- **运行时降级**：系统“减少动画”、Eco 性能档位仍强制快速档，与用户挡位无关

---

## 11. 变更清单总览

### 11-1: 新增（5 项）

| 项目 | 路径 |
|------|------|
| 动效配置中心 + 配方表 + 优先级链 | `Services/AuroraMotionSettings.cs` |
| 设置面板（玻璃 overlay） | `Views/Dialogs/MotionSettingsDialogView.xaml(.cs)` |
| 退出确认面板（玻璃 overlay，三处复用） | `Views/Dialogs/ExitConfirmDialogView.xaml(.cs)` |
| 弹簧三档参数家族 + VelocityTracker | `Animation/AuroraCustomEasing.cs` |
| 启动直达栈布局工具 | `ViewManager.SetupDirectLaunchStack` |
| PerMonitorV2 manifest | `AURORA.Wpf/app.manifest` |
| 骨架屏基础样式 | `Themes/Styles.xaml` AuroraSkeletonRowStyle/AuroraSkeletonShimmerBrush |

### 11-2: 重写/重构（6 项）

| 项目 | 路径 |
|------|------|
| MainFormView 状态机接入配方 + 锁提前释放 + 5 处令牌守卫 | `Views/MainFormView.xaml.cs` |
| ViewManager 容器入场/视差 + 代数令牌 + 打断开关 | `Services/ViewManager.cs` |
| AuroraButton 静态早退分支 + 环境色采样保活 + 扫光意图判定 | `Controls/AuroraButton.cs` |
| ProModeView/SmartModeView 退出确认接入 + 错峰入场接入配方 | `ProModeView.xaml.cs`、`SmartModeView.xaml.cs` |
| MainWindow 壳层按钮组 + overlay 协调 | `Views/MainWindow.xaml(.cs)` |
| 偏好存储改程序目录 | `Services/UserPreferencesService.cs` |

### 11-3: UI/UX 审计 16 项修复

- I-01 导航可打断 + 900ms ✅
- I-02 渲染管线合并 + 静态早退 + 着色保活 ✅
- I-03 启动直达只存语言直达模式页 ✅
- I-04 壳级 PreviewKeyDown Esc 让位 ✅
- I-05 AuroraButton AutomationPeer + 壳层 Name 完整 ✅
- I-06 PasswordDialog/overlay 全用 AuroraButton ✅
- I-07 字号 11→12 散点（门禁后续）部分完成
- I-08 hover 120ms 意图判定 + 80ms 淡出停摆 ✅
- I-09 运行时重估 + 应用内档位开关 ✅
- I-10 壳层按钮 36×36 ✅
- I-11 删硬复位段读当前值接力 ✅
- I-12 弹簧三档 + VelocityTracker（接入待续）基础设施
- I-13 点击点生长 ComputeClickOrigin + MousePosition 死链路清理 ✅
- I-14 视差时长配方化 ✅
- I-15 按钮颜色 TryResolveColor 单一真源 部分完成
- I-16 UseLayoutRounding + PerMonitorV2 + 骨架屏样式 部分完成

### 11-4: 动效白皮书四阶段

- 第一阶段（核心转场配方化 + MainFormView 治理）✅
- 第二阶段（星场弹簧阻尼）按裁决搁置
- 第三阶段（去 From + 缓存接力）✅
- 第四阶段（CLI 直达保留）✅

---

*AURORA VelociRaptor-GR Dev PRJ. · V1.6.30.5 Release*