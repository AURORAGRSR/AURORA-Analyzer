# ==========================================
# BOM 检查与清理工具
# ==========================================

param(
    [Parameter(Mandatory=$false)]
    [string]$Path = ".",
    
    [Parameter(Mandatory=$false)]
    [string]$Filter = "*.ps1",
    
    [Parameter(Mandatory=$false)]
    [switch]$RemoveBOM,
    
    [Parameter(Mandatory=$false)]
    [switch]$AddBOM,
    
    [Parameter(Mandatory=$false)]
    [switch]$Recursive
)

function Test-BOM {
    param([string]$FilePath)
    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($FilePath)
        if ($stream.Length -lt 3) {
            return $false
        }
        $header = New-Object byte[] 3
        $bytesRead = $stream.Read($header, 0, 3)
        if ($bytesRead -ge 3) {
            return ($header[0] -eq 239 -and $header[1] -eq 187 -and $header[2] -eq 191)
        }
        return $false
    }
    catch {
        Write-Warning "无法读取文件 '$FilePath': $_"
        return $false
    }
    finally {
        if ($stream) { $stream.Close() }
    }
}

function Remove-BOM {
    param([string]$FilePath)
    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($FilePath)
        if ($stream.Length -lt 3) {
            return $false
        }
        $header = New-Object byte[] 3
        $bytesRead = $stream.Read($header, 0, 3)
        if ($bytesRead -lt 3 -or ($header[0] -ne 239 -or $header[1] -ne 187 -or $header[2] -ne 191)) {
            $stream.Close()
            return $false
        }
        
        $remainingBytes = New-Object byte[] ($stream.Length - 3)
        $stream.Read($remainingBytes, 0, $remainingBytes.Length)
        $stream.Close()
        
        [System.IO.File]::WriteAllBytes($FilePath, $remainingBytes)
        return $true
    }
    catch {
        if ($stream) { try { $stream.Close() } catch {} }
        Write-Warning "移除 BOM 失败 '$FilePath': $_"
        return $false
    }
}

function Add-BOM {
    param([string]$FilePath)
    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($FilePath)
        if ($stream.Length -ge 3) {
            $header = New-Object byte[] 3
            $stream.Read($header, 0, 3)
            if ($header[0] -eq 239 -and $header[1] -eq 187 -and $header[2] -eq 191) {
                $stream.Close()
                return $false
            }
        }
        
        $contentBytes = New-Object byte[] $stream.Length
        $stream.Read($contentBytes, 0, $contentBytes.Length)
        $stream.Close()
        
        $bom = [byte[]](239, 187, 191)
        $newBytes = $bom + $contentBytes
        [System.IO.File]::WriteAllBytes($FilePath, $newBytes)
        return $true
    }
    catch {
        if ($stream) { try { $stream.Close() } catch {} }
        Write-Warning "添加 BOM 失败 '$FilePath': $_"
        return $false
    }
}

function Invoke-BOMScan {
    param(
        [string]$Path,
        [string]$Filter,
        [bool]$Recursive,
        [bool]$RemoveBOM,
        [bool]$AddBOM
    )
    
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "    BOM 检查与清理工具 v1.3" -ForegroundColor Cyan
    Write-Host "    (仅读取文件开头，高效检查)" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "`n路径: $Path" -ForegroundColor Gray
    Write-Host "过滤器: $Filter" -ForegroundColor Gray
    Write-Host "递归: $Recursive" -ForegroundColor Gray
    Write-Host "移除 BOM: $RemoveBOM" -ForegroundColor Gray
    Write-Host "添加 BOM: $AddBOM`n" -ForegroundColor Gray

    $files = @()
    if ($Recursive) {
        $files = Get-ChildItem -Path $Path -Filter $Filter -Recurse -File
    } else {
        $files = Get-ChildItem -Path $Path -Filter $Filter -File
    }

    $bomFiles = @()
    $noBomFiles = @()
    $totalCount = $files.Count

    Write-Host "正在扫描 $totalCount 个文件...`n" -ForegroundColor Cyan

    foreach ($file in $files) {
        if (Test-BOM -FilePath $file.FullName) {
            $bomFiles += $file
            Write-Host "✅ 有 BOM: $($file.Name)" -ForegroundColor Green
        } else {
            $noBomFiles += $file
            Write-Host "⚠️ 无 BOM: $($file.Name)" -ForegroundColor Yellow
        }
    }

    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "扫描完成!" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "`n总计文件: $totalCount" -ForegroundColor White
    Write-Host "有 BOM: $($bomFiles.Count)" -ForegroundColor Green
    Write-Host "无 BOM: $($noBomFiles.Count)" -ForegroundColor Yellow

    if ($RemoveBOM -and $bomFiles.Count -gt 0) {
        Write-Host "`n正在移除 BOM...`n" -ForegroundColor Cyan
        $removedCount = 0
        foreach ($file in $bomFiles) {
            if (Remove-BOM -FilePath $file.FullName) {
                Write-Host "✅ 已移除 BOM: $($file.Name)" -ForegroundColor Green
                $removedCount++
            } else {
                Write-Host "❌ 移除失败: $($file.Name)" -ForegroundColor Red
            }
        }
        Write-Host "`n已成功移除 $removedCount 个文件的 BOM" -ForegroundColor Green
    }
    
    if ($AddBOM -and $noBomFiles.Count -gt 0) {
        Write-Host "`n正在添加 BOM...`n" -ForegroundColor Cyan
        $addedCount = 0
        foreach ($file in $noBomFiles) {
            if (Add-BOM -FilePath $file.FullName) {
                Write-Host "✅ 已添加 BOM: $($file.Name)" -ForegroundColor Green
                $addedCount++
            } else {
                Write-Host "❌ 添加失败: $($file.Name)" -ForegroundColor Red
            }
        }
        Write-Host "`n已成功为 $addedCount 个文件添加 BOM" -ForegroundColor Green
    }
    
    if (-not $RemoveBOM -and -not $AddBOM) {
        Write-Host "`n请选择操作:" -ForegroundColor Cyan
        Write-Host "  1 - 移除所有 BOM" -ForegroundColor Yellow
        Write-Host "  2 - 为所有文件添加 BOM" -ForegroundColor Green
        Write-Host "  其他 - 退出" -ForegroundColor Gray
        
        $choice = Read-Host "`n请输入选择"
        
        if ($choice -eq "1") {
            Write-Host "`n正在移除 BOM...`n" -ForegroundColor Cyan
            $removedCount = 0
            foreach ($file in $bomFiles) {
                if (Remove-BOM -FilePath $file.FullName) {
                    Write-Host "✅ 已移除 BOM: $($file.Name)" -ForegroundColor Green
                    $removedCount++
                } else {
                    Write-Host "❌ 移除失败: $($file.Name)" -ForegroundColor Red
                }
            }
            Write-Host "`n已成功移除 $removedCount 个文件的 BOM" -ForegroundColor Green
        } elseif ($choice -eq "2") {
            Write-Host "`n正在添加 BOM...`n" -ForegroundColor Cyan
            $addedCount = 0
            foreach ($file in $noBomFiles) {
                if (Add-BOM -FilePath $file.FullName) {
                    Write-Host "✅ 已添加 BOM: $($file.Name)" -ForegroundColor Green
                    $addedCount++
                } else {
                    Write-Host "❌ 添加失败: $($file.Name)" -ForegroundColor Red
                }
            }
            Write-Host "`n已成功为 $addedCount 个文件添加 BOM" -ForegroundColor Green
        } else {
            Write-Host "`n已取消操作" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n"
}

Invoke-BOMScan -Path $Path -Filter $Filter -Recursive $Recursive -RemoveBOM $RemoveBOM -AddBOM $AddBOM