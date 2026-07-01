# AURORA Analyzer V1.4.27.0 Release Notes

> **Windows Event Log Export and Intelligent Diagnostic Tool**
>
> Version: V1.4.27.0Release · Build Date: 2026.06.30 · Author: AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ **Warning**: This tool is intended for personal educational use only. Please comply with local laws and regulations.

---

## Table of Contents

1. [Version Overview](#1-version-overview)
2. [P0 Level: Architecture Layer Changes](#2-p0-level-architecture-layer-changes)
3. [P1 Level: Core System Changes](#3-p1-level-core-system-changes)
4. [P2 Level: New Components](#4-p2-level-new-components)
5. [P3 Level: Optimizations and Fixes](#5-p3-level-optimizations-and-fixes)
6. [Compatibility Preservation](#6-compatibility-preservation)
7. [Change Summary Table](#7-change-summary-table)

---

## 1. Version Overview

V1.4.27.0 is an architecture upgrade release for AURORA Analyzer. The core change in this update is the complete migration of the entire UI layer from Windows Forms (WinForm GDI+) to Windows Presentation Foundation (WPF), along with the introduction of the Model-View-ViewModel (MVVM) layered architecture. The PowerShell engine layer remains compatible, and all command-line parameters, environment variable interfaces, and the syncHash synchronization mechanism are preserved unchanged.

In V1.3.26.7Release, the UI layer was built by dynamically creating WinForm controls through PowerShell scripts, relying on GDI+ for software rendering. This approach met basic requirements in the early stages, but as functional complexity grew, its limitations became increasingly apparent: GDI+ could not achieve modern frosted glass effects, complex animations experienced noticeable frame rate fluctuations, and UI logic was intermixed with business logic in PowerShell scripts, making maintenance difficult.

V1.4.27.0 thoroughly resolves these issues through the following three core strategies:

- **UI Framework Migration**: All windows and controls are migrated from System.Windows.Forms to System.Windows.Controls, leveraging WPF's GPU-accelerated rendering pipeline (DirectX backend) to achieve high-performance visual effects.
- **MVVM Architecture Introduction**: The UI presentation layer (XAML windows), data binding layer (ViewModel), and infrastructure layer (Service) are clearly separated, eliminating the intermixing of UI code and business logic in PowerShell scripts.
- **C# Compiled Control Library**: A C# 5.0 compiled AURORA.Wpf.dll control library replaces PowerShell's New-Object dynamic control creation, utilizing compile-time type checking and higher execution efficiency.

This update is a "bottom-layer refactoring, top-layer compatible" release. All user-facing command-line interfaces, environment variables, and cross-Runspace communication protocols remain fully compatible, ensuring that existing scripts and workflows can run without modification.

---

## 2. P0 Level: Architecture Layer Changes

P0-level changes define the technical foundation of the entire system. These changes are not simple feature enhancements, but fundamental reshaping of the underlying system architecture.

### P0-1: UI Framework Migration from WinForm to WPF

In V1.3.26.7Release and earlier versions, the entire UI layer was built on System.Windows.Forms. All windows, buttons, and controls were dynamically created through the `New-Object` command in PowerShell scripts, with rendering relying on the GDI+ software rasterization pipeline. GDI+ is a mature but dated 2D graphics API whose core limitation is the complete absence of GPU acceleration — all drawing operations (including anti-aliasing, gradient fills, and transparency blending) are performed on the CPU, and each draw operation involves expensive GDI handle allocation and deallocation.

V1.4.27.0 migrates the entire UI layer to System.Windows.Controls (WPF). WPF uses DirectX as its rendering backend, with all visual element drawing hardware-accelerated by the GPU. This means that complex transparency blending, drop shadow effects, blur processing, and other operations can now leverage the GPU's parallel computing capability, delivering an order-of-magnitude improvement in rendering performance compared to GDI+.

WPF also brings declarative UI description capabilities. The XAML markup language allows structured description of UI layouts, replacing the verbose, imperative PowerShell control creation code of the WinForm version. The data binding mechanism eliminates the need for manual synchronization between UI state and data state, with property change notifications (INotifyPropertyChanged) automatically driving UI updates, significantly reducing boilerplate code.

| Dimension | V1.3.26.7 (WinForm) | V1.4.27.0 (WPF) |
|-----------|---------------------|------------------|
| Rendering Backend | GDI+ Software Rasterization | DirectX GPU Acceleration |
| UI Description Style | Imperative PowerShell Scripts | Declarative XAML Markup |
| Data Synchronization | Manual Control Property Updates | Automatic Data Binding Synchronization |
| Animation Capability | Timer-Driven Frame-by-Frame Updates | Storyboard Hardware Acceleration |
| Visual Effects | Limited GDI+ Drawing | Full Effects: Drop Shadow, Blur, Transparency, etc. |

**Reason for Change**: WinForm GDI+ has limited rendering performance and cannot achieve modern frosted glass effects or complex real-time animations. WPF provides GPU-accelerated rendering, declarative UI, data binding, and other core capabilities of modern UI frameworks, laying the foundation for future feature evolution.

**Impact Scope**: All windows, controls, and animation systems are replaced. Original WinForm code is completely removed with no backward compatibility layer.

---

### P0-2: MVVM Architecture Introduction

The code organization in V1.3.26.7Release was essentially "procedure-oriented." PowerShell scripts simultaneously contained UI control creation code, event handling logic, business rule judgments, and data processing code. Taking the main window as an example, a single PowerShell script file exceeding 5,000 lines simultaneously handled window layout, button click responses, PRO mode flow control, log output formatting, and multiple other responsibilities. This intermixed organization meant that any modification could produce unintended side effects and made unit testing nearly impossible.

V1.4.27.0 introduces the Model-View-ViewModel (MVVM) layered architecture, dividing the system into three clearly defined responsibility layers:

- **View Layer (XAML Windows)**: Pure UI description, containing window layout, control declarations, styles, and animation definitions. The View layer contains no business logic and communicates with the ViewModel solely through data binding. All XAML files maintain a declarative style with no business code in code-behind.

- **ViewModel Layer (Data Binding and Business Logic)**: Implemented as C# classes, containing UI state (properties), user interaction commands (ICommand), and UI-related business logic. The ViewModel notifies the View of updates through the INotifyPropertyChanged interface and receives command invocations from the View through the ICommand interface. The ViewModel does not directly reference any View controls, achieving complete view-independence.

- **Service Layer (Infrastructure Services)**: Provides cross-view common service capabilities, including logging services, language services, performance detection services, integrity verification services, privilege elevation services, watchdog services, and more. The Service layer is provided to ViewModels through dependency injection, ensuring that service instance lifecycles are uniformly managed by the framework.

The core advantage of this layered architecture lies in testability and maintainability. ViewModels can be independently instantiated and tested without launching a full WPF window. The service layer can be replaced with mocks for isolated testing. When UI layout needs modification, View layer changes do not affect business logic; when business rules need adjustment, ViewModel layer changes do not affect UI rendering.

**Reason for Change**: The original WinForm version lacked clear layering, with UI logic and business logic intermixed in PowerShell scripts. A single 5,000-line script file often simultaneously contained window layout, event handling, flow control, and other responsibilities, making it difficult to maintain, test, and extend.

**Impact Scope**: All views and business logic are reorganized according to the MVVM pattern. Original UI code in PowerShell scripts is completely removed, and business logic is migrated to C# ViewModel and Service layers.

---

### P0-3: PowerShell Integration Upgrade

V1.3.26.7Release used a single PowerShell Runspace to communicate with the GUI. Scripts sent output to the GUI thread through the Pipeline, and the GUI thread sent commands to the Runspace through the Invoke method. This single-Runspace architecture meant that only one script task could execute at a time, making multiple parallel operations in PRO mode (such as running diagnostic and repair scripts simultaneously) impossible.

V1.4.27.0 upgrades the PowerShell integration to a RunspacePool parallel execution model. RunspacePool maintains a configurable number of Runspace instances in a pool, with each Runspace able to independently execute scripts without blocking each other. When multiple tasks need to run in parallel, RunspacePool allocates idle Runspaces from the pool, and after task completion, recycles the Runspaces for subsequent use.

Cross-Runspace state sharing is implemented through a static Hashtable.Synchronized syncHash. The syncHash is a thread-safe hash table that all Runspaces and the GUI thread can safely read from and write to. This maintains the same communication semantics as V1.3.26.7Release — scripts report progress, output logs, and status information to the GUI through syncHash, and the GUI passes user instructions and parameters to scripts through syncHash.

C# static fields provide another method of cross-Runspace state sharing. Static fields defined in C# code exist at the AppDomain level and can be accessed by all Runspaces without locks. This approach is suitable for pure C# state that does not need to interact with PowerShell scripts, such as global configuration and performance detection results.

**Reason for Change**: The original single Runspace could not process multiple script tasks in parallel, limiting PRO mode's concurrency capability. RunspacePool enables multi-task parallel execution by maintaining a pool of Runspace instances, while maintaining full compatibility with the original communication protocol through syncHash and C# static fields.

**Impact Scope**: PRO mode script execution, log output, and progress reporting are all implemented through RunspacePool. Original script code requires no modification because the syncHash read/write interface remains unchanged.

---

### P0-4: C# 5.0 Compiled Control Library Replaces PowerShell Dynamic Control Creation

In V1.3.26.7Release, all UI controls were dynamically created at runtime through PowerShell's `New-Object` command. For example, creating 17 buttons involved 17 `New-Object System.Windows.Forms.Button` calls, each requiring the PowerShell interpreter to look up types, parse constructor parameters, and execute object initialization. During window loading, hundreds of such operations caused noticeable startup delays.

V1.4.27.0 compiles all custom controls into a C# 5.0 AURORA.Wpf.dll assembly. C# code undergoes type checking at compile time, eliminating an entire class of runtime errors — type mismatches, method signature errors, property name typos, and similar issues are caught at the compilation stage. The execution efficiency of compiled IL code is far higher than interpreted PowerShell script execution, especially in scenarios involving substantial mathematical computation (such as animation interpolation and color operations).

Custom control inventory includes:

| Control Name | Description |
|--------------|-------------|
| AuroraButton | Button control with 17 animation effects, replacing TechButton |
| AuroraStarfield | 60fps starfield background animation control |
| AuroraConsoleBox | Console log control with integrated frosted glass background |
| AuroraFrostedGlassBorder | Frosted glass border container control |
| AuroraTaskHUD | Task progress visualization HUD control |
| AuroraTextBlock | Text control supporting text transition animations |
| AuroraProgressBar | Progress bar control with full glass material scheme |
| AuroraCustomEasing | Spring-Damper physics model easing curve |

**Reason for Change**: C# compiled code has significantly higher execution efficiency than interpreted PowerShell script execution. Compile-time type checking eliminates an entire class of runtime errors — type mismatches, method signature errors, property name typos, and similar issues are caught at the compilation stage. C#'s DrawingContext rendering API provides a more efficient GPU-accelerated rendering path compared to GDI+'s Graphics object.

**Impact Scope**: All UI controls are provided through AURORA.Wpf.dll. Original PowerShell `New-Object` control creation code is completely removed.

---

## 3. P1 Level: Core System Changes

P1-level changes focus on the refactoring of the UI rendering and interaction systems. These changes are built upon the P0 WPF architectural foundation and comprehensively upgrade the original visual effects and interaction experience.

### P1-1: Frosted Glass Material System (AuroraGlassMaterial)

The WinForm version in V1.3.26.7Release could not achieve true blurred background effects. GDI+ has no built-in blur filter; implementing blur effects would require manual convolution computation on the CPU, which is completely impractical in real-time rendering scenarios. Consequently, all original window backgrounds were solid colors or simple gradients, unable to present the frosted glass visual effect common in modern UIs.

V1.4.27.0 introduces a brand-new AuroraGlassMaterial shared glass material rendering system. This system employs a four-layer rendering pipeline to achieve realistic frosted glass effects:

- **Layer 1 (Dual Drop Shadows)**: DropShadowEffect is applied both inside and outside the control. The inner shadow produces a sense of glass thickness, while the outer shadow produces a floating effect. The offset, blur radius, and opacity of both shadows are independently configurable, making the glass panel appear truly "suspended" above the background.

- **Layer 2 (True Blurred Background)**: Content behind the control is captured via RenderTargetBitmap, and WPF's BlurEffect is then applied for Gaussian blur processing. This blur is genuine image blur — it samples the content below the control in real time and performs weighted averaging on each pixel's neighborhood, producing the visual effect of looking through frosted glass at the background. The blur radius ranges from 15 to 25 pixels, automatically adjusted through the performance tier system.

- **Layer 3 (Glass Body Gradient)**: A semi-transparent linear gradient brush is overlaid on top of the blurred background. The gradient transitions from slightly brighter semi-transparent white at the top-left to slightly darker semi-transparent gray at the bottom-right, simulating the light transmittance variation of glass material at different angles.

- **Layer 4 (Surface Overlay)**: An extremely faint micro-noise texture (Opacity 0.03-0.05) is overlaid on the topmost layer, simulating the microscopic irregularities of real glass surfaces and adding material texture and realism.

This material system is designed as a shared instance. All controls using frosted glass effects (AuroraFrostedGlassBorder, AuroraConsoleBox, AuroraTaskHUD, AuroraButton's glass background) share the same AuroraGlassMaterial instance, ensuring consistent rendering parameters and avoiding redundant computation.

**Reason for Change**: The original WinForm could not achieve true blurred background effects because GDI+ lacks a built-in GPU-accelerated blur filter. The new system achieves true blur by capturing content behind controls via RenderTargetBitmap and applying BlurEffect, and creates a realistic glass material feel through the four-layer rendering pipeline.

**Impact Scope**: The glass backgrounds of AuroraFrostedGlassBorder, AuroraConsoleBox, AuroraTaskHUD, and AuroraButton all use this shared material system.

---

### P1-2: Starfield Background Refactoring (AuroraStarfield)

The starfield background in V1.3.26.7Release was implemented through a WinForm Panel subclass. In the Panel's Paint event, each star point was drawn using GDI+'s Graphics object — calling FillEllipse individually for each circle, with each star point requiring an independent GDI drawing call. In a scenario with 500 star points, each frame required 500 GDI calls, producing significant performance overhead at high frame rates. Animation was driven by DispatcherTimer, triggering repaints at 30fps. However, DispatcherTimer shares the thread with the UI message loop; when the UI thread is busy (such as processing large volumes of log output), the Timer's Tick event is delayed, causing unstable frame rates.

V1.4.27.0 refactors AuroraStarfield as a WPF FrameworkElement subclass. Rendering uses the DrawingContext API, batch-drawing star points through DrawingVisual and DrawingGroup. All star points are drawn in a single DrawingContext call, avoiding the overhead of individual GDI calls. Star points use pre-computed position and size caches, reducing per-frame computation.

Animation is now driven by the CompositionTarget.Rendering event at 60fps (synchronized with the display's vertical sync). CompositionTarget.Rendering fires before each frame in WPF's rendering pipeline, synchronized with the vsync signal, ensuring that animation frame rates remain consistently stable and do not fluctuate due to UI thread load.

Frame rate normalization is a critical detail in the WPF migration. The original WinForm constants (such as star point movement speed and flicker frequency) were designed for 30fps. In WPF's 60fps environment, using these constants directly would cause animations to run at double speed. AuroraStarfield introduces an animationTimeScale factor (0.5), normalizing 60fps frame time to the 30fps baseline, ensuring all animation behavior remains consistent with the original version.

**Reason for Change**: The original DispatcherTimer was delayed under UI thread overload, causing unstable frame rates. GDI+ point-by-point drawing of 500 star points required 500 independent calls per frame, incurring significant performance overhead. CompositionTarget.Rendering aligned with vsync provides stable frame rates, and DrawingContext batch drawing of star points provides higher performance.

**Impact Scope**: The starfield background in all windows uses the new AuroraStarfield control. Visual effects remain consistent with the original version, but with more stable frame rates.

---

### P1-3: Button System Refactoring (AuroraButton)

The button system in V1.3.26.7Release was based on TechButton — a custom control derived from WinForm Button. TechButton overrode the OnPaint method, using GDI+'s Graphics object to draw the button's gradient background, borders, text, and icons. The 17 animation effects (such as hover glow, press scale, release bounce, etc.) were implemented through a Timer-driven state machine, with each animation phase requiring manual interpolation calculation, state updates, and repaint triggering.

V1.4.27.0 refactors the button system as AuroraButton — a custom control derived from WPF Button. Rendering uses WPF's DrawingContext API, drawing the button's various visual layers through DrawingVisual. WPF's DrawingContext provides richer drawing primitives and a more efficient GPU-accelerated path compared to GDI+'s Graphics object.

The preserved 17 animation effects are implemented in WPF through Storyboards. Each animation effect is defined as a Storyboard resource, launched under the corresponding trigger (such as IsMouseOver, IsPressed, IsEnabled changes). Storyboards are driven by WPF's animation engine, running on the compositor thread, unaffected by UI thread load, ensuring animations are always smooth.

V1.4.27.0 introduces the following new button features:

- **Aurora Ambient Color Injection**: AuroraButton automatically detects the AuroraGlassMaterial ambient color of its parent window and matches the button's border and glow effects to the ambient color, achieving visual style consistency.

- **iOS-Style Bounce Release Feedback**: When the user quickly clicks and releases the button, the button executes an overshoot-bounce animation — the button first shrinks to 95%, then bounces to 102%, and finally settles at 100%. This animation simulates the tactile feedback sensation of iOS system buttons, enhancing interaction enjoyment.

- **Enabled/Disabled Gradient Transition**: When the button state transitions from enabled to disabled (or vice versa), the change is no longer instantaneous but smoothly transitions through a 200ms gradient. This detail avoids abrupt visual jumps during state switching.

- **Micro-Noise Texture**: A very faint Perlin noise texture (Opacity 0.02) is overlaid on the button surface, adding physical texture to the button and avoiding the overly "digital" feel of pure solid-color surfaces.

**Reason for Change**: GDI+ is inefficient at drawing complex buttons; WPF DrawingContext provides higher-performance rendering. WPF Storyboards run on the compositor thread, unaffected by UI thread load, ensuring animations are always smooth. The newly added interaction details (ambient color injection, bounce feedback, gradient transitions, noise texture) enhance the overall user experience.

**Impact Scope**: All interactive buttons are replaced with AuroraButton. Original TechButton and related code are completely removed.

---

### P1-4: Animation System Refactoring

The animation system in V1.3.26.7Release was entirely driven by PowerShell Timers. Each animation defined a Timer that updated control properties (position, size, opacity, etc.) in the Tick event, then called Invalidate to trigger repaint. The fundamental problem with this approach was the low execution efficiency of PowerShell Timer callbacks — each Tick event involved the overhead of PowerShell interpreter invocation, which became non-negligible in high-frame-rate animations (such as 60fps entrance animations).

V1.4.27.0 adopts a dual-driver architecture to refactor the entire animation system:

- **Storyboard-Driven**: Suitable for discrete animations with clear start and end points, such as window entrance/exit, button effects, and text transition animations. Storyboards are executed by the WPF animation engine on the compositor thread, providing hardware-accelerated interpolation computation, completely unaffected by UI thread load.

- **CompositionTarget.Rendering-Driven**: Suitable for continuous, real-time computed animations, such as starfield background animation and frosted glass blur updates. CompositionTarget.Rendering fires before each frame render, synchronized with the display vsync.

The newly introduced 4-stage view transition animation is the core highlight of the animation system refactoring. When the user switches from one view to another (such as from the main interface to PRO mode), the animation executes in the following sequence:

1. **Button Exit Stage**: All buttons in the current view execute a shrink-and-fade-out animation, with each button having a 30ms delay offset, producing a wave-like effect.
2. **Skeleton Exit Stage**: The background panel of the current view executes a fade-out animation.
3. **Skeleton Enter Stage**: The background panel of the new view executes a fade-in animation.
4. **Button Enter Stage**: The buttons of the new view execute an expand-and-fade-in animation, also with a wave-like delay offset.

The entire view transition process takes approximately 600ms, with animation easing curves adopting the UWP style (BackEase, CubicEase, PowerEase), producing natural and elastic visual transitions.

AuroraTextBlock's IsTextTransitionEnabled property is a key mechanism for resolving view transition flickering issues. During view transitions, ViewModel property changes trigger AuroraTextBlock's text transition animation (old text slides out + new text slides in). If the text animation and view transition animation execute simultaneously, visual flickering occurs. IsTextTransitionEnabled is set to false at the start of view transitions, suppressing text animations; it is restored to true after the transition completes. This protection mechanism ensures visual cleanliness during view transitions.

**Reason for Change**: The original Timer-driven animation had low execution efficiency in the PowerShell environment, with each Tick event involving interpreter invocation overhead. WPF Storyboards execute on the compositor thread, providing hardware-accelerated interpolation computation. The 4-stage view transition animation and IsTextTransitionEnabled protection mechanism resolve the visual flickering issue during view transitions in the original version.

**Impact Scope**: All window animations, view transitions, and control effects use the new dual-driver architecture. Original Timer animation code is completely removed.

---

### P1-5: Console Refactoring (AuroraConsoleBox)

The console in V1.3.26.7Release was based on the WinForm RichTextBox control. Log output was appended line by line through the AppendText method, with each append triggering RichTextBox's formatting engine to recompute text layout. In PRO mode, diagnostic scripts could produce hundreds of log lines in a short period, and line-by-line appending caused the UI thread to be frequently blocked, resulting in a "frozen" user experience.

V1.4.27.0 refactors the console as AuroraConsoleBox — a custom control derived from WPF Control, with an integrated full frosted glass background scheme. Rendering no longer relies on RichTextBox's formatting engine but instead draws text directly through DrawingContext, providing higher performance and fully customizable visual effects.

The core optimization is the batch line refresh mechanism. Log lines first enter a ConcurrentQueue buffer rather than being directly appended to the UI. An independent timer checks the buffer at 320ms batch intervals, rendering accumulated log lines in a single batch to the DrawingContext. This 320ms delay strikes a balance between "real-time responsiveness" and "batch efficiency" — the perceived delay is imperceptible to users (well below human reaction time), while batch rendering eliminates the overhead of single-line appending.

After batch rendering, a 260ms smooth scroll animation scrolls the viewport to the latest log line. This scrolling is not an instantaneous jump but a smooth transition through an EaseOut curve, allowing users to track the flow direction of the logs.

The newly added UWP-style text slide-in animation further enhances the visual experience. Each new log line slides in slightly from the right (offset approximately 10 pixels), reaching its final position within 200ms. This subtle animation lets users perceive that "new content is being generated" rather than "text suddenly appearing."

**Reason for Change**: The original RichTextBox line-by-line refresh caused frequent UI thread blocking during large-volume logging, resulting in a "frozen" user experience. Batch line refresh (320ms batch delay + 260ms smooth scroll) eliminates the overhead of single-line appending, and the UWP-style text slide-in animation enhances the smoothness of visual feedback.

**Impact Scope**: PRO mode log output comprehensively uses AuroraConsoleBox. Original RichTextBox and related code are completely removed.

---

### P1-6: Progress Bar Refactoring (AuroraProgressBar)

The progress bar in V1.3.26.7Release was implemented through a custom WinForm Panel. The Panel's Paint event drew a filled rectangle to represent progress, with a simple and direct drawing approach — solid color fill with a border, without any visual effects.

V1.4.27.0 refactors the progress bar as AuroraProgressBar — a WPF FrameworkElement subclass adopting a full glass material scheme. The progress bar uses the AuroraGlassMaterial shared instance to render the frosted glass background, maintaining visual consistency with the entire application's design language.

The newly added diagonal sweep light effect is the core of the progress bar visual upgrade. In the filled area of the progress bar, a semi-transparent white light band moves from left to right at a 30-degree tilt angle (achieved via SkewTransform). The light band width is approximately 20% of the progress bar's filled area, completing one left-to-right sweep in 1.5 seconds. This effect makes the progress bar appear "active" — even when the progress value is not changing, the sweep light effect lets the user perceive that the system is working.

At the progress leading edge, there is a glow point effect. The glow point is a small circle (radius approximately 3 pixels), colored bright white, following the filled front of the progress bar. The glow point's opacity attenuates in a gradient from center outward, producing a soft glow sensation. This detail makes the front of the progress bar more prominent, allowing users to see the current progress position at a glance.

**Reason for Change**: Unifying the glass material style ensures the progress bar is consistent with the entire application's design language. The diagonal sweep light and leading-edge glow point add visual depth and dynamism to the progress bar, enhancing the user experience.

**Impact Scope**: All progress bar displays use AuroraProgressBar. Original Panel progress bar code is completely removed.

---

### P1-7: Performance Tier System Upgrade (AuroraRenderEngine)

Performance detection in V1.3.26.7Release was implemented through PowerShell scripts — querying CPU core count, memory size, and other information via WMI, then assigning performance tiers based on preset rules. WMI queries in PowerShell scripts were relatively slow, and the detection logic was scattered across multiple script files.

V1.4.27.0 upgrades performance detection to a C#-implemented AuroraRenderEngine. Using C#'s System.Management namespace for direct WMI queries, detection is faster and results are more accurate. Detection content includes CPU core count, CPU frequency, total memory, GPU model, and video memory size, with this information synthesized to determine 4 performance tiers:

| Tier | Name | Determination Criteria | Effect Configuration |
|------|------|----------------------|---------------------|
| 0 | Eco | Low-end integrated graphics, memory < 4GB | Disable particles, disable complex glow, disable sweep light, disable path shadows |
| 1 | Balanced | Mid-range integrated graphics, memory 4-8GB | Enable particles (few), disable complex glow, enable sweep light, disable path shadows |
| 2 | Performance | Mid-range discrete graphics, memory 8-16GB | Enable particles (medium), enable complex glow, enable sweep light, enable path shadows |
| 3 | Extreme | High-end discrete graphics, memory > 16GB | All effects enabled, maximum quality rendering |

V1.4.27.0 introduces a user-upgradable tier feature. Through the PerformanceUpgradeDialogView dialog, users can manually select a performance tier higher than the auto-detected result. This feature is applicable to scenarios where auto-detection results are conservative — for example, a laptop with a discrete GPU may be detected as Balanced in battery mode, but the user can manually upgrade to Performance after connecting to power. The user's selection is persisted to local configuration and automatically applied on subsequent launches.

**Reason for Change**: C# WMI detection is faster and more accurate, avoiding the interpreter overhead of WMI queries in PowerShell scripts. The user-upgradable tier provides flexibility for advanced users — when auto-detection results are conservative, users can manually select a higher performance tier for better visual effects.

**Impact Scope**: Global effect levels (particles, complex glow, sweep light, path shadows) are determined by AuroraRenderEngine's performance tier. Effect switches and behaviors of all visual controls are differentially configured based on the tier.

---

### P1-8: Language Service Unification (LanguageService)

V1.3.26.7Release used a dual-engine file model to support Chinese and English — CHSPRO.ps1 (Chinese engine, approximately 3,000 lines) and ENGPRO.ps1 (English engine, approximately 3,000 lines). The two files were highly similar in content (approximately 90% identical), differing only in text strings. This dual-file model caused a serious structural drift problem: when a bug fix was implemented in CHSPRO, developers needed to manually synchronize it to ENGPRO, and manual synchronization often missed items, leading to ENGPRO having features absent from CHSPRO, or bugs fixed in CHSPRO still existing in ENGPRO.

V1.4.27.0 unifies the dual engine files into a single engine + LanguageService architecture. There is only one engine file (approximately 3,000 lines), with all user-visible text strings obtained at runtime through LanguageService. LanguageService maintains a language resource table containing Chinese and English translations for all UI text. At engine startup, the corresponding language resources are loaded based on the language parameter (--language), and all subsequent text is obtained through LanguageService's key-value lookups.

This unified architecture eliminates the structural drift problem — any engine logic change only needs to be made once and automatically applies to all languages. When adding new UI text, only the corresponding Chinese and English entries need to be added to the language resource table, without modifying engine code.

**Reason for Change**: The dual engine files (CHSPRO/ENGPRO, totaling approximately 6,000 lines of duplicate code) suffered from structural drift — ENGPRO had unique functions missing from CHSPRO, and bug fixes required manual synchronization that was often missed. Unifying to a single engine + LanguageService eliminates structural drift and reduces maintenance costs by approximately 50%.

**Impact Scope**: The PRO mode engine and all UI text are uniformly managed through LanguageService. The original CHSPRO.ps1 and ENGPRO.ps1 dual files are completely merged.

---

## 4. P2 Level: New Components

P2-level changes cover the new independent components and services introduced in V1.4.27.0. These components are built upon the P0 and P1 architectural foundations, providing new functional capabilities to the system.

### P2-1: AuroraFrostedGlassBorder (Frosted Glass Border Control)

AuroraFrostedGlassBorder is a unified frosted glass border container control, inheriting from WPF's Border. It uses the AuroraGlassMaterial shared instance's four-layer rendering pipeline (dual drop shadows, true blurred background, glass body gradient, surface overlay) to provide frosted glass visual effects for inner content.

This control serves as the glass panel foundation container for dialogs such as ElevationDialogView and MainFormView. All dialogs requiring frosted glass backgrounds simply need to place their content inside AuroraFrostedGlassBorder to automatically obtain consistent glass material effects, without needing to re-implement rendering logic.

**Purpose**: Glass panels for dialogs such as ElevationDialogView and MainFormView.

---

### P2-2: AuroraTaskHUD (Task Status HUD)

AuroraTaskHUD is a horizontal 4-step node indicator control used for visualizing PRO mode task progress. It displays 4 sequentially arranged nodes, each representing a task phase (such as "Diagnose," "Repair," "Verify," "Complete"), with nodes connected by connecting lines.

Each node has 4 states: Pending (dimmed, not yet reached), Running (bright, pulsing animation, indicating the currently executing phase), Success (green, checkmark icon, indicating completion), and Error (red, cross icon, indicating failure). State transitions are achieved through smooth color transitions and icon transformations, allowing users to understand task progress at a glance.

**Purpose**: PRO mode task progress visualization, enabling users to clearly understand the current execution phase and overall progress.

---

### P2-3: AuroraTextBlock (Text Control)

AuroraTextBlock is a text control supporting UWP-style text transition animations, inheriting from WPF's TextBlock. When the bound text content changes, AuroraTextBlock does not instantly replace the text but executes a smooth transition animation: the old text slides out upward or downward (depending on the content change direction), while the new text simultaneously slides in from the opposite direction.

The IsTextTransitionEnabled property is AuroraTextBlock's core protection mechanism. During view transitions, if multiple ViewModel properties change simultaneously, it triggers multiple AuroraTextBlock instances to simultaneously execute text animations, which, when overlaid with the view transition animation, creates visual chaos. By setting IsTextTransitionEnabled to false, text animations are temporarily suppressed, displaying only the final text value; after the view transition completes, it is restored to true, and subsequent text changes resume normal animation.

**Purpose**: All dynamic text displays, such as window titles, progress percentages, status labels, etc.

---

### P2-4: AuroraCustomEasing (Custom Easing Curve)

AuroraCustomEasing is a custom easing curve based on the Spring-Damper spring physics model. Unlike WPF's built-in easing functions (such as CubicEase and BackEase), the Spring-Damper model simulates real physical spring behavior — the damping coefficient controls the spring's decay rate, the spring coefficient controls the spring's stiffness, and the mass parameter affects the spring's inertia.

This easing curve is primarily used for the SplashScreen entrance animation. When the splash screen appears, AuroraCustomEasing drives an overshoot-bounce scaling animation, presenting the splash screen in a "bouncing" manner that enhances brand visual impact.

**Purpose**: SplashScreen entrance animation, providing overshoot-bounce effects based on the spring physics model.

---

### P2-5: IntegrityGuardService (Integrity Protection Service)

IntegrityGuardService is a C#-implemented integrity verification and anti-debugging mechanism. At program startup, this service executes the following verification steps:

- Verifies the SHA-256 hash values of all core files against the hash list embedded at build time, ensuring files have not been tampered with.
- Detects debugger attachment status through the CheckRemoteDebuggerPresent and IsDebuggerPresent APIs, determining whether a debugger is attempting to attach to the process.
- Verifies the watchdog connection status, ensuring the communication channel with the watchdog process is functioning properly.

Any verification failure triggers the security response flow — interrupting startup, displaying a security warning, and logging the event.

**Purpose**: Security verification at program startup, ensuring code integrity and runtime environment security.

---

### P2-6: ElevationService + ElevationTokenService (Privilege Elevation Services)

ElevationService and ElevationTokenService work together to implement a secure UAC privilege elevation flow. When the program requires administrator privileges (such as modifying the system registry, writing to protected directories), these two services operate according to the following flow:

1. ElevationTokenService generates an elevation token, encrypted using AES-256-CBC. The token contains a nonce, timestamp, and payload (encrypted script path and hash list).
2. The token is written to a temporary file and passed to the new elevated process via the `-ElevationTokenPath` command-line parameter.
3. After the elevated process starts, ElevationService reads the token file and decrypts it using a PBKDF2-derived key.
4. It verifies that the decrypted content contains a valid identifier, confirming the legitimacy of the token source.
5. The token has a validity period of 120 seconds and automatically expires after timeout.

**Purpose**: Secure privilege elevation when administrator privileges are required, ensuring the trust chain is not broken during the UAC elevation process.

---

### P2-7: WatchdogService (Watchdog Service)

WatchdogService is a process monitoring and anomaly recovery service. It maintains an independent watchdog process that continuously monitors the main program's running status. The watchdog process maintains heartbeat communication with the main program through a named pipe; if the main program fails to send a heartbeat signal within the specified time, the watchdog determines that the main program has exited abnormally, executes cleanup operations (releasing resources, cleaning temporary files, resetting security state), and logs the anomaly event.

Additionally, WatchdogService is responsible for monitoring the main program's memory usage, issuing warnings when memory usage exceeds thresholds, and triggering a graceful shutdown flow when necessary.

**Purpose**: Ensuring stable program operation, executing cleanup operations upon abnormal exit to prevent resource leaks and security state residue.

---

### P2-8: SessionCacheService + UndoManagerService + RestoreService

These three services work together to provide comprehensive work progress saving and recovery capabilities:

- **SessionCacheService**: Serializes and persists the current work session's state (progress, parameters, intermediate results) to local cache. Cache data is stored in JSON format, containing timestamps, phase identifiers, and progress percentages.

- **UndoManagerService**: Maintains an operation history stack, recording each user operation step. When the user triggers undo, UndoManagerService pops the most recent operation from the top of the stack and executes the inverse operation, restoring the state to before the operation.

- **RestoreService**: Detects whether there are incomplete sessions at program startup. If so, RestoreService reads the cached data, calculates AgeInDays (days since session interruption), and prompts the user through SessionRestoreDialogView whether to restore the previous progress.

**Purpose**: Supporting work progress saving and recovery, preventing work progress loss due to unexpected exits.

---

## 5. P3 Level: Optimizations and Fixes

P3-level changes focus on performance optimizations and visual defect fixes. These changes do not affect functional behavior but significantly enhance user experience and system stability.

### P3-1: Frame Rate Normalization

AuroraStarfield's animation parameters (star point movement speed, flicker frequency, opacity change rate) were designed for 30fps in V1.3.26.7Release. After migrating to WPF, CompositionTarget.Rendering drives at 60fps; if the original parameters were used directly, all animations would run at double speed.

The fix introduces an animationTimeScale factor (value of 0.5), multiplying all animation increments by this factor. Thus, at double frame rate, per-frame increments are halved, and the overall animation speed remains unchanged. This normalization ensures that the WPF version's starfield animation behavior is completely consistent with the original WinForm version.

**Reason**: The original WinForm constants were designed for 30fps, and WPF's 60fps caused 2x animation speed. All animation increments are normalized to the 30fps baseline through the animationTimeScale factor.

---

### P3-2: Brush Cache Pooling

In WPF, the creation of Brush objects (SolidColorBrush, LinearGradientBrush, etc.) involves the allocation of unmanaged resources. If new Brush objects are created every frame, it leads to frequent GC allocation and collection, increasing rendering overhead.

AuroraGlassMaterial and AuroraStarfield pre-create all required static Brush objects at initialization and call the Freeze method to freeze them into immutable state. Frozen Brushes can be accessed by the WPF rendering engine through a faster path because thread safety concerns are eliminated. All Brushes shared across frames are cached and reused, eliminating per-frame GC allocation.

**Reason**: Eliminates per-frame GC allocation. By pre-creating and freezing static Brush objects, rendering overhead is reduced and frame rate stability is improved.

---

### P3-3: Blurred Background 30fps Throttling

AuroraGlassMaterial's blurred background generation involves the RenderTargetBitmap.Render call — a relatively expensive operation because it needs to capture the complete visual tree behind the control and apply Gaussian blur. Under 60fps CompositionTarget.Rendering driving, executing this operation every frame would produce unnecessary computational overhead.

The throttling optimization reduces the blurred background update frequency from 60fps to 30fps — the RenderTargetBitmap.Render is executed only every other frame. The blur effect is inherently a smooth visual change, and the human eye cannot distinguish between 30fps and 60fps blur update frequencies. This optimization halves the rendering overhead of the blurred background while maintaining visual quality.

**Reason**: The blur effect is inherently smooth, and the human eye cannot distinguish between 30fps and 60fps blur updates. Halving the RenderTargetBitmap.Render frequency significantly reduces rendering overhead.

---

### P3-4: Skip RTB When No Glass Controls Are Present

During the SplashScreen display period, no controls using AuroraGlassMaterial are registered in the rendering pipeline. In this case, AuroraGlassMaterial's RenderTargetBitmap.Render call is completely unnecessary — the captured frame would not be used by any control.

The optimization logic maintains a registration counter, tracking how many controls are currently using AuroraGlassMaterial. When the counter is 0, RTB.Render calls are completely skipped. The SplashScreen animation monopolizes the UI thread through Storyboards, and avoiding the additional overhead of RTB.Render prevents animation frame drops.

**Reason**: The Splash animation monopolizes the UI thread through Storyboards, and unnecessary RTB.Render calls cause frame drops. By detecting the registration counter, RTB.Render is completely skipped when no Glass controls are present.

---

### P3-5: View Transition Flicker Fix

WPF completes the first frame render before the Loaded event fires. This means that if a control defines a visible initial state in XAML, before the Loaded event handler changes it to hidden, the user will see one frame of the "flashed" initial state, creating a flicker sensation.

The fix is to set all controls' initial states to hidden in XAML (Opacity=0, Visibility=Collapsed, or appropriate initial transforms), and then in the Loaded event handler, launch the entrance animation to make them visible. This way, during the first frame render, controls are in a hidden state, the user sees nothing, and the entrance animation smoothly transitions from the hidden state to the visible state.

**Reason**: WPF completes the first frame render before the Loaded event fires, causing the initial control state to "flash." By setting hidden initial states in XAML and launching entrance animations in the Loaded event, first-frame flashing is avoided.

---

### P3-6: Title Dual-Animation Fix

During view transitions, ViewModel title property changes trigger AuroraTextBlock's text transition animation (old text slides out + new text slides in). Simultaneously, the view transition animation is also executing (skeleton exit/enter, button exit/enter). The two animations overlay each other, causing visual flickering — two different animations are running simultaneously in the same area.

The fix uses AuroraTextBlock's IsTextTransitionEnabled property. At the start of view transitions, this property is set to false, suppressing text transition animations; after the transition completes, it is restored to true. This way, during view transitions, only the final title text is displayed (without animation), avoiding the flicker caused by dual-animation overlay.

**Reason**: ViewModel property changes trigger text animations, which overlay with view transition animations, causing flickering. By temporarily disabling text animations through IsTextTransitionEnabled during view transitions, the dual-animation conflict is eliminated.

---

### P3-7: Process Exit Safe Cleanup

In V1.3.26.7Release, Timers held strong references to controls through Tick events. If a Timer was not stopped when the window closed, this strong reference would prevent the GC from reclaiming the control object, causing memory leaks. More seriously, when the SplashScreen closed, if the Starfield animation's Timer was still running, it could continue firing Tick events after the new window was created, accessing the closed SplashScreen control and causing exceptions.

In V1.4.27.0, all controls implement the IDisposable interface. In the Dispose method, controls stop all animations (Storyboard and CompositionTarget.Rendering event handlers), release all Dispatcher resources, and unsubscribe from all events. When a window closes, the framework calls the Dispose method of all child controls, ensuring resources are completely released.

When the SplashScreen closes, Starfield's Dispose method is specifically called to stop the CompositionTarget.Rendering subscription, preventing animations from continuing to fire after the window is closed.

**Reason**: Timers hold strong references to controls through Tick events, preventing GC reclamation. All controls implement IDisposable, thoroughly releasing resources when windows close. Starfield animation is stopped when the Splash closes, preventing access to the closed window.

---

### P3-8: Console Batch Refresh

In PRO mode, diagnostic scripts can produce a large volume of log output in a short period. The line-by-line refresh method in V1.3.26.7Release caused Dispatcher queue congestion — each log line was enqueued as an independent UI update operation, with a large number of operations simultaneously waiting for UI thread processing, causing the UI to become completely unresponsive.

The batch refresh solution uses ConcurrentQueue as a buffer. Log lines are first enqueued, and an independent timer checks the queue at 320ms intervals, batch-writing accumulated log lines to the UI in a single operation. This drastically reduces the number of Dispatcher operations (from one operation per line to one operation per batch), avoiding queue congestion.

A 50ms initial delay further optimizes the startup phase experience — during the startup phase, log output is very rapid, and the 50ms delay allows the first batch of log lines sufficient time to accumulate before entering the normal 320ms batch interval.

**Reason**: Large-volume line-by-line log refresh caused Dispatcher queue congestion and complete UI unresponsiveness. The ConcurrentQueue buffer + 320ms batch refresh drastically reduces the number of Dispatcher operations, eliminating UI freezing.

---

## 6. Compatibility Preservation

Although V1.4.27.0 has undergone fundamental changes in its underlying architecture, it maintains full compatibility with V1.3.26.7Release in the following aspects:

| Compatibility Item | Description |
|--------------------|-------------|
| PowerShell 5.1 Compatibility | C# code uses C# 5.0 language version, ensuring it can run in Windows' built-in PowerShell 5.1 environment without requiring additional .NET Framework installation |
| Command-Line Parameters | All command-line parameters are fully compatible, including --pro, --language, --launched-by-exe, --ElevationTokenPath, etc. |
| syncHash Synchronization Mechanism | The cross-Runspace communication syncHash interface is fully compatible, with script-side read/write methods unchanged |
| Environment Variable Interface | AURORA_PERF_TIER, AURORA_LANGUAGE, AURORA_TOKEN_PATH, AURORA_LAUNCHED_BY_EXE, and other environment variable interfaces are fully compatible |
| LogOutput Type | LogOutput maintains the string type, supporting the += string concatenation operation on the script side, ensuring original scripts are unaffected |
| Startup Flow | The interaction flow between the launcher (EXE) and PowerShell scripts remains unchanged; only the internal implementation is replaced from WinForm to WPF |

These compatibility guarantees mean that existing users can upgrade to V1.4.27.0 without modifying any scripts, configurations, or startup parameters.

---

## 7. Change Summary Table

| No. | Tier | Change Description | Reason for Change | Impact Scope |
|-----|------|-------------------|-------------------|--------------|
| P0-1 | P0 | UI framework migrated from WinForm to WPF | GDI+ rendering performance is limited, cannot achieve modern frosted glass effects; WPF provides GPU-accelerated rendering | All windows, controls, animation systems |
| P0-2 | P0 | MVVM architecture introduced | Original version lacked layering, UI and business logic were intermixed, difficult to maintain and test | All views and business logic |
| P0-3 | P0 | PowerShell integration upgraded from single Runspace to RunspacePool | Single Runspace cannot process multiple script tasks in parallel | PRO mode script execution, log output, progress reporting |
| P0-4 | P0 | C# 5.0 compiled control library replaces PowerShell dynamic creation | Compiled code is more efficient; compile-time type checking eliminates runtime errors | All UI controls |
| P1-1 | P1 | Frosted glass material system (AuroraGlassMaterial) | WinForm cannot achieve true blurred background; four-layer rendering pipeline achieves realistic glass effects | AuroraFrostedGlassBorder, AuroraConsoleBox, AuroraTaskHUD, AuroraButton |
| P1-2 | P1 | Starfield background refactoring (AuroraStarfield) | DispatcherTimer has unstable frame rate; CompositionTarget.Rendering aligns with vsync | Starfield backgrounds in all windows |
| P1-3 | P1 | Button system refactoring (AuroraButton) | GDI+ drawing efficiency is low; WPF Storyboard provides hardware-accelerated animation | All interactive buttons |
| P1-4 | P1 | Animation system refactoring (dual-driver architecture) | Timer-driven animation is inefficient; Storyboard provides compositor thread hardware acceleration | All window animations, view transitions, control effects |
| P1-5 | P1 | Console refactoring (AuroraConsoleBox) | Line-by-line refresh causes UI freezing; batch refresh eliminates performance bottleneck | PRO mode log output |
| P1-6 | P1 | Progress bar refactoring (AuroraProgressBar) | Unifies glass material style; adds sweep light and glow point effects | All progress bar displays |
| P1-7 | P1 | Performance tier system upgrade (AuroraRenderEngine) | C# WMI detection is faster and more accurate; user-upgradable tier provides flexibility | Global effect levels |
| P1-8 | P1 | Language service unification (LanguageService) | Dual engine files had structural drift; bug fixes required manual synchronization | PRO mode engine, all UI text |
| P2-1 | P2 | New AuroraFrostedGlassBorder | Unified frosted glass border container, avoiding duplicate rendering logic implementation | Dialog glass panels |
| P2-2 | P2 | New AuroraTaskHUD | Horizontal 4-step node indicator, task progress visualization | PRO mode task progress |
| P2-3 | P2 | New AuroraTextBlock | Supports UWP-style text transition animations, IsTextTransitionEnabled protection mechanism | All dynamic text displays |
| P2-4 | P2 | New AuroraCustomEasing | Spring-Damper spring physics model easing | SplashScreen entrance animation |
| P2-5 | P2 | New IntegrityGuardService | C#-implemented integrity verification and anti-debugging mechanism | Startup security verification |
| P2-6 | P2 | New ElevationService + ElevationTokenService | AES-256-CBC encrypted elevation token, secure UAC elevation | Administrator privilege elevation flow |
| P2-7 | P2 | New WatchdogService | Process monitoring and anomaly recovery | Program stable operation guarantee |
| P2-8 | P2 | New SessionCacheService + UndoManagerService + RestoreService | Session caching, undo management, restore service | Work progress saving and recovery |
| P3-1 | P3 | Frame rate normalization | Original 30fps constants cause 2x speed animation at 60fps | Starfield background animation |
| P3-2 | P3 | Brush cache pooling | Eliminates per-frame GC allocation, reduces rendering overhead | Glass material and starfield rendering |
| P3-3 | P3 | Blurred background 30fps throttling | Human eye cannot distinguish 30fps from 60fps blur updates | Frosted glass background rendering |
| P3-4 | P3 | Skip RTB when no Glass controls present | Avoids unnecessary RTB overhead during Splash animation | Splash screen performance |
| P3-5 | P3 | View transition flicker fix | First frame rendered before Loaded event causes initial state flash | View transitions in all windows |
| P3-6 | P3 | Title dual-animation fix | Text animation and view transition animation overlay causes flicker | Title display during view transitions |
| P3-7 | P3 | Process exit safe cleanup | Timer strong references prevent GC reclamation, causing resource leaks | All control lifecycles |
| P3-8 | P3 | Console batch refresh | Large-volume line-by-line log refresh causes Dispatcher queue congestion | PRO mode log output performance |

---

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *This tool is intended for personal educational use only. Please comply with local laws and regulations.*