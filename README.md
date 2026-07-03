# AURORA-Analyzer V1.4.27.1 Release Notes

***

## 1. Welcome to V1.4.27.1

Thank you for choosing AURORA-Analyzer! V1.4.27.1 is a carefully refined release building upon V1.4.27.0. On top of the frosted glass material system introduced in V1.4.27.0, we have introduced the more advanced V5 material pipeline and conducted deep tuning of the glass visual details. Every hover illumination, every edge highlight, and every color gradient layer has been meticulously refined to deliver a more ceremonial user experience.

***

## 2. Evolution of Glass Material

### V5 Advanced Material Pipeline

The brand-new V5 material system decomposes glass rendering into nine independent layers: shadow, blur, tint, body, noise, fresnel, bevel, scanline, and glow. Each layer is computed independently and composited in order, delivering an unprecedented level of material depth. The console, task HUD, privilege indicator, and progress bar in PRO mode have all been upgraded to the V5 pipeline, achieving visual consistency with the main interface.

### More Natural Edge Highlights

Previously, when hovering over glass, the edge highlights concentrated only at the four corners, looking unnatural. V1.4.27.1 redesigns the highlight algorithm so that the glow is evenly distributed along the rounded rectangular edge of the glass — the midpoints of the four edges and the four corners share consistent brightness, with transitions as smooth as silk.

### More Layered Color Sampling

The ambient color of the glass now produces a gradient along the vertical direction. The top, middle, and bottom separately sample different positions of the aurora color band, simulating the hue shift of a real aurora from top to bottom. Tall glass panels (such as the console) are no longer a flat expanse of solid color but present a profound sense of depth.

***

## 3. More Ceremonial Interaction

### Elegant Hover Illumination

When you hover over the glass, the edge glow no longer snaps on instantly but gracefully blooms over approximately 3 seconds. Using an EaseInOutCubic easing curve, the beginning is nearly imperceptible, the middle progresses steadily, and the end converges with composure. When you move the mouse away, the glow fades out at the same gentle rhythm. Every interaction feels like a gaze, full of ceremony.

### Removal of Mouse-Following Highlight

The mouse-following highlight introduced in V1.4.27.0 had no noticeable visual effect in actual use and instead added unnecessary rendering overhead. V1.4.27.1 removes this layer, letting hover feedback be carried entirely by the edge glow, making the visual expression purer and more focused.

***

## 4. Bug Fixes

### Main Interface Glass Blur Restored

Some users reported that the glass panels on the main interface lacked blur effects, allowing the starfield beneath to show through directly. This was caused by a timing race during window switching — when the old window closed, it incorrectly cleared the background source already registered by the new window, causing blur sampling to fail. V1.4.27.1 fixes this issue; every window in the startup chain now correctly obtains a blurred background.

### Animation Speed Parameter Now Effective

Fixed a defect that prevented animation speed parameters from taking effect. Previously, when time-delta data was unavailable, the system would fall back to a fixed rate, causing the carefully tuned gentle transitions to be "fast-forwarded." The speed parameter now correctly takes effect, and the hover transition truly achieves a 3-second unhurried rhythm.

***

## 5. Upgrade Notes

V1.4.27.1 is fully compatible with V1.4.27.0. All command-line parameters, configuration files, and script interfaces require no modification. Simply replace the program files to complete the upgrade.

***

## 6. System Requirements

| Item              | Minimum Requirement              |
| ----------------- | -------------------------------- |
| Operating System  | Windows 10 or later              |
| .NET Framework    | 4.8 or later                     |
| Memory            | 4 GB or more recommended         |
| Screen Resolution | 1366 × 768 or higher recommended |

***

> **© AURORA VelociRaptor-GR Dev PRJ. All rights reserved.**
>
> *This tool is intended for personal educational use only. Please comply with local laws and regulations.*

