# AURORA Analyzer V1.4.27.5 更新说明

> **Windows 事件日志导出与智能诊断工具**
>
> 版本：V1.4.27.5Release · 构建时间：2026.07.07 · 作者：AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **警告**：本工具仅用于个人学习使用。请遵守当地法律法规。

---

## 目录

1. [版本概述](#1-版本概述)
2. [P1 级别：窗口入场动效统一](#2-p1-级别窗口入场动效统一)
3. [P2 级别：窗口退场动效统一](#3-p2-级别窗口退场动效统一)
4. [P3 级别：对话框窗口动效移植](#4-p3-级别对话框窗口动效移植)
5. [P4 级别：V5 玻璃材质管线优化](#5-p4-级别v5-玻璃材质管线优化)
6. [P5 级别：材质光学层逐层打磨](#6-p5-级别材质光学层逐层打磨)
7. [P6 级别：果冻弹性动效系统](#7-p6-级别果冻弹性动效系统)
8. [P7 级别：AuroraButton 果冻回弹](#8-p7-级别aurorabutton-果冻回弹)
9. [P8 级别：缺陷修复](#9-p8-级别缺陷修复)
10. [兼容性保持](#10-兼容性保持)
11. [变更清单总览](#11-变更清单总览)

---

## 1. 版本概述

V1.4.27.5 是 AURORA Analyzer 的动效与材质系统全面升级版本。本次更新涵盖三大核心领域：窗口缩放动效统一、V5 玻璃材质管线优化、果冻弹性动效系统。PowerShell 引擎层保持兼容，所有命令行参数、环境变量接口和 syncHash 同步机制均维持不变。

在窗口缩放动效方面，此前各窗口的参数参差不齐：SplashScreen 采用入场 1.15→1.0、退场 1.0→1.15 的放大冲出模式；MainFormView 和 ProModeView 采用入场 1.1→1.0、退场 1.0→0.85 的缩小消退模式；ElevationDialogView 采用入场 1.08→1.0、退场 1.0→0.85；SessionRestoreDialogView 无任何窗口级动效；PerformanceUpgradeDialogView 采用缩小式入场 0.92→1.0 和简单淡出退场。

V1.4.27.5 通过以下核心策略实现了全面升级：

- **入场统一**：所有窗口入场缩放统一为 1.15→1.0（放大收敛），伴随 Opacity 0→1 淡入。对话框窗口使用 400ms UwpExpoOutEase 缓动，主窗口和 PRO 模式使用 600ms AuroraCustomBackEase 缓动。
- **退场统一**：所有窗口退场缩放统一为 1.0→1.15（放大冲出），伴随 Opacity 1→0 淡出。统一使用 800ms QuadraticEase/CubicEase EaseOut 缓动。
- **星空锁定统一**：所有窗口在入场/退场动画期间统一使用 IsWindowAnimating 锁定星空背景降级渲染，Closed 事件统一调用 StopAnimation 防止定时器泄漏。
- **V5 玻璃材质管线优化**：修复 RtbBlurBackend 硬编码模糊半径和重复节流，提升 ShaderEffectBackend MaxShaderBlurRadius 至 40，校准 AuroraFluentGlass 预设（BlurRadius 12→8，BlurSaturation 1.0→1.4），异步化渲染流水线（UI 线程 4ms→1.5ms/帧）。
- **14 层光学层逐层打磨**：BodyLayer 环境色混合、SpecularLayer 双光斑+呼吸漂移、FresnelLayer 四方向线性渐变重写、BevelLayer 4 段渐变、EdgeHighlightLayer 峰值降低，新增 CausticsLayer 和 IridescenceLayer。
- **果冻弹性动效系统**：AuroraButton hover 离开三阶段果冻回弹（~271ms）、iOS Q弹释放反馈、磁吸回弹改纯 EaseOutCubic、控件交错入场 1.07 过冲收敛、窗口液态玻璃微回弹，新增 11 个缓动曲线类。

本次更新是一个"动效与材质全面升级、底层兼容"的版本。所有面向用户的命令行接口、环境变量和跨 Runspace 通信协议均保持完全兼容，确保现有脚本和工作流无需修改即可运行。

---

## 2. P1 级别：窗口入场动效统一

P1 级别的变更是将所有窗口的入场缩放统一为 1.15→1.0。

### P1-1: 对话框窗口入场统一（400ms UwpExpoOutEase）

ElevationDialogView、SessionRestoreDialogView、PerformanceUpgradeDialogView 三个对话框窗口统一采用与 SplashScreen 完全一致的入场参数：ScaleTransform 1.15→1.0，Opacity 0→1，400ms，UwpExpoOutEase（EaseIn）缓动。动画完成后解锁星空并启动控件级交错入场。

**变更原因**：三个对话框窗口的入场动效参数各不相同（1.08→1.0、无动效、0.92→1.0），缺乏统一性。统一为 Splash 风格后，所有对话框的入场视觉语言一致。

**影响范围**：ElevationDialogView、SessionRestoreDialogView、PerformanceUpgradeDialogView 的入场动画。

---

### P1-2: MainFormView 入场统一（600ms AuroraCustomBackEase）

MainFormView 构造函数中预设的初始缩放从 ScaleX=1.1, ScaleY=1.1 提升至 ScaleX=1.15, ScaleY=1.15。PlayWindowEnterAnimation 中的缩放动画起点从 1.1 改为 1.15，保留 600ms 时长和 AuroraCustomBackEase 缓动曲线。

**变更原因**：MainFormView 入场起始缩放 1.1 与 SplashScreen 的 1.15 不一致，统一为 1.15 后所有窗口的入场起始幅度一致。

**影响范围**：MainFormView 的入场动画。

---

### P1-3: ProModeView 入场统一（600ms AuroraCustomBackEase）

AnimationHelper.PlayProModeWindowEnter 中的缩放动画起点从 1.1 改为 1.15，保留 600ms 时长和 AuroraCustomBackEase 缓动曲线。

**变更原因**：ProModeView 入场起始缩放 1.1 与 SplashScreen 的 1.15 不一致，统一为 1.15。

**影响范围**：ProModeView 的入场动画。

---

### P1-4: AnimationHelper.PlayMainWindowEnter 统一

AnimationHelper.PlayMainWindowEnter 中的缩放动画起点从 1.1 改为 1.15，保留 600ms 时长和 AuroraCustomBackEase 缓动。该方法被 AuroraExitCountdownView 等窗口使用。

**变更原因**：PlayMainWindowEnter 的起始缩放 1.1 与 Splash 风格不一致。

**影响范围**：所有使用 PlayMainWindowEnter 的窗口。

---

## 3. P2 级别：窗口退场动效统一

P2 级别的变更是将所有窗口的退场缩放统一为 1.0→1.15（放大冲出），取代之前的 1.0→0.85（缩小消退）。

### P2-1: MainFormView 退场统一

MainFormView.PlayWindowScaleAndFadeOut 中的缩放动画从 1.0→0.85 改为 1.0→1.15，时长从 450ms 延长至 800ms，缩放缓动从 CubicEase EaseIn 改为 QuadraticEase EaseOut，淡出缓动从 CubicEase EaseIn 改为 CubicEase EaseOut。

**变更原因**：MainFormView 的缩小消退退场（1.0→0.85）与 SplashScreen 的放大冲出退场（1.0→1.15）方向相反。统一为放大冲出后，所有窗口的退场视觉语言一致——"化为星光远去"而非"向中心塌缩"。

**影响范围**：MainFormView 的退场动画，包括正常退出和 PRO 模式切换。

---

### P2-2: ProModeView 退场统一

AnimationHelper.PlayMainWindowExit 中的缩放动画从 1.0→0.85 改为 1.0→1.15，时长从 450ms 延长至 800ms，缩放缓动从 CubicEase EaseIn 改为 QuadraticEase EaseOut，淡出缓动从 CubicEase EaseIn 改为 CubicEase EaseOut。

**变更原因**：ProModeView 通过 PlayMainWindowExit 退场，其缩小消退方向与 Splash 风格相反。

**影响范围**：ProModeView 的退场动画。

---

### P2-3: 对话框窗口退场统一

ElevationDialogView、SessionRestoreDialogView、PerformanceUpgradeDialogView 三个对话框窗口的退场缩放统一为 1.0→1.15，800ms，QuadraticEase/CubicEase EaseOut。ElevationDialogView 之前为 1.0→0.85 收缩；SessionRestoreDialogView 之前无退场动画；PerformanceUpgradeDialogView 之前仅 180ms 简单淡出。

**变更原因**：三个对话框的退场动效各不相同，且与 Splash 风格不一致。统一后所有窗口的退场都呈现出"放大消散"的视觉语言。

**影响范围**：三个对话框窗口的退场动画。

---

## 4. P3 级别：对话框窗口动效移植

P3 级别的变更涵盖将 Splash 风格的完整动效生命周期移植到此前缺少动效的对话框窗口。

### P3-1: ElevationDialogView RenderTransform 层级修复

ElevationDialogView 的 RenderTransform 从 RootGrid 移到 Window 级别，并添加 Window.RenderTransform 中的 TransformGroup(ScaleTransform + TranslateTransform)。XAML 中预设 ScaleTransform ScaleX="1.15" ScaleY="1.15" 避免首帧闪烁。

**变更原因**：RenderTransform 放在 RootGrid 上时，OnLoaded 中操作 this.RenderTransform 的动画代码找不到目标变换，导致初始缩放永不被收回。

**影响范围**：ElevationDialogView 的入场/退场动画。

---

### P3-2: SessionRestoreDialogView 完整动效移植

SessionRestoreDialogView 添加了完整的入场/退场动画生命周期：Window 级别 RenderTransform、XAML 预设 ScaleTransform 1.15、OnLoaded 入场动画（1.15→1.0，400ms）、PlayWindowExitAnimation 退场动画（1.0→1.15，800ms）、Closed 事件 StopAnimation 清理。

**变更原因**：此前该窗口没有任何窗口级动效，出现和消失都是瞬间的。

**影响范围**：SessionRestoreDialogView 的完整动效生命周期。

---

### P3-3: PerformanceUpgradeDialogView 动效升级

PerformanceUpgradeDialogView 的 XAML 中 ScaleTransform 初始值从 1.10 改为 1.15，入场动画从 0.92→1.0（缩小式）改为 1.15→1.0（放大收敛），退场从 180ms 简单淡出改为 1.0→1.15 放大冲出 800ms。添加 IsWindowAnimating 星空锁定和 Closed 事件 StopAnimation 清理。

**变更原因**：缩小式入场与 Splash 风格相反，简单淡出退场缺乏仪式感。

**影响范围**：PerformanceUpgradeDialogView 的入场/退场动画。

---

### P3-4: 星空锁定机制统一

所有对话框窗口在 OnLoaded 中设置 StarfieldBg.IsWindowAnimating = true（入场动画期间锁定），动画完成后解锁；退场动画开始时锁定，Closed 事件调用 StopAnimation 停止。

**变更原因**：部分对话框窗口此前未使用 IsWindowAnimating 锁定，窗口缩放动画期间星空全特效渲染导致性能下降；未调用 StopAnimation 导致 DispatcherTimer 泄漏。

**影响范围**：所有对话框窗口的星空背景渲染和定时器生命周期。

---

## 5. P4 级别：V5 玻璃材质管线优化

P4 级别的变更涵盖 V5 材质管线的模糊后端修复、材质预设校准和管线架构改进。

### P4-1: RtbBlurBackend 硬编码模糊半径修复

删除 RtbBlurBackend 中硬编码的 `CaptureBlurRadius=3.0`，改用传入的实际 blurRadius 参数 × CaptureScale 进行分辨率补偿。

**变更原因**：硬编码 3.0 导致所有材质风格的模糊半径被固定为等效 6px，无法体现不同预设的 BlurRadius 差异。

**影响范围**：RtbBlurBackend.cs 行 257-260。

---

### P4-2: RtbBlurBackend 重复节流移除

移除 RtbBlurBackend 内部的 33ms 节流逻辑。Pipeline 已通过 `BackgroundCaptureThrottleMs=33ms` 统一节流，RTB 内部重复节流导致最坏 ~66ms 延迟，极光模糊跟随明显滞后。

**变更原因**：双层节流导致极光模糊在窗口移动时出现可见延迟。

**影响范围**：RtbBlurBackend.cs 行 113-116。

---

### P4-3: RtbBlurBackend 异步化渲染流水线

将模糊渲染从同步改为异步两阶段流水线：UI 线程截图（~1.5ms）+ 后台线程 Task.Run 模糊（~2.5ms），UI 线程 CPU 开销从 4ms/帧降至 1.5ms/帧。

**变更原因**：同步渲染导致 UI 线程在每帧背景捕获时阻塞 4ms，影响动画流畅度。

**影响范围**：RtbBlurBackend.cs 行 155-174。

---

### P4-4: ShaderEffectBackend MaxShaderBlurRadius 提升

将 MaxShaderBlurRadius 从 8.0 提升至 40.0，避免截断高模糊预设（BlurRadius=12 → 12/0.5=24 被截断到 8）。同时添加 1/2 分辨率下模糊半径视觉放大 2× 的补偿：`shaderEffect.BlurRadius = Math.Min(blurRadius / RenderScale, MaxShaderBlurRadius)`。

**变更原因**：高模糊预设被截断导致玻璃模糊效果不明显。

**影响范围**：ShaderEffectBackend.cs 行 41、138。

---

### P4-5: AuroraMaterialPipeline 共享捕获参数

共享捕获模糊半径从硬编码 6.0 改为取所有注册 Composer 的 `Preset.BlurRadius` 最大值；共享饱和度取所有 Composer 的最大 `BlurSaturation`。

**变更原因**：硬编码 6.0 无法适配不同材质风格的模糊需求。

**影响范围**：AuroraMaterialPipeline.cs 行 493-506。

---

### P4-6: MaterialStylePreset 校准（AuroraFluentGlass）

BlurRadius 12→8（修复后端后模糊量翻倍过强），BlurSaturation 1.0→1.4（Mica vibrance +40%），NoiseAmplitude 0.04→0.07（越过 IsAnimating 阈值），RimLightStrength 0.3→0.35。新增 TintColor(90,200,255)、TintStrength 0.15、FresnelStrength 0.25、SpecularStrength 0.5、ChromaticAberration 0.4、RefractionStrength 0.3、BevelDepth 0.6、CausticsStrength 0.35、IridescenceStrength 0.3 等完整光学参数。

**变更原因**：旧版预设参数不完整，模糊量在后端修复后翻倍过强，饱和度不足导致玻璃偏灰。

**影响范围**：MaterialStylePreset.cs 行 100-120。

---

## 6. P5 级别：材质光学层逐层打磨

P5 级别的变更涵盖 14 层光学层的逐层参数精调。

### P5-1: BodyLayer 环境色混合

颜色混合从纯 TintColor 恒冷蓝改为 60% AmbientColor + 40% TintColor。depthFactor 0.6→0.68，bottomAlpha 系数 0.7→0.78，底部偏暗系数 0.7→0.66，边框 alpha 35→45，方向边框 alpha 70→55。

**变更原因**：纯 TintColor 恒冷蓝无法响应环境色变化，缺乏自然感。

**影响范围**：BodyLayer.cs 行 87-97、104、106、114、149、175-176。

---

### P5-2: SpecularLayer 双光斑+呼吸漂移

新增次级光斑 (0.72, 0.78) 右下象限，SecondaryStrengthRatio=0.4。主光斑 sin 漂移（DriftAmplitude=0.02, DriftSpeed=0.0008，约 8 秒一周期）。IsBreathing=true 持续重绘。颜色 75% 白 + 25% AmbientColor。

**变更原因**：旧版单光斑缺乏动态感，镜面高光过于静态。

**影响范围**：SpecularLayer.cs 行 47-56、89、147-149。

---

### P5-3: FresnelLayer 四方向线性渐变重写

从单 RadialGradientBrush 重写为 4 个 LinearGradientBrush（top/bottom/left/right）。朝光组(顶/左) BrightCoeff=150，背光组(底/右) DimCoeff=30。带宽=短边的 50%。朝光组冷色、背光组暖色（色温偏移）。

**变更原因**：单径向渐变无法表达方向性菲涅尔效果，缺乏光感层次。

**影响范围**：FresnelLayer.cs 行 15-27、40-41、45、104-114。

---

### P5-4: BevelLayer 4 段渐变升级

Order 100→95（与 EdgeHighlight 交换）。顶部深度笔从 2 段→4 段白渐变（peak 80→45→16→0），底部深度笔从 2 段→4 段黑渐变（0→15→45→90）。新增顶部入射高光带（高度=bevelDepth×3.5, peak 130, mid 55）和底部反射光带（高度=bevelDepth×2.5, reflMid 28, reflPeak 45）。

**变更原因**：2 段渐变过渡生硬，缺乏斜面立体感。

**影响范围**：BevelLayer.cs 行 69、175-243。

---

### P5-5: EdgeHighlightLayer 峰值降低

Order 95→100（与 Bevel 交换）。BasePeakAlpha 90→60，BrightnessModulation 80→40（旧版峰值 90-170 过强形成白边）。GaussianSigma 0.22→0.19（peak 更锐利），高光带宽度 2.0→2.2。IsFlowing 独立动画属性持续 60fps 重绘。

**变更原因**：旧版峰值过高在玻璃边缘形成明显白边，不够精致。

**影响范围**：EdgeHighlightLayer.cs 行 58、63-64、71、98、227。

---

### P5-6: ChromaticLayer/RefractionLayer 层级调整

ChromaticLayer Order 40→105（移到 Body 之上避免被衰减），PeakAlphaCoeff 40→80。RefractionLayer Order 30→62（移到 Body 之上），peak 80→100，背光面 30→35。

**变更原因**：色散和折射在 Body 之下被衰减，视觉效果不明显。

**影响范围**：ChromaticLayer.cs 行 86、58；RefractionLayer.cs 行 97、50、53。

---

### P5-7: 新增 CausticsLayer 和 IridescenceLayer

CausticsLayer（V1.4.29 光学增强新增）：Order=75，预生成 128×128 sin/cos 干涉纹理，IsFlowing 持续位移，BaseOpacity 0.35→0.50。IridescenceLayer：PeakAlphaCoeff 55→75。

**变更原因**：焦散和虹彩是真实玻璃的重要光学特征，旧版缺失。

**影响范围**：CausticsLayer.cs（新增文件）；IridescenceLayer.cs 行 39。

---

### P5-8: 其他层参数优化

GlowLayer peak 90→100, mid 0.4→0.5, rate 9.0→1.5（仪式感）。InnerGlowLayer peak 60→78→90, strength 0.20→0.30。TintLayer peak 25→30, low 5→7（提亮 ~20%）。

**变更原因**：各层参数微调以配合整体光学效果统一。

**影响范围**：GlowLayer.cs、InnerGlowLayer.cs、TintLayer.cs。

---

## 7. P6 级别：果冻弹性动效系统

P6 级别的变更涵盖控件级和窗口级果冻弹性动效的引入。

### P6-1: 控件交错入场过冲收敛（PlayMetroStaggerEnter）

Scale 过冲峰值从 1.0 改为 0→1.07（V1.5 过冲）。主动画到 1.07 后追加回弹收敛到 1.0，回弹时长 525ms，缓动 QuarticEase EaseOut，通过 DispatcherTimer 在 durationMs 后触发。

**变更原因**：旧版控件入场无过冲，缺乏液态玻璃的弹性质感。

**影响范围**：AnimationHelper.cs PlayMetroStaggerEnter 行 688-732。

---

### P6-2: 面板入场过冲收敛（PlayPanelEnter）

Scale 从 0.92→1.0 改为 0.92→1.07（V1.5 过冲），时长 360ms。追加 1.07→1.0 果冻弹入，525ms QuarticEase EaseOut。

**变更原因**：面板入场无过冲，与控件交错入场风格不统一。

**影响范围**：AnimationHelper.cs PlayPanelEnter 行 476-509。

---

### P6-3: 窗口入场液态玻璃微回弹（PlayMainWindowEnter）

在窗口缩放 1.15→1.0 完成后，追加液态玻璃微回弹：第一段 1.0→1.03（120ms QuadraticEase EaseOut），第二段 1.03→1.0（280ms QuarticEase EaseOut）。

**变更原因**：窗口入场缩放线性收敛到 1.0 缺乏弹性收尾。

**影响范围**：AnimationHelper.cs PlayMainWindowEnter 行 169-208。

---

### P6-4: 窗口退场弹性蓄力（PlayMainWindowExit）

退场从单调放大改为先微缩蓄力再放大离开：蓄力 1.0→0.97（80ms QuadraticEase EaseOut），放大离开 0.97→1.15（720ms QuadraticEase EaseOut），淡出 1→0（800ms CubicEase EaseOut）。

**变更原因**：单调放大缺乏"蓄力释放"的弹性感。

**影响范围**：AnimationHelper.cs PlayMainWindowExit 行 225-252。

---

### P6-5: iOS Q弹按钮点击反馈（PlayIOSTapSpring）

新增 iOS 风格 Q弹点击反馈，300ms 三阶段关键帧：0-60% 1.0→0.96（CubicEase EaseIn 轻压），60-85% 0.96→1.02（CubicEase EaseOut 首次过冲），85-100% 1.02→1.0（QuadraticEase EaseOut 收敛）。

**变更原因**：旧版按钮点击无弹性反馈，缺乏触感。

**影响范围**：AnimationHelper.cs PlayIOSTapSpring 行 755-783。

---

### P6-6: 缓动曲线库新增 11 个类

新增 AuroraCustomEasing.cs（5 个：AuroraCustomBackEase、AuroraSpringEase、AuroraElasticEaseOut、AuroraElasticEaseIn、AuroraBounceEaseOut）和 UwpEasingCurves.cs（6 个：UwpStandardEase、UwpAccelEase、UwpDecelEase、UwpExpoOutEase、UwpDampedEase、IOSBounceEase）。

**变更原因**：旧版仅使用 WPF 内置缓动，无法精确还原 UWP/iOS 风格曲线。

**影响范围**：AuroraCustomEasing.cs（新增文件）、UwpEasingCurves.cs（新增文件）。

---

## 8. P7 级别：AuroraButton 果冻回弹

P7 级别的变更涵盖 AuroraButton 的果冻弹性交互动效。

### P7-1: hover 离开果冻回弹（V1.5 液态玻璃新增）

新增 `_hoverExitSpringProgress` / `_hoverExitSpringActive` 字段。鼠标离开时触发三阶段果冻回弹（总时长 ~271ms）：0→0.35 1.05→0.96（EaseOutCubic 惯性下冲），0.35→0.65 0.96→1.02（EaseInOutQuad 弹性恢复），0.65→1.0 1.02→1.0（EaseOutQuart 优雅归位）。重新 hover 时立即取消。

**变更原因**：旧版 hover 离开线性回归 1.0，缺乏果冻弹性。

**影响范围**：AuroraButton.cs 行 84-85、535-551、580-588、912-939。

---

### P7-2: iOS Q弹释放反馈

新增 `_iosReleaseSpringProgress` / `_iosReleaseSpringActive` 字段。PreviewMouseUp / KeyUp(Enter/Space) 触发，600ms 内 0→1：0..0.5 0.98→1.02（EaseOutCubic 轻微过冲），0.5..1.0 1.02→1.0（EaseOutQuad 收敛）。幅度 2%。

**变更原因**：按钮释放缺乏 Q弹触感。

**影响范围**：AuroraButton.cs 行 76-77、353-354、383-384、565-573、940-959。

---

### P7-3: 磁吸回弹改进

旧版 UwpDampedEase 三段插值（3.5% 过冲）改为纯 EaseOutCubic `1-(1-t)³`，无过冲、无反向偏移，500ms。

**变更原因**：旧版磁吸 offset 会越过中心到反侧，"先回弹、再晃到另一端"显得刻意。

**影响范围**：AuroraButton.cs 行 801-823。

---

### P7-4: 极光环境色注入

新增 `_ambientColor` / `_ambientStrength` / `_ambientTargetStrength` / `_ambientPhase` 字段和 `EnableAmbientColorInjection` 属性。UpdateAmbientInjection() 每帧采样极光色 + 三态强度推进（Normal 0 / Hover 0.50 / Press 0.80）。

**变更原因**：旧版按钮不响应环境色，与玻璃材质的环境色混合不统一。

**影响范围**：AuroraButton.cs 行 185-191、677。

---

## 9. P8 级别：缺陷修复

P8 级别的变更涵盖本次版本中修复的关键缺陷。

### P8-1: ElevationDialogView 控件大小异常

**问题**：ElevationDialogView 的 RenderTransform 被放在 RootGrid 上，但 OnLoaded 中的动画代码操作的是 this.RenderTransform（Window 级别）。Window 级别没有 RenderTransform，动画静默失败，RootGrid 的 1.10 倍缩放永不被收回，导致所有控件看起来被放大了 10%。

**修复**：将 RenderTransform 连同 ScaleTransform 从 RootGrid 移到 Window 级别。

**原因**：RenderTransform 层级与动画代码操作目标不匹配。

**影响范围**：ElevationDialogView 的所有控件尺寸。

---

### P8-2: SessionRestoreDialogView C# 5 兼容性

**问题**：SessionRestoreDialogView.xaml.cs 中使用了 C# 6 的 ?. 空条件运算符（三处），在 C# 5 编译器下报错 CS1525/CS1003。

**修复**：将 x?.Method() 替换为 if (x != null) x.Method() 写法。

**原因**：项目使用 C# 5.0 语言版本编译，确保 PowerShell 5.1 兼容。

**影响范围**：SessionRestoreDialogView.xaml.cs 编译。

---

### P8-3: 星空 DispatcherTimer 泄漏

**问题**：部分对话框窗口关闭后未调用 StarfieldBg.StopAnimation()，星空的 DispatcherTimer 继续在后台刷新，导致内存泄漏。

**修复**：所有窗口的 Closed 事件统一调用 StarfieldBg.StopAnimation()。

**原因**：缺少 Closed 事件清理逻辑。

**影响范围**：ElevationDialogView、SessionRestoreDialogView、PerformanceUpgradeDialogView 的窗口关闭后行为。

---

## 10. 兼容性保持

V1.4.27.5 虽然动效与材质系统发生了全面升级，但在以下方面保持了与 V1.4.27.1 的完全兼容：

| 兼容项 | 说明 |
|--------|------|
| PowerShell 5.1 兼容 | C# 代码仍使用 C# 5.0 语言版本编译，确保在 PowerShell 5.1 环境中运行 |
| 命令行参数 | 所有命令行参数完全兼容，无新增或移除 |
| syncHash 同步机制 | 跨 Runspace 通信的 syncHash 接口完全兼容 |
| 环境变量接口 | 所有环境变量接口完全兼容 |
| 脚本接口 | PowerShell 脚本引擎无需任何修改 |
| 材质管线 | V5 材质管线参数虽经优化，但 UseV5Pipeline 开关行为不变，UseV5Pipeline=false 时仍可回退到 v4 路径 |
| 材质层接口 | 14 层光学层的接口和注册方式不变，仅参数调整 |
| 控件级动效接口 | 控件级动效方法的签名和调用方式不变，仅内部缓动参数调整 |

---

## 11. 变更清单总览

| 编号 | 级别 | 变更描述 | 变更原因 | 影响范围 |
|------|------|----------|----------|----------|
| P1-1 | P1 | 对话框入场统一 1.15→1.0 | 三个对话框入场参数不一致 | ElevationDialog/SessionRestore/PerformanceUpgrade 入场 |
| P1-2 | P1 | MainFormView 入场 1.1→1.15 | 起始缩放与 Splash 不一致 | MainFormView 入场 |
| P1-3 | P1 | ProModeView 入场 1.1→1.15 | 起始缩放与 Splash 不一致 | ProModeView 入场 |
| P1-4 | P1 | PlayMainWindowEnter 1.1→1.15 | 起始缩放与 Splash 不一致 | AuroraExitCountdown 等窗口入场 |
| P2-1 | P2 | MainFormView 退场 1.0→0.85 改为 1.0→1.15 | 缩小消退与 Splash 放大冲出方向相反 | MainFormView 退场 |
| P2-2 | P2 | PlayMainWindowExit 1.0→0.85 改为 1.0→1.15 | 缩小消退与 Splash 放大冲出方向相反 | ProModeView 退场 |
| P2-3 | P2 | 对话框退场统一 1.0→1.15 | 三个对话框退场参数不一致 | ElevationDialog/SessionRestore/PerformanceUpgrade 退场 |
| P3-1 | P3 | ElevationDialog RenderTransform 移到 Window 级别 | RootGrid 上动画找不到目标 | ElevationDialog 入场/退场 |
| P3-2 | P3 | SessionRestoreDialog 完整动效移植 | 此前无任何窗口级动效 | SessionRestoreDialog 完整生命周期 |
| P3-3 | P3 | PerformanceUpgradeDialog 动效升级 | 缩小式入场和简单淡出与 Splash 不一致 | PerformanceUpgradeDialog 入场/退场 |
| P3-4 | P3 | 星空锁定机制统一 | 部分窗口未锁定星空，未清理定时器 | 所有对话框窗口星空背景 |
| P4-1 | P4 | RtbBlurBackend 硬编码模糊半径修复 | 硬编码 3.0 固定所有风格模糊 | RtbBlurBackend 模糊半径 |
| P4-2 | P4 | RtbBlurBackend 重复节流移除 | 双层节流导致 ~66ms 延迟 | RtbBlurBackend 节流 |
| P4-3 | P4 | RtbBlurBackend 异步化渲染流水线 | 同步渲染阻塞 UI 线程 4ms/帧 | RtbBlurBackend 渲染性能 |
| P4-4 | P4 | ShaderEffectBackend MaxShaderBlurRadius 8→40 | 高模糊预设被截断 | ShaderEffectBackend 模糊截断 |
| P4-5 | P4 | AuroraMaterialPipeline 共享捕获参数 | 硬编码 6.0 无法适配不同风格 | AuroraMaterialPipeline 共享参数 |
| P4-6 | P4 | MaterialStylePreset 校准 | 模糊量翻倍过强，饱和度不足 | AuroraFluentGlass 预设 |
| P5-1 | P5 | BodyLayer 环境色混合 | 纯 TintColor 恒冷蓝不响应环境色 | BodyLayer 颜色混合 |
| P5-2 | P5 | SpecularLayer 双光斑+呼吸漂移 | 单光斑缺乏动态感 | SpecularLayer 光斑和漂移 |
| P5-3 | P5 | FresnelLayer 四方向线性渐变重写 | 单径向渐变无方向性 | FresnelLayer 渐变结构 |
| P5-4 | P5 | BevelLayer 4 段渐变升级 | 2 段渐变过渡生硬 | BevelLayer 渐变段数 |
| P5-5 | P5 | EdgeHighlightLayer 峰值降低 | 峰值过高形成白边 | EdgeHighlightLayer 峰值参数 |
| P5-6 | P5 | Chromatic/Refraction 层级调整 | 在 Body 之下被衰减 | Chromatic/Refraction 层级 |
| P5-7 | P5 | 新增 CausticsLayer 和 IridescenceLayer | 焦散和虹彩光学特征缺失 | CausticsLayer/IridescenceLayer |
| P5-8 | P5 | 其他层参数优化 | 配合整体光学效果统一 | Glow/InnerGlow/TintLayer |
| P6-1 | P6 | 控件交错入场过冲收敛 | 旧版无过冲缺乏弹性 | PlayMetroStaggerEnter |
| P6-2 | P6 | 面板入场过冲收敛 | 面板入场无过冲 | PlayPanelEnter |
| P6-3 | P6 | 窗口入场液态玻璃微回弹 | 线性收敛缺乏弹性收尾 | PlayMainWindowEnter |
| P6-4 | P6 | 窗口退场弹性蓄力 | 单调放大缺乏蓄力感 | PlayMainWindowExit |
| P6-5 | P6 | iOS Q弹按钮点击反馈 | 旧版点击无弹性反馈 | PlayIOSTapSpring |
| P6-6 | P6 | 缓动曲线库新增 11 个类 | WPF 内置缓动无法还原 UWP/iOS | AuroraCustomEasing/UwpEasingCurves |
| P7-1 | P7 | hover 离开果冻回弹 | 线性回归缺乏果冻弹性 | AuroraButton hover 退场 |
| P7-2 | P7 | iOS Q弹释放反馈 | 按钮释放缺乏 Q弹触感 | AuroraButton 释放反馈 |
| P7-3 | P7 | 磁吸回弹改进 | 旧版过冲到反侧显得刻意 | AuroraButton 磁吸回弹 |
| P7-4 | P7 | 极光环境色注入 | 按钮不响应环境色 | AuroraButton 环境色注入 |
| P8-1 | P8 | ElevationDialog 控件大小异常修复 | RenderTransform 层级错误 | ElevationDialog 控件尺寸 |
| P8-2 | P8 | SessionRestoreDialog C# 5 兼容性修复 | 使用了 C# 6 ?. 运算符 | SessionRestoreDialog 编译 |
| P8-3 | P8 | 星空 DispatcherTimer 泄漏修复 | Closed 事件未调用 StopAnimation | 对话框窗口关闭后行为 |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *本工具仅供个人学习使用。请遵守当地法律法规。*
