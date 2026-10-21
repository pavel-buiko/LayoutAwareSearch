#Requires -Version 7.2
[CmdletBinding()]
param(
    [ValidateSet('x64', 'ARM64')]
    [string[]]$Architectures = @('x64', 'ARM64')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$project = Join-Path $root 'LayoutAwareSearch\LayoutAwareSearch.csproj'
$manifestPath = Join-Path $root 'LayoutAwareSearch\Package.appxmanifest'
[xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
$packageVersion = [version]$manifest.Package.Identity.Version
$version = '{0}.{1}.{2}' -f $packageVersion.Major, $packageVersion.Minor, $packageVersion.Build
$outputRoot = Join-Path $root "artifacts\v$version"
$keyDirectory = Join-Path $root '.release-signing'
$pfxPath = Join-Path $keyDirectory 'LayoutAwareSearch.pfx'
$passwordPath = Join-Path $keyDirectory 'password.dpapi'
if (!(Test-Path -LiteralPath $pfxPath) -or !(Test-Path -LiteralPath $passwordPath)) {
    throw 'Signing material is missing. Run scripts/New-ReleaseCertificate.ps1 once on Windows.'
}

$securePassword = (Get-Content -LiteralPath $passwordPath -Raw).Trim() | ConvertTo-SecureString
$password = [System.Net.NetworkCredential]::new('', $securePassword).Password
$certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
    $pfxPath, $password, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
try {
    if ($certificate.Subject -ne $manifest.Package.Identity.Publisher -or !$certificate.HasPrivateKey) {
        throw 'The signing key must match the package publisher and contain a private key.'
    }
    if ($certificate.NotAfter -le (Get-Date)) { throw 'The release signing certificate has expired.' }
    $sdkBin = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
    $signTool = Get-ChildItem -LiteralPath $sdkBin -Directory |
        Where-Object { $_.Name -match '^10\.0\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending |
        ForEach-Object { Join-Path $_.FullName 'x64\signtool.exe' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (!$signTool) { throw 'Windows SDK SignTool was not found.' }
    [void](New-Item -ItemType Directory -Path $outputRoot -Force)

    foreach ($architecture in $Architectures) {
        $runtime = 'win-' + $architecture.ToLowerInvariant()
        $buildOutput = Join-Path $outputRoot "build-$architecture"
        $assetName = "LayoutAwareSearch-$version-$architecture"
        $staging = Join-Path $outputRoot $assetName
        $zipPath = Join-Path $outputRoot "$assetName.zip"
        if ((Test-Path -LiteralPath $staging) -or (Test-Path -LiteralPath $zipPath)) {
            throw "Release output already exists for $architecture. Use a new version or move the previous output before rebuilding."
        }

        # A self-contained package includes .NET. Disable trimming for reliable WinRT marshalling.
        & dotnet publish $project -c Release -r $runtime --self-contained true `
            "-p:Platform=$architecture" '-p:PublishTrimmed=false' '-p:PublishSingleFile=false' `
            '-p:GenerateAppxPackageOnBuild=true' '-p:AppxPackageSigningEnabled=false' `
            '-p:AppxAutoIncrementPackageRevision=false' '-p:AppxBundle=Never' `
            '-p:UapAppxPackageBuildMode=SideloadOnly' "-p:AppxPackageDir=$buildOutput\"
        if ($LASTEXITCODE -ne 0) { throw "Package build failed for $architecture." }

        $packages = @(Get-ChildItem -LiteralPath $buildOutput -Recurse -File -Filter '*.msix')
        if ($packages.Count -ne 1) { throw "Expected one MSIX for $architecture; found $($packages.Count)." }
        [void](New-Item -ItemType Directory -Path $staging)
        $packageName = "$assetName.msix"
        $packagePath = Join-Path $staging $packageName
        Copy-Item -LiteralPath $packages[0].FullName -Destination $packagePath
        & $signTool sign /fd SHA256 /f $pfxPath /p $password $packagePath
        if ($LASTEXITCODE -ne 0) { throw "MSIX signing failed for $architecture." }

        # Check package identity, registration and runtime without trusting or installing it.
        $archive = [System.IO.Compression.ZipFile]::OpenRead($packagePath)
        try {
            foreach ($required in @('AppxSignature.p7x', 'coreclr.dll', 'hostpolicy.dll', 'LayoutAwareSearch.exe', 'Microsoft.CommandPalette.Extensions.dll', 'Public/README.txt')) {
                if (!$archive.GetEntry($required)) { throw "Package is missing $required." }
            }
            $reader = [System.IO.StreamReader]::new($archive.GetEntry('AppxManifest.xml').Open())
            try { [xml]$packedManifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
            if ($packedManifest.Package.Identity.Publisher -ne $certificate.Subject `
                -or $packedManifest.Package.Identity.Version -ne $packageVersion.ToString() `
                -or $packedManifest.Package.Identity.ProcessorArchitecture -ne $architecture.ToLowerInvariant()) {
                throw 'Packaged identity, version or architecture does not match the release.'
            }
        }
        finally { $archive.Dispose() }

        $publicCertificateName = 'LayoutAwareSearch.cer'
        [System.IO.File]::WriteAllBytes((Join-Path $staging $publicCertificateName), $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
        $certificateSha256 = $certificate.GetCertHashString([System.Security.Cryptography.HashAlgorithmName]::SHA256)
        [ordered]@{
            Version = $packageVersion.ToString()
            Architecture = $architecture
            Package = $packageName
            PackageSha256 = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash
            Certificate = $publicCertificateName
            CertificateSha256 = $certificateSha256
            Publisher = $certificate.Subject
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $staging 'release-info.json') -Encoding utf8
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'installer\Install.ps1') -Destination $staging
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'installer\Install.cmd') -Destination $staging
        Copy-Item -LiteralPath (Join-Path $root 'docs\INSTALL.md') -Destination (Join-Path $staging 'INSTALL.md')
        Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $staging -File).FullName -DestinationPath $zipPath
        Write-Host "Release asset: $zipPath"
        Write-Host "Certificate SHA256: $certificateSha256"
    }

    Get-ChildItem -LiteralPath $outputRoot -File -Filter '*.zip' | Sort-Object Name | ForEach-Object {
        '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name
    } | Set-Content -LiteralPath (Join-Path $outputRoot 'SHA256SUMS.txt') -Encoding ascii
}
finally { $certificate.Dispose(); $password = $null }
