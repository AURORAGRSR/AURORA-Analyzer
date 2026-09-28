#Requires -Version 5.1
<#
.SYNOPSIS
    AURORA 知识库 v4.0 → v4.1 迁移脚本（智慧赋能 Phase 0-T1/T2）。

.DESCRIPTION
    为每条命令补齐自主化所需的策略元数据：
      - post_check    ：执行后验证表达式（PowerShell，真值输出=通过；空串=无断言，不撒谎）
      - reversible    ：可逆性（静态回滚命令 / 快照提取 / 瞬态无副作用）
      - alternate_of  ：同规则内替代命令引用（失败自恢复链用）
      - pre_check     ：真实化（目标存在性检查，替换 $true 占位）
      - rollback_command：能推导静态逆操作的补齐
      - risk_level    ：补齐 Critical 样本（bootrec / mdsched / chkdsk /f /r），点亮 C2 3 秒防线

    输出保持 UTF-8 无 BOM，Unicode 不转义（兼容 C# KnowledgeBaseService 手写解析器）。
    默认干跑（仅统计），-Apply 落盘并备份原文件为 *.v40.bak，同时删除 CliXML 缓存。

.NOTES
    发布提示：TechData.json 在 build.ps1 守卫哈希清单内，发布前必须重跑 build.ps1 重铸 GAURORA.CHK.ENC。
#>
param(
    [string]$KbPath = (Join-Path $PSScriptRoot '..\..\Data\AURORA-TechData.json'),
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

# ============================================================
# 工具函数
# ============================================================

function Get-ServiceNamesFromCommand {
    param([string]$text)
    $names = New-Object 'System.Collections.Generic.List[string]'
    # PS -Name 参数（含逗号列表，截止到 -Force/;/行尾）
    foreach ($m in [regex]::Matches($text, '(?i)-Name\s+([^\r\n;]+?)(?=\s+-Force|\s*;|\s*$)')) {
        $raw = $m.Groups[1].Value
        foreach ($part in ($raw -split ',')) {
            $n = $part.Trim().Trim("'").Trim('"')
            if ($n -match '^[A-Za-z0-9._-]+$') {
                if (-not $names.Contains($n)) { $names.Add($n) }
            }
        }
    }
    # PS 裸服务名（Start-Service w32time; Set-Service ...）——首字符不可为 -/.，避免吞掉 -Name 等参数名
    foreach ($m in [regex]::Matches($text, '(?i)(?:Start|Stop|Restart|Set|Get)-Service\s+(?!-)([A-Za-z0-9][A-Za-z0-9._-]*)')) {
        $n = $m.Groups[1].Value
        if ($n -and -not $names.Contains($n)) { $names.Add($n) }
    }
    # cmd 风格（net stop/start X、sc.exe stop/start/config/failure X；qfailure/qc/query 为只读，不进 pre 检查也无妨）
    foreach ($m in [regex]::Matches($text, '(?i)(?:net\s+(?:stop|start)|sc(?:\.exe)?\s+(?:config|stop|start|failure))\s+([A-Za-z0-9][A-Za-z0-9._-]*)')) {
        $n = $m.Groups[1].Value
        if ($n -and -not $names.Contains($n)) { $names.Add($n) }
    }
    # [修复] 逗号包裹防管道展开（单元素时调用方 [0] 索引会变成字符串首字符）
    return ,$names
}

function ConvertTo-NameList {
    param($names)
    # 归一化为 string[]（防止单元素被展开成标量导致 [0] 取首字符）
    # [修复] return 语句同样会走管道展开，必须逗号包裹保数组
    $arr = @($names | Where-Object { $_ })
    return ,([string[]]$arr)
}

function New-ServicePreCheck {
    param($names)
    $n = ConvertTo-NameList $names
    if ($n.Count -eq 0) { return $null }
    if ($n.Count -eq 1) {
        return "[bool](Get-Service -Name '$($n[0])' -ErrorAction SilentlyContinue)"
    }
    $list = ($n | ForEach-Object { "'$_'" }) -join ','
    $cnt = $n.Count
    return "((@($list) | ForEach-Object { Get-Service -Name `$_ -ErrorAction SilentlyContinue }) | Measure-Object).Count -eq $cnt"
}

function New-ServiceRunningPostCheck {
    param($names)
    $n = ConvertTo-NameList $names
    if ($n.Count -eq 0) { return $null }
    $list = ($n | ForEach-Object { "'$_'" }) -join ','
    return "((@($list) | ForEach-Object { (Get-Service -Name `$_ -ErrorAction SilentlyContinue).Status }) -notcontains 'Stopped')"
}

function New-ServiceStoppedPostCheck {
    param($names)
    $n = ConvertTo-NameList $names
    if ($n.Count -eq 0) { return $null }
    $list = ($n | ForEach-Object { "'$_'" }) -join ','
    return "((@($list) | ForEach-Object { (Get-Service -Name `$_ -ErrorAction SilentlyContinue).Status }) -notcontains 'Running')"
}

function Convert-RegPathToPs {
    param([string]$regPath)
    # "HKLM\SYSTEM\..." → "HKLM:\SYSTEM\..."（首段后插冒号）
    if ($regPath -match '^(HKLM|HKCU|HKCR|HKU|HKCC)\\(.+)$') {
        return ($matches[1] + ':\' + $matches[2])
    }
    return $regPath
}

# ============================================================
# 单命令计划推导（有序匹配，首中即止）
# 返回 @{ pre; post; rollback; reversible; risk; class }
#   class: readonly / launcher / mutation
# ============================================================

function Resolve-CommandPlan {
    param([PSObject]$cmd)

    $c = [string]$cmd.command
    $plan = @{
        pre        = $null
        post       = ''
        rollback   = $null   # $null=保持现状；''=清空；字符串=新增
        reversible = $false
        risk       = $null
        class      = 'mutation'
    }

    # ---------- 0. GUI/设置启动器 ----------
    if ($c -match '(?i)^(start\s+""\s+)?(ms-[a-z]+:|windowsdefender:|https?:|control(\.exe)?(\s|$)|taskmgr|devmgmt\.msc|wf\.msc|dcomcnfg|tpm\.msc|diskmgmt\.msc|taskschd\.msc|services\.msc|sigverif|perfmon(\s|\.exe|/)|msinfo32|powercfg\.cpl|SystemPropertiesProtection|useraccountcontrolsettings)' -or
        $c -match '(?i)^control\s+(/name|printers)') {
        $plan.class = 'launcher'
        $plan.reversible = $true
        return $plan
    }

    # ---------- 1. 只读命令 ----------
    $readOnly = $false
    if ($c -match '(?i)^(Get-|whoami|systeminfo|quser|query session|query user|pnputil /enum|Search-ADAccount|Resolve-DnsName|Measure-Command|Test-|route print|nltest|rpcping|tracert|net accounts|gpresult|defrag [A-Z]: /A|cipher )') { $readOnly = $true }
    if ($c -match '(?i)\b(Get-Service|sc(\.exe)? (qfailure|qc|query)|w32tm /query|powercfg /(query|getactivescheme|lastwake|batteryreport|energy|requests|devicequery|aliases)|netsh .+ show|netsh winhttp show|klist( query| tickets)?$|klist tickets|auditpol /get|wevtutil (qe|gl|ge)|winmgmt /verifyrepository|wsl --(status|list)|reagentc /info|fsutil quota query|verifier /query|secedit /export|certutil -(dump|verify|generateSSTFromWU|backup)|bcdedit /enum|bcdedit /export|DISM /Online /Get-Packages|/Cleanup-Image /(CheckHealth|ScanHealth|AnalyzeComponentStore))') { $readOnly = $true }
    if ($c -match '(?i)^(shutdown /a$|\$gw =|\$os =|ver |ipconfig( /all)?$|ipconfig /displaydns)') { $readOnly = $true }

    if ($readOnly) {
        $plan.class = 'readonly'
        $plan.reversible = $true
        # 只读命令也做目标存在性 pre_check（可推导时）
        $svcNames = Get-ServiceNamesFromCommand $c
        $svcPre = New-ServicePreCheck $svcNames
        if ($svcPre) { $plan.pre = $svcPre }
        if ($c -match "'(HK[LMCU]:\\[^']+)'") {
            $plan.pre = "Test-Path '$($Matches[1])'"
        }
        return $plan
    }

    # ---------- 2. 变更命令（模式表）----------

    # --- sfc ---
    if ($c -match '(?i)^sfc /scannow') {
        $plan.pre = '[bool](Get-Command sfc.exe -ErrorAction SilentlyContinue)'
        # [2026-09-03 T2] 弱断言（执行痕迹型）：sfc 完成必写 CBS 日志，30 分钟窗口内被写过=执行完成。
        # sfc 无确定性的效果级断言（修复与否取决于源文件可用性），此断言只背书"确实跑了"。
        $plan.post = '((Get-Item "$env:windir\Logs\CBS\CBS.log" -ErrorAction SilentlyContinue).LastWriteTime -gt (Get-Date).AddMinutes(-30))'
        $plan.reversible = $false
        return $plan
    }

    # --- DISM 修复 ---
    if ($c -match '(?i)/Cleanup-Image /RestoreHealth') {
        $plan.pre = '[bool](Get-Command dism.exe -ErrorAction SilentlyContinue)'
        $plan.post = 'DISM /Online /Cleanup-Image /CheckHealth | Out-Null; $LASTEXITCODE -eq 0'
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)/Cleanup-Image /StartComponentReset') {
        $plan.pre = '[bool](Get-Command dism.exe -ErrorAction SilentlyContinue)'
        # [2026-09-03 T2] 组件存储重置后组件库健康检查应通过
        $plan.post = 'DISM /Online /Cleanup-Image /CheckHealth | Out-Null; $LASTEXITCODE -eq 0'
        $plan.reversible = $false
        return $plan
    }

    # --- 服务操作 ---
    if ($c -match '(?i)Restart-Service') {
        $svcNames = Get-ServiceNamesFromCommand $c
        $plan.pre = New-ServicePreCheck $svcNames
        $plan.post = New-ServiceRunningPostCheck $svcNames
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Start-Service' -and $c -match '(?i)Set-Service .*StartupType Automatic') {
        # 组合：Start-Service X; Set-Service X -StartupType Automatic
        $svcNames = Get-ServiceNamesFromCommand $c
        $n = if ($svcNames.Count -gt 0) { [string]$svcNames[0] } else { $null }
        $plan.pre = New-ServicePreCheck $svcNames
        if (-not $n) { $plan.post = New-ServiceRunningPostCheck $svcNames; $plan.reversible = $true; return $plan }
        $plan.post = "((Get-Service -Name '$n' -ErrorAction SilentlyContinue).Status -eq 'Running') -and ((Get-Service -Name '$n' -ErrorAction SilentlyContinue).StartType -eq 'Automatic')"
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Start-Service') {
        $svcNames = Get-ServiceNamesFromCommand $c
        $plan.pre = New-ServicePreCheck $svcNames
        $plan.post = New-ServiceRunningPostCheck $svcNames
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Stop-Service') {
        $svcNames = Get-ServiceNamesFromCommand $c
        $plan.pre = New-ServicePreCheck $svcNames
        $plan.post = New-ServiceStoppedPostCheck $svcNames
        if ($svcNames.Count -gt 0) {
            $list = ($svcNames | ForEach-Object { "'$_'" }) -join ','
            $plan.rollback = "Start-Service -Name $list"
        }
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^net stop\b' -and $c -match '(?i)&' -and $c -match '(?i)net start') {
        # 组合重置（含 stop & start 序列，如 WU 组件重置）
        $svcNames = Get-ServiceNamesFromCommand $c
        $plan.pre = New-ServicePreCheck $svcNames
        $wuOnly = @($svcNames | Where-Object { $_ -eq 'wuauserv' })
        if ($wuOnly.Count -gt 0) {
            $plan.post = New-ServiceRunningPostCheck $wuOnly
        } else {
            $plan.post = New-ServiceRunningPostCheck $svcNames
        }
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^net (stop|start) ') {
        $svcNames = Get-ServiceNamesFromCommand $c
        $plan.pre = New-ServicePreCheck $svcNames
        $plan.post = New-ServiceRunningPostCheck $svcNames
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^sc\.exe failure') {
        $svcNames = Get-ServiceNamesFromCommand $c
        $n = if ($svcNames.Count -gt 0) { $svcNames[0] } else { 'Spooler' }
        $plan.pre = New-ServicePreCheck $svcNames
        # [2026-09-03 修正] 原断言匹配控制台中文输出（'restart|重新启动'），本机控制台输出
        # 捕获为乱码必失败；改注册表键存在性（设置过恢复动作后 FailureActions 键必在），无本地化依赖。
        $plan.post = "Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\$n\FailureActions'"
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^sc\.exe stop' -or $c -match '(?i)^sc\.exe start') {
        # [2026-09-03 修正] stop 与 start 的效果断言方向相反：stop→Stopped，start→Running
        #（原实现两者都断言 Running，stop 类命令永远验证未过）
        $svcNames = Get-ServiceNamesFromCommand $c
        $plan.pre = New-ServicePreCheck $svcNames
        $plan.post = if ($c -match '(?i)^sc\.exe stop') {
            New-ServiceStoppedPostCheck $svcNames
        } else {
            New-ServiceRunningPostCheck $svcNames
        }
        $plan.reversible = $false   # 复合索引重建命令
        return $plan
    }

    # --- powercfg ---
    if ($c -match '(?i)^powercfg /setactive\s+([0-9a-fA-F-]+)') {
        $guid = $Matches[1]
        $plan.post = "((powercfg /getactivescheme) -join ' ') -match '$($guid.Substring(0,[Math]::Min(8,$guid.Length)))'"
        if (-not $cmd.rollback_command) { $plan.rollback = 'powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e' }
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^powercfg /(SETACVALUEINDEX|setacvalueindex)') {
        $plan.post = "((powercfg /q SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226) -join ' ') -match '0x00000000'"
        if (-not $cmd.rollback_command) { $plan.rollback = 'powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1' }
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^powercfg /restoredefaultschemes') {
        $plan.post = "((powercfg /getactivescheme) -join ' ') -ne ''"
        $plan.reversible = $false
        return $plan
    }

    # --- reg add（注册表快照可逆） ---
    if ($c -match '(?i)^reg add "([^"]+)" /v (\S+) /t \S+ /d (.+?) /f\s*$') {
        $regPath = $Matches[1]; $vName = $Matches[2]; $vData = $Matches[3]
        $psPath = Convert-RegPathToPs $regPath
        $plan.pre = "Test-Path '$psPath'"
        $plan.post = "(Get-ItemProperty '$psPath' -ErrorAction SilentlyContinue).'$vName' -eq '$vData'"
        $plan.reversible = $true
        return $plan
    }

    # --- TLS 1.2 组合注册表 ---
    if ($c -match '(?i)SCHANNEL\\Protocols\\TLS 1\.2') {
        $plan.pre = "Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'"
        $plan.post = "((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -ErrorAction SilentlyContinue).Enabled -eq 1)"
        $plan.reversible = $true
        return $plan
    }

    # --- 网络重置族 ---
    # [2026-09-03 T2] 补效果断言：重置后栈/配置可正常查询（弱断言：执行完成+栈未损坏，非效果验证）
    if ($c -match '(?i)^netsh winsock reset') {
        $plan.post = 'netsh winsock show catalog | Out-Null; $LASTEXITCODE -eq 0'
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^netsh int (ip|ipv6) reset') {
        $plan.post = 'netsh int ip show config | Out-Null; $LASTEXITCODE -eq 0'
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^netsh advfirewall reset') {
        $plan.post = 'netsh advfirewall show allprofiles | Out-Null; $LASTEXITCODE -eq 0'
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^netsh winhttp reset proxy') {
        # [2026-09-03 T2 修正] 弱断言（退出码型）：本机实测中文系统控制台输出捕获为乱码
        # （UTF-8 字节按 GBK 解码），任何中文匹配不可靠——退化为退出码断言，不造假。
        $plan.post = 'netsh winhttp show proxy | Out-Null; $LASTEXITCODE -eq 0'
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^ipconfig /(release|renew)') {
        $plan.post = "((Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { `$_.IPAddress -notlike '169.254*' -and `$_.IPAddress -ne '127.0.0.1' }) | Measure-Object).Count -gt 0"
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^ipconfig /flushdns') {
        # [2026-09-03 T2] 强断言：清空后解析器缓存应为空
        $plan.post = '((Get-DnsClientCache -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0)'
        $plan.reversible = $true
        return $plan
    }

    # --- 时间 ---
    if ($c -match '(?i)^w32tm /resync') {
        $plan.pre = "[bool](Get-Service -Name 'w32time' -ErrorAction SilentlyContinue)"
        # [2026-09-03 T2] 弱断言（执行痕迹型）：重同步后时间服务应答查询。
        # 效果级断言（Source 非 free-running）因 w32tm 输出本地化不可靠，不造假。
        $plan.post = 'w32tm /query /status | Out-Null; $LASTEXITCODE -eq 0'
        $plan.reversible = $true
        return $plan
    }

    # --- WU 软件分发重命名 ---
    if ($c -match '(?i)^Rename-Item .*SoftwareDistribution') {
        $plan.pre = 'Test-Path "$env:SystemRoot\SoftwareDistribution"'
        $plan.post = 'Test-Path "$env:SystemRoot\SoftwareDistribution.old"'
        if (-not $cmd.rollback_command) { $plan.rollback = 'Rename-Item -Path "$env:SystemRoot\SoftwareDistribution.old" -NewName "SoftwareDistribution" -ErrorAction SilentlyContinue' }
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Ren .+SoftwareDistribution') {
        $plan.pre = 'Test-Path "C:\Windows\SoftwareDistribution"'
        $plan.post = 'Test-Path "C:\Windows\SoftwareDistribution.bak"'
        if (-not $cmd.rollback_command) { $plan.rollback = 'Ren C:\Windows\SoftwareDistribution.bak SoftwareDistribution' }
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Ren .+catroot2') {
        $plan.pre = 'Test-Path "C:\Windows\System32\catroot2"'
        $plan.post = 'Test-Path "C:\Windows\System32\catroot2.old"'
        if (-not $cmd.rollback_command) { $plan.rollback = 'Ren C:\Windows\System32\catroot2.old catroot2' }
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Rename-Item .*catroot2') {
        # [2026-09-03 T2] PowerShell 形式的 catroot2 重命名（与 Ren 形式同断言）
        $plan.pre = 'Test-Path "$env:SystemRoot\System32\catroot2"'
        $plan.post = 'Test-Path "$env:SystemRoot\System32\catroot2.old"'
        if (-not $cmd.rollback_command) { $plan.rollback = 'Rename-Item -Path "$env:SystemRoot\System32\catroot2.old" -NewName "catroot2" -ErrorAction SilentlyContinue' }
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)Stop-Service .*Rename-Item .*SoftwareDistribution') {
        $plan.pre = 'Test-Path "$env:SystemRoot\SoftwareDistribution"'
        $plan.post = "((Get-Service -Name 'wuauserv' -ErrorAction SilentlyContinue).Status -eq 'Running')"
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^wusa /uninstall') {
        $plan.reversible = $false
        return $plan
    }

    # --- hosts 重置（内建备份） ---
    if ($c -match '(?i)drivers\\etc\\hosts') {
        $plan.pre = 'Test-Path "$env:SystemRoot\System32\drivers\etc\hosts"'
        # [2026-09-03 T2] 按方向断言：备份型→备份文件存在；还原型→hosts 仍在（弱）
        if ($c -match '(?i)Copy-Item.*hosts".*hosts\.backup') {
            $plan.post = 'Test-Path "$env:SystemRoot\System32\drivers\etc\hosts.backup"'
        } else {
            $plan.post = 'Test-Path "$env:SystemRoot\System32\drivers\etc\hosts"'
        }
        if (-not $cmd.rollback_command) { $plan.rollback = 'Copy-Item "$env:SystemRoot\System32\drivers\etc\hosts.backup" "$env:SystemRoot\System32\drivers\etc\hosts" -Force' }
        $plan.reversible = $true
        return $plan
    }

    # --- Defender ---
    if ($c -match '(?i)^Update-MpSignature') {
        $plan.pre = '[bool](Get-MpComputerStatus -ErrorAction SilentlyContinue)'
        $plan.post = "((Get-MpComputerStatus -ErrorAction SilentlyContinue).AntivirusSignatureLastUpdated -gt (Get-Date).AddHours(-2))"
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Start-MpScan -ScanType QuickScan') {
        $plan.pre = '[bool](Get-MpComputerStatus -ErrorAction SilentlyContinue)'
        $plan.post = '((Get-MpComputerStatus -ErrorAction SilentlyContinue).QuickScanEndTime -gt (Get-Date).AddHours(-1))'
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Start-MpScan -ScanType FullScan') {
        $plan.pre = '[bool](Get-MpComputerStatus -ErrorAction SilentlyContinue)'
        # [2026-09-03 T2] 弱断言（启动型）：全盘扫描小时级且异步，只能背书"已启动"
        $plan.post = '((Get-MpComputerStatus -ErrorAction SilentlyContinue).FullScanStartTime -gt (Get-Date).AddMinutes(-5))'
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Set-MpPreference') {
        $plan.pre = '[bool](Get-MpComputerStatus -ErrorAction SilentlyContinue)'
        $plan.post = '(Get-MpComputerStatus -ErrorAction SilentlyContinue).RealTimeProtectionEnabled'
        if (-not $cmd.rollback_command) { $plan.rollback = 'Set-MpPreference -DisableRealtimeMonitoring $true' }
        $plan.reversible = $true
        return $plan
    }

    # --- 其他修复族 ---
    if ($c -match '(?i)^klist purge') { $plan.reversible = $true; return $plan }
    if ($c -match '(?i)^certutil -urlcache') { $plan.reversible = $true; return $plan }
    if ($c -match '(?i)^winmgmt /salvagerepository') {
        $plan.post = 'winmgmt /verifyrepository | Out-Null; $LASTEXITCODE -eq 0'
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^Enable-WindowsOptionalFeature .* -FeatureName (\S+)') {
        $feat = $Matches[1]
        $plan.pre = '[bool](Get-Command dism.exe -ErrorAction SilentlyContinue)'
        $plan.post = "((Get-WindowsOptionalFeature -Online -FeatureName $feat -ErrorAction SilentlyContinue).State -eq 'Enabled')"
        if (-not $cmd.rollback_command) { $plan.rollback = "Disable-WindowsOptionalFeature -Online -FeatureName $feat -NoRestart" }
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^reagentc /enable') {
        # [2026-09-03 修正] 原断言匹配控制台中文输出（'Enabled|已启用'），本机控制台输出捕获为
        # 乱码必失败；改退出码型弱断言（WinRE 配置可查询）。
        $plan.post = 'reagentc /info | Out-Null; $LASTEXITCODE -eq 0'
        if (-not $cmd.rollback_command) { $plan.rollback = 'reagentc /disable' }
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^bootrec /rebuildbcd') {
        # [2026-09-03 T2] 重建后 BCD 存储应可枚举（Critical 仍永远人工，断言供验证报告）
        $plan.post = 'bcdedit /enum | Out-Null; $LASTEXITCODE -eq 0'
        $plan.risk = 'Critical'
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^bootrec /') {
        $plan.risk = 'Critical'
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^mdsched\.exe') {
        $plan.risk = 'Critical'
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^chkdsk [A-Z]: /f') {
        $plan.risk = 'Critical'
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^chkdsk [A-Z]: /scan') {
        $plan.pre = "[bool](Get-Volume -DriveLetter C -ErrorAction SilentlyContinue)"
        $plan.reversible = $true
        $plan.class = 'readonly'
        return $plan
    }
    if ($c -match '(?i)^verifier /standard') {
        if (-not $cmd.rollback_command) { $plan.rollback = 'verifier /reset' }
        # [2026-09-03 T2] 弱断言（执行痕迹型）：验证器状态可查询（下次重启生效，无即时效果断言）
        $plan.post = 'verifier /query | Out-Null; $LASTEXITCODE -eq 0'
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)Stop-Process -Name explorer') {
        $plan.pre = '[bool](Get-Process explorer -ErrorAction SilentlyContinue)'
        $plan.post = '[bool](Get-Process explorer -ErrorAction SilentlyContinue)'
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Optimize-Volume') {
        $plan.pre = '[bool](Get-Volume -DriveLetter C -ErrorAction SilentlyContinue)'
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^gpupdate') {
        # [2026-09-03 T2] 弱断言（执行痕迹型）：策略应用后 RSOP 应可计算
        $plan.post = 'gpresult /r | Out-Null; $LASTEXITCODE -eq 0'
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^secedit /configure') { $plan.reversible = $true; return $plan }
    if ($c -match '(?i)^esentutl /r') {
        $plan.pre = 'Test-Path "$env:windir\security\Database\secedit.sdb"'
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^msiexec') { $plan.reversible = $true; return $plan }
    if ($c -match '(?i)^regsvr32') { $plan.reversible = $true; return $plan }
    if ($c -match '(?i)^wsl --update') {
        $plan.pre = '[bool](Get-Command wsl.exe -ErrorAction SilentlyContinue)'
        $plan.post = 'wsl --status | Out-Null; $LASTEXITCODE -eq 0'
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^wsl --shutdown') {
        $plan.pre = '[bool](Get-Command wsl.exe -ErrorAction SilentlyContinue)'
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Checkpoint-Computer') { $plan.reversible = $true; return $plan }
    if ($c -match '(?i)^cleanmgr') {
        $plan.pre = '[bool](Get-Command cleanmgr.exe -ErrorAction SilentlyContinue)'
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^Enable-LocalUser') {
        $plan.pre = "[bool](Get-LocalUser -Name 'username' -ErrorAction SilentlyContinue)"
        $plan.post = "(Get-LocalUser -Name 'username' -ErrorAction SilentlyContinue).Enabled"
        if (-not $cmd.rollback_command) { $plan.rollback = "Disable-LocalUser -Name 'username'" }
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Unlock-LocalUser') { $plan.reversible = $true; return $plan }
    if ($c -match '(?i)^Set-LocalUser') { $plan.reversible = $false; return $plan }
    if ($c -match '(?i)^Remove-Item -Path .+spool') {
        $plan.post = "((Get-Service -Name 'Spooler' -ErrorAction SilentlyContinue).Status -eq 'Running')"
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^Remove-Item') {
        # [2026-09-03 T2] TEMP 清理不做 post：实测本机 TEMP 常驻近 2000 项（含占用文件与系统重建），
        # 任何阈值都无可靠语义（清理前未知、清理后残留不可预测），宁可留空不造假断言。
        $plan.reversible = $false
        return $plan
    }
    if ($c -match '(?i)^(netsh wlan export|certutil -backup)') { $plan.reversible = $true; return $plan }
    if ($c -match '(?i)^shutdown /a') { $plan.reversible = $true; return $plan }
    if ($c -match '(?i)^net stop\b') {
        $svcNames = Get-ServiceNamesFromCommand $c
        $plan.pre = New-ServicePreCheck $svcNames
        $plan.post = New-ServiceStoppedPostCheck $svcNames
        if ($svcNames.Count -gt 0 -and -not $cmd.rollback_command) {
            $list = ($svcNames | ForEach-Object { "'$_'" }) -join ','
            $plan.rollback = "Start-Service -Name $list"
        }
        $plan.reversible = $true
        return $plan
    }
    if ($c -match '(?i)^Defrag') {
        $plan.pre = '[bool](Get-Volume -DriveLetter C -ErrorAction SilentlyContinue)'
        $plan.reversible = $true
        return $plan
    }

    # 兜底：未识别的变更命令——保守不可逆、不撒谎
    $plan.reversible = $false
    return $plan
}

# ============================================================
# 主流程
# ============================================================

if (-not (Test-Path $KbPath)) { Write-Error "KB not found: $KbPath" }
$kb = Get-Content $KbPath -Raw -Encoding UTF8 | ConvertFrom-Json

$stats = [ordered]@{
    rules        = 0
    commands     = 0
    readonly     = 0
    launcher     = 0
    mutation     = 0
    preReal      = 0      # pre_check 真实化（非 $true 占位）
    postReal     = 0      # post_check 有真实断言
    rollbackNew  = 0      # 本次新增 rollback
    rollbackKeep = 0      # 原有 rollback
    reversible   = 0
    covered      = 0      # 安全网并集：reversible=true 或 rollback_command 非空（去重计数，2026-09-03 修正重复计数虚高）
    critical     = 0
    alternateSet = 0
}

foreach ($cat in $kb.categories) {
    foreach ($item in $cat.items) {
        $stats.rules++
        $fixPrimary = $null
        foreach ($cmd in $item.commands) {
            $stats.commands++
            $plan = Resolve-CommandPlan $cmd
            switch ($plan.class) {
                'readonly' { $stats.readonly++ }
                'launcher' { $stats.launcher++ }
                default    { $stats.mutation++ }
            }

            # pre_check：真实化（可推导时替换 $true 占位）
            $newPre = $plan.pre
            if ($newPre) {
                $cmd.pre_check = $newPre
            }
            if ($cmd.pre_check -and $cmd.pre_check.Trim() -ne '' -and $cmd.pre_check.Trim() -ne '$true') {
                $stats.preReal++
            }

            # post_check / reversible（新增字段）
            $cmd | Add-Member -MemberType NoteProperty -Name 'post_check' -Value $plan.post -Force
            $cmd | Add-Member -MemberType NoteProperty -Name 'reversible' -Value $plan.reversible -Force
            if ($plan.post -and $plan.post.Trim() -ne '') { $stats.postReal++ }
            if ($plan.reversible) { $stats.reversible++ }

            # rollback：只补不清
            if ($plan.rollback -and -not ([string]$cmd.rollback_command).Trim()) {
                $cmd.rollback_command = $plan.rollback
                $stats.rollbackNew++
            } elseif (([string]$cmd.rollback_command).Trim()) {
                $stats.rollbackKeep++
            }

            # 安全网并集（在 rollback 补齐后统计）：reversible=true 或 rollback_command 非空
            if ($plan.reversible -or ([string]$cmd.rollback_command).Trim()) {
                $stats.covered++
            }

            # 风险升级（Critical 样本）
            if ($plan.risk) {
                $cmd.risk_level = $plan.risk
            }
            if ($cmd.risk_level -eq 'Critical') { $stats.critical++ }

            # alternate_of：同规则内第 2+ 条变更修复命令指向首条
            if ($plan.class -eq 'mutation') {
                if (-not $fixPrimary) {
                    $fixPrimary = $cmd.name_en
                } elseif ($cmd.name_en -ne $fixPrimary) {
                    $cmd | Add-Member -MemberType NoteProperty -Name 'alternate_of' -Value $fixPrimary -Force
                    $stats.alternateSet++
                }
            }
        }
    }
}

# 版本提升
$kb.meta.version = '4.1'

# 强制数组字段（防单元素折叠）
foreach ($cat in $kb.categories) {
    foreach ($item in $cat.items) {
        $item.event_ids = @($item.event_ids)
        $item.message_keywords = @($item.message_keywords)
        $item.causes = @($item.causes)
        $item.causes_en = @($item.causes_en)
        $item.solutions = @($item.solutions)
        $item.solutions_en = @($item.solutions_en)
        $item.applies_to = @($item.applies_to)
        $item.commands = @($item.commands)
    }
}

# ---------- 统计输出 ----------
# 安全网覆盖率 = 并集（reversible=true 或 rollback_command 非空）/ 总命令数。
# 2026-09-03 修正：旧公式 reversible+rollback 简单相加含重复计数（rollback 命令的 reversible 全为 true），
# 虚报 92.2%；精确并集为 87.1%（仍超 80% 目标）。
$rollCoverage = [math]::Round(100.0 * $stats.covered / [math]::Max(1, $stats.commands), 1)
Write-Host "==== KB v4.1 迁移统计 ====" -ForegroundColor Cyan
$stats.GetEnumerator() | ForEach-Object { Write-Host ("  {0,-12} : {1}" -f $_.Key, $_.Value) }
Write-Host ("  回滚覆盖率（可逆+显式回滚）: {0}%（目标≥80%）" -f $rollCoverage)

if (-not $Apply) {
    Write-Host "`n[干跑] 未落盘。加 -Apply 执行迁移。" -ForegroundColor Yellow
    return
}

# ---------- 序列化与落盘 ----------
$json = ConvertTo-Json -InputObject $kb -Depth 16

# 反转 \uXXXX 转义（PS5.1 JavaScriptSerializer 会转义非 ASCII 与 <>&'）
$json = [regex]::Replace($json, '\\u([0-9a-fA-F]{4})', {
    param($m)
    [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
})

# 备份原文件
$bak = "$KbPath.v40.bak"
Copy-Item $KbPath $bak -Force
Write-Host "`n已备份原文件 → $bak" -ForegroundColor Gray

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($KbPath, $json, $utf8NoBom)
Write-Host "已写入 v4.1 → $KbPath" -ForegroundColor Green

# 删除 CliXML 缓存（引擎按时间戳判断重建，双保险）
$cache = Join-Path (Split-Path $KbPath) 'AURORA-TechData.cache.clixml'
if (Test-Path $cache) {
    Remove-Item $cache -Force
    Write-Host "已删除缓存 → $cache（下次启动重建）" -ForegroundColor Green
}

# ---------- 回读验证 ----------
$check = Get-Content $KbPath -Raw -Encoding UTF8 | ConvertFrom-Json
$rules2 = @($check.categories | ForEach-Object { $_.items } | ForEach-Object { $_ })
$cmds2 = @($rules2 | ForEach-Object { $_.commands } | ForEach-Object { $_ })
if ($rules2.Count -ne $stats.rules -or $cmds2.Count -ne $stats.commands) {
    Write-Error ("回读验证失败：rules {0}/{1} commands {2}/{3}" -f $rules2.Count, $stats.rules, $cmds2.Count, $stats.commands)
}
$postCnt = @($cmds2 | Where-Object { $_.post_check -and $_.post_check.Trim() -ne '' }).Count
$revCnt = @($cmds2 | Where-Object { $_.reversible -eq $true }).Count
Write-Host ("回读验证通过：rules={0} commands={1} post_check={2} reversible={3} version={4}" -f `
    $rules2.Count, $cmds2.Count, $postCnt, $revCnt, $check.meta.version) -ForegroundColor Green
