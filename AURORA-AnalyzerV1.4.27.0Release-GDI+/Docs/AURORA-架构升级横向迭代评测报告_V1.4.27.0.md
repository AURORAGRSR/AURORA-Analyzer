# AURORA-Analyzer 架构升级横向迭代评测报告

> **评测日期**：2026-06-30
> **评测范围**：V1.3.26.7Release（WinForm GDI+）→ V1.4.27.0Release（WPF）全架构对比
> **评测方法**：逐文件深度阅读 + 架构维度横向对比 + 控件级别逐项核对
> **评测人**：Senior Architecture Analyst

---

## 目录

1. [版本概述](#1-版本概述)
2. [架构对比](#2-架构对比)
3. [控件体系对比](#3-控件体系对比)
4. [动画系统对比](#4-动画系统对比)
5. [性能系统对比](#5-性能系统对比)
6. [视觉设计对比](#6-视觉设计对比)
7. [安全性对比](#7-安全性对比)
8. [代码质量对比](#8-代码质量对比)
9. [总结与展望](#9-总结与展望)

---

## 1. 版本概述

### V1.3.26.7Release（PowerShell + WinForm GDI+）

V1.3.26.7 是 AURORA-Analyzer 在 WinForm 时代的最终稳定版本。整个系统基于 PowerShell 脚本构建，UI 层通过 `System.Windows.Forms` 程序集动态创建 WinForm 控件，所有视觉效果依赖 GDI+ 的 `OnPaint` 事件逐帧绘制。架构上表现为"脚本驱动 GUI"的模式——约 10,000 行级别的 LauncherGUI 脚本内嵌 C# 代码通过 `Add-Type` 编译，承担了安全检查、动画渲染、会话管理等全部职责。CHSPRO 与 ENGPRO 两个语言版本存在约 6,000 行语义重复，通过 dot-source 隐式导入模块，全局 `syncHash` 哈希表充当进程间通信的"穷人的 IPC"。

### V1.4.27.0Release（PowerShell + WPF）

V1.4.27.0 是一次架构层面的根本性重构。UI 层从 WinForm GDI+ 完全迁移到 WPF 框架，采用 C# 5.0 编译的独立控件库项目 `AURORA.Wpf.csproj`。整体遵循 MVVM 架构模式，View（XAML 声明式 UI）/ ViewModel（数据绑定与命令）/ Service（业务逻辑）三层分离。PowerShell 引擎通过 `System.Management.Automation.Runspaces.RunspacePool` 嵌入 WPF 进程，利用 `Hashtable.Synchronized` 实现跨 Runspace 状态同步。语言支持从双 .ps1 文件合并为单一引擎 + `LanguageService`（基于 .resx 资源文件）统一管理。

---

## 2. 架构对比

| 维度 | V1.3.26.7 WinForm | V1.4.27.0 WPF |
|------|-------------------|---------------|
| UI 框架 | WinForm GDI+，PowerShell 脚本通过 `Add-Type` 动态创建控件，所有 UI 在运行时由脚本拼接 | WPF XAML 声明式 UI，C# 编译控件库（`AURORA.Wpf.csproj`），设计时与运行时分离 |
| 架构模式 | 事件驱动，无明确分层。LauncherGUI 混合了 GUI 构建、安全检查、动画渲染、会话管理 | MVVM 模式：View（XAML）/ ViewModel（数据绑定 + `RelayCommand`）/ Service（业务逻辑）三层分离 |
| 渲染管线 | GDI+ `OnPaint` 逐帧绘制，CPU 渲染。每个控件自主管理 `Timer` 驱动的重绘循环 | WPF 保留模式渲染，GPU 加速。`CompositionTarget.Rendering` 驱动（vsync 对齐），`OnRender` 仅在需要时触发 |
| PowerShell 集成 | 单 Runspace 通过管道通信，`syncHash` 哈希表轮询等待 GUI 响应 | `RunspacePool` 并行执行，`Hashtable.Synchronized` 共享状态，`EventWaitHandle` 事件驱动授权 |
| 动画系统 | PowerShell `Timer` 驱动，逐帧更新 `Left`/`Top`/`Opacity` 等属性，帧率不稳定 | `Storyboard` + `EasingFunction`（窗口入场/退场）与 `CompositionTarget.Rendering`（背景/按钮动效）双驱动架构 |
| 语言支持 | 双 .ps1 文件（CHSPRO/ENGPRO），约 6,000 行重复，结构漂移风险 | 单一引擎 + `LanguageService`（.resx 资源文件），运行时切换，零重复 |
| 性能分级 | PowerShell 脚本通过 `Get-CimInstance` 检测硬件，全局变量 `$global:AuroraPerfTier` 控制 | C# WMI 硬件检测（`ManagementObjectSearcher`），环境变量 `AURORA_PERF_TIER` + 静态类 `AuroraRenderEngine` 控制 |
| 安全机制 | PowerShell 脚本验证，环境变量传递信任链，反调试检测在脚本中实现 | C# `IntegrityGuardService` + RSA 令牌验证 + AES-256-CBC 提权令牌 + 反调试 + `WatchdogService` 看门狗 |
| 依赖管理 | dot-source 隐式导入，依赖导入顺序，无显式依赖声明 | C# 项目引用（`.csproj`），NuGet 包管理，显式编译期依赖 |
| 工程化程度 | 脚本级工程，`build.ps1` 通过正则替换注入密钥，版本号硬编码 5+ 处 | 专业 .NET 项目，`Build-Aurora.ps1` / `build-wpf.ps1` 构建，MSBuild 编译，GitHub Actions CI |

### 详细分析

**UI 框架升级**：从 WinForm 到 WPF 的迁移不仅是框架替换，更是渲染模型的根本改变。WinForm 使用即时模式（Immediate Mode）——每个 `OnPaint` 事件必须重新绘制全部内容，所有视觉状态（悬停、按下、动画进度）由开发者手动跟踪并逐帧重绘。WPF 使用保留模式（Retained Mode）——视觉树由框架维护，GPU 负责合成与光栅化，开发者只需声明视觉元素并通过依赖属性绑定状态，框架自动处理脏区域重绘。这在 AuroraButton 的 17 种动效中体现尤为明显：WinForm 版需要维护 17 个 Timer 状态变量并在 `OnPaint` 中逐一计算，而 WPF 版通过 `OnAnimationTick` 统一推进所有动画进度，`OnRender` 仅负责绘制，逻辑清晰分离。

**MVVM 架构**：V1.4.27.0 引入了完整的 MVVM 分层。`ViewModels/` 目录包含 10 个 ViewModel（`MainViewModel`、`ProModeViewModel`、`SplashScreenViewModel`、`ElevationDialogViewModel` 等），通过 `ObservableObject` 基类实现 `INotifyPropertyChanged`，通过 `RelayCommand` 实现 `ICommand` 绑定。`Views/` 目录包含对应的 XAML 视图和 code-behind。`Services/` 目录包含 15 个服务类，覆盖 PowerShell 宿主、完整性守卫、语言管理、会话缓存、修复、恢复、撤销管理等全部业务领域。

---

## 3. 控件体系对比

### 3.1 AuroraButton（原 TechButton）

AuroraButton 是控件体系升级的核心代表，从 WinForm 的 GDI+ 自定义绘制完全迁移到 WPF 的 `FrameworkElement` 继承体系。

**WinForm 版（TechButton）**：通过 `Button` 派生，重写 `OnPaint` 方法，使用 GDI+ 的 `Graphics` 对象进行全部绘制。17 种动效细节（悬停缩放 5%、颜色插值、扫光、磁吸偏移、按下缩放 3%、涟漪、状态机、焦点动画、外发光、路径阴影、内散射高光、鼠标移出回弹、点击冷却、长按检测、键盘事件、加载态虚线环、成功/失败图标）全部通过独立的 `Timer` 逐帧更新对应的属性变量，在 `OnPaint` 中根据当前状态逐层绘制。由于 GDI+ 不支持模糊效果，所有"光晕"通过多层半透明椭圆叠加模拟。

**WPF 版（AuroraButton）**：继承自 `Button`，完整保留了全部 17 种动效，并新增了以下关键特性：

- **极光环境色注入**：通过 `TransformToAncestor(Window)` 获取按钮在窗口中的绝对 Y 坐标，调用 `AuroraStarfield.SampleAuroraColorAt(ny, timePhase)` 静态方法采样当前位置的极光层颜色，将其注入到玻璃主体中。Normal 状态强度 0（无注入），Hover 状态强度 0.50（玻璃强烈浮现极光色），Press 状态强度 0.80（按进极光，玻璃内层染色）。使用径向渐变 `RadialGradientBrush`（偏下中心，模拟极光从下方透上来的折射感），峰值 alpha 150，通过 `_ambientStrength` 平滑插值过渡。

- **iOS Q 弹释放反馈**：当按下释放时启动 600ms 的二次回弹动画——scale 从 0.97 过冲到 1.04 再收敛到 1.0。分两阶段：前半段（0→0.5 进度）从 0.98 到 1.02（EaseOutCubic 过冲），后半段（0.5→1.0 进度）从 1.02 收敛到 1.0（EaseOutQuad）。幅度控制在 2% 以内，点到为止，避免卡通感。

- **enabled/disabled 渐变过渡**：通过 `_disabledProgress`（0=完全可用/亮色玻璃，1=完全禁用/灰玻璃）实现 IsEnabled 切换时的平滑插值。所有 alpha 通道使用 `Lerp(亮值, 暗值, _disabledProgress)` 而非三目硬切，彻底杜绝了"灰↔亮"的瞬时跳变。过渡速度 `_animSpeed * 0.5`，约 0.3 秒完成。

- **微噪点磨砂纹理**：128×128 无缝灰度噪点图（`WriteableBitmap`），灰度范围 110-155，固定种子（Random(42)）确保所有按钮共享相同纹理。以 4% 不透明度叠加在玻璃主体之上，通过 `Lazy<ImageBrush>` 静态懒加载实现单例共享，打破纯色渐变的"塑料感"，模拟真实磨砂玻璃表面微观不平整带来的漫反射颗粒感。

- **倾斜扫光**：在 WinForm 版水平扫光（渐变矩形 + TranslateTransform 横向平移）基础上加入 `SkewTransform(-20°)`，让光带斜着飞过按钮。视觉差异：水平扫光像"探照灯"，倾斜扫光像"日光透过百叶窗"——更自然、更高级。扫光参数保持 2400ms 时长、-0.6→1.6 行程、EaseOutCubic 缓动、5 段高斯衰减渐变（透明→浅白→纯白→浅白→透明）。

**绘制顺序**（从后到前）：软投影（磁吸外）→ 毛玻璃主体（半透明冷蓝白渐变，alpha 60→40）→ 微噪点纹理 → 渐变边框高光 → 内阴影侧壁（深紫黑折射）→ 漫射高光（Fake Blur 横向雾化）→ 极光环境色注入 → 外发光（渐亮渐灭，跟随 `_glowProgress`）→ 倾斜扫光 → 按下内阴影 → 涟漪（填充椭圆）→ 文本 → 焦点虚线框 → 加载态/成功/失败图标。

### 3.2 AuroraStarfield（原 StarfieldPanel）

**WinForm 版（StarfieldPanel）**：`Panel` 子类，GDI+ 绘制星星闪烁、飞入、流星、深空粒子、鼠标光晕。通过 `Timer` 驱动帧循环，每帧调用 `Invalidate` 触发 `OnPaint`。极光效果缺失（深空背景为纯色渐变），星星本体为单色白色圆点，无拖尾、无星座连线、无视差深度。

**WPF 版（AuroraStarfield）**：`FrameworkElement` 继承，实现了以下重大升级：

- **CompositionTarget.Rendering 60fps 驱动**：替代 `DispatcherTimer`，与显示器刷新对齐，避免 Dispatcher 调度抖动。通过 `Stopwatch` 计算真实帧间时间差（`_frameClock`），所有动画基于真实时间步进（`LastFrameMs`），与渲染帧率完全解耦。

- **帧率归一化至 30fps 基准**：原版 WinForms 所有动画常量按约 30fps 设计。WPF 实际运行在 60fps 下，通过 `_animationTimeScale = clampedMs / 33.333` 将极光、流星、文本切换等所有逐帧动画还原到原版速度，避免 2x 速"快进"。

- **预生成 RadialGradientBrush 缓存池**：极光渲染原方案每帧创建 80 个 `RadialGradientBrush` + 520 个 `GradientStop`，GC 压力巨大。优化后为每层极光预生成 2 套冻结 Brush（主光晕 + 核心辉光），运行时仅通过 `Brush.Opacity` 属性调整整体透明度，每帧创建 0 个新对象。

- **笔刷缓存消除 GC 压力**：`_starBrushCache[256]` + `_glowBrushCache[256]` 预创建 256 级灰度的 `SolidColorBrush`，`_particleBrushCache[121]` 覆盖 alpha 0-120。所有绘制操作从缓存索引取 Brush，零分配。

- **5 层动态极光幕**：HSV 色彩空间（绿/青/蓝紫/粉紫/青绿），24 个径向光斑沿 6 层非谐波正弦波叠加路径分布（0.003~0.230 频率），MRO 垂直 alpha 调制（抛物线衰减），MaxAlpha 145/120/100/85/70 自上而下递减。

- **新增效果**：星星拖尾（柔和椭圆粒子，按 BaseAlpha 调制透明度）、星座连线（鼠标跟随式动态拓扑，每 30 帧重建，柔光 + 主线双层叠加）、视差深度（0.2~1.0，驱动尺寸/速度/入场占比）、恒星色温（5 段分布：冰蓝 55% / 纯白 20% / 极光青绿 13% / 极光紫 8% / 暖橙 4%）、有机闪烁（双正弦波叠加，基频 + 2.3x 无理谐波，永不重复）。

- **闪烁浮现入场**：单星入场 3.5s（EaseOutQuint 缓动），体积从 55% 缓慢长大至 100%，错峰 0-5500ms（90% 随机 + 10% 径向倾向），总铺展约 5.5s，与渲染帧率解耦。入场期间跳过拖尾、光晕渲染，性能开销极低。

### 3.3 AuroraConsoleBox（原 AuroraConsoleBox）

**WinForm 版**：`RichTextBox` 派生，`FormattedText` 逐行渲染。新内容到达时直接追加到文本框，自动滚动到底部。无入场动画。

**WPF 版**：`Control` 子类，实现了以下升级：

- **毛玻璃背景**：完整集成 `AuroraGlassMaterial` 材质方案——双层投影（接触阴影 + 环境漫射）+ 真模糊背景（从共享缓存 `DrawImage`，1/2 分辨率 `RenderTargetBitmap` + `BlurEffect`）+ 玻璃主体渐变（`CachedConsoleBodyBrush`，零分配）+ 表层覆盖（噪点 + 极光染色 + 顶部高光 + 双层边缘 + 厚度暗角）。

- **批量行刷新 50ms 节流**：通过 `Dispatcher.BeginInvoke(Render)` 调度 flush，`_flushScheduled` 防重入，`MinFlushIntervalMs = 33ms`（30fps）节流。流星（PowerShell 进度条）场景下每秒 30-100 行输出时，多次 `CollectionChanged` 合并为一次 flush，避免每帧 `OnRender` 全量重绘。

- **增量包裹**：只包裹新增文本，不重裹已有文本。复杂度从 O(n²) 降至 O(m²)（m 为新增字符数，通常 < 500）。流星输出场景下每次 flush 仅新增 1-10 行。

- **UWP 风格文本滑入动画**：新行从下方 1.0 行高处滑入，颜色从淡蓝紫（180,220,255）过渡到正常白，顶部加 1.5px 亮蓝色高亮线，外围加冷蓝色外发光。旧行向上推动 0.65 行高。缓动使用 CubicEase EaseOut 近似（`progress += (1-progress) * 0.10`），时长约 380ms。

- **320ms 批次延迟 + 260ms 平滑滚动**：`PendingFlushDelayMs = 320ms` 让高频到达的行聚合成 3-6 行/批，视觉上"成段"出现。`SmoothScrollDuration = 260ms` 配合 EaseOutCubic 缓动，信息变更不突兀。

### 3.4 AuroraProgressBar（原 CreateAuroraProgressBar）

**WinForm 版**：自定义 `Panel`，通过 GDI+ 绘制轨道、填充、光晕扫过、粒子效果。粒子较为粗犷（大颗光点随机飞散）。

**WPF 版**：`FrameworkElement` 继承，完整实现了 AuroraButton 同款玻璃材质方案：

- **完整玻璃材质**：软投影（径向渐变阴影，iOS 风）+ 玻璃轨道（靛蓝紫→深紫黑渐变，alpha 70→25）+ 微噪点纹理 + 顶部高光描边（alpha 160→40）+ 内阴影侧壁（深紫黑折射）+ 内散射高光（Fake Blur 横向雾化）。

- **倾斜扫光**：与 AuroraButton 共享同一套 `SkewTransform(-20°)` + 渐变矩形（5 段高斯衰减，峰值 alpha 235）方案。额外叠加一层极光青绿染色（alpha 80），强化"极光"主题。

- **进度前缘光点**：外层光晕（极光青绿 `RadialGradientBrush`，alpha 170）扩大范围至 `height * 1.6`，中心亮点（alpha 250）更小更白，模拟"光流到达终点"。

- **粒子精致化**：严格限制数量（< 20），降低扩散范围（水平漂移 0.15、垂直漂移 0.1），寿命缩短至 0.6-1.6s，颜色改为极光青绿（160,255,220），alpha 提升至 160。

### 3.5 AuroraFrostedGlassBorder（新增）

AuroraFrostedGlassBorder 是 V1.4.27.0 全新引入的毛玻璃容器控件，为整个应用的玻璃质感提供统一的基础设施。继承自 `Border`，通过 `Loaded`/`Unloaded` 事件自动注册/注销到 `AuroraGlassMaterial` 共享材质系统。

**四层渲染架构**：

1. **双层投影**：`AuroraGlassMaterial.DrawDualShadow` 方法绘制接触阴影（`RadialGradientBrush`，Center 0.5/0.5，RadiusX/Y 0.6）和环境漫射阴影（更大的 `RadialGradientBrush`，较低 alpha），模拟 iOS 风格的物理深度。

2. **真模糊背景**：`AuroraGlassMaterial.DrawBlurredBackground` 从共享缓存绘制模糊后的背景图像。模糊捕获由 `AuroraGlassMaterial` 统一管理——30fps 节流，1/2 分辨率 `RenderTargetBitmap` + `BlurEffect`（等效 radius=6），所有 glass 控件共享同一份模糊结果。无 glass 控件时完全跳过 RTB.Render，Splash/MainForm 入场前零开销。

3. **玻璃主体渐变**：使用 `AuroraGlassMaterial.CachedGlassBodyBrush`（静态缓存，Frozen），冷蓝白渐变，alpha 50→30，让模糊背景透出来呈现磨砂质感。

4. **玻璃表层覆盖**：`AuroraGlassMaterial.DrawGlassOverlay` 一次性绘制四层叠加——噪点（8% alpha 共享纹理）+ 极光染色（按 Y 位置采样 `AuroraStarfield.SampleAuroraColorAt`，`RadialGradientBrush` 4 段衰减）+ 顶部高光（alpha 120→0）+ 双层边缘高光（外层 alpha 80→0，内层 alpha 30→0）+ 厚度折射暗角（`CombinedGeometry.Exclude` 环形，深紫黑 alpha 50）。所有 Brush/Pen 预创建并 Frozen，零分配。

### 3.6 AuroraTaskHUD（新增）

AuroraTaskHUD 是 V1.4.27.0 全新引入的任务状态面板控件，用于在修复流程中可视化展示当前步骤进度。

**核心设计**：

- **横向 4 步骤节点**：固定显示 4 个步骤节点（环境侦测 → 风险评估 → 定向修复 → 验证结果），通过连接线串接。节点间距自适应控件宽度（`Math.Min(55, (width - 40) / 3)`）。

- **四态系统**：Pending（暗灰色实心圆，半径 4px）、Running（青色脉冲呼吸动画，外环 8px + 内核 4px，`sin(breathingValue)` 驱动）、Success（绿色实心圆 + 外环，入场时弹出动画 `EaseOutCubic` + 扩散光环）、Error（红色实心圆 + 外环，入场时弹出动画 + 水平抖动 `sin(progress * 6π) * (1-progress)`）。

- **文本滑入动画**：与 AuroraStarfield 同款文本过渡状态机——FadingOut（旧文本向左滑出 10px，`easeInCubic`）→ FadingIn（新文本从右侧 10px 处滑入，`easeOutCubic`）。文本颜色跟随当前活动节点的状态色。

- **毛玻璃材质**：完整集成 `AuroraGlassMaterial` 四层渲染——双层投影 + 真模糊背景 + 玻璃主体 + 表层覆盖（噪点 + 极光染色 + 高光 + 边缘 + 暗角）。与 `AuroraFrostedGlassBorder` 和 `AuroraConsoleBox` 保持视觉一致性。

---

## 4. 动画系统对比

### 4.1 WinForm：Timer 驱动的逐帧动画

V1.3.26.7 的动画系统完全依赖 PowerShell 的 `System.Windows.Forms.Timer` 组件。每个需要动画的控件独立维护一个或多个 Timer，在 Tick 事件中逐帧更新 `Left`、`Top`、`Opacity`、`Size` 等属性。这种方式存在以下固有问题：

- 帧率不稳定：Timer 精度受限于 Windows 消息泵调度（典型精度 15-30ms），在 UI 重载时帧率会显著下降。
- 动画逻辑分散：每个动画的起始值、目标值、缓动计算、持续时间散落在各个 Timer Tick 处理函数中，没有统一的动画抽象。
- 缺乏缓动函数：所有过渡使用线性插值或简单的 `+=` 推进，没有标准缓动曲线（EaseIn、EaseOut、BackEase 等）。

### 4.2 WPF：双驱动动画架构

V1.4.27.0 的动画系统采用双驱动架构，根据不同场景选择最优的动画机制：

**Storyboard + EasingFunction 驱动**：用于窗口入场/退场、视图切换等顶层动画。通过 XAML 声明式定义 `DoubleAnimation` / `DoubleAnimationUsingKeyFrames`，配合 WPF 内置的 `EasingFunctionBase` 派生类（`BackEase`、`CubicEase`、`PowerEase`、`SineEase`）实现精确的缓动曲线。Storyboard 由 WPF 动画时钟驱动，独立于 UI 线程，不受渲染负载影响。

**CompositionTarget.Rendering 驱动**：用于需要实时响应的逐帧动画——星空背景（星星闪烁、流星、极光相位）、按钮动效（磁吸、扫光、涟漪、悬停/按下进度）、进度条光晕。

**4 阶段视图切换动画**：视图切换（如从主界面切换到 ProMode）采用精心编排的 4 阶段序列动画：

1. **旧按钮退场**：左侧按钮逐个淡出 + 左移，间隔 50ms，`BackEase` 缓出。
2. **旧面板 + 标题退场**：旧面板 `Opacity` 和 `TranslateTransform.Y` 同时动画，标题淡出。
3. **新面板 + 标题入场**：新面板从下方淡入，标题从上方淡入，`CubicEase` 缓出。
4. **新按钮入场**：新按钮从左侧逐个滑入，`BackEase` 缓入，弹性过冲。

在视图切换期间，`AuroraTextBlock` 的 `IsTextTransitionEnabled` 保护机制确保文本不会在面板切换过程中触发自身的过渡动画，避免双重动画叠加造成的视觉混乱。

**UWP 风格缓动曲线**：`AuroraCustomEasing.cs` 实现了 UWP 设计语言中的标准缓动曲线（`UwpEasingCurves.cs`），包括 `UwpDampedEase`（临界阻尼弹簧）、`UwpExponentialEase`（指数衰减）、`UwpCubicEase`（三次方）。这些缓动曲线赋予动画"微软原生"的流畅感，与 Fluent Design 风格一致。

---

## 5. 性能系统对比

### 5.1 性能分级体系

| 挡位 | 目标帧率 | 粒子系统 | 复杂光晕 | 动态扫光 | 路径阴影 | 适用场景 |
|------|---------|---------|---------|---------|---------|---------|
| Eco | 30FPS | 关 | 关 | 关 | 关 | 低配硬件/虚拟机，保证基本可运行 |
| Balanced | 60FPS | 关 | 关 | 关 | 开 | 中配硬件，流畅基础特效 |
| Performance | 60FPS | 开 | 关 | 开 | 开 | 高配硬件，完整特效（复杂光晕例外） |
| Extreme | 60FPS | 开 | 开 | 开 | 开 | 顶级硬件，全部特效 |

**WinForm 版**：性能分级通过 PowerShell 脚本的 `Get-CimInstance` 查询硬件信息（CPU 核心数、内存总量），计算评分后设置全局变量 `$global:AuroraPerfTier`。各控件在脚本中读取该变量决定粒子数量、动画帧率等参数。检测逻辑分散在 LauncherGUI 中，与 UI 构建代码混合。

**WPF 版**：性能分级由 C# 静态类 `AuroraRenderEngine` 集中管理。`DetectPerformanceTier` 方法通过 `ManagementObjectSearcher` 查询 WMI（`Win32_ComputerSystem`、`Win32_Processor`），评分算法为：核心数×15 + 内存（GB）×5 + 主频溢出奖励。评分 ≥240 为 Extreme，≥120 为 Performance，≥70 为 Balanced，否则为 Eco。检测结果通过 `Environment.SetEnvironmentVariable("AURORA_PERF_TIER", tier)` 写入进程级环境变量，供所有 C# 引擎层代码极速读取。

**WPF 新增特性**：用户可升级挡位。当自动检测为 Eco 或 Balanced 时，系统通过 `PerformanceUpgradeDialogView` 弹窗询问用户是否升级到下一挡位。用户确认后调用 `AuroraRenderEngine.SetTier(newTier)` 实时切换——重新应用特效开关、更新环境变量，所有控件在下一帧自动适配新挡位。

### 5.2 特效开关差异化

WPF 版对特效开关进行了精细差异化，而非 WinForm 版的"全开/全关"二值逻辑：

- **粒子系统**：仅在 Performance 和 Extreme 挡位开启。影响 AuroraProgressBar 的粒子生成和绘制。
- **复杂光晕**：仅在 Extreme 挡位开启。影响 AuroraStarfield 的 `DrawSoftGlow`（`RadialGradientBrush` 光晕）和 AuroraButton 的外发光。这是最昂贵的特效——每次 `DrawSoftGlow` 创建一个新的 `RadialGradientBrush` + 3 个 `GradientStop`。
- **动态扫光**：在 Performance 和 Extreme 挡位开启。影响 AuroraButton 的倾斜扫光和 AuroraProgressBar 的光晕扫过。
- **路径阴影**：在 Balanced 及以上挡位开启。影响所有控件的 `EnablePathGradientShadows` 开关。

### 5.3 笔刷缓存与零分配策略

WPF 版的性能优化核心在于消除运行时的 GC 压力：

- **Frozen Brush 零分配**：`AuroraGlassMaterial` 中所有不随帧变化的 Brush（顶部高光、外层边框、内阴影、倒角、接触阴影、环境漫射、玻璃主体、控制台主体）全部预创建、填充 `GradientStop`、调用 `Freeze()` 冻结。冻结后的 Brush 可以被任意线程安全共享，CLR 不会为其分配托管内存。

- **RadialGradientBrush 预生成池**：AuroraStarfield 的极光渲染为每层极光预生成 2 套 `RadialGradientBrush`（主光晕 + 核心辉光），`GradientStop` 的 alpha 比例固定，运行时仅通过 `Brush.Opacity` 属性调整整体透明度。每帧从 80 次 `new RadialGradientBrush` + 520 次 `new GradientStop` 降至 0 次对象分配。

- **SolidColorBrush 缓存阵列**：`_starBrushCache[256]`、`_glowBrushCache[256]`、`_particleBrushCache[121]` 预创建覆盖全部 alpha 范围的 `SolidColorBrush`，所有绘制操作通过数组索引取 Brush，零分配。

### 5.4 毛玻璃刷新节流

`AuroraGlassMaterial` 的模糊背景捕获是整个应用中最昂贵的操作——需要 `RenderTargetBitmap.Render` 捕获整个窗口的视觉树，再应用 `BlurEffect`。WPF 版通过以下策略将其性能影响降至最低：

- **30fps 节流**：模糊捕获最大频率 30fps（33ms 间隔），而非 60fps。人眼对磨砂玻璃背景的更新频率不敏感，30fps 已足够平滑。
- **1/2 分辨率**：`RenderTargetBitmap` 以 `ActualWidth/2 × ActualHeight/2` 的分辨率捕获，再通过 `BlurEffect` 模糊上采样。分辨率降为 1/4，Rendering 耗时显著降低，等效 blur radius=6。
- **无 glass 控件时跳过**：SplashScreen 和 MainForm 入场动画期间，没有任何 glass 控件注册，`NotifyStarfieldRedrawn` 直接 return，零开销。这让 Storyboard 独占 UI 线程，确保入场动画流畅。
- **共享缓存**：所有 glass 控件（`AuroraFrostedGlassBorder`、`AuroraConsoleBox`、`AuroraTaskHUD`）共享同一份模糊背景图像，通过 `dc.DrawImage` 直接绘制，无需各自捕获。

---

## 6. 视觉设计对比

### 6.1 WinForm：纯 GDI+ 单层渲染

V1.3.26.7 的视觉呈现完全依赖 GDI+ 的 `Graphics` 对象。所有视觉效果通过以下方式模拟：

- 半透明渐变：通过 `Color.FromArgb(alpha, r, g, b)` 设置 alpha 通道实现半透明。
- 光晕/发光：通过多层半透明椭圆叠加模拟，没有真正的模糊。
- 阴影：通过偏移绘制半透明黑色矩形模拟。
- 高光：通过在顶部绘制白色渐变矩形模拟。

这种方式存在明显局限：无真正的模糊效果（GDI+ 不支持 `BlurEffect`），所有"磨砂玻璃"感只能通过降低 alpha + 叠加冷色渐变近似，视觉上呈现"塑料半透明"而非"磨砂玻璃"质感。

### 6.2 WPF：多层毛玻璃材质

V1.4.27.0 的视觉呈现以 `AuroraGlassMaterial` 为基础设施，实现了真正的多层毛玻璃材质：

- **真模糊背景**：`VisualBrush` + `RenderTargetBitmap` + `BlurEffect`（`KernelType.Gaussian`，`RenderingBias.Quality`）实现真正的背景模糊。背后的星空、极光、按钮等元素经过高斯模糊后呈现真实的"磨砂玻璃背后"视觉效果。

- **微噪点纹理**：128×128 无缝灰度噪点图（`WriteableBitmap`），以 4%-8% 不透明度叠加在玻璃表面，模拟真实磨砂玻璃的微观漫反射颗粒感。固定种子（`Random(42)`）确保所有 glass 控件共享相同纹理，视觉一致。

- **极光环境色注入**：玻璃材质不是固定颜色，而是通过 `AuroraStarfield.SampleAuroraColorAt(ny, timePhase)` 动态采样当前 Y 位置的极光层颜色，将其注入到玻璃表层。极光染色随极光相位（`timePhase`）缓慢呼吸（0.85~1.0 范围），玻璃的颜色随时间微微变化，仿佛"折射"了背后的极光。

- **双层投影**：接触阴影（小范围深色 `RadialGradientBrush`，模拟物理接触面的暗部）和环境漫射（大范围浅色，模拟环境光散射）。双层叠加比单层阴影更接近真实物理光照，让控件"浮"在背景上而非"贴"在背景上。

- **iOS 风格光泽**：所有玻璃控件顶部都有 1px-1.2px 的白色渐变描边（alpha 180→15），模拟真实玻璃边缘的锐利反光。配合内阴影侧壁（深紫黑折射色），形成"一明一暗"的厚度交界，在二维平面上挤压出三维倒角错觉。

### 6.3 视觉对比总结

| 维度 | V1.3.26.7 WinForm | V1.4.27.0 WPF |
|------|-------------------|---------------|
| 背景模糊 | 无真模糊，靠半透明+冷色渐变模拟 | 真高斯模糊（`BlurEffect`），背景实时模糊 |
| 玻璃质感 | "塑料半透明"感 | "磨砂玻璃"感，噪点纹理 + 极光染色 + 边缘高光 |
| 阴影 | 单层偏移矩形 | 双层投影（接触 + 环境漫射），`RadialGradientBrush` |
| 色彩系统 | 固定冷蓝白 | 动态极光环境色注入，按 Y 位置采样，时间相位呼吸 |
| 星空 | 纯色背景 + 白色圆点 | 5 层极光 + 恒星色温 + 视差深度 + 拖尾 + 星座连线 |
| 光效 | 多层半透明椭圆叠加 | `RadialGradientBrush` 软光晕 + `BlurEffect` 外发光 |

---

## 7. 安全性对比

### 7.1 WinForm：PowerShell 脚本级安全

V1.3.26.7 的安全机制完全在 PowerShell 脚本层面实现：

- 启动检测：通过检查 `$global:syncHash` 变量是否存在判断是否由 EXE 合法启动，此检测可被恶意脚本通过在运行前设置全局变量绕过。
- 文件完整性：通过 `Get-FileHash` 计算 SHA-256 与硬编码白名单比对，但白名单本身存储在脚本中，篡改脚本即可绕过。
- 信任链：RSA 公钥嵌入脚本，AES 会话密钥通过 PBKDF2 派生（迭代次数仅 1,000 次，与构建加密的 100,000 次不一致）。
- 反调试：`AuroraGuard` 类在 PowerShell 中通过 `Add-Type` 编译 C# 代码，检测 `IsDebuggerPresent`、`CheckRemoteDebuggerPresent`、`NtQueryInformationProcess` 等。

### 7.2 WPF：C# 编译级安全

V1.4.27.0 的安全机制迁移到 C# 编译层，显著提升了安全强度和工程化程度：

- **IntegrityGuardService**：完整的 C# 静态类实现，包含：
  - 24+ 文件 SHA-256 白名单验证（覆盖核心引擎、安全模块、PRO 引擎、UI 控件、动画、修复、Session 等关键文件）
  - 运行时完整性监控双定时器（3s 定时 + 2-7s 随机扫描）
  - 连续 2 次确认机制（`_consecutiveDetectionCount`，防误报）
  - 引擎层二次完整性检查（`_engineIntegrityVerified`）
  - 反调试检测（`IsDebuggerPresent`、`CheckRemoteDebuggerPresent`、PEB `NtGlobalFlag`、硬件断点寄存器 Dr0-Dr3、30+ 调试器进程名枚举）

- **RSA 令牌验证**：`RsaTokenService` 提供 RSA 非对称加密的令牌签发与验证，确保提权流程的信任链完整性。

- **AES-256-CBC 提权令牌**：`ElevationTokenService` 使用 AES-256-CBC 模式加密提权令牌，令牌包含时间戳、会话 ID、权限范围等元数据。

- **看门狗服务**：`WatchdogService` 通过命名管道（`AURORA_WD_PIPE`）进行心跳检测，会话标识隔离，30s 超时自动重启机制。进程退出时通过 `IDisposable` 安全清理管道资源。

- **进程退出安全清理**：`PowerShellHostService` 实现 `IDisposable`，在 `Dispose` 中调用 `_runspacePool.Dispose()` 清理所有 Runspace，`ElevationTokenService` 通过 `Clear` 方法使用 `Array.Clear` 清零密钥数组。

### 7.3 安全对比总结

| 维度 | V1.3.26.7 WinForm | V1.4.27.0 WPF |
|------|-------------------|---------------|
| 完整性校验 | PowerShell 脚本白名单，可被篡改脚本绕过 | C# 编译层 `IntegrityGuardService`，双定时器持续监控 |
| 信任链 | RSA 公钥嵌入脚本，AES PBKDF2 迭代 1,000 次 | RSA + AES-256-CBC + 时间戳令牌，工程化服务类 |
| 反调试 | PowerShell 内嵌 C#，检测手段有限 | C# 完整实现，多层检测（PEB、硬件断点、进程枚举） |
| 进程安全 | `Stop-Process -Force` 立即终止，跳过 finally 清理 | `IDisposable` 模式，看门狗 Named Pipe 心跳，安全清理 |
| 代码保护 | 脚本源码可见，XOR 混淆密码 | 编译为 IL 的 `.exe`，反编译难度显著提升 |

---

## 8. 代码质量对比

### 8.1 WinForm：脚本级工程

V1.3.26.7 的代码表现出典型的"脚本思维"：

- **单文件巨型函数**：LauncherGUI 约 10,000 行，混合了 C# 嵌入式代码、GUI 构建、安全检查、动画渲染、会话管理。PRO 引擎约 7,800 行，包含 76+ 个函数。
- **CHSPRO 与 ENGPRO 重复**：两个语言版本约 6,000 行语义重复，已出现结构漂移（ENGPRO 独有 `Show-CacheInfo`、`Get-CacheUsageChoice` 等函数而 CHSPRO 缺失）。
- **dot-source 隐式依赖**：所有模块通过 `. "$scriptDir\Module.ps1"` 导入，依赖关系完全依赖"导入顺序正确"的隐含假设，无静态分析工具能检测依赖链。
- **全局变量污染**：`$global:syncHash`、`$global:AuroraPerfTier`、`$global:AURORA_PublicKeyXml` 等散落在各模块中，无统一管理。
- **syncHash 轮询通信**：GUI 与后端通过 `while ($null -eq $syncHash['UserInput']) { Start-Sleep -Milliseconds 100 }` 轮询等待，无超时保护。

### 8.2 WPF：MVVM 工程化

V1.4.27.0 的代码体现了专业的 .NET 工程实践：

- **MVVM 分层**：View（`Views/` 目录，XAML + code-behind）→ ViewModel（`ViewModels/` 目录，数据绑定 + 命令）→ Service（`Services/` 目录，业务逻辑）。单一职责，每个文件职责清晰。

- **依赖注入**：ViewModel 通过构造函数注入 Service 依赖（如 `MainViewModel` 注入 `PowerShellHostService`、`SessionCacheService`、`RepairService` 等），而非使用全局变量。

- **WeakReference 避免内存泄漏**：事件订阅使用弱引用模式，防止事件源持有订阅者的强引用导致无法 GC。

- **IDisposable 资源管理**：`PowerShellHostService`、`WatchdogService` 等实现 `IDisposable`，在 `Dispose` 中释放 `RunspacePool`、`CancellationTokenSource`、`Timer` 等非托管资源。

- **ObservableObject 基类**：所有 ViewModel 继承 `ObservableObject`，通过 `SetProperty<T>(ref field, value, propertyName)` 统一实现 `INotifyPropertyChanged`，避免重复的样板代码。

- **RelayCommand 命令模式**：通过 `RelayCommand` 实现 `ICommand`，支持 `Action<object>` 执行和 `Func<object, bool>` 条件判断，将 UI 交互逻辑从 View 移到 ViewModel。

- **值转换器**：`Infrastructure/` 目录包含 8 个值转换器（`BooleanToVisibilityConverter`、`InverseBoolConverter`、`StringToVisibilityConverter` 等），将数据绑定值转换为 UI 属性，消除 code-behind 中的逻辑。

- **语言服务**：`LanguageService` 基于 .NET `ResourceManager` + `.resx` 资源文件，支持运行时切换（`SetLanguage("CHS"/"ENG")`），通过 `Loc["Key"]` 索引获取本地化文本。完全消除了 CHSPRO/ENGPRO 双文件重复。

- **主题系统**：`Themes/` 目录包含 `AuroraTheme.xaml`、`Brushes.xaml`、`Styles.xaml`、`Templates.xaml`、`Animations.xaml`，所有颜色、字体、控件模板、动画资源集中定义，支持全局换肤。

### 8.3 代码质量对比总结

| 维度 | V1.3.26.7 WinForm | V1.4.27.0 WPF |
|------|-------------------|---------------|
| 架构模式 | 事件驱动，无分层，上帝对象 | MVVM 三层分离，依赖注入 |
| 文件规模 | 单文件 ~10,000 行 / ~7,800 行 | 单文件 < 2,000 行，职责清晰 |
| 语言管理 | 双 .ps1 文件，6,000 行重复 | 单一引擎 + `.resx` 资源文件 |
| 依赖管理 | dot-source 隐式依赖 | `.csproj` 编译期引用，NuGet 包管理 |
| 资源管理 | 无显式清理，`Stop-Process -Force` | `IDisposable` 模式，`WeakReference` |
| 代码复用 | 函数级复制粘贴 | 基类 `ObservableObject`、`RelayCommand`、值转换器 |
| 测试能力 | 无模块边界，无法独立测试 | 服务类可独立 Mock，ViewModel 可单元测试 |
| 版本控制 | 版本号硬编码 5+ 处 | 程序集版本统一管理（`AssemblyInfo`） |

---

## 9. 总结与展望

### 9.1 架构升级的核心价值

V1.3.26.7 到 V1.4.27.0 的升级是一次**架构层面的根本性重构**，而非简单的框架替换。其核心价值体现在以下五个方面：

**渲染能力的质变**：从 GDI+ CPU 渲染到 WPF GPU 加速，从即时模式到保留模式，从单层半透明到多层真模糊毛玻璃材质。这不仅是性能的提升（GPU 合成 vs CPU 逐像素绘制），更是视觉表现力的代际飞跃——真高斯模糊、极光环境色注入、微噪点纹理、双层投影、iOS 风格光泽等效果在 GDI+ 下根本不可能实现。

**工程化水平的飞跃**：从"脚本思维"（dot-source 隐式依赖、全局变量通信、源码注入构建、单文件单体）到"软件工程"（MVVM 分层、依赖注入、IDisposable 资源管理、编译期类型检查、CI/CD 流水线）。代码的可维护性、可测试性、可扩展性获得了根本性提升。

**语言架构的彻底解决**：从 CHSPRO/ENGPRO 双文件 6,000 行重复（且已出现结构漂移）到单一引擎 + `LanguageService` 统一管理。这是 V1.3.26.7 时代最大的技术债，V1.4.27.0 一举根除。

**安全机制的工程化**：从 PowerShell 脚本层面的安全检测（可被绕过）到 C# 编译层的 `IntegrityGuardService`（双定时器持续监控、连续确认机制、多层反调试）。安全强度从"脚本级"提升到"编译级"。

**视觉一致性的统一**：所有 glass 控件（`AuroraFrostedGlassBorder`、`AuroraConsoleBox`、`AuroraTaskHUD`）共享 `AuroraGlassMaterial` 基础设施，确保视觉风格完全一致。在 WinForm 时代，每个控件独立实现自己的"玻璃效果"，视觉上难免存在细微差异。

### 9.2 仍存在的挑战

尽管架构升级取得了巨大成功，以下方面仍有改进空间：

- **syncHash 通信模式未根本改变**：V1.4.27.0 仍使用 `Hashtable.Synchronized` 作为 PowerShel 引擎与 WPF 前端之间的通信桥梁。虽然从 `$global:syncHash` 升级为 `PowerShellHostService.SharedSyncHash`（静态字段 + 显式初始化），但通信模式仍是轮询而非事件驱动，键名仍是魔法字符串。

- **PowerShell 5.1 依赖**：系统仍要求 PowerShell 5.1，无法利用 PowerShell 7+ 的 `ForEach-Object -Parallel` 等原生并行特性。`RunspacePool` 并行处理框架虽然完整，但代码复杂度高于 PowerShell 7 的原生方案。

- **C# 5.0 语言限制**：由于目标 .NET Framework 4.8，C# 版本限制在 5.0。代码中多处可见因缺少 C# 7+ 特性（元组、模式匹配、本地函数）而不得不使用额外的辅助类（如 `NeighborEntry`、`PendingConn` 替代元组，`NeighborEntryComparer` 替代 lambda 比较器）。

- **无单元测试覆盖**：虽然 MVVM 架构使单元测试成为可能（Service 可 Mock，ViewModel 可独立测试），但项目中尚未引入测试框架（如 xUnit 或 NUnit）。这是从"可测试"到"已测试"的关键一步。

### 9.3 后续演进方向

短期（1-2 个月）：

- 引入 xUnit 单元测试框架，为核心 Service 和 ViewModel 编写测试用例
- 将 syncHash 通信从轮询升级为 Event-Driven（`EventWaitHandle` 或 `IProgress<T>`）
- 统一魔法字符串键名为枚举或常量

中期（3-6 个月）：

- 评估迁移到 .NET 8+ 和 PowerShell 7+ 的可行性，利用 `ForEach-Object -Parallel` 简化并行代码
- 引入 Serilog 或 NLog 结构化日志系统，替代当前的字符串拼接日志
- 实现 Authenticode 代码签名，替代当前的自定义完整性校验

长期（6-12 个月）：

- 探索 Avalonia UI 或 .NET MAUI 跨平台方案，将 AURORA-Analyzer 扩展到 Linux/macOS
- 实现插件架构，支持第三方扩展诊断规则
- 建立完整的 CI/CD 流水线（自动化测试 → 构建 → 签名 → 发布）

---

> **评测结论**：V1.4.27.0 在架构层面实现了从"脚本级工具"到"专业级 .NET 应用"的质变。MVVM 分层、WPF 渲染管线、C# 编译层安全、统一语言服务、毛玻璃材质系统——每一项改进都精准地解决了 V1.3.26.7 时代的核心痛点。这不仅是 AURORA-Analyzer 迄今为止最重大的架构升级，也为后续演进奠定了坚实的工程基础。