# test-rsa-verification.ps1 - 直接测试 RSA 密钥对是否匹配

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent

Write-Host "=== RSA Key Pair Matching Test ===" -ForegroundColor Cyan
Write-Host ""

# [1] Extract GUI public key
Write-Host "[1/4] Extracting GUI public key..." -ForegroundColor Cyan
$guiPs1Path = Join-Path $ScriptDir "Scripts\AURORA-AnalyzerLauncherGUI.ps1"
$guiContent = Get-Content $guiPs1Path -Raw -Encoding UTF8

$guiKeyPattern = '(?s)<RSAKeyValue><Modulus>(.*?)</Modulus><Exponent>(.*?)</Exponent></RSAKeyValue>'
$guiMatch = [regex]::Match($guiContent, $guiKeyPattern)

if (-not $guiMatch.Success) {
    Write-Host "  ✗ Failed to extract GUI public key" -ForegroundColor Red
    exit 1
}

$guiModulus = $guiMatch.Groups[1].Value
$guiExponent = $guiMatch.Groups[2].Value
$guiPublicKeyXml = "<RSAKeyValue><Modulus>$guiModulus</Modulus><Exponent>$guiExponent></RSAKeyValue>"

Write-Host "  ✓ GUI Public Key extracted" -ForegroundColor Green
Write-Host "    Modulus (first 50 chars): $($guiModulus.Substring(0, 50))..." -ForegroundColor Gray

# [2] Try to extract EXE private key from C# source
Write-Host ""
Write-Host "[2/4] Looking for C# source to extract EXE private key..." -ForegroundColor Cyan
$csPath = Join-Path $ScriptDir "AuroraLauncher.cs"

if (Test-Path $csPath) {
    $csContent = Get-Content $csPath -Raw -Encoding UTF8
    
    $csKeyPattern = 'static readonly string RsaPrivateKeyXml = @"(.*?)"'
    $csMatch = [regex]::Match($csContent, $csKeyPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    if ($csMatch.Success) {
        $privateKeyXml = $csMatch.Groups[1].Value
        Write-Host "  ✓ C# source found, extracting private key..." -ForegroundColor Green
        
        # Extract modulus from private key
        $privModulusPattern = '<Modulus>(.*?)</Modulus>'
        $privModulusMatch = [regex]::Match($privateKeyXml, $privModulusPattern)
        
        if ($privModulusMatch.Success) {
            $privModulus = $privModulusMatch.Groups[1].Value
            Write-Host "  ✓ EXE Private Key Modulus extracted" -ForegroundColor Green
            Write-Host "    Modulus (first 50 chars): $($privModulus.Substring(0, 50))..." -ForegroundColor Gray
            
            # Compare modulus
            Write-Host ""
            Write-Host "[3/4] Comparing RSA modulus..." -ForegroundColor Cyan
            
            if ($guiModulus -eq $privModulus) {
                Write-Host "  ✓ RSA modulus MATCH - Keys are from same pair!" -ForegroundColor Green
            } else {
                Write-Host "  ✗ RSA modulus DO NOT MATCH - Keys are from different pairs!" -ForegroundColor Red
                Write-Host ""
                Write-Host "This is the ROOT CAUSE of the problem!" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "GUI Modulus:  $($guiModulus.Substring(0, 80))..." -ForegroundColor Gray
                Write-Host "EXE Modulus:  $($privModulus.Substring(0, 80))..." -ForegroundColor Gray
            }
        } else {
            Write-Host "  ✗ Failed to extract modulus from private key" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✗ C# source not found or key pattern not found" -ForegroundColor Yellow
        Write-Host "     (This is normal if build.ps1 cleaned up after compilation)" -ForegroundColor Gray
    }
} else {
    Write-Host "  ℹ C# source not found (build.ps1 deletes it after compilation)" -ForegroundColor Yellow
}

# [4] Test signature verification with current GUI key
Write-Host ""
Write-Host "[4/4] Testing signature verification with GUI key..." -ForegroundColor Cyan

try {
    # Generate test data
    $testNonce = "test_nonce_12345"
    $testTimestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $testPayload = "test_payload_67890"
    $testInput = "${testNonce}:${testTimestamp}:${testPayload}"
    $testBytes = [System.Text.Encoding]::UTF8.GetBytes($testInput)
    
    # Try to verify with GUI key (we can't sign without private key, but we can check if key is valid)
    $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider
    $rsa.FromXmlString($guiPublicKeyXml)
    
    Write-Host "  ✓ GUI public key is valid XML and can be loaded" -ForegroundColor Green
    Write-Host "  ✓ Key size: $($rsa.KeySize) bits" -ForegroundColor Green
    
    $rsa.Dispose()
} catch {
    Write-Host "  ✗ GUI public key is invalid: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host ""

if ($guiModulus -and $privModulus -and $guiModulus -ne $privModulus) {
    Write-Host "DIAGNOSIS: RSA keys DO NOT match!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Root cause:" -ForegroundColor Yellow
    Write-Host "  The C# source (AuroraLauncher.cs) was not updated during build." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Solution:" -ForegroundColor Cyan
    Write-Host "  1. Delete AuroraLauncher.cs if it exists" -ForegroundColor White
    Write-Host "  2. Run build.ps1 again in a clean session" -ForegroundColor White
    Write-Host "  3. Make sure build.ps1 updates the C# source before compilation" -ForegroundColor White
} else {
    Write-Host "DIAGNOSIS: Unable to fully verify (C# source not available)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This is expected if build.ps1 cleaned up the C# source." -ForegroundColor Gray
    Write-Host "The GUI key looks valid, so the issue might be:" -ForegroundColor Yellow
    Write-Host "  1. EXE was compiled with old/different private key" -ForegroundColor Yellow
    Write-Host "  2. GUI file was manually edited after build" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Recommended action:" -ForegroundColor Cyan
    Write-Host "  Run build.ps1 again, making sure:" -ForegroundColor White
    Write-Host "  - No manual edits to files during build" -ForegroundColor White
    Write-Host "  - Build completes without errors" -ForegroundColor White
    Write-Host "  - Use the freshly built EXE immediately" -ForegroundColor White
}
