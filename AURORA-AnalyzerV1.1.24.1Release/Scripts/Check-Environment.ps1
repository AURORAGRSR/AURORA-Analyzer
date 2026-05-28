# AURORA 环境安全检查脚本
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " AURORA 环境安全检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allGood = $true

# 检查 1: 调试工具进程
Write-Host "[1] 检查调试工具进程..." -ForegroundColor Yellow
$debuggers = @()
$excludePid = $PID
foreach ($proc in (Get-Process)) {
    if ($proc.Id -eq $excludePid) { continue }
    $name = $proc.ProcessName.ToLowerInvariant()
    if ($name -match "windbg|windbgx|cdb|ntsd|x64dbg|x32dbg|ida|ida64|idag|idaw|ollydbg|ghidra|radare2|r2|rizin|dbgshell|vsjitdebugger|mdbg|dnspy|ilspy|processhacker|wireshark|fiddler|scylla|scyllahide|titancall|phant0m|devenv|visualfsharp|visualstudio") {
        $debuggers += $proc
    }
}
if ($debuggers.Count -gt 0) {
    Write-Host "  [FAIL] 发现调试工具进程：" -ForegroundColor Red
    foreach ($d in $debuggers) {
        Write-Host "    - $($d.ProcessName) (PID: $($d.Id))" -ForegroundColor DarkRed
    }
    $allGood = $false
} else {
    Write-Host "  [OK] 未发现调试工具进程" -ForegroundColor Green
}
Write-Host ""

# 检查 2: 当前进程是否被调试
Write-Host "[2] 检查当前进程调试状态..." -ForegroundColor Yellow
$isDebug = [System.Diagnostics.Debugger]::IsAttached
if ($isDebug) {
    Write-Host "  [FAIL] 当前进程正在被调试！" -ForegroundColor Red
    $allGood = $false
} else {
    Write-Host "  [OK] 当前进程未被调试" -ForegroundColor Green
}
Write-Host ""

# 检查 3: 系统启动调试选项
Write-Host "[3] 检查系统启动调试选项..." -ForegroundColor Yellow
try {
    $bcdedit = bcdedit /enum 2>$null
    if ($bcdedit -match "debug\s+Yes") {
        Write-Host "  [WARN] 系统启用了调试模式（BCD）" -ForegroundColor Yellow
        Write-Host "    这可能被 AuroraGuard 误判为调试环境" -ForegroundColor DarkYellow
        Write-Host "    关闭方法：bcdedit /debug off" -ForegroundColor Gray
    } else {
        Write-Host "  [OK] 系统未启用调试模式" -ForegroundColor Green
    }
} catch {
    Write-Host "  [INFO] 无法检查 BCD 配置" -ForegroundColor DarkGray
}
Write-Host ""

# 检查 4: 内核调试器
Write-Host "[4] 检查内核调试器..." -ForegroundColor Yellow
try {
    $kernelDebugger = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "DebugPrintOption" -ErrorAction SilentlyContinue
    if ($kernelDebugger) {
        Write-Host "  [WARN] 发现内核调试配置" -ForegroundColor Yellow
    } else {
        Write-Host "  [OK] 未发现内核调试器配置" -ForegroundColor Green
    }
} catch {
    Write-Host "  [OK] 未发现内核调试器配置" -ForegroundColor Green
}
Write-Host ""

# 检查 5: 可疑 DLL 模块
Write-Host "[5] 检查 PowerShell 进程的可疑模块..." -ForegroundColor Yellow
$current = Get-Process -Id $PID
$suspicious = @()
foreach ($module in $current.Modules) {
    $moduleName = $module.ModuleName.ToLowerInvariant()
    if ($moduleName -match "inject|hook|detour|spy|trace|monitor") {
        $suspicious += $module
    }
}
if ($suspicious.Count -gt 0) {
    Write-Host "  [FAIL] 发现可疑模块：" -ForegroundColor Red
    foreach ($m in $suspicious) {
        Write-Host "    - $($m.ModuleName)" -ForegroundColor DarkRed
    }
    $allGood = $false
} else {
    Write-Host "  [OK] 未发现可疑模块" -ForegroundColor Green
}
Write-Host ""

# 检查 6: 远程桌面/虚拟机（可能影响检测）
Write-Host "[6] 检查运行环境..." -ForegroundColor Yellow
$isVM = $false
if (Get-Service -Name "vmtools" -ErrorAction SilentlyContinue) {
    Write-Host "  [INFO] 检测到 VMware 工具" -ForegroundColor DarkGray
    $isVM = $true
}
if (Get-Service -Name "vmicguestinterface" -ErrorAction SilentlyContinue) {
    Write-Host "  [INFO] 检测到 Hyper-V 集成服务" -ForegroundColor DarkGray
    $isVM = $true
}
if (-not $isVM) {
    Write-Host "  [OK] 物理机环境" -ForegroundColor Green
} else {
    Write-Host "  [INFO] 虚拟机环境（某些调试器可能被误判）" -ForegroundColor DarkGray
}
Write-Host ""

# 总结
Write-Host "========================================" -ForegroundColor Cyan
if ($allGood) {
    Write-Host " 检查结果：通过 - 可以正常运行 AURORA" -ForegroundColor Green
} else {
    Write-Host " 检查结果：失败 - 存在调试环境特征" -ForegroundColor Red
    Write-Host ""
    Write-Host "建议操作：" -ForegroundColor Yellow
    Write-Host "  1. 关闭所有调试工具（WinDbg、IDA、VS 等）" -ForegroundColor Gray
    Write-Host "  2. 完全退出 AURORA（包括后台进程）" -ForegroundColor Gray
    Write-Host "  3. 如果问题仍然存在，请重启计算机" -ForegroundColor Gray
    Write-Host ""
    Write-Host "为什么需要重启？" -ForegroundColor DarkGray
    Write-Host "  注销不会清除：" -ForegroundColor DarkGray
    Write-Host "    - 内核调试标志" -ForegroundColor DarkGray
    Write-Host "    - 调试器驱动" -ForegroundColor DarkGray
    Write-Host "    - 某些后台服务" -ForegroundColor DarkGray
    Write-Host "    - 内存中的调试状态" -ForegroundColor DarkGray
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
