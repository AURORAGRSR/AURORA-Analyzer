<#
.SYNOPSIS
    AURORA Undo 管理器 - 快速备份与还原
.DESCRIPTION
    提供快速的备份创建和还原功能
    作为系统还原的补充方案
    支持注册表、文件、服务的备份与还原
.NOTES
    版本：V1.3.26.5Release | 构建时间：2026.06.08
    作者：AURORA VelociRaptor-GR Dev PRJ.
    与 RestoreManager 和 RepairLogger 配合使用
    提供快速的撤销操作（无需重启）
#>

#requires -Version 5.0

param()

#region 全局变量

$script:BackupDir = if ($PSScriptRoot) {
    Join-Path $PSScriptRoot "SessionCache\backup"
} else {
    Join-Path $env:TEMP "AURORA-Backups"
}

$script:CurrentSnapshot = $null

#endregion

#region 初始化函数

function Initialize-UndoManager {
    <#
    .SYNOPSIS
        初始化 Undo 管理器
    .DESCRIPTION
        创建必要的目录结构
    #>
    
    try {
        # 创建备份目录
        if (-not (Test-Path $script:BackupDir)) {
            New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
        }
        
        Write-Host "✅ AURORA Undo 管理器初始化完成" -ForegroundColor Green
        Write-Host "   备份目录：$script:BackupDir"
        
        return $true
    } catch {
        Write-Warning "Undo 管理器初始化失败：$($_.Exception.Message)"
        return $false
    }
}

#endregion

#region 备份创建

function Create-BackupSnapshot {
    <#
    .SYNOPSIS
        创建备份快照
    .DESCRIPTION
        备份指定的注册表项、文件或服务配置
    .PARAMETER Type
        备份类型（Registry, File, Service）
    .PARAMETER Paths
        要备份的路径（注册表路径或文件路径）
    .PARAMETER ServiceNames
        要备份的服务名称
    .OUTPUTS
        备份快照对象
    .EXAMPLE
        Create-BackupSnapshot -Type "Registry" -Paths @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate")
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Registry", "File", "Service", "Mixed")]
        [string]$Type,
        
        [string[]]$Paths = @(),
        
        [string[]]$ServiceNames = @()
    )
    
    # 生成快照 ID
    $snapshotId = "BS_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$(Get-Random -Maximum 999)"
    $snapshotDir = Join-Path $script:BackupDir $snapshotId
    
    Write-Host "💾 正在创建备份快照：$snapshotId" -ForegroundColor Cyan
    Write-Host "   类型：$Type"
    Write-Host "   备份目录：$snapshotDir"
    
    # 创建快照目录
    if (-not (Test-Path $snapshotDir)) {
        New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
    }
    
    $snapshot = @{
        SnapshotId = $snapshotId
        CreatedAt = Get-Date -Format "o"
        Type = $Type
        BackupDir = $snapshotDir
        Items = @()
        Size = "0 KB"
        Status = "Creating"
    }
    
    try {
        # 备份注册表
        if ($Type -eq "Registry" -or $Type -eq "Mixed") {
            foreach ($path in $Paths) {
                if ($path -like "HKLM:*" -or $path -like "HKCU:*") {
                    $registryBackup = Backup-RegistryKey -Path $path -BackupDir $snapshotDir
                    if ($registryBackup) {
                        $snapshot.Items += $registryBackup
                    }
                }
            }
        }
        
        # 备份文件
        if ($Type -eq "File" -or $Type -eq "Mixed") {
            foreach ($path in $Paths) {
                if (Test-Path $path) {
                    $fileBackup = Backup-File -Path $path -BackupDir $snapshotDir
                    if ($fileBackup) {
                        $snapshot.Items += $fileBackup
                    }
                }
            }
        }
        
        # 备份服务配置
        if ($Type -eq "Service" -or $Type -eq "Mixed") {
            foreach ($serviceName in $ServiceNames) {
                $serviceBackup = Backup-Service -Name $serviceName -BackupDir $snapshotDir
                if ($serviceBackup) {
                    $snapshot.Items += $serviceBackup
                }
            }
        }
        
        # 计算备份大小
        $totalSize = (Get-ChildItem -Path $snapshotDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $snapshot.Size = "{0:N1} KB" -f ($totalSize / 1KB)
        
        # 保存元数据
        $snapshot.Status = "Active"
        Save-SnapshotMetadata -Snapshot $snapshot
        
        Write-Host "✅ 备份快照创建完成" -ForegroundColor Green
        Write-Host "   备份项数：$($snapshot.Items.Count)"
        Write-Host "   备份大小：$($snapshot.Size)"
        
        $script:CurrentSnapshot = $snapshot
        
        return $snapshot
    } catch {
        Write-Warning "备份快照创建失败：$($_.Exception.Message)"
        $snapshot.Status = "Failed"
        return $null
    }
}

function Backup-RegistryKey {
    param(
        [string]$Path,
        [string]$BackupDir
    )
    
    try {
        $safeName = $Path -replace '[\\:]','_'
        $regFile = Join-Path $BackupDir "${safeName}.reg"
        
        # 使用 reg.exe 导出注册表项
        $process = Start-Process "reg.exe" -ArgumentList "export `"$Path`" `"$regFile`"" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Verbose "注册表备份成功：$Path"
            
            return @{
                Type = "Registry"
                OriginalPath = $Path
                BackupFile = $regFile
                BackedUpAt = Get-Date -Format "o"
                Status = "Success"
            }
        } else {
            Write-Warning "注册表备份失败：$Path (退出码：$($process.ExitCode))"
            return $null
        }
    } catch {
        Write-Warning "注册表备份失败：$Path - $($_.Exception.Message)"
        return $null
    }
}

function Backup-File {
    param(
        [string]$Path,
        [string]$BackupDir
    )
    
    try {
        $fileName = Split-Path -Leaf $Path
        $backupFile = Join-Path $BackupDir $fileName
        
        Copy-Item -Path $Path -Destination $backupFile -Force
        
        Write-Verbose "文件备份成功：$Path"
        
        return @{
            Type = "File"
            OriginalPath = $Path
            BackupFile = $backupFile
            BackedUpAt = Get-Date -Format "o"
            Status = "Success"
        }
    } catch {
        Write-Warning "文件备份失败：$Path - $($_.Exception.Message)"
        return $null
    }
}

function Backup-Service {
    param(
        [string]$Name,
        [string]$BackupDir
    )
    
    try {
        $service = Get-Service -Name $Name -ErrorAction Stop
        $configFile = Join-Path $BackupDir "Service_${Name}.json"
        
        # 导出服务配置
        $config = @{
            Name = $service.Name
            DisplayName = $service.DisplayName
            Status = $service.Status
            StartType = $service.StartType
            ServiceType = $service.ServiceType
        }
        
        $config | ConvertTo-Json | Out-File $configFile -Encoding UTF8
        
        Write-Verbose "服务配置备份成功：$Name"
        
        return @{
            Type = "Service"
            ServiceName = $Name
            BackupFile = $configFile
            BackedUpAt = Get-Date -Format "o"
            Status = "Success"
        }
    } catch {
        Write-Warning "服务配置备份失败：$Name - $($_.Exception.Message)"
        return $null
    }
}

#endregion

#region 备份还原

function Restore-BackupSnapshot {
    <#
    .SYNOPSIS
        还原备份快照
    .DESCRIPTION
        从备份快照还原注册表、文件或服务配置
    .PARAMETER SnapshotId
        快照 ID
    .EXAMPLE
        Restore-BackupSnapshot -SnapshotId "BS_001"
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$SnapshotId
    )
    
    Write-Host "🔄 正在还原备份快照：$SnapshotId" -ForegroundColor Cyan
    
    # 获取快照元数据
    $snapshot = Get-SnapshotMetadata -SnapshotId $SnapshotId
    if (-not $snapshot) {
        Write-Warning "未找到快照：$SnapshotId"
        return $false
    }
    
    if ($snapshot.Status -ne "Active") {
        Write-Warning "快照状态异常：$($snapshot.Status)"
        return $false
    }
    
    try {
        $successCount = 0
        $totalCount = $snapshot.Items.Count
        
        foreach ($item in $snapshot.Items) {
            try {
                if ($item.Type -eq "Registry") {
                    Restore-RegistryBackup -BackupItem $item
                    $successCount++
                } elseif ($item.Type -eq "File") {
                    Restore-FileBackup -BackupItem $item
                    $successCount++
                } elseif ($item.Type -eq "Service") {
                    Restore-ServiceBackup -BackupItem $item
                    $successCount++
                }
            } catch {
                Write-Warning "还原项失败：$($item.OriginalPath) - $($_.Exception.Message)"
            }
        }
        
        Write-Host "✅ 备份还原完成" -ForegroundColor Green
        Write-Host "   成功：$successCount / $totalCount 项"
        
        return ($successCount -eq $totalCount)
    } catch {
        Write-Warning "备份还原失败：$($_.Exception.Message)"
        return $false
    }
}

function Restore-RegistryBackup {
    param([hashtable]$BackupItem)
    
    try {
        $regFile = $BackupItem.BackupFile
        if (Test-Path $regFile) {
            # 静默导入注册表
            $process = Start-Process "reg.exe" -ArgumentList "import `"$regFile`"" -Wait -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                Write-Verbose "注册表还原成功：$($BackupItem.OriginalPath)"
                return $true
            } else {
                throw "reg.exe 退出码：$($process.ExitCode)"
            }
        } else {
            throw "备份文件不存在：$regFile"
        }
    } catch {
        Write-Warning "注册表还原失败：$($BackupItem.OriginalPath) - $($_.Exception.Message)"
        return $false
    }
}

function Restore-FileBackup {
    param([hashtable]$BackupItem)
    
    try {
        $backupFile = $BackupItem.BackupFile
        $originalPath = $BackupItem.OriginalPath
        
        if (Test-Path $backupFile) {
            Copy-Item -Path $backupFile -Destination $originalPath -Force
            Write-Verbose "文件还原成功：$originalPath"
            return $true
        } else {
            throw "备份文件不存在：$backupFile"
        }
    } catch {
        Write-Warning "文件还原失败：$($BackupItem.OriginalPath) - $($_.Exception.Message)"
        return $false
    }
}

function Restore-ServiceBackup {
    param([hashtable]$BackupItem)
    
    try {
        $configFile = $BackupItem.BackupFile
        if (Test-Path $configFile) {
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
            
            $service = Get-Service -Name $config.Name -ErrorAction Stop
            
            # 还原服务启动类型
            Set-Service -Name $config.Name -StartupType $config.StartType
            
            Write-Verbose "服务配置还原成功：$($config.Name)"
            return $true
        } else {
            throw "配置文件不存在：$configFile"
        }
    } catch {
        Write-Warning "服务配置还原失败：$($BackupItem.ServiceName) - $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region 快照管理

function Get-SnapshotMetadata {
    param([string]$SnapshotId)
    
    try {
        $metadataFile = Join-Path $script:BackupDir "$SnapshotId\metadata.json"
        if (Test-Path $metadataFile) {
            return Get-Content $metadataFile -Raw | ConvertFrom-Json
        }
    } catch {
        Write-Verbose "读取快照元数据失败：$($_.Exception.Message)"
    }
    
    return $null
}

function Save-SnapshotMetadata {
    param([hashtable]$Snapshot)
    
    try {
        $metadataFile = Join-Path $Snapshot.BackupDir "metadata.json"
        $Snapshot | ConvertTo-Json -Depth 5 | Out-File $metadataFile -Encoding UTF8
    } catch {
        Write-Warning "保存快照元数据失败：$($_.Exception.Message)"
    }
}

function Remove-BackupSnapshot {
    param([string]$SnapshotId)
    
    try {
        $snapshotDir = Join-Path $script:BackupDir $SnapshotId
        if (Test-Path $snapshotDir) {
            Remove-Item -Path $snapshotDir -Recurse -Force
            Write-Host "✅ 快照已删除：$SnapshotId" -ForegroundColor Green
            return $true
        } else {
            Write-Warning "快照目录不存在：$snapshotDir"
            return $false
        }
    } catch {
        Write-Warning "删除快照失败：$($_.Exception.Message)"
        return $false
    }
}

function Test-BackupIntegrity {
    param([string]$SnapshotId)
    
    $snapshot = Get-SnapshotMetadata -SnapshotId $SnapshotId
    if (-not $snapshot) {
        return $false
    }
    
    $integrityOk = $true
    
    foreach ($item in $snapshot.Items) {
        if (-not (Test-Path $item.BackupFile)) {
            Write-Warning "备份文件丢失：$($item.BackupFile)"
            $integrityOk = $false
        }
    }
    
    return $integrityOk
}

#endregion

#region 导出函数

# 注意：本脚本作为模块使用，通过点号导入
# 函数在全局作用域中自动可用

#endregion































