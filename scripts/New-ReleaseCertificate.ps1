#Requires -Version 7.2
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$keyDirectory = Join-Path $root '.release-signing'
$pfxPath = Join-Path $keyDirectory 'LayoutAwareSearch.pfx'
$passwordPath = Join-Path $keyDirectory 'password.dpapi'
if ((Test-Path -LiteralPath $pfxPath) -or (Test-Path -LiteralPath $passwordPath)) {
    throw 'Signing material already exists. Keep the existing key for future releases; this script never overwrites it.'
}

# Generate in memory. This neither installs a certificate nor changes Windows trust.
$rsa = [System.Security.Cryptography.RSA]::Create(3072)
try {
    $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=pavel-buiko', $rsa, [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $request.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($false, $false, 0, $true))
    $request.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new(
        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature, $true))
    $usages = [System.Security.Cryptography.OidCollection]::new()
    [void]$usages.Add([System.Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.3'))
    $request.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($usages, $true))
    $certificate = $request.CreateSelfSigned([DateTimeOffset]::UtcNow.AddMinutes(-5), [DateTimeOffset]::UtcNow.AddYears(3))
    try {
        $password = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
        $protectedPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
        [void](New-Item -ItemType Directory -Path $keyDirectory)
        [System.IO.File]::WriteAllBytes($pfxPath, $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $password))
        $protectedPassword | ConvertFrom-SecureString | Set-Content -LiteralPath $passwordPath
        [System.IO.File]::WriteAllBytes((Join-Path $keyDirectory 'LayoutAwareSearch.cer'), $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
        Write-Host "Created local signing key in $keyDirectory"
        Write-Host "Public certificate thumbprint: $($certificate.Thumbprint)"
        Write-Host "Expires: $($certificate.NotAfter.ToString('u'))"
        Write-Host 'Keep this directory backed up securely. The DPAPI password file is tied to this Windows user.'
    }
    finally { $certificate.Dispose() }
}
finally { $rsa.Dispose() }
