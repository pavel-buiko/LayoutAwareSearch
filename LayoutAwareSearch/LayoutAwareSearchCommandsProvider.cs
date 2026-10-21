// Copyright (c) Microsoft Corporation
// The Microsoft Corporation licenses this file to you under the MIT license.
// See the LICENSE file in the project root for more information.

using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;
using LayoutAwareSearch.Search;

namespace LayoutAwareSearch;

public partial class LayoutAwareSearchCommandsProvider : CommandProvider
{
    private readonly ICommandItem[] _commands;
    private readonly IFallbackCommandItem[] _fallbackCommands;

    public LayoutAwareSearchCommandsProvider()
    {
        DisplayName = "Layout-Aware Search";
        Icon = IconHelpers.FromRelativePath("Assets\\StoreLogo.png");
        Id = "layout-aware-search";
        var search = new SearchService();
        _ = search.WarmUpAsync();
        _commands = [
            new CommandItem(new LayoutAwareSearchPage(search)) { Title = DisplayName },
        ];
        _fallbackCommands = [new ApplicationFallbackItem(search)];
    }

    public override ICommandItem[] TopLevelCommands()
    {
        return _commands;
    }

    public override IFallbackCommandItem[] FallbackCommands() => _fallbackCommands;
}
