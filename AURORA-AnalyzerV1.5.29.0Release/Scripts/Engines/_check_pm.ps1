$tokens = $null
$errors = $null

$files = @(
    'g:\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory-Dev\AURORA-Analyzer-Factory\Scripts\Session\AURORA-ProgressManager.ps1',
    'g:\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory-Dev\AURORA-Analyzer-Factory\Scripts\Session\AURORA-ProgressManager-Integration.ps1',
    'g:\PowerShellBat\AURORA-Analyzer\AURORA-Analyzer-Factory-Dev\AURORA-Analyzer-Factory\Scripts\Core\AURORA-CoreEngine.ps1'
)

foreach ($file in $files) {
    $fname = Split-Path $file -Leaf
    # Check BOM
    $bytes = [System.IO.File]::ReadAllBytes($file)
    $hasBom = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $bomStr = if ($hasBom) { "UTF-8 BOM" } else { "NO BOM" }

    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors)
    if ($errors.Count -eq 0) {
        Write-Host "$fname [$bomStr]: Syntax OK (0 errors)"
    } else {
        Write-Host "$fname [$bomStr]: $($errors.Count) errors"
        foreach ($e in $errors | Select-Object -First 5) {
            Write-Host ("  L" + $e.Extent.StartLineNumber + ": " + $e.Message)
        }
    }
}
