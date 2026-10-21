# Layout-Aware Search

Find and launch apps in **PowerToys Command Palette**, even when you type their names in the wrong keyboard layout.

Находите и запускайте приложения в **PowerToys Command Palette**, даже если название набрано в другой раскладке.

[English](#english) · [Русский](#russian)

<a id="english"></a>

## English

### Why this extension exists

You open Command Palette and type `срфепзе`, intending to enter `chatgpt`. The keys are correct, but the Russian layout is active, so app search may offer a web search instead of ChatGPT.

Layout-Aware Search checks the original query and the text those same physical keys would produce in your other loaded Windows keyboard layouts. This works in both directions:

- `срфепзе` → `chatgpt` → **ChatGPT**.
- `,kjryjn` → `блокнот` → **Блокнот**, if an indexed application has that Russian name.

This corrects the keyboard layout, rather than translating application names. Windows keyboard APIs are used instead of a hardcoded Russian/English character table.

### Features

- Searches across every pair of loaded Windows keyboard layouts, in both directions.
- Keeps the original query and performs case-insensitive matching.
- Ranks exact matches first, followed by name prefixes and substrings. At equal match quality, the original query takes priority.
- Indexes current-user and shared Start Menu shortcuts (`.lnk` and `.appref-ms`), plus MSIX/Microsoft Store applications for the current user.
- Offers the best match as a launch action in Command Palette's main search through a fallback command.
- Provides **Show all matches** in the fallback's context menu when multiple applications match, and a dedicated search page.

Query conversion and application indexing run locally. The extension does not send queries to an online search service or change the active keyboard layout.

### Build and install from source

Requirements:

- Windows supported by your installed version of PowerToys, with **Command Palette** enabled.
- A .NET SDK capable of building the project's `net9.0-windows10.0.26100.0` target.
- Visual Studio with MSIX packaging/deployment support and the Windows SDK required by the project.
- An `x64` or `ARM64` target matching your device.

Steps:

1. Clone this repository and open `LayoutAwareSearch.sln` in Visual Studio.
2. Restore NuGet packages, select `Debug` and your platform, and set **LayoutAwareSearch** as the startup project.
3. Build and deploy the extension using its **LayoutAwareSearch (Package)** profile. Running the unpackaged executable alone does not register an extension with Command Palette.
4. Open Command Palette's extension settings and enable **Layout-Aware Search** and its **Search apps in other keyboard layouts** fallback. Restart Command Palette if the extension is not listed after deployment.
5. If web search appears before the application result, adjust the fallback order in Command Palette settings.

You can compile the extension from the repository root with:

```powershell
dotnet build LayoutAwareSearch\LayoutAwareSearch.csproj -p:Platform=x64
```

Use `-p:Platform=ARM64` for ARM64. This command builds the project; deployment/registration is a separate step.

The manifest currently contains the template publisher identity. Before distributing a signed MSIX, replace it with your own publisher identity and configure the matching signing certificate. This is a community extension for PowerToys.

### Usage

Type an application name directly into Command Palette, even in the wrong layout. The fallback offers the best matching application for launch. Use its **Show all matches** context action to see the remaining results.

You can also open **Layout-Aware Search** from Command Palette and search within the extension's page.

### Scope and limitations

- The main search integration uses Command Palette's public fallback mechanism. It does not modify the built-in Apps provider; the host controls fallback visibility and ordering.
- Windows layouts are read on each query. The application index is refreshed on the next search once its two-minute cache expires.
- Portable applications need a Start Menu shortcut to be discovered by this index.
- Physical keys are mapped using `VkKeyScanExW`, `MapVirtualKeyExW` and `ToUnicodeEx`, including Shift/AltGr where Windows can resolve the characters.
- IME input and composed dead-key sequences are not reconstructed. Characters that cannot be converted are preserved.
- Conversion applies to the whole query for each layout pair. It does not try every possible per-character combination for text typed in mixed layouts.

### Verification

Run the check executable from the repository root:

```powershell
dotnet run --project LayoutAwareSearch.Tests\LayoutAwareSearch.Tests.csproj -p:Platform=x64
```

Checks cover matching and ranking, blank input, Unicode, query deduplication, the real Windows application index, and conversion between loaded US/Russian layouts in both directions. US/Russian checks are explicitly skipped if that pair is unavailable. The live ChatGPT check runs when those layouts and an application named ChatGPT are present.

The checks neither add keyboard layouts nor launch applications. The full integration run requires access to Windows package enumeration and expects both packaged applications and Start Menu shortcuts. In a restricted sandbox, pass `-- --skip-package-checks` to skip the assertion requiring packaged applications.

Automated checks do not replace a test of the deployed extension inside Command Palette: verify app launch, clearing the query, and **Show all matches** there.

The x64 Debug build and full application-index checks have passed. The x64 Release build also succeeds, but currently reports WinRT trimming warnings (`IL2081`, summarized as `IL2104`) and SDK WinMD packaging warning `APPX1707`. Runtime behavior of a deployed Release package still needs manual verification.

---

<a id="russian"></a>

## Русский

### Для чего нужно расширение

Вы открываете Command Palette и вводите `срфепзе`, собираясь набрать `chatgpt`. Клавиши нажаты правильно, но активна русская раскладка, поэтому поиск приложений может предложить поиск в интернете вместо ChatGPT.

Layout-Aware Search проверяет исходный запрос и текст, который те же физические клавиши дали бы в других загруженных раскладках Windows. Это работает в обе стороны:

- `срфепзе` → `chatgpt` → **ChatGPT**.
- `,kjryjn` → `блокнот` → **Блокнот**, если в индексе есть приложение с таким русским названием.

Расширение исправляет раскладку ввода, а не переводит названия приложений. Вместо зашитой таблицы русских и английских букв используются API клавиатуры Windows.

### Возможности

- Поиск по всем парам загруженных раскладок Windows в обоих направлениях.
- Сохранение исходного запроса и поиск без учёта регистра.
- Сначала точное совпадение, затем начало названия и вхождение подстроки. При одинаковом качестве совпадения исходный запрос имеет приоритет.
- Индексация ярлыков `.lnk` и `.appref-ms` из пользовательского и общего меню «Пуск», а также приложений MSIX/Microsoft Store текущего пользователя.
- Запуск лучшего совпадения из основного поиска Command Palette через fallback-команду.
- Команда **Show all matches** в контекстном меню fallback при нескольких совпадениях и отдельная страница поиска.

Преобразование запроса и индексация приложений выполняются локально. Расширение не отправляет запросы в интернет-поисковик и не переключает текущую раскладку.

### Сборка и установка из исходников

Требования:

- Windows, поддерживаемая установленной версией PowerToys, с включённым **Command Palette**.
- .NET SDK, способный собрать проект с целевой платформой `net9.0-windows10.0.26100.0`.
- Visual Studio с поддержкой упаковки и развёртывания MSIX и Windows SDK, требуемым проектом.
- Платформа `x64` или `ARM64`, соответствующая устройству.

Порядок установки:

1. Клонируйте репозиторий и откройте `LayoutAwareSearch.sln` в Visual Studio.
2. Восстановите NuGet-пакеты, выберите `Debug` и нужную платформу, назначьте **LayoutAwareSearch** запускаемым проектом.
3. Соберите и разверните расширение через профиль **LayoutAwareSearch (Package)**. Запуск обычного exe без упаковки сам по себе не регистрирует расширение в Command Palette.
4. В настройках расширений Command Palette включите **Layout-Aware Search** и его fallback **Search apps in other keyboard layouts**. Если после развёртывания расширение отсутствует в списке, перезапустите Command Palette.
5. Если веб-поиск находится выше результата приложения, измените порядок fallback-команд в настройках Command Palette.

Для сборки из корня репозитория:

```powershell
dotnet build LayoutAwareSearch\LayoutAwareSearch.csproj -p:Platform=x64
```

Для ARM64 используйте `-p:Platform=ARM64`. Команда собирает проект; развёртывание и регистрация выполняются отдельно.

Сейчас манифест содержит идентификатор издателя из шаблона. Перед распространением подписанного MSIX замените его своим идентификатором и настройте соответствующий сертификат подписи. Это независимое расширение для PowerToys.

### Использование

Введите название приложения прямо в Command Palette, даже если активна другая раскладка. Fallback предложит запуск лучшего совпадения. Остальные результаты можно открыть через **Show all matches** в его контекстном меню.

Также можно открыть **Layout-Aware Search** из Command Palette и искать на отдельной странице расширения.

### Область работы и ограничения

- Интеграция с основным поиском использует публичный механизм fallback Command Palette. Встроенный провайдер Apps не изменяется; видимость и порядок fallback определяет Command Palette.
- Раскладки Windows считываются при каждом запросе. Индекс приложений обновляется при следующем поиске после истечения двухминутного кеша.
- Для обнаружения переносимого приложения нужен ярлык в меню «Пуск».
- Физические клавиши сопоставляются через `VkKeyScanExW`, `MapVirtualKeyExW` и `ToUnicodeEx`, включая Shift/AltGr, когда Windows может восстановить соответствующий ввод.
- Ввод через IME и составные последовательности dead keys не восстанавливаются. Символы, которые нельзя преобразовать, сохраняются.
- Для каждой пары раскладок преобразуется вся строка запроса. Все возможные сочетания раскладок для отдельных букв смешанного текста не перебираются.

### Проверки

Запустите проверочный проект из корня репозитория:

```powershell
dotnet run --project LayoutAwareSearch.Tests\LayoutAwareSearch.Tests.csproj -p:Platform=x64
```

Проверяются поиск и ранжирование, пустой ввод, Unicode, отсутствие повторяющихся вариантов запроса, реальный индекс приложений Windows и преобразования между загруженными раскладками US/RU в обоих направлениях. При отсутствии этой пары соответствующие проверки явно пропускаются. Проверка поиска установленного ChatGPT выполняется, если доступны эти раскладки и приложение с названием ChatGPT.

Проверки не добавляют раскладки и не запускают приложения. Полный интеграционный прогон требует доступа к перечислению пакетов Windows и наличия приложений обоих типов: пакетных и ярлыков меню «Пуск». Для ограниченной песочницы добавьте `-- --skip-package-checks`, чтобы пропустить проверку наличия пакетных приложений.

Автоматические проверки не заменяют проверку развёрнутого расширения в Command Palette: там нужно проверить запуск приложения, очистку запроса и **Show all matches**.

Сборка x64 Debug и полный прогон проверок индекса приложений прошли успешно. Сборка x64 Release также завершается успешно, но сейчас выдаёт предупреждения тримминга WinRT (`IL2081`, в сводке — `IL2104`) и упаковки SDK WinMD `APPX1707`. Работу развёрнутого Release-пакета ещё нужно проверить вручную.

## API references / Документация API

- [PowerToys Command Palette: fallback handler](https://learn.microsoft.com/en-us/windows/powertoys/command-palette/microsoft-commandpalette-extensions/ifallbackhandler)
- [Command Palette SDK: fallback visibility](https://github.com/microsoft/PowerToys/blob/main/src/modules/cmdpal/doc/initial-sdk-spec/initial-sdk-spec.md#fallback-commands)
- [Windows keyboard conversion: ToUnicodeEx](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-tounicodeex)
