# Test-PRO-Merge.ps1
# AURORA PRO 引擎合并验证测试脚本
# 用于验证合并后的 PRO 引擎正确性
# 版本: V1.3.26.0Release
# 构建时间: 2026.06.08

$ErrorActionPreference = "Continue"

# ==========================================
# 基础路径设置
# ==========================================
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ScriptsDir  = Join-Path $ProjectRoot "Scripts"
$PRODir      = Join-Path $ScriptsDir "PRO"
$GUIDir      = Join-Path $ScriptsDir "GUI"
$SessionDir  = Join-Path $ScriptsDir "Session"

# ==========================================
# 测试计数器和格式化函数
# ==========================================
$script:TestPassed = 0
$script:TestFailed = 0
$script:IndentLevel = 0
$script:CurrentDescribe = ""
$script:CurrentContext = ""

function Write-Describe {
    param([string]$Name)
    $script:CurrentDescribe = $Name
    $script:IndentLevel = 0
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Describe: $Name" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Context {
    param([string]$Name)
    $script:CurrentContext = $Name
    $script:IndentLevel = 1
    Write-Host "`n  Context: $Name" -ForegroundColor DarkCyan
}

function Write-It {
    param([string]$Name, [bool]$Passed, [string]$Detail = "")
    $script:IndentLevel = 2
    $indent = "    "
    if ($Passed) {
        $script:TestPassed++
        Write-Host "$indent✅ 通过 - $Name" -ForegroundColor Green
    } else {
        $script:TestFailed++
        Write-Host "$indent❌ 失败 - $Name" -ForegroundColor Red
        if ($Detail) {
            Write-Host "$indent   详情: $Detail" -ForegroundColor Yellow
        }
    }
}

# ==========================================
# 1. 文件存在性测试
# ==========================================
Write-Describe "文件存在性测试"

Write-Context "必需文件存在性"

$proEnginePath    = Join-Path $PRODir "AURORA-AnalyzerPRO-Engine.ps1"
$proEntryPoint    = Join-Path $PRODir "AURORA-AnalyzerPRO.ps1"
$integrationPath  = Join-Path $SessionDir "AURORA-ProgressManager-Integration.ps1"
$languagePath     = Join-Path $GUIDir "AURORA-Language.psd1"

Write-It "AURORA-AnalyzerPRO-Engine.ps1 存在" (Test-Path $proEnginePath)
Write-It "AURORA-AnalyzerPRO.ps1 存在" (Test-Path $proEntryPoint)
Write-It "AURORA-ProgressManager-Integration.ps1 存在" (Test-Path $integrationPath)
Write-It "AURORA-Language.psd1 存在" (Test-Path $languagePath)

Write-Context "旧文件应已删除"

$oldFiles = @(
    @{ Path = "AURORA-AnalyzerCHSPRO.ps1";           Label = "CHSPRO 入口文件" },
    @{ Path = "AURORA-AnalyzerENGPRO.ps1";           Label = "ENGPRO 入口文件" },
    @{ Path = "AURORA-AnalyzerCHSPRO-Engine.ps1";    Label = "CHSPRO 引擎文件" },
    @{ Path = "AURORA-AnalyzerENGPRO-Engine.ps1";    Label = "ENGPRO 引擎文件" },
    @{ Path = "AURORA-ProgressManager-Integration-CHS.ps1"; Label = "CHS Integration 文件" },
    @{ Path = "AURORA-ProgressManager-Integration-ENG.ps1"; Label = "ENG Integration 文件" }
)

$allOldDeleted = $true
$deletedDetails = @()
foreach ($of in $oldFiles) {
    $fullPath = Join-Path $PRODir $of.Path
    # 也在 Session 目录搜索 Integration 文件
    if ($of.Path -like "*Integration*") {
        $fullPath = Join-Path $SessionDir $of.Path
    }
    $exists = Test-Path $fullPath
    if ($exists) {
        $allOldDeleted = $false
        $deletedDetails += "$($of.Label) 仍然存在: $fullPath"
    }
}
Write-It "所有旧文件已被删除（CHSPRO, ENGPRO, Integration-CHS, Integration-ENG）" $allOldDeleted ($deletedDetails -join "; ")

# ==========================================
# 2. 语言资源完整性测试
# ==========================================
Write-Describe "语言资源完整性测试"

Write-Context "加载语言资源"

$langResource = $null
$langLoadSuccess = $false
$langRawContent = $null

# 尝试使用 Import-LocalizedData 加载
try {
    $langResource = Import-LocalizedData -FileName "AURORA-Language.psd1" -BaseDirectory $GUIDir -ErrorAction Stop
    $langLoadSuccess = $true
} catch {
    # Import-LocalizedData 失败，回退到手动解析
    Write-It "Import-LocalizedData 加载方式 (psd1 格式严格，可能因引号嵌套而失败)" $false "回退到手动解析模式"
}

# 回退方案：直接读取原始内容进行键分析
if (-not $langLoadSuccess) {
    try {
        $langRawContent = Get-Content $languagePath -Raw -Encoding UTF8
        $langLoadSuccess = $true
    } catch {
        Write-It "成功读取 AURORA-Language.psd1 原始内容" $false $_.Exception.Message
    }
}

Write-It "成功加载 AURORA-Language.psd1" $langLoadSuccess

Write-Context "CHS 和 ENG 键一致性"

if ($langLoadSuccess -and $langResource) {
    # 使用 Import-LocalizedData 加载的方式
    $chsKeys = $langResource["CHS"].Keys
    $engKeys = $langResource["ENG"].Keys
    $chsCount = ($chsKeys | Measure-Object).Count
    $engCount = ($engKeys | Measure-Object).Count

    Write-It "CHS 语言包键数量: $chsCount" ($chsCount -gt 0)
    Write-It "ENG 语言包键数量: $engCount" ($engCount -gt 0)

    $keysMatch = $chsCount -eq $engCount
    Write-It "CHS 和 ENG 键数量一致 ($chsCount vs $engCount)" $keysMatch

    if (-not $keysMatch) {
        $missingInEng = $chsKeys | Where-Object { $_ -notin $engKeys }
        $missingInChs = $engKeys | Where-Object { $_ -notin $chsKeys }
        $details = @()
        if ($missingInEng) { $details += "ENG 缺少: $($missingInEng -join ', ')" }
        if ($missingInChs) { $details += "CHS 缺少: $($missingInChs -join ', ')" }
        Write-It "键差异详情" $false ($details -join "; ")
    }

    Write-Context "关键语言键存在性"

    $criticalKeys = @(
        "Launcher_Required",
        "Session_Detected",
        "Stage_ProcessingLog",
        "Report_Generating",
        "Banner_Line1",
        "Perf_Evaluating",
        "Cache_Match",
        "HighRisk_Scanning",
        "Health_Assessment",
        "SmartAnalysis_Invoking",
        "Final_Complete"
    )

    foreach ($key in $criticalKeys) {
        $chsHas = $langResource["CHS"].ContainsKey($key)
        $engHas = $langResource["ENG"].ContainsKey($key)
        $bothHave = $chsHas -and $engHas
        Write-It "关键键 '$key' 在 CHS 和 ENG 中均存在" $bothHave "CHS: $chsHas, ENG: $engHas"
    }
} elseif ($langLoadSuccess -and $langRawContent) {
    # 使用原始内容解析的方式（正则匹配键名）
    $chsKeyPattern = '"(?<key>[^"]+)"\s*='
    $chsSection = $langRawContent -split 'ENG\s*=\s*@{' | Select-Object -First 1
    $engSection = ($langRawContent -split 'ENG\s*=\s*@{')[-1]

    $chsKeys = [regex]::Matches($chsSection, $chsKeyPattern) | ForEach-Object { $_.Groups['key'].Value }
    $engKeys = [regex]::Matches($engSection, $chsKeyPattern) | ForEach-Object { $_.Groups['key'].Value }
    $chsCount = ($chsKeys | Measure-Object).Count
    $engCount = ($engKeys | Measure-Object).Count

    Write-It "CHS 语言包键数量 (手动解析): $chsCount" ($chsCount -gt 0)
    Write-It "ENG 语言包键数量 (手动解析): $engCount" ($engCount -gt 0)

    $keysMatch = $chsCount -eq $engCount
    Write-It "CHS 和 ENG 键数量一致 ($chsCount vs $engCount)" $keysMatch

    Write-Context "关键语言键存在性 (手动解析)"

    $criticalKeys = @(
        "Launcher_Required",
        "Session_Detected",
        "Stage_ProcessingLog",
        "Report_Generating",
        "Banner_Line1",
        "Perf_Evaluating",
        "Cache_Match",
        "HighRisk_Scanning",
        "Health_Assessment",
        "SmartAnalysis_Invoking",
        "Final_Complete"
    )

    foreach ($key in $criticalKeys) {
        $chsHas = $chsKeys -contains $key
        $engHas = $engKeys -contains $key
        $bothHave = $chsHas -and $engHas
        Write-It "关键键 '$key' 在 CHS 和 ENG 中均存在" $bothHave "CHS: $chsHas, ENG: $engHas"
    }
}

# ==========================================
# 3. 语法检查测试
# ==========================================
Write-Describe "语法检查测试"

Write-Context "PRO-Engine.ps1 语法分析"

$engineContent = $null
$engineReadSuccess = $false
if (Test-Path $proEnginePath) {
    try {
        $engineContent = Get-Content $proEnginePath -Raw -Encoding UTF8
        $engineReadSuccess = $true
    } catch {
        Write-It "成功读取 PRO-Engine.ps1 文件内容" $false $_.Exception.Message
    }
}

Write-It "成功读取 PRO-Engine.ps1 文件内容" $engineReadSuccess

if ($engineReadSuccess -and $engineContent) {
    Write-Context "PowerShell Tokenize 语法检查"

    $tokens = $null
    $parseErrors = @()
    try {
        $tokens = [System.Management.Automation.PSParser]::Tokenize($engineContent, [ref]$parseErrors)
        $tokenizeSuccess = $true
    } catch {
        $tokenizeSuccess = $false
        Write-It "PowerShell Tokenize 语法检查通过" $false $_.Exception.Message
    }

    Write-It "PowerShell Tokenize 语法检查通过" $tokenizeSuccess

    if ($tokenizeSuccess -and $tokens) {
        # 检查未闭合的引号
        $stringTokens = $tokens | Where-Object { $_.Type -eq "String" }
        Write-It "字符串 Token 解析正常 (共 $($stringTokens.Count) 个)" ($stringTokens.Count -gt 0)

        # 检查注释 token
        $commentTokens = $tokens | Where-Object { $_.Type -eq "Comment" }
        Write-It "注释 Token 解析正常 (共 $($commentTokens.Count) 个)" ($commentTokens.Count -gt 0)

        # 检查关键字
        $keywordTokens = $tokens | Where-Object { $_.Type -eq "Keyword" }
        Write-It "关键字 Token 解析正常 (共 $($keywordTokens.Count) 个)" ($keywordTokens.Count -gt 0)
    }

    Write-Context "基本语法结构检查"

    # 检查未闭合的括号 (简化检查)
    $openBraceCount = ([regex]::Matches($engineContent, '\{')).Count
    $closeBraceCount = ([regex]::Matches($engineContent, '\}')).Count
    $braceBalanced = $openBraceCount -eq $closeBraceCount
    Write-It "花括号平衡 (左: $openBraceCount, 右: $closeBraceCount)" $braceBalanced

    $openParenCount = ([regex]::Matches($engineContent, '\(')).Count
    $closeParenCount = ([regex]::Matches($engineContent, '\)')).Count
    $parenBalanced = $openParenCount -eq $closeParenCount
    Write-It "圆括号平衡 (左: $openParenCount, 右: $closeParenCount)" $parenBalanced

    $openBracketCount = ([regex]::Matches($engineContent, '\[')).Count
    $closeBracketCount = ([regex]::Matches($engineContent, '\]')).Count
    $bracketBalanced = $openBracketCount -eq $closeBracketCount
    Write-It "方括号平衡 (左: $openBracketCount, 右: $closeBracketCount)" $bracketBalanced
}

# ==========================================
# 4. 引用一致性测试
# ==========================================
Write-Describe "引用一致性测试"

Write-Context "Integration 文件引用"

if ($engineReadSuccess -and $engineContent) {
    # 检查是否引用了统一的 Integration 文件
    $hasUnifiedIntegration = $engineContent -match 'AURORA-ProgressManager-Integration\.ps1'
    Write-It "引用统一的 Integration 文件" $hasUnifiedIntegration

    # 检查是否还有对分裂版本的引用
    $hasCHSIntegration = $engineContent -match 'Integration-CHS'
    $hasENGIntegration = $engineContent -match 'Integration-ENG'
    Write-It "不存在 Integration-CHS 引用" (-not $hasCHSIntegration)
    Write-It "不存在 Integration-ENG 引用" (-not $hasENGIntegration)
}

Write-Context "Save-PROProgress 引用一致性"

if ($engineReadSuccess -and $engineContent) {
    $chsProgressCount = ([regex]::Matches($engineContent, 'Save-CHSProgress')).Count
    $engProgressCount = ([regex]::Matches($engineContent, 'Save-ENGProgress')).Count
    $proProgressCount = ([regex]::Matches($engineContent, 'Save-PROProgress')).Count

    Write-It "不存在 Save-CHSProgress 引用 ($chsProgressCount 处)" ($chsProgressCount -eq 0) "$chsProgressCount 处"
    Write-It "不存在 Save-ENGProgress 引用 ($engProgressCount 处)" ($engProgressCount -eq 0) "$engProgressCount 处"
    Write-It "使用统一的 Save-PROProgress ($proProgressCount 处)" ($proProgressCount -gt 0) "$proProgressCount 处"
}

# 检查 PRO.ps1 入口文件
$proPsContent = $null
if (Test-Path $proEntryPoint) {
    try {
        $proPsContent = Get-Content $proEntryPoint -Raw -Encoding UTF8
    } catch {}
}

if ($proPsContent) {
    Write-It "PRO.ps1 不存在 Save-CHSProgress 引用" (-not ($proPsContent -match 'Save-CHSProgress'))
    Write-It "PRO.ps1 不存在 Save-ENGProgress 引用" (-not ($proPsContent -match 'Save-ENGProgress'))
    Write-It "PRO.ps1 引用统一的 PRO-Engine" ($proPsContent -match 'AURORA-AnalyzerPRO-Engine\.ps1')
}

# ==========================================
# 5. 硬编码中文检查
# ==========================================
Write-Describe "硬编码中文检查"

Write-Context "扫描 PRO-Engine.ps1 中的硬编码中文"

$hardcodedChinese = @()
$lineNumber = 0

if ($engineReadSuccess) {
    $lines = Get-Content $proEnginePath -Encoding UTF8
    $totalLines = $lines.Count

    for ($i = 0; $i -lt $totalLines; $i++) {
        $line = $lines[$i]
        $lineNum = $i + 1

        # 跳过注释行 (以 # 开头的行，但不跳过 <# ... #> 块注释内的内容)
        $trimmedLine = $line.TrimStart()
        if ($trimmedLine -match '^#') {
            continue
        }

        # 检测 Write-Host, Write-CustomProgress, Save-PROProgress 中的中文
        if ($line -match '(Write-Host|Write-CustomProgress|Save-PROProgress|\.CustomStage\s+|\.CurrentTask\s+)') {
            # 检测中文字符 (Unicode 范围 \u4e00-\u9fff)
            if ($line -match '[\u4e00-\u9fff]') {
                # 进一步检查是否是语言资源引用（如 $script:Loc[...]）
                # 如果是资源引用中的 format 参数中的中文（变量内插），也算硬编码
                $hasLiteralChinese = $false
                $chineseMatches = [regex]::Matches($line, '[\u4e00-\u9fff]+')
                foreach ($match in $chineseMatches) {
                    $chineseText = $match.Value
                    # 检查该中文是否在 $script:Loc 内部（不算硬编码）
                    # 检查该中文是否在注释中
                    if ($line -notmatch '\$script:Loc\[.*' + [regex]::Escape($chineseText)) {
                        # 不在 Loc 引用中，判定为硬编码
                        $hasLiteralChinese = $true
                        break
                    }
                }

                if ($hasLiteralChinese) {
                    $hardcodedChinese += @{ Line = $lineNum; Content = $line.Trim() }
                }
            }
        }
    }
}

if ($hardcodedChinese.Count -eq 0) {
    Write-It "PRO-Engine.ps1 中未发现硬编码中文" $true
} else {
    Write-It "PRO-Engine.ps1 中未发现硬编码中文" $false "发现 $($hardcodedChinese.Count) 处"
    Write-Host "    发现的硬编码中文:" -ForegroundColor Yellow
    foreach ($hc in $hardcodedChinese) {
        # 截断过长的行
        $displayContent = if ($hc.Content.Length -gt 120) { $hc.Content.Substring(0, 120) + "..." } else { $hc.Content }
        Write-Host "      行 $($hc.Line): $displayContent" -ForegroundColor Red
    }
}

Write-Context "扫描 PRO.ps1 中的硬编码中文"

$proPsHardcodedChinese = @()
if ($proPsContent) {
    $lines = Get-Content $proEntryPoint -Encoding UTF8
    $totalLines = $lines.Count

    for ($i = 0; $i -lt $totalLines; $i++) {
        $line = $lines[$i]
        $lineNum = $i + 1

        # 跳过注释行
        $trimmedLine = $line.TrimStart()
        if ($trimmedLine -match '^#') {
            continue
        }

        # 检测 Write-Host 中的中文
        if ($line -match 'Write-Host' -and $line -match '[\u4e00-\u9fff]') {
            $proPsHardcodedChinese += @{ Line = $lineNum; Content = $line.Trim() }
        }
    }
}

if ($proPsHardcodedChinese.Count -eq 0) {
    Write-It "PRO.ps1 中未发现硬编码中文" $true
} else {
    Write-It "PRO.ps1 中未发现硬编码中文" $false "发现 $($proPsHardcodedChinese.Count) 处"
    Write-Host "    发现的硬编码中文:" -ForegroundColor Yellow
    foreach ($hc in $proPsHardcodedChinese) {
        $displayContent = if ($hc.Content.Length -gt 120) { $hc.Content.Substring(0, 120) + "..." } else { $hc.Content }
        Write-Host "      行 $($hc.Line): $displayContent" -ForegroundColor Red
    }
}

# ==========================================
# 6. build.ps1 引用检查
# ==========================================
Write-Describe "build.ps1 引用检查"

Write-Context "检查构建脚本中的旧文件引用"

$buildPsPath = Join-Path $ProjectRoot "build.ps1"
$buildContent = $null
$buildReadSuccess = $false

if (Test-Path $buildPsPath) {
    try {
        $buildContent = Get-Content $buildPsPath -Raw -Encoding UTF8
        $buildReadSuccess = $true
    } catch {
        Write-It "成功读取 build.ps1" $false $_.Exception.Message
    }
}

Write-It "成功读取 build.ps1" $buildReadSuccess

if ($buildReadSuccess -and $buildContent) {
    $oldReferences = @(
        @{ Pattern = "CHSPRO";           Label = "CHSPRO 文件引用" },
        @{ Pattern = "ENGPRO";           Label = "ENGPRO 文件引用" },
        @{ Pattern = "Integration-CHS"; Label = "Integration-CHS 文件引用" },
        @{ Pattern = "Integration-ENG"; Label = "Integration-ENG 文件引用" },
        @{ Pattern = "AnalyzerCHSPRO";  Label = "AnalyzerCHSPRO 文件引用" },
        @{ Pattern = "AnalyzerENGPRO";  Label = "AnalyzerENGPRO 文件引用" }
    )

    foreach ($ref in $oldReferences) {
        $hasRef = [bool]($buildContent -match $ref.Pattern)
        Write-It "build.ps1 不存在 $($ref.Label)" (-not $hasRef)
    }

    Write-Context "检查必需的新文件引用"

    $newReferences = @(
        @{ Pattern = "AURORA-AnalyzerPRO-Engine\.ps1";          Label = "PRO-Engine 文件引用" },
        @{ Pattern = "AURORA-AnalyzerPRO\.ps1";                 Label = "PRO 入口文件引用" },
        @{ Pattern = "AURORA-ProgressManager-Integration\.ps1"; Label = "统一 Integration 文件引用" },
        @{ Pattern = "AURORA-Language\.psd1";                   Label = "语言资源文件引用" }
    )

    foreach ($ref in $newReferences) {
        $hasRef = [bool]($buildContent -match $ref.Pattern)
        Write-It "build.ps1 存在 $($ref.Label)" $hasRef
    }
}

# ==========================================
# 测试汇总
# ==========================================
Write-Host "`n" -NoNewline
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  测试汇总" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan

$totalTests = $script:TestPassed + $script:TestFailed
$passRate = if ($totalTests -gt 0) { [Math]::Round(($script:TestPassed / $totalTests) * 100, 1) } else { 0 }

Write-Host ""
Write-Host "  ✅ 通过: $($script:TestPassed)" -ForegroundColor Green
Write-Host "  ❌ 失败: $($script:TestFailed)" -ForegroundColor Red
Write-Host "  📊 总数: $totalTests" -ForegroundColor White
Write-Host "  📈 通过率: $passRate%" -ForegroundColor $(if ($passRate -ge 90) { "Green" } elseif ($passRate -ge 70) { "Yellow" } else { "Red" })

Write-Host "`n========================================" -ForegroundColor Cyan

if ($script:TestFailed -eq 0) {
    Write-Host "  🎉 所有测试通过！PRO 引擎合并验证成功！" -ForegroundColor Green
} elseif ($passRate -ge 80) {
    Write-Host "  ⚠️  大部分测试通过，请检查失败项" -ForegroundColor Yellow
} else {
    Write-Host "  ❌ 测试通过率过低，请修复问题后重新测试" -ForegroundColor Red
}
Write-Host "========================================`n" -ForegroundColor Cyan

# 返回测试状态（用于 CI/CD）
exit $(if ($script:TestFailed -eq 0) { 0 } else { 1 })
