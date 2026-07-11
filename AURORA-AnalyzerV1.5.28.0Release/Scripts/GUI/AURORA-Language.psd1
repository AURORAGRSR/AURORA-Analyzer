# AURORA-Language.psd1
# 集中式双语资源文件 (CHS / ENG)
# 用于统一版 PRO 引擎
# 版本：V1.5.28.1Release | 构建时间：2026.07.11
# 作者：AURORA VelociRaptor-GR Dev PRJ.

@{
    CHS = @{
        # ==========================================
        # 启动检测 (Startup Detection)
        # ==========================================
        "Launcher_Required"           = "❌ 此脚本不能直接运行！";
        "Use_Launcher"                = "请使用以下方式启动：";
        "Method_1"                    = "双击运行 AURORA-Analyzer.exe";
        "Method_2"                    = "  2. 或运行 AURORA-AnalyzerLauncherGUI.ps1";
        "Closing_Soon"                = "程序将在 5 秒后自动关闭...";
        "Separator"                   = "========================================";
        
        # ==========================================
        # 权限请求 (Permission Request)
        # ==========================================
        "Admin_Title"                 = "🛡️ 权限请求";
        "Admin_Message"               = "检测到您需要导出安全日志 (Security)，这需要管理员权限。`n`n是否以管理员身份重新运行？";
        "Admin_Required"              = "⚠️ 安全日志 (Security) 需要管理员权限才能访问。";
        "Admin_Granted"               = "✅ 已获得管理员权限";
        "Admin_Denied"                = "⚠️ 用户拒绝提权，跳过 Security 日志导出";
        
        # ==========================================
        # 系统兼容性 (System Compatibility)
        # ==========================================
        "Compat_PSVersion"            = "❌ 本工具需要 PowerShell 5.0 或更高版本。";
        "Compat_PSUpgrade"            = "💡 建议：升级到 Windows 10 或安装 Windows Management Framework 5.1。";
        "Compat_OSVersion"            = "❌ 本工具需要 Windows Vista 或更高版本。";
        "Compat_OSUpgrade"            = "💡 建议：升级到 Windows 10 或 Windows 11。";
        "Compat_PressEnter"           = "按 Enter 键退出";
        
        # ==========================================
        # 会话恢复 (Session Recovery)
        # ==========================================
        "Session_Detected"            = "🔄 检测到未完成的会话";
        "Session_ID"                  = "会话 ID: {0}";
        "Session_SavedProgress"       = "已保存进度：{0}%";
        "Session_CurrentStage"        = "当前阶段：{0}";
        "Session_SavedAt"             = "保存时间：{0}";
        "Session_SuspendedDays"       = "已挂起天数：{0} 天";
        "Session_WaitingGUI"          = "⏳ 等待用户在 GUI 上做出选择...";
        "Session_GUIClosed"           = "GUI 已关闭，退出...";
        "Session_Timeout"             = "⚠️ 等待用户选择超时，假设重新开始...";
        "Session_syncHashInvalid"     = "⚠️ syncHash 无效，使用控制台模式";
        "Session_ConsoleRestart"      = "⚠️ 检测到未完成的会话，控制台模式下假设重新开始";
        "Session_UserRestart"         = "🔄 用户选择重新开始，清除会话...";
        "Session_UserResume"          = "✅ 用户选择恢复会话，继续执行...";
        "Session_ResumePrompt"        = "[会话恢复] 检测到未完成的会话";
        "Session_ResumeOption1"       = "  1) 恢复会话（从上次保存点继续）";
        "Session_ResumeOption2"       = "  2) 重新开始（放弃之前的进度）";
        "Session_LogScopeRestored"    = "   ✅ 已恢复日志范围数据 ({0} 个范围)";
        "Session_ExportChoiceRestored"= "   ✅ 已恢复导出模式选择: {0}";
        
        # ==========================================
        # 文件操作 (File Operations)
        # ==========================================
        "File_WriteSuccess"           = "文件写入成功";
        "File_WriteFail"              = "文件写入失败";
        "File_WriteFailMsg"           = "写入文件失败: {0}";
        "File_WriteMaxRetries"        = "写入文件失败: 已达到最大重试次数 ({0} 次)";
        "File_SafePath"               = "安全文件路径: {0}";
        
        # ==========================================
        # 性能优化 (Performance Optimization)
        # ==========================================
        "Perf_Level"                  = "性能等级: {0}";
        "Perf_Parallelism"            = "并行度: {0}";
        "Perf_ChunkSize"              = "分块大小: {0}";
        "Perf_Compression"            = "是否压缩: {0}";
        "Perf_CacheSize"              = "缓存大小: {0}";
        "Perf_ExpiryMinutes"          = "过期时间: {0} 分钟";
        "Perf_BufferSize"             = "缓冲区大小: {0} 字节";
        "Perf_ParallelIO"             = "是否使用并行I/O: {0}";
        "Perf_WriteBatchSize"         = "写入批次大小: {0}";
        "Perf_AsyncWrite"             = "是否使用异步写入: {0}";
        "Perf_Score"                  = "系统性能分数: {0}/100";
        "Perf_Excellent"              = "系统性能优秀";
        "Perf_Good"                   = "系统性能良好";
        "Perf_Average"                = "系统性能一般";
        "Perf_DiskScore"              = "磁盘性能分数: {0}/50";
        "Perf_DiskModel"              = "磁盘: {0}";
        "Perf_DiskSize"               = "  大小: {0} GB";
        "Perf_DiskInterface"          = "  接口: {0}";
        "Perf_DiskSSD"                = "  是否SSD: {0}";
        "Perf_DiskAvgResponse"        = "平均响应时间: {0} 秒";
        "Perf_DiskReadSpeed"          = "读取速度: {0} 字节/秒";
        "Perf_DiskWriteSpeed"         = "写入速度: {0} 字节/秒";
        "Perf_CPU"                    = "处理器：{0} {1} 核心 @ {2} MHz (基础: {3} MHz)";
        "Perf_Memory"                 = "内存容量：{0} GB";
        "Perf_DiskConfig"             = "磁盘配置：{0} 个 SSD, {1} 个 HDD";
        "Perf_Calculating"            = "正在计算性能分数...";
        "Perf_YourScore"              = "您的性能分数为：{0}/100";
        "Perf_OptimalChunk"           = "最佳分块大小: {0} 小时/块";
        "Perf_UsingChunk"             = "使用最佳分块大小：{0} 小时/块";
        "Perf_UsingThreads"           = "根据系统负载使用 {0}/{1} 个线程";
        "Perf_MemoryAdjusted"         = "内存使用：{0}%，已调整分块大小以减少内存占用";
        "Perf_LoadAdjusted"           = "系统负载：{0}%，已调整分块大小以减少系统压力";
        "Perf_ResourceStrategy"       = "【资源优化策略】";
        "Perf_LogScanParallelism"     = "日志扫描并行度: {0}";
        "Perf_ReportParallelism"      = "报告生成并行度: {0}";
        "Perf_CacheCompression"       = "缓存压缩: {0}";
        "Perf_IOBuffer"               = "I/O 缓冲区大小：{0} bytes";
        "Perf_Evaluating"             = "【正在评估系统性能...】";
        "Perf_OptimalCacheSize"       = "最佳缓存大小: {0} 项";
        "Perf_OptimalParallelism"     = "最佳并行度: {0} 线程";
        "Perf_OptimalParallelismIO"   = "IO 任务最佳并行度: {0} 线程";
        "Perf_OptimalParallelismCPU"  = "CPU 任务最佳并行度: {0} 线程";
        "Perf_SystemLoad"             = "系统负载: {0}%";
        "Perf_SystemLoadHigh"         = "系统负载较高，建议降低并行度";
        
        # ==========================================
        # 缓存管理 (Cache Management)
        # ==========================================
        "Cache_Match"                 = "找到匹配的缓存数据";
        "Cache_NoMatch"               = "没有找到匹配的缓存数据";
        "Cache_Valid"                 = "缓存数据完整有效";
        "Cache_Invalid"               = "缓存数据无效或已损坏";
        "Cache_InitSuccess"           = "缓存初始化成功";
        "Cache_InitFail"              = "缓存初始化失败";
        "Cache_ForceInit"             = "缓存已强制重新初始化";
        "Cache_Key"                   = "缓存键: {0}";
        "Cache_GetData"               = "从缓存中获取到 {0} 条日志数据";
        "Cache_NoData"                = "缓存中没有找到数据或缓存已过期";
        "Cache_Getting"               = "从缓存中获取数据...";
        "Cache_Stored"                = "日志数据已存入缓存";
        "Cache_Compressed"            = "数据已压缩并存入缓存（压缩率：{0}%）...";
        "Cache_StoredSimple"          = "数据已存入缓存...";
        "Cache_CompressedLen"         = "压缩后数据长度: {0}";
        "Cache_Decompressed"          = "解压缩后数据: {0}";
        "Cache_Cleared"               = "日志缓存已清除";
        "Cache_ClearFail"             = "日志缓存清除失败";
        "Cache_ClearResult"           = "缓存已清除，清除前 {0} 项，清除后 {1} 项";
        "Cache_NotExist"              = "缓存不存在，无需清除";
        "Cache_ClearError"            = "清除缓存时出错: {0}";
        "Cache_UsingCache"            = "【使用缓存数据】";
        "Cache_NoMatchScanning"       = "【无匹配缓存，正在扫描所选范围内的高危事件...】";
        "Cache_Checking"              = "///正在检查缓存状态...///";
        "Cache_CheckDone"             = "///缓存状态检查完成!///";
        
        # ==========================================
        # 知识库 (Knowledge Base)
        # ==========================================
        "KB_LoadSuccess"              = "知识图谱加载成功";
        "KB_LoadFail"                 = "知识图谱加载失败";
        "KB_FileNotFound"             = "❌ 知识图谱文件未找到: {0}";
        "KB_LoadedCount"              = "✅ 知识图谱加载成功，包含 {0} 个分类";
        "KB_LoadError"                = "❌ 加载知识图谱时出错: {0}";
        "KB_IndexCreated"             = "知识图谱索引创建完成";
        "KB_IndexCreateSuccess"       = "✅ 知识图谱索引创建成功";
        "KB_IndexCreateError"         = "❌ 创建知识图谱索引时出错: {0}";
        "KB_SolutionsFound"           = "找到 {0} 个解决方案";
        "KB_SolutionName"             = "解决方案: {0}";
        "KB_SolutionPriority"         = "优先级: {0}";
        "KB_NoSolutions"              = "未找到解决方案";
        "KB_LocalizedSolution"        = "本地化解决方案: {0}";
        "KB_LocalizedCount"           = "找到 {0} 个本地化解决方案";
        "KB_EventPriority"            = "事件优先级: {0}";
        "KB_EventPriorityDetail"      = "事件 ID {0} 优先级: {1}";
        "KB_BatchProcessing"          = "[知识库分析] 正在批量处理 {0} 条事件的知识库查询...";
        "KB_BatchDone"                = "[知识库分析] 批量处理完成";
        
        # ==========================================
        # 内存/系统监控 (Memory/System Monitoring)
        # ==========================================
        "Mem_Usage"                   = "内存使用: {0}%";
        "Mem_Total"                   = "总内存: {0} MB";
        "Mem_Available"               = "可用内存: {0} MB";
        "Mem_Used"                    = "已用内存: {0} MB";
        "Mem_UsagePercent"            = "内存使用: {0}%";
        "Sys_ResMonitor"              = "[系统资源监控] 并行线程数: {0}, 内存使用率: {1}%";
        
        # ==========================================
        # 并行处理 (Parallel Processing)
        # ==========================================
        "Parallel_ArraySplit"         = "数组已分割成 {0} 个批次";
        "Parallel_BatchDetail"        = "批次 {0}: {1}";
        "Parallel_RunspaceCreated"    = "RunspacePool创建成功，线程数: {0}";
        "Parallel_TasksComplete"      = "并行任务执行完成，共完成 {0} 个任务";
        "Parallel_TPLInit"            = "[TPL并行处理] 初始线程数: {0}, 任务数: {1}";
        "Parallel_RunspaceClosed"     = "RunspacePool已成功关闭";
        "Parallel_RunspaceCloseFail"  = "RunspacePool关闭失败";
        "Parallel_CSVAccel"           = "使用并行处理加速CSV数据生成...";
        
        # ==========================================
        # 日志分析 (Log Analysis)
        # ==========================================
        "LogAnalysis_Complete"        = "分析完成，找到 {0} 个事件";
        "LogAnalysis_Patterns"        = "重复模式: {0} 个";
        "LogAnalysis_Anomalies"       = "异常: {0} 个";
        "LogAnalysis_TimePatterns"    = "时间模式: {0} 个";
        "LogAnalysis_Correlations"    = "关联分析: {0} 个";
        "LogAnalysis_Starting"        = "【正在执行高级日志模式分析...】";
        "LogAnalysis_FoundPatterns"   = "找到 {0} 个模式";
        "LogAnalysis_FoundAnomalies"  = "找到 {0} 个异常";
        "LogAnalysis_FoundCorrelations" = "找到 {0} 个关联";
        
        # ==========================================
        # 趋势分析 (Trend Analysis)
        # ==========================================
        "Trend_Complete"              = "日志趋势分析完成，报告已保存至 {0}";
        "Trend_ReportSaved"           = "趋势分析报告已保存至：{0}";
        "Trend_CSVSaved"              = "趋势数据已保存至：{0}";
        "Trend_CSVEmpty"              = "趋势数据为空，未生成CSV文件";
        "Trend_SaveFailed"            = "保存趋势报告失败：{0}";
        "Trend_SaveFailedHint"        = "建议：检查输出目录权限或磁盘空间。";
        "Trend_CompleteTitle"         = "【趋势分析完成】";
        
        # ==========================================
        # 日志访问 (Log Access)
        # ==========================================
        "LogAccess_Granted"           = "有权限访问系统日志";
        "LogAccess_Denied"            = "无权限访问系统日志";
        "LogAccess_SecurityDenied"    = "❌ 无权访问 {0} 事件日志。";
        "LogAccess_SecurityHint"      = '👉 Security日志需要管理员权限才能访问，请以"管理员身份运行"PowerShell，或选择其他日志类型。';
        "LogAccess_AdminHint"         = '👉 请以"管理员身份运行"PowerShell，或选择其他不需要管理员权限的日志类型。';
        "LogAccess_NotFound"          = "❌ 找不到 {0} 日志。";
        "LogAccess_Error"             = "❌ 访问 {0} 日志时出错：{1}";
        
        # ==========================================
        # 用户交互 - 日志类型选择 (User Interaction)
        # ==========================================
        "Prompt_LogType"              = "【请选择日志类型】";
        "Prompt_LogType_1"            = "1: System (系统)";
        "Prompt_LogType_2"            = "2: Application (应用程序)";
        "Prompt_LogType_3"            = "3: Security (安全) - 需要管理员权限";
        "Prompt_LogType_4"            = "4: Setup (安装) - 需要管理员权限";
        "Prompt_LogType_5"            = "5: DNS Server (DNS服务器) - 需要管理员权限";
        "Prompt_LogType_6"            = "6: DHCP Server (DHCP服务器) - 需要管理员权限";
        "Prompt_LogType_7"            = "7: Active Directory (活动目录) - 需要管理员权限";
        "Prompt_LogType_8"            = "8: IIS (Web服务器) - 需要管理员权限";
        "Prompt_MultiSelect"          = "💡 提示：可选择多个日志类型，用逗号或空格分隔（如：1,2 或 1 2）";
        "Prompt_NoSelection"          = "❌ 未选择任何有效的日志类型，请重新输入！";
        "Prompt_Selected"             = "✅ 已选择日志类型: {0}";
        "Prompt_TooManyErrors"        = "🛑 输入错误次数过多，程序即将退出...";
        "Prompt_LogTypeSelected"      = "选择的日志类型: {0}";
        "Prompt_StartTime"            = "开始时间: {0}";
        "Prompt_EndTime"              = "结束时间: {0}";
        "Prompt_ReportTitle"          = "报告标题: {0}";
        
        # ==========================================
        # 用户交互 - 导出模式 (Export Mode)
        # ==========================================
        "Prompt_ExportMode"           = "【请选择导出模式】";
        "Prompt_ExportMode_1"         = "1: 单日导出（例如：2026-01-21）";
        "Prompt_ExportMode_2"         = "2: 日期范围导出（起止日期，格式：YYYY-MM-DD）";
        "Prompt_DateFuture"           = "❌ 日期不能是未来日期！";
        "Prompt_DateFormat"           = "❌ 日期格式错误！请使用 YYYY-MM-DD 格式（例如：2026-01-21）。";
        "Prompt_DateRangeStartAfterEnd" = "⚠️ 起始日期不能晚于结束日期！";
        "Prompt_DateBothFormat"       = "❌ 日期格式错误！两个日期都必须是 YYYY-MM-DD 格式。";
        "Prompt_InvalidOption"        = "❌ 无效选项！请输入 1 或 2。";
        
        # ==========================================
        # 用户交互 - 事件过滤 (Event Filter)
        # ==========================================
        "Prompt_EventFilter"          = "【事件过滤选项】";
        "Prompt_EventFilter_1"        = "1: 无过滤（默认）";
        "Prompt_EventFilter_2"        = "2: 按事件 ID 过滤";
        "Prompt_EventFilter_3"        = "3: 按事件提供程序过滤";
        "Prompt_EventFilter_4"        = "4: 按事件级别过滤";
        "Prompt_EventLevel"           = "请选择事件级别：";
        "Prompt_EventLevel_1"         = "1: 严重 (Critical)";
        "Prompt_EventLevel_2"         = "2: 错误 (Error)";
        "Prompt_EventLevel_3"         = "3: 警告 (Warning)";
        "Prompt_EventLevel_4"         = "4: 信息 (Information)";
        "Prompt_EventLevel_5"         = "5: 详细 (Verbose)";
        
        # ==========================================
        # 进度显示 (Progress Display)
        # ==========================================
        "Progress_Activity"           = "[{0}]";
        "Progress_Status"             = "{0}";
        "Progress_Detail"             = "{0}";
        "Progress_Speed"              = "{0}";
        "Progress_Bar"                = "{0}";
        
        # ==========================================
        # 高危事件扫描 (High-Risk Event Scanning)
        # ==========================================
        "HighRisk_ScanComplete"       = "【高危事件扫描完成】共发现 {0} 条高危事件";
        "HighRisk_ForceRescan"        = "【强制重新扫描】跳过缓存，直接扫描事件...";
        "HighRisk_Scanning"           = "【正在扫描所选范围内的高危事件...】";
        "HighRisk_ScanError"          = "扫描过程中发生错误：{0}";
        
        # ==========================================
        # 完整日志读取 (Full Log Reading)
        # ==========================================
        "FullLog_ReadComplete"        = "【完整 {0} 日志读取完成】共采集 {1} 条事件";
        "FullLog_ReadFromCache"       = "【完整 {0} 日志读取完成】从高危事件缓存中获取数据，共采集 {1} 条事件";
        "FullLog_ReadError"           = "读取事件时出错: {0}";
        "FullLog_ReadWithErrors"      = "读取过程中遇到 {0} 个错误，但已尽力收集所有可用事件。";
        "FullLog_NoEvents"            = "⚠️ 未发现有效事件，无法生成报告。";
        
        # ==========================================
        # 报告生成 (Report Generation)
        # ==========================================
        "Report_SummarySaved"         = "摘要报告已保存至：{0}";
        "Report_CSVFail"              = "CSV导出失败";
        "Report_JSONFail"             = "导出JSON格式失败";
        "Report_Exported"             = "已导出:";
        "Report_CSVPath"              = "  CSV: {0}";
        "Report_JSONPath"             = "  JSON: {0}";
        "Report_XMLPath"              = "  XML: {0}";
        "Report_SaveFail"             = "保存失败: {0}";
        "Report_SaveFailHint"         = "请检查目录权限或磁盘空间。";
        
        # ==========================================
        # 启动横幅 (Banner)
        # ==========================================
        "Banner_Line1"                = "/// AURORA Analyzer Release Version ///";
        "Banner_Line2"                = "/// AURORA 2026 VelociRaptor-GR 版权所有 ///";
        "Banner_Line3"                = "/// Windows 系统事件日志导出与智能分析工具 ///";
        "Banner_Waiting"              = "///请稍后... 正在检测当前系统日期...///";
        "Banner_DateDetected"         = "📅 检测完成! 当前日期为: {0}///";
        
        # ==========================================
        # 输出目录 (Output Directory)
        # ==========================================
        "Output_InvalidPath"          = "❌ 无效的输出路径: {0}";
        "Output_InvalidPathHint"      = "💡 建议：使用有效的本地路径。";
        "Output_Created"              = "📁 已创建输出目录：{0}";
        "Output_NoPermission"         = "❌ 无权限访问输出目录：{0}";
        "Output_NoPermissionHint"     = "💡 建议：选择一个具有写入权限的目录。";
        "Output_ErrorDetail"          = "📝 错误详情：{0}";
        
        # ==========================================
        # 路径验证 (Path Validation)
        # ==========================================
        "Path_InvalidChar"            = "路径包含无效字符: {0}";
        "Path_TooLong"                = "路径长度超过Windows限制（260字符）";
        "Path_CreateDirFail"          = "无法创建输出目录: {0}";
        "Path_NotDir"                 = "指定的路径不是有效的目录";
        "Path_NoWrite"                = "无写入权限: {0}";
        "Path_AccessDenied"           = "无法访问目录";
        
        # ==========================================
        # 作用域恢复/验证 (Scope Recovery/Validation)
        # ==========================================
        "Scope_Restoring"             = "🔄 正在从会话恢复数据中重建任务范围...";
        "Scope_Restored"              = "   ✅ 成功恢复 {0} 个日志任务范围";
        "Scope_NoDataInSession"       = "   ⚠️ 会话数据中没有找到任务范围，将使用默认值";
        "Scope_FallbackHint"          = "💡 提示：您可以选择 System 或 Application 日志类型继续使用普通模式。";
        "Scope_Exiting"               = "   正在退出当前操作...";
        "Scope_Invalid"               = "⚠️ scopes 变量无效，正在使用默认值...";
        "Scope_SingleObject"          = "⚠️ 检测到 scopes 是单个对象，正在转换为数组...";
        "Scope_StillInvalid"          = "⚠️ scopes 仍然无效，正在使用默认值...";
        "Scope_StartTimeConverted"    = "⚠️ 已转换 scopes[{0}] 的 StartTime";
        "Scope_EndTimeConverted"      = "⚠️ 已转换 scopes[{0}] 的 EndTime";
        "Scope_StartTimeNull"         = "⚠️ scopes[{0}] 的 StartTime 为 null，已设置为今天";
        "Scope_EndTimeNull"           = "⚠️ scopes[{0}] 的 EndTime 为 null，已设置为今天结束";
        "Scope_LogTypeEmpty"          = "⚠️ scopes[{0}] 的 LogType 为空，已设置为默认值";
        "Scope_Validated"             = "✅ scopes 验证完成，共 {0} 个范围";
        
        # ==========================================
        # 并发模式 (Concurrent Mode)
        # ==========================================
        "Concurrent_Start"            = "🚀 Phase 3.4 并发优化：检测到多个日志类型，启用并发处理模式...";
        "Concurrent_LogCount"         = "   日志类型数量：{0}";
        "Concurrent_Speedup"          = "   预计加速比：{0}x";
        "Concurrent_MaxThreads"       = "   最大并发线程数：{0}";
        "Concurrent_Launching"        = "📦 正在启动并发任务...";
        "Concurrent_Merging"          = "📊 并发任务完成，正在合并结果...";
        "Concurrent_Done"             = "✅ 并发处理完成";
        "Concurrent_Skipped"          = "✅ 已跳过：{0}（已由并发任务处理）";
        
        # ==========================================
        # 断点续传 (Resume/Checkpoint)
        # ==========================================
        "Resume_ExportChoice"         = "💡 使用已恢复的导出选择：{0}";
        "Resume_PrevExportChoice"     = "💡 使用之前选择的导出模式：{0}";
        "Resume_ExportMode"           = "💡 使用已恢复的导出模式：{0}";
        "Resume_SkipScan"             = "✅ 跳过：高危事件扫描已完成（恢复进度 {0}% >= 60%）";
        "Resume_FromSession"          = "   从会话恢复：{0} 条高危事件（严重：{1}, 错误：{2}, 警告：{3}）";
        "Resume_SkipHealth"           = "✅ 跳过：系统健康评估已完成（恢复进度 {0}% >= 70%）";
        "Resume_HealthFromSession"    = "   从会话恢复：健康评分 {0}/100 | 等级：{1}";
        "Resume_SkipExport"           = "✅ 跳过：日志导出已完成（恢复进度 {0}% >= 85%）";
        "Resume_SkipTrend"            = "✅ 跳过：趋势分析已完成（恢复进度 {0}% >= 93%）";
        "Resume_SkipSmart"            = "✅ 跳过：智能分析已处理过（恢复进度 {0}% >= 95%）";
        
        # ==========================================
        # 处理进度 (Processing Progress)
        # ==========================================
        "Processing_Scope"            = "  [{0}/{1}] 正在处理：{2}";
        "Processing_ScanComplete"     = "【扫描完成】";
        "Processing_ScanResult"       = "发现：{0} 条严重事件，{1} 条错误，{2} 条警告（共 {3} 条高危事件）";
        "Processing_TotalLogs"        = "总日志数：{0} 条";
        
        # ==========================================
        # 健康评估 (Health Assessment)
        # ==========================================
        "Health_Assessment"           = "【系统健康评估】";
        "Health_Stats"                = "错误: {0} | 警告: {1} | 严重: {2}";
        "Health_Score"                = "健康评分: {0}/100 | 健康等级: {1}";
        "Health_Status"               = "{0}";
        
        # ==========================================
        # 导出决策 (Export Decision)
        # ==========================================
        "Export_NoHighRisk"           = "💡 未发现高危事件。";
        "Export_UserCancelled"        = "操作已被用户取消。";
        "Export_InvalidInput"         = "❌ 无效输入！请按 Enter 导出完整日志，或输入 'skip' 取消（剩余尝试次数：{0}）";
        "Export_TooManyErrors"        = "❌ 输入错误次数过多，默认导出完整日志。";
        "Export_InvalidInput2"        = "❌ 无效输入！请按 Enter 仅导出高危事件，或输入 '1' 导出完整日志（剩余尝试次数：{0}）";
        "Export_TooManyErrors2"       = "❌ 输入错误次数过多，默认仅导出高危事件。";
        "Export_Progress"             = "【正在导出：{0}】";
        "Export_InvalidTrendInput"    = "无效输入！请输入 Y 或 N（剩余尝试次数：{0}）";
        "Export_TooManyTrendErrors"   = "输入错误次数过多，跳过趋势分析。";
        
        # ==========================================
        # 智能分析 (Smart Analysis)
        # ==========================================
        "SmartAnalysis_Invoking"      = "🧠 正在调用 AURORA 智能诊断引擎...";
        "SmartAnalysis_Available"     = "  智能诊断分析可用";
        "SmartAnalysis_CSVDetected"   = "📊 已检测到导出的 CSV 文件：";
        "SmartAnalysis_Location"      = "   位置：{0}";
        "SmartAnalysis_CSVCount"      = "   文件：找到 {0} 个 CSV 文件";
        "SmartAnalysis_NoCSV"         = "   文件：未找到 CSV 文件";
        "SmartAnalysis_WillDo"        = "🔍 智能模式将执行：";
        "SmartAnalysis_Step1"         = "   ✓ 加载已导出的 CSV 文件";
        "SmartAnalysis_Step2"         = "   ✓ 知识库靶向碰撞分析";
        "SmartAnalysis_Step3"         = "   ✓ 提供自主修复方案";
        "SmartAnalysis_Confirm"       = "⚡ 是否立即启动智能诊断分析？";
        "SmartAnalysis_Waiting"       = "📋 正在等待用户确认...";
        "SmartAnalysis_GUIResponse"   = "✅ GUI 已响应智能分析请求（等待了 {0}ms）";
        "SmartAnalysis_GUITimeout"    = "⚠️ GUI 响应超时（等待了 30 秒），继续执行...";
        "SmartAnalysis_UserConfirmed" = "✅ 用户确认，开始智能分析...";
        "SmartAnalysis_UserSkipped"   = "⏭️ 用户跳过智能分析。";
        "SmartAnalysis_NonInteractive"= "⚠️ 检测到非交互式环境，自动启动智能分析...";
        "SmartAnalysis_Loading"       = "📖 正在加载智能引擎...";
        "SmartAnalysis_Complete"      = "✅ 智能诊断分析完成！";
        "SmartAnalysis_NoEngine"      = "⚠️ 未找到智能引擎文件，跳过智能分析。";
        "SmartAnalysis_ExpectedPath"  = "   预期路径：{0}";
        "SmartAnalysis_Skipped"       = "⏭️ 已跳过智能分析。";
        "SmartAnalysis_SkippedHint"   = "   如需分析，可手动运行 AURORA-SmartEngine.ps1";
        "SmartAnalysis_Error"         = "⚠️ 调用智能引擎失败：{0}";
        "SmartAnalysis_ErrorHint"     = "   不影响已导出的日志结果。";
        
        # ==========================================
        # 最终消息 (Final Messages)
        # ==========================================
        "Final_Complete"              = "✅ 操作完成！感谢使用本工具。";
        "Final_Error"                 = "❌ 发生错误：{0}";
        "Final_ErrorHint"             = '💡 建议：以"管理员身份运行"PowerShell 以获取完整日志权限。';
        "Final_PressEnter"            = "按 Enter 键退出";
        "Final_OpenFolder"            = "📂 正在打开输出文件夹...";
        
        # ==========================================
        # 日期选择 (Date Selection)
        # ==========================================
        "Date_Title"                  = "📅 日期选择";
        "Date_SingleDay_Prompt"       = "请选择要导出的日期：";
        "Date_Range_Start_Prompt"     = "请选择起始日期：";
        "Date_Range_End_Prompt"       = "请选择结束日期：";
        
        # ==========================================
        # 导出进度 (Export Progress)
        # ==========================================
        "Export_Start"                = "📤 开始导出日志...";
        "Export_InProgress"           = "   正在导出：{0}";
        "Export_Done"                 = "✅ 导出完成，共 {0} 条记录";
        "Export_Error"                = "❌ 导出失败：{0}";
        
        # ==========================================
        # 分析进度 (Analysis Progress)
        # ==========================================
        "Analyze_Start"               = "🧠 正在分析日志模式...";
        "Analyze_Level"               = "   分析级别：{0}";
        "Analyze_Done"                = "✅ 分析完成";
        
        # ==========================================
        # 报告生成 (Report Generation)
        # ==========================================
        "Report_Generating"           = "📄 正在生成报告...";
        "Report_Done"                 = "✅ 报告已保存至：{0}";
        "Report_Open"                 = "📂 正在打开报告文件夹...";
        
        # ==========================================
        # 错误消息 (Error Messages)
        # ==========================================
        "Error_LogType"               = "❌ 无效的日志类型：{0}";
        "Error_TimeRange"             = "❌ 时间范围无效，结束时间必须晚于开始时间";
        "Error_Permission"            = "❌ 权限不足：{0}";
        "Error_Notfound"              = "❌ 未找到日志：{0}";
        
        # ==========================================
        # PRO 模式 (PRO Mode)
        # ==========================================
        "PRO_Mode"                    = "🔧 PRO 模式：高级日志导出";
        "PRO_Scope_System"            = "系统日志 (System)";
        "PRO_Scope_Application"       = "应用程序日志 (Application)";
        "PRO_Scope_Security"          = "安全日志 (Security)";
        "PRO_Scope_Setup"             = "安装日志 (Setup)";
        "PRO_Scope_DNS"               = "DNS 服务器日志";
        "PRO_Scope_DHCP"              = "DHCP 服务器日志";
        "PRO_Scope_AD"                = "Active Directory 日志";
        "PRO_Scope_IIS"               = "IIS 服务器日志";
        
        # ==========================================
        # 智能引擎 (Smart Engine)
        # ==========================================
        "SmartEngine_Language"        = "CHS";
        "SmartEngine_Start"           = "🤖 正在启动 AURORA 智能诊断引擎...";
        "SmartEngine_Done"            = "✅ 智能诊断完成";
        
        # ==========================================
        # 进度管理器 (Progress Manager)
        # ==========================================
        "Checkpoint_Starting"         = "准备启动";
        "Checkpoint_Exporting"        = "正在导出日志";
        "Checkpoint_Analyzing"        = "正在分析模式";
        "Checkpoint_Reporting"        = "正在生成报告";
        "Checkpoint_Completed"        = "导出完成";
        "Checkpoint_Failed"           = "导出失败";
        
        # ==========================================
        # 文件名 (File Names)
        # ==========================================
        "FileName_Log"                = "{0}_日志_{1}";
        "FileName_Report"             = "{0}_报告_{1}";
        "LogType_System"              = "系统";
        "LogType_Application"         = "应用程序";
        "LogType_Security"            = "安全";
        "LogType_Setup"               = "安装";
        "LogType_DNS"                 = "DNS服务器";
        "LogType_DHCP"                = "DHCP服务器";
        "LogType_AD"                  = "活动目录";
        "LogType_IIS"                 = "Web服务器";
        
        # ==========================================
        # 缓存详情 (Cache Details)
        # ==========================================
        "Cache_Created"               = "创建时间: {0}";
        "Cache_DataCount"             = "数据数量: {0} 条事件";
        "Cache_OriginalSize"          = "原始大小: {0} MB";
        "Cache_CompressedSize"        = "压缩大小: {0} MB";
        "Cache_CompressionRatio"      = "压缩率: {0}%";
        "Cache_ExpiryTime"            = "缓存过期时间: {0}";
        "Cache_NotUsingCache"         = "不使用缓存数据，重新获取";
        "Cache_Info"                  = "【缓存信息】";
        "Cache_UsePrompt"             = "是否使用缓存数据？(Y/N) [默认: Y]";
        "Cache_InvalidInput"          = "❌ 无效输入！请输入 Y 或 N（剩余尝试次数：{0}）";
        "Cache_TooManyErrors"         = "❌ 输入错误次数过多，默认使用缓存。";
        
        # ==========================================
        # 趋势方向 (Trend Direction)
        # ==========================================
        "Trend_Up"                    = "上升";
        "Trend_Down"                  = "下降";
        "Trend_Stable"                = "稳定";
        "Trend_SignificantUp"         = "显著上升趋势";
        "Trend_SlightUp"              = "轻微上升趋势";
        "Trend_SignificantDown"       = "显著下降趋势";
        "Trend_SlightDown"            = "轻微下降趋势";
        "Trend_StableTrend"           = "稳定趋势";
        "Trend_Upward"                = "上升趋势";
        "Trend_Downward"              = "下降趋势";
        
        # ==========================================
        # 分析消息 (Analysis Messages)
        # ==========================================
        "Analysis_NoEvents"           = "没有事件可分析";
        "Analysis_InvalidStructure"   = "事件对象结构无效";
        "Analysis_Failed"             = "分析失败: {0}";
        
        # ==========================================
        # 严重级别 (Severity Levels)
        # ==========================================
        "Severity_Critical"           = "严重";
        "Severity_Error"              = "错误";
        "Severity_Warning"            = "警告";
        "Severity_Info"               = "信息";
        "Severity_Verbose"            = "详细";
        "Severity_AlwaysLog"          = "始终记录";
        "Severity_Unknown"            = "未知(Level={0})";
        
        # ==========================================
        # 健康等级 (Health Level)
        # ==========================================
        "Health_Excellent"            = "优秀";
        "Health_Good"                 = "良好";
        "Health_Fair"                 = "一般";
        "Health_Poor"                 = "较差";
        "Health_StatusExcellent"      = "系统状态：优秀 —— 运行稳定，无明显异常！";
        "Health_StatusGood"           = "系统状态：良好 —— 存在少量异常，建议定期检查！";
        "Health_StatusFair"           = "系统状态：一般 —— 存在较多异常，需要关注！";
        "Health_StatusPoor"           = "系统状态：较差 —— 存在大量异常，建议立即检查！";
        
        # ==========================================
        # 占位符 (Placeholders)
        # ==========================================
        "Placeholder_NoProvider"      = "<无提供程序信息>";
        "Placeholder_NoMessage"       = "<无消息内容>";
        "Placeholder_NoTime"          = "<无时间信息>";
        "Placeholder_NoLevel"         = "<无级别信息>";
        "Placeholder_Truncated"       = " [已截断]";
        
        # ==========================================
        # 通用 (Common)
        # ==========================================
        "Common_To"                   = "至";
        "Common_Items"                = "条";
        "Type_HighSeverity"           = "高严重性事件";
        "Type_HighFrequency"          = "高频率事件";
        
        # ==========================================
        # 进度消息 (Progress Messages)
        # ==========================================
        "Progress_CacheProcessing"    = "处理缓存";
        "Progress_ClearingMemory"     = "正在清理内存...";
        "Progress_MonitoringMemory"   = "正在监控内存使用... {0}%";
        "Progress_EvaluatingDataSize" = "正在评估数据大小... {0} 条事件";
        "Progress_AnalyzingDataSize"  = "正在分析数据大小...";
        "Progress_HighMemoryConservative" = "内存使用较高，采用保守处理策略...";
        "Progress_CompressingChunk"   = "正在压缩数据块 {0}/{1}";
        "Progress_CompressChunkTask"  = "压缩数据块 {0}";
        "Progress_CompressingData"    = "正在压缩数据...";
        "Progress_CalculatingCompression" = "正在计算压缩率...";
        "Progress_CompressionDone"    = "压缩完成，压缩率: {0}%";
        "Progress_CompressionFailed"  = "压缩失败，使用原始数据";
        "Progress_DirectStore"        = "数据较小或内存充足，直接存储";
        "Progress_StoringToCache"     = "正在存储到缓存...";
        "Progress_AdjustedCacheSize"  = "已根据内存使用情况调整缓存大小为 {0} 项";
        "Progress_HighMemoryCleared"  = "内存使用过高，已清理部分缓存，当前缓存项数：{0}";
        "Progress_CacheDone"          = "缓存处理完成！";
        "Progress_Initializing"       = "初始化...";
        "Progress_GettingTotalLogs"   = "正在获取总日志数...";
        "Progress_ScanStart"          = "初始化完成，开始扫描...";
        "Progress_ScannedChunks"      = "已扫描 {0}/{1} 块，发现 {2} 条高危事件";
        "Progress_ScannedAllChunks"   = "已扫描 {0}/{0} 块，发现 {1} 条高危事件";
        "Progress_GotTotalLogs"       = "已获取总日志数: {0}";
        "Progress_UsingTotalLogs"     = "使用已获取的总日志数: {0}";
        "Progress_DirectFetch"        = "正在直接获取所有事件...";
        "Progress_AnalyzingInterval"  = "正在分析 {0} 至 {1} 的日志";
        "Progress_AnalysisDone"       = "分析完成";
        "Progress_TasksDone"          = "已完成 {0}/{1} 个任务";
        "Progress_AllTasksDone"       = "已完成 {0}/{0} 个任务";
        "Progress_AnalyzingTrend"     = "分析日志趋势";
        "Progress_AnalyzeTimeSlot"    = "分析时间段 {0}";
        "Progress_ExecParallel"       = "执行并行任务";
        
        # ==========================================
        # 错误消息 (Error Messages)
        # ==========================================
        "Error_InputEmpty"            = "输入数据不能为空";
        "Error_CompressFail"          = "压缩数据时出错: {0}";
        "Error_InvalidBase64"         = "输入数据不是有效的Base64字符串";
        "Error_DecompressFail"        = "解压缩数据时出错: {0}";
        "Error_ThreadCountZero"       = "线程数必须大于0";
        "Error_RunspaceNotSupported"  = "当前PowerShell版本不支持RunspacePool";
        
        # ==========================================
        # 并行处理 (Parallel Processing)
        # ==========================================
        "Parallel_ThreadWarning"      = "线程数 {0} 超过推荐最大值 {1}，可能会影响性能";
        "Parallel_RunspaceCreateError"= "创建RunspacePool时出错: {0}";
        "Parallel_TaskError"          = "并行任务执行时出错: {0}";
        "Parallel_RunspaceCloseError" = "关闭RunspacePool时出错: {0}";
        
        # ==========================================
        # 时间 (Time)
        # ==========================================
        "Time_Minutes"                = "{0} 分钟";
        
        # ==========================================
        # 报告 (Report)
        # ==========================================
        "Report_ComputerName"         = "计算机名称";
        "Report_OS"                   = "操作系统";
        "Report_ExportTime"           = "导出时间";
        "Report_ToolVersion"          = "工具版本";
        "Report_Separator"            = "==================================================";
        "Report_TimeRangeTitle"       = "时间范围";
        "Report_TotalEvents"          = "总事件数";
        "Report_AdvancedAnalysis"     = "【高级模式分析摘要】";
        "Report_RepetitivePatterns"   = "重复模式";
        "Report_TimePatterns"         = "时间模式";
        "Report_DetectedAnomalies"    = "检测到的异常";
        "Report_LevelSummary"         = "【事件级别摘要】";
        "Report_TopEventIds"          = "【高频事件 ID（Top 10）】";
        "Report_TopProviders"         = "【主要事件提供程序（Top 10）】";
        "Report_FoundIssues"          = "【发现问题】";
        "Report_RecentErrors"         = "【最近 10 条错误事件】";
        "Report_KnowledgeBase"        = "【知识库解决方案】";
        "Report_KnowledgeBaseHint"    = "基于知识库的智能分析和解决方案推荐：";
        "Report_ErrorEvents"          = "错误事件";
        "Report_WarningEvents"        = "警告事件";
        "Report_CriticalEvents"       = "严重事件";
        "Report_HealthRating"         = "健康评分";
        "Report_HealthLevel"          = "健康等级";
        "Report_EventId"              = "事件ID";
        "Report_Source"               = "来源";
        "Report_Description"          = "描述";
        "Report_Time"                 = "时间";
        "Report_TimeRange"            = "时间段: {0} 至 {1}";
        "Report_CriticalCount"        = "  严重: {0} 条";
        "Report_ErrorCount"           = "  错误: {0} 条";
        "Report_WarningCount"         = "  警告: {0} 条";
        "Report_HealthScore"          = "  健康分数: {0}/100";
        "Report_TrendAnalysis"        = "【趋势分析】";
        "Report_AvgHealthScore"       = "平均健康分数: {0}/100";
        "Report_MaxHealthScore"       = "最高健康分数: {0}/100";
        "Report_MinHealthScore"       = "最低健康分数: {0}/100";
        "Report_TotalIssues"          = "总问题数: {0}";
        "Report_HealthTrend"          = "健康趋势: {0}";
        "Report_PredictedHealthScore" = "预测健康分数: {0}/100";
        "Report_AdviceGood"           = "【健康建议】系统状态良好，继续保持。";
        "Report_AdviceGoodDeclining"  = "虽然当前状态良好，但检测到下降趋势，建议关注系统变化。";
        "Report_AdviceAverage"        = "【健康建议】系统状态一般，建议定期检查。";
        "Report_AdviceAverageDeclining" = "检测到下降趋势，建议加强系统监控，及时处理潜在问题。";
        "Report_AdviceAverageImproving" = "检测到上升趋势，继续保持当前的维护策略。";
        "Report_AdvicePoor"           = "【健康建议】系统状态较差，建议立即检查。";
        "Report_AdvicePoorDeclining"  = "检测到严重下降趋势，建议立即进行系统诊断和维护。";
        
        # ==========================================
        # 报告标题模版 (Report Title Templates)
        # ==========================================
        "ReportTitle_Daily"           = "{0} 日志日报 - {1}";
        "ReportTitle_Range"           = "{0} 日志报告 - {1} 至 {2}";
        
        # ==========================================
        # 知识库 (Knowledge Base)
        # ==========================================
        "KB_Issue"                    = "问题";
        "KB_Severity"                 = "严重程度";
        "KB_Priority"                 = "优先级";
        "KB_Cause"                    = "原因";
        "KB_Solution"                 = "解决方案";
        "KB_Action"                   = "建议操作";
        "KB_Commands"                 = "建议执行命令";
        
        # ==========================================
        # 趋势报告头部 (Trend Report Header)
        # ==========================================
        "TrendReport_Title"           = "日志趋势分析报告";
        "TrendReport_ReportDate"      = "报告日期: {0}";
        "TrendReport_LogType"         = "日志类型: {0}";
        "TrendReport_AnalysisRange"   = "分析范围: {0} 至 {1}";
        "TrendReport_AnalysisDays"    = "分析天数: {0}";
        "TrendReport_AnalysisInterval" = "分析间隔: {0} 天";
        "TrendReport_Separator"       = "==================================================";
        "TrendReport_DailyStats"      = "【每日事件统计】";
        "TrendReport_FileNameTrend"   = "{0}_日志_{1}_趋势分析.txt";
        "TrendReport_FileNameCSV"     = "{0}_日志_{1}_趋势数据.csv";
        
        # ==========================================
        # 提示 (Prompt)
        # ==========================================
        "Prompt_Choose"               = "请选择 (1 或 2)";
        
        # ==========================================
        # 状态 (Status)
        # ==========================================
        "Status_TaskConfig"           = "任务配置";
        
        # ==========================================
        # 进度阶段 (Progress Stages)
        # ==========================================
        "Stage_ProcessingLog"         = "正在处理 {0} ({1}/{2})";
        "Stage_ScanComplete"          = "高危事件扫描完成，发现 {0} 条高危事件";
        "Stage_HealthComplete"        = "系统健康评估完成";
        "Stage_ExportModeSelected"    = "已选择导出模式：{0}";
        "Stage_FetchingLog"           = "正在获取完整 {0} 日志";
        "Stage_LogFetched"            = "已获取完整 {0} 日志，共 {1} 条事件";
        "Stage_Exporting"             = "正在导出：{0}";
        "Stage_AssessingPerformance"  = "正在评估系统性能与硬件资源...";
        
        # ==========================================
        # 报告生成进度 (Report Generation Progress)
        # ==========================================
        "ReportGen_Generating"        = "生成报告";
        "ReportGen_AnalyzingEvents"   = "正在分析事件数据 {0}/{1}";
        "ReportGen_SaveReport"        = "保存报告";
        "ReportGen_GeneratingCSV"     = "正在生成CSV数据 {0}/{1}";
        "ReportGen_GeneratingJSON"    = "正在生成JSON数据 {0}/{1}";
        "ReportGen_GeneratingXML"     = "正在生成XML数据 {0}/{1}";
        "ReportGen_ProcessingEvent"   = "处理事件 {0}";
        "ReportGen_CSVComplete"       = "CSV导出完成";
        "ReportGen_JSONComplete"      = "JSON导出完成";
        "ReportGen_XMLComplete"       = "XML导出完成";
        
        # ==========================================
        # 进度状态 (Progress Status)
        # ==========================================
        "Progress_Completion"         = "完成度: {0}%";
        "Progress_Environment"        = "{0}/4 环境准备与初始化";
        "Progress_EstimatedRemaining" = "预计剩余: {0}";
        
        # ==========================================
        # 导出完成状态 (Export Complete Status)
        # ==========================================
        "Report_CSVComplete_Status"   = "CSV导出完成";
        "Report_JSONComplete_Status"  = "JSON导出完成";
        "Report_XMLComplete_Status"   = "XML导出完成";
        
        # ==========================================
        # 扫描和评估状态 (Scan & Assessment Status)
        # ==========================================
        "Stage_ScanComplete_Detail"   = "高危事件扫描完成，发现 {0} 条高危事件";
        "Stage_HealthComplete_Detail" = "系统健康评估完成";
        "Stage_ExportModeSelected_Detail" = "已选择导出模式：{0}";
        "Stage_LogFetched_Detail"     = "已获取完整 {0} 日志，共 {1} 条事件";
        
        # ==========================================
        # 导出模式 (Export Modes)
        # ==========================================
        "ExportMode_HighRiskOnly"     = "仅高危事件";
        "ExportMode_FullLog"          = "完整 {0} 日志";
    }
    
    ENG = @{
        # ==========================================
        # Startup Detection
        # ==========================================
        "Launcher_Required"           = "❌ This script cannot run directly!";
        "Use_Launcher"                = "Please launch using:";
        "Method_1"                    = "  1. Double-click AURORA.Launcher.exe";
        "Method_2"                    = "  2. Or run AURORA-AnalyzerLauncherGUI.ps1";
        "Closing_Soon"                = "Exiting in 5 seconds...";
        "Separator"                   = "========================================";
        
        # ==========================================
        # Permission Request
        # ==========================================
        "Admin_Title"                 = "🛡️ Permission Request";
        "Admin_Message"               = "Security log export requires administrator privileges.`n`nDo you want to rerun as administrator?";
        "Admin_Required"              = "⚠️ Security log requires administrator privileges to access.";
        "Admin_Granted"               = "✅ Administrator privileges granted";
        "Admin_Denied"                = "⚠️ User declined elevation, skipping Security log export";
        
        # ==========================================
        # System Compatibility
        # ==========================================
        "Compat_PSVersion"            = "❌ This tool requires PowerShell 5.0 or higher.";
        "Compat_PSUpgrade"            = "💡 Recommendation: Upgrade to Windows 10 or install Windows Management Framework 5.1.";
        "Compat_OSVersion"            = "❌ This tool requires Windows Vista or higher.";
        "Compat_OSUpgrade"            = "💡 Recommendation: Upgrade to Windows 10 or Windows 11.";
        "Compat_PressEnter"           = "Press Enter to exit";
        
        # ==========================================
        # Session Recovery
        # ==========================================
        "Session_Detected"            = "🔄 Incomplete session detected";
        "Session_ID"                  = "Session ID: {0}";
        "Session_SavedProgress"       = "Saved progress: {0}%";
        "Session_CurrentStage"        = "Current stage: {0}";
        "Session_SavedAt"             = "Saved at: {0}";
        "Session_SuspendedDays"       = "Suspended for: {0} days";
        "Session_WaitingGUI"          = "⏳ Waiting for user to make a choice from GUI...";
        "Session_GUIClosed"           = "GUI closed, exiting...";
        "Session_Timeout"             = "⚠️ Timeout waiting for user choice, assuming restart...";
        "Session_syncHashInvalid"     = "⚠️ syncHash invalid, using console mode";
        "Session_ConsoleRestart"      = "⚠️ Detected incomplete session, assuming restart in console mode";
        "Session_UserRestart"         = "🔄 User chose to restart fresh, clearing session...";
        "Session_UserResume"          = "✅ User chose to restore session, continuing...";
        "Session_ResumePrompt"        = "[Session Recovery] Detected an incomplete session";
        "Session_ResumeOption1"       = "  1) Resume session (Continue from last save point)";
        "Session_ResumeOption2"       = "  2) Start fresh (Discard previous progress)";
        "Session_LogScopeRestored"    = "   ✅ Log scope data restored ({0} scopes)";
        "Session_ExportChoiceRestored"= "   ✅ Restored export mode choice: {0}";
        
        # ==========================================
        # File Operations
        # ==========================================
        "File_WriteSuccess"           = "File written successfully";
        "File_WriteFail"              = "Failed to write file";
        "File_WriteFailMsg"           = "Failed to write file: {0}";
        "File_WriteMaxRetries"        = "Failed to write file: Maximum retry attempts ({0}) reached";
        "File_SafePath"               = "Safe file path: {0}";
        
        # ==========================================
        # Performance Optimization
        # ==========================================
        "Perf_Level"                  = "Performance level: {0}";
        "Perf_Parallelism"            = "Parallelism: {0}";
        "Perf_ChunkSize"              = "Chunk size: {0}";
        "Perf_Compression"            = "Compression: {0}";
        "Perf_CacheSize"              = "Cache size: {0}";
        "Perf_ExpiryMinutes"          = "Expiry time: {0} minutes";
        "Perf_BufferSize"             = "Buffer size: {0} bytes";
        "Perf_ParallelIO"             = "Parallel I/O: {0}";
        "Perf_WriteBatchSize"         = "Write batch size: {0}";
        "Perf_AsyncWrite"             = "Async write: {0}";
        "Perf_Score"                  = "System performance score: {0}/100";
        "Perf_Excellent"              = "System performance: Excellent";
        "Perf_Good"                   = "System performance: Good";
        "Perf_Average"                = "System performance: Average";
        "Perf_DiskScore"              = "Disk performance score: {0}/50";
        "Perf_DiskModel"              = "Disk: {0}";
        "Perf_DiskSize"               = "  Size: {0} GB";
        "Perf_DiskInterface"          = "  Interface: {0}";
        "Perf_DiskSSD"                = "  SSD: {0}";
        "Perf_DiskAvgResponse"        = "Average response time: {0} sec";
        "Perf_DiskReadSpeed"          = "Read speed: {0} bytes/sec";
        "Perf_DiskWriteSpeed"         = "Write speed: {0} bytes/sec";
        "Perf_CPU"                    = "Processor: {0} {1} cores @ {2} MHz (Base: {3} MHz)";
        "Perf_Memory"                 = "Memory: {0} GB";
        "Perf_DiskConfig"             = "Disk configuration: {0} SSD(s), {1} HDD(s)";
        "Perf_Calculating"            = "Calculating performance score...";
        "Perf_YourScore"              = "Your performance score: {0}/100";
        "Perf_OptimalChunk"           = "Optimal chunk size: {0} hours";
        "Perf_UsingChunk"             = "Using optimal chunk size: {0} hours per chunk";
        "Perf_UsingThreads"           = "Using {0}/{1} threads based on system load";
        "Perf_MemoryAdjusted"         = "Memory usage: {0}%, adjusted chunk size to reduce memory usage";
        "Perf_LoadAdjusted"           = "System load: {0}%, adjusted chunk size to reduce system pressure";
        "Perf_ResourceStrategy"       = "[Resource Optimization Strategy]";
        "Perf_LogScanParallelism"     = "Log scan parallelism: {0}";
        "Perf_ReportParallelism"      = "Report generation parallelism: {0}";
        "Perf_CacheCompression"       = "Cache compression: {0}";
        "Perf_IOBuffer"               = "I/O buffer size: {0} bytes";
        "Perf_Evaluating"             = "[Evaluating system performance...]";
        "Perf_OptimalCacheSize"       = "Optimal cache size: {0} items";
        "Perf_OptimalParallelism"     = "Optimal parallelism: {0} threads";
        "Perf_OptimalParallelismIO"   = "Optimal parallelism for IO tasks: {0} threads";
        "Perf_OptimalParallelismCPU"  = "Optimal parallelism for CPU tasks: {0} threads";
        "Perf_SystemLoad"             = "System load: {0}%";
        "Perf_SystemLoadHigh"         = "System load is high, consider reducing parallelism";
        
        # ==========================================
        # Cache Management
        # ==========================================
        "Cache_Match"                 = "Cache match found! Using cached data.";
        "Cache_NoMatch"               = "No cache match found. Scanning logs...";
        "Cache_Valid"                 = "Cache data is valid";
        "Cache_Invalid"               = "Cache data is invalid, scanning fresh";
        "Cache_InitSuccess"           = "Cache initialized successfully";
        "Cache_InitFail"              = "Failed to initialize cache";
        "Cache_ForceInit"             = "Cache force reinitialized";
        "Cache_Key"                   = "Cache key: {0}";
        "Cache_GetData"               = "Found cached data with {0} events";
        "Cache_NoData"                = "No cached data found or cache expired";
        "Cache_Getting"               = "Getting data from cache...";
        "Cache_Stored"                = "Data cached successfully";
        "Cache_Compressed"            = "Data compressed and stored in cache (compression ratio: {0}%)...";
        "Cache_StoredSimple"          = "Data stored in cache...";
        "Cache_CompressedLen"         = "Compressed data length: {0} bytes";
        "Cache_Decompressed"          = "Decompressed data: {0}";
        "Cache_Cleared"               = "Cache cleared successfully";
        "Cache_ClearFail"             = "Failed to clear cache";
        "Cache_ClearResult"           = "Cache cleared, {0} items before, {1} items after";
        "Cache_NotExist"              = "Cache does not exist, no need to clear";
        "Cache_ClearError"            = "Error clearing cache: {0}";
        "Cache_UsingCache"            = "[Using cached data]";
        "Cache_NoMatchScanning"       = "[No cache match, scanning high-risk events in selected range...]";
        "Cache_Checking"              = "///Checking cache status...///";
        "Cache_CheckDone"             = "///Cache status check complete!///";
        
        # ==========================================
        # Knowledge Base
        # ==========================================
        "KB_LoadSuccess"              = "Knowledge base loaded successfully";
        "KB_LoadFail"                 = "Failed to load knowledge base";
        "KB_FileNotFound"             = "❌ Knowledge base file not found: {0}";
        "KB_LoadedCount"              = "✅ Knowledge base loaded successfully, contains {0} categories";
        "KB_LoadError"                = "❌ Error loading knowledge base: {0}";
        "KB_IndexCreated"             = "Knowledge base indexes created";
        "KB_IndexCreateSuccess"       = "✅ Knowledge base indexes created successfully";
        "KB_IndexCreateError"         = "❌ Error creating knowledge base indexes: {0}";
        "KB_SolutionsFound"           = "Found {0} solutions for event ID {1}";
        "KB_SolutionName"             = "Solution: {0}";
        "KB_SolutionPriority"         = "Priority: {0}";
        "KB_NoSolutions"              = "No solutions found for event ID {0}";
        "KB_LocalizedSolution"        = "Localized solution: {0}";
        "KB_LocalizedCount"           = "Localized {0} solutions";
        "KB_EventPriority"            = "Event priority: {0}/100";
        "KB_EventPriorityDetail"      = "Event ID {0}: Priority {1}/100";
        "KB_BatchProcessing"          = "[Knowledge Base Analysis] Batch processing knowledge base queries for {0} events...";
        "KB_BatchDone"                = "[Knowledge Base Analysis] Batch processing complete";
        
        # ==========================================
        # Memory/System Monitoring
        # ==========================================
        "Mem_Usage"                   = "Memory usage: {0}%";
        "Mem_Total"                   = "Total memory: {0} MB";
        "Mem_Available"               = "Free memory: {0} MB";
        "Mem_Used"                    = "Used memory: {0} MB";
        "Mem_UsagePercent"            = "Memory usage: {0}%";
        "Sys_ResMonitor"              = "[System Resource Monitor] Parallel threads: {0}, Memory usage: {1}%";
        
        # ==========================================
        # Parallel Processing
        # ==========================================
        "Parallel_ArraySplit"         = "Split into {0} batches";
        "Parallel_BatchDetail"        = "Batch {0}: {1}";
        "Parallel_RunspaceCreated"    = "RunspacePool created with {0} threads";
        "Parallel_TasksComplete"      = "Completed {0} tasks";
        "Parallel_TPLInit"            = "[TPL Parallel Processing] Initial threads: {0}, Tasks: {1}";
        "Parallel_RunspaceClosed"     = "RunspacePool closed successfully";
        "Parallel_RunspaceCloseFail"  = "Failed to close RunspacePool";
        "Parallel_CSVAccel"           = "Using parallel processing to accelerate CSV data generation...";
        
        # ==========================================
        # Log Analysis
        # ==========================================
        "LogAnalysis_Complete"        = "Analysis complete, found {0} events";
        "LogAnalysis_Patterns"        = "Repetitive patterns: {0}";
        "LogAnalysis_Anomalies"       = "Anomalies: {0}";
        "LogAnalysis_TimePatterns"    = "Time patterns: {0}";
        "LogAnalysis_Correlations"    = "Correlations: {0}";
        "LogAnalysis_Starting"        = "[Performing advanced log pattern analysis...]";
        "LogAnalysis_FoundPatterns"   = "Found {0} patterns";
        "LogAnalysis_FoundAnomalies"  = "Found {0} anomalies";
        "LogAnalysis_FoundCorrelations" = "Found {0} correlations";
        
        # ==========================================
        # Trend Analysis
        # ==========================================
        "Trend_Complete"              = "Trend analysis completed";
        "Trend_ReportSaved"           = "Trend analysis report saved to: {0}";
        "Trend_CSVSaved"              = "Trend data saved to: {0}";
        "Trend_CSVEmpty"              = "Trend data is empty, CSV file not generated";
        "Trend_SaveFailed"            = "Failed to save trend report: {0}";
        "Trend_SaveFailedHint"        = "Recommendation: Check output directory permissions or disk space.";
        "Trend_CompleteTitle"         = "[Trend Analysis Complete]";
        
        # ==========================================
        # Log Access
        # ==========================================
        "LogAccess_Granted"           = "Access to System log granted";
        "LogAccess_Denied"            = "Access to System log denied";
        "LogAccess_SecurityDenied"    = "❌ Access denied to {0} event log.";
        "LogAccess_SecurityHint"      = "👉 Security log requires admin privileges, please run PowerShell as Administrator, or select another log type.";
        "LogAccess_AdminHint"         = "👉 Please run PowerShell as Administrator, or select another log type that doesn't require admin privileges.";
        "LogAccess_NotFound"          = "❌ {0} log not found.";
        "LogAccess_Error"             = "❌ Error accessing {0} log: {1}";
        
        # ==========================================
        # User Interaction - Log Type Selection
        # ==========================================
        "Prompt_LogType"              = "[Select Log Type]";
        "Prompt_LogType_1"            = "1: System";
        "Prompt_LogType_2"            = "2: Application";
        "Prompt_LogType_3"            = "3: Security - Requires Admin Privileges";
        "Prompt_LogType_4"            = "4: Setup - Requires Admin Privileges";
        "Prompt_LogType_5"            = "5: DNS Server - Requires Admin Privileges";
        "Prompt_LogType_6"            = "6: DHCP Server - Requires Admin Privileges";
        "Prompt_LogType_7"            = "7: Active Directory - Requires Admin Privileges";
        "Prompt_LogType_8"            = "8: IIS (Web Server) - Requires Admin Privileges";
        "Prompt_MultiSelect"          = "💡 Tip: You can select multiple log types, separated by commas or spaces (e.g., 1,2 or 1 2)";
        "Prompt_NoSelection"          = "❌ No valid log types selected. Please try again!";
        "Prompt_Selected"             = "✅ Selected log types: {0}";
        "Prompt_TooManyErrors"        = "🛑 Too many invalid attempts. Exiting...";
        "Prompt_LogTypeSelected"      = "Selected log type: {0}";
        "Prompt_StartTime"            = "Start time: {0}";
        "Prompt_EndTime"              = "End time: {0}";
        "Prompt_ReportTitle"          = "Report title: {0}";
        
        # ==========================================
        # User Interaction - Export Mode
        # ==========================================
        "Prompt_ExportMode"           = "[Select Export Mode]";
        "Prompt_ExportMode_1"         = "1: Single Day (e.g., 2026-01-21)";
        "Prompt_ExportMode_2"         = "2: Date Range (YYYY-MM-DD to YYYY-MM-DD)";
        "Prompt_DateFuture"           = "❌ Date cannot be in the future!";
        "Prompt_DateFormat"           = "❌ Invalid date format! Please use YYYY-MM-DD format (e.g., 2026-01-21).";
        "Prompt_DateRangeStartAfterEnd" = "⚠️ Start date cannot be later than end date!";
        "Prompt_DateBothFormat"       = "❌ Invalid date format! Both dates must be in YYYY-MM-DD format.";
        "Prompt_InvalidOption"        = "❌ Invalid option! Please enter 1 or 2.";
        
        # ==========================================
        # User Interaction - Event Filter
        # ==========================================
        "Prompt_EventFilter"          = "[Event Filter Options]";
        "Prompt_EventFilter_1"        = "1: No Filter (Default)";
        "Prompt_EventFilter_2"        = "2: Filter by Event ID";
        "Prompt_EventFilter_3"        = "3: Filter by Event Provider";
        "Prompt_EventFilter_4"        = "4: Filter by Event Level";
        "Prompt_EventLevel"           = "Select event level:";
        "Prompt_EventLevel_1"         = "1: Critical";
        "Prompt_EventLevel_2"         = "2: Error";
        "Prompt_EventLevel_3"         = "3: Warning";
        "Prompt_EventLevel_4"         = "4: Information";
        "Prompt_EventLevel_5"         = "5: Verbose";
        
        # ==========================================
        # Progress Display
        # ==========================================
        "Progress_Activity"           = "[{0}]";
        "Progress_Status"             = "{0}";
        "Progress_Detail"             = "{0}";
        "Progress_Speed"              = "{0}";
        "Progress_Bar"                = "{0}";
        
        # ==========================================
        # High-Risk Event Scanning
        # ==========================================
        "HighRisk_ScanComplete"       = "[High-Risk Event Scanning Complete] Found {0} high-risk events";
        "HighRisk_ForceRescan"        = "[Force Rescan] Skipping cache, scanning events directly...";
        "HighRisk_Scanning"           = "[Scanning high-risk events in selected range...]";
        "HighRisk_ScanError"          = "Error during scanning: {0}";
        
        # ==========================================
        # Full Log Reading
        # ==========================================
        "FullLog_ReadComplete"        = "[Full {0} Log Reading Complete] Collected {1} events";
        "FullLog_ReadFromCache"       = "[Full {0} Log Reading Complete] Got data from high-risk event cache, {1} events collected";
        "FullLog_ReadError"           = "Error reading events: {0}";
        "FullLog_ReadWithErrors"      = "Encountered {0} errors during reading, but collected all available events.";
        "FullLog_NoEvents"            = "⚠️ No valid events found, cannot generate report.";
        
        # ==========================================
        # Report Generation
        # ==========================================
        "Report_SummarySaved"         = "Summary report saved to: {0}";
        "Report_CSVFail"              = "CSV export failed";
        "Report_JSONFail"             = "JSON export failed";
        "Report_Exported"             = "Exported:";
        "Report_CSVPath"              = "  CSV: {0}";
        "Report_JSONPath"             = "  JSON: {0}";
        "Report_XMLPath"              = "  XML: {0}";
        "Report_SaveFail"             = "Save failed: {0}";
        "Report_SaveFailHint"         = "Please check directory permissions or disk space.";
        
        # ==========================================
        # Banner
        # ==========================================
        "Banner_Line1"                = "/// AURORA Analyzer Release Version ///";
        "Banner_Line2"                = "/// AURORA 2026 VelociRaptor-GR All Rights Reserved ///";
        "Banner_Line3"                = "/// Windows System Event Log Export & Intelligent Analysis Tool ///";
        "Banner_Waiting"              = "///Please wait... Detecting current system date...///";
        "Banner_DateDetected"         = "📅 Detection complete! Current date: {0}///";
        
        # ==========================================
        # Output Directory
        # ==========================================
        "Output_InvalidPath"          = "❌ Invalid output path: {0}";
        "Output_InvalidPathHint"      = "💡 Recommendation: Use a valid local path.";
        "Output_Created"              = "📁 Output directory created: {0}";
        "Output_NoPermission"         = "❌ No permission to access output directory: {0}";
        "Output_NoPermissionHint"     = "💡 Recommendation: Choose a directory with write permissions.";
        "Output_ErrorDetail"          = "📝 Error details: {0}";
        
        # ==========================================
        # Path Validation
        # ==========================================
        "Path_InvalidChar"            = "Path contains invalid character: {0}";
        "Path_TooLong"                = "Path exceeds Windows limit (260 characters)";
        "Path_CreateDirFail"          = "Cannot create output directory: {0}";
        "Path_NotDir"                 = "Specified path is not a valid directory";
        "Path_NoWrite"                = "No write permission: {0}";
        "Path_AccessDenied"           = "Cannot access directory";
        
        # ==========================================
        # Scope Recovery/Validation
        # ==========================================
        "Scope_Restoring"             = "🔄 Rebuilding task scopes from session recovery data...";
        "Scope_Restored"              = "   ✅ Successfully restored {0} log task scopes";
        "Scope_NoDataInSession"       = "   ⚠️ No task scopes found in session data, using defaults";
        "Scope_FallbackHint"          = "💡 Tip: You can select System or Application log types to continue in normal mode.";
        "Scope_Exiting"               = "   Exiting current operation...";
        "Scope_Invalid"               = "⚠️ scopes variable is invalid, using defaults...";
        "Scope_SingleObject"          = "⚠️ Detected scopes is a single object, converting to array...";
        "Scope_StillInvalid"          = "⚠️ scopes still invalid, using defaults...";
        "Scope_StartTimeConverted"    = "⚠️ Converted scopes[{0}] StartTime";
        "Scope_EndTimeConverted"      = "⚠️ Converted scopes[{0}] EndTime";
        "Scope_StartTimeNull"         = "⚠️ scopes[{0}] StartTime is null, set to today";
        "Scope_EndTimeNull"           = "⚠️ scopes[{0}] EndTime is null, set to end of today";
        "Scope_LogTypeEmpty"          = "⚠️ scopes[{0}] LogType is empty, set to default";
        "Scope_Validated"             = "✅ Scopes validated, {0} scopes total";
        
        # ==========================================
        # Concurrent Mode
        # ==========================================
        "Concurrent_Start"            = "🚀 Phase 3.4 Concurrent Optimization: Multiple log types detected, enabling concurrent processing mode...";
        "Concurrent_LogCount"         = "   Log type count: {0}";
        "Concurrent_Speedup"          = "   Estimated speedup: {0}x";
        "Concurrent_MaxThreads"       = "   Max concurrent threads: {0}";
        "Concurrent_Launching"        = "📦 Launching concurrent tasks...";
        "Concurrent_Merging"          = "📊 Concurrent tasks complete, merging results...";
        "Concurrent_Done"             = "✅ Concurrent processing complete";
        "Concurrent_Skipped"          = "✅ Skipped: {0} (already processed by concurrent task)";
        
        # ==========================================
        # Resume/Checkpoint
        # ==========================================
        "Resume_ExportChoice"         = "💡 Using restored export choice: {0}";
        "Resume_PrevExportChoice"     = "💡 Using previously selected export mode: {0}";
        "Resume_ExportMode"           = "💡 Using restored export mode: {0}";
        "Resume_SkipScan"             = "✅ Skipped: High-risk event scan already completed (restored progress {0}% >= 60%)";
        "Resume_FromSession"          = "   Restored from session: {0} high-risk events (Critical: {1}, Error: {2}, Warning: {3})";
        "Resume_SkipHealth"           = "✅ Skipped: System health assessment already completed (restored progress {0}% >= 70%)";
        "Resume_HealthFromSession"    = "   Restored from session: Health score {0}/100 | Level: {1}";
        "Resume_SkipExport"           = "✅ Skipped: Log export already completed (restored progress {0}% >= 85%)";
        "Resume_SkipTrend"            = "✅ Skipped: Trend analysis already completed (restored progress {0}% >= 93%)";
        "Resume_SkipSmart"            = "✅ Skipped: Smart analysis already processed (restored progress {0}% >= 95%)";
        
        # ==========================================
        # Processing Progress
        # ==========================================
        "Processing_Scope"            = "  [{0}/{1}] Processing: {2}";
        "Processing_ScanComplete"     = "[Scan Complete]";
        "Processing_ScanResult"       = "Found: {0} critical, {1} errors, {2} warnings ({3} high-risk events total)";
        "Processing_TotalLogs"        = "Total logs: {0}";
        
        # ==========================================
        # Health Assessment
        # ==========================================
        "Health_Assessment"           = "[System Health Assessment]";
        "Health_Stats"                = "Errors: {0} | Warnings: {1} | Critical: {2}";
        "Health_Score"                = "Health score: {0}/100 | Health level: {1}";
        "Health_Status"               = "{0}";
        
        # ==========================================
        # Export Decision
        # ==========================================
        "Export_NoHighRisk"           = "💡 No high-risk events found.";
        "Export_UserCancelled"        = "Operation cancelled by user.";
        "Export_InvalidInput"         = "❌ Invalid input! Press Enter to export full log, or type 'skip' to cancel (remaining attempts: {0})";
        "Export_TooManyErrors"        = "❌ Too many invalid attempts, defaulting to full log export.";
        "Export_InvalidInput2"        = "❌ Invalid input! Press Enter to export high-risk events only, or type '1' for full log (remaining attempts: {0})";
        "Export_TooManyErrors2"       = "❌ Too many invalid attempts, defaulting to high-risk events only.";
        "Export_Progress"             = "[Exporting: {0}]";
        "Export_InvalidTrendInput"    = "Invalid input! Please enter Y or N (remaining attempts: {0})";
        "Export_TooManyTrendErrors"   = "Too many invalid attempts, skipping trend analysis.";
        
        # ==========================================
        # Smart Analysis
        # ==========================================
        "SmartAnalysis_Invoking"      = "🧠 Invoking AURORA Smart Diagnostics Engine...";
        "SmartAnalysis_Available"     = "  Smart Diagnostics Analysis Available";
        "SmartAnalysis_CSVDetected"   = "📊 Detected exported CSV files:";
        "SmartAnalysis_Location"      = "   Location: {0}";
        "SmartAnalysis_CSVCount"      = "   Files: Found {0} CSV files";
        "SmartAnalysis_NoCSV"         = "   Files: No CSV files found";
        "SmartAnalysis_WillDo"        = "🔍 Smart mode will perform:";
        "SmartAnalysis_Step1"         = "   ✓ Load exported CSV files";
        "SmartAnalysis_Step2"         = "   ✓ Knowledge base targeted collision analysis";
        "SmartAnalysis_Step3"         = "   ✓ Provide autonomous repair solutions";
        "SmartAnalysis_Confirm"       = "⚡ Launch smart diagnostics analysis now?";
        "SmartAnalysis_Waiting"       = "📋 Waiting for user confirmation...";
        "SmartAnalysis_GUIResponse"   = "✅ GUI responded to smart analysis request (waited {0}ms)";
        "SmartAnalysis_GUITimeout"    = "⚠️ GUI response timeout (30 seconds), continuing...";
        "SmartAnalysis_UserConfirmed" = "✅ User confirmed, starting smart analysis...";
        "SmartAnalysis_UserSkipped"   = "⏭️ User skipped smart analysis.";
        "SmartAnalysis_NonInteractive"= "⚠️ Non-interactive environment detected, auto-starting smart analysis...";
        "SmartAnalysis_Loading"       = "📖 Loading smart engine...";
        "SmartAnalysis_Complete"      = "✅ Smart diagnostics analysis complete!";
        "SmartAnalysis_NoEngine"      = "⚠️ Smart engine file not found, skipping smart analysis.";
        "SmartAnalysis_ExpectedPath"  = "   Expected path: {0}";
        "SmartAnalysis_Skipped"       = "⏭️ Smart analysis skipped.";
        "SmartAnalysis_SkippedHint"   = "   To analyze, manually run AURORA-SmartEngine.ps1";
        "SmartAnalysis_Error"         = "⚠️ Failed to invoke smart engine: {0}";
        "SmartAnalysis_ErrorHint"     = "   Does not affect the exported log results.";
        
        # ==========================================
        # Final Messages
        # ==========================================
        "Final_Complete"              = "✅ Operation complete! Thank you for using this tool.";
        "Final_Error"                 = "❌ Error occurred: {0}";
        "Final_ErrorHint"             = "💡 Recommendation: Run PowerShell as Administrator to get full log permissions.";
        "Final_PressEnter"            = "Press Enter to exit";
        "Final_OpenFolder"            = "📂 Opening output folder...";
        
        # ==========================================
        # Date Selection
        # ==========================================
        "Date_Title"                  = "📅 Date Selection";
        "Date_SingleDay_Prompt"       = "Please select date to export:";
        "Date_Range_Start_Prompt"     = "Please select start date:";
        "Date_Range_End_Prompt"       = "Please select end date:";
        
        # ==========================================
        # Export Progress
        # ==========================================
        "Export_Start"                = "📤 Starting log export...";
        "Export_InProgress"           = "   Exporting: {0}";
        "Export_Done"                 = "✅ Export complete, {0} records total";
        "Export_Error"                = "❌ Export failed: {0}";
        
        # ==========================================
        # Analysis Progress
        # ==========================================
        "Analyze_Start"               = "🧠 Analyzing log patterns...";
        "Analyze_Level"               = "   Analysis level: {0}";
        "Analyze_Done"                = "✅ Analysis complete";
        
        # ==========================================
        # Report Generation
        # ==========================================
        "Report_Generating"           = "📄 Generating report...";
        "Report_Done"                 = "✅ Report saved to: {0}";
        "Report_Open"                 = "📂 Opening report folder...";
        
        # ==========================================
        # Error Messages
        # ==========================================
        "Error_LogType"               = "❌ Invalid log type: {0}";
        "Error_TimeRange"             = "❌ Invalid time range, end time must be later than start time";
        "Error_Permission"            = "❌ Insufficient permissions: {0}";
        "Error_Notfound"              = "❌ Log not found: {0}";
        
        # ==========================================
        # PRO Mode
        # ==========================================
        "PRO_Mode"                    = "🔧 PRO Mode: Advanced Log Export";
        "PRO_Scope_System"            = "System Log";
        "PRO_Scope_Application"       = "Application Log";
        "PRO_Scope_Security"          = "Security Log";
        "PRO_Scope_Setup"             = "Setup Log";
        "PRO_Scope_DNS"               = "DNS Server Log";
        "PRO_Scope_DHCP"              = "DHCP Server Log";
        "PRO_Scope_AD"                = "Active Directory Log";
        "PRO_Scope_IIS"               = "IIS Server Log";
        
        # ==========================================
        # Smart Engine
        # ==========================================
        "SmartEngine_Language"        = "ENG";
        "SmartEngine_Start"           = "🤖 Starting AURORA Smart Diagnostics Engine...";
        "SmartEngine_Done"            = "✅ Smart diagnostics complete";
        
        # ==========================================
        # Progress Manager
        # ==========================================
        "Checkpoint_Starting"         = "Preparing to start";
        "Checkpoint_Exporting"        = "Exporting logs";
        "Checkpoint_Analyzing"        = "Analyzing patterns";
        "Checkpoint_Reporting"        = "Generating report";
        "Checkpoint_Completed"        = "Export completed";
        "Checkpoint_Failed"           = "Export failed";
        
        # ==========================================
        # File Names
        # ==========================================
        "FileName_Log"                = "{0}_Log_{1}";
        "FileName_Report"             = "{0}_Report_{1}";
        "LogType_System"              = "System";
        "LogType_Application"         = "Application";
        "LogType_Security"            = "Security";
        "LogType_Setup"               = "Setup";
        "LogType_DNS"                 = "DNS_Server";
        "LogType_DHCP"                = "DHCP_Server";
        "LogType_AD"                  = "Active_Directory";
        "LogType_IIS"                 = "IIS";
        
        # ==========================================
        # Cache Details
        # ==========================================
        "Cache_Created"               = "Created: {0}";
        "Cache_DataCount"             = "Data count: {0} events";
        "Cache_OriginalSize"          = "Original size: {0} MB";
        "Cache_CompressedSize"        = "Compressed size: {0} MB";
        "Cache_CompressionRatio"      = "Compression ratio: {0}%";
        "Cache_ExpiryTime"            = "Cache expiry: {0}";
        "Cache_NotUsingCache"         = "Not using cached data, re-fetching";
        "Cache_Info"                  = "[Cache Information]";
        "Cache_UsePrompt"             = "Use cached data? (Y/N) [Default: Y]";
        "Cache_InvalidInput"          = "❌ Invalid input! Please enter Y or N (remaining attempts: {0})";
        "Cache_TooManyErrors"         = "❌ Too many invalid attempts, defaulting to use cache.";
        
        # ==========================================
        # Trend Direction
        # ==========================================
        "Trend_Up"                    = "Up";
        "Trend_Down"                  = "Down";
        "Trend_Stable"                = "Stable";
        "Trend_SignificantUp"         = "Significant upward trend";
        "Trend_SlightUp"              = "Slight upward trend";
        "Trend_SignificantDown"       = "Significant downward trend";
        "Trend_SlightDown"            = "Slight downward trend";
        "Trend_StableTrend"           = "Stable trend";
        "Trend_Upward"                = "Upward trend";
        "Trend_Downward"              = "Downward trend";
        
        # ==========================================
        # Analysis Messages
        # ==========================================
        "Analysis_NoEvents"           = "No events to analyze";
        "Analysis_InvalidStructure"   = "Invalid event object structure";
        "Analysis_Failed"             = "Analysis failed: {0}";
        
        # ==========================================
        # Severity Levels
        # ==========================================
        "Severity_Critical"           = "Critical";
        "Severity_Error"              = "Error";
        "Severity_Warning"            = "Warning";
        "Severity_Info"               = "Information";
        "Severity_Verbose"            = "Verbose";
        "Severity_AlwaysLog"          = "Always Log";
        "Severity_Unknown"            = "Unknown(Level={0})";
        
        # ==========================================
        # Health Level
        # ==========================================
        "Health_Excellent"            = "Excellent";
        "Health_Good"                 = "Good";
        "Health_Fair"                 = "Fair";
        "Health_Poor"                 = "Poor";
        "Health_StatusExcellent"      = "System Status: Excellent - Stable operation, no obvious anomalies!";
        "Health_StatusGood"           = "System Status: Good - Minor anomalies detected, recommend regular checks!";
        "Health_StatusFair"           = "System Status: Fair - Multiple anomalies detected, needs attention!";
        "Health_StatusPoor"           = "System Status: Poor - Numerous anomalies detected, recommend immediate inspection!";
        
        # ==========================================
        # Placeholders
        # ==========================================
        "Placeholder_NoProvider"      = "<No provider info>";
        "Placeholder_NoMessage"       = "<No message content>";
        "Placeholder_NoTime"          = "<No time info>";
        "Placeholder_NoLevel"         = "<No level info>";
        "Placeholder_Truncated"       = " [Truncated]";
        
        # ==========================================
        # Common
        # ==========================================
        "Common_To"                   = "to";
        "Common_Items"                = "items";
        "Type_HighSeverity"           = "High severity event";
        "Type_HighFrequency"          = "High frequency event";
        
        # ==========================================
        # Progress Messages
        # ==========================================
        "Progress_CacheProcessing"    = "Processing cache";
        "Progress_ClearingMemory"     = "Clearing memory...";
        "Progress_MonitoringMemory"   = "Monitoring memory usage... {0}%";
        "Progress_EvaluatingDataSize" = "Evaluating data size... {0} events";
        "Progress_AnalyzingDataSize"  = "Analyzing data size...";
        "Progress_HighMemoryConservative" = "High memory usage, using conservative strategy...";
        "Progress_CompressingChunk"   = "Compressing data chunk {0}/{1}";
        "Progress_CompressChunkTask"  = "Compress data chunk {0}";
        "Progress_CompressingData"    = "Compressing data...";
        "Progress_CalculatingCompression" = "Calculating compression ratio...";
        "Progress_CompressionDone"    = "Compression complete, ratio: {0}%";
        "Progress_CompressionFailed"  = "Compression failed, using original data";
        "Progress_DirectStore"        = "Data small or memory sufficient, storing directly";
        "Progress_StoringToCache"     = "Storing to cache...";
        "Progress_AdjustedCacheSize"  = "Adjusted cache size to {0} items based on memory usage";
        "Progress_HighMemoryCleared"  = "High memory usage, cleared partial cache, current items: {0}";
        "Progress_CacheDone"          = "Cache processing complete!";
        "Progress_Initializing"       = "Initializing...";
        "Progress_GettingTotalLogs"   = "Getting total log count...";
        "Progress_ScanStart"          = "Initialization complete, starting scan...";
        "Progress_ScannedChunks"      = "Scanned {0}/{1} chunks, found {2} high-risk events";
        "Progress_ScannedAllChunks"   = "Scanned {0}/{0} chunks, found {1} high-risk events";
        "Progress_GotTotalLogs"       = "Got total log count: {0}";
        "Progress_UsingTotalLogs"     = "Using obtained total log count: {0}";
        "Progress_DirectFetch"        = "Fetching all events directly...";
        "Progress_AnalyzingInterval"  = "Analyzing logs from {0} to {1}";
        "Progress_AnalysisDone"       = "Analysis complete";
        "Progress_TasksDone"          = "Completed {0}/{1} tasks";
        "Progress_AllTasksDone"       = "Completed {0}/{0} tasks";
        "Progress_AnalyzingTrend"     = "Analyzing log trends";
        "Progress_AnalyzeTimeSlot"    = "Analyzing time slot {0}";
        "Progress_ExecParallel"       = "Executing parallel tasks";
        
        # ==========================================
        # Error Messages
        # ==========================================
        "Error_InputEmpty"            = "Input data cannot be empty";
        "Error_CompressFail"          = "Compression failed: {0}";
        "Error_InvalidBase64"         = "Input data is not a valid Base64 string";
        "Error_DecompressFail"        = "Decompression failed: {0}";
        "Error_ThreadCountZero"       = "Thread count must be greater than 0";
        "Error_RunspaceNotSupported"  = "Current PowerShell version does not support RunspacePool";
        
        # ==========================================
        # Parallel Processing
        # ==========================================
        "Parallel_ThreadWarning"      = "Thread count {0} exceeds recommended max {1}, may affect performance";
        "Parallel_RunspaceCreateError"= "Error creating RunspacePool: {0}";
        "Parallel_TaskError"          = "Error executing parallel tasks: {0}";
        "Parallel_RunspaceCloseError" = "Error closing RunspacePool: {0}";
        
        # ==========================================
        # Time
        # ==========================================
        "Time_Minutes"                = "{0} minutes";
        
        # ==========================================
        # Report
        # ==========================================
        "Report_ComputerName"         = "Computer Name";
        "Report_OS"                   = "Operating System";
        "Report_ExportTime"           = "Export Time";
        "Report_ToolVersion"          = "Tool Version";
        "Report_Separator"            = "==================================================";
        "Report_TimeRangeTitle"       = "Time Range";
        "Report_TotalEvents"          = "Total Events";
        "Report_AdvancedAnalysis"     = "[Advanced Pattern Analysis Summary]";
        "Report_RepetitivePatterns"   = "Repetitive Patterns";
        "Report_TimePatterns"         = "Time Patterns";
        "Report_DetectedAnomalies"    = "Detected Anomalies";
        "Report_LevelSummary"         = "[Event Level Summary]";
        "Report_TopEventIds"          = "[Top 10 Event IDs]";
        "Report_TopProviders"         = "[Top 10 Event Providers]";
        "Report_FoundIssues"          = "[Issues Found]";
        "Report_RecentErrors"         = "[Last 10 Error Events]";
        "Report_KnowledgeBase"        = "[Knowledge Base Solutions]";
        "Report_KnowledgeBaseHint"    = "Intelligent analysis and solution recommendations based on knowledge base:";
        "Report_ErrorEvents"          = "Error Events";
        "Report_WarningEvents"        = "Warning Events";
        "Report_CriticalEvents"       = "Critical Events";
        "Report_HealthRating"         = "Health Score";
        "Report_HealthLevel"          = "Health Level";
        "Report_EventId"              = "Event ID";
        "Report_Source"               = "Source";
        "Report_Description"          = "Description";
        "Report_Time"                 = "Time";
        "Report_TimeRange"            = "Time range: {0} to {1}";
        "Report_CriticalCount"        = "  Critical: {0}";
        "Report_ErrorCount"           = "  Errors: {0}";
        "Report_WarningCount"         = "  Warnings: {0}";
        "Report_HealthScore"          = "  Health Score: {0}/100";
        "Report_TrendAnalysis"        = "[Trend Analysis]";
        "Report_AvgHealthScore"       = "Average Health Score: {0}/100";
        "Report_MaxHealthScore"       = "Max Health Score: {0}/100";
        "Report_MinHealthScore"       = "Min Health Score: {0}/100";
        "Report_TotalIssues"          = "Total Issues: {0}";
        "Report_HealthTrend"          = "Health Trend: {0}";
        "Report_PredictedHealthScore" = "Predicted Health Score: {0}/100";
        "Report_AdviceGood"           = "[Health Advice] System is in good condition, keep it up.";
        "Report_AdviceGoodDeclining"  = "Although currently good, a declining trend is detected, recommend monitoring system changes.";
        "Report_AdviceAverage"        = "[Health Advice] System is in average condition, recommend regular checks.";
        "Report_AdviceAverageDeclining" = "A declining trend is detected, recommend strengthening system monitoring and addressing issues promptly.";
        "Report_AdviceAverageImproving" = "An improving trend is detected, continue current maintenance strategy.";
        "Report_AdvicePoor"           = "[Health Advice] System is in poor condition, recommend immediate inspection.";
        "Report_AdvicePoorDeclining"  = "A severe declining trend is detected, recommend immediate system diagnostics and maintenance.";
        
        # ==========================================
        # Report Title Templates
        # ==========================================
        "ReportTitle_Daily"           = "{0} Log Daily Report - {1}";
        "ReportTitle_Range"           = "{0} Log Report - {1} to {2}";
        
        # ==========================================
        # Knowledge Base
        # ==========================================
        "KB_Issue"                    = "Issue";
        "KB_Severity"                 = "Severity";
        "KB_Priority"                 = "Priority";
        "KB_Cause"                    = "Cause";
        "KB_Solution"                 = "Solution";
        "KB_Action"                   = "Recommended Action";
        "KB_Commands"                 = "Recommended Commands";
        
        # ==========================================
        # Trend Report Header
        # ==========================================
        "TrendReport_Title"           = "Log Trend Analysis Report";
        "TrendReport_ReportDate"      = "Report Date: {0}";
        "TrendReport_LogType"         = "Log Type: {0}";
        "TrendReport_AnalysisRange"   = "Analysis Range: {0} to {1}";
        "TrendReport_AnalysisDays"    = "Analysis Days: {0}";
        "TrendReport_AnalysisInterval" = "Analysis Interval: {0} days";
        "TrendReport_Separator"       = "==================================================";
        "TrendReport_DailyStats"      = "[Daily Event Statistics]";
        "TrendReport_FileNameTrend"   = "{0}_Log_{1}_TrendAnalysis.txt";
        "TrendReport_FileNameCSV"     = "{0}_Log_{1}_TrendData.csv";
        
        # ==========================================
        # Prompt
        # ==========================================
        "Prompt_Choose"               = "Please choose (1 or 2)";
        
        # ==========================================
        # Status
        # ==========================================
        "Status_TaskConfig"           = "Task Configuration";
        
        # ==========================================
        # Progress Stages
        # ==========================================
        "Stage_ProcessingLog"         = "Processing {0} ({1}/{2})";
        "Stage_ScanComplete"          = "High-risk event scan complete, found {0} events";
        "Stage_HealthComplete"        = "System health assessment complete";
        "Stage_ExportModeSelected"    = "Export mode selected: {0}";
        "Stage_FetchingLog"           = "Fetching full {0} log";
        "Stage_LogFetched"            = "Fetched full {0} log, {1} events total";
        "Stage_Exporting"             = "Exporting: {0}";
        "Stage_AssessingPerformance"  = "Assessing system performance and hardware resources...";
        
        # ==========================================
        # Report Generation Progress
        # ==========================================
        "ReportGen_Generating"        = "Generating Report";
        "ReportGen_AnalyzingEvents"   = "Analyzing event data {0}/{1}";
        "ReportGen_SaveReport"        = "Saving Report";
        "ReportGen_GeneratingCSV"     = "Generating CSV data {0}/{1}";
        "ReportGen_GeneratingJSON"    = "Generating JSON data {0}/{1}";
        "ReportGen_GeneratingXML"     = "Generating XML data {0}/{1}";
        "ReportGen_ProcessingEvent"   = "Processing event {0}";
        "ReportGen_CSVComplete"       = "CSV export complete";
        "ReportGen_JSONComplete"      = "JSON export complete";
        "ReportGen_XMLComplete"       = "XML export complete";
        
        # ==========================================
        # Progress Status
        # ==========================================
        "Progress_Completion"         = "Completion: {0}%";
        "Progress_Environment"        = "{0}/4 Environment Preparation & Initialization";
        "Progress_EstimatedRemaining" = "Estimated remaining: {0}";
        
        # ==========================================
        # Export Complete Status
        # ==========================================
        "Report_CSVComplete_Status"   = "CSV export complete";
        "Report_JSONComplete_Status"  = "JSON export complete";
        "Report_XMLComplete_Status"   = "XML export complete";
        
        # ==========================================
        # Scan & Assessment Status
        # ==========================================
        "Stage_ScanComplete_Detail"   = "High-risk event scan complete, found {0} events";
        "Stage_HealthComplete_Detail" = "System health assessment complete";
        "Stage_ExportModeSelected_Detail" = "Export mode selected: {0}";
        "Stage_LogFetched_Detail"     = "Fetched full {0} log, {1} events total";
        
        # ==========================================
        # Export Modes
        # ==========================================
        "ExportMode_HighRiskOnly"     = "High-risk events only";
        "ExportMode_FullLog"          = "Full {0} log";
    }
}
