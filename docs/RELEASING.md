# Maintainer release process

User installation is documented in [INSTALL.md](INSTALL.md). The steps below are for the maintainer, not for users downloading a release.

## One-time signing setup

On Windows, using PowerShell 7.2 or later:

```powershell
./scripts/New-ReleaseCertificate.ps1
```

The script creates a code-signing key in `.release-signing/` without changing Windows certificate trust. That directory is ignored by Git. Keep using this certificate for updates so users do not need to trust a new key for each release.

Back up the key securely. Its PFX password is stored using Windows DPAPI in `password.dpapi`; that file can be decrypted only in the original Windows user's context. For a backup portable to another account/machine, export the PFX with a separate strong backup password using a certificate-management tool while you still have access to this account. Never commit the PFX, a password, or DPAPI files, and never attach them to a release. The public `.cer` is intended to be distributed.

The self-signed certificate is valid for three years. These preview packages are not timestamped; plan a signing-key renewal and user trust update before expiration. A publicly trusted signing provider can replace this preview arrangement in the future.

## Prepare a version

1. Update `Package.appxmanifest` to a new four-part version, keeping its final component `0` (for example, `0.1.1.0`). Keep the release publisher and package identity stable.
2. Add `docs/releases/vMAJOR.MINOR.PATCH.md` with release notes in English and Russian. The publisher replaces `@CERTIFICATE_SHA256@` with the actual public-certificate fingerprint.
3. Run the checks and build packages from the repository root:

```powershell
dotnet run --project LayoutAwareSearch.Tests/LayoutAwareSearch.Tests.csproj -p:Platform=x64
./scripts/Test-Installer.ps1
./scripts/Build-Release.ps1
```

The build script creates self-contained, untrimmed Release MSIX packages for x64 and ARM64, signs them, and checks the packaged runtime and extension folder. The ZIPs contain the MSIX, public certificate, installer, instructions and metadata. Only the ZIPs and `SHA256SUMS.txt` are uploaded; build directories are not release assets.

Output is under `artifacts/vMAJOR.MINOR.PATCH/`, ignored by Git. Existing ZIP/staging directories are never overwritten by the build script. Move your previous output aside if you need to rebuild the same version before publication. Do not replace assets of an already published version: increment the version instead.

Test the real installer and Command Palette interaction before calling a release stable. `Test-Installer.ps1` checks architecture handling, integrity failures, path traversal and declined trust without importing certificates or installing an application. It cannot validate a real UAC prompt, AppX deployment or Command Palette UI. ARM64 packages also need testing on ARM64 hardware.

The Windows SDK may report that `mspdbcmf.exe` is unavailable; this means a separate symbols package was not produced. A clean build can also emit SDK warning `APPX1707` for WinMD implementation metadata. Packaging success and package-content checks are verified separately by the script.

## Publish to GitHub

Commit all source/documentation changes and push `main`. Git Credential Manager must already be signed in to GitHub as the repository owner.

```powershell
./scripts/Publish-GitHubRelease.ps1 -ValidateOnly
./scripts/Publish-GitHubRelease.ps1
```

The publisher checks that the working tree is clean, `origin/main` matches HEAD, ZIP checksums match and no private-key files are in the archives. It creates/pushes an annotated version tag, prepares a draft release, uploads both ZIPs and the checksum file, checks asset sizes and server digests when available, then publishes it as a **prerelease**.

For the first publication only, `-MakePublic` permits changing the repository from private to public. Obtain the owner's approval before using it. Later publications do not need this flag.

GitHub credentials are read through the configured Git credential helper and used only in memory. No signing secrets are uploaded to GitHub. If upload fails, the release stays a draft; inspect it before retrying. The script refuses to overwrite an existing release or a tag pointing at another commit.
