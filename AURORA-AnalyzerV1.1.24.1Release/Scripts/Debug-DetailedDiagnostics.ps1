# 详细调试检测诊断脚本
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 调试器检测详细诊断" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 测试 1: IsDebuggerPresent
Write-Host "[1] IsDebuggerPresent API 检测..." -ForegroundColor Yellow
$isDebug = [System.Diagnostics.Debugger]::IsAttached
Write-Host "  结果：$isDebug" -ForegroundColor $(if($isDebug){"Red"}else{"Green"})
Write-Host ""

# 测试 2: 检查调试工具进程
Write-Host "[2] 扫描调试工具进程..." -ForegroundColor Yellow
$debuggers = @()
$allProcs = Get-Process
foreach ($proc in $allProcs) {
    $name = $proc.ProcessName.ToLowerInvariant()
    if ($name -match "windbg|cdb|ntsd|x64dbg|ida|ollydbg|ghidra|dnspy|vsjitdebugger") {
        $debuggers += $proc
    }
}
if ($debuggers.Count -gt 0) {
    Write-Host "  发现调试工具：" -ForegroundColor Red
    foreach ($d in $debuggers) {
        Write-Host "    - $($d.ProcessName) (PID: $($d.Id))" -ForegroundColor DarkRed
    }
} else {
    Write-Host "  未发现调试工具进程" -ForegroundColor Green
}
Write-Host ""

# 测试 3: 检查已加载的模块（DLL 注入检测）
Write-Host "[3] 检查可疑 DLL 模块..." -ForegroundColor Yellow
$current = Get-Process -Id $PID
$suspicious = @()
foreach ($module in $current.Modules) {
    $moduleName = $module.ModuleName.ToLowerInvariant()
    if ($moduleName -match "inject|hook|detour|spy|trace|monitor") {
        $suspicious += $module
    }
}
if ($suspicious.Count -gt 0) {
    Write-Host "  发现可疑模块：" -ForegroundColor Red
    foreach ($m in $suspicious) {
        Write-Host "    - $($m.ModuleName) (路径：$($m.FileName))" -ForegroundColor DarkRed
    }
} else {
    Write-Host "  未发现可疑模块" -ForegroundColor Green
}
Write-Host ""

# 测试 4: 检查系统安装的调试工具（注册表）
Write-Host "[4] 检查系统安装的调试工具（注册表）..." -ForegroundColor Yellow
$installedDebuggers = @()
$paths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\AeDebug"
)
foreach ($path in $paths) {
    if (Test-Path $path) {
        $debugger = Get-ItemProperty -Path $path -Name "Debugger" -ErrorAction SilentlyContinue
        if ($debugger.Debugger) {
            $installedDebuggers += $debugger.Debugger
        }
    }
}
if ($installedDebuggers.Count -gt 0) {
    Write-Host "  系统调试器配置：" -ForegroundColor Yellow
    foreach ($dbg in $installedDebuggers) {
        Write-Host "    - $dbg" -ForegroundColor DarkYellow
    }
    Write-Host ""
    Write-Host "  注意：这只是系统配置，不表示正在被调试" -ForegroundColor Gray
} else {
    Write-Host "  未发现系统调试器配置" -ForegroundColor Green
}
Write-Host ""

# 测试 5: 检查进程启动参数
Write-Host "[5] 检查当前进程信息..." -ForegroundColor Yellow
Write-Host "  进程名：$($current.ProcessName)" -ForegroundColor Gray
Write-Host "  PID: $($current.Id)" -ForegroundColor Gray
Write-Host "  启动路径：$($current.Path)" -ForegroundColor Gray
Write-Host "  命令行：$($current.StartInfo.Arguments)" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 诊断完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "如果关闭 WinDbg 后仍触发检测，可能的原因：" -ForegroundColor Yellow
Write-Host "  1. 进程曾被附加，调试标志仍保留在进程中" -ForegroundColor Gray
Write-Host "  2. 其他调试工具进程在运行" -ForegroundColor Gray
Write-Host "  3. 某些 DLL 被注入到进程中" -ForegroundColor Gray
Write-Host ""
Write-Host "建议：" -ForegroundColor Yellow
Write-Host "  - 完全退出 AURORA 后重新启动（不要只是关闭 WinDbg）" -ForegroundColor Gray
Write-Host "  - 确保没有其他调试工具运行" -ForegroundColor Gray
Write-Host ""
