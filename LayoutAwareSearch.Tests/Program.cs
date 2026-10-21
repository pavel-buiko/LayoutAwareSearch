using LayoutAwareSearch.Search;
using System.Globalization;

var checks = 0;
void Check(bool condition, string message)
{
    if (!condition)
    {
        throw new InvalidOperationException(message);
    }

    checks++;
    Console.WriteLine("PASS " + message);
}

Check(KeyboardLayoutConverter.GetQueries("  ").Length == 0, "Blank query has no variants");
var layouts = KeyboardLayoutConverter.GetLayouts();
Console.WriteLine("Loaded Windows layouts: " + string.Join(", ", layouts.Select(layout => layout.ToString("X", CultureInfo.InvariantCulture))));
Check(layouts.Length > 0, "Windows input layouts are discovered");
var queries = KeyboardLayoutConverter.GetQueries("  ChatGPT  ");
Check(queries[0] == "ChatGPT", "Original query is retained and trimmed");
Check(queries.Distinct(StringComparer.OrdinalIgnoreCase).Count() == queries.Length, "Variants are deduplicated");
Check(KeyboardLayoutConverter.GetQueries("😀").Contains("😀"), "Unmappable characters are preserved");

var english = layouts.FirstOrDefault(layout => ((long)layout & 0xffff) == 0x0409);
var russian = layouts.FirstOrDefault(layout => ((long)layout & 0xffff) == 0x0419);
if (english != 0 && russian != 0)
{
    Check(KeyboardLayoutConverter.Convert("срфепзе", russian, english) == "chatgpt", "Russian → English: срфепзе → chatgpt");
    Check(KeyboardLayoutConverter.Convert("chatgpt", english, russian) == "срфепзе", "English → Russian: chatgpt → срфепзе");
    Check(KeyboardLayoutConverter.Convert(",kjryjn", english, russian) == "блокнот", "English → Russian application name");
    Check(KeyboardLayoutConverter.Convert("СрфеПЗЕ 123", russian, english) == "ChatGPT 123", "Case, Shift, spaces and digits");
    Check(KeyboardLayoutConverter.GetQueries("срфепзе").Contains("chatgpt", StringComparer.OrdinalIgnoreCase), "System layout variants contain ChatGPT");
}
else
{
    Console.WriteLine("SKIP Russian/US pair is not loaded; no input languages were added for tests.");
}

ApplicationEntry[] apps = [new("ChatGPT", "chat"), new("ChatGPT Desktop", "desktop"), new("My ChatGPT", "other"), new("Блокнот", "notepad")];
var matches = ApplicationSearch.Find(apps, ["срфепзе", "chatgpt"]);
Check(matches.Select(match => match.Application.Target).SequenceEqual(["chat", "desktop", "other"]), "Exact, prefix and substring ranking");
Check(matches.All(match => match.Query == "chatgpt"), "Result records the matching converted query");
Check(ApplicationSearch.Find(apps, []).Length == 0, "Empty search does not return every app");
Check(ApplicationSearch.Find(apps, ["unmatched"]).Length == 0, "Unknown query has no matches");
Check(ApplicationSearch.Find(apps, ["CHATGPT"]).First().Application.Target == "chat", "Search ignores case");
Check(ApplicationSearch.Find(apps, [",kjryjn", "блокнот"]).Single().Application.Target == "notepad", "Reverse search finds a Russian application");
Check(ApplicationSearch.Find([new("abc", "original"), new("xyz", "converted")], ["abc", "xyz"])[0].Application.Target == "original", "Original input wins equal-quality matches");

var catalog = new ApplicationCatalog();
var firstRefresh = catalog.GetApplicationsAsync();
Check(ReferenceEquals(firstRefresh, catalog.GetApplicationsAsync()), "Concurrent searches share a catalog refresh");
var installed = await firstRefresh;
Check(installed.Length > 0, "Real Windows application index is populated");
if (args.Contains("--skip-package-checks", StringComparer.Ordinal))
{
    Console.WriteLine("SKIP MSIX integration assertion (sandbox run).");
}
else
{
    Check(installed.Any(app => app.IsPackaged), "MSIX/Store applications are indexed");
}
Check(installed.Any(app => !app.IsPackaged), "Start Menu shortcuts are indexed");
Check(installed.Select(app => app.Target).Distinct(StringComparer.OrdinalIgnoreCase).Count() == installed.Length, "Launch targets are unique");
var actual = ApplicationSearch.Find(installed, KeyboardLayoutConverter.GetQueries("срфепзе"));
Console.WriteLine("Live срфепзе results: " + string.Join(", ", actual.Select(match => match.Application.Name)));
if (english != 0 && russian != 0 && installed.Any(app => app.Name.Equals("ChatGPT", StringComparison.OrdinalIgnoreCase)))
{
    Check(actual.Length > 0 && actual[0].Application.Name.Equals("ChatGPT", StringComparison.OrdinalIgnoreCase), "Live Windows catalog: срфепзе finds installed ChatGPT first");
}

Console.WriteLine($"{checks} checks passed. Indexed {installed.Length} applications.");
