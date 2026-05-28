# 找出触发调试器检测的进程
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 调试器进程检测诊断" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$debuggerNames = @(
    "windbg", "windbgx", "cdb", "ntsd", "x64dbg", "x32dbg",
    "ida", "ida64", "idag", "idag64", "idaw", "idaw64",
    "ollydbg", "x64ollydbg", "immunity debugger",
    "ghidra", "ghidraRun",
    "radare2", "r2", "rizin", "rz",
    "dbgshell", "mdb", "mdbx",
    "vsjitdebugger", "mdbg", "cordebug",
    "processhacker", "processhacker2",
    "wireshark", "fiddler", "fiddlereverywhere",
    "dnspy", "dnspy64", "ilspy", "jetbrains.dotpeek",
    "xenserver", "vmware", "vbox", "virtualbox", "vmmap",
    "scylla", "scyllahide", "titancall", "phant0m",
    "devenv", "visualfsharp", "visualstudio"
)

Write-Host "扫描所有运行中的进程..." -ForegroundColor Yellow
Write-Host ""

$found = @()
foreach ($proc in (Get-Process)) {
    $procName = $proc.ProcessName.ToLowerInvariant()
    foreach ($debugName in $debuggerNames) {
        if ($procName.Contains($debugName)) {
            $found += [PSCustomObject]@{
                ProcessName = $proc.ProcessName
                PID = $proc.Id
                MatchedKeyword = $debugName
                Path = $proc.Path
            }
            break
        }
    }
}

if ($found.Count -gt 0) {
    Write-Host "发现以下进程触发了调试器检测：" -ForegroundColor Red
    Write-Host ""
    $found | Format-Table -AutoSize -Property ProcessName, PID, MatchedKeyword, @{Label="Path";Expression={$_.Path.Substring([Math]::Max(0, $_.Path.Length - 60))}}
    
    Write-Host ""
    Write-Host "建议：" -ForegroundColor Yellow
    Write-Host "  1. 如果这些是调试工具，请关闭它们" -ForegroundColor Gray
    Write-Host "  2. 如果是误判（如 VS、虚拟机），请从黑名单中移除" -ForegroundColor Gray
    Write-Host ""
    
    # 统计
    Write-Host "统计信息：" -ForegroundColor Cyan
    $byKeyword = $found | Group-Object MatchedKeyword
    foreach ($group in $byKeyword) {
        Write-Host "  '$($group.Name)': $($group.Count) 个进程" -ForegroundColor DarkGray
    }
} else {
    Write-Host "未发现调试工具进程！" -ForegroundColor Green
    Write-Host ""
    Write-Host "这可能意味着：" -ForegroundColor Yellow
    Write-Host "  1. 检测逻辑有误（建议查看 AuroraGuard 源代码）" -ForegroundColor Gray
    Write-Host "  2. 进程名匹配过于宽泛（如 'visualstudio' 匹配了其他进程）" -ForegroundColor Gray
    Write-Host "  3. 某些系统服务被误判" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
