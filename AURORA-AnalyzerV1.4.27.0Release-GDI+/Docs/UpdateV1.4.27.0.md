# AURORA Analyzer V1.4.27.0 更新说明

> **Windows 事件日志导出与智能诊断工具**
>
> 版本：V1.4.27.0Release · 构建时间：2026.06.30 · 作者：AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **警告**：本工具仅用于个人学习使用。请遵守当地法律法规。

---

## 目录

1. [版本概述](#1-版本概述)
2. [P0 级别：架构层变更](#2-p0-级别架构层变更)
3. [P1 级别：核心系统变更](#3-p1-级别核心系统变更)
4. [P2 级别：新增组件](#4-p2-级别新增组件)
5. [P3 级别：优化与修复](#5-p3-级别优化与修复)
6. [兼容性保持](#6-兼容性保持)
7. [变更清单总览](#7-变更清单总览)

---

## 1. 版本概述

V1.4.27.0 是 AURORA Analyzer 的架构升级版本。本次更新的核心变更是将整个 UI 层从 Windows Forms（WinForm GDI+）完全迁移至 Windows Presentation Foundation（WPF），并引入 Model-View-ViewModel（MVVM）分层架构。PowerShell 引擎层保持兼容，所有命令行参数、环境变量接口和 syncHash 同步机制均维持不变。

V1.3.26.7Release 的 UI 层基于 PowerShell 脚本动态创建 WinForm 控件，依赖 GDI+ 进行软件渲染。这种方案在初期阶段满足了基本需求，但随着功能复杂度增长，其局限性日益凸显：GDI+ 无法实现现代毛玻璃效果、复杂动画的帧率波动明显、UI 逻辑与业务逻辑在 PowerShell 脚本中混杂难以维护。

V1.4.27.0 通过以下三个核心策略彻底解决了这些问题：

- **UI 框架迁移**：所有窗口和控件从 System.Windows.Forms 迁移至 System.Windows.Controls，利用 WPF 的 GPU 加速渲染管线（DirectX 后端）实现高性能视觉效果。
- **MVVM 架构引入**：将 UI 表现层（XAML 窗口）、数据绑定层（ViewModel）和基础设施层（Service）明确分离，消除了 PowerShell 脚本中 UI 代码与业务逻辑混杂的问题。
- **C# 编译控件库**：用 C# 5.0 编译的 AURORA.Wpf.dll 控件库替代 PowerShell 的 New-Object 动态控件创建，利用编译时类型检查和更高的执行效率。

本次更新是一个"底层重构、上层兼容"的版本。所有面向用户的命令行接口、环境变量和跨 Runspace 通信协议均保持完全兼容，确保现有脚本和工作流无需修改即可运行。

---

## 2. P0 级别：架构层变更

P0 级别的变更定义了整个系统的技术基础。这些变更不是简单的功能增强，而是对系统底层架构的根本性重塑。

### P0-1: UI 框架从 WinForm 迁移到 WPF

在 V1.3.26.7Release 及之前的版本中，整个 UI 层基于 System.Windows.Forms 构建。所有窗口、按钮、控件都是通过 PowerShell 脚本中的 `New-Object` 命令动态创建，渲染依赖 GDI+ 的软件光栅化管线。GDI+ 是一个成熟但陈旧的 2D 图形 API，它的核心限制在于完全不使用 GPU 加速——所有绘制操作（包括抗锯齿、渐变填充、透明度混合）都在 CPU 上完成，并且每次绘制都涉及昂贵的 GDI 句柄分配和释放。

V1.4.27.0 将整个 UI 层迁移到 System.Windows.Controls（WPF）。WPF 使用 DirectX 作为渲染后端，所有视觉元素的绘制都由 GPU 硬件加速完成。这意味着复杂的透明度混合、投影效果、模糊处理等操作现在可以利用 GPU 的并行计算能力，渲染性能相比 GDI+ 有数量级的提升。

WPF 还带来了声明式 UI 描述能力。XAML 标记语言允许以结构化的方式描述 UI 布局，替代了 WinForm 版本中冗长的、命令式的 PowerShell 控件创建代码。数据绑定机制消除了手动同步 UI 状态与数据状态的需求，属性更改通知（INotifyPropertyChanged）自动驱动 UI 更新，大幅减少了样板代码量。

| 维度 | V1.3.26.7（WinForm） | V1.4.27.0（WPF） |
|------|----------------------|-------------------|
| 渲染后端 | GDI+ 软件光栅化 | DirectX GPU 加速 |
| UI 描述方式 | 命令式 PowerShell 脚本 | 声明式 XAML 标记 |
| 数据同步 | 手动更新控件属性 | 数据绑定自动同步 |
| 动画能力 | Timer 驱动逐帧更新 | Storyboard 硬件加速 |
| 视觉效果 | 有限的 GDI+ 绘制 | 投影、模糊、透明度等全效果 |

**变更原因**：WinForm GDI+ 渲染性能有限，无法实现现代毛玻璃效果和复杂的实时动画。WPF 提供 GPU 加速渲染、声明式 UI、数据绑定等现代 UI 框架的核心能力，为后续功能演进奠定基础。

**影响范围**：所有窗口、控件、动画系统均被替换。原有 WinForm 代码完全移除，无向后兼容层。

---

### P0-2: MVVM 架构引入

V1.3.26.7Release 的代码组织方式本质上是"面向过程"的。PowerShell 脚本中同时包含 UI 控件的创建代码、事件处理逻辑、业务规则判断和数据处理代码。以主窗口为例，一个超过 5000 行的 PowerShell 脚本文件同时处理窗口布局、按钮点击响应、PRO 模式流程控制、日志输出格式化等多种职责。这种混杂的组织方式导致任何修改都可能产生意外的副作用，也使得单元测试几乎不可行。

V1.4.27.0 引入了 Model-View-ViewModel（MVVM）分层架构，将系统分为三个清晰的责任层：

- **View 层（XAML 窗口）**：纯 UI 描述，包含窗口布局、控件声明、样式和动画定义。View 层不包含任何业务逻辑，仅通过数据绑定与 ViewModel 通信。所有 XAML 文件保持声明式风格，不包含代码后置（code-behind）中的业务代码。

- **ViewModel 层（数据绑定和业务逻辑）**：C# 类实现，包含 UI 状态（属性）、用户交互命令（ICommand）和 UI 相关的业务逻辑。ViewModel 通过 INotifyPropertyChanged 接口通知 View 更新，通过 ICommand 接口接收 View 的命令调用。ViewModel 不直接引用任何 View 控件，实现了完全的视图无关性。

- **Service 层（基础设施服务）**：提供跨视图的公共服务能力，包括日志服务、语言服务、性能检测服务、完整性校验服务、提权服务、看门狗服务等。Service 层通过依赖注入提供给 ViewModel，确保服务实例的生命周期由框架统一管理。

这种分层架构的核心优势在于可测试性和可维护性。ViewModel 可以被独立实例化和测试，无需启动完整的 WPF 窗口。服务层可以被 mock 替换，实现隔离测试。当需要修改 UI 布局时，View 层的变更不会影响业务逻辑；当需要调整业务规则时，ViewModel 层的变更不会影响 UI 渲染。

**变更原因**：原 WinForm 版本无明确分层，UI 逻辑与业务逻辑混杂在 PowerShell 脚本中。一个 5000 行的脚本文件往往同时包含窗口布局、事件处理、流程控制等多种职责，难以维护、测试和扩展。

**影响范围**：所有视图和业务逻辑均按 MVVM 模式重新组织。原有 PowerShell 脚本中的 UI 代码完全移除，业务逻辑迁移至 C# ViewModel 和 Service 层。

---

### P0-3: PowerShell 集成方式升级

V1.3.26.7Release 使用单个 PowerShell Runspace 与 GUI 通信。脚本通过管道（Pipeline）将输出发送到 GUI 线程，GUI 线程通过 Invoke 方法向 Runspace 发送命令。这种单 Runspace 架构意味着一次只能执行一个脚本任务，PRO 模式的多个并行操作（如同时运行诊断脚本和修复脚本）无法实现。

V1.4.27.0 将 PowerShell 集成方式升级为 RunspacePool 并行执行模式。RunspacePool 维护一个可配置数量的 Runspace 实例池，每个 Runspace 可以独立执行脚本，互不阻塞。当需要并行执行多个任务时，RunspacePool 从池中分配空闲 Runspace，任务完成后回收 Runspace 供后续任务使用。

跨 Runspace 的状态共享通过静态 Hashtable.Synchronized 实现 syncHash。syncHash 是一个线程安全的哈希表，所有 Runspace 和 GUI 线程都可以安全地读写其中的键值对。这保持了与 V1.3.26.7Release 相同的通信语义——脚本通过 syncHash 向 GUI 报告进度、输出日志和状态信息，GUI 通过 syncHash 向脚本传递用户指令和参数。

C# 静态字段提供了另一种跨 Runspace 状态共享方式。在 C# 代码中定义的静态字段属于 AppDomain 级别，所有 Runspace 可以无锁访问。这种方式适用于不需要与 PowerShell 脚本交互的纯 C# 状态，如全局配置、性能检测结果等。

**变更原因**：原版单 Runspace 无法并行处理多个脚本任务，限制了 PRO 模式的并发能力。RunspacePool 通过维护 Runspace 实例池实现多任务并行执行，同时通过 syncHash 和 C# 静态字段保持与原有通信协议的完全兼容。

**影响范围**：PRO 模式脚本执行、日志输出、进度报告均通过 RunspacePool 实现。原有脚本代码无需修改，因为 syncHash 的读写接口保持不变。

---

### P0-4: C# 5.0 编译控件库替代 PowerShell 动态控件创建

V1.3.26.7Release 中，所有 UI 控件都是通过 PowerShell 的 `New-Object` 命令在运行时动态创建的。例如，创建 17 个按钮的工作涉及 17 次 `New-Object System.Windows.Forms.Button` 调用，每次调用都需要 PowerShell 解释器查找类型、解析构造函数参数、执行对象初始化。在窗口加载阶段，数百次这样的操作导致明显的启动延迟。

V1.4.27.0 将所有自定义控件编译为 C# 5.0 的 AURORA.Wpf.dll 程序集。C# 代码在编译时进行类型检查，消除了一整类运行时错误——类型不匹配、方法签名错误、属性拼写错误等问题在编译阶段就会被捕获。编译后的 IL 代码执行效率远高于 PowerShell 脚本的解释执行，尤其是在涉及大量数学计算（如动画插值、颜色运算）的场景中。

自定义控件清单包括：

| 控件名称 | 说明 |
|----------|------|
| AuroraButton | 17 种动效的按钮控件，替代 TechButton |
| AuroraStarfield | 60fps 星空背景动画控件 |
| AuroraConsoleBox | 集成毛玻璃背景的控制台日志控件 |
| AuroraFrostedGlassBorder | 毛玻璃边框容器控件 |
| AuroraTaskHUD | 任务进度可视化 HUD 控件 |
| AuroraTextBlock | 支持文本切换动画的文本控件 |
| AuroraProgressBar | 完整玻璃材质方案的进度条控件 |
| AuroraCustomEasing | Spring-Damper 弹簧物理模型缓动曲线 |

**变更原因**：C# 编译代码运行效率远高于 PowerShell 脚本的解释执行。编译时类型检查消除了一整类运行时错误——类型不匹配、方法签名错误、属性拼写错误等问题在编译阶段就会被捕获。C# 的 DrawingContext 渲染 API 相比 GDI+ 的 Graphics 对象提供了更高效的 GPU 加速渲染路径。

**影响范围**：所有 UI 控件均通过 AURORA.Wpf.dll 提供。原有 PowerShell 中的 `New-Object` 控件创建代码完全移除。

---

## 3. P1 级别：核心系统变更

P1 级别的变更聚焦于 UI 渲染和交互系统的重构。这些变更基于 P0 的 WPF 架构基础，对原有的视觉效果和交互体验进行了全面升级。

### P1-1: 毛玻璃材质系统（AuroraGlassMaterial）

V1.3.26.7Release 的 WinForm 版本无法实现真正的模糊背景效果。GDI+ 没有内置的模糊滤镜，如果需要实现模糊效果，只能通过 CPU 端的手动卷积计算，这在实时渲染场景中完全不现实。因此，原版所有窗口背景都是纯色或简单的渐变，无法呈现现代 UI 中常见的毛玻璃（Frosted Glass）视觉效果。

V1.4.27.0 引入了全新的 AuroraGlassMaterial 共享玻璃材质渲染系统。该系统采用四层渲染管线实现逼真的毛玻璃效果：

- **第一层（双层投影）**：在控件内外分别应用 DropShadowEffect，内层投影产生玻璃的厚度感，外层投影产生浮空感。两层投影的偏移量、模糊半径和透明度独立配置，使得玻璃面板看起来真的"悬浮"在背景之上。

- **第二层（真模糊背景）**：通过 RenderTargetBitmap 捕获控件后方内容，然后应用 WPF 的 BlurEffect 进行高斯模糊处理。这个模糊是真正的图像模糊——它实时采样控件下方的内容，对每个像素的邻域进行加权平均，产生透过磨砂玻璃看背景的视觉效果。模糊半径在 15 到 25 像素之间，通过性能分级系统自动调整。

- **第三层（玻璃主体渐变）**：在模糊背景之上叠加半透明的线性渐变刷。渐变从左上角略亮的半透明白色过渡到右下角略暗的半透明灰色，模拟玻璃材质在不同角度下的透光率变化。

- **第四层（表层覆盖）**：最上层覆盖一层极淡的微噪点纹理（Opacity 0.03-0.05），模拟真实玻璃表面的微观不规则性，增加材质质感和真实感。

该材质系统设计为共享实例。所有使用毛玻璃效果的控件（AuroraFrostedGlassBorder、AuroraConsoleBox、AuroraTaskHUD、AuroraButton 的玻璃背景）共享同一个 AuroraGlassMaterial 实例，确保渲染参数一致并且避免重复计算。

**变更原因**：原版 WinForm 无法实现真正的模糊背景效果，因为 GDI+ 没有内置的 GPU 加速模糊滤镜。新系统通过 RenderTargetBitmap 捕获控件后方内容并应用 BlurEffect 实现真模糊，通过四层渲染管线营造逼真的玻璃材质感。

**影响范围**：AuroraFrostedGlassBorder、AuroraConsoleBox、AuroraTaskHUD、AuroraButton 的玻璃背景均使用该共享材质系统。

---

### P1-2: 星空背景重构（AuroraStarfield）

V1.3.26.7Release 的星空背景是通过 WinForm Panel 子类实现的。在 Panel 的 Paint 事件中，使用 GDI+ 的 Graphics 对象绘制每个星点——逐个调用 FillEllipse 来绘制圆形，每个星点都需要独立的 GDI 绘图调用。在 500 颗星点的场景中，每帧需要 500 次 GDI 调用，这在高帧率下会产生显著的性能开销。动画驱动使用 DispatcherTimer，以 30fps 的频率触发重绘。但 DispatcherTimer 与 UI 消息循环共享线程，当 UI 线程繁忙时（如处理大量日志输出），Timer 的 Tick 事件会被延迟，导致帧率不稳定。

V1.4.27.0 将 AuroraStarfield 重构为 WPF 的 FrameworkElement 子类。渲染使用 DrawingContext API，通过 DrawingVisual 和 DrawingGroup 批量绘制星点。所有星点在一次 DrawingContext 调用中完成绘制，避免了 GDI+ 逐个调用的开销。星点使用预计算的位置和大小缓存，减少每帧的计算量。

动画驱动改用 CompositionTarget.Rendering 事件，以 60fps（与显示器垂直同步对齐）的频率驱动。CompositionTarget.Rendering 在 WPF 渲染管线的每帧开始前触发，与 vsync 信号同步，确保动画帧率始终稳定，不会因 UI 线程负载而波动。

帧率归一化是 WPF 迁移中的一个关键细节。原版 WinForm 常量（如星点移动速度、闪烁频率）是按 30fps 设计的。在 WPF 的 60fps 环境下，如果直接使用这些常量，动画会以两倍速度运行。AuroraStarfield 引入了 animationTimeScale 因子（0.5），将 60fps 的帧时间归一化到 30fps 基准，确保所有动画行为与原版保持一致。

**变更原因**：原版 DispatcherTimer 在 UI 线程重载时被延迟，导致帧率不稳定。GDI+ 逐点绘制 500 颗星点每帧需要 500 次独立调用，性能开销大。CompositionTarget.Rendering 与 vsync 对齐提供稳定帧率，DrawingContext 批量绘制星点提供更高性能。

**影响范围**：所有窗口的星空背景均使用新的 AuroraStarfield 控件。视觉效果与原版保持一致，但帧率更稳定。

---

### P1-3: 按钮系统重构（AuroraButton）

V1.3.26.7Release 的按钮系统基于 TechButton——一个从 WinForm Button 派生的自定义控件。TechButton 通过重写 OnPaint 方法，使用 GDI+ 的 Graphics 对象绘制按钮的渐变背景、边框、文本和图标。17 种动效（如悬停发光、按下缩放、释放回弹等）通过 Timer 驱动状态机实现，每个动效阶段都需要手动计算插值、更新状态、触发重绘。

V1.4.27.0 将按钮系统重构为 AuroraButton——一个从 WPF Button 派生的自定义控件。渲染使用 WPF 的 DrawingContext API，通过 DrawingVisual 绘制按钮的各个视觉层。WPF 的 DrawingContext 相比 GDI+ 的 Graphics 对象提供了更丰富的绘制原语和更高效的 GPU 加速路径。

保留的 17 种动效在 WPF 中通过 Storyboard 实现。每个动效定义为一个 Storyboard 资源，在相应的触发器（如 IsMouseOver、IsPressed、IsEnabled 变更）下启动。Storyboard 由 WPF 的动画引擎驱动，运行在合成线程上，不受 UI 线程负载影响，确保动画始终流畅。

V1.4.27.0 新增了以下按钮功能：

- **极光环境色注入**：AuroraButton 自动检测所在窗口的 AuroraGlassMaterial 环境色，将按钮的边框和发光效果与环境色匹配，实现视觉风格的统一。

- **iOS Q 弹释放反馈**：当用户快速点击按钮后释放时，按钮会执行一个超调回弹动画——按钮先缩小到 95%，然后弹回 102%，最后回落到 100%。这个动画模拟了 iOS 系统中按钮的触觉反馈感，提升了交互的愉悦度。

- **Enabled/Disabled 渐变过渡**：按钮状态从启用切换到禁用（或反之）时，不再瞬间改变，而是通过 200ms 的渐变过渡平滑切换。这个细节避免了状态切换时突兀的视觉跳跃。

- **微噪点纹理**：按钮表面覆盖一层极淡的 Perlin 噪点纹理（Opacity 0.02），增加按钮的物理质感，避免过于"数字感"的纯色表面。

**变更原因**：GDI+ 绘制复杂按钮效率低，WPF DrawingContext 提供更高性能的渲染。WPF Storyboard 运行在合成线程上，不受 UI 线程负载影响，确保动画始终流畅。新增的交互细节（环境色注入、Q 弹反馈、渐变过渡、噪点纹理）提升了整体用户体验。

**影响范围**：所有交互按钮均替换为 AuroraButton。原有 TechButton 和相关代码完全移除。

---

### P1-4: 动画系统重构

V1.3.26.7Release 的动画系统完全基于 PowerShell Timer 驱动。每个动画定义一个 Timer，在 Tick 事件中更新控件属性（位置、大小、透明度等），然后调用 Invalidate 触发重绘。这种方案的根本问题在于 PowerShell 的 Timer 回调执行效率低——每次 Tick 事件都涉及 PowerShell 解释器的调用开销，在高帧率动画（如 60fps 入场动画）中，这个开销变得不可忽略。

V1.4.27.0 采用双驱动架构重构了整个动画系统：

- **Storyboard 驱动**：适用于离散的、有明确开始和结束的动画，如窗口入场/退场、按钮动效、文本切换动画。Storyboard 由 WPF 动画引擎在合成线程上执行，提供硬件加速的插值计算，完全不受 UI 线程负载影响。

- **CompositionTarget.Rendering 驱动**：适用于连续的、实时计算的动画，如星空背景动画、毛玻璃模糊更新。CompositionTarget.Rendering 在每帧渲染前触发，与显示器 vsync 同步。

新增的 4 阶段视图切换动画是本次动画系统重构的核心亮点。当用户从一个视图切换到另一个视图时（如从主界面切换到 PRO 模式），动画按以下顺序执行：

1. **按钮退场阶段**：当前视图的所有按钮执行缩小淡出动画，每个按钮有 30ms 的延迟偏移，产生波浪般的效果。
2. **骨架退场阶段**：当前视图的背景面板执行淡出动画。
3. **骨架入场阶段**：新视图的背景面板执行淡入动画。
4. **按钮入场阶段**：新视图的按钮执行放大淡入动画，同样带有波浪延迟偏移。

整个视图切换过程约 600ms，动画的缓动曲线采用 UWP 风格（BackEase、CubicEase、PowerEase），产生自然而有弹性的视觉过渡。

AuroraTextBlock 的 IsTextTransitionEnabled 属性是解决视图切换闪烁问题的关键机制。在视图切换期间，ViewModel 的属性变更会触发 AuroraTextBlock 的文本切换动画（旧文本滑出 + 新文本滑入）。如果文本动画与视图切换动画同时执行，会产生视觉闪烁。IsTextTransitionEnabled 在视图切换开始时设为 false，抑制文本动画；切换完成后恢复为 true。这个保护机制确保了视图切换的视觉干净度。

**变更原因**：原版 Timer 驱动动画在 PowerShell 环境中执行效率低，每次 Tick 事件都涉及解释器调用开销。WPF Storyboard 在合成线程上执行，提供硬件加速插值计算。4 阶段视图切换动画和 IsTextTransitionEnabled 保护机制解决了原版中视图切换的视觉闪烁问题。

**影响范围**：所有窗口动画、视图切换、控件动效均使用新的双驱动架构。原有 Timer 动画代码完全移除。

---

### P1-5: 控制台重构（AuroraConsoleBox）

V1.3.26.7Release 的控制台基于 WinForm 的 RichTextBox 控件。日志输出通过 AppendText 方法逐行追加，每次追加都触发 RichTextBox 的格式化引擎重新计算文本布局。在 PRO 模式下，诊断脚本可能在短时间内产生数百行日志输出，逐行追加导致 UI 线程被频繁阻塞，用户体验为"卡死"。

V1.4.27.0 将控制台重构为 AuroraConsoleBox——一个从 WPF Control 派生的自定义控件，集成完整的毛玻璃背景方案。渲染不再依赖 RichTextBox 的格式化引擎，而是通过 DrawingContext 直接绘制文本，性能更高并且视觉效果可完全自定义。

核心优化是批量行刷新机制。日志行首先进入一个 ConcurrentQueue 缓冲区，而不是直接追加到 UI。一个独立的定时器以 320ms 的批次间隔检查缓冲区，将累积的日志行一次性批量渲染到 DrawingContext。这个 320ms 的延迟在"实时性"和"批量效率"之间取得了平衡——用户感知的延迟不可察觉（远低于人类的反应时间），而批量渲染消除了单行追加的开销。

批量渲染后，执行 260ms 的平滑滚动动画，将视口滚动到最新日志行。这个滚动不是瞬间跳转，而是通过一个缓出（EaseOut）曲线平滑过渡，让用户能够追踪日志的流动方向。

新增的 UWP 风格文本滑入动画进一步提升了视觉体验。每条新日志行从右侧略微滑入（偏移约 10 像素），在 200ms 内到达最终位置。这个微妙的动画让用户感知到"新内容正在产生"，而不是"文本突然出现"。

**变更原因**：原版 RichTextBox 逐行刷新在大批量日志时导致 UI 线程频繁阻塞，用户体验为"卡死"。批量行刷新（320ms 批次延迟 + 260ms 平滑滚动）消除了单行追加的开销，UWP 风格文本滑入动画提升了视觉反馈的流畅度。

**影响范围**：PRO 模式日志输出全面使用 AuroraConsoleBox。原有 RichTextBox 和相关代码完全移除。

---

### P1-6: 进度条重构（AuroraProgressBar）

V1.3.26.7Release 的进度条通过一个自定义 WinForm Panel 实现。Panel 的 Paint 事件中绘制一个填充矩形表示进度，绘制方式简单直接——纯色填充加边框，没有任何视觉效果。

V1.4.27.0 将进度条重构为 AuroraProgressBar——一个 WPF FrameworkElement 子类，采用完整的玻璃材质方案。进度条使用 AuroraGlassMaterial 共享实例渲染毛玻璃背景，视觉上与整个应用的设计语言保持一致。

新增的倾斜扫光效果是进度条视觉升级的核心。在进度条的填充区域中，一个半透明白色光带以 30 度倾斜角（通过 SkewTransform 实现）从左向右移动。光带宽度约占进度条填充区域的 20%，在 1.5 秒内完成一次从左到右的扫描。这个动效让进度条看起来"活跃"——即使进度值没有变化，扫光效果也让用户感知到系统正在工作。

进度前缘（leading edge）处有一个光点效果。光点是一个小圆形（半径约 3 像素），颜色为亮白色，跟随进度条的填充前端移动。光点的透明度从中心向外渐变衰减，产生柔和的发光感。这个细节让进度条的前端更加醒目，用户可以一目了然地看到当前进度位置。

**变更原因**：统一玻璃材质风格，使进度条与整个应用的设计语言保持一致。倾斜扫光和进度前缘光点为进度条增添了视觉层次和动态感，提升了用户体验。

**影响范围**：所有进度条显示均使用 AuroraProgressBar。原有 Panel 进度条代码完全移除。

---

### P1-7: 性能分级系统升级（AuroraRenderEngine）

V1.3.26.7Release 的性能检测通过 PowerShell 脚本实现——调用 WMI 查询 CPU 核心数、内存大小等信息，然后根据预设规则分配性能挡位。PowerShell 脚本中的 WMI 查询速度较慢，并且检测逻辑分散在多个脚本文件中。

V1.4.27.0 将性能检测升级为 C# 实现的 AuroraRenderEngine。使用 C# 的 System.Management 命名空间直接进行 WMI 查询，检测速度更快，结果更准确。检测内容包括 CPU 核心数、CPU 频率、内存总量、GPU 型号和显存大小，综合这些信息评定 4 级性能挡位：

| 挡位 | 名称 | 判定条件 | 特效配置 |
|------|------|----------|----------|
| 0 | Eco | 低端集成显卡，内存小于 4GB | 禁用粒子、禁用复杂光晕、禁用扫光、禁用路径阴影 |
| 1 | Balanced | 中端集成显卡，内存 4-8GB | 启用粒子（少量）、禁用复杂光晕、启用扫光、禁用路径阴影 |
| 2 | Performance | 中端独立显卡，内存 8-16GB | 启用粒子（中量）、启用复杂光晕、启用扫光、启用路径阴影 |
| 3 | Extreme | 高端独立显卡，内存大于 16GB | 全部特效启用，最高质量渲染 |

V1.4.27.0 新增了用户可升级挡位功能。通过 PerformanceUpgradeDialogView 对话框，用户可以手动选择高于自动检测结果的性能挡位。这个功能适用于自动检测结果偏保守的场景——例如，拥有独立显卡的笔记本电脑在电池模式下可能被检测为 Balanced，但用户连接电源后可以手动升级到 Performance。用户的选择会持久化到本地配置中，后续启动时自动应用。

**变更原因**：C# WMI 检测更快速准确，避免了 PowerShell 脚本中 WMI 查询的解释器开销。用户可升级挡位为高级用户提供了灵活性——当自动检测结果偏保守时，用户可以手动选择更高的性能挡位以获得更好的视觉效果。

**影响范围**：全局特效级别（粒子、复杂光晕、扫光、路径阴影）由 AuroraRenderEngine 的性能挡位决定。所有视觉控件的特效开关和行为根据挡位差异化配置。

---

### P1-8: 语言服务统一（LanguageService）

V1.3.26.7Release 使用双引擎文件模式支持中英文——CHSPRO.ps1（中文引擎，约 3000 行）和 ENGPRO.ps1（英文引擎，约 3000 行）。两个文件内容高度相似（约 90% 相同），仅文本字符串不同。这种双文件模式导致了严重的结构漂移问题：当一个 bug 修复在 CHSPRO 中实施时，开发者需要手动同步到 ENGPRO，而手动同步经常遗漏，导致 ENGPRO 中出现 CHSPRO 没有的功能，或者 CHSPRO 中修复的 bug 在 ENGPRO 中仍然存在。

V1.4.27.0 将双引擎文件统一为单一引擎 + LanguageService 架构。引擎文件只有一个（约 3000 行），所有用户可见的文本字符串通过 LanguageService 运行时获取。LanguageService 维护一个语言资源表，包含所有 UI 文本的中英文翻译。引擎启动时，根据语言参数（--language）加载对应的语言资源，后续所有文本通过 LanguageService 的键值查找获取。

这种统一架构消除了结构漂移问题——任何引擎逻辑的变更只需要修改一次，自动适用于所有语言。新增 UI 文本时，只需要在语言资源表中添加对应的中英文条目，不需要修改引擎代码。

**变更原因**：双引擎文件（CHSPRO/ENGPRO，合计约 6000 行重复代码）存在结构漂移——ENGPRO 独有函数 CHSPRO 缺失，bug 修复需人工同步，经常遗漏。统一为单一引擎 + LanguageService 消除了结构漂移，将维护成本降低约 50%。

**影响范围**：PRO 模式引擎、所有 UI 文本均通过 LanguageService 统一管理。原有 CHSPRO.ps1 和 ENGPRO.ps1 双文件完全合并。

---

## 4. P2 级别：新增组件

P2 级别的变更涵盖 V1.4.27.0 中新增的独立组件和服务。这些组件基于 P0 和 P1 的架构基础构建，为系统提供新的功能能力。

### P2-1: AuroraFrostedGlassBorder（毛玻璃边框控件）

AuroraFrostedGlassBorder 是一个统一的毛玻璃边框容器控件，继承自 WPF 的 Border。它使用 AuroraGlassMaterial 共享实例的四层渲染管线（双层投影、真模糊背景、玻璃主体渐变、表层覆盖），为内部内容提供毛玻璃视觉效果。

该控件是 ElevationDialogView、MainFormView 等对话框的玻璃面板的基础容器。所有需要毛玻璃背景的对话框，只需将内容放置在 AuroraFrostedGlassBorder 内部即可自动获得一致的玻璃材质效果，无需重复实现渲染逻辑。

**用途**：ElevationDialogView、MainFormView 等对话框的玻璃面板。

---

### P2-2: AuroraTaskHUD（任务状态 HUD）

AuroraTaskHUD 是一个横向 4 步骤节点指示器控件，用于 PRO 模式任务进度的可视化。它显示 4 个顺序排列的节点，每个节点代表一个任务阶段（如"诊断"、"修复"、"验证"、"完成"），节点之间通过连接线相连。

每个节点有 4 种状态：Pending（灰暗、未到达）、Running（亮色、脉冲动画、表示当前正在执行的阶段）、Success（绿色、勾选图标、表示已完成）、Error（红色、叉号图标、表示失败）。状态切换通过平滑的颜色过渡和图标变换实现，让用户对任务进度一目了然。

**用途**：PRO 模式任务进度可视化，让用户清晰了解当前执行阶段和整体进度。

---

### P2-3: AuroraTextBlock（文本控件）

AuroraTextBlock 是一个支持 UWP 风格文本切换动画的文本控件，继承自 WPF 的 TextBlock。当绑定的文本内容发生变化时，AuroraTextBlock 不会瞬间替换文本，而是执行一个流畅的过渡动画：旧文本向上或向下滑出（根据内容变化方向），同时新文本从相反方向滑入。

IsTextTransitionEnabled 属性是 AuroraTextBlock 的核心保护机制。在视图切换期间，如果 ViewModel 的多个属性同时变更，会触发多个 AuroraTextBlock 同时执行文本动画，与视图切换动画叠加产生视觉混乱。通过将 IsTextTransitionEnabled 设为 false，文本动画被临时抑制，只显示最终文本值；视图切换完成后恢复为 true，后续的文本变更恢复正常动画。

**用途**：所有动态文本显示，如窗口标题、进度百分比、状态标签等。

---

### P2-4: AuroraCustomEasing（自定义缓动曲线）

AuroraCustomEasing 是一个基于 Spring-Damper 弹簧物理模型的自定义缓动曲线。与 WPF 内置的缓动函数（如 CubicEase、BackEase）不同，Spring-Damper 模型模拟了真实的物理弹簧行为——阻尼系数控制弹簧的衰减速度，弹性系数控制弹簧的刚度，质量参数影响弹簧的惯性。

该缓动曲线主要用于 SplashScreen 入场动画。当启动画面出现时，AuroraCustomEasing 驱动一个超调回弹的缩放动画，让启动画面以"弹跳"的方式呈现，增强了品牌的视觉冲击力。

**用途**：SplashScreen 入场动画，提供弹簧物理模型的超调回弹效果。

---

### P2-5: IntegrityGuardService（完整性守护服务）

IntegrityGuardService 是 C# 实现的完整性校验和反调试机制。在程序启动时，该服务执行以下验证步骤：

- 校验所有核心文件的 SHA-256 哈希值，与构建时嵌入的哈希列表比对，确保文件未被篡改。
- 检测调试器附加状态，通过 CheckRemoteDebuggerPresent 和 IsDebuggerPresent API 判断是否有调试器试图附加到进程。
- 验证看门狗连接状态，确保与看门狗进程的通信通道正常。

任何验证失败都会触发安全响应流程——中断启动、显示安全警告并记录事件。

**用途**：程序启动时的安全验证，确保代码完整性和运行环境安全。

---

### P2-6: ElevationService + ElevationTokenService（提权服务）

ElevationService 和 ElevationTokenService 协同工作，实现了安全的 UAC 提权流程。当程序需要管理员权限时（如修改系统注册表、写入受保护目录），这两个服务按以下流程工作：

1. ElevationTokenService 生成一个提权令牌，使用 AES-256-CBC 加密。令牌包含 nonce、timestamp 和 payload（加密了脚本路径和哈希列表）。
2. 令牌写入临时文件，通过命令行参数 `-ElevationTokenPath` 传递给新的提权进程。
3. 提权进程启动后，ElevationService 读取令牌文件，使用 PBKDF2 派生密钥进行解密。
4. 验证解密内容中包含合法标识符，确认令牌来源的合法性。
5. 令牌有效期为 120 秒，超时后自动失效。

**用途**：需要管理员权限时的安全提权，确保信任链在 UAC 提权过程中不中断。

---

### P2-7: WatchdogService（看门狗服务）

WatchdogService 是一个进程监控和异常恢复服务。它维护一个独立的看门狗进程，持续监控主程序的运行状态。看门狗进程通过命名管道与主程序保持心跳通信，如果主程序在规定时间内未发送心跳信号，看门狗判定主程序异常退出，执行清理操作（释放资源、清理临时文件、重置安全状态）并记录异常事件。

此外，WatchdogService 还负责监控主程序的内存使用情况，当内存使用超过阈值时发出警告，并在必要时触发优雅关闭流程。

**用途**：确保程序稳定运行，在异常退出时执行清理操作，防止资源泄漏和安全状态残留。

---

### P2-8: SessionCacheService + UndoManagerService + RestoreService

这三个服务协同工作，提供完整的工作进度保存和恢复能力：

- **SessionCacheService**：将当前工作会话的状态（进度、参数、中间结果）序列化并持久化到本地缓存。缓存数据以 JSON 格式存储，包含时间戳、阶段标识和进度百分比。

- **UndoManagerService**：维护一个操作历史栈，记录用户的每一步操作。当用户触发撤销时，UndoManagerService 从栈顶弹出最近的操作并执行逆操作，恢复到操作前的状态。

- **RestoreService**：在程序启动时检测是否有未完成的会话。如果有，RestoreService 读取缓存数据，计算 AgeInDays（会话中断天数），通过 SessionRestoreDialogView 提示用户是否恢复之前的进度。

**用途**：支持工作进度保存和恢复，避免因意外退出导致的工作进度丢失。

---

## 5. P3 级别：优化与修复

P3 级别的变更聚焦于性能优化和视觉缺陷修复。这些变更不影响功能行为，但显著提升了用户体验和系统稳定性。

### P3-1: 帧率归一化

AuroraStarfield 的动画参数（星点移动速度、闪烁频率、透明度变化速率）在 V1.3.26.7Release 中按 30fps 设计。迁移到 WPF 后，CompositionTarget.Rendering 以 60fps 驱动，如果直接使用原版参数，所有动画会以两倍速运行。

修复方案是引入 animationTimeScale 因子（值为 0.5），将所有动画增量乘以该因子。这样，在两倍帧率下，每帧的增量减半，总体动画速度保持不变。这种归一化确保了 WPF 版本的星空动画行为与原版 WinForm 版本完全一致。

**原因**：原版 WinForm 常量按 30fps 设计，WPF 60fps 导致动画 2 倍速。通过 animationTimeScale 因子将所有动画增量归一化到 30fps 基准。

---

### P3-2: 笔刷缓存池化

在 WPF 中，Brush 对象（SolidColorBrush、LinearGradientBrush 等）的创建涉及非托管资源的分配。如果每帧都创建新的 Brush 对象，会导致频繁的 GC 分配和回收，增加渲染开销。

AuroraGlassMaterial 和 AuroraStarfield 在初始化时预创建所有需要的静态 Brush 对象，并调用 Freeze 方法将其冻结为不可变状态。冻结后的 Brush 可以被 WPF 渲染引擎以更快路径访问，因为不需要考虑线程安全问题。所有帧间共享的 Brush 都被缓存和复用，消除了每帧的 GC 分配。

**原因**：消除每帧 GC 分配。通过预创建并 Freeze 静态 Brush 对象，减少渲染开销，提高帧率稳定性。

---

### P3-3: 模糊背景 30fps 节流

AuroraGlassMaterial 的模糊背景生成涉及 RenderTargetBitmap.Render 调用——这是一个相对昂贵的操作，因为它需要捕获控件后方的完整视觉树并应用高斯模糊。在 60fps 的 CompositionTarget.Rendering 驱动下，每帧都执行这个操作会产生不必要的计算开销。

节流优化将模糊背景的更新频率从 60fps 降至 30fps——每两帧才执行一次 RenderTargetBitmap.Render。模糊效果本质上是平滑的视觉变化，肉眼无法区分 30fps 与 60fps 的模糊更新频率。这个优化将模糊背景的渲染开销降低了一半，同时保持了视觉质量。

**原因**：模糊效果本质平滑，肉眼无法区分 30fps 与 60fps 模糊更新。将 RenderTargetBitmap.Render 频率降低一半，显著减少渲染开销。

---

### P3-4: 无 Glass 控件时跳过 RTB

在 SplashScreen 启动画面显示期间，没有任何使用 AuroraGlassMaterial 的控件注册到渲染管道中。在这种情况下，AuroraGlassMaterial 的 RenderTargetBitmap.Render 调用是完全不必要的——它捕获的画面不会被任何控件使用。

优化逻辑是维护一个注册计数器，追踪当前有多少控件在使用 AuroraGlassMaterial。当计数器为 0 时，完全跳过 RTB.Render 调用。SplashScreen 的动画由 Storyboard 独占 UI 线程，避免 RTB.Render 的额外开销可以防止动画丢帧。

**原因**：Splash 动画由 Storyboard 独占 UI 线程，RTB.Render 的无谓调用会导致丢帧。通过注册计数器检测，在无 Glass 控件时完全跳过 RTB.Render。

---

### P3-5: 视图切换闪烁修复

WPF 在 Loaded 事件触发前已完成首帧渲染。这意味着如果一个控件在 XAML 中定义了可见的初始状态，在 Loaded 事件处理程序将其改为隐藏状态之前，用户会看到一帧"闪现"的初始状态，产生闪烁感。

修复方案是在 XAML 中将所有控件的初始状态设为隐藏（Opacity=0、Visibility=Collapsed 或适当的初始变换），在 Loaded 事件处理程序中再启动入场动画将其变为可见。这样，首帧渲染时控件处于隐藏状态，用户看不到任何内容，入场动画从隐藏状态平滑过渡到可见状态。

**原因**：WPF 在 Loaded 事件触发前已完成首帧渲染，导致控件初始状态"闪现"。通过在 XAML 中设置隐藏初始态，在 Loaded 事件中启动入场动画，避免首帧闪现。

---

### P3-6: 标题双动效修复

在视图切换期间，ViewModel 的标题属性变更触发 AuroraTextBlock 的文本切换动画（旧文本滑出 + 新文本滑入）。同时，视图切换动画也在执行（骨架退场/入场、按钮退场/入场）。两个动画叠加导致视觉闪烁——同一个区域同时有两种不同的动画在运行。

修复方案是通过 AuroraTextBlock 的 IsTextTransitionEnabled 属性。在视图切换开始时，将该属性设为 false，抑制文本切换动画；切换完成后恢复为 true。这样，视图切换期间只显示最终的标题文本（无动画），避免了双动画叠加的闪烁。

**原因**：ViewModel 属性变更触发文本动画，与视图切换动画叠加导致闪烁。通过 IsTextTransitionEnabled 在视图切换时临时禁用文本动画，消除双动效冲突。

---

### P3-7: 进程退出安全清理

在 V1.3.26.7Release 中，Timer 通过 Tick 事件对控件持有强引用。如果 Timer 在窗口关闭时未被停止，这个强引用会阻止 GC 回收控件对象，导致内存泄漏。更严重的是，SplashScreen 关闭时如果 Starfield 动画的 Timer 仍在运行，可能在新窗口创建后继续触发 Tick 事件，访问已关闭的 SplashScreen 控件，导致异常。

V1.4.27.0 中，所有控件实现 IDisposable 接口。在 Dispose 方法中，控件停止所有动画（Storyboard 和 CompositionTarget.Rendering 事件处理程序）、释放所有 Dispatcher 资源、取消所有事件订阅。窗口关闭时，框架调用所有子控件的 Dispose 方法，确保资源被完全释放。

SplashScreen 关闭时特别调用 Starfield 的 Dispose 方法，停止 CompositionTarget.Rendering 订阅，防止在窗口关闭后继续触发动画。

**原因**：Timer 通过 Tick 事件强引用控件，阻止 GC 回收。所有控件实现 IDisposable，在窗口关闭时彻底释放资源。Splash 关闭时停止 Starfield 动画，防止访问已关闭窗口。

---

### P3-8: 控制台批量刷新

PRO 模式下的诊断脚本可能在短时间内产生大量日志输出。V1.3.26.7Release 的逐行刷新方式导致 Dispatcher 队列堆积——每一行日志都作为一个独立的 UI 更新操作入队，大量操作同时等待 UI 线程处理，导致 UI 完全无响应。

批量刷新方案使用 ConcurrentQueue 作为缓冲区。日志行先入队，一个独立的定时器以 320ms 间隔检查队列，将累积的日志行一次性批量写入 UI。这大幅减少了 Dispatcher 操作的数量（从每行一个操作减少到每批次一个操作），避免了队列堆积。

50ms 的初始延迟进一步优化了启动阶段的体验——在启动阶段，日志输出速度很快，50ms 的延迟让第一批日志行有足够的时间累积，之后再进入 320ms 的正常批次间隔。

**原因**：大量日志逐行刷新导致 Dispatcher 队列堆积，UI 完全无响应。ConcurrentQueue 缓冲区 + 320ms 批量刷新大幅减少 Dispatcher 操作数量，消除 UI 卡死。

---

## 6. 兼容性保持

V1.4.27.0 虽然底层架构发生了根本性变化，但在以下方面保持了与 V1.3.26.7Release 的完全兼容：

| 兼容项 | 说明 |
|--------|------|
| PowerShell 5.1 兼容 | C# 代码使用 C# 5.0 语言版本，确保在 Windows 自带的 PowerShell 5.1 环境中无需额外安装 .NET Framework 即可运行 |
| 命令行参数 | 所有命令行参数完全兼容，包括 --pro、--language、--launched-by-exe、--ElevationTokenPath 等 |
| syncHash 同步机制 | 跨 Runspace 通信的 syncHash 接口完全兼容，脚本端读写方式不变 |
| 环境变量接口 | AURORA_PERF_TIER、AURORA_LANGUAGE、AURORA_TOKEN_PATH、AURORA_LAUNCHED_BY_EXE 等环境变量接口完全兼容 |
| LogOutput 类型 | LogOutput 保持 string 类型，支持脚本端的 += 字符串拼接操作，确保原有脚本不受影响 |
| 启动流程 | 启动器（EXE）与 PowerShell 脚本的交互流程不变，仅内部实现从 WinForm 替换为 WPF |

这些兼容性保证意味着现有用户无需修改任何脚本、配置或启动参数即可升级到 V1.4.27.0。

---

## 7. 变更清单总览

| 编号 | 级别 | 变更描述 | 变更原因 | 影响范围 |
|------|------|----------|----------|----------|
| P0-1 | P0 | UI 框架从 WinForm 迁移到 WPF | GDI+ 渲染性能有限，无法实现现代毛玻璃效果；WPF 提供 GPU 加速渲染 | 所有窗口、控件、动画系统 |
| P0-2 | P0 | MVVM 架构引入 | 原版无分层，UI 与业务逻辑混杂，难以维护和测试 | 所有视图和业务逻辑 |
| P0-3 | P0 | PowerShell 集成方式从单 Runspace 升级为 RunspacePool | 单 Runspace 无法并行处理多个脚本任务 | PRO 模式脚本执行、日志输出、进度报告 |
| P0-4 | P0 | C# 5.0 编译控件库替代 PowerShell 动态创建 | 编译代码效率更高，编译时类型检查消除运行时错误 | 所有 UI 控件 |
| P1-1 | P1 | 毛玻璃材质系统（AuroraGlassMaterial） | WinForm 无法实现真模糊背景；四层渲染管线实现逼真玻璃效果 | AuroraFrostedGlassBorder、AuroraConsoleBox、AuroraTaskHUD、AuroraButton |
| P1-2 | P1 | 星空背景重构（AuroraStarfield） | DispatcherTimer 帧率不稳定；CompositionTarget.Rendering 与 vsync 对齐 | 所有窗口的星空背景 |
| P1-3 | P1 | 按钮系统重构（AuroraButton） | GDI+ 绘制效率低；WPF Storyboard 硬件加速动画 | 所有交互按钮 |
| P1-4 | P1 | 动画系统重构（双驱动架构） | Timer 驱动效率低；Storyboard 合成线程硬件加速 | 所有窗口动画、视图切换、控件动效 |
| P1-5 | P1 | 控制台重构（AuroraConsoleBox） | 逐行刷新导致 UI 卡死；批量刷新消除性能瓶颈 | PRO 模式日志输出 |
| P1-6 | P1 | 进度条重构（AuroraProgressBar） | 统一玻璃材质风格，新增扫光和光点效果 | 所有进度条显示 |
| P1-7 | P1 | 性能分级系统升级（AuroraRenderEngine） | C# WMI 检测更快更准；用户可升级挡位提供灵活性 | 全局特效级别 |
| P1-8 | P1 | 语言服务统一（LanguageService） | 双引擎文件结构漂移，bug 修复需人工同步 | PRO 模式引擎、所有 UI 文本 |
| P2-1 | P2 | 新增 AuroraFrostedGlassBorder | 统一毛玻璃边框容器，避免重复实现渲染逻辑 | 对话框玻璃面板 |
| P2-2 | P2 | 新增 AuroraTaskHUD | 横向 4 步骤节点指示器，任务进度可视化 | PRO 模式任务进度 |
| P2-3 | P2 | 新增 AuroraTextBlock | 支持 UWP 风格文本切换动画，IsTextTransitionEnabled 保护机制 | 所有动态文本显示 |
| P2-4 | P2 | 新增 AuroraCustomEasing | Spring-Damper 弹簧物理模型缓动 | SplashScreen 入场动画 |
| P2-5 | P2 | 新增 IntegrityGuardService | C# 实现的完整性校验和反调试机制 | 启动时安全验证 |
| P2-6 | P2 | 新增 ElevationService + ElevationTokenService | AES-256-CBC 加密提权令牌，安全 UAC 提权 | 管理员权限提权流程 |
| P2-7 | P2 | 新增 WatchdogService | 进程监控和异常恢复 | 程序稳定运行保障 |
| P2-8 | P2 | 新增 SessionCacheService + UndoManagerService + RestoreService | 会话缓存、撤销管理、恢复服务 | 工作进度保存和恢复 |
| P3-1 | P3 | 帧率归一化 | 原版 30fps 常量在 60fps 下导致 2 倍速动画 | 星空背景动画 |
| P3-2 | P3 | 笔刷缓存池化 | 消除每帧 GC 分配，减少渲染开销 | 玻璃材质和星空渲染 |
| P3-3 | P3 | 模糊背景 30fps 节流 | 肉眼无法区分 30fps 与 60fps 模糊更新 | 毛玻璃背景渲染 |
| P3-4 | P3 | 无 Glass 控件时跳过 RTB | 避免 Splash 动画期间无谓的 RTB 开销 | 启动画面性能 |
| P3-5 | P3 | 视图切换闪烁修复 | Loaded 事件前首帧已渲染导致初始状态闪现 | 所有窗口的视图切换 |
| P3-6 | P3 | 标题双动效修复 | 文本动画与视图切换动画叠加导致闪烁 | 视图切换期间标题显示 |
| P3-7 | P3 | 进程退出安全清理 | Timer 强引用阻止 GC 回收，导致资源泄漏 | 所有控件生命周期 |
| P3-8 | P3 | 控制台批量刷新 | 大量日志逐行刷新导致 Dispatcher 队列堆积 | PRO 模式日志输出性能 |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *本工具仅供个人学习使用。请遵守当地法律法规。*