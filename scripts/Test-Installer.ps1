#Requires -Version 7.2
# Exercises the Windows PowerShell installer with certificate trust and installation mocked.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $root ('artifacts\installer-tests-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $fixture)
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'installer\Install.ps1') -Destination $fixture
$rsa = [System.Security.Cryptography.RSA]::Create(2048)
try {
    $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=Installer Test Only', $rsa, [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $certificate = $request.CreateSelfSigned([DateTimeOffset]::UtcNow.AddMinutes(-5), [DateTimeOffset]::UtcNow.AddHours(1))
    try {
        [IO.File]::WriteAllBytes((Join-Path $fixture 'test.cer'), $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
        [IO.File]::WriteAllText((Join-Path $fixture 'test.msix'), 'Installer fixture: never installed.')
        $baseInfo = @{
            Version = '0.1.0.0'; Architecture = 'x64'; Package = 'test.msix'; Certificate = 'test.cer'
            PackageSha256 = (Get-FileHash -LiteralPath (Join-Path $fixture 'test.msix')).Hash
            CertificateSha256 = $certificate.GetCertHashString([System.Security.Cryptography.HashAlgorithmName]::SHA256)
            Publisher = $certificate.Subject
        }
    }
    finally { $certificate.Dispose() }
}
finally { $rsa.Dispose() }

$wrapper = @'
$ErrorActionPreference = 'Stop'
$env:PROCESSOR_ARCHITEW6432 = ''
$env:PROCESSOR_ARCHITECTURE = $env:LAYOUT_INSTALLER_TEST_ARCH
function Test-Path {
    [CmdletBinding(DefaultParameterSetName='Path')]
    param(
        [Parameter(ParameterSetName='Path', Position=0)][string[]]$Path,
        [Parameter(ParameterSetName='LiteralPath', Mandatory=$true)][string[]]$LiteralPath,
        [Microsoft.PowerShell.Commands.TestPathType]$PathType = 'Any'
    )
    $requestedPath = @(if ($PSCmdlet.ParameterSetName -eq 'LiteralPath') { $LiteralPath } else { $Path })
    if ($requestedPath.Count -eq 1 -and $requestedPath[0] -like 'Cert:\LocalMachine\TrustedPeople\*') { return $env:LAYOUT_INSTALLER_TEST_TRUSTED -eq 'yes' }
    return Microsoft.PowerShell.Management\Test-Path @PSBoundParameters
}
function Import-Certificate { throw 'UNEXPECTED CERTIFICATE IMPORT' }
function Start-Process { throw 'UNEXPECTED ELEVATION' }
function Read-Host { param($Prompt); return '' }
function Add-AppxPackage { param($Path); Write-Output 'MOCK_INSTALL_SUCCESS' }
& (Join-Path $PSScriptRoot 'Install.ps1')
exit $LASTEXITCODE
'@
Set-Content -LiteralPath (Join-Path $fixture 'Run-Test.ps1') -Value $wrapper -Encoding utf8
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$cases = @(
    @{ Name = 'AMD64 maps to x64'; Arch = 'AMD64'; Trusted = 'yes'; Change = @{}; Expected = 'MOCK_INSTALL_SUCCESS'; Exit = 0 },
    @{ Name = 'ARM64 package selection'; Arch = 'ARM64'; Trusted = 'yes'; Change = @{ Architecture = 'ARM64' }; Expected = 'MOCK_INSTALL_SUCCESS'; Exit = 0 },
    @{ Name = 'Wrong architecture is rejected'; Arch = 'ARM64'; Trusted = 'yes'; Change = @{}; Expected = 'Download the ARM64 release'; Exit = 1 },
    @{ Name = 'Altered package is rejected'; Arch = 'AMD64'; Trusted = 'yes'; Change = @{ PackageSha256 = '0000' }; Expected = 'MSIX checksum is incorrect'; Exit = 1 },
    @{ Name = 'Wrong certificate is rejected'; Arch = 'AMD64'; Trusted = 'yes'; Change = @{ CertificateSha256 = '0000' }; Expected = 'signing certificate does not match'; Exit = 1 },
    @{ Name = 'Path traversal is rejected'; Arch = 'AMD64'; Trusted = 'yes'; Change = @{ Package = '..\test.msix' }; Expected = 'Invalid filename'; Exit = 1 },
    @{ Name = 'Declining trust does not elevate or install'; Arch = 'AMD64'; Trusted = 'no'; Change = @{}; Expected = 'Installation cancelled'; Exit = 1 }
)
foreach ($case in $cases) {
    $info = $baseInfo.Clone()
    foreach ($key in $case.Change.Keys) { $info[$key] = $case.Change[$key] }
    $info | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fixture 'release-info.json') -Encoding utf8
    $env:LAYOUT_INSTALLER_TEST_ARCH = $case.Arch
    $env:LAYOUT_INSTALLER_TEST_TRUSTED = $case.Trusted
    $output = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture 'Run-Test.ps1') 2>&1 | Out-String
    if ($LASTEXITCODE -ne $case.Exit -or !$output.Contains($case.Expected) -or $output.Contains('UNEXPECTED')) {
        throw "Installer check failed: $($case.Name). Output: $output"
    }
    Write-Host "PASS $($case.Name)"
}
Remove-Item Env:\LAYOUT_INSTALLER_TEST_ARCH, Env:\LAYOUT_INSTALLER_TEST_TRUSTED
Write-Host "$($cases.Count) installer checks passed without importing certificates or installing apps."
$global:LASTEXITCODE = 0
