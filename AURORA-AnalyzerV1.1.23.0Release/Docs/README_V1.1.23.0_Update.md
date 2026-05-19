# AURORA Analyzer V1.1.23.0 - Update Guide / 更新指南

**更新日期:** 2026.05.19  
**当前版本:** V1.1.23.0  
**上一版本:** V1.1.22.0  
**作者:** AURORA VelociRaptor-GR Dev PRJ.

---

## 📋 目录 / Table of Contents

1. [更新概览 / Update Overview](#-更新概览)
2. [更新前准备 / Pre-Update Preparation](#-更新前准备)
3. [更新步骤 / Update Steps](#-更新步骤)
4. [更新后验证 / Post-Update Verification](#-更新后验证)
5. [回滚指南 / Rollback Guide](#-回滚指南)
6. [新增模块详解 / New Modules Details](#-新增模块详解)
7. [常见问题 / FAQ](#-常见问题)

---

## 🎯 更新概览

### 版本信息

| 项目 | 详情 |
|------|------|
| **新版本** | V1.1.23.0 |
| **发布日期** | 2026.05.19 |
| **更新类型** | 重大功能更新 (Minor Release) |
| **兼容性** | 向下兼容 V1.1.0+ |
| **强制更新** | 否（推荐更新） |

### 更新亮点

✅ **Phase 4.2 Undo 支持系统** - 完整的撤销保护机制  
✅ **Minidump 自动解析** - 蓝屏转储文件自动分析  
✅ **知识库缓存机制** - 诊断速度提升 70%  
✅ **动画引擎解耦** - 模块化架构改进  
✅ **安全性增强** - 前置检查 + 风险评估 + 回滚机制  

### 新增文件列表

本次更新将新增以下文件：

```
新增文件（5 个 Phase 4.2 模块）:
├── Scripts\AURORA-RestoreManager.ps1           [新增] 系统还原管理器
├── Scripts\AURORA-RepairLogger.ps1             [新增] 修复日志记录器
├── Scripts\AURORA-UndoManager.ps1              [新增] 快速备份与还原
├── Scripts\AURORA-RepairTools.ps1              [新增] 修复工具入口
└── Scripts\AURORA-UndoViewer.ps1               [新增] Undo 管理器查看器

新增文件（1 个 Phase 5 模块）:
└── Scripts\Core\AURORA-AnimationCoreEngine.ps1 [新增] 动画核心引擎

新增/更新文件:
├── Data\AURORA-TechData.cache.clixml           [更新] 知识库缓存文件
├── Resources\CascadiaMono.ttf                  [更新] 字体文件（可选）
└── version.txt                                 [更新] 版本信息
```

### 更新规模

| 项目 | 数量 |
|------|------|
| 新增文件 | 7 个 |
| 更新文件 | 3 个 |
| 新增代码行数 | ~2,000 行 |
| 更新代码行数 | ~500 行 |
| 新增功能 | 4 项主要功能 |
| Bug 修复 | 3 项 |

---

## ⚠️ 更新前准备

### 1. 系统检查清单

在开始更新前，请完成以下检查：

#### ✅ 系统兼容性检查

```powershell
# 检查 PowerShell 版本
$PSVersionTable.PSVersion

# 要求：5.1 或更高
# 如果低于 5.1，请先更新 Windows
```

#### ✅ 磁盘空间检查

```powershell
# 检查可用磁盘空间
Get-Volume | Select-Object DriveLetter, SizeRemaining, Size

# 要求：至少 100MB 可用空间
# 推荐：500MB 以上
```

#### ✅ 权限检查

```powershell
# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "✅ 当前具有管理员权限" -ForegroundColor Green
} else {
    Write-Host "⚠️ 当前无管理员权限（部分功能受限）" -ForegroundColor Yellow
}
```

#### ✅ 系统还原状态检查

```powershell
# 检查系统还原是否启用
try {
    $restoreKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -ErrorAction Stop
    Write-Host "✅ 系统还原已启用" -ForegroundColor Green
} catch {
    Write-Host "⚠️ 系统还原未启用（Undo 功能将受限）" -ForegroundColor Yellow
    Write-Host "提示：系统属性 → 系统保护 → 启用系统还原" -ForegroundColor Cyan
}
```

### 2. 数据备份

#### 备份用户日志

```powershell
# 创建备份目录
$backupDir = ".\Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

# 备份用户日志
if (Test-Path ".\UserLogs") {
    Copy-Item -Path ".\UserLogs" -Destination "$backupDir\UserLogs" -Recurse
    Write-Host "✅ 用户日志已备份到：$backupDir\UserLogs" -ForegroundColor Green
}
```

#### 备份会话缓存

```powershell
# 备份会话缓存
if (Test-Path ".\SessionCache") {
    Copy-Item -Path ".\SessionCache" -Destination "$backupDir\SessionCache" -Recurse
    Write-Host "✅ 会话缓存已备份到：$backupDir\SessionCache" -ForegroundColor Green
}
```

#### 备份配置文件

```powershell
# 备份配置
$configFiles = @(
    ".\version.txt",
    ".\Data\AURORA-TechData.json"
)

foreach ($file in $configFiles) {
    if (Test-Path $file) {
        Copy-Item -Path $file -Destination "$backupDir\$([System.IO.Path]::GetFileName($file))"
        Write-Host "✅ 配置已备份：$file" -ForegroundColor Green
    }
}
```

### 3. 创建系统还原点（推荐）

```powershell
# 以管理员身份运行 PowerShell 后执行
Enable-ComputerRestore -Drive "$env:SystemDrive"

# 创建系统还原点
Checkpoint-Computer -Description "Before AURORA V1.1.23.0 Update" -RestorePointType "MODIFY_SETTINGS"

Write-Host "✅ 系统还原点已创建" -ForegroundColor Green
Write-Host "   描述：Before AURORA V1.1.23.0 Update" -ForegroundColor Cyan
```

---

## 📥 更新步骤

### 方法 1: 覆盖更新（推荐）

适用于从 V1.1.20.0 或更高版本更新。

#### 步骤 1: 下载新版本

下载 `AURORA_Analyzer_v1.1.23.0_Release.zip` 到本地。

#### 步骤 2: 解压文件

```powershell
# 解压到临时目录
$zipPath = "C:\Downloads\AURORA_Analyzer_v1.1.23.0_Release.zip"
$extractPath = "C:\Temp\AURORA_Update"

Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
```

#### 步骤 3: 关闭 AURORA

确保 AURORA 程序完全关闭：

```powershell
# 检查是否有 AURORA 进程运行
Get-Process | Where-Object {$_.Name -like "*AURORA*" -or $_.MainWindowTitle -like "*AURORA*"} | Stop-Process -Force
```

#### 步骤 4: 覆盖更新

```powershell
# 进入 AURORA 安装目录
cd "E:\PC SOFT\优化软件\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory"

# 复制新文件
Copy-Item -Path "$extractPath\Scripts" -Destination ".\Scripts" -Recurse -Force
Copy-Item -Path "$extractPath\Data" -Destination ".\Data" -Recurse -Force
Copy-Item -Path "$extractPath\Resources" -Destination ".\Resources" -Recurse -Force

# 复制根目录文件
Copy-Item -Path "$extractPath\AURORA.Launcher-双击启动.exe" -Destination ".\" -Force
Copy-Item -Path "$extractPath\GAURORA.CHK.ENC" -Destination ".\" -Force
Copy-Item -Path "$extractPath\version.txt" -Destination ".\" -Force
Copy-Item -Path "$extractPath\desktop.ini" -Destination ".\" -Force
```

#### 步骤 5: 验证完整性

```powershell
# 运行目录完整性检查
.\Scripts\AURORA-AnalyzerLauncherGUI.ps1

# 如果启动成功，说明更新完成
```

### 方法 2: 全新安装

适用于从早期版本（V1.1.19.x 或更早）更新。

#### 步骤 1: 完全卸载旧版本

```powershell
# 备份数据（参考更新前准备）
$backupDir = ".\Backup_OldVersion_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

# 备份用户数据
Copy-Item -Path ".\UserLogs" -Destination "$backupDir\UserLogs" -Recurse
Copy-Item -Path ".\SessionCache" -Destination "$backupDir\SessionCache" -Recurse

# 删除旧文件
Remove-Item -Path ".\Scripts" -Recurse -Force
Remove-Item -Path ".\Data" -Recurse -Force
Remove-Item -Path ".\Resources" -Recurse -Force
Remove-Item -Path ".\AURORA.Launcher-双击启动.exe" -Force
Remove-Item -Path ".\GAURORA.CHK.ENC" -Force
Remove-Item -Path ".\desktop.ini" -Force
```

#### 步骤 2: 安装新版本

```powershell
# 解压新版本
$zipPath = "C:\Downloads\AURORA_Analyzer_v1.1.23.0_Release.zip"
Expand-Archive -Path $zipPath -DestinationPath "." -Force
```

#### 步骤 3: 恢复用户数据

```powershell
# 恢复用户日志
if (Test-Path "$backupDir\UserLogs") {
    Copy-Item -Path "$backupDir\UserLogs" -Destination ".\UserLogs" -Recurse
}

# 恢复会话缓存
if (Test-Path "$backupDir\SessionCache") {
    Copy-Item -Path "$backupDir\SessionCache" -Destination ".\SessionCache" -Recurse
}
```

### 方法 3: 使用构建脚本更新

适用于开发者或高级用户。

#### 步骤 1: 获取源代码

```powershell
# 如果使用 Git
git pull origin main
```

#### 步骤 2: 运行构建脚本

```powershell
# 进入项目目录
cd "E:\PC SOFT\优化软件\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory"

# 运行构建脚本
.\AURORA-build.bat /generate

# 或直接使用 PowerShell
.\build.ps1
```

#### 步骤 3: 输入密码

按照提示输入主密码（用于加密验证文件）。

#### 步骤 4: 选择版本选项

```
构建选项:
1. 使用当前版本构建
2. 递增版本号并构建

请选择：1
```

#### 步骤 5: 自动打包（可选）

```
Do you want to create a ZIP release package? (Y/N, default N)
N
```

---

## ✅ 更新后验证

### 1. 版本检查

```powershell
# 检查版本文件
Get-Content .\version.txt

# 应显示：1.1.23.0
```

### 2. 文件完整性检查

```powershell
# 检查必需文件是否存在
$requiredFiles = @(
    ".\AURORA.Launcher-双击启动.exe",
    ".\Scripts\AURORA-AnalyzerLauncherGUI.ps1",
    ".\Scripts\AURORA-AnalyzerPRO.ps1",
    ".\Scripts\AURORA-SmartEngine.ps1",
    ".\Scripts\AURORA-RestoreManager.ps1",      # 新增
    ".\Scripts\AURORA-RepairLogger.ps1",        # 新增
    ".\Scripts\AURORA-UndoManager.ps1",         # 新增
    ".\Scripts\AURORA-RepairTools.ps1",         # 新增
    ".\Scripts\AURORA-UndoViewer.ps1",          # 新增
    ".\Scripts\Core\AURORA-AnimationCoreEngine.ps1"  # 新增
)

$allExist = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file" -ForegroundColor Green
    } else {
        Write-Host "❌ $file (缺失)" -ForegroundColor Red
        $allExist = $false
    }
}

if ($allExist) {
    Write-Host "`n✅ 所有文件完整性检查通过" -ForegroundColor Green
} else {
    Write-Host "`n❌ 有文件缺失，请重新更新" -ForegroundColor Red
}
```

### 3. 功能测试

#### 测试 GUI 启动

```powershell
# 启动 GUI
.\AURORA.Launcher-双击启动.exe

# 检查是否正常启动
# 应看到主界面，无错误提示
```

#### 测试 Undo 功能

```powershell
# 导入 Undo 模块
.\Scripts\AURORA-UndoManager.ps1

# 初始化 Undo 管理器
Initialize-UndoManager

# 应显示:
# ✅ AURORA Undo 管理器初始化完成
#    备份目录：...\SessionCache\backup
```

#### 测试动画引擎

```powershell
# 导入动画引擎
.\Scripts\Core\AURORA-AnimationCoreEngine.ps1

# 检查类是否可用
[AuroraProgressBar]
[StarfieldPanel]
[AURORA_Animation]

# 应无错误
```

### 4. 性能基准测试

```powershell
# 测试知识图谱加载速度
Measure-Command {
    .\Scripts\AURORA-SmartEngine.ps1
}

# 缓存命中时应 < 1 秒
# 无缓存时应 < 3 秒
```

---

## 🔙 回滚指南

如果更新后遇到问题，可以按照以下步骤回滚。

### 方法 1: 使用系统还原点

**前提:** 更新前创建了系统还原点

#### 步骤:

1. 打开"系统属性"
2. 选择"系统保护"选项卡
3. 点击"系统还原"
4. 选择更新前创建的还原点
5. 按照向导完成还原

### 方法 2: 使用备份恢复

**前提:** 更新前备份了旧版本文件

#### 步骤:

```powershell
# 进入备份目录
cd ".\Backup_20260519_123456"

# 恢复旧版本文件
Copy-Item -Path ".\Scripts" -Destination "..\Scripts" -Recurse -Force
Copy-Item -Path ".\Data" -Destination "..\Data" -Recurse -Force
Copy-Item -Path ".\Resources" -Destination "..\Resources" -Recurse -Force

# 恢复根目录文件
Copy-Item -Path ".\AURORA.Launcher-双击启动.exe" -Destination "..\" -Force
Copy-Item -Path ".\GAURORA.CHK.ENC" -Destination "..\" -Force
```

### 方法 3: 重新安装旧版本

**前提:** 保留有旧版本的安装包

#### 步骤:

1. 完全卸载新版本
2. 安装旧版本（参考安装指南）
3. 恢复用户数据

---

## 📦 新增模块详解

### 1. AURORA-RestoreManager.ps1

**用途:** 系统还原点管理

**核心函数:**
```powershell
# 创建系统还原点
Create-SystemRestorePoint -Description "Before Repair"

# 查询还原点列表
Get-SystemRestorePoints

# 删除还原点
Remove-SystemRestorePoint -SequenceNumber 45

# 执行系统还原
Restore-System -SequenceNumber 45
```

**依赖:**
- 管理员权限
- WMI 访问权限
- 系统还原功能已启用

**使用示例:**
```powershell
# 导入模块
.\Scripts\AURORA-RestoreManager.ps1

# 创建还原点
$restorePoint = Create-SystemRestorePoint -Description "AURORA Test"

# 显示信息
Write-Host "还原点 ID: $($restorePoint.RestorePointId)"
Write-Host "序列号：$($restorePoint.SequenceNumber)"
```

### 2. AURORA-RepairLogger.ps1

**用途:** 修复会话日志记录

**核心函数:**
```powershell
# 开始修复会话
Start-RepairSession -RepairType "RegistryRepair" -Target "Windows Update"

# 记录命令执行
Log-RepairCommand -SessionId "RS_001" -Command "Set-ItemProperty" -Status "Success"

# 完成会话
Complete-RepairSession -SessionId "RS_001" -Status "Success"

# 查询会话
Get-RepairSession -SessionId "RS_001"
```

**日志格式:**
```json
{
  "SessionId": "RS_20260519_123456_789",
  "StartedAt": "2026-05-19T12:34:56",
  "RepairType": "RegistryRepair",
  "Target": "Windows Update",
  "Commands": [...],
  "Status": "Success",
  "CanUndo": true
}
```

### 3. AURORA-UndoManager.ps1

**用途:** 快速备份与还原

**核心函数:**
```powershell
# 初始化
Initialize-UndoManager

# 创建备份快照
Create-BackupSnapshot -Type "Registry" -Paths @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate")

# 还原备份
Restore-BackupSnapshot -SnapshotId "BS_20260519_123456_789"
```

**备份类型:**
- Registry: 注册表备份
- File: 文件备份
- Service: 服务配置备份
- Mixed: 混合备份

### 4. AURORA-RepairTools.ps1

**用途:** 修复工具入口

**功能:**
- 提供交互式修复菜单
- 集成 Undo 支持
- 批量修复操作

### 5. AURORA-UndoViewer.ps1

**用途:** Undo 管理器查看器

**功能:**
- 图形化显示备份历史
- 一键还原操作
- 详细信息查看

### 6. AURORA-AnimationCoreEngine.ps1

**用途:** 动画核心引擎

**核心类:**
- `AuroraProgressBar`: 进度条控件
- `StarfieldPanel`: 星空背景
- `TechButton`: 动态按钮
- `AURORA_Animation`: 动画管理器

**性能分级:**
```powershell
# Extreme (发烧级): 8 核 + 32G+
# Performance (性能级): 6 核 16G
# Balanced (均衡级): 4 核 8G
# Eco (节能级): 老旧设备
```

---

## ❓ 常见问题

### Q1: 更新后 GUI 无法启动

**可能原因:**
- 文件复制不完整
- .NET Framework 版本过低
- 密码验证失败

**解决方案:**
```powershell
# 1. 检查文件完整性
Test-Path ".\Scripts\AURORA-AnalyzerLauncherGUI.ps1"

# 2. 检查.NET Framework 版本
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" |
    Get-ItemPropertyValue -Name Release

# 要求：Release >= 378389 (.NET 4.5)

# 3. 重新构建（如需更改密码）
.\AURORA-build.bat /generate
```

### Q2: Undo 功能不可用

**可能原因:**
- 未以管理员身份运行
- 系统还原未启用
- 备份目录权限问题

**解决方案:**
```powershell
# 1. 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# 2. 启用系统还原
Enable-ComputerRestore -Drive "$env:SystemDrive"

# 3. 检查备份目录权限
$acl = Get-Acl ".\SessionCache\backup"
$acl.Access
```

### Q3: 知识图谱加载缓慢

**可能原因:**
- 缓存文件损坏
- KB 文件过大
- 磁盘性能问题

**解决方案:**
```powershell
# 1. 删除缓存文件（自动重建）
Remove-Item ".\Data\AURORA-TechData.cache.clixml" -Force

# 2. 重新启动 AURORA（自动重建缓存）

# 3. 检查磁盘性能
Get-Volume | Select-Object DriveLetter, SizeRemaining
```

### Q4: 动画效果卡顿

**可能原因:**
- 硬件性能不足
- 显卡驱动过旧
- DPI 缩放问题

**解决方案:**
```powershell
# 1. 检查性能分级
$perfScore = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors * 15 + 
             (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB * 5

Write-Host "性能评分：$perfScore"

# 2. 更新显卡驱动
# 访问显卡制造商官网下载最新驱动

# 3. 调整 DPI 缩放
# 系统设置 → 显示 → 缩放与布局
```

### Q5: 更新后旧日志丢失

**可能原因:**
- 更新时未备份
- 覆盖安装时误删

**解决方案:**
```powershell
# 1. 检查备份目录
Get-ChildItem ".\Backup_*" -Directory

# 2. 恢复日志文件
Copy-Item -Path ".\Backup_*\UserLogs" -Destination ".\UserLogs" -Recurse

# 3. 如无备份，尝试数据恢复软件
# 推荐：Recuva, EaseUS Data Recovery
```

---

## 📞 获取帮助

### 官方文档

- **完整文档:** `README_V1.1.23.0.md`
- **发行说明:** `README_V1.1.23.0_Release.md`
- **更新指南:** 本文档

### 技术支持

**遇到问题？**

1. 检查日志文件：
   ```powershell
   Get-Content ".\UserLogs\*.txt" -Tail 50
   ```

2. 运行诊断工具：
   ```powershell
   .\test\Test-Bilingual.ps1
   ```

3. 联系技术支持：
   - GitHub Issues: [待添加]
   - 电子邮件：[待添加]

### 社区资源

- PowerShell 社区论坛
- Windows 事件日志文档
- 系统还原技术文档

---

## 📝 更新日志摘要

### V1.1.23.0 变更

**新增:**
- ✅ Phase 4.2 Undo 支持系统（5 个模块）
- ✅ Phase 5 动画引擎解耦
- ✅ Minidump 自动解析
- ✅ 知识库缓存机制

**改进:**
- 🚀 性能优化（双索引预查找）
- 🛡️ 安全增强（前置检查 + 回滚）
- 🎨 界面美化（文件夹图标）
- 📦 构建优化（自动 ZIP 打包）

**修复:**
- 🐛 GUI 授权 CPU 占用问题
- 🐛 PRO 模式 CSV 读取错误
- 🐛 Undo 备份元数据问题

**已知问题:**
- ⚠️ 系统还原需要管理员权限
- ⚠️ Minidump 解析不支持完整转储
- ⚠️ 高 DPI 显示器可能模糊

---

**更新指南版本:** V1.1.23.0  
**最后更新:** 2026.05.19  
**作者:** AURORA VelociRaptor-GR Dev PRJ.

*祝您更新顺利！*
