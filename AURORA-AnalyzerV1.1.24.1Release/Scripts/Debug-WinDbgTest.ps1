# ==========================================
# WinDbg 调试器检测验证脚本
# 用于在 WinDbg 附加时验证 AuroraGuard 是否会检测到
# ==========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " WinDbg 调试器检测验证" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[信息] 如果你看到这个脚本，说明：" -ForegroundColor Yellow
Write-Host "  1. PowerShell 已经成功加载" -ForegroundColor Gray
Write-Host "  2. AuroraGuard 即将或已经执行" -ForegroundColor Gray
Write-Host "  3. 调试器检测应该已经触发" -ForegroundColor Gray
Write-Host ""

Write-Host "[1] 检查当前是否被调试..." -ForegroundColor Yellow

$testCode = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class DebugChecker {
    [DllImport("kernel32.dll")]
    private static extern bool IsDebuggerPresent();
    
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CheckRemoteDebuggerPresent(IntPtr hProcess, ref bool isDebuggerPresent);
    
    public static bool Check() {
        bool isDebug = IsDebuggerPresent();
        bool isRemoteDebug = false;
        CheckRemoteDebuggerPresent(Process.GetCurrentProcess().Handle, ref isRemoteDebug);
        return isDebug || isRemoteDebug;
    }
    
    public static string GetDebugInfo() {
        Process current = Process.GetCurrentProcess();
        return string.Format("PID: {0}, Name: {1}, IsDebug: {2}", 
            current.Id, current.ProcessName, Check());
    }
}
"@

try {
    Add-Type -TypeDefinition $testCode -Language CSharp -ErrorAction Stop
    $isDebugging = [DebugChecker]::Check()
    $debugInfo = [DebugChecker]::GetDebugInfo()
    
    if ($isDebugging) {
        Write-Host "  ⚠️  检测到调试器！" -ForegroundColor Red
        Write-Host "  详细信息：$debugInfo" -ForegroundColor DarkRed
        Write-Host ""
        Write-Host "  如果 AuroraGuard 正常工作，现在应该：" -ForegroundColor Yellow
        Write-Host "    ✓ 显示安全警报窗口" -ForegroundColor Gray
        Write-Host "    ✓ 启动 15 秒倒计时" -ForegroundColor Gray
        Write-Host "    ✓ 倒计时结束后退出" -ForegroundColor Gray
    } else {
        Write-Host "  ✓ 未检测到调试器" -ForegroundColor Green
        Write-Host "  详细信息：$debugInfo" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ✗ 检测失败：$($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "[2] 检查运行中的调试工具..." -ForegroundColor Yellow

$debuggers = @()
$allProcesses = Get-Process
foreach ($proc in $allProcesses) {
    $procName = $proc.ProcessName.ToLowerInvariant()
    if ($procName -match "windbg|cdb|ntsd|x64dbg|ida|ollydbg") {
        $debuggers += $proc
    }
}

if ($debuggers.Count -gt 0) {
    Write-Host "  ⚠️  发现调试工具进程：" -ForegroundColor Yellow
    foreach ($dbg in $debuggers) {
        Write-Host "    - $($dbg.ProcessName) (PID: $($dbg.Id))" -ForegroundColor DarkYellow
    }
    Write-Host ""
    Write-Host "  AuroraGuard 的 CheckDebuggerProcesses() 应该会检测到！" -ForegroundColor Red
} else {
    Write-Host "  ✓ 未发现已知调试工具进程" -ForegroundColor Green
}

Write-Host ""
Write-Host "[3] 当前 PowerShell 进程信息" -ForegroundColor Yellow

$currentProc = Get-Process -Id $PID
Write-Host "  进程 ID: $PID" -ForegroundColor Gray
Write-Host "  进程名：$($currentProc.ProcessName)" -ForegroundColor Gray
Write-Host "  内存使用：$([Math]::Round($currentProc.WorkingSet / 1MB, 2)) MB" -ForegroundColor Gray
Write-Host "  启动时间：$($currentProc.StartTime)" -ForegroundColor Gray

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 验证完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($isDebugging -or $debuggers.Count -gt 0) {
    Write-Host "🔴 警告：检测到调试环境！" -ForegroundColor Red
    Write-Host "   AuroraGuard 应该已经触发保护机制。" -ForegroundColor DarkRed
    Write-Host "   如果没有看到倒计时窗口，请检查：" -ForegroundColor Yellow
    Write-Host "     1. AuroraGuard 是否正确加载" -ForegroundColor Gray
    Write-Host "     2. GetDetectionReason() 返回值" -ForegroundColor Gray
    Write-Host "     3. AuroraExitCountdown 窗口是否显示" -ForegroundColor Gray
} else {
    Write-Host "🟢 正常：未检测到调试环境" -ForegroundColor Green
    Write-Host "   AuroraGuard 会正常通过验证。" -ForegroundColor DarkGreen
}

Write-Host ""
Write-Host "按任意键继续..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
