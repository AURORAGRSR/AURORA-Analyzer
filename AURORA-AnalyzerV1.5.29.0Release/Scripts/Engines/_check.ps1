$tokens = $null
$errors = $null
$files = @(
    'g:\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory-Dev\AURORA-Analyzer-Factory\Scripts\Core\AURORA-CoreEngine.ps1',
    'g:\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory-Dev\AURORA-Analyzer-Factory\Scripts\Engines\AURORA-SmartEngine-CLI.ps1',
    'g:\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory-Dev\AURORA-Analyzer-Factory\Scripts\Engines\AURORA-SmartEngine.ps1',
    'g:\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory-Dev\AURORA-Analyzer-Factory\Scripts\Security\AURORA-SecurityModule.ps1',
    'g:\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory-Dev\AURORA-Analyzer-Factory\Scripts\PRO\AURORA-AnalyzerPRO.ps1'
)
$allOk = $true
foreach ($file in $files) {
    $fname = Split-Path $file -Leaf
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors)
    if ($errors.Count -eq 0) {
        Write-Host ($fname + ' = OK')
    } else {
        $allOk = $false
        Write-Host ($fname + ' = ' + $errors.Count + ' ERRORS')
        foreach ($e in $errors | Select-Object -First 5) {
            Write-Host ('  L' + $e.Extent.StartLineNumber + ': ' + $e.Message)
        }
    }
}
if ($allOk) { Write-Host '=== ALL SYNTAX OK ===' }
