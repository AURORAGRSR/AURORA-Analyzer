# AURORA-Language.psd1
# 集中式双语资源文件 (CHS / ENG)
# 用于 CHSPRO 和 ENGPRO 统一版本
# 版本：V1.2.13Release
# 构建时间：2026.06.01
# 作者：AURORA VelociRaptor-GR Dev PRJ.

@{
    CHS = @{
        # 启动检测
        "Launcher_Required"           = "❌ 此脚本不能直接运行！";
        "Use_Launcher"                = "请使用以下方式启动：";
        "Method_1"                    = "双击运行 AURORA-Analyzer.exe";
        "Closing_Soon"                = "程序将在 5 秒后自动关闭...";
        
        # 权限请求
        "Admin_Title"                 = "🛡️ 权限请求";
        "Admin_Message"               = "检测到您需要导出安全日志 (Security)，这需要管理员权限。`n`n是否以管理员身份重新运行？";
        "Admin_Required"              = "⚠️ 安全日志 (Security) 需要管理员权限才能访问。";
        "Admin_Granted"               = "✅ 已获得管理员权限";
        "Admin_Denied"                = "⚠️ 用户拒绝提权，跳过 Security 日志导出";
        
        # 日期选择
        "Date_Title"                  = "📅 日期选择";
        "Date_SingleDay_Prompt"       = "请选择要导出的日期：";
        "Date_Range_Start_Prompt"     = "请选择起始日期：";
        "Date_Range_End_Prompt"       = "请选择结束日期：";
        
        # 导出进度
        "Export_Start"                = "📤 开始导出日志...";
        "Export_InProgress"           = "   正在导出：{0}";
        "Export_Done"                 = "✅ 导出完成，共 {0} 条记录";
        "Export_Error"                = "❌ 导出失败：{0}";
        
        # 分析进度
        "Analyze_Start"               = "🧠 正在分析日志模式...";
        "Analyze_Level"               = "   分析级别：{0}";
        "Analyze_Done"                = "✅ 分析完成";
        
        # 报告生成
        "Report_Generating"           = "📄 正在生成报告...";
        "Report_Done"                 = "✅ 报告已保存至：{0}";
        "Report_Open"                 = "📂 正在打开报告文件夹...";
        
        # 错误消息
        "Error_LogType"               = "❌ 无效的日志类型：{0}";
        "Error_TimeRange"             = "❌ 时间范围无效，结束时间必须晚于开始时间";
        "Error_Permission"            = "❌ 权限不足：{0}";
        "Error_Notfound"              = "❌ 未找到日志：{0}";
        
        # PRO 模式特定
        "PRO_Mode"                    = "🔧 PRO 模式：高级日志导出";
        "PRO_Scope_System"            = "系统日志 (System)";
        "PRO_Scope_Application"       = "应用程序日志 (Application)";
        "PRO_Scope_Security"          = "安全日志 (Security)";
        "PRO_Scope_Setup"             = "安装日志 (Setup)";
        "PRO_Scope_DNS"               = "DNS 服务器日志";
        "PRO_Scope_DHCP"              = "DHCP 服务器日志";
        "PRO_Scope_AD"                = "Active Directory 日志";
        "PRO_Scope_IIS"               = "IIS 服务器日志";
        
        # 智能引擎集成
        "SmartEngine_Language"        = "CHS";
        "SmartEngine_Start"           = "🤖 正在启动 AURORA 智能诊断引擎...";
        "SmartEngine_Done"            = "✅ 智能诊断完成";
        
        # 进度管理器集成
        "Checkpoint_Starting"         = "准备启动";
        "Checkpoint_Exporting"        = "正在导出日志";
        "Checkpoint_Analyzing"        = "正在分析模式";
        "Checkpoint_Reporting"        = "正在生成报告";
        "Checkpoint_Completed"        = "导出完成";
        "Checkpoint_Failed"           = "导出失败";
    }
    
    ENG = @{
        # Startup Detection
        "Launcher_Required"           = "❌ This script cannot run directly!";
        "Use_Launcher"                = "Please launch using:";
        "Method_1"                    = "  1. Double-click AURORA.Launcher.exe";
        "Method_2"                    = "  2. Or run AURORA-AnalyzerLauncherGUI.ps1";
        "Closing_Soon"                = "Exiting in 5 seconds...";
        
        # Permission Request
        "Admin_Title"                 = "🛡️ Permission Request";
        "Admin_Message"               = "Security log export requires administrator privileges.`n`nDo you want to rerun as administrator?";
        "Admin_Required"              = "⚠️ Security log requires administrator privileges to access.";
        "Admin_Granted"               = "✅ Administrator privileges granted";
        "Admin_Denied"                = "⚠️ User declined elevation, skipping Security log export";
        
        # Date Selection
        "Date_Title"                  = "📅 Date Selection";
        "Date_SingleDay_Prompt"       = "Please select date to export:";
        "Date_Range_Start_Prompt"     = "Please select start date:";
        "Date_Range_End_Prompt"       = "Please select end date:";
        
        # Export Progress
        "Export_Start"                = "📤 Starting log export...";
        "Export_InProgress"           = "   Exporting: {0}";
        "Export_Done"                 = "✅ Export complete, {0} records total";
        "Export_Error"                = "❌ Export failed: {0}";
        
        # Analysis Progress
        "Analyze_Start"               = "🧠 Analyzing log patterns...";
        "Analyze_Level"               = "   Analysis level: {0}";
        "Analyze_Done"                = "✅ Analysis complete";
        
        # Report Generation
        "Report_Generating"           = "📄 Generating report...";
        "Report_Done"                 = "✅ Report saved to: {0}";
        "Report_Open"                 = "📂 Opening report folder...";
        
        # Error Messages
        "Error_LogType"               = "❌ Invalid log type: {0}";
        "Error_TimeRange"             = "❌ Invalid time range, end time must be later than start time";
        "Error_Permission"            = "❌ Insufficient permissions: {0}";
        "Error_Notfound"              = "❌ Log not found: {0}";
        
        # PRO Mode Specific
        "PRO_Mode"                    = "🔧 PRO Mode: Advanced Log Export";
        "PRO_Scope_System"            = "System Log";
        "PRO_Scope_Application"       = "Application Log";
        "PRO_Scope_Security"          = "Security Log";
        "PRO_Scope_Setup"             = "Setup Log";
        "PRO_Scope_DNS"               = "DNS Server Log";
        "PRO_Scope_DHCP"              = "DHCP Server Log";
        "PRO_Scope_AD"                = "Active Directory Log";
        "PRO_Scope_IIS"               = "IIS Server Log";
        
        # SmartEngine Integration
        "SmartEngine_Language"        = "ENG";
        "SmartEngine_Start"           = "🤖 Starting AURORA Smart Diagnostics Engine...";
        "SmartEngine_Done"            = "✅ Smart diagnostics complete";
        
        # Progress Manager Integration
        "Checkpoint_Starting"         = "Preparing to start";
        "Checkpoint_Exporting"        = "Exporting logs";
        "Checkpoint_Analyzing"        = "Analyzing patterns";
        "Checkpoint_Reporting"        = "Generating report";
        "Checkpoint_Completed"        = "Export completed";
        "Checkpoint_Failed"           = "Export failed";
    }
}
