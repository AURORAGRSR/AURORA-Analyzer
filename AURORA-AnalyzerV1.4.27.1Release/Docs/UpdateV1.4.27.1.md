# AURORA Analyzer V1.4.27.1 更新说明

> **Windows 事件日志导出与智能诊断工具**
>
> 版本：V1.4.27.1Release · 构建时间：2026.07.03 · 作者：AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **警告**：本工具仅用于个人学习使用。请遵守当地法律法规。

---

## 目录

1. [版本概述](#1-版本概述)
2. [P1 级别：V5 高级材质管线](#2-p1-级别v5-高级材质管线)
3. [P2 级别：控件 V5 管线升级](#3-p2-级别控件-v5-管线升级)
4. [P3 级别：玻璃视觉优化](#4-p3-级别玻璃视觉优化)
5. [P4 级别：缺陷修复](#5-p4-级别缺陷修复)
6. [兼容性保持](#6-兼容性保持)
7. [变更清单总览](#7-变更清单总览)

---

## 1. 版本概述

V1.4.27.1 是 AURORA Analyzer 的材质系统打磨版本。本次更新的核心变更是引入 V5 高级材质管线，对 V1.4.27.0 的四层玻璃渲染系统进行了全面分层重构与视觉调校。PowerShell 引擎层保持兼容，所有命令行参数、环境变量接口和 syncHash 同步机制均维持不变。

V1.4.27.0 引入的 AuroraGlassMaterial 共享材质系统通过四层渲染管线（双层投影、真模糊背景、玻璃主体渐变、表层覆盖）实现了毛玻璃效果。然而在实际使用中，该系统暴露出若干视觉缺陷：玻璃内背景拉伸变形、边缘出现硬圆环、悬停时高光只在四角亮起、取色平淡无层次、亮度跳变不顺畅。

V1.4.27.1 通过以下三个核心策略解决了这些问题：

- **V5 材质管线引入**：将玻璃渲染从四层扁平管线重构为九层独立分层架构（L1 后端 / L2 层 / L3 合成器 / L4 控件），每一层独立运算、按序叠加，并通过 IMaterialSurfaceHost 接口与控件解耦。
- **视觉细节深度调校**：针对边缘高光分布、取色层次、悬停过渡曲线等视觉细节进行了反复调校，引入 EaseInOutCubic 缓动曲线实现 3 秒仪式感过渡。
- **时序竞争缺陷修复**：修复了窗口切换链中背景源被错误清空导致主界面玻璃模糊缺失的隐蔽缺陷。

本次更新是一个"视觉打磨、底层兼容"的版本。所有面向用户的命令行接口、环境变量和跨 Runspace 通信协议均保持完全兼容，确保现有脚本和工作流无需修改即可运行。

---

## 2. P1 级别：V5 高级材质管线

P1 级别的变更是 V5 材质管线的核心架构引入。这是对 V1.4.27.0 四层渲染管线的根本性分层重构。

### P1-1: 九层独立渲染架构

V1.4.27.0 的 AuroraGlassMaterial 将投影、模糊、渐变、噪点四层渲染逻辑耦合在单一类中，层间参数硬编码，难以独立调整。V1.4.27.1 将其拆分为九个独立的 IMaterialLayer 实现，按 Order 属性排序依次渲染：

| 层级 | Order | 职责 |
|------|-------|------|
| ShadowLayer | 10 | 双层投影：外层柔光扩散 + 内层锐利边界 |
| BlurLayer | 20 | 真模糊背景：RenderTargetBitmap 捕获 + GaussianBlur |
| TintLayer | 50 | 环境色调染色：垂直方向双点渐变取色 |
| BodyLayer | 60 | 玻璃主体：圆角矩形填充 + 柔和边框 |
| NoiseLayer | 70 | 磨砂噪点：等亮度图集 + 交叉淡入淡出 |
| FresnelLayer | 80 | 菲涅尔边缘反射：55% 宽过渡区自然边缘 |
| BevelLayer | 100 | 斜角厚度感：上亮下暗模拟立体边缘 |
| ScanlineLayer | 120 | 扫描线纹理（仅 Holographic 风格） |
| GlowLayer | 130 | 悬停外发光：4 边均匀边缘高光 + 仪式感过渡 |

每一层通过 IsEnabled 接口独立判断是否参与渲染，通过 Update 接口独立更新内部状态，通过 Render 接口独立绘制。层间无耦合，参数全部通过 MaterialStylePreset 预设驱动。

**变更原因**：V1.4.27.0 的四层耦合架构难以独立调校各层参数，且无法支持 Mica/Holographic 等差异化材质风格。九层独立架构使每一层的参数可独立调整，并通过预设系统支持运行时切换材质风格。

**影响范围**：所有使用 V5 管线的控件的玻璃渲染均通过 AuroraMaterialComposer 调度九层渲染。

---

### P1-2: IMaterialSurfaceHost 接口与 AuroraMaterialComposer

V1.4.27.1 引入了 IMaterialSurfaceHost 接口，提供 CornerRadius 和 Depth 两个材质表面属性。控件实现该接口后即可接入 V5 管线。

AuroraMaterialComposer 是每个 V5 控件持有的材质合成器实例，负责：
- 在 Loaded/Unloaded 时向 AuroraMaterialPipeline 注册/注销
- 在 OnRender 时调用 `_composer.Render(dc)` 委托九层渲染
- 转发鼠标位置、尺寸变更等事件
- 提供 UseV5Pipeline 开关，true 走 V5 管线，false 回退 V4 渲染

**变更原因**：V1.4.27.0 的 AuroraGlassMaterial 是全局共享单例，控件无法独立配置材质风格。Composer 模式让每个控件持有独立的合成器实例，支持独立的材质预设和状态管理。

**影响范围**：所有升级到 V5 管线的控件均使用 AuroraMaterialComposer。

---

### P1-3: 四种材质风格预设

V1.4.27.1 通过 MaterialStylePreset 定义了四种差异化材质风格，运行时可通过 MaterialKind 枚举切换：

| 风格 | 特征 | 适用场景 |
|------|------|----------|
| AuroraFluentGlass | 标准毛玻璃，全九层启用 | 默认风格 |
| LiquidGlass | 液态玻璃，更强的菲涅尔和高光 | 高亮交互元素 |
| Mica | Mica 风格，跳过噪点和模糊层，启用 DWM Acrylic 后端 | 窗口级背景 |
| Holographic | 全息风格，启用扫描线层 | 科幻主题 |

每种风格通过独立的参数预设控制各层的模糊半径、透明度、动画速度、发光强度等参数。

**变更原因**：V1.4.27.0 仅支持单一玻璃风格，无法满足不同 UI 元素的差异化视觉需求。预设系统让同一套渲染管线支持多种材质表达。

**影响范围**：所有 V5 控件可通过 MaterialKind 属性切换材质风格。

---

### P1-4: 五级模糊后端回退链

V1.4.27.1 实现了五级模糊后端回退链，根据系统能力自动选择最优后端：

| 优先级 | 后端 | 说明 |
|--------|------|------|
| 1 | DwmAcrylicBackend | Win11 DWM Acrylic/Mica（需显式启用窗口背景） |
| 2 | ShaderEffectBackend | HLSL 着色器模糊（CPU 软件光栅化） |
| 3 | RtbBlurBackend | RenderTargetBitmap + BlurEffect（已实现） |
| 4 | D3D9ExBackend | Direct3D 9Ex 硬件模糊（预留） |
| 5 | SolidFallbackBackend | 纯色回退（预留） |

远程会话和虚拟机环境强制禁用 GPU 后端，回退到 RTB 软件模糊。

**变更原因**：V1.4.27.0 仅使用 RTB 模糊后端，在 Win11 系统上无法利用 DWM 原生 Acrylic 能力。多级回退链确保在各种环境下都能获得最佳可用模糊效果。

**影响范围**：所有 V5 控件的模糊背景渲染。

---

## 3. P2 级别：控件 V5 管线升级

P2 级别的变更涵盖 PRO 模式中各控件从 V4 渲染升级到 V5 管线的迁移工作。所有升级均遵循统一的 V5 迁移模式：实现 IMaterialSurfaceHost 接口、使用 AuroraMaterialComposer、注册/注销到 AuroraMaterialPipeline、转发鼠标事件、提供 V4 回退。

### P2-1: AuroraConsoleBox V5 升级

AuroraConsoleBox 实现了 IMaterialSurfaceHost 接口，OnRender 中的旧四步玻璃绘制替换为 `_composer.Render(dc)` 委托。Loaded/Unloaded 时注册/注销到 Pipeline，MouseMove 转发 SetMousePosition，OnRenderSizeChanged 通知 OnSizeChanged。UseV5Pipeline=false 时回退到 AuroraGlassMaterial 旧路径。

**用途**：PRO 模式控制台的毛玻璃背景。

---

### P2-2: AuroraTaskHUD V5 升级

AuroraTaskHUD 按与 AuroraConsoleBox 相同的模式升级至 V5 管线。

**用途**：PRO 模式任务进度 HUD 的毛玻璃背景。

---

### P2-3: AuroraPrivilegeIndicator V5 升级

AuroraPrivilegeIndicator 按相同模式升级至 V5 管线。

**用途**：PRO 模式权限状态指示器的毛玻璃背景。

---

### P2-4: AuroraProgressBar V5 升级

AuroraProgressBar 的 OnRender 开头插入 `_composer.Render(dc)` 替代旧的五步手绘（投影 + 轨道 + 噪点 + 高光 + 内阴影），保留进度填充、扫光、前缘光点、粒子等 ProgressBar 特有逻辑。

**用途**：PRO 模式进度条的毛玻璃背景。

---

## 4. P3 级别：玻璃视觉优化

P3 级别的变更聚焦于玻璃材质的视觉细节调校。这些变更不影响功能行为，但显著提升了视觉质感和交互仪式感。

### P3-1: 边缘高光"四角亮"修复

V1.4.27.0 的 GlowLayer 使用单一 RadialGradientBrush（RadiusX=RadiusY=0.62），等值线是圆形。在圆角矩形内，圆形等值线只在四个角附近接近边缘，导致四角比四边中点亮。

V1.4.27.1 将 GlowLayer 改为 4 个 LinearGradientBrush，每个负责一条边向中心衰减。等值线变为"距离最近边缘的距离"，沿圆角矩形边缘均匀分布。四角被相邻 2 个 brush 叠加，稍亮但自然（物理正确的角点反射）。

**原因**：圆形径向渐变在矩形控件内只在四角接近边缘，导致高光分布不均。改为四边线性渐变让等值线沿边缘均匀分布。

---

### P3-2: 玻璃取色垂直渐变

V1.4.27.0 的 AuroraMaterialComposer 只采样控件顶部 Y 位置的极光色，整块玻璃使用同一 AmbientColor，高控件平淡无层次。

V1.4.27.1 在 Update 中采样顶部、中心、底部三个 Y 位置，TintLayer 从 RadialGradientBrush 改为 LinearGradientBrush，4 段 GradientStop 实现顶边淡出 → 上中 peak(topColor) → 下中 peak(bottomColor) → 底边淡出，模拟极光从上到下的色相变化。

**原因**：单一采样点导致高控件取色平淡。三点采样 + 垂直线性渐变模拟真实极光的色相层次。

---

### P3-3: 悬停过渡仪式感

V1.4.27.0 的 GlowLayer 使用纯指数平滑（rate=9.0，约 0.5s 完成），过渡过快缺乏仪式感。

V1.4.27.1 引入 _glowProgress 进度变量（0..1）+ EaseInOutCubic 曲线映射。rate 降至 1.5（约 3s 完成 99%）。曲线两端柔和减速：开头几乎察觉不到（t=0.2 时仅 3.2% 强度），中段平稳推进，末段优雅收敛。

**原因**：纯 ease-out 曲线开头最快、末尾慢，缺乏从容感。EaseInOutCubic 两端减速，3 秒过渡更具仪式感。

---

### P3-4: 移除 SpecularLayer（鼠标跟随高光）

V1.4.27.0 的 SpecularLayer 实现鼠标位置的白色高光跟随，但在实际使用中视觉效果不明显，且增加了每帧的 Brush 属性更新开销。

V1.4.27.1 彻底移除 SpecularLayer（含文件、Composer 注册、HasActiveAnimation 分支），保留 SpecularStrength 预设字段避免破坏结构兼容。hover 反馈完全由 GlowLayer 承担。

**原因**：鼠标跟随高光实际视觉价值低，移除后视觉表达更纯粹，减少不必要的渲染开销。

---

### P3-5: NoiseLayer 亮度跳变修复

V1.4.27.0 的 NoiseLayer 使用 8 帧图集，亮度递增（128→177），循环时产生每秒一次的亮度骤降。帧切换为整数硬切，导致每 125ms 一次的突兀跳变。

V1.4.27.1 将图集改为每帧独立随机等亮度生成（平均亮度固定 128），并实现交叉淡入淡出：连续帧位置 + blend 因子 + 双 brush 叠加。

**原因**：亮度递增图集 + 硬切帧切换导致周期性亮度跳变。等亮度图集 + 交叉淡入淡出消除跳变。

---

### P3-6: BodyLayer 与 FresnelLayer 边缘柔和化

V1.4.27.0 的 BodyLayer 使用 1px 白色边框（alpha=80），FresnelLayer 使用 15% 窄过渡区（0.85→0.95→1.0）和 peak alpha=216，导致玻璃边缘出现明显的硬圆环。

V1.4.27.1 将 BodyLayer 边框 alpha 降至 35、颜色改为 tint+40；FresnelLayer 半径 0.5→0.62，过渡区拓宽至 55%（0.45→0.72→0.9→1.0），peak alpha 降至 130。

**原因**：硬白边 + 窄过渡区导致可见硬圆环。降低边框 alpha 和拓宽过渡区让边缘自然融入。

---

### P3-7: AuroraStarfield 加权取色

V1.4.27.0 的 SampleAuroraColorAt 使用离散层选择（bestInfluence 比较），层切换瞬间颜色跳变。

V1.4.27.1 改为全层加权 RGB 累加归一化：每层按 influence（raw²）加权，breath 调制，最终归一化输出。层间过渡平滑无跳变。

**原因**：离散层选择导致切换瞬间颜色突变。加权混合实现层间平滑过渡。

---

## 5. P4 级别：缺陷修复

P4 级别的变更涵盖本次版本中修复的关键缺陷。

### P4-1: 窗口切换时序竞争修复

V1.4.27.0 的 AuroraStarfield.Unloaded 无条件调用 ClearBackgroundSource()，在启动链 splash→权限窗口→mainformview→pro 中，旧窗口的 Unloaded 可能在新窗口 SetBackgroundSource 之后触发，错误清空了新窗口已注册的背景源。导致 mainformview 的玻璃无法获得模糊采样，用户看到透明无模糊的玻璃。

V1.4.27.1 的 ClearBackgroundSource 增加可选 source 参数，只有当前注册的背景源是自己时才清空。AuroraStarfield.Unloaded 传入 this。

**原因**：无条件清空导致旧窗口 Unloaded 误清新窗口背景源。身份校验确保只有自己注册的才能清空。

**影响范围**：启动链中所有窗口的背景源交接。

---

### P4-2: DwmAcrylicBackend 误选修复

V1.4.27.0 的 DwmAcrylicBackend.IsAvailable 只探测平台能力（Win11 + DWM 可用），未检查是否已调用 ApplyWindowBackdrop 启用 Mica。导致未启用 Mica 的窗口（如 MainFormView）选中 DwmAcrylic 后端，CaptureAndBlur 返回 null，BlurLayer 跳过渲染。

V1.4.27.1 增加 _backdropApplied 标志，IsAvailable 要求该标志为 true。未启用 Mica 时回退到 ShaderEffect 或 RTB 后端。

**原因**：DwmAcrylicBackend 是窗口级后端，需先启用 Mica 才能提供模糊。未启用时不应被选中。

**影响范围**：所有未显式启用 Mica 的窗口的模糊后端选择。

---

### P4-3: 动画速度参数失效修复

V1.4.27.0 的 GlowLayer 在 DeltaMs<=0 时使用固定 smoothFactor=0.15（相当于 rate=9.0），完全绕过 rate 参数。同时 AuroraMaterialComposer 首帧 DeltaMs 为几百毫秒（_lastTimeMs=0），导致 smoothFactor≈1.0，_glowProgress 瞬间跳到 1.0，跳过整个过渡动画。

V1.4.27.1 的 fallback 也按 rate 计算（假设 60fps），并将 DeltaMs 钳制到 100ms 上限。

**原因**：固定 fallback 值绕过 rate + 首帧 DeltaMs 瞬变导致动画被跳过。统一 fallback 逻辑 + DeltaMs 钳制确保参数生效。

**影响范围**：所有使用 DeltaMs 平滑的层的动画过渡。

---

### P4-4: BlurLayer 背景拉伸修复

V1.4.27.0 的 BlurLayer 在 BackgroundSourceRect 为空或 TransformToVisual 失败时，将整张 starfield sample 以 Stretch=Fill 拉伸到 surface 矩形，导致严重的宽高比变形。

V1.4.27.1 在无有效 BackgroundSourceRect 时 return 不绘制，并在 AuroraMaterialComposer 中添加 TransformToVisual 失败的 PointToScreen + PointFromScreen fallback。

**原因**：退化路径拉伸整图导致变形。返回不绘制 + fallback 坐标计算确保正确裁剪。

**影响范围**：所有 V5 控件的模糊背景渲染。

---

### P4-5: PRO 模式导出文件夹路径修复

V1.4.27.0 的 ShowUserLogs 使用 MyDocuments\AURORA\UserLogs，与 PowerShell 脚本的 $PSScriptRoot\..\..\UserLogs 路径不一致，导致点击"是"后无法正确打开导出文件夹。

V1.4.27.1 实现三级路径解析：主路径（ScriptsRoot 向上一级 + UserLogs）→ 兜底 1（exe 目录上溯 6 级查找）→ 兜底 2（MyDocuments\AURORA\UserLogs）。

**原因**：C# 与 PowerShell 路径不一致。三级解析确保找到实际导出目录。

**影响范围**：PRO 模式完成对话框的"打开导出文件夹"功能。

---

## 6. 兼容性保持

V1.4.27.1 虽然材质系统发生了重大重构，但在以下方面保持了与 V1.4.27.0 的完全兼容：

| 兼容项 | 说明 |
|--------|------|
| PowerShell 5.1 兼容 | C# 代码仍使用 C# 5.0 语言版本，确保在 PowerShell 5.1 环境中运行 |
| 命令行参数 | 所有命令行参数完全兼容，无新增或移除 |
| syncHash 同步机制 | 跨 Runspace 通信的 syncHash 接口完全兼容 |
| 环境变量接口 | 所有环境变量接口完全兼容 |
| 脚本接口 | PowerShell 脚本引擎无需任何修改 |
| UseV5Pipeline 开关 | false 时回退到 V4 AuroraGlassMaterial，确保向后兼容 |

---

## 7. 变更清单总览

| 编号 | 级别 | 变更描述 | 变更原因 | 影响范围 |
|------|------|----------|----------|----------|
| P1-1 | P1 | V5 九层独立渲染架构 | V4 四层耦合难以独立调校 | 所有 V5 控件的玻璃渲染 |
| P1-2 | P1 | IMaterialSurfaceHost + AuroraMaterialComposer | V4 全局单例无法独立配置 | 所有 V5 控件 |
| P1-3 | P1 | 四种材质风格预设 | 单一风格无法满足差异化需求 | 所有 V5 控件 |
| P1-4 | P1 | 五级模糊后端回退链 | RTB 后端无法利用 DWM Acrylic | 所有 V5 控件的模糊渲染 |
| P2-1 | P2 | AuroraConsoleBox V5 升级 | 接入 V5 管线 | PRO 模式控制台 |
| P2-2 | P2 | AuroraTaskHUD V5 升级 | 接入 V5 管线 | PRO 模式任务 HUD |
| P2-3 | P2 | AuroraPrivilegeIndicator V5 升级 | 接入 V5 管线 | PRO 模式权限指示器 |
| P2-4 | P2 | AuroraProgressBar V5 升级 | 接入 V5 管线 | PRO 模式进度条 |
| P3-1 | P3 | 边缘高光"四角亮"修复 | 圆形径向渐变只在四角接近边缘 | GlowLayer 渲染 |
| P3-2 | P3 | 玻璃取色垂直渐变 | 单一采样点导致平淡无层次 | TintLayer 渲染 |
| P3-3 | P3 | 悬停过渡仪式感 | 纯指数平滑过快缺乏仪式感 | GlowLayer 动画 |
| P3-4 | P3 | 移除 SpecularLayer | 鼠标跟随高光无实际视觉价值 | SpecularLayer 移除 |
| P3-5 | P3 | NoiseLayer 亮度跳变修复 | 亮度递增图集 + 硬切导致跳变 | NoiseLayer 渲染 |
| P3-6 | P3 | BodyLayer + FresnelLayer 边缘柔和化 | 硬白边 + 窄过渡导致硬圆环 | BodyLayer + FresnelLayer |
| P3-7 | P3 | AuroraStarfield 加权取色 | 离散层选择导致颜色跳变 | AuroraStarfield 取色 |
| P4-1 | P4 | 窗口切换时序竞争修复 | 无条件清空导致新窗口背景源丢失 | 启动链背景源交接 |
| P4-2 | P4 | DwmAcrylicBackend 误选修复 | 未启用 Mica 时不应选中该后端 | 模糊后端选择 |
| P4-3 | P4 | 动画速度参数失效修复 | fallback 固定值 + 首帧 DeltaMs 瞬变 | 所有 DeltaMs 平滑动画 |
| P4-4 | P4 | BlurLayer 背景拉伸修复 | 退化路径 Stretch=Fill 导致变形 | 模糊背景渲染 |
| P4-5 | P4 | 导出文件夹路径修复 | C# 与 PowerShell 路径不一致 | PRO 模式导出功能 |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *本工具仅供个人学习使用。请遵守当地法律法规。*
