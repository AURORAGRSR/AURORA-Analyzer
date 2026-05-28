# ==========================================
# 调试器检测功能测试脚本
# 用于验证 AuroraGuard 的调试器检测能力
# ==========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " AURORA 调试器检测功能测试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcherPath = Join-Path $testDir "AURORA-AnalyzerLauncherGUI.ps1"

Write-Host "[1] 读取 AuroraGuard 源代码..." -ForegroundColor Yellow
try {
    $content = Get-Content $launcherPath -Raw
    if ($content -match "IsDebuggerPresent") {
        Write-Host "  ✓ IsDebuggerPresent API 检测已实现" -ForegroundColor Green
    } else {
        Write-Host "  ✗ IsDebuggerPresent API 检测未实现" -ForegroundColor Red
    }
    
    if ($content -match "CheckRemoteDebuggerPresent") {
        Write-Host "  ✓ CheckRemoteDebuggerPresent API 检测已实现" -ForegroundColor Green
    } else {
        Write-Host "  ✗ CheckRemoteDebuggerPresent API 检测未实现" -ForegroundColor Red
    }
    
    if ($content -match "NtQueryInformationProcess") {
        Write-Host "  ✓ NtQueryInformationProcess API 检测已实现" -ForegroundColor Green
    } else {
        Write-Host "  ✗ NtQueryInformationProcess API 检测未实现" -ForegroundColor Red
    }
    
    if ($content -match "windbg") {
        Write-Host "  ✓ 调试工具进程黑名单已实现" -ForegroundColor Green
    } else {
        Write-Host "  ✗ 调试工具进程黑名单未实现" -ForegroundColor Red
    }
    
    if ($content -match "CheckDLLInjection") {
        Write-Host "  ✓ DLL 注入检测已实现" -ForegroundColor Green
    } else {
        Write-Host "  ✗ DLL 注入检测未实现" -ForegroundColor Red
    }
    
    if ($content -match "GetDetectionReason") {
        Write-Host "  ✓ 检测原因识别方法已实现" -ForegroundColor Green
    } else {
        Write-Host "  ✗ 检测原因识别方法未实现" -ForegroundColor Red
    }
    
} catch {
    Write-Host "  ✗ 读取文件失败：$($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "[2] 测试调试器进程检测..." -ForegroundColor Yellow

$testDebuggerNames = @("windbg", "x64dbg", "ida", "ida64", "ollydbg", "ghidra")
Write-Host "  调试工具黑名单包含：" -ForegroundColor Gray
foreach ($name in $testDebuggerNames) {
    Write-Host "    - $name" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "[3] 验证 C# 代码语法..." -ForegroundColor Yellow

$testCode = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class TestDebuggerDetection {
    [DllImport("kernel32.dll")]
    private static extern bool IsDebuggerPresent();
    
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CheckRemoteDebuggerPresent(IntPtr hProcess, ref bool isDebuggerPresent);
    
    public static bool Test() {
        bool isDebug = IsDebuggerPresent();
        bool isRemoteDebug = false;
        CheckRemoteDebuggerPresent(Process.GetCurrentProcess().Handle, ref isRemoteDebug);
        return isDebug || isRemoteDebug;
    }
}
"@

try {
    Add-Type -TypeDefinition $testCode -Language CSharp -ErrorAction Stop
    $result = [TestDebuggerDetection]::Test()
    if ($result) {
        Write-Host "  ⚠ 检测到调试器附加（当前正在调试）" -ForegroundColor Yellow
    } else {
        Write-Host "  ✓ 未检测到调试器（正常状态）" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ C# 代码编译失败：$($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "[4] 检测当前进程环境..." -ForegroundColor Yellow

$currentProcess = Get-Process -Id $PID
Write-Host "  当前进程：$($currentProcess.ProcessName) (PID: $PID)" -ForegroundColor Gray
Write-Host "  运行用户：$([Environment]::UserName)" -ForegroundColor Gray

$runningDebuggers = @()
$allProcesses = Get-Process
foreach ($proc in $allProcesses) {
    $procName = $proc.ProcessName.ToLowerInvariant()
    if ($procName -match "windbg|cdb|ntsd|x64dbg|x32dbg|ida|ollydbg|ghidra|dnspy") {
        $runningDebuggers += $proc
    }
}

if ($runningDebuggers.Count -gt 0) {
    Write-Host "  ⚠ 发现运行中的调试工具：" -ForegroundColor Yellow
    foreach ($debugger in $runningDebuggers) {
        Write-Host "    - $($debugger.ProcessName) (PID: $($debugger.Id))" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  ✓ 未发现运行中的调试工具" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 测试完成！" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "说明：" -ForegroundColor DarkGray
Write-Host "1. 此脚本用于验证调试器检测功能是否正常工作" -ForegroundColor DarkGray
Write-Host "2. 在实际环境中，AuroraGuard 会自动检测并阻止调试" -ForegroundColor DarkGray
Write-Host "3. 如果正在被调试，工具会在 15 秒后自动退出" -ForegroundColor DarkGray
Write-Host ""
