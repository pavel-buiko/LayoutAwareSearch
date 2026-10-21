#Requires -Version 5.1
[CmdletBinding()]
param([switch]$TrustCertificateOnly)

$ErrorActionPreference = 'Stop'
try {
    $info = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'release-info.json') -Raw | ConvertFrom-Json
    foreach ($name in @($info.Certificate, $info.Package)) {
        if ([System.IO.Path]::GetFileName($name) -ne $name) { throw 'Invalid filename in release-info.json.' }
    }
    $certificatePath = Join-Path $PSScriptRoot $info.Certificate
    $packagePath = Join-Path $PSScriptRoot $info.Package
    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certificatePath)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try { $certificateHash = ([BitConverter]::ToString($sha256.ComputeHash($certificate.RawData))).Replace('-', '') }
    finally { $sha256.Dispose() }
    if ($certificateHash -ne $info.CertificateSha256 -or $certificate.Subject -ne $info.Publisher) {
        throw 'The signing certificate does not match release-info.json.'
    }
    if ((Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash -ne $info.PackageSha256) {
        throw 'The MSIX checksum is incorrect. Download and extract the release again.'
    }
    if ($certificate.NotAfter -le (Get-Date)) { throw 'The signing certificate has expired.' }

    if ($TrustCertificateOnly) {
        $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
        if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Certificate trust requires administrator permission.' }
        Import-Certificate -FilePath $certificatePath -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Out-Null
        exit 0
    }

    $deviceArchitecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    if ($deviceArchitecture -eq 'AMD64') { $deviceArchitecture = 'x64' }
    if ($deviceArchitecture -ne $info.Architecture) { throw "Download the $deviceArchitecture release for this computer." }
    Write-Host "Layout-Aware Search $($info.Version) ($($info.Architecture))"
    $trusted = Test-Path -LiteralPath "Cert:\LocalMachine\TrustedPeople\$($certificate.Thumbprint)"
    if (!$trusted) {
        Write-Host 'This preview uses a self-signed code-signing certificate.'
        Write-Host 'Trusting it allows Windows to install packages signed by this key.'
        Write-Host "Publisher: $($certificate.Subject)"
        Write-Host "Certificate SHA256: $certificateHash"
        Write-Host 'Compare this fingerprint with the GitHub release before continuing.'
        if ((Read-Host 'Type YES to trust this certificate, or press Enter to cancel') -cne 'YES') {
            throw 'Installation cancelled; the certificate was not imported.'
        }
        # Only certificate trust is elevated. App installation stays under the original user.
        $elevationArguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -TrustCertificateOnly'
        $process = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
            -ArgumentList $elevationArguments -Verb RunAs -WindowStyle Hidden -Wait -PassThru
        if ($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath "Cert:\LocalMachine\TrustedPeople\$($certificate.Thumbprint)")) {
            throw 'Certificate trust was not granted. No application was installed.'
        }
    }

    Add-AppxPackage -Path $packagePath
    Write-Host 'Installed. Restart Command Palette and enable Layout-Aware Search and its fallback in extension settings.'
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
