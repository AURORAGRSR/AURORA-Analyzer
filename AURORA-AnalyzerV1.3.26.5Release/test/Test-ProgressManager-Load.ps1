#!/usr/bin/env pwsh
# 测试 ProgressManager 加载
Write-Host "=== 测试 ProgressManager 加载 ===" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptsDir = Join-Path $scriptDir "..\Scripts"

Write-Host "`n1. 测试直接加载 ProgressManager.ps1" -ForegroundColor Yellow
try {
    . "$scriptsDir\Session\AURORA-ProgressManager.ps1"
    Write-Host "✓ ProgressManager.ps1 加载成功" -ForegroundColor Green
} catch {
    Write-Host "✗ ProgressManager.ps1 加载失败：$_" -ForegroundColor Red
}

Write-Host "`n2. 测试 Initialize-CacheDirectory 函数是否存在" -ForegroundColor Yellow
if (Get-Command Initialize-CacheDirectory -ErrorAction SilentlyContinue) {
    Write-Host "✓ Initialize-CacheDirectory 函数可用" -ForegroundColor Green
    
    Write-Host "`n3. 测试初始化缓存目录" -ForegroundColor Yellow
    try {
        $result = Initialize-CacheDirectory -ToolPath $scriptDir
        if ($result) {
            Write-Host "✓ 缓存目录初始化成功" -ForegroundColor Green
            Write-Host "  缓存根目录：$script:CacheRoot" -ForegroundColor Gray
        } else {
            Write-Host "✗ 缓存目录初始化失败" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ 初始化失败：$_" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Initialize-CacheDirectory 函数不存在" -ForegroundColor Red
}

Write-Host "`n=== 测试完成 ===" -ForegroundColor Cyan
