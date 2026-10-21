using System;
using System.ComponentModel;
using System.Diagnostics;
using LayoutAwareSearch.Search;
using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace LayoutAwareSearch;

internal sealed partial class LaunchApplicationCommand : InvokableCommand
{
    private readonly ApplicationEntry _application;

    public LaunchApplicationCommand(ApplicationEntry application)
    {
        _application = application;
        Id = "launch:" + application.Target;
        Name = "Open";
    }

    public override ICommandResult Invoke()
    {
        try
        {
            var startInfo = _application.IsPackaged
                ? new ProcessStartInfo("explorer.exe") { UseShellExecute = true }
                : new ProcessStartInfo(_application.Target) { UseShellExecute = true };
            if (_application.IsPackaged)
            {
                startInfo.ArgumentList.Add("shell:AppsFolder\\" + _application.Target);
            }

            Process.Start(startInfo);
            return CommandResult.Dismiss();
        }
        catch (Exception exception) when (exception is Win32Exception or InvalidOperationException)
        {
            return CommandResult.ShowToast("Could not open " + _application.Name + ": " + exception.Message);
        }
    }
}
