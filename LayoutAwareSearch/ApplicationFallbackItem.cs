using System;
using System.Diagnostics;
using System.Threading;
using LayoutAwareSearch.Search;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace LayoutAwareSearch;

internal sealed partial class ApplicationFallbackItem : FallbackCommandItem
{
    private readonly SearchService _search;
    private int _version;

    public ApplicationFallbackItem(SearchService search)
        : base("Search apps in other keyboard layouts", "layout-aware-app-search")
    {
        _search = search;
        Command = null;
        Title = string.Empty;
        Icon = IconHelpers.FromRelativePath("Assets\\StoreLogo.png");
    }

    public override async void UpdateQuery(string query)
    {
        var version = Interlocked.Increment(ref _version);
        // CmdPal hides a fallback with an empty title. Also clear the old launch action.
        Command = null;
        Title = string.Empty;
        Subtitle = string.Empty;
        MoreCommands = [];
        try
        {
            var matches = await _search.FindAsync(query);
            if (version != Volatile.Read(ref _version) || matches.Length == 0)
            {
                return;
            }

            var best = matches[0];
            Title = best.Application.Name;
            Subtitle = "Open application · " + best.Query;
            if (matches.Length > 1)
            {
                var page = new LayoutAwareSearchPage(_search) { Name = "Show all matches", SearchText = query };
                MoreCommands = [new CommandContextItem(page)];
            }
            else
            {
                MoreCommands = [];
            }

            Command = new LaunchApplicationCommand(best.Application);
        }
        catch (Exception exception)
        {
            // This is an async-void SDK callback: failures must not escape into the host.
            Debug.WriteLine(exception);
        }
    }
}
