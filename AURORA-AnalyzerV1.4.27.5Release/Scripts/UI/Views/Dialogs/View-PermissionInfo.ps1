<#
.SYNOPSIS
    AURORA 权限说明信息对话框
.DESCRIPTION
    权限说明信息对话框
.NOTES
    版本：V1.4.27.1Release | 构建时间：2026.07.06
    作者：AURORA VelociRaptor-GR Dev PRJ.
#>
# ====== 权限说明信息对话框 ======
function Show-PermissionInfo {
    param(
        [System.Windows.Forms.Form]$ParentForm
    )
    
    # 使用系统语言作为默认
    $systemLanguage = if ((Get-UICulture).Name -like 'zh*') { 'CHS' } else { 'ENG' }
    $currentLanguage = $systemLanguage
    
    $infoMsg = if ($currentLanguage -eq "CHS") {
        "AURORA 需要管理员权限的原因：`n`n" +
        "1. 查看安全日志（Security Log）`n" +
        "   - 记录系统安全事件`n" +
        "   - Windows 限制访问`n`n" +
        "2. 查看安装日志（Setup Log）`n" +
        "   - 记录 Windows 安装事件`n" +
        "   - 需要管理员权限`n`n" +
        "3. 系统修复操作`n" +
        "   - 修改系统配置`n" +
        "   - 执行修复命令`n`n" +
        "4. 深度智能诊断`n" +
        "   - 访问系统核心信息`n" +
        "   - 执行深度分析`n`n" +
        "💡 提示：提权后，所有功能将完全可用。"
    } else {
        "Reasons AURORA needs administrator privileges：`n`n" +
        "1. Security Log Access`n" +
        "   - Records system security events`n" +
        "   - Restricted by Windows`n`n" +
        "2. Setup Log Access`n" +
        "   - Records Windows installation events`n" +
        "   - Requires admin privileges`n`n" +
        "3. System Repair Operations`n" +
        "   - Modify system configuration`n" +
        "   - Execute repair commands`n`n" +
        "4. Deep Smart Diagnosis`n" +
        "   - Access core system information`n" +
        "   - Perform deep analysis`n`n" +
        "💡 Tip: After elevation, all features will be fully available."
    }
    
    [System.Windows.Forms.MessageBox]::Show(
        $infoMsg,
        $(if ($currentLanguage -eq "CHS") { "为什么需要管理员权限" } else { "Why Administrator Privileges Are Needed" }),
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}
