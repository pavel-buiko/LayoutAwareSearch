#Requires -Version 7.2
[CmdletBinding()]
param([switch]$MakePublic, [switch]$ValidateOnly)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    $dirty = git status --porcelain
    if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Commit all source changes before publishing.' }
    $commit = git rev-parse HEAD
    $remoteCommit = (git ls-remote origin refs/heads/main) -split '\s+' | Select-Object -First 1
    if ($LASTEXITCODE -ne 0 -or $commit -ne $remoteCommit) { throw 'Push the release source to origin/main before publishing.' }
    [xml]$manifest = Get-Content -LiteralPath (Join-Path $root 'LayoutAwareSearch\Package.appxmanifest') -Raw
    $packageVersion = [version]$manifest.Package.Identity.Version
    $version = '{0}.{1}.{2}' -f $packageVersion.Major, $packageVersion.Minor, $packageVersion.Build
    $tag = "v$version"
    $directory = Join-Path $root "artifacts\$tag"
    $assets = @(
        Join-Path $directory "LayoutAwareSearch-$version-x64.zip"
        Join-Path $directory "LayoutAwareSearch-$version-ARM64.zip"
        Join-Path $directory 'SHA256SUMS.txt'
    )
    $checksums = Get-Content -LiteralPath $assets[2]
    $fingerprint = $null
    foreach ($asset in $assets[0..1]) {
        $hash = (Get-FileHash -LiteralPath $asset -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($checksums -notcontains "$hash  $([IO.Path]::GetFileName($asset))") { throw 'Release ZIP checksum mismatch.' }
        $archive = [IO.Compression.ZipFile]::OpenRead($asset)
        try {
            if ($archive.Entries.FullName -match '\.(pfx|p12|dpapi)$') { throw 'A private signing file was found in the release ZIP.' }
            foreach ($required in @('Install.cmd', 'Install.ps1', 'INSTALL.md', 'LayoutAwareSearch.cer', 'release-info.json')) {
                if (!$archive.GetEntry($required)) { throw "Release ZIP is missing $required." }
            }
            $reader = [IO.StreamReader]::new($archive.GetEntry('release-info.json').Open())
            try { $info = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
            if ($fingerprint -and $fingerprint -ne $info.CertificateSha256) { throw 'Architecture packages have different signing keys.' }
            $fingerprint = $info.CertificateSha256
        }
        finally { $archive.Dispose() }
    }

    if ($ValidateOnly) {
        Write-Host "Validated $tag assets against SHA256SUMS.txt. No GitHub changes were made."
        return
    }

    # Use the account's existing Git credential helper. Never print or persist its token.
    $env:GCM_INTERACTIVE = 'Never'
    $request = [string]::Join([char]10, @('protocol=https', 'host=github.com', 'username=pavel-buiko', '', ''))
    $lines = $request | git credential fill
    if ($LASTEXITCODE -ne 0) { throw 'Sign in to GitHub with Git Credential Manager first.' }
    $credentials = @{}
    foreach ($line in $lines) { if ($line -match '^([^=]+)=(.*)$') { $credentials[$Matches[1]] = $Matches[2] } }
    if (!$credentials['password']) { throw 'Git Credential Manager did not return an authentication token.' }
    $headers = @{ Authorization = 'Bearer ' + $credentials['password']; Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28' }
    $api = 'https://api.github.com/repos/pavel-buiko/LayoutAwareSearch'
    $repository = Invoke-RestMethod -Uri $api -Headers $headers
    if ($repository.private -and !$MakePublic) { throw 'The repository is private. Pass -MakePublic only after approving public source and releases.' }
    if ($repository.private) {
        $repository = Invoke-RestMethod -Method Patch -Uri $api -Headers $headers -ContentType 'application/json' -Body '{"visibility":"public"}'
        if ($repository.private) { throw 'The repository is still private.' }
    }

    $existingReleases = @(Invoke-RestMethod -Uri "$api/releases" -Headers $headers)
    if ($existingReleases.tag_name -contains $tag) { throw 'A release with this tag already exists. Inspect it before retrying; nothing was overwritten.' }
    $existingTag = git tag --list $tag
    if ($existingTag) {
        $tagCommit = git rev-list -n 1 $tag
        if ($tagCommit -ne $commit) { throw 'The existing tag points at another commit.' }
    }
    else {
        git tag -a $tag -m "Layout-Aware Search $tag preview"
        if ($LASTEXITCODE -ne 0) { throw 'Could not create the release tag.' }
    }
    git push origin "refs/tags/$tag"
    if ($LASTEXITCODE -ne 0) { throw 'Could not push the release tag.' }
    $notes = (Get-Content -LiteralPath (Join-Path $root "docs\releases\$tag.md") -Raw).Replace('@CERTIFICATE_SHA256@', $fingerprint)
    $body = @{ tag_name = $tag; target_commitish = $commit; name = "$tag - preview"; body = $notes; draft = $true; prerelease = $true } | ConvertTo-Json
    $release = Invoke-RestMethod -Method Post -Uri "$api/releases" -Headers $headers -ContentType 'application/json' -Body $body
    foreach ($asset in $assets) {
        $assetName = [IO.Path]::GetFileName($asset)
        $uploadUrl = $release.upload_url.Split('{')[0] + '?name=' + [Uri]::EscapeDataString($assetName)
        $contentType = if ($assetName.EndsWith('.zip')) { 'application/zip' } else { 'text/plain' }
        $uploaded = Invoke-RestMethod -Method Post -Uri $uploadUrl -Headers $headers -ContentType $contentType -InFile $asset
        if ($uploaded.state -ne 'uploaded' -or $uploaded.size -ne (Get-Item -LiteralPath $asset).Length) { throw 'Release asset upload was incomplete. The release remains a draft.' }
        if ($uploaded.digest -and $uploaded.digest -ne ('sha256:' + (Get-FileHash -LiteralPath $asset).Hash.ToLowerInvariant())) {
            throw 'Uploaded asset digest mismatch. The release remains a draft.'
        }
        Write-Host "Uploaded $assetName"
    }
    $published = Invoke-RestMethod -Method Patch -Uri "$api/releases/$($release.id)" -Headers $headers -ContentType 'application/json' -Body '{"draft":false,"prerelease":true}'
    Write-Host "Published preview: $($published.html_url)"
}
finally { Pop-Location }
