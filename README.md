# AURORA Analyzer

> **Windows 事件日志导出与智能诊断分析工具**
>
> 版本：V1.6.30.1 Release · 技术栈：WPF + .NET Framework 4.x + C# 5 + PowerShell 5.1
>
> 作者：AURORA VelociRaptor-GR Dev PRJ.
>
> ⚠️ 本工具仅用于个人学习与研究。请遵守当地法律法规。

---

## 一、简介

AURORA Analyzer 是一款专为 Windows 平台设计的系统事件日志导出与智能诊断分析工具。它能够自动收集并导出十余种 Windows 事件日志（系统、应用程序、安全等），随后通过内置的、由知识图谱驱动的诊断引擎对日志进行深度分析，将看似毫无关联的事件串联成完整的因果关系链，最终告诉用户"到底发生了什么"以及"应该如何修复"。无论你是初次接触电脑的普通用户，还是经验丰富的系统管理员，AURORA Analyzer 都能以统一而优雅的方式为你提供强大、易用的诊断能力。

工具采用 WPF + .NET Framework 4.x 单进程架构，将原本散落在 PowerShell 脚本中的引擎逻辑、安全机制、UI 表现层完整迁移并重构为模块化的 C# 代码，同时保留与原 PowerShell 诊断引擎等价的运行能力。所有核心模块在启动时通过 RSA 签名验证完整性，运行时由反调试栈与文件完整性守护持续监控，确保工具自身不被篡改、不被逆向分析。

---

## 二、适用人群

本工具面向所有 Windows 用户。对于普通用户，AURORA Analyzer 提供开箱即用的"一键诊断 + 一键修复"流程，配合中英双语界面与图形化引导，无需任何命令行经验即可使用；对于进阶用户与系统管理员，PRO 专业模式提供完整的 17 阶段诊断流水线、多日志源对比、健康度评分与历史指纹匹配，并支持结构化修复菜单、撤销管理、系统还原点与导出归档等深度功能。无论使用场景是日常体检、故障排查还是事后归因，工具都能在不同深度上提供相应的支持。

---

## 三、核心特性概览

AURORA Analyzer 的核心能力可以归纳为五个方面。第一，**智能诊断**：内置丰富的知识图谱规则库，支持事件 ID 匹配、严重程度评分（1—10 分）与因果关系分析，将零散事件串联成因果链；同时提供历史指纹匹配，将当前日志与历史归档进行三层指纹对比，给出"是否曾经发生过类似问题"的判断与系统健康度评分。第二，**多维度扫描**：覆盖系统文件完整性、服务状态、注册表健康度、磁盘 I/O、内存与 CPU、网络配置、事件日志等多个维度。第三，**一键修复**：诊断完成后可自动执行修复，修复前自动创建系统还原点与快速备份快照，所有修复操作均可撤销并精确回滚到操作前状态。第四，**会话断点续传**：诊断与修复进度自动持久化，意外中断后可从中断点恢复，并向用户展示中断天数以辅助决策。第五，**安全机制**：从启动密码、RSA 签名哈希列表到 UAC 提权令牌，构成一条完整的信任链；运行时通过反调试栈、文件完整性守护与看门狗心跳持续自我保护。

此外，AURORA Analyzer 在历史分析与报告导出方面同样表现出色。历史界面提供智能化的"分析"按钮，根据用户选中的归档数量自动切换分析模式：未选中时显示禁用态，选中单条归档时切换为"时间线"模式展示该归档内部的事件时序分布，选中多条归档时切换为"趋势"模式展示跨归档的系统健康度演进趋势，按钮图标（放大镜/时钟/折线）随模式同步切换，无需用户手动判断应使用哪种视图。报告导出支持 HTML、Excel 等多种格式，格式选择对话框的选项卡片具备平滑的鼠标悬停渐变反馈，且整个导出链路（从主界面语言设置到报告生成器再到导出器）统一传递中英双语配置，确保导出报告的语言与主界面始终保持一致。

---

## 四、启动流程

启动 AURORA Analyzer 后，用户会经历一段精心设计的入场流程，每一步都兼顾安全验证与视觉体验。

**启动闪屏（SplashScreen）** 是用户看到的第一屏。它在深空星空背景上展示 AURORA Analyzer 标题、版本号与性能档位标签，并通过极光玻璃质感的进度条循环播放 8 段状态消息（初始化 → 加载诊断引擎 → 检测硬件配置 → 准备知识库 → 完成启动）。进度条以约 60 FPS 配合 easeOut 曲线推进，并根据性能档位（ECO、PERFORMANCE、EXTREME）自动调整启动时长乘数。

**启动密码验证** 紧随其后。工具会读取 `GAURORA.CHK.ENC` 文件，该文件以 base64 形式封装 16 字节 Salt、16 字节 IV 与密文，使用 PBKDF2-SHA256 进行 100,000 次迭代派生密钥，再以 AES-256-CBC + PKCS7 填充解密出核心模块的哈希列表。用户在 400×200 的玻璃密码对话框中输入启动密码，验证通过后才能进入主流程。该对话框会根据系统 CurrentUICulture 自动选择中英文显示，并给出友好的错误提示。

**UAC 提权对话框** 在用户以普通权限启动时弹出。它以一张 720 宽的卡片同时展示"普通模式"与"管理员模式"的功能差异，让用户清楚知道提权后能多执行哪些修复操作（如 SFC、DISM、注册表修复等）。用户可在三选项中选择：提权继续、普通继续或退出。若选择提权，工具会通过 `ElevationService` 以 `runas` 方式重启进程，并通过 `ElevationTokenService` 生成一个 60 秒有效的提权令牌文件（使用 PBKDF2 100,000 次 + AES-256-CBC 加密，文件 ACL 限制为仅当前用户可访问），新进程通过该令牌恢复信任链，避免重复输入密码。

**管理员路径前置视差（V1.5.29.1）** 在用户已具备管理员权限时启用。由于管理员路径会跳过 UAC 提权对话框，从 Splash 直接进入主窗体的视差跨度仅 0.15，星场运动量被退场/入场动画遮挡后会呈现"瞬移"观感。V1.5.29.1 采用前置视差方案：在启动 NavigateTo 之前，先让星场单独跑 500ms 冲到 0.30 深度，让用户清晰感知星场运动，然后再启动 Splash 退场与主窗体入场，星场运动分两段（0.0→0.30→0.15）平滑过渡。

完成以上三步后，工具进入主界面。

---

## 五、主界面与模式选择

主界面（MainFormView）采用两阶段状态机：先选择界面语言，再选择运行模式。

**语言选择阶段** 在视图顶部以大字号标题提示用户选择语言，下方提供 AuroraButton 列表，**中文优先、英文次之**（符合中文用户的使用习惯）。点击任一按钮即可在运行时无缝切换中英文，覆盖所有 UI 文本、诊断知识库字段、checkpoint 描述、HUD 步骤标签与对话框文案。

**模式选择阶段** 在选定语言后进入。工具提供两种工作模式：**PRO 专业模式** 与 **Smart 智能模式**。两种模式共享同一套底层诊断引擎与修复服务，但在交互形式与流程深度上有所差异，以满足不同用户群体的需要。界面左侧的信息面板会实时展示当前选中模式的简短说明，用户可随时通过返回按钮回退到上一阶段。

主窗口（MainWindow）作为统一壳层，承载星空背景控件、主视图宿主与权限指示器。右上角的 AuroraPrivilegeIndicator 以绿色盾牌（管理员）或橙色盾牌（普通用户）直观显示当前进程的权限级别，并附带中英双语标签。

---

## 六、PRO 专业模式

PRO 专业模式是面向进阶用户的完整诊断流水线，采用 5 行栅格布局：顶部标题区、控制台回显区（AuroraConsoleBox）、输入面板、进度区（AuroraProgressBar + AuroraTaskHUD）与模态层叠层。控制台与任务 HUD 左右并排，便于用户在观察实时日志的同时跟踪修复进度。

PRO 模式完整的诊断流程被划分为 **17 个 checkpoint 阶段**，每一步都有双语描述与进度百分比，并通过 `SessionCacheService` 持久化到磁盘，从而支持断点续传。这 17 个阶段依次为：启动、引擎初始化、日志类型选择、日期范围配置、性能档位评估、导出、处理开始、获取完整日志、完整日志就绪、高风险扫描完成、健康度评估完成、导出模式选择、导出开始、智能分析、生成报告、完成、失败。任何阶段中断（如系统断电、进程被杀、用户主动关闭），下次启动时都会通过 `SessionRestoreDialogView` 询问用户是"恢复"还是"重启"，并在卡片上展示 SessionId、当前进度、所处阶段、最近更新时间与已过天数，帮助用户决策。

PRO 模式底层通过 `PowerShellHostService` 在进程内运行 PowerShell RunspacePool（1—3 个 runspace），并使用 `Hashtable.Synchronized()` 创建跨 runspace 共享的 syncHash，包含 30+ 个默认键（如 IsHostAlive、IsRunning、LogOutput、Progress、UserInput、IsAdmin、会话恢复键、授权键、管道键等）。引擎通过 13 键轮询（50ms 间隔）持续读取 syncHash 状态，并通过 `DispatcherTimer`（50ms 节流）+ `ConcurrentQueue` 批量刷新控制台，避免高频日志导致 UI 线程阻塞。

PRO 模式还内置一个模态动作状态机，覆盖 Elevate（提权）、UserInput（用户输入）、SmartAnalysis（智能分析）、ShowUserLogs（展示日志）、Decision（用户决策）、SessionRestore（会话恢复）、ExportedLogs（已导出日志）等状态。ActionButton 具有三态：执行 / 停止 / 重试。当用户从 Smart 模式切换回 PRO 时，会通过 SuspendPolling / ResumePolling 进行握手，确保状态一致。

**模式切换轮询状态隔离（V1.5.29.1）** 修复了从智能模式返回主窗口再进入专业模式后控制台不回显、进度卡 50% 的问题。根因是 `StartSyncHashPolling` 漏了重置 `_pollingSuspended` 标志，导致轮询回调全部被跳过。V1.5.29.1 在 `StartSyncHashPolling` 开头重置该标志，确保每次启动轮询时标志干净。同时还修复了 ClearConsole 异步清空导致的"内容闪一下后消失"、AppendConsoleLine 跨线程 CollectionChanged 不传播、DispatcherTimer 被 Render 饿死等多个连带问题。

**Runspace 复用作用域保护（V1.5.29.1）** 修复了先运行专业模式终止后再运行智能模式时，智能引擎调用 LaunchGuard 函数触发 CommandNotFoundException 的问题。根因是 `SmartEngine.ps1` 直接调用 `Assert-AuroraLaunchContext` 而缺少 `Get-Command` 存在性检查（PRO-Engine 有此保护，SmartEngine 缺失），Runspace 复用场景下函数定义可能缺失。V1.5.29.1 对齐专业引擎的防御性调用方式，先检查函数是否存在再调用。同时还修复了智能引擎快速完成时进度概率性卡 50% 的采样时序问题——检测到完成信号时强制推进 Progress 到 100%，避免轮询采样时序导致的进度未收敛。

---

## 七、Smart 智能模式

Smart 智能模式是面向普通用户的轻量化修复入口，采用 3:2 主体分栏：左侧是 AuroraConsoleBox 回显区，右侧是结构化的 SmartMenuItems 菜单列表，底部是 TaskHUD 与 ExecuteStopButton。

与 PRO 模式通过控制台文本菜单交互不同，Smart 模式使用结构化的菜单项（`SmartMenuItem`），每项包含 Index、RuleId、RuleName、Name、RiskLevel、RequiresAdmin、AutoExecute、IsExecuted（已执行显示 ✓ 勾选）、IsExecuting 等字段。显示标签会自动附加风险等级（如 "(Low)"）、管理员标记（"[Admin]"）、授权标记（"[Auto]" 或 "[Auth]"），让用户在执行前清楚了解每项操作的影响范围与权限要求。

Smart 模式底层运行独立的 SmartEngine，通过 syncHash 轮询驱动。当用户点击"执行"按钮时，`SmartModeViewModel.ExecuteNextPendingItem` 会按顺序批量执行所有 `AutoExecute=true` 的待处理项；执行过程中通过 `SyncTaskStates` 实时同步 HUD 的 4 步骤状态。所有修复结果可通过 `ExportLog` 导出为 UTF-8 文本文件，便于用户保存或分享给技术人员查看。

---

## 八、诊断引擎

诊断引擎是 AURORA Analyzer 的核心智能所在，由两个互补的服务构成：**基于规则的知识库匹配** 与 **基于历史的指纹匹配**。

**知识库匹配（KnowledgeBaseService）** 加载位于 `Data/AURORA-TechData.json` 的诊断知识图谱（采用懒加载 + 缓存策略，支持 6 级目录搜索）。每条知识库规则（KnowledgeBaseRule）都包含双语字段：Name/NameEn、Description/DescriptionEn、Causes/CausesEn、Solutions/SolutionsEn、RecommendedAction/RecommendedActionEn，以及关联的事件 ID、来源、消息关键词、优先级与一组 KnowledgeBaseCommand（每个命令包含 Command、Type、Name、PreCheck、RollbackCommand、RiskLevel、ElevationRequired、AutoExecute 等字段）。匹配算法采用三层评分：强信号 = 规则 EventIds 与当前 EventIds 的交集（权重 0.5）、源匹配 = 规则 Sources 与当前 Sources 的双向 Contains（权重 0.2）、弱信号 = 规则 MessageKeywords 与当前 keywords 的交集（权重 0.3）。所有 matchScore > 0 的规则成为候选，按 matchScore × priority 降序排序后返回 Top 5。

**历史指纹匹配（HistoryMatchService）** 通过与 Get-WinEvent 同源的 `EventLogReader` API 读取实时事件日志，配合 XPath 时间过滤，动态计算扫描窗口（取用户设置的 DateRange 与默认 24 小时的最大值，上限 30 天 / 10000 事件）。它从当前日志中提取三层指纹：强信号为 EventId+Source 对键（权重 0.7），弱信号为从错误消息中提取的关键词（经过 60+ 停用词过滤，权重 0.3）。匹配阈值 MatchThreshold=0.7，最终得分 ComputeMatchScore = strongRate×0.7 + weakRate×0.3。同时为日志计算一个 SHA256 前 16 位的指纹哈希（取 top-5 强 + top-5 弱信号），用于跨次导出的指纹比对。

**系统健康度评分** 由两个服务共享同一公式：`健康度 = 100 - (critical×3 + error×2 + warning) × 100 / totalEvents`。健康等级划分为四档：≥90 优秀、≥70 良好、≥50 一般、<50 较差。这一评分既用于历史对比，也用于在导出归档中标注每次导出的系统状态。

---

## 九、修复工具集

AURORA Analyzer 提供完整的修复工具链，覆盖 Windows 系统的多个方面。所有修复操作在执行前都会通过 `RestoreService` 创建系统还原点（基于 WMI SystemRestore 类），并通过 `UndoManagerService` 创建快速备份快照（Registry / File / Service / Mixed 四种类型），确保所有操作可撤销、可回滚。

**直接 C# 实现的修复工具（RepairService）** 包括以下几类。**Windows 更新控制**：通过注册表 `SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU` 设置 NoAutoUpdate=1、AUOptions=1 来禁用自动更新。**Defender 防护**：通过注册表 `SOFTWARE\Policies\Microsoft\Windows Defender` 设置 DisableAntiSpyware=0 来启用 Defender。**遥测控制**：通过注册表 `SOFTWARE\Policies\Microsoft\Windows\DataCollection` 设置 AllowTelemetry=0 来关闭遥测。**网络重置**：通过 `netsh winsock reset` + `netsh int ip reset` + `ipconfig /flushdns` 重置网络栈。**系统临时文件清理**：清理 `Path.GetTempPath()` 目录。**SFC 系统文件修复**：调用 `sfc.exe /scannow`（10 分钟超时）。**Windows Store 缓存重置**：调用 `wsreset.exe`（60 秒超时）。**事件日志清理**：通过 `wevtutil cl` 清理 Application / System / Security 日志。**DNS 刷新**：通过 `ipconfig /flushdns`。

**知识库命令执行（FixExecutionService）** 负责执行诊断引擎匹配出的 KnowledgeBaseCommand。命令类型支持 cmd（通过 `cmd.exe /c` 执行）与 powershell（通过 `powershell.exe -NoProfile -NonInteractive -Command` 执行）两种。执行前会先评估 PreCheck（PowerShell 表达式，输出非空即视为通过）、检查 ElevationRequired、并根据 RiskLevel（High / Medium）给出警示。仅当 AutoExecute=true 时才会自动执行（保守模式），避免高风险操作被静默执行。执行失败时会自动调用 RollbackCommand 回滚（沿用原命令的 type，避免 PowerShell 语法被 cmd.exe 解析出错）。整个执行过程通过 `RepairService` 的 StartRepairSession / LogRepairCommand / CompleteRepairSession 进行会话记录，并通过 `ProModeViewModel.RecordRepairSession` 让 UndoViewer 后续可追溯。FixPhase 状态机覆盖 Starting / Executing / RolledBack / Completed / Skipped 五个阶段，并支持 IProgress<FixProgress> 与 CancellationToken，便于 UI 实时反馈与用户取消。

**执行窗口与回滚闭环加固（V1.6.30.1）** 对解决方案视图执行窗口进行了全面重构与完整性加固。执行窗口采用步骤时间线+日志双栏布局，左侧实时展示 FixPhase 状态机推进，右侧同步回显命令日志。失败处理支持 Abort / Continue / AskUser 三态选择，Continue 模式会先执行失败命令的 RollbackCommand 再跳过，避免脏状态连锁失败。进度预估基于已执行命令的平均耗时实时估算剩余时间。取消操作通过 Process.Kill 终止整个进程树，避免孤儿进程。EvaluatePreCheck 传入实际 CancellationToken，pre_check 期间取消有效。回滚闭环方面，CompleteRepairSession 实现终态保护（已是终态则不覆盖 Status/CanUndo），过期清理联动磁盘快照清理，启动时调用 CleanupExpiredSnapshots(7) 清理孤儿快照。UndoViewerViewModel.Refresh() 加载磁盘孤儿快照对账，撤销失败保留 CanUndo=true 可重试，撤销成功后手动触发 PropertyChanged 刷新 UI。

**系统还原点（RestoreService）** 基于 WMI SystemRestore 类实现。CreateRestorePoint 接受描述、还原点类型与事件类型参数，并按 RestorePointTypeName 完成映射（APPLICATION_INSTALL、MODIFY_SETTINGS、DEVICE_DRIVER_INSTALL 等）。还原点元数据以 JSON 形式保存到 SessionCache/restorepoints/ 目录。GetRestorePoints 会过滤出 AURORA 相关的还原点并按 SequenceNumber 降序排列，便于用户定位到本工具创建的还原点。TestCapability 会检查管理员权限、系统还原是否启用（注册表 RPSessionInterval）以及 WMI 是否可访问。

---

## 十、会话管理与撤销

AURORA Analyzer 的会话管理体系由三层互补的服务构成，确保任何诊断与修复操作都可中断、可恢复、可撤销。

**进度检查点（CheckpointConfig + SessionCacheService）** 为 PRO 模式定义了 17 阶段的 checkpoint 配置（双语）。每当引擎进入新阶段，`SaveProgress` 会调用 `SessionCacheService.SaveCheckpoint` 持久化当前进度，并支持附加 additionalData 字典（JSON 持久化）。`SessionCacheService` 的目录结构分为 active/（活跃会话）、checkpoints/（检查点归档）与 archive/（已归档会话）三部分。.progress 文件以键值对形式保存 SessionId、Stage、Progress、LastUpdated。会话 7 天后自动过期归档。所有写入采用原子操作（File.Replace + .tmp + .bak），避免写入过程中崩溃导致文件损坏。缓存根目录优先解析到 Tools/Temp，回退到系统 TEMP 目录。

**撤销管理器（UndoManagerService）** 负责创建与还原快速备份快照。CreateBackupSnapshot 会在 `BS_yyyyMMdd_HHmmss_xxx` 目录中创建快照。备份类型支持 Registry（通过 `reg.exe export` 备份、`reg.exe import` 还原）、File（通过 File.Copy 备份与还原）、Service（通过 `sc.exe qc` dump 服务配置到 JSON、通过 `sc.exe config` 还原启动类型，ParseServiceStartType 负责将 sc.exe 输出映射到 auto/demand/disabled/boot/system）以及 Mixed（混合型）。TestBackupIntegrity 会验证备份文件是否完整存在。RestoreBackupSnapshot 一次性还原所有备份项。所有 JSON 序列化采用手动实现（JsonEscape / JsonUnescape / JsonExtractString），避免依赖外部库。

**撤销查看器（UndoViewerView + UndoViewerViewModel）** 以 720×500 的玻璃对话框形式展示历史会话。左侧 ListView 列出所有 RepairSessionInfo（通过 `RepairService.GetAllSessions()` 获取），右侧详情面板展示选中会话的命令日志。顶部统计区显示总会话数、成功数、失败数与已撤销数。命令包括刷新、撤销（调用 `UndoManagerService.RestoreBackupSnapshot`）、清理（删除过期会话）与查看详情。

---

## 十一、导出与历史

AURORA Analyzer 的导出能力不仅限于"把日志写到文件"，还包括一套完整的归档与历史对比机制。

**导出格式** 主要为 JSON（包含完整的事件结构，便于后续分析），Smart 模式下还支持导出为 UTF-8 文本文件（便于用户阅读与分享）。底层 PowerShell 引擎通过 syncHash 控制的多日志合并机制支持 LogType 形如 "System+Application" 的多日志源合并导出。

**导出历史归档（ExportHistoryService）** 在每次分析完成后自动归档。归档结构为 `UserLogs/.history/{timestamp}/`，每个归档目录独立存放一份 `.metadata.json`（无需全局索引，便于跨机器迁移）。归档过程采用快照 diff 机制：分析前先 SnapshotFiles 记录所有现有文件名与 LastWriteTime，分析完成后 ArchiveExport 对比快照，文件名新增或 LastWriteTime 变新即视为本次导出文件（崩溃日志 CrashLog_*.log 不纳入归档）。每个归档计算三层指纹：强信号为 Top 10 的 EventId+Source 对（按出现频率排序，权重 100）、弱信号为 Top 10 的错误关键词（经过 60+ 停用词过滤，权重 10）、Context 包含健康度评分与 critical/error/warning 计数。指纹哈希取 SHA256 前 16 位（top-5 强 + top-5 弱），用于跨次导出的快速比对。LoadUnarchivedHistory 还会回退扫描 UserLogs 根目录下未归档的 JSON 文件，兼容历史版本生成的导出。

**导出历史查看器（ExportHistoryView + ExportHistoryViewModel）** 以列表 + 详情分栏的形式展示归档。列表项显示健康度圆点（优秀绿、良好蓝、一般黄、较差红）、日志类型与 C/E/W 计数标签（Critical/Error/Warning）。详情区展示完整的元数据、指纹卡与命令列表。可用命令包括刷新、检测当前（实时扫描 UserLogs 目录下未归档的文件）、删除（同时处理归档目录与未归档文件）、打开目录（在资源管理器中定位）与导出。所有视图过渡采用 UWP 淡出延迟提交模式，避免内容跳变。

**方案详情对话框（SolutionDetailView + SolutionDetailViewModel）** 用于展示诊断引擎匹配出的修复方案。对比区同时展示历史与当前的健康度、事件计数差异，让用户清楚看到问题是否恶化或缓解。方案列表显示所有匹配到的 KnowledgeBaseCommand，支持多选（CommandDisplayItem.IsSelected）批量执行。命令区显示 CloseCommand、ExecuteFixCommand 与 ExecuteSelectedFixCommand。该 ViewModel 包含 30+ 双语文本属性，所有过渡同样采用 UWP 淡出延迟提交模式（DetailExitRequested 事件 + CommitPendingSolution）。

---

## 十二、安全机制

AURORA Analyzer 在安全方面采用多层防护，构成一条从启动到运行时的完整信任链。

**三层令牌链** 为：启动密码 → RSA Token（哈希列表授权）→ Elevation Token（提权令牌）。三者均使用 PBKDF2-SHA256 100,000 次迭代派生密钥，再以 AES-256-CBC + PKCS7 填充加密，符合现代加密强度要求。**PasswordService** 读取 `GAURORA.CHK.ENC` 文件（base64 封装 Salt+IV+Cipher），VerifyPassword 返回解密的哈希列表。**RsaTokenService** 使用硬编码的 RSA 公钥 XML 验证 RSA-SHA256-PKCS1 签名（格式为 `{nonce}:{timestamp}:{hashPayload}`），DecryptHashListFromToken 从 nonce 派生 PBKDF2 密钥后用 AES-256-CBC 解密（IV = 负载前 16 字节）。**ElevationTokenService** 生成 60 秒有效的提权令牌（格式为 `{nonce}:{timestamp}:{base64(iv+cipher)}`，age < 60 且 age > -5 视为有效），文件 ACL 限制为仅当前用户可访问（SetAccessRuleProtection），使用完毕后通过 CleanupTokenFile 清理。

**完整性守护（IntegrityGuardService）** 维护一份包含 27+ 文件的 SHA256 哈希白名单（覆盖 Core engine、Security、PRO、Smart、Animation、UI Views、WPF 可执行文件、程序集、配置、XAML 等），启动时验证所有核心模块未被篡改。运行时通过三类 Timer 持续监控：Timer1 每 3 秒轮询文件完整性、Timer2 以 2—7 秒随机间隔扫描环境、WMI Win32_ProcessStartTrace 提供零延迟的进程启动通知（仅管理员可用）。一旦检测到异常，RecheckEngineIntegrity 会进行 10 秒去抖确认，RecheckCoreEngineFiles 针对 4 个最关键文件立即复核；若 ConfirmDetection 在 5 秒窗口内连续 2 次确认，则触发 AuroraExitCountdown 15 秒安全退出倒计时，避免与攻击者持续对抗。文件哈希计算采用 3 次 IO 重试，避免瞬时 IO 错误误判。

**反调试栈** 实现了 7 类检测。第一类调用 IsDebuggerPresent 检测本机调试器；第二类调用 CheckRemoteDebuggerPresent 检测远程调试器；第三类通过 NtQueryInformationProcess 查询 ProcessDebugPort(0x7)、ProcessHandleTracing(0x22)、ProcessDebugFlags(0x1F) 三个信息类；第四类检查 PEB.NtGlobalFlag 偏移（x86 为 0x68、x64 为 0xBC，调试标志 0x70）；第五类通过 GetThreadContext 检查 Dr0-Dr3 硬件断点寄存器（x86 读取 716 字节 CONTEXT、x64 读取 1232 字节）；第六类检测 DLL 注入（扫描非系统 DLL，命中 inject/detour/spy 等关键词即告警）；第七类扫描 30+ 已知调试器与逆向工具进程（windbg、x64dbg、ida、ollydbg、ghidra、radare2、dnspy、scylla、ilspy、processhacker、cheat engine 等）。此外，HideThreadFromDebugger 通过 NtSetInformationThread(0x11) 向调试器隐藏敏感线程。

**提权流程（ElevationService）** 在用户选择提权时，先清理 6 个环境变量（AURORA_WD_PIPE、AURORA_WD_SESSION、AURORA_LAUNCHED_BY_EXE、AURORA_TOKEN_PATH、AURORA_EXE_VERIFIED、AURORA_HASH_PATH），停止 IntegrityGuardService 的运行时监控并等待 300ms 让其完成清理，然后通过 ProcessStartInfo（Verb="runas"、UseShellExecute=true）以管理员身份重启进程。命令行参数包括 --launched-by-exe、--skip-splash、--language（可选）与 --elevation-token-path。IsCurrentProcessElevased 通过 WindowsPrincipal.IsInRole(Administrator) 判断当前权限。

---

## 十三、性能自适应

AURORA Analyzer 会根据用户硬件配置自动选择最合适的性能档位，避免在低配机器上卡顿，也避免在高配机器上浪费性能。

**性能档位（AuroraRenderEngine.PerformanceTier）** 共有四档：**Eco（节能）** 在 30 FPS 下关闭所有特效（粒子、复杂光晕、扫光、路径阴影、流星、星空动画全关），适用于评分 < 115 的低配设备；**Balanced（均衡）** 在 60 FPS 下关闭粒子、复杂光晕、扫光与流星，仅保留路径阴影与星空动画，适用于评分 115—174 的中配设备；**Performance（性能）** 在 60 FPS 下开启粒子、扫光与流星，关闭复杂光晕，适用于评分 175—279 的高配设备；**Extreme（极致）** 在 60 FPS 下开启全部特效，适用于评分 ≥ 280 的旗舰设备。

**性能评分公式 v3** 为 `perfScore = (logicalCores × 20) + (ramGB × 10) + max(0, (baseClockMHz - 2000) / 100) + gpuScore`，其中 gpuScore 来自 MaterialCapabilities 的真实 GPU 探测（通过 D3D9Ex 设备创建 + WMI Win32_VideoController 查询），而非简单的显存阈值。NVIDIA/AMD 独显 + D3D9Ex + 4GB+ 显存得 80 分，Intel 集显 + D3D9Ex 得 25 分，D3D9Ex 不可用时仅 5—20 分。这种基于真实硬件能力的评分方式避免了"看起来很高级实则卡顿"的尴尬。

**性能诊断对话框（PerformanceDiagnosticsView）** 是一个 720×560 的诊断窗，展示完整的硬件信息（CPU、内存、GPU）、500ms 采样的实时 FPS、6 个可独立开关的动画选项（粒子、复杂光晕、扫光、路径阴影、流星、星空动画）与档位选择器。用户可手动覆盖自动检测的档位，所有改动即时同步到 AuroraRenderEngine。

**性能升级提示对话框（PerformanceUpgradeDialogView）** 仅对 Eco / Balanced 档用户弹出，是一个 580×460 的升级建议窗，展示目标档位信息与预期提升。对于低配机器，还会推荐使用控制台模式（即 Smart 智能模式）以获得更流畅的体验。Performance / Extreme 档用户不会看到此对话框。

**材质预设分级（MaterialStylePreset）** 自动按档位选择：Eco/Balanced 使用 AuroraFluentGlass（BlurRadius=5），Performance 使用 AuroraFluentGlassPerformance（BlurRadius=6、FresnelStrength=0.35、RimLightStrength=0.45），Extreme 使用 AuroraFluentGlassExtreme（BlurRadius=7、FresnelStrength=0.55、RimLightStrength=0.65）。背景捕获节流也按档位差异化：Eco=66ms（15fps）、Balanced=50ms（20fps）、Performance/Extreme=33ms（30fps），软件渲染（RenderCapability.Tier=0）时进一步回退到 100ms（10fps）。

**远程会话与虚拟机优化**：当 MaterialCapabilities 检测到 IsRemoteSession（RDP / VM 环境）时，会强制禁用 GPU 后端，回退到 RTB 软件模糊，避免在无 GPU 加速的远程会话中出现严重的渲染卡顿。

---

## 十四、视觉系统

AURORA Analyzer 的视觉系统是其最具辨识度的特性之一，所有渲染严格遵循 60 FPS 同步与零分配热路径原则。

**星空背景（AuroraStarfield）** 是整个 UI 的视觉基底。星点数量按档位差异化：Eco=80、Balanced=180、Performance=350、Extreme=600。V1.5.29.1 将星点 Size 基础系数从 0.8 提升到 1.1（整体放大约 37%）、CurrentRenderSize 初始值从 0.55× 提升到 0.7×（入场即明显）、BaseAlpha 上限从 130 提升到 180（亮星比例提升），让纵深运动期间星点更醒目、更亮眼。背景包含 5 层极光幕（AuroraCurtain），每层有独立的 Y 位置、色相（Hue）与最大 Alpha：Layer 0 在 Y=0.12 处呈现绿色（Hue=140，MaxAlpha=145）、Layer 1 在 Y=0.28 处呈现青色（Hue=185，MaxAlpha=120）、Layer 2 在 Y=0.48 处呈现紫色（Hue=270，MaxAlpha=100）、Layer 3 在 Y=0.68 处呈现品红（Hue=320，MaxAlpha=85）、Layer 4 在 Y=0.85 处再次呈现绿色（Hue=160，MaxAlpha=70）。仅在 Performance / Extreme 档启用流星（Meteors）、4 角十字星芒（Diffraction）与极光 Bloom 辉光。鼠标移动会触发星座连线（Connections，30 帧节流）与鼠标光晕（GlowFactor）。

**多级深度视差系统（V1.5.29.0 重塑、V1.5.29.1 优化）** 将不同视图映射到 7 级深度：SplashScreen=0.00 → MainForm view1=0.15 → MainForm view2=0.30 → ProMode=0.50 → SmartMode=0.60 → 对话框组（ExportHistory=0.70 / UndoViewer=0.78 / ElevationDialog=0.82 / SessionRestore=0.86）→ SolutionDetail=0.95。V1.5.29.1 重新分配了 5 个对话框/详情视图的深度，消除同级视图零跨度切换，让每一次点击都有可见纵深反馈。切换视图时通过 UwpStandardEase 曲线平滑过渡 2700ms，避免突兀的层级跳跃。视差参数 push=0.30、scale=0.45、opacity=0.25，既保留扑面感又避免过激冲动，亮度从 V1.5.29.0 的 38% 回升到 75%。

**流星式光晕拖尾系统（V1.5.29.1 新增）** 在视差期间为近景星（Depth>0.6，约 150-200 颗）绘制 LinearGradientBrush 渐变光晕拖尾，强化运动方向感。拖尾长度由归一化速度驱动（`trailLen = (absoluteVelocity / parallaxSpan) × depth × 600`），无论跨度大小都能看到一致的拖尾峰值。拖尾方向适配 zoomOut/zoomIn：zoomOut 时尾巴指向中心（星星从中心来），zoomIn 时尾巴指向外（星星从外来）。EMA 指数移动平均（α=0.3）消除帧间隔抖动，软阈值过渡（0.0002~0.001 线性 0→1）消除拖尾出现/消失时的硬切闪烁。拖尾随速度衰减自然缩短（"缩进去"），视差结束立即消失，无残留闪烁。所有动画使用 CompositionTarget.Rendering 驱动（替代 DispatcherTimer），并使用正弦查找表（4096 条目 + 线性插值）与 Brush 缓存实现零分配热路径（视差期间拖尾的每星 new Brush GC 压力可接受，因视差仅 2.7 秒且已跳过光晕/星芒/星座连线等昂贵渲染）。

**极光玻璃材质（V5 材质管线）** 由 AuroraMaterialPipeline（全局单例，订阅 CompositionTarget.Rendering）+ AuroraMaterialComposer（弱引用列表，防内存泄漏）+ 15 个有序 IMaterialLayer 构成。15 层从下到上依次为：ShadowLayer（软投影，iOS 风径向渐变，Order=10）、BlurLayer（模糊背景，采样共享缓存，Order=20）、TintLayer（染色层，注入极光色 / 系统色 / 壁纸色，Order=50）、BodyLayer（玻璃主体，半透明渐变，Order=60）、NoiseLayer（微噪点纹理，Order=70）、FresnelLayer（菲涅尔边缘发光，Order=80）、SpecularLayer（镜面高光，跟踪鼠标位置，Order=90）、BevelLayer（斜面深度，3D 倒角错觉，Order=100）、EdgeHighlightLayer（边缘高亮，极光流动）、InnerGlowLayer（内辉光）、GlowLayer（外发光，hover 过渡，Order=130）、ChromaticLayer（色散，像素偏移）、RefractionLayer（折射扭曲）、CausticsLayer（焦散光斑，V1.4.29 新增）、IridescenceLayer（虹彩干涉，V1.4.29 新增）。管线还实现鼠标位置注入（SpecularLayer 跟踪）、鼠标离开后 30 帧衰减停止重绘、Per-layer 渲染耗时诊断（LayerTiming[]）等特性。

**模糊后端** 提供 5 种实现：RtbBlurBackend（RenderTargetBitmap + BlurEffect，软件模糊，1/2 分辨率，作为通用回退）、ShaderEffectBackend（WPF ShaderEffect，HLSL PS 3.0）、DwmApi（DWM Acrylic Blur，Win10 17063+）、D3DCompiler（d3dcompiler_47.dll，HLSL 运行时编译）、AuroraBlurHlsl（HLSL 着色器源码）。AuroraGlassMaterial 作为 v4 静态辅助类，实现几何缓存（CombinedGeometry + PathGeometry 仅尺寸变化时重建）、共享噪点纹理（128×128，8% alpha，固定种子）、60fps overlay 刷新 + 30fps 模糊背景捕获（解耦，符合 project_memory 约束）、1/2 分辨率 RTB.Render（960×540 max，等效 radius=6）。

**UWP 标准动画系统** 提供完整的曲线族：UwpStandardEase（cubic-bezier(0.8, 0, 0.2, 1)）、UwpAccelEase（(0.7, 0, 1, 0.5)）、UwpDecelEase（(0.1, 0.9, 0.2, 1)）、UwpExpoOutEase（(0.16, 1.0, 0.3, 1.0)）、UwpDampedEase（3 段插值，3.5% 过冲）。AnimationHelper 提供 PlayUwpEnter（QuarticEase EaseOut，0→1 Scale + 0→1 Opacity + Y offset）、PlayUwpExit（3 阶段关键帧：弹性回拉 + 加速飞散 + 晚期淡出）、PlayMainWindowEnter（1.15→1.03→1.0 单调收敛 + 微过冲，660ms+1100ms SineEase）等方法，所有入场动效严格遵循 project_memory 约束：直接过冲到 1.15 后以 800ms 收敛到 1.0，所有退场动效从 1.0 放大到 1.15，Dialog RenderTransform 在代码中创建（非 XAML）以保证 PRO 模式下的可靠性，RenderTransformOrigin = (0.5, 0.5) 居中缩放。

**快速切换闪回修复（V1.5.29.1）** 针对 6 个 IAuroraStaggerView 视图（ProMode、SmartMode、ExportHistory、SolutionDetail、ElevationDialog、SessionRestore）统一引入 `_pendingEnterTimers` 跟踪列表。入场动画创建的 DispatcherTimer（per-tile 错峰、fallback 兜底、listDelay 列表项延迟）原本是 fire-and-forget，在退场动画启动后仍会触发并覆盖退场状态，导致控件闪现回原位。V1.5.29.1 在退场动画启动前统一调用 `CancelPendingEnterTimers()` 取消所有待触发的入场定时器，根除快速切换闪回问题。

**玻璃弹窗动画统一封装（V1.6.30.1）** 将 10 处重复实现的玻璃弹窗入场/退场动画统一迁移至 `GlassDialogAnimation` 工具类。入场动画为三通道 Scale 0.92→1.07→1.0（360ms CubicEase + 525ms QuarticEase 回弹）+ TranslateY 24→0 + Opacity 0→1；退场动画为蓄力 1.0→0.97（80ms QuadraticEase）→ 放大离开 0.97→1.15（720ms QuadraticEase）+ TranslateY 0→-16 + Opacity 1→0。工具类提供 `PlayGlassEnter`（overlay+contentBorder 入场）、`PlayGlassExit`（退场+onClosed 回调+兜底定时器）、`PlayWindowExit`（Window 级退场）三个公共方法，并通过 `onSafetyTimerCreated` 回调重载支持 ProModeView ModalOverlay 复用场景。动画时长常量集中管理（EnterScaleMs/EnterBounceMs/ExitWindupMs/ExitLeaveMs/ExitFadeMs/ExitSafetyMs），任何参数调整只需修改一处。

**自定义控件库** 包括 9 个核心控件。**AuroraButton** 是极光玻璃按钮，包含 Normal/Hover/Press/Disabled/Loading/Success/Failure 状态机、磁吸偏移（半径 135、强度 0.35、最大 17.5、平滑 0.08）、倾斜扫光（SkewTransform -20° + 渐变矩形，2400ms）、iOS Q弹释放反馈（600ms）、V1.5 液态玻璃 hover 离开果冻回弹（271ms）、涟漪（Lifetime 1.2s，easeOutCubic）、500ms 点击冷却 + 500ms 长按检测、极光环境色注入（按 Y 位置采样）、15+ 渲染层与键盘焦点光晕（3 层外光晕 + 2 层内辉光）。**AuroraConsoleBox** 是极光玻璃控制台回显框，集成 V5 材质管线（圆角 12、深度 0.5），实现批处理 UWP 滑动入场（_pendingLines 缓存 + 33ms 节流 flush，910ms 正常 / 560ms 流星压缩）、新行动效（DampedPushEase 位移 + SmoothEaseOut 透明度 + 顶部高亮线 + 外发光）、UWP 平滑滚动（910ms SmoothEaseOut 亚像素 _scrollFraction）、定制玻璃滚动条（轨道 + 拇指 + hover/drag 状态 + 外发光）、文字选择 + 右键菜单"复制所有终端日志" + Ctrl+C、FormattedText 缓存（稳态零分配）与形变采样冻结（IsSizeChangeFrozen）。**AuroraTaskHUD** 是任务状态 HUD，包含 4 步骤节点（环境侦测 / 风险评估 / 定向自动修复 / 验证修复结果）、TaskState 枚举（Pending / Running / Success / Error）、文本滑入动画与 V5 材质管线集成（圆角 12、深度 0.6）。**AuroraProgressBar** 是极光玻璃进度条，集成 V5 材质管线（圆角可配置、深度 0.6）、倾斜扫光、进度前缘光点与粒子系统（Performance/Extreme）。**AuroraTextBlock** 是极光文本块，实现文本切换动画（Idle→FadingOut→Waiting→FadingIn→Idle）与入场动画状态。**AuroraPrivilegeIndicator** 是权限指示器，管理员显示绿色盾牌 + 对勾、普通用户显示橙色盾牌，V5 材质管线集成（圆角 8、深度 0.6）。**AuroraFrostedGlassBorder** 是极光毛玻璃边框，继承 Border（XAML API 完全兼容），Depth DependencyProperty 控制 EffectiveBlurRadius = Preset.BlurRadius × (0.3 + Depth × 1.4)，UseV5Pipeline 开关可在 V5 管线与 v4 AuroraGlassMaterial 间切换。

---

## 十五、双语支持

AURORA Analyzer 实现完整的中英双语支持，由 `LanguageService` 统一管理。该服务通过 ResourceManager 加载 `AURORA.Wpf.Properties.Resources` 资源文件（zh-CN 为默认中文、en 为英文），CurrentLanguageName 返回 "CHS" / "ENG" 以兼容原 PowerShell 脚本约定。提供 SetChinese / SetEnglish / SetLanguage / GetString / Format / TryGetString / GetStringForCulture 等方法，运行时切换无需重启。

双语覆盖范围极为广泛，包括：所有 UI 文本（标题、描述、按钮、状态、错误提示）、KnowledgeBaseRule 的全部双语字段（Name/NameEn、Description/DescriptionEn、Causes/CausesEn、Solutions/SolutionsEn、RecommendedAction/RecommendedActionEn）、CheckpointConfig 的 17 阶段双语描述、AuroraTaskHUD 的 4 步骤双语标签、AuroraPrivilegeIndicator 的双语标签、ElevationDialog 的双语特性列表、SolutionDetailViewModel 的 30+ 双语文本属性。PasswordDialogViewModel 还会从 CurrentUICulture 自动检测语言，使第一次启动也能显示用户母语。主界面语言选择遵循"中文优先、英文次之"的顺序，符合中文用户的使用习惯。

---

## 十六、系统要求

| 项目 | 最低要求 | 推荐配置 |
|------|---------|---------|
| 操作系统 | Windows 10 1809+ | Windows 11 22H2+ |
| 处理器 | 双核 1.5 GHz | 四核 2.5 GHz+ |
| 内存 | 4 GB | 8 GB+ |
| 架构 | x64（必须） | x64 |
| .NET Framework | 4.x | 4.8 |
| PowerShell | 5.1 | 5.1 |

远程会话（RDP）与虚拟机环境会被自动识别并强制禁用 GPU 后端，回退到软件模糊，保证可用性。

---

## 十七、快速开始

最简单的方式是双击仓库根目录下的 `AURORA-AnalyzerWPF.exe`（WPF 版本）或 `AURORA-Analyzer.exe`（经典 PowerShell 版本）。程序启动后会依次完成启动密码验证、性能检测与（如需）UAC 提权，随后进入主界面。

如需从命令行启动，可使用以下方式：

```powershell
# WPF 版本
.\AURORA-AnalyzerWPF.exe

# 指定启动语言
.\AURORA-AnalyzerWPF.exe --language en-US

# 跳过启动闪屏
.\AURORA-AnalyzerWPF.exe --skip-splash
```

进入主界面后，首先选择界面语言（中文或英文），然后选择运行模式：普通用户推荐 **Smart 智能模式**（结构化菜单、批量修复、操作简单），进阶用户推荐 **PRO 专业模式**（17 阶段完整流水线、多日志源对比、深度分析）。两种模式都支持随时通过返回按钮回退到模式选择界面。

---

## 十八、项目结构

仓库采用清晰的模块化结构，主要目录如下：

| 目录 | 说明 |
|------|------|
| `AURORA.Wpf/` | WPF 版本主项目（MVVM + 单进程架构） |
| `AURORA.Wpf/Controls/` | 自定义控件库（AuroraButton、AuroraConsoleBox、AuroraStarfield 等 9 个控件） |
| `AURORA.Wpf/Materials/` | V5 材质管线（15 层 + 5 个模糊后端 + 4 套预设） |
| `AURORA.Wpf/Animation/` | 动画系统（UWP 缓动曲线族 + 自定义缓动） |
| `AURORA.Wpf/Services/` | 业务服务层（PowerShell 宿主、修复、诊断、安全、会话、导出、语言等 20+ 服务） |
| `AURORA.Wpf/ViewModels/` | MVVM 的 ViewModel 层 |
| `AURORA.Wpf/Views/` | 视图层（主界面、PRO、Smart、Splash、对话框等） |
| `AURORA.Wpf/Themes/` | 主题资源（AuroraTheme、Brushes、Animations、Styles、Templates） |
| `AURORA.Wpf/Infrastructure/` | 基础设施（转换器、ObservableObject、RelayCommand 等） |
| `Data/` | 诊断知识图谱 `AURORA-TechData.json` 与缓存 |
| `Docs/` | 架构文档、审计报告与历史 README |

---

## 十九、使用须知

本工具以"现状"（AS IS）提供，仅供个人学习与研究使用。使用前请阅读以下注意事项：

- 请勿将本工具用于任何未经授权的系统操作或违反当地法律法规的用途。系统修复操作可能对系统产生影响，执行前请备份重要数据。作者不对因使用本工具造成的任何直接或间接损失承担责任。
- 所有修复操作执行前都会自动创建系统还原点与快速备份快照，但仍建议用户在执行高风险操作（RiskLevel=High）前手动确认。所有操作可通过 UndoViewer 撤销，或通过 Windows 系统还原回滚。
- 导出的事件日志可能包含敏感信息（用户名、计算机名、应用程序路径等），请妥善保管，避免未授权泄露。
- 工具运行时会启动反调试与完整性守护。若用户安全软件（如杀毒软件）误报，可将本工具加入白名单；若用户为合法的逆向研究目的需要分析本工具，请通过正规渠道联系作者。
- 在远程会话（RDP）或虚拟机中运行时，工具会自动禁用 GPU 加速，视觉表现可能略有降级，但功能完全等价。

---

## 二十、致谢

感谢所有提供反馈、报告 Bug、提出功能建议的用户。每一条反馈都让 AURORA Analyzer 变得更好。

---

*AURORA VelociRaptor-GR Dev PRJ. · V1.6.30.1 Release*
