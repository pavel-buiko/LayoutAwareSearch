// Copyright (c) Microsoft Corporation
// The Microsoft Corporation licenses this file to you under the MIT license.
// See the LICENSE file in the project root for more information.

using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;
using LayoutAwareSearch.Search;
using System;
using System.Threading;

namespace LayoutAwareSearch;

internal sealed partial class LayoutAwareSearchPage : DynamicListPage
{
    private readonly SearchService _search;
    private IListItem[] _items = [];
    private int _version;

    public LayoutAwareSearchPage(SearchService search)
    {
        _search = search;
        Icon = IconHelpers.FromRelativePath("Assets\\StoreLogo.png");
        Title = "Layout-Aware Search";
        Name = "Open";
        _items = [Message("Type an application name in any enabled keyboard layout")];
    }

    public override IListItem[] GetItems() => _items;

    public override async void UpdateSearchText(string oldSearch, string newSearch)
    {
        var version = Interlocked.Increment(ref _version);
        IsLoading = true;
        try
        {
            var matches = await _search.FindAsync(newSearch);
            if (version != Volatile.Read(ref _version))
            {
                return;
            }

            _items = Array.ConvertAll(matches, match => (IListItem)new ListItem(new LaunchApplicationCommand(match.Application))
            {
                Title = match.Application.Name,
                Subtitle = string.Equals(match.Query, newSearch.Trim(), StringComparison.OrdinalIgnoreCase)
                    ? "Open application" : "Keyboard layout: " + match.Query,
                Icon = Icon,
            });
            if (_items.Length == 0)
            {
                _items = [Message(string.IsNullOrWhiteSpace(newSearch)
                    ? "Type an application name in any enabled keyboard layout" : "No applications found")];
            }
        }
        catch (Exception exception)
        {
            if (version == Volatile.Read(ref _version))
            {
                _items = [Message("Application search failed: " + exception.Message)];
            }
        }
        finally
        {
            if (version == Volatile.Read(ref _version))
            {
                IsLoading = false;
                RaiseItemsChanged(_items.Length);
            }
        }
    }

    private static ListItem Message(string title) => new(new NoOpCommand()) { Title = title };
}
