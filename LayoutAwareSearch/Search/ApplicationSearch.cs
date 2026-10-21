using System;
using System.Collections.Generic;
using System.Linq;

namespace LayoutAwareSearch.Search;

internal sealed record ApplicationEntry(string Name, string Target, bool IsPackaged = false);

internal sealed record ApplicationMatch(ApplicationEntry Application, string Query, int Score);

internal static class ApplicationSearch
{
    public static ApplicationMatch[] Find(IEnumerable<ApplicationEntry> applications, string[] queries)
    {
        if (queries.Length == 0)
        {
            return [];
        }

        return applications.Select(app => queries
                .Select((query, index) => new ApplicationMatch(app, query, Score(app.Name, query, index)))
                .OrderBy(match => match.Score)
                .First())
            .Where(match => match.Score < int.MaxValue)
            .OrderBy(match => match.Score)
            .ThenBy(match => match.Application.Name, StringComparer.CurrentCultureIgnoreCase)
            .ToArray();
    }

    private static int Score(string name, string query, int queryIndex)
    {
        var position = name.IndexOf(query, StringComparison.OrdinalIgnoreCase);
        if (position < 0)
        {
            return int.MaxValue;
        }

        // Exact match, prefix, then substring. Prefer the original input at equal quality.
        var quality = name.Equals(query, StringComparison.OrdinalIgnoreCase) ? 0 : position == 0 ? 1 : 2;
        return (quality * 10000) + (queryIndex == 0 ? 0 : 1000) + Math.Min(position, 999);
    }
}
