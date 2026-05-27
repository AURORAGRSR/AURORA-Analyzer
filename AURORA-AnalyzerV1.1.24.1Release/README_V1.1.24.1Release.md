# AURORA Analyzer V1.1.24.1 Release — 用户指南

**版本 / Version:** V1.1.24.1\
**发布日期 / Release Date:** 2026.05.27\
**作者 / Author:** AURORA VelociRaptor-GR Dev PRJ.\
**适用平台 / Platform:** Windows 7/8/10/11 (x64)\
**系统要求 / Requirements:** .NET Framework 4.7.2+, PowerShell 5.1+

***

## 🎯 快速开始 / Quick Start

### 方式 1：双击 EXE 启动（推荐）/ Double-click EXE Launch (Recommended)

```
双击运行：AURORA.Launcher-双击启动.exe
```

✅ **优势 / Advantages:**

- 自动处理管理员权限
- 无需密码验证
- 完整的安全保护链路

### 方式 2：PowerShell 启动 / PowerShell Launch

```powershell
# 右键 → "使用 PowerShell 运行"
```

⚠️ **注意 / Note:** 首次启动需要密码验证（请联系管理员获取）

***

## 🆕 V1.1.24.1 新功能亮点 / What's New

### 1. 🛡️ 全链路安全监控 / Full-Link Security Monitoring

> **专业图形模式运行期间，安全性不再"暂停"**\
> 即使在使用专业图形模式分析日志时（通常 5-30 分钟），程序仍持续监控文件完整性，确保整个使用过程都处于安全保护之下。

### 2. ⚠️ 友好的安全警告 / User-Friendly Security Alerts

> **检测到篡改时，不再是"突然消失"**\
> 程序会显示一个 15 秒倒计时警告窗口，清晰展示哪些文件被篡改或缺失，给您充足时间了解问题。

### 3. 📝 清爽的控制台日志 / Clean Console Logs

> **不再刷屏！日志只显示一行**\
> 完整性检查日志现在会原地刷新，显示检查次数和时间，既美观又便于追踪。

***

## 🔧 主要功能 / Key Features

### 1. 智能日志分析 / Intelligent Log Analysis

- **支持的日志类型 / Supported Log Types:**
  - System（系统日志）
  - Application（应用程序日志）
  - Security（安全日志）
  - Setup（安装日志）
  - DNS Server、DHCP Server、Directory Service、IIS Admin Service
- **分析模式 / Analysis Modes:**
  - 📊 **单日快速扫描** - 快速查看当天的关键事件
  - 📈 **日期范围深度分析** - 自定义时间段的趋势分析
  - 🎯 **高风险事件优先** - 只显示错误、警告、严重事件

### 2. 专业图形模式 / Professional Graphics Mode

- **实时进度可视化** - 动态光晕扫过进度条 + 粒子效果
- **双语界面** - 中英文自动切换
- **智能诊断集成** - 一键切换到智能修复模式

### 3. 智能诊断与自主修复 / Smart Diagnosis & Auto-Repair

- **自动识别问题** - 基于事件 ID、来源、级别的智能匹配
- **修复建议生成** - 针对每个问题提供可执行的解决方案
- **一键修复** - 支持批量应用修复方案

***

## 🔐 安全性说明 / Security Notes

### 启动验证 / Launch Authentication

本工具使用 **RSA-2048 + AES-256** 双重加密验证：

- ✅ EXE 启动器持有私钥，生成一次性 Token
- ✅ PowerShell 脚本持有公钥，验证 Token 合法性
- ✅ Token 60 秒后自动过期，防止重放攻击

### 运行时监控 / Runtime Monitoring

- **双重定时器检查** - 每 3 秒定期检查 + 2-7 秒随机检查
- **文件监视器** - 实时检测文件变化（<100ms 响应）
- **19 个核心文件** - 所有关键组件都在监控范围内

### 如果您看到警告窗口 / If You See Warning Window

```
⚠️ AURORA 安全警报

程序完整性已被破坏，检测到以下问题：
- 缺失文件：Scripts\AURORA-CoreEngine.ps1
- 篡改文件：Scripts\AURORA-AnalyzerPRO.ps1

程序将在 15 秒后自动退出。
```

**应对措施 / What to Do:**

1. ⏰ 在 15 秒内拍照记录被篡改的文件
2. 🔄 重新下载完整安装包
3. 🧹 删除旧版本，重新解压到干净目录
4. 📧 联系管理员报告问题

***

## 📊 输出文件说明 / Output Files

分析完成后，会在 `UserLogs` 目录生成以下文件：

| 文件名 / File          | 说明 / Description | 格式 / Format |
| ------------------- | ---------------- | ----------- |
| `系统_日志_日期.json`     | 结构化日志数据          | JSON        |
| `系统_日志_日期.xml`      | 可导入事件查看器         | XML         |
| `系统_日志_日期.csv`      | 可导入 Excel 分析     | CSV         |
| `系统_日志_日期_摘要.txt`   | 人类可读摘要           | 文本          |
| `系统_日志_日期_趋势分析.txt` | 周期性趋势报告          | 文本          |
| `系统_日志_日期_趋势数据.csv` | 趋势图表数据           | CSV         |

***

## ❓ 常见问题 / FAQ

### Q1: 为什么需要密码验证？/ Why Password Verification?

**A:** 防止未授权用户直接运行 PowerShell 脚本绕过 EXE 启动器的安全验证。密码由管理员在构建时设置。

### Q2: 提示"文件被篡改"怎么办？/ What if "File Tampered" Alert?

**A:**

1. 不要惊慌，这是保护机制在起作用
2. 检查是否手动修改过脚本文件
3. 如果是误报，重新下载官方版本
4. 如果确实发现异常，立即断开网络并联系管理员

### Q3: 专业图形模式打不开？/ Professional Mode Won't Open?

**A:** V1.1.24.1 已修复此问题。如果仍无法打开，请检查：

- 是否有杀毒软件拦截
- 是否以管理员身份运行
- 查看控制台是否有错误信息

### Q4: 日志分析很慢怎么办？/ Log Analysis Too Slow?

**A:**

- 选择"高风险事件优先"模式，只分析关键事件
- 缩小日期范围（建议 7 天内）
- 关闭其他占用 CPU 的程序

***

## 🆘 故障排除 / Troubleshooting

### 问题 1：启动时提示"未找到加密验证文件"

**解决方案：**

```
确保以下文件在同一目录：
- AURORA.Launcher-双击启动.exe
- GAURORA.CHK.ENC
- Scripts\AURORA-AnalyzerLauncherGUI.ps1
```

### 问题 2：分析完成后没有输出文件

**解决方案：**

1. 检查 `UserLogs` 文件夹是否存在
2. 确认当前用户有写入权限
3. 查看控制台是否有错误信息
4. 尝试以管理员身份运行

### 问题 3：智能修复模式无法识别问题

**解决方案：**

1. 确保已导出日志文件
2. 从 PRO 模式启动智能修复（而非直接运行）
3. 检查日志类型是否支持

***

## 📞 获取帮助 / Get Help

### 技术支持渠道 / Support Channels

<https://github.com/AURORAGRSR/AURORA-Analyzer/tree/ReleaseVersion>

### 报告问题时请提供 / When Reporting Issues

- ✅ 软件版本号（在启动画面显示）
- ✅ Windows 版本和 PowerShell 版本
- ✅ 完整的错误信息截图
- ✅ 问题复现步骤

***

## 📋 版本历史 / Version History

| 版本 / Version | 发布日期 / Date | 主要更新 / Key Updates    |
| ------------ | ----------- | --------------------- |
| V1.1.24.1    | 2026.05.27  | 全链路安全监控、警告窗口优化、日志清爽化  |
| V1.1.24.0    | 2026.05.25  | RSA 加密体系、反逆向工程、实时监控增强 |
| V1.1.23.0    | 2026.05.14  | 双语支持、智能修复模式、Undo 管理器  |

***

## ⚖️ 许可与免责 / License & Disclaimer

**许可 / License:** Proprietary (All Rights Reserved)\
**版权 / Copyright:** © 2026 AURORA VelociRaptor-GR Dev PRJ.

**免责声明 / Disclaimer:**

> 本工具仅供学习和研究使用。作者不对使用本工具造成的任何数据丢失、系统损坏或其他损失承担责任。使用本工具即表示您同意自行承担所有风险。
>
> This tool is for educational and research purposes only. The author is not responsible for any data loss, system damage, or other losses caused by using this tool. By using this tool, you agree to assume all risks.

***

**最后更新 / Last Updated:** 2026.05.27\
**文档版本 / Doc Version:** 1.0
