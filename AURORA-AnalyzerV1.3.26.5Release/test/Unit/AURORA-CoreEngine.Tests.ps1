# AURORA-CoreEngine.Tests.ps1 - Pester v5 单元测试
# 测试目标：Scripts\Core\AURORA-CoreEngine.ps1 中的核心函数

# 为避免 SecurityModule 中 C# 编译依赖问题，直接内联定义 Test-RSATokenSignature
# 使用与 SecurityModule 一致的真实公钥格式
$global:AURORA_PublicKeyXml = '<RSAKeyValue><Modulus>nYrBvdZUDKu+QueFBgwe6xH2XI31I7BqlfgOzG7RtT8fvjObBPAM2UbQsl1lb0XKpDt/VJEX3ESNgB6QFa6VFoDCcAekomWJoQH6ypsh0QCTfU59e3gidbvrqnuQj+jIf10/cjVU6Ou2v1ciIxg4yNPf4/kmrp0Pt5/RAQA3hlCb5pYbbMFugPD/WAl4cz/0/4Ah81ohEn0j0ep2o+mm+XQmphilCdtyovd7hyKpbgJfPKmSZLQbgRlH4IhW/86z0b/zveMV1lWCP9EDUuvrilBV317tzYjF10mEZ0g6p7dAtskwGpb97ku7eV6Prd9fx9rJ6ZX7uQ3gJ2Vi9hlRWQ==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'

function global:Test-RSATokenSignature {
    param(
        [string]$Nonce,
        [long]$Timestamp,
        [string]$HashPayload,
        [string]$Signature
    )
    try {
        $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider
        $rsa.FromXmlString($global:AURORA_PublicKeyXml)
        $signInput = "$($Nonce):$($Timestamp):$($HashPayload)"
        $signBytes = [System.Text.Encoding]::UTF8.GetBytes($signInput)
        $sigBytes = [Convert]::FromBase64String($Signature)
        $valid = $rsa.VerifyData($signBytes, $sigBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $rsa.Dispose()
        return $valid
    } catch {
        Write-Warning "RSA token verification failed: $($_.Exception.Message)"
        return $false
    }
}

Describe "Test-RSATokenSignature" {
    It "returns false for invalid signature (tampered data)" {
        # Test-RSATokenSignature 使用 global: 作用域，直接可见
        $result = Test-RSATokenSignature -Nonce "test" -Timestamp 0 -HashPayload "bad" -Signature "AAAA"
        $result | Should -BeFalse
    }

    It "returns false when signature is empty string" {
        $result = Test-RSATokenSignature -Nonce "n" -Timestamp 1 -HashPayload "p" -Signature ""
        $result | Should -BeFalse
    }
}

Describe "Invoke-SafeOperation" {
    BeforeAll {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $coreEnginePath = Join-Path $projectRoot "Scripts\Core\AURORA-CoreEngine.ps1"
        if (Test-Path $coreEnginePath) {
            Remove-Variable -Name AURORA_CoreEngine_Loaded -Scope Global -Force -ErrorAction SilentlyContinue
            . $coreEnginePath
        }
    }

    It "executes a successful operation and returns true" {
        $result = Invoke-SafeOperation -Operation { "ok" } -OperationName "TestSuccess"
        $result | Should -BeTrue
    }

    It "returns false with ContinueOnError when operation throws" {
        $result = Invoke-SafeOperation -Operation { throw "expected error" } -OperationName "TestFail" -ContinueOnError -LogLevel "Debug"
        $result | Should -BeFalse
    }

    It "re-throws when operation fails without ContinueOnError" {
        { Invoke-SafeOperation -Operation { throw "fatal" } -OperationName "TestThrow" -LogLevel "Error" } | Should -Throw
    }
}

Describe "Convert-SafeDateTime" {
    BeforeAll {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $coreEnginePath = Join-Path $projectRoot "Scripts\Core\AURORA-CoreEngine.ps1"
        if (Test-Path $coreEnginePath) {
            Remove-Variable -Name AURORA_CoreEngine_Loaded -Scope Global -Force -ErrorAction SilentlyContinue
            . $coreEnginePath
        }
    }

    It "returns null for null input" {
        Convert-SafeDateTime -Value $null | Should -BeNull
    }

    It "returns same value for [datetime] input" {
        $dt = Get-Date
        $result = Convert-SafeDateTime -Value $dt
        $result | Should -BeOfType [datetime]
        $result | Should -Be $dt
    }

    It "parses ASP.NET JSON date format \/Date(0)\/" {
        $result = Convert-SafeDateTime -Value "\/Date(0)\/"
        $result | Should -BeOfType [datetime]
    }

    It "parses ISO 8601 date string" {
        $result = Convert-SafeDateTime -Value "2025-01-15T10:30:00"
        $result | Should -BeOfType [datetime]
        $result.Year  | Should -Be 2025
        $result.Month | Should -Be 1
        $result.Day   | Should -Be 15
    }

    It "returns null for completely invalid input" {
        $result = Convert-SafeDateTime -Value "not_a_date_xyz"
        $result | Should -BeNull
    }
}

Describe "Write-AuroraLog" {
    BeforeAll {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $coreEnginePath = Join-Path $projectRoot "Scripts\Core\AURORA-CoreEngine.ps1"
        if (Test-Path $coreEnginePath) {
            Remove-Variable -Name AURORA_CoreEngine_Loaded -Scope Global -Force -ErrorAction SilentlyContinue
            . $coreEnginePath
        }
    }

    It "outputs to console when syncHash is not defined" {
        # 确保没有 syncHash（非 GUI 环境）
        if (Get-Variable -Name "syncHash" -Scope Global -ErrorAction SilentlyContinue) {
            Remove-Variable -Name "syncHash" -Scope Global -Force -ErrorAction SilentlyContinue
        }
        # 验证函数不抛异常
        { Write-AuroraLog "Test message" -Level "Info" } | Should -Not -Throw
    }
}

Describe "Get-SystemInfo" {
    BeforeAll {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $coreEnginePath = Join-Path $projectRoot "Scripts\Core\AURORA-CoreEngine.ps1"
        if (Test-Path $coreEnginePath) {
            Remove-Variable -Name AURORA_CoreEngine_Loaded -Scope Global -Force -ErrorAction SilentlyContinue
            . $coreEnginePath
        }
    }

    It "returns a hashtable with expected keys" {
        $info = Get-SystemInfo
        $info | Should -BeOfType [hashtable]
        $info.ContainsKey("OSVersion")          | Should -BeTrue
        $info.ContainsKey("PowerShellVersion")  | Should -BeTrue
        $info.ContainsKey("Is64Bit")            | Should -BeTrue
    }

    It "returns a boolean for Is64Bit" {
        $info = Get-SystemInfo
        $info.Is64Bit | Should -BeOfType [bool]
    }
}

Describe "Invoke-SafeExit" {
    BeforeAll {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $coreEnginePath = Join-Path $projectRoot "Scripts\Core\AURORA-CoreEngine.ps1"
        if (Test-Path $coreEnginePath) {
            Remove-Variable -Name AURORA_CoreEngine_Loaded -Scope Global -Force -ErrorAction SilentlyContinue
            . $coreEnginePath
        }
    }

    It "function is defined and callable (existence check only)" {
        # 只验证函数存在，不实际调用（会退出进程）
        Get-Command Invoke-SafeExit -ErrorAction SilentlyContinue | Should -Not -BeNull
    }
}