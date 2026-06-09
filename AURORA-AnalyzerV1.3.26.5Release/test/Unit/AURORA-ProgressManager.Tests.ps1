# AURORA-ProgressManager.Tests.ps1 - Pester v5 单元测试
# 测试目标：Scripts\Session\AURORA-ProgressManager.ps1 中的进度管理函数

Describe "New-Session" {
    BeforeAll {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $progressManagerPath = Join-Path $projectRoot "Scripts\Session\AURORA-ProgressManager.ps1"
        if (Test-Path $progressManagerPath) {
            . $progressManagerPath
            $tempToolPath = Join-Path $env:TEMP "AURORA_Test_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempToolPath -Force | Out-Null
            Initialize-CacheDirectory -ToolPath $tempToolPath | Out-Null
        }
    }

    AfterAll {
        if ($tempToolPath -and (Test-Path $tempToolPath)) {
            Remove-Item -Path $tempToolPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "creates a new session and returns a session ID" {
        $sessionId = New-Session -SessionType "UnitTest"
        $sessionId | Should -Not -BeNullOrEmpty
        $sessionId | Should -Match "^SESSION_\d{8}_\d{6}_\d{4}$"
    }

    It "sets initial progress to 0" {
        New-Session -SessionType "UnitTest" | Out-Null
        $script:SessionData.Progress | Should -Be 0
        $script:SessionData.Status  | Should -Be "Active"
    }
}

Describe "Save-SessionProgress" {
    BeforeAll {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $progressManagerPath = Join-Path $projectRoot "Scripts\Session\AURORA-ProgressManager.ps1"
        if (Test-Path $progressManagerPath) {
            . $progressManagerPath
            $tempToolPath = Join-Path $env:TEMP "AURORA_Test_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempToolPath -Force | Out-Null
            Initialize-CacheDirectory -ToolPath $tempToolPath | Out-Null
        }
    }

    AfterAll {
        if ($tempToolPath -and (Test-Path $tempToolPath)) {
            Remove-Item -Path $tempToolPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "saves progress and updates stage" {
        $sessionId = New-Session -SessionType "UnitTest"
        { Save-SessionProgress -SessionId $sessionId -Stage "Testing" -Progress 50 } | Should -Not -Throw

        $script:SessionData.CurrentStage | Should -Be "Testing"
        $script:SessionData.Progress     | Should -Be 50
    }

    It "does not update progress when Progress is -1" {
        New-Session -SessionType "UnitTest" | Out-Null
        Save-SessionProgress -Stage "OnlyStage" -Progress -1
        $script:SessionData.Progress     | Should -Be 0
        $script:SessionData.CurrentStage | Should -Be "OnlyStage"
    }
}

Describe "Restore-SessionProgress" {
    BeforeAll {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $progressManagerPath = Join-Path $projectRoot "Scripts\Session\AURORA-ProgressManager.ps1"
        if (Test-Path $progressManagerPath) {
            . $progressManagerPath
            $tempToolPath = Join-Path $env:TEMP "AURORA_Test_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempToolPath -Force | Out-Null
            Initialize-CacheDirectory -ToolPath $tempToolPath | Out-Null
        }
    }

    AfterAll {
        if ($tempToolPath -and (Test-Path $tempToolPath)) {
            Remove-Item -Path $tempToolPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "restores a previously saved session" {
        $sessionId = New-Session -SessionType "UnitTest"
        Save-SessionProgress -SessionId $sessionId -Stage "RestoreTest" -Progress 75

        # 重置内存数据模拟重新加载场景
        $script:SessionData = @{}
        $script:CurrentSessionId = $null

        $restored = Restore-SessionProgress -SessionId $sessionId
        $restored                           | Should -Not -BeNull
        $restored.SessionId                 | Should -Be $sessionId
        $restored.Stage                     | Should -Be "RestoreTest"
        $restored.Progress                  | Should -Be 75
    }

    It "returns null for non-existent session" {
        $result = Restore-SessionProgress -SessionId "SESSION_nonexistent_9999"
        $result | Should -BeNull
    }
}

Describe "Complete-Session" {
    BeforeAll {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $progressManagerPath = Join-Path $projectRoot "Scripts\Session\AURORA-ProgressManager.ps1"
        if (Test-Path $progressManagerPath) {
            . $progressManagerPath
            $tempToolPath = Join-Path $env:TEMP "AURORA_Test_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempToolPath -Force | Out-Null
            Initialize-CacheDirectory -ToolPath $tempToolPath | Out-Null
        }
    }

    AfterAll {
        if ($tempToolPath -and (Test-Path $tempToolPath)) {
            Remove-Item -Path $tempToolPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "marks session as completed with 100% progress" {
        $sessionId = New-Session -SessionType "UnitTest"
        Save-SessionProgress -SessionId $sessionId -Stage "AlmostDone" -Progress 90
        Complete-Session -SessionId $sessionId

        $script:SessionData.Status   | Should -Be "Completed"
        $script:SessionData.Progress | Should -Be 100
    }
}

Describe "Remove-SessionProgress" {
    BeforeAll {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $progressManagerPath = Join-Path $projectRoot "Scripts\Session\AURORA-ProgressManager.ps1"
        if (Test-Path $progressManagerPath) {
            . $progressManagerPath
            $tempToolPath = Join-Path $env:TEMP "AURORA_Test_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempToolPath -Force | Out-Null
            Initialize-CacheDirectory -ToolPath $tempToolPath | Out-Null
        }
    }

    AfterAll {
        if ($tempToolPath -and (Test-Path $tempToolPath)) {
            Remove-Item -Path $tempToolPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "removes a session without archive" {
        $sessionId = New-Session -SessionType "UnitTest"
        Save-SessionProgress -SessionId $sessionId -Stage "ToDelete" -Progress 10

        { Remove-SessionProgress -SessionId $sessionId } | Should -Not -Throw
    }
}

Describe "Test-PendingSession" {
    BeforeAll {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $progressManagerPath = Join-Path $projectRoot "Scripts\Session\AURORA-ProgressManager.ps1"
        if (Test-Path $progressManagerPath) {
            . $progressManagerPath
            $tempToolPath = Join-Path $env:TEMP "AURORA_Test_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempToolPath -Force | Out-Null
            Initialize-CacheDirectory -ToolPath $tempToolPath | Out-Null
        }
    }

    AfterAll {
        if ($tempToolPath -and (Test-Path $tempToolPath)) {
            Remove-Item -Path $tempToolPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "returns bool" {
        $result = Test-PendingSession
        $result | Should -BeOfType [bool]
    }
}