# Install / Установка

## English

1. Install PowerToys and enable Command Palette.
2. Download the ZIP for your processor from the [GitHub release](https://github.com/pavel-buiko/LayoutAwareSearch/releases): **x64** for most Intel/AMD PCs, **ARM64** for Windows on ARM.
3. Extract the entire ZIP to a local folder and open **Install.cmd**.
4. On the first installation, compare the displayed certificate SHA256 fingerprint with the one in the GitHub release. Type **YES** if you choose to trust it and accept the Windows administrator prompt. Subsequent releases signed by the same certificate reuse that trust.
5. Restart Command Palette and enable **Layout-Aware Search** and **Search apps in other keyboard layouts** in its extension settings. Adjust the fallback order if necessary.

No Visual Studio or .NET SDK is required. The package includes its .NET runtime. Updates are installed by downloading a newer release and running its installer; automatic updates are not configured.

This preview is signed with a self-signed certificate, not a publicly trusted code-signing certificate. The installer explicitly asks before adding its public certificate to **Local Machine → Trusted People**. That step requires administrator permission; application installation runs as the original user. The installer uses a process-scoped PowerShell execution-policy bypass to run the downloaded installation script. It does not change the system execution policy.

Install.cmd, Install.ps1, the MSIX, the public CER and release-info.json must stay together. Neither a private signing key nor its password is included in a release. SHA256SUMS.txt detects incomplete or altered downloads; use the project's GitHub release as the source of the checksums and certificate fingerprint.

If you previously deployed the Visual Studio template version, uninstall that development copy from Windows Settings first. The release uses its own publisher identity and cannot update the old template package in place.

To uninstall, remove Layout-Aware Search through Windows Settings → Apps. To revoke trust in this preview's signing key, open `certlm.msc` as administrator, locate the certificate with the release's fingerprint under **Trusted People → Certificates**, and remove it. Only remove that exact certificate.

## Русский

1. Установите PowerToys и включите Command Palette.
2. Скачайте ZIP для своего процессора из [GitHub Releases](https://github.com/pavel-buiko/LayoutAwareSearch/releases): **x64** для большинства компьютеров Intel/AMD, **ARM64** для Windows на ARM.
3. Полностью распакуйте ZIP в локальную папку и откройте **Install.cmd**.
4. При первой установке сравните показанный SHA256-отпечаток сертификата с отпечатком в GitHub Release. Если согласны доверять этому сертификату, введите **YES** и подтвердите запрос администратора Windows. Следующие версии с той же подписью используют уже установленное доверие.
5. Перезапустите Command Palette и включите **Layout-Aware Search** и **Search apps in other keyboard layouts** в настройках расширений. При необходимости измените порядок fallback-команд.

Visual Studio и .NET SDK не нужны: среда выполнения .NET включена в пакет. Для обновления скачайте новый релиз и запустите его установщик; автоматические обновления пока не настроены.

Эта предварительная версия подписана самоподписанным сертификатом, а не сертификатом общедоверенного центра. Установщик явно запрашивает согласие перед добавлением публичного сертификата в **Локальный компьютер → Доверенные лица**. Для этого нужны права администратора; приложение устанавливается для исходного пользователя. Чтобы запустить скачанный скрипт, установщик использует обход политики выполнения PowerShell только для своего процесса. Системная политика выполнения не изменяется.

Файлы Install.cmd, Install.ps1, MSIX, публичный CER и release-info.json должны находиться вместе. Приватный ключ подписи и его пароль в релиз не входят. SHA256SUMS.txt позволяет обнаружить неполную загрузку или изменение файлов; берите суммы и отпечаток сертификата из релиза в репозитории проекта.

Если раньше вы разворачивали шаблонную версию из Visual Studio, сначала удалите эту копию через параметры Windows. У релизной версии собственный идентификатор издателя, поэтому она не обновляет старый шаблонный пакет поверх.

Для удаления используйте Параметры Windows → Приложения. Чтобы отозвать доверие к ключу этой предварительной версии, запустите `certlm.msc` от администратора, найдите сертификат с отпечатком релиза в разделе **Доверенные лица → Сертификаты** и удалите только этот сертификат.
